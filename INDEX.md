# 工作区索引 — TB322FC "elden"（SM8750P）固件与驱动研究

> **入口。** 新会话按顺序读：本文件 §1（使命）→ §2（六视角文档集）→ 需要细节再进专题档案。
> 2026-10-03：**建立 git 版本控制**（分支 `main`，只纳管文本/脚本/补丁/记忆，大二进制忽略）→ 边界与可清理标记见 **`FILES.md`**；内核工作树已导出权威补丁（`patches/elden-working-tree-ba28ec16f-2026-10-03.patch`）。

---

## 1. 使命与范围（6 行）

1. **机型唯一**：只研究 **TB322FC / elden / SM8750(P)**；研究内容只有 **固件 + 驱动**。不做别的机型移植。
2. **设备等价**：同型号多台单元**物理地位完全等价**，唯一差异 = **容量**（内存/UFS → GPT 数值）。
   身份 = `(SN, hwboardid, 容量)`；**"新机/旧机"不是角色**，**任务按单元当前状态分派**。
3. **G1**：跑**功能健全的 Linux**，**正常驱动原厂全部固件**（ADSP/CDSP/WCN/GPU/触屏/触觉/功放/tplg）。
4. **G2**：**在没有 Android 的前提下**最大化兼容安卓（**a 槽可弃**）——以容器为主路线、参考社区先例；
   **GMS/Play Integrity/Widevine 能做到哪一级 = 待调查，不预设"不可能"**。
5. **Linux 存储容量不固定**：按项目体量估算后一次给足（`DEVICE.md` §3），并可回收 Android 专属分区扩容。
6. 术语：设备称 **U1 / U2**；备份目录 `backup/<SN>-<容量档>/`；禁用 `new-tablet` 与"两轨分机"旧口径。

---

## 2. ★ 六视角文档集（唯一维护面）

| 角度 | 文件 | 装什么 |
|---|---|---|
| **设备状态 + 设备描述** | **`DEVICE.md`** | 机型规格、固件清单与通路、驱动矩阵（529 compatible/297 `.ko` 分级）、单元台账 U1/U2、状态→任务分派、GPT 参数、**§3 Linux 容量策略与体量估算** |
| **任务拆解 + 进度** | **`TASKS.md`** | 唯一任务台账：G1-1…21、G2 的 C1…C9、主机并行 A11–A18、旧任务线作废登记、**下一步顺序** |
| **参考资源 + 本地资源** | **`RESOURCES.md`** | 上游/社区参考（**含容器跑 GMS 的社区先例取证**）、构建链、可上机资产（vk40/rootfs 归档/Mesa/相机 `.ko`/固件包/AVF）、大容量资产、归档区、**§2.5 资产瘦身优先级（P0–P3，未执行）** |
| **查漏补缺** | **`GAPS.md`** | Q1–Q12 未解问题（每条含最小实验）、缺口补救路径、环境流程待办、风险登记、勾销规则 |
| **G2 专项设计** | **`ANDROID-COMPAT.md`** | 无安卓前提下的兼容方案：R1 容器（Waydroid）/ R1' redroid / R2 VM / R3 原生 + 5 维评估 + `elden-droid` 兼容层五件事 + **a 槽可弃的风险对冲** |
| **上机手册** | **`RUNBOOK-BRINGUP.md`** | 任一单元从原厂状态做到 b 槽直启 + 持久根的 Phase 0–8（零写盘验收 → GPT 手术 → 恢复 rootfs → 固化） |

> 专题档案（下列）＝**过程证据，不再更新**；结论一律以上面六份为准。口径冲突时以六视角文档为准。

---

## 3. 现状速览（详见 `TASKS.md` §0）

- **G1 ≈80%**：mainline 已在真机全线可用（冷启 ~5 s 进 Phosh、165 Hz、A830 + Mesa 26.1.8、触屏、WiFi、BT、充电+旁路、温控分级 70/82/90/105 °C、触觉、带外串口）。
  新基线 **vk40** 已编好未上机；**当前无单元在机 mainline**（最后在机基线 vk39，U1 已逆手术回 stock）。**剩 4 个硬缺口**：音频听声、相机出流、TF 卡、BT 配对。
- **G2 ≈45%**：Waydroid 容器+内核+Mesa+GAPPS 镜像+代理通路就绪；Win-x86（Box64 0.4.5+Wine 9）PoC 成功；C9 用例集定稿；C4 传感器链（UDP HAL 实现+宿主数据源+部署脚本）全就绪待上机验证。
  待办：C1 复跑 → **C3 身份/DRM 取证** → C2 Play 登录 → C4 部署验证（与 `TASKS.md` §4 对齐）。
- **U1** 当前 = stock Android + root + **无 Linux 分区**（已逆手术，`/data` 211 GiB）；Linux 侧归档 3.44 GB 可无损恢复。
- **U2** = **BL 已解锁** + a 槽 stock 259 + **b 槽 mainline vk40 持久直启**（`/`=`/dev/sda17` ext4，Phosh 自启）；GPT 已手术（`linux17`=193 GiB / `userdata`=256.7 GiB），双表 dump 在 `backup/HA2EXB0E-16+512/`。
  ⚠️ **未解故障**：桌面空闲**熄屏→整机重启**；本轮末改 `idle-delay=10` 后陷入重启环、**设备当前不可达** → 先按 `archive/topics/复盘-2026-10-03-持久化与睡眠.md` §5 恢复（详见 `GAPS` Q21 / `TASKS` G1-22）。
  ⇒ **解锁议题已定稿关闭**：看 `RUNBOOK` §0.5 ★权威顺序 + `archive/topics/复盘-2026-10-03-BL解锁.md`；**不要重新论证**。

---

## 4. 快速入口命令

```bash
cd ~/y700-elden
# 【动手前 30 秒】引导链类问题（解锁/AVB/降级/GPT/EDL）先查本地 7、8 月已有结论（#87）
grep -rn -iE "unlock|解锁|sn\.img|1\.1\.11\.|rollback|testkey|073|\.120" \
  .pi/skills/*/references/*.md *.md archive/topics/*.md | grep -v '^Binary'
```

```bash
# 目标形态：b 槽直启 Linux（~5–9 s 进 Phosh），日常不需 fastboot
sudo bash elden-net.sh && ssh -o StrictHostKeyChecking=no root@192.168.7.1
# 内核迭代（不需 fastboot）：自签 → dd boot_b → 哈希回读 → 重启
scripts/sign-boot-b.sh out/boot-elden-vkNN.img && scripts/flash-b.sh out/boot-elden-vkNN.img
cd linux && make -j16 Image.gz dtbs        # ★ 绝不跑 olddefconfig（会删 CONFIG_ARCH_QCOM）
./cycle.sh --soft                          # 软回 fastboot（免按电源键）
fastboot boot out/boot-elden-vk40-ram.img  # 零写盘 RAM 保底，但必须先 blank 当前活跃槽的 dtbo（否则卡 logo）
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
**`FILES.md`** | **文件台账：版本控制边界 / 顶层分类 / 可清理标记 / 内核补丁回导纪律**
**`SESSION-INDEX.md`** | **45 个历史会话索引 + 实机验证边界（任务 #2 的界）**；机器副本 `archive/sessions-catalog-2026-10-03.jsonl`
`scripts/` | 构建/刷机/GPT/温控/基准/串口/容器代理 全套脚本（清单见 `RESOURCES.md` §2.1）
`out/`、`bootslot-b/` | 产物与 b 槽自签包（`boot_b_vk40{,-ram}.img`、`avb.key`）
`backup/` | 原厂分区/固件/GPT 快照（**按容量档隔离**）；`backup/fw/README.md` 说明来源
`stock-src/` | 联想 GPL 源码（厂商驱动/DT/固件名反查依据）
`env-pass/` | 过环境栈 + **Linux rootfs 归档**（3.44 GB）
`archive/2026-10-02-merged/` | **本轮合并掉的旧文档原文**（MISSION-SCOPE/DEVICES/ANDROID-COMPAT-PLAN/ROUTE-DECISION/PLAN-NODEV/DOCS-CHANGELOG）

---

## 6. 专题档案地图（证据，不再维护）

| 主题 | 文件 |
|---|---|
音频（tplg→APM 图全链） | `archive/topics/AUDIO-2026-10-02.md` `archive/topics/AUDIO-2026-10-01.md` `archive/topics/AUDIO-2026-09-30.md` `archive/topics/AUDIO-scout-2026-09-30.md`
相机 + 重力计拆解 | `archive/topics/CAMERA-2026-10-02.md` `archive/topics/STOCK-CAMERA-GRAVITY-2026-10-02.md`
显示/刷新率 | `archive/topics/PANEL-REFRESH-2026-10-01.md`
温控 / 充电 | `archive/topics/THERMAL-2026-10-02.md` `archive/topics/CHARGE-2026-09-30.md`
Waydroid / Play / 容器网络 | `archive/topics/WAYDROID-2026-10-01.md` `archive/topics/WAYDROID-AOSP-AUDIT-2026-10-01.md` `archive/topics/GPLAY-2026-10-02.md` `archive/topics/PROXY-WAYDROID-2026-10-02.md`
Win-x86 转译 PoC | `archive/topics/WIN-X86-POC-2026-10-02.md`（截图 2 张）`archive/topics/WIN-X86-2026-10-02.md`
虚拟化（EL2/Gunyah/AVF/生态） | `archive/topics/EL2-VIRT-2026-10-02.md` `archive/topics/ARM-VIRT-RESEARCH-2026-10-02.md`
驱动主线覆盖审计 / 厂商源码 | `archive/topics/DRIVER-MAINLINE-AUDIT-2026-10-02.md` `archive/topics/STOCK-DRIVERS-2026-09-30.md` `archive/topics/STOCK-KERNEL-2026-09-30.md`
持久化上机 + 熄屏重启故障 | `archive/topics/复盘-2026-10-03-持久化与睡眠.md`
过环境 / 隐藏模块 | `archive/topics/ENV-PASS-2026-10-02.md` `archive/topics/SUSFS-KERNEL-2026-10-02.md` `archive/topics/YUEHONG-MODULE-2026-10-02.md` `archive/topics/GPT槽位元数据-2026-09-30.md`
存储手术与回退 | `archive/topics/LINUX-REMOVE-2026-10-02.md` `restore-259/`（AVB/KSU/EDL 救砖）
带外调试 / 出网 | `archive/topics/OOB-CONSOLE-2026-10-02.md` `archive/topics/NET-EGRESS-PLAN-2026-10-01.md`
AOSP 迁盘校验 | `archive/topics/AOSP-MIGRATE-CHECK-2026-10-02.md`
踩坑总表（**动手前扫**） | `PITFALLS.md`（#80/#81＝“把机器当角色”“状态才是前置条件”；**#87＝引导链问题先 grep 本地既有结论**）
BL 解锁（**要不要 / 怎么**——已定稿，别再重推） | `RUNBOOK-BRINGUP.md` §0.5 ★权威顺序·`archive/topics/复盘-2026-10-03-BL解锁.md`（时线 + 7/8 月对照 + 根因）·`archive/topics/UNLOCK-BLOB-FORENSICS-2026-10-03.md`（签名链取证）
操作史/复盘 | `archive/topics/HANDOFF.md` `archive/topics/复盘.md` `archive/topics/复盘-2026-09-29-夜.md` `archive/topics/复盘-2026-09-30-日.md` `archive/topics/复盘-2026-10-02-swarm.md` **`archive/topics/复盘-2026-10-03-BL解锁.md`** `archive/topics/PAUSE-2026-10-02-android.md`
**内核增量风险审核** | `archive/topics/AUDIT-since-vk34-2026-10-03.md`（GAPS Q22 / TASKS G1-23）与 **`SESSION-INDEX.md`** 配套
换机迁移包 | `flashing-bundle/` + `flashing-bundle-2026-09-29.tar.gz`

---

## 7. 兄弟项目与边界

- ~~`~/y700类原生安卓/`~~ **已于 2026-10-02 退役并入本 repo**：该目录只有 2 份文档（24 K）+ 一个 `l2` 软链，无代码无记忆。文档原文进 `archive/topics/`（`资料汇总-2026-09-30.md`、`L2-修剪流水线-2026-09-30.md`）；LineageOS/erhai 移植线与 `aweiyry/lenovo-ota-tool` 进 gsi 技能 references；`/mnt/Samsung/l2` 改由本 repo 直接引用（`./l2` 软链）。类原生路线的**结论仍是不做**（本 repo 走 mainline + 容器）。
- `~/netfix`（USTC 路由）、`~/eacndev`、`~/lobcorp-remake`：与本设备无关。
- 外部资产位置与用途见 `RESOURCES.md` §2.3。
