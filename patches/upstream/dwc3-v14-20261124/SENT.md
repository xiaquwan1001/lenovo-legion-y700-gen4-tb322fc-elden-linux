# dwc3 v14 投递记录（2026-11-24）

- **时间**：2026-11-24 ~01:50Z（主机时钟 09:50 +0800）
- **结果**：**4 封全 `Result: 250`**（日志 `logs/sent-20261124-*.txt`）
- **cover MID**：`<20261124015002.1426767-1-xiaqinghuan@mail.ustc.edu.cn>`（1/3..3/3 = `-2/-3/-4`）
- **线程形态**：新线程（cover 无 `In-Reply-To`）—— 沿用 v12/v13 的投法（krzk 11-23 点名要求）
- **内容**：只修 sashiko 对 v13 1/3 的三条 [Low]（`mux-controls` 加 `maxItems: 1`；mux 分支拒绝
  plain `endpoint`/`endpoint@2+`；`oneOf` 搬进 `then:` 分支并删冗余项）。2/3、3/3 与 v12/v13 逐字节相同。
- **门禁**：`GATES-v14.md`（G1 3/3 干净、6 blob 中只有 yaml 变；G2 0E/0W/0C ×3；G4 rc=0/0 诊断/5420 样例；
  G5 4/4 `DTC [C]`/0 诊断；G6 11 样例 × v13/v14 两套 schema 的对照矩阵；G3 未重跑并说明理由）
- **lore 复核（2026-11-24 01:5x UTC 实测）**：`linux-devicetree` **已归档 4/4**（cover 页可见 thread overview 的
  1/3、2/3、3/3）；`linux-usb` 侧 cover 落在 devicetree 镜像（与 v12/v13 同形）。**patchwork 摄取滞后不作第一判据**。
- **发送命令**：`bash SEND.sh --yes`（本目录，自带 dry-run 前置检查）
