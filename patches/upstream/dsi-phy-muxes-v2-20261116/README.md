# `PLL_SYSTEM_MUXES` v2（答 Dmitry 11-11 唯一意见）—— 备料状态

**目的**：v1（2026-10-19，lore `[PATCH] drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable`）
被 Dmitry 回了一句 `This belongs to the commit message rather than the code.`（INBOX uid 1723405664，
`2026-11-11 19:09:07 +0200`，MID `<e4ul4zxjta4oyo5fpjjzwkykb4gicztcn7yrgjw7aer6bqowkw@6nx2arhvmyca>`）
⇒ v2 = **把解释从源码注释搬进 commit message**，代码差异不变（一枚 `writel()`）。

## 1. 件

| 件 | 说明 |
|---|---|
| `0001-drm-msm-dsi-phy-program-PLL_SYSTEM_MUXES-on-the-firs.patch` | v2 补丁（基于 **7.4-rc3 final `aebb727447`**；`---` 下方带 `Changes in v2` + v1/评审 Link 两行，`git am` 自动剥掉） |
| `commit-msg.txt` | 提交信息原文（`git commit -F` 用过） |
| `v2-range-diff.txt` | v1（在 rc3 上重放的 `a78ffcf37c`）↔ v2 的 `git range-diff`，贴 `--compose` 封面用 |
| `v1-原件` | `../m1-2026-10-14/0001-*.patch`（v1，含被删的那段注释） |

## 2. 门禁（全部本轮实测）

| 门禁 | 结果 |
|---|---|
| v1 在 7.4-rc3 上 `git am` | **rc=0**（⇒ v1 时代「master 已有等价写入」的怀疑**不成立**，delta 仍在） |
| v2 在 7.4-rc3 上 `git am` | **rc=0**（`/tmp/base-wt` `19d4b7bd3d`，`+1` 行；注释段被剥掉，`grep -c "Changes in v2"` = 0） |
| `checkpatch.pl --strict --no-tree` | **0 error**；4→3 条 warning 全是 `Unknown commit id 'cb55f39bf7b1' / '93c97bc8d85d'` |
| 「Unknown commit id」判读 | **本地浅树假阴性**（`build/daily` 只有 6 层历史，`git rev-list --count HEAD` = 6）。已按 GitHub API 对 mainline 核实：`cb55f39bf7b1e687b88dc9825c21a7d3454b5acb` = `drm/msm/dsi/phy: Fix reading zero as PLL rates when unprepared`（Krzysztof Kozlowski，2025-09-08），`compare/cb55f39bf7b1...master` = `status: ahead, behind_by: 0`（⇒ 是 master 祖先）；`93c97bc8d85d` = `drm/msm: dsi: fix PLL init in bonded mode`；`44784327815b` 在本地可读 = `Revert "drm/msm: dsi: fix PLL init in bonded mode"` |
| 构建 + 在机运行 | **由 vk192 承担**：`git show vk192:drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c` 第 1155 行 = 与 v2 **逐字相同**的 `writel(0xc0, pll->phy->pll_base + REG_DSI_7nm_PHY_PLL_SYSTEM_MUXES);`（v2 只删注释块），vk192 = 当前在机持久件（s2idle 3/3、全绿） |
| 寄存器实测（v1 期） | `phy_enable` 预置时 `muxes=0x0`；打补丁后面板使能处读回 `0xc0`，`dsi_isr(host0)=41`（坏发 0）→ `reports/m1-73-e1-pllfix-20261014.md` §1、`reports/m1-73-e1b-pllfix-20261014.md` |

## 3. v2 相对 v1 的两处改动

1. **注释 → 提交信息**（Dmitry 意见）。代码从 `+9` 行变 `+1` 行。
2. **`Fixes:` 换靶**：v1 指 `44784327815b`（且**标题写错**成 `"drm/msm/dsi: phy: rework PLL bias enable/disable"`，
   该 commit 真实标题是 `Revert "drm/msm: dsi: fix PLL init in bonded mode"` ⇒ 当时 checkpatch 就报 `FIXES_TAG`，
   见 `reports/code-style-and-duty-overlap-audit-20261030.md` A1-01）。
   v2 指 **`cb55f39bf7b1`**（引入计数器 + 预置的那枚）；revert 只在正文里叙述（用 checkpatch 要求的 `commit <sha> ("<title>")` 格式）。

## 4. 发送 —— ✅ 已投（2026-11-16 22:50 / 23:03 两发，均 `Result: 250`）

| 时刻 | 件 | Subject | Message-ID | 说明 |
|---|---|---|---|---|
| 22:50:20 | `0001-drm-msm-dsi-phy-…firs.patch` | `[PATCH]`（**前缀漏 v2**） | `20261116145020.54586-1-…` | 13 RCPT 全 250，账 = `40-sent.txt` / `logs-v2-send.log` |
| 23:03:34 | `0001-v2-sent.patch` | `[PATCH v2]`（正确） | `20261116150334.78710-1-…` | 正文多 4 行自述「上一封前缀错了、内容相同」；账 = `logs-v2-resent.log` |

两封 `In-Reply-To` 都是 Dmitry 的 `<e4ul4zxjta4oyo5fpjjzwkykb4gicztcn7yrgjw7aer6bqowkw@6nx2arhvmyca>`。

**归档复核（2026-11-17 早，`scripts/lore-fetch-raw.py` 逐列表取 raw）**：
`linux-arm-msm` 8729 B / `linux-kernel` 8722 B / `dri-devel` 8016 B **三处均命中** `20261116150334.78710-1-…`，
`Subject` 均为 `[PATCH v2] drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY`。
逐字节：lore raw 从 `diff --git` 起整段与本地 `0001-v2-sent.patch` **完全相同**（624 B = 624 B）；
头部差异仅归档追加的 `Received:`/`X-Mailing-List:` 等，属正常。错前缀那封同在 `/linux-arm-msm/` 归档（8555 B）。

```bash
scripts/lore-fetch-raw.py all 20261116150334.78710-1-xiaqinghuan@mail.ustc.edu.cn -o /tmp/lore-dsi-phy
scripts/lore-fetch-raw.py lkml 20261116150334.78710-1-xiaqinghuan@mail.ustc.edu.cn -o /tmp/lore-lkml
scripts/lore-fetch-raw.py dri-devel 20261116150334.78710-1-xiaqinghuan@mail.ustc.edu.cn -o /tmp/lore-dri
```

**待办 = 等 Dmitry 回 v2**（他会看到同内容两份，第二封自述）。

原始发送命令（备查）：

```bash
cd /tmp/muxes-v2   # 或任意 worktree；只要件在
git send-email --confirm=never --no-annotate --suppress-from \
  --to=linux-arm-msm@vger.kernel.org --to=dri-devel@lists.freedesktop.org \
  --cc=freedreno@lists.freedesktop.org --cc=linux-kernel@vger.kernel.org \
  --cc=robin.clark@oss.qualcomm.com --cc=lumag@kernel.org --cc=abhinav.kumar@linux.dev \
  --cc=jesszhan0024@gmail.com --cc=sean@poorly.run --cc=marijn.suijten@somainline.org \
  --cc=dmitry.baryshkov@oss.qualcomm.com \
  --in-reply-to="<e4ul4zxjta4oyo5fpjjzwkykb4gicztcn7yrgjw7aer6bqowkw@6nx2arhvmyca>" \
  ~/y700-elden/patches/upstream/dsi-phy-muxes-v2-20261116/0001-*.patch
```

发完必做（技能 `upstream-mail-ustc` §5）= 上面「归档复核」已做完（三列表 + 正文逐字节）。
注意：lore 直连 `curl` 现在回 **403**（Anubis），只能走 `scripts/lore-fetch-raw.py`。

**AI 披露**：补丁正文里的测量与判断由作者本人复核；本目录的备料由 LLM 助手起草，
作者在发出前逐条对树/对日志核过（项目规矩 = 全局 `AGENTS.md` 上游发信三条前提）。

## 5. 顺带修正的邮件账（`q28-DOSSIER-B` §⑤-3）

- v5 四封在 **Sent Items 查不到**（`send-mail-ustc.py` 走 `smtplib`，不做 IMAP `APPEND`）。
  **根治已落地（2026-11-17）= `scripts/mail-append-sent.py`**（默认 dry-run，`--check` 只查缺，`--apply` 才写）：

  ```bash
  scripts/mail-append-sent.py --check out/mail-20261114/*.mbox   # 列出 Sent Items 缺哪些 Message-ID
  scripts/mail-append-sent.py --apply out/mail-20261114/*.mbox   # 只补缺的，已存在的跳过
  ```
