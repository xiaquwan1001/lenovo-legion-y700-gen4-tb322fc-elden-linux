# TB322FC (elden) mainline Linux —— 交接文档

> 🧭 **本文已归档**（过程证据，不再更新）。现行文档集在仓库根：`INDEX.md` → `DEVICE.md`/`TASKS.md`/`RESOURCES.md`/`GAPS.md`/`ANDROID-COMPAT.md`/`RUNBOOK-BRINGUP.md`；
> 📇 入口 = `INDEX.md`；📟 **设备台账 = `DEVICE.md`**（本文§1 的“设备”是台账中的 **U1 = `HA2ABH62` 12+256**，
> 与同型号其他单元**物理等价**，仅容量不同）；🤖 安卓兼容方案 = `ANDROID-COMPAT-PLAN.md`。
> 本文最新结论在 **§23/§24/§25**（2026-09-30）；§17.2/§18.2/§19 为历史叙事（结论已并入相关小节）。

> 面向新会话：先读本文 + `复盘.md`（含每一步操作史与失败记录）。
> 工作区：`~/y700-elden/`。日期：**2026-09-30**。

---

## 0. TL;DR

**已在真机打通**：mainline Linux 7.2.0 → 显示(fbcon) / GPU(Adreno 830, Mesa Turnip) / 触屏 /
USB 串口+NCM 网+免密 SSH / 蓝牙 / ADSP / **充电** / **WiFi(PEACH，开机全自动、有独立互联网)** /
**Phosh 桌面（开机自动进、滑一下解锁、无需 PIN）** / **熄屏+唤醒（电源键双向）** /
**夜灯(gamma)** / **双马达触觉(AW86937 CONT)**。启动 **90s→~5s**。
**未通**：音频出声(需自编 tplg)、TF 卡(`sdhci-msm` 驱动/卡)；触摸唤醒不需要、不阻塞。

启动方式已升级为 **b 槽直启**（自签 AVB，见 §24）；`fastboot boot` 仅作保底 RAM 通道。
**Android 当前状态：完好**（a 槽 KSU + /data 146.4G FBE，见 §25 / `复盘-2026-09-30-日.md`）。

**当前基线 `out/boot-elden-vk19.img`**（无睡眠 + 夜灯 gamma + AW86937 触觉）；实时状态/待办见 **`INDEX.md`**。

---

## 1. 设备身份（= 台账中的 **U1**；其他同型号单元除容量外完全相同）

| 项 | 值 |
|---|---|
| 机型 | Lenovo Legion Tab **Y700 四代** = **TB322FC** = 代号 **elden** |
| SoC | **SM8750**（骁龙 8 至尊版 / 8 Elite），8 核，max 4.09 GHz |
| 内存 | 12 GB（可用 10.6 GB） |
| 屏幕 | LCD 1904×3040，双 DSI bonded + CPHY + DSC，CSOT PP8807HB1-1，Novatek **NT36536** |
| 存储 | UFS 234 GB（`sda1..sda16`） |
| 序列号 | `HA2ABH62`（fastboot/adb 都用它） |
| product | `elden_prc_wifi`（国行 WiFi 版） |
| hwboardid | `TB322FC_SM8750P_12+256` |
| 当前 build | `TB322FC_CN_OPEN_USER_Q00041.1_W_ZUXOS_1.5.10.259_ST_260611` |
| bootloader | 已解锁（`unlocked:yes`），`current-slot` 会因进 Android/TWRP 而变动 |

> ⚠️ 别和后来的 **Y700 无极**（8 Elite Gen5 / OLED，2026-08 发布）混淆，那是另一台机。

---

## 2. 主机环境

| 项 | 值 |
|---|---|
| 主机 | `5700g-x8664`，Ubuntu 26.04 LTS |
| 代理 | `http://127.0.0.1:7897`（http/https/socks）已在 env |
| 用户组 | `xuqianhui1001` 已在 `dialout`（但**当前 shell 会话组是旧的**，串口常需 `sudo chmod 666 /dev/ttyACM0`） |
| 无 | passwordless sudo；unshare 用户命名空间被禁（`无权限操作 /proc/self/uid_map`） |
| 已装 | `gcc-aarch64-linux-gnu`(15.2.0) flex bison libssl-dev libelf-dev qemu-user qemu-user-binfmt |

---

## 3. 工作区布局（`~/y700-elden/`）

```
linux -> geekidos-linux     # ★ 可编译内核树：GEEKiDoS/linux 分支 v7.2-elden (Linux 7.2.0)
geekidos-linux/             #   (2.1G)
Y700-elden-linux/           # xiaobai-Lethe 参考仓库（.config / project 脚本 / 部分 DTS）
rootfs/                     # Alpine rootfs 构建（脚本 + alpine/ 树 + firmware）
scripts/                    # configure-elden.sh / build-kernel.sh / build-boot.sh
initramfs/                  # 最小 busybox initramfs（串口版）
tools/mkbootimg/            # AOSP mkbootimg.py
twrp/twrp.img               # TWRP-3.7.1-16-TB322FC portrait (100MiB，sha 已校验)
backup/                     # ★ 关键备份
  dtbo_a.img                #   stock dtbo_a (32MiB) —— 还原 Android 用
  rawdump.img               #   UFS rawdump 分区回读 (256MiB，含早期 dmesg)
  elden-dump.txt            #   从 rawdump 提出的 dmesg
  fw/gen80000_{zap.mbn,sqe.fw,gmu.bin,aqe.fw}  # ★ 设备 vendor 的 GPU 固件
  libgallium-26.1.6.so.orig / libvulkan_freedreno.so.orig  # Mesa 原版备份
out/                        # 打包产物（见 §6）
复盘.md                      # ★ 完整操作史 / 失败记录 / 根因
```

---

## 4. 构建管线

### 4.1 内核
```bash
cd ~/y700-elden
bash scripts/configure-elden.sh      # 生成 .config（★ 见 §5 的 olddefconfig 坑）
bash scripts/build-kernel.sh         # ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- make Image.gz dtbs
```
- DT：`linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`（已按 §5 修复）
- 产物：`linux/arch/arm64/boot/Image.gz`、`.../sm8750-lenovo-elden.dtb`

### 4.2 Alpine rootfs（免 sudo，用 qemu binfmt + apk --root）
```bash
cd ~/y700-elden/rootfs
export QEMU_LD_PREFIX="$PWD/alpine"
Q() { qemu-aarch64 -L "$PWD/alpine" ./alpine/sbin/apk --root "$PWD/alpine" --arch aarch64 --no-cache "$@"; }
# 装包（示例）
Q add openssh bash tmux strace vulkan-tools mesa-vulkan-freedreno
# 打包
( cd alpine && find . -print0 | cpio --null -o -H newc --owner=0:0 2>/dev/null | gzip -6 ) \
  > ~/y700-elden/out/rootfs.cpio.gz
```
- busybox trigger 会因 unshare 被禁而报错，**可忽略**。
- SSH host key 用**本机** `ssh-keygen` 生成（与架构无关）到 `alpine/etc/ssh/`。
- `alpine/etc/shadow` 里 root 密码字段留空 + `sshd_config.d/00-noauth.conf` 开 PermitEmptyPasswords。

### 4.3 打包 boot.img
```bash
cd ~/y700-elden
CMDLINE="console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel printk.devkmsg=on panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0"
python3 tools/mkbootimg/mkbootimg.py --header_version 2 --os_version 15.0.0 --os_patch_level 2025-08 \
  --kernel linux/arch/arm64/boot/Image.gz --ramdisk out/rootfs.cpio.gz \
  --dtb linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb --cmdline "$CMDLINE" \
  --base 0x00000000 --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 \
  --second_offset 0x00f00000 --tags_offset 0x00000100 --dtb_offset 0x01f00000 \
  --pagesize 4096 -o out/boot-elden-X.img
```
- **boot.img 必须 < ~96 MiB**（`boot_a` = 0x6000000；超过会 `Bad Buffer Size`）。

---

## 5. 关键根因（全部已修，改的都是 DT / config）

| # | 根因 | 修复 |
|---|---|---|
| 1 | ABL 把 stock `dtbo` 的 76 个 overlay 覆到 mainline DTB → 卡 logo | 写 4KB 全零"假 dtbo" 到 **两个槽** `dtbo_a`+`dtbo_b` |
| 2 | `reserved-memory` 节点名 `splash-region`（连字符）→ ABL 找不到 `splash_region` 就**关闭显示** | 改名 `splash_region`（DTS 注释本就写着 `Please 's/-/_/'`） |
| 3 | `CONFIG_PHY_NXP_PTN3222=m`（eUSB2 repeater 是模块、RAM 无模块）→ M31 PHY 起不来 → 无 USB | 改 `=y` |
| 4 | `CONFIG_BACKLIGHT_AW99706` 未设置 → panel `Failed to get backlight` | 改 `=y` |
| 5 | `&mdss_dp0 { status="okay" }`：DP 是无 ADSP 就永远 defer 的 **DRM component** → `msm_drm_bind` 卡死 → 无 card0 | 改 `status="disabled"` |
| 6 | GPU zap shader 必须**设备签名**版（TZ 校验），linux-firmware 版被拒 `-EINVAL` | 从 TWRP 拉 `/vendor/firmware/gen80000_zap.mbn` |

### ⚠️ 三个务必记住的坑
1. **`make olddefconfig` 会把 `CONFIG_ARCH_QCOM` 整行删掉！** 改 config 后**不要**跑 olddefconfig；用 `scripts/config -e/-d` 后直接 `make`，并每次 `grep ^CONFIG_ARCH_QCOM=` 验证。这个坑曾让十几轮 diag 内核全是废配置。
2. **A/B 槽**：进过 Android/TWRP 后 `current-slot` 可能 a→b，假 dtbo 必须**两个槽都写**。排查：`fastboot getvar all | grep current-slot`。
3. **Mesa chip-id 补丁不要打**：作者 `patch-mesa-a830.sh` 把 wildcard `...44050000`→`...44050001`；本机内核报 `0x44050000`（DRM 给 Turnip 的 chip_id = `0xE844050000`），**原版**才匹配，打补丁反而 unsupported。

---

## 6. 可用产物（`out/`）

| 镜像 | 内容 | 大小 | 用途 |
|---|---|---|---|
| **`boot-elden-vk4.img`** | vk3 + **`/persist` 自动挂载 sde79** | 74 MiB | **当前最强基线，日常用** |
| `boot-elden-vk3.img` | vk2 + 触屏/蓝牙/ADSP 固件内建 + kexec-tools + probe.sh | 74 MiB | 上一版 |
| `boot-elden-vk2.img` | 内核 + Alpine + Turnip + GPU/ADSP 固件 | 59.8 MiB | 旧基线（无触屏/BT 固件） |
| `boot-elden-probe.img` | vk2 + 固件采集探针 | 77 MiB | 环境采集 |
| `boot-elden-fixed4.img` | 内核 + 最小 busybox initramfs | 18.4 MiB | 只要串口/救砖 |
| `dtbo-dummy.img` | 4KB 全零 | 4 KiB | 绕过 ABL overlay |
| 其余 `diag*/gpu*/vk*.img` | 历史调试版 | — | 可留档 |

**启动**：
```bash
fastboot flash dtbo_a out/dtbo-dummy.img
fastboot flash dtbo_b out/dtbo-dummy.img     # ★ 两个槽
fastboot boot out/boot-elden-vk2.img
```
**访问**：
```bash
sudo bash ~/y700-elden/elden-net.sh          # 配主机 enx021e5eede102 = 192.168.7.2/24
ssh -o StrictHostKeyChecking=no root@192.168.7.1
# 串口另可: sudo chmod 666 /dev/ttyACM0; stty -F /dev/ttyACM0 115200 raw; cat /dev/ttyACM0
```

---

## 7. 常用运维命令

| 目的 | 命令 |
|---|---|
| 进 EDL (9008) | `adb reboot edl`（Android）或 `fastboot oem edl`（fastboot） |
| EDL 读写分区 | `~/y700-elden/qdl/build/qdl -s ufs ~/下载/tb322fc/xbl_s_devprg_ns.melf read/write <分区名> <文件>` |
| 清 fastboot 脏状态 | `fastboot reboot bootloader`（失败会报 `Load Error` 时用） |
| 物理重启到 fastboot | 长按电源 10–15s，再 **音量减 + 电源** |
| 恢复 Android | **先切槽**：`fastboot --set-active=a` + `fastboot reboot`（见 §20，多数情况这一条就好）；dtbo 坏了才 `fastboot flash dtbo_a/b backup/dtbo_a.img` |
| 从平板重启（Alpine） | `ssh root@192.168.7.1 'sync; reboot'`（约 50s 到 fastboot） |
| 进 TWRP | 用户已会：`adb reboot bootloader` 后刷/进 recovery |

---

## 8. 设备当前状态

> 🗄️ **本节旧记录已归档**。实时状态与待办请看 **`INDEX.md` §0/§4**。

（存档 2026-09-28 23:00）基线 vk3；`current-slot=b`；`dtbo_a/b` = 假 dtbo；主机 NM `elden-usb` 已建
（`enx021e5eede102=192.168.7.2`）；迭代 `cycle.sh <img>` / `cycle.sh --soft`。

---

## 9. 下一步

> 见 **`INDEX.md` §4 待办看板**。要点：**GUI 桌面**（Phosh 卡 glycin 沙箱 bug）、**扩/缩分区**、
> **TF 卡**（`sdhci-msm`）、**音频出声**（自编 tplg）、WiFi 长稳。
>
> （本节旧候选已基本完成：持久化到 UFS ✅、触屏 ✅、WiFi ✅；仅剩 **音频** 与 **165Hz**。）

### 音频推进线索（仍未通）
- 目标：自编 `Lenovo-Y700-Gen4-tplg.bin`（AudioReach 图：MI2S → aw88461 ×2）。
- 参考 vendor `/etc/MM_audio_playback_capture_v2.0.cfg`；详见 §15。

### 165Hz（有上游补丁）
- 作者 `experiments/165hz-mode-table.patch`；已知触发 DSI FIFO 报错风暴（120Hz 正常）。

---

## 10. 关键参考

- 上游：`GEEKiDoS/linux` 分支 `v7.2-elden`；`xiaobai-Lethe/Y700-elden-linux`
- TWRP：`polygraphene/android_device_lenovo_TB322FC`（release 2026-04-04-2）
- EDL 包：`~/下载/tb322fc/`（`xbl_s_devprg_ns.melf`、rawprogram/patch XML、ABL 等）
- 详细操作史/失败记录：`~/y700-elden/复盘.md`

---

## 11. kexec（2026-09-28 实测可用）★

内核已内建：`CONFIG_KEXEC=y`、`CONFIG_KEXEC_FILE=y`、`CONFIG_EFI_STUB=y`，`kexec_load_disabled=0`。
在设备 Alpine 内（装了 `kexec-tools`）：

```
kexec -s -l /boot/elden-Image --dtb=/boot/elden.dtb --reuse-cmdline   # kexec_file_load -> FILE_LOAD_OK
kexec -l    /boot/elden-Image --dtb=/boot/elden.dtb --reuse-cmdline   # kexec_load      -> LOAD_OK
```

**`kexec -l`/`-s -l` 装载成功，但 `kexec -e` 执行会黑屏挂死**（新内核未起、无 USB gadget，需物理重启）。
arm64/Qualcomm 平台限制（跳转后无法复位 GIC/PMIC/次级 CPU）。
- 注意：`kexec -l` 需要**未压缩的 Image**（用 `gzip -dc Image.gz`）。
- **结论：kexec 不能用作内核热切换。** 软重启走 `reboot`（回 ABL→fastboot）或 `fastboot boot` 链。

## 12. UFS 分区 / 固件资产

- LUN 映射：`sda`=LUN0（含 `super`=sda10，22.0GiB 动态分区）、`sdb`=LUN1(xbl)、`sdc`=LUN2、`sdd`=LUN3(cdt/ddr)、`sde`=LUN4(uefi/aop/tz/modem/bluetooth/dsp/boot/dtbo…)。
- **`super` 动态分区可用 losetup 直接读**（无需 dm/lpunpack）：
  从 `sda10` 前 8MiB 解析 LP 元数据 → 得到各分区 extent 的 `{offset,len}`（单位 512B 扇区）→
  `losetup -o <off> --sizelimit <len> /dev/loop0 /dev/sda10 && mount -o ro /dev/loop0 /mnt`。
  已验证 `vendor_a` 挂载成功。映射表：`probe/result/lp-map.txt`。
- 固件资产目录：`backup/fw/`（`vendor/ modem/ bluetooth/ dspso/` + `gen80000_*`），说明见 `backup/fw/README.md`。
- 本轮采集产物：`probe/result/`（`kernel.config`、`devicetree.dts`、`dmesg.txt`、`partitions.txt`、`lp-map.txt`、`kexec-reboot.txt`）、
  `probe/fw2/*.tgz`、`probe/vendor-fw.tgz`、`probe/super-lp.bin`。
- 探针镜像：`out/boot-elden-probe.img`（≈77MiB，含 kexec-tools + 自动跑 `probe.sh`）。

## 13. 减少物理重启的方法论

见 `BATCH_PLAN.md`。要点：A 主机离线 → B 系统内 SSH → C 换内核；kexec 把 C 降成 B；持久 root 是最高杠杆。

## 14. 持久分区 `linux`（`/dev/sde79`，2.3 GiB ext4）★ 2026-09-28

**零 GPT 手术、零数据丢失**得到一块设备内持久盘：
- LUN4（4 GiB）尾部本就是 Qualcomm 占位分区 `last_parti`（序号 79，425236–1048570，约 2.4 GiB），
  **但其 Type-UUID 是全零 → 内核解析器跳过，不生成设备节点**。
- 修复：`fdisk /dev/sde` → `t 79` → 类型 `Linux filesystem`（原为 unknown/零）→ `w`。
  之后内核自动生成 `/dev/sde79`，**重启后依然存在**。
- `mkfs.ext4 -F -L linux /dev/sde79` → 2.3 GiB，挂载读写 OK，重启后数据保留。
- GPT 主备表快照：`backup/sde-gpt-head.bin` / `backup/sde-gpt-tail.bin`（改动前）。
- 注意：只改了第 79 条的类型 GUID，名称仍是 `last_parti`（cosmetic），**未动任何现有分区数据**；
  ABL 按名字读分区，不受影响。

用途：可挂 `/persist`，或引导成持久 root（`root=/dev/sde79` 或 initramfs `switch_root`）。
引导链已验证：`cycle.sh --soft`（Linux→fastboot ~15s）→ `cycle.sh <img>`（fastboot→Linux ~78s）。

## 15. 音频状态（2026-09-28）

| 环节 | 状态 | 关键资产 |
|---|---|---|
| ADSP | ✅ up | `qcom/sm8750/adsp.mdt`+`adsp.b*` |
| 功放 aw88461 ×2 | ✅ probe 成功 | **`awinic/y700-gen4-speakers.bin` = vendor `firmware/aw882xx_acf.bin`（内含 aw88461 ACF）** |
| 声卡 card0 | ✅ 创建（MM1/2 播放, MM3/4 录音） | `qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin.zst`（暂用 MTP 顶替） |
| 实际出声 | ❌ | tplg 缺 **MI2S** 后端（MTP 只有 WCD Codec-DMA）。需**自编 tplg** |
| 触觉 | ❌ | `aw86927` 与 `aw8697_haptic.bin` 格式不符 |

参考：vendor `/etc/MM_audio_playback_capture_v2.0.cfg`（安卓 AudioReach 用例图）。
vk5 已内建上述固件（`out/boot-elden-vk5.img`）。

## 16. 持久 root（从 `/dev/sde79` 启动）★ 2026-09-28

**已打通**：内核从 boot.img 的 initramfs 起，initramfs 内的 `init` 检测到 cmdline 有
`elden_root=` → 挂载该分区 → `switch_root` 到磁盘 `/init`。之后系统完全跑在 UFS 上。

- cmdline 加 `elden_root=LABEL=linux`（或 `UUID=...` / `/dev/sde79`）。
  打包用 `EXTRA_CMDLINE="elden_root=LABEL=linux" ./pack.sh <rootfs> <img>`。
- `init` 用 `stat -f -c %T /` 区分 initramfs(rootfs/tmpfs) 与磁盘(ext4)：
  - initramfs 模式：挂 `/persist`(sde79)、按 `elden_root` 做 switch_root、跑探针；
  - 磁盘模式：以上全部跳过（避免递归/覆盖根）。
- 磁盘 root 内容：把 `rootfs/alpine` 整树复制到 sde79（**注意属主**，见下）。
- 验证：`/` = `/dev/sde79 ext4`；ADSP/BT/触屏开机自动；sshd 自动；数据跨重启保留。
- 新基线镜像 **`out/boot-elden-vk7.img`**（77 MiB，含 `elden_root=LABEL=linux`）。

### ⚠️ 属主坑（必记）
用 `tar czf - -C rootfs/alpine .` 拷贝会**保留主机 uid=1000**，导致 sshd 以
`/var/empty must be owned by root` 拒绝启动（表现为 ping 通但 SSH `connection refused`）。
修复：
- 拷贝时用 `tar czf - --owner=0 --group=0 -C rootfs/alpine .`（或 cpio `--owner=0:0`），或
- 启动后 `find / -xdev -uid 1000 -exec chown 0:0 {} +`；
- init 已内置防御：启动 sshd 前 `chown 0:0 /var/empty; chmod 755 /var/empty`。

### 串口救急（SSH 不可用时）
`/dev/ttyACM0` 是 CDC-ACM 控制台（getty on `ttyGS0`，直接 shell）：
```bash
stty -F /dev/ttyACM0 115200 raw -echo
{ printf '\r'; sleep 0.5; printf '<cmd>\r'; } > /dev/ttyACM0 &
timeout 5 cat /dev/ttyACM0
```

## 17. 图形/桌面 与 WiFi（2026-09-28 夜）

### 17.1 图形 & Wayland 桌面 ✅（持久 root 上已装，开机自启）
- **GL/GLES 出画面**：`kmscube` → `OpenGL ES 3.2 Mesa 26.1.6`，`renderer: Adreno (TM) 830`，`vendor: freedreno`（GBM+EGL+GLES 全链路）。
- **Wayland 桌面（weston 14.0.2）开机自启**（2026-09-29 打通）：
  - `/persist/init` 在磁盘 root 模式（`on_initramfs=0`）下调用 `/usr/local/sbin/start-desktop.sh`
    （`seatd -g root` + `weston --backend=drm --idle-time=0` 循环守护），取代 tty1 getty；RAM 模式仍保留 getty。
  - `/persist/etc/xdg/weston/weston.ini`：`[core] require-input=false, idle-time=0`；`[shell] background-color`；
    `[autolaunch] path=/usr/bin/weston-terminal`（开机即拉起终端）。
  - 字体：`apk add font-dejavu`（否则 weston-terminal 无字形）。
  - **实测（vk7 磁盘 root）**：`ps` 有 weston + weston-terminal + weston-desktop-shell + weston-keyboard；
    DRM `plane-0` = `allocated by weston`、`crtc-0`、`XR24 1904x3040` → 桌面确实在屏幕上扫描输出。
- ⚠️ **weston 14 不再接受 `--tty=1`**（`fatal: unhandled option`），用 `--backend=drm --idle-time=0` 即可。
- ⚠️ **曾经的"瘦身"坑**：早前手删 Mesa/LLVM 文件但保留 apk DB，导致 `apk add` 不恢复。
  修复：`apk fix <pkg>`（重装缺失文件）。
- 手动跑桌面（调试用）：
  ```bash
  export XDG_RUNTIME_DIR=/run/weston; mkdir -p /run/weston; chmod 700 /run/weston
  seatd -g root &        # 或 libseat 以 root 直连
  kmscube                # GL 测试
  weston --backend=drm --idle-time=0    # ★ 无 --tty
  ```
- **截图受限**：`weston-screenshooter` 报 `unauthorized`（capture 协议需 shell 授权，headless 不通）。
  验证桌面改用 `cat /sys/kernel/debug/dri/0/state` 看 plane 的 `allocated by = weston`。

### 17.2 WiFi（ath12k / PEACH）⏳ 卡在固件

> ❌ **本节结论已被 §21 推翻（2026-09-29）**：WiFi **已打通**，卡点不是固件/BDF，
> 而是缺 `qdss_trace_config.bin` + 开机首探竞态。新的唯一未决 = **稳定性**。
> 下面保留的是当时的调查过程，仅供追溯。
驱动路径 `ath12k/PEACH/hw2.0/` 需要：`amss.bin`、`m3.bin`（或 `firmware-2.bin`）、`aux_ucode.bin`、`tmel.bin`、`board-2.bin`。
- linux-firmware 只有 **generic WCN7850** 的 `amss.bin`/`m3.bin`/`board-2.bin`；PEACH 的 `aux_ucode.bin`/`tmel.bin` 取自 vendor（`peach/aux_ucode20.elf`、`tmel_peach_20.elf`）。
- **现状**：MHI/BHI 阶段 `Image transfer failed, ERROR_CODE 0xef0e0002 → MHI did not load image over BHI (-5)` →
  **generic M3 与 PEACH 不匹配**，WCN 拒绝。vendor 是 qcacld 方案，无 ath12k 格式的 `m3.bin`/`firmware-2.bin`；linux-firmware 也无 `ath12k/PEACH/`。
- **结论**：WiFi 需 **PEACH 专用 ath12k 固件**（Qualcomm 发布），本地/上游暂无 → 暂挂。

### 17.3 有用的基建：设备直连 apk
主机中继代理后，设备可在线装包（持久 root 上直接生效）：
```bash
# 主机: socat TCP-LISTEN:7898,fork,reuseaddr TCP:127.0.0.1:7897   # 0.0.0.0:7898 -> 本地CN代理
# 设备: /etc/apk/repositories 改为 http:// 源（避开缺 CA 的 TLS 问题）
export http_proxy=http://192.168.7.2:7898 https_proxy=http://192.168.7.2:7898
apk update && apk add <pkg>
```

## 18. WiFi(PEACH) 大突破 + 显示问题（2026-09-28 深夜）

### 18.1 PEACH 固件命名（反提取自 vendor，关键！）
`ath12k/PEACH/hw2.0/` 需要的文件与 vendor `modem/image/peach/` 的对应关系（PEACH=PCI 0x110e，**不是** WCN7850）：

| ath12k 需要 | vendor 文件 | 说明 |
|---|---|---|
| `m3.bin` | **`peach/phy_ucode20.elf`** | ELF e_machine=0x03，与 linux-fw m3.bin 同类；**换上后 MHI 进入 mission mode、固件启动成功** |
| `amss.bin` | `peach/amss20.bin` | ELF e_machine=0x28(ARM) |
| `aux_ucode.bin` | `peach/aux_ucode20.elf` | |
| `tmel.bin` | `image/tmel_peach_20.elf` | TME-L |
| `regdb.bin` | `peach/regdb.bin` | |
| `board-2.bin` / `board.bin` | `peach/bdwlan.eXX` / `bdwlan.elf` | **BDF，待转换/匹配** |

换上后 dmesg 出现：`chip_id 0x2 ... soc_id 0x40210200`、`fw_version WLAN.GNG.1.0-03869-...`、
`qmi TME-L power-on hardware-restricted (stock-compatible, continuing)`（该内核含 PEACH 专用 workaround）。
→ **固件链路已通**。

### 18.2 当前唯一卡点：BDF / board 文件

> ❌ **本节结论已过时（2026-09-29）**：真正卡点是 `qdss_trace_config.bin`，不是 BDF。
> 见 §21。以下为当时（错误）推断，保留追溯。
```
failed to fetch board data for bus=pci,vendor=17cb,device=110e,subsystem-vendor=17cb,
  subsystem-device=110e,qmi-chip-id=2,qmi-board-id=255 from ath12k/PEACH/hw2.0/board-2.bin
failed to fetch board.bin from PEACH/hw2.0
qmi failed to load board data file:-2
```
- linux-firmware 的 generic `board-2.bin` 无 PEACH 条目；`board_api1_only=true` 会回退找 `board.bin`。
- 解决方向：用 **ath12k-bdencoder**（qca-swiss-army-knife）从 vendor `bdwlan.eXX`/`bdwlan.elf` 生成 PEACH 的 `board-2.bin`；
  或直接给 API1 的 `board.bin`（raw BDF）。

### 18.3 显示问题（独立 bug）
- 现象：**过了 logo 后只有背光、无文字**。
- 串口刷 `drm_crtc_wait_one_vblank+0x19c/0x220` 的 call trace（vblank 等不到 → DPU 不翻页 → 无 console）。
- 疑与 DSI/panel vblank 中断丢失有关（可能间歇）。之前掉 fastboot 可能也由此刷屏/watchdog 引发。
- 待办：单独排查 DRM vblank（可能在多次 KMS 操作后状态异常；冷启可恢复）。

## 19. 重启 / 内核交接流程（2026-09-28 深夜调查）

**现象**：从主线 Linux `reboot` 后，设备每次都停在 **fastboot**。

**调查结论**：
- **不是 `misc`**：`misc`(sda7) 里确实是 Android 的 `bootonce-bootloader`，但清零后 `reboot` 仍进 fastboot。
- **是 ABL 对 Android 槽的 AVB 校验失败**：ABL 的 UEFI 日志（`logfs`=`/dev/sde68` 里的 `UefiLog1.txt`）显示
  `boot_b: Public key used to sign data does not match key in chain partition descriptor`、
  `dtbo_b: Hash of data does not match digest in descriptor` → ABL 无法验证启动 Android 槽 → 回退 **fastboot**。
- **主线 reboot 机制**：`machine_restart` → **PSCI SYSTEM_RESET**；无 `reboot-mode` DT 节点（`/sys/kernel/reboot-mode` 不存在），
  因此**不向 ABL 传递启动原因**。ABL 只能按 `misc`/槽状态/AVB 自行决定。
- **交接方式**：`fastboot boot <img>`（RAM，跳过 AVB）是可用的内核交接路径。
- ABL 日志还确认：`Dtbo hdr magic mismatch 0, with D7B7AB1E` —— **ABL 认出了我们的假 dtbo 并跳过 overlay**（这正是我们要的效果）。

**可用路径 / 候选**：
1. 保持 `reboot → fastboot → fastboot boot` 的软链（`cycle.sh --soft` / `cycle.sh <img>`），不按电源键。
2. **双槽直启**（候选）：把我们的 boot.img 写进某槽的 `boot`，并给该槽配假 `dtbo`，`fastboot set_active` 切换；
   但 ABL 会用 AVB 校验未签名镜像 —— 需旁路验证或刷 permissive vbmeta。
3. **AVB 公钥资源**：酷安提到该产品线 AVB 签名有**现成公开资源**（公钥可获取），可作为 verified-boot / 双槽直启的探索路径（日后需要时再用）。

**fastboot 操作注意**：该机 fastboot 对**批量脚本/连续命令响应差**，易卡；一律拆成**单条简单命令**；
`Write to device failed` 时先单条 `fastboot reboot bootloader`，等待后再单条 `fastboot boot`。（`cycle.sh` 已按此简化。）

---

## 20. Android 卡动画根因 = 槽漂移（2026-09-29）★★

**现象**：主线折腾后 Android 卡在启动动画（动画还在动、机身发热、数据没坏），一度以为引导链签名坏了/要清数据。
**真相**：只是 `current-slot` 漂到了 **b**，而 b 槽引导链与系统不配套；**并不是砖**。

**一键修复**：
```bash
fastboot --set-active=a
fastboot reboot
```
→ 完好进 Android。**所以“进不去 Android”第一步永远是切另一个槽，别急着重刷/清数据。**

### 20.1 免解 BL root / 重签包资产：`restore-259/`

- 来源：社区（123pan/B站「悲伤的压缩包」）针对 build **`ZUXOS_1.5.10.259_260611_PRC`** 的重签包 + KSU。
- 原理：**改过的 `abl` + 自签 `vbmeta`/`vbmeta_system`**（让系统以为仍是原厂签名）；**abl 与 vbmeta 必须配套**。
- 重签包：`abl_a.img`(改) / `boot_a.img`(=官方 boot) / `recovery_a.img` / `vbmeta_a.img` / `vbmeta_system_a.img`。
- KSU：`init_boot.img` / `vbmeta.img` / `KernelSU_v3.2.5_*.apk`。
- 流程与回退/EDL 救砖见 **`restore-259/README.md`**。
- 原厂固件目录 `~/下载/tb322fc/` **不完整**（缺 dtbo/vendor_boot/recovery/super），不能全量恢复。
- 配套 Windows 工具在 `y700四代工具/`（紫罗兰工具箱/高通工具箱/刷机匣/解锁工具）。

---

## 21. WiFi(PEACH/WCN7861) 打通 + USB 离线装包（2026-09-29）★★

### 21.1 WiFi 唯一缺口：`qdss_trace_config.bin`

**本机内核的 PEACH 定制 ath12k 驱动在 TME-L 之后强制加载 QDSS trace 配置**：
`drivers/net/wireless/ath/ath12k/qmi.c: ath12k_qmi_wlanfw_qdss_config_send()`，文件常量
`ATH12K_QMI_QDSS_CFG_FILE = "qdss_trace_config.bin"`（在 `ath12k/PEACH/hw2.0/` 下查找）。
缺它 → `failed to load exact Peach QDSS config: -2` → `qmi failed to download QDSS config: -2` → **不建网卡**。

**修复**：把 vendor `backup/fw/modem/image/peach/qdss_trace_config_v2.cfg` 放到
`/lib/firmware/ath12k/PEACH/hw2.0/qdss_trace_config.bin`。

`ath12k/PEACH/hw2.0/` 完整 7 件套：

| ath12k 需要 | vendor 来源 |
|---|---|
| `amss.bin` | `peach/amss20.bin` |
| `m3.bin` | `peach/phy_ucode20.elf` |
| `aux_ucode.bin` | `peach/aux_ucode20.elf` |
| `tmel.bin` | `image/tmel_peach_20.elf` |
| `board-2.bin` | 已有（含 PEACH 条目） |
| `regdb.bin` | `peach/regdb.bin` |
| **`qdss_trace_config.bin`** | `peach/qdss_trace_config_v2.cfg` ★ |

打通后 dmesg 顺序：`chip_id 0x2 ... board_id 0xff soc_id 0x40210200` → `fw_version WLAN.GNG.1.0-03869` →
`qmi TME-L power-on hardware-restricted (stock-compatible, continuing)` → `qmi AUX_UC request succeeded` →
`qmi FW_INIT_DONE ... soft_sku=0x1` → **`wlan0` 建立**（`iw scan` 见 ustcnet/eduroam/ustc-guest）。

### 21.2 开机竞态：首探 MHI `-110`，需延迟重试 bind ★

**现象**：开机 ath12k 在 ~1.9s 就 probe，WCN 未就绪 → MHI `POWER_ON` 等 90s 超时 `-110`；
`probe with driver ath12k_wifi7_pci failed with error -110`，PCI 设备**留未绑定**。系统起来后
对**未绑定**设备 `echo 0000:01:00.0 > /sys/bus/pci/drivers/ath12k_wifi7_pci/bind` → 固件/ BDF 全过、建 `wlan0`。

**修复脚本**：`scripts/ath12k-retry.sh`（设备上 `/usr/local/sbin/ath12k-retry.sh`），已由 `/init` 在磁盘 root 模式后台拉起。
逻辑：轮询，若 `/sys/class/ieee80211/phy0` 不存在且设备**无 driver**，才 bind；**绝不 unbind/remove**。

⚠️ **禁区（已踩两次，各重启一次）**：对**在线**的 ath12k 设备 `echo 1 > .../remove` 或 `.../unbind` → **挂内核**。
只能对「已 probe 失败、未绑定」的设备 bind。
⚠️ **稳定性存疑（未解决）**：手动 bind 成功、扫描正常后，运行一段时间内核挂掉→重启（原因待查：ath12k 固件断言 vs USB gadget）。

### 21.3 充电正常（无需修电源驱动）

`/sys/class/power_supply/qcom-battmgr-bat`：`STATUS=Charging`、`CAPACITY=22`、
`CURRENT_NOW=-717000`（DT 有 `qcom,battery-current-inverted`）；`qcom-battmgr-usb` `ONLINE=1`、5.65V/403mA。
→ 主线**能充电**；此前“插着净掉电”是 **PC USB 口供电不足**（SDP ~400mA），非驱动问题。

### 21.4 USB 离线装包流程（避开设备侧网络）★

主机（Ubuntu + qemu-user）用 rootfs 里的 apk 抓 aarch64 包：
```bash
cd ~/y700-elden
export QEMU_LD_PREFIX="$PWD/rootfs/alpine" http_proxy=http://127.0.0.1:7897
qemu-aarch64 -L rootfs/alpine ./rootfs/alpine/sbin/apk --root rootfs/alpine --arch aarch64 \
  --no-cache fetch --recursive -o pkgs <pkgs...>
scp pkgs/*.apk root@192.168.7.1:/tmp/pkgs/
# 设备侧：
apk add --allow-untrusted --no-network /tmp/pkgs/*.apk
```
坑1：设备 `/etc/apk/world` 若残留**未安装**的包（本次是掉电中断的 `epiphany`），任何 `apk add` 都会去补它
整条依赖树（实测 151 包）→ 先从 world 摘掉。
坑2：设备侧 apk 走 USB+代理很慢（单次上百 MB 容易超时）→ 大包一律走本流程。

### 21.5 GUI 现状

- 持久 root 上 weston 14 已开机自启（`/init` → `start-desktop.sh`）。
- **磁盘约束**：持久 root `/dev/sde79` 仅 **2.3 GiB**（用了 478 MiB，余 ~1.7 GiB）。
  - Phosh ≈ **904 MiB / 596 包** → 能装下。
  - Plasma Mobile 6.6.6 ≈ **1622 MiB / 597 包** → **塞不下**（除非扩根分区/userdata）。
- Alpine latest-stable 可选：`phosh 0.55`、`plasma-mobile 6.6.6`、`gnome-shell 50.3`、`sway`、`xfce4`、`weston`。
- 触屏口碑：大屏平板 Plasma Mobile > GNOME > Phosh；但对 Y700 这种手机型竖屏，Phosh 最省资源且最稳（wlroots 已在 weston 上验证）。

---

## 22. WiFi 开机全自动 + GUI 尝试（2026-09-29 收尾）★

### 22.1 开机全自动 WiFi（已实测冷启验证 ✅）

`/init` 末尾并行拉起两个脚本（都已装到持久 root）：

1. **`/usr/local/sbin/ath12k-retry.sh`** —— 解决内建 ath12k 首探失败留下的未绑定设备：
   - `sleep 12` 后循环；若 `phy0` 不存在且 PCI 设备**无 driver**，则 `echo 0000:01:00.0 > /sys/bus/pci/drivers/ath12k_wifi7_pci/bind`。
   - ⚠️ **`bind` 必须写设备名**（`0000:01:00.0`），**不能写设备路径**——写路径内核直接拒绝、不触发 probe（这个坑让本脚本静默失效很久）。
   - 只 bind 未绑定设备；**绝不 unbind/remove 在线设备**（会挂内核）。
2. **`/usr/local/sbin/net-up.sh`** —— 等 wlan0 → `wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf`
   → `udhcpc -b -i wlan0 -x hostname:elden`（后台模式，拿不到租约会自动重试）。

实测（冷启全程零手动）：`bind ok`@18s → `phy0 up`@23s → wpa_supplicant@20.6s → dhcp@26.8s
→ `wlan0 = 10.23.47.x/24`，ping 通、DNS 正常。

脚本与 `/init` 补丁源在 **`scripts/`**（`ath12k-retry.sh` / `net-up.sh` / `patch-init-net.sh`）；
WiFi 配置：`/etc/wpa_supplicant/wpa_supplicant.conf`（当前存 `vivo X200 Ultra` 热点）。

### 22.2 上一轮还拿下的

- **启动 90s → 5s**：`patches/0001-ath12k-shorten-mhi-timeout.patch`（`MHI_TIMEOUT_DEFAULT_MS` 90000→3000）。当前内核镜像 **`out/boot-elden-vk10.img`**。
- **充电正常**（电源驱动无需修）。

### 22.3 TF 卡：暂判驱动/卡问题（已按用户意停手）

- 硬件/DTS/内核全支持（`&sdhc_2`、`MMC_SDHCI_MSM=y`、`F2FS_FS=y`）；**认卡、全容量裸读写、200MB 顺序写读回全部 OK**。
- **但 mkfs 后挂载失败**（ext4 `VFS: Can't find ext4 filesystem` / f2fs magic mismatch），16MB buffered 写读回 CORRUPT。
- DT 加 `no-1-8-v` 降速到 High-Speed 后**仍失败** → 属 `sdhci-msm` 的 DMA/一致性 bug（要改内核），或卡本身劣质。
- 已建分区：`mmcblk0p1` 4G ext4(`lkeep`) / `mmcblk0p2` 54G f2fs(`lroot`)（格式化成功，但挂不上）。

### 22.4 GUI：Phosh 已装、phoc 跑通，卡在已知的 glycin 沙箱 bug

- **Phosh 已装**（`apk add phosh`，889 MiB / 590 包，余 ~1.2G）。
- **`phoc` 合成器跑通**：DRM 1904×3040@120Hz、GLES2/Adreno 830、libinput 经 **eudev** 认到触屏（`NVTCapacitiveTouchScreen`）。
- ❌ **`phosh` shell 一启动就 abort**：gdk-pixbuf 2.44 默认用 **glycin** 加载 SVG 图标，glycin 的 **bwrap 沙箱内 loader `exit 1`** → GTK 断言失败 → app abort。
  - 已知上游 bug：GNOME glycin #196 / Ubuntu gnome-sdk #356。
  - 已排除：bwrap 本身可用（手工跑 loader 正常）、userns 正常、seccomp 是黑名单非 kill。属 glycin 回退逻辑缺陷。
  - 佐证：`phoc` 缺 udev 时也报 libinput 无设备 → **GUI 启动前需 `udevd` 在跑**。
- **建议后续**：PHP 换传统 gdk-pixbuf/PNG 图标/打 glycin 补丁，或改 **Plasma Mobile**（Qt，不走 glycin，但需 ~1.6G，得先扩空间）。

### 22.7 GUI glycin 沙箱绕过 + vk11（2026-09-29，PC 侧完成，待上机验证）★

**上游调研结论**（本轮在 PC 上定案）：
- gdk-pixbuf 2.44.7 **硬链接 `libglycin-2.so.0`**（`readelf -d` 实证），传统 loader 只剩 `xpm`；png/jpeg/svg 全走 glycin。
- glycin 有 `sandbox_mechanism` 三态：`Bwrap` / `FlatpakSpawn` / `NotSandboxed`；由
  `glycin/src/sandbox.rs:686 check_bwrap_syscalls_blocked()` 决定（源码已核）。
- **关键逻辑**：glycin 用 `/usr/bin/true` 跑一次 bwrap 自检；若
  (a) 退出码 `128+SIGSYS` 或信号 SIGSYS，或
  (b) stderr 含 `Creating new namespace failed` / `No permissions to create a new namespace` …
  → 判定"内核挡住 bwrap" → 自动切 **NotSandboxed**（打印 `WARNING: Glycin running without sandbox.`）。
  ⚠️ bwrap **完全不存在**反而会被判成"可用"（`Err(...) → false`），所以"删掉 bubblewrap"**不是**解法。
- 无环境变量可关沙箱（glycin 2.1.5 只有 `GLYCIN_DATA_DIR`、`GLYCIN_SECCOMP_DEFAULT_ACTION`）。

**采用的修复（纯 PC、无需重编 apk）**：给 `bwrap` 装一个 shim，让自检命中 (b)。
- 自动路径：`rootfs/alpine/init` 在 `elden_root` 分支、`mount /newroot` 成功后、`switch_root` 之前，
  向磁盘根的 `/usr/local/bin`、`/usr/bin` 写入 shim（真实 bwrap 备份为 `bwrap.real`；幂等、可回退）。
- 手动路径：`scripts/glycin-bwrap-shim.sh apply|revert|status`（已在本地沙箱测过）。
- 产物：**`out/boot-elden-vk11.img`**（77 MiB，kernel/dtb 与 vk10 同源，ramdisk = 新 init）。
  验证：镜像 cmdline 含 `elden_root=LABEL=linux`；cpio 内 `/init` 通过 `sh -n` 且含 shim 标记。
- 上机验证要点：`fastboot boot out/boot-elden-vk11.img` → `dmesg | grep glycin` 应有
  `[init] glycin bwrap shim installed`；`ps` 里不再有 bwrap；`phosh` 应不再 abort。

**未采用/备选**：`-Dglycin=disabled` 重编 gdk-pixbuf（Arch 的官方修法）需要同时恢复 png/jpeg 内建 loader，
且 2.44 起 **SVG 只能走 glycin**（librsvg 已无 gdk-pixbuf loader）→ 会丢 SVG 图标，故先不用。

### 22.8 Phosh 桌面打通（2026-09-29，vk11 上机验证）★

**结论：冷启动全自动进 Phosh**；`start-desktop.sh` 拉起 `udevd` + `seatd` + `phosh-session`（循环）。
上机实测：开机 ~1 min 内 `phosh`/`phoc`/`gnome-session` 全在，DRM plane `allocated by = phoc`，
截图确认是 Phosh 锁屏/主屏，会话无 abort、无 fail whale。

vk11 的 glycin shim 已把 phosh 的 abort 修掉；之后**又踩到 4 个进一步拦路的问题**，全部定位并修复：

| # | 现象 | 根因 | 修复（已落盘 sde79） |
|---|---|---|---|
| 1 | 滑上去后要输 PIN，但任何 PIN 都不过 | Phosh 0.55 默认 `sm.puri.phosh.lockscreen require-unlock=true`；镜像 `/etc/pam.d/` 几乎空（无 `pam_unix` 配置）| `99_elden.gschema.override` 设 `require-unlock=false` |
| 2 | shell 完全不启动（早一步 abort） | `mesa-gl` 包标记已装但 `/usr/lib/libGL.so.1` 实际缺失 → 加速检查 gl-helper abort | 从 `pkgs-phosh/mesa-gl-*.apk` 解包补回 |
| 3 | fail whale（`Unrecoverable failure in required component`）| 无 UPower/logind 下 `gsd-power` `exit 1` 且 respawn 过快 | `phosh.session` 的 `RequiredComponents` 删 `org.gnome.SettingsDaemon.Power` |
| 4 | 会话中途整体退出 | ★ 自己 `pkill -f gnome-session-failed` 把远程 shell/会话一起杀了 | 改用 `pkill -x`（见 PITFALLS §52）|

**产物 / 脚本**：
- `scripts/start-desktop.sh`（Phosh 自启；旧 weston 版在设备上备份为 `start-desktop.sh.weston.bak`）。
- `scripts/enable-phosh-desktop.sh`（幂等：装 shim / 补 libGL / 写 override / 改 session / 装 start-desktop）。
- 设备侧落盘：`/usr/share/glib-2.0/schemas/99_elden.gschema.override`、`/usr/lib/libGL.so.1*`、
  `/usr/share/gnome-session/sessions/phosh.session`、`/usr/local/sbin/start-desktop.sh`。

**截图取证**（不用 grim）：
```sh
PID=$(ps -o pid=,comm= | awk '$2=="phosh"{print $1; exit}')
BUS=$(tr '\0' '\n' < /proc/$PID/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
export DBUS_SESSION_BUS_ADDRESS=$BUS
gdbus call --session --dest org.gnome.Shell.Screenshot --object-path /org/gnome/Shell/Screenshot \
  --method org.gnome.Shell.Screenshot.Screenshot false false /tmp/shot.png
```

**遗留（桌面相关）**：
- 状态栏只有蓝牙：无 NetworkManager（WiFi 图标）/ 无 UPower（电池）→ 需在系统总线起 NM/UPower。
- 应用极少（只有 Settings）；需要装 terminal 等，注意 2.3 GiB 空间。
- 时间显示 1970（无 RTC 同步）→ 需要 `ntpd`/`chrony` 或用 WiFi 校时。
- 触屏在锁屏可用，但 Squeekboard 虚拟键盘/按键缩放（`GDK_SCALE=2`）待调。

### 22.5 遗留 / 注意

- **热重启间歇性卡死**：从主线 `reboot -f` 有时回不到 fastboot、USB 全无（§18.3 的老问题，**冷启可恢复**）。本次一度以为卡死，实为**电池耗尽**——主线不充电，长任务前先充满。
- 手机热点 `vivo X200 Ultra` 的 DHCP 曾多次不下发租约（手机侧），现已恢复正常；`net-up.sh` 的后台 DHCP 会持续重试。

### 22.6 WiFi 长稳 / 崩溃取证方法（原 `ATH12K-STABILITY.md` 精简）

若要把 WiFi 当成真·主网，再做这些：

- **禁区区**：绝不对**在线** ath12k 设备 `unbind`/`remove`（已两次挂内核→重启）；不要 `rmmod`（内建，也动不了）。
- **崩溃现场优先读 pstore**：`ls -l /sys/fs/pstore/`——有内容就是上次启动崩过；
  `cat /sys/fs/pstore/console-ramoops-0`（尾部即 faulting stack）。读完存档 `cp -a /sys/fs/pstore /root/pstore-$(date +%s)`。
  内核已开 `CONFIG_PSTORE_RAM` + `PANIC_ON_OOPS` + `PANIC_TIMEOUT`，DT 有 `ramoops@c2000000`。
  验证 ramoops 真的工作：`echo c > /proc/sysrq-trigger`（会主动 panic，仅准备就绪时做一次）。
- **区分「主动重启」与「自己崩」**：测试前 `logger -t BOOT intentional`，并记录 `date` 与主机日志对齐。
- **归因表**：

| pstore 内容 | 指向 | 下一步 |
|---|---|---|
| ath12k `fw_assert` / MHI / QMI 栈 | 驱动/固件 | `CONFIG_ATH12K_COREDUMP`；换固件版本；报上游 |
| drm/display 栈 | 显示 vblank bug（§18.3） | **与 WiFi 无关**，单独查 |
| 只有 watchdog bark、无 panic 栈 | hang | 缩小 hang 点（USB gadget / 调度 / 过热） |
| 无 pstore 但 reboot 异常 | 过热/掉电/手按 | 查 thermal / 电池 |
| 长跑不挂 | **稳定** | 结案 |

- **本轮“神秘重启”实为掉电**（主线不充电），非驱动问题。

---

## 23. ★★ GPT 手术：userdata 缩容 + 新增 65 GiB `linux` 分区（2026-09-29，已上机验证）

### 23.1 背景

原 root = `/dev/sde79`（LUN4 尾部 `last_parti`，仅 2.3 GiB，余 ~1.2 GiB），装不下桌面应用/Plasma。
内部唯一富余空间是 `sda16 userdata`（211.4 GiB）。TF 卡（`mmcblk0`）因 `sdhci-msm` flush/cache
一致性导致部分写丢失（`PITFALLS §55`），不能当可靠根分区 → 只能动 GPT。

### 23.2 障碍（Gen4 特有）

vendor fstab：`userdata` 是 **dm-default-key 元数据加密的 f2fs**
（`metadata_encryption=aes-256-xts:wrappedkey_v0`，密钥在 `/metadata` 硬件包裹）。
→ mainline / Android root 都拿不到裸密钥，**不能 `resize.f2fs` 在线缩容**；
且 TWRP 里 `resize.f2fs -s` 缩容虽能在块层保数据，但 **ZUXOS 检测到容量不对 → 反复重启卡 logo**
（`PITFALLS §58`）。
→ 唯一可行路线：**GPT 手术后把 userdata 整个擦掉，让 Android 重建 `/data`**（与 2026-09-04 那次一致）。

### 23.3 已执行

| 项 | 值 / 路径 |
|---|---|
| 原 GPT 快照 | `backup/gpt/gpt_main0_device.bin` / `gpt_backup0_device.bin` |
| 新 GPT（已写入，回读比对一致） | `backup/gpt/gpt_new_main0.bin` / `gpt_new_backup0.bin` |
| 手术脚本 | `scripts/gpt-surgery-tb322fc.py`（`list` / `build`，含 CRC 顺序与双向自检）|
| 写入方式 | **在 mainline 里 `dd /dev/sda`**（主表 LBA0–5、备表尾 LBA61390843–61390847）——不需要 EDL |

### 23.4 结果（设备实测）

```
sda16  userdata  fc95ed5b-…  PARTLABEL=userdata        157 200 756 736 B = 146.4 GiB
sda17  linux17   9d6736ba-…  LABEL=linux17 ext4         69 793 218 560 B =  65.0 GiB
```
rootfs 已 `mkfs.ext4 -L linux17` + 复制；`out/boot-elden-vk12.img`（vk11 仅改 cmdline 为
`elden_root=LABEL=linux17`，81 088 512 B，sha 与 vk11 之差仅 cmdline）。

**验证（已通过）**：

```
$ fastboot flash dtbo_a out/dtbo-dummy.img   # + dtbo_b
$ fastboot boot out/boot-elden-vk12.img
$ ssh root@192.168.7.1 'findmnt -no SOURCE,FSTYPE,SIZE /; df -h /'
/dev/sda17 ext4 63.4G          # 已用 985.6M，余 59.2G
```
phoc/phosh 正常自启（`start-desktop.sh`）；`/dev/sde79`（label `linux`）保留作后备，
`out/boot-elden-vk11.img` 可随时回退。

`pack.sh` 默认 cmdline 已改为 `elden_root=LABEL=linux17`（`EXTRA_CMDLINE` 可覆盖；
置空 `EXTRA_CMDLINE=""` 得 RAM-only 调试镜像，`EXTRA_CMDLINE="elden_root=LABEL=linux"` 回旧根）。

### 23.5 ★ 唯一遗留：Android 侧必须擦除重建 `/data`

`sda16` 已缩到 146.4 GiB，但里面还是**自认 211 GiB 的 f2fs** → Android `fs_mgr` 挂载失败 →
bootloop（`PITFALLS §58` 同款）。**这一步由用户手动执行**：

```bash
# 设备在 fastboot；确认 a 槽（b 槽是坏的，任何内核 PMIC/SPMI 早死，见 §20）
fastboot --set-active=a
fastboot erase userdata
fastboot erase metadata          # 清掉旧 FBE/metadata 加密 key，避免残留不匹配
fastboot reboot
```
首次进 Android 会重建 `/data`（146.4 GiB）并初始化；之后可恢复 `~/android-backup/` 里的
Hollow Knight + Limbus。构建版本 `TB322FC_CN_OPEN_USER_Q00041.1_W_ZUXOS_1.5.10.259_ST_260611`。

---

## 24. ★★ b 槽直启 mainline Linux（2026-09-29 深夜，已上机验证）

**目标**：摆脱 `fastboot boot`（RAM-only、每次都要主机），让设备**自己**开机进 Linux。

### 24.1 关键事实

- b 槽是**另一套固件/另一把密钥**：`vbmeta_b`/`vbmeta_system_b` 用 `8fcb864f…`，
  而 a 槽顶层 `vbmeta_a` 用 `2597c218…`。所以 b 槽原厂**永远起不来**（chain key mismatch）→ 拿它当 Linux 槽正合适。
- **顶层能过，卡在 chain**：b 槽失败时报的是 chain 级 `boot` key mismatch，
  说明 ABL 接受了顶层 `vbmeta_b`，只是要求 `boot` 用 `8fcb864f` 签名（我们没有那把私钥）。
- 我们用**自签 key**（RSA-4096，公钥 sha1 `fc1e3b33f76b269c5ad5e570a4f776eb8701f24d`）重做了一整套
  自洽 AVB：`boot_b`（带 footer）+ `dtbo_b`（带 footer）+ `vbmeta_b`（flags=3 = verification/hashtree 全关）。

### 24.2 实测（用户执行，一次成功）

```bash
fastboot --set-active=a
fastboot flash dtbo_b   bootslot-b/dtbo_b.img
fastboot flash boot_b   bootslot-b/boot_b.img
fastboot flash vbmeta_b bootslot-b/vbmeta_b_flags3.img
fastboot --set-active=b
fastboot reboot
```
→ **约 9 秒后设备自己进 Linux**（无需主机）：`ssh root@192.168.7.1`、
`findmnt /` = `/dev/sda17`（65 GiB）、`androidboot.verifiedbootstate=orange`。

### 24.3 资产与回退

- 资产在 `bootslot-b/`（`avb.key`、`avb.avbpubkey`、`boot_b.img`、`dtbo_b.img`、
  `vbmeta_b_flags3.img`、`vbmeta_b_flags0.img`），说明见 `bootslot-b/README.md`。
- 回退：`backup/stock-259/{vbmeta_b,boot_b,dtbo_b}.img` 刷回 + `--set-active=a`。
- **副作用**：b 槽不再是 Android 备用槽；`current-slot` 会停在 b。
  回 Android 仍要走 fastboot：→ `./cycle.sh --soft` 或按键进 fastboot → `fastboot --set-active=a`。

### 24.4 遗留

- **别再靠 `fastboot boot`**：现在改内核后，重新 `fastboot flash boot_b bootslot-b/boot_b.img`
  （需先用 pack.sh 重打 + `add_hash_footer`）即可；或临时用 `fastboot boot`（RAM）验证后固化。
- 打包脚本待办：把 `add_hash_footer` 步骤并进 `pack.sh`（生成可直接刷 b 槽的镜像）。
- ABL 的“启动失败自动切槽”是否会把 b 槽判为失败并翻到 a —— 待观察（本次未发生）。

### 24.5 改内核不再需要 fastboot（2026-09-29 深夜）

b 槽直启打通后，**`reboot -f` 会回到 Linux（不再掉到 fastboot）**，`cycle.sh --soft` 的旧"软回 fastboot"链路失效。
现在的迭代方式（全程不需要 fastboot、不需要主机按键）：

```bash
# 1) 改内核/配置 -> 编译 + 打包（★ 绝不跑 olddefconfig）
./build.sh && ./pack.sh out/rootfs-vk11.cpio.gz out/boot-elden-vk13.img
# 2) 自签 + 直接 dd 写 boot_b（脚本已封装，含 sha256 回读校验）
scripts/flash-b.sh out/boot-elden-vk13.img --reboot
```
- `scripts/sign-boot-b.sh`：`add_hash_footer`（partition `boot`，96 MiB，key `bootslot-b/avb.key`）。
- `scripts/flash-b.sh`：签 → scp 到 `/tmp` → `dd` 到 `/dev/disk/by-partlabel/boot_b` → 回读校验 → 可选重启。
- `cycle.sh --fastboot`：从 Linux 写 `misc` 的 BCB（`bootonce-bootloader`）请求进 fastboot（备用）。

### 24.6 第 8 号内核 = vk13（去掉睡眠）★2026-09-29

用户决定：**先让内核不支持睡眠**，排除"熄屏→挂起→挂死"这条路径。
改动：`scripts/config -d SUSPEND -d HIBERNATION`（备份 `linux/.config.bak-vk13-nosuspend`），
`CONFIG_PM_SLEEP` 随之变 `n`。实测（设备上）：

```
/proc/version  ... #8 SMP PREEMPT Tue Sep 29 23:39:21 CST 2026
/sys/power/  -> 只有 state(空) 与 pm_freeze_timeout   ← 没有 freeze/mem/disk
/sys/power/mem_sleep -> 不存在
```
→ **系统无法挂起**；桌面（phoc/phosh）与显示正常，从 slot b 正常启动。
首次用 `dd` 直接更新 boot_b 的流程见 §24.5（回读 sha256 一致）。

---

## 25. 2026-09-30 收官（Android 闭环 + 桌面轮 + 槽位根治）★

本日全部成果的**权威记录分散在以下文档**，本节仅作索引：

| 主题 | 结论 | 详文 |
|---|---|---|
| Android 收尾 | `/data` 重建 146.4G(FBE) + a 槽 KSU 全链（方案 A，abl 未动）+ MT root | `复盘-2026-09-30-日.md` §一 |
| 熄屏/唤醒修复 | 根因：**系统 dbus 未跑 + `dbus-daemon-launch-helper` 权限错（root:root→root:messagebus）**；已进 `start-desktop.sh` | `复盘-2026-09-30-日.md` §二 |
| **槽位元数据根治** | **A/B 槽状态在 GPT 分区项 attribute byte6（不在 misc）**；`python3 scripts/slot-attr.py mark-successful b` → `boot_b=0x7f` | `GPT槽位元数据-2026-09-30.md` |
| 内核 vk13→vk19 | 无睡眠（-SUSPEND/-HIBERNATION）；vk14 夜灯 gamma；vk19 AW86937 CONT 触觉 | 本文 §24.6 / `STOCK-KERNEL-2026-09-30.md` |
| 依赖分层 | A 用户态 / B 内核图形 / C 其他驱动；深色/缩放**不**依赖图形驱动 | `ROADMAP-dep-2026-09-30.md` |
| 音频侦察 | tplg 是通用占位（无 MI2S/aw88461）→ 出声需自建 AudioReach 拓扑 | `AUDIO-scout-2026-09-30.md` |
| 会话环境 bug | `/init` 无 HOME → 会话 `HOME=/`，dconf 落到 `/.config`；已 `export HOME=/root` 并迁移 dconf | `INDEX.md` §4 / `scripts/start-desktop.sh` |
| 会话归位 | 5 个 home-cwd flashing 会话已移入项目 `sessions/` | `INDEX.md` §7.1 |

**当前状态（2026-09-30 20:30 实测）**：b 槽直启 Linux，`/sys/power` 无睡眠节点，电池 77% Charging，
wlan0 连热点 + 公网 IPv6，`df /`=63.4G，`boot_b byte6=0x7f`。
**剩余小项**：① Displays 比例行恒显 100%（phosh 显示 bug）② Night Light 偏暖过重（待校阈值）；
**大项**：B2 刷新率 / C1 音频 tplg / C2 TF 卡 / WiFi 长稳 / 蓝牙。
