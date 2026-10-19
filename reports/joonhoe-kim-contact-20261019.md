# Joonhoe Kim 信息性接触 + dispcc runtime 残留实测（2026-10-19）

> 目的：Q28/Q24 相邻的第三独立度量——「显示关、系统醒」时 dispcc 是否残留 runtime active。
> 线程：`drm/msm/dsi: fix AHB clock staying enabled across suspend`（Arpit Saini v1）。
> 授权：用户 2026-10-19 采纳并逐字批准邮件正文。

## 1. 本机实测（vk127 / 7.3-rc7 血统，物理 POR 后同一 boot）

采集方式：`org.gnome.ScreenSaver.SetActive(true/false)`（DPMS off/on），读
`/sys/devices/platform/soc@0/<dev>/power/runtime_status`；`clk_summary` **最后读**（已知会
runtime-resume 时钟控制器）。`boot_id` 前后一致（`bdf43b01-d8c6-4224-a617-8921f930552b`）。

| device | 显示开 | 显示关（DPMS off） |
|---|---|---|
| `ae00000.display-subsystem` | active | **suspended** |
| `.../ae01000.display-controller` | active | **suspended** |
| `.../ae94000.dsi` | active | **suspended** |
| `af00000.clock-controller`（dispcc） | active | **active（残留）** |

显示关着时 `clk_summary` 摘录：
```
disp_cc_mdss_mdp_clk   1  1  0  575000000  ...  Y  display-controller@ae01000
disp_cc_mdss_ahb_clk   3  3  0   19200000  ...  Y  af54000.displayport-controller  core_iface
```
⇒ 两条可复用的判据新增：
1. **dispcc 在面板/DPU/DSI 全部 runtime-suspend 后仍 `active`** —— 与 Joonhoe 的观察一致，
   且比他的「probe 期 prepare」描述更靠后（DPMS off 之后仍残留）。
2. **`disp_cc_mdss_mdp_clk` 仍被 `display-controller@ae01000` 持有 (enable=prepare=1)**，
   而该设备本身已 `suspended` —— 是「设备挂起但 CCF 引用未放」的直接证据。
3. `disp_cc_mdss_ahb_clk`=3 且消费者含 **`af54000.displayport-controller`** ⇒ 本机 DP 链路
   也在占 AHB；评估 Q28「坏发=持续 down-state」时需把 DP 消费者算进去。

## 2. 发出的邮件

- **Message-ID**：`<179241542813.315541.11037007061803544238@mail.ustc.edu.cn>`
- To：Joonhoe Kim `<26rote@gmail.com>`；Cc：Arpit Saini、linux-arm-msm、dri-devel、freedreno
- `In-Reply-To`：`<20261016125036.1069-1-26rote@gmail.com>`（在原作者线程内）
- 归档复核：`/linux-arm-msm/` **已归档**（`?q=s:AHB clock staying enabled` 命中 2026-10-19T13:10:29Z）
- 正文：`out/draft-joonhoe-20261019.txt`（纯 ASCII，37 行，1697 B）
- 内容边界：只陈述本机观测 + 一个低负担问题；**未**索取日志、**未**提 G2/G3、**未**写 SN/IP/机型名。

## 3. 待跟踪

- Joonhoe 回信（若答「dispcc 也会 suspended」⇒ 我们的残留是本地缺陷，值得单独查；
  若答「同样残留」⇒ 上游共性，可并入 Q28 判据）。
- 由此派生一个**可做的小实验**（未排期）：在 DPMS off 后 `echo auto > .../control` 手动 runtime-suspend
  dispcc，看是否影响面板恢复；若可安全 suspend ⇒ 说明残留是引用计数问题而非硬件约束。
