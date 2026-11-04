# UEFI 进 DXE 之后的取证纪律（2026-11-04 下午，r1–r8 八发零写盘）

日期 2026-11-04 · 主题 UEFI/DXE 屏上取证的五个坑 · 结论 见下条每条

## #498 屏满之后，**任何带 `\n` 的屏上打印都会二次异常**；RELEASE 下寄存器 dump 一条都打不出来

- 现象：屏上稳定出现 `Synchronous Exception at 0x…` + `Recursive exception occurred while dumping the CPU state` 成对无限重印。
- 根因：`MdeModulePkg` 的 `DefaultExceptionHandler` 在 RELEASE 里只剩「第一行（SerialPortWrite）」+「`gST->ConOut->OutputString`」两条有效路径，`DEBUG()` 全被编掉；而**屏满后**的 `SerialPortWrite` 要经过 `FrameBufferSerialPortLib` 的滚屏路径，在那里又触发一次异常 ⇒ 递归打印，永远到不了 `CpuDeadLoop()`。
- 处置：① 异常报告只用 `\r` 覆盖同一行、不带 `\n`；② 或把 `gST->ConOut->OutputString` 换成 no-op 再 `CpuDeadLoop()`（本轮 `patches/uefi/20261104R7-loadmap`）。判据：屏**停住不动**才算成功。

## #499 设备 `Binaries/` 里预编译的 `ArmPkg/*.efi + .inf` 会让**源码补丁对未来运行时无效**

- `Platforms/PakalaPkg/Device/*/Binaries/ArmPkg/Drivers/CpuDxe/{CpuDxe.efi,CpuDxe.inf}` 存在 ⇒ FDF 的 `INF ArmPkg/Drivers/CpuDxe/CpuDxe.inf` 解析到**预编译件**，`--clean` 全量重建也不会用源码。
- 判据（必做）：改完库后 `grep -c "<新字符串>" Build/PakalaPkg/RELEASE_CLANGPDB/AARCH64/ArmCpuDxe.efi`，为 0 就是没进去（`DxeCore.efi` 会进，容易误判）。
- 影响：`DefaultExceptionHandlerLib` 的源码插桩只在 DxeCore 生效；**CpuDxe 覆盖安装的仍是旧处理器**。

## #500 ramoops/pstore **不能**跨 `fastboot boot` → UEFI → `fastboot reboot` 取证

- 在机 DT 的 `ramoops@c2000000` 只有 **4 MiB**（`reg = 0xc2000000 0x400000`），与 `build/m1-73` 树的 8 MiB 不一致 ⇒ 布局假设全错。
- 实测回到 Linux 后 `/sys/fs/pstore/` **全空**，连「上一 boot 的内核 console 区」都没有 ⇒ 整区被清（冷复位/ABL/PrePi 的 `0xFF` 填充三者之一，未区分）。
- `/dev/mem` 读该区被 `CONFIG_STRICT_DEVMEM=y` 挡（`Bad address`），无法旁证。
- ⇒ 屏上通道仍是唯一可用通道；不要再在 ramoops 上投入。

## #501 构建两坑：`--patch` 必须绝对路径；增量补丁必须在「基线已 staged」时生成

- `scripts/uefi-build-variant.sh` 内部 `cd "$REPO"`，相对路径的 `--patch` 在 repo 内不存在 ⇒ 报 `patch does not apply anywhere`。
- 想在已应用补丁 A 的基础上再出一条补丁 B：先 `git apply A && git add -A`（把 A 变成基线），再编辑、`git diff`，否则 B 的上下文对不上 A 之后的文件（本轮两次构建失败均因此）。

## #502 进 DXE 之后**只留标记不够**，要留「带名字的 load map + 启动点」

- `DEBUG()` 在 RELEASE 全空 ⇒ 默认构建**看不到任何模块装载信息**；一旦后面的异常把屏刷掉，早先的 `[Pxx]` 全部丢失。
- 有效做法（本轮落地）：`Image.c` 里 `[I] <name.efi> base=… size=…`、`Dispatcher.c` 里每次 `CoreStartImage` 前 `[E] start=base`，两者用 base 配对即可定位「最后一个被启动的驱动」。
- 注意：ELR **不落在任何已装载区间**时，不要硬往驱动代码上归因 —— 那是被跳进的野地址（坏函数指针 / `0xFF` 填充区）。

## #506 ConOut 被 no-op 之后，AsciiPrint/DEBUG 一律不可见（2026-11-04R14–R15）

R7 的 `DxeMain.c` 补丁把 `gST->ConOut->OutputString` 换成 no-op（让异常处理器能走到
`CpuDeadLoop`）。副作用：**所有** `AsciiPrint`/`Print`/`DEBUG` 都不再上屏，
屏上能看到的只有走 `SerialPortWrite`（FrameBufferSerialPortLib）的行。
⇒ 探针一律 `AsciiSPrint` + `SerialPortWrite`，并给目标模块的 `.inf` 补
`SerialPortLib`/`PrintLib`（LinuxLoader / BootLib / AvbLib 三处都要，替换文件不必改）。

## #507 这棵树 AVB 是编译期关闭的：`GetAVBVersion()` = `ret i32 0`

`VERIFIED_BOOT/_2/_LE` 全 0 ⇒ `LoadImageAndAuthVB2`/`avb_slot_verify` 整段被编译器删掉。
在 `LoadImageAndAuthVB2` 里加探针 = 给死代码加探针（`llvm-nm` 里连符号都没有）。
判断方法：`llvm-dis` 目标文件后看 `GetAVBVersion` 的函数体，或用 `llvm-nm` 查符号是否存在。

## #508 dtbo 分区 32 MiB > DTBO_MAX_SIZE_ALLOWED 24 MiB 会把 boot 变成 "Load Error"

noauth 路径把整个分区当 dtbo 镜像读取；本机 `dtbo_b` 是 32 MiB 且**内容全 0**。
`EFI_OUT_OF_RESOURCES` 被 `LoadImageNoAuth()` 改写成 `EFI_LOAD_ERROR`，
fastboot 两条路（`continue` / `boot`）都报 "Load Error"。
修法见 `patches/uefi/20261104R16-dtboclamp` + `20261104R17-bootmarkers`：
先读一页表头，magic 不合法 ⇒ `EFI_NO_MEDIA`（当没有 overlay），合法 ⇒ 按 `total_size`
装载并把缓冲区按 4 KiB 取整（`LoadImageFromPartition` 按块大小向上取整读）。
