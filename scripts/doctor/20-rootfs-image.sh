#!/bin/bash
# 20-rootfs-image.sh — §20 磁盘根镜像「起得来 / 登得入」写前门（委托 scripts/rootfs-image-check.py）
# 立此节的原因（2026-11-19，PITFALLS #680）：2026-11-18 的 minbase 镜像**没有 /init**、
#   /usr/local/sbin 空，却照样过了 build 侧 GATE_MIN（那里只查 /sbin/init）⇒ 上机症状是
#   「只有背光、USB 完全不枚举」，与「内核坏了」无法区分。判据必须落在**镜像**上。
# 本节三件事：① 检查器自检（内置坏件必须被抓，防它空转）
#             ② 仓内已知坏件（11-18 的 p2-minbase 镜像）**必须 FAIL**（反作弊：坏件还在盘上却报通过 = 门失效）
#             ③ 仓内已知好件（11-19 修后镜像）必须 PASS（含 /init 与真源同字节）
. "$(dirname "$0")/_lib.sh"

section '20. 磁盘根镜像门（/init 与网络登入件：坏件必拒 / 好件必过）'
CHK="$HELPERS/rootfs-image-check.py"
if [ ! -f "$CHK" ]; then
  bad "scripts/rootfs-image-check.py 缺失"
else
  if _st=$(timeout 120 python3 "$CHK" --selftest 2>&1); then
    ok "检查器自检通过（$(printf '%s' "$_st" | tail -1 | sed 's/^SELFTEST OK//;s/^（//;s/）$//')）"
  else
    bad "检查器自检失败：$(printf '%s' "$_st" | grep 'SELFTEST FAIL' | head -2 | tr '\n' ' ')"
  fi

  # 已知坏件：out/p2-minbase-20261118/rootfs-minbase-20261118.ext4.img（缺 /init + usb-gadget）
  BAD="$ROOT/out/p2-minbase-20261118/rootfs-minbase-20261118.ext4.img"
  GOOD=$(ls -1 "$ROOT"/out/min-restore-*/rootfs-minbase-gadget-*.ext4.img 2>/dev/null | tail -1)

  if [ -f "$BAD" ]; then
    if _b=$(timeout 180 python3 "$CHK" "$BAD" --profile net 2>&1); then
      bad "已知坏件（11-18 minbase，缺 /init）竟判通过 ⇒ 门失效"
    else
      _n=$(printf '%s' "$_b" | grep -c '\[FAIL\]')
      ok "已知坏件被拒（$(basename "$BAD")）：FAIL=$_n（含 /init 缺失）"
    fi
  else
    ok "仓内无已知坏件 fixture（跳过反作弊实跑）"
  fi

  # 已知好件是**冻结的历史快照**（2026-11-19 镜像），它的 /init 只能跟「当时的真源」比：
  # 夹具旁边就存着注入原件 init.inject（= 34584 B）。若拿**活的** initramfs/init 当 expect，
  # 真源每改一次（例如 2026-11-27 修 respawn ttyGS0 双读者）这条门就红一次，而镜像本身并没有坏
  # ⇒ 判据要绑在「镜像 vs 注入原件」上；真源与注入原件之间的漂移单独报 WARN（附两侧 md5/size，
  # 让人知道「该更新夹具了」而不是「镜像坏了」）。
  PIN=$(dirname "$GOOD")/init.inject
  if [ -f "$PIN" ]; then
    _pi=$(md5sum "$PIN" 2>/dev/null | cut -d' ' -f1)
    _ri=$(md5sum "$ROOT/initramfs/init" 2>/dev/null | cut -d' ' -f1)
    if [ "$_pi" != "$_ri" ]; then
      warnf "夹具 /init 与真源已漂移（夹具 $(wc -c <"$PIN") B md5 ${_pi:0:8}… vs 真源 $(wc -c <"$ROOT/initramfs/init") B md5 ${_ri:0:8}…）⇒ 夹具是历史快照，属预期；要重新采样就重建 fixture 并替换 init.inject"
    fi
  else
    PIN="$ROOT/initramfs/init"
    warnf "夹具旁无 init.inject，退回与活真源比（真源一改这条门就会红）"
  fi
  if [ -n "$GOOD" ] && [ -f "$GOOD" ]; then
    if _g=$(timeout 180 python3 "$CHK" "$GOOD" --profile net \
             --expect-init "$PIN" --strict-init 2>&1); then
      # 只有真跑到「/init 同源」那一条才算这节有牙齿（stub 检查器会让它消失）
      if printf '%s' "$_g" | grep -q '/init == '; then
        ok "已知好件通过（$(basename "$GOOD")：$(printf '%s' "$_g" | grep -c '\[ok\]') 项 ok，/init 与真源同字节）"
      else
        bad "好件判通过但没有出现「/init 同源」行 ⇒ 检查器没真跑（门空转）"
      fi
    else
      bad "已知好件不通过：$(printf '%s' "$_g" | grep '\[FAIL\]' | head -2 | tr '\n' ' ')"
    fi
  else
    ok "仓内无已知好件 fixture（跳过实跑）"
  fi
fi
