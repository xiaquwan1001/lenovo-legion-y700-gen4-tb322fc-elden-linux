# 上游化状态（2026-10-26）—— M 系列一页 + 门禁 + 备料

> 角色：upstream-m（冻结期只读备料，未发任何邮件/未改订阅/未投递）。
> Review 事实源：`reports/mail-triage-20261026.md`（窗口 10-23 00:00Z → 10-26 05:36Z，INBOX+Junk+Sent 全扫去重）。
> 机械门命令与原始输出见 §6；lore 直查被 Anubis 反爬拦截（403/挑战页），回复事实以**订阅 INBOX 收流**为准（我们订阅了 linux-arm-msm/linux-clk/linux-pm/linux-usb 等，列表信必达 INBOX）。

## §0 一页状态表

| 系列 | 最新外部消息 / 日期 (UTC) | 状态 | 阻塞 | 下一动作 | 门禁 |
|---|---|---|---|---|---|
| **M3-1**（USB 双连接器 v3） | Krzysztof Kozlowski 2026-10-23T07:49Z `<20261023-conscious-newt-of-experience-2dddf2@quoll>`：v3 以「RFC threaded 在 v2」形态发 ⇒ **已从 DT patchwork 摘掉** | 🟡 需 v4 | 待定调（正式 vs RFC） | **投正式 `[PATCH v4]`**：正文逐条写 v2→v3 对 sashiko 意见的处置（mail-triage §3 A3） | ✅ 0E/0W/0C ×2；dt-doc-validate ×2 rc=0；dwc3+roles 编译 0W |
| **M2 A2**（battmgr power_now） | Konrad Dybcio 2026-10-23T13:57Z `<84483ae1-…@oss.qualcomm.com>`：给 `github.com/lenovo-basements/android_kernel_lenovo_sm8750`，暗示自查 | 🟡 球在我方 | A2 核对未做 | 只读核对该 repo：① 是否 == 本地 GPL drop；② 是否含 `drivers/power/supply`（若含，"无厂商通道"论据需更正）。另：Konrad 要求**后续开发基线换 linux-next/master**（A1） | ✅ 0E/0W/0C；qcom_battmgr.o 0W |
| **M2 A1**（DPU GC） | — | ✅ 已撤稿（与上游 `3389406e6a03` 重复） | 无 | 无 | ✅ 0E/0W/0C |
| **M6 B5**（DSI per-SoC cfg，Q28） | 无上游线程（P4 尚未投） | 🟡 ≈35%：P1 样例已提交；**本轮 P4 草案已备** | 需上机对照（H39/H40 使能时机改动会移动 Q28 坏发率） | P1 补全 → 上机 P4 对照 → 修 H39/H40 语义 | P4：apply rc=0、编译 0E/0W、checkpatch 0E/1W/8C |
| **M8**（dispcc MDSS 复位 RFC） | Taniya Das 2026-10-22T17:23Z 反对（复位归属）；我方 10-23 已回（接受搬 `msm_mdss_reset()`）。Pengyu Luo 2026-10-25T16:56Z：`dsiclk_sel=0` 定案 + **sm8750-lenovo-elden DTS 归口移交我方** | 🟡 等 maintainer；显示块风向有利（Kaanapali INT2 GDSC v4 获 Konrad R-b） | 等回复（不催） | ① Q28 报告关闭 `dsiclk_sel` 变量；② DT squash 发布立项（display/remoteproc/misc 三串，Cc Pengyu） | ✅ 0E/0W/0C；dispcc-sm8750.o 0W |
| **M9**（ITS/LPI kexec claim） | **Marc Zyngier 否掉方案**（mail-triage §3 A4）：① nothing works at all；② EFI/DT 不互斥；③ 正解 = EFI 或 bootloader 配表 + DT memreserve | 🔴 方案不可挽救 | 方案重做 = 周级 | 二选一：撤回，或改「引导器预置 + DT memreserve」（与 UEFI 线 B2 耦合）；**先回信澄清，方案不做** | ✅ 0E/0W/0C；irq-gic-v3-its.o 0W |
| **M1**（PLL_SYSTEM_MUXES 1 行） | — | ✅ 已备 | 无 | 随 M 系列统一投递 | ⚠ 0E/1W（unknown commit id `44784327815b`，树血统性提示，非补丁问题）/0C |
| **M5**（dm-default-key / dm-inlinecrypt） | — | 🟡 立项完成（2026-10-13） | — | 确认 `dm-inlinecrypt` 覆盖面 + 补封存说明（本轮未发现新上游动态） | N/A（无补丁改动） |

## §1 M3 — 板支持系列

- M3-1：唯一已批准投递系列（v3 在途）。Krzysztof 的唯一不满是**投稿形态**（RFC/v2 threading），不是技术内容 ⇒ v4 走正式 patch + 逐条处置说明，1 h 内可完成。
- M3-3（音频 aw88461）/ M3-4（panel）/ M3-6（WCN pwrseq）：封存备料中，无新上游事件。

## §2 M6 — B5-P4 备料（本轮产出）

- 产物：`patches/upstream/m6-b5-p4-20261026/`（补丁 + README，逐 hunk 目的/硬件事实 vs 策略/落点/上游可接受性）。
- 落点判定：`CMD_DMA_CTRL1`/`DMA_SCHEDULE_CTRL*` XML = 硬件事实（方向正确）；坏发即放弃、200 ms/500×10 µs 超时、`ERR_INT_MASK0` 魔数、调度行算式 = **软件策略/Q3 风险**，全部在 commit 正文 DRAFT 声明。
- **H39/H40/H42（video 使能时机 pre_enable→atomic_enable）是 P4 里最可能移动 Q28 坏发率的改动**（b5 报告 §3.2），上机对照必须与 P4 绑定。

## §3 M8 — dispcc RFC

- 已发送并归档（`20261022140811.469417-1…`）。窗口内新事件：Pengyu 确认 `dsiclk_sel=0` 正确（我们本机现状即如此，变量关闭）；DTS 归口移交。检索范围：linux-arm-msm/linux-clk INBOX 全量 TEXT 检索 + Sent 对照（10-23→10-26 窗口），Konrad/Dmitry/Bjorn/clk maintainer 对本线程**0 新回复**。

## §4 M9 — gic-its claim

- 已投递并归档（`20261024075856.835932-1…`）。**Marc Zyngier 已否**（三点见状态表）；检索范围同上（`kexec` 关键词 6 命中，仅我方+Marc）。撤回/重做决策待用户拍板，本轮只记录。

## §5 M5 / M2

- M5：本轮未发现 `dm-default-key`/`dm-inlinecrypt` 相关上游新动态；封存说明补全仍按 2026-10-13 立项口径。
- M2 A2：最后一条 = Konrad 13:57:29Z（GitHub 链接）⇒ 轮到我方；最小动作 = 只读核对 repo（0.5 h，零设备）。

## §6 可复用门禁命令（原始输出要点）

> **坑**：checkpatch 必须在**内核树内**跑（CWD=仓根时宿主 `.git` 干扰 diff 解析，会把补丁误判为嵌套 diff 假报 trailing whitespace）。且用目标树自带 checkpatch（geekidos-linux 的版本过旧）。

```sh
# 1 风格（0E/0W/0C）
cd build/<tree> && perl scripts/checkpatch.pl --strict --no-tree <abs>/patches/upstream/<series>/*.patch
# 2 binding（M3-1）
dt-doc-validate Documentation/devicetree/bindings/usb/snps,dwc3{,-common}.yaml   # rc=0 ×2（build/m3v2-7.3rc7）
# 3 目标编译（全部 rc=0、0 warning）
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- drivers/gpu/drm/msm/dsi/ drivers/power/supply/qcom_battmgr.o   # build/m1-73
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- drivers/clk/qcom/dispcc-sm8750.o                               # build/q28-disp-73
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- drivers/usb/dwc3/ drivers/usb/roles/                            # build/m3v2-7.3rc7
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- drivers/irqchip/                                                # build/vk151
```

汇总：**checkpatch 8 枚补丁 = 7×(0E/0W/0C) + 1×(0E/1W/0C)**；dt-doc-validate 2×rc=0；5 组目标编译全 rc=0/0 warning；P4 草案 apply rc=0 + 编译 0E/0W。

## §7 解冻后建议投递顺序（dry-run，收件人）

| 序 | 系列 | To / Cc | 备注 |
|---|---|---|---|
| 1 | M3-1 v4（正式） | To linux-usb + linux-devicetree；Cc Greg KH、Krzysztof、sashiko | 形态改 patch，正文处置 sashiko 意见 |
| 2 | M2 A2 v2 | To linux-pm；Cc Konrad（**剔除已离职的 Ulf Hansson**，mail-triage §3 观察项） | 先完成 repo 只读核对 |
| 3 | M1 1 行 | To linux-arm-msm / dri-devel；Cc Dmitry、Konrad、Abhinav | 最小风险先走 |
| 4 | M6 B5 P0→P1→P2→P3→P4 | To linux-arm-msm / dri-devel | P4 带 RFC 说明（Q28 根因未定） |
| 5 | M8 v2（dispcc→msm_mdss_reset 搬迁版） | To linux-arm-msm；Cc linux-clk、Dmitry、Konrad | 需先吸收 Taniya 反对意见 |
| 6 | M9 视决策 | — | 撤回或重做后另行立项 |

> 全部投递需用户解冻 + 逐系列批准；dry-run 用 `git send-email --dry-run --confirm=never`（不执行）。
