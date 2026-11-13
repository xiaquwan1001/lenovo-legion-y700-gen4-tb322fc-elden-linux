# Git 树整合审计（嵌套仓 / 被跟踪大件 / 垃圾面）— 2026-11-13

> 审计者：代码边界检查 Lead（y700-elden，一级）。**只读**：本篇是唯一产物，未执行任何 `git` 写操作、
> 未删任何文件、未动分支/tag/worktree/历史。所有数字 = 2026-11-13 现查，每条给复现命令。
> 复现口径：字节一律 `stat -c %s`（表观字节，非 du 的块占用）；packed 字节 = `git verify-pack -v` 第 4 列。
>
> **分工（不重复劳动）**：
> ① 主仓**分支/tag 收束已执行并记账** → `reports/git-tidy-20261113.md`（13 条 `tablet/night-*` + 4 条已合并分支已删，
> 远端只剩 `main` + `history/pre-vk34`；两个 `attic/*` tag 只在 USTC、GitHub hook 拒收）——**本篇不重复审这部分**，
> 只在 §2 末尾引用它作为「旧历史对象已被 tag 固化 + 双远端已核对」的前置判据。
> ② 文档/脚本体量与孤儿报告 → `reports/repo-slim-audit-20261113.md`（其 §5/§7 覆盖 reports 的 md 分布与下沉）。
> **本篇增量 = 对象层（pack/reflog/repack）+ 48 个嵌套仓 + 被跟踪二进制大件 + 垃圾面 + 「打 tag 后删分支」保留集**。

---

## 0. 结论先行

**一句话**：**主仓 git 树不需要整合（487 MB 里有 38% 是被 4 条旧历史引用钉住的、且已 tag 固化），真正的失控面在嵌套仓与被跟踪二进制大件**——
`geekidos-linux/`（=`linux/`）1.9 GiB 对象库里只有 **13% 的对象可达**，`build/m3v2-7.3rc7/` 只有 **42% 可达**；
被跟踪的 932 MiB 里 **93.4% 是 `reports/artifacts/` 的构建产物**（.bin/.img/.fd/build.log），
而 `.gitignore` 已写了 6 条同类排除规则却漏了 `build.log` / `*.fd` / `uefi-boot-*/img` 这三类。

| # | 关键数字 | 现查命令 |
|---|---|---|
| 1 | 主仓 `git branch -a` = **7 行**（1 本地 `main` + 4 真实远端跟踪 + 2 `HEAD` 符号）；tag **65**；worktree **1** | `git branch -a \| wc -l`；`git tag \| wc -l`；`git worktree list` |
| 2 | 主仓 `.git` **525 MB**（objects 524 MB）；松散 559 个 9.13 MiB + **1 pack 513.57 MiB**；in-pack 19 111；garbage **0** | `du -sh .git`；`git count-objects -vH` |
| 3 | 主仓 packed blob 合计 **511.56 MiB**；HEAD 可达 **10 088 blob / 317.20 MiB**；**不在 HEAD 的 22 blob / 194.36 MiB = 38%** | §2.2 |
| 4 | 最大 packed blob：**114.12 MiB**（`reports/trials/20261024T021942Z-q32c1-r1/serial-delta.log`，表观 **2 812 MiB**）；第二 **79.90 MiB**（`uefi-posctrl-20261103/boot_b-live.img`，表观 96 MiB） | §2.1 |
| 5 | 被跟踪：**6 525 路径 / 932.14 MiB**；`reports/` = **3 235 / 897.14 MiB（96.2%）**；其中 `reports/artifacts/` **2 081 / 870.32 MiB（93.4%）** | `git ls-files -z \| xargs -0 stat -c '%s'` |
| 6 | ≥1 MiB 的**被跟踪**文件 **279 个 = 829.63 MiB**；≥4 MiB **98 个** | 同上 |
| 7 | 磁盘总量 **91 GiB**；`git ls-files` 纳管部分只占 0.93 GiB ⇒ **98.9% 的磁盘在 ignore 层/嵌套仓** | `du -sh .` |
| 8 | 嵌套仓：**48 个** `.git`（depth ≤6）；`linux` 是 **symlink → geekidos-linux** | `find . -maxdepth 6 -name .git \| wc -l` |
| 9 | `geekidos-linux/.git` **1.9 GiB / 8 packs / 1 094 657 对象**，`--all` 可达仅 **146 712（13.4%）**；浅克隆 | §3.1 |
| 10 | `build/m3v2-7.3rc7/.git` **1.6 GiB / 13 packs / 1 130 493 对象**，`--all` 可达 **476 514（42.2%）**；浅克隆 + `blob:none` 部分克隆 | §3.2 |
| 11 | 垃圾面：`git ls-files` 里 `*.bak*` **2** 个（0.02 MiB）、`*~`/`*.orig`/`*.rej`/`*.swp`/`*.tmp` **各 0**；`.pi/trash` **不存在**；磁盘上 `.bak-*` **29 个 / 85 172 B**（`.pi/agents/*.bak-alias-1112` 实测 **24** 个，派工单记的 22 少 2） | §4 |
| 12 | 门禁基线：`scripts/check-doctor.sh` → **FAIL=0 WARN=5**（5 条全部为既有项，与 git 树无关） | `scripts/check-doctor.sh \| tail -1` |

### 0.1 前 3 个最大可回收体量（本篇口径）

| 名次 | 项 | 可回收 | 依据 |
|---|---|---|---|
| **1** | `geekidos-linux/.git` repack（可达对象只占 13.4%，5 个 ~283–287 MB 的重复上游 pack） | **≈1.4–1.5 GiB** | §3.1 A-1 |
| **2** | `build/daily` + `wt/reb-731` 两个 linked worktree 的**构建输出树**（12.38 + 12.22 GiB，`.git` 只有 4 KB，全是 `.o`/镜像） | **≈24 GiB**（但有 19 个未提交文件挡路，见 A-8） | §3.2 |
| **3** | `build/m3v2-7.3rc7/.git` repack（13 pack → 1） | **≈1.0–1.1 GiB** | §3.2 A-2 |

> 紧随其后：`build/uefi-woa-prep/` 8.2 GiB（7 个可重取 EDK2 克隆，A-6）、
> `reports/artifacts/` 被跟踪大件 **870 MiB**（A-9，唯一会「改主仓工作树」的一项）、
> 主仓旧历史引用 **194.36 MiB**（A-3）。

---

## 1. 主仓：纳管内容 vs ignore 层

```
91 GiB 全仓磁盘 = 0.93 GiB 纳管 + 90 GiB ignore/嵌套
du -B1 --max-depth=1 .（GiB，前 12）：
 29.65 backup   28.96 build   12.52 wt    5.90 out     3.65 geekidos-linux  2.53 dl-cam
  2.09 stock-src 1.89 external 1.78 reports 1.48 bootslot-b 0.79 .pi  0.51 .git
```

**结论**：主仓 `.git`（525 MB）不是磁盘问题；`.pi/` 磁盘 805 MiB 里 **`.pi/sessions` 独占 804 MiB 且已 ignore**（`/.pi/sessions/`）。
`check-doctor §14` 实测顶层 46 条目全部登记在案，`INDEX.md` 三向一致（`reports/repo-slim-audit-20261113.md` §4.1 已算）。

## 2. 主仓对象层账（只算「什么钉住了什么」，不含分支裁决）

### 2.1 最大 10 个 blob（`git rev-list --objects --all | git cat-file --batch-check`，表观字节）

| 表观 MiB | packed MiB | 路径 | 是否仍在 HEAD |
|---|---|---|---|
| 2 812.03 | **114.12** | `reports/trials/20261024T021942Z-q32c1-r1/serial-delta.log` | **否** |
| 96.00 | **79.90** | `reports/artifacts/uefi-posctrl-20261103/boot_b-live.img` | **否** |
| 8.00 ×8 | **≈0** | `reports/artifacts/uefi-boot-2026110{1,3}/logfs.img`、`uefi-p6{1,3}-flash-20261109/logfs-*.bin`、`uefi-ddrcut-20261101/logfs-*.bin`、`uefi-slotboot-20261101/logfs-{before,after}.bin` | 是 |

**判据**：8 MiB 那一族 packed 后≈0（全零填充镜像，deflate 吃掉），**删它们不会回收对象库**，只会让工作树好看；
真正吃对象库的是那两个（**194.02 MiB，占 packed blob 的 37.9%**）。

### 2.2 谁钉住了那 194.36 MiB（逐 blob 实测，非推测）

| 引用 | 是否含 serial-delta | 是否含 boot_b-live.img | 备注 |
|---|---|---|---|
| `HEAD`(main) | 否 | 否 | 6 525 路径，1 181 commits |
| `refs/original/refs/heads/main`（1 143 commits，`filter-branch` 残留） | 否 | **是** | tip `18e6b78c` = **`backup/git-history-rewrite-20261112/pre-rewrite-main-2.bundle` 记录的 tip**（`git bundle verify` 通过、完整历史） |
| `refs/tags/attic/tablet-night-20261031` | **是** | 否 | 已在 **USTC** 远端（`git ls-remote origin 'refs/tags/attic/*'` 有）；GitHub 侧无（`git-tidy` 记 hook 拒收） |
| `refs/tags/attic/lane-upstream-20261012` | 否 | 否 | 同上，已在 USTC |
| `refs/remotes/{github,origin}/history/pre-vk34`（同一 SHA `76b2c0fa`，49 commits） | 否 | 否 | 历史锚点，`git-tidy` 已裁「保留」 |

其余账：`--all` 可达 commits **1 513** vs `HEAD` **1 181**（差 332 个旧提交）；reflog **571** 条；`FETCH_HEAD` 2026-11-13 15:55；
双远端 `refs/heads/main` 均 = 本地 HEAD `79e969d7`（`git ls-remote` 实测，代理已绕：`env -u *_proxy git -c http.proxy= ls-remote`）。

> **引用一句 `git-tidy`**：分支收束与 `attic/*` 固化已由它做完并核过双远端，故 A-3 只是「对象层收尾」，不是重新裁决。

## 3. ① 嵌套仓（48 个 `.git`，主仓一律 ignore，无一被跟踪为 gitlink）

`find . -maxdepth 6 -name .git | wc -l` = **48**；`git ls-files | grep -c '^160000'` 形态的 submodule 条目 **0**（无 `.gitmodules`）。
逐个 `git check-ignore`：**全部 = IGNORED**（`/geekidos-linux/` `/build/` `/wt/` `/external/` `/stock-src/` `/dl-cam/aosp/` …）。

### 3.1 `linux/` → `geekidos-linux/`（用户口径里的「70 个分支」）

| 项 | 实测 | 说明 |
|---|---|---|
| `linux` | **symlink → geekidos-linux**（`ls -ld linux`） | 「linux 仓」= 这个仓 |
| `git branch -a \| wc -l` | **70** | = 16 heads + 53 remote-tracking + **1 行 detached-HEAD 占位** |
| heads（`for-each-ref refs/heads`） | **16** | `git branch \| wc -l` 给 17 是因为 detached 占位行 |
| remote-tracking | **53** = `reb731/*` **49** + `gitlab/*` 3 + `origin/v7.2-elden` 1 | **`reb731` 未在 `remote.*` 配置里 ⇒ 49 条全是孤儿 remote-tracking**（`git config --get-regexp '^remote\.'` 只有 gitlab/origin） |
| tags | **70** = `v*` 18（上游）+ 本地 52：`vk40…vk83` 16、`bundle/*` 20、`archive/*` 4、`snap-20261110-*` 4、`vk127 vk163-modular vk172 vk173 vk184 vk185` 6、`elden-payload-v2 upstream-v7.3.1` 2 | 与 `reports/vk-git-branching-20261110.md` 的 tag 策略一致 |
| `.git` | **1.9 GiB**，8 pack（**5 个 265–287 MiB** + 1 个 167 MiB + 2 小）；1 094 657 in-pack；`prune-packable: 19` | 5 个近似同尺寸 pack = 同一份上游历史被多次 fetch、各自独立 delta |
| **可达性** | `git rev-list --objects --all \| wc -l` = **146 712**；`--reflog` = 119 371 | ⇒ **≈95 万对象（86.7%）不可达**，只被历史 pack 拖着 |
| 浅克隆 | **是**（`.git/shallow` 存在） | 与项目记忆「geekidos-linux 浅克隆」一致 |
| 工作树 | HEAD detached `ba28ec16f01`(2026-09-14)，`status` **干净** | 相对 `m3v2-7.3rc7`(2026-11-07) **落后 2 个月** |
| GitLab 镜像 | `git ls-remote --heads gitlab` = **2 条**（`main`、`elden-archive/archive/gitlab-mirror-vk48`），都在 `fe54fcff`（2026-10-04） | **镜像陈旧 40 天** ⇒ 16 条本地 head 里 **14 条异地无副本** |

**三分类与保留集（判据 = ①tip 是否已有同 SHA tag ②是否被别的 ref 包含 ③是否已推镜像）**

- **A 上游跟踪（永久保留，6 refs）**：`refs/remotes/origin/v7.2-elden`、18 个 `v*` tag、`upstream-v7.3.1`、`v7.2-elden` 系列 tag。
- **B 已并入主线快照（已 tag ⇒ 分支可删，5 heads）**：
  `replay/m1-73-vk127`（tip `24223e44` 已有 **4 个同名 SHA tag**：`vk127`/`vk163-modular`/`vk172`/`vk173` ⇒ 分支纯冗余）；
  `elden-archive/elden/vk42-audio-thermal`（`merge-base --is-ancestor` 判为 **`bundle/vk48` 的祖先**）；
  `elden-archive/elden/vk54-kexec-va52`（**`bundle/vk54` 的祖先**）；
  `elden-archive/archive/gitlab-mirror-vk48`（= GitLab `main` tip，异地有副本）；
  `elden-archive/v7.2-elden`（2026-10-08 主线快照，`snap-20261110-v7.2-elden` tag 已在库中，需先核对 tag==tip 后动）。
  复现：`join /tmp/gk_tags.txt /tmp/gk_heads.txt`（SHA 等值 join）+ `git merge-base --is-ancestor <tip> <tag>`。
- **C 一次性实验（11 heads，`git-tidy` 式「先补 tag 再删」）**：
  `elden-archive/sd-{n2fix,noGC,noN2,noN2N3,noN3}`（5 条调度器 A/B，同日 2026-10-06，结论已进 `PITFALLS`/`reports/`）、
  `elden-archive/wifibmiss-v1v2`、`elden-archive/wifitim`、`elden-archive/q28/vk86`、
  `elden-archive/elden/v1-thermal-only`、`elden-archive/elden/v2-audio-only`、`elden-archive/elden/vk53-hw`。
  **注意**：这 11 条 tip 目前 **既无同 SHA tag、也不被任何 ref 包含** ⇒ 直接删 = 依赖 reflog 90 天；必须先按 `snap-20261110-*` 的做法补 tag 或直接 bundle。
- **孤儿 remote-tracking**：49 条 `refs/remotes/reb731/*`（含 `reb731/tidy-20261105/*` 18 条、`reb731/wl*` 5 条）——**remote 已不存在**，
  属认知噪声而非体量（其对象与 `m3v2` 的 fetch 重叠）；`git remote remove` 后需手工 `git update-ref -d`（`--prune` 不认无名 remote）。

### 3.2 `build/m3v2-7.3rc7/`（现役内核实线 lane）+ 它的 3 个 worktree

| 项 | 实测 |
|---|---|
| 磁盘 / `.git` | 5.2 GiB 树 / **1.6 GiB `.git`**（13 pack：**5 个 283–324 MiB** + 8 小），1 130 493 in-pack 对象 |
| 克隆形态 | **shallow = YES** 且 `blob:none` 部分克隆（`remote.{origin,next,torvalds}.promisor=true`） |
| 可达性 | `rev-list --objects --all` = **476 514（42.2%）**；`--reflog` = 466 473；reflog 80 条 |
| refs | heads **40**、tags **36**（12 个 `v7.2*/v7.3*/v7.4-rc1` 上游 + 16 `snap-20261110-*` + `vk184 vk185 vk187` + `elden-payload{,-v2}` + `next-20261028` + `v72-base` + `camss/drop-contiguous-20261113`）、remote-tracking 4 |
| worktrees | `git worktree list` = 本体(`wl8board`) + `build/daily`(detached `4da9a8b6`) + `wt/reb-731`(detached `ec74c479`) |
| **未提交面** | 本体 **9 个脏文件**（`sm8750.dtsi`、`gcc-sm8750.c`、`phy-qcom-qmp-combo.c`、`llcc-qcom.c`、`tsens.c`、`dwc3/*` ×4 + 未跟踪 `include/linux/phy/phy-qcom-qmp-usb-ss.h`）；`build/daily` **19 个脏文件**；`wt/reb-731` 干净 |
| worktree HEAD 是否安全 | **提交安全**（`4da9a8b6` ∈ tag `vk184 vk185 vk187 camss/drop-contiguous-20261113`；`ec74c479` ∈ tag `vk185`），**但 `build/daily` 的 19 个未提交改动没有任何异地副本** |
| 两棵工作树体量 | `build/daily` 12.38 GiB（`drivers` 6.36）、`wt/reb-731` 12.22 GiB（`drivers` 6.32）——**几乎全是 `.o`/中间件**，`.git` 只是 4 KB 的 gitdir 文件 |

**40 heads 三分类**

- **保留（lane 主线，5）**：`m3v2 m3v4 m3v6 m3v7`、`wl8board`（当前检出 = 最新板级 DT）。
- **保留（上游送审系列，20，合并前不动）**：`wl2868c-drv-series{,-v2}`、`wl2868c-{v4,v5,v6}`、`wl7 wl7b wl7board`、
  `aw86927-upstream-series aw-v2 aw-v2-fix`、`b5/send-20261028 b5/v2-20261102 b5/v2-fixed`、
  `m4/send-20261028 m4/v3-20261029`、`m8/v3-20261102`、`elden/b5-send`、`m1-pas-dtbfw`、`fix/3a`。
- **可「打 tag 后删」（15）**：
  **同名 SHA 冗余 2**（`tidy-20261105/vk183-fastrpc`、`tidy-20261105/vk-camssv3` 与 `…/vk151` **三条指向同一 commit `509f271d523`**）；
  **名字即自证一次性 5**（`m4/v3-broken-1793242637`、`m4/v3-keep-1793243164`、`backup/m4-draft-20261027`、`draft/m4-split`、`verify/lore-mbox`）；
  **`tidy-20261105/*` 已进 11-05 归档账的 8**（`camss-icc-wt camss-v2-laneA-wt m4-camss-v2-pristine m3v5-fix m3v5-pristine q28-disp` 等）——
  依据 `backup/build-bundles/MANIFEST-20261105.tsv`：该表把 13 个 `build/*` 工作区逐条记 `head/branch_before/kept_ref/removed_at`，
  **这正是项目「先记 ref+bundle、后删工作区」的既有范式**，11-05 的 13 个工作区就是这么回收的。

### 3.3 `build/base-7.2/`（**禁删**，唯一基点载体）

`git`=569 MB、磁盘 2.4 GiB、**非浅克隆**、201 122 对象、2 heads、HEAD `378459aff` = *"elden payload v2: downstream vk64 tree state …"*；
`git tag --contains` 显示它也是 `tidy-20261105/q28-disp` 的 tip。
按技能 `kernel-downstream-replay`（「payload 基点对象丢失后的替代重建」）：**这是下游 payload 基点的现存唯一载体**，
本篇给的动作只有 **A-12 bundle 保护**，不给删除。

### 3.4 其余嵌套仓（体量降序）

| 路径 | 磁盘 | `.git` | 对象数 | 分支 | 主仓 ignore | 判定 |
|---|---|---|---|---|---|---|
| `build/uefi-woa-prep/repos/*`（7 仓：`7-mu-lenovo` 5.5 GiB、其内 `MU_BASECORE` 1.8 GiB、`1-edk2-aarch64-gunyah` 1.5 GiB、`4-qemu-for-gunyah`、`3-edk2-gunyah-qemu`、`6-DroidVM-Prebuilts`、`Binaries`） | **8.2 GiB** | 数 GiB | — | 多 | 是 | 上游 EDK2/MU 树，**可重取**；A-6 |
| `stock-src/android_kernel_lenovo_sm8750` | 1.5 GiB | 1.5 GiB | **7 299 386**（全仓最大对象库） | 1 | 是 | 原厂内核全历史；**非浅克隆**；A-7 |
| `stock-src/android_kernel_lenovo_sm8750-modules` | 527 MiB | 214 MiB | — | 1 | 是 | 同上伴生 |
| `external/ext-repos`（含 `sunuefi` 164 MiB，shallow） | 1.18 GiB | 89 MiB(sunuefi) | 1 650 | 1 | 是 | 同类芯片 UEFI 参照（G3/UEFI 面）；留 |
| `external/lc-cross/lc-src` | 449 MiB | 116 KiB | — | 0 | 是 | 交叉工具链源；可重取 |
| `external/{alpine-sysroot,mesa-out,phoc-work,aosp-vndk33}` | 93/39/36/73 MiB | — | — | 0–1 | 是 | 构建输入/输出；ignore 正确 |
| `dl-cam/aosp/*`（**12 个仓**）+ `dl-cam/libhidl` + `dl-cam/hw-interfaces` | 25/0.3/43 MiB | 0.2–18 MiB | — | 0–1 | 是 | AOSP 取件；配方在 `dl-cam/build-cam-provider.sh`（**该脚本本身已被 ignore，见 §4.3**） |
| `Y700-elden-linux/` | 27 MiB | 13 MiB | 210 | 1 | 是 | 社区移植参考，体量可忽略；留 |
| `build/{a2-ln,extmod/v4l2loopback*,droidloom,exp-cmdline,grub-arm64,phoc-src-0.58.0,gunyah-*}` | 0.4–164 MiB | 0.1–0.3 MiB | — | 0–1 | 是 | 小实验树；留（<0.2 GiB） |

## 4. ③ 垃圾面（全实测）

### 4.1 `git ls-files` 内（= 真污染仓库的部分）

| 模式 | 被跟踪数 | 字节 | 备注 |
|---|---|---|---|
| `*.bak*` | **2** | 0.02 MiB | `initramfs/init.bak-20260930`、`initramfs/init.bak-beforedbus-20260930` |
| `*~` / `*.orig` / `*.rej` / `*.swp` / `*.tmp` / `*.old` / `*.part` / `*.deb` / `*.whl` | **0** | 0 | 干净 |
| `*.log` | **448** | **152.54 MiB** | 纳管字节的 16.4%；其中 `reports/artifacts/*/build.log` **53 个 = 135.14 MiB** |
| `.pi/trash` | **0** | — | 目录**不存在**；`.git/info/exclude` 里有 `.pi/trash/` 规则（防污染，符合项目记忆） |

**tracked-but-ignored（规则与实际打架，11 个 / 5.05 MiB）**——这是**边界违例**，比垃圾更需要处理：

```
3.82 MiB  reports/trials/20261024T024942Z-q32c1-r2/serial-delta.log   ┐
0.25/0.24/0.24/0.24/0.23 MiB  reports/trials/20261024T02{0840,21127,21347,22134,5153}Z-*/serial-delta.log ┘ 规则 reports/trials/*/serial-delta.log 已在 .gitignore，但 6 个先入库者仍被跟踪
0.02 MiB  reports/artifacts/uefi-p46-boot-success/logfs-tail-16k.bin
0.01 MiB  dl-cam/build-cam-provider.sh    ┐
0.00 MiB  dl-cam/gen-headers.sh           ├ 4 个**自研脚本**被 `/dl-cam/*.sh|*.py|*.cpp` 规则盖住（= 2026-11-06 `tools/mkbootimg` 全丢的同类风险，见 .gitignore 注释）
0.00 MiB  dl-cam/brdot2img.py             │
0.00 MiB  dl-cam/external-fetch-shim.cpp  ┘
```

复现：`git ls-files -i -c --exclude-standard`

### 4.2 ignore 层残留（不进 status、不进库，仅磁盘）

`.pi/agents/*.bak-alias-1112` **24 个**（派工单记 22，实测 24）+ `.pi/{AGENT-OPS,ORCHESTRATION}.md.bak-alias-1112` + `.pi/fabric.json.bak-alias-1112` = **27 个**；
加 §4.1 的 2 个 `initramfs/*.bak-*` = **全仓 29 个 / 85 172 B**，与 `reports/repo-slim-audit-20261113.md` §3.4 的 29/85 172 一致（该条注明「`.gitignore:391` 记为用户要求保留」⇒ **本篇只登记，不建议删**）。
`logs/` 38 MiB 已 ignore；`.pi/sessions/` 804 MiB 已 ignore。

### 4.3 判据（三问门映射）

- 自研脚本 `dl-cam/{build-cam-provider.sh,gen-headers.sh,brdot2img.py,external-fetch-shim.cpp}` 属**②复用/③软件策略**类资产 ⇒ **该入库**，现被 ignore 规则覆盖 = **违例**（A-11）。
- `reports/trials/*/serial-delta.log` 属可再生大件 ⇒ **该走 ignore 层**，现被跟踪 = **违例**（A-10）。

## 5. ② 被跟踪大件逐目录判定

字节 = `git ls-files -z <dir> | xargs -0 stat -c %s`（表观）；磁盘 = `du -sh`。

| 目录 | 纳管文件 | 纳管字节 | 磁盘 | ignore | 类别 | **该留该走** |
|---|---|---|---|---|---|---|
| `reports/` | 3 235 | **897.14 MiB** | 1.78 GiB | 部分 | 混合 | **部分下沉**（§5.1） |
| `reports/artifacts/` | 2 081 | **870.32 MiB** | (含上) | 部分 | **构建产物** | **该走 ignore/归档层**（A-9） |
| `reports/trials/` | 623 | 21.19 MiB | (含上) | 部分 | 机器可读记录 + 串口件 | 留 `*.tsv/README`；6 个 delta 走 A-10 |
| `patches/` | 831 | 8.60 MiB | 11 MiB | 是(`*.bak`) | **补丁 SSOT** | **全留**（upstream 309 / uefi 222 / kernel-history 151 / local 19 / …） |
| `scripts/` | 273 | 1.26 MiB | 2.0 MiB | 否 | 工具 | **全留** |
| `TASKS/` `PITFALLS/` `SESSIONS/` `HISTORY/` `archive/` `.pi/` `versions/` `rootfs/` `tools/` `probes/` | 1 505 | 10.16 MiB | ~13 MiB | 部分 | 文本 | 留（体量维度见 `repo-slim` §5） |
| `dl-cam/` | 231 | 6.15 MiB | **2.53 GiB** | 大部分 | 混合（libcxx 185 + gen-src 40 + 6 散件） | 留纳管文本；磁盘层重取（配方脚本先按 A-11 救回） |
| `reference/` | 225 | 5.37 MiB | 6.08 MiB | 部分 | **同类芯片/上游参照源码切片** | **全留**（体量小、上游取件成本高；gunyah-refs 已只留源码切片） |
| `packaging/` | 159 | 0.37 MiB | 0.9 MiB | 否 | 配方 | 留 |
| `backup/` | **18** | 0.53 MiB | **29.65 GiB** | 大部分 | 混合 | **18 个文本账留**（getvar/GPT/pre-unlock/SHA256SUMS），29 GiB 二进制留 ignore 层 |
| `out/` | **228** | 0.49 MiB | **5.79 GiB** | 是(`/out/*` + `!/out/*.manifest`) | **镜像台账** | **纳管侧 = 228 个 `*.manifest`，一字不删**（可复现指纹）；**5.79 GiB 镜像只能走 `scripts/out-archive.py`**（默认 dry-run；**禁重跑 `scripts/vk-identity.py`**，镜像缺失会清空整表） |
| `build/` | **0** | 0 | **28.96 GiB** | **是** | **构建产物** | 磁盘层处置；**删前必须 bundle**（项目铁律）；`build/base-7.2` 例外 ⇒ 禁删 |
| `wt/` | 0 | 0 | 12.52 GiB | 是 | worktree 树 | 同 `build/` |
| `stock-src/` | 0 | 0 | 2.09 GiB | 是 | **上游/原厂 clone** | 可重取（A-7） |
| `external/` | 0 | 0 | 1.89 GiB | 是 | clone/取件 | 留（UEFI 参照），只清 `external/{mesa-out,phoc-work}` 类输出 |
| `logs/` `.pi/sessions/` `.cache/` | 0 | 0 | 38 MiB / 804 MiB / 小 | 是 | 运行时 | 留 ignore 层 |

### 5.1 `reports/artifacts/` 870.32 MiB 的成分（这是主仓唯一真正该动的面）

| 扩展 | MiB | 文件 | `.gitignore` 现状 |
|---|---|---|---|
| `.bin` | **267.05** | 227 | 仅挡了 `uefi-edl-read-20261101/*.bin`、`uefi-dxe*-*/…` 少数 |
| `.img` | **193.31** | 85 | 仅挡了 `uefi-ddr*-20261101/*.img`、`uefi-dxe*-*/…img` ⇒ **`uefi-boot-*/`、`uefi-slotboot-*/`、`uefi-posctrl-*/` 漏网** |
| `.fd` | **180.00** | 45 | 仅挡 `uefi-dxe*-20261104/*.fd` ⇒ **其余 37 个（148 MiB）漏网** |
| `.log` | **143.55** | 394 | **`build.log` 完全无规则**（53 个 = 135.14 MiB，单文件最大 4.88 MiB） |
| `.gz` | 72.17 | 32 | 仅挡 `uefi-dxe*-*/*.gz` |
| `.txt` | 7.95 | 1 037 | 留（manifest/SHA256SUMS 身份三件） |
| 其余(png/json/dtb/zst/efi/tsv/…) | 6.29 | ~250 | 留 |

**同尺寸模板证据**：50 个 `uefi-*` 目录 >1 MiB，合计 **842.6 MiB**；其中 R61–R74 系列 15 个目录**每个 22–24.5 MiB / 11 文件、结构同构**
（`build.log` + `.fd` + `payload*` + `SHA256SUMS` + `manifest.txt`）。`.gitignore` 已确立「**每变体只入库身份三件**」口径（2026-11-04 注释、2026-11-06 R8/R9 注释），
**本篇判据 = 把该口径补齐成通用规则，而不是另立标准**（三问门①：必须用主线子系统已有的框架/口径）。

## 6. 整合动作清单（**全部未执行**；按收益/风险排序）

> 通用作废项：**任何「历史重写」本篇一律不建议**；唯一允许的历史层动作是 A-3（删**旧引用**，非重写），
> 且其前置判据 = ①`git bundle verify` 通过 ②目标 ref 在**至少一个远端**有副本 ③`git ls-remote` 实测过。

| ID | 动作 | 影响体量 | 可逆性 | 执行前置条件 |
|---|---|---|---|---|
| **A-1** | `geekidos-linux`：`git reflog expire --expire=now --all && git gc --prune=now`（8 pack→1，可达对象仅 13.4%） | **≈1.4–1.5 GiB** | **半可逆**：引用/分支/tag 一律不动；**代价 = 丢 reflog 兜底**（119 371 个仅 reflog 可达对象） | ①先 `git bundle create backup/kernel-geekidos-refs-<d>.bundle --all`（**含 70 tags**）并 `bundle verify`；②确认 `git gc` 不动 `shallow` 文件；③不在编译高峰期（`make -j26` 约定同理，用 `nice`） |
| **A-2** | `build/m3v2-7.3rc7`：同上 `gc`（13 pack→1） | **≈1.0–1.1 GiB** | 半可逆（同上） | ①`bundle --all`（40 heads+36 tags）；②**部分克隆注意**：`blob:none`+promisor 下 `gc` 可能触发按需取件，须联网且**先 `git -c gc.auto=0` 手工分批**；③本体 9 个脏文件**先 stash/commit**；④`build/daily` 19 个脏文件**先处置**（否则 gc 后无法靠 reflog 找回） |
| **A-3** | 主仓删**旧历史引用**：`git update-ref -d refs/original/refs/heads/main`（**`filter-branch` 残留，属垃圾**）+ `gc --prune=now`；`attic/*` **保留** | **≈114 MiB**（boot_b-live 侧 79.9 + 旧提交/tree）；若连 `attic/*` 一起删则 **194.36 MiB** | 可逆：`refs/original` 的 tip `18e6b78c` **= 已 verify 的 `backup/git-history-rewrite-20261112/pre-rewrite-main-2.bundle`**；`attic/*` 在 USTC 有副本 ⇒ **建议只删 `refs/original`** | ①`git bundle verify` 已过（本篇实测）；②双远端 `main` 已实测 = HEAD；③GitHub 无 `attic/*` ⇒ 若要连 tag 一起清，先按 `git-tidy` 记的网页/PAT 路径补归档（**agent 不代填凭据**） |
| **A-4** | `geekidos-linux`：删 49 条**孤儿** `refs/remotes/reb731/*`（remote 未配置） | 对象≈0，**认知噪声 −49 refs** | 完全可逆（可从 `m3v2` 重 fetch） | 先 `git config --get-regexp '^remote\.'` 复核无名 ⇒ 用 `git update-ref -d` 逐条 |
| **A-5** | `geekidos-linux`：按 §3.1 三分类收 branch——B 组 5 条**先核对 tag==tip** 再 `branch -d`；C 组 11 条**先补 tag**（照 `snap-20261110-*` 命名）**或 bundle** | tag+branch 层，对象≈0（其对象已被 tag/主线共享） | 可逆（tag 在，commit 不会掉；`git branch <n> <tag>` 即复原） | ①先补 GitLab 镜像（现仅 2 条、tip 停在 `fe54fcff`/2026-10-04）⇒ **异地有副本才动手**；②C 组逐条写「结论落在哪个 report/PITFALLS」再删，防「实验账随分支沉底」 |
| **A-6** | `build/uefi-woa-prep/repos/*`（8.2 GiB，7 个 EDK2/MU 上游树）：整目录 `tar.zst` 或直接**只留 clone 脚本 + `HEAD` SHA 清单** | **≈8.0 GiB** | 可逆（上游可重 clone，前提是记下 SHA/remote） | ①逐仓 `git rev-parse HEAD` + `git remote -v` 落 `versions/` 台账；②确认 `TASKS §4/§5` UEFI 线不依赖其工作区状态；③**属 `build/*` ⇒ 走「删前 bundle」铁律** |
| **A-7** | `stock-src/android_kernel_lenovo_sm8750`（7.3 M 对象）：改 `--filter=blob:none` 或转 `archive --format=tar.gz` + 只留 DT/driver 切片 | **≈1.0–1.5 GiB** | 半可逆（原厂源可重取，但**取件成本高、且无稳定上游** ⇒ 建议**归档不删**） | ①先确认 `patches/kernel-history/`(151) + `patches/uefi/`(222) 已覆盖其全部在用 diff；②归档落 `backup/` 并写 SHA |
| **A-8** | `build/daily`、`wt/reb-731` 两棵 worktree：**只清构建输出**（`make O=… clean` / 删 `.o`），**不删 worktree 本体** | **≈20–23 GiB**（磁盘面最大项） | 完全可逆（重建即可） | ①`build/daily` **19 个未提交文件必须先 commit/tag/stash**（HEAD 提交本身已被 tag `vk184/185/187` 保住）；②`wt/reb-731` 干净可直接清；③`git worktree list` 三条必须仍在；④**属 `build/*` ⇒ bundle 铁律适用于 git 侧，不适用 `.o`** |
| **A-9** | `reports/artifacts/`：按 §5.1 补 `.gitignore` 通用规则（`reports/artifacts/*/build.log`、`*.fd`、`uefi-*/{*.img,*.gz,*.bin}`），把重件 `git rm --cached` + `git mv` 到 `archive/` 或直接移出仓库（保留 `README.md`/`manifest.txt`/`SHA256SUMS`） | 工作树 **−842.6 MiB**；对象层只有再走一次 gc 才体现 | **可逆**（`archive/` 搬迁 + `mv` 回来即复原；不改历史） | ①**逐目录先查引用**：本篇用 `grep -rl 'artifacts/<dir>' --include='*.md'` 得 **203/345 目录无 md 直接路径引用（361.8 MiB）**——此口径**偏保守**（间接引用/表格缩写未计），**待确认**，须由总管/派工逐目录定；②`check-doctor §7/§8` 与 `.githooks/pre-commit` 会挡（先补指针）；③身份三件一件不能少 |
| **A-10** | `reports/trials/` 的 6 个 tracked-but-ignored `serial-delta.log`（5.05 MiB）：`git rm --cached` 交给已有 ignore 规则 | **−5.05 MiB**（工作树） | 可逆（`git checkout` 前需文件仍在磁盘） | 先确认 `scripts/trial.sh` 的 record 判定不读这些文件本体（只读同目录 `*.tsv`）；**注意 `reports/trials` 是 trial 记录，动它等于动 record 面** ⇒ 建议总管收口时一并裁 |
| **A-11** | `dl-cam/` 4 个自研脚本加 `!` 白名单（`!/dl-cam/build-cam-provider.sh` 等），照 `.gitignore` 里 `/tools/*`+`!` 的既有写法 | +0.01 MiB（入库） | 完全可逆 | 无（纯防「换机丢自研脚本」，同 2026-11-06 `tools/mkbootimg` 教训） |
| **A-12** | `build/base-7.2`：**只做 bundle 保护**（`git bundle create backup/base-7.2-payload-v2-<d>.bundle --all`），登记进 `versions/` 与 `RESOURCES §3` | 磁盘 +≈0.5 GiB（新增 bundle） | n/a（保护动作） | 无；**这条是「不可删」判据的落地**，优先于 A-1/A-2 执行 |
| **A-13** | `initramfs/init.bak-*`（2 个 / 0.02 MiB）归档到 `archive/2026-11-13-initramfs-bak/` | −0.02 MiB | 可逆 | 先 `diff` 现版 `initramfs/init` 确认确无独有逻辑（本篇未 diff，**待确认**） |
| **A-14** | `out/` 的 5.79 GiB 镜像：`scripts/out-archive.py`（**默认 dry-run**）按 registry/manifest 对账后回收；**禁重跑 `scripts/vk-identity.py`** | **≈3–4 GiB**（registry 已登记的在途件除外） | 半可逆（归档后仍在盘上，可原子换回） | ①`check-doctor §5e` 硬门必须绿；②在途 vk 的镜像不列回收；③`out/*.manifest` 228 个一个不动 |

**明确不建议**（避免总管被反向建议带跑）：
① 历史重写（`filter-repo`/`filter-branch`）——现有 3 个 bundle（1.04 GiB，`bundle verify` 全过）+ 双远端已同步，
条件**看似**满足，但 `attic/*` 在 GitHub 侧缺失 ⇒ 判据③不闭合；
② 删 `.pi/agents/*.bak-alias-1112`（`.gitignore:391` 记用户要求保留）；
③ 删 `build/base-7.2`（payload 基点唯一载体）；
④ 删 `out/*.manifest`、`patches/`、`reference/`（三者分别是镜像身份、内核进度、同类芯片参照的 SSOT）；
⑤ 把 `reports/` 的 md 体量再算一遍（已归 `repo-slim-audit-20261113.md`）。

## 7. 本篇留下的「待确认」清单（拿不准的都标在这里）

1. `reports/artifacts/` 203 个「无 md 直接路径引用」目录（361.8 MiB）——口径偏保守，逐目录裁决需人工/派工。
2. `snap-20261110-*` 4 个 tag 是否精确等于对应 `elden-archive/*` tip（本篇只验了 `replay/m1-73-vk127` 与 2 条 `bundle/*` 祖先关系）。
3. `git ls-files` 的 6 525 路径中，`du` 与 `stat` 计数差 38 行（`du` 侧行为，`stat` 100% 命中）⇒ 本篇一律采 `stat`。
4. `m3v2-7.3rc7` 的 `blob:none` 部分克隆在 `gc` 时的按需取件面（未实测，A-2 已标为前置条件）。
5. GitLab `xqh/y700-elden-kernel` 的 40 天陈旧是否由 `history/pre-vk34` 之外还有未推分支（本篇只看 `--heads`，未看 tags）。

## 8. 复现命令（全部只读）

```bash
cd /home/xuqianhui/y700-elden
# 主仓对象层
git branch -a | wc -l ; git tag | wc -l ; git worktree list ; du -sh .git ; git count-objects -vH
git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | sort -rn -k3 | head
git verify-pack -v .git/objects/pack/*.idx | awk '$2=="blob"{print $4,$1}' | sort -rn | head
# 可达性拆分（本篇 22 blob / 194.36 MiB 即由此得）
git rev-list --objects HEAD | git cat-file --batch-check='%(objecttype) %(objectname)' | awk '$1=="blob"{print $2}' | sort -u > /tmp/h.txt
join /tmp/h.txt /tmp/pack_blobs.txt ; join -v2 /tmp/h.txt /tmp/pack_blobs.txt
# 被跟踪字节（stat 口径，勿用 du：du 会漏 38 行且是块占用）
git ls-files -z | xargs -0 -r stat -c '%s %n' | awk '{s[$2]=""} {p=$2;sub(/\/.*/,"",p);s2[p]+=$1;c[p]++} END{for(k in s2) printf "%.2f %d %s\n",s2[k]/1048576,c[k],k}' | sort -rn
# 嵌套仓
find . -maxdepth 6 -name .git | wc -l ; find . -maxdepth 6 -name .git -not -name '.git*' | xargs -n1 dirname | xargs -r -I{} sh -c 'printf "%s %s\n" "$(du -sh {}|cut -f1)" {}'
git -C geekidos-linux for-each-ref refs/heads --format='%(committerdate:short) %(refname:short) %(objectname)'
git -C geekidos-linux rev-list --objects --all | wc -l          # 146712
git -C build/m3v2-7.3rc7 rev-list --objects --all | wc -l       # 476514
# 三分类判据
git -C geekidos-linux merge-base --is-ancestor <tip> <tag-or-ref>   # 已并入
git -C geekidos-linux ls-remote --heads gitlab                       # 异地副本（代理已绕）
# 垃圾面
git ls-files -- '*.bak*' '*~' '*.orig' '*.rej' '.pi/trash'
git ls-files -i -c --exclude-standard          # 11 个 tracked-but-ignored
find . -maxdepth 4 -name '*.bak*' -not -path './build/*' -not -path './geekidos-linux/*' | xargs stat -c '%s' | awk '{s+=$1;n++}END{print n,s}'   # 29 / 85172
# bundle（只读校验）
git bundle verify backup/git-history-rewrite-20261112/pre-rewrite-main.bundle
```

---
**回执口径**：FAIL/WARN = `check-doctor.sh` **FAIL=0 / WARN=5**（5 条既有：vk 账历史留白 1、已登记例外 1、内核段不可读 1、PITFALLS 专题正文 1、报告无人引用 1——最后一条含本篇，需总管从对应 README/TASKS 补一处指针）。
本篇**未**跑 `checkpatch/DTC/dtbs_check`（本轮 0 个 DT/C 改动，无适用对象）；未改主线代码；未删任何文件。
