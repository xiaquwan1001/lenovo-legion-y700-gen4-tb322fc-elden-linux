> 会话进度见本目录 `sessions/`；本文件为该角度策展 SSOT。
# 设备描述与设备状态（DEVICE）

> 本角度文件夹的策展 SSOT（`README.md`）；`sessions/` 存以会话为单位的进度。标准见 `INDEX.md` §2。
> **本文件是设备层唯一权威**；旧专题文档中的设备结论以本文件为准。

---

## 1. 设备描述（机型唯一）

| 项 | 值 |
|---|---|
| 机型 | Lenovo Legion Tab **Y700 四代** = **TB322FC** = 代号 **elden** = `elden_prc_wifi`（国行 WiFi） |
| SoC | **SM8750(P)**（骁龙 8 至尊版 / 8 Elite），8 核 max 4.09 GHz；GPU **Adreno 830**（freedreno `gen80000`） |
| 屏 | LCD 1904×3040，双 DSI bonded + CPHY + DSC，CSOT PP8807HB1-1，Novatek **NT36536**（165 Hz 已默认） |
| 音频 | AudioReach（LPASS/q6apm）+ 双 **AW88461** 功放 + **AW86937** 双触觉 |
| 无线 | WCN7861 "PEACH"：WiFi 走 `ath12k`（pci 17cb:110e）/ BT 走 `hci_qca` |
| 相机 | 后 **Samsung S5KJNS** 50 MP（csiphy3）/ 前 **GC08A8** 8 MP（csiphy4）/ VCM GT9764 / PMIC WL2868C |
| 传感器 | 7 颗挂在 **SLPI/SSC 传感器核**私有 I2C（LSM6DSO、MMC56x3x、LPS22DF、SHT4x、SX932x、BU52053NVX、TMD3765）→ **AP 侧无引脚连** |
| 存储 | UFS 4.0（LUN0=`/dev/sda`，扇区 **4096 B**）+ TF 卡（`sdhci-msm`，有写丢失 bug） |
| Hypervisor | **签名 Gunyah 占 EL2**（内核只到 EL1）→ mainline **无 KVM**（`hyp` 分区受 XBL 签名校验） |
| 原厂 build | `TB322FC_CN_OPEN_USER_Q00041.1_W_ZUXOS_1.5.10.259_ST_260611`（Android 16） |
| BL | 已解锁；`boot` 是 **chained AVB** 分区：自签必须 **AOSP testkey（sha1 `2597c218`）+ rollback `1738713600` + 3 条 prop**，缺任一被 ABL 拒 |
| 主机 | `xuqianhui`（Ubuntu 26.04；旧文档里的 `5700g-x8664` 是历史名，2026-11 起不再使用），交叉链 gcc-15 / avbtool / mkbootimg / dtc 齐；设备地址 USB-NCM `192.168.7.1` |
| 设备访问（2026-11-08 补全） | **两个账户都已装主机公钥（`~/.ssh/id_rsa`）** ⇒ 不会因「忘了用 root」误判设备离线：`ssh elden` = 用户 `xuqianhui1001`（属 `sudo`，`sudo -n` 免密）/ `ssh elden-root` = `root`（别名在主机 `~/.ssh/config`）。`sshd`：`PubkeyAuthentication yes`、`PasswordAuthentication yes`、`PermitRootLogin prohibit-password`。Android 槽时走 `adb`（`10AF5J0FHQ0039G`），Linux 槽跑 `sshd` |

### 1.1 内核与软件基线

> **注（2026-11-20 批二，A4 判「三代口径叠写」）**：本节按时间**倒序**叠写，★/★★/★★★ 只是不同年代的标记层；**现态 = 日期最新的最顶条目**，其下所有旧条目（含旧「现态」字样）均为历史沿革，读现态不需要往下看。冲突时按 `INDEX.md` §2 时间序裁决。
- ★**现态（2026-11-20 23:10 更新，压过下面全部；在机 vk192）= b 槽主启 Linux（开关机可重复验证）+ PC 声音默认转发到平板**：
  `qbootctl` = `_b` **Active/Successful/Bootable 全 1**（`qbootctl.service` enabled ⇒ 每发自动 mark-successful，
  不再抽 retry）；内核 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`；`/` = `/dev/sda17` 190 G / **1260 包** / Mesa **26.1.6**；
  三进程 `greetd+phoc+phosh(+osk)`；`wlan0` 出网 + `usb0` 192.168.7.1 SSH；六件 mask 在位、`systemctl --failed` 空；**三次冷起均 ~25 s 直进 Linux**。
  **音赖**：PC 侧 `audio-share-server.service`（`as-cmd --bind=0.0.0.0:65530`，user unit enabled）+ ufw 放行 192.168.7.0/24；
  平板侧 `audio-share-client.service`（user 1001，目标 192.168.7.9:65530）⇒ 实测 384 KB/s = f32/2ch/48 kHz 满速、冷起自连。
  装机/体检 = `scripts/as-client-deploy.sh [--check]`，客户端源码 = `rootfs/debian/audio-share/as-client.c`。
  **fastboot 卡死的三层真因**（GUID 占位 / LUN 错配 / retry 抽干）= `PITFALLS` **#697**，处置路径同条。
- ★★**（历史，2026-11-19 13:20）自建最小 Debian（主线 Linux）+ Phosh 桌面在 slot `_b`**：
  GPT 已恢复双轨（`linux17` 193 GiB @LBA 73277435 + `userdata` 256.7 GiB，主备读回 `80ab46e5…`/`e5f79c0e…`）；
  根 = `out/min-restore-20261119/rootfs-minbase-gadget-20261119.ext4.img`（6 GiB，设备端 sha `abf96ec4…`，
  = 11-18 的 160 包 minbase + 本次注入的 `/init`、`/usr/local/sbin/usb-gadget`、`/etc/udhcpd.conf`、`/etc/elden-init-mode=systemd`）；
  `boot_b` = 自签 `bootslot-b/boot_b-minbase-labellinux-20261119.img`（同 vk192 核/DTB/initrd，cmdline `elden_root=LABEL=linux`，读回 `740d431b…`）。
  **登入方式 = USB-NCM**：`sudo scripts/ncm-host-up.sh` → `ssh root@192.168.7.1` / `ssh elden-root` / `ssh elden`（两别名均可，2026-11-19 实测；或 `scripts/acm-sh.py` 走 `ttyACM1` 免网络 root shell）。
  **★2026-11-19 晚补充（非包状态）**：重建根时只把公钥装给了 `root` ⇒ `ssh elden`（用户 `xuqianhui1001`）曾 `Permission denied`、该用户也不在 `sudo` 组；
  已补 `authorized_keys` + `/etc/sudoers.d/010-xuqianhui1001`（NOPASSWD）+ `usermod -aG sudo`，判据已机械化进 `deploy-desktop-shell.sh` **§3b**（`--check` MISS=0）。
  **WiFi 现态（同日实测）**：`ath12k` 已由 `ath12k-rescan.service` 救活（`iw dev` 有 `phy0`/`wlan0`、`nmcli dev wifi list` 能扫到 `ustcnet`/`eduroam`、`rfkill` 未封），
  但 `nmcli connection show` 只有 `lo`、`/etc/NetworkManager/system-connections/` **为空** ⇒ 状态栏无 WiFi 图标 = **没连过任何网**（不是驱动/硬件问题）；凭据属人项。
  PITFALLS `#689`；控制面矩阵与沿革 = `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md` §2.5/§2.6。
  ~~**已知未愈**：显示无 DRM（`/sys/class/drm` 只有 `version`）——根因 = `af54000.displayport-controller` deferred 拖死 DPU 组件聚合~~ **已愈（2026-11-19 13:20）**：
  真因 = 根里**没装 `udev`** ⇒ 模块零自动加载 ⇒ DP 组件 defer；装 `udev` 后 DPU aggregate + DSI×2 + DP + GPU 全 bound、`/dev/dri/card0` + fb0。
  **同日再进两步**：`resize2fs` 6.25 GB→**190 GiB**；桌面壳 = greetd+phoc+phosh（`phosh-osk-stub`）+ seatd，
  **GPU 渲染 = Mesa 26.1.6（trixie-backports）`Adreno (TM) 830`**（`glmark2-es2` Score 2594）—— 冷起自检 `bash scripts/deploy-desktop-shell.sh --check` → MISS=0。
  **锁屏需人手滑开**（内核未开 `CONFIG_INPUT_UINPUT`，无 `/dev/uinput`）。链路手册 = `RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md`。
  ⟪历史定界（2026-11-19 13:20 之前）⟫ ~~`ath12k` MHI `-110`、无 `/dev/fastrpc-adsp`、`snd-sc8280xp` deferred（均 ADSP/GPR 未就绪）~~ —— 该三项已随 `apt install udev` 全部消失（见本条上文），此处仅作定界前记录。
  **旧 `linux17` 根 fs 已确认丢失**（EDL 6 点采样全零，成因 = 原厂 `userdata` 覆盖 + `fastboot -w`），故本次为重建而非恢复。
  安卓面（2026-11-19 21:5x 更新）：a 槽 = **已回刷 v1 精简件**（`super_min.img`，读回 `e3d0d26f…` 逐字节一致；`boot_a`/`init_boot_a`/`vendor_boot_a` = 原厂，`vbmeta_a` = 自签 Flags=1）；
  **上机 3 发均未进桌面**（v3 卡 ZUXOS 动画；另两发卡 logo 后掉电，但当时 `misc` BCB = `boot-recovery` ⇒ 很可能启的是 recovery，不作数）；Linux（b 槽 + `linux17`）全程未受影响，现居 Linux。详见 `reports/android-slim-v3-20261119.md` §7。
  **设备不需要送修**（「ABL 内存类硬件故障 / 全原厂态等送修」= 已作废口径，2026-11-19 标废）：真因 = 非原厂 GPT（11-17 19:2x 单变量定因），
  此后设备连续三次真实上机（11-17 20:0x 完整起 Android 16 / 11-18 19:0x 最小安卓包 / 11-19 深夜本最小根）⇒ 硬件无故障证据。
  旧送修单仅作历史存档：`DEVICE/service-repair-note-20261117.md` 顶部作废块；对照表 `reports/device-status-20261119.md`。
- **历史：在机 = 持久化的 `vk192`（2026-11-16）**：`uname -r` = `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`
  （= `build/daily` HEAD `4bdf1711b5` + tag `vk192`；内核 payload `0a55e52c…`，dtb `89c9336d…`，ramdisk `3282ae6c…`）。
  **持久件 = `boot_b` 自签 `vk192`**（`bootslot-b/boot_b.img` = 96 MiB，分区读回 sha `06c081ca…`，空载件 `out/boot-elden-vk192.img` = `bdf47f5f…`）；
  ABL 现用槽 = `b`，`qbootctl` = Active/Successful/Bootable 全 1，**重启实测回 vk192（32 s 到 SSH）**。
  **模块树 = 1510 个 `.ko` 已部署 `/lib/modules/7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`**（新 UTS ⇒ 整套重编，不能沿用 vk190 那套）。
  **判据（本轮全绿，2026-11-16）**：`bound ae94000.dsi` + `[drm] fb0` / `wlp1s0` UP（ustcnet）/ `/dev/fastrpc-adsp` + `qrtr-lookup` 的 `400 Snapdragon Sensor Core service` /
  SensorProxy `HasAccelerometer/HasProximity/HasAmbientLight = true` / Waydroid + zramswap active / s2idle `rtcwake -m mem -s 45` **3/3 rc=0（`suspend_stats` fail=0）**。
  **本版内容 = pstore/ram 守卫**（拒绝与 initrd 重叠的 ramoops zone，两枚提交 `5c72e9e838`+`4bdf1711b5`，上游已投 3×250）。
  证据 `reports/device-session-20261116-vk192.md`、`reports/pstore-ram-initrd-guard-20261116.md`。
  - 历史：`vk191` 曾以 **RAM 启动**（`fastboot boot`，kernel/dtb 同 vk190、仅 ramdisk 换成立即 SN 版）在机 2026-11-13→11-16；
    其判据与证据见 `reports/device-session-20261113-vk191.md`（现役已换成 vk192，那条仅供沿革）。
  - `boot_a` **未动** = UEFI 干净世代 `pc1`（分区 sha `1ca2b8e69167…`，件 `out/r21-sbstop-pc1/uefi-preamblec1-r1.img` `40d43397…`）；
    要用 UEFI 路先显式 `fastboot set_active a`（该槽 `unbootable=yes` 的历史口径见下方 11-09/11-10 块）。
    **槽属性现态（2026-11-16 14:06 现查，`slot-attr.py show`）**：`boot_a` retry=7 succ=1 active=1 unbootable=0（本轮 a 槽暖启成功 7↓6 → **`mark-successful a` 回 7/1**，不会再递减）；`boot_b` retry=6 succ=1 active=0 ⇒ 已回 `_b`（14:07:48 = 16 s 到 SSH）。
  - **ESP `\EFI\BOOT\BOOTAA64.EFI` 已从 v5（A2 + `panic=0`，会挂住像死机）切回 `v3b-bigfont`**
    （sha `244c5f65…`，`--tag v3b-restore`）⇒ 从 a 槽起不再「挂住不重启」；旧值备份仍在 `\EFI\BOOT\BOOTAA64.EFI.v5.bak`。
    **★2026-11-14 只读复核（定案，取代本条以前的含糊口径）**：它是 **GRUB 嵌入菜单件**（二进制含 6 个 `menuentry`、
    **不含** `configfile …/boot/grub/grub.cfg` 桩）⇒ 它 **不读** linux17 上的 `/boot/grub/grub.cfg`，
    改菜单只能重打 EFI（`scripts/grub-arm64-arming-build.sh` → `scripts/esp-install-grub.sh --activate`）。
    当时它嵌的菜单 = 11-11 的 A/B/C 实验组，`default=0` = **无 `earlycon=efifb keep_bootcon` 的 A 臂**
    ⇒ 直接 `set_active a` 起来会黑屏无字（`PITFALLS #622`），复测前必须先换 arming 件（`out/grub-20261114/grubaa64-arming-v6.efi`）。
  - **ESP（`/dev/sda18`）实测身份（2026-11-16 现查，取代 11-14 夜“= Loader-r73”那段）**：
    **现役（2026-11-16 15:33 起）** `\EFI\BOOT\BOOTAA64.EFI` = **日常用嵌入菜单 GRUB v10 + 中文标题**（sha `15a8ddf8…`，8 204 288 B；菜单 = `out/grub-arm64-arming-20261116/arming-daily-v10-cjk.cfg`，主字体 = Noto Sans CJK 子集 72 px `build/grub-arm64/fonts/big-cjk72.pf2`，生成器 = `scripts/grub-arm64-cjk-font.sh`）——标题：`启动 vk192（直载 initrd）` / `启动 vk192（无 ramoops 诊断）` / `加载 ESP Loader.efi（r73）` / `重启` / `关机`。
    **v8/v9 沿革**：v8 = `f5dcf599…`（DejaVu 字体、中文标题渲染成点）；v9 = `82fb1f8f…`（CJK 子集 96 px，中文可读但间距大 + 标题被截断，GRUB 菜单项不折行）；两版都在 `EFI/grub/grub-*.efi` 与 `*.bak` 里。
    **v8 及以前的口径**：菜单原型 = `arming-daily-v8.cfg`（同一套 5 臂结构，仅标题/字体不同）——
    臂 0（默认，`timeout=10`）= 直载 `/boot/Image`（vk192 守卫核）+ `elden.dtb` + 64 MB initrd + 全量 `earlycon=efifb keep_bootcon` cmdline；
    臂 1 = 同一内核 + `elden-noramoops.dtb`（诊断）；臂 2 = chainload `\EFI\elden\Loader.efi`（r73 → `\boot\boot.img`）；reboot/poweroff。
    **a 槽暖启实测已过**（`fastboot set_active a` → 14:04:35 → 14:05:53 = **44 s 到 SSH**；cmdline `elden_bootmenu=grub-daily`、grubenv `51-daily-vk192-initrd-ok-booting`、ramoops 三段 `ignoring … overlaps the initrd`）；
    **冷启（POR）也已验（2026-11-16 14:46，用户断电冷起）**：菜单正常屏显（5 条，屏照 `30-cold-por-grub-menu.jpg`）→ 默认臂起进 Linux；`Active slot: _a`、DRM = **`card1`**。**注意两件事**：① 走 UEFI/GRUB 路径时 msm 是 `card1`（efifb 先占 card0 再注销），旧版 `q28-boot-watchdog` 只认 `card0` ⇒ 约 100 s 误判「Q28 坏发」自动重启（**已修**，`PITFALLS #667`，设备件 sha `d694c147…`）；② 该轮其中一发是真 Q28 坏发（屏白→仅背光、msm 未 bind），属 #228 存量问题、与本次 EFI 无关。
    证据 `reports/artifacts/uefi-daily-v8-20261116/`；15:02:49 已 `set_active b` 回日常（**12 s** 到 SSH、`_b`、`card0`）。

    **★★★2026-11-17 20:0x 现态（压过下面全部「卡 BL / 在机 vk192」说法）：原厂 Android 16 已完整启动**
    （`TB322FC_CN_OPEN_USER_Q00041.1_W_ZUXOS_1.5.10.259_ST_260611`、`sys.boot_completed=1`、slot `_a`、`verifiedbootstate=orange`）。
    真因 = **非原厂 GPT**（LUN0 改名/多出 `linux17`+`eldenesp`、LUN4 槽属性非 stock）；只写 88 KiB GPT 就把「全镜像 `Device Error`」变成「ABL 真的去启动」⇒ **硬件判读全部作废，送修单作废**。
    Linux 侧：`linux17` 条目/槽镜像/ESP 已被原厂件覆盖，但 `linux17` 的 ext4 数据物理上保留在 LBA `73277435`（192 GiB）⇒ 重建走 `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md` §3 S3a（先重建条目、不格式化）。
    本节下面「在机 vk192」的描述 = **历史时点**（2026-11-16），不是现态；取证 = `reports/bl-stuck-20261118-forensics.md` §7。

    **★★历史（19:36 T2 之前）：设备卡 BL，进不了系统（镜像/分区当时是清白的）**：
    **至今（2026-11-17 18:05）已把“软件层”排到底：全量刷回原厂引导固件 39 分区（设备端 sha256 39/39 == 官方 259 件）+ A/B 双槽原厂 `boot/vbmeta/dtbo`，冷起仍落 fastboot；
    连原厂 `boot_b.img` 与 1 MiB 自制合法 boot.img 的 `fastboot boot` 也都是 `Device Error` ⇒ 失败点固定在 ABL 的 load/authenticate，与 flash 内容无关。
    全账 = `reports/bl-stuck-20261117-device-window.md` §7/§8；历史案例与决策树 = `reports/bl-history-and-playbook.md`。
    18:53 时点态 = `current-slot=a`、`unbootable:a/b=no/no`、`retry=a7/b6`；那一时点“非原厂物只剩 GPT 里的 `linux17`/`eldenesp`”一句 **自 19:2x T1 写回原厂 GPT 后已失效**（条目消失、ext4 数据仍留在 LBA `73277435`）。
    回退到 Linux 件：`bootslot-b/boot_b.img`（`06c081ca…`）+ `backup/vbmeta_b-20261110.img`（`e974ebab…`）+ `out/dtbo-dummy.img`；引导固件旧值 dump = `backup/HA2EXB0E-16+512/dev-dump-20261117/`。
    原 11-17 上午现态（活沿革，留作对照）：
    `current-slot=b`、`slot-successful:a/b` **均 no**、`retry-count a=3 / b=0`、`unbootable` 均 no、电池 3406–3408 mV。
    `fastboot continue` → `Failed to load image from partition: Load Error`；`fastboot boot` 对**两份不同镜像**
    （自研 `out/boot-elden-vk192.img` 与 11-14/15 实测能起的 `out/r21-sbstop-pc1/uefi-preamblec1-r1.img` `40d43397…`）**3/3 同错**（`Load Error`）；
    `fastboot reboot` 与 EDL `reset` 都 20 s 内落回 fastboot。⇒ **镜像/分区/固件已由 11-16 夜 EDL+`qdl` 双工具逐项对账为台账值**
    ⇒ 剩下 ABL 载入/认证通路（**未定因**；18:5x 复核后不再定为硬件，`poke` 那条证据已撤回）。
    全账 = `reports/bl-stuck-20261116.md` §9；按全局规则 12 已上交 `~/hw-stability/evidence/inbox/20261117-y700-elden-bl-load-error/`，**项目内不深挖**。
    恢复动作（代价升序，下次设备窗口）：① 长按 10 s 全断电→只按电源；② 充到 >3.7 V 再试；③ EDL 分块同值重刷 `xbl`/`abl`/`boot_b`；④ EDL 全量刷 stock（`backup/stock-259`）。
    **2026-11-17 15:22 复测（零写盘，只 `getvar`）**：`battery-voltage:3425`、`battery-soc-ok:no`、`factory-mode:1`、`off-mode-charge:1`、`unlocked:yes`、`variant:SM8 UFS`。
    **★但电量已不作为判据（用户 16:0x 定：fastboot 下 UI 看不到电量、也测不到协商充电速率 ⇒ 不读/不推/不作阻塞理由）**；
    同一窗口 `logfs` 里 ABL 自报 `VBAT: 3899mV`——**★18:5x 复核：这条不能用**（logfs 只存成功交接段 `#485`/`#594`，该读数属过去某次成功启动；活值 `battery-voltage` 3425 mV@15:22 → **3571 mV@18:53**、`battery-soc-ok:no` 未变）⇒ 充电通路未排除但不得当阻塞理由。
    **★2026-11-17 16:02–16:50 第二次设备窗口（全账 = `reports/bl-stuck-20261117-device-window.md`）：仍未恢复，已按 AGENT-OPS 停手保留现场。**
    本轮 **11 次启动尝试**（`continue` ×4 / `boot` ×5 / EDL `reset` 冷起 ×3）全败，且**失败串自变**：
    `Failed to load image from partition: Device Error` ↔ `Failed to load/authenticate boot image: Load Error` ↔ `… Device Error`
    ⇒ 「同错逐字相同」的旧口径被推翻。**新增排除 10 条**：镜像内容（qdl `06c081ca…`）与写路径、GPT（5 LUN 全解析）、
    槽属性（复位 `unbootable=no/retry=7`，冷起 retry 7→6 证明 ABL 真尝试）、lock/verity（unlocked / `Verity mode:false`）、
    vbmeta_b 未变（= 11-16 备份 `e974ebab…`，`Flags:3` 验证关）+ dtbo_b 与其描述符一致、ABL 本体（两槽均 stock，与 11-16 取证件逐字节同）、
    存储读路径（12 分区 Firehose 读回 + 96 MiB 设备端 sha256 稳定）、**镜像大小/落点**（**2.4 MB** 件同样 `Device Error`）、槽相关 dtbo 处理。
    ⇒ 11-17 18:5x 复核：**「剩下强候选 = 运行期加载/内存通路（疑似硬件）」这条判读撤回**（DRAM 侧被自证反驳、错误串自变 = `#482` 已知特性、`poke` 无正控 + `#486` 门控），结论改 **未定因**；已按规则 12 追加证据到
    `~/hw-stability/evidence/inbox/20261117-y700-elden-bl-load-error/MANIFEST.md`，**项目内不深挖**。
    本轮写操作只有两类且已复原：`--set-active` 来回（终态 `b`）、`flash boot_b` 同一内容件（读回 `06c081ca…` 不变）。
    下一步（需人）：① 长按 15–20 s 完全断电→等 10 s→只按电源（不插 USB）；② 分级刷机预案 **A/B/C**（用户亲自刷，全量 dry-run 已验：73 分区 / 15.6 GiB / 78 patch）见 `reports/bl-stuck-20261118-forensics.md` §4；③ 或改「Android 优先」恢复可用系统。

    **换下件 = 验证用嵌入菜单 GRUB `cc6391b3…`**（11-16 11:45 装，两臂 G1/G2 对照 + D + reboot/poweroff），已备份 `BOOTAA64.EFI.daily-v8-20261116.bak`（注意：备份名取的是**新件** tag，内容 = cc6391b3）。
    **换件前实际在役件 = `92a4d8b2…`**（9.5 MB GRUB，11-15 23:01 装、此前 `DEVICE` 未记录 → 本轮补登），已备份 `BOOTAA64.EFI.grub-fixr2-20261116.bak`；
    `\EFI\elden\Loader.efi` = Loader-r73（`6e51fc60…`，未动；拷回当 BOOTAA64.EFI 即走 `\menu.cfg` → `\boot\boot.img` 那条 14 s 链）。
    历史件全在 ESP 上可回滚：`.arming-v6.bak`（`244c5f65…` v3b-bigfont 嵌入菜单，不读 linux17 的 grub.cfg）、
    `.grub-arming-v7.bak`（`a63d2ab4…`，卡 GRUB→initrd 交接，`PITFALLS #659`）、`.lf2v2.bak`（`b9fb14cb…`，LF2 只打印版）、`.v3b-restore.bak`/`.v5.bak` 等。
    `\boot\boot.img` = **`bdf47f5f…`**，与 `out/boot-elden-vk192.img`（空载件）**逐字节相同** ⇒ ESP 侧的 a 槽链路已指向 vk192（旧件备份 `out/boot-elden-vk190.img` `54e84588…`）。
    **判据（新，旧的 `elden_bootloader=esp` 已失效）**：ESP 路径 = cmdline 里 `androidboot.serialno=51318dc0`（CRC32，**不是**真 SN）
    且**无** ABL 追加的 `verifiedbootstate/hqsysfs/ufsffu`；b 槽路径反之。
  - **`/boot` 下 DTB 现为「预置 initrd 属性」版（2026-11-14 22:41）**：`elden.dtb` = `84c2e0bf…`（153 193 B）、
    `elden-nopstorecons.dtb` = `ac562717…`（153 164 B），均在 `/chosen` 预置了 `linux,initrd-start/end`（值 0）。
    原件备份 `*.bak-20261114-224158`。**预置不是修法**（`PITFALLS #659` 已证否），仅保留无害。
  - **`/boot/Image`（linux17）**：**本轮（2026-11-16）换成守卫内核** `0a55e52c…`（`build/daily` `v7.3.1-5-g4bdf1711b5`，64 072 192 B）；
    换件前实际值 = `de659cf0…`（65 120 768 B，11-15 23:06，**文件身份未记录**，已备份 `/boot/Image.bak-20261116`）。
    11-15 根因报告里写的「已还原 vk190（`0cdb7a45…`）」已被 11-15 深夜那轮覆盖 ⇒ 以本条为准。
    `/boot/initrd.img` = `3282ae6c…`（64 595 425 B，11-12 起未动）、`/boot/elden.dtb` = `84c2e0bf…`（含 ramoops）、`/boot/elden-noramoops.dtb` = `818f4d85…`。
  - **上机通道口径（新，`PITFALLS #650`）**：进 fastboot 用 `ssh elden-root 'sync; reboot bootloader'`，
    **不要**用 `scripts/to-fastboot.sh --boot`（暖复位后立刻 `fastboot boot` 实测黑屏+崩坏，同镜像 systemd 路径一次过）。
  - **★2026-11-16 新增 `fake-hwclock`（时间基线）**：硬件 RTC **不可写**（`hwclock -w` ⇒ `ioctl(RTC_SET_TIME) … 没有那个设备`，`/sys/class/rtc/rtc0` 恒停在 1970-01-08 起算），此前每 boot 的早期 journal/日志全落在假钟上（watchdog 日志 162/170 行时间戳不可信）。现装 `fake-hwclock`：`fake-hwclock-load.service` + `fake-hwclock-save.timer` 均 enabled，`/etc/fake-hwclock.data` 定时落盘，开机即恢复系统时间。**取证口径**：仍以 `boot id + short-monotonic` 为主，时间戳只作旁证。→ `reports/q28-DOSSIER.md` §t-2 的 T1
  - **★2026-11-13 夜已部署的资源采样器**：`/usr/local/sbin/suspend-resource-sample.sh`（sha256 前 16 = 现查 `sha256sum`）+
    `elden-resource-sample.timer`（30 min，`OnBootSec=5min`）⇒ 追加写 `/var/lib/elden/suspend-resource.tsv`（TSV 表头 20 列）。
    **判据**：`systemctl is-active elden-resource-sample.service` 应很快回 `inactive`（oneshot）；TSV 行数随时间增长。
    取数：`scp elden-root:/var/lib/elden/suspend-resource.tsv .`。口径与判据纪律见 `TASKS/README.md` §4 的 T9 行、坑见 `PITFALLS #651`。
  - **ESP（`/dev/sda18`）**：`\EFI\BOOT\BOOTAA64.EFI` = **v3b-bigfont GRUB**（`244c5f65…`，嵌入菜单版；
    **不是** Loader-r73 —— 2026-11-14 只读 sha 定案，见 §1.1 同条）、`\EFI\elden\Loader.efi` = Loader-r73（`6e51fc60…`，未动）；
    `\boot\boot.img` = **vk190**（`54e84588…`，`menu.cfg` 首项已改名 `Elden vk190 (ESP boot.img)`）、
    `\boot\dtbo.img`（32 MiB）、`\boot\vendor_boot.img`（96 MiB，Mu loader 的 Android 回退路径要用，**别删**）；
    **2026-11-13 清理**：`\boot\boot2.img`（vk185-adsp，宿主留档 `out/boot-elden-vk185-adsp.img`）已删、`menu.cfg` 对应行一并去掉
    ⇒ FAT `fsck.vfat -n` 干净、avail **97 MiB**（清理前 13 MiB）。现菜单 = `vk190 / Mu fastboot / Power off`。
    注：现用槽是 b ⇒ 这条 ESP 链只在 `set_active a` 后才会被走，先当**备用/对照**路径。
  - **回退**：`fastboot flash boot_b bootslot-b/boot_b-vk185.img`（或 `backup/HA2EXB0E-16+512/boot_b-before-vk185-20261107.img`）+ `fastboot oem ... ` → 回 vk185（无 s2idle）；
    ESP 旧件 `backup/HA2EXB0E-16+512/esp-boot.img-before-vk190-20261113.img`（= vk184 `27bd6ddd…`）。
  - **传感器链路前置**：ADSP fastrpc 必须带 `qcom,non-secure-domain`（vk190 起日常线才有；判据 = `/proc/device-tree/soc@0/remoteproc@6800000/glink-edge/fastrpc/qcom,non-secure-domain` 存在，**别用 `strings dtb` 计数**，见 `PITFALLS #639`）。
  - **构建门禁口径（2026-11-13 变更）**：ABI 参考 = `patches/config-daily-c2-suspend-20261113`（含 `CONFIG_SUSPEND=y`），
    `scripts/check-abi-config.sh` 默认优先 `config-daily-*`；`build/m3v2-7.3rc7` 已同步开 SUSPEND ⇒ 打包不再需要 `SKIP_KERNEL_ASSERT=1`。
  - **两条不变的硬约束（基线事实，违反 = 环境直接不可用）**：① **内核必须自编** — Debian 任何 `linux-image` 都缺本机板 DTS；
    ② 传感器栈必须有 **forky/sid 级 `iio-sensor-proxy` + `libssc2`**，否则 `libssc`/`qrtr svc 400` 链路直接死（驱动侧坑见 `PITFALLS #114/#115`）。

- **沿革：2026-11-10 → 2026-11-04 的逐轮在机快照**（`2026-11-10 20:15` active=a/UEFI-ESP 快照、2026-11-09「路线 B」零写盘路径与 p61/R62 复测、**`boot_b` vk185 身份 sha `4e38bc2c…`（2026-11-07 权威记录）**、2026-11-07/11-06/11-04 各版快照、greetd 关机细节）→ `sessions/2026-11-19-§1.1历史快照三轮下沉.md` §A（逐字未改，历史值；现态只读本节首条）。
- ★**槽位属性硬规则（仍有效）**：**改非活动槽属性必须用 `scripts/slot-attr.py` 直写 LUN4**（`qbootctl -u a` 在活动槽为 b 时必失败，`PITFALLS #487`）；**ABL 在 b 槽失败后会自己切活动槽到 a 并清其 unbootable**（`PITFALLS #487` 追加条）。
- ★**不随镜像漂移的操作约束（动手前必读；镜像号/sha/分区数字只读本节首条（现态）与上面沿革指针所指的归档，以及与本文 §2.5/§3.3）**：
  - **写 `boot_b` 后必须读回核验并核 AVB 身份**：`python3 tools/avbtool.py info_image --image <件>`（签名实际取值 `KEY=bootslot-b/avb.key`，见 `scripts/sign-boot-b.sh`）；换机后 AVB 公钥已重建 = `sha1 1e54e86ef19fad73…`（旧 `fc1e3b33…` 作废），`vbmeta_b` chain descriptor 已同步重签（`scripts/sign-boot-b.sh`；`PITFALLS #313`）。
  - **`linux18` 已删除**（2026-10-31 并根）：`by-partlabel` 只剩 `linux17`，运行根 = `/dev/sda17` ext4 `LABEL=linux17` ⇒ 历史条目里「回退 = 重启回 Alpine `linux18` f2fs」的口径**已失效**（分区数字只读 §2.5 与 §3.3）。
  - **模块树**：`/lib/modules/<UTS>` 被 vk163/vk172/m3v5 等多代镜像共用（`uts_dup`，见 `versions/vk-ledger-known-issues.tsv`）；**换新 UTS 内核必须先部署模块树再判显示**，否则 `lsmod` 空 ⇒ DP defer ⇒ 无 `card0`（`PITFALLS #293`）。
  - **相机时钟模块必须是原版**：持久根 `/lib/modules/<vk64KV>/drivers/clk/qcom/cambistmclkcc-sm8750.ko`（md5 `88a45177…`，备份 `/root/q24bak/`）——换入实验版会让任何自动加载相机的启动挂死（`PITFALLS #177`）。
  - **自建 boot.img 上机前先核三条件**（`PITFALLS #468`），否则会出现「USB 整个消失」且只能靠物理断电回 fastboot；覆盖前用设备侧 `dd` 备份（本机 ABL 无 `fastboot fetch`，`PITFALLS #290`）。
- **沿革（2026-10-10 → 2026-11-01 的逐轮在机快照：vk64/vk94/vk113/vk124/vk127/vk145/vk147/vk152/vk163/vk173/vk181/vk182/vk183 与 f2fs/Debian 换根全过程）** → `sessions/2026-11-02-在机状态沿革-vk64..vk172.md`（本节只维护「当前在机」一条 + 上面这组约束，避免与 `SESSIONS/`、`HISTORY/` 三处复写）。
- **Linux 侧提交的唯一入口 = `../TASKS/README.md` §7**（原沿革尾部条，随沿革搬家后在此保留指针）。
- **沿革：2026-10-15 晚 M1-7.3 模块树补齐 / vk127 重放冷起 + `boot_b` 刷写验收 / 2026-10-10 Q28 离线快照** → `sessions/2026-11-19-§1.1历史快照三轮下沉.md` §B（逐字未改，历史值）。其中仍有效的构建侧两条硬规则 = **必带 `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`** + **必 `export LOCALVERSION=`**（裸 `make` 会静默删 `ARCH_QCOM`；多一个 `+` 则上机被拒，`PITFALLS #282–#284`）。
- **主机串口 logger** = `scripts/serial-logger.sh`（pid 文件 `/tmp/q28_serial_logger.pid`，常驻；主机重启需重跑）。**判 Q28 显示不能只靠串口 logger**（重连会漏 0–20 s，盖住 NOCARD 的 0.86 s 现场），须 SSH 读全 dmesg + 查 `card0`。
- ★**2026-10-17 晚：相机 AE 正解 = libcamera 侧 sensor helper（用户态，与内核 UTS 无关）**：设备 `/usr/lib/libcamera/ipa/ipa_soft_simple.so` 已换成自编版（含 `s5kjns`/`gc08a8` 的增益模型 + 黑电平 4096；主机交叉编译，配方 `reports/camera-ae-helper-20261017.md` §2），原包备份 `/root/ipa-bak-20261017/`。**相机驱动 `.ko` 保持原版**（增益码语义未改，`/root/cam-ko-bak-20261017/` 里的补丁版只属 vk127 目录、未使用）。相机栈仍需 `CAM_FORCE=1 camera-modules-load.sh` 手动加载（cmdline `elden_nocamera=1`）。
- `CONFIG_LOCALVERSION` 一变，相机 20 个 `.ko` 必须整套重编（vermagic 耦合）；vk50 起模块化后驱动可单独重编。
- **容器（Waydroid）侧在机资产（2026-10-13，TASKS C10 三期）**：`/var/lib/waydroid/images/vendor.img` 已**固化**自编 AIDL V2 vibrator HAL（`/vendor/bin/hw/android.hardware.vibrator-service.elden` + rc + vintf fragment）与静态 RRO `EldenVibrationOverlay`（`/vendor/overlay`，把 Settings 振动强度档位 1→3）；运行期只剩宿主 daemon `elden-hapticd`（systemd 单元 `elden-hapticd.service`，源 `packaging/elden-userland/out/units/systemd/`；Alpine 期为 OpenRC + `/etc/conf.d`）与一条 `sys/class/leds` 桥挂载。**回退镜像** `/var/lib/waydroid/images/vendor.img.bak-elden-haptics-20261013-115055`；复现 `scripts/waydroid-haptics-bake-patch.py` + `bake-vendor.sh`（2026-11-20 注：`bake-vendor.sh` 全仓已无此件，`find . -name bake-vendor.sh` 空；镜像 sha256 账见 `versions/out-images-sha256-20261105.tsv`）；细节 `reports/waydroid-haptics-20261013.md`、踩坑 `PITFALLS #232–#246`。 **★2026-10-29**：当前在机 `vendor.img` = **打过 camera gralloc 布局修复补丁**的版本（`/lib64/hw/camera.device@3.{4,5,6}-external-impl.so` + `provider@2.{4,5}-external.so` 五个文件替换，镜像 sha256 `82769ed6…`，其余字节与 10-19 镜像相同）；该次推送前的回退件 = `/var/lib/waydroid/images/vendor.img.bak-l1d-20261029-103701`。

### 1.2 固件清单与通路（"正常驱动原厂全部固件"的分解）

| 固件 | 来源分区 | 本地资产 | 主线通路 | 状态 |
|---|---|---|---|---|
| ADSP `adsp.mdt`+`adsp_dtb` | LUN4 `modem_a` | `backup/fw/modem/` | `qcom_q6v5_pas`；DT 期望 `/lib/firmware/qcom/sm8750/adsp.mdt` | ✅ 起（音频 graph 已通） |
| AudioReach **tplg** | vendor 自研 | 自编 `Lenovo-Y700-Gen4-tplg.bin` | ASoC `q6apm` + `patches/0011` | ✅ 出声+录音（G1-4） |
| CDSP `cdsp.mdt`+seg / `cdsp_dtb.mdt`+seg | `modem_a` | `backup/fw/modem/image/`（**split**；`cdsp_dtb.mbn` 单文件被 TZ 拒） | `qcom_q6v5_pas` + DTS `firmware-name`（split）；固件须在 **initramfs** | ✅ 起（`remoteproc1 running`，2026-10-07，G1-11） |
| WiFi Peach（`amss.bin`/`bdwlan`/BDF） | `modem_a/peach` | `backup/fw/modem/image/peach/`（两套：在用 `amss20.bin` sha `848a2f04…`；**非-20 `amss.bin` 不兼容**：MHI POWER_ON `-110`） | `ath12k` + MHI 重试补丁 | ✅（**Q26 已关闭**：2026-10-10 用户实机确认关联即可用，见 `TASKS` §5 Q26） |
| BT（**5 个文件**：`brhbtfw20.tlv`/`brhbtnv20.bin`/`brhperifw20.tlv`/`brhperinv20.bin`/`tmel_peach_20.elf`） | `bluetooth_a` + LUN4 `modem_a/image`（tmel） | `backup/fw/bluetooth/`、`backup/fw/modem/image/tmel_peach_20.elf` | `hci_qca` + IBS 补丁；**WCN7861 外设阶段在代码里要 5 个文件名**（`MODULE_FIRMWARE` 只列后 3 个） | ✅ 配对 + TWS 实听通过（用户 2026-10-06）；**2026-10-28 补：第 5 个 `tmel_peach_20.elf` 缺则控制器不注册**（`Peripheral setup failed: -2`，`PITFALLS #454`），已进 `elden-firmware/local-extras.tsv` + 门禁 A2 |
| GPU gen80000 `zap/sqe/gmu/aqe` | vendor | `backup/fw/gen80000_*` | `msm` + freedreno | ✅ |
| 触屏 `novatek_ts_csot_3k_fw.bin` | vendor | `backup/fw/vendor/` | `nt36536` | ✅ |
| 触觉 FW / 功放 ACF | vendor | 改名喂入 `awinic/y700-gen4-*.bin` | `aw86927` / `aw88461` | ✅ |
| SLPI 传感器固件 + QMI-SNS | `modem_a` | 仅 `.json` 配置 | **主线无栈 + AP 无私有 I2C 总线**（需 QRTR + `qcom_smgr`） | ⛔ 不阻塞主线：G2 走容器软传感器；Linux 原生侧为可选自研（`TASKS` G1-34，未开工） |
| Modem / SDSP / SPU / TEE / Gunyah hyp | 各分区 | 有 blob | 主线无客户端 | ➖ 不立项 |

### 1.3 驱动面与投入边界（数字：厂商 529 compatible / 297 `.ko`；主线 SM8750 覆盖 146 compatible）

> **本节只定“硬件面归类 + 要不要做”；具体功能状态（✅/🟡/⬜）一律看 `../TASKS/README.md` §0/§1，本表不维护状态。**

| 面 | 项 | 性质 / 边界 |
|---|---|---|
| **主线在跑** | CPU/GPU/显示/USB/PCIe/UFS/WiFi/BT/触屏/触觉/背光/充电旁路/温控分级/音频/相机驱动栈/CDSP/DP | 驱动均在树，无缺失 |
| **在树但需调** | TF 卡写稳定性；面板 init 竞态；熄屏×相机共存 | bug / DT 电源域，非缺驱动（G1-6/Q28/Q24） |
| **低优先增强** | 温控 OEM 层（`lenovo,sys-temp`/BCL/QMI cooling）；SLPI 传感器原生栈（G1-34） | 前者可用通用框架近似；后者需 QRTR+`qcom_smgr` 栈 |
| **不成立** | ~~NFC~~ | **本机无 NFC 硬件**（vendor 无 nfc feature/HAL/固件，`PITFALLS` #108） |
| **✗ 不投入** | TEE/SPU/hw-fence/mem-buf、FM RTC6226、ST54 SE、Gunyah/PMIH010x | 私有或无源码 |

### 1.4 USB 双口与充电（2026-10-29 实测定案，本节为该事实唯一正文位置）

长边口 = USB3（`usb@a600000` + QMP SS PHY、DP altmode）；短边口 = USB2（`usb_dwc3_hs2`）。
两个 `usb-c-connector`（`connector@0`/`@1`）各绑一颗 SMB1501，
充电由 **ADSP `battery_charger`** 经 PMIC-GLINK 决定用哪一口/哪颗。
（**2026-11-21 地址更正**：旧文写 `smb1501@0x43`/`@0x42` 是错的——那两个 I²C 地址在真机 live FDT 里是 `fcs,fsa4480`（SBU/orientation mux，`reports/artifacts/uefi-eud-20261101/live-fdt.dts:1497/1513`），
vendor 板上 SMB1501 是 `qcom,smb1501@68`/`@69`（`backup/stock-elden/elden.dts:2897/2903`）；同一份 live FDT 里 `smb1501` 命中 0 条 ⇒ 「两颗充电 IC 都在当前 DT」这句降级为**未证**，待真机 `/sys/class/power_supply` 现查。）

| 观测 | 实测值（2 s 粒度采样，用户物理插拔） |
|---|---|
| **长边 = PC(SDP)** + 短边 = PD | 电池 **0.29–0.33 A**；`ucsi.01/02` 均 online（短边 PD 契约 3 A、`port1-partner/pd0` 存在）；`qcom-battmgr-usb` 报 5.05 V / 891 mA |
| 拔掉短边 PD（仅长边 SDP） | 电池 0.19→0.39 A（充电算法爬升）；`ucsi.02` offline；`qcom-battmgr-usb` 报 4.71 V / 891 mA |
| **拔掉长边 PC，仅短边 PD** | 电池 **0.199 A → 12.21 A（40 s 内爬升）**，`capacity` 19%→27%（≈+600 mAh）；**短边 PD 单独 = ≈46 W 真快充** |
| 长边 PC 插回（两口都在） | 立刻回落到 **0.18–0.19 A**，只吃长边 SDP |

**结论（已证）**

1. **不是硬件单口**：短边 PD 单独可跑 12.2 A。
2. **不是「内核只认一口」**：内核逐口建模（两个 `typec/port*`、两个 `ucsi-source-psy-*`；两颗 SMB1501 **地址与是否存在按上一段更正后的口径**）。
3. **是 ADSP 的选口策略**：两口同时在时只选长边；`qcom-battmgr-usb` 只是**只读跟随被选中的那一口**
   （插 PD 时报 PD 的 5.05 V，拔掉后报 PC SDP 的 4.71 V）。AP 侧**没有**改这个选择的控制面。
4. **只留短边 PD 时 `qcom-battmgr-usb` 的 `voltage_now` 读到 1.0–1.2 V**（与电池吃 12 A 矛盾）——
   这是 `qcom_battmgr` 单 `usb_psy` 结构的直接后果（多口时读数归属不清），**不要当电压故障**。

**★ 2026-10-30 操作事实（用户确认）**：**ABL / bootloader / fastboot 阶段只有「长边」口有数据**；
短边口在 fastboot 下不枚举 ⇒ 从 Linux `reboot bootloader` 前必须把数据线插到**长边**，否则设备进 fastboot 后主机看不到
（本轮实测踩到：插短边时 `fastboot devices` 空、`lsusb` 无 18d1，设备却已在 fastboot）。自建 BL（让短边也能用于 fastboot）
**归入远期项**，当前不作为任何任务的前置。

**接法候选**：要「数据 + 快充」同时成立，历史候选接法 **PD 插长边、数据线插短边**；「数据+充电并存」已于 2026-10-30 反向接法实测（见下条），**仅热切换/启动期仲裁**未验证（`TASKS` §7 M3-1）。
详细采样日志与判据表 = `../reports/usb-dual-port-test-protocol-20261029.md` §8。

**2026-10-30 反向接法实测**：用户接短边数据线、长边充电线；SSH 数据链路可用，两 UCSI online，`.01` 报 PD，`.02` 报 Type-C；六次采样中电池显示 100%、Charging、约 1.86–1.95 A，`qcom-battmgr-usb` 约 8.81–8.87 V / 1.46–1.62 A（标识 SDP 与 PD 报告不一致，归属未证实）。因此本次只证明**同时有数据和充电**，不证明快充功率、充电器端实际输入或长期稳定性。原「需 M3-1 仲裁才有数据」作为本接法的必需条件被当前观察推翻，启动时与热切换行为仍待区分；证据 `../reports/artifacts/usb-reverse-20261030/snapshot.txt`。

---

### 1.5 面板按键（EC）映射 —— GRUB/UEFI 菜单下实测

| 场景 | 按键 | 证据 |
|---|---|---|
| GRUB 2.14 菜单 | **音量上 / 音量下 = 上下移动高亮**；**电源键 = 确认启动** | 用户 2026-11-08 实测（`reports/uefi-grub-esp-handoff-wall-20261108.md` §2b） |
| 超时 | `grub.cfg` 里 `set timeout=8` ⇒ 8 s 后自动选第一项 | 同上 |

⇒ 后续任何「启动菜单」方案（沿用 GRUB 或自写 loader）都以这组按键为输入契约：**不需要键盘，也不需要触摸**。

---

### 1.6 设备当前可用性与下一步上机判据（2026-11-19 立）

> **结论：设备可用，不需要送修；离线≠坏机。** 判据与全账 = `reports/device-status-20261119.md`。
> 这一节存在的理由：本仓曾有一轮（2026-11-17 上午）把「ABL load/authenticate 失败」读成硬件故障并起草送修单，
> 18:5x 判读撤回、19:2x 单变量定因 = **非原厂 GPT**。为防止该口径回流，此处固化为「怎么判在线 / 下一步跑什么 / 哪几件是人的动作」。

**① 在线与否怎么确认（只读，任一命中即在线）**

```sh
timeout 15 lsusb | grep -E '05c6:9008|18d1:d00d|05c6:90'   # EDL 9008 / fastboot
timeout 15 fastboot devices                                # → HA2EXB0E  fastboot
timeout 15 adb devices                                      # → HA2EXB0E  device
timeout 10 ssh -o BatchMode=yes -o ConnectTimeout=5 root@192.168.7.1 'uname -r'   # 主线 Linux（先 sudo scripts/ncm-host-up.sh）
```

**② 判读规则（不要越级下结论）**
- 三条 USB/adb/fastboot 全空 **且** `lsusb` 无任何 `05c6:*`/`18d1:*` ⇒ **「未连接/未上电」**，不是故障；先要人插线/上电。
- `adb devices` 里有别的机器（如 `MDX5T20730009849` = P40pro、`emulator-5554`）**不是本机**；一律带 `-s HA2EXB0E` 或 `-s 51318dc0`，**禁止对它们做任何写操作**。
- 只有「在线且同一现象可重复 + 硬件四道门全过」才允许写硬件结论（四道门：`RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md` §1.2）。
- 2026-11-19 19:xx 实测：`lsusb` 只有 root hub/自身 gadget/键鼠/`12d1:108a`(Huawei)、`fastboot devices` 空、`adb` 只有上面两台 ⇒ **未连接**。

**③ 在线后下一步（按现态优先级，写操作见 ④）**
1. **主线 Linux（主任务，显示未通）**：`python3 scripts/slot-attr.py show | grep boot_b` → `mark-successful b`；
   再走显示实验（**零写盘**）`out/min-restore-20261119/dp-port2-experiment.patch` → `make dtbs -j26` → `scripts/build-boot.sh` → `fastboot boot`；
   **先跑一发 `out/boot-elden-vk192.img` 原件做 `test-ctrl`**（RAM 启动本身是否仍可用），否则 nodp 件失败不可判。
2. **安卓 a 槽（只读取证优先）**：卡 ZUXOS 动画取证 = `adb -s HA2EXB0E logcat` / recovery logcat / `ttyGS0`（`scripts/acm-sh.py`）。
3. **桌面层**：`resize2fs` 扩到 193 GiB + `daily-baseline`（需先有显示/网络）。
- 最小件在盘清单（2026-11-19 已核）：`out/min-restore-20261119/rootfs-minbase-gadget-20261119.ext4.img`（6.0 GiB，sha `abf96ec4…`）、
  `out/android-min-20261118/pkg/super_min.img`（8.28 GiB）、`out/boot-elden-vk192.img`（`bdf47f5f…`）、`scripts/{ncm-host-up.sh,acm-sh.py,slot-attr.py,build-boot.sh}`。

**④ 必须由人做的动作（agent 不自行动手）**
- 物理：插 USB 数据线、按电源键上电、长按断电（POR）、在引导菜单上选条目。
- 任何**写设备**操作（EDL `write`、`fastboot flash`、`fastboot -w`、`mark-successful`、`slot-attr` 写、`android-ksu-flash.sh --apply`、
  `android-slim-v2-plan.sh --apply`、`hide-android-partitions.sh --apply`）⇒ 先列清单等用户确认（2026-11-19 这一次一件也没做）。

---

### 1.7 安卓 / Linux 共存分区契约（2026-11-19 立，★先读这条再动任何写操作）

> 一句话：**Android 住前段（`super` + `userdata`），Linux 住后段（`linux17`），`boot_a` 归 Android、`boot_b` 归 Linux；
> 谁都不许改对方那段的起点。** 判据与全账 = `reports/android-slim-v3-20261119.md` §1；脚本 = `scripts/android-linux-coexist-check.py`。

| 分区 | LBA（4096 B/扇区） | 大小 | 归属 |
|---|---|---|---|
| `super` | 90504..5857671 | 22.00 GiB | Android（a 槽动态分区：system/vendor/product/odm/system_ext/*_dlkm） |
| `vbmeta_system_a/b`、`metadata`、`rawdump`、`pstoredump` | 5857672..5972391 | ~0.5 GiB | Android |
| `userdata` | 5972392..73277434 | 256.75 GiB | Android `/data`（`fastboot -w` 只擦它 + `metadata`） |
| `linux17` | 73277435..123871226 | 193.00 GiB | Linux 根（`boot_b` cmdline `elden_root=LABEL=linux`） |

**纪律**（每条都对应一次已发生的翻车）：
- 写 Android 只允许 `qdl write 0/90504 …` 且镜像扇区数 ≤ 5767168（= `super` 跨度）；一次只写 `super`，不串 `vbmeta`。
- 写 Linux 只允许在设备侧动 `linux17`（`dd`/`resize2fs`）或 `boot_b`；**禁止**再用「单 `linux` 从 LBA 90504 起」的 GPT-minimal 设计（2026-11-17 覆盖事故的形状）。
- 动 GPT 前必须跑 `scripts/linux-gpt-dump.sh`（六 LUN 主/备表落盘）**并且**跑 `android-linux-coexist-check.py` 得 rc=0；两条缺一条不许写表。
- 判据只认读回：EDL `read` + `sha256sum` 与主机件相等，不接受「传输完成」。

**现态（2026-11-19 21:5x）**：契约 rc=0（三段 LBA 逐字节一致、16 条目两两不重叠、无 `linux`/`elden-super`/`elden-data` 单分区）；
`super` 现为 **v1 精简件**（`e3d0d26f…`，8481.5 MiB；v3 件 `51eae107…` 已读回验证但卡 ZUXOS 动画，暂不采用）；`linux17`/`userdata`（已 erase，raw 未格式化）/`boot_b` 状态见 `reports/android-slim-v3-20261119.md` §7。

---

## 2. 设备状态

### 2.1 设备等价原则（★）
1. **身份 = (SN, hwboardid, 容量)**，"新/旧"只是到货顺序，**不是角色**。
2. **物理等价** ⇒ 同一 boot 镜像 / 内核 / rootfs 归档 / GPT 生成器 / 验证脚本对任一单元都成立；
   唯一实质差异 = **容量 → GPT 数值**，故脚本一律运行时读实际 GPT。
3. **任务按单元当前状态分派**（§2.3），做完可回收复用。禁止把任务永久绑定到某台机器或把资产命名成"某机专用"。

### 2.2 单元台账（唯一登记处；刷机状态变化当场更新）

| ID | SN | hwboardid | 内存/UFS | a 槽 | b 槽 | LUN0 GPT | 可派任务（由状态决定） |
|---|---|---|---|---|---|---|---|
| **U1** | `HA2ABH62`（主线 gadget 已改为锚定原厂 SN，见 `PITFALLS #549`/`#626`） | `TB322FC_SM8750P_12+256` | 12 G / 234 GiB | stock 259 **已 root**（SUSFS 6.6.118+KSU+ZN/Shamiko/PIF） | 原厂已刷回 | **已逆手术**：`linux17` 删、`/data` 回 211 GiB | Android 侧一切（AVF 勘察、固件对照、过环境）；mainline 需重做手术 |
| **U2** | `HA2EXB0E` | `SM8750P_16+512_13` | 16 G / ~476 GiB | **BL 已解锁** · stock **259**（Android 16；Widevine **L1**）。**进 Android = `fastboot --set-active=a` + `fastboot reboot`（无需刷 dtbo，实测 2026-10-11，HANDOFF §20 再次成立）**；未 root、无 Google 账号。C0 基线已采：`backup/HA2EXB0E-16+512/c0-baseline/` | **mainline 持久直启**（当前运行根与 boot_b 形态**只读本节 §1.1 首条**，本行不维护这些数字）；`recovery_b` 已刷 TWRP。**外设/驱动功能状态不在本表维护**，一律看 `../TASKS/README.md` §0/§1「未解项只读 §5」 | **已手术（2026-10-25 二次手术 = f2fs 并存；2026-10-31 `linux18` 已删除并入 `linux17`）**：`linux17` ext4 **192.0 GiB**（idx16，`/` 可用 163 G；分区参数与扇区见 §3.3）+ `userdata`=256.7 GiB；双表 dump 在 `backup/HA2EXB0E-16+512/`（手术前基线另存 `gpt-20261025/`，合并/扩容日志 `backup/gpt-20261031/`） | 当前在 **原厂 Android 16**（slot `_a`，无 sshd、无 `/lib/modules`；`2026-11-17` 21:4x adb 复核）。回 Linux = 重建 GPT 条目 + 刷 `bootslot-b/boot_b.img`（vk192）→ `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md` §3 S3a（**需 C1 放行**）。基线回退：`out/boot_b-before-cdsp-20261007.img`、`bootslot-b/boot_b-clean.img` |

> **★ 熄屏→整机硬复位：已结项（2026-10-24，本注 2026-11-13 更正）** —— 根因 = **RPMh rail retention 档**，上游自 7.3 起「skip retention by default」自带该修复 ⇒ **7.3 血统日常线免疫**（41 发 0 死亡 vs 7.2 的 6/8 死）；用户裁决「不值得继续取证」⇒ 关闭。
> **不作待办**；状态与复启条件只读 `../TASKS/README.md` §5 Q24、`../TASKS/README.md` §1 G1-22/G1-33 行；历史二分过程见 `archive/topics/G1-22-2026-10-05.md`、`REBOOT-5MIN-2026-10-05.md` §7.9。

> **口径纠正（2026-10-03）**：旧记录把 U2 现态写成「固件 1.1.11.073 / locked」，来自上轮 AI 未命中 7、8 月技能而留下的过时条目，**已作废**——以本表实机核验值为准（259 + unlocked）。

### 2.3 状态 → 可派任务（并行性来自状态不重合，不是机器身份）

| 前置状态 | 满足单元 | 可做 |
|---|---|---|
| mainline（b 槽直启 + 持久根） | **U2：需重建**（现为原厂 Android；走 `LINUX-STATE-REPRO` §3，版本仍按 §1.1 首条） | U1 已逆手术，mainline 需重做手术 |
| stock Android + root | **U1** | 固件对照提取、过环境、AVF 资产复采（可选路线） |
| 原厂未动 + **BL locked** | （暂无） | 路 C（EDL 直写）不依赖解锁——管线 `scripts/build-locked-chain.sh` 保留作资产；**U2 已走完解锁，不再命中此行** |
| 原厂未动（**已解锁**，首次手术） | **U2** | GPT dump + 手术 + **RAM 零写盘验收**（`fastboot boot` 可用）；b 槽链已就绪 `bootslot-b-u2/` |
| 纯 RAM（不落盘） | 任一（`fastboot boot bootslot-b/boot_b-minbase-labellinux-20261119.img`；旧 `boot_b_vk40-ram.img` 已不在盘） | 采集/dump/验收，失败即回退 |

### 2.4 目标形态（★v3：不再要求两槽对称）

用户已定：**a 槽 Android 可以不要**——目标之一正是「**在没有 Android 的前提下**完成 ARM Linux 对安卓的兼容」。

```
最小目标形态（任一台单元）：
  b 槽 = mainline（自签 AVB 直启，~9s 进 Phosh）        ← G1/G2 的唯一工作系统
  Linux 分区 = 按项目体量定（见 §3），不再写死 65/128 GiB
  a 槽/Android 专属分区 = 可回收给 Linux（Phase B），或原样保留当回退保险
  回退保险 = EDL 全量包（~/下载/tb322fc/）+ qdl + backup/stock-259/（不再依赖槽位常驻）
```
- Phase A（现在）：只动 **b 槽 + GPT**，a 槽不动 → 零风险拿数据。
- Phase B（G1 稳定后）：回收 Android 专属分区（`super`、`userdata`、`metadata`、`vbmeta_system_*`、`rawdump`、`pstoredump`、LUN4 的 `vendor_boot_*`/`init_boot_*`）
  → 直接腾出**数百 GiB** 给 Linux。**准确口径（2026-11-17 定，取代本行旧名单）：`misc`/`devinfo`/`persist`/`proinfo` 必留；`boot_a`/`dtbo_a`/`recovery_a` 属 A/B 回退槽也留**（回退价值 > 1 GiB）。
  设计、件清单、实验计划与脚本 = **`RUNBOOK-BRINGUP/GPT-MINIMAL-DESIGN.md`**（`scripts/gpt-minimal-build.py`：LUN0 18→10 项、单 `linux` 472 GiB）。

### 2.5 GPT 参数（容量档唯一体现；**禁止跨档复用 GPT 二进制**）

| 参数 | U1（234 GiB 实测） | U2（512 GiB 实测 2026-10-03） | 取法 |
|---|---|---|---|
| 扇区 | 4096 B | 4096 B | `blockdev --getss $BLK` |
| 主表 | LBA0..5 | LBA0..5 | `scripts/gpt-dump.sh` |
| `backup_lba` | `61390847` | **`123871231`**（现 dump；头 0x20 处 8B LE） | `gpt-dump.sh` 会打印 |
| `userdata` | 211.4 GiB | **256.7 GiB**（手术后；first=5972392 last=73277434） | `gpt-surgery-tb322fc.py list` |
| `linux17` | （已删） | **192.0 GiB**（idx16，first=73277435 **last=123609082**，`/dev/sda17`；★2026-10-31 删 `linux18` 后并回，见 §3.3。本表其余列仍为 **2026-10-03 快照**，当时 `linux17` = 193.0 GiB / last=123871226） | 同上（**写前一律以 `scripts/gpt-surgery-tb322fc.py list` 实测为准**） |
| `eldenesp`（ESP） | — | **512 MiB**（idx17，first=123609088 **last=123740159**，EFI System，`/dev/sda18`；2026-11-08 在**尾部空闲区纯追加**，未动任何已有分区，见 `reports/uefi-grub-esp-handoff-wall-20261108.md`）。**现役内容以 `DEVICE/README.md` §1.1 为准**（2026-11-14 现查：`/EFI/BOOT/BOOTAA64.EFI`=`244c5f65…` v3b-bigfont GRUB 嵌入菜单版、`/EFI/elden/Loader.efi`=`6e51fc60…` r73、`/boot/boot.img`=vk190 `54e84588…`、`/boot/{dtbo.img(32M),vendor_boot.img(96M)}`、`/menu.cfg`、`/espboot.force`、`/loader.log`、`/espboot.log`）；**FAT 写后必须 `sync`+`umount` 再 `fsck.vfat -n` 核对文件数**（曾因 dirty bit 被 `fsck -a` 丢掉 `dtbo.img`） | 同上 |
| free slots | 16–31（可加 16 个分区） | 18–31（ESP 占用 idx17） | 同上 |
| boot/dtbo/vbmeta 大小 | 100663296 / 33554432 / 65536 | 同（同型号同布局） | `fastboot getvar partition-size:*` |
| 备份目录规范 | `backup/<SN>-<容量档>/`（**禁用 `new-tablet`**） | 同 | — |

---

## 3. ★ Linux 容量策略（按项目体量决定，不预设固定值）

### 3.1 体量估算表（设备侧占用组成；用于决定 `--linux-gib`）

| 组成 | 实测/估算 | 依据 |
|---|---|---|
| Linux rootfs（Debian 13 最小根 + 桌面 + Mesa + 工具） | 装开后 **15–20 GB**（为 Alpine 期实测口径；Debian 档待按 `df /` 现测回填） | 现测：`/` 已扩到 190 GiB（`resize2fs`，2026-11-19） |
| Waydroid（system+vendor+data+ART 缓存） | **30–50 GB**（压缩镜像 1.25 GB 在手） | `~/下载/` GAPPS `system.zip` 1.17 G + `vendor.zip` 77 M |
| x86 转译 chroot（Ubuntu base + Wine prefix） | **10–15 GB** | `pkgs-x86/`，PoC 已跑通 |
| guest VM 镜像（Debian / Android / Windows ARM） | **每镜像 20–60 GB** | AOSP AVF `custom_vm.md` 建议 ≥10 GB（2026-11-20 注：AOSP 上游文档，不在本仓；需要时看 AOSP `device/generic/avf` 文档）；Windows 更大 |
| 设备侧构建（内核树 + 模块 + ccache） | **25–40 GB** | 主机树 605 M + AOSP 树（体量见 `../RESOURCES/README.md` §2.3；AOSP 不在设备侧） |
| 基准/压测/日志（pstore、perf、worker 日志） | **5–15 GB** | `logs/agent-logs-2026-10-02/` 已 80 M/天 |
| **合计（全都要）** | **约 105–180 GB** | → 512 档可全放；256 档需取舍 |

### 3.2 决策规则（取代"65/128 GiB 固定值"）

1. **一次给足，不反复缩 `userdata`**：GPT 手术缩容不可逆（f2fs 需重建），二次扩容代价高 ⇒
   按 §3.1 的上界一次划足（**512 档建议 160–200 GiB；256 档建议 64–96 GiB**，若同时回收 Android 分区可再放大）。
2. **可再生的大对象不外置到设备**：内核/模块/镜像/归档留主机，用 `sshfs`/NFS/`scp` 按需取；TF 卡未修好前不指望它。
3. **回收 Android 分区是主要扩容手段**（§2.4 Phase B），不是二次缩 `userdata`。
4. 任何改动前先备份分区（**设备侧 `dd` / 官方线刷包解出 / EDL 读回——本机 ABL 无 `fastboot fetch`，`PITFALLS` #290**）+ GPT 双表 dump；改后**读回校验**（回读 md5/sha256，不看"传输完成"）。
5. **文件系统选型（ext4 vs f2fs）**：见 `reports/f2fs-plan-20261021.md`；结论 = f2fs 可行但 P2，随 Phase B GPT 手术一并做（`DEVICE/sessions/2026-10-21-f2fs根分区可行性.md`）。

### 3.3 当前容量决定（2026-10-30 用户裁定；**2026-10-31 已执行完毕**）

- **只保留一个 Linux 分区**：保留 `linux17`（ext4，Debian 根），删除 `linux18`（f2fs，Alpine 回退根）并把空间并入 `linux17`。
  **执行结果（2026-10-31 10:5x–11:0x，总管执行）**：`sda17` = **192.0 GiB**（sectors 73277435–123609082，起点逐字未变）、
  ext4 `50331648 × 4 KiB` blocks、`/` = **188 G，可用 163 G**；`linux18` 已删除，`by-partlabel` 只剩 `linux17`。
  `partx -u` 在线更新分区尺寸 + `resize2fs` 在线扩容，**重启后复验通过**（新 `boot_id`、`/dev/sda17 ext4 /`）。
  GPT 双表 + `sgdisk --backup` 已留档：设备 `/root/gpt-20261031.*`、主机 `backup/gpt-20261031/`（sha 见该目录日志）。
  ⚠ 执行中一次 `sgdisk --new` 默认对齐把起点挪到 73277436（+1 sector）——已用 `--set-alignment=1` 立即改回 73277435 并逐字核验后才 `resize2fs`。
- **Alpine 秒级回退随之退役**；等价回退 = `boot_b` 签名镜像（`boot_b-vk181-daily-signed`/`vk162-rescue` 等）+ 主机侧备份 + 救援镜像。**不再以“重启回 Alpine”作为回退路径**（T19 旧口径作废）。
- **执行顺序（硬约束）**：M3-1 v5 上机实验收尾 → GPT 双表备份（`scripts/gpt-dump.sh`）→ 删 `sda18` → 扩 `sda17` → `resize2fs` 在线增长 → 读回校验（`lsblk`/`df`/`e2fsck -fn`）。设备是单一串行资源，未完成前不得与其它上机 lane 并行。
