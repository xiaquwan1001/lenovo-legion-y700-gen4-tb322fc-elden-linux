# UEFI issue #12 回帖定稿（2026-10-29；**已发送** comment 6487769609；2026-11-13 另发闭环 comment 6847932534）

> **状态更正（2026-11-13）**：本文标题原写「草稿·未发送」，但 §2 正文已于 2026-10-29T04:16:34Z 作为新 comment 发布
> （GitHub comment id 6487769609）。本轮另发闭环回帖（id 6847932534）：UFS 枚举通、两种形态都能起 Linux、
> flashed 形态真阻塞 = `dtbo_a` 而非 UFSDxe ⇒ 不需要 tiny DXE。详见
> `TASKS/sessions/2026-11-13-上游投递-wl2868c-v11-mdss-v4-uefi12闭环.md` §3。

对象：`sunflower2333/mu_wide_platforms#12`
（`SM8750 (Pakala) Lenovo Y700 Gen4: vendor UFSDxe fails UEFI_DEVICE_ERROR — which platform config is it missing?`）

性质：**纯主机、只读、零写盘、不发送、不评论 GitHub**（工具面只用了 `llvm-objdump` / `cmp` / `sha256sum` / `python3` 读本地文件）。
承接：`reports/uefi-issue12-reply-draft-20261028.md`（初稿 + 已发布评论 `#issuecomment-6467336320`）、
`reports/uefi-visibility-rebuild-20261028.md`（E0/E1/E2 取证）、`reports/uefi-samechip-tablet-display-20261028.md`、
`reports/uefi-restart-20261021.md` §A.2（0x402/`UFS.c+2326` 首次静态定位）、`TASKS/README.md` §4 N1 / §5 Q25、`PITFALLS #387/#418`。

> 本文档 = 「待发送文本」+「逐条断言证据账」+「发送前检查清单」。**本轮唯一实质新增**：`0x402` 的语义从「推测是运行期注册表条目类型字段」（`uefi-restart-20261021.md:78` 标【推测，未证实】）**升级为已证**——它是**回调上下文结构体偏移 0 的 opcode**，取值域 `0x401..0x404`，由 `0x12e30` 的跳转表分派；且该路径**全程没有任何 config 查表调用**。这直接支撑「不是 `PlatformConfigurationMapLib` config tag」这一要给出上游的结论。

---

## §0 结论（先数字）

| # | 结论 | 等级 |
|---|---|---|
| 1 | `0x402` = **调用方传入的上下文结构体偏移 0 的 32 位 opcode**（分派器接受 `0x401..0x404`，跳转表 `0x1e2b8` 实测 `0x402 → 0x12e90 → bl 0x13120`） | **已证**（本轮反汇编 + 表字节直读） |
| 2 | 崩溃点 `0x13224 ldr x9,[x0,#8]` 用 `x0 = u32[ctx+4..+7]` 零扩展（`0x13200..0x13218`），值 `0xD6ABB030` ⇒ FAR `0xD6ABB038` | **已证**（反汇编 + 10-05 日志签名 `archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md:33`） |
| 3 | 从 `0x13120` 入口到崩溃指令**只有 2 个调用**：`0x6cc8`（`[gBS+0x40]` = `AllocatePool(PoolType=4)`）、`0x779c`（`CopyMemWrapper`）⇒ **该路径上不存在任何配置表/protocol 查表** | **已证**（全函数反汇编 `0x13120..0x13234`） |
| 4 | 同一条 `0x402` 路径在 Mu `PatchedBinaries` 里**一个字节都没改**（3 个补丁点 `0xa998`/`0x114c4`/`0x1b080` 均不在 `0x13120..0x13234`） | **已证**（`cmp -l` 偏移集合） |
| 5 | `UFS.c+2326` 是**另一层独立失败**：`mov w1,#0x916`（2326）全 `.text` 唯一一处 `0x42f4`，紧邻 `"UFS.c"`（RVA `0x1b438`）；守卫路径字符串 `UFSSmmuConfig failed`（RVA `0x1c073`）；断言载荷 RVA `0x1c14e` = `!EFI_ERROR (((RETURN_STATUS)(0x8000000000000000ULL | (7))))` ⇒ `EFI_DEVICE_ERROR` | **已证**（反汇编 + 三段字符串逐字节命中） |
| 6 | E0/E1 复现件仍**未上机**；BootShim **不含** cache 维护（E0 口径） | **已证**（`uefi-visibility-rebuild-20261028.md:13-18`） |
| 7 | 谁在运行期**写入** `ctx+4` 那个指针 | **未证实**（回帖据此提问 Q1） |
| 8 | `D6ABB030` 在「本机 Mu 内存映射下未映射」——只有 FAR 这一条间接证据，无独立 MemMap 比对 | **未证实**（回帖只陈述 FAR） |

---

## §1 已发布评论的现状（发送前基线）

| 项 | 值 |
|---|---|
| 上一条我方评论 | `#issuecomment-6467336320`，2026-10-28T11:04:46Z，5 423 字符（`reports/uefi-issue12-reply-draft-20261028.md` §4） |
| 该条正文口径 | 接受「link state = Sleep」方向；指出「本机 Mu UFSDxe 就是厂商件（6 字节差）」；请对方在 (a) UFSDxe 代次 / (b) 运行期数据表 / (c) link state+PHY 中选一 |
| **本条要更正的口径** | 初稿里「which platform config is it missing」这一框架**是我方误设**。0x402 不是 config 项 ⇒ 新回帖必须**明说撤回该问题**，否则上游会继续按「缺配置」方向答 |
| 作者最近回复（2026-10-28T04:27:34Z） | 「UFS问题是Link State处于Sleep状态，你让AI写个tiny dxe用来把link state拉起来不就行了」（60 字符） |
| 未变项 | issue 仍 `OPEN`；本机 Mu 树 = `build/uefi-woa-prep/repos/7-mu-lenovo`（`mu_wide_platforms@6b6ac42a` + `build_cfg/sm8750.json`） |

---

## §2 英文回帖定稿（待发送文本，纯 ASCII）

> 发送形态建议：**一条新 comment**（不是 edit 旧 comment）——因为旧 comment 里的错误框架需要被显式撤回，edit 会让历史讨论断链。
> 下面 `~~~` 之间的内容即待发送正文（GitHub Markdown）。

~~~
Thanks for the pointer. Before following the tiny-DXE route I have to correct
our own framing first: we now have a static proof of what `0x402` is, and it is
not a platform configuration entry. That changes the questions we should be
asking you.

## 1. Reproduction data (all from our unit)

Device: Lenovo Y700 Gen4 (TB322FC, SM8750P, "lenovo-y700g4" in your tree).

- stock `uefi.elf`: 5,242,880 B, sha256 `fc68d2f9...`
- embedded FV (LZMA, FFS `9e21fd93-9c72-4c15-8c4b-e77f1db2d792`, data offset 24):
  4,247,560 B, sha256 `657940ca74a667aaa518038f2d4bfe7de04205ca883574e0c46172df002962d9`
- vendor `UFSDxe.efi` out of that FV: PE32, 151,552 B, file GUID
  `0d35cd8e-97ea-4f9a-96af-0f0d89f76567`,
  sha256 `fa561bf11eb18f142b128f0335973f6c4a8d0241747ea581d5b3a56d601878d2`
- your `Binaries/.../UFSDxe/UFSDxe.efi` differs from the stock binary in **6 bytes
  only**, all inside the embedded build-path string (`mp250526` vs `mp251201`, file
  offsets `0x23d21`, `0x23d30..0x23d33`, `0x23d3b`) -- so your unpatched copy is the
  same build as ours.
- your `PatchedBinaries/UFSDxe.efi` differs from stock in **32 bytes = 3 sites**:
  `0xa998` (8 B), `0x114c4` (16 B), `0x1b080` (8 B).
- failure signature (10-05 run, patched binary, v0 header):
  `Synchronous Exception`, `PC = UFSDxe+0x13224`, data abort / translation fault
  level 2, handler reads `FAR = X0 + 8` with `X0 = 0xD6ABB030`.

## 2. What 0x402 is

All offsets below are RVAs into `UFSDxe.efi` `.text`; the bytes at these RVAs are
identical in your `PatchedBinaries` copy (none of the 3 patch sites touches this
function).

- `0x12e30` is a callback `(ctx, len)`. It requires `len >= 0x1c`
  (`0x12e38 cmp w2,#0x1c ; b.hs`), then reads `w8 = [ctx] - 0x401` and, when
  `w8 <= 3`, jumps through the 4-entry byte table at `0x1e2b8`
  (`0x12e4c..0x12e70`). The table bytes are `00 07 0a 0d`, i.e. targets
  `0x401 -> 0x12e74`, `0x402 -> 0x12e90`, `0x403 -> 0x12e9c`, `0x404 -> 0x12ea8`.
  So **the first 32-bit word of `ctx` is an opcode in the range 0x401..0x404**,
  and `0x402` only means "case 2 of this dispatch table".
- `0x12e90` loads `x0 = ctx` and calls `0x13120`, the handler:
  - size = `u32[ctx+0x10] + u32[ctx+0x14]` (`0x13138..0x13170`)
  - `AllocatePool(EfiBootServicesData, size)` via `[gBS+0x40]` (helper `0x6cc8`)
  - `CopyMemWrapper(dst, ctx, size)` (`0x779c`; its assert strings are
    `CopyMemWrapper.c` at RVA `0x1cbb1`)
  - validates `u32[copy+0] == 0x402` (`0x131f4`) -- i.e. it re-checks the opcode
    it just copied
  - zero-extends `u32[copy+4..7]` (`0x13200..0x13218`), bails out if zero
    (`0x1321c`), and then executes `ldr x9,[x0,#8]` at `0x13224`.

Two consequences:

1. **`0x402` is not a configuration tag.** Between the entry of `0x13120` and the
   faulting load there are exactly two calls: `AllocatePool` and `CopyMemWrapper`.
   There is no config-map lookup, no `LocateProtocol`, no
   `ConfigurationMapHelperLib` call anywhere on this path. (For completeness, the
   configuration map in your tree, `dodgePkg/Library/ConfigurationMapLib/
   ConfigurationMapLib.c`, has 41 entries and all of them are named keys such as
   `EnableShell`, `NumCpus`, `EnableUfsIOC`; there is no numeric `0x402` key.)
2. The fault is the **second word of our own request context** (`ctx+4`), holding
   `0xD6ABB030`, being dereferenced as a pointer. So the interesting question is
   not "which config is missing" but "who is supposed to fill `ctx+4`".

We would like to retract the earlier "which platform config is it missing"
framing from our previous comment -- it was our own misreading.

## 3. The second, independent failure we see: UFS.c+2326

Separately from the above we also get `ASSERT UFS.c +2326` with
`Status = EFI_DEVICE_ERROR`. Statically:

- `mov w1,#0x916` (= 2326) occurs exactly once in `.text`, at `0x42f4`, next to
  `"UFS.c"` (RVA `0x1b438`);
- the assert payload is at RVA `0x1c14e`:
  `!EFI_ERROR (((RETURN_STATUS)(0x8000000000000000ULL | (7))))`;
- the guard path right before prints `UFSSmmuConfig failed` (RVA `0x1c073`), and a
  second assert at `UFS.c+2331` follows.

So that layer is SMMU/context configuration, not link state. We see it as a second
failure signature, independent of the `0x402` dereference.

## 4. Two questions

**Q1 (0x402 path).** In your tree, which component is expected to populate the
`+4` word of the request context for opcode `0x402` before UFSDxe runs? Two
concrete possibilities from our side: (a) it is supposed to come from a
firmware-version-dependent data blob -- which would match your earlier "needs a
special UFSDxe patch" comment; or (b) it comes from a DXE producer that is present
in the stock FV but missing from the FV we build. Which one is it, and if (b),
which module?

**Q2 (SMMU layer).** Does the SM8750 UFS SMMU work you mentioned also cover
`UFSSmmuConfig` (the `UFS.c+2326` assert)? Concretely: on Mu/Pakala should that
`EFI_DEVICE_ERROR` disappear once the correct SMMU/IOMMU description is used, or
does UFSDxe need a platform-specific SMMU bypass on this device?

## 5. What we can provide

- the exact `cmp -l` offset lists (stock vs your `Binaries` vs your
  `PatchedBinaries`), so you can confirm we test *your* binary and not a rebuild;
- sha256 of every artifact in the chain (`uefi.elf` -> FV -> `UFSDxe.efi`) plus
  the extraction commands;
- a full disassembly listing of `0x12e30`, `0x13120` and the three patch sites
  (as a text attachment, offsets only -- no decompiled source);
- our BootShim, including the cache-maintenance patch we had to add
  (`dc civac` over `UEFI_BASE..+0x500000`, `dsb sy`, `ic iallu`, `dsb sy`, `isb`),
  and the ABL `Final RAM Partitions` line showing `UEFI_BASE = 0xFF300000`,
  size `0x500000`;
- `UFSDxe.depex` (value `06 08`, i.e. TRUE) and its `APRIORI.inc` position (line
  76), in case the ordering of the `0x402` producer matters;
- on request, the v0-header image that reproduces `PC = UFSDxe+0x13224` on our unit.

On the tiny-DXE suggestion: we agree it is the right shape *if* the link really is
in Sleep, but we would rather settle Q1/Q2 first, because hand-programming the UFS
UIC registers can leave the link unrecoverable on this unit, and we currently have
no early console output to debug it with.
~~~

---

## §3 逐条断言 × 仓库内证据账

判据口径：**已证** = 本轮或既有报告里有命令 + 原始输出；**未证实** = 只有推断；**未上机** = 有产物无实测。

| # | 断言（回帖中的说法） | 证据指针 | 等级 |
|---|---|---|---|
| L1 | 设备型号/代号 TB322FC·SM8750P·`lenovo-y700g4` | `AGENTS.md` 首段；`reports/uefi-visibility-rebuild-20261028.md:1` | 已证 |
| L2 | stock `uefi.elf` 5 242 880 B / `fc68d2f9…` | `reports/uefi-issue12-reply-draft-20261028.md` §0 表行 1（本轮未重算，沿用 10-28 本轮重算值） | 已证（10-28） |
| L3 | FV 4 247 560 B / `657940ca…` / FFS GUID / DataOffset=24 | 同上 §0 表行 2–3 | 已证（10-28） |
| L4 | vendor `UFSDxe.efi` 151 552 B / `fa561bf1…878d2` / GUID `0d35cd8e-…` | `reports/uefi-issue12-reply-draft-20261028.md` §0 表行 4；本轮 `sha256sum reports/artifacts/uefi-dxe-20261024/vendor-UFSDxe.efi` = `fa561bf1…878d2` | 已证（本轮重算） |
| L5 | `Binaries` 件与厂商件差 6 字节、全在 build 路径串（`0x23d21/0x23d30..33/0x23d3b`） | 本轮 `cmp -l vendor Binaries/...UFSDxe.efi` → 恰 7 个偏移（`0x23d20` 起算 1-based 23d21…），10-28 §0 表行 5 | 已证（本轮复算） |
| L6 | `PatchedBinaries` 件差 32 字节 = 3 段 `0xa998`(8)/`0x114c4`(16)/`0x1b080`(8) | 本轮 `cmp -l` 分组 → `0xa998..0xa99f`、`0x114c4..0x114d3`、`0x1b080..0x1b087` + 7 个路径串字节 | 已证（本轮） |
| L7 | 3 个补丁点**不触及** `0x13120`/`0x13224` | 同 L6 偏移集合，`0x13120..0x13234` 无任何命中 | 已证（本轮） |
| L8 | 崩溃签名 `PC=UFSDxe+0x13224`、`FAR=X0+8`、X0 坏指针 | `archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md:33`（A 矩阵行 A） | 已证（10-05 日志） |
| L9 | `FAR = 0xD6ABB038`、X0 = `0xD6ABB030` | `reports/uefi-restart-20261021.md:78` 引用 10-05 日志 | 已证（日志）／「未映射」未证实 |
| L10 | `0x12e30` 回调 `len>=0x1c` 门槛 | 本轮反汇编 `0x12e30: stp x29,x30…; cmp w2,#0x1c; b.hs 0x12e4c; …`（见 §7 R1） | 已证（本轮） |
| L11 | `w8=[ctx]-0x401`、`cmp w8,#3`、表 `0x1e2b8` | 本轮反汇编 `0x12e4c..0x12e70`（§7 R1） | 已证（本轮） |
| L12 | 表字节 `00 07 0a 0d` ⇒ `0x402 → 0x12e90` | 本轮 `python3` 直读 `.text` 文件偏移 `0x1e2b8`（RVA==文件偏移，见 §7 R2）；`0x12e90: mov x0,x1; bl 0x13120` | 已证（本轮） |
| L13 | size = `u32[ctx+0x10]+u32[ctx+0x14]` | 本轮反汇编 `0x13138..0x13170`（§7 R3） | 已证（本轮） |
| L14 | `AllocatePool(PoolType=4)` 经 `[gBS+0x40]`，helper `0x6cc8` | 本轮反汇编 `0x6cc8..0x6cfc`：`mov w0,#4; ldr x8,[gBS]; ldr x8,[x8,#0x40]; blr x8` | 已证（本轮） |
| L15 | `CopyMemWrapper`（`0x779c`，assert 串 RVA `0x1cbb1`） | 本轮 `d.find(b"CopyMemWrapper.c")` = 文件偏移 `0x1cbb1`，且 `0x1b438`/`0x1c073`/`0x1c14e` 三串逐字节命中（§7 R4） | 已证（本轮） |
| L16 | 校验 `u32[copy+0]==0x402` 在 `0x131f4` | 本轮反汇编 `0x131d8..0x131f8`（§7 R3） | 已证（本轮） |
| L17 | 崩溃取 `u32[copy+4..7]` 零扩展 + `cbz` + `ldr x9,[x0,#8]` | `0x13200..0x13224`（§7 R3） | 已证（本轮） |
| L18 | **该路径只有 2 个调用、无任何查表** | 全函数 `0x13120..0x13234` 反汇编中 `bl` 仅 `0x6cc8`、`0x779c` 两处；`ldr` 只读 `ctx`/`copy` 局部 | 已证（本轮） |
| L19 | `ConfigurationMapLib.c` 41 条全为命名键、无 `0x402` 数值键 | `reports/uefi-restart-20261021.md:80`（10-21 实测 `dodgePkg/Library/ConfigurationMapLib/ConfigurationMapLib.c`） | 已证（10-21，本轮未复算） |
| L20 | `mov w1,#0x916` 全 `.text` 唯一在 `0x42f4`，紧邻 `"UFS.c"` RVA `0x1b438` | `reports/uefi-restart-20261021.md:53,57-58`；本轮串命中 `0x1b438 = "UFS.c"` | 已证（本轮补串） |
| L21 | 断言载荷 RVA `0x1c14e` = `…(0x8000000000000000ULL\|(7))` | 本轮直读 = 逐字节命中（§7 R4） | 已证（本轮） |
| L22 | 守卫串 `UFSSmmuConfig failed` RVA `0x1c073` | 本轮直读命中；`reports/uefi-restart-20261021.md:63` | 已证（本轮） |
| L23 | BootShim 含 `dc civac` 补丁（回帖 §5 材料清单提到） | `reports/uefi-issue12-reply-draft-20261028.md` §0 表行 9（`BootShim/BootShim.S` L51–67）；对照 `reports/artifacts/uefi-visibility-20261026/BootShim-cachefix.bin` `0c1bb4da…` 含 `d50b7e25`/`d508751f` | 已证（10-26/10-28） |
| L24 | E0 呈「10-05 口径」= BootShim **不含** cache 维护（`d50b7e25` 0 命中，12 条指令） | `reports/uefi-visibility-rebuild-20261028.md:18,124-144` | 已证（10-28） |
| L25 | `UEFI_BASE=0xFF300000` / size `0x500000`（ABL Final RAM Partitions） | `reports/uefi-issue12-reply-draft-20261028.md` §0 表行 10（`reports/uefi-control-experiment-20261027.md`）；`reports/uefi-restart-20261021.md:96` | 已证（10-27 在机内核映射） |
| L26 | `UFSDxe.depex` = `06 08`（TRUE）、`APRIORI.inc` 第 76 行 | `reports/uefi-issue12-reply-draft-20261028.md` §0 表行 12 | 已证（`xxd` + `grep -n`） |
| L27 | E0/E1 镜像 sha256 与尺寸 | `reports/uefi-visibility-rebuild-20261028.md:13-21`（E0 `987bcde9…a16f2` 2 441 216 B；E1 `1ae201c2…96540` 2 445 312 B） | 已证（10-28）未上机 |
| L28 | 回复中「hand-programming UFS UIC 可致链路不可恢复」 | `reports/uefi-visibility-rebuild-20261028.md` §4（E2 风险段） | 已证（10-28 静态评估）＝**工程判断**，非实测 |
| L29 | **谁写 `ctx+4`** | 无 —— 只知道 `0x12e30` 之前有调用方（`0x12e38` 检查 `w2`），未回溯到生产者 | **未证实** → 回帖 Q1 |
| L30 | **`D6ABB030` 在本机 Mu MemMap 下未映射** | 仅 FAR 一条间接证据；无 `MemMap`/调试器比对 | **未证实** → 回帖只写 FAR |
| L31 | 「tiny DXE 能拉起 link state」 | 作者口头（2026-10-28T04:27:34Z）；dodge 补丁已含 sleep→wakeup（`0xa998`/`0x114c4` 语义）但**未上机验证** | **未证实** |

**需补证据（[需补证据]，主机侧可做但本轮时间盒内未做）**

| 编号 | 缺什么 | 取证命令（主机侧，零写盘） |
|---|---|---|
| M1 | `ctx+4` 生产者（L29） | `llvm-objdump -d --triple=aarch64 vendor-UFSDxe.efi \| grep -n "bl.*0x12e30"` 找调用方，再回溯其 `x1` 来源；必要时用 `0x12e30` 的 xref 交叉 `gh` 上游源码（`MdePkg`/`QcomPkg` 中同名回调） |
| M2 | `D6ABB030` 是否在 MemMap 内（L30） | 上机侧：在 Shell 下 `memmap`（当前无 Shell/无输出 ⇒ **未上机不可做**）；主机侧只能做「该地址落在哪个 DXE 模块加载区间」的反算 —— 需一份该次启动的 `gEfiDebugImageInfoTableGuid` 转储（**未留存**） |
| M3 | dodge 3 个补丁点的语义（L31 前半） | `llvm-objdump -d --start-address=0xa960 --stop-address=0xaa20`（+`0x114a0` +`0x1b060`）对 vendor/patched 双份并排 diff；本轮已取到片段（§7 R5），**未做完函数级归属**（`0x1b080` 被整体 stub 成 `mov w0,#0; ret` 已明确） |
| M4 | `ConfigurationMapLib` 41 条（L19）本轮未复算 | `grep -c '{"' build/uefi-woa-prep/repos/7-mu-lenovo/.../dodgePkg/Library/ConfigurationMapLib/ConfigurationMapLib.c` |

---

## §4 我方可提供的材料清单（对应回帖 §5，附本机路径与哈希）

| 材料 | 本机路径 | 校验值 |
|---|---|---|
| `cmp -l` 偏移清单（stock vs `Binaries` vs `PatchedBinaries`） | 本文 §7 R5/R6 | 32 B / 3 段 / 6 B 路径串 |
| 链路哈希（`uefi.elf`→FV→UFSDxe） | `reports/artifacts/uefi-dxe-20261024/vendor-dxe-fv.bin`、`vendor-UFSDxe.efi` | `657940ca…62d9` / `fa561bf1…878d2` |
| `0x12e30`/`0x13120` 全反汇编清单 | 本文 §7 R1/R3（可直接贴 issue 代码块，**纯偏移+助记符**） | — |
| `0x1e2b8` 跳转表字节 | 本文 §7 R2（`00 07 0a 0d`） | — |
| BootShim（含 cache 补丁） | `patches/uefi/0001-*`、`BootShim/BootShim.S` L51–67 | 对照件 `BootShim-cachefix.bin` `0c1bb4da…` |
| ABL RAM 表行（`UEFI_BASE`/size） | `reports/uefi-control-experiment-20261027.md` | `0xFF300000` / `0x500000` |
| `UFSDxe.depex` + `APRIORI.inc:76` | 同 L26 | `06 08` |
| E0/E1 复现镜像（按需） | `reports/artifacts/uefi-e0e1-20261028/` | `987bcde9…` / `1ae201c2…` |

> **不提供的**：整包固件、`uefi.elf` 本体（体积 + 未确认再分发许可）⇒ 回帖只给哈希与偏移，让对方自行核对其自有副本。

---

## §5 发送前检查清单

| # | 检查项 | 做法 / 当前状态 |
|---|---|---|
| 1 | **是否需要用户先点头** | **必须**。派工单与 `AGENTS.md` 硬性规则 5 一致：对外发言属「外部可见动作」，且本条**撤回**我方已发布的说法 ⇒ **用户显式批准后才发**。状态：**待批准** |
| 2 | 收件人 | 不指定 `@`（沿用 issue 线程；原作者 `sunflower2333` 会收到通知）。若要 `@`，只用 `@sunflower2333` |
| 3 | 是否 CC 原 issue 参与者 | **不 CC**。`gh issue comment` 无 CC 概念；本轮不新建 PR/不发邮件。若用户要求另发邮件（`out/mail-20261028/` 已有邮件稿目录），需单独派工 |
| 4 | 发送形态 | **新 comment**（保留旧 comment 作为「我方误判 → 更正」的审计链）；**不用** delete/edit 旧评论 |
| 5 | 纯 ASCII | 发送前 `LC_ALL=C grep -c '[^ -~]' out/mail-20261029/uefi-issue12-reply-final.txt` 必须 = 0（§2 正文已按纯 ASCII 写） |
| 6 | 哈希逐字核对 | `fa561bf1…878d2`（`vendor-UFSDxe.efi`）、`657940ca…62d9`（`vendor-dxe-fv.bin`）、`fc68d2f9…`（`uefi.elf`）、`987bcde9…a16f2`/`1ae201c2…96540`（E0/E1）——发布前用 `sha256sum` 全部重算一遍，禁止手抄 |
| 7 | **未证项不得升格** | L29/L30/L31 三条：回帖里只以提问或 FAR 事实出现，**不得**写成「已定位生产者」「已验证未映射」「tiny DXE 可行」 |
| 8 | 撤回措辞 | 必须含 `We would like to retract the earlier "which platform config is it missing" framing`一句，否则对方会按旧框架继续答 |
| 9 | 问题数 | 恰好 2 个（Q1/Q2），编号清晰，避免又变成「多选项让作者挑」 |
| 10 | 附件/链接齐全 | 回帖正文不挂外链（本仓库不公开）；材料以「可提供」清单形式给出，等对方要 |
| 11 | 凭据/权限 | `gh auth status` 应为 `xiaquwan1001`（scopes 含 `repo`）；本轮**未执行**任何 `gh` 写操作 |
| 12 | 发布后回读 | `gh issue view 12 --repo sunflower2333/mu_wide_platforms --json comments` 末条比对正文 sha/字符数 |
| 13 | 若作者已自行回复（线程变动） | 先 `gh issue view 12 --comments` 复核最新 2 条再发，避免答非所问 |

---

## §6 未证实项与本次未做项

- **未上机**：E0/E1 两件仍未 `fastboot boot`；§0 结论 1–6 全部为**静态/离线**证据。
- **未证实**：L29（`ctx+4` 生产者）、L30（`D6ABB030` 未映射）、L31（tiny DXE 有效性）。
- **未做**：向 `0x12e30` 的调用方回溯（M1）；dodge 三补丁点的函数级归属（M3）；`ConfigurationMapLib` 条目数复算（M4）。
- **未做**：任何 GitHub 读写（`gh issue view` 本轮亦未跑，issue 现状沿用 2026-10-28 18:51 快照）。
- **口径更正提醒（父 agent 动作，本文不做）**：`TASKS/README.md` §5 Q25 现文「① `0x402` = 运行期注册表条目类型字段」应改为「① `0x402` = 请求上下文偏移 0 的 opcode（0x401..0x404 分派表），崩溃点是其 `+4` 字段被当指针解引用」——本轮已把该结论从【推测】升为【已证】。

---

## §7 取证记录（本轮实跑命令与原始输出节选）

工具：`llvm-objdump`（Ubuntu LLVM 21.1.8）、`cmp`、`sha256sum`、`python3`（只读）。
PE 结构实测：`.text` RVA `0x1000` / 文件偏移 `0x1000` ⇒ **本轮所有 RVA == 文件偏移**（故 `python3` 直读偏移即 RVA）。

**R1 分派器 `0x12e30`（原始输出节选）**

```
   12e30: a9bf7bfd  stp x29, x30, [sp, #-0x10]!
   12e38: 7100705f  cmp w2, #0x1c
   12e3c: 54000082  b.hs 0x12e4c
   12e4c: b9400028  ldr w8, [x1]
   12e50: 51100508  sub w8, w8, #0x401
   12e54: 71000d1f  cmp w8, #0x3
   12e58: 54000148  b.hi 0x12e80
   12e5c: 90000069  adrp x9, 0x1e000
   12e60: 910ae129  add x9, x9, #0x2b8
   12e68: 3868692b  ldrb w11, [x9, x8]
   12e6c: 8b0b094a  add x10, x10, x11, lsl #2
   12e70: d61f0140  br x10
   12e74: aa0103e0  mov x0, x1 ; bl 0x12f38     (case 0x401)
   12e90: aa0103e0  mov x0, x1 ; bl 0x13120     (case 0x402)
   12e9c: aa0103e0  mov x0, x1 ; bl 0x13314     (case 0x403)
   12ea8: aa0103e0  mov x0, x1 ; bl 0x13554     (case 0x404)
```

**R2 跳转表字节（文件偏移 `0x1e2b8`）**

```
tbl bytes [0, 7, 10, 13, ...]
opcode 0x401 -> target 0x12e74
opcode 0x402 -> target 0x12e90
opcode 0x403 -> target 0x12e9c
opcode 0x404 -> target 0x12ea8
```

**R3 处理器 `0x13120` 关键片段**

```
   13138..13170  拼 size = u32[ctx+0x10] + u32[ctx+0x14] -> w21
   13178: bl 0x6cc8            ; AllocatePool
   1317c: cbz x0, 0x132b8      ; 失败返回
   1318c: bl 0x779c            ; CopyMemWrapper(dst, ctx, w21)
   131d8..131f0  从 copy 取 u32[+0..3]
   131f4: cmp w12, #0x402
   13200..13218  从 copy 取 u32[+4..7] 零扩展进 x0
   1321c: cbz w0, 0x13300
   13224: ldr x9, [x0, #8]     <-- 崩溃点
```

**R4 三处字符串逐字节命中**（`python3` 直读，RVA==文件偏移）

```
0x1b438 -> b'UFS.c'
0x1c073 -> b'UFSSmmuConfig failed\n'
0x1c14e -> b'!EFI_ERROR (((RETURN_STATUS)(0x8000000000000000ULL | (7))))'
0x1cbb1 -> b'CopyMemWrapper.c'
```

**R5 补丁点语义（vendor vs PatchedBinaries，节选）**

```
0xa998  vendor : bl 0xbfa4                      -> patched: mov x1,#1 ; bl 0xc0d0
0x114c4 vendor : cbz w0, 0x114dc                -> patched: mov x0,x19 ; mov w1,#0 ; bl 0x106d0
0x1b080 vendor : sub sp,sp,#0x40 (函数体)       -> patched: mov w0,#0 ; ret   (整函数 stub)
```

**R6 差异面统计**

```
== vendor vs Binaries(unpatched) diff: 7 处（0x23d20..0x23d3b，build 路径串）
== vendor vs Patched diff: 0xa998..0xa99f(8B) / 0x114c4..0x114d3(16B) / 0x1b080..0x1b087(8B) + 同上 7 处
   （0x13120..0x13234 无任何命中 ⇒ 崩溃函数未被打补丁）
```

**R7 哈希复算**

```
fa561bf11eb18f142b128f0335973f6c4a8d0241747ea581d5b3a56d601878d2  reports/artifacts/uefi-dxe-20261024/vendor-UFSDxe.efi
```
