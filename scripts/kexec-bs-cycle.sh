#!/usr/bin/env bash
# elden kexec 二分单轮。进 fastboot 只走一个入口：`eldroid-bootctl reboot bootloader`
  # （脚本内部已挂 6 s sysrq-b 看门狗；**不要再叠加** sysrq-b —— 两个复位请求落同一关机窗口
  # 正好是 PITFALLS #368 的症状区。kexec 不可用是 PITFALLS #154 的 device_shutdown()，与 restart 通路无关）。
# 判据：落盘日志出现 "Starting new kernel" = 跳过成功(元凶>K,往大)；不出现 = 掉电(元凶<=K,往小)。
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
K="${1:?usage: kexec-bs-cycle.sh <stop_after K>}"
export PATH="$HOME/bin:$PATH"
# 2026-11-18 审计 R2 P1-5：裸 fastboot（无 -s/-k/无锁/无槽属性回读）⇒ 多发到别的设备、
# 或把失败发记成「kexec 不可用」。统一走 lib-fastboot（SER 必填 + timeout -k + 禁管道）。
. "$ROOT/scripts/lib-device-lock.sh" 2>/dev/null || true
device_lock_acquire 2>/dev/null || true
. "$ROOT/scripts/lib-fastboot.sh"
[ -n "${SER:-}" ] || { echo "需显式 SER=<SN>（禁止裸 fastboot，PITFALLS #371）" >&2; exit 2; }
SSH="timeout -k 2 20 ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=6 \
-o ServerAliveInterval=5 -o ServerAliveCountMax=2 -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR ${TAB:-root@192.168.7.1}"
BOOT=${BOOT:?需 BOOT=<boot.img>（旧默认 vk69 已随 out 清理删除）}
LOG="/root/kmsg-bs$K.log"

echo "== [K=$K] 设备须在 vk64/Linux；写 bootloader magic + SysRq b → fastboot =="
timeout 12 $SSH 'sync; eldroid-bootctl reboot bootloader' >/dev/null 2>&1 || true
FB=""
for i in $(seq 1 24); do fbdevices "$SER" && { FB=$_FB_OUT; echo "fastboot: $FB"; break; }; sleep 3; done
[ -z "$FB" ] && { echo "BOOT-FAIL: 没进 fastboot（可能需物理断电复位）"; exit 2; }
# 槽属性回读（每次 fastboot boot 都可能被 ABL 记一次失败）
echo "--- boot_b 槽属性（boot 前）"; $SSH 'python3 /usr/local/sbin/slot-attr.py show 2>/dev/null | grep -E "^  boot_[ab] "' 2>&1 || true
FBTO=120 fbx boot "$BOOT" >/dev/null 2>&1 || { echo "FASTBOOT-BOOT-FAIL: $_FB_OUT"; exit 2; }
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
