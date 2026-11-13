#!/bin/sh
# phoc-install.sh — 把自编 phoc 装到设备并**钉住**，防 apt 覆盖（PITFALLS #654）
#
# 背景：我们给 phoc 打了两枚本地补丁（syncobj 广告 + 去 OSK 版本门），
#   而 Debian 包名同为 `phoc`。**只 `install -m 0755` 到 /usr/bin/phoc 是不够的**：
#   `apt install/upgrade phoc`（以及任何触发 phoc 重装的 dist-upgrade）会把它覆盖回
#   上游件 —— 2026-11-13 实测就是这样悄悄退化的（在版 phoc 变成 dpkg 的
#   0.59~rc1 原件 e561c4f5…，C12 L2 的 syncobj 全局与 G1-38 的 OSK 补丁同时消失，
#   而 `systemctl status greetd` 一切正常、**没有任何报错**）。
#
# 两层防护（都要，缺一不可）：
#   1. `dpkg-divert --divert /usr/bin/phoc.dpkg-dist`：包的 phoc 落到 .dpkg-dist，
#      /usr/bin/phoc 永远留给我们的件。**这是根本**（`--reinstall` 也覆盖不了）。
#   2. `apt-mark hold phoc`：连版本升级都不做，防止 .dpkg-dist 被换掉后无从回退。
#
# 用法：
#   sh scripts/phoc-install.sh --check                     # 只体检现状
#   sh scripts/phoc-install.sh --install <本地phoc文件>     # 装 + 钉住（幂等）
#   sh scripts/phoc-install.sh --uninstall                 # 撤掉钉住、恢复发行版件
#
# 只在设备上跑（需要 root）。主机侧 rsync/scp 你自己来。
set -eu

BIN=/usr/bin/phoc
DIST=$BIN.dpkg-dist
DIVERT_PKG=elden-phoc-override
# 我们两枚补丁的判据（任一为 0 就说明装的是上游件，不是我们的）
say() { printf '%s\n' "$*"; }
die() { printf '!! %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "需要 root"

check() {
    say "== 现状"
    if [ -e "$BIN" ]; then
        say "    $BIN  = $(sha256sum "$BIN" | cut -d' ' -f1 | cut -c1-16)  ($(stat -c%s "$BIN") B)"
    else
        say "    $BIN  不存在"
    fi
    if [ -e "$DIST" ]; then
        say "    $DIST = $(sha256sum "$DIST" | cut -d' ' -f1 | cut -c1-16)  ($(stat -c%s "$DIST") B)"
    fi
    if dpkg-divert --list 2>/dev/null | grep -q "$DIVERT_PKG"; then
        say "    divert: 已在位"
    else
        say "    divert: *** 缺失 *** ⇒ apt reinstall 会覆盖我们的件"
    fi
    if apt-mark showhold 2>/dev/null | grep -qx phoc; then
        say "    hold:   已在位"
    else
        say "    hold:   *** 缺失 *** ⇒ 版本升级会换掉 .dpkg-dist"
    fi
    # 行为判据：我们的件广告 syncobj，上游件不广告
    if grep -q "linux_drm_syncobj" "$BIN" 2>/dev/null; then
        say "    补丁:   syncobj 串存在于二进制（= 我们的件）"
    else
        say "    补丁:   *** 无 syncobj 串 *** ⇒ 装的是上游件"
    fi
}

install_one() {
    src=$1
    [ -f "$src" ] || die "找不到 $src"
    # 1) 先建 divert（--rename 会把现有 $BIN 挪到 $DIST）
    if ! dpkg-divert --list 2>/dev/null | grep -q "$DIVERT_PKG"; then
        say "== 建立 divert"
        dpkg-divert --package "$DIVERT_PKG" --divert "$DIST" --rename "$BIN" || true
    fi
    # 2) .dpkg-dist 必须是**发行版原件**。--rename 已把旧 $BIN 挪过去，
    #    若旧 $BIN 恰好也是我们的件（重复跑本脚本），要从包缓存/备份恢复。
    if [ -e "$DIST" ] && grep -q "linux_drm_syncobj" "$DIST" 2>/dev/null; then
        say "== .dpkg-dist 里也是我们的件（重复安装）⇒ 从 apt 缓存恢复发行版原件"
        cache=$(find /var/cache/apt/archives -name 'phoc_*.deb' 2>/dev/null | head -1)
        if [ -n "$cache" ]; then
            tmp=$(mktemp -d); dpkg-deb -x "$cache" "$tmp"
            cp -a "$tmp/usr/bin/phoc" "$DIST.new" && mv -f "$DIST.new" "$DIST"
            rm -rf "$tmp"
        else
            say "   *** 无 apt 缓存，无法自动恢复 .dpkg-dist；请手工提供发行版件 ***"
        fi
    fi
    # 3) 装我们的件（.dpkg-dist 可能正在被运行中的 phoc 占用 ⇒ 不用 install 覆盖它）
    say "== 安装 $src → $BIN"
    install -m 0755 "$src" "$BIN.new" && mv -f "$BIN.new" "$BIN"
    # 4) hold
    apt-mark hold phoc >/dev/null 2>&1 || true
    check
}

uninstall_all() {
    say "== 撤 hold + divert，恢复发行版件"
    apt-mark unhold phoc >/dev/null 2>&1 || true
    if [ -e "$DIST" ]; then
        install -m 0755 "$DIST" "$BIN.new" && mv -f "$BIN.new" "$BIN"
    fi
    dpkg-divert --package "$DIVERT_PKG" --divert "$DIST" --rename --remove "$BIN" 2>/dev/null || true
    check
    say "== 记得 systemctl restart greetd 让新件生效"
}

case "${1:-}" in
    --check)     check ;;
    --install)   [ $# -ge 2 ] || die "用法: $0 --install <文件>"; install_one "$2" ;;
    --uninstall) uninstall_all ;;
    *) printf 'usage: %s --check | --install <file> | --uninstall\n' "$0" >&2; exit 2 ;;
esac
