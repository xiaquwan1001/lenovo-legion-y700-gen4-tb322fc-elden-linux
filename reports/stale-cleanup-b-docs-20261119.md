# 文档层「过时 Alpine 件」清理（B/C 类落地，2026-11-19）

- **任务范围**：文档层 10 个文件（`INDEX.md`、`TASKS/README.md`、`DEVICE/README.md`、`RUNBOOK-BRINGUP/{README,LINUX-STATE-REPRO,ZERO-TO-DESKTOP}.md`、
  `PITFALLS/README.md`、`RESOURCES/README.md`、`.pi/AGENT-OPS.md`、`AGENTS.md`）。**未动**任何 `scripts/`、未动 `RUNBOOK-BRINGUP/f2fs-migration.md`（已有作废头）、
  未执行任何设备命令。
- **依据**：`reports/stale-alpine-audit-docs-20261119.md`（C 17 / B 12 / A 12）。
- **判据基线（现态）**：自建 Debian 13 trixie 根（systemd PID1、1253 包、greetd+phoc+phosh、Mesa 26.1.6）、内核 vk192、
  根 fs label = `linux`（`/dev/sda17`）、Linux→fastboot 软路径不存在（`PITFALLS #690`，只能长按电源 10 s → 音量上+电源）。
- **自检**：① `bash scripts/check-progress-counts.sh` → `G1 36/37`、`G2 10/13`（与 selftest 口径一致，§1 状态标记未动）；
  ② 新增/改写引用路径逐个 `ls` 存在（`scripts/deploy-modules.sh`、`scripts/slot-attr.py`、`bootslot-b/boot_b-minbase-labellinux-20261119.img`、
  `out/boot-elden-vk192.img`、`packaging/elden-userland/out/units/systemd/{net-selfheal,wifi-scan-refresh}.service`、`rootfs/debian/pkgmap.tsv`）；
  ③ `git status` 只有 10 个文档被改（无脚本改动）；④ 表格管道完整性扫描：本轮改动行无破损。
- **统计**：C 类 12 条可执行项全部落地（其中 `f2fs-migration.md` 相关 3 条按指示跳过，该文件已有 2026-11-19 作废头；`LINUX-STATE-REPRO.md:217` 上一轮已改好，本轮复核确认）；B 类 12 条全部落地（另补 1 条漏项 C/B）；A 类 12 条只在 2 处补「历史」限定，其余保持原样。

---

## 一、C 类（改成今天可执行的说法 / 加作废头）

### C1 `.pi/AGENT-OPS.md:57-62`（原 57-58）
- 原文：`**进 fastboot 的唯一入口 = scripts/to-fastboot.sh** … 它内部走 eldroid-bootctl reboot bootloader 且带 6 s sysrq-b 兜底；…不再使用。停手判据 = …请用户断电。`
- 新写：`**进 fastboot 的首选路径 = ssh elden-root 'sync; reboot bootloader'**（PITFALLS #650）；**2026-11-19 起软路径默认拒绝（PITFALLS #690）**：… eldroid-bootctl（python3 件）与 python3 在现役 Debian 根上都不存在 ⇒ --boot 静默失败并白等 90 s；… to-fastboot.sh 只保留 --flash 用途，--boot 明确不推荐。**软路径失败即转手工**：长按电源 10 s 断电 → 音量上 + 电源进 fastboot。`
- 理由：agent 行为唯一入口文件把不可执行命令写成硬指令（脚本 `--boot` 走 `eldroid-bootctl` + `|| true` 吞错）。

### C2 `RUNBOOK-BRINGUP/README.md:436-441`
- 原文：`**Linux → fastboot**（必要时）：scripts/to-fastboot.sh [--flash …] [--boot …]` / `走 PSCI vendor reset（eldroid-bootctl reboot bootloader，vk41+）——这是唯一可靠路径；`
- 新写：主路径 `ssh elden-root 'sync; reboot bootloader'`；⛔ 作废块说明 vk192 无 vendor RESTART2 钩子 + 无 `eldroid-bootctl`/`python3`，并保留 `--flash` 用途、`--boot` 不推荐、软路径失败转手工。
- 理由：与 `DEVICE/README.md:131`（#650）直接冲突，照跑 90 s 超时后会误判「ABL 不认 reboot 参数」。

### C3 `RUNBOOK-BRINGUP/README.md:432`
- 原文：`…并保留 to-fastboot.sh + fastboot boot 作为带外回退。`
- 新写：`…并保留 fastboot boot 作为带外回退。`
- 理由：同上，回退链不应再引导到已失效入口。

### C4 `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md:203-218`（S6）
- 原文：`tar xzf env-pass/backup-*/linux17-rootfs-*.tar.gz -C /mnt/new` / `tar xzf out/modules-<UTS>.tar.gz … && depmod -b /mnt/new <UTS>`
- 新写：抬头写「该归档不在盘 + 属 Alpine/musl/label linux17 世代，与本文 `:306`『rootfs 无全量归档』自相矛盾，已按后者收口」；
  命令改成「建根 = EDL 写 minbase ext4（`ZERO-TO-DESKTOP.md` S3）；模块 = `bash scripts/deploy-modules.sh`」，保留 `/boot` 件与 `phoc-install.sh` 两行。
- 理由：同文档一处说无归档、一处给解包命令；且该 tar 不存在。

### C5 `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md:242`（S8 验收）
- 原文：``uname -r` = 台账 UTS → `/` = `linux17` → …`
- 新写：``/` = `LABEL=linux`（`/dev/sda17` ext4；`linux17` 仅是 GPT 条目名）`
- 理由：现役 fs label 是 `linux`，旧判据会把合格状态判成不合格。

### C6 `RUNBOOK-BRINGUP/README.md:44-58`（§0 资产表）
- 原文：6 行资产（vk40 RAM/持久件、`bootslot-b/boot_b_vk40*`、`modules-7.2.0-…tar.gz`、`linux17-rootfs-20261002.tar.gz`）无任何失效标记。
- 新写：表前加 ⛔ 块（四个路径 `ls` 实测不在盘 + 属 Alpine/label `linux17` 世代 + 指向 `LINUX-STATE-REPRO.md`/`ZERO-TO-DESKTOP.md`）；4 行逐条标 ⛔ 并给现役替代件。
- 理由：Phase 2/4/5 的执行源，路径不存在会让读者先怀疑自己命令写错。

### C7 `RUNBOOK-BRINGUP/README.md:262-267`（Phase 2）
- 原文：`## 3. Phase 2 — b 槽直启「RAM 版 vk40」（首次上机，零写盘）` + 直接给 `flash boot_b bootslot-b/boot_b_vk40-ram.img`
- 新写：标题去 vk40；标题下加 ⛔ 作废块（三件 `ls` 不到 ⇒ 照跑必失败）+ 替代件 `bootslot-b/boot_b-minbase-labellinux-20261119.img` + 指向现链手册；原命令段保留为存档。
- 理由：审计附录 A 首条同源：Phase 2 必失败。

### C8 `RUNBOOK-BRINGUP/README.md:347-364`（Phase 4）
- 原文：`## 5. Phase 4 — 建 linux17 并恢复持久 rootfs` / `mkfs.ext4 -L linux17 /dev/disk/by-partlabel/linux17` / 两段 `scp … tar xzf`
- 新写：标题改「建根分区（fs label 必须 `linux`）」；`mkfs.ext4 -L linux`；删两段归档步骤，改为「历史（Alpine 期，已不可执行）」块 + 指 `LINUX-STATE-REPRO.md` S3/S6/S9 + `scripts/deploy-modules.sh`。
- 理由：现役 cmdline/fstab 都是 `LABEL=linux`，装出 `linux17` 直接起不来（同源事故）；两个归档都不在盘。

### C9 `RUNBOOK-BRINGUP/README.md:374-378`（Phase 5）
- 原文：`fastboot flash boot_b bootslot-b/boot_b_vk40.img     # 已签名的持久版`
- 新写：`fastboot flash boot_b bootslot-b/boot_b-minbase-labellinux-20261119.img   # 现役持久件（vk192 核，cmdline LABEL=linux）` + ⛔ 一行说明旧名不在盘。
- 理由：同 C6/C7，路径不存在。

### C10 `INDEX.md:335-338`（快速入口）
- 原文：`./cycle.sh --soft                          # 软回 fastboot（免按电源键）` / `fastboot boot bootslot-b/boot_b-f2fs-root.img  # 零写盘·持久变体…功能测试用`
- 新写：`ssh elden-root 'sync; reboot bootloader'`（#650）+ ⛔ 行说明 `cycle.sh --soft`/`eldroid-bootctl` 不可用（#690）+ `fastboot boot bootslot-b/boot_b-minbase-labellinux-20261119.img`；`boot_b-f2fs-root.img` 单独标历史（cmdline `LABEL=linux18`，linux18 已删⇒永久起不来）。
- 理由：`cycle.sh:23` 实现就是 sysrq-b 暖复位；f2fs 件被误标成「功能测试用持久变体」。

### C11 `RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md:41-44`（补口径，非审计条目）
- 新增：口径声明块 ——「最小化安装」= 最快到可用 Linux 后补齐能力；S3–S9 的 minbase 是中间态不是目标态，不得为「最小」省 `udev`/systemd 单元/`phosh-osk-stub`；目标态 = S10–S12（现态 1253 包）。
- 理由：用户 2026-11-19 重定义口径；本文件是现链权威手册，缺此声明会被读成「minbase = 终点」。

### C12 `TASKS/README.md:54`（G1-32）
- 原文：标题「OpenRC 化（init 交接，替代自研服务编排）」；判据 `rc-status default 全 started + ps -p 1 = /sbin/init`；`回退 echo legacy >/etc/elden-init-mode; reboot`。
- 新写：标题前加「**⛔ 已被 Debian+systemd 根取代（2026-10-31 并根）**」+〔历史〕；回退命令划删除线并注「在 systemd 根上等价于再 `exec /sbin/init`，空操作，已删」；判据改「`systemctl --failed` 空 + `ps -p 1 -o comm=` = `systemd`」；关键文件注「后两者 = Alpine 期件」。
- 理由：判据命令在现根不存在；回退在现根是空操作。**状态列 `✅` 未动**（`check-progress-counts.sh` 复算仍 36/37）。

### C13 `TASKS/README.md:57`（G1-35 触发）
- 原文：`触发 = OpenRC local（等 wlan0 UP）+ NM dispatcher.d`；关键文件 `rootfs/persistent-overlay/{etc-local.d,…}.tar.gz`。
- 新写：`触发 = systemd net-selfheal.service（源 packaging/elden-userland/out/units/systemd/，Alpine 期为 OpenRC local …）+ NM dispatcher.d`；关键文件列首项换成该 unit，overlay 三件标「后三者 = Alpine 期」。
- 理由：现役触发是 systemd（unit 文件已在盘核过）。

### C14 `TASKS/README.md:58`（G1-36 服务）
- 原文：`**修复** = wifi-scan-refresh OpenRC 服务`；关键文件 `etc-initd-wifi-scan-refresh`、`etc-conf.d-wifi-scan-refresh`。
- 新写：`**修复** = wifi-scan-refresh.service（systemd；源 packaging/…/units/systemd/，Alpine 期为 etc-initd-*/etc-conf.d-*）`；关键文件列首项换 unit 路径，旧件标 Alpine 期；判据 `wifi-scan-refresh.sh --check` 保留。
- 理由：同 C13，`/etc/local.d`、`/etc/init.d` 在现根不存在。

### C15 `INDEX.md:47`（现态块数字）
- 原文：`… / 165 包 / `/` 2.0 of 5.9 GiB。`
- 新写：`**当时 165 包** / **当时 `/` 2.0 of 5.9 GiB**（数字均为当晚快照；今日现态 = 1253 包 / `/` 190 GiB 且桌面已起，见上条）`。
- 理由：INDEX §2 要求「当前口径」只允许一处；同节已写 1253 包/190 GiB。

---

## 二、B 类（当前态 → 现态）

### B1 `RESOURCES/README.md:29`
- 原文：`**宿主**：Alpine apk 预制（mesa-dri-gallium + mesa-vulkan-freedreno），零编译…`
- 新写：`**宿主**：Debian 13 apt 预制（libgl1-mesa-dri + mesa-vulkan-drivers；Alpine 期为 mesa-dri-gallium + mesa-vulkan-freedreno），零编译…`
- 理由：读者会去 `apk add` 找不到；结论（零编译/原版）不变。

### B2 `RESOURCES/README.md:197`
- 原文：`> **GPU 栈编译账（2026-10-06）**：宿主用户态 **0 编译**（Alpine apk），内核属 G1 主线；`
- 新写：`> **GPU 栈编译账（2026-10-06；渠道 2026-11-19 更新）**：宿主用户态 **0 编译**（现根 Debian 13 apt 预制，原 Alpine 期为 apk），内核属 G1 主线；`
- 理由：结账结论未变、装包渠道已变。

### B3 `RESOURCES/README.md:92`（qbootctl）
- 原文：`✅ **已采纳**（取代 slot-attr.py 常用操作，PITFALLS #126）`（来源标 Alpine community）
- 新写：`◐ **仅作设备侧状态读取**；改属性/切槽以主机侧 python3 scripts/slot-attr.py（--image）+ fastboot --set-active 为准（PITFALLS #677）——设备无 python3/eldroid-bootctl，旧「取代 slot-attr.py」口径（#126）已改判`；来源改「原 Alpine community，现由 rootfs/debian/pkgmap.tsv 进包」。
- 理由：与 11-18/19 实践与 #677 相反；旧结论会让 agent 在设备侧改属性（必然失败）。

### B4 `RESOURCES/README.md:107`（G3 FEX）
- 原文：`（需 Alpine 侧自建 FEX/gamescope）`
- 新写：`（需在现根 Debian 13 自建 FEX/gamescope，或改用发行版包；Alpine 期口径已不适用）`
- 理由：宿主发行版已换；照旧排期会去准备 apk 构建环境。

### B5 `RESOURCES/README.md:159`（rootfs 归档台账）
- 原文：状态列 `3.44 GB / 30852 项，tar/gzip 完好`
- 新写：`⛔ 已不在盘（2026-11-19 核，env-pass/ 只剩 scripts/ tools/）；Alpine 期件（musl/OpenRC、label linux17），恢复链已改 minbase ext4 + resize2fs（LINUX-STATE-REPRO.md S3/S9）`
- 理由：文件不在盘却写「完好」，台账失信会让读者先怀疑自己的命令。

### B6 `DEVICE/README.md:44`
- 原文：`ath12k MHI -110、无 /dev/fastrpc-adsp、snd-sc8280xp deferred（均 ADSP/GPR 未就绪）。`
- 新写：`⟪历史定界（2026-11-19 13:20 之前）⟫ ~~…~~ —— 该三项已随 apt install udev 全部消失（见本条上文），此处仅作定界前记录。`
- 理由：与紧邻上文「已愈（2026-11-19 13:20）…全部随 apt install udev 消失」同段正反两说。

### B7 `DEVICE/README.md:167`（elden-hapticd）
- 原文：`宿主 daemon elden-hapticd（OpenRC + /etc/conf.d）`
- 新写：`elden-hapticd（systemd 单元 elden-hapticd.service，源 packaging/elden-userland/out/units/systemd/；Alpine 期为 OpenRC + /etc/conf.d）`
- 理由：unit 文件在盘；`/etc/conf.d` 只存在于 Alpine overlay。

### B8 `DEVICE/README.md:346`（§3.1 容量估算）
- 原文：`| Linux rootfs（Alpine + 桌面 + Mesa + 工具） | 装开后 **15–20 GB**（归档规格见 RESOURCES §2.2） | env-pass/backup-20261002/linux17-rootfs-…tar.gz |`
- 新写：`| Linux rootfs（Debian 13 最小根 + 桌面 + Mesa + 工具） | 装开后 **15–20 GB**（为 Alpine 期实测口径；Debian 档待按 df / 现测回填） | 现测：/ 已扩到 190 GiB（resize2fs，2026-11-19） |`
- 理由：分区容量决策依据不能引用不存在的归档；Debian 档体量尚未重测（如实标注）。

### B9 `DEVICE/README.md:306`（补漏，审计未列）
- 原文：`| 纯 RAM（不落盘） | 任一（刷 bootslot-b/boot_b_vk40-ram.img） |`
- 新写：`任一（fastboot boot bootslot-b/boot_b-minbase-labellinux-20261119.img；旧 boot_b_vk40-ram.img 已不在盘）`
- 理由：现态表格里的可执行命令指向不存在件。

### B10 `TASKS/README.md:345`（Q34 现象列）
- 原文：`（rc-service bluetooth stop/start 后正常）`
- 新写：`（systemctl restart bluetooth 后正常；原记为 Alpine rc-service bluetooth stop/start）`
- 理由：今天照跑会 `rc-service: not found`，可能被误读成「现象不可复现」；处置正文（缺 tmel 固件）不动。

### B11 `TASKS/README.md:535`（§6-C GPU 栈）
- 原文：`| **宿主用户态** GL/Vulkan | Alpine mesa-dri-gallium(freedreno) + mesa-vulkan-freedreno(Turnip) + mesa-egl + vulkan-loader | ❌ **apk 预制、零编译** … |`
- 新写：组件列改 Debian 包名（`libgl1-mesa-dri` / `mesa-vulkan-drivers` / `libegl1`+`libgl1` / `libvulkan1`）并括注 Alpine 期名；结论改「❌ **预制、零编译**」。
- 理由：读者据此判断「要不要编 Mesa」，apk 包名在现根查不到。

### B12 `PITFALLS/README.md:232`（#525）
- 原文：`纪律：每轮崩溃实验后核 eldroid-bootctl slot info，必要时 slot set-retry 7 b 补回余量`
- 新写：原文保留为历史结论，工具名处补「（Alpine 期件，现根已无此件/无 python3）」；并加 **现执行**：`设备侧只读 qbootctl`；改属性/补 retry 用主机侧 `python3 scripts/slot-attr.py --image … set-retry 7 b`（`PITFALLS #677`）。
- 理由：纪律仍成立，但照旧命令会 command not found 或被误当「已核过」。

### B13 `AGENTS.md:44`
- 原文：`busybox pgrep -x 恒假阴性（用 ps -eo comm | grep -cx）。`
- 新写：`设备侧查进程统一用 ps -eo comm | grep -cx（Alpine 期用 busybox applet 时 pgrep -x 恒假阴性；现根 pgrep 来自 procps-ng，但统一写法免分发行版）。`
- 理由：前提（busybox applet）已消失；推荐命令仍安全，只把历史限定与现状分开。

---

## 三、A 类（历史，仅登记；只给了 2 处最小限定）

- `TASKS/README.md:46`（G1-24）末尾加一句：「（设备侧前端 `eldroid-bootctl` 已于并根后退场，现用 systemd `reboot bootloader`）」——内核侧 PSCI 结论仍有效，只补现状。
- `TASKS/README.md:47`（G1-25）末尾加：「（换 systemd 根后此问题域已消失，仅存档）」。
- 其余 A 类（`TASKS:44,48,52,53,59`、`INDEX:303`、`DEVICE:157/365/371`、`PITFALLS #399/#397/#419/#420/#422/#455`、`AGENTS:58`）**原样未动**：均已带日期/世代限定词，或本来就在描述历史。

---

## 四、未处置 / 交回父代理

1. `RUNBOOK-BRINGUP/f2fs-migration.md` 的 3 条 C（`:3` 现态陈述、`:70` `rc-status` 判据、`:79` `mkfs.f2fs -l linux18 /dev/sda18`）按指示**未动**——该文件已有 2026-11-19 作废头（第 3–8 行），已明写「`/dev/sda18` 现为 ESP，任何步骤会格式化 ESP」。
   若要求把 `:70`/`:79` 正文也标废，需父代理确认后再改（会破坏「正文保持原样」的既有约定）。
2. 范围外线索（审计已列、属 `rootfs/`）：`rootfs/persistent-overlay/README.md:41-45` 仍把 `echo legacy >/etc/elden-init-mode` 写成可执行流程；`initramfs/init:287` 的该分支在 Debian 根上只是再 `exec` 一次 systemd（无害但无用）。未改。
3. `RUNBOOK-BRINGUP/README.md:392`（Phase 6 表内 `vk40 已含 netd IPv6/XFRM`）与 `RESOURCES/README.md:154-156`（vk40/modules-7.2.0 资产行）保留原文：前者是带版本的沿革注，后者已自带 ⚠️MIGRATION-LOST 标记。
4. `PROGRESS.md`：全文按日期分行的进度台账，命中项（`:13/:57/:60/:61/:65/:86/:100`）都自带日期与世代，属 A 类历史，未动。

■ 结束
