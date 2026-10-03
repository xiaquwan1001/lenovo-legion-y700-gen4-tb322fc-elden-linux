set +e
DT=/proc/device-tree
echo "== model =="; cat $DT/model; echo
echo "== compatible =="; cat $DT/compatible | tr '\0' ' '; echo
echo "== qcom,msm-id =="; od -An -tx4 $DT/qcom,msm-id
echo "== qcom,board-id =="; od -An -tx4 $DT/qcom,board-id
echo "== qcom,pmic-id =="; od -An -tx4 $DT/qcom,pmic-id 2>/dev/null
echo "== reserved-memory nodes =="; ls $DT/reserved-memory/
echo "== splash / framebuffer region =="
for n in $DT/reserved-memory/*splash* $DT/reserved-memory/*cont_splash* $DT/reserved-memory/*display*; do
  [ -d "$n" ] && { echo "$n"; od -An -tx4 "$n/reg"; }
done
echo "== memory reg =="; od -An -tx4 $DT/memory/reg 2>/dev/null || od -An -tx4 $DT/memory@*/reg
echo "== chosen/bootargs =="; cat $DT/chosen/bootargs 2>/dev/null; echo
echo "== /proc/cmdline =="; cat /proc/cmdline
echo "== fb size =="; cat /sys/class/graphics/fb0/virtual_size 2>/dev/null; cat /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null
echo "== drm modes =="; cat /sys/class/drm/card*/card*-DSI-*/modes 2>/dev/null
echo "== kernel =="; cat /proc/version
echo "== props =="; getprop ro.boot.dtbo_idx; getprop ro.boot.dtb_idx; getprop ro.boot.slot_suffix; getprop ro.hardware; getprop ro.boot.hardware.platform; getprop ro.board.platform
echo "== modules =="; ls /vendor/lib/modules/ 2>/dev/null | tr '\n' ' '; echo; ls /vendor_dlkm/lib/modules/ 2>/dev/null | tr '\n' ' '; echo
