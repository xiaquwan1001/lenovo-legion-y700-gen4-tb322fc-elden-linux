#!/bin/bash
# t14-rebuild.sh — T14「Mobian 换根重建 recipe」可执行化（2026-11-13，主机侧，零设备动作）
#
# 依据：reports/t14-userland-recipe-20261111.md §3（P0 → R1 → R2 → R3 → R4）。
# 前提已过时项不再检查（ELF 源码缺口已于 0e60a55 关闭，ok=7/missing=0）。
#
# 用法：
#   bash scripts/t14-rebuild.sh            # 全链：P0 检查 + R1 干跑 + R2 真编 + R3 门禁 + R4 渲染
#   bash scripts/t14-rebuild.sh --dry      # 只跑 R1（离线干跑）+ R3 + R4
#
# D1–D5（部署到 Mobian 根 + 功能验收）**待上机**，不在本脚本（C-U8）。
#
# 需人决策的 4 项（见 reports/t14-userland-recipe-20261111.md §4；本脚本不做裁决）：
#   D-1 diff=4 验收口径：eldroid-sensord/ffrumble/elden-ime-focusd/reboot2 重编 sha 与设备件
#       不一致；是否对 ffrumble（纯重写件）再做一轮上机 A/B 命中数回归（建议：做）。
#   D-2 musl 备选分支去留：waydroid-sensord.sh --target=musl 从未真跑；换根已定案，建议保留并
#       在 tsv 注明 unproven（不占运行成本）。
#   D-3 provenance 记账位置：artifacts.tsv 扩列（建议）还是单独 provenance 文件。
#   D-4 设备二进制兜底是否成文：建议在 README 明确「设备件仅作 A/B 参照，不进 MANIFEST 正式位」。
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
CHROOT=${CHROOT:-/opt/elden/arm64-sid}
DRY=0
[ "${1:-}" = "--dry" ] && DRY=1

fail() { echo "[t14] FATAL: $*" >&2; exit 1; }
step() { echo; echo "==== [t14] $* ===="; }

step "P0. arm64 glibc chroot 前置（离线检查）"
[ -x "$CHROOT/bin/sh" ] || fail "chroot 缺 $CHROOT/bin/sh —— 先: sudo debootstrap --arch=arm64 --variant=minbase --include=ca-certificates sid $CHROOT https://mirrors.ustc.edu.cn/debian"
ls /proc/sys/fs/binfmt_misc/ 2>/dev/null | grep -q qemu-aarch64 || fail "binfmt qemu-aarch64 未注册（apt 装 qemu-user-static）"
echo "P0 OK: $CHROOT + binfmt 就绪"

step "R1. 全量干跑（离线，7 配方逐条打印）"
( cd "$ROOT/packaging/elden-userland/build" && bash all.sh ) >/tmp/t14-r1.log 2>&1 || fail "R1 干跑 rc≠0（/tmp/t14-r1.log）"
grep -c . /tmp/t14-r1.log >/dev/null
echo "R1 OK（日志 /tmp/t14-r1.log，$(wc -l < /tmp/t14-r1.log) 行）"

step "R3. 门禁复核（--rebuildable，离线）"
bash "$ROOT/packaging/elden-userland/tools/verify.sh" --rebuildable | tail -3
# 判据：elf=7 ok=7 missing=0 recipe=7 dry-run-ok=7；FAIL=0

if [ "$DRY" = 1 ]; then
	echo; echo "[t14] --dry：跳过 R2/R4。D1–D5 待上机（C-U8）。"
	exit 0
fi

step "R2. 真跑 7 配方（root 配方自动要 sudo；静态件无需 chroot）"
( cd "$ROOT/packaging/elden-userland/build" && bash all.sh --apply ) || fail "R2 rc≠0"
# 判据 A：7 产物存在且为 aarch64
for f in out/hapticd/elden-hapticd out/sensord/eldroid-sensord out/ffrumble/ffrumble \
         out/sensord-host/waydroid-sensord out/sensord-host/waydroid-sensord-udp \
         out/ime-host/elden-ime-focusd out/reboot2/reboot2; do
	[ -f "$ROOT/$f" ] || fail "产物缺失: $f"
	file "$ROOT/$f" | grep -q aarch64 || fail "产物非 aarch64: $f"
done
echo "R2 OK: 7 产物齐全且为 aarch64"
echo "R2 判据 B（sha 对表，人工复核）："
echo "  identical 预期: elden-hapticd(aca55cb1…)、waydroid-sensord/-udp(22028ffd…)"
echo "  diff 允许（记 provenance，非功能漂移）: eldroid-sensord / ffrumble / elden-ime-focusd / reboot2"
sha256sum "$ROOT"/out/{hapticd/elden-hapticd,sensord/eldroid-sensord,ffrumble/ffrumble,sensord-host/waydroid-sensord,sensord-host/waydroid-sensord-udp,ime-host/elden-ime-focusd,reboot2/reboot2} 2>/dev/null || true

step "R4. 渲染两套 init 单元"
python3 "$ROOT/packaging/elden-userland/tools/render.py" || fail "render.py rc≠0"
echo "[t14] R4 OK: out/units/{openrc,systemd}/（git diff 人工复核漂移）"

echo
echo "[t14] 全链绿。判据 = R1 rc0 + R2 产物 7/7 aarch64 + R3 FAIL=0 + R4 rc0。"
echo "[t14] 4 个人决策项（D-1~D-4）见脚本头注；部署验收 D1–D5 待上机（C-U8）。"
