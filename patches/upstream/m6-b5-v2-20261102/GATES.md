# M6 B5 v2 门禁原始输出（2026-11-02）

- 树：`build/b5-v2`（worktree，分支 `b5/v2-20261102`）
- base：`6628e7d4c6b25c8d18f1345e3a20d21829aae7e4`（`Linux 7.4-rc1`，公开 torvalds 树）
- 序列：4 枚（见本目录 `0001..0004`）
- 全部日志留档于 `logs/`

## 1. checkpatch --strict --no-tree（stdin 喂）

命令：

```sh
cd build/b5-v2
for f in patches/upstream/m6-b5-v2-20261102/000[1-4]-*.patch; do
    perl scripts/checkpatch.pl --strict --no-tree - < "$f"
done
```

原始输出（`logs/checkpatch-*.log`）：

```
== 0001 ==
total: 0 errors, 0 warnings, 0 checks, 205 lines checked
"[PATCH 1/4] drm/msm/dsi: add per-SoC bonded command-path config" has no obvious style problems and is ready for submission.

== 0002 ==
CHECK: usleep_range is preferred over udelay; see function description of usleep_range() and udelay().
#480: FILE: drivers/gpu/drm/msm/dsi/dsi_host.c:2497:
+		udelay(10);
total: 0 errors, 0 warnings, 1 checks, 486 lines checked

== 0003 ==
total: 0 errors, 0 warnings, 0 checks, 163 lines checked

== 0004 ==
total: 0 errors, 0 warnings, 0 checks, 35 lines checked
```

结论：**4/4 枚 0 error / 0 warning**。唯一的 CHECK（`udelay(10)`）保留：对端引擎是在紧
寄存器轮询里等 `INTR_CTRL.CMD_DMA_DONE`，换成 `usleep_range()` 会把 10 us 的轮询粒度
交给调度器（最坏 500×~20 us），是本路径刻意不要的行为。

## 2. 编译门

命令：

```sh
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j26 O=/tmp/b5v2-out drivers/gpu/drm/msm/
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j26 O=/tmp/b5v2-out W=1 drivers/gpu/drm/msm/
```

config：`make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/b5v2-out defconfig`
+ `scripts/config -e DRM_MSM`（`=y`）+ `olddefconfig`。

原始输出末段（`logs/make-drivers-gpu-drm-msm.log`）：

```
  CC [M]  drivers/gpu/drm/msm/dsi/dsi.o
  CC [M]  drivers/gpu/drm/msm/dsi/dsi_cfg.o
  CC [M]  drivers/gpu/drm/msm/dsi/dsi_host.o
  CC [M]  drivers/gpu/drm/msm/dsi/dsi_manager.o
  ...
  LD [M]  drivers/gpu/drm/msm/msm.o
make[1]: 离开目录“/tmp/b5v2-out”
```

结论：`rc=0`，`warning:`/`error:` 计数 **0**；`W=1` 复跑同样 `rc=0`、0 warning
（`logs/make-W1-drivers-gpu-drm-msm.log`）。真编译到 `dsi_cfg.o / dsi_host.o /
dsi_manager.o`，不是复用旧对象。

## 3. `git am` 逐枚重放

命令（日志 `logs/git-am.log`；工作树里 `tools/testing/selftests/` 的 10 处**既有**脏文件
与本序列无关，`git am` 不触碰这些路径，未做 stash）：

```sh
cd build/b5-v2
git checkout -B b5-v2-am-test 6628e7d4c6
git am .../0001-*.patch .../0002-*.patch .../0003-*.patch .../0004-*.patch
```

原始输出：

```
6628e7d4c6 Linux 7.4-rc1
应用：drm/msm/dsi: add per-SoC bonded command-path config
应用：drm/msm/dsi: add the bonded command broadcast host ops
应用：drm/msm/dsi: route bonded commands through the DSI manager
应用：drm/msm/dsi: reject bonded commands issued on the peer link
am_rc=0
```

结论：**4/4 全绿**，无 fuzz/无冲突；重放后 `git diff b5/v2-20261102 b5-v2-am-test --
drivers/gpu/drm/msm/` 为空（仅 commit sha 不同），验证分支已删除。

## 4. 环境噪音（如实记录）

`build/b5-v2` 的 `.git` 是 **partial clone（blob:none, promisor = git.kernel.org）**。
凡 git 需要历史里未落地的 blob 时，会尝试向 origin 取并立刻失败：

```
warning: filtering not recognized by server, ignoring
fatal: 远程错误：upload-pack: not our ref 4c152950...
```

本轮**没有**执行任何 `git fetch/clone/pull/submodule`，上述为 git 自身的 promisor
取块尝试，网络不可达即失败（无代理、无数据流入），不影响任何门禁结论。所有门禁只用
本 worktree 内已存在的对象与工作树内容。
