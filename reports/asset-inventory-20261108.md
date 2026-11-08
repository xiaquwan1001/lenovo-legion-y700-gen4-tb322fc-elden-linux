# 资产与工具盘点 — 2026-11-08（只读，零删除）

> 执行：physical-exec（只读盘点 + 无损校验）；未删除/未改写任何既有文件；
> 未跑 git gc/prune；未上机、未构建。数据快照时间 2026-11-08。

## §0 数字总表

| 项 | 值 |
|---|---|
| 派工单 9 个目录合计占用 | **89,997 MiB ≈ 88 GiB**（backup 30.4 + build 18.4 + out 17.9 + wt 12.5 + geekidos 3.6 + dl-cam 2.7 + stock-src 2.0 + external 1.9 + logs 0.03） |
| 登记外的大头（供参考） | bootslot-b 1,255 MiB、env-pass 3,285 MiB、.pi/ 6,131 MiB、y700四代工具/ 271 MiB |
| 文件系统余量 | 937G 盘用 572G，余 318G（65%）——**不紧迫** |
| 可回收候选（见 §5） | ≈ **10,900 MiB**（保守档）/ ≈ 27,600 MiB（进取档） |
| 孤儿工具数（tools/） | **0**（3 个工具均在 versions/layout.tsv §tools 登记，avbtool 被 scripts 引用 3 处；l2-extract/gunyah-modules 在 RESOURCES/reports 有引用） |
| 无引用脚本 | **0 UNREFERENCED**（versions/scripts-inventory.tsv 2026-11-06 快照：318 入口 = LIVE 264 / HIST-ONLY 54） |
| 未提交改动仓数 | **1**（external/lc-cross/lc-src：no origin、branch=master、无提交、17 个未跟踪文件） |
| git 仓脏树数（build/ + external/ + geekidos + wt） | 1（同上；build/a2-ln、base-7.2、m3v2-7.3rc7 均 dirty=0） |

## §1 空间账（顶层 + 二层，du -sm）

| 目录 | MiB | 最新改动 | 二层大头 |
|---|---|---|---|
| backup/ | 30,429 | 2026-11-08 | official-rom 16,009；out-history-20261105 7,840；build-bundles 1,274；HA2EXB0E-16+512 1,053；git-repair-20261105 882；fw 790 |
| build/ | 18,441 | 2026-11-08 | uefi-woa-prep 8,371；m3v2-7.3rc7 4,977；daily 2,709；base-7.2 2,350 |
| out/ | 18,336 | 2026-11-08 | real-ladder 1,935；r21-sbstop-p9 1,090；debian 683；r21-sbstop-p55/56/57 各 642；共 353 项 |
| wt/ | 12,516 | 2026-11-07 | reb-731 12,516（torvalds worktree，dirty=0） |
| geekidos-linux/ | 3,653 | 2026-11-07 | .git 1,871；drivers 1,163 |
| dl-cam/ | 2,667 | 2026-10-29 | ndk 1,642；vendor-orig/vendor-cam-l1d.img 各 256 |
| stock-src/ | 2,036 | 2026-10-17 | 联想 GPL 内核 clone 1,495 + modules 528 |
| external/ | 1,884 | 2026-10-18 | ext-repos 1,220；lc-cross 450；alpine-sysroot 94 |
| logs/ | 35 | 2026-11-07 | memstress 系列 ~13 MiB |

## §2 工具账（tools/，sha256 + 可用性 + 引用）

| 工具 | sha256（前 16） | 可用性 | scripts/ 引用 |
|---|---|---|---|
| tools/avbtool.py | e5a664a38db623da | `avbtool 1.3.0` 正常 | 3（build-initramfs/build-boot/sign-boot-b 等，另 sign-boot-b.sh 等） |
| tools/l2-extract/lp_tool.py | 7625f3df3f6011bb | `--help` 缺参报错（需参数才能跑，非损坏） | 0（文档引用：RESOURCES/README、reports/asset-tidy-20261103） |
| tools/l2-extract/dump-super.sh | fb89455759b7ff08 | 需块设备参数 | 0（同上） |
| tools/gunyah-modules/vmmtest/vmmtest | 426c6660f308579a | 可执行（无 --help，Gunyah VMM 测试器） | 0（reports/gunyah-* 系列引用） |
| tools/gunyah-modules/{dtbo,hypprobe,rmtest} | 源码 + Makefile | 源码形态 | 0（TASKS/Gunyah 会话引用） |

**scripts/ 覆盖**：versions/scripts-inventory.tsv（2026-11-06 快照）318 入口，UNREFERENCED=0；
本次对 229 个顶层脚本做了独立 rg 复核，均在 scripts 外有 ≥2 处引用（与快照一致）；
check-doctor.sh 自引用本身 + scripts/doctor/ 门禁集（15 文件）。

## §3 资产账（versions/layout.tsv ↔ 磁盘 + backup 兜底）

- layout.tsv 登记的**全部顶层条目实际存在，0 MISSING**（`linux` 是 `geekidos-linux` 软链，正常）。
- 不可再生件 bundle 兜底情况：
  - build/m3v2-7.3rc7 → ✅ `backup/build-bundles/m3v2-7.3rc7-git-20261105.tar.zst`（1,273 MiB）+ MANIFEST（13 行台账，含 m3v5-pristine/base-7.2 前身 m4-v3/m8 等 4 件 2026-11-05 删除件的 head SHA 与 kept_ref）。
  - out/ 历史镜像 → ✅ `backup/out-history-20261105/`（7,840 MiB，ARCHIVE.tsv 117 行 + ROLLBACK.sh）。
  - UEFI 构建 → ✅ `backup/uefi-builds-20261106/`（99 MiB）+ `backup/artifacts-bundle-20261105/`（44 MiB，SHA256SUMS.all）。
  - **待兜底**：`build/uefi-woa-prep`（8,371 MiB，2026-11-08 活跃）与 `out/real-ladder`（1,935 MiB）目前**只有目录本体，未见独立 bundle**（real-ladder 是脚本再生成的数据，风险低）。
  - backup 侧不可再生件均有时间戳目录 + 台账（MANIFEST/ARCHIVE/SHA256SUMS 模式统一），无需动作。

## §4 外部仓账（external/ + 相邻 git 树）

| 仓 | remote | HEAD | dirty |
|---|---|---|---|
| external/ext-repos/sunuefi | github.com/slwyts/Project-SunUEFI | afe922b @ main | 0 |
| external/aosp-vndk33/×6（system-core/libhwbinder/libhidl/frameworks-native/logging/libbase） | mirrors.tuna AOSP | 8301b33/bfbbb04/3f58213/938b812/ec3daa6/843e04，全部 detached | 各 0 |
| external/lc-cross/lc-src | **(无 origin)** | master，**无提交** | **17**（全部未跟踪） |
| geekidos-linux | git@github.com:GEEKiDoS/linux.git | ba28ec16f01 | 0 |
| wt/reb-731 | torvalds/linux（worktree） | ec74c4795a | 0 |
| external/ext-repos/{af,mu,vk64rd,mu-dodge,dl} | 非 git（静态快照，2,169/2,246/1,698/4/2 文件） | — | — |

## §5 建议动作分级（本报告只建议，不执行）

**可直接删（可再生/纯中间产物，≈9,400 MiB）**
- `build/base-7.2`（2,350 MiB，2026-11-06 后未动；7.2 基线产物可由 m1 流程重建；bundle 台账已有前身记录）
- `out/r21-sbstop-p55..p58`（≈2,570 MiB，sbstop 系列同构产物，保留最新 p59 即可）
- `build/grub-arm64`、`build/gunyah-port-6.6-orig`（12+9 MiB，陈旧）
- `scripts/__pycache__`、`logs/memstress-*` 旧样本（~14 MiB）

**需备份后删（≈24,300 MiB，删前 bundle + 导 diff）**
- `build/uefi-woa-prep`（8,371 MiB）：活跃工作树，先按 MANIFEST 模式出 git bundle + dirty diff。
- `out/real-ladder`（1,935 MiB）：确认 real-vs-ladder.sh 可完整再生成后再删。
- `out/` 其余 2026-10 月以前的散件（约 14,000 MiB）：逐件对照 out-history ARCHIVE，未归档的先补 ARCHIVE。
- `wt/reb-731`（12,516 MiB）：dirty=0，确认 lane 任务结束后可整删（worktree 可重建）。
- `external/lc-cross/lc-src`：17 个未跟踪文件**只有这一份**，先归档进 backup 再处理（或补 git init + commit）。

**保留（不动）**
- `backup/` 全部（不可再生件，30,429 MiB，账目齐全）；
- `build/m3v2-7.3rc7`、`build/daily`（活跃基线）；`geekidos-linux`、`stock-src`、`external/aosp-vndk33`、`dl-cam`（源码/固件资产）；`env-pass`、`bootslot-b`（含私钥，登记件）。

---
复现：`cd /home/xuqianhui/y700-elden && cat reports/artifacts/asset-inventory-20261108/du.tsv`；
`python3 scripts/static-scan.py --inventory`（对照 versions/scripts-inventory.tsv）；
`git -C external/lc-cross/lc-src status --porcelain | wc -l`。
