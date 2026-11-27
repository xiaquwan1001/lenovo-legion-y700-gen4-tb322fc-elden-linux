# 订阅 `coresight@lists.linaro.org` —— 网页操作指引（2026-11-27 晚，人工接手）

> 背景：我方 2026-11-27 投的 3 封（v1）与 v2 的 3 封都收到
> `coresight-bounces … Your message to coresight@lists.linaro.org awaits moderator approval` ——
> 因为发件地址不是列表成员，列表侧只经 Cc 进 lore，列表成员看不到。用户已放行订阅。
> 三条**邮件**路已试全败；结论：**只能网页（Postorius）登录态确认**。

## 0. 邮件路为什么不行（已实测，别再试）

| 尝试 | 结果 |
|---|---|
| 发 `coresight-join@lists.linaro.org`（Subject: subscribe） | ✅ 触发确认信：From `coresight-confirm+9e940513…@lists.linaro.org`，Subject `Your confirmation is needed to join the coresight@lists.linaro.org mailing list.` |
| 回信到 `coresight-confirm+9e940513…@lists.linaro.org`（正文 "Confirming the subscription of …"） | ❌ 仍被当作非成员压审（无 welcome） |
| 发 `coresight-request@lists.linaro.org`，正文 = `confirm 9e940513…` | ❌ `No confirmation token found` |
| 同上但 Subject 也放 token | ❌ `Confirmation token did not match` |

判读：该 token 属于**站点账号注册**（Mailman "Address Registration Confirmation"），不是列表订阅确认；
且确认 URL `https://lists.linaro.org/mailman3/lists/coresight.lists.linaro.org/confirm/<token>` 未登录时 404
（页面里给出 `/accounts/login/?next=…` ⇒ 必须登录态）。我们连续尝试可能已使旧 token 失效。

## 1. 网页步骤（清单版，按顺序做）

1. 打开列表页：<https://lists.linaro.org/mailman3/lists/coresight.lists.linaro.org/>
2. **先登录/注册**（右上角 `Login` / `Sign Up`）。用**同一个地址** `xiaqinghuan@mail.ustc.edu.cn`：
   - 若 `Sign Up`：会发一封**站点注册确认**邮件，标题类似 `Your confirmation is needed …`，
     邮件里有确认链接 —— **必须登录后**打开该链接才生效（未登录点开是 404，页面会给登录入口）。
3. 回到列表页，用页面上的 **Subscribe**（anonymous subscribe 表单，字段 = Email + 可选 Display name）提交；
   或登录后在 `Manage subscription` 里订阅。
4. 收确认信：From `coresight-confirm+<token>@lists.linaro.org`，标题
   `Your confirmation is needed to join the coresight@lists.linaro.org mailing list.`
   - **先查 `Junk E-mail`**：USTC 邮箱会把列表信判成 `[SPAM]`（`read-mail-ustc.py` 默认就扫三个箱）。
   - 打开信里的确认链接（保持登录态）。
5. **成功判据（三条都要）**：
   - 收到 `Welcome to the coresight@lists.linaro.org mailing list` 欢迎信；
   - Postorius 里该列表的 `Manage subscription` 能看到 `xiaqinghuan@mail.ustc.edu.cn`；
   - 之后发到列表的信**不再**出现 `awaits moderator approval`（可发一封 v2 的 `Re:` 回帖做验证，不必新开系列）。

## 2. 订上以后要做的两件事（本仓侧）

1. `TASKS/NEXT.md` 的 **T24** 改 ✅，并把「列表侧可见性」写进 `TASKS/UPSTREAM.md` §7 的投递口径行。
2. 反查 v1/v2 是否进了列表归档：`https://lists.linaro.org/mailman3/hyperkitty/list/coresight@lists.linaro.org/`
   （lore 一直能看到；列表归档是另一份，用来证「成员可见性」）。

## 3. 不用再做的事

- 不用再发 `-join@` / `-confirm+…@` / `-request@` 的 confirm 命令（三条路已否证，重复会继续污染 token）。
- 不影响在飞评审：**James Clark 的 `Reviewed-by` 就是从 lore/Cc 拿到的**（`<6f997513-27da-47e5-83bb-18c267e930c6@linaro.org>`），
  v2 已按他的意见带 `Fixes:` 标签并已发出（3×250，lore `t.mbox.gz` 200/7229 B 实证）。
