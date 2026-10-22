# Mu-Silicium 参考快照（Project Mu UEFI for ARM64 · SM8750 路径）

> 2026-10-22 拉取。`github.com/Project-Silicium/Mu-Silicium`，**main = `42fe5637`**（2026-10-21）；
> 其设备二进制子模块 `Project-Silicium/Device-Binaries`，**main = `a1501e0c`**（2026-10-04）。
> 本目录只留小件（12 KB）；仓库本体（展开 229 MB）与设备二进制按需外取，**不入库**。

## 1. 这是什么

基于 **Microsoft Project Mu** 的 ARM64 自制 **UEFI 固件**，目标是让手机/平板经 UEFI 启动 Windows 或 Linux（AArch64）。
上游依赖 WOA-Project `mu_andromeda_platforms` 与 Project-Aloha `mu_aloha_platforms`；设备二进制按机型放在
`Device-Binaries/<codename>/`（预编译 DXE，**不在 Mu-Silicium 源码树里**）。

许可：`Mu-Silicium` 除 `GPLDrivers`/`GPLApplications`/`GPLLibrary` 外为 **BSD-2-Clause**；GPL 目录为 GPLv2+。
设备二进制按其各自来源（原厂固件 + 补丁），**只作引用，不 vendor**。

## 2. 与本项目（G1-29 路线 A，已搁置）的关系

本仓 `archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md` 的判定是：
用 **`sunflower2333/mu_wide_platforms`** 的 `Platforms/PakalaPkg/Device/lenovo-y700g4/` 能编出 boot.img、能进 BDS，
但 **UFS 初始化过不去**（`ufs_error_log: 11/3b/55`、`UFSDxe` `EFI_DEVICE_ERROR`），
且换用其 `PatchedBinaries/UFSDxe.efi` 后升级为 `Synchronous Exception`（`UFSDxe+0x13224`）。
上游（mu_wide_platforms#12）回复：**与固件版本相关，需要 UFSDxe 专用补丁**。

**本轮新取证：这个「专用补丁」在 Project-Silicium 侧已经存在，且有 SM8750 设备实测在用。**

| 事实 | 证据 |
|---|---|
| Mu-Silicium `Status.md` 的 **Snapdragon 8 Elite（= SM8750）** 段有 **OnePlus 13（`dodge`）**：Display ✅ / Internal Storage ✅ / USB Device Mode ✅ / Mass Storage ✅ / **Linux Boot ✅** | `Status.md`（仓库内），Linux 侧配 `index986/sm8750-mainline`，有 pmOS wiki 页 |
| `dodge` 的 UFS 驱动用的是 **打过补丁的二进制** `UFSDxe.patched.efi`（`UFSDxe.inf` 里 `PE32|UFSDxe.patched.efi|*`） | 本目录 `UFSDxe.inf` |
| 补丁内容（原文，`Device-Binaries/dodge/README.md`）：「**The UFS Sleep call has been Replaced with the UFS Wakeup Call**」「**Force UFS Link Wake Up Function to run before Gear Check**」，作者 Kancy Joe(`sunflower2333`) & N1kroks | 本目录 `dodge-binaries-README.md` |
| 同 README 另外记录了为「UEFI 不崩」而打的 Buttons/Pmic/Spmi/QcomCharger/TzDxeLA 补丁，以及 UsbConfig/UsbMsd 补丁 | 同上 |

**为什么这条正好对症**：我们失败在 **UFS link/gear 阶段**（`ufs_error_log: 11/3b/55` 记在 `UFS.c+2326`，属 link/gear 阶段失败），
而「先强制 link 唤醒再 gear check、把 sleep 换成 wakeup」正是该阶段的修法。我们当时试的是 **mu_wide_platforms 自己那版**
`PatchedBinaries/UFSDxe.efi`（另一套补丁，反而把 32 位配置值当指针解引用 ⇒ 硬崩），**不是这一版**。

### 二进制对照（2026-10-22 实测下载，未上机）

| 文件 | 大小 | sha256 |
|---|---|---|
| `Device-Binaries/dodge/QcomPkg/Drivers/UFSDxe/UFSDxe.efi`（未打补丁） | 151552 | `0b32d9244c945d8c4105142f1a8dafb02f7cc29d37cca6e7e1973465add41aac` |
| `Device-Binaries/dodge/QcomPkg/Drivers/UFSDxe/UFSDxe.patched.efi`（dodge 在用） | 155648 | `e76b555f7c855784cc03303ae1044c69b24f04f214a320a8e2ea101b4f3c85ef` |

取件（任选其一，均无需凭据）：
```sh
# 直链
curl -L -o UFSDxe.patched.efi \
  https://raw.githubusercontent.com/Project-Silicium/Device-Binaries/main/dodge/QcomPkg/Drivers/UFSDxe/UFSDxe.patched.efi
# 或按 sha256 校验后使用
sha256sum UFSDxe.patched.efi   # 期望 e76b555f…3c85ef
```

## 3. 若要重开 G1-29（最小重试配方，**未执行**）

前置：本机**已无** `mu_wide_platforms/`（1.0 G）、`uefi-firmware-backup/`（1.3 G）、`edk2-gunyah*/` ——
2026-10-17 换机未随迁（`RESOURCES/README.md` §1.6 的「已落盘」需按此更正）。重试需重新拉取。

1. 重取 `sunflower2333/mu_wide_platforms`（含 `Platforms/PakalaPkg/Device/lenovo-y700g4/`）；
2. 沿用上次的**最佳基线 B/D**：`未打补丁 UFSDxe` + `补丁版 ClockDxe` + `EnableMultiThreading=0`；
3. **只把 UFSDxe 换成上表的 `UFSDxe.patched.efi`**（即 dodge 那版，先校验 sha256），保留 `UFSDxe.efi.mu-patched-orig` 备回退；
4. 主机侧 `./build_uefi.py -d lenovo-y700g4`，设备侧 `fastboot boot`（**零写盘**），看是否越过 gear check 到 BDS；
5. 判据：`ufs_error_log` 消失 / 出现 `SimpleFileSystem` 句柄 / 能列出分区；否则抓 NOSB（`PakalaNoSb.dsc`）帧缓冲串口日志。
6. 另可对照 `dodge` 的 `Resources/DTBs/dodge.dts`（46660 行，含完整 `ufsphy_mem@1d80000` / `ufshc@1d84000` 与 PMIC 供电）
   与我们的 `linux-y700g4.dtb` 在 UFS/PHY/regulator/clock 上的差异。

## 4. 构建侧事实（避免踩坑）

- Mu-Silicium 源码树**不能单靠 tarball 构建**：`.gitmodules` 依赖 `Common/Mu`(mu_plus)、`Common/Mu_OEM_Sample`、`Mu_Basecore`(mu_basecore)、
  `Binaries`(Device-Binaries)、`Silicium-ACPI` 等子模块；`Silicon/Qualcomm/PakalaPkg` 本身只有 **4 个文件**
  （`PakalaPkg.dsc.inc` + `PlatformSecLib`），真正的 SoC 支持在 `Mu_Basecore` / 预编译二进制里。
- 构建入口：`build_uefi.py`、`setup_env.sh`、`build_active_devices.sh`，文档 `Building.md`；端口指南在
  `github.com/Project-Silicium/Guides`。
- `Platforms/OnePlus/dodgePkg/` 是**可抄的模板**：`dodge.{dec,dsc,fdf}` + `Include/{APRIORI,DXE,RAW}.inc` +
  `Library/{ConfigurationMapLib,MemoryMapLib}` + `DeviceBuild.py`；`Resources/Configs/dodge.toml` 记录
  BootShim 参数（`uefi_fd base=0xA7100000 size=0x300000`）与 Android boot header 版本。
- 另有 `Silicon/Qualcomm/QcomPkg/Drivers/DisplayReEnablerDxe`（ExitBootServices 前把显示 off→on 一次）、
  `Applications/MassStorage`、`Library/ArmSmmuDetachLib` 等**源码可用**的小驱动，值得在自研引导层里参考。

## 5. 结论

- SM8750 在 **Mu + Project-Silicium** 体系下**已能进 Linux 且内部存储可用**（OnePlus 13 实测），与我们 2026-10-05 的失败结论
  **不矛盾**——差别就在 **UFSDxe 的补丁版本**。
- 因此 G1-29 从「Mu Pakala 移植层系统性缺口」应**降级为「换一个 UFSDxe 二进制再试一次」**（仍需真机零写盘验证，未做）。
- 其余 Mu-Silicium 内容（`PakalaPkg`/`dodgePkg`）价值在**模板与配置**，不在可直接复用的产物。
