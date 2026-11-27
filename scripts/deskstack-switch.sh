#!/bin/sh
# RETIRED 2026-11-27：0.58 vs 0.59 桌面栈整档 A/B 对照执行器，对照已完成，配方在 reports/；可复核：reports/scripts-index-20261120.md
# deskstack-switch.sh — 桌面栈整档切换（phoc + phosh 全套），用于 T20/T19 的 A/B 对照
#
# 背景（2026-11-14）：设备桌面栈是混装 —— phosh 三包 0.58.0-1，phoc/portal/osk 0.59~rc1。
#   「电源键不熄屏」「滚动撕裂」都缺一次「整档 0.58 vs 整档 0.59」对照，混装对照无意义。
#
# 两档定义：
#   0.58 = /usr/bin/phoc.syncobj-20261111（自编 0.58.0-syncobj, 863731b0…）
#          + phosh/libphosh/phosh-common 0.58.0-1 + xdg-desktop-portal-phosh 0.58.0-1
#          + phosh-osk-stevia 保持（无 0.58 deb 在盘，见报告「未配平项」）
#   0.59 = /usr/bin/phoc 自编件（暂存于 /usr/bin/phoc.custom-0.59rc1-20261113, 6125964…）
#          + phosh 三包 0.59~rc1-1 + portal 0.59~rc1-1
#
# 只改文件与包版本，**不重启会话**（桌面组件是下次会话才换）；divert / hold 保持不动。
# 用法（设备上，root）： sh /tmp/deskstack.sh 0.58 | 0.59 | --check
set -eu
BIN=/usr/bin/phoc
DIST=$BIN.dpkg-dist           # 发行版 0.59 原件 e561c4f5（divert 在位时包里的件落这里）
P058=$BIN.syncobj-20261111    # 自编 0.58.0-syncobj
P059=$BIN.custom-0.59rc1-20261113  # 自编 0.59~rc1（2026-11-13 22:59 上机件）
ARCH=/var/cache/apt/archives
D58=""
DEBS_58="/tmp/debs58"
say() { printf '%s\n' "$*"; }
die() { printf '!! %s\n' "$*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || die "需要 root"

state() {
    say "== 现状"
    say "  $BIN              $(sha256sum "$BIN" | cut -c1-16) $(stat -c%s "$BIN")B $(stat -c%y "$BIN" | cut -d. -f1)"
    for f in "$DIST" "$P058" "$P059"; do
        [ -e "$f" ] && say "  $f  $(sha256sum "$f" | cut -c1-16) $(stat -c%s "$f")B"
    done
    say "  divert: $(dpkg-divert --list | grep -c elden-phoc-override) ; hold: $(apt-mark showhold | grep -cx phoc || true)"
    dpkg-query -W -f='  ${Package} ${Version}\n' phoc phosh libphosh-0.45-0 phosh-common xdg-desktop-portal-phosh phosh-osk-stevia 2>/dev/null
}

to_058() {
    dpkg-divert --list | grep -q elden-phoc-override || die "divert 不在位，先跑 phoc-install.sh"
    [ -f "$P058" ] || die "缺 $P058"
    # 发行版 0.59 原件必须在 .dpkg-dist（若 .dpkg-dist 现在是我们自编 0.59，先从 apt 缓存恢复）
    if grep -q linux_drm_syncobj "$DIST" 2>/dev/null; then
        say "== .dpkg-dist 是自编件 ⇒ 从 apt 缓存恢复发行版原件"
        tmp=$(mktemp -d); dpkg-deb -x "$ARCH/phoc_0.59~rc1-1_arm64.deb" "$tmp"
        cp -a "$tmp/usr/bin/phoc" "$DIST.new" && mv -f "$DIST.new" "$DIST"; rm -rf "$tmp"
    fi
    say "== phoc -> 自编 0.58.0-syncobj"
    install -m 0755 -o root -g root "$P058" "$BIN.new" && mv -f "$BIN.new" "$BIN"
    say "== portal -> 0.58.0-1（断网/无 apt 源，纯本地 deb）"
    dpkg -i --force-downgrade "$ARCH/xdg-desktop-portal-phosh_0.58.0-1_arm64.deb" >/dev/null || \
      apt-get install -y --allow-downgrades --no-download "$ARCH/xdg-desktop-portal-phosh_0.58.0-1_arm64.deb"
    say "== phosh 三包 -> 0.58.0-1"
    dpkg -i --force-downgrade "$DEBS_58"/phosh_0.58.0-1_arm64.deb "$DEBS_58"/phosh-common_0.58.0-1_all.deb "$DEBS_58"/libphosh-0.45-0_0.58.0-1_arm64.deb >/dev/null
    state
}

to_059() {
    dpkg-divert --list | grep -q elden-phoc-override || die "divert 不在位"
    [ -f "$P059" ] || die "缺 $P059（自编 0.59 暂存件）"
    say "== phoc -> 自编 0.59~rc1"
    install -m 0755 -o root -g root "$P059" "$BIN.new" && mv -f "$BIN.new" "$BIN"
    say "== portal -> 0.59~rc1-1"
    dpkg -i "$ARCH/xdg-desktop-portal-phosh_0.59~rc1-1_arm64.deb" >/dev/null
    say "== phosh 三包 -> 0.59~rc1-1"
    dpkg -i "$ARCH"/phosh_0.59~rc1-1_arm64.deb "$ARCH"/phosh-common_0.59~rc1-1_all.deb "$ARCH"/libphosh-0.45-0_0.59~rc1-1_arm64.deb >/dev/null
    state
}

case "${1:-}" in
    0.58) to_058 ;;
    0.59) to_059 ;;
    --check|"") state ;;
    *) die "用法: $0 0.58 | 0.59 | --check" ;;
esac
