# rayburst/aria2 GitHub release 下载 hang 的 A/B 复现与定位（D20，2026-11-27）

承接 `reports/rayburst-redirect-hang-20261126.md`（上一轮只读取证）。本轮全部小流量（aria2 任务限时 35 s、curl ≤ 8 MB），只读不改任何配置；测试任务通过 RPC 投到 `/tmp/d20-ab/part`，结束即 forceRemove + 删目录。实测目标资产 totalLength = **66,862,311 B**（≈64 MB，非上轮估算的 903 MB 那个资产）。

引擎：`/usr/bin/aria2-next 3.1.0`（pid 1257492，conf 端口 29100，all-proxy=127.0.0.1:7890，split=20 / max-conn=20）。

## 一、aria2 RPC 三档 × 2 次（addUri → 5 s 采样 → forceRemove）

| 档 | run | status(5s) | 完成字节 | 速率 | errorMessage | 结果 |
|---|---|---|---|---|---|---|
| ① 默认 split=20 | 1 | active, 15 conn, 48 MB @ 13.7 MB/s | 66,862,311 | ~13 MB/s | 空 | **10 s complete** ✅ |
| ① | 2 | active, 11 conn, 57 MB @ 11.2 MB/s | 66,862,311 | ~11 MB/s | 空 | **10 s complete** ✅ |
| ② split=1 / max-conn=1 | 1 | —（≤5 s 已完） | 66,862,311 | — | 空 | **complete** ✅ |
| ② | 2 | — | 66,862,311 | — | 空 | **complete** ✅ |
| ③ all-proxy=""（直连） | 1 | active 35 s，**connections=0**，0 字节，totalLength=0 | 0 | 0 | 空 | **hang** ❌ |
| ③ | 2 | 同上，35 s 0 连接 0 字节 | 0 | 0 | 空 | **hang** ❌ |

每次测量外层均套 `timeout -k`；③ 两次由 forceRemove 收回。

## 二、curl 对照（`-r 0-8388607`，8 MB，`--max-time 45`，`-L` 跟随 302）

| 路径 | code | ttfb | total | bytes | 速度 |
|---|---|---|---|---|---|
| 直连 | 206 | 0.56 s | 2.90 s | 8,388,608 | 2.89 MB/s |
| 代理 127.0.0.1:7890 | 206 | 0.43 s | 1.44 s | 8,388,608 | 5.81 MB/s |

302 落到 `release-assets.githubusercontent.com`（Azure Blob，SAS 带 `se=2026-11-27T04:57:55Z`，有效期约 1 小时）。

## 三、判定

1. **本轮未复现用户会话的「代理路径 hang」**：默认 split=20 与单连接两种配置均 10 s 内完整下完 64 MB，速率 11–14 MB/s，无任何 errorMessage。上一轮的空等更可能是 **SAS 过期（`se=` 约 1 h 时效）或 mihomo 出口瞬时故障**，与 split 数无关。
2. **直连档稳定复现 hang**：`all-proxy=""` 覆盖后 aria2 两次均 35 s 内 connections=0、0 字节、totalLength=0（连元数据都拿不到）；而同机 curl 直连同一 URL 却 206/2.9 MB/s。矛盾点说明 aria2-next 的空字符串覆盖下出口行为与 curl 直连不同（可疑：空串覆盖未真正清掉 conf 的 all-proxy、DNS/IPv6 路径差异，或引擎对无代理场景的处理缺陷）——**即 rayburst 若曾走"无代理直连"路径，就会表现为永久空等**。
3. 结论置信度：代理路径本轮健康 = 高（4/4 成功）；直连路径 = aria2 引擎内部缺陷或覆盖语义问题 = 中。

## 四、配置建议（只建议，不改）

1. **不要改 split/max-connection-per-server**——本轮证明它们不是 hang 根因；保持现状即可。
2. 真正要点是**确保 all-proxy 恒有值**：mihomo 在线时代理路径完全健康；`all-proxy` 为空/失效的直连路径会 0 连接挂死。给 rayburst 引擎加「all-proxy 探活，代理不可达时拒绝任务并报错，而不是直连空等」。
3. GitHub release 场景兜底：即取即用（拿 `browser_download_url` 后立即投递），不缓存直链重试；SAS URL（302 目标含 `se=`）过期后必须重新走 302 取新链，不可复用旧 URL 重试。

## 五、下次现场复现取证指令

```bash
curl -sI -L --max-time 20 "<直链>"          # 先判活：200/206=网络面通，问题在引擎
aria2 RPC :29100 → tellStatus <gid>         # 看 connections / downloadSpeed / errorMessage(403=SAS过期)
curl -s "<302目标>" | grep -o 'se=[^&]*'     # 记录 SAS 过期时刻，与 hang 时刻对比
ss -tnp | grep aria2                         # 看引擎实际出口（代理 or 直连）
```

## 六、清理

- 全部 RPC 测试任务 forceRemove + removeDownloadResult；`/tmp/d20-ab/part` 已删（脚本 rpc.py 留存于 /tmp/d20-ab/）。
- `pgrep -a aria2` 仅剩原引擎 pid 1257492，无遗留下载进程。
