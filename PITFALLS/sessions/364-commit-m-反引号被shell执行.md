# #731 `git commit -m "…"` 里的反引号会被 shell 先执行

## 现场（2026-11-26 晨，y700-elden）

提交 `deploy-ssc-sensors.sh` 时用了双引号 `-m "…（`install /dev/null`）…"`，终端先出现：

```
Too few arguments.
install: missing destination file operand after '/dev/null'
Try 'install --help' for more information.
```

随后提交成功，但 `git log -1 --format=%B` 显示那段文字变成 `（）`，另外两处反引号内容也空了。

## 机理

双引号里的 `` `…` `` 是**命令替换**，bash 先执行、把输出填进去；输出为空 ⇒ 文字消失。
`$()`、`!`（交互式历史展开）同理。

## 处置（本项目硬规则）

- 提交信息/评审回复/任何多行中文一律：`cat > /tmp/msg.txt <<'MSGEOF' … MSGEOF` 然后 `git commit -F /tmp/msg.txt`
  （单引号 heredoc 不做任何展开）。
- 已经推出去再修订：`--amend` + `push --force-with-lease` 在 **GitHub 可以**，在 **USTC GitLab `main`（保护分支）被 pre-receive 拒**，
  结果变成「双远端分歧」。本次处置 = 回到原提交（内容与修订版相同，只有消息差两处反引号内容）+ 强制推 GitHub 回同一提交，
  把教训写进本条。**先想清楚再推**比事后修更省事。
