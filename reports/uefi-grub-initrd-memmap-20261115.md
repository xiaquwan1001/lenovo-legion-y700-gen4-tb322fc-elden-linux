# UEFI(GRUB) 路径 64 MB initrd 交接失败 —— 内存图方向收窄报告

**日期**：2026-11-15（纯主机侧：不上机、不写盘、不发信）
**上游计划**：`.pi/plans/2026-11-15-uefi-grub-initrd-next.md`
**前序**：`TASKS/sessions/2026-11-14-UEFI复测2-间接形态通过与GRUB-initrd断点.md`、`PITFALLS/sessions/295-GRUB大initrd交接坏掉.md`（#659）
**证据目录**：`reports/artifacts/uefi-grub-memmap-20261115/`（8 份 QEMU 原始日志 + 2 份诊断日志 + 一份汇总 + 复现脚本）
**结论一句话**：断点从「GRUB 通用逻辑 / 内核解包代码 / 地址截断」**再收窄一层到「64 MB 缓冲区里的内容在前 ~1–5 MB 之后就不是原文件了」**；
「Put 到哪 / 多高地址 / 多大」全部被 QEMU 消元排除（initrd 放在 **4.68 GiB** 都成功），离线可做的只剩「谁把字节写坏了」两条路，且已备好**一发、零写盘、单比特判决**的上机单（GRUB 侧 `hashsum`）。

---

## 0. 结论优先（TL;DR）

1. **GRUB 根本没在放 initrd**：我们的 `Image` 是 EFI-stub 版本 3（PE `MajorImageVersion=3`），
   GRUB 走 **LoadFile2 协议**分支——它只装一个 `EFI_LOAD_FILE2_PROTOCOL`，**不分配、不搬运** initrd；
   真正的 `AllocatePages(64 MB)` 是**内核 EFI stub** 用**固件（=我们的 Mu UEFI）**的分配器做的。
   ⇒ 「GRUB 的 `allocate_initrd_mem` 把 initrd 放错地方」「GRUB 在 EBS 前后搬移 initrd」**这两条假设对本配置直接不成立**（见 §1）。
2. **QEMU 消元把「位置/大小/高地址」全部打掉**：同一份 64 MB initrd 在 EDK2 下被放在 **物理 0x12b660000 = 4.68 GiB**
   （**4 GiB 以上**！），1.60 s 解包成功；`-m 2048` 时放 **0xab660000（4 GiB 以下）** 也成功；16 MB 也成功（§2 表）。
3. **屏上那一行 `broken padding` 不是 gzip 错误**：它来自 `init/initramfs.c:337` 的 **cpio 解析器 `do_reset()`**。
   QEMU 标定（§2.2）给出它的**指纹含义**：缓冲区里的 gzip 成员**真的解压完了**，但解出来的流是
   「一段**提前结束**的合法 cpio 归档 + 1–3 个 NUL + 非零垃圾」；而设备只花了 **37 ms**（照片 15.265951 → ~15.30）
   ⇒ 解压输出只有**几 MB** 量级（真件要 1.6 s / 181 MB）。**⇒ 不是「末尾被截」、不是「尺寸不对」，是前段几个 MB 之后内容就变了。**
4. 反证表（重要）：真·截断会打 `read error`（Y3），「短 gzip + 后面全 0」**什么都不打**（Y1），
   「短 gzip + 后面随机垃圾」打 `invalid magic at start of compressed archive`（Y2）。设备打的是 `broken padding`，
   **只能是「成员内部就坏了/提前结束了」**（Y4/Y5）。
5. **剩下两条候选**（都落在「64 MB 缓冲区怎么被填」这一层，不再是内核逻辑）：
   **C1** Mu 的 UFS `EFI_BLOCK_IO` 在**大块读**上返回错误字节而不报错（GRUB 的读是 1 MiB 粒度，`max_agglomerate`）；
   **C2** Mu 的 `AllocatePages` 把 64 MB 给了内核 stub，但这片页**同时被别的东西写**（分配器与内存图不一致 / 落在未描述区）。
   二者的判决**一发就够**：让 GRUB 自己算 initrd 的 sha256（同一读路径），与主机 sha 比（§5 Shot A）。
6. **Mu 内存图侧的结构性事实**（pc1 **无** R74）：EFI 可见的 `Conv` 只有 **`0xB90C0000`–`0xD65C0000` = 469 MiB** 这一块；
   `0xD65C0000`–`0xFC800000` 这 612 MiB **在表里没有条目**（pc2/R74 补过后症状就变了，见 §3）。
   64 MB initrd + 63 MB Image + KASLR 副本 + GRUB 自身全挤在这 469 MiB 里 ⇒ 分配器行为值得怀疑，但**已不是「地址太高」那种问题**。

---

## 1. GRUB arm64 到底把 initrd 放哪（源码事实，版本 = 我们出货的 arm64 模块 2.14）

源码：`ubuntu-ports` 的 `grub2-unsigned_2.14.orig.tar.xz`（sha256 `bc8d3c73…`，解在 `/tmp/grubsrc/grub-2.14`，不入库）。
与我们 `scripts/grub-arm64-standalone.sh` 用的 `grub-efi-arm64-bin_2.14-2ubuntu1_arm64.deb` **同一上游版本**。

| 事实 | 位置 |
|---|---|
| 是否装 LoadFile2 由**内核 PE 头**的 `MajorImageVersion >= 1` 决定 | `grub-core/loader/efi/linux.c:135-136` |
| 我们的 `out/vk188-bootfiles/Image`：`machine=0xAA64`、`opt magic=0x20b`、**`MajorImageVersion=3`** ⇒ **走 LoadFile2** | 本机 `python3` 读 PE 头（本轮实测） |
| LoadFile2 分支：装完协议就 `return GRUB_ERR_NONE`，**不分配、不拷贝** | `grub-core/loader/efi/linux.c:428-442`（`Using LoadFile2 initrd loading protocol`） |
| 「受限地址分配」`allocate_initrd_mem()`（`ram_base + 32 GiB`，`EFI_ALLOCATE_MAX_ADDRESS`）**只在非 LoadFile2 分支用到** | `grub-core/loader/efi/linux.c:311-333, 450` |
| `finalize_params_linux()` 只有在 `initrd_start != 0`（即 legacy 分支）时才写 `linux,initrd-start/end` | `grub-core/loader/efi/linux.c:147-183` |
| 内核 Image 本身用 `grub_efi_allocate_any_pages` 分配（不受限） | `grub-core/loader/efi/linux.c:537` |
| **内核 stub 侧**：`efi_load_initrd(image, ULONG_MAX, efi_get_max_initrd_addr(image_addr))` | `drivers/firmware/efi/libstub/efi-stub.c:172` |
| arm64 的 hard limit = `(image_addr & ~(1G-1)) + (1<<(VA_BITS_MIN-1))` ≈ **1 GB 对齐 + 128 TiB**（等于没有限制） | `arch/arm64/include/asm/efi.h:83-86` |
| stub 先问 LoadFile2 尺寸，再 `efi_allocate_pages(size, &base, max)`（`EFI_ALLOCATE_MAX_ADDRESS`，hint=`ALIGN_DOWN(max+1,4K)-1`），**由固件挑地址**（EDK2 系实现挑 **Top 以下最高可用块**） | `drivers/firmware/efi/libstub/efi-stub-helper.c:552-588`、`libstub/mem.c:82-104` |
| GRUB 的 `LoadFile2` 回调体 = `grub_initrd_load(ctx, buffer)`，即**把自己读的文件写进内核给的 buffer** | `grub-core/loader/efi/linux.c:~360-380` |
| 该回调**校验读满**：`grub_file_read(...) != cursize` ⇒ 直接返回错误（stub 会打 `Failed to load initrd`） | `grub-core/loader/linux.c:328-336` |
| GRUB 读盘经 `grub_disk_read`，单次 agglomerate 上限 **1 MiB**（`max_agglomerate = 1048576 >> …`） | `grub-core/kern/disk.c:207` |

**由此可推出的硬结论**（都是本轮新增，计划 §0 里没有）：

- **不是「GRUB 分配 initrd 落点」的问题**：本配置下 GRUB 一个字节的 initrd 内存都不分配。
- **不是「GRUB 在 ExitBootServices 前后搬移 initrd」**：GRUB 全程只在内核 stub 要求时（EBS **之前**）填 buffer 一次。
- **一旦 GRUB 的读失败/读短，内核根本不会打印 `Unpacking initramfs...`**（会打 `Failed to load initrd` 且没有 initrd 表）。
  设备屏上**既有 `Unpacking`、又有 `Freeing initrd memory: 63080K`（与 QEMU 同件同值，量级 = 文件大小 64,595,425 B）**
  ⇒ 在 `EFI_LOAD_FILE2` 这一侧，GRUB/stub 都认为「64 MB 全读进 buffer 了、尺寸正确」。
- **⇒ 剩下的唯一解释是「buf 里的字节内容在 GRUB 记账之外被改过」**：
  要么读回来就是错的（固件 BlockIo 悄悄给错），要么这片物理页不是「独占的」（Mu 分配器给的页被别处同时写）。

---

## 2. QEMU 消元实验（同一份 GRUB、同一份 Image、每次只改一个变量）

工作目录 `/tmp/qsay2`（脚本 `reports/artifacts/uefi-grub-memmap-20261115/run.sh`，完整日志同名 `log-*.log`）。
除注明外：`-M virt,acpi=off -cpu cortex-a72 -smp 4 -bios QEMU_EFI.fd`（AAVMF），菜单**不写 `devicetree`**（计划 §1 的坑），
cmdline 含 `efi=debug`（用于取 EFI 内存图与确认走的是 LoadFile2）。

### 2.1 位置/大小消元（全部成功，无 `broken padding`）

| 实验 | 变量 | initrd | 结果（原始输出） | initrd 物理落点（从 `efi=debug` 内存图反查） |
|---|---|---|---|---|
| **X1b** | 基线 | 64 MB（64,595,425 B）`-m 4096` | `[0.343394] Unpacking initramfs...` → `[1.940575] Freeing initrd memory: 63080K`（**1.60 s**） | **`0x12b660000`–`0x12f3fffff`（4.68 GiB，4 GiB 以上）** |
| **X2b** | 只改 **尺寸** → 16 MB | 16 MB（14,682,541 B）`-m 4096` | `[0.405144] Unpacking` → `[0.490907] Freeing initrd memory: 14336K`（86 ms） | `0x12e5f0000`（同在高区） |
| **X3b** | 只改 **内存大小** → 2 GB | 64 MB `-m 2048` | `[0.372167] Unpacking` → `[2.034284] Freeing initrd memory: 63080K`（1.66 s） | `0xab660000`–`0xaf3fffff`（**4 GiB 以下**） |

配套事实：三次日志都有 `EFI stub: Loaded initrd from LINUX_EFI_INITRD_MEDIA_GUID device path`
⇒ **QEMU 走的就是设备上同一条 LoadFile2 代码路径**，所以上面的"成功"是可对标的，不是走了别的分支。

**⇒ 结论**：
- 「initrd 被放到 **4 GiB 以上**」**不是**病因（X1b 就在 4.68 GiB，1.6 s 解包成功）；
- 「64 MB 尺寸本身」「跨 4 GiB 边界」「落点高低」都不是病因；
- 有效信息只剩 **「设备上这片 64 MB 是谁的、字节对不对」**。

### 2.2 屏上那一行的指纹标定（这是本轮最有用的新工具）

做法：故意构造各种「坏的 initrd」，看内核**打哪句话**，把设备屏上唯一的那一行变成可判读的指纹。

| 实验 | initrd 构造 | 内核原话（时间戳） | 耗时 |
|---|---|---|---|
| **Y1** | `slim.gz`（1 MB，真件）+ 63 MB **全 0** | *（无错误）* `[0.347038] Unpacking` → `[0.708223] Freeing` | 361 ms |
| **Y2** | `slim.gz` + 63 MB **随机垃圾** | `[0.418030] Initramfs unpacking failed: **invalid magic at start of compressed archive**` | 66 ms |
| **Y3** | 真 64 MB initrd **截断到 32 MB** | `[0.929735] Initramfs unpacking failed: **read error**` | 596 ms |
| **Y4** | gzip( `slim.cpio` + **1 个 NUL** + 400 KB 随机 ) | `[0.412846] Initramfs unpacking failed: **broken padding**` | **62 ms** |
| **Y5** | gzip( `slim.cpio` + **4 个 NUL** + 400 KB 随机 ) | `[0.432601] Initramfs unpacking failed: **junk within compressed archive**` | 60 ms |
| **设备** | 真 64 MB initrd（3 发均同） | 照片 `15.265951 Unpacking initramfs...` → `~15.30 **broken padding**`；随后 `Freeing initrd memory: 63080K` | **37 ms** |

源码对得上：`broken padding` 只出现在 `init/initramfs.c:332-338`（`do_reset()`）——
即「cpio 解析器已进入 `Reset` 态，跳掉一串 NUL 之后 `this_header & 3 != 0` 却还有非零数据」。
而 `Reset` 态是 `flush_buffer()`（`init/initramfs.c:483`）在解压**输出流中段**遇到 NUL 时设的
⇒ **解压确实在进行、并且"提前结束/中途错位"**。

**⇒ 设备那 37 ms 的物理含义**：真件解 181,832,192 B 要 1.6 s（QEMU），设备 37 ms 只能解出**几 MB**输出
（约 2.8× 压缩比 ⇒ 只吃进了**文件前 ~1–5 MB** 的压缩数据），随后解压流就"结束了/错位了"。
配合 Y1/Y2/Y3 的反证：**设备上不是"尾巴被截"、不是"尺寸不对"、不是"后面接垃圾"，而是"前 ~1–5 MB 之后压缩流本身就已经不是原文件"。**

---

## 3. Mu UEFI 侧的结构性事实（内存图 / 保留区形状）

来源：`reference/uefi-samechip-20261028/PlatformMemoryMapLib-lenovo-y700g4.c`（= 我们 Mu 树的这份表）、
`patches/uefi/pc1-recipe.txt`（**pc1 不含 R74**）、`patches/uefi/20261110R74-memmap-appsfree/`、`out/vk188-bootfiles/elden.dtb`。

| 项 | 值 | 备注 |
|---|---|---|
| EFI 可见 `Conv`（Conventional） | **只有** `DXE Heap = 0xB90C0000 + 0x1D500000` ⇒ `[0xB90C0000, 0xD65C0000)` = **469 MiB** | pc1 唯一可分配区 |
| `0xD65C0000`–`0xFC800000` | **表里完全没有条目**（既非 Reserv 也非 Conv），612 MiB | pc2 = pc1 + R74 把它标 Conv 后**症状变了**（`reports/uefi-clean-pc1-and-grub-menu-20261110.md` §7） |
| 名字叫 `Kernel` 的区 | `0xA8000000 + 0x10000000`，`Reserv` | 不参与分配 |
| DTB `/memory` | 只声明 DDR 碎片 + 高区（`0x8_80000000`、`0x8_b0000000`、`0xA_00000000`…） | **远多于 EFI 图**；UEFI 路径下内核可用内存由 **EFI 图**决定 |
| DTB `/reserved-memory` 与 469 MiB `Conv` 窗口的**交集** | 只有两处：`0xC2000000 + 0x800000`（8 MiB，ramoops 系）与 `0xD4E23000 + 0x2DD000`（2.9 MiB，DDR 碎片边界） | 其余 42 个保留区都在窗口外 |
| `PrePi` 的 `EfiFreeMemoryTop` | `0xD6580000`（= DXE Heap 顶 − 栈） | `archive/plans-20261110/next/uefi-next-experiments.md` §2.2 |

**现在怎么读这张表**：469 MiB 窗口内要同时装下
`GRUB 镜像(7 MB) + GRUB 堆 + Image 63 MB + stub 里 KASLR 重定位副本(~63 MB) + 页表 + DTB 153 KB + initrd 64 MB`
≈ 200 MB+，**能放下但很紧**；而 **`0xD65C0000` 以上"没有条目"612 MiB** 是这条线上唯一被实测证明"改了就变症状"的结构差异（pc2）。

⇒ 若走 **C2**（分配器与内存图不一致）路线，最可能的具体形态不是"落到 4 GiB 以上"（已被 X1b 排除），而是：
**Mu 的 `AllocatePages(MAX_ADDRESS)` 返回的块跨进了"没有条目的区"或与别的使用者重叠**，
于是"分配成功、尺寸正确、内容却被别处周期性改写"。

---

## 4. 断点现在在哪一层 / 还剩哪些候选

**当前断点层（本轮新口径）**：
```
[✅] ABL → pc1 Mu UEFI → ESP BOOTAA64.EFI(GRUB) → linux 命令 → LoadImage(内核 stub)     （#622/#659 已定）
[✅] stub 装 LoadFile2、GRUB 回调按 64 MB 记账读满、stub AllocatePages 成功、尺寸 63080K 正确
[❌] 缓冲区字节内容：前 ~1–5 MB 之后就"不是原文件了"（37 ms 提前结束 + broken padding 指纹）
[—] 之后的解包/挂 root 全未真正开始（本轮无需再讨论）
```
即：**已从"GRUB 逻辑 / 内核解包 / 地址与尺寸"下沉到"这 64 MB 页是谁的、谁写的、写对没有"。**

| # | 候选 | 支持证据 | 反对/待验 | 判别实验 |
|---|---|---|---|---|
| **C1** | **Mu 的 UFS `EFI_BLOCK_IO` 大块读静默给错字节**（GRUB 按 1 MiB agglomerate 读，`disk.c:207`），`grub_file_read` 只核对**长度**不核对内容 ⇒ 记账 64 MB 全到、内容在第 N 个 1 MiB 块起变味 | 设备只解出几 MB 就"结束"；QEMU（virtio-blk/EDK2）无此问题；GRUB 侧长度校验通过但不校验内容 | 若真错，为何错得"像合法 gzip 提前结束"？——Y4 表明**中段错字节也能被 zlib 当垃圾输出**并触发同一句 `broken padding`（不要求"合法提前结束"） | **Shot A**：GRUB 侧 `hashsum --hash sha256` 直接算同一读路径的 sha（§5） |
| **C2** | **Mu `AllocatePages` 给的 64 MB 页不独占**：与"没有条目的 612 MiB"或其它使用者重叠，被固件/其它 agent 覆盖 | pc2(R74) 一改内存图症状就变；469 MiB 窗口被压得很紧；`broken padding` 需要"内容被改写" | 需证明"改写者"存在；本机无法验证 | Shot A 若 sha **匹配** ⇒ 读路径清白 ⇒ C2 升为首选；再上 Shot B（换 cmdline 装载路径 / 换小 initrd） |
| C3 | GRUB 的 ext4/文件层在 64 MB 上把内容读成"另一份文件"（例如缓存错块） | 极罕见 | 无 | Shot A 同判 |
| C4 | 内核侧（stub 之后、unpack 之前）把 initrd 区改掉 | `memblock_clear_nomap + reserve` 已排除常规路径（`arch/arm64/mm/init.c:257-296`）；`initrd not fully accessible` 的 WARN 未出现在屏上 | 屏上没看到那条 WARN（若出现会伴随 `- disabling initrd`，可立刻排除本项） | 同 Shot A |
| （已废） | 「initrd 落在 4 GiB 以上 / 尺寸大 / 跨 4 GiB / 落在 DTB 保留区 / 32 位地址截断 / GRUB 分配落点」 | —— | **X1b/X2b/X3b 已逐一打掉**；且 LoadFile2 分支下 GRUB 不分配 initrd | 不再投设备 |

---

## 5. 下一发上机单（**仅备好，未执行**）

> 形态：**一发、零写盘（除 ESP 上换一个 BOOTAA64.EFI，与既往每个诊断轮同性质）、屏拍照判读**。
> 只改一个变量：**在 boot 之前多打两行 sha**——boot 路径与第 3 发逐字相同（同一 64 MB initrd、同一 DTB、同一 cmdline）。

### Shot A（首选，单比特判决：读路径 vs 写/内存路径）

**装什么**：`hashsum` + `lsefimmap` 模块的 arming GRUB（菜单见
`reports/artifacts/uefi-grub-memmap-20261115/menu-hashsum-lsefimmap.cfg`，已在本机 QEMU 打通语法与模块可用性）：

```text
menuentry "A: hash(initrd) + boot same 64MB" {
  set root=(hd0,gpt17)                     # linux17；ESP 上则 (hd0,1)
  echo "== SHA256 INITRD (HOST 3282ae6c…0706e) =="
  hashsum --hash sha256 ($root)/boot/initrd.img
  echo "== SHA256 IMAGE (HOST 0cdb7a45…33bfe) =="
  hashsum --hash sha256 ($root)/boot/Image
  echo "== BOOT CONTROL =="
  linux  ($root)/boot/Image console=tty0 earlycon=efifb keep_bootcon ignore_loglevel panic=0 <其余与第 3 发一致>
  initrd ($root)/boot/initrd.img
  devicetree ($root)/boot/elden-nopstorecons.dtb
  boot
}
```

**期望输出 / 判据（拍照 2 张：sha 页 + 内核页）**：

| 结果 | 判读 | 下一步 |
|---|---|---|
| initrd sha **≠ 3282ae6c…** | **C1 成立**（Mu BlockIo/GRUB 读路径给出错误字节）——读时就错了 | 立刻转"读粒度二分"：同一条 GRUB 用 `cmp` 比 1 MiB 分段副本定位第一个坏块（下一发再准备） |
| initrd sha **= 3282ae6c…**，且随后仍 `broken padding` | **读路径清白 ⇒ C2 升为首选**（allocated 页不独占/被改写） | Shot B：见下 |
| sha 匹配但**不再** `broken padding` | 「读之前多读了 64 MB」本身改变了分配/时序 ⇒ 强烈指向 C2（时序/重叠） | 同上，Shot B |
| `hashsum` 报错或没输出 | GRUB 的读路径**直接失败**（也是一种 C1 强证据） | 记录错误串，Photograph，收工重设计 |

**回退**：本发不写任何分区；ESP 换件前先 `cp` 备份（沿用 `scripts/esp-install-grub.sh --rollback`），
失败后不清楚就 `fastboot set_active b` / ESP 恢复 `Loader-r73`（`6e51fc60…`）；`boot_a` 不动。

**注意（本轮 QEMU 实测）**：`lsefimmap` 在 AAVMF + 这份 GRUB 上**只打表头、不打描述符**（`log-Z2.log`），
所以**不要把内存图当判据**；要看 Mu 侧的图，正确做法是给 Mu 本身加一条打印（`SbMark`/`FrameBufferSerialPortLib`），那是另一个件、另一发。

### Shot B（仅当 Shot A 判 sha 匹配时用；同样一发）

变量换一处：**不用 `initrd` 命令**，改成在 `linux` 命令行里给 `initrd=\boot\initrd.img` ——
这样 stub 的 LoadFile2 探测返回 NOT_FOUND，退回 `efi_load_initrd_cmdline()` 路径
（`drivers/firmware/efi/libstub/efi-stub-helper.c:590-600`，用 **EFI SimpleFileSystem** 读文件、仍用同一 `efi_allocate_pages`）。

- 若**能过** ⇒ 罪在 **GRUB 的 LoadFile2 写入路径**（谁写 buffer），Mu 分配器清白；
- 若**仍 `broken padding` 且耗时仍几十 ms** ⇒ 罪在 **Mu 分配器/内存图**（两条完全不同的读路径都坏在同一片页上）。

---

## 附录 A. 对计划文件 §0/§1 的增量（追加，不改计划正文）

### A.1 §0「已排除项」新增（本轮主机侧否证，勿再投设备）

| 假设 | 否证方式 |
|---|---|
| GRUB 用受限地址（`ram_base+32 GiB`，`EFI_ALLOCATE_MAX_ADDRESS`）放 initrd，被我们的内存图挤到坏地方 | 我们的 `Image` 是 stub **MajorImageVersion=3** ⇒ GRUB 走 **LoadFile2** 分支，`allocate_initrd_mem()` 根本不被调用（`grub-core/loader/efi/linux.c:135,428-450`） |
| GRUB 在 `ExitBootServices` 前后把 initrd 搬一次 | 同一分支下 GRUB 只在 stub 索要时（EBS 前）填 buffer 一次，无搬移代码 |
| 「initrd 落到了 4 GiB 以上」是病因 | QEMU X1b：落点 **0x12b660000 = 4.68 GiB**，1.60 s 解包成功，无 `broken padding` |
| 「initrd 尺寸大（64 MB）本身过不去」 | QEMU X2b（16 MB 成功）+ X1b/X3b（64 MB 两次成功） |
| 「initrd 跨 4 GiB / 落点低才有问题」 | QEMU X3b（`-m 2048`，initrd 在 `0xab660000`，4 GiB 以下）同样 1.66 s 成功 |
| 「`Freeing initrd memory` 的尺寸能证明数据完整」 | 尺寸只取决于 `phys_initrd_size`（= stub 报的文件大小，`arch/arm64/mm/init.c:294`），与内容无关；设备与 QEMU 同件都打 63080K |
| 「设备上的错可能是文件尾巴被截」 | QEMU 标定 Y3（真件截断一半）⇒ `read error`，**不是** `broken padding`；Y1/Y2 也各打不同的话 |
| 「`lsefimmap` 可以在 GRUB 里把 Mu 的内存图打出来」 | AAVMF + 本 GRUB 2.14 上实测**只打表头**（`reports/artifacts/uefi-grub-memmap-20261115/log-Z2.log`）；要看图必须走 Mu 侧插桩 |

### A.2 §1「QEMU 可复现配方」新增

1. **必须带 `efi=debug`**（cmdline）：否则拿不到 `EFI stub: Loaded initrd from LINUX_EFI_INITRD_MEDIA_GUID device path`
   与 EFI 内存图，也就**无法反查 initrd 落点**（本轮就是这样拿到 `0x12b660000` 的）。
   反查方法：把 `efi: 0x….0x…. [Loader Data]` 里长度 ≈ 文件页数的那块当成 initrd 落点（本轮 8 份日志全部唯一匹配）。
2. **每次实验必须用独立的 ESP 目录**：`-drive file=fat:rw:<dir>` 的多个实例共享同一目录会互相串菜单——
   本轮第一版就因此两次跑成同一个 initrd（已修：`run.sh` 里 `ESP=$W/esp-$TAG`）。
3. **`broken padding` 指纹标定集**（可直接复用，1 分钟一发）：真件截一半⇒`read error`；
   `slim.gz`+63 MB 零⇒无错误；`slim.gz`+随机⇒`invalid magic at start of compressed archive`；
   `gzip(slim.cpio + 1–3 个 NUL + 随机)`⇒**`broken padding`**；`+4 个 NUL`⇒`junk within compressed archive`。
   ⇒ 以后设备屏上出现这四句中的哪一句，就能直接定位"坏在成员内/成员外/长度/截断"。
4. `hashsum --hash sha256`、`cmp`、`crc64`、`lsefimmap` 模块在该 arm64 deb 里**都有**；
   `hashsum` 在 QEMU 上输出与主机 `sha256sum` 一致（`log-Z1.log`），可作为设备侧读路径判据。

---

## 复现清单（本轮全部产物）

```
reports/artifacts/uefi-grub-memmap-20261115/
  run.sh                        # 单变量 QEMU 跑法：run.sh <tag> <memMB> <initrd-basename>
  menu-hashsum-lsefimmap.cfg    # Shot A 菜单（hashsum 判读 + 同路径 boot）
  00-summary.txt                # 8 次实验的关键行汇总
  log-X1b.log log-X2b.log log-X3b.log        # 位置/尺寸/内存大小 消元（全成功）
  log-Y1.log log-Y2.log log-Y3.log log-Y4.log log-Y5.log   # 错误串指纹标定
  log-Z1.log log-Z2.log         # hashsum 可用性 / lsefimmap 只打表头
主机临时区（不入库）：/tmp/grubsrc/grub-2.14（GRUB 源码）、/tmp/qsay2（QEMU 工作目录）
```
