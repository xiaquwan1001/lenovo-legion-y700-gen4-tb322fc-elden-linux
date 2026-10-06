# 2026-10-04 过时入口清理归档（快捷启动 + 已卸载插件 pi-messenger-swarm）

> 证据层 · 只增不改。权威登记条目在 `PITFALLS.md` §15.1。
> **2026-10-06 修订**：按「过时插件的工作流一律删除」指示，`pi-messenger-swarm` 的**运行形态 / 恢复步骤 / 补丁 / 运行时 tarball 已删除**（历史见 git）。
> 本目录只保留**入口副本**与**机器层登记**，不再提供任何 swarm 操作指引。

## 1. 移除清单

### 1.1 shell 快捷入口（机器层，`~/.local/bin/`）

| 脚本 | 内容 | 归档副本 |
|---|---|---|
| `flashing` | `cd ~/y700-elden && exec pi "$@"`（4 行） | `bin/flashing` |
| `eacndev` | `cd ~/eacndev && exec pi "$@"` | `bin/eacndev` |
| `lob-remake` | `cd ~/lobcorp-remake && exec pi "$@"` | `bin/lob-remake` |

三者同族、同批生成（2026-09-30 20:11），功能 = 单纯 `cd`，**不加载任何东西**。
现役入口 = **`cd ~/y700-elden && pi`**。

### 1.2 已卸载插件 `pi-messenger-swarm`（工作流已删除）

- **2026-10-04**：脚本 / 补丁 / 配置（`.pi/pi-messenger.json`、`.pi/messenger/`）从活跃树移出。
- **2026-10-06**：**工作流资产删除**——`scripts/{swarm,swarm-monitor,y700-swarm-reset,y700-harness-restart,start-y700-harness,apply-swarm-patch}.sh`、`patches/pi-messenger-swarm-*`、`pi-messenger-runtime.tar.gz`。
  理由：插件已卸载，脚本 `node …/server.js` 静默 ENOENT；保留恢复指引只会误导后续会话去跑不存在的流程。
- **现役并发形态** = `Agent` 工具（`pi-subagents`）+ `.pi/agents/<role>.md` + `.pi/missions/<topic>.md`；方法见 `.pi/CONCURRENCY.md`。
- **历史**（含当时 detach 补丁动机、会话）见 `git log -- archive/2026-10-04-retired-entrypoints` 与 `archive/topics/复盘-2026-10-02-swarm.md`。

## 2. 机器层孤儿目录登记（**未动**，需机器层授权才清）

`~/.pi/` 下这些目录不再被任何已安装包引用（`grep` node_modules 无命中）：

| 路径 | 大小 | 来源 |
|---|---|---|
| `~/.pi/agent/pi-sessions/` | 12 M | 旧会话索引插件（已卸载） |
| `~/.pi/wechat/` | 1.1 M | `@ericzhaozzz/wechat-channel`（已卸载） |
| `~/.pi/todos/` | 48 K（11 文件） | `pi-task-kanban`（已卸载） |
| `~/.pi/agent/pi-agent-profiles/` | 24 K | `pi-profile-switch`（已卸载） |
| `~/.pi/agent/_cron_backup/`、`~/.pi/agent/missions/`、`~/.pi/agent/git/`、`~/.pi/session-control/`、`~/.pi/_wtest/` | 各 ≤12 K | 同类残留 |

`~/.pi/workflows/` **保留**（`pi-subagents` 引用）。

## 3. 机器层收尾（2026-10-04）

| 项 | 处置 | 体积 |
|---|---|---|
| `~/.bash_profile` 第 2 行 `导出 PATH=` | 改为 `export PATH=`；备份 `~/.bash_profile.bak-20261004` | — |
| 上表孤儿目录（含 `credentials.json`） | **移动到回收目录**（未硬删）`~/.pi/_trash-2026-10-04/`，共 13 M；确认无误后 `rm -rf` | 13 M |
| `~/.pi/agent/npm/node_modules/` 疑似孤立依赖 | **不需要清**：`package.json` 直接依赖 + lockfile 传递闭包 = 11 包，与磁盘一致 | — |
| `~/.pi/workflows/` | **保留**（`pi-subagents` 保存位） | — |

⚠️ **回收前必读**：`_trash-2026-10-04/agent__cron_backup/crontab.2026-10-04-preclean.bak` 是当日 `crontab` 清空前
（08:51）的**唯一备份**，内容 = lobcorp-remake 的 swarm 看门狗（`*/10 * * * * … bash tools/swarm_watch.sh`）。
当前 `crontab -l` 为空；若 lobcorp 项目仍需，从该文件恢复。

回收命令（确认无误后自己执行）：`rm -rf ~/.pi/_trash-2026-10-04`
