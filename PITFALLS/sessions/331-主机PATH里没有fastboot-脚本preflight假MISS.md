# #699 本机 PATH 里没有 `fastboot`：脚本的「工具在不在」判据会假 MISS，把整轮设备窗口挡在门外

- 日期：2026-11-21（无人值守轮次，设备 offline；主机侧发现）
- 现象：`bash scripts/android-v3-bringup-walkthrough.sh --step S5 --dry-run` 在前置校验里打印
  `MISS  fastboot` 并以 `FAIL 前置校验有缺件/缺工具` 退出（S1–S5 全被跳过）。同一台机器上
  `fastboot` 其实**在**：`/home/xuqianhui/.local/opt/platform-tools/fastboot`（v37.0.1）。
- 判据：`command -v fastboot` 空、`ls -l ~/.local/opt/platform-tools/fastboot` 有且可执行、
  `/usr/bin` 与 `/usr/lib/android-sdk/platform-tools/` 都**没有** fastboot（系统只装了 `adb` 包）。
- 成因：fastboot 是 2026-10-17 从 `dl.google.com` 下载 zip 解压到 `~/.local/opt/platform-tools`
  （无需 sudo，见 `.pi/memory/failures-kernel.md`），**从未进 PATH**；历史会话里都是显式全路径或临时 export。
  于是所有写成 `command -v fastboot` / 裸 `fastboot` 的脚本在无人值守环境里都会「工具在、判不在」。
- 为什么危险：这个 MISS 看起来像「环境没装工具」，实际是**脚本缺陷**；若在真设备窗口才撞上，
  整轮（S1–S5 / 刷件 / 验收）会白等，还容易被误判成设备侧问题。
- 处置（已落地）：
  1. 新 `scripts/lib-hosttools.sh`：`hosttool_resolve <name>`（PATH → `~/.local/opt/platform-tools` →
     `/usr/lib/android-sdk/platform-tools`）+ `ensure_hosttools`（幂等把落点目录前置进 PATH，导出
     `FB_BIN`/`ADB_BIN`，找不到也不报错）；
  2. `scripts/lib-fastboot.sh` 顶部 source 它并用 `${FB_BIN:-fastboot}` 调用（fbx/fbdevices）；
  3. `scripts/android-v3-bringup-walkthrough.sh` 前置校验改成打印**解析到的绝对路径 + 版本**
     （`OK fastboot ~/.local/opt/platform-tools/fastboot（v37.0.1）`），只有两处都找不到才 MISS。
- 副作用（登记）：前置进 PATH 后**同目录的 adb（v37.0.1）会优先**于系统 adb 34；
  两者混用时 adb server 会自报版本不符并重启一次，属预期行为（不是故障）。
- 通则：设备脚本里的「工具存在性」判据一律走 `lib-hosttools.sh`，不要写裸 `command -v fastboot`。
