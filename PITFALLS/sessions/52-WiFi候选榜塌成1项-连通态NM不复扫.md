# 五十二、WiFi 候选榜塌成只剩已连接项 = 连通态 NM 不复扫（bgscan 86400 s）

日期 2026-10-19 | 设备 U2 `7.3.0-rc7-debug-vk127` | 完整报告 `reports/wifi-scan-stale-20261019.md`
修复 `scripts/wifi-scan-refresh.sh` + OpenRC 服务 `wifi-scan-refresh`（`TASKS` G1-36）

**一句话**：连通态下 NetworkManager **不做**周期扫描（`periodic_allowed=FALSE`），把复扫交给
wpa_supplicant 的 `bgscan`，而 NM 把该串**写死**为 `simple:30:-70:86400` ⇒ 信号好于 -70 dBm 时
24 h 才扫一次 ⇒ supplicant 的 BSS 缓存按 age(180 s) 过期被清 ⇒ NM 删 AP 对象 ⇒ 候选榜只剩当前连接项。

---

## #354：连通态「候选榜只剩已连接那一个」= NM 自己不复扫 + bgscan 86400 s

**现象**：WiFi 连着、正常用；但可用网络列表里只有当前连着的 SSID。手动关开 WiFi 一次
（或断开再连）候选榜就恢复正常。首次上机前后最明显，日常几乎无感。

**根因链**（NM 1.52.2；源码 + 设备实测双向印证）：

```
NM 内部: _scan_notify_allowed()  ACTIVATED 分支 => periodic_allowed = FALSE
        （注释："we ask the supplicant to background scan for us"）
   ↓
NM 给 supplicant 写死 bgscan = "simple:30:-70:86400"
        （nm_supplicant_config_add_bgscan()；多 BSS ESS 才用 :300）
   ↓
信号 -30 dBm > -70 阈值 => 走 long 档 = 86400 s  => 连通态实际不再扫描
   ↓
wpa_supplicant BSS 缓存按 bss_expiration_age(180 s) 过期被清
   ↓
NM 收到 bss removed => 删掉 AP 对象 => 候选榜塌成 1 项
```

**实测（本机可重复）**：`rc-service networkmanager restart` 后只扫 1 次（+1.27 s 起，5.6 s 扫完
110 信道），随后 120 s 内 **0 次**扫描事件；再静置 150 s，候选 AP **35 → 1**；
`nmcli dev wifi rescan` 后 **1 → 24**（12 s）。有 UI 面板在线时看到的是 15 s 节奏——那是
**客户端 RequestScan**，别误判成「NM 有周期扫描」。

**判据 / 诊断三行**：

```sh
nmcli -f BSSID dev wifi list --rescan no | grep -cE '^[0-9A-F]{2}:'   # 跌到 1 且连着网 = 本 bug
timeout 150 iw event -t | grep -c 'scan started'                      # 0 = 连通态确实没扫
nmcli dev wifi rescan && sleep 12 && nmcli -f BSSID dev wifi list --rescan no | grep -cE '^[0-9A-F]{2}:'
```

**修复**：连通态每 **150 s** 显式 RequestScan（`explicit` 在 ACTIVATED 下仍允许，源码只禁
`periodic`）。间隔必须 **< 180 s**（supplicant 的 `bss_expiration_age`），150 s 档全信道扫描
（5.6–8.4 s）约 4–6% 占空比。未连接时**不要**叠加（那条路径 NM 自己按 ≤120 s 扫）。

---

## #355：别去改连接的 `802-11-wireless.bgscan` —— 1.52 里它不被读取

`nm-supplicant-config.c` 的 `nm_supplicant_config_add_bgscan()` **不看** connection 里的
`bgscan` 属性，直接把串写死（`simple:30:-70:86400` / 多 BSS 时 `simple:30:-65:300`）。
全树 grep `bgscan` 只有 3 处：白名单校验、函数本身、调用点。⇒
`nmcli connection modify X 802-11-wireless.bgscan ...` **完全无效**（改了看不到任何行为变化），
不要把时间花在这条路上；要么外挂周期 RequestScan，要么重编 NM。

同理：`/etc/wpa_supplicant/wpa_supplicant.conf`（含 `country=`、`network={}`）**不是** NM 用的那份
——NM 用 D-Bus 自己拉起 `wpa_supplicant -u`，该文件是遗留物，改它不生效。

---

## #356：静置观察「有没有周期扫描」必须排除 UI/SSH 客户端干扰

设备上同时跑着 phosh + `gnome-control-center --gapplication-service`，任一 UI 打开 Wi-Fi 面板
都会自己发 RequestScan（g-c-c 面板实测 **15 s** 一次，300 s 内 20 次扫描）。
在这种环境下抓 `iw event` 会看到「扫描很勤」，从而**掩盖**「NM 自己不扫」的事实。

**正确做法**：`setsid nohup` 起抓取（`iw event -t`）后**立刻断开 SSH**，等 2–5 分钟再连回来读文件；
或用 `nmcli general logging LEVEL=DEBUG` 之外的间接判据（AP 数随时间塌陷）。判定「谁在扫」时，
先问一句：**当时有没有 GUI 面板开着**。

---

## #357：OpenRC `supervise-daemon` 的 pidfile 记的是**它自己**，不是子进程

判活/排查时顺手 `kill -9 $(cat /run/<svc>.pid)` 会**杀掉 supervise-daemon**，留下孤儿
`--loop` 子进程照旧在跑；随后 `rc-service <svc> status` 显示 **`unsupervised`**，
看起来像「服务挂了但进程还在」，很容易误判成 initd 写错。

- `/run/<svc>.pid` = **supervise-daemon 的 pid**（实测 `pgrep -a supervise-daemon <svc>` 与之一致）。
- 要测重启韧性：`kill -9 $(pgrep -f '<svc>.<sh> --loo[p]')`（**方括号**防 `pgrep -f` 自匹配当前 shell，
  见 `PITFALLS` §pkill-self-match 技能）；实测 5 s `respawn_delay` 后新子进程起来、`status: started`。
- 干净复位：`rc-service <svc> stop` → 清 pidfile → `start`；不要在 supervise 活着时手工 kill 子进程之外的东西。
