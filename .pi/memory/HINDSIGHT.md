# Hindsight — elden（y700-elden）

Techniques and root causes proven on Qualcomm/Lenovo tablet flashing. Host-machine

<!-- Older entries compacted -->
   # 一次性
   scripts/iterate.sh kernel --boot VERSION=vk50        # fastboot 零写盘验证
   ```
   之后驱动改动就进 `iterate.sh mod ...` 的 30s 环。
2. **首次 kexec 实测**（用已知good的 vk49/vk50 镜像先验证不崩外设）：
   ```
   scripts/iterate.sh kernel --kexec VERSION=vk51
   ```
3. 若要我把内核仓也做成完整非浅历史（需 `git fetch --unshall


## Automatic settled outcome - 2026-10-04

## 复核结论（先数字）

| 维度 | 判定 | 关键数字 |
|---|---|---|
| 1 可记录可溯源 | 🟡 骨架好，**2 个闭环漏洞** | doctor FAIL=0/WARN=1；git 纳管 391 文件、双仓双远程、回填 107 提交+49 tag；**manifest 生成数=0 且被 .gitignore 吞** |
| 2 规划/并发/子代理 | 🔴 **子代理定义整体过期** | 6 角色+11 任务书 **100% 仍引用已退役 swarm**（`send SageYak`/`task done`/SWARM-PLAN 旧路径）；设备锁覆盖 **3/5**（flash-b.sh、cycle.sh 无锁） |
| 3 迭代/忙等 | 🟡 工具全在，**快环未接通** | ccache 缓存 **8 KB（从未命中）**；`WCD939X=y` 未模块化 ⇒ 音频进不了 30s 环；kexec 实测 **0 次**；轮询已全部有界 ✅ |

---

## 维度 1：可记录可溯源

**做得对**：6 文档分层 + SSOT 声明、archive 只增不改、git 回填+graft+VERSION-MAP、双异地备份、`check-doctor` 守门、.gitignore 边界有注释台账。

**漏洞**：
1. **manifest 闭环断裂**：`scripts/build-manifest.sh:9` 自己写着 "Commit the manifests"，但产物写到 `out/`，而 `.gitignore:18` 整目录忽略 `/out/`，且无 `!/out/*.manifest` 例外 → **每版可复现指纹永远进不了 git**。vk49 及之前的版本也还没有 manifest（生成数=0）。
2. **入口目录混散件**：根目录有 `sn.img`（BL 解锁证据，UNTRACKED）、`dtc-*.whl`、5 个 `y700-elden-docs-*.tar.gz`——与"根目录只有 6 文档+AGENTS"纪律冲突，且都不在 git 里。
3. 小项：RESOURCES §4 收录 54 ≠ 实际 68 会话（doctor 已 WARN）；`.pi/memory/HINDSIGHT.md` 有 +51 行未提交。

## 维度 2：规划任务 / 并发 / 冲突合并 / 子代理

**做得对**：TASKS 唯一台账+§2.1 主机侧并行清单、`device-lock.sh` flock 语义正确（自锁可嵌套、`DEVICE_LOCK_HELD` 透传）、AUDIT3 教训（副作用与轮询不同条命令）已写进任务书、retry 参数已按限流调好、默认模型已切 deepseek。

**漏洞（按危害排序）**：
1. **子代理不可用级过期**：`.pi/agents/*.md` 6 个角色与 `.pi/missions/*.md` 11 个任务书全部是 swarm 时代原文——`send SageYak`、`task done task-12`、"先读 `AUDIO-2026-10-01.md`"（实际在 `archive/topics/`）、`SWARM-PLAN-2026-10-02.md`（同）。`smoke.md` 还绑在已不存在的 task-12。**现在派生这些 Agent 类型，子代理会先浪费多轮去执行不存在的命令/读不存在的路径**，且任务书里"设备当前 vk34"等状态已落后 13 个版本。
2. **锁旁路**：`mod-loop/kexec-boot/to-fastboot` 自锁，但 `flash-b.sh`（写 boot_b+重启）与 `cycle.sh`（reboot/fastboot）无锁——而 **INDEX §4 快速命令恰恰推荐的就是这两条无锁路径**。并发子代理照 INDEX 行事即可撞车。
3. **规划项过期**：TASKS §4 第 1 步"⛔ 先救机器：U2 不可达"与 INDEX §3"U2=vk47 持久直启在跑"矛盾（§4 未随 10-03 深夜恢复刷新）；INDEX §3 快照 82% vs §0 的 85%（SSOT 已声


## Automatic settled outcome - 2026-10-04

P0+P1（无设备项）全部落地并推送。总结：

## 已完成（3 个提交 → origin/main）

| 项 | 内容 | 验证 |
|---|---|---|
| ① 子代理现代化 | 11 份任务书+5 份角色全部重写：**4 条活跃线**（audio 残余/bench/camera 出流/gplay+el2 收口动作）状态对齐 vk49 并指向 `archive/topics/` 真路径；**7 条已收官线**改为「墓碑+残余」，误派时先报告"已收官"不空转；删 `smoke.md` | `send SageYak`/`task done`/`SWARM-PLAN`/`task-N` **0 残留**；新引用路径**全部存在** |
| ② 锁旁路消除 | `flash-b.sh`/`cycle.sh` 补与 mod-loop 同款自锁；INDEX §4 快速命令从 sign+flash-b 改为 `scripts/iterate.sh` 四档环 + `device-lock.sh --status` | 实测三态：空闲拿锁 ✅、被占 1s 报 busy 退出 ✅、`device-lock.sh` 外层持锁时内层透传不死锁 ✅ |
| ③ manifest 闭环 | `.gitignore` 改 `/out/*` + `!/out/*.manifest` | `check-ignore`：img/子目录仍忽略、`.manifest` 放行 ✅ |
| ④ 双 iterate | 根 `iterate.sh` 改为 `exec scripts/iterate.sh`（带新用法注释） | `bash -n` ✅ |
| 顺手 | 修了一个**复核时新发现的 TASKS 原生死引用**：`build-camera-overlay.sh` 实际在 `rootfs/` 而非 `scripts/`（TASKS G1-5 + 任务书同改） | 存在性核实 ✅ |

`check-doctor` FAIL=0（WARN=1 仍是既知的会话索引 54≠68，属 P2）。

## 剩余（下次上机/收工时顺手）

- **P1⑤ 快环接通**（唯一需设备的一次性动作）：`scripts/apply-kernel-fragment.sh patches/fragment-modular.config` → 全量构建一次（带暖 ccache）→ `iterate.sh kernel --kexec` 首测 → 音频 30s mod 环首测。
- **P2**：RESOURCES §4 补 14 个会话；提交 HINDSIGHT 的 +51 行；TASKS §4 删过期的"⛔ 先救机器"；根目录散件归档（`sn.img`/`dtc-*.whl`/5 个 docs tar.gz）；doctor 加 G1% 口径检查。

上机那轮开始时说一声，我把 P1⑤ 和 G1-22/G1-5 的验证合并进同一次会话计划。


## Memory - 2026-10-04

y700-elden 镜像版本归属：boot 镜像文件名 vkNN 与内部内核无关——"vk47.img" 实为 vk46-dirty 内核（commit 在构建后补记），连内核流 sha 也只证"与哪个文件相同"不证版本名。唯一可靠链 = manifest（构建时生成）+ uname 内嵌 LOCALVERSION=-vkNN（2026-10-04 起）；对历史镜像解 gzip 内核流取 "Linux version" UTS 串定性。


## Automatic settled outcome - 2026-10-04

审计完成。全部只读（ls/test/rg/git log/read），未删改任何文件。

# 只读审计报告 — ~/y700-elden（2026-10-05）

**先数结论**：`.pi` 路径引用 93 处核实 **0 真死链**（missions/agents）；SKILL.md 引用 **2 处问题**；无引用脚本 **10 个**（其中 7 个死脚本候选）；HINDSIGHT 有 5 行值得提交；settings/README 无过时。

---

## 一、.pi 配置（agents / missions / skills / settings / README）

| 路径 | 问题 | 证据 | 建议 |
|---|---|---|---|
| `.pi/missions/` + `.pi/agents/`（16 份） | ✅ 健康：93 处路径引用 `test -e` 全部存在（含通配符 `AUDIO-*`、`0011-*` 均命中）；状态全部写 vk47/vk49，与 INDEX §3 一致，**无 vk34/vk40 过期残留**（vk43 均为历史事实表述） | python 提取全部反引号路径核实 | 保留 |
| `.pi/missions/`（覆盖缺口） | bench.md / el2-virt.md / gplay.md 3 份**活跃任务书无对应 agents/ 角色定义**（agents 仅 5 个：audio-graphopen/camera/proxy-waydroid/thermal/win-x86-poc） | `ls .pi/agents/` 对比 `ls .pi/missions/` | 更新：补 3 个角色或派发时用 general-purpose |
| `.pi/missions/thermal.md`（墓碑+残余） | 残余动作（其余热点 passive 盘点、GPU 分级复核）**未并入 TASKS.md**（rg ‘GPU 热区’/‘其余热点’ 在 TASKS 无独立行） | `rg 'GPU 热区' TASKS.md` 空 | 保留（有独特残余判据） |
| `.pi/missions/proxy-waydroid.md`（墓碑+残余） | 残余（netd 原生路由核实/workaround 退役判据）TASKS §2 无独立行（仅 §6 图景一句） | `rg 'netd' TASKS.md` | 保留 |
| `.pi/missions/audio-graphopen.md` | 根因链已被 `audio.md`「现状（已完成，勿重做）」段 + TASKS G1-4 完整覆盖，残余指向 audio.md | 两文件对照 | **可删候选**（低优先） |
| `.pi/missions/stock-camgrav.md` | 纯路标：相机→camera.md、传感器→C4（TASKS §2 C4 均在） | 6 行 | **可删候选**（低优先） |
| `.pi/missions/win-x86.md` | 纯墓碑，指向 archive + win-x86-poc.md；TASKS 59 行 C-历史已覆盖 | 4 行 | **可删候选**（低优先） |
| `.pi/missions/win-x86-poc.md` | 护栏（cgroup/timeout/trap）已进 `FAILURES.md`（Box64 记录）；残余“游戏兼容未排期”TASKS 196 行有 | 对照 | **可删候选**（低优先） |
| `.pi/skills/qualcomm-android-flashing/SKILL.md:81` | **真死链**：`references/dual-boot-complete-2026-08-10.md` 不存在（本 skill references 有 `tb322fc-dualboot-2026-09.md`，疑似改名/从未建） | `test -e` MISS | 更新：改指 2026-09 文档或补建 |
| `.pi/skills/qualcomm-android-flashing/SKILL.md:77` | 路径缺 `../`：写


## Automatic settled outcome - 2026-10-04

审计完成。以下为发现清单（全部只读核实，未动任何文件）。

# 只读审计发现清单 — y700-elden 文档精简（2026-10-04）

**核实方法**：6 份文档全读 + 90+ 个引用路径逐一 `test -e` + `du`/`ls` 对账 + 会话文件计数。

## 1. 引用不存在的文件（doctor 查不到的正文反引号路径）

| 位置 | 问题 | 证据 | 建议 |
|---|---|---|---|
| RESOURCES §2.1（locked 链构建行）+ PITFALLS #85 | **`scripts/extract-avfpubkey.py` 不存在** | `test -e` MISS；两处引用均称"提取工具" | 更新（确认改名或已并入其他脚本） |
| RUNBOOK-BRINGUP.md:375 | **`patches/config-vk-modular` 不存在**，实际名为 `config-vk50-modular` | `ls patches/` 只有 config-vk50-modular | ★只需改一个名字 |
| PITFALLS #74（约 :467） | **`scripts/net-up-manual.sh` 不存在** | `test -e` MISS | 更新（NM 版已取代则删引用） |
| INDEX.md:148 | `flashing-bundle-2026-09-29.tar.gz` 已不在根目录 | 实际在 `archive/2026-10-04-root-strays/`（10-04 归档） | ★只需改路径 |
| RESOURCES §3 顶层台账 "flashing-bundle/ + flashing-bundle-\*.tar.gz \| 19 M" | 同上，tar.gz 已归档 | 同上；台账同节已有 root-strays 行，两行重复 | 合并两行 |
| 其余 85+ 引用（INDEX §6 全部专题档案、TASKS/RUNBOOK 全部脚本、backup/avf/stock、外部 ~/mesa-out、~/下载/tb322fc、~/文档/TB322FU…） | 全部存在 ✅ | test -e 全 OK | 无需动 |

## 2. 过时的数字/状态（含已知“51 会话”同类）

| 位置 | 问题 | 证据 | 建议 |
|---|---|---|---|
| INDEX.md:40、:117 | 会话数 **"51 会话"** | RESOURCES §4 自称 68 条；实际 `.pi/sessions` 递归 **72** jsonl（顶层 63） | ★只需改数字 |
| RESOURCES.md:190 vs :270 vs :195 | 同文档三处会话数 **59 / 68 / 54 互不一致** | 实际递归 72 / 顶层 63 | 统一为一处权威（§4），§3 台账改链接 |
| RESOURCES.md:193 | "archive/ 1.1 M \| 57 篇专题" | 实际 5.4 M / **62** 篇 topics md | ★只改数字 |
| RESOURCES.md:157（§2.5 P1） | "其余 **33 个** boot 镜像" | `out/` 实际 **57 个** boot-elden-\*.img | ★只改数字 |
| TASKS.md:15 | "运维/资产：内核 **vk45**" | out/ 已有 vk46–vk50 + `vk50.manifest`；§4 也述 vk50 | ★只需改数字 |
| TASKS.md:92（§4 步骤 1） | "快环接通（vk50）…kexec 首测" 仍列为下一步，但 RESOURCES §4 表 01a105d1（最新会话）已记 "vk50 构建+kexec 首测”；且同条说“设备实跑 vk46-dirty" | 两处互斥 | **需用户确认**后勾销或改写 |
| INDEX §3 vs TASKS §4 vs RESOURCES §4§3 vs DEVICE §2.2 | **U2 在跑版本四处口径：vk47 / vk46


## Automatic settled outcome - 2026-10-04

这是会话审计子代理的超限失败通知——该维度我在主会话已用脚本补齐并整合进清单（S1–S4），无新增发现。

审计三轮通知全部收官，状态不变：**等你审批** `archive/topics/清理清单-2026-10-04-精简审计.md` 里的编号项（E1–E6 产物 ~7.3 G、S1–S4 会话、D1–D19 文档、C1–C7 配置/脚本）。回复编号即可执行。


## Automatic settled outcome - 2026-10-04

全部执行完毕并推送（`76c444c` → origin/main）。

## 执行总结（先数字）

| 维度 | 结果 |
|---|---|
| 空间 | **28 G → 22 G（省 ~6 G）** |
| 提交 | `76c444c` 已推送 origin/main，工作区干净 |
| doctor | **FAIL=0**（死链检测扩覆盖后扫 26 份文档无死链；唯一 WARN=会话 66≠索引 68，属未批的 S3） |

## 已执行

**删除（批=E1/E2/E4/E5/S1/C1/C2）**
- E1 out/ 旧镜像 **47 个（3.7 G）**；E2 out/archive（1.3 G）；E4 env-pass 中间物（494 M）；E5 swarm 日志（80 M）；S1 五个 junk 会话
- C1 七个死脚本 + C2 四份被覆盖任务书（git rm，历史可回溯）

**D 组（含你给的 vk50 事实）**
- **vk50 kexec 首测失败（内核未换动、无反馈、半成品）**→ 落 `TASKS.md` §4 步骤 1（改写为失败状态，下一步=排查静默失败）；INDEX §3 / DEVICE §1.1、§2.2 同步把 **U2 实跑口径统一为 vk46-dirty**（vk47 文档口径作废）
- DEVICE §1.1 基线段整段重写（vk39/vk40 过时口径）、U2 行 a/b 槽错位修正并精简指向 TASKS；GAPS Q7（=193 GiB）/Q8（出声+采集）标已解决；4 个死路径全修

**C 组**
- **D1 意外发现**：`build-locked-chain.sh:88` 还在静默调用不存在的 `extract-avfpubkey.py` → **补回重建**（~50 行），自测 PASS：对自签 vbmeta 提取 == `avb.avbpubkey` 逐字节一致
- SKILL 2 处引用修正；**check-doctor 扩覆盖** missions/agents/SKILL（原 2 处 SKILL 死链正是漏网）；RESOURCES §2.1 补全量口径；补 3 份角色定义（bench/el2-virt/gplay）；提交 HINDSIGHT +5 行

## 清单外保留（逐个理由，已记录在执行记录里）
`v1-thermal`/`v2-audio`（**G1-23 V1/V2 二分镜像**，删则实验报废）、`vk46{,-ram}`（实跑版本对账锚点）、`vk47a-ram`（基线家族变体）

## 未批不动
**E3** bootslot-b 历史签名包（672 M）、**E6** *.bak、**S2-S4**（子代理会话/补索引/旧会话归档方案待拍板）

全量清单+执行记录：`archive/topics/清理清单-2026-10-04-精简审计.md`


## Automatic settled outcome - 2026-10-04

## 当前进度（截至最后一次提交 `76c444c`，已推 origin/main）

**上一轮做的事**：精简审计执行 —— 磁盘 **28G → 22G**，清掉 47 个旧镜像、junk 会话、7 个死脚本，`check-doctor` FAIL=0。同时把 **vk50 kexec 首测失败**落账，全文档把 U2 实跑口径统一为 **vk46-dirty**（vk47 口径作废）。

### 两个目标

| 目标 | 完成度 | 硬缺口 / 待办 |
|---|---|---|
| **G1** 健全 Linux + 原厂固件驱动 | **~85%** | 3 个硬缺口：**相机出流**、**TF 卡**、**BT 配对**（音频播放+输入已✅） |
| **G2** 无 Android 兼容安卓 | **~45%** | Waydroid/Win-x86 通路就绪；待 C1 复跑 → C3 身份取证 → C2 Play → C4 传感器部署 |

设备：U2 = BL 已解锁 + b 槽 mainline 持久直启（`/`=`/dev/sda17` ext4，Phosh 自启）；U1 = stock Android + root，无 Linux 分区。

### 下一步（TASKS §4，按序）

1. **快环接通排查**（唯一卡点）：vk50 全量构建成功但 **kexec 未换动内核、静默失败**，需先排查（可用 `--boot` 环对照）；之后才是 30s mod 环首测。
2. **G1-5 相机出流**：`UYVY8_1X16` vs `SRGGB10` 格式协商断点（media-ctl）。
3. **G1-22 熄屏重启**：先烧 vk34recon 作基线再二分。
4. **C0 真 Android 对照取证**（U1，覆盖 a 槽前不可复得）。
5. C1 → C3 → C2（C2 需你恢复上行+凭据）。
6. 顺路单变量：BT H1/H2、换卡 A/B、C4 传感器部署、C8 Gunyah 探测。
7. 不占设备：G1-8 基准、G1-9 DP、C5/C6/C7、上游化 M1–M5。

### 一处待处理

工作区唯一未提交改动 = `.pi/memory/HINDSIGHT.md`（+35 行自动记录的本轮执行总结），其余干净。

要不要现在开一轮上机，把 **P1⑤ 快环排查（kexec 静默失败）** 与 **G1-5 / G1-22 验证**合并进同一次会话？


## Automatic settled outcome - 2026-10-04

设备没有看门狗复位，需要你**手动强制重启**：

**操作**：长按 **电源键 ≥ 15 秒**直到屏幕黑掉松开；若无效，试 **电源键 + 音量加** 组合键（高通强制复位）。

复位后它会按 ABL 默认启动 **b 槽（boot_b = vk46 Linux，持久直启）**。启动完成后我这边检测到 `enx` 就会自动 SSH 进去继续。

我这边现在做两件事，等你复位：
1. 后台重建 vk50 全量模块（`LOCALVERSION=-vk50`）—— 这是**必修**的：当前 vk50 内核 UTS 带 `-vk50`，但磁盘/ramdisk 里的模块全是 `7.2.0-debug-g5a70ade46a88`（不带），vermagic 不匹配，相机/音频/WiFi 模块根本加载不了。这也是让 30s mod 环能用的前提。
2. 复位后读 pstore/串口，确认 kexec 挂死点。

### 已确认结论（本轮 kexec 诊断）
| 阶段 | 结果 |
|---|---|
| `kexec -s -l`（load） | ✅ RC=0，`kexec_loaded=1` |
| `kexec -e`（execute） | ❌ **硬挂死**：串口日志在 t≈182s 处中止，无新内核启动横幅、无 panic、无看门狗复位；USB/网络/fastboot 全消失 |

所以旧的"kexec 未换动内核、无反馈"= **执行阶段把 SoC 挂死**，不是配置缺失。kexec 快环在这台机器上当前不可用。

复位后告诉我一声（或我检测到设备自动继续）。


## Automatic settled outcome - 2026-10-04

## 本轮成果（先数字）

| 项 | 结果 |
|---|---|
| 提交 | **`99d49aa` 已推送** origin/main；doctor **FAIL=0** |
| **G1-5 相机出流** | ✅ **前后摄均连续出帧**（此前一直卡在 `-32`） |
| **kexec** | ❌ 定论**不可用**（`-e` 硬挂整机，非配置问题） |
| vk50 模块 | ✅ 用 `LOCALVERSION=-vk50` 重建 **1513 个**，vermagic 与内核一致 |

### G1-5 关键结论
- **前摄** `gc08a8`：`SRGGB10_1X10` 3264×2448 → csiphy4→csid0→vfe0_rdi0→`/dev/video0`（pRAA），10 帧 `<<<<<<<<<<`
- **后摄** `s5kjns`：`SGRBG10_1X10` 4080×3072 → csiphy3→csid1→vfe1_rdi0→`/dev/video3`（pgAA），3 帧 `<<<`
- 帧尺寸精确吻合（9,987,840 = 4080×2448；15,679,488 = 5104×3072）
- **根因**：csiphy/vfe 默认 `UYVY8_1X16` 与 sensor raw 不匹配 + 链路未使能。用 `media-ctl` 整链统一格式 + `-l` 使能即解——**与 3A/供电/时钟无关**。
- 固化：`scripts/camera-stream-up.sh {front|rear} [stream N]`（幂等）

### kexec 定论
`kexec -s -l` **成功**（RC=0、`kexec_loaded=1`），但 `kexec -e` **硬挂整机**：串口 t≈182s 戛然而止、无 panic、无看门狗、USB/网络/fastboot 全消失、pstore 空，需物理强制重启。旧"未换动内核、无反馈"= 这次硬挂。→ 内核迭代改用 **fastboot 零写盘 `boot`/`flash`**。

### 当前设备状态与遗留
- 设备正跑 **vk50**（`fastboot boot`，RAM 内核 + 磁盘根 vk46），SSH 通、双摄可用；**一重启即回 boot_b=vk46**。
- ⚠️ 两个待办：
  1. **镜像超分区**：vk50 镜像 101 MB > boot_b 96 MiB（`build-camera-overlay.sh` 忘了给 `BASE=` 重复叠加）。要刷槽需用 `BASE=out/rootfs-overlaid.cpio.gz.bak-vk48` 重建到 <96 MiB。
  2. **音频模块加载器缺失**：vk50 起音频等驱动改 `=m`，目前无人加载（相机不受影响）。这是 mod 环迁移的另一半。

---

下一步建议二选一：

- **A. 继续 G1-22**（熄屏重启）基线：零写盘 `fastboot boot` vk34recon / vk40 对照 + 空闲熄屏复现。耗时长、会重启，但符合你之前"合并进同一次会话"的意图。
- **B. 先收尾**：把 vk50 重建成可刷的 <96 MiB 版本（并补音频加载器），再做 G1-22。

你要 A 还是 B？（设备目前也能直接停在这，重启回 vk46 即可）


## Automatic settled outcome - 2026-10-04

已落地并推送 `bfe0002`。先给结论，再给约束。

## 已完成（含冒烟验证）

| 产物 | 作用 | 验证 |
|---|---|---|
| `scripts/lane.sh` | `new/list/done/merge/remove/install/alloc`：worktree+分支+元数据 | ✅ 建/删 lane、hook 生效、清理无残留 |
| `.githooks/commit-msg` | lane 分支强制 trailer；lane 名与分支一致性校验 | ✅ 无 trailer→FAIL；错 lane→FAIL；齐 trailer→PASS |
| `versions/vk-registry.tsv` | vk 号 **SSOT**，`flock` 原子分配 | ✅ 已 seed vk50，下次给 vk51 |
| `scripts/iterate.sh` | `next_vk` 改调 `lane.sh alloc`（不再扫 `out/` 猜号） | ✅ 语法检查 |
| `.pi/CONCURRENCY.md` | 约束正文 | ✅ `check-doctor` FAIL=0 |

## 模型：single integrator + forked lanes

```
main ─ base/<date>-<sha> ─┬─ lane/c3-id   (worktree) ─ commits ─┐
                          ├─ lane/c7-slot  (worktree) ─ commits ─┤ 父 merge --no-ff
                          └─ lane/upstream (worktree) ─ commits ─┘  解冲突+doctor+tag
```

## 约束（不可变式）

1. **单写者**：只有父写 `main`、领域层 5 文档、`.githooks`、`versions/`。
2. **文件归属不重叠**：lane 只写自己路径；跨路径回父协调。
3. **lane 只从 baseline 前进**，不 rebase、不 merge main 进来。
4. **内核改动必走 worktree**（`geekidos-linux` 13 G，禁止主 checkout 并发改）。
5. **设备单一串行**：上机/刷写走 `device-lock.sh`，同一时刻一个 lane 持设备。
6. **并发 ≤3**。

## 子代理提交格式（可区分）

```
camera: 前摄出流打通（vk52）

Lane: camera
Agent: camera              # .pi/agents/<role>.md
Baseline: base/20261005-99d49aa
Task: G1-5
VK: vk52
```
`git log --format='%(trailers:key=Lane,valueonly)'` 可机器归集。绕过：`LANE_HOOK_SKIP=1`。

## 版本号：修掉撞车根因

旧 `next_vk()` 扫 `out/boot-elden-vk*.img` → 两个并发构建必取同一个 N。现改为对 `versions/vk-registry.tsv` `flock` 后取 `max+1` 并追加一行，台账入库，父在 merge 时一并提交。

## 当前并行 lane 规划

| lane | 任务 | 只写 | 设备 |
|---|---|---|---|
| `c3-id` | C3 身份/DRM 取证+社区对照 | `archive/topics/c3-*`、`.pi/drafts/` | 无 |
| `c7-slot` | C7 slot 脚本 + A16 `new-tablet` 参数化 | `scripts/` | 无 |
| `upstream` | M1–M5 上游化补丁整理 | `patches/` | 无 |
| （设备 lane） | G1-22 二分 / BT H1·H2 / G1-8 基准 / C1 | 内核 worktree | *


## Automatic settled outcome - 2026-10-04

已推送（`99d49aa` → `bfe0002` → **`2bbd3ea`**；`bfe0002` 是并发会话的 vcs 提交，已在其上）。doctor **FAIL=0 WARN=0**。

# G1-22「熄屏 → 整机重启」彻底查清结果

## 受控复现（零写盘，`scripts/g1-22-dpms-test.sh`）
唯一可靠触发 = **DPMS off**（`wlr-randr --output DSI-1 --off`），不依赖等 5 分钟空闲。

| 内核 | 熄屏测试 | 复位 |
|---|---|---|
| vk34recon | 5 轮 off/on | ❌ 无 |
| v1-thermal（仅热区 DTS） | 5 轮 + **持续 90s** | ❌ 无（×2） |
| v2-audio（仅插桩音频） | 5 轮 + **持续 90s** | ❌ 无（×2） |
| **vk40 原始** | **1 次 off** | ✅ **硬复位 3/3** |
| **vk42（热区 + 干净音频）** | 5 轮 + 90s | ❌ **无** |
| **boot_b 当前 `g4c68eb5ed4e3`** | 10 轮 + 持续 90s | ❌ 无 |

**关键对照**：vk40 引导后**不做熄屏**稳定 ≥151s（uptime 连续）⇒ 复位确由熄屏触发，不是自崩。

## 根因
- 源码二分确定性：`git diff vk40 vk34-recon` = 恰好 5 文件；**v1+v2 源码上 == vk40**；DTB 校验证明 v1 的 DTB == 原始 vk40 DTB（重建忠实）。
- vk40 音频改动含三处插桩：**N1**（`dev_info` 实参里同步调用 `q6apm_get_apm_state()`，每次 probe/开图都额外向 ADSP 发 `GET_SPF_STATE` 并阻塞等待）、**N4**（`print_hex_dump` 整包）、**N2**（给命令加 APM 头）。
- **排除 N2**：vk42 保留了 N2 却完全干净。
- **判定**：崩溃源 = **N1/N4 调试插桩**，且需与**热区 DTS 组合**才致命（单独任一都干净）。机制上 N1 在 ADSP probe/开图路径上做同步阻塞等待，与显示电源切换形成竞态。
- **修复 = vk42 的"干净重落"**（删掉全部音频调试插桩）⇒ **当前内核已免疫**。

## 结论与遗留
- **G1-22 实质已解**：当前 boot_b 不再因熄屏复位；持久根的 `idle-delay=0` 规避可在长测后解除（本轮未动持久根）。
- 取证限制：复位是**硬复位**，无 panic、pstore 为空；ttyGS0 被 getty + 主机 ModemManager 的 AT 探测刷屏，串口没抓到崩溃前消息。
- 次要残留：DPU `vblank timeout` 在 vk40/boot_b 仍偶发，但不再致复位。

证据全部落 `archive/topics/G1-22-2026-10-05.md`，SSOT（TASKS §1/§4/Q21、INDEX §3/§6）已同步。

---

下一步你要哪个？
- **A**：再建一个变体把 N1 与 N4 谁为主钉死（多一次内核构建 + 一轮上机）；
- **B**：就此收尾——当前 G1-22 已足够定论；
- **C**：先处理别的事（比如把 vk50 的音频模块加载器补上，让 vk50 能起桌面）。


## Automatic settled outcome - 2026-10-04

收尾完成。

## 本次会话总览（`76c444c` → `3b00711`，全部已推 origin/main；doctor FAIL=0 WARN=0）

| # | 事项 | 结果 |
|---|---|---|
| 1 | **G1-5 相机出流** | ✅ **前后摄均连续出帧**（此前卡 `-32`）；根因=csiphy/vfe 默认格式与 sensor raw 不匹配+链路未使能；固化 `scripts/camera-stream-up.sh` |
| 2 | **kexec** | ❌ 定论**不可用**：`-s -l` 成功但 `-e` 硬挂整机（无 panic/无看门狗/pstore 空）→ 改用 fastboot 零写盘 |
| 3 | **vk50 模块/版本一致性** | ✅ 用 `LOCALVERSION=-vk50` 重建 **1513 模块**，内核↔模块 vermagic 一致（此前不一致导致相机/音频模块无法加载） |
| 4 | **G1-22 熄屏→重启** | ✅ **彻底查清**：受控复现（vk40+DPMS off **3/3 硬复位**，不熄屏稳定 ≥151s）；根因=**vk40 音频调试插桩**（`dev_info` 内同步阻塞调用 `q6apm_get_apm_state`）+**热区组合**；**N2 已排除**；`vk42` 干净重落即修复，**当前 boot_b 已免疫**（10 轮+90s 熄屏不复位） |

### 关键产物
- 脚本：`scripts/camera-stream-up.sh`、`scripts/g1-22-dpms-test.sh`
- 证据：`archive/topics/CAMERA-2026-10-05.md`、`archive/topics/G1-22-2026-10-05.md`
- SSOT 全文同步：TASKS（§0/§1/§4/Q9/Q21）、INDEX（§3/§6）、DEVICE、RUNBOOK、PITFALLS
- 内核树已恢复原状（`5a70ade46`，`.config` = `config-vk50-modular`）

### 当前设备状态
- U2 跑 **boot_b 持久直启**（`7.2.0-debug-g4c68eb5ed4e3-dirty`，`/`=`/dev/sda17`，Phosh 在跑），SSH 可达 → 直接可用。
- 工作区干净；临时构建物已清理。

### 留待以后（非阻塞）
- 解除持久根 `idle-delay=0` 规避并做一次长时空闲验证；
- 把 vk50 的音频/背光模块加载器补上（让模块化内核能起桌面）；
- G1-22 若要钉死 N1 vs N4，可再建一个变体（本轮已判定修复点，非必需）。

需要我以后处理其中任一项时，随时说。


## Automatic settled outcome - 2026-10-04

设备在线，我把现状和上机队列捋清楚了。先说结论。

## 一、现状快照（只读实测，U2）

| 项 | 实测值 |
|---|---|
| 内核 | `7.2.0-debug-g4c68eb5ed4e3-dirty`（= vk42 干净重落，G1-22 免疫版） |
| 根 | `/dev/sda17` ext4，Phosh 在跑，uptime 8 min，SSH 经 usb0 通 |
| 模块 | ⚠️ `/lib/modules/` **只有** `...gba28ec16f01f-dirty`（旧），**没有运行内核的目录**；`lsmod`=1；`modprobe qcom-camss` → **not found** |
| 相机/音频 | `/dev/media0`、`/dev/video0/3` **不存在**；`amixer controls` 空 |
| Waydroid | `Session: STOPPED`，`Vendor: MAINLINE` |
| 磁盘 | `/` 8.6G/189G |
| 其他 | wlan0 已连；dmesg 有 `pmic_glink ucsi PPM init failed`（已知 DP/altmode 缺，G1-9） |

**即时发现（阻塞复测）**：持久 boot_b 的内核 `g4c68eb5ed4e3` 在持久根里**没有匹配的 `/lib/modules`**（config 里 `CONFIG_VIDEO_QCOM_CAMSS=m`）。所以 **G1-5 相机、G1-4 音频在这套持久系统上现在都复现不出来**——它们是上一轮在 **vk50 RAM 启动 + 自带 overlay** 下验的。这不是新 bug，是「模块化内核 ↔ rootfs 模块」尚未对齐（HINDSIGHT 里记的"vk50 音频/背光模块加载器缺失"同一根问题）。

## 二、进度（TASKS §0）

- **G1 ~88%**：显示/图形/触屏/WiFi/充电/温控/串口/**相机出流✅**/音频播放+输入✅；剩 3 硬缺口 = **TF 卡、BT 配对**（进行中）+ **DP/NFC/CDSP**（未开始）。
- **G2 ~45%**：容器通路就绪，待 C1→C3→C2；C4 代码全就绪待部署。
- 上一轮 AI 的 vk40 结论已闭环：**G1-22 熄屏→硬复位**根因 = vk40 音频调试插桩（N1 同步阻塞 `q6apm_get_apm_state`）+ 热区组合；`vk42` 干净重落即免疫，当前 boot_b 已扩证 10 轮+90s 不复位。

## 三、需要上机的环节（按依赖排序）

| 优先 | 环节 | 前置/条件 | 备注 |
|---|---|---|---|
| **0** | **对齐持久根模块**（修复上面那条） | 主机侧用 `g4c68eb5ed4e3` 的 LOCALVERSION 重编模块并部署，或改刷一个内核↔模块成套的 boot_b | **是所有功能复测的地基**；也可顺手把 vk50 的音频/背光加载器补上 |
| 1 | **G1-22 收尾**：解除 `idle-delay` 规避 → 长时空闲 ≥2×idle 不复位 | 无（内核已免疫） | 低风险 |
| 2 | **G1-6 TF 卡 换卡 A/B** | **需你物理换卡** | 定性"卡 vs 驱动" |
| 3 | **G1-7 BT H1/H2 单变量** | 蓝牙耳机 + 编 `candidate-bt-maxspeed-3000k` / `no-flow-control` 内核 | RTT 常态 <10ms / 无丢包 |
| 4 | **C0 真 Android 对照取证（U1）** | U1 steam+root 接入 | **覆盖 a 槽前必做、不可复得** |
| 5 | **C1 Waydroid 复跑** → C3 身份取证 → C2 Play | C2 需你恢复上行+凭据 | |
| 6 | **C4 传感器 HAL 部署验证** | 需先 `waydroid init` | GAPS Q14 三未知 |
| 6' | **C8 Gunyah 探测


## Automatic settled outcome - 2026-10-04

按方案 A 完成。结论先行。

## 完成情况（U2，boot_b 持久系统，零写盘）

| 项 | 结果 |
|---|---|
| 根因 | 持久根 `/lib/modules/` 只有旧内核 `…gba28ec16f01f-dirty`，运行内核 `…g4c68eb5ed4e3-dirty` **无匹配模块** → 相机/音频"消失"是配置缺失，非功能回归 |
| 对齐 | 按运行内核 config 重建模块（MODVERSIONS/SIG 均关 ⇒ **只需 vermagic 匹配**），部署 **25 个 `.ko`** |
| **G1-5 相机** | ✅ 前摄 `/dev/video0`、后摄 `/dev/video3` 各 **10 帧 `<<<<<<<<<<`，rc=0** |
| **G1-4 音频** | ✅ `audio-alsa-init` 设 L/R=400；`speaker-test -D hw:0,0 -c2` **rc=0** |
| boot 持久化 | `/init` 接入 `camera-modules-load.sh`（旧 `/init` 备份为 `/init.bak-kmod-align`），模块+loader 均在盘上 |
| 资产/文档 | `out/camera-modules-…g4c68eb5ed4e3-dirty.tar.gz`（sha256 `4146dfd0…`）；提交 `cf14411`，doctor FAIL=0 |

## 过程中发现的两个真问题（已入 PITFALLS #99–#101）

1. **构建**：`setlocalversion` 在环境变量 `LOCALVERSION` **未设置**时会补尾 `+`（vermagic 变 `…-dirty+` ≠ 运行内核 `…-dirty`）——必须 `export LOCALVERSION=` 才精确匹配。
2. **运行**：持久桌面上 **PipeWire/WirePlumber 占用 `/dev/media0`** → `media-ctl` 报 `Resource busy`（纯 RAM 无桌面时不存在）。这是持久系统上相机应用会踩的真实冲突，**根治需让 WirePlumber 忽略 V4L2**。
   - 另一坑：模块**开机很久后热载**会撞 `deferred_probe` 超时（`power domains -110`）；**必须开机加载**——已由 `/init` 接线解决。

## 待确认 / 遗留

- **未重启验证开机自动加载**：按项目纪律（SSH-only 持久系统、用户操作设备），我没有自行重启。当前靠热载已验证功能；重启后 `/init` 应自动加载。**要我引导你重启验证吗？**
- **WirePlumber↔相机冲突**未根治（当前是停 wireplumber 才取流）——建议下一步做成 WirePlumber 配置，否则桌面相机应用会间歇 `Resource busy`。
- **G1-6 TF 卡**状态已按你的更正更新为"新卡已在位，可测"，下一步可直接跑 `scripts/tf-stress.sh`。

下一步你要：**A** 重启验证开机自动加载；**B** 根治 WirePlumber 相机冲突；**C** 跑 TF 卡新卡 A/B？


## Automatic settled outcome - 2026-10-04

已记录，未再深挖。结论如下。

## 归档内容（提交 `f6e77e2`）

**新增** `archive/topics/REBOOT-5MIN-2026-10-05.md` —— 原始观测 + 假设 + 受控实验建议：

| 项 | 记录 |
|---|---|
| 现象 | U2 boot_b 持久直启，内核 `g4c68eb5ed4e3`（vk46 + 未提交 vk47 DTS）；**进桌面后 ~5 min 整机硬重启，用户观察 2 次** |
| 复位性质 | **硬复位**：pstore 空、无 panic；无 `/dev/watchdog*`（`watchdog: Hard watchdog permanently disabled`）→ 排除看门狗 |
| 关键对照 | `git diff vk42..vk46` **仅 DTS（+111 行，WCD939x/SWR/DMIC）**，驱动代码与"免疫"的 vk42 完全一致 ⇒ **不是旧 G1-22 的 N1/N4 插桩**；但"免疫"从未在 vk46/vk47 DTS 上复检 |
| **未受控复现** | 同机桌面态 `idle-delay=300` 连续稳定 **≥60 min 未重启**；盯守到 uptime **304 s 时 `dpms` 仍为 `On`**，同一 boot 跑到 **475 s 仍未重启** ⇒ 无法用"等 5 min"稳定复现 |
| 候选假设（未验证） | H1 DPMS off→复位（新 DTS 电源域）；H2 相机自动加载与显示电源切换交互；H3 其他 ~5 min 定时（`PPM init failed` t≈324 s，已知良性） |

**同步落账**：`TASKS.md` §5 新增 **Q24**、G1-22 行加"复检"标记；`PITFALLS.md` §15.5 缺陷索引更新。

## 附带确认（正面）

- 本轮**相机 boot 自动加载已由多次自然重启验证**：重启后 `lsmod | grep -c camss`=8，`/dev/media0`、`/dev/video0`、`/dev/video3` 均在 → `/init` 接线有效（原先那条"待重启验证"已勾销）。

## 留待后续（写进 Q24 的受控实验清单）

1. `g1-22-dpms-test.sh` 多轮 DPMS off，**相机加载 vs 卸载** 单变量；
2. boot_b 临时切 `vk42`/`vk34recon` 同口径对照（`bootslot-b/` 有签名资产）；
3. dmesg 跨复位落盘（注意"取证装置本身是变量"的旧教训）。

需要时再从 Q24 接着做；当前设备同一 boot 已稳跑 ~8 min，未再重启。


## Automatic settled outcome - 2026-10-04

已确认并落档。结论先行。

## 根因确认（受控复现）

**触发 = 熄屏（DPMS off）→ 整机硬复位。电源键只是触发入口。**

| 实验 | 结果 |
|---|---|
| 受控 `wlr-randr --output DSI-1 --off` | SSH 立即断、`boot_id` 改变 ⇒ **硬复位** |
| 单击电源键（跨重启 `dmesg -w` 抓取） | `elogind: Power key pressed short.`（**无** poweroff）→ 4.2s 后 `qcom-battmgr-usb online -110` → USB 掉线 ⇒ 复位 |
| 卸载相机栈（`camss`=0）后再熄屏 | **仍复位** ⇒ **排除**本轮新加的相机自动加载 |

复位性质：**硬复位**（pstore 空、无 panic/suspend/poweroff、无看门狗）。elogind 是 `HandlePowerKey=ignore`，**不是它发起的**——是 phosh 熄屏（DPMS off）本身把机器带崩。

## 与旧结论的矛盾（关键）

- 当前 boot_b 解包核对 = **`out/boot-elden-vk47.img`**，UTS `7.2.0-debug-g4c68eb5ed4e3-dirty`。
- **这正是 G1-22 声称"同一 UTS、10 轮+90s 熄屏已免疫"的那个内核** ⇒ 与本次直接矛盾，**"免疫"结论必须重审**。
- 镜像身份实测：`vk42`=`…vk42-geb432f18a0d1` · `vk46`=`…ga923477be3a9-dirty` · `vk47`=`…g4c68eb5ed4e3-dirty` · `vk34recon`=`…ge72a036ed4be`。
- `git diff vk42..vk46` **仅 DTS（+111 行：WCD939x / SoundWire / VA-macro / regulator）**，驱动代码与 vk42 一致。

已记录：`archive/topics/REBOOT-5MIN-2026-10-05.md` §7、`TASKS.md` Q24、`PITFALLS` §15.5（提交 `d860655`）。

## 建议的下一步（单变量，零写盘）

用 **`fastboot boot` 依次引导 vk42 / vk34recon 镜像**（**同一持久 rootfs**），各跑一次 `g1-22-dpms-test.sh`：

- vk42 免疫、vk47 复位 ⇒ 回归源锁定在 **DTS 增量**，再逐块（WCD939x / SWR / VA-macro）二分；
- vk42 也复位 ⇒ 早先"免疫"判断本身有误，回到 vk34recon 基线重查。

命令（你操作设备侧 fastboot，其余我经 SSH 驱动）：
```sh
# 设备（SSH）：进 fastboot
eldroid-bootctl reboot bootloader
# 主机：零写盘引导（一条一条来）
fastboot devices
fastboot boot ~/y700-elden/out/boot-elden-vk42.img
```

## 临时规避

熄屏即复位 ⇒ **先别按电源键**；空闲自动熄屏若也生效，可把 `idle-delay` 设 0 规避（要我做吗？）。

要我现在带你跑 vk42 对照实验吗？


## Automatic settled outcome - 2026-10-04

已按更正后的口径编排完毕，两条 lane 已在后台开跑。汇报如下。

## 先纠正一个关键事实
`boot.img` 顶到上限**不是内核变大，是 ramdisk**：
- 内核 `Image.gz` 仅 **20.5 MB**；随 boot.img 打进的是**完整 Alpine rootfs 当 ramdisk ≈ 80 MB**；boot_b 分区 **96 MiB**。
- 所以除了你要的间接引导层，还有一条**立刻见效的缓解**（G1-30）：持久启动改最小 initramfs（busybox 挂 `linux17` → switch_root），boot.img 可从 ~101 MB 降到 ~22 MB。

## 任务编排（4 条 + 1 缓解）

| ID | 问题 | lane | 设备 | 状态 |
|---|---|---|---|---|
| **G1-26** | 深色模式无效 / 主题配色不可切 | `dt-ui` | U2 | 🟡 后台诊断中 |
| **G1-27** | 电源菜单四图标反色（黑到分不清） | `dt-ui`（同批） | U2 | 🟡 后台诊断中 |
| **G1-28** | 状态栏亮度滑块无效 | `dt-ui`（同批） | U2 | 🟡 后台诊断中 |
| **G1-29** | **间接引导层**（GRUB 类，尽量符合 UEFI） | `bootchain` | 只读 | 🟡 后台研究中 |
| **G1-30** | boot.img 瘦身（短期缓解） | 待排 | U2 | ⬜ 未开工 |

## 两条 lane 已在跑
- **`dt-ui`**（占 U2）：先诊断再最小修复。已把三条硬线索交给它——① 设备 `/usr/share/themes/` 只有 `Default`+`Emacs`（**没有 Adwaita-dark 目录**）；② dconf 可能落错 HOME（`/root` vs `/`）；③ 背光设备本身可写，但 `upower` 的 `DisplayDevice` **没有 `Brightness` 属性** ⇒ Phosh↔elogind 集成断链。四个问题一次只变一个变量，不自行重启持久系统。
- **`bootchain`**（host-only，不占设备）：已读本地三代权威记录——GUF296 的链是 `ABL → boot.img 内完整 Qualcomm UEFI DXE → bootloader LUN 上的 FAT → GRUB`，而**四代没有 `vm-bootsys` 分区**（我用实机 `lsblk` 已确认），三代链不能照搬。它会给出机制判定 + 路线排序（含 `uefi_a/b`、`imagefv_a/b`、`logfs/qmcs/spunvm` 等 FAT 载体的可行性）+ 需设备验证清单。

## 并发骨架
- baseline `base/20261005-d860655`；worktree：`~/wt-dt-ui`、`~/wt-bootchain`；角色定义 `.pi/agents/{dt-ui,bootchain}.md`。
- `TASKS.md` 新增 G1-26…G1-30；`CONCURRENCY.md` §5 已登记；父提交 `9bbfc1a`。`check-doctor` **FAIL=0**（WARN=会话计数，既有）。

## 两点提请注意
1. 我侦察期间**另一个会话在 main 上提交了 `d860655`（Q24：熄屏→硬复位受控复现）**——说明有并发写者，merge 时我会以 lane 语义为准收口。
2. 两条 lane 完成后我会独立复跑验证再 merge，不会只信它们的自报。有结果我通知你；你也可以随时插别的活。


## Automatic settled outcome - 2026-10-04

## 状态：编排被外部预算墙打断

**`dt-ui` 已死，零工作量** —— 不是推理失败，而是 key 超预算：
```
429 ExceededBudget: Key over 12h budget. Spend=$70.02, Limit=$70.00
```
- 这个 $70/12h 限额挂在 **`ustc-ai-3`**（当前会话与子代理同 key），旧的「3h/$30」记忆不准，我已更正到长期记忆。
- **`bootchain` 仍在跑**，随时可能撞同一面墙；若它中断，完整 transcript 已存 `/tmp/pi-subagents-.../tasks/928d57ff-....output`，预算恢复后可按 lane 续。

## 好在设备空闲，我内联抓到了真线索（只读，未改任何东西）

| 问题 | 证据 | 推断 |
|---|---|---|
| **G1-26 深色无效** | phosh(765) 环境 `HOME=/root`；`/root/.config/dconf` 里 **确已** `color-scheme=prefer-dark`、`gtk-theme=Adwaita-dark` | **不是 dconf 落错**；是 GTK 根本没应用该主题（待 GUI 确认） |
| **G1-27 电源菜单图标反色** | Adwaita 的 `system-shutdown/log-out-symbolic.svg` **都在** | 与 G1-26 **同源**：主题/symbolic 前景色没生效 → 图标取默认黑色，深底不可辨 |
| **G1-28 亮度滑块** | `loginctl list-sessions` = **No sessions**；`/etc/pam.d` 无 `pam_elogind`，无登录管理器（greetd/lightdm）；`gsd-power` 确实在跑(1206) | **缺 logind 会话** → gsd-power 的 backlight(logind `SetBrightness`) 路径断链，滑块死；`upower DisplayDevice` 无 `Brightness` 是同一病征 |
| 主题资源 | `/usr/share/themes/` 只有 `Default`+`Emacs`；但 GTK3 的 Adwaita 是**内建 GResource**，故缺目录≠必然无效 | 仍需在会话内确认主题是否真被应用 |

（我先前用 **system bus** 测 gsd-power 是错的——它在 **session bus**；后续要在 phosh 会话环境里测 `org.gnome.SettingsDaemon.Power.Screen.Brightness`。）

## 需要你拍板（一条外部决定）

预算墙只能换 key 或等窗口，我无法自行绕：

1. **换 key**：把本会话/子代理切到 `ustc-ai-1 / 2 / 4` 里的一个有余额的 key（或 `deepseek`，但 `auth.json` 里我只看到 `ustc-ai-1..4`，没见到 deepseek 凭据）。→ 我立刻重启 `dt-ui`（设备已空闲、锁 free）。
2. **等窗口**：`ustc-ai-3` 12h 窗口滚出后自动恢复，期间我只做**主机侧**、不派子代理的活。
3. **继续内联**：我在主会话自己把桌面 UI 查完（风险：主会话同 key，随时 429；且 GUI 类问题在纯 SSH 下判断力有限）。

你选哪个？另外 `bootchain` 一旦回报我会独立复核再 merge。


## Automatic settled outcome - 2026-10-04

已切换并重启。

- **Key**：`PI_PROVIDER=ustc-ai-2`，本会话已生效。
- **`dt-ui` 已重新派发**（新 agent `a6fe93c2`，lane 仍干净在 baseline）；我把本轮内联证据（dconf 已正确、缺 logind 会话、symbolic 图标在位、gsd-power 在 session bus）都喂给了它，避免重复侦察。
- **`bootchain`** 仍在跑（62 次工具调用，未死）。

两条 lane 完成时我会独立复核再 merge，届时汇报。期间你可以插别的活。


## Automatic settled outcome - 2026-10-04

vk42 对照**免疫**，回归源已锁定在 **DTB/DTS 增量**。现在做最后一步隔离。

## 结果

| 镜像 | 内核 | 熄屏(DPMS off) |
|---|---|---|
| `vk42` | `7.2.0-debug-vk42-geb432f18a0d1` | ✅ **免疫**（2 轮 off/on 同一 boot 存活） |
| `vk47`（boot_b） | `…g4c68eb5ed4e3-dirty` | ❌ 熄屏即硬复位 |

`git diff vk42..vk47` 只改了 **DTS**（C 代码/驱动相同）⇒ 嫌疑锁定 **DTB**。

## 已备好隔离镜像（等你引导）

`out/boot-elden-vk47-dtb42.img` = **vk47 内核 + vk47 ramdisk + vk42 DTB**（DTB 段逐字节 == vk42，已校验）。
保持内核/config/ramdisk 不变，**只换 DTB**：
- 免疫 ⇒ 触发在 DTS（WCD939x / SoundWire / VA-macro 实例化），随后逐块二分；
- 仍复位 ⇒ 不在 DTB，转查 config/其他。

命令（你操作设备侧 fastboot，其余我经 SSH 驱动）：
```sh
# 设备（SSH）
eldroid-bootctl reboot bootloader
# 主机
fastboot devices
fastboot boot ~/y700-elden/out/boot-elden-vk47-dtb42.img
```

引导起来（进桌面）后跟我说一声，我跑 `g1-22-dpms-test.sh`。


## Automatic settled outcome - 2026-10-04

根因找到并修好了——**不是你的 key，是我埋的坑**。

## 两次 `dt-ui` 猝死的真因
- 我在角色文件里写了 `model: deepseek/deepseek-flash`，插件的 `resolveModel` 把它 **fuzzy 解析成 `ustc-ai-1/deepseek-flash`**，
- 而超预算的正是 **`ustc-ai-1`**（`Spend=$70.0224 / Limit=$70.00`）——证据来自 transcript 里子代理实际用的 `"provider":"ustc-ai-1"`。
- 你切到的 **`ustc-ai-2` 一直是好的**（本会话主循环就用它）。

## 修复
- 已从 `.pi/agents/{dt-ui,bootchain}.md` 去掉钉死的 `model:`（父提交 `8e4061d`），子代理改为继承父会话模型；
- **`dt-ui` 已重新派发**（agent `c9078261`），并**显式指定 `model: ustc-ai-2/deepseek-flash`**，确保落在新 key。
- `bootchain` 用的是 `ustc-ai-3`（另一把 key，未超额），60 次工具调用仍在跑，不受影响。

两条 lane 完成时我会独立复核再 merge。你继续忙别的即可。


## Automatic settled outcome - 2026-10-04

完成。已提交（`1eb269c`，分支 `lane/bootchain`，trailer 齐全，VK=vk51），lane 已 `done`。原始证据在 `archive/topics/BOOTCHAIN-2026-10-05.md`。

---

## ① 机制判定（四代 TB322FC）

**四代 UEFI 是"有的"，但被拆成独立分区、由 XBL 加载——不是三代那种"塞进 boot.img 内核槽"。**

| 分区 | 内容（本轮实机固件包 `~/下载/tb322fc/` 亲手解析） | 读它的是谁 |
|---|---|---|
| `uefi_a`(5M) | `uefi.elf` = ELF64 aarch64，内含 **EDK2 核**（`DxeCore.efi`/`uefiplat.cfg`） | **XBL** |
| `imagefv_a`(2M) | DXE 驱动卷（LZMA→~32 MB，4×PE） | XBL |
| `abl_a`(1M) | **LinuxLoader 应用**（解出 663 KB 可读：AVB+slot+直接内核启动） | XBL |
| `toolsfv`(1M) | 工具 FV | XBL |

- **四代 stock `boot.img` = 真 Linux arm64 Image**（magic `0x644d5241@56`，含 "Linux version"），**无 UEFI 载荷**。即 ABL 走的是"直接内核启动"，**ABL 自身不扫任何 FAT**（解出的 ABL 无 BDS/`SimpleFileSystem`，未发现 0x10000381 字面量）。
- **三代 GUF296 `boot.img`**（亲手拉取解析）：v3，内核段 = gzip(**arm64 壳 `code0=0x10000381` + 完整 EDK2 FV，41×PE**)；其自带平台 BDS（`DefaultBDSBootApp="LinuxLoader"`, `EnableShell=1`）才去扫 FAT 起 GRUB。**真正扫 FAT 的是"载荷里的" BDS。**
- **`logfs`/`qmcs`/`spunvm` 都是固件数据分区（GPT type=raw），不是被扫描的启动 FAT**；uefivarstore 里也没有 `Boot####`。→ **四代没有任何现成分区今天会被当启动 FAT；要 GRUB 起来必须先自供一套 UEFI(BDS+FS 驱动)。**

## ② 路线排序表

| 路线 | 所需产物 | 烧写/回退 | 验证判据 | 风险 |
|---|---|---|---|---|
| **C〔现在就能做〕** 最小 initramfs→`switch_root` 到 `linux17` | busybox(~1M) initramfs + Image.gz(20.5M) 打 boot.img | `fastboot flash boot_b`；回退 `out/boot_b-vk49.img` | `findmnt /`=linux17、相机模块自动加载不回归、**boot.img 由 96M→~22M** | **低** |
| **A〔GRUB/UEFI 间接层，Gen3 同构〕** 自建 SM8750 可自举 UEFI 载荷塞 boot.img | ①SM8750 可自举 UEFI 卷（**缺环**：Mu-Silicium 移植 / 或重组四代`uefi.elf`+`imagefv.elf`）②小 FAT(放 GRUB) ③`linux17`(放 kernel+initramfs) | `fastboot flash boot_b`；GPT 若动→`backup/gpt*` 回退 | 出现 GRUB/BDS 菜单、`root=LABEL=linux17`、boot.img 内不再有 ramdisk | **中高**（壳机制三代已证；四代 ABL 接受自编 boot.img，"倾向可行"但**未验证**） |
| **B〔最符合 UEFI 标准〕** 替换 `uefi_a` 为 U-Boot/Mu-Silicium | SM8750 U-B


## Automatic settled outcome - 2026-10-04

## 子代理路线：确认不可用（工具层，非你的 key）
三次 `dt-ui` 全部 transcript `provider=ustc-ai-1`、`Spend=$70.0224` 一字不差；**删 frontmatter + 显式传 `model=ustc-ai-2/...` 都无效**。我停止重试。要么你修插件/provider 映射，要么我**继续主会话内联**（现在就是这么做）。

## 桌面四项：内联已拿到一手定位

**G1-28 亮度 —— 根因已抓到并复现**
- Phosh 日志：`phosh-backlight-WARNING: Setting backlight on DSI-1 failed: GDBus.Error:System.Error.EISDIR: Is a directory`
- 我用 `dbus-send` 直调 **elogind 的 `Session.SetBrightness`**，对**任意** name（含空串）都返回 `System.Error.EISDIR` ⇒ **不是设备名/滑块绑定问题，是 elogind 端**。
- elogind **255.24**；其 `logind-brightness.c` 用「brightness writer 子进程 + `/sys/class/tty/tty0/active`」，并带串 `Only owner of session may change brightness.`；本机 **`loginctl list-sessions` 为空、无 VT/active tty0** ⇒ 该机制走不通。
- Phosh 其实**自带 sysfs 后端**（`PhoshBacklightSysfs`/`backlight-sysfs.c`），但优先走 logind；且 `/sys/class/drm/card0-DSI-1/backlight` 符号链接**不存在**。
- 可修方向（择一）：**A** 起真 session+VT（greetd/`pam_elogind`，或让 phoc 占 tty1）；**B** 换/降级 elogind（走简单 sysfs 写）；**C** 让 Phosh 走 sysfs 后端（补 DRM connector backlight 链接或 patch phosh）；**D** 小 root 守护桥接。**我推荐先试 A**（也顺带补齐 logind 生态）。

**G1-26/27 深色 / 主题色 / 电源菜单图标 —— 部分定位**
- dconf 正确（`/root/.config/dconf/user`：`prefer-dark`/`Adwaita-dark`/`accent=pink`，phosh `HOME=/root`）。
- 日志见到 GTK4 应用加载 dark css（`Adwaita: style-dark.css is deprecated…`）⇒ **GTK4/libadwaita 侧深色是生效的**；问题集中在 **phosh 本体（GTK3）**。
- `accent-color` 是 GNOME 47+/libadwaita 机制，**GTK3 的 phosh 不消费** ⇒ "主题色无法切换"很可能是 phosh 0.55 的能力边界（需 patch 或换壳）。
- 电源菜单图标"反色"：symbolic 图标资源都在，疑似 **GTK3/GTK4 深色状态不一致** → 前景取错。**这一条需要你在屏幕上确认一次**（我 SSH 看不到画面）。
- 待做：查 phosh 0.55 是否消费 `color-scheme`（源码/libhandy）；可能需 patch phosh。

## 仍等你拍板的三件事
1. **子代理**：修 provider 映射，还是我就内联干？
2. **亮度**：走 A / B / C / D 哪条（我建议 A，但 A 要动 session/启动链，需你同意）？
3. **E5（slim 上机）**：目标内核选 `vk50` 还是 `vk46`？要不要先用 `fastboot boot` 零写盘试？

你给个方向，我就继续（或先只做你点名的某一条


## Automatic settled outcome - 2026-10-04

镜像本身正确（内核 UTS `7.2.0-debug-g4c68eb5ed4e3-dirty`），但设备目前**仍跑 vk42**（boot_id 未变），测试镜像还没引导。

请在设备/主机上执行：

```sh
# ① 设备（SSH，当前 vk42 系统）
eldroid-bootctl reboot bootloader

# ② 主机（等设备进 fastboot 后，一条一条）
fastboot devices
fastboot boot ~/y700-elden/out/boot-elden-vk47-dtb42.img
```

引导完（SSH 应换成 `uname -r` = `7.2.0-debug-g4c68eb5ed4e3-dirty`）告诉我，我立刻跑 `g1-22-dpms-test.sh` 判定。


## Automatic settled outcome - 2026-10-04

干净重建镜像已就绪：`out/boot-elden-clean.img`（**已提交源码 + vk47 config** 重新编译的内核，vk47 ramdisk/DTB）。请引导它做判定。

```sh
# 设备（SSH）
eldroid-bootctl reboot bootloader
# 主机
fastboot devices
fastboot boot ~/y700-elden/out/boot-elden-clean.img
```

**判定逻辑**：
- 若**免疫** ⇒ 当前 boot_b 那份 `-dirty` 构建是坏的（含未提交改动），修复 = 用干净内核重刷 boot_b；
- 若**仍复位** ⇒ 已提交源码本身有该 bug，vk42 的"免疫"需重查（我们继续二分）。

（旁证已完成：vk42/vk47 的 **config 完全相同**、内核字符串几乎相同、ramdisk 内容相同、只换 DTB 无效——所以这次干净重建是决定性一步。）


## Automatic settled outcome - 2026-10-04

修复资产已就绪。

## 根因（已定位，已落档 `4495828`）

**boot_b 烧的是 `kernel_git_state=dirty` 的 vk47 镜像**——带**未提交的改动**（git 历史里看不到，很可能是残留的音频调试插桩）。所以：
- config 完全相同、DTB 无关、ramdisk 相同——差的是那份"脏"二进制；
- **用已提交源码干净重建 ⇒ 实测免疫**（2 轮熄屏同一 boot 存活）。

## 修复（等你执行写盘）

**镜像（已签名，key `fc1e3b33` 匹配 vbmeta_b 链）**：`bootslot-b/boot_b-clean.img`

```sh
# 设备（SSH）
eldroid-bootctl reboot bootloader
# 主机：一条一条
fastboot devices
fastboot flash boot_b ~/y700-elden/bootslot-b/boot_b-clean.img
fastboot reboot
```

**随后我会**：部署与该干净内核（UTS `7.2.0-debug-vk47clean-gbd114ca335e1`）匹配的相机模块到持久根（模块正在后台重建中），恢复相机。

## 验证判据（刷完我来跑）
- `uname -r` = `7.2.0-debug-vk47clean-gbd114ca335e1`；
- `g1-22-dpms-test.sh` 多轮熄屏**不复位**；
- 单击电源键熄屏**不再关机**。

## 两点提醒
1. **并发**：另一会话正持设备锁（`/tmp/elden-device-root_192_168_7_1_.lock`，GTK 诊断）——刷机前最好确认它不在跑，或由你协调。
2. 我误把并发会话的 `edk2-aarch64-gunyah` 收进了提交，已 `git rm --cached` 修正并把 `/edk2-aarch64-gunyah/` 加进 `.gitignore`；`out/boot-elden-vk52-slim.manifest` 是 bootslim lane 的产物，我保留未动。

要我现在就绪后直接驱动（模块部署 + DPMS 复测），还是你先刷？


## Automatic settled outcome - 2026-10-04

明白，从现在起我只描述、不碰设备。

## 已完成（主机侧 + 已部署）
- 干净内核**实测免疫**；已签名持久镜像：`bootslot-b/boot_b-clean.img`（UTS `7.2.0-debug-vk47clean-gbd114ca335e1`）。
- 匹配的相机模块已部署到持久根：`/lib/modules/7.2.0-debug-vk47clean-gbd114ca335e1/`（25 个 `.ko`），`camera-modules-load.sh` 已确认加载（1 media / 17 video 节点，`/dev/media0`、`video0`、`video3` 在）。

## 需要你执行（一条一条来）

**① 刷 boot_b（持久固化）**
```sh
# 设备（SSH，当前跑的就是干净内核）
eldroid-bootctl reboot bootloader
```
等设备进 fastboot 后，在**主机**：
```sh
fastboot devices
fastboot flash boot_b ~/y700-elden/bootslot-b/boot_b-clean.img
fastboot reboot
```

**② 回退手段（万一）**：若刷完起不来，`fastboot boot ~/y700-elden/out/boot-elden-vk42.img`（已证免疫）可零写盘进系统。

## 刷完告诉我这三点，我来判定
1. `uname -r`（应为 `7.2.0-debug-vk47clean-gbd114ca335e1`）；
2. 单击电源键熄屏后**是否还关机**；
3. `ls /dev/media0 /dev/video0 /dev/video3`（相机节点是否在）。

需要我把这几条验证命令也写成"你复制即可运行"的单条形式，就说一声。


## Automatic settled outcome - 2026-10-04

已整理完毕。先给数字结论。

## 一、本次整理动了什么

| 项 | 结果 |
|---|---|
| 未收录会话 | **15 个 jsonl / 12 个独立 ID**（索引 68→**77**，与实有文件一致）；删 6 条已清理 junk 行 |
| 新建证据档 | `archive/topics/DT-UI-2026-10-05.md`（**dt-ui lane 的全部成果原本只在会话里，未提交、未入档**） |
| 文档更新 | `TASKS`（G1-26/27/28 定根因 + §4 下一步重排）、`PITFALLS` #103、`RESOURCES` §1.5/§3/§4、`INDEX` §3 |
| 自检 | `check-doctor` **FAIL=0 WARN=0**；提交 `8b1293f` |
| 新参考登记 | 3 个 `edk*` 文件夹已入 `RESOURCES` §1.5/§3 |

## 二、卡点（按优先级）

1. **🔴 G1-22/Q24 熄屏→硬复位（U2 日常不可用）**——根因已锁定：boot_b 烧的是 **`-dirty` 的 vk47 镜像**（带未提交改动），**干净重建实测免疫**。`bootslot-b/boot_b-clean.img` 已签名、匹配的 25 个相机模块**已部署到持久根**。**只差用户执行 `fastboot flash boot_b`**（回退 `boot_b.img`）。这是当前第一卡点。
2. **🔴 桌面用户态四问（G1-26/27/28）**——**dt-ui lane 已查出根因但会话中断、无提交**：
   - 深色无效 + 电源菜单图标反色 + accent 无效**同一根因**：`gtk-theme='Adwaita-dark'` 在 GTK3 **解析失败→回退浅色**（无头探针证实：`Adwaita-dark`→fg 近黑/浅底；`Adwaita`→fg 白/深底）。**修复=`gtk-theme='Adwaita'`**（accent 也因 phosh 的 name guard 一并放行）。
   - 亮度滑块：背光可写，但 **elogind 无 session/VT** ⇒ `SetBrightness` 返回 `EISDIR`；A/B/C/D 四方案待你拍板。
   - ⚠️ 操作坑：`gsettings` 必须 `dbus-run-session`，否则**静默不落盘**（之前"改了没变化"的结论因此作废）→ PITFALLS #103。
3. **🟡 G1-6 TF 卡 A/B**：新卡已在位、脚本就绪，**始终没跑**（会话被打断）。可直接 `scripts/tf-stress.sh`。
4. **🟡 G1-7 BT**：剩 H1(8Mbps)/H2(CTS) 单变量补丁未测。
5. **🟡 G2 主线**：**C0 真机对照取证未做**（U1 覆盖前唯一不可复得项）；C1/C3/C2 未推进；C4 待上机部署验证。
6. **🟢 G1-29/30**：机制判定与 slim 镜像（101 MB→20.8 MiB）主机侧已交付，**上机实验 E1/E3→E4→E5 待排期**（E5 需用目标内核重打）。

## 三、会话成果汇总（重点：未入档的）

| 会话 | 成果 | 是否入档 |
|---|---|---|
| `01a10736-a2dd` **dt-ui** | GTK3 根因 + 修复 + elogind 亮度根因 | ❌→**已补档** |
| `01a1072e` 编排+内联 | dconf 未落错、无 logind 会话、gsd-power 在 session bus | ❌→已补档 |
| `01a106b9` | 25 模块对齐、boot_b=`-dirty`、干净内核免疫 | ✅ Q24/KMOD-ALIGN |
| `01a10635` | 相机出流、kexec 定论、G1-22 根因 | ✅ |
| `01a10736-a2c7` bootchain | 四代 UEFI 分区机制 + 路线 A–D + grindfat 脚本 | ✅ BOOTCHAIN |
| `01a1068c

## 2026-10-04 子代理插件迁移（影响本项目派工）

子代理插件由 `@tintinweb/pi-subagents` 换成 `pi-subagents`（nicobailon），**工具名从 `Agent`/`SubagentWorkflow` 变为 `subagent`**（另有 `bg_wait`、`/subagents-*` 命令）。
本项目 `.pi/agents/*.md` 已迁移：新增必填 `name:`/`description:`（**缺则新插件静默跳过该 agent**）、`advertise: true`；删掉死引用 `model: deepseek/deepseek-flash`（该 provider 无凭据）→ 子代理继承会话默认模型。`role`/`objective` 保留为人读注释（插件不解析）。详见 `.pi/README.md` 与全局 `~/.pi/agent/memory/HINDSIGHT.md`。


## Automatic settled outcome - 2026-10-04

收尾完成。数字结论先行。

## 本次结论

| 项 | 结果 |
|---|---|
| 现象 | 熄屏（DPMS off，含单击电源键）→ **整机硬复位**；**间歇性** |
| 判定 | 受控复现成立；但 vk42 与"干净重建"各 2 轮"免疫"的少样本观测**不可信**——**刷入干净内核到 boot_b 后仍复位** ⇒ 「`-dirty` 镜像为根因」**假设未证实** |
| 处理 | 按你的指示**停止深究** |

## 设备现状（收尾态）
- boot_b = **干净内核** `7.2.0-debug-vk47clean-gbd114ca335e1`（已刷、已签，key `fc1e3b33` 匹配 vbmeta_b 链）；
- 匹配 **25 个相机模块**已部署到持久根，相机 boot 自动加载 OK（`/dev/media0`、`video0/3` 在）；
- **熄屏→复位仍未解**（仅此一项遗留）。

## 资产与文档（已落档）
- 镜像：`bootslot-b/boot_b-clean.img`（96 MiB 签名）、`out/boot-elden-vk47clean.img`；模块包 `out/camera-modules-vk47clean.tar.gz`。
- 提交 `5d59788`：`archive/topics/REBOOT-5MIN-2026-10-05.md` §7.9（收尾证据）、`TASKS.md` Q24/G1-22（转「未解/间歇性」）、`PITFALLS.md` #102（保留"`-dirty` 镜像不可复现"的卫生纪律，**去掉因果断言**，并记"少样本不可判定免疫"）。
- `scripts/check-doctor.sh`：**FAIL=0 WARN=0**。

## 并发处置（未越界）
- 只提交了自己的 3 个文件（避免再误收）；
- 误收的 `edk2-aarch64-gunyah` 已从提交移除 + 加入 `.gitignore`；
- 清掉我自建的游离 worktree `wt-clean`（回收 13 G）；**未碰** bootslim/bootchain/dt-ui 三个并发 lane 与它们的产出的文件。

## 若日后重启调查（已写入 Q24）
须按 **长时窗 + 多样本 + 单变量** 重做（参 G1-23/Q22 的方法论教训），例如：`g1-22-dpms-test.sh` 连续 ≥10 轮、跨多次 boot，并固定"是否加载音频/相机"等变量，再谈面板/DPU/ADSP 的因果。

需要我把「熄屏复位」这条在 `INDEX.md` §3 快照里也加一句状态吗？（现已在 TASKS §5 Q24 / §1 G1-22 与 PITFALLS §15.5 有索引）


## Automatic settled outcome - 2026-10-04

已按反转后的结论修正完毕。

## 修正情况

并发会话 `5d59788` 已改 TASKS Q24/G1-22 与 PITFALLS #102，但它**没覆盖**我上一轮和更早写入的几处，仍留着"已修复/免疫"的口径。本轮全部清除并统一：

| 文件 | 原（错误） | 现（已改） |
|---|---|---|
| `DEVICE.md` §2 U2 行 + ★注 | "熄屏→重启**已解**，vk42 起内核免疫" | **未解/间歇性**；`-dirty` 根因**未证实**；停止深究 |
| `INDEX.md` §3/§6 | "已定位；修复待刷；干净重建实测免疫" | 同上；boot_b 现状=干净内核 `vk47clean` |
| `RUNBOOK-BRINGUP.md` §7 | "已定位并修复；旧规避非必需" | 根因未证实；**规避必须保留** |
| `TASKS.md` Q21 | "已解决（2026-10-05）… ✅" | **仍未解（2026-10-05 反转）** |
| `RESOURCES.md` §4 会话行 + §3 时间线 | "干净重建实测免疫 / 根因=vk40 插桩" | 标为"后续反转：未证实" |

提交 `26d31c0`；`check-doctor` **FAIL=0 WARN=0**。

## 反转后的卡点重排

1. **🔴 G1-22/Q24 熄屏→硬复位** —— 受控复现成立，但 **vk42 / 干净重建各 2 轮"免疫"是少样本、不可信**；**刷入干净内核到 boot_b + 相机模块后仍复位** ⇒ 「`-dirty` 镜像为根因」**假设未证实**。**已停止深究（你定）**。现状：boot_b=干净内核 `vk47clean`（相机正常），`idle-delay=0` 规避保留。若重启调查须**长时窗+多样本+单变量**。
   - 注意：这条现在是"**已复现但未解、且不打算再投入**"，不再是"只差刷机"。所以原第一卡点从"待你刷机"变成"**维持现状**"。
2. **🔴 桌面四问（G1-26/27/28）** —— 根因已定（dt-ui 会话，已补档），**可上机落 `gtk-theme='Adwaita'`**；亮度方案待拍板。
3. **🟡 G1-6 TF 卡 A/B**、**G1-7 BT H1/H2** —— 条件就绪、未跑。
4. **🟡 G2**：C0 真机取证未做（不可复得）、C1/C3/C2/C4 未推进。

需要我把 `gtk-theme` 修复写成上机单条命令，或继续推进某一项吗？


## Automatic settled outcome - 2026-10-04

读完了三个仓库（含各自的 git 历史、README、补丁、构建配置），并对照了上一轮的 `EL2-VIRT-2026-10-02.md` / `ARM-VIRT-RESEARCH-2026-10-02.md` / `BOOTCHAIN-2026-10-05.md` 与 `RESOURCES.md §1.5` 的登记。结论先行。

## 一、一句话结论

**这三个全是"guest 侧（ArmVirt 虚拟平台）UEFI 固件"，没有一个含 SM8750 裸机平台代码。**

| 用途 | 价值 |
|---|---|
| G1（裸机主线 Linux + 原厂固件） | **≈0**：它们期望的是 QEMU/Gunyah 的虚拟硬件，不是真机 |
| G1-29 路线 A（自建可自举 UEFI 塞 `boot.img`） | **只提供"打壳/瘦身"技巧**，缺环（SM8750 平台初始化）依旧缺 |
| C8 / G2 的 Gunyah VM 路线 | **现成的 guest 固件**，但受"需 gunyah 主 VM 驱动 / 需 Android 宿主"卡点不变 |
| Windows-on-ARM 方向 | 有一个专用 fork（`edk2-aarch64-gunyah`），仅当该方向复活才有用 |

上一轮 `RESOURCES.md §1.5` 把三者定性为"仅观察、可重下、可清理"——**该定性成立**，下面是把"里面到底有什么能用"讲清楚。

## 二、三个仓库画像

| 仓库 | 上游 | 体量/提交 | 本质 | 独有内容 |
|---|---|---|---|---|
| `edk2-gunyah` | `Droid-VM/edk2-gunyah` | 1.8 M / 50 提交 | **crosvm+Gunyah 的 guest UEFI**（`GunyahPkg/GunyahKernel.dsc`→`edk2-gunyah.fd`），README **明列测试平台含 Lenovo Y700 Gen4 = TB322FC/SM8750** | `patches/edk2/` 5 个 ACPI 补丁；`SimpleFbDxe`/`GunyahVirtioGpuDxe`（双队列）/`VirtioFs` 等 crosvm 适配；CI 直接把 `.fd` 推到 `DroidVM-Prebuilt-Root` |
| `edk2-gunyah-qemu` | `qemu-gunyah/edk2-gunyah-qemu` | 469 M / 35523 提交 | 完整 tianocore EDK2 + **一个 Gunyah QEMU 支持大补丁**（`50c9eb78fa`，38 文件/3920 行） | 给 `qemu-for-gunyah`（KVM-in-EL1 + Gunyah backend，C8 另一条腿）用的 guest 固件：`GunyahIoMmuDxe`、`GunyahRestrictedDmaPoolAcpiDxe`、SMBIOS、`PatchedSerialPortLib16550`、`PrePi/FdtParser`、`QemuRamfb` |
| `edk2-aarch64-gunyah` | `AnyLaySys/edk2-aarch64-gunyah` | 1.5 G / 12 提交 | 整片 aarch64 EDK2，构建 `ArmVirtPkg/ArmVirtGunyah.dsc`；面向 **Windows-on-ARM64 guest**（提交"启动 Microsoft Windows 改 ramfb"） | **FD 瘦身 3 MB→860 KB**、ramfb、中文提交、`GunyahIoMmuDxe`+`GunyahRestrictedDmaPoolAcpiDxe`（与 qemu 那份**逐字节相同**） |

**共享谱系**：`GunyahIoMmuDxe.c`(608 行) 与 `GunyahRestrictedDmaPoolAcpiDxe.c` 在 `edk2-gunyah-qemu` 和 `edk2-aarch64-gunyah` 里完全相同；`edk2-gunyah` 


## Automatic settled outcome - 2026-10-05

调查完成。本地已有 2026-10-05 的机制判定；本轮做的是**外部取证 + 推翻其中一处"缺环"**。结论先行。

## 一、一句话结论

**UEFI 启动（间接引导层）从"机制可行但缺一个 SM8750 可自举 UEFI"升级为"基座已存在、只差 TB322FC 设备包"。** 可行性评级：Route A 由**中高 → 高**（SoC 级已解）；Route B（替换 `uefi_a`）不变=**高险**；Route C（min-initramfs）不受影响。

## 二、新证据（相对 `BOOTCHAIN-2026-10-05.md` 的推翻/补充）

原判定"**缺环 = 一个 SM8750 可自举 UEFI 卷，需 Mu-Silicium TB322FC 移植**"——**前半句已被证伪**：

| # | 事实 | 出处 |
|---|---|---|
| N1 | Mu-Silicium **已有 SM8750 SoC 级支持**：`Silicon/Qualcomm/PakalaPkg`（Pakala = SM8750 家族） | Mu-Silicium tree |
| N2 | **已有可用的 SM8750 设备端口**：`Platforms/OnePlus/dodgePkg`（OnePlus 13 = dodge），Status 表 **Linux Boot ✅ / Internal Storage ✅ / 显示 ✅ / 触屏 ✅ / Mass Storage ✅** | `Status.md` |
| N3 | **更关键——Mu 的输出本来就是 `boot.img`**：`build_uefi.py:create_android_boot_img()` 把 `SILICIUM_UEFI.fd`（可前置 `BootShim.bin`）gzip 后塞进 **Android boot image 的 kernel 槽**（`{device}-kernel`），另有 `requires_kernel_header`（BootShim 会补 `ARM\x64` 头） | `build_uefi.py` L237–316；`BootShim.S` |
| N4 | 即：**Mu 原生走的就是三代 GUF296/我们 Route A 的"arm64 壳 + ABL chainload"机制**，不是替换 `uefi_a` | N3 |
| N5 | 第二个 SM8750 UEFI 工程活跃：Xiaomi 15（dada）workspace，基于 `Project-Aloha/mu_aloha_platforms` + `BootShim v2-d1` + `repack_d1.py`，**明确"只 `fastboot boot`、不刷机"**；dada 的 dsc 同样 `!include PakalaPkg` | `wumai2580/xiaomi-dada-manifest`（2026-09-28） |
| N6 | 移植面**小且有模板**：设备包 = `.dec/.dsc/.fdf` + `Include/{APRIORI,DXE,RAW}.inc` + `Library/{MemoryMapLib,ConfigurationMapLib}` + `FdtBlob/<dtb>` + `DeviceBuild.py`；Mu 里有 **两个 Lenovo 设备包**（`9707fPkg`=Y700 2023、`j706fPkg`）可照抄厂商约定 | Mu-Silicium `Platforms/Lenovo/` |
| N7 | 设备驱动来源 = **从原厂 `uefi/xbl` 提取的 DXE 二进制**（UEFIReader）。**我们本机已有 `~/下载/tb322fc/{uefi.elf,imagefv.elf,tools.fv,abl.elf}`**（`BOOTCHAIN` §2.2 已解析） | 移植指南 |

**缺口收窄为**：只差一个 **TB322FC 设备包**（内存映射 + ConfigurationMap + 设备 DTB + dsc/fdf）。SoC 级（Pakala）与"能跑的 SM8


## Automatic settled outcome - 2026-10-05

联网检索完成（GitHub API 直连可用；web_search 后端全灭——代理 TLS 故障，未能搜中文社区/预构建产物）。**结论：需要的资源基本可以"直接用现成的"，不必从零移植。**

## 一、一句话结论

之前判定的"缺环 = TB322FC 设备包"**已经在公开仓库里完整存在**：
- **设备包**：`sunflower2333/mu_wide_platforms` → `Platforms/PakalaPkg/Device/lenovo-y700g4/`（518 个文件）
- **原厂 DXE 驱动源**：`Project-Aloha/UEFIFirmwareBackup` → `lenovo-y700g4/BOOT.MXF.2.5.1-00240.1-PAKALA-1/`
- **构建脚本原生输出 `lenovo-y700g4.img`**（Android boot 镜像 = BootShim+UEFI FD）——正是 Route A 要的产物。

## 二、资源清单（已核实存在）

| 资源 | 位置 | 内容/证据 |
|---|---|---|
| SM8750 平台包 | `sunflower2333/mu_wide_platforms` `Platforms/PakalaPkg/` | `PakalaNoSb.dsc`：`TARGET_DEVICE` 选设备；`Silicon/QC/Sm8750/QcomPkg` |
| **TB322FC 设备包** | 同上 `Device/lenovo-y700g4/` | `PlatformMemoryMapLib.c`（**真实 SM8750/Y700g4 内存映射**）、`PlatformConfigurationMapLib`、`ACPI/DSDT.aml`、`DeviceTreeBlob/Linux/linux-y700g4.dtb` |
| 设备专属 patched 驱动 | 同上 `PatchedBinaries/` | Clock/UFS/PMIC/SPMI/WDog/UsbConfig/FeatureEnabler 的 `.efi+.inf` |
| Qualcomm DXE 全集 | 同上 `Binaries/` | ArmPkg/EmbeddedPkg/**FatPkg**/MdeModulePkg/QcomPkg/RawFiles |
| 显示/SMBIOS | `PcdsFixedAtBuild.dsc.inc` | 1904×3040 framebuffer；SMBIOS `Lenovo / Y700 / 4` |
| BootShim 参数 | `build_cfg/sm8750.json` | `UEFI_BASE=0xFF300000, UEFI_SIZE=0x400000` |
| 原厂 UEFI 备份 | `Project-Aloha/UEFIFirmwareBackup/lenovo-y700g4/` | 480 文件，`BOOT.MXF.2.5.1-00240.1-PAKALA-1`（提取 Binaries 的来源） |
| 同族 SM8750 参考 | `Device/{oneplus-dodge,oneplus-erhai,xiaomi-piano,nubia-nx789j}` | xiaomi-piano 有独立 CI 工作流 + 现存产物 |

**构建命令**（README 明确）：`./build_uefi.py -d lenovo-y700g4` → 产物 `Build/PakalaPkg/lenovo-y700g4.img`。`build_uefi.py` 自动按 `Device/` 目录发现设备、按 `build_cfg/*.json` 定平台，我们的设备名会被解析到 Sm8750/PakalaPkg。

## 三、仍缺 / 风险（无法靠联网补）

1. **无该设备的验证记录**：GitHub 上找不到 `lenovo-y700g4` 的可用性报告/CI 工作流（只有 bulk commit "add pakala pkg."，作者 KancyJoe，2026-07-19）；同族 `xiaomi-p


## Memory - 2026-10-05

中文社区检索方法（本机实测）：①B 站可用——先 curl https://www.bilibili.com/ 拿 cookie(buvid)，再 curl -b 调 api.bilibili.com/x/web-interface/search/type?search_type=video&keyword=<urlencoded> 带 Referer，code=0 正常返回；view?bvid= 取详情、x/v2/reply 取评论。②cn.bing.com 对长尾/技术查询返回“热门兜底”（不同查询结果完全相同）不可用；baidu/sogou 被 SEO 污染；tieba/coolapk 403、xda 直连 000、4pda 403。③中国站点 direct 与 proxy 均可 200，但 GitHub api 直连需重试（间歇 000/200）。④GitHub 搜索 API 未认证限 10/min；用 `gh auth token` 取 token 后 curl -H "Authorization: Bearer $TOKEN" 走 search/code 与 /search/repositories，可绕限。


## Automatic settled outcome - 2026-10-05

中文社区这次查到位了。结论先行。

## 结论：中文社区**没有** TB322FC 的 UEFI / U-Boot / Windows-on-ARM 资源

本轮用 B 站官方 API（先取 cookie 再搜）+ 贴吧/酷安/百度/必应/搜狗，结果是**否**：

| 渠道 | 结果 |
|---|---|
| **B 站**（API 可用） | 无 UEFI/U-Boot/WoA 移植；检索词 `TB322FC/UEFI/uboot/双系统/Windows` 命中的都是别的主题 |
| cn.bing / baidu / sogou | 长尾查询返回"热门兜底"（4 组不同查询结果完全相同）或 SEO 污染，不可用 |
| 贴吧 / 酷安 / XDA / 4pda | 403/404（反爬），未能进入 |

**唯一像 UEFI 的线索已排除**：`BV1FNKtzLEmM《让拯救者y700四代用上Windows系统》`（UP 夏折腾1118，2025-06-25）——其评论区自证是**串流/远程 + Winlator 类**，不是本地 UEFI WoA（评论在问"为什么骁龙 8E 不行、只支持到 K20"）。

## 中文社区实际在做的是（与本项目相邻）

- **澎湃 OS 移植**（免解锁 root）：悲伤的压缩包等，多条 2026 视频——纯 Android。
- **主线 Linux**：`BV1stYX66EKG` GEEKiDoS《Y700 四代主线 Linux 7.2 KDE Plasma》= 与本仓 `geekidos-linux/` 同源；`BV1q2N46WEXs` 三代 Linux（作者 **酷安@GUF296**）。
- **一加 Pad2Pro / 橘子系统移植**、**Winlator/盖世游戏**跑 PC 游戏（Android 侧转译，非真 Windows）。

⇒ 中文社区**只有 Android 侧 OS 移植与模拟器**，没有我们 Route A 需要的那类产出。

## 因此

- **可用资源仍是上一轮那批 GitHub 的东西**（`sunflower2333/mu_wide_platforms` 的 `lenovo-y700g4` 设备包 + `Project-Aloha/UEFIFirmwareBackup`）——那看起来也是中文开发者（sunflower2333/KancyJoe）在 GitHub 上做的，但**没有在中文字区公开/发教程**。
- 中文社区这条线**到此为止**，按你说的"不行就算了"。

要我把本轮两条线（GitHub 资源清单 + 中文社区无果）合并落一页 `archive/topics/UEFI-RESOURCES-2026-10-06.md` 并更新 `RESOURCES.md §1.5/§3` 吗？或者直接开 lane 去 clone + 构建冒烟？


## Automatic settled outcome - 2026-10-05

完成。本会话只做**资源收集 + 社区经验记录**，未 clone/未构建/未上机。

## 交付

**新增档案** `archive/topics/UEFI-RESOURCES-2026-10-05.md`（过程证据，只增不改）：
- **§2 可用资源清单**（均 API 核实）：`sunflower2333/mu_wide_platforms` 的 `Platforms/PakalaPkg/Device/lenovo-y700g4/`（518 文件：真实内存映射/DT/DSDT/patched DXE/原厂 DXE 全集）+ `Project-Aloha/UEFIFirmwareBackup/lenovo-y700g4/`（480 文件原厂 DXE 备份）+ Mu-Silicium `PakalaPkg`/`dodgePkg` 备选。
- **§3 机制**：`build_uefi.py -d lenovo-y700g4` → `Build/PakalaPkg/lenovo-y700g4.img`（BootShim + UEFI FD 塞 boot kernel 槽）＝Route A 要的产物。
- **§4 中文社区检索记录**：B站/必应/百度/搜狗/贴吧/酷安/XDA/4pda 全渠道；唯一 UEFI 线索 `BV1FNKtzLEmM` 已由评论区自证是串流/Winlator；**中文社区无 TB322FC 独立 UEFI/WoA/U-Boot 产出**。
- **§5 检索经验**（B站 cookie-bootstrap API、Bing 长尾兜底、`gh auth token` 绕 GitHub 搜索限流、fork 内容用 contents API、`web_search` 全灭时改 curl 直连）。

**领域层更新**：
- `RESOURCES.md` §1.6 新增「间接引导层 / SM8750 UEFI」资源表；§4 补本会话索引行 + 统计。
- `TASKS.md` G1-29 增 ⑤：**设备包已现成，Route A 由「自造 UEFI」转「取用+构建+验证」**。
- `INDEX.md` §6 登记新档案。

**提交** `e76413a`。`check-doctor`：**FAIL=0**。

## 一处待你决定的卫生问题

`check-doctor` **WARN=1**（改动前就是 WARN=1）：它用 `find .pi/sessions -name '*.jsonl'` 计数 = **79**，而 §4 索引 **78** 行。差异来自 `.pi/sessions/--home-…--/` 下 **9 个与顶层重复的旧会话 jsonl**（属 `fold-evidence`/历史副本），doctor 把嵌套文件也算成会话。这是**既有漂移**，本次编辑把差距从 2 缩到 1。

三个选项（都不属本会话既定范围，待你定）：
1. 让 doctor 只统计**顶层**会话 jsonl（改 1 行 `-maxdepth 1`）；
2. 清掉那 9 个重复的嵌套 jsonl；
3. 维持现状（已知、不影响内容）。

要处理吗？


## Automatic settled outcome - 2026-10-05

处理完成。

## 结论

先精确核对后发现：`check-doctor` 的 WARN **不是"重复文件"问题**，而是**索引缺一条会话**：
- 磁盘 79 条 jsonl（顶层 70 + `--home-…--/` 嵌套 9）、73 个唯一 ID；
- §4 索引 78 行、缺的是 **`01a107a2`**（2026-10-04「EDK2-Gunyah 三仓资产分析」会话，正是登记 `RESOURCES §1.5` 的那次）；
- 另有 5 行对应**已删会话**（保留作史，未动）。

⇒ 补上 `01a107a2` 后 **79 = 79**，无需删除任何文件。

## 交付

- `RESOURCES.md §4`：补 `01a107a2` 索引行 + 统计校准（79 行 / 73 磁盘唯一 ID / 5 行已删会话保留作史）。
- `check-doctor`：**FAIL=0 WARN=0**（全绿）。
- 提交 `2efd0ec`。

两个提交：`e76413a`（资源档案 + §1.6 + TASKS/INDEX）、`2efd0ec`（索引对齐）。本会话边界不变：**只收集资源、记录社区经验，未 clone/未构建/未上机**。
