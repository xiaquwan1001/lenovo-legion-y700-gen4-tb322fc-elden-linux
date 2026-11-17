# 卡 bootloader（卡 BL / 落 fastboot）历史案例与排查手册

- 范围：本机 U1/U2（TB322FC / SM8750P / `elden`），2026-09-29 → 2026-11-17 全部「起不来且停在 bootloader / 落 fastboot」的现场。
- 口径：**只收录「设备确实停在 BL 或落回 fastboot」的案例**；「卡 logo 但最终进系统」「卡 GRUB→initrd 交接」（`PITFALLS #659`）等只作旁证引用。
- 证据指针一律为相对仓库根的路径 + 行号/章节。取证件目录：`reports/artifacts/bl-stuck-20261116/`、`reports/artifacts/bl-stuck-20261117/`（各含 `SHA256SUMS.txt`）。
- 本文只做历史归档与决策树，**不改变任何既有结论**；正在进行的案例（BL-09/BL-10）以 `reports/bl-stuck-20261117-device-window.md` 为准。

---

## 1. 一页结论（先数字）

| 项 | 数字 | 说明 |
|---|---|---|
| **历史案例总数 N** | **10** | BL-01…BL-10，见 §2 |
| **「错误串/现象 → 根因」能一一对应、且已复现验证的 M** | **7** | BL-01/02/03/04/06/07/08 |
| **仍未定因的 K** | **2** | BL-09（2026-11-16）、BL-10（2026-11-17），同一台 U2、同一现象族的连续两天 |
| **判据纠正（非新故障）** | **1** | BL-05（把「挂死」读成「ABL 自己换槽」） |

七条可对照的因果链（每条都在同一台机上复现或被双向验证过）：

1. **retry 计数耗尽 → 槽被标 `unbootable` → 停 fastboot**（BL-01）。自建 Linux 不调用 `markBootSuccessful`，GPT 属性 `boot_*` byte6 的 bit6 永不置位 ⇒ ABL 每次启动减 1 ⇒ 约 7 次后归零。
2. **`fastboot boot` 前没把 `dtbo_<slot>` 清成「假 dtbo」→ ABL 把原厂 Android overlay 套到我们的 DTB 上 → 卡 logo 后回 fastboot**（BL-02 / BL-07，同一个坑在 `_b`（10-03）与 `_a`（11-10）各踩一次）。
3. **异类载荷 `fastboot boot` 失败 → 当前槽被标 `slot-unbootable=yes` → 落 fastboot / 回落另一槽**（BL-03）。
4. **引导固件代次与 A/B 槽脱钩（槽↔boot LUN 不配对）→ 只进 fastboot + `continue` 报 `Device Error`**（BL-04）。
5. **我们自己 UEFI 的 noauth 路径把整个 32 MiB dtbo 分区当镜像，超过 `DTBO_MAX_SIZE_ALLOWED`=24 MiB → `Load Error`**（BL-06）。
6. **主机侧孤儿 `fastboot` 进程抢 USB 命令通道 → 命令发出后设备黑屏崩溃**（BL-08，「能枚举」≠「通道可用」）。
7. **A/B 属性只能在正确的 LUN/会话下改；改完要读回双表**（贯穿 BL-01/03/04，见 §3 第 1 步）。

两个未定因案例的共同形状：**镜像/分区/固件/GPT/槽属性/AVB/解锁态全部逐字节清白，失败点固定在 ABL 的 load/authenticate 步骤；新增偏硬件信号 = 大块内存访问不稳（512 MiB EDL 读失联、`edl.py poke 32 MiB→0x90000000` 5 min 不返回）**（`reports/bl-stuck-20261116.md` §5、`reports/bl-stuck-20261117-device-window.md` §0）。

---

## 2. 逐例表

> 「解决动作」列只写**当轮真正生效的那一步**；无效的尝试见各案例的「共同误判」注记。

| # | 日期 | 现象 / 错误串 | 根因 | 解决动作 | 证据指针 |
|---|---|---|---|---|---|
| **BL-01** | 2026-09-29 夜（现象）→ 2026-10-11（定因+修） | `current-slot=b`，`fastboot reboot` 进不去系统；`--set-active` 后能起（旁证：每次 `set_active` 都能起） | **A/B `tries_remaining` 被耗尽 → 槽标 `UNBOOTABLE`**。真因：Alpine 自带 `/etc/init.d/qbootctl` **不在任何 runlevel** ⇒ 每次启动都没把槽标记成功 ⇒ Linux 镜像侧 GPT byte6 的 `BOOT_SUCCESSFUL`(bit6) 永不置位，ABL 每启动减 1（默认 7） | ① 临时：`fastboot --set-active=b && fastboot reboot`（重置槽元数据）；② 根治：`scripts/fix-ab-mark-successful.sh`（显式 `start()` + `rc-update add qbootctl default`），新 rootfs 之后必跑一次 | `archive/topics/复盘-2026-09-29-夜.md` §四.2；`PITFALLS/sessions/23-…测试协议陷阱.md:43`（#181）；`HISTORY/days/2026-10-11.md:13`；byte6 位图权威 = `.pi/skills/qualcomm-edl-flashing/SKILL.md` §Pitfalls「A/B attribute byte[6] full bit map」 |
| **BL-02** | 2026-10-03 | `fastboot boot` 后屏幕停在联想 logo，约 10 s 后落回 fastboot（不是砖） | `dtbo_b` 仍是原厂合法 DTBO（76 个 Android overlay），ABL 在 `BootLinux` 后 `Apply Overlay` 把它合进我们的内嵌 DTB ⇒ 模型/面板不匹配 | 先刷「假 dtbo」：`fastboot flash dtbo_b out/dtbo-dummy.img`（4 KiB 全零，magic `d7b7ab1e` 不匹配 ⇒ ABL 跳过 overlay） | `RUNBOOK-BRINGUP/README.md:269-270`；`archive/topics/复盘.md:21`、`:136`；`archive/topics/复盘-2026-10-03-持久化与睡眠.md:41`；`PITFALLS/sessions/01-引导fastboot重启交接.md:3-4` |
| **BL-03** | 2026-10-24 | `fastboot boot` 回 `Booting OKAY [10.1s]` 但设备**仍留 BL**（v3 header）；随后载荷崩 ⇒ 设备起成 stock Android，`slot-unbootable:b: yes`、`slot-retry-count:b: 6`，日用 Linux（`boot_b`）起不来 | ① 本机 ABL 对 boot image **v3 header 是子集支持**（静默忽略，不跳）；② `fastboot boot` 失败由 ABL 把当前槽标 `unbootable` 并回落另一槽 | ① 实验镜像一律 repack 成 **v0**（`--base 0x10000000 --kernel_offset 0x8000`）；② `fastboot set_active b` 清 `unbootable`（只写槽元数据，不碰分区镜像） | `HISTORY/days/2026-10-24.md:58`；`PITFALLS/sessions/76-UEFI载荷fastboot三坑…md:11-30`（#387）；`PITFALLS/README.md:110`；v0 `--base` 硬要求见 `PITFALLS/README.md:143`（#418） |
| **BL-04** | 2026-11-01 16:39 → 21:4x | 全程只能进 fastboot；`fastboot continue` 对 a/b 两槽都回 **`Failed to load image from partition: Device Error`**；`--set-active a|b` + 完整重启 8 s 内落回 | **引导固件代次与活动槽脱钩**：本机双代引导固件并存（`*_a`+LUN1 = 259 原厂 UEFI `6.0.260611`，`*_b`+LUN2 = 上一版 `6.0.260514`），ABL 按活动槽选 boot LUN；卡死那次是 `slot=b` 却跑在 `UFS Boot LUN: 1` | 一条命令：`fastboot --set-active=a`（进 Android）/ `--set-active=b`（回 Linux），**双向可复现** | 事故全账 `reports/uefi-slotboot-stuck-fastboot-20261101.md` §0/§1/§2/§8.1；定案 `PITFALLS/sessions/148-…md:12-27`（#484）+ 判据表 `:52-64` + 固件台账 `:83-96`；`PITFALLS/README.md:193` |
| **BL-05** | 2026-11-02 | （纠正）UEFI「A3」那一发被读成「挂死/卡 BL」 | 实际是 **ABL 自己换槽并清了 `unbootable`，落到 Android 槽**——不是挂死 | 判据改为「看 logfs 有没有 `Booting from slot` + 看 `getvar current-slot` 变了没」，别只看屏 | `HISTORY/days/2026-11-02.md:9`；同类「ABL 自兜」机理见 `PITFALLS/README.md:269`（#572） |
| **BL-06** | 2026-11-04 | `fastboot continue` 与 `fastboot boot` **都报 `Load Error`**（当时用的是我们自己的 UEFI 件） | 我们 UEFI 的 **noauth 路径把整个 `dtbo_<slot>` 分区当 dtbo 镜像**：本机 `dtbo_b` 是 32 MiB 且内容全 0 ⇒ `EFI_OUT_OF_RESOURCES` 被 `LoadImageNoAuth()` 改写成 `EFI_LOAD_ERROR` | 补丁 `patches/uefi/20261104R16-dtboclamp`（+`R17-bootmarkers`）：先读一页表头，magic 不合法 ⇒ `EFI_NO_MEDIA`（当无 overlay）；合法 ⇒ 按 `total_size` 装载、缓冲区按 4 KiB 取整 | `PITFALLS/sessions/162-UEFI进DXE之后的取证纪律.md:49-56`（#508）；`PITFALLS/README.md:215` |
| **BL-07** | 2026-11-09 → 11-10 | 「同一份镜像 `_a` 起不来、`_b` 起得来」；`_a` 卡联想 logo 后**回 fastboot 或回落 `_b`**（p60–p69 每发如此） | **`dtbo_a` 仍是原厂合法 Android DTBO**（magic `D7B7AB1E`、`total_size` 23 348 092 B）：`_a` 上 `Apply Overlay` **真的合并成功**（logfs `Apply Overlay total time: 175 ms`）⇒ 卡 logo；`_b` 因 dtbo 全 0 合并不上而被容忍 | 把 `dtbo_a` 也清成 32 MiB 全 0：`scripts/uefi-a-slot-prepare.sh`（备份原厂件 → 写全 0 → 读回校验）。同件随后 34 s（RAM）/27 s（flashed）起 | `reports/uefi-dtbo-a-rootcause-20261110.md` §0 判据表/§1 机理/§3 配方；`PITFALLS/README.md:297-299`（#600/#601/#602）；`HISTORY/days/2026-11-10.md:23` |
| **BL-08** | 2026-11-14 | 设备**能枚举**（`fastboot devices` 有），但我们的命令（**甚至只发 `getvar`**）发出后设备黑屏崩溃并回落 | 多项目共用一台 USB 调试主机：隔壁项目的**孤儿 `fastboot` 进程**（本例 13 个 `fastboot oem dump-emmc ptable`、`PPID=systemd --user`、存活 10 h）周期性重开同一设备抢通道 | `pgrep -af "[f]astboot"` 数孤儿 → 杀掉 → 之后 `getvar product` 5 s 内返回即恢复；脚本里判活一律带 `-s <SN>` | `PITFALLS/sessions/294-多项目共用USB主机-fastboot通道被抢.md`（#658）；`PITFALLS/README.md:338` |
| **BL-09** | 2026-11-16 夜 → 11-17 上午 | U2（`HA2EXB0E`）停 fastboot（`18d1:d00d`）；`continue`/`boot <已知好件>` 均 `Device Error`；`--set-active a|b` + 完整重启**两个方向都 8 s 落回**；11-17 上午 `continue` 变成 **`Load Error`**，`boot` 回 `Failed to load/authenticate boot image: Load Error`，**已知好件 3/3 同败** | **未定因**。已逐条排除：镜像内容（`qdl` 设备端 sha `06c081ca…`）、引导固件（xbl/abl/uefi 全在台账值）、GPT、槽属性、AVB/vbmeta（orange 常态）、ESP 默认 EFI、命令通道抢占。剩两个候选：**ABL/UEFI 加载通路本身** 或 **DDR/内存侧硬件退化**（新信号：EDL 一次读 512 MiB 两次失联、`poke 32 MiB` 不返回） | 本轮**未解决**；恢复动作按代价升序见右列 §6；已按全局规则 12 上交 hw-stability | `reports/bl-stuck-20261116.md` §1（排除表）/§3（已否证假设）/§5（剩余候选）/§8.3（qdl 第二把尺子）/§9（11-17 复测表）；件 `reports/artifacts/bl-stuck-20261116/SHA256SUMS.txt`；`DEVICE/README.md:59-80`；`~/hw-stability/evidence/inbox/20261117-y700-elden-bl-load-error/MANIFEST.md` |
| **BL-10** | 2026-11-17 16:02–16:50 | 同一台机第二次窗口：**11 次启动尝试全败**（`continue`×4 / `boot`×5 / EDL `reset` 冷起×3）；失败串**在同一设备内自变**：`Failed to load image from partition: Device Error` ↔ `Failed to load/authenticate boot image: Load Error` ↔ `… Device Error` | **未定因**（同 BL-09）。本轮新增 10 条独立排除：写路径、GPT（5 LUN）、槽属性（复位后冷起 retry 7→6 证明 ABL 真尝试）、lock/verity、vbmeta_b 未变 + `Flags:3`、dtbo_b 与 vbmeta 描述符一致、ABL 本体 stock、存储读路径（12 分区 + 96 MiB 设备端 sha）、**镜像大小**（2.4 MB 件同样 `Device Error`）、槽相关 dtbo 处理 | **未解决，已停手保留现场**；下一步需人：① 长按 15–20 s 全断电→等 10 s→只按电源（不插 USB）；② 用户拍板是否 EDL 只刷 stock 259 引导链；③ 或改「Android 优先」先恢复可用系统 | `reports/bl-stuck-20261117-device-window.md` §0/§2（10 条排除）/§3（判据边界）/§4（与已知 PITFALLS 关系）/§5（恢复动作）/§6（写操作清单）；`reports/artifacts/bl-stuck-20261117/getvar-20261117-1647.txt`；`DEVICE/README.md:66-80` |

### 表注（易误判点，逐条都有代价）

- **BL-04 之前：#482** 同一份未改镜像 `423188a0…` 同 header 连发出现 HANDOFF / `Booting OKAY [10.145s]` / `Invalid Parameter` **三种结果** ⇒ 别用 header 差分追「接受规则」，判据要写成统计式（`PITFALLS/sessions/146-…md:5-30`、`PITFALLS/README.md:191`）。
- **BL-04 之前：#483** 断言「断电/刷回/切槽全无效」，8 小时后被一条 `--set-active` 推翻 ⇒ 「不可恢复」结论必须留状态维度余地（`PITFALLS/sessions/147-…md`、`PITFALLS/sessions/148-…md:109-113`）。
- **#525** UEFI 载荷失败后 **ABL 自己会写槽位 retry**（实测 `boot_b` 7→6）⇒ 「零写盘」只对 agent 动作成立，每轮崩后要核 `slot info` 并补余量（`PITFALLS/sessions/173-…md`、`PITFALLS/README.md:232`）。
- **`reboot2` 不带参数会被 ABL 当成「进 fastboot」**，曾被误判成「启动次数耗尽」；**RAM 直启既不扣 tries 也不置 successful**（`PITFALLS/sessions/19-…md:151-152`）。
- **进 fastboot 的通道本身也可能骗人**：`reboot2 bootloader` 会让设备 USB 全不枚举（`#368`，`PITFALLS/README.md:94`）；暖复位后立刻 `fastboot boot` 不可靠（`#650`，`PITFALLS/README.md:330`）⇒ 上机默认走 `ssh elden-root 'sync; reboot bootloader'`。
- **`logfs` 只能作正控**：对最近启动常常根本不写（`#602`）、失败那一发不落盘（`#594`）、恢复动作会覆盖它（`#594`）、八成为工厂模板（`#485`）。判「有没有尝试启动」用 retry 递减 + `getvar`，不要只靠 logfs。
- **`Image size : 4096 Bytes` 不是通用判据**：TB322FC 上它出现在**能正常启动**的段里；TB321FU 才是「ABL 解析失败」（`PITFALLS/sessions/147-…md`）。

---

## 3. 排查决策树（起点：`fastboot devices` 有设备）

> 全程只读优先。所有 fastboot 命令**必须带 `-s HA2EXB0E`**（裸命令会把命令发给同总线的另一台机，`#371`/`PITFALLS/README.md:97`）。
> 9008 侧只读（`printgpt` / `r` / `qdl sha256`）不写分区；`qdl` 为默认工具，`edl.py` 只留 loader/Sahara 与小写 GPT（`#669`）。
> loader：`~/下载/tb322fc/xbl_s_devprg_ns.melf`；工具：`~/edl/qdl/build/qdl`（tag v2.9）、`~/edl/bkerler-edl/edl.py`。

### 第 0 步（前置，30 秒）：先证明「通道可用」，否则后面全是假判据

| 动作 | 判据 | 命中后 |
|---|---|---|
| `pgrep -af "[f]astboot"` ；`timeout -k 5 5 fastboot -s HA2EXB0E getvar product` | 返回 product 且 `< 5 s` ⇒ 通道可用；`< waiting for HA2EXB0E>` 挂住 ⇒ **通道不可用**（孤儿进程抢占 `#658`） | 杀孤儿后重测；仍不可用 ⇒ 物理拔插/换线/换到 USB2 口，再不行按第 7 步走 9008 |
| `lsusb \| grep -E '18d1:d00d\|05c6:9008'` | `18d1:d00d` = fastboot；`05c6:9008` = **已经在 EDL**（屏上写着 fastboot 也可能 USB 侧是 9008） | 是 9008 就跳过 fastboot，直接进第 1 步的 EDL 分支 |

### 第 1 步：槽属性 / slot 元数据（最常见、最便宜）

| 命令 | 判据 | 命中后动作 |
|---|---|---|
| `fastboot -s HA2EXB0E getvar current-slot` `… getvar slot-unbootable:a` `… getvar slot-unbootable:b` `… getvar slot-retry-count:a` `… getvar slot-retry-count:b` `… getvar slot-successful:a` `… getvar slot-successful:b` | 任一槽 `unbootable: yes`，或 `retry-count: 0` ⇒ **BL-01 型**；`successful: no` 长期不变 ⇒ 自建系统没 mark（`#181`） | `fastboot -s HA2EXB0E --set-active=<另一槽>` 后 `reboot`；能进 Linux 就立刻 `scripts/slot-attr.py mark-successful <slot>`（**写 primary+backup 双表 + 重算 CRC**），并跑 `scripts/fix-ab-mark-successful.sh` 防复发 |
| （在 Linux 里）`python3 scripts/slot-attr.py show \| grep -E 'boot_a\|boot_b'` | `succ=0` 或 `retry` 在递减 ⇒ 同上；两表 `byte6` 应等于 `0x7f`（active+successful+retry7） | `scripts/slot-attr.py set b --retry 7` / `mark-successful b`；写完**独立解析两表条目复核**，不要只看脚本自报（`#487`，`PITFALLS/README.md:196`） |
| 判「ABL 到底尝试了没」 | 冷起一次后 `retry-count` **掉了 1** ⇒ ABL 真的在尝试并失败（不是 BCB 强制进 fastboot）；`--set-active` 会把 retry **重置为 7**，所以「retry=7」**不能**证明没尝试过 | 掉了 ⇒ 属性不是死因，进第 2 步；没掉 ⇒ 回第 0 步查通道/BCB（`misc` 的 `bootonce` 类命令） |

### 第 2 步：GPT（分区表本身）

| 命令 | 判据 | 命中后动作 |
|---|---|---|
| `fastboot -s HA2EXB0E getvar partition-size:boot_b`（期望 `0x6000000` = 96 MiB）、`…:dtbo_b`（期望 `0x2000000` = 32 MiB） | 尺寸不符 ⇒ GPT 与固件代次错配 | 见下 |
| `fastboot -s HA2EXB0E oem edl` → `timeout -k 5 300 ~/edl/qdl/build/qdl -R -s ufs <melf> printgpt` （或 `edl.py --loader=<melf> printgpt`） | 5 个 LUN 全解析、`EFI PART` 在、主备表 header+entries CRC 都 OK、`boot_a/boot_b/vbmeta_a/b/dtbo_a/b` 全在 ⇒ 排除 | 结构坏 ⇒ 从 `backup/` 双表 dump 写回（写后读回比 sha）；**GPT 代次错配**（旧 GPT 配新 boot 链）会表现为 `Image size : 4096 Bytes` + `Start EBS` 死循环 ⇒ 必须整包刷 GPT **且把每个分区按新布局重写**（`.pi/skills/qualcomm-edl-flashing/SKILL.md` §Pitfalls 第 3 条） |
| **LUN 归属必须先确认**：`printgpt` 里看该分区属哪张 LUN 表 | 猜 LUN ⇒ `edl.py` **不报错**但给你别处的数据（本轮踩过：`eldenesp` 属 LUN0 而按 `--lun=4` 读） | 对不上就停下（`#669`） |

### 第 3 步：镜像内容（设备端算摘要，不经 USB 传数据）

| 命令 | 判据 | 命中后动作 |
|---|---|---|
| `timeout -k 5 300 ~/edl/qdl/build/qdl -R -s ufs <melf> sha256 4/321824+24576` | 本机 `boot_b` 的台账值 = **`06c081ca4af94915…`**（= `bootslot-b/boot_b.img`）；不等于 ⇒ 内容变了 | 不等于 ⇒ 用 `fastboot -s HA2EXB0E flash boot_b bootslot-b/boot_b.img` 写回，写完再算一次 sha（写路径也要证明：`#669` 的 `cmd_program()` 拒绝仍回 True） |
| 大块读一律分块（≤32 MiB/发）：`qdl -u` 或 `edl.py rs <LBA> 8192 --lun=0` | 单发 512 MiB 会失联（`edl.py` 无分块开关） | 失联本身是**信号**（记一笔，进第 8 步），不是工具用法问题就完事 |

### 第 4 步：vbmeta / AVB / 解锁态

| 命令 | 判据 | 命中后动作 |
|---|---|---|
| `fastboot -s HA2EXB0E getvar unlocked` `… oem device-info` | `unlocked: yes` / `Device unlocked: true` / `Device critical unlocked: true` / `Verity mode: false` ⇒ 解锁态正常（orange） | 未解锁 ⇒ 画像是 AVB 拒绝，按 `RUNBOOK-BRINGUP/README.md:157-188` 走解锁/EDL 路线 |
| `python3 tools/avbtool.py info_image --image <vbmeta_b 读回件>` | `Flags: 3`（`VERIFICATION_DISABLED\|HASHTREE_DISABLED`）+ chain `boot` → 我方 key；`vbmeta_a` 全 0（a 槽 UEFI 期既定态） | `Flags: 0`（校验开）⇒ 换槽/换件前先过这道墙；但**解锁态下哈希失败只告警不拒绝**（BL-04 已证：能正常启动的段里也有 `Public key used to sign data rejected`）⇒ **别把这条 ERROR 当死因** |
| 一致性 | `dtbo_b` 的 AVB footer `Original image size` 必须等于 vbmeta 里 dtbo 描述符的长度（本机 4096 B） | 不一致 ⇒ 先重写 dtbo + vbmeta 这一对 |

### 第 5 步：dtbo 形状（32 MiB 上限 / overlay 是否合法）

| 命令 | 判据 | 命中后动作 |
|---|---|---|
| `fastboot -s HA2EXB0E getvar partition-size:dtbo_a` `…:dtbo_b` | 两槽都应 **32 MiB**（`0x2000000`） | 不符 ⇒ 回第 2 步 |
| 读首块判 magic：`timeout -k 5 120 edl.py --loader=<melf> rs <dtbo_b LBA> 1 --lun=4 /tmp/dtbo.bin` 后 `xxd -l 32` | 首 4 字节 `d7 b7 ab 1e`（`D7B7AB1E`）= **合法 Android DTBO ⇒ ABL 会 `Apply Overlay`，卡 logo 型（BL-02/BL-07）**；全 0 = 「假 dtbo」⇒ ABL 容忍并继续（预期态） | 合法 ⇒ 清成 32 MiB 全 0（`truncate -s 33554432` + `fastboot flash dtbo_<slot>`，或 `scripts/uefi-a-slot-prepare.sh`）；**注意：清 `dtbo_a` 之后 Android 不再能从 a 槽启动**，要回 Android 先跑脚本打印的回滚 |
| （走我们自己的 UEFI 时）分区大小 vs `DTBO_MAX_SIZE_ALLOWED` | 32 MiB **大于**我们 UEFI 的 24 MiB 上限 ⇒ noauth 路径 `Load Error`（BL-06） | 用已打 `dtboclamp` 补丁的 UEFI 件（`patches/uefi/20261104R16-dtboclamp`）；或换回 ABL 直启 Linux |

### 第 6 步：固件会话污染（同一 9008 会话连打的副作用）

| 检查 | 判据 | 命中后动作 |
|---|---|---|
| 本会话已发过几发 EB 之后（stage ≥ 40）的件 | 先打 `stop40` 能回话，再打 `stop41` 之后**连 `stop40` 也退化成 `Load Error`**；同一 sha 的件**换会话立刻正常** ⇒ 会话污染（`#523` B 段） | 一个会话只打一发；要连打就重载 preamble 或断电（`PITFALLS/sessions/171-…md:19-26`） |
| `fastboot boot` 失败后的「脏态」 | 连续报 `Load Error` ⇒ `fastboot -s HA2EXB0E reboot bootloader` 清；仍不行 ⇒ 走 EDL `reset` / 物理断电 | 见 `PITFALLS/sessions/01-…md:27-28` |
| `fastboot getvar` 挂住 | 设备**已离开 fastboot** 时会阻塞到 timeout（`#583`）⇒ 采样器必须先 `fastboot devices` 再 `getvar` | 改脚本，别当成设备死 |

### 第 7 步：存储读路径（证明 flash + Firehose 通路都是好的）

| 命令 | 判据 | 命中后动作 |
|---|---|---|
| 逐个只读 12 个分区并本地比 sha：`boot_b` / `vbmeta_a` / `vbmeta_b` / `dtbo_b` / `misc` / `logfs` / `xbl_sc_logs` / `abl_a` / `abl_b` / `xbl_config_a` / `xbl_config_b`（**分块、每次 ≤32 MiB**） | 每个 sha **稳定 + 大小正确** ⇒ 读路径好、96 MiB DRAM 缓冲在 Firehose 下正常 | 某个分区**读不稳**（同命令两次不同 sha）⇒ 直接进第 8 步（硬件侧），不要再在软件层绕 |
| 正控（本轮**没做**的那一步）：读回 → **原样写回** → 再读回，三轮 sha 稳定 | 不稳 = 硬件；稳 = 回软件层继续（`reports/bl-stuck-20261116.md` §6.3） | 写回前先备份；`qdl` 写完必须 `sha256` 复核 |

### 第 8 步：内存 / DDR

| 检查 | 判据 | 命中后动作 |
|---|---|---|
| 大块传输稳定性 | EDL 单发 512 MiB 读**两次失联**、分块 16×32 MiB 才成功；ABL 每段都打 `Failed to add memory space :0x8088F000 0x1000` 与 `ERROR:NACK: SA:0x1C`（i2c） | 记一笔（硬件侧嫌疑），继续只读取证 |
| `edl.py poke 0x90000000 <32 MiB>` 写 DDR 再读回 | **5 min 无输出**（`edl.py` 侧无 `program` 完成行）⇒ DDR 侧可疑 | 已实测=一轮一次即止，别重试 |
| EDL 是否支持 `peek`（直读 DDR） | **本机 loader 不支持**：`Supported Functions` 无 `peek`，`rawxml` 手发也空回包 ⇒ **「EDL 直读 DDR」这条路不存在**（`#486`），不要为它设计实验 | 改用「冷断电 + 屏上判读 + 换机对照」三条间接判据 |
| 冷断电 | 长按电源 15–20 s 至全黑 → 等 10 s → **只按电源**（不插 USB） | 进系统 ⇒ 问题自愈（上电残留态）；仍落 fastboot ⇒ 排除 DDR 训练/上电残留，进「恢复动作」 |
| 收口 | 若上面全部清白且仍失败 ⇒ 按全局规则 12 上交 `~/hw-stability/evidence/inbox/<日期>-y700-elden-<现象>/` + `MANIFEST.md`，**项目内不再深挖** | 恢复动作按 §2 BL-09/BL-10 的代价升序执行（全断电 → 同值重刷 xbl/abl/boot_b → stock 259 引导链 → 全量 stock） |

---

## 4. 与 2026-11-17 本次现象（BL-10）的异同对照

### 4.1 本次已排除项（每条都有独立判据，全部只读）

| 候选 | 判据 | 出处 |
|---|---|---|
| boot 镜像内容坏 | `qdl sha256 4/321824+24576` = `06c081ca…` = `bootslot-b/boot_b.img` | `reports/bl-stuck-20261117-device-window.md` §2#1 |
| 写路径坏 / 上次写没落地 | `flash boot_b` 后再算 sha 仍 `06c081ca…`（= 等价无效写） | 同上 §2#2 |
| GPT 坏 | `printgpt` 5 LUN 全解析，分区长度正常 | 同上 §2#3 |
| 槽属性 | `unbootable=no/retry=7`；冷起 retry 7→6（ABL 真尝试） | 同上 §2#4 |
| lock / verity | `unlocked=true`、`critical=true`、`Verity mode: false` | 同上 §2#5 |
| vbmeta 链 / dtbo 不一致 | `vbmeta_b` = 11-16 备份 `e974ebab…`，`Flags:3`；`dtbo_b` 与描述符（4096 B）一致；`vbmeta_a` 全 0（既定态） | 同上 §2#6 |
| ABL 本体被改坏 | 两槽 ABL 均 stock，与 11-16 取证件 `cmp` rc=0 | 同上 §2#7 |
| 存储读路径 | 12 分区 Firehose 读回 sha 稳定 + 96 MiB 设备端 sha256 | 同上 §2#8 |
| 镜像大小/落点 | **2.4 MB** 件同样 `Device Error` | 同上 §2#9 |
| 槽相关 dtbo 处理差异 | `--set-active=a` 后同样失败 | 同上 §2#10 |
| ESP / GRUB 半写 | `BOOTAA64.EFI` sha = arm0 逐字节相同 | `reports/bl-stuck-20261116.md` §3.4 |
| 主机侧命令通道被抢 | `pgrep -af fastboot` = 0 个孤儿 | `reports/bl-stuck-20261116.md` §3.6 |

### 4.2 与历史哪些案例同 / 不同

| 历史案例 | 同 | 不同（关键判据） |
|---|---|---|
| **BL-04**（11-01，`Device Error` 只进 fastboot） | **错误串逐字相同**（`Failed to load image from partition: Device Error`）；形态同（切槽 + 完整重启仍落回） | BL-04 的死因是**槽↔boot LUN 脱钩**（`slot=b` 跑在 `UFS Boot LUN: 1`）。本次两槽引导固件都在台账值上、`--set-active a\|b` 双向都失败 ⇒ BL-04 的招**已试且无效**（§4.3 已列） |
| **BL-06**（11-04，`Load Error`） | 错误串同族（`Load Error`） | BL-06 是**我们自己 UEFI** 的 noauth 路径 + 32 MiB dtbo 超 24 MiB 上限；本次 `continue`（走 stock ABL 直启）也报 `Load Error`，且 2.4 MB 件同样失败 ⇒ 上限/形状假设不成立 |
| **BL-03**（10-24，落 fastboot + `unbootable`） | 落回 fastboot 的形态同；`Sending … OKAY` 说明 USB 下载通路正常这一点也同 | BL-03 的特征是**当前槽被标 `unbootable`**；本次两槽 `unbootable=no`、retry 正常递减 ⇒ 不是槽被标死 |
| **BL-08**（11-14，命令发出即崩） | 「设备停在 BL 但不响应/回话怪」的观感相近 | BL-08 的主机侧有孤儿进程，本次 0 个；且 BL-08 的命令连 `getvar` 都不回，本次 `getvar` 全部正常应答 |
| **BL-09**（11-16，同一台机） | **同一台机、同一现象族**、同一组排除 | BL-09 记录「同一已知好件 3/3 报错**逐字相同**」⇒ 当时判「非随机」；**BL-10 推翻了这条**：同一设备内失败串会自变（`Device Error` ↔ `Load Error`） |
| **#482**（11-01，`fastboot boot` 判定非确定性） | 「同一输入不同回话」这一点同源 | #482 的非确定性在**上层终态**（HANDOFF / `Booting OKAY` / `Invalid Parameter`）；本次连 `continue`（不走 `fastboot boot` 载荷路径）的回话也在变 |
| **#523**（11-06，固件会话污染） | 都表现为「同一份件在不同会话/不同发次行为不同」 | 本次换会话（EDL `reset` ×3、`reboot bootloader` 多次）**无效** ⇒ 不是会话污染 |

### 4.3 历史上用过、本次**还没试**的招（按代价升序）

| # | 动作 | 历史出处 | 本次状态 |
|---|---|---|---|
| 1 | **完全断电**：长按 15–20 s 至全黑 → 等 10 s → 只按电源（不插 USB） | 11-01 用过（那次无效，因为真因是 LUN）；11-16 §6.1 定为第一步 | **未做**（两轮报告都列为「需人·物理」） |
| 2 | **屏上判读**（冷起 10 s 看是「GRUB 5 条菜单」/「Lenovo logo 后转 fastboot」/「只有背光」） | 11-16 §6.2；BL-05 的纠正就来自屏上判读 | **未做**（需人） |
| 3 | **EDL 正控**：`boot_b` 读回 → 原样写回 → 再读回，三轮 sha（再对 `linux17` 前 512 MiB 同做） | 11-16 §6.3 | **未做**（只做了读，没做「写回-再读回」） |
| 4 | **EDL 分块同值重刷** `xbl`/`abl`/`boot_b`（验证写路径 + 分区归属） | 11-16 §9 恢复动作③ | **未做** |
| 5 | **stock 259 引导链重刷**（`~/文档/TB322FC_15.10.259/rawprogram{0..5}.xml`，只碰 `xbl/xbl_config/abl/uefi/boot/dtbo/vbmeta` 与各 LUN GPT，不碰 `elden-*`/`linux17`/`super`） | 11-16 §6.4、11-17 §5.2 | **未做**（需用户拍板） |
| 6 | **「Android 优先」回滚**（stock `boot.img`+`vbmeta` 刷 a/b 槽先拿到能进系统） | 11-17 §5.3 | **未做**（需用户拍板） |
| 7 | **同型第二台机（U1）做对照**（判「是否本单元硬件特有」） | `#549`/`#572` 的「判据必须归属到具体设备」 | 未做；U1 已逆手术，不能直接当对照，只能做「同固件下另件是否也失败」的形态对照 |
| 8 | **`logfs` 以外的 ABL 侧通道**（`oem sbread` 只在**我们自己的** UEFI 里有，stock 上没有） | `PITFALLS/README.md:292`（#595） | 不可用（已定案）；`xbl_sc_logs` 128 KiB 全 0（未启用） |

---

## 5. 历史教训清单（≤10 条）

1. **「能枚举」≠「通道可用」**：任何结论前先 `fastboot -s <SN> getvar product` 5 s 内返回；挂住先数孤儿 `fastboot`（`#658`/`#371`）。
2. **先穷举可读量，再谈不可见量**：槽属性 → GPT → 镜像 sha → vbmeta → dtbo 形状，五步全在 EDL 只读范围内，比反复 `fastboot boot` 试错便宜两个数量级（BL-04 的教训）。
3. **同一台机的 `Device Error` ≠ 同一个根因**：同串命中的根因至少三种（LUN/槽脱钩、槽被标 unbootable、加载层/硬件），必须逐条判据否证，不许按串名归因。
4. **`--set-active` 会重置 retry=7**，所以「retry 满 7」不证明没尝试过；判「ABL 试过没」看冷起后的 **retry 递减**。
5. **写 boot 分区前 30 秒先抓基线**：`logfs` + LUN4 GPT 主备双表 + `misc` + `getvar all`；备份只覆盖「内容」，不覆盖 GPT 属性/`misc`/`devinfo`/rpmb（`#483`）。
6. **失败发之后先拷 `logfs`，再恢复设备**（恢复动作会覆盖它）；但 `logfs` 只能作正控——最近的启动常常根本不写（`#594`/`#602`）。
7. **`dtbo_<slot>` 必须两槽都清成「假 dtbo」**：合法原厂 DTBO 会被 ABL `Apply Overlay` 合进我们的 DTB ⇒ 卡 logo 后回 fastboot（BL-02/BL-07，项目第一天的坑）。
8. **自建/自编系统的槽必须显式 `mark-successful`**，否则 ~7 次重启后槽被标 `unbootable` 永久停 fastboot（`#181`）；新 rootfs 之后必跑 `scripts/fix-ab-mark-successful.sh`。
9. **9008 取证的每条「读回」至少要有两件**：① LUN 归属（`printgpt` 行）② 4096 B 扇区单位 ③ 第二个工具或第二次独立读；摘要优先用 `qdl … sha256`（设备端算，不经 USB），别信退出码（`#669`）。
10. **「不可恢复」要留余地**（`#483` 被一条 `--set-active` 推翻）；但「软件层全部逐字节清白 + 失败点固定在 ABL load/authenticate + 大块内存访问不稳」时，就该按规则 12 交 hw-stability，**不在项目里深挖**（BL-09/BL-10）。
