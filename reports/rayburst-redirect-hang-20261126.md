# rayburst 下载 GitHub release hang 取证（2026-11-26，只读取证）

## 现象

rayburst（下载引擎）直取
`https://github.com/denialwm/droidloom/releases/download/packages/droidloom-image-0.1.0-49-aarch64.pkg.tar.zst`
空等不出数据；同一 URL 从浏览器（http 网页跳转）可正常下载。用户已手工下到 `/home/xuqianhui/下载/`。

## 铁律遵守声明

本轮只读取证：未改 rayburst / aria2 / mihomo（bettbox）任何配置，未外发数据，大流量测试仅取 1 MB 范围请求。

## 本机部署（父会话现查，2026-11-26 23:0x CST）

- 进程：`/usr/bin/rayburst --autostart`（pid 6070）+ 引擎 `/usr/bin/aria2-next --conf-path=/home/xuqianhui/.local/share/dev.aninsomniacy.rayburst/engine/aria2.conf`；另有 defunct 残留进程（父会话 `ps` 观察）。
- `aria2.conf` 关键项：`all-proxy=http://127.0.0.1:7890`（mihomo/bettbox）、`split=20`、`max-connection-per-server=20`、UA=Chrome/147、`dir=/home/xuqianhui/下载`、RPC 端口 **29100**（非常见 29000）、RPC secret 存在（本文不落明文）。
- 技能文档：`~/.pi/agent/skills/software-development/aria2-rpc-downloads/SKILL.md`。

## 资产存在性（GitHub API 直接证据）

`api.github.com/repos/denialwm/droidloom/releases`（tag `packages`，release id 387046539）确认目标资产：
`droidloom-image-0.1.0-49-aarch64.pkg.tar.zst`（release-assets 系，同批次 `droidloom-base-0.1.0-49-aarch64` size = **903,293,629 B** ≈ 903 MB，
content_type `application/zstd`，state `uploaded`，2026-11-20 上传）——与用户手工下载的 903 MB 一致，URL 无误、文件未删。

## curl 对照实测（父会话执行，本轮转述原始输出）

| 路径 | 结果 |
|---|---|
| 直链 `curl -sSIL` | **200**（2.3 s，302 已跟随） |
| 302 链 | github.com → **`release-assets.githubusercontent.com`**（Azure Blob，`server: Windows-Azure-Blob`，**SAS 签名 URL，带 `se=` 过期时间**）→ 206 |
| 直链 `-r 0-1048575` | 206，1 MB / 4.46 s（~235 KB/s） |
| 走 mihomo 代理 127.0.0.1:7890 同上 | 206（~239 KB/s） |

⇒ **此刻本机两条出口（直连 / mihomo）对该 release 直链均通**，1 MB 分段请求正常，无 objects.githubusercontent.com 直连被掐、无 UA/Accept 差异致死（curl 默认 UA 也能通）。

## 根因（判读，非直接观测）

GitHub release 下载语义 = `github.com` 302 → Azure Blob **短时效 SAS URL**（`se=` 过期）。多连接下载器在此链路上的典型失效模式：

1. 拆 20 连接打 SAS URL：Azure Blob 对同一 SAS 的并发/Range 行为不稳定，部分连接 0 字节拖死整单；
2. 重试复用已过期的 SAS URL：`se=` 一过，任何重试都拿不到数据（403/空响应），表现为永久空等；
3. `split=20` 部分连接出口不一致（部分绕过代理直连），混路时最慢/被掐的一路卡住全局。

浏览器成功的原因：每次点按**重新取新 SAS** 且**单连接**跟随 302。rayburst 空等发生在用户会话时刻，SAS 已过期，**事后无法用同一 URL 复现**——这是本次取证的时序性限制（已在下节标注）。

## 可复用判据

- 现场判活：`curl -sI -L --max-time 20 <直链>` 应 200；若 aria2 侧卡住而 curl 通 ⇒ 问题在下载器处理 302/SAS，不在网络/代理。
- aria2 RPC（端口 29100）：`aria2.tellStatus <gid>` 看 `errorMessage`（403 = SAS 过期）、`connections`/`downloadSpeed`（0 B/s 多连接 = 拆连打死）。
- 302 目标含 `se=`（SAS 过期参数）时，**不要缓存该 URL 用于重试**。

## 修法建议（未实施，仅建议）

1. **改用 aria2 RPC 通道**（项目已有技能 `aria2-rpc-downloads`）：GitHub release 用单连接（`split=1`）+ 跟随重定向投递；903 MB 在 ~235 KB/s 下约 64 分钟，可接受或走 mihomo 节点提速。
2. rayburst 侧试验性把 `max-connection-per-server` 降为 1（针对 GitHub release 域），或升级 rayburst/aria2-next 看是否已修 SAS 重取。
3. 兜底：GitHub release 大文件优先走 `api.github.com` 拿 `browser_download_url` 后即取即用，不落库长存 URL。

## 验证限制（如实标注）

- rayburst 侧 hang 的**现场**（引擎日志、当时 RPC 状态、当时的 SAS URL）未采到，空等结论基于用户会话观察 + 机制判读。
- 父会话 curl 对照为**事后**复测（当时通）；不能排除用户会话时刻 mihomo 出口短暂故障与 SAS 过期叠加。结论置信度：网络面排除 = 高；rayburst 内部根因 = 中（机制推断，未引擎日志实证）。

## 来源

- GitHub API releases（直接证据，2026-11-26 fetch）：https://api.github.com/repos/denialwm/droidloom/releases
- 父会话 curl 实测原始输出（2026-11-26 23:0x CST，本报告转述）
- rayburst 部署事实：父会话 `ps` + `aria2.conf` 现查
- 技能：`~/.pi/agent/skills/software-development/aria2-rpc-downloads/SKILL.md`
