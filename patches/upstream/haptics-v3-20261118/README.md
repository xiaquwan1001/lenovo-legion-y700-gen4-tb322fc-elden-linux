# haptics aw86937 v3 备料（2026-11-18，**未发送**）

> 来源 = sashiko 对 v2 的 1 封机器评审（2026-11-17 05:46 UTC，patchwork comment
> `27379422` / `27379419`）。本目录只做「答完 1×High + 1×Low」，**未发信**
> （发信需用户按系列逐次批准，见 `TASKS/README.md` §7 / 待办 C4）。

## 1. 提问 ↔ 改动对照（逐条）

| # | 严重度 | sashiko 原文要点 | 判定 | v3 改动 | 位置 |
|---|---|---|---|---|---|
| H1 | **High** | `aw86927_close()` 里 `WRITE_ONCE(level, 0)` 会让 ml effect timer 重新排队 `play_work`；`input_inhibit_device()` 下 `close()` 不走 `flush()`，unbind 时 `input_flush_device()` 再排一次 `play_work`，而 devm `aw86927_reset()` **不 drain** ⇒ worker 在 regmap/haptics 释放后 `regmap_write()` = use-after-free | **成立** | `aw86927_reset()` 先 `disable_work_sync(&play_work)` 再拉 reset；`INIT_WORK` 提前到 probe 开头（devm action 注册之前），使任何早退路径都能安全释放该 action | `0006`：`aw86927_reset()`、`aw86927_probe()` |
| L1 | **Low** | commit message 说 suspend/shutdown「都 stop + drain + park in reset」，实际 suspend 只 standby、shutdown 只拉 reset 不 stop；`aw86927_haptics_play()` 注释说芯片已断电、排队事件只会失败，实际 suspend 期间只是 standby、排队事件会**重新起播** | **成立** | message 改成逐路径陈述（suspend = 标 suspended + drain + standby；shutdown/unbind/失败 = drain + 拉 reset）；`aw86927_haptics_play()` 注释改成「suspended 时芯片在 standby，排队事件会用 I2C 重新起播；teardown 期间的事件由 `aw86927_reset()` disable 掉」 | `0006`：commit message、`aw86927_haptics_play()` |

## 2. 与 v2 的差分（只该动 0006）

- `0006`：内容重切（drain 进 devm action、`INIT_WORK` 前移、message/注释改写）。
- `0001`–`0005`：**内容与 v2 逐字相同**，差异仅 `[PATCH v2]`→`[PATCH v3]` 编号、
  Subject 折行位置、`@@` hunk 行号偏移（v2 用另一基线切）。复核命令：对每枚
  `diff <(grep -v -E '^(From [0-9a-f]{40}|index |@@ |Subject:)' v2) <(… v3)`，
  仅 0001/0003/0005 的 Subject 折行有差，正文零差异。
- v2 已有的 Krzysztof `Acked-by`（绑定那枚）原样保留。

## 3. 门禁

见 `GATES.md`：`git am 6/6`（树哈希 `c918d45472`）· checkpatch `--strict` **0E/0W/0C**
（0001/0002 的 1 个 W = 浅克隆导致的 `UNKNOWN_COMMIT_ID` 假阳性，`--ignore` 后为 0）·
`W=1` **0 warning** · `dt_binding_check` **rc=0**。

## 4. 文件清单与「SENT 前还差什么」

- `0000-cover-letter.patch`（含 AI 辅助披露 + What changed in v3 + 逐条回答 + 门禁摘要）
- `0001`–`0006`
- `GATES.md`（本目录）

**SENT 前一步（未做，等用户放行）**：

1. 收件人沿用 v2 的 7 个：`dmitry.torokhov@gmail.com`、`robh@kernel.org`、`krzk+dt@kernel.org`、
   `conor+dt@kernel.org`、`linux-input@vger.kernel.org`、`devicetree@vger.kernel.org`、
   `linux-kernel@vger.kernel.org`（MAINTAINERS 现查无 aw86927 独立条目）。
2. `git send-email --dry-run` 一次（只核对编码/收件人）。
3. 覆盖 v2 线程：`--in-reply-to '<20261117052112.32527-1-xiaqinghuan@mail.ustc.edu.cn>'`
   （v2 cover MID，见 `../haptics-v2-20261117/SENT.md`）。
4. 发信后补 `SENT.md`（MID 清单 + lore 复核），再改 `TASKS` §7 `Input: aw86927` 行。
5. **不得声称实测**：两边实件都没有，cover 已写明静态评审。
