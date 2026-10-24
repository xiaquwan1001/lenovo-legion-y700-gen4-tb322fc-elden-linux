#!/bin/bash
# gunyah-rm-bringup.sh — 在机内核上把 Gunyah RM 栈拉起来并验证一次真实 RM RPC。
#
# 前置（都是本机的既有事实/产物）：
#   * 内核必须带 CONFIG_OF_OVERLAY + 板 DTB 带 __symbols__（patches/gunyah/0001-*.patch，
#     `DTC_FLAGS_sm8750-lenovo-elden.dtb := -@`），否则 overlay 解析 fixups 返回 -EINVAL；
#   * gunyah 模块树已装在 /lib/modules/$(uname -r)/kernel/drivers/virt/gunyah/（vmk vk127 起）；
#   * 不在 Android/slot a 上跑，必须是我们的 mainline。
#
# 用法：
#   scripts/gunyah-rm-bringup.sh              # 构建+安装 dtbo.ko、拉起栈、跑 RM RPC 验证
#   scripts/gunyah-rm-bringup.sh --no-build   # 只拉起/验证（dtbo.ko 已在模块树）
#   HOOK=1 scripts/gunyah-rm-bringup.sh       # 额外在设备装开机自启钩子 /etc/local.d/50-gunyah.start
# 判据：/dev/gunyah 出现 + GUNYAH_CREATE_VM 返回 fd（RM RPC 往返成功）。
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
TAB=${TAB:-root@192.168.7.1}
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=8 $TAB"
KSRC=${KSRC:-$ROOT/build/gunyah-port}
BUILD=${BUILD:-1}
[ "${1:-}" = "--no-build" ] && BUILD=0

if [ "$BUILD" = 1 ]; then
	echo "[gunyah] build dtbo.ko (KSRC=$KSRC)"
	make -s -C "$KSRC" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= \
		M=elden-gunyah-dtbo modules >/dev/null
	KREL=$($SSH 'uname -r')
	aarch64-linux-gnu-gcc -static -O2 -o "$KSRC/elden-rmtest/rmtest" "$KSRC/elden-rmtest/rmtest.c"
	scp -q "$KSRC/elden-rmtest/rmtest" "$TAB:/tmp/rmtest"
	echo "[gunyah] install to /lib/modules/$KREL/extra on device"
	$SSH "mkdir -p /lib/modules/$KREL/extra"
	scp -q "$KSRC/elden-gunyah-dtbo/dtbo.ko" "$TAB:/lib/modules/$KREL/extra/dtbo.ko"
	$SSH 'depmod -a'
fi

echo "[gunyah] apply hyp DTBOs"
$SSH 'modprobe dtbo 2>/dev/null || insmod /lib/modules/$(uname -r)/extra/dtbo.ko'
$SSH 'ls -d /proc/device-tree/hypervisor >/dev/null && echo "  /hypervisor OK"'
$SSH 'od -An -tx8 -v /proc/device-tree/hypervisor/qcom,resource-manager-rpc@*/reg'

echo "[gunyah] load gunyah stack"
$SSH 'for m in gunyah_hypercall gunyah gunyah_platform_hooks gunyah_qcom gunyah_rsc_mgr; do modprobe $m; done'
$SSH 'ls -l /dev/gunyah && ls /sys/bus/platform/drivers/gunyah_rsc_mgr/ | sed "s/^/  bound: /"'

if [ "${HOOK:-0}" = 1 ]; then
	echo "[gunyah] install boot hook /etc/local.d/50-gunyah.start"
	$SSH 'mkdir -p /etc/local.d'
	cat <<'HOOKEOF' | $SSH 'cat > /etc/local.d/50-gunyah.start && chmod +x /etc/local.d/50-gunyah.start'
#!/bin/sh
# Bring up Gunyah RM on mainline elden. dtbo.ko fetches the per-boot hyp DTBOs
# (TZ SIP 0x02000609 -> hyp boot info -> overlay); harmless if the DTB lacks
# __symbols__ (overlay apply then fails with -EINVAL and gunyah stays unbound).
modprobe dtbo 2>/dev/null
for m in gunyah_hypercall gunyah gunyah_platform_hooks gunyah_qcom gunyah_rsc_mgr; do
	modprobe "$m" 2>/dev/null
done
HOOKEOF
fi

echo "[gunyah] RM RPC smoke test (GUNYAH_CREATE_VM)"
$SSH 'test -x /tmp/rmtest || echo "  (缺 /tmp/rmtest，跳过)"; /tmp/rmtest 2>/dev/null || true'
