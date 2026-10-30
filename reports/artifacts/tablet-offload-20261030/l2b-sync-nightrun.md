# L2-B 回执：三方同步协议 + 夜间无人值守运行设计（tablet-offload-20261030）

- 结论：**PASS**（协议与脚本/单元/队列全部落盘，语法自检通过；未执行任何 push/commit，未对平板/vlab 写）。
- 产物：见下「产物」段，5 个文件全部在白名单内。
- 关键数字：bash -n 3 个脚本 rc=0；jq 校验 5 行 jsonl rc=0；配额假设 = 平板夜间 CPU 上限 4 核（runner 内用 nice + max 并发 1 实现）。
- 复现命令：
  ```
  bash -n .pi/plans/tablet-sync.sh .pi/plans/tablet-night-runner.sh
  jq -c . <(cat .pi/plans/tablet-queue.example.jsonl)
  systemd-analyze --user verify .pi/plans/pi-tablet-night.service 2>&1 || true   # 平板上执行
  ```

---

## 1. 三方（平板 / 本机 / USTC GitLab）同步顺序与防分叉

### 1.1 远端与凭据事实（L1 已实测，引用）

- origin（https 匿名）= 401，**不可用**；glab token 对 git.ustc 报 Invalid token，**不可用**。
- `ssh://git@git.ustc.edu.cn/xqh/y700-elden.git`（SSH:22）从本机 rc=0 可列 refs ⇒ **协议统一走 SSH remote，别名建议 `ustc-ssh`**。
- 前提：平板需自行生成 key 并把公钥加到 git.ustc 账号（这是**外部人工干预项**，由用户操作；平板上 `ssh-keygen -t ed25519` + 在 USTC GitLab 网页贴公钥，脚本不代做）。
- 本机 main = 5bad548，领先 github/main 与 origin/main 各 **141 提交**（未推送）。

### 1.2 分派口径（防同文件冲突）

| 侧 | 只许碰 | 禁碰 |
|---|---|---|
| 平板 | `reports/`、`TASKS/sessions/`、`PITFALLS/` 增补条目、邮件草稿/日志分析产物 | 内核源码、`.pi/`、INDEX/README/TASKS 主文件、DEVICE/RESOURCES |
| 本机 | 一切（含 SSOT 归并权） | — |
| USTC GitLab | 仅作为唯一同步远端；`main` 与 `tablet/*` 两类 ref | — |

### 1.3 同步顺序（每次上电合流，脚本 `tablet-sync.sh` 实现，只读验证模式默认开）

规则（写死在脚本头注释）：
1. **本机先 push**：上电后本机先 `git fetch ustc-ssh` 看远端 main 是否前进；
   - 未前进：本机继续持有 141 提交，先解决 §1.5 风险再 push main。
   - 前进了：`git rebase ustc-ssh/main`（冲突收口人 = 总管，见 §1.4）。
2. **平板只推 `tablet/<task>` 分支，禁止直推 main，禁止 force push**（脚本里对 main 一律不 push；runner 的 push 命令写死 `refs/heads/tablet/<task>`）。
3. 平板推完（或夜间离线）后，本机 `git fetch ustc-ssh 'refs/heads/tablet/*:refs/remotes/tablet/*'` 逐分支 `git merge --no-ff` 收口，合并后由本机统一 push main。
4. 会话/用户数据不进 git，见 §2。

### 1.4 冲突收口

- 任何 rebase/merge 冲突：**不自动选边**，`git merge --abort` / 保留现场，写入 `reports/artifacts/tablet-offload-20261030/conflict-<日期>.md`，交总管裁决。
- 平板侧脚本遇到 push 被拒（non-fast-forward）：一律不 force，改为把分支改名为 `tablet/<task>-<date>` 再推，留两条分支给总管收口。

### 1.5 pre-flight 检查（`tablet-sync.sh --preflight`，只读）

- 工作区必须干净：`git status --porcelain` 为空，否则退出码 2。
- 未推送提交阈值：`git rev-list --count ustc-ssh/main..main`；>50 报警，>200 拒绝继续（退出码 3）。
- **「141 提交未推送」处置待办（不执行）**：
  1. `git log --oneline origin/main..main | head -30` 快速人工过目有无敏感内容（key/凭据/token 字样 `rg -i 'token|key|secret'` 于 patch 内容）。
  2. 确认 USTC GitLab 是否设为私有仓库（是 → 直接 push 无泄露风险；否 → 先在网页设置私有）。
  3. 处置顺序：先 push 本机 main 到 ustc-ssh（恢复单一真源），再让平板 fetch；**在 push 完成前平板不得开工任何依赖 main 新提交的任务**。
  4. push 后清点：`git rev-list --count ustc-ssh/main..main` 归零才算合流成功。

---

## 2. 会话/用户数据同步（git vs rsync 裁决）

| 数据 | 体量（L1 实测） | 载体 | 理由 |
|---|---|---|---|
| `.pi/sessions/*.jsonl` | 616M / 265 文件 | **rsync 单向，主机<-平板**（`--checksum`） | 二进制级追加型 JSONL，git 化会让 .git pack 从 31MiB 膨胀数百 MiB 且无 diff 价值 |
| `reports/` | 99M（artifacts 含大量 log） | **git**（代码/结论 md）+ rsync（>5MB 的原始 log/artifacts，见 .gitignore 口径） | 结论要进历史，原始大 log 不该 |
| `TASKS/sessions/` | 含在 TASKS 1.1M 内 | **git**（平板经 tablet/* 分支提交） | 纯文本小文件，天然可 merge |
| memory（`~/.pi/agent/pi-hermes-memory/` + projects-memory/y700-elden） | KB 级 | **rsync 单向平板->主机 `--checksum`**，由主机归并后 commit | 平板无权改主机记忆 SSOT |

### 2.1 .gitignore 口径建议（只建议，不改文件）

```gitignore
# 建议追加（tablet-offload-20261030 L2-B）：
.pi/sessions/            # 616M 会话流，走 rsync 不走 git
reports/**/*.raw.log
reports/**/*.log.gz
reports/artifacts/**/trace-*.dat
*.pw.
```
（原则：结论 md 进 git；原始遥测/超 5MB 的 log 一律 rsync 目录 `reports/artifacts/`。）

### 2.2 冲突策略

- 会话文件按设备前缀分目录/文件名：平板侧落盘为 `.pi/sessions/tablet/<task>/<id>.jsonl`，主机为 `.pi/sessions/<原样>`；rsync 单向（主机<-平板，`--checksum --ignore-existing` 或固定目录隔离），**禁双向覆盖**（绝不加 `--delete`）。
- rsync 命令口径（主机侧执行，示例，脚本已内置）：
  `rsync -av --checksum root@192.168.7.1:/home/xuqianhui1001/y700-elden/.pi/sessions/tablet/ .pi/sessions/tablet/`

### 2.3 断电续作与上电合流检查清单

- 断电续作口径沿用 `scripts/sess.sh` / pi 的 `/resume`：本项目 sessionDir = `.pi/sessions`，平板上同路径 + `pi /resume` 或 `scripts/sess.sh -a 2 <关键词>` 找回中断点；runner 每任务写 `state/<id>.done|.fail|.retry<n>` 标记，重启后跳过 `.done` 续跑其余。
- 上电合流清单（顺序执行）：
  1. `ping -c2 192.168.7.1` 确认平板活着；
  2. 跑 `tablet-sync.sh --preflight`（本机）；
  3. `tablet-sync.sh --fetch-tablet`（拉 reports/TASKS/sessions 增量 + rsync 会话）；
  4. 逐个 `git merge --no-ff remotes/tablet/<task>`，冲突即停报总管；
  5. review runner 日志 `reports/artifacts/tablet-offload-20261030/night-<日期>/`；
  6. 本机 push main（含 §1.5 待办前置）。

---

## 3. 夜间无人值守设计

### 3.1 启动两法（细节在 `pi-tablet-night.service` / `tablet-night-runner.sh` 头注释）

- **首选：systemd user unit**（平板 systemd --user running，uid 1001）。装到
  `~/.config/systemd/user/pi-tablet-night.service` + `systemctl --user enable --now pi-tablet-night.timer`（timer 文件由总管按需再加；本单只给 oneshot + `WantedBy=multi-user.target` 不合适，改用 `DefaultDependencies=no` 的 user 级 oneshot，由 cron/timer 触发）。
  前提：**无交互登录** ⇒ `loginctl enable-linger xuqianhui1001`（需平板 root 执行一次，属用户物理干预项）。
- **备选：tmux**（平板已装 tmux 3.8）：`tmux new -ds nightrun .pi/plans/tablet-night-runner.sh`；断电后重进 `tmux attach -t nightrun` 看现场。无 linger 时用 `crontab @reboot` 拉起。

### 3.2 任务队列 jsonl

字段（与 `tablet-queue.example.jsonl` 一一对应）：
`id / kind / prompt / inputs / max_minutes / timeout_box / retry / log_path / needs_network / needs_device / allowed_write_paths`
- `timeout_box` = `timeout -k 60 <秒>` 的秒数，硬截止；`max_minutes` 为软预算（runner 记录超预算警告）。
- `retry` 失败重试上限（默认 2），退避 = 30s*n。
- `needs_device` 一律 false（平板夜间不碰主机设备）；`allowed_write_paths` 白名单，runner 逐条校验，越界即 fail。

### 3.3 runner 必须项（已在 `tablet-night-runner.sh` 实现）

- `timeout -k 60 <秒>` 截止盒 + `nice -n 19`（低 CPU）；
- 失败重试上限 + `.done/.fail` 状态落盘；
- 每任务 `exec > >(tee log) 2>&1` 产物落盘；
- 结束回传：rsync `reports/artifacts/` + `TASKS/sessions/` 增量到主机（`rsync -av --checksum`，单向平板->主机），或 SSH 可用则 push `tablet/<task>`（脚本默认 rsync，push 需 `--allow-push` 显式开启）；
- 早上主机 review+合并 = §2.3 清单。

### 3.4 API 路线（主机断电后 127.0.0.1:4000 litellm 必不可用）

| 路线 | 文件位置 | 键名 | 键值 |
|---|---|---|---|
| A 平板直连 api.llm.ustc.edu.cn | 平板 `~/.config/pi-agent/credentials.json`（或 env file `~/.config/pi-tablet-night.env`） | `USTC_API_KEY` | `__PLACEHOLDER__`（真实 key 由用户手动填，不进 git/rsync 白名单） |
| B 平板本地 litellm | 平板 `/etc/litellm/config.yaml`（或 `~/.litellm/config.yaml`） | `api_key:` / `model_list[].api_key` | `os.environ/USTC_API_KEY` 占位 |

- 探活命令（runner 内置，两种都做，先 B 后 A）：
  - 直连：`curl --noproxy '*' -m 10 -s -o /dev/null -w '%{http_code}' https://api.llm.ustc.edu.cn/v1/models -H "Authorization: Bearer $USTC_API_KEY"`，期望 200；`000/28` = 网络不通，`401` = key 无效，`429` = 限流（退避）。
  - 本地 litellm：`curl --noproxy '*' -m 5 -s -o /dev/null -w '%{http_code}' http://127.0.0.1:4000/health/liveliness`，期望 200。
- 超时判定：>10s 无响应即判死，任务标 `skip:api-down`，不重试网络类失败超过 retry 上限。
- 安全：env 文件 `chmod 600`，且 **不在** `allowed_write_paths` / rsync 回传范围内。

---

## 4. 附：本回执的验证证据

- 三个脚本 `bash -n` rc=0；jsonl 5 行 jq 解析 rc=0（见同目录 `l2b-verify.log`）。
- 未执行：git push/commit、对平板/vlab 的任何写、凭据打印（脚本内键值全为占位符）。
