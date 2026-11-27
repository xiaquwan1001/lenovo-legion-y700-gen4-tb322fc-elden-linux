#!/bin/bash
# RETIRED 2026-11-27：ramoops 盖 initrd 的 QEMU 单轮回归，根因与守卫已定案 reports/uefi-grub-initrd-rootcause-20261115.md；可复核：reports/pstore-ram-initrd-guard-20261116.md
# qemu-ramoops-initrd-ab.sh — QEMU 复现「ramoops zone 盖住 initrd ⇒ 内核自己的 console
# 写坏 initrd」并用内核守卫（fs/pstore/ram.c: ramoops_skip_zone）拦住它的单轮回归。
#
# 背景（真机根因）：reports/uefi-grub-initrd-rootcause-20261115.md
#   Mu UEFI 把 GRUB LoadFile2 的 initrd buffer 分配进 DTB 的 ramoops@c2000000 保留区，
#   内核 t=0.0269 s 就把 ramoops 注册成 printk console ⇒ 每行 console 输出都写进那 8 MB
#   ⇒ initrd 中间几 MB 被内核自己覆盖 ⇒ 解包 ~120 ms 即 broken padding。
#
# 本脚本把同一条因果链在 QEMU 上做成两发 A/B（单轮 ≈ 35 s，TCG，无 KVM）：
#   守卫版   —— 串口出现 `ignoring console zone ... overlaps the initrd` + `Run /init`
#   未守卫版 —— 串口出现 `Initramfs unpacking failed: invalid magic`（或 ramoops console 注册后的 oops）
#
# 用法：
#   scripts/qemu-ramoops-initrd-ab.sh [IMAGE] [INITRD]         # 期望「守卫生效 + 起得去」
#   scripts/qemu-ramoops-initrd-ab.sh --expect-fail [IMAGE] [INITRD]  # 期望「被写坏」
#   IMAGE  默认 build/daily/arch/arm64/boot/Image
#   INITRD 默认 out/initramfs-slim.cpio.gz
#
# 配方要点（本轮踩过的，改脚本前先读）：
#   - `-M virt` 必须 `acpi=off`（本内核无 CONFIG_ACPI ⇒ build_all_zonelists 空指针 panic）。
#   - **`-dtb` 与 `-device loader` 都落在 RAM 尾部**：`-dtb` 在 -m 2048 下默认装到
#     0x48000000，initrd 放同址会被 QEMU 判 "regions overlap" 直接拒启动 ⇒ initrd/ramoops
#     一律放 **0x50000000/0x4ff00000**。
#   - initrd 用 **`initrd=<phys>,<size>` cmdline + `-device loader,file=…,addr=…,force-raw=on`**
#     装进内存（不用 `-initrd`）：只有走 phys_initrd_start 这条，物理地址才是我们钉死的，
#     ramoops 才能与之重叠。
#   - ramoops 节点插在 QEMU 自己 dump 出来的 virt dtb 里（`-M virt,dumpdtb=…`），
#     布局 = dmesg(0x100000) | console(0x100000) | pmsg(0) | ftrace(0)，console 段正好盖住 initrd。
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
EXPECT=guard
[ "${1:-}" = "--expect-fail" ] && { EXPECT=fail; shift; }
IMAGE=${1:-$ROOT/build/daily/arch/arm64/boot/Image}
INITRD=${2:-$ROOT/out/initramfs-slim.cpio.gz}
W=${W:-/tmp/qemu-ramoops-ab}

RAMOOPS=0x4ff00000
INITRD_ADDR=0x50000000

QEMU=${QEMU:-qemu-system-aarch64}
for f in "$IMAGE" "$INITRD"; do [ -f "$f" ] || { echo "缺 $f" >&2; exit 2; }; done
command -v dtc >/dev/null || { echo "缺 dtc（apt install device-tree-compiler）" >&2; exit 2; }

ISIZE=$(stat -c %s "$INITRD")
mkdir -p "$W"

# 1) QEMU virt 的 dtb（-m 必须与下面实跑一致：dtb 里的 memory 节点按 -m 生成）
if [ ! -s "$W/virt-m2048.dtb" ]; then
	timeout 60 $QEMU -M virt,acpi=off,dumpdtb="$W/virt-m2048.dtb" -m 2048 -smp 4 \
		-nographic -serial none >/dev/null 2>&1 || true
fi

# 2) 插 ramoops 节点（console 段盖住 initrd 起点）；节点名不可省，dtc 用 reg 校验。
dtc -I dtb -O dts "$W/virt-m2048.dtb" -o "$W/virt.dts" 2>/dev/null
python3 - "$W/virt.dts" "$W/virt-ramoops.dts" "$RAMOOPS" <<'PY'
import sys
src, dst, base = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(src).read()
node = f'''
\tramoops@{int(base, 16):x} {{
\t\tcompatible = "ramoops";
\t\treg = <0x00 {base} 0x00 0x200000>;
\t\trecord-size = <0x20000>;
\t\tconsole-size = <0x100000>;
\t}};
'''
i = s.index('\tchosen {')
open(dst, 'w').write(s[:i] + node + s[i:])
PY
dtc -I dts -O dtb "$W/virt-ramoops.dts" -o "$W/virt-ramoops.dtb" 2>/dev/null || {
	echo "dtc 合成失败（看 $W/virt-ramoops.dts）" >&2; exit 3; }

# 3) 一发启动
LOG="$W/$(basename "$IMAGE").$EXPECT.log"
timeout -k 5 150 $QEMU -M virt,acpi=off -cpu cortex-a72 -m 2048 -smp 4 -nographic \
	-kernel "$IMAGE" -dtb "$W/virt-ramoops.dtb" \
	-device loader,file="$INITRD",addr=$INITRD_ADDR,force-raw=on \
	-append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 keep_bootcon loglevel=8 ignore_loglevel panic=-1 initrd=$INITRD_ADDR,$ISIZE" \
	> "$LOG" 2>&1

# 4) 判据
guard_warn=$(grep -c "ignoring console zone .* overlaps the initrd" "$LOG")
run_init=$(grep -c "Run /init as init process" "$LOG")
bad_magic=$(grep -c "Initramfs unpacking failed" "$LOG")
oops=$(grep -c "Kernel panic\|Oops\|Unable to handle" "$LOG")

echo "log: $LOG"
echo "  ignoring console zone = $guard_warn   Run /init = $run_init   unpack failed = $bad_magic   panic/oops = $oops"
if [ "$EXPECT" = guard ]; then
	if [ "$guard_warn" -ge 1 ] && [ "$run_init" -ge 1 ] && [ "$bad_magic" -eq 0 ]; then
		echo "PASS(guard): 守卫跳过与 initrd 重叠的 console 段，initrd 完整解包并起进 /init"
		exit 0
	fi
	echo "FAIL(guard): 期望守卫 + 起得去（见上三数）" >&2
	tail -20 "$LOG" >&2
	exit 1
else
	if [ "$bad_magic" -ge 1 ] || [ "$oops" -ge 1 ]; then
		echo "PASS(expect-fail): 无守卫内核被自己的 ramoops console 写坏 initrd（复现真机现象）"
		exit 0
	fi
	echo "FAIL(expect-fail): 没复现出破坏，检查 ramoops 是否真与 initrd 重叠" >&2
	tail -20 "$LOG" >&2
	exit 1
fi
