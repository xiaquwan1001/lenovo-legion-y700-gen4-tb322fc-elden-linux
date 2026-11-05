# 2026-10-27 · U3 判定（删 `presync_floor`）+ U7 缩小（-5）

- **日期**：2026-10-27
- **pi 会话 id**：`01a17be4-9a0f-71ca-96ab-2f5cecf4fcd3`
- **主题**：按顺序做 U3（`rpmhpd` `presync_floor` 框架级 workaround 的定性），顺带用设备只读证据缩小 U7。
- **结论（数字）**：
  1. **U3 = 本机死代码 ⇒ 删除（D13），不立项上游**：`presync_floor` 只挂在 `gfx`/`gmxc` 两个 rail 上，
     而设备 `pm_genpd_summary` 显示两者 **consumer = 0**（`gfx off-0 … 0`、`gmxc off-0 … 0`；对照 `mx on 256`/`cx on 256`/`mmcx on 64`），
     板级 DTS 与 `sm8750.dtsi` 也无 `VDD_GFX/GMXC` 消费者（GPU 走 GMU/AOP）⇒ `rpmhpd_aggregate_corner()` 的该分支**不可达**。
  2. 该方法在 **7.2 血统树里就存在**（`geekidos-linux @ba28ec16f0` 同 4 处）＝厂商血统，不是我方实验件；且两份 q24 报告已各自写明它**不修 Q24**（兜的正是 `enable_corner`）。
  3. **动作 = 删除**：`patches/local/rpmhpd-drop-presync-floor-20261027/`（**−8 行**），删后 `rpmhpd.c` 与 pristine 7.3-rc7 **逐字节相同**（`diff` rc=0）；
     门禁：`rpmhpd.o` 编译 rc=0、`W=1` **0 warning**、全树 `grep presync_floor` 0 命中。**未进日常线载荷**（行为等价）。
  4. **U7 缩小**：日常线两路 `aw86927` 控制器 `6-005a`/`6-005b` 均 probe 成功（`input4`/`input7` 均 `aw86927-haptics`），
     固件 `awinic/y700-gen4-haptic.bin`（5881 B）在机、dmesg 无 sram 失败 ⇒ **固件波形装载在双控上成立**；实振已由 C10（2026-10-24）人工确认（单路），
     剩余仅「左右分别实振」这一主观项。
  5. 台账：M1 §4 未决 **9 → 4 条**（累计关闭 U3/U4/U6/U8/U9；剩 U1/U2/U5 DSI bonded 一族 + U7 收缩项）。
- **证据指针**：`reports/u3-rpmhpd-presync-floor-20261027.md`（§1 设备证据、§3 若将来真需要时的正确上游形态）、
  `patches/local/rpmhpd-drop-presync-floor-20261027/{README.md,0001-*.diff}`、`reports/upstream-status-20261027.md` §0/§3。
- ★SSOT 待并入：无（已并入 §7 M1，2026-11-05）
- **未做**：U1/U2/U5（DSI bonded 重构：需 per-SoC cfg 设计 + 上机时序确认）；aw86927 5 提交系列实建；任何投递。
