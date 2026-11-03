# UEFI 线：**DxeCore 从未被启动** —— 真卡点在内层 FV 解压（11 发零写盘）

- **日期**：2026-11-04（主机 2026-11-03 21:00–22:35 时钟）
- **pi 会话 id**：`01a1a16b-6cc9-735f-b518-a50a78af95f6`
- **主题**：给 DXE Core 打屏上串口插桩后，发现前一轮「已交给 DXE Core」的判据是误读；逐层把卡点定位到 `DecompressFirstFv` 的 LZMA GUIDED 段解码失败，并发现设备侧 FD 在 DRAM 里从 1 MiB 起已被改坏。
- **结论**：
  1. **`[P11]` ≠ 交棒**：它打在 `LoadDxeCoreFromFv()` **返回之后**，实测返回 `0x800000000000000E`（EFI_NOT_FOUND）⇒ **DxeCore 一次都没被执行**（`[D00]` 从未出现、屏从未被 DXE 清屏）。
  2. **FV 发现链正常**（HOB 里 1 个 FV = `0xFF300000`/`0x400000`），失败在**内层 FV 解压**：`FV_IMAGE` 文件（type=0x0B）唯一段是 GUIDED/LZMA（`DataOffset=0x18`，`PROCESSING_REQUIRED`）→ `ExtractGuidedSectionGetInfo` **成功**（解压后 `0xC45008`）→ `ExtractGuidedSectionDecode` 返回 **`EFI_INVALID_PARAMETER`** → `FfsProcessSection` 统一改写为 `EFI_NOT_FOUND` ⇒ 无内层 FV HOB ⇒ 找不到 `DXE_CORE`。
  3. **压缩数据本身没问题**：主机用 Mu 树内**同一份** `Sdk/C/LzmaDec.c` 解压 `res=0`、解出 `0xC45008` 字节；Python `lzma` 亦成功 ⇒ 排除「压缩参数/字典过大/scratch 64 KiB 不足」等假设（`LzmaDecode` 只分配 16 KB probs，`p.dic = dest`，不需要字典分配）。
  4. **设备侧 FD 内容已被改坏**：块表（64×64 KiB 的 32 位 FNV）显示 **块 0–15（0–1 MiB）全部正确**（仅 2 个单比特翻转），**从块 16（FD `0x100000`）起 48 块全错**；坏内容 ≠ ramdisk、≠ gz 载荷、≠ 全 `0xFF`、≠ 全 `0x00`。
  5. **未定**：损坏发生在 **PrePi 之前**（shim 拷贝 / ABL 解 gz）还是 **PrePi 之内**（内存图把 `0xFF300000` 声明为 `BsData` = 可分配空闲内存）。第 11 发（`[A]`/`[B]` 两张块表）屏纯黑无输出，该判据未取到；本轮按用户要求收尾。
- **证据指针**：
  - 补丁：`patches/uefi/20261104-dxe/0001…0014`（`0001` DxeMain 相位点、`0002` Dispatcher `>`、`0003/0005` PrePiLib 装载/FV 发现、`0004/0010…0014` PrePi 状态与校验、`0006/0007/0008/0009` FwVol GUIDED 段与载荷校验）
  - 构建产物：`reports/artifacts/uefi-dxe{,2…11}-20261104/`（各含 `SM8750_EFI.fd`/`BootShim.bin`/`manifest.txt`/`build.log`）
  - 镜像：`out/uefi-20261104-dxe{,2…11}.img`（全部 `fastboot boot` 零写盘）
  - 上机现场：`reports/artifacts/uefi-boot-20261103-dxe{,2…11}/boot.txt`
  - 工具：`scripts/uefi-build-variant.sh`（本轮升级）、`scripts/uefi-repack-v2aligned.py`
- **★SSOT 待并入**：
  - `TASKS/README.md` §5 新块（已并入）；§4 N1 与 G1-29 行的「已交给 DXE Core」口径**必须改成「DxeCore 从未启动」**（已改 §4 N1 一条，G1-29 行待并入）。
  - `reports/uefi-payload-execution-20261104.md` §7 的「`[P11]` ⇒ 已交 DXE」结论**作废**，需在该报告加更正指针。
  - 坑：`PITFALLS #493/#494/#495/#496`。

---

## **#493** `[P11]` 不是「已交给 DXE Core」——DxeCore 若真进场，该函数永不返回

`AndromedaPkg/PrePi/PrePi.c` 的 `[P11]` 打在 `LoadDxeCoreFromFv (NULL, 0)` **返回之后**。
真交棒时 DxeCore 进入自己的 `DxeMain` 后**永不返回**（末尾是 `CpuDeadLoop`），所以：

- 屏上出现 `[P11]` ⇒ **`LoadDxeCoreFromFv` 返回了** ⇒ DxeCore 没被调用（或调用后立刻返回）。
- 本轮实测返回 `0x800000000000000E`（`EFI_NOT_FOUND`）：`FfsAnyFvFindFirstFile (EFI_FV_FILETYPE_DXE_CORE)` 在所有 FV 里没找到 DxeCore 文件。
- RELEASE 构建下 `ASSERT_EFI_ERROR` 是空操作 ⇒ PrePi 会静默往下走，**不报错、不复位**，看起来像「跑完了」。

**正确判据**（进 DXE 的最低证据）：屏被 DXE 侧 `SerialPortInitialize()` 清屏（`FbConReset`）+ 出现 `[D00]`。
只看 `[P11]` 会把「加载失败」误读成「已交 DXE」。

## **#494** 构建脚本会静默打包「上一轮旧 FD」——必须以 FD 是否真的重新生成作为成败判据

`build_uefi.py` 在编译阶段失败（例如插桩里调用了后置定义的函数，`-Werror` 直接报
`call to undeclared function`）时，脚本里 `|| echo "note: rc!=0"` 会吞掉返回码，而
`Build/.../FV/SM8750_EFI.fd` 仍然**是上一轮留下的旧文件** ⇒ 旧 FD 被当成新产物打包上机，白烧一发。

已修（`scripts/uefi-build-variant.sh`）：

- 记录 `BUILD_START=$(date +%s)`，构建后断言 `stat -c %Y $FD >= $BUILD_START`，否则 **exit 1**；
- 注意 `build.log` 是**追加**写，旧 `error:` 行会残留 ⇒ 不能靠 `grep error:` 判成败；
- 事后用 `strings -a $FD | grep '\[新标记\]'` 确认插桩真的进了产物（压缩 FV 里的标记 `strings` 看不到，
  要看 `Build/.../FV/FVMAIN.Fv` 或对应 `.obj`）。

## **#495** 子模块内补丁：要 `git -C <submodule> apply`，且回滚必须逆序

- `MU_BASECORE`、`Common/MU_TIANO`、`Silicon/Arm/MU_TIANO` 等是 **submodule**；主仓 `git apply`
  对 `MU_BASECORE/...` 这类路径**不生效**。`uefi-build-variant.sh` 的 `--patch` 现在会先在主仓试，
  失败再逐个 `git -C <sm> apply --check`。
- **回滚必须逆序**：后打的补丁依赖先打的补丁上下文。顺序回滚会失败，而脚本里 `|| true` 会把失败吞掉
  ⇒ 树留在脏状态，下一轮**第一个补丁**就 `git apply` 失败（本轮实际踩到）。
- 生成「增量补丁」时，先 `git add` 已应用的基线再改文件，否则 `git diff` 会把上一层补丁也算进去，
  导致两份补丁无法按序叠加。

## **#496** 屏上串口是唯一通道时，一次输出必须塞进一屏，否则证据直接被滚掉

`SCALE_FACTOR=3`（`Platforms/AndromedaPkg/Include/Resources/font5x12.h`）时可见区约 **75 列 × 50 行**。
本轮第 8 发把 4 组 × 4 个 64-bit 字**一行一个**打印 ⇒ 超过 50 行，第一屏证据滚没了，白烧一发。

做法：

- 诊断值统一「8 位十六进制、8 个一行」的紧凑块表（例：64 个 64 KiB 块的 32 位 FNV = 正好 8 行）；
- 先把**已知结论**的插桩点删掉再上机（`[Pnn]` 之类只保留首尾）；
- `--scale N` 已参数化（`--scale3` 保留为别名）；`--scale 2` 可再多塞一倍行，但字形变小。
