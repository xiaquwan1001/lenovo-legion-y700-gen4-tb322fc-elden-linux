# droidloom cell 无网根因（工单 D2）——U2 平板，2026-11-26

- **性质**：纯静态（本地源码 `~/src/droidloom` @ 572e1c5 = release 49）+ 设备只读现查（`ssh elden-root`，仅 `ip`/`nft list`/`dumpsys`/`logcat -d`/`cat`/`journalctl`）。零写入、零重启、零网络配置改动；未持设备锁（锁全程 free）。
- **上游对账**：denialwm/droidloom **issue #48**（2026-11-22，open）与本机故障**逐项同构**，其 workaround 已被报告者实测；本机数据为 #48 增加第二个独立缺陷（校园网 UDP/53 全封）。

## 0. 一页结论

| # | 问题 | 判定 | 一句话依据 |
|---|---|---|---|
| 1 | **cell 为什么拿不到 10.177.0.2** | 网络 "Droidloom" 被 WifiConfigManager **永久禁用**（`NETWORK_SELECTION_DISABLED_NO_INTERNET_PERMANENT`，已持久化），网络选择器每轮扫描都「Ignoring network selection disabled SSID: "Droidloom"」⇒ 永远不发起 L2 关联 ⇒ 永远不发 DHCP DISCOVER | `dumpsys wifi`：`- DSBLE ID: 0 SSID: "Droidloom" … firstL2ConnectionAttempt=null`；`WifiConfigStore.xml`：`SelectionStatus=NETWORK_SELECTION_PERMANENTLY_DISABLED`；`hasEverConnected: true` + `hasEverValidatedInternetAccess: false`（早期 cell 会话连上过、验证失败后升级为永久禁用并落盘） |
| 2 | **adb 端点为什么不可达** | 同一因：10.177.0.2 从未出现（宿主 `adb devices -l` 空；journal 只有 `ADB disconnect failed: no such device '10.177.0.2:5555'`） | 同上 |
| 3 | **隐藏第二缺陷（修好 #1 也会立刻踩）** | DhcpResponder 硬编码 DNS `1.1.1.1 / 8.8.8.8`，但本校园网（USTC）**封所有校外 UDP/53** ⇒ cell 即使拿到 IP 也无 DNS ⇒ 信息流/验证探针全死，且验证再失败会**再次**触发永久禁用（#48 报告者实测 +79 s 复禁） | `busybox nslookup`：`202.38.64.18` ✓，`1.1.1.1 / 8.8.8.8 / 223.5.5.5 / 114.114.114.114` 全部 `connection timed out`；TCP 853/443 到公共 DNS IP 也 BLOCKED |
| 4 | **基础设施本身** | 全部在位、无故障：netns/veth/nft 两表/ip_forward/DhcpResponder/wificond/supplicant HAL 全正常 | 见 §2 |

**根因排序**：① 永久禁用未清除（可信度 ~95%，直接证据 + 上游 #48 机制吻合）；② cell DNS 硬编码撞校园网 53 封锁（~90%，直接证据，独立缺陷）；③ 「veth/对端没起来」「cell 内无 DHCP 客户端」「nft 没做 SNAT」「真 wifi suspend 不关联」**全部排除**（零风险判据见 §3）。

## 1. 期望形态（源码 + 上游文档实读）

droidloom release 49 已从静态 `eth0` 迁到**虚拟 Wi-Fi `wlan0`**（`runtime/droidloom-supervisor/src/development_network.rs`）：

- **宿主侧（droidloom-supervisor，root，每次起 cell 重建）**：
  1. `ip netns add droidloom-u1001`；建 veth 对：宿主端 `dlh1001`（10.177.0.1/30），**对端直接在 netns 内创建、名为 `wlan0`**（MAC `02:64:6c:00:00:02`）——**不是把真 wifi 搬进 netns**，真 wifi 留宿主（宿主同名 `wlan0` 不冲突）；
  2. netns 内 `lo up` + `wlan0 up`；
  3. **DHCP responder 是 supervisor 进程内的线程**（`dhcp_responder.rs`，AF_PACKET socket 挂 `dlh1001`，netfilter 之下）：应答 cell 的 DISCOVER，发**固定租约** `10.177.0.2/30`，网关 10.177.0.1，**DNS 硬编码 [1.1.1.1, 8.8.8.8]**，租期 24 h。⇒ **不依赖 dnsmasq**；
  4. 记录并置 `/proc/sys/net/ipv4/ip_forward=1`；
  5. 一条 `nft -f -` 事务建两表：`inet droidloom_u1001`（input：只放行来自 10.177.0.2 的 established tcp sport 5555，其余 iif=dlh1001 drop；forward：只放行 saddr=10.177.0.2 出站 + established 回程）+ `ip droidloom_u1001_nat`（postrouting masquerade）。有 UFW 时额外插一条 accept（本机无 UFW）。**这两张表由 supervisor 拥有，cell stop 时整表删除**。
- **cell 侧（Android）**：`wlan0` 被伪造成唯一 AP：`wificond`（`/droidloom/wifi/wificond`，`droidloom-wifi.rc`）+ `android.hardware.wifi.supplicant-service.droidloom`（`android/wifi/droidloom-supplicant/supplicant.cpp`）伪造扫描（SSID `"Droidloom"`、ch36 5180 MHz、RSSI −45）与关联状态机（选中该 SSID 后 ~150 ms 走完 SCANNING→ASSOCIATING→ASSOCIATED→COMPLETED）；
  - **一次性供给**：SystemUI `WifiProvisioning.java`（首次解锁后）`addNetwork("Droidloom", OPEN)` + `enableNetwork` + `setWifiEnabled(true)`，成功后写 `wifi_provisioned=true` **从此不再运行、也不复查禁用状态**（#48 主因）；
  - 之后是原生链：ClientModeImpl → NetworkAgent → IpClient/**DhcpClient**（cell 内确实跑 DHCP 客户端，即 Android 原生）→ `netd`（compat 的 `netd-cell-policy`）→ NetworkMonitor  captive-portal 验证（默认 google 探针）→ 成为默认网络。
- **adb**：host 侧用户级 `droidloom-adb-server.service` 自动连 `10.177.0.2:5555`（`~/.android/adbkey` 公钥投影进 cell；无 LAN 监听、无端口转发）。INSTALL.md §ADB。

## 2. 实际差在哪（设备只读现查，命令 + 原始输出摘录）

| 命令 | 关键输出 | 判读 |
|---|---|---|
| `ip -br a`（宿主） | `wlan0 UP 114.214.233.60/22 …`；`dlh1001@if2 UP 10.177.0.1/30` | 宿主真 wifi 正常；veth 宿主端在位 |
| `ip netns list` | `droidloom-u1001 (id: 0)` | netns 在 |
| `nft list ruleset` | `table inet droidloom_u1001{…}` + `table ip droidloom_u1001_nat{… masquerade}` 全部在位 | **nft/NAT 没问题**（排除假设③） |
| `cat /proc/sys/net/ipv4/ip_forward` | `1` | 转发开着 |
| `nsenter -t 120626 -n ip -br a` | `wlan0@if14 UP`（无 IPv4）；`ip route`（空） | cell 端 UP、LOWER_UP、**从未 DHCP** |
| `nsenter … -n ip -d link show wlan0` | `veth … link/ether 02:64:6c:00:00:02` | 对端是 veth、MAC 符合设计（排除「veth 对端未起来」） |
| `ps -eo … \| grep -Ei 'droidloom\|dnsmasq\|iwd\|wpa\|wificond'` | `droidloomd`(root)、supervisor 120626、`wificond`(uid 1010)、`supplicant-service.droidloom` 在；宿主 `wpa_supplicant`/`NetworkManager` 是**宿主自己**的 wifi 栈 | 各就各位 |
| `journalctl -u droidloomd -b` | 两条 `ADB disconnect failed: no such device '10.177.0.2:5555'`（14:48 / 15:19） | adb 无端点可连（与 #1 同因） |
| `journalctl --user -u droidloom.service -b`（grep error） | 仅 1 条无关 `could not remember … window size: Permission denied` | 用户单元无网络类报错 |
| `dmesg \| grep -i veth` | 空 | 无异常事件 |
| cell 内 `cmd settings get global wifi_on` | `1` | wifi 已开（供给完成过） |
| cell 内 `dumpsys wifi` | `Wi-Fi is enabled`；`Supplicant state: DISCONNECTED, Net ID: -1`；`firstNetworkSelectionAttempt{…isSuccess=false}`，`firstL2ConnectionAttempt=null,firstL3ConnectionAttempt=null`；`- DSBLE ID: 0 SSID: "Droidloom" …`；每轮扫描 `Ignoring network selection disabled SSID: "Droidloom"` | **链条死在选择器**：根本不尝试关联 |
| cell 内 `cat /data/misc/apexdata/com.android.wifi/WifiConfigStore.xml` | `SelectionStatus=NETWORK_SELECTION_PERMANENTLY_DISABLED` / `DisableReason=NETWORK_SELECTION_DISABLED_NO_INTERNET_PERMANENT`；`CreatorUid=10072(systemui)` | **永久禁用已落盘**（boot 间持久） |
| cell 内 `dumpsys wifi`（PerNetwork） | `hasEverConnected: true` / `hasNeverDetectedCaptivePortal: true` / `hasEverValidatedInternetAccess: false` | 历史上 L2+DHCP 成功过一次，验证从未通过 → 升级为永久禁用 |
| 宿主 `adb devices -l` | 空列表 | 端点不可达实锤 |
| 宿主直连探针（`curl --noproxy '*'`） | `connectivitycheck.gstatic.com/generate_204`→**204**、`www.google.com/generate_204`→**204**、`wifi.vivo.com.cn/generate_204`→**204**（http+https） | **现在**宿主出网完全正常 ⇒ 禁用是更早会话（宿主断网或探针被墙时）捕获后持久化的 |
| 宿主 `busybox nslookup <域> <DNS>` | 校内 `202.38.64.18` ✓；`1.1.1.1/8.8.8.8/223.5.5.5/114.114.114.114` 全 `connection timed out`；TCP `223.5.5.5:853/443`、`8.8.8.8:853` BLOCKED；DoH 域名 https ✓(200) | 校园网只放行校内 resolver 的 UDP/53；DoT 走不通，DoH 可走（但 Android 系统解析器不用 DoH） |

时间线：部署轮 14:22 首个 cell 会话内 wifi 供给成功 → 某次 L2+DHCP 成功（`hasEverConnected:true`）→ NetworkMonitor 验证失败（当时宿主断网或 google 探针被墙）→ NO_INTERNET 暂禁→**升级永久禁用并落盘** → 14:51 tcpdump 期已零帧（选择器跳过）→ 15:19 重启 cell 后依旧（本报告现查状态）。

## 3. 根因假设排序 + 区分判据

| # | 假设 | 可信度 | 区分判据（全部零风险可现查，除非注明） | 状态 |
|---|---|---|---|---|
| ① | "Droidloom" 被 `NO_INTERNET_PERMANENT` 永久禁用，供给一次性不复查 → 零 L2 尝试 | **~95%** | `dumpsys wifi` 的 `DSBLE`+`Ignoring network selection disabled`；`WifiConfigStore.xml` SelectionStatus；`firstL2ConnectionAttempt=null`。**反证法**：修法生效后该字段应变非 null 且出现 DISCOVER | ✅ 确认 |
| ② | cell DNS `[1.1.1.1, 8.8.8.8]` 被校园网 UDP/53 封锁 → 即使有 IP 也无解析、验证再失败再触发① | **~90%（独立缺陷）** | `busybox nslookup` 直测（已做）；修②后 cell 内 `dumpsys netd`/解析成功 | ✅ 确认 |
| ③ | nft 未做 SNAT / 转发没开 | <5% | `nft list ruleset` + `ip_forward`（已做，全在位） | 排除 |
| ④ | veth 对端未起来 / netns 没建 | <5% | `ip netns list` + netns 内 `ip -d link`（已做） | 排除 |
| ⑤ | cell 内没有 DHCP 客户端 / 需要 dnsmasq | <5% | 源码：DhcpClient 为 Android 原生；responder 是 supervisor 线程，不需要 dnsmasq；`hasEverConnected:true` 证明链路通过过 | 排除 |
| ⑥ | 真 wifi suspend/省电不关联 | 0% | cell 的 "wifi" 是 veth 无射频；宿主真 wlan0 正常拿网 | 排除（**需写设备才能进一步证的项：无**） |

## 4. 修法（下一轮上机；本轮零写入未执行）

**顺序很重要：先修 DNS（②），再解禁（①）**——否则重连后验证探针解析失败 → ~79 s 内再次永久禁用（#48 实测复发）。

### ① 只读/临时（快速验证；除标注外重启即消失）

```sh
ssh elden-root   # 全程套 timeout -k；设备写入走 scripts/device-lock.sh 串行（下轮）

# [0] 旁证：tcpdump 应开始出现 DHCP DISCOVER（此前为零帧）
timeout -k 3 20 tcpdump -i dlh1001 -n -c 20 &

# [1] 临时 DNS 重定向：独立 nft 表（不要写进 droidloom_u1001*——cell stop 会整表删除）
nft add table ip dl_dns_redirect
nft add chain ip dl_dns_redirect pr '{ type nat hook prerouting priority -100; }'
nft add rule ip dl_dns_redirect pr iifname "dlh1001" ip saddr 10.177.0.2 udp dport 53 dnat to 202.38.64.18
#   回退：nft delete table ip dl_dns_redirect
#   预期：cell 内 DNS 立即可解析（走校内 resolver）

# [2] 解除永久禁用（= 用户手动连一次，是写操作；上机轮执行）
SUP=$(pgrep -f "droidloom-supervisor development-enter" | head -1)
AIP=$(pgrep -P $SUP | head -1)     # Android init
nsenter -t $AIP -m -n -p -- /system/bin/cmd wifi connect-network "Droidloom" open
#   若仍被禁用，回退到重建网络：
#   nsenter … cmd wifi forget-network 0 && nsenter … cmd wifi connect-network "Droidloom" open

# [3] 预期现象（逐条判据）：
#   tcpdump：DHCP DISCOVER → OFFER → REQUEST → ACK
#   nsenter -t $AIP -n ip -br a ⇒ wlan0 出现 inet 10.177.0.2/30
#   cell 内 dumpsys wifi ⇒ SupplicantState COMPLETED；firstL2/L3ConnectionAttempt isSuccess=true
#   cell 内 dumpsys connectivity ⇒ Active default network: 100（Wi-Fi, VALIDATED）
#   宿主 su xuqianhui1001 -c "adb devices -l" ⇒ device:droidloom 10.177.0.2:5555 model:Droidloom
```

### ② 持久（落盘正规位置，含回退）

1. **captive-portal 探针换可达端点**（上游 #48 已验证的 workaround；settings 写入 `/data/system/users/0/settings_global.xml`，**持久**但可逆；本机已实测 vivo 端点 http/https 双 204）：
   ```sh
   nsenter -t $AIP -m -n -p -- /system/bin/cmd settings put global captive_portal_http_url  http://wifi.vivo.com.cn/generate_204
   nsenter -t $AIP -m -n -p -- /system/bin/cmd settings put global captive_portal_https_url https://wifi.vivo.com.cn/generate_204
   nsenter -t $AIP -m -n -p -- /system/bin/cmd settings put global captive_portal_fallback_url http://wifi.vivo.com.cn/generate_204
   #   回退：cmd settings delete global captive_portal_http_url（其余同）
   #   注意：connect.rom.miui.com 在本网返回 200（非 204）会被当 portal，勿用。
   ```
   首次 VALIDATED 后 `hasEverValidatedInternetAccess=true`，此后即使探针再挂也**不再**升级为永久禁用（#48 机制）——这是它作为持久项的价值。
2. **DNS 持久化**：dnat 规则若要跨重启存在，须独立 nft 表 + 宿主侧 systemd unit（additive：`/etc/systemd/system/droidloom-dns-redirect.service`，`After=droidloomd.service`；回退 = disable + rm）。**必须用独立表**，写进 `droidloom_u1001*` 会在 cell stop 时被 supervisor 删掉。更好的归宿是上游：#48 已提「DhcpResponder DNS 可配/从宿主带出」——`dns: [202.38.64.18]`（或从 `/run/systemd/resolve` 带出）一次解决。
3. **正统修法在上游**（本仓不 fork）：`WifiProvisioning.java` 设 `config.noInternetAccessExpected = true` + 开机复查"已保存网络被永久禁用"即解禁（#48 Suggested fixes 1）。本仓动作 = 去 #48 评论补充本机复现数据（USTC：探针今日可达但早期会话被捕获 + UDP/53 全封实测）。
4. **与 `deploy-desktop-shell.sh` 门禁的关系**：上述 1（cell 内 settings）、2（独立 nft 表 + 新 unit）**不触碰**门禁清单里的任何项（udev/phosh/phoc/greetd/phosh-osk-stub/gnome-session/elden-session-user/截图链），不会撞 `--check` 判据；按仓库纪律仍须 `scripts/device-lock.sh` 串行 + additive + 回滚记录。**唯一会撞车的形态**：若把 DNS 重定向塞进 `droidloom_u1001*` 表或改 `/usr/lib/droidloom/current` 内文件（deploy 轮的产物），会被 supervisor 删除/污染部署件——已规避。

## 5. 附带：网络修好之后

- **小红书能否真加载——判据链**：
  1. `droidloomctl launch com.xingin.xhs` 返回窗口对象（已有）；
  2. cell 内 `dumpsys connectivity`：`Active default network: 100` 且 Wi-Fi NetworkAgent 带 `VALIDATED`；
  3. cell 内 `logcat -d | grep -cE "UnknownHost|Unable to resolve"` = 0（DNS 修复的直接证据；若仍走 1.1.1.1 会在 `dumpsys netd` 看到 `BROKEN`）；
  4. `logcat -d` 出现 xhs 域名 TLS/OkHttp 200 级别的网络活动、无 `xyass`/`SystemHealer` 网络超时风暴；
  5. 窗口级目视：信息流出图（用户确认）。
- **adb 官方分片路径**：端点可达后，Limbus 三 split 不再需要 `nsenter + cmd package install-*` staging 绕过，改走官方通道：
  ```sh
  su xuqianhui1001 -c "adb -s device:droidloom install-multiple \
    /home/xuqianhui1001/dl-apps/limbus/base.apk \
    …/split_config.arm64_v8a.apk …/split_UnityDataAssetPack.apk"
  ```
  `droidloom-adb-server.service`（用户单元）自动重连；`-s device:droidloom` 为稳定选择器（INSTALL.md §ADB）。**注意**：adb 通了不解决 Limbus 的 AppSealing 自杀（deploy 报告 §4 独立问题）。

## 6. 下一轮上机验收判据（≤5 条）

1. `nsenter -t $AIP -n ip -br a`：`wlan0` 出现 `inet 10.177.0.2/30`（解除禁用 + DHCP 成功）。
2. `tcpdump -i dlh1001`：观察到 DISCOVER→OFFER→REQUEST→ACK 完整四步（此前零帧）。
3. 宿主 `su xuqianhui1001 -c "adb devices -l"`：`device:droidloom 10.177.0.2:5555` 在列。
4. cell 内 `dumpsys wifi`：`firstL2ConnectionAttempt/firstL3ConnectionAttempt isSuccess=true` 且无 `Ignoring network selection disabled`；`dumpsys connectivity`：`Active default network: 100` + VALIDATED。
5. cell 内域名解析成功（`cmd` 侧任一 HTTPS 请求或 `dumpsys netd` 无 BROKEN/超时）且 `logcat -d` XHS 网络活动无 `UnknownHost`。

## 7. 产物指针

- 本报告 = 本工单唯一领域写入。证据全部内嵌（§2 表）；源码依据 = `~/src/droidloom`（572e1c5）：`runtime/droidloom-supervisor/src/{development_network,dhcp_responder}.rs`、`android/wifi/{include/droidloom/wifi_access_point.h,droidloom-supplicant/supplicant.cpp}`、`android/framework/droidloom-systemui/src/com/android/systemui/wifi/WifiProvisioning.java`；上游文档 = docs/INSTALL.md；上游缺陷 = denialwm/droidloom#48。


---

## §8 已修（同日 18:2xZ 实测，父代理执行）

按本文件 §4 顺序落地（**先 DNS 后解禁**）：

1. cell 内三条 `settings put global captive_portal_{http,https,fallback}_url = wifi.vivo.com.cn/generate_204`（持久，落 `/data/system/users/0/settings_global.xml`）。
2. 宿主独立 nft 表（**不写进 `droidloom_u1001*`**，否则 cell stop 被 supervisor 整表删）：
   `ip dl_dns_redirect`，`hook prerouting priority dstnat`，规则 `iifname "dlh1001" ip saddr 10.177.0.2 udp/tcp dport 53 dnat to 202.38.64.18`。
3. cell 内 `cmd wifi connect-network Droidloom open`。

**结果（判据逐条命中）**：cell `wlan0 10.177.0.2/30` + 默认路由；`dumpsys connectivity` = `Active default network: 100 … IS_VALIDATED`；宿主 `adb devices -l` ⇒ `10.177.0.2:5555  device … device:droidloom`。
**待办**：DNS 表跨重启不持久 ⇒ 需独立 systemd unit（additive）；若换到 lane D24 建议的 fork（`EvilBorsch`，已实现 lease 带宿主 resolver）则该表可整件删除。

---

## §9 重启后回归实测（2026-11-26T14:0x–14:2xZ / CST 22:0x，网关中断后的收尾复核）

**触发**：上轮 21:52 的试验核 boot 之后设备自然回 boot_b，本段是「重 boot 后 §8 的修复还在不在」的实测。

| 判据 | 实测 | 结论 |
|---|---|---|
| `nft list ruleset \| grep -c dl_dns_redirect` | **0** | §8-2 的 DNS 重定向表**不跨重启**（T4 判据「重启后命中」= **FAIL**，已实测而非推测） |
| droidloom 是否自启 | `systemctl is-enabled droidloomd` = disabled（系统 scope）；真正的 cell 起停件 = **user 1001 的 user manager** 下的 `droidloom.service`/`droidloom-*.socket`，`WantedBy=graphical-session.target`；该 target 在本栈 **inactive**（已知 P1）⇒ 重 boot 后 journal 里 droidloom 记录 **0 条** | deploy 报告的「开机自启」**在重 boot 后不成立**；需 `su xuqianhui1001 -c "systemctl --user start droidloom.service"`（本轮实测可起来） |
| cell 起后链路 | cell `wlan0@if5 UP 10.177.0.2/30`；宿主 `dlh1001@if2 UP 10.177.0.1/30`；两侧 `/30` 路由都在；宿主 `ping 10.177.0.2` **100% 丢包**；`adb devices` 无 `10.177.0.2:5555` | 地址面齐全但**链路不通**（此前同态）；不能用 ping/adb 当「cell 网络好」的判据 |
| 总线干扰 | `adb devices` 里 `MDX5T20730009849` = 华为 ELS-AN00（非本机，`PITFALLS #371`） | adb 侧判据一律显式 `-s 10.177.0.2:5555` / `device:droidloom` |

**净结论**：§8 的三步修复（captive 探针 / nft DNS 表 / `cmd wifi connect-network`）是**会话内一次性**的，重 boot 后全部要重做 ⇒ T4（持久化）与 T5（重启后 IME/默认项）都必须拿「重 boot 后重启命」当判据，本轮 T4 已判 FAIL。
