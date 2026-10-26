# UEFI 路线 × Mobian 迁移：交界面事实与冲突裁决（2026-10-26）

> 纯主机侧只读。**设备不可达**（`ssh 192.168.7.1` 超时）⇒ 零设备操作、零写盘、未发任何邮件。
> 承接：`archive/topics/{BOOTCHAIN,UEFI-RESOURCES,UEFI-UFS-BRINGUP,UEFI-UFS-UPSTREAM-ASK}-2026-10-05.md`、
> `reports/uefi-restart-20261021.md`、`reports/uefi-gunyah-reassess-20261024.md`、`reports/uefi-experiment-build-20261024.md`、
> `reports/uefi-boot-A-attempt-20261024.md`、`TASKS/README.md` §1 G1-29/G1-30 与 §4 N1、§5 Q25。
> 迁移侧：`reports/mobian-migration-plan-20261021.md`（S1–S7）、`reports/modular-mobian-transition-20261026.md`（J1/J2、`/init` 三模式）、
> `reports/m6-debian-candidate-boot-nousb-20261026.md`、`DEVICE/README.md` §1.1。

---

## 0. 三问结论（先看这里）

| # | 问题 | 裁决 | 依据 |
|---|---|---|---|
| **①** | **UEFI 是否阻塞本次迁移？** | **不阻塞，零耦合。** 迁移的三条硬路径（`fastboot boot` 候选镜像 / `elden_root=LABEL=linux17` / systemd 交接）**没有一步经过 UEFI**；UEFI 路线本身也已是「搁置」状态（上机死在 UEFI 早期，无可见性） | §3.1 通道表、§4 冲突矩阵 C0 行 |
| **②** | **迁移是否让 UEFI 复启条件变差？** | **实质变差 1 项（GPT 现在已没有空闲槽）、中性 2 项、变好 1 项。** 最要紧的是：`BOOTCHAIN` 设想的「`linux17`(ext4) 放 Image/initramfs + 小 FAT 放 GRUB」里，**`linux17` 已被 Debian 占用**，而 LUN0 已无空槽 | §2.2、§4 冲突 C1/C2 |
| **③** | **迁移后若要复启 UEFI，需提前保留什么？** | **6 项**：① `linux17` 的 LABEL 名（不要改成 `debian`）② `linux17` 上**一个可被 GRUB 读的 ext4 目录**（放 Image/initramfs）③ 一个 ≤1 GiB 的 FAT 载体（**只能靠尾部 1024 MiB 余量或回收 Android 分区**）④ 原厂 `~/下载/tb322fc/*.elf` 固件包 ⑤ Mu 构建树与 3 个 `.img`（当前**不存在**，2.3 G 需重下）⑥ **kexec 通道保持可用**（`/sys/kernel/kexec_diag` + `kexec_marker=` 解析） | §5 保留清单 |

**一句话**：UEFI 与本次迁移**不共享任何可执行路径**，只共享**一块盘**；冲突的唯一形态是「`linux17` 这个标签/分区被两条路线都当成"
放内核与 initramfs 的地方"」，而其中 UEFI 那条**当前不可执行**（连 BDS 都出不来）。⇒ **UEFI 让路，代价≈0，可回退性不受影响。**

---

## 1. 引导链事实（逐条带证据）

### 1.1 四代引导链 ≠ 三代

```
PBL → XBL → { uefi_a (EDK2 核, 5 MiB) + imagefv_a (DXE 驱动卷, 2 MiB) } → ABL(LinuxLoader.efi, abl_a 1 MiB) → boot_a/b boot.img → 内核
```

- `uefi_a`/`imagefv_a` 由 **XBL** 加载，**不是** ABL 扫描；`abl_a` 本体 = Qualcomm `LinuxLoader`（含 `avb_slot_verify`/`slot_suffix` 字符串），
  **不扫 FAT、无 BDS/`SimpleFileSystem`/`Boot####` 逻辑**。证据：`archive/topics/BOOTCHAIN-2026-10-05.md` §2.2–§2.3（`abl.elf` LZMA 段解出 663 752 B 可读文本）。
- 三代（GUF296）那套「`boot.img` 内核槽装完整 UEFI DXE 环境（`code0=0x10000381` + `_FVH` + 41 个 PE）」在四代**没有对应物**：
  四代 stock `boot.img` = Android v4、kernel = 36 731 392 B **裸 arm64 Image**、ramdisk=0、**无 `_FVH`**。同文 §2.1/§2.2。
- **`uefivarstore` 里没有 `Boot####`/`BootOrder`**（`backup/slot-probe/uefivarstore_S1.bin` 检索为空）⇒ 「常驻 UEFI 会自动扫 FAT 起 GRUB」**无证据支持**。同文 §2.4。

### 1.2 上机现状：载荷死在 UEFI 早期，**零可见性**

| 试验 | 镜像 | 结果 | 证据 |
|---|---|---|---|
| T1 | `lenovo-y700g4-A.img`（`--header_version 3`） | ABL **接受但不跳**（`Booting OKAY`，`fastboot getvar` 仍 0.004 s 应答、USB 未重枚举） | `reports/uefi-boot-A-attempt-20261024.md` §2 |
| T2 | 同一载荷 repack **v0**（`--base 0x0 --kernel_offset 0x8000 --pagesize 4096`） | **真交棒**（`usb_read failed: No such device`）→ 约 25 s 后以 **stock Android 槽 a** 出现 ⇒ 载荷崩溃/复位 | 同文 §3 |
| 副作用 | — | 失败 `fastboot boot` 会把当前槽标 `slot-unbootable:b=yes` 并切 a 槽；恢复 = `fastboot set_active b`（已实测） | 同文 §5、`PITFALLS #387` |

观察通道盘点（同文 §4）：**UART 未开**（ABL 日志 `get uart controll value:0x0`）、**显示未到 GOP**、**崩溃发不落 `logfs`**、
EDL 只能读写分区**不能看 RAM**。⇒ **当前不存在任何能定位「它死在哪一层」的手段**。

### 1.3 UFS DXE 阻断点（两层，且已再分层）

| 层 | 内容 | 现状 |
|---|---|---|
| L-A | 原判 = `0x402` 运行期注册表条目解引用 `0xD6ABB030`（未映射） | **已推翻**：`0x89a4` = `UefiBootServicesTableLib` 构造函数、`0x6cc8` = `gBS->AllocatePool` ⇒ **不存在「运行期表」**；真实依赖 = 22 处标准 `LocateProtocol`（NpaDxe/ScmDxe/HWIODxe，同 FV 内、APRIORI 顺序 NpaDxe 33 行 → UFSDxe 70 行）。见 `TASKS/README.md` §4 N1 的「二次更正」段 |
| L-B | `UFS.c+2326` = `EFI_DEVICE_ERROR`（208 B 上下文/`UFSSmmuConfig` 失败） | **独立第二故障**，修好 L-A 仍撞。`reports/uefi-restart-20261021.md` §A.2 |
| L-C | 厂商 UFSDxe 代次差 | 本机 FV 的 UFSDxe = 151 552 B / `fa561bf1…`，Mu 的是 159 744 B（KaanapaliLAA 26310）⇒ issue #12 的「firmware version dependent」很可能就是**代次差**；最小实验（换 PE32 不重编）**已构建 A 镜像但死在 §1.2** |
| 上游 | `sunflower2333/mu_wide_platforms#12` | 2026-10-09 作者「需 UFSDxe 专用补丁」后**我方追问 0 回复**；本窗口（10-23→10-26）邮件检索 `UFSDxe`/`mu_wide_platforms` **均 0 命中**（`reports/mail-triage-20261026.md` §4）⇒ **信息入口仍然断着** |

### 1.4 体积与其它约束

| 约束 | 事实 | 来源 |
|---|---|---|
| **96 MiB boot 上限** | 分区实为 **100 663 296 B**（96 MiB 满幅）。日常镜像 81–86 MB 安全；**`vk95` 107.7 MB 超限只能 `fastboot boot`** | `reports/waydroid-camera-provider-64bit-20261018.md:20`、`reports/c1-iprule-vk95-20261011.md:58`、`DEVICE/README.md` §1.1 |
| **96 MiB 已不是难点** | G1-30 路线 C（完整 ramdisk 只换 `/init`）= **83.3 MB**，零写盘验收；`vk61` 成日常 | `TASKS/README.md` §1 G1-30 |
| **cmdline 落点机制** | 根由 **cmdline 的 `elden_root=LABEL=`** 决定（`initramfs/init:210-231` 白名单解析 → `findfs/blkid` → `mount -t <type>` → `switch_root`）；cmdline **烧在 boot.img 里** ⇒ **换根必须换 boot 镜像** | `reports/modular-mobian-transition-20261026.md` §0 J2、`initramfs/init` |
| **默认 ROOTARGS** | `scripts/build-boot.sh:63` `ROOTARGS="${ROOTARGS-elden_root=LABEL=linux17}"`（**默认值仍是 linux17**，与当前实际使用 `linux18` 不一致，属历史遗留） | `scripts/build-boot.sh:63` |
| **AVB / 槽位** | `boot` 是 **chained AVB**：自签必须 AOSP testkey（sha1 `2597c218`）+ rollback `1738713600` + 3 条 prop；`fastboot boot` 不过 AVB。`boot_a/b` 属性在 **LUN4 `/dev/sde`**（sde12/sde45），不在 `/dev/sda` | `DEVICE/README.md` §1、`scripts/slot-attr.py`、`reports/mobian-migration-plan-20261021.md` §5 R3 |
| **cmdline 必须留 `androidboot.slot_suffix=_b`** | 否则 `qbootctl -m/-u` 静默落到槽 a | `scripts/build-boot.sh:64-69`、`PITFALLS #181` |
| **kexec 现状** | `CONFIG_KEXEC` **未编**，只有 `kexec_file_load`；`mask=1` 旋钮在树（`/sys/kernel/kexec_diag`，`kernel/kexec_core.c` + `reboot.c`）⇒ **交接成立、零掉电**，但**目标内核静默挂死**（继承态 display/SMMU），**只可靠于不需显示的调试** | `reports/kexec-plan-20261021.md` §A、`reports/kexec-vk147-display-inherit-20261023.md`、`TASKS/README.md` §1 C12 |

---

## 2. 与迁移直接冲突/可利用的接口事实

### 2.1 可利用（迁移**帮** UEFI 的地方）

| # | 事实 | 对 UEFI 的意义 |
|---|---|---|
| U1 | 迁移后 `linux17` = **ext4** 上的 Debian 根，**GRUB 原生可读 ext4** | `BOOTCHAIN` 路线 A 的核心诉求「kernel/initramfs 从 ext4 分区读、不吃 96 MiB」**在迁移后被自动满足**（前提：分区上真的放一份 `Image`+`initramfs`） |
| U2 | `/init` 已三值化（`legacy`/`openrc`/**`systemd`**），且 **lifeline 在 PID1 交接之前**（usb0+udhcpd+sshd+ttyGS0/1） | 一旦 UEFI 真能起 GRUB 并 chainload 内核，**恢复通道不依赖发行版**，Debian/Alpine 都不影响「能不能上网取证」 |
| U3 | 候选镜像走 `fastboot boot`（零写盘），`boot_b` 不动 | 迁移上机试验与 UEFI 上机试验**可以并存在同一台机上**、互不覆盖（都只改 RAM） |
| U4 | `m6` 事故已把「lifeline 必须在 `switch_root` **之前**」变成显式工程结论（`elden_early_gadget=1` 已进 `/init`） | UEFI 载荷若真起来，早期可见性也用同一条通道（USB 串口/网口） |

### 2.2 冲突（迁移**恶化** UEFI 复启条件的地方）

| # | 事实 | 恶化程度 |
|---|---|---|
| X1 | `BOOTCHAIN` §3.2/§4 路线 A 明写「kernel/initramfs 放 **`linux17`**」；而 T17/J1 已把 **`linux17` 定为 Debian 落点** | **同一分区被两条路线同时当作"内核与 initramfs 的家"**（§4 矩阵 C1） |
| X2 | `BOOTCHAIN` 需要「一个**小 FAT32 放 `BOOTAA64.EFI`**」；LUN0 **已无空槽**（`linux17`+`linux18` 各 96 GiB + 尾部余 1024 MiB；`userdata` 256.7 GiB） | 唯一低成本载体 = **尾部 1024 MiB**（够 1 GiB FAT，但需 GPT 手术 + 会与"尾部余量"作为其它用途的余量冲突） |
| X3 | `BOOTCHAIN` 的验证判据是 `cat /proc/cmdline` 里 **`root=LABEL=linux17`**（连字符式 `root=`，非本项目实际使用的 `elden_root=`） | **判据本身是过时口径**：本项目 `/init` 只认 `elden_root=`/`ubuntu_root=`（`initramfs/init:212-231` 白名单）。若照抄 `root=` 会**静默落到 RAM 根**（无磁盘根） |
| X4 | UEFI 一旦上线 = **更换复位/显示相关重大变量**（bootloader 会把 framebuffer 交给 simpledrm、且在 SMMU 起来后仍可能写 splash region） | 这正好命中 `TASKS/README.md` §5 Q28 的**复启条件之一**（"更换复位或显示相关的重大变量（如 UEFI 上线…）"）⇒ UEFI 与 Q28 已收口线**互相拉扯**，不能当成纯增益 |
| X5 | Pengyu 2026-10-25 原话：他当年给 Konrad 的 SMMU 说法**已自行撤回**（「UEFI 在 SMMU 起来后还在写 splash region… 后来我自己解决了」），并称 **splash 存在时 10/10 可用** | ⇒ UEFI 与「面板点亮」**不是互斥**，但**要求 bootloader/splash 行为正确**；我们现有的 `simple-framebuffer` 已从 DTS 移除（`reports/m1-73-dts-fix-catchup-20261013.md`），**UEFI 上线等于重新引入 simpledrm**（§4 矩阵 C4） |

---

## 3. 三问的展开证据

### 3.1 ① UEFI 是否阻塞：不阻塞（通道矩阵）

| 迁移步骤 | 实际通道 | 经 UEFI？ |
|---|---|---|
| S5 initramfs | 现役自建 busybox ramdisk（`scripts/build-initramfs.sh`），`/init` 挂 `elden_root` | **否** |
| S6 systemd 单元 | `packaging/elden-userland` 渲染 → `out/stage-debian/` | **否** |
| S7 上机（M6） | `fastboot boot out/boot-elden-vk164-debianroot.img` → ABL 直接跳内核 | **否**（ABL 是 LinuxLoader，不经 BDS） |
| 回退 | `reboot2 bootloader` + `fastboot reboot` 回 `boot_b`（`elden_root=LABEL=linux18`） | **否** |
| 模块树 depmod | 主机侧 `depmod -b`（rc=0 实测） | **否** |

⇒ 迁移的全部前置条件里 **0 项**依赖 UEFI；UEFI 的全部前置条件里 **1 项**依赖迁移（盘布局，见 §4）。

### 3.2 ② 是否变差

- **变差 1 项**：`linux17` 从「**空出来的可回退 ext4 根**」变成「**Debian 现役/候选根**」。`BOOTCHAIN` 路线 A 需要的正是这块 ext4 空间
  （放 `Image` + `initramfs` + GRUB 可读的 `/boot`）。迁移后这份空间**仍然物理存在且仍可读**，但：
  - 不能再"清空重排"（会毁掉 Debian 根）；
  - 需要**在 Debian 根内**划 `/boot`（或 `/boot/efi` 目录），即 **GRUB 配置必须迁就 Debian 布局**（不是反过来）。
  ⇒ 不是"不可做"，而是**从"随便用"变成"要协调"**。
- **中性 2 项**：① `linux17` 的 **LABEL 名不变**（`blkid` 仍 `LABEL=linux17`，见 `reports/mobian-migration-plan-20261021.md` §1.1 与 m6 报告 §2「LABEL 仍是 linux17」）
  ⇒ `root=LABEL=linux17`（UEFI 侧判据）与 `elden_root=LABEL=linux17`（迁移侧）**指同一个分区**，只是**语义不同**（前者是 GRUB/内核的 `root=`，后者是本仓 `/init` 的私有变量）。
  ② 槽位与 AVB**完全不受影响**（迁移走 `fastboot boot`，UEFI 也走 `fastboot boot`）。
- **变好 1 项**：迁移上机试验已是**零写盘**，`boot_b` 保持 `f2fs-root`。UEFI 试验同样零写盘 ⇒ **两条线的失败都不会破坏对方**。

### 3.3 ③ 复启保留清单（详见 §5）

判据：**"迁移完成 + 6 个月后想重试 UEFI"**，那时必须仍然具备的东西。逐项标注"现在是否已有 / 谁负责保住"。

---

## 4. 冲突矩阵：同一分区被两条路线同时占用

> 命名约定：**U-A** = `BOOTCHAIN`/`UEFI-*` 文档里的 UEFI 路线 A（BDS+GRUB，`root=LABEL=linux17`）；
> **T17** = 本轮迁移裁决（Debian 装 `linux17` ext4，Alpine 留 `linux18`，`elden_root=LABEL=linux17`）。

| # | 资源 | U-A 的用法 | T17 的用法 | 冲突性质 | 裁决建议 | 代价 | 可回退性 |
|---|---|---|---|---|---|---|---|
| **C1** | **`linux17` 分区本体**（96.0 GiB ext4，idx16） | 放 **`Image` + `initramfs`**，由 GRUB 从 ext4 读；验证判据 `root=LABEL=linux17` | **Debian forky/sid 根**（1.9 G / 36 268 文件，`/sbin/init→systemd`）；`elden_root=LABEL=linux17` | **同分区两种"根语义"**：GRUB 的 `root=` 给内核当根 ⇒ 内核会**直接把 Debian 根挂成 `/`**（这在技术上其实是"U-A 成功"的一种形态，而不是冲突） | **U-A 让路**：把"kernel/initramfs 的家"改到 **`linux17:/boot`（Debian 内）**，`grub.cfg` 里 `linux /boot/Image` + `initrd /boot/initramfs.img`，**不要**把 `root=` 指成 linux17（那是把 Debian 当根，不是 UEFI 的收益） | **0**（不写盘、不改分区；只是改 GRUB 配置的落点） | **完全可回退**（GRUB 配置是文件级改动） |
| **C2** | **LUN0 剩余空间** | 需要**一个 ≤1 GiB FAT32** 放 `/EFI/BOOT/BOOTAA64.EFI` + `grub.cfg`（EFI 规范要求 FAT ESP） | 需要 `linux17`(96 G) + `linux18`(96 G) + `userdata`(256.7 G)；**尾部余 1024 MiB 不属于任何路线** | **无冲突但余量只有 1024 MiB** | **两侧都让路到"先不切"**：U-A 不在本轮做 GPT 手术；若将来做，用**尾部 1024 MiB**建 FAT（`scripts/gpt-surgery-tb322fc.py` 已有，备份 `backup/HA2EXB0E-16+512/gpt-20261025/`） | GPT 手术 = 有写坏风险（须先备份 + 读回校验）；**1 GiB FAT 也够不到"多内核并存"的体量** | 可回退（GPT 双表 dump 在手），但**属"需要人在场"的动作** |
| **C3** | **`/boot` 目录内容的归属** | GRUB 读到的 kernel/initramfs **必须与 boot.img 里那份内核同版本**（否则模块树不匹配 = 静默 panic，`CONFIG_MODVERSIONS` 未开） | Debian 的 `/boot` 默认会想放 `vmlinuz-*`（`linux-image-*`）——而 S2 清单**已显式排除 `linux-image-*`** | **口径冲突**：若将来给 Debian 装发行版内核，`/boot` 会被错误内核占据 | **T17 让路 + 加门禁**：`/boot` 只允许出现**自编内核**（UTS `7.3.0-rc7-debug-vk127-…-debug-vk163`）；把 `check-pkgmap.sh` 的 `linux-image-*` 排除项**升级为运行时断言**（`/boot` 里出现 `vmlinuz-*` 即 FAIL） | 0（门禁） | 完全可回退 |
| **C4** | **framebuffer / simpledrm** | UEFI 走的 BDS→GRUB 会把 **GOP framebuffer** 交给内核 ⇒ 重新出现 `/chosen/framebuffer`（`simple-framebuffer`），`simpledrm` 会绑定 | 本机 DTS **已刻意删除** `simple-framebuffer`（`reports/m1-73-dts-fix-catchup-20261013.md` §2.1：与 `splash_mem` 同址争用、`fbcon` 会绑到死 fb） | **直接冲突**：UEFI 上线 = 重新引入 `simpledrm`；而 Q28 的 mdss 复位会**把 simpledrm 正在扫的 framebuffer 抽掉**（sashiko High / Taniya 的"闪屏"论点原话） | **Q28 侧让路（不新增变量）**：UEFI 一旦上线，Q28 的"复位搬到 mdss 侧"必须在 **simpledrm 在场**的条件下重测（这正是 `TASKS/README.md` §5 Q28 复启条件第 3 条「如 UEFI 上线」的由来）。**不在本轮做** | 上机一轮（≥5 发 POR） | 可回退（不写盘） |
| **C5** | **`root=` vs `elden_root=`** | U-A 判据写 `root=LABEL=linux17` | `/init` **只认** `elden_root=`/`ubuntu_root=`（白名单，`initramfs/init:212-231`） | **判据过时**：照抄 `root=` ⇒ `/init` 认为"没有磁盘根请求" ⇒ 走 **RAM 根**（`on_initramfs=1`、挂 `/persist`），**不 switch_root** | **U-A 文档口径修正**：验证判据改为「`/proc/cmdline` 含 `elden_root=LABEL=…` 且 `findmnt /` = 目标分区」；`root=` 只作为 GRUB 传给内核的传统参数，**对本项目无效** | 0（改文档） | — |
| **C6** | **面板/复位与 splashing**（外部证据） | — | — | 用户的现实约束 | Pengyu 2026-10-25 原话：**「UEFI is still writing to the splash region after SMMU is broughtup」是他的问题，后来解决；「it works well with splash, or a proper and whole backlight initialization without splash… display worked 10 out of 10」** ⇒ **UEFI + splash 可与显示共存**，但**要求 bootloader 的 splash 行为正确**；这**削弱**了"UEFI 上线必然破坏 Q28"的最坏假设 | — | — |

### 4.1 裁决（一句话）

- **C1/C3/C5 → UEFI（U-A）让路**，代价 = **0**（改 GRUB 配置与文档口径，不动盘）；可回退性 = 文件级。
- **C2 → 两条路线都搁置**（GPT 手术不在本轮，且属"需人在场"）。
- **C4/C6 → Q28 让路**（UEFI 上线时 Q28 必须重测，这是既有复启条件的原文，不是新增）。
- **没有任何一条冲突需要"现在就把某个分区让出来"** —— 因为 UEFI 路线当前**不可执行**（§1.2）。

---

## 5. 迁移后若复启 UEFI：必留清单（6 项）

| # | 保留项 | 现状 | 谁负责保住 | 丢失后果 |
|---|---|---|---|---|
| R1 | **`linux17` 的 LABEL 名 = `linux17`**（不要为了 Debian 改名） | 已有（`blkid` 实测 `LABEL=linux17`；m6 报告 §2 复核「LABEL 仍是 linux17」） | 迁移脚本（`scripts/f2fs-migrate.sh` 一类）；`/etc/fstab` 只写 `LABEL=linux17`（m6 §2 已确认） | `elden_root=LABEL=linux17` 与 `root=LABEL=linux17` **双双失效** |
| R2 | **`linux17` 上一个 GRUB 可读、版本与 boot.img 一致的 `Image` + `initramfs`**（建议 `/boot/Image-vk*/`） | **未准备**（Debian 根里当前没有 `Image`） | 迁移收口时一并落盘（S6/M5 之后） | U-A 只剩"从 boot.img 里的 ramdisk 起"，等于回到 G1-30 之前 |
| R3 | **一个 ≤1 GiB 的 FAT 载体（ESP）** | **无**（LUN0 无空槽，尾部余 1024 MiB） | 只在真复启时做 GPT 手术；**手术前必须** `backup/HA2EXB0E-16+512/gpt-20261025/` 双表 + 写后 `cmp` | EFI 规范要求 FAT ESP ⇒ 没有它就**不可能有 BOOTAA64.EFI** |
| R4 | **原厂固件包 `~/下载/tb322fc/`**（`uefi.elf` 5 242 880 B / `imagefv.elf` 2 097 152 B / `abl.elf` 1 048 576 B / `tools.fv` 1 048 576 B / `hypvm.mbn` 8 MiB） | **在盘**（`reports/uefi-gunyah-reassess-20261024.md` §1.2） | 不要在磁盘清理中删；建议与 `backup/` 一起进备份清单 | 「重组原厂 FV」与「厂商 UFSDxe/RmVmDxe 提取」全部要从头（`reports/artifacts/uefi-dxe-20261024/` 虽已有产物，但源头丢了就无法复核） |
| R5 | **Mu 构建树 + 3 个实验镜像（N/A/C）** | **不存在**（`reports/uefi-restart-20261021.md` §A.1：`mu_wide_platforms` 1.0 G、`uefi-firmware-backup` 1.3 G、`edk2-*` 1.5 G、7 个 `out/local-exp/*.img` 全丢；`build/uefi-woa-prep/repos/7-mu-lenovo` 本轮未核，属「需现查」） | 若确定要长期保留复启能力，**至少保留 3 个 `.img`**（`reports/artifacts/uefi-built-20261024/`，含 `sha256` 与 manifest）——它们是"下一次最小实验"的输入 | 复启成本 = **重下 2.3 G + 重建 clang-21/nuget 工具链**（估 0.5–1 天），见 `reports/uefi-experiment-build-20261024.md` §R1 的三个坑（全局 git `insteadOf`→SSH、嵌套子模块、mono btls 证书） |
| R6 | **kexec 通道（多内核菜单的替代品）** | **可用但有硬限制**：`/sys/kernel/kexec_diag`（`mask=1`）+ `kexec_marker=1`（`/init` 白名单已支持）+ 只能 `kexec_file_load`；**目标内核静默挂死**（继承 display/SMMU 态）⇒ **仅可靠于不需显示的调试** | 迁移后 `systemd` 路径**必须保留** `kexec_marker=` 解析（`initramfs/init:221-223` 白名单 + `kexec_marker_dump()`），否则连"目标死没死"都测不到 | 若 UEFI 与 kexec **双失**，则"多内核选择"归零，`TASKS/README.md` §4 N1 的复启条件第 3 条「kexec 不可用而又需要启动菜单」会被**误判为成立** |

> ⚠ **R6 与迁移的一个具体接口**：`kexec_marker_dev=` 当前示例用 `/dev/sda17`（=`linux17`）。迁移后 `linux17` 是 Debian 根，
> **marker 文件会写进 Debian 根**（`/var/tmp/kexec-marker.txt`）——这**不是问题**（只是落点变了），但**取证路径要跟着改**：
> 原来在 Alpine(linux18) 上读 `/mnt/l17/var/tmp/...`，迁移后应直接在 Debian 根读。**属文档/脚本口径更新，非阻塞。**

---

## 6. 未解 / 未证实（明确不编）

| # | 项 | 状态 |
|---|---|---|
| 1 | T2 repack 之后载荷死在哪一层（BootShim 的 cache 未 clean / PEI / DXE 早期） | **未证实**，三条假设并列，`reports/uefi-boot-A-attempt-20261024.md` §3 |
| 2 | 厂商 PE32 替换 Mu UFSDxe 能否解掉 L-B（`UFSSmmuConfig`） | **从未执行到**（载荷在显示初始化之前就死） |
| 3 | 「尾部 1024 MiB」能否安全建 1 GiB FAT（GPT 手术的具体可行性） | **未验证**；需读实际 GPT（设备不可达，本轮无法） |
| 4 | Debian 根内的 `/boot` 是否会被 `dpkg` 自动塞 `vmlinuz-*` | **未验证**（S2 只排除包名，未做运行时断言） |
| 5 | UEFI 上线后 `simpledrm` 与 mdss 复位共存的实际行为 | **未验证**；仅 Pengyu 的"10/10 可用"口头证据（**不同内核/不同树下**，不能直接套） |
| 6 | `build/uefi-woa-prep/repos/7-mu-lenovo` 是否仍在盘 | **本轮未核**（任务限定"只读研究 + 3 份报告"，未做全盘 find；`reports/uefi-restart-20261021.md` §A.1 记录 2026-10-21 时不存在，之后 10-24 又 clone 过 ⇒ **需现查**） |

---

## 7. 复现命令（全部只读，无需设备）

```bash
# 引导链机制（四代 ABL 不扫 FAT / uefivarstore 无 Boot####）
sed -n '1,140p' archive/topics/BOOTCHAIN-2026-10-05.md

# 96 MiB 与日常镜像体量
grep -n "100663296\|96 MiB" reports/*.md DEVICE/README.md | head -20

# cmdline 落点机制与默认值
grep -n "ROOTARGS\|elden_root" scripts/build-boot.sh
grep -n "elden_root\|elden_early_gadget\|kexec_marker" initramfs/init

# 盘布局真值（需设备；本轮设备不可达，以下为历史记录）
grep -n "linux17\|linux18" DEVICE/README.md

# 上游 issue 状态（只读网页；本轮未执行）
#   https://github.com/sunflower2333/mu_wide_platforms/issues/12
```

---

## 8. 边界

- 未执行任何 `fastboot`/`adb`/`ssh`/EDL；**设备未触碰**（本轮 `ssh 192.168.7.1` 超时，按前置条件即为不可达）。
- 未写任何分区、未改 GPT、未动 `boot_b`。
- 未发任何邮件、未跑 lore 请求、未改仓库既有 SSOT 文件（`TASKS/README.md`/`DEVICE/README.md`/`INDEX.md`/`RESOURCES/README.md`/`PITFALLS/README.md`/`versions/` 全部未改）。
- 本文只新建本文件；所有结论都指向上游文档行号或命令，**无编造数字/Message-ID**。
