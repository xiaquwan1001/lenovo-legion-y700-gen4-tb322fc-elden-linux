# 88 · 退役 `local.d` 前必须先装新 `/init`，否则静默断 WiFi（#399）

**日期**：2026-10-25 · **pi 会话 id**：宿主会话 · **主题**：入口收敛（/init vs local.d vs 服务管理器）时的顺序陷阱 + OpenRC oneshot 的 `crashed` 假状态
**证据**：`reports/userland-service-consolidation-20261025.md`、设备 `/root/bak/20261025-entry-consolidation/`、`packaging/elden-userland/tools/render.py`

## #399a 仓库 `/init` 与在机 disk `/init` 是两个版本

- 仓库 `initramfs/init`（444 行）在 openrc 模式下**刻意不启动**那批后台脚本，注释写明「/sbin/init 与
  `/etc/local.d/elden-bringup` 负责，故跳过这套手写编排」。
- 但**在机 disk `/init` 是旧版（350 行）**，既没有模块加载块也没有启动块 ⇒ 那些脚本当时唯一的启动者就是
  `/etc/local.d/elden-bringup.start`（它启动 ath12k-retry / charge-watch / time-sync / q28-boot-watchdog）。

于是「先把 local.d 退役、再把启动权交给服务管理器」的顺序会**静默断 WiFi**：
`ath12k-retry` 没人启动 ⇒ PCI 设备保持 unbound ⇒ **连 `wlan0` 这个接口都不存在**（本次实测：`ip -br link` 只剩 lo/usb0，
`/proc/modules` 里 0 个模块），而桌面照样起来（DRM 是 `=y`）⇒ 看起来"只坏了网络"，很容易误判成无线驱动回归。

**正确顺序**：① 装新 `/init` 到 disk（备份旧件）→ ② 部署服务 initd 并 `rc-update add` → ③ **最后**才把 local.d 改成 no-op。
**恢复手段**：旧 `/init`、旧 initd、local.d 原件都在 `/root/bak/<日期>-entry-consolidation/`；
纯 RAM 启动镜像 `out/boot-elden-vk162-rescue.img`（`ROOTARGS=` 空）可在 disk `/init` 坏掉时进去改文件。

**判据（别再靠"感觉网络断了"）**：`grep -c . /proc/modules`（0 = 模块根本没加载，不是驱动 bug）、
`pgrep -f sbin/ath12k-retry`、`ip -br link show wlan0`、`ls /sys/bus/pci/devices/0000:01:00.0/driver`（`readlink` 空 = unbound）。

## #399b OpenRC oneshot 用 `command=` 起，状态会永远报 `crashed`

`command=/usr/local/sbin/x.sh` + 无 `command_background` 时，openrc-run 仍按"daemon"记账；脚本跑完退出
（哪怕 rc=0）就变成 `crashed`。多个一次性脚本因此看起来"挂了"，`rc-status --crashed` 全是噪声。
**修法**（已进 `render.py`）：oneshot/shutdown 类必须显式写

```sh
start() {
	ebegin "…"
	"$command" $command_args
	eend $?
}
```
改后 `ath12k-retry / bt-alias / elden-bootlog / pstore-catch` 全部如实报 `started`。

## #399c 判"重复进程"不能只看 `pgrep -c`

`supervise-daemon` 的命令行里含子进程路径 ⇒ `pgrep -fc sbin/charge-watch` 返回 **2**（supervisor + child），
这不是双启。判双启要看 `ps -eo pid,ppid,args | grep <script>` 里有几个 **`/bin/sh …/<script>`**，或看父进程是否为 1。
