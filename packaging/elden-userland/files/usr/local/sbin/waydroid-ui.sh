#!/bin/sh
export XDG_RUNTIME_DIR=/run/phosh
export WAYLAND_DISPLAY=wayland-0
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
exec waydroid show-full-ui
