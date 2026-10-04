#!/bin/bash
# bt-link-test.sh — BR/EDR 数据链路只读诊断（y700-elden / WCN7861 Brahma v2）
#
# 目的：在不改内核、不刷机的前提下，把「l2ping 高延迟 + 突发掉包」拆成可对比的数字。
#
# 用法（设备上以 root 运行，或经 SSH）：
#   ssh root@192.168.7.1 'sh -s' < scripts/bt-link-test.sh
#   PEER=AA:BB:CC:DD:EE:FF COUNT=30 scripts/bt-link-test.sh
#   PEER=... RUN_BTMON=0 scripts/bt-link-test.sh          # 跳过 btmon 采集
#   PEER=... IBS_TX_IDLE=600000 scripts/bt-link-test.sh  # 临时试「主机不睡」(仅本次运行，退出恢复)
#
# 设计约束：
#   * 只读为主：默认不写任何内核参数；唯一的写是可选 IBS_TX_IDLE（退出时恢复原值）。
#   * 全部外部命令带 timeout，脚本总时长有上限（见 MAX_TOTAL）。
#   * 不留下后台进程：btmon 用 timeout 包裹；退出 trap 兜底 pkill 自己起的 btmon。
#   * 可重复运行得到可对比数字（幂等：只在 hci0 down 时才 up）。
#
# 输出：末尾一张 TAB 分隔的数字表 + 结论行（H3 判定）。
#
# 依赖：hciconfig / hcitool / l2ping / btmon（bluez-utils）、debugfs 挂载点
#       /sys/kernel/debug/bluetooth/hci0/（内核 debugfs，已有）

set -u

PEER="${PEER:-}"
COUNT="${COUNT:-20}"
INTERVAL="${INTERVAL:-0.2}"
SIZE="${SIZE:-44}"
RUN_BTMON="${RUN_BTMON:-1}"
BTMON_SECS="${BTMON_SECS:-8}"
KEEPALIVE="${KEEPALIVE:-0}"   # 1 = 跑 l2ping 期间每 50ms 发一条无害 HCI 命令，测「控制器深睡」假设
MAX_TOTAL="${MAX_TOTAL:-60}"
IBS_TX_IDLE="${IBS_TX_IDLE:-}"      # 空 = 不动；数字 = 临时改并在退出时恢复
IBS_DIR="/sys/kernel/debug/bluetooth/hci0"

TMPD="$(mktemp -d /tmp/bt-link-test.XXXXXX)" || exit 1
BTMON_PID=""
KEEPALIVE_PID=""
IBS_TX_IDLE_SAVED=""

cleanup() {
    [ -n "$BTMON_PID" ] && kill "$BTMON_PID" 2>/dev/null
    # 兜底：只杀本次运行的 btmon（TMPD 唯一），绝不碰别人的进程
    if [ -n "$BTMON_PID" ]; then
        pkill -P "$$" btmon 2>/dev/null
    fi
    [ -n "$KEEPALIVE_PID" ] && kill "$KEEPALIVE_PID" 2>/dev/null
    pkill -P "$$" hcitool 2>/dev/null
    if [ -n "$IBS_TX_IDLE_SAVED" ] && [ -w "$IBS_DIR/tx_idle_delay" ]; then
        printf '%s' "$IBS_TX_IDLE_SAVED" > "$IBS_DIR/tx_idle_delay" 2>/dev/null
    fi
    logger -t bt-link-test "done" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# 整个脚本的硬截止：到点给自身 SIGTERM，触发 cleanup
( sleep "$MAX_TOTAL"; kill -TERM "$$" 2>/dev/null ) &
WATCHDOG=$!
trap 'cleanup; kill '"$WATCHDOG"' 2>/dev/null; exit 0' EXIT INT TERM

say() { printf '%s\n' "$*" >&2; }
hr()  { say "------------------------------------------------------------"; }

need() { command -v "$1" >/dev/null 2>&1; }

# ---------- 前置检查 ----------
hr; say "bt-link-test @ $(hostname)  $(date -Is)"
[ -d "$IBS_DIR" ] || say "WARN: $IBS_DIR 不存在（IBS 计数器将为空）"
need hciconfig || { say "FATAL: 无 hciconfig（bluez-utils）"; exit 2; }
hciconfig hci0 >/dev/null 2>&1 || { say "FATAL: 无 hci0"; exit 2; }

# ---------- 记录前态 ----------
hciconfig hci0 > "$TMPD/hci_before.txt" 2>&1
say "hci0 前态:"; cat "$TMPD/hci_before.txt" >&2

if ! grep -q 'UP RUNNING' "$TMPD/hci_before.txt"; then
    say "hci0 未 UP，正在 up..."
    hciconfig hci0 up 2>&1 || say "WARN: hciconfig up 失败（可能仅 paging 未开）"
fi

# 临时改主机 IBS tx_idle（可选，纯诊断）
if [ -n "$IBS_TX_IDLE" ] && [ -w "$IBS_DIR/tx_idle_delay" ]; then
    IBS_TX_IDLE_SAVED="$(cat "$IBS_DIR/tx_idle_delay" 2>/dev/null)"
    printf '%s' "$IBS_TX_IDLE" > "$IBS_DIR/tx_idle_delay"
    say "临时设 tx_idle_delay=${IBS_TX_IDLE}（原值 ${IBS_TX_IDLE_SAVED}，退出恢复）"
fi

# 读取一组 IBS 计数器，输出 "k=v" 行
ibs_read() {
    if [ -d "$IBS_DIR" ]; then
        for f in "$IBS_DIR"/*; do
            [ -f "$f" ] || continue
            printf '%s=%s\n' "$(basename "$f")" "$(cat "$f" 2>/dev/null)"
        done
    fi
}

ibs_read > "$TMPD/ibs_before.txt"
say "IBS 前态:"; sed 's/^/   /' "$TMPD/ibs_before.txt" >&2

# ---------- 选择对端 ----------
if [ -z "$PEER" ]; then
    # 退而求其次：取第一个已连接/已配对设备
    PEER="$(hcitool con 2>/dev/null | awk '/ACL/{print $5; exit}')"
fi
if [ -z "$PEER" ]; then
    say ""
    say "FATAL: 未给出对端 MAC。请先配对/连接，或：PEER=AA:BB:... $0"
    say "       （当前 hcitool con:）"
    hcitool con 2>/dev/null | sed 's/^/   /' >&2
    exit 3
fi
say "对端 PEER=$PEER   COUNT=$COUNT  INTERVAL=${INTERVAL}s  SIZE=${SIZE}B"

# ---------- 只读：QCA/驱动启动日志（拿 product_id/soc_id/rom_ver）----------
# 用于判断 qca_wcn7861_uses_current_baudrate() 是否命中，进而判断
# DT / PERI 波特率改动哪个才真正生效。
dmesg 2>/dev/null | grep -iE 'qca|wcn78|bluetooth|hci0|hci_qca' | tail -30 \
    > "$TMPD/dmesg_bt.txt" 2>/dev/null || true
say "QCA 启动日志关键行:"; grep -iE 'Product ID|SoC ID|ROM|setting up|Patch|baud|wcn' \
    "$TMPD/dmesg_bt.txt" 2>/dev/null | sed 's/^/   /' >&2 || true

# ---------- 可选：控制器 keepalive（测 H4 控制器深睡）----------
if [ "$KEEPALIVE" = 1 ] && need hcitool; then
    say "KEEPALIVE=1：ping 期间每 50ms 发 Read_Local_Version(0x1001) 保持控制器不睡"
    timeout -s KILL "$(( MAX_TOTAL - 5 ))" \
        sh -c 'while :; do hcitool cmd 0x03 0x0001 >/dev/null 2>&1; sleep 0.05; done' \
        >/dev/null 2>&1 &
    KEEPALIVE_PID=$!
fi

# ---------- 可选：btmon 抓一段（timeout 包裹，绝不留后台）----------
if [ "$RUN_BTMON" = 1 ] && need btmon; then
    say "btmon 采集 ${BTMON_SECS}s -> $TMPD/btmon.snoop"
    timeout -s TERM "$BTMON_SECS" btmon -w "$TMPD/btmon.snoop" >/dev/null 2>&1 &
    BTMON_PID=$!
else
    say "跳过 btmon（RUN_BTMON=$RUN_BTMON / 无 btmon）"
fi

# ---------- l2ping（主证据）----------
say ""
say ">>> l2ping -c $COUNT -i $INTERVAL -s $SIZE $PEER"
L2OUT="$TMPD/l2ping.txt"
timeout -s KILL $(( COUNT * 2 + 15 )) \
    l2ping -c "$COUNT" -i "$INTERVAL" -s "$SIZE" "$PEER" > "$L2OUT" 2>&1
L2RC=$?
cat "$L2OUT" >&2

# ---------- 收尾：等 btmon 自然结束 ----------
if [ -n "$BTMON_PID" ]; then
    wait "$BTMON_PID" 2>/dev/null
    BTMON_PID=""
fi
if [ -n "$KEEPALIVE_PID" ]; then
    kill "$KEEPALIVE_PID" 2>/dev/null
    KEEPALIVE_PID=""
fi

# ---------- 记录后态 ----------
hciconfig hci0 > "$TMPD/hci_after.txt" 2>&1
ibs_read > "$TMPD/ibs_after.txt"

# ---------- 解析 ----------
# hciconfig 统计
hci_get() { sed -n "s/.*$1:\([0-9]*\).*/\1/p" "$TMPD/hci_after.txt" | head -1; }
RX_BYTES="$(hci_get 'RX bytes')";  TX_BYTES="$(hci_get 'TX bytes')"
RX_ERR="$(hci_get 'RX errors')";   TX_ERR="$(hci_get 'TX errors')"

# l2ping 汇总：X sent, Y received, Z% loss, time Wms / rtt min/avg/max/mdev
LOSS="$(sed -n 's/.*, \([0-9]*%\) loss.*/\1/p' "$L2OUT" | head -1)"
RTT="$(sed -n 's/.*rtt \([0-9./]*\) ms.*/\1/p' "$L2OUT" | head -1)"
N_SENT="$(sed -n 's/^\([0-9]*\) sent.*/\1/p' "$L2OUT" | head -1)"
N_RECV="$(sed -n 's/.*sent, \([0-9]*\) received.*/\1/p' "$L2OUT" | head -1)"

ibs_val() { sed -n "s/^$1=//p" "$TMPD/$2" | head -1; }
ibs_delta() {
    local a b; a="$(ibs_val "$1" ibs_before.txt)"; b="$(ibs_val "$1" ibs_after.txt)"
    if [ -n "$a" ] && [ -n "$b" ]; then echo $(( b - a )); else echo "n/a"; fi
}

# ---------- 数字表 ----------
hr
printf 'METRIC\tVALUE\n'
printf 'peer\t%s\n'            "$PEER"
printf 'l2ping_sent\t%s\n'     "${N_SENT:-?}"
printf 'l2ping_recv\t%s\n'     "${N_RECV:-?}"
printf 'l2ping_loss\t%s\n'     "${LOSS:-?}"
printf 'l2ping_rtt_minavgmaxmdev\t%s\n' "${RTT:-?}"
printf 'l2ping_rc\t%s\n'       "$L2RC"
printf 'hci_rx_errors\t%s\n'   "${RX_ERR:-?}"
printf 'hci_tx_errors\t%s\n'   "${TX_ERR:-?}"
printf 'hci_rx_bytes\t%s\n'    "${RX_BYTES:-?}"
printf 'hci_tx_bytes\t%s\n'    "${TX_BYTES:-?}"
printf 'ibs_recv_wakes_delta\t%s\n'  "$(ibs_delta ibs_recv_wakes)"
printf 'ibs_sent_wakes_delta\t%s\n'  "$(ibs_delta ibs_sent_wakes)"
printf 'ibs_recv_slps_delta\t%s\n'   "$(ibs_delta ibs_recv_slps)"
printf 'ibs_sent_slps_delta\t%s\n'   "$(ibs_delta ibs_sent_slps)"
printf 'ibs_recv_wacks_delta\t%s\n'  "$(ibs_delta ibs_recv_wacks)"
printf 'ibs_sent_wacks_delta\t%s\n'  "$(ibs_delta ibs_sent_wacks)"
printf 'ibs_wake_retrans_setting\t%s\n' "$(ibs_val wake_retrans ibs_after.txt)"
printf 'ibs_tx_idle_delay_setting\t%s\n' "$(ibs_val tx_idle_delay ibs_after.txt)"
printf 'ibs_tx_ibs_state_after\t%s\n'   "$(ibs_val tx_ibs_state ibs_after.txt)"
printf 'ibs_rx_ibs_state_after\t%s\n'   "$(ibs_val rx_ibs_state ibs_after.txt)"
# 仅当应用了 candidate-bt-ibs-wait-stats.patch 时才有
printf 'tx_wait_cnt_delta\t%s\n'      "$(ibs_delta tx_wait_cnt)"
printf 'tx_wait_ms\t%s\n'             "$(ibs_val tx_wait_ms ibs_after.txt)"
printf 'keepalive\t%s\n'              "$KEEPALIVE"
printf 'btmon_file\t%s\n'             "$( [ -s "$TMPD/btmon.snoop" ] && echo "$TMPD/btmon.snoop" || echo none )"
hr

# ---------- 结论提示（不代替人判）----------
say ""
say "解读提示："
say "  * RTT 中位 <10ms  = 链路健康；>30ms 即本轮要修的症状。"
say "  * ibs_sent_wakes_delta ≈ 0 且 tx_wait_cnt_delta ≈ 0 → IBS 唤醒握手不是瓶颈（H3 否）。"
say "  * ibs_sent_wakes_delta > 0 且 RTT 随 wake_retrans/us 变化 → 唤醒握手是瓶颈（H3 是）。"
say "  * ibs_recv_wakes_delta 远大于 N_RECV（每包数次）→ 控制器侧频繁唤醒，看 btmon 的时间轴。"
say "  * l2ping_loss 高但 hci_rx/tx_errors = 0 → 丢在空口/控制器，不是主机 UART。"
say "  * 同一链路分别跑 KEEPALIVE=0 / KEEPALIVE=1：若 1 的 RTT 塌回 <10ms，"
say "    则控制器自身深睡（H4）成立，且需要一个「保持活跃」的缓解手段。"
say ""
say "原始件保留在 $TMPD/ （btmon.snoop / l2ping.txt / hci_*.txt / ibs_*.txt）"
exit 0
