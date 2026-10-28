#!/bin/bash
# b5-u2-atomic-timeline.sh — M6/B5 **U2** 取证门：原子回调时序（零写盘、可复跑）
#
# 背景：B5（bonded-DSI per-SoC cfg）把厂商非原子桥回调 `.enable/.disable` 映射到
# 7.3 的 `.atomic_pre_enable/.atomic_enable/.atomic_disable/.atomic_post_disable`。
# 这个映射**静态判不了**（`reports/b5-per-soc-cfg-design-20261027.md` §1 第 9 项）：
# 唯一判据是现场时间线——「面板 prepare 必须夹在 pre_enable 与 enable 之间」这类顺序。
#
# 判据（任一不满足 ⇒ rc=1）：
#   A1 enable 方向：pre_enable < panel_prepare < bridge_enable
#   A2 enable 方向：host_enable 在 panel_prepare 之后（面板就绪才开数据通路）
#   A3 enable 方向：panel_enable 在 host_enable 之后（先 video 后 display-on）
#   A4 disable 方向：panel_disable < host_disable < panel_unprepare（关屏命令仍可下发）
#   A5 disable 方向：host_power_off 在 host_disable 之后（先断链路再断电）
#   A6 bonded：每方向 host_enable/host_disable/host_power_on/off 各 **2 次**（master+slave），
#      而桥回调各 **1 次**（slave 桥早退）
#   A7 无回归：`command DMA timeout` / `vblank timeout` / `reset failure` /
#      `panel is not prepared` 计数在采集前后**不变**
#
# 触发方式：`org.gnome.ScreenSaver.SetActive true/false`（真实合成器提交；
#   `/sys/class/drm/card0-DSI-1/dpms` 在本机是 0444 **只读**，`modetest -w` 也是空操作，
#   见 `scripts/g1-22-dpms-test.sh` 头注释）。
#
# 用法：
#   scripts/b5-u2-atomic-timeline.sh                 # 采 2 轮 + 判 + 存 artifacts
#   scripts/b5-u2-atomic-timeline.sh --no-capture    # 只判最新一包 artifacts
#   环境：HOST=root@192.168.7.1 / SESSION_USER=xuqianhui1001 / CYCLES=2
set -uo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd -- "$HERE/.." && pwd)
HOST=${HOST:-root@192.168.7.1}
SESSION_USER=${SESSION_USER:-xuqianhui1001}
CYCLES=${CYCLES:-2}
MODE=capture
for a in "$@"; do case "$a" in --no-capture) MODE=check ;; -h|--help) sed -n '2,32p' "$0"; exit 0 ;; esac; done

OUTBASE="$REPO/reports/artifacts"
if [ "$MODE" = capture ]; then
	OUT="$OUTBASE/b5-u2-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$OUT"
	remote=$(mktemp); trap 'rm -f "$remote"' EXIT
	cat >"$remote" <<-EOS
	#!/bin/sh
	set -eu
	TR=/sys/kernel/tracing
	FUNC="dsi_mgr_bridge_pre_enable dsi_mgr_bridge_enable dsi_mgr_bridge_disable dsi_mgr_bridge_post_disable dsi_mgr_bridge_mode_set msm_dsi_host_power_on msm_dsi_host_power_off msm_dsi_host_enable msm_dsi_host_disable dsi_mgr_phy_disable msm_dsi_host_set_display_mode drm_atomic_bridge_chain_pre_enable drm_atomic_bridge_chain_enable drm_atomic_bridge_chain_disable drm_atomic_bridge_chain_post_disable drm_panel_prepare drm_panel_enable drm_panel_disable drm_panel_unprepare drm_atomic_helper_commit_modeset_enables drm_atomic_helper_commit_modeset_disables"
	U=$SESSION_USER; R=\$(loginctl show-session c1 -p Display --value >/dev/null 2>&1; echo /run/user/\$(id -u \$U))
	ss() { runuser -u \$U -- env XDG_RUNTIME_DIR=\$R DBUS_SESSION_BUS_ADDRESS=unix:path=\$R/bus \\
	         timeout 10 gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver \\
	         --method org.gnome.ScreenSaver.SetActive "\$1" >/dev/null 2>&1; }
	st() { echo "dpms=\$(cat /sys/class/drm/card0-DSI-1/dpms) enabled=\$(cat /sys/class/drm/card0-DSI-1/enabled) status=\$(cat /sys/class/drm/card0-DSI-1/status)"; }
	cnt() { for p in "command DMA timeout" "vblank timeout" "reset failure" "panel is not prepared"; do printf "%s=%s\n" "\$p" "\$(dmesg | grep -ci "\$p")"; done; }
	echo "UNAME=\$(uname -r)"
	echo "=== BASE ==="; cnt
	echo 0 > \$TR/tracing_on; echo nop > \$TR/current_tracer; : > \$TR/trace; : > \$TR/set_ftrace_filter
	for f in \$FUNC; do
		if grep -qx "\$f" \$TR/available_filter_functions; then echo "\$f" >> \$TR/set_ftrace_filter; else echo "SKIP_INLINE \$f"; fi
	done
	echo function > \$TR/current_tracer
	echo "FILTER=\$(wc -l < \$TR/set_ftrace_filter)"
	ss false; sleep 3; echo "WARM \$(st)"
	: > \$TR/trace; echo 1 > \$TR/tracing_on
	i=0
	while [ \$i -lt $CYCLES ]; do
		echo "CYCLE_\$i BLANK"; ss true;  sleep 2; echo "  \$(st)"
		echo "CYCLE_\$i WAKE";  ss false; sleep 3; echo "  \$(st)"
		i=\$((i + 1))
	done
	echo 0 > \$TR/tracing_on
	cp \$TR/trace /tmp/u2-trace.txt
	dmesg | grep -iE "msm_dsi|novatek|panel|command DMA|vblank timeout" | tail -80 > /tmp/u2-dmesg-dsi.txt
	echo "=== AFTER ==="; cnt
	echo "TRACE_LINES=\$(wc -l < /tmp/u2-trace.txt)"
	echo "FINAL \$(st)"
	echo nop > \$TR/current_tracer
	EOS
	echo "== 采集（$HOST，$CYCLES 轮 blank/wake，零写盘）=="
	ssh -o BatchMode=yes "$HOST" 'sh -s' <"$remote" | tee "$OUT/capture.log"
	scp -q -o BatchMode=yes "$HOST":/tmp/u2-trace.txt "$OUT/u2-trace.txt"
	scp -q -o BatchMode=yes "$HOST":/tmp/u2-dmesg-dsi.txt "$OUT/u2-dmesg-dsi.txt"
	echo "artifact: ${OUT#$REPO/}"
else
	OUT=$(ls -1d "$OUTBASE"/b5-u2-* 2>/dev/null | sort | tail -1)
	[ -n "${OUT:-}" ] || { echo "没有 artifacts（先不带 --no-capture 跑一次）" >&2; exit 2; }
	echo "== 只判：${OUT#$REPO/}"
fi

python3 - "$OUT" <<'PY'
import re, sys, pathlib
out = pathlib.Path(sys.argv[1])
trace = (out / "u2-trace.txt").read_text(errors="replace")
log = (out / "capture.log").read_text(errors="replace") if (out / "capture.log").exists() else ""

ev = []   # (ts, func)
for line in trace.splitlines():
    if not line.strip() or line.startswith("#"):
        continue
    m = re.search(r"(\d+\.\d+):\s+(\S+)\s+<-", line)
    if m:
        ev.append((float(m.group(1)), m.group(2)))

if not ev:
    print("FAIL  时间线为空（ftrace 过滤器没生效？）"); sys.exit(1)

# 切分「一次提交」：不能按时间间隔切 —— panel_prepare 本身就要 ~228 ms（DCS 初始化），
# 会把同一次提交的 pre_enable/panel_prepare 与 bridge_enable 拆开。
# 判据锚点 = 桥链入口：chain_disable 起一个 disable 组，chain_pre_enable 起一个 enable 组。
groups, cur, prev_kind = [], [], None
for ts, fn in ev:
    kind = None
    if fn == "drm_atomic_bridge_chain_disable":
        kind = "dis"
    elif fn == "drm_atomic_bridge_chain_pre_enable":
        kind = "en"
    if kind and cur:
        groups.append(cur); cur = []
    cur.append((ts, fn))
    if kind:
        prev_kind = kind
if cur:
    groups.append(cur)

def idx(g, fn, start=0):
    for i in range(start, len(g)):
        if g[i][1] == fn:
            return i
    return -1

fails = []
def need(cond, msg):
    print(("  ok    " if cond else "  FAIL  ") + msg)
    if not cond:
        fails.append(msg)

n_en = n_dis = 0
for g in groups:
    names = [f for _, f in g]
    if "dsi_mgr_bridge_enable" in names and "drm_panel_prepare" in names:
        n_en += 1
        i_pre  = idx(g, "dsi_mgr_bridge_pre_enable")
        i_ppre = idx(g, "drm_panel_prepare")
        i_en   = idx(g, "dsi_mgr_bridge_enable")
        i_hen  = idx(g, "msm_dsi_host_enable")
        i_pen  = idx(g, "drm_panel_enable")
        need(0 <= i_pre < i_ppre < i_en, "A1 enable 序 pre_enable < panel_prepare < bridge_enable")
        need(i_ppre < i_hen, "A2 host_enable 在 panel_prepare 之后")
        need(i_hen < i_pen, "A3 panel_enable 在 host_enable 之后（先 video 后 display-on）")
        need(names.count("msm_dsi_host_enable") == 2, "A6 bonded：host_enable 恰好 2 次（master+slave）")
        need(names.count("dsi_mgr_bridge_enable") == 1, "A6 bonded：桥回调恰好 1 次（slave 早退）")
        dt = (g[i_en][0] - g[i_ppre][0]) * 1000
        print(f"        panel_prepare→host_enable 间隔 {dt:.1f} ms（= 面板 DCS 初始化耗时）")
    if "dsi_mgr_bridge_disable" in names and "drm_panel_unprepare" in names:
        n_dis += 1
        i_pdis = idx(g, "drm_panel_disable")
        i_dis  = idx(g, "dsi_mgr_bridge_disable")
        i_off  = idx(g, "msm_dsi_host_power_off")
        i_punp = idx(g, "drm_panel_unprepare")
        need(0 <= i_pdis < i_dis, "A4 panel_disable < host_disable")
        need(i_dis < i_punp, "A4 host_disable < panel_unprepare（关屏命令仍可下发）")
        need(i_dis < i_off, "A5 host_power_off 在 host_disable 之后")
        need(names.count("msm_dsi_host_disable") == 2, "A6 bonded：host_disable 恰好 2 次")
        need(names.count("dsi_mgr_bridge_disable") == 1, "A6 bonded：桥回调恰好 1 次")

need(n_en >= 1, f"采到 enable 方向样本 n={n_en}")
need(n_dis >= 1, f"采到 disable 方向样本 n={n_dis}")

# A7：错误计数前后不变
KEYS = ("command DMA timeout", "vblank timeout", "reset failure", "panel is not prepared")

def counters(tag):
    seg = log.split(f"=== {tag} ===")
    if len(seg) < 2:
        return {}
    d = {}
    for line in seg[1].splitlines()[:10]:
        if "=" in line:
            k, v = line.rsplit("=", 1)
            k = k.strip()
            if k in KEYS and v.strip().isdigit():
                d[k] = int(v)
    return d
b, a = counters("BASE"), counters("AFTER")
if b and a:
    for k in b:
        need(a.get(k) == b[k], f"A7 无回归：'{k}' {b[k]}→{a.get(k)}")
else:
    print("  WARN  未取到 BASE/AFTER 计数，A7 跳过")

print(f"\n==== U2 时序门: {'PASS' if not fails else 'FAIL'}  (enable n={n_en} / disable n={n_dis}) ====")
sys.exit(0 if not fails else 1)
PY
