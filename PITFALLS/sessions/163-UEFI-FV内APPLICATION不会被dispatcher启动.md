# #503 FV 里的 `UEFI_APPLICATION` 永远不会被 DXE dispatcher 启动

**日期**：2026-11-04 深夜（R10–R12 之后的静态复核）
**影响**：整条 UEFI 引导线的「最后一步」被误判为「缺一个 loader」，实际是「loader 早就在 FV 里，只是没人启动它」。

## 现象

R10 之后 UEFI 已经跑到底（约 150 条 `[I]/[E]`、零异常），R11/R12 证明 `BlockIo=119`、唯一 `SimpleFileSystem` 是
`modem_b`（不是 ESP）⇒ BDS 无交接目标 ⇒ 复位回落原厂 recovery。当时的结论写成
「本 Mu 构建**不含** `QcomModulePkg`，所以缺 kernel 交接层」。

## 真因（两层，都靠源码定案）

- **`QcomModulePkg` 在树里、也编了**：`build.log:4354` 有
   `Building .../QcomModulePkg/Application/LinuxLoader/LinuxLoader.inf [AARCH64]`，
   产物 `LinuxLoader.efi` 176 128 B，GUID `F536D559-459F-48FA-8BBC-43B554ECAE8D`，
   在 `Build/.../FV/FVMAIN.Fv.txt` 里是**最后一行**（`0xC126B0`）⇒ 它确实进了 FV。
- **它不会被启动**：`LinuxLoader.inf` 是 `MODULE_TYPE = UEFI_APPLICATION`，而 DxeCore 的
   `mDxeFileTypes[]`（`MU_BASECORE/MdeModulePkg/Core/Dxe/Dispatcher/Dispatcher.c:73`）只列
   `EFI_FV_FILETYPE_DRIVER / COMBINED_SMM_DXE / COMBINED_PEIM_DRIVER / DXE_CORE / FIRMWARE_VOLUME_IMAGE`，
   **没有 `EFI_FV_FILETYPE_APPLICATION`** ⇒ dispatcher 从不把它加进 driver 列表；
   BDS 又只认 `Boot####` 变量 / 可移动介质路径（本机 `uefivarstore` 里 0 条 `Boot####`，`VariableDxe` 在 `DXE.inc` 里被注释掉）
   ⇒ 这个应用在整个 UEFI 生命周期里**一次都没被 LoadImage 过**。

## 判据/教训

- 「树里有没有某模块」要查**三处**：源码目录、`build.log` 的 `Building` 行、`FV/*.Fv.txt` 的 GUID 行。
  只看第一处会得出「不含该包」的错误结论（本次就是这么错的）。
- 「进了 FV」≠「会被执行」：FV 文件的 **FFS 类型** 决定 dispatcher 是否派发；`APPLICATION` 必须由 BDS
  或某个 driver 显式 `LoadImage`。要确认一个 FV 内文件跑没跑，看屏上 load map 里有没有它（`PITFALLS #502`）。
- 本树把 `LinuxLoader.c` 的按键检测整段注释掉、写死 `BootIntoFastboot = TRUE` ⇒ 只要它被启动，
  UEFI 就会进**自己的 fastboot**（这正是上游 Mu-Silicium 在 SM8750 上「Linux Boot ✅」的形态：
  宿主 `fastboot boot <img>` / `fastboot continue` 走 `CmdBoot`/`CmdContinue` → `LoadImageAndAuth` → `BootLinux`）。
- 附带两条可用事实：`LoadImage(TRUE, gImageHandle, NULL, buf, size, &h)` 在 `SourceBuffer != NULL` 时
  **不需要 device path**（`MdeModulePkg/Core/Dxe/Image/Image.c:1243`）；解锁态 AVB 走
  `AVB_SLOT_VERIFY_FLAGS_ALLOW_VERIFICATION_ERROR`（`VerifiedBoot.c:1105`），我们自签的 boot.img 不会被拦。
