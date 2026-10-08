#!/usr/bin/env bash
# elden kexec 二分单轮（SysRq-b 版；因 RESTART2 reboot-mode 通路被我们 kexec 测写坏，
# 用 SysRq b 硬重启进 fastboot，再 fastboot boot 诊断内核 vk69）。
# 判据：落盘日志出现 "Starting new kernel" = 跳过成功(元凶>K,往大)；不出现 = 掉电(元凶<=K,往小)。
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
K="${1:?usage: kexec-bs-cycle.sh <stop_after K>}"
export PATH="$HOME/bin:$PATH"
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 root@192.168.7.1"
BOOT="$ROOT/out/boot-elden-vk69.img"
LOG="/root/kmsg-bs$K.log"

echo "== [K=$K] 设备须在 vk64/Linux；写 bootloader magic + SysRq b → fastboot =="
timeout 12 $SSH 'eldroid-bootctl reboot bootloader' >/dev/null 2>&1; sleep 2
timeout 15 $SSH 'sync; echo 1 > /proc/sys/kernel/sysrq; echo b > /proc/sysrq-trigger' >/dev/null 2>&1
FB=""
for i in $(seq 1 24); do FB=$(timeout 4 fastboot devices 2>/dev/null); [ -n "$FB" ] && { echo "fastboot: $FB"; break; }; sleep 3; done
[ -z "$FB" ] && { echo "BOOT-FAIL: 没进 fastboot（可能需物理断电复位）"; exit 2; }
timeout 120 fastboot boot "$BOOT" >/dev/null 2>&1 || { echo "FASTBOOT-BOOT-FAIL"; exit 2; }
for i in $(seq 1 30); do timeout 8 $SSH 'echo OK' >/dev/null 2>&1 && break; sleep 5; done
$SSH "uname -r; sha1sum /root/Image.kd|cut -c1-8; [ -f /root/kd-dump.py ] && echo dumper-ok" 2>&1

echo "== [K=$K] 触发 kexec -e =="
timeout 40 $SSH "bash -s" <<EOF
set -e
D=/sys/kernel/kexec_diag
echo 0 > \$D/kexec_diag; echo $K > \$D/stop_after; echo 0 > \$D/settle_ms
echo PRE stop=[\$(cat \$D/stop_after)]
: > $LOG
setsid nohup python3 /root/kd-dump.py $LOG >/dev/null 2>&1 </dev/null &
sleep 0.4
kexec -l /root/Image.kd --dtb=/root/elden.dtb --command-line="\$(cat /proc/cmdline)" >/dev/null 2>&1
echo loaded=\$(cat /sys/kernel/kexec_loaded); sync; kexec -e
EOF
echo "== [K=$K] 触发已发出，等设备回来 =="

for i in $(seq 1 40); do timeout 8 $SSH 'echo x' >/dev/null 2>&1 && { echo "back ~$((i*5))s"; break; }; sleep 5; done
echo "== [K=$K] 判读 =="
$SSH "L=$LOG
if grep -qa 'Starting new kernel' \"\$L\"; then
  echo \"RESULT_K=$K: JUMPED → device_shutdown 返回 → 元凶>$K\"
else
  echo \"RESULT_K=$K: POWERED-OFF → device_shutdown 未返回 → 元凶<=$K\"
fi
echo last_done=\$(grep -a 'SD-done' \"\$L\"|tail -1|sed -E 's/.*caller=T[0-9]*;//')
echo last_idx=\$(tail -1 \"\$L\"|grep -oE 'idx=[0-9]+'|tail -1)" 2>&1
