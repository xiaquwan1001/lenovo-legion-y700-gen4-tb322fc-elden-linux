# `patches/uefi/` 分级 + p7 配方脚本化 + `out/r21-sbstop` 清仓（2026-11-06 第二轮）

> 用户 2026-11-06：「按推荐顺序继续」（上一轮整理给出的下一轮入口 ①→④；①②为 UEFI 线、纯主机侧）。
> 本轮做完 **②（配方脚本化）** 与 **③（patches/uefi 分级）**，并因此**解锁并执行**了上轮挂起的
> `out/r21-sbstop` 清仓（4.6 G）。①（探针 35 上机）需设备 + 崩溃后物理断电，留给你在场时做。

## 0. 数字结论

| 项 | 前 | 后 | 判据 |
|---|---|---|---|
| `out/r21-sbstop` | 76 件 / **4.8 G** | **4 件 / 257 M** | 逐件 sha256 先校验再删（72 件全 OK） |
| `out/` 总体 | 7.9 G | **3.1 G** | `du -sh out` |
| p7 配方可复现性 | **无脚本**（`grep 'p7-m3\|preamble7' scripts/` 零命中） | `--verify` **rc=0**，4 件逐字节相同 | `scripts/uefi-r21-p7-ladder.sh --verify` |
| `patches/uefi/` | 45 目录，无分级 | **ACTIVE 25 / RETIRED 18 / UNCLEAR 0** | `versions/patches-uefi-status.tsv` |

## 1. 配方脚本化（②，考据 → 结论）

三步拆解，每步都**实测**过：

| 步 | 结论 | 证据 |
|---|---|---|
| ① UEFI 变体构建 | 配方 = R7 manifest 的 35 个补丁 + `--scale 3 --shim stock`，已导出为 `patches/uefi/p7-recipe.txt` | `reports/artifacts/uefi-20261105R7-markonly/manifest.txt` |
| ② repack → `uefi-preamble7-r1.img` | **逐字节可复现**（用归档 R7 构建目录） | `uefi-repack-v2aligned.py` → sha `6ae62bd0…` = 在盘件 |
| ③ 逐档写 cmdline | 令牌是**两个**：`sbstop=N sbprobe=3 `（19 B 前缀）；旧 `uefi-sbstop-patch.py` 只会写一个 ⇒ 补 `--probe N` | `--probe 3` 后 `p7-s26-pb3`/`p7-m3-stop34` sha 与在盘件相同 |

新脚本 `scripts/uefi-r21-p7-ladder.sh`：`--list` / `--verify`（秒级，默认用归档构建目录）/
`--mkimg-only [--outdir]` / `--mkimg-only --rebuild`（从配方重建）/ `--stages "26 34"`。

**「可复现」的边界（重要，别再误承诺）**：
- **镜像段**逐字节可复现（基点是归档 FD，已入 git）。
- **构建段不逐字节可复现**：`--rebuild` 两次 FD 必不同（`__DATE__`/`__TIME__` 及立即数偏移），
  这是**既有**结论 `PITFALLS #510`；本轮实测再次确认（payload gz 2438369 B vs 归档 2438368 B，差 1 字节）。
  ⇒ 重建后不要比 sha，只验关键字串 + 「逐块 diff 只落在时间字符串区」。

## 2. `patches/uefi/` 分级（③）

方法：**in_recipe = 与 `p7-recipe.txt` 求交**（客观、可机器算），理由逐条读报告。
产出 = `versions/patches-uefi-status.tsv`（43 行）+ `patches/uefi/README.md`（人读面：怎么区分、怎么重建、纪律）。

- **ACTIVE 25 目录**（= 活线累积栈，35 个补丁按序）：`20261104-dxe`(8)、`20261104R21-hostdiag`、
  `20261105-{diagentry,finebisect,vsbisect}`、`20261105R2..R7` 等。
- **RETIRED 18 目录**（结论已推翻/已被取代，补丁留档勿再应用）：
  `20261103-v4header`（ABL 拒 v3/v4）、`20261031-{vis,prepi-vis}`（屏显通道判废）、
  `20261101-ddr`/`20261102-ddr-clean`/`20261103-posctrl`（DDR 黑匣子不可用；`text_offset=0` 已固化进 repack 脚本）、
  `20261104-{fbfill,fbband,m3block,prog,nocivac,dual}`（早期 payload 探针，真因 = `#497` copy-length）、
  `20261104R-pstore`（`#414` pstore 不能当通道）、`20261104R{11,12}`（被 R13 loaderstart 取代）、
  `20261104R{4,5,6}`（异常打印探针从未命中）。
- **顺带**：删掉空目录 `patches/uefi/20261028-visibility/`（0 文件、0 引用）。

## 3. 清仓（上轮的闸，现在满足）

上轮拒绝删的理由是「p7 一族不可再生」；②完成后该前提消失，故执行：

```bash
cd out/r21-sbstop && sha256sum -c ../../reports/artifacts/uefi-r21-sbstop-trim-20261106/DELETED-*.sha256 --quiet  # 72/72 OK
while read -r f; do rm -f "$f"; done < ../../reports/artifacts/uefi-r21-sbstop-trim-20261106/del-list.txt
```

保留 4 件（`KEPT.sha256`）：`uefi-preamble7-r1.img`、`p7-m3-stop{27,34}.img`、`p7-s26-pb3.img`。
**注意**：`--mkimg-only` 随时可按配方重建这 4 件，所以它们也不再是"不可再生件"，只是"省一次构建"的缓存。

## 4. 未做（下一轮）

- **① 探针 35（`MarkPtnActive()` 之后）单发定案**：需要设备在 fastboot + 崩后**物理断电**（用户在场）。
  件可用 `scripts/uefi-r21-p7-ladder.sh --stages "34 35 27" --mkimg-only` 造（35 需先在
  `patches/uefi/20261104R20-stage-bisect/0001` 里加档再进 `p7-recipe.txt`）。
- **④ 10 个 >1500 B 单元格下沉**：方案已在 `reports/doc-audit-20261106.md` §2，未动。
