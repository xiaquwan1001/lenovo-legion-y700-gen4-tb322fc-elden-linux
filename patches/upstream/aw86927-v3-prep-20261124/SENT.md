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
- **2026-11-24 02:35 UTC（发信 ~45 min）三处交叉验证**：
  - `lore.kernel.org/linux-input/…-2-…` → `not found`；`lore.kernel.org/linux-devicetree/…` → `not found`；
  - `patchwork.kernel.org/api/1.2/patches/?msgid=…-1-/-2-` → **hits 0**（patchwork 也没有 ⇒ 不是"lore 慢"）；
  - `marc.info` 404、`mail-archive` 「Not Found」。
  ⇒ **结论：这批邮件没有到达 vger 归档链路**（同分钟投出的 dwc3 v14 已归档 ⇒ 排除本机通道/普遍滞后）。
- 发送侧证据：`git send-email` 对 7 封各报 `Result: 250`；收件人解析正确（含 `linux-input@vger.kernel.org`）。
- **最可能假设**：`linux-input` 是「订阅者才能投」的列表（vger 审核队列，或静默丢弃非订阅者）。
  v2 于 11-17 曾归档成功 ⇒ 订阅可能在期间失效。
- **待用户**（人不在时不做）：核实/恢复 `linux-input` 订阅，或改用 `dmitry.torokhov@gmail.com` 直投 + 论坛转贴。
  **不要重投整套 7 封**（会制造重复线程）；若最终要重发，只补一封 cover 说明「v3 已发但未进归档」并附
  `b4` 或 `lore` 之外的链接。
- **发送命令**：`bash SEND.sh --yes`
