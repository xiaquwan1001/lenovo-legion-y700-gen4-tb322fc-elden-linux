# 上游化当前一页（2026-11-13）

> 取代 `archive/topics/upstream/upstream-status-20261105.md`（11-05 快照，留作沿革）。
> 只写「逐系列状态 / 我方欠什么 / 复启条件」；每条论断的证据指针在行内。
> 外部动向快照 = `reports/upstream-watch-20261113.md`（patchwork REST 取证 29 条）。

## 1. 本窗口已投（2026-11-11 → 11-14）

| 系列 | 版本 | 封数 | 结果 | 证据 |
|---|---|---|---|---|
| `regulator: willsemi,wl2868c` | **v11** | 3 | 3×250，lore 归档逐字节通过 | `patches/upstream/wl2868c-v11-20261113/`；回 Mark 的 LDOx_SEQ 问题（datasheet Rev1.4 p.35 + 板上读数 `0x0a..0x0d=00`） |
| `drm/msm/mdss` 块复位 | **v4 → v5** | 4 + 4 | v4 4×250（11-13）；**v5 4×250（2026-11-14）** | v4 = `patches/upstream/m8-mdss-v4-20261113/`（只重写 3/3 message，带 Abel+Dmitry R-b）；**v5 = `patches/upstream/m8-mdss-v5-20261114/`**（答 sashiko 的「0xa000 是未 attach 的独立域」Medium：1/3、2/3 未变，3/3 diff 逐字节相同、只收窄 message，三个 R-b 含 Konrad；全账 `reports/mail-send-20261114-mdss-v5.md`） |
| `drm/msm/dsi/phy` PLL_SYSTEM_MUXES | v1 | 1 | 11-11 已投 | Dmitry 要求把解释性注释搬进 commit message ⇒ 待 v2 |
| `arm64: dts: sm8750 ADSP fastrpc non-secure` | v3 | 1 | 11-11 已投 | 等 Konrad 拉的四位定性；`accel/qda` v4 与 `nsessions` 废弃在动 |
| UEFI `mu_wide_platforms#12` | — | 1 评论 | 11-13 闭环已发（comment 6847932534） | UFS 枚举通、两形态都通、flashed 真阻塞 = `dtbo_a` |

## 2. 逐系列状态与「我方欠什么」

| 系列 | 状态 | 我方欠 |
|---|---|---|
| **wl2868c**（M4） | v11 等 Mark 复审；binding 侧 Rob 已 R-b | 若被要求「非零 SEQ 时隐藏 ops」的替代方案，需给出为何不选（cover 已答）；否则等 |
| **mdss**（M8） | **v5 已发（11-14）**：sashiko 的「0xa000 是 dispcc 单独描述的域、mdss 没 attach」质疑成立 ⇒ 保留 3/3、只收窄 message（不再称 interrupt controller / same block）+ 声明两条测量边界（15/15 是三枚形状、0xa000 未做单变量）；3 R-b 全保留 | 等回复；若被判不可接受则发 v6 删 3/3（并发回 1/3 应有的 Rob Acked-by）。**仍未证**：两枚形状的上机验证、0xa000 单变量（`reports/mdss-int2-evidence-20261113.md` §2.3） |
| **dsi/phy** | v1 收到 Dmitry 一条（注释位置） | **v2：注释搬进 commit message**，代码只留 `writel(0xc0, …)` + 一行理由 |
| **haptics aw86937** | v1；bindings 有 Krzysztof Acked-by；同串其余只收 bot 意见 | **v2 顺手采纳** `GENMASK(6,5)` 与 `devm_add_action_or_reset` 两点 |
| **counter/dispcc reset RFC** | 两轮追问无维护者回信 | 按自己承诺：v2 挪到 display 侧、`reset_control_*`、补 simple-framebuffer 在场对照；否则撤 |
| **相机 camss** | **改接 Qualcomm v6**（7 补丁，2026-07-21）；自建 9 补丁串停止后续版本 | 拿 7.4-rc2+ 树比对 `csiphy_res_kaanapali` 与本机 vendor 2.4.0 表；SOF 等 Bryan 的 `V4L2_EVENT_FRAME_SYNC`；板级 dts 等 v6 合入后 rebase。详见 `reports/camss-v6-rebase-plan-20261113.md` |
| **dwc3 双 connector** | Rob 11-10 结构性反对（ports 留给独立数据流、endpoint 留给 mux 后数据流；删 `port@2`） | 方案先行：binding + DTS + driver 三件同时改，工作量最大，未排期 |
| **ath12k WCN7861 / hci_qca** | 上游 0 命中（只有 WCN7850） | 无敌对信息，维持自维护 |
| **gie-v3-its 认领继承 LPI 表**（M9） | 已投并归档 | 无 |
| **fastrpc** | 等 Konrad 线程定性 | 准备「为什么不能简单写 non-secure」的寄存器/固件证据；跟踪 `accel/qda` v4 与 `deprecate qcom,nsessions` |
| **Gunyah** | 主线仍 0 进展（停在 2023-03 v11） | 拓展项维持「无上游可依赖」 |

## 3. 复启/纪律

- **投递按系列逐次批准**；本轮两批（wl2868c v11、mdss v4）由用户「按推荐顺序执行」放行。
- 代写回信/cover 的三件前提不变（披露 AI / 每条论断有可复现证据 / 逐条回应）——见 `AGENTS.md`「上游发信」。
- **无对照表不发提问**：11-13 相机 CSIPHY 版本分歧就属于「先对账再发信」的例子（`reports/camss-v6-rebase-plan-20261113.md` §2）。
- lore 抓取：`scripts/lore-fetch-raw.py`（过 Anubis）；patchwork REST 用于评论与状态。
