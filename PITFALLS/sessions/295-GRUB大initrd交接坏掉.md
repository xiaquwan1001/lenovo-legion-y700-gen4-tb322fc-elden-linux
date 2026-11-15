## #659 GRUB（arm64 standalone）把 64 MB initrd 交给内核时数据被毁：设备上 36 ms 就 `Initramfs unpacking failed: broken padding`，而同一份件在 QEMU `-kernel` 直接启动要 6.45 s 才解包成功

结论: 2026-11-14 实测 —— **initrd 文件、内核解包代码都没问题，断点在 GRUB 交给内核这一步**。判据组合（缺一不可）：
① 主机侧 `zlib` 精确复核 initrd：gzip 单流、`eof=True`、`unused_data=0`、解压 181 832 192 B（%4=0）、cpio 归档止于 181 832 008、尾部 184 字节全零、零后无数据；设备侧 sha 与主机一致；ext4 上是**单 extent**（`filefrag` 15771 块连续）。
② QEMU `-kernel <同 Image> -initrd <同 initrd>` 直接启动（绕开 GRUB/UEFI）⇒ `Unpacking initramfs...` → **6.45 s** → `Freeing initrd memory: 63080K`，无任何 unpack 错误。
③ 设备走 GRUB arm64 standalone（`\EFI\BOOT\BOOTAA64.EFI`，嵌入菜单，`linux`+`initrd`+`devicetree`）⇒ `Unpacking initramfs...` 之后 **36 ms** 就 `broken padding`。
⇒ 解压耗时差 180 倍 = 设备上只解了几百 KB 就撞错 ⇒ **GRUB 递过去的 initrd 数据早期被截断/错位**（不是尺寸不够、不是 DTB 问题，见下）。

判据: 屏上 `Unpacking initramfs...` 之后**几十毫秒**就报 `broken padding` / `no cpio magic` ⇒ **先怀疑交接方（GRUB/Loader），不要怀疑 initrd 件**。真解压 60+ MB 要**数秒**（本机 QEMU 实测 6.45 s），时间对不上就是没真解压。

两条必须记住的**错判**（都是我本轮踩的）：
- ❌「看到 `free_initrd_mem` / `Freeing initrd memory` ⇒ initramfs 解包成功」——**错**：`do_populate_rootfs()` 解包失败后照样调 `free_initrd_mem`。这句话只能证明「populate_rootfs 跑到了」，不能证明解包成功。
- ❌「FDT 结构块与字符串块之间无空隙（gap=0）⇒ GRUB 为写 `linux,initrd-start/end` 必须扩容 FDT ⇒ initrd 布局错」——**假设已被否证**：用 `fdtput -t x <dtb> /chosen linux,initrd-start 0 0` 预置两个属性（GRUB 变成原地改值、不扩容）后，**第 3 发照样 `broken padding`**。预置本身无害可保留，但它**不是**修法。

**收窄一层（同轮深夜追加）**：QEMU `AAVMF(QEMU_EFI.fd)` + 同一份 GRUB + 同一份 64 MB initrd ⇒ `[0.388] Unpacking` → `[2.278] Freeing initrd memory: 63080K`（**1.89 s，无 broken padding**）。
⇒ **GRUB 的 initrd 通用逻辑本身没问题**，断点在**我们的 Mu UEFI（pc1 载荷）环境 / 它给的内存图**（QEMU 标准 EDK2 与我们 Mu 件最大差异就是内存图；且第 1 发 panic 栈顶正落在 `ramoops` 那片 `no-map` 区）。
**QEMU 配方的坑**：菜单里**不能**写 `devicetree` —— virt 上加载骁龙板 DTB（无 pl011/virtio）会让内核连控制台都没有，全程静默、误判成"内核没起来"。

处置: 见 `TASKS/sessions/2026-11-14-UEFI复测2-间接形态通过与GRUB-initrd断点.md` §5、明天的完整清单 `.pi/plans/2026-11-15-uefi-grub-initrd-next.md` —— ①主机侧查 `grub-core/loader/arm64/linux.c` 的 initrd 分配/读取（重点：`grub_efi_allocate_pages` 返回区间是否与内核镜像重叠、`grub_file_read` 返回值是否校验）；②设备发小 initrd（1 MB slim）走同一臂做尺寸二分；③不想查就用**已验证的 ESP Loader 链**（`Loader-r73` + `\menu.cfg` + `\boot\boot.img`），那条链 2026-11-14 实测 14 s 到 SSH。

附带两条同轮定案：
- **ESP 路径的判据换了**：旧说法「cmdline 含 `elden_bootloader=esp`」**已失效**（ESP `boot.img` 头里没这个 token，`strings | grep -c` = 0）；新判据 = `/proc/cmdline` 里 `androidboot.serialno=51318dc0`（CRC32，**不是**真 SN `HA2EXB0E`）且**无** ABL 追加的 `verifiedbootstate/hqsysfs/ufsffu`。
- **pstore 不保 UEFI 失败现场**：连续几发失败后 `/var/lib/systemd/pstore/console-ramoops-0` 会被后续启动覆盖（实测 2 MB → 503 KB），panic 文本全丢 ⇒ **屏拍照仍是失败细节的唯一通道**。

证据指针: `reports/artifacts/uefi-retest2-20261114-220325/`（`10/13` 两发屏上照片、`21-u2b-loader.txt` 通过判据、`12-dtb-padded-install.txt` 否证记录）

**2026-11-15 增量（主机侧 lane，权威 `reports/uefi-grub-initrd-memmap-20261115.md`）—— 上一段「查 GRUB 的 `grub_efi_allocate_pages`」这条处置作废**：

- **GRUB 根本不分配 initrd**：我们的 `/boot/Image` PE `MajorImageVersion = 3`（实查，>=1 即可），GRUB 2.14 在 `grub-core/loader/efi/linux.c:135` 判定后走 **LoadFile2 分支**（`:420-451` 只装 `EFI_LOAD_FILE2_PROTOCOL`），64 MB 的 `AllocatePages` 是**内核 EFI stub 调固件（Mu）分配器**做的。
- **`broken padding` 的正确指纹**（QEMU 标定）：它来自 `init/initramfs.c` 的 cpio `do_reset()`，含义 = 「gzip 成员**内部**提前结束 + 1–3 NUL + 非零垃圾」；真截断打 `read error`，短 gzip + 全 0 什么都不打，短 gzip + 垃圾打 `invalid magic at start of compressed archive`。设备只花 37 ms ⇒ **只解出几 MB 就错位**，不是「末尾被截」也不是「尺寸不对」。
- **判决用一发单比特**：GRUB 侧 `hashsum --hash sha256`（同一读路径）与主机 sha 比；不匹配 ⇒ Mu 大块 `BlockIo` 读回错字节；匹配仍坏 ⇒ Mu `AllocatePages` 的页被别处复用。
