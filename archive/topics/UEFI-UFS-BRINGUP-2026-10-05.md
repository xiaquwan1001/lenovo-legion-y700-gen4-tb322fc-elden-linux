# UEFI (G1-29 路线 A) 上机 bring-up 复盘 — 2026-10-05

> 过程证据，只增不改。结论：**壳机制成立、平台能进 BDS，但 UFS 初始化过不去**；
> 该阻塞属 Mu Pakala 移植层的系统性 bring-up 缺口，非单点补丁可解。**暂缓路线 A，转路线 C + 上游问询。**

## 1. 目标与判据

- G1-29 路线 A：自建 SM8750 可自举 UEFI 卷打包进 `boot.img`，出现 BDS/GRUB 菜单并能从 FAT 读 kernel。
- 平台：`PakalaPkg`（SM8750）；设备包 `Device/lenovo-y700g4`（本 project 提供，上游无）；
  源码 fork `xiaquwan1001/mu_wide_platforms`（源自 `sunflower2333/mu_wide_platforms`）。

## 2. 主机侧：本地编译链打通

- 工具链：clang-21 + `/usr/lib/llvm-21/bin`（含 lld-21）+ nasm + iasl + mono + aarch64-linux-gnu-gcc + nuget(rootless) + venv(py3.12)。
- **决定性变量**：`export CLANG_BIN=/usr/lib/llvm-21/bin/`（**结尾斜杠必须有**；插件 `ClangPdbToolChain` 读 `CLANG_BIN` 而非 `CLANGPDB_BIN`，缺斜杠 → `/usr/lib/llvm-21/binclang: not found`）。
- NuGet 依赖：`ext_dep.yaml` 的 `source` 指向本地目录 `pkgs/nuget/`（绕开 feed / mono TLS）。
  三个 nupkg 曾**静默截断**（`unzip -t` 报缺中央目录），用 `curl -C -` 续传循环补齐：
  `edk2-acpica-iasl.20230628.0.1`(2811804) / `mu-uncrustify-release.73.0.8`(2768185) / `mu_nasm.20016.1.1`(5019557)。
- 耗时实测：完整构建（SB+NOSB DEBUG）≈ **2m59s**；无改动增量 ≈ **17s**；CI（GitHub 4vCPU）= run 整体 9m48s。

## 3. 崩溃取证手段（本轮建立，有效）

- NOSB（`PakalaNoSb.dsc`：`USE_SCREEN_FOR_SERIAL_OUTPUT=1`）的 debug 输出经 `AndromedaPkg/Library/FrameBufferSerialPortLib` 直写 framebuffer；
  字号 = `Platforms/AndromedaPkg/Include/Resources/font5x12.h` 的 `SCALE_FACTOR`（默认 **1**，面板 1904×3040 下不可读；改 **3** → 105 列×84 行、字形 36px，可读）。
- 异常处理器 `Silicon/Arm/MU_TIANO/ArmPkg/Library/DefaultExceptionHandlerLib/AArch64/DefaultExceptionHandler.c`
  经 `gEfiDebugImageInfoTableGuid` 打印 `PC (ImageBase+offset) [n] ModuleName` 调用栈；已改为栈转储 ±64 并在末尾重印 `*** FAULT PC … [模块] ESR … FAR … ***`。
- DEBUG 版才打印（`TARGET=DEBUG` → `PcdDebugPropertyMask=0x0f`、`PcdDebugPrintErrorLevel=0x800fee0f`）。

## 4. 实验矩阵（全部 `fastboot boot`，零写盘）

| 实验 | UFSDxe | ClockDxe | 多线程 | 结果 |
|---|---|---|---|---|
| A | Mu 补丁版 | 补丁版 | 0 | ❌ `Synchronous Exception`；PC=`UFSDxe+0x13224`；Data abort/translation fault L2，X0 坏指针 FAR=X0+8 |
| B | **未打补丁** | 补丁版 | 0 | ✅ **跑到 BDS**；UFSDxe 干净 ASSERT（`ufs_error_log: 11/3b/55`、`UFS.c+2326`、Status=EFI_DEVICE_ERROR）；无可启动设备 |
| D | xiaomi-piano 版 | 补丁版 | 0 | 同 B（→ 崩溃非二进制本身，而是 Mu 补丁）|
| C | 无 | 补丁版 | 0 | ❌ 崩溃循环 |
| E | 未打补丁 | lenovo 原版 | 0 | ❌ 更早崩：到 `ArmTimerDxe` 后白屏+蓝点 |
| F | 未打补丁 | dodge 原版 | 0 | 同 E |
| G | 未打补丁 | 补丁版 | **1** | ❌ 卡在 `StartSchedulerFunc`（Mu 多线程调度器起不来）|

**最佳基线 = B/D**（`未打补丁 UFSDxe` + `补丁版 ClockDxe` + `EnableMultiThreading=0`）。

## 5. 已证实结论（根因）

1. **硬崩的元凶 = Mu 给 UFSDxe 打的补丁**（`PatchedBinaries/UFSDxe.efi`）。换未打补丁版后 `Synchronous Exception` 消失。
   反汇编定位：`UFSDxe` 函数 `0x13120` 经全局对象方法（`[.data:0x228d8]+0x40`，即 `PlatformPeiLib` 装的 ConfigLib/DTB 扩展）查 `tag==0x402` 表项，把项内 **32 位值当对象指针**解引用。
2. **`EnableMultiThreading=1` 不可用**：DxeCore 调度器 `StartSchedulerFunc` 卡死；lenovo 的 `=0` 是正确设置。
3. **原版 ClockDxe 不可用**：lenovo/xiaomi-piano/erhai/nubia 共用"补丁版 ClockDxe"（与原版差 108759 字节）；dodge 用自己的原版且 UFS 正常，但该原版放到 lenovo 会令平台更早崩 → 补丁是移植必需的。
4. **平台可达 BDS**，说明壳机制（BootShim+FD）、四代 ABL 接受度、显示、GIC/定时器等都成立。
5. **UFS 初始化失败是当前唯一硬阻塞**，且伴随一串"平台配置/服务缺失"：
   - `Failed to locate SCM protocol for Mailbox 14`
   - `ERROR: Fail to init client handle to QBSS clock node`
   - `ERROR: CPU_Vectors region not present in cfg file !`
   - `UsbBusStart: Init command not active`（USB 栈同样失败）
   → 指向 `PlatformConfigurationMapLib` / `PlatformPeiLib`(InfoBlk/ConfigLib/DTB 扩展) 提供的配置**不完整**。

## 6. 已排除

- **SMMU detach**：`MmuDetach()` 只在 SM8150/8350/8450/7150 的 `PlatformUtils.c` 调用，**SM8750 不调用**；SM8750 也无 `PcdSMMUSIDsToKeep` 覆盖 → 与本机无关。
- **内存映射/配置映射差异**：lenovo 与 oneplus-dodge 的 `PlatformMemoryMapLib.c` **逐字节相同**，`PlatformConfigurationMapLib.c` 仅差两个多线程开关；与 xiaomi-piano 亦相同。
- **设备树**：`linux-y700g4.dtb` 是 6 字节 `dummy` 占位（xiaomi-piano 同样），不是根因。
- **UFS 二进制本身**：lenovo 原版与 xiaomi-piano 版表现一致。

## 7. 未解点

- UFS init 的 Device Error 具体失败环节（vendor 二进制无源码/PDB，`ufs_error_log: 11/3b/55` 语义未知）。
- `0x402` 表项来自哪个配置源、为何其 32 位值指向未映射地址。
- 日志中 UEFI 区地址出现 `0x87600000…`（源码为 `0xA7600000…`）——疑为转写误读（`A`→`8`），未证实。
- `fastboot boot` 路径下 ABL 是否给 UEFI 留好了 UFS/SMMU 状态（对比 stock 正常引导）。

## 8. 文件清单（本轮改动 / 资产）

**源码改动（`mu_wide_platforms` fork，未提交）**
- `Platforms/AndromedaPkg/Include/Resources/font5x12.h`：`SCALE_FACTOR 1→3`（调试字号）
- `Silicon/Arm/MU_TIANO/ArmPkg/Library/DefaultExceptionHandlerLib/AArch64/DefaultExceptionHandler.c`：栈转储 ±256→±64 + 末尾重印 FAULT 行
- `MU_BASECORE`（submodule）：三处 `ext_dep.yaml` 的 nuget `source` → `pkgs/nuget/`
- `Platforms/PakalaPkg/Device/lenovo-y700g4/PatchedBinaries/UFSDxe.efi`：换为未打补丁原版（Mu 补丁版留存 `UFSDxe.efi.mu-patched-orig`）

**产出资产**
- 对照镜像 `out/local-exp/`：`expB-ufs-unpatched.img`（最佳基线）、`expC-no-ufsdxe.img`、`expD-xiaomi-ufsdxe.img`、`expE/F/G-*.img`
- 可读化基线镜像 `out/local-scale3/lenovo-y700g4_NOSB-scaleFaultline.img`
- 构建日志 `logs/local-*.log`、`logs/local-clean-build.log`

## 9. 去向（2026-10-05 决定）

1. **暂缓路线 A**（UEFI+GRUB）——UFS 未通前无磁盘可引导，继续单点实验收益低。
2. **转路线 C**（G1-30 已交付）：min initramfs + `switch_root`，boot.img 已瘦到 20.8 MiB，不依赖 UEFI，直接解体积卡死。
3. **并行上游问询**：向 `sunflower2333` / Mu-Silicium 询问 SM8750(Pakala) UFS 在 Mu 下所需的配置项（InfoBlk/ConfigLib/DTB 扩展），或是否已有可用设备包可对照。
4. **若日后重启路线 A**：优先从 `uefi-firmware-backup/`（本机原厂 UEFI 备份）提取 stock 的配置/内存映射，与 Mu 的 `PlatformConfigurationMapLib`/`PlatformMemoryMapLib` 逐项比对，补齐缺项后再验 UFS。
