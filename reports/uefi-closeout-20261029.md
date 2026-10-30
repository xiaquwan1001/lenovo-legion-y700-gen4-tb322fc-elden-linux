# UEFI 线收口（2026-10-29，lane H5）

> 纯主机、只读（`gh` 只读 / `curl` / 反汇编 / 文件核对），**不改设备、不刷机、不发评论不开 issue**。
> 任务来源：lane H5 派工单。路线 A（UEFI 间接引导）维持搁置（`TASKS` §4 N1、§5 Q25），本报告不做可行性论证。

## §0 一句话结论

**回帖已发**：comment `6487769609`（作者 `xiaquwan1001`，2026-10-29T04:16:34Z，6 227 字符）真实存在，且与定稿 `reports/uefi-issue12-reply-final-draft-20261029.md` §2 **逐字一致**（diff 为空）；`TASKS/sessions/2026-10-29-收官-…camss定调.md` 记「已发」为**事实**，定稿报告首行与 `TASKS/sessions/2026-10-29-UEFI回帖定稿.md` 的「未发送」为**过期快照**（写于发送之前）。**上游有新回复**：`sunflower2333` 于 04:19:30Z（我方评论 3 分钟后）回 `6487815074`（79 字符）：「别的设备当然可以用，我都说了是你系统版本问题。/ 别用劣质token瞎猜了。/ 你要是没有办法把屏幕拍给AI调试，就去弄个UEFI的USB ACM Gadget。」——实质上确认了我方 Q1 的 (a) 假设（固件版本相关数据），并给出调试手段建议（USB ACM Gadget 出控制台）。issue 仍 OPEN。

## §1 issue #12 现状（2026-10-29 核对）

核对方式：`gh auth status`（已登录 `xiaquwan1001`）→ `gh api repos/sunflower2333/mu_wide_platforms/issues/12/comments --paginate`，原始响应落 `reports/artifacts/uefi-issue12-20261029/comments-api-raw.json`（29 998 B）；issue 状态快照 `issue-state.json`。

- issue 状态：**OPEN**，`comments=7`，最后更新 `2026-10-29T04:19:30Z`，标题未变（仍带「which platform config is it missing?」旧框架字样——标题由作者所有，我方不改）。
- 全部 7 条评论时间线：

| # | id | 作者 | 时间 (UTC) | 长度 | 要点 |
|---|---|---|---|---|---|
| 1 | 6082698119 | sunflower2333 | 10-09 14:14:56 | 83 | 「firmware version 问题，需要 special patch on UFSDxe」 |
| 2 | 6318155640 | xiaquwan1001 | 10-21 14:09:43 | 2 522 | 我方首条：两份 UFSDxe 静态分析 + 崩溃日志比对 |
| 3 | 6460500452 | xiaquwan1001 | 10-28 04:14:57 | 3 159 | bootshim 加载地址在 ABL 交接 RAM 内等新事实 |
| 4 | 6460662381 | sunflower2333 | 10-28 04:27:34 | 60 | 「Link State 处于 Sleep，写个 tiny dxe 拉起来」 |
| 5 | 6467336320 | xiaquwan1001 | 10-28 11:04:46 | 5 423 | 我方接受 Sleep 方向 + 提「缺哪个 platform config」框架（后被撤回） |
| 6 | **6487769609** | xiaquwan1001 | **10-29 04:16:34** | **6 227** | **本次定案对象**：撤回「缺 config」框架 + 0x402 静态证明 + Q1/Q2 |
| 7 | **6487815074** | sunflower2333 | **10-29 04:19:30** | **79** | **上游对我方 6 号评论的回复**（全文见下） |

- `6487769609` 正文前 200 字：`Thanks for the pointer. Before following the tiny-DXE route I have to correct our own framing first: we now have a static proof of what \`0x402\` is, and it is not a platform configuration entry. That c…`
- 逐字核对：定稿 §2 抽取正文 6 227 字符 == 已发正文 6 227 字符，`draft == posted: True`（无任何编辑痕迹，`updated_at == created_at`）。
- **上游新回复全文**（`6487815074`）：

  > 别的设备当然可以用，我都说了是你系统版本问题。\n别用劣质token瞎猜了。\n你要是没有办法把屏幕拍给AI调试，就去弄个UEFI的USB ACM Gadget。

- **该回复对我方 Q1/Q2 的对应关系**：①「系统版本问题」再次确认其 10-09 立场（= 我方 Q1 的 (a)「firmware-version-dependent data blob」），**未点名**是哪个组件填 `ctx+4`；②「USB ACM Gadget」是对我方「无早期控制台输出」困境的调试手段建议；③ Q2（`UFSSmmuConfig`/SMMU 层）**未被回应**；④ 语气含「别用劣质token瞎猜了」，上游对我方基于反汇编的推断路径不认可。无后续我方评论，线程到我方收到该回复为止。
- **是否需要回帖**：本 lane 红线不允许回帖。判断：当前路线 A 搁置、无新证据可反驳「系统版本」论，且回帖只剩客套/追问风险 ⇒ **不建议立即回帖**；若用户将来重启 UEFI 线并做出 USB ACM Gadget 产出，可再回一条「已按建议做 ACM Gadget，`UFS.c+2326` 仍未解」。草案已备：`out/uefi-issue12/reply-if-restart-20261029.txt`（**未发送**，仅存档）。

## §2 三条主机侧补证（M1 / M3 / M4）

（待填；M2 需上机，标「待上机」不做）

## §3 E0/E1/E2 复现件盘点与恢复时第一步

（待填）

## §4 SSOT 并入建议（只建议，不改 TASKS/INDEX/PITFALLS）

（待填）

## §5 已做 / 未做 / 待拍板

（待填）
