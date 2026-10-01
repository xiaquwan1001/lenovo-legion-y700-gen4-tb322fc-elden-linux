# 任务：探究 Linux 上转译运行 Windows x86 的可行性（以 Steam 为例）

你是 y700-elden（联想拯救者 Y700 四代 TB322FC / SM8750 / Adreno 830 / 8GB RAM）主线 Linux 项目的一名专项研究员。工作目录 `~/y700-elden`，先读 `INDEX.md` 了解项目。**本任务以调研 + 方案为主，不改内核、不刷机。**

## 目标
评估在这台 **ARM64 + Alpine/Phosh(drm/wayland) + Adreno 830** 设备上，运行 **Windows x86_64 游戏（以 Steam 为起点）** 的可行路径与最佳方案。

## 必须覆盖的候选路径（逐一给出优劣、依赖、预期性能损失）
1. **Box64 + Wine**（box86/box64 + wow64）、**Hangover**（Wine arm64ec + box64/qemu）
2. **FEX-Emu**（x86_64→arm64 JIT）及其 Wine/Proton 集成
3. **QEMU user-mode (qemu-x86_64) + Wine**（慢但通用）
4. **Proton/Wine 的 ARM64EC 路线**（如 FEX 驱动的 "Proton for ARM"）
5. 图形栈：**DXVK/VKD3D-Proton + Turnip(freedreno)** 在 Adreno 830 上的成熟度；Gamescope；是否可用 Waydroid + Winlator 作为取巧路径（本机已有 Android 容器）
6. 已知硬约束：AVX/AVX2 缺失、反作弊/DRM、32 位支持、内存带宽与 8GB 上限

## 交付物
- 文档 `WIN-X86-2026-10-02.md`（写在 `~/y700-elden/`），包含：
  - 一张**排序后的方案表**（方案 / 依赖包 / 预期性能 / 风险 / 落地难度）
  - 明确的 **PoC 最小验证计划**：在设备上跑通 1 个 x86 Windows 小程序或 Steam 安装器 的具体命令序列
  - "先做哪一步、验证标准是什么"
- 尽量准备**离线可用的软件包/源码**（主机侧下载好 aarch64 包或 build 脚本），但不要现在就在设备上批量安装。

## 约束
- 只读/调研为主；不刷机、不重启设备、不改内核。
- 查资料用 web_search / web_fetch；社区已有方案优先，避免重复造轮子。
- 结论与证据写入 `task progress` / `task done`（协调者只看任务板）。
- 完成后立即 `task done` 并退出。
