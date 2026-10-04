# 2026-10-04 过时入口清理归档（快捷启动 + pi-messenger-swarm）

> **性质**：过程证据，只增不改。登记判据见 §3；权威登记条目在 `PITFALLS.md` §15.1。
> **一句话**：三个 shell 快捷入口 与 已卸载插件 `pi-messenger-swarm` 的全部资产，一次性退出活跃树。

## 1. 移除清单

### 1.1 shell 快捷入口（机器层，`~/.local/bin/`）

| 脚本 | 内容 | 目标目录 | 归档副本 |
|---|---|---|---|
| `flashing` | `cd ~/y700-elden && exec pi "$@"`（4 行） | 存在 | `bin/flashing` |
| `eacndev` | `cd ~/eacndev && exec pi "$@"` | 存在 | `bin/eacndev` |
| `lob-remake` | `cd ~/lobcorp-remake && exec pi "$@"` | 存在 | `bin/lob-remake` |

三者同族、同批生成（2026-09-30 20:11），功能 = 单纯 `cd`，**不加载任何东西**。
现役入口 = **`cd ~/y700-elden && pi`**（等价写法 `pi` 于本目录内）。

### 1.2 已卸载插件 `pi-messenger-swarm` 的资产（repo 层）

| 原路径 | 处置 | 归档位置 |
|---|---|---|
| `scripts/swarm.sh` | git mv | `scripts/swarm.sh` |
| `scripts/swarm-monitor.sh` | git mv | `scripts/swarm-monitor.sh` |
| `scripts/y700-swarm-reset.sh` | git mv | `scripts/y700-swarm-reset.sh` |
| `scripts/y700-harness-restart.sh` | git mv | `scripts/y700-harness-restart.sh` |
| `scripts/start-y700-harness.sh` | git mv | `scripts/start-y700-harness.sh` |
| `scripts/apply-swarm-patch.sh` | git mv | `scripts/apply-swarm-patch.sh` |
| `patches/pi-messenger-swarm-detach-spawn.patch` | git mv | `patches/…` |
| `patches/pi-messenger-swarm-spawn.js.patched` | git mv | `patches/…` |
| `.pi/pi-messenger.json`（`maxConcurrentSpawns`） | git rm | 本 README §1.2（值：3） |
| `.pi/messenger/`（运行时 848 K） | tar 后删除 | `pi-messenger-runtime.tar.gz` |
| `logs/swarm-monitor.log`（272 K） | 删除（运行时噪声） | — |

**保留**：`.pi/agents/*.md`（6 个角色定义，现由 `@tintinweb/pi-subagents` 加载，活跃）
与 `.pi/missions/*.md`（任务卡正文，作为 `Agent` 提示词的输入素材）。

## 2. 现役替代形态

| 旧（swarm harness） | 新（pi-subagents，已装 v0.19.0） |
|---|---|
| `scripts/swarm.sh --start` + 常驻 harness `server.js` | 无守护进程：`Agent` 工具 + `.pi/agents/<role>.md` |
| `maxConcurrentSpawns: 3`（`.pi/pi-messenger.json`） | 编排者自控并发；API 限流判据仍见 `AGENTS.md` §API 限流 |
| `PI_MESSENGER_DIR` 分桶 / `session-id` 钉桶 | 不存在该问题（会话按 cwd + `sessionDir`） |
| worker 自报 → `task done` | 结论仍需独立复跑（该教训与本归档无关，继续有效） |

> **入库注意**：§1.2 的 8 个 `git mv` 与 `.pi/pi-messenger.json` 的 `git rm` 被**同时运行的另一个 pi 会话**的提交
> `2d4408d`（"R1 硬件验收冻结"）扫走入库（同一 worktree 共享 index 所致）。移动本身完整无损，
> 只是提交信息不匹配；本目录其余内容随本次清理提交。教训：**并发会话下不要用 `git commit -a`，须显式列路径**。

## 3. 判据（为何判定为"不存在"）

```
settings.json packages = pi-quiet, pi-extension-manager, provider-manager,
                         pi-undo, pi-edit-session-in-place, pi-fold, @tintinweb/pi-subagents
pi list                → 无 pi-messenger-swarm
npm/node_modules/      → 无 pi-messenger-swarm 目录
scripts/*.sh 引用的 ~/.pi/agent/npm/node_modules/pi-messenger-swarm/dist/... → 不存在
pgrep -f harness/server.js → 无进程
```

即 6 个脚本 + 2 个 patch 自某次卸载起已 **静默失效**（`node …/server.js` 会 ENOENT），
`.pi/pi-messenger.json` 与 `.pi/messenger/` 是无人读的化石。`AGENTS.md` 原第 21 行引用的
`swarm.py` 与 `.pi/messenger/agent-card.json` 同样**从未在本机存在过**。

## 4. 恢复方法（若某天确实要回到 swarm 形态）

```bash
cd ~/y700-elden
# 1) 插件本体需重新安装（本归档不含插件源码，只含本项目的配置与补丁）
pi install npm:pi-messenger-swarm          # 包名/可得性需自行核实
# 2) 铺回本项目脚本与补丁
git mv archive/2026-10-04-retired-entrypoints/scripts/* scripts/
git mv archive/2026-10-04-retired-entrypoints/patches/* patches/
git checkout 4aacf40 -- .pi/pi-messenger.json
tar xzf archive/2026-10-04-retired-entrypoints/pi-messenger-runtime.tar.gz
# 3) 关键：重装后必须立刻重新应用 detach 补丁，否则 worker 会被别的项目重启 harness 时 SIGPIPE 带走
#    原因与补丁动机见 archive/topics/复盘-2026-10-02-swarm.md
scripts 目录下 apply-swarm-patch.sh 归位后运行
```

## 5. 顺带登记：机器层孤儿目录（**本次未动**，需机器层授权才清）

`~/.pi/` 下这些目录不再被任何已安装包引用（`grep` node_modules 无命中）：

| 路径 | 大小 | 来源 |
|---|---|---|
| `~/.pi/agent/pi-sessions/` | 12 M | 旧会话索引插件（已卸载） |
| `~/.pi/wechat/` | 1.1 M | `@ericzhaozzz/wechat-channel`（已卸载） |
| `~/.pi/todos/` | 48 K（11 文件） | `pi-task-kanban`（已卸载） |
| `~/.pi/agent/pi-agent-profiles/` | 24 K | `pi-profile-switch`（已卸载） |
| `~/.pi/agent/_cron_backup/`、`~/.pi/agent/missions/`、`~/.pi/agent/git/`、`~/.pi/session-control/`、`~/.pi/_wtest/` | 各 ≤12 K | 同类残留 |

`~/.pi/workflows/` **保留**（`@tintinweb/pi-subagents` 引用）。
`node_modules/` 里的 `@ericzhaozzz`、`@furbyhaxx`、`@wechatbot`、`croner` 等为卸载后孤立依赖。

## 6. 附录：被移出活跃记忆区的原文（`.pi/memory/FAILURES.md`，2026-10-02 块）

> 移除理由：整段的**修法**都挂在已卸载的 `pi-messenger-swarm` 上（`apply-swarm-patch.sh`、
> `session-id` 钉桶、`PI_AGENT_NAME`），保留在活跃 FAILURES 里会误导后续会话去跑不存在的脚本。
> 其中与插件无关的**限流结论**在下一块（同日期）与全局 `~/.pi/agent/AGENTS.md` 仍完整保留。

```
## Memory - 2026-10-02

pi-messenger-swarm 子代理"秒退/agent crashed"（2026-10-02）两个真因：①ustc_ai 每 key 限 20 请求/滚动窗口，
pi 默认 retry.maxRetries=3（2/4/8s）在窗口复位前放弃→exitCode 0。
修：settings.json 加 retry{maxRetries:8,baseDelayMs:3000,maxAgentDelayMs:60000}，并降 maxConcurrentSpawns。
②本机多项目共用 node_modules 与 /tmp/pi-messenger-swarm.log；别的项目 SIGTERM 其 harness 时本项目的也被重启，
worker stdout 是管道→SIGPIPE 死。修：给 dist/swarm/spawn.js 打 spawn detached+stdout 落文件的 LOCAL PATCH
（scripts/apply-swarm-patch.sh 重新应用），重启 harness 用 kill -TERM（preserve）而非 --stop。
另：swarm.sh 须每次钉回 .pi/messenger/session-id 原桶，且 PI_AGENT_NAME 用 ${..:-SageYak} 不硬编码。
```

**仍然有效的抽象结论**（与插件无关，留在全局 `AGENTS.md` §API 限流）：
worker 自报成功不可信 → 编排者独立复跑；429 有两种（请求窗口 / 3h 预算），后者只能等或换 key。

## 7. 机器层收尾（同轮，2026-10-04 追加授权后执行）

| 项 | 处置 | 体积 |
|---|---|---|
| `~/.bash_profile` 第 2 行 `导出 PATH=` | 改为 `export PATH=`（原行每次登录打印「导出: 未找到命令」，dotnet tools 从未进 PATH）。备份 `~/.bash_profile.bak-20261004` | — |
| `~/.pi/agent/pi-sessions/`(12 M) · `~/.pi/wechat/`(1.1 M，含已卸载渠道的 `credentials.json`) · `~/.pi/todos/`(11 个) · `~/.pi/agent/pi-agent-profiles/` · `~/.pi/{session-control,_wtest}/` · `~/.pi/agent/{_cron_backup,missions,git}/` | **移动到回收目录**（未硬删）`~/.pi/_trash-2026-10-04/`，共 **13 M**；确认无影响后 `rm -rf` 该目录即可 | 13 M |
| `~/.pi/agent/npm/node_modules/` 疑似孤立依赖 | **判定为不需要清理**：`package.json` 7 个直接依赖 + lockfile 传递闭包 = 11 个包，与磁盘实际 11 个完全一致；`croner`/`nanoid`/`typebox` 是 `pi-subagents` 的传递依赖。此前"孤立依赖"的判断源于把 scoped 目录（`@aws`、`@babel` 等）当作**包**计数，实际它们已随 lockfile 清除 | — |
| `~/.pi/workflows/` | **保留**（`@tintinweb/pi-subagents` 的 `SubagentWorkflow` 保存位） | — |

⚠️ **回收前必读**：`_trash-2026-10-04/agent__cron_backup/crontab.2026-10-04-preclean.bak` 是当日
`crontab` 清空前（08:51，另一个会话的 preclean）的**唯一备份**，内容 = lobcorp-remake 的 swarm 看门狗
`*/10 * * * * … bash tools/swarm_watch.sh`。当前 `crontab -l` 为空。若 lobcorp 项目仍需要它，从该文件恢复。

回收命令（确认无误后你自己执行）：`rm -rf ~/.pi/_trash-2026-10-04`
