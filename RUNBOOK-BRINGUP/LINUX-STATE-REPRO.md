# Linux 部署持久化 —— 从 EDL/fastboot 完整复现（含「卡 BL」误判防护）

> **本文件回答一个问题**：不管设备现在是什么状态（原厂 Android / 卡 BL / 半刷坏 / 我们自己的 Linux），
> 如何**只靠主机 + EDL(9008) + fastboot**，把「Linux 相关的设备进度」完整、可复现地重建出来，
> 且**不再出现「判成硬件坏了」这类误判**。
>
> 与 `RUNBOOK-BRINGUP/README.md` 的分工：那篇 = **首次上机全流程**（Phase −1…6，假设是从未动过的新机）；
> 本文件 = **状态复现 / 迁移 / 事故恢复**（3 种入口状态 → 同一目标态），所有命令都经过实机验证或 dry-run。
> 判据纪律的权威出处 = `.pi/AGENT-OPS.md`；坑 = `PITFALLS/`；本次事故全账 = `reports/bl-stuck-20261118-forensics.md`。

---

## 1. 判据纪律（动手前必读，本次事故就是违反这四条）

1. **「坏了」之前先做只读对账**：状态基线（§2 的 A–H 八项）没逐项读过、没和台账逐字节比过，不许下任何故障结论。
2. **硬件结论的四道门（全部满足才可以说硬件）**：
   ① 整包原厂全量线刷已执行（`rawprogram1..5 + rawprogram_save_persist_unsparse0 + patch0..5`，**含 6 LUN GPT 回原厂**）；
   ② 失败点有**单变量证据**（只改一类东西，现象随之改变）；
   ③ 「错误串自变」**不能**当证据（本机已知特性 `#482`：同一份镜像连发三种结果）；
   ④ EDL `poke/peek` 族**不可用**（`#486` loader secboot 门控），不得用它推 DRAM。
   > 2026-11-17 的反例：跳过 ①②，拿 ③④ 推「主板 DRAM 故障」，结果真因是 **GPT 非原厂**（§6）。
3. **单变量 + 可回退**：一次只改一类（GPT / 槽镜像 / 数据分区），改前 `dump`、改后**设备端**算摘要校验
   （`qdl sha256 <lun>/<lba>+<n>`，不信退出码，`#669`）。
4. **通道先自证**：`pgrep -af "[f]astboot"` 数孤儿 + `getvar product` < 5 s（`#658`/`#371`）；
   任何 `fastboot` 命令带 `-s HA2EXB0E`（裸命令会打到同总线另一台机）。

---

## 2. 「Linux 进度」= 8 项设备状态（复现清单，缺一不可）

| # | 项 | 在哪里 | 校验 | 台账/来源 |
|---|---|---|---|---|
| **A** | **GPT（6 LUN）**：LUN0 必须含 `linux17`(≥192 GiB)、`eldenesp`(512 MiB)；LUN4 的 `boot_a/boot_b` 属性正常 | 设备 LUN0/LUN4 | `scripts/gpt-audit-tb322fc.py`（逐字节 vs 官方）+ `partlabel` 列表 | 本单元 dump：`backup/<SN>-16+512/gpt_*.bin` |
| **B** | **b 槽内核镜像**（持久启动件） | `boot_b` 分区 | `qdl sha256 4/321824+24576` == 台账 sha | `bootslot-b/boot_b.img`（现 `06c081ca…` = vk192） |
| **C** | **a 槽/ESP 链路件**（UEFI 那条） | `boot_a` 或 `eldenesp:\EFI\BOOT\BOOTAA64.EFI` | 同上 / `sha256sum` on ESP | `out/boot-elden-vk192.img`（`bdf47f5f…`）、`out/grub-*`、`Loader.efi` r73 |
| **D** | **AVB 相关**：`vbmeta_b`(自签)、`dtbo_b`(4 KiB dummy)、`dtbo_a`(32 MiB 全 0) | LUN4 分区 | `qdl sha256` | `backup/vbmeta_b-20261110.img`（`e974ebab…`）、`out/dtbo-dummy.img` |
| **E** | **ESP 内容**：`BOOTAA64.EFI`(GRUB v10 嵌入菜单) + `EFI/elden/Loader.efi`(r73) + `boot/boot.img` + `menu.cfg` + `grubenv` + 字体 + `.bak` | `eldenesp`（FAT32） | 目录清单 + 每件 sha | `DEVICE/README.md` §1.1 现役件段（唯一台账） |
| **F** | **rootfs**：ext4 `linux17`，含 Debian/Phosh + `/lib/modules/<UTS>`（整套）+ `/boot/{Image,elden.dtb,initrd}` + `phoc` divert/hold | `linux17` | `findmnt /`、`lsmod \| wc -l`、`uname -r`、`dpkg-divert --list \| grep phoc` | **库里没有全量 rootfs 归档**（只有 `rootfs/` overlay 骨架 952 KB）⇒ F 项的「备份」实质 = **设备 `linux17` 分区本体 + 它的 LBA 台账**（见 §3 S3 两条路径） |
| **G** | **槽属性**：Linux 槽 `byte[6]` 必须含 `bit6`(successful)+`tries=7`（否则约 7 次重启后被标 unbootable，`#181`） | LUN4 GPT `boot_b` 条目 | `scripts/slot-attr.py show`（双表都要读） | 同脚本 `mark-successful b` |
| **H** | **回退资产**：原厂 259 全量包、本单元 GPT/独有分区 dump、`bootslot-b/*`、`out/*.img`+`*.manifest` | 主机 | `scripts/linux-state-audit.sh --host` | `RESOURCES/README.md` §2 |

> 判读口诀：**A/B/C/D/E/F 是「内容」，G 是「计数器」，H 是「后悔药」**。任何一项没读到，就不算「已核对」。

---

## 3. 复现步骤 S0–S9（任选入口状态，收敛到同一目标态）

入口状态三种：**原厂 Android / 卡 BL（只落 fastboot）/ 半刷坏（GPT 与镜像不一致）**。差别只在 S2，S3 起完全一致。

### S0 主机侧装备（零设备操作）

```sh
cd ~/y700-elden
bash scripts/linux-state-audit.sh --host        # 逐项检查 A–H 的资产是否齐、sha 是否对
```

### S1 只读取证（3 条通道，按现态选一条；**不许写**）

```sh
# ① Android 可用：adb
adb devices | grep HA2EXB0E && adb -s HA2EXB0E shell getprop ro.build.display.id
# ② 落 fastboot：getvar 全家桶（槽是判「ABL 有没有尝试」的唯一活口径）
for v in current-slot slot-retry-count:a slot-retry-count:b slot-successful:a slot-successful:b \
         slot-unbootable:a slot-unbootable:b unlocked battery-voltage battery-soc-ok; do
  timeout -k 5 6 fastboot -s HA2EXB0E getvar $v 2>&1 | head -1; done
# ③ EDL 只读（GPT/misc/logfs；一次会话 10 条命令，见 forensics §6）
timeout -k 5 20 fastboot -s HA2EXB0E oem edl; sleep 6; lsusb | grep 05c6:9008
```
然后 **对账**（这是本次事故里被跳过、代价最大的那一步）：

```sh
python3 scripts/gpt-audit-tb322fc.py --dev <dump目录> --stock ~/文档/TB322FC_15.10.259
```
判读：`分区数/命名/属性字节` 与官方不同 = **GPT 非原厂**，在把这一项清掉之前，任何「镜像坏了/硬件坏了」的结论都无效。

### S2 收敛到「已知好基线」（唯一允许的大动作）

```sh
PKG=~/文档/TB322FC_15.10.259; L=~/下载/tb322fc/xbl_s_devprg_ns.melf; Q=~/edl/qdl/build/qdl
css_edl() { timeout -k 5 20 fastboot -s HA2EXB0E oem edl; sleep 6; lsusb | grep 05c6:9008; }
css_edl
# ① 只改 GPT（88 KiB，零数据损失；T1）
cd "$PKG" && $Q -f -s ufs "$L" gpt-only0.xml gpt-only4.xml patch0.xml patch4.xml
# ② LUN4 全套（boot/dtbo/vbmeta/固件 + GPT）：37 分区 / 793.6 MiB
$Q -R -f -s ufs "$L" rawprogram4.xml patch4.xml
# ③ LUN0 全套（super/metadata/lenovoraw + GPT）：~15 GiB / 6 min @41 MiB/s
$Q -R -f -s ufs "$L" rawprogram_save_persist_unsparse0.xml patch0.xml
$Q -s ufs "$L" reset
# ④ 起 Android 基线（userdata_*.img 在包内缺失，必须显式擦）
adb devices | grep HA2EXB0E && adb -s HA2EXB0E reboot fastboot
fastboot -s HA2EXB0E -w && fastboot -s HA2EXB0E reboot
```
- **`-R` 是必须的**：同一台机的第二次 `qdl` 调用前，上一发默认会发 reset 把设备踢出 EDL ⇒ `SAHARA: failed to read request`（2026-11-17 踩过）。
- **一条命令版**：`bash scripts/t2-stock-lun45.sh`（已把上述 ①②③ + reset + 120 s 轮询封好，日志落 `reports/artifacts/bl-stuck-20261118/flash/T2.log`；2026-11-17 用它的变体实际恢复成功）。
- 期望：约 3 min 后 `adb devices` 出现 `HA2EXB0E device`，`getprop sys.boot_completed` = 1。
- 失败分支：仍回 recovery ⇒ `fastboot -w` 再 reboot；仍落 fastboot ⇒ 回 S1，别猜硬件。
- **这一步的意义**：把「未知状态」变成「逐字节原厂」，之后所有实验都有基线可退。

### S3 GPT 手术：加回 `linux17` + `eldenesp`

**两条路径，优先 (a)**：

**(a) 数据还在、只要条目（零数据损失）** —— 当设备曾经有过 Linux（哪怕现在跑着原厂 Android）：
按「丢失前那一次的 LUN0 dump」里的 `start / size` 原值重建条目，**不要重新分区、不要格式化**。

```sh
# 输入：旧 dump（例：本次 18:53 取的 gpt0-primary.bin，linux17 start=73277435 × 192 GiB、eldenesp start=123609088 × 512 MiB）
python3 scripts/gpt-audit-tb322fc.py --dev <旧dump目录> --stock "$PKG" --luns 0   # 先看清原 start/size/名字
python3 scripts/gpt-surgery-tb322fc.py add \
  --main "$PKG/gpt_main0.bin" --backup "$PKG/gpt_backup0.bin" \
  --part linux17:<start>:<nsectors> --part eldenesp:<start>:<nsectors> \
  --out-prefix "$BAK\/gpt_readd"      # 若脚本无 add 子命令：用 --linux-gib 同值 + 手校 start 与旧 dump 逐字段相等
# 写主表(0)+备表(<BLBA>)，读回再用 gpt-audit 对账；随后挂载验证数据：
mount /dev/disk/by-partlabel/linux17 /mnt/x && ls /mnt/x/usr/bin | head
```

判据：`blkid` 能读出 `linux17` 的 ext4 UUID/LABEL，挂载后 `/mnt/x/etc/os-release` 在且 `/lib/modules/` 有整套目录。

**(b) 数据已丢、要重建** —— 只有在这种情况下才新建分区 + 重装 rootfs（走 `RUNBOOK-BRINGUP/README.md` Phase 4，或从 Debian 基底重建 `rootfs/` overlay）：

```sh
python3 scripts/gpt-surgery-tb322fc.py build \
  --main "$BAK/gpt_main0.bin" --backup "$BAK/gpt_backup0.bin" \
  --out-prefix "$BAK/gpt_linux" --linux-gib 192 --esp-gib 0.5
python3 scripts/gpt-surgery-tb322fc.py list --main "$BAK/gpt_linux_main0.bin"   # 记下 backup=<BLBA>
```

- 必须**写主备双表**并重算 CRC（`slot-attr.py`/`gpt-surgery` 已处理）。
- 写 GPT 会让 `/dev/sdX` 短暂重扫（Linux 侧 ~3 s），属正常（`#487`）。

### S4 槽镜像（顺序：先 b 后 a）

```sh
fastboot -s HA2EXB0E flash dtbo_b  out/dtbo-dummy.img         # 4 KiB 全零，ABL 跳过 overlay（BL-02/07）
fastboot -s HA2EXB0E flash vbmeta_b backup/vbmeta_b-20261110.img
fastboot -s HA2EXB0E flash boot_b  bootslot-b/boot_b.img      # 现役 vk192（06c081ca…）
# a 槽链路二选一：
#  (i) 直载：flash boot_a out/boot-elden-vk192.img
#  (ii) ESP/UEFI：boot_a 留原厂或空载件，走 esp GRUB → Loader.efi → \boot\boot.img
fastboot -s HA2EXB0E --set-active=b
```
**每条写完立刻 `qdl sha256 4/<lba>+<n>` 核账**（不信 `fastboot flash` 自报）。

### S5 ESP 内容（`eldenesp`）

FAT32 + 现役件（台账 = `DEVICE/README.md` §1.1）：`/EFI/BOOT/BOOTAA64.EFI`（GRUB v10 嵌入菜单）、
`/EFI/elden/Loader.efi`（r73）、`/boot/boot.img`（= `out/boot-elden-vk192.img`）、`/menu.cfg`、`/grubenv`、字体 `*.pf2`。
用 `mcopy`/`mtools`（主机侧组装后整分区写入）；保留 `.bak` 件（`.arming-v6.bak` 等）便于回滚。
判据：`mmd -i`/`mdir -i` 列表与台账逐项 sha 一致；ESP 路径的 cmdline = `androidboot.serialno=51318dc0` 且**无** ABL token。

### S6 rootfs（`linux17`）

```sh
# 设备在 Linux 侧或 RAM 启动时：解 tar → 叠加模块 → depmod → 放 /boot 件
tar xzf env-pass/backup-*/linux17-rootfs-*.tar.gz -C /mnt/new
tar xzf out/modules-<UTS>.tar.gz -C /mnt/new && depmod -b /mnt/new <UTS>
cp out/boot-elden-vk192.img /mnt/new/boot/Image.tmp   # 实际按 manifest 的 kernel/dtb/initrd 组合
scp /mnt/new/... ; scripts/phoc-install.sh            # 自编件必须 divert + apt-mark hold（#654）
```
**模块必须整套同 UTS 部署**（RAM 起新核前尤其，`PITFALLS` 内核条）。

### S7 槽属性（持久性的关键，60 s）

```sh
scp scripts/slot-attr.py root@192.168.7.1:/tmp/ ; ssh root@192.168.7.1 'python3 /tmp/slot-attr.py mark-successful b'
# 或从主机侧直接改 LUN4 双表；写完必须 `show` 复核双表 byte[6] 都含 0x40
```

### S8 冷起 + 验收

```sh
ssh root@... 'sync; reboot'          # 或长按电源 15–20 s 冷起
```
验收 20 项（照 `RUNBOOK-BRINGUP/README.md` §7 Phase 6 表逐条；最短集）：
`uname -r` = 台账 UTS → `/` = `linux17` → `lsmod | wc -l` ≈ 台账 → DSI `bound` → WiFi `wlp1s0` UP →
`/dev/fastrpc-adsp` → SensorProxy ×3 → Waydroid session → s2idle fail=0。

### S9 反向（回 Android，本次实测 8 min）

```sh
adb -s HA2EXB0E reboot fastboot && fastboot -s HA2EXB0E -w && fastboot -s HA2EXB0E reboot
# 需要完整原厂：S2 ①②③ 全套；只要 Android 能起：S2 ① + ② 已足够（11-17 实测）
```

---

## 4. 持久化边界：什么改动「留下来」了

| 改动 | 存在哪 | 重启后还在？ | 换 Android/回原生后还在？ |
|---|---|---|---|
| 内核 / DTB / initrd | `boot_b` 分区内容 | ✅ | ❌（S2/S4 会覆盖） |
| 模块 / 用户态 / 桌面 | `linux17` 文件系统 | ✅ | ✅（数据不写就还在，但条目会丢，见 §6.3） |
| GRUB / Loader / ESP boot.img | `eldenesp` | ✅ | ❌（GPT 手术会丢条目） |
| GPT 分区（`linux17`/`eldenesp`） | LUN0 GPT | ✅ | ❌ 原厂 GPT 覆盖即消失 |
| 槽「成功」标记 | LUN4 GPT `boot_b` 属性 | ✅（写入后） | ❌ |
| kexec/RAM 启动的内核 | 内存 | ❌ | — |

⇒ **「Linux 进度」= B+C+D+F 内容 + A 条目 + G 计数器**；只保留文件系统（F）而丢 A/G 是本次事故后设备的状态。

---

## 5. 台账与快照（每次变更都做，30 s）

```sh
bash scripts/linux-state-audit.sh --snapshot versions/state-$(date +%Y%m%d-%H%M).tsv
```
快照含：设备态（adb/fastboot/EDL）、8 项的存在性 + sha、GPT 与官方差异摘要、槽属性、电池。
变更后立刻再拍一份，`diff` 两份快照 = 本次到底改了什么（取代「凭记忆复述」）。

---

## 6. 事故回放：2026-11-17「卡 BL」误判（反面教材，全文见 `reports/bl-stuck-20261118-forensics.md`）

1. **现象**：`continue`/`boot` 全报 `Device Error` / `Load Error`；39 个引导固件分区已回原厂且 39/39 校验。
2. **误判**：拿「错误串自变」+「单发 `poke` 不返回」推「运行期大块内存访问不稳 = 唯一存活解释（硬件类）」，
   写进 `DEVICE/service-repair-note-*.md` 准备送修。
3. **真因（单变量证据）**：**只写 88 KiB 的 GPT（LUN0+LUN4 主备表，零镜像改动）**，现象立刻从「直接落 fastboot」
   变成「解锁警告 → 联想 logo」；再把 LUN4/LUN0 全套原厂刷上 + `fastboot -w`，Android 16 完整启动
   （`sys.boot_completed=1`）。⇒ **非原厂 GPT** 才是 ABL `load/authenticate` 失败的原因。
4. **为什么之前没发现**：「GPT 已排除」只验了 `printgpt` **可解析**，没验**逐字节回原厂**（命名/条目/属性字节）。
5. **五条教训**：① 硬件结论四道门（§1.2）；② GPT 必须逐字节对账；③ `qdl` 多次调用要 `-R`；
   ④ `logfs` 里的 `Failed to add memory space` / `NBAT` / `VBAT` 都不能当证据（成功段里也有）；⑤ 先到基线再实验。

---

## 7. 现象 → 首查 → 处置（高频表）

| 现象 | 首查 | 处置 |
|---|---|---|
| 落 fastboot、`continue` 报 `Device Error` | §2 A（GPT 对账）+ §1.4 通道 | 先 §3 S2 ①（GPT 回原厂），再谈别的 |
| `fastboot boot` 报 `Load Error` | `dtbo_<slot>` 是否原厂 Android DTBO（BL-02/07）、镜像 >24 MiB（BL-06） | `flash dtbo_b out/dtbo-dummy.img` |
| 起 7 次后进不去 | `byte[6]` 的 `bit6` | `slot-attr.py mark-successful <slot>`（S7） |
| Android 起但落 recovery | userdata/metadata 不兼容 | `fastboot -w` + reboot |
| `adb shell` 在 recovery 里 SIGABRT | recovery adbd 的 SELinux 限制 | 走 `adb reboot fastboot` 用 fastbootd |
| 卡 GRUB→initrd 交接 | `PITFALLS #659` | 不预置 initrd 属性、用嵌入菜单件 |
| 想读 DDR 判内存 | `#486`（loader 不支持 peek/poke） | 不做；改用「原厂全量 + 单变量」判 |

---

## 8. 待补（本文件当前边界）

- **rootfs 无全量归档**（唯一硬缺口）：`F` 项的恢复依赖设备上 `linux17` 分区本体；一旦该分区的数据被真正覆盖（写 super/userdata 落到该 LBA 区间），只能重装。
  ⇒ 两次铁律：① **任何会落刀到 `linux17` 的写操作前，先确认它的 start/size 台账**；② 每次改 GPT 后立刻把新的 LUN0 dump 归入 `backup/<SN>-16+512/` 并更新 `SHA256SUMS`。
- S3 的「EDL 直写 GPT」目前分两步（Linux 内 `dd` / 主机 `qdl`），尚未做成一条脚本；
  目标：`scripts/linux-gpt-apply.sh --gpt <main> --backup <backup>`（输入 = `gpt-surgery` 产物，自动算 backup_lba、写双表、读回对账）。
- S5 ESP 组装仍手工（`mcopy`），目标：`scripts/esp-apply.sh --esp-dir out/esp-20261116/`。
- 这两条落地的判据：**在 U2 上从「原厂 Android」一口气跑到「Linux 登入」全程无手工步骤**（当前需 2 次人工）。
