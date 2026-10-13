# 工作区索引 — TB322FC "elden"（SM8750P）固件与驱动研究

> **入口。** 新会话：本文件 §1（使命）→ §2（文档分层）→ §3（现状）→ 需要细节再进对应文档/专题档案。
> **唯一入口 = 本文件**；根目录 9 份 `.md` = 6 内部维护 + `AGENTS.md` + 公开 `README`/`PROGRESS`（三层入口见 §2）。
> 2026-10-03：git 纳管 + 文档收敛（12→6）；自检 `scripts/check-doctor.sh`；不再有 SQLite/生成物。

---

## 1. 使命与范围（8 行）

1. **机型唯一**：只研究 **TB322FC / elden / SM8750(P)**；不做别的机型移植。研究面 = 让本机在主线 Linux 上功能完整。
2. **设备等价**：同型号多台单元**物理地位完全等价**，唯一差异 = **容量**（内存/UFS → GPT 数值）。
   身份 = `(SN, hwboardid, 容量)`；**"新机/旧机"不是角色**，**任务按单元当前状态分派**。
3. **G1 完整 Linux + 上游化**：跑**功能健全的 Linux**，**正常驱动原厂全部固件**（ADSP/CDSP/WCN/GPU/触屏/触觉/功放/tplg/相机…）；
   达到上游规范后**按模块向上游提交**（checkpatch/DTC/`dtbs_check` 绿，见 `TASKS.md` §7 M1–M5）。
4. **G2 安卓容器**：**无 Android 宿主**下运行安卓（主路线 Waydroid，备胎 redroid）；核心验收 = **可用性 + 风控/完整性等级**：
   GMS 登录、**Play Integrity / SafetyNet**、Widevine 能做到哪一级（**取证判定，不预设"不可能"也不承诺**；见 `RESOURCES.md` §1.3、`TASKS.md` §6）。
5. **G3 x86 模拟运行**：以 **Steam 游戏**为验收载体，跑通 x86 用户态/游戏（Box64 + Wine/Proton 线）。
6. **拓展（非主线）**：**UEFI 间接引导**、**Gunyah 高通虚拟化做 VM**——不阻塞 G1–G3，现状/裁决见 `TASKS.md` §4/§5。
7. **Linux 存储容量不固定**：按项目体量估算后一次给足（`DEVICE.md` §3），并可回收 Android 专属分区扩容。
8. 术语：设备称 **U1 / U2**；备份目录 `backup/<SN>-<容量档>/`；禁用 `new-tablet` 与"两轨分机"旧口径。

---

## 2. ★ 文档分层（入口最少）

> **单一事实源（SSOT）**：每个数字/结论只在一个文件维护，其余用链接引用。
> **根目录 9 份 `.md` = 三层入口**：① **内部维护层 6 份**（SSOT，唯一维护面）：`INDEX`（本文件）· `DEVICE` · `TASKS` · `RESOURCES` · `RUNBOOK-BRINGUP` · `PITFALLS`；② **项目身份层**：`AGENTS.md`；③ **公开面**：`README.md`（GitHub 门面）· `PROGRESS.md`（外部进度线）。
> **公开层豁免**：`README`/`PROGRESS` 可摘要复述领域层事实，但**完成度 / 未解等数字只认 `TASKS.md` §0，本层只给指针不复述**。`check-doctor` 校验根目录 md = 9。
> **推荐阅读顺序**：本文件 → `.pi/AGENT-OPS.md`（做事规范）→ `TASKS.md`（任务/进度/未解）→ `PITFALLS.md`（动手前扫）→ 需要时再进 `DEVICE`/`RESOURCES`/`RUNBOOK`。

### 入口（唯一）

| 文件 | 装什么 |
|---|---|
| **`INDEX.md`** | 使命与范围、分层地图、现状快照、快速命令、专题档案索引 |

### 1 分钟版（新人 / 第一次会话）

1. **本文件 §1**（使命 8 行）→ 知道「在做什么、不做什么」。
2. **`TASKS.md` §0**（总览表）→ 知道「做到哪、什么卡着」。
3. **`PITFALLS.md` §0**（零号纪律 4 条）→ 知道「动手前必须先做什么」。

需要做事时再按下方分层按需展开其余文件；完整规范见 `.pi/AGENT-OPS.md`。

### 规范入口（agent 行为唯一入口）

| 入口 | 文件（权威） | 装什么 |
|---|---|---|
| **行为/规范** | **`.pi/AGENT-OPS.md`** | agent **自主优先**（写坏风险先备份，超出预期的错误才上报）、物理干预边界、设备安全纪律、研发纪律、文档写入权限、汇报/时间盒；并发细则见 `.pi/CONCURRENCY.md` |

> 项目描述（机型/目标/设备等价）在 `AGENTS.md`；根目录 6 份维护文档不再复述规范与经验。

### 领域层（4 份，唯一维护面）

| 角度 | 文件（权威） | 装什么 |
|---|---|---|
| **设备状态 + 设备描述** | **`DEVICE.md`** | 机型规格、固件清单与通路、驱动矩阵、单元台账 U1/U2、状态→任务分派、GPT 参数、**§3 Linux 容量策略** |
| **任务 / 进度 / 未解 / 方案** | **`TASKS.md`** | **唯一任务台账 + 进度权威**（§0）；G1/C/A 任务（§1–4）；**§5 查漏补缺（GAPS/Q1–Q30；Q27 从无此号）**；**§6 G2 安卓兼容方案**；**§7 上游化（M1–M5）** |
| **资源 / 资产 / 会话轨迹** | **`RESOURCES.md`** | §1 外部参考 · §2 本地资源 · **§3 文件与资产台账（git 边界/可清理）** · **§4 会话索引（数字 SSOT；实机边界）** |
| **上机手册** | **`RUNBOOK-BRINGUP.md`** | 任一单元从原厂状态做到 b 槽直启 + 持久根的 Phase −1…9 |

### 经验层（1 份）

| 文件 | 装什么 |
|---|---|
| **`PITFALLS.md`** | **开发经验唯一入口**：**§0 零号纪律**（动手前先做四件事）+ 踩坑正文（按主题编号，范围见 `PITFALLS` 头部）+ **§15 过时/废弃/功能缺陷登记**（DEPRECATED） |

### 证据层（`archive/`，追加为主）

> 专题档案＝**过程证据**；结论一律以领域层为准，archive 不得被引用为「当前结论」。
> **追加为主**；允许为更正错误 / 回填结果做带日期的最小修订（不改写既有结论口径，权威恒在领域层）。

### 机器可查（无 SQLite，无生成物）

- 文本搜索：`rg` / `grep`（`PITFALLS.md` 找踩坑、`RESOURCES.md` 找资源、`TASKS.md` 找任务）。
- 会话回忆：pi 原生会话选择器（`/resume`）+ `rg .pi/sessions`。
- 结构自检：`scripts/check-doctor.sh`（计数/死链/口径冲突/vk 版本账 §5+§5d）。
- 版本对账：**`versions/vk-kernel-identity.tsv`**（构建号 ↔ 内核二进制 ↔ 源提交，含每个镜像的失真标记）。
  它是本目录**唯一入 git 的派生表**（破例理由：兼作版本欠账账本）；由 `scripts/vk-identity.py` 重生成，
  `check-doctor` §5d 强新鲜度（过期即 FAIL）。“vkN 是什么”的口径见 `PITFALLS` #135。

---

## 3. 现状速览（指针，不复述状态）

> **SSOT**：任务状态、完成度、样本数一律以 `TASKS.md` §0（总览）/ §1（G1）/ §5（Q 项）为准；
> 单元与镜像形态以 `DEVICE.md` §1.1/§2.2 为准。**本节只回答「现在还没解决什么」，任何数字都不在此维护。**

- **完成度**：见 `TASKS.md` §0（数字唯一权威；本文件不复述，见 §2 公开层豁免）。
- **Linux 侧未解（3 项，按影响排序）**：
  ① **Q28 显示间歇失败**（只有背光无桌面）→ 日常可用性第一道门，**未解、`boot_b` 仍 = `vk94`**。当前口径（2026-10-12 深夜）：L1 根因 = bonded 双 DSI 首条 DCS `ff 20` 的命令 DMA 引擎 hang，**坏发 ~50%、逐启动随机、按时间成簇（会话级），与镜像/构建身份无关**（旧「构建身份伪影」定案**作废**，`PITFALLS #217/#223`；3 位身份仅降险偏置）；**故障态不在 DSI 控制器内部**（DYN pclk 域闩住、`sw_reset` 后仍在）；七臂 vk116–vk122 + vk123 **全部否证**（+ vk125 复位终态对齐寄存器级否证）；原厂 dispcc/INTF 静态对照后主靶削弱；**恢复只能整机复位**，日常可用性靠看门狗兜底（~50%→~75%）。判据 = 三态（NOCARD/STORM/GOOD）+ SSH 全 dmesg + `card0` + ≥60 s 存活门 + **真实 POR**。**2026-10-13**：报告已发并归档；回移候选 `vk124-merged` **取得 1 次 GOOD 冷起 + 功能验收全绿 ⇒ T1 达标**（写 `boot_b` 需用户在场）。**🆕 2026-10-13 深夜（上游显示栈对照 P1–P2c，`reports/p1-upstream-dsi-20261013.md`）**：纯上游 7.3-rc7 DSI 点不亮（缺 SM8750 DSI PLL/C-PHY 时钟块，`-22` 早于 Q28 的 `-110`）；**上游 DSI host/manager + vendor PHY（P2b）1 发 GOOD 且无 `command DMA timeout` ⇒ Q28 疑为 vendor DSI 命令路径专有**——⚠️ 2026-10-14 悬置：同镜像复测 4/4 未复现且面板从未实测，见 `reports/p2b-retest-20261014.md`；原文：**（单发，待多发起采样）**；P2c 合成器/`grim` 全 GOOD 但面板只有背光 ⇒ **「点亮」只认面板实测（`PITFALLS #251`）**。**状态/样本数/下一步只读 `TASKS.md` §5 Q28（含历史口径链）与 `reports/q28-dsi-recover-20261012.md`**；过程稿索引 `reports/q28-INDEX.md`。
  ② **Q24 熄屏 × 相机** → 用户裁决 = **互斥二选一**：日常零相机模块（熄屏安全），需要时 `cam-mode.sh on/off`。最小触发 = **`camcc-sm8750` + `cambistmclkcc-sm8750` 配对 + 真实熄屏**（单独任一不触发，历史「cambist 单模块」否证）。**根治未成**；2026-10-12 九轮已收敛：`{camcc}` 单模块不致死首次确证、H1 DT 臂否证、GPU runtime-PM 否定、NoC/BCM 靶否证、致死 = **SoC 级复位 + ~30 s 自动重启**（不需物理 POR）、PMIC PON 块无差异、无硬件看门狗 ⇒ 靶点已是**电气/时序级**；**上游 RFC v3 已于 2026-10-12T08:22Z 发出并归档，2026-10-13 已发同线 follow-up**（引 Kaanapali camcc MCLK 用法 + v7.4 `gcc-sm8750` CX 电源域）；**2026-10-13 复核 3 发（回移台 1 活 1 死、日常 `vk94` 台 1 死）⇒ 复现口径不变**；下一步 = **外部电流/电压测量（需人手）**。详见 `TASKS.md` G1-22/G1-33、§5 Q24 与 `reports/q24-*-20261012.md`。
  ③ **进 GUI 后整机卡死**（`PITFALLS #106`，与 Q28 不同因）→ 已常驻自动取证（`/etc/sysctl.d/99-freeze-trace.conf` + `pstore-catch`），命中即 panic→暖复位→带回全 CPU 栈；暂未复现。
- **本轮已关闭 / 搁置**（不再占未解）：✅ Q26 WiFi（2026-10-10 用户确认）、⚪ G1-6 TF 卡（用户裁决忽略）、✅ G1-34 重力/自动旋转（SSC/QRTR + iio-sensor-proxy；prox/als/compass 已核）、✅ **C10 Waydroid 马达透传**（2026-10-13：容器 HAL ↔ `aw86927` FF 全链路 → 自编 **AIDL V2** 拿到幅度控制与 `cancel` → **固化进 `vendor.img`**（运行期零 bind）→ 补上 **Settings 振动强度档位**（静态 RRO，档位 1→3）；`reports/waydroid-haptics-20261013.md`、`PITFALLS #232–#246`）。
- **未开工 / 进行中**：上游化 **M1–M5**（`TASKS.md` §7；**M1-7.3 重基树已上机 bringup**：显示被 DP 阻塞已解＝纯 ramdisk 缺 `fsa4480` 模块，**亮屏仍无好发**（Q28 同源）；**2026-10-13 深夜上游显示栈对照（P1–P2c）已把上游化缺口收窄到 DSI PHY + 少量 host/manager/mdss（DPU 无需 vendor 改动）**，细节只读 §7）、G1-8 CPU/GPU 基准（GPU 已确认工作 Adreno 830 GLES3.2，待装 glmark2/vkmark 跑数）。
- **模块化载荷线（2026-10-09 深夜已在机验收）**：`/init` 自加载 7 个载荷驱动（1.5–4.4 s）、WiFi 扫描 25 AP + 自动重连、声卡/背光/触屏/触觉全在；`scripts/mod-loop.sh` 热换驱动 **7 s** 上机。两个待决定见 `TASKS.md` §5 条 8.5。
- **相机（2026-10-09 深夜零写盘复验）**：现役 boot_b(vk64/H2) 上 `CAM_FORCE=1 camera-modules-load.sh` 加载全栈 20 模块（18 s）→ 1 media/17 video/32 subdev，**前后摄各出帧且内容是真图像**；之前"相机不可用"的真因 = cmdline `elden_nocamera=1` + loader 三处静默守卫（`PITFALLS` #157–#159）。**用户裁决：相机在位时熄屏掉电 = 常态 ⇒ 相机与熄屏互斥**：日常态零相机模块，需要时 `cam-mode.sh on`（先禁熄屏再加载）、用完 `off`；**相机不固化进日常态**（`PITFALLS` #160）。
- **上机纪律硬约束（本轮踩出来的，`PITFALLS` #150–#152）**：坏发现场 `reboot`/`reboot -f` **全挂**，只能用 `reboot2 <mode>` 或 SysRq-b；OpenRC 下 `reboot bootloader` 不进 fastboot（会变成 halt + VBUS 自开机）；**温启循环必须自带 `slot-attr.py mark-successful b`/retry 预检**（RAM 直启不置 succ、真开机扣次数，本轮 boot_b 已被耗到 retry=6/succ=0）。
- **已定不做 / 搁置 / 取消**（勿重推）：**G1-26/27/28 桌面用户态三问题**（深色主题 / 电源菜单图标 / 亮度滑块）—— **2026-10-11 已收口：G1-26/27 上机复核通过（`grim` 截屏三态）、G1-28 后端链路已验证（logind SetBrightness 实测生效；仅 GUI 拖拽目视待人手）**，详见 `TASKS.md` §1 与 `reports/userland-dark-brightness-verify-20261011.md`；G1-29 UEFI（卡 UFS 初始化）、G1-10 NFC（**本机无 NFC 硬件**）、G1-30 slim initramfs（无固件→外设全废）、kexec 快环（**根因已定位 2026-10-08**；2026-10-09 补充：trans_pgd bug 与当前路径无关；crashkernel=64M + kexec -p + SysRq-c 已实机尝试，缺串口观察不确定 crash kernel 是否引导，待下次用 ttyACM0 串口捕获重做；`out/boot-elden-vk77-modkdump.img` 就绪）。
- **内核分界线（2026-10-10，新增）**：内核树功能基线 = **`clean/base`（vk64 源 `d02658e63`，tag `baseline/clean-base`）**；其上为**实验层**（Q28/Q24/kexec/显示实验），只作实验引用。纯功能对照点 = `baseline/feature-only`（`6c1376907`）。细则与理由见 `reports/BOUNDARY-2026-10-10-clean-base.md`，口径在 `TASKS.md` §4。
- **单元**：U1 = stock Android + root（无 Linux 分区，C0 备用设备；基线成品/剩余项见 `TASKS.md` §5 Q5）；U2 = b 槽 mainline 持久直启（在机镜像与回退资产见 `DEVICE.md` §1.1）。
  🟢 解锁议题**已定稿关闭**：看 `RUNBOOK` §0.5 ★权威顺序 + `archive/topics/复盘-2026-10-03-BL解锁.md`，**不要重新论证**。

---

## 4. 快速入口命令

```bash
cd ~/y700-elden          # ★ 启动入口即此（旧 cd 包装与根目录兼容包装 build.sh/iterate.sh/pack.sh 均已移除 → PITFALLS §15.1）
# 【收尾自检】计数漂移 / 死链 / 口径冲突（全绿再收工）
scripts/check-doctor.sh
# 【版本对账】“这个 boot.img 里到底是哪个内核” / 重生成对齐表
python3 scripts/vk-identity.py --gate                    # 只看命名/溯源规则结果
python3 scripts/vk-identity.py > versions/vk-kernel-identity.tsv   # 重生成（随后连表一起提交）
# 【

[Exact evidence: /home/xuqianhui1001/y700-elden/.pi/sessions/pi-fold-evidence/pi-session/sha256/af/afc463b27847028c8ee5a6f17898ade8137b3fc6480a118fd65c65e236ea42e2.txt; sha256=afc463b27847028c8ee5a6f17898ade8137b3fc6480a118fd65c65e236ea42e2; bytes=25288]