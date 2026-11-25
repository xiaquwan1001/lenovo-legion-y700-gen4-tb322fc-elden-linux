# #725 `checkpatch.pl <file.patch>` 可能把补丁本身当**源码文件**解析 ⇒ 报一串假的 `ERROR: trailing whitespace`

> 2026-11-25 实例：复核 dwc3 v14 三枚补丁时，`perl scripts/checkpatch.pl --no-tree --strict --no-signoff v14-000N-*.patch`
> 每枚都报 **4 条** `ERROR: trailing whitespace`，行号定位到 `+ $` / `+-- $` —— 那些是**补丁正文里的空行**，
> 不是被改源码里的尾随空格。同一批件 `GATES-v14.md` 记的是 0E/0W/0C。

## 根因

`checkpatch.pl` 判「这是补丁还是源码文件」靠首行特征。我们的件由 `git format-patch` 生成后**首行是 `From: …`**
（无 commit hash），`--no-tree` 下它就走「源码文件」分支，于是把 diff 里的 `+`/`-` 当代码字符审，
`+ `（带一个空格的空行）自然被判成 trailing whitespace。**件本身没问题，是调用方式错了。**

## 判据（两条都对才算干净）

```sh
# 正确：喂 stdin（checkpatch 必走 patch 模式）
perl scripts/checkpatch.pl --no-tree --strict --no-signoff - < v14-0003-*.patch | tail -1
#   => total: 0 errors, 0 warnings, 0 checks, 624 lines checked   （2026-11-25 实测三枚全绿）

# 或者：放进 worktree 里用 `git format-patch` 重新出件后再喂 stdin；
#   绝不要为了「消掉这 4 条」去动补丁里的空行 —— 那会把 diff 改坏。
```

## 处置

- 复核别人/子代理报的 checkpatch 结论时，**先确认它用的是 patch 模式**（看输出里有没有 `FILE: <源文件路径>`；
  出现 `FILE: …/*.patch` 就是解析错了）。
- 本项目门禁脚本里凡跑 checkpatch 的地方，一律 `- < file.patch`。
