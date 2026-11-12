# 脚本冗余审计：reboot → fastboot 入口 + 其它脚本过时缺陷（lane E）

日期 2026-11-12 · 只读审计（未改任何既有文件、未碰设备、未 commit）
起点（用户现场判定）：**「重启到 fastboot 有多个脚本，且只有一个是干净重启，agent 刚用的是有缺陷的那个」**
—— 刚用的 = 设备侧 `reboot2 bootloader`（`rootfs/reboot2.c` → `RESTART2 reason` 内核路径），
结果 USB 全不枚举、屏幕不亮，人工断电（`PITFALLS #368` 2026-11-12 复现）。

> 本文件结构固定：§0 结论先行 / §1 入口盘点 / §2 冗余冲突 / §3 其它过时缺陷 / §4 统一口径 / §5 未证盲区。
> 每条结论给 `文件:行号` + 可复现命令。写作过程按「每 3–5 条追加」分节落盘。

---

## §0 结论先行（≤ 8 行）

1. **唯一推荐入口 = `scripts/to-fastboot.sh`，内部只允许 `eldroid-bootctl reboot bootloader`，且必须是带 6 s sysrq-b 看门狗的版本**（`scripts/eldroid-bootctl`，sha `f86d7d2d…`）。`reboot2 bootloader` 停用。
2. 关键发现：`reboot2` 与 `eldroid-bootctl` 的**内核路径完全相同**（都只是 `RESTART2 "bootloader"` → PSCI `SYSTEM_RESET2`），差别**只在卡死兜底** ⇒ #368 与 #525/#542 是同一故障、只差一个看门狗。
3. 入口盘点 **19 行 / 18 个实入口**（含 7 份重复的 ssh 封装）；带兜底的**只有 1 个**；实测成功 **1**、实测失败 **7**、无实测 **7**、未证 **1**、过时提示 **2**。
4. 成对冗余 **11 组**；其它过时缺陷 **17 条**（FATAL 7 / REDUNDANT 5 / STALE 5）。
5. 最危险 3 条：① `MANIFEST` 装的 `eldroid-bootctl` 是**无看门狗版**（重铺设备就退回 #368）；② `MANIFEST` 装的 `/usr/local/sbin/slot-attr.py` 是旧变体 —— **`--dry-run` 放在子命令前会被覆盖成真写**（示范文档正是这种写法），已本地最小复现证实，见 S16；③ `sources.tsv:16` 把已两次实测失败的 `reboot2` 写成「Linux→fastboot 的**可靠入口**」（同族：`usb-gadget` 包装副本仍写死 `HA2CB1KY`）。
6. 最该先修：`packaging/…/files/usr/local/bin/eldroid-bootctl` ← `scripts/eldroid-bootctl`（+ 刷 MANIFEST sha）—— 不修这一条，推荐入口就会在重铺后静默退化。
7. `cycle.sh --fastboot`（misc BCB）与 `cycle.sh --soft`（裸 sysrq-b）**都到不了 fastboot**（仓库内有实测记录）；`uefi-oneshot.sh:32` 从 UEFI 侧 `fastboot reboot bootloader` 也实测进不了 ABL。
8. 停手判据：发出后 25 s 内 `fastboot devices` 空 + `lsusb` 无 `18d1/05c6/1d6b` + `ssh uptime` 不通 ⇒ **停**，不重试，请用户物理断电（#368/#391）。

---

## §1 reboot → fastboot 入口盘点

### 1.0 机制口径先校准（后续所有判定的前提）

当前内核（vk41 起）里 `reboot bootloader` 的**真实**路径是 PSCI `SYSTEM_RESET2` vendor reset，
不是 PMIC SDAM 写 magic：

```
patches/kernel-history/elden_vk41-psci-reboot/0003-elden-vk41-minimal-PSCI-SYSTEM_RESET2-vendor-reset-h.patch:11-15
  "Maps the reboot(2) RESTART2 reason string to SM8750 SYSTEM_RESET2 vendor
   reset types … Replaces (until the upstream psci-reboot-mode 13-patch series
   lands) the non-working nvmem-sdam / misc-BCB paths on TB322FC."
:48-49  PSCI_ELDEN_RESET_TYPE_EDL 0x80000000 / PSCI_ELDEN_RESET_TYPE_BOOTLOADER 0x80010001
:58-66  只识别 "edl" 与 "bootloader"，其余 reason 直接 return（落回普通 reset）
```

判据命令：`rg -n 'SYSTEM_RESET2|nvmem-sdam' patches/kernel-history/elden_vk41-psci-reboot/0003-*.patch`

由此得到**两条非常关键的推论**，后面的冗余判定全靠它们：

1. **`reboot2 bootloader` 和 `eldroid-bootctl reboot bootloader` 走的是同一条内核路径**
   （都是 `syscall(__NR_reboot, …, RESTART2, "bootloader")`）：
   - `rootfs/reboot2.c:35-37`
   - `scripts/eldroid-bootctl:154-158` → `_do_reboot(LINUX_REBOOT_CMD_RESTART2, "bootloader")`，`MODE_MAGIC`（`:42`）只用于打印。
   判据：`rg -n 'RESTART2' rootfs/reboot2.c scripts/eldroid-bootctl`
   ⇒ 「谁干净」**不在复位机制上**，只在**卡死有没有兜底**上（见下一条）。
2. **唯一实质差异 = `eldroid-bootctl` 在带 reason 重启前预挂 `sleep 6; echo b > /proc/sysrq-trigger` 看门狗**
   （`scripts/eldroid-bootctl:57-79, 156-158`；`--no-watchdog` 可关，`:215`）；`reboot2` 没有。
   这正好解释 #368 与 #525/#542 是**同一个故障的两种表现**：关机路径卡住 → 无看门狗版本停在
   「gadget 已拆、复位没发」的僵尸态（USB 全不枚举、无串口、只能断电）；有看门狗版本 6 s 后被
   sysrq-b 强制复位，ABL 照常接管（`PITFALLS/sessions/173-…retry.md` §#542 末段：
   「magic 由 nvmem-reboot-mode 的 reboot-notifier 在 kernel_restart() **早期**写进 PMIC SDAM …
   卡死点在其后」—— 该段对机制的描述也停在 SDAM 口径，与 vk41 patch 不一致，属于同族漂移）。

> ⚠️ 因此本报告把「干净」定义为：**带卡死兜底、且失败后主机侧有可观测通道**。
> 单纯比较 reboot 机制会得出错误结论（两者机制相同）。

### 1.1 入口盘点表（分两批落盘；本批 #1–#7）

证据等级：**【实测成功】**= 仓库内有带日期的上机记录且成功；**【实测失败】**= 有带日期的失败记录；
**【无实测】**= 只有注释/推导声称，我没有找到上机证据；**【未证】**= 有间接线索但我无法确认。

| # | 脚本:行 | 机制 | 证据等级 | 干净? | 冗余对象 | 建议 |
|---|---|---|---|---|---|---|
| 1 | `scripts/eldroid-bootctl:57-79,154-158,215` | ① RESTART2 reason → PSCI SYSTEM_RESET2 vendor reset **+ 6 s sysrq-b 看门狗** | **【实测成功】** `PITFALLS #542`（2026-11-07「正常路径 4 s 进 fastboot」，两次卡死后落看门狗）；`#525` 记录卡死本身 | ✅ 干净 | 与 #2/#3 同功能 | **保留 = 唯一推荐入口**（见 §4） |
| 2 | `packaging/elden-userland/files/usr/local/bin/eldroid-bootctl:57`（全文 182 行） | ① 同上但**无看门狗**（`_do_reboot` 少 watchdog 参数；无 `--no-watchdog`） | **【实测失败】** 同文件缺兜底 ⇒ `PITFALLS #525`（2026-11-06 两次卡死）+ `#542` 复现 | ❌ 不干净 | 与 #1 **同功能、已漂移 86 行**（`diff scripts/eldroid-bootctl packaging/elden-userland/files/usr/local/bin/eldroid-bootctl \| wc -l` → 86；sha 不同：`f86d7d2d…` vs `720796d7…`） | **必须先修**：把 #1 同步过去（MANIFEST sha 也要更新），否则重铺设备就退回 #368 形态 |
| 3 | `rootfs/reboot2.c:35-37`（+ `rootfs/build-rootfs.sh:68`、`packaging/elden-userland/build/reboot2.sh`） | ① 裸 RESTART2 reason，**无看门狗、无日志、无 rc** | **【实测失败】** `PITFALLS #368`（2026-10-23 首次；**2026-11-12 长 uptime 6 h 复现**，USB 零枚举、屏不亮、只能断电） | ❌ 不干净（且失败后主机侧零可观测） | 与 #1 同功能 | 降级为 wrapper（`exec eldroid-bootctl reboot "$@"`）或直接标废弃；**至少**禁止在自动化里调用（`n5b`/`arm-window-hunt` 仍用，见 #8/#9） |
| 4 | `scripts/to-fastboot.sh:41`（+ `:45-46` 等待） | ① 经 `$SSH 'sync; eldroid-bootctl reboot bootloader'` → **走 PATH 上的版本** | **【无实测】** 纯 wrapper，无「本轮实测成功」记录；`PITFALLS/sessions/01-…:23` 另有「这类封装脚本代跑 fastboot 在本机故障率高」的经验条目 | ⚠️ 取决于 PATH 上是 #1 还是 #2（**当前 MANIFEST 装的是 #2 ⇒ 实际不干净**） | 与 #1 重复（只是多了等待与 `--flash` 前置） | 保留作唯一包装层，但**加版本门**：`ssh … 'eldroid-bootctl reboot --help 2>&1 \| grep -q -- --no-watchdog' \|\| 拒绝执行` |
| 5 | `cycle.sh:32-36` | ③ misc BCB 写 `bootonce-bootloader` + sysrq-b | **【实测失败】** `cycle.sh:33` 自注「PITFALLS #65：未被 ABL 采纳（2026-10-03 实测）」；`:34` 追加「2026-10-15 实测 … 落 BL 后进 Q28 坏发」；`scripts/bisect/README.md:26` 同口径 | ❌ 失败 | 与 #1 争同一目标 | 删除该分支（或改成打印「请用 to-fastboot.sh」并 exit 2） |
| 6 | `cycle.sh:23` | ④ 裸 sysrq-b（无 reason） | **【实测失败/不适用】** `cycle.sh:24-31` 注释：b-slot 起来后 `reboot -f`/sysrq-b **回 Linux 而非 fastboot**（PITFALLS #288） | ❌ 到不了 fastboot | 与 `--soft` 名义重复 | 把 `--soft` 改名或删，避免「soft reboot -> fastboot」这句假承诺 |
| 7 | `cycle.sh:39` | ⑥ 主机侧 `fastboot reboot bootloader`（需已在 fastboot） | **【无实测】** 是 ABL 内部重进，非 Linux→fastboot；`#525` §3 另记「从 UEFI 侧 fastboot 发 `reboot bootloader` **不会**进 ABL（实测落到 Linux）」⇒ 只能从 ABL 侧用 | ⚠️ 只在已在 ABL 时有意义 | 与 `scripts/bl-unlock.sh:29` 的同类提示重复 | 保留，但注释限定「仅当 `fastboot devices` 已见 ABL」 |

### 1.2 入口盘点表（第二批 #8–#19）

| # | 脚本:行 | 机制 | 证据等级 | 干净? | 冗余对象 | 建议 |
|---|---|---|---|---|---|---|
| 8 | `scripts/n5b-vk64-death-rate.sh:131,167,177` | ① 裸 `reboot2 bootloader`（+ 自己的 SysRq-b 逃生、`uptime≥60s` 门 `:124-129`） | **【实测失败】** 该脚本自己的注释就写着 #368/#369（`:122-123`、`:158-160`）；#368 正文钦定它就是首发现场 | ❌ | 与 #1 同功能 | 3 处 `reboot2` 改 `eldroid-bootctl reboot bootloader`；改完可删 `:168-179` 的手工逃生梯 |
| 9 | `scripts/arm-window-hunt.sh:16,26` | ① 裸 `reboot2 bootloader` | **【实测失败】** `:18` 注释「显示坏态下 reboot2 会挂 DRM cleanup（#253）」 | ❌ | 与 #1 同功能 | 同上改 `eldroid-bootctl`；`:14` 的 `fastboot devices \| grep -q .` 另违 #584 |
| 10 | `scripts/q32-arm.sh:165` | ① `eldroid-bootctl reboot bootloader \|\| reboot bootloader` | **【无实测】** 新写的 A/B 矩阵脚本，未找到上机记录 | ⚠️ 主路径干净，**fallback 不干净** | 与 #1 重复 + 自带危险 fallback | 删 `\|\| reboot bootloader`（busybox reboot = halt+VBUS 自开机，`slot-switch.sh:19-20` 引 PITFALLS #150-152） |
| 11 | `scripts/sd-run-variant.sh:35` | ① 同上，同款 fallback | **【无实测】** | ⚠️ 同 #10 | 同 #10 | 同 #10 |
| 12 | `scripts/slot-switch.sh:96-98` | ① 经 ssh 调 `/usr/local/sbin/eldroid-bootctl` → 失败再调裸名 | **【无实测】**（切槽路径本身有 HANDOFF §20 实测，但**不覆盖**这一步） | ⚠️ 路径写错（包装树装的是 `/usr/local/bin`，见 §3） | 与 #1 同功能 | 改成 `/usr/local/bin/eldroid-bootctl`，并加 watchdog 版本门 |
| 13 | `scripts/to-fastboot.sh` 的使用者：`scripts/uefi-boot-trial.sh:121`、`uefi-r21-sbstop-ladder.sh:225`、`kexec-bs-cycle.sh:14`、`uefi-ddr-trial.sh:34`、`uefi-flashed-trial.sh:165`、`uefi-a-slot-prepare.sh:79`、`uefi-oneshot.sh:40` | ① 各有自己一份 ssh 封装（超时/后台/`nohup` 各不同） | **【无实测】** 多为 UEFI 实验脚本；`uefi-ddr-trial.sh:35` 自己就写「fastboot 没起来（PITFALLS #368，需要物理断电）」 | ⚠️ 取决于 PATH 版本 | **7 份重复实现**（应统一走 `to-fastboot.sh` 或 `lib-boot-ready.sh`） | 合并为一个 `to_fastboot()` 函数（放 `lib-fastboot.sh`/`lib-boot-ready.sh`） |
| 14 | `scripts/uefi-oneshot.sh:32` | ⑥ **从 UEFI 侧** `fastboot -s $UEFI reboot bootloader` | **【实测失败】** `PITFALLS/sessions/173-…` §1 末：「从 UEFI 侧 fastboot 发 `reboot bootloader` **不会**进 ABL（实测落到 Linux）」 | ❌ 明确失败 | 与 #13 争同一目标 | 删这条分支，直接走 `:34-41` 的「回 Linux → eldroid-bootctl」 |
| 15 | `scripts/flash-recovery.sh:55` | ② `eldroid-bootctl reboot recovery`（reason=`recovery`） | **【未证】** 内核 vendor-reset 钩子只认 `edl`/`bootloader`（patch `:58-66`），`recovery` 落回普通 reset；但 DT 仍有 `reboot-mode` 节点（`reports/artifacts/uefi-eud-20261101/live-fdt.dts:9173-9179`，`mode-recovery=0x01`），`nvmem-reboot-mode` 的 notifier 优先级 0 < psci 的 129 ⇒ 理论上会写 SDAM。**未上机验证** | ⚠️ 未证 | 无 | 改用 psci 钩子支持 recovery，或改走 `fastboot reboot recovery`（ABL 侧） |
| 16 | `scripts/bl-unlock.sh:29` | ⑥ 主机侧提示「单条 `fastboot reboot bootloader` 后重试」 | **【无实测】** 提示语，非入口 | — | 与 #7 重复文案 | 保留 |
| 17 | `cycle.sh:39` `--recover` | ⑥ `fastboot reboot bootloader` | 同 #7 | 同 #7 | 同 #7 | 同 #7 |
| 18 | `scripts/q26-recheck.sh:45` | 只打印提示 `/usr/local/sbin/reboot2 bootloader` | **【过时】** 指向无看门狗的 #3 | — | 与 #1 冲突 | 提示改 `eldroid-bootctl reboot bootloader` |
| 19 | `scripts/f2fs-migrate.sh:319` | 只打印提示「先 reboot2 bootloader」 | 同 #18 | — | 同 #18 | 同 #18 |

**盘点结论**：仓库内一共 **19 个入口**（含 7 份 ssh-封装重复 = #13）。其中：
- 机制 ①（RESTART2 → PSCI vendor reset，唯一有效）：**10 行 / 16 个调用点**（#1–#4、#8–#13；#13 一行含 7 个脚本）；机制 ②（SDAM magic）：1 处（#15 未证）；机制 ③（BCB）：1 处（#5 实测失败）；
  机制 ④（裸重启）：2 处（#6、`q32-arm.sh` w2 的 `reboot -f`）；机制 ⑤（EDL）：`eldroid-bootctl reboot edl`（1 处，文中未展开 —— 见 §5）；机制 ⑥（主机侧）：4 处。
- **物理上没有 `flash/*.sh` 目录**（`ls -d flash` → 不存在），任务里的这一项为**空集**。
- 带卡死兜底的入口：**只有 #1 一个**（`scripts/eldroid-bootctl`）。
- 证据等级统计（19 行去重后 18 个实入口）：实测成功 **1**（#1）/ 实测失败 **7**（#2 #3 #5 #6 #8 #9 #14；其中 #2 是「同时期同命令无兜底版」的间接证据，标记为推断）/ 无实测 **7**（#4 #7 #10 #11 #12 #13 #16）/ 未证 **1**（#15）/ 过时提示 **2**（#18 #19）。

判据命令（可复现整张表）：
```
rg -n 'reboot2 bootloader|reboot bootloader|eldroid-bootctl reboot|bootonce-bootloader|sysrq-trigger' \
   scripts/ rootfs/ packaging/ cycle.sh | grep -v '\.log:'
```

---

## §2 冗余与冲突

### 2.1 成对冗余表（谁该活）

| # | 对 A | 对 B | 冲突实态 | 判据 | 谁该活 |
|---|---|---|---|---|---|
| P1 | `scripts/eldroid-bootctl`（246 行，带 watchdog） | `packaging/elden-userland/files/usr/local/bin/eldroid-bootctl`（182 行，无 watchdog） | **同一命令在仓库里两份，且装到设备的是弱的那份** | `diff scripts/eldroid-bootctl packaging/elden-userland/files/usr/local/bin/eldroid-bootctl \| wc -l` → 86；`sha256sum` → `f86d7d2d…` vs `720796d7…`；`grep eldroid-bootctl packaging/elden-userland/MANIFEST.tsv` → sha `720796d7…` = **无 watchdog 版** | **A**。B 必须用 A 覆盖 + 刷 MANIFEST sha（并加一道 drift gate） |
| P2 | `rootfs/reboot2.c`（无兜底） | `scripts/eldroid-bootctl reboot bootloader`（有兜底） | 两者内核路径**完全相同**（§1.0），只差 6 s sysrq-b 看门狗 | `rg -n 'RESTART2' rootfs/reboot2.c scripts/eldroid-bootctl` | **B**。reboot2 降为 wrapper 或标废弃 |
| P3 | `scripts/to-fastboot.sh:4-7`（「BCB 不被 ABL 采纳，PSCI 是 working path」） | `cycle.sh:32-36`（仍在推 `--fastboot` = misc BCB） | 同一仓库两种口径；**`to-fastboot.sh` 与 `bisect/README.md:26` 一致，`cycle.sh` 是孤岛** | `rg -n 'bootonce-bootloader' scripts/ cycle.sh` | **A（to-fastboot）**。`cycle.sh` 的 `--fastboot` 分支应删（只留告警） |
| P4 | `cycle.sh:23` `--soft`（sysrq-b，注释却写 `-> fastboot`） | `cycle.sh:32` `--fastboot` | 两个分支都到不了 fastboot，但都叫「进 fastboot」 | `sed -n '23,36p' cycle.sh` | 两个都死；保留 `--wait/--dtbo/<img>`，进 fastboot 统一交 `to-fastboot.sh` |
| P5 | `scripts/slot-attr.py`（== `packaging/…/**bin**/slot-attr.py`，`1d433236…`，11011 B） | `packaging/…/**sbin**/slot-attr.py`（`33a11eef…`，10905 B，**旧变体**） | 同名工具装两个目录且内容不同；**在用脚本走的是 sbin 那份**（`scripts/trial.sh:55,58`、`scripts/fix-ab-mark-successful.sh:47`）⇒ `--dry-run` 在子命令前失效（见 S16） | `grep slot-attr packaging/elden-userland/MANIFEST.tsv`（`:34` bin、`:67` sbin）；`diff scripts/slot-attr.py packaging/elden-userland/files/usr/local/sbin/slot-attr.py` → 5 行差，正是 `default=argparse.SUPPRESS` 那行 | 只留 `/usr/local/bin/slot-attr.py`（= 权威源）；sbin 那份删并把在用脚本改路径 |
| P6 | `rootfs/usb-gadget:37-45`（动态 SN，`#549` 已修） | `packaging/…/files/usr/local/sbin/usb-gadget:41`（写死 `HA2CB1KY`） | **MANIFEST 装的是写死版**（sha `7c70e2b9…` = packaging 那份）⇒ 重铺设备就复发「认错设备（误把华为手机当目标板）」 | `sha256sum rootfs/usb-gadget packaging/elden-userland/files/usr/local/sbin/usb-gadget` + `grep usb-gadget …/MANIFEST.tsv` | **rootfs 那份**。packaging 副本必须回灌 |
| P7 | `scripts/lib-wait.sh`（统一等待层，2026-11-05 审计产物） | 各脚本内联等待循环：`uefi-ddr-trial.sh:26-27`、`uefi-oneshot.sh:19-26`、`n5b-vk64-death-rate.sh:161`、`q28-por-rounds.sh:61-67`、`arm-window-hunt.sh:14,17,20-27`、`sd-run-variant.sh:39-45` | 审计只落了 4 个脚本（`to-fastboot`/`cycle`/`slot-switch`/`flash-b`），其余未收口；且内联版本大量违 #584（管道） | `rg -n 'fastboot devices .*\| *grep' scripts/` | **lib-wait.sh**；内联循环逐个替换 |
| P8 | `scripts/lib-device-lock.sh`（单一来源） | `scripts/device-lock.sh:37` 先 `printf … > "$LOCK"` 再 `:42` 调 `device_lock_acquire` | **顺序 bug**：等锁的 agent 会在**等之前**把 holder 信息覆写成自己的 → `--status` 告的 holder 是「最后排队的人」（且 `$LOCK` 被 truncate） | `sed -n '36,43p' scripts/device-lock.sh` | 保留 lib；把 holder 写入移到 `device_lock_acquire` **之后** |
| P9 | `eldroid-bootctl:60-66` 文档串（reason magic 由 `nvmem-reboot-mode` 写 PMIC SDAM） | kernel patch（RESTART2 → PSCI `SYSTEM_RESET2`） | **机制描述与自家实测结论相反**：`TASKS/README.md:1070` 明写「PMIC SDAM `reboot-reason@48`、`misc` BCB **均不被 ABL 采纳**；PSCI SYSTEM_RESET2 被采纳」 | `rg -n 'SDAM' scripts/eldroid-bootctl TASKS/README.md` | 改文档串（不改代码）；否则审阅者会沿错误机制找 bug |
| P10 | `rootfs/persistent-overlay/q28-boot-watchdog.sh` | `packaging/…/files/usr/local/sbin/q28-boot-watchdog.sh` | 两份**完全一致**（`709e9eb8…`）⇒ 当前无漂移，但属于「同一文件的镜像副本」，无法阻止下次单边修改 | `sha256sum` 二者 | 保留，但应改为构建期从 `rootfs/` 拷贝（同 P1/P6 同一种病） |
| P11 | `scripts/lib-ssh.sh:27-29`（自称「设备 SSH 调用的单一实现」） | `scripts/lib-fastboot.sh:62-75` `sshc()`（同样自称唯一 ssh 封装） | **两个「单一实现」并存且选项不同**：`lib-ssh` 用 `ConnectTimeout=5` 且**无** `ServerAlive*`（#585 已建立连接卡 tcp_retries2 的病因仍在）；`sshc` 有 `ServerAliveInterval=5 CountMax=2` | `diff <(rg -n 'ConnectTimeout' scripts/lib-ssh.sh) <(rg -n 'ConnectTimeout' scripts/lib-fastboot.sh)`；`rg -n 'ServerAlive' scripts/lib-ssh.sh scripts/lib-fastboot.sh` | **lib-fastboot.sh `sshc`**（唯一带 #585 修复）；`lib-ssh.sh` 成为它的别名层 |

### 2.2 「注释说 A，代码还在用 B」的漂移点（专列）

1. **`to-fastboot.sh:6-7` 说 working path 是 `eldroid-bootctl`**，但 `:41` 调的是 **PATH 上的** `eldroid-bootctl` ——而 MANIFEST 装的正是无 watchdog 版（P1）⇒ **注释在理，运行时不在理**。
2. **`slot-switch.sh:19` 说「不用 `reboot bootloader`」**，`:98` 却回退到 `/usr/local/sbin/eldroid-bootctl`（该路径在包装树里不存在，见 P5 同源问题）再回退裸名。
3. **`slot-switch.sh:19-20` 与 `q32-arm.sh:165` / `sd-run-variant.sh:35` 相矛盾**：前二者引 PITFALLS #150-152 说裸 `reboot bootloader` 在 OpenRC 下变「halt + VBUS 自开机」，后二者却把它写成 fallback。
4. **`cycle.sh:24-27` 的注释早已判定 `reboot -f` 回 Linux**，但 `q32-arm.sh:170-173` 的 W2 臂仍用 `reboot -f` 当「暖复位」基准（该臂测的就是「暖复位会不会回 Linux」，属有意为之，但注释未说明与 #288 的关系）。
5. **`scripts/lib-boot-ready.sh` 是为 #143/#368 专门写的「复位前就绪门」（`uptime>=90 s` + `phoc`/`phosh` 在跑，fail-closed），但 18 个实入口里只有 `q32-arm.sh` 用了它** —— 包括**推荐入口 `to-fastboot.sh` 自己也没用**（它只 source 了 `lib-device-lock.sh` 与 `lib-wait.sh`）。判据：`rg -ln 'boot_ready_or_die' scripts/` → 只有 `q32-arm.sh`。
   ⇒ 这是「纪律写了、闸门也造好了，但主线入口没接」的典型漂移；#368 的「下发前无法预判」其实在主机侧有一个可用门（见 §4 前置门 2）。

6. **`packaging/elden-userland/sources.tsv:16` 把 `reboot2` 描述成「Linux→fastboot 的**可靠入口**」**
   —— 这与 `PITFALLS #368`（2026-10-23 + 2026-11-12 两次 USB 全不枚举）**正面冲突**，
   而 `DEVICE/README.md:68` / `RUNBOOK-BRINGUP/README.md:420-421` / `TASKS/README.md:46,159` 的现行口径是
   `eldroid-bootctl`。判据：`sed -n '16p' packaging/elden-userland/sources.tsv`。
   这是全仓最危险的一句注释：**它把已被实测否定 2 次的入口称为可靠入口**。

> 计数：成对冗余 **11 组**（P1–P11），其中 **P1/P5/P6** 属同一病（包装树是快照、静默腐化），**P7/P11** 属同一病（统一层只落了一半）。

---

## §3 其它脚本的过时缺陷

分类：**FATAL** = 能让通道断/设备丢且无告警；**REDUNDANT** = 重复实现/漂移；**STALE** = 注释或默认值已过期。

| # | 文件:行 | 问题 | 判据命令 | 建议 | 档 |
|---|---|---|---|---|---|
| S1 | `scripts/uefi-oneshot.sh:23,29,30,45,60` | `timeout 6 fastboot devices \| grep -q …` —— **直接违 PITFALLS #584**（SIGPIPE 打断 bulk 通道 ⇒ 只能物理 POR） | `rg -n 'fastboot devices .*\|' scripts/uefi-oneshot.sh` | 改成 `d=$(timeout 6 fastboot devices 2>/dev/null)` 再 `case "$d" in *SN*)` | **FATAL** |
| S2 | `scripts/arm-window-hunt.sh:14` | `fastboot devices 2>/dev/null \| grep -q .` —— 同 #584。而这个脚本的卖点恰恰是「判据只依赖串口（SSH 挂了也能跑）」 | `rg -n 'fastboot devices .*\|' scripts/arm-window-hunt.sh` | 同 S1 | **FATAL** |
| S3 | `scripts/uefi-ddr-trial.sh:26` | `timeout 5 fastboot devices \| grep -q .` —— 同 #584 | `rg -n 'fastboot devices .*\|' scripts/uefi-ddr-trial.sh` | 同 S1 | **FATAL** |
| S4 | `scripts/kexec-bs-cycle.sh:14-15` | 先 `eldroid-bootctl reboot bootloader`、**2 s 后再发 sysrq-b**：两个复位请求叠加在同一个关机窗口里，正好落在 #368 的症状区（且无任何等待/判定） | `sed -n '13,16p' scripts/kexec-bs-cycle.sh` | 只保留一个（推荐 eldroid-bootctl，其内部已有 6 s 看门狗） | **FATAL** |
| S5 | `scripts/q32-arm.sh:165`、`scripts/sd-run-variant.sh:35` | `eldroid-bootctl reboot bootloader 2>/dev/null \|\| reboot bootloader`：fallback 是 **busybox reboot**（无 reason），`slot-switch.sh:19-20` 引 PITFALLS #150-152 说是「halt + VBUS 自开机」 | `rg -n 'reboot bootloader' scripts/q32-arm.sh scripts/sd-run-variant.sh` | 删 fallback；失败就报错停手 | **FATAL** |
| S6 | `packaging/elden-userland/files/usr/local/sbin/usb-gadget:41` | SN 写死 `HA2CB1KY`（真实 `HA2EXB0E`）；`rootfs/usb-gadget:37-45` 已改动态取值。**MANIFEST 装的仍是写死版**（P6） | `sed -n '37,45p' rootfs/usb-gadget; sed -n '41p' packaging/elden-userland/files/usr/local/sbin/usb-gadget` | 回灌 rootfs 版 + 刷 MANIFEST sha | **FATAL** |
| S7 | `scripts/uefi-oneshot.sh:12-13`；`scripts/switch-kernel-abi.sh:49` | 写死序列号：`ABL_SERIAL:-HA2EXB0E`、`UEFI_SERIAL:-51318dc0`；`FB_PRESENT()` 硬 grep `HA2EXB0E` —— 同型号多台机（U1/U2）等价原则下，换机即误判 | `rg -n 'HA2EXB0E|51318dc0' scripts/` | 改为 `SER=${SER:?}` 必填 + `TABLET_PRODUCT_MATCH`（照抄 `slot-switch.sh:38-63` 的做法） | **REDUNDANT** |
| S8 | `scripts/kexec-bs-cycle.sh:9`、`scripts/arm-window-hunt.sh:10`、`scripts/slotboot-run.sh:10`、`scripts/uefi-oneshot.sh:40` | IP 字面量写死且**不可用 TAB/TABLET 覆盖**（其余 40+ 脚本都是 `${TAB:-…}`） | `rg -n 'root@192\.168\.7\.1' scripts/*.sh \| grep -v 'TAB'` | 统一 `${TAB:-root@192.168.7.1}` | **STALE** |
| S9 | `scripts/slotboot-run.sh:8` | `cd /home/xuqianhui/y700-elden`（写死绝对路径 + 写死用户 home），与全仓 `$(cd "$(dirname "$0")/.." && pwd)` 惯例不一致 | `sed -n '7,10p' scripts/slotboot-run.sh` | 改 `ROOT=$(cd "$(dirname "$0")/.." && pwd)` | **STALE** |
| S10 | `scripts/flash-b.sh:19`（`out/boot-elden-vk40.img`）、`scripts/q28-por-rounds.sh:27`（`out/boot-elden-vk152.img`）、`scripts/uefi-oneshot.sh:15-16`（`out/r21-sbstop-p20/uefi-preamble20-r1.img`、`out/real-ladder/real-vs$ST.img`）、`scripts/kexec-bs-cycle.sh:10`（`out/boot-elden-vk69.img`）、`scripts/flash-recovery.sh:16`（`twrp/twrp.img`） | **默认输入已不存在**：`out/boot-elden-vk40.img`/`vk152`/`vk69` 无、`out/r21-sbstop-p20/` 无、`out/real-ladder/` 无、`twrp/` 目录无 ⇒ 无参数调用必失败（部分脚本有 `-f` 检查报错，`flash-b.sh` 是先 sign 后失败） | `for p in out/boot-elden-vk40.img out/boot-elden-vk152.img out/real-ladder out/r21-sbstop-p20 twrp; do [ -e "$p" ] \|\| echo MISSING $p; done` | 默认值改为「必填参数 + 不得有默认」或指向当前在账 vk（`versions/vk-registry.tsv`） | **STALE** |
| S11 | `scripts/kexec-bs-cycle.sh:2` | 头部口径「因 RESTART2 reboot-mode 通路被我们 kexec 测写坏」—— 与 `TASKS/README.md:46`（vk47clean 上 `reboot2 bootloader` 22 s 进 fastboot 实测）和 `#542`（4 s 进 fastboot）矛盾；且该结论无指针 | `sed -n '1,3p' scripts/kexec-bs-cycle.sh` | 删/改这半句（kexec 不可用是 #154 的 `device_shutdown()`，与 restart 通路无关） | **STALE** |
| S12 | `scripts/eldroid-bootctl:60-66` | 机制文档串写「reason magic 由 `nvmem-reboot-mode` …… 写进 PMIC SDAM」—— 与 kernel patch（PSCI `SYSTEM_RESET2`）和 `TASKS/README.md:1070`（SDAM **不被 ABL 采纳**）双重矛盾 | `rg -n 'SDAM' scripts/eldroid-bootctl TASKS/README.md` | 改文档串（P9） | **STALE** |
| S13 | `scripts/slot-switch.sh:98` | 调 `/usr/local/sbin/eldroid-bootctl`，而 MANIFEST 装的是 `/usr/local/bin/eldroid-bootctl`（P5 同族）⇒ 总是走 `\|\|` 的第二个分支，等于白写一条 | `grep eldroid-bootctl packaging/elden-userland/MANIFEST.tsv` | 改 `/usr/local/bin/` | **REDUNDANT** |
| S14 | `scripts/device-lock.sh:37` vs `:42` | **先在等锁前就把 holder 信息写入 `$LOCK`**（并 truncate），后调 `device_lock_acquire` ⇒ `--status` 会把「最后排队的人」当成 holder；并发时信息不可信 | `sed -n '36,43p' scripts/device-lock.sh` | 把 `printf holder` 移到 `device_lock_acquire` 之后 | **REDUNDANT** |
| S15 | 模块部署三套：`scripts/mod-loop.sh:73`（tar 管道 `lib/modules/$KV`）、`scripts/m1-73-modules-overlay.sh:20-31`（只拷 2 个 `.ko` 到 overlay）、`scripts/deploy-camera-modules.sh` | 同一动作（把 `.ko` 弄到设备 `/lib/modules/<UTS>`）三种实现，UTS 目录推导与校验各不相同；项目记忆里的「必须先部署 1497 个 .ko 否则 defer」是硬约束 | `rg -n 'lib/modules/\$KV|lib/modules/\$1' scripts/mod-loop.sh scripts/m1-73-modules-overlay.sh` | 合成一个 `deploy-modules.sh --from <build树> --uts <UTS>`，其余变参数调用 | **REDUNDANT** |
| S16 | `packaging/elden-userland/files/usr/local/sbin/slot-attr.py:238`（`common.add_argument("--dry-run", action="store_true")`，缺 `default=argparse.SUPPRESS`） | **`--dry-run` 放在子命令之前时被子解析器默认值覆盖成真写**（argparse bpo-9351 形态）：只有 `set … --dry-run` 才生效。而仓库里的示范写法恰好是坏的那种：`archive/topics/GPT槽位元数据-2026-09-30.md:91` = `slot-attr.py --dry-run set b --retry 7` ⇒ **会真写 GPT**。权威源 `scripts/slot-attr.py:239` 已加 `default=argparse.SUPPRESS` 修掉。用到的脚本：`scripts/trial.sh:55,58`、`scripts/fix-ab-mark-successful.sh:47` | 最小复现（不碰设备，已实测）：父/子各注册一次 `--dry-run`（不用 SUPPRESS）时 `["--dry-run","set"]` → `dry_run=False`、`["set","--dry-run"]` → `True`；子解析器用 `default=argparse.SUPPRESS` 后两种顺序都 `True` | 用 `scripts/slot-attr.py` 覆盖 sbin 那份（或删），并修 `trial.sh`/`fix-ab-mark-successful.sh` 的路径 | **FATAL（已本地证实）** |

统计：**FATAL 7 / REDUNDANT 5 / STALE 5**（合计 17 条，不含 §2 的 11 组成对冗余）。

---

## §4 建议的统一口径

### 4.1 唯一推荐入口（一句话）

> **`scripts/to-fastboot.sh`（内部只允许 `eldroid-bootctl reboot bootloader`，且该二进制必须是带
> 6 s sysrq-b 看门狗的版本 —— 即 `scripts/eldroid-bootctl` f86d7d2d…）**

理由（按证据粒度，不超一条）：
1. 机制 ①（RESTART2 → PSCI `SYSTEM_RESET2` vendor reset）是唯一被 ABL 采纳的路径
   （`TASKS/README.md:1070` 实测否定 SDAM/BCB；patch `:11-15`）；
2. 同一命令的失败模式已被两次独立记录为「关机路径卡死」，而看门狗是唯一能把卡死变成「仍落在
   fastboot」的机制（`PITFALLS #525` → `#542`，2026-11-07 实测 4 s 进 fastboot）；
3. `to-fastboot.sh` 已经是文档钦定入口（`RUNBOOK-BRINGUP/README.md:420-421`、`DEVICE/README.md:68`），
   且它自己是 `device_lock` 的持有者（`:21-22`），并发安全。

**前置门（缺一不可，建议写进 `to-fastboot.sh`）**：
```
# 0) 就绪门：仓库已有现成的
. "$(dirname "$0")/lib-boot-ready.sh"; boot_ready_or_die   # uptime>=90s + phoc/phosh
# 1) 版本门：没看门狗就拒绝
ssh $TAB 'eldroid-bootctl reboot --help 2>&1 | grep -q -- --no-watchdog' \
  || { echo "device has stale eldroid-bootctl (no watchdog) — PITFALLS #368"; exit 3; }
# 2) sysrq 门：（eldroid-bootctl 自己会打印警告，但它只警告不失败）
ssh $TAB '[ "$(cat /proc/sys/kernel/sysrq)" != 0 ]'
```

**失败后主机侧有没有可观测通道？有，三层（全在主机侧，不需要设备配合）**：
- **L1（10 s 内）**：`fastboot devices` 出现目标 SN ⇒ 成功（判活**永不接管道**，`d=$(timeout N fastboot devices)`，`PITFALLS #584`）；
- **L2（±20 s）**：`journalctl -k` 里的 USB 事件 —— 看门狗复位后会先出 `18d1:*`（ABL gadget）
  再切 `1d6b:0104`（Linux gadget）；只看到前者 = 又进了 ABL 而没进 fastboot；
- **L3（终局）**：`lsusb` 全量 + `/dev/ttyACM*` + `ssh uptime`。三者全空 ⇒ 设备彻底没了，**停**。

判据参考：#391（`fastboot boot` 后 USB 会变 `1d6b:0104` 且慢枚举 60–90 s，按 VID 白名单判活会误判硬挂）、
#413（全静默时「磁盘 /init 坏 / rescue / SoC 硬挂」在主机侧不可区分）。

### 4.2 失败判据 / 停手规则（建议直接照抄成纪律）

1. **停手判据（参考 #368 + #391）**：发出进 fastboot 命令后 **25 s** 内，
   `d=$(timeout 8 fastboot devices 2>/dev/null)` 为空 **且** `lsusb` 无 `18d1:`/`05c6:`/`1d6b:` **且**
   `ssh root@192.168.7.1 uptime` 不通 ⇒ 判「USB 全不枚举 + 无串口」= **停**。
   不重试、不换现场、不跑第二条重启命令（重试只会多一个僵尸态实例）。
2. **重试上限 1+1**：同一会话内同一个入口最多发 2 次；第 2 次不通 ⇒ 请用户**物理断电**
   （`#368` 明确：三件套全空 = 只能人工断电，EDL 也不会出现）。
3. **不在以下状态发**：`uptime < 60 s`；`phoc` 不在；无 `device_lock`；用户不在场（#368 2026-11-12 补充：
   「下发前无法预判 ⇒ 当有物理依赖的动作、用户在场时做」）。
4. **把 `reboot2 bootloader` 全部改为 `eldroid-bootctl reboot bootloader`**（含 `n5b`、`arm-window-hunt`），
   否则每修好一次就再撞一次。

### 4.3 建议的收敛顺序（改动最小的先做）

| 顺 | 动作 | 影响文件 | 验证方式（无需设备） |
|---|---|---|---|
| 1 | `packaging/…/files/usr/local/bin/eldroid-bootctl` ← `scripts/eldroid-bootctl` + 刷 MANIFEST sha | 2 | `diff` 为空 + `sha256sum` 对齐 MANIFEST |
| 2 | `packaging/…/sbin/usb-gadget` ← `rootfs/usb-gadget` + 刷 MANIFEST sha | 2 | `grep -c HA2CB1KY` = 0 |
| 3 | 删 `cycle.sh --fastboot` 分支；`--soft` 改名或删 | 1 | `bash -n cycle.sh` |
| 4 | 删 `q32-arm/sd-run-variant` 的 `\|\| reboot bootloader` fallback；3 处 #584 管道 | 5 | `rg 'fastboot devices .*\|' scripts/` = 0 |
| 5 | 把 `reboot2` / `script/slot-*` / UEFI 系列统一到 `to_fastboot()`；`reboot2` 成为 wrapper | ~10 | `rg -n 'reboot2 bootloader' scripts/` 只剩 wrapper 内部 |
| 6 | 加一条 doctor 门：`scripts/check-doctor.sh` 里校「`scripts/X` 与 `packaging/…/files/…/X` sha 一致」 | 1 | `scripts/check-doctor.sh` FAIL=0 |

> 第 1、2 两条是**同一个病**（包装树是快照、静默腐化），建议合成一条 doctor 门一次性防回归。

---

## §5 未证 / 盲区

以下我**没有**确认，不混进上面的结论：

1. **设备上现在到底是哪份 `eldroid-bootctl`**（带不带看门狗）—— 我未碰设备。
   * 线索指向矛盾：`MANIFEST.tsv` 装的是无看门狗版（sha `720796d7…`），但 `PITFALLS #542` 与
     `DEVICE/README.md:68` 都说「设备侧已同步带看门狗版」。
   * 验证方法（需设备）：`ssh root@192.168.7.1 'eldroid-bootctl reboot --help | grep -- --no-watchdog; sha256sum /usr/local/bin/eldroid-bootctl'`。
2. **#368 与 #525 是否同一根因**（我给出的是「同一关机卡死，只差看门狗」的推断）。
   * 支持：两者症状都是「SSH 断 + 屏不动/不亮 + USB 无重枚举 + 只能断电」；
   * 未证：没有一次对照实验（同一镜像上交替发 `reboot2` / `eldroid-bootctl` 各 N 次，并抓串口）。
   * 反证路径：若带上看门狗的 `eldroid-bootctl` 也出现过「USB 全不枚举且屏不亮」的终态，
     则「只差看门狗」不成立（现有记录里 `#525` 的卡死最终都被挽回到 fastboot，未见该终态）。
3. **`eldroid-bootctl reboot recovery` 能不能进 recovery**（#15）。理论路径是 `nvmem-reboot-mode`
   （优先级 0，在 psci 的 129 之后）写 SDAM `0x01`，但 **ABL 是否采纳 SDAM recovery magic 本身有反例**
   （`TASKS/README.md:1070`：SDAM/BCB 「均不被 ABL 采纳」）⇒ 极可能不工作。需一次上机（写 recovery 分区后试）。
4. **`reboot edl` 真机未验**：`TASKS/README.md:1070` 明写「真机 9008 触发未验（需用户同意）」。
   本次审计不重复该结论，只标注它仍是「未证」。
5. **包装树漂移面可能更大**：我只比对了 `eldroid-bootctl`、`usb-gadget`、`q28-boot-watchdog.sh`、
   `slot-attr.py` 四个文件。已跑过的 **MANIFEST 自校验是干净的**（MANIFEST 的 sha 与 `files/` 下实现逐条相符，
   0 DRIFT）—— 说明问题不在「创建快照时算错」，而在「`files/` 与仓库权威源（`scripts/`、`rootfs/`）
   之间**没有声明映射**」，所以快照会随时间单边变旧。
   后续可用的对比命令（对四个已知对）：
   ```bash
   for p in "scripts/eldroid-bootctl packaging/elden-userland/files/usr/local/bin/eldroid-bootctl" \
            "rootfs/usb-gadget packaging/elden-userland/files/usr/local/sbin/usb-gadget"; do
     set -- $p; cmp -s "$1" "$2" && echo "SAME $1" || echo "DIFF $1"; done
   ```
   （当前结果：两条都 DIFF。）真要防回归，应先在 `sources.tsv`-同类表里补"权威源 → packaging 路径"一列。
6. **`rootfs/build-rootfs.sh` 与 `packaging/` 是两个独立的安装器**（一个编 `reboot2`、不装 `eldroid-bootctl`；
   一个装 `eldroid-bootctl`、不编 `reboot2`）—— 这解释了为何两份副本会各自腐化，但我**没有**逐条比完
   两者最终产物集（哪一份是设备上真实的文件集），只能确定它们**不等价**。
7. **`flash/*.sh` 不存在**（`ls -d flash` 空）；`packaging/` 下也没有以 `.sh` 结尾的设备入口（只有 build/tools 辅助）。
   任务里列的这两项为空集，不是我漏查。
8. **机制优先级判读**（psci 129 > nvmem 0）来自阅读 `build/daily/drivers/firmware/psci/psci.c:370-373`
   与 `build/daily/drivers/power/reset/reboot-mode.c:214-215`，**未**在设备上验过 ``/proc/kallsyms`` 注册顺序；
   但 `reboot` notifier 是按 priority 降序调用，这是内核框架固定行为。
9. **本次全为只读**：未跑任何会写设备/仓库的命令，`check-doctor` 等门也未重新跑。

---

报告结束。共：**入口 19 个**、**成对冗余 11 组**、**其它过时缺陷 17 条**（FATAL 7 / REDUNDANT 5 / STALE 5）。
