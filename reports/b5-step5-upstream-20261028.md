# B5 投递前收尾 + 系列组装（2026-10-28）

> lane `L2 · b5-upstream` · 内核 worktree `build/b5-resoc`（`build/m3v2-7.3rc7` 的 linked worktree，**非** `geekidos-linux` 主 checkout）
> 分支 `b5/send-20261028`（从日常线 `24223e44a` 起）
> 承接：`reports/b5-step4-master-from-cfg-20261027.md`、`reports/b5-step5-doc-unblock-20261028.md`、`reports/b5-per-soc-cfg-design-20261027.md` §4
> 产物：`patches/local/b5-resoc-20261028/`（6 枚）、本报告、`TASKS/sessions/2026-10-28-B5投递前收尾.md`

## §0 结论（数字，逐项判据见后文各节）

| 项 | 结果 |
|---|---|
| 续作判定 | 上一轮遗留：`build/b5-resoc` 有一份**未提交且编译失败**的半成品（`compatible` 加错到 `msm_dsi_cfg_handler`，25 条表项位置初始化全错）⇒ 本轮**推翻重做**，非继续 |
| 系列枚数 | **6**（3 枚行为中性搬移 + 3 枚语义/可读性） |
| 全量 `make -j26 Image.gz dtbs` | 见 §4 |
| `make -j26 W=1 drivers/gpu/drm/msm/` | **rc=0 / 0 warning**（逐提交复跑 6/6） |
| checkpatch `--strict`（每枚） | **6/6 = 0E / 0W / 0C** |
| `git am` 到 pristine `24a19b953` | 见 §5（**已知阻塞**：系列依赖日常线 payload 的 bonded 核心，pristine 无此代码） |
| 投递 | 见 §6 |

## §1 步骤 1：bonded 数据脱离 `sm8650_dsi_cfg`（拆独立 SM8750 表项）

**做法**：新增 `sm8750_dsi_cfg`，`compatible = "qcom,sm8750-dsi-ctrl"`，`bonded` 指针挂这张表；
`sm8650_dsi_cfg` 退回纯净（不再声称有 bonded 能力）。查表函数 `msm_dsi_cfg_get()` 加 `struct device *dev`
参数，用 `of_device_is_compatible()` 匹配表项的 `compatible`；**未命名 SoC 的表项保持通用回退**，
所以真正的 SM8650（同报 6G v2.9）行为逐字不变。

**关键设计点**（上一轮半成品的错在哪）：`compatible` 属于 **`struct msm_dsi_config`**（per-SoC 表，与 `dsi_phy.c`
的 `dsi_phy_cfg` 同范式），**不是** `struct msm_dsi_cfg_handler`。后者是「版本号 → 表」的索引，25 条既有表项
全是位置初始化（`{major, minor, &cfg, &ops}`），中间插一个字符串字段会让**全部**表项错位——上一轮正是死在这里。

**驱动侧与 DTS 侧一致**：`sm8750.dtsi` 与 `eliza.dtsi` 的 DSI 控制器都是
`compatible = "qcom,sm8750-dsi-ctrl", "qcom,mdss-dsi-ctrl"`，`Documentation/.../dsi-controller-main.yaml`
已列 `qcom,sm8750-dsi-ctrl`（`:48`、`:390`）⇒ 无需新增 binding。

**表项顺序**：SM8750 专用项排在通用 V2_9_0 项**之后**，查表从后往前扫 ⇒ 专用项先命中。

## §2 步骤 2：「调用者必须是 master」显式检查

`dsi_mgr_bonded_cmd_xfer()` 现在接收**发起命令的 link id**，在入口处校验：

```c
if (id != master_id) {
        dev_err(&dsi_mgr_get_dsi(id)->pdev->dev,
                "bonded command on link %d, but link %d is the master\n",
                id, master_id);
        return -EINVAL;
}
```

- **无副作用**：校验位于 `dsi_bonded_xfer_prepare()`（`pm_runtime_resume_and_get` + 时钟使能）**之前**，
  也不碰 `bonded_cmd_failed` 闩锁 ⇒ 被拒的调用让两条链路保持原样。
- **错误路径清晰**：`dev_err` 同时点名发起 link 与真正的 master，不再是底层控制器的裸 `-EINVAL`。
- **覆盖非 master 调用者**：`msm_dsi_manager_cmd_xfer(id, msg)` 的 `id` 原样传下去，任何从 peer link 进来的
  写命令都会命中这条检查（此前是「照样按 master 组装」，结果 `ff 20` 三连 `-22`，见
  `reports/b5-step4-master-from-cfg-20261027.md` §1）。
- 返回 `-EINVAL` 而非 `-EXDEV`：与函数内其余参数校验保持同一错误码，且 `-EXDEV` 在 DRM 显示路径无先例。

## §3 步骤 3：`master_link_id` 降级为事实登记

按 `reports/b5-step4-master-from-cfg-20261027.md` §0 的裁决（判别臂强改 DSI1 ⇒ 面板首条 DCS 三连 `-22`），
字段文档改为：

```c
 * @master_link_id: link that drives the broadcast; a hardware fact of the
 *                  panel wiring, not the probe order and not a tunable: it
 *                  must be the link the panel is attached to
```

即：**登记硬件事实**（本机 = DSI0 = 挂 panel 的那条），**不声称可自由切换**。
代码侧 `dsi_mgr_bonded_master_link_id()` 的注释同样写明「read, never negotiated」。

## §4 全量构建门（`make -j26 Image.gz dtbs`，整树，非子目录）

**命令（整树，非子目录；`make clean` 后从零编，开工前先修好被上轮 `make defconfig` 污染成 x86 的 `.config`）**

```sh
cd build/b5-resoc
. ../../scripts/env-build.sh          # ARCH=arm64, CROSS_COMPILE="ccache aarch64-linux-gnu-"
cp ../../build/vk151/.config .config  # 日常线 arm64 配置；olddefconfig 回填 0 行差异
make ARCH=arm64 olddefconfig
timeout -k 60  900 make clean
timeout -k 60 3600 make -j26 Image.gz dtbs
```

**原始输出（`reports/artifacts/b5-build-20261028/full-build.log`）**

```
== tree: /home/xuqianhui/y700-elden/build/b5-resoc  branch: b5/send-20261028  HEAD: 481225269
== ARCH=arm64 CROSS_COMPILE=ccache aarch64-linux-gnu- CC=ccache aarch64-linux-gnu-gcc
== CONFIG check: CONFIG_ARM64=y CONFIG_DRM_MSM=y
== make clean rc=0 @ 2026-10-28T21:24:37+08:00
  OBJCOPY arch/arm64/boot/Image
  GZIP    arch/arm64/boot/Image.gz
ELAPSED=4:28.47 MAXRSS=1493688kB
== full build rc=0 @ 2026-10-28T21:29:09+08:00
```

| 指标 | 值 |
|---|---|
| `make` 退出码 | **0** |
| `error` 计数 | **0**（日志内 6 条含 "error" 的行全是**目标文件名**：`scripts/dtc/libfdt/fdt_strerror.o`、`lib/fdt_strerror.o`、`fs/fserror.o`、`lib/zstd/common/error_private.o`、`drivers/scsi/scsi_error.o`、`kernel/trace/error_report-traces.o`） |
| `warning` 计数 | **0**（`grep -ci warning` 全文 0 命中） |
| 编译单元 | `CC` 4570 行、`DTC` 1897 行（全量，非增量：`make clean` 清空后重建） |
| 产物 | `arch/arm64/boot/Image.gz` 19 762 970 B @21:29、`vmlinux` 637 548 528 B、`dtbs` 410 个 `.dtb` |
| 目标 DTB | `sm8750-lenovo-elden.dtb` 153 089 B（在 410 个之内） |
| 补丁是否真进内核 | `nm vmlinux` 见 `ffff800081fe2918 d sm8750_dsi_cfg`；`strings vmlinux` 含 `dsi_mgr_bonded_master_link_id` / `dsi_mgr_uses_bonded_cmd` ⇒ 系列确实参与了本次全量编译 |

**两处需要说明的现场情况（不改结论，但影响复跑）**

1. **`.config` 被上一轮的 `make defconfig` 污染成 x86**：本轮开工时 `build/b5-resoc/.config` 头三行是
   `# Linux/x86 7.3.0-rc7 Kernel Configuration`、`CONFIG_X86_64=y`，于是首跑直接
   `make[1]: *** 没有规则可制作目标“Image.gz”`（8.5 s 即退，未编任何 `.o`；该次失败输出已被随后成功的一轮覆盖，
   现场以 `.config` 头三行、`grep CONFIG_X86_64` 与 `find . -name '*.o' -newermt` = 0 为凭）。已用日常线
   `build/vk151/.config`（`CONFIG_ARM64=y`、`CONFIG_DRM_MSM=y`）覆盖，`olddefconfig` 回填 **0 行差异**
   ⇒ 配置与日常线逐字一致。⚠ 上一轮 20:18 那份 15 MB `Image.gz` 是**另一份 config** 的产物，不可与本轮 19.7 MB 直接比大小。
2. **构建 4 分 28 秒**：`make clean` 后仍这么快是 ccache（`~/.cache/ccache-elden`）全命中，
   `CC` 4570 行的行数证明是整树重建而非增量跳过。⚠ 上两轮出现过的 gcc 15 并发 ICE 本轮未复现。

## §5 pristine 重放（`git am` 到 `24a19b953`）

**做法**：`git worktree add --detach /tmp/l2b-pristine 24a19b953`（干净树，`git status --porcelain` = 0 行），
逐枚 `git am --3way patches/local/b5-resoc-20261028/000*.patch`；失败即停，不 `--skip`。

**结果：`git am` = 0/6（第 1 枚即冲突），逐枚机械可打性 1/6。**

```
===== git am 0001-drm-msm-dsi-move-the-bonded-command-failure-flag-int.patch
应用：drm/msm/dsi: move the bonded command failure flag into the manager state
使用索引来重建一个（三路合并的）基础目录树...
M	drivers/gpu/drm/msm/dsi/dsi_manager.c
回落到在基础版本上打补丁并进行三路合并...
自动合并 drivers/gpu/drm/msm/dsi/dsi_manager.c
冲突（内容）：合并冲突于 drivers/gpu/drm/msm/dsi/dsi_manager.c
error: 无法合并变更。
打补丁失败于 0001 drm/msm/dsi: move the bonded command failure flag into the manager state
rc=128
```

**失败提交号**：`0001` = upstream 提交 `0f24eb699`（`drm/msm/dsi: move the bonded command failure flag into the manager state`）。
定位到行：`drivers/gpu/drm/msm/dsi/dsi_manager.c:30`。

```
$ git apply --check -v 0001-*.patch      # 在 pristine 上
error: 在搜索：
	bool is_bonded_dsi;
	bool is_sync_needed;
	bool is_sm8750;
	int master_dsi_link_id;
};
error: 打补丁失败：drivers/gpu/drm/msm/dsi/dsi_manager.c:30
```

**逐枚机械可打性（pristine 上 `git apply --check`，各枚单独判定）**

| 补丁 | 结果 |
|---|---|
| 0001 | ❌ fail（`dsi_manager.c:30`：`struct msm_dsi_manager` 缺 `is_sm8750` / `master_dsi_link_id` 字段） |
| 0002 | ✅ 干净应用（纯追加：新结构 + 新表项；带 `块 #1 成功应用于 229（偏移 -16 行）`） |
| 0003 | ❌ fail（`dsi.h`：需要 `msm_dsi_manager_cmd_failed()` 等一排下游原型） |
| 0004 | ❌ fail |
| 0005 | ❌ fail |
| 0006 | ❌ fail |

**根因（一句）**：整个系列做的是「**已经存在的** bonded 命令（DCS 广播）通路」的搬迁/配置化/错误码命名，
而这条通路本身**不在上游 7.3-rc7**，属于日常线下游载荷 `0f1fb1c9c`（`elden payload v2: downstream vk64 tree state …`，
`dsi_host.c +578`、`dsi_manager.c +249`、`dsi.h +19`、`registers/display/dsi.xml`）。
上游 7.3-rc7 的 `drivers/gpu/drm/msm/` 里 **`broadcast` 仅 6 处命中且无一与 DCS 命令通路相关**
（`dsi.xml:190 BROADCAST_EN` 一个位域 + HDMI/Adreno 的无关命中），`dsi_mgr_bonded_cmd_xfer` 等符号 **0 命中**。

**精确缺失依赖清单**（逐个符号在「系列基线 `24223e44a`」与「pristine `24a19b953`」的出现次数，
原始表见 `reports/artifacts/b5-build-20261028/pristine-missing-deps-curated.log`）

| 缺失符号 / 结构 | 文件 | 基线 `24223e44a` | pristine |
|---|---|---|---|
| `msm_dsi_host_bonded_cmd_arm_master` / `_build` / `_init_trigger` / `_poll_slave` / `_stage` / `_trigger` / `_wait_master` | `dsi.h` `dsi_host.c` `dsi_manager.c` | 3–4 处各 | **0** |
| `msm_dsi_host_bonded_xfer_prepare` / `_xfer_restore` / `_bonded_wait_video` | 同上 | 4–5 处各 | **0** |
| `msm_dsi_host_cmd_xfer_config()` | `dsi.h` `dsi_host.c` | 5 | **0** |
| `msm_dsi_manager_cmd_failed()` | `dsi.h` `dsi_manager.c` | 10 | **0** |
| `dsi_mgr_bonded_cmd_xfer()` / `dsi_mgr_uses_bonded_cmd()` | `dsi_manager.c` | 2 / 4 | **0** |
| `dsi_bonded_cmd_lock`（`DEFINE_MUTEX`）/ `dsi_bonded_cmd_failed` | `dsi_manager.c` | 3 / 4 | **0** |
| `struct msm_dsi_manager` 字段 `is_sm8750` | `dsi_manager.c` | 7 | **0** |
| `dsi_cmd_error_prepare()` / `dsi_cmd_error_cleanup()` | `dsi_host.c` | 2 / 2 | **0** |
| 寄存器位域 `CMD_DMA_CTRL.BROADCAST_MASTER` / `.WC_SEL` / `.PACKET_TYPE` | `registers/display/dsi.xml` | 有 | **无** |
| 寄存器 `DMA_SCHEDULE_CTRL`、`DMA_FIFO_CTRL` | 同上 | 有 | **无** |
| `DSI_CMD_DMA_CTRL_BROADCAST_EN` 之外的广播控制宏 | `dsi_host.c` | 1+ | **0** |

（`dsi_mgr_bonded_master_link_id` / `msm_dsi_bonded_cfg` / `sm8750_dsi_cfg` 三者在两处都是 0 次，因为它们是**本系列自己新增**的，
不算前置依赖。）

**结论口径**：这不是「rebase 噪声」，而是**缺前置系列**。要让 6 枚能落到上游树上，必须先把下游载荷里的
bonded 命令通路本身拆成上游可接受的若干枚（host ops + 寄存器定义 + manager 侧广播/超时/错误处理）先投，
本系列只能作为**其后的第 2 组**。⇒ 本轮**不投递**（否则 maintainer 侧 `git am` 同样 0/6）。

## §6 投递状态

**本轮按派工要求：一封邮件都不发（等用户批准）。**

| 门 | 状态 | 判据来源 |
|---|---|---|
| 全量 `make -j26 Image.gz dtbs` | ✅ 0 error / 0 warning，rc=0 | §4 |
| `checkpatch --strict` 6/6 | ✅ 0E / 0W / 0C | §6.1 |
| `git am` 到上游 `24a19b953` | ❌ **0/6**，缺前置系列 | §5 |
| 设备行为（本轮 6 枚整体） | ⛔ **未上机**（本轮为「推翻重做」后的重新组装，未刷机验证） | `reports/b5-step4-master-from-cfg-20261027.md` §0 的 vk178/vk179 只覆盖 20261027 版 1–3（其中 0001 diff 逐字相同，0002/0003/0004 有改动） |
| `to:`/`cc:` 收件人、`git send-email` 配置 | 未做（另有 `upstream-mail-ustc` 技能线负责，本轮不碰） | — |

### §6.1 本轮 checkpatch 复核（6/6 全部 0E/0W/0C）

命令（每枚单独跑，`--strict`，用**该内核树自带**的 `scripts/checkpatch.pl`）：

```sh
for p in patches/local/b5-resoc-20261028/000*.patch; do
  build/b5-resoc/scripts/checkpatch.pl --strict --no-tree "$p"
done
```

| 补丁 | rc | total |
|---|---|---|
| 0001 move the bonded command failure flag | 0 | `total: 0 errors, 0 warnings, 0 checks, 43 lines checked` |
| 0002 add per-SoC bonded command-path config | 0 | `total: 0 errors, 0 warnings, 0 checks, 151 lines checked` |
| 0003 route the bonded command path through host ops | 0 | `total: 0 errors, 0 warnings, 0 checks, 380 lines checked` |
| 0004 take the bonded master link from the SoC config | 0 | `total: 0 errors, 0 warnings, 0 checks, 150 lines checked` |
| 0005 reject bonded commands issued on the peer link | 0 | `total: 0 errors, 0 warnings, 0 checks, 39 lines checked` |
| 0006 name the FIFO error bits | 0 | `total: 0 errors, 0 warnings, 0 checks, 37 lines checked` |

原始输出：`reports/artifacts/b5-build-20261028/checkpatch-strict.log`（`--terse`，0 行输出）、
`checkpatch-strict-totals.log`（上表 `total:` 行）。

**「可投递」判定：❌ 未达到。** 硬门（构建、checkpatch）已过，但 **pristine `git am` 0/6** 说明这 6 枚在上游树上落不下去，
投出去只会换来 maintainer 一句 "does not apply"。必须先补/先投前置的 bonded 命令通路系列（§5 的依赖清单即是其范围）。

## §7 附：行为中性证据（任务 4，`0001–0003`）

**方法**：在 `/tmp/l2b-neutral`（`git worktree` @ 基线 `24223e44a`，同一份 `build/vk151/.config`）上
**逐枚 `git apply` + `make -j26 drivers/gpu/drm/msm/` 重建**，每级记录 `dsi_manager.o` / `dsi_host.o` / `dsi_cfg.o`
的 section 尺寸、逐函数指令数（`aarch64-linux-gnu-objdump -d` 计数）、以及数据符号表。
原始数据：`reports/artifacts/b5-build-20261028/neutral-{r0-base,r0001,r0002,r0003}.txt`、汇总 `neutral-comparison.txt`。
（临时 worktree `/tmp/l2b-neutral`、`/tmp/l2b-pristine` 测完即 `git worktree remove`，只保留上述证据文件；复跑按本节命令重建即可。）

| 阶段 | manager `.text/.data/.bss` | host `.text` | cfg `.text` | 函数数 |
|---|---|---|---|---|
| r0 = `24223e44a`（基线） | 5408 / 24 / 32 | 23048 | 96 | 93 |
| r1 = +0001 | 5344 / 24 / **24** | 23048 | 96 | 93 |
| r2 = +0002 | 5344 / 24 / 24 | 23048 | **196** | 93 |
| r3 = +0003 | 5088 / 24 / 24 | 22944 | 196 | **92** |

**① 0001 = 纯状态搬移（已证，编译级）**

- 函数集合 **完全不变**（93 → 93，无增无删）。
- 只有 6 个函数指令数变化，且都是地址形式差：`dsi_mgr_bridge_disable` 48→44、`dsi_mgr_bridge_post_disable` 136→132、
  `dsi_mgr_bridge_pre_enable` 274→272、`msm_dsi_manager_cmd_failed` 16→12、`msm_dsi_manager_cmd_xfer` 284→280、
  `msm_dsi_manager_connector_init` 58→60（合计 **−16 条**）。
- 存储证据：`dsi_manager.o` 的 `.bss` **32 → 24 字节**（全局 `static bool` 挪进 `msm_dsim_glb`，少一个 8 字节对齐槽），
  `.data` 不变。
- 语义证据：diff 内 `WRITE_ONCE` +2/−2、`READ_ONCE` +1/−1、`mutex_lock/unlock` ±0、`dsi_write` ±0
  ⇒ **同一批调用点、同一把锁、零新增硬件访问**。文件头注释亦从「file-scope flag」改成「state 字段」。

**② 0002 = 纯数据追加 + 查表能力（已证，编译级）**

- `dsi_manager.o`/`dsi_host.o` 的 section 尺寸 **逐字节不变**，93 个函数的指令数 **93/93 全部不变**。
- 唯一代码变化：`msm_dsi_cfg_get()` 22 → 47 条（加 `struct device *dev` 形参 + `of_device_is_compatible()` 匹配）。
  `dsi_cfg.o .text` 96 → 196 即此。
- diff 内 `dsi_write`/`dsi_read` **±0**，只新增 1 处 `of_device_is_compatible()`。
- 关键：本枚新增的 `sm8750_dsi_cfg.bonded` 指针**此时还没有消费者**（消费者在 0004），所以对已上电的旧板行为为恒等；
  已命名 SoC 之外仍回落通用 `V2_9_0` 表项（`reports/b5-step5-upstream-20261028.md` §1 的设计点）。

**③ 0003 = 跨文件搬移 + 一层 ops 间接（未证实为「逐字等价」——明确区分）**

- 搬移规模：`dsi_manager.o` 侧 **9 个 `msm_dsi_host_bonded_*` 函数消失**（合计 776 条指令：
  arm_master 76 / build 90 / init_trigger 54 / poll_slave 64 / stage 90 / trigger 10 / wait_master 112 / xfer_prepare 160 / xfer_restore 120）；
  `dsi_host.o` 侧出现 **8 个新函数**（合计 770 条：`dsi_bonded_cmd_stage` 90、`dsi_bonded_cmd_init_trigger` 54、
  `dsi_bonded_xfer_prepare` 140、`dsi_bonded_xfer_restore` 118、`dsi_cmd_dma_intr_update` 46、
  `msm_dsi_host_bonded_cmd_xfer` 304、`msm_dsi_host_get_cfg_ops` 8、`msm_dsi_manager_mark_cmd_failed` 10）。
- 另有 13 个函数指令数变化（主要是 `msm_dsi_manager_cmd_xfer` 280→206：bonded 分支改为经 ops 派发）。
  其中 `dsi_calc_clk_rate_v2` / `dsi_wait4video_eng_busy` / `dsi_update_dsc_timing` 等**本枚未触碰**的函数也有 ±2 条漂移，
  属整文件重编译的对齐/常量池噪声，不计入语义判断。
- 总量：7116 → 7051（**−90 条 / −1.3%**），硬件访问原语 **`dsi_write` +1/−1、`wmb` +2/−2、`udelay/usleep_range` ±0**
  ⇒ 没有新增/删掉任何一次寄存器读写或延时。
- **判定**：这是**重构性搬移**（函数改名 + 新增 ops 表 + 派发点），不是 0001 那种「一处存储换位置」，
  因此只能给「语义等价（按 hunk 论证 + 硬件访问净 0）」，**不给「逐字等价」**。
  与 20261027 版的同名补丁相比，本版多拆出独立 `msm_dsi_6g_v2_9_bonded_host_ops` 表（旧版是往 6g_v2_9 表里塞两行），
  所以 `reports/b5-step4-master-from-cfg-20261027.md` §0 里 vk178 那台机器的零计数证据**不能直接套用到本版 0003**。

**④ 0003 的「搬移」不是逐行搬移（实测，修正措辞）**

> 订正：§0 表格里的「3 枚行为中性搬移」按本节实测应读作「2 枚纯搬移/追加（0001、0002）+ 1 枚改写式搬移（0003）」。
> §0 既有文本按派工要求**未改**，以本节为准。

把 0003 的 `-` / `+` 行做多重集比对（`python3` 计数，`removed=87` / `added=139`）：
**只有 28 行在两边的文本完全相同**，其余 **59 行删除 / 111 行新增**是真正的改写。因此对外措辞不能写「pure move」，
只能写「把 bonded 命令路径移到 host 侧」+ 下面的等价性证据。可枚举的改写只有 4 类：

1. 9 个 `msm_dsi_host_bonded_*()` 从 `dsi_manager.c`（入参 `struct mipi_dsi_host *host`）移到 `dsi_host.c` 并 `static` 化，
   对外只留一个入口 `msm_dsi_host_bonded_cmd_xfer(host, peer, msg)`。
2. 新增 `static dsi_bonded_cfg(msm_host)` 访问器（**本枚自带**；0004 的 `msm_dsi_host_get_bonded_cfg()` 是另一件事，0003 里 0 命中）。
3. 3 处硬编码常量换成 per-SoC 表取值（值等价见下表）。
4. 新增 `struct msm_dsi_host_cfg_ops` + 独立 `msm_dsi_6g_v2_9_bonded_host_ops` 表 + `msm_dsi_manager_cmd_xfer()` 处的派发点。

**值等价核对（硬证据，逐项对值而非对文本）**

| 常量 | 搬移前 `24223e44a` | 搬移后（0002 表项 + 0006 命名宏） | 判定 |
|---|---|---|---|
| FIFO 清理掩码 | `dsi_write(msm_host, REG_DSI_FIFO_STATUS, val \| 0x44440400)`（`dsi_host.c:2367`） | `val \| bonded->err_cleanup_bits`，`= DSI_FIFO_STATUS_FIFO_ERRORS` | **相同**：`0x44440400` = bit10 `CMD_DMA_FIFO_UNDERFLOW` + bit18/22/26/30 `DLN0..3_HS_FIFO_OVERFLOW`，与 `0006` 里该宏的 5 个位逐一对应（`dsi.xml` 位定义核对） |
| `CMD_DMA_CTRL` 位 | `DSI_CMD_DMA_CTRL_BROADCAST_EN \| DSI_CMD_DMA_CTRL_FROM_FRAME_BUFFER` | `bonded->cmd_dma_ctrl` = 同两条宏，逐字相同 | **相同**（宏未变，只是从函数体挪进表） |
| 对端轮询超时 | `for (i = 0; i < 500; i++) { …; udelay(10); }` = 500 × 10 µs | `poll_timeout_us = 5000`，`for (elapsed = 0; elapsed < timeout_us; elapsed += 10)` = 500 × 10 µs | **等价**（次数与间隔均同） |

**⑤ 逐 hunk 论证要点（人工复核，供 maintainer 读）**

1. **调用序列逐项同序（实测，非推断）**：把前后两版的派发函数区域拉出来对比（`git show 24223e44a:…/dsi_manager.c`
   的 `dsi_mgr_bonded_cmd_xfer()` vs HEAD `dsi_host.c` 的 `msm_dsi_host_bonded_cmd_xfer()`），顺序**完全一致**：

   ```
   prepare(master) → prepare(slave) → wait_video(master) → wait_video(slave)
   → build → init_trigger(master) → init_trigger(slave) → stage(master,+true) → stage(slave,+false)
   → wmb() → trigger(slave) → arm_master(master) → [ wmb() → trigger(master) → wait_master(master) ]
   → poll_slave(slave) → mark_cmd_failed() → restore(master) → restore(slave)
   ```

   `wait_video` 仍卡在 build 之前、`restore` 仍在最后、`mark_cmd_failed` 位置不变（旧版是
   `WRITE_ONCE(dsi_bonded_cmd_failed, true)`，新版是 `msm_dsi_manager_mark_cmd_failed()`）。
   `wmb()` 在 diff 里是 +2/−2 成对，`udelay/usleep_range` ±0。
2. 错误处理路径不变：`dsi_cmd_error_prepare/cleanup` 仍在提交命令前后各调一次；掩码值来自 per-SoC 表（0002），
   与搬移前硬编码常量按上表逐值对应（0006 只把裸数字换成命名宏）。
3. 剩下的**不确定性**：ops 查表（`msm_dsi_host_get_cfg_ops()`）与 `peer` 的取得位置是新的控制流，
   只能靠「值等价 + 硬件原语净 0 + 指令数 −1.3%」三重间接证据支撑，**不给「逐字等价」**。
   ⇒ 若要给 maintainer 一个「无语义争议」的系列，建议**评估把 0003 拆成 (a) 纯搬移 + (b) 表化常量 + (c) ops 间接**三枚。
