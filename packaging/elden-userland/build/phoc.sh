#!/bin/bash
# phoc.sh — 重建「带我们两枚补丁的 phoc」并（可选）装到设备上钉住
#
# 背景（PITFALLS #653/#654）：
#   * 设备在版的 phoc 必须同时有 ① `wp_linux_drm_syncobj_manager_v1` 广告（C12 droidloom L2 门槛）
#     ② OSK 版本门去掉（G1-38 点输入框弹键盘）。两者都是我们打的补丁，上游没有。
#   * phoc 是 **Debian 包**提供的二进制 ⇒ 装上去必须 `dpkg-divert` + `apt-mark hold` 钉住，
#     否则 `apt install/upgrade phoc` 会静默换回上游件（2026-11-13 实测，功能消失而进程/桌面全正常）。
#
# 口径：本配方**不产出** MANIFEST.tsv 里的 `elf` 行（phoc 是 dpkg 的包，不是我们的自编件），
#   覆盖登记在 `overrides.tsv`；产物落 `out/phoc-syncobj-arm64-<日期>/`。
#
# 用法：
#   bash packaging/elden-userland/build/phoc.sh --dry-run                  # 只打印
#   sudo env VER=0.59~rc1 DEBVER=0.59~rc1-1 WRAPMODE=nodownload \
#        bash packaging/elden-userland/build/phoc.sh --apply               # 真编
#     （可选）--install 目的：编完把产物 scp 到设备并用 scripts/phoc-install.sh 钉住
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"
REPO=$(repo_root)

# 版本口径：设备在版是 Debian sid 的 0.59~rc1（2026-11-13 实测 dpkg -l phoc = 0.59~rc1-1）
VER=${VER:-0.59~rc1}
DEBVER=${DEBVER:-0.59~rc1-1}
WRAPMODE=${WRAPMODE:-nodownload}
BUILD=$REPO/scripts/build-phoc-arm64.sh
INSTALL=$REPO/scripts/phoc-install.sh
SOURCES="patches/phoc-syncobj-20261111/ patches/phoc-osk-versiongate-20261111/"

need_file "$BUILD" || exit 1
need_file "$INSTALL" || exit 1
for d in $SOURCES; do need_file "$REPO/$d" || exit 1; done

note "phoc $VER；构建脚本 $BUILD"
note "补丁源: $SOURCES"
note "产物: $REPO/out/phoc-syncobj-arm64-<日期>/phoc-${VER}-syncobj-osk"
note "上机钉住: $INSTALL --install <产物>（dpkg-divert + apt-mark hold，见 PITFALLS #654）"

# 产物命名与 build-phoc-arm64.sh 的 OUTTAG 逻辑一致：有额外补丁 ⇒ syncobj-osk
TAG=syncobj-osk

run env VER="$VER" DEBVER="$DEBVER" WRAPMODE="$WRAPMODE" bash "$BUILD"

if [ "$DRY_RUN" = 0 ]; then
	OUT=$(ls -d "$REPO"/out/phoc-syncobj-arm64-* 2>/dev/null | tail -1)
	if [ -n "$OUT" ] && [ -f "$OUT/phoc-${VER}-${TAG}" ]; then
		printf '[run] sha256sum %s\n' "$OUT/phoc-${VER}-${TAG}"
		sha256sum "$OUT/phoc-${VER}-${TAG}"
		printf '[note] 上机后按 scripts/phoc-install.sh --check 复核 divert/hold 是否在位\n' >&2
	else
		printf 'WARN: 未找到产物 %s/phoc-%s-%s\n' "${OUT:-<无 out 目录>}" "$VER" "$TAG" >&2
	fi
fi

finish phoc
