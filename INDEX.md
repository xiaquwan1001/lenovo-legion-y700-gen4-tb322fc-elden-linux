# 工作区索引 — TB322FC "elden"（SM8750P）固件与驱动研究

> **入口。** 新会话：本文件 §1（使命）→ §2（文档分层）→ §3（现状）→ 需要细节再进对应文档/专题档案。
> **唯一入口 = 本文件**；根目录只有 **6 份维护文档**（§2）+ `AGENTS.md`。
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
> 根目录只有 6 份维护文档：`INDEX`（本文件）· `DEVICE` · `TASKS` · `RESOURCES` · `RUNBOOK-BRINGUP` · `PITFALLS`。
> **推荐阅读顺序**：本文件 → `.pi/AGENT-OPS.md`（做事规范）→ `TASKS.md`（任务/进度/未解）→ `PITFALLS.md`（动手前扫）→ 需要时再进 `DEVICE`/`RESOURCES`/`RUNBOOK`。

### 入口（唯一）

| 文件 | 装什么 |
|---|---|
| **`INDEX.md`** | 使命与范围、分层地图、现状快照、快速命令、专题档案索引 |

### 规范入口（agent 行为唯一入口）

| 入口 | 文件（权威） | 装什么 |
|---|---|---|
| **行为/规范** | **`.pi/AGENT-OPS.md`** | agent **自主优先**（写坏风险先备份，超出预期的错误才上报）、物理干预边界、设备安全纪律、研发纪律、文档写入权限、汇报/时间盒；并发细则见 `.pi/CONCURRENCY.md` |

> 项目描述（机型/目标/设备等价）在 `AGENTS.md`；根目录 6 份维护文档不再复述规范与经验。

### 领域层（4 份，唯一维护面）

| 角度 | 文件（权威） | 装什么 |
|---|---|---|
| **设备状态 + 设备描述** | **`DEVICE.md`** | 机型规格、固件清单与通路、驱动矩阵、单元台账 U1/U2、状态→任务分派、GPT 参数、**§3 Linux 容量策略** |
| **任务 / 进度 / 未解 / 方案** | **`TASKS.md`** | **唯一任务台账 + 进度权威**（§0）；G1/C/A 任务（§1–4）；**§5 查漏补缺（GAPS/Q1–Q28；Q27 从无此号）**；**§6 G2 安卓兼容方案**；**§7 上游化（M1–M5）** |
| **资源 / 资产 / 会话轨迹** | **`RESOURCES.md`** | §1 外部参考 · §2 本地资源 · **§3 文件与资产台账（git 边界/可清理）** · **§4 会话索引（数字 SSOT；实机边界）** |
| **上机手册** | **`RUNBOOK-BRINGUP.md`** | 任一单元从原厂状态做到 b 槽直启 + 持久根的 Phase −1…9 |

### 经验层（1 份）

| 文件 | 装什么 |
|---|---|
| **`PITFALLS.md`** | **开发经验唯一入口**：**§0 零号纪律**（动手前先做四件事）+ 踩坑正文（按主题编号，范围见 `PITFALLS` 头部）+ **§15 过时/废弃/功能缺陷登记**（DEPRECATED） |

### 证据层（`archive/`，只增不改、不改结论）

> 专题档案＝**过程证据**；结论一律以领域层为准，archive 不得被引用为「当前结论」。
> 新证据只追加，不回头改写。

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

- **完成度**：G1 ≈90% · G2 ≈50% · G3 PoC ✅（数字权威 = `TASKS.md` §0）。
- **Linux 侧未解（3 项，按影响排序）**：
  ① **Q28 显示间歇失败**（只有背光无桌面）→ 日常可用性第一道门。根因已定案=冷起首次 DSI PLL/PHY 未稳定锁定 → bonded 双 DSI 首条 DCS 的 cmd-DMA hang（冷起 ~60%，冷起失效有 NOCARD/STORM 两模式）。**⚠️ 2026-10-10 夜「按内核二进制确定性」说法已被溯源审计降级（`reports/q28-binary-determinism-provenance-20261010.md`、`PITFALLS #171`）：原台账 21 发仅 7 发有原始日志；所谓 5,040,884 B 二进制差主要是 `LOCALVERSION` 长度导致的 4 字节 `.rodata` 平移（`.text` 仅 26 个 word、全为地址立即数）；且同一 vk64.img 在冷 POR 路径 3/3=STORM。⇒ 现口径=「在 reboot2 暖路径上 vk64 亮、vk89/vk64c 不亮，真因未定」。** **【2026-10-10 夜②：同一 `boot-q28-oct8.img` 同晚同路径 5 发=GOOD/STORM/STORM/GOOD/STORM ⇒ 同镜像非确定；且 `storm=0` 的干净 GOOD 3/3 数秒内整机冻死、`storm>0` STORM 4/4 存活 ⇒ 判 GOOD 必须加**存活门**（`PITFALLS #172`、`reports/q28-layout-ab-20261010.md`）。】** 现状/判据/下一步只读 SSOT `reports/q28-DOSSIER.md` 与 `TASKS.md` §5 Q28；**【2026-10-11 新增：NOCARD 与新编镜像的 `LOCALVERSION` 强相关（同源同 config，`-vk64` GOOD 1/1 vs `-vk93-cleanctl` NOCARD 3/3）；见 `reports/q28-DOSSIER.md` §m、`PITFALLS #175`。】**
  ② **Q24 熄屏 × 相机**（🆕 2026-10-11 最小触发重定 = **`camcc-sm8750` + `cambistmclkcc-sm8750` 配对 + 真实熄屏**；单独任一不触发，历史「cambist 单模块」否证；FIX-3 实测挂死）→ 用户裁决=互斥二选一：日常零相机模块（熄屏安全），需要时 `cam-mode.sh on/off`。详见 `TASKS.md` G1-33 / §5 Q24、`reports/q24-repro-20261011.md`、`PITFALLS #173–#179`；
  ③ **进 GUI 后整机卡死**（`PITFALLS #106`，与 Q28 不同因）→ 已常驻自动取证（`/etc/sysctl.d/99-freeze-trace.conf` + `pstore-catch`），命中即 panic→暖复位→带回全 CPU 栈；暂未复现。
- **本轮已关闭 / 搁置**（不再占未解）：✅ Q26 WiFi（2026-10-10 用户确认）、⚪ G1-6 TF 卡（用户裁决忽略）、✅ G1-34 重力/自动旋转（SSC/QRTR + iio-sensor-proxy；prox/als/compass 已核）。
- **未开工**：上游化 **M1–M5**（`TASKS.md` §7）、G1-8 CPU/GPU 基准（GPU 已确认工作 Adreno 830 GLES3.2，待装 glmark2/vkmark 跑数）。
- **模块化载荷线（2026-10-09 深夜已在机验收）**：`/init` 自加载 7 个载荷驱动（1.5–4.4 s）、WiFi 扫描 25 AP + 自动重连、声卡/背光/触屏/触觉全在；`scripts/mod-loop.sh` 热换驱动 **7 s** 上机。两个待决定见 `TASKS.md` §5 条 8.5。
- **相机（2026-10-09 深夜零写盘复验）**：现役 boot_b(vk64/H2) 上 `CAM_FORCE=1 camera-modules-load.sh` 加载全栈 20 模块（18 s）→ 1 media/17 video/32 subdev，**前后摄各出帧且内容是真图像**；之前"相机不可用"的真因 = cmdline `elden_nocamera=1` + loader 三处静默守卫（`PITFALLS` #157–#159）。**用户裁决：相机在位时熄屏掉电 = 常态 ⇒ 相机与熄屏互斥**：日常态零相机模块，需要时 `cam-mode.sh on`（先禁熄屏再加载）、用完 `off`；**相机不固化进日常态**（`PITFALLS` #160）。
- **上机纪律硬约束（本轮踩出来的，`PITFALLS` #150–#152）**：坏发现场 `reboot`/`reboot -f` **全挂**，只能用 `reboot2 <mode>` 或 SysRq-b；OpenRC 下 `reboot bootloader` 不进 fastboot（会变成 halt + VBUS 自开机）；**温启循环必须自带 `slot-attr.py mark-successful b`/retry 预检**（RAM 直启不置 succ、真开机扣次数，本轮 boot_b 已被耗到 retry=6/succ=0）。
- **已定不做 / 搁置 / 取消**（勿重推）：**G1-26/27/28 桌面用户态三问题**（深色主题 / 电源菜单图标 / 亮度滑块）—— **2026-10-11 已收口：G1-26/27 上机复核通过（`grim` 截屏三态）、G1-28 后端链路已验证（logind SetBrightness 实测生效；仅 GUI 拖拽目视待人手）**，详见 `TASKS.md` §1 与 `reports/userland-dark-brightness-verify-20261011.md`；G1-29 UEFI（卡 UFS 初始化）、G1-10 NFC（**本机无 NFC 硬件**）、G1-30 slim initramfs（无固件→外设全废）、kexec 快环（**根因已定位 2026-10-08**；2026-10-09 补充：trans_pgd bug 与当前路径无关；crashkernel=64M + kexec -p + SysRq-c 已实机尝试，缺串口观察不确定 crash kernel 是否引导，待下次用 ttyACM0 串口捕获重做；`out/boot-elden-vk77-modkdump.img` 就绪）。
- **内核分界线（2026-10-10，新增）**：内核树功能基线 = **`clean/base`（vk64 源 `d02658e63`，tag `baseline/clean-base`）**；其上为**实验层**（Q28/Q24/kexec/显示实验），只作实验引用。纯功能对照点 = `baseline/feature-only`（`6c1376907`）。细则与理由见 `reports/BOUNDARY-2026-10-10-clean-base.md`，口径在 `TASKS.md` §4。
- **单元**：U1 = stock Android + root（无 Linux 分区，可做 Android 侧对照取证 C0）；U2 = b 槽 mainline 持久直启（在机镜像与回退资产见 `DEVICE.md` §1.1）。
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
# 【动手前 30 秒】引导链类问题（解锁/AVB/降级/GPT/EDL）先查本地 7、8 月已有结论（#87）
grep -rn -iE "unlock|解锁|sn\.img|1\.1\.11\.|rollback|testkey|073|\.120" \
  .pi/skills/*/references/*.md *.md archive/topics/*.md | grep -v '^Binary'
```

```bash
# 目标形态：b 槽直启 Linux（~5–9 s 进 Phosh），日常不需 fastboot
sudo bash elden-net.sh && ssh -o StrictHostKeyChecking=no root@192.168.7.1
# 内核迭代＝统一入口 scripts/iterate.sh（四档环，细则 RUNBOOK §迭代；mod-loop/kexec/to-fastboot/flash-b/cycle 均已自锁）
scripts/iterate.sh mod <driver-dir>              # 环0：=m 模块热载 ~30s 不重启（需先应用 fragment-modular）
scripts/iterate.sh kernel VERSION=vkNN           # 全量重编（迭代通道见 RUNBOOK；kexec 快环未闭环，勿默认）
scripts/iterate.sh kernel --flash VERSION=vkNN   # 写回 boot_b（设备写：按 .pi/AGENT-OPS.md 先备份后执行）
scripts/device-lock.sh --status                  # 谁占着设备；并发子代理写操作前必查
# ★ 绝不跑 olddefconfig（会删 CONFIG_ARCH_QCOM）
./cycle.sh --soft                          # 软回 fastboot（免按电源键）
fastboot boot bootslot-b/boot_b-clean.img  # 零写盘·持久变体（RAM 内核+磁盘根，有桌面/服务），功能测试用（见 PITFALLS #93）
fastboot boot <img>                        # 零写盘·纯RAM变体（无桌面/服务）仅内核/引导级验证；先 blank 活跃槽 dtbo 否则卡 logo（PITFALLS #1/#10）
# 新单元开工三件套（先写台账，再备份，再手术）
fastboot getvar serialno; adb shell getprop ro.boot.hwboardid   # → 写进 DEVICE.md §2.2
sh scripts/gpt-dump.sh                                          # 打印本单元 backup_lba（禁跨容量档复用）
fastboot fetch boot_b "$BAK"/boot_b.img                         # dtbo_b / vbmeta_b 同理
python3 scripts/slot-attr.py show                               # 槽位属性（在 GPT attribute，非 misc）
```

---

## 5. 目录速查

| 路径 | 内容 |
|---|---|
`linux -> geekidos-linux` | 内核树（7.2.0 + `patches/0001–0011`）
`patches/` | 内核改动与 config 快照（`config-vk40-bringup`）；**`elden-working-tree-ba28ec16f-2026-10-03.patch` = 权威工作树全量补丁**
**`RESOURCES.md §3`** | **文件台账：版本控制边界 / 顶层分类 / 可清理标记 / 内核补丁回导纪律**
**`PITFALLS.md`** | **开发经验唯一入口（新会话动手前先读）**：§0 零号纪律 + 踩坑正文（按主题编号）
**`RESOURCES.md §4`** | **历史会话索引 + 实机验证边界**（数字 SSOT；无产出/冒烟会话以 `junk` 标注可整行忽略）
**`.pi/AGENT-OPS.md`** | **agent 行为/授权规范（唯一入口）**：自主分级 / 物理干预边界 / 写入权限
**`.pi/CONCURRENCY.md`** | 并发任务约束（lane/fork/registry；AGENT-OPS 下级细则）
`scripts/` | 构建/刷机/GPT/温控/基准/串口/容器代理 全套脚本（清单见 `RESOURCES.md` §2.1）
`out/`、`bootslot-b/` | 产物与 b 槽自签包（`boot_b_vk40{,-ram}.img`、`avb.key`）
`backup/` | 原厂分区/固件/GPT 快照（**按容量档隔离**）；`backup/fw/README.md` 说明来源
`stock-src/` | 联想 GPL 源码（厂商驱动/DT/固件名反查依据）
`env-pass/` | 过环境栈 + **Linux rootfs 归档**（3.44 GB）
`archive/2026-10-02-merged/` | **本轮合并掉的旧文档原文**（MISSION-SCOPE/DEVICES/ANDROID-COMPAT-PLAN/ROUTE-DECISION/PLAN-NODEV/DOCS-CHANGELOG）
`reports/` | **活跃主题工作区**：进行中主题的专题/取证稿所在（如 `reports/q28-DOSSIER.md` 为 Q28 单一事实源、`reports/Q24-Q28-INDEX.md` 为 Q24+Q28 会话/进度/产物合并台账）；主题定案后证据迁 `archive/topics/` 归档层

---

## 6. 专题档案地图（证据层，只增不改）

| 主题 | 文件 |
|---|---|
音频（tplg→APM 图全链） | `archive/topics/AUDIO-2026-10-02.md` `archive/topics/AUDIO-2026-10-01.md` `archive/topics/AUDIO-2026-09-30.md` `archive/topics/AUDIO-scout-2026-09-30.md`
相机 + 重力计拆解 | `archive/topics/CAMERA-2026-10-02.md` `archive/topics/STOCK-CAMERA-GRAVITY-2026-10-02.md`
显示/刷新率 | `archive/topics/PANEL-REFRESH-2026-10-01.md`
温控 / 充电 | `archive/topics/THERMAL-2026-10-02.md` `archive/topics/CHARGE-2026-09-30.md`
**CDSP（G1-11 修复：split 固件 + initramfs）** | `archive/topics/CDSP-FIX-2026-10-07.md` `archive/topics/CDSP-PROBE-2026-10-06.md`
Waydroid / Play / 容器网络 | `archive/topics/WAYDROID-2026-10-01.md` `archive/topics/WAYDROID-AOSP-AUDIT-2026-10-01.md` `archive/topics/GPLAY-2026-10-02.md` `archive/topics/PROXY-WAYDROID-2026-10-02.md`
Win-x86 转译 PoC | `archive/topics/WIN-X86-POC-2026-10-02.md`（截图 2 张）`archive/topics/WIN-X86-2026-10-02.md`
虚拟化（EL2/Gunyah/AVF/生态） | `archive/topics/EL2-VIRT-2026-10-02.md` `archive/topics/ARM-VIRT-RESEARCH-2026-10-02.md`
间接引导层 / SM8750 UEFI（**G1-29 路线 A 已搁置 2026-10-05**） | `archive/topics/BOOTCHAIN-2026-10-05.md`（机制） `archive/topics/UEFI-RESOURCES-2026-10-05.md`（可用资源+中文社区检索） **`archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md`（上机实验矩阵 + UFS 阻塞根因）** **`archive/topics/UEFI-UFS-UPSTREAM-ASK-2026-10-05.md`（上游 issue #12）**
驱动主线覆盖审计 / 厂商源码 | `archive/topics/DRIVER-MAINLINE-AUDIT-2026-10-02.md` `archive/topics/STOCK-DRIVERS-2026-09-30.md` `archive/topics/STOCK-KERNEL-2026-09-30.md`
**用户态发行版选型 + 硬盘布局** | **`archive/topics/USERLAND-STACK-2026-10-05.md`**（Phosh 新鲜度 / U1–U14 用户态 bug 单 / 不换发行版 + 会话 overhaul / boot 分区布局 / UEFI 搁置）
**本轮三调查合并决议**（kexec / 发行版+布局 / 驱动补全；优先级裁决） | **`archive/topics/MERGE-2026-10-05.md`**
**驱动批次上机验证**（vk53/vk54 启动失败与**归因撤回**；`fastboot boot` 矩阵） | **`archive/topics/DRIVER-VERIFY-2026-10-06.md`**
持久化上机 + 熄屏重启故障 | `archive/topics/复盘-2026-10-03-持久化与睡眠.md` **`archive/topics/G1-22-2026-10-05.md`**（受控复现；根因未证实） **`archive/topics/REBOOT-5MIN-2026-10-05.md`**（§7.9 收尾）
过环境 / 隐藏模块 | `archive/topics/ENV-PASS-2026-10-02.md` `archive/topics/SUSFS-KERNEL-2026-10-02.md` `archive/topics/YUEHONG-MODULE-2026-10-02.md` `archive/topics/GPT槽位元数据-2026-09-30.md`
存储手术与回退 | `archive/topics/LINUX-REMOVE-2026-10-02.md` `restore-259/`（AVB/KSU/EDL 救砖）
带外调试 / 出网 | `archive/topics/OOB-CONSOLE-2026-10-02.md` `archive/topics/NET-EGRESS-PLAN-2026-10-01.md`
AOSP 迁盘校验 | `archive/topics/AOSP-MIGRATE-CHECK-2026-10-02.md`
踩坑总表（**动手前扫**） | `PITFALLS.md`（#80/#81＝“把机器当角色”“状态才是前置条件”；**#87＝引导链问题先 grep 本地既有结论**）
BL 解锁（**要不要 / 怎么**——已定稿，别再重推） | `RUNBOOK-BRINGUP.md` §0.5 ★权威顺序·`archive/topics/复盘-2026-10-03-BL解锁.md`（时线 + 7/8 月对照 + 根因）·`archive/topics/UNLOCK-BLOB-FORENSICS-2026-10-03.md`（签名链取证）
操作史/复盘 | `archive/topics/HANDOFF.md` `archive/topics/复盘.md` `archive/topics/复盘-2026-09-29-夜.md` `archive/topics/复盘-2026-09-30-日.md` `archive/topics/复盘-2026-10-02-swarm.md` **`archive/topics/复盘-2026-10-03-BL解锁.md`** `archive/topics/PAUSE-2026-10-02-android.md`
**近四天会话审查**（失败方向特征 F1–F9 + 排查思路 + 文档精简结论） | **`archive/topics/SESSION-AUDIT-2026-10-06.md`**
**内核增量风险审核** | `archive/topics/AUDIT-since-vk34-2026-10-03.md`（GAPS Q22 / TASKS G1-23）与 **`RESOURCES.md §4`** 配套
换机迁移包 | `flashing-bundle/`（tar.gz 已归档 `archive/2026-10-04-root-strays/`）
**退场的入口**（快捷方式副本 + 已卸载插件 `pi-messenger-swarm` 登记；**插件工作流已删**） | `archive/2026-10-04-retired-entrypoints/README.md`
**上游化审查**（内核树 vs 主线 v7.2 全量 diff，A/B/C/D 分级） | `archive/topics/UPSTREAM-REVIEW-2026-10-04.md`（任务 `TASKS.md` §7 M1–M5）

---

## 7. 兄弟项目与边界

- ~~`~/y700类原生安卓/`~~ **已于 2026-10-02 退役并入本 repo**：该目录只有 2 份文档（24 K）+ 一个 `l2` 软链，无代码无记忆。文档原文进 `archive/topics/`（`资料汇总-2026-09-30.md`、`L2-修剪流水线-2026-09-30.md`）；LineageOS/erhai 移植线与 `aweiyry/lenovo-ota-tool` 进 gsi 技能 references；`/mnt/Samsung/l2` 改由本 repo 直接引用（`./l2` 软链）。类原生路线的**结论仍是不做**（本 repo 走 mainline + 容器）。
- `~/netfix`（USTC 路由）、`~/eacndev`、`~/lobcorp-remake`：与本设备无关。
- 外部资产位置与用途见 `RESOURCES.md` §2.3。
