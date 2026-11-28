# 交叉编 sysroot vs podman：长期手动管理负担评估（2026-11-28，用户提问）

> 触发：用户问「上一个会话提出编译可以用 chroot 而不用 podman，长期建设时手动管理会不会增加负担」；
> 补充事实：**用户已自行装好 podman（5.7.0）备用，可以不用**。
> 前一份同类评估 = `reports/build-env-podman-eval-20261128.md`（结论 = 不装；本文不重复其四类活判定，只补「长期维护成本」这一维）。

## 0. 结论（三句）

1. **日常路径不用 podman**：本仓现在真正需要的构建形态是「主机交叉编 + arm64 sysroot」，今天 phoc 0.46 就是零 root、零容器编出来的；容器在这条路径上**只增加一层，不减少任何手工步骤**。
2. **手动管理的负担是真的，但来源不是「没容器」**，而是三件本可以机械化的东西：依赖清单散在多个脚本里、`scripts/sysroot-add-debs.sh` 仍要 root、trixie sysroot 的包版本只隐含在 deb 缓存里。三步修法（§4）约 2–3 h，比引入 podman 便宜，且修完**任何 lane（含子代理）都能自己加依赖**。
3. **podman 保留为「rootless 版 chroot」**（不是「构建隔离层」）：当某活必须**运行** arm64 发行版用户态（`configure`/测试套件/apt 操作）而又不想 sudo 时，`podman import /opt/elden/arm64-trixie` 是最短路径。触发条件见 §5。

## 1. 现查事实（可复核）

| 项 | 值 | 命令 |
|---|---|---|
| podman | **已装 5.7.0**（用户 2026-11-28 自装，备用） | `podman --version` |
| 现有 chroot | `/opt/elden/arm64-trixie` **1.6 GB**、`/opt/elden/arm64-sid` **3.0 GB**，root 属主 ⇒ `chroot(2)` 必须 root | `du -sh /opt/elden/arm64-*` |
| 现有 sysroot | `out/sysroot-trixie-arm64` **912 MB**，用户属主；内含 `debs/` 缓存 **25 个 deb / 14 MB** | `du -sh out/sysroot-trixie-arm64{,/debs}` |
| sysroot 构建器 | **两套**：`rootfs/build-sysroot.sh`（**零 root**，apt 用 `-o Dir=` 覆盖后 `dpkg-deb -x`）/ `scripts/sysroot-add-debs.sh`（**要 root**，走 chroot `apt-get download`） | `sed -n 1,20p` 两脚本 |
| cross file | 3 个：`rootfs/cross-aarch64{,-gmobile,-phoc}.ini` | `ls rootfs/*.ini` |
| 今天的数据点 | T34 gmobile、T45 phoc 两个设备件**都已零容器**产出；phoc 交叉编 **672 432 B**、NEEDED 与 chroot 版逐项一致 | `out/phoc-cross-20261128/meta.txt` |

## 2. 逐项负担对比（长期维护视角）

| 维度 | 交叉编 sysroot（现状） | podman（rootless，假设） | 谁更省 |
|---|---|---|---|
| 加一个新依赖 | 改包表 → 重跑构建器（**实测 3 包 5.5 s**，§3）；但**当前要 root**（走 chroot 那条） | 改 Containerfile → 重建层（几分钟，含 apt update） | sysroot（前提：§4 去 root） |
| 依赖清单 SSOT | **散**：`rootfs/build-sysroot.sh` 内嵌表 + `scripts/sysroot-add-droidloom-deps.sh` + `build-phoc-cross.sh` 头注 | Containerfile 天然一份 | podman 略胜 ⇒ 用 `sysroot-trixie.pkgs`（rootfs/ 下，待建） 补齐即可打平 |
| 版本可追溯 | 隐含在 `sysroot/debs/*.deb` 文件名（**可复原**，见 §3） | 镜像 digest / 层 | 平（sysroot 补 lock 文件即等值） |
| 从零重建 | `build-sysroot.sh` + 包表（**零 root**）；不需重建 chroot | `podman build`（需先有基础镜像/QEMU binfmt） | sysroot |
| 权限 | 加依赖要 sudo ⇒ **子代理被堵**（今天两条 lane 就是这么卡的） | rootless 本来就不 sudo | podman 胜 ⇒ §4 去掉 root 后拉平 |
| 跑 arm64 二进制 | sysroot 里的工具经已注册的 `qemu-aarch64` binfmt 直接跑（py 侧 `needs_exe_wrapper`）| 同样要 binfmt；`podman run --arch arm64` 免 root | podman 略胜（但只在「要跑整套用户态」时才有差） |
| 隔离 | 无（同一用户，写坏 sysroot 就是写坏） | 有（层 + 挂载命名空间） | podman（本仓无不可信构建源，价值低） |
| 排障/透明 | 目录直接看，`objdump -p` 即验 | 多 storage driver / `fuse-overlayfs` / `podman unshare` 属主坑 | sysroot |
| 磁盘 | 0.9 GB（+ 可删的 4.6 GB chroot） | 基础镜像 ~1.5 GB + 层 | 平 |

**一句话**：容器赢在「清单即文件 + 天然免 root」，但这两点 sysroot 用 3 个文件就能做到；容器输在「又多一层要排障的东西，且完全不解决手工步骤」。

## 3. 实测：trixie sysroot 扩依赖**已经可以零 root**（5.5 s）

`rootfs/build-sysroot.sh` 走的是 apt 的 `-o Dir=<sysroot>/.apt` 覆盖（不 chroot、不 sudo），今天用它给 trixie 加三个 phoc 依赖：

```sh
SUITE=trixie MIRROR=http://deb.debian.org/debian \
PKGS_ENV="libgmobile-dev libgnome-desktop-3-dev libwlroots-0.18-dev" \
SYSROOT=/tmp/sysroot-probe bash rootfs/build-sysroot.sh
```

结果（真实运行，2026-11-28）：

```
== downloading 3 packages
downloaded: 3
== unpacking into sysroot
157M	/tmp/sysroot-probe
real    0m5.512s
```

- `usr/lib/aarch64-linux-gnu/pkgconfig/{wlroots-0.18,gnome-desktop-3.0,gmobile}.pc` **都在** ⇒ 交叉编 phoc 的 dev 依赖就是这样进去的。
- 版本账**没丢**：下载的 `.deb` 留在 `sysroot/debs/`，文件名即 `pkg_version_arch.deb`（`out/sysroot-trixie-arm64/debs/` 现有 25 个，含 `libc6_2.41-12+deb13u5_arm64.deb`）。
- 顺带证伪了「必须 chroot 才能取 arm64 包」这个前提：`scripts/sysroot-add-debs.sh` 的 `chroot + apt-get download` 只是历史写法（T45 沿用），**不是必要条件**。

## 4. 去掉手动负担的三步（推荐，取代「装 podman」）

| # | 动作 | 判据 | 估计 |
|---|---|---|---|
| 1 | `sysroot-trixie.pkgs`（rootfs/ 下，待建）：把 phoc/gmobile/droidloom 三处依赖并成一份清单（谁要什么写注释） | `grep -c` 与三脚本现有包表合计一致；构建器只读这份文件 | 30 min |
| 2 | `scripts/sysroot-add-debs.sh` 改成**零 root**（复用 `build-sysroot.sh` 的 `-o Dir=` 路径），或直接让 `build-sysroot.sh` 支持 `--add <pkgs>` | 用非 root 用户跑一次「加 libwlroots-dev」，与 chroot 版产物 `NEEDED` 一致 | 40 min |
| 3 | 依赖**闭包自动解析**（替代手写 78 条）+ 写 `sysroot-trixie.lock`（rootfs/ 下，待建）（`pkg=version` 逐行） | `apt-get -o Dir=… install -s --no-install-recommends <pkg>` 的 `^Inst` 行数 = 实下包数；`lock` 能被 `--rebuild` 逐条满足 | 60–90 min |

做完的效果：**加依赖 = 改一行清单 → 跑一条命令（秒级、免 sudo、版本落 lock）**；子代理不再因为「要 root chroot」把活推回父代理（今天两条 lane 的卡点就是它）。
实测支撑：`apt-get … install -s --no-install-recommends libwlroots-0.18-dev` 输出 **210** 行 `^Inst` ⇒ 闭包可机器列出，不必再靠「从 trixie chroot 里 rsync 一份」。

## 5. podman 的定位（已装，留作 rootless chroot）

**用它的唯一场景**：需要**运行**完整 arm64 发行版用户态（`./configure`、`make check`、`apt` 操作、跑 autotest），而又不想 sudo。做法（不重新 debootstrap）：

```sh
tar -C /opt/elden/arm64-trixie -c . | podman import - elden-trixie-arm64:13
podman run --rm -it --arch arm64 -v $PWD:/w -w /w elden-trixie-arm64:13 bash
```

**不用的场景**（今天全部构建活都属于这类）：交叉编。容器在这条路径上只是多一层，`fuse-overlayfs` 还会明显慢于 `qemu-user` 直跑。

**转正触发条件**（任一命中再投入）：
- ① 某活必须**在 arm64 用户态里跑测试/autotest** 且因此又被迫 sudo（今天 chroot 仍是唯一 root 通路）；
- ② 同时维护 **≥2 个发行版基线**（trixie + bookworm/sid），且 sysroot 的 lock/清单开始打架；
- ③ 需要把构建环境**搬到 CI 或别的机器**复用（镜像比 chroot 目录可移植）。

## 6. 与旧结论的关系

- `reports/build-env-podman-eval-20261128.md` §3（交叉编落地）**不变**，仍是正确方向；
- 本文新增 ①「podman 已装、但不用于交叉编」②「长期负担在清单/root/lock 三处，不在有没有容器」③「podman 的正确定位 = rootless chroot」；
- 未变的前提：老版本 podman 的 `--platform` 弱、需 `qemu-aarch64` binfmt（本机已注册）、镜像须钉 **trixie 2.41**（sid 2.43 的件上不了设备，今天踩过）。
