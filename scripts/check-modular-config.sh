#!/bin/bash
# check-modular-config.sh — 模块化 config 门禁（第二层，2026-10-26）
#
# 用法：
#   scripts/check-modular-config.sh                # 检查 KDIR(默认 build/vk151) 当前 .config
#   KDIR=… CONFIG=<path> scripts/check-modular-config.sh
#   scripts/check-modular-config.sh --self-test    # 正/负向自检（负向必须 FAIL）
#   MODDIR=<path> …                                # 额外校验模块树 modules.dep + vermagic
#
# 校验项：
#  1. 锚点不回退（ARCH_QCOM/DRM_MSM/panel/clk/pinctrl/interconnect/SPMI/regulator/
#     console/UFS/TSENS 等 28 个；MMC 故意不设锚——v2 把 TF 翻 =m，root 在 UFS）。
#     可用 ANCHORS="..." 环境变量覆盖。
#  2. syncconfig 复核：olddefconfig 跑两遍，第二遍必须零变化（一致性）；
#     且第一遍解析不得丢掉任何锚点（PITFALLS #162）。
#  3. 静态依赖核对：**tristate** 的 =y 符号，其 `depends on`/`select` 不得指向 =m
#     （kconfig 不可能给出这种解 ⇒ 说明 config 被手改撒谎）。
#     注意：bool 子项随 tristate 父项 =m 保持 =y 是合法的（代码并入该模块，
#     见第一层 hci_qca 案例），不判 FAIL。
#  4. MODDIR 提供时：modules.dep 行数 ≥ .ko 数；抽查 modinfo vermagic == 内核 UTS。
set -euo pipefail

ROOT="${ROOT:-/home/xuqianhui/y700-elden}"
if [ -z "${KDIR:-}" ]; then
	_t=$(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$ROOT/patches/current-tree" 2>/dev/null | grep -v '^$' | head -1)
	KDIR="${_t:+$ROOT/$_t}"
fi
# 兜底（2026-11-05）：current-tree 指向的树可能已被归档 ⇒ 退到任意现有 build/*/.config
for _c in "$ROOT"/build/*/.config; do [ -f "$_c" ] && { KDIR="${_c%/.config}"; break; }; done
KDIR="${KDIR:-$ROOT/build/m3v2-7.3rc7}"
CFG="${CONFIG:-$KDIR/.config}"
CROSS="${CROSS:-aarch64-linux-gnu-}"
DEFAULT_ANCHORS="ARCH_QCOM DRM_MSM DRM_MSM_DSI DRM_PANEL_NOVATEK_NT36536 CLK_GLYMUR_GCC QCOM_CLK_RPMH QCOM_RPMH QCOM_RPMHPD QCOM_COMMAND_DB PINCTRL_SM8750 PINCTRL_GLYMUR INTERCONNECT_QCOM_SM8750 SPMI_MSM_PMIC_ARB MFD_SPMI_PMIC REGULATOR_QCOM_SPMI REGULATOR_QCOM_RPMH SERIAL_QCOM_GENI SERIAL_QCOM_GENI_CONSOLE QCOM_GENI_SE BLK_DEV_SD SCSI_UFS_QCOM SCSI_UFSHCD_PLATFORM PHY_QCOM_QMP_UFS QCOM_TSENS NVMEM_QCOM_QFPROM I2C_QCOM_GENI SPI_QCOM_GENI"
ANCHORS="${ANCHORS:-$DEFAULT_ANCHORS}"

fail() { echo "FAIL: $*"; exit 1; }
pass() { echo "PASS: $*"; }

# ---------------------------------------------------------------- 结果缓存（2026-11-05）
# 为什么：本节是 check-doctor 里最贵的一段（实测 3.23 s = 两遍 `make olddefconfig` +
# 全 Kconfig 树静态依赖扫描），而它**只在 .config / 锚点清单 / 本脚本 / Kconfig 树改动时
# 才可能改变结论**；文档类提交、收尾轮、pre-commit 里反复跑同一份结论纯属重算。
# 失效键 = .config 内容 + 本脚本内容 + ANCHORS + KDIR + CROSS + 被扫描目录里最新 Kconfig 的
# (mtime, 路径)。任何一项变 ⇒ key 变 ⇒ 重算；**不做 TTL**（时间不能证明结论有效）。
# 关闭：MOD_CFG_CACHE=off（调试/怀疑缓存脏）或 --refresh（强制重算并刷新）。
cfg_fingerprint() {
	{
		sha256sum "$CFG" 2>/dev/null | cut -d' ' -f1
		sha256sum "${BASH_SOURCE[0]}" 2>/dev/null | cut -d' ' -f1
		printf '%s\n%s\n%s\n%s\n' "$ANCHORS" "$KDIR" "$CROSS" "${MODDIR:-}"
		# head 会 SIGPIPE 掉 sort；pipefail 下不接住就会让整个指纹命令"失败"而退化成每轮全算。
		( cd "$KDIR" 2>/dev/null && find drivers sound net firmware arch/arm64 mm security \
		    -name 'Kconfig*' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 ) || :
	} | sha256sum | cut -c1-16
}

check_cached() {
	local key dir out rcfile rc
	key=$(cfg_fingerprint) || { check_real; return; }
	# 缓存默认放仓库外（同 vk-identity.py 的理由：仓库根目录的任何新条目都会撞 §14 布局门）
	dir="${MOD_CFG_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/elden-doctor/$(printf '%s' "$ROOT" | sha256sum | cut -c1-8)/modular-config}"
	out="$dir/$key.out"; rcfile="$dir/$key.rc"
	if [ "${REFRESH:-0}" != 1 ] && [ -f "$out" ] && [ -f "$rcfile" ]; then
		cat "$out"
		rc=$(cat "$rcfile")
		echo "  info: 命中缓存 key=$key（.config/锚点/脚本/Kconfig 树均未变；--refresh 可强算）"
		return "$rc"
	fi
	mkdir -p "$dir" 2>/dev/null || { check_real; return; }
	# 注意：不能用裸 `( check_real ) > "$out"`——check_real 失败时 `set -e` 会提前终止，
	# 结果既没缓存也没输出（doctor 会收到空输出 → FAIL 详情为空）。用 `|| rc=$?` 接住。
	rc=0
	( check_real ) > "$out.tmp.$$" 2>&1 || rc=$?
	mv "$out.tmp.$$" "$out"
	printf '%s\n' "$rc" > "$rcfile"
	# 清掉崩溃残留的临时文件（保留最近 20 分钟内的，避免误删并发实例）
	find "$dir" -maxdepth 1 -name '*.out.tmp.*' -mmin +20 -delete 2>/dev/null || :
	# 只保留最近 12 份结论（每个 key 一份，键变了旧 key 就没用）
	ls -1t "$dir"/*.out 2>/dev/null | tail -n +13 | while read -r _f; do
		rm -f "$_f" "${_f%.out}.rc"; done || :
	cat "$out"
	return "$rc"
}

cfg_value() { grep -E "^${1}=" "$CFG" | tail -1 | sed "s/^${1}=//"; }

dedupe() { # Kconfig 语义：同名行后者生效
	awk '/^CONFIG_[A-Z0-9_]+=/{k=$1; sub(/=.*/,"",k); seen[k]=$0; order[++n]=k; next}
	     {print} END{for(i=1;i<=n;i++) print seen[order[i]]}' "$1" > "$2"
}

check_real() {
	local rc=0
	echo "== 门禁目标: $CFG =="
	[ -f "$CFG" ] || fail "config 不存在: $CFG"
	local tmp; tmp="$(mktemp -d)"
	dedupe "$CFG" "$tmp/r0.cfg"

	# 1. 锚点
	for a in $ANCHORS; do
		v="$(cfg_value "CONFIG_${a}")"
		[ "$v" = y ] || { echo "FAIL: 锚点回退 CONFIG_${a}=$v (需 =y)"; rc=1; }
	done
	[ $rc -eq 0 ] && pass "锚点全部 =y（$(echo $ANCHORS | wc -w) 个）"

	# 2. olddefconfig 解析两遍：第一遍允许依赖解析，第二遍必须零变化
	local before after
	before="$(grep -cE '^CONFIG_[A-Z0-9_]+=y$' "$tmp/r0.cfg" || true)"
	( cd "$KDIR" && export PATH="$HOME/bin:$PATH" && \
	  KCONFIG_CONFIG="$tmp/r0.cfg" make ARCH=arm64 CROSS_COMPILE="$CROSS" olddefconfig >/dev/null 2>&1 )
	cp "$tmp/r0.cfg" "$tmp/r1.cfg"
	( cd "$KDIR" && export PATH="$HOME/bin:$PATH" && \
	  KCONFIG_CONFIG="$tmp/r0.cfg" make ARCH=arm64 CROSS_COMPILE="$CROSS" olddefconfig >/dev/null 2>&1 )
	if cmp -s "$tmp/r0.cfg" "$tmp/r1.cfg"; then
		pass "olddefconfig 幂等（第二遍零变化）"
	else
		echo "FAIL: olddefconfig 非幂等（解析后有依赖漂移）："
		diff "$tmp/r1.cfg" "$tmp/r0.cfg" | head -20
		rc=1
	fi
	after="$(grep -cE '^CONFIG_[A-Z0-9_]+=y$' "$tmp/r0.cfg" || true)"
	echo "  info: =y $before → $after, =m $(grep -cE '^CONFIG_[A-Z0-9_]+=m$' "$tmp/r0.cfg" || true)"
	for a in $ANCHORS; do
		grep -qE "^CONFIG_${a}=y$" "$tmp/r0.cfg" || { echo "FAIL: 解析后丢失锚点 CONFIG_${a}（PITFALLS #162 型）"; rc=1; }
	done

	# 3. 静态依赖：tristate=y 的 depends/select 不得指向 =m
	if python3 - "$KDIR" "$tmp/r0.cfg" <<'PYEOF'
import re, sys, os
kdir, cfgp = sys.argv[1], sys.argv[2]
cfg = {}
for l in open(cfgp):
    m = re.match(r'CONFIG_([A-Z0-9_]+)=(y|m|n)', l)
    if m: cfg[m.group(1)] = m.group(2)
types, deps = {}, {}
for root in ['drivers', 'sound', 'net', 'firmware', 'arch/arm64', 'mm', 'security']:
    base = os.path.join(kdir, root)
    if not os.path.isdir(base): continue
    for dp, _, fs in os.walk(base):
        for f in fs:
            if f != 'Kconfig' and not f.startswith('Kconfig.'): continue
            cur = None
            for line in open(os.path.join(dp, f), encoding='utf-8', errors='ignore'):
                m = re.match(r'config\s+([A-Z0-9_]+)', line)
                if m: cur = m.group(1); continue
                if cur:
                    tm = re.match(r'\s*(tristate)\b', line)
                    if tm: types[cur] = 'tristate'
                    for dm in re.finditer(r'(?:depends on|select)\s+([A-Z0-9_]+)', line):
                        deps.setdefault(cur, set()).add(dm.group(1))
bad = []
for s, v in cfg.items():
    if v != 'y' or types.get(s) != 'tristate': continue
    for d in deps.get(s, ()):
        if cfg.get(d) == 'm':
            bad.append(f"{s} (tristate=y) -> {d} (m)")
if bad:
    print("FAIL: tristate=y 依赖/选中 =m（kconfig 不可能解，config 撒谎）：")
    for b in bad[:20]: print("  " + b)
    sys.exit(1)
sys.exit(0)
PYEOF
	then pass "tristate=y 的 depends/select 无 =m 引用（bool 子项随模块 =y 属合法）"
	else rc=1; fi

	# 4. 模块树（可选）
	if [ -n "${MODDIR:-}" ]; then
		[ -f "$MODDIR/modules.dep" ] || { echo "FAIL: $MODDIR/modules.dep 缺失"; rc=1; }
		ko_total="$(find "$MODDIR" \( -name '*.ko' -o -name '*.ko.zst' \) | wc -l)"
		dep_lines="$(wc -l < "$MODDIR/modules.dep" 2>/dev/null || echo 0)"
		[ "$dep_lines" -ge "$ko_total" ] || { echo "FAIL: modules.dep 行数 $dep_lines < .ko 数 $ko_total"; rc=1; }
		uts="$(cat "$KDIR/include/config/kernel.release" 2>/dev/null || sed -n 's/^#define UTS_RELEASE \"//p' "$KDIR/include/generated/utsrelease.h" 2>/dev/null | head -1)"
		[ -n "$uts" ] || { echo "FAIL: 取不到内核 UTS"; rc=1; }
		bad_ver=0
		for ko in $(find "$MODDIR" -name '*.ko' | head -50); do
			vm="$(modinfo -F vermagic "$ko" 2>/dev/null || true)"
			# vermagic = "<UTS> SMP preempt mod_unload aarch64"；逐字一致指首字段 == UTS
			[ "${vm%% *}" = "$uts" ] || { echo "FAIL: vermagic 不一致 $ko: '$vm' != '$uts'"; bad_ver=1; break; }
		done
		[ $bad_ver -eq 0 ] && pass "vermagic 与 UTS 一致（抽查 50 个 .ko, UTS=$uts）"
		[ "$dep_lines" -ge "$ko_total" ] && pass "modules.dep 覆盖完整（$ko_total .ko / $dep_lines 行）"
	fi

	rm -rf "$tmp"
	[ $rc -eq 0 ] && echo "== 门禁 PASS ==" || { echo "== 门禁 FAIL =="; exit 1; }
}

self_test() {
	local tmp; tmp="$(mktemp -d)"
	echo "== self-test: 正向（基线 + fragment-modular-v2）=="
	local pos="$tmp/pos.cfg"
	{ grep -vE '^CONFIG_(MMC|QRTR|RPMSG|QCOM_APR|QCOM_PDR|QCOM_QMI|QCOM_Q6V5|QCOM_PIL|USB_DWC3|PHY_QCOM_QMP_USB|PHY_QCOM_QMP_COMBO|PHY_QCOM_EUSB2|PHY_QCOM_M31|TYPEC_UCSI|TYPEC_DP_ALTMODE|QCOM_PMIC_GLINK|BATTERY_QCOM_BATTMGR|QCOM_VADC|QCOM_SPMI_ADC5|QCOM_SPMI_ADC_TM5|QCOM_SPMI_TEMP|RTC_DRV_PM8XXX|PINCTRL_LPASS_LPI|PINCTRL_SM8650_LPASS|UCSI_PMIC_GLINK|QCOM_SMD_RPM|QCOM_CLK_SMD_RPM|REGULATOR_QCOM_SMD_RPM|INTERCONNECT_QCOM_SMD_RPM|QCOM_RPMPD|QCOM_PD_MAPPER|QCOM_RPROC_COMMON|QCOM_SYSMON|PWRSEQ_EMMC|PWRSEQ_SIMPLE|CRC7)=' "$KDIR/.config";
	  grep '^CONFIG' "$ROOT/patches/fragment-modular-v2.config"; } > "$pos"
	if CONFIG="$pos" bash "$0" >/dev/null 2>&1; then echo "self-test 正向 PASS ✓"; else echo "self-test 正向应 PASS 却 FAIL ✗"; CONFIG="$pos" bash "$0"; exit 1; fi

	echo "== self-test: 负向1（DRM_MSM=y→m，锚点必须拦下）=="
	local neg="$tmp/neg1.cfg"; sed 's/^CONFIG_DRM_MSM=y$/CONFIG_DRM_MSM=m/' "$pos" > "$neg"
	if CONFIG="$neg" bash "$0" >/dev/null 2>&1; then echo "self-test 负向1 应 FAIL 却 PASS ✗"; exit 1; else echo "self-test 负向1 FAIL ✓（如预期）"; fi

	echo "== self-test: 负向2（清空 ARCH_QCOM，解析复核必须拦下）=="
	local neg2="$tmp/neg2.cfg"; sed 's/^CONFIG_ARCH_QCOM=y$/# CONFIG_ARCH_QCOM is not set/' "$pos" > "$neg2"
	if CONFIG="$neg2" bash "$0" >/dev/null 2>&1; then echo "self-test 负向2 应 FAIL 却 PASS ✗"; exit 1; else echo "self-test 负向2 FAIL ✓（如预期）"; fi

	rm -rf "$tmp"
	echo "== self-test 全部通过 =="
}

case "${1:-}" in
	--self-test) self_test ;;
	--refresh) REFRESH=1; if [ -n "${MODDIR:-}" ]; then check_real; else check_cached; fi ;;
	*) if [ -n "${MODDIR:-}" ] || [ "${MOD_CFG_CACHE:-}" = off ]; then check_real
	   else check_cached; fi ;;
esac
