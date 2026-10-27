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
