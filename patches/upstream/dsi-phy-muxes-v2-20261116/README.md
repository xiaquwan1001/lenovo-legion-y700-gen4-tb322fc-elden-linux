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

## 4. 发送（等用户放行；本项目规矩 = 按系列逐次批准）

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

发完必做（技能 `upstream-mail-ustc` §5）：`lore-query.py "https://lore.kernel.org/linux-arm-msm/?q=f:xiaqinghuan@mail.ustc.edu.cn"`
+ 按 Message-ID 取 raw 比正文 sha256；`/lkml/`、`/dri-devel/` 各自单独核。

**AI 披露**：补丁正文里的测量与判断由作者本人复核；本目录的备料由 LLM 助手起草，
作者在发出前逐条对树/对日志核过（项目规矩 = 全局 `AGENTS.md` 上游发信三条前提）。

## 5. 顺带修正的邮件账（`q28-DOSSIER-B` §⑤-3）

- v5 四封在 **Sent Items 查不到**（`send-mail-ustc.py` 用 `smtplib` 发，不做 IMAP `APPEND`）。
  补法（只写自己的 Sent Items，零风险）：

  ```bash
  python3 - <<'PY'
  import imaplib, keyring, glob
  U="xiaqinghuan@mail.ustc.edu.cn"; M=imaplib.IMAP4_SSL("mail.ustc.edu.cn",993)
  M.login(U, keyring.get_password("smtp",U)); M.select('"Sent Items"')
  for f in sorted(glob.glob("/home/xuqianhui/y700-elden/out/mail-20261114/*.patch")):
      M.append('"Sent Items"', None, None, open(f,'rb').read())   # 需换成实际存档的 mbox/patch 原件
  M.logout()
  PY
  ```
  根治 = `send-mail-ustc.py` 在 `--send` 成功后自动 `APPEND`（未做，登记为待办）。
