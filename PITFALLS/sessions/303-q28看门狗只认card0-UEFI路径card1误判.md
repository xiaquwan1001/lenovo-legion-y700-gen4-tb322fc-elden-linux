## #667 `q28-boot-watchdog` 只认 `/sys/class/drm/card0`：走 UEFI/GRUB 路径时 msm 是 **card1** ⇒ 一次完全正常的启动被判「Q28 坏发」并自动重启两次

**现象（2026-11-16，a 槽 UEFI/GRUB 冷起回归时）**：用户看到「第一次进 Linux 后自己关机 → 第二次 GRUB 后只有背光卡住 → 第三次正常」。
`/var/log/q28-watchdog.log` 给的正是我们自己的看门狗：

```
14:48:22 Q28 bad boot detected (attempt 1/2 sess=yes card=no sig=no) -> normal reboot [uptime=101.08s]
14:56:10 Q28 bad boot detected (attempt 2/2 sess=yes card=no sig=no) -> normal reboot [uptime=98.02s]
14:58:44 Q28 bad boot (sess=yes card=no sig=no) but retry budget exhausted (2>=2) -> staying up for diagnosis
```

**判据/机制**：`have_card()` 原实现 = `[ -e /sys/class/drm/card0 ]`。走 UEFI/GRUB 路径时 `SYSFB_SIMPLEFB` 的 efifb 先注册成 DRM
`card0`、随后注销，msm_drm 拿到的是 **`card1`** ⇒ `have_card()` 恒假 ⇒ `sess=yes card=no` ⇒ 命中「坏发」判据 ⇒ 75 s 后
`reboot`（且计数跨启动累加到 MAX=2）。**b 槽直启（ABL 直接 `boot_b`，无 efifb 前身）仍是 `card0`**，所以运营线从来没触发过。

实测对照（同一天，同一台机器）：

| 启动路径 | `/sys/class/drm/` | 看门狗判定 |
|---|---|---|
| b 槽（`boot_b` 直启） | `card0 card0-DP-1 card0-DSI-1 card0-Writeback-1` | 正常，不重启 |
| a 槽（Mu UEFI → GRUB → `/boot/Image`） | `card1 card1-DP-1 card1-DSI-1 card1-Writeback-1` | 判 bad ⇒ 重启（**误判**） |

**处置**：改成「存在任一 `cardN` 即算有卡」，并把卡名写进日志（`cards=[…]`）；源 = `packaging/elden-userland/files/usr/local/sbin/q28-boot-watchdog.sh`
（设备件由 `render.py` 生成，勿手改设备侧），已部署（sha `d694c147…`），b 槽 dryrun 后 `count` 归 0。

```sh
drm_cards() { for d in /sys/class/drm/card[0-9] /sys/class/drm/card[0-9][0-9]; do [ -e "$d" ] && printf '%s ' "${d##*/}"; done; }
have_card() { drm_cards | grep -q .; }
```

**别据此删掉看门狗**：同一轮里第二次启动的「只有背光 + 卡住」是真 Q28 坏发（`msm` 根本没 bind，一个 `cardN` 都不存在），
该发看门狗的判定是**对的**（日志里三条 `card=no` 中只有 uptime 98 s 那发属于真坏发）。真正的 Q28 根因（DYN pclk 域闩住）
仍未修，见 #228。

**一般化教训**：凡是按 `/sys/class/drm/card0` 写死的脚本（`dpms-watch.sh`、`cam-mode.sh`、`sleep-cumulative.sh`、
`elden-bootlog.sh` 等）在 UEFI/GRUB 路径上都会指错卡 —— 这些只跑日常线，暂不必改，但**回归 UEFI 路径时先想一遍**。

证据：`reports/artifacts/uefi-daily-v8-20261116/{41-q28-wd-unit.txt,42-q28-watchdog-log.txt,40-loop-boot-journal.txt,30-cold-por-grub-menu.jpg}`。
