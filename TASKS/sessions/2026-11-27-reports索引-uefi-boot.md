# 报告索引回填：uefi-boot（2026-11-27 11:23 CST）

本文件作用：把手写报告挂进判据语料，按主题归集并说明用途。
生成时间：2026-11-27 11:23 CST。

## 指针

- **UEFI 镜像 A 首次上机（2026-10-24 晚）：header v3 不 handoff，v0 repack 才真跳；载荷死在 UEFI 早期，全程无可见性**：`reports/uefi-boot-A-attempt-20261024.md`
- **UEFI N2-v0b 上机：不交棒（与 E0 同，A2 对照仍为真交棒）—— 2026-10-30 14:16**：`reports/uefi-n2-v0b-onboard-20261030.md`
- **UEFI p49 → p50：R43 令牌确认已写进 UEFI 的 cmdline，但内核侧仍拿不到 ⇒ 交棒仍未成立**：`reports/uefi-p49-p50-cmdline-witness-20261107.md`
- **UEFI p51→p53：交棒成立（内核侧实锤），卡点是那个内核在 4–10 s 后整机硬复位**：`reports/uefi-p52-p53-handoff-confirmed-20261107.md`
- **UEFI p54→p57：三条「关硬件看门狗」的路全部证伪（+ 一条反证：复位不是独立定时器）**：`reports/uefi-p54-p57-wdog-negative-20261107.md`
- **UEFI p58：间接引导打通 —— 真因是 SdccDxe 抢初始化 SD 主控，不是看门狗**：`reports/uefi-p58-sdccdxe-handoff-success-20261107.md`
- **UEFI 可见性与 UFSDxe 代次差（lane E，2026-10-26）**：`reports/uefi-visibility-20261026.md`
- **UEFI 线收口（2026-10-29，lane H5）**：`reports/uefi-closeout-20261029.md`
- **外部发现扫描：SM8750(P)/Pakala UEFI 引导 Linux — 2026-11-03**：`reports/uefi-external-scan-20261103.md`
- **UEFI 补证恢复（M1/M3/M4 + E0/E1/E2 核对，2026-10-30）**：`reports/uefi-recovery-20261030.md`
