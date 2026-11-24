# osk-stub 重编配方（**必须全部打上**，漏一枚会静默丢功能）

> 2026-11-24 实测事故：做「RIME 候选条常显」时只乘了 `rime/0003`、`0004`、`0005`，
> **漏了 `haptic/0001` 与 `layout/0002`** ⇒ 装上去的件里 `strings … | grep -c ELDEN_OSK_HAPTIC` = 0、
> 每键震动**悄无声息地没了**（用户先发现「震动之前已经做了」）。这正是 `scripts/ime-single-stack.sh`
> C8 这条判据的由来：**装机件里必须能 grep 到钩子字符串**，只看"进程在跑/键盘能弹"是查不出来的。

## 补丁清单（顺序固定，后面叠前面）

| # | 文件 | 作用 |
|---|---|---|
| 1 | `rime/0003-osk-stub-rime-completer-wiring.patch` | B 案 RIME completer 接线（manager/meson/gschema/gresource + completer 本体） |
| 2 | `rime/0004-osk-stub-rime-userdir-fallback.patch` | 空 `Completers.Rime user-data` ⇒ 退化到 `$XDG_DATA_HOME/rime` 并自建（PITFALLS #713） |
| 3 | `rime/0005-osk-stub-rime-completer-always-active.patch` | 自组词 completer（name=`rime`）恒活跃 ⇒ 候选条常显（`PITFALLS #709` 的 11-24 更新） |
| 4 | `haptic/0001-osk-stub-keypress-haptic-hook.patch` | 每键 `ffrumble`（`ELDEN_OSK_HAPTIC_DEV` 未设 = 上游行为） |
| 5 | `layout/0002-osk-stub-terminal-arrows.patch` | terminal 布局方向键 + Home/End |

`0004`/`0003` 都能 `git apply`/`patch -p1`；`haptic`/`layout` 若报
`Reversed (or previously applied)` = 树里已有，**不是失败**（用 `--dry-run` 先看）。

## 构建（宿主 aarch64 交叉；本机 sysroot 现成）

```sh
P=/home/xuqianhui/y700-elden/patches-userland/zh-ime-rime-20261123
SRC=/tmp/osks/phosh-osk-stub-0.46.0           # 上游 0.46.0 原树
W=/tmp/osk-src; B=/tmp/osk-build
rm -rf "$W" "$B"; cp -a "$SRC" "$W"; cd "$W"
for p in $P/rime/0003-*.patch $P/rime/0004-*.patch $P/rime/0005-*.patch \
         $P/haptic/0001-*.patch $P/layout/0002-*.patch; do
  patch -p1 -N < "$p" || echo "!! 检查 $p（Reversed = 已打过）"
done
export PKG_CONFIG_LIBDIR=/tmp/trixie-sysroot/root/usr/lib/aarch64-linux-gnu/pkgconfig:/tmp/trixie-sysroot/root/usr/share/pkgconfig
export PKG_CONFIG_SYSROOT_DIR=/tmp/trixie-sysroot/root
build-slot take y700-elden:osk --jobs 8
meson setup "$B" --cross-file /tmp/trixie-sysroot/cross.txt -Drime=true -Dman=false -Dgtk_doc=false -Dtests=false
ninja -C "$B"
build-slot drop <id>
```

## 出厂自检（**装之前**跑，别等用户发现）

```sh
strings "$B/src/phosh-osk-stub" | grep -c ELDEN_OSK_HAPTIC        # 必须 = 3
strings "$B/src/phosh-osk-stub" | grep -c -E 'Rime|librime'       # >0
ldd "$B/src/phosh-osk-stub" | grep -c librime                     # >=1
```

## 部署（divert 已在位；PITFALLS #654）

```sh
scp "$B/src/phosh-osk-stub" root@192.168.7.1:/tmp/osk-new
ssh root@192.168.7.1 'install -m755 /tmp/osk-new /usr/bin/phosh-osk-stub && pkill -x phosh-osk-stub'
# phosh 会按需重拉；或手动 su -l xuqianhui1001 -c '… /usr/bin/phosh-osk-stub &'
scripts/ime-single-stack.sh        # C1–C8 全绿；C8 = 震动在位
```

回退件：`/root/osk-stub-backup-20261124`（sha256 `cde21b9c…`，2026-11-24 之前的在机件）。
