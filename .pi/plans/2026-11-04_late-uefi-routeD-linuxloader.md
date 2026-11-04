# 规划 · 2026-11-04 深夜 —— UEFI 交出 Linux：路线重排（D > A > B）

> 上一轮的交接文档 = `.pi/plans/2026-11-04_handoff-uefi-dxe-to-linux.md`（结论、12 发清单、复现步骤）。
> 本文只写**复核结果**与**重排后的下一步**。设备状态：**fastboot（`HA2EXB0E`，`18d1:d00d`）**，`boot_b` 未写。

---

## 0. 一句话

今日突破**成立**（DXE 全走完 / UFS 枚举 `BlockIo=119` / 无 ESP），但交接文档给的「方案 A = 往 FD 里塞 GRUB」
**不是最省的一条**：本次主机侧核查发现 **Qualcomm 自己的 `LinuxLoader` 早就编进 FV 了**（`F536D559…`，176 KB，就在 FVMAIN 末尾），
它没被启动的唯一原因是 **`UEFI_APPLICATION` 类型的 FV 文件不会被 DxeCore dispatcher 派发**（`Dispatcher.c:73`）。
⇒ 新首选 **路线 D**：BdsDxe 里 `LoadImage`+`StartImage` 这个 FV 内应用 → 它进 UEFI 侧 fastboot → 宿主 `fastboot continue` 启 `boot_b`。

---

## 1. 今日突破的复核（按证据等级）

| 结论 | 复核方式 | 等级 |
|---|---|---|
| R10 剔除 `QRKSDxe` 后 DXE 全程走完、无异常 | 补丁 `patches/uefi/20261104R10-noqrks/0001` 存在；`DXE.inc` 里 `QRKSDxe` 已注释；manifest 与 sha 与交接表一致 | 已证（屏上原文为一次性目视，无截图存档） |
| `0xD2B9B224` = `QRKSDxe` | 单变量对照（r8 崩 / r10 不崩）+ 该驱动字符串 `ScmGetClientEnv - Fail %d` | 已证 |
| `BlockIo=119` / `SFS=1` / `SFS=modem_b` | 屏上 `[B]`/`[S]` 两行；`lun4-gpt-primary.bin` part39 = `modem_b`（`0x34180`,`0x15E00`）逐值吻合 | 已证 |
| 整机无 ESP | 119 个 BlockIo 里只有 1 个 SFS，且是 modem_b；`linux17` 是 ext4（UEFI 无 ext4 驱动 ⇒ 本来也不会出 SFS） | 已证（但**措辞要收**：准确说法是「UEFI 视野内没有 FAT 启动卷」，不是「盘上没有可放 ESP 的空位」） |
| 交接文档「本 Mu 构建不含 `QcomModulePkg`」 | ❌ **错**：`build.log:4354` 编了 `QcomModulePkg/Application/LinuxLoader`；FV 里 GUID `F536D559-459F-48FA-8BBC-43B554ECAE8D` 就在 `FVMAIN.Fv.txt` 末行（`0xC126B0`） | **本次更正** |

---

## 2. 本次新增的主机侧硬事实（都可复算）

| # | 事实 | 证据 |
|---|---|---|
| F1 | **FD 4 MiB，尾部有 1 727 675 B 空闲**（`0x25A345`–`0x400000`）；内层 `FVMAIN` 已满（`0xc3e000` 中用了 `0xc3d6e8`） | `SM8750_EFI.fd` 末个非 `0xFF` 字节 = `0x25A344` |
| F2 | arm64 GRUB **可现取可用**：USTC 镜像 `grub2-unsigned/grub-efi-arm64-bin_2.14-2ubuntu1_arm64.deb`；`grub-mkstandalone -O arm64-efi -d <解包目录>` 交叉可用；最小模块集产物 **2 093 056 B**，`xz -9` 后 **1 174 968 B** ⇒ 压进 FV 装得下（余量 ~0.5 MB） | `/tmp/grubarm64/grubaa64.efi`（本机实测） |
| F3 | **`LinuxLoader` 在 FV 里但永远不会被启动**：`Dispatcher.c:73 mDxeFileTypes[]` 只含 `DRIVER / COMBINED_SMM_DXE / COMBINED_PEIM_DRIVER / DXE_CORE / FIRMWARE_VOLUME_IMAGE`，**不含 `APPLICATION`**；`LinuxLoader.inf:19 MODULE_TYPE = UEFI_APPLICATION` | `MU_BASECORE/MdeModulePkg/Core/Dxe/Dispatcher/Dispatcher.c` |
| F4 | 树里 `LinuxLoader.c:223` 被改成 **`BootIntoFastboot = TRUE;`**（`GetKeyPress` 整段注释）⇒ 只要它被启动就进 **UEFI 侧 fastboot**（这正是上游 Mu-Silicium 在 SM8750 上「Linux Boot ✅」的形态：UEFI fastboot 收 `boot`/`continue`） | 源码 + `reference/uefi-samechip-20261028/Mu-Silicium-Status-SM8750-section.md`（dodge = Linux Boot ✅） |
| F5 | UEFI fastboot 两条启动入口都在：`CmdBoot`（`fastboot boot <img>`，内存镜像 → `LoadImageAndAuth` → `BootLinux`）、`CmdContinue`（`fastboot continue`，读**活动槽** `boot` 分区 → 同上） | `FastbootCmds.c:2854` / `:2685` |
| F6 | AVB 不会挡：`AllowVerificationError = IsUnlocked()`，解锁则带 `AVB_SLOT_VERIFY_FLAGS_ALLOW_VERIFICATION_ERROR`；`EnableMdtpSupport` 默认 `FALSE` | `VerifiedBoot.c:1105/1122`；`QcomModulePkg.dec:167` |
| F7 | `LoadImage(TRUE, gImageHandle, NULL, buf, size, &h)` 合法（`SourceBuffer != NULL` 时不要求 device path） | `MU_BASECORE/.../Image/Image.c:1243` |

---

## 3. 路线重排

| 路线 | 做法 | 新增字节 | 写盘 | 判定 |
|---|---|---|---|---|
| **D（新首选）** | BdsDxe 里 `LoadImage`+`StartImage` **FV 内现成的 `LinuxLoader`** → UEFI fastboot → `fastboot continue` 启 `boot_b` | **0** | `continue` 路径 0；`boot` 路径有 `ClearUnbootable`（写 misc 槽位元数据，ABL 每次启动也写） | 启的就是今天 ABL 启的同一份 `boot.img` ⇒ 内核/DTB/initrd/cmdline 全部零变量 |
| A（退路，交接文档首选） | GRUB standalone arm64 塞进 FV，GRUB 用 `ext2` 读 `linux17` 的 `/boot` | ~1.2 MB（F1 余量够，F2 已实测尺寸） | 0 | 多一层 GRUB + 要新写 grub.cfg + 内核参数手抄 |
| B（最后） | GPT 手术建 ESP | — | **有** | 需要备份/回退，`linux17` 有数据 |

**为什么 D 优先**：D 不引入任何新二进制、不动 FD 尺寸、不碰盘，而且**复用的就是当前每次启动都在跑的 ABL 同源代码路径**（ABL 本体 = `LinuxLoader`，见 `reports/uefi-migration-interface-20261026.md` §1.1）。A 的每一条优势 D 都有，D 还少一层。

---

## 4. R13 实施单（一发，零写盘）

### 4.1 补丁
`patches/uefi/20261104R13-loaderstart/0001-bdsdxe-start-fv-linuxloader.patch`，插在 `BdsEntry()` 里 R11/R12 那段
`[B] BlockIo / [S] SFS` 探针**之后**（同一文件、同一风格，见 `patches/uefi/20261104R12-sfsprobe/0001`）：

```
1. LocateHandleBuffer(ByProtocol, gEfiFirmwareVolume2ProtocolGuid)
2. 逐个 FV2->GetFileByGuid(&{F536D559-459F-48FA-8BBC-43B554ECAE8D}, &FileHandle)
3. Fv2->ReadSection(FileHandle, EFI_SECTION_PE32, 0, NULL, &PeSize, &Auth)  // 取长
   Fv2->ReadSection(... PeBuf, &PeSize, &Auth)                             // 取值
4. 屏上打 [L] found=1 size=0x… / [L] LoadImage=0x… / [L] StartImage=0x…
5. gBS->LoadImage(TRUE, gImageHandle, NULL, PeBuf, PeSize, &Img)   // F7 已核合法
   gBS->StartImage(Img, NULL, NULL)                                 // 不返回（进 fastboot）
```

判读（全部屏上 `\r` 单行，按 `PITFALLS #498` 不用 `\n`）：
- `[L] found=0` ⇒ FV 枚举/取文件失败（GUID 或 FV2 句柄问题），改按 `ReadFile`+walk sections。
- `[L] LoadImage=0x8000…` ⇒ PE32 取错（ReadSection 返回了别的 section）或内存不足。
- `[L] StartImage=0x…` 出现 ⇒ **LinuxLoader 返回了**，说明它内部早期失败（看它自己的屏上日志；RELEASE 下 `DEBUG()` 可能为空，所以下一步再加 `[L]` 分点探针：`DeviceInfoInit` / `EnumeratePartitions` / `BoardInit` 三处返回码）。
- **最好情况**：屏停在 fastboot UI / `Launching fastboot`，宿主 `fastboot devices` **重新出现设备**（ABL 的 fastboot 在 `fastboot boot` 时已拆掉 ⇒ 再出现必是我们的 UEFI）。

### 4.2 第二阶段（同一次上机就能做）
宿主：
```bash
fastboot devices                       # 期望 HA2EXB0E
fastboot getvar version-bootloader     # 与 ABL 口径对比，作为「这是 UEFI fastboot」的辅证
fastboot continue                      # 读活动槽 boot_b → BootLinux（不写 misc）
# 或：fastboot boot out/boot-elden-<vk>.img   （内存镜像；会 ClearUnbootable）
```
判据：屏上出现内核日志 / 主机 `ssh root@192.168.7.1` 通 / 回来后 `boot_id` 变化且 `findmnt /` = `/dev/sda17`。

### 4.3 构建命令（在交接文档模板上只换一个 `--patch`）
```bash
scripts/uefi-build-variant.sh reports/artifacts/uefi-20261104R13-r1 --scale 3 \
  --patch $PWD/patches/uefi/20261104-fixcopylen/0001-*.patch \
  --patch $PWD/patches/uefi/20261104-prepi/0001-*.patch \
  --patch $PWD/patches/uefi/20261104-dxe/{0004,0010,0013,0003,0005,0006,0007,0001}*.patch \
  --patch $PWD/patches/uefi/20261104R5-dxebase/0001-*.patch \
  --patch $PWD/patches/uefi/20261104R7-loadmap/0001-*.patch \
  --patch $PWD/patches/uefi/20261104R8-names/0001-*.patch \
  --patch $PWD/patches/uefi/20261104R10-noqrks/0001-*.patch \
  --patch $PWD/patches/uefi/20261104R13-loaderstart/0001-*.patch \
  --patch $PWD/patches/uefi/20261104R2-slow-serial/0001-*.patch
python3 scripts/uefi-repack-v2aligned.py --build-dir reports/artifacts/uefi-20261104R13-r1 -o out/uefi-20261104R13-r1.img
```
（`--patch` 必须绝对路径，`PITFALLS #501`；R11/R12 的探针**不带**，它们已完成使命，省屏。）

---

## 5. 风险与对策

| 风险 | 概率 | 对策 |
|---|---|---|
| `LinuxLoader` 早期失败（`DeviceInfoInit`/`BoardInit` 依赖 Mu 里没有的库） | 中 | 屏上返回码 + 分点探针；失败点即补点，仍比 GRUB 便宜 |
| UEFI 侧 fastboot 起不来（USB device 栈已被 UsbDeviceDxe 占） | 中 | R10 已见 `ssusb_phy_init_success`；退一步 `BootIntoFastboot=FALSE` 直启（跳过 fastboot，直接 `LoadImageAndAuth`+`BootLinux`） |
| `LoadImageAndAuth` 对 `boot_b`（我们自签的 Linux 镜像）判 AVB 失败 | 低（F6） | 解锁态允许错误；仍失败就 patch 成 `LoadImageNoAuthWrapper` |
| `BootLinux` 的 DTB 选择与 ABL 不同（dtbo 叠加） | 低 | 同一份 boot.img ABL 现在就在启；真不同则用 `fastboot boot` 内存镜像路径对比 |
| 内核起来后 UFS 控制器仍被 UEFI 初始化过 | 中 | `ufs-qcom` probe 会 reset；失败则先看屏上 dmesg，必要时 `fastboot continue` 前不做 UFS 读写 |

---

## 6. 明确不做

- 不写 `modem_b`（唯一 FAT 卷，装基带镜像）。
- 不为「塞 GRUB」去缩 `linux17`（A 路已证明 1.2 MB 压得进 FD 余量，不需要动盘）。
- 不再用 ramoops/pstore 做跨 `fastboot boot` 取证（`PITFALLS #500`）。
- 不再指望 `QRKSDxe`（SCM 客户端环境缺失，`0xD2B9B224` 已定案）。
