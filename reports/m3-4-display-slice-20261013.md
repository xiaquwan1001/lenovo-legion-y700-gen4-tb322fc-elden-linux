# M3-4 显示片：nt36536 面板驱动 payload 改动 → 可上游补丁系列

- 日期：2026-10-13
- 工作树：`/home/xuqianhui1001/y700-elden/build/m3-4-worktree`（detach @ `24a19b953e` = Linux 7.3-rc7 pristine）
- 净 diff 来源：`build/m1-upstream/clean-tree` 的 `drivers/gpu/drm/panel/panel-novatek-nt36536.c` 覆盖进 pristine
- 补丁导出：`patches/upstream/m3-4-2026-10-13/`
- 上游驱动现状：该文件**已在上游**（pristine 含 486 行），of_device_id 仅一项 `csot,pp8807hb1-1`，且 `is_dual_dsi = true`
- 设备侧：纯主机侧任务，未上机；本片只做静态分类 + 机械门

## 0. 摘要

- pristine `24a19b953e` 的 `panel-novatek-nt36536.c` **已是上游驱动**（486 行），`of_device_id` 仅一项 `csot,pp8807hb1-1`，该 desc `is_dual_dsi = true`、`has_dcs_backlight = false`（无新 compatible 被加入）。
- clean-tree 相对 pristine 的净 diff：`1 file changed, 62 insertions(+), 18 deletions(-)`，**6 个 hunk**。
- 逐 hunk 独立复核 ≠ 父 agent 的 5 组描述：实际是 **6 个 hunk**（父 agent 的 b) 由 H2+H3 两个 hunk 组成），且 **a) 与其余改动可完全解耦**。
- 分类结论：**5 组逻辑改动**，其中 **4 组可上游**（mode 数据 / probe 时序 / prepare 错误处理 / enable 守护），**1 组阻断**（`to_primary_dsi` 无条件改 dsi[0]，H1）。
- 导出补丁 **4 枚**（每枚 1 个逻辑改动；b) 拆成错误处理 + enable 守护两枚）。
- 阻断项 a) 不进补丁，只在 §5 写设计建议（desc per-panel 字段）。

## 1. hunk 逐条分类

净 diff（`git diff --stat`）：`1 file changed, 62 insertions(+), 18 deletions(-)`，共 6 个 hunk。

| hunk | pristine 行号 | 内容摘要 | 类别 | 去留 | 理由 |
|---|---|---|---|---|---|
| H1 | @@ -65,8 +65,10 @@ | `to_primary_dsi()` 由 `ctx->desc->is_dual_dsi ? ctx->dsi[1] : ctx->dsi[0]` 改为**无条件 `return ctx->dsi[0]`**，并加 elden 专属注释 | 兼容性回归风险 | **剔除（阻断项）** | 该函数被 prepare/unprepare/backlight ops 共用；全树唯一 desc（`csot,pp8807hb1-1`，`is_dual_dsi=true`）的同步主链路会从 DSI1 变 DSI0，**直接改变唯一在册面板的行为**。elden 注释是板级事实，正确姿势 = desc per-panel 字段（见 §5），不能无条件改 |
| H2 | @@ -100,18 +102,33 @@ | prepare 错误路径重构为 `power_off:` 单一出口；新增 `dsi_ctx.accum_err` 检查（PPS/compression 之后）；`backlight_enable` 移入受保护路径并处理错误；新增 `novatek_enable()` 函数体 | 功能修正 | **保留 → P3（goto/accum_err/backlight）+ P4（enable 守护）** | 原代码只在 `init_sequence` 失败时清理；PPS/compression 的静默失败（`accum_err`）与 `backlight_enable` 失败不会清理。`power_off:` 出口与 `init_sequence` 失败共用同一清理，语义等价且完整。拆两枚：错误清理与 enable 守护是两种关注点 |
| H3 | @@ -177,6 +194,7 @@ | `novatek_panel_funcs` 注册 `.enable = novatek_enable` | 功能修正 | **保留 → P4** | 与 H2 的 `novatek_enable()` 同一改动；`drm_panel_enable()` 会**无条件**调用 `.enable`（`drivers/gpu/drm/drm_panel.c:258`，不检查 `panel->prepared`），因此 prepare 失败时用 `.enable` 返回 `-EIO` 可阻止 `panel->enabled=true` |
| H4 | @@ -320,6 +338,28 @@ | `csot_pp8807hb1_1_modes[]` 在 30Hz 与 165Hz 之间新增 **40Hz**、**24Hz** 两档（vtotal 分别为 10200、17000） | 面板 mode 数据 | **保留 → P1** | 纯 DT/数据表类硬件事实（刷新率 mode table），符合 Q3“硬件事实进数据表”；pristine 该表已有 120/60/30/165/144/90 六档，新增两档不改既有档位语义 |
| H5 | @@ -417,6 +457,18 @@ | probe 把 backlight 解析（`novatek_create_backlight` / `drm_panel_of_backlight`）**提前到 `devm_drm_panel_add` 与 attach 之前** | 功能修正 | **保留 → P2** | attach 会绑定 DRM bridge 并可能立即 prepare 面板，此时 backlight 必须已就绪；提前解析避免 prepare 拿到空 backlight / probe defer 竞态 |
| H6 | @@ -428,23 +480,15 @@ | probe 把“设置 lanes/format/mode_flags/dsc + attach”的单循环拆成**先设全部 dsi format、再统一 attach** 两个循环 | 功能修正 | **保留 → P2** | 与 H5 同属“attach 之前一切就绪”的时序修正：attach `dsi[0]` 可能触发 prepare，此时 `dsi[1]` 的 format 必须已设置；二者合并为一枚补丁 |

## 2. 补丁清单

补丁目录：`patches/upstream/m3-4-2026-10-13/`，按序 0001→0004 叠在 pristine `24a19b953e` 上；**终态 = clean-tree 减掉 H1**（已用 `diff` 校验 rc=0，见 §3）。

| # | 文件名 | hunk | 逻辑改动 | 行数 | 上游判定 |
|---|---|---|---|---|---|
| 0001 | `0001-drm-panel-novatek-nt36536-add-40Hz-and-24Hz-modes-fo.patch` | H4 | mode table 增 40Hz / 24Hz（vtotal 10200 / 17000） | 1 file, +22 | **可上游**（数据表） |
| 0002 | `0002-drm-panel-novatek-nt36536-finish-setup-before-attach.patch` | H5+H6 | backlight 解析提前；先设全部 DSI format 再统一 attach | 1 file, +15 -11 | **可上游**（probe 时序） |
| 0003 | `0003-drm-panel-novatek-nt36536-power-off-on-any-prepare-f.patch` | H2（goto/accum_err/backlight） | 单一 `power_off:` 出口；查 `dsi_ctx.accum_err`；backlight 失败也清理 | 1 file, +17 -9 | **可上游**（评审可能对 scope 提问） |
| 0004 | `0004-drm-panel-novatek-nt36536-reject-enable-when-prepare.patch` | H2（`novatek_enable`）+ H3 | `.enable` 在 `!panel->prepared` 时返回 `-EIO` | 1 file, +7 | **可上游**（新写法，见 §5） |

英文 commit 信息 + `Signed-off-by: Xu Qianhui <xiaqinghuan@mail.ustc.edu.cn>`，均由 `git format-patch --no-signature` 生成（未跑 `git send-email`，本片只备料）。

**H1 不进任何补丁**：`to_primary_dsi` 无条件改 `dsi[0]` 属板级事实，见 §5 阻断项。

## 3. 验收原始输出

### 3.1 checkpatch `--strict --no-tree`（4/4 0E/0W）

```
$ cd build/m3-4-worktree && for p in patches/upstream/m3-4-2026-10-13/*.patch; do scripts/checkpatch.pl --strict --no-tree "$p"; done
0001-...modes-fo.patch  : total: 0 errors, 0 warnings, 0 checks, 28 lines checked
0002-...attach.patch    : total: 0 errors, 0 warnings, 0 checks, 44 lines checked
0003-...prepare-f.patch : total: 0 errors, 0 warnings, 0 checks, 32 lines checked
0004-...prepare.patch   : total: 0 errors, 0 warnings, 0 checks, 19 lines checked
```
每枚均以 `has no obvious style problems and is ready for submission.` 结尾。

### 3.2 编译（worktree 内，`drivers/gpu/drm/panel/`，rc=0）

前置：`cp build/m1-upstream/clean-tree/.config build/m3-4-worktree/.config`（其中 `CONFIG_DRM_PANEL=y`、`CONFIG_DRM_PANEL_NOVATEK_NT36536=y`），`make ... olddefconfig` rc=0。

```
$ cd build/m3-4-worktree && make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- drivers/gpu/drm/panel/
  CC      drivers/gpu/drm/panel/panel-novatek-nt36536.o
  ...
  AR      drivers/gpu/drm/panel/built-in.a
MAKE_RC=0
```
（`panel-novatek-nt36536.o` 已实际重编，非 up-to-date 跳过。）

### 3.3 终态一致性（rc=0）

```
$ diff -u /tmp/expected-panel.c build/m3-4-worktree/drivers/gpu/drm/panel/panel-novatek-nt36536.c
DIFF_RC=0
```
`/tmp/expected-panel.c` = clean-tree 文件把 H1 的 `to_primary_dsi` 还原为 pristine 版本 ⇒ 证明 4 枚补丁完整覆盖除 H1 外的全部改动，无遗漏、无多余。

### 3.4 binding / DTS

本片**未改** binding 与 DTS，无新增 compatible ⇒ `dt-doc-validate` 不适用（未跑）。

### 3.5 补丁在 pristine 上逐枚 apply（rc=0）

```
$ mkdir -p /tmp/m34check/drivers/gpu/drm/panel && (cd /tmp/m34check && git -C <repo> archive 24a19b953e drivers/.../panel-novatek-nt36536.c | tar -x)
$ cd /tmp/m34check && for p in patches.../0*.patch; do git apply --check "$p" && git apply "$p"; done
APPLY-CHECK OK  0001-...modes-fo.patch
APPLY-CHECK OK  0002-...attach.patch
APPLY-CHECK OK  0003-...prepare-f.patch
APPLY-CHECK OK  0004-...prepare.patch
$ diff -q /tmp/m34check/drivers/gpu/drm/panel/panel-novatek-nt36536.c /tmp/expected-panel.c
MATCH_EXPECTED
```
⇒ 4 枚补丁在纯 pristine 上顺序 apply 无冲突，结果与「clean-tree 去 H1」一致。每枚含 1 个 `Signed-off-by: Xu Qianhui`。

## 4. 收件人草案（get_maintainer.pl）

在树根 `build/m3-4-worktree` 跑（4 枚合并与单文件结果一致）：

```
$ scripts/get_maintainer.pl --no-git-fallback --no-rolestats patches/upstream/m3-4-2026-10-13/*.patch
Neil Armstrong <neil.armstrong@linaro.org>
Jessica Zhang <jesszhan0024@gmail.com>
Maarten Lankhorst <maarten.lankhorst@linux.intel.com>
Maxime Ripard <mripard@kernel.org>
Thomas Zimmermann <tzimmermann@suse.de>
David Airlie <airlied@gmail.com>
Simona Vetter <simona@ffwll.ch>
dri-devel@lists.freedesktop.org
linux-kernel@vger.kernel.org
```

补丁前缀用 `drm/panel:`，To = Neil + Jessica + dri-devel，Cc = 其余 maintainer + linux-kernel。注意 `linux-kernel@vger.kernel.org` 在名单里但 DRI 补丁通常不必投 LKML——实际发送时按 `upstream-mail-ustc` 技能再定（本片只出草案）。

## 5. 待做 / 阻断项

### 5.1 阻断项 a)：`to_primary_dsi` 无条件改 dsi[0]（H1）——**不上游**

- 现象（pristine → clean-tree）：```diff
-	/* Sync on DSI1 for dual dsi */
-	return ctx->desc->is_dual_dsi ? ctx->dsi[1] : ctx->dsi[0];
+	/* elden's downstream command master is DSI0; the MSM manager mirrors
+	 * each write to DSI1 before triggering the DSI0 broadcast master.
+	 */
+	return ctx->dsi[0];
```
- 风险：该函数被 `novatek_prepare/unprepare` 与 `novatek_bl_ops`（`to_primary_dsi`）共用；全树唯一 desc `csot,pp8807hb1-1` 是 `is_dual_dsi=true`，改动把它（及所有复用该 desc 的板）的命令主链路从 DSI1 改成 DSI0。而 payload 并未新增 compatible（`of_device_id` 仍只有 csot 一项）⇒ 这是**把板级事实覆盖到既有面板**，会改其它双 DSI 板行为，上游必问「凭什么是 dsi0」。
- 建议方案（择一，均需新证据/设备侧验证）：
  1. **desc per-panel 字段**：`struct panel_desc { ... u8 primary_dsi; }`，`to_primary_dsi` 返回 `ctx->dsi[ctx->desc->primary_dsi]`；csot 仍填 1 保留既有板行为，elden 若确有独立 compatible 则填 0。
  2. 若真属 **DSI 控制器/manager** 行为（注释所说 “MSM manager mirrors each write to DSI1”），则归 **B5（DSI 一族）** 在 controller 侧按 per-SoC cfg 处理，而非改面板驱动。
- 结论：**本片只记录，不生成补丁**。定案前需要 (a) 确认 elden 面板 compatible 与上游 csot 是否同一颗；(b) 设备侧 DSI0/DSI1 主从取证（未上机；AGENT-OPS §3 判据在设备侧）。

### 5.2 其它待做

- [ ] 0004 的 `.enable` 检查 `panel->prepared` 是**新写法**（`grep -rn "panel->prepared" drivers/gpu/drm/panel/` 仅命中本驱动），提交时在 cover letter 说明动机（`drm_panel_prepare()` 为 void 且失败不上报，`drm_panel_enable()` 仍无条件调 `.enable`，见 `drivers/gpu/drm/drm_panel.c:149-161, 258`），请评审判断是否应在 core 层修。
- [ ] mode table 现顺序为 120/60/30/**40/24**/165/144/90（未按刷新率排序；`DRM_MODE_TYPE_PREFERRED` 仍落 index 0 = 120Hz）。若评审要求排序，单独重排（不影响本片功能）。
- [ ] 40/24Hz 与 120Hz 共用 pixel clock 915552 KHz（vtotal 10200/17000 vs 3400），符合同 pixel clock + 加长 vblank 的常规做法；数字仍待**设备侧**点亮确认（未上机）。
- [ ] 本片全部为主机侧静态/机械门结果；`AGENT-OPS §3` 要求「判据在设备侧」⇒ 未上机前不得写「已修复/已验证」，上游提交前建议先在 elden 上做一次模式切换点亮对照。

## 产物绝对路径清单 + 每条结论的验证命令

| 产物 | 路径 |
|---|---|
| 报告 | `/home/xuqianhui1001/y700-elden/reports/m3-4-display-slice-20261013.md` |
| 补丁目录 | `/home/xuqianhui1001/y700-elden/patches/upstream/m3-4-2026-10-13/`（0001–0004 + README.md） |
| 工作树 | `/home/xuqianhui1001/y700-elden/build/m3-4-worktree`（4 commit：12fede3a02 / 87ea61b4f4 / b0ed6624f2 / 4184f2efdf，detach @ 24a19b953e） |

验证命令：

```sh
# 净 diff 来源
diff -u <(git -C /home/xuqianhui1001/y700-elden/geekidos-linux show 24a19b953e:drivers/gpu/drm/panel/panel-novatek-nt36536.c) \
        /home/xuqianhui1001/y700-elden/build/m1-upstream/clean-tree/drivers/gpu/drm/panel/panel-novatek-nt36536.c

# 补丁系列 + 机械门
ls /home/xuqianhui1001/y700-elden/patches/upstream/m3-4-2026-10-13/
cd /home/xuqianhui1001/y700-elden/build/m3-4-worktree
for p in /home/xuqianhui1001/y700-elden/patches/upstream/m3-4-2026-10-13/0*.patch; do scripts/checkpatch.pl --strict --no-tree "$p"; done
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- drivers/gpu/drm/panel/

# H1 未进补丁 ⇒ 计数=1（pristine 的 to_primary_dsi 仍在）
grep -c "is_dual_dsi ? ctx->dsi\[1\]" /home/xuqianhui1001/y700-elden/build/m3-4-worktree/drivers/gpu/drm/panel/panel-novatek-nt36536.c

# 收件人
scripts/get_maintainer.pl --no-git-fallback --no-rolestats /home/xuqianhui1001/y700-elden/patches/upstream/m3-4-2026-10-13/*.patch
```
