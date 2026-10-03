# Y700 四代 (TB322FC) ROM/镜像生态全景

2026-08 调研。五条线：官方原厂 / GSI / 移植 ROM / 工具链 / 开发中。决策刷哪个前先看本清单。

## ① 官方原厂线（ZUX OS）
| 版本 | 说明 | 状态 |
|---|---|---|
| 043 出厂版 | 性能调度最激进，"出厂版=性能巅峰"共识 | 有降级教程（B站"送就到家"） |
| 1.1 终版（073/076） | 甜点位；073 本地已备 `~/下载/刷机-四代/firmware/TB322FC_073/` | ✅ 本机当前版本 |
| 096 版本 | 线刷版，附带 7 种免解锁 Root 方案 | 悲伤的压缩包发布 |
| 1.5 系（Android 16） | 1.5.04.366 稳定推送 / 1.5.10.259 线刷 / C16 16.0.3.502（免解锁镜像工具） | 口碑负优化（性能保守/三角洲糊/删小白条/野兽模式降频），不升；解锁通道可能被堵（ROM基地警告） |

## ② GSI 线
- **LineageOS 23.2 GSI（tdgsi_arm64_ab 23.2-20260603-UNOFFICIAL）** = 本机已获取（TrebleDroid 构建线，Android 16，指纹 BP4A.251205.006，KMI android15-6.6）。实测：能跑；QQ/TIM 不认平板（characteristics=device+telephony）、相机 fishfood 空壳（已 disable）；修复流程见本技能 SKILL.md 与 y700-tb322fc-gsi.md。
- **MisterZtr LineageOS GSI**（native A16 QPR2，无 TrebleDroid 补丁）：要求真 vendor ≥ Android 13 + 内核 5.10+（四代 6.6 满足）。SourceForge `misterztr-gsi/files/LineageOS/Android 16(native)` + GitHub MisterZtr/LineageOS_gsi releases。**有 microG 内置版**（XDA 4769976，实测蓝牙/相机/LTE 正常）。
- **Google 官方 A16 GSI**：developer.android.com/about/versions/16/gsi-release-notes，纯 AOSP 验证用途。
- **phh/TrebleDroid 生态其他 GSI**（PixelOS/crDroid/EvolutionX 等）：理论可刷，SM8750 兼容性需逐个实测。

## ③ 移植 ROM 线（国内玩机圈最活跃）
- **澎湃OS 3.0.307.0**（HyperOS 3）：最新 2026-08-02，作者 **GUF296**，含刷机包+免解锁镜像（6 种面具自选）。抖音有"不解锁 BL 直接刷入澎湃OS3 开机"实例。
- **ColorOS 16（一加 Pad 2 Pro 金标系统）**：GUF296 移植；**免解锁刷入不损坏 tee**；三角洲可改机型支持 165 帧（抖音实测）。同源玩法：一加 Pad2Pro 改 OPPO Pad 4 Pro 免熔断保数据。
- 二代移植包作者 = 酷安@兰微卡鱼。
- 资源入口：**bszip.me/9008/**（悲伤分享页，四代救砖包/9008 固件/刷机包 3.0k 下载）、ROM乐园 romleyuan.com（教程+远程帮刷）、B站"悲伤的压缩包"（32万播放合集：免解锁 root/ColorOS16/金标/C16/降级 043 教程齐）。
- 刷法：9008 线刷包直刷，或 fastboot 刷 super；system 镜像模式的包需 fastboot。

## ④ 工具链（本地大多已备）
- **TWRP**（TB322FC 专用）：ROM乐园 2026-01 发布，`fastboot flash recovery twrp.img`；第三方 ROM/Magisk 卡刷/分区备份/卡刷救砖。device tree = polygraphene/android_device_lenovo_TB322FC。
- **LTBox v3.2.2** ✅ 本地（全量刷/救砖/降级/免解锁 root）。
- **9008/EDL 全套** ✅ 本地（edl.py、xbl_s_devprg_ns.melf、qfil；经验见 qualcomm-* 技能）。

## ⑤ 开发中（未成熟）
- **XDA 自定义内核**：TB322FC kernel build 进行中（找完整 GPL kernel source）——KSU LKM 的未来出路。
- **Mu-Silicium UEFI / mainline Linux**（SM8750 路线）：TB322FC 端口未完成，DT patch（Pengyu Luo）pending linux-arm-kernel。

## ⑥ LineageOS 源码移植线（路线 A，未开工；2026-09-30 调研，随 `~/y700类原生安卓/` 并入本仓）
同 SoC（SM8750）的类原生 ROM 生态已官方成熟，是唯一「成套上游」路线：

| 资产 | 内容 |
|---|---|
| `LineageOS/android_device_oneplus_sm8750-common` | SM8750 通用设备树（官方维护，LuK1337/bgcngm） |
| `LineageOS/android_device_oneplus_erhai` | 一加 Pad 2 Pro / Pad 3 = `erhai`，同 SM8750，当前 23.2 (Android 16) |
| `LineageOS/android_kernel_oneplus_sm8750` | 官方 6.6 内核源码 |
| XDA `[ROM][OFFICIAL][erhai]`（4761418） | 已知问题：触笔/键盘 BT 不稳、144Hz 闪屏、语音转文字异常 |
| AICP `[ROM][OFFICIAL][erhai][desktop mode]`（XDA 4764515） | Android 16 + 桌面模式 |
| /e/OS（erhai，基于 Lineage） | 去 Google 化变体，unofficial |

- **可行性证据**：TWRP 树以 `twrp_device_oplus_sm87xx` + `twrp_device_xiaomi_sm8750_thales`（小米平板 8 Pro，同 SM8750）为基础 → recovery 层跨厂通用；B站「悲伤的压缩包」已把 erhai 金标/澎湃OS3 移植到本机型成功。
- **必须自研的差异**：屏参（本机 1904×3040 vs erhai 2400×3392）、NT36536 触屏、aw88461 音频、TF 卡槽、Lenovo 特有外设。**同 SoC ≠ 免改**。
- **vendor blobs 提取工具**：`aweiyry/lenovo-ota-tool` —— 联想 OTA 增量包查询 + 分区提取（三/四/五代），路线 A 拿 vendor 的关键件，别处未记录。
- **原文**：`archive/topics/资料汇总-2026-09-30.md`（三路线 A/B/C 全评估 + 设备硬信息 + 风险清单）。

## 本地资产衔接（避免重复下载）
073 原厂包 / LTBox / tdgsi GSI 均已本地。要试移植 ROM 只需下：澎湃OS 3.0.307.0（bszip.me，含免解锁镜像）或 ColorOS16 金标包，2~3 GB 量级。
