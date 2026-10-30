## #448 lane 产物提交在分支、主仓只写收口总结 ⇒ 文档开始指向不存在的路径

> 2026-10-27 晚收尾时发现。三条 lane（`aw86927-series` / `b5-resoc` / `devcam-ab`）全部 `status=done`，
> 报告与补丁也都「在」，但**都在各自 worktree 的分支上**（`/home/xuqianhui/wt-*` @ `lane/*`），
> 主仓 `main` 只落了父 agent 自己写的那一句收口总结。

### 一、现象（可复现）

`TASKS/README.md §7` 与 `reports/upstream-status-20261027.md` 里写着：

```
补丁 `patches/upstream/aw86927-20261027/`（5 枚 853 行 + README 59 行）、判定 `reports/aw86927-series-20261027.md`（192 行）
补丁 `patches/local/b5-resoc-20261027/`、报告 `reports/b5-resoc-20261027.md`
```

而主仓里这 8 条路径**一条都不存在**：

```sh
ls patches/upstream/aw86927-20261027 reports/aw86927-series-20261027.md \
   patches/local/b5-resoc-20261027 reports/b5-resoc-20261027.md
# → No such file or directory ×4（另有 4 条同类）
```

危害不是「少了几个文件」，而是**下个会话会照路径找不到，然后把已经做完的工作重做一遍**；
`check-doctor §8` 只查「每篇 reports 是否被引用」，**不查「被引用的路径是否存在」**，所以静默通过。

### 二、根因

lane 的工作方式 = `git worktree add /home/xuqianhui/wt-<lane>`，lane 在**自己的分支**上提交产物。
父 agent 收口时写的是书面的「三条 lane 收口」文档，**没有把 lane 的 commit 合进 main**。
lint 侧没有任何东西会因为这个失败（`git status` 干净，因为 worktree 的文件是已提交的）。

### 三、处置（已落地）

- **合入**：`git cherry-pick ea6c518 41f9996 72acfd3` —— 三次全部干净（各 lane 只加了
   `patches/**`、`reports/**`、`scripts/**`，无构建产物）。合入后 8 条路径全部存在。
- **加门禁**：新脚本 `scripts/check-doc-assets.sh` —— 扫入口文档（`TASKS/README.md` / `INDEX.md` /
   `DEVICE/README.md` / `PITFALLS/README.md`）+ 最新的 `reports/upstream-status-*.md`，
   把反引号里的 `patches/ reports/ scripts/ rootfs/ packaging/ bootslot-b/` 路径逐个验存在；
   **前缀截断**（`patches/0011` 指 `0011-*.patch`）按 glob 解析，避免误报；
   豁免表 `scripts/doc-assets-allowlist.txt`（每行 `路径<TAB>理由`）只收「换机丢失 / out/ 不入库」这类。
   接进 `check-doctor.sh` 的新 **§13**：现状 `checked=384 missing=0`。
- **纪律**：lane 收口 = 「报告落盘 + **分支合入 main** + `check-doctor` FAIL=0」，
   缺任何一项都不算收口（父 agent 不能只看 `git -C wt-* status` 干净就认为产物在主仓）。

### 四、附带查出的旧记账错误

（历史断言，已修正）`PITFALLS/README.md` 索引行曾出现 `#446`/`#447` 同编号 110 且 `#446` 无链接——现索引已改为 110=#446、111=#447 且两行均有链接。
已改成 110/111 且补全链接；本条起编号顺延。
