#!/system/bin/sh
# 进入「游戏/干净环境」模式（需 root）
# 用法（设备端终端或 adb shell su -c）：
#    sh /data/local/tmp/envpass/gaming-mode.sh
# 效果：关 USB 调试 + 确保 KSU 管理器已卸载 + 再次应用属性伪装。
# 注意：关 USB 调试会断开 adb；之后用 admin-mode.sh 或开发者选项恢复。

KS=/data/adb/ksu/bin/ksud
RP=/data/adb/ksu/bin/resetprop

echo "[envpass] apply prop spoof"
[ -f /data/adb/modules/envpass_props/props.txt ] && "$RP" -f /data/adb/modules/envpass_props/props.txt

echo "[envpass] remove KSU manager (keeps root; reinstall with admin-mode.sh)"
pm uninstall me.weishu.kernelsu 2>/dev/null
pm uninstall com.topjohnwu.magisk 2>/dev/null

echo "[envpass] hide root from all apps (Shamiko whitelist)"
mkdir -p /data/adb/shamiko; : > /data/adb/shamiko/whitelist

echo "[envpass] disable USB debugging (adb will drop)"
settings put global adb_enabled 0
setprop ctl.stop adbd 2>/dev/null

echo "[envpass] done. Detectors: Native Detector should be 'normal'."
