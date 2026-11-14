#!/bin/sh
# recent-sessions.sh — 开工前核实「最近 N 轮会话进度 vs 文档」的一步入口。
#
# 为什么需要它（2026-11-14 M1）：项目文档曾多次与会话实测结论不一致（文档写 A、会话已实测为 B），
# 每轮靠人肉考古才发现 ⇒ 硬规则里要求开工先核实最近 2–3 轮。手工做这件事要：
#   ① 从 .pi/sessions/*.jsonl 里翻最后一条 assistant 收尾汇报；
#   ② 再看各角度 sessions/ 下最新的几篇（★SSOT 待并入字段）。
# 本脚本把这两步合成一条命令，输出**只给结论与指针**，不复述正文。
#
# 用法：
#   scripts/recent-sessions.sh            # 默认最近 3 轮
#   scripts/recent-sessions.sh 5          # 最近 5 轮
#   scripts/recent-sessions.sh --files    # 只看最近会话文件（不解析 jsonl）
#
# 判读纪律（.pi/AGENT-OPS.md §0 + INDEX.md §2）：与文档不一致时，以**这里有实测证据**的那条为准，
# 并同一提交内把文档改成一致；不要留两套说法。
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
n=3
files_only=0
for a in "$@"; do
  case "$a" in
    --files) files_only=1 ;;
    ''|*[!0-9]*) echo "recent-sessions.sh: 未知参数 $a（用 --files 或一个数字）" >&2; exit 2 ;;
    *) n=$a ;;
  esac
done

echo "== 最近 $n 轮 pi 会话（结论摘要；正文 = .pi/sessions/*.jsonl）=="
if [ "$files_only" -eq 0 ] && command -v python3 >/dev/null 2>&1; then
  ELDEN_ROOT="$root" ELDEN_N="$n" python3 - <<'PY'
import glob, json, os
root, n = os.environ['ELDEN_ROOT'], int(os.environ['ELDEN_N'])
paths = sorted(glob.glob(os.path.join(root, '.pi/sessions/*.jsonl')), key=os.path.getmtime)[-n:]
if not paths:
    print('  （无 .pi/sessions/*.jsonl：新克隆或会话未落在项目目录）')
for p in paths:
    msgs = []
    with open(p, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                m = json.loads(line)
            except ValueError:
                continue                      # 截断行/非 JSON 行忽略，不影响其余
            r = m.get('message') or m
            if r.get('role') != 'assistant':
                continue
            c = r.get('content')
            if isinstance(c, list):
                txt = '\n'.join(b.get('text', '') for b in c if isinstance(b, dict) and b.get('type') == 'text')
            elif isinstance(c, str):
                txt = c
            else:
                txt = ''
            if txt.strip():
                msgs.append(txt.strip())
    head = '  【%s】' % os.path.basename(p).split('_')[0]
    if not msgs:
        print(head + ' 无 assistant 文本')
        continue
    body = msgs[-1]
    lines = [l for l in body.split('\n') if l.strip()]
    keep = lines[:6] + (['  …'] if len(lines) > 12 else []) + lines[-6:] if len(lines) > 12 else lines
    print(head)
    for l in keep:
        print('   ' + l[:240])
    if len(msgs) > 1:
        print('   （该会话共 %d 条 assistant 汇报，上为最后一条；要看更早的: jq 或 /resume）' % len(msgs))
PY
fi

echo
echo "== 最近 $n 篇角度会话记录（文件头含 结论 / ★SSOT 待并入）=="
ls -t "$root"/*/sessions/*.md 2>/dev/null | head -"$n" | while read -r f; do
  echo "  ${f#"$root"/}"
  # 文件头只取「结论」与「★SSOT 待并入」两行，避免把正文倒出来
  # 文件头「结论」块（到下一个 `- **字段**` 为止，最多 8 行）——只给结论，不倒正文
  awk '/\*\*结论\*\*/{f=1} f && /^- \*\*(证据指针|★?SSOT)/{f=0} f' "$f" | head -9 | cut -c1-240 | sed 's/^/     /' || true
done

echo
echo "== 下一步（判读，不是命令）=="
echo "  1) 与本项目文档冲突处：以带实测证据的会话结论为准，同轮改文档（INDEX.md §2 时间序裁决）"
echo "  2) 改完刷新 INDEX.md §0 的「核对日期」，门 = scripts/check-doctor.sh --only 15"
