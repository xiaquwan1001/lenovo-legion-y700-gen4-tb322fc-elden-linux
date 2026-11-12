# 脚本清理审计（2026-11-12，只读）

> 范围：`scripts/`（250 个入口 + `scripts/doctor/` 15 个子门）、`packaging/elden-userland/`（`files/` +
> `MANIFEST.tsv` + `sources.tsv` + `services.tsv`）、`tools/` 顶层。
> 性质：**只读审计**。本轮未改任何脚本、未碰设备（无 adb/fastboot/ssh）、未 `git commit`、
> 唯一写入 = 本文件。
> 先读过的既有结论（本文件**不重复**它们的条目，只做增量与「仍未修」复核）：
> `reports/script-redundancy-audit-20261112.md`（11 组成对冗余 P1–P11 / 17 条缺陷 S1–S16，已修 6）、
> `reports/script-tidy-20261106.md`（§3 五个家族定性为「不重复」+ 留了「`build/` 旧树名引用清扫」待办）、
> `reports/script-audit-20261105.md`（doctor 拆门 + `lib-wait`/`lib-ssh` 统一层）、
> `PITFALLS/sessions/06-脚本工具.md`、`15-过时废弃功能缺陷登记.md`、`282-打包副本与权威源漂移.md`（#627）、
> `TASKS/README.md` §4「进 fastboot 的唯一入口 + 停手判据」。

---

## §0 结论先行

1. **两处 P0 漏网仍在（与 `#627`/`#584` 同族，本轮新命中）**：
   ① `packaging/elden-userland/files/usr/local/sbin/ath12k-load.sh` **仍然被 MANIFEST 装机，但全仓无任何调用点**
   （只 `ath12k-retry.sh` 进了 `initramfs/init:634` + `services.tsv:41`），且它的 re-bind 写的是**设备路径**而
   sysfs `driver/bind` 要的是**设备名**（同仓 `ath12k-retry.sh:50-51` 的 NOTE + `:51` 的正确写法明写此事）⇒ 它一旦被手工调用必然
   静默失败（`2>/dev/null`）——**P0**；
   ② `scripts/arm-console-run.sh:14` 与 `scripts/trial.sh:186` 仍在用 `fastboot devices | grep -q .`
   （#584 SIGPIPE 打断 bulk 通道 ⇒ 只能物理 POR）。#627 只修了 `arm-window-hunt`/`uefi-ddr-trial` 两处，
   **同一判据在另外两个入口漏网**——**P0**。
2. **`build/` 旧树名漂移是全仓最大的一类过时（28 处不存在的 `build/<名>` 引用 / 17 个文件）**，其中
   **`scripts/kbuild-sanity.sh:26` 是硬赋值 `KDIR=${ROOT}/build/m1-73`（树已不存在），而文档给的用法
   `scripts/kbuild-sanity.sh --rounds 3` 不带位置参数**（`reports/t9-vk130-pcie-l2-live-20261021.md:16`）
   ⇒ 主机位翻转防护门在默认用法下对不存在的树做检查。——本轮新查（正是 11-06 那轮留下的待办 §5.4）。
3. **`lib-ssh`/`lib-wait` 统一层只落了 10%：61 个脚本自带内联 `ssh -o …`，只有 6 个 source
   `lib-ssh.sh`/`lib-fastboot.sh`；`lib-wait.sh` 只有 5 个调用者；内联 `fastboot devices` 轮询点 35 处。**
   ⇒ #584 类误判与「不带 BatchMode 卡在密码提示」的根因没有被关闭，只是逐点打补丁。
4. **权威文档指向已被实测否定的实现（P1）**：`DEVICE/README.md:123` 把 `scripts/serial-logger.sh` 写成
   「主机串口 logger」现役入口，而 `PITFALLS #622`（`PITFALLS/README.md:316`）与
   `scripts/serial-tap.py:2-6` 自述都判定它会 **open/close 狂抖**、真数据一行不留 ⇒ 按文档做取证会得到
   「没有 panic」的假阴性。
5. **仍在用的设备侧脚本还在发已停用的 `reboot2 bootloader`**：`scripts/n5b-vk64-death-rate.sh:131`
   （`TASKS` §4 已写「`reboot2 bootloader` 停用」）。
6. **A/B 槽位三套实现并存且其中一套已随换根失效**：`scripts/fix-ab-mark-successful.sh` 是
   Alpine/OpenRC 专用（`/etc/init.d/qbootctl` + `rc-update`），现役 Debian/systemd 根上第一步就 `exit 1`；
   它同时引用 P5 判定要删的 `/usr/local/sbin/slot-attr.py`（`:47`）。
7. **可安全删除 = 0 个**：本轮用「`*.md` 排除 archive/HISTORY + scripts/packaging/tools 命中数」双查，
   `scripts/` 下**没有任何入口达到 0 引用**（与 11-06 那轮 `UNREFERENCED=0` 一致）。
   所以清理动作以「**加 RETIRED 头 / 合并 / 修默认值**」为主，不是删除（见 §4）。
8. 汇总：**§1 冗余 13 行**（P0 2 / P1 4 / P2 4 / 明确「不合并」3）、**§2 过时 12 条**
   （P1 5 / P2 6 / 负结论 1，覆盖 28 处 `build/*` 死引用 + 11 个漏账脚本等）、**§3 仍未修缺陷 12 条**（P0 2 / P1 4 / P2 6）。

判据可整表复现的命令在每行「证据命令」列；本审计用的扫描一律限定路径
（`scripts/` `packaging/elden-userland/` `tools/` `rootfs/` `initramfs/` + `--glob '*.md'`），未跑全仓 `rg`。

---

## §1 表一：冗余（多脚本同事）

> 判定口径：**真源** = 唯一该被调用的实现；**包装** = 只是转发/差参数；**可合并** = 删除后语义无损。
> 「不可合并」也要写，避免下一轮重新怀疑（11-06 §3 已定性的家族在此只补证据，不重开）。

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P0** | `scripts/ath12k-load.sh:36` + `packaging/elden-userland/MANIFEST.tsv:40` | **两个脚本干同一件事（重新 bind ath12k PCI 让 phy0 出现），只有 retry 那份被接线**；`ath12k-load.sh` 被 MANIFEST 装到 `/usr/local/sbin/`、被 `build-rootfs.sh:73` 拷进根，但**没有任何服务/init 调它**；并且它 `:36` 的 `echo "$DEV" > "$DRV/bind"` 写的是**路径**，`ath12k-retry.sh:50-51` 的 NOTE 明写「`bind` 吃的是 *device name*，不是 path」且 `:51` 写的是 `$DEVNAME`⇒ 真被调用时 `2>/dev/null` 吞掉、恒不生效 | `rg -n 'ath12k-load' scripts/ rootfs/ initramfs/ packaging/ \| grep -v 'MANIFEST\|sync-from-device\|STATE.txt\|build-rootfs\|^scripts/ath12k-load.sh:'` → **只有两份副本自身的 echo 行，零调用点**；接线证据 `rg -n 'ath12k-retry' initramfs/init packaging/elden-userland/services.tsv` → `init:634` + `services.tsv:41`；语义差 `sed -n '34,36p' scripts/ath12k-load.sh` vs `sed -n '48,52p' scripts/ath12k-retry.sh` | 真源 = **`scripts/ath12k-retry.sh`**（唯一被 init + systemd unit 调用）。`scripts/ath12k-load.sh` **加退役头**（首行注释替换为 `# ⛔ RETIRED 2026-11-12：职责由 scripts/ath12k-retry.sh 承担（唯一被 initramfs/init:634 与 services.tsv:41 接线）。本脚本 bind 写的是设备路径而非设备名 ⇒ 恒不生效（见 ath12k-retry.sh:50-51 NOTE）。保留仅作历史参考。`），并从 `MANIFEST.tsv` 第 40 行与 `rootfs/build-rootfs.sh:73` 的拷贝名单里去掉这一项（**先证 0 引用，见 §4 D1**） |
| **P0** | `scripts/arm-console-run.sh:14`、`scripts/trial.sh:186` | #584 同类**仍未修**：`fastboot devices 2>/dev/null \| grep -q .`（`grep -q` 提前退出把 SIGPIPE 送回 fastboot ⇒ bulk 通道被打断，只能物理 POR）。#627 只修了 `arm-window-hunt.sh:14`、`uefi-ddr-trial.sh:26` 两处 | `rg -n '(fastboot\|adb)[^|]*\| *(grep\|head\|wc)' scripts/ packaging/ tools/ rootfs/` → 只剩这两条实代码 + 4 条注释 | 两处统一替换为（照 `scripts/lib-wait.sh:85` 的口径）：<br>`_fb=$(timeout 8 fastboot devices 2>/dev/null)`<br>`case "$_fb" in *"$SER"*) : ;; *) echo "[arm] ❌ 设备不在 fastboot" >&2; exit 2 ;; esac`<br>（`trial.sh` 同样先取值再 `case`；顺带把 SN 从硬编码改成 `SER=${SER:?}`） |
| P1 | `scripts/n5b-vk64-death-rate.sh:131`（同族 `:167`、`:177` 的 sysrq 逃生梯） | 现役采样脚本仍发**已停用**的 `reboot2 bootloader`（无 6 s sysrq-b 看门狗）。`TASKS/README.md` §4 已写「**只允许 `scripts/to-fastboot.sh`**……`reboot2 bootloader` 停用」 | `rg -n "SSH 'reboot2 bootloader'" scripts/` → 1 命中；口径 `rg -n 'reboot2 bootloader.停用' TASKS/README.md` | `sed -i "s\|SSH 'reboot2 bootloader' >/dev/null 2>&1 \|\| true\|SSH 'eldroid-bootctl reboot bootloader' >/dev/null 2>&1\|; s\|echo \"  (uptime=\${up:-?}s < 60s：等设备稳定再 reboot2，避免 #368)\"\|echo \"  (uptime=\${up:-?}s < 60s：等设备稳定再进 fastboot，避免 #368)\"\|" scripts/n5b-vk64-death-rate.sh`；改完可删 `:167-179` 的手工 SysRq-b 逃生梯（`eldroid-bootctl` 内部已带 6 s 看门狗，叠加两个复位落同一关机窗口正是 #368 症状区） |
| P1 | `scripts/q28-por-rounds.sh:99` vs `scripts/q28-devprobe.sh` / `scripts/q28-devprobe2.sh` | **v2 判据已写好，但在用的取样器还在跑 v1**。`q28-devprobe2.sh:3-6` 自述 v1 的病：把所有 DPU/DSI 错误塌成一个 `storm_sig` 计数，**混掉 L1（panel/DSI 真失败）与 L2（ctl reset/frame done/vblank 下游）**；而 Q32/POR 取样链只喂 `q28-devprobe.sh` | `rg -n 'q28-devprobe' scripts/ \| grep -v '^scripts/q28-devprobe'` → 只有 `q28-por-rounds.sh:99` 一个消费点；v1 缺陷自述 `sed -n '1,10p' scripts/q28-devprobe2.sh` | 把 `scripts/q28-por-rounds.sh:99` 改成 <br>`$SSH "$T" 'sh -s' < "$ROOT/scripts/q28-devprobe2.sh" > "$LOGDIR/probe.txt" 2>&1`<br>（同文件 `:100` 之后若解析 `storm=` 键，需同步改成 v2 的 `L1=`/`L2=` 键——先 `sed -n '95,110p' scripts/q28-por-rounds.sh` 核对字段名再改）。改完给 `scripts/q28-devprobe.sh` 加头：`# ⚠ 仅当只需要三态（NOCARD/STORM/GOOD）时用；分层判定用 q28-devprobe2.sh` |
| P1 | `scripts/deploy-sensord-routec.sh`（全文件） vs `scripts/deploy-sensord-routec-debian.sh` | 同一职责（装路线 C 的 Waydroid sensor HAL）两份安装器，**分别面向 Alpine/musl 根与 Debian/glibc 根**；现役根已是 Debian（`TASKS` §4 T17：`findmnt /` = `/dev/sda17`、`os-release` = Debian sid），旧那份装的是 musl 动态件，`-debian.sh:4-8` 记的正是它换根后「`which` 仍命中但跑不起来」的坑（PITFALLS #431） | 头部对照 `sed -n '1,10p' scripts/deploy-sensord-routec.sh` vs `sed -n '1,12p' scripts/deploy-sensord-routec-debian.sh`；账目 `grep -E 'deploy-sensord-routec' versions/scripts-inventory.tsv` → 旧 = `live=0 hist=3 HIST-ONLY`，新 = `live=3 LIVE` | **真源 = `deploy-sensord-routec-debian.sh`**。`deploy-sensord-routec.sh` 首行注释替换为：<br>`# ⛔ RETIRED 2026-11-12：仅适用 Alpine/OpenRC + musl 根。现役 Debian 根用 scripts/deploy-sensord-routec-debian.sh`<br>`#   （原因与判据见 PITFALLS #431；verdict=HIST-ONLY，见 versions/scripts-inventory.tsv）。保留仅作历史。`<br>并入 `PITFALLS/sessions/15-过时废弃功能缺陷登记.md` §15.2 一行 |
| P2 | `scripts/q28-coldboot-collect.sh:38-40` vs `scripts/q28-por-rounds.sh:82-84` | **逐字重复的「跑 clkdiag → 按 boot_id 落盘」三行**；`q28-por-rounds.sh:4-6` 自己声明它是 `coldboot-collect` 的 N 轮超集（同产物名 `q28-clkdiag-r<N>-<bid8>.txt`）⇒ 单轮版 = `por-rounds` 的 `--rounds 1` 特例 | `diff <(sed -n '38,40p' scripts/q28-coldboot-collect.sh) <(sed -n '82,84p' scripts/q28-por-rounds.sh)`；自述 `sed -n '1,8p' scripts/q28-por-rounds.sh` | **可合并**：给 `q28-por-rounds.sh` 加 `ROUNDS=${ROUNDS:-2}` 的单轮别名说明，`q28-coldboot-collect.sh` 首行加 <br>`# ⚠ 单轮薄包装：等价于 ROUNDS=1 bash scripts/q28-por-rounds.sh；重复实现见 :82-84`<br>（保留不删：`reports/q28-*` 里它是取证指针） |
| P2 | `scripts/waydroid-headless-start.sh:1-13`、`scripts/waydroid-headless-restart.sh:1-24` vs `scripts/waydroid-cam-restart.sh:2-5` | headless weston 两条已被 `waydroid-cam-restart.sh:3-5` 的 **2026-10-19 更正**判定为错路（「旧版固定跑 `XDG_RUNTIME_DIR=/run/user/0` + headless weston ⇒ session 挂在没有界面的空合成器上」），现仅对「Q28 坏发无合成器」有效；两脚本各带一份内联 ssh（不 source `lib-ssh.sh`） | `sed -n '1,8p' scripts/waydroid-cam-restart.sh`；`head -6 scripts/waydroid-headless-start.sh scripts/waydroid-headless-restart.sh` | 两个脚本首行注释各加 <br>`# ⚠ 仅用于「Q28 坏发、没有合成器」的场景；正常态起会话用 scripts/waydroid-cam-restart.sh（本文件的 headless weston 路已在 2026-10-19 被判定挂在空合成器上）` |
| — | `scripts/wd.sh:33` vs `scripts/wd-ctl.sh` | **不是冗余**（负结论）：`wd.sh` 是主机侧薄包装，除 `sync` 分支外全部 `remote "sh /usr/local/sbin/wd-ctl.sh $*"` 转发到设备侧实现 | `rg -n 'wd-ctl' scripts/wd.sh` → 唯一命中 `:33` 的转发 | 保留（记录以免下一轮重疑）；可在 `wd.sh:2` 加一句「设备侧真源 = `scripts/wd-ctl.sh`（本文件只做 ssh 包装）」 |
| — | `scripts/serial-{log,logger,capture,fanout,probe,run}.sh`、`serial-{sysrq,tap}.py`、`install-serial-logger.sh`、`lib-serial-source.sh` | 11 个入口，**职责边界成立**（11-06 §3 已定性为「不是重复」，本轮复核仍成立），但**缺一个家族说明 + 有一处指向错件**（见 §2 T1）：`serial-tap.py` 与 `serial-log.sh` 的采集方式互斥，一个被 #622 认可、一个正是 #622 批评的 `cat` 循环 | `head -8 scripts/serial-tap.py`（自述替代 `serial-logger.sh`）；`sed -n '8,23p' scripts/serial-log.sh`（`cat \| sleep` 循环）；`rg -n 'serial-logger\.sh' DEVICE/README.md` | 不合并。在 `RESOURCES/README.md` §2.1 串口行补一行家族口径（**本轮不改，列为 §4 A2 动作**）：<br>`常驻落盘 = serial-tap.py（#622）；serial-log.sh / serial-logger.sh = 历史 cat 循环，已知 open/close 狂抖，勿用于 panic 取证；等节点 = serial-capture.sh；独占敲一下 = serial-probe.sh；发 SysRq = serial-sysrq.py；串口执行命令 = serial-run.sh；被 source 的采集层 = lib-serial-source.sh` |
| — | `scripts/{sleep-bisect,sleep-cumulative,sleep-sweep}.sh` | 三份设备侧模块扫测工具；`15-过时废弃功能缺陷登记.md` §15.2 已登记前两份「**不删，降为 legacy**，新扫测用 `sleep-sweep.sh`」⇒ 结论已有，本轮只补一条：它们仍被 `inventory` 记 `LIVE`（live=3），与「legacy」口径不一致 | `grep -E 'scripts/sleep-' versions/scripts-inventory.tsv`；口径 `rg -n 'sleep-bisect' PITFALLS/sessions/15-过时废弃功能缺陷登记.md` | 不改脚本；在 `scripts/sleep-bisect.sh` 与 `sleep-cumulative.sh` 头各加一行 <br>`# legacy（2026-10-08 登记，见 PITFALLS §15.2）：新扫测用 scripts/sleep-sweep.sh；本脚本仅备重新二分` |
| P1 | `scripts/fix-ab-mark-successful.sh:18-49` vs `qbootctl` / `scripts/slot-switch.sh` | A/B 槽位标记**三套实现**：① distro 自带 `qbootctl.service`（设备上已 enable）② `packaging/elden-userland/services.tsv` 声明的 override ③ 本脚本（**Alpine/OpenRC 专用**：`/etc/init.d/qbootctl` + `rc-update`/`rc-service`），现役 Debian/systemd 根上 `:19` 的 `[ -e /etc/init.d/qbootctl ]` 不成立 ⇒ 立刻 `exit 1`；且 `:47` 还引用 P5 判定该删的 `/usr/local/sbin/slot-attr.py` | `sed -n '17,22p;44,49p' scripts/fix-ab-mark-successful.sh`；根口径 `rg -n 'os-release.*Debian\|findmnt /' TASKS/README.md`（§4 T17 行）；副本账 `rg -n 'slot-attr' packaging/elden-userland/MANIFEST.tsv` | 首行注释替换为 <br>`# ⛔ RETIRED 2026-11-12：仅适用 Alpine/OpenRC 根。现役 Debian 根由 distro 的 qbootctl.service 负责 mark-successful`<br>`#   （qbootctl -m b；必须显式带槽位，见 PITFALLS #126）。本脚本在 systemd 根上第一步就 exit 1。`<br>并把 `:47` 的 `/usr/local/sbin/slot-attr.py` 改为 `/usr/local/bin/slot-attr.py`（与 §282/#627 的 P5 裁决一致：只留 bin 那份） |
| P2 | `scripts/{uefi-boot-trial,uefi-flashed-trial,uefi-r21-sbstop-ladder,uefi-a-slot-prepare}.sh` 各带一份 fastboot/ssh 等待与「进 fastboot」实现 | 与前一报告的 P7/P13 同病，本轮**量化**：`scripts/*.sh` 里 **61 个脚本自带 `ssh -o …` 内联封装**，只有 **6 个** source `lib-ssh.sh`/`lib-fastboot.sh`；`lib-wait.sh` 只有 **5 个**调用者；内联 `fastboot devices` 轮询点 **35 处** | `rg -l 'ssh -o ' scripts/ --glob '*.sh' \| wc -l` → 61；`rg -l 'lib-ssh\.sh\|lib-fastboot\.sh' scripts/ --glob '*.sh' \| wc -l` → 6；`rg -l 'lib-wait\.sh' scripts/` → 5；`rg -n 'fastboot devices' scripts/*.sh \| grep -v 'lib-wait\|lib-fastboot' \| wc -l` → 35 | 不新增脚本。做法 = **把统一层变成默认**：在 `scripts/doctor/` 加一条子门（见 §4 A1），判据「`scripts/*.sh` 中出现 `ssh -o ` 且未 source `lib-ssh.sh`/`lib-fastboot.sh` ⇒ warn，并列出文件名」，然后**每次改到某脚本就顺手接一个**（避免一次性大改 61 个文件） |
| P2 | `scripts/slotboot-run.sh:8-12` | 「一次性上机脚本」把仓库绝对路径、产物目录、SN-less IP、载荷路径全写死（`cd /home/xuqianhui/y700-elden`、`OUT=reports/artifacts/uefi-slotboot-20261101`、`IMG=reports/artifacts/uefi-ddr-20261101/slotb-uefi-marks.img`），是 2026-11-01 单发的执行体；`IMG` 无 `-f` 前置检查 | `sed -n '7,13p' scripts/slotboot-run.sh`；`ls reports/artifacts/uefi-ddr-20261101/slotb-uefi-marks.img` | 加 RETIRED/ONE-SHOT 头：`# ⚠ ONE-SHOT（2026-11-01 的 P2 单发执行体）。路径全写死；重跑前先改 OUT/IMG 并确认 IMG 存在。进 fastboot 请用 scripts/to-fastboot.sh（TASKS §4）` |

**§1 小结**：12 组（2 组 P0 含真缺陷、4 组 P1、4 组 P2、2 组明确「不合并」）。
所有「不可合并」判定都给了证据，供下一轮直接引用而不再重开。

---

## §2 表二：过时（引用已退役流程/路径/设备态、硬编码漂移值）

> 分类：**PATH** = 路径/树/镜像已不存在；**FLOW** = 引用的流程已停用或被换根作废；
> **VALUE** = 硬编码漂移值（SN/IP/分区号/内核串）；**STATE** = 把某一天的设备现场写进脚本当「现状」。

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `DEVICE/README.md:123`（文档指向；被指对象 = `scripts/serial-logger.sh`、`scripts/serial-log.sh:15-23`） | **权威入口文档把已被实测否定的实现写成现役**：`DEVICE` 说「主机串口 logger = `scripts/serial-logger.sh`」，而 `PITFALLS #622`（`PITFALLS/README.md:316`）与 `scripts/serial-tap.py:2-6` 自述都判定 `cat` 循环式采集「ttyACM 存在但无数据时 open/close 狂抖、真数据一行没留」，#622 的正解就是换 `serial-tap.py`。⇒ 按文档做取证会得到「没有 panic」的假阴性（正是 `lib-serial-source.sh:6-9` 警告的那类静默假阴性） | `sed -n '123p' DEVICE/README.md`；`sed -n '1,10p' scripts/serial-tap.py`；`rg -n 'serial-logger' PITFALLS/README.md` | 把 `DEVICE/README.md:123` 行首改为 <br>`- **主机串口落盘** = `scripts/serial-tap.py`（长期持有 fd；`PITFALLS #622`：`serial-logger.sh`/`serial-log.sh` 的 `cat` 循环会 open/close 狂抖、真数据不留，**不得用于 panic 取证**）。常驻服务 = `scripts/install-serial-logger.sh`（unit 跑 `serial-fanout.sh`），被采集脚本 source 的层 = `scripts/lib-serial-source.sh`。**判 Q28 显示不能只靠串口**（重连会漏 0–20 s），须 SSH 读全 dmesg + 查 `card0`。` |
| **P1** | `scripts/kbuild-sanity.sh:26`；另有 **28 处指向不存在的 `build/<名>` 的引用 / 17 个文件**（本行末给出逐条清单与复算命令） | **`KDIR=${ROOT}/build/m1-73` 是硬默认（无 `:-` 可覆盖），而 `build/m1-73` 已不在**（现役树 = `patches/current-tree` = `build/m3v2-7.3rc7`）；文档给的用法不带位置参数（`reports/t9-vk130-pcie-l2-live-20261021.md:16` 写 `kbuild-sanity.sh --rounds 3/2`）⇒ 宿主位翻转防护门在默认用法下检查一棵不存在的树（树完整性段退化为 `warn 不是 git 树`）。这正是 11-06 审计 §5.4 留下的「`build/` 旧树名引用清扫」待办 | 逐条核对：<br>`rg -n 'build/[A-Za-z0-9_.-]' scripts/ \| while IFS=: read f l r; do for x in $(echo "$r"\|grep -o 'build/[A-Za-z0-9_.-]*'); do [ -e "$x" ]\|\| echo "$f:$l $x"; done; done \| sort -u` → **28 行 / 17 文件**<br>现役树：`cat patches/current-tree`；默认用法：`rg -n 'kbuild-sanity.sh' reports/t9-vk130-pcie-l2-live-20261021.md` | ① `scripts/kbuild-sanity.sh:26` 改为 <br>`KDIR=${KDIR:-$ROOT/$(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$ROOT/patches/current-tree" \| grep -v '^$' \| head -1)}`<br>② 其余 26 处按「注释/文档里的示例」处理：把 `build/vk151` 一律替换为 `build/daily`（现役第二棵树，存在），把 `build/m1-73`/`build/m4-base`/`build/m1-upstream`/`build/vk83-tree` 换成 `build/m3v2-7.3rc7` 或明确写「（已归档；重建 = `git worktree add build/<名> <tag>`）」；**需动的 16 个文件**（`scripts/doctor/05f-abi.sh:4,14` 是「已改动态发现」的历史说明，不计）：<br>`scripts/assert-kernel-sane.sh:11,20` `scripts/build-locked-chain.sh:123` `scripts/build-phoc-arm64.sh:28,113` `scripts/check-abi-config.sh:18` `scripts/check-modular-config.sh:5` `scripts/deploy-v4l2loopback.sh:11` `scripts/deploy-zh-ime.sh:44` `scripts/env-build.sh:37,40,49` `scripts/f2fs-migrate.sh:294` `scripts/gpt-surgery-tb322fc.py:334` `scripts/gunyah-rm-bringup.sh:19` `scripts/m1-73-modules-overlay.sh:10,15` `scripts/rebuild-vk64-image.sh:15,28` `scripts/verify-tree-integrity.py:9` `scripts/host-arm64-chroot.sh:69,70`（`check-abi-config.sh` 为 3 处 `:2,18,60`；`assert-kernel-sane.sh` 为 3 处 `:11,20`） |
| **P1** | `scripts/n5b-vk64-death-rate.sh:72-73` | 前置门把**内核串**写死成 7.2 血统：`ls -d /lib/modules/7.2.0-debug-vk64-*`，现役日常线是 7.3-rc7（`build/m3v2-7.3rc7`，在途 vk189）⇒ 该门在当前设备上恒失败，脚本给出的解释（「vk64 的 .ko 全缺」）会把人引向错误结论 | `sed -n '70,74p' scripts/n5b-vk64-death-rate.sh`；现役 `cat patches/current-tree` | 改为从实际 UTS 推：<br>`kv_dir=$(SSH 'ls -d /lib/modules/$(uname -r) 2>/dev/null' \| tr -d '\r')`<br>`[ -n "$kv_dir" ] \|\| { echo "❌ 设备上无 /lib/modules/$(SSH uname -r)：模块树未部署（AGENTS 硬约束）"; return 1; }`<br>并在头部加 `# 本脚本只适用于 vk64 台架（7.2 血统）；7.3 线的死亡率测量需先复制本脚本并改 IMG/UTS` |
| **P1** | `scripts/q28-watchdog.sh:46` | 装设备看门狗的方式是改 **`/etc/local.d/elden-bringup.start`**（Alpine/OpenRC `local` 服务路径）——现役 Debian/systemd 根上该文件不存在；`sed -i` 无 `-e`/无备份、失败被 `set -u`（非 `set -e`）吞掉 ⇒ 「装成功」的提示与真实状态无关 | `sed -n '40,52p' scripts/q28-watchdog.sh`；`rg -n 'local.d' scripts/`；根口径 `rg -n 'os-release.*Debian' TASKS/README.md` | `:44-50` 段改为 systemd 路 + 显式校验：<br>`if [ -d /etc/systemd/system ]; then`<br>`  printf '[Service]\nExecStartPost=/usr/local/sbin/q28-boot-watchdog.sh on\n' > /etc/systemd/system/q28-boot-watchdog.path.d/override.conf 2>/dev/null \|\| { echo "需先建 unit（见 packaging/elden-userland/services.tsv）"; exit 1; }`<br>`  systemctl daemon-reload; systemctl enable --now q28-boot-watchdog.service`<br>`  systemctl is-active --quiet q28-boot-watchdog.service \|\| { echo "FAIL: 未 active"; exit 1; }`<br>`elif [ -f /etc/local.d/elden-bringup.start ]; then …（保留原 sed，但加 cp -a 备份 + grep -q 幂等判断）`<br>`else echo "FAIL: 既无 systemd 也无 /etc/local.d，未知根形态"; exit 1; fi` |
| P1 | `scripts/f2fs-migrate.sh`（整文件，重点 `:2`、`:30-31`、`:93`、`:294`、`:296`、`:356`） | 整脚本的前提已结案：它做的是「缩 `linux17` + 尾部新建 `linux18`(f2fs)」，而 **`linux18` 已于 2026-10-31 删除并入 `linux17`**（`DEVICE/README.md:106`、`:288`）；脚本内还引用 `build/vk151`（无）、`out/boot-elden-vk152.img`（无）、`out/boot-elden-vk162-rescue.img`（无）与 `usr/local/sbin/reboot2` 作为根内 sha 校验项（`:279`，Debian 根没有此件） | `sed -n '1,3p;29,35p' scripts/f2fs-migrate.sh`；结案口径 `rg -n 'linux18.*已删除\|by-partlabel 只剩' DEVICE/README.md`；缺件 `for p in build/vk151 out/boot-elden-vk152.img out/boot-elden-vk162-rescue.img; do [ -e "$p" ] \|\| echo MISSING $p; done` | 头部（`:2` 之后）插入 <br>`# ⛔ 历史路线（2026-10-25 的「f2fs 并存」手术）：linux18 已于 2026-10-31 删除并入 linux17`<br>`#   （DEVICE/README.md §3.3）。**勿再据此迁移**；本文件只作手术配方存档。`<br>并把 `:294` 的 `kd=$ROOT/build/vk151` 改成 `${KDIR:?需显式给内核树}`（禁默认） |
| P2 | `scripts/sign-boot-b.sh:12`、`scripts/q26-recheck.sh:26`、`scripts/n5b-vk64-death-rate.sh:26`、`scripts/rebuild-vk64-image.sh:28`、`scripts/bisect/eldtest.sh:29-32` | **默认输入镜像已不在 `out/`**（已移 `backup/out-history-20261105/`）：`out/boot-elden-vk13.img`、`vk62`、`vk64`、`build/vk83-tree`、`vk34recon/v1-thermal/v2-audio/vk40re`。注：前一报告 S10 已列 `flash-b.sh:19`、`q28-por-rounds.sh:27`、`kexec-bs-cycle.sh:11`、`uefi-oneshot.sh:15-16`、`flash-recovery.sh:16`，此处只列**新增**命中 | `rg -n '^(IN|IMG|IMAGE|KDIR)=.*out/boot-elden-[A-Za-z0-9_.+-]*\.img' scripts/ \| while IFS=: read f l r; do x=$(echo "$r"\|grep -o 'out/[A-Za-z0-9_.+-]*\.img'\|head -1); [ -e "$x" ]\|\| echo "$f:$l $x"; done`；归档账 `ls backup/out-history-20261105/*.img \| wc -l` | 统一改法（对每个）：把 `X=${X:-out/boot-elden-vkNN.img}` 改为 **无默认 + 明确报错**：<br>`IN=${1:?用法: sign-boot-b.sh <boot.img>（out/ 历史镜像已归档到 backup/out-history-20261105/，先查 versions/vk-registry.tsv 取现役件）}`<br>`rebuild-vk64-image.sh:28` 改 `KDIR=${KDIR:-$ROOT/build/vk64-tree}` 并在 `--check-only` 分支加一行提示 `git worktree add build/vk64-tree vk64`；`build-initramfs.sh:83` 与 `grub-bootfiles.sh:44-45` **已有 `[ -f ] \|\| die` 守卫，只需把 die 文案补一句「历史件在 `backup/out-history-20261105/`」** |
| P2 | `scripts/esp-install-grub.sh:18`、`scripts/dev-userdata-relabel.sh:8` | 硬编码**分区号**：`ESP=/dev/sda18`、`PART=/dev/sda16`。号本身当前正确（`DEVICE/README.md:254` = `eldenesp` idx17 = `/dev/sda18`），但违反 AGENTS「产出必须设备无关 / 运行时读实际 GPT」，且换单元或再次追加分区即错位。同目录已有正例可抄 | `sed -n '17,19p' scripts/esp-install-grub.sh`；正例 `rg -n 'by-partlabel' scripts/uefi-a-slot-prepare.sh \| head -3` | `ESP=${ESP:-/dev/disk/by-partlabel/eldenesp}`（并在写入前 `[ -b "$ESP" ] \|\| { echo "FAIL: 找不到 eldenesp 分区（gpt-surgery-tb322fc.py list 核对）"; exit 1; }`）；<br>`dev-userdata-relabel.sh:8` → `PART=${PART:-/dev/disk/by-partlabel/userdata}` |
| P2 | `scripts/q28-por-rounds.sh:13`、`scripts/bisect/README.md:17`、`scripts/bisect/eldtest.sh:46-55` | 把**某一天的设备现场**当「当前」写在脚本/README 里：`boot_b 已是待测内核（当前 vk152）`、`当前 boot_b 烧的是 vk40 现场内核`。实际 boot_b 自 2026-11-07 起 = `vk185`（DEVICE §1.1 / TASKS §4），在途 vk189 | `rg -n '当前.{0,8}(vk[0-9]+)' scripts/ \| head`；现役 `rg -n 'boot_b.*vk185' DEVICE/README.md \| head -2` | 三处把「当前 vkNN」改为带日期的历史断言：`（2026-10-XX 当时的 boot_b = vkNN；现役 boot_b 只读 DEVICE/README.md §1.1 首条，本脚本不维护）` |
| P2 | `versions/scripts-inventory.tsv`（全表，快照日期 2026-11-06） | **唯一的「写了但已不用」机器账已漏账 11 项**：`scripts/` 现 255 个入口，快照里只有 244；漏账含 `scripts/serial-tap.py`（正是 #622 钦定的采集正解）、`lib-fastboot.sh`、`esp-install-grub.sh`、`uefi-a-slot-prepare.sh`、`uefi-flashed-trial.sh`、`boot-img-cmdline.py` 等 ⇒ §2/§1 里所有「live/hist」判定对这 11 个都无账可查 | `export LC_ALL=C; find scripts -type f \\( -name '*.sh' -o -name '*.py' \\) \| sort > /tmp/a; awk -F'\\t' 'NR>6{print $1}' versions/scripts-inventory.tsv \| grep '^scripts/' \| sort > /tmp/b; comm -23 /tmp/a /tmp/b` → 11 行 | 重跑生成命令（表头即答案）：`python3 scripts/static-scan.py --inventory \| sed '1d' > versions/scripts-inventory.tsv`，然后对本报告 §1/§2 涉及的 11 个逐个裁决；并在 `scripts/doctor/06-hygiene.sh` 加一行「inventory 落后于 `scripts/` 计数 ⇒ warn」（§4 A6） |
| P2 | `scripts/deploy-zh-ime.sh`（Alpine 世代用户态栈）、`scripts/setup-session-greetd.sh`、`scripts/greetd-initial-session.sh`、`scripts/start-desktop.sh`、`scripts/openrc-enable.sh`、`scripts/bt-up.sh`、`scripts/bench-install.sh` | 17 个脚本仍带 Alpine/OpenRC 或 postmarketOS 世代假设（`rc-update`/`rc-service`/`/etc/runlevels`/`apk add`/`openrc-run`/`phosh-session` 循环）。其中 `openrc-enable.sh` 与 `setup-session-greetd.sh` 的功能在现役 Debian 根上已由 systemd user unit 承担（`TASKS` §1 G1-38 的 `rootfs/debian/ime/elden-ime-focusd.service` 即新形态） | `rg -ln 'rc-update\|rc-service\|/etc/runlevels\|apk add\|openrc-run' scripts/` → 17 个文件 | 逐个裁决（本轮只登记）。最小动作：对**只在 Alpine 根有效**的 7 个，首行加 <br>`# ⛔ RETIRED 2026-11-12：Alpine/OpenRC 根专用。现役 Debian/systemd 根见 rootfs/debian/（stage.sh + systemd unit）与 TASKS §4 G1-37/G1-38。`<br>并把 `openrc-enable.sh` 的现役替代在注释里点名（`scripts/openrc-enable.sh:37` 已自注 `persistent-overlay/restore.sh`，一并标 retire） |
| — | 全 `scripts/` + `packaging/elden-userland/` + `tools/` | **负结论（供下一轮免检）**：`nexavlinks` 在脚本/包装/工具里 **0 命中**（禁用只体现在 agent 配置层，脚本无残留）；`HA2CB1KY` 在 `scripts/` 里 0 命中，仅 `packaging/elden-userland/files/usr/local/sbin/usb-gadget:37` 以注释形式解释「旧值 HA2CB1KY 是模板常量」⇒ #627 的回灌没有留下活代码 | `rg -n 'reboot2\|nexavlinks\|HA2CB1KY\|out-history\|build/vk' scripts/ packaging/elden-userland/files` → `nexavlinks` 0 行；`HA2CB1KY` 仅 1 行且是注释 | 无需动作（保留该注释，它是有解释价值的反例记录） |
| P2 | `scripts/check-abi-config.sh:13,78,124` | 默认 ABI 参考 = `patches/config-vk127-working-*`（2026-10-18 的快照），而现役树 = `build/m3v2-7.3rc7` ⇒ 打开 `CONFIG_SUSPEND` 的在途构建必然被本门判红。**这与前一报告无关，是 `TASKS` §4「vk189 已知门禁红灯」的同一条**，此处只补「默认值本身该跟树走」这一层 | `sed -n '76,80p' scripts/check-abi-config.sh`；红灯登记 `rg -n '已知门禁红灯' TASKS/README.md` | 按 `TASKS` §4 已定的解除条件做，但把默认值改成**跟树走**：`REF` 解析顺序 = ①`--ref` ②`patches/config-<当前树名>*` ③`patches/config-daily-*` ④`patches/config-vk127-working-*`（保底），并在输出里打印「参考=config-X（推导自树 Y）」，避免下次再靠记忆解释红灯 |

**§2 小结**：12 条，分 5 类：**PATH**（不存在的 `build/<名>` 引用 28 处 / 17 文件 + 已归档镜像默认值 6 处）、、**FLOW**（Alpine/OpenRC 世代 17 个脚本 + `f2fs-migrate` 结案路线 + `q28-watchdog` 的 `local.d`）、**VALUE**（内核串 1、分区号 2；SN/IP 前一报告已计）、**STATE**（3 处「当前 vkNN」）、**DOC**（`DEVICE:123` 指向被否定实现 + inventory 漏账 11）。
`nexavlinks` 与 `HA2CB1KY` 已确认清干净（负结论）。

---

## §3 表三：已知缺陷（**只列仍未修**的；逐条读过现文件）

> 前一报告 17 条中，已核实现已修好的 4 条**不再列**：
> `slot-attr.py` 的 `--dry-run`（三份副本 sha 现逐字相同，`grep -n SUPPRESS` 命中 `:239`）、
> `device-lock.sh` 的 holder 写入顺序（现 `:39` acquire → `:42` 写）、
> `arm-window-hunt.sh:12`/`uefi-ddr-trial.sh:26` 的 `#584` 管道（已改为注释 + 取值再判）、
> `kexec-bs-cycle.sh:2-4` 的叠加 sysrq-b（已删并改写为告诫）。

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P0** | `scripts/arm-console-run.sh:14`、`scripts/trial.sh:186` | （同 §1 第 2 行，此处计入缺陷数）**#584 SIGPIPE 未修的仅剩这两处**，且都在「进 fastboot 失败就报错退出」的判据位上 ⇒ 判据本身会打断通道 | `rg -n '(fastboot\|adb)[^|]*\| *(grep\|head\|wc)' scripts/ packaging/ tools/ rootfs/` | 见 §1 同行改法（先 `d=$(timeout 8 fastboot devices 2>/dev/null)`，再 `case "$d" in *"$SER"*)`） |
| **P0** | `scripts/ath12k-load.sh:36` | `echo "$DEV" > "$DRV/bind"` 写的是 **`/sys/bus/pci/devices/0000:01:00.0`（路径）**；sysfs `driver/bind` 要的是 **设备名**。同仓 `ath12k-retry.sh:50-51` 有原话 NOTE 且 `:51` 写的是 `$DEVNAME` ⇒ 本脚本的 re-bind 恒失败，还被 `2>/dev/null` 吞掉（静默） | `sed -n '23,36p' scripts/ath12k-load.sh`（`DEV=` 与 `echo "$DEV" >`）；对照 `sed -n '17,18p;48,52p' scripts/ath12k-retry.sh` | 二选一：**（推荐）删调用面**（见 §4 D1），或最小修：<br>`echo "${DEV##*/}" > "$DRV/bind" 2>&1 \| log "re-bind result: $?"`<br>（去掉 `2>/dev/null`，让失败可见） |
| **P1** | `scripts/switch-kernel-abi.sh:151-152` | **写 `boot_b` + 重启，却不取设备锁**：全文件无 `device_lock_acquire`；并发 agent 可在它刷写中途发 `fastboot boot`/`reboot`（正是 #368 的「复位窗口叠加命令」形态）。同族未取锁且会改设备状态的还有：`kexec-bs-cycle.sh:15,19`、`q32-arm.sh:165`、`sd-run-variant.sh:35,51`、`uefi-ddr-trial.sh:35,37`、`n5b-vk64-death-rate.sh:131`、`slotboot-run.sh`、`f2fs-migrate.sh`（`writeslot`） | `for f in $(rg -l 'fastboot (flash\|boot)\|eldroid-bootctl reboot\|reboot2 bootloader' scripts/ --glob '*.sh'); do rg -q device_lock_acquire $f \|\| echo "无锁: $f"; done`；锁的真源 `sed -n '1,12p' scripts/lib-device-lock.sh` | 在每个未取锁脚本的**参数解析之后、第一条设备命令之前**插入（与 `to-fastboot.sh:21-22` 逐字同形）：<br>`. "$(dirname "$0")/lib-device-lock.sh"`<br>`device_lock_acquire`<br>（`switch-kernel-abi.sh` 放在 `:149` 的 `echo "-- [3/3] 内核镜像"` 之前） |
| **P1** | `scripts/cam-loopback.sh:82`、`scripts/deploy-zh-ime.sh:86` | **`pkill -f` 自匹配打死自己所在的 shell**：`cam-loopback.sh` 的 `stop` 分支把 `pkill -f '…libcamerasrc'` 与 `echo stopped` 拼在同一条 `S "…"`（= `ssh … "<整串>"`）里 ⇒ 远端 `sh -c` 的 argv 含该模式，`pkill -f` 先杀掉自己，`echo stopped` 永不打印、`stop` 的返回值不可信；`deploy-zh-ime.sh:86` 经 `as()` = `su -s /bin/sh $U -c "$1"`，同样自匹配 | `sed -n '/^S()/p' scripts/cam-loopback.sh`；`sed -n '82p;68p' scripts/cam-loopback.sh`（**同文件 `:68` 已经用了 `libcamera[s]rc` 字符组写法**，`:82` 漏了）；`sed -n '78p;86p' scripts/deploy-zh-ime.sh` | `cam-loopback.sh:82` → <br>`S "pkill -f 'gst-launch-1.0 -q libcamera[s]rc' 2>/dev/null; echo stopped"`<br>`deploy-zh-ime.sh:86` → <br>`as "$E pkill -f elden-ime-focus[d]" 2>/dev/null \|\| true`<br>（另见全局技能 `pkill-self-match`） |
| **P1** | `scripts/deploy-zh-ime.sh:63-66,79-80,91`、`scripts/b3b-session-retry.sh:24-25,43`、`scripts/q28-watchdog.sh:38`、`packaging/elden-userland/files/usr/local/sbin/q28-boot-watchdog.sh:34-35` | **设备侧 `pgrep -x`/`pkill -x`（PITFALLS #120 明写「设备脚本里出现一律当 bug」**：busybox 的 `-x` 匹配 argv[0] 全串而非 comm ⇒ 恒假阴性）。现役部署脚本 `deploy-zh-ime.sh` 用 `pkill -x fcitx5` 收尾，正是 `TASKS` §4 #619 记的「`pkill -x fcitx5` 杀不掉（systemd user unit 立刻拉起）」；`q28-boot-watchdog.sh` 用 `pgrep -x phoc` 当「桌面起来了」的判据 ⇒ 判据可能恒假 | `rg -n 'pg?kill -x\|pgrep -x' scripts/ packaging/elden-userland/files/` → 上述 4 文件多命中；正例（同仓已改对）`sed -n '1,8p' scripts/dpms-watch.sh`、`sed -n '48,56p' scripts/net-up-manual.sh` | 统一改成 shell-agnostic（#120 钦定的写法，照 `dpms-watch.sh`）：<br>`pkill -x NAME` → `ps -eo pid,comm \| awk -v n=NAME '$2==n{print $1}' \| xargs -r kill`<br>`pgrep -x NAME >/dev/null` → `ps -eo comm \| grep -qx NAME`<br>逐个替换：`NAME ∈ {fcitx5, squeekboard, wvkbd-mobintl, fcitx5-candbar, candidate-bar, candidate-bar.new, phoc, phosh}` |
| **P1** | `scripts/serial-capture.sh:12` | 头注释教的是 **`pkill -f serial-capture.sh`** 并断言「不会自杀」——**在 agent 的 `bash -c` 通道下这个断言为假**：包装 shell 的 argv 含该模式 ⇒ 自杀（全局技能 `pkill-self-match` 记录的同款）。停法本已有正确形式（同文件用的 pid 文件路径没写出来，等于只教了危险的那条） | `sed -n '10,14p' scripts/serial-capture.sh`；对照正确样板 `grep -n 'PIDF' scripts/serial-logger.sh \| head -3` | 把 `:12` 改为 <br>`# 停止：脚本会把 pid 写到 /tmp/serial-capture.pid，用 kill "$(cat /tmp/serial-capture.pid)" 停；`<br>`#      不要用 pkill -f serial-capture.sh —— 经 ssh/bash -c 下发时会匹配到自己所在的 shell 并自杀（见技能 pkill-self-match）。`<br>并在脚本内补 `echo $$ > /tmp/serial-capture.pid`（照 `serial-logger.sh:10`） |
| P2 | `scripts/cam-loopback.sh:69`、`:85` | ① `:69` 的清理模式**永远匹配不到**：模式是 `v4l2-ctl -d /dev/video100 --stream-out`，而真实 argv 在 `-d <dev>` 与 `--stream-out-mmap=8` 之间还夹着 `--set-fmt-video-out=width=…`（见同文件 `:74-76`）⇒ 写端进程不会被清掉，下一轮 `start` 撞占用；② `:85` 的 `pgrep -af "gst-launch-1.0 -q libcamerasrc"` 同样无字符组 ⇒ 会把承载它的远端 `sh -c` 自己列成「还在跑」 | `sed -n '69,76p;85p' scripts/cam-loopback.sh`（对照 argv 与模式） | ① `:69` → `pkill -f 'v4l2-ctl -d /dev/video100.*--stream-out[-]mmap' 2>/dev/null`（或直接 `pkill -f 'v4l2-ct[l] --stream-out-mmap'`）<br>② `:85` → `pgrep -af "gst-launch-1.0 -q libcamera[s]rc" \| head -2` |
| P2 | `scripts/t5-q24-capture.sh:81` | 违反 AGENTS 硬约束「设备侧脚本必须 POSIX sh：整文件 scp 到 /tmp 再 `sh /tmp/x.sh`，**禁长 inline ssh 单引号/多行块**」：这一行是双引号包裹的多行 shell 块、内部 `\$`/`\\0`/`\\n` 层层转义、还嵌 `$( )`+管道+`cut`，主机/设备任一侧改引号就静默改变语义（`lib-boot-ready.sh` 的自检正是被同类展开坑过，见 `reports/script-audit-20261105.md` §2.3） | `sed -n '79,83p' scripts/t5-q24-capture.sh`；纪律 `rg -n '禁长 inline ssh' AGENTS.md` | 把取 `DBUS_SESSION_BUS_ADDRESS` 的逻辑做成一个函数文件（复用已有 `S_kv` 口径）：<br>`BUS=$(ssh $SSH_TAB "\$S_kv DBUS_SESSION_BUS_ADDRESS")`，或把这段移进 `scripts/lib-ssh.sh` 里新增的 `S_session_bus()`（**用单引号**包住远端片段，避免主机侧展开） |
| P2 | `scripts/cam-loopback.sh:64`（同类 `:68` 的 `busy=` 判据） | 互斥判据把**自己**的匹配串写在 grep 模式里，靠 `grep -vE 'pgrep\|grep\|cam-loopback'` 事后剔除；一旦脚本改名（如复制到 `scripts/bisect/`）剔除即失效，`REFUSE` 会恒真（该 bug 的历史形态就写在 `:61-63` 的注释里：旧判据命中内核线程 `[disp_snapshot]` 导致永远误报） | `sed -n '58,70p' scripts/cam-loopback.sh` | 用字符组自屏蔽替代事后剔除：<br>`busy=$(S "ps -eo pid,args \| grep -E '(^\|[ /])(cam\|captureScript\|gnome-snapshot\|snapsho[t])( \|\\\$)' \| grep -v '\\[.*\\]' \| wc -l") \|\| busy=0` |
| P2 | `scripts/doctor/06-hygiene.sh:11-30` + `scripts/static-scan.py:195-196` | **bashism/死脚本门的覆盖面只有 `scripts/*.sh`（深度 1）**：`^scripts/[^/]+\.sh$` 把 `scripts/doctor/*`、`scripts/bisect/*`、`packaging/elden-userland/files/**`、`rootfs/*.sh`、`initramfs/*` 全排除在外——而这些恰是**在 busybox ash 上跑**的设备侧脚本（#120 的整条教训都在这一层）。本轮按同正则口径补扫这些目录，当前真阳性 = 0（所以是「风险」不是「现存 bug」），但门无法阻止下一个 | `rg -n 'scripts = \[' -A2 scripts/static-scan.py`；补扫（0 命中即无现存违规）：`python3 - <<'PY'` 后按 `r"\[\[(?!:)\|declare -\|[A-Za-z_][A-Za-z0-9_]*=\("` 扫 `packaging/elden-userland/files rootfs initramfs scripts/doctor scripts/bisect` 中 `#!/bin/sh` 开头文件 | `scripts/static-scan.py:195` 改为：<br>`scripts = [p for p in git(root, 'ls-files', '-z', '--', 'scripts/*.sh', 'scripts/*/*.sh', 'packaging/*/*/*/*.sh', 'packaging/*/*/*/*/*.sh', 'rootfs/*.sh', 'rootfs/*/*.sh', 'initramfs/*.sh').stdout.split('\0') if p.endswith('.sh')]`<br>（`DEAD` 判据仍只对 `scripts/` 生效：在 `dead_scripts()` 里加 `if rel.startswith('scripts/')`，避免把设备侧脚本误报成死脚本） |
| P2 | `scripts/serial-log.sh:6-23` | 只有 `set -u`、采集靠 `cat "$PORT" \| sleep` 循环，且**无 pid 文件**、无「节点权限不足 ⇒ 明确报错」的分级（`lib-serial-source.sh:6-9` 描述的静默假阴性形态与之相同）；虽被 12 篇文档提过，但 `live` 引用主要来自历史报告 ⇒ 现役取证若用它就中招 | `sed -n '5,23p' scripts/serial-log.sh`；对照 `sed -n '1,12p' scripts/lib-serial-source.sh` | 在 `scripts/serial-log.sh:2` 之后插入 <br>`# ⚠ 已知缺陷（PITFALLS #622）：cat 循环在 ttyACM 无数据时 open/close 狂抖，真数据不留。`<br>`#   panic/Q28 取证请用 scripts/serial-tap.py（或 source scripts/lib-serial-source.sh）。` |
| P2 | `packaging/elden-userland/MANIFEST.tsv:34` 与 `:67`（`/usr/local/bin/slot-attr.py` + `/usr/local/usr/sbin/slot-attr.py`）、`packaging/elden-userland/services.tsv` 与设备上 distro `qbootctl.service` | 三个后果之一已消除（内容已逐字一致），但**「双份安装 + 无漂移门」的结构没变**：`MANIFEST` 同时装 bin 与 sbin 两份（sha 相同），`scripts/trial.sh:55,58` 仍调 `/usr/local/sbin/…`；`#627` 定的「`files/` 只允许是权威源逐字副本」规则**没有任何机器门**（`scripts/doctor/` 里 `rg 'packaging'` = 0 命中），下一轮单边改动会静默复活 | `grep -n slot-attr packaging/elden-userland/MANIFEST.tsv`；`sha256sum scripts/slot-attr.py packaging/elden-userland/files/usr/local/{bin,sbin}/slot-attr.py` → 三者同 sha；`rg -n 'packaging\|MANIFEST' scripts/doctor/*.sh` → 0 行；`rg -n 'slot-attr' scripts/trial.sh` | ① 删 `MANIFEST.tsv:67` 与 `files/usr/local/sbin/slot-attr.py`，`scripts/trial.sh:55,58` 改 `/usr/local/bin/slot-attr.py`；<br>② 加 §4 A1 的漂移门（对 `sources.tsv` 新列 `upstream` 的每一项比 sha） |
| — | `set -euo pipefail` 缺失 | **不作为缺陷计**：`scripts/` 下 133 个 `.sh` 无 `set -e`（多为 `set -u`/`set -uo pipefail` 的设备侧工具，加 `-e` 需要逐条核语义，批量加反而出错）。抽查 4 个真正写盘的脚本，均在各写点自带显式 rc 判定：`sign-boot-b.sh:5`（`set -eu` + `:15 [ -f ] \|\| exit 1`）、`flash-b.sh`（有 `set -e`，`:28` 调 sign 失败即止）、`switch-kernel-abi.sh:151-153`（`\|\| { …exit 1; }`）、`slot-switch.sh:133`（读回不符即 exit） | `for f in scripts/*.sh; do grep -Eq '^[[:space:]]*set[[:space:]]+-[a-z]*e' $f \|\| echo $f; done \| wc -l` → 133；逐条 `sed -n '5p;12p;15p' scripts/sign-boot-b.sh` | 不动。若要收紧，只对**新增**脚本生效：在 `scripts/doctor/06-hygiene.sh` 加一条「新出现的 `.sh`（`git log --diff-filter=A` 在本轮窗口内）缺 `set -e`/`set -u` ⇒ warn」 |
| — | `#!/bin/sh` 里的 bashism | **负结论**：`static-scan.py` 报 `BASHISM -`；本轮按同一正则对其余目录（`packaging/**/files`、`rootfs/`、`initramfs/`、`scripts/doctor/`、`scripts/bisect/`）补扫 = **0 真阳性**。我最初 grep 出的 3 条（`audio-alsa-init.sh:61`、`bench-run.sh:113`、`wd-c1-noworkaround.dev.sh:41`）经复核是 `sed` 字符类 `[[:space:]]` 造成的**假阳性**，已排除 | `python3 scripts/static-scan.py --root "$PWD" --tsv` → `BASHISM -` | 无需动作（记录以免下一轮把这 3 条当 bug 重报） |

**§3 小结**：**仍未修 12 条 = P0 2 / P1 4 / P2 6**，另有 2 条明确「不作为缺陷 / 负结论」（批量 `set -e`、bashism）。
最值得先动的是两条 P0（`ath12k-load.sh` 的 bind 语义 + 残余两处 `#584` 管道）与「写盘不取设备锁」一族（P1）。

---

## §4 清理动作清单（按「收益/代价」排序；每条带证据与回滚）

> 本轮**只登记不执行**（硬约束）。列内命令是给执行者的成品。
> 「可删」的前置 = 规定的 0 引用双查（`*.md` 排除 `archive/`、`HISTORY/` + `scripts|packaging|tools` 命中数）。

### A. 加机器门（防回归）—— 最高优先，因为 §1/§2 的所有病都是「规则写了、门没有」

| # | 动作 | 落地位置 | 判据（写进门里的话） | 依据 |
|---|---|---|---|---|
| **A1** | **新增子门 `scripts/doctor/05g-packaging-drift.sh`：包装副本 ↔ 权威源 sha 必须逐字一致** | 新文件（照 `scripts/doctor/_lib.sh` 的契约：只打印 `  [ok]/[FAIL]/[warn]` + `== 5g. …==` 段头，退出码不参与判定） | 逐条读 `packaging/elden-userland/sources.tsv` 的新列 `upstream`（见 A2），对每个 `(源, files/…)` 做 `cmp -s`；不一致 ⇒ `bad "packaging 副本落后于权威源: <dst> ≠ <src>"`；`files/` 存在但表里无映射 ⇒ `warn`。**再补**：`MANIFEST.tsv` 的 sha/size 与 `files/` 实际逐条核（离线也能查，补上 `verify.sh` 只在在线时报漂移的缺口） | `#627`（`PITFALLS/sessions/282-*`）的规则是纯文字；现证 `rg -n 'packaging\|MANIFEST' scripts/doctor/*.sh` = **0 命中**；本轮实测三份副本曾长期不一致（`sha256sum scripts/ath12k-load.sh packaging/elden-userland/files/usr/local/sbin/ath12k-load.sh` 现一致，但无人阻止下次分歧） |
| **A2** | `packaging/elden-userland/sources.tsv` **加一列 `upstream`**（权威源路径：`scripts/…` 或 `rootfs/…`；无源则填 `own`） | 现有表（表头注释 `:3` 的列定义同步加一列） | 列：`dst ⇥ build ⇥ source ⇥ status ⇥ note ⇥ upstream` | 前一报告 §5.5 已给同样结论（「真要防回归，应先补『权威源 → packaging 路径』一列」） |
| **A3** | `scripts/doctor/06-hygiene.sh` 增加 **6d：#584 管道禁令** | 现有子门末尾 | `rg -n '(fastboot\|adb)[^|]*\| *(grep\|head\|wc)' scripts/ packaging/ tools/ rootfs/` 有命中 ⇒ `bad`；命中数 0 ⇒ `ok "设备工具输出不接提前退出的管道（#584）"` | 本轮实测仍有 2 处实代码命中（`arm-console-run.sh:14`、`trial.sh:186`）；#627 修了 2 处但无门 ⇒ 同类必然再出现 |
| **A4** | 同门增加 **6e：设备侧 `pkill -f` 自匹配 / `-x` 假阴性** | 同上 | ① `pkill -f`/`pgrep -f` 的模式里没有字符组（`[x]`）且整条命令会与自身 argv 同现（在 `S "…"`/`as "…"`/`ssh … "<…" ` 单串里）⇒ `bad`；② 设备侧脚本出现 `pgrep -x`/`pkill -x` ⇒ `warn`（引 #120） | 现存：`cam-loopback.sh:82,85`、`deploy-zh-ime.sh:63-66,79-80,86,91`、`b3b-session-retry.sh:24-25,43`、`q28-watchdog.sh:38`、`q28-boot-watchdog.sh:34-35`；#120 原文「设备脚本里出现 `pgrep -x`/`pkill -x` 一律当 bug」 |
| **A5** | 同门增加 **6f：写设备必须持锁** | 同上 | 脚本里出现 `fastboot (flash\|boot)` / `eldroid-bootctl reboot` / `reboot2 bootloader` / `sysrq-trigger` 的**可执行行**，却 `grep -q device_lock_acquire` 失败 ⇒ `warn`（列文件名，逐个转 `ok`） | 实测 7 个真会写盘的脚本无锁：`switch-kernel-abi.sh`（`fastboot flash boot_b:151`）、`kexec-bs-cycle.sh:15,19`、`q32-arm.sh:165`、`sd-run-variant.sh:35,51`、`uefi-ddr-trial.sh:35,37`、`slotboot-run.sh`、`f2fs-migrate.sh`；真源 `scripts/lib-device-lock.sh:1-12` |
| **A6** | 同门增加 **6g：inventory 落后即 warn** + 重刷快照 | `scripts/doctor/06-hygiene.sh`；先跑 `python3 scripts/static-scan.py --inventory \| sed '1d' > versions/scripts-inventory.tsv` | `find scripts -type f \( -name '*.sh' -o -name '*.py' \) \| wc -l` ≠ `awk` 统计的 `scripts/` 行数 ⇒ `warn "scripts-inventory.tsv 落后 N 项（跑了 static-scan.py --inventory 重刷）"` | 实测漏账 11 项（含 `serial-tap.py`、`lib-fastboot.sh`）；`static-scan.py:195` 的 `--inventory` spec 也要补 `scripts/*/*` 已含但 `packaging/*/*/*.sh` 之外的深度（`files/usr/local/{bin,sbin}/**`） |

### B. 合并 / 改默认值（可照抄文本）

| # | 动作 | 文件:行 | 代价 | 依据（本表内编号） |
|---|---|---|---|---|
| B1 | 删 `fastboot devices \| grep -q .` 两处 | `scripts/arm-console-run.sh:14`、`scripts/trial.sh:186` | 5 min | §1-2 / §3-1（P0） |
| B2 | `ath12k-load.sh` 退役（见 D1） | `scripts/ath12k-load.sh`、`packaging/elden-userland/MANIFEST.tsv:40`、`rootfs/build-rootfs.sh:73` | 10 min | §1-1（P0） |
| B3 | `n5b-vk64-death-rate.sh`：`reboot2`→`eldroid-bootctl`、UTS 硬串→`uname -r` | `scripts/n5b-vk64-death-rate.sh:131,167,72` | 20 min（含 `--check` 跑通） | §1-3 / §2-3 |
| B4 | `q28-por-rounds.sh` 取样改喂 `q28-devprobe2.sh` 并同步字段名 | `scripts/q28-por-rounds.sh:99` | 15 min | §1-4 |
| B5 | `kbuild-sanity.sh` 默认树改读 `patches/current-tree` | `scripts/kbuild-sanity.sh:26` | 5 min | §2-2 |
| B6 | 写盘脚本补 `device_lock_acquire`（7 个，逐个） | 见 A5 清单 | 每个 5 min | §3-3 |
| B7 | 6 处 `out/*.img` 默认值改「无默认 + 带归档指针的报错」 | `sign-boot-b.sh:12`、`q26-recheck.sh:26`、`n5b:26`、`rebuild-vk64-image.sh:28`、`bisect/eldtest.sh:29-32`、`build-initramfs.sh:83`（仅补文案） | 30 min | §2-6 |
| B8 | 分区号改 `by-partlabel` | `esp-install-grub.sh:18` → `/dev/disk/by-partlabel/eldenesp`；`dev-userdata-relabel.sh:8` → `/dev/disk/by-partlabel/userdata` | 10 min | §2-7 |
| B9 | 删 `slot-attr.py` 的 sbin 第二份 | `MANIFEST.tsv:67` + `files/usr/local/sbin/slot-attr.py` + `scripts/trial.sh:55,58` 改路径 | 15 min（要刷 MANIFEST sha 并重跑 `rootfs/debian/stage.sh`） | §3-11；前报告 P5 |
| B10 | `pkill/pgrep` 六处改写（字符组 + `ps -eo comm`） | `cam-loopback.sh:69,82,85`、`deploy-zh-ime.sh:63-66,79-80,86,91`、`b3b-session-retry.sh:24-25,43`、`q28-watchdog.sh:38`、`q28-boot-watchdog.sh:34-35` | 40 min（含设备侧回归，需设备窗口） | §3-4、§3-5、§3-7 |
| B11 | `DEVICE/README.md:123` 改指 `serial-tap.py` | 文档一行 | 2 min | §2-1 |

### C. 加 `RETIRED` / `ONE-SHOT` 头（不删，避免断历史指针）

| # | 文件 | 头内容（首行注释之后插入） |
|---|---|---|
| C1 | `scripts/deploy-sensord-routec.sh` | `# ⛔ RETIRED 2026-11-12：仅适用 Alpine/musl 根；现役 Debian 根用 scripts/deploy-sensord-routec-debian.sh（PITFALLS #431；verdict=HIST-ONLY）` |
| C2 | `scripts/fix-ab-mark-successful.sh` | `# ⛔ RETIRED 2026-11-12：Alpine/OpenRC 专用；现役 Debian 根由 distro qbootctl.service（qbootctl -m b）负责（PITFALLS #126）。本脚本在 systemd 根上第一步 exit 1` |
| C3 | `scripts/{openrc-enable,setup-session-greetd,greetd-initial-session,bt-up,start-desktop,bench-install,bench-run}.sh` | `# ⛔ RETIRED 2026-11-12：Alpine/OpenRC（或 postmarketOS phosh-session）世代；现役形态见 rootfs/debian/ + TASKS §4 G1-37/G1-38` |
| C4 | `scripts/f2fs-migrate.sh` | 见 §2-4 的原文（`⛔ 历史路线 … linux18 已于 2026-10-31 删除并入 linux17`） |
| C5 | `scripts/slotboot-run.sh`、`scripts/{wd-c1-noworkaround,wd-c1-verify,wd-net-baseline}.dev.sh` | `# ⚠ ONE-SHOT：<日期> 单发执行体，路径/载荷写死；重跑前先改并核实输入存在。相关结论见 <报告路径>` |
| C6 | `scripts/waydroid-headless-{start,restart}.sh`、`scripts/q28-devprobe.sh`、`scripts/sleep-{bisect,cumulative}.sh`、`scripts/serial-log.sh` | 见 §1-7 / §1-4 / §1-11 / §3-10 各行给出的原文 |

### D. 可删（**已按规定的 0 引用双查**；删法含回滚）

| # | 对象 | 0 引用证据 | 删法 | 回滚 |
|---|---|---|---|---|
| **D1** | `scripts/ath12k-load.sh` + 其安装面 | 规定命令 `rg -n --glob '*.md' --glob '!archive/**' --glob '!HISTORY/**' 'ath12k-load' .` → **仅 1 个文件命中，且是本报告自身**（历史会话都没提过）；`rg -c 'ath12k-load' scripts/ packaging/ tools/ rootfs/ initramfs/` → 6 个文件，但**全部**是「自身两份副本 + 安装/同步名单」（`MANIFEST.tsv:40`、`packaging/elden-userland/tools/sync-from-device.sh:24`、`rootfs/build-rootfs.sh:73`、`rootfs/persistent-overlay/STATE.txt:3`）⇒ **零功能调用点**（对照 `ath12k-retry` 有 `initramfs/init:634` + `services.tsv:41`） | ① `git rm scripts/ath12k-load.sh packaging/elden-userland/files/usr/local/sbin/ath12k-load.sh`；② 删 `MANIFEST.tsv:40` 一行、`build-rootfs.sh:73` 名单去掉该项、`sync-from-device.sh:24` 同步；③ `bash rootfs/debian/stage.sh` + `packaging/elden-userland/tools/verify.sh`（FAIL 不得增加）；④ 设备侧 `/usr/local/sbin/ath12k-load.sh` **本轮不碰**（无锁、无设备窗口），登记为下一次设备任务 | `git checkout HEAD -- scripts/ath12k-load.sh packaging/elden-userland/files/usr/local/sbin/ath12k-load.sh` + 还原三处名单行；设备侧误删可用 `packaging/elden-userland/tools/verify.sh` 发现并从 `files/` 重铺 |
| **D2** | `scripts/q26-recheck.sh`（**建议归档而非删**） | 规定命令 → **0 个入口文档命中**（只有 `reports/q26-*`）；`scripts/packaging/tools` 命中 1 = 自身。且其 `IMG=${IMG:-out/boot-elden-vk62.img}`（已归档）、提示仍写 `/usr/local/sbin/reboot2 bootloader`（`:45`，前报告 #18 已列） | `git mv scripts/q26-recheck.sh archive/2026-11-12-retired-scripts/` 并在该目录 README 写一行「Q26 已关闭（`PITFALLS §15.5`），脚本依赖 vk62/63 镜像已归档」；`Q26` 状态口径在 `TASKS` §5 不动 | `git mv` 回来；无安装面（不在 MANIFEST） |
| D3 | **不建议删的**：`scripts/{wd-c1-noworkaround,wd-c1-verify}.dev.sh`、`scripts/real-vs-ladder.sh`、`scripts/uefi-{oneshot,ddr-trial}.sh`、`scripts/uefi-r21-p7-ladder.sh`、`scripts/sd-run-variant.sh` | 规定命令命中数：`wd-c1-noworkaround.dev` = 3（含 2 篇 `reports/` 权威：`c1-noworkaround-20261013.md`、`c9-cases-20261013.md`）、`wd-c1-verify.dev` = 1（`reports/wd-netd-route-20261011.md`）、`real-vs-ladder` = 4（含 `TASKS/README.md`、`patches/uefi/README.md`）、`uefi-r21-p7-ladder` = **10**（含 `RESOURCES`、`TASKS`、`PITFALLS`）、`sd-run-variant` = 2（`PITFALLS/README.md`、`282-*`）⇒ **删了会断权威指针** | 走 C5（ONE-SHOT 头），**不删** | — |

> **可删总数 = 1（`ath12k-load`）+ 1 建议归档（`q26-recheck`）**。与 11-06 那轮 `UNREFERENCED=0` 一致：
> 本仓脚本的问题从来不是「没人引用」，而是「有引用但默认值/路径/根形态已过期」⇒ 清理主力是 A/B/C，不是 D。

### E. 明确保留（附理由，供下一轮免检）

| 对象 | 保留理由（证据） |
|---|---|
| `scripts/serial-*` 全家 11 个 | 职责边界成立（§1-10），11-06 §3 已定性 + 本轮复核 |
| `scripts/waydroid-*` 12 个 | 分属 C5/C10/Q28/代理四条线（11-06 §3）；本轮只给 headless 两件加限定头 |
| `scripts/wd.sh` + `scripts/wd-ctl.sh` | 主机/设备两端，`wd.sh:33` 是转发不是复制（§1-8） |
| `scripts/q28-{clkdiag,coldboot-collect,watchdog,disp-ab-sample}.sh` | 各为一次取证协议服务且产物路径互不相同；`coldboot-collect` 与 `por-rounds` 的重复面已在 §1-6 以「薄包装」定性并给合并口径，暂不并 |
| `scripts/flash-b.sh` / `sign-boot-b.sh` / `flash-recovery.sh` | 目标分区不同（boot_b / boot_b 签名 / recovery_b），11-06 §3 结论沿用 |
| `scripts/check-abi-config.sh` 的 `config-vk127-working-*` 默认 | 改默认值必须与 `TASKS` §4「vk189 上机通过后指到 `config-vk189-suspend-20261112`」同批做，**否则会把已知红灯变成真红灯**（§2-13） |

### F. 执行顺序与验收

1. 顺序：**A1/A3（门，先建门）→ B1/B2（P0）→ B5/B3/B4 → A4/A5/A6 → B6–B11 → C 全部 → D1 → D2**。
2. 每批之后验收（全部主机侧、可离线）：
   `bash -n` 全量：`for f in scripts/*.sh scripts/doctor/*.sh; do bash -n $f \|\| echo "SYNTAX $f"; done`；
   `bash scripts/check-doctor.sh` 期望 **FAIL=0 WARN=0**（当前若有既存 WARN 需先记录基线数再比）；
   `python3 scripts/static-scan.py --root "$PWD" --tsv` 期望 `BASHISM -`、`DEAD -`；
   `bash scripts/test-lib-wait.sh` 期望 `ALL PASS`（若动了等待层）；
   `bash packaging/elden-userland/tools/verify.sh --rebuildable` 期望 `FAIL=0 WARN=0`（动了 `files/`/`MANIFEST` 时）。
3. 需要设备窗口的只有：B10（设备侧 `pkill/pgrep` 改写）、D1 的设备侧文件清理、C3 里 `start-desktop.sh`/`bt-up.sh` 的现役性确认。
4. 全仓回滚：本清单若按批提交，逐批 `git revert <sha>`；单文件回滚见 D1/D2 的「回滚」列。

---

## §5 未证 / 盲区（不混进结论）

1. **设备侧真实现状未取**（本轮禁止碰设备）：① `/usr/local/sbin/ath12k-load.sh` 在机上是否真存在且无人跑；
   ② `charge-watch`/`qbootctl.service`/`ath12k-retry.service` 在机 enable 状态；
   ③ `/etc/init.d/qbootctl` 是否还存在（决定 C2 的 `RETIRED` 措辞）。
   验证命令（下一个设备任务）：`ssh root@192.168.7.1 'systemctl is-enabled ath12k-retry charge-watch qbootctl 2>&1; ls -l /usr/local/sbin/ath12k-load.sh /etc/init.d/qbootctl 2>&1'`。
2. **`static-scan.py` 的 `live` 计数含 `reports/`？** 已核：`corpus()` 不排除 `reports/`，但 `verdict` 的 live/hist 分类只看「入口文档 + 代码目录」，故我引用的 live=0 结论可用；**未核**：它对 `PITFALLS/README.md` 里「脚本改名史」这类提及是否算 live（会影响 §2-8 的重刷结果，重刷后需人工过一遍新 HIST-ONLY 名单）。
3. **`#584` 的 2 处残余是否仍在实际路径上被走到**：我只做了静态确认（可执行行 + 无 `timeout` 保护差异）。`trial.sh` 的 `--deploy fastboot-boot` 分支是否还在用，需要一次 `trial.sh run --help` 级别的确认。
4. **`scripts/q28-watchdog.sh` 的 systemd 化改法未验证**：我给的是方向（unit + `is-active` 校验），具体 unit 名/`ExecStartPost` 形态要看 `packaging/elden-userland/services.tsv` 里 `q28-boot-watchdog` 是否已登记（本轮未逐行读该表的 21 行以外内容）。
5. **13 条缺陷里没有「锁前写」「`--dry-run` 被覆盖」「bashism」**：三者本轮逐条读文件核实**已不存在**（见 §3 表前说明与最后一行），不是没查。

6. **树在被并发修改（执行前必读）**：本审计期间 `git status` 已有他人 lane 的未提交改动
   （`scripts/deploy-v4l2loopback.sh` 于 21:50 新建、`rootfs/debian/ime/*` 于 22:12 改动），
   均**早于**本文件创建时间 22:23（本文件是唯一产物，未改任何被审计文件）。
   因此执行 §4 前**必须逐条重跑该行「证据命令」**再改；本文件所有 P0 与 §2-2 已在 22:33 二次复核通过：
   `arm-console-run.sh:14` / `trial.sh:186` 两处管道仍在、`ath12k-load` 调用点仍为 0、
   `ath12k-load.sh:36` 与 `ath12k-retry.sh:50-51` 的 bind 语义差仍在、`kbuild-sanity.sh:26` 默认树仍不存在、
   `rg -c packaging scripts/doctor/*.sh` 仍 0 命中。
