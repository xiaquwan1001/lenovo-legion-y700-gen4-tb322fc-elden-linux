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
- ★★**2026-11-10 20:15（当前状态，唯一权威）**：**落盘 UEFI = 干净世代 `pc1`**（`boot_a`，分区 sha `1ca2b8e69167…`，
  件 `out/r21-sbstop-pc1/uefi-preamblec1-r1.img` `40d43397…`）；`active=a`、`retry=7 succ=0 unbootable=0`；
  **flashed 形态实测总耗时 37.0 s**（`fastboot reboot` → SSH；对照 p69 = **129.2 s**，差 92 s 全是 R70 的 25 s×3 停留 + 慢速屏显），
  `/proc/cmdline` 含 `elden_bootloader=esp`、内核 `7.3.1-debug-vk184-00002-g4da9a8b69fc8`（ESP 侧 `\boot\boot.img`）。
  ESP：`\EFI\BOOT\BOOTAA64.EFI` = `\EFI\elden\Loader.efi` = **Loader-r73**（`6e51fc60…`，菜单倒计时可见 + 任何按键即取消自动启动，R72/R73）；
  `\EFI\grub\{grub-menu,grub-stub,grub-chain}.efi` 为 GRUB 三件（**未**替换 BOOTAA64.EFI）；`dtbo_a` = 全 0（UEFI 前置，`scripts/uefi-a-slot-prepare.sh`）。
  **EFI-stub 结论（2026-11-10，三发）**：GRUB 的 `linux`（EFI-stub）交接在本平台**不通** —— pc1/pc2（内存图加 612 MiB Conv）/fbdiag 内核
  三发都是「先只剩背光 → 掉电」，`/sys/fs/pstore` 空 ⇒ 死在 ramoops 注册之前 ⇒ **菜单保持两层**（GRUB 选 loader/重启/关机，loader 选内核）。
  **回滚**：`fastboot flash boot_a backup/boot_a-pre-uefi-20261108.img`（`d4772c11…`，原 Android 内核）+ `fastboot set_active b`。
  **关机**：greetd 停等已压到 10 s（`/etc/systemd/system/greetd.service.d/zzz-faststop.conf`，实测 `final.target` 2 s、`Timed out`=0；
  原件 `rootfs/debian/systemd/greetd.service.d/`，未接生成链 ⇒ 见 `reports/shutdown-greetd-hang-plan-20261030.md` §7）。

- **2026-11-09（历史快照，已被上条覆盖）**：`boot_b` 仍 = `vk185-adsp`（持久，重启即回它）；`boot_a` = 原 Android 内核（已回灌）：`boot_b` 仍 = `vk185-adsp`（持久，重启即回它）；`boot_a` = 原 Android 内核（已回灌）**
  `boot_b` sha256 = `4e38bc2cd46a45b9c458c7f706ab3001a2aa3ccec693f7eb22c3ad0dc3ddb1e5`（自 11-08 起未变）；
  `slot a` = **`unbootable=yes`（故意保留**：防止有人 `set_active a` 又踩同一坑；要用槽 a 先显式 `--set-active=a` 清标志）。
  **「路线 B」启动路径（非默认、零写盘）**：`fastboot boot out/r21-sbstop-p59/uefi-preamble59-r1.img`（`cd73fbdc…`）
  → Mu UEFI（p59）→ R54 定向连 BlockIo → 优先起 ESP(`/dev/sda18`) 的 `\EFI\BOOT\BOOTAA64.EFI`
  → **loader 先读 ESP 的 `\menu.cfg` 出屏显菜单**（音量上/下移动、电源键确认，超时 8 s）
  → 从 ESP 的 `/boot/*.img` 直接起 Linux（**不碰 boot 槽/96 MiB 限制**）。
  现状件：ESP loader = **p60 世代 + R60/R61（含菜单）**（`out/espboot-20261108/Loader-r65.efi` `3523b320…` 为最新；源码快照
  `patches/uefi/20261109R65-loader-snapshot/`）；默认项 `\boot\boot.img` = vk184 `00002`，备选项 `\boot\boot2.img` = vk184 `00003`。
  判据：`/proc/cmdline` 含 `elden_bootloader=esp`、`uname -r` 以 ESP 侧内核为准（与 `boot_b` 的 `00003` 按选项对应）、`boot_b` sha 不变。
  证据通道：ESP 上 `\loader.log`、`\espboot.log`（面板不可靠，`#567`）；`\espboot.force` 是**实验开关**（存在即强制 `BootIntoFastboot=FALSE`，
  绕开 `LinuxLoader.c` 写死的 TRUE，`#565`）——正式化前不要当正式机制用。
  **落地实验（2026-11-08 深夜，已回滚）**：`fastboot flash boot_a` + `--set-active=a` ⇒ ABL 认这个件并跳到它，但 **flashed 形态 ESP 枚举不到
  （`[K] esp fs=1`，`fastboot boot` 形态是 `8`）** ⇒ 回退 FV loader 失败 ⇒ ABL 7 次后自动回 `_b`（**无需救砖**）。
  `boot_a` 已回灌 `backup/boot_a-pre-uefi-20261108.img`（`d4772c11…`）；`uefi_a/imagefv_a/abl_a/xbl_a/GPT` 全程未动。
  **2026-11-09 复测（p61/R62）**：同样负结果 —— 仍 `[K] esp fs=1` → `esp none` → PSHOLD 复位 → ABL 回 `_b`；
  `[K] esp fs2=` 未出现（**不能据此判 R62 无效**，见 `reports/uefi-p61-flash-trial-20261109.md`）。已回灌 `boot_a`、
  `slot` 回 `_b`、`boot_b` `mark-successful`（retry 6→7），`boot_a` 槽属性回到 `retry=7 succ=0 unbootable=0`。
  正文 = `reports/uefi-persist-boot-a-20261108.md`、`reports/uefi-espboot-r58b-success-20261108.md`；
  **下一步计划** = `archive/plans-20261110/2026-11-09-p61-onboard.md`（p61/R62 待上机）。
  **回退**：删/改 ESP 上文件即可；GRUB 原件备份在 `BOOTAA64.EFI.grub.bak`（`7993adfc…`）。
- ★**2026-11-07 深夜（boot_b 身份的权威记录，内容仍有效）：`boot_b` 已写 `vk185-adsp`（持久，重启即回它）** ——
  `boot_b` 分区 sha256 = **`4e38bc2cd46a45b9c458c7f706ab3001a2aa3ccec693f7eb22c3ad0dc3ddb1e5`**
  （= `bootslot-b/boot_b-vk185.img`，100 663 296 B，AVB 自签，公钥 sha1 `1e54e86ef19fad73…`；flash 后**设备侧 dd 读回逐字节一致**）。
  写前备份 = `backup/HA2EXB0E-16+512/boot_b-before-vk185-20261107.img`（`fb55997c…`，旧 vk172 件）。
  槽位 = `boot_b retry=7 succ=1 unbootable=0`（ABL 因 p37 崩溃扣到 6，已用 `slot-attr.py set b --retry 7` 补回）。
  **从 `boot_b` 冷启实测**：30 s 内 SSH、`findmnt /` = `/dev/sda17`、`systemctl --failed` 空、DSI connected、声卡 2 张、
  WiFi（首试 `MHI -110` → `ath12k-retry` try2 关联）、`/dev/fastrpc-adsp`、`zramswap` active；
  `eldroid-bootctl reboot bootloader`（**带新加的 sysrq-b 兜底看门狗**，见 `PITFALLS` #542）→ **4 s 进 fastboot**、
  `fastboot reboot` 回 Linux 正常 ⇒ **G1-24 在新内核上复验通过**。
  件身份：`out/boot-elden-vk185-adsp.img`（`3fa8f7bb…`，85 594 112 B）+ `.manifest`（`kernel_release_matches_image=yes`）；
  UTS `7.3.1-debug-vk184-00003-gec74c4795a43`；tag `vk185`。
- ★**2026-11-07 晚（历史快照，已被上一条取代）：在机 = `vk185-adsp`（`7.3.1` 重基件，RAM 起、`boot_b` 未动）** ——
  `fastboot boot out/boot-elden-vk185-adsp.img`（`3fa8f7bb…`，85 594 112 B）。**全绿**：10 s SSH、`card0-DSI-1=connected`、声卡 2 张、
  WiFi（首试 MHI `-110` → `ath12k-retry` **try2 成功**关联 ustcnet）、`/dev/fastrpc-adsp` + `qrtr svc 400` + `iio-sensor-proxy`
  HasAccelerometer/Light/Proximity **全 true**、`modprobe zram` OK + `zramswap` **7.3 G active**、thermal 44.9 °C。
  **模块树**：`/lib/modules/7.3.1-debug-vk184-00003-gec74c4795a43/`（1499 `.ko`，`INSTALL_MOD_STRIP=1`）；
  另留 `...-00002-g4da9a8b69fc8/`（vk184 首件，同一 payload、无 ADSP DT 修复）。
  **新增一枚 DT**（=`G1-34` 在机真因）：`sm8750.dtsi` 的 ADSP `fastrpc` 节点缺 `qcom,non-secure-domain`（提交树里只有 `cdsp` 有）
  ⇒ 缺它时 `/dev/fastrpc-adsp` 不出现、传感器全哑。上游件在 `patches/upstream/sm8750-adsp-nonsecure-20261107/`。
  ⚠ 记忆点：`/lib/modules` 现在有 **3 棵**树（vk172/vk184-vk185），换 UTS 一定先 `depmod -a <UTS>` 再判显示/传感器。
- ★**2026-11-07（同日早，历史快照）：用户态已补到「日用基线」** —— 设备在 Linux（`vk172`，持久根 `/dev/sda17` ext4），`boot_b` 未动（`fb55997c…`）。
  已装包 **1355 → 1625**（全新增，**0 升级 / 0 删除**）：`sudo`（无口令账户 ⇒ `/etc/sudoers.d/90-elden-desktop` NOPASSWD）、`locales` + `zh_CN.UTF-8`、
  `fonts-noto-cjk`（补前 `fc-list :lang=zh` = **0**）、`gnome-keyring`(+libpam) / `xdg-desktop-portal-phosh` / `gnome-control-center` / `gvfs-backends`、
  `man-db` / `bash-completion` / `vim` / `ncdu` / `command-not-found`、`fcitx5`(systemd user unit，`--disable waylandim`) + Rime、`bluetooth` / `rfkill` /
  `power-profiles-daemon` / `wl-clipboard` / `wtype` / gst 解码插件。固化三件套 = `rootfs/debian/daily-baseline.tsv` + `daily-baseline.sh`
  + `scripts/mobian-daily-baseline.sh`（`--check` rc=0 = 达标，幂等）。
  **未收口**：中文「组词上屏」未证实（合成 `wtype` 按键在 fcitx5/ibus 两臂均为字面量；须屏上真点一次）；
  **内核缺 `CONFIG_ZRAM`** ⇒ `zramswap.service` 已 mask（脚本有内核门；配置侧 2026-11-07 已补 `CONFIG_ZRAM=m`，编进镜像后自动解除）。
  证据 `reports/mobian-daily-baseline-20261107.md`、任务行 `TASKS` G1-37、坑 `PITFALLS` §05 #538–#541。
- ★**2026-11-06 傍晚（历史快照，已被上一条取代）—— 设备在 Linux（`vk172`，持久根 `/dev/sda17` ext4），`boot_b` 未动（`fb55997c…`）**：
  11-05 夜 → 11-06 傍晚两轮 UEFI 实验**全部 `fastboot boot` RAM 件、零写盘**（11-06 傍晚一轮 26 发），
  `a`/`b` 两槽仍 `Bootable:1`；最后一发真启动件崩后 `fastboot reboot` 回 Linux，**无遗留异常态**
  （`TASKS/sessions/2026-11-06-UEFI上机全场走通到跳内核.md` §6.6、`reports/uefi-onboard-walkthrough-20261106.md` §6）。
  ⚠ 11-06 有一发真启动件崩到 USB 只枚举不应答 ⇒ 只能**物理断电**回 fastboot（`PITFALLS #523` 的「一会话一发电平 ≥40」纪律）。
- ★**2026-11-04 深夜（历史快照，已被上一条取代）**：当时设备停在 fastboot，最后 4 发（R9–R12）只 `fastboot boot`，`boot_b` 仍 `fb55997c…`。
  最近一次在机 Linux 记录：`boot_id` `2422f8cd-29dc-4efa-ae01-ebcdd85e531b`、`systemctl --failed` 0、根 `/dev/sda17` ext4。
  历史（2026-11-02）：`boot_id` `109a2bce-b3e9-4648-a4be-03aed6862764`、`uname -v` `#1 SMP PREEMPT Fri Oct 30 19:00:42 CST 2026`（UTS `…vk172`）、
  根 `/dev/sda17` ext4、`current-slot=_b`、**a/b 两槽均 `Bootable:1`**、`systemctl --failed` **0**、
  `boot_b` 分区 sha256 = **`fb55997c524ea26201841b5fdcc657c011423c7049766f7e36d5d994b3c35169`**（与本轮备份件逐字节一致）。
  本轮（UEFI ① 四臂判别）只在 `boot_b` 上写过 3 轮载荷、每轮都刷回本备份并读回核验；`a` 槽的 unbootable 位已复原（GPT 主/备双表 + CRC，脚本 `scripts/slot-attr.py`），
  原始双表留档 `reports/artifacts/uefi-ddrcut-20261101/lun4-gpt-{primary,backup}.bin`。报告 `reports/uefi-ddrcut-fallback-20261101.md`。
  **改非活动槽属性必须用 `scripts/slot-attr.py` 直写 LUN4**（`qbootctl -u a` 在活动槽为 b 时必失败，`PITFALLS #487`）；
  **ABL 在 b 槽失败后会自己切活动槽到 a 并清其 unbootable**（`PITFALLS #487` 追加条）。
- ★**不随镜像漂移的操作约束（动手前必读；镜像号/sha/分区数字只读上一条与本文件 §2.5/§3.3）**：
  - **写 `boot_b` 后必须读回核验并核 AVB 身份**：`python3 tools/avbtool.py info_image --image <件>`（签名实际取值 `KEY=bootslot-b/avb.key`，见 `scripts/sign-boot-b.sh`）；换机后 AVB 公钥已重建 = `sha1 1e54e86ef19fad73…`（旧 `fc1e3b33…` 作废），`vbmeta_b` chain descriptor 已同步重签（`scripts/sign-boot-b.sh`；`PITFALLS #313`）。
  - **`linux18` 已删除**（2026-10-31 并根）：`by-partlabel` 只剩 `linux17`，运行根 = `/dev/sda17` ext4 `LABEL=linux17` ⇒ 历史条目里「回退 = 重启回 Alpine `linux18` f2fs」的口径**已失效**（分区数字只读 §2.5 与 §3.3）。
  - **模块树**：`/lib/modules/<UTS>` 被 vk163/vk172/m3v5 等多代镜像共用（`uts_dup`，见 `versions/vk-ledger-known-issues.tsv`）；**换新 UTS 内核必须先部署模块树再判显示**，否则 `lsmod` 空 ⇒ DP defer ⇒ 无 `card0`（`PITFALLS #293`）。
  - **相机时钟模块必须是原版**：持久根 `/lib/modules/<vk64KV>/drivers/clk/qcom/cambistmclkcc-sm8750.ko`（md5 `88a45177…`，备份 `/root/q24bak/`）——换入实验版会让任何自动加载相机的启动挂死（`PITFALLS #177`）。
  - **自建 boot.img 上机前先核三条件**（`PITFALLS #468`），否则会出现「USB 整个消失」且只能靠物理断电回 fastboot；覆盖前用设备侧 `dd` 备份（本机 ABL 无 `fastboot fetch`，`PITFALLS #290`）。
- **沿革（2026-10-10 → 2026-11-01 的逐轮在机快照：vk64/vk94/vk113/vk124/vk127/vk145/vk147/vk152/vk163/vk173/vk181/vk182/vk183 与 f2fs/Debian 换根全过程）** → `sessions/2026-11-02-在机状态沿革-vk64..vk172.md`（本节只维护「当前在机」一条 + 上面这组约束，避免与 `SESSIONS/`、`HISTORY/` 三处复写）。
- **Linux 侧提交的唯一入口 = `../TASKS/README.md` §7**（原沿革尾部条，随沿革搬家后在此保留指针）。
- ★**2026-10-15 晚：M1-7.3 模块树已补齐并部署**（此前持久根 `/lib/modules/7.3.0-rc7-debug-ged6f232d10e3` **不存在** ⇒ 该内核下**所有 `=m` 驱动不可加载**、`cam-mode.sh`/`camera-modules-load.sh` 静默失效，`PITFALLS #282–#284`）。现状态：`/lib/modules/7.3.0-rc7-debug-ged6f232d10e3/` = **1497 个 `.ko`**（`depmod -a` 已跑），**vermagic 与 `uname -r` 逐字相等**；来源 tarball `out/m1-73-modules-7.3.0-rc7-debug-ged6f232d10e3.tar.gz`（20 MB，sha256 `c0702e56c5f5…`；⚠️MIGRATION-LOST — 该 tarball 已轮转不在盘（2026-11-05 实测），可由 `build/m1-73` 重编复现；分区侧 1497 个 `.ko` 事实不变）；树侧 config 与设备 `/proc/config.gz` **diff=0**。**实测生效**：相机栈可加载（`/dev/media0` + 17 `/dev/video*`，双摄绑定）——**但出流仍失败**（`STREAMON` EINVAL/EPIPE，详见 `../TASKS/README.md` C5 与 `reports/m1-73-modules-p0-20261015.md`）。**构建侧两条硬规则**：① 该树改配置/编译**一律带 `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`**（裸 `make` 按 x86 求值会静默删 `ARCH_QCOM`）；② **必须 `export LOCALVERSION=`**，否则 git worktree 会让 vermagic 多一个 `+` ⇒ `depmod` 全绿但**上机必被拒**。
- ★**2026-10-18：冷起无桌面 = `greetd` 崩（已修）** —— 面板/DRM 正常（`card0-DSI-1=connected`）但 `loginctl` 无会话、`rc-status` 里 `greetd [crashed]`。修法：initd 补 `after seatd elogind` + `supervise-daemon` 守护（源文件入库 `rootfs/persistent-overlay/etc-initd-greetd`，设备备份 `/etc/init.d/greetd.bak-20261018`）。判据链与手工救场见 `PITFALLS #318`，报告 `reports/camera-linux-vk127-20261018.md` §2。
- ★**2026-10-19：WiFi 候选榜塔成「只剩已连接项」已修** —— 不是 ath12k 问题；NM 1.52 连通态**不做**周期扫描且 `bgscan` 写死 `simple:30:-70:86400`（连接级属性不被读取）⇒ supplicant BSS 缓存过期被清 ⇒ AP 对象被删。根因链与实测见 `PITFALLS §52 #354–#356`、`reports/wifi-scan-stale-20261019.md`、`TASKS` G1-36。**设备侧服务**：`wifi-scan-refresh`（OpenRC `default`，源文件 `scripts/wifi-scan-refresh.sh` + `rootfs/persistent-overlay/etc-initd-wifi-scan-refresh`），参数 `/etc/conf.d/wifi-scan-refresh` 的 `WIFI_SCAN_INTERVAL=150`（**必须 <180 s**，否则仍会被 supplicant 的 `bss_expiration_age` 清掉）；未连接时自动跳过（NM 自扫 ≤120 s）。判活：`/usr/local/sbin/wifi-scan-refresh.sh --check` + `grep -c 'requested scan' /var/log/wifi-scan-refresh.log`。
- ★**2026-10-17 晚：重放镜像 `vk127` 已通过冷起验收（仍未写盘）** —— `backup/out-history-20261105/boot-elden-vk127.img`（sha `7515f6a4…`，85 585 920 B）=
  **7.3-rc7 + 下游 `vk64` 树 payload（cambist 回上游 parity）+ M1 DSI 1 行**，config = `config-daily-c1` + C1 片段；
  真 POR 冷起 **3/3 GOOD**（`l1=0`、`dsi_isr=41`、目视有桌面）+ 功能抽查全绿（WiFi/音频/fastrpc-adsp/SensorProxy）。
  **★2026-10-18 上午：`boot_b` 已刷写 = `vk127`（读回校验）** —— 签名件 `bootslot-b/boot_b.img`（100 663 296 B，`sha256 83d4e08add88abd2…`）与设备 `dd /dev/disk/by-partlabel/boot_b` 逐字节一致；在机 `uname -r` = `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`。
  ⚠️ **换机后 `tools/avbtool.py` 与 `bootslot-b/avb.key` 已丢失并重建**：新 AVB 公钥 `sha1 1e54e86ef19fad73…`（旧 `fc1e3b33…` 作废），`vbmeta_b` chain descriptor 已同步重签（`scripts/sign-boot-b.sh`；`PITFALLS #313`）。本轮冷起 Q28 **7 发坏 / 第 8 发 GOOD**。
  模块树 `/lib/modules/7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty/`（1497 `.ko`）已部署在持久根。
  ⚠️ **换新 UTS 内核必须先部署模块树再判显示**，否则 `lsmod` 空 ⇒ DP defer ⇒ 无 `card0`（`PITFALLS #293`）。配方 `reports/replay-2026-10-17-m1-73-vk127.md`。
- **2026-10-10 离线快照（Q28 调试轮收尾；本轮整理时 adb/fastboot 均无设备在场）**：boot_b **持久直启仍 = `vk64`（未动）**；本轮 vk74/vk84 仅 `fastboot boot` RAM 取证，**永不作 boot_b**。Q28 根因/双模式/判据/下一步见 `reports/q28-DOSSIER.md`、`../TASKS/README.md` §5 Q28。
- **主机串口 logger** = `scripts/serial-logger.sh`（pid 文件 `/tmp/q28_serial_logger.pid`，常驻；主机重启需重跑）。**判 Q28 显示不能只靠串口 logger**（重连会漏 0–20 s，盖住 NOCARD 的 0.86 s 现场），须 SSH 读全 dmesg + 查 `card0`。
- ★**2026-10-17 晚：相机 AE 正解 = libcamera 侧 sensor helper（用户态，与内核 UTS 无关）**：设备 `/usr/lib/libcamera/ipa/ipa_soft_simple.so` 已换成自编版（含 `s5kjns`/`gc08a8` 的增益模型 + 黑电平 4096；主机交叉编译，配方 `reports/camera-ae-helper-20261017.md` §2），原包备份 `/root/ipa-bak-20261017/`。**相机驱动 `.ko` 保持原版**（增益码语义未改，`/root/cam-ko-bak-20261017/` 里的补丁版只属 vk127 目录、未使用）。相机栈仍需 `CAM_FORCE=1 camera-modules-load.sh` 手动加载（cmdline `elden_nocamera=1`）。
- `CONFIG_LOCALVERSION` 一变，相机 20 个 `.ko` 必须整套重编（vermagic 耦合）；vk50 起模块化后驱动可单独重编。
- **容器（Waydroid）侧在机资产（2026-10-13，TASKS C10 三期）**：`/var/lib/waydroid/images/vendor.img` 已**固化**自编 AIDL V2 vibrator HAL（`/vendor/bin/hw/android.hardware.vibrator-service.elden` + rc + vintf fragment）与静态 RRO `EldenVibrationOverlay`（`/vendor/overlay`，把 Settings 振动强度档位 1→3）；运行期只剩宿主 daemon `elden-hapticd`（OpenRC + `/etc/conf.d`）与一条 `sys/class/leds` 桥挂载。**回退镜像** `/var/lib/waydroid/images/vendor.img.bak-elden-haptics-20261013-115055`；复现 `scripts/waydroid-haptics-bake-patch.py` + `bake-vendor.sh`；细节 `reports/waydroid-haptics-20261013.md`、踩坑 `PITFALLS #232–#246`。 **★2026-10-29**：当前在机 `vendor.img` = **打过 camera gralloc 布局修复补丁**的版本（`/lib64/hw/camera.device@3.{4,5,6}-external-impl.so` + `provider@2.{4,5}-external.so` 五个文件替换，镜像 sha256 `82769ed6…`，其余字节与 10-19 镜像相同）；该次推送前的回退件 = `/var/lib/waydroid/images/vendor.img.bak-l1d-20261029-103701`。

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
两个 `usb-c-connector`（`connector@0`/`@1`）各绑一颗 SMB1501（`smb1501@0x43`/`@0x42`），
充电由 **ADSP `battery_charger`** 经 PMIC-GLINK 决定用哪一口/哪颗。

| 观测 | 实测值（2 s 粒度采样，用户物理插拔） |
|---|---|
| **长边 = PC(SDP)** + 短边 = PD | 电池 **0.29–0.33 A**；`ucsi.01/02` 均 online（短边 PD 契约 3 A、`port1-partner/pd0` 存在）；`qcom-battmgr-usb` 报 5.05 V / 891 mA |
| 拔掉短边 PD（仅长边 SDP） | 电池 0.19→0.39 A（充电算法爬升）；`ucsi.02` offline；`qcom-battmgr-usb` 报 4.71 V / 891 mA |
| **拔掉长边 PC，仅短边 PD** | 电池 **0.199 A → 12.21 A（40 s 内爬升）**，`capacity` 19%→27%（≈+600 mAh）；**短边 PD 单独 = ≈46 W 真快充** |
| 长边 PC 插回（两口都在） | 立刻回落到 **0.18–0.19 A**，只吃长边 SDP |

**结论（已证）**

1. **不是硬件单口**：短边 PD 单独可跑 12.2 A。
2. **不是「内核只认一口」**：内核逐口建模（两个 `typec/port*`、两个 `ucsi-source-psy-*`、两颗 SMB1501 都在 DT 与 `/sys` 里）。
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
| **U2** | `HA2EXB0E` | `SM8750P_16+512_13` | 16 G / ~476 GiB | **BL 已解锁** · stock **259**（Android 16；Widevine **L1**）。**进 Android = `fastboot --set-active=a` + `fastboot reboot`（无需刷 dtbo，实测 2026-10-11，HANDOFF §20 再次成立）**；未 root、无 Google 账号。C0 基线已采：`backup/HA2EXB0E-16+512/c0-baseline/` | **mainline 持久直启**（当前运行根与 boot_b 形态**只读本节 §1.1 首条**，本行不维护这些数字）；`recovery_b` 已刷 TWRP。**外设/驱动功能状态不在本表维护**，一律看 `../TASKS/README.md` §0/§1「未解项只读 §5」 | **已手术（2026-10-25 二次手术 = f2fs 并存；2026-10-31 `linux18` 已删除并入 `linux17`）**：`linux17` ext4 **192.0 GiB**（idx16，`/` 可用 163 G；分区参数与扇区见 §3.3）+ `userdata`=256.7 GiB；双表 dump 在 `backup/HA2EXB0E-16+512/`（手术前基线另存 `gpt-20261025/`，合并/扩容日志 `backup/gpt-20261031/`） | 当前在 **Linux**（b 槽持久直启，环境可 SSH）。基线回退：`out/boot_b-before-cdsp-20261007.img`、`bootslot-b/boot_b-clean.img` |

> **★ 熄屏→整机硬复位：未解（间歇性）**。根因已锁定为单模块 `cambistmclkcc-sm8750` × DT 电源域耦合（H1/D1/D2/H2 均未根治）；**无相机模块态安全**。设备侧规避（持久根现状，不得轻改）：cmdline `elden_nocamera=1` + `/etc/modules-load.d/camera.conf` 置空 + `idle-delay=0`。
> 状态/样本数以 `../TASKS/README.md` §5 Q24 为准；历史二分过程见 `archive/topics/G1-22-2026-10-05.md`、`REBOOT-5MIN-2026-10-05.md` §7.9。

> **口径纠正（2026-10-03）**：旧记录把 U2 现态写成「固件 1.1.11.073 / locked」，来自上轮 AI 未命中 7、8 月技能而留下的过时条目，**已作废**——以本表实机核验值为准（259 + unlocked）。

### 2.3 状态 → 可派任务（并行性来自状态不重合，不是机器身份）

| 前置状态 | 满足单元 | 可做 |
|---|---|---|
| mainline（b 槽直启 + 持久根） | **U2**（b 槽持久直启在跑；当前镜像版本看 §1.1） | U1 已逆手术，mainline 需重做手术 |
| stock Android + root | **U1** | 固件对照提取、过环境、AVF 资产复采（可选路线） |
| 原厂未动 + **BL locked** | （暂无） | 路 C（EDL 直写）不依赖解锁——管线 `scripts/build-locked-chain.sh` 保留作资产；**U2 已走完解锁，不再命中此行** |
| 原厂未动（**已解锁**，首次手术） | **U2** | GPT dump + 手术 + **RAM 零写盘验收**（`fastboot boot` 可用）；b 槽链已就绪 `bootslot-b-u2/` |
| 纯 RAM（不落盘） | 任一（刷 `bootslot-b/boot_b_vk40-ram.img`） | 采集/dump/验收，失败即回退 |

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
- Phase B（G1 稳定后）：回收 Android 专属分区（`super_a/b`、`boot_a`、`dtbo_a`、`recovery_a`、`metadata`、`misc`…）
  → 直接腾出**数十至上百 GiB** 给 Linux，这同时回答"容量不够"的问题。回收前必备 EDL 包与 stock 备份。

### 2.5 GPT 参数（容量档唯一体现；**禁止跨档复用 GPT 二进制**）

| 参数 | U1（234 GiB 实测） | U2（512 GiB 实测 2026-10-03） | 取法 |
|---|---|---|---|
| 扇区 | 4096 B | 4096 B | `blockdev --getss $BLK` |
| 主表 | LBA0..5 | LBA0..5 | `scripts/gpt-dump.sh` |
| `backup_lba` | `61390847` | **`123871231`**（现 dump；头 0x20 处 8B LE） | `gpt-dump.sh` 会打印 |
| `userdata` | 211.4 GiB | **256.7 GiB**（手术后；first=5972392 last=73277434） | `gpt-surgery-tb322fc.py list` |
| `linux17` | （已删） | **192.0 GiB**（idx16，first=73277435 **last=123609082**，`/dev/sda17`；★2026-10-31 删 `linux18` 后并回，见 §3.3。本表其余列仍为 **2026-10-03 快照**，当时 `linux17` = 193.0 GiB / last=123871226） | 同上（**写前一律以 `scripts/gpt-surgery-tb322fc.py list` 实测为准**） |
| `eldenesp`（ESP） | — | **512 MiB**（idx17，first=123609088 **last=123740159**，EFI System，`/dev/sda18`；2026-11-08 在**尾部空闲区纯追加**，未动任何已有分区，见 `reports/uefi-grub-esp-handoff-wall-20261108.md`）。**2026-11-09 内容**：`/EFI/BOOT/BOOTAA64.EFI`=路线 B 的 loader（p60 世代 + R60/R61 菜单；最新 `Loader-r65.efi` `3523b320…`，源码快照 `patches/uefi/20261109R65-loader-snapshot/`；GRUB 原件另存 `BOOTAA64.EFI.grub.bak`）、`/boot/{boot.img(85.6M,含令牌),boot2.img(备选 vk184-00003),vendor_boot.img(96M),dtbo.img(32M)}`、`/menu.cfg`、`/espboot.force`（实验开关）、`/loader.log`、`/espboot.log`；**FAT 写后必须 `sync`+`umount` 再 `fsck.vfat -n` 核对文件数**（曾因 dirty bit 被 `fsck -a` 丢掉 `dtbo.img`） | 同上 |
| free slots | 16–31（可加 16 个分区） | 18–31（ESP 占用 idx17） | 同上 |
| boot/dtbo/vbmeta 大小 | 100663296 / 33554432 / 65536 | 同（同型号同布局） | `fastboot getvar partition-size:*` |
| 备份目录规范 | `backup/<SN>-<容量档>/`（**禁用 `new-tablet`**） | 同 | — |

---

## 3. ★ Linux 容量策略（按项目体量决定，不预设固定值）

### 3.1 体量估算表（设备侧占用组成；用于决定 `--linux-gib`）

| 组成 | 实测/估算 | 依据 |
|---|---|---|
| Linux rootfs（Alpine + 桌面 + Mesa + 工具） | 装开后 **15–20 GB**（归档规格见 `../RESOURCES/README.md` §2.2） | `env-pass/backup-20261002/linux17-rootfs-…tar.gz` |
| Waydroid（system+vendor+data+ART 缓存） | **30–50 GB**（压缩镜像 1.25 GB 在手） | `~/下载/` GAPPS `system.zip` 1.17 G + `vendor.zip` 77 M |
| x86 转译 chroot（Ubuntu base + Wine prefix） | **10–15 GB** | `pkgs-x86/`，PoC 已跑通 |
| guest VM 镜像（Debian / Android / Windows ARM） | **每镜像 20–60 GB** | AOSP AVF `custom_vm.md` 建议 ≥10 GB；Windows 更大 |
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
