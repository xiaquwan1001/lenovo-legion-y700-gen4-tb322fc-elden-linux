# 资产清理执行账（2026-11-09）

> 用户 2026-11-09 批准「可以删掉冗余文件」。本账逐项记录**删了什么、为什么、证据在哪、怎么重建**。
> 候选清单来源 = `.pi/plans/2026-11-09-整理候选清单.md`；判据 = 对应世代/判据已被后续世代取代且结论已入 SSOT。

## 1. 删除前空间
/dev/nvme0n1p2  937G  519G  371G   59% /

## 2. 已删除（逐项）

| 路径 | 体量 | 理由 | 结论去处 |
|---|---|---|---|
| `out/r21-sbstop-p8/` | 513 M / 8 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p9/` | 1090 M / 17 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p9m1/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p10/` | 449 M / 7 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p11/` | 257 M / 4 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p12/` | 193 M / 3 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p13/` | 193 M / 3 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p14/` | 641 M / 10 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p15/` | 641 M / 10 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p16/` | 257 M / 4 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p17/` | 193 M / 3 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p18/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p19/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p20/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p21/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p22/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p23/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p24/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p25/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p26/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p27/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p28/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p29/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p30/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p31/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p32/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p33/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p34/` | 193 M / 3 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p35/` | 193 M / 3 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p36/` | 193 M / 3 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p38/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p39/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p40/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p41/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p43/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p45/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p46/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p47/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p48/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p49/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p50/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p51/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p52/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/r21-sbstop-p53/` | 129 M / 2 件 | 判死世代（结论已进 `TASKS` §5 对应块与 `PITFALLS`）；p54–p61 保留 | `patches/uefi/pNN-recipe.txt` + `reports/` 同名报告 |
| `out/real-ladder/` | 1935 M | 历史取证目录，结论已固化进 `PITFALLS`/`TASKS` §5 与对应报告正文 | 报告正文（见 `reports/uefi-*-2026110{1,7}.md`） |
| `reports/artifacts/uefi-ddr-20261101/` | 100 M | 历史取证目录，结论已固化进 `PITFALLS`/`TASKS` §5 与对应报告正文 | 报告正文（见 `reports/uefi-*-2026110{1,7}.md`） |
| `reports/artifacts/uefi-ddrcut-20261101/` | 122 M | 历史取证目录，结论已固化进 `PITFALLS`/`TASKS` §5 与对应报告正文 | 报告正文（见 `reports/uefi-*-2026110{1,7}.md`） |
| `reports/artifacts/uefi-posctrl-20261103/` | 133 M | 历史取证目录，结论已固化进 `PITFALLS`/`TASKS` §5 与对应报告正文 | 报告正文（见 `reports/uefi-*-2026110{1,7}.md`） |
| `reports/artifacts/uefi-20261107R33-p38/` | 26 M | 历史取证目录，结论已固化进 `PITFALLS`/`TASKS` §5 与对应报告正文 | 报告正文（见 `reports/uefi-*-2026110{1,7}.md`） |
| `reports/artifacts/uefi-20261107R34-p39/` | 26 M | 历史取证目录，结论已固化进 `PITFALLS`/`TASKS` §5 与对应报告正文 | 报告正文（见 `reports/uefi-*-2026110{1,7}.md`） |
| `reports/artifacts/uefi-20261107R35-p40/` | 26 M | 历史取证目录，结论已固化进 `PITFALLS`/`TASKS` §5 与对应报告正文 | 报告正文（见 `reports/uefi-*-2026110{1,7}.md`） |
| `reports/artifacts/uefi-20261107R36-p41/` | 26 M | 历史取证目录，结论已固化进 `PITFALLS`/`TASKS` §5 与对应报告正文 | 报告正文（见 `reports/uefi-*-2026110{1,7}.md`） |
| `reports/artifacts/uefi-20261107R38-p43/` | 35 M | 历史取证目录，结论已固化进 `PITFALLS`/`TASKS` §5 与对应报告正文 | 报告正文（见 `reports/uefi-*-2026110{1,7}.md`） |
| `reports/artifacts/uefi-20261107R39R40-p45/` | 26 M | 历史取证目录，结论已固化进 `PITFALLS`/`TASKS` §5 与对应报告正文 | 报告正文（见 `reports/uefi-*-2026110{1,7}.md`） |
| `out/boot-elden.img` | 85 M | doctor §5 WARN：内核段解不出（明确勿据其判构建身份）/ 无版本号默认产物 | 需重建时按 `scripts/build-boot.sh` |

## 3. 删除后空间
/dev/nvme0n1p2  937G  508G  382G   58% /

## 4. 保留说明
- `out/r21-sbstop`（p7 件，含不可再生的 `uefi-preamble7-r1.img`）与 `out/r21-sbstop-p54…p61` **保留**：前者是 `--gen p7 --verify` 的基点，后者可 `--gen pNN --verify` 逐字节复现。
- `reports/artifacts/uefi-ddrcut-20261101/lun4-gpt-{primary,backup}.bin`（**设备 GPT 原始双表**）删前已复制到 `backup/lun4-gpt-20261101/`（含 `SHA256SUMS`）：`84efc47d…` / `7d4e7feb…`。
- `.pi/trash`（5.3 G）、`backup/`、`.pi/sessions` 按用户 2026-11-06 裁决不动。

## 5. 引用这些路径的文档
- 门禁文档（`TASKS/INDEX/DEVICE/PITFALLS`）里仍指向已删目录的 token 已**逐条处理**：`TASKS` 两处（`out/r21-sbstop-p38`、`out/r21-sbstop-p45`）改成「见 §5 报告」的写法，并在 `scripts/doc-assets-allowlist.txt` 登记理由。
- `reports/*.md` 里的历史路径不追改（报告是当时的现场记录）；读者按本账就能知道文件去哪了。
