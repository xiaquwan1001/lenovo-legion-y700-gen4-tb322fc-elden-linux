# 2026-11-03 本地 git 树精简合并 + 损坏镜像重建

> 触发：用户「把本地的 git 树开始精简合并」「那个损坏的文件重新建」。
> 前置：`reports/asset-tidy-20261103.md`（同日项目整理；该轮检出 `out/boot-elden-m3v5-daily.img` 静默损坏）。

## 1. 数字结论

| 项 | 结果 |
|---|---|
| 分支 | 5 → **1**（`main`）；3 条 lane 合并、1 条已合并分支删除 |
| 工作树 | 4 → **1**（`wt/` 下 3 个 lane 工作树已移除） |
| `.git` 体积 | **450 M → 201 M**（−55 %，`git gc --prune=now` 后） |
| 历史中最大 blob | 2.8 GB `serial-delta.log` → **已从本地独有历史中清除**；96 MiB `boot_b-backup-2350.img` 同样清除（改由 `SHA256SUMS.img` 记账） |
| 提交/标签 | 1031 提交 / 61 标签；`main` 已推到 GitHub 且**本地=远端逐字节一致** |
| 损坏镜像 | 重打后 **sha256 与 manifest 记录逐字节相同**（`4d7e2ea9…`）⇒ 完全修复，身份表该行恢复原值 |

## 2. 分支合并（按 `scripts/lane.sh merge` 的 `--no-ff` 流程 + 打 `merge/<lane>` 标签）

三条 lane 都是 `status=done`、各**领先 main 1 个提交**、工作树干净：

| lane | 内容 | 冲突裁决 |
|---|---|---|
| `aw86927-series` | 5 枚固件波形系列草案 + 报告（1104 行） | `patches/upstream/aw86927-20261027/README.md` 取 **main 版**：main 已有「⛔ 被 v2 取代」横幅，lane 版是未带横幅的旧稿 |
| `b5-resoc` | bonded-DSI per-SoC cfg + host ops 补丁（780 行） | `patches/local/b5-resoc-20261027/0001-0003` 取 **main 版**：main 已扩到 5 枚（另有 0004/0005），lane 停在 3 枚初稿 ⇒ main 是超集 |
| `devcam-ab` | M4-R1 SKEW_CAL A/B 上机件 + 测量脚本 | `reports/trials/index.tsv` 按**首列时间戳并集**合并（两侧都追加数据行，无重复行丢失） |

**验证**：逐 lane 用 `git cat-file`/`git diff` 核对「该 lane 那 1 个提交改过的每个文件」都在 main 里，且除上面 4 处**有意保留 main 版**的文件外内容逐字相同。删分支后这些内容仍可从 merge 提交的第二父（`f4b6852`/`0f5a270`/`6dbc0c3`）取回，历史未丢。

另删 `sync/glab-20261031`（已完全并入 main）。

## 3. 历史重写（仅为解 GitHub 拒收），范围 = 本地独有段

GitHub 拒收原因（`gh001 Large files detected`）：
- `reports/trials/20261024T021942Z-q32c1-r1/serial-delta.log` **2812 MB** —— 该文件在 2026-10-26 的历史重写里被剔除过，但后来又被重新提交（`.gitignore` 只对未跟踪文件生效）；
- `reports/artifacts/uefi-ddrcut-20261101/boot_b-backup-2350.img` **96 MiB** —— 违反项目既有口径「96 MiB 槽位镜像不入库」。

处置：
1. 备份：`backup/git-history-rewrite-20261103/pre-rewrite-all.bundle`（280 M，`git bundle verify` 通过，**含重写前全部 61 标签与全部分支**，可完整回滚）。
2. 96 MiB 镜像 → 出索引、文件留盘，新增同目录 `SHA256SUMS.img`（`fb55997c…`）+ `README.md` 作唯一账；`.gitignore` 补该目录 `*.img`。
3. `.gitignore` 补 `reports/trials/*/serial-delta.log`（该行原已存在；本次确认它**防不住已被跟踪的文件**，故同时做历史清除）。
4. `git filter-branch --index-filter`（范围 `3b7041b6..HEAD`，即 `github/main..main`，**未触碰任何已发布提交**）剔除上述两个路径；`--tag-name-filter cat` 同步重写范围内的标签。
5. `refs/original` 删除 + `reflog expire --expire=now --all` + `git gc --prune=now`。

**代价（如实记账）**：本地独有段内 242 个提交的 SHA 变了（例如 `439fe20` → `b23cc24`）。文档里若直接引用这些 SHA 会失效——本项目历史重写已有先例（`backup/git-history-rewrite-20261026/`），口径一贯是「引用日期/路径，不引用 SHA」。旧 SHA → 新 SHA 的映射可查 `backup/git-history-rewrite-20261103/pre-rewrite-all.bundle`。

残余：2.8 GB blob 仍可由 `refs/remotes/origin/main`（USTC 旧线 `953ec24`）reachable，故本地未彻底消失；`origin` 是保护分支/已停用的旧远端，**不影响 GitHub 推送**（push 只发送从所推 ref 可达的对象）。

## 4. 损坏镜像重建

- 输入三件（`build/m3v5-daily` 的 `Image.gz`、DTB、`out/initramfs-full-elden.cpio.gz`）**sha256 与 manifest 逐项吻合**。
- 用 manifest 里记录的 `mkbootimg_args` 原样重打（`scripts/mkbootimg.py`）：产出 **84 529 152 B**，
  sha256 = **`4d7e2ea9a10ca0f4ed0d97946089b6d6cabccea9a9a209b867c23c47c4143e73`** = manifest 的 `image_sha256`（**逐字节复现**）。
- 结论：输入无误、打包器确定性正常 ⇒ 之前那份确实是**落盘后的静默数据损坏**（size/mtime 未变、220 个镜像中仅此 1 个不符）。
- 已恢复 `out/boot-elden-m3v5-daily.img`；身份表重生成后该行回到原值（`kbin 712d9872bded`、`uts_dup12`）；
  `versions/vk-ledger-known-issues.tsv` 的计数改动已回滚为原值，仅保留一条事件注记。
- 损坏原件留在 `backup/corrupt-20261103/`（84 MiB，sha `9a5000d3…`）作取证。

## 5. 收尾状态

- `scripts/check-doctor.sh`：**FAIL=0 / WARN=3**（均为历史留白：vk183 无 manifest、账本例外、无版本号拷贝）。
- `git status` 干净；`main` = `github/main` = `6fde4f9`。
- 未做：`origin`（USTC）同步——该远端为保护分支且已停用，口径见 `RESOURCES/README.md` §1。
