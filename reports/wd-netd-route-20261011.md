# C 线：Waydroid 容器 netd 路由失败 / 无默认路由 根因调查（2026-10-11）

> 任务派发：专线 C。设备 U2 root@192.168.7.1。**注意：本会话只读调查段被中途叫停**（主会话 POR 需设备），
> 核实段（c1pin 内核上 netd 行为、旧 workaround 失败点）未能在设备上重跑，标为「未证/推测」。
> 本文只报「命令 + 原始输出」；无日志支撑的结论一律标注。未改 TASKS/其它文档、未碰设备配置。

## 0. 结论（数字先行）

| # | 结论 | 依据等级 |
|---|---|---|
| 1 | **根因 = netd `RouteController` 初始化失败**：容器内 netd 在启动时向宿主内核下发 IPv4+IPv6 两条 fib rule，**IPv6 那条被内核拒**（`EAFNOSUPPORT, Address family not supported by protocol`），RouteController 把它当致命错误 → 整个 per-network 路由/规则体系不建立 | **已证**（设备 logcat 原文 + AOSP 源码路径） |
| 2 | **性质 = 内核 config 缺项**（`CONFIG_IPV6_MULTIPLE_TABLES` 一类），不是 Waydroid 集成 bug；netd 本身在跑（pid 73, uid 0, Seccomp=2） | 已证（行为）+ **推测（具体缺哪个 config，设备上 `zgrep /proc/config.gz` 无输出，无法核对该内核 config 清单）** |
| 3 | `No such device (code 19)` 与 table 99/1002 空 是根因的**下游结果**：RouteController 死 → netd 从不 register per-network 路由/表；ConnectivityService `networkAddRouteParcel` → ndc `addRoute` 找不到该 network | 已证（ndc 手测复现） |
| 4 | 手测：`ndc network create 99` → `400 createPhysicalNetwork() failed (Invalid argument)` —— netId 99 越界（AOSP netd 的 per-network netId 从 100 起）；容器真实 network 是 **100**（fwmark `0x10064`=100 | 0x1ffff → lookup 1002） | 已证（输出）；netId 起点=推测（AOSP 常识） |
| 5 | c1pin（开 IP_ADVANCED_ROUTER）把旧 workaround（无 onlink 的 `ip route replace default`）弄坏 | 事实已证（派发词）；**机制未证**——设备窗口被收，未能在 c1pin 上重跑定位 |
| 6 | 国内网路径：宿主有真出网（baidu=200、DNS 正常），容器目前连 192.168.240.1 都 `Network is unreachable` ⇒ **当前不可行**；修根因后 NAT 通路即通（宿主 MASQUERADE 192.168.240.0/24 在、ip_forward=1），但需改容器 DNS（waydroid 镜像默认 8.8.8.8 被墙） | 已证（现状）；修复后通路=推测 |

## 1. 设备实测证据（原始输出，只读段）

> ⚠️ **父代订正（2026-10-11 21:5x，主会话直测）**：本节 logcat 时间 `13:16Z`=**21:16 CST** 属于 **c1pin RAM 启动**（`out/boot-elden-vk102-c1pin.img`，`CONFIG_IP_ADVANCED_ROUTER=y`），**不是日常内核**。主会话在 vk97（= 日常 config `a383cdb9`）上直测：`ip rule` → `RTNETLINK answers: Not supported`、`# CONFIG_IP_ADVANCED_ROUTER is not set`、`# CONFIG_IPV6_MULTIPLE_TABLES is not set`。
> ⇒ 正确口径：**日常内核 IPv4 多路由表也没开**，RouteController 更早死在 IPv4 fib rule；c1pin 只补了 IPv4，IPv6 fib rule 仍被拒 ⇒ **两内核下 RouteController::init 都失败**（与 A 基线 `failed to add interface eth0 to netId 100` 一致）。修复片段应同时包含 `IP_ADVANCED_ROUTER`/`IP_MULTIPLE_TABLES` **和** `IPV6_ADVANCED_ROUTER`/`IPV6_MULTIPLE_TABLES`。

### 1.1 netd 在跑、宿主侧网络正常
```
$ uname -r
7.2.0-debug-vk64-gd02658e63cf6
$ ip rule            # ⚠️ 本次为 c1pin（IP_ADVANCED_ROUTER=y）；日常内核无此规则、报 Not supported（见上文父代订正）
0:	from all lookup local
32766:	from all lookup main
32767:	from all lookup default
$ waydroid status
Session:	RUNNING
Container:	RUNNING
Vendor type:	MAINLINE
IP address:	192.168.240.112
Session user:	xuqianhui1001(1000)
$ iptables-legacy -t nat -S POSTROUTING | grep -i masq
-A POSTROUTING -s 192.168.240.0/24 ! -d 192.168.240.0/24 -j MASQUERADE
$ sysctl net.ipv4.ip_forward
net.ipv4.ip_forward = 1
```
（派发词声称日常内核 `ip rule` → Operation not supported；此次 **c1pin** 上 `ip rule` 正常出 3 条经典规则，但**日常内核 IPv4 多路由表也没开**（父代订正）。故缺项同时含 IPv4 与 IPv6 两套，见 §2。）

### 1.2 **根因句**（netd 自己的失败点）
```
$ waydroid shell -- logcat -d -b all | grep -iE "netd|RouteController|networkAddRoute|ConnectivityService"
10-11 13:16:18.226  73  73 E netd    : Failed to initialize RouteController (Address family not supported by protocol)
10-11 13:16:18.226  73  73 I netd    : Initializing RouteController: 111us
10-11 13:16:23.177  234  234 W NetworkStats: ... ServiceSpecificException: Unable to swap active stats map: Address family not supported by protocol (code 97)   [×多次]
10-11 13:16:38.607  234  407 D ConnectivityService: [100 ETHERNET] validation failed
10-11 13:22:36.137  234  407 D ConnectivityService: [100 ETHERNET] validation failed
```
netd 进程本身活着：
```
$ waydroid shell -- ps -A | grep netd
root              73       1 2616896  17156 binder_thread_read  0 S netd
$ waydroid shell -- cat /proc/73/status | grep -iE "Name|Uid|Seccomp"
Name:	binder:73_4
Uid:	0	0	0	0
Seccomp:	2
```

### 1.3 per-network 路由表空、netd 只建了 **IPv4** fwmark 规则（没有 IPv6 规则）
```
$ waydroid shell -- ip rule
0:	from all lookup local
15999:	from all fwmark 0x10064/0x1ffff iif lo uidrange 0-2147483647 lookup 1002
18000:	from all fwmark 0x0/0x10000 lookup 99
$ waydroid shell -- ip route show table 99
(空)
$ waydroid shell -- ip route show table 1002
(空)
$ waydroid shell -- ip link            # eth0 存在，ifindex=2
2: eth0@if7: <BROADCAST,MULTICAST,UP,LOWER_UP> ... state UP ...
$ waydroid shell -- cat /sys/class/net/eth0/ifindex
2
$ waydroid shell -- cat /proc/net/route
Iface	Destination	Gateway 	Flags	RefCnt	Use	Metric	Mask
eth0	00F0A8C0	00000000	0001	0	0	0	00FFFFFF      # 192.168.240.0/24 链路路由在主表
$ waydroid shell -- ping -c1 -W2 192.168.240.1
connect: Network is unreachable
```
**判据**：容器 `ip rule` 里只有 IPv4 的 fwmark 规则、无任何 IPv6 规则 ⇒ netd 的 `modifyIpRule` 双族循环（AF_INET 成功 → AF_INET6 被拒 → 整个函数返回错误）半途而废，与 AOSP 源码路径一致（§3）。

### 1.4 ndc 手测复现下游失败
```
$ waydroid shell -- ndc network create 99
400 0 createPhysicalNetwork() failed (Invalid argument)
$ waydroid shell -- ndc network route add 99 eth0 0.0.0.0/0 192.168.240.1
400 0 addRoute() failed (No such device)
$ waydroid shell -- ip route add default via 192.168.240.1 dev eth0 table 99
RTNETLINK answers: Network is unreachable
```
（`create 99` 的 Invalid argument：netId 99 在 AOSP netd 的合法 netId 区间之外，真实 per-network netId 从 100 起——推测；容器真实 network=100 由 `ip rule` 的 fwmark 0x10064 与 logcat `[100 ETHERNET]` 证实。`addRoute → No such device`：network 未注册，RouteController 死的下游结果。）

## 2. 是 Waydroid 集成问题还是内核 config 缺项？—— **内核 config 缺项**

判据链：
1. 同一台容器镜像、同一 waydroid 版本，netd 死于 **内核返回的错误**（EAFNOSUPPORT）——错误源在内核，不在 netd/Waydroid。
2. 容器内 netd 无独立内核：LXC 共享宿主内核 ⇒ 宿主内核缺 IPv6 policy routing 直接决定 netd 生死。
3. 外部旁证（同错误字符串的多平台案例）：
   - redroid-doc #387：「`Error adding IPv6 rule: Address family not supported by protocol` … enabling **CONFIG_IPV6_MULTIPLE_TABLES** solved my issue」
   - redroid-doc #750：同报错 ⇒ `init: Service 'netd' (pid 3993) exited with status 1`
   - netbirdio/netbird #1761：`add rule v6 ...: address family not supported by protocol`，作者确认「an issue that pops up when ipv6 (policy routing) is not supported … kernel support should suffice」
4. **本设备具体缺哪个 config 未证**：`zgrep -E "CONFIG_(IPV6|IP_ADVANCED_ROUTER)=" /proc/config.gz` 无输出（该内核没开 /proc/config.gz）。可证的是：IPv4 `ip rule` 可用（§1.1），容器内 IPv4 fwmark rule 已被加入（§1.3）——**IPv4 多路由表已在**；死的是 **IPv6** 那条 ⇒ 缺项最可能是 **`CONFIG_IPV6_MULTIPLE_TABLES`**（连带可补 `CONFIG_IPV6_SUBTREES=y`）。标注：**推测（强旁证，待换内核片段重编译验证）**。

## 3. AOSP 源码路径（为何一条 IPv6 失败 = 全局死）

`system/netd/server/RouteController.cpp`（main 分支，googlesource blob d7a6e834…）：

- `const uint8_t AF_FAMILIES[] = {AF_INET, AF_INET6};`，`modifyIpRule()` 内：
  ```cpp
  for (size_t i = 0; i < ARRAY_SIZE(AF_FAMILIES); ++i) {
      rule.family = AF_FAMILIES[i];
      if (int ret = sendNetlinkRequest(action, flags, iov, ARRAY_SIZE(iov), nullptr)) {
          ALOGE("Error %s %s rule: %s", actionName(action), familyName(rule.family), strerror(-ret));
          return ret;          // IPv6 被拒 ⇒ 立即失败返回
      }
  }
  ```
- RouteController::init 对该返回值按致命处理 ⇒ logcat 原文 `Failed to initialize RouteController (Address family not supported by protocol)`。
- 内核在 **IPV6 fib rule 不支持**（`CONFIG_IPV6_MULTIPLE_TABLES=n`）时对 `RTM_NEWRULE, family=AF_INET6` 返回 `EAFNOSUPPORT`。
- RouteController 死 ⇒ per-network 的 route/rule 全不建 ⇒ `networkAddRouteParcel` 下发的路由无处安放 ⇒ `[100 ETHERNET] validation failed` ⇒ 容器无默认路由。（另一旁路：netd 正常时 per-network 链路/默认路由本来也主要由 netd 写进表 1002/1003，而非主表——所以就算手动给主表塞默认路由，Android apps 的 socket 被 fwmark 引到 1002，主表路由救不了验证/应用流量。）

## 4. c1pin 上旧 workaround 为何反被弄坏 —— 机制**未证**（推测，附验证命令）

事实（派发词已证）：c1pin 上 `/root/wd/blank_screen.rc` 的 `ip route replace default via 192.168.240.1 dev eth0`（无 onlink，主表）失败（`Network is unreachable`），加 `onlink` 才 rc=0。

推测机制（待验证）：内核对「via 网关」的路由在**网关不可达时拒绝**是查**目标表内**的可达性。日常内核 IPv6 规则缺 → netd 死 → 容器 ip rule 干净；c1pin 上 netd 活 → 容器 ip rule 里出现 fwmark/uidrange 规则，若 c1pin 起的容器主表恰好缺 192.168.240.0/24 链路路由（或 boot_completed 时序下 eth0 还没配齐），gateway 查不到 ⇒ `Network is unreachable`；`onlink` 跳过网关可达性校验所以 rc=0。

验证命令（下次设备窗口，c1pin RAM 起时）：
```
waydroid shell -- ip route show table main        # 看 192.168.240.0/24 链路路由是否在
waydroid shell -- ip route replace default via 192.168.240.1 dev eth0 ; echo rc=$?
waydroid shell -- ip route replace default via 192.168.240.1 dev eth0 onlink ; echo rc=$?
waydroid shell -- logcat -d | grep -E "RouteController|IPv6 rule"   # c1pin 上应无 init 失败
```
预测：若 `table main` 有链路路由则 replace 应成功（推测被证伪）；若无则证实「链路路由缺失/时序」机制。

## 5. 确定性修复（优先级排序）

### ① 根因修复：内核补 `CONFIG_IPV6_MULTIPLE_TABLES=y`（推荐，唯一治本）
- 给日常内核（和 c1pin 一并）的 config fragment 加：
  ```
  CONFIG_IPV6=y                    # 已确认在（容器 eth0 有 inet6 地址）
  CONFIG_IPV6_MULTIPLE_TABLES=y    # ← 缺项，补这个
  CONFIG_IPV6_SUBTREES=y           # 可选，netd 不强需
  ```
- 重编译刷入后预期现象：
  ```
  waydroid shell -- logcat -d | grep RouteController
  # 应无 "Failed to initialize RouteController (Address family not supported by protocol)"
  waydroid shell -- ip rule
  # 应出现 IPv6 的 fwmark 规则（fwmark 0x10064/0x1ffff … lookup <1000+n> 的 v6 版）
  waydroid shell -- ip route show table 1002
  # 应非空：192.168.240.0/24 dev eth0 + default via 192.168.240.1
  logcat: [100 ETHERNET] 依次出现 validation succeed / VALID network
  容器 ping 192.168.240.1 → 1 packets transmitted, 1 received
  ```
- 依据：redroid #387 同错误串 + `CONFIG_IPV6_MULTIPLE_TABLES` 启用即修复（外部已证）；本设备未证（无法在线改 config）。

### ② 治标（不动内核）：把 workaround 改成 table-aware，写进 netd 用的表 + 顺带 onlink
在容器 boot_completed 后（把 `blank_screen.rc` 的 route 行替换为）：
```
ip route add 192.168.240.0/24 dev eth0 table 1002
ip route add default via 192.168.240.1 dev eth0 table 1002 onlink
```
- 预期现象：apps 的 socket 被 netd 的 fwmark 规则（`fwmark 0x10064/0x1ffff lookup 1002`）引到表 1002 ⇒ 路由生效；`[100 ETHERNET] validation` 是否转绿**未证**（netd 的 NetworkMonitor 走 fwmark socket，理论可过）。
- 前提：容器 `ip rule` 里已有该 fwmark 规则（本内核已证在，§1.3）；表号 1002 来自「netId 100 + ROUTE_TABLE_OFFSET」，若 netId 变化需用 `ip rule` 实读。
- 注意：旧 workaround 写主表无效——Android apps 的流量由 fwmark 引到 per-network 表，主表路由救不了（AOSP 设计，已证 by ip rule 输出）。

### ③ Waydroid/lxc 配置调整：无需
netd 的 per-network 表建立是 netd↔内核的行为，Waydroid 侧（waydroid-net.sh 的 bridge/NAT/MASQUERADE）全部就位（§1.1）；无 lxc 参数能替代内核的 IPv6 policy routing。**结论：此路无修复点**（判据：错误由内核 netlink 返回，非 Waydroid 脚本）。

### ④ DNS（国内网所需，配合①或②）
waydroid 镜像默认 DNS 8.8.8.8 被墙（redroid #750 同场景原文：「redroid use 8.8.8.8 as default DNS server, try change to something else if Google related links cannot be accessed」）。路由修好后若容器仍解析失败，改容器 DNS 为宿主 DHCP 下发的国内 DNS：
```
waydroid shell -- settings put global private_dns_mode off
# 或在 /var/lib/waydroid/waydroid_base.prop 加 net.dns1=<国内DNS>
```

## 6. 回退

- ① 是 config 变更，回退 = 换回现内核镜像；不改数据。
- ② 只改容器内路由（重启容器即失，非持久），回退 = 删 `blank_screen.rc` 的 route 行。

## 7. 已确认 / 未确认清单

| 项 | 状态 |
|---|---|
| netd RouteController init 失败是根因（EAFNOSUPPORT on IPv6 rule） | ✅ 已证（logcat + AOSP 源码 + 三例外部同错） |
| 缺项 = `CONFIG_IPV6_MULTIPLE_TABLES` | ⚠️ 推测（强旁证；设备无 /proc/config.gz，无法直读确认） |
| `No such device (19)` / table 99、1002 空 / validation failed = 下游结果 | ✅ 已证（ndc 复现 + ip rule 半套规则） |
| c1pin 上无 onlink workaround 失败的**机制** | ❌ 未证（设备窗口被收；验证命令见 §4） |
| ②表 1002 路由能否让 validation 转绿 | ❌ 未证（需设备实测） |
| 宿主内核支持 IPv4 多路由表（派发词「ip rule not supported」已过时） | ✅ 已证（§1.1 实测） |

---
*只写本文件；未改其它文档、未改 kernel/config、未刷机、未写设备。设备锁已释放（flock -n 成功验证）。*

---

## 6. 父代补：治本验证（vk103，2026-10-11 22:19 实机）

构建 `vk103-c1r6` = clean/base `5d01d3324` + `IP_ADVANCED_ROUTER` / `IP_MULTIPLE_TABLES` / `IPV6_MULTIPLE_TABLES` + **PINUTS 钉死 UTS**（`CONFIG_LOCALVERSION_AUTO=n` + `LOCALVERSION=-vk64-gd02658e63cf6`），冷起 **GOOD**；跑 `scripts/wd-c1-verify.dev.sh`（**不注入任何 workaround**）：

```
=== container ip rule ===
0: from all lookup local
10000: from all fwmark 0xc0000/0xd0000 lookup legacy_system
11000: from all iif lo oif eth0 uidrange 0-0 lookup eth0
15998: from all fwmark 0x10064/0x1ffff iif lo uidrange 0-2147483647 lookup eth0
16000: from all fwmark 0x10063/0x1ffff iif lo lookup local_network
16000: from all fwmark 0x10064/0x1ffff iif lo lookup eth0
17000: from all fwmark 0xc0000/0xc0000 iif lo oif eth0 lookup eth0
18000: from all fwmark 0x0/0x10000 lookup legacy_system
=== container route ===
[main] default via 192.168.240.1 dev eth0
[1002] default via 192.168.240.1 dev eth0 proto static      ← netd 自建（proto static）
       192.168.240.0/24 dev eth0 proto static scope link
=== egress w/o workaround ===
curl baidu : code=200
```
无 `RouteController failed`。⇒ **根因（本报告 §0 行1）= `CONFIG_IPV6_MULTIPLE_TABLES`（+ IPv4 多路由表）确认；治本 = 补内核 config**，不再需要 `blank_screen.rc` workaround。
