#!/bin/bash
# ime-candidates-check.sh — 中文候选窗「可出候选」判据的只读体检（2026-11-15 立）
#
# 用途：一条命令现查「这一版设备到底满不满足出候选词的三件套」。
#      判据来源 = PITFALLS #618（GTK_IM_MODULE 遮蔽）/ #619（新 IC 取 Items/0 + 必须 CurrentUI=kimpanel）
#                / #653（focusd State==0 闸门）/ #660（fcitx5 两条启动路径 / profile 写回）
#      台账 = TASKS/sessions/2026-11-15-IME候选回归台账.md
#
# 只读：不发 D-Bus 请求、不启停 unit、不写 profile、不碰 /sys。
#       （注意：任何 `fcitx5-remote` 调用都可能 D-Bus 拉起 fcitx5 —— 本脚本一律不调它，见 #660）
#       （同样禁 `busctl --user status <name>`：对 org.kde.impanel 这类名会触发 D-Bus 激活，
#         而 .service 里 Exec 没带 --disable waylandim → 拉起第二个实例（2026-11-15 实测发生）。
#         查 owner 一律用 `busctl --user list`（走 ListNames，不激活）。）
#
# 用法：scripts/ime-candidates-check.sh [-H ssh目标] [-q]
#   默认 HOST=elden-root；-q 只打汇总行。exit 0 = 全部 PASS，1 = 有 FAIL。
set -u
HOST="${HOST:-elden-root}"
QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    -H) HOST="$2"; shift 2 ;;
    -q) QUIET=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

remote=$(cat <<'EOF'
# ★ 必须读「会话用户」的 home，不能读 root 的 $HOME：
#   2026-11-15 实测 /root/.config/fcitx5/{profile,config} 存在（#660 的第二实例曾在 root 下跑过），
#   脚本按 $HOME 读会拿到 root 的陈旧 profile（Items/0=keyboard-us、无 config）⇒ G3/G4 恒 FAIL 假阳性。
UH=$(getent passwd "${1:-1001}" 2>/dev/null | cut -d: -f6)
[ -n "${UH:-}" ] || UH=/home/xuqianhui1001
export HOME="$UH"
echo "### session-home"
echo "$HOME"
echo "### fcitx5-procs"
ps -eo comm,args | grep -E '^fcitx5' | grep -v grep
# ★ 同理：`systemctl --user` / `busctl --user` 必须落到**会话用户**的总线上。
#   以 root 身份直跑会读到 root 的 user bus（空）⇒ "unit fcitx5 非 active" 与 "org.kde.impanel 无 owner" 两条恒假。
UID_=${1:-1001}
# ★ 不能继承调用者的 XDG_RUNTIME_DIR / DBUS_SESSION_BUS_ADDRESS：ssh 以 root 登录时
#   pam_systemd 会把它们设成 root 的（/run/user/0），asuser 那条就静默连不上会话总线（本轮实测）。
UR=/run/user/$UID_
UB=unix:path=$UR/bus
asuser() { setpriv --reuid="$UID_" --regid="$UID_" --init-groups \
  env HOME="$UH" XDG_RUNTIME_DIR="$UR" WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0} \
  DBUS_SESSION_BUS_ADDRESS="$UB" "$@"; }
echo "### unit-active"
asuser systemctl --user is-active fcitx5 2>/dev/null
echo "### unit-enabled"
asuser systemctl --user is-enabled fcitx5 2>/dev/null
echo "### unit-exec"
asuser systemctl --user show -p ExecStart fcitx5 2>/dev/null
echo "### dbus-exec"
grep -h '^Exec=' /usr/share/dbus-1/services/org.fcitx.Fcitx5.service 2>/dev/null \
  || grep -h 'Exec=' /usr/share/dbus-1/services/*fcitx* 2>/dev/null
echo "### profile"
cat "$HOME/.config/fcitx5/profile" 2>/dev/null
echo "### profile-mtime"
stat -c '%y %s' "$HOME/.config/fcitx5/profile" 2>/dev/null
echo "### fcitx-config"
cat "$HOME/.config/fcitx5/config" 2>/dev/null
echo "### classicui-conf"
cat "$HOME/.config/fcitx5/conf/classicui.conf" 2>/dev/null
echo "### kimpanel-conf"
cat "$HOME/.config/fcitx5/conf/kimpanel.conf" 2>/dev/null
echo "### focusd-proc"
ps -eo comm,args | grep -E 'elden-ime-focusd' | grep -v grep
echo "### kimpanel-owner"
command -v busctl >/dev/null && asuser busctl --user --no-pager list 2>/dev/null | grep 'org\.kde\.impanel'
echo "### phosh-env"
pid=$(pgrep -x phosh | head -1)
[ -n "$pid" ] && tr '\0' '\n' < "/proc/$pid/environ" | grep -E '^(GTK|QT)_IM_MODULE=|^XMODIFIERS='
echo "### osk"
ps -eo comm,args | grep -E 'squeekboard|phosh-osk-stevia' | grep -v grep
echo "### im-module"
ls /usr/lib/*/gtk-3.0/*/immodules/im-fcitx5.so /usr/lib/*/gtk-4.0/*/immodules/libim-fcitx5.so 2>/dev/null
EOF
)

out=$(timeout 60 ssh -o BatchMode=yes -o ConnectTimeout=8 "$HOST" "$remote" 2>&1) || {
  echo "FAIL  ssh $HOST 不可达（阻塞：设备不在机/网络断）"; exit 1; }

# 取一个 section 的正文。注意：不能用 `sed -n '/^### $1$/,/^### /p' | sed '1d;$d'`——
# 当 section 是远程输出的最后一段时，范围延伸到 EOF，末尾的 `$d` 会把它的**最后一行**删掉
# （2026-11-15 实测：im-module 段被吞掉 gtk-3.0 那行 → 误报 FAIL=1）。改用 awk 精确到 EOF。
sec() { printf '%s\n' "$out" | awk -v s="### $1" '$0==s{f=1;next} /^### /{f=0} f'; }

fails=0; passes=0
chk() { # name expected actual -> PASS/FAIL
  local name="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then passes=$((passes+1)); [ $QUIET -eq 0 ] && printf 'PASS  %-46s %s\n' "$name" "$got"
  else fails=$((fails+1)); printf 'FAIL  %-46s want=%s got=%s\n' "$name" "$want" "${got:-<空>}"; fi
}

# 1. 只有一个 fcitx5 实例，且带 --disable waylandim（否则与 OSK 抢 input-method 槽位）
procs=$(sec fcitx5-procs); nproc=$(printf '%s\n' "$procs" | grep -c 'fcitx5')
chk "fcitx5 实例数(=1)" "1" "$nproc"
chk "fcitx5 启动参数含 --disable waylandim" "1" "$(printf '%s\n' "$procs" | grep -c -- '--disable waylandim')"

# 2. 两条启动路径的 flag 必须一致（#660：D-Bus 激活那条若不带 flag，会拉起第二个实例并在退出时写回 profile）
uexec=$(sec unit-exec | sed 's/.*argv\[\]=//' | head -1)
dexec=$(sec dbus-exec | sed 's/^Exec=//' | head -1)
case "$uexec" in
  *--disable*) chk "systemd ExecStart 含 --disable waylandim" "yes" "yes" ;;
  "") printf 'WARN  %-46s %s\n' "systemd unit ExecStart 取不到" "-" ;;
  *) chk "systemd ExecStart 含 --disable waylandim" "yes" "no ($uexec)" ;;
esac
case "$dexec" in
  *--disable*) chk "D-Bus 激活 Exec 也带 --disable waylandim" "yes" "yes" ;;
  "") printf 'WARN  %-46s %s\n' "找不到 D-Bus 激活文件" "-" ;;
  *) chk "D-Bus 激活 Exec 也带 --disable waylandim" "yes" "no ($dexec)" ;;
esac

# 3. profile 的 Items/0 必须是 rime（新 IC 取 Items/0，DefaultIM 改不了它，#619）
first_im=$(sec profile | awk '/^\[Groups\/0\/Items\/0\]/{f=1;next} f&&/^Name=/{print substr($0,6);exit}')
chk "profile Items/0 = rime" "rime" "$first_im"

# 4. 首选 UI 必须是 kimpanel（classicui 在 phoc 出不了窗，#619）；fcitx5 里这是 config 的 [Behavior] 段
#    实证：存在 config 且 CurrentUI=kimpanel 才算过；没有 config = 走默认 classicui = 不出窗
sel_ui=$(sec fcitx-config | awk '/^CurrentUI=/{print substr($0,11);exit}')
chk "config CurrentUI = kimpanel" "kimpanel" "$sel_ui"

# 5. focusd 活着（kimpanel owner）且自己没被 State==0 误收（#653 的闸门已上机）
chk "elden-ime-focusd 在跑" "1" "$(sec focusd-proc | grep -c 'elden-ime-focusd')"
owner=$(sec kimpanel-owner | grep -ci 'impanel')
[ "$owner" -ge 1 ] && chk "org.kde.impanel 有 owner" "yes" "yes" || printf 'WARN  %-46s %s\n' "org.kde.impanel 无 owner（kimpanel 未注册）" "(busctl list 无此名)"

# 5b. unit 状态仅供参考（/--disable waylandim 的实例常由 D-Bus 或手工拉起，unit 可以 inactive）
uact=$(sec unit-active)
[ "$uact" = active ] || printf 'WARN  %-46s %s\n' "systemd unit fcitx5 非 active" "${uact:-<空>}（进程在跑即可，但两条启动路径不一致）"

# 6. GTK_IM_MODULE 遮蔽（#618）：设成 fcitx 时 GTK 客户端走 D-Bus IM，不发 text-input-v3
shadow=$(sec phosh-env | grep -c '^GTK_IM_MODULE=fcitx')
chk "phosh 环境无 GTK_IM_MODULE=fcitx（#618 遮蔽）" "0" "$shadow"

# 7. 前置依赖件在位
chk "im-fcitx5.so（GTK3/4 IM 模块）在位" "2" "$(sec im-module | grep -c 'im-fcitx5.so')"
chk "OSK 进程在跑（stevia 或 squeekboard）" "1" "$(sec osk | grep -cE 'phosh-osk-stevia|squeekboard')"

echo "---"
echo "汇总: PASS=$passes FAIL=$fails  （判据正文 = PITFALLS #618/#619/#653/#660）"
[ $QUIET -eq 0 ] && echo "profile mtime: $(sec profile-mtime)"
[ "$fails" -eq 0 ] || exit 1
