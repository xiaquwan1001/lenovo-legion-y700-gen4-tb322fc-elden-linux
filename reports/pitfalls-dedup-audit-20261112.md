# PITFALLS 去重审计（2026-11-12）

> 只读审计产物。范围：`PITFALLS/README.md`、`PITFALLS/sessions/*.md`、`.pi/memory/{MEMORY,failures-device,failures-kernel,notes-display,USER}.md`。
> 本文件不由 PITFALLS 索引登记（审计报告，非条目）。

## §0 结论先行

**计数（本轮实测，全部可复现）**

| 类别 | 数量 | 说明 |
|---|---|---|
| §A 重复条目组 | **13 组 / 约 70 处落点** | 其中 3 组是「同一判据被写 ≥4 遍」的重灾区：`pkill -f` 自匹配（**18 个副本**，全库提及 24 行）、RAM 启动未部署模块树（5 处）、`dpms` 只读（4 处，且 1 处权限值写错） |
| §B 回归/被推翻未标记 | **9 条** | 最危险 2 条：`#617`（已被 `#620` 否证但标题仍肯定）、`#558`（同样被 `#620` 收紧，正文零标记） |
| §C 编号/索引健康 | **9 项**（P0×3、P1×3、P2×3） | 最硬的一条：**6 个编号被跨文件重复定义**（#53、#192、#282、#283、#284、#285），而 `check-doctor` 报「编号无撞车 ✅」= 假绿；长度门/悬空门的漏判则集中在 `s07-08-docs.py:116,161` 一处条件 |

**四条最重要的判断（先说结论）**

0. **存在真实的编号撞车（P0，机器全绿）**：`#53`、`#192`、`#282`、`#283`、`#284`、`#285` 各被**两个不同文件的不同教训**定义为条目；另外 `#286`–`#289` 只有「`## 286. ★★`（数字前无 `#`）」这一种**不受门覆盖**的写法。`check-doctor --only 8` 仍报 `文件名/条目编号无撞车 ✅`。证据见 §C-0，修法见 §D-批次4（**只让「后到的那份」让位**，与 §15.7 的 `#166→#154`/`#217→#257` 先例同法，不做全局重排）。

1. **`PITFALLS/README.md` 的索引已经悄悄变成「正文的替代品」**：228 条带编号的索引行里，**36 行的「正文」列指向 `../reports/*.md`**；这 36 行覆盖的 **27 个 `#NNN` 在 `PITFALLS/sessions/` 里既无标题定义、也无粗体引用**（例：`#527–#533`、`#579–#592`、`#603–#608`）。它们躲过了 `check-doctor` 的两道门（长度门 + 悬空门），因为两道门都要求该行含字符串 `sessions/`（证据：`scripts/doctor/s07-08-docs.py:116` 与 `:161`）。**这直接违反 README 自己第 8 行的定义**（`PITFALLS/README.md:8`：「条目唯一性 = 每个 `#NNN` 在 `sessions/*.md` 里只被定义一次」）。
2. **索引行长度门（≤800 B）当前形同虚设的一半**：含 `sessions/` 的 247 行全部 ≤800 B（最长 800 B），但**指向 reports 的 12 行 802–1093 B** 完全不被检查（最长 `README.md:277` = 1093 B）。超长行 = 结论只写在索引、正文不存在 → 必然与后续复测漂移（本轮 §B 的多条就是这么产生的）。
3. **重复的主战场不在 `PITFALLS/sessions/`，在 `.pi/memory/`**：`pkill -f` 自匹配这一个判据在 `.pi/memory/failures-device.md` 里被写了 **7 遍**（第 57/59/61/65/67/107/121 行），在 `PITFALLS` 里另有 **4 个正式条目**（`#30/#52/#148/#179`）+ **7 处正文附带重复**。全局还有现成技能 `pkill-self-match`、`AGENTS.md` 也有一条常驻口径。**合计 18 个副本；全库 `pkill -f` 提及 24 行**（`rg -n 'pkill -f' PITFALLS/sessions/*.md .pi/memory/*.md | wc -l` = 24）。

**建议的最小动作集（细节见 §D）**：先改门禁（1 个文件、3 处）→ 再补 9 个 superseded/口径更正标记 → 再做 13 组去重（每组保留 1 条权威条目，其余改指针）→ 最后收编号与索引（含 6 处撞号让位）。四批各自独立可提交、可回滚。

---

## §A 重复条目（同一判据 / 同一根因被 ≥2 个编号分别写过）

> 通用口径：**保留 1 条权威条目（正文最完整、带可复现判据的那条），其余改成一行指针**。
> 「证据命令」全部只读、已在本机跑通；搜索一律限定 `PITFALLS/ .pi/memory/ scripts/`。

### A1 `pkill -f` / `pgrep -f` 匹配到自己所在命令行 → 自杀（**P0，18 个副本 / 全库提及 24 行 / 3 层重复**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法（可直接替换的文本） |
|---|---|---|---|---|
| P0 | `PITFALLS/sessions/05-设备上装包环境.md:11`（#30）、`:27`（#52 → 实为 `10-桌面Phosh.md:27`）、`PITFALLS/sessions/18-GUIGPU负载压测与「gfx电源域」读法.md:22`（#148）、`PITFALLS/sessions/23-Q24复现定案+Q28「版本串」变量+测试协议陷阱.md:33`（#179） | 同一根因（`bash -c "<整条命令>"` 的 cmdline 含模式文本 ⇒ 杀自己 / `pkill` 只排自身 PID 不排父 shell）写成 4 个正式条目；#148 与 #179 连「规避手法」都同（字符组 + `grep -vw $$` + 先 `pgrep -af` 只列不杀） | `rg -n 'pkill -f' PITFALLS/sessions/*.md` | 保留 **#148** 为权威（唯一写清「模式里**所有**分支都要加括号 + 同行不得出现裸字面量」这条真判据的）。把 #30、#52、#179 三条正文各替换为一行指针：<br>`30. **`socat` 后台化时别 `pkill -f 'TCP-LISTEN:7898'`** —— 属 `pkill -f` 自匹配自杀，判据与规避见 **#148**（技能 `pkill-self-match`）。`<br>`52. **★ `pkill -f <模式>` 会匹配到自己的 ssh 命令行** ⇒ 见 **#148**（同族，含 ssh 场景与技能 `pkill-self-match`）。`<br>`179. **`pkill -f <pattern>` 自杀（`exit 143`）** ⇒ 见 **#148**；本轮补充事实 = `pkill` 只排除自身 PID、**不排除父 shell**。` |
| P0 | `.pi/memory/failures-device.md:57,59,61,65,67,107,121` | **同一个判据在同一个文件里写了 7 遍**（措辞各异：远程 shell 自杀 / 无输出 / `bash -c` cmdline / 括号法 / `grep -vw $$`） | `rg -n 'pkill -f' .pi/memory/failures-device.md` | 只保留 **第 121 行**（信息最全，含用户 2026-10-12 的指认）为一行，其余 6 行（连同其上的 `---` 分隔符各一行）删除；第 121 行改为：<br>`pkill -f / pgrep -f 会匹配到自己这条 bash -c 命令行（命令里含 pattern 文本）从而自杀、命令半截未跑（2026-10-12 用户指认；本仓已复发 ≥7 次）。规则：模式每个分支写成字符组（driver[-]log、ttyACM[0]、dev[-]str…）+ grep -vw $$ 兜底，先 pgrep -af 只列不杀；权威条目 = PITFALLS #148，技能 = pkill-self-match。` |
| P1 | `PITFALLS/sessions/`正文级重复：`128-截图判据前先核DRM输出状态.md:30`、`44-容器侧camera-provider：64位自编-ABI崩溃-YUYV协商.md:72-73`、`29-Waydroid马达透传.md:24`、`51-容器camera-provider真根因-vtable错位与符号抢占.md:188`、`89-f2fs手术五个工具级坑.md:50`、`109-lore-Anubis挑战与投递复核.md:44`、`58-nohup设备脚本不随终端中断而死.md:32` | 7 处「顺带复述一遍判据」，每处都自带局部结论 | `rg -n 'pkill -f' PITFALLS/sessions/ | wc -l` | 不改语义、只削重复：把这 7 行里的「会匹配到发起命令自身/自杀」解释句统一替换为 `（`pkill -f` 自匹配，判据见 #148）`，保留各条目自己的现场事实。 |

### A2 busybox `pgrep -x` / `pkill -x` 恒假阴性（**P1，1 条权威 + 4 份 memory 副本**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P1 | 权威 = `PITFALLS/sessions/06-脚本工具.md:150`（#120）；指针 = `PITFALLS/sessions/14-睡眠挂起.md:31`（#68，已写「关联 #120」，**这是全仓唯一正确写法**）；副本 = `.pi/memory/failures-device.md:17,19,25,35` | 同一判据（busybox 匹配 argv[0] 全串，`/sbin/udevd` 使 `-x udevd` 不成立 ⇒ 所有 `pgrep -x` 守卫空操作）在 memory 里 4 遍；`#68` 与 `#120` 的分工已经做对了 | `rg -n 'pgrep -x' .pi/memory/failures-device.md` | 删除 `.pi/memory/failures-device.md` 第 17、19、25 行（各连同其后的 `---`）；第 35 行改为一行：<br>`busybox pgrep -x / pkill -x 在本机设备上恒假阴性（按 argv[0] 全串匹配，GNU procps 语义相反）⇒ 设备脚本里出现 -x 一律当 bug；判据改 ps -eo comm | grep -cx NAME。权威 = PITFALLS #120。` |

### A3 RAM 启动（`fastboot boot`）未先部署 `/lib/modules/<新UTS>` ⇒ `lsmod` 空 ⇒ 无 DRM（**P0，5 处，且已被误当成 Q28 坏发**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P0 | 权威 = `PITFALLS/sessions/40-RAM起新内核不部署模块树就没有DRM.md`（该节条目）；副本 = `.pi/memory/failures-kernel.md:669`、`:675`、`:681`；判据顺序变体 = `.pi/memory/failures-kernel.md:673`；另 `.pi/memory/MEMORY.md:53` 第 4 次复述 | 同一因果链（`lsmod` 空 → DP PHY/altmode 缺 → DP 控制器永久 `-EPROBE_DEFER` → DPU 组件不齐 → 无 `card0`）写了 5 遍，其中 3 遍在**同一个文件相邻 12 行内** | `rg -n 'lib/modules' .pi/memory/failures-kernel.md` | 删 `.pi/memory/failures-kernel.md:669` 与 `:675`（连同各自后面的 `---`），把 `:681` 与 `:673` 合并为一条：<br>`RAM 起自编内核（fastboot boot）前必须先部署 /lib/modules/<新UTS>（1497 个 .ko ≈85M），否则 lsmod 空、modprobe 静默失败、DP PHY/altmode 缺、DP 控制器永久 -EPROBE_DEFER、DPU 组件集不齐 ⇒ 无 card0（症状伪装成 Q28 坏发）。判据顺序 = ① lsmod 条数（空=模块树没上）② dmesg \| grep 'bound ae94000.dsi' ③ 才看 L1 签名。权威 = PITFALLS 四十节；AGENTS.md 项目记忆第 3 条为常驻口径。` |

### A4 `/sys/class/drm/card0-DSI-1/dpms` 只读（**P1，4 处，其中 1 处权限值写错**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P1 | `PITFALLS/sessions/17-设备侧自动化踩坑：会话总线DPMS传感器总线.md:12`（#141）、`41-设备侧熄屏自动化：dpms只读与坏发会话崩溃.md:6`（#294）、`119-取证方法两坑-dpms只读与ftrace分组.md:1`+`:6`（#456）、`.pi/memory/notes-display.md:5` | 4 处同一判据；**权限值互相矛盾**：#294/#456/`failures-kernel.md:679` 实测 `-r--r--r--`（0444，root 也写不进），而 `notes-display.md:5` 写「**0644** 只读、**写入需 ~2.5s 生效**」= 自相矛盾（既只读又能生效） | `rg -n 'dpms' .pi/memory/notes-display.md` | 保留 **#456**（唯一给出「DRM legacy `dpms` 属性需驱动实现 `atomic_set_property`，msm 链上没有」这一层机理）为权威。① #141 正文替换为：<br>`    熄屏**没有 sysfs 退路**，唯一真实路径是会话总线 `ScreenSaver.SetActive`；权限值与机理见 **#456**（同坑另记 #294）。判「有没有画面」用 `dpms` + dmesg `vblank timeout`，不要用亮度节点。`<br>② #294 保留其「假阴性/读回校验」段（那是它独有的），标题行下补一行 `机理与权限值见 #456；本条只保留判据 = 必须读回并校验 On→Off 跃迁。`<br>③ `.pi/memory/notes-display.md:5` 改为：<br>`- 桌面/熄屏判据：/sys/class/drm/card0-DSI-1/dpms 在本机是 0444 只读（-r--r--r--，root 也写不进，echo 失败常被 ssh 吞掉），所以熄屏只能走 ScreenSaver.SetActive 且**必须读回校验 On→Off 跃迁**，否则整轮样本是假 INVALID-NO-BLANK；判桌面在不在要抓帧看亮度，不能只看 pgrep phoc。` |

### A5 vermagic / UTS 必须与在机模块目录逐字一致（**P1，4 条正式条目 + 1 条索引专属**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P1 | `#95`=`06-脚本工具.md:11`；`#176`=`23-Q24复现定案….md:18`；`#332`=`47-刷机取证与相机App-portal根因.md:24`；`#99`=`06-脚本工具.md:20`；异类 = `#367`=`62-vermagic只比UTS-同UTS不同config模块树静默错位.md:1`（同 UTS **不同 config** 才静默错位）；`#607` 只有索引行 `PITFALLS/README.md:301` | `#95`/`#176`/`#332`/`#99` 都是「UTS 串不一致 ⇒ 模块加载/`modprobe` 静默失效」，四者给的验收命令各不相同（`uname -r` vs `make -s kernelrelease` vs 从 `boot.img` 解 kernel 比 `Linux version`+`vermagic` 两串）⇒ 读者不知以哪个为准 | `rg -n 'vermagic' PITFALLS/sessions/*.md` | 保留 **#332** 为权威（唯一给出「从成品 `boot.img` 解出 kernel，逐字比 `Linux version` 与 `vermagic` 两串」的端到端验收）。① `#95` 正文改为：<br>`95. **模块热载的 vermagic 必须匹配**：设备 `uname -r` ≠ 内核树 `make -s kernelrelease` 时 push 的 `.ko` insmod 失败；`scripts/mod-loop.sh` 会**拒绝执行**。端到端验收与 `LOCALVERSION` 写法见 **#332**（同 UTS 不同 config 的静默错位见 **#367**）。`<br>② `#176` 首行下补：`（通用法则见 #332；本条只保留「单模块重编必须钉 LOCALVERSION 复用整棵已部署模块树」这一事实。）`<br>③ `#99` 首行下补：`（UTS 逐字一致的验收口径见 #332；本条只保留「持久根 `/lib/modules` 缺失 ⇒ 相机/音频『消失』」这一现象。）`<br>④ `#367` 首行下补：`（同 UTS 但 config 不同才会错位；串本身不一致的处置见 #332。）` |

### A6 `make olddefconfig` 删 `CONFIG_ARCH_QCOM`（**P0，重复且已被新证据部分推翻 → 见 §B-4**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P0 | `#9`=`PITFALLS/sessions/02-内核DTS构建.md:3`（已带「⚠ 收窄（#162）」）；`#162`=`PITFALLS/sessions/22-构建守卫&Q28变量纠正.md:3` | 两条讲同一件事（`olddefconfig` 抹掉 `ARCH_QCOM` → 无 QCOM 驱动的死内核）。差异：#162 多「机制（`apply-kernel-fragment.sh` 自动跑）+ 编后符号守卫 + 判据命令 + 恢复备份 sha」，#9 只有结论 | `rg -n 'olddefconfig' PITFALLS/sessions/*.md` | #9 正文（`02-内核DTS构建.md:3-7`）整段替换为指针：<br>`9. **`make olddefconfig` 会删掉 `CONFIG_ARCH_QCOM` 整行**（7.2 血统）⇒ 机制、判据、守卫与 2026-11-10 后的「已不复现」范围，**一律以 #162 为准**（含 7.3 树的收窄，见 #605）。` |

### A7 裸 `make` 漏 `ARCH=arm64` 会按宿主 x86 重写 `.config`（**P1，同一文件两处 + 1 条补记，另常驻层还有一份**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P1 | `#9b`=`PITFALLS/sessions/02-内核DTS构建.md:9`；同一事实被追加到 `#162` 的「★补记（2026-11-08）」= `PITFALLS/sessions/22-构建守卫&Q28变量纠正.md:8`；常驻层 `AGENTS.md`「内核构建必须走 `scripts/build-kernel.sh`」再写一遍 | 三处同判据，恢复方法只在 #9b 里（`zcat /proc/config.gz > /tmp/device.config`） | `rg -n 'ARCH=arm64' PITFALLS/sessions/02-内核DTS构建.md PITFALLS/sessions/22-构建守卫*.md` | 把 `#162` 的补记行改为指针（其余不动）：<br>`    - ★补记（2026-11-08）：**裸命令漏 `ARCH=arm64` 同样会成片抹掉 arm64 符号**，机制与恢复方法见 **#9b**；写法固定 `make ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" olddefconfig`（先 source `scripts/env-build.sh`），改完立刻 `grep -c '^CONFIG_ARCH_QCOM=y'`。` |

### A8 客户端接会提前退出的管道（`head`/`grep -q`）⇒ SIGPIPE 打挂上游（**P1，4 处，#411 自己已声明同族**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P1 | `#199`=`PITFALLS/sessions/27-Q24台架工具链教训.md:3`（fastboot 专属，后果最重 = 打挂设备 gadget，只能物理 POR）；`#411`=`94-迁移门禁三坑….md:32`（`dpkg-deb -c \| grep -q`，正文已写「与 #199 是同一类错误的另一处落点」）；`#270`=`36-构建落点与调试信息实测.md:30`（`pipefail`+`grep -m1` 把兜底值拼进变量）；`#584` **只有索引行** `PITFALLS/README.md:277`（`fastboot … \| grep -q` / `\| head` / `\| tail`） | 同一机制 4 处，后果分两档（打挂设备 vs 门禁假红），但没有一条总则 | `rg -n 'grep -q\|grep -m1\|SIGPIPE' PITFALLS/sessions/*.md` | 以 **#199** 为权威并补总则一行：在 `27-Q24台架工具链教训.md:3` 条目末尾追加<br>`    - ★总则（覆盖 #411 的 dpkg-deb、#270 的 pipefail+grep -m1、#584 的 fastboot 管道）：**任何会被下游提前关闭的生产者，都不得与 `grep -q`/`grep -m1`/`head` 直接串接**——先落临时文件再 grep。后果分两档：普通命令 = 假阴性；fastboot = 设备侧 gadget 僵尸态，只能物理 POR。`<br>#411、#270 各保留现场与专属修法，首行下补 `（同族总则见 #199）`。`#584` 按 §C-2 先建正文再挂指针。 |

### A9 Linux→fastboot 入口族（`#88`/`#150`/`#368`/`#525`/`#542` + `01:23`）（**P0，重复 + 互相冲突，裁决在 §B-1/§B-2**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P0 | `#368`=`63-reboot2早期下发致设备USB不枚举.md:1`；`#525`=`173-reboot-bootloader卡死Linux与ABL写槽位retry.md:1`；`#542`=同文件 `:35`；`#88`=`14-睡眠挂起.md:228`；`#150`=`19-重启通道AB槽位ramdisk层叠Q28判据.md:3`；禁忌经验=`01-引导fastboot重启交接.md:23` | `#368`/`#525`/`#542` 三条各自描述「关机/复位阶段卡死 ⇒ USB 全不枚举、只能断电」，`reports/script-redundancy-audit-20261112.md:16` 已实证**内核路径完全相同、只差 6 s sysrq-b 看门狗**；但三条正文互不引用（`#368` 的相关段只列 `#166/#363`） | `sed -n '15,16p' reports/script-redundancy-audit-20261112.md` | 三合一：以 **#542** 为权威（唯一含机制 + 已落地看门狗）。① `63-…md` 的「## 相关」段（`- \`PITFALLS #166\`（暖复位粘坏态）、\`#363\`（nohup 无人看管）`）替换为：<br>`- \`PITFALLS #542\`（**同一故障**：内核路径同为 RESTART2→PSCI SYSTEM_RESET2，差别只在 6 s sysrq-b 看门狗；`eldroid-bootctl` 已内置 ⇒ 唯一入口 `scripts/to-fastboot.sh`，`reboot2 bootloader` 停用，裁决见 `TASKS/README.md` §4 与 `reports/script-redundancy-audit-20261112.md` §1）`<br>`- \`PITFALLS #166\`（暖复位粘坏态）、\`#363\`（nohup 无人看管）`<br>② `#525` 标题行下补一行 `**已被 #542 取代（同一故障；看门狗已落地）**；本条只保留第 2 段「ABL 会自己写槽位 retry（`boot_b` 7→6）」这一独立事实。`<br>③ `01-引导fastboot重启交接.md:23` 的「封装脚本代跑 fastboot 属禁忌」句改为：<br>`   ★ **经验事实（非授权规则）**：**裸 fastboot** 连跑批量故障率高（见 #3、#584）；进 fastboot 的唯一入口是 `scripts/to-fastboot.sh`（内部 `eldroid-bootctl reboot bootloader` + 6 s 看门狗，见 #542），不得绕过它直接下发 `reboot2 bootloader`。「谁执行 fastboot」见 `.pi/AGENT-OPS.md` §1。` |

### A10 设备侧脚本必须 POSIX sh / 整文件 scp 后再 `sh`（**P1，memory 同文件 6 遍**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P1 | `.pi/memory/failures-device.md:13,21,29,109,117,119` | 同一判据（设备 shell = ash/dash，`[[ ]]`/`$'...'`/数组/`set -o pipefail`/`date -d`/`stat -c` 不行；长 inline ssh 必坏）6 条，其中 21 与 29 几乎逐字重复 | `rg -n 'POSIX\|syntax error' .pi/memory/failures-device.md` | 保留 **第 29 行**（唯一同时给出「必须 POSIX sh」+「先 scp 再 sh」两条），删 13/21/109/117/119 五行（连同其后 `---`）；第 29 行末尾追加：<br>`（同族现场：q24-s123-run.sh 的 case 模式、zsh 下 == 报错、滚动执行器把 case/if 切进两个 shell —— 结论同一：设备侧只写 POSIX sh 且整文件执行。）` |

### A11 换机后 `tools/mkbootimg` 丢失 ⇒ 已用自研 `scripts/mkbootimg.py` 补回（**P1，MEMORY.md 内 4 条 + failures-kernel 2 条 + notes-display 1 条**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P1 | `.pi/memory/MEMORY.md:25,43,47,57`（**47 与 57 近逐字重复**：同一条工具、同一句 `.gitignore:15`、同两个引用点 `build-boot.sh:16`/`build-initramfs.sh:30`）；`.pi/memory/failures-kernel.md:663,667`；`.pi/memory/notes-display.md:3` | 7 处复述同一事实链（丢失原因 → 原位抽 ramdisk → 自研 v2 头打包器 → 逐字节自校验） | `rg -n 'mkbootimg' .pi/memory/MEMORY.md` | 保留 **MEMORY.md:57**（最新、含自校验镜像名与字节数），删除 25/43/47 三条（连同 `---`）；`.pi/memory/failures-kernel.md:663`、`:667` 两条压缩为一条并置于该节末尾：<br>`boot.img v2 头打包/解包正解 = scripts/mkbootimg.py（pack/unpack/--selftest）；丢失根因 = /tools/ 在 .gitignore:15。头字段坑：id 槽 20B sha1 必须补零到 32B、name@48/cmdline@64、header_size=1660。权威账 = MEMORY.md 的 mkbootimg 条 + PITFALLS 的 boot.img 打包条目。` |

### A12 版本账耦合：`out/*.img` 不可直接删、**禁重跑 `scripts/vk-identity.py`**（**P1，同一规则 5 处**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P1 | `.pi/memory/MEMORY.md:3`、`:11`、`:170`、`:180` + 常驻层 `AGENTS.md`「项目记忆（2026-11-11 整理）」第 1 条 | 「§5d 拿现扫 `out/*.img` 生成的表逐行比对 ⇒ 删镜像/重跑脚本会清空整表」写了 5 遍；`:170` 与 `:180` 各讲一半（前者 = 别删/别重跑，后者 = 正解是让脚本扫归档目录 `ARCHIVE_GLOB`） | `rg -n 'vk-identity.py' .pi/memory/MEMORY.md` | 合并为 **MEMORY.md:180 一条**：在该行末尾追加 `；禁重跑 vk-identity.py（镜像缺失会清空整表），清镜像只能走 scripts/out-archive.py（默认 dry-run）——此即 AGENTS.md 项目记忆第 1 条的展开，二者同源。`，然后删除 `:3`、`:11`、`:170` 三条中与本判据重复的句子（`:3`/`:11` 的其余内容 = 迁移缺口登记与抢救资产，保留）。 |

### A13 换机抢救资产清单（boot_b 唯一副本 + 模块树 tar + sha）（**P2，MEMORY.md 同文件两遍**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P2 | `.pi/memory/MEMORY.md:7` 与 `.pi/memory/MEMORY.md:11` | 同一段（`device-rescue-20261017/` 内容清单 + boot_b sha `78a2beb1…` + 1497 个 .ko + `device-config-20261017.tar.zst` 207 项）几乎逐字写了两遍 | `rg -n 'device-rescue-20261017' .pi/memory/MEMORY.md` | 保留 `:7`；`:11` 删掉清单段，只留结论：<br>`y700-elden 换机后（2026-10-17）两条最紧约束：① check-doctor §5d「内核身份表已过期」FAIL 是迁移假信号，禁重跑 scripts/vk-identity.py（见本文件 vk-identity 条与 AGENTS.md 项目记忆）；② 设备独有资产（sn.img / GPT / unique/*.bin / 两个 boot_b）只剩本地 + 一份抢救副本（清单与 sha 见本文件「设备侧抢救通道与资产清单」条）。` |

**跨组小结**：A1/A2/A3/A4/A10/A11/A12/A13 八个组的重复**主体在 `.pi/memory/` 而不是 `PITFALLS/sessions/`**——即 AGENTS.md 里「一条 ≤300 字、写入前先 `mem <关键词>` 查重」的纪律**没有被门禁覆盖**。§D-4 给出一条可落地的机器化判据（同文件相邻条目 bigram Jaccard ≥0.5 报警），比再写一遍纪律更有效。

---

## §B 回归条目（结论已被后来证据否证，但条目仍是肯定语气、无 `superseded`/口径更正标记）

> 判据来源：`PITFALLS/README.md §15`（`PITFALLS/sessions/15-过时废弃功能缺陷登记.md`）、`TASKS/README.md §4`（进 fastboot 唯一入口，2026-11-12 立）、`reports/script-redundancy-audit-20261112.md §1`、条目之间的互相否证。
> 现有**正确样板**（改法照此写）：`01-引导fastboot重启交接.md:29` 的 `⛔superseded 中间态`、`22-构建守卫&Q28变量纠正.md:10` 的 `⚠️ **已被取代（…）**；全文 → archive/…`、`45-冷起无桌面与相机成像验收.md:71` 的 `⚠ **本条结论已作废（…见 §46 #323/#324）**`。

| # | 严重度 | 位置 file:line | 现状（现文摘句） | 推翻/收紧证据 | 建议加的标记文本（可直接插入） |
|---|---|---|---|---|---|
| B1 | **P0** | `PITFALLS/sessions/270-OSK不弹是phoc版本门.md:78`（#617） | 标题即结论：「**#617 GRUB→EFI-stub 直启在本板「60–70 s 硬件掉电」，墙在我们这套 UEFI 件、不在机型/GRUB**」，正文「死点在 ~60–70 s 之后且无 panic 记录」 | `PITFALLS/sessions/275-掉电判读可能是ramoops-oops.md:1` + 同文 §六 `:96-99`：三臂日志逐字相同 = `Kernel panic - not syncing: Oops`，并明写「`#617` 的『pstore 空 + 无 watchdog + uptime 归零』三条判据**全部可由 panic 解释**，不构成『硬件掉电』的证明」 | 在 `:78` 标题行**下一行**插入：<br>`> ⚠️ **本条「60–70 s 硬件掉电」的判读已被 #620 否证（2026-11-11 深夜）**：三臂日志均为 ramoops oops + panic（`persistent_ram_write`←`ramoops_pstore_write`），非硬件掉电；「pstore 空 + 无 watchdog + uptime 归零」三判据不足以排除 panic。本条**仍成立**的部分 = ①「不能对外说本平台原理上不能 EFI-stub 直起」（PR #820 反证）②GRUB 2.14 无 arm64 EFI-stub 捷径 ③`efi=noruntime` 是最省的第一发。取证的当前口径见 **#620**。` |
| B2 | **P0** | `PITFALLS/sessions/195-GRUB起来了但EFI-stub交接死在本平台.md:5`（#558） | 「从 GRUB 走『EFI-stub 内核』在本平台会在 **ExitBootServices 之后立即死**，**四通道同时静默**」——全文件 `#620/作废/更正/推翻` **0 命中** | ① `270-OSK不弹是phoc版本门.md:84`（#617 正文）已写「『EB 之后立即死』『≈15 s = `panic=15` 计时』『EFI 只给 469 MiB』三条旧判读**全部作废或收紧**」；② `275-…md:1` 给出真机制（ramoops 在 `no-map` 区被 `iomap` 且地址错 ⇒ 崩溃文本根本没落对地方） | 在 `:5` 标题行下一行插入：<br>`> ⚠️ **口径已收紧（2026-11-11/12）**：「EBS 之后**立即**死」不再成立——#617 实测内核在 EFI 路径下能走完数百个 `device_initcall`；「四通道同时静默」的真机制 = ramoops 落盘地址错（见 **#620** 第四节），即**通道没坏、取证面坏了**。本条保留价值 = R54 定向连接判据与 `CoreExitBootServices()` 尾巴两行的识别法。` |
| B3 | **P1** | `PITFALLS/sessions/14-睡眠挂起.md:228`（#88） | 「**★能力缺口：本机没有『Linux→fastboot』的可靠工具（2026-10-03 实测）**」+「想进 fastboot，目前只有**物理键**」，全条无后续更正 | 同文件同仓已被两次推翻：① `19-重启通道AB槽位ramdisk层叠Q28判据.md:3`（#150）实测 `reboot2` **5 s 进 fastboot、坏发下照样管用**；② `TASKS/README.md:136`（2026-11-12）定「进 fastboot 的唯一入口 = `scripts/to-fastboot.sh`（内部 `eldroid-bootctl reboot bootloader` + 6 s sysrq-b 看门狗）」 | 在 `:228` 条目首行后插入子项：<br>`    - ⚠️ **superseded（2026-10-10 起）**：本条的「能力不存在」只适用于**BCB/`reboot -f` 路径**；能力后来由 PSCI vendor reset 造出来（#150 的 `reboot2`；现口径 = **唯一入口 `scripts/to-fastboot.sh`** → `eldroid-bootctl reboot bootloader`，带 6 s sysrq-b 看门狗，见 #542 与 `TASKS/README.md` §4）。本条**仍有效**的部分 = `misc` BCB `bootonce-bootloader` 未被 ABL 采纳、以及「先 `mark-successful b` 否则扣 retry」的前置。` |
| B4 | **P1** | `PITFALLS/sessions/02-内核DTS构建.md:3`（#9）与 `22-构建守卫&Q28变量纠正.md:3`（#162） | 无限定语气：「**改 `.config` 后绝不跑它**」/「`make olddefconfig` 删 `CONFIG_ARCH_QCOM` → 静默产出无 QCOM 驱动的死内核」 | `PITFALLS/README.md:299`（#605，2026-11-10，正文在 `reports/droidloom-feasibility-20261110.md`）：7.3 树上实跑 `scripts/config --enable … && make olddefconfig` 后 `CONFIG_ARCH_QCOM=y` **仍在** ⇒ 「旧条目的警告只对 7.2 血统成立」 | 在 `02-内核DTS构建.md:3` 与 `22-构建守卫&Q28变量纠正.md:3` 各插入一行（紧接标题）：<br>`    - ⚠️ **适用范围收窄（#605，2026-11-10）**：「`olddefconfig` 必删 `ARCH_QCOM`」= **7.2 血统树的历史行为**；7.3 树（`build/daily`、`wt/reb-73*`）实测**不复现**。**但守卫与「先 source `scripts/env-build.sh`、改完立刻 `grep -c '^CONFIG_ARCH_QCOM=y'`」照旧执行**——本条的正解是不依赖「会不会删」的幂等检查，不是禁用 `olddefconfig`。` |
| B5 | **P1** | `PITFALLS/sessions/09-WiFiath12k装包.md:10`（#44） | 「开机首探 MHI `-110` 是竞态…**用只 bind 不 unbind 的延迟重试脚本（`scripts/ath12k-retry.sh`，已挂 `/init`）解决**」+「另有稳定性隐患：bind 成功后运行一段时间内核崩（**待查**）」 | 同仓 `35-WCN首探修法：只有整轮重探有效.md:7`（#264）：「**同一 MHI 实例内重发无效（连每轮 SoC 全局复位也无效）——必须让驱动 core 重跑整轮 probe**」；`:13`（#265）给出正解形态 = `ath12k_pci_probe()` 里 `-ETIMEDOUT` → 返回 `-EPROBE_DEFER`（上限 4 次）。`34-…md:5`（#263）进一步否定「等得不够久」这一类归因。**#44 全条不提 #263/#264/#265，两个后续文件也不回指 #44** | 在 `09-WiFiath12k装包.md:10` 条目内插入：<br>`    - ⚠️ **处方已作废（#263/#264/#265，2026-10-14/15）**：「同一实例内延迟重试 / 只 bind 不 unbind」**无效**（连每轮 SoC 全局复位也无效）。正解 = 让驱动 core 重跑整轮 probe，内核内自愈形态 = `ath12k_pci_probe()` 在 `ath12k_core_init()` 返回 `-ETIMEDOUT` 时返回 `-EPROBE_DEFER`（计数上限 4，成功清零）。**本条保留**：首探在 ~1.9 s 失败、设备留未绑定这一现象，以及「历史判据只到 bind 层、不看 MHI 实例状态 ⇒ 会误判已修」。` |
| B6 | **P1** | `PITFALLS/sessions/96-卡死取证三反直觉-pmsg不落地与console后起与proc搬走.md:6`（#414） | 「**pstore/pmsg 不能当取证通道**（这颗内核上写成功但读不到）」，并断言 `CONFIG_PSTORE=y`+DT `ramoops` 齐全仍读不到 | 与同仓 `68-…md:21`（#374）直接冲突：#374 写「**正确渠道：pstore / ramoops（在机已就绪）**」并贴出**同一行** DT（`ramoops@c2000000`、`0x400000@0xc2000000`）、以 `console-ramoops*` 为读取路径；后来 `270-…md:80`（#617）已用「`/sys/fs/pstore/` 为空（**E4 已补 `record-size`**）」把 pstore 当**正常证据面**使用；`AGENTS.md` 项目记忆写的是「`ramoops@c2000000` **缺 `record-size`/`max-reason`** 才拿不到跨 kexec dump」。**两文互不引用，无一处收口** | 在 `96-…md:6` 标题下一行插入：<br>`> **与 #374 的矛盾在此收口（2026-11-12 审计）**：pstore **可以**当取证通道，前提是 DT `ramoops` 带 `record-size`（E4 起已补，见 #617 的取证用法）；本条的「恒空」样本 = **缺 `record-size`/`max-reason` 的那颗内核**，不是 pstore 本身不可用。因此：① 判「pstore 能不能用」的第一条 = 读回 DT 里 `ramoops` 的 `record-size`；② `#374`（复位深度证据在上一个内核的 pstore）与 `#377`（ramoops POR 后不清零 ⇒ 新旧文本交错）**才是常态**，本条只作「配置不齐时的症状」保留。` |
| B7 | **P1** | `PITFALLS/sessions/63-reboot2早期下发致设备USB不枚举.md` 的「## 规则」段（`sed -n '/^## 规则/,/^## 相关/p'`，首条即「**死亡后不要立刻 `reboot2 bootloader`**…再进 fastboot 流程」） | 规则仍是「等 60 s + `pidof phoc` 后用 `reboot2`」，即**把已被停用的下发方式当推荐路径**；2026-11-12 追加段（同文件 `:44` 起）只补了「长 uptime 也中招、下发前无法预判」 | `reports/script-redundancy-audit-20261112.md:15-16`：`reboot2` 与 `eldroid-bootctl` **内核路径完全相同**（都 `RESTART2 "bootloader"` → PSCI `SYSTEM_RESET2`），差别只在 6 s sysrq-b 看门狗 ⇒「#368 与 #525/#542 是同一故障、只差一个看门狗」；`TASKS/README.md:136` 据此把 `reboot2 bootloader` **停用** | 把「## 规则」段首条替换为：<br>`① **唯一入口 = \`scripts/to-fastboot.sh\`**（内部 \`eldroid-bootctl reboot bootloader\` + 6 s sysrq-b 看门狗，见 #542）。\`reboot2 bootloader\` 已停用：两者内核路径相同，`reboot2` 只是少了兜底看门狗（裁决 = \`TASKS/README.md\` §4、\`reports/script-redundancy-audit-20261112.md\` §1）。时序门（\`wait_ssh\` + \`uptime\` ≥ 60 s + \`pidof phoc\` 非空）**继续保留**，作用是降低撞上关机路径卡死的概率，不是「等够就改用 reboot2」。` |
| B8 | **P2** | `PITFALLS/sessions/01-引导fastboot重启交接.md:3`（#1） | 「**所以『进不去 Android』第一步 = 切另一个槽试试**」+「`--set-active=a` + `fastboot reboot` 就完好进系统」；该条只加了「主语：属设备写操作、先备份 GPT」，**没有指向 §15.1 的作废口径** | `PITFALLS/sessions/15-过时废弃功能缺陷登记.md:18`：「『进 fastboot 先 `fastboot --set-active=a`』操作规则 = **错误规则已作废**：会动在用的 b 槽 active；现口径 = 不改 active slot，槽位管理用 `qbootctl`」；`13-AVB免签KSU.md:8` 已就地写「⚠ **已作废（#114）**」——同一规则在 A 处标了、在 B 处（#1）没标 | 在 `01-引导fastboot重启交接.md:3` 的「⚠️ **主语**」行之后插入：<br>`   ⚠ **口径（#114 / §15.1）**：本条只适用于「Android 卡启动动画、数据完好」的**恢复**场景（现场取证：切槽即好）。**不得**把它读成「进 fastboot / 日常切槽用 `--set-active`」——那条规则已作废（会动在用的 b 槽 active），读状态与 mark-successful 用 `qbootctl`/`scripts/slot-attr.py`（#126/#133），见 `13-AVB免签KSU.md` 的作废行。` |
| B9 | **P2** | `PITFALLS/sessions/41-设备侧熄屏自动化：dpms只读与坏发会话崩溃.md:16`（#294 内） | 活跃判据挂在**不存在的编号**上：「…否则该发记 `INVALID`（**见 `#288` 的假 ALIVE 教训**）」 | `#288` 在 `PITFALLS/sessions/*.md` 里**无任何定义**（`rg -n '^##? #?288\|^[[:space:]]*288\. \*\*' PITFALLS/sessions/*.md` 空）；该判据的真实现场在 `PITFALLS/sessions/38-M1-7.3模块树补建：ARCH与vermagic双坑+相机栈跑通.md:183-185`（改用 `boot_id` 判据 + 显式校验 `On→Off` 跃迁，`SetActive(true)` 在已熄灭态是 no-op ⇒ 第二个假阳性）；`.pi/memory/MEMORY.md:75` 又把「死活唯一可信判据 = `boot_id`」记成「PITFALLS #288」 | 把该行的悬空引用改为可落点：<br>`  ⇒ 熄屏必须**读回 \`dpms\` 并校验 \`On -> Off\` 跃迁**，否则该发记 \`INVALID\`（假 ALIVE 的实测现场与 \`boot_id\` 判据 = 四十节 N2'/N3 处置段；「死活唯一可信判据 = \`/proc/sys/kernel/random/boot_id\`」的账已记在 \`.pi/memory/MEMORY.md\`，**旧引用 \`#288\` 从未建条目，停用**）。` |

**§B 的结构性诊断（为什么这类回归会不断产生）**：`PITFALLS` 的「新证据」有两条互相竞争的写入路径 —— ①在旧条目里加「⚠ 收窄/已作废」行（正确，如 #5/#163/#322）；②另开一个**只有索引行、正文指向 `../reports/`** 的新编号（本轮 §C-2 的 27 个编号就是这种）。路径 ② 从结构上**不可能**给旧条目打标记，于是旧条目永远保持肯定语气。§C-2 的修法（强制为这些编号建 `sessions/*.md` 正文）同时也是 §B 的治本手段：建正文时才有「替代了谁」的落点。

---

## §C 编号健康 / 索引↔正文对账 / 索引行长度

**基线命令（只读，已跑通）**

```sh
bash scripts/check-doctor.sh --only 8        # 结果：FAIL=0 WARN=2（其中 1 个 WARN 是本次新建的本报告）
python3 - <<'PY'   # 索引行长度分布（无需改仓库）
for i,ln in enumerate(open('PITFALLS/README.md',encoding='utf-8'),1):
    if ln.startswith('|') and '](' in ln and len(ln.encode())>800: print(i,len(ln.encode()))
PY
```

`check-doctor --only 8` 报「索引行长度合规 ✅ / 索引 #NNN 均有正文定义 ✅」——**两项都是假绿**，C-1、C-2 给出反例与门禁源码行。

### C-0 编号撞车：6 个号被跨文件重复定义，另有 4 个号只有「不受管」的写法（**P0，门禁报绿**）

| 编号 | 两份定义（file:line） | 内容是否同一件事 | 门禁为何看不见 | 证据命令 | 建议改法 |
|---|---|---|---|---|---|
| **#53** | `PITFALLS/sessions/10-桌面Phosh.md:31`（`53. **Phosh 会话起来后要的东西**…`）<br>`PITFALLS/sessions/53-用户态先查内置能力-phosh旋转磁贴重复造轮子.md:1`（`# 53. 用户态改动前先查…`） | **否**（前者 = 会话依赖清单；后者 = 先查上游有没有现成能力） | 第二份是 `# 53. ` 标题形式：门 8d 的标题支路只搜 `#(\d{1,3})\b`（数字前要有 `#`），行首 `NNN. **` 支路又要求行首不是 `#` ⇒ 两边都不匹配，跨文件比较里只剩 1 份 | `rg -n '^53\. \*\*\|^# 53\. ' PITFALLS/sessions/*.md` | 让位给后到的：**`53-…md:1` 改号**（当前最大号 +1 = `#628`；文件名前缀不动，只改条目号与索引行），正文首行加一行「原误用 #53，2026-11-12 去重审计 C-0 改号；#53 归 10-桌面Phosh.md」；在 `15-…md` §15.7 表加一行消歧 |
| **#192** | `25-Q28冷起判定=内核构建身份法则+冷起AB测补丁作废.md:3`（`192. **★Q28「冷起只有背光」…由构建身份决定**`，⚠ 此条已标 `已作废` 并指向 archive）<br>`192-启动形态对比与充电净电流判据.md:1`（`## 192. 启动形态对比（ESP/路线 B vs boot_b）与「到底有没有在充电」的判据`） | **否** | 同上（第二份 `## 192. ` 形式不受管） | `rg -n '^192\. \*\*\|^## 192\. ' PITFALLS/sessions/*.md` | `192-…md:1` 改为标题「## #629 启动形态对比（ESP/路线 B vs boot_b）与「到底有没有在充电」的判据」，并补索引行 |
| **#282 / #283 / #284 / #285** | `54-构建机静默文件损坏与坏对象.md:9,32,37,41`（`282.–285.` = 构建机位翻转 / `bad reloc symbol index` / `-O0` 能过 `-O≥1` 崩 / `m1-73` 的三处有意未提交修改）<br>`38-M1-7.3模块树补建：ARCH与vermagic双坑+相机栈跑通.md:8,30,55,81`（`## 282.–## 285.` = 裸 `make` 漏 `ARCH` / `vermagic` 多 `+` / 相机栈首跑 / `cam-mode.sh off` 反而开熄屏） | **否**（两组完全不同的教训成对撞号） | 38 那 8 行全是 `## NNN. ★` 形式 ⇒ 只有 54 的那份进 `pnum`，比较时形不成「跨文件」 | `rg -n '^#{1,4} [0-9]{1,3}\. ' PITFALLS/sessions/38-*.md`（8 行）+ `rg -n '^28[2-5]\. \*\*' PITFALLS/sessions/54-*.md`（4 行） | 38 的 8 条（#282–#289）整体让位到 `#628` 起连续取号（#286–#289 本就只有这一种写法，一并处理），文件名与文件内小节顺序不动；每条首行加一行「原误用 #28N，2026-11-12 去重审计 C-0 改号；#28N 归 54-构建机静默文件损坏与坏对象.md」；§15.7 加 8 行消歧 |
| **#286–#289 的历史误判** | `reports/doc-audit-20261026.md:229-232` | 上一轮审计因看不见这 4 行，判为「号段缺口」并建议「在 README 表尾加**空号声明**：#286–#289 无对应条目」 | 与本轮同源（写法不受管） | `rg -n '空号声明' reports/doc-audit-20261026.md` | 不执行该建议（未被执行，`rg -n '空号' PITFALLS/README.md` = 0）；本轮以 C-0 改号 + C-4 反向判据收口，并在 `15-…md` §15.7 注明「**号段缺口需先用三种定义形式各查一遍**」 |

> **为什么不重排**：`15-…md` §15.7 的规则是「编号 = 跨文档稳定引用键，只补不重排」，且历史上已有两次「**让位改号**」先例（`#166`→`#154`、`#217`→`#257`，见同表）。本审计照此办理：**保留先出现的那份，后到的取新号并留消歧行**；`TASKS/README.md:1075`（Q24 行）等对 `#282–#289` 的历史引用，改号后在 §15.7 一处集中映射，不逐处追改。

### C-1 索引行 ≤800 B 的门禁漏掉整类行（**P1**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P1 | 门：`scripts/doctor/s07-08-docs.py:116`；受害者：`PITFALLS/README.md:273`(809 B)、`:277`(**1093 B**)、`:278`(987)、`:282`(945)、`:283`(1004)、`:298`(807)、`:300`(848)、`:301`(813)、`:302`(802)、`:303`(964)、`:304`(1069)、`:306`(1085) | 条件写的是 `ln.startswith('\|') and 'sessions/' in ln`，而超长的 12 行的链接目标全是 `../reports/*.md` ⇒ 一条都不进检查。含 `sessions/` 的 247 行确实全 ≤800 B（最长恰好 800）⇒ 门只对「有正文的那一半」生效，而**没正文的那一半正是把结论堆进索引的那一半** | `python3 -c "print(sum(1 for ln in open('PITFALLS/README.md',encoding='utf-8') if ln.startswith('|') and '](' in ln and len(ln.encode())>800))"` → `12` | `scripts/doctor/s07-08-docs.py:116` 的<br>`        if ln.startswith('|') and 'sessions/' in ln and len(ln.encode()) > lim:`<br>改为<br>`        if ln.startswith('|') and '](' in ln and len(ln.encode()) > lim:`<br>（同文件 `:161` 同步改，见 C-2）；改后先在报告里列出 12 行，再按 C-2 建正文瘦身 |

### C-2 27 个编号「只在索引里活着」，且悬空门同样看不见（**P0**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P0** | `PITFALLS/README.md:230-236`（#527–#533）、`:272-285`（#579–#592）、`:297-302`（#603–#608） | 这 **27 个 `#NNN`** 在 `PITFALLS/sessions/*.md` 中**既无标题定义、也无 `**#NNN**` 粗体引用**（全库 0 命中），条目正文实际只存在于 `reports/*.md`。悬空门 `s07-08-docs.py:161` 只把含 `sessions/` 的行喂进 `idxnums` ⇒ 这 27 个号从未参与「索引有、正文没有 = 硬错」的检查 | `rg -c '#5(2[7-9]\|3[0-3])\b' PITFALLS/sessions/` → 无命中；`rg -n '^\s*#{1,4}.*#60[3-8]\b' PITFALLS/sessions/*.md` → 无命中 | ① 门禁：`s07-08-docs.py:161` 的<br>`    if ln.startswith('|') and 'sessions/' in ln:`<br>改为<br>`    if ln.startswith('|') and '](' in ln:`<br>② 内容：为这 27 个号**建 `sessions/` 正文**（每号一节 `## #NNN 结论一句话`，正文 5–20 行 + `证据指针` 指回原 report），索引行瘦身为「一句话主题」并改指 `sessions/<NN>-<slug>.md`（`../reports/` 留在正文的指针里）。可直接套用的模板（对齐 `196-…md` 但**必须**是标题形式）：<br>`## #527 <一句话结论>`<br>`>`<br>`> 索引行见 \`PITFALLS/README.md\` 第 <行号> 行。首次取证：<日期>。相关：\`#<相邻号>\`。`<br>`- 结论：…`<br>`- 判据（可复现）：\`<命令>\``<br>`- 证据指针：\`reports/uefi-flt-attribution-20261106.md\` §x` |

### C-3 索引 36 行把「正文」列指向 `../reports/`，与 README 自订定义冲突（**P1**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P1 | 定义：`PITFALLS/README.md:8`「条目唯一性 = 每个 `#NNN` 在 `sessions/*.md` 里**只被定义一次**；新增条目取当前最大号 +1」；违反行：`README.md:230,231,232,233,234,235,236,272,…,307`（共 36 行 `](../reports/…)`） | 「正文」不是 `sessions/` 而是报告文件 ⇒ 索引成为该教训的唯一载体，`PITFALLS` 内部无法引用它（§A8 的 `#584` 就是这么变成孤儿号的） | `python3 -c "print(sum(1 for ln in open('PITFALLS/README.md',encoding='utf-8') if ln.startswith('|') and '](../reports' in ln))"` → `36` | 与 C-2 同一批处置；同时在 `README.md:8` 后追加一句（把规则写明，防止再次漂）：<br>`> **正文落点唯一**：条目正文只允许写在 \`PITFALLS/sessions/\*.md\`；\`reports/*.md\` 只能是「证据指针」，不得充当正文（否则索引行必然超长并与复测漂移）。` |

### C-4 编号「定义形式」不统一 ⇒ 9 条真实条目对门禁与对账**双向隐形**（**P0**；撞号后果见 C-0，并已骗过一次上游审计）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P0** | 隐形条目：`PITFALLS/sessions/38-M1-7.3模块树补建：ARCH与vermagic双坑+相机栈跑通.md:8,30,55,81,108,134,160,187`（#282–#289，写法 `## 286. ★★ …`，**数字前没有 `#`**）、`192-启动形态对比与充电净电流判据.md:1`（#192 同形）、`53-…md:1`（#53 写成 `# 53. …`） | 门禁 `s07-08-docs.py` 只认两种形式（标题里的 `#NNN`、行首 `NNN. **`）；`## 286. ★★` 两者都不匹配 ⇒ 这 9 条**不在 `pnum`、不在 `idxnums`（README 里也没有它们的索引行）**。后果已兑现一次：`reports/doc-audit-20261026.md:229-232` 把 `#286–#289` 判成「号段缺口」，并建议「在 README 表尾加**空号声明**：#286–#289 无对应条目（历史上并入 #285/#338，勿再补号）」——**若照做就等于宣布 4 条真实教训不存在**（该建议最终未被执行，`rg -n '空号' PITFALLS/README.md` = 0） | `rg -n '^#{1,4} [0-9]{1,3}\. ' PITFALLS/sessions/*.md` → 命中 `## 282.`–`## 289.`、`## 192.`；`rg -c '\*\*#286[ *]' PITFALLS/README.md` → 0 | ① 把这 9 条标题改成受管形式（**只改标题行，正文不动**）：`## 286. ★★ 「死前最后看到的日志」…` → `## #286 「死前最后看到的日志」…`（#282–#289、#192、#53 同此，前缀统一 `## #NNN `）；② 补索引行（当前 9 条连索引都没有），格式对齐现有行且 ≤800 B；③ 门禁加一条**反向**判据，把这次的教训固化：在 `s07-08-docs.py` 的 8d 之后追加<br>`    m2 = re.match(r'^#{1,4}\s+(\d{1,3})\.\s', line)`<br>`    if m2:`<br>`        dupnum.append('PITFALLS 条目 #%s 用了未受管的标题形式（应改为 "## #%s …"）: %s' % (m2.group(1), m2.group(1), os.path.relpath(f, root)))`<br>（复用 `dupnum` = 硬错通道，防止再出现「审计器看不见 → 审计结论说它不存在」） |

### C-5 悬空引用与真正的空号（**P1**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P1 | 被引用但无定义：`#339`（`PITFALLS/sessions/48-输入法崩溃phoc-wlroots-NULL约定.md:115` 以「坑（#339）」形式引用）、`#563`/`#564`（`TASKS/sessions/2026-11-09-离线收口-zram与世代可复现.md` 与 `reports/uefi-espboot-recursive-dump-rootcause-20261108.md` 引用）；真·空号：`#504`、`#505`（全库 0 提及） | ① `#339/#563/#564` = 有引用、无定义（读者按号找不到条目）；② `#504/#505` = 号被跳过、也没有任何文档解释为什么（`README.md:8` 规定「取当前最大号 +1」，跳号必须留痕） | `rg -n '#339\b' PITFALLS/sessions/*.md \| head`（只有 1 处、非定义行）；`rg -c '#50[45]\b' -g '*.md' PITFALLS TASKS reports .pi/memory` → 无命中 | ① 建条目或在原处改指：`#339` 的现场在 `48-…md:92`（§4 取证方法），把 `:115` 改为 `（取证方法见 §4 / #337）`；`#563`/`#564` 各建 `sessions/` 正文（内容取 `TASKS/sessions/2026-11-09-离线收口-zram与世代可复现.md` 的对应段），并把引用改指新号；② 在 `PITFALLS/sessions/15-过时废弃功能缺陷登记.md` §15.7 表尾追加一行留痕：<br>`\| 空号 \`#504\`/\`#505\` \`#339\` | 1–627 中被引用或跳号但无条目（\`#339\` 历史并入 #337 取证段；\`#504/#505\` 用途不可考） | **不重排、不补号**；引用方一律改指实际条目（2026-11-12 去重审计 C-5） \|` |

### C-6 「为过门而写的锚点」= 粗体提及被当成定义（**P2**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P2 | `PITFALLS/sessions/196-phoc广告syncobj与arm64构建坑.md:18`（小标题字面写着「**## 条目定义（供 check-doctor §8e 锚点）**」，其下 `:20-27` 用 `- **#609** …` 列表形式）、同形：`66-…md:3`（#371）、`100-…md:4,8`（#420/#421）、`109-…md:3`（#444）、`110-…md:3`（#446）、`194-…md:9,28,33`（#600/#601/#602） | 门 8e（`s07-08-docs.py:170-177`）把正文任意位置的 `**#NNN**` 也算「定义」，于是这 13 个号能过关，但 `grep '^## #'` 取不到它们 ⇒ 条目对「按号取正文」的一切工具（含本报告 §A 的聚类）不可见，且**文档自己承认是为门而写** | `rg -n '供 check-doctor' PITFALLS/sessions/*.md` | 把这 13 处的锚点提升为真标题（内容不变，只把列表项首项改为标题）：<br>`- **#609** wlr_linux_drm_syncobj_manager_v1_create() …` → `## #609 合成器必须回落到 wlr_renderer_get_drm_fd()：`drm_fd` 无效时 `create()` 直接返回 NULL`<br>（#610/#611/#612/#613/#371/#420/#421/#444/#446/#600/#601/#602 同法），并把小标题「（供 check-doctor §8e 锚点）」删掉；随后收紧门：`pdef_all` 的粗体支路改为**只用于诊断输出、不再喂悬空门**（悬空门只认标题形式 + 行首 `NNN. **` + 本轮 C-4 的 `## NNN.`）。 |

### C-7 索引未登记的文件（**P2**，机器已抓到的那一条）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P2 | `PITFALLS/sessions/283-G1-38边角上机AltTab漏收确认与探测复活陷阱.md` | `check-doctor --only 8` 唯一实质 WARN：`索引未登记 … 283-G1-38边角上机…md`（`PITFALLS` 属 `INDEXED_ANGLES`，逐文件登记是硬要求，见 `s07-08-docs.py:71-79`） | `bash scripts/check-doctor.sh --only 8 \| grep 索引未登记` | 在 `PITFALLS/README.md` 索引表尾（现末行 `README.md:321` 之后）追加一行（≤800 B，指向该文件）：<br>`\| 283 | G1-38 边角上机：Alt-Tab 漏收的确认口径 + 探测脚本「复活」陷阱 | [283-G1-38边角上机AltTab漏收确认与探测复活陷阱.md](sessions/283-G1-38边角上机AltTab漏收确认与探测复活陷阱.md) <!-- created=2026-11-12, last=2026-11-12 --> \|` |

### C-8 §15.7 的手写编号体检结论已过期（**P2**）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| P2 | `PITFALLS/sessions/15-过时废弃功能缺陷登记.md:103-106` | 「本次体检结果：**1–261 现已一号一条（无重复、无缺号）**」——实际当前号域 1–627，连续区间内缺号 49 个（其中 27 个是 C-2 的索引专属号、9 个是 C-4 的隐形条目、其余见 C-5）；该结论写在 2026-10-14，之后无人复核，而 `check-doctor` 的手写计数复核规则（`s07-08-docs.py` 的 `COUNT_RULES`）只覆盖 `INDEX.md` 的「N 节」，**不覆盖这句** | `rg -n '1–261 现已一号一条' PITFALLS/sessions/15-*.md` | 把 `:103-106` 的结论句替换为不写死的形式：<br>`> 规则：编号是**跨文档的稳定引用键**，只允许「补号/消歧」，**不重排**（见文首「物理顺序不随编号单调」）。`<br>`> **体检结果不写死**（2026-11-12 起）：现查 \`bash scripts/check-doctor.sh --only 8\`（撞号=硬错）；号域/缺号/索引专属号的清单见 \`reports/pitfalls-dedup-audit-20261112.md\` §C（历史：2026-10-14 那次覆盖 1–261）。`<br>并把该正则加入 `COUNT_RULES` 或直接删除该数字（本审计取后者）。 |

### C-9 汇总（供 §D 排序）

| 项 | 严重度 | 一句话 | 影响面 |
|---|---|---|---|
| C-2 | P0 | 27 个编号无正文 + 悬空门跳过该类行 | 索引成唯一载体 → §B 的回归无法被追认 |
| C-4 | P0 | 9 条真实条目（#282–#289、#192、#53）写法不受门覆盖 | 已导致一次错误审计结论（建议「宣布其为空号」） |
| C-1 | P1 | 800 B 长度门漏 12 行（最长 1093 B） | 结论堆在索引、必然漂移 |
| C-5 | P1 | `#339/#563/#564` 悬空引用；`#504/#505` 无留痕空号 | 按号检索断链 |
| C-6 | P2 | 粗体锚点被当定义（13 个号） | 「过门」条目不可被工具消费 |
| C-7 | P2 | `283-…md` 未登记索引 | 机器已报警，1 行修掉 |
| C-8 | P2 | §15.7 写死「1–261 无缺号」 | 过期账 |
| C-3 | P1 | 36 行正文指向 `../reports/`，违反 `README.md:8` | C-1/C-2 的共同根因 |

---

## §D 执行顺序 + 按文件分组的编辑清单

**顺序原则**：先让门禁「看得见」（否则修完仍会复发）→ 再补标记（防止继续误导读者）→ 再删重复（删之前门禁必须已能兜住）→ 最后瘦身索引。
**每一步独立可提交、独立可回滚**；每步末尾的「验收」必须现场跑。

### 批次 1（门禁，1 个文件 3 处）——**必须最先做**

**文件：`scripts/doctor/s07-08-docs.py`**

| # | oldText（锚，逐字） | newText |
|---|---|---|
| 1.1 | `        if ln.startswith('|') and 'sessions/' in ln and len(ln.encode()) > lim:` | `        if ln.startswith('|') and '](' in ln and len(ln.encode()) > lim:` |
| 1.2 | `    if ln.startswith('|') and 'sessions/' in ln:` | `    if ln.startswith('|') and '](' in ln:` |
| 1.3 | （新增，接在 8d 的 `for ln in open(f, …)` 循环内、`else:` 分支之后，缩进对齐）<br>`        else:`<br>`            m = re.match(r'^(\d{1,3})\.\s+\*\*', line)`<br>`            if m:`<br>`                pnum.setdefault(m.group(1), set()).add(os.path.basename(f))` | `        else:`<br>`            m = re.match(r'^(\d{1,3})\.\s+\*\*', line)`<br>`            if m:`<br>`                pnum.setdefault(m.group(1), set()).add(os.path.basename(f))`<br>`        # 未受管的标题形式（`## 286. …`、`# 53. …`）：数字前没有 #，历史上让 9 条真条目对门禁`<br>`        # 隐形，并造成 #53/#192/#282–#285 六处跨文件撞号无人报（2026-11-12 审计 C-0/C-4）。`<br>`        m2 = re.match(r'^#{1,4}\s+(\d{1,3})\.\s', line)`<br>`        if m2:`<br>`            pnum.setdefault(m2.group(1), set()).add(os.path.basename(f))   # ← 让撞号成为硬错`<br>`            dupnum.append('PITFALLS 条目 #%s 标题形式未受管（应写 "## #%s …"）: %s'`<br>`                          % (m2.group(1), m2.group(1), os.path.relpath(f, root)))` |

**验收**：`bash scripts/check-doctor.sh --only 8` 应 **FAIL>0**（预期新增：12 条索引行超长 + 9 条标题形式未受管 + 27 条悬空）——**这一步之后「红」才是对的**；随后批次 2/3/4 把它一条条清零。

### 批次 2（补 9 个回归标记，防止继续误导；纯插入，零删除）

| 文件 | oldText（锚） | 动作 |
|---|---|---|
| `PITFALLS/sessions/270-OSK不弹是phoc版本门.md` | `` ## #617 GRUB→EFI-stub 直启在本板「60–70 s 硬件掉电」，墙在我们这套 UEFI 件、不在机型/GRUB `` | 其后插入 §B1 的 `> ⚠️ …` 段 |
| `PITFALLS/sessions/195-GRUB起来了但EFI-stub交接死在本平台.md` | `` ## #558 从 GRUB 走「EFI-stub 内核」在本平台会在 ExitBootServices 之后立即死，**四通道同时静默** `` | 其后插入 §B2 段 |
| `PITFALLS/sessions/14-睡眠挂起.md` | `` 88. **★能力缺口：本机没有「Linux→fastboot」的可靠工具（2026-10-03 实测）**。 `` | 其后插入 §B3 子项 |
| `PITFALLS/sessions/02-内核DTS构建.md` | `` 9. **`make olddefconfig` 会删掉 `CONFIG_ARCH_QCOM` 整行！** 改 `.config` 后**绝不**跑它。 `` | 其后插入 §B4 行（与批次 3 的指针改写二选一，先标记后瘦身） |
| `PITFALLS/sessions/22-构建守卫&Q28变量纠正.md` | `` 162. **`make olddefconfig` 删 `CONFIG_ARCH_QCOM` → 静默产出无 QCOM 驱动的死内核（vk81/82/83 作废）。** `` | 其后插入 §B4 行 |
| `PITFALLS/sessions/09-WiFiath12k装包.md` | `` 44. **开机首探 MHI `-110` 是竞态**：ath12k 在 ~1.9s probe，WCN 未就绪→MHI 超时→设备留未绑定。 `` | 其后插入 §B5 子项 |
| `PITFALLS/sessions/96-卡死取证三反直觉-pmsg不落地与console后起与proc搬走.md` | `` ## #414 pstore/pmsg **不能**当取证通道（这颗内核上写成功但读不到） `` | 其后插入 §B6 收口段 |
| `PITFALLS/sessions/63-reboot2早期下发致设备USB不枚举.md` | `` ① **死亡后不要立刻 `reboot2 bootloader`**：先 `wait_ssh` 成功 **且** `uptime` ≥ 60 s **且** `pidof phoc` 非空，再进 fastboot 流程。 `` | 整行替换为 §B7 的「① **唯一入口 = `scripts/to-fastboot.sh`**…」 |
| `PITFALLS/sessions/01-引导fastboot重启交接.md` | ``    ⚠️ **主语**：`--set-active` 属设备写操作，按 `.pi/AGENT-OPS.md` §1「先备份 GPT + 记当前 slot 再执行」；不再限定谁执行。 `` | 其后插入 §B8 的 `⚠ **口径（#114 / §15.1）**` 段 |

**验收**：`for n in 617 558 88 9 162 44 414 368; do rg -n -A3 "^[^#]*#?$n\b" PITFALLS/sessions/*.md >/dev/null; done`（仅确保文件仍可解析）；`bash scripts/check-doctor.sh --only 7`（围栏/截断门不破）。

### 批次 3（去重：只删「有权威条目兜住」的副本；**只动 `.pi/memory/` 与 PITFALLS 指针行**）

按 §A 组号执行，逐文件的 `oldText` 取「该行前 60 字符（唯一）」：

| 文件 | 动作（按行号，从大到小删，避免行号漂移） |
|---|---|
| `.pi/memory/failures-device.md` | 删 `121` 保留（改写为 §A1 文本）；删 `107,67,65,61,59,57` 各连同其后 `---`；删 `119,117,109,21,13`（A10，保留 `29` 并追加同族句）；删 `35,25,19,17`（A2，保留 `35`→改写为指针后置于第 17 行位置） |
| `.pi/memory/failures-kernel.md` | 删 `681,675,669` 三条（连同 `---`），在 `673` 位置写入 §A3 合并条；删 `663,667` 两条，在 `665` 位置写入 §A11 合并条 |
| `.pi/memory/MEMORY.md` | **A11**：保留 `57`，删 `47`、`43`、`25` 三条（连同其后 `---`）。**A13**：保留 `7`（抢救资产清单的权威），只把 `11` 瘦身为 §A13 文本（清单段改为指针）。**A12**：把判据合并进 `180`，并从 `3`、`170` 中删除与本判据重复的句子（两行的其余内容——迁移缺口登记、`build/*` 删除前置闸——原样保留）。 |
| `.pi/memory/notes-display.md` | `5` 行整行替换为 §A4-③ 文本（`0644`→`0444`、删去「写入需 ~2.5s 生效」） |
| `PITFALLS/sessions/17-…md` | #141 正文替换为 §A4-① 指针 |
| `PITFALLS/sessions/41-…md` | `6` 标题下补 §A4-② 一行；`16` 行整行替换为 §B9 文本（消灭 `#288` 悬空引用） |
| `PITFALLS/sessions/05-…md` | #30（`:11`）整条替换为 §A1 指针 |
| `PITFALLS/sessions/10-桌面Phosh.md` | #52（`:27`）整条替换为 §A1 指针 |
| `PITFALLS/sessions/23-…md` | #179（`:33-35`）整条替换为 §A1 指针 |
| `PITFALLS/sessions/18-…md` | #148 保留为权威；其后补「已收编 #30/#52/#179 与 `.pi/memory/failures-device.md` 全部副本」一行 |
| `PITFALLS/sessions/06-脚本工具.md` | #95（`:11`）替换为 §A5-①；#99（`:20`）标题下补 §A5-③；#120 保留（A2 权威，补一句 memory 副本已收编） |
| `PITFALLS/sessions/47-…md` | #332 保留为权威，正文末补「已收编 #95/#176/#99」一行 |
| `PITFALLS/sessions/62-…md` | #367 标题下补 §A5-④ 一行 |
| `PITFALLS/sessions/27-Q24台架工具链教训.md` | #199 末尾追加 §A8 总则行 |
| `PITFALLS/sessions/94-…md`、`36-…md` | #411、#270 各首行下补 `（同族总则见 #199）` |
| `PITFALLS/sessions/22-…md` | `#162` 的 `★补记（2026-11-08）` 行整行替换为 §A7 指针 |
| `PITFALLS/sessions/02-内核DTS构建.md` | `#9` 的 `:3-7` 段替换为 §A6 指针（`#9b` 原样保留 = A7 权威） |
| `PITFALLS/sessions/173-…md` | `#525`（`:1`）标题下补 §A9-② 取代标记；`#542` 保留为权威 |
| `PITFALLS/sessions/63-…md` | 「## 相关」段首项插入 §A9-① 的 `#542` 行 |
| `PITFALLS/sessions/48-…md` | `115` 行的 `（#339）` 改为 `（取证方法见 §4 / #337；#339 无条目）`（C-5） |

**验收**：`rg -c 'pkill -f' .pi/memory/failures-device.md` → **1**；`rg -c 'pgrep -x' .pi/memory/failures-device.md` → **1**；`rg -c 'lib/modules' .pi/memory/failures-kernel.md` → **≤2**；`rg -n '#288' PITFALLS/sessions/41-*.md` → 0 命中。

### 批次 4（编号与索引收口，**改动最大，放最后**）

| 文件 | 动作 |
|---|---|
| **（先做 C-0）**`38-…md`、`192-…md`、`53-用户态…md` | 让位改号：38 的 8 条 `## 282.`–`## 289.` → `## #628`–`## #635`；`192-…md:1` → `## #636`；`53-用户态…md:1` → `## #637`（号从当前最大 `#627`+1 起，逐条 +1）；每条正文首行插入「原误用 #NNN」消歧行；`15-…md` §15.7 表追加对应 10 行映射 |
| `PITFALLS/sessions/38-…md`（8 处）、`192-…md`、`53-…md` | 标题形式改为受管形式 `## #NNN …`（与上一行的改号合并成同一次编辑；只改标题行） |
| `PITFALLS/sessions/196-…md`（`18-27`）、`66-…md:3`、`100-…md:4,8`、`109-…md:3`、`110-…md:3`、`194-…md:9,28,33` | 把 `- **#NNN** …` 锚点提升为 `## #NNN …` 真标题，并删掉「（供 check-doctor §8e 锚点）」小标题（C-6） |
| **新建** `PITFALLS/sessions/<NN>-<slug>.md` | 为 #527–#533、#579–#592、#603–#608 共 **27 条**建正文，模板见 C-2 ②（每条正文 5–20 行 + 证据指针指回原 report） |
| `PITFALLS/README.md` | ① `:8` 后追加 C-3 的「正文落点唯一」规则行；② 把 36 条 `](../reports/…)` 索引行的目标改为新 `sessions/…` 文件、并把每行瘦身到 ≤800 B（结论从索引移出，落到新建正文）；③ 表尾追加 C-7 的 `283` 行；④ 为 C-4 的 10 个隐形条目补索引行 |
| `PITFALLS/sessions/15-过时废弃功能缺陷登记.md` | ① 替换 §15.7 的「1–261 现已一号一条」结论句（C-8）；② 表尾追加 C-5 的空号留痕行 |
| `scripts/doctor/s07-08-docs.py` | 收紧悬空门：粗体支路只出诊断、不再喂 `DANGLING`（C-6 末）；可选：把 `INDEX.md`/`PITFALLS §15.7` 的手写计数纳入 `COUNT_RULES`（C-8） |
| `INDEX.md` 或 `TASKS/README.md` 对应行 | 追加指向本报告的指针（消掉 `check-doctor --only 8` 的 `报告无人引用` WARN） |

**批次 4 收口验收（全绿即完成）**：

```sh
bash scripts/check-doctor.sh --only 8          # 期望 FAIL=0 WARN=0（除本报告指针补齐前）
python3 -c "print(sum(1 for ln in open('PITFALLS/README.md',encoding='utf-8') if ln.startswith('|') and '](' in ln and len(ln.encode())>800))"   # 0
rg -c '\]\(\.\./reports' PITFALLS/README.md    # 期望：仅剩「证据指针」用途，索引列 0
rg -n '^#{1,4} [0-9]{1,3}\. ' PITFALLS/sessions/*.md | wc -l   # 0（未受管标题形式清零）
python3 - <<'PY'   # 撞号自查（三种定义形式并集；当前基线 = 6 个：#53 #192 #282 #283 #284 #285）
import re,glob,collections
d=collections.defaultdict(set)
for f in glob.glob('PITFALLS/sessions/*.md'):
    for ln in open(f,encoding='utf-8'):
        line=re.sub(r'`[^`]*`','X',ln)
        for pat in (r'^#{1,4}\s+#?(\d{1,3})\.\s', r'^(\d{1,3})\.\s+\*\*', r'^#{1,4}\s+#(\d{1,3})\b'):
            m=re.match(pat,line)
            if m: d[m.group(1)].add(f)
print([ (n,sorted(x.split('/')[-1] for x in v)) for n,v in d.items() if len(v)>1 ])
PY
```

### 明确**不做**的事（避免误伤）

- **不重排编号、不补号**（`15-…md` §15.7 的既有规则；本报告 C-5 的空号一律「留痕」而非填充）。
- **不删除任何 `sessions/*.md` 文件**：§A 的「删」全部指 `.pi/memory/` 内的重复**条目行**；PITFALLS 侧一律「保留编号 + 改指针」。
- **不动 `archive/topics/pitfalls-archive-20261014.md`**（作废条目全文存档，按 §15.7 的规则原位保留）。
- **不碰设备**：本审计全程零 `adb/fastboot/ssh`；§A9/§B7 的入口裁决只是**引用**已存在的 `TASKS/README.md` §4 与 `reports/script-redundancy-audit-20261112.md`，不重跑任何入口实验。
