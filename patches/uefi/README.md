# `patches/uefi/` — UEFI（G1-29）补丁栈：谁在活线上、谁已经废了

> 本目录是 UEFI 间接引导线 2026-10-28 → 2026-11-06 的全部补丁，**75 个目录 / 98 个 `.patch`**（另含顶层 1 个 BootShim cache 补丁、本文件、`p7…p36-recipe.txt`，以及少量试验件 `.S/.bin/.o`）。
> 逐目录分级（机器可读）= **`../../versions/patches-uefi-status.tsv`**（列：dir / patches / in_recipe / status / 理由 / 证据）。
> 结论：**目录数与分级一律以 `versions/patches-uefi-status.tsv` 现查为准**（本行不写死计数，2026-11-10 收尾时加了 R50–R70 共 14 行补登）。

## 0. 当前世代 = **p69**（含 R70 计时停留）—— **flashed 与 `fastboot boot` 两种形态都已打通（2026-11-10 深夜）**

> **★ 定版（2026-11-10 收尾）**：**p69 = 本线定版件** —— `out/r21-sbstop-p69/uefi-preamble69-r1.img`
> （`38202e129af58cc9d20881115de192d5f988e05e08ed50a39992a761940c4fcc`，67 194 880 B），配方 `p69-recipe.txt`（104 行）。
> 上机判据（flashed 形态，n=3 全部可复现）：总耗时 **129.2 / 129.2 / 131 s**、信标 `R68LOG n=3→4→5 … s9:esp-ld-ok`、`elden_bootloader=esp`。
> **前置条件 = a 槽 `dtbo_a` 全 0**（一次性，用 `scripts/uefi-a-slot-prepare.sh`，幂等、带备份与读回校验）。
> p60–p68 与 R63–R70 的逐目录状态已补登进 `versions/patches-uefi-status.tsv`（2026-11-10 收尾现查）。

> **2026-11-10 深夜（最终口径，覆盖下面两条更正）**：flashed 形态的三年全败**真根因 = `dtbo_a`** —— 原厂 `dtbo_a` 是合法 Android DTBO
> （`D7B7AB1E`/23.3 MB），ABL 在 `BootLinux` 后把它的 overlay 合进**我们的** Linux DTB ⇒ 卡联想 logo、~10 s 回落；`dtbo_b` 早在 10-03 就写成全 0
> ⇒「`_b` 一直好、`_a` 一直坏」。清 `dtbo_a` 后 **p69 写 `boot_a` 直接闭环**：129.2 s（基线 54.5 + R70 **74.3 s**）、
> 信标 `R68LOG n=3 s1:bds-in s2:r54-in s3:blk-enum s4:blk-conn s5:fs-enum s9:esp-ld-ok`、`elden_bootloader=esp`。
> ⇒ **`vbmeta_a` 不是墙**（原厂 Flags 0 照样起），**不要再按下面那条 `vbmeta` 假设做实验**。
> 正文 `reports/uefi-dtbo-a-rootcause-20261110.md`；坑 `PITFALLS #600/#601/#602`。
>
> **2026-11-10 晚更正（已被上条覆盖，保留作被推翻的记录）**：`R70` 的计时判据证明「停留确实执行」，但**不能**判 flashed 形态跑到哪（硬复位剪断）；
> 真正的门槛在更前面 —— 把设备 `boot_b` **逐字节**刷进 `boot_a` 也起不来，而 `avbtool` 显示两槽唯一差异是
> **`vbmeta_a` Flags 0 vs `vbmeta_b` Flags 3** ⇒ 根因假设 = `vbmeta_a` 校验失败导致 ABL 不交棒。
> 正文 `reports/uefi-p69-flashed-and-vbmeta-20261110.md`；坑 `PITFALLS #593–#597`。
>
> **2026-11-10 更正**：11-09 晚又推进了 p63–p66 四代，且**四发写 `boot_a` 全部失败回退 `_b`**；
> 关键对照 = **`p60`（此前在 `fastboot boot` 形态验证过）写 `boot_a` 同样失败** ⇒ flashed 形态的失败
> **与某一个补丁无关**，不要再用「换个补丁再刷一次」的方式试。
> 正文/判据：`reports/uefi-p63-p66-beacon-20261109.md`；TASKS §5「2026-11-09（晚，p63→p66）」块。

| 项 | 值 |
|---|---|
| 最新世代 | **`p69`** = p68(`R69` PrePi `[P00]`+6 s / `[P10]`/`[P11]` 各 3 s 屏停留) + **`20261110R70-prepi-timing`**（PrePi `[P00]`/`[P08]`/`[P10]` 各停 **25 s**，把「回落到 `_b` 的总耗时」当免屏分级判据：0/+25/+50/+75 s）。**已上机（两形态）**：`fastboot boot` +74.3 s（仪器成立），写 `boot_a` +0 s（**被硬复位剪断，不能反证**）⇒ 结论见 `reports/uefi-p69-flashed-and-vbmeta-20261110.md`。上一代 `p68` = p67 + R69（未上机、已被 p69 覆盖）。上一代 `p66` = p65 + `20261109R67-panelhold`（屏上 `[K] R67 blk=<blk 句柄数> fs=<SFS 卷数>` + `Stall(10 s)`，**零依赖**判据通道）；**已构建、上机一发但屏读数未记**（会话中断） |
| 上机跑通的最新一代 | **`p65`/`p64`/`p63`/`p62`** 在 `fastboot boot`（零写盘）形态都能把内核从 ESP 起起来；**flashed 形态全部失败** |
| 信标 | `20261109R66-beacon2`（v2，按内容指纹 `SBLOG0` 认 logfs）**可用**；`20261109R65-beacon`（v1，按容量 4–16 MiB 认分区）**已废**（本机 3 个 8 MiB 分区 ⇒ 必撞车） |
| 复现（一条命令） | `scripts/uefi-r21-p7-ladder.sh --gen p69 --mkimg-only --rebuild`（p69 无指纹，只能重建比关键字串）；`--gen p6{3,4,5,6} --verify` 同法 |
| 构建归档 | p66 `reports/artifacts/uefi-20261109R67-p66/` … p63 `reports/artifacts/uefi-20261109R64-p63/`；p62 `…R63-p62/`、p61 `…R62-p61/` |
| 在盘指纹 | p60/p61 有 `p6{0,1}-kept.sha256`；p62–p66 未出指纹（`--verify` 给「未提供指纹，仅产出」） |
| 历史世代（留作对照） | `--gen p59`（ESP-first 首通）/ `p58`（交棒打通）/ `p54` / `p7`，均 PASS |

**信标的两个硬限制（读判据前必看）**：① v2 的写入 LBA 与内容都是**固定的**（最后 16 KiB 记录区第 2 块），
`st=<n>` 只随检查点变、不含世代/计数 ⇒ 「读到 `st=8`」**不能**证明「这一发跑到了 8」；下一发必须加世代/计数。
② **`st=8 tag=fallback` 不是「走了 fallback」**：R66 里 `R66Beacon(8,"fallback")` 在 `if (!Found)` **之前**，是无条件检查点（下一代必须移进分支内并补 `st=9 esp-ld-ok`，坑 `PITFALLS #589`）。
③ 取证一律 `/dev/disk/by-partlabel/logfs`，`dd` 后断言字节数 = 8 388 608（ssh/dd 会静默短读，曾把唯一一发证据读丢），分析前 `cmp` `0x7FC000` 的 `SBLOG01` 头块（`PITFALLS #587`）。

- **两件套**：整套「跑通路线 B」的件 = **FD**（`--gen p61`）+ **`Loader.efi`**（`patches/uefi/20261109R65-loader-snapshot/`）。
  loader 侧源码**从未提交**（Mu 树单提交浅克隆），此前 R55→R65 的 `.efi` 整体不可再生 ⇒ 2026-11-09 已冻结为整文件快照
  （含基线 `6b6ac42a`、放回路径、`stuart_build` 命令；产物对应 `Loader-r65.efi` `3523b320…`）。见 `PITFALLS #574`。
- **新世代从 `p66-recipe.txt` 派生**（p62–p66 是链式追加，`p60` 起每代一行；历史世代仍可 `--gen pNN`）（p58 起 `SdccDxe` 三处全摘已是基线，`PITFALLS #554`）。
  ⚠ 2026-11-09 之前本节写的是 p58：p59/p60/p61 一度只能靠手敲 `PFX=/RECIPE=/BUILD_DIR=/KEPT=` 四件套复现
  ⇒ 现在 `--gen` 已把 p60/p61 也绑好（手敲漏 `BUILD_DIR` 会静默退回 R7 归档造错件，`#520` 同族）。
  摘任何 DXE 件仍须三处清单同步（`APRIORI.inc`/`DXE.inc`/`DXE.dsc.inc`，`PITFALLS #554`）。
- 其他世代（p54 及更早）的命令行四件套（`PFX=`/`RECIPE=`/`BUILD_DIR=`/`KEPT=`）仍可手敲，
  但 `--gen` 已把它们绑好——手敲最容易漏 `BUILD_DIR`，那会静默退回 R7 归档造出错件（`#520` 同族）。
- 这些补丁里 **R47/R48/R49（关看门狗）与 R50–R52（看门狗探针）已被证伪**，但仍在 p58 配方里；
  它们是「无效但无害的调用」。想做「干净世代」需删掉后再上机 1 发复验，属可选收尾，不影响当前可用性。

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
  —— 修 `PITFALLS #534` 的刷屏、EB 后用缓存 `BlkIo` 转储 `tag=posteb`）。**那一轮的活线是 p36**（历史）。
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

- **2026-11-07 深夜 世代（p46，✅ 上机成功：UEFI 路径真起内核）**：
  `p46` = `p45` + `R41-noebdump`（删掉 `SbDumpLogNoBs("posteb")` 整段 —— p45 实锤 EB 之后
  `BlkIo->WriteBlocks` 读出 0 ⇒ `blr 0`；并给 `PreparePlatformHardware()` 加 `pph-go`/`pph-ok`）。
  配方 `p46-recipe.txt`；镜像 `out/r21-sbstop-p46/uefi-preamble46-r1.img`（`e78b86bc…`）；
  上机账/证据 `reports/uefi-p46-kernel-boot-success-20261107.md`。**纪律：UEFI 路径必须
  `fastboot boot` 之后再发 `fastboot continue`；且内核 cmdline 来自 `boot_b` 头部，
  `sbstop=`/`sbprobe=` 走这条路无效（`PITFALLS #547`）。**

- **2026-11-07 深夜·三 世代（p58，✅ 间接引导打通）**：
  `p58` = `p54` + `20261107R46-nosdcc`（`DXE.inc` 注掉 `SdccDxe`）+ `20261107R53-nosdcc-all`
  （`APRIORI.inc` + `DXE.dsc.inc` 同步注掉 —— 只改 `DXE.inc` 会被 APRIORI 拉回 FV，单变量白做）。
  真因 = `SdccDxe` 抢初始化 SD 主控（`8804000.mmc`）→ 内核接手 `mmc0: ADMA error` → 整机硬复位。
  配方 `p58-recipe.txt`（76）；镜像 `out/r21-sbstop-p58/uefi-preamble58-r1.img`（`d76ede27…`）；
  报告 `reports/uefi-p58-sdccdxe-handoff-success-20261107.md`；坑 `PITFALLS #554/#555`。
  ⚠ 摘任何 DXE 件都要三处清单同步（`APRIORI.inc`/`DXE.inc`/`DXE.dsc.inc`）。

## 2. 重建与"可复现"的精确含义

```bash
scripts/uefi-r21-p7-ladder.sh --list          # 看配方/在盘指纹/会产出什么
scripts/uefi-r21-p7-ladder.sh --gen p58 --verify   # 秒级：按世代复现并与 p58-kept.sha256 逐件比 sha（rc=0 = 可复现）
scripts/uefi-r21-p7-ladder.sh --verify        # 等价 --gen p7（历史默认）
scripts/uefi-r21-p7-ladder.sh --gen p58 --mkimg-only    # 按世代写入该世代目录（p58 → out/r21-sbstop-p58/）
scripts/uefi-r21-p7-ladder.sh --mkimg-only --rebuild   # 从配方重建 UEFI（sha 必变，见下）
```

- **镜像段逐字节可复现**：基点是归档的 `reports/artifacts/uefi-20261105R7-markonly/`（FD 已入 git）。
- **构建段不逐字节可复现**：`--rebuild` 两次 FD 必不同（`__DATE__`/`__TIME__` 及其立即数偏移，
  `PITFALLS #510`）⇒ 重建后**不要比 sha**，只验关键字串与"逐块 diff 只落在时间字符串区"。

## 3. 纪律

- 新增补丁 = 新目录 + 进当前世代的配方（**现在从 `p61-recipe.txt` 派生**）+ 跑 `--verify`；
  改活线时优先**新建世代配方**（p62…）而不是就地改 `p61-recipe.txt`——p61 是在盘件与
  `p61-kept.sha256` 的唯一复现基点。
  **不要**把新补丁只塞进某个报告然后靠记忆重放（2026-11-06 的四件活线镜像就是这么差点变成不可再生件）。
- 本目录里除 `p7-recipe.txt` 与本文件外，**不应出现构建产物**；`20261103-posctrl/` 下的
  `markspin*.S/.bin/.o` 是该轮 BootShim 试验件的既有遗留，勿扩散。
