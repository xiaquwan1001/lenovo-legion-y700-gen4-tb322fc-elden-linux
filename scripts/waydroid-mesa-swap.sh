#!/bin/bash
# waydroid-mesa-swap.sh — 在 Y700 设备上把新编的 Mesa/gralloc 库 bind-mount 进 Waydroid 容器
#
# 用法（设备上 root 执行）：
#   bash waydroid-mesa-swap.sh install [<含 lib64/ 的目录>]   # 默认 /root/wd/mesa-new
#   bash waydroid-mesa-swap.sh rollback                        # 撤销，恢复原状
#   bash waydroid-mesa-swap.sh status                          # 看当前状态
#
# 设计：
#   * 只读容器 rootfs 用 bind-mount 覆盖，不改动原镜像 → 随时可回退
#   * 会**移除旧 libgallium_dri.so 的 8 字节 chip-id 补丁**（那个补丁会破坏新库）
#   * config_nodes 用标记块管理，幂等
set -euo pipefail

ROOTFS=/var/lib/waydroid/rootfs
VENDOR_LIB="$ROOTFS/vendor/lib64"
NODES=/var/lib/waydroid/lxc/waydroid/config_nodes
STAGE=/root/wd/mesa                 # 新库落点（持久）
MARK_BEGIN="# >>> waydroid-mesa-swap BEGIN"
MARK_END="# <<< waydroid-mesa-swap END"

log()  { echo -e "\033[1;36m[swap]\033[0m $*"; }
warn() { echo -e "\033[1;33m[swap] ⚠️  $*\033[0m"; }
die()  { echo -e "\033[1;31m[swap] ❌ $*\033[0m" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "需要 root"
[ -f "$NODES" ] || die "找不到 $NODES（Waydroid 没初始化？）"

# 库 → 容器内相对路径（与设备现有 vendor 布局一致）
REL_FILES=(
  lib64/libgallium_dri.so
  lib64/libgbm_mesa.so
  lib64/dri_gbm.so
  lib64/libgbm_mesa_wrapper.so
  lib64/egl/libEGL_mesa.so
  lib64/egl/libGLESv1_CM_mesa.so
  lib64/egl/libGLESv2_mesa.so
  lib64/egl/libGLES_mesa.so
  lib64/hw/vulkan.freedreno.so
  lib64/hw/gralloc.minigbm_gbm_mesa.so
  lib64/hw/gralloc.gbm.so
)

strip_block() {
  [ -f "$NODES" ] || return 0
  sed -i "\|$MARK_BEGIN|,\|$MARK_END|d" "$NODES"
}

remove_stale_patch_entry() {
  # 去掉任何指向 libgallium_dri.so 的旧 bind-mount（含打了 8 字节补丁那条）
  sed -i '\|lxc.mount.entry = .*libgallium_dri\.so.*none bind|d' "$NODES" || true
}

cmd_status() {
  echo "== config_nodes 里的 mesa-swap 块 =="
  grep -n "waydroid-mesa-swap\|libgallium_dri.so" "$NODES" 2>/dev/null || echo "(无)"
  echo
  echo "== 当前容器 Mesa =="
  if [ -f "$VENDOR_LIB/libgallium_dri.so" ]; then
    ls -l "$VENDOR_LIB/libgallium_dri.so"
    # 26.0.8 的打补丁文件在 0x1f7bf90 处被改成 0xffff44050000；原版该处是 0x44050000
    if [ -f /root/wd/libgallium_dri.so ]; then
      warn "存在旧的 /root/wd/libgallium_dri.so（8 字节补丁残留）→ 会污染新库，install 时会处理"
    fi
  fi
  echo
  echo "== 落点 ==";  ls -lR "$STAGE" 2>/dev/null || echo "(尚未安装)"
}

cmd_rollback() {
  log "撤销 mesa-swap…"
  strip_block
  remove_stale_patch_entry
  mv -f "$STAGE" "/root/wd/mesa.removed.$(date +%s)" 2>/dev/null || true
  if [ -f /root/wd/libgallium_dri.so ]; then
    mv -f /root/wd/libgallium_dri.so "/root/wd/libgallium_dri.so.patched.$(date +%s)"
  fi
  log "已移除 bind-mount 与新库。重启容器生效："
  echo "    waydroid container restart   # 或 stop && start"
  log "（容器 vendor 库回到镜像原版 Mesa 26.0.8）"
}

cmd_install() {
  local src="${1:-/root/wd/mesa-new}"
  [ -d "$src/lib64" ] || die "源目录里没有 lib64/: $src"
  [ -f "$src/lib64/libgallium_dri.so" ] || die "$src/lib64/libgallium_dri.so 缺失"

  # 版本提示
  [ -f "$src/VERSION.txt" ] && cat "$src/VERSION.txt"

  log "备份 config_nodes"
  cp -a "$NODES" "$NODES.bak-$(date +%s)"

  log "安装新库到 $STAGE"
  rm -rf "$STAGE"; mkdir -p "$STAGE"
  cp -a "$src/lib64" "$STAGE/lib64"
  [ -f "$src/VERSION.txt" ] && cp -a "$src/VERSION.txt" "$STAGE/"
  [ -f "$src/manifest.txt" ] && cp -a "$src/manifest.txt" "$STAGE/"

  strip_block
  remove_stale_patch_entry

  log "写 bind-mount 条目"
  {
    echo "$MARK_BEGIN"
    for rel in "${REL_FILES[@]}"; do
      [ -f "$STAGE/$rel" ] || continue
      # 容器内目标路径（无前导 /，相对 rootfs）
      echo "lxc.mount.entry = $STAGE/$rel vendor/$rel none bind,create=file,optional 0 0"
    done
    echo "$MARK_END"
  } >> "$NODES"

  # 确保 /dev/dri/card0 也在（Waydroid 默认只放 renderD128）
  if ! grep -q 'dev/dri/card0' "$NODES"; then
    warn "config_nodes 缺 /dev/dri/card0，补上"
    echo "lxc.mount.entry = /dev/dri/card0 dev/dri/card0 none bind,create=file,optional 0 0" >> "$NODES"
  fi

  log "完成 ✅ 已装 $(ls "$STAGE/lib64" -R | grep -c '\.so$') 个库"
  echo
  echo "下一步（在 Phosh 会话里重启容器/会话）："
  echo "    waydroid container restart"
  echo "    # 会话按你现有方式重起，然后 waydroid show-full-ui"
  echo
  echo "验证："
  echo "    cat /var/lib/waydroid/rootfs/vendor/lib64/libgallium_dri.so | strings | grep -a 'Mesa 26'"
  echo "    logcat -b crash | grep -i 'output buffer not gpu writeable'   # 应消失"
  echo "    dmesg | grep -i hangcheck                                    # 应无 gpu lockup"
  echo
  echo "回退： bash $0 rollback"
}

case "${1:-status}" in
  install)  shift; cmd_install "$@";;
  rollback) cmd_rollback;;
  status)   cmd_status;;
  *) die "用法: $0 {install [dir] | rollback | status}";;
esac
