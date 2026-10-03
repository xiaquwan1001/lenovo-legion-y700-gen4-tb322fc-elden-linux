# 任务拆解与进度（TASKS）

> 六视角文档集之一（`DEVICE.md` 设备 / `RESOURCES.md` 资源 / `GAPS.md` 查漏 / `ANDROID-COMPAT.md` 兼容方案 / `INDEX.md` 入口）。
> **本文件是唯一任务台账**：所有 ID、状态、下一步只在这里维护；专题文档只放过程与证据。
> 纪律：worker 只报「命令 + 原始日志」，编排者**独立复跑**；每步留回退；设备锁串行、主机侧并行。

---

## 0. 进度总览（数字）

| 目标 | 已完成 | 进行中 | 未开始 | 完成度 |
|---|---|---|---|---|
| **G1** 健全 Linux + 驱动原厂固件 | 21 项（显示/图形/触屏/网络/电源/相机驱动栈/音频 APM 图/温控/串口/基准脚本…） | 4（音频听声、相机出流、TF 卡、BT 配对） | 3（DP、NFC、CDSP） | **~80%** |
| **G2** 无安卓前提下的安卓兼容 | 6（Waydroid 图形/内核/GAPPS 镜像/代理通路/Win-x86 PoC/**C9 用例集**） | 4（Play 登录收口、切槽脚本、C8 上机探测、**C4 部署验证**——代码/编译全就绪） | 4（相机共享、音频容器、C3 实测…） | **~45%** |
| 运维/资产 | 内核 vk40、rootfs 归档、Mesa 包、文档集重构、`qemu-utils` 已装（A13）、fstab nofail 已修（A18）、**C4 传感器链（A14）**、**env-pass provision（A17）** | — | — | ✅ |

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
| **G1-4** | **音频可听**（vk39 已 `GRAPH_START status=0`） | 🟡 待现场听声 | 任一 mainline | `amixer cset numid=8 on; speaker-test` 可听；双 AW88461；录音频测 | `archive/topics/AUDIO-2026-10-02.md`、`patches/0011` |
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

> 路线定义见 `ANDROID-COMPAT.md`。ID 前缀 `C`（compat）。

| ID | 任务 | 状态 | 层 | 验收 | 备注 |
|---|---|---|---|---|---|
| **C0** | **真 Android 对照取证**（趁 U1 还是 stock+root，**覆盖 a 槽前必做，不可复得**） | ⬜ **建议立刻插入** | 基线 | `getprop` 全量、`dumpsys media.drm` 级别、7 颗传感器 30 s 采样 CSV、5 个目标 App 关键流程录屏 | 兼容层的“标准答案”；见 `GAPS.md` Q5 |
| **C1** | Waydroid 在 vk40 端到端复跑（去掉旧的 bind-mount 路由 workaround） | ⬜ 下一步 | 容器 | `waydroid status` 有 IP、SurfaceFlinger running、桌面可点 | Mesa 26.1.8 + GAPPS 镜像在手 |
| C2 | Play / GMS 登录收口（旧结论：卡在外部上行与代理） | ⬜ 需你给上行+凭据 | 容器 | Play Store 登录成功 + 装 3 个目标 App | `archive/topics/PROXY-WAYDROID-2026-10-02.md` |
| C3 | **身份兼容性取证**（GMS/Play Integrity/Widevine 能做到哪一级）——**不预设结论** | 🟡 社区侧取证已补全（2026-10-02，见 `RESOURCES.md` §1.3） | 容器 | 出「社区先例 × 本机实测」对照表 + 回填 `ANDROID-COMPAT.md` §1 的 C2 格 | 先例：redroid / waydroid_script `certified` / WayDroid-ATV（arm64 GAPPS 有、L3 仅 x86-64） / PlayIntegrityFork；**实测需设备+上行** |
| **C4** | **传感器注入原型**（~~uinput + UDP~~ **作废**→ **UDP HAL 真实现**：waydroid-build 树 Sensors.cpp 已编译，宿主侧 sensord 已冒烟） | 🟡 主机侧代码+编译全就绪，待上机部署验证（GAPS Q14） | HAL | `dumpsys sensorservice` 列出 5 个 elden 传感器；地图自动旋转有读数 | 前提修正+证据：`archive/topics/SENSORS-WAYDROID-STUB-2026-10-03.md`；部署：`scripts/deploy-sensors-hal.sh`（overlay 方式） |
| C5 | 相机共享（`v4l2loopback` + sampler → 容器） | ⬜ 待 G1-5 | 容器 | 容器内相机出预览 | — |
| C6 | 音频通路打通后的容器音频（PipeWire） | ⬜ 待 G1-4 | 容器 | 容器内播放有声、延迟 <100 ms | — |
| C7 | `scripts/slot-switch.sh` 一键切槽 + 槽属性自检 | ⬜ 低工作量 | 双槽保险 | 两条命令完成往返切换 | 即便 a 槽可弃，也要保留回退手段 |
| C8 | **无 Android 的 VM 路线调研**（Gunyah guest on mainline / crosvm+`--parallel_vcpus`；KVM 已确认不可行） | 🟡 **书面结论已出（2026-10-02）**：维持低优先不立项——① 设备侧 KVM 不可达（XBL 锁 hyp，`-el2.dtb` overlay 只适用 dev kit）；② 独立 gunyah 驱动未进主线（本地 7.2 树无 `drivers/virt/gunyah`）；③ 唯一新路线=KVM-in-EL1+Gunyah backend（RFC 00/34，Linaro，配 `qemu-for-gunyah`，WIP） | VM | 上机后跑一次 Gunyah UUID 探测（`dmesg \| grep -i gunyah`，本地 qcom_scm 已带探测逻辑），据结果归档或续立项 | `archive/topics/EL2-VIRT-2026-10-02.md`、`RESOURCES.md` §1.5 |
| C9 | 兼容层验收用例集 `GAPS.md` §Q6 打分表 | ⬜ 新增 | 全部 | 5 维打分表出数 | — |
| ✅ C-历史 | Waydroid 容器打通、Mesa 26.1.8 解 A830 chip-id、GAPPS 镜像安装、容器代理通路、**Win-x86（Box64 0.4.5+Wine 9）PoC** | **已完成** | — | 见 `archive/topics/WIN-X86-POC-2026-10-02.md` | — |

### 2.1 主机侧并行任务（不占设备，随时可做）

| ID | 内容 | 状态 |
|---|---|---|
| A11 | Debian/Alpine arm64 guest rootfs（VM 路线用） | ⬜ |
| A12 | guest 内核（`CONFIG_DMA_RESTRICT_POOL`，microdroid_defconfig 思路） | ⬜ |
| A13 | `sudo apt install qemu-utils` | ✅ 已装（`qemu-img`/`qemu-nbd` 实测在位，2026-10-02 核验） |
| A14 | 传感器注入代码 | ✅ **已完成（2026-10-03，前提修正后重定义）**：HAL 真实现（waydroid-build 树 Sensors.cpp，编译成功）+ 宿主侧 `scripts/eldroid-sensord.c`（selftest 7/7 + UDP 环回冒烟）+ `scripts/deploy-sensors-hal.sh`（overlay 部署）+ `env-pass/scripts/sensor-send-termux.sh`（真值转发） |
| A15 | C9 用例表 + 打分模板 | ✅ 已定稿 → `ANDROID-COMPAT.md` §5（2026-10-02，10 条用例+阈值） |
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
| 「两轨分机」路线决定 | 作废（设备等价）；技术结论并入 `DEVICE.md` §1.2/`ANDROID-COMPAT.md` |
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
