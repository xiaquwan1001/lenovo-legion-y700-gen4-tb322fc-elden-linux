# db/ — 项目知识库（SQLite）

把项目的**进度轨迹、踩坑经验、任务台账、参考文献**从纯文字转成**可查询的结构化索引**。
数据源仍是 git 纳管的文本；数据库由脚本重建，可随源演进、可丢弃重生成。

```bash
cd ~/y700-elden
python3 db/build.py --lessons     # 重建 db/elden.db 并刷新根目录 LESSONS.md
python3 db/build.py --check       # 只校验同步性（过期则退 1，不重建）
sqlite3 db/elden.db ".tables"
```

> ⚠️ `db/elden.db` 与 `LESSONS.md` 都是**生成物**：不要手改，改文本源后重跑上面第一条。
> `scripts/check-doctor.sh` 会检查它们是否过期。

## 表

| 表 | 内容 | 源 |
|---|---|---|
| `sessions` | 45 个历史会话（进度轨迹：目标/结论/实机验证/状态/风险） | `archive/sessions-catalog-*.jsonl` |
| `pitfalls` | 88 条踩坑经验（编号/主题/正文） | `PITFALLS.md` |
| `tasks` | 32 条任务台账（G1/C/A 编号 + 状态） | `TASKS.md` |
| `references_` | 参考文献与资源（外部/本地/URL，158 条） | `RESOURCES.md` + 全仓库 `*.md` 的 URL |
| `docs` | 文档清单（125） | `git ls-files *.md` |

统一人读入口：**`LESSONS.md`**（经验总入口，由 `pitfalls` 生成）。

## 常用查询

```bash
# 踩坑：按关键词找（动手前扫）
sqlite3 db/elden.db "SELECT num,section,title FROM pitfalls WHERE body LIKE '%olddefconfig%' OR title LIKE '%olddefconfig%';"

# 经验按主题浏览
sqlite3 -header -column db/elden.db "SELECT num,substr(title,1,60) FROM pitfalls WHERE section LIKE '%睡眠%';"

# 会话：哪些动过设备（实机验证）
sqlite3 -header -column db/elden.db "SELECT substr(id,1,8),start,name,kernel_versions FROM sessions WHERE hardware_verified='yes' ORDER BY start;"

# 进度：未完成/进行中的任务
sqlite3 -header -column db/elden.db "SELECT id,substr(title,1,40),substr(status,1,30) FROM tasks WHERE status NOT LIKE '%已完成%' AND status NOT LIKE '%✅%';"

# 参考文献：某主题的入口
sqlite3 -header -column db/elden.db "SELECT kind,substr(title,1,40),locator FROM references_ WHERE topic LIKE '%容器%' OR title LIKE '%redroid%';"

# 全文找 URL（跨所有文档）
sqlite3 -header -column db/elden.db "SELECT locator,source_doc FROM references_ WHERE kind='url' AND locator LIKE '%github%';"

# 失败/作废的会话
sqlite3 -header -column db/elden.db "SELECT substr(id,1,8),start,name FROM sessions WHERE status IN ('junk','superseded');"
```

## 备注

- `db/elden.db` 是**生成物**；权威源是文本，改文本后重跑 `build.py`。
- 需要更重的多表/并发查询时可用 mysql：`sqlite3 db/elden.db .dump | mysql ...`，
  或按 `db/schema.sql` 建表后从源导入（本项目规模用 SQLite 足够）。
