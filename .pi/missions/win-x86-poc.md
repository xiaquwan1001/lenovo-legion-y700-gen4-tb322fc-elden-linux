# 任务：Win x86 转译 PoC（已收官，墓碑+残余）

> 状态权威 = `TASKS.md` §2「C-历史」行（Win-x86 PoC ✅）。2026-10-04 现代化。

**主线不再执行。** PoC 成功：Ubuntu 24.04 arm64 glibc rootfs + **Pi-Apps-Coders Box64 0.4.5**（noble 自带 0.2.6 与 Wine 9 不兼容 → explorer.exe fork 风暴，教训见下）+ Wine 9 wow64；notepad/桌面无截图证据在 `archive/topics/WIN-X86-POC-2026-10-02.md`（WIN-X86-POC-*.png）。可复用脚本：`scripts/win-x86-rootfs.sh`、`scripts/win-x86-run.sh`。

## 关键护栏（若在此线上继续任何 Wine/box64 实验，必守）
设备上用 cgroup v2（`/sys/fs/cgroup/guard` 设 `pids.max`）+ `timeout -k` + trap 按 comm 名 pkill（explorer.exe/services.exe/wineserver64），防 fork 风暴拖垮设备；外部 exe 必须放进 chroot 内。

## 残余
无立项工作。游戏兼容/性能 = 未排期（用户点头才开）。

## 纪律（2026-10-04 约定）
- 最终回复即交付物（命令+原始日志）；**不改 `TASKS.md`**；证据追加 `archive/topics/win-x86-<YYYY-MM-DD>-subagent.md`。
