# UEFI 补证恢复（M1/M3/M4 + E0/E1/E2 核对，2026-10-30）

> 接续 `reports/uefi-closeout-20261029.md` §2/§3 的待填部分。**纯主机、只读**：未接触设备、未刷写、未发评论/邮件、
> 未改 SSOT（`TASKS`/`INDEX`/`PITFALLS`/`versions/`）、未动既有中断产物、未做全量构建、未联网下载。
> 单写者：本文件为本 lane 唯一写入。路线可行性不重开论证（维持 `TASKS` §4 N1 / §5 Q25 搁置口径）。
> 证据根：`reports/artifacts/uefi-dxe-20261024/`、`reports/artifacts/uefi-e0e1-20261028/`、
> `build/uefi-woa-prep/repos/7-mu-lenovo/`（只读）、`/home/xuqianhui/ext-repos/mu`（只读）。

## §0 结论（数字先行）

| 项 | 状态 | 关键数字 |
|---|---|---|
| **M1** `ctx+4` 生产者 | **收窄，未定位到指令级写入者** | UFSDxe 内 **0 处** `bl/b 0x12e30`；该地址只在 `0x12de8/0x12df0` 被取成回调指针注册；`0x12e30` = **GPTListener 派发器**，`0x402` → `GPTListenerReadSectors` |
| **M2** `D6ABB030` 是否在 MemMap | **需上机，本轮不做** | 主机侧无 `MemMap`/`gEfiDebugImageInfoTableGuid` 转储 |
| **M3** dodge 三补丁点语义 | **完成（相对仓库内 `PatchedBinaries`）** | 差异 **38 B**：3 段代码（8+16+8 B）+ 6 B build 路径串；第三段 = **整体 stub 掉 UFS IOMMU(domain create/configure/attach)** |
| **M4** ConfigurationMap 条目 | **完成且纠正对象** | elden 自己的 `PlatformConfigurationMapLib.c` **62 条启用**（另有 8 条注释掉）；`dodgePkg` 那份是 **41 条**——上一轮引用的对象不是本机平台 |
| **E0/E1** | **产物核对完成（sha 全部重算一致）** | E0 img `987bcde9…a16f2` / E1 img `1ae201c2…96540`；payload 位于 **文件偏移 `0x1000`**（page size 4096），`img[0x1000:]+==e{0,1}-bootpayload.bin` **True** |
| **E2** | **无产物**（10-28 只做可行性、未实现） | 目录内无 E2 镜像/源码，与 10-28 报告 §4 口径一致 |

## §1 M1 —— `ctx+4` 生产者（对应 L29）

工具：`llvm-objdump 21.1.8 -d --triple=aarch64`，输入 `reports/artifacts/uefi-dxe-20261024/vendor-UFSDxe.efi`
（151 552 B，sha256 `fa561bf11eb18f142b128f0335973f6c4a8d0241747ea581d5b3a56d601878d2`）。

### 1.1 已证：`0x12e30` 无任何直接调用点

- 全 `.text` 反汇编 28 171 条指令中，`bl 0x12e30` / `b 0x12e30` = **0 条**（上一轮只能写「有调用方」，本轮把「直接调用」这条路否掉）。
- 地址仅在一处被物化：

```
12de8: adrp x2, 0x12000
12df0: add  x2, x2, #0xe30      ; x2 = 0x12e30（回调函数指针）
12df4: mov  w1, #0x2001         ; 回调 id
12df8: movk w5, #0x4, lsl #16   ; w5 = 0x40001000
12dfc: add  x8, x4, #0x41, lsl #12
12e00: ldp  x3, x0, [x8, #0x8]! ; x3=[ctx+0x41008], x0=[ctx+0x41010]
12e04: ldr  x8, [x0, #0x20]
12e08: blr  x8                  ; 注册：method(x1=0x2001, x2=0x12e30, x3, x4=ctx, w5=0x40001000)
```

⇒ **注册者是 UFSDxe 自己（`GPTListenerInit`），调用者是外部协议对象的虚方法**，故静态 xref 不可能命中。

### 1.2 已证：函数与协议身份（新事实，比 10-29 更具体）

| 地址 | 身份 | 证据（字符串引用，`adrp/add` 直读偏移） |
|---|---|---|
| `0x12bd8` | `GPTListenerAllocMem` | `0x12cdc → 0x1e2ca "GPTListenerAllocMem: Failed memory allocation"` |
| `0x12cf8` | `GPTListenerInit` | `0x12d4c → 0x1e2f9 "GPTListenerInit: GPTListenerParams is NULL"` |
| **`0x12e30`** | **GPTListener 派发器（回调解入口）** | 跳转表 `0x1e2b8 = 00 07 0a 0d`，紧接 `0x1e2bc "GPTListener.c"` |
| **`0x13120`** | **`GPTListenerReadSectors`**（= `0x402` 分支目标，崩溃函数） | `0x132c8 → 0x1e325 "GPTListenerReadSectors: Failed mem allocation. mTzSDGptRWReq"` |
| `0x13314` | `GPTListenerWriteSectors` | `0x13458 → 0x1e363 "GPTListenerWriteSectors: …"` |

- 于是 `0x402` 的语义从「请求上下文 opcode」进一步收窄为 **GPT 读扇区请求**（`0x403` = 写扇区）。
  `u32[ctx+4]` 即 `mTzSDGptRWReq` 里被当指针用的那个字段。
- `GPTListenerInit` 的依赖协议 GUID（`gBS->LocateProtocol`，`gBS@[+0x140]`，GUID 指针 `0x20218`）实测 16 B：
  `8d10ed7724858b4b9d2e34987aecb9c1` = `77ed108d-8524-4b8b-9d2e-34987aecb9c1`。
  该 GUID 在 `vendor-dxe-fv.bin` 内 **8 处**命中（`0x8496c/0x9a99c/0xaba7c/0xb29d4/0xcfc3c/0x227428/0x29d5ac/0x2f05bc`）。
  邻近串显示其中一处落在 **`ScmDxe`** 模块（同段含 `ScmArmV8.c`、`DriverEntryPoint.c`、
  **`"Listener Callback function failed. id 0x%x"`**）⇒ **回调的实际发起者在 SCM（TZ SMC）监听分发路径**，与「请求缓冲来自安全世界/SCM 应答」一致。
- 一致性补充：模块内 `0x402` 的立即数用法只有 `0x75a0` 一处，且是 `tst x19, #0x80000402` 的位测试（日志掩码），
  **不存在「自己构造 `0x402` 请求缓冲」的代码** ⇒ 请求缓冲不由 UFSDxe 生成。

### 1.3 缺口（明确未证）

1. **没定位到 `ctx+4` 的写入指令**：需要 `ScmDxe`（及 TZ 侧应答格式）侧取证，本轮未做——`vendor-dxe-fv.bin` 的 PE/TE 镜像未在本轮成功解析出模块边界（FV 走查脚本在 `.pi/trash` 侧无现成解析器，FV 内未找到裸 `MZ`/`VZ` 签名），故只到「哪个模块发起」未到「哪条 `str` 写入」。
2. `w5=0x40001000` 的语义（大小/属性）未对上任何本地头文件；本地 Mu 树无该协议头（`grep -ri gptrw/gpt_rw` 0 命中）。
3. **不得**据此把 L29 升格为「已定位生产者」：仍为 **未证实**，回帖口径不变。

## §2 M3 —— dodge 三补丁点（对应 L31 前半）

对象：`vendor-UFSDxe.efi`（`fa561bf1…878d2`） vs
`build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/PakalaPkg/Device/lenovo-y700g4/PatchedBinaries/UFSDxe.efi`
（151 552 B，sha256 `00ae059f5b4a95fbe85dc9eb4c6d991c4ea5037f330cc8d3206951680a280ac1`）。

`cmp -l` 复算 = **38 字节**，分布与 10-29 §7 R6 完全一致：

| 偏移 | 长度 | vendor | patched | 归属函数 |
|---|---|---|---|---|
| `0xa998` | 8 B | `bl 0xbfa4` | `mov x1,#1` + `bl 0xc0d0` | `0xa910`（UIC/链路初始化链：同函数内 `bl 0xbfa4/0xc0d0/0xd294/0xc1dc/0xc2f0/0xcd10/0xcfb0/0xcc68/0xca3c/0xc858/0xd130`） |
| `0x114c4` | 16 B | `cbz w0,0x114dc`（判 `bl 0x11370` 结果） | `mov x0,x19` + `mov w1,#0` + `bl 0x106d0` + `b 0x114dc`（**丢弃返回码、强制继续**） | `0x11370`（同函数内字符串：`UFS PHY Init Error`、`UFS PHY EOM Init Error`、`UFS PHY 2 Lane Init Error`、`dUFS Get PHY Tune Table Error`、`UFS Get PHY Tune 2 Lane Table Error`、`UFS_UIC_ERROR_REG_DUMP` ⇒ **PHY/UIC 初始化与错误转储**） |
| `0x1b080` | 8 B | `sub sp,sp,#0x40`（真函数体，原体保留为死代码） | `mov w0,#0` + `ret`（**整函数 stub 成成功**） | `0x1b080`（字符串：**`EnableUfsIOC`**、**`UFS IOMMU LocateProtocol failed 0x%x`**、**`UFS IOMMU domain create failed`**、**`UFS IOMMU domain configure failed`**、`UFS IOMMU domain attach failed`、`UFS_MEM`）⇒ **UFS IOMMU/SMMU 域创建+配置+附着被整体跳过** |
| `0x23d21..0x23d3b` | 6 B | build 路径串 | — | 非语义 |

- `0x1b080` 的**唯一调用者** = `0xb358`（薄包装 `0xb350`：成功返 0、失败返 `-100`），而它被
  **UFS 驱动入口 `0x3fe8`** 在 `0x4290/0x42a0` 调用，前置判据是配置键 **`UfsSmmuConfigForOtherBootDev`**
  （串 `0x1c056`，xref `0x4200`，同函数），失败即报 **`0x1c073 "UFSSmmuConfig failed"`**（xref `0x42ac`）。
  ⇒ **dodge 的第三处补丁正好把「UFSSmmuConfig」这一步变成恒成功**，与 10-29 崩溃面（SMMU 层 `FAR=0xD6ABB038`）**同层**。
- 崩溃函数 `0x13120`（`GPTListenerReadSectors`）区间 `0x13120..0x13234` 在 diff 中 **0 命中** ⇒ 与 10-29 结论一致：**dodge 未触碰崩溃函数**。

### 2.1 缺口（重要，影响 E1 解释）

**E1 里实际装进去的不是这份 `PatchedBinaries`**：
`reports/artifacts/uefi-e0e1-20261028/UFSDxe.patched.efi` = 155 648 B、sha256
`e76b555f7c855784cc03303ae1044c69b24f04f214a320a8e2ea101b4f3c85ef`（≠ 上面 `00ae059f…`；两者 `cmp -l` 45 306 B 不同）。
⇒ 本轮「三补丁点」结论对 **仓库内 `PatchedBinaries` 成立**；**E1 所带二进制的补丁来源/等价性未证**
（`E1-UFSDxe-in-FV-SEC2.pe32` 155 652 B、`bc336c04a85748fc952a07b826b2f98ed9ccc9680ade3d6d3c6f28d2406f243d`）。
上机前应先澄清 E1 变量身份，否则 E1 的成败不能被解释为「dodge 三补丁」的成败。

## §3 M4 —— ConfigurationMapLib 条目（对应 L19）：**对象纠正**

- **10-29 引用的是 `/home/xuqianhui/ext-repos/mu/Platforms/OnePlus/dodgePkg/.../ConfigurationMapLib.c`（58 行，`grep -c '{"'` = 41）**。
  该文件属 **OnePlus dodge** 平台，不是本机平台。
- 本机（elden）真正的配置表在 Mu 的 lenovo 平台包：
  `build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/PakalaPkg/Device/lenovo-y700g4/Library/PlatformConfigurationMapLib/PlatformConfigurationMapLib.c`
  （72 行，sha256 `0ee7e304b40050a26c20db2b85c3ddaec352e585092869763590fdb1d1355dcd`）。
  实测：**`grep -c '{"'` = 62 条启用**（另有 8 条被 `//` 注释掉，合计 70 行条目的字面量）。
  `UfsSmmuConfigForOtherBootDev` = **1**（第 62 行）、`EnableUfsIOC` = **1**（第 30 行）。
- 结论（口径不变、对象更正）：**配置表全是命名键、无 `0x402` 这类数值键** ⇒ 「`0x402` 不是平台配置项」这一条
  在本机自己的表上同样成立（本条不依赖 dodge 那份文件）。
- 缺口：本机表**是否被编进本次 `SM8750_EFI-E1.fd`** 以及二进制内条目数，本轮未核（未做构建/未解析 FD 内该库符号）。

## §4 E0 / E1 / E2 现存产物核对（对应 10-28 复现件）

### 4.1 哈希与尺寸（全部本轮 `sha256sum` 重算）

| 文件 | 尺寸 | sha256 | 与 10-28 记录 |
|---|---|---|---|
| `lenovo-y700g4-E0-v0.img` | 2 441 216 | `987bcde9bafc7ccfb244956acb805bd7fb3e4e7cbbad72dfbc4c5b5f327a16f2` | 一致 |
| `lenovo-y700g4-E1-v0.img` | 2 445 312 | `1ae201c2d518672dc2715e2553396c6bd1fbf13c7c4804fc0ee9ed1f74f96540` | 一致 |
| `e0-bootpayload.bin` | 2 436 681 | `98511db91fc69a9f7112a10c9ec9dd2a7b3ae81c565a63161d99541dabcb7028` | 一致（= `manifest.sha256`） |
| `e1-bootpayload.bin` | 2 437 723 | `2a40bc9e02833a7fdf085153991ff40eb41c670002721180d28c60e5d2b32616` | 一致 |
| `SM8750_EFI-E1.fd` | 4 194 304 | `bde4831b280710829894635ad48c2ad25107a376089ef13aba81a4550cd6bea5` | 一致（§2.3 记录） |
| `UFSDxe.patched.efi` | 155 648 | `e76b555f7c855784cc03303ae1044c69b24f04f214a320a8e2ea101b4f3c85ef` | manifest 一致；**来源见 §2.1 缺口** |
| `E1-UFSDxe-in-FV-SEC2.pe32` | 155 652 | `bc336c04a85748fc952a07b826b2f98ed9ccc9680ade3d6d3c6f28d2406f243d` | manifest 一致 |
| `empty.ramdisk` | 0 | — | — |

`manifest.sha256`（610 B）内 6 条已逐条复算，**6/6 一致**（无手抄漂移）。

### 4.2 结构核对（新证）

- 两个 `.img` 都是 **Android boot header v0**（magic `ANDROID!`），**page size = 4096**；
  **payload（gzip）起始于文件偏移 `0x1000`**，`img[0x1000:0x1000+len] == e{0,1}-bootpayload.bin` **True/True**。
  （上一轮报告只写了镜像级 sha，未记 payload 偏移；本轮补上，供上机前二次校验。）
- gunzip 后 payload：E0 = 4 194 416 B `90b17286b453bb0643487c33dace6a1b7baf21dc31fdabc72be3b7f835f7238c`、
  E1 = 4 194 416 B `c5b82bef4321c557292dfd044a94b764715d89c3706a42e4baa69448d98f205b` ⇒ 与 10-28 §0 表**逐字节一致**。
- 磁盘空间/完整性无异常（目录 13.9 MB，10-28 后再无写入痕迹；本轮只读）。

### 4.3 E2

- `reports/artifacts/uefi-e0e1-20261028/` **无任何 E2 产物**（无 `.efi`/`.c`/镜像），与 10-28 报告 §4「只做可行性、不实现」一致。
- 缺口：E2 仍是**未证实**项（tiny DXE 能否拉起 link state 只有作者口头说法）；本轮不新增论证。

## §5 M2 —— 需上机（本轮不做）

- `D6ABB030` 是否落在 Mu `MemMap` 内，需要**设备/Shell 侧 `memmap`** 或该次启动的 `gEfiDebugImageInfoTableGuid` 转储；
  本轮主机侧无该转储、不做地址区间反算（缺内存映射输入，反算无意义）。
- 状态：**需上机 / 未证实**。不因 M1/M3 的进展而改变。

## §6 本轮已做 / 未做 / 待拍板

**已做（全部只读、单命令 `timeout -k`，均 < 2 min）**
1. M1：全 `.text` xref 扫描（0 命中）、注册点反汇编、5 个函数身份串归属、GUID 提取、FV 内 GUID 8 处命中与 `ScmDxe` 邻近串。
2. M3：`cmp -l` 38 B 复算、三段并排反汇编、`0x1b080` 调用链（`0xb350`←入口 `0x3fe8`）与配置键/错误串 xref。
3. M4：纠正对象（elden `PlatformConfigurationMapLib.c` 62 条启用 / dodge 41 条），sha 与行号留证。
4. E0/E1/E2：7 个产物 sha256 重算 + manifest 6/6 + img 内 payload 偏移与逐字节一致 + gunzip 后 sha 复核 + E2 无产物确认。

**未做（明确缺口）**
1. `ScmDxe`/TZ 侧「谁写 `ctx+4`」——**L29 仍为未证实**；FV 模块边界本轮未解析成功（无裸 `MZ`/`VZ`，疑似压缩段）。
2. E1 所带 `UFSDxe.patched.efi`（`e76b555f…`）与仓库 `PatchedBinaries`（`00ae059f…`）**不是同一件**，其补丁集等价性未证。
3. 本机配置表是否真被编入 E1 的 FD（需构建或 FD 内符号解析，本轮按禁令不做全量构建）。
4. M2（需上机）；E0/E1 仍**未上机**（`fastboot boot` 属父 agent 排他动作）。

**待拍板（只建议，不改 SSOT）**
- `TASKS` §5 Q25 的 `0x402` 描述可再收紧一格：`0x402` = **GPT 读扇区请求（GPTListenerReadSectors）**，`0x401/0x403/0x404` 依次为同派发器的其它三支（写扇区 = `0x403`）；崩溃点是 `mTzSDGptRWReq` 的 `+4` 字段被当指针解引用。是否并入由父 agent 决定。
- 若将来上机 E1，建议先记录**所用 `UFSDxe.patched.efi` 的 sha**（两件共存，极易混淆）。
