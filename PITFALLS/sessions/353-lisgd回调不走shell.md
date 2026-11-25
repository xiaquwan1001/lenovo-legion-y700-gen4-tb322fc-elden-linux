# #720 lisgd 的手势回调是 **fork+exec（不经 shell）** ⇒ `VAR=value cmd` 前缀形式会**静默不执行**

> 2026-11-25 实测（y700-elden，lisgd 0.3.7-1+b1）：为了给左右边缘各用一只马达，把回调从
> `/usr/local/bin/elden-swipe-back` 改成 `ELDEN_SWIPE_EDGE=L /usr/local/bin/elden-swipe-back`。
> **手势本身照样被识别**（lisgd `-v` 会打 `Swipe distance=… / Execute …`），但那条命令一行也没执行
> —— 窗口不关、没有任何报错。手工 `sh -c 'ELDEN_SWIPE_EDGE=L …'` 与直接执行都 rc=0，极具误导性。

## 判据

```sh
# 直接给 lisgd 一条带 env 前缀的命令，看窗口关不关（不关就是这条坑）
lisgd -d /dev/input/eventN -w W -h H -t 60 -m 800 \
      -g "1,LR,L,*,R,FOO=1 /path/to/cmd"
# 改成「包装脚本」后同一手势立刻生效
-g "1,LR,L,*,R,/path/to/cmd-wrapper"
```

分辨方法：`strace -f -e trace=execve` 看 lisgd 子进程的 argv —— 前缀形式下 argv[0] 是整串
`FOO=1 /path/to/cmd`（ENOENT），而不是 shell。

## 处置

- 需要环境变量/不同参数的变体 ⇒ **写成薄包装脚本**（`#!/bin/sh` + `VAR=… exec real-cmd "$@"`），
  让 lisgd 只拿一个绝对路径。本仓实例：`elden-swipe-back-left` / `-right`（左 `event2`、右 `event3`）。
- 同类「回调只有单条命令、没有 shell」的桌面 daemon（sway `bindsym exec`、dwl、部分 hotkey 工具）
  都要按这条检查一遍，别假设 `VAR=value cmd` 成立。
