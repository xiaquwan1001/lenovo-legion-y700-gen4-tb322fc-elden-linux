# 归因复核：内核/驱动 vs DTS vs initramfs/rootfs vs 用户态（2026-10-06）

> 证据层 · 只增不改。承接 2026-10-06 目标重心上移：**按新目标复核现有任务规划的因果归因**。
> 动因：项目多次把 **initramfs/rootfs 打包**或**用户态配置**问题记成「驱动/内核」问题，导致修错方向、误判 G1 进度。
> 权威条目 = `PITFALLS` #115；现状以 `TASKS.md` §1 为准。

## 0. 分层定义（归因前先分类）

| 层 | 含义 | 典型症状 |
|---|---|---|
| **A 内核/驱动代码** | C 驱动逻辑、DT 绑定、**DTS/DTB** | 节点不 probe、格式协商错、路由缺失 |
| **B 固件/资源文件** | vendor `.mbn/.bin` 命名与安装路径 | `firmware load failed`、remoteproc 不 running |
| **C initramfs/rootfs 打包** | 根/模块/固件在**启动那一刻**是否可见、模块是否同构建、cmdline/ramdisk 形态 | 早期探测失败、vermagic 不匹配、停在 initramfs |
| **D 用户态服务/配置** | elogind/phosh/PipeWire/UCM/media-ctl/dconf | 逻辑已通但行为不对 |
| **E 工具/流程** | 构建脚本、串口通道、轮询 | 观测不到、误判 |

## 1. 复核结论（按受影响任务）

| 任务/事件 | 旧口径（可能误导） | **正确层** | 证据 |
|---|---|---|---|
| **vk60 slim「驱动全废」** | 记为驱动/内核问题（G1 缺口） | **C** initramfs 缺 `/lib/firmware`（本机 40 M），built-in 驱动 1–3 s 探测 `-2` 且不重试；switch_root 后自愈 | `PITFALLS` #113、`DRIVER-VERIFY-2026-10-06.md` §5、`BOOTSLIM-2026-10-05.md` |
| **min initramfs 期 `firmware load failed -2` 刷屏** | 误读为 awinic/novatek/ath12k 驱动故障 | **C**（同上；非驱动 bug，`switch_root` 后恢复） | `DRIVER-VERIFY` §5、`INIT-HARDEN-2026-10-06.md` |
| **「没进桌面」** | 记为内核（vk46）故障 | **C** 刷了 `-ram` 变体，cmdline 无 `elden_root` → 停 initramfs | `PITFALLS` #92 |
| **模块无法加载 / vermagic 不匹配** | 记为驱动问题 | **C** 内核↔模块/rootfs 部署对齐 | `PITFALLS` #99–#101、`KMOD-ALIGN` |
| **kexec `-e` 失败** | 归「arm64 syscall 限制 / 死挂」 | **C+E**：真 bug 之一 = slim initramfs 缺 `/bin/sh`（#107）；分支点**未定位**（无存活 console） | `KEXEC-ONDEVICE-R2`、`PITFALLS` #5/#107 |
| **vk53/vk54 整机启动失败** | 「驱动批次未上机」含糊 | **A（DTS/DTB）**：内核 config 已排除，vk47 DTB 一换即过 | `DRIVER-VERIFY` §3、`PITFALLS` #108 |
| **Q24 熄屏→关机** | 记为内核/驱动（vk40 音频插桩 / `-dirty`） | **未证实**；待裁决 = 内核 DSI blank **vs 用户态**（elogind/phosh/UPower）电源路径 ⇒ 不应记作驱动根因 | `TASKS` Q24、`PITFALLS` #102 |
| **BT vk61 后「无法连接」消失** | — | **C/D**（RAM init 变化）候选，机制未证，非驱动 | `TASKS` G1-7 |
| **音频曾不可听** | 「codec 驱动」 | **A/B**：真根因 = tplg MI2S **SD 线错**（供应商固件/配置），非 codec 驱动逻辑 | `PITFALLS` #90 |
| **相机 `-32`** | 「驱动/供电/时钟」 | **D**：csiphy/vfe 默认格式与 sensor raw 不匹配 + 链路未使能，`media-ctl` 配置即解 | `TASKS` G1-5 |

## 2. 对任务规划的影响

1. **G1-30 应从「驱动缺口」改归「initramfs 打包」**：其结论（slim 不作日常启动）不变，但原因层要写对，否则会去改驱动。
2. **G1 进度百分比不应因 vk60/vk61 的 initramfs 问题加减**：驱动本身在 vk47clean 已可用（#113/#114）。
3. **Q24 不是驱动项**：应挂在「用户态/电源」或「显示内核路径」的未裁决项下，隔离实验 = 纯 DRM vs phosh/UPower。
4. **kexec**：既有 initramfs bug 已修；残余属「内核 kexec 路径 + 无存活 console」，非驱动。

## 3. 推行的归因纪律（已写入 `PITFALLS` #115）

- 报「XX 驱动坏」前，先问：**故障发生时，根/固件/模块可见吗？cmdline 是哪种变体？模块与内核同构建吗？**
- 报「内核 bug」前，先排除**用户态服务/配置**（D）与**打包/部署**（C）。
- 报「固件/资源缺失」时区分 **B（文件命名/路径）** 与 **C（时刻不可见/未打包）**。

---

## 4. 更正（2026-10-06 用户设备侧，追加不删旧文）★

§1 表中「**vk53/vk54 整机启动失败 → 正确层 = A（DTS/DTB）**」一行**作废**。

- 用户更正：当时是**坏 init**（`PITFALLS` #107/#110）+ **用户态服务干扰**（#106），不是 DTS。
- 正确层 = **C（initramfs/打包）+ D（用户态服务）**；A（DTS）**未获证据**。
- ⇒ vk53/vk54 驱动项（DP/NFC/CDSP）回落「未上机验证」，须用 vk61 载具重测。
- 权威：`TASKS.md` §0/§1/§4、`PITFALLS` #108（⛔superseded）、`DRIVER-VERIFY-2026-10-06.md` §7 追加。

---

## 5. 再更正（2026-10-06，单变量定案）★

§4 把 vk53/vk54 归到「C（initramfs）+D（用户态）」**仍不准确**。

单变量二分（vk61 full 载具 + vk53 kernel）定案：根因 = **使能 `&i2c0`**（`&i2c0 { status="okay"; }` 单独即可硬关机），**正确层 = A（DTS，QUP/总线使能）**——但是 DTS 里「**本板不存在的设备**」被点亮所致，**不是** NFC 驱动/GPIO。

并且 **TB322FC 本机无 NFC 硬件**（vendor 无 nfc feature XML / 无 vintf NFC HAL / 无 NFC HAL 库 / 无固件；stock 无 NFC 服务；GSMArena NFC:No）⇒ G1-10 取消。

修正 §1 表：vk53/vk54 → **A（DTS：使能了不存在的 i2c0）**，非 C/D。权威 `PITFALLS` #108。
