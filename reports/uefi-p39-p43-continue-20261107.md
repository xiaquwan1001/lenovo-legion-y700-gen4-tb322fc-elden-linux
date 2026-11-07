# UEFI p39–p43：漏掉的 `fastboot continue` + 崩溃点搬到 EB 段（2026-11-07）

> 线：G1-29（UEFI 间接引导）。承接 `reports/uefi-p38-true-nobs-20261107.md`。
> 本轮 = **6 发零写盘上机**（p39/p40/p41/p43 + p36 对照 + p38）＋ 3 次构建 ＋ 2 次 logfs 读回。
> 产物：`patches/uefi/20261107R3{4,5,6,8}-*`、`patches/uefi/p39..p43-recipe.txt`、
> `out/r21-sbstop-p3{9},p4{0,1,3}/`、`reports/artifacts/uefi-20261107R3*-p4*/`。

---

## 0. 一句话结论

**前四发全部白打，原因是我漏了 `fastboot continue`**：这棵树把 `BootIntoFastboot` 写死为 TRUE
（我们自己 `20261104R13` 补丁的眉注里就写着这句），UEFI 起来后**一直在 fastboot 等命令**，
要它真引导内核必须再发 `fastboot continue`（`CmdContinue` → `LoadImageAndAuth` → `BootLinux`）。
补发后 p41 **第一次真正进了 `BootLinux`**，拿到完整阶段链；p43 证明**跳内核前的 logfs 转储是成功的**，
崩溃点因此搬回 **`ExitBootServices()` 段**（与 p37 结论一致，不是转储自杀）。

---

## 1. 六发上机的账（全部零写盘 `fastboot boot`）

| 世代 | 件 sha256（前 8） | 动作 | 结果 |
|---|---|---|---|
| p38 (R33) | `0e2bddbd` | boot | UEFI fastboot 常驻、无 `[K]` ⇒ **没发 continue** |
| p39 (R34) | `477ff507` | boot | 同上（屏上无 `pre-BL`） |
| p36 对照 | `bf559e97` | boot | 同上 ⇒ **不是 R33/R34 引进的回归** |
| p40 (R35) | `010c4ab5` | boot | 同上；`flags`/`LIA` 三条标记被自己后面的 USB 洪水冲掉 |
| p41 (R36) | `0359a7c1` | boot + **`continue`** | 屏上 `[K] fb-loop LIA=FFFFFFFFFFFFFFFF flags=5`（= 走 fastboot 分支的证据）；`continue` 后进 `BootLinux` → FLT `pc=0 esr=86000007` |
| p43 (R38) | `62f2b065` | boot + `continue` | 同形态崩（FLT `pc=0 esr=96000007`）；**logfs 里 `tag=preeb` 记录完整** |

p41 / p43 的 logfs `preeb` 记录（逐字）：

```
[K] dump-tag=entry cached=Not Ready        ← 入口：缓存还没有，退回枚举句柄
[K] dump-tag=entry search=Success          ← 枚举句柄在 USB 还活着时是好的
[K] flags fb=1 rec=0 msb=1
[K] goto-fastboot
[K] fb-loop LIA=FFFFFFFFFFFFFFFF flags=5
[K] BL-in vm=1                             ← fastboot continue 之后真正进 BootLinux
[K] BL-vm=1 ok
[K] dtb=B405D000 m=EDFE0DD0 sz=96590200 k=A8080000
[K] gbs=D4C0B010 ap=D4BF8200 eb=D4BF3B80 fp=D4BF85BC   ← EB 之前 gBS 与三个成员全非 0
[K] preeb-go                               ← 记录头 tag=preeb ⇒ 这次转储**成功**
```

---

## 2. 两条被推翻/更正的判读（诚实记账）

1. **「p41 崩在 preeb 转储里」——错**。记录里 `tag=preeb` 且内容是 `preeb-go` 之前的完整环 ⇒
   `SbWriteLogWindow()` **写成功了**（p43 的 `dump-tag=entry search=Success` 也证明枚举句柄在入口是好的）。
   因此 `R38-cached-dump` 是「预防性」而非「修复性」，p43 与 p41 崩溃形态一致也印证了这点。
   `x30=D2AD9B08` / `x10="Part"` / `x09=x21="ufs "` 那些寄存器值是**前面 GetBlkIOHandles 的残留**，
   不是崩点代码 —— 这是本轮最容易读错的一处。
2. **「UEFI 起来就在引导内核」——错**。`BootIntoFastboot` 硬编码 TRUE ⇒ fastboot 是**入口态**，
   必须 `continue` 才走 `BootLinux`。前四发所有「没进 BootLinux」的推论都是这条造成的。

## 3. 剩下的真问题：`ExitBootServices()` 段

- 崩溃签名（两发一致）：`[K] FLT pc=00000000`，`esr=86000007`（IABT，p41）/ `96000007`（DABT，p43），`far=0`，
  `x30=D2AD9B08`（不在 LinuxLoader `0xCFCxxxxx` 段内 ⇒ 指向别的模块或已失效的返回地址）。
- 时间位置：`[K] preeb-go` 已落盘 ⇒ 崩点在 `SbDumpLog("preeb")` 返回之后：
  `[K] preeb-ok` → `SB_STOP(40)` → `ShutdownUefiBootServices()`（`GetMemoryMap` → `ExitBootServices`）
  → `SbBbMark(4)` → R33 的 EB 后标记 → `SbDumpLogNoBs("posteb")`；`posteb` 记录不存在。
- 已排除：EB 之前 gBS 成员为 0（记录里三个成员都非 0）；转储链本身（preeb 成功）。

## 4. 下一发（p45）该做什么（已备料，未构建）

1. **把 EB 段每一步打成屏显**（`[K] eb-go` / `[K] eb-ret` / `[K] bb4` / `[K] posteb-go`），
   因为 `posteb` 记录永远拿不到时只有屏能说话；
2. **异常 dump 不再清屏**（R30 的清屏会把上面这些标记抹掉）——补丁已写好但**没进配方**：
   handler 在子模块 `Silicon/Arm/MU_TIANO`，`git diff` 会把 CRLF 归一化 ⇒ `git apply` 对不上
   （构建脚本用裸 `git apply`）。两种修法：给 `uefi-build-variant.sh` 的 `apply_patch` 加
   `--ignore-whitespace`，或改用 `git diff --binary`/`core.autocrlf=false` 生成补丁。
3. 若 `eb-ret` 不出现 ⇒ 崩在 `gBS->ExitBootServices` 内部（则打印两个指针值再试）；
   若 `posteb-go` 出现而记录仍无 ⇒ `SbWriteLogWindowNoBs` 的缓存句柄在 EB 后确实失效。

## 5. 顺带发现（重要，已进 PITFALLS）

- **工作区静默损坏**：构建时报 `openssl/crypto/evp/legacy_sha.c:192: EVP_{ha512`（正确是 `EVP_sha512`），
  而 `git status` 显示干净、`git fsck` 干净、`git cat-file` 里内容是对的 —— 即**工作区文件被就地改坏
  且 size/mtime 未变**，git 的 stat 缓存因此判定「未修改」。修法：`rm` 掉再 `git checkout --`。
  （`PITFALLS #544`；与 `#512/#513` 同族，但这次是**工作区**而不是页缓存/磁盘。）
- `boot_b` 全程未动（`retry=7 succ=1`，每次崩后 ABL 都没扣，因为 `fastboot boot` 的载荷失败不计入槽位）。

## 6. 纪律补充

- **UEFI 线的每一发必须写清「boot 之后还要 continue」**，否则整发信息量为 0（本轮代价：4 发 + 2 次构建）。
- 判据「屏上有没有 `[K]`」在 fastboot 分支下**天然为假**：先看 `[K] fb-loop` 再谈别的。
