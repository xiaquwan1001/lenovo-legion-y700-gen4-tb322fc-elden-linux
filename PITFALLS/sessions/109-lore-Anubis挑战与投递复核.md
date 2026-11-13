# 109 · lore.kernel.org 的 Anubis 挑战：别把「查不到」当成「没投递」

> 2026-10-27（M4-1 投递当轮）。**#444**

## 现象

补丁 `git send-email` 全封 `Result: 250`，但复核归档时 `curl` 打 lore 拿到的是：

```
<title>Making sure you&#39;re not a bot!</title> ... Protected by Anubis From Techaro ... Difficulty: 4
```

带 `User-Agent` 能看到 200，但正文仍是挑战页；`/raw` 同；MTA 侧一切正常（250 + 本机 Sent 副本在位）。
**误判风险**：以为邮件没进列表，进而重发或改配置 —— 实际只是复核通道被挡。

## 判据与可行路径（实测）

| 方式 | 结果 |
|---|---|
| `curl` 直连（无 UA） | **403** |
| `curl -A "Mozilla/5.0"` | 200 但是挑战页（不是归档页） |
| `web_fetch provider=browser`（headless Firefox） | **能过**（同一 MID 有时第一次就过，有时需重试 1–2 次） |
| `touch ~/pi-firefox/headed` 用有头窗口 | **无改善**（PoW 不受影响） |
| 换列表前缀（`/linux-media/` → `/devicetree/` → `/all/`） | 都会命中挑战，但 `/all/<mid>/` 命中率最高 |

⇒ 复核顺序：`/all/<message-id>/` → 失败重试 → 仍失败则先信 250 + Sent 副本，**隔一轮再复核**，
不要据此重发（重发会产生重复线程，比晚确认更糟）。

## 顺带确认的事实

- 归档页里 `In-Reply-To`/`References` 与 `git send-email` 的 `--no-chain-reply-to` 组合正确（cover → 1/2 → 2/2）。
- 归档正文与本站 `format-patch` 输出逐字一致（人工比对 `diff --git` 段）。

## 附：#445 手写 TCP 中继会把 TLS 首包丢掉（暴露代理给设备要用的正确做法）

同轮为修「设备到宿主代理不通」自写了 python 中继（thread-per-connection、双 `pipe()`）：

- 症状：`curl -x http://192.168.7.9:7897 https://…` **6 连里挂 2–3 发**（`SSL connect error` / exit 35），
  而直连 `127.0.0.1:7890` **5/5 全 204**；失败的那一发 `CONNECT` 已经 200，说明隧道建好但**首包被吞**。
- 试过换实现细节（`--accept` 线程化、`TCP_NODELAY`、把程序文本从 stdin 挪到文件）**都不解决**。
- 正解：**用 systemd 自带的两件套**——
  `systemd-socket-activate -l <ip>:<port> /lib/systemd/systemd-socket-proxyd 127.0.0.1:7890`
  （实体脚本 `scripts/host-net-proxy.sh`，实测 host 6/6、device 6/6 全 204）。**不要再手写字节中继**。
- 另一条纪律：清理这类助手**别用 `pkill -f <模式>`**——模式文本就在自己的 `bash -c` 命令行里，
  会把自己那条 shell 杀掉（本轮实测 exit 143）。用 `ss -ltnp` 取出 `pid=` 再 `kill`。

## #648：上游有「正统系列」时，先逐条对账再决定收发；没有对照表不发提问

- 场景（2026-11-13，camss）：Krzysztof 早在 10-28 就问过「Qualcomm v6 怎么了」，我们一直没接。
  本轮把 v6（7 补丁，2026-07-21）与自建 9 补丁逐项对账：**5 项被覆盖、2 项被 reviewer 否、
  1 项已作独立修复投递、1 项板级 DTS 等 rebase**；唯一硬分歧 = CSIPHY 2.3.0（v6 复用 kaanapali）
  vs 2.4.0（本机 vendor `camera.ko` 表 103 条证据）。
- 判据：**能给出差集才发信**。手上没有 kaanapali 表时，提问只能给结论、给不了证据——
  这正是 `mu_wide_platforms#12` 里被回「别用劣质 token 瞎猜」的那类。
- 做法：先落盘对账报告（`reports/camss-v6-rebase-plan-20261113.md`），把「需要哪棵树/哪张表才能定论」
  写成下一步；只有实测失败（不出流/坏帧）才升级为上游 thread。
- 附带纪律：路线被取代时**立刻**给自建系列打 superseded（`patches/upstream/<系列>/README.md` 顶部状态行），
  否则后续会话会继续按旧系列出 vN——与 #637–#646 的「config 快照漂移」同源的静默腐烂。
