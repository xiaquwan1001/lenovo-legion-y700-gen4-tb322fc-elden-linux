# 任务：Win x86 转译 PoC（glibc 环境 + Box64 + Wine）

你是 y700-elden 的转译可行性工程师。**先读** `WIN-X86-2026-10-02.md`（上一轮调研结论）、`INDEX.md`。

## 上一轮结论
- 本机宿主是 **musl 1.2.6，无 glibc**；Box64/FEX/Hangover/Steam 全是 glibc 生态。
- **一切方案第一步：建 glibc aarch64 rootfs**（chroot/LXC/proot）。
- 首选 **Box64(DynaRec NEON) + Wine(wow64)**；图形栈（Adreno 830 / Turnip / Vulkan 1.4）通路已成立；无 AVX（Box64 默认模拟暴露）；无 /dev/kvm 不影响用户态 JIT。

## 目标
把上一轮的方案**推进到可运行 PoC**：在设备上用一个 **glibc aarch64 环境**跑通 **Box64 + Wine**，并运行一个最小的 Windows x86 程序（如 notepad / 一个 Win32 hello world / `winecfg`）。

## 步骤建议
1. **构建 glibc aarch64 rootfs**（主机侧）：`debootstrap --arch=arm64` + `qemu-user-static`（主机是 x86_64，可交叉构建）；或直接用 Ubuntu/Debian arm64 最小 rootfs。产出可 chroot 的目录。
2. 部署到设备（放 `sda17` 剩余空间），用 **proot 或 chroot** 进入（宿主 musl，注意 `env -u PYTHONPATH` 等）。
3. 安装 **Box64**（预编译 aarch64 或源码构建）与 **Wine wow64**（或 Hangover 单 tar）。
4. 跑最小 Win x86 程序，记录是否成功、报错、性能。
5. 若 chroot 受限，退回 **LXC**；记录每一步的阻塞。

## 交付物
- 文档 `WIN-X86-POC-2026-10-02.md`：环境构建步骤、部署命令、PoC 结果、下一步（Steam/游戏）。
- 可复用脚本 `scripts/win-x86-rootfs.sh`（构建 rootfs）与运行包装脚本。
- 结论写 `task progress` / `task done`。

## 设备纪律
- 大部分是**主机侧构建**，不占设备；在设备上跑 PoC 时会占 CPU，先 `send SageYak` 报备（避免与音频刷 boot 冲突）。
- 不刷机、不动 boot；设备上只写 `sda17` 的工作目录（建议 `~/` 或专用目录），用完可清理。
- SSH 禁长 sleep，后台任务 `nohup ... &` 后短命令轮询。

## 上一轮进度（2026-10-02，勿重做）
- **阶段A 已完成**：Ubuntu 24.04 arm64 glibc rootfs 已构建并部署到设备 `/root/glibc-rootfs`（sha256 校验 OK）；bind-mount `/dev /proc /sys /dev/shm /run` 后 chroot 验证：`ldd`=glibc 2.39（非 musl）、`uname -m`=aarch64。
- **接续**：直接进入阶段B——在 chroot 内装 **Box64(DynaRec NEON)** + **Wine wow64**（或 Hangover 单 tar），跑最小 Win x86 程序并记录结果。
