#!/usr/bin/env bash
# q28-verdict.sh <LOG> [SINCE_MARKER] — 从串口日志判定一次启动 Q28 GOOD/BAD。
# 判据同时看三层，避免旧只 grep command DMA 的漏判：
#   L1: 'Failed to initialize panel' / 'command DMA timeout' / 'bonded command DMA failed'
#   L2: 'ctl [0-9]+ reset failure' / 'frame done timeout' / 'vblank wait timed out'
# 默认看整文件；给 SINCE_MARKER（该串在 LOG 中最后一次出现之后的内容）只看某轮。
set -u
LOG="${1:?need log}"
MARKER="${2:-}"
SEG="$LOG"
if [ -n "$MARKER" ]; then
  ln=$(grep -nF "$MARKER" "$LOG" | tail -1 | cut -d: -f1)
  if [ -n "$ln" ]; then SEG=$(mktemp); tail -n +"$ln" "$LOG" > "$SEG"; fi
fi
c(){ grep -cE "$1" "$SEG"; }
dma=$(c 'command DMA timeout|bonded command DMA failed')
initfail=$(c 'Failed to initialize panel')
ctlreset=$(c 'ctl [0-9]+ reset failure')
framedone=$(c 'frame done timeout')
vblank=$(c 'vblank wait timed out')
boot=$(c 'Linux version')
echo "boot_banner=$boot  commandDMA=$dma  initFail=$initfail  ctlReset=$ctlreset  frameDone=$framedone  vblankTimeout=$vblank"
total=$((dma+initfail+ctlreset+framedone+vblank))
if [ "$boot" -eq 0 ]; then echo "VERDICT=NOBOOT (没抓到内核 banner)";
elif [ "$total" -eq 0 ]; then echo "VERDICT=GOOD";
else echo "VERDICT=BAD (display bring-up failed)"; fi
[ "$SEG" != "$LOG" ] && rm -f "$SEG"
