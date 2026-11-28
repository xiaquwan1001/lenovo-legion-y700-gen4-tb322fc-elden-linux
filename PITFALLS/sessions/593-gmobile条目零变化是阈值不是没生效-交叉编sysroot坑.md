# #754 gmobile 面板条目「装了但零变化」不一定是没生效：phosh 的 corner shift 有 MIN_PADDING=9 逻辑 px 门槛；交叉编用户态件先修 sysroot 默认路径

- 日期：2026-11-28（T34）
- 场景：给 y700-elden 自建 gmobile 显示面板条目（`lenovo,elden.json`，圆角 80 px）后，按「装后 grim 裁图应有内缩」判据验收，结果**装前/装后整屏 sha256 完全相同**。
- 根因（不是没加载）：phosh 0.46 `src/layout-manager.c:get_corner_shift()` 算出 `shift = MAX(PHOSH_TOP_BAR_MIN_PADDING /*9*/, ceil(r - a))`，其中 `r = c = border_radius / fractional_scale`、`b = c - 9.6`、`a = sqrt(c²-b²)`。本机 `wlr-randr` 的 `Scale: 3.000000` ⇒ 80 px 半径换算 `c=26.67` ⇒ `shift=7 < 9` ⇒ 取默认内边距，**像素级零变化是正确结果**。反解阈值：原始半径 `≳95 px` 才开始改变顶栏。
- 判据怎么写：
  - 只看「有没有变化」会误判成失败/假绿。**先用超大值做管线对照**（本次 `border-radius=600` ⇒ 图内首墨 x 27→417），证明资源加载 + 布局消费一路通；再用真值判断「是否需要变化」。
  - 判定「phosh 真的加载了新库」用 inode 对齐：`/proc/<phosh-pid>/maps` 的 gmobile 段与目标文件 inode 相同。
- 交叉编用户态件（同一轮踩到的四个坑，都已修/记）：
  1. `rootfs/build-sysroot.sh` 默认 `SYSROOT=/home/xuqianhui1001/y700-elden/out/sysroot-arm64`（旧用户名，本机不存在）⇒ 已改按仓根推导，并加 `SUITE`/`MIRROR`/`PKGS_ENV` 覆盖口。
  2. `rootfs/cross-aarch64.ini` 写死 `--sysroot=/TB322FC/out/sysroot-arm64`（本机不存在）⇒ 另建 `rootfs/cross-aarch64-gmobile.ini`。
  3. Debian trixie 的 GLib 头**不在** `libglib2.0-dev`（那只是 57 KB 元包，只有 gdb 脚本），实际在 `libgio-2.0-dev`；`gio-2.0.pc` 还会层层要 `libsysprof-capture-4-dev` → `libmount-dev` → `libselinux1-dev`/`uuid-dev` → `libblkid-dev`/`libsepol-dev`。少一个就 `Dependency lookup … found: NO`。
  4. GCC 的 `--sysroot` **不作用于 `-I`**：手写交叉编译命令行时要另设 `PKG_CONFIG_SYSROOT_DIR=<sysroot>`，只设 `PKG_CONFIG_LIBDIR` 会读到宿主 `/usr/include`。
- 复现：`reports/gmobile-t34-build-deploy-20261128.md`（§1 构建 / §3 验收数据 / §4 阈值推导）。
