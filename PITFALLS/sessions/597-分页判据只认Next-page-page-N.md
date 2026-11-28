# #758 分页循环终止判据不能认裸 `Next page`（stub 的 `Next page:` ⇒ 无限自我分页，挂死 30 min）；顺带：列表解析必须校验「广告行数 = 解析行数」否则静默漏信

- 日期：2026-11-28（`scripts/read-mail-outlook.sh` 首版自检 + 父代理接管修复）
- 现象：`sh scripts/read-mail-outlook.sh --selftest` 起后不返回；`ps` 看到**同一 argv 的进程链不断增长**
  （`sh scripts/read-mail-outlook.sh --days 36500 --mailbox sent` → …），`impl-worker` 的 `bash` 工具调用挂 1800 s 被 subagent 告警。
  父代理第一次 `pkill -TERM -f "read-mail-outlook"` 还**把自己杀了**（`exit 143`）—— 命令串里本身含该模式，属 `pkill` 自匹配（技能 `pkill-self-match`）。
- 根因（可复现）：分页循环写成 `printf '%s\n' "$out" | grep -q "Next page" || break`；
  真 himalaya 的下一页标记是 `Next page: --page 2`，而**自检 stub 的末页只打印 `Next page:`（没有页号）** ⇒ 判据仍命中 ⇒ `page++` ⇒ stub 对 `p>=2` 永远返回同一页 ⇒ 无限循环。
- 修法（已落地）：判据只认**带页号的真实格式** `Next page: --page`，另加硬上限
  ```sh
  printf '%s\n' "$out" | grep -q "Next page: --page" || break
  page=$((page + 1)); [ "$page" -le 200 ] || { echo "… 分页超过 200 页，中止" >&2; break; }
  ```
  修后 `--selftest` 4/4 PASS（含 3 条反样本）、`--check` 5/5 PASS、真实 `--days 2 --mailbox all` 正常出 5 行。
- 纪律：① 任何「读到 X 就继续」的循环，判据要匹配**能解析出下一页编号**的完整标记，不要用前缀；② 循环都要有页数/次数上限；
  ③ 写 stub 时，**stub 的输出格式必须与真件逐字同形**（否则自检只是在测 stub 自己的语法）；④ `pkill -f` 前先排除自身（含 `$$`），否则会杀掉发命令的 shell。
- 同轮第二个坑（同类：格式假设）**未读标记 `*` 列导致静默漏信**：himalaya 把未读信渲染成 `<id>  *  <date>  <sender>  <subject>`，
  解析正则要求 `id` 后紧跟日期 ⇒ 未读行**整条丢弃且无告警**；实测 `--days 9 --mailbox inbox` 修复前 **9 行**、修复后 **36 行**（与直读 himalaya 一致）。
  修法 = 解析前 `sed` 去 `*` 列 + 每页比对「广告行数 vs 解析行数」不相等就 WARN；自检里加反样本（`*` 行必须出现）。
  纪律：**任何「按列解析外部输出」的工具，都要有行数守恒断言**，否则格式一变就是静默漏数据。
- 出处：`scripts/read-mail-outlook.sh`、`reports/outlook-mail-tooling-20261128.md` §3（§3.1 分页 / §3.2 漏信）。
