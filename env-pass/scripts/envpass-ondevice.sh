#!/system/bin/sh
# 一键在设备上装好「过环境」隐藏栈（KernelSU 官方版，无需刷机）。
# 用法：root shell 里执行  sh /data/local/tmp/envpass/envpass-ondevice.sh
# 或主机： adb shell su -c "sh /data/local/tmp/envpass/envpass-ondevice.sh"
set -u
KS=/data/adb/ksu/bin/ksud
KSD=/data/local/tmp/envpass
RP=/data/adb/ksu/bin/resetprop

say(){ echo "[envpass] $*"; }

say "1) install modules (幂等：已装跳过)"
installed_list() {
  ls /data/adb/modules/ 2>/dev/null
}
for m in Zygisk-Next-1.5.0-deflate Shamiko-v1.2.5-414-deflate-patched Shamiko-v1.2.5-414-deflate PlayIntegrityFork-v18-deflate TrickyStore-v1.4.1-deflate; do
  if [ -f "$KSD/$m.zip" ]; then
    # 取 zip 内 module.prop 的 id，已装则跳过
    mid=$(unzip -p "$KSD/$m.zip" module.prop 2>/dev/null | sed -n 's/^id=//p' | tr -d '\r')
    if [ -n "$mid" ] && [ -f "/data/adb/modules/$mid/module.prop" ]; then
      say "  skip $m (已装: $mid)"
      continue
    fi
    "$KS" module install "$KSD/$m.zip" && say "  installed $m" || say "  FAILED $m"
  fi
done

say "2) install props module"
rm -rf /data/adb/modules/envpass_props
cp -r "$KSD/envpass_props" /data/adb/modules/envpass_props
chmod 755 /data/adb/modules/envpass_props/post-fs-data.sh /data/adb/modules/envpass_props/service.sh
say "  ok"

say "3) Shamiko whitelist mode (hide root from everything except allowlisted root apps)"
mkdir -p /data/adb/shamiko
: > /data/adb/shamiko/whitelist

say "4) KSU feature: selinux_hide"
"$KS" feature set 4 1 2>/dev/null && say "  selinux_hide enabled" || say "  (selinux_hide not settable)"

say "5) apply props now (no-reboot preview)"
"$RP" -f /data/adb/modules/envpass_props/props.txt 2>/dev/null
say "  ro.boot.verifiedbootstate=$(getprop ro.boot.verifiedbootstate) ro.boot.flash.locked=$(getprop ro.boot.flash.locked)"

say "done. reboot to activate Zygisk."
