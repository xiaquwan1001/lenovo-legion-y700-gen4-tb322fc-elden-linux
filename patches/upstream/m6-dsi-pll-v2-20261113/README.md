# dsi/phy PLL_SYSTEM_MUXES v2（B4 / A3 备料）— 2026-11-13

> 状态：**v2 草案就绪，未发送**；同时给出对 `reports/upstream-74-replay-20261113.md` §3
> 「上游已覆盖 ⇒ 建议 retire」这一判定的**复核结论：不成立**（依据见 §1，逐条 file:line）。
> 基线：`gh/master` = `9d66f26fef`（7.4-rc3 线）。门禁在 `/tmp/g74` 做，仓库内不留工作树。
> 零发信、零设备动作。

## 0. 结论（先给数字）

1. **复核不成立**：上游 `dsi_pll_enable_pll_bias()` 的 `writel(0xc0, …)` **在首次 bring-up 时根本到不了**——
   它前面有 `if (pll->pll_enable_cnt++) { … return; }`，而 `dsi_7nm_phy_enable()` 在**更早**就把
   `pll_enable_cnt` 直接赋成 1。⇒ 7.4-rc3 上 `PLL_SYSTEM_MUXES` 仍停在 0x0，我们那 9 行**不是语义重复**。
2. 因此 **A3 不应改成「撤回」，应按 Dmitry 的要求出 v2**：注释搬进 commit message，代码只留
   `writel(0xc0, …)` + 一行理由（本次已做，9 行 → 2 行）。
3. 风险提示（回信里要主动说）：这段 early-return + pre-seed 正是 Dmitry 2026-07-12 的
   revert `44784327815b` 带回来的，其 commit message 明说 **"letting Neil to work on a better fix"**；
   截至 2026-11-13 patchwork 里**没有** Neil 的替代修投递（§3）。⇒ 发 v2 时明确「若 Neil 的正解在途，本补丁让位」。

## 1. 自证：`0xc0` 在首次 enable 时写不到（7.4-rc3，逐行）

全部行号取自 `gh/master:drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c`：

| # | 事实 | 位置 |
|---|---|---|
| 1 | bias 使能里 `writel(0xc0, … PLL_SYSTEM_MUXES)` **确实存在**（replay 报告引的就是这行） | `:439` |
| 2 | 但它前面 4 行有早退：`if (pll->pll_enable_cnt++) { spin_unlock…; WARN_ON(…); return; }` | `:429-433` |
| 3 | 首次 bring-up 之前，`dsi_7nm_phy_enable()` **直接赋值** `pll->pll_enable_cnt = 1`（不是 `++`，是 `=`） | `:1094`（在 `:1093` 的 `spin_lock_irqsave` 临界区内） |
| 4 | 调用顺序：`dsi_mgr_bridge_power_on()` 先 `dsi_mgr_phy_enable()`（→ `ops->enable` = `dsi_7nm_phy_enable`） | `dsi_manager.c:223`（之后才是 `:227` 的 `msm_dsi_host_power_on()`，bonded 从 `:234` 起） |
| 5 | `msm_dsi_host_power_on()` 里 `link_clk_set_rate()` → `clk_set_rate(pixel_clk)` | `dsi_host.c:2517` → `:409`/`:518` |
| 6 | 该 `clk_set_rate` 走 `dsi_pll_7nm_vco_set_rate()`，其**第一行**就是 `dsi_pll_enable_pll_bias()` | `:353` |
| 7 | 此时 `pll_enable_cnt` 已是 1 ⇒ 命中 `:429` 早退，**`:439` 不执行**（cnt 变 2） | 推导自 1+2+3 |
| 8 | 同一 PLL 的 `vco_prepare()`（`clk_prepare_enable` 路径）同样先调 bias，同样早退 | `:499`（+ slave `:501`） |
| 9 | 唯一会在 `cnt == 0` 时进到 `:439` 的是 recalc/save/restore 路径，但它们**成对**调用 disable，而 disable 在 cnt 归 0 时 `writel(0, … SYSTEM_MUXES)` | `:581`（recalc）、`:641`（save_state）、`:677`（restore→set_rate）；清零在 `:417` |

即：**「`:439` 存在」≠「首次 enable 会写」。** replay 报告 §3 只看了 `:439` 这一行，没看
`:429` 的早退与 `:1094` 的预置，因此把「语义重复」当成了结论。

顺带解释「为什么这与 Dmitry 的 revert 有关」：`git show 44784327815b -- dsi_phy_7nm.c`（本机
`build/m3v2-7.3rc7` 有该对象，只读）显示这次 revert 同时**引入**了
`if (pll->pll_enable_cnt++) { … return; }`（`:429`）与 `dsi_7nm_phy_enable()` 里的
`pll->pll_enable_cnt = 1`（`:1094`），而它 revert 掉的 `93c97bc8d85d` 原本是**无条件** `pll_enable_cnt++`。
⇒ 我们的补丁修的正是这枚 revert 带回的 bonded 侧缺口，`Fixes: 44784327815b` 是对的。

## 2. 产物

| 文件 | 说明 |
|---|---|
| `0001-drm-msm-dsi-phy-program-PLL_SYSTEM_MUXES-on-the-fi.patch` | v2；9 行块注释→commit message；代码 = 1 行理由注释 + `writel(0xc0, …)`（`1 file changed, 2 insertions(+)`） |

v1（`patches/upstream/m1-2026-10-14/0001-…`，patchwork `14901898`，MID
`<20261019130041.…@mail.ustc.edu.cn>`）的 `Fixes:` 保留；v2 在 `---` 下注明只搬注释。

## 3. 上游有没有「正解」在途（patchwork 只读核查，2026-11-13）

`https://patchwork.kernel.org/api/1.2/patches/?project=dri-devel&q=<kw>&since=2026-07-01`：

| 查询 | 命中 |
|---|---|
| `PLL_SYSTEM_MUXES` | 仅 **1 条**：我们的 v1（2026-10-19） |
| `bonded PLL` / `bonded mode` | 仅 **1 条**：Dmitry 的 revert（2026-07-12） |

⇒ 截至核查时刻，**没有**第三方（含 Neil Armstrong）针对同一缺口的补丁在 patchwork 里。
（lore 本体被 Anubis 挡，本核查只覆盖 patchwork 侧；若对方直接进 maintainer 树则看不到——这是已知盲区。）

## 4. 门禁（本机实测，2026-11-13）

| 门禁 | 命令 / 环境 | 结果 |
|---|---|---|
| `git am` | `/tmp/g74`（`gh/master` 导出 + base 提交），`git am --3way` | **rc=0，1/1**，得提交 `2b0615219`（`1 file changed, 2 insertions(+)`） |
| `checkpatch --strict` | 在 `build/m3v2-7.3rc7`（**有** `44784327815b` 对象，只读调用）跑 `scripts/checkpatch.pl --strict --no-tree` | **0E / 0W / 0C**（8 行）<br>要点：`Fixes:` 标题按 checkpatch 要求写成不带反斜杠转义的形式 `("Revert "drm/msm: dsi: fix PLL init in bonded mode"")`，否则报 *Please use correct Fixes: style* |
| 目标文件编译 | `make … -j26 W=1 drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.o`（同为 `build/m3v2-7.3rc7/.config` 副本） | **rc=0，0 warning / 0 error** |

## 5. 建议

**发 v2（不要撤）**，但在 cover/回信里带三句分寸：

1. 说明 §1 的调用链证据（`:429` 早退 + `:1094` 预置 + `dsi_manager.c:227` 顺序），
   以证明「上游那行 `0xc0` 在首次 enable 时不会执行」，而不是「我们没看到」；
2. 说明 `Fixes: 44784327815b`（Dmitry 自己的 revert），并**主动提出**：若 Neil 的 better fix
   已在准备，本补丁可作为最小回退/让位，不抢设计；
3. 承认边界：现网只在我们这块板（bonded，DSI0+DSI1）上复现「面板不亮」，非 bonded 设备不受影响
   （它们的 `SYSTEM_MUXES` 期望值就是 0x0），因此**没有**其它平台的回归证据。

## 6. 尚未闭环（如实记）

- 「bonded 面板不亮」的现场复现证据是 elden 上的 Q28/M6 记录，**没有**在 7.4-rc3 树上重跑过；
- v2 与 `DIGTOP_PWRDN_B`（`dsi_pll_enable_pll_bias` 之外的另一个坑）是两件事，本补丁不碰，别混写；
- `PLL_SYSTEM_MUXES = 0xc0` 的位语义（哪两位选哪路 mux）我们只有 vendor 代码实证，无 datasheet 页码。
