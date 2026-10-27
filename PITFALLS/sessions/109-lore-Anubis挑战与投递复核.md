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
