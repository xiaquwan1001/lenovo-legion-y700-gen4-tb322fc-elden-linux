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

## #379 SM8750 的 `GICR_CTLR.EnableLPIs` 是 **RES1**：写过 1 之后再也清不掉

- 实测（vk157，`/sys/kernel/its_quiesce/its_quiesce` 触发，内核自己写盘）：
  `RD cpu0..cpu7 CTLR 00000005 -> 00000005` —— 8/8 全部写 0 无效。
- 后果：**任何**「进来时 LPIs 已使能」的内核都**不能**禁用 LPI、也**不能**重编程
  `GICR_PROPBASER/PENDBASER`（架构要求先 disable+quiescent）⇒ 只能**沿用**原表。
- 因此跨 kexec 时 LPI 表必须被保留（上游靠 EFI `efi_mem_reserve_persistent()`）；
  **DT 启动没有这条路**，`fdt_add_mem_rsv()` 实测 `-3 (-FDT_ERR_NOSPACE)`（ABL 的 live DTB `rsv 0->0`），
  且 kexec 在 `kexec -l` 时就克隆完 FDT，跳转时再改已晚。
- 可行解 = **incoming 侧 `memblock_reserve()` 认领**继承的表（在 `memblock_free_all()` 之前），
  让 `RDIST_FLAGS_RD_TABLES_PREALLOCATED` 成立、走 preallocated 路径。详见
  `TASKS/sessions/2026-10-24-kexec-its-lpi-claim.md`。
- 误判风险：`reboot`/`kexec` 后看到 `Failed to disable LPIs` 不要以为「驱动写错了」，**是硬件 RES1**；
  也不要再尝试「退出侧把 LPI 清掉」这条路（已否决）。

## #380 kexec 实验臂里**别把兜底看门狗关掉**（`elden_q28_nowd`）——否则设备会停在无网络态

- 2026-10-24 实测：为了观察目标 userland 之后的现场，在目标 cmdline 加 `elden_q28_nowd`（停用 Q28 看门狗）。
  结果目标起来后 **无 card0、无 dwc3/USB**（继承活态）⇒ 既不能 SSH 也没有看门狗把它重启 ⇒ 设备在无网络态
  **挂了 17 分钟以上**，只能人工长按电源。
- 规约：kexec/复位类实验臂**保留兜底看门狗**（它正好把「card=no」的坏台架重启回可用线）；
  要看得更晚，就把现场**落盘**（`/etc/local.d/elden-bootlog.start` 写 `/var/log/dmesg-<boot_id>.txt`），
  不要去延长一个无网络的台架寿命。
- 配套：`mask=1` 跳过 `device_shutdown` ⇒ 目标侧 **dwc3 与显示都留在 live 态**（`no UDC after 20s`、drm 只有 `version`），
  这是 kexec 臂「能跑内核但没显示没网」的默认结果，不是新 bug。
