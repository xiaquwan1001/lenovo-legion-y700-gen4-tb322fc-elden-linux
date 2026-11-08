# G1-29 路线 B 第一发（p59 + GRUB chainload ESP Loader.efi）：**判 indeterminate —— 与 EFI-stub 墙逐行相同**

> 线：G1-29（拓展，非主线）。设备 = U2 `HA2EXB0E`。**零写盘**（只动 ESP 的 FAT 文件），`boot_b` sha 全程 `4e38bc2c…`。
> 承接 `reports/uefi-grub-esp-handoff-wall-20261108.md`、`reports/route-b-impl-20261108.md`（R55 补丁 + Loader.efi）、
> `.pi/plans/2026-11-08-g1-29-route-b-espboot.md`（D1–D5）。

---

## 0. 结论（一句话）

**没拿到判别证据，因此不能说路线 B 失败，也不能说它跑过。** 屏上与 11-08 上午的 EFI-stub 墙**逐行相同**，
而 R55 的 RELEASE 构建把 DEBUG 串剥掉了 ⇒ 无法区分「我们的 `Loader.efi` 跑了」与「GRUB 又选了 `/boot/Image`（EFI-stub）」。
已按纪律停手，改走「加面板标记」的判别件（R56，见 §5）。

## 1. 这一发的账

| 项 | 值 |
|---|---|
| 固件 | `out/r21-sbstop-p59/uefi-preamble59-r1.img`（`cd73fbdc…`，p59 = p58 + R54-espfirst） |
| 上机方式 | `fastboot boot`（Sending 1.487 s / Booting 10.106 s，OKAY） |
| GRUB 条目 | `set default=1` → 「Elden ESP loader（chainloader ESP 上的 Loader.efi）」 |
| ESP 内容（前置 sha 双侧核对一致） | `/boot/boot.img` 85 594 112 B（vk184 + 注入令牌 `elden_bootloader=esp`，sha `33a67e1f…`）、`/boot/dtbo.img` 33 554 432 B（来自 `dtbo_b`，`27d54050…`）、`/EFI/elden/Loader.efi` 176 640 B（`3a846511…`，R55） |
| 观测 | 14:33:34 起 **140 s 内 ssh 恒 down**；其后 **fastboot / adb / USB 三路全无**（与前两发「~75 s 自动回 `boot_b`」不同） |
| 用户侧屏上（关键） | `[I] ? base=00000000C5D80000 size=03F40000` → `DBI dump table info not found, Status = (0x0)` → `App Log Flush : 0 ms`，随后**随机掉电**、重启回 Linux |
| pstore | 本次 boot **无新记录**（`/sys/fs/pstore` 空；`/var/lib/systemd/pstore` 最新仍是 11-05 23:40） |
| `journalctl --list-boots` | 每次尝试只多一条（回 `boot_b` 那次） |
| trial record | `reports/trials/20261108T063155Z-uefi-p59-espboot-r55.json`（`verdict=INDETERMINATE`） |

## 2. 为什么「不能判定」（两条独立的盲区）

1. **构建把标记剥了**：R55 的 `Loader.efi` 是 `TARGET=RELEASE` 构建，EDK2 的 RELEASE DebugLib 把 `DEBUG()` 串整段丢弃
   （见 `reports/route-b-impl-20261108.md` §3.2，作者已提示）。⇒ 即使 `Loader.efi` 真跑了，屏上也不会多一行。
2. **菜单有歧义 + 超时不自动推进**：本轮 `grub.cfg` 有 5 个条目、`set default=1`；而本机 **GRUB 的 15 s 超时不会自动推进**
   （用户实测：曾因此卡在菜单不动）。若当时是手动/超时选中了另一条（`/boot/Image` = EFI-stub 内核），
   屏上必然就是现在这三行 —— 与 11-08 上午完全一致。

⇒ 两个盲区叠加，**同一份屏照同时兼容「B 路线撞同一面墙」和「B 路线根本没跑」**。这种实验设计本身就是错的（`PITFALLS` 关于单变量/判据唯一性的老账）。

## 3. 本次已就位的判别件（消除歧义，未上机）

1. **`grub.cfg` 收成单条目**（`/boot/grub/grub.cfg`，已写入设备）：
   `set timeout=3`，唯一条目 = `search --label ELDENESP` + `chainloader ($esp)/EFI/elden/Loader.efi`。
   ⇒ 菜单不再有第二个可选项，超时/手选都只会走 B。
2. **R56 面板标记件**（派工单已下）：`[E] esp in` / `[E] esp boot sz=<n>` / `[E] esp dtbo=<sz|none>` / `[E] esp take` / `[E] esp miss <Status>`，
   走本树已验证的面板通道 `SerialPortWrite`（R21 惰性初始化）。判据：**看到 `[E] esp take` 才说明 ESP-first 真跑了**。

## 4. 设备侧现状（安全）

- 当前在 Linux（`7.3.1-debug-vk184-00003-gec74c4795a43`，root=`/dev/sda17`），`boot_b` sha `4e38bc2c…` 未变；
- ESP 三件在位、`fsck.vfat` 干净（曾因一次 `umount` 未同步留下 dirty bit，已 `fsck.vfat -a` 清掉并复核 9 files / 30817 clusters）；
- `grub.cfg` 已改为单条目；`/boot/{Image,Image.fbdiag,Image.vk184.bak}` 均在，`grub.cfg.bak-20261108` 为回退件。

## 5. 下一步（R56 到货后一发）

1. 把 `out/espboot-20261108/Loader-r56.efi` 覆盖到 ESP `/EFI/elden/Loader.efi`（FAT，零写盘）；
2. `fastboot boot` p59；
3. **判据（三条全中才算 B 路线跑过）**：屏上出现 `[E] esp take` → 之后内核起（ssh 通 / `/proc/cmdline` 含 `elden_bootloader=esp`）
   → `boot_b` sha 不变。
4. 若看到 `[E] esp miss <Status>`：按 Status 定位（缺文件/读失败/pool 不足），这是**可归因的失败**，不是墙。
5. 若**连 `[E] esp in` 都没有**：说明 chainloader 根本没执行到我们的 PE ⇒ 问题在 GRUB 侧（`search` 标签、`chainloader` 语义、ESP 卷识别），
   与内核/内存表无关，回到 GRUB 侧取证。

## 6. 停止条件（提前写明，避免无限试错）

- 连续 **2 发**仍拿不到 `[E] esp in` ⇒ 停 B 路线的 GRUB 侧，转「用 p59 的 R54 直接加载 ESP 的 `Loader.efi`」（不经 GRUB）。
- 拿到 `[E] esp take` 但内核仍不起 ⇒ 问题在 BootLinux 的内存图（`BaseMem`/`SetandGetLoadAddr`），
  这时才考虑 A 路线（`PlatformMemoryMapLib` 给 DDR 标 Conv），**且必须先出静态 diff 再上机**。
- 累计 **4 发**无进展 ⇒ 本线整体降级回「只跟踪」，把时间还给 G1 剩余/G2/G3（写进 `TASKS` §4）。

## 7. 证据指针

- `reports/artifacts/uefi-boot-20261108-143155-p59-espboot/{fastboot-boot.log,observe.log,pre.log,verdict.md}`
- `reports/artifacts/esp-stage-20261108/pre.log`（ESP 落件与 sha 核对全过程）
- `out/espboot-20261108/{Loader.efi,boot-elden-vk184-espb.img}`、`patches/uefi/20261108R55-espboot/`
- 计划 `.pi/plans/2026-11-08-g1-29-route-b-espboot.md`；实现 `reports/route-b-impl-20261108.md`
