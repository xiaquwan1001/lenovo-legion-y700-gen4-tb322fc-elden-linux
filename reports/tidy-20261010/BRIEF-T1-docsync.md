# T1 任务简报 — INDEX/TASKS/DEVICE 进度同步（提案模式）

你是 y700-elden 项目（cwd /home/xuqianhui1001/y700-elden）的文档整理提案子代理。
**领域层文档（INDEX/TASKS/DEVICE/RESOURCES/PITFALLS）与 versions/ 是父代理（integrator）专属，你绝对不可修改。**
你的全部产出只写入新文件：`reports/tidy-20261010/index-tasks-device-edits.md`。

## 背景
文档分层 SSOT：INDEX.md=唯一入口+现状指针（不复述数字）；TASKS.md=唯一任务台账（§0 进度总览、§1 G1 任务行、§5 查漏补缺 Q 表、§7 上游化）；DEVICE.md=设备/单元台账（§1.1 U2 在机状态）。2026-10-10 的 Q28 调试轮产出大量新结论，全部**未同步**进这三份文档。

## 权威输入（按优先级，先读 1 和 2）
1. `reports/q28-DOSSIER.md` —— Q28 权威汇总：根因已定案（bonded 双 DSI 首条 DCS 命令的**命令 DMA 引擎 hang**，~60% 冷起；L2 DPU ctl reset -22 是下游）；冷起失效有 **NOCARD / STORM 两种模式**；判据=SSH 读全 dmesg+查 card0（串口 logger 会漏 0–20s）；§f=5 个未决+下一步优先级；§g=6 条旧报告不一致（以 DOSSIER 为准）。
2. `reports/q28-handoff-20261010.md` 顶部横幅时间线（**后面的横幅推翻前面的**；§3 的 cherry-pick 方案已被推翻）。
3. `reports/q28-upstream-diff-20261010.md`（上游 2028280686f4 对本树 NOT-IN-TREE、逐字移植无效，Method B 是按机制自落）；`reports/q28-two-layers-20261010.md`（正文初判被其顶部★横幅推翻，只信顶部）。
4. PITFALLS.md 条目 #162–#165（用 grep 定位）：#162=make olddefconfig 删 ARCH_QCOM 导致 **vk81/82/83 是无 QCOM 驱动的死内核、作废**；#163=Q28 冷/暖方向修正（冷起基本失败、暖起基本成功，与时间无关）；#164/#165=根因与 GOOD 判据修正。
5. `git log --oneline -15` 看本轮历史；工作区未提交的 reports/、patches/q28-*、scripts/q28-*、out/*vk84*.manifest 都是本轮产物。

## 必须产出的修改建议（至少覆盖 A–F）
**A. TASKS.md §0**：『内核迭代至 vk83』行更新到 vk84（vk84-q28delay A/B 对、config=恢复好档 a80cbabb）；**关键**：vk81/82/83 已被 #162 判死（无 QCOM 驱动），凡在这三个镜像上得到的上机结果（见 C 条）一律失效或存疑，按证据链写『作废，需好档重测』，不要照抄旧结论。

**B. TASKS.md Q28 相关行（§0 阻塞项速览 + §5 Q28 行 + §1 若有对应行）**：按 DOSSIER 重写——根因定案、双模式 NOCARD/STORM、判据修正（card0 有无才是判据；DSI PLL lock failed×4 是良/坏都有的开机噪声，#165）、下一步（①先定 fastboot-boot 冷路径是否等价真 POR；②Method B 重出到 vk85（generic dsi_link_clk_set_rate_6g 落点、非 cherry-pick）；③三臂冷起 A/B 需用户断电配合；④若取整无效转 CMD engine 编程/PHY pll save-restore；⑤采 GOOD 冷暖对照坐实基线）。

**C. TASKS.md G1-22/G1-33（Q24 熄屏×相机）**：现在写着『2026-10-10 根治三路无效：E4a vk81 熄屏即死、FIX-3 vk82 卡 logo、FIX-2 vk83 破启动』——这三条**全部是在死内核（#162）上测的**，症状（卡 logo/破启动/睡死）正是无 QCOM 内核的预期表现。核实该推理链后把状态改为『10-10 三条验证因死内核作废，需好档重做』（历史结论 H1/H2/D1/D2 样本不受影响，保留）。另记一句：vk71-mxc/mxnom 变体按用户裁决（DT 变体扫测不再排期）收口、从 inflight 白名单移除（账目由父执行）。

**D. INDEX.md §3**：① Q28 条目按 DOSSIER 更新（保持指针风格，细节指 TASKS/DOSSIER）；② Q24 条目『根治三路全部无效』同步改死内核作废口径；§5 目录速查表加一行 `reports/`（活跃主题工作区；主题定案后证据迁 archive/topics/ 归档层）。

**E. DEVICE.md §1.1**：先读现有格式，补 2026-10-10 离线快照：boot_b=vk64 持久直启未动（vk74/vk84 仅 RAM 取证、永不作 boot_b）；本轮整理时 adb/fastboot 均无设备在场；主机串口 logger=scripts/serial-logger.sh（pid 文件 /tmp/q28_serial_logger.pid，主机重启需重跑）。

**F.『下一轮入口』类段落**（INDEX/TASKS 若有）：按 DOSSIER §f + 现存未解更新（Q28 vk85 冷 A/B〔需用户断电〕、#106 死挂装弹待命中、Q24 好档重做三路、M1–M5 上游化、G1-8 基准、kexec crashkernel 串口重测、dt-ui 三项已裁决非主线）。

## 输出格式（严格遵守）
每个修改一节：目标文件、位置说明、理由（引来源 DOSSIER/handoff/#16x），然后：

<<<OLD file=TASKS.md
（与目标文件**逐字节一致**的原文，≤1200 字符，全文件唯一——写前用 grep -F 验证出现次数=1；原文太长时 OLD 只取该句最独特的一小段，但须字节精确）
===
（替换后文本）
>>>

口径纪律：INDEX 不写任务细节只留指针；数字/样本数/日期照权威输入不编造；不确定的写『待复核：…』。

## 禁令
不修改仓库任何既有文件（只新建你的产出文件）；不执行 git 写命令（add/commit/checkout/branch/tag…）；不碰设备（adb/fastboot/ssh 192.168.7.1）；不跑 check-doctor/vk-identity/构建脚本；不读 .pi/sessions/*.jsonl（太大）。

## 完成回报
写了哪些节、每节 OLD 块唯一性验证结果、发现但没写成 edit 的疑点清单。
