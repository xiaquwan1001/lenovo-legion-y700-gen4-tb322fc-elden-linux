# 仓库瘦身盘点（只读盘点 lane）— 2026-11-25

> 性质：**只读盘点报告**。本 lane 未删除、未移动任何文件、未做 git 写操作、未 ssh 上机。
> 唯一写入 = 本文件。所有「可删/归档」均为**待裁决候选**，执行须走各分级注明的授权与前置步骤。

## 0. 执行摘要 + 预期收益合计

盘面（`df -h /` 现查）：`/` = 937 G，已用 ~718 G，可用 ~172 G（81%）。主要占用：`out/ 44G`、`backup/ 29G`、`build/ 27G`、`geekidos-linux/ 6.3G`、`reports/ 2.0G`、`bootslot-b/ 1.8G`、`logs/ 0.6G`；**另有仓外 `/tmp` = 161 G（同一块 nvme、同一个 `/` 分区，未计入上面的仓内目录）**。

### 预期收益合计

| 面 | 分级 | 量 | 说明 |
|---|---|---|---|
| **仓内 A（立即可回收，无证据/无引用/可再生）** | A | **≈ 20.7 GB** | `build/` 编译对象残渣 + 重复/可重建 worktree；`build/` 27G → 约 6G |
| **仓内 B（归档后再删 / 需 owner 批准的子目录裁剪）** | B | **≈ 14 GB**（footprint） | 其中 10.5G 是 slim-v3 内部读回/中间件（**需 owner 批准**），其余 ~3.5G 走 tar.zst 或外置后删 |
| **仓内小计** | A+B | **≈ 34.7 GB** | 落地后 `/` 预计 81% → **~77%** |
| **仓外 `/tmp`（最大项，附带）** | 仓外 | **≈ 150 GB**（161G 中约 150G 为可清 temp） | 需 `git worktree prune` + 逐 `-evidence`/`-verify` 确认；是单块最大释放来源 |

> 关键结论：**out/ 的四大目录（40 G）全部是 `pending/verified` 现役件，不可删。** 真正的仓内大头在 `build/`（对象残渣与重复树）；**单块最省事的回收在仓外 `/tmp`（~150 G）**，但 `/tmp` 在盘点授权外，只列证据与命令。

---

## 1. 方法与判据（每条落纸的来源）

逐大件按四问判定（任务书要求①–④）：

- **① 是否被引用为「当前可用件」**：真源 = `versions/out-artifacts.tsv`（状态词表 active/verified/superseded/**pending=禁删**）、`versions/out-candidate-sha.tsv`（上机候选 sha 身份账）、`versions/vk-registry.tsv`（vk 代次账）、`TASKS/README.md`、`INDEX.md`、`RESOURCES/README.md §3`。
- **② 是否已有 `backup/` 或 `out-history` 同 sha 副本**：`backup/out-history-20261105/`（114 件 + `ARCHIVE.tsv`）、`backup/out-history-20261121/`、`backup/git-slim-20261113/`（3 bundle）。
- **③ 是否属 `.pi/trash` 保护范围**：真源 `.pi/memory/MEMORY.md` §20 —— `.pi/trash/` 受 harness 保护、清空须用户侧动作；本机 `~/.pi/trash` 现查 **4.0K 空**（无保护占用）。
- **④ `scripts/out-archive.py` dry-run 口径**（**只跑 dry-run**，命令 `timeout -k 10 300 python3 scripts/out-archive.py`）：
  ```
  out/ 现有 *.img: 24
  保留: 14 件 / 1006.7 MiB
  归档: 10 件 / 735.7 MiB -> backup/out-history-20261125
  （同文件系统 rename ⇒ 净释放 0；要真回收空间需 tar.zst 或上云后删）
  ```
  - **`out-archive.py` 只处理 `out/*.img`（顶层 24 件），不处理 out/ 下的大目录（40 G 四大目录完全不在其视野）。**
  - **只 `mv` 到 `backup/out-history-*`（同盘 rename）⇒ 净释放 0**。真正回收必须 `tar.zst` 或外置/上云后删（`scripts/out-archive.py:118` 原文）。
  - 待归档 10 件 = `vk184/vk185-adsp/vk187/vk187b/vk188/vk188b/vk189/vk190/vk192` + `dtbo-dummy.img`（735.7 MiB）。

---

## 2. out/ 盘点（44 G，373 项）

### 2.1 四大目录 = 40 G，全部 **C（必须保留）**

| 目录 | du | 状态（真源） | 判据 |
|---|---|---|---|
| `out/android-slim-v3-20261119` | **28 G** | pending（禁删） | `versions/out-artifacts.tsv:11`「唯一 final：主机造件+EDL 写入读回一致，但首启判据未取得（禁删，等上机）」；无 backup 同 sha 副本 |
| `out/android-min-20261118` | **8.5 G** | pending | `versions/out-artifacts.tsv:14`（S1/S3 对照要用的 **v1 造件**，`pkg/super_min.img` sha e3d0d26f…；删了 S1/S3 无从复现） |
| `out/min-restore-20261119` | **2.5 G** | verified | `versions/out-artifacts.tsv:12`「在机恢复件（唯一含 `/init` 成品…bigfile-verdict B 档不能删）」；sha 账 `versions/out-candidate-sha.tsv:7-10`（rootfs 6.4G sha `abf96ec4…`） |
| `out/android-slim-v2b-20261119` | **1.1 G** | pending | `versions/out-artifacts.tsv:10`（S4 二分要用的造件；删了 S2–S4 实验材料没了） |

**结论：这 4 个目录本体一律 C。** 但 `android-slim-v3` 内部有可回收的**子目录**（属 B，见 §5-B1）：

| 子目录 | du | 性质 |
|---|---|---|
| `new/super_min_v3.img` | 7.0 G | **final 成品**（MANIFEST sha `51eae107…`）→ 留 |
| `new/system_a.img` | 3.4 G | 成品 `system_a`（MANIFEST sha `db74cd06…`）→ 留 |
| `new/super_dbg.img` | 7.0 G | **debug 变体**（可重生，非 MANIFEST final）→ 候选裁 |
| `rb/super_rb.img` | 7.0 G | **EDL 读回副本（verify-only）**，与 new/super_min_v3 同源 → 候选裁 |
| `work/system_v3/` | 3.5 G | **解包中间目录**（system/ 2300+ 文件，可重生）→ 候选裁 |

### 2.2 out/ 其余 ~4 G

逐项判据要点（引用行号）：

- `out/uefi-bslot-20261121`（277 M）—— **C**：`out-artifacts.tsv:19` pending（GRUB 直起 a 槽四件，段 2/3 待设备窗）；sha 账 `out-candidate-sha.tsv:14-15`（esp.img/esp4k.img）。
- `out/g7-20261121`（206 M）—— **C**：`out-artifacts.tsv:20` pending「dwc3 v11 G7 上机件…**禁删**」；sha 账 `out-candidate-sha.tsv:16-17`。
- `out/android-v3-bringup-20261120`（203 M）—— **C**：`out-artifacts.tsv:14` pending（S1–S5 上机执行包，3 条 sha 账 `out-candidate-sha.tsv:11-13`）。
- `out/g7-routeA-20261121`（104 M）+ `out/g7-routeA-dtfix-20261123`（104 M）—— **C**：G7 上机候选（`TASKS/README.md:178` D2 flight-2 已上机结论、`reports/g7-routeA-dtfix-20261123.md`）。
- `out/boot-elden-vk*.img`（17 件，1.2 G）—— **混合**：`vk189`=**在机 daily**（`TASKS/README.md:177` D1）、`vk192`=**回退件**（`INDEX.md:345`）→ C；`vk172/173/181/182/183`、`m3v5-*`、`uefi 四件`、`boot-elden.img` → out-archive KEEP（`scripts/out-archive.py:41-56`）；其余 `vk184/185/187/187b/188/188b/190` = **B**（registry 有账，归档候选）。
- `out/*-kernel.gz` + `Image-*` + `*.cpio.gz`（613 M）—— **B**：`vk-kernel-identity.tsv`/`vk-registry.tsv` 均有代次账，tar.zst 后删。
- `out/grub-*` / `out/uefi-ddrmarks-*` / `out/debian`(21M) / `out/apk`(11M) / `out/arm64-apps`(27M) —— **B**（世代件/包缓存，可重生或可归档）。

---

## 3. build/ 盘点（27 G）—— A 级回收主战场

| 树 | du | 对象残渣（`*.o/*.ko/*.a/vmlinux*/*.cmd`） | git 关系 | 分级 |
|---|---|---|---|---|
| `build/g7a-tree` | 13 G | **≈ 9.92 G（10155 MiB）** | worktree of `build/elden-tree/.git`；HEAD `aebb727447` | **A**（对象）/ **A★**（整树，见注） |
| `build/g7-tree` | 7.5 G | **≈ 4.94 G（5061 MiB）** | worktree of `build/elden-tree/.git`；HEAD `aebb727447` | **A**（对象）/ **A★**（整树） |
| `build/elden-tree` | 2.6 G | 0.4 M | 独立 repo（`.git` 含 g7/g7a 全部 worktree 元数据） | **C**（worktree 历史基座） |
| `build/uefi-woa-prep` | 1.9 G | — | `merge-espfirst-20261121/` + `repos/` | **A***（保留被引用件） |
| `build/g7b-vk185` | 1.8 G | 0.2 M | worktree of `geekidos-linux/.git` @ `ec74c4795a43`，无脏改动 | **A★** |

判据与依据：

- **对象残渣（A，最安全）**：`g7a 9.92G + g7 4.94G ≈ 14.86 G`。是纯编译产物（`vmlinux.o/vmlinux/*.o/*.ko`），成品内核已导出到 `out/boot-elden-*.img`；不可作证据、无引用。`make clean`/`mrproper` 即可回收、不影响 `.config`（`check-doctor §5d/§12` 读 `build/*/.config` 仍在：`build/g7a-tree/.config`、`build/g7-tree/.config`）。
- **`g7a-tree` 与 `g7-tree` 是重复 checkout**：同一 HEAD `aebb727447`，**工作树 diff 逐字节相同**（`git diff | sha256sum` 两者均 `29a8bd76a61a71143cf1eb453d40e997b58615e6164b8c42fabf51a65f08221e`），脏改动 = dwc3 v11 六 blob + routeA DTS（已在 `patches/upstream/dwc3-v11-20261121/`）。⇒ 去掉对象后只保留**一棵**（约 3 G），另一棵（`g7-tree` 去对象后 ~2.6 G）可删。
- **`g7b-vk185`（A★）**：HEAD `ec74c4795a43` 在 `geekidos-linux` 的 140 refs 中可达（`git -C geekidos-linux branch -a --contains ec74c4795a43` 命中多条 `elden-archive/*`），无脏改动 ⇒ `git -C geekidos-linux worktree add build/g7b-vk185 ec74c4795a43` 可原样重建。
- **`uefi-woa-prep`（A\*）**：`INDEX.md:183` 引用 `merge-espfirst-20261121/out-p65/uefi-preamble65-r1.img`（`4d1ebc06…`）⇒ **保留 `out-p65`**；其余 `repos/`(295M) + `tree/` + `out-p69` 等为可重生工作区（~1.5 G）。

> **★ 注（强制前置，来自项目规则）**：`versions/layout.tsv:52` 明定 `build/` 为 `ignore` 工作区「**删除前必须先 bundle + 导 diff**」。因此整树级删除（`A★`）须先 `git diff > backup/…-dirty.diff`（本轮盘点**未执行**，仅列候选）。**纯对象残渣（A，`make clean`）不触发此规则。**

### build/ 收尾后形态（可行目标）

`build/` 27 G → **约 6 G**：`elden-tree .git 2.6G`（C）+ `g7a-tree` 源码 3 G（保留的重复树）+ `uefi-woa-prep/out-p65` 少量。**回收 ≈ 21 G（与 §0「A ≈ 20.7G」一致）。**

---

## 4. 附带目录（超出 out/build 主面，任务书 item 3/4 之外的顺带发现）

| 项 | du | 判据 | 分级 |
|---|---|---|---|
| `backup/` 全体（`official-rom 16G`、`out-history-20261105 7.6G`、`git-slim 1.2G`、固件/gpt/bundle…） | **29 G** | 不可再生原件，`RESOURCES/README.md §3` 资产台账；`layout.tsv:22` evidence/ignore | **C** |
| `geekidos-linux/` | 6.3 G | `layout.tsv:53` 2026-11-21 恢复的源树（vk 版本账/DTB 反查真源） | **C** |
| `bootslot-b/`（`boot_b-*` 签名件/回滚件） | 1.8 G | b 槽签名件 + 回滚件（`bootslot-b/README.md`；`vk192 bootslot-b/boot_b.img` 见 `INDEX.md:345`） | **C** |
| `reports/artifacts/`（`uefi-*` 264 个历史世代目录） | **1.8 G**（reports 2.0G 的 90%） | 仅 3 个被 `TASKS/INDEX` 引用（`uefi-daily-v8-20261116`、`uefi-eud-20261101`、`uefi-pstoreguard-20261116`）；其余为 2026-10~11 UEFI 世代取证快照 | **B**（tar.zst 归档后删） |
| `logs/`（`a-slot-forensics` 147M、`uefi-flashed` 135M、`forensics-20261120` 122M…） | **635 M** | 串口/取证日志（`layout.tsv:56` ignore 工作区） | **B**（tar.zst） |

---

## 5. 分级清单总表（A / B / C）

### A = 可安全删除（有账 / 有副本 / 纯可再生残渣，无证据、无引用）

| # | 项 | 量 | 判据 file:line | 前置 |
|---|---|---|---|---|
| A1 | `build/g7a-tree` 编译对象（`vmlinux* *.o *.ko *.a *.cmd`） | ≈9.92 G | 成品已导出 `out/`；`layout.tsv:52`(work/ignore)；非证据 | `make clean`；不动 `.config` |
| A2 | `build/g7-tree` 编译对象 | ≈4.94 G | 同上 | 同上 |
| A3 | `build/g7-tree` 整棵（去对象后） | ≈2.6 G | 与 g7a 同 HEAD `aebb727447`、diff 同 sha `29a8bd76…`（重复 checkout） | **先 bundle+导 diff**（`layout.tsv:52`） |
| A4 | `build/g7b-vk185`（整棵） | 1.8 G | HEAD `ec74c4795a43` 在 geekidos-linux refs 可达、无脏改动 | `git worktree add` 可重生；先 `git worktree prune` 记账 |
| A5 | `build/uefi-woa-prep` 除 `out-p65`（保留，`INDEX.md:183`）外的 `repos/tree/out-p69` | ≈1.5 G | 可重生工作区 | 保留 `out-p65` |
| A6 | `scripts/__pycache__/*.pyc` | 小（~百 KB） | 可再生字节码 | 无 |
| | **A 合计** | **≈ 20.7 G** | | |

### B = 应归档后再删（有身份账/可回取；**或** 需 owner 批准的子目录裁剪）

| # | 项 | 量 | 判据 file:line | 处置 |
|---|---|---|---|---|
| B1 | `android-slim-v3` 内 `rb/super_rb.img` + `work/system_v3/`（+可选 `new/super_dbg.img`） | **10.5 G**（含 dbg 则 17.5 G） | `out-artifacts.tsv:11` 目录级 pending（禁删）⇒ **需 owner 批准**；`new/MANIFEST.md` 已存 final sha（`51eae107…`/`db74cd06…`），rb=EDL 读回、work=解包中间 | 批准后 `rm`（final 件 sha 已入 MANIFEST）；不碰 `new/super_min_v3.img` 与 `new/system_a.img` |
| B2 | `reports/artifacts/uefi-*` 261 个非引用世代目录 | ≈1.7 G | 仅 3 个被 TASKS/INDEX 引用（见 §4） | `tar --zstd` 归档到外部/云后删；保留 3 引用目录 |
| B3 | `out/*-kernel.gz`(9×20M) + `Image-*` + `*.cpio.gz` | ≈613 M | `vk-registry.tsv`/`vk-kernel-identity.tsv` 有代次账 | tar.zst 后删（zip 已压缩，压缩比有限；外置更划算） |
| B4 | `out/boot-elden-vk{184,185,187,187b,188,188b,190}.img` | ≈574 M | 身份账在（`vk-kernel-identity.tsv`）；`out-archive.py` 归档候选（**但见 §8 风险：会误含 vk189/vk192**） | 走 `tar.zst` 或修正 KEEP 后 `out-archive.py --apply` |
| B5 | `logs/*` 历史串口/取证日志 | 635 M | `layout.tsv:56` ignore | tar.zst |
| | **B 合计** | **≈ 14 G**（其中 10.5G 需 owner 批准；其余 ~3.5G 经 tar.zst/外置回收） | | |

### C = 必须保留（现役候选件 / 未备份唯一证据）

| 项 | 量 | 判据 |
|---|---|---|
| `out/android-slim-v3-20261119` 本体（除 B1 子目录） | ~17.5 G（28 G − B1 裁剪） | `out-artifacts.tsv:11` pending/禁删 |
| `out/android-min-20261118` | 8.5 G | `out-artifacts.tsv:14` pending（v1 对照件） |
| `out/min-restore-20261119` | 2.5 G | `out-artifacts.tsv:12` verified（唯一 /init 成品） |
| `out/android-slim-v2b-20261119` | 1.1 G | `out-artifacts.tsv:10` pending（S4） |
| `out/android-v3-bringup-20261120` / `out/uefi-bslot-20261121` / `out/g7-20261121` / `out/g7-routeA-*` | ~0.9 G | `out-artifacts.tsv:14/19/20` + sha 账 |
| `out/boot-elden-vk189.img`（在机 daily）、`out/boot-elden-vk192.img`（回退件） | 164 M | `TASKS/README.md:177`（D1 vk189 在机）、`INDEX.md:345`（vk192 回退件） |
| `out/boot-elden-{vk172,173,181,182,183,m3v5-*,uefi 四件,boot-elden.img}` | ~1.0 G | `scripts/out-archive.py:41-56` KEEP 集 |
| `backup/`（29 G）、`geekidos-linux`（6.3 G）、`build/elden-tree`（2.6 G）、`bootslot-b`（1.8 G） | ~40 G | 不可再生/恢复真源/worktree 基座/b 槽回滚 |

---

## 6. item 4：重复文档 / 临时文件 / 构建残留（仓内）

- **无版本号拷贝**：`out/boot-elden.img`（21.4 M）—— `build-boot.sh` 默认产物、每次构建重生；`scripts/out-archive.py:43` 明确 KEEP（非证据、可重生，但脚本保护，**不算 A**）。无可安全直删的「无版本号」大 IMG（`SUPERSEDED.md` 列的旧 UEFI 判死件 **已不在盘**：`out/uefi-20261104-{nocivac,prog,dxe*}.img` 现查均 `No such file`）。
- **构建残留**：`build/g7a-tree`+`build/g7-tree` 的对象文件共 ≈14.86 G（见 §3 A1/A2）；`scripts/__pycache__/`（`.pyc` 一批）。
- **临时/草稿文件**：`out/draft-joonhoe-20261019.txt`（2.1K，历史草稿）、`out/mail-trash-20261102/`（476K）、`out/mail-20261102-*` 等历史发信目录（均已入 `out/mail-*`，体量小、可归档但影响可忽略）。
- **重复文档**：文档去重已有专账 —— `reports/doc-dedup-audit-20261112.md`、`reports/doc-audit-20261026.md`、`reports/tidy-docs-20261019/`（4 篇 lane 报告）。本轮**未重做文档内容判重**（属文档 lane）；仅提示：`reports/` 内 `upstream-recheck`/`upstream-delta`/`comm-triage`/`mail-triage`/`doc-audit` 等存在**同日/近名多版**（如 `doc-audit-20261026` vs `doc-dedup-audit-20261112`），体量均 <100K，非空间瓶颈。
- **无 `.orig/.bak/.rej/.swp` 散落**（现查仓内除 `.pyc` 外无此类）。

---

## 7. item 4：`/tmp` 残留（仓外，单块最大项）

`/tmp` 与 `/` **同分区**（`findmnt -T /tmp` → `/dev/nvme0n1p2 ext4`），故 `/tmp` 直接吃 `/` 的 84%。现查 **161 G**：

| 类别 | 代表目录（du） | 说明 |
|---|---|---|
| 安卓 super 重建/验证镜像 | `pkgtest 17G`、`lpz 16G`、`v3test 15G`、`super_rebuild.img 7G`、`super_corrupt_evidence.img 7G`、`ltbox-target 5.8G`、`b9 4.3G`、`rbex 3.9G`、`gu-test 3.3G` | **≈ 80 G**；`super_corrupt_evidence` 名为证据但 `grep reports/TASKS/INDEX` = **0 命中** |
| dwc3 上游门禁/verify worktree | `dwc3-v10/v11/v12/v13-*`、`v11-verify`、`gate-*`、`hap-*`、`muxes-v2`、`csiphy2`、`base-wt`…（各 ~1.9G） | **≈ 40 G**；其中 **9 个是注册在 `build/elden-tree` 的 git worktree**（`dwc3-v11-base/apply`、`dwc3-am-20261121` 等），删后须 `git -C build/elden-tree worktree prune` |
| sysroot / 冷启前后样本 | `trixie-sysroot 2.6G`、`ncm-cold-before/after 2.3+2.2G` | 可重生 |
| 其他 | 各 `*-verify`、`gate-*` 子目录 | 逐项确认 |

- **可回收 ≈ 150 G**（161 G 中去 `/tmp/.wine-1000`、`.X*` socket、少量在用件）。
- **注意**：`/tmp/lpz` 被 206 处报告/文档提及（多为路径记录而非硬依赖）；`/tmp/ltbox-target` 1 处命中。**/tmp 按设计随重启/清理消失**，但若报告里写死 `/tmp/<x>` 作证据路径，清理前需确认是否为唯一取证件（本盘点只读，未验证这些 /tmp 路径是否仍被当作证据引用）。
- **本项在「只读盘点」授权外**（不在 cwd 仓内），仅列证据与命令，**未执行任何动作**。

---

## 8. 风险与依赖（执行前必读）

1. **`scripts/out-archive.py` 的 KEEP 表已过时（关键）**：`scripts/out-archive.py:41-56` 的 KEEP 集**不含 `vk184`–`vk192`**，dry-run 会把 `vk189`（**在机 daily**，`TASKS/README.md:177`）与 `vk192`（**回退件**，`INDEX.md:345`）一并列为「归档」候选。⇒ **直接 `--apply` 会把现役/回退件移走**。要归档 B4 前须先给 KEEP 补 `boot-elden-vk189.img`、`boot-elden-vk192.img`（同步 `scripts/out-archive.py` 注释要求的 `reports/out-archive-*.md` 保留集）。
2. **`out-archive.py` 只 `mv`（同盘 rename）⇒ 净释放 0**（`scripts/out-archive.py:118`）。要真回收只能 `tar.zst` 或外置/上云后删。
3. **`patches/current-tree` 断指针（既有状态，非本轮引入）**：`patches/current-tree` = `build/daily`，但 **`build/daily` 现已不存在**（build/ 只剩 g7a/g7/elden/uefi-woa/g7b）。删/改组 build tree 前须同步该指针，否则 `build-kernel/iterate` 走 KDIR 默认会静默错树（`PITFALLS #162` 同类）。
4. **整树删除须先 bundle+导 diff**（`versions/layout.tsv:52`，反映在 A3/A4 的「前置」列）。
5. **worktree prune**：删 `build/g7b-vk185` 或 `/tmp` worktree 后须 `git -C <repo> worktree prune`，否则 git 元数据残留。
6. **O_DIRECT 复核**：归档/移动 `out/*.img` 的身份必须走 `scripts/odirect-sha.py`（页缓存位翻转取证，`PITFALLS #513`）——即 `out-archive.py --apply` 的内置 `odirect_sha()`；本轮**未跑 --apply**。
7. **`.pi/trash`**：`~/.pi/trash` 现查空；若此后 `rm` 到受保护路径会被 harness 拒并进 trash，清空须用户侧动作（`.pi/memory/MEMORY.md` §20）。

---

## 9. 建议执行顺序（供 owner 裁决，本 lane 未执行）

1. **先做 A（零风险，~20.7 G）**：`make -C build/g7a-tree clean` + `make -C build/g7-tree clean`（回收 ~14.9 G）→ `git -C geekidos-linux worktree remove build/g7b-vk185`（1.8 G，可重生）→ 删重复 `build/g7-tree` 与 `uefi-woa-prep` 非引用部分（先 bundle/diff）。
2. **再议 B1（需 owner 批准，10.5 G）**：确认 `new/MANIFEST.md` 的 final sha 后裁 `android-slim-v3/rb`、`work`（保留 2 个 final 件）。
3. **B2/B3/B5 归档（~3.5 G）**：`tar --zstd` 归档 `reports/artifacts/uefi-*`（保留 3 引用件）+ `out/*kernel.gz` + `logs/*` 到外部/云后删。
4. **/tmp（~150 G）**：`git -C build/elden-tree worktree prune` + 清理 `*-verify/gate/pkgtest/v3test/lpz/super_*` —— **单块最大释放**，须逐 `-evidence`/引用确认。
5. 收尾按 `.pi/AGENT-OPS.md §5`：`check-doctor` FAIL=0、`vk-identity --gate` 0 FAIL、`patches/current-tree` 指针修复。

---

## 10. 证据索引（现查命令，均可复跑）

```
df -h / ; findmnt -T /tmp
du -sh out/* | sort -rh | head          # 四大目录 28/8.5/2.5/1.1 G
du -sh build/* ; du -sh build/g7a-tree/{vmlinux*,*.o}   # 对象残渣 10155/5061 MiB
git -C build/g7a-tree diff | sha256sum   # 与 g7-tree 均 29a8bd76…（重复 checkout 实证）
git -C geekidos-linux branch -a --contains ec74c4795a43  # g7b-vk185 可重生
timeout -k 10 300 python3 scripts/out-archive.py          # dry-run：24 img / 归档 10 / 净释放 0
grep -n 'android-slim-v3\|android-min\|min-restore\|slim-v2b\|uefi-bslot\|g7-20261121' versions/out-artifacts.tsv
grep -n 'min-restore\|uefi-bslot\|g7-20261121' versions/out-candidate-sha.tsv
sed -n '177p' TASKS/README.md ; sed -n '345p' INDEX.md     # vk189 在机 / vk192 回退件
du -sh /tmp/* | sort -rh              # /tmp 161 G；pkgtest/lpz/v3test/… 
```
