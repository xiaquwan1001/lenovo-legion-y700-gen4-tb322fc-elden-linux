# dpu gamma LUT 校验 v2（B5 / A2 备料）— 2026-11-13

> 状态：**v2 草案就绪，未发送**（发信 = A2，需用户放行）。
> 基线：`gh/master` = `9d66f26fef`（7.4-rc3 线，2026-11-11）。门禁在 `/tmp/g74`（该 tree 的一次性导出）
> 做完，仓库内不留工作树。

## 0. 这是哪一枚补丁（先消歧，重要）

`reports/mail-triage-20261112.md` §3.1 T3 记的名字是「drm/msm/dpu gamma LUT」，容易被读成
「给 sm8750 补 GC 块」那枚（`patches/upstream/m2-2026-10-13/0001-…missing-GC-block…`）。**不是它。**

- 本项 = patchwork **`14884121`**，series **1184466**，标题
  `drm/msm/dpu: reject undersized gamma LUT blobs`（v1，2026-10-13T02:04:25Z，
  MID `<20261013020425.408928-1-xiaqinghuan@mail.ustc.edu.cn>`），改的是
  `drivers/gpu/drm/msm/disp/dpu1/dpu_crtc.c`（15 行，`dpu_crtc_atomic_check()` 里加精确长度校验）。
- Dmitry 2026-11-11T16:58:23Z 在 `https://patchwork.kernel.org/comment/27361985/`
  （MID `<h346otfneexdgpndvmydknzuxuljywvflaoss3xppblp4k2svo@wcanozcwnysb>`）
  给了 `Reviewed-by` **并要求补** `Fixes: 39a750ff5fc9 ("drm/msm/dpu: Add DSPP GC driver to provide GAMMA_LUT DRM property")`。
- 那枚「补 sm8750 GC 块」的补丁**已于 2026-10-13 自行撤稿**（与已合入 msm 树的 `3389406e6a03` 逐字重复，
  见 `patches/upstream/m2-2026-10-13/README.md` 顶部警告）；**7.4-rc3 的 `dpu_hw_catalog.c:428-433`
  已经有 sm8750 的 `.gc = {.base = 0x17c0, .len = 0x40, .version = 0x10008}`**，不需要再发。

## 1. 产物

| 文件 | 说明 |
|---|---|
| `0001-drm-msm-dpu-reject-undersized-gamma-LUT-blobs.patch` | v2；**diff 与 v1 逐字节相同**，只有 commit message 变了（加 `Fixes:`，保留 Dmitry 的 `Reviewed-by`） |

`Fixes:` 的 sha 与标题取自 Dmitry 原话；其对应的上游系列是 Federico Amedeo Izzo 的
「drm/msm/dpu: Add DSPP GC driver to provide GAMMA_LUT DRM property」（patchwork v3，2025-10-19，
`https://patchwork.kernel.org/project/dri-devel/list/?q=DSPP+GC+driver`），故 sha 可信。

## 2. 门禁（本机实测，2026-11-13）

| 门禁 | 命令 / 环境 | 结果 |
|---|---|---|
| `git am` | `/tmp/g74`（= `gh/master` `9d66f26fef` 的 source 导出 + 一个 base 提交），`git am --3way` | **rc=0，1/1 应用**，得提交 `e2833dc8b0`（`1 file changed, 15 insertions(+)`） |
| `checkpatch --strict` | `/tmp/g74/scripts/checkpatch.pl --strict --no-tree` | 原始 **0E / 1W / 0C**；唯一 W = `Unknown commit id '39a750ff5fc9'`（门禁树是**浅仓库**，没有该对象，属环境性）<br>`--ignore UNKNOWN_COMMIT_ID` ⇒ **0E / 0W / 0C**（21 行） |
| 目标文件编译 | `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j26 W=1 drivers/gpu/drm/msm/disp/dpu1/dpu_crtc.o`（config = 本仓 `build/m3v2-7.3rc7/.config` 的副本，`CONFIG_DRM_MSM=y`，`LOCALVERSION=""`） | **rc=0，0 warning / 0 error**，`dpu_crtc.o` 生成（704 184 B） |

行号差异说明：v1 是在 7.3-rc7 上生成的（hunk `@@ -1534,6 +1534,21 @@`），7.4-rc3 里同函数在 `:1522`
起，`bool needs_dirtyfb = …` 在 `:1536` ⇒ 上下文逐字吻合，`git am` 只做偏移，**不需改行**。

## 3. 建议

**发 v2。** 理由：Dmitry 已给 RV 且明确只要一个 `Fixes:` 标签；补丁在 7.4-rc3 上仍未修
（`_dpu_crtc_get_gc_lut()` 依旧无条件按 `PGC_TBL_LEN` 读 `lut[]`），语义未被上游吸收。
投递方式沿用 v1（To `dri-devel@lists.freedesktop.org` + `linux-arm-msm@vger.kernel.org`，
Cc `freedreno@…` + Rob Clark / Dmitry / Abhinav / Jessica / Sean Paul / Marijn，
见 `patches/upstream/m2-2026-10-13/README.md` 的收件人表），`--no-thread` 单发。
