# Hindsight — flashing

Techniques and root causes proven on Qualcomm/Lenovo tablet flashing. Host-machine

<!-- Older entries compacted -->
自锁式实验 |

## 下次开工第一件事（无需现在做）

物理键进 fastboot（关机后长按 电源+音量下）→ 回刷 `bootslot-b/boot_b_vk40-ram.img` 拿回可达 RAM 环境 → 把持久根 `idle-delay` 改回 0（或写进 `start-desktop.sh`）→ 再谈继续。命令与判据都在复盘 §5。

设备现在在重启环里等人工介入，本轮不再动。


## Automatic settled outcome - 2026-10-03

完成。结论先行。

## 结果

| 项 | 数值 |
|---|---|
| 建立 git 仓库 | 分支 `main`，**293 文件 / 7.9 M** 纳管，`.git` 仅 4.5 M |
| 排除资产 | `geekidos-linux` 13 G、`out` 4.6 G、`env-pass` 3.8 G、`backup` 1.5 G、`l2` 45 G 外置等全部 ignore |
| `git status` 耗时 | 0.004 s（大目录被忽略，不再刷屏） |
| 发现并修复的一个真问题 | `patches/0001–0011` **不能完整重建内核工作树**（5 个文件有差异，`q6prm.c` 根本没 patch） |
| 导出权威补丁 | `patches/elden-working-tree-ba28ec16f-2026-10-03.patch`（13 文件，反向 apply 校验通过）|

## 做了什么

1. **`.gitignore`（版本控制边界）**
   - 纳管：八份文档、`scripts/`、`patches/`、`archive/`、`.pi/{skills,memory,missions,agents,settings}`、`initramfs/`、`rootfs/` 脚本、`env-pass/{scripts,tools}`、几个关键 README。
   - 排除：上游 clone、构建产物、大二进制 dump、运行时状态（`.pi/sessions`、`.pi/messenger`）、**`sn.img`（含本机序列号）** 与 `l2` 外置挂载。
   - 踩坑记录：gitignore **不支持行尾注释**，`#` 必须独占一行，否则模式静默失效（第一次就栽在这）。

2. **`FILES.md`（新台账，已接入 `INDEX.md`）**：顶层逐项分类（体积 / 是否纳管 / 说明）+ 可清理标记表（P0–P3 + H1）+ 内核补丁回导纪律。

3. **内核进度固存**：把真实工作树导出为补丁。这是本仓库版本控制覆盖不到的唯一边界——之前进度只存在于 dirty tree。

4. 更新 `RESOURCES.md §2.5`：**P0-b 前置闸已解除**，`geekidos-linux make clean` 现在可安全执行。

## 可清理标记（未动手，等你确认）

| 标记 | 目标 | 可回收 | 风险 |
|---|---|---|---|
| P0-a | `/mnt/Samsung/fiotest/` | 4.1 G | 无 |
| P0-b | `geekidos-linux` 构建产物 `make clean` | ~11.4 G | 低（补丁已存） |
| P1-a | `out/`+`bootslot-b/` 旧 boot（留 vk40/vk39） | ~4.7 G | 低 |
| P1-b | `pkgs*` 包缓存 638 M | 0.6 G | 无 |
| P3 | AOSP 树 + `l2`（外置） | 568 G | 需先做 Q13 取证 |

根盘 P0–P2 合计约 **18 G** 可回收。

## 关于「轨迹变复杂」

38 个会话 / 45 M 在 `.pi/sessions/`（H1 标记）——这部分也影响 AI 上下文稳固度。可用 `session-librarian` 技能归档非活跃会话，只留最近若干。

## 请你拍板

1. 现在就执行 **P0（fiotest + `make clean`，约 15 G）**？（我可以先 `df -h` 记录、执行后再核）
2. 要不要顺手做 **P1（旧 boot 镜像 + 包缓存，约 5.3 G）**？——vk39 建议等 vk40 上机验收后再删。
3. H1 会话归档现在做吗？

`git log` 已有一条初始提交，工作树干净；后续每轮改动 `git add -A && git commit` 即可。


## Automatic settled outcome - 2026-10-03

DONE batch3: 9


## Automatic settled outcome - 2026-10-03

DONE batch1: 9


## Automatic settled outcome - 2026-10-03

DONE batch2: 9


## Automatic settled outcome - 2026-10-03

DONE batch4: 9


## Automatic settled outcome - 2026-10-03

DONE batch5: 9


## Automatic settled outcome - 2026-10-03

三件事的进展如下（数字先行，一页）。

## 任务 #1：会话条目整理 ✅

| 项 | 结果 |
|---|---|
| 派子代理 | **5 个**（batch1–5，各 9 会话），全部 `completed` |
| 产出 | `SESSION-INDEX.md`（全量 45 会话）+ `archive/sessions-catalog-2026-10-03.jsonl`（机器可读） |
| 独立复核 | 条目 45/45 合法唯一、字段齐全；抽查 09-29/09-30 两条**证实子代理准确**（非臆造） |
| 分类 | 实机验证 **20 ✅ / 2 ◐ / 23 ✗**；状态 **active 23 / reference 15 / junk 5 / superseded 2** |

会话分布在两处：`.pi/sessions/*.jsonl`（36）+ slug 子目录（7）+ 2 个重复测试。

## 任务 #2：以「最后一版实机验证」为界审核 ✅（第一遍）

**边界判定：vk34（2026-10-01 23:12）** 是最后一个有明确会话级实机确认的版本；INDEX 曾写「最后在机基线 vk39」但**无会话确认**（待你核）。

**未验证增量精确到 5 个文件 + config**（全部 10-02 10:48–12:12，mtime 取证）：

| 文件 | 内容 | 单独上机 |
|---|---|---|
| `sm8750-lenovo-elden.dts` | 分级热 trip 70/82/90/105 ℃ | ❌ |
| `q6apm.c` | APM 命令头 + **残留 `DBG` 打印** | ❌ |
| `q6prm.c` | 5 行（**`patches/0001–0011` 里根本没有**） | ❌ |
| `audioreach.c` | 35 行 | ❌ |
| `q6apm-lpass-dais.c` | MI2S BE graph 提前到 prepare（patch 0011） | ❌ |

vk34 之前的 8 个文件改动都已上机。**vk40 = vk34 基线 + 这 5 文件 + 10-03 持久化 initramfs**，是「新 bug」的最可能来源。

**4 条结构性缺陷（比单条改动更值得修）**：
- **F1** 所有 vk 共用同一 `uname -r` → 设备上**无法分辨在跑哪版**（回归无法归因，正是「进步不稳固」的根）
- **F2** `patches/0001–0011` 不能忠实重建工作树
- **F3** `q6apm.c` 残留调试打印
- **F4** 无 per-version git commit → 不能 bisect

已落盘：`archive/topics/AUDIT-since-vk34-2026-10-03.md`；登记 **GAPS Q22**、**TASKS G1-23**。

## 待你拍板

1. **边界确认**：10-01 之后到 10-03 之间，mainline 上机你是否**亲眼确认过任何一版**？若没有，就以 **vk34** 为界。
2. **任务 #2 下一步**（我建议）：`geekidos-linux` 建 `elden/` 分支提交现状 + 唯一 localversion（修 F1/F4）→ 以 vk34 为基线**反向移除音频 4 文件改动**，看 vk40 症状是否消失，直接定位回归源。
3. **重命名 + 删除**（任务 #3）：索引 §5 已列 38 条建议重命名、§4 列删除候选（5 junk + 2 superseded）。**等 #2 收口后再执行**——你要不要我先批量应用重命名（可逆）？

`git log` 已有 3 条提交（边界 → 会话索引 → 审计），工作树干净，296 文件纳管，`.git` 4.6 M。


## Automatic settled outcome - 2026-10-03

下一步已执行（全部主机侧、可回滚）。结论先行。

## 做了什么

**1. 内核树固存 + 修 F1/F4**（`geekidos-linux` 自己的 git）：

| 分支 | commit | 含义 |
|---|---|---|
| `elden/vk40-2026-10-03` | `6ef87e6a8` | vk40 现场原样（含 DBG 插桩）——回归对照 |
| `elden/vk34-recon` | `e72a036ed` | 回退 vk34 之后的 5 文件增量 |

因为 `.config` 早已有 `CONFIG_LOCALVERSION_AUTO=y`，**一提交 uname 就自动唯一**：
- vk40re → `7.2.0-debug-g6ef87e6a8868`
- vk34recon → `7.2.0-debug-ge72a036ed4be`

→ 设备上 `uname -r` 终于能分辨在跑哪版（这就是「进步不稳固」的根，已修）。

**2. 用真机镜像校验重建的 vk34**（关键可信度）：

| 项 | vk34 实机镜像 | 重建 recon |
|---|---|---|
| DBG 字符串 | 无 | **无** ✅ |
| 分级热 trip（DTB） | 无（单一 max 状态） | **无** ✅ |
| `sm8750-lenovo-elden.dtb` | 136346 B | **逐字节相同** ✅ |

→ recon 忠实重建了 vk34；顺带**确定**：DBG 插桩与分级热 trip 都是 vk34 之后的增量。

**3. 产出 A/B RAM 镜像**（`out/`，`fastboot boot` 即可，不写 flash）：`vk34recon.img`/`-ram`、`vk40re.img`/`-ram`。音频/QDSP6 全是 `=y`，不受 vermagic 影响。

## 请你上机做隔离实验（判据明确）

```bash
cd ~/y700-elden
fastboot fetch boot_b backup/HA2EXB0E-16+512/boot_b.pre-ab.img   # 备份
# 进 fastboot；确认活跃槽 dtbo 已 blank（否则卡 logo）
fastboot --set-active=b && fastboot flash dtbo_b bootslot-b/dtbo_b.img
fastboot boot out/boot-elden-vk34recon.img                       # 先跑 vk34
ssh root@192.168.7.1 'uname -r'      # 期望 …-ge72a036ed4be
# 复现熄屏：设 idle-delay=10，SSH 常 ping 观察是否重启；测完改回 0
# 再 reboot 回 vk40，对 vk40re 重复对照
```

- **vk34recon 不重启 / vk40re 重启** → 回归源就在那 5 个文件里，继续二分（先只留 DTS 热 trip，或只留音频）。
- **两者都重启** → 与内核增量无关，转向 10-03 持久化 initramfs / `start-desktop.sh` / UCSI 电源路径。

⚠️ RAM 引导非持久，万一重启回到 flash 的 boot_b（vk40）可恢复；但 `idle-delay` 写在持久根**会留存**，务必改回。

完整步骤与哈希记在 `archive/topics/AUDIT-since-vk34-2026-10-03.md` §5；父仓库 4 条提交、内核仓库 2 分支，均已固存。

**一个前提想跟你确认**：设备现在是从先前的「重启环」里救回来了吗、fastboot 可用？如果暂时不方便上机，我可以先把「只回退音频 / 只回退热 trip」的中间变体也编好备着。


## Memory - 2026-10-03

内核回归定位法（可复用）：①从实机 boot 镜像解包内核/DTB，用 `strings`/DTB 逐字节对比确定"最后实机验证版本"到底含哪些改动；②用文件 mtime 锁定边界之后的增量文件集；③重建时把重建 DTB 与实机 vk34 DTB 逐字节比对来证明重建忠实；④内核树开 CONFIG_LOCALVERSION_AUTO=y 并**每版一 commit**，uname 即自动带唯一 commit（否则所有构建共用同一 uname，回归无法归因）。


## Automatic settled outcome - 2026-10-03

三项整理全部完成，工作树干净。结论先行。

## 实机结论（本 session 主任务收口）

**`vk34recon` 睡眠正常、不自动重启；`vk40` 复现重启 → 回归源锁定在 vk34 之后的 5 文件内核增量内**（与 10-03 持久化 rootfs 无关）。已记入 `GAPS` Q22、`TASKS` G1-22/G1-23、`AUDIT` §5；逐项二分（只回退 DTS 热 trip / 只回退音频）留待将来。

## 整理三项

**① 经验统一入口 → `LESSONS.md`**
- 开篇「零号纪律」三条（先查本地结论 / 刷写前备份+读回校验 / 持久系统不做自锁实验）
- `PITFALLS.md` **#1–#87 共 88 条**按主题分类索引
- 并列其他来源：`.pi/memory/{FAILURES,HINDSIGHT}`、`archive/topics/复盘-*`、`GAPS` 风险、技能 `references/`

**② 进度与描述用 git 管理（复用子代理成果）→ `db/`**
- SQLite `db/elden.db`：`sessions` **45**（进度轨迹，来自 `archive/sessions-catalog-*.jsonl`）、`tasks` **32**（TASKS 台账）
- 结构化 + 可查询，取代纯文字；`db/build.py` 从 git 文本源重建，**已验证确定性**（两次构建 sha 相同）

**③ 参考文献数据库索引 → `references_` 表**
- **127 条**：`RESOURCES.md` 的外部参考/本地资源（kind=ext/local）+ 全仓库 `*.md` 里的 URL（kind=url，已过滤本机/私网噪声）
- `db/schema.sql`（5 表）+ `db/build.py` + `db/README.md`（查询手册）

## 状态

| 项 | 数值 |
|---|---|
| git 提交 | **6 条**（边界 → 会话索引 → 审计 → 回归准备 → 知识库 → 重建） |
| 纳管文件 | **301**（`.git` 4.9 M，工作树干净） |
| 知识库 | `db/` 224 K，5 表 |
| 可复现 | `python3 db/build.py --lessons` → 重建 DB + 刷新 `LESSONS.md` |

常用查询（见 `db/README.md`）：
```bash
sqlite3 db/elden.db "SELECT num,title FROM pitfalls WHERE body LIKE '%关键词%';"
sqlite3 -header -column db/elden.db "SELECT substr(id,1,8),start,name FROM sessions WHERE hardware_verified='yes';"
sqlite3 -header -column db/elden.db "SELECT kind,title,locator FROM references_ WHERE title LIKE '%redroid%';"
```

新会话建议读取顺序：`INDEX.md → LESSONS.md → db/README.md`（已写入 INDEX 顶部）。

后续改动分析（vk34 增量的逐项二分）按你的要求不再展开，入口与 A/B 镜像（`out/boot-elden-vk34recon*.img` / `vk40re*.img`）已备好留将来。


## Automatic settled outcome - 2026-10-03

我已把 post-vk34 增量全部逐 hunk 分类，并在串口日志里找到一条**先前没被记录的关键证据**。先给结论。

## 审计结果：post-vk34 增量逐 hunk 分类

边界固定：`git diff elden/vk34-recon → elden/vk40-2026-10-03` = **仅 5 文件**（已 DTB 逐字节比对确认 recon 忠实）。

| 文件 | 功能性改动 | 纯调试 | 风险 |
|---|---|---|---|
| `sm8750-lenovo-elden.dts` | **24 个热区**全部改成 4 级 passive trip（70/82/90/105 ℃）+ 4 条 cooling-map | 0 | 🟡 纯策略，空闲低温不触发；**从未单独验证** |
| `q6apm.c` | **3 处 GPR 命令** `alloc_apm_pkt` → `alloc_apm_cmd_pkt`（GET_SPF_STATE / SHARED_MEM_MAP / UNMAP，多 8 字节 APM cmd header） | 3（其中 2 个有副作用） | 🔴 见 N1/N2 |
| `q6apm-lpass-dais.c` | 新增 `q6i2s_prepare`：**MI2S BE graph 提前到 prepare 启动** | 3 | 🟠 见 N3 |
| `audioreach.c` | **无**（13 行全是 print） | 3 | 🟡 见 N4 |
| `q6prm.c` | **无**（`int ret` + 1 行 print） | 1 | 🟢 |

## 发现的实质问题（不止"未验证"，是真隐患）

- **N1（副作用写进日志）**：`q6apm.c` 把 `q6apm_get_apm_state(apm)` **当作 `dev_info` 的实参**调用，位置在 `apm_probe` 和 `q6apm_graph_open`。即：**每开一次 graph / 每次 probe 都额外向 ADSP 发一条 GET_SPF_STATE 并可能阻塞 5 s**。日志不该有副作用。
- **N2（最可疑）**：3 处命令换成 `alloc_apm_cmd_pkt` —— 它给包**加了 8 字节 APM command header**。而 vk34 的原注释白纸黑字写着 *"GET_SPF_STATE has no APM command header or payload"*，vk40 直接推翻了它。这是**唯一会改变发给 ADSP 的字节流的改动**。
- **N3**：`q6i2s_prepare` 把 BE graph 启动从 trigger 挪到 prepare，`is_port_started` 语义随之改变；启动顺序/重复启动无对上机验证。
- **N4**：`audioreach.c` 残留 `print_hex_dump` 整包 + 3 条 DBG；`q6apm-lpass-dais.c` 的 `set_sysclk` 打印用 `%px`。上机日志被灌爆（serial 里大量串行噪声即与此有关）。

## 新证据（复盘里没有的）

`logs/serial-20261003-192121.log` 段 B：**ADSP 真的崩了**，不是只有 UCSI 报错：

```
[ 20.874] [drm] vblank timeout: 400000 / wait for commit done -110
[ 21.165] qcom_q6v5_pas 6800000.remoteproc: fatal error received:
          sys_m_smsm.c:322:err fatal notification received from TZ
[ 21.165] remoteproc remoteproc0: crash detected in adsp: type fatal error
[ 21.165] remoteproc remoteproc0: recovering adsp
[ 21.165] ucsi_g


## Automatic settled outcome - 2026-10-03

设备已在 fastboot。我停手，给当前状态（不强行解释）：

## 已确立的事实（可复现）

| 内核 | 显示 on/off 提交后 dmesg 计数 |
|---|---|
| vk34recon（基线） | vblank=0, PPM=0, adsp=0 |
| vk40re | **vblank=6, PPM=1**, adsp=0 |

→ **DPU `vblank timeout` + `UCSI PPM init failed` 是 vk40 可量化的回归**（比间歇重启更适合二分）。

## 未定 / 需谨慎

- **V1(热区)/V2(音频) 是否引发该回归**：尚未取到（上一次测 V1 的命令中途卡死）。
- **复位根因**：vk40re 时而 ~1 min 一次、时而稳定 400 s → **单次观测无统计意义**；上一次 vk34recon/V1 卡死更要说明：不稳定未必只属于 vk40。
- **钩子副作用**：你提的这点无法排除——加钩子后 vk40re 从"1 min 一次"变"400 s 稳定"。钩子已撤、`start-desktop.sh` 已还原。

## 对设备的残留（无害，可清理）

- 设备持久根：`/usr/local/sbin/start-desktop.sh.bak-eldroid`、`/var/log/kmsg-*.log`（取证文件）。

## 建议

不再碰持久系统，只用 `fastboot boot` + SSH(`192.168.7.1`) 读 `dmesg`，**一次只测一版、你看着**。最有价值的一刀：测 **V1（热区 only）**——若 V1 也出 vblank → 归因热区（70 ℃ 提前限频拖慢 DPU 提交），与音频无关。

要我现在只测这一版 V1，还是先停下把已有结论落盘归档？


## Automatic settled outcome - 2026-10-03

归档完成。已落盘并提交（`12843c7`）：

## 写入内容

| 产物 | 内容 |
|---|---|
| **`archive/topics/AUDIT2-post-vk34-bisect-2026-10-03.md`** | 第二遍审核全文：逐 hunk 分类（N1–N4）、V1/V2 二分变体表、实机结果、方法学坑、钩子事件 |
| **`GAPS.md` Q22** | 补充第二遍进展 + vblank 可量化回归 + 间歇性告警 + 钩子副作用嫌疑 |
| **`TASKS.md` G1-23** | ✅→🟡 第二遍进行中；判据改为"同口径 dmesg 计数，V1/V2 各 ≥1 有效样本"；G1-22 补记伴生回归 |
| **`profile_memory`** | 新增失败教训：间歇性故障的**观察者效应**（取证钩子改变被测行为）+ ModemManager 占 ttyACM |

## 归档的硬结论

- **post-vk34 增量 = 5 文件**；其中 N1（日志内副作用调用 `q6apm_get_apm_state`）、N2（`alloc_apm_cmd_pkt` 加 8 B APM cmd header，与 vk34 注释矛盾）、N3（提前启动 BE graph）是实质改动，N4 是残留 DBG 打印。
- **可量化回归**：`vk40re` 显示 on/off 后 `DPU vblank timeout`=6、`UCSI PPM init failed`=1；`vk34recon` 同操作 **0/0**。
- **静默硬复位是间歇性的**（1 min/次 与 400 s 稳定都出现）→ 单次观测无统计意义，不强行解释。
- **钩子副作用不可排除**，已回退；V1/V2 同口径样本未取到。

## 设备侧

- 设备在 **fastboot**；持久根残留两个无害取证文件（`start-desktop.sh.bak-eldroid`、`/var/log/kmsg-*.log`），文档已列。
- 二分镜像已备好：`out/boot-elden-v1-thermal.img`、`out/boot-elden-v2-audio.img`（uname 唯一、已验证组成）。

下次要推进时，入口就是 `AUDIT2` §8 的"单变量、长时窗、最小侵入"三条。


## Automatic settled outcome - 2026-10-03

审查完成。结论先行。

## 1. 你担心的「副作用放进轮询内部」——**没有发生**

扫描 `~/y700-elden/.pi/sessions/**/*.jsonl` **全部 49 个会话**的 bash 调用：含副作用的命令 132 条，其中同时含循环的 69 条；**副作用字面出现在 `do…done` 循环体内 = 0 条**（另 4 条正则命中经逐条核对全是假阳性：grep 自身模式、`adb dd` 备份 uefivarstore/devinfo）。仓库脚本同样为 0：`cycle.sh` 的 `wait_fastboot/wait_linux`、`serial-log.sh`、`dpms-watch.sh`、`thermal-watch.sh`、`/tmp/cap-loop.sh` 全是纯读/纯探测；`iterate.sh`、`flash-b.sh --reboot` 都是「先动作、后轮询」的线性结构。

## 2. 但找到同源的**真隐患**：「副作用 + 长轮询同处一条命令，被 harness 超时杀死」

本次二分会话里 AI 反复写 `写misc+reboot -f` ⏎ `for…轮询fastboot…done` ⏎ `[ $OK=1 ] && fastboot boot X`。这类命令 10 条，**4 条 `Command aborted`**（#77 reboot→boot vk40re；#113 boot vk34recon；#127 reboot→boot v1；#80 纯轮询）。被 SIGTERM 时可能停在轮询中（boot 没发），也可能停在 `fastboot boot` 传输中途——**副作用发没发无法判定**。不是「重复执行」，是「执行点不可判定」。

## 3. 新发现（比你担心的更严重）：**持久 b 槽烧的就是 vk40 内核**

解出每个 boot 镜像的内核 payload（gzip 流）sha256：

| 镜像 | uname | kernel payload |
|---|---|---|
| `bootslot-b/boot_b.img`（当前 b 槽） | `…gba28ec16f01f-dirty` | **d16ab35ce4a57afa** |
| `bootslot-b/boot_b_vk40-ram.img`（10-03 实烧） | 同上 | **d16ab35ce4a57afa** |
| `out/boot-elden-vk40.img` | 同上 | **d16ab35ce4a57afa** |
| `out/boot-elden-vk34recon.img` | `…ge72a036ed4be` | ecfa53db763c57fe |

⇒ **b 槽 = vk40 现场内核**；且 `vk30…vk40` 全部共用同一 dirty uname（F1/F4 的根源）。
串口捕获 `logs/console-v1-1003-204530.log`（20:45–21:01）16 分钟内启动 8 次，**其中 5 次是 vk40**，每次只活 **20→40 s**。
⇒ **任何复位都回退到 vk40**，所以「复位次数/复位后行为」的跨版本比较天然被污染。

## 4. 对现有结论的裁决
- ✅ `vk40re` vblank=6/PPM=1 vs `vk34recon` 0/0 —— **版本归属可信**（per-uname 的 kmsg 文件）。
- ⚠️ 「vk40 会静默硬复位 / vk34 不会」—— **存疑**（复位后落回 vk40，无法归因）。
- ⛔ V1/V2 —— 未取到（#127 中断）。
- ❌ 「vk40 vs vk40re 两个对照」—— 同一 commit `6ef87e6a8`，仅重打包。

## 5. 已落地 + 下一步
- 新增 `archive/topics/AUDIT3-polling-sideeffects-2026-10-03.md`（含复现脚本）；更新 `GAPS` Q22、`TASKS` G1-23；提交 `3f7604b`/`1040228`。
- **资产已备（host 侧，未碰设备）**：`


## Automatic settled outcome - 2026-10-03

已按你的要求准备好。数字先行。

## 1. 测试版本（已备齐，uname 全唯一，`matrix` 可复核）

| label | 镜像 | uname | sha256(前16) |
|---|---|---|---|
| `vk34recon` | `out/boot-elden-vk34recon.img` | `…ge72a036ed4be` | `5397af38cf55480c` |
| `v1-thermal` | `out/boot-elden-v1-thermal.img` | `…gf681b616a3af` | `d6cb6e2b29a86718` |
| `v2-audio` | `out/boot-elden-v2-audio.img` | `…g951c5f1c2ca5` | `5e6d71df1f687d7d` |
| `vk40re` | `out/boot-elden-vk40re.img` | `…g6ef87e6a8868` | `1a2315b8450f1103` |
| **b 槽基线** | `bootslot-b/boot_b-vk34recon.img`（已签名） | 同 vk34recon | `53e5857a581e77a3` |

## 2. 自动化脚本 `scripts/bisect/eldtest.sh`（已提交 `28d6860`）

针对 AUDIT3 的教训做了三件事：
- **减少轮询**：等待启动改成**事件驱动**（`tail -F` 串口日志，等 `Linux version <uname>` 横幅出现），不再 tight `fastboot devices` 轮询。
- **渐进触发**：`idle0(45s)` → `on` → `off` → `on/off×5` → `idle2(120s)`，每级之间只读一次 `dmesg` 计数，逐级加压。
- **单步副作用**：`fastboot boot` 单独成步并落 journal；任何等待循环里**没有** reboot/boot。

常用命令：
```bash
scripts/bisect/eldtest.sh matrix      # 版本表（不碰设备）
scripts/bisect/eldtest.sh prepare     # 生成 manifest 到 logs/bisect/
scripts/bisect/eldtest.sh baseline    # 打印 b 槽基线烧写步骤
scripts/bisect/eldtest.sh one vk34recon   # fastboot boot + 渐进触发观测
scripts/bisect/eldtest.sh observe vk40re  # 你手动 boot 好后只观测
```
结果落 `logs/bisect/<ts>/{results.tsv,journal.log,console.log}`；复位判据 = uname 变化 / uptime 回退 / SSH 断。

## 3. 建议的第一刀（你亲自操作设备）

```bash
fastboot flash boot_b bootslot-b/boot_b-vk34recon.img
fastboot boot out/boot-elden-vk34recon.img          # 临时起来做读回校验
ssh root@192.168.7.1 'dd if=/dev/disk/by-partlabel/boot_b bs=1M count=96 2>/dev/null | sha256sum'
sha256sum bootslot-b/boot_b-vk34recon.img           # 两个 sha 必须一致
```
这一步把「复位回退目标」从被测的 vk40 换成已知基线，之后测 vk40re 时若复位，会看到 uname 变成 vk34recon，归因才干净。

## 4. 两个待你拍板的点

1. **是否加温度压测级**：V1 是热区改动，光靠显示 on/off 未必触到 70 ℃ passive trip。可加一个可选级 `s4:load`（设


## Automatic settled outcome - 2026-10-03

你说得对，是我归因错了——**刚才那次是你物理重启进的 fastboot**，我把手动操作误记成 BCB 生效。本地检索后确认：

## 结论：Linux→fastboot 能力确实不存在

| 途径 | 事实 |
|---|---|
| `cycle.sh --soft`（纯 `reboot -f`） | b 槽主线可直启后**不再落 fastboot**（HANDOFF §19/§24、PITFALLS #65） |
| `cycle.sh --fastboot`（写 `misc` BCB `bootonce-bootloader`） | **实测 ABL 未采纳**：misc 首 20 字节确为 `bootonce-bootloader`，`reboot -f` 后仍正常启 Linux |
| 历史「reboot 必落 fastboot」 | 是当时 **a 槽 AVB 校验失败**的副产物（HANDOFF §19），不是 BCB 生效 |
| 现在进 fastboot | **只有物理键**（或 fastboot 内的 `fastboot reboot bootloader`） |

`abl_a.img` 只有 1 MB 且无明文串，离线反查 ABL 接受的 BCB 命令不可行。

## 好消息：A/B 测试**不需要**这个能力

`scripts/flash-b.sh <img> --reboot` 从 Linux 里自签 + `dd` 写 `boot_b` + sha256 回读校验 + 重启，**全程不开 fastboot**：
- 每版 uname 唯一 ⇒ 版本归属精确；
- 测试中复位 → ABL 回退到**同一个**已烧内核（uname 不变）⇒ 靠 uptime/SSH 断判定复位，归因干净；
- **前置必做**：`python3 scripts/slot-attr.py mark-successful b`——否则主线没有 `markBootSuccessful`，retry 每次 -0x08，约 7 次后 b 槽 unbootable 也会停 fastboot（机理见 `GPT槽位元数据-2026-09-30.md`）。

## 已落地
- 脚本 `eldtest.sh`：**移除不可靠的 `cycle`(BCB)，新增 `flash` 子命令**（flash-b → 重启 → 渐进触发观测）。`one`（fastboot 已就绪时 RAM 引导）与 `observe` 保留。
- `PITFALLS.md` **#88** + `AUDIT3` §7 记录该缺口与对策；提交 `b4f92f1`。
- 附带教训：任何「Linux 切 fastboot」的记录，**先分清是物理键还是软件**，别把用户的手动操作记成工具生效。

## 待你拍板
1. **走 flash-b 路线继续测试**（推荐，无需新能力）：我会把前置 `slot-attr.py mark-successful b` 也纳入脚本，然后按 `vk34recon → vk40re → v1-thermal → v2-audio` 各 3 轮跑。设备现在是你 RAM 引导的 vk40re（uptime 已 160s+，可当第一轮 vk40re 样本）。
2. **另立专项造 Linux→fastboot**（可选）：候选 ① ABL 认可的其它 BCB 命令；② IMEM `restart_reason`=fastboot 魔术；③ 用 `slot-attr.py` 可控耗尽 retry 逼 ABL 回退 fastboot（有风险）。需要 XBL/ABL 取证，建议单独会话。

你选哪条？


## Automatic settled outcome - 2026-10-03

已把这条决策记入会话笔记（基座甲/乙待你选，音频在纯 vk34 上不可用的原因）。等你回复选甲还是乙 + 第一个要测的功能项。


## Automatic settled outcome - 2026-10-03

调研完成，已落盘（`ee2b0c5`）：`archive/topics/FLASHCTL-2026-10-03.md` + `TASKS.md G1-24` + `GAPS.md Q23`。数字先行。

## 三条能力，现状完全不同

| 能力 | 现状 | 机制 | 缺口 |
|---|---|---|---|
| **reboot→fastboot** | 🟢 机制**已在设备上** | DT `reboot-mode`(nvmem-reboot-mode) → PMIC SDAM `reboot-reason@48`；`mode-bootloader=0x02`；驱动**已绑定** | 只缺 userspace：以 reason 调 `reboot(2)` RESTART2 |
| **reboot→EDL** | 🔴 主线 7.2 树**无通路** | 需 PSCI `SYSTEM_RESET2` vendor reset（`mode-edl=<0x80000000 0x1>`）或 TCSR dload cookie | 移植驱动+DT，`psci.c` 现在只发 architectural reset |
| **选槽/成功位/清次数** | 🟢 已有 `scripts/slot-attr.py` | GPT 分区项 byte6（`boot_*` 在 **LUN4 `/dev/sde`**） | 包成 CLI；与 **C7** 合并 |

关键证据：`/sys/bus/platform/drivers/nvmem-reboot-mode/reboot-mode` 已绑定；`reboot-mode.c` 靠 **reason 字符串**匹配 DT 的 `mode-*`（所以 busybox `reboot` 无参不行，必须 RESTART2）。`/sys/kernel/reboot/mode` 是 cold/warm 那个，**无关**，别用。

## 关于你指的 TWRP

`twrp/twrp.img` 是 Android bootimg（header v4，ramdisk 52 MB **LZ4**）；TWRP 的「重启到 EDL」走的是**厂商内核**的 reboot handler，属私有实现，**不能直接移植到 mainline**——但它印证了用户侧行为。主机暂无 `lz4`（python lz4 被 PEP668 拦），ramdisk 内脚本待解，只作行为对照用。

## 设计：一个 `eldroid-bootctl`

```
eldroid-bootctl reboot <bootloader|recovery|edl|system>
eldroid-bootctl slot {info|active|set-active <a|b>|mark-successful [a|b]|set-retry <n> [a|b]}
```
- reboot = `libc.reboot(...RESTART2, reason)`（ctypes，免编译）；slot 复用 `slot-attr.py`。
- 写操作要 root，写前自动备份 GPT 前后 34 扇区、写后读回校验。

## 分阶段

- **S1（免内核，可立刻测）**：先只验 `reboot bootloader` —— 机制已在，最坏结果只是进 fastboot，`fastboot reboot bootloader`/`fastboot reboot` 或物理键即回。
- **S2（需内核构建）**：EDL 要么移植上游 `psci-reboot-mode`（2026-05 系列 + `psci.c` vendor 出口 + DT），要么加 `qcom,dload-mode=<&tcsr 0x19000>` + 自加触发。建议以内核基座 **`elden/vk34-recon`** 出 `vk41-flashctl`（本特性与音频/热区增量正交）。
- **S3**：slot 子命令上机验证。

## 需要你拍板

1. **现在就走 S1**？我把 `eldroid-bootctl`（先带 reboot+slot）备好，你在设备上跑 `eld


## Automatic settled outcome - 2026-10-03

审查完成。先给数字，再说结构问题，最后给目标架构与可执行清单。

## 一、现状盘点（数字）

| 维度 | 数量 |
|---|---|
| 根目录 `.md` | **12 份**（INDEX/DEVICE/TASKS/RESOURCES/GAPS/ANDROID-COMPAT/RUNBOOK-BRINGUP/PITFALLS/LESSONS/SESSION-INDEX/FILES/AGENTS） |
| 全仓 `.md` | 300（archive/topics 51、archive 层 57、.pi/missions 11、.pi/agents 6、skills 3） |
| 会话 jsonl | **51**（SESSION-INDEX/db 仍写 45） |
| git 纳管 | 306 文件（scripts 78、.pi 61、archive 61、patches 31） |
| 顶层条目 | **40+**（源码树/产物/缓存/备份/文档 tar 全部平铺） |

结论：**内容已经很丰富，缺的不是文档，是"分层"。** 现在 12 份根文档属于两个不同平面，却平级摆放、互相登记计数，已经开始漂移。

## 二、审查发现（按严重度）

1. **维护面定义过时且自相矛盾。** INDEX §2 仍写"六视角=唯一维护面"，但 §5 又列出 LESSONS/SESSION-INDEX/FILES/db。TASKS/GAPS 的表头还写"六视角文档集之一"，INDEX 已改口径。**三处对同一定义各说各话。**

2. **同一事实多处维护，漂移已发生。**
   - 会话数：`.pi/sessions` 实有 **51**，SESSION-INDEX/db 写 **45**。
   - 主题数：INDEX 写 49，实为 51。
   - db docs 表 127，全仓 `.md` 实为 300（口径未定义）。
   - "G1 ≈80%" 同时存在于 INDEX §3、TASKS §0、DEVICE、GAPS——四处，无指定权威。

3. **元层知识散落根目录。** `PITFALLS.md`（正文，591 行）+ `LESSONS.md`（生成索引）+ `db/pitfalls` 表 = **同一知识的第三份拷贝**，且 db 最后重建 20:03、PITFALLS 改到 22:11 → **已不同步**。

4. **根目录资产/源码/产物/文档混放。** 5 个 `y700-elden-docs-*.tar.gz`、flashing-bundle tar、`sn.img`、40+ 顶层目录；**脚本两处**：根 `build.sh/cycle.sh/iterate.sh/pack.sh/elden-net.sh` vs `scripts/` 78 个。

5. **过程证据 vs 活文档边界被打破。** INDEX §6 声明 archive/topics"**不再更新**"，但 AUDIT3 昨天还在加、GAPS 持续引用它当活文档。

6. **`.pi/` 内部无说明。** missions/agents 存在同名文件（audio-graphopen.md 两处）、messenger 运行时状态、sessions 轨迹，彼此关系与是否纳管均未记录。

7. **记忆单体化。** `HINDSIGHT.md` **80 KB**、`FAILURES.md` 17 KB，按 `## Memory - <date>` 追加大块，检索靠 grep，已接近上下文成本上限。

## 三、建议目标架构：三个平面，边界显式

```
y700-elden/
├── INDEX.md              ← 唯一入口；只做路由 + 分层定义
├── docs/                 ← 【平面1】领域活文档（唯一维护面，状态只此一处）
│   DEVICE  TASKS  RESOURCES  GAPS  ANDROID-COMPAT  RUNBOOK-BRINGUP
├── meta/                 ← 【平面2】知识管理/元数据
│   FILES(资产台账)  PITFALLS(经


## Automatic settled outcome - 2026-10-03

收到，方案按这个改。已交付并 commit（`0f90f1c`）。

## S1 交付物（已上设备只读验证）

| 文件 | 作用 |
|---|---|
| `scripts/eldroid-bootctl` | `reboot <bootloader\|recovery\|system\|edl>`（ctypes `reboot(2)` RESTART2；EDL 占位、默认拒绝）+ `slot info/active/set-active/mark-successful/set-retry`（转发 `slot-attr.py`，**写前自动备份 GPT 前 34 扇区**） |
| `scripts/flash-recovery.sh` | Linux 内 `dd` 写 `recovery_b` + sha 回读 + 可选 `--reboot` |

设备上已放 `/usr/local/bin/`，`slot info`/`active` 实跑通过。

## 实读暴露的两个关键事实

1. **⚠️ `boot_b` 正在倒计时**：`byte6=0x2f → retry=5, succ=0`。mainline 从不调 `markBootSuccessful`，再启动 5 次 ABL 就置 unbootable 停 fastboot。这也正是你要的"重置启动次数"功能——**建议立刻**：
   ```bash
   ssh root@192.168.7.1 eldroid-bootctl slot mark-successful b
   ```
2. **TWRP 其实还没装**：设备 `recovery_a`/`recovery_b` 都是原厂（ramdisk ~16 MB）；`twrp/twrp.img` 才是 TWRP（ramdisk 52 MB）。另外 `backup/stock-259/recovery_{a,b}.img` 与 `twrp.img **同 sha**` —— 命名误导，它们不是原厂，恢复时别用。

## 为什么 recovery 目标选 `recovery_b`（免签）

`current-slot=b`（GPT 实测）；`vbmeta_b` 已被我们的 key 重签且 **Flags=3**、描述符**不含 recovery** ⇒ 写 `recovery_b` 不用签名。`vbmeta_a` 是原厂含 recovery 描述符，动它还要切槽，不值。

## 请你执行的验证（可逆，最坏进 fastboot/recovery）

```bash
# 0) 先止血
ssh root@192.168.7.1 eldroid-bootctl slot mark-successful b
# 1) 验 ABL 是否采纳 PMIC SDAM reason（这决定后面走 S2 还是移植 PSCI）
ssh root@192.168.7.1 eldroid-bootctl reboot bootloader
#    → 进 fastboot 即成功；fastboot reboot 回来
# 2) 装 TWRP 到 recovery_b
scripts/flash-recovery.sh twrp/twrp.img
# 3) 验 reboot recovery → TWRP
ssh root@192.168.7.1 eldroid-bootctl reboot recovery
```

## 待你拍板

1. 先跑 1) 验 `reboot bootloader`，还是直接连 TWRP（2→3）一起做？
2. TWRP 装好后是否要顺手做一次"从 TWRP 里重启到 EDL"的对照（记录 TWRP 如何触发 EDL，为将来 EDL 立项留证）？

（细节与证据在 `archive/topics/FLASHCTL-2026-10-03.md`；TASKS G1-24 / GAPS Q23 已更新。）


## Automatic settled outcome - 2026-10-03

A 已全部落地并提交（`e5e20df`）。自检全绿（仅剩 1 条真实待办）。数字先行：

## 已交付

| 项 | 产出 | 说明 |
|---|---|---|
| **分层定义** | `INDEX.md` §2 重写 | 「六视角」→ **三平面**：领域层(唯一维护面) / 元层 / 证据层；明确 **SSOT** 与生成物禁手改 |
| **表头统一** | 6 份领域文档 + `AGENTS.md` | 「六视角文档集之一」→「领域层活文档之一；分层见 INDEX §2」 |
| **自检脚本** | `scripts/check-doctor.sh` | 4 类检查：计数漂移 / 死链 / db 新鲜度 / 口径冲突；退出码可入 CI |
| **生成物纪律** | `db/build.py --check` + `db/README.md` + `LESSONS.md` 横幅 | 标注 `LESSONS.md`/`elden.db` 为生成物，禁手改 |
| **`.pi` 说明** | `.pi/README.md` | 分清 skills/memory/missions/agents/sessions/messenger，含 track 状态 |

`check-doctor.sh` 当前输出：**FAIL=0，WARN=1**——唯一 WARN 是 `.pi/sessions` 实有 **51** 个、而 `SESSION-INDEX`/catalog 只收录 **45**（6 个新会话未入索引）。这是真实待办，不是假警报。

## 两处我**没动**，需要你知悉

1. **`HINDSIGHT.md` 未拆分。** 我核实了：项目 `.pi/memory/` 就是本项目会话的**活跃 profile 记忆**（由 pi 按固定文件名加载，不是普通文档）。按主题拆成 `memory/decisions/` 有**加载不到而丢记忆**的风险，违背"先确认不破坏可用系统"。所以只做了 `.pi/README.md` 说明，**拆分留作 B 项另行验证加载机制后再做**。
2. **`HINDSIGHT.md` 的工作区改动未纳入本次提交。** 它在会话开始前就已是 dirty（疑似上一轮 harness 的压缩/追加），与本轮整理无关，故未替它背书。

## 下一步（等你选）

- **补 6 个会话进索引**（消掉最后的 WARN）：读 6 个新 jsonl，补进 `SESSION-INDEX.md` + catalog → 重建 db。
- **B 项**（低风险、改路径）：建 `meta/` 移入 FILES/PITFALLS/LESSONS/SESSION-INDEX/db；5 个根脚本并入 `scripts/`。
- **C 项**（需决策）：领域文档是否也进 `docs/`；`archive/topics` 是否真冻结；旧会话归档。

要我接着做"补 6 个会话索引"吗？这能把 doctor 打到全绿。


## Automatic settled outcome - 2026-10-03

明白，目标改成**入口最小化**。现状是「1 个入口 + 11 个根文档」，其中不少是**索引/台账/说明**类冗余入口。下面给一个收敛方案，确认后执行。

## 现状：根目录 12 个 `.md`，真正的「内容」与「索引/说明」混在一起

| 类 | 文件 | 问题 |
|---|---|---|
| 入口 | `INDEX.md` | 唯一入口 ✓ |
| 内容(领域) | DEVICE / TASKS / RESOURCES / GAPS / ANDROID-COMPAT / RUNBOOK-BRINGUP | 六份，各有独立价值 |
| 索引/台账 | `PITFALLS.md`(正文) · **`LESSONS.md`(生成索引)** · **`FILES.md`(台账)** · **`SESSION-INDEX.md`(索引)** | 后三者＝同一批知识的第二入口 |
| 说明 | `AGENTS.md`(pi 必需) · `.pi/README.md` · `db/README.md` | 可下沉 |

**可收敛的正是「索引/台账」层**——它们不是内容，只是内容的另一个入口。

## 建议：根文档 12 → 6（+AGENTS.md）

| 保留 | 从哪来 | 合并动作 |
|---|---|---|
| **`INDEX.md`** | 入口 | 保持唯一入口；`.pi/README.md` 的要点并入 §5 后删除该文件 |
| **`DEVICE.md`** | 设备 | 不变 |
| **`TASKS.md`** | 任务 | **并入 `GAPS.md`**（未解问题/风险）**+ `ANDROID-COMPAT.md`**（G2 方案） |
| **`RUNBOOK-BRINGUP.md`** | 操作 | 不变 |
| **`PITFALLS.md`** | 经验 | **并入 `LESSONS.md` 的零号纪律**，删除 `LESSONS.md`（它本就是 PITFALLS 的生成索引） |
| **`RESOURCES.md`** | 资源 | **并入 `FILES.md`（资产/版本控制边界）+ `SESSION-INDEX.md`（会话索引）** |

结果：根目录只剩 `INDEX / DEVICE / TASKS / RUNBOOK-BRINGUP / PITFALLS / RESOURCES`（+必需 `AGENTS.md`），**入口仍只有 INDEX 一个**；`db/` 继续做机器可查索引，不再需要有同义的人读第二份。

## 取舍（需要你知道）

- 合并后 `TASKS.md` ≈ 280 行、`RESOURCES.md` ≈ 410 行、`PITFALLS.md` ≈ 600 行——**文件变长**，但"入口"变少。这两者是此消彼长，我按你的偏好取"入口少"。
- `LESSONS.md` 由 `db/build.py --lessons` 生成。删除后我会把生成逻辑改为「不写根文件」或输出到 `db/`，并更新 `check-doctor`（不再检查 LESSONS 新鲜度）。
- `SESSION-INDEX.md` 是逐会话摘要（156 行），并入 `RESOURCES.md` 末尾作为"会话轨迹"节；`db/elden.db` 的 `sessions` 表保留。
- 所有跨文件引用（含 `INDEX`/`check-doctor`/`db/build.py`）会一并改写，`check-doctor.sh` 做死链兜底。

## 更激进（可选，若你要求再少）

再砍到 **4 份**：`INDEX`（使命+状态+路由）+ `TASKS`（任务+未解+G2+上机手册）+ `PITFALLS` + `RESOURCES`。代价：`TASKS.md` 会到 ~700 行（把 RUNBOOK 也吞进去），定位信息会变难。**我不建议**，但你要就做。

---

**按推荐方案（6 份）执行吗？** 还是你要更激进的 4 份？定了我就一次性重写 + 修引用 + 跑 `check-doctor` 验证。


## Automatic settled outcome - 2026-10-03

已更新会话笔记，等你选 A / B。


## Automatic settled outcome - 2026-10-03

查了 pi 的文档与本地扩展，结论先给：**pi 没有等价的结构化知识库服务**；`db/` 属于它自己 `extensions.md` 里定义的「External storage」。但 db **可以整体删掉**，因为它的功能都能被更少的东西覆盖。顺带发现一个关于记忆的重要事实。

## pi 原生能提供什么

| 原生设施 | 实际能力 | 能否替代 db |
|---|---|---|
| **profile memory**（`pi-profile-memory.ts`） | 只认 3 个固定文件 `USER/HINDSIGHT/FAILURES.md`，**追加式**，加载时**只取每文件尾部**（USER/FAILURES 各 4 KB、HINDSIGHT 8 KB），超 64 KB 自动压缩 | ❌ 不能查询，只适合少量durable偏好 |
| **`context_history`** | 搜/读 transcript 里的消息，**scope 仅当前会话**（branch/session） | ❌ 跨会话索引它不做 |
| **session manager**（`/resume`、`/name`、会话选择器） | 存会话、搜索/改名/删除 | ◐ 替代 db 的 `sessions` 表 |
| **`pi.appendEntry()`** | 会话内durable、不进模型上下文 | ❌ 单会话，非项目库 |
| **`grep` 工具 / `rg`** | 文件内容搜索 | ✅ 替代 db 的 `pitfalls`/`references_`/`tasks`/`docs` 查询 |

**关键点**：没有 SQLite/向量/索引类原生服务；要"原生查询"只能写**扩展**（反而增加基建，与"入口最少"相反）。

## db 的五张表 → 替代方案

| db 表 | 原用途 | 替代 |
|---|---|---|
| `sessions` | 跨会话轨迹、是否实机 | pi 会话选择器 + `rg '关键词' .pi/sessions/*.jsonl`（原生数据，零基建） |
| `pitfalls` | 关键词找踩坑 | `rg #关键词 PITFALLS.md` |
| `tasks` | 任务状态查询 | `rg` / `TASKS.md` 表格 |
| `references_` | 参考资源索引 | `rg 'url\|关键词' RESOURCES.md` |
| `docs` | 文档清单 | `git ls-files '*.md'` |

也就是说，db 提供的"机器可查"在**文档收敛到 6 份后，`rg` 已经够用**；唯一独有的是预计算的交叉统计，而那正是 `check-doctor.sh` 已经在做的轻量一致性检查。

## 建议：把 db 也一起删掉

- 删除 `db/`（4 个文件）与生成物 `LESSONS.md`；`db/build.py --lessons` 改为**不写根文件**或整体退役。
- `SESSION-INDEX` 内容并入 `RESOURCES.md` 会话轨迹节；会话回忆走 pi 原生选择器 + `rg .pi/sessions`。
- `check-doctor.sh` 保留，但去掉"db 新鲜度"检查（改为纯文本一致性检查）。
- 结果：根文档 12 → **6**（INDEX/DEVICE/TASKS/RUNBOOK/PITFALLS/RESOURCES + AGENTS），且**不再有生成物与第二索引**。

## 顺带一个纠正（关于 HINDSIGHT）

`pi-profile-memory.ts` 的 `readMemory()` 只把每个文件**最后 4–8 KB** 注入系统提示。所以：
- 之前担心的"拆分丢记忆"其实不成立——**只有尾部会加载**，拆成子目录反而更读不到。
- 正确做法是让 `HINDSIGHT.md` **保持小**（主动修剪旧条目），而不是拆分。现在 85 KB 里 90% 永远不进上下文。

---

要不要我把「删 db + 删 LESSONS + 6 份文档合并 + check-doctor 改造」作为


## Automatic settled outcome - 2026-10-03

SDAM 路线确认死亡，但我在 ABL 固件里找到了真正的机制线索。

## 已查明

1. **PMIC SDAM reason 不被采纳**：`reboot recovery` 后 SDAM cell 复位为 `0x00`，设备正常起 Linux（vk34recon）。→ `nvmem-reboot-mode` 这条链对 ABL 无效。
2. **ABL 认的是 DLOAD cookie（TCSR 寄存器）**：`uefi_a` 里有 `DloadCookieAddr / DloadCookieValue / EDLCookieAddr / "ERROR: Failed to set DLOAD cookie"` → 正好对应主线 `qcom,dload-mode = <&tcsr 0x19000>`。这是 **EDL** 的触发点（留档）。
3. **`misc` 在 LUN0 `/dev/sda7`**（boot/recovery 在 LUN4 `/dev/sde`），ABL 按分区名跨 LUN 读，所以 BCB 位置没错。

## 正在做零成本测试：BCB `boot-recovery`

`bootonce-bootloader` 不生效 ≠ `boot-recovery` 不生效（前者是 fastboot 的一次性命令，后者是 recovery 的经典命令）。我已：
- 备份 `misc` → `/root/misc-bak/`
- 写入 `misc` 首字段 = `boot-recovery`（已读回确认）

**请跑一条重启**（普通重启即可，不需要 reason——BCB 会留着）：

```bash
ssh root@192.168.7.1 'sync; reboot -f'
```

预期二选一：
- **进 TWRP** → 这条路通了：Linux 侧只需"写 BCB + 重启"，**零内核改动**，我把它包进 `eldroid-bootctl`。
- **仍进 Linux** → BCB 也被 ABL 忽略。下一步走 **DT-only 修**：给 `pmk8550_pon` 节点加 `mode-recovery = <0x01>`（上游标准写法，`qcom-pon` 驱动本树已编译 `=y`），即改用 **PMIC PON spare** 写 reason；只需重编 DTB 重打包。再不行才移植 PSCI vendor reset。

跑完告诉我进了哪个。


## Automatic settled outcome - 2026-10-03

三连否定后找到正解。汇总与下一步。

## 触发机制结论（全部实测）

| 机制 | 结果 |
|---|---|
| PMIC SDAM `reboot-reason@48`（DT 已绑的 `nvmem-reboot-mode`） | ❌ 不采纳 |
| `misc` BCB `bootonce-bootloader` | ❌ |
| `misc` BCB **`boot-recovery`**（本次新测） | ❌ |
| **TCSR DLOAD cookie** | ✅ 是 **EDL** 的触发点（`uefi_a` 里 `DloadCookieAddr/Value`、`EDLCookieAddr`；↔ 主线 `qcom,dload-mode=<&tcsr 0x19000>`） |
| **PSCI `SYSTEM_RESET2` vendor reset** | ✅ **SM8750 的上游正解**（`mode-bootloader=<0x80010001 0x2>`、`mode-edl=<0x80000000 0x1>`） |

上游正解是个 **13 补丁 / 559 行**的大系列（`psci-reboot-mode`+64bit reboot-mode+PSCI-MFD），**7.2 未合并**；而且它**没有 `mode-recovery`**，只有 bootloader/edl。

## 已交付：`elden/vk41-psci-reboot`（最小钩子）

只改 `drivers/firmware/psci/psci.c` **~35 行**：把 `reboot(2)` 的 reason 字符串映射成 SM8750 的 `SYSTEM_RESET2` vendor reset；**SMC 若返回（固件不支持）就回退普通重启**，不会卡死。正常重启路径不变。

- commit `4b643f169`（基于 `elden/vk34-recon`）
- 镜像 `out/boot-elden-vk41-psci.img`：image sha `f2038fb20f666263`，Image sha `e79dd77f0303b01c`，uname `7.2.0-debug-ge72a036ed4be-dirty`
- 已确认钩子字符串在镜像内核里

## 请你执行

```bash
cd ~/y700-elden
scripts/flash-b.sh out/boot-elden-vk41-psci.img --reboot
# ~30s 后确认在跑新内核：
ssh root@192.168.7.1 uname -r        # 期望 7.2.0-debug-ge72a036ed4be-dirty
# 测试：
ssh root@192.168.7.1 eldroid-bootctl reboot bootloader
```

预期：**真进 fastboot**（主机 `fastboot devices` 可见）。回退主机侧 `fastboot reboot`。
失败（仍进 Linux）：说明 TZ 不接受该 vendor reset，届时再议。
（`reboot edl` 也可测，但退出 EDL 需长按电源或 qdl；你说过 EDL 暂缓，先不动。）

## 注意

- **没有 recovery 的 vendor reset** → `reboot recovery` 不会进 TWRP。以后进 TWRP 的路线 = `reboot bootloader` → fastboot → `fastboot reboot recovery` / 直接刷写。
- 回退基线：`dd` 回 `bootslot-b/boot_b-vk34recon.img`（sha `53e5857a…`）。
- `misc` 里还留着我写的 `boot-recovery`（ABL 忽略、无害），需要的话我帮你还原备份。

跑完告诉我进的是 fastboot 还是 Linux。


## Automatic settled outcome - 2026-10-03

✅ **成功** —— Linux 侧 `reboot bootloader` 真进 fastboot（`HA2EXB0E`，current-slot=b）。PSCI `SYSTEM_RESET2` vendor reset 被 TZ/ABL 采纳，机制坐实。

## 现状与回退

- 设备当前在 **fastboot**。回 Linux：`fastboot reboot`
- b 槽现有内核 = **vk41-psci**（`uname` `7.2.0-debug-ge72a036ed4be-dirty`）；回退基线 `bootslot-b/boot_b-vk34recon.img`
- 已登记：`archive/topics/FLASHCTL-2026-10-03.md` §7–§9、TASKS G1-24、GAPS Q23、DEVICE U2

## 现在可用的 Linux 侧能力

| 命令（设备内） | 结果 |
|---|---|
| `eldroid-bootctl reboot bootloader` | ✅ 实测进 fastboot |
| `eldroid-bootctl reboot edl` | 同机制（`0x80000000/0x1`），**未测**（退出 EDL 需长按电源/qdl） |
| `eldroid-bootctl slot info/active/set-active/mark-successful/set-retry` | ✅ 已验证（GPT attribute） |
| `eldroid-bootctl reboot recovery` | ⚠️ **不行**：上游 sm8750 无 recovery 的 vendor reset |

## 建议下一步（你在 fastboot，正合适）

1. **回 Linux**：`fastboot reboot`
2. **测 TWRP**（recovery_b 已刷 TWRP）：
   ```bash
   fastboot reboot recovery
   ```
   - 进 TWRP → 你的原目标（TWRP 接管）达成；
   - 若起不来 → 说明 TWRP 那 52 MB ramdisk 借的是 `boot` 内核、而 boot_b 现在是 mainline；那就 `fastboot reboot` 回来再议。
3. **可选**：我写个主机侧 `scripts/to-recovery.sh`（`reboot bootloader` → 等 fastboot → `fastboot reboot recovery`），把"进 recovery"包成一条命令。

另外两个未决项仍在：桌面**关机/锁屏**（缺 elogind 守护进程）、熄屏→重启。

先试 `fastboot reboot recovery`？还是先回 Linux？


## Automatic settled outcome - 2026-10-03

## 电源关机：根因已定位并修复，需重启一次生效

**根因（两个叠加）**
1. **只装了 `libelogind`，没装 `elogind` 守护进程** → phosh 关机菜单调 logind 超时（日志 `phosh-session-manager: Failed to shutdown: Timeout was reached`）；且 gnome-session 在**会话启动时**就探测 logind，当时没有 → 缓存 `CanShutdown=false`。
2. `idle-delay=10` + `lock-enabled=true`（上一轮复现熄屏时设的）→ 10 秒熄屏即锁；root 空密码 + phosh 解锁断言失败 → **一直卡锁屏**。

**已做**
| 项 | 结果 |
|---|---|
| `apk add elogind elogind-openrc` | ✅ 已装，`elogind-daemon` 在跑 |
| `org.freedesktop.login1` | ✅ `CanPowerOff`/`CanReboot` = **yes** |
| `start-desktop.sh` 在 phosh-session **之前**启动 elogind | ✅ 已落（持久） |
| `gsettings`：`idle-delay=0`、`lock-enabled=false`、`idle-activation-enabled=false` | ✅ 已设（dconf 持久） |
| 即时解锁 | ✅ `ScreenSaver.GetActive=false`，桌面现在应该可以用了 |
| 内核 `pm_power_off=psci_sys_poweroff` | ✅ 已确认（SYSTEM_OFF 可用） |

**当前 `CanShutdown` 仍是 false** —— 因为 gnome-session 是在 elogind 起来**之前**启动的，缓存了失败。所以要**重启一次**，让 elogind 先于会话启动。

## 请你执行一次重启

```bash
ssh root@192.168.7.1 eldroid-bootctl reboot
```

回来后我验证 `CanShutdown=true`；然后你测**长按电源键 → 关机**（或电源菜单"立刻关机"）。

> 兜底（现在就能用）：`ssh root@192.168.7.1 eldroid-bootctl reboot --poweroff`

若重启后菜单仍不工作，我再把关机直接接到 logind（绕过 gnome-session 的 CanShutdown 门）。另外 TWRP 那次失败已记录在案、不深究。

提交：`20cc135`（elogind+关锁屏）、`79a4327`（TASKS G1-25）。


## Automatic settled outcome - 2026-10-03

第二轮根因找到并处理了。

## 真正卡住关机的原因

重启后 `CanShutdown` 已变 `true`，但**elogind 进程内部卡在「一个 shutdown 操作已在进行中」**：
- 任何 `Inhibit("shutdown", …)` 都返回 `OperationInProgress`（`sleep` 的却正常）；
- 于是 gnome-session / `gsd-power` 的关机路径（先取 shutdown delay inhibitor，再 `PowerOff`）全被拒，表现就是"点了立刻关机没反应"。

**诱因**：elogind 默认 `HandlePowerKey=poweroff`，电源键事件被它抢先�“占位”，与 phosh（持 `handle-power-key` block inhibitor）冲突，留下 in-progress 状态。

**处理**：
| 步骤 | 结果 |
|---|---|
| `kill -9` + 重启 elogind | ✅ `Inhibit("shutdown")` 立即恢复正常（返回 fd） |
| `/etc/elogind/logind.conf` 加 `HandlePowerKey=ignore` / `HandlePowerKeyLongPress=ignore` | ✅ 已落，elogind 不再接管电源键（交回 phosh） |
| elogind 以新配置重启 | ✅ `pid=5343`，`CanPowerOff=yes`，shutdown inhibitor 可获取 |

## 请你现在测一下

**长按电源键 → 「立刻关机」**（应该是真断电了）。
若菜单仍不行，直接测后端：`ssh root@192.168.7.1 loginctl poweroff`。

- 成功 → 我再确认**重启后是否仍有效**（配置已落盘，但 elogind 的启动顺序要复核）。
- 仍失败 → 我绕过 gnome-session：把 gsd-power/电源菜单直接接到 `eldroid-bootctl reboot --poweroff`。

兜底一直可用：`ssh root@192.168.7.1 eldroid-bootctl reboot --poweroff`。

（`logind.conf` 两行 + rootfs 重建须知已记入 `archive/topics/复盘-2026-10-03-持久化与睡眠.md` §6.1，commit `e9d03f9`。）


## Automatic settled outcome - 2026-10-03

整套重构完成并提交（`183477b`）。自检 **FAIL=0 / WARN=0**。

## 结果

| 指标 | 前 | 后 |
|---|---|---|
| 根目录 `.md` | 12 | **6 维护文档 + `AGENTS.md` = 7** |
| 入口 | INDEX + 11 份 | **唯一入口 `INDEX.md`** |
| SQLite/生成物 | `db/` 4 文件 + `LESSONS.md` | **0（全删）** |
| 第二索引 | FILES / SESSION-INDEX / LESSONS / catalog | **0** |
| 会话索引覆盖 | 45/51 | **51/51** |

## 具体动作

**合并（内容零丢失，只降级标题后追加）**
- `GAPS.md` + `ANDROID-COMPAT.md` → **`TASKS.md §5 / §6`**
- `FILES.md` + `SESSION-INDEX.md` → **`RESOURCES.md §3 / §4`**
- `LESSONS.md` 的零号纪律 → **`PITFALLS.md §0`**

**删除**：`GAPS.md`、`ANDROID-COMPAT.md`、`FILES.md`、`SESSION-INDEX.md`、`LESSONS.md`、`db/`（schema/build/README/elden.db）、`archive/sessions-catalog-2026-10-03.jsonl`

**新会话补录**（6 个，全部进 `RESOURCES.md §4`）
- `01a101b5` 问候（junk）
- `01a101bf` AUDIT2：vk34 后增量第二遍 + v1/v2 二分
- `01a101ee` AUDIT3：工具调用审计 + boot_b=vk40 混淆
- `01a101f3` Linux→fastboot 能力核实（后被推翻）
- `01a1021c` **PSCI vendor reset 实测进 fastboot + elogind 关机修复**
- `01a10224` 本次架构整理

**重写** `scripts/check-doctor.sh`：去掉 db 检查，改为「会话覆盖 / 死链 / 过期字样」三项，当前全绿。

## 现在的终态

```
y700-elden/
├── INDEX.md              ← 唯一入口（使命/分层/现状/命令/专题地图）
├── DEVICE.md             设备描述+状态
├── TASKS.md              任务/进度/未解(§5)/G2方案(§6)
├── RESOURCES.md          参考/本地资源/资产台账(§3)/会话索引(§4)
├── RUNBOOK-BRINGUP.md    上机手册
├── PITFALLS.md           零号纪律(§0) + 踩坑 #1–#88
├── AGENTS.md             pi 项目指令
├── scripts/check-doctor.sh
└── archive/              证据层（只增不改）
```

查询方式变为：`rg` 搜文本、pi 原生 `/resume` 找会话、`rg .pi/sessions` 搜轨迹——**无自建索引**。

> 说明：`.pi/memory/HINDSIGHT.md` 仍保持未提交（它是 harness 自动追加的活跃记忆，与本轮整理无关）；你刚定的「入口越少」偏好已存入项目记忆。


## Automatic settled outcome - 2026-10-03

完成并提交（`bea4c1b`），自检 FAIL=0 / WARN=0。

## 一、git 追踪审计

**结论：所有 durable 文本本来就在 git；漏网的是 `backup/` 下的"证据文本"，已补进。**

| 类别 | 状态 |
|---|---|
| 文档、脚本、内核补丁/config、`.pi/memory`、`.pi/skills`、`.pi/missions`、`archive/`、`AGENTS.md` | ✅ 早已 track |
| **`backup/` 证据文本**（本次新纳入） | `elden-dump.txt`、`HA2EXB0E-16+512/{getvar-locked,getvar-unlocked-1.1,gpt-list-pre-surgery,vk40-ram-acceptance-dmesg}.txt`、`pre-unlock/` 全部基线（getprop/by-name/sensorservice/packages/settings…）+ `SHA256SUMS` |
| 仍 ignore | 二进制分区/GPT dump、`sn-neko-zuxos.img`（含签名 blob，敏感）、`sn.img` |

git 追踪文件数 **306 → 316**。

**仍被 ignore 的"文本但运行时/大"**（需你拍板是否要）：
- `.pi/sessions/` **54 M**（51 个会话 jsonl，即 `RESOURCES.md §4` 的原始素材）
- `logs/` **90 M**（串口/构建/agent 日志）
- `.pi/messenger/`（swarm 运行时任务卡）
- `backup/pi-assets-*`、`flashing-bundle/`（迁移快照，内容已在 `.pi/`）

> 我倾向**不**把 sessions/logs 入 git：体量大且可能含工具输出里的敏感信息；会话已有 `RESOURCES.md §4` 索引 + pi 原生会话文件。要不要纳入，你说一句。

## 二、过时/废弃/功能缺陷列表

放在 **`PITFALLS.md §15（DEPRECATED）`**（不新增根文件，维持"入口最少"），git 管理。五个子表：

| 子节 | 内容 |
|---|---|
| **15.1 废弃/合并/删除的文档** | GAPS/ANDROID-COMPAT/FILES/SESSION-INDEX/LESSONS/db/catalog 各自的"现在看哪" |
| **15.2 迁移/退役的外部资产** | `~/y700类原生安卓/` 退役、profile/技能/会话内聚迁移、迁移前备份与 flashing-bundle |
| **15.3 被取代/无效的会话** | 3 个 superseded（`01a0ed5b`/`01a100d9`/`01a101f3`）+ 5 个 junk（空/测试会话） |
| **15.4 技能参考中过时结论** | `grub-uefi-dual-boot.md`（sn.img 解锁已失效）、`tb321fu-*`（Gen3 勿套 Gen4）、两份 `community-tool-status-2026-08`、`gsi-device-adaptation/*`（a 槽路线已弃） |
| **15.5 已知功能缺陷** | 12 项（熄屏重启、vk34 回归、音频/相机/TF/BT/DP/NFC/CDSP、reboot recovery 无解、reboot edl 未测、60 Hz 黑屏）各带权威指针 |

已同步：`INDEX.md §2` 标注 PITFALLS 含 §15；`check-doctor.sh` 的过期字样扫描**排除 PITFALLS**（§15 故意登记旧文件名），其余活跃文档仍严格查。

---

两个待你决定：**①`.pi/sessions`/`logs` 是否入 git？②§15 是否要单独拆成 `DEPRECATED.md`？**（我建议都保持现状：不入 git / 不拆，以符合"入口最少"。）


## Automatic settled outcome - 2026-10-03

复查完成，找到真根因并已修复（**与 vk41 内核无关**）。

## 结论（数字先行）

| 项 | 结果 |
|---|---|
| 真根因 | elogind 的 helper `/sbin/{poweroff,reboot,halt}` 是 **busybox applet**，**不带 `-f` 时根本不调 `reboot(2)`** |
| 实证 | `strace`：`poweroff` → `kill(1, SIGUSR2)` 后 **exit 0**（`reboot`/`halt` 同理 SIGTERM/SIGUSR1）；dmesg 有 `System is powering down.` 却**从无 `reboot: Power down`** |
| 为什么无效 | 本机 **PID 1 = `/bin/sh /init`**（不是 busybox-init），不处理这些信号 → 关机假成功 |
| 连带假死 | elogind 对 poweroff/reboot/halt 这类**非 sleep** 动作不清 `delayed_action` → 之后所有关机都回 `OperationInProgress`（phosh 菜单"无反应"就是这个） |
| 修复 | `/sbin/{poweroff,reboot,halt}` 换成 `busybox <applet> -f` 包装 → 直调 `reboot(2)`，`strace -e inject` 已验证 |

> 前一轮把根因归给"电源键被 elogind 占位"，只 `kill -9` 治了症状；这次是**真根因**。v41 只改 `psci_sys_reset`，不碰 POWER_OFF。

## 已落地

- 设备已装：`/sbin/{poweroff,reboot,halt}` 包装脚本 + `/usr/local/sbin/fix-logind-poweroff.sh`；`start-desktop.sh` 启动 elogind 前调用（幂等，**在 `/dev/sda17` 上持久**）。
- 仓库提交 `47c14aa`：脚本 + `PITFALLS #89` + `archive/topics/LOGIND-POWEROFF-2026-10-03.md` + TASKS/DEVICE/RESOURCES。`check-doctor` **FAIL=0/WARN=0**。
- elogind 当前是排查用的 debug 实例（状态干净，`PreparingForShutdown=false`）；重启后由 start-desktop.sh 正常拉起。

## 请你做真机验证（关键最后一步）

**测试 1（后端，最直接）**：
```bash
ssh root@192.168.7.1 loginctl poweroff
```
预期：设备**真断电**（屏幕灭、SSH 断）。再按电源键开机。

**测试 2（你的原目标，电源键）**：
长按电源键 → phosh 电源菜单 → 点「立刻关机」→ 真断电。

> 回退：若真断电失败而设备卡住（PSCI `SYSTEM_OFF` 极少数固件不支持会转 `machine_halt` 自旋），长按电源键硬复位即可。

跑完告诉我结果。成功的话我把 G1-25 标 ✅ 收口。


## Automatic settled outcome - 2026-10-03

收口完成 ✅

## 结论

**电源键关机已跑通**：长按电源键 → phosh 菜单 →「立刻关机」= **真断电**。重启后包装脚本仍在（`start-desktop.sh` 开机幂等重装，落在 `/dev/sda17`，已实测）。

## 真根因（与 vk41 内核无关）

| | |
|---|---|
| 机制 | elogind 执行 `/sbin/{poweroff,reboot,halt}`（编译期绝对路径） |
| 缺陷 | 这些是 busybox applet，**不带 `-f` 只给 PID 1 发信号**（`SIGUSR2/TERM/USR1`）后 exit 0 |
| 后果 | 本机 PID 1 是 `/init`（shell，不处理）→ 关机假成功，且 elogind 永久卡 `OperationInProgress` |
| 修复 | 换成 `busybox <applet> -f` 包装 → 直调 `reboot(2)`（`strace -e inject` 已证） |

## 一个边角（已记录）

`loginctl poweroff` 在 **USB 连着时**会让设备立即重启——你判断为平板探测到数据线插入（VBUS/充电检测自动开机），这是独立行为，不是 elogind 的问题。**正式关机先拔 USB** 即可。

## 提交

- `47c14aa` 真根因定位+修复（脚本/`PITFALLS #89`/专题/TASKS）
- `1be1acf` G1-25 真机验证通过 + USB 边角
- `check-doctor` **FAIL=0 / WARN=0**

G1-25 已标 ✅ 收口。下一个待办回到未解项：**「熄屏→整机重启」**（G1-22/Q21）和 **vk34 后增量回归二分**（G1-23/Q22）。


## Automatic settled outcome - 2026-10-03

日志采集方法已就位（`scripts/devlogs.sh`，已提交 `18bbf08`）：

| 子命令 | 用途 |
|---|---|
| `pull [tag]` | 单次 SSH 抓设备快照（`dmesg`、`/run/*.log`、`/var/log/kmsg`、`pstore`、uname/boot_id/uptime/power）→ `logs/devlogs-<tag>-<ts>/` |
| `watch [秒] [间隔]` | 周期 pull，并靠 `boot_id` 变化**自动标记复位**（抓"熄屏→重启"这类瞬时事件） |
| `pstore` | 读 ramoops 崩溃日志（survives 复位，无需设备侧写入器 → 无观察者效应） |
| `tail` / `serial` | 实时 dmesg / 主机串口 `/dev/ttyACM0` |

冒烟已通过。顺带一个日志发现：**vk41 的 `CONFIG_SUSPEND` 未开** → `/sys/power/mem_sleep` 不存在、`/sys/power/state` 为空（suspend 被整个拿掉了），这本身就是个待确认的改动。

不过——**"这两个改动"具体指哪两项？** 我不敢猜错，列几个候选请你点一下：

1. **logind 电源**：`HandlePowerKey=ignore` + `/sbin/{poweroff,reboot,halt}` 包装（本轮已验关机；短按熄屏/唤醒还未单独验）
2. **vk41 PSCI**：`reboot bootloader` / `reboot edl` 两个 vendor reset（只验了 bootloader，edl 未测）
3. **G1-23 二分**：`vk34-recon` ↔ `vk40` 两个内核版本/增量是否正常
4. **G1-22**：熄屏→重启 的修复改动

你指哪两个？（如果是别的，直接说改动内容即可。）确定后我就用 `devlogs.sh` 建基线、跑对照、出功能验证结论。


## Automatic settled outcome - 2026-10-03

已就绪。**vk42 = 当前 vk41（含 PSCI）＋ 干净重落这两项改动，不带 vk40 调试插桩**，已编译并校验内容：

| 项 | 证据 |
|---|---|
| 产物 | `out/boot-elden-vk42.img`（sha256 `40c87976…`，83 MB） |
| 内核 | `7.2.0-debug-geb432f18a0d1`（唯一 uname，便于版本归属）；含 `q6i2s_prepare` 符号、**0 处 DBG** |
| 音频修复 | `q6apm.c` 3 处改用 `audioreach_alloc_apm_cmd_pkt`；`q6apm-lpass-dais.c` 加了 `q6i2s_prepare`（BE graph 在 prepare 起） |
| 温控 | DTB 四级 trip `0x11170/0x14050/0x15f90/0x19a28` = **70/82/90/105 ℃**（当前 vk41 是单级 105） |
| tplg | ramdisk + 持久 root 都是自定义 10436 B 版（音频前提具备） |

## 请你刷入（设备侧断联操作，你来执行）

```bash
cd ~/y700-elden
scripts/flash-b.sh out/boot-elden-vk42.img --reboot
```
约 1–3 分钟回 SSH。**回退**：`scripts/flash-b.sh out/boot-elden-vk41-psci.img --reboot`

> 我也可以只跑"写入+回读校验"（不重启），你再单独重启——你选。
> 注意：这两项正是"熄屏→重启"的**嫌疑增量**，刷回后可能重现；我会用 `devlogs.sh watch` 盯 `boot_id`。

## 刷好后我来跑验证

- **温控**：`/sys/class/thermal/*/trip_point_*` 应现 70/82/90/105；跑 `thermal-stress.sh` + `thermal-watch.sh`，出稳态温度/频点与 cdev state。
- **音频**：`amixer -c0 cset numid=8 on` + `speaker-test`；抓 `dmesg` 的 q6apm 图状态（`GRAPH_OPEN/START status`），**由你确认是否出声**。
- **回归监控**：全程 `devlogs.sh watch`，捕捉熄屏/复位。

要我现在就把 vk42 写入 boot_b（不重启）吗？还是你直接跑上面那条？


## Automatic settled outcome - 2026-10-03

温控侧已确认生效；音频侧技术上链路是通的（MI2S bclk 在走），且发现两个功放音量 `numid=1/2` **默认是 0**（可能原来就没声）。我刚把它拉到 1023 并播了 8 秒 1 kHz 正弦。

**关键问题：你刚才听到扬声器出声了吗？**（1 kHz 蜂鸣/正弦音）

同时把目前证据汇总如下：

## 温控 ✅（功能正常）

| 检查 | 结果 |
|---|---|
| CPU/GPU 热区 trip | 全部 `120000 125000 70000 82000 90000 105000`（hot/critical + 四级 passive）|
| cooling device | `cpufreq-cpu0` 0/15、`cpufreq-cpu6` 0/15、`devfreq-3d00000.gpu` 0/13 |
| 空闲温度 | CPU 38–44 ℃ |

下一步我会跑 `thermal-stress.sh` + `thermal-watch.sh`（约 6 min），看四级 trip 是否按预期逐级降频。

## 音频 ◐（链路通、待听声）

| 检查 | 结果 |
|---|---|
| 声卡/控件 | `Lenovo-Y700-Gen4`；`numid=8` MM1→SECONDARY_MI2S_RX 路由 ✅ |
| **`SEC_MI2S_IBIT` 时钟** | **enable=1 / 1.536 MHz，consumer `dai@12` bclk** ← 0011 修复的直接证据 |
| PCM | state=RUNNING，指针推进 |
| dmesg | 无 q6apm graph 报错；仅有 `wsa_macro … flat cache` 无害告警 |
| 音量 | `Left/Right Playback Volume` 默认 **0**，已拉到 1023 |

## 一个已确认的"非回归"

`dmesg` 里 boot 6.8 s 的 `qcom-apm … CMD timeout for [1001021] opcode` 在 **vk41 也有**（vk41 快照里有 5 处），不是 vk42 引入的。

> 另外这两项正是"熄屏→重启"的嫌疑增量。要不要我同时开 `devlogs.sh watch` 盯 `boot_id`，边测边抓？


## Automatic settled outcome - 2026-10-03

修复已提交（`31cde62`）。新 boot 镜像已就绪：

| 项 | 值 |
|---|---|
| 产物 | `out/boot-elden-vk43.img`（sha256 `f3e53fe4…`，83 MB） |
| 内容 | vk42 + **tplg SD 线修正**（SD0→SD1，`db7e16e7…`，已同时写入 ramdisk 和持久 root） |
| 内核 | 同 vk42（`geb432f18a0d1`，音频 0009/0011 + 温控 0010 都在） |

## 请你刷入

```bash
cd ~/y700-elden
scripts/flash-b.sh out/boot-elden-vk43.img --reboot
```
回退：`scripts/flash-b.sh out/boot-elden-vk42.img --reboot`

> 理论上这一步**必须冷启**（运行期重载 tplg 会 ADSP 图残留，文档已记）。刷好回 SSH 后我来开 mixer、音量拉满、放测试音，**由你听声**。

## 这次修复的根据

- 功放 I2S 数据脚 = `gpio124 = i2s1_data1`（**SD1**），主 DTS 与原厂 DT dump（`probe/result/devicetree.dts`）**完全一致**。
- 但 tplg 是从 Google SC7180 SEC-I2S 模板抄来的 `SD_LINE_IDX_I2S_SD0`（=值 1），ADSP 便往 SD0/gpio122 发数据 → 功放挂在 SD1 收不到。
- 证据链：整条 DAPM 图全 On、`SEC_MI2S_IBIT` 时钟 1.536 MHz 在走、功放未静音/音量最大且 PLL+ready 就绪，**但 SYSST 的 SWITCHING 位不置位**（无输入信号）= 数据没到功放。

刷好后我来跑验证；若仍无声，下一步查 WORDSELECT/数据格式或功放 I2SCTRL。

> 另：设置界面输入输出设备为空是**独立问题**（系统里没装 PipeWire/PulseAudio 守护进程，只有库）。ALSA 出声确认后再装音频服务补上 UI。


## Automatic settled outcome - 2026-10-03

收口完成 ✅

## 结果

| 改动 | 状态 | 关键证据 |
|---|---|---|
| **温控**（0010，四级 trip） | ✅ 功能正常 | 所有 CPU/GPU 热区 `70/82/90/105 ℃`；cdev `cpufreq-cpu0/6`、`devfreq-gpu` 就位 |
| **音频**（0009/0011 + tplg SD 线） | ✅ **出声** | `SEC_MI2S_IBIT` 1.536 MHz；功放 SYSST `0x0215`→**`0x2315`（SWITCHING 置位）** |

**过程要点**：
1. 这两项在原 vk41 里被 `vk34-recon`（隔离熄屏重启）整批回退 → 新分支 **vk42** 干净重落（`geb432f18a0d1`），保留 PSCI。
2. 音频图全通但无声，真根因不在内核改动，而在 **tplg 的 MI2S SD 线抄错**：功放接 `gpio124=i2s1_data1`（SD1），tplg 却用 SD0 → ADSP 往 gpio122 发。改 `SD_LINE_IDX_I2S_SD1` 后出声（**vk43**）。
3. tplg 在 boot 早期从 initramfs 加载，故用**字节级替换**改了 ramdisk + 持久 root。

**提交**：`31cde62`（tplg 修复）、`cddb1ca`（收口：`PITFALLS #90`、`archive/topics/AUDIO-SDLINE-2026-10-04.md`、TASKS/DEVICE/RESOURCES）。`check-doctor` **FAIL=0/WARN=0**。当前设备 = vk43。

## 剩余待办（音频侧）

- **UI/应用音频**：系统只装了 `pipewire-libs`/`libpulse`（库），没有音频服务守护进程 → 设置界面"输入输出设备"为空。需装并启用 **PipeWire + WirePlumber**（或 PulseAudio）。
- 左/右两片 AW88461 分别验证、录音通路。
- 「熄屏→重启」仍未解（本轮 vk42/vk43 暂未复现）。

下一个做哪个？我建议先把 **PipeWire/WirePlumber** 装上（让设置界面和浏览器等应用有声音），这是"功能健全"的必要一块。


## Automatic settled outcome - 2026-10-03

音频这块收口完成 ✅

## 结果（冷启持久已验证）

| 项 | 状态 |
|---|---|
| ALSA 出声 | ✅（tplg SD1 修正） |
| **桌面音频服务** | ✅ **PipeWire + WirePlumber + pipewire-pulse**，由 `/etc/xdg/autostart` 自启 |
| **输出设备** | ✅ `Active Profile=HiFi`，sink = `HiFi__Speaker__sink`（GNOME 显示 **"Built-in Audio Speaker playback"**） |
| UCM2 | ✅ `scripts/audio-ucm/`（自动开 `numid8` 路由 + 抬功放音量；`start-desktop.sh` 幂等安装） |
| 输入设备 | ❌ **仍缺**：本卡只有 Secondary MI2S 播放 DAI，`arecord -l` 为空 |

提交：`9934f7b`（PipeWire+UCM）、`34394bc`（文档收口）。`check-doctor` FAIL=0/WARN=0。

## 建议先确认一步

请打开 **设置 → 声音**，应能看到输出设备「Built-in Audio Speaker playback」，并可播放测试音。看一眼对不对。

## 下一步（二选一）

1. **补麦克风/录音（输入设备）**：需要在机器驱动加 capture DAI（VA/TX macro → DMIC）、tplg 加采集子图、内核配置补齐——是新一轮 bring-up（中等工作量），做完"输入输出设备"就齐了。
2. **回到「熄屏→重启」**（G1-22，稳定性阻塞）：用 `devlogs.sh watch` 抓 `boot_id` 做长时窗复现与定位。

你说哪个，我就开工。（也可以先只做个小验证：用 `arecord` 确认确实无 capture PCM。）


## Automatic settled outcome - 2026-10-03

vk44 就绪（含 DMIC capture）。**请你刷入**：

```bash
cd ~/y700-elden
scripts/flash-b.sh out/boot-elden-vk44.img --reboot
```
回退：`scripts/flash-b.sh out/boot-elden-vk43.img --reboot`

| 项 | 值 |
|---|---|
| 镜像 | `out/boot-elden-vk44.img`（sha256 `001516a0…`） |
| 内核 | vk43 + **VA capture dai-link**（cpu=`VA_CODEC_DMA_TX_0`/110，codec=`lpass_vamacro`）+ VA macro **DMIC pinmux**（dmic01+dmic23，4 麦） |
| tplg | 加采集子图：FE **MultiMedia3** → **VA codec-DMA TX0** → DMIC（10436→15380B，ramdisk 已重打包） |

## 依据（与上游 SM8750-MTP 完全同构）

- 原厂 DT 已有 `dmic01-default-state`/`dmic23-default-state`（gpio6-9）+ VA macro 节点 → 硬件是 **4×DMIC 接 VA macro**。
- 主线 `sm8750-mtp.dts`：`&lpass_vamacro { pinctrl-0 = <&dmic01_default>, <&dmic23_default>; }` + `va-dai-link`（`VA_CODEC_DMA_TX_0`）。
- DMIC 的 mux/DEC 选择由 UCM `cset` 完成（`codecs/qcom-lpass/va-macro/DMIC0/1EnableSeq.conf` 模板已有）。
- macro 驱动（`VA/TX/RX/WSA_MACRO=y`）本就编进内核。

刷好回 SSH 后我查 `arecord -l` 与卡 link，再补 UCM 的 `Mic` 设备并现场录一段验证。


## Automatic settled outcome - 2026-10-03

## 两个问题的诊断结果

### ① 音频输入端：ALSA 已通，差最后两步

| 检查 | 结果 |
|---|---|
| **采集 PCM** | ✅ `arecord -l` 出现 `device 2: MultiMedia3 Capture`（vk44 的 DTS+tplg 生效）|
| 设置界面看不到 | 缺 **UCM Mic 段**（已补 `scripts/audio-ucm/HiFi.conf` 并部署到设备）|
| 录音全 0 | ❌ 根因：**`vdd-micb` 偏置 = Off**（DAPM 实测）→ 缺 `vdd-micb-supply` + `"VA DMIC0..3","vdd-micb"` 路由 |
| 修法 | 已补进 DTS（对齐上游 MTP：`vreg_l1b_1p8` + `qcom,dmic-sample-rate=4800000`）→ **vk45** |

另外 debug 时发现：**`numid=15 MultiMedia3 Mixer VA_CODEC_DMA_TX_0` 默认 off** 会让 `arecord` open 直接 EINVAL——UCM 的 Mic 段已含这条 `cset`。

**vk45 已就绪**：`out/boot-elden-vk45.img`（sha256 `f46de05d…`）。回退 vk43/vk44。

### ② 马达反馈：硬件正常，是 feedback profile 的问题

- **硬件好**：直接调 `org.sigxcpu.Feedback.Haptic.Vibrate` 返回 `true`（应已震）。
- 原因：feedbackd 的 **profile = "full"**（默认），而默认主题里 `full` 只映射 **Sound**，Vibra\*（震动）只在 **"quiet"** profile 里。
- 已修：`gsettings set org.sigxcpu.feedbackd profile quiet` + 重启 feedbackd → 现在 `Profile=quiet`。**按键应当有震动了**（quiet = 震动代替声音；两者不能同时对同一事件）。

> 所以不是包缺失（`feedbackd`/`feedbackd-device-themes` 都在）。若你想要"震动+声音"同时，需要给本机写一个自定义 device theme（feedbackd 每个事件只能一种类型，得权衡）。

## 请你刷入（修麦克风）

```bash
cd ~/y700-elden
scripts/flash-b.sh out/boot-elden-vk45.img --reboot
```

刷好回 SSH 后我验证：`arecord` 录一段（应非静音）+ 设置界面出现麦克风输入设备。同时你可试试按键震动是否回来了。


## Automatic settled outcome - 2026-10-03

**找到"没有 input"的真正原因了**——麦克风根本不是 DMIC。

## 关键发现（原厂设备树 `backup/stock-elden/elden.dts`）

原厂 `sound` 节点的 `qcom,audio-routing`（line 16249）里**全是模拟麦，没有一条 "VA DMIC"**：

```
"AMIC1","Analog Mic1","AMIC1","MIC BIAS1",  ... "AMIC5","MIC BIAS4",
"VA AMIC1","Analog Mic1","VA AMIC1","VA MIC BIAS1", ...
"VA SWR_INPUT","WCD_TX_OUTPUT", "VA_AIF1 CAP","VA_SWR_CLK", ...
```

- 本机音频栈 = **Awinic smart PA（I2S 功放，我们已打通）+ WCD939x 编解码器**（SoundWire TX/RX）。
- 麦克风是**模拟麦（Analog Mic）**，偏置由 **WCD939x 的 MIC BIAS1–4** 提供，ADC 在 WCD 里，经 **SoundWire** 送给 ADSP。
- **主线 DTS 里没有启用 WCD939x**（只有 I2S 的 aw88461 功放）。

### 这解释了我们所有现象

| 观察 | 解释 |
|---|---|
| ALSA `MultiMedia3 Capture` 出现、整条 APM/DAPM 图 On | 图/软件链路没问题 |
| `vdd-micb` 加了我们 DTS 的 `vreg_l1b_1p8`，regulator 也 enabled | 但硬件上根本没接 DMIC，偏置来源也应是 WCD |
| 4 个 DMIC 通道全 0 | **硬件没有 DMIC 麦**（原厂 routing 里也没有） |

> 所以 vk45 的 DMIC 方向是错的（软件对、硬件不对）。要出声必须走 **WCD939x**。

## 可选路线

**A. 上 WCD939x（正确路线，中等偏大工作量）**
镜像主线 `sm8750-mtp.dts` 的 WCD939x 配置移植：
1. DTS：`wcd939x` 节点（SWR slave + `cdc-vdd-rx/tx/buck/px/mic-bias` 稳压 + reset GPIO + pinctrl）+ 启用 rx-macro / va-macro 的 SWR master。
2. 加 `wcd-capture-dai-link`（cpu `TX_CODEC_DMA_TX_3`，codec `wcd939x`+`txmacro`）。
3. tplg 加 WCD 采集子图；UCM 加 Mic。
4. 稳压映射照原厂（`L15B`=WCD vdd、`BOB1`=mic-bias）。

**B. 先用 USB/Type-C 或蓝牙麦兜底**（当前可用，快速让"输入设备"不为空）。

## 顺带：haptics 已定位（不是包缺失）

- 硬件正常（`Haptic.Vibrate` 返回 true）。
- 原因：feedback profile='full'（默认，只映射 Sound）。**已设 `org.sigxcpu.feedbackd profile=quiet`**（震动代替声音）。

> 想要 LineageOS 那种"声音+震动强度分开"：feedbackd 每个事件只能一种类型（Sound **或** Vibra）。要两者兼得，需要写自定义 device theme（例如按键走 Vibra、其他走 Sound），并可用 `max-haptic-strength` 调强度——可以做，但要权衡。

**要我开始做 A（WCD939x）吗？** 这是麦克风/耳麦正路。或者先做 B 兜底、再排期 A？


## Automatic settled outcome - 2026-10-03

收到——**input 未打通，到此停下**。

## 技术报告已落盘

- `archive/topics/AUDIO-INPUT-2026-10-04.md`（本日全量技术报告）
- 提交 `5d70996`；`check-doctor` **FAIL=0/WARN=0**

## 结论汇总

| 项 | 状态 | 一句话 |
|---|---|---|
| **音频播放** | ✅ | 真根因＝tplg MI2S **SD 线错**（SD0→SD1），修 tplg 后出声（vk43） |
| **桌面音频** | ✅ | PipeWire+WirePlumber+UCM2 → "Built-in Audio Speaker playback" |
| **温控** | ✅ | 四级热 trip 70/82/90/105 ℃ + cdev 生效（vk42） |
| **音频输入** | ❌ **未打通** | **本机麦克风是模拟麦接 WCD939x，不是 DMIC**；主线 DTS 未启用 WCD939x |
| **按键震动** | ◐ | 硬件正常；根因 profile='full'，已设 **quiet** |
| **日志方法** | ✅ | `scripts/devlogs.sh` |

## 输入未通的根因（关键）

原厂设备树 `backup/stock-elden/elden.dts` 的 `qcom,audio-routing` **全是 `AMIC*`/`VA AMIC*` + `MIC BIAS*`，没有一条 `VA DMIC`**：

- 本机音频栈 ＝ Awinic smart PA（I2S，已通）＋ **WCD939x 编解码器（SoundWire）**；
- 麦克风偏置来自 **WCD939x 的 MIC BIAS**，ADC 在 WCD，经 SWR 送 ADSP；
- 我们按上游 MTP 做的 VA DMIC 采集虽然 **ALSA/APM 图全绿**（`MultiMedia3 Capture`、DAPM 全 On、`vdd-micb` On、寄存器正确），但硬件无 DMIC → 录音恒 0。

⇒ 正路是 **WCD939x bring-up**（镜像 `sm8750-mtp.dts`：wcd939x + rx/va SWR master + 稳压 + capture dai-link + tplg + UCM），**本轮未做**。

## 设备当前状态

- 内核 **vk45**（`7.2.0-debug-g26cc186e9485-dirty`），播放正常（HiFi 扬声器 sink）。
- 期间 UCM 加 `Mic` 段曾弄坏 HiFi verb，**已撤回并重启恢复**（`PITFALLS #91` 已记这个坑）。

停止。下一步若要继续，从 **WCD939x bring-up** 开工。


## Automatic settled outcome - 2026-10-04

## 项目进度快照（实测 + 文档核对）

**设备实测（U2，刚 SSH 确认在线）**
| 项 | 实测值 |
|---|---|
| 内核 | `7.2.0-debug-g26cc186e9485-dirty` = **vk45** |
| 持久根 | `/dev/sda17` ext4 ✅ |
| 运行时长 | **up 7h20m**（当前无重启环） |
| 采集 PCM | `MultiMedia3 Capture` 在，但录音恒 0（硬件是模拟麦→WCD939x，非 DMIC） |
| adb/fastboot | 空（U1 未接入） |

**目标完成度**
| 目标 | 完成度 | 本轮变化 |
|---|---|---|
| **G1** | **≈82%**（22 ✅ / 3 🟡 相机·TF·BT / 3 ⬜ DP·NFC·CDSP） | 音频**播放**听声 ✅、桌面 PipeWire+UCM2 ✅、温控四级 ✅、关机/重启 ✅ |
| **G2** | ≈45%（C4 代码全就绪待上机、C9 用例定稿） | 无 |

**硬缺口（4 个）**：① 音频**输入**（WCD939x，正路未做，v45 DMIC 方向已证伪）② 相机出流 ③ TF 卡写稳定 ④ BT 配对收口。
**稳定性阻塞**：熄屏→重启（G1-22，源锁定在 vk34 后 5 文件增量，未根治，靠禁空闲熄屏规避）。

## 文档漂移（已发现，需收口）

- `INDEX.md §3`：仍写"vk40 未上机 / 无单元在机 mainline / 剩 4 缺口含音频听声"——**过时**（现 U2=vk45）。
- `TASKS.md §0`：进行中仍列"音频听声"——**过时**（G1-4 已 ✅）。
- `check-doctor`：**WARN=1**（会话 jsonl 53 ≠ 索引 52）。
- `.pi/memory/HINDSIGHT.md` 有**未提交**改动。

## 下一步规划（按性价比排序）

**P0 · 零设备成本（本会话即可做完）**
1. 文档收口：改 `INDEX §3` + `TASKS §0` 数字，`RESOURCES §4` 补第 53 会话，提交 HINDSIGHT，跑 `check-doctor` 到 FAIL=0/WARN=0。

**P1 · 占 U1（"覆盖 a 槽前不可复得"，越早越值）**
2. **C0 真 Android 对照取证 + Q13 AVF 资产复采**：U1 仍 stock+root。`getprop` 全量 / Widevine 级别 / 7 传感器采样 CSV / 目标 App 录屏 + AVF APEX 解包。这是兼容层的"标准答案"，U1 一旦动手术就没了。

**P2 · 占 U2（主线技术攻坚，二选一）**
3. **WCD939x bring-up（音频输入正路）**：镜像 `sm8750-mtp.dts` 的 wcd939x + rx/va SWR master + 稳压 + capture dai-link + tplg + UCM。中等偏大工作量，是你上轮定的下一步。
4. **G1-22 熄屏→重启根治**：现 uptime 7h20m 稳定（规避生效），但要日常可用必须解；可在有带外串口+EDL 回退前提下做 vk34→vk40 五文件二分（已有 V1/V2 镜像）。

**P3 · 常规缺口**：G1-5 相机出流（只差 config/部署）→ G1-6 TF 卡 → G1-7 BT。

**我的建议**：先 **P0 收口（10 分钟）**，然后 **P1（U1 取证，过期作废）**——趁 U1 还是 stock，把不可复得的东西先采下来；之后回 U2 攻 **WCD939x**。

要我先执行 P0 收口吗？或者你直接指定 P1/P2 哪条开工。
