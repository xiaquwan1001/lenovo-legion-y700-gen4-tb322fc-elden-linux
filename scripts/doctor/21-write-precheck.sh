#!/bin/bash
# 21-write-precheck.sh — §21 写前预检两道门（委托 scripts/gpt-preflight.py / dump-verdict.py）
# 立此节的原因（2026-11-19，LTBox 评估 P0-5/P0-6）：
#   P0-5 写之前要**重读** GPT 并与快照逐条比对（start/span/size），主备两表必须一致、重名必须拒 ——
#        我们原来的等价物是 linux-gpt-apply.sh 里一段**内联 python**，不可离线自检、没有 CRC/跨度判定；
#   P0-6 dump 失败只认「分区不存在」这一个签名，超时/USB stall/静默失败都是"存在性未知"，
#        而我们存量脚本里还有 `qdl read … || true` 之后按"文件空"推断空分区的写法。
# 本节四件事：① 两个检查器自检（合成坏件必须被抓）
#             ② 仓内真实 GPT 表件实跑（官方 259 包 LUN0/LUN4 主备对 + 设备 LUN0 对）
#             ③ 快照复验跨来源实跑（官方 LUN0 快照 vs 设备 LUN0 现表：几何必须逐条一致）
#             ④ 反作弊：现场造坏件（挪一个 start 字节）必须被拒；同一坏件喂给「恒 0 的 stub」
#                必须"通过" ⇒ 说明 ④ 的负例由真判据决定，不是环境噪声。
. "$(dirname "$0")/_lib.sh"

section '21. 写前预检（GPT 快照复验 P0-5 / dump 三值判定 P0-6）'
GP="$HELPERS/gpt-preflight.py"
DV="$HELPERS/dump-verdict.py"

if [ ! -f "$GP" ]; then
  bad "scripts/gpt-preflight.py 缺失"
else
  if _st=$(timeout 120 python3 "$GP" --selftest 2>&1); then
    ok "GPT 预检自检通过（$(printf '%s' "$_st" | tail -1 | sed 's/^== //')）"
  else
    bad "GPT 预检自检失败：$(printf '%s' "$_st" | grep 'SELFTEST FAIL' | head -2 | tr '\n' ' ')"
  fi
fi

if [ ! -f "$DV" ]; then
  bad "scripts/dump-verdict.py 缺失"
elif _st=$(timeout 120 python3 "$DV" --selftest 2>&1); then
  ok "dump 判定自检通过（$(printf '%s' "$_st" | tail -1 | sed 's/^== //')）"
else
  bad "dump 判定自检失败：$(printf '%s' "$_st" | grep 'SELFTEST FAIL' | head -2 | tr '\n' ' ')"
fi

PKG="$ROOT/backup/official-rom-15.10.259"
if [ -f "$GP" ] && [ -f "$PKG/gpt_main0.bin" ] && [ -f "$PKG/gpt_backup0.bin" ]; then
  for lun in 0 4; do
    if [ -f "$PKG/gpt_main$lun.bin" ] && [ -f "$PKG/gpt_backup$lun.bin" ]; then
      if _c=$(timeout 120 python3 "$GP" check --main "$PKG/gpt_main$lun.bin" \
                 --backup "$PKG/gpt_backup$lun.bin" 2>&1); then
        ok "官方包 LUN$lun 主备表自洽（$(printf '%s' "$_c" | grep -o '[0-9]\+ 分区' | head -1)）"
      else
        bad "官方包 LUN$lun 主备表不自洽：$(printf '%s' "$_c" | grep 'FAIL ' | head -1)"
      fi
    fi
  done

  DEV_MAIN="$ROOT/backup/gpt/gpt_main0_device.bin"
  DEV_BKP="$ROOT/backup/gpt/gpt_backup0_device.bin"
  TMP=$(mktemp -d "${TMPDIR:-/tmp}/wrprecheck.XXXXXX")
  SNAP="$TMP/lun0.json"
  if timeout 120 python3 "$GP" snapshot --main "$PKG/gpt_main0.bin" \
       --backup "$PKG/gpt_backup0.bin" -o "$SNAP" >/dev/null 2>&1; then
    if [ -f "$DEV_MAIN" ]; then
      if timeout 120 python3 "$GP" verify --expect "$SNAP" --main "$DEV_MAIN" \
           --backup "$DEV_BKP" >/dev/null 2>&1; then
        ok "写前复验跨来源一致（官方 259 快照 vs 设备 LUN0 现表：几何/字节数/guid 逐条相同）"
      else
        bad "官方快照与设备现表不一致（要么设备被改过，要么表读错了）"
      fi
    else
      ok "仓内无设备 LUN0 表件 fixture（跳过跨来源复验）"
    fi

    # ④ 现场坏件：把官方主表第一个分区的 start_sector 挪 1（其余字节与 CRC 都不动）
    python3 - "$PKG/gpt_main0.bin" "$TMP/bad-main0.bin" <<'PY'
import sys
b = bytearray(open(sys.argv[1], "rb").read())
b[8192 + 32] = (b[8192 + 32] + 1) & 0xFF
open(sys.argv[2], "wb").write(b)
PY
    if timeout 60 python3 "$GP" verify --expect "$SNAP" --main "$TMP/bad-main0.bin" \
         >/dev/null 2>&1; then
      bad "现场坏件（start 挪 1 扇区）竟判通过 ⇒ 写前复验门失效"
    else
      _moved=$(timeout 60 python3 "$GP" verify --expect "$SNAP" --main "$TMP/bad-main0.bin" 2>&1 \
               | grep -c 'MOVED ')
      ok "现场坏件被拒（MOVED=$_moved 条 + 条目 CRC 不符）"
    fi

    # 反作弊：恒返回 0 的 stub 检查器喂同一个坏件必须「通过」，否则负例不是靠检查器能力区分的
    printf 'import sys\nsys.exit(0)\n' >"$TMP/stub.py"
    if python3 "$TMP/stub.py" verify --expect "$SNAP" --main "$TMP/bad-main0.bin" >/dev/null 2>&1; then
      ok "反作弊：stub(恒 0) 在坏件上判通过 ⇒ 上面的负例由真判据决定（不是环境噪声）"
    else
      bad "反作弊失效：负例在 stub 上也失败 ⇒ 该负例区分不出检查器是否真在工作"
    fi
  else
    bad "官方 LUN0 快照落不下来（表件损坏或工具坏了）"
  fi
  rm -rf "$TMP"
else
  ok "仓内无官方包 GPT fixture（跳过实跑，自检已覆盖）"
fi

# ⑤ dump 三值判定的真实语义抽查（合成日志，不连设备）：传输故障绝不能落到 absent
if [ -f "$DV" ]; then
  TMPL=$(mktemp "${TMPDIR:-/tmp}/dvlog.XXXXXX")
  printf 'ERR: LIBUSB_ERROR_TIMEOUT during firehose read\n' >"$TMPL"
  _v=$(timeout 30 python3 "$DV" --part boot_b --rc 1 --log "$TMPL" 2>&1)
  case "$_v" in
    "VERDICT error"*) ok "传输故障未被当作「分区不存在」（$(printf '%s' "$_v" | cut -d' ' -f2)）" ;;
    *) bad "传输故障被判成 $(printf '%s' "$_v" | cut -d' ' -f2)（P0-6 的核心错法）" ;;
  esac
  printf 'ERROR: PartitionNotFound: vbmeta_system_a\n' >"$TMPL"
  if timeout 30 python3 "$DV" --part vbmeta_system_a --rc 1 --log "$TMPL" >/dev/null 2>&1; then
    bad "PartitionNotFound 竟判 present"
  else
    _rc=$?
    [ "$_rc" -eq 10 ] && ok "仅 PartitionNotFound 判 absent（rc=10）" \
      || bad "PartitionNotFound 应判 absent(rc=10)，实际 rc=$_rc"
  fi
  rm -f "$TMPL"
fi
