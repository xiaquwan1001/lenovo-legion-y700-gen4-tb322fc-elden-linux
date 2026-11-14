#!/bin/sh
# phosh-install.sh — 把自编 phosh 装到设备并**钉住**，防 apt 覆盖（同 PITFALLS #654 的 phoc 做法）
#
# 背景：我们给 phosh 0.58.0 打了一枚补丁（patches-userland/upstream/phosh-power-mode-fallback.patch）：
#   zwlr_output_power_v1 握手失败时把 power_mode 设为 ON 并 notify，否则
#   PhoshScreenSaverManager 的 active 恒 TRUE ⇒ 电源键短按/空闲熄屏全失效。
#   包名同为 `phosh`，只 `install -m0755 /usr/libexec/phosh` 会被下次 apt upgrade 静默冲刷
#   （2026-11-13 已在 phoc 上实测过一次，见 PITFALLS #654）。
#
# 两层防护（都要，缺一不可）：
#   1. `dpkg-divert --divert /usr/libexec/phosh.dpkg-dist`：包的件落到 .dpkg-dist。
#      **这是根本**（`--reinstall` 也覆盖不了）。
#   2. `apt-mark hold phosh`：防版本升级换掉 .dpkg-dist。
#
# 用法：
#   sh phosh-install.sh --check                     # 只体检现状
#   sh phosh-install.sh --install <本地phosh文件>    # 装 + 钉住（幂等）
#   sh phosh-install.sh --uninstall                 # 撤掉钉住、恢复发行版件
#
# 只在设备上跑（需要 root）。
set -eu
BIN=/usr/libexec/phosh
DIST=$BIN.dpkg-dist
DIVERT_PKG=elden-phosh-override
PATCH_MARK="failed"   # 占位：真实判据是 "power_mode" 字符串组合，见下面 check()
say() { printf '%s\n' "$*"; }
die() { printf '!! %s\n' "$*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || die "需要 root"

# 我们的件与发行版件的判据：把 "Failed to set output power mode" 附近的逻辑
# 编译产物里不好直接 grep；改用「二进制里同时出现 power-mode 通知路径特征串」不可靠，
# 因此用**文件大小 + 已知 sha**双判据（脚本 --install 时会写下 sha）。
MARK=/usr/local/share/elden-phosh-build.txt

check() {
    say "== 现状"
    if [ -e "$BIN" ]; then
        say "    $BIN  = $(sha256sum "$BIN" | cut -d' ' -f1 | cut -c1-16)  ($(stat -c%s "$BIN") B)"
    else
        say "    $BIN  不存在"
    fi
    [ -e "$DIST" ] && say "    $DIST = $(sha256sum "$DIST" | cut -d' ' -f1 | cut -c1-16)  ($(stat -c%s "$DIST") B)"
    if dpkg-divert --list 2>/dev/null | grep -q "$DIVERT_PKG"; then
        say "    divert: 已在位"
    else
        say "    divert: *** 缺失 *** ⇒ apt reinstall 会覆盖我们的件"
    fi
    if apt-mark showhold 2>/dev/null | grep -qx phosh; then
        say "    hold:   已在位"
    else
        say "    hold:   *** 缺失 ***"
    fi
    [ -f "$MARK" ] && say "    登记: $(cat "$MARK")"
}

install_one() {
    src=$1
    [ -f "$src" ] || die "找不到 $src"
    if ! dpkg-divert --list 2>/dev/null | grep -q "$DIVERT_PKG"; then
        say "== 建立 divert"
        dpkg-divert --package "$DIVERT_PKG" --divert "$DIST" --rename "$BIN" || true
    fi
    say "== 安装自编 phosh"
    install -m 0755 -o root -g root "$src" "$BIN.new" && mv -f "$BIN.new" "$BIN"
    say "== 钉住"
    apt-mark hold phosh >/dev/null
    mkdir -p "$(dirname "$MARK")"
    printf '%s  %s\n' "$(sha256sum "$BIN" | cut -d' ' -f1)" "$(basename "$src")" > "$MARK"
    check
    say ""
    say "生效需要重开桌面会话：systemctl restart greetd（会关掉所有 app）"
}

uninstall_one() {
    if dpkg-divert --list 2>/dev/null | grep -q "$DIVERT_PKG"; then
        dpkg-divert --package "$DIVERT_PKG" --divert "$DIST" --rename --remove "$BIN" || true
    fi
    apt-mark unhold phosh >/dev/null 2>&1 || true
    rm -f "$MARK"
    say "已撤销 divert/hold（发行版件在 $DIST，必要时手工 install 回 $BIN）"
}

case "${1:-}" in
    --install) shift; install_one "${1:?需要文件路径}" ;;
    --uninstall) uninstall_one ;;
    --check|"") check ;;
    *) die "用法: $0 --check | --install <file> | --uninstall" ;;
esac
