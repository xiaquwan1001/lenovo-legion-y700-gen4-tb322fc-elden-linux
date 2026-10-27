# UEFI 线：拟定的「对照实验」失效 + 取得两条新事实（2026-10-27）

日期：2026-10-27 21:40–22:00　设备：`HA2EXB0E`（U2，在机 vk172 / Debian 根，`192.168.7.1`）
性质：**零写盘**（SSH 只读 + 主机侧源码/二进制静读）。结论对 `TASKS/README.md` §4 N1、§5 Q25 是**输入**，不改既有裁决。

## 0. 结论（先数字）

| 项 | 结果 |
|---|---|
| 原定对照件 `Droid-VM/edk2-gunyah` | ❌ **不成立，方案作废**：它是 **crosvm guest 固件**，不是裸机 UEFI 载荷，不能 `fastboot boot` |
| `UEFI_BASE=0xFF300000` 是否可用 RAM | ✅ **ABL 真值证实可用**：`Final RAM Partitions` 明确列 `Add Base 0xFF300000 / Available Length 0x500000`（5 MiB ≥ `UEFI_SIZE` 4 MiB）⇒ 「候选 1：拷贝目标不在普通内存」在**内核启动路径**上被削弱 |
| Mu 是否有「已知能裸机跑到 BDS」的同 SoC 参照 | ❌ **没有**：Pakala(SM8750) 5 个设备包（含本机）在上游状态表中**一行都没有**；本机设备包来自 `nubia-nx789j` 同代提取 |
| Mu 早期可见性通道 | ❌ **无**：`USE_UART_{GENI,DM}_FOR_SERIAL_OUTPUT=0`、无 `UsbSerial*Dxe`；NoSb 变体只有 `USE_SCREEN_FOR_SERIAL_OUTPUT=1`（屏幕输出依赖 GOP，GOP 在 DXE，PrePi 期不亮） |
| 新发现的取证通道 | 🟡 **ABL 日志可得（本次已取到）**，但**每次启动重写** ⇒ 交棒失败后回落 stock 会把那次日志覆盖 |
| 裁决 | **维持搁置**；复起的真实前置 = 硬件串口 或 上游 issue #12 给出层级答案（不是再编一版固件） |

## 1. 作废的方案（我上一轮的建议有误，撤回）

上一轮建议「用 `build/uefi-woa-prep/repos/2-Droid-VM-edk2-gunyah` 出一个已知能在 tb322fc 跑的 EDK2 载荷做 `fastboot boot` 对照」。**复核源码后该方案不成立**：

| 证据 | 内容 |
|---|---|
| `GunyahPkg/GunyahKernel.dsc:237` | `gArmTokenSpaceGuid.PcdFdBaseAddress\|0x80000000`（crosvm 的 guest 内存基址，非裸机 FD 基址） |
| 同上 `:228-229` | `PcdSystemMemoryBase=0x80000000`、`PcdSystemMemorySize=0x0`（由虚拟 DT 给） |
| `:69` | `VirtioMmioDeviceLib` —— 设备全部来自 virtio-mmio（crosvm），**无** UFS/SCM/PMIC/NPA/HWIODxe |
| `:220` | 「NS16550A UART」= **模拟串口** |
| README「Tested platforms: Lenovo Y700 Gen4 (tb322fc)」 | 语义 = 在**该机 Android 宿主上用 crosvm+Gunyah 起 VM** 时固件可用；不是裸机自举 |

⇒ 它连一个 DXE 平台初始化都没有，裸机 `fastboot boot` 必然立刻死，**无法把「打包/交棒」与「Mu 平台支持」分开**。原计划的判据（出画面/usb 枚举）对它永远为假，做了只会产生假阴性。

## 2. 新事实一：`0xFF300000` 是 ABL 眼里的可用 RAM（5 MiB）

`scripts/abl-log.sh`（本次新增）取到本机 ABL 完整日志，其中 ABL 为 `fastboot boot` 生成的 RAM 分区表含：

```
Add Base: 0x00000000E3720000 Available Length: 0x00000000100E0000
Add Base: 0x00000000FF300000 Available Length: 0x0000000000500000   ← UEFI_BASE
Add Base: 0x0000000880000000 Available Length: 0x000000002F700000
```

- 与在机 Linux 侧 `System RAM` 一致（`ff300000-ff7fffff : System RAM`）。
- ⇒ 2026-10-26 报告里「剩余候选 1：`stp` 拷贝地址在 MMU/cache 状态下不可用」**证据权重下降**（不能说死，因为该表是给内核镜像算的，`fastboot boot` 载荷路径未单独取到；但地址本身不是保留区/设备区）。
- 同时 `bootshim.UEFI_BASE` 在 `build_cfg/sm8750.json` 与 `sm8850.json` 里**同为 0xFF300000** ⇒ 与活跃开发的 Kaanapali 线共用同一约定，非本机独有魔数。

## 3. 新事实二：ABL 日志可读，但救不了失败那一次

- 通道：`/dev/sde68`（`logfs`，FAT12，卷标 `LOGFS`，内含 `UEFILOG1.TXT` 64 KiB），覆盖 **PBL 时间戳 → XBL → ABL（`Launching fastboot`、`Cmdline`、`Final RAM Partitions`）→ `Start EBS` 交棒**。
- **限制定量**：本次取到的内容就是「本次 `fastboot boot out/boot-elden-vk17x.img` → Linux vk172」这一次启动（591 行 / ~30 KiB，单文件、单个 `Format:` 头 ⇒ **每次启动重写**）。
  ⇒ 交棒失败后设备回落 stock Android（10-26 实测 ~82 s）本身就是一次新启动，**那次 ABL 日志已被覆盖**。
- ⇒ 该通道可用于：核实 RAM 表真值、核实 ABL 是否真的按预期交棒、核实 cmdline/slot 状态；**不可用于**给「载荷死在哪」取证。
- 复用命令：`scripts/abl-log.sh`（`-g '正则'` 过滤 / `-o 文件` 落盘 / `-p /dev/sdXN` 换分区）。

## 4. 所以「可见性」才是这条线的唯一门槛

| 方案 | 可行性 | 成本 |
|---|---|---|
| Mu `DEBUG` 构建 + UART | 需**物理串口**（SM8750 调试 UART，要拆机/找测试点） | 高（硬件动作，用户侧） |
| Mu 屏幕输出（NoSb 已有 `USE_SCREEN_FOR_SERIAL_OUTPUT=1`） | 依赖 GOP ⇒ 必须活到 DXE；而当前正是死在 DXE 之前，**逻辑上不可能提供早期证据** | — |
| Mu `UsbSerial` | 上游 Pakala/通用包里**没有该驱动**（`rg -i usbserial` 仅命中 QcomModulePkg 的 ABL 代码） | 要自己写 DXE，且在 PrePi 期也用不上 |
| 标记位 + warm reset + 读 RAM | DRAM 经 PBL 重新训练，内容不可保 | 不可靠 |
| 等上游 issue #12 | 作者口径「firmware version dependent，需 UFSDxe 专用补丁」 | 0（但 0 回复已 ~17 天） |

**结论**：在拿到串口之前，任何新的 Mu 镜像实验都只能是「黑箱二值」，且现有两个黑箱结果都是「零可见」。⇒ 与 2026-10-21/10-24 的裁决一致：**不重启**。

## 5. 仍然值得做（10 分钟，零成本，非阻塞）

把 2026-10-21 就挂着的回帖发给上游 `sunflower2333/mu_wide_platforms#12`，内容包括三条本机实测结论：
1. `0x402` 不是 `PlatformConfigurationMapLib` 的 config tag（运行期注册表条目类型字段）；
2. `UFS_BASE` 侧 `0xFF300000` 在 ABL RAM 表中可用（排除「装载地址」一类误判）；
3. 裸机当前**完全无早期可见性**（UART=0、无 UsbSerial、屏幕输出依赖 GOP）⇒ 「需要 UFSDxe 专用补丁」的答复无法在本机验证，请给**层级判据**（例如 DEBUG 构建下应看到哪一行）。

## 6. 产物

- `scripts/abl-log.sh`（新增，可复用的 ABL 日志读取器）
- 本报告。**未改** `TASKS/README.md` §0/§5 的任何状态数字（无状态变化，仅补证据）。
