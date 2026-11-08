# 2026-11-08（下午·上机 1 发）— G1-29 路线 B 首试：p59 + GRUB chainload ESP Loader.efi → **判 indeterminate**

- **日期**：2026-11-08 下午（接同日「路线定案 B + diag 内核备件」轮）
- **pi 会话 id**：`.pi/sessions/*.jsonl`（关键词「espboot-r55 / chainloader / [E] esp in / App Log Flush」）
- **主题**：把 R55（ESP-first `LoadImageAndAuth`）+ `Loader.efi` 放到 ESP，用 GRUB chainloader 上机 1 发
- **结论**：
  1. **上机完成但判 indeterminate**：`fastboot boot` p59 OKAY（1.487 s / 10.106 s），140 s 内 ssh 恒 down，
     之后 fastboot/adb/USB 三路全无；屏上仍是 `[I] ? base=… size=03F40000` → `DBI dump table info not found` → `App Log Flush`，
     与 11-08 上午 EFI-stub 墙**逐行相同**，随后整机掉电重启回 `boot_b`。
  2. **无法判定 B 路线是否跑过**（两个盲区叠加）：① R55 是 RELEASE 构建，EDK2 把 `DEBUG()` 串整段剥掉；
     ② 当时 `grub.cfg` 有 5 条目且 `default=1`，而**本机 GRUB 15 s 超时不自动推进**（用户实测会卡住）⇒
     不排除选到了 `/boot/Image`（EFI-stub 项）。同一份屏照对两种解释都成立 = 实验设计错误。
  3. **已就位的判别件**：`grub.cfg` 收成**单条目**（`set timeout=3` + 只有 chainloader 那条，已写入设备）；
     R56 面板标记补丁件（`[E] esp in/boot sz/dtbo/take/miss`）已派工。
  4. **零写盘、设备安全**：`boot_b` sha `4e38bc2c…` 未变；ESP `fsck.vfat` 干净（曾留 dirty bit，已清）。
     写入面仅 ESP FAT：`/boot/boot.img`（vk184 + 令牌 `elden_bootloader=esp`，`33a67e1f…`）、`/boot/dtbo.img`（`27d54050…`）、
     `/EFI/elden/Loader.efi`（`3a846511…`，176 640 B）。
  5. 顺带发现：**GRUB 超时在本机不自动推进**（会一直停在菜单）——这是操作层坑，已写进报告 §2 与停止条件。
- **下一步（一发定生死）**：R56 到货 → 覆盖 ESP 的 `Loader.efi` → `fastboot boot` p59 →
  **看到 `[E] esp take` 才说明 B 路线真跑了**；连续 2 发拿不到 `[E] esp in` 就转「R54 直接加载 ESP 的 Loader.efi（不经 GRUB）」；
  累计 4 发无进展则本线降级「只跟踪」。
- **证据指针**：
  - `reports/uefi-espboot-r55-indeterminate-20261108.md`（正文 + §6 停止条件）
  - `reports/trials/20261108T063155Z-uefi-p59-espboot-r55.json`（`verdict=INDETERMINATE`）
  - `reports/artifacts/uefi-boot-20261108-143155-p59-espboot/`、`reports/artifacts/esp-stage-20261108/pre.log`
  - 产物 `out/espboot-20261108/{Loader.efi,boot-elden-vk184-espb.img}`、`patches/uefi/20261108R55-espboot/`
- **★SSOT 待并入**：`TASKS/README.md` §5「2026-11-08（下午）」块（本会话已加）+ §1 G1-29 行剩余项一句；
  `PITFALLS` 拟新增一条「RELEASE 剥 DEBUG ⇒ 无标记的实验无法归因」（编号待总管分配）
- **设备态**：U2 在 Linux（vk184，root=`/dev/sda17`），`boot_b` 未变；`grub.cfg` = 单条目（下次经 UEFI 起必走 B）
