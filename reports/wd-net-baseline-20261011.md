# Waydroid 容器网络 (A) 基线 — 日常内核下容器出网可达（2026-10-11）

> 承接 `TASKS.md §2 C1` / `§5 Q2`、`archive/topics/C1-WAYDROID-2026-10-11.md`、`scripts/waydroid-proxy-setup.sh`。
> 设备 U2 `HA2EXB0E`；本轮在 GOOD 启动 `out/boot-elden-vk97-base-lv64.img`（= 日常内核同源/config，UTS `…-vk64-gd02658e63cf6`，无 IP_ADVANCED_ROUTER）上取基线。

## 0. 结论

| 项 | 结果 |
|---|---|
| 容器起 | ✅ manager(`rc-service waydroid-container`)+**session 必须以 user 1000 起** ⇒ `waydroid status`: Session/Container RUNNING、IP `192.168.240.112` |
| 容器→网关 | ✅ `ping 192.168.240.1` 0% loss |
| 容器→国内网 | ✅ 注入主表默认路由后 **`curl http://www.baidu.com` = 200**（DNS 亦通） |
| 容器→外网(ICMP) | ⚠️ `ping 223.5.5.5` 100% loss（TCP 通，属 ICMP/NAT 细节，非阻塞） |
| per-network 表 99/1002 | ❌ 空（netd 未建） |

## 1. 根因链（netd，供 (C) 专线复用）

```
E Netd: failed to add interface eth0 to netId 100
E Netd: interface eth0 not assigned to any netId
E ConnectivityService: networkAddRouteParcel ... ServiceSpecificException: No such device (code 19)
```
⇒ netd 把 eth0 加入 netId 失败 ⇒ 不建 per-network 路由表 ⇒ 容器无默认路由。
日常内核 `ip rule` 不支持（`CONFIG_IP_MULTIPLE_TABLES` off）⇒ 所有路由查询走主表 ⇒ **主表补一条默认路由即可恢复出网**（实测 `curl baidu`=200）。

## 2. 历史 workaround 不可靠 → 已工具化

- 历史做法：`/root/wd/blank_screen.rc`（bind 到容器 `system/etc/init/blank_screen.rc`）在 `on property:sys.boot_completed=1` 跑
  `ip route replace default via 192.168.240.1 dev eth0`。本轮该 `.rc` **确实挂进容器**（`/system/etc/init/blank_screen.rc` 含该行），但**本次启动主表仍无默认路由 ⇒ 未生效**（原因未定：boot_completed 时序/接口未就绪/init 未解析）。
- 改为可靠工具（`scripts/wd-ctl.sh`）：
  - `session`：改**以 user 1000** 起（root 连用户 system bus 会 `DBus.Error.NoReply`，本会话实测）。
  - `route`：等容器 RUNNING **且 eth0 拿到 IP** 后，重试注入主表默认路由（规避早注入的 `Network is unreachable`）。
  - `egress`：一条命令取 ping 网关 + `curl baidu` 码。
- 实测（干净 cycle）：`start → session → route → egress` = `default via 192.168.240.1` + `curl baidu code=200`。

## 3. 未决 / 与 (C) 的分工

- **netd `eth0 not assigned to netId 100` 的根因**（为什么加接口失败）—— (C) 子代理专线（`reports/wd-netd-route-*.md`）。
- **开 IP_ADVANCED_ROUTER 反而恶化**：`out/boot-elden-vk102-c1pin.img`（`ip rule` 生效）上，netd **仍不建表**，且旧 workaround 的**无 `onlink`** `ip route replace default` 如今报 `Network is unreachable`（netd 的 `ip rule` 把 nexthop 解析导向空表 99；加 `onlink` 才成）⇒ **「开该 config 去 workaround」假设不成立**（见 `reports/c1-iprule-vk95-20261011.md` 需回填此否证）。
- **Google/GMS 线**：设备**直连 google=000**（被墙），host Clash 7897 从设备**不可达**（`192.168.7.9`/`192.168.7.2` 均 closed）⇒ 需一个**设备可达的 host 代理地址**（外部配置）。

## 4. 顺带：Q28 日常 boot 也会 STORM（补 §o）

本轮一次**纯净冷起**（日常 boot_b，UTS `…-vk64-gd02658e63cf6`）落在 **STORM**：`card0` 在、`DSI-1 connected`，但 `storm=45`（`vblank wait timed out` / `drm_crtc_wait_one_vblank`）、无 `phoc/phosh`/无 `wayland-0`/无会话 ⇒ 桌面未起。
⇒ `PITFALLS #192` / `q28-DOSSIER §o` 的「UTS 逐字=GOOD 串 ⇒ 冷起 GOOD」**只解释 NOCARD 分支**；**STORM 是独立随机**（同 UTS 串的日常 boot_b 也会 STORM）⇒ 日常 Q28 痛点仍在（STORM 模式），与 boot 镜像身份无关。
