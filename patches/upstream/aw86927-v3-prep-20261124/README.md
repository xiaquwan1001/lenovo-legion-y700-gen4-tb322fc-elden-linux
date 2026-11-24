# aw86927 v3 备料（2026-11-24）——**未投递，等放行**

- 触发：sashiko 对 v2 6/6 的 **1×[High] + 1×[Low]**（2026-11-17 05:46Z）。两条都成立，**只改 6/6**。
- 内容：1–5 与 v2 逐字节相同；6/6 见 `GATES-v3.md` §1（devres 动作先 `disable_work_sync` 再拉 reset；
  message 与代码对齐）。
- 门禁：G1 6/6 干净落树、G2 checkpatch 0E/0W/0C ×6、G3 `W=1` 编译 rc=0/0 warning（7.4-rc3 基线）。
  另按 **linux-next master（v2 原基线，2026-11-24 快照）** 复验：1–5 干净；6/6 因 `#include` 块漂 1 行
  **已按该基线重生成上下文**后再验干净（详见 `GATES-v3.md` §4，含「别在本项目仓里跑内核 checkpatch」的坑）。
- 与 v2 的关系：v2 = `../haptics-v2-20261117/`（已投、有 SENT.md）；v3 只覆盖 6/6。
- 投递：**未发**。放行后 `bash SEND.sh`（默认 dry-run，`--yes` 才真发；收件人同 v2：7 个、新线程 7 封）。
  投前建议先在 **linux-next 基线**复跑 G1/G3（v2 的原基线）。
