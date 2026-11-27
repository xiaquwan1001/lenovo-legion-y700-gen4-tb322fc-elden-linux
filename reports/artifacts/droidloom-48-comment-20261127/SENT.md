# 已投：droidloom issue #48 补充复现数据

- **时间**：2026-11-27 22:4x CST（本机 `gh` 账号 `xiaquwan1001`）
- **目标**：<https://github.com/denialwm/droidloom/issues/48>
- **落地链接**：<https://github.com/denialwm/droidloom/issues/48#issuecomment-7221182777>
- **正文 sha256**：`7d621ce436f65a91eb462bff071363d5bb85a6dcfef223cdfa99356338b55a68`（= 仓内 `body.md`）
- **口径**：外发策略「默认一律允许 + 发完当轮报备」（`AGENTS.md` 2026-11-27 用户改）；三件前提保留 = ① 无套话、每条论断附可复现证据（命令 + 原始输出片段/报告小节）② 逐条对应原帖的两个根因 ③ 不推销我方本地 patch（只把 workaround 作为「我们怎么绕的」列出，并明确「我没有那次复禁的日志」）。
- **发前父代理独立复核**：`0.1.0-51` 源码两处如实（`development_network.rs:29-34` LEASE 硬编码 `1.1.1.1/8.8.8.8`、`WifiProvisioning.java:42/82` 一次性位 + `enableNetwork(networkId,false)`）；「三探针今日全 204」来自 `reports/droidloom-cell-network-20261126.md`。
- **隐私处理（父代理改过正文，与 subagent 初稿不同）**：删掉宿主公网 IP `114.214.233.60/22`、学校名与校内 DNS 明文 IP（改为 `behind NAT` / `the university's resolver` / `<campus-resolver>`），技术论断一字未削弱。
- **回滚**：`gh api -X DELETE repos/denialwm/droidloom/issues/comments/7221182777`（需要时）。
- **原帖状态**：open、0 评论（发前 `gh issue view 48` 实测）；原帖主题 = 虚拟 Wi-Fi `"Droidloom"` 被 `WifiConfigManager` 永久禁用 + `WifiProvisioning` 一次性位不复查 + `DhcpResponder` 硬编码公共 DNS。
