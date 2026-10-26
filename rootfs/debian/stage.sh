#!/bin/bash
# stage.sh — 组装 Debian/Mobian 目标根的 **overlay 树**（`out/stage-debian/`），免 root、可重复
#
# 它把「换发行版时我们自己要加的东西」全部落成**一棵可直接 rsync 到目标根上的树**：
#   1. 固件：`out/debian/elden-firmware_<ver>_all.deb` 解包（/lib/firmware + /usr/share/qcom）
#   2. 模块树：`out/modstage-<vk>/lib/modules/<UTS>` + `depmod -b`（无需 chroot/root）
#   3. 用户态：`packaging/elden-userland/MANIFEST.tsv` 里 repo_src != "-" 的行（脚本/配置/二进制）
#   4. systemd 单元：`packaging/elden-userland/out/units/systemd/*.service`
#   5. 发行版单元覆盖（drop-in）：hexagonrpcd（SSC 传感器入口，见下）
#   6. `/init` + `/etc/elden-init-mode=systemd`（pre-systemd 恢复通道，见 init 注释）
#
# 为什么是 overlay 而不是完整 rootfs：完整 rootfs 要 root（chroot 里跑 dpkg），
# 而 overlay 的全部内容都能免 root 组装+门禁。完整 rootfs 由 `--rootfs` 走 sudo 那条路（未实现）。
#
# 用法：
#   bash rootfs/debian/stage.sh                 # 全量组装 + 全部门禁
#   bash rootfs/debian/stage.sh --check         # 只跑门禁（要求已组装过）
#   VER=<deb 版本> MODSTAGE=out/modstage-vk163 UTS=... bash rootfs/debian/stage.sh
#
# 门禁（任一 FAIL 即 rc=1）：
#   A 固件：deb 内 `sm8750` 的 DT 固件名全在（复用 elden-firmware 的门禁）+ 传感器 DSP 树在
#   B 模块：每条 3 个抽样 `.ko` 的 vermagic **逐字等于** UTS；`modules.dep` 非空且无 "not found"
#   C 用户态：MANIFEST 每行 sha256 与 files/ 副本一致（与 verify.sh 同源判据）
#   D 单元：systemd-analyze verify 全绿；单元里不得出现 `rc-service`/`apk`（跨 init 污染）
#   E 语义红线：qbootctl 默认 enable、greetd 有 Restart、wifi-scan <180s、hapticd amp=255
#   F 初始化：/init 可 `sh -n`；`/etc/elden-init-mode` = systemd；init 里三个模式分支齐全
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
CHROOT=${CHROOT:-/opt/elden/arm64-sid}
STAGE=${STAGE:-$ROOT/out/stage-debian}
MODSTAGE=${MODSTAGE:-$ROOT/out/modstage-vk163}
UNITS=$ROOT/packaging/elden-userland/out/units/systemd
MANIFEST=$ROOT/packaging/elden-userland/MANIFEST.tsv
USERLAND=$ROOT/packaging/elden-userland
QCOM_ROOT=/usr/share/qcom/sm8750/LENOVO/TB322FC

MODE=all
for a in "$@"; do case "$a" in
	--check) MODE=check ;;
	-h|--help) sed -n '2,26p' "$0"; exit 0 ;;
	*) echo "未知参数 $a" >&2; exit 2 ;;
esac; done

fail=0; warn=0
ok()   { printf '  ok    %s\n' "$*"; }
bad()  { printf '  FAIL  %s\n' "$*"; fail=$((fail+1)); }
warnf(){ printf '  WARN  %s\n' "$*"; warn=$((warn+1)); }
sec()  { printf '\n[%s]\n' "$*"; }
die()  { printf 'FATAL  %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- 选版本/UTS
UTS=${UTS:-$(ls -1 "$MODSTAGE/lib/modules" 2>/dev/null | head -1)}
[ -n "${UTS:-}" ] || die "找不到模块树：$MODSTAGE/lib/modules/*（先跑 scripts/build-kernel.sh / modules_install）"
DEB=${DEB:-$(ls -1t "$ROOT"/out/debian/elden-firmware_*.deb 2>/dev/null | head -1)}
[ -n "${DEB:-}" ] || die "找不到固件 deb：out/debian/elden-firmware_*.deb（先跑 rootfs/debian/elden-firmware/build.sh --all）"

printf 'stage   : %s\n' "${STAGE#$ROOT/}"
printf 'modules : %s\n' "${MODSTAGE#$ROOT/}/lib/modules/$UTS"
printf 'firmware: %s\n' "${DEB#$ROOT/}"

# ---------------------------------------------------------------- 组装
if [ "$MODE" != check ]; then
	sec "组装 overlay"
	rm -rf "$STAGE"
	mkdir -p "$STAGE"

	printf '  1/6 固件 deb 解包\n'
	dpkg-deb -x "$DEB" "$STAGE" || die "dpkg-deb -x 失败"

	printf '  2/6 模块树 + depmod -b（免 root）\n'
	mkdir -p "$STAGE/lib/modules"
	rsync -a "$MODSTAGE/lib/modules/$UTS" "$STAGE/lib/modules/" || die "rsync 模块树失败"
	depmod -b "$STAGE" "$UTS" || die "depmod -b 失败"

	printf '  3/6 用户态文件（MANIFEST）\n'
	while IFS=$'\t' read -r dst kind sha size mode repo_src; do
		[ "$dst" = dst ] && continue
		[ -n "${dst:-}" ] || continue
		[ "${repo_src:-}" = - ] && continue          # 设备侧 ELF：迁移时用 sources.tsv 的 host 产物
		case "$kind" in
			openrc-initd|locald) continue ;;           # Debian 侧不需要 OpenRC/local.d
		esac
		src="$USERLAND/$repo_src"
		[ -f "$src" ] || { bad "MANIFEST 副本缺失: $repo_src"; continue; }
		install -D -m "${mode:-644}" "$src" "$STAGE$dst" || bad "install 失败: $dst"
	done < "$MANIFEST"

	printf '  4/6 systemd 单元\n'
	mkdir -p "$STAGE/usr/lib/systemd/system"
	for u in "$UNITS"/*.service; do
		install -D -m 644 "$u" "$STAGE/usr/lib/systemd/system/$(basename "$u")"
	done

	printf '  5/6 hexagonrpcd drop-in（SSC 传感器入口）\n'
	# 为什么是 drop-in 而不是自建 unit / 自建包：
	#   Debian 的 hexagonrpcd 0.4.0 **没有** hexagonrpcd-adsp-sensorspd 二进制；
	#   同一个 /usr/bin/hexagonrpcd 用 `-s` 就是 attach sensorspd，路径用 -R 指到
	#   /usr/share/qcom/sm8750/LENOVO/TB322FC（本仓库 elden-firmware 包提供）。
	#   ¥ 变量名/默认值取自包内 /usr/share/doc/hexagonrpcd/README.Debian（实测）。
	mkdir -p "$STAGE/etc/systemd/system/hexagonrpcd.service.d"
	# 别名：这是**必要**的，不是美化。render.py 把 services.tsv 的 `iio-sensor-proxy after
	# hexagonrpcd-adsp-sensorspd` 渲染成 `After=hexagonrpcd-adsp-sensorspd.service`，而 Debian
	# 侧根本没这个单元名（只有 hexagonrpcd.service）—— 不加别名就是「依赖静默失效」，
	# 与本项目已踩过的 `Requires=localmount` 同一类（render.py 注释里的那段）。
	ln -sfn /usr/lib/systemd/system/hexagonrpcd.service \
		"$STAGE/etc/systemd/system/hexagonrpcd-adsp-sensorspd.service"
	# hexagonrpcd.service 本体由 Debian 包提供（init=package），但它的**启用**我们预先落下：
	# overlay 先于包安装展开，所以这里直接建 wants 符号链接（systemd 允许目标单元稍后出现）。
	mkdir -p "$STAGE/etc/systemd/system/multi-user.target.wants"
	ln -sfn /usr/lib/systemd/system/hexagonrpcd.service \
		"$STAGE/etc/systemd/system/multi-user.target.wants/hexagonrpcd.service"
	# 第二个别名：`elogind.service` → `systemd-logind.service`。
	# services.tsv 给 greetd 写的是 `after seatd elogind`（Alpine 侧真是 elogind），
	# 渲染成 `After=elogind.service`；Debian 侧 logind 由 systemd 提供（systemd-logind.service）
	# ⇒ 不给别名就又是一条「依赖静默失效」（gate H 实测抓到，2026-10-26）。
	ln -sfn /usr/lib/systemd/system/systemd-logind.service \
		"$STAGE/etc/systemd/system/elogind.service"
	cat > "$STAGE/etc/systemd/system/hexagonrpcd.service.d/elden.conf" <<-EOF
	# GENERATED by rootfs/debian/stage.sh — DO NOT EDIT
	# 语义真源：packaging/elden-userland/services.tsv 的 hexagonrpcd-adsp-sensorspd 行
	# Alpine 侧等价物：/etc/init.d/hexagonrpcd-adsp-sensorspd
	#   command_args="-f /dev/fastrpc-adsp -d adsp -s" + -R \$hexagonrpcd_fw_dir
	[Service]
	Environment=hexagonrpcd_device=/dev/fastrpc-adsp
	Environment=hexagonrpcd_dsp=adsp
	Environment=hexagonrpcd_extra=-s
	Environment=hexagonrpcd_fw_dir=$QCOM_ROOT
	EOF

	printf '  6/7 init 模式标记\n'
	install -D -m 755 "$USERLAND/files/init" "$STAGE/init"
	mkdir -p "$STAGE/etc"
	printf 'systemd\n' > "$STAGE/etc/elden-init-mode"

	printf '  7/7 离线 enable 单元（systemctl --root，不需 root）\n'
	# 为什么不用“装完再 systemctl enable”：目标根里的首次启动就可能因为 qbootctl 未启用
	# 而让 AB 槽 retry 递减（PITFALLS #181，~7 次开机卡 fastboot）。把启用状态直接烘进 overlay，
	# 就不依赖“人在场记住跑 enable”这一步。
	enabled=0
	# ⚠️ 不能用 `IFS=$'\t' read` 直接读 services.tsv：tab 是 **IFS whitespace**，
	# 连续两个 tab（空列，如 before 列为空）会被当成**一个**分隔符吃掉 ⇒ 字段错位、
	# 取到空的 enabled（2026-10-26 实测：13 个该启用的单元只 enable 了 1 个）。
	# 与 check-pkgmap.sh 同一个坑：先用 awk 换成分隔符 \x1f 再 read。
	# （注意 awk 必须写 `{$1=$1; print}`：裸 `print` 直接输出 $0，OFS 不生效。）
	while IFS=$'\x1f' read -r name init class desc exec args env log respawn need after before wantedby en; do
		[ "${en:-0}" = 1 ] || continue
		[ "${init:-}" = package ] && continue  # 单元由 Debian 包自带，由包自己的 postinst 启用
		[ -f "$STAGE/usr/lib/systemd/system/$name.service" ] || continue
		systemctl --root="$STAGE" enable "$name.service" >/dev/null 2>&1 </dev/null \
			&& enabled=$((enabled+1)) || bad "systemctl --root enable 失败: $name"
	done < <(awk -F'\t' 'BEGIN{OFS="\x1f"} !/^#/ && NF {$1=$1; print}' "$USERLAND/services.tsv")
	ok "已烘入 enable: $enabled 个单元"
fi

# ---------------------------------------------------------------- 门禁
sec "A. 固件（DT 名 + 传感器 DSP 树）"
# 复用 elden-firmware 的 DTS 门禁：它自带「每条 firmware-name 都要在」的逻辑，这里只做包内复核。
# 注意：**不要**写 `dpkg-deb -c | grep -q` —— grep -q 提前关闭管道会让 tar 吃 SIGPIPE，
# 在 `set -o pipefail` 下把「文件其实在」误判成 FAIL（本项已踩：2026-10-26）。
# 先把清单落到临时文件再 grep。
DEB_LIST=$(mktemp); dpkg-deb -c "$DEB" > "$DEB_LIST" 2>/dev/null || die "dpkg-deb -c 失败"
trap 'rm -f "$DEB_LIST"' EXIT
for must in lib/firmware/qcom/sm8750/adsp.mdt \
            lib/firmware/qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin;
 do
	if grep -qF "./$must" "$DEB_LIST"; then ok "包内: $must"
	else bad "包内缺 $must"; fi
done
for must in sns_reg.conf config registry; do
	if [ -e "$STAGE$QCOM_ROOT/sensors/$must" ]; then ok "传感器 DSP: sensors/$must"
	else bad "传感器 DSP 缺 sensors/$must（SSC 传感器链必死）"; fi
done

sec "B. 模块树（vermagic / modules.dep）"
if [ -d "$STAGE/lib/modules/$UTS" ]; then ok "模块树在: lib/modules/$UTS（$(find "$STAGE/lib/modules/$UTS" -name '*.ko' | wc -l) 个 .ko）"
else bad "模块树缺失: lib/modules/$UTS"; fi
n=0
while read -r ko; do
	[ -n "$ko" ] || continue
	vm=$(modinfo -F vermagic "$ko" 2>/dev/null | awk '{print $1}')
	if [ "$vm" = "$UTS" ]; then ok "vermagic 逐字: $(basename "$ko")"
	else bad "vermagic 不符: $(basename "$ko") → '$vm' ≠ '$UTS'"; fi
	n=$((n+1))
done < <(find "$STAGE/lib/modules/$UTS" -name 'ath12k.ko' -o -name 'snd-q6apm.ko' -o -name 'novatek-nvt36xxx-spi.ko' 2>/dev/null | head -3)
[ "$n" -gt 0 ] || warnf "抽到 0 个 .ko 做 vermagic 比对（驱动名变了？）"
if [ -s "$STAGE/lib/modules/$UTS/modules.dep" ]; then
	if grep -q "not found" "$STAGE/lib/modules/$UTS/modules.dep"; then bad "modules.dep 有 not found 依赖"
	else ok "modules.dep 非空且无 not found"; fi
else bad "modules.dep 缺失/为空（depmod 没跑？）"; fi

sec "C. 用户态清单自洽（MANIFEST sha）"
nc=0
while IFS=$'\t' read -r dst kind sha size mode repo_src; do
	[ "$dst" = dst ] && continue
	[ -n "${dst:-}" ] || continue
	[ "${repo_src:-}" = - ] && continue
	case "$kind" in openrc-initd|locald) continue ;; esac
	[ -f "$STAGE$dst" ] || { bad "overlay 缺 $dst"; continue; }
	got=$(sha256sum "$STAGE$dst" | cut -d' ' -f1)
	[ "$got" = "$sha" ] && nc=$((nc+1)) || bad "$dst sha 不符（$got ≠ $sha）"
done < "$MANIFEST"
[ "$nc" -gt 0 ] && ok "$nc 个文件 sha 一致"

sec "D. systemd 单元（结构 + 跨 init 污染）"
have_verify=0; command -v systemd-analyze >/dev/null && have_verify=1
for u in "$STAGE"/usr/lib/systemd/system/*.service; do
	b=$(basename "$u")
	if grep -qE '\b(rc-service|rc-update|apk)\b' "$u"; then bad "$b 含 OpenRC/apk 调用（跨 init 污染）"; fi
	if [ "$have_verify" = 1 ]; then
		# 过滤三类**预期**噪声（overlay 不是完整根，故 ExecStart 目标大多不在主机上）：
		#   · "Command /usr/... is not executable" —— 目标根才有那个二进制（greetd/qbootctl/自研脚本）
		#   · "Unit ... not found" / "Failed to ..." —— 依赖单元由 Debian 包提供（dbus/NetworkManager…）
		# 只留真正的语法/键错误（如 Unknown key / Invalid ...）
		out=$(systemd-analyze verify "$u" 2>&1 \
			| grep -vE "is not executable|Failed to (load|find|resolve)|not found|could not be found" || true)
		[ -z "$out" ] || bad "$b systemd-analyze verify: $(echo "$out" | head -2 | tr '\n' ' ')"
	fi
done
nunits=$(ls "$STAGE"/usr/lib/systemd/system/*.service 2>/dev/null | wc -l)
ok "$nunits 个单元已核（systemd-analyze=$have_verify）"
grep -q "hexagonrpcd_extra=-s" "$STAGE/etc/systemd/system/hexagonrpcd.service.d/elden.conf" \
	&& ok "hexagonrpcd drop-in: -s + fw_dir 指向 $QCOM_ROOT" \
	|| bad "hexagonrpcd drop-in 缺 -s/fw_dir"

sec "E. 语义红线"
grep -q "WantedBy=multi-user.target" "$STAGE/usr/lib/systemd/system/qbootctl.service" \
	&& ok "qbootctl 会被 enable（PITFALLS #181：否则 ~7 次重启卡 fastboot）" \
	|| bad "qbootctl 缺 WantedBy（槽位会 retry 归零）"
grep -q "^Restart=always" "$STAGE/usr/lib/systemd/system/greetd.service" \
	&& ok "greetd Restart=always（PITFALLS #318：崩=无桌面）" \
	|| bad "greetd 无 Restart=always"
grep -qE "WIFI_SCAN_INTERVAL=1[0-7][0-9]|WIFI_SCAN_INTERVAL=[0-9]{1,2}$" "$STAGE/usr/lib/systemd/system/wifi-scan-refresh.service" \
	&& ok "wifi-scan-refresh 间隔 <180s（PITFALLS #354）" \
	|| warnf "wifi-scan-refresh 间隔未在 1–179s 区间（人工核）"
grep -q "amp-a 0xffff" "$STAGE/usr/lib/systemd/system/elden-hapticd.service" \
	&& ok "elden-hapticd amplitude=255（C10）" \
	|| bad "elden-hapticd amplitude 不是 255"

sec "F. init 模式（pre-systemd 恢复通道）"
if [ -f "$STAGE/init" ]; then
	sh -n "$STAGE/init" && ok "/init 语法通过" || bad "/init 语法错误"
	[ "$(cat "$STAGE/etc/elden-init-mode" 2>/dev/null)" = systemd ] \
		&& ok "/etc/elden-init-mode = systemd" || bad "/etc/elden-init-mode 不是 systemd"
	grep -q 'init_mode" = legacy' "$STAGE/init" && grep -q 'init_mode" != legacy' "$STAGE/init" \
		&& ok "init 三值分支（legacy / openrc / systemd）齐全" \
		|| bad "init 模式分支不全（改坏了 openrc/legacy 语义？）"
	# 关键性质：lifeline 必须在交接之前（恢复通道先于 PID1 服务）
	l=$(grep -n 'usb0 up: 192.168.7.1' "$STAGE/init" | head -1 | cut -d: -f1)
	h=$(grep -n 'handing PID1' "$STAGE/init" | head -1 | cut -d: -f1)
	if [ -n "$l" ] && [ -n "$h" ] && [ "$l" -lt "$h" ]; then ok "lifeline(usb0/sshd) 在交接之前（第 $l 行 < 第 $h 行）"
	else bad "lifeline 顺序可疑（usb0=$l handoff=$h）"; fi
else bad "overlay 缺 /init"; fi

sec "G. 单元启用状态（烘进 overlay，不靠首启人工 enable）"
W="$STAGE/etc/systemd/system/multi-user.target.wants"
for u in qbootctl greetd iio-sensor-proxy wifi-scan-refresh elden-hapticd ath12k-retry net-selfheal; do
	[ -L "$W/$u.service" ] && ok "已 enable: $u" || bad "未 enable: $u（首启会自己恢复/跳步）"
done
[ -L "$STAGE/etc/systemd/system/display-manager.service" ] \
	&& ok "display-manager.service → greetd（桌面由 greetd 起）" \
	|| bad "display-manager 别名缺失（greetd 不会被当作显示管理器）"

sec "H. 单元依赖名可解析（防「依赖静默失效」）"
# 为什么单列一段：render.py 的 UNIT_MAP 就是因为 `Requires=localmount` 静默失效而存在的；
# Debian 侧还有一批单元名由**包**提供（dbus/NetworkManager/bluetooth/lxc/waydroid/hexagonrpcd…），
# 一旦我们把 services.tsv 的依赖名渲染成一个两边都不存在的名字，systemd 只会默默忽略。
# 判据：每个 After=/Requires=/Before=/Wants= 里的单元名，必须属于下列之一，否则 WARN 点名。
KNOWN_UNITS="dbus.service NetworkManager.service bluetooth.service seatd.service rtkit-daemon.service
 udisks2.service polkit.service lxc.service waydroid-container.service hexagonrpcd.service
 hexagonrpcd-adsp-sensorspd.service elogind.service systemd-logind.service
 local-fs.target multi-user.target network-pre.target
 systemd-modules-load.service systemd-udevd.service systemd-sysusers.service systemd-tmpfiles-setup.service
 systemd-udev-settle.service systemd-udev-trigger.service systemd-hwclock.service systemd-hostnamed.service
 systemd-sysctl.service shutdown.target poweroff.target reboot.target halt.target default.target
 greetd.service elden-local.service sshd.service chronyd.service"
for u in "$STAGE"/usr/lib/systemd/system/*.service; do
	b=$(basename "$u")
	deps=$(grep -hoE '^(After|Requires|Before|Wants|Requisite)=.*' "$u" 2>/dev/null \
		| sed 's/^[A-Za-z]*=//' | tr ' ' '\n' | grep -v '^$' | sort -u)
	for d in $deps; do
		case " $(echo $KNOWN_UNITS) " in
			*" $d "*) : ;;
			*) warnf "H $b 依赖 $d —— 既不在 overlay 也不在已知 Debian 单元清单里（systemd 会静默忽略）" ;;
		esac
	done
done
ok "依赖名解析完毕（$nunits 个单元）"

printf '\n==== stage: FAIL=%d WARN=%d  （产物 %s）\n' "$fail" "$warn" "${STAGE#$ROOT/}"
[ "$fail" -eq 0 ] || exit 1
