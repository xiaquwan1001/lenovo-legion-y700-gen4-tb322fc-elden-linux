# 模块化边界（SSOT，2026-10-27 收尾轮）

> 回答一个问题：**哪些驱动可以翻 `=m`、哪些必须留 `=y`、凭什么判。**
> 数据来源 `reports/modular-driver-audit-20261026.md`（全量分类表，逐符号理由）；
> 片段本体 `fragment-modular-v2.config`（42 符号，行内带理由）；门禁 `scripts/check-modular-config.sh`
> （已接进 `scripts/check-doctor.sh` §12）。数字以审计报告为准，本文只写规则。

## 1. 分类规则（判据 = 启动早期是否需要）

| 类 | 含义 | 处置 |
|---|---|---|
| **a** | 可转 `=m`：root(`UFS /dev/sda18`) 起来之前不需要；载荷在 `/init` 后由 `payload-modules-load.sh` 按序 modprobe | 入片段 |
| **b** | 必须 `=y`：console / 面板 / UFS 链 / 电源总线底座 / 全系统 clock-regulator 依赖 | 不翻；其中 28 个进 `DEFAULT_ANCHORS`，翻掉即门禁 FAIL |
| **c** | 被 `bool`/`select` 锁死：写 `=m` 也没用，`olddefconfig` 回弹 `=y` | 不写进片段（PAS/MDT_LOADER 已在片段里标注「select 锁死不放」） |

三类之外还有一类**故意不动**的：非 SM8750 平台的 `=y` 驱动（imx/tegra/meson/rockchip 等，约 1100 个 tristate）
—— 它们是 `=n` 裁剪的候选，与模块化无关，不要混进来。

## 2. 现状（第二层完成，`vk172` 起在日常线）

- `=y 3364 / =m 1464`，1638 个 `.ko`，vermagic 1638/1638 逐字一致；上机全绿（含 MMC 整链 `=m`）。
- 收益：叶驱动（触屏/背光/触觉/音频子链/WiFi/BT）改一行 → `iterate.sh mod` 秒级热换，不重编内核、不重启。
- 边界里最容易被误判的两条：① **MMC/sdhci 可 `=m`**（root 在 UFS；代价 = 不能走 SD 卡启动）；②
  **`QCOM_PAS`/`QCOM_MDT_LOADER` 永远翻不动**（`DRM_MSM` select），remoteproc 固件链只能留在内核里。

## 3. 新增一个 `=m` 的安全流程（改动前先读）

1. 判据先问「root 起来之前需要吗」——需要 → 不做。
2. 写进 `fragment-modular-v2.config`（每条附一行理由），**不要手改 `.config`**。
3. `bash scripts/check-modular-config.sh`（锚点不回退 + `olddefconfig` 幂等 + tristate 自洽）；
   `MODDIR=<模块树> …` 追加时再查 `modules.dep` 行数与 vermagic。
4. 全量构建后核对 `vermagic` 全量一致（不能只抽查）。
5. **上机验收清单**（缺一不可）：`module_err=0`、该子系统主功能可用、`dmesg` 无 defer 风暴、
   `iterate.sh mod` 热换成功、以及**冷 POR 后仍然可用**（=m 的加载顺序在冷启路径上）。
6. DRM/显示栈与 `QCOM_PAS` 一律不动（c 类）。

## 4. 已知未做（收尾遗留）

- 非 SM8750 平台 `=y` 驱动的 `=n` 裁剪轮（省内核体积，与功能无关）。
- 救援镜像（无磁盘模块树）对 `=m` 载荷的等价性未验。
