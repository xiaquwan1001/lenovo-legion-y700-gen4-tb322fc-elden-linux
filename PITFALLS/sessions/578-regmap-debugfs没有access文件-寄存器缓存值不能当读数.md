# #739 · `regmap` debugfs **没有 `access` 文件**时，用户态读不到 PMIC 任意寄存器；`registers` 是**缓存值**（含默认值），不能当新鲜读数

- 日期：2026-11-27（无人值守轮，只读；起因 = 想在设备上直接读 PMIC PON 复位原因寄存器）
- 事实：
  1. `/sys/kernel/debug/regmap/0-00/`（USID 0 = 主 PMIC `pm8550`/`pmk8350-pon`）只有 `name` / `range` / `registers` 三个文件，
     **没有 `access`**。`access`（可按地址读/写单寄存器）只在 **`CONFIG_REGMAP_ALLOW_WRITE_DEBUGFS=y`** 时创建；本机未开该符号。
  2. `registers` 只打印 regmap **缓存**（未读过的显示 `XX`）。别用「全非 XX」推断「读到了」：
     本机 PON 段 `0x1300–0x13ff` 256 条全非 `XX`，但出现 `0x130a = 0x130b = 0xc4`、`0x1311..0x1316` 多为 `0xc0` 这类
     明显是默认/残留的值 ⇒ 不能当寄存器真值。
  3. PON 段可用的真实新鲜信息只有驱动自己读过的那些（例如 `0x1305 = 0x09` = `PON_GEN3_HLOS`、`0x1310` = RT_STS）。
- 判据（照抄可用）：
  - 想从用户态读 PMIC/SPMI 寄存器：先 `ls /sys/kernel/debug/regmap/<usid>-<sid>/` 看有没有 `access`；没有就是没路。
    **不要**为了取证去开 `CONFIG_REGMAP_ALLOW_WRITE_DEBUGFS`（等于给用户态任意写 PMIC 的能力）。
  - 需要寄存器真值时：走驱动（临时 `dev_info` 打印后 RAM 起核）或专用 debugfs，而不是 `registers` 缓存表。
- 关联：`#738`（ABL logfs 只留最近一次启动）、`reports/pmic-pon-reset-reason-20261127.md`（本条的完整上下文与结论）。
