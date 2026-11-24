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

# 2026-11-23 修复：原实现 = `for a in "$@"` + 每轮尾部 `shift`。for 的词表在循环开始时
# 就已展开，shift 只改位置参数不改词表 ⇒ `--root DIR`（空格形）的 DIR 会被当成下一轮
# 的 a 撞上 `*)` 退出 rc=2（且 stderr 被 `2>/dev/null` 吞掉）；build-rootfs.sh:231 用的
# 恰是空格形 ⇒ 构建侧 daily-baseline 配置段一直是 no-op（被 `|| say warn` 掩盖）。
# 改法 = 数组下标遍历，取值参数显式 +2。
ROOT=""; CHECK=0; USER_NAME=xuqianhui1001
_args=("$@"); _i=0
while [ "$_i" -lt "${#_args[@]}" ]; do
	case "${_args[$_i]}" in
		--root) ROOT="${_args[$_i+1]}"; _i=$((_i+2)); continue ;;
		--root=*) ROOT="${_args[$_i]#--root=}" ;;
		--user) USER_NAME="${_args[$_i+1]}"; _i=$((_i+2)); continue ;;
		--user=*) USER_NAME="${_args[$_i]#--user=}" ;;
		--check) CHECK=1 ;;
		-h|--help) sed -n '2,30p' "$0"; exit 0 ;;
		*) echo "未知参数: ${_args[$_i]}" >&2; exit 2 ;;
	esac
	_i=$((_i+1))
done

R=${ROOT%/}
P() { printf '%s%s\n' "$R" "$1"; }
MISS=0; FIXED=0
ok()   { printf '  ok    %s\n' "$*"; }
warnf() { printf '  warn  %s\n' "$*"; }
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
# ★2026-11-24 单栈裁决（PITFALLS #716，用户报「输入法键盘无法唤起」当日实测）：
#   默认 IME 栈 = **phosh-osk-stub（我们的 divert+hold 自编件）+ B 案 RIME completer**，
#   fcitx5 整套（unit 自启 / indicator / toggle / focusd）退为 `--rollback` 资源、**默认不启用**。
#   原因两条且都实测：① 应用网格里点 `Fcitx 5` = 用默认参数起 fcitx5（waylandim 已加载）⇒ 抢
#   `zwp_input_method_v2` 槽 ⇒ osk-stub 只印 `Input method unavailable`、键盘永久不弹；
#   ② 两栈同时在册时，排障会先撞协议层，浪费整轮时间。
#   收敛工具 = `scripts/ime-single-stack.sh --check|--apply|--rollback`；要回老路则
#   `IME_STACK=fcitx bash daily-baseline.sh`（或直接跑 ime-single-stack.sh --rollback）。
IME_STACK=${IME_STACK:-osk}
say "[3. 输入法（单栈=$IME_STACK：osk = phosh-osk-stub + RIME completer；fcitx = 老路）]"
# 2026-11-21 用户裁决（落实 11-15 台账 T4）：**GTK_IM_MODULE 一律不设**。
#   依据 = `PITFALLS #618`：GTK 走 im-fcitx5.so 时客户端**不发** `zwp_text_input_v3.enable`
#   ⇒ phoc 收不到 ⇒ 虚拟键盘不自动弹；代价 = GTK 应用内无 fcitx 组词（#653 实测本栈 GTK3
#   本就不建 fcitx IC）⇒ **中文组词延后**。QT/XMODIFIERS 保留，Qt 应用仍可组词。
#   配带落地：`packaging/elden-userland/files/usr/local/sbin/elden-session-user` 里还额外
#   `unset GTK_IM_MODULE` + 先占住 QT/XMODIFIERS（im-config 的 70im-config_launch 有
#   “已设置则 hands off” 分支，不先占它会把 GTK_IM_MODULE 写回去）。
ENVD=$(P /etc/environment.d/50-elden-ime.conf)
if [ -f "$ENVD" ] && ! grep -qE '^GTK_IM_MODULE=' "$ENVD" && grep -qx 'QT_IM_MODULE=fcitx' "$ENVD"; then
	ok "/etc/environment.d/50-elden-ime.conf（无 GTK_IM_MODULE，QT/XMODIFIERS 在）"
elif [ "$CHECK" = 1 ]; then
	miss "/etc/environment.d/50-elden-ime.conf 不合策略（应无 GTK_IM_MODULE、有 QT_IM_MODULE=fcitx）"
else
	mkdir -p "$(P /etc/environment.d)"
	cat > "$ENVD" <<'EOF'
# 输入法：fcitx5 + Rime。**GTK_IM_MODULE 故意不设**（2026-11-21 用户裁决：
# 优先 OSK 自动弹；设 =fcitx 会让 GTK 不发 zwp_text_input_v3.enable，见 PITFALLS #618）。
# QT/XMODIFIERS 保留 ⇒ Qt 应用仍走 fcitx 组词；中文组词在 GTK 侧延后。
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF
	fix "写入 /etc/environment.d/50-elden-ime.conf（无 GTK_IM_MODULE）"
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
if [ "$IME_STACK" = fcitx ]; then
	if [ -L "$LINK" ]; then ok "fcitx5 已 enable（graphical-session.target.wants）"
	elif [ "$CHECK" = 1 ]; then miss "fcitx5 未 enable（登录后不会自启；IME_STACK=fcitx 时这是 MISS）"
	else
		# 用系统级 wants 而不是 ~/.config：构建 chroot 里没有用户 home，构建/现场同一路径生效
		mkdir -p "$(dirname "$LINK")"
		ln -sf /etc/systemd/user/fcitx5.service "$LINK" && fix "enable fcitx5（graphical-session.target.wants）"
	fi
else
	# 单栈（osk）：fcitx5 **不得**自启，否则会抢 IM 槽（PITFALLS #716）
	if [ -L "$LINK" ]; then
		if [ "$CHECK" = 1 ]; then miss "fcitx5 仍有自启链接（单栈下会抢 zwp_input_method_v2 槽；跑 scripts/ime-single-stack.sh --apply）"
		else rm -f "$LINK" && fix "移除 fcitx5 自启链接（单栈）"; fi
	else ok "fcitx5 未自启（单栈；IME_STACK=$IME_STACK）"; fi
fi

# ---------------------------------------------------------------- 3b 输入法可用性（触摸可达的中/英开关 + 配置器）
# 背景（2026-11-09）：Phosh 无 SNI 托盘 ⇒ fcitx5 的图标不在顶栏，触屏用户「找不到中文入口」；
# 另外「配置」图标点了没反应的真因 = 只装了 `fcitx5-configtool` 薄壳、**缺 fcitx5-config-qt**（真 UI 包）。
say "[3b. 输入法可用性（中/英切换图标 + 配置器）]"
IMESRC="$(dirname "$0")/ime"
UHOME="$(P /home/$USER_NAME)"
if [ "$ROOT" = "" ] && [ "$(id -un)" != "$USER_NAME" ] && [ -d "/home/$USER_NAME" ]; then
	UHOME="/home/$USER_NAME"
fi
TOGGLEBIN="$UHOME/.local/bin/fcitx5-ime-toggle"
TOGGLEDESK="$UHOME/.local/share/applications/fcitx5-ime-toggle.desktop"
if [ -f "$TOGGLEBIN" ]; then ok "中/英切换脚本已装（$TOGGLEBIN）"
elif [ "$CHECK" = 1 ]; then miss "缺 $TOGGLEBIN（触屏无中文入口）"
elif [ -f "$IMESRC/fcitx5-ime-toggle" ]; then
	mkdir -p "$(dirname "$TOGGLEBIN")"
	install -m 0755 "$IMESRC/fcitx5-ime-toggle" "$TOGGLEBIN" && fix "装中/英切换脚本"
else warnf "缺源文件 $IMESRC/fcitx5-ime-toggle（跳过）"; fi
if [ -f "$TOGGLEDESK" ] && [ "${IME_STACK:-osk}" = osk ]; then
	# 单栈（osk）：中/英切换走 osk-stub 自身布局，fcitx5 不在跑 ⇒ 这个图标点了只会报「输入法未就绪」
	if grep -qs '^NoDisplay=true' "$TOGGLEDESK"; then ok "应用网格「输入法 中/英」已隐藏（单栈）"
	elif [ "$CHECK" = 1 ]; then miss "「输入法 中/英」图标仍可见（单栈下无效；跑 scripts/ime-single-stack.sh --apply）"
	else printf '\nNoDisplay=true\n' >> "$TOGGLEDESK" && fix "隐藏「输入法 中/英」图标（单栈）"; fi
elif [ -f "$TOGGLEDESK" ]; then ok "应用网格图标已装（中/英切换）"
elif [ "$CHECK" = 1 ]; then miss "缺 $TOGGLEDESK"
elif [ -f "$IMESRC/fcitx5-ime-toggle.desktop" ]; then
	mkdir -p "$(dirname "$TOGGLEDESK")"
	sed "s#@HOME@#$UHOME#g" "$IMESRC/fcitx5-ime-toggle.desktop" > "$TOGGLEDESK" && fix "装应用网格图标（中/英切换）"
	command -v update-desktop-database >/dev/null 2>&1 && \
		update-desktop-database "$(dirname "$TOGGLEDESK")" >/dev/null 2>&1 || true
else warnf "缺源文件 $IMESRC/fcitx5-ime-toggle.desktop（跳过）"; fi
# fcitx5 配置器：只装薄壳会「点开没反应」，真 UI 在 fcitx5-config-qt（包在 tsv 里）
if [ -x "$(P /usr/bin/fcitx5-config-qt)" ] || [ -x "$(P /usr/lib/aarch64-linux-gnu/libexec/fcitx5-config-qt)" ]; then
	ok "fcitx5 配置器（fcitx5-config-qt）在位"
elif [ "$CHECK" = 1 ]; then miss "缺 fcitx5-config-qt（配置图标点了没反应）"
else warnf "缺 fcitx5-config-qt（apt 装；见 daily-baseline.tsv）"; fi
# 顶栏输入法指示（Phosh 无 SNI ⇒ 自己画 layer-shell 小胶囊）
INDHOME="$UHOME/.local/lib/elden"
IND="$INDHOME/fcitx5-indicator.py"
INDUNIT="$UHOME/.config/systemd/user/fcitx5-indicator.service"
if [ -f "$IND" ]; then ok "顶栏输入法指示脚本已装"
elif [ "$CHECK" = 1 ]; then miss "缺 $IND（顶栏看不到 中/英）"
elif [ -f "$IMESRC/fcitx5-indicator.py" ]; then
	mkdir -p "$INDHOME"
	install -m 0755 "$IMESRC/fcitx5-indicator.py" "$IND" && fix "装顶栏输入法指示"
else warnf "缺源文件 $IMESRC/fcitx5-indicator.py（跳过）"; fi
if [ -f "$INDUNIT" ]; then ok "顶栏指示 user unit 已装"
elif [ "$CHECK" = 1 ]; then miss "缺 $INDUNIT"
elif [ -f "$IMESRC/fcitx5-indicator.service" ]; then
	mkdir -p "$(dirname "$INDUNIT")"
	install -m 0644 "$IMESRC/fcitx5-indicator.service" "$INDUNIT" && fix "装顶栏指示 unit"
else warnf "缺源文件 $IMESRC/fcitx5-indicator.service（跳过）"; fi
# 依赖：GTK4 layer-shell（缺了指示器会退化成普通窗口）
if [ -f "$(P /usr/lib/aarch64-linux-gnu/libgtk4-layer-shell.so.0)" ] && \
   [ -f "$(P /usr/lib/aarch64-linux-gnu/girepository-1.0/Gtk4LayerShell-1.0.typelib)" ]; then
	ok "GTK4 layer-shell 运行库 + typelib 在位"
elif [ "$CHECK" = 1 ]; then miss "缺 libgtk4-layer-shell0 / gir1.2-gtk4layershell-1.0（包在 tsv）"
else warnf "缺 GTK4 layer-shell（apt 装；包在 daily-baseline.tsv）"; fi

# ---------------------------------------------------------------- 3b2 OSK 自动弹/收桥（elden-ime-focusd）
# 背景（2026-11-12，G1-38）：桥原来只靠手工起 ⇒ 重登就没了（用户报「自动弹/收没做好」）。
# 与 fcitx5 同一模式：/etc/systemd/user + graphical-session.target.wants（构建 chroot 与设备同路径生效）。
say "[3b2. OSK 自动弹/收桥（elden-ime-focusd）]"
FOCUSDBIN=$(P /usr/local/bin/elden-ime-focusd)
FOCUSDUNIT=$(P /etc/systemd/user/elden-ime-focusd.service)
FOCUSDLINK=$(P /etc/systemd/user/graphical-session.target.wants/elden-ime-focusd.service)
if [ -x "$FOCUSDBIN" ]; then ok "focusd 二进制在位（$FOCUSDBIN）"
elif [ "$CHECK" = 1 ]; then miss "缺 $FOCUSDBIN（OSK 不会自动弹）"
else warnf "缺 $FOCUSDBIN（用 packaging/elden-userland/build/elden-ime-focusd.sh 生成后装）"; fi
if [ -f "$FOCUSDUNIT" ]; then ok "focusd user unit 已装"
elif [ "$CHECK" = 1 ]; then miss "缺 $FOCUSDUNIT（重登后桥不在）"
elif [ -f "$IMESRC/elden-ime-focusd.service" ]; then
	mkdir -p "$(dirname "$FOCUSDUNIT")"
	install -m 0644 "$IMESRC/elden-ime-focusd.service" "$FOCUSDUNIT" && fix "装 focusd user unit"
else warnf "缺源文件 $IMESRC/elden-ime-focusd.service（跳过）"; fi
if [ "${IME_STACK:-osk}" = fcitx ]; then
	if [ -L "$FOCUSDLINK" ]; then ok "focusd 已 enable（graphical-session.target.wants）"
	elif [ "$CHECK" = 1 ]; then miss "focusd 未 enable（重登后不会自启）"
	else
		mkdir -p "$(dirname "$FOCUSDLINK")"
		ln -sf ../elden-ime-focusd.service "$FOCUSDLINK" && fix "enable focusd（graphical-session.target.wants）"
	fi
else
	# 单栈（osk）：kimpanel 桥没有 fcitx5 可听 ⇒ 常驻件只是误导（PITFALLS #716）
	if [ -L "$FOCUSDLINK" ]; then
		if [ "$CHECK" = 1 ]; then miss "focusd 仍有自启链接（单栈下无 kimpanel 信号源；跑 scripts/ime-single-stack.sh --apply）"
		else rm -f "$FOCUSDLINK" && fix "移除 focusd 自启链接（单栈）"; fi
	else ok "focusd 未自启（单栈）"; fi
fi

# ---------------------------------------------------------------- 3b3 候选/preedit 浮条（**已撤下，2026-11-13**）
# 试行版 = rootfs/debian/ime/elden-ime-candidates.{py,service}（GTK4 layer-shell 浮条 + focusd 的
# org.elden.ImePanel 信号转发）。**上机实测不可用**：layer-surface 一 map，焦点/IC 被打断，
# 页面被顶掉再回来，组字缓冲被直接提交上屏（PITFALLS #646）。
# ⇒ 这里**故意不再安装/启用**；文件留在仓库里作下次重做的起点（要重做必须做到「surface 全程不
#   unmap、只用透明度/内容切换」，并且先在合成器侧确认不抢焦点）。

# 输入法组：**`Items/0` 必须是 rime**（PITFALLS #619）
# 机制：fcitx5 给「每个新输入上下文」用的是 profile 的 `Items/0`，`DefaultIM=` 对它**无效**。
# 本脚本 2026-11-13 前写的是 `Items/0=keyboard-us`（DefaultIM=rime）⇒ 新窗口恒拿英文、Rime 不参与、
# 候选恒空（用户 11-12 报「还是没有候选词」的直接来源之一）。判据必须同时看两处。
PROF="$UHOME/.config/fcitx5/profile"
# 判据只看 `Items/0`（#619 实测 `DefaultIM=` 对新建输入上下文无效，别拿它当门禁）
prof_items0() {
	awk '/^\[Groups\/0\/Items\/0\]/{f=1;next} f&&/^Name=/{sub(/^Name=/,"");print;exit}' "$PROF" 2>/dev/null
}
prof_ok() { [ -f "$PROF" ] && [ "$(prof_items0)" = rime ]; }
if prof_ok; then
	ok "fcitx5 profile: Items/0=rime（新窗口进 Rime）"
	grep -qx 'DefaultIM=rime' "$PROF" || warnf "profile DefaultIM 不是 rime（不影响新 IC，仅提示）"
elif [ "$CHECK" = 1 ]; then miss "fcitx5 profile 的 Items/0 不是 rime（$( [ -f "$PROF" ] && prof_items0 || echo 缺文件)）⇒ 新窗口拿英文、候选为空（#619）"
else
	# fcitx5 **退出时会把内存态写回 profile** ⇒ 必须先停 unit 再改（#619 的坑）
	STOPPED=0
	if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -S "${XDG_RUNTIME_DIR}/bus" ] && command -v systemctl >/dev/null 2>&1; then
		systemctl --user stop fcitx5 >/dev/null 2>&1 && STOPPED=1
		pkill -x fcitx5 >/dev/null 2>&1 || true
	fi
	mkdir -p "$(dirname "$PROF")"
	cat > "$PROF" <<'PROFEOF'
[Groups/0]
Name=默认
Default Layout=us
DefaultIM=rime

[Groups/0/Items/0]
Name=rime

[Groups/0/Items/1]
Name=keyboard-us

[GroupOrder]
0=默认
PROFEOF
	fix "写 fcitx5 profile（Items/0=rime，一律按 #619 顺序）"
	[ "$STOPPED" = 1 ] && { systemctl --user start fcitx5 >/dev/null 2>&1 || true; }
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

# ------------------------------------------------- 5 GPU devfreq 爬频（T19，2026-11-14）
# 现象：桌面「触屏滑动的第一下」卡顿，后续操作正常。
# 根因（实测 2026-11-14）：GPU `3d00000.gpu` 空闲停在 **160 MHz**（simple_ondemand，polling 50 ms），
#   而第一帧通常是**全屏重绘**（1904x3040 = 12 MP）⇒ 在最低档吃几十 ms；
#   把 min_freq 抬到 max 后第一下不再卡（用户目视确认）⇒ 固化「缩短 polling + 抬地板」，
#   **不是钉死频率**：simple_ondemand 仍会按负载上跑（max 1.10 GHz）。
# 代价：空闲频率从 160 → 525 MHz，待机耗电会略升；嫌耗电就调小 GPU_MIN（见下）。
# 只对本机 sysfs 有意义：`--root`（chroot 构建）阶段目标设备的 GPU 不存在 ⇒ 直接跳过。
say "[5. GPU devfreq 爬频（第一下卡顿，T19）]"
GPU=/sys/class/devfreq/3d00000.gpu
GPU_POLL=10          # ms（默认 50；缩短到 10 让负载上升被更快发现）
GPU_MIN=525000000    # Hz（默认 160000000；要实现「完全不卡」可用 1100000000，代价=空闲耗电）
if [ -n "$R" ]; then
	ok "chroot 阶段跳过（GPU sysfs 属目标设备）"
elif [ ! -d "$GPU" ]; then
	miss "$GPU 不存在（GPU 未绑 devfreq？）"
else
	cur_poll=$(cat "$GPU/polling_interval" 2>/dev/null || echo '')
	cur_min=$(cat "$GPU/min_freq" 2>/dev/null || echo '')
	setv() { # setv <file> <want> <下文描述>
		if [ "$CHECK" = 1 ]; then miss "$(basename "$1"): 现值=${2:-未取到}，期望 $3"; return; fi
		if printf '%s' "$3" > "$1" 2>/dev/null; then fix "$(basename "$1") -> $3"; else miss "$(basename "$1") 写入失败（$3）"; fi
	}
	if [ "${cur_poll:-}" = "$GPU_POLL" ]; then ok "polling_interval = ${GPU_POLL} ms"; else setv "$GPU/polling_interval" "$cur_poll" "$GPU_POLL"; fi
	# min_freq 允许 ≥ 目标值（有人手工抬更高时不回退）
	if [ -n "${cur_min:-}" ] && [ "$cur_min" -ge "$GPU_MIN" ] 2>/dev/null; then ok "min_freq = ${cur_min} Hz (≥ ${GPU_MIN})"
	else setv "$GPU/min_freq" "$cur_min" "$GPU_MIN"; fi
fi

# --------------------------------------- 6 hexagonrpcd 不得可自启（D1-②，2026-11-23）
# 背景：hexagonrpcd 0.4.0 `-s` attach ADSP sensorspd 实测硬崩整机（无 Oops/pstore，journal
# 截断，PITFALLS #692/#694）⇒ 政策 = **构建器不装**（pkgmap.tsv drop 行 + check-pkgmap 门禁，
# 2026-11-20 落，stage.sh §5 P0-2 构建期无条件 mask 兜底）+ **在机保持 mask**（等串口/ramoops
# 取证通道建好再评估）。本节补最后一道：不管包从哪条路径进来（旧 chroot 残留 / 未来依赖链
# 变动 / 手工 apt install），unit 都不得可自启。幂等：未装 → ok；装了且已 mask → ok；
# 装了未 mask → --check 报 MISS / fix 落 mask（**不卸载**，保留二进制供取证；
# 卸载 = 手工 `apt-get purge hexagonrpcd`，见 reports/d1-host-side-20261123.md 回退节）。
say "[6. hexagonrpcd 不得可自启（builder 不装 / 在机 mask）]"
HXD=$(P /usr/bin/hexagonrpcd)
HXU=$(P /etc/systemd/system/hexagonrpcd.service)
if [ ! -e "$HXD" ]; then
	ok "hexagonrpcd 未安装（构建器不装政策，pkgmap.tsv drop）"
elif [ -L "$HXU" ] && [ "$(readlink "$HXU")" = /dev/null ]; then
	ok "hexagonrpcd 已安装但 unit 已 mask（取证通道未建前的预期态）"
elif [ "$CHECK" = 1 ]; then
	miss "hexagonrpcd 已安装且未 mask（-s attach ADSP 硬崩整机，PITFALLS #692/#694）"
else
	mkdir -p "$(dirname "$HXU")"
	if ln -sfn /dev/null "$HXU"; then fix "mask hexagonrpcd.service（→ /dev/null）"
	else miss "mask hexagonrpcd.service 失败（手工: ln -sfn /dev/null $HXU）"; fi
fi

# --------------------------------------- 7 时间基线自愈（D1-④，q28-DOSSIER §t T1）
# 背景：硬件 RTC 断电归零且**不可写**（hwclock -w → RTC_SET_TIME 拒绝）⇒ 冷启时钟停在假值。
# 设备 2026-11-16 已手工装 fake-hwclock（DOSSIER t-2 T1），但不在任何基线表 ⇒ 重建根回归。
# 本节把「时间基线四件套」并进巡检：chrony enabled / fake-hwclock 装并 enabled /
# elden-time-baseline.service（网络 UP → set-ntp → 等 NTPSynchronized）在位并 enabled。
# 装包不在这里（本脚本只做配置）：fake-hwclock 由 daily-baseline.tsv P0 行进构建/设备 apt 侧。
say "[7. 时间基线自愈（chrony + fake-hwclock + elden-time-baseline）]"
if [ -x "$(P /usr/sbin/chronyd)" ]; then ok "chrony 已安装"
else miss "chrony 未安装（pkgmap.tsv map chrony）"; fi
WANTS=$(P /etc/systemd/system/multi-user.target.wants)
if [ -e "$WANTS/chrony.service" ] || [ -e "$(P /etc/systemd/system/chronyd.service)" ]; then
	ok "chrony NTP 入口已 enable（chronyd.service 别名 / wants 链接）"
elif [ "$CHECK" = 1 ]; then
	miss "chrony NTP 未 enable（冷启不会自动校时）"
else
	mkdir -p "$WANTS"
	if ln -sfn /usr/lib/systemd/system/chrony.service "$WANTS/chrony.service"; then fix "enable chrony.service"
	else miss "enable chrony.service 失败"; fi
fi
FHBIN=""
for b in /usr/sbin/fake-hwclock /sbin/fake-hwclock /usr/bin/fake-hwclock; do
	[ -x "$(P $b)" ] && { FHBIN=$b; break; }
done
if [ -n "$FHBIN" ]; then
	ok "fake-hwclock 已安装（$FHBIN，RTC 不可写的冷启兜底）"
	FHW=""
	for u in /usr/lib/systemd/system/fake-hwclock.service /lib/systemd/system/fake-hwclock.service; do
		[ -e "$(P $u)" ] && { FHW=$u; break; }
	done
	if [ -z "$FHW" ]; then ok "fake-hwclock 无包内单元（设备侧自定义 load.service/save.timer 形态，不处理）"
	elif [ -e "$WANTS/fake-hwclock.service" ] || [ -n "$(find "$(P /etc/systemd/system)" -maxdepth 2 -name 'fake-hwclock*' 2>/dev/null | head -1)" ]; then
		ok "fake-hwclock 启动入口已 enable"
	elif [ "$CHECK" = 1 ]; then
		miss "fake-hwclock.service 未 enable（冷启不恢复时间）"
	else
		mkdir -p "$WANTS"; ln -sfn "$FHW" "$WANTS/fake-hwclock.service" && fix "enable fake-hwclock.service" \
			|| miss "enable fake-hwclock.service 失败（该单元若为 static，手工建 wants 链接）"
	fi
else
	if [ "$CHECK" = 1 ]; then
		miss "fake-hwclock 未安装（daily-baseline.tsv P0 行；设备 11-16 已手工装，重建根会回归）"
	else
		warnf "fake-hwclock 未安装（本脚本不装包；apt-get install fake-hwclock，包在 daily-baseline.tsv）"
	fi
fi
TBU=""
for u in /etc/systemd/system/elden-time-baseline.service /usr/lib/systemd/system/elden-time-baseline.service; do
	[ -f "$(P $u)" ] && { TBU=$u; break; }
done
if [ -z "$TBU" ]; then
	warnf "elden-time-baseline.service 未部署（上机配方：scp rootfs/debian/units-extra/elden-time-baseline.service → /etc/systemd/system/；scp scripts/elden-time-baseline.sh → /usr/local/sbin/ chmod 755；ln -sfn ../elden-time-baseline.service /etc/systemd/system/multi-user.target.wants/）"
else
	ok "elden-time-baseline.service 在位（$TBU）"
	if [ -e "$WANTS/elden-time-baseline.service" ]; then ok "elden-time-baseline.service 已 enable"
	elif [ "$CHECK" = 1 ]; then miss "elden-time-baseline.service 未 enable（网络 UP 后不会自愈）"
	else mkdir -p "$WANTS"; ln -sfn ../elden-time-baseline.service "$WANTS/elden-time-baseline.service" && fix "enable elden-time-baseline.service" \
		|| miss "enable elden-time-baseline.service 失败"; fi
fi

say ""
say "结果: MISS=$MISS FIX=$FIXED"
[ "$CHECK" = 1 ] && [ "$MISS" -gt 0 ] && exit 1
exit 0
