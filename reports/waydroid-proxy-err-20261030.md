# Waydroid 容器内浏览器 `ERR_PROXY_CONNECTION_FAILED` — 只读取证

- 日期：2026-10-30（采集窗 11:2x，单次采样，全程只读）
- 设备：`root@192.168.7.1`，在机内核 `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172 #28`
- 容器：`Session RUNNING / Container FROZEN`（省电态，`sys.boot_completed=1`），`waydroid0` 容器 IP `192.168.240.112`
- 所有设备命令经 `scripts/device-lock.sh`，单条 `timeout -k 5`(<60 s)；**未写设备文件、未改 Waydroid 配置、未启停任何服务**
- 关联：`TASKS/README.md` §5（2026-10-30 条目）、同表 C2 行（容器代理上位结论）、`reports/wd-net-baseline-20261011.md`、`archive/topics/PROXY-WAYDROID-2026-10-02.md`

> 约束遵守：本文件不含任何代理凭据、订阅链接、账号。Clash/Bettbox 配置仅记录 `allow-lan`/`bind-address`/`mixed-port` 三个非敏感键。

---

## 0. 结论（先行结论，证据见 §1–§3）

**根因成立（设备侧直接证据）：容器全局代理指向 `192.168.7.9:7897`，而该端口在宿主侧根本没有监听进程 ⇒ TCP `Connection refused` ⇒ Chromium 网络栈报 `ERR_PROXY_CONNECTION_FAILED`。**

- 容器 `settings get global http_proxy` = **`192.168.7.9:7897`**（`global_http_proxy_host/port` 同值，PAC 与排除表均为空串）。
- 宿主 `ss -lntp` 无 `7897` 监听；容器实测 `nc 192.168.7.9 7897` → `nc: connect: Connection refused`（对照组 `192.168.7.9:22` → `SSH-2.0-OpenSSH_10.2p1`，证明链路本身通）。
- 暴露 7897 的既有手段 `scripts/host-net-proxy.sh`（`systemd-socket-activate`+`socket-proxyd` **7897 → 127.0.0.1:7890**）**当前未运行**：`/tmp/elden-host-net-proxy.{pid,log}` 均不存在。
- 底层代理（Bettbox/mihomo）只监听 **`127.0.0.1:7890`**，且 `allow-lan: false` ⇒ 即便把容器代理改成 `192.168.7.9:7890` 也**不通**（实测 refused），所以「只改端口号」不是可行修法。

**三类判定**：容器网络不通 = **否证**；代理指向不存在端口 = **成立（唯一被支持的根因）**；代理只听 127.0.0.1 = **成立（同一失效链的第二段，解释了为何不能改指 7890）**。

**未修复**：本条只做定位与建议，未做任何配置变更，故不写「已修复」。

---
## 1. 宿主侧取证（x86 主机 `/home/xuqianhui`）

### 1.1 代理环境变量（有，且为 loopback）

命令：`env | grep -iE '(^|_)https?_proxy|all_proxy|no_proxy'`

```
no_proxy=localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,ustc.edu.cn,edu.cn,...
https_proxy=http://127.0.0.1:7890
http_proxy=http://127.0.0.1:7890
ALL_PROXY=http://127.0.0.1:7890
```

来源：`~/.bashrc:148-151`（`export http_proxy=$_proxy_url …`，`_proxy_url` 为 `http://127.0.0.1:7890`）。
⇒ 宿主 shell 变量只影响宿主进程，**不会**下发到容器；容器代理是 Android 侧 `settings global http_proxy` 独立配置。

### 1.2 PAC / 自动代理

命令：`echo $AUTO_PROXY_URL`、容器侧 `settings get global global_proxy_pac_url`
⇒ 两侧**均为空**。**PAC 不是本故障因素**。

### 1.3 监听端口（关键证据：无 7897）

命令：`ss -lntp`

```
LISTEN 0 4096 127.0.0.1:7890  0.0.0.0:*
LISTEN 0 4096 127.0.0.1:9090  0.0.0.0:*
LISTEN 0 4096 127.0.0.1:4000  (litellm)
LISTEN 0 4096 127.0.0.1:29100 (aria2-next)
LISTEN 0 4096 127.0.0.1:29110 (rayburst)
LISTEN 0 128 127.0.0.1:5037  (adb)
LISTEN 0 4096 0.0.0.0:22, *:3389, *:1704, *:1705, *:1780 ...
```

`ss -lntpe | grep -E ':7890|:9090|:7897'`：

```
127.0.0.1:9090 uid:1000 cgroup:...app-gnome-Bettbox-5724.scope
127.0.0.1:7890 uid:1000 cgroup:...app-gnome-Bettbox-5724.scope
```

⇒ 代理 = **Bettbox（mihomo 系）GUI 进程**，`mixed-port 7890`，**仅绑 loopback**；**全机无 `7897` 监听者**（`grep :7897` 无输出，`ss -lntp` 全表也没有）。

### 1.4 Bettbox 关键配置（非敏感三键）

命令：`grep -nE '^(allow-lan|bind-address|mixed-port|mode)' ~/.local/share/com.appshub.bettbox/profiles/*.yaml`
与运行时 `curl -s --noproxy '*' http://127.0.0.1:9090/configs`

```
mixed-port: 7890
allow-lan: false          <-- LAN 客户端一律拒绝
bind-address: '*'
mode: rule
tun.enable: false
```

⇒ **`allow-lan: false`**：即使 `bind-address: '*'`，mihomo 也只接受本机连接。故必须由宿主侧自建 7897 中继（§4 方案 A），或改这一项（方案 B）。

### 1.5 宿主自身连通性（对照组）

```
curl -I --noproxy '*' --max-time 8 https://www.google.com      -> curl: (28) Connection timed out
curl -I -x http://127.0.0.1:7890 https://www.google.com        -> HTTP/2 200
curl -I -x http://127.0.0.1:7897 https://www.google.com        -> curl: (7) Failed to connect ... 127.0.0.1:7897 (立即拒绝)
curl -sS -o /dev/null --noproxy '*' -w '%{time_connect} %{time_appconnect} %{http_code}' https://www.gstatic.com/generate_204
                                                              -> conn=0.042416 tls=0.140692 code=204
curl -sS -o /dev/null --noproxy '*' http://www.baidu.com       -> code=200
```

解读：宿主**直连并非全阻断**（gstatic 204、baidu 200 通；google.com 目标超时）；**7897 在宿主本机都是 refused**，与容器看到的完全一致 ⇒ 失效点在端口/中继，不在分流规则。

出口：`ip route show default` = `default via 192.168.42.129 dev enx027644563e50 metric 100`（手机 USB 共享）+ `via 114.214.176.1 dev eno1 metric 20500`（校园有线）。宿主对接设备的链路 = `enx021e5eede102 192.168.7.9/24`（即容器代理里的 `192.168.7.9`）。

---
## 2. 容器侧取证

命令统一形态：`scripts/device-lock.sh ssh root@192.168.7.1 'waydroid shell …'`（`waydroid shell` 只接受 argv 形态，多参数须加 `--`，否则 argparse 报 `unrecognized arguments`）。

### 2.1 代理配置（全局，指向 7897）

```
$ waydroid shell settings get global http_proxy
192.168.7.9:7897
$ waydroid shell settings get global global_http_proxy_host
192.168.7.9
$ waydroid shell settings get global global_http_proxy_port
7897
$ waydroid shell settings get global global_http_proxy_exclusion_list
(空)
$ waydroid shell settings get global global_proxy_pac_url
(空)
```

- **PAC = 空**，**排除表 = 空**（无 bypass，所以每次连接都走死代理）。
- `getprop | grep -iE 'proxy|dns'` → 只有 `[net.bt.name]: [Android]`、`[net.tcp_def_init_rwnd]: [60]`、`mdnsd` 与 `netd_native.dns_*` 调参项；**无 `http.proxy`、无 `net.dns1`**（Android 10+ 代理只走 `settings global`，DNS 由 netd resolver 管理，不落 props）。
- `sys.boot_completed` = `1`（容器已完整启动，排除「系统没起完」这类噪声）。

### 2.2 容器网络与解析（正常）

```
$ waydroid shell -- ip route
default via 192.168.240.1 dev eth0
192.168.240.0/24 dev eth0 proto kernel scope link src 192.168.240.112
$ waydroid shell -- ip -4 addr        -> eth0 192.168.240.112/24 (mtu 1400)
$ waydroid shell cat /etc/hosts       -> 仅 127.0.0.1 localhost / ::1 ip6-localhost
$ waydroid shell cat /etc/resolv.conf -> No such file (Android 正常形态，DNS 在 netd)
```

连通性（toybox `ping`/`nc`；注意 toybox `nc` **连接失败也返回 rc=0**，必须看 stderr 文本，不能看退出码——本轮先踩后纠，见 §5）：

```
$ waydroid shell -- ping -c 2 -W 2 192.168.240.1   -> 2 packets, 0% loss
$ waydroid shell -- ping -c 2 -W 2 192.168.7.9     -> 2 packets, 0% loss   (宿主 USB 侧 IP 可达)
$ waydroid shell -- ping -c 2 -W 2 8.8.8.8         -> 2 packets, 0% loss
$ waydroid shell -- nc -w 4 192.168.7.9 22   -> SSH-2.0-OpenSSH_10.2p1 Ubuntu-2ubuntu3.8   (TCP 通)
$ waydroid shell -- nc -w 4 192.168.7.9 7897 -> nc: connect: Connection refused              (代理端口死)
$ waydroid shell -- nc -w 4 192.168.7.9 7890 -> nc: connect: Connection refused              (改指 7890 同样死)
$ waydroid shell -- nc -w 4 192.168.240.1 7897 -> nc: connect: Connection refused
$ waydroid shell -- nc -w 4 192.168.7.9 9090 -> nc: connect: Connection refused              (对照组：非暴露端口也 refused)
```

**容器直连（绕代理）可用**：`printf 'GET / HTTP/1.0\r\nHost: www.baidu.com\r\n\r\n' | waydroid shell -- nc -w 6 www.baidu.com 80` → `HTTP/1.0 200 OK`。
⇒ 容器 DNS 解析 + 出网 + 宿主 NAT 全部工作，**唯一坏掉的是 7897 这个代理端点**。

### 2.3 系统级报错（不是浏览器独有）

`waydroid shell -- logcat -d -t 600 | grep -i proxy`（重启后 11:24 采样）：

```
11:24:27.083  793 2150 W AppLinksAsyncVerifierV2: Caused by: m1.ex: Exception in BidirectionalStream:
                net::ERR_PROXY_CONNECTION_FAILED, ErrorCode=11, InternalErrorCode=-130, Retryable=false
11:24:27.183 1322 1522 W A: Caused by: m1.hu: Exception in CronetUrlRequest:
                net::ERR_PROXY_CONNECTION_FAILED, ErrorCode=11, InternalErrorCode=-130, Retryable=false
11:24:31.097 / 11:24:35.101  (同签名重复)
```

⇒ 与用户报的文字**逐字一致**；`793` = GMS 进程、`1322` = 使用 Cronet 的进程 ⇒ 全系统 Chromium 网络栈都吃这条死代理，浏览器只是最先被注意到的界面。

### 2.4 容器内应用面

`waydroid shell pm list packages -3`（第三方）：`de.markusfisch.android.binaryeye`、`net.sourceforge.opencamera`、`com.henrikherzig.playintegritychecker`；系统侧仅 `com.android.webview`（无预装独立浏览器）。
⇒ 「容器内浏览器」= WebView/Cronet 系应用（Waydroid 官方镜像不自带浏览器 App）；**未证实**用户当时具体用的是哪个 App，但 §2.3 已证明该错误与具体 App 无关（GMS 同样报错），故不影响根因判定。

---

## 3. 判定层次：三选一

| 候选判定 | 证据 | 裁决 |
|---|---|---|
| ①容器网络本身不通 | `ping 8.8.8.8` 0% loss、`ping 192.168.7.9` 0% loss、`nc 192.168.7.9:22` 拿到 SSH banner、直连 `http://www.baidu.com:80` = **200**、`sys.boot_completed=1` | **否证**（容器网络/路由/DNS/宿主 NAT 均正常） |
| ②代理配置指向不存在的端口 | 容器 `http_proxy=192.168.7.9:7897`；宿主 `ss -lntp` **无 7897** 监听；容器 `nc 192.168.7.9 7897` = **Connection refused**；宿主本机 `curl -x 127.0.0.1:7897` = **refused** | **成立（唯一被支持的根因）** |
| ③代理进程只监听 127.0.0.1，容器看不到 | Bettbox/mihomo 仅 `127.0.0.1:7890`（`ss -lntpe` 显示 loopback + uid 1000）；配置 `allow-lan: false`；容器 `nc 192.168.7.9 7890` = **refused** | **成立（同一失效链的第二段）** |

**合成因果链**：`allow-lan: false` + 仅 loopback 监听（③） ⇒ 容器永不可能直连 7890 ⇒ 历史方案用 `host-net-proxy.sh` 在 `192.168.7.9:7897` 做中继，把流量转给 `127.0.0.1:7890` ⇒ **该中继本轮未运行**（`/tmp/elden-host-net-proxy.pid|.log` 不存在） ⇒ 7897 无监听（②） ⇒ 容器每个 HTTP(S) 请求被拒 ⇒ `ERR_PROXY_CONNECTION_FAILED`。

**两段都是必要条件**：只解决 ②（起中继）即可恢复；只解决 ③（开 `allow-lan`）并把容器指向 `:7890` 也可恢复，但要动用户代理配置，风险更高。

**未证实项（缺证据）**：
- 用户当时具体用哪个 App/哪个 URL（容器内无独立浏览器 App；`ERR_PROXY_CONNECTION_FAILED` 已在 GMS/Cronet 侧复现，但不等于复现了用户那一次操作）。
- 中继是「曾在 2026-10-27 起过、后被重启/登出清掉」还是「本轮从未起过」——`/tmp` 中无 pid/log 残留，**无法区分**（缺 journal/`/tmp` 清理时序）。
- 容器 WebView 是否还叠加 App 级代理（如 Binary Eye 自带设置）：未逐 App 检查 `shared_prefs`。

---
## 4. 修复建议（仅建议，本轮未执行任何变更）

排序原则：**单变量、可回退、先不动用户的代理配置**。

### 方案 A（首选，1 条命令，零配置改动）

1. 宿主执行：`scripts/host-net-proxy.sh`
   - 作用：`systemd-socket-activate -l 192.168.7.9:7897` + `systemd-socket-proxyd 127.0.0.1:7890`，把宿主 loopback 代理中继到 USB 侧 IP 的 7897。**不改 Bettbox/mihomo 任何配置**（`allow-lan: false` 保持原样）。
   - 幂等，已在跑只报告。
2. 验收（三个独立判据，全绿才算成立）：
   - `scripts/host-net-proxy.sh --check` → 退出码 0，`OK: 经 192.168.7.9:7897 取 generate_204 = 204`
   - 宿主：`curl -s -o /dev/null -w '%{http_code}' -x http://192.168.7.9:7897 https://www.gstatic.com/generate_204` → `204`
   - 容器：`scripts/device-lock.sh ssh root@192.168.7.1 'waydroid shell -- nc -w 4 192.168.7.9 7897'` → **不再** 出现 `Connection refused`；随后同一浏览器访问目标站，并做**直连对照**（`settings delete global http_proxy` 后同 App 再试，见方案 C 的回退动作）。
3. 回退：`scripts/host-net-proxy.sh --stop`（只 kill 自己的 pid，不碰 Bettbox）。容器侧配置**无需回退**（本来就没改）。
4. 固有缺点：`/tmp` 里的临时进程，**重启/登出即失效**——这正是本轮现状的成因。若要长期生效，第二步再单独立项：把同一条 `systemd-socket-activate`+`socket-proxyd` 组合固化成 **systemd user unit**（`~/.config/systemd/user/elden-host-net-proxy.service`，`WantedBy=default.target`），改动面仍只在宿主、仍不影响 Bettbox。**（此项未做，属独立变更，需单独立项验证）**

### 方案 C（临时对照/最小回退：关掉容器全局代理走直连）

- 改什么：容器侧 `settings delete global http_proxy`（等价于把 host/port 置空）；`global_http_proxy_host/port` 一并 `delete`。
- 依据：§2.2 已实测容器**直连可用**（`www.baidu.com:80` → 200、`ping 8.8.8.8` 0% loss）。
- 局限：**不是长期方案**——C2 上位结论与 §1.5 都显示境外目标直连不可用（宿主 `curl --noproxy https://www.google.com` 超时），GMS/Play 会退化。
- 回退：`settings put global http_proxy 192.168.7.9:7897`（改前先记原值，本轮原值已记录于 §2.1）。

### 方案 B（最后手段：放开 Bettbox 的 LAN 监听）

- 改什么：Bettbox 配置 `allow-lan: false → true`（`bind-address` 已是 `'*'`），然后容器代理改指 `192.168.7.9:7890`（或保持 7897 但没有中继则仍不通，故必须同时改端口）。
- **风险**：等于把可用代理开放给 `192.168.42.0/24`（手机共享网段）与 `192.168.7.0/24`（USB 链路）上的任意主机，属安全面扩大；且改的是用户的代理 App 配置。
- 回退：`allow-lan: true → false` + 容器 `settings put global http_proxy 192.168.7.9:7897`。
- 建议：**仅在 A 因故不可用时使用**，使用后立即回退。

### 不建议

- 在容器内装第二个代理客户端（叠加二层代理、且与既有 C2 通路冲突）。
- 把 `global_http_proxy_exclusion_list` 加 `192.168.7.0/24` 之类的「绕开」写法——那只让容器**绕过代理直连**，与方案 C 等价但更隐蔽。

### 顺带记录（非本 bug，不修）

- 宿主 `no_proxy` 与环境变量命名混用（`no_proxy` 与 `NO_PROXY` 同时存在、大小写各一份），只在宿主 shell 内生效，与容器无关。

---

## 5. 取证方法学与环境变化（可复现性）

### 5.1 命令清单（全部只读，经 `device-lock.sh`，每条 `<60 s`）

| 目的 | 命令 |
|---|---|
| 设备身份 | `scripts/device-lock.sh ssh root@192.168.7.1 'uname -v; cat /proc/sys/kernel/random/boot_id; uptime -s'` |
| 容器状态 | `... 'waydroid status'` |
| 代理配置 | `... 'waydroid shell settings get global http_proxy'`（另 4 键同理） |
| props | `... 'waydroid shell getprop' \| grep -iE 'proxy\|dns'` |
| 路由/地址 | `... 'waydroid shell -- ip route; waydroid shell -- ip -4 addr'` |
| hosts/resolv | `... 'waydroid shell cat /etc/hosts; waydroid shell cat /etc/resolv.conf'` |
| 连通性 | `... 'waydroid shell -- ping -c 2 -W 2 <ip>'`、`... 'waydroid shell -- nc -w 4 <ip> <port>'` |
| 直连 HTTP | `printf 'GET / HTTP/1.0\r\nHost: www.baidu.com\r\n\r\n' \| waydroid shell -- nc -w 6 www.baidu.com 80` |
| 系统报错 | `... 'waydroid shell -- logcat -d -t 600' \| grep -i proxy` |
| 宿主 | `env \| grep -i proxy`、`ss -lntp`/`ss -lntpe`、`ip route show default`、`curl --noproxy '*'`、`curl -x 127.0.0.1:7890/7897`、`grep -E '^(allow-lan\|bind-address\|mixed-port\|mode)' ~/.local/share/com.appshub.bettbox/profiles/*.yaml`、`curl 127.0.0.1:9090/configs` |

### 5.2 三条踩坑（本轮实际踩到，供后续复用）

1. **`waydroid shell` 不接受多参数**：`waydroid shell ping -c 2 -W 2 1.2.3.4` → `waydroid: error: unrecognized arguments`；必须 `waydroid shell -- ping -c 2 -W 2 1.2.3.4`。直接把带管道的整串塞进去则会 `lxc_attach … No such file or directory - Failed to exec "getprop | grep …"`（lxc-attach 不跑 shell）。
2. **toybox `nc` 连接失败仍返回 `rc=0`**：用 `nc … && echo OPEN` 会把 `Connection refused` 判成 OPEN（本轮首测四连全假阳）。**必须看 stderr 文本**（输出为空 = 真的连上）。
3. **设备在取证窗口内重启过**（非本次操作所致）：11:22 采集时 `uname -v = #28`（`…-vk172`）、`boot_id` 变更前；11:24 起 `ssh` 连续超时，复查 `uptime -s = 2026-10-30 11:23:59`、`uname -v = #1 SMP PREEMPT Fri Oct 30 11:22:59`、新 `boot_id 912f6d7b…`，即**换了一枚 11:22:59 构建的内核并冷启**。SSH 超时是重启而非链路故障（`ping 192.168.7.1` 0% loss、`ip route get` 正常）。
   - 影响评估：§2.1 代理设置**重启后原值不变**（`192.168.7.9:7897`），§2.2/§2.3 的关键判据在**重启后**复测仍一致 ⇒ 结论跨重启稳定。
   - 处置：本文件不追查该重启来源（可能是并行 lane 的 M8/U2 刷写与重启）；**提请父代理核对是否与并行设备任务冲突**（`TASKS/README.md` §5 记录的在机状态为 vk181-daily `#28`，与本轮末次观测到的 `#1 / 11:22:59` 不一致）。

### 5.3 设备收尾状态

只读采集，未写设备任何文件/未改配置/未启停服务；容器停在 `Session RUNNING / Container RUNNING`（采集时自然态），`http_proxy` 保持原值 `192.168.7.9:7897`。**故障仍在**（未修复）。

### 5.4 本报告的引用位置（待父代理执行，本轮不写 SSOT）

`TASKS/README.md` §5「2026-10-30 新增待办」第 1 条 `Waydroid 浏览器 ERR_PROXY_CONNECTION_FAILED` 应链到本文件（本轮按约束**未改** TASKS）。
