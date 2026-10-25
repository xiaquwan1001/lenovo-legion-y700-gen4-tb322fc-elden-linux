#!/bin/sh
# gunyah-modprobe.sh — 加载 Gunyah RM 驱动栈（**当前不启用**）
#
# 背景：2026-10-25 裁决——本 firmware 下纯 Linux 宿主 + 主线 gunyah 驱动建 VM 走不通
# （VM_INIT 恒定 0xA MEM_INVALID，厂商路径依赖主线不存在的 MEM_DONATE + gunyah_loader）。
# 见 reports/gunyah-decision-20261025.md。保留此脚本只为「模块树还在机器上时能一键加载」，
# 不排期、不进默认 runlevel。
#
# dtbo.ko 负责取每次启动的 hyp DTBO（TZ SIP 0x02000609 → hyp boot info → overlay）。

modprobe dtbo 2>/dev/null
for m in gunyah_hypercall gunyah gunyah_platform_hooks gunyah_qcom gunyah_rsc_mgr \
         gunyah_vcpu gunyah_irqfd gunyah_ioeventfd gunyah_qtvm; do
	modprobe "$m" 2>/dev/null || echo "gunyah-modprobe: $m 未加载" >&2
done
exit 0
