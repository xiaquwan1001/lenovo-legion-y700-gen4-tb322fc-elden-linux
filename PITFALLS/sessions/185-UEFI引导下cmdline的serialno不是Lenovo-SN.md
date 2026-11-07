# #555 · UEFI 引导的内核 cmdline 里 `androidboot.serialno` **不是** Lenovo SN（`51318dc0` vs `HA2EXB0E`）

- 日期：2026-11-07（深夜·三，G1-29，p58 打通后首次在 UEFI 引导的系统里读 cmdline）

## 事实

- `fastboot getvar serialno` → `HA2EXB0E`（设备真实 SN）。
- p58 UEFI 引导的内核 `/proc/cmdline` → `… androidboot.serialno=51318dc0 …`
  （同一串也出现在 p54/p55 的 `ramoops` 内核 console 里，说明是 UEFI 侧统一填的，不是偶然）。
- `PITFALLS #549` 的纪律是「认设备只认 `getvar serialno` / 内核 `androidboot.serialno`」——
  **在 UEFI 引导下这两者不一致**，按后者会指到「另一台机」。

## 纪律

- 认机器：优先 `fastboot getvar serialno`；用内核侧字段时只认**与 getvar 一致**的那个，
  目前本机 UEFI 路径**不能**用 `androidboot.serialno` 归属设备。
- 任何按 `androidboot.serialno` 派工/写备份目录的脚本，在 UEFI 引导下必须先比对 getvar。
- 想让该字段可用 ⇒ 改 UEFI 侧（`DeviceInfo`/`UpdateCmdLine` 里的 serial 来源），属功能项，别当已成事实。
