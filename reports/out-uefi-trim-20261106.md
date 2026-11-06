# `out/r21-sbstop` 处置：先记指纹与可复现性缺口，本轮不删（2026-11-06）

> 起因：2026-11-06 整理轮盘点资产时，`out/` 7.9 G 里 **4.8 G 是 `out/r21-sbstop/`**（76 件 × ~65 MiB，UEFI R21 诊断阶梯的中间镜像）。
> 结论：**本轮不删**，改为「记全量 sha256 + 定出保留口径 + 指明真正的缺口（构建配方未脚本化）」。
> 机器指纹已落 `reports/artifacts/uefi-r21-sbstop-trim-20261106/`。

## 0. 为什么不是「直接删」

1. 盘不紧：`df /` = 937 G 总量、**可用 464 G**（48% used）；项目本体 72 G。4.6 G 只占项目 6%，没有腾空间的紧迫性。
2. 这 76 件里有一组**当前在用的活件**：11-06 的 UEFI 判据阶梯复现步骤（`reports/uefi-vsstop-and-fbconsole-20261106.md` §6）
   直接引用 `out/r21-sbstop/uefi-preamble7-r1.img`、`p7-m3-stop34.img`、`p7-m3-stop27.img`。
3. **真正的缺口不是空间，是可复现性**：`p2/p3/p4/p5/p6/r21/fb/pre/vs` 各家族由 `scripts/uefi-r21-sbstop-ladder.sh`
   （`--mkimg-only`，`IMGDIR` 默认就是这里）批量造出，**可重造**；但 **`uefi-preamble7-r1.img` 与 `p7-m3-*` 这一族没有任何脚本产出**
   （`grep -rn 'p7-m3\|preamble7' scripts/` 零命中；报告里只写「preamble7 = R7 mode-3 构建」）⇒ 它们是**事实上不可再生件**。
   在配方脚本化之前删掉，等于把当前活线的基线镜像删了。

## 1. 保留口径（4 件，~270 MiB）

| 文件 | sha256 | 理由 |
|---|---|---|
| `uefi-preamble7-r1.img` | `6ae62bd089d90b49…` | ABL 侧载 UEFI 的入场件（11-06 §6 步骤 1） |
| `p7-m3-stop34.img` | `fe0316d45b6ddb21…` | 窗口下界，`diag st=Aborted last=[vs-34]` |
| `p7-m3-stop27.img` | `1919d0d5f1aeb81d…` | 窗口上界，无应答 = 崩 |
| `p7-s26-pb3.img` | `e8c6230d926d8e7f…` | `sbprobe=3`（只写 `SbLastMark`、不写帧缓冲）通道基件 |

指纹 = `reports/artifacts/uefi-r21-sbstop-trim-20261106/KEPT.sha256`（4 行，`sha256sum -c` 可直接校验）。

## 2. 可归档/可删清单（72 件，4.6 G，**本轮保留、下轮按配方决定**）

- 清单：`reports/artifacts/uefi-r21-sbstop-trim-20261106/del-list.txt`
- 全量指纹：`reports/artifacts/uefi-r21-sbstop-trim-20261106/DELETED-r21-sbstop-20261106.sha256`（72 行）
- 家族分布：`fb`5 / `p2`5 / `p3`4 / `p4`6 / `p5`3 / `p6`4 / `p7-m3`17（除保留 3 件）/ `pre`4 / `r21`6 / `vs`6 / `uefi-preamble[1-6]`6 / `uefi-divers`4
- 处置前提（二者满足其一才动）：
  1. `scripts/uefi-r21-sbstop-ladder.sh --mkimg-only` 能重建该家族（→ 已验证可造 `r21*/p*/`，`p7-m3` 待补配方）；
  2. 该家族的结论已进 SSOT（`TASKS` §5 的 11-04/11-05/11-06 三块 + `PITFALLS #490–#518`），且没有任何活跃脚本/report 的复现步骤引用它。
- 执行命令（下轮直接跑，删前先 `sha256sum -c` 两遍确认指纹未漂）：

```bash
cd ~/y700-elden
(cd reports/artifacts/uefi-r21-sbstop-trim-20261106 && sha256sum -c DELETED-r21-sbstop-20261106.sha256)   # 全 OK 才继续
while read -r f; do rm -f "out/r21-sbstop/$f"; done < reports/artifacts/uefi-r21-sbstop-trim-20261106/del-list.txt
du -sh out/r21-sbstop        # 预期 4.8 G → ~270 M
```

## 3. 下轮要补的「精简修补」（真正的欠账）

`p7-m3` / `uefi-preamble7` 这一族的构建是**手敲命令**（`R7 mode-3` + 逐档改 `sbstop` 常量后再 repack）。
当前活线每一步都依赖它，却无法复现 ⇒ 应新增 `uefi-r21-p7-ladder.sh`（脚本名，待新建）（或给 `uefi-build-variant.sh` 加 `--preamble7 --stages …`），
把「源件 → 每档 img」固化成命令，产出 sha 写进 `reports/artifacts/`。做完这一步，本文件 §2 的 72 件才真正可删。

判据：`bash uefi-r21-p7-ladder.sh --mkimg-only`（待新建） 能在空 `out/r21-sbstop` 下重建 §1 的 4 件，
且与 `KEPT.sha256` **逐字节一致**（不一致就说明配方还缺参数，不要删旧件）。
