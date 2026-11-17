# 卡 BL 现况取证 + 原厂全量线刷预案（2026-11-17 18:53，只读；用户将亲自刷机）

> 触发：用户质疑「没做过原厂全量线刷之前不能定性硬件」。本文件 = ① 18:53 只读取证（零写盘）；
> ② 与官方 259 包的**逐字节**对账（此前只验过「可解析」）；③ 分级刷机预案 A/B/C + 命令 + 预期数字 + 回退。
> 前序全账：`reports/bl-stuck-20261117-device-window.md`（§10 = 定性修正）、`reports/bl-history-and-playbook.md`。
> 取证件：`reports/artifacts/bl-stuck-20261118/`（9.3 MB + `SHA256SUMS.txt`）。

## 0. 结论（先数字）

1. **定性 = 未定因**（11-17 18:5x 撤回「硬件」判读，理由 = `bl-stuck-20261117-device-window.md` §10）。
2. **与官方包的差距只剩 3 处**（此前文档记为「GPT 已排除」，实际是只验了可解析）：
   - **LUN0 GPT**：18 分区 vs 官方 16；`super`/`userdata` 我方改名成 `elden-super`/`elden-data`；多出 `linux17`(192 GiB)、`eldenesp`(512 MiB)；`pstoredump` 被改名 `pstoredu`；另有 `vbmeta_system_a/b` 两个属性字节非 stock。**这份 GPT 从未回原厂。**
   - **LUN4 GPT 属性字节**：78 个分区里 **22 个**的 A/B 属性字节与 stock 不同（见 §2.2）——其中仅 `boot_a`/`boot_b` 被 ABL 当真，而那两处的差异 = `successful` 位被清（我方 Linux 从不 mark-successful，`#181`）+ `boot_b` 的 `unbootable` 位被清 ⇒ **可解释、非新异常**。
   - **`misc` BCB**：前 7 字节由 `ffbm-00` 变全 0（我方 17:xx 清 BCB 的结果仍在）。
3. **LUN1/LUN2/LUN3/LUN5 的 GPT 与官方 `gpt_main*.bin` 逐字节相同**；引导固件内容 39/39 已等于官方（11-17 §7）。
4. ⇒ **便宜且未做的对照 = 只把 GPT 回原厂（T1，写 ~50 KB，不动任何数据分区）**；形式上最完整的是 **T3 = 整包 `rawprogram1..5 + rawprogram_save_persist_unsparse0 + patch0..5`**（dry-run 已验：**73 分区 / 15.6 GiB / 78 patch**）。

## 1. 现况（18:53，`fastboot -s HA2EXB0E getvar all` 全量见 `artifacts/bl-stuck-20261118/getvar-all-20261117-1853.txt`，281 行）

| 项 | 值 |
|---|---|
| USB | `18d1:d00d` fastboot（`fastboot devices` → `HA2EXB0E`），EDL 进出正常（`oem edl` 4 s；`qdl reset` 后 12 s 回 fastboot） |
| 槽 | `current-slot:a`、`unbootable:a/b:no/no`、`retry-count:a7/b6`、`successful:a/b:no/no` |
| 安全态 | `secure:yes`、`unlocked:yes`、`Device critical unlocked:true`、`Verity mode:false` |
| 电量 | `battery-voltage:3571`（15:22 为 3425 ⇒ 在充，约 +146 mV/3.5 h）、**`battery-soc-ok:no`（未变）** |
| 电池口径更正 | 旧文档引 `logfs` 的 `VBAT: 3899mV` 当「已充到可用区间」——**该读数属过去成功启动段**（logfs 只存成功交接段 `#485`/`#594`）。现测只有 3571 mV，**充电通路仍未排除**（不阻塞，但也不许当反证） |
| 主机侧 | 无孤儿 `fastboot` 进程（`pgrep -af "[f]astboot"` 仅自身 shell）；ADB 上另有 `MDX5T20730009849`（**别的设备，本轮未碰**） |

## 2. 与官方 259 的逐字节对账（新做，EDL 只读）

工具：`~/edl/qdl/build/qdl -s ufs <loader> read <lun>/<lba>+<n> <file>`（一次会话 10 条命令、零写盘）；解析脚本见 §6。

### 2.1 GPT 五 LUN 逐字节 vs `~/文档/TB322FC_15.10.259/gpt_main{0..5}.bin`

| LUN | 分区数（设备/官方） | 与官方差异 | 备注 |
|---|---|---|---|
| 0 | **18 / 16** | **差 4 条**（缺 `super`、`userdata`；多 `elden-super`、`elden-data`、`linux17`、`eldenesp`）+ 2 处改名 | 我方 Linux 布局加了 2 个分区并把 super/userdata 改名 |
| 1 / 2 | 5 / 5 | **逐字节相同** | `xbl_a/b`、`xbl_config_*`、`apdp*` |
| 3 | 3 / 3 | **逐字节相同** | `cdt`、`ddr` |
| 4 | 78 / 78 | 名称/几何全同，**22 个分区属性字节不同** | 见 §2.2 |
| 5 | 5 / 5 | **逐字节相同** | `modemst1/2`、`fsg`、`fsc` |

LUN0 新增/改名（本机现值）：

```
[9]  elden-su?  → elden-super   start=90504     22.00 GiB   （= 官方 super 同起始、同尺寸，仅改名）
[15] elden-data                 start=5972392  256.75 GiB   （= 官方 userdata 位置，改名并缩短）
[16] linux17                    start=73277435 192.00 GiB   （我方 Linux 根，ext4）
[17] eldenesp                   start=123609088  0.50 GiB   （ESP，放 GRUB/Loader.efi）
```

### 2.2 LUN4 属性字节（`byte[6]`，权威位图 = `.pi/skills/qualcomm-edl-flashing/SKILL.md`）

位图：`bit2`=active(0x04)、`bit6`=successful(0x40)、`bit7`=unbootable(0x80)、`bits5..3`=tries。

| 分区 | 官方 `byte[6]` | 设备 `byte[6]` | 解读 |
|---|---|---|---|
| `boot_a` | `0x77` | **`0x37`** | successful 位被清（我方 Linux 不 mark-successful，`#181`）⇒ **可解释** |
| `boot_b` | `0xf3` | **`0x32`** | 同上 + 官方 b 槽本身带 unbootable 位 |
| `aop_a/tz_a/hyp_a/modem_a/abl_a/keymaster_a/devcfg_a/qupfw_a/vbmeta_a/dtbo_a` | `0x7f` | `0xcf` 或 `0x4f` | **非 stock**，但**只有 `boot_*` 的属性被 ABL 当真**（`SKILL.md` 明载「only boot_a/boot_b carry a live counter」）⇒ 惰性偏离 |
| 同名的 `*_b` 十个 | `0xfb` | `0x4b` | 同上（惰性） |
| 其余 56 个 | — | 与官方相同 | — |

⇒ LUN4 的属性偏离**不足以**解释 load/authenticate 失败（惰性字段），但它属于「GPT 未回原厂」的一部分，**T1 顺手就能清掉**。

### 2.3 `misc` / `logfs` / `xbl_sc_logs` / `devinfo`

| 件 | 现状 | 与 11-17 16:26 取证件对比 |
|---|---|---|
| `misc` | 前 7 字节全 0（BCB 空）；`0x8000` 槽元数据区 `02b0 0a74 5600 …` | **差 7 字节**（原 `ffbm-00` → 全 0，即我方清 BCB 的结果仍在） |
| `logfs`（8 MiB） | 10 段成功交接；seg0 = 本机（ECID `0x045A7FD29739`，Linux `_b`，带 `avb_slot_verify :913 Public key … rejected` 告警但照常起动）；seg1–9 = 官方模板（ECID `0x045AC096892B`） | **sha256 完全相同**（`21fbbf81…`）⇒ 今天的失败**没有**新增段级记录 |
| `xbl_sc_logs`（128 KiB） | 全 0（未启用） | **sha256 相同**（`fa43239b…`） |
| `devinfo`（4 KiB） | `dee6a0ca…`（解锁态来源） | 新取 |

**反证一条旧证据**：`logfs` 里 `Failed to add memory space :0x8088F000 0x1000`、`ERROR:NACK: SA:0x1C`、`mbox_os_init: Failed to locate SCM protocol for Mailbox 14` —— 这些行在**成功交接的 seg0 里也全都有** ⇒ 曾被当作「硬件共同形状」的这些打印是平台常态，不能当故障证据。

## 3. 由此产生的「未排除项」清单（取代旧的「软件层已排到底」）

| # | 未排除项 | 为什么仍可能 | 怎么排除 |
|---|---|---|---|
| 1 | **LUN0 GPT 非原厂**（改名 + 2 个自建分区） | ABL 在 load/authenticate 时会解析 GPT；此前只验了「可解析」 | **T1**（只写 GPT）或 **T3**（整包） |
| 2 | **LUN4 22 个分区属性非 stock** | 惰性字段，概率低但零成本可清 | T1 一并清 |
| 3 | **充电/供电通路**（3571 mV、`battery-soc-ok:no`） | 现测仅在慢充；旧的反证（3899 mV）已失效 | 墙充数小时到 `soc-ok:yes`，或换充电器/线，再冷起 |
| 4 | ABL/UEFI 加载通路本身 | 无段级日志，只能靠「全原厂后仍失败」反证 | T3 后仍失败 ⇒ 升级为硬件报修（此时才算证据充分） |

已排除（不再重复）：镜像内容/大小、写路径、槽属性编码、lock/verity、vbmeta 链与 dtbo 一致性、ABL 本体（两槽 stock）、存储读路径、LUN1/2/3/5 GPT、引导固件内容（39/39）。

## 4. 分级刷机预案（**用户亲自刷**；主机侧命令已用 `qdl --dry-run` 验过）

公共前置（在主机上，项目根）：

```sh
LOADER=~/下载/tb322fc/xbl_s_devprg_ns.melf          # 或 backup/fw/tb322fc-edl/xbl_s_devprg_ns.melf
PKG=~/文档/TB322FC_15.10.259                         # 官方 259 全量包（= backup/official-rom-15.10.259）
QDL=~/edl/qdl/build/qdl
# 0) 通道自证（必须 < 5 s）：无孤儿 fastboot
pgrep -af "[f]astboot"
timeout -k 5 5 fastboot -s HA2EXB0E getvar product
# 1) 进 EDL（4–6 s 后 lsusb 出现 05c6:9008）
timeout -k 5 20 fastboot -s HA2EXB0E oem edl
lsusb | grep 05c6:9008
```

**T1（最便宜，只改 GPT，零数据写）** — 建议先跑这一发，2 分钟：

```sh
cd "$PKG"
# 只取两个 GPT 行（LUN0 + LUN4），不写任何数据分区；patch 负责 NUM_DISK_SECTORS/CRC
$QDL --dry-run -f -s ufs "$LOADER" gpt-only0.xml gpt-only4.xml patch0.xml patch4.xml   # 先看 dry-run
$QDL           -f -s ufs "$LOADER" gpt-only0.xml gpt-only4.xml patch0.xml patch4.xml
$QDL -s ufs "$LOADER" reset
```

`gpt-only{0,4}.xml` 由 `rawprogram*` 里**只保留** `PrimaryGPT`/`BackupGPT` 两行生成：

```sh
python3 scripts/make-gpt-only-xml.py rawprogram_save_persist_unsparse0.xml -o /tmp/gpt-only0.xml
python3 scripts/make-gpt-only-xml.py rawprogram4.xml -o /tmp/gpt-only4.xml
```

已验（2026-11-17 19:1x，`--dry-run`）：**4 个 GPT 分区 / 88.0 KiB / 26 patch**（LUN0 + LUN4 的主备表）。
代价：`linux17`/`eldenesp` **条目**消失（数据物理仍在，见 §5 回退）；`super`/`userdata` 名字恢复原厂。

**T2（A+B，按 LUN 全套刷）**：

```sh
cd "$PKG"
# A: LUN4（37 分区 / 793.6 MiB / 13 patch；含 boot_a/boot_b=官方 Android、dtbo、vbmeta、logfs）
$QDL -f -s ufs "$LOADER" rawprogram4.xml patch4.xml
# B: LUN0（super/userdata/metadata/lenovoraw/lenovocust + GPT）
$QDL -f -s ufs "$LOADER" rawprogram_save_persist_unsparse0.xml patch0.xml
```
副作用：**`logfs` 分区会被官方模板覆盖**（我们 18:53 的 dump 已在 `artifacts/bl-stuck-20261118/`）；`elden-data` 内的少量低 LBA 区域会被 `userdata_*.img` 覆盖；`lenovoraw`/`lenovocust` 写回官方件（**刷完要复核 `getvar unlocked`**）。

**T3（整包，形式上最完整的「原厂全量线刷」）**：

```sh
cd "$PKG"
$QDL --dry-run -f -s ufs "$LOADER" rawprogram1.xml rawprogram2.xml rawprogram3.xml rawprogram4.xml \
      rawprogram5.xml rawprogram_save_persist_unsparse0.xml patch0.xml patch1.xml patch2.xml \
      patch3.xml patch4.xml patch5.xml          # dry-run 实测：73 分区 / 15.6 GiB / 78 patch
$QDL           -f -s ufs "$LOADER" rawprogram1.xml rawprogram2.xml rawprogram3.xml rawprogram4.xml \
      rawprogram5.xml rawprogram_save_persist_unsparse0.xml patch0.xml patch1.xml patch2.xml \
      patch3.xml patch4.xml patch5.xml
$QDL -s ufs "$LOADER" reset
```

风险窗口：写 `xbl`（LUN1/2）期间断电 ⇒ 仍可 EDL 重入，但别在此时拔线；包内 `rawprogram5` 的 `modemst1/2`/`fsg`/`fsc` 若被写（官方 `filename` 为空则跳过），设备独有分区（`persist`/`proinfo`/`keystore`/`ssd`/`frp`）在官方 xml 里是 `filename=""` ⇒ **不会被写**（`backup/HA2EXB0E-16+512/unique/` 另存）。

刷完判读（30 s）：

```sh
timeout -k 5 5 fastboot devices     # 进系统的话这里会消失
timeout -k 5 5 adb devices          # 出现设备 SN ⇒ 已进 Android
fastboot -s HA2EXB0E getvar current-slot; fastboot -s HA2EXB0E getvar unlocked
```
屏上判读：Lenovo logo → Android 开机动画 = 成功；logo 后落回 fastboot = 失败（**此时硬件判读才算有底气**）。
失败的话请再跑一次只读取证（§6 的命令），我比对「GPT 是否真回原厂」再定案。

## 5. 回退（GPT 别慌，件齐全）

- 现 GPT 六 LUN 主表 dump：`artifacts/bl-stuck-20261118/edl-read/gpt{0..5}-primary.bin`（含 sha256）；LUN0/LUN4 的备表 11-16 已 dump（`artifacts/bl-stuck-20261116/lun0-gpt.bin`、`lun4-gpt-backup-final.bin`）。
- Linux 侧回退三件套：`bootslot-b/boot_b.img`（`06c081ca…`）+ `backup/vbmeta_b-20261110.img`（`e974ebab…`）+ `out/dtbo-dummy.img`。
- `linux17` 数据：T1/T3 只动条目不动数据（stock `userdata` 覆盖范围包含 LBA 73277435 起，但官方 `userdata_*.img` 只写到 ~6053xxx）⇒ 需要 Linux 时用 `scripts/gpt-surgery-tb322fc.py` 按原 LBA 重建 `linux17`/`eldenesp` 条目即可，**不需要重装 rootfs**。
- 若 T3 后要恢复 Android 侧空间：`elden-*` 分区名需重新加回；`backup/HA2EXB0E-16+512/dev-dump-20261117/`（39 件）+ `backup/stock-259/` 都在库。

## 6. 取证复现（只读，任何人可重跑）

```sh
L=~/下载/tb322fc/xbl_s_devprg_ns.melf
timeout -k 5 20 fastboot -s HA2EXB0E oem edl ; sleep 6
cd reports/artifacts/bl-stuck-20261118/edl-read
timeout -k 10 300 ~/edl/qdl/build/qdl -s ufs "$L" \
  read 0/0+6 gpt0-primary.bin read 1/0+6 gpt1-primary.bin read 2/0+6 gpt2-primary.bin \
  read 3/0+6 gpt3-primary.bin read 4/0+6 gpt4-primary.bin read 5/0+6 gpt5-primary.bin \
  read 0/89992+256 misc.bin read 4/409338+1 devinfo.bin \
  read 4/409595+2048 logfs.bin read 4/425202+32 xbl_sc_logs.bin
timeout -k 10 90 ~/edl/qdl/build/qdl -s ufs "$L" reset
```

解析（GPT 头/条目 CRC、分区表、与官方件逐字节对账、属性字节位图）：`scripts/gpt-audit-tb322fc.py`（已跑通，本文件 §2 的数字全部由它产出）：

```sh
python3 scripts/gpt-audit-tb322fc.py --dev reports/artifacts/bl-stuck-20261118/edl-read --stock ~/文档/TB322FC_15.10.259
```

---

## 7. 结果：**已修复**（2026-11-17 20:0x，设备已进 ZUXOS；硬件判读彻底作废）

### 7.1 时间线（全部有 USB/adb 证据）

| 时刻 | 动作 | 结果 |
|---|---|---|
| 19:2x | **T1**：只写 GPT（LUN0+LUN4 主备表 + patch）—— **4 分区 / 88 KiB / 26 patch**，零镜像改动 | 现象从「直接落 fastboot」变成「解锁警告 → 联想 logo → 黑屏」；`slot-successful:a` 由 `no` 变 **`yes`**、`slot-unbootable:b` 变 **`yes`**（= 原厂出厂态）；`logfs`/`misc` sha 未变 ⇒ ABL 仍未交接 |
| 19:36–19:37 | **T2 step1**：`rawprogram4 + patch4`（LUN4，37 分区 / 793.6 MiB / 13 patch） | 成功。boot_a/boot_b/dtbo/vbmeta = 原厂 Android 件 |
| 19:37 | T2 step2 首次尝试（未加 `-R`） | **失败**：上一发 qdl 结束即发 reset，设备已离开 EDL ⇒ `SAHARA: failed to read request`。教训：多次 qdl 调用必须 `-R` 且显式 reset |
| 19:44–19:50 | **T2 step2 重跑**（`-R -f`）：`rawprogram_save_persist_unsparse0 + patch0` ⇒ **21 分区 / 14.9 GiB / 13 patch**，6 min 6 s @41.5 MiB/s | 成功。`userdata_*.img` 11 件在包内已缺失（`-f` 跳过 ⇒ userdata 内容仍是旧的 Linux `elden-data`） |
| 19:52 | reset → 60 s 后枚举 `18d1:d001`，`fastboot devices` = `HA2EXB0E recovery` | **Android 内核起来了**（此前所有镜像都 `Device Error`） |
| 19:57 | `adb reboot` | 仍回 recovery（= userdata/metadata 不兼容） |
| 19:59 | `adb reboot fastboot` → `fastboot -w`（erase userdata + metadata）→ `fastboot reboot` | — |
| 20:02 | 屏幕出现 **ZUXOS 开机 logo**；`adb devices` = `HA2EXB0E device` | 系统起 |
| 20:04 | `getprop`：`TB322FC_CN_OPEN_USER_Q00041.1_W_ZUXOS_1.5.10.259_ST_260611`、`Android 16`（`BQ2A.250610.001`）、slot `_a`、`verifiedbootstate=orange`、**`sys.boot_completed=1`** | **完全启动** |

证据：`reports/artifacts/bl-stuck-20261118/{recovered-getprop.txt, recovered-screen.png}`（3040×1904 截图）、`flash/T1-*`、`flash/T2*`。

### 7.2 真因（按判据，不按推测）

**真因 = 非原厂 GPT（LUN0 条目/命名 + LUN4 槽属性字节）导致 ABL 在 boot-image load/authenticate 阶段失败。**

判据（单变量）：T1 **只写了 88 KiB 的 GPT**（未动任何 boot/vbmeta/dtbo/固件，39/39 件与 18:53 完全相同），现象即从「`continue`/`boot` 全部 `Device Error`」变成「ABL 真的去启动、走到 logo」；同一时刻 `slot-successful:a` / `slot-unbootable:b` 回到出厂态。⇒ 失败变量在**分区表状态**，不在镜像、不在内存。

由此可解释此前所有「互相矛盾」的观察：
- 「原厂 `boot.img` 与 1 MiB 合法件都 `Device Error`」⇒ ABL 根本没进到校验镜像内容那一步（GPT 解析/槽判定先失败）。
- 「错误串自变」⇒ 加载路径在不同槽属性下走不同分支（`#482` 同类非确定性）。
- 「`poke` 不返回」⇒ 与故障无关（`#486` 门控）。

### 7.3 对既有结论的裁决（时间序，本条压过 11-17 18:05 与更早）

1. ~~「运行期大块内存访问不稳 = 唯一存活解释（硬件类）」~~ **删除**；`DEVICE/service-repair-note-20261117.md` **作废**（不需要送修）。
2. 「GPT 已排除」的旧口径错在**只验可解析、没验逐字节对账**——真因恰在 GPT。
3. 教训：`qdl` 多次调用必须 `-R`（否则第二发打在已被 reset 的设备上）；`userdata_*.img` 缺失要靠 `fastboot -w` 补格式化。
4. 设备现态 = **原厂 Android 16 / ZUXOS 1.5.10.259 已完全启动**，`slot _a`、`verifiedbootstate=orange`（解锁态）、`linux17`/`eldenesp` 条目已随原厂 GPT 消失（数据物理保留）。回 Linux = 重新加回两个 GPT 条目 + 刷 `bootslot-b/boot_b.img` 那条链（件齐全）。
