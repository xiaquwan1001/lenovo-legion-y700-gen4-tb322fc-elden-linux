# WiFi 候选榜塌成只剩已连接那一项 — 根因与修复（2026-10-19, U2 vk127）

**现象（用户报）**：WiFi 能正常连着，但「可用候选列表」里只有当前连着的那个网络；
手动关开 WiFi 一次（或断开再连）候选榜才正常。日常不影响使用，只在系统首次上机前后明显。

**结论（一句话）**：不是 ath12k/固件问题，也不是 NM 的 bug 而是**上游设计**——
NetworkManager 在**已连接**状态下**禁止自己做周期扫描**，把复扫交给 wpa_supplicant 的
`bgscan`；而 NM 把 `bgscan` **写死**成 `simple:30:-70:86400`（信号好于 -70 dBm 时 long 档 =
**86400 s**）⇒ 连通态实际上不再扫描 ⇒ supplicant 的 BSS 缓存按 age（默认 180 s）过期被清
⇒ NM 移除 AP 对象 ⇒ 候选榜只剩当前连接项。**已用「连通态每 150 s 显式 RequestScan」修复并上机验证。**

---

## 1. 根因链（源码 + 实测互为印证）

### 1.1 源码（NetworkManager 1.52.2，设备实际版本）

| # | 位置 | 事实 |
|---|---|---|
| ① | `src/core/devices/wifi/nm-device-wifi.c` → `_scan_notify_allowed()` | `state == NM_DEVICE_STATE_ACTIVATED` 分支写死 `periodic_allowed = FALSE`，注释原文：*"Prohibit periodic scans when connected; we ask the supplicant to background scan for us"* |
| ② | `src/core/supplicant/nm-supplicant-config.c` → `nm_supplicant_config_add_bgscan()` | `bgscan` **不看连接属性、直接写死**：`simple:30:-70:86400`；只有 `num_seen_bssids > 1`（多 BSS 的 ESS）或 EAP 才换成 `simple:30:-65:300` |
| ③ | 同上全树 grep `bgscan` | 1.52.2 里**没有任何**配置项能改这个串（`nm-supplicant-settings-verify.c` 里 `bgscan` 只是白名单），连接级 `802-11-wireless.bgscan` **不被读取** ⇒ 改连接属性无效 |

`simple:<short>:<signal>:<long>` 语义：信号 **低于** `<signal>` 阈值时每 `<short>` 秒扫一次，
**高于**阈值时每 `<long>` 秒扫一次。本机连手机热点，RSSI **-29 ~ -39 dBm**（远优于 -70）
⇒ 走 long 档 = 86400 s（24 h）。

### 1.2 设备实测（本次复现）

环境：`7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`、NM 1.52.2、`wpa_supplicant -u`（D-Bus，
无独立 ctrl socket）、热点 SSID `P40 Pro`（ch6，单 BSS）、`iw dev wlan0 get power_save` = **off**。

| 观测 | 数值 |
|---|---|
| `rc-service networkmanager restart` 后 | 只做 **1 次**扫描（`scan started` +1.27 s，`scan finished` +5.6 s，110 信道全扫），+6.5 s 关联成功 |
| 其后 120 s（无 UI、无 SSH） | **0 次** `scan started` / **0 次** sched-scan 事件 |
| 再 150 s 静置窗口 | 仍然 **0 次**扫描；候选 AP **35 → 1**（只剩 `P40 Pro`，SIGNAL 82） |
| 对照（有 UI 客户端在线时） | 20 次扫描 / 300 s（15 s 节奏）——**是客户端主动 RequestScan**，不是 NM 自扫 |
| `nmcli dev wifi rescan` | **1 → 24** 项，12 s 内（与用户「手动关开一次就恢复」一致） |
| `nmcli dev wifi rescan` 后 AP 数长期 | 若无人再请求扫描，又会按同样节奏塌回 1 项 |

> 注：`wpa_supplicant` 侧清缓存的默认参数是 `bss_expiration_age`（180 s）与
> `bss_expiration_scan_count`（2 次扫描）；无扫描时按 age 过期，NM 收到 `bss removed`
> 就删掉对应 AP 对象。这解释了 35 → 1 的时间尺度。

### 1.3 为什么「首次上机前后」最明显

首次上机时 `wlan0` 上来得晚（ath12k WCN 首探 11.7 s 成功 / 慢发 23 s，见 `PITFALLS` §34–§35），
NM 的连接期扫描往往只拿到「热点那一次快照」附近的结果，而之后连通态不再自扫；
用户第一次去开 WiFi 面板时看到的正是这份快照随时间被清空后的残局。
日常用起来「不影响」是因为一旦有 UI 打开面板（客户端 RequestScan）就会补回来。

---

## 2. 修复

**做法**：连通态用 NM 的**显式**扫描路径补周期复扫（源码 ① 只禁 `periodic`，`explicit` 在
ACTIVATED 下仍允许，只要 supplicant 不在关联握手中）。

| 组件 | 位置 | 说明 |
|---|---|---|
| 脚本 | `scripts/wifi-scan-refresh.sh` → 设备 `/usr/local/sbin/wifi-scan-refresh.sh` | `--loop`（服务）/`--once`/`--check`；只在 `wlan0` 已连接时扫；未连接/设备未就绪时**每 15 s 重试**（不耗射频，覆盖开机上电窗口），那条路径 NM 自己按 ≤120 s 扫（`SCAN_INTERVAL_SEC_MAX`） |
| OpenRC 服务 | `rootfs/persistent-overlay/etc-initd-wifi-scan-refresh` → `/etc/init.d/wifi-scan-refresh` | `supervise-daemon`，`respawn_delay=30 respawn_max=0`，日志 `/var/log/wifi-scan-refresh.log` |
| 参数 | `rootfs/persistent-overlay/etc-conf.d-wifi-scan-refresh` → `/etc/conf.d/wifi-scan-refresh` | `WIFI_SCAN_INTERVAL=150` |

**为什么是 150 s**：必须 **小于 supplicant 的 `bss_expiration_age`(180 s)**，否则缓存照样过期；
本机全信道扫描实测 **5.6–8.4 s / 110 信道** ⇒ 150 s 档约 **4–6 %** 占空比。
想省电可调到 170（贴上限），要更实时可设 120。

**为什么不改 NM**：②/③ 说明 1.52 没有可用旋钮（连接属性 `bgscan` 不被读取），
改 `nm-supplicant-config.c` 需要重编 NM 包，收益/维护成本不划算。

---

## 3. 上机验证（U2，2026-10-19）

| 判据 | 结果 |
|---|---|
| 服务在跑 | `rc-service wifi-scan-refresh status` = started；pid 存活 470 s |
| 扫描节奏 | `iw event` 捕获到扫描在 **+0 s / +150 s**；服务日志连续 4 轮（interval=150s） |
| 候选榜不再塌 | 服务运行期间 `aps` = **24 → 27 → 26 → 22 → 26 → 28**（全部 >1） |
| 未连接不叠加 | 断开后 `--once` → 日志 `wlan0 state=disconnected — skip (NM self-scans)`；断连状态下重启服务，40 s 内 **3 次** 15 s 重试（开机窗口等价）；重连后 `connected`、aps=35 |
| 幂等/自恢复 | `supervise-daemon` 托管；`kill -9` 子进程后 **~6 s** 重启（`respawn_delay=5`）；`rc-update add wifi-scan-refresh default` 已置位 |

**边界**：本次只验证「连通态候选榜不塌」；`SIGNAL` 数值仍会随扫描刷新，
面板若在两次扫描之间打开，最多滞后 150 s（可调小）。

**运维注意**：`/run/wifi-scan-refresh.pid` 是 **supervise-daemon 自己的 pid**（不是子进程，
`PITFALLS` #357）——判活动它要 `pgrep -f 'wifi-scan-refres[h].sh --loop'`，
杀这个 pid 会留下孤儿进程并让 `rc-service status` 变成 `unsupervised`。

---

## 4. 复现/验收配方（下次直接用）

```sh
# 反例（证明会塌）：让 NM 静置，不碰 UI，仅观察
rc-service networkmanager restart && date +%s
timeout 300 iw event -t | grep -E 'scan (started|finished)'    # 期望：只有连接期那 1 次
nmcli -f BSSID dev wifi list --rescan no | grep -cE '^[0-9A-F]{2}:'   # 期望：约 3 分钟后跌到 1

# 正例（修复后）
/usr/local/sbin/wifi-scan-refresh.sh --check    # aps / state / interval
grep -c 'requested scan' /var/log/wifi-scan-refresh.log
```

**判据**：连通态下 `iw event` 每 ~150 s 必须有一次 `scan started`；
`nmcli dev wifi list --rescan no` 的 BSSID 数不得跌到 1（除非环境里确实只有一个 AP）。
