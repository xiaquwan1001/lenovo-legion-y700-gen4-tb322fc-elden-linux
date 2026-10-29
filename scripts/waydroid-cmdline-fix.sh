#!/bin/bash
# waydroid-cmdline-fix.sh — 让 Waydroid 容器不受宿主 `androidboot.mode=charger` 影响
#
# 为什么（PITFALLS #465，2026-10-29 实测）：
#   宿主**插着 USB** 重启时 `/proc/cmdline` 带 `androidboot.mode=charger`。
#   容器里的 Android `init` 直接读 `/proc/cmdline` ⇒ `ro.bootmode=charger`
#   ⇒ 只跑 `on charger`，不跑 `late-init` ⇒ 没有 vold/zygote/system_server。
#   现象：容器只有 **15 个进程**、`sys.boot_completed` 为空、
#         `dumpsys media.camera` 报 `Can't find service: media.camera`。
#   （极易被误判成「刚换的 vendor.img 坏了」——先查这两个判据再怀疑镜像。）
#
# 做什么：造一份**去掉 `androidboot.mode=` 那一段、其余逐字保留**的 cmdline，
#   放到 `/run/fake-cmdline`，并在 lxc 配置里 bind 覆盖容器内 `/proc/cmdline`。
#   零改镜像、零改内核，容器重启即生效。
#
# 注意：`/run` 是 tmpfs ⇒ **每次重启都要重建**。本脚本幂等，可直接放进
#   `waydroid-cam-restart.sh`（已接线）或开机流程。
#
# 用法：
#   bash scripts/waydroid-cmdline-fix.sh            # 需要时才改（幂等）
#   FORCE=1 bash scripts/waydroid-cmdline-fix.sh    # 无论当前 cmdline 是否含 charger 都装
#   bash scripts/waydroid-cmdline-fix.sh --status   # 只看状态，不改
# 回退：删掉 /var/lib/waydroid/lxc/waydroid/config 里 `elden-l1d` 段（脚本会打印行号）+ 重启容器。
set -u
TAB=${TAB:-root@192.168.7.1}
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 $TAB"
CFG=/var/lib/waydroid/lxc/waydroid/config
FAKE=/run/fake-cmdline
MODE=${1:-fix}

remote=$(cat <<'EOS'
set -u
CFG=/var/lib/waydroid/lxc/waydroid/config
FAKE=/run/fake-cmdline
bootmode() { lxc-attach -P /var/lib/waydroid/lxc -n waydroid -e -- /system/bin/sh -c 'getprop ro.bootmode' 2>/dev/null; }
nproc_()  { lxc-attach -P /var/lib/waydroid/lxc -n waydroid -e -- /system/bin/sh -c 'ps -A | wc -l' 2>/dev/null; }
has_charger=0
grep -q 'androidboot.mode=charger' /proc/cmdline && has_charger=1
has_bind=0
grep -q "$FAKE proc/cmdline" "$CFG" 2>/dev/null && has_bind=1
echo "  宿主 cmdline 含 androidboot.mode=charger : $has_charger"
echo "  lxc 配置已含 $FAKE bind            : $has_bind"
echo "  $FAKE 存在                              : $([ -f $FAKE ] && echo yes || echo no)"
echo "  容器 ro.bootmode=$([ -n "$(bootmode)" ] && bootmode || echo '<容器未起>')  进程数=$([ -n "$(nproc_)" ] && nproc_ || echo -)"
EOS
)

if [ "$MODE" = "--status" ]; then
  echo "== waydroid-cmdline-fix 状态"
  timeout 60 $SSH bash -s <<<"$remote"
  exit 0
fi

timeout 120 $SSH bash -s <<'EOS' 2>&1 | sed 's/^/  /'
set -u
CFG=/var/lib/waydroid/lxc/waydroid/config
FAKE=/run/fake-cmdline
if ! grep -q 'androidboot.mode=charger' /proc/cmdline; then
  echo "宿主 cmdline 不含 androidboot.mode=charger ⇒ 无需处理（容器 init 会走正常 late-init）"
  exit 0
fi
# ① 造 cmdline 副本（去掉 androidboot.mode=* 一段，其余逐字保留）
tr ' ' '\n' < /proc/cmdline | grep -v '^androidboot.mode=' | tr '\n' ' ' > "$FAKE"; echo >> "$FAKE"
chmod 644 "$FAKE"
echo "写出 $FAKE（$(wc -c <"$FAKE") B）：$(grep -c 'androidboot.mode=' "$FAKE" || true) 处 androidboot.mode"
# ② 幂等补 lxc bind（先备份配置一次）
if grep -q "$FAKE proc/cmdline" "$CFG"; then
  echo "lxc 配置已含 bind，跳过"
else
  cp -n "$CFG" "$CFG.bak-cmdlinefix-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
  cat >> "$CFG" <<EOF

# >>> elden-l1d (PITFALLS #465): 宿主以 USB 供电启动时 cmdline 带 androidboot.mode=charger，
# 容器 init 继承 ro.bootmode=charger ⇒ 只跑 on charger、不跑 late-init（无 vold/zygote，卡在 15 进程）。
# 用 bind 覆盖容器内 /proc/cmdline 抹掉该参数（其余参数逐字保留）。/run 是 tmpfs，重启后由
# scripts/waydroid-cmdline-fix.sh 重建。
lxc.mount.entry = $FAKE proc/cmdline none bind,create=file,optional 0 0
# <<< elden-l1d
EOF
  echo "已追加 bind 到 $CFG（第 $(grep -n 'elden-l1d (PITFALLS' "$CFG" | cut -d: -f1) 行起）"
fi
EOS

echo "== 复核"
timeout 60 $SSH bash -s <<<"$remote"
