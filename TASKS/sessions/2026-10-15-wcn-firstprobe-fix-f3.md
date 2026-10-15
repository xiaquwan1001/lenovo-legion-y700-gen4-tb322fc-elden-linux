# 会话记录 2026-10-15：WCN 首探修法（F1/F2/F3）与 boot_b 换新

> 承接 `TASKS/sessions/2026-10-14-wcn-firstprobe-dyndbg.md`（E3/E3a/E3c/E4：首探必失败、重发即成功）。
> 主题：把「重发」做进内核；结论 = **只有整轮重探有效（`-EPROBE_DEFER`）**。设备 U2 `HA2EXB0E`，全部零写盘 `fastboot boot` + 一次 `boot_b` 刷写。

## 0. 结论（数字）

| 臂 | 改动 | 结果 |
|---|---|---|
| F1 | `ath12k_mhi_start` 内重发 ×6 | try2–6 全 **-5**（设备停 SBL）；`Run /init` 12.78 s ⇒ **否证** |
| F2 | 每轮先 `ath12k_pci_sw_reset(true)` 再重发 | **6/6 -110**；`Run /init` 28.15 s ⇒ **否证** |
| **F3** | `ath12k_core_init` 失败返 **`-EPROBE_DEFER`**（上限 4） | 重探#3 **11.78 s `chip_id 0x2` 成功**；`Run /init` **7.670 s**；`wlan0` 19.1 s 关联 ⇒ **采纳** |

## 1. 已落地

- 分支：`m1-73/f1-mhiretry` / `m1-73/f2-socreset`（`7f163a797f`）/ `m1-73/f3-defer`（`fba09b5385`）；**F3 已 cherry-pick 入 `m1-73/baseline`（tip `ad5f03c43c`）**。
- 镜像：`out/boot-elden-{f1-mhiretry,f2-socreset,f3-defer}.img`、`out/boot-elden-m1-baseline-f3.img`（sha `40e13f8a…`）+ 各 `.manifest`。
- **`boot_b` 已刷 `m1-baseline-f3`**（`scripts/flash-b.sh`，签名 sha `78a2beb1…`，读回一致）；冷起 GOOD：`Run /init` 7.667 s、WCN 11.767 s、`wlan0` 17.52 s、L1=0/L2=0 + `dsi_isr`=41 ⇒ 面板 GOOD、槽位 marked successful。
- 证据：`logs/arm-{f1-mhiretry,f2-socreset,f3-defer}/`、`logs/arm-m1-baseline-f3-20261015/`、`logs/arm-boot_b-m1-baseline-f3-20261015/`；报告 `reports/f1-f3-wcn-firstprobe-20261014.md`；经验 `PITFALLS #264/#265`。

## 2. 遗留

- 上游报告（投递冻结中）：F3 属**本地件**（正确解在 firmware/MHI 侧）；可作 bug report 素材。
- `boot_b` 现在跑 7.3 树 ⇒ 需要 7.3 `/lib/modules` 的 `=m` 驱动目前只有 ramdisk 内嵌的 `fsa4480`/`fastrpc`；**日常功能抽检全在**（触屏 `NVTCapacitiveTouchScreen` 为内建、BT/声卡/传感器/电池/DP 均正常），若后续需要相机等 `=m` 栈须再做 ramdisk overlay 或部署 7.3 模块目录。
- Q28 仍未根治：本次 4 发中 3 坏 1 好（群聚），与 F3 无关。
