# 内核 git 树合并/差分分析（geekidos-linux × wt/reb-731）— 2026-11-11

> 只读分析。禁 fetch/pull/checkout/commit。证据行号基于当日快照。
> 范围：`geekidos-linux`（浅克隆）与 `wt/reb-731`（worktree）及 `versions/vk-kernel-identity.tsv`。

## 1. 现状图：仓库、worktree、分支拓扑

### 1.1 两个独立对象库，`geekidos-linux` 与 `wt/reb-731` **不共享任何对象**

- `git -C wt/reb-731 rev-parse --git-common-dir --git-dir` →
  `/home/xuqianhui/y700-elden/build/m3v2-7.3rc7/.git` + `.../.git/worktrees/reb-731`；
  `wt/reb-731/.git` 内容为 `gitdir: /home/xuqianhui/y700-elden/build/m3v2-7.3rc7/.git/worktrees/reb-731`。
  ⇒ **wt/reb-731 属于 `build/m3v2-7.3rc7` 这一个对象库**，不是 `geekidos-linux` 的 worktree。
- `git -C build/m3v2-7.3rc7 worktree list` → 3 个 worktree：
  `build/m3v2-7.3rc7 e18a4a66eb [wl8board]` / `build/daily 4da9a8b69f (detached)` / `wt/reb-731 ec74c4795a (detached)`。
- `geekidos-linux` 是**另一棵树**：remote 为 `origin=git@github.com:GEEKiDoS/linux.git`、`gitlab=https://git.ustc.edu.cn/xqh/y700-elden-kernel.git`，
  HEAD = `ba28ec16f01`（分离），`git log --oneline -15` 在该浅克隆里**只有 1 条可见提交**（`ba28ec16f01 power: supply: qcom_battmgr: omit SM8750 maximum-load power reading`）。
- 两边 `rev-parse --is-shallow-repository` 均为 `true`；`git -C geekidos-linux branch -a | wc -l` = 70，命名空间分布
  （`git branch -a --format='%(refname)' | awk -F/ ...`）：`elden-archive 15 / gitlab 3 / origin 1 / reb731 49 / replay 1` + 1 条分离头指针。
  即 `geekidos-linux` 里 `reb731/*` 是**远端跟踪 ref**（远程设备仍在），这与 `wt/reb-731` 的对象库是两套。

### 1.2 `wt/reb-731` 对应哪个「分支」：**没有本地分支，detached HEAD**

- `git -C wt/reb-731 rev-parse --abbrev-ref HEAD` → `HEAD`（即 detached），HEAD = `ec74c4795a43`。
- 该 commit 在 `build/m3v2-7.3rc7` 对象库里是 **tag `refs/tags/vk185`**（`git for-each-ref | grep vk18[457]` →
  `refs/tags/vk184 4da9a8b69f`、`refs/tags/vk185 ec74c4795a`、`refs/tags/vk187 4da9a8b69f`）。
  ⇒ 结论：wt/reb-731 = **vk185-adsp 的 tree**（对应 `versions/vk-kernel-identity.tsv:72` 的 `src_sha=ec74c4795a43`），
  是以 tag 锚定的临时检查点，而非可长期推进的分支。
- 工作区干净（`git -C wt/reb-731 status --porcelain | wc -l` = 0）。
- `wt/reb-731` 的提交史极短：`git log --oneline --reverse | head -3` →
  `79a907609d Linux 7.3.1` → `88cd0bc0f4 elden payload v2 ...` → `4da9a8b69f drm/msm/dsi/phy: program PLL_SYSTEM_MUXES ...`（再上一条即 `ec74c4795a`）。
  即 **基座只有 7.3.1 + 3 条本仓提交**，没有 7.2-elden 的下游历史。

## 2. vk 版本账的引用覆盖与重复

### 2.1 vk184/185/187/187b 四行（`versions/vk-kernel-identity.tsv:71-74`）

| vk | src_sha | src_ref | src_tag | tree_head | tree_state | flag |
|---|---|---|---|---|---|---|
| vk184 (`:71`) | `4da9a8b69fc8` | `branch:vk184,vk185` | `vk184` | `4da9a8b69fc8` | clean | `ok\|uts_dup2` |
| vk185-adsp (`:72`) | `ec74c4795a43` | `branch:vk185` | `vk185` | `ec74c4795a43` | clean | `ok` |
| vk187 (`:73`) | `4da9a8b69fc8` | `branch:vk184,vk185` | `vk184` | `4da9a8b69fc8` | clean | `num_ne_tag(vk184)` |
| vk187b (`:74`) | `4da9a8b69fc8` | `branch:vk184,vk185` | `vk184` | `4da9a8b69fc8` | clean | `num_ne_tag(vk184)\|kbin_shared2\|uts_dup2` |

- **tree_state 分布**：本任务这 4 行全部 `clean`（无 dirty/暂存）。全表里 dirty 只出现在 `:1-2`（dtbo1/dtbo2，`tree_head=24223e44ad80 state=dirty`）。
- **vk 号指向同一 tree_head（镜像重复）**：`vk184`/`vk187`/`vk187b` 三者 `tree_head` 均为 `4da9a8b69fc8`，
  且 `git -C build/m3v2-7.3rc7 rev-parse vk184^{tree} vk187^{tree}` → **两者 tree 完全相同的 `64704fd63e2e`**，`vk185^{tree}=1c7abdae88b9`。
  ⇒ **vk187 与 vk184 是同一棵树的两个版本号（同 tree 不同 image sha）**：
  image sha `c76bc2e8e75a`(vk184) / `d2a8bbc7f8c4`(vk187) / `1d11e81557b4`(vk187b)，版本账因此打 `num_ne_tag(vk184)` 与 `kbin_shared2`。
- **src_ref/source tag 的实质**：`src_ref` 写的是 `branch:vk184,vk185`，但对象库中 `vk184`/`vk185`/`vk187` **只是 tag，没有同名 branch**
  （`git -C build/m3v2-7.3rc7 for-each-ref | grep vk18[457]` 仅返回 `refs/tags/*`；`branch -a | grep vk18[457]` 为空）。
  ⇒ 版本账的 `src_ref=branch:` 字段与仓库实际 ref 类型**不一致**（改名丢失 branch，只剩 tag），属账目漂移，非镜像问题。
- **哪些分支没被任何 vk 号引用**：见 2.2 的 ref 清单覆盖统计。

## 3. 候选合并对的文件级差分规模

> 均用 `git -C build/m3v2-7.3rc7 diff --stat <base>..<tip>`（只读，不写任何 ref）。

### 3.1 重要前提：`vk184` 与 `wl8board` **无共同祖先**

- `git -C build/m3v2-7.3rc7 merge-base vk184 wl8board` → **空输出**；而 `merge-base vk184 m3v7` → `040f1aba97`。
  ⇒ `vk184`（7.3.1 短史）+ `ec74c4795a` 属于「短基座」历史线；`wl8board`(e18a4a66eb) 属于另一条（含完整 7.x 历史）的线，
  两者 diff 不是可合并差分，而是**整树重写规模**（见 3.2 的 1.6 万文件）。**这类对比不可用作合并代价参考**。

### 3.2 三对候选的差分规模

| 对 | 命令 | 规模 | 读法 |
|---|---|---|---|
| `vk184..vk187` | `diff --stat vk184..vk187` | **空（0 文件）** | 同 tree（`64704fd63e2e`），仅版本号不同 → 纯重复 |
| `vk184..vk185` | `diff --stat vk184..vk185` | **1 文件 / +1 行**：`arch/arm64/boot/dts/qcom/sm8750.dtsi` 加 `qcom,non-secure-domain;`（fastrpc/adsp 节点） | 极小，唯一真实功能增量 |
| `m4/v3-20261029..draft/m4-split` | 同 | **3 文件 / +9 −57**：`camss-csid-980.c`(−49/-)、`camss-csid.h`(−2)、`camss-vfe.c`(重写 15 行) | 同一功能的两个分支形态 |
| `m4/v3-20261029..m4/send-20261028` | 同 | 同上 3 文件 +9 −57 | 发送版与 draft 可能等价，**待逐条 diff 确认**（未做） |
| `vk185..wl8board`（参考） | `diff --stat -- arch/arm64/boot/dts/qcom drivers` | 7415 文件 / +597795 −217717 | 跨历史线，无合并价值 |
| `vk184..m3v7`（参考） | `diff --stat -- arch/arm64 drivers` | 8181 文件 / +646400 −228567 | 同上；m3v7 与 wl8board **互不为祖先**（`--is-ancestor` 失败） |

结论：**真正小的差分只出现在同一祖先家族内部**（vk184↔vk185 ↔ m4/v3↔draft/m4-split），
跨线对比的「万级文件」是 base 不可比造成的伪差分。

## 4. 浅克隆不能 fetch 的风险

### 4.1 两个对象库都是 shallow 且新增了 partial clone，风险叠加

- `build/m3v2-7.3rc7`（wt/reb-731 的宿主对象库）：`--is-shallow-repository` = `true`，`.git/shallow` **439 行**；
- `geekidos-linux`：`true`，`.git/shallow` **18 行**；
- `build/m3v2-7.3rc7/.git/config` 里 `remote.origin` / `remote.torvalds` / `remote.next` 全带
  `promisor = true` + `partialclonefilter = blob:none`（`git remote -v` 后面也标 `[blob:none]`）；
  `.git/objects/pack/*.promisor` 文件存在（`ls -lh .../pack/`）。
  ⇒ 这是 **shallow + partial clone 双层**：连「已存在的提交」也可能缺 blob，历史重建需要网络。

### 4.2 实际后果（本项目已实测过，非推测）

- `git -C build/m3v2-7.3rc7 rev-list --count vk184` → **3**（`79a907609d`→`88cd0bc0f4`→`4da9a8b69f`）；
  `rev-list --count wl8board` → **也不是完史**；`rev-list --count v7.3.1` → **1**（单提交 graft 边界）。
  即「上游历史」在这里是**按需拉取的碎片**，而非完整图。
- `git -C geekidos-linux log --oneline -15` 只输出 **1 条**（HEAD `ba28ec16f01`）——历史在 graft 处即断。
- 仓库内已沉淀的失败记录（本次只读引用）：
  - `AGENTS.md:48`：「内核仓 geekidos-linux 是浅克隆：`git fetch`/bundle 一律被拒 → 从本地 worktree `git fetch <wt> refs/heads/...`」；
  - `.pi/memory/failures-kernel.md:655/659/661`：「`fatal: Not a valid object name <sha>^{commit}`」、「拒绝 refs/tags/vkNN 因为浅克隆的根不允许被更新」（rc=128）；
  - `.pi/memory/MEMORY.md:51/59`：可从本地 worktree fetch 成功（2026-10-17 实测），取旧 tag 树用 `git worktree add build/<tag>-tree <tag>`。
- **bundle 兜底不可用（新发现）**：唯一 bundle 是 `backup/git-history-rewrite-20261103/pre-rewrite-all.bundle`（280 MB，`find . -name '*.bundle'`），
  但它**在 `build/m3v2-7.3rc7` 仓库内不可读**：`git -C build/m3v2-7.3rc7 bundle list-heads backup/...bundle` →
  `error: could not open 'backup/git-history-rewrite-20261103/pre-rewrite-all.bundle'`（0 heads）。
  它相对仓库根存在，但不在该 git 仓库视角可寻址的路径上 ⇒ **「有 bundle」不等于「可恢复」**。
- 另一重风险：本报告 2.1 已证 `vk` 号在对象库里**只剩 tag、branch 已丢**；浅克隆 + 只剩 tag + 无可用 bundle = 一旦误删 tag 就不可再生。

### 4.3 引用覆盖统计（哪些分支没被 vk 号引用）

- 版本账 `versions/vk-kernel-identity.tsv` 共 **134 条数据行**；`src_ref` 去前缀去重后 **38 个 ref 名**。
- `build/m3v2-7.3rc7` 本地 heads = **40**；**未被任何 vk 号引用的 40 个 head 中占大多数**（`comm -13` 实得全部 40 个，即
  `src_ref` 里的名字大量写成了 `reb731/xxx` 形式 —— 这些名字**属于 `geekidos-linux` 的远程跟踪 ref**
  （`git -C geekidos-linux for-each-ref | grep -c '^reb731/'` = **49**），在 `build/m3v2-7.3rc7` 里查不到）。
  ⇒ **版本账的 `src_ref` 混写了两套仓库的 ref 命名空间**，跨仓对账必然错报「ref 不存在」。
  - 量化：`src_ref` 含 `reb731/` 前缀的行 = **66** 行，不含且非空的行 = **17** 行（共 134 数据行，`awk -F'\t'` 统计）。
    ⇒ 台账里**约一半的行指向的是另一套仓库的命名空间**。
- 典型无 vk 引用的分支（本地 head，`comm -13` 输出摘录）：`m3v2`、`m3v4`、`m3v6`、`m3v7`、`m4/send-20261028`、`m4/v3-broken-1793242637`、
  `m4/v3-keep-1793243164`、`draft/m4-split`、`backup/m4-draft-20261027`、`replay/m4-20261028`、`wl7b`、`wl8board`、`verify/lore-mbox`、
  以及 `tidy-20261105/*` 下 9 个、`wl2868c-*` 系列 6 个、`aw*` 3 个、`b5/*` 3 个。
- 另有 **`snap-20261110-*` 11 个快照 tag**（`git tag -l 'snap-*' | wc -l` = 11），全部不被 vk 号引用，属 2026-11-10 的临时防丢快照。

## 5. 建议合并/清理顺序（≤3 步）

> 均只含判据，不含破坏性命令；执行需单独授权。

**步骤 1｜台账与 ref 命名空间对齐（无风险，先做）**
- 动作：把 `versions/vk-kernel-identity.tsv` 的 `src_ref` 按其对象库归属分成两种写法——本地 head（`build/m3v2-7.3rc7`）直写名，
  远端跟踪（`geekidos-linux`）统一加 `geekidos:` 前缀；并修正 `vk184/vk185/vk187` 三行 `branch:` 实为 `tag:`（见 2.1）。
- 判据：`git -C build/m3v2-7.3rc7 for-each-ref --format='%(refname:short)'` 与 `git -C geekidos-linux for-each-ref` 两侧对 `src_ref` 的解析**零缺失**；
  且 `scripts/check-doctor.sh` §5d FAIL=0/WARN=0（注意：**禁重跑 `scripts/vk-identity.py`**，见 `AGENTS.md`「项目记忆」第一条）。

**步骤 2｜先备份可恢复性，再做去重（不可逆前的唯一门槛）**
- 动作：`git bundle create` 在 **`build/m3v2-7.3rc7` 内部**生成一份包含全部heads+tags 的 bundle（当前唯一 bundle 不可读，见 4.2），
  记录校验：`git -C build/m3v2-7.3rc7 bundle verify <file>` 通过且 `bundle list-heads` 条数 = `for-each-ref | wc -l`（当前 79）。
- 判据：`bundle list-heads` 非 0 且 `bundle verify` 返回 0；否则不得进入步骤 3。

**步骤 3｜只删/归档已证同树的重复 ref，不同功能内容**
- 动作：删除**同 tree** 的重复版本号引用（`vk187`/`vk187b` 与 `vk184` tree 完全相同 `64704fd63e2e`，见 2.1）；
  对 `snap-20261110-*` 11 个快照 tag 先合入步骤 2 的 bundle 再统一清。
- 判据：删前 `git rev-parse <ref>^{tree}` 与保留目标的 tree 相等；删后 `git -C build/m3v2-7.3rc7 fsck --no-dangling` 无 missing
  且 `git bundle list-heads` 中仍能解出该 tree（即删除不降低可恢复性）。
- **不做**：`vk184` 与 `wl8board` 一类「无共同祖先」（4.2/3.1）的树**不纳入合并**——它们不存在渐进差分，强行 merge 等于造第二条完整历史。

## 6. 未完成项

1. **未逐条 diff 验证** `m4/v3-20261029..draft/m4-split` 与 `m4/v3-20261029..m4/send-20261028` 的 3 文件 +9/−57 是否完全等价（只看了 `--stat`）。
2. **未扫描全部 134 行**的 `tree_head` 重复聚类（只做了任务指定的 vk184/185/187/187b 四行 + 全表 dirty 分布）；
   完整「镜像重复」名单需另跑一次 `cut -f10 | sort | uniq -c` 并交叉 image sha。
3. **未验证** `backup/git-history-rewrite-20261103/pre-rewrite-all.bundle` 的 280 MB 内容能否用绝对路径或独立克隆 verify
   （本次只证实「在 build/m3v2-7.3rc7 视角不可读」）。
4. `geekidos-linux` 的 18 条 shallow 边界与 `build/m3v2-7.3rc7` 的 439 条边界**未逐一对应**到 tag/分支，因此「某 vk 的源提交目前在哪一侧仍可达」未逐号核实。
5. `snap-20261110-*` 11 个快照 tag 各自指向的 sha 与是否已被 vk 覆盖**未逐对比较**。

## 结论

1. **主结构**：`wt/reb-731` **不是** `geekidos-linux` 的 worktree，而是 `build/m3v2-7.3rc7` 的第三个 worktree（`git-common-dir` 实测），
   detached 于 `ec74c4795a` = tag `vk185`。两棵树**无共享对象**。→ 不存在「两棵树合并」这个命题，只有「两套仓库各自收敛」。
2. **重复**：`vk184` / `vk187` / `vk187b` 三者 tree 完全相同（`64704fd63e2e`），`git diff --stat vk184..vk187` 为空；
   唯一真实功能增量是 `vk184..vk185` 的 1 文件 +1 行（`sm8750.dtsi` 加 `qcom,non-secure-domain`）。
3. **台账漂移（最高优先级）**：`src_ref` 写 `branch:vk184,vk185`，但对象库里 `vk184/vk185/vk187` **只有 tag 无 branch**；
   且 134 数据行里 66 行用 `reb731/` 前缀（属 `geekidos-linux` 的远端命名空间），跨仓解析必然误报缺失。
4. **可恢复性比合并更紧急**：两库皆 shallow（439 / 18 条 graft）且 `build/m3v2-7.3rc7` 是 `blob:none` partial clone；
   唯一 280 MB bundle 在仓库视角**打不开**（`bundle list-heads` 报 could not open）⇒ 当前**没有已验证的灾备**。
5. **行动顺序**：①对齐 src_ref 命名空间并改 `branch:`→`tag:`（判据 = 两库零缺失 + check-doctor 5d 绿，禁重跑 vk-identity.py）；
   ②在 `build/m3v2-7.3rc7` 内新建并 `bundle verify` 通过的全量 bundle（79 refs，判据 = list-heads 非 0）；
   ③只删/归档已证同 tree 的重复 ref（判据 = `rev-parse <ref>^{tree}` 相等 + 删后 bundle 仍可解）。
   `vk184 ↔ wl8board` 这类无共同祖先的组合**明确排除**在合并清单外。
