# G2 方案设计 — 最大化兼容安卓（elden / TB322FC / SM8750P）

> 总纲：`MISSION-SCOPE.md` §4。本文是 **G2 的唯一收口设计**，把散在
> `WAYDROID-2026-10-01.md` / `WAYDROID-AOSP-AUDIT` / `GPLAY-2026-10-02.md` / `PROXY-WAYDROID-2026-10-02.md` /
> `ENV-PASS-2026-10-02.md` / `EL2-VIRT-2026-10-02.md` / `ARM-VIRT-RESEARCH-2026-10-02.md` / `DRIVER-MAINLINE-AUDIT` 里的结论
> 合成**一套可实施分层方案**。设备无关：**任一单元（`DEVICES.md`）都成立**。
> 撰写 2026-10-02。

---

## 0. 结论先行

**一句话：不做单选题，做「两槽对称 + 容器优先 + VM 备选」的四层并存栈，用一次切槽/一次会话启动覆盖 0%→100% 的兼容面。**

| 层 | 形态 | 兼容度 | 冷切换代价 | 本地现成度 | 立项 |
|---|---|---|---|---|---|
| **S0** | a 槽 **原厂 Android 259 直启** + 过环境栈 | **100%（真 Android）** | 切槽重启 ~25 s | ✅ 已在 U1（含 KSU/SUSFS/ZN/Shamiko/PIF，Native Detector = normal） | ✅ 保底 |
| **S1** | mainline + **Waydroid 容器**（Android 16 GAPPS） | 高（除 DRM L1 / 部分传感器 / 强检测应用） | 会话启动 ~10 s，**不离开 Linux** | ✅ Mesa 26.1.8 已解 A830 chip-id、GAPPS 镜像在手、netd/路由已修 | ✅ **主力** |
| **S2** | Android 侧 **AVF / Gunyah 真 VM**（`vm`/crosvm → Debian / Android / WinARM guest） | 中高（guest 内是真 Android/Debian；图形未验证） | VM 启动 ~10 s；需宿主在 Android | ✅ **底层资产已从本机 ROM 离线提取**（`crosvm`+Gunyah、`vm`、microdroid 6.6.77、u-boot） | ✅ 备选 |
| **S3** | **denial / droidloom**（Linux 桌面原生 Android 应用窗口） | 中（形态最优） | — | ⛔ ARM64 未打包、SM8750 无验证 | 👁 只观察 |

**为什么不单选**：G1 要求"Linux 是主力"，而"最大化兼容安卓"的最高分只能来自真 Android。
两槽对称（a=Android、b=mainline）让二者**互不牺牲**；S1 负责"日常在 Linux 里用 Android 应用"，S2 负责"需要另一个完整系统但不想重启"。

---

## 1. 先把"最大化兼容安卓"拆成可测的 5 个维度

| 维度 | 定义 | S0 | S1 | S2 | S3 |
|---|---|---|---|---|---|
| **C1 功能兼容** | 目标 App 能装能跑（含厂商 App、游戏、微信/钉钉类） | 5 | 4 | 4 | 3 |
| **C2 身份兼容** | GMS 认证、Play Integrity(CTS/PlayGuard)、Widevine L1、DRM 视频 | 5(L1/认证原厂) | 3（非认证设备；L3 软解） | 3–5（取决于 guest 镜像） | 3 |
| **C3 性能** | GPU 直通/帧率/内存开销 | 5 | 4（freedreno 直驱，已 830 可用） | 2–4（virtio_gpu/VirGL 是**最不确定项**） | 4 |
| **C4 系统集成** | 窗口化/多任务、输入、**传感器**、音频延迟、相机、剪贴板/文件共享、通知 | 5 | 3（**传感器与相机是主要短板**，见 §4） | 2 | 4 |
| **C5 可逆与风险** | 失败是否可回退、是否触碰信任根 | 5（槽回退） | 5（容器可删） | 4（guest 崩不伤宿主/hyp） | 5 |

> **C2/C4 是主战場**：C1/C3 已被 S0/S1 覆盖；G2 的工程价值集中在 §4 的补偿设计。

---

## 2. 四条路线的关键事实（一次性正反判断，不再重复论证）

### S0 · 两槽对称直启（保底，已被实践验证）
- 事实：b 槽自签 mainline 直启 + a 槽原厂 Android **已共存过**（`linux17` 65 GiB 时期，两槽互不干扰）。
- 过环境（`ENV-PASS-2026-10-02.md`）：ZN + Shamiko + PIF + TrickyStore + `envpass_props` + 卸载 KSU 管理器 → **Native Detector = normal**；`verifiedbootstate=green`。
- 坑：xz 压缩的模块 zip 要重打 deflate；Shamiko 1.2.5 的 KSU 版本校验对 KSU 3.x 误判需绕过。
- 限制：**切换要重启**；Linux 侧长任务会被打断（这是 S1 存在的理由）。

### S1 · Waydroid 容器（主力）
- 已通：LXC + 内核 netfilter（vk27→vk40 已含 `XFRM_USER`/`IP6_NF_FILTER`）+ **自编 Mesa 26.1.8 解 SurfaceFlinger `output buffer not gpu writeable`（A830 chip-id）**；GAPPS 镜像已 `waydroid init -f -s GAPPS`（30 个 Google 包）；容器代理通路打通（容器 curl Google=200、GSF checkin 1530 行、Play Store 到 Sign in）。
- 已定位未收口：登录卡在**上行网络 + 代理**（非软件问题）；`CONFIG_IP_ADVANCED_ROUTER` 缺 → 用 bind-mount `blank_screen.rc` 补默认路由（**vk40 已在内核侧解决**，上机可去掉 workaround）。
- 待补：传感器（§4.1）、相机共享（§4.3）、音频延迟（§4.4）、多窗口/大屏（phoc 已有 freeform）。

### S2 · Android 侧 AVF/Gunyah 真 VM（备选）
- 硬约束：本机 **EL2 被签名 Gunyah 占死**，mainline 拿不到 KVM（`EL2-VIRT`）→ **主线侧自建 VM 路线放弃**。
- 但 Android 侧 `/dev/gunyah` 现成，且 **DroidVM 官方推荐 SoC 正是 SM8750**；**AVF 全套已从本机 ROM 离线提取**，无需外部下载：
  `com.android.virt.apex` → `bin/crosvm`(10.7 MB，strings 出 `hypervisor/src/gunyah/*`)、`bin/vm`(1.2 MB)、`microdroid_kernel`(6.6.77)+initrd、`u-boot.bin`。
- 8 Elite 红利：支持 `--protected-vm-without-firmware`，免按 pvmfw 给 guest 内核签名。
- 已知坑：`ulimit -l unlimited`（Android 默认 64 kB）、guest 内核需 `CONFIG_DMA_RESTRICT_POOL`、RM 拒绝 → "Prepare Lend mTHP"、**图形加速是最不确定项**。
- 前置：**宿主需 root 的 Android** ⇒ 此刻只有 U1 满足（状态性绑定，见 `MISSION-SCOPE.md` §2.3）。

### S3 · denial / droidloom（观察）
形态最贴"Linux 桌面里开 Android 应用"，但 ARM64 未打包、无 SM8750 案例 → 只跟踪上游，不立项。

---

## 3. 收口设计：`elden-droid` 兼容层（本文的核心交付）

> 目标：**同一份 Linux 镜像 + 同一份 Android 资产**，在任一单元上一条命令进入所需兼容层，并能一键回退。

```
                    ┌──────────────────────────────────────────┐
   Phosh / Wayland  │  eldroid-cli  (waydroid / vm / slot 统一入口)│
                    └───┬───────────────┬───────────────┬───────┘
                        │               │               │
              S1 waydroid-session   S2 vm/crosvm    S0 slot-switch
                        │               │               │
   ┌────────────────────▼───┐   ┌───────▼────────┐  ┌───▼──────────────┐
   │ eldroid-bridge (新写)  │   │ Android 宿主侧  │  │ a 槽 stock 259    │
   │  · 传感器注入 uinput→容器│   │ /dev/gunyah     │  │  + env-pass 栈    │
   │  · 相机共享 (v4l2loopback)│  │ /apex/.../vm    │  │  （100% 兼容下限）│
   │  · 音频 PipeWire→容器   │   │ qcow2/raw guest │  └──────────────────┘
   │  · 文件/剪贴板共享      │   └────────────────┘
   │  · 网络/代理 (已通)     │        ▲ 资产：crosvm/vm/microdroid（ROM 自有）
   └────────────────────────┘        ▲       + Debian nocloud rootfs(A11) + guest 内核(A12)
        ▲ 依赖：内核 vk40(netd/XFRM) + Mesa 26.1.8 + GAPPS 镜像
```

## 4. 关键缺口的补偿设计（兼容层真正要写的东西）

> 下图的 `eldroid-bridge` 具体要做四件事：传感器（4.1）、身份（4.2）、相机（4.3）、音频（4.4）；输入/窗口见 4.5。

### 4.1 ★ 传感器（G1 放弃的 SLPI 7 颗，在 G2 里必须补上）
SLPI 传感器核不可落地 ⇒ **不救硬件，救接口**。方案：**主机侧（Linux）合成虚拟传感器，喂给 Android 侧**。

| 环 | 做法 | 代价 | 备注 |
|---|---|---|---|
| 数据源 | ① `uinput` 造 `accelerometer`/`gyro`/`magnetometer` 等虚拟设备；② **真值来源（首选）= 同型号另一台单元跑 a 槽 Android**：一个小 daemon 读 SLPI 传感器（Android 下本来就工作）→ UDP 推给 mainline 单元——**设备等价原则的直接红利**：任一台可当另一台的“传感器外置”；③ 兼容备选：局域网内其他 Android 手机；④ 兵蓝：纯软件（恒定重力 / 脚本轨迹 / 鼠标姿态） | 小 | 零硬件成本，纯用户态 |
| 注入容器 | Waydroid 侧用 `init.rc` 起一个 `sensord`，把 UDP → `/dev/input/event*` 或 Android `HAL`（`android.hardware.sensors@2.x` 的 shim，最简：写一个 `hardware/…/sensor-shim` 直报） | 中 | 先做 **input/evdev 层**（覆盖大量游戏），不够再上 HAL |
| Android 宿主（S2 guest） | guest 内跑同一 sensord | 小 | — |
| 验收 | 地图自动旋转、赛车游戏陀螺、“水平仪”类 App 有读数 | — | 记入 §6 **T3** |

### 4.2 身份兼容（Play Integrity / DRM）
- 现成：`env-pass` 的 resetprop 属性伪装（boot/verity/指纹 8 段）+ TrickyStore + PIF → 在**真 Android** 侧已判 normal。
- Waydroid 侧：GAPPS 镜像 + `waydroid_prop` 注入同等 prop；**预期只能到 `BASIC`（CTS）而非 `DEVICE`**（无密钥）→ 明确写进验收：**关键应用能用 Play 下载即可，不追 L1/`DEVICE`**。
- Widevine：容器内为 **L3 软件级**（可播 720p/1080p 软解），L1 需原厂 TZ ⇒ **归 S0**。

### 4.3 相机共享
mainline 侧 camss 已就绪（S5KJNS/GC08A8，`/dev/media0`+`video*`）→ **`v4l2loopback` + `camera-sampler` 把 `/dev/video*` 转发进容器**，替代 Android 私有 `camera-provider`。验收：容器内相机 App 出预览/视频通话对端可见。

### 4.4 音频
容器 → PipeWire（host）→ AudioReach（vk39/0011 修好后可出声）→ 扬声器。延迟目标 <100 ms（非游戏）；游戏音频走 PipeWire 默认 quantum。前置：**G1#4 音频先落地**。

### 4.5 输入与窗口
触屏/键盘/鼠标已由主线输入子系统透传；马达触觉走 `aw86927`（evdev `ff-status`）→ 容器 `vibrator` HAL shim；窗口用 phoc freeform（S1 独有优势）。

---

## 5. 决策原则（G2 专用）

1. **能容器不 VM，能 VM 不重启**：S1 优先，S2 只在"需要另一个完整系统且不想切槽"时用，S0 是兜底。
2. **不追认证**：不试图伪造 Play `DEVICE` 级 / Widevine L1（无密钥、成本无限）；需要它们的场景归 S0。
3. **救接口不救硬件**：SLPI 类缺失一律走合成注入（§4.1），不投入 QMI-SNS 移植。
4. **兼容层必须设备无关**：任何脚本读 `/proc/device-tree/compatible` + 实际 GPT，不写 SN。
5. **每层都可独立卸载**：删容器 / 删 guest 镜像 / 切回 a 槽，均不留残余。

---

## 6. 任务分解（并入 swarm 任务制，取代旧 "D 轨 task-14…17"）

| ID | 任务 | 设备状态要求 | 层 | 验收 | 风险 |
|---|---|---|---|---|---|
| **T1** | Waydroid 在 **vk40** 上端到端复跑（去 workaround：路由/`XFRM` 已由内核提供） | mainline | S1 | `waydroid status` IP 正常、SurfaceFlinger running、桌面可点 | 零 |
| **T2** | Play 登录收口（需你恢复上行 + 代理 + 凭据） | mainline | S1 | Play Store 登录成功、装 3 个目标 App | 零 |
| **T3** | **传感器注入原型**（`uinput` + UDP sensord，evdev 层；真值源优先用另一台单元的 a 槽 Android） | mainline（主机侧可先写） | S1 | 地图自动旋转 / 赛车陀螺有反应 | 零 |
| **T4** | 相机共享（`v4l2loopback` + sampler → 容器） | mainline（G1 相机出流后） | S1 | 容器内相机出预览 | 低 |
| **T5** | **AVF 只读勘察 + 最小 VM**（`/dev/gunyah`、`vm list`、microdroid headless） | stock Android **root** | S2 | `vm console` 进 guest shell | 零（用户态） |
| **T6** | Debian guest（A11 rootfs + A12 内核 `DMA_RESTRICT_POOL`）→ DroidVM APK 实测 | stock Android root | S2 | guest SSH 可达；图形能力**如实记录** | 低 |
| **T7** | `scripts/slot-switch.sh`（一键切槽 + 槽位属性自检 `slot-attr.py` + 切换后自检） | 任一 | S0 | 两条命令完成往返切换 | 低 |
| **T8** | 兼容层验收用例集 `ANDROID-COMPAT-CASES`（T1–T6 的分数记录表） | 任一 | 全部 | 出 5 维打分表（§1） | 零 |

> 主机侧现在就能做（不碰设备）：**A11 Debian rootfs、A12 guest 内核、T3 sensord 代码、T7 脚本、T8 用例表**。

---

## 7. 待你拍板（G2 只剩 2 条）

1. **Play `DEVICE` 级认证与 Widevine L1 明确放弃**（需要它们的场景走 S0 重启）——认可？
2. **S2 图形（virtio_gpu/VirGL）若实测不通**：接受"无头/软件渲染 VM"结论并停止投入（不与 EL2 独占死磕）——认可？
