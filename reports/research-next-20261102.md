# 下一步任务调研（2026-11-02）——三条线的判别性事实与可执行第一步

> 性质：**只读 + 联网**。未接触设备（无 adb/fastboot/ssh/EDL），未 sudo，未构建，未下载大文件；
> 未改任何 `README.md` / `INDEX.md` / `PITFALLS/` / `DEVICE` / `TASKS/README.md`；未 git add/commit。
> 唯一新增产物 = 本文件 + `TASKS/sessions/2026-11-02-下一步调研.md`。
> **抓取日期统一 2026-11-02**（下文 URL 后不再重复日期）。
> 证据分级：`已证` = 本次亲手取到的代码/API 原文或命令输出（附 `file:line` / msgid / sha）；`外部` = 第三方项目文档/issue 原文，
> 未独立复核；`社区` = 有可复现步骤的博客/issue 讨论；`未证实` = 单一帖子/传闻/推断。
> 联网手段：`gh api`（GitHub 只读）、`patchwork.kernel.org` / `patchwork.freedesktop.org` REST API、
> `raw.githubusercontent.com`（curl）。**lore.kernel.org 未被访问**（Anubis），全部用 patchwork API 替代。

---

## §0 结论先行（数字 + 一句影响）

| # | 结论（一行事实） | 对我方的影响 | 等级 |
|---|---|---|---|
| 1 | 上游 **camss 的 `CSIPHY_SKEW_CAL` 条目根本不写寄存器**：`case CSIPHY_SKEW_CAL: continue`（上游 `up-csiphy.c:1099-1100`，本地 `linux/.../camss-csiphy-3ph-1-0.c:1216-1217`） | M4 的 R1「0x54 vs 0x00 已做上机 A/B 无可测差异」**不是证据**（差异不可能被测出）；应改写为「inert + 采用厂商值」，否则评审会当场打回 | 已证 |
| 2 | **SM8750 的 DSI per-SoC cfg + host 回调已经在上游**：`80dd5911cb`（2025-06-18，Krzysztof，13 发系列 `b4-sm8750-display-v7`）新增 `dsi_clk_init_6g_v2_9()` 与 `sm8750_dsi_cfg`；`2482c6f93a`（2026-01-15）再加 Kaanapali 2.10.0 | M6 B5「把 bonded DSI 收进 `msm_dsi_config` + `host_cfg_ops`」的**目标结构不是新设计**，我方增量只能是 v2_9 ops 上的 delta；B5 的「机械样例 P1」需先查重 | 已证 |
| 3 | **Qualcomm 已有一份在审的 SM8750 camss 系列**：Hangxiang Ma `[v6 0/7]`，2026-07-21，`Reviewed-by: Bryan O'Donoghue`，patchwork state=`new`（binding 那枚 `not-applicable`） | 我方 2026-10-28 发出的 9 发 `[v2 0/9]`（msgid `20261028093003.722745-9-…`）在范围上与其**重叠**；继续「自成一系列」有被判重复的风险，应先做覆盖差集 | 已证 |
| 4 | **Bryan 2026-10-29 发了 14 发「Add SOF/EOF sequence logic」**（series 1196135，cover `<20261029-v4l2-frame-sync-v1-0-d37992559c58@kernel.org>`）：CSID 驱动 SOF/跟踪 + 事件 + 逐 SoC 打开 `frame_sync_en`，**打开名单 = sm8650/x1e/x2e/sm8250/sdm845，不含 sm8750** | M4 R3（帧起始从 VFE 移到 CSID）**不该再单立 RFC**，正解 = 评审该系列 + 提交 sm8750 的 `frame_sync_en` 后续增量 | 已证 |
| 5 | **Mu 维护者对本机 UFS 的定性**：「Link State 处于 Sleep 状态，写个 tiny DXE 把 link state 拉起来」；并明确**「你系统版本问题」**（即需按固件版本的 UFSDxe 补丁）——`mu_wide_platforms` issue #12 评论 2026-10-28 | UFS 不是「配错 config map」而是**链路状态 + 固件代次**；不再往 `PlatformConfigurationMapLib` 方向查 | 已证 |
| 6 | 同一 issue 里维护者的第二条建议：**「去弄个 UEFI 的 USB ACM Gadget」**（没有屏幕时唯一早期通道） | 与 SunUEFI 的「UEFI 侧 fastboot」同构；这是把「载荷到底跑没跑」变成一次 `getvar` 的正解，**优先于**继续折腾 DDR marker | 已证 |
| 7 | 同族设备的实测把「载荷被执行」与「看得见」彻底拆开：OnePlus 8T（SM8250）`fastboot boot` 连**已签名**镜像都报 `Failed to load/authenticate boot image`，只有 `flash boot_a` 能起；起后 **72 B `wfi` stub 也让机器离开 fastboot ~6 s、~8 s 回落 = 看门狗**；对 `0x9C000000` 刷整屏红**从未可见**；关 APSS WDT 使能寄存器**也不生效** | ①「执行了但不可见」是被独立复现的一类；② 判据必须是**独立通道**；③ 回落时限先查看门狗；④ **槽位路径**才是该 ABL 验证过的载体 | 已证 |
| 8 | SunUEFI 的 stage0 打包 = `gzip.compress(shim + fd) + dtb` 作为 `kernel`，header v3/v4（`tools/package_stage0.py:48-49`）；合体 BOOT **只改 `kernel_size`**，selector+shim+FD 全部接在**原厂 GKI 之后**，让 ABL 走**正常 boot 路径**整段加载（`docs/devel/boot/combined-boot.md`） | 「用槽位正常启动承载自定义载荷」在 **SM8750P 同档平板**上已被走通；我方 v0 载荷本身也已是 gzip（实测首字节 `1f8b08`）⇒ **压缩不是差异源** | 已证 |
| 9 | SunUEFI 的执行判据不是屏幕也不是 `OKAY`，而是**UEFI 自己重新枚举成一个 fastboot 设备**：`fastboot -s SunUEFI-piano getvar product` 返回 `piano-sunuefi`；并写明「`OKAY` 只说明原厂 Bootloader 收下了镜像」（`docs/user/temporary-boot.md`） | 我方「`usb_read failed` = 交棒」的口径应**整体废弃**，改用「新 USB 设备自报身份」 | 已证 |
| 10 | 我方 `boot_b` 载荷的 v0 header 实测：`kernel_size=2436791`、`kernel_addr=0x10008000`、`ramdisk_size=0`、page=4096、kernel 首字节 `1f8b0800`（`reports/artifacts/uefi-ddr-20261101/slotb-uefi-marks.img`） | 与 SunUEFI 的形态差异只在「无 DTB 尾、无 selector、无 ramdisk」；这三项可作为下一批单变量，而不是继续 header 全字段差分 | 已证 |
| 11 | 三个 Pakala 设备包里 **patched UFSDxe 是三个不同 blob**：y700g4≡nx789j `00ae059f…`、dodge≡erhai `1ff2d468…`、piano `c1f38f91…`（155 648 B）；未补丁件每机不同（y700g4 `dac620ac…`） | 跨机型借 UFSDxe 会引入新变量；y700g4 的三处补丁（`0xa998`/`0x114c4`/`0x1b080`）是共享 delta，但**维护者说要按固件版本再补** | 已证 |
| 12 | G2 的上限被上游文档写死：PIFork README 明说 A13+ 的 Play Integrity「**连 DEVICE 都要靠 locked bootloader**」，且「新机型的值只允许**完整硬件背书**」；模块本身要求 Magisk/KSU/APatch + Zygisk | Waydroid（无 TEE、`test-keys`、unlocked、容器）**到不了 DEVICE/STRONG**；C3 的「待取回包」只值得做一次取证，不值得再投优化 | 已证 |
| 13 | Waydroid 侧：维护者原话「**Waydroid is not a Google verified device**」（issue #1858，2025-05-09）；「Magisk 支持 / 让 SafetyNet 过」的 issue **#182 至今 open**（最后更新 2025-10-20），社区 2024 年把 Magisk 跑起来了但 PIF/SafetyNet 仍不过 | 「容器里装 PIF/TrickyStore」缺少可用的注入层（无 Magisk），任何「已过 DEVICE」的说法目前只有 Telegram 级来源（`未证实`） | 已证/社区 |
| 14 | G3 的路线已经换代：Valve 的 **ARM64 Steam 客户端**（Proton beta 的 ARM64 builds + 内置 FEX）随 Steam Frame 出货；2026-09 实测**原生 ARM 客户端启动 ~11 s**（对比 FEX/Box64 时代的数分钟），Portal 2 / Silksong 1080p 平均 ~100 fps；同期 Valve 开发者仍声明「Steam for Linux **不官方支持** ARM 硬件」 | G3 从「Box64+Wine PoC」切到「**Valve ARM64 steamrt + FEX + Proton(ARM64)**」，验收改成「启动时间 + 一个 Proton-verified 标题」；Box64 降为备胎 | 已证/外部 |
| 15 | 工具链现状：`FEX-2610` 发布 2026-10-07（FEX 仓库 2026-11-02 仍在推）；`box64` 2026-11-01 仍活跃；Canonical 2026-06 把 **arm64 Steam snap 转 stable**，做 GL/Vulkan thunk 以绕开全量 FEX | 我方不必自己攒 Wine；先试「装包 + 一个标题」即可判断 G3 能否从 3.3/5 抬档 | 外部 |

**一句话**：三条线里**最贵的两个判断都已经被别人替我们做了**——UEFI 的判据应该是 USB 自报身份（不是 DDR、不是 `usb_read failed`），
上游 camss/DSI 已经有在审系列（不该再自建系列）；真正还需要我方动手的只有「把判据落到本机」和「把差集算清楚」。

---

## §1 线 1：UEFI/Mu 为什么载荷未执行

### 1.1 已证事实（带出处）

| # | 事实 | 出处 | 等级 |
|---|---|---|---|
| L1-1 | 本机 Mu 设备包 **有 USB device 栈**：`UsbfnDwc3Dxe`、`UsbDeviceDxe`、`UsbBusDxe`、`UsbConfigDxe`、`UsbInitDxe` 全在 `Platforms/PakalaPkg/Device/lenovo-y700g4/Binaries/QcomPkg/Drivers/` | `mu_wide_platforms` tree（`gh api .../git/trees/main?recursive=1`，29 557 条） | 已证 |
| L1-2 | 同一棵树里**没有任何 `UsbSerial*` / CDC-ACM**；我方此前也已核实 `USE_UART_GENI_FOR_SERIAL_OUTPUT = 0`、`USE_UART_DM_FOR_SERIAL_OUTPUT = 0` | tree grep；issue #12 我方 2026-10-28 评论 | 已证 |
| L1-3 | `QcomGeniSerialPortLib` 只存在于 `Platforms/AndromedaPkg/Library/`（通用包），y700g4 的 `APRIORI.inc` 未引用它；APRIORI 第一梯队是 `QcomWDogDxe`(patched) → `ClockDxe`(patched) → … → `UFSDxe`(patched) | 同上 + `lenovo-y700g4/APRIORI.inc` 原文 | 已证 |
| L1-4 | 维护者对 UFS 的定性 = **Link State Sleep**，并要我方按固件版本打 UFSDxe 补丁；对「看不见」的建议 = **UEFI USB ACM Gadget** | issue #12 评论 2026-10-28 / 2026-10-29（`sunflower2333`） | 已证 |
| L1-5 | 同族 ABL 实测（OnePlus 8T/SM8250）：`fastboot boot` 对**未签名与已签名**镜像都 `Load Error`；`flash boot_a` 能起；**72 B `wfi` stub** 离开 fastboot ~6 s、~8 s 回落（判为看门狗）；整屏红**不可见**；关 APSS WDT 使能寄存器**无效** | <https://github.com/Project-Silicium/Mu-Silicium/issues/2163>（2026-10-24） | 已证 |
| L1-6 | SunUEFI 的两条装载路径：①**合体 BOOT**（只改 `kernel_size`，selector+shim+FD 接在原厂 GKI 之后，ABL 走正常 boot 路径）；②`fastboot boot` 纯 UEFI 镜像（零写入） | <https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/devel/boot/combined-boot.md>；<https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/user/temporary-boot.md> | 已证 |
| L1-7 | stage0 的 kernel 段 = **gzip(shim+FD) + dtb**，header v3/v4 | <https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/tools/package_stage0.py>（第 48–49、57–61 行） | 已证 |
| L1-8 | 执行判据 = **新 fastboot 设备自报**（`-s SunUEFI-piano getvar product` → `piano-sunuefi`）；另有 `oem ramlog`(≤256 KiB)/`oem screenshot`/`fetch`(≤64 KiB)/`oem status`，`flash`/`erase` 一律拒绝 | <https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/user/fastboot.md> | 已证 |
| L1-9 | 第三方 UEFI 的第二套实现同样把「UEFI 期 USB 调试 fastboot」当可见性主通道，并额外给了 `oem dump 81CE4000 10000` 读 ABL 日志、`boot app.efi` 从 RAM 起 EFI 应用 | <https://github.com/xiaomi-pad-8-pro-development/android_device_xiaomi_piano-uefi> `docs/DETAILS.md` | 外部 |
| L1-10 | EUD 侧：本机内核 `CONFIG_USB_QCOM_EUD=m` 但在跑 DT 里 `eud` 节点 **0 个** ⇒ 0 次 probe；`logfs` 10/10 段有 `EUD Init`、`EUD wait` **0/10**；官方文档只承诺「Linux/console 起来后手动 enable」 | `reports/uefi-eud-feasibility-20261101.md` §0/§2（本仓） | 已证（本仓） |
| L1-11 | 我方载荷实测 header 形态见 §0#10；`slotb-uefi-marks.img` 与 `out/uefi-20261101-1005recipe-v0.img` 的 kernel 首字节都是 `1f8b0800` | `python3` 直读两枚镜像 header（本次） | 已证 |
| L1-12 | 我方**唯一一次**「屏上出现 EDK2 文字」= 2026-10-05 的 CI 件（`fastboot boot`），后续所有重建均未复现 | `TASKS/README.md` §5（10-31/11-01 各块）+ `reports/uefi-ddr-blackbox-20261101.md` §7.2 | 已证（本仓） |
| L1-13 | 槽位路径上一次失败时 `logfs` **没有** `Booting from slot`，`POST Time` 后 7.8 s 就 `Start EBS [7940]`；而卡死事故的真根因是**槽位与 boot LUN 代次不配对**（`*_a`+LUN1=259 原厂，`*_b`+LUN2=上一版） | `TASKS/README.md` §5（11-01 19:40 / 21:xx 两块）、`PITFALLS #484` | 已证（本仓） |

### 1.2 由这些事实推出的判别结构（不再猜「执行了没」，而是先归类）

```
fastboot boot 发出
  ├─ A 拒：<10.2 s 回 "Booting OKAY"，fastboot 仍应答            → 根本没加载
  ├─ B 回落：USB 静默 ~20 s 后出现 17ef:7f3d(Android)/回 Linux   → 加载了但没跳到我们，或跳到后立刻死
  └─ C 挂：USB 永久静默 / 屏停 logo                              → ABL 自己在加载/解压里挂了
```
- 现有 50 ms 轮询证据（`scripts/uefi-usb-gap.py`）已把「不写东西的 shim」与「`b .` 自旋」量成同一档（20.53/20.05 s vs 20.20/19.99 s）
  ⇒ **A/B 两态无法区分「执行」与「没执行」**，必须换通道（§0#6/#9）。
- 剩下的**唯一零成本**判别是「同一镜像多发统计」+「已知能执行的真内核做正控」。

### 1.3 对我方最小的下一步（零写盘优先）

1. **统计化 `fastboot boot`（15 min，零写盘）**：同一枚 2.4 MB 载荷连发 3 发，每发抓 `usb-gap` + `logfs` + `getvar` 活性，
   按 A/B/C 三态记；对同一枚「日常 Linux boot.img + 唯一 cmdline」也连发 3 发。判据见 §4-R1。
2. **若正控（Linux 镜像）稳定进 B 而我们载荷稳定进 A/C** ⇒ 差异在载荷侧，按 §0#10 列的三项（无 DTB 尾 / 无 selector / 无 ramdisk）
   做单变量，而不是再差分 header 字段。
3. **通道**：写最小 UEFI CDC-ACM gadget（复用 `UsbfnDwc3Dxe`/`UsbDeviceDxe`，把 `SerialPortLib` 指向它），
   或直接移植 SunUEFI `uefi/core/PianoFastboot.c`（BSD-2-Clause-Patent）命令层（`getvar product` + `oem ramlog`）。
4. **UFS 侧**（若要继续走 UFS）：按维护者口径写「把 link state 从 Sleep 拉起来」的 tiny DXE，
   **不要**再改 `PlatformConfigurationMapLib`（我方 10-21 静态分析已证 `0x402` 不是 config tag）。

---

## §2 线 2：上游化剩余硬项

### 2.1 CSIPHY SKEW_CAL 的 4 条偏离——已不再需要 A/B

| 事实 | 出处 | 等级 |
|---|---|---|
| 上游 `csiphy_gen2_config_lanes()` 对 `CSIPHY_SKEW_CAL` 是 `continue`（**不写寄存器**） | 上游 master `drivers/media/platform/qcom/camss/camss-csiphy-3ph-1-0.c:1099-1100`；本地 `linux/...:1216-1217` | 已证 |
| 上游 lane 表里 `SKEW_CAL` 取值**没有统一约定**：x1e80100 = `0x00/0xBD/0x7F`（`:833-834`），sm6350 = `0xc0/0x0d`（`:424-425`），sm8550/sm8650 表里根本没有 SKEW_CAL 段 | 同上（`up-csiphy.c` 本次抓取，1277 行） | 已证 |
| 上游 `camss` **没有** `CAMSS_8750`、**没有** `lane_regs_2_4_0`（9 张 lane 表里无 2.4.0） | 同文件 grep（`CAMSS_8750`/`lane_regs_2_4_0` 命中 0） | 已证 |
| 我方 lane 表与厂商 `csiphy_2ph_v2_4_0_reg` 地址/掩码/类型 103/103 一致、data 99/103；4 条差异全在 `0x5c` 的 SKEW_CAL | `reports/m4-csiphy-vendor-provenance-20261027.md` §2 | 已证（本仓） |

**影响**：`0x54 → 0x00` 的改动在**当前驱动里不产生任何寄存器写**，所以「本机 A/B 90 帧无可测差异」是**结构必然**，
不能作为「这两个值等价」的论据。建议表述改成：
> 「lane 表取自厂商 CSIPHY 2.4.0 (2ph) register map；其中 4 条 `SKEW_CAL` 条目在当前驱动中被跳过
> （`csiphy_gen2_config_lanes()` 的 `continue`），保留厂商值仅为与厂商寄存器图逐条对齐，无运行期效果。」

### 2.2 M6 B5「per-SoC DSI cfg 重构」——上游已有同类提交

| 事实 | 出处 | 等级 |
|---|---|---|
| `drm/msm/dsi: Add support for SM8750`（`80dd5911cb`，2025-06-18，Krzysztof Kozlowski）：新增 `dsi_clk_init_6g_v2_9()`、`sm8750_dsi_cfg`、`msm_dsi_6g_v2_9_host_ops`；属 13 发系列 `20250618-b4-sm8750-display-v7-7`（patchwork fdo #659619） | <https://git.kernel.org/torvalds/c/80dd5911cb>；<https://patchwork.freedesktop.org/patch/659619/> | 已证 |
| `drm/msm/dsi: Add support for Kaanapali`（`2482c6f93a`，2026-01-15）：DSI 2.10.0 + `kaanapali_dsi_cfg` | <https://git.kernel.org/torvalds/c/2482c6f93a> | 已证 |
| 上游 `struct msm_dsi_config` / `struct msm_dsi_host_cfg_ops` 已存在，`calc_clk_rate(..., bool is_bonded_dsi)` 已把 bonded 概念放进 ops | 上游 `dsi_cfg.h:44-66` | 已证 |
| 我方 B5 设计稿的口径是「per-SoC 侧改动 0 行」——指的是**我们自己的增量**没动那张表，不是上游没有 | `reports/b5-per-soc-cfg-design-20261027.md` §0 | 已证（本仓） |

**影响**：B5 的价值从「引入 per-SoC 分层」下调为「把 elden 的 bonded 增量**搬进**已有分层」。
投递前必须先 `git log`/`git blame` 核 `dsi_cfg.c` 的 v2_9 段与 `dsi_sw_reset_v2_9()` 是否已被上游写入
（本地 7.3 树已含 `msm_dsi_6g_v2_9_host_ops`，grep 命中 4 处）——若命中，则 P1「机械样例」可能整枚冗余。

### 2.3 camss SOF 迁移——**不要**单立 RFC，应挂到 Bryan 的在审系列

| 事实 | 出处 | 等级 |
|---|---|---|
| `[00/14] Add SOF/EOF sequence logic`（Bryan O'Donoghue，2026-10-29，series 1196135）：`Introduce SOF sequence tracking` / `csid-gen3: Enable RDI SOF driving` / `csid-680` / `csid-gen2` / 逐 SoC 打开 `frame_sync_en`（**sm8650、x1e/x2e、sm8250、sdm845**） | <https://patchwork.kernel.org/api/1.0/series/1196135/>；cover msgid `<20261029-v4l2-frame-sync-v1-0-d37992559c58@kernel.org>` | 已证 |
| cover 明确语义：SOF 用于 `V4L2_EVENT_FRAME_SYNC` 时间对齐 + 后续 shadow-register 编程；EOF 用于 `vb.sequence` 逐帧递增 + 参数/统计 buffer 归属 | 同上（cover 正文） | 已证 |
| Qualcomm 的 SM8750 camss 系列：`[v6 0/7]`，2026-07-21，`Reviewed-by: Bryan O'Donoghue`，7 枚；binding 那枚 `not-applicable` | <https://patchwork.kernel.org/api/1.0/series/1131654/>；patch 14700822 | 已证 |
| 我方 `[v2 0/9]` 2026-10-28 已实际发出（不是「未发」）：patch 14920898，submitter `Qianhui Xu`，msgid `20261028093003.722745-9-xiaqinghuan@mail.ustc.edu.cn`，state 立即 `superseded`（重复投递） | <https://patchwork.kernel.org/api/1.0/patches/14920898/> | 已证 |
| 我方自己 10-31 的 v2 fixes cover 里已经写明「SM8750 camss enablement 是 Hangxiang 在做」 | `patches/upstream/m4-camss-v2-20261031/v2-0000-cover-letter.patch` | 已证 |

**影响**：M4 的正确动作是**算差集 + 挂依赖**，而不是再发一轮 9 发：
- 与 Hangxiang v6 比对后，只保留**他确实没有的**：CSIPHY 2.4.0 (2ph) lane 表、CSID-980（full/lite）、VFE gen4 资源/寄存器数值。
- R3（帧起始）改成「review Bryan 的 14 发 + 追加 `sm8750 frame_sync_en` + csid-980 SOF 钩子」，并在 cover 写 `Depends-on`。

---

## §3 线 3：G2/G3 现状校准（只留能改打分/路线的事实）

### 3.1 G2 / Play Integrity

| 事实 | 出处 | 等级 |
|---|---|---|
| PIFork 是 **Zygisk 模块**（需 Magisk / KSU(+ZygiskNext/ReZygisk/NeoZygisk) / APatch），不是普通 APK | <https://github.com/osm0sis/PlayIntegrityFork> README（2026-10-29 push） | 已证 |
| 同一 README：**A13+ 的 Play Integrity 连 `DEVICE` 都要靠 locked bootloader**；「新机型的属性只允许**完整硬件背书**」 | 同上 | 已证 |
| 原 `chiteroman/PlayIntegrityFix` 仓库**已 404**（2026-11-02 查）；PIFork 是活跃分支（★4637） | `gh api repos/chiteroman/PlayIntegrityFix` → 404 | 已证 |
| Waydroid 维护者：「Waydroid is not a Google verified device」（2025-05-09） | <https://github.com/waydroid/waydroid/issues/1858> | 已证 |
| 「Magisk support or getting safetynet to pass」issue **#182 仍 open**（2025-10-20 最后更新）；社区 2024 用 `waydroid_script` PR#143 让 Magisk 跑起来，但 **PIF/SafetyNet 仍不过** | <https://github.com/waydroid/waydroid/issues/182> | 社区 |
| TrickyStore：改 key attestation 证书链；**TEE broken 设备**回落「generate certificate」模式（需未吊销 keybox）；模块形态同样是 Magisk/KSU 模块 | <https://github.com/5ec1cff/TrickyStore> README（2025-11-30 push） | 已证 |
| 「Waydroid 已过 DEVICE / 有个叫 Playstrong 的闭源方案」 | Telegram 转发（issue #182 评论 2025-09-17，后续追问「还works吗」无答） | 未证实 |
| 我方 C3 取证：容器内 **Widevine 不存在**（只有 clearkey 插件）、`userdebug`+`test-keys`、DRM HAL 仅 clearkey | `TASKS/README.md` C3 行 / `reports/c3-identity-drm-20261013.md` | 已证（本仓） |

**对打分的影响（结论）**：
- **STRONG / DEVICE 结构性不可达**（无 TEE、无 locked bootloader、无硬件 keymaster；且 PIF 系列本身要靠 Zygisk 注入层，Waydroid 没有）。
- **BASIC 也不应假设可得**：A13+ 判定包含 bootloader 状态；我方镜像 `test-keys`。
- ⇒ C3 的剩余动作从「按社区三做法各变一变量复现」压缩为**一次取证**（装检查器取三档回包 + 记录 build 属性），
  结论大概率是「三档全 false / 仅 basic 偶尔 true」；此后 **G2 不再为 PI 投任何工时**。
- TrickyStore 路线（伪造 keybox）**不投入**：既是未证实收益，又引入凭据/合规风险（硬规则 2）。

### 3.2 G3 / Steam

| 事实 | 出处 | 等级 |
|---|---|---|
| Valve 的 ARM64 Steam 客户端已实际存在（Steam Frame 上 `steam` 为 `ELF aarch64`），Proton 的 ARM64 builds 内置 **FEX 2604**；Valve 开发者仍声明「Steam for Linux is **not currently supported** on Arm-based hardware」 | <https://www.techpowerup.com/353418/valve-confirms-steam-for-linux-isnt-officially-supported-on-arm-chips>（2026-10-06） | 外部（含 Valve 开发者原话引用） |
| 2026-09 实测：原生 ARM 客户端**启动 ~11 s**（Orin NX）/ ~17 s（RK3588），对比 FEX/Box64 时期「数分钟」；Proton(ARM64)+FEX「无需额外配置」；Portal 2 / Silksong 1080p 平均 **~100 fps**，Skyrim SE 开场 60 fps | <https://interfacinglinux.com/2026/09/20/steams-unofficially-official-arm-client-for-linux/>（2026-09-20） | 社区（有步骤 + 硬件型号） |
| Canonical 2026-06 把 **arm64 Steam snap 转 stable**，用 GL/Vulkan **thunk** 取代全量 FEX；官方说下一步改用 Valve 原生 ARM64 客户端 | <https://itsfoss.com/news/arm64-steam-snap-goes-stable/>（2026-06-04） | 外部 |
| `FEX` 最新 release **FEX-2610**（2026-10-07），仓库 2026-11-02 仍在推；`box64` 2026-11-01 仍活跃 | `gh api repos/FEX-Emu/FEX/releases/latest`、`repos/ptitSeb/box64` | 已证 |
| 本机图形栈：Adreno 830 走 **Turnip + Zink** 已可用（下游树报告 165 Hz、GPU 可用） | `reports/research-vertical-y700-lineage-20261101.md` §2.4（引 h0cheung/GEEKiDoS） | 外部 |

**对路线的影响**：G3 的「技术选型」这一格应从 **Box64 0.4.5 + Wine 9 PoC** 换成
**Valve ARM64 steamrt（或 arm64 snap）+ FEX-2610 + Proton(ARM64)**；Box64 只在「拿不到 steamrt 包」时做备胎。
验收载体也应从「Wine 里跑一个 exe」换成「Steam 客户端起得来 + 一个 Frame-verified 标题能进游戏」。

---

## §4 下一步 3 条建议（每条：做什么 / 需要设备 / 判别判据 / 预计成本 / 失败副作用）

### R1（UEFI，最高判别力）先把「载荷到底跑没跑」变成 USB 自报身份

- **做什么**（两步，先后不可换）：
  1. **统计化三态判别**（先做）：`slotb-uefi-marks.img` 连发 3 发 `fastboot boot`，每发：`usb-gap.py` 记间隙、
     抓 `logfs`（`scripts/abl-log.sh`）、记 ABL 回话；**同一天**用同一脚本发 3 发「日常 Linux boot.img + 唯一 cmdline」作正控。
  2. **UEFI CDC-ACM gadget / UEFI fastboot**：复用设备包内 `UsbfnDwc3Dxe`+`UsbDeviceDxe`，实现一个只支持
     `getvar product` + 读回一行 stage 计数的最小服务（命令层可移植 `PianoFastboot.c`，BSD-2-Clause-Patent）。
- **需要设备**：步骤 1 需要（约 15 min）；步骤 2 的**编码与构建不需要设备**，只需 1 次上机验证。
- **判别判据**：
  - 步骤 1：同一镜像 3 发中若出现 ≥2 种终态（拒/回落/挂）⇒ ABL 接受性非确定，**任何单发结论作废**；
    若 3/3 为「拒」而正控 3/3 为「回落」⇒ 问题在载荷侧（进入步骤 2 / §0#10 的单变量）。
  - 步骤 2：主机 `lsusb` 出现**新的** VID/PID，且 `fastboot -s elden-uefi getvar product` 返回自报串 ⇒ **载荷执行 + USB 栈活**（一次成功即永久解决可见性）。
- **预计成本**：步骤 1 = 0.25 h；步骤 2 = 2–4 人日（含调试），上机 1–2 次。
- **失败副作用**：仅影响自建 FD/镜像（`scripts/flash-b.sh` 一条命令回退），**不写 GPT、不动 AVB、不碰 a 槽**；
  若 gadget 让 USB 不枚举，最坏退回「`fastboot boot` 日常内核」即可恢复，无不可回退点。

### R2（上游，性价比最高）把 M4 从「新系列」改成「差集 + 依赖」

- **做什么**：
  1. 逐文件比对 **Hangxiang v6（7 枚）** 与我方 9 枚，产出一张覆盖表（`csiphy` / `csid-980` / `vfe-gen4` / `dtsi` / binding）。
  2. 只把**他确实没有**的块重投，cover 写 `Depends-on: <v6 msgid>`；R3 改为对 **Bryan series 1196135** 的后续增量（`sm8750 frame_sync_en` + csid-980 钩子）。
  3. 把 SKEW_CAL 段改成「inert + 厂商值」表述（删除「A/B 无可测差异」作为论据）。
- **需要设备**：**不需要**（纯主机 + 只读 API）。
- **判别判据**：覆盖表若显示「我方 9 枚中有 ≥6 枚被 v6 完全覆盖」⇒ 撤回/不发，只发 3 块 delta；
  若 ≤2 枚被覆盖 ⇒ 说明我方仍有独立价值，按 delta 形态投。
- **预计成本**：0.5 人日（含写 delta cover）。
- **失败副作用**：无（只读 + 文档）。风险仅在「发得太快」——重复投递已经在 10-28 造成过一次 `superseded` 噪声。

### R3（G2/G3 口径）用一次取证同时给 PI 定档、给 Steam 定路线

- **做什么**：
  1. 容器内装一个 PI 检查器 APK，取 `BASIC/DEVICE/STRONG` 三档回包 + 记录 `ro.build.fingerprint`/`ro.build.tags`/`ro.product.first_api_level`；
  2. 在同一台设备上试 **arm64 Steam**（Canonical arm64 snap 或 ROCKNIX/steamrt 包）+ `FEX-2610`，跑一个 Frame-verified 标题；
     记录客户端启动时间、能否进游戏、帧率。
- **需要设备**：是（两条都要联网/上行）。
- **判别判据**：
  - PI：三档全 false（尤其 BASIC=false）⇒ **G2 打分定档「PI 不可达」并停止投入**；仅 BASIC=true ⇒ 目标降为「BASIC-only」。
  - Steam：客户端能起且一个 verified 标题进游戏 ⇒ G3 从「PoC」抬到「可玩（限定标题）」；起不来 ⇒ 记录失败点（缺 32-bit 库 / Vulkan / FEX 版本），Box64 备胎。
- **预计成本**：取证 0.5–1 h；Steam 路径 2–4 h（含下载与依赖）。
- **失败副作用**：只装用户态包/APK，占磁盘，可卸；不写分区、不改内核。

---

## §5 明确留白 / 未证实（不猜）

| 项 | 状态 | 说明 |
|---|---|---|
| 联想 ABL 对 `fastboot boot` 载荷的 size/地址/签名上限 | 未证实 | 全网 0 资料；只能自测（R1 步骤 1） |
| 我方 10-05 出字件与 11-01 重建件之间的**唯一**因果变量 | 未证实 | 已知差异至少 3 项（header 版本、配置、UFSDxe 来源），未做单变量 |
| `0x54` SKEW_CAL 是否曾是「有意打开 skew cal」 | 未证实 | 代码里 SKEW_CAL 被跳过；本地树单一 squash 提交（`ba28ec16f0`），无历史可查 |
| Hangxiang v6 是否已在 linux-next/媒体树排队 | 未证实 | patchwork state `new`；未见 v7 |
| Waydroid 过 DEVICE 的任何可复现证据 | 未证实 | 只有 Telegram 级来源 + 闭源「Playstrong」 |
| SM8750 + EUD + OpenOCD 成功记录 | 未证实 | 依旧 0 条公开记录（`reports/uefi-eud-feasibility-20261101.md` §3） |
| Mu 设备包是否有人在 y700g4 上真上机 | 未证实 | 仅我方 issue #12；仓库无 CI/无其他报告 |

---

## §6 附录：本次一手来源清单（共 22 条，抓取 2026-11-02）

**代码 / 提交（可直接复核）**
1. <https://git.kernel.org/torvalds/c/80dd5911cb> —— `drm/msm/dsi: Add support for SM8750`
2. <https://git.kernel.org/torvalds/c/2482c6f93a> —— `drm/msm/dsi: Add support for Kaanapali`
3. <https://raw.githubusercontent.com/torvalds/linux/master/drivers/media/platform/qcom/camss/camss-csiphy-3ph-1-0.c> —— `CSIPHY_SKEW_CAL: continue` 在 1099–1100；x1e80100 的 `0x00/0xBD/0x7F` 在 833–834；无 `lane_regs_2_4_0`/`CAMSS_8750`
4. <https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/msm/dsi/dsi_cfg.c> / `dsi_cfg.h` —— `kaanapali_dsi_cfg`、`msm_dsi_6g_v2_9_host_ops`、`struct msm_dsi_config`
5. <https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/tools/package_stage0.py> —— `gzip.compress(shim+fd)+dtb`（48–49 行）
6. <https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/devel/boot/combined-boot.md> —— 只改 `kernel_size`，正常 boot 路径整段加载
7. <https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/user/temporary-boot.md> —— `OKAY ≠ 执行`，判据 = 新 fastboot 设备
8. <https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/user/fastboot.md> —— `oem ramlog`/`oem screenshot`/`fetch`
9. <https://github.com/sunflower2333/mu_wide_platforms/issues/12> —— 本机 UFS 定性「Link State Sleep」+「USB ACM Gadget」建议
10. <https://github.com/Project-Silicium/Mu-Silicium/issues/2163> —— 72 B `wfi` stub 实测表（执行 ≠ 可见）
11. <https://github.com/xiaomi-pad-8-pro-development/android_device_xiaomi_piano-uefi> `docs/DETAILS.md` —— `oem dump`/`boot app.efi`
12. `mu_wide_platforms` tree（29 557 条）—— `UsbfnDwc3Dxe`/`UsbDeviceDxe` 在，`UsbSerial*` 不在
13. `patches/upstream/m4-camss-v2-20261031/v2-0000-cover-letter.patch`（本仓）—— 我方已知「SM8750 camss 在 Hangxiang 手上」

**patchwork API（msgid 可回溯到 lore）**
14. <https://patchwork.kernel.org/api/1.0/series/1196135/> —— Bryan `[00/14] Add SOF/EOF sequence logic`（2026-10-29）
15. <https://patchwork.kernel.org/api/1.0/series/1131654/> —— Hangxiang `[v6 0/7] media: qcom: camss: Add SM8750 support`（2026-07-21）
16. <https://patchwork.kernel.org/api/1.0/patches/14920898/> —— 我方 `[v2 8/9]`（2026-10-28，msgid `20261028093003.722745-9-…`）
17. <https://patchwork.freedesktop.org/patch/659619/> —— SM8750 display v7 系列中的 DSI 那枚

**G2/G3**
18. <https://github.com/osm0sis/PlayIntegrityFork> README（Zygisk 依赖 + A13+ 需 locked bootloader + 硬件背书）
19. <https://github.com/waydroid/waydroid/issues/1858> —— 维护者「not a Google verified device」
20. <https://github.com/waydroid/waydroid/issues/182> —— Magisk/SafetyNet issue 仍 open
21. <https://github.com/5ec1cff/TrickyStore> README —— TEE broken 回落 generate 模式
22. <https://interfacinglinux.com/2026/09/20/steams-unofficially-official-arm-client-for-linux/> +
    <https://www.techpowerup.com/353418/valve-confirms-steam-for-linux-isnt-officially-supported-on-arm-chips> +
    `gh api repos/FEX-Emu/FEX/releases/latest`（FEX-2610）

DONE
