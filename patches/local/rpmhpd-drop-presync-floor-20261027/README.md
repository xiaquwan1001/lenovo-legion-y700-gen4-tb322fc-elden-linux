# 删除 `rpmhpd` 的 vendor `presync_floor`（U3 → D13，2026-10-27）

判定报告 = `reports/u3-rpmhpd-presync-floor-20261027.md`。

- 基树：`build/aw-chip`（7.3 线 scratch worktree @ `24223e44a`，与日常线载荷同源）
- 文件：`0001-pmdomain-rpmhpd-drop-vendor-presync-floor.diff`（`git diff` 格式，**−8 行**）
- **删后 `drivers/pmdomain/qcom/rpmhpd.c` 与 pristine 7.3-rc7 逐字节相同**（`diff` rc=0）⇒ 这条 vendor 增量整条消失
- 门禁（已跑）：`rpmhpd.o` 编译 rc=0；`W=1` 0 warning；全树 `grep -rn presync_floor` 0 命中
- 为什么删而不是留：`gfx`/`gmxc` 在本机 **consumer = 0**（设备 `pm_genpd_summary` 均为 `off-0 … 0`）
  ⇒ 该分支不可达；它也不修 Q24（兜的正是 `enable_corner`，见 q24 两份报告）
- 未进日常线载荷（行为等价：分支本就不执行）；下次构建可随 bunches 应用
