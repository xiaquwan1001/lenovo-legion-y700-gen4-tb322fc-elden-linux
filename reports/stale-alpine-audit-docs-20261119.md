# 文档层「过时 Alpine 件」审计（只读，2026-11-19）

- **判据现态**：自建最小 Debian 13 trixie 根（systemd PID1、1253 包）+ 主线 vk192；`reboot2` / `eldroid-bootctl` / OpenRC(`rc-service`/`rc-update`/`/etc/local.d`) / `apk` / `/init` 作 PID1 / `doas` / 设备侧 `python3` **均不存在**。
- **实测校核依据（本轮现查，非印象）**：
  - `INDEX.md:36` + `TASKS/README.md:149`（2026-11-19 下午，桌面已起之后）：「设备无 python3 ⇒ dd LUN4 主备 GPT → 主机 `slot-attr.py --image`」——非旧账，是现态；
  - `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md:73`（2026-11-19 14:55）：「minbase 根没有 `reboot2`/`eldroid-bootctl`（那两个是 Alpine 期件）」；
  - `DEVICE/README.md:131`（`PITFALLS #650`）：「进 fastboot 用 `ssh elden-root 'sync; reboot bootloader'`，**不要**用 `scripts/to-fastboot.sh --boot`」；
  - 现役服务单元是 systemd 形态：`packaging/elden-userland/out/units/systemd/net-selfheal.service`、`rootfs/debian/stage.sh:409-414`（`wifi-scan-refresh.service` / `elden-hapticd.service`）。
- **只读边界**：仅 `read`/`grep`/`sed -n`/`ls`/`wc`；未 ssh/adb/fastboot/qdl，未改任何仓库文件（本报告为唯一产物）。

## 结论排序表（C → B → A）

| 类别 | 文件:行 | 原文片段 | 为什么过时 | 建议处置 |
|---|---|---|---|---|
| C | `.pi/AGENT-OPS.md:57-58` | 「**进 fastboot 的唯一入口 = `scripts/to-fastboot.sh`** … 它内部走 `eldroid-bootctl reboot bootloader` 且带 6 s sysrq-b 兜底」 | 这是 agent 行为唯一入口文件（§2 设备安全纪律）。它把「必走 to-fastboot.sh」写成硬指令，而该脚本 `scripts/to-fastboot.sh:54` 是 `ssh … 'sync; eldroid-bootctl reboot bootloader'`——现根没有 `eldroid-bootctl`（且它是 python3 脚本，设备无 python3）⇒ 命令静默失败（`\|\| true`），随后白等 90 s 判 fastboot 超时 | 改成：**首选 `ssh elden-root 'sync; reboot bootloader'`（systemd 正常关机，`PITFALLS #650`）**；`scripts/to-fastboot.sh` 降为 `--flash`（设备内 dd 写 boot_b）用途，`--boot` 明确不推荐；补一句「minbase 根无 `eldroid-bootctl`/`python3`」 |
| C | `RUNBOOK-BRINGUP/README.md:427-428` | 「**Linux → fastboot**（必要时）：`scripts/to-fastboot.sh …` / 走 PSCI vendor reset（`eldroid-bootctl reboot bootloader`，vk41+）——**这是唯一可靠路径**」 | 同上，且与 `DEVICE/README.md:131`（#650）「不要用 to-fastboot.sh --boot、用 systemd reboot arg」直接冲突；照跑会 90 s 超时后停手，误判「ABL 不认 reboot 参数」 | 该条改成 systemd `reboot bootloader` 为主路径，把 `eldroid-bootctl` 标为「Alpine 期、现根无此件」；`--flash` 用途保留 |
| C | `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md:217` | `scp scripts/slot-attr.py root@192.168.7.1:/tmp/ ; ssh root@192.168.7.1 'python3 /tmp/slot-attr.py mark-successful b'` | S7 首选步骤在**设备侧**跑 `python3`，设备无 python3 ⇒ `python3: command not found`，槽属性不会被写。同文件 2026-11-19 的 S6/S8 已是新口径，唯独 S7 漏改；而 `INDEX.md:36`/`TASKS:149` 已给出正确做法 | 改成现口径：设备 `dd` 读 LUN4 主备 GPT → 主机 `python3 scripts/slot-attr.py --image … mark-successful b` → `dd` 写回 + 读回核验（保留「或从主机侧直接改双表」这行作为唯一路径，删掉「scp 到设备再跑」这半句） |
| C | `RUNBOOK-BRINGUP/f2fs-migration.md:70` | 「\| 服务 \| `rc-status` 无 crashed；`qbootctl` 在 default 里 \|」 | f2fs 迁移 runbook 的验收判据用 OpenRC 的 `rc-status`/runlevel 概念；现根 systemd，`rc-status` 不存在 ⇒ 判据无法执行、易被误判为失败 | 该文件整体标「**已作废（2026-10-31 并根）**」横幅（见下一行 B 项），判据行改为 `systemctl --failed` 为空 + `systemctl is-enabled qbootctl`（或直接删该行） |
| C | `TASKS/README.md:54`（G1-32） | 「**OpenRC 化（init 交接…）** ✅ 已完成（2026-10-06 U2）… 回退 `echo legacy >/etc/elden-init-mode; reboot`。 \| 判据 `rc-status` default 全 started + `ps -p 1` = `/sbin/init`」 | §1 是「功能健全的 Linux」现行账。该行的验收判据（`rc-status`）与回退命令（写 `elden-init-mode`）在 systemd 根上都不成立：判据命令不存在；回退写文件后 `/init` 的 openrc 分支（`initramfs/init:287`）只是 `exec /sbin/init` = 又是 systemd ⇒ 回退=空操作 | 行首加 **「⛔ 已被 Debian+systemd 根取代（2026-10-31 并根）」**；判据换成 `systemctl --failed` 空 + `ps -p1 -o comm=` = `systemd`；删掉回退命令 |
| B | `TASKS/README.md:535` | 「**宿主用户态** GL/Vulkan \| Alpine `mesa-dri-gallium`(freedreno) + `mesa-vulkan-freedreno`(Turnip) + `mesa-egl` + `vulkan-loader` \| ❌ **apk 预制、零编译**」 | §6-C「GPU 栈编译量」是读者判断「要不要编 Mesa」的现行表；它把宿主用户态写成 apk 包名，今天在 Debian 上找这些名字会找不到（包名是 `mesa-vulkan-drivers`/`libgl1-mesa-dri`） | 组件列改 Debian 包名并注明「现根 = Debian 13，`apt` 预制；结论「零编译、不打 chip-id 补丁」不变」 |
| B | `RESOURCES/README.md:29` | 「**宿主**：Alpine apk 预制（`mesa-dri-gallium` + `mesa-vulkan-freedreno`），**零编译**」 | 同上：读者会去 `apk add`。事实（零编译、用原版）仍成立 | 换成 Debian 包名 + 「（Alpine 期为 `mesa-dri-gallium`/`mesa-vulkan-freedreno`）」括号沿革即可 |
| B | `RESOURCES/README.md:197` | 「**GPU 栈编译账（2026-10-06）**：宿主用户态 **0 编译**（Alpine apk）」 | 结论未变、渠道已变；作为「编译量核账」的现行依据会误导装包路径 | 「（Alpine apk）」→「（现根 Debian `apt` 预制，原 Alpine 期为 apk）」 |
| B | `RESOURCES/README.md:92` | 「**`qbootctl`**（Alpine community）\| … \| ✅ **已采纳**（取代 `slot-attr.py` 常用操作，`PITFALLS` #126）」 | 「已采纳、取代 slot-attr.py」与近两轮实践相反：2026-11-18/19 的槽操作主路径是 `slot-attr.py`（主机侧 `--image`）+ `fastboot --set-active`，`PITFALLS #677`（切槽两工具语义不同）刚刚把 eldroid-bootctl/属性直写定为唯一可信组合；来源标注仍指 Alpine community，而现由 `rootfs/debian/pkgmap.tsv` 进包 | 结论行改为「◐ 设备侧可读状态（`qbootctl` 仍可用）；**改属性/切槽以 `slot-attr.py` + `fastboot --set-active` 为准（#677）**」，来源标注加「现由 Debian pkgmap 提供」 |
| B | `RESOURCES/README.md:107` | 「⚪ **G3 新选项**：官方 arm64 Steam + FEX …（**需 Alpine 侧自建 FEX/gamescope**）」 | 「Alpine 侧」已不是宿主发行版；G3 若照此排期会去准备 apk 构建环境 | 「需在现根（Debian 13）自建 FEX/gamescope，或改用发行版包」 |
| B | `DEVICE/README.md:167` | 「运行期只剩宿主 daemon `elden-hapticd`（**OpenRC + `/etc/conf.d`**）与一条 `sys/class/leds` 桥挂载」 | 陈述「在机资产现态」，但 `elden-hapticd` 现是 systemd 单元：`rootfs/debian/stage.sh:412` 校验 `usr/lib/systemd/system/elden-hapticd.service`；`/etc/conf.d` 只存在于 Alpine 期 overlay（`rootfs/persistent-overlay/etc-conf.d-elden-hapticd`） | 改「（systemd `elden-hapticd.service`，源 `packaging/elden-userland/out/units/systemd/`）」，其余（vendor.img 固化、回退件 sha）不动 |
| B | `DEVICE/README.md:346` | 「\| Linux rootfs（**Alpine** + 桌面 + Mesa + 工具） \| 装开后 **15–20 GB**」 | §3.1 容量估算表是**当前**给分区的依据，读者会按「Alpine 根」体量估；现根是 Debian（同一实测口径未重测） | 改成「Linux rootfs（Debian 13 最小根 + 桌面 + Mesa + 工具）」并注明「15–20 GB 为 Alpine 期实测，Debian 档待按 `df /` 现测回填」 |
| B | `TASKS/README.md:57`（G1-35） | 「自愈脚本 `scripts/net-selfheal.sh`…**触发 = OpenRC `local`（等 wlan0 UP）+ `NM dispatcher.d`**」；关键文件 `rootfs/persistent-overlay/{etc-local.d,…}.tar.gz` | 现役触发是 systemd：`packaging/elden-userland/out/units/systemd/net-selfheal.service`（`PITFALLS #475` 的 `net-selfheal.pre` 就是 systemd 侧改写）。读者去 `/etc/local.d` 找会扑空 | 触发改成「systemd `net-selfheal.service`（+ `.pre` 等网卡）+ `NM dispatcher.d`」；关键文件换成 `packaging/elden-userland/out/units/systemd/net-selfheal.service`，`persistent-overlay/*` 标「Alpine 期」 |
| B | `TASKS/README.md:58`（G1-36） | 「**修复** = `wifi-scan-refresh` **OpenRC 服务**」；关键文件 `rootfs/persistent-overlay/etc-initd-wifi-scan-refresh`、`etc-conf.d-wifi-scan-refresh` | 同上：现是 `wifi-scan-refresh.service`（`rootfs/debian/stage.sh:409` 校验间隔 <180 s），`etc-initd-*`/`etc-conf.d-*` 是 Alpine overlay 件 | 服务名/单元路径换 systemd；判据 `wifi-scan-refresh.sh --check` 不变（仍有效） |
| B | `TASKS/README.md:345`（Q34） | 「**`bluetoothd` 冷起偶发 crash**（`rc-service bluetooth stop/start` 后正常）」 | Q 表的「现象」列用 OpenRC 命令描述复现动作；今天照着跑会 `rc-service: not found`，可能被误读成「现象不可复现」 | 改成 `systemctl restart bluetooth`（并标「原记为 Alpine `rc-service`」）；处置正文（缺 `qca/tmel_peach_20.elf`，补文件才对）不动 |
| B | `PITFALLS/README.md:232`（#525） | 「纪律：**每轮崩溃实验后核 `eldroid-bootctl slot info`**，必要时 `slot set-retry 7 b` 补回余量」 | 纪律本身仍成立，但指定的设备侧工具已不存在（设备无 `eldroid-bootctl`/`python3`）⇒ 照做会 command not found，或误以为「已核过」 | 换成 `qbootctl`（设备侧只读）+ 主机 `python3 scripts/slot-attr.py show/set-retry`；原文保留为历史结论，只改命令名 |
| B | `RUNBOOK-BRINGUP/f2fs-migration.md:3` | 「状态：**已执行完成（2026-10-25 真机）** —— 根现为 `f2fs @linux18`，… ext4 `linux17`（96 GiB）保留为回退根」 | 「根现为…」是**当前态**陈述，已失效：`DEVICE/README.md:157/365` 记载 2026-10-31 linux18 已删、根 = `linux17` ext4（Debian）。读者会据此认为还有 f2fs 回退根 | 顶部加「**⛔ 已作废（2026-10-31 并根：linux18 已删）**，仅存档」；正文保持原样（含 5 条工具级坑的指针仍有效） |
| B | `AGENTS.md:44` | 「设备侧脚本只写 **POSIX sh**…busybox `pgrep -x` 恒假阴性（用 `ps -eo comm \| grep -cx`）」 | 前提（设备侧用 busybox applet）是 Alpine 期特征；现根 `pgrep` 来自 procps-ng、`busybox` 只装 `/bin/busybox` 无 applet 链接（`PITFALLS #422`）。推荐命令 `ps -eo comm` 仍安全，故低危，但「busybox 恒假阴性」会被当成今天的判据 | 改为「（Alpine 期用 busybox applet 时 `pgrep -x` 恒假阴性；现根为 procps-ng `pgrep`。设备侧统一用 `ps -eo comm \| grep -cx` 免分发行版）」 |
| A | `TASKS/README.md:46`（G1-24） | 「`scripts/eldroid-bootctl` + `flash-recovery.sh` … `reboot2 bootloader` → 22 s 进 fastboot」 | 有日期（2026-10-03/08）的沿革账，读作历史不会照跑脚本；且本条内核侧结论（PSCI RESTART2）仍有效 | 只登记；建议在该行末尾加半句「（设备侧前端 `eldroid-bootctl` 已于并根后退场，现用 systemd `reboot bootloader`）」 |
| A | `TASKS/README.md:47`（G1-25） | 「根因=elogind helper `/sbin/{poweroff,reboot,halt}` 是 busybox applet…修复=`scripts/fix-logind-poweroff.sh`」 | 2026-10-03 日期明确；现 systemd 根上 `/sbin/poweroff` 为 systemd 自带，问题域消失 | 只登记（可在行尾加「随换根失效」） |
| A | `TASKS/README.md:48`（G1-26） | 「用户态深色模式…（Phosh 0.55，**Alpine**）」 | 明写发行版+日期，属历史验证记录 | 只登记 |
| A | `TASKS/README.md:52/53`（G1-30/G1-31） | 「真机 busybox **有 findfs、无 blkid/mountpoint**（#112）」；「`coreutils …`（735→760 包，world 104→120 行）…**重启回归 ×2 通过**」 | 明写在机日期与当时包数，结论已被 Debian 根取代 | 只登记 |
| A | `TASKS/README.md:59`（G1-37） | 「根因 = 两张清单覆盖面差（`apt-list.txt` 源自 Alpine `apk-world`）」 | 自述沿革（「源自」），且已给现役三件套（`rootfs/debian/daily-baseline.tsv` 等） | 只登记 |
| A | `INDEX.md:303` | 「宿主 rootfs 方向（**Alpine → Debian/Mobian**，2026-10-26 用户定）」 | 带日期与「方向」字样，明确是迁移沿革 | 只登记 |
| A | `DEVICE/README.md:157/365/371` | 「历史条目里「回退 = 重启回 Alpine `linux18` f2fs」的口径**已失效**」；「**Alpine 秒级回退随之退役**…（T19 旧口径作废）」 | 已显式标注「已失效/作废」，正是期望的写法 | 只登记（可作为其它条目的改写范本） |
| A | `PITFALLS/README.md:126/128/144/145/146`（#399/#397/#419/#420/#422） | 「OpenRC oneshot 用 `command=` 起…」「OpenRC `after elogind` 只定顺序…修法 = `start_pre` 里等…」 | 有会话文件+日期锚定，且 #419/#420 的**机理**（服务就绪不等于依赖就绪、串行 oneshot 里 sleep 阻塞）在 systemd 侧同样成立 | 只登记；若日后有人照抄 `start_pre` 语法，再补一条 systemd 对照（`ExecStartPre=` + `After=`/`Wants=`） |
| A | `PITFALLS/README.md:164`（#455） | 「13 条 openrc 专属路径在 systemd 根上本就不存在 ⇒ 门禁按画像跳过」 | 该条本身就是「换根后假 FAIL」的定案记录，已把 OpenRC 归为旧画像 | 只登记 |
| A | `AGENTS.md:58` | 「81 条设备侧细粒度坑（**Alpine/busybox**、Waydroid 容器状态机…）：`.pi/memory/failures-device.md`」 | 只是记忆文件的**内容描述**，不是可执行口径 | 只登记 |

## 核过、但**不算过时**的关键词命中（避免夸大数量）

| 文件:行 | 命中 | 核验结论 |
|---|---|---|
| `INDEX.md:36`、`TASKS/README.md:149` | 「设备无 python3」 | **现态为真**（2026-11-19 下午、桌面已起之后），且正是 `LINUX-STATE-REPRO.md:217` 应改成的口径；不要当旧账删 |
| `RESOURCES/README.md:147`、`INDEX.md:314-317,343`、`RUNBOOK-BRINGUP/README.md:139,251,277,311,319`、`ZERO-TO-DESKTOP.md:77-81`、`LINUX-STATE-REPRO.md:124,160-177` | `python3 scripts/…` | 全部是**主机侧** repo 脚本调用（设备侧无 python3 不影响），仍可直接跑 |
| `RUNBOOK-BRINGUP/README.md:68` | 「Debian 根的 busybox 有 applet 无符号链接，靠 `/init` 的 `usb0_dhcp()` 回退调用（#430）」 | 已是 Debian 口径，正确 |
| `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md:73` | 「minbase 根没有 `reboot2`/`eldroid-bootctl`…用 systemd 的 reboot arg」 | **最新正确写法**，建议作为 C 类三条改写的模版 |
| `PITFALLS/README.md:129`（#400）、`RUNBOOK-BRINGUP/f2fs-migration.md:5` | 「设备无 `python3` ⇒ 偏移算空产出 0 字节 GPT dump」 | 与现态一致（仍是坑，不是过时） |
| `RUNBOOK-BRINGUP/GPT-MINIMAL-DESIGN.md:206` | 「`/init` 解析 `elden_root=` 走 busybox `findfs`」 | 与在机 `/init` 注入路径一致（2026-11-19 已注入 `/init`），词条有效 |
| `TASKS/README.md:96`（C11）、`232`（T17）、`459`、`104`（A11） | 「Alpine 世代」「Alpine→Mobian 迁移」「Alpine 不现实」 | 均自带世代/日期限定词，属明确的历史界定 |

**范围外线索（供合并时一起改，本轮未列入上表）**：`rootfs/persistent-overlay/README.md:41-45` 仍把「OpenRC 模式 = `exec /sbin/init` → openrc」与 `echo legacy >/etc/elden-init-mode` 写成可执行流程；`initramfs/init:287` 的 `elden-init-mode` 分支亦然——在 Debian 根上该分支只是再 `exec` 一次 systemd，属「无害但无用」的残留。

■ 结束

---

# 附录 A：第二轮独立审计（2026-11-19，按「件是否在盘」重核；与上表重叠的取上表，此处只列增量与相左点）

> 方法补充：对上表未覆盖的**件存在性**逐条 `ls` 核对（`out/boot-elden-vk40*.img`、`out/modules-7.2.0*.tar.gz`、
> `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz`、`bootslot-b/boot_b_vk40*.img` **均不在盘**），
> 以及「分区号/fs label 已变」这类**会直接导致起不来或毁数据**的项。计数：**C 9 条 / B 3 条 / A 0 条（增量）**。

| 类别 | 文件:行 | 原文片段 | 为什么过时 | 建议处置 |
|---|---|---|---|---|
| C | `RUNBOOK-BRINGUP/f2fs-migration.md:79`（步骤在 `:48` `:55`） | 「要重建 f2fs 只需 `mkfs.f2fs -l linux18 /dev/sda18` 再复制」；正文 `bash scripts/f2fs-migrate.sh shrink --yes` | ①`linux18` 已于 2026-10-31 删除并入 `linux17`；②**`/dev/sda18` 现在是 ESP**（`DEVICE/README.md:141`「ESP（`/dev/sda18`）」）⇒ 照做直接 mkfs 掉 GRUB/Loader/boot.img 所在的 FAT32。这是本族里**唯一有破坏性**的一条 | 顶部加 `⛔ 作废（2026-11-19）：linux18 已删、/dev/sda18 现为 ESP；勿执行`；`shrink`/`writeslot` 在脚本侧标 `--retired` |
| C | `RUNBOOK-BRINGUP/README.md:51` + `:350-351` | 资产表「**持久 rootfs 归档** `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz`」；步骤 `scp … /tmp/` → `tar xzf … -C /mnt/new` | ①该文件**不在盘**（`ls env-pass/` 只剩 `scripts/ tools/`）；②它是 2026-10-02 的 **Alpine(musl/OpenRC)** 根，铺出来是 Alpine 不是 trixie；③label `linux17` 与现役 `elden_root=LABEL=linux` 不符（照装 = 找不到根 → `panic=15`） | 两处删除，Phase 4 改指 `ZERO-TO-DESKTOP.md` S3（EDL 写 minbase ext4）+ S9（`resize2fs`）；资产表该行标「作废（Alpine 期件，已不在盘）」 |
| C | `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md:207`（S6） | `tar xzf env-pass/backup-*/linux17-rootfs-*.tar.gz -C /mnt/new` | 同上；且**同文档 `:296` 自认「rootfs 无全量归档」**，一处说无归档一处给解包命令 | S6 改「无归档 ⇒ 走 ZERO-TO-DESKTOP S3 + S10/S11 收敛」，与 `:296` 合并成一句 |
| C | `RESOURCES/README.md:159` | 「**持久 rootfs 归档** `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz` \| 3.44 GB / 30852 项，tar/gzip 完好」 | 状态列写「完好」而文件**不在盘**；这是上面两条步骤的执行源（台账失信会让读者先怀疑自己命令写错） | 状态列改「⛔ 已不在盘（2026-11-19 核）；Alpine 期件，恢复链已改 minbase + `resize2fs`」 |
| C | `RUNBOOK-BRINGUP/README.md:49`（步骤 `:353-357`） | 「**全模块包** `out/modules-7.2.0-debug-gba28ec16f01f-dirty.tar.gz` … 1484 个 `.ko`」；`depmod -b /mnt/new 7.2.0-debug-gba28ec16f01f-dirty` | ①文件不在盘（`RESOURCES:156` 自己也记 MIGRATION-LOST）；②7.2.0 vermagic ≠ 现役 UTS `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0` ⇒ 模块全废（`DEVICE:145` 模块树硬规则） | 改指 `scripts/deploy-modules` + `DEVICE` §1.1 的 1510 `.ko` 台账 |
| C | `RUNBOOK-BRINGUP/README.md:46-48`（步骤 `:262-268`、`:400-404`） | 「RAM 版内核 `out/boot-elden-vk40-ram.img`」「持久版 `out/boot-elden-vk40.img`」「`bootslot-b/{boot_b_vk40-ram.img, boot_b_vk40.img, dtbo_b.img, vbmeta_b_flags3.img}`」 | 路径**全部不在盘**（`ls` 实测）⇒ Phase 2/5 的 `fastboot flash boot_b bootslot-b/boot_b_vk40*.img` 必然失败 | 4 行标作废，改指 `bootslot-b/boot_b-minbase-labellinux-20261119.img` / `out/boot-elden-vk192.img` |
| C | `RUNBOOK-BRINGUP/README.md:337/344` | 「## 5. Phase 4 — 建 `linux17` 并恢复持久 rootfs」/ `mkfs.ext4 -L linux17 /dev/disk/by-partlabel/linux17` | 现役 boot cmdline = `elden_root=LABEL=linux`（`DEVICE:32`），fstab 也是 `LABEL=linux`（`GPT-MINIMAL-DESIGN:206`）⇒ 按本文装出的根 label 是 `linux17`，**装完起不来**（同源事故 `TASKS:163`） | `mkfs.ext4 -L linux …`，并在小节抬头写「label 必须 `linux`，`linux17` 只是历史分区名」 |
| C | `INDEX.md:335` | `./cycle.sh --soft                          # 软回 fastboot（免按电源键）` | 同仓 `.pi/AGENT-OPS.md:58` 已判「`cycle.sh --fastboot/--soft` 实测到不了 ABL，不再使用」；`cycle.sh:23` 实现就是 `echo b > /proc/sysrq-trigger`（暖复位可能回 Linux） | 换成 `ssh elden-root 'sync; reboot bootloader'`，或删行指 `PITFALLS #65/#66` |
| C | `INDEX.md:336` | `fastboot boot bootslot-b/boot_b-f2fs-root.img  # 零写盘·持久变体…功能测试用` | 该件 cmdline = `elden_root=LABEL=linux18`（`RESOURCES:167`），`linux18` 已删 ⇒ 起不来（panic 回 fastboot），但被标成「功能测试用持久变体」 | 换成现役件；f2fs 件标作废 |
| B | `DEVICE/README.md:44` | 「`ath12k` MHI `-110`、无 `/dev/fastrpc-adsp`、`snd-sc8280xp` deferred（均 ADSP/GPR 未就绪）」 | 与紧邻上文 `:40-41`「**已愈（2026-11-19 13:20）**…同根因下游（ath12k `-110`、无 `/dev/fastrpc-adsp`、snd deferred）**全部随 `apt install udev` 消失**」正反两说，同一段内 | 删该半句或移进 `⟪历史定界⟫` 块 |
| B | `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md:227`（S8 验收） | 「`uname -r` = 台账 UTS → `/` = `linux17` → `lsmod \| wc -l` ≈ 台账」 | 现役根 fs label = `linux` ⇒ `findmnt /` 不再出现 `linux17`，合格状态会被判不合格 | 改「`/` = `LABEL=linux`（`/dev/sda17` ext4）」，注明 `linux17` 仅是 GPT 条目名 |
| B | `INDEX.md:41` | 「**现态**：`ssh root@192.168.7.1` … / **165 包** / `/` 2.0 of 5.9 GiB」 | 该块写「现态：165 包」，而今天现态 = 1253 包、`/` 190 GiB、桌面已起（同节 `:29-33`）；`INDEX` §2 要求「当前口径」只允许一处 | 数字改「当时 165 包」或删数字留指针 |

## 附录 A 的「核过但不列为过时」

- `RUNBOOK-BRINGUP/README.md:68`「Debian 根的 busybox 有 applet 无符号链接…（#430）」= 已是 Debian 口径，有效。
- `RUNBOOK-BRINGUP/GPT-MINIMAL-DESIGN.md:206`「`/init` 解析 `elden_root=` 走 busybox `findfs`；用 LABEL 不用 PARTLABEL」= 与在机 `/init` 一致，有效。
- `DEVICE/README.md` §1.1 同日口径（`elden_root=LABEL=linux`、`slot-successful:b=yes` 走主机侧 `slot-attr.py --image`）= 目前**最新且自洽**的写法，宜作 C 类改写的模板。

