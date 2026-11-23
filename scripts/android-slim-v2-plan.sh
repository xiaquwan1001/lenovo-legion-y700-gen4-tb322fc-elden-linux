#!/bin/bash
# ★ SUPERSEDED-BY（2026-11-23，D5 批 4 / reports/scripts-hardening-4-20261123.md §2）：**保留 + 本头注，不归档**。
#   后继实现 = `scripts/android-slim-v3-build.sh`（v3 = v2-B 删全集 + 空目录占位 + 布局裁剪 + 重建 ext4 后 e2fsck/round-trip），
#   它才是真正出件的构建器；本件是 **v2 的「只打印不落盘」计划器**，作为 v2 口径的记录与体积活码器仍可只读重跑。
#   为何不删：`DEVICE/README.md:288` 与 `TASKS/sessions/*` 仍把它当作「需用户确认的 apply 类清单」范例引用
#   （devices 默认 dry-run 口径的标杆），归档会让那些指针变悬挂。新工作请直接用 v3。
#
# android-slim-v2-plan.sh — 「安卓干净瘦身 v2」计划器（主机侧；默认只打印，不写任何东西）
#
# 背景：v1（out/android-min-20261118/new/system_a.img，5.0 GiB，已上机两发 boot_completed=1）
#       只删了 3 棵子树（/system/preinstall、/system/etc/AI、/system/etc/bgmusic），
#       但 /system/etc/launcher.db 里 47 条默认布局仍指向池里的包 ⇒ 恢复出厂后桌面全是占位图标。
#       v2 = 删的内容更明确 + 把「占位来源」一起处理（布局裁剪 + 空目录占位）。
# 依据：reports/android-slim-v2-20261119.md（本轮）；reports/android-min-avb-facts-20261118.md（AVB 边界）
#
# 用法：
#   scripts/android-slim-v2-plan.sh --variant A          # 默认 dry-run：打印清单/体积/命令
#   scripts/android-slim-v2-plan.sh --variant B --apply  # 只打印「需 root / 需设备」的命令，不执行
#
# 变体：
#   A = 保 ZUI 自有池应用（图库/便签/天气/闹钟/日历/录音机/换机/计算器），删第三方池
#   B = 池全删（体积最小）
#
# 只读输入（脚本绝不修改）：
#   SRC_SYSTEM=out/android-min-avb-20261118/parts/system_a.img     原厂 system_a（11.43 GiB）
#   V1_SYSTEM =out/android-min-20261118/new/system_a.img           v1 已上机件（5.0 GiB）
#   SUPER_V1  =out/android-min-20261118/pkg/super_min.img          v1 super（8481.5 MiB）
# 产物（--apply 只打印命令，由主代理执行）：
#   WORK=out/android-slim-v2-20261119/work   NEW=out/android-slim-v2-20261119/new
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC_SYSTEM=${SRC_SYSTEM:-$ROOT/out/android-min-avb-20261118/parts/system_a.img}
V1_SYSTEM=${V1_SYSTEM:-$ROOT/out/android-min-20261118/new/system_a.img}
SUPER_V1=${SUPER_V1:-$ROOT/out/android-min-20261118/pkg/super_min.img}
WORK=${WORK:-$ROOT/out/android-slim-v2-20261119/work}
NEW=${NEW:-$ROOT/out/android-slim-v2-20261119/new}
PARTS=${PARTS:-$ROOT/out/android-min-avb-20261118/parts}
LANE=$ROOT/out/android-slim-v2-20261119
MKFS_FEATURES="-O ^has_journal,^resize_inode,extent,ext_attr,dir_index,filetype,sparse_super,large_file,huge_file,uninit_bg,dir_nlink,extra_isize -I 256 -m 0"
VARIANT=A
APPLY=0

while [ $# -gt 0 ]; do case "$1" in
	--variant) VARIANT=${2:?}; shift 2 ;;
	--apply) APPLY=1; shift ;;
	--dry-run) APPLY=0; shift ;;
	-h|--help) sed -n '2,26p' "$0"; exit 0 ;;
	*) echo "未知参数 $1" >&2; exit 2 ;;
esac; done
case "$VARIANT" in A|B) ;; *) echo "--variant 只接受 A 或 B" >&2; exit 2 ;; esac

say() { printf '%s\n' "$*"; }
hr() { printf '%s\n' "----------------------------------------------------------------------"; }

for f in "$SRC_SYSTEM" "$V1_SYSTEM" "$SUPER_V1"; do
	[ -f "$f" ] || { echo "缺输入 $f" >&2; exit 1; }
done

# ---- 1. 体积核算（用 debugfs 只读清点，不 mount）---------------------------
hr; say "1. 体积核算（判据：debugfs 清点，非估算）"
SIZING=$(python3 - "$SRC_SYSTEM" "$V1_SYSTEM" "$VARIANT" "$ROOT" <<'PY'
import os, re, subprocess, sys, math
src, v1, variant, root = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
tmp = os.path.join(root, "out/android-slim-v2-20261119/.sizing.tsv")
subprocess.run([sys.executable, os.path.join(root, "scripts/android-img-lswalk.py"),
                "--img", src, "--root", "/system", "--out", tmp, "--jobs", "16",
                "--max-depth", "10"], check=True, capture_output=True)

# 删除清单：路径前缀（相对镜像根 /system）
DROP_COMMON = ["system/preinstall", "system/etc/AI", "system/etc/bgmusic",
               "system/media/bootanimation_mcdonalds.zip",
               "system/media/shutdownanimation_mcdonalds.zip"]
# A 变体保留的 ZUI 自有池项（池目录名前缀）
ZUI_KEEP = ("ZuiGallery", "ZuiNotes", "ZuiWeather", "ZuiAlarm", "XuiCalendar",
            "XuiRecorder", "ZuiClone", "XuiCalculator")

drop_pref = list(DROP_COMMON)
kept_pool = 0
if variant == "A":
    # A：只删池里的第三方；ZUI 自有项保留 → 用一个「反向前缀」清单表达
    pool_keep = ZUI_KEEP

files = {}
for ln in open(tmp):
    t, mode, uid, gid, size, path = ln.rstrip("\n").split("\t")
    if t != "F":
        continue
    rel = path.lstrip("/")
    files[rel] = int(size)

def under(rel, pref):
    return rel == pref or rel.startswith(pref.rstrip("/") + "/")

drop = 0
keep = 0
for rel, size in files.items():
    # system/preinstall 的细分处理
    if under(rel, "system/preinstall/"):
        m = re.match(r"^system/preinstall/([^/]+)/", rel)
        d = m.group(1) if m else ""
        if variant == "A" and d.startswith(ZUI_KEEP):
            keep += size
            continue
        drop += size
        continue
    if any(under(rel, p) for p in DROP_COMMON):
        drop += size
        continue
    keep += size

MiB = 1024 * 1024
def r16(n):  # 向上取整到 16 MiB
    return int(math.ceil(n / 16.0) * 16)

mkfs_mib = r16((keep * 1.064) / MiB) if keep else 0
# super 里其它逻辑分区按 v1 实测值（MiB）
others = {"vendor_a": 1466, "product_a": 993, "system_ext_a": 571,
          "vendor_dlkm_a": 141, "system_dlkm_a": 12, "odm_a": 2}
super_mib = r16(sum(others.values()) + mkfs_mib + 1)  # +1 MiB 元数据
v1_files = sum(1 for _ in open(os.path.join(root, "out/android-slim-v2-20261119/ls-system-v1.tsv")))
print("文件条目        %d" % len(files))
print("DROP 逻辑字节   %.2f MiB" % (drop / MiB))
print("KEEP 逻辑字节   %.2f MiB" % (keep / MiB))
print("预计 system.img %d MiB (%.2f GiB)" % (mkfs_mib, mkfs_mib / 1024))
print("预计 super      %d MiB (%.2f GiB)" % (super_mib, super_mib / 1024))
print("v1 super        %d MiB (%.2f GiB)" % (8481, 8481 / 1024))
print("EDL 写盘预估    %.1f min @42.2 MiB/s" % (super_mib / 42.2 / 60))
PY
)
[ $? -eq 0 ] || { echo "体积核算失败" >&2; exit 1; }
printf '%s\n' "$SIZING"
MKFS_MIB=$(printf '%s\n' "$SIZING" | awk '/预计 system.img/{print $3}')
SUPER_MIB=$(printf '%s\n' "$SIZING" | awk '/预计 super/{print $3}')

# ---- 2. 清单 ---------------------------------------------------------------
hr; say "2. 删除 / 保留清单（变体 $VARIANT）"
say "删：system/preinstall/*（B 全删；A 只删第三方，保留 $( [ $VARIANT = A ] && echo 'ZuiGallery/ZuiNotes/ZuiWeather/ZuiAlarm/XuiCalendar*/XuiRecorder/ZuiClone/XuiCalculator' || echo '无')）"
say "删：system/etc/AI（qwen 权重 3209.5 MiB）、system/etc/bgmusic（209.1 MiB）"
say "删：system/media/{boot,shutdown}animation_mcdonalds.zip（23.7 MiB，libbootanimation.so 的候选路径回退链，最大损失=零售主题动画）"
say "改：system/etc/launcher.db 与 launcher_2layer.db —— 按清单删被删包的 favorites 行（现成件：launcher.db.v2A/.v2B）"
say "加：空目录 system/preinstall 与 system/etc/AI（0 字节，避免调用方 File#list() 得到 null）"
say "不动：system/etc/selinux、system/etc/permissions、system/etc/init、framework、apex、oat/vdex"

# ---- 3. 需 root / 需设备的命令（--apply 只打印）----------------------------
hr; say "3. 执行命令（$([ $APPLY = 1 ] && echo '需 root / 需设备：请主代理逐条执行' || echo 'dry-run：仅打印'))"
DROP_PKGS=$LANE/drop-pkgs-$VARIANT.txt
cat > "$DROP_PKGS" <<'EOF'
# 第三方池包（A/B 共同删除）
com.ss.android.ugc.aweme
com.lemon.lv
com.netease.cloudmusic
com.baidu.netdisk
cn.wps.moffice_eng
com.sina.weibo
cn.emagsoftware.gamehall
com.bilibili.comic
cn.canva.editor
com.photosir.flashpaint
com.qihoo.aiwork
net.huanci.hsjpro
com.newskyer.draw
com.lenovo.nceetj.educenterhd
com.lenovo.legionzone
com.lenovo.club.app
com.motorola.mobiledesktop
com.youku.phone
com.qiyi.video.pad
com.smile.gifmaker
com.lenovo.minigamelauncher
com.lenovo.xbb
com.sohu.inputmethod.sogou
EOF
if [ "$VARIANT" = B ]; then cat >> "$DROP_PKGS" <<'EOF'
# ZUI 自有池应用（仅 B 删）
com.zui.gallery
com.zui.notes
com.zui.weather
com.zui.deskclock
com.zui.calendar
com.zui.recorder
com.zui.clone
com.zui.calculator
EOF
fi
say "# 已写出包清单：$DROP_PKGS（$(grep -c '^com\|^cn\|^net' "$DROP_PKGS") 条）"
hr
cat <<CMDS
# 3.1 解出原厂 system（需 root：loop 只读挂载 + rsync 保 xattr/caps）
sudo mkdir -p $WORK
sudo mount -o loop,ro $SRC_SYSTEM $WORK/.mnt-system
sudo mkdir -p $WORK/system_v2
sudo rsync -aHAX --numeric-ids --delete $WORK/.mnt-system/ $WORK/system_v2/
sudo umount $WORK/.mnt-system && sudo rmdir $WORK/.mnt-system

# 3.2 删（逐条，便于回看）
sudo rm -rf $WORK/system_v2/preinstall              # A 变体：只删下面的第三方子目录，保留 ZUI 自有项
CMDS
if [ "$VARIANT" = A ]; then
	say "sudo sh -c 'cd $WORK/system_v2/preinstall && ls -d */ | grep -v -E \"$(echo 'ZuiGallery|ZuiNotes|ZuiWeather|ZuiAlarm|XuiCalendar|XuiRecorder|ZuiClone|XuiCalculator')\" | xargs rm -rf'"
fi
cat <<CMDS
sudo rm -rf $WORK/system_v2/etc/AI $WORK/system_v2/etc/bgmusic
sudo rm -f  $WORK/system_v2/media/bootanimation_mcdonalds.zip \\
            $WORK/system_v2/media/shutdownanimation_mcdonalds.zip

# 3.3 空目录占位（0 字节；让 File#list() 返回空数组而不是 null）
sudo mkdir -p $WORK/system_v2/preinstall $WORK/system_v2/etc/AI
sudo chown root:root $WORK/system_v2/preinstall $WORK/system_v2/etc/AI
sudo chmod 755 $WORK/system_v2/preinstall $WORK/system_v2/etc/AI
# restatcon 由设备侧 init 的 restorecon_recursive 处理；如需预置：
sudo setfattr -n security.selinux -v u:object_r:system_file:s0 $WORK/system_v2/preinstall 2>/dev/null || true

# 3.4 桌面布局裁剪（同一份清单；现成件见 $LANE/launcher.db.v2$VARIANT）
python3 $ROOT/scripts/android-launcher-db-trim.py --db $WORK/system_v2/etc/launcher.db \\
        --drop-pkgs $DROP_PKGS --out $WORK/system_v2/etc/launcher.db.new
python3 $ROOT/scripts/android-launcher-db-trim.py --db $WORK/system_v2/etc/launcher_2layer.db \\
        --drop-pkgs $DROP_PKGS --out $WORK/system_v2/etc/launcher_2layer.db.new
sudo mv $WORK/system_v2/etc/launcher.db.new        $WORK/system_v2/etc/launcher.db
sudo mv $WORK/system_v2/etc/launcher_2layer.db.new $WORK/system_v2/etc/launcher_2layer.db
sudo chown root:root $WORK/system_v2/etc/launcher.db $WORK/system_v2/etc/launcher_2layer.db
sudo chmod 644       $WORK/system_v2/etc/launcher.db $WORK/system_v2/etc/launcher_2layer.db

# 3.5 重建 ext4（体积见 §1）
sudo mkdir -p $NEW
sudo mke2fs -q -t ext4 -b 4096 $MKFS_FEATURES -L system -d $WORK/system_v2 $NEW/system_a.img ${MKFS_MIB}M
sudo e2fsck -fn $NEW/system_a.img && echo "e2fsck clean"

# 3.6 重打 super（system 换新；其余六个分区沿用原厂 ext4 件与 v1 的尺寸，单位 MiB）
#     尺寸取自 v1 super 实测（= 各 .img 文件大小向上取整到 MiB），改别的分区必须同步改这里。
~/bin/lpmake --device-size=23622320128 --metadata-size=65536 --metadata-slots=3 \\
    --super-name=super --block-size=4096 --alignment=524288 --alignment-offset=491520 \\
    --group=qti_dynamic_partitions_a:23618125824 \\
    --partition=system_a:readonly:${MKFS_MIB}M:qti_dynamic_partitions_a \\
    --partition=vendor_a:readonly:1466M:qti_dynamic_partitions_a \\
    --partition=product_a:readonly:993M:qti_dynamic_partitions_a \\
    --partition=system_ext_a:readonly:571M:qti_dynamic_partitions_a \\
    --partition=vendor_dlkm_a:readonly:141M:qti_dynamic_partitions_a \\
    --partition=system_dlkm_a:readonly:12M:qti_dynamic_partitions_a \\
    --partition=odm_a:readonly:2M:qti_dynamic_partitions_a \\
    --image=system_a=$NEW/system_a.img \\
    --image=vendor_a=$PARTS/vendor_a.img \\
    --image=product_a=$PARTS/product_a.img \\
    --image=system_ext_a=$PARTS/system_ext_a.img \\
    --image=vendor_dlkm_a=$PARTS/vendor_dlkm_a.img \\
    --image=system_dlkm_a=$PARTS/system_dlkm_a.img \\
    --image=odm_a=$PARTS/odm_a.img \\
    -o $NEW/super_min_v2.img
# 自检（三份 metadata 必须都能读、分区表与上一步一致）
for slot in 0 1 2; do python3 $ROOT/scripts/android-super.py list $NEW/super_min_v2.img --slot \$slot | head -20; done
cmp <(python3 $ROOT/scripts/android-super.py list $NEW/super_min_v2.img --slot 0 | grep -E '^(system|vendor|product|system_ext|odm)') \\
    <(python3 $ROOT/scripts/android-super.py list $NEW/super_min_v2.img --slot 1 | grep -E '^(system|vendor|product|system_ext|odm)') \\
    && echo "slot0 == slot1 分区表一致"
sha256sum $NEW/super_min_v2.img $NEW/system_a.img

# 3.7 设备侧（每发耗 ~$((SUPER_MIB/42/60+1)) min；命令拆单条）
#   qdl write 0 90504 $NEW/super_min_v2.img   （EDL；同一发内不要夹别的写）
#   qdl read 0 90504 <len> /tmp/rb.img ；sha256sum 对比（第二把尺子）
#   fastboot -w                             # 只擦 userdata+metadata，别再做 recovery factory reset
#   fastboot reboot
#   adb wait-for-device shell getprop sys.boot_completed   # 期望 1；同时看 dumpsys window | grep -i EnableScreen
CMDS

hr; say "4. AVB 影响（不改 vbmeta 即可）"
say "system_a 的 hashtree 描述符在 vbmeta_system_a（原厂指向 12,079,427,584 B 的 system）；"
say "现役 vbmeta_a 是自签 Flags=1（HASHTREE_DISABLED）+ 设备 veritymode=disabled，ABL 在 orange 态不执行校验 ⇒"
say "换 system 尺寸不需要重签；反过来，若将来要回绿灯，必须 avbtool add_hashtree_footer 按新尺寸重算 vbmeta_system_a。"
hr; say "5. 回退"
say "v1 件：$SUPER_V1（sha256 e3d0d26f…，已上机两次 boot_completed=1）→ EDL 写回 90504 即回 v1"
say "原厂件：backup/official-rom-15.10.259/super_*.img（15.6 GB，重刷 ~20 min，11-17 已走通）"
say "GPT 双表：backup/HA2EXB0E-16+512/edl-20261118/gpt{0,4}-{primary,backup}.bin"
say "boot/vbmeta_a 原件：out/android-min-20261118/pkg/vbmeta_a.img（原厂 Flags=0）"
exit 0
