# KEXEC-ONDEVICE-2026-10-05：kexec 上机取证（H2 排除 / vk54 / 设备不稳定，**已停手**）

> 承接 `archive/topics/KEXEC-2026-10-05.md`（主机侧分析）与 `MERGE-2026-10-05.md`（优先级裁决）。
> 本文是**过程证据**，只增不改；结论口径以 `TASKS.md`/`PITFALLS.md` 为准。
> **本轮曾短暂独占设备（用户授权 agent 执行 fastboot）；结尾因设备不稳定，用户指示停手。** 设备已回到 b 槽持久系统（vk47clean）。

---

## 0. 一句话结论

- **H2（次级 CPU offline 失败 → `BUG_ON`）已排除**（可逆 hotplug 实测）。
- **H4 触发条件成立**（运行期 VA=48 位、配置 `VA_BITS=52`）；已构建 vk54（2 行 trans_pgd 修复），`kexec -s -l` 装载 OK。
- vk54 下 **`kexec -e` 行为改变**：从旧版「死挂需长按」变为「**掉电 → ABL → fastboot**」，但**仍未成功换内核**。
- kexec 复位**扣 `boot_b` retry** → b 一度 UNBOOTABLE；已用 `slot-attr.py mark-successful b` **根治**（`0x3f→0x7f`）。
- 后续 `fastboot boot`（vk54 持久/纯 RAM）**反复使设备掉电重启**，**用户指示停手**，分支点仍未定位。
- **无存活 console** + **APSS 看门狗被永久禁用** ⇒ 分支点取证仍是未解项。

---

## 1. 设备勘察（只读，2026-10-05）

| 项 | 值 |
|---|---|
| 型号 / SN | Lenovo Legion Y700 Gen4（SM8750P）/ `HA2EXB0E`（U2） |
| 运行内核 | `7.2.0-debug-vk47clean-gbd114ca335e1`（b 槽持久，`/`=`/dev/sda17`=`linux17`） |
| 分区 | `sda17`=linux17 193 GiB；boot 分区在 `/dev/sde`（`boot_b`=`sde45`，96 MiB；`boot_a`=`sde12`） |
| CPU | 8 核 `0-7`；`cpuidle` 仅 state0/1 |
| **kexec config** | `CONFIG_KEXEC_FILE=y`、`CONFIG_KEXEC_CORE=y`；`kexec-tools 2.0.32`；`/sys/kernel/kexec_loaded` 存在 |
| **VA 配置** | `CONFIG_ARM64_VA_BITS=52`、`CONFIG_ARM64_LPA2=y`、`PGTABLE_LEVELS=5`、`KASAN` **未开** |
| **运行期 VA** | `/proc/cpuinfo` Features **无 `lpa2`** ⇒ 实际 **48 位**（命中 `1537e55728ec` 触发面） |
| **看门狗** | dmesg `Hard watchdog permanently disabled`（`/sys/class/watchdog/` 为空）⇒ 死挂不自复位 |
| ramoops | DT `ramoops@c2000000`（4 MiB）已注册为 kmsg 转储器；但 `record_size=0`、`max_reason=2`（不含 `KMSG_DUMP_SHUTDOWN`） |
| DP/NFC/CDSP | 无 `/sys/class/typec`；无 i2c-0（NFC）；`remoteproc` 仅 adsp（无 CDSP）— 与 vk53 待验证项一致 |
| console | 仅 `ttyGS0`（USB gadget，跳转必断）+ `tty0`（phoc 下不可见）；无物理 UART |

---

## 2. kexec 取证步骤 0 —— 可逆 CPU hotplug（**H2 排除**）

设备内，不碰 kexec：
```sh
for c in 7 6 5 4 3 2 1; do echo 0 > /sys/devices/system/cpu/cpu$c/online; done
cat /sys/devices/system/cpu/online      # -> 0
for c in 1 2 3 4 5 6 7; do echo 1 > /sys/devices/system/cpu/cpu$c/online; done
cat /sys/devices/system/cpu/online      # -> 0-7
```
原始日志：CPU7→CPU1 每条均 `psci: CPUx killed (polled 0 ms)`，随后全部 `Booted secondary processor`；恢复 `0-7`。
⇒ **`smp_shutdown_nonboot_cpus` 在 kexec 里会成功，H2 被排除。**

---

## 3. vk54 构建（H4 对照 + ramoops 取证 DT）

内核分支 `elden/vk54-kexec-va52`（基线 vk47 `bd114ca33`），两处改动：

1. **上游 `1537e55728ec`（2 行）** — `arch/arm64/kernel/machine_kexec.c`：
   ```c
   rc = trans_pgd_create_copy(&info, &trans_pgd,
                              _PAGE_OFFSET(vabits_actual), PAGE_END);   // 原为 PAGE_OFFSET
   ```
2. **ramoops 取证 DT** — `sm8750-lenovo-elden.dts` 的 `ramoops@c2000000`：
   `console-size 2M→1M`、`pmsg-size 2M→1M`、**新增 `record-size=2M`**、**新增 `max-reason=<5>`**（含 `KMSG_DUMP_SHUTDOWN`，捕获 `kernel_kexec()` 在 `machine_kexec` 前的最后日志，`kexec_core.c:1207`）。

产物：`out/boot-elden-vk54.img`（持久，101 MB）、`out/boot-elden-vk54-ram.img`（纯 RAM）。`UTS=7.2.0-debug-vk54-g2b5badef00fb-dirty`。
`kexec -s -l .../Image --command-line=...` **装载成功**（`/sys/kernel/kexec_loaded=1`）。

> 注：`--dtb=` 对 file-load 仍是空操作（见 `KEXEC-2026-10-05.md` §2.1）；新 DT 要生效必须先 `fastboot boot` 该 DTB 的镜像再 kexec。

---

## 4. `kexec -e`（vk54，从 vk47clean 运行）

- 命令：`scripts/kexec-boot.sh`（load vk54 Image + 运行 cmdline）→ `kexec -e`。
- **观测（用户）**：设备**直接关机**，随后**进入 fastboot**（不是旧版的死挂需长按）。
- 复位后 fastboot 读数：`current-slot=b`、**`slot-unbootable:b=yes`、`slot-retry-count:b=0`**。
  ⇒ kexec 复位被 ABL 记为一次 b 槽启动失败，retry 耗尽 → b 不可启动 → 停 fastboot（`PITFALLS` #71）。
- 用户手动重置失败标记后方能启动；随后正式根治：
  ```
  dd GPT 备份(/dev/sde 前/后 34×4096)  →  python3 slot-attr.py mark-successful b
  boot_b byte6: 0x3f -> 0x7f（active=1/succ=1/retry=7/unbootable=0，主备 GPT 均修 CRC）
  ```
- **结论**：H4 单修**未使 kexec 成功**；行为从「死挂」变为「复位」，但**分支点仍不可判定**（无 console / 无 pstore 记录）。

---

## 5. `fastboot boot` 投递 vk54 的尝试（不稳定）

| 镜像 | 结果 |
|---|---|
| `out/boot-elden-vk46-ram.img`（对照，纯 RAM 旧内核） | ✅ 成功：`uname ga923477be3a9`、`root=rootfs` ⇒ **`fastboot boot` 本身正常** |
| `bootslot-b/boot_b-clean.img` | ❌ `Failed to load/authenticate boot image: Load Error` |
| `out/boot-elden-vk54.img`（持久） | 报 `Booting OKAY`，但起来仍是 vk47clean（疑似未接管：图形变体不稳/回退 b 槽） |
| `out/boot-elden-vk54-ram.img`（纯 RAM，**无桌面**） | 用户观测：**掉电重启**（回 b 槽）；多次尝试均不稳定 |

补充事实：纯 RAM initramfs（`rootfs-overlaid-camera.cpio.gz` 的 `init`）在 `on_initramfs=1` 时**只 `respawn ttyGS0/tty1`、不启桌面**；并会起 `usb-gadget`+`usb0`+`udhcpd`+`sshd`。故「图形卡死」应来自**持久变体**，已登记 `PITFALLS` #106。
RAM 变体**无 `python3`/`eldroid-bootctl`**（有 `kexec`），进 fastboot 需绕道持久系统。

---

## 6. 停手与状态

- 用户指示：设备在重复 `fastboot boot`/图形启动下**不稳定（掉电重启）**，**停止进一步操作**。
- 停机时设备状态：**b 槽持久系统 vk47clean 正常**（SSH 通、`boot_b` succ=yes/retry=7），**未提交任何设备侧写入**（仅 GPT slot 属性 `mark-successful` 属修复性写入，已备份）。

---

## 7. 若再续（主机侧已就绪，上机待条件）

1. **存活 console** 仍是唯一缺口：物理 UART，或「无 GUI 环境 + `console=tty0` 拍屏」，或 **ramoops SHUTDOWN dump**（DT 已备，需稳定跑起带新 DT 的内核）。
2. **上机纪律**：任何 kexec/重启实验前先 `slot-attr.py mark-successful b`；每轮实验后检查 `boot_b` 属性。
3. **待定位**：`kexec -e` 分支点 B1/B2/B3（H2 已排除 ⇒ 重点 B3：relocation/KASLR/新内核早期）。
4. **可先做的对照**（无需 console）：`nokaslr`、`maxcpus=1`、同源内核，逐项二分——但每次可能复位，需用户在场物理回退。

---

## 8. 引用

- `archive/topics/KEXEC-2026-10-05.md`（主机侧分析）、`archive/topics/MERGE-2026-10-05.md`（优先级裁决）。
- `PITFALLS` #5（kexec）、#71（retry 耗尽）、#93（RAM/持久变体歧义）、**#106（图形启动即挂）**。
- 内核分支 `elden/vk54-kexec-va52`；`versions/vk-registry.tsv` vk54。
