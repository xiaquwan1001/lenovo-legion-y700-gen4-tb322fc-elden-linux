# psci-vendor-reset-20261123 —— Linux→BL/EDL 软路径（本地补丁）

- **用途**：让 `reboot bootloader` / `reboot edl` 经 PSCI `SYSTEM_RESET2` vendor reset 到达固件。
  否则（`PITFALLS #690/#701`）所有软路径失效，进 fastboot 只能物理键。
- **来源**：`patches/kernel-history/elden_wifibmiss-v1v2/0003-elden-vk41-minimal-PSCI-SYSTEM_RESET2-vendor-reset-h.patch`
  （vk41 时期，2026-10-03）；本轮从 `build/g7a-tree` 现状重导出为普通 `git diff`（无 commit 元数据，方便直接 `git apply`）。
- **基线**：上游 v7.4-rc3（`aebb727447`）干净树验证可 apply；只改 `drivers/firmware/psci/psci.c`（+43 行）。
- **实测**：2026-11-23 `reboot bootloader` → ~21 s 进 fastboot，`fastboot reboot` 回 Linux 正常。
  报告 = `reports/linux-to-bl-vendor-reset-20261123.md`。
- **语义**：`bootloader` → `reset_type 0x80010001`/`cookie 0x2`；`edl` → `0x80000000`/`0x1`；
  固件返回（拒绝）则落回原普通复位路径，不会卡死。
- **注意**：函数为 static 单点调用 ⇒ 内联，`System.map` 无独立符号；判断是否编入用
  `strings arch/arm64/boot/Image | grep 'SYSTEM_RESET2 vendor reset'`。
- **未实测**：`reboot edl`（EDL 只能 qdl 救回，需用户在场 + 备份齐）。
- **纳入默认栈**：`scripts/build-kernel.sh` 的补丁应用列表需加本目录（下一轮 D5 工作项）。
