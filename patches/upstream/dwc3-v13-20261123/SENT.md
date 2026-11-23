# dwc3 v13 投递记录（2026-11-23）

- **时间**：2026-11-23 ~11:08Z；**结果**：4 封全 `Result: 250`
- **cover MID**：`<20261123110858.538884-1-xiaqinghuan@mail.ustc.edu.cn>`
- **线程形态**：新线程（cover 无 In-Reply-To）
- **内容**：三枚 patch 与 v12 **逐字节相同**（G1 fresh am 3/3 + 6 blob sha 与 v11/v12 一致）；v13 只改 cover —— ① changelog 补全历代（v4/v5/v7/v8/v9 新增全史段 + item 8 答 greg k-h 08:20Z）② Subject 升 v13
- **门禁**：G1/G2 本轮实跑（am 3/3；checkpatch --strict 3/3 0E0W0C）；G3–G6 沿用 v12 日志（`patches/upstream/dwc3-v12-20261123/logs/`，代码相同）；G4 重跑按用户 11-23 裁决后延（编译任务后延）
- **lore 复核**：待摄取，按 MID 查 linux-usb / linux-devicetree
