# sessions/ — 会话单位文档（新约定，2026-10-14 起）

## 约定

- 每次会话的产出（结论、证据、下一步、待并入 SSOT 的事实）写成一个 md：
  `sessions/YYYY-MM-DD-<短主题>.md`（同日多主题可加 `-2`）。
- **不再改写根目录 SSOT 文档**：`INDEX.md` / `TASKS.md` / `PITFALLS.md` / `DEVICE.md` / `RESOURCES.md` /
  `RUNBOOK-BRINGUP.md` / `AGENTS.md` / `README.md` / `PROGRESS.md`。
  需要并入 SSOT 的内容，在会话文件里用 **「★SSOT 待并入」** 小节列出，交由项目宿主择机合并。
- **机器账例外**：`versions/` 是 `scripts/check-doctor.sh` 强制校验的派生表（编号 / 溯源 / 新鲜度）。
  新镜像必须登记 `vk-ledger-known-issues.tsv` 的例外 + 重生成 `vk-kernel-identity.tsv`，否则 doctor FAIL
  ⇒ **`versions/` 仍按旧规矩更新**。
- `reports/` 与 `archive/` 视为**只读归档**；本次会话起，新的过程证据放 `sessions/` 引用的 `logs/`
  或在会话文件内展开，不再新建 `reports/*.md`。

## 会话索引

| 日期 | 主题 | 文件 |
|---|---|---|
| 2026-10-14 | Linux 7.3 主线化（M1-7.3）：WCN 根因 / WiFi 打通 / 显示三连否证 | `2026-10-14-m1-73-mainlining.md` |
