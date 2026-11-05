# 2026-10-28 dispcc 与 battmgr 回信（lane session）

- **日期**：2026-10-28
- **pi 会话 id**：lane 子代理（编排者派发；本文件由该 lane 写）
- **主题**：A. 回 Taniya Das 的 dispcc-sm8750 RFC 方向否决；B. 回 Konrad Dybcio 的 battmgr vendor repo 核查
- **结论**：两封均已发出并进 lore 归档。battmgr 核查结论 = **该 repo 确实含 QBG/battery 路径**，我方旧说法「drop 不含该子系统」**推翻**，根因是本地 sparse-checkout 未拉 `drivers/power`。
- **证据指针**：
  - 报告：`reports/dispcc-battmgr-20261028.md`（§A/§B/§C）
  - API 证据：`out/mail-20261028/battmgr-verify/`（`evidence-github-api.txt`、`local-lstree.txt`、`repo.json`、`supply-qcom.json`、`sun_perf.config`、`sun_le.config`、`defconfig`、`qcom_battmgr.c`）
  - 草稿：`out/mail-20261028/re-taniya-dispcc.txt`、`out/mail-20261028/re-konrad-battmgr-20261028.txt`
  - Sent Items 回读：`out/mail-20261028/sent-verify/`
  - 原信：`out/mail-20261028/orig2/`（Taniya 1 封 + Konrad 3 封）
- ★SSOT 待并入：无（过程叙事留 sessions/，2026-11-05）
  1. `TASKS/README.md` M2 A2 行：把「drop 不含该子系统」改成「drop 含该子系统，我方旧观测为 sparse-checkout 假象；厂商 SM8750 编 `QTI_BATTERY_CHARGER=m`，属性 id 22 无重映射」。
  2. `TASKS/README.md` Q28 行：dispcc RFC 形状已被 Taniya 否决，改落点待选（三个候选，均未上机）。
  3. `reports/m2-a2-vendor-repo-check-20261026.md` §1 的措辞需带一句指针到本轮更正。

## 时间线（追加式）

- 19:14–19:22 上一轮 lane 已把 repo 单文件抓到 `out/mail-20261028/battmgr-gh/`，但**无 API 证据落盘**，且报告骨架全空。
- 19:50 本轮起：读 RFC 原文、`msm_mdss.c`、`sm8750.dtsi`、`dispcc-sm8750.c`、`clk-alpha-pll.c`。
- 19:52 GitHub API 单文件核实（`repos/`、`contents/drivers/power/supply`、`contents/.../qcom`、逐文件 HTTP 码、`sun_*.config`、`Makefile`/`Kconfig`）。
- 19:55 证据落盘 `out/mail-20261028/battmgr-verify/`；发现 `stock-src` 的 `.git/info/sparse-checkout` 未含 `drivers/power` ⇒ 定性为**我方观测错误**。
- 19:56 报告骨架 + 两封草稿落盘；dry-run 均为纯 ASCII、收件人/线程头正确。
- 19:57:48 发 A（Message-ID `179318866835.88849.1485640983989491497`），`已发送 OK`。
- 19:57:57 发 B（Message-ID `179318867727.88971.13007415873000488463`），`已发送 OK`。
- 20:00 Sent Items 回读 #190/#191 逐字一致。
- 20:04 lore：A 命中 `/linux-arm-msm/`（`2026-10-28T11:57:57Z`）、B 命中 `/linux-pm/`（`2026-10-28T11:57:58Z`）。

## 未做 / 遗留

- `linux-clk` 侧 raw 被 Anubis 403 挡（Cc 列表，同 Message-ID 已在 `linux-arm-msm` 证投递）。
- dispcc 新落点选型、battmgr raw slot 22 采样：**均未上机 / 未证实**。
- 未改 `patches/upstream/q28-dispcc-2026-10-22/README.md` 的状态行（SSOT 面，超出本 lane 写权限）。
