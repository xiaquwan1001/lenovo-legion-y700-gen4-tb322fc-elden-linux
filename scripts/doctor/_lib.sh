# _lib.sh — check-doctor 子门的公共外壳（被 scripts/doctor/*.sh source）。
#
# 契约（2026-11-05 脚本审计定的调度协议）：
#   * 每个子门是一个可独立执行的文件（scripts/doctor/NN-*.sh|py），从 stdin 不读任何东西，
#     只往 stdout 打印「与旧版 check-doctor 逐字相同」的行：
#         `  [ok]   消息` / `  [FAIL] 消息` / `  [warn] 消息`（缩进两格，方括号大写）
#     以及自己的 `== N. 标题 ==` 段头。
#   * 退出码不参与判定（判据只看行）：这样同一个子门在「并行调度」与「单独手跑」下语义一致，
#     也不会因为 set -e 的一处意外退出把整段判据变成静默跳过。
#   * ROOT  = 被检查的仓库根（由 check-doctor 传入，缺省 = 本文件上两级）
#   * HELPERS = 仓库 scripts/ 目录（可被 ELF_HELPERS 覆盖，用于 A/B 跑暂存副本）
set -uo pipefail

: "${ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
: "${HELPERS:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export ROOT HELPERS
cd "$ROOT" || exit 2

ok()    { printf '  [ok]   %s\n' "$1"; }
bad()   { printf '  [FAIL] %s\n' "$1"; }
warnf() { printf '  [warn] %s\n' "$1"; }
section() { printf '\n== %s ==\n' "$1"; }
