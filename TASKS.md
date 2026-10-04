# 任务拆解与进度（TASKS）

> 领域层活文档之一；文档分三层（领域 / 元 / 证据），定义与 SSOT 见 `INDEX.md` §2。
> **本文件是唯一任务台账**：所有 ID、状态、下一步只在这里维护；专题文档只放过程与证据。
> 纪律：worker 只报「命令 + 原始日志」，编排者**独立复跑**；每步留回退；设备锁串行、主机侧并行。

---

## 0. 进度总览（数字）

| 目标 | 已完成 | 进行中 | 未开始 | 完成度 |
|---|---|---|---|---|
| **G1** 健全 Linux + 驱动原厂固件 | 23 项（显示/图形/触屏/网络/电源/相机驱动栈/音频播放+输入/温控/串口/基准脚本…） | 3（相机出流、TF 卡、BT 配对） | 3（DP、NFC、CDSP） | **~85%** |
| **G2** 无安卓前提下的安卓兼容 | 6（Waydroid 图形/内核/GAPPS 镜像/代理通路/Win-x86 PoC/**C9 用例集**） | 4（Play 登录收口、切槽脚本、C8 上机探测、**C4 部署验证**——代码/编译全就绪） | 4（相机共享、音频容器、C3 实测…） | **~45%** |
| 运维/资产 | 内核 vk45、rootfs 归档、Mesa 包、文档集重构、`qemu-utils` 已装（A13）、fstab nofail 已修（A18）、**C4 传感器链（A14）**、**env-pass provision（A17）** | — | — | ✅ |

---

## 1. G1 任务分解（功能健全的 Linux + 原厂固件全部驱动）

| ID | 任务 | 状态 | 单元状态要求 | 验收判据 | 关键文件 |
|---|---|---|---|---|---|
| G1-0 | **U2 BL 解锁** | ✅ **已完成（2026-10-03）**——走**降级路**：线刷 `TB322FU_ZUXOS_1.1.11.073`（出厂 1.1/Android15）后 `fastboot oem unlock` 一次成功。第三方 blob（A3）与官网 sn.img（B）未用上且**已判死**（四代 1.5.x 换 ABL key）；路 C（EDL+testkey 链）成**保留资产**（`build-locked-chain.sh` 验证全绿） | U2 | ✅ `unlocked:yes`、`oem device-info: Device unlocked=true / critical unlocked=true` | `PITFALLS` #86–#87、`RUNBOOK` §0.5、`archive/topics/复盘-2026-10-03-BL解锁.md` |
| G1-1 | vk40 基线上机（持久直启） | ✅ **已完成（2026-10-03 U2）**：b 槽刷 blank dtbo + vk40 RAM 直启，后切持久版；重启后 `findmnt /`=`/dev/sda17`（ext4），**Phosh 自启**（phoc/phosh/gnome-session 在跑）。踩坑：`fastboot boot` 不清 dtbo 会卡 logo（`PITFALLS`/`复盘.md`） | U2（**已解锁**） | `uname -r`=`7.2.0-debug-gba28ec16f01f-dirty`；`findmnt /` 持久根=linux17 | `RUNBOOK-BRINGUP.md`、`bootslot-b/boot_b_vk40.img` |
| G1-2 | GPT 手术：按 §3.2 体量给 `linux17` | ✅ **已完成（2026-10-03 U2）**：`userdata` 449.7→**256.7 GiB**、新增 `linux17`=**193.0 GiB**（idx16，`/dev/sda17`）；写后重 dump 校验 CRC OK | U2 | `list` 读回：`linux17` 末扇区=`last_usable`、CRC OK | `backup/HA2EXB0E-16+512/gpt_{main0,backup0}.bin`、`gpt_post-surgery_*` |
| G1-3 | 恢复持久 rootfs（3.44 GB 归档） | ✅ **已完成**：`mkfs.ext4 -L linux17` + 解包 30852 项（8.3 GB）→ 持久根 | U2 | `df /` 与归档项数一致；Phosh 自启 | `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz` |
| **G1-23** | **vk34→vk40 未验证增量回归审核** | 🟡 **第二遍进行中（2026-10-03）**：逐 hunk 分类（N1–N4）+ 建 V1/V2 二分镜像；取到**可量化回归**（`vk40re` vblank=6/PPM=1 vs `vk34recon` 0/0）。⚠️ 静默复位间歇→单次无统计意义；**V1/V2 尚未取到有效样本**。**第三遍（审计，`AUDIT3`）**：排除「副作用在轮询内」（0 条）；发现真隐患=「reboot/boot 与长轮询同条命令被 harness 杀死」（4/10 条 `Command aborted`）；**新混淆：持久 `boot_b`=vk40 内核**，复位必回退到 vk40 ⇒ 复位相关跨版本比较作废；vblank/PPM 版本归属仍可信。**下一步：先烧 `bootslot-b/boot_b-vk34recon.img` 作已知基线** | 任一 mainline | 同口径 dmesg 计数（V1、V2 各 ≥1 有效样本）+ 各版 ≥3 轮长时窗 | `archive/topics/AUDIT2-post-vk34-bisect-2026-10-03.md`、`AUDIT3-polling-sideeffects-2026-10-03.md`、`AUDIT-since-vk34-2026-10-03.md` §5、`GAPS` Q22 |
| **G1-22** | **熄屏/睡眠稳定性** | 🟡 **根因范围已锁定**（2026-10-03 实机：`vk34recon` 不重启 / `vk40` 重启 ⇒ 源在 vk34 之后的 5 文件内核增量；逐项二分留将来）。当前规避=禁止空闲熄屏。**补充（2026-10-03）**：vk40 可量化到的伴生回归 = 显示提交后 `DPU vblank timeout` + `UCSI PPM init failed`（vk34 无） | 任一 mainline | 长时空闲（≥ 2×idle-delay）不重启；电源键熄屏/唤醒正常；`dpms-watch.sh` 全程无复位 | 复盘 `archive/topics/复盘-2026-10-03-持久化与睡眠.md`、`GAPS` Q21/Q22、`AUDIT-since-vk34` §5 |
| **G1-24** | **Linux 侧刷机控制**（reboot→fastboot、选槽、清启动次数）——用户 2026-10-03 定的第一个新增功能。设计：`archive/topics/FLASHCTL-2026-10-03.md`。**S1 ✅ 已交付**：`scripts/eldroid-bootctl` + `scripts/flash-recovery.sh`。**S2 ✅ 已打通（2026-10-03 深夜，实测）**：否定 SDAM/BCB 三路后，落 **`elden/vk41-psci-reboot` @`4b643f169`**（`psci.c` ~35 行，把 reason `bootloader`/`edl` 映射为 **PSCI SYSTEM_RESET2 vendor reset** `0x80010001/0x2`、`0x80000000/0x1`）；刷入 boot_b 后 `eldroid-bootctl reboot bootloader` **真进 fastboot**（主机 `fastboot devices`=HA2EXB0E，current-slot=b）。⚠️ 上游该机制=13补丁大系列（未合并），本树是**最小设备侧钩子**（将来上游合入可替换）。剩：① `reboot edl` 实测（EDL 暂缓）；② TWRP 路线=`reboot bootloader`→`fastboot reboot recovery`（TWRP 能否在 mainline 内核下启动待测）；③ slot 写操作验证（与 **C7** 合流） | 任一 mainline | `reboot bootloader` 进 fastboot ✅；`reboot edl` 进 9008；slot 写后读回校验 | `archive/topics/FLASHCTL-2026-10-03.md` §7–§9、`scripts/eldroid-bootctl`、`PITFALLS` #88 |
| **G1-25** | **桌面电源/会话（无 systemd）**：长按电源键/电源菜单无法关机（60s 倒计时不动、立即关机无反应）、开机“卡锁屏” | ✅ **已真机验证（2026-10-03 深夜）**：①～② 见旧轮（缺 elogind 守护/`idle-delay`锁屏）已修；**③ 真根因**：elogind 的 helper `/sbin/{poweroff,reboot,halt}` 是 busybox applet，**不带 `-f` 只 `kill(1,SIGUSR2/TERM/USR1)`**，而本机 PID 1=`/init`(shell) 不处理 → 关机/重启**假成功**（dmesg 有 `System is powering down.` 但无 `reboot: Power down`），且让 elogind 永久卡 `OperationInProgress`。修复：`scripts/fix-logind-poweroff.sh`（`start-desktop.sh` 启动 elogind 前调用，幂等）把三个 symlink 换成 `busybox <applet> -f`；`strace -e inject=reboot:error=EINVAL` 已证直调 `reboot(2)`。内核 `pm_power_off=psci_sys_poweroff` 已就位 | U2 | ✅ 长按电源键 → phosh 菜单「立即关机」**真断电**（USB 已拔）；`HandlePowerKey=ignore` 已重启持久。⚠️ **USB 连着时 `loginctl poweroff` 会立即重启**（疑似 VBUS/充电检测自动开机）→ 关机前先断 USB | `archive/topics/LOGIND-POWEROFF-2026-10-03.md`、`PITFALLS.md` #89、`scripts/fix-logind-poweroff.sh` |
| **G1-4** | **音频可听** | ✅ **已打通（2026-10-04 实测听声）**：vk43（vk42 + tplg 修正）冷启，长按开 mixer `numid=8`、音量 `numid=1/2=1023` 后 **扬声器出声**。关键根因=tplg 的 MI2S **SD 线错**（SD0→SD1，见 `PITFALLS` #90）。客观证据：`SEC_MI2S_IBIT`=1.536MHz、功放 SYSST **0x2315（bit8 SWITCHING 置位）**；DAPM 全 On。剩：录音、双功放分别验证、UI 音频服务（✅ PipeWire+UCM 已做，见 `PITFALLS` #90）。**输入端 ✅ 已打通（2026-10-04）**：本机麦克风是**模拟麦接 WCD939x**（非 DMIC）；做 WCD939x bring-up（DTS codec + swr1/swr2 + `wcd-capture-dai-link` TX3、去 VA DMIC），补采集 DAPM mux/mixer 控件后 `arecord -D hw:0,2` 出真实音频（AMIC1 最响），持久化到 UCM2 `SectionDevice."Mic"`（`wpctl` 有 Source）。见 `archive/topics/WCD939X-2026-10-04.md`、`PITFALLS` #91。 | 任一 mainline | `amixer cset numid=8 on; speaker-test` 可听 ✅ | `archive/topics/AUDIO-SDLINE-2026-10-04.md`、`patches/0011`、`scripts/audio-tplg/` |
| **G1-5** | **相机出流**（graph 已 ENABLED） | 🟡 待出流 | 同上 | `qcam`/`gst` 出帧；前后摄切换 | `archive/topics/CAMERA-2026-10-02.md`、`out/camera-modules/` |
| **G1-6** | TF 卡写稳定性 | 🟡 未定性 | 任一 | 换卡 A/B + `fio` 校验无丢失 | `archive/topics/TF卡-2026-09-30.md` |
| G1-7 | BT 配对收口 | 🟡 | 任一 | 配对+音频回连 | `archive/topics/BT-2026-09-30.md` |
| G1-8 | CPU/GPU 基准（脚本已备） | ⬜ | 任一 mainline | `bench-run.sh` 出分；温控不破 82 °C | `scripts/bench-run.sh`、`scripts/bench-install.sh` |
| G1-9 | DP 输出（解锁 `mdss_dp0`） | ⬜ P1 | 任一 | `/sys/class/drm/*-1` connected | `DRIVER-MAINLINE-AUDIT` §3 |
| G1-10 | NFC compatible 修正 | ⬜ P2 | 任一 | `nfc-list` 可见 | 同上 §2.3 |
| G1-11 | CDSP 启用（可选加分） | ⬜ P3 | 任一 | `remoteproc1` running | `backup/fw/modem/` |
| ✅ G1-12…21 | 显示 165 Hz、图形 A830、触屏、WiFi、BT 基础、充电+旁路、温控分级、带外串口、启动 ~5 s、触觉 | **已完成** | — | 见 `DEVICE.md` §1.3 | `PANEL-REFRESH`/`THERMAL`/`CHARGE`/`OOB-CONSOLE` |

---

## 2. G2 任务分解（**前提：不依赖 Android**，参考社区资源做 ARM Linux 侧安卓兼容）

> 路线定义见 `TASKS.md §6`。ID 前缀 `C`（compat）。

| ID | 任务 | 状态 | 层 | 验收 | 备注 |
|---|---|---|---|---|---|
| **C0** | **真 Android 对照取证**（趁 U1 还是 stock+root，**覆盖 a 槽前必做，不可复得**） | 🟡 **采集器已就绪，待 U1 接入**：`scripts/c0-android-evidence.sh` | 基线 | `getprop` 全量、`dumpsys media.drm` 级别、7 颗传感器 30 s 采样 CSV、5 个目标 App 关键流程录屏 | 兼容层的“标准答案”；见 `TASKS.md §5` Q5。传感器 CSV + App 录屏需人工（脚本尾有提示） |
| **C1** | Waydroid 在 vk40 端到端复跑（去掉旧的 bind-mount 路由 workaround） | ⬜ 下一步 | 容器 | `waydroid status` 有 IP、SurfaceFlinger running、桌面可点 | Mesa 26.1.8 + GAPPS 镜像在手 |
| C2 | Play / GMS 登录收口（旧结论：卡在外部上行与代理） | ⬜ 需你给上行+凭据 | 容器 | Play Store 登录成功 + 装 3 个目标 App | `archive/topics/PROXY-WAYDROID-2026-10-02.md` |
| C3 | **身份兼容性取证**（GMS/Play Integrity/Widevine 能做到哪一级）——**不预设结论** | 🟡 社区侧取证已补全（2026-10-02，见 `RESOURCES.md` §1.3） | 容器 | 出「社区先例 × 本机实测」对照表 + 回填 `TASKS.md §6` §1 的 C2 格 | 先例：redroid / waydroid_script `certified` / WayDroid-ATV（arm64 GAPPS 有、L3 仅 x86-64） / PlayIntegrityFork；**实测需设备+上行** |
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

## 3. 已作废/合并的旧任务线（只登记，不再展开）

| 旧 ID | 现状 |
|---|---|
| swarm `task-1…13`（2026-10-02 那轮 13 项） | **12/13 完成**，仅 task-7 基准未派 → 并入 **G1-8**；日志 `logs/agent-logs-2026-10-02/`、复盘 `archive/topics/复盘-2026-10-02-swarm.md` |
| `task-14…17`（D 轨 AVF） | 改 **C8**（且因"无 Android"新前提降级为低优先调研） |
| `PLAN-NODEV` A 轨/B 轨 | A 轨并入 §2.1；B 轨并入 `RUNBOOK-BRINGUP.md` + G1-1…3 |
| 「两轨分机」路线决定 | 作废（设备等价）；技术结论并入 `DEVICE.md` §1.2/`TASKS.md §6` |
| 「新机 = mainline、旧机 = D 轨宿主」角色表 | 作废 → 按状态分派（`DEVICE.md` §2.3） |

---

## 4. 下一步（按顺序，含并行项）

1. ⛔ **先救机器**：U2 现处于「熄屏即重启」环、不可达 → 按 `archive/topics/复盘-2026-10-03-持久化与睡眠.md` §5 恢复（物理键→fastboot→回刷 RAM 核，再把持久根 `idle-delay` 改回 0 / 在 `start-desktop.sh` 里禁用空闲熄屏）。
2. **G1-22 熄屏/睡眠稳定性**：定位 `ucsi_glink PPM` 与熄屏的关系；产出「空闲不重启」的自动验收 + 写进 rootfs。
3. **C0 真 Android 对照取证**（U1 或 U2 a 槽；覆盖 a 槽前）。
4. **G1-4 / G1-5**：音频听声 + 相机出流（各需你 1 次现场确认）。
5. **C1 → C3 → C2**：Waydroid 复跑 → 身份/DRM 取证 → Play 登录（C2 需你恢复上行 + 代理 + 凭据）。
6. 并行（不占设备）：A15 用例表 ✅、A14 ✅、A17 ✅。
7. 视结果再排：G1-6 TF 卡、G1-9 DP、C5/C6、C7 切槽脚本、C8 上机 Gunyah 探测（零成本顺带）。

---

## 5. 查漏补缺（GAPS）

### 1. 待调查（Open questions，按优先级）

| ID | 未知 | 为什么要知道 | 怎么测（最小实验） | 关联任务 |
|---|---|---|---|---|
| **Q22** | **vk34（2026-10-01）之后未逐版验证的内核增量**：5 文件（DTS 分级热 trip、q6apm.c/q6prm.c/audioreach.c/q6apm-lpass-dais.c 音频）+ `config-vk40-bringup`，全部只在 vk40 叠加体上上过机，与「vk40 新 bug（含熄屏→重启）」可能因果相关 | 决定 G1 基线是否可信；是「AI 难以稳固推进」的核心 | 静态取证：`archive/topics/AUDIT-since-vk34-2026-10-03.md`。**✅ 2026-10-03 实机确认**：`vk34recon` 睡眠正常、不重启，`vk40` 重启 ⇒ **回归源锁定在这 5 文件增量内**（与 10-03 持久化 rootfs 无关）。**第二遍（2026-10-03）**：逐 hunk 分类（N1 日志副作用 / N2 APM cmd header / N3 提前启动 graph / N4 残留 DBG）；建 V1(仅热区)/V2(仅音频) 二分镜像；实机取到**可量化回归**：`vk40re` 显示 on/off 后 `vblank timeout`=6、`PPM init failed`=1，`vk34recon` 同操作 =0/0。⚠️ 整机**静默硬复位是间歇性的**（~1 min/次 与 稳定 400 s 都出现）→ 单次观测无统计意义；V1/V2 尚未取到有效样本；per-boot kmsg 钩子有**副作用嫌疑**（装后 vk40re 变稳定），已回退。**第三遍（2026-10-03，`AUDIT3`）**：审计前序工具调用——**副作用从未写在轮询循环体内**（49 会话 132 条含副作用命令，0 条在 `do…done` 内）；真隐患是「reboot/`fastboot boot` 与长轮询同处一条命令、被 harness 超时杀死」（10 条中 4 条 `Command aborted`，副作用发没发不可判定）。**更关键的新混淆**：持久 `boot_b` 烧的就是 vk40 内核（kernel payload 与 `out/boot-elden-vk40.img` 逐字节同 =`d16ab35ce4a57afa`），而 vk30–vk40 共用 uname `…gba28ec16f01f-dirty`；串口捕获 16 min 内 8 次启动中 5 次是 vk40，每次仅活 20–40 s ⇒ **复位必回退到 vk40**，「复位次数/复位后行为」的跨版本比较被污染；但 vblank/PPM 的**版本归属仍可信**（per-uname kmsg 日志）。**下一步**：先把 `vk34recon` 烧进 `boot_b` 作已知基线（资产 `bootslot-b/boot_b-vk34recon.img` 已签好），再单变量长时窗重测。 | **G1-23**；`archive/topics/AUDIT-since-vk34-2026-10-03.md` §5、`AUDIT2-post-vk34-bisect-2026-10-03.md`、`AUDIT3-polling-sideeffects-2026-10-03.md` |
| **Q21** | **桌面空闲熄屏（DPMS blank）→ 整机重启**（2026-10-03 U2 实测；`idle-delay=10` 必触发）。重启前串口最后 3 行为 `ucsi_glink … timeout waiting for UCSI read response / failed to reset PPM / PPM init failed`，**无 kernel panic** | 直接阻塞持久系统的日常使用；且与 DP/altmode（G1-9）疑似同源 | 已做：串口日志 `logs/serial-20261003-192121.log`；复现 2 次。**待做**：① 先禁止空闲熄屏（`idle-delay=0`/caffeine）→ 看是否不再重启；② 抓 `dpms-watch.sh` 日志 + 必要时抓 ADSP/PDR 日志定位 UCSI PPM；③ 试在熄屏前 `echo 1 > /sys/class/drm/card0/card0-DSI-1/...` 逐步隔离 | **G1-22** |
| **Q23** | ~~Linux 侧 reboot→fastboot 的触发点~~ **已解决（2026-10-03 深夜）** | 已定 G1-24 路线 | **实测结论**：PMIC SDAM `reboot-reason@48`、`misc` BCB `bootonce-bootloader`/`boot-recovery` **均不被 ABL 采纳**；**PSCI SYSTEM_RESET2 vendor reset 被采纳**（`mode-bootloader=<0x80010001 0x2>`、`mode-edl=<0x80000000 0x1>`，无 recovery）。落地 = `elden/vk41-psci-reboot` 最小钩子（`psci.c`）；`reboot bootloader` → fastboot **实测成功**。EDL = TCSR DLOAD cookie（`qcom,dload-mode=<&tcsr 0x19000>`）未测 | **G1-24**；`archive/topics/FLASHCTL-2026-10-03.md` §7–§9 |
| **Q1** | **容器内的 GMS 身份/Play Integrity/Widevine 能做到哪一级**（不作废猜测，先取证） | 决定 G2 兼容上限与是否需要 VM/换路线 | 复现社区三条做法各一次，只变一个变量：① Waydroid + GApps（OpenGApps/MindTheGapps）；② 未认证设备注册流程（Android ID → `google.com/android/uncertified` → 清 GMS 缓存）；③ Widevine L3 库注入。记录 `getprop` 关键项 + `drminfo` + Play 状态。**社区侧已补证（2026-10-02）**：WayDroid-ATV 有 arm64 GAPPS 镜像（2026-01 SourceForge）但 **L3 仍仅 x86-64**（release notes 原文）；官方 licensing 页明确 GApps/Widevine 受许可限制、建议开源替代；PlayIntegrityFork(pif.json) 仍是主流过 PI 手段（v18 在手）；L1 需芯片商+GMS 认证（L3 是默认必测项，不需额外申请） | **C3** |
| Q2 | Waydroid 在 **vk40** 上是否不再需要旧 workaround（vk40 已开 iptables/NAT：`IP_NF_FILTER/NAT`、`NF_NAT_MASQ`、`XT_MATCH_COMMENT` ✅；`CONFIG_IP_ADVANCED_ROUTER` 仍 not set，若需策略路由再补） | 少一处 bind-mount 脆弱点 | 起容器看 `ip route` 是否自动有默认路由；不通再启用 workaround 并记因 | **C1** |
| Q3 | **droidloom**（Linux 原生跑 Android 应用，Wayland 直出窗口）在 arm64 宿主是否可用 | 形态优于容器（无需 Android 镜像） | **已查（2026-10-02）**：`denialwm/droidloom`（251★，Rust，活跃）repo 声称支持 arm64+x86_64 平台，但**预览包只发 x86_64 Arch**（pacman+ship.yml）；INSTALL 的 "experimental ARM64" 指 x86 宿主跑 ARM64 APK（Digitalis/Berberis 翻译层）；arm64 宿主 = 官方目标但无公开包。自构建一条命令 `cargo run --locked -p droidloom-package -- build`（需 rootless podman+AOSP pin，免宿主 sudo），产物 pacman 格式需适配本 rootfs。**剩两点未知**：① arm64 自构建是否干净；② freedreno+Phosh 下 GPU/输入路径 | 观察（R1 受阻再试） |
| Q4 | **无 KVM 前提下 VM 路线值不值得投**（**书面评估已完成 2026-10-02**，结论见 TASKS C8） | 决定要不要开第二条腿 | 结论：**维持低优先**。① 设备侧 KVM 不可达（XBL 在 secure-boot 链内加载 hyp，主线 `-el2.dtb` overlay 只适用 Qualcomm dev kit，ABL 重签救不了——hyp 加载点在 ABL 上一级）；② 独立 gunyah 驱动（v17）未进主线（本地 7.2 树 `drivers/virt/` 无 gunyah 目录）；③ 唯一新路线 = KVM-in-EL1+Gunyah backend（RFC 00/34，Linaro，2025-04，配 `qemu-for-gunyah`），WIP（pinned pages/无 guest_memfd/禁 swap）。**决定性上机实验**：vk40 起机后 `dmesg \| grep -i gunyah`（本地 qcom_scm 已带 gunyah UUID 探测）——通则路线第一步成立，败则归档 | **C8**（🟡 书面结论已出） |
| **Q5** | **真 Android 对照基线**（一旦覆盖 a 槽就不可复得）：GMS 属性 8 段、Widevine 级别、7 颗传感器读数曲线、目标 App 行为 | 兼容层的"标准答案"，也是判定容器是否等价的尺子 | 在 U1（当前仍 stock+root）一次采完：`getprop` 全量、`dumpsys media.drm`、传感器 30 s 采样 CSV、5 个目标 App 关键流程录屏 | **建议立刻插入（覆盖 a 槽前）** |
| Q6 | 兼容层验收的**量化判据**——**已定稿（2026-10-02，A15）**：10 条用例+阈值见 `TASKS.md §6` §5 | 避免"看起来能用"的自欺 | 上机后按用例表逐条实测打分（打分模板同处） | **C9**（模板就绪） |
| Q7 | Linux 分区到底要多大（**本轮已定"按项目体量决定"**） | 决定 GPT 手术一次给多少，避免二次缩容 | 按 `DEVICE.md` §3.1 估算表，上机后 `du` 实测各组成 → 回填表 → 定 `--linux-gib` | G1-2 前完成 |
| Q8 | 音频是否真的可听 + 有无录音通路（`GRAPH_START status=0` 只是控制面） | G1 硬验收 #4 | 上机 `amixer cset numid=8 on; speaker-test -c2`；录音需另找 ADC 通路 | G1-4 |
| Q9 | 相机能否真正出流（graph ENABLED ≠ 有帧） | G1 硬验收 #5 | `qcam`/`gst-launch-1.0 v4l2src` 取 10 帧存盘 | G1-5 |
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
| 相机出流 | config/部署 | 开 `CONFIG_V4L2_FLASH_LED_CLASS` 之类逐项补齐 + 部署 `.ko` | 🟡 到 graph 就绪 |
| 音频出声/录音 | tplg + 驱动时序 | 已修 BE graph 时序（`patches/0011`）；录音通路待查 | 🟡 Q8 |
| TF 卡 | 驱动 bug 或卡 | 换卡 A/B 定性后再决定补丁方向 | ⛔ Q10 |
| DP 输出 | bring-up（非缺驱动） | 修 `pmic_glink` UCSI/altmode | ⬜ Q11 |
| NFC | DT compatible 不匹配 | 改 compatible + config | ⬜ 低优先 |
| SLPI 7 传感器 | **架构性不可做** | 不救硬件，救接口（容器内虚拟传感器） | → `ANDROID-COMPAT` §2① |
| TEE/SPU/hw-fence/Gunyah/PMIH010x/BCL/FM/ST54 | 私有或无源码 | 明确不投入 | ✗ 结案 |

---

### 3. 环境与流程类待办（不属功能，但会咬人）

| 项 | 现象 | 处理 |
|---|---|---|
| 代理 `127.0.0.1:7897` 整体故障 | `web_search`/`web_fetch` 全灭（curl 35 TLS eof）；**直连反而可用** | 需你修代理；期间外部资料用 `curl --noproxy '*'` + GitHub API（本轮已如此取证） |
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
| ④ | GMS/商店/DRM 身份 | **按社区既有做法逐条复现并记录**：GApps 包（OpenGApps/MindTheGapps/MicroG 三选 + **WayDroid-ATV arm64 GAPPS 镜像** 2026-01 SourceForge）、未认证设备注册流程、Widevine L3 注入（**L3 仅 x86-64 有现成库**，arm64 待查）；每次只变一个变量 | **不预设"不可能"**；不做密钥伪造/绕过安全启动 |
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
