# Outlook 邮件通道工具化（`scripts/read-mail-outlook.sh`）— 2026-11-28

> 背景：用户 2026-11-28 新部署 Outlook 邮箱（himalaya + XOAUTH2 `ortie`），D10 通信 lane 以后每轮都要扫这一个箱。
> 本轮由子代理起草脚本，**两个真缺陷由父代理独立复核发现并修掉**（30 min 挂死 + 84% 静默漏信），最终版本父代理亲测。
> 产物：`scripts/read-mail-outlook.sh`（7849 → 现查字节）、`RESOURCES/README.md` §5 一行指针、本条报告、`PITFALLS #758`。

## 1. 用法与判据

```sh
sh scripts/read-mail-outlook.sh --check                      # 通道自检：himalaya / token / 三箱 SELECT
sh scripts/read-mail-outlook.sh --selftest                   # stub 注入式反样本自检（不碰真实账号）
sh scripts/read-mail-outlook.sh --days 9 --mailbox inbox     # 只读快照（不改已读态）
sh scripts/read-mail-outlook.sh --days 2 --mailbox all       # inbox+junk+sent
```

- 只读实现：全部走 `himalaya envelope list`（不 `message read`），因此**不改变已读标记**。
- 每次外部调用都套 `timeout -k 5 60`；分页有硬上限 200 页。
- `sent` 别名缺陷由脚本内部规避：把用户配置 `mailbox.alias.sent = "Sent Items"` 用 `sed` 改成 `"Sent"` 写进临时文件，再 `-c` 叠加传入，**不改 `~/.config`**（那是用户环境）。

## 2. 父代理实测（本报告写就时现跑）

```
$ sh scripts/read-mail-outlook.sh --check
[PASS] himalaya 存在: /usr/bin/himalaya
[PASS] XOAUTH2 token 可取 (ortie, len=1420)
[PASS] mailbox 'inbox' 可 SELECT
[PASS] mailbox 'junk' 可 SELECT
[PASS] mailbox 'sent' 可 SELECT
check: 全部通过                      # rc=0

$ sh scripts/read-mail-outlook.sh --selftest
[PASS] 反样本1: 账号不可用 ⇒ check rc≠0
[PASS] 反样本2: mailbox=bogus ⇒ rc≠0 且报错点名 bogus (rc=2)
[PASS] 反样本3: --days 3 排除 2020 旧信且保留新信 (rc=0)
[PASS] 反样本4: 未读标记 * 的邮件行仍被列出 (rc=0)
[PASS] 附加: sent 经临时配置修正可列出 (rc=0)
selftest: 全部通过                   # rc=0

$ sh scripts/read-mail-outlook.sh --days 9 --mailbox inbox | wc -l
36                                   # 与 D10 lane 直读 himalaya 的 inbox 36 封逐数一致
```

反样本 4 是**针对本轮真缺陷**加的：修前该输入会漏掉 `*` 行；加断言后先红后绿（红样本已手工复现：见 §3.2）。

## 3. 两个真缺陷（子代理版 → 父代理修）

### 3.1 分页终止判据太宽 ⇒ `--selftest` 无限自我分页，挂死 30 min

- 子代理版：`printf '%s\n' "$out" | grep -q "Next page" || break`。
- 真 himalaya 下一页标记是 `Next page: --page 2`；**subagent 自写 stub 的末页只打印 `Next page:`（无页号）** ⇒ 判据仍命中 ⇒ `page++` ⇒ stub 对 `page>=2` 恒返回同一页 ⇒ 无限循环。
- 现场：`ps` 出现同 argv 进程链持续增长；`impl-worker` 的 `bash` 工具调用挂 1800 s 触发 subagent 告警，父代理 `stop` 该 run 后接管。
- 附带：父代理第一次 `pkill -TERM -f "read-mail-outlook"` **把自己杀了**（`exit 143`）—— 命令串里含同一模式 = `pkill` 自匹配（技能 `pkill-self-match`）。
- 修法：判据只认 `Next page: --page`，并加 `page <= 200` 硬上限。

### 3.2 未读标记列 `*` 未处理 ⇒ 静默漏信（100 封只出 16 行）

- himalaya 把未读信渲染成 `<id>  *  <date>  <sender>  <subject>`；子代理的正则要求 `id` 后紧跟日期 ⇒ **所有未读行整条丢弃，且无任何告警**。
- 实测：`--days 9 --mailbox inbox` 修复前 **9 行**（当时以为窗口内只有 9 封），修复后 **36 行**；与 D10 lane 直读结果（36）对上。
- 修法：① 解析前先 `sed` 去掉 `*` 列；② 每页加「广告行数 vs 解析行数」比对，不相等就 WARN 到 stderr（防下一次 himalaya 改格式再静默漏）。
- 注意：本轮 D10 报告（`reports/comms-track-20261128-c.md`）的数字来自 lane 直读 himalaya，**未受本 bug 影响**；脚本侧已对齐到同一组数字。

## 4. 登记

- `PITFALLS #758`（`PITFALLS/sessions/597-分页判据只认Next-page-page-N.md`）：分页判据只认带页号的完整标记 + 页数上限 + stub 输出必须与真件同形 + `pkill -f` 自匹配。
- `RESOURCES/README.md` §5「通信 / 邮件（2026-11-28 新立面）」一行指针。
- 未做（留给用户）：把 `~/.config/himalaya/config.toml` 的 `mailbox.alias.sent` 直接改成 `"Sent"`（属用户环境，脚本已规避）。
