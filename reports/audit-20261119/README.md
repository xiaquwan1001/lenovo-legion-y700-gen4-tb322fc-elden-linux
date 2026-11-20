# 2026-11-19 全仓审计（A1–A8）— 总入口

> 本轮 = 用户要求「多角度审计 + 精简资产 + 严格归档 + 收束分叉 + 设备回最优 Linux 模式」的一次性产出。
> **只读为主**：八个子代理一律禁止改仓（只有 A3 的 3 个删除候选、A4 的归档清单、A6 的清理批次是**清单**，不是已执行）。
> 实际执行的动作只有三项，全部在本文 §5 记账：① 删 `out/stage-*` 与 `__pycache__`（2.4 G 可再生产物）；② 生成 `reports/README.md` 索引；③ 设备侧 6 个 unit 落盘 mask + 回最优桌面（另见 PITFALLS #694）。
> 每份子报告开头都写了「审计代理 / 时间 / 只读」，结论均带指针；无法核实的都显式写「未取证」。

| 文件 | 内容 | 一句话结论 |
|---|---|---|
| `A1-phase-timeline.md` | 13 个阶段的突破/卡点/被推翻旧结论 + 「现在真正卡什么」表 + 已结项清单 | G1 36/37、G2 10/13、G3 登录界面 ✅；当前最大卡点 = 安卓 v3 未进桌面（设备窗口） |
| `A2-best-state.md` | 分子系统「历史最优状态」与「最强可复现组合」+ 设备现态 | （见该文件；A2 代理因宿主 SIGSEGV/超时风险晚交） |
| `A3-scripts-audit.tsv` / `A3-scripts-summary.md` | 344 个脚本逐条分类（docs 引用/scripts 引用/建议动作） | 332 KEEP / 9 KEEP-ARCHIVE / 3 删除候选 / 61 个 .pyc 脏数据；**无可合并的重复脚本**（仅 host-net-proxy `.sh`→`.service` 一处真替代） |
| `A4-docs-audit.tsv` / `A4-docs-audit.md` | 29 条文档问题（矛盾 4 / 死指针 8 / 旧结论 2 / 重复 3 / 体量 2 / 过期 2 / 孤儿 1）+ 三批执行顺序 + 归档目录设计 | 无未来日期；`reports/README.md` 索引已过期（本轮已重生成）；建议归档目录 `archive/2026-11-19-docs-audit-retired/` |
| `A5-forks.md` | 14 个分叉点的原因/目的/互斥性/可整合性 | 只有 3 个真物理互斥（GPT-minimal↔共存契约、slim v1/v2/v3、boot_a↔boot_b）；推荐 3 条主线 + 5 项主机侧立即合并 |
| `A6-assets-audit.tsv` / `A6-assets-summary.md` | 152 G 工作区逐目录判定 + 按风险排序的清理批次 | 可精简 ~55–65 G（不含用户拍板项）；`out/android-slim-v3-20261119` 41 G 是活跃实验材料**禁动** |
| `A7-hygiene.md` | 门禁 + PITFALLS/记忆/文档量化体检 | `check-doctor` FAIL=0 / WARN=7（1 可修+2 豁免+4 C 类）；PITFALLS 跳号 159；`.pi/memory` 332 条超 300 字 |
| `A8-device-state.md` | 设备只读现态详查 | （见该文件；设备在本轮中途经历掉电链，最终已回最优态，见 §4） |

---

## 1. 阶段突破与卡点（A1 摘要）

- **完整清单在 `A1-phase-timeline.md`**（13 阶段 × 突破/卡点/被推翻旧结论三列，全部带 `文件:行` 或 git 指针）。
- 三条最容易被误解的「突破」：① 11-19 显示修复 = **minbase 缺 `udev`**（不是 DP 组件问题，nodp DTB 实验件留档勿用）；② 安卓「3 发全败」里 2 发是 **BCB=`boot-recovery` 污染不算数**；③ 11-18 两次 RAM 启动失败 = **cmdline 根标签 `linux17` vs `linux`**，RAM 路径本身是好的。
- 当前 11 条阻塞按价值排序见 A1 §(b)；前三位 = 安卓 v3 取证（设备窗口）、锁屏需人手滑（缺 `CONFIG_INPUT_UINPUT`）、camss CSIPHY 等 Qualcomm v8。

## 2. 累计最优进度在哪里（A2 摘要 + 本轮实测补充）

**一句话：最优 Linux 态 = `boot_b` 持久件 + `linux17`（193 G，label `linux`）+ minbase→resize2fs 190 G + 49 包日用基线 + Phosh/Mesa 26.1.6 桌面。**

本轮 22:37 起在机实测（可作为「最优态」的现态判据）：

| 项 | 值 |
|---|---|
| 内核 | `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`（vk192 构建件；boot_b 持久槽） |
| cmdline 根 | `elden_root=LABEL=linux`、`androidboot.slot_suffix=_b` |
| 根文件系统 | `/dev/sda17` = `linux17` 193 G，已用 6.2 G（4%） |
| 桌面链 | greetd + phoc + phosh + phosh-osk-stub 四进程；`graphical.target` active；`deploy-desktop-shell.sh --check` = **MISS=0** |
| 图形 | `/dev/dri/card0` + `renderD128`，fb0 1904×3040；Mesa **26.1.6**（trixie-backports） |
| 网络 | `wlan0` = ustcnet 5.8 GHz，114.214.230.246/21，**默认路由经 wlan0**；`usb0` = 192.168.7.1/24 保留 SSH 通道 |
| 时间 | 时钟已正确（2026-11-19 22:5x，非镜像构建日） |
| 包 | dpkg 1256 行（≈1253 包） |
| 安卓面 | `super` 22 G、`userdata` 256.7 G、`metadata` 64 M **全部原样保留**；`boot_a` 未动 |

历史最优的**证据件与复现路径**（A2 逐件核实主机现存性）与「最强可复现组合」命令序列见 `A2-best-state.md`；本文不复制。

## 3. 脚本与文档：审计结论（A3/A4）

- 脚本侧**没有大块可砍**：344 项里 332 项被 SSOT 文档/`versions/*.tsv` 账目/门禁闭包引用；可动面只有 9 项证据型归档 + 3 个零引用 Java 测试源 + 61 个 `.pyc`。真正的「脚本膨胀」是**账目引用层**（`versions/*.tsv` 记 210 个 basename），动它会破坏 vk 版本账 ⇒ **不动**。
- 文档侧**问题集中在指针与重复**：8 条死指针（跨 6 文件）、4 条与 §0 矛盾、3 段重复、2 篇过期专题。所有合并/归档动作需同步改引用，按 A4 §3 的三批顺序执行；**本轮只做了零风险的索引重生成**。
- 归档目录沿用既有惯例 `archive/<日期>-<主题>-retired/`（现状无 `archive/README.md`，每个 retired 目录自带 README）。

## 4. 分叉点收束（A5 摘要）

- 14 个分叉点：在用/并行 8、已废/被取代 4（两轨分机、GPT-minimal、7.2-elden 下游树、day-1 rootfs）、纯备胎 1（redroid）、治理性 1（`archive/` vs `reports/` 双历史）。
- **真物理互斥只有 3 个**：GPT-minimal ↔ 共存契约（同 LBA 段，已定共存契约）；slim v1/v2/v3（同 `super`）；`boot_a` ↔ `boot_b`（同 active/retry）。
- 推荐收束 = **3 条主线**：L（Linux 日常栈）、A（共存契约 + v1 现役 / v3 候补 + KSU 支线）、U（上游化 7.4-rc3 基线）。
- 可**立即合并**（主机侧零风险）5 项：造根唯一链、DEVICE §1.7 补槽位归属/dpbo 用法表、过期快照归档、M1 行去死指针、v2 标「不出件」。需设备窗口 2 项（v3 首启取证、KSU 一发 + revert 演练）。

## 5. 本轮实际执行的改动（记账）

| 动作 | 量 | 判据 |
|---|---|---|
| 删 `out/stage-min-20261118`、`out/stage-modules-20261118`、`out/stage-debian` | 2.44 G | 三者均为构建 scratch（`rootfs-minbase-build.sh` 的默认 `STAGE` 可重生成）；删除前 `grep -rn` 确认无脚本硬依赖；`df /` 93%→92%，`out/` 90 G→88 G |
| 删 `scripts/__pycache__`、`scripts/doctor/__pycache__` | 0.9 M | 编译缓存，可再生 |
| 重生成 `reports/README.md` | 564 篇 / 147 组 | `scripts/reports-index.py` rc=0（原索引过期） |
| 设备：6 个 unit 落盘 mask（droid-juicer、plymouth×4、hexagonrpcd） | 6 个 symlink | `systemctl is-enabled` = masked；详见 PITFALLS **#694** 与 `PITFALLS/sessions/326-…md` |
| 设备：回最优 Linux 桌面 | — | 正常 reboot 后 45 s 到 SSH、`graphical.target` active、四进程、MISS=0、wlan0 带默认路由；Android 分区零改动（`lsblk PARTLABEL` 复核） |

**未执行（登记，等拍板）**：A6 批次 2/3（`out/` 内 ~34 G 归档与 ~20 G 中间物）、A7 的 PITFALLS 跳号重排、A4 批二/批三（文档合并与归档移动）、A3 的 9 项证据型脚本归档。

## 6. 下一步（按 A1 §(b) 价值序）

1. 安卓 v3 首启取证：**先清 BCB → 读回校验 → 才 reset**，然后 S2/S3/S4/S5（`INDEX.md` §0 首条「下轮纪律」）。
2. 内核开 `CONFIG_INPUT_UINPUT`（解锁「桌面内不能自动验证」）。
3. camss CSIPHY：等 Qualcomm CAMSS v8 落地再定形状；上机出流回归仍未做。
4. 归档执行：按 `A4-docs-audit.md` §3 批一 → 批二 → 批三；资产按 `A6-assets-summary.md` 批次 1 → 2 → 3（每批前先跑 A6 的前置校验命令）。
5. `hexagonrpcd` 保持 mask，直到取证通道（物理串口 / ramoops 窗口）建好；G1-34 传感器恢复按 PITFALLS #692 前置清单走。
