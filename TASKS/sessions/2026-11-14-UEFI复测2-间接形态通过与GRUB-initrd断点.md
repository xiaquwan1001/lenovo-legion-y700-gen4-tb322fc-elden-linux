# UEFI 复测第 2 轮：间接形态通过；GRUB 路径卡在 initrd 交接；三处旧判据被推翻

**日期**：2026-11-14（会话 `2026-11-14T13-23-59-069Z`，第二轮设备窗口 22:03–22:33）
**主题**：隔离孤儿 fastboot 进程后，复测 UEFI 两种形态
**结论一句话**：**U2 间接形态（零写盘）通过**（ABL→pc1 Mu UEFI→ESP Loader-r73→ESP `boot.img` vk190→Linux，14 s 到 SSH）；
**新引入的 GRUB 路径卡在 initrd 交接**（36 ms `broken padding`，而同样件在 QEMU 直接启动 6.45 s 成功解包）；
`boot_a` 全程未动，设备始终安全。

**证据指针**：`reports/artifacts/uefi-retest2-20261114-220325/`（含 `20/21` 两发与屏上照片）

---

## 1. ✅ U2 间接形态通过（本轮唯一正结果）

| 项 | 实测 |
|---|---|
| 起法 | `ssh elden-root 'sync; reboot bootloader'` → `fastboot boot out/r21-sbstop-pc1/uefi-preamblec1-r1.img`（零写盘） |
| 链路 | ABL → **pc1 Mu UEFI** → ESP（`/dev/sda18`）`\EFI\BOOT\BOOTAA64.EFI` = **Loader-r73**（`6e51fc60…`）→ `\menu.cfg` → `\boot\boot.img`（vk190，85 819 392 B）→ Linux |
| 耗时 | `fastboot boot` 返回后 **14 s** SSH 可用 |
| 判据（新） | `/proc/cmdline` = `androidboot.serialno=51318dc0`（**CRC32，不是真 SN**）且**无** `verifiedbootstate/hqsysfs/ufsffu`（ABL 追加 token） |
| 旁证 | ESP `\loader.log` = `menu entry n 3 / menu boot \boot\boot.img / pre-bootlinux`；`\espboot.log` = `esp boot 85819392 / vendor_boot 100663296 / dtbo 33554432 / esp done 0` |

**★旧判据作废**：11-10 记录「ESP 路径 cmdline 含 `elden_bootloader=esp`」——现查 ESP `boot.img` 头里**没有**该 token
（`strings | grep -c` = 0）⇒ 该判据已失效，必须改用「serialno = CRC32 + 无 ABL 追加 token」。
（依据 `reports/sn-anchoring-audit-20261113.md`：UEFI 路径的 serialno 来自 cmdline 烤死的 CRC32。）

## 2. ❌ GRUB 路径：内核起来了，但 initrd 交接是断点

本轮先装了自造的 arming GRUB（`\EFI\BOOT\BOOTAA64.EFI` = `45632c79…` → `a63d2ab4…`），三发实测：

| 发 | DTB | 屏上结果 |
|---|---|---|
| 1（22:06，v6） | `elden.dtb` | 内核从 0.000000 有字（`earlycon=efifb keep_bootcon` 成立）→ **15.5 s panic**，栈顶 `memcpy_toio ← ramoops_pstore_write ← pstore_console_write ← … ← free_initrd_mem` |
| 2（22:16，v7） | `elden-nopstorecons.dtb` | 滚到 **16.7 s**，`[15.26] Initramfs unpacking failed: broken padding`，随后只剩背光 |
| 3（22:42，v7） | 预置了 `linux,initrd-start/end` 的 DTB | **仍 `broken padding`**，同 2 |

**站得住的结论**：
- **GRUB→内核交接成立**：屏上 `Hardware name: Lenovo 4/NULL, BIOS 001.2024.12.74 12/23/2024` 是 Mu UEFI 传下来的；
  `earlycon=efifb` 让早期 printk 上屏（`PITFALLS #622` 再证）。
- **initrd 件本身无问题**：主机侧 `zlib` 精确复核 = gzip 单流、`eof=True`、`unused_data=0`、解压 **181 832 192 B（%4=0）**、
  cpio 归档止于 181 832 008、尾部 184 字节全零、零后无数据；设备上 sha `3282ae6c…` 与主机一致；ext4 上是**单 extent**（15771 块连续）。
- **内核解包代码无问题**：QEMU `-kernel` 直接启动**同一份 Image + 同一份 initrd** ⇒
  `Unpacking initramfs...` → **6.45 s** → `Freeing initrd memory: 63080K`，**无 broken padding、无 no cpio magic**。
- **⇒ 断点在 GRUB 交给内核的那一步**：设备上 36 ms 就报错（只解了几百 KB），QEMU 直接启动要 6.45 s ⇒
  GRUB 递过去的 initrd 数据在早期就被截断/错位。

**被推翻的两条「我自己的」假设（必须记住，别再试）**：
1. ❌「`free_initrd_mem` 出现 ⇒ initramfs 解包成功」 —— **错**：解包失败后 `do_populate_rootfs()` 照样调 `free_initrd_mem`。
2. ❌「FDT 无空隙 ⇒ GRUB 扩容 FDT ⇒ initrd 布局错」—— 预置 `linux,initrd-start/end`（`fdtput -t x … 0 0`）后**第 3 发照样 broken padding**，假设被否证。
   （预置本身无害，`/boot/elden*.dtb` 现在是预置版，备份 `*.bak-20261114-224158`。）

## 3. 三处旧判据同时被推翻/收紧

| 旧说法 | 现口径 |
|---|---|
| ESP 路径 cmdline 有 `elden_bootloader=esp` | **失效**（ESP boot.img 头里没这个 token）；改判 serialno=CRC32 + 无 ABL 追加 token |
| `#623`「initrd 已修 ⇒ GRUB 路径能用」 | **只对文件成立**：文件确实好了，但 **GRUB 交接这一步仍会毁掉它**（新坑，见 `PITFALLS #659`） |
| 「UEFI/内核失败可以从 pstore 取证」 | **本轮失效**：`/var/lib/systemd/pstore/console-ramoops-0` 被后续启动覆盖（2 MB → 503 KB），三发的 panic 文本全丢 ⇒ **屏拍照仍是失败细节的唯一通道** |

## 4. 设备现态（收尾）

- `boot_a` **全程未动**：sha `40d43397c14ce4ca18e99f553e618b40e901ed90d0c536dbed4fec76defb18de`（= `out/r21-sbstop-pc1/uefi-preamblec1-r1.img`）；
  `qbootctl` = `_a Active0 Succ0 Bootable1 / _b Active1 Succ1 Bootable1`，现用槽 `_b`。
- ESP `\EFI\BOOT\BOOTAA64.EFI` = **Loader-r73**（`6e51fc60…`，本轮从 `\EFI\elden\Loader.efi` 复制回去，恢复文档验证过的链）；
  arming GRUB 三份备份都在：`BOOTAA64.EFI.arming-v6.bak`（= `244c5f65…` 原 v3b GRUB）、`BOOTAA64.EFI.grub-arming-v7.bak`（= `a63d2ab4…`）。
- `/boot/elden.dtb` = `84c2e0bf…`（预置 initrd-start/end 版，153 193 B）、`/boot/elden-nopstorecons.dtb` = `ac562717…`（153 164 B），
  原件备份 `*.bak-20261114-224158`。
- 设备当前：Linux / `_b` 槽 / 本 boot 由 **ESP 路径**起来（serialno=51318dc0）。

## 5. 下一步（判读，按代价排序）

1. **（主机侧，零设备）** 查 GRUB arm64 的 `initrd`/`linux` 在 64 MB 尺寸上的行为：
   `grub-core/loader/arm64/linux.c` 的 `initrd_start/end` 与 `grub_efi_allocate_pages` 返回区间；
   重点看它是否把 initrd 放在**会与内核镜像重叠**的地址，或 `grub_file_read` 返回值未校验。
   **判据**：能在 QEMU 复现「GRUB + 大 initrd → broken padding」即视为定位（QEMU 的 GRUB 路径当前因 EFI-stub 环境差异起不来内核，需先修 QEMU 侧）。
2. **（设备，1 发）** 把 initrd 换成**小件**（`out/initramfs-slim.cpio.gz` 1 MB）走同一条 GRUB 臂：
   - 若**能过** ⇒ 坐实「GRUB 大 initrd 交接」是唯一断点，接着binary-search 尺寸门限（64 → 32 → 16 MB）；
   - 若**仍 broken padding** ⇒ 与尺寸无关，是 GRUB `initrd` 命令本身在我们这套 FDT 上写错了指针。
3. **（设备，1 发）** U1 flashed 形态：`set_active a` + 重启（`dtbo_a` 已全 0）。
   注意 a 槽现在会被 ESP 的 `BOOTAA64.EFI` 引导 —— 现为 **Loader-r73**（文档验证过的链），不是 GRUB ⇒ 预期能起。
