# aw86927 SRAM 窗口 → per-chip 数据表（U4，2026-10-27）

本地（**非上游**）重构草案。分析/上游化判定 = `reports/u4-aw86927-sramwindow-20261027.md`。

- 基树：`build/aw-chip`（7.3 线 scratch worktree @ `24223e44a`，与日常线载荷同源）
- 文件：`0001-input-aw86927-move-sram-window-to-per-chip-data.diff`（`git diff` 格式，1 文件 +39 −25）
- 应用：`cd build/aw-chip && git apply …/0001-*.diff`
- 门禁（已跑）：`make drivers/input/misc/aw86927.o` rc=0；`W=1` 重编 0 warning
- 状态：**未进日常线载荷、未上机**（行为等价：同样的 0x800/0x1000/0x2000 只是换了存放位置）
- 上游归属：只能作为「aw86927 固件波形系列」的**第 2 提交**（第 1 = binding、第 3 = 固件装载、第 4 = AW86937 差异、第 5 = 双控/suspend），
  单独投会被判「no user of this data」
