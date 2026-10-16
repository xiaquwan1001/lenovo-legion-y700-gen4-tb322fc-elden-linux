#!/usr/bin/env bash
# pack-cloud-backup.sh — 把「本机独有、不可重下」的二进制整理成一个可直接上传云盘的目录
#
# 做法：用【硬链接】把源文件挂进上传目录（同文件系统 ⇒ 几乎不额外占盘）。
# 源都是只读 dump/归档，不会被就地改写 ⇒ 硬链接安全；跨文件系统时自动退化为真实拷贝。
#
# 分层：
#   T1-irreplaceable/            不可再生（设备/单元独有，或本机唯一副本）—— 建议无条件上云
#   T2-optional-redownloadable/  可重下但代价高 / 上游源可能失效 —— 建议一并上云（省重下）
#   明确可重下者（上游 clone / 云包已覆盖的整机镜像 / 可重建产物）不入包，见包内 README。
#
# 用法：
#   scripts/pack-cloud-backup.sh [DEST]         # 默认 ~/cloud-backup-y700-elden-<YYYYMMDD>
#   scripts/pack-cloud-backup.sh --list [DEST]  # 只列清单，不建目录
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
LIST_ONLY=0
if [ "${1:-}" = "--list" ]; then LIST_ONLY=1; shift; fi
DEST=${1:-"$HOME/cloud-backup-y700-elden-$(date +%Y%m%d)"}
DL=${EDL_PACKAGE_DIR:-"$HOME/下载/tb322fc"}
L2=${L2_DIR:-"/mnt/Samsung/l2"}
MESA=${MESA_OUT_DIR:-"/mnt/Samsung/mesa-out"}
WBD=${WAYDROID_BUILD_DIR:-"/mnt/Samsung/waydroid-build"}

# ---- T1：不可再生 ----
# 每行 = 相对 $ROOT 的路径，或以 / 开头的绝对路径
T1=(
	"backup/HA2EXB0E-16+512/unique"        # 21 个设备独有分区（EDL 包不含 ⇒ 刷机不恢复）
	"backup/HA2EXB0E-16+512/pre-unlock"    # 解锁前基线取证（Widevine L1 / by-name / getprop）
	"backup/HA2EXB0E-16+512/c0-baseline"   # Android 侧身份/DRM/传感器/分区基线
	"backup/HA2EXB0E-16+512/current-259"   # 1.5.10.259 现场态（by-name/cmdline/getprop/df）
	"backup/HA2EXB0E-16+512/stock"         # U2 降级前原厂 b 槽分区（259）
	"backup/HA2EXB0E-16+512/boot_b-before-vk72-20261009.img"
	"backup/HA2EXB0E-16+512/boot_b-before-vk94-20261011.img"
	"backup/HA2EXB0E-16+512/gpt_main0.bin"
	"backup/HA2EXB0E-16+512/gpt_backup0.bin"
	"backup/HA2EXB0E-16+512/gpt_new_main0.bin"
	"backup/HA2EXB0E-16+512/gpt_new_backup0.bin"
	"backup/HA2EXB0E-16+512/gpt_post-surgery_main0.bin"
	"backup/HA2EXB0E-16+512/gpt_post-surgery_backup0.bin"
	"backup/HA2EXB0E-16+512/sn.img"         # ⚠ 含本机序列号（敏感：只上自己的云盘）
	"backup/HA2EXB0E-16+512/sn-neko-zuxos.img"
	"backup/gpt"                           # 234 GiB 档 GPT 快照（禁跨容量档复用）
	"backup/misc"                          # misc / devinfo / uefivarstore
	"backup/sde-gpt-head.bin"
	"backup/sde-gpt-tail.bin"
	"backup/avf"                           # 从 U1 原厂镜像离线提取（U1 已非 stock ⇒ 删 l2 后不可再取）
	"backup/rawdump.img"                   # sda14 日志型 dump
	"backup/slot-probe"
	"backup/doctor-scripts-wt-20261015"
	"backup/kernel-git-repair-2026-10-08/elden-all-refs-1820.bundle"   # 内核现役线唯一备份
	"backup/kernel-git-repair-2026-10-10/elden-all-refs-pre-boundary.bundle"
	"env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz"          # 过环境栈里程碑 rootfs 归档
	"$L2/lp_tool.py"                       # LP v1.2 dump/extract/splice —— 全项目唯一副本
	"$L2/dump-super.sh"
)

# ---- T2：可重下但代价高 / 源可能失效 ----
T2=(
	"backup/stock-elden"                   # 原厂 kernel/dtbo/vendor_dlkm/DT/dts（从原厂镜像解出）
	"backup/stock-259"                     # 原厂 13 分区备份（云全量包已覆盖，但重取繁琐）
	"backup/fw"                            # 固件子集（EDL 包抽取）
	"backup/dtbo_a.img"
	"y700四代工具"                          # 厂商工具 + 解锁工具箱（第三方源可能失效；含 sn 模板 ⇒ 敏感）
	"$DL"                                  # EDL 全量包（救砖 programmer/loader，版本敏感）
	"$MESA"                                # Waydroid bionic Mesa 交付包（7 M tar.gz + lib64；/mnt/Samsung 将清空）
	"$WBD/out/target/product/waydroid_arm64_only/vendor.img"  # C2/C10 固化态构建产物（86 M；可重编 1–3 h）
)

# ---- T3：会话轨迹（本机独有；可单独上传）----
# 注意：.pi/sessions/ 里含**正在写入**的当前会话 jsonl ⇒ 这一层用【真实拷贝】冻结快照
# （不用硬链接，否则被追加时上传目录里的文件会跟着变、sha256 立刻失效）。
T3=(
	".pi/sessions"                         # pi 原生会话轨迹（含 subagent-artifacts）；SESSIONS/ 只有策展快照
)

rel() { case "$1" in /*) printf '%s' "$1";; *) printf '%s' "$ROOT/$1";; esac; }
staged() { case "$1" in /*) printf '%s' "${1#/}";; *) printf '%s' "$1";; esac; }

# $1=src abs  $2=dest abs  $3=hardlink|copy（默认 hardlink）
link_path() {
	[ -e "$1" ] || { echo "  跳过（不存在）: $1"; return 0; }
	mkdir -p "$(dirname "$2")"
	rm -rf "$2"
	if [ "${3:-hardlink}" = copy ]; then
		cp -a "$1" "$2"
	else
		cp -al "$1" "$2" 2>/dev/null || cp -a "$1" "$2"
	fi
}

print_group() { # $1=label  $2..=paths
	local label=$1; shift
	echo "== $label =="
	local p s
	for p in "$@"; do
		s=$(rel "$p")
		if [ -e "$s" ]; then
			printf '  %-8s %s\n' "$(du -sh "$s" 2>/dev/null | cut -f1)" "$p"
		else
			printf '  %-8s %s  (缺失)\n' '-' "$p"
		fi
	done
}

if [ "$LIST_ONLY" = 1 ]; then
	print_group "T1-irreplaceable" "${T1[@]}"
	print_group "T2-optional-redownloadable" "${T2[@]}"
	print_group "T3-sessions" "${T3[@]}"
	exit 0
fi

rm -rf "$DEST"
mkdir -p "$DEST"
for p in "${T1[@]}"; do link_path "$(rel "$p")" "$DEST/T1-irreplaceable/$(staged "$p")"; done
for p in "${T2[@]}"; do link_path "$(rel "$p")" "$DEST/T2-optional-redownloadable/$(staged "$p")"; done
for p in "${T3[@]}"; do link_path "$(rel "$p")" "$DEST/T3-sessions/$(staged "$p")" copy; done

cat > "$DEST/README.md" <<'README_EOF'
# y700-elden — 云盘备份包（本机独有 / 不可重下的二进制）

上传方式：把整个目录（或它的 tar）丢到自己的云盘即可。`T1`/`T2` 两层是【硬链接】，
与仓库内源文件共享数据块 ⇒ 上传读内容、不额外占盘；`T3-sessions/` 是**真实拷贝**（冻结快照）。

## 分层

| 层 | 内容 | 处置建议 |
|---|---|---|
| `T1-irreplaceable/` | 设备/单元独有（分区 dump、GPT、misc、解锁前取证），以及本机唯一副本（内核 bundle、AVF 提取物、rootfs 归档、现场 boot 镜像） | **无条件上云**：本机之外没有任何副本，坏了就没了 |
| `T2-optional-redownloadable/` | 可重下但代价高 / 源可能失效（原厂厂商资产、EDL 全量包、厂商工具） | 建议一并上云，省将来重下与找源的时间 |
| `T3-sessions/` | pi 原生会话轨迹 `.pi/sessions/`（本机独有；含 subagent 工件） | 可选但建议：这是「怎么走到今天的」全文，`SESSIONS/` 只存策展快照。**注意**：本层是**真实拷贝**（非硬链接），因会话文件在写入中 |

## 校验

`MANIFEST.sha256` 是包内每个文件的 SHA256（相对路径）。校验：

    cd <本目录> && sha256sum -c MANIFEST.sha256

## 不在包内（明确可重下 / 已另有副本）

- `geekidos-linux/` `stock-src/` `Y700-elden-linux/` `edk2-*` `mu_wide_platforms/` `uefi-firmware-backup/`
  —— 上游/自有 fork，可重下（见 `RESOURCES/README.md` §1）。
- `/mnt/Samsung/l2/{super,system_a,system_a.pristine}.img`（47 G）
  —— 云盘**全量线刷包**已覆盖；真要删前另议。
- `/mnt/Samsung/waydroid-build/`（530 G AOSP 树）—— 可 `repo init+sync` 重下；
  其**本地提交**已在两个 USTC 仓（见 RESOURCES §3），**树外本地件**在 `reference/waydroid-buildtree/`（已入库）。
- `/mnt/Samsung/ccache`（166 M）、`fiotest`（4.1 G）—— 缓存/临时文件，可重建可删。
- `out/` `build/` `bootslot-b*/` `logs/` `pkgs*/`
  —— 可由 `patches/` + `scripts/` 重建。

## ⚠ 敏感

`T1-irreplaceable/backup/HA2EXB0E-16+512/sn.img`、`sn-neko-zuxos.img`，以及
`y700四代工具/` 内含的解锁模板文件含**本机序列号**。只放自己的私有云盘，别公开分享。
README_EOF

echo "[pack] 计算 SHA256 中（$(du -sh "$DEST" 2>/dev/null | cut -f1)）..."
( cd "$DEST" && find . -type f ! -name MANIFEST.sha256 -print0 | LC_ALL=C sort -z \
    | xargs -0 sha256sum ) > "$DEST/MANIFEST.sha256"

echo "[pack] 完成: $DEST"
echo "  包内文件 $(find "$DEST" -type f ! -name MANIFEST.sha256 | wc -l) 个"
echo "  逻辑体积 $(du -sh --apparent-size "$DEST" | cut -f1) / 实占 $(du -sh "$DEST" | cut -f1)"
