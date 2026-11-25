# 按需使用节点 + 休眠：在既有 PM 方案之上的增量深化（TB322FC · 主线 7.3.1 · vk189）

> 立：2026-11-25（规划 lane）。**设备不在线 ⇒ 本文件所有设备侧命令都是「待上机判据」，本轮一条都没跑**；
> 本轮唯一写入 = 本文件；未改仓内既有文件（含 `.pi/plans/2026-11-25-device-power-management.md`）、未 ssh/adb、未做 git 写操作。
>
> 与既有方案的关系：**不重复正文，只做增量与引用**。
> 基线 = `.pi/plans/2026-11-25-device-power-management.md`（下称 **PLAN**：`mem_sleep=[s2idle] deep`、本 boot `suspend_stats 0/0`、
> `cpuidle` 每 CPU 仅 `WFI+cpu-sleep-0`、GPU `min_freq` 被我们自己钉 525 MHz、`energy_model` 有 `cpu0/cpu6`、
> 无 devfreq 的只有 display/interconnect、UFS 只 100/403 两档、`power_now` 空）。
> 实测补充 = `reports/thermal-baseline-20261125.md`（空载 cpuss 39.9–40.3 °C、无限流、95% 时间 556 MHz）；
> 时间基线 = `reports/q28-DOSSIER.md` §t-0/t-2 **T1**（已装 `fake-hwclock`；**硬件 RTC 不可写**：`hwclock -w` 报 `ioctl(RTC_SET_TIME)` 失败）；
> 两条约束坑 = `PITFALLS #692`（`hexagonrpcd` attach ADSP sensor PD 硬崩整机）、`PITFALLS #726`（power_supply 的 `usb_type` **方括号里才是当前值**）。
>
> **三条纪律（贯穿全文）**：① 第一步永远不是改内核；② 每条动作必须带回退命令；③ `deep` **不进日常线**（PLAN §4 已裁决：本机固件不支持，7.2 时代进 `mem` 黑屏死机、vk130 上 `deep` 也只站 1.43 s）。

---

## 0. 本轮新增的四个「抓手」（都是既有方案里没有的观测/操作面）

| # | 抓手 | 路径（本内核已确认编译进） | 为什么值得单列 | 命令证明它在 |
|---|---|---|---|---|
| **N1** | **`pm_test` 分级试挂**（`CONFIG_PM_SLEEP_DEBUG=y`） | `/sys/power/pm_test`（`none [freezer] devices platform`） | 能**完整跑一遍全设备 suspend/resume 回调**却在进入低功耗前 5 s 自动返回 ⇒ 把「BT `-110`／ath12k `-110`」这类**回调期失败**在**零失联风险**下先打出来 | `cat /sys/power/pm_test`（**文件存在即已编进**；主机侧源码证据 `grep -n 'CONFIG_PM_SLEEP_DEBUG=y' build/daily/.config`） |
| **N2** | **`wakeup_sources` 总账**（`CONFIG_PM_SLEEP_DEBUG=y`） | `/sys/kernel/debug/wakeup_sources`（**0444**，debugfs 根下） | 一次列全「谁能把系统叫醒 + 谁在拦着不让睡」：`active_count / prevent_sleep_time / max_time_ms`。比 `dmesg` 猜快得多 | `timeout -k 5 10 head -1 /sys/kernel/debug/wakeup_sources; timeout -k 5 10 wc -l /sys/kernel/debug/wakeup_sources` |
| **N3** | **谁把我叫醒的**：`/sys/power/pm_wakeup_irq` | `/sys/power/pm_wakeup_irq`（RO，无唤醒时 `ENODATA`） | 配合 `/proc/interrupts` 直接给出**唤醒源 IRQ 号**（#719 那轮就是 `pm_wakeup_irq=22`）；比翻 `dmesg` 定位快 | `timeout -k 5 5 cat /sys/power/pm_wakeup_irq; echo rc=$?` |
| **N4** | **`pm_print_times` = 1** | `/sys/power/pm_print_times`（RW，默认 `=initcall_debug` 即 0） | 打开后 dmesg 逐设备打 suspend/resume 耗时 ⇒ **恢复时延预算**第一次可以量化（PLAN 的 S2/S3/S4 都没有这一项） | `timeout -k 5 5 cat /sys/power/pm_print_times` |

> 另有一条**必须记住的否定结论**：`/sys/power/suspend_stats/{last_hw_sleep,total_hw_sleep,max_hw_sleep}` 在本机**永远是 0**——
> 这三个值只由 x86 PMC 驱动调 `pm_report_hw_sleep_time()` 写入（`kernel/power/main.c:442`，全树唯二调用点在
> `drivers/platform/x86/{intel/pmc/core.c,amd/pmc/pmc.c}`）。**别拿它当 s2idle 驻留时长**；
> 驻留判据只能取 dmesg `PM: suspend entry`/`PM: suspend exit` 的**单调时钟差值**（同 `PITFALLS #719` 的纪律）。

---

## 1. 节点级按需清单

### 1.0 一次性普查（只读，≈ 2 min；先把「现状」变成可比的数字）

```sh
# 全量体检（设备侧本地跑，输出落 /tmp，避免 SSH 交互把 load 拉起来）
timeout -k 5 10 sh -c '
{ echo "== UTS/boot =="; uname -r; cat /proc/sys/kernel/random/boot_id
  echo "== power =="; cat /sys/power/state /sys/power/mem_sleep
  echo "== suspend_stats =="; for f in success fail last_failed_dev last_failed_errno last_failed_step; do printf "%s=%s " "$f" "$(cat /sys/power/suspend_stats/$f)"; done; echo
  echo "== genpd =="; cat /sys/kernel/debug/pm_genpd/pm_genpd_summary
  echo "== devfreq =="; for d in /sys/class/devfreq/*; do printf "%s cur=%s min=%s max=%s gov=%s poll=%s\n" "${d##*/}" \
      "$(cat $d/cur_freq 2>/dev/null)" "$(cat $d/min_freq 2>/dev/null)" "$(cat $d/max_freq 2>/dev/null)" \
      "$(cat $d/governor 2>/dev/null)" "$(cat $d/polling_interval 2>/dev/null)"; done
  echo "== rproc =="; for r in /sys/class/remoteproc/remoteproc*; do printf "%s name=%s state=%s\n" "${r##*/}" "$(cat $r/name)" "$(cat $r/state)"; done
  echo "== cpuidle =="; cat /sys/devices/system/cpu/cpuidle/current_driver /sys/devices/system/cpu/cpuidle/current_governor
  for s in /sys/devices/system/cpu/cpu0/cpuidle/state*; do printf "%s:%s usage=%s time=%s\n" "${s##*/}" "$(cat $s/name)" "$(cat $s/usage)" "$(cat $s/time)"; done
  echo "== wakeup_sources(前 15 行) =="; head -15 /sys/kernel/debug/wakeup_sources
} > /tmp/pm-census.txt 2>&1; wc -l /tmp/pm-census.txt'
```

判据：文件里 `pm_genpd_summary` 有 `power-domain-cpu0..7 / cluster0 / cluster1 / system` + rpmhpd 域（`cx/mx/mmcx/gx/lcx/...`）+ GCC GDSC；
`devfreq` 至少 `3d00000.gpu` / `1d84000.ufs`；`rproc` 两行 `adsp`/`cdsp`（名字对应 `remoteproc0`/`remoteproc1`，见 `reports/t18-usb-charging-triage-20261111.md`）。
失败即停：`debugfs` 未挂（`/sys/kernel/debug/pm_genpd` 不存在）⇒ 先 `timeout -k 5 5 mount -t debugfs none /sys/kernel/debug`，仍无 ⇒ 本节的「可观测」结论全部记「不可判」。

回退：无（纯读）。

---

### 1.1 power domain（genpd）：**可观测、不可直接关**

| 项 | 内容 |
|---|---|
| 路径 | `/sys/kernel/debug/pm_genpd/pm_genpd_summary`；每域 `/sys/kernel/debug/pm_genpd/<域>/{current_state,idle_states,idle_states_desc,active_time,total_idle_time,devices,sub_domains,perf_state}`（`drivers/pmdomain/core.c:4111-4146`，全部 **0444**） |
| 现状 | PLAN 已测：`energy_model` 有 `cpu0/cpu6`、EAS 在；cpu 域拓扑按 OSI 模式初始化（11-25 实测 `psci: OSI mode supported.` + `Initialized CPU PM domain topology using OSI mode`） |
| 运行期可否关 | **不能直接关**。genpd debugfs **没有** writable 属性；唯一合法路径 = 让**挂在域上的设备的 runtime PM 进入 suspended**（见 §1.2），域才可能下电。反向旋钮 `power/pm_qos_no_power_off` 只能**钉住不下电**（调试用），不能强制下电 |
| 关掉的代价/风险 | 试图「手工关域」（写寄存器/`echo` 域状态）**没有任何稳定接口**，且 cmdline 已带 `pd_ignore_unused clk_ignore_unused`（PLAN §2 M7）⇒ 越权操作等于自己重演 bring-up 期显示/相机不 probe 的失败模式。**禁止**作为动作项 |
| 判据命令 | ① 域是否真在下电：两次采样 `active_time`/`total_idle_time` 差分（`for f in active_time total_idle_time; do cat /sys/kernel/debug/pm_genpd/power-domain-system/$f; done`），间隔 60 s，`total_idle_time` 明显增长 ⇒ 域真进了低功耗；② `current_state` 读 `off`/状态号 |
| 回退命令 | 无（只读）。若曾为调试写 `pm_qos_no_power_off=1`：`echo 0 > <dev>/power/pm_qos_no_power_off` |

> 结论边界（沿用 PLAN §2.1）：**genpd 不是本轮的动作面，只是度量面**。本轮所有节能都必须落在「设备 runtime PM 状态」而不是「域开关」上。

---

### 1.2 runtime PM 状态与 usage_count：**唯一真正可关的通用旋钮**

| 项 | 内容 |
|---|---|
| 路径 | 每设备 `/sys/devices/.../<dev>/power/{runtime_status,runtime_usage,runtime_active_kids,runtime_active_time,runtime_suspended_time,runtime_enabled,control,autosuspend_delay_ms}`（`drivers/base/power/sysfs.c:121,179,558`；`runtime_usage` 需 `CONFIG_PM_ADVANCED_DEBUG=y` —— 本内核 **=y**） |
| 现状 | 上一轮未普查。已知人为例外：USB UDC 的 `power/control=on` 是**我们自己钉的**（`packaging/elden-userland/files/usr/local/sbin/usb-gadget:19`，那是 SSH 生命线，PLAN §4 已判「不做」） |
| 运行期可否关 | **可**。`control` 是 RW（`auto`/`on`）：`auto` = 允许 runtime 自动挂起该设备；`on` = 强制常开。真正「关设备」是驱动在 `runtime_suspend` 里做的（关 clock/PD/regulator），用户态只能**放行**它 |
| 关掉的代价/风险 | ① `control=auto` 会把驱动长期没走过的 runtime 挂起/恢复路径打开 ⇒ 首次可能撞 resume 失败（ath12k 类 `-110`）；② `control=on` 反向增加功耗；③ 改 UDC 的 `control` = 立刻断 SSH（**禁止**） |
| 判据命令 | 「谁在空载时还 `active`」= 按需名单的输入：<br>`timeout -k 5 60 sh -c 'for f in $(ls /sys/devices/platform/soc@0/*/power/runtime_status 2>/dev/null); do [ "$(cat $f)" = active ] && echo "${f%/power/runtime_status} $(cat ${f%status}runtime_usage 2>/dev/null)"; done'`<br>再按 usage 降序：`| sort -k2 -nr | head -20`<br>溯源用 tracepoint：`echo 1 > /sys/kernel/debug/tracing/events/rpm/enable; ...; grep -c rpm_status /sys/kernel/debug/tracing/trace`（`include/trace/events/rpm.h:84,128`） |
| 回退命令 | 对任何改过的设备：`echo auto > <dev>/power/control`（默认值；UDC 除外，绝不改） |

---

### 1.3 remoteproc（ADSP / CDSP）：**技术上可关，工程上禁作节能旋钮**

| 项 | 内容 |
|---|---|
| 路径 | `/sys/class/remoteproc/remoteproc{0,1}/{name,state,recovery,coredump,firmware}`（`drivers/remoteproc/remoteproc_sysfs.c:66,128,160,209,219`，`state` 是 **RW**，可写 `start`/`stop`） |
| 现状 | `remoteproc0=adsp`、`remoteproc1=cdsp`，两者 `state=running`（`reports/t18-usb-charging-triage-20261111.md:26-27`） |
| 运行期可否关 | **是**（`echo stop > .../state`，秒级）；`echo start` 重新加载固件（`qcom_q6v5_pas`，ADSP 分支固件 `qcom/sm8750/adsp.mdt`） |
| 关掉的代价/风险 | **见下方依赖表。ADSP stop = 直接摧毁登录通道与全部电能口径 ⇒ 列为「禁止动作」，只作故障注入/取证手段。** |
| 判据命令 | 停之前先记依赖面（全部只读）：<br>`ls /sys/class/power_supply/`；`ip -br a`；`ls /sys/class/typec/ 2>/dev/null`；`ls /sys/class/sound/`；`timeout -k 5 5 cat /sys/kernel/debug/qcom_glink/* 2>/dev/null \| head`；`dmesg \| tail -50` |
| 回退命令 | `echo start > /sys/class/remoteproc/remoteproc0/state`；ADSP 重启后**客户端不一定自动重绑**（`pmic_glink`/`ucsi_glink`/`q6apm` 都是 glink/rpmsg 客户端）：先 `systemctl restart charge-watch`，仍缺节点 ⇒ 只能 `reboot`（**这就是「不做」的理由**） |

**依赖表（stop 后谁死）——每条给出证据类别**

| 子系统 | 依赖 | 证据 | stop 后现象 |
|---|---|---|---|
| **充电/电池（battmgr）** | ADSP（`pmic_glink` → `qcom_battmgr`） | 本内核 `CONFIG_QCOM_PMIC_GLINK=y`、`CONFIG_BATTERY_QCOM_BATTMGR=y`；`scripts/charge-ctl.sh` / `charge-watch.sh` 头注「ADSP 默认给 100 mA，需要人顶回」 | `/sys/class/power_supply/qcom-battmgr-{bat,usb}` 消失 ⇒ **所有功耗测量和充电控制同时归零**；限流回落到固件默认 |
| **UCSI / PD / role-switch（→ USB-NCM 登录通道）** | ADSP（`ucsi_glink`，`CONFIG_UCSI_PMIC_GLINK=y`） | `reports/m3v5-connector-bind-rootcause-20261030.md:128`（connector 侧由 **PDR(ADSP UP)** 触发的异步 work）、`reports/m1-73-dts-fix-catchup-20261013.md:398`（「优先怀疑 ADSP/UCSI 未起导致 role-switch 端点 defer」） | Typec 端口状态丢失 → PD 停止；role-switch 端点可能重算 ⇒ **gadget 有可能被解绑 ⇒ SSH 直接断**（高置信、未单变量） |
| **DP 外接输出** | ADSP（UCSI altmode）+ 显示链 | `reports/best-state-and-gap-20261122.md:50`（「UCSI/PPM 走 ADSP」） | 外接屏起不来 |
| **音频** | ADSP（`q6apm`/GPR/APM） | `reports/m3-3-audio-thermal-slice-20261013.md:103,109` | 播放/录音全死（`q6apm` 客户端断） |
| **传感器（SSC）** | ADSP（`fastrpc-adsp` + glink） | `PITFALLS #692`、`reports/debian-root-accounts-sensors-20261026.md:43` | 传感器不可用；**且 attach ADSP sensor PD 本身有硬崩整机史（#692）⇒ 这条线连「实验」都不该做** |
| **NPU / fastrpc-cdsp** | **CDSP**（`remoteproc1`） | 本内核 `CONFIG_QCOM_Q6V5_PAS=y`；`/dev/fastrpc-cdsp` | CDSP stop 只掉 NU*/compute 加速，**不碰音频/充电/USB** ⇒ 若真要做「按需关核」实验，**只有 CDSP 是候选**（且须 Waydroid/相机都没在用） |

> **裁决**：ADSP = 禁止关（关掉的代价 = 失去唯一登录通道 + 失去全部功耗口径，收益无法测——因为测功耗的工具本身也被关掉了）。
> CDSP = 允许做一次「零收益确认实验」（阶段 2，带 WiFi SSH 兜底），但先把结论写成「不发生活动时 CDSP 是否本来就已空闲」——
> 若 `cat /sys/class/remoteproc/remoteproc1/state` 常为 `running` 且 `pm_genpd_summary` 里 cdsp 域一直 `on`，才有节能空间；否则关它没有意义（还丢 NU*）。

---

### 1.4 WCN（WiFi `ath12k` + BT `hci0`）：**可关，但 WiFi 是唯一备份登录通道**

| 项 | 内容 |
|---|---|
| 路径 | WiFi：`/sys/bus/pci/devices/0000:01:00.0/`（`ath12k_wifi7_pci`，见 `reports/suspend-pcie-l2-blocker-20261020.md` §2 原文）、`.../power/{control,runtime_status}`、`.../link/l1_aspm`（`drivers/pci/pcie/aspm.c:1759,1799`）、`/sys/class/net/wlan0/`、`iw`/`rfkill`；BT：`/sys/class/bluetooth/hci0`、`rfkill`、`/sys/devices/platform/soc@0/*/serial*`（serdev `serial0-0`） |
| 现状 | `ath12k` 与 `hci_qca` 在机；`net-selfheal.sh` 强制 `iw ... power_save off`（ath12k 突发丢包，`reports/net-https-mtu-rootcause-20261018.md`）；`wifi-scan-refresh.service` 每 150 s 全信道扫描（4–6% 占空比） |
| 运行期可否关 | WiFi：**可**（`ip link set wlan0 down` 或 `rfkill block wlan`；**不能 rmmod** —— `CONFIG_ATH12K=y` 编进内核）。BT：**只能 rfkill**（`rfkill block bluetooth`）；控制器的 `vreg_wlan_pmu_*` 常开供电，`rfkill` 不切电源（`packaging/.../sm8750-lenovo-elden.dts:3027-3045` 的 regulator 全挂在 PMU 上） |
| 关掉的代价/风险 | ① **`wlan0` 是「拔掉 USB 后唯一的登录通道」**（PLAN §1.4 路 A）⇒ 关它 = 自己断掉兜底；② `rfkill block bluetooth` 后若马上挂起是安全的，但**反向**（unblock 后 23–25 s 固件下载窗口内挂起）**必 `-110` 弹出整机挂起**（`reports/qca-fw-download-suspend-20261021.md` §1）；③ WoWLAN 需要 WiFi 保持关联（ath12k 支持 `DISCONNECT/MAGIC_PKT/GTK_REKEY/NET_DETECT`，`drivers/net/wireless/ath/ath12k/wow.c:22-26`），`wlan0 down` 后 WoWLAN 一并失效 |
| 判据命令 | `for r in /sys/class/rfkill/*/; do printf "%s %s %s\n" "$(cat $r/name)" "$(cat $r/soft)" "$(cat $r/hard)"; done`；`timeout -k 5 10 iw dev wlan0 link`；`timeout -k 5 10 iw phy phy0 wowlan show`；`timeout -k 5 10 iw dev wlan0 get power_save`；BT 就绪判据**必须看 dmesg 顺序**（不是 sysfs）：`dmesg \| grep -c "QCA setup on UART is completed"`（`rootfs/persistent-overlay/usr-libexec-elogind-system-sleep/50-elden-bt-guard` 头注：`hci0` 在下载期间根本不存在） |
| 回退命令 | `rfkill unblock bluetooth` + `systemctl restart bt-alias`（或 `sh /usr/local/sbin/bt-up.sh`）；`ip link set wlan0 up` + `systemctl restart net-selfheal`；**顺序纪律：unblock 后必须等到 `QCA setup on UART is completed` 再允许任何挂起** |

> 附带发现（**需核，不在本轮改**）：BT 保护钩子装在 **elogind** 的目录 `/usr/libexec/elogind/system-sleep/`，
> 而在机 init 是 **systemd**（PLAN 头「systemd + greetd」、`DEVICE/README.md:42` `/etc/elden-init-mode=systemd`），
> systemd 的钩子目录是 `/usr/lib/systemd/system-sleep/`。**判据**：`systemctl --version | head -1` + `ls /usr/lib/systemd/system-sleep/ 2>&1`。
> 若目录为空 ⇒ 「BT guard 自动生效」这个前提**不成立**，阶段 2 之前必须手工 `rfkill block bluetooth`（本文件全部流程都已按手工前置写）。

---

### 1.5 DRM / DSI 面板：**DPMS 只读，能关的只有「背光」和「合成器路径」**

| 项 | 内容 |
|---|---|
| 路径 | `/sys/class/drm/card0-DSI-1/{dpms,enabled,status}`（`dpms` **0444 只读**，`PITFALLS #456`、`notes-display.md`）；`/sys/class/backlight/aw99706-backlight/{brightness,max_brightness,bl_power}`；面板节点 `panel0: panel@0`（`reset-gpios=<&tlmm 98>`、`backlight=<&backlight>`，`build/daily/.../sm8750-lenovo-elden.dts:2380-2394`） |
| 现状 | `bl_power=4` 能观测到（PLAN S3）；分辨率地板 = 1024（`backlight-floor.service` 每 20 s 回写） |
| 运行期可否关 | **两档**：<br>① **背光关**：`echo 4 > /sys/class/backlight/aw99706-backlight/bl_power`（RW，秒级）——按 `drivers/video/backlight/aw99706.c:339-349`，`update_status` 取 `backlight_get_brightness()`，blank 时返回 0 ⇒ 写 `AW99706_BACKLIGHT_EN=0`，**只是关背光 IC，不停 DSI/面板供电**；<br>② **面板/DSI 关**：只能经合成器（`ScreenSaver.SetActive true` / `loginctl lock-session`）让 CRTC 关；`dpms` 自己不可写 |
| 关掉的代价/风险 | ① **`bl_power=4` ≠ 面板断电**：把它当「面板已关」的证据会把测量口径写错（本文件新增这条纠正）；② 锁屏/熄屏路径有**整机掉电史**（`PITFALLS #694`：`droid-juicer`/`hexagonrpcd` 组合，现均已 mask，但仍属高风险路径）；③ 假熄屏（读回不校验）= 整轮样本作废（`PITFALLS #456`） |
| 判据命令 | `cat /sys/class/drm/card0-DSI-1/dpms /sys/class/drm/card0-DSI-1/enabled /sys/class/backlight/aw99706-backlight/bl_power`；会话内 `gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.GetActive`；**「面板真断」的旁证**：`pm_genpd_summary` 里 `mmcx`/display 域 `total_idle_time` 增长 + `dmesg \| grep -ci "dsi"` 无新错误 |
| 回退命令 | `echo 0 > /sys/class/backlight/aw99706-backlight/bl_power`；`systemctl restart backlight-floor`；会话层 `SetActive false`；异常 ⇒ `systemctl restart greetd`（D12 纪律） |

---

### 1.6 UFS：**只有 2 档、由驱动 gear 决定；能动的只有「允许 runtime 挂起」与「省电档位」**

| 项 | 内容 |
|---|---|
| 路径 | `/sys/class/devfreq/1d84000.ufs/{available_frequencies,cur_freq,min_freq,max_freq,governor,trans_stat}`；设备侧 `/sys/devices/platform/soc@0/1d84000.ufs/{rpm_lvl,spm_lvl,rpm_target_dev_state,rpm_target_link_state,spm_target_dev_state,spm_target_link_state,auto_hibern8,clkscale_enable,power/{control,runtime_status,runtime_usage,runtime_suspended_time}}`（`drivers/ufs/core/ufs-sysfs.c:642-658`、`drivers/ufs/core/ufshcd.c:1813-1881`） |
| 现状 | 频点只有 **100 MHz（low_svs）/ 403 MHz（nom）** 两档（`build/daily/.../sm8750.dtsi:6205-6236` 的 `ufs_opp_table`），与 PLAN 一致 |
| 运行期可否关 | `power/control` = **auto/on**（可改）；`auto_hibern8`/`spm_lvl`/`rpm_lvl`/`clkscale_enable` 都是 **RW**。**但**「降到 100 MHz」不是我们能选的——那是驱动按负载/gear 自己切；手写 `min_freq=100000000` 只是把下限压低，空载本来就在 100 MHz |
| 关掉的代价/风险 | ① `spm_lvl` 调到最深（link `OFF`）能省，但**唤醒时延**上升、且 `qcom` UFS 在深 link 状态下有已知不稳风险；② `auto_hibern8=1` 是省电默认，关掉反而费电；③ 手改 `min_freq` 无收益（不是频率绑定的问题） |
| 判据命令 | `cat /sys/class/devfreq/1d84000.ufs/trans_stat`（各档驻留时间；空载应主要停留在 100 MHz）；`cat /sys/devices/platform/soc@0/1d84000.ufs/{rpm_lvl,spm_lvl,auto_hibern8,power/runtime_status}`；运行期挂起比例：`awk '{print $1,$2}' .../power/runtime_suspended_time .../power/runtime_active_time` |
| 回退命令 | `echo auto > .../power/control`；`echo <原值> > .../rpm_lvl`（先备份读回值）；`echo 1 > .../auto_hibern8`；`echo 1 > .../clkscale_enable` |

> 裁决：**UFS 不进「按需关」名单**（PLAN §4 已判「手调没有稳定接口」）。本文件只把它当**观测项**：`runtime_suspended_time/runtime_active_time` 比例是「存储侧到底有没有睡」的硬指标。

---

### 1.7 interconnect（ICC）：**只有观测面，没有可写旋钮**

| 项 | 内容 |
|---|---|
| 路径 | `/sys/kernel/debug/interconnect/interconnect_summary`、`interconnect_graph`（`drivers/interconnect/core.c:1262-1266`，**0444**）；`qcom,bcm-voters` = RSC |
| 现状 | PLAN 已测：interconnect **无 devfreq 入口** |
| 运行期可否关 | **不能**。带宽投票由消费驱动（display/camera/UFS/PCIe）在做；用户态无 sysfs 写点 |
| 关掉的代价/风险 | 越权关总线 = 直接黑屏/掉盘，**禁止** |
| 判据命令 | `timeout -k 5 10 grep -E "avg_bw|peak_bw" /sys/kernel/debug/interconnect/interconnect_summary \| head -20`（空载若某些 NOC 的 avg_bw 很高，说明有驱动常驻投票 ⇒ 去查那个驱动，而不是调 ICC） |
| 回退命令 | 无（只读） |

---

### 1.8 cpuidle / PSCI：**OSI 已生效，「集群不可管」这条旧结论作废**

| 项 | 内容 |
|---|---|
| 路径 | `/sys/devices/system/cpu/cpuidle/{current_driver,current_governor,available_governors}`；`/sys/devices/system/cpu/cpuN/cpuidle/stateM/{name,usage,time,disable}`（`disable` 是 **RW**）；域空闲 tracepoint `/sys/kernel/debug/tracing/events/power/psci_domain_idle_{enter,exit}/` |
| 现状 | 本内核 `CONFIG_ARM_PSCI_CPUIDLE=y` + `ARM_PSCI_CPUIDLE_DOMAIN=y` + `DT_IDLE_GENPD=y`；governor = **menu**（`CONFIG_CPU_IDLE_GOV_MENU=y`，**TEO 未编入** ⇒ `available_governors` 只有 `menu`，无 A/B 空间）；11-25 实测 **OSI 已启用**（PLAN §3 更正块） |
| 运行期可否关 | 每状态 `disable` **可写**（单变量实验用）；governor **不可换**（只有一个） |
| 关掉的代价/风险 | 禁用 `cpu-sleep-0` ⇒ 只剩 WFI ⇒ 空载更费电，**只会更差**；它的唯一用途是「隔离变量」做诊断。改 `current_governor` 无意义（只有一个） |
| 判据命令 | ① `dmesg \| grep -E "OSI mode supported\|using OSI mode\|using PC mode"`（应见前两条）；② 每状态利用：`cat /sys/devices/system/cpu/cpu0/cpuidle/state1/usage`；③ 域是否真进：`echo > /sys/kernel/debug/tracing/trace; echo 1 > /sys/kernel/debug/tracing/events/power/psci_domain_idle_enter/enable; sleep 30; echo 0 > .../enable; grep -c psci_domain_idle_enter /sys/kernel/debug/tracing/trace`（≫0 ⇒ cluster/system 状态在用） |
| 回退命令 | `echo 0 > /sys/devices/system/cpu/cpuN/cpuidle/stateM/disable`；tracepoint 关回 `echo 0 > .../enable` |

> 增量点：PLAN S5 只判「OSI 有没有」。本文件把它推进到**「域有没有真的进去」+「进去多久」**（`total_idle_time` 差分），
> 因为这决定了「s2idle 时到底省在哪一节」——若域状态在 s2idle 期间本来就被用满，那 s2idle 的收益主要来自**设备被挂起**而不是 CPU 侧。

---

### 1.9 GPU（`3d00000.gpu`）：**本轮唯一「高收益 + 秒级回退」的节点**

| 项 | 内容 |
|---|---|
| 路径 | `/sys/class/devfreq/3d00000.gpu/{governor,cur_freq,min_freq,max_freq,available_frequencies,polling_interval,trans_stat}`；`/sys/devices/platform/soc@0/3d00000.gpu/power/{control,runtime_status}`；GMU `3d6c000.gmu` |
| 现状 | `simple_ondemand`，`cur=min=525 MHz`、`max=1100`、`polling=10 ms` —— **是我们自己的 `gpu-devfreq-tune.service` 钉的**（`scripts/deploy-desktop-shell.sh:279-316`，脚本注释「min_freq 525 MHz（默认 160 MHz）消灭首绘卡顿；代价 = 空闲略耗电」）；上游 OPP 最低档 **160 MHz**（`sm8750.dtsi:3906`） |
| 运行期可否关 | **可**（`min_freq`/`polling_interval` 都是 RW，`devfreq.c:1606,1841`；`min_freq` 会**覆盖** governor 请求，`Documentation/ABI/testing/sysfs-class-devfreq`） |
| 关掉的代价/风险 | **T19 首绘/滚动卡顿回归**（这是当初钉 525 的唯一理由）⇒ 属**用户体验取舍，需用户拍板**（PLAN §4 已标）。`polling_interval` 10→50 ms 是**次要变量**，单独做，别和 `min_freq` 混在一起 |
| 判据命令 | `G=/sys/class/devfreq/3d00000.gpu; cat $G/{available_frequencies,cur_freq,min_freq,polling_interval,governor}`；`cat $G/trans_stat`（改前/改后各存一份：`cat $G/trans_stat > /tmp/gpu-tr-before.txt`）；改后 300 s 内 `cur_freq` 应稳定在 `160000000` |
| 回退命令 | `systemctl restart gpu-devfreq-tune`（脚本会把 `min_freq` 抬回 525、`polling` 回 10）；`echo 10 > /sys/class/devfreq/3d00000.gpu/polling_interval` |

---

## 2. 休眠路径

### 2.1 s2idle 与 deep 在本 SoC 的实际差别（把「列出来」和「能用」分开）

| 维度 | **s2idle**（日常线唯一候选） | **deep**（不做，仅记账） |
|---|---|---|
| 内核调用链 | 不经过 `suspend_ops`；`s2idle_loop()` 冻结进程 + 把所有 CPU 推进 idle 循环（`kernel/power/suspend.c:133-160`）。本机**没有 ACPI**（`build/daily/.config` 无 `CONFIG_ACPI`）⇒ `s2idle_ops` 为空，走的就是「冻结设备 + CPU idle」这条路 | 走 `suspend_ops`：PSCI `SYSTEM_SUSPEND`（`drivers/firmware/psci/psci.c:573-600`，注册条件 = 固件报 `PSCI_FEATURE_SYSTEM_SUSPEND`，`:632-635`） |
| `mem_sleep` 为什么两个都有 | `s2idle` 恒列出；`deep` 只因 PSCI 报了 feature 就列出（`suspend_set_ops()` 生效） | — |
| 实测事实 | 11-25：`rtcwake`/`wakealarm` 各一次后 `success 0→2 fail=0 boot_id` 不变；**S4 = PASS**（`echo +300 > wakealarm` 后写 `mem`，驻留整 300 s、`success 2→3`） | vk130：`deep` 也只站 **1.43 s** 就 exit（`reports/suspend-pcie-l2-blocker-20261020.md` §1 四次同型）；7.2 时代进 `mem` **黑屏死机**（`.pi/memory/failures-kernel.md:9`） |
| 能不能省到「整机下电」 | **不能**——s2idle 不请求平台掉电，SoC 仍在「深 idle」；省的是**设备时钟/电源门 + CPU 深状态** | 理论上能，但本机固件路径不可用 |
| 唤醒面 | 任何使能的 wake IRQ 都能把它叫醒 ⇒ **唤醒源治理 = s2idle 的核心工作**（§2.3） | 同左但风险高（唤不醒=黑屏） |
| 结论 | **日常线只做 s2idle**（与 PLAN §4「deep 不做」一致，本文件不翻案） | deep 仅允许在**取证**场景、**带 RTC 自动唤醒 + 人在旁**时单发一次，且不得写进任何部署门 |

> 一个容易误读的点（写进来防下轮再踩）：`mem_sleep` 里有 `deep` **不代表 deep 可用**；它只代表 `psci_suspend_ops` 注册成功。
> 判据要读 `dmesg` 的 `PM: suspend entry (deep)` 之后**有没有真的掉电/黑屏**，不是读 `mem_sleep`。

### 2.2 `/sys/power/*` 的用法（标准挂起流程 + 本机特有坑）

| 文件 | 语义 | 本机注意 |
|---|---|---|
| `/sys/power/state` | 写 `freeze`（= 等效 s2idle）或 `mem`（按 `mem_sleep_current` 解析）触发挂起 | 本机 HIBERNATION 未编 ⇒ 无 `disk` |
| `/sys/power/mem_sleep` | `[s2idle] deep` | **不改**。写 `deep` = 进 §2.1 右列 |
| `/sys/power/wakeup_count` | **读会阻塞**（`PITFALLS #651`、`scripts/suspend-resource-sample.sh` 头注）⇒ 必须 `timeout` 包；写的语义 = 「自读值以来没有唤醒事件才允许睡」 | 标准用法：`wc=$(timeout -k 5 5 cat /sys/power/wakeup_count); echo "$wc" > /sys/power/wakeup_count; echo mem > /sys/power/state` |
| `/sys/power/suspend_stats/` | **是目录**（`PITFALLS #651`），逐项文件 | 关注 `success/fail/last_failed_dev/last_failed_errno/last_failed_step` |
| `/sys/power/pm_test` | `none/freezer/devices/platform`（s2idle 下 `core/processors` 被拒，`suspend.c:583`） | **N1 抓手**：`devices` 会跑全设备回调再 5 s 自动回；`pm_test_delay` 模块参数默认 5 s |
| `/sys/power/pm_print_times` | 1 = 逐设备打耗时 | **N4**：恢复时延预算的量化来源 |
| `/sys/power/pm_async` | 1 = 设备异步 suspend | 排障时可 `echo 0` 让顺序确定（回退 `echo 1`） |
| `/sys/power/pm_wakeup_irq` | 上次唤醒 IRQ 号 | **N3**；无则 `cat` 返回 `ENODATA`（rc≠0，不是坏） |
| `/sys/power/autosleep` | `CONFIG_PM_AUTOSLEEP=y` ⇒ **存在**。`echo mem >` = 内核在「无活动 wakeup source」时自动 s2idle；`echo off >` 关闭 | **危险点**：kernel autosleep **绕过 logind 的 inhibitor** ⇒ 会无视「用户正在看视频」。只允许在「已锁屏」场景做**受控试验**（阶段 2），严禁写成常驻配置 |

**标准受控挂起片段（阶段 2 用；先武装唤醒源，再睡）**

```sh
# 0) 武装自动唤醒（相对写法；绝对写法会被 1970 的 RTC 时基坑，PITFALLS #719）
timeout -k 5 5 sh -c 'echo +600 > /sys/class/rtc/rtc0/wakealarm; cat /sys/class/rtc/rtc0/wakealarm'
# 1) 前置：BT 必须已 settled（没有 systemd 钩子的前提下手工做）
timeout -k 5 10 rfkill block bluetooth
# 2) 后台落日志（SSH 会在挂起/恢复期间断，不能把结论留在终端的 stdout）
timeout -k 5 10 setsid sh -c 'cat /sys/power/wakeup_count > /dev/null; echo mem > /sys/power/state' >/var/log/pm-try.log 2>&1 &
# 3) 醒来后在 dmesg 取驻留差（单调时钟，不依赖 RTC）
timeout -k 5 10 dmesg | grep -E 'PM: suspend (entry|exit)'
timeout -k 5 5 cat /sys/power/suspend_stats/{success,fail,last_failed_dev}
timeout -k 5 5 cat /sys/power/pm_wakeup_irq
```

回退：`echo 0 > /sys/class/rtc/rtc0/wakealarm`（撤销闹钟）；`rfkill unblock bluetooth`；人按电源键。

### 2.3 wakeup source 清单与抑制源（**这一节决定 s2idle 能不能「待得住」**）

先取总账，再逐条决定：

```sh
timeout -k 5 10 cat /sys/kernel/debug/wakeup_sources          # N2：active_count / prevent_sleep_time / max_time_ms
timeout -k 5 10 sh -c 'for i in $(seq 0 300); do f=/sys/kernel/irq/$i/wakeup; [ -r "$f" ] && grep -q enabled "$f" && echo "$i"; done'  # 使能了唤醒的 IRQ 号
timeout -k 5 10 grep -E "^ *[0-9]+:" /proc/interrupts        # 号 → 名字
```

| 唤醒源 | 路径（可观测/可抑制） | 默认 | 抑制手段 | 反作用 / 代价 |
|---|---|---|---|---|
| **电源键（pmk8350 pwrkey）** | `find /sys/devices -name pmic_pwrkey`（设备名 `pmic_pwrkey`，`pon_gen3_pwrkey_data.name`）；DT `&pon_pwrkey status=okay`（`sm8750-lenovo-elden.dts:2567`） | **使能**（驱动 `wakeup_source_default=true`，`drivers/input/misc/pm8941-pwrkey.c:431,452,465`） | `echo disabled > <dev>/power/wakeup` | **唯一可靠的免工具唤醒源 ⇒ 不要关**。关了就要靠 RTC/网络，人在旁时等于自断后路 |
| **触摸（nt36536）** | `/sys/bus/spi/devices/spi4.0/`（IRQ `tlmm 162`，`sm8750-lenovo-elden.dts:2659-2678`） | **不可作为唤醒源**：驱动 `novatek-nvt-ts.c` 无 `enable_irq_wake()`、DT 无 `wakeup-source` | — | 现状 = **挂起后点屏不亮，必须按电源键**。这是 UX 缺口，属阶段 3（§4.3） |
| **RTC 闹钟** | `/sys/class/rtc/rtc0/wakealarm`（RW）；`/sys/class/rtc/rtc0/device/power/wakeup` | 使能 | `echo disabled > /sys/class/rtc/rtc0/device/power/wakeup`；或 `echo 0 > wakealarm` | **本机 RTC 停在 1970 且不可写**（T1：`hwclock -w` 报 `ioctl(RTC_SET_TIME) … 没有那个设备`）⇒ 只能用**相对写法** `+N`（11-25 实测 300 s PASS）；`rtcwake -m mem -s N` 会算成过去时刻而 1.6–1.9 s 就醒（#719）。抑制它 = 失去「自动醒来兜底」 ⇒ 阶段 2 **不要**抑制 |
| **USB gadget / `usb0`（dwc3 `a600000.usb`）** | `/sys/bus/platform/devices/a600000.usb/power/wakeup`（DT `usb: usb@a600000` 内 `wakeup-source`，`sm8750.dtsi:2865,2930`）；`/sys/class/net/usb0/` | 使能 | `echo disabled > /sys/bus/platform/devices/a600000.usb/power/wakeup` | 它是**登录通道的物理线路**：主机侧任何活动（host resume、枚举、ARP/DHCP 重试）都能把设备叫醒 ⇒ **挂起驻留会被主机打断**（PLAN §1.4 已实测到「拔线=断 SSH」这一面）。抑制它的**收益 = s2idle 待得住**，代价 = 抑制期间 USB 侧事件不再唤醒（但线路本身仍在，恢复后 SSH 可回来）。**这是本文件唯一建议「按场景关掉」的唤醒源**，且必须在 WiFi SSH 可用时做 |
| **WiFi WoWLAN（ath12k）** | `/sys/class/net/wlan0/device/power/wakeup`；`iw phy phy0 wowlan show/enable` | 取决于是否启用 wowlan | `iw phy phy0 wowlan disable`（不唤醒）；`rfkill block wlan`（彻底） | 启用 = 可被 magic packet/断连叫醒；**长驻留后 resume 有 `ath12k -110` 史**（`reports/t9-vk130-pcie-l2-live-20261021.md` A1：24.9 s 驻留后 `pci_pm_resume -110`）⇒ 长窗实验建议 `rfkill block wlan`（但先确认 WiFi SSH 不是你的唯一通道） |
| **蓝牙（hci_uart_qca / `serial0-0`）** | `/sys/bus/serial/devices/serial0-0/power/wakeup` | 使能 | `rfkill block bluetooth`（**首选**，已有实测：`rfkill block` 后 held **56.5 min**，`reports/t9-vk130-pcie-l2-live-20261021.md` B1） | 固件下载窗口内挂起必 `-110`（3 s 预算 vs 23–25 s 下载，`reports/qca-fw-download-suspend-20261021.md`）⇒ 抑制是**挂起前置的硬要求**，不是优化 |
| **充电器/PD（pmic_glink via ADSP）** | 无独立 `/power/wakeup` 写点（走 ADSP glink 中断） | 使能 | 无用户态旋钮（只能拔插控制） | 插拔 VBUS 会唤醒 ⇒ 测量窗口必须「线已拔、不再插」 |
| **PCIe（`1c00000.pcie` → WiFi）** | `/sys/bus/pci/devices/0000:01:00.0/power/wakeup`；`.../link/l1_aspm` | 使能 | 同上（rfkill/wlan down 后再抑制） | 历史 `Timeout waiting for L2 entry`（vk130 前）；11-25 的 300 s 驻留 **PASS** 说明当前未咬，但每次阶段 2 都要计数：`dmesg \| grep -c "Timeout waiting for L2"`（期望 0） |

判据纪律：**每次挂起前存一份 `wakeup_sources` + `irq/*/wakeup` 快照，醒来后存 `pm_wakeup_irq`**；否则「谁把我叫醒」永远只能猜。

### 2.4 结构性约束：USB-NCM 是唯一登录通道 ⇒ 挂起 = 失联（以及怎么处置）

**事实链**（三条独立证据）：
1. 登录通道 = `usb0` NCM `192.168.7.1`，拔 VBUS 即断（`DEVICE/README.md` §1.1；PLAN §0）。
2. 所谓「物理串口」并不独立：项目里的串口 = `console=ttyGS0` → 主机 `/dev/ttyACM0`，**还是同一根 USB 线的 gadget ACM**（`DEVICE/README.md:176`、`scripts/serial-tap.py`）。⇒ **没有真正的带外控制台**。
3. **没有硬件看门狗**：`/dev/watchdog` 不存在，dmesg 只有 `watchdog: Hard watchdog permanently disabled`（`reports/autonomous-test-cycle-20261125.md:16,41`、`reports/uefi-p52-p53-handoff-confirmed-20261107.md:63`）⇒ **挂起后若唤不醒，没有任何东西会自动复位**，只能人按电源键。

**因此**：挂起期间的「可观测性」必须**预先**放在设备本地，而不是指望在线看。

| 处置 | 做法 | 判据 | 回退 |
|---|---|---|---|
| **① 双通道** | 拔 VBUS 后走 **WiFi SSH**（PLAN §1.4 路 A）：先 `ip -4 addr show wlan0` 取 IP，主机 `ping` 通再开窗 | 主机 `ssh -o ConnectTimeout=5 <wlan-ip> true` rc=0 | 回到 USB 线；`systemctl restart net-selfheal` |
| **② 本地落盘 + 事后取数** | 采样器/挂起脚本一律 `setsid` + 写 `/var/lib/elden/pm/*.log`；主机只在窗口结束后 `scp` | 醒来后 `ls -l /var/lib/elden/pm/` 有窗口期文件、行数 > 0 | 无（只读文件） |
| **③ 自动唤醒兜底（**必做**）** | 每次挂起前 `echo +N > /sys/class/rtc/rtc0/wakealarm`（N 略大于窗口，例：10 min 窗用 `+660`） | 醒来 `cat /sys/class/rtc/rtc0/wakealarm` 为空（已被消费）；dmesg 有 `PM: suspend exit` | `echo 0 > wakealarm` |
| **④ 挂起期间不依赖网络** | 阶段 2 的「驻留/唤醒」验收只看**设备本地**证据：`dmesg entry/exit` 差值、`suspend_stats`、`boot_id` | 见 §2.5 | — |
| **⑤ 无人值守禁止** | **没有硬件看门狗** ⇒ 阶段 2 必须「人在旁、可长按电源键」；`autosleep` 之类常驻自动挂起**不得**在无人值守时开启 | 窗口清单里显式写「人在旁」 | `echo off > /sys/power/autosleep` |

> 关于「LAN / 串口 / 看门狗 / 自动唤醒」四选一的回答：**本轮只有「WiFi + RTC 自动唤醒 + 本地落盘」三件套可用**；
> 真串口 = 需硬件改造（不做）；硬件看门狗 = 需内核/DT 补（阶段 3，见 §4.3）。

### 2.5 驻留与唤醒的判定（把「睡了几秒」变成可复现的数）

| 量 | 取法 | 合格判据 |
|---|---|---|
| 驻留时长 | `dmesg` 里 `PM: suspend entry` 与 `PM: suspend exit` 的**单调时间戳差**（不是命令返回耗时，`PITFALLS #719`） | ≥ 目标窗 90%（5 min 窗 ≥ 270 s） |
| 是否真的挂过 | `/sys/power/suspend_stats/success` +1、`fail` 不变 | 且 `boot_id` 未变（变了 = 复位，**立刻停窗**） |
| 谁叫醒的 | `/sys/power/pm_wakeup_irq` + `/proc/interrupts` | 与「预期唤醒源」一致；不一致就回 §2.3 抑制 |
| 失败点 | `/sys/power/suspend_stats/{last_failed_dev,last_failed_errno,last_failed_step}` | 空/`0`；出现 `serial0-0` ⇒ BT 未 settled；出现 `0000:01:00.0` ⇒ ath12k |
| 恢复时延 | `pm_print_times=1` 后 dmesg 逐设备耗时 + 首帧时间（`phoc` 日志/`GetActive` 读回） | 唤醒到 SSH 可达 < 60 s；到能交互 < 5 s（预算值，首轮实测后固化） |

---

## 3. 按需策略矩阵（场景 × 动作 × 时延预算 × 与 PLAN §3 的对应）

> 表中「对应」只引用 PLAN §3 的步骤号（S1 屏亮 idle 基线 / S2 GPU A/B / S3 屏灭态 / S4 s2idle 5 min 驻留 / S5 只读判据）/ §2 的机制号（M1 s2idle、M2 GPU、M3 屏灭、M4 射频、M5 常驻裁剪、M9 充电）。
> **不重复 PLAN 正文**，只补「按需：关什么、什么时候关、关了以后多久能回来」。

| 场景 | 节点动作（关/降） | 是否挂起 | 恢复时延预算 | 对应 | 主要风险 & 回退 |
|---|---|---|---|---|---|
| **锁屏待机**（人离开） | ① 屏灭（合成器 DPMS，非 `bl_power`）② `rfkill block bluetooth` ③ `wlan0` 视需要 down（若 WiFi SSH 不再需要）④ GPU `min_freq=160 MHz` ⑤ 相机栈 off（`cam-mode.sh status` 确认） | **是**（s2idle；先武装 `wakealarm +N`） | 唤醒→可交互 < 5 s；→SSH 可达 < 60 s | PLAN **S3 → S4**（+M1/M2/M3/M4/M5） | #694 掉电链；BT `-110`；ath12k resume `-110`。回退：`SetActive false` / `rfkill unblock` / `ip link up` / `systemctl restart gpu-devfreq-tune` |
| **阅读不动屏**（屏亮、无输入） | ① 背光固定地板 1024 ② GPU `min_freq=160`、`polling_interval=50` ③ `rfkill block bluetooth` ④ **不** down `wlan0`（要待机收消息） | **否**（不睡，只降节点） | 无（不睡） | **S1 → S2**（+M2/M4） | 滚动/翻页卡顿（T19）。回退：重启 `gpu-devfreq-tune`、`echo 10 > polling_interval` |
| **视频播放** | ① GPU **保持** `min_freq=525`（解码/合成要立刻响应）② 背光按需（省电主要是屏幕）③ 音频必须留 **ADSP**（`q6apm` 在 ADSP 上，`reports/m3-3-audio-thermal-slice-20261013.md`） | **否**（且必须挡住 `autosleep`：`echo off > /sys/power/autosleep`） | 无 | 不属 PLAN 步骤；对应 PLAN §4「不做」里的「不主动限频」 | 误挂起 = 音画中断。回退：`echo off > autosleep`；`systemctl restart greetd` 兜底 |
| **编译压测** | ① `autosleep` **必须 off** ② GPU 不必降（不与编译争频）③ 散热前先 `charge-ctl.sh limit 80`（M9，只为降充电热）④ 确认 `cam-mode.sh` 已 off | **否** | 无 | PLAN **S5**（无限流的判据）+ M9 | 过热（`#302` 纪律：窗口内不跑重编译）。回退：`charge-ctl.sh limit off` |
| **充电过夜** | ① `charge-ctl.sh limit 80`（电池保养 + 降充电热）② BT off ③ 屏灭 ④ **不要** `autosleep` 常驻（无硬件看门狗）⑤ 可挂起但必须 `wakealarm` 兜底 | 可选（**有人值守才挂**） | 清晨唤醒→SSH < 60 s | PLAN **M9 + S3** | 充电器插拔即唤醒（§2.3）；`charge-watch` 会回写限流。回退：`charge-ctl.sh limit off` |

**跨场景的三条硬规则**
1. **GPU 的两档取值按场景切**：待机/阅读 = 160 MHz（S2），视频/交互 = 525 MHz（现装 tuner）。这是「按需」在本机最大的一块收益，且**零内核风险**。
2. **BT 的开关不是优化而是前置**：任何进入挂起的动作前 `rfkill block bluetooth`；unblock 之后 30 s 内**禁止**任何挂起。
3. **`autosleep` 只许在「已锁屏 + 人在旁」下短暂试用**；它是唯一能绕过 logind inhibitor 的自动挂起路径（§2.2），一旦常驻会与「视频/编译/阅读」全部冲突。

---

## 4. 分阶段实验序列

> 三个阶段严格串行：**前一阶段没有「全绿 + 记账」就不进下一阶段**。每阶段都写明验收判据与「失败即停」条件。
> 全部设备侧命令默认 `timeout -k`；全部写操作都附回退。

### 阶段 1 —— 纯 sysfs，零内核风险（秒级回退；可在任何在线窗口做，≈ 40 min）

| 步 | 动作 | 验收判据 | 失败即停 |
|---|---|---|---|
| **1.0** | §1.0 普查落 `/tmp/pm-census.txt`，取回主机 | 文件齐全（genpd/devfreq/rproc/cpuidle/wakeup_sources 各有内容） | debugfs 不可读 ⇒ 记「不可判」，只做 1.1–1.2 |
| **1.1** | **只读定性**：§1.8 判据③（域空闲 tracepoint，30 s）+ §1.1 `active_time/total_idle_time` 60 s 差分 + §2.3 `wakeup_sources` 快照 | 得到「域是否真进 + 谁在拦着睡」两个结论 | tracefs 不可写 ⇒ 记「不可判」，不阻塞 |
| **1.2** | **GPU 降档 A/B（PLAN S2）**：`cat trans_stat > before`；`echo 160000000 > min_freq`；采 300 s；`cat trans_stat > after` | `cur_freq=160000000`；`trans_stat` 里 525 档驻留明显下降；重启 tuner 后 `min_freq≥525000000` | `cur_freq` 仍 525（另有 freq holder）⇒ **不加码**，只记账；首绘卡顿肉眼可见 ⇒ 立即回退 |
| 1.3 | **`polling_interval` 次变量**：`echo 50 > polling_interval`，同上采样 | 唤醒次数下降（`trans_stat`/`rpm` tracepoint），无卡顿 | 有卡顿 ⇒ `echo 10 >` |
| **1.4** | **BT 前置与恢复演练**：`rfkill block bluetooth` → 30 s → `rfkill unblock` → 等 `QCA setup on UART is completed` | `rfkill list` 状态正确；BT 回来后 `hci0` 在且 `hciconfig hci0`/`bluetoothctl show` 正常 | unblock 后 60 s 仍无 `hci0` ⇒ `sh /usr/local/sbin/bt-up.sh`，仍无 ⇒ 记「BT 不可恢复」并停（不再做任何挂起实验） |
| **1.5** | **`pm_test` 分级试挂（N1，本文件新增）**：先 `echo freezer > pm_test` → `echo mem > state`（5 s 自动回）；再 `echo devices >`；再 `echo platform >`。**执行方式：`setsid sh -c '…' >/var/log/pmtest.log 2>&1 &`**——`devices`/`platform` 级会挂起 USB gadget，SSH 会眨眼断 5 s（这是预期，不是失败） | 每级都返回、`boot_id` 不变、`suspend_stats.fail` 不增；`devices`/`platform` 级的 dmesg 里**没有** `Some devices failed to suspend` | 见 `last_failed_dev` 非空或 `boot_id` 变 ⇒ **立刻 `echo none > pm_test`** 并停阶段 1，把失败点写进下轮 |
| **1.6** | **唤醒源账本演练（不真睡）**：每次只改一条，然后跑 `echo devices > pm_test` + `echo mem > state`（5 s 自动回）观察是否有设备被某个唤醒源提前挡回：<br>a) USB gadget `power/wakeup=disabled`<br>b) `iw phy phy0 wowlan disable`<br>c) RTC `power/wakeup=disabled`（**只在有其它唤醒源时做**） | 每次改完 `wakeup_sources` 里对应条目的 active/prevent_sleep 行为可解释；`pm_test` 仍 5 s 自动回、`fail` 不增 | 任何一次写 `pm_test` 后未在 30 s 内返回、或无 `PM: suspend exit` ⇒ **立刻 `echo none > pm_test`**，人按电源键；停该项，恢复 `enabled` |

> 阶段 1 **不做真挂起**（真挂起一律放阶段 2）：1.6 只验证「抑制手段是否生效、是否有副作用」，
> 「抑制后驻留到底变长多少」是阶段 2 的 2.1 / 2.3 要量的东西。

**阶段 1 总验收**：① 至少拿到「GPU 160 MHz 的功耗/驻留差」一个数字；② `pm_test` 三级全过（全设备回调无失败）；③ 唤醒源账本一项不缺（§2.3 表逐行有值）；④ 全部写操作已回退（`min_freq≥525000000`、`polling=10`、`pm_test=none`、`rfkill` 原态、`power/wakeup` 全 `enabled`）。

### 阶段 2 —— 需设备窗（人旁、可长按电源键、可拔插 VBUS；≈ 90 min）

**窗口前置（硬门，任一不满足即不开窗）**：`systemctl --failed` 只有已知项；`/sys/class/power_supply/qcom-battmgr-bat/status=Discharging` + `qcom-battmgr-usb/online=0`（拔线后；`PITFALLS #726`：`usb_type` 取值要 `grep -o '\[.*\]'`）；WiFi SSH 已通（路 A）或已决定「全程本地落盘」（路 B）；**外部唤醒源已武装**。

| 步 | 动作 | 验收判据 | 失败即停 |
|---|---|---|---|
| **2.1** | **s2idle 5 min 驻留复验 + 驻留归因（PLAN S4 的深化）**：`rfkill block bluetooth` → `echo +600 > wakealarm` → `echo mem > state`（setsid，落盘） | dmesg entry/exit 差 ≥ 300 s；`success+1`、`fail` 不变、`boot_id` 不变；`last_failed_dev` 空；`pm_wakeup_irq` 与预期一致 | `boot_id` 变（复位）/ 30 min 未醒（需按键）⇒ **停窗**，记「驻留不稳定」 |
| **2.2** | **长窗 30 min 驻留 + 掉电率**（走 `scripts/suspend-drain-rate.sh` 既有口径 + 相机栈 off） | 掉电率有值且重复 3 次 CV<10%；唤醒后模块数 = 睡前（`lsmod \| wc -l`） | 任何一发 `boot_id` 变 ⇒ 停（Q24 签名） |
| **2.3** | **WiFi 变量**：A `wlan0` up（ath12k 挂起/WoW）/ B `rfkill block wlan` | 两次驻留差 + resume 是否有 `ath12k -110`（`dmesg \| grep -c "pci_pm_resume\|failed to resume async"`） | 出现 `-110` 且 wlan 不回来 ⇒ 记「长挂起 + WiFi 不可组合」，回退 `ip link set wlan0 up` + `systemctl restart ath12k-retry` |
| **2.4** | **唤醒后恢复质量**（不只看「能醒」）：时延 + 功能 | `pm_print_times=1` 下逐设备耗时；唤醒→`GetActive` 可读、触摸正常、`wlan0` 重关联 < 60 s、BT 若 unblock 则 ≥ 30 s 后才允许再挂 | 触摸/音频/WiFi 任一不恢复且重启服务无效 ⇒ 停，写「resume 后遗症清单」 |
| **2.5** | **`autosleep` 候选试验（受控 10 min）**：锁屏态 `echo mem > /sys/power/autosleep` → 静置 → `echo off >` | 自动进入与否可用于「锁屏待机」；退出后系统功能完整 | 出现「屏幕亮着却被挂起导致交互中断」⇒ **立即 off** 并判「autosleep 不进日常线」 |
| **2.6** | **CDSP stop 零收益确认（可选，最后一个做）**：`echo stop > remoteproc1/state` → 采 300 s → `echo start` | 能耗无变化（±噪声）⇒ 结论「CDSP 常驻不是功耗主因」；`ip -br a`/音频/SSH 不受影响 | 任何 SSH/网络异常 ⇒ 立即 `echo start`；`start` 失败 ⇒ reboot，停该项 |

**阶段 2 总验收**：① ≥1 发 ≥300 s 驻留且 `success`/`fail`/`boot_id` 三件证据齐；② 掉电率有数字且 CV<10%；③ 「BT 抑制 + RTC 自动唤醒」两件前置端到端跑通（这是后续任何自动化挂起的前提）；④ 恢复后遗症清单为空或已明确登记。

### 阶段 3 —— 需内核/DT 改（**只立项、不在本轮动手**；按 PLAN §4 与 `TASKS/README.md` §7 的先例排）

| # | 缺口 | 现状证据 | 为什么要改内核 | 验收判据 | 停手条件 |
|---|---|---|---|---|---|
| **3.1** | **触摸唤醒**（s2idle 后点屏不亮） | `novatek-nvt-ts.c` 无 `enable_irq_wake()`；DT `touchscreen@0` 无 `wakeup-source`（`sm8750-lenovo-elden.dts:2659-2678`） | 用户态无替代路径（`bl_power`/`dpms` 都不能把触摸变成唤醒源） | 挂起后点屏能唤醒，且 `pm_wakeup_irq` = 触摸 IRQ（tlmm 162）；`current` 不增 | 唤醒后触摸不工作（需重下固件）⇒ 回退补丁，记「与 resume 固件重下冲突」 |
| **3.2** | **硬件看门狗（APSS WDT）** | `/dev/watchdog` 不存在；`qcom_wdt` 的 `of_match_table` **没有 sm8750 项**（`drivers/watchdog/qcom-wdt.c:400`）；sm8750 DT 无 wdt 节点 | 挂起后「唤不醒」目前**只能人按电源键**；`qcom_wdt` 还有 suspend 自动停/恢复（`qcom-wdt.c:361-382`），正好配套 | 出现 `/sys/class/watchdog/watchdog0`，`state=active`，超时能被 ping 住；挂起/恢复后仍 active | 挂起时看门狗不自动停（会咬）= 直接回退，不改默认 |
| **3.3** | **`deep`（PSCI SYSTEM_SUSPEND）** | vk130 `deep` 只站 1.43 s；7.2 时代 `mem` 黑屏死机 | 只有它能真正掉电 | **本轮不设验收**：只作取证，且**不得进日常线/部署门**（PLAN §4） | 任何 `deep` 试验后 `boot_id` 变 ⇒ 永久判「本机固件不支持」 |
| **3.4** | **OSI** | **已满足**（11-25 dmesg：`OSI mode supported.` + `using OSI mode`）；PLAN §2.1 的「PC 模式」判断已作废 | — | 无需动作 | — |
| **3.5** | **长挂起后 ath12k `-110`** | `reports/t9-vk130-pcie-l2-live-20261021.md` A1（24.9 s 驻留后 `pci_pm_resume -110`） | 决定「WiFi 能不能和长 s2idle 共存」 | 30 min 驻留后 `wlan0` 自动回来，无 `-110`；或明确书面结论「不可共存 ⇒ 长窗必须 rfkill wlan」 | — |

> 阶段 3 的**顺序纪律**：3.1（触摸唤醒）优先于 3.2（看门狗）——因为「能自己醒」比「醒不来能复位」更常被用到；
> 3.3 永远最后且**不承诺**；3.4 已关闭，不要重开。

---

## 5. 待上机确认清单（按「影响结论的程度」排序）

| # | 待确认项 | 一条命令 | 若为「否」的影响 |
|---|---|---|---|
| 1 | BT guard 在 systemd 下到底装没装 | `ls /usr/lib/systemd/system-sleep/` | §1.4 的「自动前置」不成立 ⇒ 阶段 2 全程手工 `rfkill block` |
| 2 | `wlan0` 在拔线后是否可达（路 A） | 主机 `ssh -o ConnectTimeout=5 <wlan-ip> true` | 只能用「全程本地落盘 + 事后取数」 |
| 3 | 触摸是否真的不能唤醒 | 挂起 → 点屏 → 看 `pm_wakeup_irq`/是否亮 | 若意外能唤醒，则 3.1 降级为「已满足」（先测再立项） |
| 4 | `pm_genpd` 里 display/GPU/UFS 域是否真在 `total_idle_time` 增长 | §1.1 判据 | 若全都不下电 ⇒ 「按需」的收益要先从驱动侧查（不是用户态旋钮能解决） |
| 5 | `1d84000.ufs` 的 `runtime_suspended_time/active_time` 比例 | §1.6 判据 | 若几乎不挂 ⇒ 存储是常驻功耗项，值得单独立项 |
| 6 | GPU 160 MHz 下首绘是否真回归 | 目视 + `trans_stat` | 回归 ⇒ 场景矩阵里「阅读」也要回 525，收益缩水 |

---

### 附：本文件对既有方案的**增量点清单**（便于 review）

1. **N1 `pm_test` 三级试挂** —— PLAN 没有；这是把「回调期失败」和「真挂起失败」分开的唯一零风险手段。
2. **N2 `wakeup_sources` / N3 `pm_wakeup_irq` / N4 `pm_print_times`** —— 把「谁叫醒了我」和「恢复要多久」变成可复现的两个数。
3. **否定 `suspend_stats/{last_hw_sleep,…}` 可用性** —— 只在 x86 PMC 写入，本机恒 0，别当驻留证据。
4. **`bl_power=4` 的语义纠正** —— 只关背光 IC，不是面板断电；面板关闭只能走合成器 DPMS（`dpms` 只读）。
5. **触摸不是唤醒源**（驱动 + DT 双缺）—— 解释了「挂起后点屏不亮」，并把它变成阶段 3 的第 1 项。
6. **ADSP stop 的依赖表 + 裁决「禁止作节能旋钮」** —— 因为它同时摧毁登录通道与功耗测量口径。
7. **BT guard 可能装在 elogind 目录而 init 是 systemd** —— 一个「以为有兜底其实没有」的隐患，需先确认。
8. **「无硬件看门狗 + 无独立串口」的联合结论** —— 阶段 2 必须有人值守；RTC 自动唤醒是必做项而非可选项。
9. **`autosleep` 的定位** —— 存在但绕过 logind inhibitor，只允许受控试用，不许常驻。
10. **OSI 已关闭**（不再作为待办）；`deep` 仍不进日常线（结论未翻案）。

■ 结束
