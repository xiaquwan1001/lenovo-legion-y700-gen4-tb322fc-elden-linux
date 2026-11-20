# 文档批二/批三 + 内核树重建（无人值守轮 2026-11-20）

状态：进行中（骨架，增量覆盖）

## 任务 A：文档批二/批三 — ✅ 全部完成
- [x] A1 合并重复叙述：公开 `README.md` §4 已知问题表（Q28/Q32/Q24/#106/N1）压成 4 行指针（状态→INDEX §0「已结项」，正文→TASKS §5）；A4 tsv 判「MERGE-INTO，README 只留一行指针」
- [x] A2 归档：`git mv` 8 篇 `reports/asset-*.md`（asset-cleanup-20261109/20261110、asset-inventory-20261101/20261108、asset-slim-20261112、asset-tidy-20261103/20261105、asset-tidy-exec-20261111）→ `archive/2026-11-19-docs-audit-retired/superseded/`；每篇头部加一行「已归档+现行台账=RESOURCES §3」注记；`assets-inventory-20261023.md` 不动（RESOURCES:214 仍引为现行清理纪律）；活文档引用已改（TASKS/README、RESOURCES/README、reports/ 下 10 篇活报告）；`scripts/reports-index.py` 重生成（570 篇/153 组）；`.pi/plans`、`.pi/memory`、sessions 等历史档按 SSOT 规则不改
- [x] A3 作废标注：`RUNBOOK-BRINGUP/README.md:13` BRINGUP-NEW-TABLET-2026-10-02.md 标「件已删，仓内不存在」；`:403` build.sh/pack.sh/cycle.sh「兼容保留」改删除线+作废；`TASKS/README.md` 9 个已删脚本裸名逐一标（已删）+ 表头后加一条集中注记指向 `reports/script-cleanup-audit-20261112.md`
- [x] A4：`RESOURCES/README.md:80` 的 `docs/archive/.../blockio-usb-progress.md` 标注为外置仓库 sunuefi 内路径；`DEVICE/README.md` §1.1 顶部加「倒序叠写、现态=日期最新顶条、旧条目均为历史沿革」注记
- [~] 收口：check-doctor **FAIL=0 WARN=7**（与改前基线相同，7 条全为 11-19 磁盘清理遗留的「不可核」项，其中 4 条预期由任务 B 恢复 geekidos-linux 后下降）

## 任务 B：内核树重建 + 编译
- [ ] B1 确定重建目标（读 versions/kernel-src-archive.tsv 等）
- [ ] B2 浅克隆 GEEKiDoS/linux → geekidos-linux/
- [ ] B3 应用 reports/build-m3v2-7.3rc7-dirty-20261119.patch
- [ ] B4 make -j26 编译
- [ ] B5 阻塞如实记录（若发生）
- [ ] B6 更新 tsv / notes + check-doctor

## 逐条改动记录
（增量写入）

## 结尾总结
（A 完成几条 / B 到哪一步 / 阻塞原因）
