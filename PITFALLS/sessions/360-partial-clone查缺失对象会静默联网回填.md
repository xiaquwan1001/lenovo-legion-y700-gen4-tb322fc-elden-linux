# #727 partial clone 上查缺失对象会**静默联网回填**：代理链路挂死时表现为「命令永久卡住」

> 2026-11-25 实例（恢复 `geekidos-linux/` 的残缺祖先）：在 `/tmp/kchk`（`git clone --filter=tree:0 --depth=1` 的
> stable 浅克隆）里跑 `git cat-file -p <sha>`，git 自动起了一个 `git fetch <remote> --filter=blob:none` 子进程去
> GitHub 回填对象，走 `127.0.0.1:7890` 代理 ⇒ **13 分钟零 I/O 进展**，socket ESTAB 但不搬数据；`ps` 里只看得到那个
> fetch 子进程，原命令看起来「就是卡住了」。同轮 `geekidos-linux/` 里 `git rev-list --all` 也因同机制尝试联网后 abort。

## 根因

partial clone（`--filter=blob:none` / `tree:0`）把缺对象记在 **promisor remote** 上；任何读对象操作
（`cat-file` / `log -p` / `diff` / `show` / `fsck` 的某些路径）撞到缺对象时，git **不报错、先联网要**。
于是「只读核对」变成网络动作：代理/上游不稳 ⇒ 无超时地挂住；反过来，网络通时又会悄悄下几百 MB，违背「不要全量」。

## 判据

```sh
# ① 只读核对一律禁掉隐式回填（本机已实测：缺对象立刻报错而不是联网）
GIT_NO_LAZY_FETCH=1 git -C <repo> cat-file -t <sha>

# ② 怀疑卡住时看子进程：出现 `<remote> --filter=blob:none` 的 fetch 就是隐式回填
ps -eo pid,ppid,etime,cmd | grep -E "[g]it (fetch|cat-file)|[f]etch-pack"

# ③ 判断仓库是不是 partial
git -C <repo> config --get remote.origin.partialclonefilter   # blob:none / tree:0
```

## 处置

- 只读判定：一律 `GIT_NO_LAZY_FETCH=1`（本仓 `scripts/vk-identity.py` 交叉核对内核树时同理）。
- 真要补对象：**显式** `git fetch --filter=tree:0 <remote> <sha>` 或先 `--depth=1` 取单提交，别让读操作代劳；
  外部命令仍守 `timeout -k`（全局规则 14）。
- 网络面：本机对 GitHub 的 **HTTPS git 不稳**（`GnuTLS recv error (-110 / -9)`、`curl 56`，直连与代理都出现过），
  而 `curl` 拉网页 200 ⇒ 不要用「网页通」证明「git 通」；要拉对象就重试 2–3 次并带超时。

## 指针

`versions/kernel-src-archive.tsv`（该目录的恢复命令与「18 条祖先断链」记录）、`versions/layout.tsv`（`geekidos-linux/` 行）、
`reports/disk-cleanup-20261119-validation-impact.md`。
