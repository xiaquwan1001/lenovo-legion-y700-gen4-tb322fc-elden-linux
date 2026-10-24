# UEFI WoaA / Gunyah 资源包与工具链准备报告

- 日期：2026-10-24
- 目标目录：`/home/xuqianhui/y700-elden/build/uefi-woa-prep/`
- 磁盘：开始前 `df -h`（见 §9）

## 1. 结论一览
- **6 个仓库全部落地**（含搜出的 Droid-VM/DroidVM-Prebuilts；gunyah-guest-drivers-windows 未找到公开地址），合计约 2.0G，磁盘净增 ≈3G（937G 盘：194G→197G）。
- 直连 GitHub 下载仅 ~30KB/s，改走 `gh-proxy.com` 镜像后 git clone 全部成功（详见 §2）。
- 工具链：lld/mono(6.14.1) 预装；iasl(20251212)/nasm(3.01)/uuid.h 经 apt download+解包落 `~/.local`（无 sudo）；pip --user 装 uefi_firmware + capstone 5.0.7；rustup 装 cargo/rustc 1.99.1。nuget apt 无候选（见 §7）。
- UEFITool 套件：UEFIExtract/UEFIFind NE A75 x64 linux 落位 tools/，实测可运行。
- uefi.elf 冒烟解析 OK：FV@0x1000，内嵌 LZMA FV 4247552 B，DxeCore 等可枚举（§5）。

## 3. 工具链
| 工具 | 版本 | 获取方式 | 状态 |
|------|------|----------|------|
| lld | /usr/bin/ld.lld（已装） | 预装 | OK |
| iasl | 20251212-1 | apt download acpica-tools → dpkg-deb -x → ~/.local/bin | OK |
| nasm | 3.01 | apt download nasm → ~/.local/bin | OK |
| uuid-dev | 2.41.3（uuid.h → ~/.local/include） | apt download + 解包 | OK |
| mono | 6.14.1（预装 /usr/bin/mono） | — | OK |
| nuget | 无候选版本（`apt-get download nuget` → E: 没有候选版本） | FAIL | 见 §7 |
| uefi_firmware + capstone | capstone 5.0.7 | get-pip --user --break-system-packages | OK |
| cargo/rustc (crosvm) | cargo/rustc 1.99.1（rustup --profile minimal --user） | OK |

> 注：本会话无 sudo（`sudo -n` 要求交互认证），apt 包均以 download+解包方式落到 `~/.local`，等效但 PATH 依赖 `~/.local/bin`。

## 4. UEFITool / UEFIExtract
- LongSoft/UEFITool release A75（2026-07-10 build），`UEFIExtract_NE_A75_x64_linux.zip` 与 `UEFIFind_NE_A75_x64_linux.zip`。
- 路径：`build/uefi-woa-prep/tools/uefiextract`、`uefifind`（3326848 B / 2865648 B）。
- 实测：`./uefiextract` 输出 `UEFIExtract NE alpha 75 (Jul 10 2026)` 使用说明 → 可执行 OK。
- sha256: uefiextract `f1b8d112838adcf741c43dbd87f3dc61f06996239e9801ae62cf46ea1cd2485a`；uefifind `0c1643e107a32580f3760c635ef1ba3145bf9178b977666869487fb15bd08a42`。

## 2. 仓库下载
- 初次直连 clone 实测过慢（`AnyLaySys/edk2-aarch64-gunyah` 直连 ssh，22 min 仅 22M，全部仓库合计约 800M 无法接受）；实测 GitHub 直连下载 ~30KB/s（UEFIExtract zip 819232 B / 26.1s）。
- 改走镜像 `https://gh-proxy.com/` 前缀的 git clone（验证支持 smart protocol；codeload tarball 实测 156,504,064 B / 90s ≈ 1.7MB/s）。已杀掉原直连进程（pid 947458/947463，确认无残留），重新执行脚本 `repos/clone2.sh`（每仓 `timeout -k 30 7200`）。全部 rc=0，日志 `repos/clone2.log`。

| # | 仓库 | 路径 | 大小 | commit | 状态 |
|---|------|------|------|--------|------|
| 1 | AnyLaySys/edk2-aarch64-gunyah | repos/1-edk2-aarch64-gunyah | 1.5G | `ebd28432ed3f2b2f5c995667b8d7599ba5b21463`（2026-08-31） | OK；`ArmVirtPkg/ArmVirtGunyah.dsc`+`.fdf`、`OvmfPkg/QemuRamfbDxe` 均在 |
| 2 | Droid-VM/edk2-gunyah | repos/2-Droid-VM-edk2-gunyah | 1.8M | `90c4d52c7d11485318bbb4fb9291a15ea1550ab2`（2026-10-10） | OK；`GunyahPkg/GunyahKernel.dsc` 在；README 列明 "Lenovo Y700 Gen4 (codename \"tb322fc\", with SM8750)" |
| 3 | qemu-gunyah/edk2-gunyah-qemu | repos/3-edk2-gunyah-qemu | 165M | `50c9eb78fa17d012bf850bcb4d06422f850a3126`（2026-03-31） | OK；ArmVirtPkg 含 GunyahIoMmuDxe / GunyahRestrictedDmaPoolAcpiDxe 等 |
| 4 | karim-manaouil/qemu-for-gunyah | repos/4-qemu-for-gunyah | 198M | `9248d80ced293fdee0a84d2780808c30c2d0dfba`（2025-02-25） | OK；`accel/kvm/gunyah.c`、`include/system/gunyah.h`、`hw/intc/arm_gicv3_gunyah.c` 确认 KVM API→Gunyah hypercall 线 |
| 5 | sunflower2333/mu_wide_platforms | repos/5-mu_wide_platforms | 6.4M（sparse） | `3e1d052064beb6e59cda3cfba87d50e6cc088174`（2026-10-01） | OK（见 2.5） |
| 6 | Droid-VM/DroidVM-Prebuilts | repos/6-DroidVM-Prebuilts | 148M | `c4998e150a08f0e60d141591fd63ea0010eb4f75`（2026-09-12） | OK；GitHub 搜索发现其位于 Droid-VM 组织下（任务文本猜的独立 org `DroidVM-Prebuilts` 404）；含 `prebuilt-arm64-v8a.tar.xz`（72M，json 内含 `usr/bin/crosvm`） |
| 7 | gunyah-guest-drivers-windows | — | — | — | **未找到公开地址**：GitHub 搜索 `gunyah guest drivers windows` total_count=0；`gunyah drivers` 仅命中 CodeLinaro 内核驱动镜像。Droid-VM/edk2-gunyah 内有 Windows 相关补丁（如 `0004-SsdtSerialPort-...-for-Windows-SerPL011.patch`），但独立 Windows guest driver 仓未见 |

### 2.5 mu_wide_platforms（sparse checkout，先完成）
- 路径：`build/uefi-woa-prep/repos/5-mu_wide_platforms`（`--depth 1 --filter=blob:none --sparse`）
- commit：`3e1d052064beb6e59cda3cfba87d50e6cc088174`（2026-10-01），大小 6.4M，21736 文件
- 目标文件已取得：
  - `Platforms/KaanapaliPkg/Device/oneplus-plk110/PatchedBinaries/UFSDxe.efi`
  - `Platforms/IstariPkg/Device/qcom-mtp8996/Binaries/QcomPkg/Drivers/UFSDxe/UFSDxe.efi`
- 注：该仓目录结构与预期不同——`PatchedBinaries` 在设备子目录下，不存在仓库根级 `PatchedBinaries/`；sparse-checkout 按实际路径设置，无需整 clone。

## 3. 工具链
| 工具 | 版本 | 获取方式 | 状态 |
|------|------|----------|------|

## 4. UEFITool / UEFIExtract
（追加）

## 5. uefi.elf 只读冒烟解析
- 文件：`~/下载/tb322fc/uefi.elf`，5242880 B（5 MB），ELF64 EXEC，sha256 前缀 `fc68d2f91a71372290`。
- 工具：uefi_firmware（uefi-firmware-parser CLI，A75 配套 pip 版）。
- 结果（`uefi-firmware-parser -b` 只读）：
  - `Found volume magic at 0x1000`，FV FFS2 size 0x2a8000 (2785280 B)；
  - File 1 = SEC（security core，TE section）；File 2 = `uefiplat.cfg`（freeform/raw）；
  - File 3 内 Guid-Defined section（ee4e5898-3914-4259-9d6e-dc7bd79403cf，LZMA）解出内嵌 FV 631008b0-b2d1-410a-8b49-2c5c4d8ecc7e，size 0x40d000 (4247552 B)，含 DxeCore（d6a2cb7f-6a18-4e2f-b43b-9920a733700a，192560 B PE32）及 EnvDxeEnhanced/RscRtDxe 等驱动。
- 结论：解析链路 OK（ELF 外壳需手工定位 FV 偏移 0x1000；AutoParser 直接吃 ELF 报 unknown）。未做 dump/解包写入（只读）。

## 6. Win11 ARM64 ISO 渠道记录
- 官方渠道：https://www.microsoft.com/software-download/windows11arm64 （需选择下载 ARM64 ISO，约 5–6 GB）；仅记录，未下载。
- 备选：微软官方 media creation / UUP dump（uupdump.net 选 arm64 → 转 ISO）。均未下载。

## 7. 失败项与下一步建议
- **直连 GitHub 慢**（~30KB/s，原因未深查，疑出口链路限速）：已改走 `gh-proxy.com` 镜像，5 仓全部成功。后续 GitHub 大流量下载建议默认加该前缀。
- **nuget 无 apt 候选**：Ubuntu 源未收录。建议：① `dotnet` 路线（Mu stuart 在 Linux 上主要靠 pip：`pip-requirements.txt`，nuget 仅个别 CI 用）；② 需要时从 https://aka.ms/NuGetCLI 装 mono 版单文件。当前不阻塞。
- **python3-venv 不可用**（ensurepip 缺失）：已用 `python3 get-pip.py --user --break-system-packages` 替代，包落 `~/.local`。
- **gunyah-guest-drivers-windows 未找到**：下一步建议翻 `Droid-VM/DroidVM-Prebuilts` 的 json/issue 与 AnyLaySys 仓 README 的驱动说明，或直接从 Qualcomm distributions（qpm）拿 Windows 驱动包。

## 8. 未证实 / 待办
- `ArmVirtGunyah.dsc` 是否真能 build 出 WoaA 可引导固件：仅确认文件存在，未跑 stuart/build（属后续构建任务）。
- `prebuilt-arm64-v8a.tar.xz` 内 crosvm 是否含 SBSA UART / PmReset 补丁：json 确认含 `usr/bin/crosvm`，二进制内补丁未解包验证。
- Win11 ARM64 ISO 实际体积未实测（仅记录渠道，官方页约 5–6 GB，以页面为准）。
- 直连 GitHub 慢的根因（运营商 QoS / 代理规则）未取证。
- 5 号仓 sparse 的 `Binaries/` 目录实际未包含根级补丁二进制（该仓无根级 PatchedBinaries），目标文件已从设备子目录取得；如需其他设备的 UFSDxe 版本需扩大 sparse 范围。

## 9. 磁盘占用前后
- 开始前：`df -h` → 937G 盘，已用 194G，可用 696G。
- 全部完成后：已用 197G，可用 693G（净增 ≈3G，主要 1/3/4/6 号仓 + rustup）。
