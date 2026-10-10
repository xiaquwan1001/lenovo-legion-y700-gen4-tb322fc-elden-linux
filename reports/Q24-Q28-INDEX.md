# Q24 + Q28 会话与进度合并台账（2026-10-10 整理）

> 覆盖两条当前唯一未解主线问题的**本地会话 + 进度 + 产物**索引。
> **状态/结论 SSOT**：`TASKS.md` §5（Q24 / Q28）与 `INDEX.md` §3；本文件只做「谁在哪个会话、产出了什么、现在到哪」的导航，**不复述状态**。
> 相关文档地图：`reports/q28-INDEX.md`（Q28 各过程稿的收编/SSOT 判定）。

---

## 0. 两条问题的一句话口径

| 项 | 现象 | 当前口径 | SSOT |
|---|---|---|---|
| **Q28** | 开机间歇「只有背光无桌面」 | 根因 L1=bonded 双 DSI 首条 DCS `ff 20` 的**命令 DMA 引擎 hang**（冷起 ~60%）；冷起失效两模式 **NOCARD**（无 card0，0.86s DSI PLL 未锁）/ **STORM**（有 card0 的 cmd-DMA 风暴） | `reports/q28-DOSSIER.md`、`TASKS.md` §5 Q28 |
| **Q24** | 相机模块在位时「熄屏→整机硬复位/掉电」 | 触发=单模块 `cambistmclkcc-sm8750` × DT 电源域；**用户裁决=互斥二选一**：日常零相机模块，需要时 `cam-mode.sh on/off`；根治（DT/驱动变体）未成 | `TASKS.md` G1-22/G1-33、§5 Q24 |

---

## 1. 会话台账（父会话 + 关键 lane；ID = RESOURCES §4 口径）

### Q28 主线会话
| 日期 | 父会话 | 关键 lane（子代理任务） | 产出/结论 |
|---|---|---|---|
| 10-08 | `01a11a70` | — | 「修相机/熄屏电源/桌面」三角接管；Q28 首观测 |
| 10-08 | `01a1167d` | — | 稳定基线盘点（`sleep-sweep.sh` 线索） |
| 10-09 | `01a11e06` | — | 仅 SSH 探测平板侧状态（可达性） |
| 10-09 | `01a11f5d` | `22498504` DPU power-on 竞态根因+鲁棒化草案；`67cb8347` 面板诊断内核；`3584b986` 构建；`f5d40343` Q28b 断电态链路；`b5547fef` 测试/部署包 | `research-q28-dpu-powerup-race`、`2026-10-09-Q28b-断电态证据` |
| 10-09 | `01a12093` | （编排，非 Q28 专属） | 多线派发 |
| 10-09 | `01a12302` | `29f2dd72` Q28 深研；`fefe46b7` E0 诊断；`36a5cf53` 实验顺序 | `2026-10-10-Q28-深研`、vk74/75 寄存器差分 |
| 10-10 | `01a1241b` | `17a41f85`/`6f8b8937`/`f2b172ba` 上游调研；`853c3d7c` 单变量构建；`9bb694f9`/`9f55f31e` cmd-DMA；`a1895cbe` DOSSIER 合订；`cab8f9ae` 好发取证；`bf9c7e84` 清理审计 | `reports/q28-DOSSIER.md`（SSOT）、vk84、vk86、`q28-*` 脚本与报告 |
| 10-10 | `01a12542`/`01a1259d` | — | 进度盘点/本轮审计 |

### Q24 主线会话
| 日期 | 父会话 | 关键 lane | 产出/结论 |
|---|---|---|---|
| 10-03 | `01a1021c` | — | vk34 后「奇怪重启」最早线索（后被 Q24 根因取代） |
| 10-04 | `01a104e2` | — | 以 vk47 为基线做 TF卡+相机驱动 |
| 10-06 | `01a10f5e` | — | 复查疑似问题版本 |
| 10-07 | `01a115a8` | — | **Q24 根因实锤**（相机模块链，dp5/6/7 控制变量 A/B）；DP 打通 |
| 10-07 | `01a11702` | — | 「相机 × 熄屏矛盾」专项 |
| 10-08 | `01a11a70`/`01a11bee` | — | 相机/熄屏/桌面三角；待测问题整理 |
| 10-09 | `01a12302` | `150068b7` Q24 深研；`3379c860` E4a DT；`7e70c97f` FIX-3 驱动；`a7f6ed45` E4a 上机扫测 | `2026-10-10-Q24-深研`、`2026-10-10-E4a-FIX1-DT` |
| 10-09 | `01a12140` | `9f0d0540`/`c6451b9b` 相机模块收尾 | 「camera not found」真因=cmdline `elden_nocamera=1`（配置态非驱动坏） |
| 10-09 | `01a120fe`/`01a11fe1` | — | 接手待办、多线编排 |
| 10-10 | `01a1241b` | — | **E4a/FIX2/FIX3 死内核作废**（`PITFALLS #162`）；vk79–83 资产入账 |

> 完整会话行（含实机/状态/风险列）= `RESOURCES.md` §4（`01a115a8`/`01a11702`/`01a12302`/`01a1241b` 等已收录）。

---

## 2. 进度时间线（选摘，权威以 TASKS 为准）

**Q28**
- 10-08 首测：累计 11 boot 7 失败（~64%），`DSI DCS -110`；与烧录路径/dtbo 无关。
- 10-09 收窄：否掉 runtime-PM 吞错（vk74 4/4 复现）+ DPU 断电态；拿到好发基线（vk75）；出 vk76-freezetrace（#106 GUI 死挂取弹）。
- 10-09 深夜：判据更正（`dsi_isr` 增量不可判死活→累计值+dmesg）；定义 NOCARD/STORM 前身。
- 10-10 定案：L1=cmd-DMA hang，L2=下游；**NOCARD/STORM 双模式**；`PITFALLS #164/#165`；死内核事故修复（#162）。
- 10-10 深夜：**真实日常失败=STORM**（C1real POR + C2 冷 fastboot 2/2）；`reboot2` 暖复位粘 NOCARD（#166）；vk86 STORM 台架对入库。
- **下一步（唯一门）**：同一镜像（vk86-round2）冷起 2 次（隔真实 POR），判定「同二进制非确定性 ⇒ 停 Q28 转 Q24」还是「`/init` 时序敏感 ⇒ 继续」。

**Q24**
- 10-07 根因：单模块 `cambistmclkcc-sm8750` 单独加载即触发；H1（去 power-domains）7/9、D1/D2 无效。
- 10-08 H2（单挂 MX）重开未根治；上游报告已发（be79b256d）。
- 10-09 用户裁决：**相机 ⇄ 熄屏互斥**，日常零相机模块；`cam-mode.sh` 上机。
- 10-10 E4a/FIX-2/FIX-3 三路**作废**（在无 QCOM 死内核上测，`#162`）⇒ 需恢复好档重做。

---

## 3. 产物清单（按类）

**报告（reports/，活跃工作区，未入库）**：`q28-DOSSIER.md`(SSOT)、`q28-INDEX.md`、`q28-two-layers-20261010.md`、`q28-upstream-diff-20261010.md`、`q28-upstream-research-20261010.md`、`q28-nocard-research-20261010.md`、`q28-orchestration-20261010.md`、`q28-handoff-20261010.md`、`local-cleanup-audit-20261010.md`

**计划（.pi/plans/）**：`research-q24-cambist-2026-10-09.md`、`research-q28-panel-init-2026-10-09.md`、`research-q28-dpu-powerup-race-2026-10-09.md`、`2026-10-09-Q24-mxnom-sweep-runbook.md`、`2026-10-09-Q24-变体与G1-34资产.md`、`2026-10-09-Q28-密集复现与vk74.md`、`2026-10-09-Q28-证据与方案.md`、`2026-10-09-Q28-诊断上机包.md`、`2026-10-09-Q28b-断电态证据.md`、`2026-10-09-深夜-Q28寄存器差分-模块化在机验证-槽位险情.md`、`2026-10-10-Q24-深研.md`、`2026-10-10-Q28-深研.md`、`2026-10-10-E4a-FIX1-DT.md`

**脚本（scripts/）**：
- Q28：`q28-devprobe.sh`（三态判据）、`q28-boot-cycle.sh`（已补 card0 硬门）、`q28-ab-delay.sh`、`q28-race-hunt.sh`、`q28-verdict.sh`、`q28diag-forensic.sh`
- Q24：`sleep-sweep.sh`、`sleep-bisect.sh`、`sleep-cumulative.sh`、`cam-mode.sh`、`camera-modules-load.sh`、`keep-awake.sh`

**补丁（patches/）**：`q28-dsi-regdump{,-with-baseline}.patch`、`q28-poweron-propagate.patch`、`q28-cmd-dma-delay.patch`、`q28-dsi-cmd-recover.patch`、`q28-methodB-round-byteclk.patch`(+`q28-methodB-NOTES.md`)、`q28-round-vk86.patch`
（Q24 侧为内核提交：E4a `97b8ee3c7`/`68e8ab2c0`、FIX-2 `86193a58a`、FIX-3 `e1d2c658a`、上游 `be79b256d`）

**镜像/构建（out/，逐镜像身份见 `versions/vk-kernel-identity.tsv`）**：
- Q28：`vk64`（在机 boot_b）、`vk72*`/`vk73-q28diag`/`vk74-q28power`/`vk75-q28ab`（诊断，部分已删）、`vk76-freezetrace`、`vk84-q28delay-{base,exp}`、`vk86-{base,round,round2}`、`vk85`（计划未建）
- Q24：`vk62`(H1)、`vk63`(H2)、`vk71-{mxc,mxnom}`、`vk79-E0`、`vk80-e4amxc`、`vk81`(E4a,死)/`vk82`(FIX-3,死)/`vk83`(FIX-2,死)

---

## 4. 边界与提醒

- 判 Q28 显示**必须** `q28-devprobe.sh` 三态 + SSH 读全 dmesg + 查 `card0`；串口 logger 重连漏 0–20s，只数风暴签名会把 NOCARD 误判 GOOD（`PITFALLS #165/#167`）。
- Q28 每个样本之间**必须真实 POR 断电**；`reboot2` 暖复位结果全是粘态伪影（`PITFALLS #166`）。
- Q24 日常态保持零相机模块；`cam-mode.sh on` 前先禁熄屏（`keep-awake.sh`）。
- 死内核红线：`ARCH_QCOM` 编后必须 `grep` 符号校验（`PITFALLS #162`；`build-kernel.sh` 已守卫）。
