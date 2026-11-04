# L2：小米系/第三方 SM8750 UEFI 自研驱动知识吸收

> 只读调研 lane，交付时间 2026-11-04/05。所有结论带证据（文件:行 / 命令+输出 / URL）。

## A. 本地副本盘点（路径/commit/大小/许可证，缺什么）

| 资产 | 本地路径 | commit / 日期 | 大小 | 许可证 | 状态 |
|---|---|---|---|---|---|
| SunUEFI (piano) | `external/ext-repos/sunuefi` | `afe922bc0d9f` 2026-10-28 | 165M | BSD-2-Clause-Patent（文件级声明，`LICENSE.md`） | ✅ 已有，较新 |
| Mu-Silicium Pakala（我们自建树） | `build/uefi-woa-prep/repos/7-mu-lenovo` | `6b6ac42a7edc` 2026-10-05 | 5.6G | BSD-2-Clause-Patent 系 | ✅ 已有 |
| upstream-mu-silicium 参考 | `reference/upstream-mu-silicium` | `5f6bdcf45b72` 2026-11-04 | **20K（仅 stub：README + dodge UFSDxe.inf + binaries 说明）** | — | ⚠️ 只是占位，不是完整树 |
| UniXNU-dada（小米15/SM8750） | **未 clone**（仅 4 个补丁 vendored 于 `patches/uefi/20261103-v4header/`） | 上游 pushed 2026-10-27 | GitHub API `size=607` KB | NOASSERTION | ❌ 缺；获取：`git clone --depth 1 https://github.com/7Night-kqx/UniXNU-dada`，预估 <5 MB |
| UniXNU-Pagani_SM8750（一加13T） | 未 clone | pushed 2026-11-02 | API `size=10785` KB ≈10.8 MB | NOASSERTION | ❌ 缺；浅克隆预估 <50 MB，含 oneplus13tPkg 完整 Mu-Silicium 派生结构 |
| UniXNU-erhai（一加 Pad 2 Pro/SM8750P，同芯片家族） | 未 clone | 2026-10-22 | 未见 API 数据 | — | ❌ 缺；次要，`reports/uefi-external-scan-20261103.md:30-32` |

补充：SunUEFI 本地副本里还包含 `upstream/Mu-Silicium` 工作区引用（`tools/build_product.sh:9-11` 依赖 `.firmware-workspace.json`/`upstream/` 子模块，见 `docs/devel/uefi-core.md` §固件构建与组装），即它本身就是 Mu-Silicium 衍生（`piano.dsc:35` `!include PakalaPkg/PakalaPkg.dsc.inc`），与我们 7-mu-lenovo 同族。证据：`git -C external/ext-repos/sunuefi log -1`、`gh api repos/7Night-kqx/UniXNU-dada`。

## B. SunUEFI UFS 只读栈：文件清单/层次/依赖/与 Mu Pakala UFSDxe 差异/最小移植步骤

### B.1 架构定性（先说结论）

SunUEFI 的 UFS 栈**不是** EDK2 MdeModulePkg UfsPassThru，也不是厂商 UFSDxe 二进制，而是**手写 HCI 寄存器级只读栈**（`uefi/core/PianoUfs*.c/.h`，BSD-2-Clause-Patent），以 `prepare_product.py` 生成的 `pianoProductPkg` 内一个扁平 DXE 模块编译（`tools/prepare_product.py:27-28` 源清单：`PianoUfsProbe.c, PianoUfsReadOnlyDma.c, PianoUfsDmaLayout.c, PianoGpt.c, PianoReadOnlyBlock.c, PianoUfsProductVolume.c, PianoUfsBoundedLayout.c`）。HCI 基址硬编码 `0x01D84000`（`PianoUfsProbe.c:12`、`PianoUfsReadOnlyDma.c:98`）。

### B.2 层次（自下而上）

1. **Probe/时钟层** `PianoUfsProbe.c`：只做寄存器/时钟探测与释放（`Protocol/EFIClock.h`，厂商 Stage0 提供的 clock protocol），明确注释「No UIC command, DMA, LUN or disk I/O」。
2. **链路层（inherited link）** `PianoUfsReadOnlyDma.c: LinkReady()`（约 :186-207）：**继承 XBL/ABL 已初始化好的 UFS 链路**，仅读 M-PHY TX FSM、按需退出 Hibern8（`SUNUEFI_UFS_HIBERN8_EXIT`），显式注释「before using the inherited link」「Preserve the inherited link/PHY/HCE」(:1061)。没有完整 UIC/DME 初始化序列——它假设原厂 bootloader 已把 UFS 带到工作态。
3. **SMMU/DMA 层** `PianoOwnedSmmu.c` + `PianoIoPageTable.c` + `PianoUfsDmaLayout.c`：自管 SMMU 上下文/页表（「Every transfer uses the shared allocator, owned SMMU and cache lifecycle」，:3），带 fault 快照比对（`PianoUfsProductBindings.inc:23-43`）。**需要 SMMU 管理，但是自己实现，不依赖厂商 HALIOMMU 之外的东西**（HALIOMMU.efi 仍在 FDF 里，`piano.fdf:58`）。
4. **传输/SCSI 层**：直接构造 UPIU + doorbell（`SUNUEFI_UFS_UPIU` 日志 :180-184），对上以 `EFI_EXT_SCSI_PASS_THRU` 语义自洽，但实际只装 **BlockIo**（`PianoUfsReadOnlyDma.c:993` `InstallMultipleProtocolInterfaces(... gEfiBlockIoProtocolGuid ...)`）。
5. **块/GPT/文件系统层** `PianoUfsBlockIo.c`（ExtScsiPassThru→BlockIo 包装，:1-9 头注释）→ `PianoGpt.c` → `PianoReadOnlyBlock.c`（原厂分区只读保护）→ `PianoUfsProductVolume` → 可选 PianoExt4（`PianoUfsReadOnlyDma.c:7-12` 编译开关 `PIANO_UFS_PRODUCT_STORAGE`）。
6. **写保护/退出层**：`PianoUfsWriteGuard.h`（边界写）、`PianoUfsShutdown`（EBS 安全退出，`docs/devel/uefi-core.md` §安全退出）。

### B.3 依赖清单

- 需要厂商 Stage0 二进制（FDF 里的 TzDxeLA/ScmDxeCompat/HALIOMMU/SmemDxe 等，`piano.fdf:51-59`）——与 Mu-Silicium PakalaPkg 的既有依赖同源，我们树里同样有。
- 需要 `EFI_CLOCK` protocol（EFIClock.h）持有/释放 UFS 时钟域。
- **不需要**厂商 UFSDxe.efi：`grep UFSDxe piano.fdf` 无命中；UFS 完全自研。
- **需要 SMMU**，但用 PianoOwnedSmmu/PianoIoPageTable 自管（~共享 allocator + cache lifecycle）。
- **依赖原厂链路已就绪**（XBL/ABL 初始化 PHY/设备）——我们 `fastboot boot` 路径同样继承 ABL 之后的 UFS 状态，前提成立。

### B.4 与我们 Mu Pakala UFSDxe 的差异

| | SunUEFI 自研栈 | 我们 (7-mu-lenovo PakalaPkg) |
|---|---|---|
| 驱动形态 | 手写 C 源码，扁平 DXE，构建期由 prepare_product.py 拼包 | 厂商闭源 `UFSDxe.efi` 二进制 + `.depex`（`Platforms/PakalaPkg/Device/*/Binaries/QcomPkg/Drivers/UFSDxe/`，nubia/oneplus 提取） |
| UFS 初始化 | 继承 ABL 链路，只做 FSM 校验 + Hibern8 exit | 期望驱动自己完成完整初始化（含 refclk/PHY/设备 reset），depex 依赖一堆 QCOM 协议 |
| SMMU | 自管页表 + fault 断言 | 依赖厂商 HALIOMMU/闭源 IOMMU 行为（黑盒） |
| 输出协议 | BlockIo（只读为主，写按 profile 门控） | ExtScsiPassThru / BlockIo 全功能（但行为不透明） |
| 可调试性 | 每步 `SUNUEFI_UFS_*` DEBUG 日志，寄存器现值全打 | 黑盒，只能看协议是否出现 |

### B.5 最小移植步骤（以 7-mu-lenovo 为底）

1. 把 `uefi/core/` 的 UFS 子集拷入 `Platforms/PakalaPkg/`（或新建 `PakalaUfsPkg`）：`PianoUfsProbe.c/.h、PianoUfsReadOnlyDma.c/.h、PianoUfsDmaLayout.c/.h、PianoUfsBlockIo.c/.h、PianoReadOnlyBlock.c、PianoGpt.c、PianoOwnedSmmu.c/.h、PianoIoPageTable.c/.h`（`prepare_product.py:27-28` + core 目录清单为准）。
2. 写一个 `PakalaUfsDxe.inf`：`[Sources]` 列上述文件；`[Packages]` MdePkg/MdeModulePkg/ArmPkg + 本包；`[LibraryClasses]` UefiBootServicesTableLib、IoLib、DebugLib、CacheMaintenanceLib、FdtLib；`[Protocols]` gEfiBlockIoProtocolGuid、gEfiDevicePathProtocolGuid + EFIClock（来自 Stage0 ChipInfo/EFIClock 二进制的 GUID，查 `Binaries/piano/Stage0/` 对应 `.depex`）。
3. DSC：`[LibraryClasses]` 加 FdtLib 路径；`[Components]` 加 `PakalaUfsPkg/PakalaUfsDxe.inf`。
4. FDF：内层 FV `INF PakalaUfsPkg/PakalaUfsDxe.inf`，同时**注释掉/不引用**厂商 UFSDxe INF 行，避免双驱动抢 HCI。
5. 确认 DTB 里 UFS 节点 iommus/smmu 匹配 PianoOwnedSmmu 的解析（`PianoUfsProbe.c:60` 期望 `iommus` 属性 12 字节）。
6. 风险点：piano 的 HCI 基址 0x01D84000 需与 SM8750(P) elden 的 UFS_MEM_MAP 核对（DT `ufshc` reg）；时钟 ID 表需按 elden 的 clock plan 调整。

## C. UniXNU-dada boot image v3/v4 header + BootShim header-size 补丁逐字段分析

（dada 的补丁已 vendored 到本仓 `patches/uefi/20261103-v4header/`，逐字段对照如下，无需 clone 即可核。）

### C.1 `unixnu-bootimg-header-v4.patch`（改 `scripts/unixnu/bootimg.py` 的 `verify()`）

逐字段：
- **offset 0-7 magic `ANDROID!`**：不变。
- **v≥3 分支**：v3/v4 头**没有 kernel/ramdisk load addresses、没有 tags**，页大小恒 4096；区分 v3/v4 用 **offset 20 的 header_size**（v3=1580, v4=1584，补丁 hunk 原文 `header_size != (1584 if version == 4 else 1580)`）。v4 头比 v3 多 4 字节（reserved/签名相关），且 v4 在 ramdisk 后追加 **4 KiB 空 boot signature block**（补丁：`signature = start + align(ramdisk_size, page)`，要求全零 4096）。
- **kernel/ramdisk 尺寸**：v≥3 从 offset 8 起直接读两个 `uint32`（`struct.unpack_from('<II', data, 8)`），跳过 v0-v2 的 kernel_address 字段。
- **页对齐修正**：旧代码 `start = page * (1 + -(-kernel_size // page))` 对 v0-v2 正确但写法繁琐；新代码 `start = page + align(kernel_size, page)` 等价化简——**这一条就是 kernel 数据区页对齐起点**，ramdisk 从其后对齐页开始。
- 解决的问题：小米 15 ABL 接受 **Android boot image v4** 头（SM8750 出厂即 v4 世代），用 v3/v4 头可携带更大的 kernel 分区（无 second/tags 布局约束），供 BootShim(112B)+gzip FV+DTB 的 2,195,456 B 组合 payload 过 ABL 校验（`reports/uefi-external-scan-20261103.md:41-43`，README 称 host 侧已验证、`fastboot boot` 未真机跑）。

### C.2 `mu-silicium-bootshim-header-size.patch`（BootShim.S）

```diff
-  .quad FD_SIZE         /* Image Size */
+  .quad FD_SIZE + (_Payload - _Head)  /* Image Size: the shim plus the firmware volume */
```

- **offset 16 image_size** 必须覆盖 **shim 头 + FD** 全长；原版只写 FD_SIZE，ABL 按 image_size 计算 kernel 总量/校验时，尾部 shim 长度未计入——header 声明与实际载荷长度不一致。
- 与 C.1 配套：v4 头对长度/签名的校验更敏感，所以 image_size 必须如实。

### C.3 与我们 `patches/uefi/20261104-fixcopylen/0001-bootshim-copy-length-from-build-constants.patch` 的关系

- **同源问题、不同字段**：fixcopylen 修的是 shim **执行时**把被 repack 改写的 offset 8（text_offset）/offset 16（image_size）误当拷贝长度导致「只拷 1 MiB」（patch 注释引 `PITFALLS #497`）；dada 的 header-size patch 修的是 **打包声明**（offset 16 应含 shim+FD）。两者互补：**dada 的做法应在打包侧生效（build_boot_repack 把 image_size 写成真实全长），我们的做法在执行侧免疫 repack 改写**——同时采纳不冲突：打包侧如实写全长度（过 ABL），执行侧用构建期常量拷贝（`UEFI_BASE/UEFI_SIZE/UEFI_BASE+UEFI_SIZE` 三个字面量池，fixcopylen 补丁 `_UefiBaseLit/_UefiSizeLit/_UefiEndLit`）。
- fixcopylen 还多做了 dada patch 没有的：`dc civac` 扫 4 MiB + `ic iallu`（clean to PoC）。

## D. 我们当前卡点在他们实现里如何被绕开

当前死点（`reports/uefi-payload-execution-20261104.md`）：PrePi 全走完、DxeCore 已交接，死点在 **M2→M3 之间，嫌疑 = shim 拷贝后的 `dc civac` 4 MiB cache 维护循环**（§0 结论 6，§3 变体 7 `nocivac` 待发）。

**SunUEFI BootShim 的硬证据**（`external/ext-repos/sunuefi/uefi/handoff/bootshim/BootShim.S`）：
- 拷贝循环 `.Lcopy`（:81-86）：`ldp/stp` 16B 步进、`subs x6, x6, #16`，**长度直接用 `ldr x6, =FD_SIZE` 构建期字面量**（:80）——和我们 fixcopylen 的「构建期常量长度」修法一致（同源独立发现）。
- 拷完后**没有任何对 FD 的 `dc civac`/clean-to-PoC**：只有 `dsb sy` + CRC 自检 + `br x5` 跳 `FD_BASE`（:99-106）。即：**在他们的 ABL→shim→FD 路径上，目的地址的 cache 维护被证明可以整段省略且能进 DxeCore**（piano 实机已跑通 UEFI/内核/桌面，README 支持的硬件表）。
- 唯一的 cache 维护是 RamLog 环形缓冲的 `WriteBackInvalidateDataCacheRange`（`RamLog.c:33-40`），范围仅 log 区，非 FD。
- 头字段：他们的 shim 头 `text_offset=FD_BASE, image_size=FD_SIZE`（:4-9），且他们的流程里 shim 由**合体 BOOT/原厂内核入口改向**加载，与 ABL fastboot boot 的 header 语义略有差异——但「拷完不刷 cache 直接 br」这个点对 nocivac 变体是直接支持证据。

关于「内层 FV 解压失败」：SunUEFI 的 FDF 同样是 `GUIDED EE4E5898-...（LZMA）PROCESSING_REQUIRED` 包 FVMAIN（`piano.fdf:19-20`），DxeCore 能解——说明 LZMA 内层 FV 解压本身与芯片无关，我们的观察（PrePi `DecompressFirstFv`/`LoadDxeCoreFromFv` 已返回，payload 报告 §1 P10/P11）也证实解压不是死点，无需另修。

> 注：SunUEFI 能进 DxeCore 还依赖完整的 Stage0 厂商二进制集（TzDxeLA/HALIOMMU/ChipInfo 等，`piano.fdf:51-59`）+ APRIORI 里 DxeMain 优先——这与我们 7-mu-lenovo 的二进制来源相同族，说明二进制集合本身不是卡点。

## E. 第二路线 vs 继续修 Mu Pakala：工作量/风险对比 + 推荐顺序

| 维度 | 路线 1：继续修 BootShim→Mu Pakala（现线） | 路线 2：换 SunUEFI 自研 UFS 栈 |
|---|---|---|
| 前置条件 | 零（DxeCore 交接已证，`payload-execution` §1） | 需先把 DxeCore 跑起来（路线 1 的目标本身就是路线 2 的前置） |
| 下一步工作量 | 发 `nocivac` 变体一发（变体已构建 `out/uefi-20261104-nocivac.img daf8d891`，报告 §3 #7 待发）；SunUEFI 证据支持去掉整个 civac 扫描 | DxeCore 通了之后：拷 ~10 个 .c/.h + 写 1 个 INF + DSC/FDF 三行 + 核对 HCI 基址/时钟 ID（B.5）；预估 1-2 天 |
| 不确定性 | 低：SunUEFI BootShim 同路径无 cache 维护可跑通（D 节证据）；若 nocivac 仍死，则死点前移到 PrePi/内存阶段（另有 1.9GB 0xFF 疑点，§4） | 中：piano(平板) 与 elden(平板，SM8750P) HCI 时钟树/字号可能有差；继承链路假设在 `fastboot boot` 下未在 elden 验证过 |
| 风险 | 不动存储，零变砖风险 | 只动 UFS 驱动侧，只读栈 + 写门控，风险低；但依赖原厂链路，若 ABL 把 UFS 置于不同状态需回补初始化 |
| 收益上限 | 只解决「能启动」 | 顺带拿到可调试的存储栈（每步 SUNUEFI_UFS_* 日志）+ 原厂分区只读保护，摆脱闭源 UFSDxe 黑盒 |

**推荐顺序**：
1. **立即**：发 `nocivac` 变体（已构建待发，零新工作）。SunUEFI BootShim 是同路径无 cache 维护成功的直接先例。
2. DxeCore 进了之后：**先不改 UFS**——用现有厂商 UFSDxe 走通启动链，确认问题域只剩 UFS。
3. 若厂商 UFSDxe 在 elden 上不可用/depex 不满足：再引入 SunUEFI 自研只读栈（B.5 步骤），先只读（BlockIO+GPT+日志），验证后再考虑写 profile。同时浅克隆 UniXNU-dada 与 UniXNU-Pagani_SM8750 作参考（A 节，两仓合计 <60 MB）。

## 未完成/卡点

- UniXNU-dada / UniXNU-Pagani_SM8750 未 clone（本次只读+时限约束；获取方式与体积见 A 节）。dada 仓 README 声称的「UFS works in Mu-Silicium」未核对其 UFS 驱动来源（可能是 SunUEFI 同源或另一套，A/B 节结论基于 SunUEFI 本地副本，dada 侧未验证）。
- SunUEFI UFS 栈在 elden（SM8750P）上的 HCI 基址/时钟 ID 差异未核对（需查 elden DT `ufshc` reg 与 SunUEFI 硬编码 `0x01D84000` 对照）。
- `nocivac` 变体结果未知（待设备侧发射，本 lane 无上机权限）。
