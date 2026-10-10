# T1 修改建议 — INDEX/TASKS/DEVICE 进度同步（提案，交 integrator 落盘）
> 本文件是 worker 的**只读提案**：不改任何既有文档；下面每个 `<<<OLD … === … >>>` 块的 OLD 均为从目标文件**逐字节提取**（脚本内 `count==1` 断言通过），integrator 可直接套用。口径：INDEX 只留指针、数字/样本/日期照权威输入（`reports/q28-DOSSIER.md`、`reports/q28-handoff-20261010.md`、`reports/q28-upstream-diff-20261010.md`、`PITFALLS #162–#165`），不确定的写「待复核」。
> **本轮权威口径摘要**：Q28 根因已定案=**bonded 双 DSI 首条 DCS 命令的命令 DMA 引擎 hang**（~60% 冷起，L2 DPU ctl reset -22 为下游）；冷起失效有 **NOCARD/STORM 两模式**；判据=**SSH 读全 dmesg + 查 card0**（串口 logger 漏 0–20 s）。**`PITFALLS #162`：vk81/82/83 因 `make olddefconfig` 删 `ARCH_QCOM` = 无 QCOM 驱动的死内核、作废**——凡在这三镜像上得到的上机结果一律作废、需好档重测。

---

## A · TASKS §0 内核迭代行（vk83 → vk84，并标 vk81/82/83 死内核作废）

### 修改 A

**目标文件**：TASKS.md

**位置**：§0 进度总览 · 「运维/资产」行「内核迭代至 vk83」

**理由**：DOSSIER B5/C13（vk84 base/exp 单变量对，唯一差 cmdline delay）、`PITFALLS #162`（vk81/82/83 无 QCOM 驱动的死内核、作废）、handoff §1（好档=config sha a80cbabb）。任务 A：迭代行更新到 vk84，并把 vk81/82/83 标死内核作废。

```
<<<OLD file=TASKS.md
内核迭代至 **vk83**（vk79 E0 诊断 / vk81 E0+E4a / vk82 FIX-3 已 revert / vk83 FIX-2，均 vermagic-一致模块 tar + manifest；
===
内核迭代至 **vk84-q28delay**（base/exp 单变量 A/B 对，唯一差 cmdline `dsi_cmd_delay_us=1000`；config=恢复好档 `patches/config-before-fragment-20261009-210432.bak`（sha a80cbabb）系、含 QCOM 驱动非死内核；镜像 `out/boot-elden-vk84-q28delay-{base,exp}.img`+manifest）。**⚠ 作废：`PITFALLS #162` 判定 vk81/82/83 因 `make olddefconfig` 删 `ARCH_QCOM` 成无 QCOM 驱动的死内核 ⇒ 在这三个镜像上得到的上机结果一律作废、需好档重测**；
>>>
```

---

## B · TASKS Q28 行按 DOSSIER 重写（§0 阻塞项速览 + §5 Q28 行）

### 修改 B1

**目标文件**：TASKS.md

**位置**：§0 进度总览 · 「G1 阻塞项速览」行 Q28 段

**理由**：DOSSIER a/b/f（根因定案、双模式 NOCARD/STORM、冷 A/B 仅 T1=NOCARD n=1、下一步 vk85）、`PITFALLS #163/#164/#165`。任务 B（§0 阻塞项速览部分）。

```
<<<OLD file=TASKS.md
🟡 Q28 显示间歇（**首次好/坏寄存器差分到手**；dmesg 级判据已立；剩三个单变量实验）
===
🟡 Q28 显示间歇（**根因已定案**=bonded 双 DSI 首条 DCS 命令的命令 DMA 引擎 hang，~60% 冷起；冷起失效有 NOCARD/STORM 两模式，判据=SSH 读全 dmesg + 查 card0；**冷 A/B 仅 1 次且撞 NOCARD，剩 Method B→vk85 冷 A/B**；细节见 `reports/q28-DOSSIER.md`、`TASKS.md` §5 Q28）
>>>
```

### 修改 B2

**目标文件**：TASKS.md

**位置**：§5 查漏补缺 · Q28 行「怎么测/状态」正文末句「下一步 = 再抓一发坏发与基线对拍」

**理由**：DOSSIER a/b/d/e/f（根因定案、双模式对比表、判据修正、候选修法状态、未决+下一步 5 步）、`PITFALLS #164/#165`、upstream-diff §3–5（NOT-IN-TREE、非 cherry-pick）。任务 B（§5 Q28 行按 DOSSIER 重写）。

```
<<<OLD file=TASKS.md
**下一步 = 再抓一发坏发与基线对拍**
===
**【2026-10-10 定案，权威=SSOT `reports/q28-DOSSIER.md`，覆盖本行上文全部旧推断】** 根因=L1：bonded 双 DSI 首条 DCS（`ff 20`）命令 DMA 引擎 hang（~60% 冷起，hang 时 STATUS0=0x20003、TRIG_DMA=0x1 自不清；L2 DPU `ctl 1 reset failure -22`/frame done/vblank 风暴 = L1 下游，非独立 bug；`PITFALLS #164`）。冷起失效有两模式（`#165`）：NOCARD（无 card0，~0.86 s DSI host probe `DSI PLL(0) lock failed` → display-subsystem 组件没聚齐）与 STORM（有 card0 的 cmd-DMA 风暴）；两者同指一根=冷起首次 DSI PLL/PHY 未稳定锁定。**判据修正**：三态 NOCARD/STORM/GOOD，判显示必须 SSH 读全 dmesg + 查 `card0` 有无（串口 logger 重连漏 0–20 s；只数风暴签名会把 NOCARD 误判 GOOD）；`DSI PLL lock failed`×4 与 `Failed to create device link` 在 GOOD 冷/暖起也出现（DOSSIER §f-2/§g-2，良性/会重试成功），card0 有无才是判据、不是这两行。**下一步（DOSSIER §f，冷起需用户断电配合）**：① 先定 `fastboot boot` 冷路径是否等价真 POR（不等价则用真 POR 做 A/B）；② Method B 按上游「加」部分重出到 vk85（落点 generic `dsi_link_clk_set_rate_6g()`、对象 `msm_host->byte_clk`，非 `_v2_9` 分支、非 `dsi_calc_clk_rate_6g`、非 cherry-pick `2028280686f4`——本树 7.2 基线三 commit 全 NOT-IN-TREE，逐字移植无效）；③ 三臂冷起 A/B（base vs round vs delay/CLK_STATUS 轮询），每轮 `scripts/q28-devprobe.sh` 三态判 + SSH 读全 dmesg + 查 card0；④ 若取整仍高坏发转 CMD engine 编程 / PHY `save/restore_pll_state`；⑤ 采 GOOD 冷暖对照坐实 DSI_PLL/device-link 基线。*
>>>
```

---

## C · TASKS §1 G1-22（Q24 根治三路 = 死内核上测，作废需好档重做）

### 修改 C

**目标文件**：TASKS.md

**位置**：§1 G1-22 行末「🆕 E4a（MXC 单票，vk81）…驱动侧两条路也均无效/破启动」段

**理由**：`PITFALLS #162`、DOSSIER C16/§g、handoff §1。任务 C：E4a/FIX-3/FIX-2 三条 10-10 验证在死内核上测得⇒作废需好档重做；历史 H1/H2/D1/D2 样本保留。G1-33 行（§1）不含 vk81/82/83 三路声明（其 H1/H2/D1/D2 为 vk63 好档样本），故本任务对 G1-33 不产 edit（见文末疑点①）。

```
<<<OLD file=TASKS.md
**🆕 E4a（MXC 单票，vk81）：2026-10-10 上机熄屏即睡死关机 ⇒ 换轨（MX/MXC/MX_AO）全部无效；FIX-3（vk82）卡 logo 已 revert、FIX-2（vk83）破启动（卡 logo/内核不响应）⇒ 驱动侧两条路也均无效/破启动，详见 §5 条 3 与 `.pi/plans/2026-10-10-E4a-FIX1-DT.md`**
===
**🆕 10-10 三条验证作废（2026-10-10 整理，`PITFALLS #162`）**：上文 E4a（vk81）/FIX-3（vk82）/FIX-2（vk83）的 10-10 上机判定（熄屏即死 / 卡 logo / 破启动）全部是在死内核上测的——`make olddefconfig` 删了 `ARCH_QCOM`（连带 DRM_MSM/DSI/rpmh 全无），这三镜像是无 QCOM 驱动的死内核，症状（卡 logo/破启动/睡死）正是无 QCOM 内核的预期表现，不能当「根治三路无效」的证据 ⇒ 三条验证作废、需恢复好档（`patches/config-before-fragment-20261009-210432.bak`，sha a80cbabb）重做。历史 H1（7/9）/H2/D1（6/9）/D2（7/9）样本在 vk63 好档上取得，不受影响、保留。待复核：vk81 曾报「相机加载成功 + 桌面起来」与死内核判定矛盾（无 QCOM 内核不应出桌面），归属请 integrator 复核**
>>>
```

---

## D · INDEX §3 Q28/Q24 指针更新 + §5 目录速查加 `reports/` 行

### 修改 D1

**目标文件**：INDEX.md

**位置**：§3 现状速览 · 未解 ① Q28 条目（整条）

**理由**：DOSSIER a/b（根因定案、双模式、判据）+ 口径纪律「INDEX 不写任务细节只留指针」。原条目复述寄存器差分值，违反指针风格且数字易漂，改为指针。任务 D①。

```
<<<OLD file=INDEX.md
① **Q28 显示间歇失败**（只有背光无桌面）→ 日常可用性第一道门。**已拿到首个好/坏同口径差分**：断点 = 面板首条 DCS 写走 **bonded 命令 DMA 超时**（不是 DPU modeset），只有 `STATUS0 0x0→0x20003`、`CLK_STATUS 0x2343→0x3743`（多 `DYN_PCLK_ACTIVE`+`DYN_CMD_PCLK_ACTIVE`）、`cmd_dma_busy/cmd_engine_busy 0→1` 四项不同 ⇒ 假说收窄到「首次 modeset 命令引擎撞 DYN 像素时钟域切换」；**dmesg 级判据**：`command DMA timeout`+`panel init attempt failed`（同批 5 坏/2 好零误报；`vblank timeout` 单独用会误判）；剩三个单变量实验（delay / busy 重触发 / 查谁开 DYN pclk）。详见 `.pi/plans/2026-10-09-深夜-Q28寄存器差分-模块化在机验证-槽位险情.md` §1；
===
① **Q28 显示间歇失败**（只有背光无桌面）→ 日常可用性第一道门。**根因已定案**=bonded 双 DSI 首条 DCS 命令的命令 DMA 引擎 hang（冷起 ~60%；冷起失效有 NOCARD/STORM 两模式；判据=SSH 读全 dmesg + 查 card0）。细节/样本/下一步一律不在此复述，权威=`TASKS.md` §5 Q28 与 `reports/q28-DOSSIER.md`（SSOT）；
>>>
```

### 修改 D2

**目标文件**：INDEX.md

**位置**：§3 现状速览 · 未解 ② Q24 条目「2026-10-10 根治三路全部无效」句

**理由**：`PITFALLS #162`、DOSSIER §g/C16。任务 D②：Q24 条目「根治三路全部无效」同步改死内核作废口径。

```
<<<OLD file=INDEX.md
**2026-10-10 根治三路全部无效**：换轨（E4a MXC 单票 vk81 熄屏即死）+ 驱动侧（FIX-3 vk82 卡 logo 已 revert、FIX-2 vk83 破启动）⇒ 剩定位手段 = ttyACM0 串口；v2 上游报告已重发（10-08 原邮件未进 lore 归档）；
===
**2026-10-10 根治三路验证作废（`PITFALLS #162`）**：E4a vk81 / FIX-3 vk82 / FIX-2 vk83 三条都是在无 QCOM 驱动的死内核上测的，症状即无 QCOM 内核的预期表现，非「根治无效」证据 ⇒ 作废、需恢复好档重做（历史 H1/H2/D1/D2 样本不受影响）；v2 上游报告已重发（10-08 原邮件未进 lore 归档）；
>>>
```

### 修改 D3

**目标文件**：INDEX.md

**位置**：§5 目录速查 · 表末（`archive/2026-10-02-merged/` 行之后新增一行）

**理由**：任务 D③：目录速查表补一行 `reports/`（活跃主题工作区，定案后迁 archive/topics/ 归档层）。Q28 过程稿当前即活在 reports/。

```
<<<OLD file=INDEX.md
`archive/2026-10-02-merged/` | **本轮合并掉的旧文档原文**（MISSION-SCOPE/DEVICES/ANDROID-COMPAT-PLAN/ROUTE-DECISION/PLAN-NODEV/DOCS-CHANGELOG）
===
`archive/2026-10-02-merged/` | **本轮合并掉的旧文档原文**（MISSION-SCOPE/DEVICES/ANDROID-COMPAT-PLAN/ROUTE-DECISION/PLAN-NODEV/DOCS-CHANGELOG）
`reports/` | **活跃主题工作区**：进行中主题的专题/取证稿所在（如 `reports/q28-DOSSIER.md` 为 Q28 单一事实源）；主题定案后证据迁 `archive/topics/` 归档层
>>>
```

---

## E · DEVICE §1.1 补 2026-10-10 离线快照（boot_b=vk64 未动 / 无设备在场 / 串口 logger）

### 修改 E

**目标文件**：DEVICE.md

**位置**：§1.1 内核与软件基线 · 在机基线（vk64）条目之后新增两条

**理由**：任务 E + handoff §0/顶部横幅（boot_b=vk64 持久直启未动、vk74/vk84 仅 RAM 取证永不作 boot_b；logger=scripts/serial-logger.sh + pid 文件；重启需重跑）。DOSSIER B4/§g-3（判显示须 SSH 读全 dmesg + 查 card0，串口漏 0–20 s）。

```
<<<OLD file=DEVICE.md
kexec 已定论不可用（见 `TASKS.md` §4）。提交号：Linux 侧提交的唯一入口 = `TASKS.md` §7。
===
kexec 已定论不可用（见 `TASKS.md` §4）。提交号：Linux 侧提交的唯一入口 = `TASKS.md` §7。
- **2026-10-10 离线快照（Q28 调试轮收尾；本轮整理时 adb/fastboot 均无设备在场）**：boot_b **持久直启仍 = `vk64`（未动）**；本轮 vk74/vk84 仅 `fastboot boot` RAM 取证，**永不作 boot_b**。Q28 根因/双模式/判据/下一步见 `reports/q28-DOSSIER.md`、`TASKS.md` §5 Q28。
- **主机串口 logger** = `scripts/serial-logger.sh`（pid 文件 `/tmp/q28_serial_logger.pid`，常驻；主机重启需重跑）。**判 Q28 显示不能只靠串口 logger**（重连会漏 0–20 s，盖住 NOCARD 的 0.86 s 现场），须 SSH 读全 dmesg + 查 `card0`。
>>>
```

---

## F · TASKS §4「下一步（下一轮入口）」Q28/Q24 两项更新

### 修改 F1

**目标文件**：TASKS.md

**位置**：§4 下一步 · 第 1 项 Q28「下一步三个单变量实验」句（下一轮入口）

**理由**：DOSSIER §f（下一步优先级 5 步）。任务 F：按 DOSSIER §f 更新「下一轮入口」Q28 项为 vk85 冷 A/B（需用户断电）。

```
<<<OLD file=TASKS.md
**下一步三个单变量实验**（代价序）：① 命令 DMA 触发前插 delay；② 超时后若 engine 仍 busy 则 reset 引擎重试一次；③ 查是谁开了 DYN pclk（`logs/q28-BAD-vk75dump-*/state.txt` 已存）。详见 `.pi/plans/2026-10-09-深夜-Q28寄存器差分-模块化在机验证-槽位险情.md` §1。
===
**下一步（2026-10-10 定案后更新，权威=`reports/q28-DOSSIER.md` §f）**：① 先定 `fastboot boot` 冷路径是否等价用户真 POR 冷起（不等价则改用真 POR 做 A/B）；② Method B 按上游「加」部分重出到 vk85（落点 generic `dsi_link_clk_set_rate_6g()`、对象 `msm_host->byte_clk`，非 `_v2_9` 分支、非 cherry-pick `2028280686f4`）；③ 三臂冷起 A/B（base vs round vs delay/`REG_DSI_CLK_STATUS` 轮询），需用户断电配合，每轮 `scripts/q28-devprobe.sh` 三态判 + SSH 读全 dmesg + 查 card0；④ 若取整仍高坏发转 CMD engine 编程 / PHY pll save-restore；⑤ 采 GOOD 冷暖对照坐实基线。判据/根因详见 §5 Q28 与 `reports/q28-DOSSIER.md`。
>>>
```

### 修改 F2

**目标文件**：TASKS.md

**位置**：§4 下一步 · 第 3 项 Q24「2026-10-10 深夜驱动侧两版本上机判定」句（下一轮入口）

**理由**：`PITFALLS #162`、DOSSIER §g/C16。任务 F：Q24 项改死内核作废 + 下一轮好档重做三路。

```
<<<OLD file=TASKS.md
**2026-10-10 深夜驱动侧两版本上机判定：FIX-2/FIX-3 均破启动链路**——FIX-3（vk82，删 use_rpm + lazy-on + quiesce，`e1d2c658a`）卡联想 logo（probe 读写未 resume 域 MMIO → NoC hang），已 revert（`67fcff7f0`）；FIX-2（vk83，probe 常持票，`86193a58a`）一次卡 logo、一次过 logo 但内核不响应 ssh（只剩充电标志）。vk81（MXC DT + 原版 probe）能启动 ⇒ 剩余定位手段 = ttyACM0 串口抓早期 dmesg；详细判定与下一步见 `.pi/plans/2026-10-10-E4a-FIX1-DT.md` §FIX-3/FIX-2 上机判定。
===
**2026-10-10 E4a/FIX-2/FIX-3 上机判定作废（`PITFALLS #162`）**：这三版（vk81/82/83）经核实是 `make olddefconfig` 删 `ARCH_QCOM` 后的无 QCOM 驱动死内核，「熄屏即死 / 卡 logo / 破启动」是无 QCOM 内核的预期表现，非三路根治失败的证据 ⇒ 作废。**下一轮 = 恢复好档（`patches/config-before-fragment-20261009-210432.bak`，sha a80cbabb）重做 E4a/FIX-2/FIX-3 三路**；历史 H1/H2/D1/D2 样本（vk63 好档）保留不受影响。详见 `reports/q28-DOSSIER.md`（死内核事故 C16）与 `.pi/plans/2026-10-10-E4a-FIX1-DT.md`。
>>>
```

---

## 附 1 · OLD 块唯一性验证
提取脚本对每个 OLD 片段断言「在目标文件中恰好出现 1 次」（`count==1`），全部通过；OLD 长度（字符）：

| 键 | 目标文件 | OLD 长度 | NEW 长度 | 表内 NEW 无竖线 |
|---|---|---|---|---|
| A | TASKS.md | 106 | 349 | 是 |
| B1 | TASKS.md | 49 | 210 | 是 |
| B2 | TASKS.md | 21 | 1129 | 是 |
| C | TASKS.md | 188 | 464 | 是 |
| D1 | INDEX.md | 484 | 214 | 是 |
| D2 | INDEX.md | 149 | 194 | 是 |
| D3 | INDEX.md | 130 | 241 | 不适用(表/多行) |
| E | DEVICE.md | 65 | 454 | 不适用(表/多行) |
| F1 | TASKS.md | 190 | 483 | 是 |
| F2 | TASKS.md | 362 | 391 | 是 |

---

## 附 2 · 发现但未写成 edit 的疑点（交 integrator 裁决）

1. **G1-33（§1）不含 vk81/82/83 三路声明**：任务 C 点名「G1-22/G1-33」，但「2026-10-10 根治三路无效（E4a vk81/FIX-3 vk82/FIX-2 vk83）」这段只出现在 **G1-22（§1 行 35）**、**§4 下一步第 3 项**与 **INDEX §3**。G1-33 行只有 H1/H2/D1/D2（vk63 好档样本，保留），无死内核上测内容，故**未对 G1-33 产 edit**。若 integrator 认为 G1-33 也应加一句「三路验证作废见 G1-22/§4」指针，可自加。
2. **§5 Q24 行同样只含 H1/H2/D1/D2（vk63 好档）**，无 vk81/82/83 三路声明，不受死内核作废影响，未产 edit。
3. **vk84 实际 config sha 与 a80cbabb 不一致**：任务 A/DOSSIER 称 vk84「config=恢复好档 a80cbabb」，但 `out/boot-elden-vk84-q28delay-*.manifest` 记 `config_sha256=a383cdb99dfe…`（≠ 好档备份 a80cbabb）。推断：a383cdb9 = 好档(a80cbabb) + 模块化片段(olddefconfig 修好后) 派生的构建 config；且 vk84-exp 冷起出 `DSI PLL probe` 现场 ⇒ 确含 QCOM 驱动（非死内核），方向不受影响。edit 里用「恢复好档 a80cbabb **系**」表述并在 A 段留痕，**待复核**：请 integrator 确认对 vk84 应记 a383cdb9（构建态）还是 a80cbabb（好档基线）。
4. **vk81「相机加载成功 + 桌面起来」与死内核判定矛盾**：G1-22/§4 记录 vk81 E4a 曾「相机 10 模块加载成功 + 桌面起来、熄屏即死」，但 #162 判 vk81 无 QCOM 驱动（不应出桌面/不应加载 camss）。两者不能同真。edit C 里以「待复核：归属请 integrator 复核」保留该矛盾，未擅自删除历史观测。若确为死内核，则该「桌面起来」观测本身也作废。
5. **`DSI PLL lock failed`/`Failed to create device link` 是否良性噪声仍属未决 2**（DOSSIER §f-2/§g-2 仅「初步/强提示」，GOOD 冷暖对照基线尚未正式坐实）。edit B2 已按「良性/会重试成功、card0 有无才是判据」写入，并把「采 GOOD 冷暖对照坐实基线」列为下一步⑤；**待复核**。
6. **DOSSIER §g-1：`reports/q28-orchestration-20261010.md` 正文冷/暖方向仍与 #163 相反**（磁盘上未真正纠正）。此为 reports/ 内不一致，非 INDEX/TASKS/DEVICE 范围，本任务未碰；提请 integrator 决定是否单独修正该过程稿。
7. **vk85 尚未存在**：edit 中「重出到 vk85」是按 DOSSIER §f/upstream-diff §5 的**计划**表述（vk85 未编、未 apply、未上机）。若 integrator 倾向「先编再写台账」，可把 vk85 措辞降级为「计划中」。
8. **未纳入本轮 edit 的 F 类开放项**（#106 死挂装弹待命中、M1–M5 上游化、G1-8 基准、kexec crashkernel 串口重测、dt-ui 三项非主线）：这些在 **INDEX §3「未开工 / 已定不做」段与 TASKS §4** 现有条目里已在位且与 DOSSIER 无冲突，无需改动；仅 Q28（F1）与 Q24（F2）两项因本轮定案/作废结论而需更新，已产 edit。
