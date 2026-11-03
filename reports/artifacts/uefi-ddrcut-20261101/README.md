# uefi-ddrcut-20261101 — 切断回落实验取证件

- 用途：UEFI 线「切断回落」实验（2026-11-01/02）的只读取证物；结论见
  `reports/uefi-ddrcut-20261101.md`（如无此文件，见 `TASKS/sessions/2026-11-01-卡fastboot闭环-引导固件代次与槽位脱钩.md`）。
- **`*.img` 不入库**（`boot_b-backup-2350.img` = 96 MiB，超 GitHub 50 MiB 建议线且可重读回）：
  唯一账 = 本目录 `SHA256SUMS.img`（sha256 + 文件名）+ 文档里记录的 `fb55997c…` 前缀。
- 小件（`logfs-*.bin` 8 MiB、GPT 双表、`misc.bin`）仍入库，属可携带证据。
