# 磁盘清理第二轮执行账 — 2026-11-16（承接 `reports/disk-cleanup-20261115.md`）

> 口径：只处理 11-15 报告「待第二轮」清单中**用户已批准**的 6 组项；三个只评估项不动；硬排除全程未触碰。
> 本轮起点：`df -h /` = 937G 总 / 632G 已用 / 259G 可用（第一轮后状态）；项目 `du -sh` = 82G。

## 1. 执行记录（先 du -sb → 删 → 核消失）

| 项 | 路径 | 删前 du -sb (B) | 删后核对 |
|---|---|---|---|
| R1 | stock-src/ | 2 105 289 516 | 已消失 |
| R2 | dl-cam/ndk/ | 1 692 297 589 | 已消失（dl-cam/ 其余保留，vendor-cam-l1d.img 在） |
| R3 | out/r21-sbstop-p69/ | 671 948 800 | 已消失 |
| R4 | out/r21-sbstop-pc2/ | 671 866 880 | 已消失（**pc1 保留**，sha 复核见 §4） |
| R5 | out/mu-memmap-20261115/ | 697 671 618 | 已消失（结论已落 reports/mu-memmap-20261115.md，删前核实存在） |
| R6 | out/espboot-20261108/ | 173 371 392 | 已消失 |
| R7 | out/espboot-20261110/ | 369 664 | 已消失 |
| R8 | out/fbdiag-20261108/ | 191 664 087 | 已消失 |
| R9 | out/dbg-uefi-initrd-20261115/ | 381 730 710 | 已消失 |
| R10 | y700四代工具/ | 279 766 234 | 已消失 |

删除前逐项 du -sb 求和 = **6 865 976 490 B（6.40 GiB）**；全部 10 项核对消失，无跳过项。

## 2. 汇总

- `df -h /`：632G/937G used（259G avail）→ **625G used（265G avail）**，实测释放 ≈ 6.4 GiB，与逐项求和一致。
- 项目 `du -sh`：82G → **76G**。
- 未做 os.link 去重、未 git gc、未动任何 git 仓库、未 commit。

## 3. 只评估项（本轮未执行任何删除/压缩/改名）

### 3.1 `backup/official-rom-15.10.259/` super 镜像（15.1 G）—— 压缩可行，仅文档引用

- 依据 `grep -rn "official-rom" scripts/ tools/ .githooks/ versions/ .pi/`：**scripts/tools/.githooks/versions 零命中**；命中全部是文档/记忆（`.pi/memory/MEMORY.md:154` 布局注册表、`.pi/reports/disk-audit-2026-11-15.md`、`.pi/plans/2026-11-03-项目整理.md:13`），另有 `RESOURCES/README.md:192`、`reports/asset-slim-20261112.md:46` 等报告引用。
- **结论：无脚本/门禁运行时读取 ⇒ 可改名/压缩**，但压缩后必须同轮改引用（否则布局注册表/check-layout 报 FAIL）。
- 构成：super_4.img 12.27 G + super_7 1.54 G + super_3 1.04 G + super_6 0.60 G + super_8 0.15 G + NON-HLOS.bin 0.37 G + super_{1,2,5} ~17 M。
- 建议命令（不强压 NON-HLOS.bin，已是二进制固件；分件压便于单分区解取）：
  ```sh
  cd backup/official-rom-15.10.259
  for f in super_3.img super_4.img super_6.img super_7.img super_8.img; do
    timeout -k 60 21600 zstd -19 --long=27 -T26 "$f" -o "$f.zst" && sha256sum "$f.zst" && rm -- "$f"
  done
  ```
- 预估：`disk-audit-2026-11-15.md:200` 实测 super_4 压缩率 1.68 ⇒ super 系 15.1 G → 约 9 G，**净省 ~6 G**；耗时 -19 档 -T26 约 1–2 h/12G 件。
- 需同轮改的文档行：`RESOURCES/README.md:192`、`.pi/memory/MEMORY.md:154`（条目路径补 `.zst`）、`versions/layout.tsv` 若该目录有条目路径行、`.gitignore:63`（`/backup/*` 通配，无需改）。另注意 EDL unbrick 前需先解压对应 super 分件。

### 3.2 `backup/out-history-20261105/`（8.13 G / 114 个 .img + ARCHIVE.tsv + ROLLBACK.sh）—— 无可删项

- 读取方确认：`scripts/vk-identity.py:54`（`ARCHIVE_GLOB = backup/out-history-*`，check-doctor §5d 调用）+ `scripts/out-archive.py`（归档目标）+ `versions/out-images-sha256-20261105.tsv`（111 行 path 列指向本目录，O_DIRECT 复算校验用）。
- 逐文件对账：114 个 .img 的 basename 与 `versions/out-images-sha256-20261105.tsv`（path+name 两列）∪ `versions/vk-kernel-identity.tsv` 的引用并集（230 个）比对 —— **全部被引用，未被引用清单为空，总大小 0 B**。
- ARCHIVE.tsv / ROLLBACK.sh 是归档账与回滚脚本，属账目件，保留。
- **结论：不动**（清单为空，删任何一个都破坏版本账可校验性）。

### 3.3 `.pi/sessions/`（874 M）与 `reports/artifacts/`（1.83 G）—— 只列不动

`.pi/sessions/` 最大 10 项：

| 大小 | 项 |
|---|---|
| 26.3 M | subagent-artifacts/ |
| 11.5 M | pi-fold-evidence/ |
| 11.4 M | 2026-10-18T07-03-22-698Z_01a14dd2….jsonl |
| 10.4 M ×2 | --home-xuqianhui{,1001}-y700-elden-- 两个指针文件 |
| 9.6 M | 2026-10-12T02-37-23-800Z_01a12df8….jsonl |
| 8.6 M | 2026-11-13T01-13-49-768Z_01a1d277….jsonl |
| 8.3 M | 2026-11-11T23-59-39-372Z_01a1cd0d….jsonl |
| 8.2 M | 2026-10-17T13-39-06-431Z_01a14a16….jsonl |

判据：`.pi/sessions/` 是硬排除清单明列项；且 AGENTS.md「开工三件事」依赖 `sessfind`/会话索引取证（session-index.md 由它生成）。**建议**：不删；若将来瘦身，只清 10-17/10-18 之前的纯调试会话 jsonl 且先 `sessfind --build` 刷新索引，收益 <100 M，优先级低。

`reports/artifacts/` 最大 10 项：uefi-edl-read-20261101（33.8 M）、uefi-20261107R49-p54（29.4 M）、uefi-20261106R19-fbconsole（28.4 M）、uefi-20261107R{41,42,47,48,51,52}-p{46,47,48,52,53,56,57}（各 23.4 M）等，均为 r21-sbstop ladder 逐挡取证目录。

判据：`scripts/uefi-r21-sbstop-ladder.sh:80,87` 注释明示「记录/判据落 reports/artifacts（**入库**）」，`scripts/uefi-build-variant.sh:22`、`scripts/b5-u2-atomic-timeline.sh:37`、`scripts/q32-arm.sh:35` 都以它为工件根 —— 是多脚本的活跃写入/读取面，且 .gitignore 策略按「入库」管理。**建议**：不删；若要瘦身只能走 `scripts/out-archive.py` 同款「账目化归档」改造，不在本轮范围。

## 4. 硬排除清单（本轮未触碰的证明）

| 项 | 证明 |
|---|---|
| out/r21-sbstop-pc1/ | 删后复核：`sha256sum out/r21-sbstop-pc1/uefi-preamblec1-r1.img` = `40d43397c14ce4ca18e99f553e618b40e901ed90d0c536dbed4fec76defb18de`（与 DEVICE §1.1 一致） |
| out/vk188-bootfiles/ | 删后 `ls` 正常（qemu-full-chain-smoke 默认件在位） |
| backup/official-rom-15.10.259/ | 只 grep 评估，未写未改名（§3.1） |
| backup/out-history-20261105/ | 只读对账，未删（§3.2） |
| backup/{fw,HA2EXB0E-16+512,device-test-20261113,corrupt-*} | 未出现在任何 rm 命令中 |
| bootslot-b/avb.key、versions/*.tsv、build/daily、patches/、scripts/、.git/、.pi/sessions/、reports/artifacts/ | 同上；本轮 rm 列表仅为 §1 的 10 条路径 |

---

**自报**：本轮释放 6 865 976 490 B（6.40 GiB），10 项全部删净、零跳过；§3 三个评估项均只评估未动（official-rom 可压缩净省 ~6 G、out-history 无可删、sessions/artifacts 建议保留）；全部硬排除未触碰（pc1 sha 逐字节复核一致）。
