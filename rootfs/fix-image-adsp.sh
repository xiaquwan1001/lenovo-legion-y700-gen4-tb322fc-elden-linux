#!/bin/bash
# Install the ADSP bring-up service into the Ubuntu image.
#
# The built-in remoteproc driver probes before switch_root, so its automatic
# firmware request fails with ENOENT and the ADSP stays offline. Nothing then
# creates the PMIC_RTR_ADSP_APPS rpmsg channel, so qcom_battmgr never gets any
# battery data. Starting the ADSP once the real root is mounted fixes that.
set -euo pipefail
R=${1:-/mnt/rootfs}
S=${S:-/home/xuqianhui1001/y700-elden/rootfs}

test -f "$R/lib/firmware/qcom/sm8750/elden/adsp.mdt"

install -m 0755 "$S/elden-start-adsp" "$R/usr/local/sbin/elden-start-adsp"
install -m 0644 "$S/elden-adsp.service" "$R/etc/systemd/system/elden-adsp.service"
ln -sfn ../elden-adsp.service \
	"$R/etc/systemd/system/multi-user.target.wants/elden-adsp.service"

echo "== installed"
ls -l "$R/usr/local/sbin/elden-start-adsp" \
      "$R/etc/systemd/system/elden-adsp.service" \
      "$R/etc/systemd/system/multi-user.target.wants/elden-adsp.service"
