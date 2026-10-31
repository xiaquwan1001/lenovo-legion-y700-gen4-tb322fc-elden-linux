# #476 · 手工 `cat >` 部署 hook 会绕过 `stage.sh` 的三件事：shebang、属主、内容

- 日期：2026-10-31（一次启动周期的代价换来的）
- 背景：`packaging/elden-userland/hooks/*.pre` 是**片段**（无 shebang），因为 `render.py` 把它们内联进
  OpenRC initd 的函数体；作为 systemd `ExecStartPre=` 的独立脚本时，**`stage.sh` 才补 `#!/bin/sh`**
  （`rootfs/debian/stage.sh:120`：`{ echo '#!/bin/sh'; cat "$h"; } > "$dest"`）。
- 事故（两个独立故障，都是「手工部署」引起）：
  1. 直接把仓库源文件 `cat >` 到设备的 `/usr/local/libexec/elden/net-selfheal.pre` ⇒ 丢 shebang ⇒
     下一轮启动 systemd 报
     `Failed to execute /usr/local/libexec/elden/net-selfheal.pre: Exec format error`
     + `status=203/EXEC`，`net-selfheal.service` 直接失败。**注意它与「文件不存在」长得一模一样**。
  2. 为了省一次传输，把部署脚本 `cat script | ssh host "cat > /tmp/x.sh && sh /tmp/x.sh"`
     —— 远端 `sh /tmp/x.sh` 里的 `cat > <目标>` **又去读同一份 stdin**，此时 stdin 已被上面的
     `cat > /tmp/x.sh` 读空 ⇒ **目标文件被截成 0 字节**（`ls -l` 立刻可见 `0`，属主还变成 uid 1000）。
     即「把脚本和数据塞进同一个 stdin 管道」必然互相偷数据。
- 正确做法：
  - **部署一律取暂存产物**：`out/stage-debian/usr/local/libexec/elden/<hook>`（或走 `install-overlay.sh`），
    不要从仓库 `hooks/` 源文件直接推。推完立刻 `head -1` 验 shebang、`ls -l` 验非 0 字节与 0755。
  - 传输与执行分两条通道：`cat file | ssh host 'cat > dest'`（数据），
    `ssh host 'sh -s' < script`（脚本）——**不要串在一条管道里**。
  - 改完跑 `bash packaging/elden-userland/tools/verify.sh`（F 段逐字比对）而不是手工凭感觉。
- 附：`hooks/greetd.stop` 是带 shebang 的（`stage.sh` 见 `^#!` 就原样拷贝），所以同目录里两种形态并存是**正常**的；
  判断标准是「`stage.sh` 之后的东西对不对」，不是「源文件看起来像不像脚本」。
