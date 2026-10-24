# UEFI WoaA / Gunyah 资源包与工具链准备报告

- 日期：2026-10-24
- 目标目录：`/home/xuqianhui/y700-elden/build/uefi-woa-prep/`
- 磁盘：开始前 `df -h`（见 §9）

## 1. 结论一览
- 磁盘起点：937G 盘，已用 194G，可用 696G（df -h）。下载中/后占用见 §9。
- 5 个 Gunyah 相关仓库已确认可达（HTTP 200），含 `Droid-VM/DroidVM-Prebuilts`（搜索发现，位于 Droid-VM 组织下而非独立 org）。
- `gunyah-guest-drivers-windows` 关键词 GitHub 搜索 total_count=0（未找到公开地址）。
- 工具链：lld/mono 本机已有；iasl(20251212)/nasm(3.01)/uuid.h 经 `apt-get download` + `dpkg-deb -x` 解包到 `~/.local`（无 sudo，不能直接 apt install）；pip 经 get-pip --user --break-system-packages 安装 uefi_firmware + capstone 5.0.7。
- UEFITool 套件：UEFIExtract NE A75 / UEFIFind NE A75 x64 linux 二进制落位 tools/，实测可运行。
- 大仓库 clone 后台进行中，逐项追加 §2。

## 3. 工具链
| 工具 | 版本 | 获取方式 | 状态 |
|------|------|----------|------|
| lld | /usr/bin/ld.lld（已装） | 预装 | OK |
| iasl | 20251212-1 | apt download acpica-tools → dpkg-deb -x → ~/.local/bin | OK |
| nasm | 3.01 | apt download nasm → ~/.local/bin | OK |
| uuid-dev | 2.41.3（uuid.h → ~/.local/include） | apt download + 解包 | OK |
| mono | 预装 /usr/bin/mono | — | OK（版本待录） |
| nuget | 待办：apt download nuget 或 Mu stuart 自带 | — | 待办 |
| uefi_firmware + capstone | capstone 5.0.7 | get-pip --user --break-system-packages | OK |
| cargo/rustc (crosvm) | 待办 | rustup --user | 待办 |

> 注：本会话无 sudo（`sudo -n` 要求交互认证），apt 包均以 download+解包方式落到 `~/.local`，等效但 PATH 依赖 `~/.local/bin`。

## 4. UEFITool / UEFIExtract
- LongSoft/UEFITool release A75（2026-07-10 build），`UEFIExtract_NE_A75_x64_linux.zip` 与 `UEFIFind_NE_A75_x64_linux.zip`。
- 路径：`build/uefi-woa-prep/tools/uefiextract`、`uefifind`（3326848 B / 2865648 B）。
- 实测：`./uefiextract` 输出 `UEFIExtract NE alpha 75 (Jul 10 2026)` 使用说明 → 可执行 OK。
- sha256: uefiextract `f1b8d112838adcf741c43dbd87f3dc61f06996239e9801ae62cf46ea1cd2485a`；uefifind `0c1643e107a32580f3760c635ef1ba3145bf9178b977666869487fb15bd08a42`。

## 2. 仓库下载
| # | 仓库 | 路径 | 大小 | commit | 状态 |
|---|------|------|------|--------|------|
（逐项追加）

## 3. 工具链
| 工具 | 版本 | 获取方式 | 状态 |
|------|------|----------|------|

## 4. UEFITool / UEFIExtract
（追加）

## 5. uefi.elf 只读冒烟解析
（追加）

## 6. Win11 ARM64 ISO 渠道记录
- 官方渠道：https://www.microsoft.com/software-download/windows11arm64 （需选择下载 ARM64 ISO，约 5–6 GB）；仅记录，未下载。
- 备选：微软官方 media creation / UUP dump（uupdump.net 选 arm64 → 转 ISO）。均未下载。

## 7. 失败项与下一步建议
（追加）

## 8. 未证实 / 待办
（追加）

## 9. 磁盘占用前后
（追加）
