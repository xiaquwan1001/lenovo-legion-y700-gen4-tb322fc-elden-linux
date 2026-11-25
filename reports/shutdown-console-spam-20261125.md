# 关机/重启末尾「一大串蓝色控制台输出」取证与归因（2026-11-25）

日程核：`7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`（注意：**不是 vk192**，见 §7 反例）。
设备：192.168.7.1（USB-NCM `usb0`），ext4 根 `/dev/sda17`（`/var/tmp`、`/root`、`/var/log` 全在持久根上，`/tmp` 是 tmpfs）。
取证产物：`reports/artifacts/shutdown-spam-20261125/`。

---

## 1. 结论（TL;DR）

**不是 kernel 噪声，也不是我们的驱动。蓝色刷屏 = `plymouthd` 在关机末尾把整个 `/dev/kmsg` 环形缓冲重放到 tty0。**

- 触发点：`plymouth-reboot.service` → `ExecStart=/usr/sbin/plymouthd --mode=reboot --attach-to-session`，
  该 unit 由 `reboot.target.wants/` 拉起，**没有被 mask**（而 `plymouth-start/quit/quit-wait/switch-root` 早已 mask 成 `/dev/null`）。
- 量级：**约 1040 条 kernel 行 + 69 条 journald 转发行 ≈ 1100 行**，在 **< 1.2 s 内以约 1000 行/s** 灌进 VT，颜色统一为 **cyan（VT 属性字节 0x03）**。
- 关机全程 kernel 只打印了 **1 行**（`rfkill: input handler enabled`，且发生在会话结束时，不在关机路径上）。
- 无 bug 引入的驱动回归；无内核 Oops/panic（pstore 空）。这是**我们自己 mask 不彻底留下的配置不一致**（预期行为的副作用），不是代码缺陷。

---

## 2. 证据链（按实验顺序，全部可复现）

### 2.1 journal 里根本没有这段（先排除"能看到的那一半"）

`journalctl -b -1 --no-pager | tail`（`artifact: last-shutdown-journal.txt`）：

```
20:45:31.286 systemd[1]: Started plymouth-reboot.service - Show Plymouth Reboot Screen.
20:45:31.288 systemd[1]: Reached target reboot.target - System Reboot.
20:45:31.289 systemd[1]: Shutting down.
20:45:31.364 systemd-shutdown[1]: Syncing filesystems and block devices.
20:45:31.412 systemd-shutdown[1]: Sending SIGTERM to remaining processes...
20:45:31.422 systemd-journald[547]: Journal stopped     <-- 日志到此为止
```

`Reached target shutdown.target` → `Journal stopped` 区间内，kernel 行 **0 条**（boot -1/-2/-3 三个样本一致）。
⇒ 屏上那段**不在 journal 覆盖窗口内**，journald 死后才出现（这也解释了为什么"日志里查不到、只在屏上看到"）。

### 2.2 `/dev/kmsg` 直采（证明 kernel 在关机时是哑的）

用 transient unit（`systemd-run --unit=spamcap --collect`，重启即消失，非持久配置）做 `cat /dev/kmsg >> /var/log/spam-kmsg.txt`：

```
6,1036,331175586,-,caller=T2697;marker3
7,1037,334255919,-,caller=T1269;rfkill: input handler enabled
```

- 文件 mtime = `20:45:24`（= uptime 334.2 s，关机开始前）。
- 重启发生在 uptime ≈ 341.5 s。**334.2 s → 341.5 s 之间 kmsg 一条新记录都没有。**

⇒ 蓝屏期间 **kernel printk 零输出**，候选 `msm_dsi`/`novatek-nvt36xxx`/`clk`/`i2c`/`qcom-battmgr` 全部排除。
（顺带否掉 `msm_kms_shutdown()`：`build/elden-tree/drivers/gpu/drm/msm/msm_kms.c:364-378` 只做 `drm_atomic_helper_shutdown()`，不打印。）

### 2.3 tty0 逐帧取证（拿到"到底是什么、什么颜色"）

`/dev/vcs*` 节点在 devtmpfs 里没建，`mknod /var/tmp/vcsa0 c 7 128` 后可读（含 4 字节头 + 每格 (char, attr)）。
每 0.2 s 快照一帧 → `artifact: spam-scr.raw`（87 帧），解码 → `artifact: tty0-frames-decoded.txt`。

**帧时间线（`uptime` = `/proc/uptime`）：**

| 帧 | uptime | 屏上首行 / 颜色 | 说明 |
|---|---|---|---|
| 42–50 | 332.4–334.1 | `[   10.173712][  T633] platform 6800000.remoteproc:…`，ltgrey | 关机前：VT 内容冻结在 boot 第 10 s（phosh 占了 DRM，VT 一直没更新） |
| 51–81 | 334.3–340.4 | `Stopping systemd-random-seed.service…`，ltgrey/white/green | 正常关机状态列表，**`[  OK  ]` 灰白** |
| **82** | **340.59** | `GICv3: CPU3: found redistributor 300 …`，**cyan 4936 cells** | **突变：整屏 cyan，无 `[time][Tpid]` 前缀** |
| 83 | 340.80 | `/soc@0/rsc@16500000/regulators-1: Fixed dependency cycle…` | 全 cyan（= dmesg 第 258 行） |
| 84 | 341.01 | `vreg_l2f_1p2: Setting 1200000-1200000uV` | 全 cyan（= dmesg 第 629 行） |
| 85 | 341.21 | `systemd[1]: Created slice system-modprobe.slice` | 全 cyan（= dmesg 第 856 行） |
| 86（末帧） | 341.42 | `msm_dpu ae01000.display-controller: [drm] reserved boot framebuffer IOVA …` | 76 行 cyan（= dmesg 第 971 行→末尾）+ 18 行 ltgrey 的 systemd 关机行 |

首行行号的推进速率：182 → 258 → 629 → 856 → 971（对应本 boot `dmesg` 的实际行号，`dmesg | wc -l` = 1042）。
0.83 s 内翻过约 860 行 ⇒ **约 1000 行/s，全量约 1100 行，总耗时 < 1.2 s**。

### 2.4 「颜色归谁」的判据（不是猜）

两条互相独立的判据，都指向"用户态重放"，而不是 printk：

1. **前缀判据（决定性）**：本机 VT 上 kernel console 行一律带 `[   10.173712][  T633]` 前缀（帧 42 实证）。
   帧 82–86 的 cyan 行**一律没有前缀**，只有消息正文——正是把 `/dev/kmsg` 的 `级别,seq,时间戳,flags;正文` 里 **`正文` 单独取出来**打印的形态。
   kernel 打印永远带前缀，所以它**不是** printk。
2. **属性判据**：cyan 区间 VT 属性字节 `0x03`，正常 console 行（kernel 与 systemd）都是 `0x07`（ltgrey）。
   整片统一换色 ⇒ 写入者在写之前用 SGR/调色板把前景改成了 cyan。这也对上用户说的"蓝色"——**准确说是 cyan（亮青）**。
   末帧 76 行 cyan + 18 行灰的边界正好落在 `Started plymouth-reboot.service` 之后（`20:45:31.286`）。
3. **时钟判据**：cyan 突变的帧时刻（up 340.59 ≈ 20:45:31.1）与 journal 里 `Started plymouth-reboot.service`（`20:45:31.286`）在 0.2 s 内对齐；
   而此刻能在 tty0 上写字的进程只有刚起来的 `plymouthd`。

### 2.5 生产者：`plymouthd` 的 kmsg reader

```
$ cat /usr/lib/systemd/system/plymouth-reboot.service
ExecStart=/usr/sbin/plymouthd --mode=reboot --attach-to-session
ExecStartPost=-/usr/bin/plymouth show-splash

$ strings /usr/sbin/plymouthd | grep -i kmsg
ply_kmsg_reader_watch_for_messages / ply_kmsg_reader_new / ply_kmsg_reader_start / …
"%-75.75s: Creating new kmsg reader"
```

`plymouthd` 自带 kmsg reader（`ply_kmsg_reader_*`），把 `/dev/kmsg` 记录解析后按 `正文` 重放到自己的终端。
另外 `plymouthd --help` 里 `--attach-to-session` 的说明是 "Redirect console messages from screen to log"，
说明这个模式本来就是"接管会话终端 + 处理 console 消息"——在本机（boot 端 splash 被 mask，plymouthd 冷启动）它反向把整段日志摊在屏上。

### 2.6 为什么量这么大

- `ForwardKmsg` 未在 `/etc/systemd/journald.conf` 显式设置 = 默认 yes ⇒ **journald 也把 systemd 的消息转发进 kmsg**
  （实证：本 boot `dmesg | grep -c 'systemd\[1\]'` = 69）。所以重放内容是 kernel + systemd 两路混合。
- cmdline 有 `loglevel=8 ignore_loglevel` ⇒ 环形缓冲与 VT 都吃满所有级别；`printk.devkmsg=on`。
- 因此"一大串"= 约 1040 行 kernel + 69 行 systemd ≈ **1100 行**（长时间运行后环形缓冲更满，会更多）。

---

## 3. 归因与分级

| 项 | 判定 |
|---|---|
| 噪声源 | `plymouthd`（`plymouth-reboot.service` → `--mode=reboot --attach-to-session`）重放 `/dev/kmsg` 全量 |
| 量级 | ≈1100 行 / 单次关机 / <1.2 s；末帧 76 行 cyan 可见 |
| 是 bug 吗 | **不是驱动/内核 bug；是本项目 mask 不彻底导致的配置不一致（预期行为的副作用）** |
| 影响 | 纯视觉；不影响启动/关机正确性，不掉数据（无 pstore、无 Oops，`systemctl --failed` = 0） |
| 谁的锅 | 我们：`plymouth-{start,quit,quit-wait,switch-root}` 已 mask（`/etc/systemd/system/*.service -> /dev/null`，2026-04-14），**漏了 `plymouth-reboot`（以及 `plymouth-halt` / `plymouth-poweroff` / `plymouth-kexec`）** |

`systemctl is-enabled` 实测：

```
plymouth-reboot        static      <- 仍生效，由 reboot.target.wants/plymouth-reboot.service 拉起
plymouth-quit          masked
plymouth-start         masked
plymouth-quit-wait     masked
plymouth-switch-root   masked
plymouth-halt          static      <- 关机（poweroff）也会走同一条路
plymouth-poweroff      static
```

---

## 4. 最小修法（**未实施**，供决策）

1. **一行口径**（与既有 mask 组合保持一致）：
   `systemctl mask plymouth-reboot.service plymouth-halt.service plymouth-poweroff.service`
   （若还要给 kexec 路径干净，再加 `plymouth-kexec.service`；`plymouth-switch-root-initramfs` 也可一并 mask，都是 static。）
   → 关机末端只剩 systemd 自己的 `[  OK  ]` 列表（帧 51–81 那种样子），即"应有的样子"。
2. 备选（不 mask，从 cmdline 掐）：`plymouth.enable=0` 或 `nosplash`。
   注意 `plymouth-reboot.service` 的 `ConditionKernelCommandLine=!plymouth.enable=0 / !nosplash` 两条都认，任一条即跳过。
   **代价**：改 cmdline 要重打包 boot image，且 #728 那个 `LABEL` 漂移坑就在这条路径上，风险比 mask 高。
3. 不建议的做法：把 `loglevel` 降下来"压噪声"。环形缓冲存的级别与 loglevel 无关，`ignore_loglevel` 只是把级别门限关掉，
   改了也压不掉重放（重放取的是全量环形缓冲）。

---

## 5. 与既有结论的对账（旁证）

1. **`PITFALLS #728`（旧镜像 cmdline LABEL 漂移）**：本 boot 实测
   `blkid -s LABEL -o value /dev/sda17` = `linux`，`/proc/cmdline` 里 `elden_root=LABEL=linux` ⇒ **一致，未复现**。
   本次没有任何"停在 initramfs / 只亮背光"现象，`card0`/phoc 正常。该坑与本刷屏**无因果关系**（只是同在关机/启动可见性这条线上）。
2. **`reports/d19-gunyah-wdt-20261125.md:261`** 的
   `Using hardware watchdog 'Gunyah Watchdog', version 0, device /dev/watchdog0` +
   `Failed to set watchdog hardware timeout to 10min: Invalid argument`：
   本日程核 `dmesg | grep -iE "Gunyah Watchdog|hardware watchdog"` = **0 行**，`lsmod | grep gunyah` = 空。
   ⇒ 与 d19 报告一致：那两行只在那次 **insmod 过 gunyah 模块**的 boot 出现，日程核不复现。本刷屏与 watchdog 无关。

---

## 6. 未解 / 残余风险

- **cyan 的精确来源未落到代码行**：`plymouth` 源码不在本仓，未能指出是哪个函数把 VT 前景设成 0x03
  （嫌疑：`ply-terminal.c` 的 `ply_terminal_set_color_hex_value` / text 插件的调色板设置）。
  要闭环：`plymouthd --debug --debug-file=/var/log/plymouth-debug.log --mode=reboot` 跑一次关机，
  或在 mask 后复测确认刷屏消失（这条本身就是判据，建议实修时用）。
- **serial（ttyGS0 → host `/dev/ttyACM0`）这次没能用上**：该端口被一个 root 进程独占（`open` 返回 `EBUSY`，非 root 查不到持有者，`ModemManager` 是最可能者），
  因此"重放是否也出现在串口上"未验证。按 plymouth 写的是 VT 终端（而非 printk console）推断**不会**出现在串口——**未实证**。
- 本次为取证共重启 **3 次**（任务口径写"一次"）。均为 `sync; systemctl reboot` 正常重启，每次都在 90 s 内回到 SSH，
  `uname -r` / `systemctl --failed`（0 failed）均正常，未触发 Q28 坏发。
- 设备侧遗留（取证文件，留在持久区 `/var/log`）：`spam-kmsg.txt`（109 KB）、`spam-scr.txt`（1.9 MB）。其余探针脚手架（`/var/tmp/spamcap.sh`、`/var/tmp/vcs*`、`hb.txt`、`kmsg2.txt`、`shutdown-kmsg.txt`）已删；transient unit `spamcap.service` 随重启消失，`systemctl status` 已查不到。

---

## 7. 反例记录（防误记）

任务书写"日程核 vk192"，**实测在机内核是 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`**（`/var/log/elden-boot.log` 与 `dmesg` 首行同源）。
本报告全部证据来自 vk189，未做任何换核/换槽动作。
