# C1 端到端验收：去 workaround 后容器原生出网（vk126-c1）— 2026-10-13

> 任务：`TASKS.md` §2 C1 / §5 Q2。设备 U2 `HA2EXB0E`，`fastboot boot` 零写盘 RAM 启动。
> 前序：`reports/c1-iprule-vk95-20261011.md`（内核 config 修复已上机确认，端到端因坏发未取到样本）、
> `reports/wd-netd-route-20261011.md`（根因 = netd `RouteController::init` 失败）。

## 0. 结论

| 项 | 结果 |
|---|---|
| **内核 config（C1 根修）** | ✅ `/proc/config.gz`：`CONFIG_IP_ADVANCED_ROUTER=y`、`CONFIG_IP_MULTIPLE_TABLES=y`、`CONFIG_IPV6_MULTIPLE_TABLES=y` |
| **netd `RouteController` 初始化** | ✅ 成功（整 boot `Failed to initialize RouteController` 计数 = **0**；vk64 上为 EAFNOSUPPORT 致命失败） |
| **容器默认路由来源** | ✅ **netd 自建**：`table eth0` / `table 1002` 均有 `default via 192.168.240.1 dev eth0 proto static`，**没有任何 workaround 注入** |
| **容器出网** | ✅ `ping 223.5.5.5` 2/2（29–49 ms）、`curl http://www.baidu.com` = **200** |
| **workaround 可退役性** | ✅ 本发在 `blank_screen.rc` bind-mount **禁用**下取得上述结果 ⇒ **C1 判据满足** |

结论：**Q2 答案 = 「去掉 workaround 仍可原生出网」**（前提是内核带上述 4 个 config）。

## 1. 镜像

- `out/boot-elden-vk126-c1.img`：**81 MiB**（85340160 B），sha256 `7e9f459ebc5f8e46e0aad1d2bba8abc9591fd5955ba4168e946030ff8dd4c391`
- 内核载荷 sha256 `6c20f38fa355b5415c47a51756f3924bb71a92ba0f92d0417a458ad9d8fb7c30`
- 构建：`BASE_IMG=out/boot-elden-vk124-merged.img VERSION=vk126-c1 BASE_COMMIT=5b169d541 CFG=patches/config-daily-c1 EXPECT_CFG=f008aae441af bash scripts/q28-build-daily-id.sh`
  - 源 = `clean/base@5b169d541`（与 vk124-merged 同源）
  - config = `patches/config-daily-c1`（= 日常好档 a383cdb9 + `patches/fragment-c1-iprule{,6}.config`，**差 10 行全为 C1 相关**）
  - ramdisk `35823240…` / DTB `5d658a2c…` / cmdline / UTS `#121` **与 vk124-merged 逐字节同** ⇒ **唯一变量 = C1 config**
  - 新增 config 快照：`patches/config-daily-c1`（sha `f008aae4…`）

## 2. 上机证据（GOOD 冷起，boot_id `ed4a3391-39c8-4622-8c5d-e5d0de570935`）

前置：显示 GOOD —— `card0-DSI-1 connected`、`dmesg | grep -c 'hangcheck recover'` = **0**、phoc/phosh 存活。

```
# 宿主
CONFIG_IP_ADVANCED_ROUTER=y
CONFIG_IP_MULTIPLE_TABLES=y
CONFIG_IPV6_MULTIPLE_TABLES=y

# 容器（workaround 已禁用：config_nodes 第 37 行 = '#C1-TEST-DISABLED lxc.mount.entry = /root/wd/blank_screen.rc …'）
$ getprop sys.boot_completed
1
$ ip -br addr show eth0
eth0@if5   UP   192.168.240.112/24 fe80::cd80:811d:2206:96aa/64

$ ip rule
0:      from all lookup local
10000:  from all fwmark 0xc0000/0xd0000 lookup legacy_system
11000:  from all iif lo oif eth0 uidrange 0-0 lookup eth0
15998:  from all fwmark 0x10064/0x1ffff iif lo uidrange 0-2147483647 lookup eth0
16000:  from all fwmark 0x10064/0x1ffff iif lo lookup eth0
18000:  from all fwmark 0x0/0x10000 lookup legacy_system

$ ip route show table eth0
default via 192.168.240.1 dev eth0 proto static
192.168.240.0/24 dev eth0 proto static scope link

$ ip route show table 1002
default via 192.168.240.1 dev eth0 proto static
192.168.240.0/24 dev eth0 proto static scope link

$ ping -c2 -W2 192.168.240.1   # 2/2, 0.047 ms
$ ping -c2 -W2 223.5.5.5       # 2/2, 29.7/39.5/49.2 ms
$ curl -s -m15 -o /dev/null -w '%{http_code}' http://www.baidu.com
200
```

对照（vk64，`reports/c1-iprule-vk95-20261011.md`）：`ip rule` → `Operation not supported on transport endpoint`；去 workaround 后容器只有链路路由、无 default。

## 3. 测试方法（可复现）

1. 设备在 fastboot（用户 POR）→ `fastboot boot out/boot-elden-vk126-c1.img`。
2. **必须判显示 GOOD**：`cat /sys/class/drm/card0-DSI-1/status` = connected **且** `dmesg | grep -c 'hangcheck recover'` = 0 **且** phoc/phosh 存活。
   —— 坏发（STORM）下 phoc 卡在 DPU hangcheck ⇒ 容器 `sys.boot_completed` 恒空、eth0 无 IPv4，**测不了**（本轮第一发即如此）。
3. 设备侧脚本 `scripts/wd-c1-noworkaround.dev.sh`（自动备份/禁用/还原 `config_nodes`）：
   禁用 `blank_screen.rc` bind-mount → 起容器 + 会话 → 等 `sys.boot_completed`/eth0 IPv4 → 查 `ip rule`/`ip route` 各表/`ping`/`curl` → 还原。
   > 注意：`ip route`（main 表）**本来就不该有 default**——Android 走 fwmark + per-network 表（`eth0`/`1002`）。判据看**表 `eth0`**。

## 4. 残留 / 待办

- `patches/config-daily-c1` 尚未并入日常构建管线的默认 config（`q28-build-daily-id.sh` 默认仍 `a383cdb9`）。若要让**日常 boot_b** 带 C1，需把该快照设为日常 config 或显式传 `CFG=`。
- 设备持久态未改：`boot_b` 仍 vk94；`config_nodes` 已还原（workaround 行恢复）；`blank_screen.rc` 文件未动。
- 本发为 `fastboot boot`（RAM），掉电即回日常。
