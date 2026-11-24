# aw86927 v3 投递记录（2026-11-24）

- **时间**：2026-11-24 ~01:50Z（主机时钟 09:50 +0800）
- **结果**：**7 封全 `Result: 250`**（日志 `logs/sent-20261124-095028.txt`）
- **cover MID**：`<20261124015028.1427393-1-xiaqinghuan@mail.ustc.edu.cn>`（1/6..6/6 = `-2 .. -7`）
- **线程形态**：新线程（cover 无 `In-Reply-To`）
- **内容**：只改 6/6（1–5 与 v2 逐字节相同）——
  ① devres 动作先 `disable_work_sync(&haptics->play_work)` 再拉 reset（修 sashiko [High] unbind 竞态，
  inhibited 设备 unbind 时 `input_close_device()` 被跳过、flush 会重排队）；`shutdown()` 复用同一 helper；
  ② message 与代码对齐（suspend 只 standby、shutdown 只 reset）。
- **门禁**：`GATES-v3.md`（G1 6/6 干净落树；G2 checkpatch 0E/0W/0C ×6；G3 `W=1` 编译 rc=0/0 warning；
  §4 = 按 linux-next master 2026-11-24 快照复验，6/6 上下文已按该基线重生成后干净）
- **lore 复核（2026-11-24 01:53 / 02:20 UTC 两次实测）**：`linux-input` 与 `linux-devicetree` **两侧都 `not found`**。
  对照：26 秒前投的 dwc3 v14 已 `linux-devicetree` 归档 4/4 ⇒ 不是本机通道问题，也不是同一时段的普遍滞后。
- **★2026-11-24 03:0x UTC 更正（是摄取延迟，不是投递失败）**：同一批邮件此时已在 `linux-input` 归档
  （3/6、4/6、5/6、6/6 + sashiko 回复，时间戳 `01:50:38–02:03:12Z`）。
  02:35Z 判的「这批邮件没有到达 vger 归档链路」**作废**；真实成因 = input 子系统侧摄取延迟 **>1 h**
  （同分钟投出的 dwc3 v14 在 devel 侧 26 s 归档，属列表差异）。**⇒ 不要按「订阅失效」去改订阅或补投。**
  判据与全过程：`reports/comm-triage-20261124-c.md` §1。
- **v3 已收到 sashiko 4 条意见（2026-11-24T02:03:12Z）**：**[High] patch 6 缺 `Signed-off-by:` = 真实**
  （`grep -c '^Signed-off-by:' v3-0006-*.patch` = 0，其余 5 件各 = 1）⇒ **必须出 v4**；
  另 2 条 Medium 也成立（devres 动作对未初始化 `play_work` 调 `disable_work_sync`；`close()` 里
  `level=0` 让 memless timer 重排 play_work），1 条 Low（注释/commit message 措辞 + `Changes since v2:` 位置）。
  逐条判别：`reports/comm-triage-20261124-c.md` §2。
- **历史（已作废，保留作沿革）**：2026-11-24 02:35Z 三处交叉验证（`linux-input`/`linux-devicetree` `not found`、
  patchwork `hits 0`、marc/mail-archive 404）当时判「未到 vger」；**这些判据的时效不足 1 h，不可再作结论依据。**
  发送侧证据仍成立：`git send-email` 7 封各 `Result: 250`，收件人解析正确（含 `linux-input@vger.kernel.org`）。
- **发送命令**：`bash SEND.sh --yes`
