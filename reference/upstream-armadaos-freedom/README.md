# armadaos-freedom 参考快照（Y700 Gen4/Gen5 · 同机型另一条 Linux 分支）

> 2026-10-22 拉取。仓库 `github.com/mydanyi/armadaos-freedom`，**main = `244b7451`**（2026-10-22）。
> 拉取方式：GitHub codeload tarball（aria2 JSON-RPC），**未保留 `.git`**，故本目录为**文件快照**，不是可 `git log` 的 clone。
> 快照体量：仓库 tar 189 MB / 展开 403 MB；本目录**只留可复用的小件**（168 KB），全套用下方 URL 重取。

## 1. 这是什么

ArmadaOS（SteamOS 风格 ARM 发行版，**Fedora bootc** 镜像体系）的**平板适配分支**，当前维护两代联想拯救者：

| 机型 | 型号 / SoC | 设备树标识 | 内核 |
|---|---|---|---|
| Y700 四代（= 本项目唯一机型） | TB322FC / SM8750 | `lenovo,elden` | 统一 Linux **7.2.6** |
| Y700 五代 / Legion Tab Gen5 | TB323FU / SM8850P | `lenovo,baldur` | 同上（同一构建，各自 DTB） |

自述能力：kShimC 多系统启动菜单、Steam Gaming Mode + KDE Plasma、FEX + Proton、触屏/双 USB/电池温度、G9 手柄与 RGB。
四代**已确认**的项（其 `devices/lenovo-tb322fc/README.md`）：kShimC 中文菜单、进原厂 Android、进机身 Linux/Steam 模式、
触屏坐标修正、**Steam 会话重开后的显示修正**、G9 手柄基础键 + 双击 Home + RGB。
**未确认**：充电功率/快充/双 USB 端口行为、安装与 OTA 端到端、启动器机型选择持久化、TF 卡与高级启动、**相机功能**（只补了 DTS 控制节点）。

## 2. 许可（决定能拿什么、不能拿什么）

| 部分 | 许可 | 对本仓（kernel 料 GPL-2.0-only / 文档 MIT） |
|---|---|---|
| 自有脚本与补丁 | GPL-2.0-or-later | ✅ 与本仓 kernel 料兼容，可摘录（保留出处与作者） |
| `devices/lenovo-tb323fu/boot/kshim-success-source/`（kShimC） | **GPL-3.0** | ⛔ **不并入本仓、不 vendor**（GPLv3 与本仓口径不一致）；只作外部构建依赖引用 |
| `packages/kshim-tools/vendor/` | 见其 `vendor/` 来源（Project-Aloha/DualBootKernelPatcher） | 只引用，不 vendor |

## 3. 本目录文件

| 文件 | 原路径（在 armadaos-freedom 内） | 用途 |
|---|---|---|
| `patches/0142…0155-*.patch` | `packages/kernel/patches/` | **elden 专属内核补丁全集**（显示/DPU/DSI/CPHY/时钟/电池），下方逐条裁决 |
| `dts/sm8750-lenovo-elden.dts.patch` | `packages/kernel/dts/` | 他们对 DTS 的适配补丁（内存节点/ramoops/splash/simplefb 处理方式与**本仓相反**，见 §5） |
| `device-README.md` | `devices/lenovo-tb322fc/README.md` | 四代功能状态与已知缺口（原文） |
| `boot-README.md` | `devices/lenovo-tb322fc/boot/README.md` | 四代 boot.img 打包（原厂 Android 基座 / 机身 Linux 两种布局） |
| `device-conf.txt` | `system_files/usr/lib/armada/devices/lenovo-tb322fc.conf` | 机型配置：显示旋转策略、触屏设备名、无内置手柄 |
| `steam-bootstrap-BASE.env` | `packages/steam-bootstrap/BASE.env` | **Steam ARM64 客户端 + Steam Runtime 的 pin**（G3 参考） |

原始 URL（重取整套时用）：
- tarball：`https://codeload.github.com/mydanyi/armadaos-freedom/tar.gz/refs/heads/main`
- 单文件：`https://raw.githubusercontent.com/mydanyi/armadaos-freedom/main/<path>`

## 4. ★ 逐条裁决：哪些我们已有、哪些是真增量

判据 = 本仓 `linux/`（7.2.0 + 本仓提交）中对应符号/行为是否已存在（2026-10-22 核查）。

| 补丁 | 内容 | 本仓状态 |
|---|---|---|
| `0142` DSC1.2 / 10bpc | DPU DSC 计算分支 | ✅ 已有（`DPU_DSC_FULL_ICH_PREC`、`dpu_hw_dsc_1_2.c`、`dpu_12_0_sm8750.h`） |
| `0143` CPHY link clocks | elden CPHY timing/时钟 | ✅ 已有（DTS `qcom,cphy-timing-ctrl` + PHY 侧实现） |
| `0144` bonded 命令 DMA | bonded DSI 命令/DMA 同步与错误处理 | ✅ 已有（`dsi_mgr_bonded_cmd_xfer`、`bonded_polling`） |
| `0145` panel binding + 14 字节 CPHY 属性 | DT binding | ✅ 已有（`novatek,nt36536.yaml` 在树） |
| `0146` SMMU boot handoff | 保留 bootloader 显示映射 | 🟡 **部分**：本仓有 `arm_smmu_map_boot_framebuffer()`，但**缺** `arm_smmu_boot_fb_range()`（见 §6） |
| `0148` clk orphan reparent | reparent 时保留迁移引用 | 🟡 **部分**：本仓有 `clk_core_reparent_orphan_nolock()`，实现细节不同（见 §6） |
| `0149` / `0150` battmgr SM8750 | `POWER_NOW` 上报 / USB `current_now`+`usb_type` | ✅ 已有（`qcom_battmgr.c` 内 SM8750 desc 与 usb props；来源不同） |
| `0153` video teardown 顺序 | 主/slave 拆管道时序（修 Steam 会话重开黑屏） | 🟡 有 `dpu_encoder_helper_phys_cleanup()` 与 enable-state 逻辑，但 elden 专属排序**未见**（补丁 3 处 hunk 对不上，需逐段比） |
| **`0154` dispcc probe 复位活显示** | `lenovo,elden` 上 probe 时**断言再释放** MDSS CORE / CORE_INT2 / RSCC 三个 BCR | ❌ **缺**（补丁可干净 `git apply`）——**Q28 候选**，见 §5.1 |
| **`0155` DSI PHY DIGTOP 供电** | `dsi_pll_{enable,disable}_pll_bias()` 里同 PLL 一起置/清 `DIGTOP_PWRDN_B`（仅 elden） | ❌ **缺**（可干净 apply）——**Q28 候选**，见 §5.1 |
| （未拷贝）`1000` hv-haptics / `1002` rsinput FF | 高通 HV 触觉驱动 + RSInput 震动桥 | ⚪ 不采用：本仓触觉走既有链路、手柄走 HID/xpad，无 RSInput 驱动 |
| （未拷贝）`0033/0035/0037/0038/0066` 等 SM8750 基础设施 | gpucc/GPU 节点/UART15/CPU capacity/热/ufshc | ✅ 本仓树更全（`sm8750.dtsi` 已含 gpu/gpucc/`qcom,sm8750-ufshc`） |

## 5. ★ 两个真增量

### 5.1 Q28「冷起 NOCARD」的直接候选：`0154` + `0155`

两条都**只对 `lenovo,elden` 生效**，合计 +32 行，风险面小：

- **`0154`**（SuperKali，出自 `retro98boy/armada@c3e46680`，原经 Armbian 提交）：某些 bootloader 在
  `ExitBootServices` 时把显示块留在**全活**状态（dispcc PLL 已锁、MDSS CORE/INT2/RSCC 已出复位）。
  内核随后 `mdss_reset()` / `PLL configure()` 叠在这个活状态上，command-mode 面板卡死（kickoff timeout / encoder reset failure）。
  解法 = probe 时把三个 BCR 置 1、握 50 ms、逆序释放，让 PLL 与 `qcom_cc_really_probe()` 从零编程。
- **`0155`**（Dmitry Baryshkov，上游系列）：`dsi_pll_7nm_vco_prepare()` 只清 `PLL_SHUTDOWNB`、不抬
  `DIGTOP_PWRDN_B` ⇒ **PLL 锁不上**；自 `acf7a91d0b0e`（dispcc-sm8250 让 pixel clock 自带 parent enable）后，
  时钟框架会在 PHY 未使能时**先**去锁 PLL，于是打印
  `DSI PLL(0) lock failed, status=0x00000000` 并让 pixel clock 使能计数失衡。
  `CMN_CTRL_0` 在失败时刻读到 `0x20`（`PLL_SHUTDOWNB` 已置、`DIGTOP_PWRDN_B` 未置）。

**与本仓症状的对应**：本仓 `PITFALLS`/`reports` 记录的冷起 NOCARD 模式正是
「`DSI PLL(0) lock failed status=0x00000000` ×4 + `Failed to create device link … for panel@0` ×6 ⇒ 无 `card0`」。
历史判定把这条打印当「下游伪影」（`PITFALLS #277`、`#31` 会话）——在「display-subsystem 因缺模块不聚合」那种场景下成立，
但 **`0155` 给出了另一条独立成因**：即便组件齐备，PLL 也可能真的锁不上。
⇒ 作为 **Q28 候选 A/B** 落地，判据用现成三态探针（`scripts/q28-devprobe.sh`，NOCARD/STORM/GOOD），**冷起 ≥10 发**才谈结论。
⚠ 不可与「软件闩锁 / `link_configured` 误清」那两条（2026-10-22 `TASKS/sessions/`）混为一谈：那两条解释**不可恢复性**，这两条解释**首次坏发**。

### 5.2 G3（Steam）：本仓路线是 Box64+Wine，他们走**官方 ARM64 Steam + FEX**

`steam-bootstrap-BASE.env` 给出可直接复用的 pin：

```
STEAM_CLIENT_VERSION=1791918634
STEAM_RUNTIME_VERSION=3c.0.20260729.253765
STEAM_RUNTIME_SHA256=d0e21db9538bcbdfa51b46f0acbba8a3dcbd6e5f345ae410a6b89d9b90b7d09e
# manifest 名：steam_client_steamdeck_stable_linuxarm64（CDN client-update.steamstatic.com）
```

`packages/steam-bootstrap/` 里有 `fetch.py`/`verify.py`/`generate.sh`：按 manifest 逐包 sha256 校验下载、离线生成
`~/.steam` bootstrap，再配 `packages/fex`（FEX-Emu + 交叉 sysroot）+ `packages/gamescope`(+session) + `packages/mesa`。
**对本仓意义**：Steam 官方 **linuxarm64 客户端通道确实存在**且被第三方跑通 ⇒ G3 不必从「x86 Steam under Box64」单腿走，
可评估「native ARM Steam + FEX 跑 x86 游戏」这条更像 SteamOS 的路（我们的 Alpine 侧需 FEX + gamescope 打包，属新工作量）。

## 6. 两条「我们只做了一半」的差异（供 Q28/显示交接排查）

- **`0146` vs 本仓**：本仓从 DT `memory-region`（`splash_mem`）取基址；他们改为在运行时 `/chosen/simple-framebuffer`
  取**实际** framebuffer 范围，并新增 `arm_smmu_boot_fb_range()` 把该 4K 对齐范围**从 DMA allocator 预留**，同时把
  `arm-smmu-qcom.c` 的 SID 切换路径按 elden 收窄。**若出现「splash 区域被后续 DMA 覆盖 / 花屏」类症状，这是对照点。**
  注意：他们把 DTS 里固定 `memory@a0000000`、`ramoops@c2000000`、`splash-region@fc800000` 全 `status="disabled"`，
  内存节点改由 kShimC 交接重建 —— 与**本仓保留固定地址**的做法相反；**不要照搬**（我们不是 kShimC 引导链）。
- **`0148` vs 本仓**：同样有 orphan reparent 函数，但他们在 `clk_core` 里加 `orphan_reparent_failed` 并**保留迁移引用**
  （避免 reparent 期间 parent 被关），并在 `-EPROBE_DEFER` 路径复用。差别属「同一问题的两种写法」，比对本仓
  `drivers/clk/clk.c` 的 reparent 段即可判断是否需要补。

## 7. 可复用但**未**取进本仓的部分（按需外取）

| 资产 | 路径 | 价值 | 障碍 |
|---|---|---|---|
| kShimC 启动菜单（含 `tb322fc_android_defconfig`、STAR_CHART 主题、中文菜单、按键导航） | `devices/lenovo-tb323fu/boot/kshim-success-source/`（5.4 MB，GPL-3.0） | 现成的「原厂 Android / 机身 Linux / TF 卡 / 诊断 / EDL」菜单，**四代已实测** | GPL-3.0 许可；且引入即等于换掉本仓「单槽 boot_b + kexec」启动架构，属立项级决策 |
| kshim-tools（`MultiBootKernelPatcher`/`UnpackTool`/`repack_boot_v4.py`/`avbtool.py`，静态 AArch64） | `packages/kshim-tools/` | 在已有 Android v4 boot.img 里**换内核**并打包多启动载荷 | 与本仓 `bootslot-b/` 打包脚本功能重叠，先比再取 |
| 引导布局脚本 | `system_files/usr/libexec/armada/kshim-build-boot.py`、`armada-kshim-{prepare,sync}` | `maintenance` / `installed` 两种布局的离线打包（含 avbtool 未签名校验闭环） | 同上 |
| Steam/游戏栈 | `packages/{gamescope,gamescope-session,steam-bootstrap,fex,mesa,plasma-mobile,…}` | G3 端到端配置（gamescope flags、session、FEX sysroot） | Fedora 配方；本仓是 Alpine，只能当配置参考 |
| 设备配置语义 | `device-conf.txt` | `ARMADA_GAMESCOPE_USE_ROTATION_SHADER=1`（硬件旋转 scanout 未定时用 shader 兜底）、触屏名 `NVTCapacitiveTouchScreen`、`ARMADA_BUILTIN_GAMEPAD=0` | 直接可用的**事实**（尤其触屏设备名） |
| tplg 源文件 | `audio_topology/sm8750/*.m4`（AYN/KONKR，非本机） | m4→`alsatplg` 生成 tplg 的方法链 | 机型不同，只学方法 |

## 8. 结论（一句话）

**唯一高价值增量是 `0154`+`0155` 这两条 elden 专属显示初始化补丁**（Q28 冷起 NOCARD 的独立候选成因），
其余显示/电池/SM8750 基础设施本仓已具备或更全；kShimC 与 Steam 栈是**另一条架构路线**的现成资产，需立项另议。
