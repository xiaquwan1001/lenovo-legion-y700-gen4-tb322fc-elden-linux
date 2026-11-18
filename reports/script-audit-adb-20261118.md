# adb / fastboot 板块静态审查（R3）

- 日期：2026-11-18
- 性质：**只读静态审查**。全程**未执行任何 adb / fastboot / ssh / scp / qdl / edl.py / 9008 命令**
  （设备可能停在 fastboot 且带 UNBOOTABLE 标志）；未改 `scripts/` 与仓内任何既有文件。
- 范围（主件）：`slot-switch.sh`(adb 段)、`linux-state-audit.sh`、`lib-wait.sh`、`c0-android-evidence.sh`、
  `bl-unlock.sh`、`bl-preunlock-evidence.sh`、`q26-recheck.sh`、`t2-stock-lun45.sh`、
  `android-img-inventory.py`、`android-lpdump.py`、`android-super-scan.py`、`dev-super-relabel.sh`、
  `waydroid-*.sh` 里用 adb 的部分。对照件：`esp-apply.sh`、`to-fastboot.sh`、`fix-ab-mark-successful.sh`、`slot-attr.py`。
- 方法：`read`/`grep` 静态读代码；在 `/tmp` 副本上跑 `sh -n`/`bash -n`/`python3 -m py_compile`，
  并实跑 `python3 android-lpdump.py --verify`（纯本地只读解析 `backup/official-rom-15.10.259/`）确认建议补丁不改行为。
- 建议补丁：`/tmp/script-audit-adb.patch`（10 文件 / 476 行，**`git apply --check -p1` 通过**，未落仓）。

## #0 一页结论

| 判据 | P0 | P1 | P2 | 合计 |
|---|---|---|---|---|
| A 忘记清理失败标志（槽属性 / 落点 / 残留） | **6** | 2 | 2 | 10 |
| B 忘记检查 GPT（存在性 / LUN / 单位 / 主备表 / 覆盖） | **3** | 3 | 0 | 6 |
| C 写后校验（退出码可信度、读回比 sha） | **1** | 4 | 0 | 5 |
| D 超时 / 串行 / 通道纪律 | 0 | 5 | 3 | 8 |
| E 回退（可复现备份 + 回退步骤可执行） | 0 | 1 | 1 | 2 |
| F 幂等与重入 | **1** | 0 | 1 | 2 |
| G 设备选择（永不猜）/ 工具正确性 | **1** | 0 | 3 | 4 |
| **合计** | **12** | **15** | **10** | **37** |

口径：同一函数里的同一根因算一条；每条都能落到一个 `file:line`。

**最严重三条（任意一条复发都直接毁实验）**

1. **ADB-17 `t2-stock-lun45.sh:30-31/35-36`**：`qdl … | tail -6 | tee` 之后 `say "step1 rc=$?"` —— `$?` 是 `tee`
   的退出码（恒 0）。qdl 静默失败（PITFALLS #669「写路径退出码不可信」）时脚本仍继续写 LUN0 全量 ~15 GiB；
   叠加 ADB-03（末行恒 `exit 0`）⇒ **整条全量线刷的成功/失败在脚本层面不可观测**。脚本是 `#!/bin/sh`(dash)，
   `set -o pipefail` 不可用。**（审查期间该两处已被并行任务修掉；`reset` 段与收尾判定仍未修。）**
2. **ADB-01 `slot-switch.sh:130`**：切槽前不查目标槽 `UNBOOTABLE`/`retry=0`。这正是本轮设备现状（fastboot 带
   UNBOOTABLE）：`set-active a` + reboot ⇒ 设备停在 fastboot，脚本只等 300 s 后 `exit 1`，**把设备留在
   「下一次实验注定失败」的 fastboot**；而修表命令（`slot-attr.py set <s> --retry 7 --no-unbootable`）脚本里一字未提。
3. **ADB-13 `dev-super-relabel.sh:14/30/40`**：按分区号 10 直接 `sgdisk --typecode/--change-name` + `mkfs.ext4 -F`，
   既不校验扇区单位（本机逻辑 4096；项目自己的结论是 sgdisk 按 512 读会整表错位 —— `scripts/slot-attr.py` 头注释、
   `.pi/memory/failures-kernel.md:141`），也不校验 `sda10` 的 GPT name 是否还是 `super`。写错分区 = 直接抹数据。

### 0.1 Top 10 必须先修

| # | 编号 | 一行 |
|---|---|---|
| 1 | ADB-17 | `t2:30/35` 退出码取自 `tee`（恒 0）⇒ qdl 失败照样写 LUN0。dash 无 pipefail，必须 `>log 2>&1` 后立刻 `rc=$?`。**状态：审查期间（11-18 18:01）已被并行任务按同一办法修掉两处 qdl；`reset` 一行仍无 rc 判定、仍无落点校验（见 ADB-03）。** |
| 2 | ADB-11 | `t2:28-40` 全量刷含 `gpt_main0/gpt_main4`，**写前零存证**。**状态：并行任务已补「写后读回比 cmp」「写前 slot-attr show」，但写前主/备 GPT 的落盘仍缺（失败即无回退件）。** |
| 3 | ADB-12 | `t2:16/23` + `linux-state-audit.sh:111/144`：`lsusb \| grep 05c6:9008` 认的是「总线上**任何**一台 9008」，而 `qdl -s ufs` 不认 serial ⇒ 可能刷到隔壁项目/另一台机器（#669 第一缺陷；`MEMORY.md` §EDL 工具链未列 serial 选择器）。 |
| 4 | ADB-03 | `t2:51` 末行 `say "=== T2 end ==="` ⇒ 恒 `exit 0`；9008 / fastboot / 黑屏都算成功。 |
| 5 | ADB-01 | `slot-switch.sh:130` 切槽前不体检目标槽 `UNBOOTABLE`/`retry`，坏槽照切。 |
| 6 | ADB-02 | `slot-switch.sh:139` `qbootctl -m b … \|\| true` 不读回 ⇒ #181（retry 逐次扣到 UNBOOTABLE）静默复活。 |
| 7 | ADB-04 | `linux-state-audit.sh:146-155` `qdl reset` 后不校验是否离开 9008；EDL 失败只记 WARN ⇒ **设备留在 9008 而脚本 `exit 0`**。 |
| 8 | ADB-05 | `lib-wait.sh:90` `wa_adb_alive` 缺 `9>&-` ⇒ adb fork-server 继承 device-lock 的 fd 9，之后所有设备脚本 flock 阻塞（#371 后半）。`slot-switch.sh:43` 的 `adbx()` 已关 fd，等待路径却绕过了它。 |
| 9 | ADB-13 / ADB-32 | `dev-super-relabel.sh` 不校验扇区单位/分区身份；`mkfs.ext4 -F` 无条件格式化（重跑即毁数据）。 |
| 10 | ADB-34 | `bl-unlock.sh:14` 取「总线第一台」fastboot 设备且 `SN_EXPECT` 可选，`flash unlock` 不可逆 ⇒ 打到无关手机。 |

---

## §A 忘记清理失败标志

### ADB-01 · P0 · `scripts/slot-switch.sh:126-133`

- 触发：`slot-switch.sh a --reboot`（或 `b`），目标槽 GPT `boot_*` byte6 已 `bit7=1`(UNBOOTABLE) 或 `retry=0`
  （典型来源：反复 kexec/reboot 实验，见 `.pi/memory/failures-kernel.md:67`）。
- 后果：`fb --set-active` 只改 ACTIVE 位，不清 UNBOOTABLE、不补 retry ⇒ ABL 放弃该槽 → 停在 fastboot；
  `wait_adb 300`/`wait_linux` 失败后 `exit 1`，设备留在 fastboot + 坏槽激活。
- 修法：切之前 `getvar slot-unbootable:<s>` / `slot-retry-count:<s>`，坏槽拒绝并打印
  `python3 slot-attr.py set <s> --retry 7 --no-unbootable`；`FORCE=1` 才放行。补丁已含 `preflight_slot()`。

### ADB-02 · P0 · `scripts/slot-switch.sh:139`

- 触发：切回 b 槽后 `qbootctl -m b` 失败（GPT 重扫竞态——`failures-kernel.md:141` 记载紧随其后的
  `qbootctl -n b` 会报 `No slots found`；qbootctl 缺失；cmdline 无 slot_suffix 时默认按 slot a 处理）。
- 后果：`|| true` 吞掉 ⇒ `BOOT_SUCCESSFUL` 未置 ⇒ 每次启动扣 retry，~7 次后 b 槽 UNBOOTABLE（#181 原文）。
  紧随的 `qbootctl -n b` 也被 `|| true` 吞，等于完全没有判据。
- 修法：置完读回（`slot-attr.py show | grep 'boot_b '` 要求 `succ=1`），不符即非零退出。补丁已含 `mark_successful()`。

### ADB-03 · P0 · `scripts/t2-stock-lun45.sh:51`

- 触发：任何路径跑到文件末尾。
- 后果：恒 `exit 0`。与 ADB-17 组合后，脚本输出的「成功」与设备实际状态完全脱钩。
- 修法：收尾判定 + 非零退出（补丁：仍在 9008 → `exit 4`；本机未以 adb 枚举 → `exit 4`）。

### ADB-04 · P0 · `scripts/linux-state-audit.sh:143-155`

- 触发：`--edl`。`qdl -s ufs … reset` 之后无任何落点校验；`EDL读`/`EDL进` 失败只 `cnt UNKNOWN`（WARN 类）。
- 后果：`reset` 静默失败 / loader 不响应 ⇒ 设备留在 9008；末行 `[ "$miss" -eq 0 ]` 只看 MISSING/DRIFT，
  WARN 不参与 ⇒ **退出码 0**。与判据 A 第三条（「设备被留在 9008 而脚本 return 0」）逐字对应。
- 修法：reset 后 60 s 内有界轮询「离开 9008」，未离开算 DRIFT；EDL 读失败算 DRIFT 而非 WARN。

### ADB-05 · P0 · `scripts/lib-wait.sh:89-92`

- 触发：任何 `device_lock_acquire` 之后的 `wait_adb`（`slot-switch.sh:76`、`uefi-boot-trial.sh` 等）。
- 后果：`adb -s … get-state` 未关 fd 9 ⇒ adb fork-server 常驻并继承锁 fd ⇒ 之后所有设备脚本
  `flock -w 300` 阻塞（或永久）。PITFALLS #371 记录过同一现象。
- 修法：`wa_adb_alive` / `wa_fastboot_alive` / `wa_ssh_alive` 全部 `9>&-`。

### ADB-06 · P0 · `scripts/t2-stock-lun45.sh:43-49`

- 触发：reset 后 120 s 观察窗。`[ -n "$FB" ] || break` 把「fastboot 消失」当成功；`AD` 用
  `adb devices | grep -c 'device$'` 数**任意**设备。
- 后果：① 设备从 fastboot 掉到 9008/黑屏也叫「可能进系统」；② 总线上另一台手机在线 ⇒ `adb_dev=1` 假阳性；
  ③ `fastboot devices | head -1` 是 PITFALLS #584 的 SIGPIPE 形状（`head` 提前退出打断设备侧 bulk 通道）。
- 修法：只认本机 `$SER` 重新枚举（`awk -v s="$SER" '$1==s'`），fastboot 输出先落变量再取首行。

### ADB-07 · P1 · `scripts/slot-switch.sh:126-134`

- 触发：任何 `a|b` 调用（尤其失败路径）。
- 后果：脚本**没有日志文件**；「before」只记 `current-slot`，不记 `boot_a/boot_b` 的 byte6
  （succ/retry/unbootable）。wait 超时后 `exit 1` 时磁盘上什么都不留 ⇒ 事后无法复盘「切之前是什么状态」。
- 修法：头部 `exec > >(tee -a logs/slot-switch-$(date +%FT%T).log) 2>&1`；切换前后各 `show_attrs`
  **并**（设备在 Linux 时）`slot-attr.py show`，失败路径也要有这两行。

### ADB-08 · P1 · `scripts/dev-super-relabel.sh:21-23`

- 触发：`--apply` 写 GPT 前只 `sgdisk --backup=/root/gpt-sda-$TS.bin`（落在**设备** /root）。
- 后果：回退件与被改对象在同一块盘上；后续若回收/格式化该盘（本脚本干的就是这件事）或重刷 stock，备份一起消失。
  主机侧无副本、无 sha 台账。
- 修法：备份后立刻回传 `backup/<SN>-<容量>/gpt-sda-<TS>.bin` 并把 sha256 写进台账。

### ADB-09 · P2 · 全板块（缺失能力）

- 现状：`grep -rn "misc\|BCB" scripts/*.sh scripts/*.py` 无任何脚本读取 GPT `misc` 的 bootloader message。
- 后果：一旦残留 BCB（`bootonce-bootloader` / recovery command）让设备又进 fastboot，现有脚本无法区分
  「槽属性问题」与「BCB 问题」。**已证 ABL 忽略 misc BCB**（`scripts/to-fastboot.sh:5`），所以是低概率而非零概率。
- 修法：实验前后各 `qdl read <lun>/<misc-lba>+1`（或设备侧 `dd if=/dev/disk/by-partlabel/misc bs=1024 count=1 | xxd`）
  并落日志对比。

### ADB-10 · P2 · 全板块（缺失能力）

- 现状：`slot-switch.sh` / `t2` / `q26` 重启前后都不记录 `/sys/fs/pstore` 的条目与 mtime。
- 后果：崩溃判读把上一轮 pstore 记录当本轮（假阳性）。`display-drop-forensics.sh` 已有「先记 mtime 再判」的习惯，
  adb/fastboot 主线没跟上。
- 修法：实验开始/结束各 `ssh … 'ls -l /sys/fs/pstore'` 落日志。

---

## §B 忘记检查 GPT / 分区归属

### ADB-11 · P0 · `scripts/t2-stock-lun45.sh:28-40`

- 触发：T2 全量线刷（`rawprogram4.xml` + `rawprogram_save_persist_unsparse0.xml`）。
- 后果：两份 XML 都带 `gpt_main*.bin`/`gpt_backup*.bin` ⇒ 重写 LUN4 与 **LUN0** 的整张 GPT：
  `linux17/eldenesp/elden-super` 条目全部消失，而脚本**写前没有导出任何 GPT/槽属性**。失败即无回退件
  （判据 B「主表+备表」与 E「回退」同时失守）。
- **当前状态（18:01 并行任务）**：已补「写前 `slot-attr.py show`」与「写后 `read 0/0+6,4/0+6` + `cmp` 原厂件」；
  但**写前**主/备 GPT 仍未落盘（`readback` 是写后取，覆盖不了「写坏后要回退到写前」这个用途），
  且读回只取 6 扇区（主表 34 扇区里的 header 段），备表（末 34 LBA）从未读。
- 修法：写前 `qdl read <lun>/0+34`（主表）+ 末 34 扇区（备表）+ `sha256` 落盘；补丁给了主表与单位判定。

### ADB-12 · P0 · `scripts/t2-stock-lun45.sh:16,23`；`scripts/linux-state-audit.sh:111,144`

- 触发：总线同时插着另一台 Qualcomm 设备且处于 9008（多项目共用刷写机时常见）。
- 后果：`lsusb | grep -q 05c6:9008` 通过 ⇒ 全量/只读命令发给**别人的 9008**。qdl 无 serial 选择器
  （`MEMORY.md` §EDL 工具链只列 `-s ufs` 存储类型）⇒「先确认归属」是唯一防线。
- 修法：只接受「本脚本刚对 `$SER` 发过 `oem edl`」这条路径；已在 9008 时要求显式 `ALREADY_EDL=1`，
  并把 `lsusb -d 05c6:9008` 完整行写进日志。

### ADB-13 · P0 · `scripts/dev-super-relabel.sh:13-16,28-30`

- 触发：`--apply`。脚本假设「分区 10 = super，且 sgdisk 读到的表是对的」。
- 后果：① 本机 UFS 逻辑扇区 4096（`slot-attr.py` 头注释；`failures-kernel.md:141/149` 记「`blockdev --getsz`
  返回 512B 扇区数而 UFS 逻辑扇区 4096，按 4096 换算必须 /8」）——若 sgdisk 按 512 读表，
  `--typecode=10:8300` 会写到错位 LBA 并按错位内容重算 CRC = **静默毁 GPT**；② 分区号 10 在重排后不一定还叫
  `super`，改错分区类型后紧跟 `mkfs`。
- 修法：`blockdev --getss` 必须 4096；`sgdisk -p` 必须自报 `Sector size (logical): 4096`；`sgdisk -i 10` 的
  `Partition name` 必须等于 `super`；任一不符直接拒绝（补丁已含）。

### ADB-14 · P1 · `scripts/linux-state-audit.sh:145`

- 触发：`--edl` 取 GPT 做对账。
- 后果：① 只读主表、不读备份表 —— B 项要求「主+备同时更新、写完读回」，这里只验主表；② 读回件不做尺寸/单位校验
  （qdl 会探测 512/4096；原命令 `0/0+6` 若按 512 解释只拿到 header，entry array 被截断，而
  `gpt-audit-tb322fc.py` 照样输出「无漂移」）；③ 无 `qdl … sha256` 第二把尺子（#669 的判据要求）。
- 修法：读 34 扇区 + 长度必须落在 `17408`/`139264` 之一 + `qdl sha256` 设备端摘要进日志（补丁已含前两条）。

### ADB-15 · P1 · `scripts/linux-state-audit.sh:109-124`

- 触发：`--device`。
- 后果：① 全程不做 `device_lock_acquire`（同板块其它脚本都做）⇒ 与 `slot-switch`/`q26` 并发时抢通道
  （#658 的前提）；② `case "$esp" in *linux17*)` 只 grep `by-partlabel` 清单，**不核 LUN 归属**，也不处理
  「Android 侧命名 ≠ Linux 侧命名」：Android 的 `by-partlabel` 是跨 LUN 合并视图，名字在清单里 ≠ 它在 LUN0 预期 LBA 上。
- 修法：加锁；同时记 `/dev/block/sd* → readlink -f` 的 LUN 映射与 `ls -l /dev/disk/by-partlabel`（带链接目标）。

### ADB-16 · P1 · `scripts/android-lpdump.py:103-113`

- 触发：`--extract` 抽到跨段间空洞的分区（本包 `super_1..8` 之间确有空洞，`android-super-scan.py` 专为此存在；
  实测某分区 extent 已出现 `32@5232` 这种明显落在段覆盖之外的偏移）。
- 后果：`SegReader.read()` 对未覆盖区间**静默返回 0** ⇒ 产出「掺零镜像」，而算出来的 sha 看起来完全正常（判据 C）。
- 修法：记录未覆盖字节，`--extract` 前有空洞即拒绝并提示先跑 `android-super-scan.py`（补丁已含）。

---

## §C 写后校验 / 退出码可信度

### ADB-17 · P0 · `scripts/t2-stock-lun45.sh:30-31,35-36`

- 触发：任意 qdl 失败（loader 不合、patch 不匹配、掉线、写保护）。
- 后果：`$?` 是 `tee` ⇒ 恒 0；且 `tail -6` 只留尾部，前面的 `NAK`/`ERROR` 行在日志里也丢了（没有 `.out` 全文）。
- 修法：`cmd >"$O/stepN.out" 2>&1; rc=$?`，再 `tail`，再判 `rc`。注意 dash 下 `set -o pipefail` 会报
  `pipefail: invalid option` 并继续跑不带 pipefail 的脚本 = 又一种「静默降级」。
- **当前状态（2026-11-18 18:01 并行任务改动）**：step1/step2 已改为 `>"$O/stepN.raw.log"` + `rc=$?` + 非零 `exit 3`，
  本条前半已修；**仍缺**：① `reset`（`t2:76`）仍是 `qdl … | tail -2 | tee`，失败与否则无判定；
  ② 收尾无落点判定（见 ADB-03）。本报告补丁不再重复已被修的两处。

### ADB-18 · P1 · `scripts/bl-unlock.sh:22-32`

- 触发：fastboot 通道被孤儿进程抢（#658）、USB 抖动。
- 后果：`getvar all` / `flash unlock` / `oem unlock-go` **全部无 timeout**；`set -uo pipefail` 无 `-e` ⇒
  `flash unlock` 成功而 `oem unlock-go` 失败时脚本继续打印「设备将自动重启」，退出码 0；也没有读回校验
  （sn.img 是否写全、`getvar unlocked` 是否变 yes）。
- 修法：统一 `fbx()` 包 timeout；`oem unlock-go` 失败即非零；收尾用 `getvar unlocked` 或
  `ro.boot.verifiedbootstate` 作落地判据。

### ADB-19 · P1 · `scripts/q26-recheck.sh:53-55,64-107`

- 触发：`fastboot boot` 后设备未跑新镜像（面板失败回落、Q28 闩锁）。
- 后果：判据只有「SSH 可达」+ 固定 3 s 轮询；不校验起的是 `$IMG`（`boot-info.txt` 只记录 `uname -a`，不比对）；
  `wlan0` 未出现、`assoc_t`/`ip_t` 为空都只 `echo` 后继续 ⇒ 末行 `echo "[q26] 完成"`，**恒 exit 0**。
- 修法：记录 `boot_id` 并做换代判据（`lib-wait.sh` 已有 `wait_reboot`/`wa_boot_changed`）；未拿到
  wlan0/关联/IPv4 时非零退出或在 `SUMMARY.txt` 顶部标 `VERDICT=INVALID`（补丁只加了 boot_id 与提示，
  未改退出语义以免破坏既有跑法）。

### ADB-20 · P1 · `scripts/linux-state-audit.sh:117`

- 触发：`adb` 在线但系统未起全（`sys.boot_completed` 为空 / 0 / 卡在 bootanim）。
- 后果：`emit "状态机" OK "… boot_completed=$(g sys.boot_completed) …"` 无条件标 OK ⇒ 「adb 在线」被当成
  「系统真起来了」，正是任务书点名的「adb 侧结论当设备真相」。
- 修法：值 ≠ 1 时标 DRIFT（补丁已含）。

### ADB-21 · P1 · `scripts/c0-android-evidence.sh:26-45`

- 触发：`dumpsys` 卡住（drm/sensorservice 在异常 ROM 上会挂），或 adb 未授权。
- 后果：15 处 adb 调用**没有一处带 timeout**；`$ADB shell "$@"` 既没 `-n` 也没 `</dev/null`，可能无限挂起并
  吃掉调用方 stdin（#397 同族：`while read` 里裸调 ssh 吞 stdin）。C0 数据「一旦 a 槽覆盖即不可复得」，
  挂死等于白跑。
- 修法：`ADB="timeout 30 adb -s $SER"` + `shell -n … </dev/null`（补丁已含）。

---

## §D 超时 / 串行 / 通道纪律

### ADB-22 · P1 · `scripts/c0-android-evidence.sh:20-26`

- 触发：总线有多台 adb 设备（多项目共用调试机）。
- 后果：`SER=$(adb devices | awk '…{print $1; exit}')` 取**第一台**，无唯一性检查、无 product 复核
  ⇒ 把无关设备的 getprop/dumpsys 当成本机「标准答案」写进 `backup/<SN>-<容量>/c0-baseline/`
  （目录名跟着错设备走，事后还很容易被当成真基线）。PITFALLS #371 的原形状。
- 修法：唯一设备才自动选，否则要求显式 SN（补丁已含）。

### ADB-23 · P1 · `scripts/bl-preunlock-evidence.sh:8-10`

- 触发：同上；或设备授权弹窗未点。
- 后果：`head -1` 取第一台；`adb wait-for-device` 无超时上限（无 `-s` 时等**任何**设备）⇒ 可无限阻塞。
- 修法：唯一/显式 SN；`timeout 60 adb -s … wait-for-device`（补丁已含）。

### ADB-24 · P1 · `scripts/bl-preunlock-evidence.sh:21-35`

- 触发：任一条 `dumpsys -l` / `settings list` 卡住。
- 后果：15 处 adb 调用无 timeout；for 循环里 `adb -s "$SER" shell getprop $p` 不 `-n`/不重定向 stdin。
- 修法：`adb_s()` 统一包超时 + `shell -n` + `</dev/null`（补丁已含）。

### ADB-25 · P1 · `scripts/q26-recheck.sh:43`

- 触发：总线上有多台 fastboot 设备。
- 后果：`fastboot devices | awk 'NR==1{print $1}'` 取第一台、不校验 `product` ⇒ 可能把本机内核
  `fastboot boot` 到别的设备（RAM-only，但仍是往别人设备灌 payload）。
- 修法：显式 `SER` 或 `getvar product` 必须含 `elden`（补丁已含）。

### ADB-26 · P1 · `scripts/slot-switch.sh:75,103`

- 触发：`wait_fastboot`（`ensure_fastboot` 的落点校验）。
- 后果：`wa_fastboot_alive` 只判「有任意 fastboot 设备」，不认 SN ⇒ 我们的设备还没进 fastboot 时，
  总线上的另一台 fastboot 设备会让等待立刻「成功」，随后 `fb getvar` 才在 `-s` 处失败/挂到超时。
- 修法：`wait_fastboot [timeout] [serial]`，带 SN 时用 `wa_fastboot_alive_ser`（补丁已含）。

### ADB-27 · P2 · `scripts/slot-switch.sh:43,94,122`

- `adb shell` 无 `-n`、无 `</dev/null`（`9>&-` 已正确处理）⇒ 交互式调用时可能与脚本 stdin 抢数据。
- 修法：`adbx -s "$SER" shell -n … </dev/null`。

### ADB-28 · P2 · `scripts/lib-wait.sh:84,88`

- `wa_ssh_alive`/`wa_fastboot_alive` 同样没 `9>&-`（ssh 不常驻，风险低于 adb）；`wa_fastboot_alive` 不认 SN（见 ADB-26）。
- 修法：`9>&-` + `wa_fastboot_alive_ser`（补丁已含）。

### ADB-29 · P2 · `scripts/waydroid-proxy-setup.sh:73-85`

- 触发：容器 adbd 未起、`adb connect` 超时。
- 后果：① 远端 `adb` 全无 timeout；② `adb kill-server` 会波及设备上其它 adb 使用者（宿主机调试/其它容器）；
  ③ 结束后不 `kill-server`/不 `disconnect`，**留下 adb server 与 TCP 连接**。
- 修法：每条 adb 包 timeout；结束 `adb disconnect <ADDR>:5555; adb kill-server`。
- 正面：本板块**没有** `adb forward`/`adb reverse` 使用（全仓 grep 仅此处 `adb connect`），所以「残留 forward 规则」不成立。

---

## §E 回退

### ADB-30 · P1 · `scripts/slot-switch.sh:78-87` + 头部注释

- 触发：读槽属性 / 需要回退时。
- 后果：① `show_attrs` 用 `fastboot getvar slot-unbootable/slot-retry-count/slot-successful` 当槽真相 ——
  那是 ABL 的内存视图，权威在 GPT byte6（`slot-attr.py` 头注释、`failures-kernel.md:67`），写后也不从 GPT 读回；
  ② 头部注释写「回退 = 再切回」，但槽被标 UNBOOTABLE 后 `set-active` 无法回退（ABL 直接放弃），必须
  `slot-attr.py set … --no-unbootable --retry 7` —— 这条没写，属「回退步骤不可执行」。
- 修法：`show_attrs` 追加一次设备侧 `slot-attr.py show`（Linux 侧）或在 fastboot 侧明确标注「ABL 视图」；
  注释补 UNBOOTABLE 情形的回退命令。**未进补丁**：涉及判定口径变更，需先在任一单元上对照一次。

### ADB-31 · P2 · `scripts/q26-recheck.sh` 全文

- 无换代判据 ⇒ 无法区分「新内核」与「旧系统还在答」（已并入 ADB-19 的修法；本条只记口径）。

---

## §F 幂等与重入

### ADB-32 · P0 · `scripts/dev-super-relabel.sh:38-41`

- 触发：第二次 `--apply`（脚本自称「可逆」，实际不可重入）。
- 后果：无条件 `mkfs.ext4 -q -F` ⇒ 已挂载在用的 ext4 被抹平。
- 修法：`blkid` 已是 `ext4` 且 label 匹配则跳过；其它文件系统要 `RECREATE=1` 才格式化（补丁已含）。

### ADB-33 · P2 · `scripts/dev-super-relabel.sh:46-52`

- fstab 追加有 `grep -q` 保护（**幂等 OK**）、`mkdir -p` OK；但 `mount "$MP" 2>/dev/null || mount "LABEL=…"` 把
  首次失败完全掩盖，最终只有 `df -h` 间接体现。
- 修法：`findmnt -n "$MP"` 复核，失败即非零。

---

## §G 设备选择 / 工具正确性

### ADB-34 · P0 · `scripts/bl-unlock.sh:14-18`

- 触发：总线有多台 fastboot 设备（或另一台手机恰在 fastboot）。
- 后果：`fb=$(fastboot devices | awk '{print $1}' | head -1)` 取第一台；`SN_EXPECT` 是**可选**的 ⇒
  `flash unlock`（不可逆、擦用户数据、永久影响 Widevine L1/保修）可能落在无关设备上；
  `| head -1` 同时是 #584 的 SIGPIPE 形状。
- 修法：`SN_EXPECT` 强制必填 + 先落变量再取首行（补丁已含）。

### ADB-35 · P2 · `scripts/t2-stock-lun45.sh:16,20,47`

- `fastboot -s HA2EXB0E` 把序列号写死（违反「产出必须设备无关」：U1/U2 任一单元跑都会在 `oem edl` 处静默失败，
  而失败又被 `tee` 的 rc 吞掉）。改为 `SER=${SER:-HA2EXB0E}`（补丁已含）。
- `lsusb` 未套 `timeout -k`（本板块唯一没超时的外部命令）；USB 栈异常时会挂。

### ADB-36 · P2 · `scripts/android-img-inventory.py:73`

- 触发：`--max-depth N`。
- 后果：`if typ == "D" and rel.count("/") < a.max_depth` —— `rel` 每次只追加 `/x`，与真实目录深度无关
  ⇒ `--max-depth` 形同虚设（层级不受控，深镜像上耗时不可预期）。
- 修法：用 `path.count("/")` 或显式 `depth` 变量。

### ADB-37 · P2 · `scripts/android-super-scan.py:101,181`

- `load_lp()` 用裸 `assert magic == 0x616C4467` 做校验 ⇒ 畸形输入得 traceback 而非可读错误；
  `--segment-dir` 与 `--xml` 目录不同时静默读错文件（`meta_path` 由 `segment_dir` 拼，而 `segs` 由 xml 目录拼）。
- 修法：`sys.exit("…")` + 校验 `meta_path` 存在且其 base_lba 与 xml 一致。

---

## §2 已核实无问题（避免重复审计）

1. **`slot-switch.sh:41-67` 的设备选择已按 #371 修好**：`fb()` 一律 `-s "$SER"`；`have_adb()` 要求显式 SER；
   `resolve_target()` 只允许「fastboot 唯一设备 + `product` 含 `elden`」自动推导；`adbx()`/`adb_devices()` 已 `9>&-`。
   剩余缺口只在**等待路径**绕过它们（ADB-05/ADB-26）。
2. **`lib-wait.sh` 的换代判据设计正确**：`wait_boot_capture` + `wa_boot_changed`（boot_id 变）+ 降级时显式告警；
   并有 stub 测试 `scripts/test-lib-wait.sh:99-106`（含「错误序列号必须拒绝」用例）。
3. **`lib-wait.sh:88` 已吸收 #584**：`fastboot devices` 先落变量再判断，不接管道。
4. **`esp-apply.sh:180-210` 是本板块「写后校验」的正面样板**：同一 qdl 会话 `write` + `read`，再用 `sha256sum`
   逐字节比对，不一致 `exit 1` 并提示用旧 ESP 回滚。其它写路径应照抄。
5. **`q26-recheck.sh:26-27` 持锁**；`t2:30/35` 与 `linux-state-audit.sh:109-127` 都套了 `timeout -k`。
6. **`android-super-scan.py` 的「原始 magic 命中 + checksum 复核」是正确防线**：`iter_hits` 命中后必须过
   `validate()`（geom 校 `struct_size==52` + SHA-256；header 校 `header_size∈[128,256]` + SHA-256）才算。
7. **`slot-attr.py`** 本身：主备双表同改 + 双 CRC 重算 + `--dry-run` + `image` 模式，本板块质量最高；
   问题只在**没人用它做前置体检/读回校验**（ADB-01/02/30）。
8. **`fix-ab-mark-successful.sh`** 的判据（OpenRC runlevel + 显式 `start()` + 复核 `slot-attr.py show`）是对的，
   与 ADB-02 的修法同一口径。

## §3 未进补丁 / 需上机

- **ADB-30**（`show_attrs` 用 ABL 视图当槽真相 + 回退注释缺 UNBOOTABLE 情形）：判定口径变更，需先在一台单元上
  fastboot `getvar` 与 `slot-attr.py show` 对照一次再改。
- **ADB-36 / ADB-37**（img-inventory 深度判据、super-scan 的 assert/segment-dir）：离线取证工具，不在设备路径上。
- 本轮**未验证**（禁执行）：`getvar` 实际返回格式、qdl 的 512/4096 判定、`lsusb -d 05c6:9008` 输出形态。
  补丁里凡涉及这三点都写成「读回长度判定」而非硬编码，以留上机实测空间。

## §4 补丁清单（`/tmp/script-audit-adb.patch`）

| 文件 | 覆盖条目 | 语法校验 |
|---|---|---|
| `scripts/t2-stock-lun45.sh` | ADB-03/06/11(写前存证)/12/17(reset 段)/35 | `sh -n` OK（按 18:01 的并行改动 rebase） |
| `scripts/slot-switch.sh` | ADB-01/02/26 | `bash -n` OK |
| `scripts/lib-wait.sh` | ADB-05/28 | `bash -n` OK |
| `scripts/linux-state-audit.sh` | ADB-04/14/15/20 | `sh -n` OK |
| `scripts/dev-super-relabel.sh` | ADB-13/32 | `sh -n` OK |
| `scripts/c0-android-evidence.sh` | ADB-21/22 | `bash -n` OK |
| `scripts/bl-preunlock-evidence.sh` | ADB-23/24 | `bash -n` OK |
| `scripts/bl-unlock.sh` | ADB-18/34 | `bash -n` OK |
| `scripts/q26-recheck.sh` | ADB-19/25 | `bash -n` OK |
| `scripts/android-lpdump.py` | ADB-16 | `py_compile` OK；`--verify` 实跑输出未变 |

`git apply --check -p1 /tmp/script-audit-adb.patch` → 通过（按任务要求只放 `/tmp`，未落仓）。

## §5 引用

- `PITFALLS/README.md`：#371（裸 adb 探测打到另一台手机 + 锁 fd 被 adb fork-server 继承）、#584（fastboot 接管道 →
  SIGPIPE 打断 bulk 通道）、#658（孤儿 fastboot 抢通道）、#669（EDL 三类静默缺陷：`--lun` 不报错 / 退出码不可信 /
  需设备端 sha256 第二把尺子）、#181（不置 BOOT_SUCCESSFUL ⇒ 7 次后 UNBOOTABLE，见 `scripts/fix-ab-mark-successful.sh` 头注释）、
  #473（sgdisk 默认对齐会挪动分区起点）。
- `.pi/memory/failures-kernel.md:67`（kexec 反复失败后 b 槽 UNBOOTABLE，根治 = `slot-attr.py mark-successful b`）、
  `:141`（qbootctl 走 `BLKSSZGET` 4K 自动识别，「无 sgdisk 那类 512B/4096B 误判」；`-m` 纯 GPT 写、主备+CRC 同改）、
  `:149`（`blockdev --getsz` 512 vs 逻辑 4096，换算必须 /8；槽 GPT 在 `/dev/sde`）。
- `scripts/slot-attr.py` 头注释（AB_FLAG_OFFSET=byte6；bit7 UNBOOTABLE / bit6 SUCCESSFUL / bit3..5 retry；
  本机 4096 逻辑扇区；A/B 在 `/dev/sde`，`boot_a`=sde12、`boot_b`=sde45）。
- `scripts/to-fastboot.sh:5`（已证 ABL **不认** misc BCB 的 fastboot 请求）。
- `.pi/memory/MEMORY.md` §EDL 工具链（qdl v2.9 能力清单：无 serial 选择器；`sha256` 设备端摘要；512/4096 探测）。
- `reports/code-style-and-duty-overlap-audit-20261030.md`（本报告沿用其 P0/P1/P2 + 「已核实无问题」体例）。

## §6 并发改动说明

审查期间（2026-11-18 18:01）另一个并行任务正在改 `scripts/t2-stock-lun45.sh`（已修：qdl 落日志取 rc、
`-R` 跳过会话末 reset、写前 `slot-attr.py show`、写后 `cmp` 原厂件）。本报告的
`/tmp/script-audit-adb.patch` 已按该时刻的文件内容 rebase，只保留仍缺的部分（ADB-03/06/11/12/17 的 reset 段/35）；
若该文件继续变动，请以 `git apply --check` 结果为准重新 rebase。其余 9 个文件在工作区无改动。
