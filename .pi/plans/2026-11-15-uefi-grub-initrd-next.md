# 明天待查方向：UEFI GRUB 路径的 initrd 交接

> 起点（2026-11-14 夜收尾状态）：**U2 间接形态已通过**（ESP Loader-r73 链，14 s 到 SSH，零写盘）；
> **GRUB 路径卡在 initrd 交接**；`boot_a` 未动、`_b` 槽、ESP 已恢复 Loader-r73。
> 详见 `TASKS/sessions/2026-11-14-UEFI复测2-间接形态通过与GRUB-initrd断点.md`、`PITFALLS #659`。

---

## 0. 已经排除的（别再试，省下明天的设备窗口）

| 假设 | 怎么否证的 |
|---|---|
| initrd 文件坏 | 主机侧 zlib 精确复核：gzip 单流、`eof=True`、`unused_data=0`、解压 181 832 192 B（%4=0）、cpio 止于 181 832 008、尾部 184 字节全零；设备 sha 一致 |
| ext4 碎片导致 GRUB 读不全 | `filefrag` = **单 extent**（15771 块连续） |
| 内核解包代码有 bug | QEMU `-kernel` 直接启动同件 → 6.45 s 解包成功 |
| FDT 无空隙 ⇒ GRUB 扩容 FDT ⇒ 布局错 | `fdtput` 预置 `linux,initrd-start/end` 后第 3 发照样 `broken padding` |
| `/chosen` 地址单元是 32 位 ⇒ 地址截断 | `/ #address-cells = 2`、`/chosen #address-cells = 2`，无截断 |
| `free_initrd_mem` 出现 ⇒ 解包成功 | 错判（失败后照样调）。判据改为**解压耗时** |

## 1. ★本轮最重要的新进展：QEMU 已能复现「GRUB + 64 MB initrd」

**结论**：`AAVMF(QEMU_EFI.fd)` + 同一份 GRUB（arm64 standalone）+ 同一份 Image + 同一份 64 MB initrd
⇒ `0.388s Unpacking initramfs...` → `2.278s Freeing initrd memory: 63080K`，**1.89 s 成功，无 broken padding**。

⇒ **GRUB 通用逻辑没问题，断点收窄到「我们的 Mu UEFI（pc1 载荷）环境 / 它给的内存图」**。

**可复用的 QEMU 配方（明天直接用）**：

```bash
W=/tmp/qsay; mkdir -p $W/esp/EFI/BOOT $W/esp/boot
cp out/vk188-bootfiles/Image  $W/esp/boot/Image
cp out/vk188-bootfiles/initrd.img $W/esp/boot/initrd.img
# ★ 关键：菜单里【不要】写 devicetree —— 我们在 virt 上，必须让内核用 QEMU 自己的 DTB，
#   否则加载骁龙板 DTB（无 pl011/virtio）⇒ 连控制台都没有，全程静默（今晚踩过这个坑）
cat > $W/menu.cfg <<'EOF'
set timeout=3
set default=0
insmod all_video
insmod font
insmod gfxterm
insmod ext2
insmod part_msdos
insmod search
insmod linux
menuentry "QEMU GRUB initrd test" {
  set root=(hd0,1)
  linux ($root)/boot/Image console=ttyAMA0,115200 loglevel=8 ignore_loglevel panic=0 rdinit=/nonexistent
  initrd ($root)/boot/initrd.img
}
EOF
WORK=$W/grub MODULES="normal linux ext2 fat part_msdos search search_label echo test sleep reboot halt minicmd cat ls configfile font gfxterm gfxmenu all_video video" \
  CFG=$W/menu.cfg bash scripts/grub-arm64-standalone.sh
cp $W/grub/grubaa64.efi $W/esp/EFI/BOOT/BOOTAA64.EFI
timeout -k 5 100 qemu-system-aarch64 -M virt,acpi=off -cpu cortex-a72 -m 4096 -smp 4 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -drive file=fat:rw:$W/esp,format=raw,if=virtio \
  -display none -device ramfb -serial file:$W/qbig.log >/dev/null 2>&1
grep -aE "Unpacking|broken padding|Freeing initrd|Kernel panic" $W/qbig.log
```

**判据**：`Unpacking initramfs...` 到 `Freeing initrd memory` 的**耗时**。
- ~2 s（QEMU 实测 1.89 s）/ 设备正常 6.45 s ⇒ 真解压，成功；
- **几十 ms** ⇒ 没真解压，交接坏了（就是设备上那 36 ms）。

## 2. 明天的主攻方向（按性价比排序）

### D1【主机侧，零设备，首选】把 Mu UEFI 的内存图拿下来，看 GRUB 会把 initrd 放哪

为什么可能是内存图：QEMU（标准 EDK2）能过、我们的 Mu 件不能过，两者最大的差异就是 **UEFI 给的内存图**。
若 GRUB 拿到的空闲区落在**我们 DTB 的 `reserved-memory` 里**（ramoops@c2000000 8 MB、adsp 堆、gunyah 区…），
内核 boot 早期按 DTB 初始化这些区 ⇒ **把 initrd 覆盖掉** ⇒ 表现正是「快速外伤式损坏」。

已有线索支持这条：第 1 发 panic 栈顶是 `memcpy_toio ← ramoops_pstore_write`，落在 **ramoops 那片 no-map 区**。

做法（零设备）：
1. `patches/uefi/` 的 Mu 源码树里查 `gBS->GetMemoryMap` 相关初始化，或直接看 ABL/Mu 的 `PlatformMemMap` 定义，
   列出 **被标成 EfiConventionalMemory / EfiBootServicesData 的高地址区**。
2. 与 `out/vk188-bootfiles/elden-nopstorecons.dtb` 的 `/reserved-memory/*` 逐段比对，找**交集**。
3. 若找到交集 ⇒ **修法明确**：在 GRUB 菜单里先 `devicetree` 加载 DTB 后，让 GRUB 感知不到那些保留区是禁止的…
   （更实际的做法见 D2-a：换 DTB 把冲突区先删掉做单变量验证）。

### D2【设备侧，1 发/次】用「小 initrd」做尺寸二分，把断点性质确定下来

这是**最省的一发**，能直接分开两类完全不同的病：

| 结果 | 含义 | 后续 |
|---|---|---|
| 小 initrd（`out/initramfs-slim.cpio.gz`，1 MB）**能过** | 是**尺寸/落点**问题（D1 那条内存图假设） | 二分 1 → 8 → 32 → 64 MB 找门限；门限附近看是否恰好撞上某个 reserved 区 |
| 小 initrd **仍 `broken padding`** | 与尺寸无关，是 GRUB `initrd` 命令在我们 FDT 上**写错了指针** | 转 D3 |

**做法**：把 arming GRUB 菜单的 `initrd` 指向 ESP 上的小件（ESP 只读，不动 linux17），`fastboot boot` pc1 一发，**拍屏**（pstore 不保现场，见 §3）。

### D3【设备侧，1 发】在 GRUB 里把 `chosen` 的 initrd 属性回显出来

GRUB 有 `lsefimmap` / `lsefienv` 等模块可打印内存图；也可在 `initrd` 之后用 `echo` 打 FDT 里的值（受限）。
若 D2 落到「与尺寸无关」，就需要知道 GRUB 到底写了什么地址 ⇒ 这一发是指向性的。

替代更省的办法：GRUB 的 `save_env -f ($esp)/grubenv <var>` 能把**一个小值**（initrd 起址）写回 ESP，
Linux 起来后 `cat` 出来（但失败时起不到 Linux…）。所以还是**拍屏**最实际。

### D4【设备侧，1 发，价值高但与 GRUB 无关】U1 flashed 形态

`dtbo_a` 已全 0、`boot_a` = pc1 UEFI 原件（`40d43397…`）⇒ `set_active a` + 重启即可测。
**注意**：a 槽现在会被 ESP 的 `BOOTAA64.EFI` 引导，而它已恢复成 **Loader-r73**（验证过的链）⇒ 预期能起。
**风险**：a 槽 `Successful=0`，ABL 每发扣 retry；失败立刻 `fastboot set_active b`。
**判据**：≤180 s SSH + cmdline 里 `serialno=51318dc0`（ESP 路径标志）。

## 3. 三条必须遵守的取证纪律（本轮用血换的）

1. **pstore 不保 UEFI 失败现场**：连续失败几发后 `/var/lib/systemd/pstore/console-ramoops-0` 会被后续启动覆盖
   （实测 2 MB → 503 KB）。⇒ **屏拍照是失败细节的唯一通道**，失败当下就要拍，且每次只发一个变量。
2. **判「有没有真解压」用耗时**，不要用 `Freeing initrd memory` 有没有出现（失败后照样出现）。
3. **判「走的哪条链」用 `androidboot.serialno`**：ESP 路径 = `51318dc0`（CRC32）且**无** `verifiedbootstate/hqsysfs/ufsffu`；
   b 槽路径反之。旧的 `elden_bootloader=esp` 判据**已失效**。

## 4. 明天的设备就绪检查（开工前跑）

```bash
pgrep -af "[f]astboot"                       # 必须为空（隔壁项目的孤儿会抢通道，PITFALLS #658）
fastboot devices                             # 能列出 SN 只证明枚举
fastboot -s HA2EXB0E getvar product          # 真正的门：5 s 内必须返回
ssh elden-root 'qbootctl; head -c 67186688 /dev/disk/by-partlabel/boot_a | sha256sum'
#  期望：_a Active0 Succ0 Bootable1 / _b Active1 Succ1；boot_a = 40d43397…
ssh elden-root 'sha256sum /efi/EFI/BOOT/BOOTAA64.EFI'   # 期望 6e51fc60…（Loader-r73）
```

## 5. 备好的件（都在盘上，明天直接用）

| 件 | 用途 |
|---|---|
| `out/grub-20261114/grubaa64-arming-v6.efi`（`a63d2ab4…`）+ `arming-menu.cfg` | arming GRUB，默认臂带 `earlycon=efifb keep_bootcon panic=0` + grubenv 留痕 |
| `scripts/grub-arm64-arming-build.sh` | 重打该件（自校验 PE/menuentry/三档字体/cfg 抽样） |
| `scripts/esp-install-grub.sh --efi … --tag … --activate` / `--rollback` | 装机与回滚 |
| `patches/uefi/20261114-grub-arming-menu/` | 菜单源（可复现） |
| ESP 备份 | `BOOTAA64.EFI.arming-v6.bak`=`244c5f65…`(原 v3b GRUB)、`BOOTAA64.EFI.grub-arming-v7.bak`=`a63d2ab4…` |
| `out/initramfs-slim.cpio.gz`（1 MB） | D2 的小 initrd 单变量 |
| `/tmp/qsay/`（QEMU 工作目录） | 配方已跑通，重启后按 §1 重建 |

---

## ★2026-11-15 勘误与增量（主机侧 lane 收口，权威 = `reports/uefi-grub-initrd-memmap-20261115.md`）

> 本节覆盖上文 §0/§1 里**已作废**的两条假设，其余保留。

| 上文说法 | 现口径（2026-11-15，源码 + QEMU 八发实测） |
|---|---|
| ~~GRUB 分配 initrd 内存并把 initrd 放错地方~~ | **作废**：`/boot/Image` 的 PE `MajorImageVersion=3`(实查) ≥1 ⇒ GRUB 走 **LoadFile2**，只装 `EFI_LOAD_FILE2_PROTOCOL`（`grub-core/loader/efi/linux.c:135` 判定、`:420-451` 安装），**不分配不搬运**；64 MB `AllocatePages` 由**内核 EFI stub 经 Mu 分配器**做 |
| ~~GRUB 在 ExitBootServices 前后搬移 initrd / 受限 4 GiB 地址~~ | **作废**：QEMU 里 64 MB 被放到 `0x12b660000`（**4.68 GiB**）仍 1.60 s 成功；`-m 2048`（4 GiB 以下）与 16 MB 也都成功 |
| —— | **新增判读**：`broken padding` 来自 `init/initramfs.c:338`（`build/daily`）的 cpio `do_reset()`，指纹 = 「成员**内部**提前结束 + 1–3 NUL + 垃圾」；真截断是 `read error`，短 gzip+全 0 什么都不打 ⇒ 设备 37 ms 意味着**只解出几 MB 就错位** |
| —— | **下一发 = 单比特判决（未执行）**：GRUB 侧 `hashsum --hash sha256` 算同一读路径的 initrd sha；不匹配 ⇒ Mu 大块 BlockIo 读错；匹配仍坏 ⇒ Mu 分配页被复用（再上 Shot B 走 SFS 路径） |

