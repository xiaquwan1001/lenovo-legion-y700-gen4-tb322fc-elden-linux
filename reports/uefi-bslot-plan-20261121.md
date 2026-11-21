# UEFI「纯 b 槽」部署 + GRUB 菜单加 a 槽安卓 —— 可行性与方案（2026-11-21）

## 0. 先回答两个问题

**Q1：UEFI 能不能只靠 b 槽部署？** —— **能，而且比 a 槽更干净**。但**不能**沿用「把 UEFI 塞 `boot_b`」这种做法，
因为 `boot_b` 现在是**唯一**的 Linux 直启路径（ABL `BootLinux` 直接读 `boot_b`，今天在机 vk192 就是这么起的）。
推荐形态 = **b 槽三分区分工**：

| 分区（b 槽） | 现内容 | 建议用途 | 代价 |
|---|---|---|---|
| `boot_b` 96M | 我们的 Linux boot.img（vk192） | **保持不动**（ABL 直启 Linux 的回退路径） | 零 |
| `recovery_b` 100M | 原厂 Android recovery（`ANDROID!`） | **换成 UEFI 载荷**（boot.img 形状，内核位放 Mu/GRUB 件） | 失去 b 槽 recovery（不影响 Linux） |
| `vendor_boot_b` 96M | 原厂 vendor_boot（Android b 槽用） | **改造成 FAT32 ESP**（放 `EFI/BOOT/BOOTAA64.EFI` + `/boot/Image` + initrd + `grub.cfg`） | 失去 b 槽 Android 启动能力（a 槽 Android 不受影响） |
| `dtbo_b` 32M | **全 0**（实测前 16 字节全零） | 不用动 | —（当年 a 槽卡 logo 就是 `dtbo_a` 是原厂 Android DTBO，b 槽天生没这问题） |
| `vbmeta_b` 64K | 自签 `1e54e86e…`、Flags 3、整链验签 rc=0（2026-11-21 了结） | 不用动 | — |

**为什么这样分**：UEFI 载荷必须以 Android boot image 形状存在（ABL 只认这个），而 ABL 进 recovery 的唯一触发
是 `misc` 的 BCB = `boot-recovery` —— 这条**有实测先例**（2026-11-19 现场 `misc=boot-recovery`，设备确实起了
recovery）。所以「平时直启 Linux（boot_b），需要时写 BCB 进 GRUB」可以并存，**不牺牲任何现有能力**。

**Q2：GRUB 菜单里能放 a 槽安卓吗？** —— **能，但不是"chainload Android boot.img"**。GRUB 不认 Android
boot 头，正确做法是把 a 槽**拆成 GRUB 能吃的三件**再 `linux` 启动（下面的方案 G）。

## 1. 现状（2026-11-21 设备实测，只读）

| 事实 | 证据 |
|---|---|
| **ESP 已不存在**：`/dev/sda18` 没有这个设备、`/boot/efi` 未挂 | `ls -l /dev/sda18` = 无；`lsblk /dev/sda` 只到 `sda17`。11-19 重建 LUN0 GPT（`linux17` + `userdata` 手术）把当年的 ESP 干掉了 |
| ⇒ **UEFI 链当前完全没有部署**：设备是 ABL 直接读 `boot_b` 起 Linux | `uname -r` = vk192；ESP 无挂载点；`boot_a` = 原厂 Android boot v4 |
| b 槽固件分区是完整一套 | `uefi_b 5M`、`abl_b 1M`、`hyp_b 8M`、`tz_b 5M`、`aop_b`、`devcp_b`、`cpucp_b`、`featenabler_b`、`uefisecapp_b`、`xbl_b`(LUN2)… |
| b 槽可引导分区 | `boot_b 96M`、`dtbo_b 32M`、`vbmeta_b 64K`、`vendor_boot_b 96M`、`init_boot_b 8M`、`recovery_b 100M` |
| `dtbo_b` 全 0 | `dd … dtbo_b` 前 16 字节 = `00 ×16` |
| `recovery_b` 是原厂 Android recovery | 前 8 字节 = `ANDROID!` |

## 2. 方案 G：GRUB 直起 a 槽安卓（技术路线与未知量）

Android boot 的每一件都在盘上，且都是标准格式（主机侧件已在仓里）：

| 件 | 来源 | 尺寸/头 |
|---|---|---|
| 内核 `Image` | `boot_a`（`out/android-v3-bringup-20261120/boot-ttygs0-boot.img` 同一件） | header v4，**kernel 36 731 392 B**，`ramdisk_size = 0`（GKI：generic ramdisk 在 `init_boot`） |
| generic ramdisk | `init_boot_a` 8M | cpio.gz |
| vendor ramdisk | `vendor_boot_a` v4 | **8 633 118 B**，cmdline 含 `bootconfig` 关键字 |
| DTB | `vendor_boot_a` 的 dtb 段 | 需解析实际大小（本文 §4 待办） |
| **bootconfig** | `vendor_boot_a` v4 的 bootconfig 段 | 关键：`androidboot.*` 的全量键值 |

路线：主机侧把上述件**拆出来固化到 ESP**，GRUB 用

```
linux    /boot/android-a/Image  <cmdline>
initrd   /boot/android-a/initrd.img      # init_boot ramdisk + vendor ramdisk 拼接
devicetree /boot/android-a/dtb
```

**关键简化**：不需要让内核从 bootconfig 段读参数 —— `init` 会**同时**从 `/proc/cmdline` 解析 `androidboot.<key>=<value>`，
所以主机侧把 bootconfig 里的键值**逐条搬进 cmdline** 即可（`androidboot.hardware=qcom` 等，实测 vendor_boot 里能抓到
`androidboot.hardware`/`memcg`/`usbcontroller` 等 7 处）。

### 未知量（必须先做小样本，不能直接承诺）

| # | 未知 | 判据/处置 |
|---|---|---|
| U1 | **AVB/verity**：a 槽 `vbmeta_a` 是自签 `419e01ac…`（≠原厂），`super` 是自建 v1 ⇒ Android 起来会不会因 verity 失败停 | 起不来就看 `androidboot.veritymode=disabled` + `androidboot.vbmeta.device=PARTUUID=…` 两个参数；再不行回退走 ABL 正常启动做对照 |
| U2 | **bootconfig 里是否有 `androidboot.slot_suffix=_a` 之类的强约束** | 解析 bootconfig 全文逐条核对（§4） |
| U3 | **GRUB 的 arm64 `devicetree` 命令**是否可用（Mu 件是否带了该模块） | 查 GRUB 构建配置/`grub-mkimage` 模块表；不可用则退回「内核自带 dtb」（Android 内核一般不支持） |
| U4 | GKI 内核是否开了 `CONFIG_BOOT_CONFIG` 之外的 EFI stub 直启兼容（`EFI_STUB` 是否在） | 在 `Image` 里搜 `PE\0\0`/`Linux kernel ARM64 boot protocol` 头 |
| U5 | `init_boot_a` + `vendor_boot_a` ramdisk 拼接顺序 | Android 约定 generic 在前、vendor 在后（`first_stage_ramdisk`），需按 vendor_boot 的 ramdisk table 顺序校验 |

## 3. 执行顺序（分三段，每段都可回退）

**段 1（主机侧，零风险，现在就能做）**
1. 解析 `vendor_boot_a` v4 全字段（含 bootconfig 全文、dtb 大小、ramdisk table）；
2. 拆出 `Image` / `init_boot ramdisk` / `vendor ramdisk` / `dtb`，落 `out/uefi-bslot-20261121/android-a/`；
3. 生成 cmdline（boot_a cmdline + vendor_boot cmdline + bootconfig 键值），写 `grub.cfg` 片段；
4. 组 ESP 树（FAT 镜像或目录），`sha256` 全件登记。

**段 2（设备，需物理键进 fastboot；写 2 个 b 槽分区）**
1. `recovery_b` ← UEFI 载荷（boot.img 形状，复用 `scripts/grubfat-build-uefi-bootimg.sh` 造件）；
2. `vendor_boot_b` ← FAT32 ESP（`mkfs.vfat` + 拷 ESP 树）；
3. 逐件读回 sha 校验（O_DIRECT）；回退件先备（`recovery_b`/`vendor_boot_b` 原厂 96M+100M 全量 dump 到 `backup/`）。

**段 3（设备，零写盘验证）**
1. `misc` 写 BCB `boot-recovery` → `reboot` → 是否进 GRUB 菜单（判据：屏上菜单 / Mu logfs 信标 / 或 GRUB 起来后串口）；
2. 菜单里选 **Linux** ⇒ 起进 vk192（等价现状，证明这条链不破坏主路径）；
3. 菜单里选 **Android (a slot)** ⇒ 观察（U1–U5 的判据在这里一次拿到）；
4. 回退：`misc` 清 0 → 普通重启即回 `boot_b` 直启 Linux（**这条回退不依赖 fastboot**）。

## 4. 立即待办（本文档之后先做的三件）

1. `vendor_boot v4` 全字段解析 + bootconfig 全文 dump（主机侧，仓里已有件，`scripts/boot-img-cmdline.py` 的解析器可复用）；
2. 检查 GRUB 件的模块表（`devicetree`/`linux` 是否在内）与 `Image` 的 EFI stub 头；
3. 造 `recovery_b` 用的 UEFI 载荷件 + ESP 树，全部落 `out/uefi-bslot-20261121/` 并登记 `versions/out-artifacts.tsv`。

## 5. 风险与边界（写清楚再动手）

- **最大的单点风险 = 段 2 写 `vendor_boot_b` 与 `recovery_b` 之后，Android b 槽与 b 槽 recovery 不再可用**（a 槽 Android 不受影响）；
  Linux 直启与回退都只依赖 `boot_b` + `misc`，**不在这次写的范围内**。
- 物理键仍是唯一进 fastboot 的路（`PITFALLS #701`），所以段 2 必须你在场。
- 不碰 `uefi_b`/`abl_b`/`xbl_b` 等固件分区（那是引导器本体，写坏 = 变砖，且与本方案无关）。
