# dpu gamma LUT 校验 —— 发信就绪版（**v2**，2026-11-17）

> 状态：**备料完成、未发**（等用户按系列放行）。原件 `../dpu-gamma-lut-v2-20261113/` 未改动。
> 报告：`reports/主机侧-发信备料1-20261117.md` §2。

## 1. 版本 = v2（已核）

- v1 = patchwork `14884121`（2026-10-13，`[PATCH] drm/msm/dpu: reject undersized gamma LUT blobs`，MID `20261013020425.408928-1-…`）。
- Dmitry 2026-11-11T16:58Z 给 `Reviewed-by` 并要求补 `Fixes: 39a750ff5fc9 ("drm/msm/dpu: Add DSPP GC driver to provide GAMMA_LUT DRM property")`
  （`<h346otfneexdgpndvmydknzuxuljywvflaoss3xppblp4k2svo@wcanozcwnysb>`）。
- ⇒ 本轮 = v2；`Subject: [PATCH v2]` **原始件即正确，未改**。

## 2. 相对上一版（v1）改了什么（正文已自述）

`---` 下方原文：

```
v2: only the commit message changed (added the Fixes: tag asked for in
    <h346otfneexdgpndvmydknzuxuljywvflaoss3xppblp4k2svo@wcanozcwnysb>);
    the diff is byte-identical to v1.
```

- 只加 `Fixes:`，保留 Dmitry 的 `Reviewed-by`；**diff 与 v1 逐字节相同**（15 行，同一 hunk）。
- 单枚无 cover（v1 也无 cover）。

## 3. 门禁（本轮实测 2026-11-17 12:38，基线 `/tmp/mailbase-wt` = `666539eecd`）

| 门 | 命令 | 结果 |
|---|---|---|
| `git apply --check` | `git -C /tmp/mailbase-wt apply --check <0001>` | **rc=0** |
| `checkpatch --strict --no-signoff` | `cd /tmp/mailbase-wt && perl scripts/checkpatch.pl --strict --no-signoff <0001>` | **0E / 1W / 0C**（21 行） |
| 收件人 | `perl scripts/get_maintainer.pl --no-rolestats <0001>` | rc=0（另有 `git rev-parse 39a750ff5fc9` 的 stderr，属浅/截断历史的噪音，不影响名单） |
| 发送干跑 | §4 原命令 + `--dry-run` | **Result: OK**，Subject `[PATCH v2] …` |

唯一 W = `Unknown commit id '39a750ff5fc9'`，**环境性假阳性**：门禁树只有 42040 个提交（历史被截断，无该对象）。
已用 GitHub API 反向核实（2026-11-17 本轮）：

```bash
curl -s https://api.github.com/repos/torvalds/linux/commits/39a750ff5fc9   # → "drm/msm/dpu: Add DSPP GC driver to provide GAMMA_LUT DRM property"
```

⇒ `Fixes:` 指向的提交真实存在且标题一致；加 `--ignore UNKNOWN_COMMIT_ID` 后 **0E / 0W / 0C**。

## 4. 发送命令（**exact**，已 `--dry-run` 验证）

```bash
cd /tmp/mailbase-wt
timeout -k 5 120 git send-email --confirm=never --no-annotate --suppress-from \
  --to=dri-devel@lists.freedesktop.org --to=linux-arm-msm@vger.kernel.org \
  --cc=freedreno@lists.freedesktop.org --cc=linux-kernel@vger.kernel.org \
  --cc=robin.clark@oss.qualcomm.com --cc=lumag@kernel.org --cc=abhinav.kumar@linux.dev \
  --cc=jesszhan0024@gmail.com --cc=sean@poorly.run --cc=marijn.suijten@somainline.org \
  /home/xuqianhui/y700-elden/patches/upstream/dpu-gamma-lut-v2-20261113-sent-20261117/0001-*.patch
```

先加 `--dry-run` 验一遍（`Result: OK` 后再实发）。`--no-thread` 不需要（1 枚）。

## 5. 收件人（get_maintainer 现算）

To：`dri-devel@lists.freedesktop.org`、`linux-arm-msm@vger.kernel.org`
Cc：`freedreno@lists.freedesktop.org`、`linux-kernel@vger.kernel.org`、Rob Clark <robin.clark@oss.qualcomm.com>、
Dmitry Baryshkov <lumag@kernel.org>、Abhinav Kumar <abhinav.kumar@linux.dev>、Jessica Zhang <jesszhan0024@gmail.com>、
Sean Paul <sean@poorly.run>、Marijn Suijten <marijn.suijten@somainline.org>

> get_maintainer 还列了 David Airlie / Simona Vetter / Krzysztof Kozlowski(oss) / Martin K. Petersen / Maxime Ripard
> （来自顶层 DRM/树维护者规则）；沿用 v1 的投递惯例不 Cc 这几类顶层维护者，仅 Cc 上表 8 人。

## 6. 与另一枚「dpu GC 块」补丁的消歧

**不是** `../m2-2026-10-13/0001-…missing-GC-block…`（那枚已于 2026-10-13 自行撤稿，与已合入的 `3389406e6a03` 逐字重复）。
本枚只加运行时 LUT 长度校验。7.4-rc3/master 上 `_dpu_crtc_get_gc_lut()` 仍无条件按 `PGC_TBL_LEN` 读 `lut[]`。

## 7. AI 披露

补丁正文与测量/决定由作者本人复核；本目录与报告由 LLM 助手起草，作者在发出前逐条对树核对。
