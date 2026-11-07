# `patches/uefi/` — UEFI（G1-29）补丁栈：谁在活线上、谁已经废了

> 本目录是 UEFI 间接引导线 2026-10-28 → 2026-11-06 的全部补丁，**75 个目录 / 98 个 `.patch`**（另含顶层 1 个 BootShim cache 补丁、本文件、`p7…p36-recipe.txt`，以及少量试验件 `.S/.bin/.o`）。
> 逐目录分级（机器可读）= **`../../versions/patches-uefi-status.tsv`**（列：dir / patches / in_recipe / status / 理由 / 证据）。
> 结论：**ACTIVE 31 目录 / RETIRED 18 目录 / UNCLEAR 0**。

## 1. 怎么区分（唯一判据：在不在这份配方里）

活的判据不是「报告里夸过它」，而是**它在不在当前构建配方里**：

- 配方 = **`p7-recipe.txt`**（本目录），35 个补丁、**顺序敏感**，从
  `reports/artifacts/uefi-20261105R7-markonly/manifest.txt` 逐字导出（2026-11-06T09:19:38 构建）。
- 消费它的唯一入口 = **`scripts/uefi-r21-p7-ladder.sh`**（`--mkimg-only` / `--verify` / `--list`）；
  它产出当前活线用的 4 件：`uefi-preamble7-r1.img`、`p7-m3-stop{27,34}.img`、`p7-s26-pb3.img`。
- 判据（2026-11-06 实测）：`scripts/uefi-r21-p7-ladder.sh --verify` **rc=0**，四件 sha256 与在盘件**逐字节相同**。
- **世代叠加（2026-11-06 新增）**：`p8-recipe.txt` = `p7` + `20261106-vsstop35`（FindBootableSlot 尾段
  `VS_STOP(35..38)`）；`p9-recipe.txt` = `p8` + `20261106R2-gate-outwrite`（把 `out:` 那条 R15 诊断写纳入
  `SbProbeMode`）。**p7 保持不动**（在盘件仍靠它逐字节复现）；新世代的件名/构建目录用
  `PFX=p8 RECIPE=…p8-recipe.txt BUILD_ARCHIVE=… scripts/uefi-r21-p7-ladder.sh --mkimg-only --rebuild`。
  静态判定与上机排产见 `reports/uefi-vsstop35-tail-static-20261106.md`。
- **上机世代（2026-11-06 傍晚）**：`p10` = p9 + `20261106R3-bootlinux-eb`（EB 前后标记 40/41/42）；
  `p11` = p10 + `20261106R4-real-boot`（`SbProbeMode` 默认 3 + 去掉 R18 的 `CpuDeadLoop`，= **真启动件**）；
  `p12` = p11 + `20261106R5-jump-banner`（跳内核前强制一行屏显）。上机结论见
  `reports/uefi-onboard-walkthrough-20261106.md`（含「EB 后宿主判据失效」与「一会话一发电平 ≥40」两条纪律）。
  `p13` = p12 + `20261106R6-eb-banners`（`--scale 1` 的四行 banner：A pre-EB / B post-EB / C post-PPH / D JUMP），
  **仅用于屏上定位、字号小需拍照判读**。**⚠ 2026-11-06 深夜判定：p13 的判据设计错** —— 四行全在
  `BootLinux()` 内，而当时的崩点在它之前，上机只会"四行全无"、信息量为 0（未上机即作废）。
- **2026-11-06 深夜世代链（p14→p24，全部上机过）**：
  `p14`=p12+`R7-cmdboot-progress`（单行进度字符，scale 1，字太小读不出）；
  `p15`=p14+`R8-progress-accum`（累积串每步重打，scale 3）；
  `p16`=p15+`R9-dual-channel`（`SbProgRaw` 不 flush + `FastbootFail("ret-after-lia")` 早退）；
  `p17`=p12+`R10-ret-after-lia`（零屏显写、LIA 返回即回话）；
  `p18`=p17+`R11-lia-tail`（LIA 尾部 `VS_STOP 43..45`）；
  **`p19`=p18+`R12-probemode-guard` ← 关键修复**（只有带 `sbstop=` 令牌才改 `SbProbeMode`；
  详见 `README-p19-p20-NOTE.md`）；`p20`=p19 去早退（全路径）；
  `p21`=p20+`R13-skip-usbstop`（跳过 `FastbootUsbDeviceStop()`，**被否证**）；
  `p22`=p21+`R14-eb-oneline`（EB 后同行 `B/C/D` 覆盖标记，被 dump 冲掉读不出）；
  `p23`=p21+`R15-eb-halt`（EB 后打 `[K] EB-OK st=` 再 `CpuDeadLoop()`，仍崩 ⇒ 不在 EB 内）；
  `p24`=p21+`R16-no-eb`（**完全跳过 EB** 只停机，仍崩 `0xCFE98C84` ⇒ 崩点在第三方二进制驱动里）。
  上机判据账 `reports/artifacts/real-vs-ladder-20261106T21*.tsv`；会话
  `TASKS/sessions/2026-11-06-UEFI真启动崩溃真因-探针写屏.md`。

不在配方里的 18 个目录**不是"待用"，是"已废"**——它们各自服务的通道/结论都已推翻，逐条理由在 tsv 里，
列几条最容易再次被想起的：

| 目录 | 为什么别再用 |
|---|---|
| `20261103-v4header/` | ABL 静默拒 v3/v4 头（`PITFALLS #387/#418`）；现一律 v2 + base 0 |
| `20261031-vis/`、`20261031-prepi-vis/` | 屏显通道判废：`ConOut` no-op + 帧缓冲写穿（`PITFALLS #514/#515`） |
| `20261101-ddr/`、`20261102-ddr-clean/`、`20261103-posctrl/` | DDR 读回恒 `0xFF`（黑匣子不可用）；`text_offset=0` 已固化进 `scripts/uefi-repack-v2aligned.py`，不再需要补丁 |
| `20261104-{fbfill,fbband,m3block,prog,nocivac,dual}/` | 早期 payload 执行探针，真因是同一条 copy-length 缺陷（`PITFALLS #497`） |
| `20261104R-pstore/` | pstore/pmsg **不能**当取证通道（`PITFALLS #414`） |
| `20261104R{11-bdsprobe,12-sfsprobe}/` | 被 `R13-loaderstart`（进 FV 里的 `LinuxLoader`）取代 |
| `20261104R{4-excprint,5-excnoscroll,6-excimg}/` | 异常打印探针：DXE 异常从未走到打印路径 |

- **2026-11-06 夜·五世代链（p34→p36，全部上机过）**：
  `p34` = p33 + `R29-fbgeometry`（帧缓冲控制台改**像素语义**几何，关 `PITFALLS #532`）+ `R30-faultdump`
  （异常归因两档：`[K] FLT …esr/far` → 清屏重钉 → `[K] sp=` → x0..x28/FP/LR，不读栈内存）；
  `p35` = p34 + `R31-logfsdump`（控制台环形日志 + `logfs` 尾部 16 KiB 转储 + `oem sbread:<off>:<len>`）；
  `p36` = p35 + `R32-ringshared`（环放 **`0xE3F80000` 全固件共享**、`[F]` 自检**只进环不上屏**
  —— 修 `PITFALLS #534` 的刷屏、EB 后用缓存 `BlkIo` 转储 `tag=posteb`）。**当前活线 = p36**。
  上机账与判据：`reports/uefi-p34-p36-logfs-20261106.md`；宿主读端 `scripts/uefi-logfs-read.py`。
  ⚠ 纪律：`oem sbread` 一次 ≤512 B、块间 sleep（连读 1200 B 会把 USB 端点打死，`PITFALLS #537`）；
  真内核件（82 MB）仍**一会话一发**。

- **2026-11-07 世代（p37→p38，p38 已构建、未上机）**：
  `p37` = p36 原样件（无新构建）上机真内核载荷 ⇒ 拿到 `preeb`、**拿不到 `posteb`**，屏上
  `[K] FLT pc=00000000 esr=86000007`（见 `reports/uefi-p37-logfs-20261107.md`）。
  `p38` = p36 + `R33-true-nobs`（**修 R32 的伪 NoBs**：`SbDumpLogNoBs()`/`SbWriteLogWindowNoBs()`
  仍用 `AllocatePool/FreePool`，EB 后 `gBS` 已死 ⇒ `blr` 到 0；并修 NoBs 版 LBA 单位漏改），
  另加 EB 前后环内标记 `[K] BL-in` / `BL-vm=` / `gbs=…` / `EBC-call` / `EBC-ret0|ret!` / `post gbs=`。
  配方 `p38-recipe.txt`；镜像 `out/r21-sbstop-p38/uefi-preamble38-r1.img`（`0e2bddbd…`）；
  静态复核 `reports/uefi-p38-static-verify-20261107.md`（PASS）；上机单 `reports/uefi-p38-true-nobs-20261107.md` §2。

- **2026-11-07 世代（p39→p43，全部上机过）**：
  `p39` = p38 + `R34-screenmarks`（`pre-BL`/`BL-in`/`preeb-go`/`preeb-ok` 改成**屏显**；去掉 R33 的入口大转储）；
  `p40` = p39 + `R35-fastboot-branch`（`flags`/`LIA st`/`goto-fastboot`，打在进 fastboot **之前**——会被随后的
  USB 洪水冲掉）；`p41` = p40 + `R36-fastboot-loopmark`（把判据搬到 `FastbootInitialize()` 的循环里，
  屏上 `[K] fb-loop LIA=… flags=…`）；`p43` = p41 + `R38-cached-dump`（`SbDumpLog` 先走缓存 BlkIo 直写）。
  **关键纪律**：本树 `BootIntoFastboot` 写死 TRUE ⇒ `fastboot boot` 之后**必须再发 `fastboot continue`**
  才会走 `BootLinux`（前四发就是漏了这一步）。崩点与判读见 `reports/uefi-p39-p43-continue-20261107.md`。

- **2026-11-07 夜 世代（p45，已构建、静态复核 PASS，未上机）**：
  `p45` = `p43` + `R39-ebscreen`（`SbDumpLog` 内三步上屏 `dump-in`/`dump-ring-ok`/`dump-write`，
  EB 段每步上屏 `eb-go`/`eb-ret`/`bb4`/`posteb-go`/`posteb-ok`）+ `R40-noclear`（异常 dump
  **不再清屏**——R30 的清屏会抹掉崩溃前全部 `[K]` 标记）。配方 `p45-recipe.txt`；镜像
  `out/r21-sbstop-p45/uefi-preamble45-r1.img`（`fbde3a70…`）；报告
  `reports/uefi-p45-ebscreen-prebuilt-20261107.md`。**同一轮把 `apply_patch()` 加了
  `--ignore-whitespace` 兜底、`revert_patch()` 不再吞错（`PITFALLS #545`）。**

## 2. 重建与"可复现"的精确含义

```bash
scripts/uefi-r21-p7-ladder.sh --list          # 看配方/在盘指纹/会产出什么
scripts/uefi-r21-p7-ladder.sh --verify        # 秒级：用归档构建目录 repack，逐字节比对（rc=0 = 可复现）
scripts/uefi-r21-p7-ladder.sh --mkimg-only    # 写入 out/r21-sbstop/
scripts/uefi-r21-p7-ladder.sh --mkimg-only --rebuild   # 从配方重建 UEFI（sha 必变，见下）
```

- **镜像段逐字节可复现**：基点是归档的 `reports/artifacts/uefi-20261105R7-markonly/`（FD 已入 git）。
- **构建段不逐字节可复现**：`--rebuild` 两次 FD 必不同（`__DATE__`/`__TIME__` 及其立即数偏移，
  `PITFALLS #510`）⇒ 重建后**不要比 sha**，只验关键字串与"逐块 diff 只落在时间字符串区"。

## 3. 纪律

- 新增补丁 = 新目录 + 进当前世代的配方（`p7…p13-recipe.txt`，若要留在活线上）+ 跑 `--verify`；
  改活线时优先**新建世代配方**（p8/p9）而不是就地改 `p7-recipe.txt`——p7 是在盘四件的唯一复现基点。
  **不要**把新补丁只塞进某个报告然后靠记忆重放（2026-11-06 的四件活线镜像就是这么差点变成不可再生件）。
- 本目录里除 `p7-recipe.txt` 与本文件外，**不应出现构建产物**；`20261103-posctrl/` 下的
  `markspin*.S/.bin/.o` 是该轮 BootShim 试验件的既有遗留，勿扩散。
