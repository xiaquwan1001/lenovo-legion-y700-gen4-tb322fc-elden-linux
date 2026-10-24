# 全局 git 的 `url.git@github.com:.insteadOf` 会把子模块 https 改写成 SSH，导致 clone 挂死且 0 字节（#386）

> 日期：2026-10-24 · 场景：Mu UEFI 仓库 `git submodule update --init` 反复「卡住 25 分钟」。

## 症状

- 子模块 clone 长时间无进展，报告里表现为「某个很大的资源一直阻塞」；
- `ps` 里看到真实传输进程是 `/usr/bin/ssh -o SendEnv=GIT_PROTOCOL git@github.com git-upload-pack 'openssl/openssl'`，状态 `S`、`wchan=poll_schedule_timeout`；
- 同时 `/sys/class/net/<iface>/statistics/rx_bytes` 5 秒增量为 **0 KB/s** ⇒ 根本没有任何流量（不是带宽慢、不是资源大）；
- 仓库体积几乎不涨（`du -sh` 前后一致），`.git/modules/*` 里对应目录为空。

## 根因

`~/.gitconfig` 里有：

```
[url "git@github.com:"]
    insteadOf = https://github.com/
```

它把**所有** `https://github.com/...` 改写成 `git@github.com:...`（SSH）。本机 SSH 到 github 不通/无响应，
于是每个子模块都会先挂满自己的 timeout。命令行再用 `-c url."https://gh-proxy.com/https://github.com/".insteadOf="https://github.com/"`
也无法覆盖——**同前缀的 insteadOf 冲突时，不能指望命令行那条赢**。

## 判据与修法

```sh
# 判据：禁止 ssh 协议后立刻变得可诊断（不再挂死，直接报错）
GIT_ALLOW_PROTOCOL=https git ls-remote https://github.com/openssl/openssl HEAD
#   → fatal: 传输 'ssh' 不允许      （说明 https 被改写成了 ssh）

# 修法：忽略全局/系统配置，让 https 真的是 https（需要镜像再用 -c 改写）
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
  git -c url."https://gh-proxy.com/https://github.com/".insteadOf="https://github.com/" \
      submodule update --init --depth 1 --jobs 1 -- <path>
```

两条都在本机实测 `rc=0`、秒回。

## 纪律

- **「卡住」先看流量**：`rx_bytes` 增量 0 ⇒ 不是带宽/资源问题，是协议或 DNS/握手；再看 `ps` 里真正在跑的是 ssh 还是 git-http。
- **别靠加 timeout 解决**：25 分钟 × N 个子模块 = 白等；先用 `GIT_ALLOW_PROTOCOL=https` 一条命令定位协议层问题。
- 全局 `insteadOf` 是「便利」也是「暗坑」：凡是要按 URL 精确控制通道（镜像、sparse、submodule）的场合，一律用
   `GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null` + 命令行 `-c` 显式指定，别继承全局。
