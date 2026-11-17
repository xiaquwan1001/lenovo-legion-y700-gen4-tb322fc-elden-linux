# 门禁（2026-11-17 本 lane 实跑，原始日志在同目录 `logs/`）

系列 = `0001`+`0002`；基线 = **7.4-rc3 `aebb727447` + kaanapali v25 `[01/15]`–`[03/15]`**。

## 0. 基线说明（别让门禁看起来比实际强）

- 上游 `gh/master`（= `aebb727447`，7.4-rc3 final）**无法整树导出**：`build/m3v2-7.3rc7` 的 `.git` pack 有 3 个坏 object
  （`worktree add` / `archive` 都中途失败，v1 的 `GATES.md` §0 已记）。⇒ 与 v1 同样走两条替代路径，**被改的 4 个文件内容一律是 `git show aebb727447:<path>` 的 blob 原文**：
  | 用途 | 树 | 说明 |
  |---|---|---|
  | ①②⑥（apply/checkpatch/am） | `/tmp/csiphy2/git` | 只有这 4 个文件，`git init` 后 commit 成 `base`，再 `git apply` v25 01–03 成 `86e8cec`（前缀） |
  | ③④（编译/dt_binding_check） | `/tmp/csiphy2/build` | `rsync -a --exclude=.git build/m3v2-7.3rc7/`（7.3-rc7 + payload，本就可编译）后**把这 4 个文件覆盖成本系列终态** |
- 因此 ③ 证明的是「这 4 个文件的 7.4-rc3 内容 + v25 前缀 + 本系列，在 arm64 `W=1` 下无 warning」，
  **不是**「整棵 7.4-rc3 全绿」。`build/m3v2-7.3rc7` 本身零改动。
- v25 三枚前缀是**从 lore 取回原文**再 `git apply`（`logs/v25-0{1,2,3}-*.patch`），
  不是手抄：`lore-fetch-raw.py linux-media 20261112-kaanapali-camss-v25-{1,2,3}-1d709f57f370@oss.qualcomm.com`。

## 1. `git apply --check` + `git am`（前缀树上）

```
$ git checkout 86e8cec
$ git apply --check -v 0001-*.patch 0002-*.patch      → rc=0（4 个文件逐个 OK）
$ git am 0001-*.patch 0002-*.patch                    → 2/2 干净落地，rc=0
  0001 = 3 行 / 0002 = 137+1+1 行
```
原始日志：`logs/01-apply-check.log`。

## 2. `checkpatch.pl --strict`

```
0001  total: 0 errors, 0 warnings, 0 checks,   9 lines checked
0002  total: 0 errors, 0 warnings, 0 checks, 163 lines checked
```
用 `--no-tree`（树里没有本系列落地后的 binding，`--no-tree` 关掉「compatible 未文档化」的树内 grep 假阳性；
`--no-signoff` 只关「必须带 SoB」，SoB 在补丁里本来就有）。
原始日志：`logs/02-checkpatch-0001.log`、`logs/02-checkpatch-0002.log`。
踩过的两条（v1 期间）：长行 `>{100}` 与「结构体后缺空行」；本版两项 `checkpatch` 已 0。

## 3. `W=1` 编译 `drivers/phy/qualcomm/`

```
$ make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j6 W=1 drivers/phy/qualcomm/
  CC [M] drivers/phy/qualcomm/phy-qcom-mipi-csi2-core.o
  CC [M] drivers/phy/qualcomm/phy-qcom-mipi-csi2-3ph-dphy.o
  ...
  LD [M] drivers/phy/qualcomm/phy-qcom-mipi-csi2.o
rc=0；`grep -icE 'warning:|error:'` = 0（17 个 CC 行）
```
`CONFIG_PHY_QCOM_MIPI_CSI2=m`（.config 第 10694 行）、`CONFIG_ARCH_QCOM=y`，未跑 `olddefconfig`。
原始日志：`logs/10-build-W1.log`。

## 4. `dt_binding_check`（改了 binding ⇒ 必跑）

```
$ make ARCH=arm64 dt_binding_check DT_SCHEMA_FILES=Documentation/devicetree/bindings/phy/qcom,x1e80100-csi2-phy.yaml
  SCHEMA / CHKDT / LINT / STYLE / DTEX / DTC [C] …example.dtb
rc=0
```
原始日志：`logs/30-dt_binding_check.log`。

## 5. 表内容对账（13/13 差异 + vendor 103/103 全等）

```
$ python3 logs/verify-table.py /tmp/csiphy2/build/drivers/…/phy-qcom-mipi-csi2-3ph-dphy.c \
      /tmp/csiphy2/git/drivers/…（前缀态，无 sm8750 表） backup/stock-elden/vendor_dlkm/camera.ko
lane_regs_sm8750 entries: 105 (2ph power-up 2 + data/clock lanes 103)
lane_regs_x1e80100 entries: 105
address sequence identical: True
differing entries: 13            ← 4 DEFAULT + 5 SETTLE + 4 SKEW
vendor csiphy_2ph_v2_4_0_reg: 103 entries
address set equal (sm8750 vs vendor): True
(addr,data,type) multiset equal: True
```
原始日志：`logs/40-table-diff.txt`。

## 门禁汇总

| # | 门禁 | 结果 |
|---|---|---|
| ① | 前缀树上 `git apply --check` | **rc=0**（2/2） |
| ② | `checkpatch --strict` | **0E/0W/0C**（0001 9 行、0002 163 行） |
| ③ | `W=1` 编译 `drivers/phy/qualcomm/` | **rc=0，0 warning** |
| ④ | `dt_binding_check` | **rc=0** |
| ⑤ | 表对账 | **13/13**，与 vendor 2.4.0 表 **103/103** 全等 |
| ⑥ | `git am` 实跑 | **2/2 干净** |
| ⑦ | **上机出流回归** | ❌ **未做**（本 lane 只做静态门禁；投标前必须补或显式声明无实测） |
