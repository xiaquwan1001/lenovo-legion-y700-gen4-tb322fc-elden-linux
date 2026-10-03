# 任务：让 Waydroid 容器内网络可用（代理共享），验证可访问 Google

你是 y700-elden 的网络集成工程师。工作目录 `~/y700-elden`。先读 `INDEX.md`、`SWARM-PLAN-2026-10-02.md`、`GPLAY-2026-10-02.md`。

## 需求（用户）
设备与主机在同一 WiFi。用户希望“安装代理并确认 waydroid 内网络正常”。

## 已核实的硬事实（先看，别重复走弯路）
- 用户给的 `~/下载/Clash Verge_2.4.7_amd64.deb` 是 **amd64**；而**设备是 aarch64（Alpine）**→ 该 deb **无法装到设备上**。
- **主机**（本机，Ubuntu 26.04 / x86_64）**已经装好并运行 Clash Verge 2.4.7**：`verge-mihomo` 监听 `mixed-port 7897`，配置里 `allow-lan: true`、`bind-address: '*'`。
- 主机 LAN IP：`192.168.43.197`（wlp5s0）。设备 wlan0：`192.168.43.78`（SSID `P40 Pro`）——**同网段**。
- 设备 side：`waydroid0 192.168.240.1`，Waydroid Session RUNNING、Container RUNNING（已装 GAPPS，Mesa 26.1.8）。
- 设备直连 Google 失败（`GOOGLE_FAIL`）。

## 目标
让 **Waydroid 容器内**能正常访问 Google（为后续账号登录/Play 商店铺路），并给出可复现配置。

## 建议路线（优先 A）
- **A. 复用主机 Clash（推荐）**：设备本来就能到 `192.168.43.197:7897`（allow-lan 已开）。先验证：在设备上 `curl -x http://192.168.43.197:7897 https://www.google.com`（若主机有 ufw/firewall，需放行 7897）。
  然后让 Waydroid 走它：`waydroid prop set persist.waydroid.http_proxy "192.168.43.197:7897"`（必要时重启 session/container），并在容器内验证。
- **B. 设备本地代理**：若 A 有障碍（如需要 TUN/透明代理），改装 **aarch64** 的代理内核（Clash.Meta/mihomo、sing-box）到设备，再把 Waydroid 指向 `127.0.0.1:<port>`。**不要**用 amd64 deb。

## 验证（必须给出证据）
1. 设备侧：到主机代理端口的可达性与 HTTPS 测试。
2. 容器侧：`waydroid shell` 内 `getprop persist.waydroid.http_proxy`、`wget/curl https://www.google.com`（或 `ping` + `getent hosts google.com`）。
3. 若能：在 Play Store 里确认能加载（截图/日志）。

## 交付物
- 文档 `PROXY-WAYDROID-2026-10-02.md`：拓扑图、改了什么、怎么验证、如何回退、遗留问题。
- 结论与命令证据写 `task progress` / `task done`。

## 设备纪律
- 本任务是**容器网络配置**，不刷 boot。改 Waydroid 前 `send SageYak` 报备（音频 task-8 可能正在刷 boot）。
- SSH 禁长 sleep，后台任务 `nohup ... &` 后短命令轮询。
- 若需要连主机：主机就是本机（`127.0.0.1` 是主机；`192.168.43.197` 是主机对设备的 LAN 地址）。

## 上一轮进度（2026-10-02，勿重做）
- 根因已定位：**内核缺 `CONFIG_IP_ADVANCED_ROUTER`（连带 `CONFIG_IP_MULTIPLE_TABLES` 关）** → Android netd 用 ip rule/多路由表下发 per-network 路由失败 → Waydroid 容器只有 `192.168.240.0/24` 链路路由，出网 `Network is unreachable`。
- 已验证：手动 `ip route add default via 192.168.240.1` 后，容器可 **CONNECT 主机 Clash 7897**（`200 Connection established`）；设备侧经 `192.168.43.197:7897` 得 204 OK。
- **接续（不刷 boot 优先）**：1) LXC 静态网关/route 或 overlay `init.rc` 持久化默认路由；2) 容器内有 adbd apex，可用 `adb` + `settings put global http_proxy` 绕过 `waydroid shell` 写入 NPE。若确实需要内核补 config 再刷 boot，先 `send SageYak` 报备。
