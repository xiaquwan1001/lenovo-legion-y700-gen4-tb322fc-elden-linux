# #730 Debian 交叉打包脚本用**相对** `--sysroot` 会假报「pkg-config 找不到库」

## 现场（2026-11-26 晨，droidloom deb 化 lane 收尾）

`packaging/debian/build.sh` 交叉构建 arm64 时，按 `cross-arm64.sh` 的提示传**相对**路径：

```
packaging/debian/build.sh --arch arm64 --sysroot packaging/debian/.work/arm64/sysroot
```

报错（节选）：

```
pkg-config exited with status code 1
> PKG_CONFIG_LIBDIR=packaging/debian/.work/arm64/sysroot/usr/lib/aarch64-linux-gnu/pkgconfig:...
  PKG_CONFIG_SYSROOT_DIR=packaging/debian/.work/arm64/sysroot ...
  pkg-config --libs --cflags wayland-server
  Package wayland-server was not found in the pkg-config search path.
```

`ls` 该 `.pc` 明明存在。

## 真因

`PKG_CONFIG_LIBDIR` 与 `PKG_CONFIG_SYSROOT_DIR` 都是**相对路径**，而 `cargo build` 的 cwd 是 **Droidloom 源码仓**
（这里 `~/src/droidloom`，由 `--source`/`DROIDLOOM_SOURCE` 决定），不是脚本所在目录 ⇒ pkg-config 从错误的
基准目录找 `.pc`。同理 `RUSTFLAGS` 里的 `-L native=`、`link-arg=-Wl,-rpath-link=` 也一起错。

## 处置

`build.sh` 在 `stage_runtime_from_source` 的交叉分支里把 sysroot 归一化成绝对路径
（`sysroot=$(cd "$sysroot" && pwd)`），此后相对/绝对写法都成立。commit 与 deb 的 sha 见同轮提交。

## 判据

- 反例可复现：改前传相对路径 ⇒ 上面那段 pkg-config 报错；改后同命令 `Finished release profile` 且产出
  `droidloom-runtime_*.deb`。
- 同类脚本通用判据：**任何交给 Rust/cargo 子进程的环境变量（`PKG_CONFIG_*`、`CFLAGS_*`、`RUSTFLAGS`）都要先绝对化**，
  因为 cargo 的 cwd 是 workspace 根而不是调用者 cwd。
