-- elden 项目知识库 schema（SQLite 3）
-- 由 db/build.py 重建：DROP + CREATE + 从 git 源解析。
-- 表：sessions=进度轨迹  pitfalls=踩坑经验  tasks=任务台账
--     references_=参考文献/资源  docs=文档清单

DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS pitfalls;
DROP TABLE IF EXISTS tasks;
DROP TABLE IF EXISTS references_;
DROP TABLE IF EXISTS docs;

-- 会话 / 进度轨迹（源：archive/sessions-catalog-*.jsonl）
CREATE TABLE sessions(
  id TEXT PRIMARY KEY,
  start TEXT,                    -- ISO 时间
  name TEXT,
  topic TEXT,
  goal TEXT,
  outcome TEXT,
  hardware_verified TEXT,        -- yes|partial|no|unknown
  device_evidence TEXT,
  kernel_versions TEXT,          -- 摘要中提及（含噪声）
  status TEXT,                   -- active|reference|superseded|failed|junk
  risks TEXT,
  file TEXT,
  size INTEGER);

-- 踩坑经验（源：PITFALLS.md）
CREATE TABLE pitfalls(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  num TEXT,                      -- 原编号，如 "9b"
  section TEXT,
  title TEXT,
  body TEXT,
  source_doc TEXT);

-- 任务台账（源：TASKS.md 表格）
CREATE TABLE tasks(
  id TEXT,                       -- G1-0 / C1 / A11 / task-1
  area TEXT,                     -- 章节（G1 / G2 / 主机侧并行…）
  title TEXT,
  status TEXT,
  evidence TEXT,
  source_doc TEXT,
  PRIMARY KEY(id, source_doc));

-- 参考文献 / 资源（源：RESOURCES.md + 全仓库 *.md 里的 URL）
CREATE TABLE references_(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT,                     -- ext(外部参考) | local(本地资源) | doc | url
  title TEXT,
  locator TEXT,                  -- URL（若有）
  topic TEXT,
  source_doc TEXT,
  status TEXT,
  notes TEXT);

-- 文档清单（源：git ls-files *.md）
CREATE TABLE docs(
  path TEXT PRIMARY KEY,
  kind TEXT,
  title TEXT);
