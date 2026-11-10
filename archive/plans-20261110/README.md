# 归档计划文件（2026-11-10 清理轮）

> 用户 2026-11-10 批准「可以清理」。本目录收的是**入口已被取代、结论已进 SSOT** 的计划文件；
> **不删**，只从活跃目录 `.pi/plans/` 移出，便于新会话不再照旧入口找错方向。
> 候选来源：`.pi/plans/2026-11-09-整理候选清单.md` §B + `reports/tidy-audit-20261110.md` §2。

## 为什么归档（一句话/条）

| 文件 | 理由 |
|---|---|
| `2026-11-04_handoff-uefi-bootlinux-crash.md`、`2026-11-04_handoff-uefi-dxe-to-linux.md`、`2026-11-04_late-uefi-routeD-linuxloader.md` | 11-04 的 handoff 链，入口已被 `TASKS §5` 的 11-07 p58 / 11-08 路线 B 块取代 |
| `2026-11-05-交接-下一轮会话.md`、`2026-11-06-交接-下一轮会话.md` | 同上的交接件，每次都被后一轮取代 |
| `2026-11-06_200000-uefi-p14-进度字符.md`、`2026-11-06_uefi-batch-next.md` | p14 世代判死；批次入口已被 `patches/uefi/README.md` §0 取代 |
| `2026-11-08-g1-29-menu-{r59,esp-p59}.md`、`2026-11-08-g1-29-route-b-espboot.md` | 菜单闭环与路线 B 打通均已定案（`TASKS §5`「2026-11-08（深夜）/（晚间）」块） |
| `2026-11-09-p61-onboard.md`、`2026-11-09-p62-onboard.md` | 两发均已执行、**负结果**；判据与回退已进 `reports/uefi-p61-flash-trial-20261109.md` 与 `reports/uefi-p63-p66-beacon-20261109.md` |
| `next/*`（除 `non-uefi-open-items.md`） | 11-04 的 lane 派工单，已收口（dwc3/wl2868c 各自有 `patches/upstream/` 目录 + `reports/mail-*`） |
| `next2/*` | 11-04 取证 lane 的中间材料，结论已进 `reports/uefi-posctrl-20261103-summary.md` 等 |

## 明确保留（**没动**）

- **`.pi/plans/next/non-uefi-open-items.md`** —— 仍被 `TASKS/README.md` 引用（非 UEFI 的开口清单）。
- `.pi/plans/2026-11-09-整理候选清单.md` —— 仍在活跃使用（清理账的候选源）。

## 引用已同步

移动时把这 12 个顶层文件的引用路径从 `.pi/plans/<名>` 改成了 `archive/plans-20261110/<名>`
（脚本 `scripts/grub-bootfiles.sh` + 15 个 `TASKS/` `DEVICE/` `reports/` 文档）。
