#!/bin/bash
# waydroid-haptics-aidl-deploy.sh — 部署 AIDL V2 vibrator HAL（TASKS C10 二期：幅度 + cancel）
#
# 零写盘：
#   ① 把自编 AIDL HAL 二进制 bind 到镜像里那条 HIDL 服务路径上
#      （镜像的 rc 会照旧拉起它，省掉 mount_overlays / 改 init）
#   ② 把「镜像原有 vintf fragment + 我们的 fragment」目录 bind 到容器
#      /vendor/etc/vintf/manifest（servicemanager 强制校验声明：未声明 = addService -3）
#
# 顺序纪律：**必须先停容器再上传**，否则正在运行的 bind 目标会 ETXTBSY
#（scp 报 `dest open ...: Failure`）。
#
# 用法（主机）：
#   bash scripts/waydroid-haptics-aidl-deploy.sh             # 停容器→上传→起容器→验证
#   bash scripts/waydroid-haptics-aidl-deploy.sh --no-restart  # 只上传/改配置（容器本来就没在跑时用）
#   bash scripts/waydroid-haptics-aidl-deploy.sh --verify      # 只验证
# 回退：删掉 config 里 '# >>> elden-haptics aidl' 段的两条 mount.entry，再全量重启容器。
set -eu
cd "$(dirname "$0")/.."

TAB=${TAB:-root@192.168.7.1}
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $TAB"
WB=${WB:-/mnt/Samsung/waydroid-build}
PROD=$WB/out/target/product/waydroid_arm64_only
BIN=$PROD/vendor/bin/hw/android.hardware.vibrator-service.elden
XML=$PROD/vendor/etc/vintf/manifest/android.hardware.vibrator.elden.xml
RESTART=1
VERIFY_ONLY=0
for a in "$@"; do
  case "$a" in
    --no-restart) RESTART=0 ;;
    --verify)     VERIFY_ONLY=1 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done

if [ "$VERIFY_ONLY" = 0 ]; then
  [ -f "$BIN" ] || { echo "缺少 HAL 二进制：$BIN（先按 patches-userland/waydroid-haptics-aidl/README.md 编译）" >&2; exit 1; }
  [ -f "$XML" ] || { echo "缺少 vintf fragment：$XML" >&2; exit 1; }

  if [ "$RESTART" = 1 ]; then
    echo "[aidl] 1/4 停容器（释放 bind 目标；顺带清残留 session daemon）"
    $SSH 'for p in $(pgrep -f "usr/bin/waydroi[d]"); do kill -9 "$p"; done; sleep 2;
          lxc-stop -P /var/lib/waydroid/lxc -n waydroid -k 2>/dev/null || true; sleep 1; echo "  stopped"'
  fi

  echo "[aidl] 2/4 上传 HAL + fragment"
  $SSH 'mkdir -p /root/wd/vib /root/wd/vib-frags /root/wd/vib-incoming'
  scp -q "$BIN" "$TAB:/root/wd/vib/hw-vibrator-aidl"
  scp -q "$XML" "$TAB:/root/wd/vib-incoming/android.hardware.vibrator.elden.xml"

  echo "[aidl] 3/4 拼 fragment 目录 + 加 lxc 挂载项（幂等）"
  $SSH 'sh -s' <<'EOS'
set -eu
chmod 755 /root/wd/vib/hw-vibrator-aidl
mkdir -p /mnt/vnd
mountpoint -q /mnt/vnd || mount -o loop,ro /var/lib/waydroid/images/vendor.img /mnt/vnd
cp -f /mnt/vnd/etc/vintf/manifest/*.xml /root/wd/vib-frags/ 2>/dev/null || true
umount /mnt/vnd 2>/dev/null || true
cp -f /root/wd/vib-incoming/*.xml /root/wd/vib-frags/
ls /root/wd/vib-frags/

CFG=/var/lib/waydroid/lxc/waydroid/config
MARK="# >>> elden-haptics aidl"
if ! grep -qF "$MARK" "$CFG"; then
  cp -n "$CFG" "$CFG.bak-elden-haptics-aidl" 2>/dev/null || true
  cat >> "$CFG" <<'CFGEOF'

# >>> elden-haptics aidl (2026-10-13) — 自编 AIDL V2 vibrator HAL 换掉镜像的 HIDL 1.0（幅度/cancel）
lxc.mount.entry = /root/wd/vib/hw-vibrator-aidl vendor/bin/hw/android.hardware.vibrator@1.0-service.waydroid none bind,optional 0 0
lxc.mount.entry = /root/wd/vib-frags vendor/etc/vintf/manifest none bind,optional 0 0
# <<< elden-haptics aidl
CFGEOF
  echo "  lxc config: 已追加（备份 $CFG.bak-elden-haptics-aidl）"
else
  echo "  lxc config: 已存在，跳过"
fi
EOS

  if [ "$RESTART" = 1 ]; then
    echo "[aidl] 4/4 起容器 + 会话"
    $SSH 'setsid nohup waydroid container start >/tmp/wd-c.log 2>&1 </dev/null & sleep 10; /usr/local/sbin/wd-ctl.sh session >/dev/null; sleep 25; /usr/local/sbin/wd-ctl.sh state | head -3'
  fi
fi

echo "[aidl] 验证"
$SSH 'sh -s' <<'EOS'
L=/var/log/elden-hapticd.log
echo "-- capabilities:"; timeout 25 waydroid shell -- dumpsys vibrator_manager 2>/dev/null | grep -oE "mCapabilities=\[[^]]*\]" | head -1
echo "-- supportedEffects:"; timeout 25 waydroid shell -- dumpsys vibrator_manager 2>/dev/null | grep -oE "mSupportedEffects=\[[^]]*\]" | head -2
echo "-- 幅度（oneshot -a 300 160）:"; base=$(wc -l < $L)
timeout 20 waydroid shell -- cmd vibrator_manager synced oneshot -a 300 160 >/dev/null 2>&1; sleep 1; awk -v b=$base 'NR>b' $L
echo "-- prebaked 0（CLICK，走 perform）:"; base=$(wc -l < $L)
timeout 20 waydroid shell -- cmd vibrator_manager synced prebaked 0 >/dev/null 2>&1; sleep 1; awk -v b=$base 'NR>b' $L
echo "-- cancel（后台 8 s 振，1.2 s 后取消）:"; base=$(wc -l < $L)
( timeout 25 waydroid shell -- cmd vibrator_manager synced -B oneshot 8000 >/dev/null 2>&1 & ); sleep 1.2
stamp=$(date +%T); timeout 20 waydroid shell -- cmd vibrator_manager cancel >/dev/null 2>&1
sleep 1.5; awk -v b=$base 'NR>b' $L; echo "   cancel 发于 $stamp（看 OFF 时刻是否≈同秒）"
echo "-- HAL 侧日志:"; timeout 20 waydroid shell -- logcat -d 2>/dev/null | grep vibrator.elden | tail -5
EOS
