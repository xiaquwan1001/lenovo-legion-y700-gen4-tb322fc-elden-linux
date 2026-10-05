# KEXEC-ONDEVICE-R2-2026-10-05：kexec 第二轮取证 —— trans_pgd fix 不充分 + slim initramfs 真 bug

> 承接 `KEXEC-2026-10-05.md`（主机侧分析）、`KEXEC-ONDEVICE-2026-10-05.md`（第一轮上机）。
> 过程证据，只增不改；结论口径以 `TASKS.md`/`PITFALLS.md` 为准。
> 本轮 2026-10-05 深夜上机（用户授权；主线零写盘 `fastboot boot`；设备 U2/HA2EXB0E）。

---

## 0. 一句话结论

1. **trans_pgd fix 不是充分条件**：在**带 fix 的运行内核 vk58** 上发起 kexec 仍然失败 ⇒ 上游 `1537e55728ec`（VA_BITS_52/!LPA2）**不是**本机 kexec 挂死的主因/唯一因。
2. **`kexec -e` 的表现 = 直接掉电**（非 panic、非看门狗复位、非"死挂发热"）：屏灭→断电→**USB VBUS 自动开机**回 boot_b。
3. **落盘 kmsg 抓取仍未拿到里程碑**（最后一条 t≈183.4s，无 `Starting new kernel`/`Bye!`）⇒ 掉电点在里程碑之前（疑 **B1**：`kernel_restart_prepare`/`syscore_shutdown`），或掉电快到用户态来不及落盘。**非定论**。
4. **附带定位并修复一个真 bug**：G1-30 的最小 busybox initramfs 缺 `/bin/sh`/applet 符号链接 → `No working init found`（**所有 slim 镜像此前从未启动成功**）。
5. 唯一硬缺口仍是**跨跳转/掉电存活的 console**（只剩物理 UART）。

---

## 1. 纠正第一轮的测试设计错误（本轮起点）

`trans_pgd_create_copy()` 在 **运行内核** 里执行：`kexec_file_load` → `kexec_post_load()`（`kernel/kexec_file.c:448`）→
`machine_kexec_post_load()`（`:210`）→ arm64 `arch/arm64/kernel/machine_kexec.c:105`。
**它不在被 kexec 的目标 Image 里。**

⇒ 第一轮把 vk54 的两行 fix 装在**目标 Image**、却从 **vk47clean** 发起 kexec ⇒ **那段 fix 从未被执行**，
第一轮记录的「H4 单修后行为由死挂变掉电」**不能**归因于该 fix。本轮改用**带 fix 的运行内核 vk58** 重做。

---

## 2. vk58 的构造、启动与 slim initramfs 真 bug

- 原 vk54 Image 是 **dirty 构建**（manifest `kernel_git_state=dirty`，基线 vk53，config 里 `FSA4480=y/NFC=y`）。
- 本轮重建：**干净树 HEAD（26cd13b1c = vk54）** + **运行内核 vk47clean 的 config**（`FSA4480=m`/`NFC=m`/`CRC_CCITT=m`）
  + **vk47 DTS + ramoops 取证节点**（无 NFC/CDSP），`LOCALVERSION=-vk58` → `UTS=7.2.0-debug-vk58-g26cd13b1c4a2-dirty`。
- **vk58-slim 首次启动失败**。用户抓到的串口日志给出铁证（内核本身正常）：
  ```
  Run /init as init process ... Failed to execute /init (error -2)
  Run /sbin/init ... /etc/init ... /bin/init ... /bin/sh ...
  Kernel panic - not syncing: No working init found.
  ... Rebooting in 15 seconds..
  ```
- **根因**：`scripts/build-boot.sh` 拼的最小 busybox initramfs **只放了 `bin/busybox`**，没有 `/bin/sh`；
  而 `initramfs/init` 的 shebang 是 `#!/bin/sh` ⇒ 执行 `/init` 返回 ENOENT。
  修一次后 `/init` 能跑，但 `mount`/`mountpoint`/`ip: not found` —— 因为当时抓的 applet 列表来自**设备上 busybox 的符号链接**，
  而设备上 `mount`/`mountpoint` 是 util-linux、`ip` 是 iproute2（**不是 busybox 链接**），不在该列表里。
- **修复**：
  1. `scripts/build-boot.sh` 在最小 initramfs 里为 applet 建符号链接；
  2. 新增 `initramfs/busybox-applets.txt`（272 项 = 设备 busybox 259 项 ∪ `mount/mountpoint/umount/switch_root/ip/modprobe/insmod/rmmod/lsmod/dmesg/blkid/setsid/...`）。
- 修后 **vk58c-slim 启动进用户态**（进锁屏、SSH 可用；GUI 因磁盘根缺 vk58 模块而卡，与本实验无关）。

> 影像教训：`vk52/54/56/57-slim` 的"启动失败/掉电重启"**全部**是这个 initramfs bug，**不是内核**。
> 这也否定了第 5 节里为解释它们而做的 FSA4480/显示参数假设。

---

## 3. 决定性实验：从「带 fix 的运行内核」发起 kexec

- 运行 **vk58c-slim**（vk58，含 trans_pgd fix）→ `uname=7.2.0-debug-vk58-g26cd13b1c4a2-dirty`，SSH 通。
- `scripts/kexec-boot.sh --load-only` 装 vk58 Image + 最小 initramfs → **RC=0**，`/sys/kernel/kexec_loaded=1`。
- `kexec -e` → 用户观测：**屏幕熄灭 → 设备直接掉电（非关机提示、无反馈）→ USB VBUS 自动开机 → 回 boot_b(vk47clean)**。
- ⇒ **fix 已生效但 kexec 仍失败**。

---

## 4. 落盘 kmsg 抓取（本轮最可靠的通道，仍未拿到里程碑）

- 方法：设备内 `python3` 读 `/dev/kmsg`，**逐行 write+fsync** 到磁盘根 `/var/log/kc2.log`（跨复位保留）。
- 结果：最后一条 `6,1059,183435489,-,caller=T3457;wlan0: deauthenticating ... DEAUTH_LEAVING`；
  `grep` 全部里程碑/关键字（`Starting new kernel`/`Bye!`/`power down`/`kexec`/`SYS_RESTART`）**零命中**。
- 对照通道：
  - `ttyGS0`（USB gadget console，宿主 `/dev/ttyACM0`）跨不过 kexec —— 第一轮已证，本轮宿主 `cat` 也只到 `t=109.65s`（wlan 行）。
  - `tty0` 帧缓冲在掉电时熄灭。
- **判读（非定论）**：里程碑要么没来得及打印（掉电点在 `kernel_restart_prepare`/`syscore_shutdown`，即 **B1**），
  要么掉电快于用户态读取+落盘（B2/B3 也可能）。

---

## 5. 本轮排除项

| 项 | 结论 | 依据 |
|---|---|---|
| H2（次级 CPU offline 失败 → `BUG_ON`） | ❌ 排除 | 第一轮可逆 hotplug 7→1 全部 `psci: CPUx killed` 干净下线 |
| vk54 Image「dirty/坏」 | ❌ 排除为主因 | 干净重建的 vk58 仍 kexec 失败；且 vk46 镜像（任意版本）`fastboot boot` 通 |
| FSA4480/NFC config（`=y` vs 运行内核 `=m`）、禁 `typec-mux` 节点 | ❌ 非主因 | vk57 禁两片 FSA4480 仍失败；后证实失败是 initramfs bug（§2） |
| `msm_drm.dsi_display0` 显示参数 | ❌ 排除 | ABL 在 `fastboot boot` 时**同样注入**（`vk46-ram` 的 `/proc/cmdline` 已见） |
| `fastboot boot` 机制本身 | ✅ 正常 | `vk46-ram`（纯 RAM）与 `vk46.img`（持久）都成功启动、uname 不同可区分 |

补充：`vk54.img`（101 MB）等大镜像 `fastboot boot` 失败，与 slim（21 MB）失败**不同因**——后者已定位为 initramfs bug；大镜像未再深究。

---

## 6. 设备侧纪律与现象

- 每次实验前 `python3 /usr/local/sbin/slot-attr.py mark-successful b`（`boot_b` 维持 `0x7f`），本轮未再耗尽 retry。
- kexec 掉电后靠 **USB VBUS 自动开机**回 boot_b；无需手动长按（与第一轮"死挂需长按"不同，疑随内核/状态而异）。
- 设备在连续 `fastboot boot`/图形启动下偶发不稳（沿用 `PITFALLS` #106 观察）。

---

## 7. 剩余缺口与建议

- **定死 B1/B2/B3 只剩物理 UART**（`ttyGS0`/`tty0`/落盘 kmsg 均失败）。
- 结论：**kexec 快环继续停用**；迭代统一 `--boot`/`--flash`（与 `TASKS.md` 合并决议一致）。
- 资产：`out/boot-elden-vk58c-slim.img`（+ `-slim.manifest`）、`scripts/build-boot.sh` 修改、`initramfs/busybox-applets.txt`。

---

## 8. 引用

- 内核源码（本树）：`kernel/kexec_file.c:448/210`、`arch/arm64/kernel/machine_kexec.c:105`、`drivers/of/kexec.c`、`arch/arm64/mm/trans_pgd.c`。
- 项目内：`archive/topics/KEXEC-2026-10-05.md`、`KEXEC-ONDEVICE-2026-10-05.md`、`PITFALLS` #5/#94/**#107**、`TASKS.md` §4。
