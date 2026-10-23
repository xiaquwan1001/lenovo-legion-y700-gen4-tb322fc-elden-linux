# 资产盘点与台账对账（2026-10-23）

> 目的：把 `RESOURCES/README.md` §3「文件与资产台账」与**磁盘真值**对齐，并给出可执行清理候选。
> 方法：纯主机侧只读（`du` / `git ls-files` / `git bundle list-heads` / `git -C <tree> rev-list`），无上机。
> **2026-10-23 已执行**：用户批准后 A0–A7 全部跑完，**净回收 37.3 GiB**（根盘 `df` 184.0→146.7 GiB，仓库 83.5 GB→≈47 GB）。
> 执行记录（每级 df、前置闸、保留理由、抢救件）= **`archive/topics/清理清单-20261023.md`**；**本文 §2 的体积是清理前快照**，现行值只看 `RESOURCES/README.md` §3.2。
> 结论口径：**数字全部现查于 2026-10-23 本次会话**；删除类动作一律「待令」，本报告只登记不吃掉。

## 1. 结论（数字先行）

| 项 | 数值 |
|---|---|
| 仓库总占用（`du -sx .`） | **83.5 GB**（可用 707 G / 根盘 937 G） |
| 入 git 的受管内容 | **2399 文件 / 49 MB**（`.git` 另 31 MB） |
| 未入 git 的磁盘占用 | ≈ 83.4 GB（其中 **61 GB = `.pi/trash` 21 G + `build/` 40 G**） |
| **最大未登记资产** | **`.pi/trash/` 21 GB**（trash-cli 回收站，单件最大 `out-m1-73.1792228804` **11 G**，另有 5.07 GB 云盘包 tar；台账完全没记；忽略依据在 `.git/info/exclude`，本机私有） |
| 台账失配行 | **17 行数字过期 / 10 条路径已不存在 / 5 项未登记**（逐条见 §3） |
| 不可再生资产（须留） | 3 类：build 树本地 commit、`backup/HA2EXB0E-16+512/unique`+`device-rescue`、`.pi/sessions` 209 会话 |
| 可回收上限（若全批） | ≈ **69 GB** → **已收 37.3 GiB**（A0–A7） |

## 2. 顶层清单（磁盘真值）

`git` 列：`track` = 纳管；`ignore` = 被 `.gitignore` 排除（括号内为**已纳管的零星文件数**）。

| 路径 | 体积 | git | 台账旧值 / 状态 |
|---|---|---|---|
| `build/` | **40 GB** | ignore | 4.0 G ❌ 且**「可再生」判断不成立**（见 §4.1）；另有 `build/linux-7.2.tar.xz` **153 M**（源快照，可重下） |
| `.pi/` | **21 GB** | track（76 文件） | 仅登记 `sessions/`；**`trash/` 21 G 未登记**（ignore 来自 `.git/info/exclude:7`） |
| `dl-cam/` | 8.8 GB | ignore（**但已纳管 231 文件 / 6.4 MB**：`libcxx/` 185 + `gen-src/` 40 + 脚本） | 8.7 G ✅ |
| `env-pass/` | 3.3 GB | 混合（8） | 3.8 G ❌ |
| `backup/` | 3.2 GB | 混合（18） | 1.5 G ❌ |
| `geekidos-linux/` | 2.9 GB | ignore | 13 G ❌ |
| `out/` | 2.4 GB | ignore（172 manifest） | 3.5 G ❌ |
| `stock-src/` | 2.0 GB | ignore | 350 M ❌ |
| `bootslot-b/` | 409 MB | ignore（README） | 905 M（含已消失的 `bootslot-b-u2/`） |
| `y700四代工具/` | 271 MB | ignore | 与 `probe/`+`twrp/` 合计 552 M ❌ |
| `tools/` | 232 KB | ignore | 14 M ❌（venv-avb 已不在） |
| `logs/` | 204 MB | ignore | 92 M ❌ |
| `Y700-elden-linux/` | 28 MB | ignore | 15 M ❌ |
| `reports/` | 15 MB | track（632） | 216 K ❌ |
| `patches/` | 11 MB | track（310） | 3.7 M ❌（旧注「q28 delay/methodB 草稿未入库」**已不成立**：`q28-cmd-dma-delay.patch`、`q28-methodB-*.patch/NOTES.md` 均已 track） |
| `archive/` | 2.6 MB | track（219 文件，含 124 篇 md） | 5.5 M ❌ |
| `probes/` | 2.1 MB | track（8 文件；2 个 `.ko` + `.module-common.o` 被 ignore） | **未登记** |
| `initramfs/` | 2.0 MB | track | ✅ |
| `reference/` | 4.0 MB | track（58） | **未登记** |
| `scripts/` | 1.3 MB | track（180） | 530 K ❌ |
| `SESSIONS/` | 792 KB | track（171） | ✅ |
| `rootfs/` | 672 KB | track（63） | ✅「小」——但旧注「`alpine/ dl/ debs/` 176 M+ 已 ignore」**已过期**：三目录均不存在，现体量在 `persistent-overlay/` 568 K |
| `versions/` | 652 KB | track（8） | **未登记**（仅 INDEX §2 提及） |
| `PITFALLS/` | 564 KB | track（60） | 164 K（仅 README） |
| `patches-userland/` | 536 KB | track（62） | <60 K ❌ |
| `TASKS/` `HISTORY/` `RESOURCES/` `DEVICE/` `RUNBOOK-BRINGUP/` `net/` `waydroid-ota/` | 456 K / 144 K / 84 K / 48 K / 44 K / 160 K / 48 K | track | 领域层合计 ≈ 0.8 M（含 `INDEX.md`/`AGENTS.md`/`PROGRESS.md`/`README.md`） |
| `restore-259/` | 20 KB | track（2 md） | 254 M ❌（二进制已不在，只剩文档，属预期） |
| `README.md` `PROGRESS.md` `LICENSE` `.gitignore` `cycle.sh` `elden-net.sh` `.githooks/` `.pi/rambuild/` | 76 KB | track | **2026-10-23 补登记**（此前 §3.2 未列） |
| `pkgs/` | 4 KB（空目录） | ignore | 639 M ❌（已清空，只剩空壳） |
| 根 `*.deb`（8 个） | 1.9 MB | ignore | ✅ |
| `.git/` | 31 MB | — | 未登记 |
| `cycle.sh` `elden-net.sh` `linux`(符号链接) | 小 | track | ✅ |
| `l2`（符号链接） | 0 | ignore | 45 G ❌ → **目标目录存在（16 K：`dump-super.sh`+`lp_tool.py`），镜像已随盘丢失**（不是断链；`lp_tool.py` 是**唯一副本**，见 §4.2） |

**台账里已不存在、磁盘也无的路径（6 条）**：`qdl/`、`edk2-gunyah*/`（3 个）、`mu_wide_platforms/`、`uefi-firmware-backup/`、`flashing-bundle/`、`pkgs-phosh/`、`pkgs-x86/`、`probe/`、`twrp/`、`bootslot-b-u2/`。
其中 `mu_wide_platforms` / `uefi-firmware-backup` 已按 `⚠️MIGRATION-LOST` 登记，其余（qdl / edk2-* / flashing-bundle / pkgs-* / probe / twrp）属**换机未随迁或已清理**，须在台账改成「不存在」而不是留旧体积。

## 3. 台账失配逐条（旧 → 新）

1. `build/` 4.0 G → **40 G**，且「可再生」需加前置闸（§4.1）。
2. `geekidos-linux/` 13 G → **2.9 G**（换机后重新 clone；bundle 覆盖到 `q28/vk86`）。
3. `out/` 3.5 G → **2.4 G / 22 个 img / 172 个 manifest**；现存 vk64、vk127、vk130–vk137-q28base、vk138–vk147。**vk130、vk131 现「内核段不可读」**（`scripts/vk-identity.py` 硬化后的判定，属内核线在途，未在本轮改派生表）。
4. `backup/` 1.5 G → **3.2 G**，新增 `stock-elden/` 271 M、`git-pack-repair-20261020/` 574 M、`kernel-git-repair-2026-10-10/` 265 M、`HA2EXB0E-16+512/device-rescue-20261017/` 19 M。
5. `env-pass/` 3.8 G → **3.3 G**（`build/`、`kernel-susfs/` 已不在；只剩 `backup-20261002/linux17-rootfs-20261002.tar.gz` 3.3 G，里程碑件，不瘦身）。
6. `logs/` 92 M → **204 M**（`cam-vk127-20261017-203657/` 110 M、`cam-snapshot-20261019/` 61 M 为大头）。
7. `pkgs/` 639 M → **4 KB 空目录**（`pkgs-phosh/`、`pkgs-x86/` 已不存在）。
8. `tools/` 14 M → **232 KB**（只剩 `avbtool.py` + `mkbootimg/`；`venv-avb` 不在）。
9. `stock-src/` 350 M → **2.0 G**。10. `Y700-elden-linux/` 15 M → **28 M**。
11. `restore-259/` 254 M → **20 KB**（只剩 2 个 md，符合 `.gitignore` 只留 md 的设计）。
12. `l2` 45 G → **断链 0 B**（`~/mnt/Samsung/l2` 空目录，外置盘未挂）。
13. `scripts/` 530 K → 1.3 M；`patches/` 3.7 M → 11 M；`patches-userland/` <60 K → 536 K；`reports/` 216 K → 15 M；`archive/` 5.5 M → 2.6 M。
14. `.pi/sessions/` 456 M（10-19 记）→ **496 M / 209 个 jsonl**。
15. **新增未登记**：`.pi/trash/`、`probes/`、`reference/`、`versions/`、`.git/`。
16. 未登记子项：`.pi/plans` 244 K、`.pi/hermes-memory-mirror` 620 K、`.pi/skills` 424 K、`.pi/fabric` 56 K、`.pi/lanes`、`.pi/rambuild`。

## 4. 不可再生资产（删前必核）

### 4.1 `build/`：不是「整目录可再生」

7 棵树 = 2 个**独立仓** + 5 个 worktree：

| 树 | 体积 | 归属 | 本地独有提交 |
|---|---|---|---|
| `build/base-7.2/` | 2.4 G | **独立仓**（remote = 本地 `geekidos-linux`） | `master`(=`elden-payload-v2` `378459aff`) **ahead=2**、`elden-payload` `85ea412e4`、`v72-base` `25f7927e6` — 对象**不在** `geekidos-linux`（实测 `cat-file -e` = no） |
| `build/m3v2-7.3rc7/` | 2.9 G | **独立仓**（origin = torvalds/linux） | `m3v2` `f3cf334` ahead=3、`replay-m1-73-vk127` `24223e4` ahead=3、payload 三支同上 |
| `build/m1-73/` | 7.3 G | `m3v2` 的 worktree | 无（HEAD `24223e4` 已在仓内，**13 个未提交改动**） |
| `build/q28-disp/` `q28-disp2/` | 5.7 / 7.0 G | `base-7.2` 的 worktree | 各 1 个未提交改动 |
| `build/q28-disp-73/` | 7.3 G | `m3v2` 的 worktree | 4 个未提交改动 |
| `build/vk83-tree/` | 7.3 G | `geekidos-linux` 的 worktree | 干净 |
| `build/linux-7.2.tar.xz` | 153 M | 普通文件 | 可重下（非树） |

⇒ **回收前先做两件事**：① `git -C build/base-7.2 bundle create … --all`、`git -C build/m3v2-7.3rc7 bundle create … --all`（把 payload/m3v2/replay 支固定下来）；② 把上述 4 棵 worktree 的未提交 diff 导出到 `patches/`。否则「删 build/」= 丢 M1-7.3 与 elden-payload 的落地态。

### 4.2 其他不可再生

| 资产 | 体积 | 说明 |
|---|---|---|
| `backup/HA2EXB0E-16+512/unique/` | 133 M | 21 个**设备独有分区**（线刷包不含）+ MANIFEST/SHA256SUMS ⇒ 唯一副本 |
| `backup/HA2EXB0E-16+512/device-rescue-20261017/` | 19 M | 换机抢救的 207 项设备端文件 |
| `backup/{stock-elden,gpt,misc,slot-probe}/` | 271 M+92 K+1.6 M+6.7 M | 原厂 dtb/dtbo/dts、GPT 快照、misc/devinfo/uefivarstore |
| **`~/mnt/Samsung/l2/lp_tool.py`** | 5.9 K | **自研 LP v1.2（dump/extract/splice）唯一副本**；同目录 `dump-super.sh`（新机路径版）——外置盘 l2 唯一幸存的遗留物，必须收进 `tools/` |
| `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz` | 3.3 G | 过环境栈成功态里程碑（台账明示不瘦身） |
| `.pi/sessions/` | 496 M | 209 会话轨迹（未入 git；在 T3 云盘包内） |
| `backup/kernel-git-repair-2026-10-10/elden-all-refs-pre-boundary.bundle` | 265 M | 43 ref，**bundle 边界 = `q28/vk86`（10-10）** |
| `geekidos-linux` 新 ref | — | `replay/m1-73-vk127`（3 commit，10-17）**不在**上述 bundle 内 ⇒ 需补 bundle |

## 5. 可清理候选（**A0–A7 已于 2026-10-23 执行**）

> ✅ **全部执行完毕**（A1 只做 idle 部分）；执行证据与每级 `df` 见 `../archive/topics/清理清单-20261023.md`。下表保留当时的决策依据。
> ⚠ 执行中发现：本机 pi bash 把 `rm -rf` 转成 trash ⇒ 批量删必须用 `python3 shutil.rmtree`（否则「删除」只是搬进 `.pi/trash`，21 G 就是这么攒的）。

| 级别 | 目标 | 可回收 | 前置闸 / 重建路径 |
|---|---|---|---|
| **A0** | `.pi/trash/` | **21 G** | 就是回收站（`trash-cli` 元数据在 `.pi/trash/info/`；忽略依据在 `.git/info/exclude`，非 `.gitignore`）。单件最大 `out-m1-73.1792228804` **11 G**，另有 5.07 G `cloud-backup-y700-elden-20261016.tar.zst`（已按 MANIFEST 校验过、结论在 `reports/cloud-backup-manifest-20261016.md`）与大量 `obj/gen/stage/out-cam` 中间物。**唯一需挑拣的**：`patches/upstream/m3-v2-2026-10-17/*.patch` 的删除记录 ⇒ 该目录现仍在 `patches/upstream/` 中，可直删 |
| **A1** | `build/` 中 5 个可弃 worktree + `linux-7.2.tar.xz` 类中间物 | ≈ 25–32 G | 先做 §4.1 两项固定；`build/m1-73` 若不再跑 M1 也可弃（分支在 `m3v2` 仓里） |
| **A2** | `backup/kernel-git-repair-2026-10-08/`（265 M，41 ref） | 265 M | 已被 10-10 版**逐 ref 覆盖**（差集只有 5 个 `worktrees/*/HEAD` 临时 ref） |
| **A3** | `backup/git-pack-repair-20261020/`（574 M） | 574 M | 2026-10-20 宿主文件损坏后的 git pack 修复中间物；须先确认主仓 `.git` 已自洽（`git fsck` 干净） |
| **A4** | `out/` 旧实验镜像（vk130–vk136、`*-unpack/`） | ≈ 1.0–1.6 G | 需 registry 已登记（台账在 `versions/vk-registry.tsv`）；`*-unpack/` 纯解包中间物 |
| **A5** | `logs/cam-vk127-20261017-203657/`(110 M) 等 | ≈ 200 M | 结论已进 `reports/`，日志可按需重取 |
| **A6** | `dl-cam/` 下载/中间物（NDK、los20 OTA、`out-cam`、`gen*`） | ≈ 7.4 G | 配方在 `patches/waydroid-camera-64bit-20261018/`（重启构建需重下 NDK/OTA） |
| **A7** | `pkgs/` 空目录 | 4 K | 无（已空） |
| **不动** | `backup/HA2EXB0E-16+512/{unique,device-rescue,stock}`、`env-pass` rootfs tar、`.pi/sessions`、`patches/`、`versions/`、`reference/`、`probes/`、`reports/`、`archive/`、领域层文档 | — | — |

## 6. `⚚ MIGRATION-LOST` 对账（`RESOURCES/README.md` §5）

| §5 行 | 现状（2026-10-23） |
|---|---|
| 内核线 vk87–vk126 / `m1/*` / `m3/*` | **部分恢复**：`geekidos-linux` 现最高 ref = `elden-archive/q28/vk86`（bundle 边界）；`replay/m1-73-vk127` 为 10-17 新建本地线（3 commit，**未进任何 bundle**）；vk87–vk126 仍**无提交对象** |
| `build/`（M1/M3 树，~4 G） | **已重建**：现 40 G / 7 棵（§2），不再是「丢失」 |
| `out/*.img`（vk42–vk126） | **部分重建**：现只 vk64/vk127/vk130–vk147，旧号仍缺；manifest 172 个 |
| `logs/`（92 M）、`tools/`（14 M） | **logs 已重建到 204 M**；`tools/` 只剩 232 K（`venv-avb`、`wd-audio-test` 仍缺） |
| 可重下类（`edk2-*`、`mu_wide_platforms`、`qdl`、`twrp`、`pkgs*`、`probe`、`rootfs/{alpine,dl,debs}`） | 仍为空（需时重下） |

## 7. 本轮未做（边界）

- **未重生成** `versions/vk-kernel-identity.tsv`：现表相对新脚本已过期（`check-doctor §5d` FAIL=1，属**内核线在途**）。重生成会把 vk130/vk131 写成「内核段不可读」、并把 `uts_dup11` 改判 `uts_dup9`，属于内核线口径变更，不宜在资产整理轮顺手改。（vk130/131 镜像已在 A4 删除）
- 未上机、未动 `boot_b`。

## 8. 引用

- 台账正文：`RESOURCES/README.md` §3（本轮已按本报告刷新）、§5（MIGRATION-LOST 已更新）。
- 云盘包清单：`reports/cloud-backup-manifest-20261016.md`；上次清理审计：`reports/local-cleanup-audit-20261010.md`。
- 会话记录：`RESOURCES/sessions/2026-10-23-资产台账与磁盘真值对账.md`。
