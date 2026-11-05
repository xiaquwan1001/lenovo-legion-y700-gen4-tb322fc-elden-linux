# 2026-11-03 · Project-SunUEFI（piano / SM8750）可复用资产盘点

- **日期**：2026-11-03
- **pi 会话 id**：`01a1a1ad-de7c-72ea-81b7-6a84ed1a0285`
- **主题**：把 `slwyts/Project-SunUEFI`（小米平板 8 Pro = `piano` = SM8750，与我们同芯片）拆成「A 直接可用 / B 内核补丁对照 / C 用户态可借 / D 不要搬」，判据 = 对我们现有卡点与已有补丁的增量，不按仓库热度
- **结论（一句话）**：**三件真增量**——① **UEFI 自研 UFS 只读栈**（`uefi/core/PianoUfsReadOnlyDma.c` 1138 行 + 只读 BlockIO/PartitionInfo/SFS，**完全不依赖厂商 `UFSDxe`**，实机 133 分区 / 139 句柄 / 7 个只读 SFS 卷）⇒ 为 G1-29 提供**第二条路线**（我们现路线 = 赌 dodge 的 `UFSDxe.patched.efi` 黑盒）；② **合体 BOOT 全套**（bootselect + BootShim + 2×4 KiB 请求页 + `RSTRv1` 无损恢复目录 + 无损 repack/restore 工具）⇒ 直接答「96 MiB boot.img + 必须保留 Android」；③ **UEFI 阶段屏上可见性方法**（延后原厂 ClockDxe CESTA/media + DCD 初始化、GOP 色块检查点、在 LoadImage 副本零填充区放 trampoline 给厂商二进制插桩）⇒ 正对我们「已进 DXE、屏上无输出」的下一步。另有两条**我们已独立踩过、他们文档逐字印证**的硬事实（ABL 按 `kernel_size` 整段拷贝；MMU-off 下 8 字节非对齐读必炸、须 `-mstrict-align`）
- **证据指针**：`external/ext-repos/sunuefi`（`afe922b`，2026-10-28，与 zip 版 main 同日；本次核对用 `~/下载/Project-SunUEFI-main.zip` 解包件，100 MB）；逐条证据均在下方标 `file:line`/文件名
- ★SSOT 待并入：无（已并入 RESOURCES/README.md §1.6，2026-11-05）

---

## 0. 边界与口径

- **只读静态分析**，未 clone（用用户已下好的 zip）、未构建、未上机、未改任何代码或设备。
- 判据统一两问：**① 对我们某个具体卡点是否形成新选项？② 我们是否已有等价实现？** 第二条用「`patches/` 里有没有同名域补丁」双向核（见 §5）。
- 仓库版本：本地 `external/ext-repos/sunuefi` @ `afe922b`（2026-10-28），zip 版 main（push 2026-10-27）**同日**，内容一致 ⇒ **不需要重新下载**。
- 许可：`LICENSE.md` 是**逐文件**混合（BSD-2-Clause-Patent / **GPL-2.0-only** / GPL-2.0-or-later / LGPL-3.0-or-later / BSD-3-Clause），搬任何文件前按该文件 SPDX 核。

---

## 1. A 级：直接可用

### A1 ★ UEFI 自研 UFS 只读栈（G1-29 的第二条路线）

**为什么重要**：我们 11-03 的裁决是「装对树内 `PatchedBinaries/UFSDxe.efi`（`00ae059f…`）再试」（`reports/uefi-next-step-decision-20261103.md`），本质是**换黑盒二进制**，成败不可解释、失败也无法定位。SunUEFI 反过来做：**根本不加载 UFSDxe**，从寄存器层自己写。

| 文件 | 规模 | 作用 |
|---|---|---|
| `uefi/core/PianoUfsReadOnlyDma.c` | 1138 行 | UFS host（`HCI 0x01D84000`）+ UIC/UTRD + DMA bounce buffer + **owned SMMU bypass bank** + `ExitBootServices` 通知 |
| `uefi/core/PianoUfsProbe.c` | 110 行 | 控制器/时钟探测与**租约账本**：`PianoUfsStopClocksForReset()` / `PianoUfsRetainClocks()` / GDSC 释放，DEBUG 串 `SUNUEFI_UFS_RESET_GDSC`、`SUNUEFI_UFS_RESET_CLOCKS` |
| `uefi/core/PianoReadOnlyBlock.c/.h`、`PianoUfsProductVolume.c`、`PianoUfsBlockIo.c`、`PianoUfsDmaLayout.c` | ~500 行 | 自装 `gEfiBlockIoProtocolGuid` + `gEfiDevicePathProtocolGuid` + DiskIo/PartitionInfo/SFS，厂商分区一律 `EFI_WRITE_PROTECTED` |
| `uefi/core/PianoUfs{WriteTest,BoundedBlock,BoundedFileSystemTest}.c` | ~480 行 | 受控写入实验（14 MiB 窗口 + 全 gap 恢复），默认关闭 |

**实机证据**（`docs/archive/storage-usb/blockio-usb-progress.md`，逐条引用原文数字）：
- 第 57 次：6 个只读 LUN 父设备 → 标准 `DiskIoDxe`/`PartitionDxe` 连接后 **133 个 GPT 分区子设备、139 个 BlockIO 句柄**，6 份 GPT CRC 与 Android 只读对照一致，全部 `WriteBlocks` 返回 `EFI_WRITE_PROTECTED`；
- 第 67 次：加 `EnhancedFatDxe` 后识别 **7 个 UFS 文件系统卷**（1 属 LUN0、6 属 LUN4），全部 `OpenVolume/GetInfo/目录读取` 成功且 `ReadOnly=1`；
- 第 80/86 次：限定窗口可写 + `SUNTEST.BIN` 8193 B 写入/读回 + **整段 14 MiB 恢复并逐字节校验**，返回 Android 后 26 个启动分区 SHA 一致；
- 第 82 次：标准 fastboot bulk 实机验收（`1209:8750`、5000 Mb/s、`serial=SunUEFI-piano`）。

**对我们的三点价值（按可搬性排序）**：
1. **时钟/GDSC 租约与释放状态机**——我们 UFS 失败现场（`EFI_DEVICE_ERROR` / Sync Exception）最可疑的就是「所有权与释放顺序」，这份代码把每一步的成因写成了可审计账本，**即使不搬驱动也值得逐函数对照**；
2. **owned SMMU bypass bank 的建立/拆除序列**（配 `patches/linux/0001–0003` 的 smmu 观测补丁读同一类寄存器）；
3. 整套驱动本体（BSD-2 为主）——若我们决定不赌厂商 `UFSDxe`，这是唯一**已知能跑通 SM8750 UFS 的开源实现**。

> 注：`uefi/platforms/pianoPkg/native-modules.json` 只列 10 个原厂基础 DXE（`ChipInfo`/`DALSys`/`HWIODxeDriver`/`HALIOMMU`/`SmemDxe`…），**无 `UFSDxe`**；`piano.dsc` 亦无 UFS 条目 ⇒ 自研栈结论成立（已证）。

### A2 ★ 合体 BOOT 全套（96 MiB boot.img + 保留 Android）

`docs/devel/boot/combined-boot.md` + `uefi/handoff/{bootselect,bootshim,early-memory}/` + `android/native/piano-boot-repack.c`。

**机制**：原厂 GKI **留在入口原地不动**，`BOOT4` 只改 `kernel_size`；在 GKI 的 `image_size` 工作区之后依次放：
`2 × 4 KiB 请求页`（每页 64 B 记录：magic/版本/序号/目标/CRC32/APP 标识）→ `selector` + 私有栈 → `BootShim` → 产品 FD（3 MiB）→ `APPv1` → **`RSTRv1` 恢复目录**（320 B header，实例 18,368 B，只存原 BOOT page + 原 GKI header + 非零尾块）→ 对齐填充 + **unsigned AVB NONE** 元数据 + footer。
普通启动 = 直接跳原厂 `code1` 指向的 `primary_entry`，**不改代码页**，DTB/initrd/`x0–x3`/SP/DAIF 原样保留（`docs/devel/boot/reboot-request.md`）；只有请求 UEFI 才进 BootShim。

**可直接用的三件**：
- `piano-boot-repack{ probe | repack | restore | request }` 的**无损往返**设计（原文件 / 恢复件 SHA256 相等才算合格，实测 `7c444a2d…`）；
- **请求页 + 序号/CRC 双页冗余**（把「改选路线」做成数据而非重打包）；
- **Mi Recovery 优先级**：`reboot recovery` 忽略保存路线直接回原厂 GKI，且不清除已存偏好。

**两条硬事实（他们 static 核对 + 实机走通，我们已独立得出，此处为交叉印证）**：
- **ABL 按 Android header `kernel_size` 整段拷贝，不看 PE `SizeOfImage`** —— 与我们 11-04「v2 base 0 + Image 头对齐」结论一致；
- **`-mstrict-align`**：旧产物 `Be64` 被优化成 `LDR X8,[X0]`，MMU 关闭时 8 字节非对齐读 → 实测 `ESR=0x96000021 / FAR=0xB5B76634 / ELR=0xA8001428`；修法 = 编译加 `-mstrict-align`（并在 QEMU 打开 `SCTLR_EL1.A` 复现）。**我们的 selector/shim 同样跑在 MMU off，须自查同类访问**（见 §4 待办 1）。

### A3 UEFI 阶段「看不见屏」的定位法

`docs/devel/boot/uefi-display.md`（他们是同款「合体 BOOT → UEFI 白屏」）：
- 真因 = 原厂 **ClockDxe 的 CESTA/media 与 DCD 启动期初始化**，延后即可显示；
- **已否证**的假设（别重走）：把显示实例 `0x3e4b0` 的 `+0xd0` 申请数 4→0（只差 7 字节）**不够**，仍只看到 `BEFORE CLOCK`；
- `SUNUEFI_DISPLAY_DIAGNOSTIC=1`：GOP 涂色 + 阶段名（`BEFORE DRIVERS` 蓝 / `AFTER CLOCK` 绿 / `AFTER UFS` 紫 / `BEFORE SIMPLEINIT` 青）；
- `=2`：**在 `LoadImage` 拿到的驱动副本的零填充可执行区放 trampoline**，按原 BL 目标+重定位接管，包装函数原样转发 8 个整数参数 —— 给「别人的二进制」插桩的通用手法，正是我们给 `DxeMain`/`Dispatcher` 插桩同一类活；
- `docs/devel/boot/uefi-console.md`：`ConsoleScale` 4× 放大 + zh-CN HII 字形（Noto Sans CJK SC 16×19），音量键上下 / 电源键回车 / 双音量键返回。

---

## 2. B 级：内核补丁要逐条对照（不整包搬）

| SunUEFI 补丁 | 我们的对应项 | 判断 |
|---|---|---|
| `patches/linux/7.3/0023-dpu-shared-video-ctl.patch`（双 DSI 共用 CTL 每帧只 flush 一次；超时日志带 controller/interface/mask） | **无**（我们 Q28 是 `dsi_bonded_cmd_failed` 闩锁域） | ★ 值得评估：同属 bonded 双 DSI 提交路径 |
| `7.3/0019–0022`（pmic-glink altmode connector children / ucsi-glink connector children / prefer-numbered / initial usb mux） | G1-9 用 DTS `dr_mode=otg`+`usb-role-switch` 硬顶 | ★ **上游正解**，直接服务 M 系列投递 |
| `7.2.9/{0008,0025,0024,0026,0034}`（bonded slave 先停/恢复、PLL 未编程不动、DPU 先停视频管线、DSI PHY 运行时接口时钟） | 我们 `patches/m1-73-e1{,b}-pllfix.patch` 与 Q28 系列同域 | ◐ 同域不同点，值得一次逐条 diff（尤其 0008/0025 的 slave 时序） |
| `7.3/0011-fastrpc-drain-ssr-invokes.patch` | **无** | ◐ SSR 时排空在飞 invoke（我们 G1-34/相机邻域） |
| `7.3/0015-remoteproc-sm8750-cdsp-sync-memory.patch` | G1-11 CDSP 已 running，但无同步内存补丁 | ◐ 对照 |
| `patches/linux/0001–0003`（smmu-qcom 保留占用路由 / 每 master 身份回读 / 校验 live stage1） | 我们 DMA/显示取证走自研探针 | ★ 通用、可上游，价值高 |
| `7.3/0014,0018-qcomtee*`、`0016-igcv5-dither`、`0008-gem-api` | 部分已有 | ○ 低优先 |
| `7.3/0004-media.patch`（csid-980 590 行 / vfe-gen4 634 行 / isp-debug） | 我们 `patches/upstream/m4-camss-series-20261029-v3/` 已有同批并在投上游 | ✗ **不用搬** |

---

## 3. C 级：用户态 / 桌面 / G3（我们有空白）

- **`patches/gamescope/0001..0007`**：分离 render/display、背光双重调暗、SDR 颜色一致、尊重会话刷新率、触控板自然滚动、平板指针、保留输入 damage ⇒ 我们 G3 **一条 gamescope 补丁都没有**，可作第一版基线。
- **`linux/desktops/gnome/patches/mutter/`**（KMS 空 gamma 旁路 / 无 EDID 用标准色彩 profile / Wayland 触屏忽略 cancelled grab）+ `patches/gnome-settings-daemon/0001-power-optional-device-ambient-profile.patch` + `linux/desktops/gnome/power-overlay/`（自动亮度策略、logind/sleep conf、电源键 udev）。
- **`linux/bsp/**`** 服务清单与 UCM2（`Qualcomm/sm8750/Xiaomi-Pad-8-Pro`）、udev/modprobe 规则 —— 我们 OpenRC，**只作参照**。
- **`linux/userspace/piano-camera-ctl.c` + `docs/devel/hardware/camera-controls.md`**：手动 AE/AWB/AF + **按行时间换曝光**的完整推导（前摄 HTS1182/FLL2820 → 42 行 ≈ 496 µs；后摄 4352/560 MHz）。我们相机痛点是画质/首帧，这套「控制面 + 数值校验」写法可对照。
- `docs/devel/hardware/{sensors,ssc-vector,auto-brightness}.md`：libssc + SensorProxy + 自动亮度曲线（我们 SSC 已通，但缺 ambient 策略）。

---

## 4. D 级：明确不要搬 / 待办

**不要搬**：piano 专有面板/触控/传感器 DTS（NT36532、CSOT、OV32D40 vs 我们 s5kjns+g08a8、BOE）；`vendor/firmware/**` 50 MB HyperOS4 ADSP/CDSP（我们自有原厂件）；Gunyah 全套（2026-10-25 已裁决不做）；BORE/SteamOS/Nyarch 根（我们 Alpine/Mobian）；指纹（Goodix，本机无此硬件）；`7.3/0004-media`（我们已有）。

**下一步（按性价比，尚未执行）**：
1. **自查我们 selector/BootShim 的 8 字节非对齐访问**（`-mstrict-align`）—— 最便宜，可能直接解释 `dc civac` 段死点；
2. 逐函数对照 `PianoUfsProbe.c` + `PianoUfsReadOnlyDma.c` 的**时钟/GDSC 账本与 SMMU bypass**，判定我们缺的是「驱动」还是「所有权/释放顺序」（不写代码，只判定）；
3. `0023` + `7.2.9/{0008,0025}` 对我们 7.3 树做 dry `git apply`，评估 Q28 与 bonded slave 时序；`0019–0022` 评估替 G1-9 DTS hack；
4. 可选取 `patches/gamescope/` 七条做 G3 基线。

---

## 5. 我们「已有 / 没有」的现查口径（下次别重做）

```
grep -rli "<关键词>" patches/ --include=*.patch   # 判「我们是否已有同名域补丁」
ls external/ext-repos/sunuefi                     # 本地已有克隆（afe922b，2026-10-28）
```

本轮实测：`bonded` → 有（`m1-73-e1b-pllfix`、`q28-dsi-*`）；`shared-video-ctl` → **无**；`fastrpc-drain` → **无**；`gamescope` → **无自有补丁**（只在历史 worktree patch 里出现字符串）；`mutter` → **无**。
