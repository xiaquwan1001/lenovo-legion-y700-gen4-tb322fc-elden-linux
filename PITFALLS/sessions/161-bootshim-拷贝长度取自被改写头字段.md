# 161 · UEFI：载荷只拷了 1 MiB —— 拷贝长度取自被 repack 改写的头字段（主机侧定案，零上机）

## **#497** `Image` 头字段不能既给引导器用、又给自己代码当输入；循环禁用等值比较

- **日期**：2026-11-04（主机侧静态复核；发现时机 = 11-03 深夜 11 发「DxeCore 从未启动」之后）
- **主题**：把「内层 FV 的 GUIDED/LZMA 段 `Decode` 返回 `EFI_INVALID_PARAMETER`」这一症状，追到真正的因 —— **BootShim 只把 FD 的前 1 MiB 拷到 `0xFF300000` 就跳了进去**。
- **结论**：卡点不在 FV / 解压器 / scratch / 内存图 / cache，而在**拷贝长度这一个值**。修复 = 长度与目标改构建期常量 + 循环改硬上界 + repack 加对齐断言（补丁 `patches/uefi/20261104-fixcopylen/`，产物 `out/uefi-20261104-fixcopylen.img`，未上机）。

## 1. 证据链（全部主机侧，指令级）

- 载荷头实测（`reports/artifacts/uefi-dxe10-20261104/payload-v2aligned.bin`）：
   `code0=10000601 code1=1400000f`、`text_offset=0x0`、**`image_size=0x400308`**、`flags=0xa`。
   `0x400308` ≡ **8** (mod 16)、≡ **776** (mod 1 MiB)。`uefi-dxe-`、`uefi-prepi-`、`uefi-prog-` 同值。
- shim 的拷贝长度取自该字段：`bootshim` 反汇编 `0x98: ldr x6, 0x10`（从载荷头 offset 16 读）。
- 拷贝循环（同一轮 `20261104-prog` 变体）在 `0xa4` 起是「拷 1 MiB → `subs x6,x6,#0x100000` → 与 `0x300000`/`0x200000`/`0x100000` **等值比较** → 相等则画色带回循环头；不相等则落 `0x1b8` 的收尾路径（连画三条色带）→ `0x2a4: ldr x5,0x300; br x5`」。
- 首轮后 `x6 = 0x400308 − 0x100000 = 0x300308 ≠ 0x300000` ⇒ 三个等值比较全不相等 ⇒ **只拷了 1 MiB 就 `br` 进 `0xFF300000`**。
- 这与 11-04 晚设备侧取证逐位吻合：**块 0–15（0–1 MiB）正确，从 `0x100000` 起 48 块全错**；坏内容 ≠ ramdisk / ≠ gz 载荷 / ≠ `0xFF` / ≠ `0x00`（= 上一轮遗留）。
- 因此 `LoadDxeCoreFromFv()` 的 `EFI_NOT_FOUND` 与 `LzmaDecode` 的 `EFI_INVALID_PARAMETER` 都是**下游症状**：压缩流从 `0x100000` 起根本没在内存里；PrePi 之所以还能跑，是因为它在 FD 的前 1 MiB 内。
- 同源坑（历史误判）：`patches/uefi/20261103-posctrl/0002-*` 里那段 4 MiB `dc civac` 清扫用同一 `_StackSize` 做 `subs x6,#64; b.ne`，`0x400308` 不是 64 的倍数 ⇒ **永不归零、扫出 4 MiB 窗口** ⇒ 挂死。当时被记成「死点在 civac 段」，于是有人把清扫整段删掉（`20261104-nocivac`），真因（脏行未 clean + 拷贝长度错）反而留了下来。旧 `_CopyLoop` 的 `subs #16` 同理（`0x400308 % 16 = 8`）。
- 「进度色带 4/4 = FD 拷完」是**误读**：三条色带都在收尾路径里连画，与「拷完 4 MiB」无关。

## 2. 修法（已落地为补丁，未上机）

`patches/uefi/20261104-fixcopylen/0001-bootshim-copy-length-from-build-constants.patch`：

- 头字段**只给 ABL 看**：`text_offset=0`、`image_size=UEFI_SIZE`、`flags=0xA`（`image_size` 之后仍由 repack 改写成真实长度，shim 不再读它）。
- 新增字面量 `_UefiBaseLit / _UefiSizeLit / _UefiEndLit`，`ldp/stp` 拷贝与 `dc civac` 清扫都取这三个**构建期常量**。
- 清扫循环改「地址 < 上界」（`cmp x7,x8; b.lo`），任何长度都不会扫出窗口。
- `.balign 16` 放在 `_Payload` 前 ⇒ 拷贝源 16 字节对齐（原 `0x2e8`/`0x308` 是非对齐 `ldp`）。

自校验（已跑）：`BootShim.bin` 192 B、`%16==0`、`_Payload=0xc0`；反汇编确认 `adr x6,_UefiSizeLit; ldr x6,[x6]`（长度 0x400000）与 `cmp x7,x8; b.lo`（清扫上界 0xff700000）；repack 后 `payload len 4194496`、`%16==0`。

## 3. 下一发上机的判据

- **`[P11]` 不再出现**（`LoadDxeCoreFromFv` 若不返回，就不会打这条）；
- 屏被 DXE 侧 `SerialPortInitialize` 清屏 + **出现 `[D00]`**（= DxeCore 真的进场）；
- 附带：64 块 FNV 块表应 **64/64 全对**（本轮变体保留了 `20261104-dxe/0013` 的块表插桩）。

## 4. 证据指针

- 补丁 `patches/uefi/20261104-fixcopylen/0001-*`；构建 `reports/artifacts/uefi-fixcopylen-20261104/`（`manifest.txt` 记录 11 枚补丁与 worktree 状态）；镜像 `out/uefi-20261104-fixcopylen.img`（sha256 `c0118018…`）。
- 对照件：`reports/artifacts/uefi-dxe10-20261104/`（同 FD 插桩、旧 shim）。
- 前置结论：`PITFALLS #493–#496`、`reports/uefi-payload-execution-20261104.md`。
