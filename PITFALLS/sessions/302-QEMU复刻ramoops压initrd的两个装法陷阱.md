## #666 QEMU 复刻「ramoops 盖住 initrd」时两个必踩的装法陷阱：`-dtb` 与 `-device loader` 抢同一地址；`-initrd` 让物理地址不可控

**症状**：想在一台 QEMU（`-M virt`）上复现「ramoops zone 压住 initrd ⇒ 内核 pstore 控制台写坏 initrd」，
两发都起不来——要么 QEMU 直接拒启动，要么 `initrd=` 与 `-initrd` 混用后 ramoops 与 initrd 根本不重叠、复现不出破坏。

**判据/成因**：

- **`-dtb` 与 `-device loader` 抢同一地址**：`-M virt` + `-m 2048` 时，`-dtb` 默认装在 `0x48000000`**（RAM 尾部 128 MiB 处）。
   若同时用 `-device loader,file=initrd,addr=0x48000000`，QEMU 报
   `The following two regions overlap (...): initrd (0x48000000-...) dtb (0x48000000-...)` 并**拒绝启动**
   （不是内核问题，也不是 dtb 内容问题）。
- **`-initrd` 让物理地址不可控**：initrd 想被 `initrd=<phys>,<size>` 钉在指定物理地址，就必须**自己把文件 load 进内存**
   （`-device loader,file=…,addr=…,force-raw=on`），**不能再用 `-initrd`**：`-initrd` 的落点由 QEMU 算，
   拿不到可预期的物理地址，ramoops 节点也就没法精确压上去。

**处置**：initrd 与 ramoops 统一挪到 `0x50000000 / 0x4ff00000`（离 `-dtb` 的默认落点足够远）；
脚本 = `scripts/qemu-ramoops-initrd-ab.sh`（`--expect-fail` 跑无守卫内核验证「真能复现」）。
ramoops 节点插在 QEMU 自己 `-M virt,dumpdtb=` 出来的 dtb 里（`dtc` 反编译 → 插节点 → 再编译），
布局 `dmesg | console | pmsg | ftrace` 顺排，让 **console 段**正好压住 initrd 起点——那一段才是真机上的凶手。

**验证**：守卫版（`fs/pstore/ram.c` 的 `ramoops_skip_zone`）串口出
`ignoring console zone … overlaps the initrd` + `Run /init`；无守卫版出
`Initramfs unpacking failed: invalid magic at start of compressed archive`。
账：`reports/pstore-ram-initrd-guard-20261116.md`、`patches/upstream/pstore-ram-initrd-overlap-20261116/`。
