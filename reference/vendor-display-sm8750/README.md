# SM8750 原厂 display 源码参考（vendor display-drivers）

2026-10-12 拉取。用于 Q28（bonded 双 DSI 冷起首条 DCS 命令 DMA 超时，`status=0x2200200`）的**代码级对照**。

## ★ 权威副本在本仓（优先用它）

- **本机机型权威**：`stock-src/android_kernel_lenovo_sm8750-modules/qcom/opensource/display-drivers/msm/dsi/`
  （Lenovo GPL 开源，与设备同板；含全部 40 个 dsi 文件）。
- **本目录** = 同 SoC 兄弟机型参考：OnePlus SM8750
  （`LineageOS/android_kernel_oneplus_sm8750-modules` @ `lineage-24.0`，路径 `qcom/opensource/display-drivers/msm/dsi/`）。
- 逐文件比对：`dsi_ctrl_reg.h` / `dsi_clk_manager.c` 与 Lenovo 版**逐字节相同**；
  其余差异 = `OPLUS_*`（OnePlus OEM 异常上报）与 `CONFIG_PXLW_IRIS`（Pixelworks）OEM 补丁，**非通用核心逻辑**。

> 结论：**本机已不需要 /tmp 里的易失副本**；`/tmp/vdsrc` 是这批文件的来源，可弃。

## 文件清单（sha256）

| 文件 | sha256 |
|---|---|
| dsi_ctrl_hw_cmn.c | f14ca3abe5b905d2413df041a49c2cb5663353b8207ded055c95dcd47178e293 |
| dsi_ctrl.c | 8860d2fc57f3303a088595ee9cd06ea50f8d170598ce2200a81daacedf715ba0 |
| dsi_ctrl_hw.h | （2026-10-12 追加拉取）|
| dsi_ctrl_reg.h | 22dd3637d7505f388532a065110abe1fcc69f206617fa00230c5bbfbc9d775e9 |
| dsi_clk_manager.c | 440d524fb503b4578c6ac02512cda2d372903153d5c06f9b507a883686962a13 |
| dsi_display.c | 1bdf20c1070b6a5c2a956a2f7e211c595f10875c7ec2abbe4ede13c65f678ba3 |
| dsi_phy_hw.h | 77dbed8606a887db79ed5d6ee08b69dd8951e724f84426512a9bf20111abe118 |
| dsi_phy_hw_v7_2.c | e045727c3a2d7a3bdd46399960ca97ff97b6213e5db93f894bfe9069b92767bf |
| dsi_pll_3nm.h | 8120622f76bdaa01cd3b5731ca558f7c6156caefaa413a93ae7f786f1942207d |

原始 URL：
`https://raw.githubusercontent.com/LineageOS/android_kernel_oneplus_sm8750-modules/lineage-24.0/qcom/opensource/display-drivers/msm/dsi/<file>`

## 对照结论

见 `reports/q28-dispcc-static-20261012.md`（命令路径逐项对照、复位终态差异、PHY reset clamp 候选、下一步实验）。
