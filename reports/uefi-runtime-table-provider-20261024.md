# UFSDxe「运行时表提供者」溯源报告（2026-10-24）

> 只读主机侧取证。目标：定位向厂商 UFSDxe 注册「带 vtable 服务对象」的 DXE 模块，
> 判断注入机制，对照 Mu Kaanapali 构建是否存在该提供者，并给出最小验证实验。
> 证据对象：`reports/artifacts/uefi-dxe-20261024/vendor-dxe-fv.bin`（4247560 B）、
> `vendor-UFSDxe.efi`（151552 B，sha256 fa561bf1…）、59 模块清单 `modules.tsv`。
> 59 个 PE32 本次重新抽取到 `/tmp/dxefv2/`（`scripts/ffs-extract.py`，/tmp/dxefv 已被清）。

## 0. 结论速览

1. **编排者原判断需要修正**：UFSDxe 的 0x89a4 不是「外部服务对象注册点」，而是标准的
   `UefiBootServicesTableLib` 构造函数；0x6cc8 是 `gBS->AllocatePool` 包装（type=4）。
   0x228c8/0x228d0/0x228d8 三个全局 = gImageHandle / gST / gBS。
2. **UFSDxe 的真实外部依赖是若干 DXE 协议**（LocateProtocol 消费方），提供者（安装方）在
   同一 FV 内全部找到，模块自报名 + FILE_GUID 双重确认：
   - **NpaDxe = cb29f4d1（77824 B）**，gNpaProtocolGuid = `79D6C870-725E-489E-A0A1-27E7A5D0CB35`
   - **ScmDxe = 4b4973ee（53248 B）**，gQcomScmProtocolGuid = `B5062BE7-170B-4A32-BE21-689262FF4399`
   - **HWIODxe = af9763a2（32768 B）**，GUID `D2B2B828-0826-48A7-B3DF-983C006024F0`
3. **机制**：三者均为标准 DXE 驱动，入口处 `InstallProtocolInterface / InstallMultipleProtocolInterfaces`
   发布协议；UFSDxe 运行时 `LocateProtocol`（gBS+0x140）取回「带 vtable 的接口对象」。
   不是 HOB、不是 PE 导出符号、不是构造期外部注入。
4. **Mu Kaanapali（oneplus-plk110）构建里提供者齐全**：DXE.inc 明确包含 `NpaDxe.inf`、
   `HWIODxe.inf`、`DALSYSDxe.inf`、`TzDxe/ScmDxeCompat.inf`；FILE_GUID 与厂商 FV 模块逐一相同
   （NpaDxe=CB29F4D1…、ScmDxeCompat=4B4973EE…、HWIODxe=AF9763A2…）。
   UFSDxe 本身（FILE_GUID 0D35CD8E-97EA-4F9A-96AF-0F0D89F76567）也在
   `PatchedBinaries/UFSDxe.inf` 打包，且其 depex=0x0608（TRUE），顺序由 APRIORI.inc 保证
   （NpaDxe 在 APRIORI 第 33 行、UFSDxe 在第 70 行）。
5. 因此「Mu 缺提供者导致 issue #12」的假设**基本排除**；更值得怀疑的是
   **Mu 的 UFSDxe.efi（159744 B，BOOT.MXF.2.5.3 KaanapaliLAA 26310 构建）与本机厂商 FV 里
   的 UFSDxe（151552 B）不是同一构建**——最小实验应做 UFSDxe 二进制对换，见 §5。

## 1. 0x1230 的调用者与 UFSDxe 侧证据（含前提修正）

UFSDxe 内部 `bl 0x1230` 唯一调用点在 0x1148：

```
$ aarch64-linux-gnu-objdump -D -b binary -m aarch64 vendor-UFSDxe.efi | grep -n 'bl\s+0x1230'
162:    118c:	94000029 	bl	0x1230
    1184:	aa1403e0 	mov	x0, x20
    1188:	aa1303e1 	mov	x1, x19
    118c:	94000029 	bl	0x1230
```

0x1230 原样把 (x0,x1) 传给 0x89a4：

```
    1244:	aa0003f4 	mov	x20, x0
    1248:	94001dd7 	bl	0x89a4
```

**关键证据 1**：0x89a4 = UefiBootServicesTableLib 构造，不是外部注册：

```
aarch64-linux-gnu-objdump -D -b binary -m aarch64 --start-address=0x89a4 --stop-address=0x8a00 …
    89b0:	f9046500 	str	x0, [x8, #2248]      // gImageHandle = x0   (0x228c8)
    89bc:	f9046901 	str	x1, [x8, #2256]      // gST = x1            (0x228d0)
    89c4:	f9403028 	ldr	x8, [x1, #96]        // SystemTable->BootServices (+0x60)
    89cc:	f9046d28 	str	x8, [x9, #2264]      // gBS                 (0x228d8)
    89d4:	aa1f03e0 	mov	x0, xzr              // return EFI_SUCCESS
```

**关键证据 2**：0x6cc8 = `gBS->AllocatePool`（gBS+0x40 = AllocatePool；w0=4=EfiBootServicesData）：

```
aarch64-linux-gnu-objdump -D -b binary -m aarch64 --start-address=0x6cc8 --stop-address=0x6d30 …
    6ce0:	52800080 	mov	w0, #0x4
    6ce4:	f9446d08 	ldr	x8, [x8, #2264]      // gBS
    6ce8:	f9402108 	ldr	x8, [x8, #64]        // gBS+0x40 = AllocatePool
    6cec:	d63f0100 	blr	x8
```

⇒ 编排者说的「带 vtable 的服务对象」实际是 **UEFI Boot Services 表本身**（gST+0x60 取出），
不是某个外部模块注册的自定义表；「外部注册给 UFSDxe」这一前提不成立。
UFSDxe 真正消费的外部对象见 §2。

## 2. 提供者模块定位（GUID + 大小 + 证据偏移）

方法：在 UFSDxe 反汇编中找 `ldr x8,[x8,#320]`（gBS+0x140=LocateProtocol）调用点，取其
`adrp 0x20000; add x0,x0,#imm` 指向的 GUID，再解析错误字符串；随后在 59 个模块中搜 GUID 字节
（bytes_le）与模块自报名字符串交叉定位安装方。

UFSDxe（0d35cd8e）.rodata GUID 表（文件偏移=RVA）：

```
0x20278 0389B776-625F-11EB-83BE-C741A913DE34   // DTBExtn（UFSEyemonGetDTData 用）
0x20288 570800BE-5485-4E42-986A-8A4FC4FDC8D4   // 用途未证实（见 §6）
0x202a8 B5062BE7-170B-4A32-BE21-689262FF4399   // QcomScm
0x202c8 D2B2B828-0826-48A7-B3DF-983C006024F0   // HWIO（见 §6 注）
0x20328 79D6C870-725E-489E-A0A1-27E7A5D0CB35   // NPA
```

NPA 消费点（GUID 0x202-328 + 错误串 "Locate NpaProtocol failed" 同函数）：

```
    1b278:	910ca000 	add	x0, x0, #0x328       // GUID @0x20328
    1b294:	f940a108 	ldr	x8, [x8, #320]       // LocateProtocol
    1b2a8:	912fb021 	add	x1, x1, #0xbec       // → 0x1fbec "Locate NpaProtocol failed:%r"
```

59 模块 GUID/字符串扫描（节选，全表见附录脚本逻辑）：

```
$ for f in /tmp/dxefv2/*-PE32.bin; do strings -n4 "$f" | grep -oE 'ScmDxe|HWIODxe|NpaDxe|ClockDxe|PmicDxe' …
4b4973ee-DXE_DRIVER-PE32.bin :: ScmDxe,
af9763a2-DXE_DRIVER-PE32.bin :: HWIODxe,
cb29f4d1-DXE_DRIVER-PE32.bin :: NpaDxe,
4db5dea6-DXE_DRIVER-PE32.bin :: ClockDxe,
5776232e-DXE_DRIVER-PE32.bin :: PmicDxe,
```

- **NpaDxe = cb29f4d1，77824 B**：含 GUID 79D6C870；模块内 DAL/NPA 框架（111 个 "npa" 字符串命中，
  全 FV 最多）；25 处 `ldr xN,[xN,#128|152]`（InstallProtocolInterface / InstallMultipleProtocolInterfaces）
  后跟 `blr`。
- **ScmDxe = 4b4973ee，53248 B**：含 GUID B5062BE7；自报 "ScmDxe"；含 InstallMultiple 调用点。
- **HWIODxe = af9763a2，32768 B**：含 GUID D2B2B828；自报 "HWIODxe"；10 处 install 型调用。

### 模块 GUID 与 Mu 侧 FILE_GUID 的对应（双重确认）

```
$ gh api repos/sunflower2333/mu_wide_platforms/contents/…/Drivers/NpaDxe/NpaDxe.inf
  FILE_GUID = CB29F4D1-7F37-4692-A416-93E82E219711      == cb29f4d1
$ …/Drivers/TzDxe/ScmDxeCompat.inf
  FILE_GUID = 4B4973EE-401B-4F36-A6A9-533DFCCDFC33      == 4b4973ee
$ …/Drivers/HWIODxe/HWIODxe.inf
  FILE_GUID = AF9763A2-033B-4109-8E17-56A98D380C92      == af9763a2
```

## 3. 注入机制分析

结论：**标准 DXE 协议注册（安装方入口处 Install(Multiple)ProtocolInterface），消费方运行时
LocateProtocol**。证据：

1. UFSDxe 侧全部为 `LocateProtocol(GUID, NULL, &out)` 模式（`ldr x8,[x8,#320]` + `blr`，共 22 处），
   拿到接口后按 `ldr x8,[x8,#offset]; blr x8` 走 vtable 调用（例：NPA 接口 +0x30/+0xC8，见 0x66a8–0x66f8）。
2. 提供者侧（NpaDxe 25 处、HWIODxe 10 处）为 install 型 gBS 调用（+0x80 / +0x98）。
3. 不是导出符号：DXE FV 内模块以 PE32 加载，无跨模块符号解析；不是 HOB：消费方显式拿的是
   LocateProtocol 返回的接口指针。
4. 顺序保障：Mu 侧 UFSDxe.depex 仅 2 字节 `06 08`（TRUE/END）——不靠 depex，靠
   `APRIORI.inc` 固定调度顺序（NpaDxe/DALSYSDxe/HWIODxe 排在 UFSDxe 之前，见 §4）。

## 4. Mu Kaanapali 构建对照

本地 sparse 仓库 `build/uefi-woa-prep/repos/5-mu_wide_platforms`（HEAD 3e1d052），单文件用 gh api 补取。

提供者**齐全**（`Platforms/KaanapaliPkg/Device/oneplus-plk110/DXE.inc`）：

```
INF …/QcomPkg/Drivers/DALSYSDxe/DALSYSDxe.inf
INF …/QcomPkg/Drivers/HWIODxe/HWIODxe.inf
INF …/QcomPkg/Drivers/NpaDxe/NpaDxe.inf
INF …/QcomPkg/Drivers/TzDxe/ScmDxeCompat.inf        (DXE.inc:88)
INF …/PatchedBinaries/UFSDxe.inf                     (DXE.inc:70)
```

`APRIORI.inc`：`DALSYSDxe → HWIODxe → NpaDxe`（33 行）均在 `PatchedBinaries/UFSDxe.inf`（70 行）之前。

`PatchedBinaries/UFSDxe.inf`（自动生成）：

```
FILE_GUID = 0D35CD8E-97EA-4F9A-96AF-0F0D89F76567   == 厂商 UFSDxe（0d35cd8e）
[Binaries.AARCH64]
   DXE_DEPEX|UFSDxe.depex|*      # 内容 06 08 = TRUE
   PE32|UFSDxe.efi|*
```

但 **两份 UFSDxe 二进制不同构建**：

```
$ sha256sum PatchedBinaries/UFSDxe.efi reports/artifacts/…/vendor-UFSDxe.efi
d08a85c9… (159744 B, Mu)   !=   fa561bf1… (151552 B, 本机 FV)
$ strings PatchedBinaries/UFSDxe.efi | grep BOOT.MXF
/work/000e/workspace/Build_S_BP/26310/code/source/msm_amss/BOOT.MXF.2.5.3/boot_images/
Build/KaanapaliLAA/Core/RELEASE_CLANG180LINUX/AARCH64/QcomPkg/Drivers/UFSDxe/UFSDxe/DEBUG/UFSDxe.dll
```

Mu UFSDxe 与厂商 UFSDxe 的协议依赖 GUID 集完全一致（NPA/SCM/HWIO/DTBExtn/0x20288 均在，
仅整体 +0x2000 偏移），说明两者是同一驱动的不同代构建。
⇒ **提供者不是 Mu Kaanapali 的缺口**；issue #12 的「firmware version related」更可能出在
UFSDxe 构建代次 / 其依赖的时钟/NPA 资源树或 DTB 数据差异上。

## 5. 最小验证实验建议（不重编）

前提：所有实验用 `fastboot boot <img>`（不刷写、可重启回退）。

**实验 A（优先）：把 Mu 的 UFSDxe 换成与本机厂商 FV 同源的 UFSDxe。**
1. 取 `reports/artifacts/uefi-dxe-20261024/vendor-UFSDxe.efi`（即 FV 里 0d35cd8e PE32）。
2. 用 `GenFfs`/`GenSec`（主机工具，不算重编）把该 PE32 + UI="UFSDxe" + depex(06 08) 重新包成
   FFS FILE（FILE_GUID 保持 0D35CD8E-97EA-4F9A-96AF-0F0D89F76567），替换 Mu 构建产物
   `FVMAIN_COMPACT` 中的对应 FFS 文件（可先对未压缩 FvMain 做 FFS 级替换再重新压缩，或直接
   用 Mu 的 PatchedBinaries 路径：把 `PatchedBinaries/UFSDxe.efi` 换成厂商 PE32 后用 mu_fdf 走
   一次只做 FV 组装的构建目标——FDF 组装不触碰 C 代码编译）。
3. 打包文件清单：Mu `FVMAIN_COMPACT`（其余不动）+ 替换后的 UFSDxe FFS。
4. 判据：串口/uart log 中 UFSDxe 是否再报 "firmware version related" 类错误；
   `fastboot oem`/BlockIo 是否出现 UFS 设备；对比换前换后日志行号。
5. 风险：厂商 UFSDxe 期望的 NPA/HWIO 接口代次与 Mu 提供者（同为 26310 代）不匹配 → Locate 成功但
   vtable 调用返回错误或挂死；故实验前确认串口可用，并设 60 s 超时。

**实验 B（对照）：只换提供者。** 把 Mu 的 NpaDxe/HWIODxe/ScmDxeCompat 换成厂商 FV 的
cb29f4d1/af9763a2/4b4973ee PE32，保留 Mu UFSDxe。若 B 修复而 A 不修复，则问题在提供者代次；
若 A 修复而 B 不修复，问题在 UFSDxe 本身。
风险更高：NPA/DAL 资源树初始化失败可能拖垮整个 DXE 调度（APRIORI 顺序敏感），建议只在 A 无效后做。

**实验 C（零改动对照）**：直接 `fastboot boot` 现有 Mu 产物，抓取 UFSDxe 失败的原始日志行，
与厂商原厂 UEFI 的 UFS 初始化日志逐行比对，确认报错来自 UFSDxe 还是其上游（Clock/Pmic/DTB）。

## 6. 未证实

- `570800BE-5485-4E42-986A-8A4FC4FDC8D4` 的协议名（UFSDxe 0x3e58 处使用，调用 vtable+0x20，
  传入 fourcc "PUS4"）；仅在 UFSDxe 一个模块中出现，提供者可能不在本 DXE FV（或在数据段以
  其他方式注册）。
- `D2B2B828-0826-48A7-B3DF-983C006024F0` = gQcomHWIOProtocolGuid 的等号（推断依据：UFSDxe
  含 "ERROR: Failed to locate HWIO Protocol" 字符串，且 HWIODxe(af9763a2) 含该 GUID；未逐字节
  对照 QC 头文件）。
- issue #12 的根因：本报告只排除了「提供者缺失」假设并指出 UFSDxe 构建代次差异这一候选，
  未拿到设备日志验证。
- 0x1148（0x1230 的调用者）的完整语义：看起来是带版本/长度检查（[x19+8] 与 [0x1b000+1056] 比较）
  的分发包装，未逐条反推。
- B5062BE7、D2B2B828 两个 GUID 出现在全部 59 个模块中（疑为共享 GUID 库表常驻），未深究原因。

## 附录：方法与命令

- 反汇编：`aarch64-linux-gnu-objdump -D -b binary -m aarch64 [--start-address/--stop-address] <file>`
- 重抽取：`python3 scripts/ffs-extract.py reports/artifacts/uefi-dxe-20261024/vendor-dxe-fv.bin --out /tmp/dxefv2`（59 个 PE32）
- GUID 交叉扫描：python3 + `uuid.UUID(bytes_le=…)`，在 59 个 PE32 中搜 GUID 字节；字符串用
  `strings -n4/-n5`；安装调用用「`ldr xN,[xN,#128|152]` 前窗内 adrp 页 + add imm → 数据段 GUID 匹配」扫描。
- Mu 侧：本地 sparse（Platforms/KaanapaliPkg/Device/oneplus-plk110/ 的 DXE.inc、APRIORI.inc、
  PatchedBinaries/*），远端单文件 `gh api repos/sunflower2333/mu_wide_platforms/contents/<path>`。
