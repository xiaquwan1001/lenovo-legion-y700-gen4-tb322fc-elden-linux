# #413 · `fastboot boot` 到「disk root 有问题」的镜像后设备**全静默**：不是慢枚举，是恢复通道根本没起来

> 2026-10-26 · 设备 `HA2EXB0E` · 场景：把根从 Alpine(linux18 f2fs) 换成 Debian(linux17 ext4) 的候选镜像。
> 相关条目：见 `PITFALLS/README.md` 索引里「USB 变 `1d6b:0104` 且 60–90 s 慢枚举」与「boot 镜像活过暖复位」两条。

## 现象

`fastboot boot <img>` → `Sending OKAY` / `Booting OKAY`，然后：

- 内核日志 `USB disconnect, device number 11`，**之后 8 分钟无任何 usb 事件**；
- `lsusb` 既没有 `18d1:d00d`（fastboot）也没有 `1d6b:0104`（composite gadget）；
- `/dev/ttyACM*` 消失（主机侧原本持有的 `cat /dev/ttyACM0` 进程自己退出了）；
- `fastboot devices` 空。

## 为什么它不是「慢枚举」（对照已有的 USB 消失类条目）

#391 的判据是「按 VID 白名单判活会误判」，正确做法是等 60–90 s 再看 `1d6b:0104`。
本次等 **>7 min**，`1d6b:0104` **一次都没出现**，且连枚举失败的痕迹（`new high-speed USB device`）都没有。
⇒ 差别不是「慢」，是 **gadget 从来没被创建**。

## 根因方向（判据来自代码结构，不是猜测）

本机的**整条恢复通道都在 `switch_root` 之后**：

```
ramdisk /init → 解析 elden_root → mount 磁盘根 → exec switch_root /newroot /init
                                                   ↓
                              磁盘 /init：mnt proc/sysfs/run → ip lo up → usb-gadget → udhcpd → sshd
```

所以「磁盘根有问题」= 主机侧**完全失明**，而且看不出是哪一种：

| 万一发生 | 主机侧看到的 |
|---|---|
| 磁盘 `/init` 跑不起来（dash 兼容 / 权限 / 缺文件） | PID1 退出 → 内核 panic → `panic=15` 重启 → 回 `boot_b`（这时 USB 会再现，判据 = 有没有 `1d6b:0104` 复活） |
| `/init` 落进 `rescue()`（`exec /bin/sh` 当 PID1） | **永久静默**：sh 在等 ttyGS0，而 ttyGS0 正是它本该拉起来的东西 |
| `usb-gadget` 起不来（configfs 未挂 / 无 UDC / 脚本缺） | 永久静默（`warn "usb0 never appeared"` 只写 dmesg，而 dmesg 靠 ttyGS0 才看得到） |
| SoC 硬挂 | 永久静默 |

三种「永久静默」在主机侧**完全不可区分**。这是本次最大的工程结论。

## 治法（优先做，不需要先知道根因）

**把 lifeline 提前一层**：在 **RAM 阶段**（`switch_root` 之前）可选地就挂 `configfs` + 起 `usb-gadget`，
用 cmdline 开关（如 `elden_early_gadget=1`）控制。这样磁盘根再怎么坏，主机仍能拿到
`/dev/ttyACM0` 的 dmesg 与 ttyGS1 的 root shell。

⚠️ 两个必须先验的点（否则会把「调试手段」变成「新的坏点」）：
- `PITFALLS` 已有教训：ramdisk 里的资源不能在 `switch_root` 后继续被持有（`/init` 注释里写着
  「no ramdisk files are held open when switch_root frees the initramfs」）。gadget 的 configfs
  对象是否随 switch_root 失效，必须先在 **RAM-only 镜像**（`ROOTARGS=`）上零写盘验一次。
- 早挂 gadget 意味着 `usb-gadget` 会在 `/sys`/`/dev` 还是 ramdisk 的挂载点时运行，`switch_root`
  之后 `mount --move` 会把它们带到新根 —— 顺序要实测。

## 操作纪律（本次执行到的部分）

- 试验前记槽位基线（`boot_b retry=6 succ=1 unbootable=0`）、确认 `linux17` 未被挂载、未被 systemd 引用；
- 只做 `fastboot boot`（零写盘），**没有** `fastboot flash`；
- 出现「无任何通道」→ **停止重试**，保留现场，交用户做物理 POR（`.pi/AGENT-OPS.md` §1）。

## 复现/判活命令（不要接管道，`PITFALLS #199`）

```bash
lsusb | grep -E '18d1:d00d|1d6b:0104'      # fastboot / composite gadget
fastboot devices
ls /dev/ttyACM*                             # gadget 起来才有
journalctl -k --since '-10 min' | grep -E 'usb 1-10|ttyACM'
```
