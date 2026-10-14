# 上游回信与归档核查 — 2026-10-14（只读主机侧 lane）

- 方法：IMAP `read-mail-ustc.py`（7/14 天 + `--replies-only`，INBOX/Junk/Sent 三处）＋ lore 按 Message-ID 取 raw / 线程视图 / 搜索页。全部为**我实测**（命令+原始输出摘录见文末）。
- 纪律遵守：未发信、未碰设备、未改任何树。

## 结论表

| 系列 | Message-ID | lore 归档 | 有无回信 | 回信要点 |
|---|---|---|---|---|
| Q28 报告：bonded dual-DSI + NT36536 | `179184923104.248043.14168731037113716140@mail.ustc.edu.cn` | ✅ [linux-arm-msm](https://lore.kernel.org/linux-arm-msm/179184923104.248043.14168731037113716140@mail.ustc.edu.cn/)（raw 直取成功，头含 ARC，subspace 2026-10-12 23:53 UTC 收） | ✅ Pengyu Luo 2 封（lore 2026-10-13 04:35/04:38 UTC；IMAP 收到 4 份副本） | IRT 直指本 Message-ID。要点：**panel 驱动 upstream 支持，DPU 未必**；dual-DSI/dual-DSC 上游驱动大体可用，但 DPU 还缺件（如 10-bit CPHY plane 的 dsi clk source select hack），他之前只上游了部分补丁，集成费时。 |
| Q24 RFC v3：cambistmclkcc+camcc 硬复位 | `179179331695.677917.11557670447411700010@mail.ustc.edu.cn` | ✅ linux-arm-msm / linux-devicetree / lkml / linux-clk 四处均在线（author 搜索命中） | ✅ Taniya Das (oss.qualcomm.com) 2026-10-13 10:33 UTC，[lore](https://lore.kernel.org/linux-clk/869f6981-38d3-48cc-824e-98b5f662bd01@oss.qualcomm.com/)；另有我方补充回帖 179185039667…（Taniya IRT 指向该补充帖） | 回答了"上游是否有 consumer"之问：Kaanapali camera DT overlay v21 14/14 用 cambistmclkcc 作 MCLK provider ⇒ 上游确有 consumer；讨论 bare/consumer-less controller 是否安全。⚠️ Junk 里有一封 `postmaster@qualcomm.com` `Undeliverable`（10-12）退信，属早期收件人之一，主投递不受影响。 |
| M3-1 系列：dwc3 双连接器共享 HS 总线（0..3/3） | `20261013102927.1141696-1..4-xiaqinghuan@mail.ustc.edu.cn` | ✅ linux-usb 4/4、linux-devicetree 4/4、linux-arm-msm 4/4、lkml 4/4（author 搜索全命中） | ❌ 无外部回信（线程视图 "replies" 全为同系列自件；IMAP --replies-only 7 天窗口零命中） | 投递 ~1 天，无 review；待 Greg/Thinh 侧响应。 |
| M2 A2：qcom_battmgr 不上报 power_now | `20261013002124.332111-1-xiaqinghuan@mail.ustc.edu.cn` | ✅ linux-pm / lkml / linux-arm-msm 在线 | ❌ 0 replies（线程视图 "0 siblings, 0 replies"） | 待 Sebastian Reichel / linux-pm 响应。 |
| M2 附带：dpu DSPP GC block（同批发出，非任务点名但相邻） | `20261013002124.332074-1-...` | ✅ linux-arm-msm 在线 | ❌ 仅有我方自回（179185706019…，2:04 UTC） | — |
| M2 P3：dpu reject undersized gamma LUT | `20261013020425.408928-1-xiaqinghuan@mail.ustc.edu.cn` | ✅ linux-arm-msm 在线 | ❌ 0 replies | 待 dri-devel/msm 维护者响应。 |

## 我实测（命令与原始输出摘录）

### 邮箱（read-mail-ustc.py --days 7 --replies-only）
```
=== INBOX : 8 封（SINCE 07-Oct-2026）=== [replies-only]
  [623] 13 Oct 08:13 | Qianhui Xu | Re: [Regression v3] SM8750: cambistmclkcc + camcc ...
  [767/768] 13 Oct 12:34 | Pengyu Luo <mitltlatltl@gmail.com> | Re: [REPORT] SM8750 bonded dual-DSI + NT36536 ...
  [1234/1357/1388] 13 Oct 16:03 +0530 | Taniya Das <taniya.das@oss.qualcomm.com> | Re: [Regression v3] SM8750: cambistmclkcc ...
=== "Junk E-mail" : [3] 12 Oct | postmaster@qualcomm.com | Undeliverable: [Regression v3] ...
=== "Sent Items" : M3-1 4 patch（18:29 10-13）、M2 GC/battmgr（08:21）、P3（10:04）均无外部回信
```

### lore（lore-query.py + 直接 raw 抓取）
- Q28 raw 直取成功：`https://lore.kernel.org/linux-arm-msm/179184923104.../raw` → `Received: ... by smtp.subspace.kernel.org ... Mon, 12 Oct 2026 23:53:58 +0000`，Thread 视图：`0 siblings, 1 reply`（Pengyu Luo 04:34 UTC）。
- Pengyu 回信 raw：`In-Reply-To: <179184923104.248043.14168731037113716140@mail.ustc.edu.cn>`；正文："the panel driver is supported, the DPU may not be ... we need to hack the dsi clk source select for the 10-bit CPHY plane"。
- Taniya 回信 raw：`In-Reply-To: <179185039667.309517.8503800087166757122@mail.ustc.edu.cn>`（我方补充帖）；正文："The Kaanapali camera DT overlay (PATCH v21 14/14) uses cambistmclkcc as a camera MCLK provider ... So upstream does have a consumer for the block."。
- M3-1 cover 线程：`2026-10-13 10:29 Qianhui Xu ... 0 siblings, 3 replies`（3 条均为本系列 1..3/3 自件）。
- battmgr 线程：`0 siblings, 0 replies`；gamma LUT 线程：`0 siblings, 0 replies`。
- M3-1 四枚在 linux-usb / linux-devicetree / lkml 的 author 搜索（`?q=f:xiaqinghuan@mail.ustc.edu.cn`）各 4/4 命中，URL 形如 `https://lore.kernel.org/linux-usb/20261013102927.1141696-1-...`。

## 阻塞
无。邮箱凭据可用（keyring 通道正常），lore Anubis 均已通过；本任务全部完成，未发任何邮件。
