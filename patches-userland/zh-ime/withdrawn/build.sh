#!/bin/sh
# 构建 zh-ime 用户态组件（在设备上跑；依赖 wayland-client / gio / glib / cairo / pango / xkbcommon）
set -e
cd "$(dirname "$0")"

# 生成缺失的 wayland 协议绑定（一次性；产物已入库，重新生成需 wayland-scanner）
gen() {
    xml=$1; out=$2
    [ -f "$out" ] && return 0
    [ -f "$xml" ] || { echo "missing $xml" >&2; return 1; }
    wayland-scanner client-header "$xml" "${out%-protocol.c}-client.h"
    wayland-scanner private-code  "$xml" "$out"
}

gen input-method-unstable-v2.xml im-v2-protocol.c
gen layer-shell.xml              layer-shell-protocol.c
gen xdg-shell.xml                xdg-shell-protocol.c
gen virtual-keyboard-unstable-v1.xml vk-protocol.c

CC=${CC:-gcc}
CFLAGS="-O2 -Wall"
WAYLAND_CFLAGS=$(pkg-config --cflags wayland-client)
WAYLAND_LIBS=$(pkg-config --libs wayland-client)

# 候选条
$CC $CFLAGS -o candidate-bar candidate-bar.c layer-shell-protocol.c xdg-shell-protocol.c vk-protocol.c \
  $WAYLAND_CFLAGS $(pkg-config --cflags gio-2.0 glib-2.0 cairo pangocairo xkbcommon) \
  $WAYLAND_LIBS $(pkg-config --libs gio-2.0 glib-2.0 cairo pangocairo xkbcommon) -lm

# 唤起/折叠控制面
$CC $CFLAGS -o osk-ime osk-ime.c im-v2-protocol.c \
  $WAYLAND_CFLAGS $(pkg-config --cflags gio-2.0 glib-2.0) \
  $WAYLAND_LIBS $(pkg-config --libs gio-2.0 glib-2.0)

echo "built: $(pwd)/candidate-bar $(pwd)/osk-ime"
