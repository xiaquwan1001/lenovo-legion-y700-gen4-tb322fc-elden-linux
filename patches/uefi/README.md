# `patches/uefi/` — UEFI（G1-29）补丁栈：谁在活线上、谁已经废了

> 本目录是 UEFI 间接引导线 2026-10-28 → 2026-11-06 的全部补丁，**45 个目录 / 67 个 `.patch`**（另含顶层 1 个 BootShim cache 补丁、本文件、`p7/p8/p9-recipe.txt`，以及少量试验件 `.S/.bin/.o`）。
> 逐目录分级（机器可读）= **`../../versions/patches-uefi-status.tsv`**（列：dir / patches / in_recipe / status / 理由 / 证据）。
> 结论：**ACTIVE 27 目录 / RETIRED 18 目录 / UNCLEAR 0**。

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

- 新增补丁 = 新目录 + 进当前世代的配方（`p7/p8/p9-recipe.txt`，若要留在活线上）+ 跑 `--verify`；
  改活线时优先**新建世代配方**（p8/p9）而不是就地改 `p7-recipe.txt`——p7 是在盘四件的唯一复现基点。
  **不要**把新补丁只塞进某个报告然后靠记忆重放（2026-11-06 的四件活线镜像就是这么差点变成不可再生件）。
- 本目录里除 `p7-recipe.txt` 与本文件外，**不应出现构建产物**；`20261103-posctrl/` 下的
  `markspin*.S/.bin/.o` 是该轮 BootShim 试验件的既有遗留，勿扩散。
