# 任务总纲 / 范围（MISSION & SCOPE）— TB322FC "elden" × SM8750(P)

> **本文件是项目总纲。** 与任何单话题文档、历史"路线决定"冲突时，**以本文件为准**；
> 被本文件覆盖的旧结论在 §8 逐条列出。入口仍是 `INDEX.md`。
> 制定：2026-10-02 21:2x（用户重述任务定位）。设备台账：`DEVICES.md`。

---

## 0. 一句话

**研究对象只有一台机器**：联想拯救者 Y700 四代 = **TB322FC** = 代号 **elden** = SoC **SM8750(P)**（骁龙 8 至尊版）。
**研究内容只有两样**：**固件** 与 **驱动**（含 DT、用户态 blob、协处理器固件）。
手里的多台同型号设备**物理地位完全等价**，**唯一差异是容量**（内存/UFS），"新机/旧机"只是到货顺序，**不构成角色**。
两个目的：

| | 目的 | 交付物 |
|---|---|---|
| **G1** | **跑功能健全的 Linux，正常驱动原厂全部固件** | 内核+DT+固件包 + **§3 验收矩阵**全绿 |
| **G2** | **设计一套方案，最大化兼容安卓** | `ANDROID-COMPAT-PLAN.md`（分层方案 + 收口设计 + 验收指标） |

---

## 1. 边界：做什么 / 不做什么

| 做（In scope） | 不做（Out of scope） |
|---|---|
| TB322FC/elden + SM8750P 这一组合的**固件逆向/提取/重签**与**驱动 bring-up** | 其它机型/其它 SoC 的移植（方法论可复用，但不立项） |
| 主线 Linux（`linux -> geekidos-linux`，7.2.0 + 补丁 0001–0011）在本机的**全外设驱动** | 通用发行版工程、包管理、桌面美化（够用即可） |
| **原厂固件**：ADSP/CDSP/SDSP、WCN7861(Peach) WiFi/BT、GPU gen80000 zap/sqe/gmu、触屏 NT36536 FW、触觉/功放 ACF、AudioReach tplg、ABL/XBL/dtbo 契约 | 闭源 TEE/QSEE 内部实现、TrustZone 攻击面、反作弊对抗（只在"过环境"层观察） |
| **安卓兼容层**：容器（Waydroid）/ 虚拟机（AVF-Gunyah）/ 双槽直启，三者并存比较 | 重造 Android ROM（类原生移植在兄弟项目 `~/y700类原生安卓/`，不并入本 repo） |
| GPT/双槽/A-B 直启等**让 Linux 成为一等公民启动路径**的存储层手术 | 解锁/bootloader/签名链本身的突破（BL 已解锁，不追求绕过） |
| 可复现资产：脚本化、参数化、**设备无关** | 手工一次性操作（必须落成 `scripts/`） |

---

## 2. ★ 设备等价原则（本次修订核心）

### 2.1 原则

1. **身份 = (序列号, hwboardid, UFS 容量)**，不是"新/旧"。台账在 `DEVICES.md`；任何文档/脚本/备份目录**以 SN 或容量命名**，不再用 `new-tablet` / `新机` 这类相对称谓（存量文档逐步替换）。
2. **物理等价** ⇒ 同一份 boot 镜像、同一内核、同一 rootfs 归档、同一 GPT 生成器、同一套验证脚本，对**任一**单元都成立。
   已核对的唯一实质差异 = **UFS 容量 → GPT 分区数值不同**（扇区 4096 B、分区表 LBA、`userdata` 大小、`backup_lba`）。
   ⇒ GPT 相关脚本一律**读实际 GPT 参数化**（`scripts/gpt-surgery-tb322fc.py`、`scripts/gpt-dump.sh` 已如此）。
3. **任务按"单元当前状态"分派，不按身份**。任一单元满足某任务的前置状态就可被派该任务；做完即可回收复用（见 §2.3）。
4. **禁止**：把某条轨/某类任务永久绑定到某台机器；把资产命名成"新机专用"；在文档里写"只有旧机能做 X"。
   唯一合法的绑定理由是**当前状态**（例：只有已 root 的单元能做 AVF 用户态实验——它一旦刷回 stock 就该换单元）。
5. **收敛目标形态统一**：每台单元最终都收敛到**同一套形态**，只差容量（见 §2.4）。差异不是设计，是进度。

### 2.2 容量差异的唯一体现（参数表）

| 参数 | 256 GB 档（U1，SN `HA2ABH62`） | 512 GB 档（U2，到货登记） |
|---|---|---|
| `hwboardid` | `TB322FC_SM8750P_12+256` | 预期 `TB322FC_SM8750P_16+512`（到货实测为准） |
| LUN0 实际容量 | 234 GiB（`/dev/sda`） | 约 476 GiB（待 dump 实测） |
| 扇区大小 | 4096 B | 4096 B（同） |
| `userdata`（原厂未手术） | 211.4 GiB | 约 470 GiB（待 `gpt-surgery… list`） |
| `backup_lba` | `61390847`（旧 dump 实测） | **必须现 dump**，不可沿用 |
| GPT 备份表取法 | LBA0..5 + `[backup_lba-4 .. backup_lba]` | 同法（`scripts/gpt-dump.sh`） |
| boot/dtbo/vbmeta 分区大小 | `boot` 100663296 / `dtbo` 33554432 / `vbmeta` 65536 | 同（同型号同布局，仅 LUN0 表不同） |
| 内存 | 12 GB（可用 10.6 GB） | 16 GB（预期） |

> ⚠️ **绝对不要**把 U1 的 GPT 二进制（`backup/gpt/gpt_*_device.bin`，234 GiB）写到 512 GB 单元上——历史已踩（`flashing-bundle/…/tb322fc-bootloop-gpt-mismatch.md`）。

### 2.3 按状态分派（取代"两轨分机"）

| 任务所需前置状态 | 该用哪台（此刻） | 说明 |
|---|---|---|
| mainline Linux（b 槽直启 + `linux17` 持久根） | **U2**（状态最接近：原厂未动，做手术不影响已有成果） | U1 也能做：需重做 GPT 手术 + 恢复 rootfs 归档（3.44 GB，已校验可无损恢复） |
| **stock Android + root**（AVF/Gunyah 用户态、`vm`/crosvm、过环境、EDL 对照） | **U1**（a 槽已 root：SUSFS 6.6.118 + KSU，`/data` 211 GiB） | U2 到货后若不 root 就不满足此状态 |
| 破坏性实验（GPT 手术、擦 `/data`、刷写压测） | 任一，**先备份 b 槽原厂分区 + GPT** 即可 | 回退路径见 `BRINGUP-UNIT` §8 |
| 需要"两个系统同时在场"的对比（Linux ↔ Android 切换、兼容层验收） | **任一单元**（目标形态本就两槽都在场） | 不再需要两台机各跑一个系统 |

### 2.4 每台单元的统一目标形态（唯一目标镜像）

```
a 槽 = stock Android 259（安全网 + G2 的 100% 兼容下限）
b 槽 = mainline Linux vk40+（自签 AVB，直启，开机 ~9s 进 Phosh）
GPT  = 原厂 16 分区 + 新增 linux17（容量按档位取，见下）
Linux 分区建议：256G 档 65 GiB ｜ 512G 档 128 GiB（剩余留 userdata）
共用资产：out/boot-elden-vkNN.img、bootslot-b/*.img、
         env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz、
         ~/mesa-out/mesa-vendor-26.1.8_waydroid_arm64_only.tar.gz
```
> 即：**两台是同一目标的两份实例**，可以随时互换角色、可以互为回退、可以并行做不同状态的实验。

---

## 3. G1 — 功能健全的 Linux：什么叫"功能健全"

8 条硬性验收（任一不满足即 G1 未完成）：

| # | 验收项 | 判据（在任一单元上） | 当前 |
|---|---|---|---|
| 1 | 冷启动到桌面 | b 槽直启，`findmnt /` = 持久根，≤ 15 s | ✅ ~5–9 s（U1 已验） |
| 2 | 显示 | 165 Hz preferred、无 DSI 报错、背光可调、熄屏/唤醒双向 | ✅（`PANEL-REFRESH`） |
| 3 | 图形 | `/dev/dri` + GLES/Vulkan（freedreno A830）+ Mesa ≥ 26.1.8 | ✅ |
| 4 | **音频出声** | `amixer cset numid=8 on; speaker-test` 可听 + 双功放 AW88461 + 录音？ | 🟡 **vk39 全 `GRAPH_START status=0`，待现场听声** |
| 5 | 相机 | `/dev/media0`+`video*`，S5KJNS/GC08A8 出流 | 🟡 graph 就绪，**未出流验证** |
| 6 | 无线 | WiFi(ath12k/Peach) 自动连 + BT 可配对 | ✅ WiFi（MHI 补丁）/ 🟡 BT 配对未收口 |
| 7 | 电源 | 旁路供电 + 输入电流限制 + 电量显示 + 温控分级 trips 生效 | ✅（`CHARGE`/`THERMAL`） |
| 8 | 存储扩展 | TF 卡稳定读写（`sdhci-msm`） | ⛔ 间歇写丢失未定性 |
| — | 触觉/触屏/USB-NCM+SSH/带外串口 | 已通 | ✅ |

### 3.1 固件侧清单（"正常驱动原厂全部固件"的分解）

| 固件 | 来源分区 | 本地资产 | 主线通路 | 状态 |
|---|---|---|---|---|
| ADSP（`adsp.mdt`+`adsp_dtb`） | LUN4 `modem_a` | `backup/fw/modem/` | `qcom_q6v5_pas` + `remoteproc`；**DT 期望 `/lib/firmware/qcom/sm8750/adsp.mdt`** | ✅ 起（音频/graph 已通） |
| AudioReach **tplg** | vendor（联想自研） | 自编 `Lenovo-Y700-Gen4-tplg.bin` | ASoC `q6apm` + `patches/0011` | 🟡 待听声 |
| CDSP (`cdsp.mbn`) | `modem_a` | `backup/fw/modem/` | DT `status=disabled` | ➖ 暂不启用（可作 G1 加分项） |
| WiFi WCN7861 "Peach"（`amss.bin`/`bdwlan`/BDF） | `modem_a/peach` | `backup/fw/modem/peach/` | `ath12k`（pci 17cb:110e） | ✅ |
| BT（`brhbtfw20.tlv`/`brhbtnv20.bin`） | `bluetooth_a` | `backup/fw/bluetooth/` | `hci_qca` + IBS 补丁 | ✅ 起，配对待收 |
| GPU gen80000 `zap/sqe/gmu/aqe` | vendor | `backup/fw/gen80000_*` | `msm` + freedreno | ✅ |
| 触屏 `novatek_ts_csot_3k_fw.bin` | vendor | `backup/fw/vendor/` | `nt36536` | ✅ |
| 触觉 AW86937 FW / 功放 ACF | vendor | 已改名喂入（`y700-gen4-speakers.bin`） | `aw86927` / `aw88461` | ✅ |
| SLPI/SSC **传感器固件 + QMI-SNS** | `modem_a` SLPI 区 | 仅 `.json` 配置 | **主线无 QMI-SNS 栈 + AP 无 I2C 通路** | ⛔ 架构性放弃（→ G2 用软传感器补） |
| Modem / SDSP / SPU / TEE / Gunyah hyp | 各自分区 | 有 blob | 主线无对应客户端 | ➖ 不立项（Gunyah 走 Android 侧，见 G2） |

### 3.2 驱动缺口分级（数字取自 `DRIVER-MAINLINE-AUDIT-2026-10-02.md`：529 compatible / 297 vendor `.ko` / 主线 SM8750 覆盖 146 compatible）

| 级别 | 项 | 性质 |
|---|---|---|
| **P0** | 相机出流（camss+s5kjns+gc08a8+wl2868c+flash） | 只差 config/部署 → G1#5 |
| **P1** | 音频可听 + 麦克风；TF 卡写稳定性 | tplg/驱动 bug → G1#4/#8 |
| **P1** | DP 输出（`mdss_dp0` + QMP DP PHY 在树，被 `disabled`） | 缺 ADSP altmode/UCSI，属 **bring-up** 非缺驱动 |
| **P2** | NFC（主线 `st21nfca` 在，改 compatible）、BT 配对收口 | 小 |
| **P3** | 温控 OEM 增强（`lenovo,sys-temp`/BCL/QMI cooling） | 主线主保护已够，可用通用框架近似 |
| **✗** | SLPI 7 颗传感器、TEE/SPU/hw-fence/mem-buf、FM RTC6226、ST54 SE | 架构性/无源码，**不投入** |

> **G1 的判据不是"100% 功能等同 Android"**，而是：**表内 P0–P2 全绿 + 8 条验收全绿**，
> 且 ✗ 类项有明确的"为什么不可做"证据（已有），并在 G2 里补齐传感器（见 `ANDROID-COMPAT-PLAN` §4）。

---

## 4. G2 — 最大化兼容安卓：一句话方案

**一套"两槽对称 + 容器优先 + VM 备选"的兼容层**，在任一单元上都成立：

- **S0 保底（100% 兼容）**：a 槽原厂 Android 259 直启 + `env-pass` 过环境栈 → 兼容上限即真 Android。
- **S1 日常（Linux 内的 Android）**：mainline + **Waydroid**（Mesa 26.1.8 已解 A830 chip-id、GAPPS 镜像、netd/路由已修）。
- **S2 备选（真 VM）**：Android 侧 **AVF/Gunyah**（`crosvm`/`vm`/microdroid **已从本机 ROM 离线提取**，无需下载）→ 跑 Debian/Android/Windows guest，宿主崩不影响 hyp/XBL。
- **S3 观察**：denial / droidloom（Linux 桌面原生跑 Android 应用，ARM64 未打包）。

分层设计、决策矩阵、缺口（传感器/DRM/Play Integrity/音频延迟）与工程任务分解 → **`ANDROID-COMPAT-PLAN.md`**。

---

## 5. 长期有效的 6 条决策原则

1. **设备无关优先**：任何产出先写成"对任一单元成立"，容量/布局参数运行时读实际值。
2. **不碰安全链**：不动 abl/XBL/hyp/GPT 之外的信任根；手术前必备份（`fastboot fetch` b 槽原厂三件套 + GPT 双表）。
3. **驱动优先主线**：主线有驱动就只补 DT/config/固件命名；主线没有就分"架构性不可做/私有/可自研"三类，只有第三类立项。
4. **固件只提取不重造**：一切 blob 从本机分区/EDL 包提取，命名按主线 DT 期望；不做跨机借固件。
5. **改动小样本冒烟 → 再全量**；worker 自报不可信，编排者**独立复跑**。
6. **文档即交付物**：每个结论落 `.md` + 可复现命令 + 回退命令；旧文档不删，标注被谁覆盖。

---

## 6. 立即行动（与设备到货无关，全部只动主机）

| ID | 任务 | 服务于 | 状态 |
|---|---|---|---|
| A1 | vk40 基线内核 + 1484 `.ko` + `config-vk40-bringup` | G1 | ✅ |
| A2/A3 | Waydroid Mesa 26.1.8 包 + GAPPS/MAINLINE 镜像 | G2-S1 | ✅ |
| A4 | bring-up runbook（通用化）+ `gpt-dump.sh` + b 槽签名包 | G1/G2 | ✅（本文件已改名通用） |
| A5 | rootfs 归档 3.44 GB（30852 项） | G1 | ✅ 可无损恢复 |
| A7 | `scripts/bench-run.sh` 基准 | G1 性能基线 | ✅ 待上机 |
| **A11** | Debian nocloud arm64 guest rootfs | G2-S2 | ⬜ |
| **A12** | guest 内核（`CONFIG_DMA_RESTRICT_POOL`） | G2-S2 | ⬜ |
| **A14** | **传感器注入方案原型**（IIO/uinput → Waydroid 虚拟 IMU） | G2（补 SLPI 缺口） | ⬜ 新增 |
| **A15** | 兼容层验收用例集（Play 登录/游戏帧率/视频通话/DP 外接） | G2 验收 | ⬜ 新增 |

---

## 7. 术语统一（写文档请照此）

| 旧写法 | 统一为 |
|---|---|
| 新机 / 旧机 / new-tablet | **单元 U1 / U2**（首次出现附 SN + 容量）；目录 `backup/<SN>-<容量档>/` |
| "两轨分机"、"X 轨只能在某机" | **按状态分派**（§2.3） |
| "接力主线" | "在处于 mainline 状态的单元上继续 G1" |
| D 轨 | **G2-S2（Android 侧 AVF/Gunyah 真 VM）** |

---

## 8. 被本文件覆盖的旧结论（不删原文，就地失效）

| 文档 | 被覆盖内容 | 现状 |
|---|---|---|
| `ROUTE-DECISION-2026-10-02.md` §2/§3/§7 | **"两轨分机"：新机=mainline、旧机=D 轨** | 作废 → 改为 §2.3 按状态分派；D 轨更名 G2-S2（该文件已加 v2 修订说明） |
| `BRINGUP-UNIT-2026-10-02.md`（**已从 `BRINGUP-NEW-TABLET-2026-10-02.md` 改名**）标题与目标 | "新机接力、旧机留 Android" | 已改写为 **通用单元 bring-up runbook（设备无关 · 容量参数化 `$SN/$CAP/$BLK/$BACKUP_LBA/$LINUX_GIB/$BAK`）**；步骤不变 |
| `PLAN-NODEV-2026-10-02.md` §4.1 | "新平板角色 = 接力主线" | 作废（同上）；文内已改 v2 |
| `ARM-VIRT-RESEARCH-2026-10-02.md` §9.4/§9.6 | D 轨绑定旧机 | 作废绑定，技术结论保留 |
| `INDEX.md` §0「下一步」 | 以"新平板到货接力"为轴 | 已改为以 **G1 验收矩阵 + G2 方案** 为轴（见 §M） |
