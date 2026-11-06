#!/bin/bash
# 04-retired.sh — §4 已退场入口不得复辟（2026-10-04 清理）。
# 判据来源：archive/2026-10-04-retired-entrypoints/；机器层快捷入口从 ~/.local/bin 退场。
. "$(dirname "$0")/_lib.sh"

section '4. 已退场入口（2026-10-04 清理，见 archive/2026-10-04-retired-entrypoints/）'
for p in .pi/pi-messenger.json .pi/messenger \
         scripts/swarm.sh scripts/swarm-monitor.sh scripts/y700-swarm-reset.sh \
         scripts/y700-harness-restart.sh scripts/start-y700-harness.sh scripts/apply-swarm-patch.sh \
         patches/pi-messenger-swarm-detach-spawn.patch patches/pi-messenger-swarm-spawn.js.patched; do
  if [ -e "$p" ]; then bad "已退场资产又出现在活跃树: $p"; else ok "无 $p"; fi
done
for f in flashing eacndev lob-remake; do
  [ -e "$HOME/.local/bin/$f" ] && warnf "机器层快捷入口复辟: ~/.local/bin/$f（现役 = cd ~/y700-elden && pi）" || ok "无 ~/.local/bin/$f"
done
