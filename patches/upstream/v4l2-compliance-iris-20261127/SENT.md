# 已投：iris v4l2-compliance driver-quality 系列（3 贴）

- **时间**：2026-11-27 23:20 CST（git send-email，USTC SMTP，`Result: 250`）
- **发件人**：Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>
- **To**：linux-media@vger.kernel.org
- **Cc**：linux-arm-msm@vger.kernel.org、Vikash Garodia、Dikshita Agarwal、Abhinav Kumar、Bryan O'Donoghue、Mauro Carvalho Chehab、Hans Verkuil、Stefan Schmidt
- **Message-ID（本次实发，cover 及 -2/-3/-4）**：
  - cover  : `<20261127152024.2149804-1-xiaqinghuan@mail.ustc.edu.cn>`
  - patch1 : `<20261127152024.2149804-2-xiaqinghuan@mail.ustc.edu.cn>`
  - patch2 : `<20261127152024.2149804-3-xiaqinghuan@mail.ustc.edu.cn>`
  - patch3 : `<20261127152024.2149804-4-xiaqinghuan@mail.ustc.edu.cn>`
- **正文/AI 披露**：cover letter 已含「AI assistance was used… I reviewed every change… measurements are mine」。
- **三件前提**：① AI 披露 ✅ ② 可复现证据（v4l2-compliance 39/48→47/48、REPORT.md 有代码位置与复现）✅ ③ 无 reviewer 意见可逐条回应（首次投递）N/A。
- **lore 复核**：✅ 已归档 4 封（cover + 3 patch），线程正确 —— https://lore.kernel.org/linux-media/20261127152024.2149804-1-xiaqinghuan@mail.ustc.edu.cn/ （Thread overview: 4 messages）。
- **回滚/撤回**：内核列表无法撤回，若需更正只能回信 self-NACK 或发 v2。

## 后续（2026-11-28 早，无人值守轮）

- **Bryan O'Donoghue 回帖**（2026-11-27T16:04:09Z，MID `<6505dda0-f534-4705-bcea-ecf5f6b9ec30@kernel.org>`，挂在 1/3 下）：
  「Please add an appropriate Fixes: and Cc: stable@vger.kernel.org」。
- **对 mainline 机械对账结论**：1/3 **重复** `1facae9bc3c1`（Vishnu Reddy，2026-09-29，已含 `Fixes: 94ef75095d5e` + `Cc: stable`）；3/3 被主线 `iris_vdec_s_fmt()` 的无条件 `inst->crop` seed（v7.4-rc3 `iris_vdec.c:271-274` / `:309-312`）取代；**仅 2/3 仍成立**。
- **v2 = 单贴** `0002-v2-fill-default-colorspace.patch`（rebase 到 v7.4-rc3，`Fixes: b530b95de22c` + `Cc: stable`，AI 披露，正文要求 drop 1/3 与 3/3）：
  `git apply --check` OK / `checkpatch --strict` 0E 0W 0C / `make M=drivers/media/platform/qcom/iris modules` 编过 / `git send-email --dry-run` 解析 OK（stable@vger 由 Cc trailer 自动带入）。
- **未投**：本机只有 GDM greeter 会话，keyring 锁 ⇒ `git credential fill` rc=128 `could not read Password`。投递命令与 lore 复核判据见 `reports/v4l2-compliance-v2-20261128.md` §4（需用户登录后一条命令发）。

## 2026-11-28 二版 patch（Fixes 甄别被独立复核纠正）

- lane 独立核（`reports/v4l2-compliance-overlap-20261128.md`）：`b530b95de22c` 的 **parent `38fc8beaba55` 里那 4 行 `*_DEFAULT` 已存在** ⇒ 父代理初判「b530b95 是初始化引入点」作废。
- 父代理复跑（GitHub API 逐级 parent + raw 文件「有/无」）：`iris_vdec.c` 在 **`38fc8beaba55`**（reqbuf 提交，2025-02-07）才创建（其 parent `bb8a95aa038e` 该文件 404），**初始化**引入点 = 38fc8bea；**行为**（S_FMT 存 DEFAULT / G_FMT 回吐）引入点 = `b530b95de22c`。
- 二版报文同时点名两个 sha，`Fixes:` 仍用 `b530b95de22c`（缺陷可观测形态的引入点）。新 sha256 = `35816a1bc7db3db9…`，`git apply --check` 与 `send-email --dry-run` 重跑均 OK。

## 2026-11-28 08:37 CST —— **v2 已实发（单贴，keyring 解锁后）**

| 项 | 值 |
|---|---|
| 命令 | `git send-email --confirm=never … --in-reply-to=<v1 cover> 0002-v2-fill-default-colorspace.patch`（用户已登录图形会话，keyring 解锁） |
| 结果 | **`Result: 250`**（日志 `out/mail-20261128/send-v2-iris-colorspace.log`） |
| Message-ID | `<20261128003737.1300698-1-xiaqinghuan@mail.ustc.edu.cn>` |
| 收件人 | To `linux-media`；Cc `linux-arm-msm`/Vikash/Dikshita/Abhinav/Bryan/Mauro/Hans/Stefan + `stable@vger`（Cc trailer 自动带入） |
| lore 复核 | ✅ `GET /linux-media/<MID>/t.mbox.gz` **HTTP 200 / 15 377 B gzip**；线程 **6 封**（v1 cover+3 贴+Bryan 回帖+本 v2），Subject 未改写，`Fixes:`/`Cc: stable`/SoB 逐字在档 |
| 正文要点 | v2 只留 colorspace 1 贴；明写 1/3 重复主线 `1facae9bc3c1`、3/3 被主线 s_fmt 无条件 crop seed 取代，请 drop；点名 `38fc8beaba55`（初始化）与 `b530b95de22c`（行为）两个 sha |

## 2026-11-28 10:36 CST —— **v3 已实发（只改 commit message，代码 diff 与 v2 逐字节同）**

| 项 | 值 |
|---|---|
| 起因 | media-ci `patchwork@media-ci.org`（2026-11-28T01:27:06Z）对我方 v2 判 `ERROR: Fails one or more mandatory checkpatch tests`；本机复现命令 = `perl scripts/checkpatch.pl --no-tree --strict`，v2 = **2E/4W**（`GIT_COMMIT_ID` 标题折行 + 行首 `Cc:` 前导空格） |
| 备料 | `0003-v3-fill-default-colorspace.patch`（sha256 `713c41d2…`）+ `V3-SEND.md` + `logs/checkpatch-v2-v3-20261128.log`；代码区 `sed -n '/^diff --git/,$p'` 与 v2 逐字节相同（`diff` 空输出，diff 区 sha256 两边均 `8515c6c1…`） |
| 门禁（父代理独立重跑） | v3 `--no-tree --strict` = **0 errors**（2 条 `Unknown commit id` 仅因复核用的 `/tmp/ktree` 无真 git 对象，非报文问题） |
| 发送 | `git send-email --confirm=never … --in-reply-to=<v1 cover>`；**`Result: 250`**（日志 `out/mail-20261128/send-v3-iris-colorspace.log`） |
| Message-ID | `<20261128023628.24408-1-xiaqinghuan@mail.ustc.edu.cn>` |
| 收件人 | To `linux-media`；Cc `linux-arm-msm`/Vikash/Dikshita/Abhinav/Bryan/Mauro/Hans/Stefan + `stable@vger`（trailer 自动带入） |
| lore 复核（父代理自查） | `GET /linux-media/<MID>/t.mbox.gz` **HTTP 200 / 16 939 B gzip / 57 949 B 解压**，线程 **7 封**（v1 cover+3 贴+Bryan 回帖+v2+v3），Subject 未改写，`Fixes: b530b95de22c` / `Link:` / `Cc: stable` 均在档 |
| 正文实质 | ① 正面回应 Bryan：1/3 与主线 `1facae9bc3c1` 重复，**"there is nothing left to tag there now"**，请 drop；② 3/3 已被主线 `iris_vdec_s_fmt()` 无条件 crop seed 取代 ⇒ dropped；③ 声明「v3 只重写 commit message，diff = v2，未 rebase/未重测」；④ AI 披露在档 |
