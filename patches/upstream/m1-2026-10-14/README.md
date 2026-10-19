# M1 显示修复片（2026-10-14）

上游基线：**pristine 参照 = `24a19b953e`（Linux 7.3-rc7）**。
工作树 = `build/m1-upstream/clean-tree-73`，**功能基线分支 = `m1-73/baseline`（tip `c7da05b1d8`）**：
`m1/clean-tree-7.3rc7`（7.3-rc7 + 板 DTS 追赶）之上只加 2 个提交。

| 提交 | 主题 | 性质 | 上游 |
|---|---|---|---|
| `54dc4dd8fe` | `drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable` | **修上游回归**（bonded 面板不亮） | ✅ **本目录 0001** |
| `c7da05b1d8` | `ath12k: shorten MHI wait timeout 90s->3s` | 本地 workaround | ❌ **不进上游**（见下） |

> 基线分支的两枚提交分工与 E2 会话结论一致（`../TASKS/sessions/2026-10-14-m1-73-mainlining.md` §3）：
> **E1b 无探针版 = 上游件**；**`0001`（ath12k）/ Kconfig / 板 DTS = 本地件**。

## 0001 —— 唯一可上游补丁（未发送）

**文件**：`0001-drm-msm-dsi-phy-program-PLL_SYSTEM_MUXES-on-the-firs.patch`

**内容（净 9 行，无探针）**：在 `dsi_7nm_phy_enable()` 预置 `pll_enable_cnt = 1` 之后补写
`PLL_SYSTEM_MUXES = 0xc0`；`dsi_pll_enable_pll_bias()` **保持上游原样**（refcount 语义不动，暖路径写入保留）。

**根因（已证）**：`93c97bc8d85d ("drm/msm: dsi: fix PLL init in bonded mode")` 被 Dmitry Baryshkov
**revert**（`44784327815b`，2026-07-12，理由 = 破坏非 bonded 用例）后，7.3-rc1 起
`dsi_7nm_phy_enable()` 预置 `pll_enable_cnt = 1` 使 `dsi_pll_enable_pll_bias()` **必然早退**，
`PLL_SYSTEM_MUXES = 0xc0` 在**首次（bonded）bring-up 中永不写入** ⇒ 面板只有背光、无内容。
补丁把该写入放回 PHY 初始化路径，**不动 refcount 语义**（避免再次以"破坏非 bonded"为由被 revert）。

**上机证据**：E1b 臂（同 1 行语义 + 5 条探针）物理 POR 干净发实测 **面板有内容 + 触屏可操作**，
探针实证 `phy_enable … muxes=0xc0`、`bias_en EARLY-RET` ×21、`dsi_isr=41`（= vk94 基线）。
证据层 `reports/m1-73-e1b-pllfix-20261014.md`、`reports/m1-display-rootcause-analysis-20261014.md`。

**验收门（本机实跑）**

| 门 | 命令 | 结果 |
|---|---|---|
| checkpatch | `scripts/checkpatch.pl --strict --no-tree --terse <patch>` | **0E / 1W / 0C**；唯一 W = `Unknown commit id '44784327815b'`（partial clone 无该对象，**已知良性**：提交由 lore 外部核实，见根因报告 §36） |
| 干净应用 | `git worktree add --detach /tmp/m1-pristine-verify 24a19b953e && git am <patch>` | **rc=0**（tip `4741b209f9`） |
| 编译（补丁树） | `make … drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.o` | **rc=0**，0 error/warning |
| 全量构建（基线分支） | `make -j16 … Image.gz dtbs` | **rc=0 / 0 error / 0 warning**；`Image.gz` **20 798 895 B**；板 DTB 153 101 B（**与补丁前逐字节同**） |

**投递（2026-10-19，用户解除冻结）**：
- 前置复核：上游 `master` = **Linux 7.3 正式版 `c03c1a145`**，`dsi_phy_7nm.c` 自 `v7.3-rc7` **零改动**，
  `PLL_SYSTEM_MUXES` 缺失仍在；`linux-arm-msm` 搜索无同名补丁（无重复工作）。
- 通道：`git send-email`（smtp.ustc.edu.cn:465），Result: **250**。
- **Message-ID**：`<20261019130041.305805-1-xiaqinghuan@mail.ustc.edu.cn>`
- 归档复核：`/linux-arm-msm/` **已归档**（`?q=PLL_SYSTEM_MUXES` 命中，2026-10-19T13:01:05Z）。
- To：Rob Clark / Dmitry Baryshkov / Abhinav Kumar / Jessica Zhang / Sean Paul / Marijn Suijten；
  Cc：linux-arm-msm / dri-devel / freedreno / linux-kernel。
- 本地门（复跑）：checkpatch --strict **0E/1W/0C**（W = partial clone 缺 `44784327815b`，良性）、
  pristine `24a19b953` `git am` rc=0、`dsi_phy_7nm.o` `W=1` rc=0/0 warn（2026-10-19）。

## 本地件（不在本目录，勿发上游）

- **`c7da05b1d8` ath12k `MHI_TIMEOUT_DEFAULT_MS 90000→3000`**：`reports/upstream-policy-20261013.md` §3
  列为 **Q3 违例 D4**（"全局超时 | 掩盖 WCN 上电时序 | **删；正确解 = probe defer**"）。
  ⇒ **仅作功能基线的本地件**；上游形态应改为 `probe defer`（WCN 未就绪时不阻塞内核 initcall），另立项。
- **板 DTS 追赶**（`&i2c0 disabled`、`splash_region` 改名）：属 **M3 板支持系列**（板尚未上游），随 M3-2 发。
