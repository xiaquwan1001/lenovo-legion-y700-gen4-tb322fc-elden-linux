# #417 门禁脚本里 `grep -r "$REPO"` 会把 13 GiB 内核树一起扫；`grep -qE` 的 rc 在 `if !` 里不能当正则编译判据

> 2026-10-26，`packaging/elden-userland/tools/check-coupling.sh`（用户态去 Alpine 化门禁）首次跑就卡住 60 s 不返回，
> 被误当成「命令太长」。两个独立缺陷叠在一起。

## #417a 全仓递归 grep = 分钟级门禁

```bash
# 坏写法（verify_waivers 的 message 分支里，且这段逻辑本身是死代码 `... | head -0 && true`）
grep -nE "$pr" --include='*' -r "$REPO" 2>/dev/null | head -0
```

`$REPO` = 项目根，里面 `geekidos-linux/`（13 G 内核树）+ `build/`（多份 worktree）+ `out/` + `backup/`。
`head -0` 立刻退出，但 grep **要遍历完整个目录树**才发现要写的东西，所以 EPIPE 救不了；
实测 `real 60.0s / user 0.03s`（几乎全在 I/O 阻塞）⇒ 看起来像「命令太长/挂死」。

**判据**：门禁脚本只允许扫「明确的小范围路径清单」；出现 `grep -r <仓库根>` 一律视为缺陷。
修法：删掉死代码；若确实要按行核查，用 `emit_hits` 里已有的「逐文件 + 已知行号」路径。

## #417b `if ! cmd; then ... $?` 测不出 grep 的 rc

```bash
# 坏写法：$? 在 then 块里是 `! cmd` 的结果（0），永远不等于 1 ⇒ 合法正则全被报「无法编译」
if ! printf '' | grep -qE "$pr"; then [ $? -eq 1 ] || bad "W 正则无法编译"; fi
```

`grep -qE` 退出码语义：**0=命中，1=合法但无匹配，2=正则非法**。要区分 1 与 2 必须直接收 rc：

```bash
printf '' | grep -qE "$pr" 2>/dev/null; rc=$?
[ "$rc" -le 1 ] || bad "W 正则无法编译（rc=$rc）"
```

同类坑还有：`set -u` 下 `trap 'rm -f "$probe"' EXIT` 引用函数内 `local` 变量 ⇒ 退出时报
`probe: 未绑定的变量`（用 `${probe:-}`）；`printf` 的格式串里出现 `\.` ⇒ `无效的格式字符`
（正则里的点用 `[.]`，或在 printf 里 `%%` 转义）。

## 影响与现状

修完后 `check-coupling.sh` 全量扫描 **2.7 s**、`FAIL=0`、`--self-test` 全绿。
教训适用于所有新门禁：**先测空跑耗时**（`time bash gate.sh`），再谈判据正确性。
