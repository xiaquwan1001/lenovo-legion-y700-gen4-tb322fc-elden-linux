# 脚本/工具精简与整理审计（2026-11-22，只读）

> 范围：`scripts/`（含 `doctor/`、`bisect/`、`lib-*.sh`、`audio-tplg/`、`audio-ucm/`、`wd-audio-test/`、`systemd/`）、
> `tools/`、`packaging/elden-userland/`、`rootfs/debian/*.sh`。机器清单 = `out/audit/scripts-audit-20261122.tsv`
> （369 个入口，列 = path/kind/evidence/action/fix）。
> 性质：**只读审计**。本轮未改任何脚本、未碰设备（设备在 bootloader、由主会话独占；无 fastboot/adb/ssh/qdl）、
> 未跑 `vk-identity.py`、未 `git commit`。唯一写入 = 本文件 + 上述 TSV。
> 既有结论只做增量与复核，不重复其正文：`reports/script-cleanup-audit-20261112.md`（P0/P1 复核主参照）、
> `PITFALLS/sessions/15-过时废弃功能缺陷登记.md`、`PITFALLS/sessions/06-脚本工具.md`、
> `scripts/README.md`（gen-scripts-index 生成索引：入口 345 + 孤立件 0）、
> `INDEX.md` §0/§2、`.pi/AGENT-OPS.md` §0。

---

## §结论（≤10 行）

1. 全量 369 个脚本入口：**KEEP 344 / STALE 15 / DANGEROUS 7 / BROKEN 3**（TSV 现查）。
2. **上轮 4 个 P0/P1 已修**（本轮复核）：`trial.sh`、`kbuild-sanity.sh`、`check-abi-config.sh`、`fix-ab-mark-successful.sh`（各证据见 TSV 行）。
3. **上轮 3 个 P0/P1 未修**：`scripts/ath12k-load.sh`（P0）、`scripts/arm-console-run.sh:14`（P0）、`scripts/q28-por-rounds.sh:99`（P1）。
4. **新判据产生的新 BROKEN（3）**：`arm-window-hunt.sh`、`q26-recheck.sh`、`n5b-vk64-death-rate.sh` 仍依赖 `ssh reboot2 bootloader`——PITFALLS #701（2026-11-21 实测）三条 Linux→fastboot 软路径全灭，这些脚本会静默产无效样本/无效指引。
5. **DANGEROUS 7 个**全部有既定门或需最小 fail-closed 修复（见 §3），没有一个处于「裸奔可写坏设备」态；最高优先补门 = `gpt-restore-tb322fc.py`（usage 内嵌删 linux 分区的 dd，无表指纹校验）。
6. STALE 15 个 = 上轮已登记未落地头注（sleep-*、headless waydroid、serial-*）+ 日期名一次性件 + 绑死 U1 备份路径的 2 个脚本 + 已 supersede 的 v2 计划器。
7. 无任何文件在本轮被删除/移动/修改；整改全部为「补丁建议」，见 §5 分批计划。

## §1 方法

1. 枚举：`find scripts tools packaging/elden-userland rootfs/debian -maxdepth 2 -type f` 过滤 `*.sh|*.py|*.c|*.initd`，去二进制/`__pycache__` ⇒ **369 个入口**（`scripts/` 340 + `tools/` 9 + `packaging` 6 + `rootfs/debian` 14，TSV 现查）。
2. 交叉：`PITFALLS` 15/06 号 sessions、`.pi/memory/failures-*.md` 关键词（reboot2、bind、slot、legacy、#584/#622/#696/#699/#701）、`reports/script-cleanup-audit-20261112.md` 逐条复核「是否已修」。
3. 静态判定：`fastboot|grep` 漏网、`dd of=<设备>` 写点清单、`build/<旧树名>` 引用、硬编码 SN/备份目录、日期名一次性件。
4. 分类：KEEP（在用/无负面证据，引用数>0 由生成索引背书）/ STALE / DANGEROUS / BROKEN。

## §2 抽样深读（17 个文件逐个依据）

| # | 文件 | 判 | 依据（file:line） |
|---|---|---|---|
| 1 | `scripts/ath12k-load.sh` | DANGEROUS | `MANIFEST.tsv:40` 仍装机；全仓零调用点；`:35` 把**设备路径**写进 `driver/bind`，而 `ath12k-retry.sh:50-51` NOTE 明写 bind 只吃设备名 ⇒ 被调用必静默失效（`2>/dev/null` 吞错）。上轮 P0 原样未修 |
| 2 | `scripts/arm-console-run.sh` | BROKEN | `:14` `fastboot devices \| grep -q .` = #584 SIGPIPE 模式原样；上轮只修了 arm-window-hunt/uefi-ddr-trial，这个漏网仍漏 |
| 3 | `scripts/trial.sh` | KEEP | 上轮说 `:186` 有 #584 模式——现 `grep -n 'fastboot devices'` 只剩 `:249` 的取值式（`timeout … fastboot devices 2>&1`），`186` 行已是参数解析 ⇒ **已修** |
| 4 | `scripts/kbuild-sanity.sh` | KEEP | `:23` 自述「收编进 hw-stability 后去掉了 y700 默认 build/m1-73」，`:31` `KDIR=` 必填、`:47` 空即退 ⇒ 上轮「默认对不存在树检查」已修 |
| 5 | `scripts/check-abi-config.sh` | KEEP | `:62` 注释明写「不再写死 build/m1-73，改 patches/current-tree」⇒ 28 处 `build/*` 死引用里最硬的一处已消 |
| 6 | `scripts/m1-73-modules-overlay.sh` | STALE | 头部有 S15 收口指针（历史/专用形态）；目标树 `build/m1-73` 不存在（`build/` 现仅 `elden-tree`）⇒ 建议归档 |
| 7 | `scripts/q28-por-rounds.sh` | STALE | `:99` 仍 `< scripts/q28-devprobe.sh`（v1 storm_sig 单计数）；`q28-devprobe2.sh:3-6` 自述 v1 混 L1/L2 ⇒ 上轮 P1 未修，POR 轮次判据失真 |
| 8 | `scripts/fix-ab-mark-successful.sh` | KEEP | 上轮判「Alpine 专用、Debian 根第一步 exit 1」已过时：`:17-22` 新增 Debian/systemd 分支（2026-11-21），从 `/proc/cmdline` 取槽位并复位 tries_remaining ⇒ **已修** |
| 9 | `scripts/deploy-sensord-routec.sh` | STALE | Alpine/musl 安装器；现役根 Debian（INDEX §0 2026-11-20）；`-debian.sh` 是真源（#431） |
| 10 | `scripts/n5b-vk64-death-rate.sh` | DANGEROUS | `:131` 仍发 `SSH 'reboot2 bootloader'`（TASKS §4 停用令 + #701 实测全灭）；`:167-179` 手工 sysrq 逃生梯仍在 |
| 11 | `scripts/arm-window-hunt.sh` | BROKEN | `:17-18,27-28` ssh `reboot2 bootloader`——#701 后这些发现在普通重启，脚本继续采样 = 静默无效样本 |
| 12 | `scripts/q26-recheck.sh` | BROKEN | `:50` 指引用户/agent 走同一已死软路径 |
| 13 | `scripts/gpt-restore-tb322fc.py` | DANGEROUS | usage 内嵌设备侧 `dd … of=/dev/block/sda`（恢复 userdata、**删 linux 分区**）；生成器无表指纹/SN 校验 ⇒ 拿错 dump = 抹 Linux 根 |
| 14 | `scripts/linux-gpt-apply.sh` | KEEP | 反面教材的对立面：默认 dry-run + 写后读回对账（头部自述 2026-11-17 教训），是 DANGEROUS 组的「门的标准形」 |
| 15 | `scripts/flash-b.sh` / `flash-recovery.sh` | KEEP | flash-b `:44-52` 写前容量核对、`:56` 读回 sha、`:66` mark-successful 兜底；flash-recovery `:35-39,56-58` 同口径 ⇒ 这条家族不需要整改 |
| 16 | `scripts/dev-super-relabel.sh` / `dev-userdata-relabel.sh` | DANGEROUS | `:5`/`:6` 硬编码 `PART=/dev/sda10` / `/dev/sda16`——违反「设备等价、运行时读实际 GPT」原则；`--apply` 改类型码，默认 dry-run 是唯一门 |
| 17 | `scripts/pack-cloud-backup.sh` / `linux-state-audit.sh` | STALE | `:36-39` / `:86-91` 绑死 `backup/HA2EXB0E-16+512/`（U1）；U2 上跑 = 全 MISS，基线判据失真 |

（另：`scripts/elden-to-bootloader.sh`、`build-vbmeta-b.sh`、`sign-boot-b.sh`、`rawprogram-preflight.py`、`gpt-slot-flip-active.py`、`t2-stock-lun45.sh`、`tools/*`、`rootfs/debian/build-rootfs.sh`、`stage.sh`、`import-waydroid.sh` 逐个过目，判定与处置见 TSV 对应行；`vk-identity.py` 本轮未运行——项目 AGENTS.md 硬规则。）

## §3 DANGEROUS 组：危险点 + 最小修复

| 文件 | 危险点 | 最小修复（fail-closed） |
|---|---|---|
| `gpt-restore-tb322fc.py` | 打印的 dd 指令直接重写 LUN0 主表（删 linux） | build 时强制 `--expect-fingerprint <sha>`，main/backup 表 sha 不符即拒绝输出；dd 指引后附「写后逐字节读回」一步 |
| `gpt-slot-flip-active.py` | ACTIVE 位写错槽 = 引导指向错槽 | 写前读表校验「type GUID 已在该槽侧」才允许写该槽（#697 的 GUID 搬家语义）；写后读回 CRC |
| `f2fs-migrate.sh:250,259` | 对整盘设备 dd | apply 级阶段加 `SER=${SER:?}` + 写前双表 dump 断言，对齐 linux-gpt-apply 口径 |
| `dev-super-relabel.sh` / `dev-userdata-relabel.sh` | sda 编号硬编码 + --apply 改表 | PART 按 partlabel+size 解析；`--apply` 必须显式 `SN=` |
| `n5b-vk64-death-rate.sh:131` | 停用 reboot2 + sysrq 梯 | 换 `eldroid-bootctl reboot bootloader`（to-fastboot 口径）；软路径失败即停 |
| `ath12k-load.sh` | 装机但恒不生效 + `2>/dev/null` 吞错 | 退役头 + 移出 MANIFEST（先证 0 引用） |

## §4 STALE/BROKEN 与上轮账目的对齐

- 上轮审计（2026-11-12）8 条 P0/P1/P2 缺陷：**4 修 / 3 未修 / 1 条目性质变化**（fix-ab 由「缺陷」转「已重构」）。未修三项全部在本轮 TSV 里带 file:line。
- 新增判定只有一类来源：**#701（2026-11-21）** 使所有依赖 `ssh reboot2 bootloader` 的脚本由「口径过时」升级为「实际不工作」——共命中 3 文件（TSV BROKEN 组）+ 若干注释引用（不改）。
- 上轮「28 处 `build/*` 死引用」本轮抽查 6 文件：4 处已修或已带退役头，余 `m1-73-modules-overlay.sh`（已带头注）⇒ 该债基本还清，无需再开专项。

## §5 分批整改计划（每批 ≤10 项，可独立回退；只出建议，本轮不落地）

**批 1（P0：写坏/静默失效风险，~1 h，每项独立 commit 可 revert）**
1. `ath12k-load.sh` 加 RETIRED 头 + 移出 `MANIFEST.tsv:40` / `build-rootfs.sh` 拷贝名单（先 `rg -n ath12k-load` 证 0 引用）。判据：check-doctor §24/§13 全绿。
2. `arm-console-run.sh:14` 换 lib-wait.sh:85 口径。判据：`rg -n '(fastboot|adb)[^|]*\| *(grep|head|wc)' scripts/` 实代码归零。
3. `gpt-restore-tb322fc.py` 加 `--expect-fingerprint` fail-closed。判据：错指纹输入 rc≠0 且不打印 dd 行。
4. `gpt-slot-flip-active.py` 写前 GUID 位置校验。判据：对 11-20 现场表自测 a/b 两方向。
5. `n5b-vk64-death-rate.sh:131` 换 to-fastboot 口径、删 sysrq 梯。判据：`rg reboot2` 该文件 0 实代码命中。
6. `dev-super/userdata-relabel.sh` PART 解析 + SN 断言。判据：`bash -n` + dry-run 输出含 SN。

**批 2（BROKEN→可用，~30 min）**
7. `q28-por-rounds.sh:99` 喂 v2 取样器 + 字段名核对（`sed -n '95,110p'`）。判据：dry 样本出现 L1=/L2=。
8. `arm-window-hunt.sh` / `q26-recheck.sh` 加 #701 停手门（软路径失败即退出要求物理键）。判据：模拟软路径失败 rc=2。
9. `linux-state-audit.sh` / `pack-cloud-backup.sh` 备份目录参数化（默认现值保留，可显式传 U2）。判据：`--sn` 传入后 MISS=0。

**批 3（STALE 头注与归档，~30 min，纯注释/移动）**
10. sleep-bisect/cumulative、waydroid-headless-*、serial-log/serial-logger、deploy-sensord-routec、android-slim-v2-plan 加头注（照 11-12 审计已写好的文案）。
11. `android-assets-extract-20261119.py`、`mailbox-cleanup-20261102.py`、`m1-73-modules-overlay.sh`、`t2-stock-lun45.sh` 移 `archive/`（先 `gen-scripts-index.py` 重算指纹 + §24 门）。
12. `DEVICE/README.md:123` serial-logger 指针改 serial-tap.py（上轮 A2 未落地项）。
13. 每批结束跑 `scripts/check-doctor.sh` FAIL=0 才进下一批；任何一批可单独 `git revert`。

## §边界与未验证

- TSV 的 KEEP 行是「无负面证据 + 生成索引引用>0」的**默认分类**，未逐文件深读（369 个不可行）；深读覆盖 17+9=26 个高危/存疑文件。
- `scripts/bisect/eldtest.sh`、`scripts/audio-tplg/build.sh`、`packaging/elden-userland/templates/` 仅按索引归类，内容未逐行读——标注「未验证」。
- 本轮未运行任何会碰设备/网络的脚本；全部判定基于文本与已有实测记录。
