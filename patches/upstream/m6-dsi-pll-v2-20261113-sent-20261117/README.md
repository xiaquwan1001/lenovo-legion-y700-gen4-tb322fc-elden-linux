# dsi/phy PLL_SYSTEM_MUXES —— **已发**（v2，2026-11-16）的归档副本（2026-11-17 归集）

> **状态：已投，禁止重发。** 本目录不是「待发备料」，而是把**真正发出去的那一版**归档到「-sent-20261117」命名下，
> 供核对/回信引用。原件 `../m6-dsi-pll-v2-20261113/` 未改动。
> 报告：`reports/主机侧-发信备料1-20261117.md` §3。

## 0. 重要消歧：本目录的补丁 ≠ 原目录的补丁

| 路径 | 是什么 |
|---|---|
| `../m6-dsi-pll-v2-20261113/0001-…on-the-fi.patch` | 11-13 的**草案**：`Fixes: 44784327815b`（指 revert）、代码里带一行注释、`+2` 行 |
| `../dsi-phy-muxes-v2-20261116/0001-v2-sent.patch` | **实际投递**的那一版（11-16 23:03 `[PATCH v2]`）：`Fixes: cb55f39bf7b1`、无行内注释、`+1` 行、正文带测量证据 + 两行 `Link:` |
| 本目录 `0001-drm-msm-dsi-phy-program-PLL_SYSTEM_MUXES-on-the-firs.patch` | = 上一行那份 **sent 件的副本**（md5 一致：`656f0f2cf25b1c7becafb9a64be48e6d`） |

理由：任务要求「发信要用的那一版」，而这个系列**已经发过**；把未发的旧草案放进 sent 目录会误导后续 lane
重复投递或引用错 `Fixes:`。原始草案仍原样留在 `../m6-dsi-pll-v2-20261113/`。

## 1. 投递账（已闭环，勿重发）

| 时刻（UTC） | Subject | Message-ID | 结果 |
|---|---|---|---|
| 2026-11-16 14:50:20 | `[PATCH]`（**前缀漏 v2，属错误**） | `20261116145020.54586-1-…` | 13 RCPT 全 250 |
| 2026-11-16 15:03:34 | `[PATCH v2]`（正确，正文自述前一封前缀有误、内容相同） | `20261116150334.78710-1-…` | 250；`linux-arm-msm`/`linux-kernel`/`dri-devel` 三处归档逐字节一致 |

两封 `In-Reply-To` = Dmitry 的 `<e4ul4zxjta4oyo5fpjjzwkykb4gicztcn7yrgjw7aer6bqowkw@6nx2arhvmyca>`。
账见 `../dsi-phy-muxes-v2-20261116/{40-sent.txt,logs-v2-send.log,logs-v2-resent.log,README.md}`。
v2 投出后 **0 回**（`reports/upstream-replies-20261117.md` §1.2）。

## 2. 相对上一版（v1）改了什么（正文已自述）

```
Changes in v2: move the explanation out of the source comment and into the
commit message, as requested; the code delta is the same single writel().
Fixes: is re-pointed at cb55f39bf7b1, which introduced both the counter and
the pre-seed, instead of at the revert that restored them.
```

（v1：`../m1-2026-10-14/0001-…`，patchwork `14901898`，`+9` 行含注释块、`Fixes: 44784327815b` 且标题写错。）

## 3. 门禁（本轮对**归档件**在 `/tmp/mailbase-wt` = `666539eecd` 上重跑，2026-11-17 12:38）

| 门 | 命令 | 结果 |
|---|---|---|
| `git apply --check` | `git -C /tmp/mailbase-wt apply --check <0001>` | **rc=0** |
| `checkpatch --strict --no-signoff` | `cd /tmp/mailbase-wt && perl scripts/checkpatch.pl --strict --no-signoff <0001>` | **0E / 3W / 0C**（3W 全是 `Unknown commit id`：`cb55f39bf7b1`×2、`93c97bc8d85d`） |
| 收件人 | `perl scripts/get_maintainer.pl --no-rolestats <0001>` | rc=0，名单同 §5 |
| 发送干跑 | §5 原命令 + `--dry-run` | **Result: OK**（若将来确需重发才用；当前**不要**用） |

W 判读 = **环境性假阳性**（门禁树仅 42040 个提交，历史截断）。本轮用 GitHub API 反向核实三个 sha：

```bash
curl -s https://api.github.com/repos/torvalds/linux/commits/cb55f39bf7b1   # → "drm/msm/dsi/phy: Fix reading zero as PLL rates when unprepared"
curl -s https://api.github.com/repos/torvalds/linux/commits/93c97bc8d85d   # → "drm/msm: dsi: fix PLL init in bonded mode"
git -C /tmp/mailbase-wt cat-file -t 44784327815b                          # → commit（revert 在树内可读）
```

`--ignore UNKNOWN_COMMIT_ID` 后 **0E / 0W / 0C**。

## 4. 与「上游已覆盖 ⇒ retire」的关系

复核结论仍为**不成立**（逐行证据见 `../m6-dsi-pll-v2-20261113/README.md` §1：`dsi_phy_7nm.c:429` 早退 +
`:1094` 预置 `pll_enable_cnt = 1`）。v2 已在 11-16 发出，本目录只是归档。

## 5. 收件人 / 发送命令（**仅存档**，当前勿重发）

To：`dri-devel@lists.freedesktop.org`、`linux-arm-msm@vger.kernel.org`
Cc：`freedreno@lists.freedesktop.org`、`linux-kernel@vger.kernel.org`、Rob Clark <robin.clark@oss.qualcomm.com>、
Dmitry Baryshkov <lumag@kernel.org>、Abhinav Kumar <abhinav.kumar@linux.dev>、Jessica Zhang <jesszhan0024@gmail.com>、
Sean Paul <sean@poorly.run>、Marijn Suijten <marijn.suijten@somainline.org>（与 11-16 实发一致）

```bash
cd /tmp/mailbase-wt
timeout -k 5 120 git send-email --confirm=never --no-annotate --suppress-from \
  --to=dri-devel@lists.freedesktop.org --to=linux-arm-msm@vger.kernel.org \
  --cc=freedreno@lists.freedesktop.org --cc=linux-kernel@vger.kernel.org \
  --cc=robin.clark@oss.qualcomm.com --cc=lumag@kernel.org --cc=abhinav.kumar@linux.dev \
  --cc=jesszhan0024@gmail.com --cc=sean@poorly.run --cc=marijn.suijten@somainline.org \
  --in-reply-to="<e4ul4zxjta4oyo5fpjjzwkykb4gicztcn7yrgjw7aer6bqowkw@6nx2arhvmyca>" \
  /home/xuqianhui/y700-elden/patches/upstream/m6-dsi-pll-v2-20261113-sent-20261117/0001-*.patch
```

## 6. AI 披露

补丁正文与测量/决定由作者本人复核；本目录与报告由 LLM 助手起草，作者在发出前逐条对树核对。
