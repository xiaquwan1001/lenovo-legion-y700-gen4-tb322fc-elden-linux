#!/bin/sh
# Live scale change for DSI-1 via wlr-randr (no phoc restart needed).
# Usage: scale.sh <value>   e.g. scale.sh 2.5
# Persist the chosen value into /etc/phosh/phoc.ini afterwards.
V="${1:?usage: scale.sh <value>}"
export XDG_RUNTIME_DIR=/run/phosh
wlr-randr --output DSI-1 --scale "$V" && \
	echo "live scale -> $V (remember to persist in /etc/phosh/phoc.ini)"
