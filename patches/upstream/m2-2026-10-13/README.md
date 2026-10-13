# M2 上游首发（2026-10-13）

> 基线 = **upstream v7.3-rc7**（`24a19b953e`）；工作树 `build/m2-worktree`（分支 `m2/series`）。
> 生成与验证：`git format-patch -1 --no-numbered`；`scripts/checkpatch.pl --strict --no-tree` = **0 errors / 0 warnings**；
> 两目标文件在 v7.3-rc7 配置下 **编译干净**（`aarch64-linux-gnu-gcc`，仅 CC 行、无 warning）。

## 补丁

| # | 文件 | 提交 | 收件人 |
|---|---|---|---|
| 1 | `0001-drm-msm-dpu-add-the-missing-GC-block-to-the-SM8750-D.patch` | `8d70ccd476` | To: `dri-devel@lists.freedesktop.org`, `linux-arm-msm@vger.kernel.org`；Cc: `freedreno@lists.freedesktop.org` + Rob Clark / Dmitry Baryshkov / Abhinav Kumar / Jessica Zhang / Sean Paul / Marijn Suijten |
| 2 | `0001-power-supply-qcom_battmgr-do-not-report-power_now-on.patch` | `9995d8a131` | To: `linux-pm@vger.kernel.org`, `Sebastian Reichel <sre@kernel.org>`；Cc: `linux-arm-msm@vger.kernel.org`, `linux-kernel@vger.kernel.org` |

两枚补丁**互不相关**，各自单独成帖（不做 series、不带 cover letter）。

## 投递结果（2026-10-13 08:21 +0800，已发送）

| 补丁 | Message-ID | 归档复核（独立取 raw） |
|---|---|---|
| 1 DPU | `20261013002124.332074-1-xiaqinghuan@mail.ustc.edu.cn` | `/linux-arm-msm/` OK；`dri-devel`/`freedreno` 在 lore 无该 inbox（归档在 lists.freedesktop.org，未复核） |
| 2 battmgr | `20261013002124.332111-1-xiaqinghuan@mail.ustc.edu.cn` | `/linux-pm/` + `/linux-arm-msm/` + `/lkml/` 均 OK |

正文 canonical body sha256：patch1 `b8fu5G/OnuGOyXYY…`、patch2 `xg0wufdtQ6dk83lO…`（16 字符前缀，取自归档 raw）。

## 发送命令（dry-run 已通过；实际发送加 `--confirm=never`）

```bash
cd build/m2-worktree
git send-email --no-thread \
  --to=dri-devel@lists.freedesktop.org --to=linux-arm-msm@vger.kernel.org \
  --cc=freedreno@lists.freedesktop.org \
  --cc='Rob Clark <robin.clark@oss.qualcomm.com>' --cc='Dmitry Baryshkov <lumag@kernel.org>' \
  --cc='Abhinav Kumar <abhinav.kumar@linux.dev>' --cc='Jessica Zhang <jesszhan0024@gmail.com>' \
  --cc='Sean Paul <sean@poorly.run>' --cc='Marijn Suijten <marijn.suijten@somainline.org>' \
  out-m2/0001-drm-*.patch

git send-email --no-thread \
  --to=linux-pm@vger.kernel.org --to='Sebastian Reichel <sre@kernel.org>' \
  --cc=linux-arm-msm@vger.kernel.org --cc=linux-kernel@vger.kernel.org \
  out-m2/0001-power-*.patch
```

## A3 为何没进首发（重要更正）

审查档案把 A3 记为「aw86927 SRAM 窗口 0x1000→0x2000」，但**上游 v7.3-rc7 的 `drivers/input/misc/aw86927.c` 根本没有 firmware waveform 装载路径**
（882 行，无 `request_firmware()`、无 `aw86927_ram_load()`、无 `AW86937` 型号）：那段代码是我们树自己的实现。
因此 A3 的窗口放宽**在上游没有对应代码可以修补**；要上行必须先走「firmware 波形装载」这个功能的 RFC（含 DT 属性），或在我们的驱动里继续带。**本项重分类为 B/C 级，不进 M2。**

## 后续

- 订阅状态：`linux-arm-msm`（已有）、`linux-pm`（用户 2026-10-13 已订）；`dri-devel`/`freedreno` 在 lists.freedesktop.org，投递后将按 Message-ID 到 lore 复核（dri-devel 在 lore 有 inbox：`/dri-devel/`）。
- 发出后 24–48 h：`~/.local/bin/lore-query.py` 或 `read-mail-ustc.py --replies-only` 复核归档与回信。
- 反馈应对：DPU 补丁可能被要求改成 `Fixes:` 标签或调整注释；battmgr 补丁可能被要求改为显式属性和/或提供 QBG 固件侧依据。
