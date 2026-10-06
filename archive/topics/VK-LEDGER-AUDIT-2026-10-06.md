# vk 版本账目审查 — vk40–vk50 / vk51–vk61（2026-10-06）

> 证据层 · 只增不改。结论权威在领域层（`TASKS.md`、`RESOURCES.md` §3、`PITFALLS.md`）。
> 目的：把「vk 号 ↔ 内核源 ↔ 镜像 ↔ 设备侧证据」四列对齐，找出**不可复现号**与
> **镜像/文档互相矛盾**处，并落地机读校验，防止再出「静默打进错内核」类事故。
> 方法：`versions/vk-registry.tsv`、`out/boot-elden-vk*.manifest`、
> **直接从镜像内解 gzip 抽 `Linux version`**（与 `scripts/build-manifest.sh` 同法，为 ground truth）、
> 内核仓 tag/commit、`RESOURCES.md` §3、`archive/topics/ITERATION-AUDIT-2026-10-04.md` §5。
> **本轮不动设备**；改动只涉及台账/校验/文档。
>
> ⚠️ **范围排除**：`vk53` 正在独立接受审查 ⇒ 本档案不裁决 vk53（不打 tag、不改其口径），
> 只在对照表中如实列出其可观测事实。

---

## 0. 一句话结论

| 项 | vk40–vk50 | vk51–vk61 |
|---|---|---|
| 号段 | 11 号 | 11 号 |
| registry 行 | 0（seed=vk50 起） | 11（vk51–61 连续、无重复） |
| 内核 tag | 8（40/41/42/44/45/46/47/48） | 0 → **已补 tag vk54**（vk53 排除） |
| 有 manifest | 2（vk42、vk50） | 12（vk52–61 及变体） |
| **不可复现号** | **vk43**（源/镜像/manifest 三缺）；vk49 源缺（镜像在） | 无（但 vk52/vk54/56/57 镜像内核错包，见 §2） |
| 硬矛盾 | 1（`boot_b.img` 命名 vs 实际） | 1（vk52-slim 打包内核非本树） |

---

## 1. 批一：vk40–vk50

| vk | 内核源 | 镜像/产物 | 设备侧证据 | 判定 |
|---|---|---|---|---|
| 40 | tag `vk40`@`6ef87e6a8`（自述含未清理插桩） | `bootslot-b/boot_b_vk40{,-ram,-persist-diag}.img` | ✅ 10-03 U2 持久 Phosh；曝熄屏→重启 | ⚠ UTS=`gba28ec16f01f-dirty`（与 vk7–41 同串）；编译主机 `5700g-x8664` |
| 40re | 同 vk40 树 | 无镜像 | 10-03 二分（V1/V2） | ⚠ 只剩 `logs/bisect/vk40re-r1{,b}` |
| 41 | tag `vk41`@`4b643f169` | **无**（清理时删除） | ✅ `reboot bootloader` 真进 fastboot | ❌ 无镜像、无 manifest |
| 42 | tag `vk42`@`eb432f18a` | `out/boot-elden-vk42.img` + manifest | ✅ 10-04 上机 | ✅ 老号里唯一有 manifest（11:27 重生成） |
| **43** | **无 commit/tag**（树=vk42） | **无** | ✅ 10-04 vk43 出声 | ❌❌ **UNREPRODUCIBLE**：本号改动=rootfs tplg overlay（MI2S SD0→SD1），overlay 未留档 |
| 44 | tag `vk44`@`26cc186e9` | 无 | 采集图全绿但录音恒 0（本机无 DMIC，方向证伪） | ⚠ 无 manifest |
| 45 | tag `vk45`@`a923477be` | 无 | 同上 | ⚠ 无 manifest |
| 46 | tag `vk46`@`4c68eb5ed` | `out/boot-elden-vk46{,-ram}.img` | ✅ 10-04 模块对齐 | ⚠ 无 manifest；`bootslot-b/boot_b.img` 实为 vk46-dirty |
| 47 | tag `vk47`@`bd114ca33` | `vk47.img`(-ram/-dtb42)、`vk47a-ram` | ✅ 持久根基线；BT A/B | ⚠ 无 manifest |
| 47clean | `bd114ca33` 重建 + `LOCALVERSION=-vk47clean` | `vk47clean.img` = `boot_b-clean.img` = `out/boot_b-live.img` | ✅ **当前在机** | ✅ 后缀命名合规，无 registry 行 |
| 48 | tag `vk48`@`5a70ade46` | 仅 rootfs/tplg 覆盖包，无 boot 镜像 | R1 耳麦 tplg 未验证 | ⚠ |
| **49** | **无 commit/tag**（树=vk48，KV 同串） | `out/boot_b-vk49.img` | ✅ 20 相机模块全载 | ❌ 源缺；镜像在 |
| 50 | 无 commit（树=vk48 + `LOCALVERSION=-vk50`） | `vk50.img` + manifest | ✅ 前后摄出帧；❌ kexec 硬挂 | ✅ registry seed 行 |

### 1.1 批一问题
- **A1** `vk43` 为全账唯一**零证据号**（无 commit/镜像/manifest）；`vk49` 半缺（有镜像无源）。
  `ITERATION-AUDIT §6 V1b`（补 commit/tag）**未执行**。本轮**不伪造 tag**，改为在
  `patches/kernel-history/README.md` 落「版本→commit 对照 + 不可复现留白」。
- **A2** manifest 覆盖断层 vk43–49 ⇒ 这 7 个号不可机读复现。
- **A3** vk40 段 UTS 同串（`gba28ec16f01f-dirty`）且**跨机编译**（`5700g-x8664`）⇒ 设备历史无法反查版本。
- **A4** 镜像留存不全：vk41/43/44/45 全无；vk48 只剩覆盖包（10-04 清理 -6G 所致）。
- **A5** `bootslot-b/README.md` 资产表写 `boot_b.img = vk12`，与现状（vk46 dump / vk47clean 在机）不符 —— **已修正**（见 §4）。
- **A6** `bootslot-b/boot_b.img`(db2d6afb) 实测 UTS=`g4c68eb5ed4e3-dirty`=**vk46 时代 dump**，
  而 `boot_b-clean.img`/`out/boot_b-live.img`=vk47clean（与 `INDEX` §U2「当前 boot_b=vk47clean」一致）。

---

## 2. 批二：vk51–vk61

| vk | registry | 镜像内实测内核 | 产物 | 判定 |
|---|---|---|---|---|
| 51 | ✅ bootchain | —（研究/脚本交付） | 无镜像 | ✅ 研究类无产物属正常 |
| **52** | ✅ bootslim | **`vk42-geb432f18a0d1`** | `vk52-slim.img` + manifest | ❌ **错包内核**（见 §2.1） |
| 53 | ✅（⚠️未上机） | `vk53-g2b5badef00fb` | `vk53.img`、`vk53f.img` | ⏸ **独立审查中，本轮不裁决** |
| 54 | ✅ | `vk54-g2b5badef00fb-dirty` | `vk54.img`/`-ram`/`-slim`/`vk54f` | ❌ 全部基于 **dirty 树**（违「只烧 clean」纪律）→ 已补 tag `vk54`@`26cd13b1c` |
| 55 | ✅ userland-session | —（用户态/会话层） | 无镜像（主库 `ee72844`/`03b4777`） | ✅ 设备侧已上机验证 |
| 56/57 | ✅（补录） | 同 **vk54-dirty**（`kernel_image_sha256` 相同） | `vk56/57-slim` | ⚠ 名字像独立版本，实为**同一内核**换 ramdisk |
| 58 | ✅（补录） | `vk58-g26cd13b1c4a2-dirty` | `vk58/58b/58c-slim` + manifest | ✅ vk58c `fastboot boot` 启动 |
| 59 | ✅ lane=`hw-driver` | `vk59-g26cd13b1c4a2`（=vk54 提交，vk53 内容超集） | `vk59-slim` + `vk59a`/`cdspoff`/`nfcoff` | ⚠ registry note 写「vk53 内核」不精确；变体无 kernel 哈希 |
| 60 | ✅ | `vk47clean-gbd114ca335e1` | `vk60.img` + manifest | ⚠ slim 已弃用（无 `/lib/firmware`，`PITFALLS` #113）；registry note 未标弃用 |
| 61 | ✅ | `vk47clean-gbd114ca335e1` | `vk61.img` + manifest | ✅ 零写盘验收；boot_b 待刷 |
| vkX-dtb53 / vkY-kern53 | ❌ 不在 registry | vk47clean / vk53 内核 | 2 镜像 + manifest | ⚠ 非约定后缀命名，仍是 vk53 载具重测资产 |

### 2.1 vk52-slim 错包内核（本轮最实质发现）
- manifest 自身即自相矛盾：`kernel_release=7.2.0-debug-g5a70ade46a88`（树自称）vs
  `kernel_uts=7.2.0-debug-vk42-geb432f18a0d1`（镜像内，ground truth）。
- 交叉证据：`kernel_image_sha256` 与 vk42 manifest **完全相同**（`7ac1699b…`）。
- 成因：11:27 为重打 vk42 把树/产物退到 vk42，14:30 打 slim 时**未重编内核**，沿用陈旧 `Image.gz`。
- 影响：当时设备模块对齐的是 vk50（`g5a70ade46a88`）⇒ slim 实验的「内核与 `/lib/modules` 同版本」
  前提**未满足**（未被发现的混淆变量）。slim 失败的真归因（最小 initramfs 缺 `/bin/sh`，`PITFALLS` #107）
  **不受影响**；但同类错误若发生在驱动 A/B 上会直接给出错误结论。
- 同类（同 bug 类）：`vk54-slim`/`vk56-slim`/`vk57-slim` 亦复用 vk54-dirty 内核（`b3b87ed1`），
  非当时树内核（`g26cd13b1c4a2`）—— 即 kexec R2 的 slim 矩阵实际跑的是 **trans_pgd fix 之前**的内核镜像。

### 2.2 批二问题
- **B1** manifest 具备检出矛盾的能力，但**无任何校验**（check-doctor 原不查 registry/manifest）⇒ 事故无人发现。**已修**（§4）。
- **B2** `verification=` 字段默认写死 `NOT_TESTED_ON_DEVICE`、**无回填机制**：实测过的 vk58c/vk60/vk61 仍标未测。
- **B3** 号不唯一标识内核：vk54/56/57-slim 同内核、vk59 全家同内核 ⇒ 必须比 `kernel_image_sha256`。
- **B4** 内核 tag 原停在 vk48；vk53/vk54 有 commit 无 tag（**已补 vk54**；vk53 排除）。
- **B5** 未提交产物 4 个 manifest（`vk53f`/`vk54f`/`vkX-dtb53`/`vkY-kern53`）⇒ 已提交其中 3 个（vk53f 排除）。
- **B6** lane 名漂移：registry vk53=`hw-drivers`、vk59=`hw-driver`。
- **B7** registry note 未回填弃用结论（vk52 slim、vk60 slim）—— 行不可改写，故作**注释追加**（§4）。

---

## 3. 不可复现号登记（诚实留白）

| vk | 缺口 | 现存可考证物 |
|---|---|---|
| vk43 | 无内核 commit、无镜像、无 manifest | `RESOURCES` §3（tplg SD0→SD1 出声）、`ITERATION-AUDIT` §5 |
| vk41 | 无镜像、无 manifest（源有 tag） | tag `vk41`@`4b643f169` + `patches/kernel-history/elden_vk41-psci-reboot/` |
| vk44/45 | 无镜像、无 manifest（源有 tag） | tag + `elden_vk42-audio-thermal` 补丁集 |
| vk48 | 无 boot 镜像（源有 tag） | `out/rootfs-vk48.cpio.gz`、`out/tplg-overlay-vk48.cpio.gz` |
| vk49 | 无内核 commit/manifest（镜像在） | `out/boot_b-vk49.img`、`RESOURCES` §3 |

---

## 4. 本轮已落地更正（2026-10-06）

| # | 动作 | 产物 |
|---|---|---|
| 1 | 内核仓补 annotated tag **`vk54`**@`26cd13b1c`（vk53 排除，不伪造 vk43/49/50） | `geekidos-linux` tags |
| 2 | 内核版本→commit 对照表 + 不可复现留白 | `patches/kernel-history/README.md` |
| 3 | registry **注释追加**账目更正（行不改写） | `versions/vk-registry.tsv` |
| 4 | 已知问题白名单（历史项降 WARN，新事故仍 FAIL） | `versions/vk-ledger-known-issues.tsv`（新增） |
| 5 | 机读校验：registry 单调唯一 / registry 号必有 manifest / **树自称 ≠ 镜像内** / dirty 位漂移 | `scripts/check-doctor.sh` §5 |
| 6 | 修正 `boot_b.img` 口径 + 现状表（sha/UTS/在机/目标） | `bootslot-b/README.md` |
| 7 | 提交 3 个未入库 manifest（vk53f 排除） | `out/boot-elden-vk54f/vkX-dtb53/vkY-kern53.manifest` |
| 8 | 本档案 | `archive/topics/VK-LEDGER-AUDIT-2026-10-06.md` |

**未做（留待决定）**：`verification=` 回填机制（B2）、vk59 registry note 精确化、lane 名统一（B6）。
vk53 相关（tag、registry 口径、`vk53f.manifest`）一律**等独立审查结论**。

## 5. 校验命令（可复跑）

```bash
scripts/check-doctor.sh                    # §5 = vk 版本账；FAIL=0 才算过
# 负向验证：临时移走白名单应恢复 FAIL（证明校验非空转）
mv versions/vk-ledger-known-issues.tsv /tmp/ && scripts/check-doctor.sh; echo $?   # → 1
mv /tmp/vk-ledger-known-issues.tsv versions/
```
