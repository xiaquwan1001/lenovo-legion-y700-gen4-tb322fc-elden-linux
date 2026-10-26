# Debian 根 ②：Waydroid 容器/会话已起，Android 卡在 sensors HAL

> 2026-10-26 23:3x · 设备 = U2 `HA2EXB0E` · 全部现场操作，未写分区/槽位

## 0. 结论（先数字）

| 判据 | 结果 |
|---|---|
| `waydroid` 包 | 已在 Debian 根（`1.6.3+ds-3`） |
| 内核 binderfs | `/dev/binderfs/{binder,binder-control}` 在，`/proc/filesystems` 有 binder |
| images | **复用现役 Alpine 根那份**（GAPPS `system.img` 2 432 MiB + 烤过的 `vendor.img` 256 MiB） |
| `waydroid-container` | **active** |
| `lxc` 容器 | **RUNNING**（`servicemanager` / `surfaceflinger` / `zygote64` / `system_server` 都在） |
| `waydroid status` | **Session RUNNING / Container RUNNING**，session user = `xuqianhui1001`，`wayland-0` |
| `waydroid0` 网络 | `192.168.240.1/24` + `fd00:240::1/64`（宿主侧就绪） |
| Android `sys.boot_completed` | ⬜ **卡在 bootanimation** |
| 根因（日志实证） | `sensorservice` 阻塞：`android.hardware.sensors@1.0::ISensors/default` 一直 `not registered`；容器内 `init.svc.vendor.sensors-hal-1-0 = stopped`；`ctl.interface_start` 报 `0x20` |

## 1. 搬过来的东西（`rootfs/debian/import-waydroid.sh` 固化）

为什么"搬"而不是 `waydroid init`：① 现役根的 GAPPS 镜像已验证过、省 2.6 GB 下载；
② **设备侧静态 ELF** 在仓库里没有源（MANIFEST `repo_src=-`，T14 债务）只能从现役根拿；
③ `/root/wd`（2 GB，Mesa/allocator.rc 等容器 bind 资产）同样只存在于设备。

脚本做四件事（幂等）：images（跳过 `.bak`）→ 配置（cfg/prop/lxc/rootfs/overlay*）→
**静态**二进制（dynamic 的直接跳过并告警，因为 glibc 根上跑不了 musl 动态件）→ `/root/wd` +
`config_nodes` 修正。

## 2. `config_nodes` 三处 Alpine 专属必须改（否则 lxc 起不来）

| 条目 | Alpine 侧 | Debian 侧处理 |
|---|---|---|
| `/root/wd/allocator.rc` | 存在（Mesa/minigbm 覆盖） | 把 `/root/wd` 一起搬过来后保留；**没有就删条目**，否则 `Failed to setup mount entries` |
| `/dev/video100` | 相机 loopback，通常不在 | 改 `optional 1`（否则整机容器启动失败） |
| `/var/lib/waydroid/host-permissions` | 是**目录** | 建空目录（`cp` 不带 `-a` 会漏掉目录 ⇒ 之前的失败点之一） |

实测：改完 `lxc-start … -F` 从 `Failed to spawn container` 变成 **RUNNING**。

## 3. 仍缺（按依赖顺序）

1. **容器内 sensors HAL 不注册**：`vendor/bin/hw/android.hardware.sensors@1.0-service.waydroid`
   与 `vendor/etc/init/…service.waydroid.rc` 都在 vendor.img 里，服务定义是 `oneshot`，
   手工跑立刻退出（rc=0）⇒ 说明它要的东西不在（host 侧 route-C 供给：UDP 52012 的
   `waydroid-sensord`/`-udp` 与 `eldroid-sensord` 已随脚本搬到 `/usr/local/bin`，但
   **`ssc-udp-relay.service` 每 5 s 退出重启、`elden-hapticd` 以 `status=2 INVALIDARGUMENT` 退出**）。
   ⇒ 下一步：先把这三个服务在 Debian 根上跑稳（对照 Alpine 的 initd 参数），再看 HAL 是否注册。
2. `sys.boot_completed` 依赖 (1) ⇒ 现在是「Android 起来但停在开机动画」。
3. `lxc-net.service` 在 Debian 根**必然失败**（`ip6tables … Could not fetch rule set generation id`），
   而 Waydroid 用自己的 `waydroid0` 网络 ⇒ 已 `systemctl disable --now lxc-net`，应写进 overlay。

## 4. 复现/回退

- 复现：`bash rootfs/debian/import-waydroid.sh` → `systemctl start waydroid-container` →
  `su xuqianhui1001 -c 'XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 \
   DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus waydroid session start'`
- ⚠️ Debian 根上 `XDG_RUNTIME_DIR` 是 **`/run/user/1001`**（logind），**不是** Alpine 的 `/run/phosh`
  ⇒ 仓库里的 `waydroid-session.sh` / `waydroid-ui.sh` 写死 `/run/phosh`，在 Debian 上必须改（待办）。
- 回退：`waydroid session stop; lxc-stop -n waydroid -k; systemctl stop waydroid-container`
