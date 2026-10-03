# 审核：vk34 之后未逐版验证的改动（2026-10-03）

> 任务背景（用户 2026-10-03）：*「从 10.2 开始到此刻，某些 sessions 的版本迭代从未上机验证，
> vk40 出现了一些以前从来没有的 bug。以最后一版有实机验证的项目为界，审核后续任务是否有风险和纰漏。」*
> 本文是审核的**第一遍**（静态取证，只读，未做任何修改/上机）。会话侧证据见 `SESSION-INDEX.md`。

---

## 0. 结论摘要（数字先行）

| 项 | 结论 |
|---|---|
| 最后有**明确实机确认**的版本 | **vk34**（2026-10-01 23:12；会话 `01a0f80f` 实测 `uname` = vk34 在跑）。INDEX 曾写「最后在机基线 vk39」但**无会话级确认** → 待你拍板 |
| vk34 之后的**内核源码增量** | 精确 **5 个文件 + 1 config**，全部落在 2026-10-02 10:48–12:12（见 §1） |
| 其中**从未单独上机**的 | **全部 5 个文件**（只作为 vk40 叠加体上过机，未逐版回归） |
| 结构性缺陷 | **4 条**（§2）——最重的是「所有 vk 共用同一 `uname`，无法分辨在跑哪版」 |
| 与「vk40 新 bug」的关系 | 熄屏→重启（G1-22/Q21）发生在 **vk40 + 10-03 持久化 initramfs**；音频等改动集中在 vk34 之后的音频/DTS 增量，**高度可疑** |

---

## 1. vk34 之后的内核增量（确定性取证：文件 mtime + `git diff`）

边界 = vk34 构建时刻 `2026-10-01 23:12`。`geekidos-linux` 工作树里 mtime 晚于此的改动：

| # | 文件 | 最后改动 | 规模 | 内容要点 | 关联补丁 | 单独上机验证 |
|---|---|---|---|---|---|---|
| 1 | `arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts` | 10-02 10:48 | 累计 +870 行 | 冷启 165Hz head、`splash_region`、`mdss_dp0` disabled、**分级热 trip（70/82/90/105 ℃）** 等 | 0010（及更早） | ❌ |
| 2 | `sound/soc/qcom/qdsp6/q6apm.c` | 10-02 11:10 | +23/−8 | 改用 `audioreach_alloc_apm_cmd_pkt`（APM 命令头）；**残留 `DBG graph_open`/`DBG q6apm_graph_open` 调试打印** | 0005/0009 相关 | ❌ |
| 3 | `sound/soc/qcom/qdsp6/q6prm.c` | 10-02 11:31 | +5/−1 | q6prm 改动（**`patches/0001–0011` 里根本没有它的 patch**） | 无 | ❌ |
| 4 | `sound/soc/qcom/qdsp6/audioreach.c` | 10-02 11:31 | +35/−1 | APM 命令头 / 图元处理 | 0009/0011 | ❌ |
| 5 | `sound/soc/qcom/qdsp6/q6apm-lpass-dais.c` | 10-02 12:00 | +39/−1 | MI2S BE graph 提前到 `prepare` 启动（ADSP 要求 sink 先于 source） | **0011** | ❌ |
| 6 | `.config` | 10-02 12:12 | — | `config-vk40-bringup`（= `config-vk38-camera`） | — | — |

**对照**：mtime 在 vk34 之前的 8 个文件（`mhi.c` 09-29、`dpu_hw_catalog.c`/`aw86927.c` 09-30、`btqca.c` 09-30、
`audioreach.h`/`sm8750.dtsi`/`dsi_host.c`/`panel-novatek-nt36536.c` 10-01 ≤22:57）**在 vk34 及更早版本中已上机**。
→ **「未验证增量」= §1 表 5 个音频/DTS 文件**，边界非常干净，可直接做回归定位。

构建时间线（`out/boot-elden-vk*.img`）与验证状态：

| vk | 构建 | 验证 |
|---|---|---|
| vk7–vk34 | 09-28 → 10-01 23:12 | ✅ 多轮会话实机（vk34 有明确「在跑」） |
| vk35 | 10-02 01:40 | ⚠️ 只有 ssh 读数，无明确 vk35 确认 |
| vk36–vk39 | 10-02 10:48 → 12:01 | ⚠️ 无会话级确认（INDEX 声称 vk39，待核） |
| vk40 / vk40-ram | 10-02 19:43 / 20:02 | ✅ 10-03 上机（U2 持久 Phosh），**但曝熄屏即重启** |

---

## 2. 结构性缺陷（比单条改动更值得修）

| ID | 缺陷 | 影响 | 证据 | 建议 |
|---|---|---|---|---|
| **F1** | **所有 vk 共用同一 `uname -r`** = `7.2.0-debug-gba28ec16f01f-dirty`（`CONFIG_LOCALVERSION` 未随版本改） | 设备上**无法从内核自报分辨在跑哪版**；日志/回归无法归因；「稳固取得进步」的根障碍之一 | `SESSION-INDEX.md` §3；各会话 grep 全同 | 每版注入唯一 localversion（如 `-vk40`），并在刷机脚本里校验读回 |
| **F2** | **`patches/0001–0011` 不能忠实重建工作树** | 重放/回滚得到的内核与真机不一致，是回归定位的陷阱 | 5 文件与 patch 后像不符、`q6prm.c` 无 patch | 已导出权威全量 patch `patches/elden-working-tree-ba28ec16f-2026-10-03.patch`（反向 apply 校验通过）；**今后每版一 commit + format-patch** |
| **F3** | **残留调试打印** `DBG graph_open` / `DBG q6apm_graph_open`（`q6apm.c`） | 噪声、可能影响时序判断；说明改动未收口就上机 | §1 表 #2 | 清理后再作为正式基线；调试打印只在 debug 版 |
| **F4** | **无 per-version git 提交** | 不能在 vk34 与 vk40 之间 `git bisect` 找回归点 | `geekidos-linux` 仅 1 个上游 HEAD、13 文件 dirty | 立即：把当前树 commit 到一个 `elden/` 分支，此后每版一 commit |

---

## 3. 后续任务（TASKS）逐条复核：声称完成 vs 实际验证

| 任务 | TASKS 状态 | 审核意见 | 风险 |
|---|---|---|---|
| **G1-1** vk40 持久直启 | ✅ 已完成 | 仅「能起到 Phosh」；**驱动健全（G1 定义）未达成** | 🔴 与 G1-22 冲突，不应标「基线验收通过」 |
| **G1-22** 熄屏/睡眠 | 🔴 未解 | 实测 `idle-delay=10` 必重启，无 panic；`ucsi_glink PPM init failed` | 🔴 阻塞日常 |
| G1-4 音频听声 | 🟡 | `GRAPH_START status=0` 仅控制面；**vk34 之后的音频 5 文件改动全部未验证** | 🟠 Q8 |
| G1-5 相机出流 | 🟡 | graph ENABLED ≠ 出帧；`config-vk38-camera` 未显式回归 | 🟠 Q9 |
| G1-7/8/9/10/11 | 🟡/⬜ | 未上机；基准脚本未跑 | 🟡 |
| C1 Waydroid vk40 复跑 | ⬜ | 依赖一个「带新 bug 的 vk40」 | 🟠 先稳内核 |
| C3 身份/DRM | 🟡 社区侧 | 实测需设备+上行 | 🟡 |
| C4 传感器 HAL | 🟡 宿主侧就绪 | 未上机；Q14 三未知 | 🟡 |
| 10-02 `env-pass` 过环境 | ✅ PoC | 刷第三方 SUSFS `boot_a` 被 ABL 拒后回刷原厂；**a 槽侧改动不算 G1** | 🟡 与 mainline 无关 |
| 10-03 U2 GPT 手术 / 持久化 | ✅ | 写后 CRC 校验 OK；但 a 槽 `/data` 与 GPT 不匹配、持久 initramfs 引入新行为 | 🟠 |

---

## 4. 建议的验证与修复顺序（待你确认）

1. **确认边界**：vk34 还是 vk39？（我需要你确认「10-01 之后是否有任何一次 mainline 上机是你亲眼确认的」）
2. **固化当前树**：`geekidos-linux` 建 `elden/` 分支提交现状 → 后续每版一 commit + 唯一 localversion（修 F1/F4）。
3. **增量二分**：以 vk34 状态为基线，**只**把 §1 的 5 文件改动分批加回（先音频 4 文件、后 DTS/thermal），逐批上机验证；
   或先从当前树**反向移除**音频 4 文件改动，看 vk40 的熄屏/音频症状是否消失 → 直接定位回归源。
4. **修 F3**：清掉 `q6apm.c` 的 `DBG` 打印，再作为正式基线。
5. **熄屏 bug（G1-22）**：与 §1 增量是否有因果关系需实验隔离（`idle-delay=0` 先规避）。

> 纪律提醒：任何变更上机前先 `fastboot fetch` + GPT 双表 dump；在不可回滚的持久系统上不做熄屏/电源类实验
> （`GAPS` 风险登记 / `archive/topics/复盘-2026-10-03-持久化与睡眠.md`）。
