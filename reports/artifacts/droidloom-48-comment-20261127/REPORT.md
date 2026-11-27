# `denialwm/droidloom#48` 英文补充评论 —— 草稿与出处台账（2026-11-27）

- **唯一写入**：本目录（`reports/artifacts/droidloom-48-comment-20261127/`）。`body.md` = 待发评论（英文，31 行），**未发布、未提交、未改任何仓内其它文件**。
- **原帖读取状态**：**读到**（`timeout -k 10 60 gh issue view 48 -R denialwm/droidloom --json title,body,comments`，rc=0）。
  - 标题：*[Bug] Virtual Wi-Fi "Droidloom" gets permanently disabled on captive-portal validation failure, breaking networking and ADB across reboots*
  - open，`updated 2026-11-22T12:33:38Z`，**comments = 0** ⇒ 本评论不会与既有讨论重叠（仓内 `reports/droidloom-upstream-cluster-20261127.md` §1 记的「0 评论」与本次实查一致）。
- **写作口径**：只补「原帖没有的量化」。原帖已有：主因机制、`noInternetAccessExpected` 建议、captive URL workaround、`1.1.1.1` 被拦的 secondary note。故评论**不重复论证修法**，只加：探针今日可达仍永久禁用、校园网 53 全封（而非拦截）、恢复顺序与副作用（miui 端点 200）、跨重启不持久、51 源码未变。

## 一、评论内每个论断 ↔ 仓内出处

| § | 论断（body.md） | 仓内出处 | 原始命令/摘要 |
|---|---|---|---|
| 环境 | `TB322FC` / SM8750 / Debian 13 + phoc/phosh / 校园网 | `reports/droidloom-deploy-20261126.md` 标题+§3-3（Debian trixie、phoc/phosh 各 1）；`reports/android-compat-20261026.md` §G3（TB322FC/SM8750） | — |
| 环境 | `droidloom-{runtime,image,base} 0.1.0-49` 为取证版本；51 已装 | `droidloom-upgrade-51-ime-20261127.md` §0-1/§1/§5；`droidloom-cell-network-20261126.md` 第 3 行（源码 = release 49 @572e1c5） | — |
| 1 | `- DSBLE ID: 0 … NETWORK_SELECTION_PERMANENTLY_DISABLED`；`firstL2ConnectionAttempt=null`；`Ignoring network selection disabled SSID` | `droidloom-cell-network-20261126.md` §0-1 与 **§2 表 `cell 内 dumpsys wifi` 行** | cell 内 `dumpsys wifi` |
| 1 | `hasEverConnected: true / hasNeverDetectedCaptivePortal: true / hasEverValidatedInternetAccess: false` | 同上 **§2 表 `cell 内 dumpsys wifi（PerNetwork）` 行** | 同上 |
| 1 | `WifiConfigStore.xml`：`SelectionStatus` / `DisableReason` / `CreatorUid=10072(systemui)` | 同上 **§2 表 `cell 内 cat …/WifiConfigStore.xml` 行** | `cat /data/misc/apexdata/com.android.wifi/WifiConfigStore.xml` |
| 1 | netns `wlan0` `UP,LOWER_UP` 无 IPv4、`ip route` 空 | 同上 **§2 表 `nsenter -t 120626 -n ip -br a` 行的判读列** | `nsenter -t 120626 -n ip -br a` / `ip route` |
| 1 | 宿主 `adb devices -l` 空；journal 仅 `ADB disconnect failed: no such device '10.177.0.2:5555'` | 同上 **§2 表 `journalctl -u droidloomd -b` 行 + `宿主 adb devices -l` 行** | `journalctl -u droidloomd -b` |
| 2 | 探针今日三端点 http+https 全 `204` | 同上 **§2 表「宿主直连探针（`curl --noproxy '*'`）」行** | `curl --noproxy '*' …/generate_204` |
| 3 | `202.38.64.18` 可解析；`1.1.1.1/8.8.8.8/223.5.5.5/114.114.114.114` 全 `connection timed out` | 同上 **§2 表「宿主 `busybox nslookup <域> <DNS>`」行** + §0-3 | `busybox nslookup <域> <DNS>` |
| 3 | TCP `8.8.8.8:853`、`223.5.5.5:853/443` BLOCKED；DoH 域名 https 200 | 同上 **§2 表同行的「判读」列** | 同轮只读探测 |
| 3 | 「先改 DNS 再解禁」的顺序；仅称未复测 +79 s | 同上 **§4 开头**（「顺序很重要：先修 DNS（②），再解禁（①）」）与 §0-3 | — |
| 4a | `captive_portal_{http,https,fallback}_url = wifi.vivo.com.cn/generate_204` | 同上 **§4 ②-1 代码块** + §8-1 | `cmd settings put global …` |
| 4a | `connect.rom.miui.com` 返 **200** 会被当 portal | 同上 **§4 ②-1 代码块内「注意：」行** | — |
| 4b | 独立 nft 表 `ip dl_dns_redirect`（prerouting，`iifname dlh1001 ip saddr 10.177.0.2 udp dport 53 dnat to 202.38.64.18`）；写进 `droidloom_u1001*` 会随 cell 删除 | 同上 **§4 ①-[1]** + **§8-2** | `nft add table/chain/rule …` |
| 4c | `cmd wifi connect-network "Droidloom" open` | 同上 **§4 ①-[2]** + §8-3 | `nsenter … cmd wifi connect-network` |
| 4 | 恢复后：`wlan0 10.177.0.2/30`、`Active default network: 100 … IS_VALIDATED`、`adb devices -l` → `10.177.0.2:5555 device … device:droidloom` | 同上 **§8「结果（判据逐条命中）」** | — |
| 5 | 重 boot 后 `nft list ruleset \| grep -c dl_dns_redirect` = 0；`journalctl -b \| grep -c droidloom` = 0；`graphical-session.target` inactive | 同上 **§9 表第 1/2 行** | `nft list ruleset`、`journalctl -b`、`systemctl is-enabled` |
| 5 | `captive_portal_*` 落在 `/data/system/users/0/settings_global.xml` 故不随宿主重启丢 | 同上 **§4 ②-1**；`reports/droidloom-upstream-lane-20261126.md` §「captive-portal 探针」行（「不丢（在 Android data 里）」） | — |
| 5 | 重 boot 后两侧 /30 都在但 `ping 10.177.0.2` 100% 丢包、adb 无端点 | 同上 **§9 表第 3 行** | `ping 10.177.0.2`、`adb devices` |
| 6 | 51 仍：`development_network.rs:33` `dns: [1,1,1,1]/[8,8,8,8]`（含上方注释）；`WifiProvisioning.java:42` 一次性 `DONE` 早退、`:82` `enableNetwork(id,false)` | **仓外一手核对（只读）**：`tar -xzOf ~/dl-droidloom-51/droidloom-source-0.1.0-51.tar.gz droidloom/runtime/droidloom-supervisor/src/development_network.rs \| grep -n "1, 1, 1, 1"` → `33:`；`… /WifiProvisioning.java \| grep -n "getBoolean(DONE\|enableNetwork"` → `42:` `82:`；同源判定见 `droidloom-upgrade-51-ime-20261127.md` §1（资产路径）与 `droidloom-local-patches-20261127.md`（base = 51 源码包） | `tar -xzOf`（不写盘） |

**报告间冲突的取舍**：`cell-network` 内部 §8（「已修」）与 §9（「重 boot 后全丢 + 链路不通」）钟点标注互相矛盾（§8 写 18:2xZ、§9 写 14:0x–14:2xZ）；按「§9 = 明确陈述的重启后复核」取为更晚事件，评论里**不引用任何钟点**，只写命令与输出。

## 二、哪些数字我们没有 —— 所以没写

| 未写的内容 | 为什么 |
|---|---|
| `counter:2` / 「+79 s 再次永久禁用」的我方独立测量 | 仓内只有「#48 报告者实测」（`cell-network` §0-3）这一条二手归属，无本机日志。评论里明确标注「我未复测，先修了 DNS」，不冒充我方数据 |
| cell 内 `PROBE_HTTP … ret=204` / `PROBE_HTTPS … SocketTimeoutException` / `isPartialConnectivity()` / `ConnectivityService: [100 WIFI] validation failed` | 本仓无这些 cell 侧探针原文（`cell-network` §2 未采集该类行）。这些串仅出现在 #48 原帖与 `droidloom-upstream-lane-20261126.md` §86-87 的引用里，**不是我方输出** |
| `dumpsys netd` 的 `1.1.1.1 (15, 0, 0, …) BROKEN` 计数 | 同上：仓内只作为「修好后应满足的判据」出现（`cell-network` §5-3），从未采集过实际输出 |
| `IS_VALIDATED` 的完整 `dumpsys connectivity` 原文 | §8 只有带 `…` 的摘要引用，无整段原文 ⇒ 评论沿用摘要措辞，不额外补字段 |
| 内核版本 | 两份必读报告不一致：`droidloom-deploy-20261126.md` 记 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`，`droidloom-upgrade-51-ime-20261127.md` 记 `…-g4da9a8b69fc8`，且无法判定取证窗口用的是哪颗 ⇒ 整条省略 |
| 「在 0.1.0-51 上复现」 | 升级报告只判 `droidloomctl status`/doctor/IME，**未重测网络与 adb** ⇒ 只声称「51 源码未变」（源码级，可复核），不声称「51 上实测复现」 |
| 校园网 resolver 的上游/DoH 具体域名与响应体 | 仓内只记「DoH 域名 https ✓(200)」，无域名与内容 ⇒ 不写 |
| phoc 版本 `0.58` + 本地 syncobj patch | 只出现在 `reports/droidloom-upstream-cluster-20261127.md` §4 草稿（非带原始日志的报告）；`droidloom-deploy-20261126.md` 只记「phoc/phosh 各 1」⇒ 环境行只写 phoc/phosh |
| `dhcp_responder.rs` 作为 DNS 硬编码位置 | 该文件 `:434` 的同一串在 `#[cfg(test)] mod tests` 里（测试常量），真实值在 `development_network.rs:33` 的 `LEASE` 常量 ⇒ 评论指向 `development_network.rs`（与原帖一致），不用 `dhcp_responder.rs` |
| 我方本地 patch / fork 应用建议 | 按派工单要求不推销；评论只陈述「51 源码里这两处仍是原样」，不提本仓规避件 |
| IME / launch 卡死 / Limbus 等其它缺陷 | 与本 issue 无因果交集（`droidloom-upstream-cluster-20261127.md` §3 判「不碰」） |

## 三、自检（只读 / 无发布动作）

```sh
cd /home/xuqianhui/y700-elden
timeout -k 10 60 gh issue view 48 -R denialwm/droidloom --json title,body,comments   # 读到，comments=0
wc -l reports/artifacts/droidloom-48-comment-20261127/body.md                        # 31 ≤ 60
git status --porcelain reports/artifacts/droidloom-48-comment-20261127/               # 仅本目录两个未跟踪文件
```

- **未执行**：`gh issue comment`、任何 `git commit`/`push`、任何设备写入。
