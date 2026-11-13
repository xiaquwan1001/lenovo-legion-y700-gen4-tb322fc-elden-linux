# 上游 7.4 重放可行性实验 — 2026-11-13

> 只读实验：在**独立 worktree** 里做的 cherry-pick 演练，未改任何受管树、未碰设备、未发信。
> 原始记录：`reports/artifacts/r74-20261113/{replay-conflicts.txt,replay-status.txt}`。

## §0 结论（数字先行）

1. **能合，而且比想象便宜**：把**现役功能树的 payload**（`79a907609d5` Linux 7.3.1 → `88cd0bc0f4f` elden payload v2，148 文件 / +16 412 −649）重放到
   **上游 `gh/master` = `9d66f26fefa`（7.4-rc3 线，2026-11-11）**，结果 **107 文件自动干净、26 个新文件自动落地、只有 15 文件 / 19 个冲突 hunk**。
   冲突全部集中在「上游同一处也被改过」的文件上，**显示/DSI/camss/ath12k/remoteproc/sm8750.dtsi 一条冲突都没有**。
2. **别从 7.2 功能树直接合**：同一 payload 若以老的 `linux/`（geekidos 7.2 快照）为源，冲突是 **27 文件 / 46 hunk**（多 2.4 倍）。
   7.3.1 那一步重放已经把 7.3 的上游重构吸收掉了 ⇒ **必须从 `build/daily`（7.3.1 + payload v2）出发**，不是从 `linux/`。
3. **7.4 已经吃掉了我们两处本地补丁**：`panel-novatek-nt36536.c` 上游已有（Pengyu Luo 版，我们的 elden delta 只剩 8 行且**干净叠加**）；
   `PLL_SYSTEM_MUXES=0xc0` 的 bonded 修法上游 `dsi_pll_enable_pll_bias()` 已等价实现 ⇒ `4da9a8b69fc` 那 9 行在 7.4 上**语义重复、可 retire**。
   `rpmhpd` 的 `skip_retention_level` 上游 7.3 起改成**无条件 skip Retention** ⇒ 我们的字段该删、语义保留。
4. **「7.4 上游本身」对我们的功能增量 ≈ 0**（`reports/upstream-merge-candidates-20261112.md` 已逐条查过：master 相比 7.4-rc2 基线只有
   treewide `devm_kzalloc_obj` 机械转换；真正值得并的是 patchwork 里那 3 条必修）。**所以「上 7.4」的价值 = 换基线、不是取功能**。

## §1 实验装置（可复现）

```bash
# 上游：build/m3v2-7.3rc7 已有 gh/master（部分克隆，1.6 GB，不重下）
cd /home/xuqianhui/y700-elden/build/m3v2-7.3rc7
git log -1 --format='%H %ad %s' --date=iso gh/master
#   9d66f26fefacebfeed15de31c1123451a17ff119 2026-11-11 Merge tag 'vfs-7.4-rc3.fixes.2'

# 演练：独立 worktree，cherry-pick 现役 payload（只 -n，不落提交）
git worktree add -q --detach /tmp/r74b gh/master
cd /tmp/r74b && git cherry-pick -n 88cd0bc0f4f      # rc=1（有冲突）
git status --short | awk '{print $1}' | sort | uniq -c
#   26 A / 107 M / 15 UU
git diff --stat HEAD | tail -1
#   148 files changed, 16412 insertions(+), 649 deletions(-)

# 对照组（老路，7.2 快照为源）：/tmp/r74 = v7.2 + linux/ 的 173 文件 delta -> 26 A / 114 M / 27 UU / 46 hunk
```

## §2 15 个冲突文件与判定（hunk 数 / 性质 / 处置）

| hunk | 文件 | 性质 | 处置 |
|---|---|---|---|
| 4 | `drivers/pci/controller/dwc/pcie-qcom.c` | 上游重写了 `iommu-map` 解析（支持 `#iommu-cells=2`），我们的 SID 映射补丁与它同函数 | 取上游结构，把我们"每项 5 cells"的注释/行为**合并进上游循环**（可判定，需读 40 行） |
| 2 | `sound/soc/qcom/qdsp6/q6apm.c` | 我们的 audioreach/Q6APM 增量 vs 上游同文件改动 | 手工合（两处插入相邻） |
| 1 | `sound/soc/qcom/qdsp6/q6apm-dai.c` | 同上 | 手工合 |
| 1 | `sound/soc/qcom/qdsp6/audioreach.h` | 同上（头文件插入位置） | 手工合 |
| 1 | `drivers/power/sequencing/pwrseq-qcom-wcn.c` | 我们的 WCN 供电序列 vs 上游 refactor | 手工合 |
| 1 | `drivers/media/i2c/Makefile` | 上游新加 `s5kjn5.o`，我们是 `s5kjns.o`（两颗不同传感器） | **两行都留** |
| 1 | `drivers/leds/flash/leds-qcom-flash.c` | 上游 treewide `devm_kzalloc_obj` vs 我们的改动 | 取上游 + 重贴我们的逻辑 |
| 1 | `drivers/gpu/drm/panel/Kconfig` | 上游新加 ILI7807S/ILI7836A 条目，我们的 NT36536 条目同区 | 两处都留（顺序） |
| 1 | `drivers/gpu/drm/msm/disp/dpu1/dpu_hw_catalog.c` | 我们给 sm8750 DSPP 补 GC 块（Night Light/色温）的注释块 | 保留我们的注释 + 上游代码 |
| 1 | `drivers/gpu/drm/msm/disp/dpu1/dpu_encoder_phys_vid.c` | 我们的 payload 删了上游的 DSC `timing->width` 缩放块 | **需裁决**：7.4 上游有、我们 7.3.1 payload 没有（回退来源要查清） |
| 1 | `drivers/gpu/drm/msm/adreno/a6xx_catalog.c` | 上游 GPULIST 宏改名/新增（`DECLARE_ADRENO_GPULIST(a6xx)` vs 我们的 a7xx 段） | 我们的 a750/x285 reglist 段**整段保留**，宏按上游 |
| 1 | `drivers/clk/qcom/gcc-sm8750.c` | 上游 `.driver_data` vs 我们的 `.use_rpm = true` | 两个字段都留 |
| 1 | `drivers/bluetooth/hci_qca.c` | 上游 `devm_kzalloc_obj` treewide vs 我们新增的 `QCA_WCN7861` 分支 | 取上游写法 + 保留 WCN7861 分支 |
| 1 | `arch/arm64/boot/dts/qcom/Makefile` | 上游插了 `sm8650-valve-deckard.dtb`，我们插 `sm8750-lenovo-elden.dtb` | **两行都留** |
| 1 | `Documentation/devicetree/bindings/clock/qcom,sm8750-gcc.yaml` | 上游现只声明 CX 供电，我们加 MX | 保留我们的 MX 项（并核对上游是否另有说法） |

**判定汇总**：19 个 hunk 里 **16 个是「两边都加、取并集」或「上游改了写法、我们重贴语义」**；
只有 3 个需要真判断（pcie-qcom、dpu_encoder_phys_vid 的 DSC 块、q6apm 组）。估**半天到一天 / 2–3 个 agent 轮次**即可出可编译树。

## §3 7.4 已经吸收了我们什么（必须据此收窄 payload）

| 我们的东西 | 7.4 状态 | 证据 |
|---|---|---|
| `panel-novatek-nt36536.c` | **上游已有**（Pengyu Luo），我们的 elden delta = 8 行（`to_primary_dsi` 取 DSI0 命令主 + pps/prepare 微调） | `git show gh/master:...panel-novatek-nt36536.c`；重放后该文件**无冲突**、diff 只剩 elden 段 |
| `PLL_SYSTEM_MUXES=0xc0`（M6 L1 / E1b） | **上游等价覆盖**：`dsi_pll_enable_pll_bias()` 首次 enable 就写 0xc0（`dsi_phy_7nm.c:439`） | `git cherry-pick -n 4da9a8b69fc` 在 gh/master 上仍 +9 行 ⇒ 与上游重复，**建议 retire** |
| `rpmhpd` `skip_retention_level` | 上游 7.3 起**无条件 skip Retention**（`rpmhpd_update_level_mapping()` 内 `continue`） | v7.3/v7.4 `grep -c skip_retention_level` = 0；我们 payload 里该字段与上游语义重复 |
| `rpmhpd` `presync_floor`（GPU/GMXC 轨） | **上游没有**（我们的本地 workaround） | 与上游冲突存在 ⇒ 保留，但要重写成上游形状 |

## §4 7.4 还没有、仍然要我方投递的（重放里必须原样保留）

`arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`（上游 0 命中）、camss 的 sm8750 支持（`camss.c` 0 命中）、
ADSP fastrpc `qcom,non-secure-domain`（M10，7.4 `sm8750.dtsi` 里 adsp 节点仍无该属性）、
wl2868c（regulator 0 命中）、aw86927（codecs 0 命中）、gc08a8 / gt9764 / s5kjns（media/i2c 0 命中）。

## §5 上机验证计划（零写盘，复用 vk185 判据集）

1. 编译：`scripts/build-kernel.sh`（严禁裸 `make`；KDIR 指重放树），`make -j26`；
   `dtbs_check` 对 `sm8750-lenovo-elden.dtb` 0 诊断；`.ko` 数量与在机模块树比对。
2. 打包 `out/boot-elden-vk19x.img` + manifest，`--selftest`。
3. `fastboot boot`（零写盘）一发，判据 = vk185 那 10 项（10 s SSH / DSI connected / 2 张声卡 / WiFi 关联 /
   `/dev/fastrpc-adsp` + `qrtr svc 400` + SensorProxy 三项 / zram / 温度），**另加**：Night Light 色温（GC 块）、
   相机出流 5 帧、`dmesg | grep -i devm` 无新 warning。
4. 通过后才谈写 `boot_b`（写前备份 + AVB 自签 + dd 读回逐字节）。

## §6 风险与不建议

- **不要**把 treewide `devm_kzalloc_obj`（202 文件）当"上游增量"去 cherry-pick 回来——它正是本次多数机械冲突的来源。
- **不要**从 `linux/`（7.2 快照）出发做这次重放（冲突翻倍，且 `fs/crypto/block.c` 这类上游已重构的文件会把 M5 的 vendor 血统带回来）。
- `build/m3v2-7.3rc7` 是部分克隆（`blob:none`）+ 439 行 shallow；`git worktree` 演练完必须 `git worktree remove` + `prune`，否则 `check-doctor` 的身份账会漂。
