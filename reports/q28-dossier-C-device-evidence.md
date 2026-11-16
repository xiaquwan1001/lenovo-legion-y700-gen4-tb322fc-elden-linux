# Q28 dossier-C —— 设备实测证据（watchdog 日志 / journal 全 boot / dmesg / sysfs）

> 采集时间：2026-11-16 15:40–16:05 CST，全程只读 ssh（`ssh -o BatchMode=yes elden-root '...'`）。
> 在机内核（采集时 boot 0）：`7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0 #32 SMP PREEMPT Mon Nov 16 10:55:25 CST 2026 aarch64`。
> 纪律（PITFALLS #620，`PITFALLS/README.md:318`）：**无 `Kernel panic`/`Oops`/`end trace` 不得写「硬件掉电」**；pstore 空不能当没 panic。本档所有「异常结束」均按 journal 判据分类，不做掉电结论。

---

## ① 一句话结论

**设备侧数据不支持「Q28 仍在日常线复发」**：全 journal 67 个 boot **零** panic/Oops/end trace/vblank-wait/command-DMA-timeout；`/var/log/q28-watchdog.log` 170 行里只有 8 条真事件（**sig 从未命中**，11 月的 4 条 `card=no` 全部可用「UEFI 路径 msm=card1 而看门狗只认 card0」解释为误判，1 条可用「msm 真缺席」解释）——今日唯一一台 msm 从未 bind 的 boot（`378fb95f`，11-16 11:30→11:36）的指纹是 phoc `Waiting for a KMS device`，而**不是**任何内核错误行；同时发现看门狗时间戳与 journal 时间戳在 RTC 失效下大面积失真，且**3 条带真实时间的 watchdog 事件对不上任何 journal boot**（见 ⑤）。

---

## ② 时间线

### ② .1 时钟前提（先读这条，否则一切时间线不可信）

- `timedatectl`（boot 0 现场）：`System clock synchronized: yes`、`NTP service: active`，但 **`RTC time: 四 1970-01-08 22:24:41`**、`/sys/class/rtc/rtc0/date` = `1970-01-08` ⇒ **RTC 电源域每次断电归零，从 epoch 起走**（当前累计 ≈ 8.4 天通电时间）。
- 后果 1（watchdog 日志）：170 行中 **146 行时间戳是假钟**——82 行 `1970-01-12…1970-01-20`、**64 行逐字符相同**的 `2026-10-17T05:54:20`（该 boot 全程假钟冻结在 05:54:20，`uptime=77.14s` 的行戳 `05:55:35` = 冻结值+75 s，自洽）。
- 后果 2（journal）：**67 个 boot 的 FIRST ENTRY 全部是 `2026-11-05 23:40:21–27`**（冻结锚点，来源未定位，见 ⑤-6）；每次 boot 的早期条目盖假钟，NTP 步进时刻在 30 s–5.5 min 之间浮动（实测 `9ac465` boot 冻结到真实 12:24:38 才跳）。
- 因此：**只有「事件发生前时钟已同步」的行/boot 段能进时间线**；下面 2026-11-08 之后的事件时间戳均满足此条件（与 boot 簇互相咬合）。

### ② .2 watchdog 日志时间簇（`/var/log/q28-watchdog.log`，设备实测）

| 时间簇（行首戳） | 行数 | 内容 | 时钟可信性 |
|---|---|---|---|
| `2026-10-17T05:54:19/20` | 71（其中 05:54:20 ×64） | 全部 `disabled by cmdline` | ❌ 冻结假钟（真实日期不可知，属 elden_q28_nowd 时代） |
| `1970-01-12 … 1970-01-20` | 82 | 全部 `disabled by cmdline` | ❌ RTC 死钟 |
| `2026-10-26 … 2026-10-29` | 9 | 全部 `disabled by cmdline` | ❌ 未同步（uptime≈3 s，早于任何 NTP） |
| `2026-11-08T16:11:20` | 1 | `no session (card=yes sig=no …) but no Q28 signature -> NOT rebooting [uptime=85.91s]` | ✅ |
| `2026-11-10T22:18:04` | 1 | `Q28 bad boot detected (attempt 1/2 sess=no card=no sig=no …) [uptime=84.81s]` | ✅（但 journal 无对应 boot，⑤-1） |
| `2026-11-16T11:32:40` / `11:34:30` | 2 | `attempt 1/2 sess=no` / `attempt 2/2 sess=yes`，均 `card=no sig=no`，uptime 84.32/84.62 | ✅（journal 无对应末端，⑤-1） |
| `2026-11-16T14:48:22 / 14:56:10 / 14:58:44` | 3 | `attempt 1/2` / `attempt 2/2` / `budget exhausted (2>=2) -> staying up for diagnosis`，uptime 101.08/98.02/100.18 | ✅ 三条逐 boot 归因成功（③-族4） |

`2026-10-17T05:55:35`（attempt 1/2，uptime=77.14）为全文件唯一 10 月的非 disabled 行，时钟冻结 ⇒ 真实日期不可知。

### ② .3 journal 全 boot 时间轴（67 boots，`journalctl --list-boots`）

- 覆盖窗口：末端真实时间 `2026-11-05 23:40:42 → 2026-11-16 15:40+`（10 月的 boot 已被 journal 轮转掉，October 事件**无 journal 可对**）。
- 簇（按末端真实时间）：
  - **11-05 深夜 `23:40:2x–23:42:14`：12 个短 boot（多数全假钟，条目 367–430 条即终）** = 当晚 R21 引导 ladder 实验（`HISTORY/days/2026-11-05.md:16-20`「il: 崩溃点锁进 LoadImageAndAuth…10 发零写盘」），**不是 Q28**。
  - 11-06 00:11 / 11-10 14:47、16:52、17:42（三个 ~400 条假钟+2~4 条真实的 boot，末端即会话实验收工）。
  - 11-11 → 11-14：9 个正常长 boot（运营/桌面，末端全带 systemd-shutdown 序列）。
  - **11-15 12:47 → 23:06：17 个 boot**（vk189-suspend -00002 时代，suspend 测试循环），末端全干净。
  - 11-16 11:30 → 15:40：**19 个 boot**（今日 GRUB v8/v9/v10 回归 + #667 误判簇，见 ③-族4）。
- 「异常结束」（整 boot 无 `Reached target reboot/shutdown.target` 且无 `Journal stopped`）共 **17 个**：
  `ea9633c5 0a46e9ff a643d7c8 154bd006 2b9f8ade b28f5444 52c474ec d103e706 ddd5db20 463a701f aa448b8f`（11 个 = 11-05/11-10 实验短 boot，假钟为主，末端 23:40:3x/23:41:25/11-10 14:47:08/16:52:50/17:42:28）＋ `dcb37ce7`（11-11 13:53:06 末端 droidloom 行）＋ `e7c3f23e`（11-12 00:34:22）＋ `2252b8c6`（11-13 09:17:29）＋ `45661786`（11-13 20:26:40）＋ `9ac4656f`（11-16 13:17:02，末端 `phoc Modesetting with 1904x3040 @ 165.000 Hz`）＋ `3f7486d3`（11-16 14:48:18，**归因已知**：att1 触发 `reboot2`，droidloom 刷屏竞速丢尾部）。
  **判读警告**：`reboot2`（看门狗重启通道）= 正常 systemd 重启 ⇒ 也产生完整关机序列（证据：`ff2bd090` 含 att2 行又有 `Reached target reboot.target`），所以「有干净关机标记」≠「非看门狗所为」，「无标记」也可能只是刷屏丢尾（`3f7486d3`）。按此判据，**没有任何 boot 需要动用「掉电」假设**。

---

## ③ 症状族与判据（从实测数据归纳，各族给可复用判据）

### 族 1 —— `disabled by cmdline`（162/170 行；uptime 中位 2.98 s，range 2.51–3.88 s）
cmdline 含 `elden_q28_nowd` 时看门狗在 local.d 起来 3 s 内记一行退出。**判据**：这一族出现 = 该 boot 处于实验态（关看门狗），与 Q28 无关。attempt 分布、uptime 分布都只被这一族主导，看门狗统计必须先剔除它。

### 族 2 —— 真 Q28「msm 缺席」（今日仅 1 boot，`378fb95f…`，11-16 11:30→11:36:04，内核 `-00005`）
- **phoc 永不打开 DRM**（67 boot 全量扫描里唯一一例 `PHOC_NO_CARD`）：
  ```
  11月 16 11:35:49 elden phoc[1672]: Failed to create server: Could not create backend
  11月 16 11:35:55 elden phoc[1922]: [backend/session/session.c:492] Waiting for a KMS device
  ```
- 内核侧无任何 Q28 特征行（无 vblank wait / command DMA timeout / Failed to initialize panel；`grep` 全 boot 0 命中）。
- **判据**：`journalctl -b <id> | grep -a "Initializing DRM backend for /dev/dri/card"` 无输出 ⇒ msm-DRM 从未出现 = 该族。旧判据 `grep "Initialized msm"` **不可用**（47 个正常 boot 同样搜不到，dmesg 级别/限流差异，实测 `3bdb4ef3` 等 phoc 正常用 card0 的 boot 也是 NO_MSM 假阳性 ×38）。
- 该 boot 末端是干净 systemd 重启（11:36:04），日志无 q28-wd journal 行——它自己没被看门狗重启，谁重启的未定（⑤-2）。

### 族 3 —— `no session 但无 Q28 特征`（1 条，11-08 16:11:20，`card=yes sig=no -> NOT rebooting`）
看门狗正确拒绝重启（有卡无会话 ≠ Q28）。**判据**：卡面存在即可排除经典 NOCARD；此族说明「无桌面」另有来源（当日为实验台架）。

### 族 4 —— **card0 误判簇**（11-16 14:48–14:58，a 槽 GRUB/UEFI 路径；PITFALLS #667）
| att 行 | 归属 boot（journal 末端咬合） | 该 boot journal 事实 |
|---|---|---|
| `14:48:22 attempt 1/2 sess=yes card=no` | `3f7486d3`（末 14:48:18） | `Initializing DRM backend for /dev/dri/card1 (msm)`、`'DSI-1' connected`、modes 1904x3040@165…、`Modesetting with 1904x3040 @ 165.000 Hz` ×1 |
| `14:56:10 attempt 2/2 sess=yes card=no` | `ff2bd090`（末 14:56:10，q28-wd 行就在其 journal 里） | 同上（phoc 开 **card1**，`Modesetting` ×1；尾部 LibBpfLoader 刷屏） |
| `14:58:44 budget exhausted` | `bcd8467b`（次 boot，q28-wd 行带 Boot 头入账） | phoc 开 **card1**，正常桌面，`count` 文件 mtime 14:56 = 2 |
- 机制：UEFI/GRUB 路径 efifb 先注册 DRM `card0` 再注销，msm 拿 `card1`；旧 `have_card()` 只认 `card0`（`rootfs/persistent-overlay/q28-boot-watchdog.sh:38-40`）⇒ 恒 `card=no` 误判。**b 槽直启 msm=card0 不误判**。
- **与 #667 的一处修正**：#667 写「uptime 98 s 那发是真坏发（msm 根本没 bind，一个 cardN 都不存在）」——**与其自身 journal 矛盾**：`ff2bd090`（98.02 s 那发）里 phoc 已打开 `/dev/dri/card1 (msm)`、`DSI-1 connected` 且完成一次 modeset。若用户当时目视「只有背光」，那说明存在「**msm bind + phoc modeset 成功而屏仍黑**」的状态（无 DCS/DMA/vblank 报错，sig=no）——这是与 NOCARD（族 2）不同的新症状态，值得单列（⑤-3）。
- 今日 a 槽 GRUB boot 用「phoc 开 card1」识别共 6 个（`8f04b113 3f7486d3 ff2bd090 bcd8467b 6367d60a 6dbf8a11`）；v10 真机验证（活过 160 s 无新行）确认修复版看门狗成立（`reports/artifacts/uefi-daily-v8-20261116/README.md` v10 节）。

### 族 5 —— 慢性背景噪声（**对坏发零判别力**，各 boot 计数）
| 行 | 分布（实测） | 结论 |
|---|---|---|
| `DSI PLL(0) lock failed, status=0x00000000`（+`PLL(0) lock failed`）×4，伴随 `disp_cc_mdss_{pclk1,pclk0,byte1,byte0}_clk_src: orphan reparent failed: -110` ×4，`msm_dsi ae94000.dsi: Failed to create device link (0x180) with supplier ae96000.dsi` ×1 | **32/32 boot（11-15 起全部内核 vk189-suspend -00002/-00005）含当前 GOOD boot**；11-14 及更早 0 命中（旧核） | dispcc 探测次序噪声，随 11-15 内核引入；**不是 Q28 指纹**（与 M8 dispcc MDSS 复位线程同域，`archive/topics/upstream/upstream-status-20261026.md:15`） |
| phoc `Atomic commit failed: Device or resource busy` | 全部有桌面的 boot，计数 56–219（**当前 GOOD boot=157**） | phoc↔droidloom/Waydroid 抢卡背景噪声 |
| `Modesetting with 1904x3040 @ 165.000 Hz` | 各 boot 1–10 次 | 灭屏/亮屏动作，非异常 |

### 族 6 —— 当前 boot（GOOD）显示链路实况（boot 0，`dmesg` 原文）
```
[    0.304375] [     T74] DSI PLL(0) lock failed, status=0x00000000
[    0.304392] [     T74] disp_cc_mdss_pclk1_clk_src: orphan reparent failed: -110
...（pclk0/byte1/byte0 同型，共 4 组）
[    0.322616] [     T74] msm_dsi ae94000.dsi: Failed to create device link (0x180) with supplier ae96000.dsi for /soc@0/.../panel@0
[    3.906328] [     T74] novatek-nvt36xxx-spi spi0.0: registered NVT36xxx touchscreen as panel follower
[   10.406079] [     T74] msm_dpu ae01000.display-controller: bound ae94000.dsi (ops dsi_ops)
[   10.406093] [     T74] msm_dpu ae01000.display-controller: bound ae96000.dsi (ops dsi_ops)
[   10.447565] [     T74] msm_dpu ae01000.display-controller: boot framebuffer mapped before SID switch: iova=0x00000000fc800000 size=2b00000 ...
[   10.474297] [     T74] [drm] Initialized msm 1.13.0 for ae01000.display-controller on minor 0
```
```
# /sys/class/drm（boot 0 现场）
card0-DP-1/status   = disconnected   dpms = On
card0-DSI-1/status  = connected      dpms = Off        （采集时屏灭，接口 connected）
card0-DSI-1/modes   = 1904x3040（×5 档）
# cmdline 关键项
msm_drm.dsi_display0=qcom,mdss_dsi_elden_nt36523_csot_3k_dsc_vid: hqsysfs.pcba_stage=SOVP ...
androidboot.slot_suffix=_b  elden_root=LABEL=linux17  panic=15 console=ttyGS0,115200
```
boot 0 看门狗状态：`phoc=yes phosh=yes`、`count=0`、无 disable marker——日常线（b 槽直启）当前健康。

---

## ④ 已否证假设（带证伪证据）

| # | 假设 | 证伪证据（命令/数据） |
|---|---|---|
| 1 | 「17 个无关机标记的 boot = 硬件掉电」 | 全 67 boot 的 `-k` 与尾部 grep `Kernel panic|Oops|end trace|BUG:|vblank wait|command DMA timeout|DMA timeout` **0 命中**；且 `reboot2` 本身产生完整关机序列（`ff2bd090` 有 att 行 + `Reached target reboot.target`），`3f7486d3` 的缺尾可归因刷屏竞速。#620 判据下不得写掉电（`PITFALLS/README.md:318`） |
| 2 | 「`DSI PLL(0) lock failed` 是 Q28 坏发指纹」 | 32/32 boot（11-15 起）命中，含当前 GOOD boot（boot 0，`dmesg` 0.30 s）；随 vk189-suspend 内核引入，与好坏发无关（③-族5） |
| 3 | 「`Atomic commit failed: EBUSY` 指示坏发」 | 当前 GOOD boot 157 次、全部桌面 boot 56–219 次（③-族5） |
| 4 | 「干净关机标记 ⇒ 不是看门狗重启」 | `reboot2` 无参 = 正常重启（`rootfs/persistent-overlay/q28-boot-watchdog.sh` 尾部逻辑 + `ff2bd090` 实例） |
| 5 | 「watchdog `card=no` ⇒ msm 真没 bind（真坏发）」 | 11-16 14:48 簇三条 `card=no` 的 boot journal 里 phoc 全部 `Initializing DRM backend for /dev/dri/card1 (msm)` + `DSI-1 connected`（#667 efifb/card1 机制；b 槽直启才是 card0） |
| 6 | 「watchdog 日志时间戳可做时间线」 | 146/170 行假钟（64 行逐字相同 `2026-10-17T05:54:20`、82 行 1970）；`RTC=1970-01-08` 实测（②.1）；journal 侧同染（67 boot FIRST ENTRY 冻结 `2026-11-05 23:40:2x`） |
| 7 | 「`grep 'Initialized msm'` 可判定 msm 是否 bind」 | 对 38 个 phoc 正常用卡的 boot 假阴性（旧核 dmesg 级别/限流），判据须改用 phoc `Initializing DRM backend` 行（③-族2） |
| 8 | 「sig（vblank/DMA/panel 三特征）仍在把关」 | 真实日志 **`sig=yes` 全库 0 次**（含今日真坏发 `378fb95f`）；特征只覆盖 #228 时代 STORM 形态，对今日「msm 缺席但内核无错」形态失明（`grep -c` 实测） |
| 9 | 「11-05 深夜 12 个短 boot 是 Q28 STORM 群」 | 11 个为假钟短 boot，末端 `23:40:2x–4x`；当晚 = R21 UEFI 引导 ladder 实验（`HISTORY/days/2026-11-05.md:16-20`），且 phoc 全部 `card0 (msm)` 打开成功 |

---

## ⑤ 未解决缺口（只列事实边界，不给结论）

1. **3 条带真实时间的 att 事件对不上任何 journal boot**：`11-10 22:18:04`（±3 min 内无 boot 末端；11-10 17:42:28 之后直到 11-11 13:53:06 无 boot）、`11-16 11:32:40`、`11:34:30`（11:30:04 与 11:36:04 之间塞不进两个「uptime≈85 s 后重启且时钟已同步」的 boot——同步时刻实测都晚于 84 s 判定点）。候选解释(a)这些 boot 的 journal 尾部整体丢失（machine-id 目录仅一个 `4c13dacf…`，排除多 machine-id）、(b)戳来自未知中间态假钟。**未找到**能同时咬合三者的机制。
2. `378fb95f`（真 msm 缺席那台）为何以干净 systemd 重启收场、谁发起——journal/日志均无记录；其 phoc 反复重启循环（11:35:49 失败→11:35:55 再启）说明 greetd 在拉活。
3. 「msm bind + phoc modeset 成功但屏黑」状态是否存在（③-族4 修正条目）——需要目视记录与 journal 的逐 boot 绑定（现有照片 31/32 的 boot 归属**未定**：mtime 15:10:23，内容只能确认是 v8 臂 `earlycon=efifb` 路径、屏显 dmesg 至 15.9 s `Unpacking initramfs...`）。
4. 看门狗修复的**源漂移**：设备在跑修复版 `d694c147…`（= `packaging/elden-userland/files/usr/local/sbin/q28-boot-watchdog.sh`，sha256 实测一致），但 `scripts/q28-watchdog.sh:13` 的 `PAY=` 仍指向旧 card0-only 版 `rootfs/persistent-overlay/q28-boot-watchdog.sh`（sha `709e9eb8…`，`:38-40`）——再跑一次 `install` 会把 #667 的修复**回退**。
5. watchdog 事件进 journal 的覆盖率低：8 条真事件行只有 2 条入账（14:5x 簇）；logger 通路在部分 boot 不可用原因未查。
6. 早期时钟被钉在 `2026-11-05 23:40:21–27` 的机制未定位（非 RTC 现值；`fake-hwclock` 服务 not-found）。
7. ramoops 在 GRUB v8 臂 boot 被禁（`journalctl -b ff2bd090 -k`：`ramoops: every zone overlaps the initrd (0xc1ab0000-0xc584a5e0); ramoops disabled for this boot`），pstore 现为空——按 #620，**空 pstore 不能作为「无 panic」的证据**；b 槽 boot ramoops 注册成功但也无残留记录。
8. 10 月全部事件（含 `attempt 1/2 uptime=77.14` 那台）无 journal（轮转窗口外），四列对账不可做。

---

## ⑥ 下一步实验（可执行 + 判据；均为建议，本档未执行）

1. **per-boot msm 缺席普查（只读，补全 67 boot 表的族 2 列）**
   `ssh elden-root 'while read id; do journalctl -b $id --no-pager -q | grep -am1 "Initializing DRM backend" >/dev/null || echo NOCARD $id; done < /tmp/bootids.txt'`
   判据：无 phoc DRM 行 = msm 缺席 boot（本档已跑，11-15 起仅 `378fb95f`）。
2. **串口先于按电源**（README 串口通道小节）：POR 前 `nohup python3 scripts/serial-tap.py >/tmp/tap-$(date +%s).log 2>&1 &` 再冷启。判据：坏发那发拿到 ttyGS0 dmesg 到死点，区分「msm 不 bind」（族 2）vs「bind 后屏黑」（族 4 新态）——这是 ⑤-3 的唯一直接闭合手段。
3. **看门狗 DRYRUN 观察器（不动作、只记账）**：`ssh elden-root 'Q28_WD_DRYRUN=1 Q28_WD_WAIT=90 sh /usr/local/sbin/q28-boot-watchdog.sh; tail -3 /var/log/q28-watchdog.log'`；同时让新行带 boot_id（`logger` 已带，log 行需加 `$(journalctl -o export|head -1)` 或 `cat /proc/sys/kernel/random/boot_id`）。判据：下一次 ⑤-1 类事件时，log 行 ⇄ journal boot 一一对应，缺口 1 变为可归因。
4. **pstore 能力验证（只在 RAM 起核内做，禁日常线）**：b 槽形态 boot（initrd 不压 ramoops 区，见 `20-back-to-b.txt`「本次 b 槽无 ramoops 冲突行」）里 `echo 1 > /proc/sys/kernel/sysrq; echo p > /proc/sysrq-trigger; ls /sys/fs/pstore`。判据：pstore 出现 console-ramoops 文件 = 取证通路建立；GRUB 臂则要先把 initrd 挪出 `0xc1ab0000–0xc584a5e0` 或用 `elden-noramoops.dtb` 对照臂。
5. **修源漂移（防 #667 回退）**：把 `scripts/q28-watchdog.sh:13` 的 PAY 改指 packaging 版或同步两份文件；判据：`sha256sum` 两仓文件 = 设备 `/usr/local/sbin/q28-boot-watchdog.sh`（`d694c147…`）。
6. **RTC/时钟**：接受「早期时钟不可信」并让取证脚本一律用 uptime/monotonic 对齐（本档 ②.1 判据）；若要真修（`hwclock -w` 时机/电池域）超出本档授权，**上报用户决策**。

---

## ⑦ 引用清单

**设备（只读 ssh，eld-en U1 boot_b/boot_a 混合，采集 2026-11-16 15:40–16:05 CST）**
- `/var/log/q28-watchdog.log`（170 行 / 10042 B / mtime 14:58:44；NUL 段：117 B @ byte 9036 = 行 164 前）；原文摘录见 ①②③。
- `/usr/local/sbin/q28-boot-watchdog.sh`（修复版 sha256 `d694c147b3bb…`；`drm_cards()/have_card()` @ `:42-49`）。
- `/proc/cmdline`、`/sys/class/drm/card0-{DSI-1,DP-1,Writeback-1}/{status,dpms,modes}`、`timedatectl`、`/sys/class/rtc/rtc0/{time,date}`、`/sys/fs/pstore`（空，已挂载 pstore）、`/var/lib/q28-watchdog/count`（boot 0 = 0）——原文见 ②.1、③-族4、③-族6。
- `journalctl --list-boots`（67 boots）；`journalctl -t q28-wd`（仅 2 行：14:56:10 ∈ `ff2bd090`、14:58:45 ∈ `bcd8467b`）；`journalctl -b ff2bd090 -k`（ramoops overlaps initrd → disabled）；各 boot 特征 grep 结果见 ③/④。

**仓库**
- `rootfs/persistent-overlay/q28-boot-watchdog.sh:1-6,38-40`（判据/uptime/sig 定义与旧 have_card）；`scripts/q28-watchdog.sh:13`（PAY 漂移，⑤-4）。
- `packaging/elden-userland/files/usr/local/sbin/q28-boot-watchdog.sh:42-49`（修复版 have_card）。
- `PITFALLS/README.md:318`（#620 判据纪律）；`PITFALLS/sessions/303-q28看门狗只认card0-UEFI路径card1误判.md`（#667 全文，含「uptime 98 s=真坏发」的待修正表述）。
- `reports/q28-DOSSIER.md:10,18,22,498-503`（根因口径沿革：DYN pclk 判别量本发不成立/软件侧无剩余靶点）。
- `reports/q28-watchdog-20261012.md:11,33,35`（selftest 产生的 `sig=yes` 行仅存在于自测，非真实日志）。
- `reports/artifacts/uefi-daily-v8-20261116/README.md`（14:03–15:36 时序、异常 A/B、串口通道、v10 验证）＋ `40-loop-boot-journal.txt`（14:57 现场 boots 表 + att2 行原文）＋ `41-q28-wd-unit.txt`（unit 定义 + 部署脚本快照 + count=2）＋ `42-q28-watchdog-log.txt`（card1/phoc RUNNING）＋ `50-serial-tap-bslot-boot.log`（串口首通，missed 72606 B）＋ 照片 `30-cold-por-grub-menu.jpg`（14:49:12）、`31/32-second-boot-dmesg-*.jpg`（efifb 屏显 dmesg 至 15.9 s）。
- `HISTORY/days/2026-11-05.md:16-20`（当晚 R21 引导 ladder 实验 = 假钟短 boot 簇归属）。
- `archive/topics/upstream/upstream-status-20261026.md:15`（M8 dispcc/DSI 上游风向，族 5 噪声的相关线程）。
