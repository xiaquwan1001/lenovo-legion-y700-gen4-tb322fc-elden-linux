# 资产清查与删除候选报告 2026-11-05（lane B，只读）

> 纪律遵守：本轮零删除/零移动/零 commit，仅新建本报告与 `asset-inventory-20261105.tsv`。
> 机器账：`reports/asset-inventory-20261105.tsv`（60 行，含每条 verify_cmd）。
> 复用前账：`reports/asset-inventory-20261101.md`、`reports/asset-tidy-20261103.md`。

## §1 数字总表（实测 `du -sb`）

| 域 | 字节 | ≈GiB | 条目 | 候选可释放字节 |
|---|---:|---:|---:|---:|
| build/ | 190,717,538,999 | 177.6 | 37 顶层 | **176,951,812,523**（10 棵点名 101,187,707,943 + 「其余大棵」聚合行 75,764,104,580；均须先 bundle） |
| out/ | 11,478,045,229 | 10.7 | 6,089 文件（129 img=9,425,911,808 B） | 9,005,520,940（linuxstop×7 + 历史 img 主体 + stage-debian） |
| backup/ | 21,164,604,918 | 19.7 | 25 | 0（never-delete） |
| env-pass/ | 3,443,814,333 | 3.2 | 3 | 3,443,799,223（backup-20261002 归档） |
| dl-cam/ | 2,745,503,645 | 2.6 | 23 | 0（keep） |
| geekidos-linux/ | 2,825,170,506 | 2.6 | 43 | 0（仅记账） |
| stock-src/ | 2,105,289,516 | 2.0 | 3 | 0（keep） |
| external/ | 1,927,530,016 | 1.8 | 1 | 0（11-03 刚收拢） |
| bootslot-b/ | 1,610,620,899 | 1.5 | 20 | 0（never-delete：私钥+槽备份） |
| .pi/sessions/ | 704,898,264 | 0.7 | 290 | 704,898,264（归档压缩） |
| reports/ | 1,735,492,334 | 1.6 | 602 | 236,200,182（uefi-dxe×11 归档） |
| logs/ | 35,381,575 | 0.03 | 258 | 0（小） |
| **候选合计** | | | | **build 外 21,315,111,107 ≈ 19.9 GiB；含 build 全部候选 = 198,266,923,630 ≈ 184.6 GiB** |

加总复现命令：
`awk -F'\t' '$5 ~ /candidate/ {s+=$2} END{print s}' reports/asset-inventory-20261105.tsv`
（已验算：`awk -F'\t' '$5 ~ /candidate/ {s+=$2} END{print s}' reports/asset-inventory-20261105.tsv` = 198,266,923,630；其中 build 10 棵点名行相加 = 101,187,707,943。）

## §2 删除候选 Top（供裁决；本 lane 未执行任何删除）

| 路径 | 字节 | 为什么不需留 | 复核命令 | 风险 |
|---|---:|---|---|---|
| build/ 10 棵旧线（vk151、vk-camssv3、gunyah-port、m3v5-fix、m3v5-pristine、uefi-woa-prep、q28-v2、m1-73、q28-disp-73、vk64-{sync,ret}-arm） | 101,187,707,943 | 全部为 worktree/独立仓，产物已入 out/ 并登记 identity.tsv；可由 patches+replay 技能再生。**前置闸（RESOURCES §3）：先 `git bundle` + 导出 dirty diff（13 棵有脏文件、m3v2-7.3rc7 共享 .git 有 142 个未推送提交，其中 m3v2-7.3rc7 与 base-7.2 两个 .git 容器本身不可删）** | `git -C build/X rev-parse --git-common-dir; git -C build/X status --porcelain\|wc -l` | **高**（脏文件/未推送提交必须先 bundle 验证可恢复） |
| out/*.img 历史主体（53 个 boot-elden-vk*.img + 其余登记历史件） | 8,166,915,360 | 均登记于 versions/vk-kernel-identity.tsv（130 行）；由 build 树+patches+mkbootimg 可重放（kernel-downstream-replay 技能）。保留口径：在机对应件、m3v5-onboard 系列、最新 vk 线即可 | `ls out/boot-elden-vk*.img\|wc -l; grep -c ok versions/vk-kernel-identity.tsv` | 中 |
| out/linuxstop1-7.img | 704,643,072 | slot_dump 序列：7 件内核段 kbin_sha 全同（5543b181，identity.tsv:75-81），仅整件 sha 因 footer 不同；信息量≈1 件 | `sha256sum out/linuxstop*.img; awk -F'\t' '$2~/linuxstop/' versions/vk-kernel-identity.tsv` | 低（建议打包归档而非直删） |
| env-pass/backup-20261002 | 3,443,799,223 | 2026-10-02 老 rootfs 整包；当前 root = /dev/sda17 由 rootfs/ 脚本体系重建；无任何 md 引用命中 | `rg -lF backup-20261002 . --glob '!build/**'` | 中（若 rootfs/ 脚本未覆盖 10-02 时期内容则降级为封存） |
| .pi/sessions/（旧会话） | 704,898,264 | 290 个 jsonl，历史结论已沉淀 reports/TASKS；可压缩外移（云盘/U盘） | `ls .pi/sessions\|wc -l` | 低 |
| reports/artifacts/uefi-dxe{,2..11}-20261104 | 236,200,182 | UEFI DXE 二分中间件 11 份（各 ~21.5 MB），终态证据在 uefi 报告；可重编译 | `du -sb reports/artifacts/uefi-dxe*-20261104 \| awk '{s+=$1}END{print s}'` | 低-中 |
| out/stage-debian/ | 134,384,685 | staging 副本，与 out/debian、modstage-* 大量同 sha（20261101 盘点表 1 #9） | `rg -lF stage-debian --glob '!out/**' --glob '!build/**'` | 低 |
| reports/artifacts/ 34 个无引用目录（20261101 盘点 §3：q28-clkdiag*、q32-boot*、uefi-boot-20261101-*×19 等） | ~数 MiB | 无 reports/*.md 引用，正式证据已在报告 | `rg -l uefi-boot-20261101 reports/*.md` | 低 |

## §3 建议封存（打包/外移，不删）

1. `out/linuxstop1-7.img` → 打包 tar.zst 后可只留 linuxstop1（内核段相同）。
2. `.pi/sessions/` → 压缩到 USTC 云盘（reccli-ts）后本地留近 30 天。
3. `env-pass/backup-20261002` → 打包上云盘，本地删除（先验证 rootfs 重建链）。
4. `reports/artifacts/uefi-dxe*-20261104` → 与 uefi 取证目录一起打一个 tar。
5. `build/` 10 棵 → **先** `git bundle create build-bundles/<X>.bundle --all` + `git diff > dirty.diff`，bundle 存 backup/ 或云盘后再删树。

## §4 不可删除清单

- `backup/` 全部 21.2 G（官方线刷包 16.8 G、EDL 包、整机备份、GPT、corrupt-20261103 取证件 84.5 MB）——唯一副本/不可再生。
- `bootslot-b/`：**avb.key（私钥，唯一）** + 17 个 boot_b 槽备份件（回退链；`boot_b.img` 为可变工作副本另当别论）。
- `out/corrupt-20261102/`（静默损坏取证，110 MB）、`backup/corrupt-20261103/`。
- `build/m3v2-7.3rc7/.git` 与 `build/base-7.2/.git` 两个**共享 .git 容器**（被 27+2 棵 worktree 引用，含 142/2 个未推送提交）；`geekidos-linux/.git` 同理。
- `out/debian/`、`out/modstage-vk{163,172}/`（模块树 uts_dup 锚点，DEVICE §1.1）。
- `reports/trials/`、identity.tsv 引用的全部 manifest。

## §5 需用户裁决项

1. **build/ 10 棵（101.2 GB）是否批准 bundle→删**：最大杠杆，但有 13 棵脏文件 + 共享 .git 未推送提交，必须走 RESOURCES §3 前置闸；建议先从 dirty=0 的 m3v5-pristine（12.7 G，树头=在机 m3v5-onboard 34865c89）试点。
2. **env-pass/backup-20261002（3.4 G）**：老 rootfs 是否还有回退价值，需用户确认；确认后走云盘封存。
3. **out/ 历史 img（8.2 G）保留窗口**：建议保留「在机件 vk172 系 + m3v5-onboard 系 + 最新线」约 1–2 G，其余按月龄归档；需用户定保留跨度。
4. **在机 fb55997c 对应件核对**：`boot_b-device-backup-20261101.img` 实测 sha=aedae5f1（20261101 盘点口径），与 DEVICE §1.1 的 fb55997c 之间有 11-02 UEFI 轮刷写回写差异；**本轮未证哪个 out/bootslot 文件逐字节等于当前在机 fb55997c**——下次上机前应先 `sha256sum bootslot-b/boot_b.img`（现为 f26e79c5）并与在机读回比对，再裁决槽备份去留。
5. `.pi/sessions/` 归档策略（本地留多久）。

—— lane B 只读盘点完毕，未做任何写/删/移动/网络投递操作。

---

## §6 父进程裁决（L0，2026-11-05；本节由父进程补写）

> lane B 只读盘点 → 父进程独立复核（`du -sb` 三域、`awk` 候选加总 198 266 923 630 复算一致、`sha256sum out/linuxstop*.img`、
> `git -C build/* status` 脏文件数、`git -C build/m3v2-7.3rc7 log --branches --not --remotes | wc -l` = 142）后裁决。

### 6.1 本轮已执行（唯一删除动作）

| 动作 | 体积 | 保全物 | 复核 |
|---|---|---|---|
| `reports/artifacts/uefi-dxe{,2..11}-20261104/` 下 77 个二进制载荷（`SM8750_EFI.fd`、`bootpayload.bin`、`kernel.bin`、`lenovo-y700g4-v3.img`、`payload-v2aligned.bin{,.gz}`、`uefi-v0.img`）打包后删除原件 | 236 200 182 B → bundle **45 868 877 B**，净释放 **≈172 MiB** | `backup/artifacts-bundle-20261105/uefi-dxe-20261104-binaries.tar.zst`（`zstd -t` OK；77 成员）+ `SHA256SUMS.all`（77 行，逐件 sha）；原目录文本三件（`build.log`/`manifest.txt`/`SHA256SUMS`）与 `BootShim.bin` 留原处 | 抽检 1 件端到端 sha 一致（`ce766c5b…` = dex5 `SM8750_EFI.fd`） |

**裁决理由**：这 11 份是 UEFI DXE 二分的中间载荷（每目录 7 件同名、内容跨目录高度重复），终态结论与构建配方已在 `reports/uefi-payload-execution-20261104.md` 等报告；打包后仍可逐件按 sha 复现，等于零证据损失。

### 6.2 裁决为「不删」（本轮及可预见期）

| 项 | 体积 | 理由 |
|---|---|---|
| `backup/` 全部 | 21.2 G | 唯一副本/不可再生（官方线刷包 16.8 G、EDL 包、整机备份、GPT、corrupt 取证） |
| `bootslot-b/` | 1.6 G | 含 `avb.key`（唯一私钥）+ 17 个槽备份（回退链） |
| `out/corrupt-20261102/`、`backup/corrupt-20261103/` | 194 M | 静默损坏取证 |
| `build/m3v2-7.3rc7/.git`、`build/base-7.2/.git`、`geekidos-linux/.git` | — | 共享 .git 容器（27+2 棵 worktree 引用；142 + 2 个未推送提交） |
| `out/debian/`、`out/modstage-vk163|vk172/`、`out/stage-debian/` | 683 M + — + 135 M | Debian/Mobian 线的 deb 源与模块树锚点；`stage-debian` 由 `rootfs/debian/stage.sh` 可重建但仍属 T14/T17 在用工作区 |
| `reports/trials/`、`versions/vk-kernel-identity.tsv` 引用的 manifest | — | 机器账锚点（删则 §5d/§5e 失真） |

### 6.3 裁决为「该删，但需前置闸 / 需用户点头」（已登记 `RESOURCES/README.md` §3「可清理标记」B1–B4）

| 项 | 可释放 | 闸门 | 建议顺序 |
|---|---|---|---|
| `build/` 十条旧线 worktree（B1） | 101.2 G（全部大棵合计 177 G） | 逐棵 `git bundle --all` + 导出 dirty diff；13 棵有脏文件 | 1) 试点 `build/m3v5-pristine`（dirty=0，head `34865c89` = 在机 m3v5-onboard tree_head）；2) 逐棵 bundle 后删；3) 回改 `TASKS`/`DEVICE` 中对这些树路径的引用 |
| `out/` 历史镜像（B3） | 8.2 G | **账目闸**：每件在 `versions/vk-kernel-identity.tsv` 有行，直接删会让 `check-doctor §5d` 报缺 | 与账目同批：先移 `backup/out-history-<date>/`，只改 ledger 路径列；禁重跑 `vk-identity.py`（迁移纪律） |
| `env-pass/backup-20261002/`（B2） | 3.44 G | 验证 `rootfs/` 重建链覆盖 10-02 内容 | 打包上云盘 → 删本地 |
| `.pi/trash/files/`（B4） | 484 M | 无（回收站） | 随时 |
| `.pi/sessions/`（H1） | ≤705 M | 归档非活跃会话 | 压缩上云盘后本地留近 30 天 |

### 6.4 本轮不改的账目口径

- **不重生成** `versions/vk-kernel-identity.tsv`、**不动** `versions/vk-ledger-known-issues.tsv`（迁移纪律：镜像缺失会清空/污染 118 行表）。
- 在机 `boot_b` 现值仍只认 `DEVICE/README.md` §1.1（vk172 `fb55997c…`）；lane B 未证 `bootslot-b/boot_b.img` 与在机值的关系（该文件是随刷写变动的工作副本），下次上机先 `sha256sum` 对读回再动槽备份。

---

## §7 父进程执行记录 — `build/` 清扫（2026-11-05 第二轮，用户批准后执行）

> 用户 2026-11-05「可以，开始逐步推进」放行 B1。本节是**执行账**（§2/§3 是 lane B 的只读盘点，保留原样）。
> 命令级明细：`backup/build-bundles/MANIFEST-20261105.tsv`（干净树 13 行）、`backup/build-bundles/dirty-20261105/MANIFEST.tsv`（脏树 16 行）。

### 7.1 数字

| 项 | 前 | 后 |
|---|---:|---:|
| `build/` 总体积 | 190.7 G | **16 G**（释放 **≈174 G**） |
| `build/` 顶层条目 | 37 | **13**（+ 新增 `build/daily`） |
| 宿主可用空间 | 346 G | **≈503 G**（`df -h /home`） |
| 备份代价 | — | `backup/build-bundles/m3v2-7.3rc7-git-20261105.tar.zst` **1.33 G** + 脏树 diff/untracked **756 K** |

### 7.2 做法（不是 `rm -rf`）

1. **共享 `.git` 整体备份**：`build/m3v2-7.3rc7/.git`（1.5 G，26 个 worktree 引用 + **142 个未推送提交**）→ `tar | zstd` 1.33 G。
   **先试图 `git bundle --all` 但失败**：该仓是**浅克隆**（`.git/shallow` 435 行），bundle 无法独立 clone（`Failed to traverse parents of commit 6eca69fc…`）
   ⇒ 改 tar `.git`；抽验 = 解包到 `/tmp` 后 `cat-file -t` 10 个关键提交全为 commit、`rev-list --count --all` = 41750、`--branches --not --remotes` = **142**（与清理前一致）。
2. **detached HEAD 全部先落 ref**：删前对每个 detached 树建 `tidy-20261105/<name>`（例：`tidy-20261105/m3v5-pristine` = `34865c8915` = 在机 m3v5-onboard 的 tree_head；`tidy-20261105/vk151` = `509f271d52` = vk172 起的 fastrpc 线）。
   有分支的树直接保留原分支（`b5/send-20261028`、`m4/v3-20261029`、`wl2868c-v5`、`m3v6` 等）。
3. **脏树先导 diff**：16 棵脏树各自 `status.txt` + `diff --binary HEAD` + `untracked.tgz`（`gunyah-port` 10 个未跟踪文件 359 K、`b5-v2` 4 个 5 K）。
4. **只删工作树**：`git worktree remove --force`（`build/vk64-{sync,ret}-arm` 在 `geekidos-linux` 仓下；`vk-camssv3` 已脱管，`rm -rf` 前 diff 已导出）。
5. **重建日常线树**：`git worktree add --detach build/daily replay-m1-73-vk127`（= `24223e44ad`，在机 vk172 源）+ `patches/config-vk163-modular-v2-20261026`；`patches/current-tree` 由已删的 `build/vk151` 改指 `build/daily`。

### 7.3 附带修复（删树暴露的三个门禁失效）

| 问题 | 原状 | 修法 |
|---|---|---|
| `patches/current-tree` 指向已删树 | `build/vk151`（`iterate.sh`/`mod-loop`/`apply-kernel-fragment` 的默认树全落空） | 改指 `build/daily`；`scripts/check-modular-config.sh` 增加「current-tree 失效 ⇒ 退到任意 `build/*/.config`」兜底 |
| `check-doctor` §5f 写死树名 | 只查 `build/m1-73 build/base-7.2 build/q28-disp-73 linux`，树没了就**静默跳过**（门禁失效） | 改**动态发现** `build/*/.config` + 首个有 `vmlinux` 的树做 of_node 偏移核对 |
| `check-doctor` §12 只在 `build/vk151` 存在时跑 | 删树后整节跳过 | 改为按 `patches/current-tree`（含兜底）解析，解析不到才 warn |

### 7.4 已知损失与残留风险（如实登记）

- **`build/b5-v2` 的 3 个已改文件**（`dsi.h`/`dsi_host.c`/`dsi_manager.c`）**未能导出 diff**：该树是 partial clone，基对象不可读（`fatal: unable to read 6ec5e0a0…`），`tracked.diff` 为 0 字节。
  该树同时出现**文件名位翻转**（`tools/testijg/`、`ublj`、`vdSo`、`dr)vers` 等 D/?? 对）——与 2026-11-03 `out/boot-elden-m3v5-daily.img` 静默损坏同型，**疑存储/RAM 层问题，非本轮操作造成**；已入 `assets` 取证清单（`status.txt` 原样留档）。
  影响面有限：该树的 B5 v2 系列**完整存档**在 `patches/upstream/m6-b5-v2-20261102/`（4 枚 + `GATES.md` + logs），未提交改动属 v3 在写内容 ⇒ 需重做，不属不可恢复资产。**建议下次任务优先排查硬件**（本机另有 `hw-stability` 取证项目）。
- `build/m3v2-7.3rc7/.config` 原为 2026-10-26 m3v4 实验遗留（`CONFIG_SUSPEND=y`，正是 §5f 注释里记的那类 ABI 漂移源），已用 `patches/config-vk163-modular-v2-20261026` 覆盖；该树不是构建树，仅作分支宿主。
- 删除后 `check-doctor` 的 §5f/§12 从「跳过」恢复为**真实检查并通过**（`build/daily` ABI 27 项一致、模块化门禁 3 项 PASS）。
