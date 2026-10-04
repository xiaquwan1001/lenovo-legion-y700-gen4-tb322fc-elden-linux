# pre-vk34 历史回填（2026-10-04）

本项目 2026-10-03 19:31（`e3ec468 chore: 建立版本控制边界…`）才开始用 git 管理。
在那之前的 vk1–vk40 只存在于文字记录（`RESOURCES.md §3/§4`、`archive/topics/`）。
本目录记录一次**一次性重建**：把 git 纳管前的版本历史补回 git 对象库，使 `git log` 连续。

## 结果

- 新分支 **`history/pre-vk34`**：49 个提交，根提交 `base1`（2026-09-28），末提交
  `pre-git: 10-02~10-03 收尾`（2026-10-03 19:31:14）。
- 新标签 **`base1` `diag` `fixed3` `fixed4` `alpine` `gpu3` `vk1`…`vk40`
  `vk36debug` `vk38` `vk38debug` `vk40-ram`**，共 49 个（`vk38` 是 `vk38debug` 的别名，
  当年未产出普通 vk38 镜像）。
- **graft**：`git replace --graft e3ec468 <回填末提交>`，使 `e3ec468` 的父提交指向回填链。
  于是 `git log HEAD` 直接连续显示 **107** 个提交（58 原有 + 49 回填），无需切换分支。
- 回填末提交的树与 `e3ec468` 的树 **逐字节相同**（`git diff e3ec468 history/pre-vk34` 为空），
  因此嫁接处无任何文件增删/改名噪声。

## 方法（可复现）

1. `gen_plan.py`：按 `out/archive/boot-elden-*.img` / `out/boot-elden-*.img` 的 **mtime**
   排序版本，生成 49 行 `plan.tsv`（每行 = 提交的 epoch/tag/标题/正文，正文含镜像 sha256）。
   版本顺带记录了当时的主要改动（来自文字记录），另对**可唯一辨识的补丁/配置**给出显式归属
   （`plan.tsv` 第 6 列 HINTS，例如 `patches/0001-ath12k-*.patch` → `vk9`）。
2. `bf_build.sh`：纯 plumbing 脚本，**不触碰工作树/索引**。
   - 文件集与 blob/mode 一律取自 **`e3ec468` 的树**（= git 纳管时的项目快照，293 个文件）；
   - 每个文件的归属提交 = 最早一个 `epoch >= mtime` 的版本；已被 rename 的文件用新路径的
     mtime；无 mtime 或 mtime 晚于所有边界者落入最后的桥接提交；
   - HINTS 覆盖 mtime 归属；
   - 用 `GIT_INDEX_FILE`（临时索引）+ `git write-tree` + `git commit-tree` 逐提交生成，
     `GIT_AUTHOR_DATE`/`GIT_COMMITTER_DATE` 设为该版本 epoch；标签在同一循环里打。
3. `git replace --graft e3ec468 <tip>` 完成嫁接。

## 已知局限

- **mtime 只记录“最后一次修改”**：同一文件被多个版本反复修改时，回填只能把它放在
  最后修改时刻所属的提交里，早前版本的中间态无法还原。因此部分提交**没有文件变化**
  （空提交，仅承载版本叙事与标签）——这是诚实的「该版本无文件存活到此形态」，非漏项。
- 编译产物/内核源码树不在 git 内（`out/`、内核树未纳管），回填只覆盖被 git 跟踪的项目文件。
- 桥接提交（10-02~10-03）把该窗口内的文件整体并入，粒度到日。

## 复现 / 维护命令

```bash
cd ~/y700-elden
python3 archive/2026-10-04-git-backfill/gen_plan.py          # 重新生成 plan.tsv
# 重建（会先删同名 tag/branch，请确认无冲突）：
git tag | xargs -r git tag -d && git branch -D history/pre-vk34
bash archive/2026-10-04-git-backfill/bf_build.sh \
     /tmp/plan.tsv history/pre-vk34 e3ec468
git tag -a vk38 -m 'vk38 仅产出 debug 变体（同 vk38debug）' 'vk38debug^{}'
git replace --graft e3ec468 "$(git rev-parse history/pre-vk34)"
```

- 查看：`git log --oneline history/pre-vk34`；`git show vk9`；`git log --oneline HEAD`。
- **撤销嫁接**：`git replace -d e3ec468`（回填分支与标签保留）。
- 注意 `git replace` 是本地引用（`.git/refs/replace/`），`git clone`/`push` 默认不携带；
  到新克隆需重新执行上面的 `git replace --graft`（或改用 filter-repo 重写哈希，
  但那会改变 `e3ec468` 之后所有提交的 sha，破坏文档中已有引用，故未采用）。

## 文件

| 文件 | 说明 |
|---|---|
| `plan.tsv` | 49 个提交的完整叙事（epoch/tag/标题/正文/显式文件归属） |
| `gen_plan.py` | 由镜像 mtime 生成 `plan.tsv` |
| `bf_build.sh` | 由 `plan.tsv` 构建回填链（plumbing） |
| `bf_manifest_all.txt` | 构建时的 `epoch\|path` 清单（当时工作树快照） |
| `VERSION-MAP.txt` | 版本→提交 sha/日期 对照表 |
