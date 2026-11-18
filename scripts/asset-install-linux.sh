#!/usr/bin/env bash
# asset-install-linux.sh — 把 assets/android-20261119/ 里的原厂安卓资产装到 Linux 桌面
#
# 用法:
#   scripts/asset-install-linux.sh --check           只读：校验 sha256 + 打印安装计划（无需 root）
#   scripts/asset-install-linux.sh --apply           安装精选壁纸 + 全部音效（需 root）
#   scripts/asset-install-linux.sh --apply --all     额外装 ZUI 壁纸商店大图 + AOD 背景（+201 MB）
#   scripts/asset-install-linux.sh --apply --fonts   额外装 ZUI 字体到 /usr/local/share/fonts/elden
#   scripts/asset-install-linux.sh --revert          按状态表精确卸载（需 root）
#
# 环境变量（测试/自定义落点；不设则 /usr/share）:
#   ELDEN_PREFIX=/tmp/x   ELDEN_ASSETS_ROOT=<assets 树>
#
# 设计要点
#   · 壁纸落 /usr/share/backgrounds/elden/；gsettings 命令由脚本打印，**不代跑**
#     （gsettings 是 per-user，sudo 下会写 root 的 dconf，反而无效）。
#   · 音效落 /usr/share/sounds/elden/，并按 freedesktop/liblycanberra 标准事件名
#     symlink 进 /usr/share/sounds/freedesktop/stereo/（已存在真实文件则备份为 *.elden-bak）。
#   · bootanimation.zip **不安装**，只作 Plymouth 主题参考（见报告）。
#   · 状态表 <prefix>/lib/elden-assets/installed.tsv 记录每个落地项 ⇒ --revert 可精确回滚。
set -euo pipefail

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ASSETS=${ELDEN_ASSETS_ROOT:-$SELF_DIR/assets/android-20261119}
PREFIX=${ELDEN_PREFIX:-/usr/share}
MANIFEST=$ASSETS/meta/MANIFEST.tsv
STATE_DIR=$PREFIX/lib/elden-assets
STATE=$STATE_DIR/installed.tsv

BG_DIR=$PREFIX/backgrounds/elden
SND_DIR=$PREFIX/sounds/elden
FD_DIR=$PREFIX/sounds/freedesktop/stereo
FONT_DIR=${ELDEN_FONT_DIR:-/usr/local/share/fonts/elden}

MODE=; ALL=0; FONTS=0
for a in "$@"; do
  case $a in
    --check) MODE=check ;;
    --apply) MODE=apply ;;
    --revert) MODE=revert ;;
    --all) ALL=1 ;;
    --fonts) FONTS=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done
[ -n "$MODE" ] || { echo "need --check | --apply | --revert" >&2; exit 2; }

say() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

need_root() {
  if [ "$(id -u)" -ne 0 ] && [ "$PREFIX" = "/usr/share" ]; then
    die "--apply/--revert 需 root（写 $PREFIX）。用 sudo 跑本脚本，或设 ELDEN_PREFIX 到可写目录做演练。"
  fi
}

# 精选壁纸 = /system/media/wallpapers 的人像/横屏/默认 + 锁屏壁纸
default_wallpapers() {
  cat <<'EOF'
wallpapers/wallpaper_port
wallpapers/wallpaper_land
wallpapers/default_wallpaper.png
wallpapers/wallpapers_pandaer_default.jpg
wallpapers/lockscreen/wallpaper
EOF
}
extra_wallpapers() {  # --all: ZUI 商店大图 + AOD/锁屏时钟背景
  find "$ASSETS/wallpapers/zui-wallpaper-setting" "$ASSETS/lockscreen/standby-mode" -type f | sort |
    sed "s#^$ASSETS/##"
}

dest_name() {  # 源相对路径 → 落地文件名（缺扩展名时按 mime 补）
  local rel=$1 base mime ext
  base=$(basename "$rel")
  case $base in *.*) echo "$base"; return ;; esac
  mime=$(awk -F'\t' -v f="$rel" '$1==f{print $4}' "$MANIFEST")
  case $mime in
    image/png) ext=.png ;; image/jpeg) ext=.jpg ;; audio/ogg) ext=.ogg ;;
    application/zip) ext=.zip ;; *) ext= ;;
  esac
  echo "$base$ext"
}

# Android 音效 → liblycanberra/freedesktop 标准事件名
sound_map() {
  cat <<'EOF'
sounds/ui/ChargingStarted.ogg	power-plug.oga	keep
sounds/ui/ChargingStarted_Quick.ogg	power-plug-quick.oga	new
sounds/ui/Undock.ogg	power-unplug.oga	keep
sounds/ui/LowBattery.ogg	battery-caution.oga	new
sounds/ui/LowBattery_Low.ogg	battery-low.oga	new
sounds/ui/Effect_Tick.ogg	button-pressed.oga	new
sounds/ui/Camera_click.ogg	camera-shutter.oga	keep
sounds/ui/VideoRecord.ogg	screen-capture.oga	keep
sounds/ui/Dock.ogg	device-added.oga	keep
sounds/alarms/Awoken.ogg	alarm-clock-elapsed.oga	keep
sounds/notifications/Bloom.ogg	complete.oga	keep
sounds/notifications/Di.ogg	message-new-instant.oga	keep
sounds/notifications/Bright.ogg	bell.oga	keep
sounds/ringtones/StereoLenovoDynamic.ogg	phone-incoming-call.oga	keep
sounds/ui/KeypressStandard.ogg	button-toggle-on.oga	new
EOF
}

verify_manifest() {
  [ -f "$MANIFEST" ] || die "缺 $MANIFEST（先跑 scripts/android-assets-extract-20261119.py）"
  local n=0 bad=0 f s h
  while IFS=$'\t' read -r f s h rest; do
    [ "$f" = file ] && continue
    n=$((n+1))
    if [ ! -f "$ASSETS/$f" ]; then warn "缺文件 $f"; bad=$((bad+1)); continue; fi
    if [ "$(stat -c %s "$ASSETS/$f")" != "$s" ]; then warn "尺寸不符 $f"; bad=$((bad+1)); fi
    if [ "$(sha256sum "$ASSETS/$f" | cut -d' ' -f1)" != "$h" ]; then warn "sha256 不符 $f"; bad=$((bad+1)); fi
  done < "$MANIFEST"
  say "manifest: $n 行实测 sha256, 不符 $bad"
  [ "$bad" -eq 0 ] || die "资产树校验失败"
}

plan_lines() {
  local rel
  for rel in $(default_wallpapers); do
    [ -f "$ASSETS/$rel" ] || { warn "精选壁纸缺 $rel"; continue; }
    echo "F	$BG_DIR/elden-$(dest_name "$rel")	$rel"
  done
  if [ "$ALL" = 1 ]; then
    for rel in $(extra_wallpapers); do
      echo "F	$BG_DIR/elden-$(dest_name "$rel")	$rel"
    done
  fi
  for rel in $(cd "$ASSETS" && find sounds -type f | sort); do
    echo "F	$SND_DIR/${rel#sounds/}	$rel"
  done
  local src name kind
  while IFS=$'\t' read -r src name kind; do
    case $kind in new|keep) ;; *) continue ;; esac
    [ -f "$ASSETS/$src" ] || { warn "缺音效 $src"; continue; }
    echo "L	$FD_DIR/$name	$SND_DIR/${src#sounds/}"
  done <<< "$(sound_map)"
  if [ "$FONTS" = 1 ]; then
    for rel in $(cd "$ASSETS" && find fonts -type f | sort); do
      echo "F	$FONT_DIR/${rel#fonts/}	$rel"
    done
  fi
}

show_gsettings() {
  local p=$BG_DIR/elden-$(dest_name wallpapers/wallpaper_port)
  say ""
  say "== 桌面/锁屏壁纸（用户本人跑，不带 sudo）=="
  say "gsettings set org.gnome.desktop.background picture-uri      'file://$p'"
  say "gsettings set org.gnome.desktop.background picture-uri-dark 'file://$p'"
  say "gsettings set org.gnome.desktop.background picture-options  'zoom'"
  say "# Phosh 锁屏没有独立壁纸键（sm.puri.phosh.lockscreen 仅 require-unlock/shuffle-keypad），"
  say "# 锁屏背景跟随 org.gnome.desktop.screensaver.picture-uri；给出显式设置以便锁屏也用同一张："
  say "gsettings set org.gnome.desktop.screensaver picture-uri 'file://$p'"
  say "# 想换横屏图: 把上面的 file://... 换成 $BG_DIR/elden-$(dest_name wallpapers/wallpaper_land)"
  say "gsettings set org.gnome.desktop.sound theme-name freedesktop   # 键名是 theme-name；音效才会走 freedesktop 事件名"
  say "gsettings get org.gnome.desktop.sound theme-name               # 现查"
}

do_check() {
  say "== assets 树: $ASSETS"
  du -sh "$ASSETS" 2>/dev/null || true
  verify_manifest
  say ""
  say "== 目标: PREFIX=$PREFIX（$( [ -w "$PREFIX" ] && echo 可写 || echo 不可写/不存在 )）"
  plan_lines > /tmp/elden-plan.$$ || true
  local nf nl
  nf=$(grep -c '^F' /tmp/elden-plan.$$ || true); nl=$(grep -c '^L' /tmp/elden-plan.$$ || true)
  say "计划: 复制 $nf 个文件, 建立 $nl 个标准名 symlink; bootanimation 4 个 zip 不安装（Plymouth 参考）"
  say ""
  say "== 落地清单（F=copy, L=symlink）"
  sed 's/^/  /' /tmp/elden-plan.$$
  say ""
  say "== 工具/键位核查"
  for c in gsettings fc-cache sha256sum; do
    printf '  %-10s %s\n' "$c" "$(command -v "$c" || echo '缺失')"
  done
  SCHEMAS=$(gsettings list-schemas 2>/dev/null || true)
  for s in org.gnome.desktop.background org.gnome.desktop.screensaver org.gnome.desktop.sound sm.puri.phosh.lockscreen; do
    # 注意：不要写 `gsettings list-schemas | grep -q`——grep -q 提前退出会 SIGPIPE 掉 gsettings，
    # set -o pipefail 下整条管道判失败（实测偶发误报「无」）。
    if grep -qx "$s" <<< "$SCHEMAS"; then say "  schema $s: 有"; else say "  schema $s: 无（该桌面不适用）"; fi
  done
  say "  锁屏键: sm.puri.phosh.lockscreen = $(gsettings list-keys sm.puri.phosh.lockscreen 2>/dev/null | tr '\n' ' ')（无壁纸键 ⇒ 锁屏随桌面/ screensaver 键）"
  show_gsettings
  rm -f /tmp/elden-plan.$$
}

do_apply() {
  need_root
  do_check >/tmp/elden-check.out 2>&1 || { cat /tmp/elden-check.out; exit 1; }
  grep -q '不符 0' /tmp/elden-check.out || die "资产校验未通过，见 /tmp/elden-check.out"
  mkdir -p "$BG_DIR" "$SND_DIR" "$STATE_DIR" "$(dirname "$FD_DIR")"
  : > "$STATE.tmp"
  local nf=0 nl=0
  while IFS=$'\t' read -r kind dst src; do
    [ -z "${kind:-}" ] && continue
    case $kind in
      F)
        mkdir -p "$(dirname "$dst")"
        if [ -e "$dst" ] && ! grep -qsF "F	$dst	" "$STATE" 2>/dev/null; then
          mv "$dst" "$dst.elden-bak"; echo "B	$dst.elden-bak	$dst" >> "$STATE.tmp"
          say "  备份已存在文件: $dst → $dst.elden-bak"
        fi
        cp -f "$ASSETS/$src" "$dst"; echo "F	$dst	$src" >> "$STATE.tmp"; nf=$((nf+1)) ;;
      L)
        mkdir -p "$(dirname "$dst")"
        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
          mv "$dst" "$dst.elden-bak"; echo "B	$dst.elden-bak	$dst" >> "$STATE.tmp"
          say "  备份发行版同名音: $dst → $dst.elden-bak"
        fi
        ln -sfn "$src" "$dst"; echo "L	$dst	$src" >> "$STATE.tmp"; nl=$((nl+1)) ;;
    esac
  done < <(plan_lines)
  # 与旧状态合并（重复 apply 不重复记）
  if [ -f "$STATE" ]; then cat "$STATE" >> "$STATE.tmp"; fi
  sort -u "$STATE.tmp" -o "$STATE"; rm -f "$STATE.tmp"
  if [ "$FONTS" = 1 ] && command -v fc-cache >/dev/null; then
    say "  fc-cache -f $FONT_DIR"; fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
  fi
  say ""
  say "APPLIED: 复制 $nf 文件, $nl symlink; 状态表 $STATE"
  say "未安装: bootanimation/*.zip（Plymouth 参考，见 reports/android-assets-20261119.md）"
  show_gsettings
}

do_revert() {
  need_root
  [ -f "$STATE" ] || { say "无状态表 $STATE，无需回滚"; return 0; }
  local kind dst src n=0
  # 两趟：先删我们装的 F/L，再恢复 B 备份（同一路径既有 L 又有 B 时顺序错会把自己的备份删掉）
  while IFS=$'\t' read -r kind dst src; do
    case $kind in
      F|L) [ -e "$dst" ] || [ -L "$dst" ] && { rm -f "$dst"; n=$((n+1)); } ;;
    esac || true
  done < "$STATE"
  while IFS=$'\t' read -r kind dst src; do
    case $kind in
      B) if [ -e "$dst" ]; then mv -f "$dst" "$src"; say "  恢复发行版原件: $src"; n=$((n+1)); fi ;;
    esac || true
  done < "$STATE"
  rm -f "$STATE"
  for d in "$BG_DIR" "$SND_DIR" "$FONT_DIR" "$STATE_DIR"; do
    [ -d "$d" ] && find "$d" -depth -type d -empty -delete 2>/dev/null || true
  done
  say "REVERTED: 处理 $n 项"
  say "如需回到发行版壁纸/音效主题:"
  say "  gsettings reset org.gnome.desktop.background picture-uri"
  say "  gsettings reset org.gnome.desktop.screensaver picture-uri"
  say "  gsettings reset org.gnome.desktop.sound theme-name"
}

case $MODE in
  check) do_check ;;
  apply) do_apply ;;
  revert) do_revert ;;
esac
