# 2026-11-04 · UEFI：DXE 全走完 → BDS 之后无 ESP（12 发零写盘）

## 文件头

- **日期**：2026-11-04（下午—晚）
- **pi 会话 id**：见会话目录（本文件由该会话产出）
- **主题**：UEFI 间接引导线从「DxeCore 从未启动」推进到「DXE 全走完、UFS 枚举成功、缺 loader」
- **结论（5 条）**：
  1. `fixcopylen` 生效：64 块 FNV 表 64/64 与主机期望一致 ⇒ 4 MiB 拷贝链收口；
  2. **DxeCore 真进场**（`[D00]`+`&DxeMain`、`[D01]…[D08]`），约 150 个 DXE 驱动全部 dispatch；
  3. 致命异常 `0xD2B9B224` **归属 `QRKSDxe`**（SCM 客户端环境失败→脏指针）；剔除后**全程零异常**；
  4. **UFS 枚举成功**：`BlockIo=119`；唯一 `SimpleFileSystem` 是 LUN4 `modem_b`（FAT），**整机没有 ESP**；
  5. BDS 无目标 ⇒ 复位 ⇒ 原厂 recovery（二维码页，字符串在本仓 0 命中 ⇒ 非我们的 UI）。
- **证据指针**：
  - 正文/逐发判据：`reports/uefi-ramoops-channel-20261104R.md` §8–§11
  - 交接文档（下轮入口）：`archive/plans-20261110/2026-11-04_handoff-uefi-dxe-to-linux.md`
  - 上机件：`out/uefi-20261104R{1..12}-r1.img`，现场 `reports/artifacts/uefi-boot-20261104R*-r1/`，trial `reports/trials/20261104T*.json`
  - 新坑：`PITFALLS/sessions/162-UEFI进DXE之后的取证纪律.md`（#498–#502）
- ★SSOT 待并入：无（DEVICE §1.1 已记录设备停在 fastboot，2026-11-05）
  `TASKS/README.md` §5 的 11-04 傍晚块已写，后续若定案 A/B 路线再补一行。
