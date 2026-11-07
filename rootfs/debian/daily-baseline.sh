#!/bin/bash
# daily-baseline.sh — 「日用基线」的**配置**部分（幂等；Linux 侧唯一实现）
#
# 分工（两张表 + 一个脚本，别混）：
#   rootfs/debian/daily-baseline.tsv  包清单（P0/P1/P2 + 理由）——构建侧并进 apt-list.txt
#   rootfs/debian/daily-baseline.sh   **本脚本**：装完包之后必须做的配置（sudo/locale/IM/zram）
#   scripts/mobian-daily-baseline.sh  主机侧驱动：解析 tsv → 设备上 apt-get → 推送并跑本脚本
#
# 本脚本**只做配置，不装包**（装包在构建 chroot 与设备侧驱动里各做一次，逻辑同源）。
# 因此在两种场合都能跑：
#   * 构建侧：`bash daily-baseline.sh --root /opt/elden/mobian-rootfs`（build-rootfs.sh §5 调用）
#   * 设备侧：直接 `bash daily-baseline.sh`（在设备上当 root 跑）
#
# 用法：
#   daily-baseline.sh [--root DIR] [--check] [--user NAME]
#     --root DIR   目标根（chroot 树）；缺省 = 当前系统
#     --check      只报告（每项 ok/MISS，末行 `结果: MISS=n`），不改任何文件
#     --user NAME  桌面用户名（缺省 xuqianhui1001）
#
# 设计原则：
#   * 每个动作先判「已经对了吗」，对了就跳过 ⇒ 可反复跑、可当巡检。
#   * 不做不可逆的事：只写 /etc 下的小文件；zram 只在**内核缺模块**时 mask（有模块就 unmask）。
#   * 无口令账户（passwd -S → NP）无法用口令走 sudo，故写 NOPASSWD；有口令账户只进 sudo 组。
set -uo pipefail

ROOT=""; CHECK=0; USER_NAME=xuqianhui1001
for a in "$@"; do case "$a" in
	--root) ROOT="$2"; shift ;;
	--root=*) ROOT="${a#--root=}" ;;
	--user) USER_NAME="$2"; shift ;;
	--user=*) USER_NAME="${a#--user=}" ;;
	--check) CHECK=1 ;;
	-h|--help) sed -n '2,30p' "$0"; exit 0 ;;
	*) echo "未知参数: $a" >&2; exit 2 ;;
esac; shift; done 2>/dev/null || true

R=${ROOT%/}
P() { printf '%s%s\n' "$R" "$1"; }
MISS=0; FIXED=0
ok()   { printf '  ok    %s\n' "$*"; }
miss() { MISS=$((MISS+1)); printf '  MISS  %s\n' "$*"; }
fix()  { FIXED=$((FIXED+1)); printf '  FIX   %s\n' "$*"; }
say()  { printf '%s\n' "$*"; }

[ -d "$R/etc" ] || { echo "目标根不存在: '${R:-/}'" >&2; exit 2; }

# ---------------------------------------------------------------- 1 sudo
say "[1. sudo 提权]"
if [ -x "$(P /usr/bin/sudo)" ]; then ok "sudo 已安装"; else miss "sudo 未安装（apt-list 应带；设备侧跑 apt-get install sudo）"; fi
udir=$(awk -F: -v u="$USER_NAME" '$1==u{print $6}' "$(P /etc/passwd)" 2>/dev/null)
if [ -n "$udir" ]; then
	if grep -qE "^sudo:.*(^|,)$USER_NAME(,|$)" "$(P /etc/group)" 2>/dev/null || id -nG "$USER_NAME" 2>/dev/null | tr ' ' '\n' | grep -qx sudo; then
		ok "$USER_NAME 在 sudo 组"
	else
		if [ "$CHECK" = 1 ]; then miss "$USER_NAME 不在 sudo 组"
		else
			if [ -z "$R" ]; then usermod -aG sudo "$USER_NAME" && fix "$USER_NAME 加入 sudo 组"
			else sed -i "s/^sudo:x:\([0-9]*\):/sudo:x:\1:$USER_NAME/" "$(P /etc/group)" && fix "$USER_NAME 写入 /etc/group sudo 行"; fi
		fi
	fi
	# 口令状态：NP = 无口令（greetd 自动登录账户就是这样）⇒ sudo 不能要求口令
	pw=$(awk -F: -v u="$USER_NAME" '$1==u{print $2}' "$(P /etc/shadow)" 2>/dev/null | cut -c1-3)
	S99=$(P /etc/sudoers.d/90-elden-desktop)
	if [ "${pw:-x}" = "NP" ] || [ -z "${pw:-}" ]; then
		want="$USER_NAME ALL=(ALL:ALL) NOPASSWD: ALL"
		if [ -f "$S99" ] && grep -qxF "$want" "$S99"; then ok "sudoers.d：$USER_NAME NOPASSWD 规则在位"
		elif [ "$CHECK" = 1 ]; then miss "sudoers.d 缺 NOPASSWD 规则（无口令账户 ⇒ sudo 不可用）"
		else
			mkdir -p "$(P /etc/sudoers.d)"
			{ echo "# elden 桌面用户：greetd 自动登录 + 无口令账户（passwd -S = NP）⇒ sudo 无法用口令提权"; echo "$want"; } > "$S99"
			chmod 440 "$S99"; fix "写入 /etc/sudoers.d/90-elden-desktop（NOPASSWD）"
		fi
	else
		ok "账户有口令 ⇒ 走标准 sudo 口令路径（不写 NOPASSWD）"
	fi
else
	miss "用户 $USER_NAME 不存在（先跑 ensure-desktop-user.sh）"
fi

# ---------------------------------------------------------------- 2 locale
say "[2. locale / 中文]"
GEN=$(P /etc/locale.gen)
if [ -x "$(P /usr/sbin/locale-gen)" ]; then ok "locales 已安装"; else miss "locales 未安装"; fi
if [ -f "$GEN" ]; then
	for L in "en_US.UTF-8 UTF-8" "zh_CN.UTF-8 UTF-8"; do
		if grep -qxF "$L" "$GEN" || grep -qE "^[[:space:]]*${L%% *}[[:space:]]+UTF-8" "$GEN"; then
			grep -qxF "# $L" "$GEN" && { [ "$CHECK" = 1 ] && miss "locale.gen 里 $L 仍是注释"; }
		else
			[ "$CHECK" = 1 ] && miss "locale.gen 缺 $L（或仍被注释）"
		fi
	done
	if [ "$CHECK" = 0 ]; then
		sed -i -e 's/^#[[:space:]]*\(en_US\.UTF-8 UTF-8\)/\1/' -e 's/^#[[:space:]]*\(zh_CN\.UTF-8 UTF-8\)/\1/' "$GEN"
	fi
else
	miss "/etc/locale.gen 不存在"
fi
# 已生成的 locale 是否存在（Debian 用 locale-archive，不是逐 locale 目录 ⇒ 必须查 `locale -a`）
loc_has() { [ -n "$R" ] && chroot "$R" locale -a 2>/dev/null || locale -a 2>/dev/null; }
if loc_has | grep -qiE '^zh_CN\.utf-?8$'; then ok "zh_CN locale 已生成"
else
	if [ "$CHECK" = 1 ]; then miss "zh_CN locale 未生成（缺 locale-gen 产物）"
	else chroot "$R" /usr/sbin/locale-gen >/dev/null 2>&1 || locale-gen >/dev/null 2>&1 || true
		loc_has | grep -qiE '^zh_CN\.utf-?8$' && fix "locale-gen 生成 zh_CN" || miss "locale-gen 未生成 zh_CN（locales 包缺失？）"
	fi
fi
DEF=$(P /etc/default/locale)
if [ -f "$DEF" ] && grep -qx 'LANG=zh_CN.UTF-8' "$DEF"; then ok "/etc/default/locale LANG=zh_CN.UTF-8"
elif [ "$CHECK" = 1 ]; then miss "/etc/default/locale 未设 LANG=zh_CN.UTF-8"
else
	cat > "$DEF" <<'EOF'
# /etc/default/locale — 设备主力语言 = 简体中文（2026-11-07 daily-baseline.sh 写）
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_TIME=zh_CN.UTF-8
LC_NUMERIC=zh_CN.UTF-8
LC_MONETARY=zh_CN.UTF-8
LC_PAPER=zh_CN.UTF-8
LC_NAME=zh_CN.UTF-8
LC_ADDRESS=zh_CN.UTF-8
LC_TELEPHONE=zh_CN.UTF-8
LC_MEASUREMENT=zh_CN.UTF-8
LC_IDENTIFICATION=zh_CN.UTF-8
EOF
	fix "写入 /etc/default/locale（zh_CN.UTF-8）"
fi
if [ -n "$(find "$(P /usr/share/fonts)" -name 'NotoSansCJK*' -print -quit 2>/dev/null)" ]; then ok "CJK 字体已装"
else miss "缺 CJK 字体（fonts-noto-cjk）"; fi

# ---------------------------------------------------------------- 3 输入法
say "[3. 输入法（fcitx5 + Rime，OSK 槽位留给 phosh-osk-stevia）]"
ENVD=$(P /etc/environment.d/50-elden-ime.conf)
if [ -f "$ENVD" ] && grep -qx 'GTK_IM_MODULE=fcitx' "$ENVD"; then ok "/etc/environment.d/50-elden-ime.conf"
elif [ "$CHECK" = 1 ]; then miss "缺 /etc/environment.d/50-elden-ime.conf（GTK/QT_IM_MODULE=fcitx）"
else
	mkdir -p "$(P /etc/environment.d)"
	cat > "$ENVD" <<'EOF'
# 输入法：fcitx5 + Rime。Phosh 0.55 的 phosh-osk-stevia 走 zwp_virtual_keyboard
# （不是 input-method v2），因此 fcitx5 作为 GTK/QT IM 模块参与组词即可。
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF
	fix "写入 /etc/environment.d/50-elden-ime.conf"
fi
UNIT=$(P /etc/systemd/user/fcitx5.service)
if [ -f "$UNIT" ]; then ok "/etc/systemd/user/fcitx5.service"
elif [ "$CHECK" = 1 ]; then miss "缺 fcitx5 user unit（无自启）"
else
	mkdir -p "$(P /etc/systemd/user)"
	cat > "$UNIT" <<'EOF'
[Unit]
Description=Fcitx5 input method (Rime; waylandim disabled: phosh-osk-stevia owns the OSK slot)
Documentation=man:fcitx5(1)
After=graphical-session-pre.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/fcitx5 -r --disable waylandim
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
EOF
	fix "写入 /etc/systemd/user/fcitx5.service"
fi
LINK=$(P /etc/systemd/user/graphical-session.target.wants/fcitx5.service)
if [ -L "$LINK" ]; then ok "fcitx5 已 enable（graphical-session.target.wants）"
elif [ "$CHECK" = 1 ]; then miss "fcitx5 未 enable（登录后不会自启）"
else
	# 用系统级 wants 而不是 ~/.config：构建 chroot 里没有用户 home，构建/现场同一路径生效
	mkdir -p "$(dirname "$LINK")"
	ln -sf /etc/systemd/user/fcitx5.service "$LINK" && fix "enable fcitx5（graphical-session.target.wants）"
fi

# ---------------------------------------------------------------- 4 zram（内核门）
say "[4. zram（有内核模块才启用）]"
if modinfo -F name zram -k "$(cat "$(P /proc/sys/kernel/osrelease)" 2>/dev/null || echo 0)" >/dev/null 2>&1 \
   || [ -n "$(find "$(P /lib/modules)" -name 'zram.ko*' 2>/dev/null | head -1)" ]; then
	ZS=$(P /etc/systemd/system/zramswap.service)
	if [ -L "$ZS" ] && [ "$(readlink "$ZS")" = /dev/null ]; then
		[ "$CHECK" = 1 ] && miss "zramswap 仍被 mask（但内核已有 zram 模块）" || { rm -f "$ZS"; fix "解除 zramswap mask"; }
	else ok "内核有 zram 模块，zramswap 可用"; fi
else
	if [ -f "$(P /usr/lib/systemd/system/zramswap.service)" ] || [ -f "$(P /lib/systemd/system/zramswap.service)" ]; then
		ZS=$(P /etc/systemd/system/zramswap.service)
		if [ -L "$ZS" ] && [ "$(readlink "$ZS")" = /dev/null ]; then ok "内核无 CONFIG_ZRAM ⇒ zramswap 已 mask（预期）"
		elif [ "$CHECK" = 1 ]; then miss "内核无 CONFIG_ZRAM 但 zramswap 未 mask（每次启动会 FAILED 单元）"
		else mkdir -p "$(dirname "$ZS")"; ln -sf /dev/null "$ZS"; fix "内核无 vk* 的 zram 模块 ⇒ mask zramswap.service（补 CONFIG_ZRAM 后本脚本会自动解除）"; fi
	else ok "未装 zram-tools，无需处理"; fi
fi

say ""
say "结果: MISS=$MISS FIX=$FIXED"
[ "$CHECK" = 1 ] && [ "$MISS" -gt 0 ] && exit 1
exit 0
