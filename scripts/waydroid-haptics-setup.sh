#!/bin/bash
# waydroid-haptics-setup.sh — 部署「Waydroid 马达透传」桥（TASKS §6 ⑤）
#
# 原理
#   容器里的 waydroid vibrator HAL（android.hardware.vibrator@1.0-service.waydroid）
#   只会写 AOSP 的 LED-trigger 路径：
#       /sys/class/leds/vibrator/{state,duration,activate}
#   主线 elden 没有该节点 ⇒ 写入静默失败（ofstream 不检查返回值），Android 以为成功。
#   桥 = 宿主持有一份这三个文件，经 lxc.mount.entry 覆盖到容器的 /sys/class/leds；
#   宿主 daemon elden-hapticd 轮询文件，把请求转成 aw86927 的 input FF_RUMBLE。
#
# 用法（主机）：
#   bash scripts/waydroid-haptics-setup.sh                # 部署 + 启动（不重启容器）
#   bash scripts/waydroid-haptics-setup.sh --restart      # 部署后重启 waydroid 容器
#   bash scripts/waydroid-haptics-setup.sh --verify       # 只做端到端验证
set -eu
cd "$(dirname "$0")/.."

TAB=${TAB:-root@192.168.7.1}
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $TAB"
RESTART=0
VERIFY_ONLY=0
for a in "$@"; do
  case "$a" in
    --restart) RESTART=1 ;;
    --verify)  VERIFY_ONLY=1 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done

if [ "$VERIFY_ONLY" = 0 ]; then
  echo "[haptics] 1/4 编译并上传 daemon"
  bash scripts/build-hapticd.sh
  scp -q out/hapticd/elden-hapticd "$TAB:/usr/local/bin/elden-hapticd"
  scp -q rootfs/persistent-overlay/elden-hapticd.initd "$TAB:/etc/init.d/elden-hapticd"

  echo "[haptics] 2/4 设备侧安装 init 脚本 + lxc 挂载项（幂等）"
  $SSH 'sh -s' <<'EOS'
set -eu
chmod 755 /usr/local/bin/elden-hapticd /etc/init.d/elden-hapticd
rc-update show 2>/dev/null | grep -q 'elden-hapticd' || rc-update add elden-hapticd default
/etc/init.d/elden-hapticd start 2>&1 | tail -2 || true

CFG=/var/lib/waydroid/lxc/waydroid/config
MARK="# >>> elden-haptics bridge"
if ! grep -qF "$MARK" "$CFG"; then
  cp -n "$CFG" "$CFG.bak-elden-haptics" 2>/dev/null || true
  cat >> "$CFG" <<'CFGEOF'

# >>> elden-haptics bridge (2026-10-13) — 让容器看到 fake /sys/class/leds/vibrator
# ① 把宿主 bridge 目录绑进容器（容器 /run 是 tmpfs，供复挂/取证用）
lxc.mount.entry = /run/elden-haptic run/elden-haptic none bind,create=dir,optional 0 0
# ② 真正覆盖 leds class（容器内 /sys 是只读 sysfs，只能在已有目录上 bind）
lxc.mount.entry = /run/elden-haptic/leds sys/class/leds none bind,create=dir,optional 0 0
# <<< elden-haptics bridge
CFGEOF
  echo "  lxc config: 已追加挂载项（备份 $CFG.bak-elden-haptics）"
else
  echo "  lxc config: 挂载项已存在，跳过"
fi
EOS

  echo "[haptics] 3/4 重启容器以生效"
  if [ "$RESTART" = 1 ]; then
    # 注意：wd-ctl.sh stop 只停 LXC，不停 session/container 两个 python daemon；
    # 残留 session 会让下一次 session start 直接返回 "already running"、容器不再拉起。
    # 这里做「全量」重启（模式用 [d] 防 pgrep 命中自己）。
    $SSH 'for p in $(pgrep -f "usr/bin/waydroi[d]"); do kill -9 "$p"; done; sleep 2; \
          lxc-stop -P /var/lib/waydroid/lxc -n waydroid -k 2>/dev/null || true; sleep 1; \
          setsid nohup waydroid container start >/tmp/wd-c.log 2>&1 </dev/null & sleep 10; \
          /usr/local/sbin/wd-ctl.sh session >/dev/null; sleep 25; /usr/local/sbin/wd-ctl.sh state'
  else
    echo "  （未加 --restart：容器内如需看到新挂载，请手动重启容器）"
  fi
fi

echo "[haptics] 4/4 端到端验证"
$SSH 'sh -s' <<'EOS'
set -u
echo "-- 宿主 daemon:"; pgrep -a elden-hapticd || echo "  (未运行)"
echo "-- bridge 文件:"; ls -l /run/elden-haptic/leds/vibrator/ 2>/dev/null
echo "-- 容器内可见性:"; timeout 15 waydroid shell -- sh -c 'ls -l /sys/class/leds/vibrator/ 2>&1; cat /sys/class/leds/vibrator/activate 2>&1' 2>&1 | tail -8
echo "-- 容器内写入 + kprobe 取证:"
T=/sys/kernel/tracing; [ -d "$T" ] || T=/sys/kernel/debug/tracing
if [ -w "$T/tracing_on" ]; then
  grep -q '^p:hph ' "$T/kprobe_events" 2>/dev/null || echo 'p:hph aw86927_haptics_play' >> "$T/kprobe_events" 2>/dev/null
  echo 0 > "$T/tracing_on"; echo > "$T/trace"
  echo 1 > "$T/events/kprobes/hph/enable" 2>/dev/null; echo 1 > "$T/tracing_on"
  timeout 15 waydroid shell -- sh -c 'echo 1 > /sys/class/leds/vibrator/state; echo 400 > /sys/class/leds/vibrator/duration; echo 1 > /sys/class/leds/vibrator/activate' 2>&1 | tail -2
  sleep 1
  echo "  aw86927_haptics_play hits: $(grep -c 'hph:' "$T/trace" 2>/dev/null)"
  echo 0 > "$T/events/kprobes/hph/enable" 2>/dev/null; echo 0 > "$T/tracing_on" 2>/dev/null
else
  echo "  (tracefs 不可写，跳过 kprobe 取证)"
fi
echo "-- daemon log 尾:"; tail -4 /var/log/elden-hapticd.log 2>/dev/null
EOS
echo "[haptics] 完成。Android 侧触发示例："
echo "  ssh $TAB \"waydroid shell cmd vibrator_manager vibrate 500\""
