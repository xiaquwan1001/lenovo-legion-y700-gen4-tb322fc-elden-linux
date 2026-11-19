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
>
> **⚠ 第 9 项（2026-11-19 补）：「包 + 桌面」≠ 「能用的设备」——rootfs 重建会静默丢「非包状态」**：
> 最小根的 165 包与桌面壳可以全绿（`deploy-desktop-shell.sh --check` MISS=0），而下面三类**不属于包**的状态全空，
> 表现却是「设备丢了 / ssh 不通 / 没有 WiFi」：
> | 丢的东西 | 成因 | 症状 | 判据 / 修法 |
> |---|---|---|---|
> | `xuqianhui1001` 的 `~/.ssh/authorized_keys` + sudo 免密 | 只把公钥装给 root | **`ssh elden` 被拒**（Permission denied），而 `root@192.168.7.1`/`ssh elden-root` 一直好用 ⇒ 误判「ssh 不通」 | `deploy-desktop-shell.sh` §3b（已机械化，`--check` 会 MISS）；`PITFALLS #689` |
> | NetworkManager 连接档（`/etc/NetworkManager/system-connections/*`） | 凭据文件不属包，且**不得**进仓 | 驱动/扫描都正常（`nmcli dev wifi list` 有 AP）、状态栏却没有 WiFi 图标（`nmcli connection show` 只有 `lo`） | 判据 = `ls /etc/NetworkManager/system-connections/ \| wc -l`（=0 即「没连过」）；修 = 用户自己输凭据 |
> | 桌面用户 dconf（深浅色/输入法/字体） | 在 `/home` 里，不在包 | UI 回默认值 | `TASKS` G1-26/27 的 dconf 项；重跑 `daily-baseline` 对应段 |
>
---

## 2.5 控制面矩阵（「现在怎么和设备说话」——五条通道，逐条带判据）

> 2026-11-19 实测现态：**USB-NCM SSH 通**（`root@192.168.7.1`，`uptime 1:56`、`systemd is-system-running=running`、`systemctl --failed` 空）。
> 判据顺序固定：**先只读验活，再动手**；任何写操作走 `scripts/device-lock.sh` 串行。

| # | 通道 | 用在什么时候 | 主机侧命令 | 判据 |
|---|---|---|---|---|
| 1 | **USB-NCM SSH**（主通道） | 系统已起到用户态 | `sudo scripts/ncm-host-up.sh`（或 `ip addr add 192.168.7.3/24 dev enx021e5eede102`）→ `ssh elden-root` / `ssh elden` | `ping -c1 192.168.7.1` + `ssh … 'ps -p1 -o comm='` = `systemd` |
| 2 | **USB ACM 串口**（零网络兜底） | 没网、没 ssh、要看 console | `scripts/acm-sh.py`（`/dev/ttyACM1`，`console=ttyGS0`） | 能拿到 shell / 能看到 `dmesg` |
| 3 | **fastboot**（引导/槽/分区） | 换 boot 件、看槽属性、进 EDL | `timeout -k 5 20 fastboot -s $SN getvar product`（**< 5 s**） | 槽四项：`current-slot`/`slot-successful:X`/`slot-unbootable:X`/`slot-retry-count:X` |
| 4 | **EDL 9008**（写盘/救砖/GPT） | 分区表、根镜像、读回校验 | `fastboot -s $SN oem edl` → `lsusb \| grep 05c6:9008` → `~/edl/qdl/build/qdl …` | **一次会话一件事**（`#675`）；写后**设备端** `qdl sha256` 对主机 `sha256sum`（`#669`） |
| 5 | **adb**（仅 Android 槽） | 安卓面取证/装包 | `timeout 20 adb devices` | 必须见 `HA2EXB0E`；`MDX5T20730009849`（P40pro）/`emulator-5554` **不是本机，禁写** |

**通道之间怎么切换**（Linux → fastboot/EDL 是「单向门」，进了就回不来，除非重启）：

| 从 | 到 | 动作 | 注意 |
|---|---|---|---|
| Linux | 重启回 Linux | `ssh … 'systemctl reboot'` 或物理长按 | 主机的 `192.168.7.3/24` 地址**随 gadget 重建消失**，每次都要重加（S5） |
| Linux | fastboot | `ssh … 'systemctl reboot bootloader'`（内核 `psci-reboot` 钩子，G1-24；历史上 `reboot2 bootloader` 22 s 进 fastboot） | **minbase 根没有 `reboot2`/`eldroid-bootctl`**（那两个是 Alpine 期件）⇒ 用 systemd 的 reboot arg；若不吃参数，退 `fastboot oem edl` 已不可用 ⇒ 走 ACM 串口 `reboot -f bootloader` |
| fastboot | EDL | `fastboot -s $SN oem edl` | 会话一次性（`#675`） |
| Android | fastboot/EDL | `adb reboot bootloader` / `adb reboot edl` | 先 `adb devices` 确认是本机 |
| 任意 | Linux（持久） | `fastboot -s $SN reboot`（走 `_b`，`slot-successful:b=yes`） | 回 Linux 后 45 s 内 gadget 必枚举（`lsusb \| grep 1d6b:0104`） |

**设备侧「自检一条命令」**（只读，不连外网）：`bash scripts/zero-to-desktop-check.sh`（S5–S12 共 8 步，`--list` 机读）；
**主机侧「资产自检」**：`bash scripts/linux-state-audit.sh --host`。

---

## 2.6 发展路径（这条路怎么走到今天的；每段只留「裁决 + 指针」）

| 阶段 | 做了什么 | 关键裁决/产物 |
|---|---|---|
| 2026-10-03 起 | BL 解锁 → b 槽 RAM 起 mainline → GPT 手术建 `linux17`(193 GiB) → 持久 rootfs → Phosh 自启 | 首次上机全流程 = `RUNBOOK-BRINGUP/README.md`（Phase −1…6）；`linux17` 起点 LBA **73277435** |
| 2026-10-04 ～ 10-19 | 外设/用户态逐项收口：音频 tplg SD 线、CDSP split 固件入 initrd、DP（`dr_mode=otg`）、相机 30 fps、TF 卡、WiFi 候选榜、日用基线 | 状态与证据只在 `TASKS/README.md` §1（G1-0…G1-38） |
| 2026-10-22 ～ 11-16 | 内核线 vk127 → vk192（suspend/pstore-ram 守卫），Waydroid/传感器/触觉；UEFI 间接引导两形态打通 | 版本账 `versions/vk-registry.tsv`；现役 vk192 UTS `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0` |
| **2026-11-17 20:0x** | 事故：全量回原厂 Android 16（真因 = **非原厂 GPT**，不是硬件） | ⇒ `linux17` 条目/ESP 被覆盖；**GPT 恢复到双轨** |
| **2026-11-18** | 安卓「最小化线刷包」上机成功（`super_min` 8.28 GiB、`/system` 5.0 GiB）；随后 `fastboot -w` + recovery factory reset ⇒ **`userdata`(449.7 GiB) 覆盖 `linux17` 区间 + discard 成零** | 判定 = `TASKS/sessions/2026-11-18-安卓最小包上机成功与卡动画.md`；安卓侧仍卡 ZUXOS 动画（未取证） |
| **2026-11-19** | **重建**（不是恢复）：GPT 手术表重写（主备读回一致）→ EDL 写 6 GiB 最小根（`/init`+`usb-gadget`+`udhcpd`）→ 刷 `boot_b`（`elden_root=LABEL=linux`）→ 显示真因 = 缺 `udev` → `resize2fs` 到 190 GiB → 日用基线 → greetd+phoc+phosh（GPU 渲染 Mesa 26.1.6） | 全链 = `RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md` S1–S12；账 = `TASKS/sessions/2026-11-19-{主线恢复最小Linux与显示定位,显示修复=minbase缺udev,EDL到桌面端到端重建}.md` |

**丢东西的三个闸**（这正是「重建 ≠ 恢复」的地方）：① GPT 条目 —— 有备份可写回；② `linux17` 数据 —— **原厂 `userdata` 覆盖 + `fastboot -w` discard 后物理归零，无法恢复**（EDL 6 点采样全 0 已证）；③ **非包状态**（公钥/sudo/WiFi 凭据/dconf）—— 不属任何镜像，只能脚本重建或人工重输（见 §2 第 9 项）。

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

### S6 rootfs（分区名 `linux17`，fs label = `linux`）

> **2026-11-19 纠错**：旧版这里写 `tar xzf env-pass/backup-*/linux17-rootfs-*.tar.gz -C /mnt/new` ——
> 该归档**不在盘**（`env-pass/` 只剩 `scripts/ tools/`），且属 Alpine(musl/OpenRC) + label `linux17` 世代。
> 与本文 `:306`「rootfs 无全量归档」自相矛盾，已按后者收口 ⇒ **无归档可解，走 ZERO-TO-DESKTOP S3 + S10/S11 收敛**。

```sh
# 建根 = EDL 写 minbase ext4（ZERO-TO-DESKTOP S3）；无 tar 解包步骤
# 模块：整套同 UTS 部署（脚本自动取当前 KV）
bash scripts/deploy-modules.sh                      # 代替旧 `tar xzf out/modules-<UTS>.tar.gz` + depmod
# /boot 件 + 自编件 divert/hold
cp out/boot-elden-vk192.img /mnt/new/boot/Image.tmp   # 实际按 manifest 的 kernel/dtb/initrd 组合
scripts/phoc-install.sh                               # 自编件必须 divert + apt-mark hold（#654）
```
**模块必须整套同 UTS 部署**（RAM 起新核前尤其，`PITFALLS` 内核条）。

### S7 槽属性（持久性的关键，60 s）

> **2026-11-19 纠错**：旧版本这里让**设备侧**跑 `python3 /tmp/slot-attr.py mark-successful b` ——
> 但现役 minbase 根**没有 python3**（165→1253 包里也没装）⇒ 那道命令只会报 `python3: not found`，
> 看起来像「写了」实际什么也没写。槽属性**一律在主机侧**改（工具也就在主机）。

```sh
# 只读先看（主备双表）：
python3 scripts/slot-attr.py show --sn $SN
# 设备无 python3 ⇒ 由主机 dd 出 LUN4 主备 GPT → 打补丁 → 写回（2026-11-19 实走路径，#677/#678）
python3 scripts/slot-attr.py --image back4.bin mark-successful b     # 改两份表里的 byte[6]
# 写完必须回读复核：主备 byte[6] 都含 0x40，且 `fastboot getvar slot-successful:b` = yes
```

> 同一文件里的 **Linux→fastboot 软路径已不成立**（见 §2.5 切换表 + PITFALLS `#690`）：
> 现役 vk192 主线核无 vendor RESTART2 钩子 ⇒ 进制 fastboot 只能手工按键。

### S8 冷起 + 验收

```sh
ssh root@... 'sync; reboot'          # 或长按电源 15–20 s 冷起
```
验收 20 项（照 `RUNBOOK-BRINGUP/README.md` §7 Phase 6 表逐条；最短集）：
`uname -r` = 台账 UTS → `/` = `LABEL=linux`（`/dev/sda17` ext4；`linux17` 仅是 GPT 条目名）→ `lsmod | wc -l` ≈ 台账 → DSI `bound` → WiFi `wlp1s0` UP →
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
   **⬛ 该送修单已于 2026-11-19 整体标作废（顶部 `⛔ 作废` 抬头）**；设备不需要送修、不需要换主板。
   新旧口径对照 / 在线判定 / 上机计划 = `reports/device-status-20261119.md`；上机判据 = `DEVICE/README.md` §1.6。
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
- S3 的「EDL 直写 GPT」已完成主机侧自动化（2026-11-18）：`scripts/linux-gpt-apply.sh --gpt <main> --backup <backup>`
  从主表头取 `alt_lba` 算 `backup_lba`，**写前校验双表 header/entries CRC、互指、entries 一致**，写主备双表后读回逐字节对账；
  默认即 dry-run，`--dry-run` 可显式写。**未上机**（设备不在线）；判据 = 真机一次写表读回 sha 相等。
- S5 ESP 组装已自动化（2026-11-18）：`scripts/esp-apply.sh --esp-dir <dir> --gpt <LUN0 主表 dump>`
  = 查分区 LBA → 必需件校验 → mkfs.fat + mtools 组 FAT32 → `mtype` 逐文件 sha 自查 → qdl 写 + 读回对账；
  默认 dry-run，`--build-only` 离线自测，`--apply` 才写。**未上机**。细节/自测证据：`reports/esp-gpt-apply-automation-20261118.md`。
- 这两条落地的判据：**在 U2 上从「原厂 Android」一口气跑到「Linux 登入」全程无手工步骤**（当前需 2 次人工）。

---

## 8. 过时条目审计（2026-11-19，Alpine 期遗留）

换了根（Alpine → Debian trixie）之后，仓里大量「可执行步骤」仍按 Alpine 写；审计做了两轮（文档层/脚本层，子代理 + 父代理抽检）：

- `reports/stale-alpine-audit-docs-20261119.md`（C 17 / B 12 / A 12）
- `reports/stale-alpine-audit-scripts-20261119.md`（C 29 / B 10 / A 7）

**已修的 6 条**（抽检成立后才改）：`build-boot.sh` 根 label、`to-fastboot.sh`/`slot-switch.sh` 的软复位静默空等（`PITFALLS #690`）、
本文件 S7 的设备侧 `python3`、`f2fs-migration.md` 全文作废抬头（`/dev/sda18` 现为 ESP）。
**剩余 C 类**（`n5b-vk64-death-rate` / `kexec-bs-cycle` / `arm-window-hunt` / `uefi-*` 六件的 `reboot2` 调用、
`openrc-enable.sh` / `fix-logind-poweroff.sh` / `persistent-overlay/restore.sh` / `deploy-zh-ime.sh`（squeekboard 栈））
按「一次一个 cohort」推进，未改前**不要照跑**。

## 9. 2026-11-19 晚的上机教训（#693，镜像侧待执行）

重装根后多次复现：**开机后 `droid-juicer.service` + `plymouth-quit-wait.service` 是死循环**
（不是慢），`graphical.target` 永远 waiting；kill -9 无效（systemd 重拉）；一次 mask+kill 组合
之后**整机掉电**（无 Oops、无 pstore、journal 截断 ⇒ `Hard watchdog permanently disabled`）。
判据与安全约束全文 = `PITFALLS sessions/325-*.md`；`deploy-desktop-shell.sh` §8b 已机械化"未 mask 即 MISS"。

**下一步（镜像侧根治，待用户点头执行）**：在 `out/min-restore-20261119/rootfs-minbase-gadget-20261119.ext4.img`
上 debugfs 删 `droid-juicer` / `plymouth-*` / `qcom-modem-setup` / `bootmac-bluetooth` 的 enable 链接
→ 重算 sha256 → 按 §3 S3 重写根 → 验证「开机即桌面」。

**资源重审** = `reports/resource-revue-20261119.md`（~16 条在用 / 12 条过时 / 4 类缺口，含
`apt-list.txt` 的 `libssc2`/`libssc-bin` 在 Debian 13 不存在 ⇒ 传感器必须源码编译路线）。
