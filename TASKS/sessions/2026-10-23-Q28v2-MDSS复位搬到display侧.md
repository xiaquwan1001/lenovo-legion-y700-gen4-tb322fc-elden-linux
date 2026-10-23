# 2026-10-23 · Q28 v2：MDSS 复位搬到 display 侧（主机侧完成）

- **日期**：2026-10-23
- **pi 会话 id**：`$PI_SESSION_ID`
- **主题**：按 Taniya Das 2026-10-22 评审，把 Q28 的复位从 `dispcc` 时钟驱动**搬到 display 侧** `msm_mdss_reset()`，
  并保证时序仍早于 PLL 配置；产出可上机镜像 `vk150-q28v2`
- **结论**：
  1. **可行性前提已核实**：`msm_mdss_init()` 第一件事是 `msm_mdss_reset()`（`:372`），
     `devm_clk_bulk_get_all()` 在 `:403`、`clk_bulk_prepare_enable()` 在 `:255` ⇒ **复位天然早于 PLL**，
     Taniya 的架构意见与我们要的时序**不冲突**。
  2. **三处改动 +79/−13**：binding 扩成 3 项 reset（`minItems: 1` 向后兼容）/ `sm8750.dtsi` 加 3 个 BCR /
     `msm_mdss.c` 改 bulk reset，**保留无 `reset-names` 时的单 reset 老路径**。
  3. **验证全绿**：`msm_mdss.o` 0 warning、整内核 **0 error / 0 warning**、
     DTB 反编译 `resets = <0xd7 0x00 0xd7 0x01 0xd7 0x02>` + `reset-names` 三项、`dtbs_check` elden 板 **0 报错**。
  4. **踩到并修掉 `PITFALLS #367` 的坑**：首轮 UTS 变成 `7.3.0-rc7-debug-00002-…`（丢了 `-vk127`），
     会与设备 1497 个 `.ko` 全部失配。修法 = 钉 `CONFIG_LOCALVERSION` + 关 `LOCALVERSION_AUTO`
     + **删 `include/config/kernel.release` 缓存**后重建（否则 `make kernelrelease` 仍返回旧值，像配置没生效）。
  5. **上机冒烟 2/2 GOOD**，但第一版直接失败并抓到一个真实 bug：
     `msm-mdss: error -EBUSY: failed to acquire mdss resets` ⇒ probe `-16`、显示完全不起来（比 base 更差）。
     根因 = `reset_control_get_exclusive()` 与 **dispcc 自己的 reset provider 持有**冲突；
     修法 = `devm_reset_control_bulk_get_shared()` + **deassert prime**（shared 是 deassert 引用计数，
     首用须先 deassert 一次，否则 assert 撞 `WARN_ON(deassert_count==0)`）。
     修正后 `connected`/`enabled`/`dpu_err=0`/`EBUSY=0`、`debugfs dri/0/state` 有 `fb=110` 真扫描、亮度 511。
  6. **未做**：读回校验（`qcom_reset_ops` 无 `.status`，需直读 dispcc regmap `0x8000/0xa000/0xc000` bit0）、
     simpledrm 在场/不在场对照、**真 POR ≥5 发**（当前 2 发是 `reboot2 bootloader` 暖复位，不构成严格 A/B；
     第 3 发撞 `PITFALLS #368` USB 全不枚举，需人工断电）。
- **证据指针**：
  - `reports/q28-v2-mdss-reset-20261023.md`（主报告）
  - `patches/q28-v2-20261023/0001-display-reset-mdss-at-probe-once-early-and-verify.patch`
  - 树 `build/q28-v2`（worktree @ `24223e44ad80`）
  - 镜像 `out/boot-elden-vk150-q28v2.img`（**修正版** `sha256 831ca7c4…`；旧 `2898d006…` 有 `-EBUSY` bug 勿用）
- **★SSOT 待并入**：`TASKS/README.md` §5 **Q28** 行已就地补入 v2 状态（本会话已改）。
