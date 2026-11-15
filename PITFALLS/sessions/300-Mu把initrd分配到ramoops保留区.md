## #665 Mu UEFI 把 initrd buffer 分配进 DTB 的 `ramoops` 保留区，内核自己的 pstore 控制台把 initrd 中间几 MB 写掉

**现象**：GRUB（arm64 standalone）路径交 64 MB initrd，`Unpacking initramfs...` 之后 ~120 ms 就
`Initramfs unpacking failed: broken padding`；同一份 Image+initrd 在 QEMU 正常（1.5–2.3 s）。

**根因（2026-11-15 定案，一次 A/B 两发）**：
- DTB 的 `ramoops@c2000000`（8 MB，`no-map`）是 **Linux 侧**保留区，Mu UEFI 读不到 ⇒ 它的 `AllocatePages`
  把 64 MB initrd buffer 铺在这个区上面（旧 6 发 base `0xc23e0000` = 落在 buffer **前 4.3 MB**；
  本轮 base `0xc18b0000` = 落在 **+7.67 MB** 处）。
- 内核 **t=0.0269 s** 就把 ramoops 注册成 printk 控制台（`printk: legacy console [ramoops-1] enabled`），
  从此每条 console 输出都往这 8 MB 环形缓冲写 ⇒ **initrd 中间几 MB 被内核自己覆盖** ⇒ 解包到那里即 `broken padding`。
- 判据：**同一颗内核、同一份 initrd、同一菜单，只把 DTB 里的 ramoops 节点删掉** ⇒ 起进 SSH 32 s，
  `ELDEN[unpack-in]/[unpack-out] sum=0x5c53688e`（= 主机期望值），解包 2.31 s；换回带 ramoops 的 DTB ⇒ 立刻失败。

**为什么地址会「玄学平移」**：本机 Mu 无 `EFI_RNG_PROTOCOL` ⇒ KASLR 退化 ⇒ 内核落点只由 Image 尺寸决定
⇒ 内核 +1 MB，initrd buffer 就整体平移（`0xc23e0000` → `0xc18b0000`）。别把「换一版就好了」当结论。

**处置**：
- **1** 诊断顺序 = 先看 `dmesg | grep -E "reserved mem|ramoops"` 的地址，再算 **initrd span 与每个
   `no-map` 保留区的交集**（本轮脚本化核对 46 段）；有交集就是本条。
- **2** 取证件与复现：`patches/local/uefi-initrd-probe-20261115/`（`ELDEN[resv]/[unpack-in]/[unpack-out]/[diag]` 探针 +
   panic_notifier 栈底重打 + 大字菜单）；判据 = `sum=0x5c53688e`。
- **3** 修法优先级见 `reports/uefi-grub-initrd-rootcause-20261115.md` §5：内核 `pstore/ram` 拒绝与 initrd 重叠的 zone（可上游）
   > GRUB 侧对 `/reserved-memory/*` 先 `AllocatePages` 占位（不改 Mu）> 挪 DTB 里的 ramoops（只是把冲突挪走）。
- **4** **`arm64_memblock_init()` 里不要采样 initrd 内容**：那一刻 `__va(initrd)` 还没映射，读一下就挂死（无任何输出）。
- **5** 失败现场仍拍屏或「起得来的那一发」自己 `dmesg` 落盘；pstore 在这里必然留不下（记录写的就是那块被自己写乱的缓冲）。

见 `TASKS/sessions/2026-11-15-UEFI-ramoops-clobber-根因定案.md`、`INDEX.md` §0 第 4 条。
