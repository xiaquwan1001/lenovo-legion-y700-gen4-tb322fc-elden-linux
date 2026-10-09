#!/bin/sh
# 在设备上当 root 跑：加载相机模块栈并做前后对拍（Q24 口径：加载后不要燄屏）。
# 有硬截止时间盒；只加载模块，不动燄屏设置（先跑 keep-awake.sh）。
L=${1:-/usr/local/sbin/camera-modules-load.sh}
export CAM_FORCE=${CAM_FORCE:-1}
PAT='camss|cci|camcc|bist|wl2868c|s5kjns|gc08a8|gt9764|leds_qcom|qcom_flash|system_heap'
M0=$(dmesg | wc -l)
echo "T0 $(date +%T) uptime=$(cut -d. -f1 /proc/uptime)s"
echo "== BEFORE  lsmod=$(lsmod | grep -icE "$PAT") media=$(ls /dev/media* 2>/dev/null | wc -l) video=$(ls /dev/video* 2>/dev/null | wc -l) dma_heap=$(ls /dev/dma_heap/ 2>/dev/null | tr '\n' ' ')"

timeout -k 10 180 sh "$L"; echo "loader rc=$?"

echo "== MODULES"
lsmod | grep -iE "$PAT" | awk '{printf "  %-26s used=%s\n", $1, $3}'
echo "== NODES   media=$(ls /dev/media* 2>/dev/null | wc -l) video=$(ls /dev/video* 2>/dev/null | wc -l) subdev=$(ls /dev/v4l-subdev* 2>/dev/null | wc -l) dma_heap=$(ls /dev/dma_heap/ 2>/dev/null | tr '\n' ' ')"
echo "== 禁止出现的（PITFALLS #130）: cma_heap=$(lsmod | grep -c cma_heap) reserved=$(ls /dev/dma_heap/reserved 2>/dev/null | wc -l)"
echo "== NEW DMESG（相机相关 / 错误）"
dmesg | tail -n +$((M0 + 1)) | grep -iE 'camss|cci|csiphy|csid|vfe|s5kjns|gc08a8|gt9764|bist|wl2868|flash|defer|error|fail|timeout' | head -22
echo "== NEW DMESG 总行数 $(dmesg | awk "END{print NR-$M0}")；其中 -EAGAIN/-ENODEV 计数 $(dmesg | tail -n +$((M0 + 1)) | grep -cE 'EAGAIN|ENODEV|EPROBE_DEFER')"
echo "T1 $(date +%T) uptime=$(cut -d. -f1 /proc/uptime)s"
