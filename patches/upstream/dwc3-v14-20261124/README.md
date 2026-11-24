# dwc3 v14 备料（2026-11-24）——**未投递，等放行**

- 触发：sashiko 2026-11-23 11:29Z 对 **v13 1/3** 的 3 条 [Low]（逐条判别 = `../../reports/upstream-recheck-20261124.md` §3）。
- 范围：**只重出 1/3**；2/3、3/3 与 v13 逐字节相同（`diff --git` 段哈希一致，仅 `index` 行缩写不同）。
- 门禁：`GATES-v14.md`（G1/G2/G4/G5 现跑；G6 用 v13/v14 两套 schema 做对照矩阵；G3 未重跑并说明理由）。
- 投递：**未发**。放行后 `bash SEND.sh`（默认 dry-run，`--yes` 才真发；2026-11-24 已 dry-run 通过 = 4 封格式/smtp 配置 OK，日志 `logs/`）。
- 回退：本目录整体删除即可（仓内其它文件未改动；`build/elden-tree` 只加了临时 worktree，已可删）。
