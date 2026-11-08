#!/bin/bash
# driver-snapshot.sh — 一次上机采集「尽可能多驱动」的状态快照，供两次启动（A/B）之间做 diff。
#
# 为什么（2026-11-08）：UEFI(ESP) 启动 vs boot_b 启动出现「不充电」差异，逐个子系统单查太慢。
# 本脚本把所有能低成本读到的驱动/子系统状态压成一份可比对的快照，一次启动 = 一次全量取证。
#
# 用法（在设备上跑）：
#   scripts/driver-snapshot.sh [输出目录]        # 默认 /root/snap-<uname>-<时间>
# 主机侧走 ssh：
#   ssh root@192.168.7.1 'bash -s' < scripts/driver-snapshot.sh
# 对比两次快照：
#   scripts/driver-snapshot-diff.sh <snapA> <snapB>
#
# 原则：**只读、绝不改设备状态**；单条探测 timeout 保护；任何失败都记 `-` 而不是让脚本退出。
set -uo pipefail

OUT=${1:-/root/snap-$(uname -r)-$(date +%H%M%S)}
mkdir -p "$OUT"
cd "$OUT" || exit 1

q() { timeout 8 sh -c "$1" 2>/dev/null || true; }

# ---------- 0. 元信息 ----------
{
  echo "release=$(uname -r)"
  echo "kernel=$(uname -v)"
  echo "booted_at=$(uptime -s 2>/dev/null | tr ' ' 'T')"
  echo "uptime=$(cut -d' ' -f1 /proc/uptime)"
  echo "root=$(findmnt -no SOURCE / 2>/dev/null)"
  echo "cmdline=$(cat /proc/cmdline)"
  echo "bootloader_esp=$(grep -c 'elden_bootloader=esp' /proc/cmdline || true)"
  echo "bootslot=$(cat /proc/cmdline | tr ' ' '\n' | grep slot_suffix || true)"
  echo "modules_loaded=$(lsmod | tail -n +2 | wc -l)"
  echo "modules_dir=$(ls /lib/modules/ | tr '\n' ',')"
  echo "dmi=$(q 'cat /sys/class/dmi/id/product_name')"
} > meta.txt

# ---------- 1. 电源 / 充电 / typec / PD（本轮问题的核心面） ----------
{
  for p in /sys/class/power_supply/*/; do
    n=$(basename "$p")
    echo "## $n"
    q "cat $p/uevent" | sort
    for f in input_current_limit current_max charge_behaviour charge_control_end_threshold; do
      [ -e "$p/$f" ] && echo "POWER_SUPPLY_${f^^}=$(q "cat $p/$f")"
    done
  done
} > power_supply.txt

{
  for d in /sys/class/typec/*/; do
    n=$(basename "$d")
    echo "## $n data_role=$(q "cat $d/data_role") power_role=$(q "cat $d/power_role")"
    for f in "$d"port*/; do
      [ -d "$f" ] || continue
      echo "  $(basename "$f") partner=$(q "cat $f/partner")"
      for pm in "$f"partner/; do
        [ -d "$pm" ] && echo "  partner: $(q "ls $pm | tr '\n' ' '")"
      done
    done
  done
  echo "## altmodes"
  q "ls -d /sys/class/typec/*/port*/*/ 2>/dev/null"
} > typec.txt

# ---------- 2. USB（角色 / gadget / 枚举） ----------
{
  echo "## udc"; q "ls /sys/class/udc"
  echo "## gadget_config"; q "ls /sys/kernel/config/usb_gadget/*/ 2>/dev/null"
  echo "## gadget_links"; q "for g in /sys/kernel/config/usb_gadget/*/; do echo \$g; ls \$g/configs/*/ 2>/dev/null; done"
  echo "## usb devices"; q "lsusb"
  echo "## usb bus tree"; q "ls /sys/bus/usb/devices"
  echo "## dwc3 state"; q "cat /sys/bus/platform/drivers/dwc3-qcom/*/state 2>/dev/null"
  echo "## dr_mode"; q "grep -h . /sys/bus/platform/drivers/dwc3-qcom/*/mode 2>/dev/null"
} > usb.txt

# ---------- 3. 电源域 / 时钟 / regulator / 互连 ----------
{
  echo "## genpd"; q "ls /sys/kernel/power 2>/dev/null; ls /sys/class/devfreq"
  echo "## devfreq_detail"; q "for d in /sys/class/devfreq/*/; do echo \$(basename \$d) \$(cat \$d/cur_freq 2>/dev/null); done"
  echo "## regulators"; q "for r in /sys/class/regulator/*/; do printf '%s %s %s\n' \$(basename \$r) \$(cat \$r/name 2>/dev/null) \$(cat \$r/state 2>/dev/null); done" | sort
  echo "## regulator_count"; q "ls /sys/class/regulator | wc -l"
  echo "## clk_summary_head"; q "head -5 /sys/kernel/debug/clk/clk_summary 2>/dev/null | cat"
  echo "## interconnect"; q "ls /sys/class/interconnect 2>/dev/null | head"
} > power_domains.txt

# ---------- 4. 显示 / 背光 / GPU ----------
{
  echo "## drm cards"; q "ls /sys/class/drm"
  echo "## connector status"; q "for c in /sys/class/drm/card*/card*-*/status; do echo \$(dirname \$c) =\$(cat \$c); done"
  echo "## backlight"; q "for b in /sys/class/backlight/*/; do echo \$(basename \$b) brightness=\$(cat \$b/brightness) max=\$(cat \$b/max_brightness); done"
  echo "## dpms"; q "for d in /sys/class/drm/card*/card*-*/dpms; do echo \$d=\$(cat \$d); done"
  echo "## gpu devfreq"; q "cat /sys/class/devfreq/*gpu*/cur_freq 2>/dev/null"
} > display.txt

# ---------- 5. 音频 / 传感器 / 输入 / LED / 触觉 ----------
{
  echo "## asound"; q "cat /proc/asound/cards"
  echo "## pcm"; q "cat /proc/asound/pcm | head -20"
  echo "## iio"; q "for d in /sys/bus/iio/devices/*/; do echo \$(basename \$d) \$(cat \$d/name 2>/dev/null); done"
  echo "## input"; q "cat /proc/bus/input/devices | grep -E '^N: |^H: ' | head -40"
  echo "## leds"; q "ls /sys/class/leds"
  echo "## ff devices"; q "ls /sys/class/input | head -20"
} > audio_sensor_input.txt

# ---------- 6. 网络 / 无线 / 蓝牙 / 相机 ----------
{
  echo "## links"; q "ip -br addr"
  echo "## wlan"; q "for w in /sys/class/net/wl*; do echo \$w \$(cat \$w/operstate 2>/dev/null) \$(cat \$w/mtu 2>/dev/null); done"
  echo "## ath12k"; q "ls /sys/bus/platform/drivers/ath12k* 2>/dev/null | head"
  echo "## bt"; q "ls /sys/class/bluetooth"
  echo "## video"; q "ls /dev/video* /dev/media* 2>/dev/null"
  echo "## camss"; q "ls /sys/bus/platform/drivers/camss* 2>/dev/null | head -3"
} > net_bt_cam.txt

# ---------- 7. 存储 / 热 / 复位 ----------
{
  echo "## block"; q "lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT"
  echo "## mmc"; q "for m in /sys/class/mmc_host/*/; do echo \$m; ls \$m 2>/dev/null; done | head -20"
  echo "## thermal"; q "for t in /sys/class/thermal/thermal_zone*/; do echo \$(basename \$t) \$(cat \$t/type 2>/dev/null) \$(cat \$t/temp 2>/dev/null); done"
  echo "## cooling"; q "ls /sys/class/thermal | grep cooling | wc -l"
  echo "## pstore"; q "ls -l /sys/fs/pstore/ /var/lib/systemd/pstore/ 2>/dev/null"
} > storage_thermal.txt

# ---------- 8. 系统级失败面（一次看全） ----------
{
  echo "## failed_units"; q "systemctl --failed --no-legend"
  echo "## dmesg_errors_by_driver"
  q "dmesg" | grep -iE "error|failed|fail |-110|-5 |timeout|denied|not found" \
    | sed -E 's/^\[[^]]*\] //; s/\[[^]]*\]//g' \
    | awk '{for(i=1;i<=NF;i++) if($i ~ /\.(c|h):|driver|probe|\[\]/){}; print}' \
    | sed -E 's/^ *//' | awk '{print $1}' | sed -E 's/:.*//' | sort | uniq -c | sort -rn | head -40
  echo "## module_problems"
  q "dmesg" | grep -iE "version magic|Unknown symbol|module verification|disagrees for version" | head -20
  echo "## dmesg_error_sample"
  q "dmesg" | grep -iE "error|failed|timeout" | tail -40
} > errors.txt

# ---------- 9. 汇总（一行一个探测项，便于 diff） ----------
{
  printf 'probe\tvalue\n'
  printf 'release\t%s\n'            "$(q 'uname -r')"
  printf 'modules_loaded\t%s\n'      "$(q 'lsmod | tail -n +2 | wc -l')"
  printf 'module_problems\t%s\n'     "$(q 'dmesg | grep -ciE "version magic|Unknown symbol"')"
  printf 'failed_units\t%s\n'        "$(q 'systemctl --failed --no-legend | wc -l')"
  printf 'power_supplies\t%s\n'      "$(q 'ls /sys/class/power_supply | wc -l')"
  printf 'battery_status\t%s\n'      "$(q 'cat /sys/class/power_supply/qcom-battmgr-bat/status')"
  printf 'battery_current_uA\t%s\n'  "$(q 'cat /sys/class/power_supply/qcom-battmgr-bat/current_now')"
  printf 'battery_charge_counter\t%s\n' "$(q 'cat /sys/class/power_supply/qcom-battmgr-bat/charge_counter')"
  printf 'usb_online\t%s\n'          "$(q 'cat /sys/class/power_supply/qcom-battmgr-usb/online')"
  printf 'usb_input_limit_uA\t%s\n'  "$(q 'cat /sys/class/power_supply/qcom-battmgr-usb/input_current_limit')"
  printf 'usb_current_now_uA\t%s\n'  "$(q 'cat /sys/class/power_supply/qcom-battmgr-usb/current_now')"
  printf 'typec_power_role\t%s\n'    "$(q 'cat /sys/class/typec/port0/power_role')"
  printf 'typec_data_role\t%s\n'     "$(q 'cat /sys/class/typec/port0/data_role')"
  printf 'udc\t%s\n'                 "$(q 'ls /sys/class/udc')"
  printf 'drm_cards\t%s\n'           "$(q 'ls /sys/class/drm | grep -c "^card[0-9]"')"
  printf 'drm_connected\t%s\n'       "$(q 'grep -l connected /sys/class/drm/card*/card*-*/status 2>/dev/null | wc -l')"
  printf 'backlight\t%s\n'           "$(q 'ls /sys/class/backlight | wc -l')"
  printf 'asound_cards\t%s\n'        "$(q 'grep -c "^ *[0-9]" /proc/asound/cards')"
  printf 'iio_devices\t%s\n'         "$(q 'ls /sys/bus/iio/devices | wc -l')"
  printf 'input_devices\t%s\n'       "$(q 'grep -c "^N: " /proc/bus/input/devices')"
  printf 'leds\t%s\n'                "$(q 'ls /sys/class/leds | wc -l')"
  printf 'net_wlan\t%s\n'            "$(q 'ls /sys/class/net | grep -c "^wl"')"
  printf 'bt_devices\t%s\n'          "$(q 'ls /sys/class/bluetooth | wc -l')"
  printf 'video_nodes\t%s\n'         "$(q 'ls /dev/video* 2>/dev/null | wc -l')"
  printf 'regulators\t%s\n'          "$(q 'ls /sys/class/regulator | wc -l')"
  printf 'thermal_zones\t%s\n'       "$(q 'ls -d /sys/class/thermal/thermal_zone* | wc -l')"
  printf 'devfreq\t%s\n'             "$(q 'ls /sys/class/devfreq | wc -l')"
  printf 'pstore_records\t%s\n'      "$(q 'ls /sys/fs/pstore 2>/dev/null | wc -l')"
} > summary.tsv

rm -f ../snap-last 2>/dev/null
ls -1 >/dev/null
echo "$OUT"
echo "--- summary ---"
cat summary.tsv
