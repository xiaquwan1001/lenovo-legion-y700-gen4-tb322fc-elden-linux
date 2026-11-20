# vk-kernel-identity.tsv 账注（追加式，不入 TSV 本体——TSV 解析器不吃注释行）

## 2026-11-20
- 已删除 `(slot-dump) bootmark-a-test.img` 一行对应的镜像 `out/bootmark-a-test.img`（97M 试验件，
  UTS `7.3.1-debug-vk184-00003-gec74c4795a43`，kbin_sha `c95a73bd7d25`），依据
  `.pi/reports/cleanup-audit-20261120/slim-worktree-plan.md` §2「out/bootmark-a-test.img 试验件，可删」。
- 行从 TSV 移除而非保留：`check-doctor` §5d 用「表行 ↔ 现存镜像」做新鲜度比对，镜像已删仍留行会把
  正常清理报成「身份表已过期」。原始读数记录在本文件，重建同镜像后跑 `scripts/vk-identity.py` 会自动回填。
- 影响：`check-doctor` 由 FAIL=1 回到 **FAIL=0 / WARN=7**（与清理前一致）。
