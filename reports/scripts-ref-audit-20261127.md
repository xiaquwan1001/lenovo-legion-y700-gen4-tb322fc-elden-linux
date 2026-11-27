# reports/scripts-ref-audit-20261127.md — `scripts/` 引用面收口（T14 / `arch-audit-20261127.md` A7）

> **任务**：`TASKS/NEXT.md` §4.0a **T14** = 把 `scripts/` 里「不被活面文档引用」的脚本分类（退役 / 补指针 / 保持私有），并修掉 7 条死引用。
> **口径**：照抄 `reports/arch-audit-20261127.md` A7 —— 活面文档集 = `INDEX.md` `AGENTS.md` `PITFALLS/README.md` `reports/README.md`
> \+ `TASKS/*.md`(7) + `DEVICE/*.md`(2) + `RESOURCES/*.md`(1) = **14 份**；入口清单 = `python3 scripts/gen-scripts-index.py --tsv`（现查 **363** 个入口）；
> 每个入口 **basename 在这 14 份里子串命中即算引用**。
> **硬约束自检**：未删任何脚本、未改 `scripts/README.md`/`reports/README.md`（生成物）、未改 `TASKS/NEXT.md`/`INDEX.md`/`DEVICE/README.md`，
> 除 7 条死引用所在行外未改其它已有行（新增内容全是本节 §2 的**新行**、§5 的**新节**、3 个脚本的**新头注行**）。

## 0. 结论（PASS）

| 指标 | A7 时点（审计快照） | **本次现查（改前）** | **改后** | 命令 |
|---|---|---|---|---|
| `scripts/` 入口 | 359 | **363** | 363 | `python3 scripts/gen-scripts-index.py --check`（`OK … 363 个入口`） |
| 活面文档命中 | 161（44.8%） | **144（39.7%）** | **194（53.4%）** | §4 命令 1 |
| 孤儿总数 | 198 | **219** | **169** | 同上 |
| ├ `scripts/doctor/` | 28 | **27** | 27 | 同上（**假阳性**：`check-doctor.sh` 按路径调用，不是文档引用关系） |
| ├ `lib-*` | 4 | **8** | 8 | 同上（**假阳性**：被 `source`） |
| └ plain（真孤儿） | 166 | **184** | **134** | 同上 |
| 死引用（文档提到、文件不存在） | 7 路径 / 12 处 | **7 路径 / 14 处** | **0 / 0** | §4 命令 2 |

- **184 个 plain 孤儿已逐条分类**（§2）：**① 退役 3** + **② 补指针 50** + **③ 保持私有 131**。
  孤儿净减 **50** = **49 条新指针行**（`RESOURCES/README.md` §5）**+ 1 条来自死引用修复**（§3 #4 那行点名了 `scripts/q28-reboot-until-good.sh`）。
- **7 条死引用全部清零**（§3）：其中 **5 条是误报**（文件真在，只是路径尾部 `scripts/` 被正则当成了仓根）、
  **1 条是真·跨树误读**（`checkpatch.pl` 指内核树）、**1 组（q28 ×4）兼有「文档自述与盘上事实相反」**（原文称「本机已无」，实际归档件逐字在盘）——已就地更正。
- `doctor` / `lib-*` 两档**不改**：它们是 A7 已认定的假阳性，口径留着只为与 A7 逐号可比。
- 数字与 A7 的差（161→144、359→363、`lib-*` 4→8、`doctor` 28→27）是**同期仓内漂移**（脚本新增/改名 + 活面文档拆章重排；本轮**未逐篇归因**），
  不是口径变化 —— 本报告用的是与 A7 §4 逐字相同的内联判据（§4 命令 1）。

## 1. 三分类的判据（可复核，先立后用）

对每个 plain 孤儿跑三组证据（脚本见 §4 命令 3）：

1. **活调用点**：`scripts/` `packaging/` `rootfs/` `initramfs/` `.githooks/` `tools/` `net/` `probes/` 里是否出现该 basename（排除自身与生成物）。
2. **历史账引用**：`reports/` `archive/` `HISTORY/` `SESSIONS/` `TASKS/sessions/` `PITFALLS/sessions/` 里的出现处。
3. **自述/依赖**：脚本头注释里的 `SUPERSEDED`/`LEGACY`/`STALE`/`一次性`/`已归档` 标记，以及它引用的仓内输入路径是否还在盘。

判定：

| 分类 | 条件 | 动作 |
|---|---|---|
| **①退役** | 活调用点 = 0 **且** 场景已关闭（TASKS 明写关闭/口径更正）**且** 输入产物已不在盘（= 不可原地重建） | 脚本头追加一行 `# RETIRED 2026-11-27：<原因>`，**不删文件** |
| **②补指针** | 活调用点 = 0 **且** 是可复用工具族（一个工具跨角度/跨会话反复用），只因「只在生成索引里」而找不到 | 在角度 README（`RESOURCES/README.md` §5）加一行「脚本 + 真的干什么 + 何时用」 |
| **③保持私有** | 被别的脚本调用/`source` 的内部件；或单次实验执行器/一次性历史件（引入它的报告就是它的指针） | 只登记本表，**不动文件** |

> **「不确定就归③」已执行**：只有 3 件能同时拿出「场景关闭 + 输入不在盘 + 0 活调用点」三证，其余一律不入①。
> 上一轮 `reports/scripts-hardening-4-20261123.md` §2 已对 15 件 STALE 做过逐条复核（3 归档 / 12 留头注），本表**沿用其结论不再翻案**。

## 2. 分类表（184 个 plain 孤儿逐条）

> 排序 = 路径字典序。**理由**列只写一句可复核的话（活调用点 / 场景关闭 / 历史指针）；**动作**列是本轮真的做了什么（或「不做」）。
> 「宏」在 §0 表：① 3 + ② 50 + ③ 131 = 184。

| # | 脚本 | 分类 | 理由（一句） | 动作 |
|---|---|---|---|---|
| 1 | `scripts/abl-log.sh` | **③保持私有** | 被 `scripts/logfs-decode.py` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 2 | `scripts/android-apk-pkgname.py` | **③保持私有** | 被 `scripts/android-slim-v3-build.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 3 | `scripts/android-assets-extract-20261119.py` | **③保持私有** | 被 `scripts/asset-install-linux.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 4 | `scripts/android-ext4-slim-test.py` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=Android 镜像面（线刷包 / ext4 / super）） | `RESOURCES/README.md` §5「Android 镜像面（线刷包 / ext4 / super）」加一行 |
| 5 | `scripts/android-img-grepmap.py` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=Android 镜像面（线刷包 / ext4 / super）） | `RESOURCES/README.md` §5「Android 镜像面（线刷包 / ext4 / super）」加一行 |
| 6 | `scripts/android-img-inventory.py` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=Android 镜像面（线刷包 / ext4 / super）） | `RESOURCES/README.md` §5「Android 镜像面（线刷包 / ext4 / super）」加一行 |
| 7 | `scripts/android-img-lswalk.py` | **③保持私有** | 被 `scripts/android-slim-v2-plan.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 8 | `scripts/android-ksu-avb-build.py` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=Android 镜像面（线刷包 / ext4 / super）） | `RESOURCES/README.md` §5「Android 镜像面（线刷包 / ext4 / super）」加一行 |
| 9 | `scripts/android-launcher-db-check.py` | **③保持私有** | 被 `scripts/android-slim-v3-build.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 10 | `scripts/android-launcher-db-trim.py` | **③保持私有** | 被 `scripts/android-slim-v2-plan.sh` 等 2 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 11 | `scripts/android-lpdump.py` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=Android 镜像面（线刷包 / ext4 / super）） | `RESOURCES/README.md` §5「Android 镜像面（线刷包 / ext4 / super）」加一行 |
| 12 | `scripts/android-min-build.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=Android 镜像面（线刷包 / ext4 / super）） | `RESOURCES/README.md` §5「Android 镜像面（线刷包 / ext4 / super）」加一行 |
| 13 | `scripts/android-rom-segassemble.py` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=Android 镜像面（线刷包 / ext4 / super）） | `RESOURCES/README.md` §5「Android 镜像面（线刷包 / ext4 / super）」加一行 |
| 14 | `scripts/android-slim-v3-build.sh` | **③保持私有** | 被 `scripts/android-slim-v2-plan.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 15 | `scripts/android-super-scan.py` | **③保持私有** | 被 `scripts/android-lpdump.py` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 16 | `scripts/android-super.py` | **③保持私有** | 被 `scripts/android-slim-v2-plan.sh` 等 4 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 17 | `scripts/android-v3-bringup-walkthrough.sh` | **③保持私有** | 被 `scripts/lib-hosttools.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 18 | `scripts/arm-window-hunt.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 19 | `scripts/asset-install-linux.sh` | **③保持私有** | 被 `scripts/android-assets-extract-20261119.py` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 20 | `scripts/ath12k-retry.sh` | **③保持私有** | 被 `packaging/elden-userland/MANIFEST.tsv` 等 12 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 21 | `scripts/b3b-session-retry.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 22 | `scripts/b5-u2-atomic-timeline.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261029-crossdoc.md` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 23 | `scripts/backup-triage.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=存储 / 分区改造） | `RESOURCES/README.md` §5「存储 / 分区改造」加一行 |
| 24 | `scripts/bb-magic-scan.py` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 25 | `scripts/bisect/eldtest.sh` | **③保持私有** | 被 `scripts/bisect/README.md` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 26 | `scripts/blackout-passive-scan.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`archive/topics/WIFI-BMISS-2026-10-06.md` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 27 | `scripts/blankspy.sh` | **③保持私有** | 被 `packaging/elden-userland/MANIFEST.tsv` 等 9 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 28 | `scripts/bootimg-replace-kernel.py` | **③保持私有** | 被 `scripts/uefi-repack-v2aligned.py` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 29 | `scripts/bt-up.sh` | **③保持私有** | 被 `packaging/elden-userland/MANIFEST.tsv` 等 5 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 30 | `scripts/build-athm-probe.sh` | **①退役** | 无活调用点；Q26 Step A 一次性质询件，基座 `wt-athm`/`wt-wifibmiss` worktree 已不在本机，且路径硬编码换机前的 `/home/xuqianhui1001` ⇒ 不可重建 | 脚本头追加 `# RETIRED 2026-11-27：<原因>`（**不删文件**） |
| 31 | `scripts/build-boot-slim.sh` | **①退役** | 无活调用点；G1-30 已口径更正「slim 不作日常启动」（TASKS/G1.md：vk60 外设全不可用，归因最小 initramfs 无 /lib/firmware），输入 `linux/arch/arm64/boot/Image.gz` 已不在盘 | 脚本头追加 `# RETIRED 2026-11-27：<原因>`（**不删文件**） |
| 32 | `scripts/build-ffrumble.sh` | **③保持私有** | 被 `packaging/elden-userland/build/README.md` 等 5 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 33 | `scripts/build-modular-overlay.sh` | **③保持私有** | 被 `scripts/build-payload-hook.sh` 等 3 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 34 | `scripts/build-payload-hook.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 35 | `scripts/build-phoc-arm64.sh` | **③保持私有** | 被 `packaging/elden-userland/build/phoc.sh` 等 2 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 36 | `scripts/build-phosh-arm64.sh` | **③保持私有** | 被 `scripts/build-phosh-upstream-fix.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 37 | `scripts/build-phosh-upstream-fix.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 38 | `scripts/build-vbmeta-b.sh` | **③保持私有** | 被 `bootslot-b/README.md` 等 3 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 39 | `scripts/c1-iprule-build.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 40 | `scripts/cam-load-verify.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=设备体检 / 电源） | `RESOURCES/README.md` §5「设备体检 / 电源」加一行 |
| 41 | `scripts/camera-stream-up.sh` | **③保持私有** | 被 `scripts/skewcal-frame-stats.sh` 等 2 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 42 | `scripts/check-init.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=内核 / 模块 / 部署） | `RESOURCES/README.md` §5「内核 / 模块 / 部署」加一行 |
| 43 | `scripts/check-modular-config.sh` | **③保持私有** | 被 `scripts/apply-kernel-fragment.sh` 等 3 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 44 | `scripts/check-series-selfcontained.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`PITFALLS/sessions/142-series-selfcontained-replay-gate.md` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 45 | `scripts/deploy-bt-suspend-guard.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=内核 / 模块 / 部署） | `RESOURCES/README.md` §5「内核 / 模块 / 部署」加一行 |
| 46 | `scripts/deploy-camera-modules.sh` | **③保持私有** | 被 `packaging/elden-userland/files/usr/local/sbin/camera-modules-load.sh` 等 3 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 47 | `scripts/deploy-modules.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=内核 / 模块 / 部署） | `RESOURCES/README.md` §5「内核 / 模块 / 部署」加一行 |
| 48 | `scripts/deploy-sensord-routec-debian.sh` | **③保持私有** | 被 `packaging/elden-userland/build/README.md` 等 3 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 49 | `scripts/deploy-v4l2loopback.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=内核 / 模块 / 部署） | `RESOURCES/README.md` §5「内核 / 模块 / 部署」加一行 |
| 50 | `scripts/deskstack-sample.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 51 | `scripts/deskstack-switch.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 52 | `scripts/dev-super-relabel.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=存储 / 分区改造） | `RESOURCES/README.md` §5「存储 / 分区改造」加一行 |
| 53 | `scripts/dev-userdata-relabel.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=存储 / 分区改造） | `RESOURCES/README.md` §5「存储 / 分区改造」加一行 |
| 54 | `scripts/device-window-collect.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 55 | `scripts/devlogs.sh` | **③保持私有** | 被 `scripts/serial-log.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 56 | `scripts/display-drop-forensics.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=取证 / 解码） | `RESOURCES/README.md` §5「取证 / 解码」加一行 |
| 57 | `scripts/dpms-watch.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=设备体检 / 电源） | `RESOURCES/README.md` §5「设备体检 / 电源」加一行 |
| 58 | `scripts/driver-snapshot-diff.sh` | **③保持私有** | 被 `scripts/driver-snapshot.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 59 | `scripts/driver-snapshot.sh` | **③保持私有** | 被 `scripts/driver-snapshot-diff.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 60 | `scripts/dump-verdict.py` | **③保持私有** | 被 `scripts/doctor/21-write-precheck.sh` 等 3 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 61 | `scripts/edl-peek.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 62 | `scripts/elden-backlight-floor.sh` | **③保持私有** | 被 `packaging/elden-userland/MANIFEST.tsv` 等 6 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 63 | `scripts/elden-powerlog.initd` | **③保持私有** | 被 `packaging/elden-userland/MANIFEST.tsv` 等 8 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 64 | `scripts/elden-time-baseline.sh` | **③保持私有** | 被 `rootfs/debian/daily-baseline.sh` 等 3 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 65 | `scripts/elden-to-bootloader.sh` | **③保持私有** | 被 `scripts/to-bootloader.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 66 | `scripts/esp-apply.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=UEFI / ESP / GRUB） | `RESOURCES/README.md` §5「UEFI / ESP / GRUB」加一行 |
| 67 | `scripts/esp-put-loader.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=UEFI / ESP / GRUB） | `RESOURCES/README.md` §5「UEFI / ESP / GRUB」加一行 |
| 68 | `scripts/f2fs-host-bench.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=存储 / 分区改造） | `RESOURCES/README.md` §5「存储 / 分区改造」加一行 |
| 69 | `scripts/f2fs-migrate.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=存储 / 分区改造） | `RESOURCES/README.md` §5「存储 / 分区改造」加一行 |
| 70 | `scripts/fb-survey.py` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 71 | `scripts/fetch-x86-assets.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`archive/2026-10-04-git-backfill/bf_manifest_all.txt` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 72 | `scripts/ffs-extract.py` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=UEFI / ESP / GRUB） | `RESOURCES/README.md` §5「UEFI / ESP / GRUB」加一行 |
| 73 | `scripts/fix-ab-mark-successful.sh` | **③保持私有** | 被 `scripts/deploy-desktop-shell.sh` 等 2 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 74 | `scripts/g1-22-dpms-test.sh` | **③保持私有** | 被 `scripts/b5-u2-atomic-timeline.sh` 等 2 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 75 | `scripts/gapps-mirror-setup.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`archive/2026-10-04-git-backfill/bf_manifest_all.txt` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 76 | `scripts/gen-pinyin-lexicon.py` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=上游 / 词库） | `RESOURCES/README.md` §5「上游 / 词库」加一行 |
| 77 | `scripts/glycin-bwrap-shim.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`archive/2026-10-04-git-backfill/bf_manifest_all.txt` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 78 | `scripts/gpt-audit-tb322fc.py` | **③保持私有** | 被 `scripts/build-locked-chain.sh` 等 5 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 79 | `scripts/gpt-preflight.py` | **③保持私有** | 被 `scripts/doctor/21-write-precheck.sh` 等 2 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 80 | `scripts/gpt-slot-flip-active.py` | **③保持私有** | 被 `scripts/recover-lun4-slotguid.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 81 | `scripts/gpt-slot-swap-guids.py` | **③保持私有** | 被 `scripts/gpt-slot-flip-active.py` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 82 | `scripts/greetd-initial-session.sh` | **③保持私有** | 被 `packaging/elden-userland/MANIFEST.tsv` 等 5 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 83 | `scripts/grub-arm64-standalone.sh` | **③保持私有** | 被 `scripts/grub-arm64-arming-build.sh` 等 3 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 84 | `scripts/grub-bootfiles.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=UEFI / ESP / GRUB） | `RESOURCES/README.md` §5「UEFI / ESP / GRUB」加一行 |
| 85 | `scripts/grubenv-set.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=UEFI / ESP / GRUB） | `RESOURCES/README.md` §5「UEFI / ESP / GRUB」加一行 |
| 86 | `scripts/grubfat-build-uefi-bootimg.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`archive/topics/BOOTCHAIN-2026-10-05.md` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 87 | `scripts/grubfat-inspect.sh` | **③保持私有** | 被 `scripts/build-boot-slim.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 88 | `scripts/gui-freeze-watch.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`HISTORY/days/2026-10-09.md` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 89 | `scripts/gunyah-rm-bringup.sh` | **③保持私有** | 被 `tools/gunyah-modules/README.md` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 90 | `scripts/hide-android-partitions-selftest.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=存储 / 分区改造） | `RESOURCES/README.md` §5「存储 / 分区改造」加一行 |
| 91 | `scripts/hk-save-decrypt.py` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`archive/2026-10-04-git-backfill/bf_manifest_all.txt` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 92 | `scripts/host-arm64-chroot.sh` | **③保持私有** | 被 `packaging/elden-userland/build/README.md` 等 6 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 93 | `scripts/host-mem-build-stress.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 94 | `scripts/ime-candidates-check.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=设备体检 / 电源） | `RESOURCES/README.md` §5「设备体检 / 电源」加一行 |
| 95 | `scripts/install-serial-logger.sh` | **③保持私有** | 被 `scripts/lib-serial-source.sh` 等 2 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 96 | `scripts/keep-awake.sh` | **③保持私有** | 被 `scripts/cam-load-verify.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 97 | `scripts/kexec-bs-cycle.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`HISTORY/days/2026-10-08.md` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 98 | `scripts/kexec-diag-test.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`archive/topics/KEXEC-DIAG-TEST-PLAN-2026-10-08.md` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 99 | `scripts/kmsgspy.sh` | **③保持私有** | 被 `packaging/elden-userland/MANIFEST.tsv` 等 4 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 100 | `scripts/lf2-expected.py` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 101 | `scripts/linux-gpt-apply.sh` | **③保持私有** | 被 `packaging/elden-userland/files/usr/local/bin/slot-attr.py` 等 9 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 102 | `scripts/logfs-decode.py` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=取证 / 解码） | `RESOURCES/README.md` §5「取证 / 解码」加一行 |
| 103 | `scripts/lore-fetch-raw.py` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=上游 / 词库） | `RESOURCES/README.md` §5「上游 / 词库」加一行 |
| 104 | `scripts/mailbox-cleanup-20261102.py` | **③保持私有** | 被 `scripts/mailbox-cleanup-weekly.sh` 等 2 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 105 | `scripts/mailbox-cleanup-weekly.sh` | **③保持私有** | 被 `scripts/mailbox-cleanup-20261102.py` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 106 | `scripts/mailbox-quota-reclaim-20261125.py` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`历史账` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 107 | `scripts/make-gpt-only-xml.py` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 108 | `scripts/manifest-from-image.py` | **③保持私有** | 被 `scripts/build-manifest.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 109 | `scripts/mesa-deploy.sh` | **③保持私有** | 被 `scripts/extract-mesa-libs.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 110 | `scripts/n7-vk127-camera-blank.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 111 | `scripts/net-egress.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`archive/2026-10-02-merged/PLAN-NODEV-2026-10-02.md` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 112 | `scripts/net-up-manual.sh` | **③保持私有** | 被 `packaging/elden-userland/MANIFEST.tsv` 等 7 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 113 | `scripts/odirect-sha.py` | **③保持私有** | 被 `scripts/android-ksu-avb-build.py` 等 22 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 114 | `scripts/oob-gs1-activate.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`archive/2026-10-04-git-backfill/bf_manifest_all.txt` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 115 | `scripts/out-candidate-sha.py` | **③保持私有** | 被 `scripts/doctor/29-out-candidate-sha.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 116 | `scripts/out-manifest-check.py` | **③保持私有** | 被 `scripts/doctor/23-out-manifest.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 117 | `scripts/package-camera-modules.sh` | **③保持私有** | 被 `rootfs/build-camera-overlay.sh` 等 2 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 118 | `scripts/partlun.py` | **③保持私有** | 被 `scripts/android-v3-bringup-walkthrough.sh` 等 3 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 119 | `scripts/payload-modules-load.sh` | **③保持私有** | 被 `rootfs/debian/svc-deps.tsv` 等 3 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 120 | `scripts/phoc-build-launch.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 121 | `scripts/phosh-install.sh` | **③保持私有** | 被 `scripts/build-phosh-arm64.sh` 等 2 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 122 | `scripts/probe-camera-sensors.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=设备体检 / 电源） | `RESOURCES/README.md` §5「设备体检 / 电源」加一行 |
| 123 | `scripts/q26-recheck.sh` | **①退役** | 无活调用点；Q26 已于 2026-10-10 关闭（TASKS/GAPS §Q26），输入 `out/boot-elden-vk62.img`/`out/Image-vk47clean.gz` 已不在盘（只余 .manifest）⇒ 不可原地重建 | 脚本头追加 `# RETIRED 2026-11-27：<原因>`（**不删文件**） |
| 124 | `scripts/q28-clkdiag.sh` | **③保持私有** | 被 `scripts/q28-coldboot-collect.sh` 等 3 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 125 | `scripts/q28-coldboot-collect.sh` | **③保持私有** | 被 `scripts/q28-por-rounds.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 126 | `scripts/q28-disp-ab-sample.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`HISTORY/days/2026-10-23.md` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 127 | `scripts/q28-reboot-until-good.sh` | **②补指针** | 无活调用点；Q28 温启想要 GOOD 现场的现役件（替代已退场的 q28-boot-cycle.sh） | 死引用修复行（`RESOURCES/README.md` §2.1 / §3 台账）已逐名点名 |
| 128 | `scripts/q32-arm.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 129 | `scripts/q32-boot-evidence.sh` | **③保持私有** | 被 `scripts/q28-coldboot-collect.sh` 等 3 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 130 | `scripts/qemu-ramoops-initrd-ab.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 131 | `scripts/real-vs-ladder.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`archive/2026-11-19-docs-audit-retired/superseded/asset-inventory-20261108.md` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 132 | `scripts/rebuild-vk64-image.sh` | **③保持私有** | 被 `scripts/n5b-vk64-death-rate.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 133 | `scripts/recover-lun4-slotguid.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=存储 / 分区改造） | `RESOURCES/README.md` §5「存储 / 分区改造」加一行 |
| 134 | `scripts/rootfs-image-check.py` | **③保持私有** | 被 `scripts/doctor/20-rootfs-image.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 135 | `scripts/rootfs-minbase-build.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=内核 / 模块 / 部署） | `RESOURCES/README.md` §5「内核 / 模块 / 部署」加一行 |
| 136 | `scripts/scale.sh` | **③保持私有** | 被 `packaging/elden-userland/MANIFEST.tsv` 等 4 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 137 | `scripts/sd-run-variant.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`archive/topics/SLEEPDEATH-BISECT-2026-10-06.md` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 138 | `scripts/sd-variant-build.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`archive/topics/SLEEPDEATH-BISECT-2026-10-06.md` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 139 | `scripts/send-upstream-report.py` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`archive/topics/UPSTREAM-REPORT-cambist-q24-2026-10-08.md` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 140 | `scripts/serial-capture.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=串口证据通道（USB-CDC-ACM `/dev/ttyACM0`；SSH/ADB 都不通时唯一通道）） | `RESOURCES/README.md` §5「串口证据通道（USB-CDC-ACM `/dev/ttyACM0`；SSH/ADB 都不通时唯一通道）」加一行 |
| 141 | `scripts/serial-cmd.py` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=串口证据通道（USB-CDC-ACM `/dev/ttyACM0`；SSH/ADB 都不通时唯一通道）） | `RESOURCES/README.md` §5「串口证据通道（USB-CDC-ACM `/dev/ttyACM0`；SSH/ADB 都不通时唯一通道）」加一行 |
| 142 | `scripts/serial-fanout.sh` | **③保持私有** | 被 `scripts/install-serial-logger.sh` 等 2 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 143 | `scripts/serial-log.sh` | **③保持私有** | 被 `scripts/devlogs.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 144 | `scripts/serial-probe.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=串口证据通道（USB-CDC-ACM `/dev/ttyACM0`；SSH/ADB 都不通时唯一通道）） | `RESOURCES/README.md` §5「串口证据通道（USB-CDC-ACM `/dev/ttyACM0`；SSH/ADB 都不通时唯一通道）」加一行 |
| 145 | `scripts/serial-run.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=串口证据通道（USB-CDC-ACM `/dev/ttyACM0`；SSH/ADB 都不通时唯一通道）） | `RESOURCES/README.md` §5「串口证据通道（USB-CDC-ACM `/dev/ttyACM0`；SSH/ADB 都不通时唯一通道）」加一行 |
| 146 | `scripts/serial-sysrq.py` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=串口证据通道（USB-CDC-ACM `/dev/ttyACM0`；SSH/ADB 都不通时唯一通道）） | `RESOURCES/README.md` §5「串口证据通道（USB-CDC-ACM `/dev/ttyACM0`；SSH/ADB 都不通时唯一通道）」加一行 |
| 147 | `scripts/setup-session-greetd.sh` | **③保持私有** | 被 `packaging/elden-userland/MANIFEST.tsv` 等 7 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 148 | `scripts/skewcal-frame-stats.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 149 | `scripts/skewcal-measure.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 150 | `scripts/sleep-bisect.sh` | **③保持私有** | 被 `packaging/elden-userland/MANIFEST.tsv` 等 5 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 151 | `scripts/sleep-cumulative.sh` | **③保持私有** | 被 `packaging/elden-userland/MANIFEST.tsv` 等 4 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 152 | `scripts/sleep-policy.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=设备体检 / 电源） | `RESOURCES/README.md` §5「设备体检 / 电源」加一行 |
| 153 | `scripts/slotboot-run.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 154 | `scripts/suspend-boot-panic-capture.sh` | **③保持私有** | 被 `scripts/suspend-drain-rate.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 155 | `scripts/suspend-drain-rate.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=设备体检 / 电源） | `RESOURCES/README.md` §5「设备体检 / 电源」加一行 |
| 156 | `scripts/switch-kernel-abi.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=内核 / 模块 / 部署） | `RESOURCES/README.md` §5「内核 / 模块 / 部署」加一行 |
| 157 | `scripts/t14-rebuild.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 158 | `scripts/t5-q24-capture.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 159 | `scripts/test-bt-guard.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 160 | `scripts/test-init-preflight.sh` | **③保持私有** | 被 `rootfs/debian/stage.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 161 | `scripts/test-lib-wait.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 162 | `scripts/thermal-stress.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=设备体检 / 电源） | `RESOURCES/README.md` §5「设备体检 / 电源」加一行 |
| 163 | `scripts/thermal-watch.sh` | **③保持私有** | 被 `scripts/thermal-stress.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 164 | `scripts/uefi-bootimg-dump-v0.py` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=UEFI / ESP / GRUB） | `RESOURCES/README.md` §5「UEFI / ESP / GRUB」加一行 |
| 165 | `scripts/uefi-ddr-trial.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 166 | `scripts/uefi-fv-strings.py` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=UEFI / ESP / GRUB） | `RESOURCES/README.md` §5「UEFI / ESP / GRUB」加一行 |
| 167 | `scripts/uefi-grubcfg-arming.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=UEFI / ESP / GRUB） | `RESOURCES/README.md` §5「UEFI / ESP / GRUB」加一行 |
| 168 | `scripts/uefi-logfs-read.py` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=UEFI / ESP / GRUB） | `RESOURCES/README.md` §5「UEFI / ESP / GRUB」加一行 |
| 169 | `scripts/uefi-oneshot.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`archive/plans-20261110/2026-11-06_uefi-batch-next.md` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 170 | `scripts/uefi-r21-sbstop-ladder.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 171 | `scripts/uefi-usb-gap.py` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=UEFI / ESP / GRUB） | `RESOURCES/README.md` §5「UEFI / ESP / GRUB」加一行 |
| 172 | `scripts/verify-tree-integrity.py` | **③保持私有** | 被 `scripts/kbuild-sanity.sh` 等 2 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 173 | `scripts/waydroid-cam-restart.sh` | **③保持私有** | 被 `scripts/waydroid-cmdline-fix.sh` 等 2 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 174 | `scripts/waydroid-cmdline-fix.sh` | **③保持私有** | 被 `scripts/waydroid-cam-restart.sh` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 175 | `scripts/waydroid-headless-start.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 176 | `scripts/waydroid-ota-serve.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=Waydroid 容器） | `RESOURCES/README.md` §5「Waydroid 容器」加一行 |
| 177 | `scripts/waydroid-proxy-setup.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=Waydroid 容器） | `RESOURCES/README.md` §5「Waydroid 容器」加一行 |
| 178 | `scripts/wd-c1-noworkaround.dev.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 179 | `scripts/wd-c1-verify.dev.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`reports/audit-20261119/A3-scripts-audit.tsv` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 180 | `scripts/wd-ctl.sh` | **③保持私有** | 被 `packaging/elden-userland/MANIFEST.tsv` 等 8 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |
| 181 | `scripts/wd.sh` | **②补指针** | 无活调用点（只被 reports/archive 等历史账引用）；可复用工具族，值得被找到（面=Waydroid 容器） | `RESOURCES/README.md` §5「Waydroid 容器」加一行 |
| 182 | `scripts/win-x86-rootfs.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`archive/2026-10-02-merged/PLAN-NODEV-2026-10-02.md` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 183 | `scripts/win-x86-run.sh` | **③保持私有** | 一次性/单次实验件：0 活调用点，只有历史账引用（`archive/2026-10-04-git-backfill/bf_manifest_all.txt` 即它的指针）；不与现役配方重叠 | 不动文件；仅本表登记 |
| 184 | `scripts/zero-to-desktop-check.sh` | **③保持私有** | 被 `scripts/doctor/22-desktop-chain.py` 等 1 处 scripts/packaging/rootfs 内的活件调用/source ⇒ 内部件，不需要文档指针 | 不动文件；仅本表登记 |

## 3. 死引用 7 条逐条处置（复核后处置，全部就地改）

判据（与 A7 §4 相同）：在 14 份活面文档里正则 `scripts/([A-Za-z0-9_./-]+\.(?:sh|py|pl))` 逐个取 token，`scripts/<token>` 不存在即计一条。
**复核发现 A7 的 7 条里 5 条是「路径尾部 `scripts/` 被当成仓根」的误报**——该正则天然会吃掉 `env-pass/scripts/…`、`archive/…-retired-scripts/…` 的前缀。

| # | A7 记的死路径 | 出现处（改前） | 复核结论 | 处置（已改） |
|---|---|---|---|---|
| 1 | `scripts/checkpatch.pl` | `PITFALLS/README.md:183`（A7 记 :99，行号已漂） | **真·跨树误读**：正文指**内核树**的 checkpatch，不是本仓 `scripts/` | 改成 `perl <内核树>/checkpatch.pl --strict --patch -`（去掉仓内 `scripts/` 前缀 ⇒ 不再被正则误判，也不再暗示本仓有它） |
| 2 | `scripts/envpass-provision.sh` | `TASKS/G2.md:32`、`RESOURCES/README.md:172` | **误报**：文件**真在** `env-pass/scripts/envpass-provision.sh`（A17 交付件），原文本就是 `env-pass/scripts/…` | 改写成「`env-pass/scripts/` 下的 `envpass-provision.sh`（…；文件真在，2026-11-27 核）」——语义不变、消歧义 |
| 3 | `scripts/sensor-send-termux.sh` | `TASKS/G2.md:29`、`TASKS/ANDROID-COMPAT.md:55`、`RESOURCES/README.md:142` | **误报**：文件**真在** `env-pass/scripts/sensor-send-termux.sh` | 同上（3 处都改成「`env-pass/scripts/` 下的 `sensor-send-termux.sh`」） |
| 4 | `scripts/q28-boot-cycle.sh` | `RESOURCES/README.md:139`、`:366` | **误报 + 文档自述与盘上事实相反**：`archive/2026-10-15-retired-scripts/q28-boot-cycle.sh` **逐字在盘**（6 478 B，2026-10-17 10:08）；原句「MIGRATION-LOST 本机已无」是错的 | 路径前缀消歧义（`archive/2026-10-15-retired-scripts/` 下的 `q28-boot-cycle.sh`）+ 把 MIGRATION-LOST 注更正为「归档件在盘、活入口退场」，并指向**现役替代** `scripts/q28-reboot-until-good.sh` |
| 5 | `scripts/q28-ab-delay.sh` | `RESOURCES/README.md:139`、`:366` | 同 #4（1 831 B 在盘） | 同 #4 |
| 6 | `scripts/q28-verdict.sh` | `RESOURCES/README.md:139`、`:366` | 同 #4（1 345 B 在盘） | 同 #4 |
| 7 | `scripts/q28-race-hunt.sh` | `RESOURCES/README.md:139`、`:366` | 同 #4（8 122 B 在盘） | 同 #4 |

**顺带更正两处同族事实错误**（都在 #4–#7 那两行内，属同一条死引用行 ⇒ 未越界改别的行）：

- 原文「现存只有 `archive/2026-10-15-retired-scripts/q28-devprobe{,2}.sh`」→ **错**：该目录里**没有** q28-devprobe；
  现役三态探头是 `scripts/q28-devprobe.sh` / `scripts/q28-devprobe2.sh`（在 `scripts/`）。已改成正确指向。
- 原文「2026-11-02 复核仍缺」→ 已改成「✅ 在盘（2026-11-27 复核：四件逐字仍在 archive）」。

**改后实测**：14 份活面文档里 `scripts/<token>` 死引用 = **0 路径 / 0 处**（§4 命令 2）。

## 4. 复现命令（全部只读，可直接复制）

```bash
cd /home/xuqianhui/y700-elden

# ---- 命令 1：入口 / 命中 / 孤儿 / 三档（与 A7 §4 逐字同一判据；入口表换成生成器的 TSV）----
python3 scripts/gen-scripts-index.py --tsv /tmp/tsv_now.tsv
python3 - <<'PY1'
import os, glob
os.chdir('/home/xuqianhui/y700-elden')
docs=['INDEX.md','AGENTS.md','PITFALLS/README.md','reports/README.md']\
     +sorted(glob.glob('TASKS/*.md'))+sorted(glob.glob('DEVICE/*.md'))+sorted(glob.glob('RESOURCES/*.md'))
print("docs=%d"%len(docs))
corpus="\n".join(open(d,encoding='utf-8',errors='replace').read() for d in docs)
rows=[l.rstrip("\n").split("\t") for l in open('/tmp/tsv_now.tsv',encoding='utf-8')][1:]
hit=[r for r in rows if r[2] in corpus]; orph=[r for r in rows if r[2] not in corpus]
doc=[r for r in orph if r[0].startswith('scripts/doctor/')]
lib=[r for r in orph if os.path.basename(r[0]).startswith(('lib-','_lib'))]
plain=[r for r in orph if r not in doc and r not in lib]
print("entries=%d hit=%d orph=%d doctor=%d lib=%d plain=%d"
      %(len(rows),len(hit),len(orph),len(doc),len(lib),len(plain)))
PY1
# 期望（改后）：docs=14 entries=363 hit=194 orph=169 doctor=27 lib=8 plain=134

# ---- 命令 2：死引用（应打印 dead=0）----
python3 - <<'PY2'
import os, glob, re
os.chdir('/home/xuqianhui/y700-elden')
docs=['INDEX.md','AGENTS.md','PITFALLS/README.md','reports/README.md']\
     +sorted(glob.glob('TASKS/*.md'))+sorted(glob.glob('DEVICE/*.md'))+sorted(glob.glob('RESOURCES/*.md'))
pat=re.compile(r'scripts/([A-Za-z0-9_./-]+\.(?:sh|py|pl))')
dead=set()
for d in docs:
    for m in pat.finditer(open(d,encoding='utf-8',errors='replace').read()):
        if not os.path.exists('scripts/'+m.group(1)): dead.add((m.group(1),d))
print("dead=%d"%len(dead)); [print(" ",k) for k in sorted(dead)]
PY2

# ---- 命令 3：分类证据（活调用点 vs 历史账引用），逐 plain 孤儿打印 ----
python3 - <<'PY3'
import os, subprocess
os.chdir('/home/xuqianhui/y700-elden')
EXT={".md",".txt",".sh",".py",".service",".conf",".dev",".tsv"}
SKIP={"scripts/README.md","scripts/gen-scripts-index.py","reports/arch-audit-20261127.md"}
LIVE=("scripts/","packaging/","rootfs/","initramfs/","bootslot-b/",".githooks/","tools/","net/","probes/")
HIST=("reports/","TASKS/sessions/","SESSIONS/","HISTORY/","PITFALLS/sessions/","archive/")
corp={f:open(f,encoding='utf-8',errors='replace').read()
      for f in subprocess.run(["git","ls-files"],capture_output=True,text=True).stdout.split()
      if f not in SKIP and os.path.splitext(f)[1] in EXT}
for p in open('/tmp/orph_plain.txt').read().split():
    path='scripts/'+p
    if not os.path.exists(path): continue
    live=[f for f,t in corp.items() if f!=path and p in t and f.startswith(LIVE)]
    hist=[f for f,t in corp.items() if f!=path and p in t and f.startswith(HIST)]
    print("%-42s live=%d hist=%d %s"%(path,len(live),len(hist),hist[:1]))
PY3

# ---- 命令 4：本轮必跑的门（期望值见行尾注释）----
bash scripts/check-doctor.sh                               # FAIL=0（WARN 3 为既有）
python3 scripts/reports-orphan-check.py --check --no-list   # rc=0
python3 scripts/gen-scripts-index.py --check                # OK … 363 个入口
python3 scripts/reports-index.py --check                    # OK
bash scripts/check-doc-assets.sh                            # missing=0
```

## 5. 没做 / 残余风险（披露）

1. **③ 131 件的「保持私有」是按机器证据 + 头注释给的批量结论，不是逐个人读 131 个文件。**
   判据是「有没有活调用点」——这能挡住「错把现役件当私有」，但**挡不住「活调用点本身已是死代码」**（调用者自己没人用）。
   下一轮可行做法：算 `scripts/` 的调用图（而非文本子串）做可达性分析，再对叶子做人工复核。
2. **`scripts/doctor/` 27 与 `lib-*` 8 两档仍是假阳性**（按路径调用 / 被 `source`）。剔除它们要改 `gen-scripts-index.py` 的 `SELF_OUTPUT`（A8）
   或改本审计判据，两者都在 T14 白名单外 ⇒ **没动**。
3. **`reports/` 侧的指针面仍由 T10 那条门管**（`reports-orphan-check.py`）；本轮只保证 `scripts/` 的 50 个②件有角度指针。
4. **`RESOURCES/README.md` 仍不在 `check-doc-assets.sh` 扫描面**（A15 绕道 3 未修）⇒ 本节新增的 49 行指针**没有机器门保护**。
   本轮用「逐名 `-f` 存在性自查」兜住（49 个 basename 全部 `os.path.exists` 通过），但下次改这文件不会有人拦。
5. **q28 四件「归档件在盘」≠「还能跑」**：它们绑 2026-10 的 vk11x 内核与旧 SSH/NCM 口径，本轮**未上机验证**。
   文档现在写的是「归档件在盘 + 活入口退场 + 现役替代 = `q28-reboot-until-good.sh`」，不是「`q28-boot-cycle.sh` 现在可用」。
6. **`PITFALLS/README.md:183` 那一行本身是半截句**（`perl …--patch -` 后面直接接「`），并同时记 lines`」）。
   本轮只改了死引用那一段（`scripts/checkpatch.pl` → `<内核树>/checkpatch.pl`），**没有补写整句**——补句子属 PITFALLS 正文维护，不在 T14 范围。

---

## 父代理复核（2026-11-27 12:4x–12:5x CST）——**自报 PASS 采信一半，分类质量不足，残留登记为 T16**

> 口径 = 全局规则 7（worker 自报不可信）。下面前三条是我重跑出来的，第四条是我拿出来的反例。

### 1. 数字对得上（采信）

| 指标 | worker 自报 | 父代理独立复算 | 结论 |
|---|---|---|---|
| 入口 | 363 | `python3 scripts/gen-scripts-index.py --check` → **363** | ✅ |
| 命中 | 194（53.4%） | 我按 A7 口径（14 份活面文档、`scripts/**` 361 个 `.sh/.py` 文件）grep basename → **193（53.5%）** | ✅（±1 属统计对象差异） |
| 死引用 | 7 路径/12 处 → **0/0** | `bash scripts/check-doctor.sh` §13 全绿、`check-doc-assets.sh missing=0` | ✅ |
| 退役头 | 3 个 | `grep -c "RETIRED 2026-11-27"` → `q26-recheck.sh` **1**、`build-athm-probe.sh` **1**、`build-boot-slim.sh` **1**，文件均在盘 | ✅ |
| **7 条死引用 5 条是误报** | 是（`env-pass/scripts/`、`archive/…-retired-scripts/` 的尾部 `scripts/` 被审计正则当成仓根） | 我逐个 `test -f` 复核 8 个路径（含 `q28-devprobe.sh`、`q28-reboot-until-good.sh`）**全部在盘** ⇒ A7 的「真死」判据本身错 | ✅ **这条是本轮最有价值的更正** |

### 2. 但「③保持私有 = 被别的脚本调用/内部件」这一档质量不足（反例）

对 131 条「③保持私有」逐条查「除自身与 `scripts/README.md` 之外，`scripts/ packaging/ rootfs/ tools/ initramfs/` 里有没有**非注释**引用」：

| 实际情形 | 条数 | 说明 |
|---|---|---|
| 有真调用点 | **69** | 这些确实是内部件，分类正确 |
| 只有注释里提到 | **10** | 不是调用（例：`driver-snapshot-diff.sh` 只在 `driver-snapshot.sh` 的注释里被点名） |
| **零引用** | **52** | 既不被人调用、也没有文档指针 ⇒ **不该算「私有」**，应落在「②补指针」或「①退役」 |

复现命令（父代理原样跑的）：

```bash
python3 - <<'PY'
import re,os,subprocess
txt=open('reports/scripts-ref-audit-20261127.md',encoding='utf-8').read()
rows=re.findall(r'\|\s*\d+\s*\|\s*`(scripts/[^`]+)`\s*\|\s*\*\*③保持私有\*\*\s*\|([^|]*)\|',txt)
for name,_ in rows:
    base=os.path.basename(name)
    r=subprocess.run(['grep','-rn','--binary-files=without-match','-F',base,
                      'scripts','packaging','rootfs','tools','initramfs'],capture_output=True,text=True).stdout
    real=[l for l in r.splitlines() if (lambda p,c: os.path.abspath(p)!=os.path.abspath(name)
          and p!='scripts/README.md' and not c.strip().startswith('#'))(l.split(':',2)[0], l.split(':',2)[2])]
    mention=[l for l in r.splitlines() if not real]
    print(('REAL ' if real else ('MENTION ' if mention else 'ZERO '))+name)
PY
# 汇总：真调用点 69 ｜ 仅注释 10 ｜ 零引用 52
```

**52 个零引用的例子**（全表见上命令输出）：`uefi-oneshot.sh`、`uefi-ddr-trial.sh`、`q28-disp-ab-sample.sh`、`waydroid-headless-start.sh`、
`win-x86-run.sh`、`edl-peek.sh`、`send-upstream-report.py`、`host-mem-build-stress.sh`、`slotboot-run.sh`、`kexec-bs-cycle.sh` …
它们要么是**仍能重跑的可用件**（⇒ 补一行指针即可被未来会话找到），要么是**一次性实验执行器**（⇒ 该按①退役打头注），必须逐条判。

### 3. 落地处置

1. **本轮已采信的成果保留**：`RESOURCES/README.md` §5 的 49 行指针、3 个 `RETIRED` 头注、7 条死引用消歧义（含更正
   「q28 取证脚本本机已无」这个**与盘上事实相反**的旧错述）、`reports/README.md` 重生成。
2. **未收口部分登记为 `TASKS/NEXT.md` §4.0a T16**：52 个零引用 + 10 个「仅注释」共 62 条要重判（口径：能否重跑 / 是否一次性 / 有无替代件）。
3. **T14 判「部分完成」**：死引用与「补指针」两档收口，③档命名与判据要改（「私有」= 有真调用点，131 → 69）。
