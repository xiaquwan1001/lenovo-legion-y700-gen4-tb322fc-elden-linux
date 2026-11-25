# 设备功耗 / 电源管理方案（TB322FC · 主线 7.3.1 · systemd + Phosh 0.46）

> 立：2026-11-25（规划 lane，**只读**：未上机、未改仓内既有文件、未发信、未做 git 写操作）。
> 本文件唯一写入 = 本文件自身。所有「设备侧命令」都是给**上机窗**照做的，本轮一条都没跑。
> 父代理已在设备上采到只读基线（2026-11-25 09:1x，在机 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`），
> 本文把它当**现状**（不再写成「待核」），并在 §7 标明一处与仓库历史的**口径差异**。

## 0. 前提与一句话摘要

| 前提 | 值 | 出处 |
|---|---|---|
| 机型 | TB322FC = SM8750(P) = elden | `AGENTS.md` |
| 内核 | `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`（= vk192 件，`CONFIG_SUSPEND=y`） | `DEVICE/README.md` §1.1、`versions/vk-registry.tsv` vk192 行 |
| 桌面 | systemd + greetd + phoc/phosh **0.46**，Mesa 26.1.6，**phoc 走 GL** | `reports/thermal-baseline-20261125.md` 头 |
| 宿主 | 无 Android 宿主（Waydroid 容器在机、zramswap 在机） | `DEVICE/README.md` §1.1 |
| cmdline | 含 `clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0` | `out/boot-elden-vk189.manifest` |
| 登录通道 | **USB-NCM `192.168.7.1`**（拔 VBUS ⇒ 断 SSH） | `DEVICE/README.md` §1.1 |

**摘要（现状 → 差距 → 动作）**

1. **闲置功耗的大头还没碰**：`mem_sleep=[s2idle] deep` 但本 boot `suspend_stats=0/0`（未尝试）；屏亮 idle 时 cpuidle 只有 `WFI + cpu-sleep-0(ret)`、GPU 被我们自己的调优钉在 **min 525 MHz**。→ 动作 = 先把「s2idle 日常化」与「GPU min_freq 回 160 MHz」两条低风险高收益做掉（§3 S2/S4）。
2. **热不是异常，功耗口径必须先立**：空载 cpuss 39.9–40.3 °C、无限流、EAS 承重表在（`energy_model` 有 `cpu0`/`cpu6`）⇒ 不是「调频坏了」。但**无电流表、无 RAPL、`power_now` 为空**，且设备常态**在充电**（本次实测 `current_now=+9133 mA`）⇒ 本轮第一件事是建立**电池侧代理口径**（§1）。
3. **cluster/OSI 空闲是「不可从 Linux 管」而不是「我们漏配」**：DT 里 cluster/system 域状态齐全（上游 `sm8750.dtsi` 就有），但 `cpuidle-psci` 只在固件宣告 OSI 时才启用域空闲，而上游 psci 默认 PC 模式。→ 动作 = 上机窗用一条 dmesg 判据定性（§3 S5），**不在本轮动内核**（§4 明确不做）。

---

## 1. 测量口径（先立，否则后面全是噪声）

### 1.1 为什么必须是代理指标

| 工具 | 判定 | 依据 |
|---|---|---|
| 外部电流表 / INA | ❌ 无此硬件（项目不做硬件改装） | 项目口径 `scripts/suspend-resource-sample.sh` 头注 |
| `powertop` | ❌ 依赖 RAPL/MSR，aarch64 无 | 判据 `command -v powertop`（即使有也没有数据源） |
| `turbostat` | ❌ x86 专用 | 位置 `tools/power/x86/turbostat/turbostat.c`（上游 master，2026-11-25 抓） |
| `perf stat -e power/energy-*` | ❌ 本 SoC 无能量计数器（Arm 侧无 RAPL 等价物） | 判据见下，**期望输出 0 条**；若无则明确写「不可用」，不得用别的计数顶替 |
| `/sys/class/power_supply/*/power_now` | ❌ 空（父代理实测） | 用 `current_now × voltage_now` 自己算 |

```sh
# 判据 A：能量计数器是否存在（期望 0）
timeout -k 5 20 perf list 2>/dev/null | grep -c 'power/energy'
# 判据 B：power_now 是否可信（期望空）
timeout -k 5 5 cat /sys/class/power_supply/qcom-battmgr-bat/power_now
```

### 1.2 四个可用量 + 换算

设备侧路径：`B=/sys/class/power_supply/qcom-battmgr-bat`（父代理实测可读；`charge-ctl.sh` 另有 `qcom-battmgr-usb/input_current_limit`）。

| 量 | 单位/语义 | 用法 | 分辨率 |
|---|---|---|---|
| `$B/current_now` | µA，**I>0 = 充电**（`charge-ctl.sh` 头注口径） | 瞬时功率代理：`P_mW = I_uA × V_uV / 1e9` | 采样级，有抖动 ⇒ 取中位数 |
| `$B/voltage_now` | µV | 与上式配 | — |
| `$B/charge_counter` | µAh 累计 | **积分代理**（首选）：`I_mA = Δcharge_counter/1000 / Δt_h` | 优于 1% |
| `$B/capacity` | % | 只做**粗校验**（1% ≈ 设计容量 1%，见 `charge_full_design`） | 太粗，20 min 窗口可能只掉 1–2% |
| `cpuss-0-0` 热区温度 | m°C | **只做定性佐证**，不做 W 换算（无标定） | 0.1 °C |

```sh
# 电池设计容量（用于把 % 换成 mAh；没有就只用 charge_counter）
timeout -k 5 5 cat /sys/class/power_supply/qcom-battmgr-bat/charge_full_design
```

判据纪律：**同一窗口内同一条件**，A/B 差值必须大于重复 3 次的离散度（CV < 10%）；否则判「噪声内，无结论」。

### 1.3 设备侧采集器（POSIX sh，落盘后取回；避免 SSH 自身耗 CPU）

> 背景：`sshd-session` 在本机空载时占 6.6% CPU（`reports/thermal-baseline-20261125.md` §1）⇒ 采样必须在**设备本地**跑，主机只在窗口结束后取数。

```sh
cat > /tmp/pm-sample.sh <<'EOF'
#!/bin/sh
# 用法: sh /tmp/pm-sample.sh <秒> <输出文件>
DUR=${1:-600}; OUT=${2:-/tmp/pm.txt}
B=/sys/class/power_supply/qcom-battmgr-bat
zone() { for z in /sys/class/thermal/thermal_zone*/; do
           [ "$(cat "$z/type" 2>/dev/null)" = "$1" ] && { cat "$z/temp"; return; }; done; echo ""; }
: > "$OUT"
i=0
while [ "$i" -lt $((DUR/5)) ]; do
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(date +%s)" "$(cut -d' ' -f1 /proc/loadavg)" \
    "$(cat $B/current_now 2>/dev/null)" "$(cat $B/voltage_now 2>/dev/null)" \
    "$(cat $B/charge_counter 2>/dev/null)" "$(cat $B/capacity 2>/dev/null)" \
    "$(zone cpuss-0-0-thermal)" >> "$OUT"
  i=$((i+1)); sleep 5
done
EOF
# 起：nohup sh /tmp/pm-sample.sh 600 /tmp/pm-S1.txt >/dev/null 2>&1 &
```

主机侧汇总（取回 `/tmp/pm-S*.txt` 后）：

```sh
awk 'NR==1{t0=$1;c0=$5} {t1=$1;c1=$5; s+=$3; v+=$4; n++}
END{d=(t1-t0)/3600;
    printf "n=%d I_mean=%.0fmA V_mean=%.3fV P=%.2fW dQ=%.0fmAh I_int=%.0fmA\n",
      n, s/n/1000, v/n/1e6, (s/n)*(v/n)/1e9, (c1-c0)/1000, (c1-c0)/1000/d}' /tmp/pm-S1.txt
```

### 1.4 窗口与噪声控制（单变量清单，逐条在窗口内**固定**）

| 项 | 固定为 | 设备侧确认命令 |
|---|---|---|
| 供电 | **电池**（`status=Discharging`、`qcom-battmgr-usb/online=0`） | `cat $B/status /sys/class/power_supply/qcom-battmgr-usb/online` |
| 背光 | 固定 `1024`（25%，`aw99706-backlight` 满刻度 4095；下限 1024 见 `etc-conf.d-backlight-floor`） | `cat /sys/class/backlight/aw99706-backlight/{brightness,max_brightness}`；先 `systemctl stop backlight-floor`（它每 20 s 回写地板值） |
| 屏 | 亮/灭**每档固定**，不混 | `cat /sys/class/backlight/aw99706-backlight/bl_power`（4=灭） |
| 桌面空闲 | `idle-delay=0`（防会话层抢先熄屏） | `gsettings get org.gnome.desktop.session idle-delay`（会话总线内） |
| Firefox / osk-stub | 不启动、不 pkill（`osk-stub` 是 `phosh.session` 必需组件，`PITFALLS #716`） | `pgrep -cx firefox` = 0 |
| WiFi | 每档固定（**不改** `power_save`，见 §2 M4） | `iw dev wlan0 get power_save`（当前部署 `net-selfheal.sh` 会强制 off） |
| 扫描服务 | 默认**保持运行**（常量噪声）；若 A/B 的 CV>10%，再 `systemctl stop wifi-scan-refresh` 单变量复核 | `systemctl is-active wifi-scan-refresh` |
| SSH 交互 | 窗口内 0 交互（采样本地跑） | — |
| 温度稳定 | 每档开始前静置 5 min | `cpuss-0-0-thermal` 两次读差 < 0.5 °C |
| 记录 | `boot_id` / `uptime` / `load` 同档可比 | `cat /proc/sys/kernel/random/boot_id; cut -d. -f1 /proc/uptime` |

**测量拓扑（必须先解决，否则「拔线」= 断 SSH）**：登录通道是 USB-NCM `192.168.7.1`。两条路：

- **路 A（首选）**：拔 VBUS 后走 WiFi SSH。先 `ip -4 addr show wlan0` 取 IP，主机 `ping` 通再开窗。
- **路 B（兜底，最稳）**：设备本地起采样器 → 落 `/var/lib/elden/pm/` → 拔线 → 窗口结束复插 → `scp` 取数。全程零网络依赖。

```sh
# 路 B 起跑（在拔线前执行）
mkdir -p /var/lib/elden/pm
nohup sh /tmp/pm-sample.sh 3600 /var/lib/elden/pm/$(date +%Y%m%d-%H%M).tsv >/dev/null 2>&1 &
```

### 1.5 充电态 ≠ 放电态（父代理实测的反例）

本次只读基线：`status=Charging`、`current_now=+9133 mA`、cpuss 47.6–54.6 °C。这 9 A 是**充电电流**，不是系统功耗；在充电态测「系统功耗」和「热」都无意义。
**同一条电池读数里必须把两件事分开**：`charge-ctl.sh status`（`charge_type`/`input_current_limit`/`charge_control_end_threshold`）说明充电功率；`current_now − 充电分量`在电池上才等于系统电流（拔线后自然分开）。

---

## 2. 可用的 PM 机制清单（按「收益/风险比」排序）

排序理由：M1/M2/M3 都是**用户态 + sysfs，秒级回退**；M4/M5 是常驻服务裁剪，零内核风险；M6/M7 要动内核/cmdline，只做判据不动手。

| # | 机制 | 现状（实测/证据） | 差距 | 动作 | 设备侧判据命令 | 风险 · 回退 | 收益量级 |
|---|---|---|---|---|---|---|---|
| **M1** | 系统挂起 **s2idle** 日常化 | `mem_sleep=[s2idle] deep`、本 boot `success/fail=0/0`；历史同 UTS 上 `rtcwake -m mem -s 45` **3/3 rc=0**（`reports/device-session-20261116-vk192.md` §待机） | 没有「长驻留（≥5 min）成功」与「日常触发路径」；BT/WiFi 两个已知弹出源没做前置 | ①`rfkill block bluetooth` 前置 ②5 min 驻留验收（S4）③再定「电源键短按 = suspend」还是 phosh 空闲挂起 | `cat /sys/power/mem_sleep`；`cat /sys/power/suspend_stats/{success,fail}`；`dmesg \| grep -E "PM: suspend (entry\|exit)\|Some devices failed"` | 风险：BT 固件下载窗口（23–25.4 s）内挂起必 `-110`（`reports/qca-fw-download-suspend-20261021.md`）。回退：`rfkill unblock bluetooth`；`loginctl` 层不动，随时 `echo on > /sys/power/state` 无关 | **最大**：屏灭 idle 与 s2idle 之间通常是**数倍**差（本轮建立数字） |
| **M2** | GPU devfreq 空闲频点 | `3d00000.gpu`：`simple_ondemand`，`cur=min=525 MHz`、`max=1100`、`polling=10 ms`。**来源是我们自己的 `gpu-devfreq-tune.service`**（`scripts/deploy-desktop-shell.sh` §8：`min_freq>=525MHz`、`polling_interval=10`，为 T19 首绘卡顿） | 上游 OPP 表最低 **160 MHz**（`sm8750.dtsi` gpu opp-table 首档），我们把地板抬了 3.3× | 上机窗 A/B：`min_freq=160000000`；并考虑 `polling_interval` 10→50（少 100 次/s 唤醒） | `cat /sys/class/devfreq/3d00000.gpu/{available_frequencies,cur_freq,min_freq,polling_interval,governor}`；`cat /sys/class/devfreq/3d00000.gpu/trans_stat` | 风险：首绘/滚动卡顿回归（T19）。回退：`systemctl restart gpu-devfreq-tune`（脚本会把 min 抬回 525、polling 回 10） | 中：空载 GPU 从 525→160 MHz |
| **M3** | 屏灭 / DPMS（熄屏） | `card0-DSI-1/dpms` 是 **0444 只读**（`notes-display.md`、`PITFALLS #456`）；熄屏只能走 `ScreenSaver.SetActive` + 读回 `bl_power=4` | 没有「屏灭态」的功耗样本；`#694` 掉电链只在**锁屏/熄屏**路径上被观察到 | 上机窗 S3 采屏灭态；同时核对 `systemd-inhibit --list` 是否有人挡挂起 | `cat /sys/class/backlight/aw99706-backlight/bl_power`；`gdbus call … org.gnome.ScreenSaver.GetActive`；`systemd-inhibit --list` | 风险：假熄屏（读回不校验 ⇒ 整轮假样本）。回退：`SetActive false`；异常时 `systemctl restart greetd`（D12 纪律） | 中：面板+DSI+DPU 关断 |
| **M4** | WiFi/BT 射频 | `ath12k` 在机；`net-selfheal.sh` 主动 `iw set power_save off`（ath12k 突发丢包源，`reports/net-https-mtu-rootcause-20261018.md`）；`wifi-scan-refresh.service` 每 **150 s** 全信道扫描（5.6–8.4 s，**4–6% 占空比**，`etc-conf.d-wifi-scan-refresh`）；BT 状态未固定 | 扫描占空比是**可调**（150→170，贴身 bss_expiration_age 180 s 上限）；BT 未用时没 rfkill | ①扫描间隔 150→170 s（省 1/5 扫描时间）②挂起前置 `rfkill block bluetooth` ③`power_save` **不做永久 on**（会回退网络问题） | `systemctl is-active wifi-scan-refresh`；`iw dev wlan0 get power_save`；`rfkill list` | 风险：候选 AP 榜变慢（>`180 s` 就塌）；回退：改回 150 + `systemctl restart wifi-scan-refresh` | 中低：射频 4–6% 占空比 + BT 控制器常驻 |
| **M5** | 常驻负载裁剪（相机栈 / hexagonrpcd / Waydroid / zramswap） | `cam-mode.sh` 定义「相机 ⇄ 熄屏」互斥（相机模块在位时熄屏掉电 = 常态，`reports/q24-*`）；`hexagonrpcd` 已 mask（D1②）；Waydroid + zramswap 在机 active | 需要**每轮确认**「日常态 = 相机栈 off」；Waydroid 不用时没有停 | 窗口前后各一条：`cam-mode.sh status`；不用 Waydroid 时 `systemctl stop waydroid-container`（**本轮只记录，不擅自停**——用户可能在用） | `sh /usr/local/sbin/cam-mode.sh status`；`lsmod \| grep -cE "camss\|cci\|camcc\|cambist"`；`systemctl is-active waydroid-container zramswap`；`zramctl` | 风险：停 Waydroid 打断用户；回退：`systemctl start waydroid-container` | 中：相机栈常驻是**已知掉电主因之一** |
| **M6** | PSCI cpuidle 集群/域空闲（OSI） | `current_driver=psci_idle`；`cpu0` 仅 `WFI` + `cpu-sleep-0 ret`；55 温区、4 cooling device | **DT 不缺**（cluster/system 域状态在上游 `sm8750.dtsi` 里齐备）；缺的是**固件 OSI 宣告**——上游 psci 默认 PC 模式，`cpuidle-psci` 只在 `psci_has_osi_support()` 为真时才用层级拓扑 | **本轮只做判据**（S5）；若确认 PC 模式 ⇒ 结论 = Linux 侧不可管理，不再投入（§4） | 见 §2.1 | 风险：以「加内核 patch 强制 OSI」推进 ⇒ 固件不配套可能挂死/唤不醒。回退：不落地 | 不确定（PC 模式下硬件可能仍自行下电） |
| **M7** | cmdline `clk_ignore_unused` / `pd_ignore_unused` | 两个都在（`out/boot-elden-vk189.manifest`）⇒ 未用的 clock/PD 保持点亮 | 从没做过 A/B | 候选：零写盘 `fastboot boot` 一件去掉这两词的镜像，看能不能到桌面（**本轮不做**，§4） | `cat /proc/cmdline` | 风险：显示/相机/PCIe probe 失败（bring-up 期加它们正是为此）。回退：`fastboot boot` 回原件，不改 boot_b | 未知（可能小） |
| **M8** | CPUfreq governor / EAS | `policy0=schedutil`；`/sys/kernel/debug/energy_model` 有 `cpu0`/`cpu6`；95% 时间 556 MHz | **无差距**（可据此否证「负载乱放」假设） | 不改。**不**切 `powersave`（丢性能、无收益） | `cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor`；`cat /proc/sys/kernel/sched_energy_aware`；`ls /sys/kernel/debug/energy_model` | — | 0（已最优） |
| **M9** | 热管理 / 充电热 | 55 zone、`cpufreq-cpu0/cpu6`、`devfreq-3d00000.gpu`、`ath12k_thermal` 四个 cooling；**无限流**（`dmesg \| grep -i throttl` 空） | 空载不需要限频；**充电热**（9 A）与系统功耗无关，但影响体感与电池 | 长时实验前 `charge-ctl.sh limit 80`（电池保养 + 降充电热）；不做主动限频 | `sh /usr/local/sbin/charge-ctl.sh status`；`dmesg \| grep -icE "throttl\|cooling"` | 风险：限充电量影响续航预期；回退：`charge-ctl.sh limit off` | 只影响体感，不改系统功耗 |
| **M10** | 明确不做 | 见 §4 | — | — | — | — | — |

### 2.1 M6 展开：cpuidle / OSI 判据与结论边界

**先说清一件事（纠正一个容易误读的现象）**：`cpu0` 只有 2 个 state**不等于**「集群状态没配」。上游 `of_get_cpu_state_node()` 现在**优先取 CPU 电源域的 `domain-idle-states`**（`drivers/of/cpu.c:191-209`，上游 master 2026-11-25 抓），`cpu_pd0` 只挂了一个 `cluster0_c4`（retention）⇒ 每 CPU 就只有 `WFI + cpu-sleep-0`。集群/系统状态挂在 `cluster0_pd`/`cluster1_pd`/`system_pd` 上，**只有 OSI 模式才会被用起来**。

| 判据 | 设备侧命令 | 期望/解读 |
|---|---|---|
| ① 固件是否宣告 OSI | `dmesg \| grep -E "OSI mode supported\|Initialized CPU PM domain topology\|failed to create CPU PM domains"` | 有 `OSI mode supported.` + `… using OSI mode` = 走了 OSI；只有 `… using PC mode` = 固件按 PC 协同；读不到这两行 = cpuidle-psci 域驱动没起来（看 `failed to create CPU PM domains ret=`） |
| ② 域状态表 | `ls /sys/kernel/debug/pm_genpd/`；`cat /sys/kernel/debug/pm_genpd/power-domain-cluster0/idle_states` | 有 `cluster-sleep-0` 行 = DT 状态被 genpd 解析到 |
| ③ 域是否真进入 | `echo > /sys/kernel/debug/tracing/trace; echo 1 > /sys/kernel/debug/tracing/events/power/psci_domain_idle_enter/enable; sleep 30; echo 0 > …/enable; grep -c psci_domain_idle_enter /sys/kernel/debug/tracing/trace` | 30 s 空闲里 →0 ⇒ 域状态没被用；≫0 ⇒ cluster 状态真的在用 |
| ④ 状态可禁（单状态） | `echo 1 > /sys/devices/system/cpu/cpu0/cpuidle/state1/disable` | 每状态 `disable` 是 RW（`Documentation/ABI/testing/sysfs-devices-system-cpu`），可做单变量 |

**结论边界**：PSCI **PC 模式 ≠ 芯片不下电**——PC（platform coordinated）是「固件/硬件自己协调」，Linux 既看不到也管不到。所以本项**不能**声称「无 cluster 下电 = 空闲功耗主因」；能确定的只有：**从 Linux 侧没有可调旋钮**。真正的空闲收益走 M1（s2idle）。

### 2.2 H1 / H2 / H3 三条合成开销假设的证伪命令（D11）

| 假设 | 证伪/证实命令（设备侧） | 判据 |
|---|---|---|
| **H2 GPU 顶格** | `cat /sys/class/devfreq/3d00000.gpu/trans_stat`（各频点驻留时间）+ 5 s 采样 `cur_freq` | **已半证实**：`cur=min=525` 是**我们自己的 tuner**（`deploy-desktop-shell.sh` §8）。判据 = A/B `min_freq=160000000` 后 `cur_freq` 是否跟到 160；`trans_stat` 里 525 档时间是否清空 |
| **H1 dmabuf modifier 禁 ⇒ CPU 合成** | `tr '\0' '\n' < /proc/$(pidof phoc)/environ \| grep -E "MESA\|GSK_RENDERER"`；`top -b -n1 -p $(pidof phoc)` | phoc 空载 CPU% 持续 >5% ⇒ 合成在烧 CPU；否则假设不成立（父代理实测 phosh 0.1%、gnome-control-c 0.2% ⇒ **空载不成立**） |
| **H3 WebRender 落 LLVMpipe** | `grep -c "llvmpipe\|swrast" /proc/$(pidof firefox)/maps`；`tr '\0' '\n' < /proc/$(pidof firefox)/environ \| grep -E "LIBGL\|MESA\|MOZ_"` | >0 ⇒ 软渲确认（只在 Firefox 窗口内成立，空载无 Firefox 时不可测） |

---

## 3. 一轮上机窗验证序列（父代理照做；总 ≈ 44 min；每步可单独回退）

**窗口前置（硬门）**：用户在旁、可拔插 VBUS；`systemctl --failed` 只有已知的 `qbootctl.service`；本窗口**不重启、不写盘、不改内核**。

| # | 步骤 | 设备侧命令（要点） | 期望读数 | 失败判据 | 复原 | 时长 |
|---|---|---|---|---|---|---|
| **S0** | 前置门 | `uname -r; cat /proc/sys/kernel/random/boot_id`；`B=/sys/class/power_supply/qcom-battmgr-bat; U=/sys/class/power_supply/qcom-battmgr-usb`；`cat $B/status $U/online $B/capacity $B/charge_full_design` | `status=Discharging`、`online=0`（**拔线后**） | 仍 `Charging`/`online=1` ⇒ **停**（充电态数据作废，父代理已踩过：9133 mA） | 无需 | 3 min |
| **S1** | 屏亮 idle **基线** | 固定背光：`systemctl stop backlight-floor; echo 1024 > /sys/class/backlight/aw99706-backlight/brightness`；会话内 `gsettings set org.gnome.desktop.session idle-delay "uint32 0"`；`nohup sh /tmp/pm-sample.sh 600 /tmp/pm-S1.txt &`；静置 | `P` 与 `I_int` 有值；`cpuss` 与 40 °C 基线同档；CV<10% | 采样文件行数 < 100（脚本没跑起来）；CV>10% ⇒ 换 `systemctl stop wifi-scan-refresh` 重测 | `systemctl start backlight-floor`；`idle-delay` 回原值 | 10 min |
| **S2** | GPU **A/B**（M2） | `G=/sys/class/devfreq/3d00000.gpu`；`cat $G/available_frequencies`；`cat $G/trans_stat >/tmp/gpu-before.txt`；`echo 160000000 > $G/min_freq`；采 `pm-S2.txt` 300 s | `min_freq=160000000`，idle `cur_freq=160000000`，`P` 比 S1 低且超噪声 | `cur_freq` 仍 525（= 另有 freq holder，如 DRM/icc）⇒ 结论写「devfreq min 不是唯一约束」并由 `trans_stat` 佐证；**不要**继续加码 | `systemctl restart gpu-devfreq-tune; cat $G/min_freq`（应 ≥525000000） | 10 min |
| **S3** | 屏灭态（M3） | 取会话总线：`SBU=$(for p in $(pidof phoc); do tr '\0' '\n' </proc/$p/environ \| sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p'; done\|head -1)`；`su - <用户> -c "DBUS_SESSION_BUS_ADDRESS=$SBU gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive true"`；**读回** `GetActive` + `cat /sys/class/backlight/aw99706-backlight/bl_power`；采 480 s | `GetActive=true`、`bl_power=4`、`P` 比 S1 低 | `bl_power` 仍 0 或 `GetActive=false` ⇒ 判 **INVALID 假熄屏**（`PITFALLS #456`），改 `loginctl lock-session` 复核；仍假则本步作废并记账 | `SetActive false`，读回 `bl_power=0`；不回 ⇒ `systemctl restart greetd` | 8 min |
| **S4** | **s2idle 5 min 驻留**（M1） | `rfkill list bluetooth`（记录）；`rfkill block bluetooth`；`cat /sys/power/mem_sleep`；`timeout -k 10 20 rtcwake -m mem -s 300; echo rc=$?`；醒来后再读 `suspend_stats` | `rc=0`；`success` +1；dmesg `PM: suspend entry (s2idle)` → `PM: suspend exit` | ①`success` 不变或 `fail`+1 ②`dmesg` 有 `Some devices failed to suspend`（记 `last_failed_dev`）③超时未醒 ⇒ 人工按键；④`boot_id` 变 = 复位（**严重，立刻停窗**） | `rfkill unblock bluetooth`；`hci0` 缺失则跑 `bt-up.sh` | 8 min |
| **S5** | 只读判据（M6 + 热链） | §2.1 表 ①–③；另 `systemd-inhibit --list`；`dmesg \| grep -icE "throttl\|cooling"` | ①得到 `PC` 或 `OSI` 定性 ③域进入计数有/无 | 无（只读）；若 tracefs 未挂则记「不可判」 | 关闭 tracepoint：`echo 0 > …/enable` | 3 min |
| **S6** | 复原 + 汇总 | `systemctl start backlight-floor`；确认 `$G/min_freq>=525000000`；`idle-delay` 回原值；`cat /sys/class/power_supply/qcom-battmgr-usb/online`（复插后=1） | 与 S0 逐项一致 | 任一项不回 ⇒ 明确写「未复原」并列入下轮 | — | 2 min |

**产出记账格式**（每档一行）：`档位 | 时长 | I_mean(mA) | V_mean(V) | P(W) | Δcharge(mAh) | cpuss(°C) | load | CV`。

---


> **★2026-11-25 上机实测更正（父代理，vk189）**：本文 §2.1/§7 的「固件未宣告 OSI ⇒ Linux 不可管集群」**不成立**——
> `dmesg` 实测 `psci: OSI mode supported.` + `CPUidle PSCI: Initialized CPU PM domain topology using OSI mode`
> ⇒ **OSI 已启用、`domain-idle-states` 生效**，`cpu0` 只有 2 个 state 是「CPU 电源域状态优先」的正常现象。
> 因此「强制 OSI」不是待办（已满足），也不该把「集群不可管」写进结论。
> 另：`rtcwake -m mem` / `wakealarm +N` 各跑一次后 `suspend_stats.success` 0→2、`fail=0`、`boot_id` 未变
> ⇒ **s2idle 挂起/恢复链路在 vk189 上是通的**，只是驻留只有 1.6–1.9 s（RTC 停在 1970 ⇒ 闹钟提前触发，见 `PITFALLS #719`）。
> ⇒ 优先级 1 的判据从「能不能挂起」改成「**能不能驻留 ≥5 min 并正常唤醒**」。
> **S4 复测（2026-11-25T03:05:17Z→03:10:17Z）= PASS**：`echo +300 > /sys/class/rtc/rtc0/wakealarm` 后写 `mem`，驻留**整 300 s**、`suspend_stats.success` 2→3、`fail=0`、`boot_id` 未变 ⇒ **M1 的「5 min 驻留」判据已满足**（早先 1.6/1.9 s 的短驻留是 `rtcwake -s` 在 RTC=1970 下的假闹钟）。
> **S5 只读判据（2026-11-25 实测）**：`dmesg | grep -icE "throttl|cooling"` = **0**（无热限频触发）；`systemd-inhibit --list` = **8 条**，其中与本项相关的两条 sleep 抑制器：`gsd-power`（reason=`GNOME needs to lock the screen`，mode=**delay**）与 `phosh`（reason=`Phosh handling suspend`，mode=**delay**）⇒ 桌面会**延迟**而非阻塞挂起，`rtcwake/suspend` 仍能进入（已实测 success 3 次）。`rfkill`：蓝牙 1 条 soft-blocked（S4 前置，测完未 unblock，如需蓝牙要 `rfkill unblock bluetooth`）。

> **S1 屏亮 idle 基线本轮作废**：采样窗内设备在**快充**（`current_now` 均值 **+4.70 A**、21 W、capacity 90→95%），不是放电态 ⇒ 功耗数字全部无效。测量必须在「拔掉所有 VBUS、`qcom-battmgr-usb/online=0`」时做（S0 硬门）。

## 4. 优先级建议

### 先做（3 条）

| 序 | 事项 | 为什么先做（收益/风险） |
|---|---|---|
| **1** | **M1 s2idle 日常化**：先按 S4 验收 5 min 驻留（带 `rfkill block bluetooth` 前置），把「电源键短按 = 挂起」写进部署门 | 收益最大（整机低功耗 vs 屏灭态，通常数倍差）；风险点已知且都有对策（BT 下载窗 = rfkill / elogind 钩子；ath12k 长挂起 resume `-110` = 驻留上限先按 ≤5 min 验收） |
| **2** | **M2 GPU min_freq 525→160**（+ `polling_interval` 10→50 的次变量） | **纯 sysfs、秒级回退**，且现状「顶格」是**我们自己的调优**，不是驱动默认 ⇒ 改回几乎零风险；唯一代价 = T19 首绘卡顿回归（用户体验取舍，需用户拍板） |
| **3** | **M3+M5 零风险裁剪**：屏灭态样本、`cam-mode.sh off` 日常态确认、`wifi-scan-refresh` 150→170 s、Waydroid「不用即停」写成日常判据 | 全部用户态，无内核风险；其中相机栈「在位 + 熄屏」是**已知掉电主因**（`cam-mode.sh` 头注） |

### 明确不做（含理由）

| 项 | 理由 |
|---|---|
| **`deep` 睡眠（PSCI SYSTEM_SUSPEND）** | 7.2 时代进 `mem` 即黑屏死机；vk130 实测 **deep 也是 1.43 s 就 exit**（`reports/suspend-pcie-l2-blocker-20261020.md` §1）；本机固件不支持 ⇒ 只做 s2idle |
| **强制 OSI 模式（内核 patch `use_osi=true`）** | 上游语义要求固件宣告（`psci_has_osi_support()`，`cpuidle-psci-domain.c:132`）；固件不宣告时 `psci_set_osi_mode()` 必失败（`FW_BUG failed to set OSI mode`）；强行推进 = 与 QCOM hyp 不配套，风险是挂死/唤不醒。**先花 3 min 把判据拿到（S5），再决定要不要立题** |
| **`powersave` governor** | schedutil + EAS 已在（`energy_model` 有 cpu0/cpu6），空载 95% 时间在最低档 556 MHz ⇒ 无收益，只丢性能 |
| **USB autosuspend / 关 gadget** | `usb-gadget` 显式 `power/control=on`（`packaging/elden-userland/files/usr/local/sbin/usb-gadget:19`）——那是 SSH/串口生命线；省下的量极小 |
| **UFS / interconnect devfreq 手调** | `1d84000.ufs` 只有 100/403 MHz 两档且由驱动 gear 决定；interconnect 无 devfreq 入口（父代理实测），手调没有稳定接口 |
| **主动限频/热兜底（`thermal-watch.sh AUTO_FALLBACK`）** | 无 trip 触发（`dmesg` 空）、空载 40 °C ⇒ 限频是负收益；`thermal-watch.sh` 只留监控（默认 `AUTO_FALLBACK=0`） |
| **cmdline 去 `clk_ignore_unused/pd_ignore_unused`（本轮）** | 需零写盘 `fastboot boot` 试验 + 可能打断显示/相机 probe；收益未知。列为**下一轮单独立项**（一件镜像、一条判据：能到桌面 + 能亮屏） |
| **`power_save=on` 永久开** | `net-selfheal.sh` 已经因为 ath12k 突发丢包强制 off（`reports/net-https-mtu-rootcause-20261018.md`）⇒ 只允许测量期 A/B，不落地 |

---

## 5. 上游事实与引用（全部 2026-11-25 抓取；=`https://raw.githubusercontent.com/torvalds/linux/master/…`，与仓内 `build/elden-tree`（`git describe` = `v7.4-rc3`）逐段一致）

| # | 事实 | 位置/URL |
|---|---|---|
| U1 | SM8750 CPU 拓扑与域空闲状态**上游就有**：每 CPU `power-domains=<&cpu_pdN>`；`cpu_pdN` 的 `domain-idle-states=<&cluster0_c4/cluster1_c4>`；`cluster0_pd/cluster1_pd` → `cluster_cl5`（`0x01000054`，2150/1983 µs，min-residency **9144 µs**）；`system_pd` → `domain_ss3`（`0x0200c354`，2800/4400 µs，min-residency **10150 µs**） | `arch/arm64/boot/dts/qcom/sm8750.dtsi`（本地 `build/elden-tree/...` 同文件 173 261 B 逐字节同尺寸） |
| U2 | 上游 psci **默认 PC 模式**（即使固件宣告 OSI）：`if (psci_has_osi_support()) { pr_info("OSI mode supported.\n"); /* Default to PC mode. */ psci_set_osi_mode(false); }` | `drivers/firmware/psci/psci.c:794` |
| U3 | 层级拓扑**只在 OSI 模式下启用**：`/* Currently limit the hierarchical topology to be used in OSI mode. */ if (!psci_has_osi_support()) return 0;` | `drivers/cpuidle/cpuidle-psci.c:253` |
| U4 | 域驱动取 `use_osi = psci_has_osi_support()` → `psci_set_osi_mode(use_osi)`；成功打 `Initialized CPU PM domain topology using %s mode`，失败打 `failed to create CPU PM domains ret=%d` | `drivers/cpuidle/cpuidle-psci-domain.c:132,167,175` |
| U5 | `of_get_cpu_state_node()` **优先**取 CPU 电源域的 `domain-idle-states`，再退到 `cpu-idle-states` ⇒ 每 CPU 只有 2 个 state 是**正常现象** | `drivers/of/cpu.c:191-209` |
| U6 | PSCI binding 明确 OSI 模式与层级表示法（"in PSCI firmware v1.0 the OS-Initiated (OSI) CPU suspend mode is introduced. Using a hierarchical representation helps to implement support for OSI mode and OS implementations may choose to mandate it."） | `Documentation/devicetree/bindings/arm/psci.yaml`（§PSCI/idle states，行 108–125） |
| U7 | `min-residency-us` 语义 = 选择该 state 的最小期望空闲时长（决定 cluster 状态是否值得进） | `Documentation/devicetree/bindings/cpu/idle-states.yaml`（行 110–230） |
| U8 | cpuidle sysfs：`/sys/devices/system/cpu/cpuidle/{current_driver,current_governor,available_governors}`；每状态 `disable` 是 **RW** | `Documentation/admin-guide/pm/cpuidle.rst`（行 162–170）+ `Documentation/ABI/testing/sysfs-devices-system-cpu`（行 144–197） |
| U9 | genpd debugfs 文件：`current_state` / `idle_states` / `idle_states_desc` / `active_time` / `total_idle_time` | `drivers/pmdomain/core.c:4241-4251` |
| U10 | 系统睡眠状态语义（s2idle vs deep；deep 需平台 `SYSTEM_SUSPEND`） | https://docs.kernel.org/admin-guide/pm/sleep-states.html |
| U11 | devfreq sysfs：`min_freq`（**覆盖 governor 请求**）、`max_freq`、`polling_interval`、`available_frequencies`、`trans_stat` | `Documentation/ABI/testing/sysfs-class-devfreq`（行 58–115）+ `drivers/devfreq/devfreq.c:1788` |
| U12 | msm GPU devfreq 默认 governor = `simple_ondemand`，且有空闲影子频点（`df->idle_freq`）机制 | `drivers/gpu/drm/msm/msm_gpu_devfreq.c:150-180,37-69` |
| U13 | ath12k 实现系统挂起（WoW：`WIPHY_WOWLAN_DISCONNECT/MAGIC_PKT/…` + `ath12k_wow_op_suspend` → `ath12k_hif_suspend`；PCI 侧 `SET_SYSTEM_SLEEP_PM_OPS`），等 HTC suspend completion **3 s ×3** | `drivers/net/wireless/ath/ath12k/wow.c:22-26,861-938`、`drivers/net/wireless/ath/ath12k/pci.c:1765-1816` |
| U14 | EAS 的开关是 sysctl `sched_energy_aware`（默认 1）；能量表 debugfs = `/sys/kernel/debug/energy_model` | `kernel/sched/topology.c:315-317` + `Documentation/power/energy-model.rst` |
| U15 | `turbostat` 属 x86 工具（`tools/power/x86/turbostat/`）⇒ aarch64 不适用 | `tools/power/x86/turbostat/turbostat.c` |

**仓内证据（非上游）**：`reports/thermal-baseline-20261125.md`（40 °C 基线、95% 时间 556 MHz、无限流）、
`.pi/memory/failures-kernel.md:9`（7.2 时代 `mem_sleep` 默认 deep ⇒ 进 mem 黑屏死机、PSCI SYSTEM_SUSPEND 未支持）、
`reports/suspend-pcie-l2-blocker-20261020.md`（deep 也 1.43 s exit；四次同型）、
`reports/qca-fw-download-suspend-20261021.md`（BT 下载 23.0/25.4 s vs `FW_DOWNLOAD_TIMEOUT` 3 s ⇒ 窗口内挂起必 `-110`）、
`reports/t9-vk130-pcie-l2-live-20261021.md`（`rfkill block bluetooth` 后 held **56.5 min**，`success=2`）、
`reports/t9-rtc-wake-limit-20261020.md`（RTC epoch 停滞导致 `rtcwake` 立即返回）、
`reports/device-session-20261116-vk192.md`（本 UTS 上 `rtcwake -m mem -s 45` **3/3 rc=0**、`success=3 fail=0`）、
`PITFALLS #651`（`wakeup_count` 读会阻塞、`suspend_stats` 是**目录**）、`PITFALLS #625`（`CONFIG_SUSPEND=y` 必须配同 config 全量重编的模块树）、`PITFALLS #694`（锁屏/熄屏路径的掉电链）、`PITFALLS #456`（dpms 只读 ⇒ 熄屏必须读回校验）。

---

## 6. 未找到 / 检索式（不编造）

| 想要的 | 状态 | 检索式（下次照抄） |
|---|---|---|
| 「psci 默认 PC 模式」的 commit hash / lore 链接 / 合并版本 | **未找到**（`lore.kernel.org` 403、`git.kernel.org` 被 Anubis 拦；`patchwork.kernel.org` 列表可达但按 subject 检索未命中） | `curl -sS "https://patchwork.kernel.org/api/1.2/patches/?q=Default+to+PC+mode"`；`curl -sS "https://www.spinics.net/lists/arm-kernel/msg*"` 内 `grep "Default to PC mode"` |
| SM8750 上游 DTS 引入 idle-states 的具体提交 | **未找到**（同上，commit API 403） | `curl -sS "https://patchwork.kernel.org/api/1.2/patches/?q=sm8750+idle+states"` |
| QCOM XBL/hyp 对 PSCI `SET_SUSPEND_MODE(OSI)` 的支持矩阵 | **未找到**（无公开文档）；只能靠本机 dmesg 判据（S5①） | `dmesg \| grep -i "OSI mode"`（设备侧）；上游检索 `"PSCI_1_0_FN_SET_SUSPEND_MODE"` |
| TB322FC 电池设计容量官方值 | **未找到**（用 `charge_full_design` 现查代替） | 设备侧 `cat /sys/class/power_supply/qcom-battmgr-bat/charge_full_design` |

---

## 7. 与仓库证据的口径差异（必须记账，避免下轮又被当成「从未挂起过」）

父代理本轮口径：「`suspend_stats=0/0` ⇒ suspend 从未成功挂起过」。
仓库有**同 UTS 的反证**：2026-11-13 夜 vk191、2026-11-16 vk192 两次上机都跑了 `rtcwake -m mem -s 45`，
**3/3 rc=0**、`suspend_stats success=3 fail=0`（`reports/device-session-20261113-vk191.md` §待机、
`reports/device-session-20261116-vk192.md` §待机；vk192 与在机 UTS 逐字相同）。

⇒ 正确读法：**`0/0` = 本 boot 未尝试过**，不是「内核不能挂」。真缺口是：
① 没有**长驻留**（≥5 min）与**日常触发路径**的证据；② BT/WiFi 两个已知弹出源没做前置；
③ 没人把它纳入部署门。§3 S4 就是补 ①，M1 的 `rfkill` 前置补 ②。
