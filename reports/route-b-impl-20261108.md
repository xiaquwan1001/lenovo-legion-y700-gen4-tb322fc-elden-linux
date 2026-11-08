# 路线 B 实现回执 — D1 补丁 + D2 构建（2026-11-08）

## §0 结论

| 项 | 结论 |
|---|---|
| D1（ESP-first 补丁） | **PASS**（静态：编译通过、逻辑核对 GetImage 口径一致；设备侧行为未证实） |
| D2（LinuxLoader RELEASE 构建） | **PASS**（产物 176 640 B，sha256 `3a8465…2eb7a`，`.text` 0x20fa8） |

## §1 改动点

只改一处：`build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/QcomModulePkg/Library/avb/VerifiedBoot.c`
（+199 行，Mu 树 git **未提交**，diff 已留档）。

- **`LoadImageFromEsp()`（新增 STATIC，插在 `LoadImageAndAuth` 之前，约 L1660 起）**：
  - `gBS->OpenProtocol(gImageHandle, gEfiLoadedImageProtocolGuid)`（GET_PROTOCOL，自身作为 agent/controller）
    → `HandleProtocol(LoadedImage->DeviceHandle, gEfiSimpleFileSystemProtocolGuid)` → `OpenVolume`。
    前两步任一失败 → `EFI_NOT_FOUND`，静默回落。
  - 读 `\\boot\\boot.img`（必需）与 `\\boot\\dtbo.img`（可选）：`SetPosition(EOF)`→`GetPosition` 取大小 →
    `AllocatePool` → 回 0 → `Read`；填 `Info->Images[NumLoadedImages]`，`Name = "boot"/"dtbo"`
    （GetImage 用 `AsciiStrnCmp(Name, ImageName, len(ImageName))` 前缀匹配，口径一致）。
  - boot 命中后 `DEBUG((EFI_D_ERROR, "ESPBOOT: boot.img from ESP %lu bytes\n"))`；dtbo 单独一行。
  - 任何失败（boot 缺/读失败/内存不足/表满）→ `Out:` 清理全部本路径分配（Name/ImageBuffer 置 NULL、
    NumLoadedImages 归 0）、返回 `EFI_NOT_FOUND`。dtbo 失败不影响 boot 已成功的情况（不进 Out）。
- **`LoadImageAndAuth()`（L1862 附近，NULL 检查后、分区名逻辑前）**：
  `LoadImageFromEsp(Info) == EFI_SUCCESS` 即直接 `return EFI_SUCCESS`——跳过 Pname/AVB/
  DisplayVerifiedBootScreen/VBSendMilestone 全套；非 SUCCESS 则原逻辑继续（原行为零改动）。
- 无 .inf/.dsc 改动：两个 GUID 实例已由 `LinuxLoader.inf`/`BootLib.inf` [Protocols] 链接。

补丁：`patches/uefi/20261108R55-espboot/0001-verifiedboot-esp-first.patch`（头部含判据，
正文为 `git diff` 原文，可 `git apply` 复现）。

## §2 构建账

- 命令（增量，VerifiedBoot.c 重编 + 全链接）：
  ```
  cd build/uefi-woa-prep/repos/7-mu-lenovo
  ~/.local/bin/stuart_build -c Platforms/PakalaPkg/PlatformBuildNoSb.py \
    TARGET=RELEASE TARGET_DEVICE=lenovo-y700g4
  ```
  注意：`--target RELEASE` 不是该 settings 的合法参数，TARGET 用 `VAR=value` 位置参数传。
- 耗时：**23 s**（增量）；日志 `reports/artifacts/espboot-20261108/build.log`（Summary: Success，108 images verified）。
- 产物：`out/espboot-20261108/Loader.efi`，**176 640 B**，
  sha256 = `3a846511810ec76c54b3fc515aaf3f00f57706b706aa3dd21fb4bc764e12eb7a`。
- `llvm-objdump -h`：`.text` 0x20fa8、`.data` 0x9000、`.pdata` 0x628、`.reloc` 0x4e0 ✓（≤ 8 MiB ✓）。

## §3 未做与风险

1. **AVB 被整体跳过**（设计使然，自签件过不了 AVB）：ESP 路径命中时 verified-boot 屏、milestone、
   rollback 全部不执行；`/proc/cmdline` 不会有 verified-boot 相关 token。
2. **RELEASE 构建下 DEBUG 字符串被剥离**：产物里 grep 不到 `ESPBOOT`（RELEASE DebugLib 直接丢）。
   若 D5 需要串口上的固定标记，可用 DEBUG target 重编一份或依赖行为判据（cmdline `eden_bootloader=esp`）。
3. **Info->Images 生命周期**：ESP 缓冲用 `AllocatePool`（EfiBootServicesData），与原分区路径的
   `LoadImage`/`AllocatePages` 生命周期一致（BootLinux 拷到 load addr 后由 FreeVerifiedBootResource 侧释放路径管）；
   ESP 失败清理只释放本路径分配，NumLoadedImages 归 0，不影响回落路径从 0 重新填表。
4. **85 MB 大文件走 AllocatePool**：boot.img 85.6 MB 单块 pool 分配，依赖 UEFI 内存池碎片状况；
   失败会静默回落分区路径（安全方向）。
5. **dtbo 覆盖语义**：ESP 路径只填表，dtbo 的 overlay 应用仍由 BootLinux 的
   `LoadAndValidateDtboImg`（GetImage "dtbo"）复用；`\boot\dtbo.img` 不存在时 dtbo 校验失败、
   overlay 跳过——与 dtbo 分区缺失场景同语义，需 D5 确认设备树无 overlay 也无碍（p58 时代 dtbo 正常）。
6. `gImageHandle` 在 AvbLib（MODULE_TYPE=BASE）中经 UefiBootServicesTableLib 拿到的是**链接宿主
   （LinuxLoader 应用）的 image handle**，DeviceHandle 即 GRUB chainload 时 ESP 卷，符合预期；未在真机验证。

## §4 交给总管的设备侧步骤（D3–D5，我不执行）

1. **D3**：ESP 上放 `\boot\boot.img`（= `out/boot-elden-vk184.img`，85.6 MB，sha 前后核对）+
   可选 `\boot\dtbo.img` + `\boot\cmdline.txt`（`eden_bootloader=esp`）；`fsck.fat` 干净、`mdir` 可见。
2. **D4**：`\EFI\elden\Loader.efi` ← 本报告产物（先记 sha256）；`grub.cfg` 加
   `chainloader ($root)/EFI/elden/Loader.efi` 条目。
3. **D5**：`fastboot boot` p59 世代 `SM8750_EFI.fd`（本轮未改固件，不需要重刷 uefi_a）→ 菜单选 B 项 →
   `scripts/uefi-boot-trial.sh` VERDICT；判据 `/proc/cmdline` 含 `eden_bootloader=esp`、`findmnt /` = `/dev/sda17`、
   `boot_b` sha 前后不变。失败回退：删 ESP 新文件 / 菜单选 A 项 / 断电重启回 boot_b（fallback 已验证）。
4. 若需要串口 `ESPBOOT` 标记：用 DEBUG target 重编（`TARGET=DEBUG`，其余同 §2 命令）。
