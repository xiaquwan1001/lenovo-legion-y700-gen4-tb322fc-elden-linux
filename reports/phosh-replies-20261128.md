# phosh/gmobile 三封维护者回复处置 + 协议层讨论起头（2026-11-28）

> **外发纪律**：按项目 AGENTS「默认外发 + 发完立刻报备」执行；三件前提都满足（AI 披露 / 可复现证据 / 逐条回应）。
> 本报告是这些外发动作的唯一台账；对应行号已回填 `TASKS/NEXT.md` 的 T37。

## 0. 数字结论

| 项 | 值 |
|---|---|
| 收到的维护者回复 | **3 封**（Guido Günther，`2026-11-28T08:43Z`/`08:47Z`/`08:50Z`） |
| 处置动作 | **6 次外发**：phoc `!829` 描述改写 + 转 Draft + 1 条回帖；gmobile `!131` commit 改写 + 描述改写 + 1 条回帖；phoc `#125` 1 条回帖；wayland-devel 1 封邮件 |
| 代码改动 | **0 行**（`!829` 只改 commit message，代码 `4931414`→`c2d2bf3` diff 不变；`!131` 只改 commit message，代码 `ac5aae2`→`4865aa8` diff 不变） |
| 遗留 | 1 项待核（wayland-devel 归档，非订阅者投递通常进审核队列）；1 项待上游（协议层讨论有结论后才回 `!829`） |

## 1. 上游原话（三封，摘关键句）

| 线程 | 原话 |
|---|---|
| phoc `!829`（edge-swipe MR） | 「there is no concept of "back" in Linux. You need to establish that on a Wayland protocol level/toolkits first… You basically want to have the discussions that you list in "follow-up" **first** before adding anything as this is the important part, the code is then quick to add.」+「Is this AI generated? … please reduce the verbosity in MRs, commit messages to a bearable amount.」 |
| phoc `#125`（back 手势 issue） | 「The issue here is not the phoc code but the toolkit / protocol integration. See my comment in `!829`, would be great if you'd pick that up.」 |
| gmobile `!131`（Y700 面板） | 「Is this AI generated? See codeberg.org/Phosh/phosh-dev-site/pulls/15 … Please compare your MR to what others in the same area do and adjust commit message and MR description accordingly (please also keep that in mind for future MRs).」 |

**规约原文要点**（`phosh-dev-site` PR 15，2026-11-28 读取）：①所有 genAI 使用必须披露，**commit 与 MR 描述都要加 `Assisted-by:`**；②人必须完全理解所交代码；③issue/讨论可用 AI，但人负责降噪删冗；④禁 AI 生成媒体；⑤DCO 责任不变。

## 2. 已执行动作（逐条可复查）

### 2.1 gmobile `!131`

| 项 | 动作 |
|---|---|
| commit message | `display-panels:` → **`data:`**（对齐同目录既有 20+ 条：`data: Add display panel for Motorola Moto G10 (capri)` 等）；正文压到 4 段（尺寸/圆角出处/实测/披露）；补 **`Signed-off-by:`**（原来缺）、`Assisted-by: pi coding agent (LLM)`、`Part-of: <MR>` |
| 代码 | 未改（`data/devices/display-panels/lenovo,elden.json` + gresources 登记各 1 行） |
| 新 sha | `4865aa8`（force-push 到 `xuqianhui1001/gmobile:lenovo-elden-panel`） |
| MR 描述 | 压到 3 行（沿用 `!129` 的短形态），加 `Assisted-by:` |
| 回帖 | note `2949022`（承认 LLM 起草、说明已改、并给出「80 px @ scale 3.0 = 26.7 逻辑 px < 顶栏 9 px 最小 padding ⇒ 顶栏视觉不动」这条对上游有用的实测） |

### 2.2 phoc `!829`

| 项 | 动作 |
|---|---|
| commit message | 正文压短（3 段），补 `Assisted-by:`；**代码 diff 逐字节不变**（`4931414` → `c2d2bf3`） |
| MR 状态 | **`Draft:`**（`draft=True`）：采纳「讨论先行、代码后补」 |
| MR 描述 | 从 5 节压到 3 节：现状形状 / **要先把哪两件事定下来**（导航意图放哪层、compositor 该不该自己决定动作）/ 实测边界；加 `Assisted-by:` |
| 回帖 | note `2949029`：承认 LLM 起草、说明转 Draft 的理由、并给出我们能提供的那份真值（边缘手势下客户端**确实收到干净 cancel**，这是用户态守护做不到的部分） |

### 2.3 phoc `#125`

- 回帖 note `2949030`：认同「phoc 不是问题所在」；给出支持他判断的本机数据点（phoc 侧能做的只有 close，对自带 back 栈的客户端是错的）⇒ phoc 应最后做。

### 2.4 协议层讨论起头（wayland-devel）

| 项 | 值 |
|---|---|
| 投递 | `2026-11-28T09:42Z`，`send-mail-ustc.py --send` → **`已发送 OK`** |
| Message-ID | `<179585895673.2877352.14872169215361909869@mail.ustc.edu.cn>` |
| Subject | `Back / navigation intent on touchscreens: protocol, keysym, or toolkit?` |
| 正文留档 | `out/mail-20261128/navigation-intent-01.txt`（47 行，纯 ASCII） |
| 内容 | 三条候选形状（① 约定：合成 `XF86Back` 键盘事件 ② 协议：`xdg_toplevel` 导航意图事件 ③ 工具包自理）+ 事前检索证据（本列表 `back gesture` 只命中一条无关 libinput announce）+ 要 prior art + 愿意写提案与 phoc/GTK 原型 |
| 事实核验 | 「Chromium 把 `XF86XK_Back` 映射 `VKEY_BROWSER_BACK`」已对源码逐行核实（`ui/events/keycodes/keyboard_code_conversion_x.cc` 第 976 行附近） |
| 披露 | 文末「I drafted this mail with an LLM coding agent and edited it myself; the Chromium mapping above was checked against the source.」 |

## 3. 待核 / 下一步

1. **归档复核（必须做，不能以「已发送 OK」当投递成功）**：`lore.freedesktop.org/wayland-devel/?q="navigation intent"` 与 `lists.freedesktop.org/archives/wayland-devel/2026-November/`。09:47Z 首查**尚无**该信（非订阅者投递进审核队列是 freedesktop 常规行为）。若 24 h 内仍无 ⇒ 选项：(a) 订阅 `wayland-devel` 后重投；(b) 改投 `wayland-protocols` 仓库 issue（需用户裁决，因为会动邮箱订阅状态）。
2. **`!829` 的回归路径**：协议层有结论后才回 MR（届时若结论是「toolkit 自理」，则关掉 `!829` 并把补丁留作 `patches/` 备案；若结论是「要协议事件」，则先写提案再改 phoc 侧消费者）。
3. **`!131`**：等 review；若要求补截图，用 `/tmp` 现拍（设备侧 inert 件已在，`gmobile` 判据 1 已绿，见 `reports/gmobile-t34-build-deploy-20261128.md`）。
4. **以后所有上游 MR 的默认形态**（写进习惯，不再等提醒）：commit 短正文 + 数据出处 + `Signed-off-by` + **`Assisted-by`** + `Part-of`；MR 描述 ≤ 3 段；能贴的实测判据贴一条，不铺设计文档。
