# Waydroid 容器网络（代理共享）— 2026-10-02

> 状态：**达成**。Waydroid 容器内可访问 Google：默认路由已持久化、Android 全局 http_proxy
> 指向主机 Clash，Play Store 可正常加载到「Sign in」界面，GSF 完成 checkin（拉回 1500+ 条配置）。
> 未刷 boot；改动全部可在容器/设备文件层回退。

任务：`task-11`（NetPilot2）。需求：设备与主机同一 WiFi，让 Waydroid 容器内网络正常、可确认访问 Google。

---

## 0. 一句话结论

问题根因不在代理，而在**容器缺默认路由**：设备运行内核 `CONFIG_IP_ADVANCED_ROUTER` 未开，
Android netd 用 `ip rule`/多路由表下发 per-network 路由失败（静默），容器只剩 `192.168.240.0/24`
链路路由，出网即 `Network is unreachable`。修复分两步、均不刷 boot：

1. **默认路由**：bind-mount 一个改过的 init.rc（`blank_screen.rc` + 追加 `on property:sys.boot_completed=1`
   加 `ip route replace default via 192.168.240.1`），容器每次启动自动补路由。
2. **代理**：给容器设 Android 全局 `http_proxy = 主机Clash:7897`（经 adb 写，绕开 `waydroid shell`
   的 `settings put` NPE），存在容器 `/data`，随镜像持久。

---

## 1. 拓扑

```
                    WiFi "P40 Pro" 192.168.43.0/24
  ┌───────────────────────────┐        ┌──────────────────────────────┐
  │ 主机 (Ubuntu, x86_64)      │        │ 设备 elden (Alpine aarch64)   │
  │ Clash Verge 2.4.7          │        │ wlan0 192.168.43.x (DHCP)     │
  │ mihomo mixed-port 7897     │◄───────┤ default via 192.168.43.1      │
  │ allow-lan:true / bind '*'  │        │ usb0 192.168.7.1 (SSH/调试)   │
  │ wlp5s0 192.168.43.197      │        │ waydroid0 192.168.240.1       │
  └───────────────────────────┘        │   │ (dnsmasq DHCP)            │
              ▲                        │   ▼                           │
              │  HTTP CONNECT          │ ┌──────────────────────────┐  │
              │  (allow-lan)           │ │ Waydroid 容器 (Android 13)│  │
              └────────────────────────┤ │ eth0 192.168.240.112/24  │  │
                                       │ │ 全局 http_proxy 指向主机   │  │
                                       │ │ default via 192.168.240.1│  │
                                       │ └──────────────────────────┘  │
                                       └──────────────────────────────┘
```

- 主机代理：`192.168.43.197:7897`（Clash Verge Rev / mihomo，`allow-lan: true`、`bind-address: '*'`）。
- 设备 IP 会变（重启后 DHCP 重新分配，实测见过 `.78/.152/.129`），**代理配置只写主机 IP**，不受影响。
- 设备给的 `Clash Verge_2.4.7_amd64.deb` 是 **amd64**，设备是 **aarch64** → 不能装设备；本方案复用主机代理，
  因此设备上**无需**安装任何代理内核。

---

## 2. 根因证据

设备内核：`7.2.0-debug-gba28ec16f01f-dirty`。

```
$ zcat /proc/config.gz | grep CONFIG_IP_ADVANCED_ROUTER
# CONFIG_IP_ADVANCED_ROUTER is not set        # → CONFIG_IP_MULTIPLE_TABLES 连带关闭
```

容器修复前：
```
$ waydroid shell -- ip route
192.168.240.0/24 dev eth0 proto kernel scope link src 192.168.240.112   # 只有链路路由
$ waydroid shell -- ip rule
RTNETLINK answers: Operation not supported on transport endpoint        # 内核不支持多路由表
Dump terminated
```
netd 依赖 `ip rule`/多路由表下发 per-network 路由，内核不支持 → 默认路由缺失。

---

## 3. 做了什么（全部命令可复现）

### 3.1 设备侧验证「主机代理可达且能到 Google」
```bash
# 设备(root@192.168.7.1)：
ping -c2 192.168.43.197          # 通
nc -z -w4 192.168.43.197 7897    # PORT_OPEN
python3 -c 'import urllib.request;
h=urllib.request.ProxyHandler({"http":"http://192.168.43.197:7897","https":"http://192.168.43.197:7897"});
print(urllib.request.build_opener(h).open("https://www.google.com",timeout=12).status)'
# → 200      （直连同一 URL 超时，符合被墙预期）
```

### 3.2 默认路由持久化（不刷 boot；bind-mount 改过的 init.rc）
原理：LXC 会把 `config_nodes` 里的 `lxc.mount.entry` bind 到容器；`/system` 只读，所以**覆盖一个已存在的
init.rc 文件**（选 `blank_screen.rc`，保留原内容后追加我们的 action）。LXC 不支持 `lxc.hook.post-start`
（本版本），故用 init.rc 方案。

设备文件：`/root/wd/blank_screen.rc`（= 原文件 + 追加块，见 `net/waydroid-proxy/blank_screen.rc`）
```ini
service blank_screen /system/bin/blank_screen
    user system
    oneshot
    group system
    shutdown critical

# NetPilot2 task-11: kernel lacks CONFIG_IP_ADVANCED_ROUTER → netd can't add default route
on property:sys.boot_completed=1
    exec - root -- /system/bin/sh -c "sleep 3; for i in 1 2 3 4 5 6 7 8 9 10; do /system/bin/ip route replace default via 192.168.240.1 dev eth0 && exit 0; sleep 2; done"
```
追加到 `/var/lib/waydroid/lxc/waydroid/config_nodes`：
```
lxc.mount.entry = /root/wd/blank_screen.rc system/etc/init/blank_screen.rc none bind,create=file,optional 0 0
```
> 注意：`/system/etc/init/` 只读，不能 `create=file` 造新文件（试过挂 `zz-waydroid-route.rc` 会静默跳过）；
> 必须覆盖**已存在**的文件。

### 3.3 容器全局 http_proxy
`waydroid shell -- settings put ...` 会抛 `NullPointerException`（AppOpsService.checkPackage 缺 calling
package）。绕法：容器内有 adbd（`init.svc.adbd=running`，`[::]:5555`），用 **adb** 写。
```bash
# 设备(root@192.168.7.1)：
apk add --no-cache android-tools            # 设备无 adb，装一个
# 把设备 adb 公钥注入容器，adbd 需鉴权：
cat /root/.android/adbkey.pub | waydroid shell -- sh -c \
  'mkdir -p /data/misc/adb; cat >> /data/misc/adb/adb_keys'
waydroid shell -- setprop ctl.restart adbd
adb connect 192.168.240.112:5555
adb -s 192.168.240.112:5555 shell settings put global http_proxy 192.168.43.197:7897
# 冗余/信息性（Waydroid 自身 prop）：
waydroid prop set persist.waydroid.http_proxy 192.168.43.197:7897
```
全局 `http_proxy` 存于容器 `/data/system/users/0/settings_global.xml`（在持久 rootfs 上），重启后仍在。

---

## 4. 验证证据（重启后重新拉起容器，全部自动生效）

设备重启后**不手动加任何路由**，仅启动 Waydroid：

| 检查 | 命令 | 结果 |
|---|---|---|
| 容器状态 | `waydroid status` | Session/Container **RUNNING**，IP `192.168.240.112` |
| 默认路由（自动） | `waydroid shell -- ip route` | `default via 192.168.240.1 dev eth0` ✅ |
| 代理设置持久 | `waydroid shell -- settings get global http_proxy` | `192.168.43.197:7897` ✅ |
| Waydroid prop | `waydroid shell -- getprop persist.waydroid.http_proxy` | `192.168.43.197:7897` ✅ |
| 出网(直连) | `curl -w %{http_code} http://mirrors.ustc.edu.cn` | `301`（路由通） |
| Google(代理) | `curl -x http://192.168.43.197:7897 https://www.google.com` | **`200`** ✅ |
| Google(直连) | `curl https://www.google.com` | `000`（被墙，符合预期，故必须走代理） |
| 主机侧连接 | 主机 `ss -tn \| grep 192.168.43` | 多个容器→`192.168.43.197:7897` ESTAB ✅ |
| **GSF checkin** | `sqlite3 .../gservices.db "select count(*) from main"` | **1530 行**（服务端下发配置）→ 已联到 Google ✅ |
| **Play Store UI** | 截图 `net/waydroid-proxy/evidence-playstore-loaded.png` | 已加载到「Google Play / Sign in」界面 ✅ |

- GSF android_id：`4084430036205227526`（hex `38aecf7a49f2ce06`）——用于后续未认证设备注册。
- 另一张 `evidence-playstore-signin.png` 是 GMS 登录流程「Checking info…」界面（Google 应用已联网）。

> 注意：GSF checkin 能成功，是因为全局 http_proxy 对 Java 网络栈生效（gservices.db 从只有 1 行 `digest`
> 变成 1530 行服务端配置）；FCM/MTalk 走裸 socket 不走 HTTP 代理，仍会报 `Error retrieving FCM instance id`，
> 属正常现象，不影响登录/下载。

---

## 5. 如何回退

```bash
D=root@192.168.7.1
# 1) 去掉默认路由 bind-mount
ssh $D "sed -i '/blank_screen.rc/d' /var/lib/waydroid/lxc/waydroid/config_nodes"
# 2) 清空全局代理
ssh $D "adb -s 192.168.240.112:5555 shell settings put global http_proxy :0"   # 或  settings delete global http_proxy
ssh $D "waydroid prop set persist.waydroid.http_proxy ''"
# 3) 重启容器
ssh $D "waydroid session stop; waydroid container stop; waydroid container start; waydroid session start"
```
`config_nodes` 备份：`/var/lib/waydroid/lxc/waydroid/config_nodes.bak-<epoch>`。
adb 公钥注入：删除容器 `/data/misc/adb/adb_keys` 中追加的那行即可（可选）。

---

## 6. 遗留问题 / 建议

1. **根治方案（推荐后续做）**：内核开 `CONFIG_IP_ADVANCED_ROUTER=y`（连带 `CONFIG_IP_MULTIPLE_TABLES=y`）
   重编 boot 刷入。这样 netd 恢复正常，不再需要 bind-mount init.rc 补路由，VPN/按应用路由等也一并可用。
   需要刷 boot，须与音频 task-8 协调设备锁。
2. **代理只覆盖尊重系统代理的应用**（Play Store / GSF / 大部分 Java 网络）。裸 socket（FCM push、部分游戏）
   不走 HTTP 代理；如需全覆盖，需在主机 Clash 开 TUN 并对 `192.168.240.0/24` 做 SNAT（需主机 sudo），
   或在设备上跑透明代理。
3. **DNS 仍被污染**：容器直连解析 `www.google.com` 会得到 GFW 投毒 IP（实测 `69.171.235.22`）。
   HTTP 代理下由代理侧解析域名，不受影响；但直连域名的应用会失败。
4. **Play Protect 未认证**：GSF id `38aecf7a49f2ce06` 需去
   https://www.google.com/android/uncertified 注册；Play Integrity `DEVICE/STRONG` 在无 TEE 的 Waydroid
   上不可达（详见 `GPLAY-2026-10-02.md §4`）。
5. **设备 IP 漂移**：设备 wlan0 每次重启 DHCP 变（`.78/.152/.129`）。设备侧脚本 SSH 用 USB `192.168.7.1`
   最稳。

---

## 7. 资产清单

| 资产 | 路径 |
|---|---|
| 本任务文档 | `~/y700-elden/PROXY-WAYDROID-2026-10-02.md` |
| 改过的 init.rc 模板 | `~/y700-elden/net/waydroid-proxy/blank_screen.rc` |
| 一键配置脚本（主机→设备） | `~/y700-elden/scripts/waydroid-proxy-setup.sh` |
| Play Store 加载截图 | `~/y700-elden/net/waydroid-proxy/evidence-playstore-loaded.png` |
| GMS 登录「Checking info」截图 | `~/y700-elden/net/waydroid-proxy/evidence-playstore-signin.png` |
| 设备端文件 | `/root/wd/blank_screen.rc`、`/var/lib/waydroid/lxc/waydroid/config_nodes(+bak)` |
| 设备端日志 | `/root/wd/proxy-*.log`、`final-*.log` |
| 相关前置文档 | `GPLAY-2026-10-02.md`（GAPPS 安装/认证）、`WAYDROID-2026-10-01.md`（容器基线） |

## 8. 用法速记（用户视角）

```bash
# 设备上，正常启动 Waydroid 即可，路由/代理自动生效：
waydroid session start
# 容器内自测：
waydroid shell -- curl -x http://192.168.43.197:7897 https://www.google.com   # → 200
```
