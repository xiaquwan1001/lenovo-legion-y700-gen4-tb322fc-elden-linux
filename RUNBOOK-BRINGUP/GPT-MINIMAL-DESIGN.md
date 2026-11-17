# GPT 最小化设计（TB322FC / `elden`）：分区表「少而可控」+ 最小 Debian 刷机资料清单

> 目标（用户口径，2026-11-17）：**精简掉不必要分区，降低调试负担**；只要 **Debian 派系最小系统**（无 Phosh 等桌面用户态）；
> 并且从 **EDL/fastboot 冷启动**就能一步步复现到「持久化 Linux」。
> 工具：`scripts/gpt-minimal-build.py`（生成表）+ `scripts/gpt-audit-tb322fc.py`（对账）+ `scripts/linux-state-audit.sh`（体检）。
> 复现步骤全文 = `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md`（本文件只讲「表怎么简化」和「要备哪些件」）。

---

## 0. 一句话结论

**LUN0 从 18 项收到 10 项（9 个固件/身份区 + 1 个 `linux` 472 GiB），LUN4 从 78 项收到 74 项；
删掉的 472 GiB Android 专属空间一次性全给 Linux，此后不再做 GPT 手术、不再缩分区。**
真机从原厂到「能进 Debian」只需 **6 类件、约 700 MB 主机资产**（不含一次性原厂全量包）。

---

## 1. 现状盘点（数字来自 2026-11-17 18:53 六 LUN dump，`reports/artifacts/bl-stuck-20261118/`）

| LUN | 分区数 | 内容 | 末分区止 |
|---|---|---|---|
| 0 | **18** | 固件/身份区 9 + Lenovo 3 + Android（`super` 22 GiB、`userdata` 256.7 GiB、`metadata`、`vbmeta_system_*`、`rawdump`、`pstoredump`）+ 我方（`linux17` 192 GiB、`eldenesp` 512 MiB） | 472.0 GiB |
| 1 / 2 | 5 / 5 | `xbl_*`、`xbl_config_*`、`multiimg*`、`apdp*`（**引导固件 LUN，与槽绑定**） | 极小 |
| 3 | 3 | `ALIGN_TO_128K_1`、`cdt`、`ddr` | 1 MiB |
| 4 | **78** | 全芯片固件 A/B 各一套（tz/hyp/modem/dsp/aop/…）+ boot/recovery/vendor_boot/init_boot/dtbo/vbmeta + `devinfo`/`logfs`/`secdata` 等 | 1.6 GiB |
| 5 | 5 | `modemst1/2`、`fsg`、`fsc`（modem 持久数据） | 极小 |

**调试负担的真实来源**：不是 LUN4 的 78 项（它是 XBL/ABL 按名字取固件的地方，删了就要赌），
而是 LUN0 里 **Android 的 4 类 + 我方历史的 3 类**混在一起，加上 `super/userdata` 两个巨无霸，导致
「哪些能删、删了会不会卡 BL」每次都要重新判断（2026-11-17 就栽在这上面）。

---

## 2. 分类（唯一的真源是 `scripts/gpt-minimal-build.py` 里的表；本表逐条对应）

### 2.1 必留（9 项 / 353.5 MiB，LUN0）

| 分区 | 大小 | 为什么不能删 |
|---|---|---|
| `proinfo` | 3 MiB | 设备身份/出厂信息（Lenovo 工具、部分校准读取） |
| `lenovolock` | 0.5 MiB | Lenovo 区锁状态（写坏会改变解锁语义） |
| `lenovocust` | 300 MiB | Lenovo 定制分区（区域/配置；300 MiB 是唯一「大」的，但删了没有收益证据） |
| `lenovoraw` | 16 MiB | Lenovo raw 配置/解锁相关（实测被 `rawprogram` 写、`lenovolock` 配套） |
| `ssd` | 8 KiB | TEE 侧安全存储 |
| `persist` | 32 MiB | 传感器/射频校准（Linux 侧部分驱动也读） |
| `misc` | 1 MiB | **BCB**：ABL 每次启动读它（`ffbm-*`/`boot-recovery`）；清空 ≠ 删除 |
| `keystore` | 0.5 MiB | keymaster/TEE 密钥材料 |
| `frp` | 0.5 MiB | 工厂重置保护（ABL 会读） |

### 2.2 删（7 类 / 472.2 GiB，LUN0）

| 分区 | 大小 | 依据 |
|---|---|---|
| `super` / `elden-super` | 22 GiB | Android 动态分区容器（system/vendor/product…）。Linux 不读；ABL 启动 Linux 不需要 |
| `userdata` / `elden-data` | 256.7 GiB | Android `/data` |
| `metadata` | 64 MiB | Android 加密/apex 元数据 |
| `vbmeta_system_a/b` | 各 64 KiB | Android system 的 AVB 链节点（我们只签 `vbmeta`） |
| `rawdump` | 256 MiB | Android ramdump 落盘区；Linux 用 **ramoops 保留内存**，不用分区 |
| `pstoredump` / `pstoredu` | 128 MiB | 同上 |
| `linux17` / `eldenesp` | 192 GiB + 512 MiB | 我方旧布局；被新的单个 `linux` 取代（ESP 链路同时退役，见 §3.3） |

### 2.3 LUN4：只删 4 项（208 MiB），其余全留

| 分区 | 大小 | 依据 |
|---|---|---|
| `vendor_boot_a/b` | 96 MiB × 2 | Android GKI 第二段（含 vendor ramdisk）；我们自建 `boot.img` 不需要 |
| `init_boot_a/b` | 8 MiB × 2 | 同上 |

**不动 LUN1/2/3/5、不删 A/B 双份固件**：合计 1.6 GiB，换来的是一整条**回退槽**（a↔b 互换就能回 Android/备用核），
删了省不了多少却失去唯一的现场退路 —— 这是「可控」的反面。

### 2.4 目标布局（`minimal-v1`）

```
LUN0 (10 项)  proinfo | lenovolock | lenovocust | lenovoraw | ssd | persist | misc | keystore | frp
              └─ linux : LBA 90504 .. 123871226  = 472.19 GiB  (ext4，整块剩余盘)
LUN3          ALIGN_TO_128K_1 | cdt | ddr            （固件，不动）
LUN4 (74 项)  全固件 A/B + boot_a/b + recovery_a/b + dtbo_a/b + vbmeta_a/b + devinfo/logfs/…（删 4 项 Android GKI）
LUN1/2/5      不动
```
生成命令（零搬迁：保留项 LBA 一个都不动）：

```sh
python3 scripts/gpt-minimal-build.py \
  --main backup/HA2EXB0E-16+512/gpt_main0.bin --backup backup/HA2EXB0E-16+512/gpt_backup0.bin \
  --out-prefix /tmp/gpt-min --linux-name linux        # 默认吃满 last_usable
# 期望输出：保留 9 项 / 353.5 MiB，删除 7 项 / 472.2 GiB，linux: 90504..123871226 (472.2 GiB)
```
写入：主表 `seek=0`（6 扇区）、备表 `seek=123871227`（5 扇区）；写完**必须**读回 + `gpt-audit` 对账。

---

## 3. 最小刷机资料清单（从 EDL/fastboot 到「持久化 Debian」）

### 3.1 主机侧必备（一次性，约 700 MB；不含 16 GB 原厂包）

| # | 件 | 大小 | 怎么来 | 写到哪 |
|---|---|---|---|---|
| 1 | EDL loader `xbl_s_devprg_ns.melf` | 1.7 MB | 原厂包（`backup/fw/tb322fc-edl/`） | 内存（Sahara） |
| 2 | `qdl`（v2.9，自建） | — | `~/edl/qdl/build/qdl` | 主机 |
| 3 | 最小 GPT（main+backup） | 24 KB + 20 KB | `scripts/gpt-minimal-build.py` | LUN0 LBA0..5 / 备表 |
| 4 | `boot.img`（kernel+DTB+initramfs） | ~86 MiB | `scripts/build-boot.sh`（打包）/ `scripts/build-kernel.sh`（编译） | `boot_b`（+可选 `boot_a`） |
| 5 | `vbmeta_b`（`Flags=3` = 关校验） | 4 KiB | `backup/vbmeta_b-20261110.img` 或 `avbtool` 重签 | `vbmeta_b` |
| 6 | `dtbo` 假件（4 KiB 全零） | 4 KiB | `out/dtbo-dummy.img`（`truncate`+`mke2fs` 历史产物，sha `ad7facb2…`） | `dtbo_b`（+`dtbo_a`） |
| 7 | **rootfs 归档**（Debian minbase） | 250–400 MB | `debootstrap --variant=minbase trixie` → `tar` | `linux` 分区（ext4） |
| 8 | 模块包（**同 UTS**） | ~23 MB | `out/modules-<UTS>.tar.gz`（`make modules_install INSTALL_MOD_PATH=`） | rootfs `/lib/modules/<UTS>` |
| 9 | 固件 blob（`/lib/firmware`：adsp/cdsp/wcn7861/gpu…） | ~120 MB | 原厂 `vendor.img` 提取 或 `linux-firmware` | rootfs `/lib/firmware` |

**不需要**：原厂 16 GB 全量包（只在「回到 Android 基线 / 救砖」时需要）、`bootslot-b/*` 历史镜像（留台账那一个即可）、ESP/GRUB 件（见 §3.3）。

### 3.2 最小 Debian 用户态（无桌面）

`debootstrap --variant=minbase` 后只装：

```
systemd（或 busybox-init，二选一）  openssh-server  iproute2  kmod  rfkill
systemd-networkd + iwd 或 wpa_supplicant    ca-certificates  vim-tiny  htop
```
判据（S8 验收的最短集）：`uname -r` = 台账 UTS → `findmnt /` = `/dev/disk/by-partlabel/linux` →
`lsmod | wc -l` 与台账同量级 → `ssh` 可登 → `ip a` 见 `wlp1s0` → `s2idle` 正常。
**不装**：Phosh/GNOME/mesa 桌面栈、Waydroid、相机/音频用户态（这些回来时按原 RUNBOOK 叠加，不阻塞最小系统）。

### 3.3 为什么连 ESP/GRUB 都可以省

原链路（ESP → GRUB → Loader.efi → `\boot\boot.img`）是为了**多臂菜单 + 无主机启动**；
最小系统直接走 **ABL → `boot_b`**（内核+DTB+initramfs 全在 boot.img 里，86 MiB 上限内），
少两个分区（`eldenesp`）和 4 个件（GRUB/Loader/menu.cfg/grubenv），调试面显著变小。
**保留 ESP 的方式**：`--keep-esp-gib 0.5`（表里会加回一个 512 MiB 的 FAT32 项），需要时再开。

---

## 4. 实验计划（每一步单变量、可逆；**删条目 ≠ 删数据**，旧 GPT 备份在手即可退回）

| 阶段 | 动作 | 判据（全绿才进下一步） | 回退 |
|---|---|---|---|
| **P0** | 现状（Android 可用，已实测） | `sys.boot_completed=1` | — |
| **P1** | 写最小 GPT（LUN0） | 能进 fastboot；Win/Linux 侧 `blkid` 见 `linux` | 写回旧 `gpt_main0/backup0` |
| **P2** | 在 `linux` 上 `mkfs.ext4` + 解 rootfs + 刷 `boot_b/dtbo_b/vbmeta_b` | 冷起进 Debian + `ssh` 通 | `fastboot --set-active=a`（a 槽 Android 全程未动） |
| **P3** | 删 LUN4 的 `vendor_boot/init_boot`（4 项） | 冷起仍进 Debian；`continue` 无 `Device Error` | 写回旧 LUN4 GPT |
| **P4** | 槽持久化：`slot-attr.py mark-successful b`（+`--set-active=b`） | 连续 8 次重启仍在 `_b`（`#181` 的 7 次耗尽） | `--set-active=a` |
| **P5**（可选） | 单槽化：把 a 槽固件也腾出来 | — **暂不做**（回退保险的价值 > 1.6 GiB） | — |

**每一步都要记录的三件事**：① `getvar` 全量；② EDL 读回的 GPT 与 `gpt-audit` 结果；③ 冷起后 `adb`/`ssh` 判据。
判据纪律（硬件结论四道门）见 `LINUX-STATE-REPRO.md` §1.2 —— 本次事故就是因为跳过了「逐字节对账」。

---

## 5. 已知风险（按危害排序）与对策

| 风险 | 说明 | 对策 |
|---|---|---|
| 删 `misc` / `devinfo` / `persist` | ABL/TEE 直接读，缺了可能报错或丢校准 | **不删**（本设计不动它们） |
| LUN4 删 `vendor_boot/init_boot` | 若某版 ABL 会校验 `vbmeta` 里指向这些分区的描述符 | 已实测（2026-11-17）：`python3 tools/avbtool.py info_image --image backup/vbmeta_b-20261110.img` 只列 **2 个描述符** —— `chain: boot`（rollback index 3）+ `hash: dtbo`（4096 B）⇒ **不涉及 `vendor_boot`/`init_boot`**，可删；`vbmeta_a` 同理需复核（stock a 槽 `vbmeta_a` 当前全 0） |
| 单 `linux` 分区吃满盘 | 以后没法再「加一个分区」而不缩它 | 这是**有意**的：需要双系统时再缩（`gpt-surgery shrink-append`），比现在留一堆未知分区更好判断 |
| 缩 `dtbo` 到 8 MiB | 与 `vbmeta` 描述符尺寸不一致 | 本设计**不缩**（保持 32 MiB，只用 4 KiB 假件） |
| 删掉 `super` 后想回 Android | Android 起不来（无 system） | 回 Android = 原厂全量重刷（`LINUX-STATE-REPRO.md` §3 S2），不是写回几个分区 |
| LUN1/2 的 `xbl_*` 与槽绑定（`#484`） | 删任一槽的固件会让该槽不可用 | 不动反而不变 |

---

## 6. 与既有文档的关系（避免两套说法）

- `DEVICE/README.md` §2.4 的「Phase B 回收 Android 专属分区」= 旧口径（列了 `super_a/b`、`boot_a`、`dtbo_a`、`recovery_a`、`metadata`、`misc`…）。
  **本设计取代其中「删 `misc` / `boot_a` / `dtbo_a` / `recovery_a`」的部分**：`misc`/`devinfo` 必留，`boot_a`/`dtbo_a`/`recovery_a` 属于 A/B 回退槽，保留价值 > 1 GiB。
- `DEVICE/README.md` §3 的容量策略在本设计下**退化为一句**：Linux = 除固件与身份区外的全部剩余盘（472 GiB），不再需要「按体量估算容量」。
- 复现步骤仍以 `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md` 为准；本文件只改「表」和「件清单」。

---

## 7. 待补（本文件当前边界，按优先级）

1. **LUN4 的最小化尚未脚本化**：`gpt-minimal-build.py` 目前只处理 LUN0（`KEEP_CRITICAL` 是 LUN0 表）；
   LUN4 的删 4 项需要「同一套 emit 逻辑 + LUN4 的 keep 表」，落到 `--lun 4 --profile minimal-v1`。
2. ~~**`vbmeta` 描述符核对**~~ **已核（2026-11-17）**：`vbmeta_b` = `chain: boot` + `hash: dtbo`(4096 B)，不含 `vendor_boot`/`init_boot` ⇒ §4 P3 可以删。剩：`vbmeta_a` 当前全 0（stock a 槽既定态），若将来 a 槽也要跑 Linux 需自己签一份。
3. **Linux 直写 GPT**（不依赖设备内 `dd`）：`scripts/linux-gpt-apply.sh`（输入 main/backup，自动算 `backup_lba`、写双表、读回对账）。
4. **rootfs 归档不存在于库**（见 `LINUX-STATE-REPRO.md` §2 F 行）：最小系统一旦确立，应产出一份 `out/rootfs-debian-minbase-<date>.tar.zst` 并记账。
