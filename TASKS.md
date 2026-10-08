# 任务拆解与进度（TASKS）

> 领域层活文档之一；文档分三层（领域 / 元 / 证据），定义与 SSOT 见 `INDEX.md` §2。
> **本文件是唯一任务台账**：所有 ID、状态、下一步只在这里维护；专题文档只放过程与证据。
> 纪律：worker 只报「命令 + 原始日志」，编排者**独立复跑**；每步留回退；设备锁串行、主机侧并行。

---

## 0. 进度总览（数字）

| 目标 | 已完成 | 进行中 | 未开始 | 完成度 |
|---|---|---|---|---|
| **G1** 完整 Linux + 上游化（驱动原厂固件 + 上游提交） | 27 项（显示/图形/触屏/网络/电源/**相机出流+App 实测**/音频播放+输入/温控/串口/**CDSP**/**DP**/**BT 配对+TWS 实听**…） | 1（TF 卡；另 **WiFi 到可用**（Q26 **重开**：**撤销「P40 Pro 热点组合已知限制」归档**——用户指出同一 P40 Pro 在早期版本可正常连接 ⇒ 假设=**版本/DTB 增量连带副作用**；下一步版本/DTB 单变量 bisect，见 §5 Q26））；**上游化 M1–M5 未开工**（`§7`） | 0 | **~90%** |
| **G1-22/Q24 熄屏→复位/关机** | 🟢 H2（cambist 单挂 MX 电源域，vk63）用户实机确认健康（2026-10-07）：手动多次电源键熄屏/唤醒循环无掉电（见 §4/§5） | — | — | — |
| **G2** 安卓容器（可用性 + 风控/完整性等级） | 6（Waydroid 图形/内核/GAPPS 镜像/代理通路/Win-x86 PoC/**C9 用例集**） | 4（Play 登录收口、切槽脚本、C8 上机探测、**C4 部署验证**——代码/编译全就绪） | 4（相机共享、音频容器、C3 实测…） | **~45%** |
| **G3** x86 模拟（Steam 载体） | 1（Box64 0.4.5 + Wine 9 **PoC 成功**） | 0 | Steam 游戏端到端（图形/音频/性能） | PoC ✅ / Steam 未上机 |
| **拓展** UEFI 间接引导 · Gunyah VM | 0 | 0 | 2（UEFI 路线 A 已搜置；Gunyah 待上机探测） | ⬜ 非主线 |
| 运维/资产 | 内核 vk61、rootfs 归档、Mesa 包、文档集重构、`qemu-utils` 已装（A13）、fstab nofail 已修（A18）、**C4 传感器链（A14）**、**env-pass provision（A17）**、**持久根内核↔模块对齐（2026-10-05）** | — | — | ✅ |

---

## 1. G1 任务分解（功能健全的 Linux + 原厂固件全部驱动）

| ID | 任务 | 状态 | 单元状态要求 | 验收判据 | 关键文件 |
|---|---|---|---|---|---|
| G1-0 | **U2 BL 解锁** | ✅ **已完成（2026-10-03）**——走**降级路**：线刷 `TB322FU_ZUXOS_1.1.11.073`（出厂 1.1/Android15）后 `fastboot oem unlock` 一次成功。第三方 blob（A3）与官网 sn.img（B）未用上且**已判死**（四代 1.5.x 换 ABL key）；路 C（EDL+testkey 链）成**保留资产**（`build-locked-chain.sh` 验证全绿） | U2 | ✅ `unlocked:yes`、`oem device-info: Device unlocked=true / critical unlocked=true` | `PITFALLS` #86–#87、`RUNBOOK` §0.5、`archive/topics/复盘-2026-10-03-BL解锁.md` |
| G1-1 | vk40 基线上机（持久直启） | ✅ **已完成（2026-10-03 U2）**：b 槽刷 blank dtbo + vk40 RAM 直启，后切持久版；重启后 `findmnt /`=`/dev/sda17`（ext4），**Phosh 自启**（phoc/phosh/gnome-session 在跑）。踩坑：`fastboot boot` 不清 dtbo 会卡 logo（`PITFALLS`/`复盘.md`） | U2（**已解锁**） | `uname -r`=`7.2.0-debug-gba28ec16f01f-dirty`；`findmnt /` 持久根=linux17 | `RUNBOOK-BRINGUP.md`、`bootslot-b/boot_b_vk40.img` |
| G1-2 | GPT 手术：按 §3.2 体量给 `linux17` | ✅ **已完成（2026-10-03 U2）**：`userdata` 449.7→**256.7 GiB**、新增 `linux17`=**193.0 GiB**（idx16，`/dev/sda17`）；写后重 dump 校验 CRC OK | U2 | `list` 读回：`linux17` 末扇区=`last_usable`、CRC OK | `backup/HA2EXB0E-16+512/gpt_{main0,backup0}.bin`、`gpt_post-surgery_*` |
| G1-3 | 恢复持久 rootfs（3.44 GB 归档） | ✅ **已完成**：`mkfs.ext4 -L linux17` + 解包 30852 项（8.3 GB）→ 持久根 | U2 | `df /` 与归档项数一致；Phosh 自启 | `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz` |
| **G1-23** | **vk34→vk40 未验证增量回归审核** | 🟡 **未取到有效样本（第二/三遍，2026-10-03）**：逐 hunk 分类 N1–N4 + V1/V2 二分；`vk40re` vblank=6/PPM=1 vs `vk34recon` 0/0（可量化）；排除「副作用在轮询内」(0 条)；真隐患=「reboot 与长轮询同命令被 harness 杀死」(4/10 `Command aborted`)；**新混淆：持久 `boot_b`=vk40 内核 ⇒ 跨版本复位比较作废**。下一步：先烧 `bootslot-b/boot_b-vk34recon.img` 作已知基线 | 任一 mainline | 同口径 dmesg 计数（V1/V2 各 ≥1 有效样本）+ 各版 ≥3 轮长时窗 | `archive/topics/AUDIT2-post-vk34-bisect-2026-10-03.md`、`AUDIT3-polling-sideeffects-2026-10-03.md`、`AUDIT-since-vk34-2026-10-03.md`、`TASKS §5 Q22` |
| **G1-22** | **熄屏/睡眠稳定性（Q24）** | 🟢 **H2 收盘（2026-10-07 用户实机确认）**。根因（60+ 轮二分）=单模块：**`cambistmclkcc-sm8750`（相机 BIST MCLK 时钟控制器）单独加载即触发熄屏→硬复位**（原 DTB 3/3）；`qcom-camss`/`camcc-sm8750`/`i2c-qcom-cci`/`wl2868c-regulator` 各 3/3 **存活**；**零相机模块对照 3/3 存活**；`system_heap` 无罪。pstore/kmsg 无痕（硬复位型）。**H1**（DTB 去该节点 `power-domains=RPMHPD_MMCX/MX`+`required-opps`）→ cambist 单独 **7/9 存活**，未根治 ⇒ 间歇。**D1（`use_rpm=false`）6/9 存活、D2（去 `critical_cbcrs`）7/9 存活均无改善 ⇒ 驱动侧不是主因**。**H2 收盘**（cambist 单挂 MX 电源域）⇒ **vk63** 用户实机确认健康（加载 cambist + 真实熄屏 + 多次电源键循环无掉电），详见 G1-33/§5 Q24 | 任一 mainline | 装相机模块后长时空闲不断电 | `.pi/plans/2026-10-07-dp5基线-相机补全-加速度.md`、`scripts/sleep-sweep.sh`、`out/boot-elden-vk63.img` |
| **G1-24** | **Linux 侧刷机控制**（reboot→fastboot、选槽、清启动次数） | ✅ **S1/S2 已交付（2026-10-03 深夜实测）**：`scripts/eldroid-bootctl` + `flash-recovery.sh`；内核分支 `elden/vk41-psci-reboot` 把 reason `bootloader`/`edl` 映射为 **PSCI SYSTEM_RESET2 vendor reset**，`reboot bootloader` 真进 fastboot（否定 SDAM/BCB 三路）。⚠️ 上游该机制为 13 补丁大系列（未合并），本树是最小设备侧钩子。剩：`reboot edl` 实测、TWRP 路线、slot 写校验（合流 C7） | 任一 mainline | `reboot bootloader` 进 fastboot ✅；slot 写后读回校验 | `archive/topics/FLASHCTL-2026-10-03.md`、`scripts/eldroid-bootctl`、`PITFALLS` #88 |
| **G1-25** | **桌面电源/会话（无 systemd）** | ✅ **已真机验证（2026-10-03 深夜）**：真根因=elogind helper `/sbin/{poweroff,reboot,halt}` 是 busybox applet，**不带 `-f` 只 `kill(1,…)`**，而 PID1=`/init`(shell) 不处理 → 假成功并让 elogind 永久卡 `OperationInProgress`。修复=`scripts/fix-logind-poweroff.sh`（换 `busybox <applet> -f`，幂等）。⚠️ USB 连着时 `loginctl poweroff` 会立即重启（疑 VBUS/充电检测自动开机）→ 关机前先断 USB | U2 | 长按电源键→菜单「立即关机」真断电 | `archive/topics/LOGIND-POWEROFF-2026-10-03.md`、`PITFALLS` #89、`scripts/fix-logind-poweroff.sh` |
| **G1-26** | **用户态深色模式 / 主题配色切换无效**（Phosh 0.55，Alpine） | 🟠 **根因已定位（2026-10-05，lane `dt-ui` 会话 `01a10736-a2dd`）**：`gtk-theme='Adwaita-dark'` 在 GTK3 **解析失败→回退浅色 Adwaita**（深色变体应靠 `prefer-dark`+主题名 **`Adwaita`**）。无头 GTK3 探针证实：`Adwaita-dark+prefer-dark` → 浅色（fg=`rgb(46,52,54)`）、`Adwaita+prefer-dark` → 深色（fg=`rgb(238,238,236)`）。**修复=`gtk-theme='Adwaita'`**（待上机落 dconf）。accent 同源：phosh 源码对 `theme_name=='Adwaita-dark'` 提前 return ⇒ 改 `Adwaita` 后放行。⚠️ 操作坑：`gsettings` 写入须 `dbus-run-session`（裸写不生效，见 `PITFALLS` #103） | U2 | 切深色/换 accent 后 Phosh 与 GTK4 应用即时变化且重启保持 | `archive/topics/DT-UI-2026-10-05.md`（lane 未提交，父代为落盘） |
| **G1-27** | **长按电源键菜单图标反色**（关机/紧急联系/锁屏等图标非常黑、深色背景分不清） | 🟠 **与 G1-26 同一根因**（symbolic 图标取主题前景色；浅色主题→近黑前景画在深色弹窗上）。修复同上 | U2 | 电源菜单四图标在深色背景下清晰可辨 | 同 G1-26 |
| **G1-28** | **状态栏亮度滑块无效**（亮度固定） | 🟠 **根因定位（2026-10-05，`dt-ui`+父内联）**：背光 `/sys/class/backlight/aw99706-backlight`（max 4095）**可写且生效**，但 elogind `Session.SetBrightness` 对**任意** name 均返回 `EISDIR`；elogind 255.24 走「writer 子进程 + `/sys/class/tty/tty0/active`」，本机 **`loginctl list-sessions` 空、无 VT** ⇒ 链路断。候选 A/B/C/D（起 session+VT / 换 elogind / 走 Phosh sysfs 后端 / root 守护桥接）**待拍板**。**↳ 候选 A 已实机取证（2026-10-05，`01a10ba8`/lane `userland-session`）**：`greetd initial_session` 建真 logind 会话后，`login1.Session.SetBrightness backlight aw99706-backlight 1800` → sysfs **511→1800**（此前无 session 恒 `EISDIR`）⇒ **核心链路已解**；剩 Phosh 滑块 UI 联动待确认 | U2 | 滑块拖动即改变 `actual_brightness` 且 UI 同步 | `archive/topics/DT-UI-2026-10-05.md` §4、`archive/topics/USERLAND-PKGS-2026-10-05.md` §U1 |
| **G1-29** | **间接引导层（GRUB 类/UEFI）——摆脱 boot.img 96 MiB 限制** | ⛔ **路线 A 上机失败 ⇒ 搁置（2026-10-05 用户定）**。机制（lane `bootchain`）：四代 UEFI 被拆成 `uefi_a`/`imagefv_a`/`abl_a` 由 XBL 加载，ABL 不扫 FAT、无现成启动 FAT。**上机：本地编译链通、壳机制成立、能进 BDS，但 UFS 初始化过不去**（UFSDxe ASSERT / Sync Exception + SCM mailbox/QBSS/CPU_Vectors 缺失）⇒ Mu Pakala 移植层系统性缺口，非单点可解；已发上游 `mu_wide_platforms#12`。**96 MiB 限制已被 G1-30/vk61 实际解决 ⇒ UEFI 不构成主线依赖** | U2（只读） | 出现 GRUB/BDS 菜单 + `root=LABEL=linux17` | `archive/topics/BOOTCHAIN-2026-10-05.md`、`UEFI-UFS-BRINGUP-2026-10-05.md`、`UEFI-UFS-UPSTREAM-ASK-2026-10-05.md`、`TASKS §5 Q25` |
| **G1-30** | **boot.img 立即瘦身（=G1-29 路线 C）** | ❌ **口径更正（2026-10-06）**：slim 能打到 20.8 MiB，但 **vk60 实机=进桌面、外设全不可用**——**归因 = initramfs 打包（最小 initramfs 无 `/lib/firmware`），不是驱动/内核**（`PITFALLS` #113/#115、`archive/topics/ATTRIBUTION-AUDIT-2026-10-06.md`）⇒ **slim 不作日常启动**。boot_b 替换版改走 **vk61**=原完整 ramdisk 只换修好的 `/init`（内核/固件/模块零回归，83.3 MB < 96 MiB，已零写盘验收）。真机 busybox **有 findfs、无 blkid/mountpoint**（#112） | U2 | —（slim 不用于日常启动） | `archive/topics/BOOTSLIM-2026-10-05.md`、`INIT-HARDEN-2026-10-06.md` §9–§11、`out/boot-elden-vk61.img` |
| **G1-31** | **GNU 用户态工具补装**（AI 调试高频失效率） | ✅ **已完成（2026-10-06 U2）**：`coreutils findutils grep sed gawk procps-ng curl wget jq rsync socat tcpdump zstd xz tree less`（735→760 包，world 104→120 行）。设备无默认路由 ⇒ 借**主机代理** `http://192.168.7.2:7897`。**重启回归 ×2 通过**（GNU 会 shadow busybox，含 init 同 PATH）。 | 任一 mainline | `sed/grep/find/sort/awk/curl/jq --version`、`ps -p 1`、`date -d '1 hour ago'` 全 rc=0 | `.pi/plans/2026-10-06-用户态查漏补缺.md` P1、`PITFALLS` #120/#121/#122、`rootfs/build-rootfs.sh` |
| **G1-32** | **OpenRC 化（init 交接，替代自研服务编排）** | ✅ **已完成（2026-10-06 U2）**：Alpine OpenRC 已装但 `runlevels` 空 ⇒ `/init` 保生命线（usb0/sshd/ttyGS0）后按 `/etc/elden-init-mode` `exec /sbin/init` → inittab → openrc。**PID1=`/sbin/init`**；`rc-status default` 全 `started`；**G1-25 关机链结构性修复**（干净 `loginctl reboot` 实测通过，wrapper 按模式选 `-f`）。回退 `echo legacy >/etc/elden-init-mode; reboot`。 | 任一 mainline | `rc-status` default 全 started + `ps -p 1` = `/sbin/init` + `loginctl reboot` 干净重启 | `scripts/openrc-enable.sh`、`initramfs/init`、`scripts/fix-logind-poweroff.sh`、`rootfs/persistent-overlay/` |
| **G1-33** | **相机 × 熄屏共存（Q24 修复）** | 🟢 **H2 收盘（2026-10-07，用户实机确认）**：cambist 节点单挂 MX 电源域（`power-domains=<&rpmhpd RPMHPD_MX>` + `required-opps low_svs`；依据上游 v3→v4 commit 说明 MX/MXC 为 always-on 轨、MMCX 是可 collapse 的那一路）→ **vk63**（`out/boot-elden-vk63.img`，提交 86ea33c25）：cambist 加载 + 真实熄屏 2/2 存活 + 用户手动多次电源键循环确认健康。历史：H1（去 power-domains）7/9、D1 `use_rpm=false` 6/9、D2 去 `critical_cbcrs` 7/9。上游报告已发送（2026-10-08，linux-arm-msm + Cc 维护者，patch be79b256d 纯 ASCII，见 archive/topics/UPSTREAM-REPORT-cambist-q24-2026-10-08.md）；「熄屏异常时命令行触发熄屏有概率让桌面只剩背光」观测待查（2026-10-07 用户更正表述：非每次，仅熄屏异常态下低概率） | 任一 mainline | 相机常驻 + 装 cambist 后长时空闲不断电 | `.pi/plans/2026-10-07-dp5基线-相机补全-加速度.md`、`scripts/sleep-sweep.sh`、`out/boot-elden-vk63.img` |
| **G1-34** | **加速度计/重力传感器（SLPI）** | ⬜ **未开工**；器件（`lsm6dso`/`icm4x6xa`）挂在 **SLPI 私有 I2C**，AP 侧不可见；主线有 QRTR-as-bus + `qcom_smgr` IIO 驱动族但**本树未含**（社区以补丁携带）。路线：① QRTR 服务/`sns_client` 探针 → ② 传感器 registry（`sns.reg`/`sensor_def_qcomdev.conf`，可由 stock `/vendor/etc/sensors/config` 生成）→ ③ 移 smgr 补丁或 libssc 用户态 | 任一 mainline | `/sys/bus/iio/devices/` 出现 accel 并有数据 | `archive/topics/STOCK-CAMERA-GRAVITY-2026-10-02.md`、`TASKS §5 Q27` |
| **G1-4** | **音频可听（播放+输入）** | ✅ **播放 2026-10-04 实测听声**：根因=tplg MI2S **SD 线错**（SD0→SD1，`PITFALLS` #90）；PipeWire+UCM2 桌面链路 ✅。**输入 ✅ 2026-10-04**：本机麦克风=**模拟麦接 WCD939x**（非 DMIC）；WCD939x bring-up（DTS codec+swr1/2+TX3、去 VA DMIC）+采集 DAPM 控件 → `arecord -D default` 出数据并持久化 UCM2 `Mic`。**R3 裸 ALSA**：`scripts/audio-alsa-init.sh` 幂等设路由，无桌面 `aplay/arecord -D default` 开箱可用（增益 400）。R1 有线耳麦：代码就绪、**硬件缺失（无 3.5mm/转接头）冻结**；FSA4480（非 `wcd_usbss`）需编 built-in。R2 双麦=AMIC1+AMIC4（未做，低价值） | 任一 mainline | 扬声器出声 ✅；`arecord`/`aplay -D default` rc=0 ✅ | `archive/topics/AUDIO-SDLINE-2026-10-04.md`、`WCD939X-2026-10-04.md`、`HEADSET-HW-2026-10-04.md`、`MIC-ARRAY-2026-10-04.md`、`patches/0011`、`scripts/audio-alsa-init.sh` |
| **G1-5** | **相机出流** | ✅ **已打通 + 相机 App 实测通过（2026-10-07，boot_b cdsp-vk47clean-camrot2 实机）**：
  ① 驱动层出帧（2026-10-05，前后摄 rc=0，`camera-stream-up.sh` 固化）。
  ② **dma-buf 补齐 → libcamera 软件 ISP 解锁**：`system_heap.ko` 部署并开机自载（`/dev/dma_heap/system`）；**`cma_heap` 必须不加载**——它造的 `/dev/dma_heap/reserved`（32 MiB CMA）会抩 libcamera DmaHeap 探测序 `linux,cma→reserved→system`，然后 ~30 MiB 帧分配 ENOMEM（`PITFALLS` #130）。
  ③ **真 App 路线打通**：`libcamera-gstreamer`（`libcamerasrc`）+ GNOME Snapshot 50.0（apk 装）——预览/拍照/**录像**全部可用，前后摄均出真实画面（前摄抓帧回传主机目视确认）。
  ④ **成像 180° 修正**：stock vendor roll（后 90/前 270）与主线 DT 一致但 app 前后都翻转 180°；DT 取补角（后 270/前 90，内核提交 `8b69eb153`）后实机确认前后均正。
  **硬件/固件/驱动判定合适（用户 2026-10-07 实机确认）**。
  剩余（登记非阻塞）：**后摄过曝、高光压制速度偏慢**（IPA 调优，libcamera `simple` IPA 无 s5kjns 校准 yaml）；**Snapshot 缺聚焦/曝光调节 UI**（app 功能基础，非驱动）。 | 任一 mainline | `cam`/`libcamerasrc` 出真实画面；Snapshot 预览+录像朝向正 | `PITFALLS` #129–#131、`out/boot-elden-cdsp-vk47clean-camrot2.manifest`、内核 `8b69eb153` |
| **G1-6** | TF 卡写稳定性 | 🟡 **根因倾向卡本身 70–80%（2026-10-04 子代理）**：尺寸相关性（64MB 大块全对 / 8MB 小写间歇丢）、`err_stats` 全 0、`e2fsck` 前后一致、已是最保守 3.3V/SD_HS 档仍坏。**关键更正**：厂商 `qcom,uses_level_shifter` 唯一作用=SD_HS 封顶 37.5MHz，主线 `max-sd-hs-hz=<37500000>` 已等价 ⇒ 无效移植。5 个候选补丁（`patches/candidate-tf-*.patch`，按代价排序）+ 压测脚本 `scripts/tf-stress.sh` 就绪。**新卡已装入（2026-10-05 用户确认），测试条件就绪，待跑 A/B** | 任一 | 新卡连续 ≥3 轮 0 不一致 + `e2fsck -fn` 干净 | `archive/topics/TF卡-2026-10-04-subagent.md`、`scripts/tf-stress.sh` |
| G1-7 | BT 配对收口 | ✅ **已完成（用户 2026-10-06 设备侧实测：配对成功、TWS 实听正常可用）**。历史排查（保留备查，不再阻塞）：**根因重定位（2026-10-04 子代理）**：表面「配对后几秒断」，实为 BR/EDR 高延迟。**排除主机 IBS 握手**——新代码事实：`IBS_HOST_TX_IDLE_TIMEOUT_MS=2000`（旧「调大 tx_idle_delay」实验近空操作）、`qca_wcn7861_uses_current_baudrate()` 命中时**跳过 `qca_set_speed`** 使 DT `max-speed` 可能失效、PERI 协议**硬编码 8Mbps**、`qca_port_reopen()` 的 RTS/CTS 同步问题 WCN7861 路径不调用。假设排序 H4 控制器固件深睡 > H2 CTS 反拉 > H1 8Mbps 误码 > H3 主机握手(已排除)。4 个候选补丁（`patches/candidate-bt-*.patch`）+ `scripts/bt-link-test.sh` 就绪。**2026-10-04 实机 A/B（iQOO TWS 2 `4C:99:92:32:D6:65`，vk47a，零写盘）**：基线 RTT 7.8/**44.4**/110.8 mdev 26.8 ms（0% loss），`KEEPALIVE=1` 仅 44→35 ms（未塌 <10）⇒ **H4 不成立**；`ibs_sent_wakes_delta=1` 两种情形相同 ⇒ **H3 排除**；`-c100 -i0.05` 20s 内跑不完 ⇒ 突发停摆复现，`hciconf errors=0`。剩 **H1(8Mbps)/H2(CTS)**，需单变量测试内核（`candidate-bt-maxspeed-3000k` / `no-flow-control`）。**⚠️ 2026-10-06 新观测（未证实）**：vk61（新 init）启动后 `hci0 UP RUNNING`、`bluetoothctl` 可见设备、用户测到「之前的蓝牙无法连接问题消失」。**但 dmesg 的 BT 部分与旧启动逐行相同（`hci0: setting up wcn7850`）**，机制未知；不能写成「已解决」。待做单变量 A/B：boot_b（旧 RAM init）+ 同一磁盘 /init vs vk61（新 RAM init），两次冷启各做一遍配对/回连与 `scripts/bt-link-test.sh`，先确认可复现再定位。**↳ 2026-10-06 用户实测收口：配对成功且 TWS 实听可用 ⇒ 功能判据满足、本项关闭；H1/H2 单变量与 `bt-link-test.sh` 长测降为可选（未留原始日志）** | 任一 | ✅ 用户实测配对 + TWS 可用（RTT 优化项可选） | `archive/topics/BT-2026-10-04-subagent.md`、`scripts/bt-link-test.sh` |
| G1-8 | CPU/GPU 基准（脚本已备） | ⬜ | 任一 mainline | `bench-run.sh` 出分；温控不破 82 °C | `scripts/bench-run.sh`、`scripts/bench-install.sh` |
| G1-9 | DP 输出（解锁 `mdss_dp0`） | ✅ **已打通（2026-10-07，dp5 载具零写盘 + 用户实机目视确认出画面）**。**根因链（三步定位，此前误判「ADSP UCSI 未起」）**：① `PPM init failed, stop trying` 实为 `ucsi_init` **EPROBE_DEFER 重试 20 次放弃**（`failed to reset PPM` 从未打印 ⇒ ADSP UCSI PPM 本身通）；② defer 源 = `fwnode_usb_role_switch_get` ⇒ role switch 未注册 ⇒ **`dwc3_drd_init` 仅在 `dr_mode=otg` 时跑**，本机 DTS 写死 `peripheral`；③ otg 又被 `/delete-property/ usb-role-switch` 强制回 peripheral（GHWPARAMS0=DRD，硬件支持双角色）。**修复 = `dr_mode=otg` + `usb-role-switch` + `mdss_dp0 okay` 三处 DTS 同批**（内核提交 `6c1376907`）。dp5 实机：`card0-DP-1` connected+enabled+dpms=On、EDID `F27G32Q Pro` 2560×1440@180 preferred、`typec/port0-partner` 出现、vblank=0、DSI 同亮、Phosh 正常、外接实测出画面。**残余（非阻塞）**：放缩/横竖屏显示尚有问题（桌面侧，非物理链路） | 任一 | `/sys/class/drm/card0-DP-1` connected + 外接出画面 ✅ | `archive/topics/DP-2026-10-06.md`、`PITFALLS` #128、`out/boot-elden-dp5.img`（sha `096470c3…`） |
| G1-10 | ~~NFC compatible 修正~~ **取消：本机无 NFC 硬件（2026-10-06 取证）** | ❌ **不成立**：TB322FC vendor **无 `android.hardware.nfc.xml`**（feature 未声明）、vintf manifest 无 NFC HAL、`/lib64(/hw)` 无 NFC HAL 库、`/firmware` 无 NFC 固件、原厂运行服务无 NFC；GSMArena `NFC: No`。`elden.dts` 的 `st21nfc` 是**总线 `disabled` 的共用模板**，`stm_nfc_i2c.ko`/`st54spi_gpio` 多 SKU 共用；`ro.nfc.port=I2C` 为通用属性。**vk53 的 `&i2c0` 使能反而致硬关机（#108），已从驱动批次移除** | — | — | `PITFALLS` #108 |
| G1-11 | CDSP 启用（可选加分） | ✅ **已启用（2026-10-07 实机）**：`remoteproc1(cdsp) state=running`、`fw=qcom/sm8750/cdsp.mdt`，dmesg `remote processor cdsp is now up`（1.40 s）。**根因=固件变体+载具，非 PAS id**：① 原 DTS 用非 stock 单文件 `cdsp.mbn`/`cdsp_dtb.mbn`，单文件 `cdsp_dtb.mbn` 被 TZ PAS init 拒（`-22`）；stock SunP DTS 用 **split** `cdsp.mdt`/`cdsp_dtb.mdt`（DTS 已改，内核提交 `c132a1bc7`）。② **固件由 initramfs 加载**（switch_root 前 ~1.16 s），磁盘 rootfs 副本不生效 ⇒ split 必须打进 ramdisk（`build-initramfs.sh full` 已加注入）。**「PAS id 不匹配」假设否证**：反汇编 stock `qcom_q6v5_pas.ko` 的 `sun_cdsp_resource` = pas_id **18** / dtb_pas_id **0x25**，与主线 `sm8650_cdsp_resource` 完全一致。**boot_b 已持久化**（2026-10-07 刷入 `out/boot-elden-cdsp-vk47clean.img`（vk47clean 内核 + 模块一致），读回 sha 校验通过；`findmnt /`=`/dev/sda17`、cdsp `running`） | 任一 | `/sys/class/remoteproc/remoteproc1` running ✅ | `archive/topics/CDSP-FIX-2026-10-07.md`、`CDSP-PROBE-2026-10-06.md`、`PITFALLS` #127 |
| ✅ G1-12…21 | 显示 165 Hz、图形 A830、触屏、WiFi、BT 基础、充电+旁路、温控分级、带外串口、启动 ~5 s、触觉 | **已完成** | — | 见 `DEVICE.md` §1.3 | `PANEL-REFRESH`/`THERMAL`/`CHARGE`/`OOB-CONSOLE` |

---

## 2. G2 任务分解（**前提：不依赖 Android**，参考社区资源做 ARM Linux 侧安卓兼容）

> 路线定义见 `TASKS.md §6`。ID 前缀 `C`（compat）。

| ID | 任务 | 状态 | 层 | 验收 | 备注 |
|---|---|---|---|---|---|
| **C0** | **真 Android 对照取证**（趁 U1 还是 stock+root，**覆盖 a 槽前必做，不可复得**） | 🟡 **采集器已就绪，待 U1 接入**：`scripts/c0-android-evidence.sh` | 基线 | `getprop` 全量、`dumpsys media.drm` 级别、7 颗传感器 30 s 采样 CSV、5 个目标 App 关键流程录屏 | 兼容层的“标准答案”；见 `TASKS.md §5` Q5。传感器 CSV + App 录屏需人工（脚本尾有提示） |
| **C1** | Waydroid 在 vk40 端到端复跑（去掉旧的 bind-mount 路由 workaround） | ⬜ 下一步 | 容器 | `waydroid status` 有 IP、SurfaceFlinger running、桌面可点 | Mesa 26.1.8 + GAPPS 镜像在手 |
| C2 | Play / GMS 登录收口（旧结论：卡在外部上行与代理） | ⬜ 需你给上行+凭据 | 容器 | Play Store 登录成功 + 装 3 个目标 App | `archive/topics/PROXY-WAYDROID-2026-10-02.md` |
| C3 | **身份兼容性取证**（GMS/Play Integrity/Widevine 能做到哪一级）——**不预设结论** | 🟡 社区侧取证已补全（2026-10-02，见 `RESOURCES.md` §1.3） | 容器 | 出「社区先例 × 本机实测」对照表 + 回填 `TASKS.md §6` §1 的 C2 格 | 先例：redroid / waydroid_script `certified` / WayDroid-ATV（arm64 GAPPS 有、L3 仅 x86-64；arm64 仅 A11 有、A13 无） / PlayIntegrityFork；**实测需设备+上行** |
| **C4** | **传感器注入原型**（~~uinput + UDP~~ **作废**→ **UDP HAL 真实现**：waydroid-build 树 Sensors.cpp 已编译，宿主侧 sensord 已冒烟） | 🟡 主机侧代码+编译全就绪，待上机部署验证（GAPS Q14） | HAL | `dumpsys sensorservice` 列出 5 个 elden 传感器；地图自动旋转有读数 | 前提修正+证据：`archive/topics/SENSORS-WAYDROID-STUB-2026-10-03.md`；部署：`scripts/deploy-sensors-hal.sh`（overlay 方式） |
| C5 | 相机共享（`v4l2loopback` + sampler → 容器） | ⬜ 待 G1-5 | 容器 | 容器内相机出预览 | — |
| C6 | 音频通路打通后的容器音频（PipeWire） | ⬜ 待 G1-4 | 容器 | 容器内播放有声、延迟 <100 ms | — |
| C7 | `scripts/slot-switch.sh` 一键切槽 + 槽属性自检 | ⬜ 低工作量 | 双槽保险 | 两条命令完成往返切换 | 即便 a 槽可弃，也要保留回退手段 |
| C8 | **无 Android 的 VM 路线调研**（Gunyah guest on mainline / crosvm+`--parallel_vcpus`；KVM 已确认不可行） | 🟡 **书面结论已出（2026-10-02）**：维持低优先不立项——① 设备侧 KVM 不可达（XBL 锁 hyp，`-el2.dtb` overlay 只适用 dev kit）；② 独立 gunyah 驱动未进主线（本地 7.2 树无 `drivers/virt/gunyah`）；③ 唯一新路线=KVM-in-EL1+Gunyah backend（RFC 00/34，Linaro，配 `qemu-for-gunyah`，WIP） | VM | 上机后跑一次 Gunyah UUID 探测（`dmesg \| grep -i gunyah`，本地 qcom_scm 已带探测逻辑），据结果归档或续立项 | `archive/topics/EL2-VIRT-2026-10-02.md`、`RESOURCES.md` §1.5 |
| C9 | 兼容层验收用例集 `TASKS.md §5` §Q6 打分表 | ⬜ 新增 | 全部 | 5 维打分表出数 | — |
| ✅ C-历史 | Waydroid 容器打通、Mesa 26.1.8 解 A830 chip-id、GAPPS 镜像安装、容器代理通路、**Win-x86（Box64 0.4.5+Wine 9）PoC** | **已完成** | — | 见 `archive/topics/WIN-X86-POC-2026-10-02.md` | — |

### 2.1 主机侧并行任务（不占设备，随时可做）

| ID | 内容 | 状态 |
|---|---|---|
| A11 | Debian/Alpine arm64 guest rootfs（VM 路线用） | ⬜ |
| A12 | guest 内核（`CONFIG_DMA_RESTRICT_POOL`，microdroid_defconfig 思路） | ⬜ |
| A13 | `sudo apt install qemu-utils` | ✅ 已装（`qemu-img`/`qemu-nbd` 实测在位，2026-10-02 核验） |
| A14 | 传感器注入代码 | ✅ **已完成（2026-10-03，前提修正后重定义）**：HAL 真实现（waydroid-build 树 Sensors.cpp，编译成功）+ 宿主侧 `scripts/eldroid-sensord.c`（selftest 7/7 + UDP 环回冒烟）+ `scripts/deploy-sensors-hal.sh`（overlay 部署）+ `env-pass/scripts/sensor-send-termux.sh`（真值转发） |
| A15 | C9 用例表 + 打分模板 | ✅ 已定稿 → `TASKS.md §6` §5（2026-10-02，10 条用例+阈值） |
| A16 | 把 `scripts/*.sh` 里残留 `new-tablet` 默认路径参数化 | ⬜ |
| A17 | `env-pass/` 打包成"装到任一单元的幂等脚本"（去掉隐含绑机） | ✅ 已完成：`env-pass/scripts/envpass-provision.sh`（状态预检 TB322FC/root + 产物自动 repack + 读回校验 + 幂等）+ `envpass-ondevice.sh` 幂等化（已装模块跳过 + Shamiko -patched 优先） |
| A18 | `sudo bash scripts/fix-fstab-samsung.sh`（/mnt/Samsung 掉盘卡开机） | ✅ 已完成（2026-10-02） |

---

## 3. 已作废/合并的旧任务线

> 2026-10-06 归档：`设备等价` 原则确立后，2026-09-30…10-02 的旧任务线 / swarm 批次 / "两轨分机" 角色表全部作废，原文已移出本文件。
> 见 **`archive/topics/RETIRED-PLANS-2026-10-06.md` §1**（含 swarm task-1…13、task-14…17、PLAN-NODEV、两轨分机、新机/旧机角色表）。本文件不再展开。

---

## 4. 下一步（按顺序，含并行项）

> **历史裁决与沿革**见 `archive/topics/MERGE-2026-10-05.md`（三调查合并/优先级）、`archive/topics/KEXEC-ONDEVICE-R2-2026-10-05.md`、`archive/topics/DRIVER-VERIFY-2026-10-06.md`、`archive/topics/SESSION-AUDIT-2026-10-06.md`。本节只留当前口径与下一步。

**当前口径（2026-10-06）**
- **本轮主线（用户定）= 尽可能覆盖硬件驱动**：G1-6 TF 卡 + 在树未实测项 + **相机 App 实测**；判据 =「命令 + 原始输出」可复现。**G1-9 DP 已打通（2026-10-07，dr_mode=otg+usb-role-switch+mdss_dp0 三处 DTS 同批，提交 `6c1376907`，外接实测出画面；残余放缩/横竖屏桌面侧问题非阻塞）**。**G1-22 根因=单模块 `cambistmclkcc-sm8750`（相机 BIST MCLK 时钟控制器）**（H1 DTB 实验 7/9 存活未根治，见 §5 Q24）**G1-11 CDSP 已完成（2026-10-07，split 固件+initramfs，见专题）**；**G1-10 NFC 取消（本机无 NFC 硬件）**；**G1-7 BT 已收口（用户实测配对+TWS 可用）**；**Q26 WiFi 到可用（重开）：机制未定论——「P40 Pro 组合已知限制」口径撤销**（用户观测：同一 P40 Pro 在早期版本 ≤2026-10-04 可正常连接）⇒ 假设=**版本/DTB 增量连带副作用**；已证伪项保留（探测时序非变量、power_save/双管理器排除），下一步版本/DTB 单变量 bisect（见 §5 Q26）。
- **不做**：桌面用户态（G1-26/27/28）、内核熄屏/关机（G1-22/Q24）、UEFI（G1-29 搁置）。
- **迭代通道**：`fastboot boot`（零写盘）/ `--flash`；**kexec 快环已死**（见下 1）。
- **boot_b 形态（在机，2026-10-08 用户烧录，读回 sha 逐字节一致）** = **`vk63`**（`out/boot-elden-vk63.img`，sha `2f34e887…`；实验提交 `86ea33c25`，上游化版 `be79b256d`）：**vk47clean 内核**（模块一致）+ **H2 DTB**（cambist 单挂 `RPMHPD_MX`；dp0 okay/otg/rotation）+ 完整 ramdisk + 修好的 `/init` + split CDSP；cmdline 带 **`elden_nocamera=1`** ⇒ 开机不自动加载相机 ⇒ **熄屏安全 + DP 可用**（相机按需）。**已知问题：面板 init 间歇失败（2026-10-08 实测 4/7 boot：`panel-novatek-nt36536 … dcs data ff 20 failed: -110` → 只有背光无桌面，DPU vblank 超时刷屏；phosh 可能不起；重启可恢复；与烧录路径无关——`fastboot boot` 同镜像也偶发，正常 reboot 也复现；见 §5 Q28、`PITFALLS` #16）**。刷入回退：`out/boot-elden-vk62.img`（H1）、`out/boot-elden-camdp-nocam.img`、`out/boot_b-before-cdsp-20261007.img`、`bootslot-b/boot_b-clean.img`；**不用 min initramfs slim**（无固件→驱动全废，#113）。
- **上机纪律**：驱动测试期间 `idle-delay=0` 禁熄屏；写操作前查 `scripts/device-lock.sh`；fastboot 命令拆单条（PITFALLS #3）。
- **归因分层**（2026-10-06）：报「驱动/内核坏」前先分清 **initramfs/rootfs 打包** 与 **用户态配置**（如 vk60「驱动全废」实为 initramfs 缺固件）——见 `PITFALLS` #115、`archive/topics/ATTRIBUTION-AUDIT-2026-10-06.md`。

**下一步（按顺序）**
1. **上机最小实验**：kexec 取证排第 1（分支点未定位，须带存活 console，见 `PITFALLS` #5/#106）→ 驱动验证（**vk53/vk54 的「DTS 破坏启动」归因已撤回**，改用 **vk61 载具**零写盘重测 DP；**CDSP 已用载具验毕 ✅**）→ Q24 隔离（**真实触发 = `ScreenSaver.SetActive(true)`**，2026-10-07 更正）。
2. ✅ **G1-5 相机出流**已完成（2026-10-05）；剩 3A/调优、C5 容器共享（非阻塞）。
3. ✅ **G1-22/Q24 已收盘（H2/vk63，用户实机确认）**：根因=单模块 `cambistmclkcc-sm8750`；修复=DT 单挂 MX 电源域（H1 去 power-domains 7/9 → H2 确认健康）；D1/D2 驱动开关无效；剩=把 vk63 刷进 boot_b。**G1-26/27/28** 根因已定（`gtk-theme='Adwaita'`；亮度核心链路已解），修复待上机。
4. **C0 真 Android 对照取证**（U1 stock+root；覆盖 a 槽前必做，不可复得）。
5. **C1 → C3 → C2**：Waydroid 复跑 → 身份/DRM 取证 → Play 登录（C2 需上行+代理+凭据）。
6. 单变量上机项（任一会话顺路）：G1-7 BT H1/H2、G1-6 新卡 A/B（`scripts/tf-stress.sh`）、C4 传感器 HAL、C8 Gunyah 探测。
7. 不占设备：G1-8 基准、G1-9 DP、C5/C6/C7、上游化 M1–M5。
8. **失败/半成品登记**（权威在各 ID 条目）：UEFI A（UFS 墙，上游 #12）；kexec（分支点未定位）；**G1-10 NFC 取消（无硬件）**；**vk53/vk54 启动失败根因 = `&i2c0` 使能（#108，已单变量定案）**；G1-6 TF（补丁就绪，A/B 未跑）；**相机 App 实测缺**；**WiFi 到可用约 2 分钟（Q26，重开：撤销「P40 Pro 组合已知限制」；用户观测早期版本可正常连接 ⇒ 怀疑 DTB 增量连带副作用；机制=固件对已关联 STA 的 ~0.5 beacon/s 唤醒拍子、~130 s 自愈；`patches/0012` 两版 / 关联后补发时序 / stock 固件换版 三条均未解决；双管理器为独立 bug 已修并部署；`CONFIG_ATH12K=m` 单次探针证伪（探测时序非变量））**。

---

## 5. 查漏补缺（GAPS）

### 1. 待调查（Open questions，按优先级）

| ID | 未知 | 为什么要知道 | 怎么测（最小实验） | 关联任务 |
|---|---|---|---|---|
| **Q22** | **vk34（2026-10-01）之后未逐版验证的内核增量**：5 文件（DTS 分级热 trip、q6apm.c/q6prm.c/audioreach.c/q6apm-lpass-dais.c 音频）+ `config-vk40-bringup`，全部只在 vk40 叠加体上上过机，与「vk40 新 bug（含熄屏→重启）」可能因果相关 | 决定 G1 基线是否可信；是「AI 难以稳固推进」的核心 | 静态取证：`archive/topics/AUDIT-since-vk34-2026-10-03.md`。**✅ 2026-10-03 实机确认**：`vk34recon` 睡眠正常、不重启，`vk40` 重启 ⇒ **回归源锁定在这 5 文件增量内**（与 10-03 持久化 rootfs 无关）。**第二遍（2026-10-03）**：逐 hunk 分类（N1 日志副作用 / N2 APM cmd header / N3 提前启动 graph / N4 残留 DBG）；建 V1(仅热区)/V2(仅音频) 二分镜像；实机取到**可量化回归**：`vk40re` 显示 on/off 后 `vblank timeout`=6、`PPM init failed`=1，`vk34recon` 同操作 =0/0。⚠️ 整机**静默硬复位是间歇性的**（~1 min/次 与 稳定 400 s 都出现）→ 单次观测无统计意义；V1/V2 尚未取到有效样本；per-boot kmsg 钩子有**副作用嫌疑**（装后 vk40re 变稳定），已回退。**第三遍（2026-10-03，`AUDIT3`）**：审计前序工具调用——**副作用从未写在轮询循环体内**（49 会话 132 条含副作用命令，0 条在 `do…done` 内）；真隐患是「reboot/`fastboot boot` 与长轮询同处一条命令、被 harness 超时杀死」（10 条中 4 条 `Command aborted`，副作用发没发不可判定）。**更关键的新混淆**：持久 `boot_b` 烧的就是 vk40 内核（kernel payload 与 `out/boot-elden-vk40.img` 逐字节同 =`d16ab35ce4a57afa`），而 vk30–vk40 共用 uname `…gba28ec16f01f-dirty`；串口捕获 16 min 内 8 次启动中 5 次是 vk40，每次仅活 20–40 s ⇒ **复位必回退到 vk40**，「复位次数/复位后行为」的跨版本比较被污染；但 vblank/PPM 的**版本归属仍可信**（per-uname kmsg 日志）。**下一步**：先把 `vk34recon` 烧进 `boot_b` 作已知基线（资产 `bootslot-b/boot_b-vk34recon.img` 已签好），再单变量长时窗重测。 | **G1-23**；`archive/topics/AUDIT-since-vk34-2026-10-03.md` §5、`AUDIT2-post-vk34-bisect-2026-10-03.md`、`AUDIT3-polling-sideeffects-2026-10-03.md` |
| **Q21** | ~~桌面空闲熄屏（DPMS blank）→ 整机重启~~ **已收盘（2026-10-07）→ 见 Q24：根因=单模块 `cambistmclkcc-sm8750`** | 与 DP/altmode（G1-9）不同源 | 已由 60+ 轮模块二分 + H1 实锤 | **G1-22 🟡 / Q24** |
| ~~**Q23**~~ | ~~Linux 侧 reboot→fastboot 的触发点~~ **已解决（2026-10-03 深夜）** | 已定 G1-24 路线 | **实测结论**：PMIC SDAM `reboot-reason@48`、`misc` BCB `bootonce-bootloader`/`boot-recovery` **均不被 ABL 采纳**；**PSCI SYSTEM_RESET2 vendor reset 被采纳**（`mode-bootloader=<0x80010001 0x2>`、`mode-edl=<0x80000000 0x1>`，无 recovery）。落地 = `elden/vk41-psci-reboot` 最小钩子（`psci.c`）；`reboot bootloader` → fastboot **实测成功**。EDL = TCSR DLOAD cookie（`qcom,dload-mode=<&tcsr 0x19000>`）未测 | **G1-24**；`archive/topics/FLASHCTL-2026-10-03.md` §7–§9 |
| **Q25** | **G1-29 路线 A 为何卡在 UFS 初始化**（Mu Pakala 平台配置不全：SCM mailbox / QBSS / CPU_Vectors 缺失 → `UFS.c+2326` ASSERT） | 决定将来是否重启 UEFI 方向；当前**不阻断主线**（96 MiB 已由 G1-30 路线 C 解决） | 已发上游 issue `sunflower2333/mu_wide_platforms#12`（附实验矩阵+日志）；只做两件事：等上游回复 / 对 `PlatformConfigurationMapLib` 给 UFSDxe 的 config tag `0x402` 解引用做静态定位 | **G1-29（已搁置）**；`archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md` |
| **Q24** | **桌面熄屏（DPMS off）→ 整机硬复位/断电** | 🟢 **H2 收盘（2026-10-07 用户实机确认）**。根因（60+ 轮二分）=单模块 **`cambistmclkcc-sm8750`** 单独加载即触发（原 DTB 3/3）；`qcom-camss`/`camcc-sm8750`/`i2c-qcom-cci`/`wl2868c-regulator` 各 3/3 存活；**零相机对照 3/3 存活**；`system_heap` 无罪；pstore/kmsg 无痕（硬复位型）。**H1**（节点去 `power-domains=RPMHPD_MMCX/MX`+`required-opps`，对齐厂商 `vdd_mx-supply`）→ **7/9 存活**，未根治（间歇）⇒ MMCX/MX 耦合是主因之一。**驱动侧已试无改善：D1 `use_rpm=false` 6/9、D2 去 `critical_cbcrs`(SLEEP_CLK) 7/9** ⇒ 残留 ~20% 间歇待续修（G1-33）。**H2 收盘（2026-10-07 用户实机确认）：cambist 单挂 MX 电源域 ⇒ `vk63` 加载 cambist + 真实熄屏存活、多次电源键循环无掉电** | 相机常驻 / 驱动修复 | 装 cambist 后长时空闲不断电 | `.pi/plans/2026-10-07-dp5基线-相机补全-加速度.md`、`scripts/sleep-sweep.sh`、`out/boot-elden-vk63.img` |
| **Q26** | **WiFi 到可用约 2 分钟（2026-10-06 实机；用户明确仍需排查）**：clean boot **28 s 就关联上**，但 IPv4 到 **~140 s**；中间**每 ~16–18 s 周期掉线**（`ath12k: failed to flush transmit queue` + `Connection to AP 00:00:00:00:00:00 lost`），`nmcli` 恒 `getting IP configuration`。设备**同时跑两套 supplicant**（NM 的 `wpa_supplicant -u` + 手动 `wpa_supplicant -B -i wlan0`）——NM 版 `net-up.sh` 超时回退引入第二套。**已排除**（干净单变量）：`power_save`（开/关各 45 s = **2 vs 2** 次掉线）、持续流量（2–3 次）、`dhcpcd` 后端、**单次手动扫描**（稳定链路上不触发 bmiss/掉线）。**真根因（2026-10-06 定位）**：固件 `WMI_ROAM_REASON_BEACON_MISS`(reason 2) 每 ~16.4–17.7 s 一次 → ath12k 3 s `connection_loss_work` 硬拆链；而**关联后前 ~100 s 主机基本收不到 beacon（`beacon rx: 1`）**，~129 s 自行恢复。**被动扫描定案（专题 §12.3）**：黑屏窗口内 `iw dev wlan0 scan passive`（只听 beacon）**仍能听到该 AP**（BSS=36、命中 1）⇒ **AP 在发 beacon、射频无辜**；同时刻已关联 STA 只上送 **~0.5 beacon/s ≈ 每 2 s 醒一次**（正常应 5/s = DTIM 2 × 100 TU）⇒ **症结 = 固件对已关联 vdev 的休眠/唤醒调度，~130 s 自校正**。三条修复尝试**均未解决**：`patches/0012`（v1 判据太松 / v2 机制生效但可见收益 0）、关联后补发 `WMI_VDEV_PARAM_BEACON_INTERVAL`+`DTIM_PERIOD`（镜像 `wifi-timing-1`）、stock 固件换版（非-20 变体 MHI POWER_ON `-110` 直接不兼容）。下列「双管理器」是**独立 bug**（清掉后黑屏照样复现；已修并部署：`net-up.sh` 去掉自动回退） | 日常可用性；**非 initramfs**（载具体验证通过） | 下一步（方法已落档专题 §13）：~~试 `CONFIG_ATH12K=m` 单次干净探针~~ **❌ 已试、证伪（2026-10-06 深夜）**：构建 `out/boot-elden-athm.img`（bd114ca33 + `CONFIG_ATH12K=m`）零写盘启动 —— 内置首探消失，WCN 在芯片就绪后 **MHI `Power on setup success`（首次成功、无 `-110`）**，但连 `P40 Pro` 后 **bmiss 拆链仍每 ~16 s、`beacon rx` ≈1、130 s 无 IPv4**，与旧 boot 逐现象一致 ⇒ **探测时序不是变量**。**⚠️ 2026-10-08 口径撤销：「按 P40 Pro 热点组合已知限制归档」不成立**——用户指出**同一 P40 Pro 在早期版本可正常连接**（参 `archive/topics/PROXY-WAYDROID-2026-10-02.md`：该实验即以 P40 Pro 热点为上行、设备 `wlan0` 正常 DHCP），故本项**重开**。**新假设 = 版本/DTB 增量连带副作用**（当年「同内核换 AP（ustcnet/vivo）即正常」只说明触发需 AP 侧时序配合，**不能排除 DTB 变量**）。**下一步**：版本/DTB 单变量 bisect——`fastboot boot` vk40/vk47/vk53/vk61/vk63（零写盘）各连 P40 Pro，量「关联→IPv4 时间 + `iw station dump` beacon rx + bmiss 次数」，定位回归引入点后再 diff 该版本 DTS。不再投入者仅限该条「归档」结论。⚠️ 踩坑：`ATH12K=m` 经 `select PCI_PWRCTRL_PWRSEQ` 把 PCIe 电源序列驱动降为 `=m` ⇒ PCIe host init 失败、wifi 全无（`PITFALLS` #125）。证据 `archive/topics/WIFI-ATHM-PROBE-2026-10-06.md`。**↳ 2026-10-08 新样本（支持版本/DTB 回归假设）**：**vk63 + P40 Pro = 干净**（两次 boot：`beacon loss 0`、`beacon rx` 1623（≈10/s 正常）、0 bmiss、1 min 内拿到 IPv4 `192.168.43.169`；SSID 确认 `P40 Pro`）——同一 AP 在 vk61 时代每 ~16 s 拆链 ⇒ 回归与版本/DTB 相关，非 AP 组合限制 | G1-12 续；`archive/topics/WIFI-SLOW-2026-10-06.md`、**`archive/topics/WIFI-BMISS-2026-10-06.md`**（§12 三条尝试、§13 手册）、**`WIFI-ATHM-PROBE-2026-10-06.md`** |
| **Q28** | **面板 init 间歇失败 → 只有背光无桌面**（2026-10-08 实测，vk63 基线）：`panel-novatek-nt36536 ae94000.dsi.0: sending dcs data ff 20 failed: -110` → `Failed to initialize panel: -110`（DSI DCS 首写超时）→ 面板从未使能 → DPU 全部提交失败（`reset failure: -22` ×数百 + `vblank timeout` + `drm_crtc_wait_one_vblank` call trace 刷屏）→ 只有背光无画面；**失败 boot 上 phosh/greetd 会话可能不起**（`phosh=0`） | 即 `PITFALLS` #16「显示间歇性坏」的可见根因（此前只见 call trace 刷屏，不知根因） | **实测（2026-10-08，vk63，P40 Pro 段）**：7 boot 中 4 失败（B3 OK → B4–B6 连续失败 → B7 OK）；同一镜像（boot_b 读回 sha 与 `out/boot-elden-vk63.img` 逐字节一致）`fastboot boot` 与正常 reboot **都**会触发 ⇒ 与烧录路径/dtbo_b（=全零+AVB footer，无 overlay 内容）无关，属**间歇性 DSI/panel init 竞态**；面板三供电（`vreg_1v8_vddio/6v1_vsp/5v8_vsn`）失败时也 enabled；DSI 连接器 `connected/enabled/dpms=On`。下一步：失败时抓 `dsi host`/PHY 上下文 + 多次 reboot 估概率；验证是否旧基线（vk62）同样存在（历史 #16 即「偶见」，应非 vk63 引入） | G1-1 续；`PITFALLS` #16、`logs/kmsg-vk63-nodesktop-2026-10-08.log` |
| **Q1** | **容器内的 GMS 身份/Play Integrity/Widevine 能做到哪一级**（不作废猜测，先取证） | 决定 G2 兼容上限与是否需要 VM/换路线 | 复现社区三条做法各一次，只变一个变量：① Waydroid + GApps（OpenGApps/MindTheGapps）；② 未认证设备注册流程（Android ID → `google.com/android/uncertified` → 清 GMS 缓存）；③ Widevine L3 库注入。记录 `getprop` 关键项 + `drminfo` + Play 状态。**社区侧已补证（2026-10-02）**：WayDroid-ATV 有 arm64 GAPPS 镜像（2026-01 SourceForge）但 **L3 仍仅 x86-64**（release notes 原文）——2026-10-07 源码核实：**arm64 仅 Android 11 有 prebuilt、A13 无**（`waydroid_script` `Widevine.dl_links`）；官方 licensing 页明确 GApps/Widevine 受许可限制、建议开源替代；PlayIntegrityFork(pif.json) 仍是主流过 PI 手段（v18 在手）；L1 需芯片商+GMS 认证（L3 是默认必测项，不需额外申请） | **C3** |
| Q2 | Waydroid 在 **vk40** 上是否不再需要旧 workaround（vk40 已开 iptables/NAT：`IP_NF_FILTER/NAT`、`NF_NAT_MASQ`、`XT_MATCH_COMMENT` ✅；`CONFIG_IP_ADVANCED_ROUTER` 仍 not set，若需策略路由再补） | 少一处 bind-mount 脆弱点 | 起容器看 `ip route` 是否自动有默认路由；不通再启用 workaround 并记因 | **C1** |
| Q3 | **droidloom**（Linux 原生跑 Android 应用，Wayland 直出窗口）在 arm64 宿主是否可用 | 形态优于容器（无需 Android 镜像） | **已查（2026-10-02）**：`denialwm/droidloom`（251★，Rust，活跃）repo 声称支持 arm64+x86_64 平台，但**预览包只发 x86_64 Arch**（pacman+ship.yml）；INSTALL 的 "experimental ARM64" 指 x86 宿主跑 ARM64 APK（Digitalis/Berberis 翻译层）；arm64 宿主 = 官方目标但无公开包。自构建一条命令 `cargo run --locked -p droidloom-package -- build`（需 rootless podman+AOSP pin，免宿主 sudo），产物 pacman 格式需适配本 rootfs。**剩两点未知**：① arm64 自构建是否干净；② freedreno+Phosh 下 GPU/输入路径 | 观察（R1 受阻再试） |
| Q4 | **无 KVM 前提下 VM 路线值不值得投**（**书面评估已完成 2026-10-02**，结论见 TASKS C8） | 决定要不要开第二条腿 | 结论：**维持低优先**。① 设备侧 KVM 不可达（XBL 在 secure-boot 链内加载 hyp，主线 `-el2.dtb` overlay 只适用 Qualcomm dev kit，ABL 重签救不了——hyp 加载点在 ABL 上一级）；② 独立 gunyah 驱动（v17）未进主线（本地 7.2 树 `drivers/virt/` 无 gunyah 目录）；③ 唯一新路线 = KVM-in-EL1+Gunyah backend（RFC 00/34，Linaro，2025-04，配 `qemu-for-gunyah`），WIP（pinned pages/无 guest_memfd/禁 swap）。**决定性上机实验**：vk40 起机后 `dmesg \| grep -i gunyah`（本地 qcom_scm 已带 gunyah UUID 探测）——通则路线第一步成立，败则归档 | **C8**（🟡 书面结论已出） |
| **Q5** | **真 Android 对照基线**（一旦覆盖 a 槽就不可复得）：GMS 属性 8 段、Widevine 级别、7 颗传感器读数曲线、目标 App 行为 | 兼容层的"标准答案"，也是判定容器是否等价的尺子 | 在 U1（当前仍 stock+root）一次采完：`getprop` 全量、`dumpsys media.drm`、传感器 30 s 采样 CSV、5 个目标 App 关键流程录屏 | **建议立刻插入（覆盖 a 槽前）** |
| Q6 | 兼容层验收的**量化判据**——**已定稿（2026-10-02，A15）**：10 条用例+阈值见 `TASKS.md §6` §5 | 避免"看起来能用"的自欺 | 上机后按用例表逐条实测打分（打分模板同处） | **C9**（模板就绪） |
| Q7 | ~~Linux 分区到底要多大~~ **已解决（2026-10-03 G1-2）** | GPT 手术一次给足，避免二次缩容 | 实测划定：`linux17`=193 GiB（CRC 校验过），估算表在 `DEVICE.md` §3.1 | G1-2 ✅ |
| Q8 | ~~音频是否真的可听 + 有无录音通路~~ **已解决（2026-10-04 G1-4）** | G1 硬验收 #4 | 实测：`amixer cset numid=8 on` 后扬声器出声 ✅；`arecord -D hw:0,2`（AMIC1）采集 ✅，UCM2 Mic | G1-4 ✅ |
| Q9 | ~~相机能否真正出流（graph ENABLED ≠ 有帧）~~ **已解决（2026-10-05 G1-5）** | G1 硬验收 #5 | 实测：前后摄 `v4l2-ctl --stream-mmap` 连续出帧 rc=0，帧尺寸精确吻合 | G1-5 ✅ |
| **Q15** | **解锁 U2 的两个不可逆代价**：① Widevine **L1→L3**（现 `sys.lenovo.widevine_security_level=L1`，属 TEE 内密钥，社区主流案例为永久降级）——它正是 Q1/Q5 容器侧 DRM 上限的「标准答案」；② 保修 + FOTA。**两台单元现均已解锁**（U1 2026-08-16 / U2 2026-10-03；U2 实机现 `flash.locked=0`） | 先拍基线再解锁，否则事后无法对照；且影响 G2 的 U5 用例上限 | ✅ **已执行（2026-10-03）**：`scripts/bl-preunlock-evidence.sh HA2EXB0E` → `backup/HA2EXB0E-16+512/pre-unlock/`（getprop 全量/by-name/传感器清单/settings/Widevine=L1 + SHA256SUMS）；解锁后重测同一项做对照 | **G1-0**、Q1/Q5 |
| ~~**Q16**~~ | ~~三代「模板改 SN 自造解锁 blob」在四代 259 上是否有效~~ **已结（2026-10-03）：无效。** 四代 1.5.x ABL 换内嵌 key，**任何** sn.img（官网/三代免签模板/第三方签名）都过不了；且 **1.1.11.120 / 1.5.x 本身就不开放解锁命令**（版本门）。正解 = 降级 1.1.11.073 后 `fastboot oem unlock`（U2 已实测一次成功，无需 sn.img） | 不影响 G1（EDL 路不受 lock 位限制） | 已验证；`PITFALLS` #86、`RUNBOOK` §0.5 ★权威顺序、复盘 `archive/topics/复盘-2026-10-03-BL解锁.md` | 已结 |
| ~~**Q18**~~ | ~~第三方签名四代 blob（356 B）能否过 259 的 ABL 验签~~ **已结（2026-10-03）：不通过**——`flash unlock` OKAY（伪分区，不算数）但 `oem unlock-go` 失败；离线 18 组合验签全败 ⇒ 四代 ABL 换 key。**结论：买/求签名文件对 1.5.x 无用**；blob 与取证保留作证据（`backup/HA2EXB0E-16+512/sn-neko-zuxos.img`、`sn-neko` 取证 §5） | 已关：G1-0 靠降级解决 | `PITFALLS` #84/#86 | 已结 |
| ~~**Q17**~~ | ~~locked 态下「EDL 直写 + testkey 自签链」能否把 b 槽引导起来~~ **不再阻塞（2026-10-03）**：U2 已解锁 → 本实验从「必需」降为「可选」；`scripts/build-locked-chain.sh` 离线验证全绿，**真机未验**（无 locked 单元） | 若将来拿到 locked 新单元且想保住 Widevine L1/保修，本实验仍可取代解锁 | 照旧：`qdl` 写 `boot_b`/`dtbo_b`/`vbmeta_b` 后从 b 槽引导；失败留屏幕状态/日志 | G1-1（可选） |
| Q10 | TF 卡间歇写丢失是卡、还是 `sdhci-msm` flush/cache | G1 硬验收 #8 | 换卡 A/B + `fio verify` 长跑 | G1-6 |
| Q11 | DP 输出被 `disabled` 的 ADSP altmode/UCSI 能否修好 | 外接显示能力 | 先只读勘察 `pmic_glink`/`ucsi` 日志与 DT 依赖 | G1-9 |
| Q12 | 温控缺 OEM 层（`lenovo,sys-temp`/BCL）会不会在长期负载下露短板 | 安全边界 | 长时压测（≥2 h）+ `thermal-watch` 采样，看壳温与限频层级 | G1-8 附带 |
| **Q13** | ~~AVF 资产（crosvm/vm/microdroid_kernel/u-boot.bin）主机上找不到~~ **已解决（2026-10-04，离线提取）** | C8/R2 VM 路线的地基资产 | 不需设备：从原厂 259 system 镜像 `/mnt/Samsung/l2/system_a.pristine.img` 的 `/system/apex/com.android.virt.apex`（87.8 MB）debugfs 提取 → `backup/avf/`（crosvm 含 **Gunyah** 后端、microdroid_kernel **6.6.77-android15-8**、u-boot.bin/rialto.bin/initrd 全；SHA256SUMS）；`scripts/extract-avf-assets.sh` 可重跑 | ✅ 资产部分已闭；**a 槽覆盖前真正不可复得的只剩 C0（真机 getprop/DRM/传感器/App 行为）** |
| **Q14** | **C4 UDP HAL 上机三未知**：① 容器 UDP 52012 从 waydroid0 网桥是否可达（容器防火墙）；② overlay 的 .rc/.so SELinux context；③ Termux 转发器实际传感器名与映射 | C4 验收前置 | 部署后逐项：`deploy-sensors-hal.sh --restart` → `dumpsys sensorservice`（5 个 elden 传感器?）→ 宿主 `sensord --send 容器IP --fake` → `dumpsys sensorservice` 事件计数增长；不通则查 `waydroid shell iptables -L` 与 logcat HAL 日志 | **C4**（代码/编译全就绪） |
| ~~**Q19**~~ | ~~locked b 槽实验三未知~~ **已结（2026-10-03）**：U2 走降级路解锁成功（`fastboot oem unlock`），locked 实验不再需要；三未知答案归档：① U2(259) vbmeta_b 顶层=8fcb864f；② 1.1 与 259 的 vbmeta 顶层/boot chain key 均为 **AOSP testkey 2597c218**（私钥在手），rollback 均 1738713600/0；③ dtbo 无 hash 校验需求由自造 vbmeta 控制。路 C 管线保留作资产 | — | — | 已结 |
| **Q20** | **流程病：引导链问题先外部取证/自研、后本地检索** ⇒ 把 7、8 月已定的结论（版本门、.120 trap、失败特征串、**U1 已于 2026-08-16 用降级路解成功一次**）在 10-03 重新发现一遍，多花一轮必败实验。根因：`references/*.md` 正文不入上下文，**不 grep 等于不存在**（`PITFALLS` #87） | 上不设防就会再犯（下次是新 ROM 版本 / 新单元 / AVB 参数） | 已落：① `AGENTS.md` 新增「本地优先」规则；② `RUNBOOK` §0.5 ★权威顺序置顶（含版本门与停手串）；③ 本文末一条 grep 命令作开场强制动作；④ 引用旧成功记录先查单元+固件态 | 流程（无单元依赖） |

---

### 2. 已知缺口的补救路径（G1 侧，简表；细节见 `DEVICE.md` §1.3）

| 缺口 | 类别 | 补救 | 状态 |
|---|---|---|---|
| 相机出流 | config/部署 | 整链用 `media-ctl` 设 raw Bayer 格式 + 使能链路（`scripts/camera-stream-up.sh`） | ✅ G1-5（Q9 已闭，2026-10-05） |
| 音频出声/录音 | tplg + 驱动时序 | 已修 BE graph 时序（`patches/0011`）+ WCD939x AMIC1 采集（UCM2 Mic） | ✅ G1-4（Q8 已闭） |
| TF 卡 | 驱动 bug 或卡 | 换卡 A/B 定性后再决定补丁方向 | ⛔ Q10 |
| DP 输出 | bring-up（非缺驱动） | 修 `pmic_glink` UCSI/altmode | ⬜ Q11 |
| NFC | DT compatible 不匹配 | 改 compatible + config | ⬜ 低优先 |
| SLPI 7 传感器 | **架构性不可做** | 不救硬件，救接口（容器内虚拟传感器） | → `ANDROID-COMPAT` §2① |
| TEE/SPU/hw-fence/Gunyah/PMIH010x/BCL/FM/ST54 | 私有或无源码 | 明确不投入 | ✗ 结案 |

---

### 3. 环境与流程类待办（不属功能，但会咬人）

| 项 | 现象 | 处理 |
|---|---|---|
| 代理 `127.0.0.1:7897` | ✅ **已恢复正常（2026-10-06 复核：`curl -x 7897 https://www.google.com` → 302）** | 现状 = **Clash Verge Rev / verge-mihomo**（root，mixed-port 7897，mode=rule，tun 关闭）；2026-10-05 已加 99 条校园/教育网 DIRECT 规则 + bashrc `no_proxy` 覆盖。排障/回滚见 `~/netfix/复盘-2026-10-05-教育网分流-clash规则.md`；凭据通道见 `~/netfix/凭据与下载通道-2026-10-05.md` |
| `/mnt/Samsung` 无 `nofail` | 掉盘卡开机 | ✅ 已修（A18，2026-10-02） |
| `qemu-utils` 缺失 | 不能造/转 guest 磁盘 | ✅ 已装（`/usr/bin/qemu-img`、`qemu-nbd` 在位，A13 勾销） |
| API 双重限流（20 req/窗口 + $30/3h） | worker"干净退出"像崩溃 | 用 provider `deepseek`；并发 ≤3；见 `archive/topics/复盘-2026-10-02-swarm.md` |
| vermagic 耦合 | 改 `CONFIG_LOCALVERSION` → 相机 `.ko` 全废 | 改内核版本必须整套重编 `.ko` |
| 备份目录命名 | 历史 `backup/new-tablet/` 语义已废 | 新操作一律 `backup/<SN>-<容量档>/`；脚本默认值参数化（A16） |

---

### 4. 风险登记（高影响，需你决策或知悉）

| 风险 | 概率/影响 | 缓解 |
|---|---|---|
| 解锁 U2 = 永久失去 Widevine L1 / 保修 / FOTA（全项目唯一 locked 单元） | 高概率 / 中 | 解锁前 locked 基线已入库（`backup/HA2EXB0E-16+512/pre-unlock/`，Widevine=L1 已记）；G2 的 U5 用例按 L3 上限做预期 |
| 1.5.10.259 屏蔽解锁指令导致白跑一轮 | ~~低/低~~ **已发生（2026-10-03）** | 已由全量降级 1.1.11.073 解决（G1-0 已关闭）；**以后新单元直接判版本门→降级，不再在 1.5.x 上试解锁**（`RUNBOOK` §0.5）。注：U2 现态已回 **259 + unlocked**（2026-10-03 实机核验） |
| 覆盖 a 槽后强检测/银行类 App 完全不可用 | 中 / 中 | Q5 先取证；保留 stock + EDL 恢复；容器不行就换路线而不是硬扛 |
| GPT 手术/回收分区写坏 LUN0 | 低 / **高** | 手术前 `fastboot fetch` + GPT 双表 dump + EDL 包在手；只写主/备表两处；写后读回校验 |
| 设备热失控（曾 103 °C） | 低 / 高 | 分级 trips 已在线；压测必带 `thermal-watch`，超 90 °C 自动降级 |
| **空闲熄屏→重启（U2 实测）** | **已发生 / 高** | 禁止空闲熄屏（`idle-delay=0` 或 phosh caffeine 常开）作为临时规避，并把它写进 `start-desktop.sh`/rootfs 归档；根治前 **不要**在不可回滚的持久系统上做熄屏实验（详见 `archive/topics/复盘-2026-10-03-持久化与睡眠.md`） |
| **未验证内核增量（vk34 之后）** | 已发生 / 高 | **✅ 已定位（2026-10-03）**：vk34recon 正常 / vk40 回归 ⇒ 源在 vk34 之后的 5 文件内核增量；逐项二分留将来。见 `Q22` + `archive/topics/AUDIT-since-vk34-2026-10-03.md` |
| 边充边跑掉电（PMIC 默认 100 mA） | 中 / 中 | 上机前 `charge-ctl.sh` 拉满输入电流；长任务挂充电器并监控 |
| 单一路线依赖（只押 Waydroid） | 中 / 中 | 保留 redroid 作 R1' 备胎（`ANDROID-COMPAT` §0） |

---

### 5. 勾销规则

- 勾销一条 Q ⇒ 必须给出：命令、原始输出片段、结论一句话、生效文档链接（`DEVICE.md` / `TASKS.md §6`）。
- 不允许"口头已确认"：控制面 OK ≠ 数据面 OK（`GRAPH_START status=0` ≠ 可听；graph ENABLED ≠ 出帧）。

---

## 6. G2 安卓兼容方案（ANDROID-COMPAT）

### 0. 结论先行

**主路线 = 容器（Android-in-Linux），备选 = 虚拟机，观察 = 原生合成器方案；三条都不依赖 a 槽常驻。**

| 路线 | 形态 | 与"无安卓"前提 | 本地现成度 | 定位 |
|---|---|---|---|---|
| **R1 容器** | **Waydroid**（LXC + AIDL/HAL + 我们的 freedreno） | ✅ 完全符合 | ✅ Mesa 26.1.8 解 A830 chip-id、GAPPS 镜像在手、内核 binder/XFRM/netfilter 已开、代理通路已通 | **主力，先做（C1–C6）** |
| **R1' 容器备胎** | **redroid**（Docker/podman/k8s，arm64 官方支持，GMS 经 OpenGApps/MicroG/MindTheGapps） | ✅ 符合 | ⬜ 未装；与我们内核的 binder 配置兼容 | **备胎**：R1 受阻（图形/HAL 层）时切换验证 |
| **R2 虚拟机** | Android/Debian guest；本机 **无 KVM**（消费者机：XBL 在 secure-boot 链内加载 hyp，主线 `-el2.dtb` overlay 模式只适用 Qualcomm dev kit）⇒ ① KVM-in-EL1+Gunyah backend（RFC 00/34，Linaro，2025-04，配 `qemu-for-gunyah`，需数周 port，WIP）或 ② QEMU TCG（可用但慢，Android 不可接受） | ✅ 不需要 Android 宿主（方案①） | ⚠️ AVF/DroidVM 是 Android 侧用法（与新前提冲突）；Gunyah ABI 兼容性待上机探测（`dmesg \| grep gunyah`） | **调研，不承诺**（C8 书面结论已出，维持低优先） |
| **R3 原生** | droidloom（Wayland 直出窗口，shared-kernel；denial 同类） | ✅ 形态最优雅 | 🟡 repo 声称支持 arm64 平台，但**预览包只发 x86_64 Arch**；arm64 = 自构建（Rust+podman+AOSP pin，pacman 包需适配本 rootfs）；freedreno 路径未验证 | **只跟踪上游**（GAPS Q3，R1 受阻再试） |
| （相邻）| Win-x86 转译 Box64+Wine | ✅ | ✅ **PoC 已成功** | 已交付，与 R1 共用 chroot/防护范式 |

> **为什么容器优先**：它是唯一"不重启、不离开 Linux、能用我们自己的 GPU 驱动栈、可单独卸载"的形态；
> 且社区在**纯 Linux 宿主**上把 GMS/Widevine 做进容器的先例最多（`RESOURCES.md` §1.3）。

---

### 1. 兼容度评估（5 维，**分数随实测更新**，当前为初始估计）

| 维度 | R1 Waydroid | R1' redroid | R2 VM | R3 原生 |
|---|---|---|---|---|
| C1 功能兼容（App 能装能跑，含厂商 App/游戏） | 4 | 4 | 4 | 3 |
| C2 身份兼容（GMS 登录、Play Integrity、Widevine） | **待调查**（社区有做法，本机未测） | **待调查** | 待调查 | 待调查 |
| C3 性能（GPU/帧率/内存） | 4（freedreno 直驱） | 3–4（GSI + binder GPU HAL） | 2–4（图形最不确定） | 4 |
| C4 系统集成（窗口/输入/**传感器**/音频/相机/文件） | 3（传感器、相机是短板） | 3 | 2 | 4 |
| C5 可逆与风险（可卸载、不触信任根） | 5（删容器即净） | 5 | 4 | 5 |

**分数口径**：1=不可用 3=可用有坑 4=日常够用 5=等同真机。**C2 一律先填"待调查"，实测后回填**（C3/C4 允许边测边改）。

---

### 2. 兼容层设计（`elden-droid`）：容器优先的四件事

```
   Phosh/Wayland ── eldroid-cli (统一入口: start/stop/status/reset)
        │
        ├── R1 waydroid session ──┐
        ├── R1' redroid container ┤（二选一，切换验证用）
        │                         ▼
        │        ┌────────────────────────────────────────┐
        │        │ eldroid-bridge（我们要写的适配层）      │
        │        │  ① 传感器注入  uinput + UDP sensord     │  ← C4，补 SLPI 7 颗缺失
        │        │  ② 相机共享    v4l2loopback + sampler   │  ← C5（待 G1-5 相机出流）
        │        │  ③ 音频通路    PipeWire → AudioReach    │  ← C6（待 G1-4 听声）
        │        │  ④ 身份/商店   GApps 注入 + 未认证注册  │  ← C3（先复现社区做法，不预设结果）
        │        │  ⑤ 网络/代理   已通（netd+默认路由+http_proxy）
        │        └────────────────────────────────────────┘
        └── 回退保险：stock Android 镜像包 + EDL 全量包（可整机复原，但非常驻）
```

| # | 缺口 | 我们的补法 | 不做什么 |
|---|---|---|---|
| ① | SLPI 7 颗传感器（IMU/磁力/气压/温湿度/SAR/霍尔/光感）主线不可用 | **UDP HAL 真实现**（原 uinput 方案作废——waydroid sensors HAL 是 stub，不读 evdev，见 `archive/topics/SENSORS-WAYDROID-STUB-2026-10-03.md`）：waydroid-build 树 `hardware/waydroid/sensors/Sensors.cpp` 实现为「UDP 收值 → 喂 framework」（已编译成功）；入口 prop = `waydroid.sensors.enabled`（**勿用** `waydroid.stub_sensors_hal`，会触发 framework 锁旋转）。真值来源：① `scripts/eldroid-sensord --send 容器IP --fake`（兜底纯软件轨迹）；② 同型号另一单元 a 槽 Android 经 Termux:API 转发（`env-pass/scripts/sensor-send-termux.sh`，设备等价的直接红利）；③ 其他安卓设备 | 不移植 QMI-SNS/不救 SLPI 固件；不动 Qt5/sensorfw（droidian 路线，Alpine 不现实） |
| ② | 容器无相机（厂商 camera-provider 不可用） | mainline camss 出流后 `v4l2loopback` 转发进容器 | 不写厂商 camera HAL |
| ③ | 容器音频路径未接（AudioReach 刚通） | PipeWire 桥接；先打通播放，再测录音 | 不追求低延迟游戏音频（先量化） |
| ④ | GMS/商店/DRM 身份 | **按社区既有做法逐条复现并记录**：GApps 包（OpenGApps/MindTheGapps/MicroG 三选 + **WayDroid-ATV arm64 GAPPS 镜像** 2026-01 SourceForge）、未认证设备注册流程、Widevine L3 注入（**x86-64 有现成库；arm64 仅 Android 11 有、A13 无**——2026-10-07 `waydroid_script` 源码核实）；每次只变一个变量 | **不预设"不可能"**；不做密钥伪造/绕过安全启动 |
| ⑤ | 传感器之外的输入/窗口 | 触屏/键盘/鼠标由主线输入子系统透传；窗口用 phoc freeform；马达走 `aw86927` + 容器 `vibrator` shim | — |

---

### 3. 「a 槽可弃」带来的风险与对冲（必须如实记账）

| 风险 | 影响 | 对冲 |
|---|---|---|
| 放弃 Android = 失去"100% 兼容兜底"，兼容度完全取决于 R1/R1' | 强检测 App / 银行类 / L1 DRM 场景可能整体不可用 | 保留 `backup/stock-259/` + EDL 全量包 + `restore-259/` 流程；**恢复只需一次 EDL**（不是不可逆） |
| 一旦 a 槽被覆盖，无法再"用真 Android 校准" | 无法对照真机行为 | **在覆盖前先完成一轮真机对照取证**（身份/DRM/App 行为/传感器读数），列为 GAPS Q5 |
| 手术回收 Android 分区（`super_a/b` 等）扩大 Linux 空间 | 更彻底不可逆 | 只在 G1 稳定后做，做前 EDL 备份 + 读回校验；分区表脚本化 |
| 无 Android ⇒ AVF 路线（需 Android 宿主）自动失效 | VM 路线只剩高成本方案 | 所以 VM 定为"调研不承诺"（C8）；若将来需要，任一台单元刷回 stock Android 即可（等价原则保证可换机） |

---

### 4. 待你拍板（2 条，都是取舍不是参数）

1. **是否 Phase B 回收 Android 专属分区**（`super_a/b`、`boot_a`、`recovery_a` 等，腾数十~上百 GiB 给 Linux）？
   —— 好处：一次解决容量；代价：回退只剩 EDL 全量刷。默认**暂不回收**，等 G1 全绿。
2. **在覆盖 a 槽前，是否先做一轮"真 Android 对照取证"**（GAPS Q5：身份属性、DRM 级别、传感器读数、目标 App 行为）？
   —— 我建议**做**，成本低且不可复得。

---

### 5. 验收用例集（C9/A15，2026-10-02 定稿）

> 用法：上机后逐条实测，结果填「实测」列；打分口径同 §1（1=不可用 3=可用有坑 4=日常够用 5=等同真机）。

| # | 用例 | 验收阈值 | 依赖 | 实测 |
|---|---|---|---|---|
| U1 | Play Store 登录 | 登录+同步完成 ≤ 5 min；失败模式记录 | C2 | |
| U2 | Play 安装 3 个目标 App | 成功率 3/3；≤ 3 min/App | C2 | |
| U3 | 地图旋转（传感器注入） | 方位角 <500 ms 反映到视图，无跳变 | C4 | |
| U4 | 视频通话（相机+音频） | 对端可见可闻；端到端延迟 ≤ 400 ms；5 min 不断流 | C5+C6 | |
| U5 | 流媒体（Widevine） | YouTube/Disney+ 可播；记录实际分辨率与 DRM 级别（L3 上限如实记） | C3 | |
| U6 | 游戏（GPU） | 目标游戏 30 fps @ 默认画质；帧时间抖动 <30% | — | |
| U7 | 相机出流进容器 | 预览出帧 ≤ 2 s；前后摄切换成功 | C5 | |
| U8 | 容器音频 | 播放可听；延迟 <100 ms；录音通路单独记 | C6 | |
| U9 | 多窗口/freeform | 2 窗口并排不崩；焦点切换正常 | — | |
| U10 | 休眠唤醒 + 切槽回退 | 熄屏唤醒不丢容器会话；a/b 往返后容器数据完好 | C7 | |

### 6. 版本基线与「自编 / 预制」账（2026-10-06 裁决）

**A. 容器 Android 版本：维持 LineageOS 20（Android 13），不追新版本。**
换版本本身不是编译问题（社区有现成镜像），且**不解决 G2 的两个真瓶颈**（arm64 Widevine L3 无库、GMS/PI 认证）；
新版反而 **Play Integrity 更严、arm64 支持更差**。

| 版本 | 现成 arm64 镜像 | Widevine(arm64) | 备注 |
|---|---|---|---|
| **LOS 20 / A13（现用）** | ✅ 官方 Waydroid OTA | ❌ | Waydroid 官方主线；PI 绕过先例最多 |
| LOS 21 / 22.2（A14/15） | 社区，主要 x86_64 | ❌ | 集成有 bug（`waydroid app install` 坏，需 adb） |
| LOS 23.2（A16） | ❌ 最新 release 原文明写「ARM64 images are NOT available」 | ❌ | 越新越偏 x86_64/PC |

**触发换版本（须有证据，不预设）**：① 目标 App 出现 `minSdk > 33` 装不上；② 某个必须能力只在 ≥A14 有；
③ LOS 20 镜像停更、而新版镜像开始带 **arm64** Widevine L3。
**换法**：优先下现成镜像（~2 GB），Mesa 对新分支重编一次（~10 min）后 bind-mount，**不重编整个 Android**。
证据：`RESOURCES.md` §1.3；WayDroid-ATV releases 页（20260717「LineageOS 23.2 / ARM64 not available」）。

**B. 后续各线的编译量账**

| 线 | 自编内容 | 结论 |
|---|---|---|
| **容器 R1（LOS 20）** | Mesa（已编，偶发重编）+ sensors HAL（已编）+ 可选一次 `vendorimage` | 已 2/3 完成；编译不是瓶颈 |
| **Win-on-ARM VM（DroidVM / crosvm+Gunyah）** | 主链全预制：DroidVM APK + `DroidVM-Prebuilts`（含自建 crosvm，带 SBSA UART/PmReset）+ 驱动 `gunyah-guest-drivers-windows` **dev release zip** + 微软 Win11 ARM64 ISO；**唯一可能要编 = guest UEFI 固件**（本地 `edk2-aarch64-gunyah` 1.5 G，含 Windows ramfb 分支；EDK2 构建 ~10–30 min）——若 prebuilts 已带则 **0** | **基本不用编**；真工作量在：① 映象构建需 **x64 Windows 或 Apple Silicon 主机**（本机 x86_64 Linux 缺此平台）；② `viogpu` **未移植** ⇒ 无 GPU 加速（仅 simplefb）；③ 需 a 槽 Android + root |
| **Win-x86 转译（G3）** | **0**：box64 deb / Wine（Ubuntu amd64）/ Hangover wowbox64 / DXVK / VKD3D-Proton 全为预制；PoC 已成功 | 剩配置+性能+打包；真要 FEX-Emu 也有预制 release |

> 配套：`RESOURCES.md` §2.5 P3「AOSP 工作树整树删」一栏据此**裁决保留**（Mesa 偶发重编需要它，与换不换安卓版本无关）。

**C. GPU 栈的编译量（2026-10-06 核账）**

| 层 | 组件 | 编？ |
|---|---|---|
| **宿主内核**（msm DRM + adreno a8xx） | 我们的 mainline 树 | ✅ 自编，但本就属 G1 主线；`patches/` 里**无 GPU 专属补丁**（0002/0006/0007/0008 均属显示/面板） |
| **宿主固件** gen80000 `zap/sqe/gmu/aqe` | vendor 提取 | ❌ blob |
| **宿主用户态** GL/Vulkan | Alpine `mesa-dri-gallium`(freedreno) + `mesa-vulkan-freedreno`(Turnip) + `mesa-egl` + `vulkan-loader` | ❌ **apk 预制、零编译**（PITFALLS：chip-id 补丁**不要**打，原版才对；未打过） |
| **Android 用户态** | AOSP `external/mesa`（freedreno GL + Turnip）+ minigbm/gralloc + libdrm | ✅ **自编**：`scripts/mesa-build.sh` 定向 make 11 库（已交付，~5.5 min；ccache 热后 ~10 min）；**已完成** |
| **Android 原厂 GPU blob**（libgsl/Adreno utils/KGSL） | Waydroid MAINLINE vendor 用 Mesa 替代，不用 | — |
| **VM 内图形**（virglrenderer/gfxstream） | DroidVM/AVF 预制 | ❌（Windows guest 的 `viogpu` 才是未移植缺口） |

**重编触发**：① 内核 DRM/A830 特性变化或 hang 调优（`has_fs_tex_prefetch` / 26.3 turnip 分支）→ Mesa 重编 ~10 min；
② 换 Android 版本（若触发）→ 对新分支重编一次；③ 想把 bind-mount 改成持久 `vendor.img` → `make vendorimage`（1–3h，一次）。
**结论：宿主用户态 GPU 编译量 = 0；Android 用户态 GPU = 1 组 11 库（已完）；剩下只有偶发 mesa 重编与可选 vendorimage。**

## 7. 上游化任务（M 系列，用户 2026-10-04 定：日后可合并为主线）

> 审查已完成（2026-10-04，只审不改）：payload=相对主线 v7.2 的 **125 改 + 11 新文件（≈12.4k 行）**，
> 分级 A/B/C/D 与推进顺序见 `archive/topics/UPSTREAM-REVIEW-2026-10-04.md`。机械检查全净
> （checkpatch/DTC/dt-validate 仅 1 红点=usb@a600000）。

| ID | 任务 | 状态 | 依赖 | 判据 | 证据 |
|---|---|---|---|---|---|
| M1 | 干净上游资产树（upstream tip + payload 重放，剔除 D 类与 vk 历史） | ⬜ | — | 树能编出 vk 等价功能镜像 | 审查档案 §4 |
| M2 | 首发小系列 A1(GC 块)+A2(battmgr)+A3(aw86927 SRAM) | ⬜ | M1 | 发至对应 ML 获 review | 同上 §1-A |
| M3 | 板支持系列（DTS+qcom.yaml；先修 usb@a600000 schema 红点、去 vendor-only 属性） | ⬜ | M1 | dtbs_check CI 绿 | 同上 §3.4 |
| M4 | 大件立项：B8 camss（media）/ B6 ath12k PEACH（wifi）/ B3 hci_qca PERI（bt） | ⬜ | M1 | 各成多轮 review 工程 | 同上 §1-B |
| M5 | C2 dm-default-key 从上游包剥离 → 持久根 out-of-tree patchset | ⬜ | — | 上游包内无 Android vendor ABI | 同上 §1-C |
