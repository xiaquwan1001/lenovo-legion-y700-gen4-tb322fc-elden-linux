# #691 重装根的启动队列会被两个「我们用不上的包」卡死：`droid-juicer` 与 `plymouth-quit-wait` ⇒ 屏上停在开机服务日志、桌面永远不出现

## 现场（2026-11-19 晚，两次重启都复现）

设备能 ssh、`card0`/fb0 在、`systemd-udevd` active、`greetd` **inactive**，用户目视「一直展示早期的各种服务信息」（= tty0 上的 systemd/fbcon 输出没被桌面接替）。

判据链（按顺序就能定位，别猜硬件/显示）：

```
systemctl is-system-running            → starting      （不是 running；degraded 也不阻塞桌面）
systemctl is-active graphical.target   → inactive
systemctl list-jobs                    → greetd/graphical.target/multi-user.target 全 "start waiting"
                                         而有两个 job 在 "running"
systemctl list-units --state=activating → droid-juicer.service / plymouth-quit-wait.service
```

两件阻塞物：

| 件 | 为什么卡 | 我们是否需要 |
|---|---|---|
| `droid-juicer.service`（Debian-on-phone） | 开机扫 Android 分区抽 vendor 固件（解 `super`/遍历分区），在自建 GPT 表上会跑很久/卡住 | **不需要**（我们的固件走 `/lib/firmware` + initramfs） |
| `plymouth-quit-wait.service` / `plymouthd` | 无 splash 需求但 plymouth 装了；`plymouthd` 不退出 ⇒ boot 永不完结 | **不需要** |

两者**任一**都能让 `multi-user.target`/`graphical.target` 永远 `waiting`，于是 `greetd` 的 job 排在后面永远不执行 —— 现象与「桌面壳坏了」无法区分。

## 处置（已机械化）

- 设备侧：`systemctl disable --now` + `systemctl mask` 上面 5 个 unit
  （`droid-juicer` + `plymouth-{start,quit,quit-wait,switch-root}`）。
- 主机侧判据：`scripts/deploy-desktop-shell.sh` **§8b**（2026-11-19 新增）
  —— 远端统计「未 mask 的阻塞件数」，非 0 即 `MISS`；真跑模式直接 mask；
  另加一条 `graphical.target` 必须 `active`。
- 若已卡住：`systemctl stop <阻塞件>` 即可解锁队列（不必重启设备）。

## 为什么早先能起、后来起不来

13:00 那次启动这两件没卡（分区/时序不同），16:39 之后两次都卡。**判据不能是「上次能起」**，
只能是 §8b 那条「阻塞件 masked + graphical.target active」。

## 顺带记录（同日观察，非阻塞）

- `qcom-modem-setup.service` failed（无 modem 用途）、`bootmac-bluetooth.service` failed
  （仓内**零命中** ⇒ Debian 包带的，读 MAC 失败）——都只让系统 `degraded`，**不阻塞桌面**，
  不要把它们和上面的「队列卡死」混为一谈。
- RTC 写不了 ⇒ 冷起时间回到镜像构建日（2026-04-14），PAM 会打印
  `account <user> has password changed in future`；先跑 `time-sync.sh` 再登桌面会话。
