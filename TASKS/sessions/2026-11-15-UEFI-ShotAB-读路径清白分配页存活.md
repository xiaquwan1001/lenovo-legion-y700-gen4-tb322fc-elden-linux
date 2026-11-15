# 2026-11-15 UEFI GRUB 路径：Shot A / Shot B 上机实测（读路径清白，Mu 分配页成唯一候选）

- **日期**：2026-11-15（12:47–13:07 三发，零写盘；ESP 只换 BOOTAA64.EFI，已回滚）
- **pi 会话 id**：$PI_SESSION_ID
- **主题**：把「GRUB 路径 64 MB initrd 交接坏掉」从两个候选收敛到一个
- **结论**：**C1（Mu UEFI 大块 BlockIo 读回错字节）否证；C2（Mu AllocatePages 给的页被复用/不独占）成为唯一存活候选**
- **证据指针**：`reports/artifacts/uefi-grub-shotA-20261115/`（menu、EFI sha、三发运行日志）、`reports/uefi-grub-initrd-memmap-20261115.md`（判据设计）
- **★SSOT 待并入**：已并入 `TASKS` §4 N1 行、`INDEX` §0 第 4 条、`PITFALLS` #659 追加与 #664（ESP 满导致 install 半成功）

## 1. 方法（关键改进：判决产物写进 ext4 的 grubenv，宿主机直接读，不靠屏拍照）

GRUB 读 ext4 后：`hashsum --hash sha256 -p ($root) -c ($root)/boot/shotA.sha` →
`if ...; then set elden_shotA_sha=OK; else ...=BAD; fi` → `save_env -f ($root)/boot/grub/grubenv elden_shotA_sha`。
`save_env` 属 `loadenv` 模块（GRUB 2.14 里**没有** saveenv.mod），且 **grubenv 必须先存在**（`grub-editenv create`），否则报 file not found。
机制先在 QEMU 打了正反两例（正例 OK / 篡改一字节 ⇒ BAD），才上设备。

## 2. 三发上机（每发：`reboot bootloader` → `fastboot boot out/r21-sbstop-pc1/uefi-preamblec1-r1.img` → 等 SSH 回来 → 读 grubenv）

| 发 | 菜单臂 | grubenv 判决 | 判读 |
|---|---|---|---|
| 1 | Shot A：只 hash 不启动，写完 reboot | `elden_shotA=1-done`、`elden_shotA_sha=OK` | **GRUB 经 Mu BlockIo 读 64 MB initrd 与 63 MB Image，sha 与主机逐字相同**（3282ae6c… / 0cdb7a45…）⇒ **C1 否证** |
| 2 | Shot B：`linux … initrd=/boot/initrd.img`（不走 LoadFile2，改走 EFI SimpleFileSystem，仍由 Mu 分配页） | `elden_shotA=B-selected`，设备 110 s 后以 ABL 正常启动回来（serialno=HA2EXB0E） | 内核**没起来** ⇒ 换一条读文件路径仍坏 |
| 3 | Shot B2：加了 B-dtb-ok / B-linux-ok-booting 两个中间标记 | `elden_shotA=B-linux-ok-booting` | 排除「GRUB 没 stage 内核」：dtb 与 Image 都装载成功、内核确实被启动，仍没到用户态 ⇒ **坏在 Mu 给的那片内存** |

## 3. 结论与下一步

- 两条完全不同的「读文件 → 填 buffer」路径（GRUB 自己读 vs 内核 SFS 读）**都**拿不到可用 initrd，而 GRUB 自己的读**内容正确**
  ⇒ 剩下唯一能同时解释两者的点：**Mu UEFI 的 AllocatePages 返回的页被别的东西同时写**（或其内存图把可用区描述错，见
  Mu 侧 Conv 只有 0xB90C0000–0xD65C0000 = 469 MiB、0xD65C0000–0xFC800000 共 612 MiB **无条目**）。
- **下一步（主机侧先做）**：给 Mu 件插桩打印 allocation / memory map（SbMark / FrameBufferSerialPortLib），或直接把那 612 MB 标 Reserved / 补齐 Conv 后重打 pc1 —— 都是**另一个固件件、另一发**，不是 GRUB 侧能修的。
- 本轮**未**动 boot_a、未 flash 任何分区；ESP BOOTAA64.EFI 已回滚到 Loader-r73（6e51fc60…）。

## 4. 过程中踩到的两个坑（已入 PITFALLS）

1. **ESP 满 ⇒ esp-install-grub.sh --activate 半成功**：备份那步报「设备上没有空间」，但脚本继续 cp 覆盖 →
   第 3 发实际跑的是**上一版 EFI**（菜单里没有新标记，判决与第 2 发逐字相同，差点误判成「标记没生效」）。
   ⇒ 装件前后都要 df + 核对 sha256sum BOOTAA64.EFI 与预期一致。
2. **他项目遗留的孤儿 fastboot oem dump-emmc（kirin-tool，2 h 36 min 无进展）会抢通道**（PITFALLS #658 同源）：
   本轮清掉两条后才 fastboot boot，三发 getvar product 均 4 ms 返回。
