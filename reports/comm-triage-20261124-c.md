# 通信 lane 复扫（2026-11-24 03:0xZ / 11:0x CST）— D10 只读

> 数字结论：**1 条旧结论被推翻**（aw86927 v3 不是「没到 vger」，是摄取延迟）；**v3 收到 sashiko 4 条意见**
> 其中 **[High] 缺 Signed-off-by 真实且现查可证**；dwc3 v14 已归档、零回复；Mobian !46 无变化。

## 0. 结论表

| 面 | 现态 | 判据来源 |
|---|---|---|
| aw86927 v3 归档 | **已归档（linux-input，2026-11-24T01:50:41Z）** | `https://lore.kernel.org/linux-input/?q=aw86927&x=A`（今 03:0xZ 实取，命中 3/6、4/6、5/6、6/6 + cover 线程） |
| aw86927 v3 评审 | **sashiko 2026-11-24T02:03:12Z 给 4 条**（1 High / 2 Medium / 1 Low） | 同上（`sashiko-bot@kernel.org` Re: `[PATCH v3] …suspend…`） |
| dwc3 v14 归档 | **已归档（2026-11-24T01:50:12Z）**，截至 03:0xZ **零回复** | `lore.kernel.org/all/?q="two connectors sharing one HS data bus"` |
| Mobian `!46` | `opened`，sha `ea9fe3d5`，`user_notes_count=0`，`updated_at 2026-11-23T11:10:29Z`（12 h 无变化） | `gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46` |
| patchwork（arm-msm，id 92） | 查询口径受限（`q` 必须配 project，且旧年份噪声多）；**本次未取得 v14 的 state**，不据此下结论 | `api/1.2/patches/?project=92&q=dwc3` 返回 2013 年旧件 |

## 1. 旧结论更正：`SENT.md` 的「没到 vger 归档链路」不成立

- 2026-11-24 02:35Z 的三处交叉验证（`linux-input`/`linux-devicetree` `not found`、patchwork `hits 0`、marc/mail-archive 404）
  ⇒ 当时写成「这批邮件没有到达 vger 归档链路（同分钟 dwc3 v14 已归档 ⇒ 排除滞后）」。
- **现查（03:0xZ）**：同一查询在 `linux-input` 命中 v3 的 3/6、4/6、5/6、6/6 与 sashiko 回复（时间戳 `01:50:38–02:03:12Z`）。
  ⇒ 真实成因 = **摄取延迟 >1 h**（v14 在 devel 侧 26 s 归档，`linux-input`/input 子系统侧本批慢了 ~70 min），
  不是「未投出」也不是「订阅失效」。**上一轮的最可能假设（订阅失效）随之作废**，不要按它去改订阅或补投。
- 处置：`patches/upstream/aw86927-v3-prep-20261124/SENT.md` 已同轮改写该块；「不要重投整套 7 封」这一条**仍然有效**
  （v4 走新线程，见 §3）。

## 2. sashiko 对 v3 的 4 条 —— 逐条判别（本地可证，不猜）

| # | 严重度 | sashiko 意见 | 判别 | 证据 |
|---|---|---|---|---|
| 1 | **High** | patch 6（`stop playback over suspend and on shutdown`）**commit message 缺 `Signed-off-by:`** | **成立，必须修** | `grep -c '^Signed-off-by:' patches/upstream/aw86927-v3-prep-20261124/v3-0006-*.patch` = **0**（其余 5 件各 = 1） |
| 2 | Medium | `aw86927_reset()` 在 probe 早期失败时对**未初始化**的 `play_work` 调 `disable_work_sync()` ⇒ `WARN_ON(!work->func)` | **成立** | `build/g7b-vk185/drivers/input/misc/aw86927.c`：`INIT_WORK` 在 **:1098**，而 v3 把 `devm_add_action_or_reset(aw86927_reset)` 放在 **:852 附近**（`aw86927_hw_reset()`=:1057、`detect()`=:1067、`devm_request_threaded_irq()`=:1093 之前）⇒ 三处失败路径都会走到 reset |
| 3 | Medium | `aw86927_close()` 里 `WRITE_ONCE(level,0)` 反而让 `ml_effect_timer()` 看到「level 变化」而重排 `play_work` ⇒ 关闭/inhibit 后仍可能起振 | **成立**（逻辑成立；`aw86927_haptics_play()` 只挡 `suspended`，不挡 closed/inhibit） | 同文件 + v3-0006 diff 的 `close()`/`haptics_play()` 两处 |
| 4 | Low | 注释「The chip is powered down」不准（suspend 只 standby）；commit message「resume leaves it in reset, as probe does」不准；`Changes since v2:` 应移到 `---` 之下 | **成立** | v3-0006 正文与 diff 原文 |

另有 1 条**非 sashiko** 的观感问题：v3-0006 的 commit message 段落有明显**断行错位**（`an effect / that is / being played` 被拆成三行）
—— 说明这封 patch 是单独 `format-patch` 出来的、与其余 5 封的生成方式不同，这也是它丢 `Signed-off-by` 的同源原因。

## 3. 下一步（本地可做 / 门槛在哪）

- **v4 备料（local-actionable）**：① 补 `Signed-off-by`（照抄其余 5 封作者行）；② `INIT_WORK` 提前到 `devm_add_action_or_reset` 之前
  （或 devres 动作里判 `work->func`）；③ `close()`/`inhibit` 路径加 closed 闸门（`haptics_play()` 里
  `!input_device_enabled(haptics->input_dev) ⇒ return 0`，或复用同一 `suspended` 语义改名 `inhibited`）；
  ④ 注释/commit message 按 §2 第 4 条改，`Changes since v2:` 移到 `---` 之下。
- 门禁可本地跑：G1 落树、G2 checkpatch、G4/G5 schema 面（`dt_binding_check` 轻）/ **G3 编译暂不做**（旧内存未换，重负载门）。
- **投递 = approval-gated**：v4 走新线程，需用户放行（`TASKS §7` 逐次批准制）。

## 4. 复跑方法（本次用到的命令，只读）

```bash
# lore（Anubis 挡普通 curl，需 Firecrawl/browser 类渲染）
web_fetch 'https://lore.kernel.org/linux-input/?q=aw86927&x=A'          # provider=firecrawl
web_fetch 'https://lore.kernel.org/all/?q=%22two+connectors+sharing+one+HS+data+bus%22&x=A'
# Mobian
curl -sS 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46'
# 本地覆盖检查
grep -c '^Signed-off-by:' patches/upstream/aw86927-v3-prep-20261124/*.patch
```
