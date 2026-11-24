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
- **lore 复核**：待摄取后按 MID 查 `https://lore.kernel.org/linux-input/<MID>/` 与 `/linux-devicetree/<MID>/`
- **发送命令**：`bash SEND.sh --yes`
