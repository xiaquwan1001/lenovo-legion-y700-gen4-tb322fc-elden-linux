# A6 项目资产体积审计（只读）
审计代理: A6-assets / 生成时间 2026-11-19 / 只读（零删除、零移动、零 git 写操作）

## 结论（数字先行）

1. **工作区约 152 G**（du --apparent-size，本机盘 937G 用 826G/93%）。分布：`out/ 112G`、`backup/ 29G`、`reports/ 6.0G`（其中 artifacts 5.9G）、`bootslot-b/ 2.0G`、`.pi/ 878M`（sessions 876M）、`external/ 855M`、`.git/ 364M`、`dl-cam/ 609M`、`assets/ 319M`，其余目录合计 <100M。命令：`du -sh --apparent-size * .[a-z]* | sort -h`。
2. **可执行精简空间约 55–65 G**（不含 user 拍板项），最大三块都在 `out/`：v2b 归档 ~20G、android-min/-avb 归档 ~27G、stage/verify/work 中间物 ~10G。**但 out/ 里 android-slim-v3(41G) 是本轮活跃实验材料，禁动**（TASKS/sessions/2026-11-19-安卓共存契约与v3精简上机.md：S3–S5 计划待执行，设备现跑 Linux）。
3. **out/ 的 18 件 boot-elden-*.img（~1.5G）全部在 vk 账有行**（逐名 `cut -f2 versions/vk-kernel-identity.tsv | grep -c` 核实 18/18），不存在"无主镜像"；处置应走既有管道 `scripts/out-archive.py`（归档进 backup/out-history），不是直接删。同镜像多副本未发现 sha 重复（18 件 sha256 全异，见 TSV）。
4. **backup/ 29G 几乎全 MUST-KEEP**：`versions/backup-manifest.tsv`（2026-11-18 triage）已逐项分级，official-rom(16G)/out-history(7.6G)/HA2EXB0E(1.2G) 均为 KEEP-CRITICAL/KEEP-REF，且 official-rom 是本轮 S3"刷原厂 super 对照"的前置材料。仅 `backup/git-history-rewrite-20261112`+`git-slim-20261113`（2.0G）不在该台账 → NEEDS-USER。
5. 重点疑点（NEEDS-USER 三件）：`reports/artifacts/slotattr-20261119/full-image.bin`（4.0G 设备分区整读回）、`backup/git-*` 快照 2.0G、`dl-cam/vendor-cam-l1d.img`（256M 设备 vendor 读出件，repo 内无脚本引用）。

## 总量分布（apparent-size）

| 路径 | 大小 | 判定概要 |
|---|---|---|
| out/ | 112G | 活跃实验 41G(留) + 历史/中间物 ~55G(批次清理) + boot 镜像 1.5G(归档) |
| backup/ | 29G | 台账已分级，全保（2.0G git 快照待问） |
| reports/ | 6.0G | artifacts 5.9G（slotattr 4.1G 待问 + 证据目录 ~1.8G 可外移） |
| bootslot-b/ | 2.0G | 21×96M 槽位镜像，保最新 2 件，19 件归档 ~1.8G |
| .pi/sessions | 876M | 老会话可归档 ~600M |
| external/ | 855M | 全部可再生（重下载成本换空间） |
| dl-cam/ | 609M | vendor 读出件待拍板；sysroot/aosp ~300M 可重建 |
| assets/ | 319M | 成品，保留 |
| .git + 源码/文档 | ~420M | 保留 |

## 可执行清理批次（按风险从低到高；本轮零执行，仅清单）

**批次 0（前置校验，任何批次前跑）**
```
cd /home/xuqianhui/y700-elden && bash scripts/check-doctor.sh && git status --porcelain | wc -l   # 必须 FAIL=0、工作区 clean
```

**批次 1（风险低，~2.6G，纯中间物）**
- 删 `out/stage-min-20261118` 1.8G、`out/stage-modules-20261118` 550M、`out/stage-debian` 129M、`out/bootmark-a-test.img` 96M。
- 前置：`grep -rn "stage-min\|stage-modules\|stage-debian\|bootmark" scripts/ reports/ | grep -v __pycache__` 确认无脚本引用（本轮已 grep，stage-* 无引用）。

**批次 2（风险低，~4.6G，成品已落位的中间态）**
- 删 `out/android-assets-20261119/staging` 809M（成品在 `assets/android-20261119/`+MANIFEST.tsv）、`out/android-slim-v3-20261119/verify` 3.9G（先 sha256 与 new/ 比对一致）。

**批次 3（风险中，需设备侧稳定确认，~34G）**
- `out/android-min-20261118`(14G) + `out/android-min-avb-20261118`(15G) → 先 `scripts/out-archive.py` 式归档，S3–S5 完成且 v3 验证通过后删。
- `out/min-restore-20261119`(6.4G) 与 `out/p2-minbase-20261118`(6.1G) 二选一：保最近一代恢复镜像。

**批次 4（风险中，走既有管道，~3.5G）**
- `out/boot-elden-*.img` 18 件 + modstage 2 件 → `bash scripts/out-archive.py --dry-run` 预览后归档。
- `bootslot-b/` 保 `boot_b-minbase-labellinux-20261119.img`、`boot_b-vk192-linux17label-20261119.img`，其余 19 件归档（引用者：scripts/flash-b.sh、sign-boot-b.sh 等 10 个脚本，见 TSV）。

**批次 5（可再生的外部下载，~855M+500M）**
- `external/` 全部（lc-cross/ext-repos/alpine-sysroot…）；`dl-cam/` 的 sysroot+aosp+hw-interfaces（gen-headers.sh 可重建）。注意重下载成本，建议设备实验密集期过了再清。

## 必须先问用户的清单

1. `reports/artifacts/slotattr-20261119/full-image.bin`（4.0G）：2026-11-19 slotattr 实验的设备分区整读回，设备态已变；留档（移 backup/）还是删？
2. `backup/git-history-rewrite-20261112` + `backup/git-slim-20261113`（2.0G）：不在 backup-manifest.tsv 台账；`.git` 本体健在（364M），快照可否删？
3. `dl-cam/vendor-cam-l1d.img`（256M）：C1 相机线供体件，仓库内无脚本引用；相机线是否继续推进？
4. `backup/boot_a-pre-uefi-20261108.img`（96M）：backup-manifest.tsv 已标 DELETE（与 stock-259/boot_a.img 同 sha），按台账需用户点头。
5. `out/android-slim-v3-20261119`（41G）：本轮活跃实验材料，何时可以整体归档由 S3–S5 进度决定，不由本审计决定。

## 附属文件
- 逐条清单：`reports/audit-20261119/A6-assets-audit.tsv`（path/大小/类别/引用者/动作/释放/复核命令/风险）。
- 未取证项已在 TSV 标注：v3 verify/ 与 new/ 的 sha 一致性、min-restore 与 p2-minbase 镜像关系，均需执行时先核对。
