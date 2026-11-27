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
