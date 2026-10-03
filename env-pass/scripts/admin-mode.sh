#!/system/bin/sh
# 退出「干净环境」回到「刷机/管理」模式（需 root，用设备端终端执行）
#    sh /data/local/tmp/envpass/admin-mode.sh
# 效果：开 USB 调试 + 装回 KSU 管理器（可 GUI 管理模块）。

echo "[envpass] enable USB debugging"
settings put global adb_enabled 1
settings put global development_settings_enabled 1
setprop ctl.start adbd 2>/dev/null

echo "[envpass] reinstall KSU manager if apk present"
for p in /data/local/tmp/envpass/KernelSU_v3.2.5_32525-release.apk /sdcard/KernelSU_v3.2.5_32525-release.apk; do
  [ -f "$p" ] && pm install -r "$p"
done
echo "[envpass] done."
