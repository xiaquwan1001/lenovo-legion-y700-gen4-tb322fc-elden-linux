#!/bin/sh
# Live scale change for DSI-1 via wlr-randr (no phoc restart needed).
# Usage: scale.sh <value>   e.g. scale.sh 2
# Persist the chosen value into /etc/phosh/phoc.ini afterwards.
#
# ⚠️ 2026-09-30: phoc 只对**整数** scale 精确上报（2.0/4.0 精确）。小数会被量化成像素网格值
#   （2.5→忽略；2.667→2.66796875；3.2→3.19921875），与 Mutter.DisplayConfig 对外宣称的
#   supported_scales（float32 值）**不相等** → g-c-c「比例」匹配失败显示 100%。
#   所以建议用整数 scale；phoc.ini 里写非支持列表内的值（如 2.5）会被整个忽略、回退默认 3.199。
V="${1:?usage: scale.sh <value>}"
export XDG_RUNTIME_DIR=/run/phosh
export WAYLAND_DISPLAY=wayland-0
wlr-randr --output DSI-1 --scale "$V" && \
	echo "live scale -> $V (remember to persist in /etc/phosh/phoc.ini)"
