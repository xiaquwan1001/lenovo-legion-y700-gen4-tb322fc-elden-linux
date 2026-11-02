# M6 B5 v2 门禁原始输出（2026-11-02，**收尾修订版**）

- 树：一次性 worktree `/tmp/wt-b5v2fix`（分支 `b5/v2-fixed`，从 `build/b5-v2` 的 base 拉出）
- base：`6628e7d4c6b25c8d18f1345e3a20d21829aae7e4`（`Linux 7.4-rc1`，公开 torvalds 树）
- 序列：4 枚（见本目录 `0001..0004`），净 **+673 −6**
- 全部日志留档于 `logs/`
- checkpatch 一律 **stdin**（`--patch - < file`）：本轮实测同一批补丁用**文件参数**会假报
  15/18/12/3 条 ERROR（`PITFALLS #474` 复现），stdin 才是 0E/0W

## 0. ★为什么重出（本轮修的缺陷）

原 v2 的两个事实叠在一起就是一次启动崩溃：

1. `.bonded_cmd_xfer` 挂在**共用的** `msm_dsi_6g_v2_9_host_ops` 上（`dsi_cfg.c`），而
   `dsi_cfg_handlers[]` 的 v2.9 修订条目是 **SM8650 与 SM8750 共用**的；
2. `dsi_mgr_uses_bonded_cmd()` 只检查 `ops->bonded_cmd_xfer` 是否存在。

⇒ 任何 `qcom,dual-dsi-mode` + `qcom,sync-dual-dsi` 的 **SM8650** 板（树内实例
`sm8650-ayaneo-pocket-s2`）在面板 DCS 写时都会走 `dsi_mgr_bonded_cmd_xfer()` →
`dsi_bonded_xfer_prepare()` → `dsi_cmd_error_prepare()`，那里 `bonded = ...->bonded` 为
**NULL** 后直接取 `bonded->err_clear_bits` ⇒ **空指针**。v1（已投的 5 枚）用的是
`msm_dsim_glb.is_sm8750 && IS_BONDED_DSI()` 门控，SM8650 天然安全；v2 去掉 `is_sm8750`
特判时把这个门一起丢了。

修法（落在 3/4）：manager 要求「op 存在 **且** per-SoC 数据非空」，并新增
`msm_dsi_host_get_bonded_cfg()` accessor。不在共用表里抽第二份 op 表，因为那要为表达
一个 bit 复制整张 v2.9 表。

`logs/gate-sm8650-no-bonded.txt` 记录修后的静态判据：`.bonded` 只在 `sm8750_dsi_cfg` 出现
（`dsi_cfg.c:249`），v2.9 的两个 handler 条目（`:401`、`:403`）里只有 SM8750 那条能找到数据。

> 这条也说明「新增路径在树内到底有没有使用者」不是哲学问题：树内确实有板子会**碰到**这段
> 代码，只是它们不该进入它。缺陷即是证据。

## 1. checkpatch --strict

```sh
# 必须 stdin 喂（PITFALLS #474）：给文件参数会把邮件头当正文，实测假报 15/18/12/3 条 ERROR
for f in patches/upstream/m6-b5-v2-20261102/000[1-4]-*.patch; do
    ./scripts/checkpatch.pl --strict --no-signoff --patch - < "$f"
done
```

`logs/checkpatch.log`：

```
0001 total: 0 errors, 0 warnings, 0 checks, 205 lines checked
0002 CHECK: usleep_range is preferred over udelay; see function description of usleep_range() and udelay().
0002 total: 0 errors, 0 warnings, 1 checks, 486 lines checked
0003 total: 0 errors, 0 warnings, 0 checks, 183 lines checked
0004 total: 0 errors, 0 warnings, 0 checks, 35 lines checked
```

结论：**4/4 枚 0 error / 0 warning**。唯一 CHECK（`udelay(10)`）保留：对端引擎在紧寄存器
轮询里等 `INTR_CTRL.CMD_DMA_DONE`，换 `usleep_range()` 会把 10 us 的轮询粒度交给调度器；
上限 500 次轮询 = 5 ms，且每条命令只走一次。**理由已写进 2/4 的 commit message**（原
`reports/m6-b5-v2-parent-review-20261102.md` §2.2 的建议已落实）。

## 2. 编译门（`W=1`）

```sh
cp build/m4-base/.config .                     # CONFIG_ARCH_QCOM=y / CONFIG_DRM_MSM=m
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j26 olddefconfig
touch drivers/gpu/drm/msm/dsi/*.c && make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j26 W=1 drivers/gpu/drm/msm/
```

`logs/make-W1-drivers-gpu-drm-msm.log`：

```
  CC [M]  drivers/gpu/drm/msm/dsi/dsi_cfg.o
  CC [M]  drivers/gpu/drm/msm/dsi/dsi_host.o
  CC [M]  drivers/gpu/drm/msm/dsi/dsi_manager.o
  LD [M]  drivers/gpu/drm/msm/msm.o
rc=0    warning: 0    error: 0
```

⚠ 两个环境坑（本轮踩到并已记入 `GATES.md` 备注）：
1. `olddefconfig` **必须带 `ARCH=arm64`**，否则按宿主 x86 解析，`CONFIG_ARCH_QCOM` 与
   `CONFIG_DRM_MSM` 被静默抹掉（`PITFALLS #162` 同族，这次在一次性测试树上复现）；
2. 必须 `CROSS_COMPILE=aarch64-linux-gnu-`，否则 `-mlittle-endian` / `-msign-return-address`
   不被宿主 gcc 识别。

## 3. 序列自足性（逐枚重放，临时 worktree）

```sh
scripts/check-series-selfcontained.sh patches/upstream/m6-b5-v2-20261102 6628e7d4c6 --repo build/b5-v2
```

```
  ok    0001-drm-msm-dsi-add-per-SoC-bonded-command-path-config.patch
  ok    0002-drm-msm-dsi-add-the-bonded-command-broadcast-host-op.patch
  ok    0003-drm-msm-dsi-route-bonded-commands-through-the-DSI-ma.patch
  ok    0004-drm-msm-dsi-reject-bonded-commands-issued-on-the-pee.patch
PASS  m6-b5-v2-20261102: 全部 5 个文件按序重放成功于 6628e7d4c6
== 汇总: PASS=4 FAIL=0 WARN=0 退出码=0 ==
```

## 4. 覆盖 Dmitry 四条（2026-10-31 回信承诺）

| Dmitry 的意见 | v2 落点 |
|---|---|
| ① 立项理由 | cover 前三段：base 树 `BROADCAST` 命中 0、本机 `ff 20` 三连 `-22`、`STATUS0=0x20003` |
| ② lock 归属 | 3/4：`bonded_cmd_failed` 与 mutex 一进就在 `msm_dsim_glb`，没有「先 file-scoped 再搬」的中间态 |
| ③ per-SoC 适用范围 | 1/4：独立 `sm8750_dsi_cfg` + handler 表新 `compatible` 字段；正文只声明本 SoC |
| ④ master 由 DT 不 by probe order | 3/4、4/4：`qcom,master-dsi` → `master_dsi_link_id`，全文无 probe order |

## 5. 环境噪音（如实记录）

`build/b5-v2` 的 `.git` 是 **partial clone（blob:none, promisor = git.kernel.org）**。凡 git 需要
历史里未落地的 blob（例如 `git diff` 触到工作树里 10 处**既有**脏文件
`tools/testing/selftests/**`），会尝试向 origin 取并立刻失败：

```
warning: filtering not recognized by server, ignoring
fatal: 远程错误：upload-pack: not our ref 4c152950...
```

本轮**没有**执行任何 `git fetch/clone/pull`，上述是 git 自身的 promisor 取块尝试（无数据流入）。
门禁全部只用 worktree 内已有对象与工作树内容；`git am` 重放在一次性 worktree 内完成。
