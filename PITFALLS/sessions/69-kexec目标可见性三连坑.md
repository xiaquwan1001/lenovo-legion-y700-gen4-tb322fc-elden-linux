# kexec 目标可见性三连坑：白名单吞 token、继承 dwc3 断网、pstore 字节序≠时间序

> 日期：2026-10-24 · 会话：kexec/冷暖复盘（`reports/kexec-target-boots-20261024.md`）
> 适用：任何「hash 跳到新内核后，怎么知道它跑到哪」的场合（kexec、远程刷写、自复位 experiment）。

## #378 「目标内核可见性」的三个静默陷阱（本轮各踩一次，共三次上机）

| # | 陷阱 | 现象 | 判据 / 修法 |
|---|---|---|---|
| a | **`/init` 的 cmdline 解析是白名单** —— `for arg in $(cat /proc/cmdline); do case …` 只认 `elden_root` / `ubuntu_root` / `elden_nocamera` | 传 `kexec_marker=1` 被**静默丢弃**，marker 段整段不执行；两次上机都「什么都没写、设备卡住」，看起来像内核挂了 | 自定义 token 必须同时加进白名单（`initramfs/init` 的 case 分支）。**别用「文件没出现」反推「没跑到」，先确认 token 真的被解析** |
| b | **`mask=1` 跳过 `device_shutdown()` ⇒ dwc3/USB 继承 live 态** | 目标内核起来了但**无网络、无串口**（NCM `carrier=0`，宿主机只剩一个僵死的 `1d6b:0104` 描述符）；靠 SSH/串口抓目标 = 永远失败 | 目标侧**唯一可靠通道 = 自己往磁盘写文件**。网络/串口判据在 kexec 臂上作废 |
| c | **pstore console record 是「按行覆盖」而非环形追加** | 同一个 122 891 B 记录里同时有游标内核关机尾（`[KD] stage=11a … Restarting system`，294 s）和目标内核 `/init`（126 s）；字节序**不等于**时间序，行长短不一还会留残影（`7"3.0/rc'-`） | pstore 只做**存在性锚点**（有/无某串）；时间线必须来自目标自己写的 dmesg 文件 |

## 落地的仪器（已验证）

`initramfs/init` 的 `kexec_marker_dump()`：带 `kexec_marker=1` 时，在 **`switch_root` 之前**
（所以磁盘根目标也必走）把三件东西写进 `var/tmp/`：

- `kexec-marker.txt`：`uptime / kernel / ts / cmdline`
- `kexec-target-dmesg.txt`：目标内核**原始 ring buffer**
- `kexec-target-irqs.txt`：`/proc/interrupts` + `/proc/iomem`

验证（vk152 载具，目标=同 Image+同 DTB，initrd `2e9c9e1f30e49ca5`）：
`kexec-marker.txt` = `alive uptime=126.57 kernel=7.3.0-rc7-… probe=K5`，dmesg **1402 行**，
即目标这次启动 **0 → 126.58 s** 的完整日志（此前一律「静默挂死、看不到」）。

## 配套口径

- `ssh 'sync; kexec -e'` 会挂到 TCP 超时才返回（本轮 ~350 s），**不能用它的返回时间当复位时间**；
  要立刻开始轮询就 `setsid … &` 把 ssh 放掉。
- 目标复位回 `boot_b` 的时间稳定在 **+310~330 s**（3 次一致），判据取「回来时的 `/proc/uptime` + `/proc/cmdline`」。
