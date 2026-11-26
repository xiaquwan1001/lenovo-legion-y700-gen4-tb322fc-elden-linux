# M6 dsi/phy `PLL_SYSTEM_MUXES` v3 —— 备料目录（2026-11-26）

> **状态：待发（未投）。** 真发需按 `TASKS/README.md` §7「按系列逐次批准」批准后
> `bash SEND.sh --yes`。本目录只备料，本轮**不发邮件、不 git commit、不改 TASKS/**。

## 1. 时间线

| 版本 | 日期 | 事件 |
|---|---|---|
| v1 | 2026-10-19 | lore `20261019130041.305805-1-xiaqinghuan@mail.ustc.edu.cn`（原件 `../m1-2026-10-14/`） |
| — | 2026-11-11 | Dmitry 回唯一一句：解释应进 commit message 而非代码注释（`<e4ul4zxjta4oyo5fpjjzwkykb4gicztcn7yrgjw7aer6bqowkw@6nx2arhvmyca>`） |
| v2 | 2026-11-16 / 11-17 | 注释搬进 commit message、`Fixes:` 换靶 `cb55f39bf7b1`；实际投递 lore MID `20261117052047.32129-1-xiaqinghuan@mail.ustc.edu.cn`（`../m6-dsi-pll-v2-20261113-sent-20261117/`） |
| — | 2026-11-26T03:23Z | **Jianfeng Liu（小米 Pad 5 Pro）在 lore 线程回 `Tested-by`**（线程 `20261117052047.32129-1`） |
| v3 | 2026-11-26 | 本目录：代码零改动，只加 Tested-by，重建线程 |

## 2. 为何 v3 / 改了什么

- **代码零改动**：v3 的 `diff --git` 段与 v2 sent 件**逐字节相同**（`cmp` 证明，见
  `reports/m6-dsi-phy-v3-20261126.md`）。commit message 正文也未动。
- **新增**：`Signed-off-by:` 之后紧跟 `Tested-by: Jianfeng Liu <liujianfeng1994@gmail.com>`
  （小米 Pad 5 Pro，2026-11-26T03:23Z lore 回信）。
- **`---` 线下**：新增 `Changes since v2` 段（无代码改动 / 新 Tested-by / 为何重发）；
  保留 v2 的 `Changes in v2` 段与三条 `Link:`（v1、Dmitry 评审、v2 lore MID）。
- **`Subject:`** 改为 `[PATCH v3]`。Message-ID 由 git send-email 发送时自动生成，本目录不预写。

## 3. 投递形态（已选定并写进 SEND.sh）：新线程

**选 ① 新线程（无 `--in-reply-to`）**。理由：Jianfeng 在回信中指出 2026-11-17 v2 那封信
thread 断裂 / subject 空——挂到一条在某些客户端看不到 subject 的坏线程上，反而让 v3 更难被
检索与 patchwork 收录；v3 补丁自带完整版本史（`Changes since v2` + `Link:` 三条），
新线程 + 自述即可让评审者还原上下文。正文 `Changes since v2` 已写明「v2 线程断裂，本版重建线程」。

## 4. 件

| 件 | 说明 |
|---|---|
| `0001-drm-msm-dsi-phy-program-PLL_SYSTEM_MUXES-on-the-firs.patch` | v3 补丁（v2 sent 件为唯一内容来源，仅改 Subject 前缀 / 加 Tested-by / `---` 下新段） |
| `SEND.sh` | 投递脚本，**默认 dry-run**，含件存在 / v3 前缀 / Tested-by 紧跟 Signed-off-by / mailinfo / 新线程（无 In-Reply-To）等逐封断言 |
| `README.md` | 本文件 |

v2 原件（内容来源）：`../m6-dsi-pll-v2-20261113-sent-20261117/0001-…firs.patch`
（与 `../dsi-phy-muxes-v2-20261116/0001-v2-sent.patch` 的 diff 段 cmp 相同，md5 `656f0f2cf25b1c7becafb9a64be48e6d`）。

## 5. 门禁（2026-11-26 实测，原始输出见 `reports/m6-dsi-phy-v3-20261126.md`）

| 门 | 命令 | 结果 |
|---|---|---|
| apply | `git -C build/elden-tree apply --check <v3>` | **rc=0** |
| checkpatch | `perl scripts/checkpatch.pl --strict --no-signoff --no-tree <v3>`（在 `~/elden-cache/src/geekidos-linux`，146 万提交全历史） | **0 errors / 0 warnings / 0 checks** |
| send 干跑 | `bash SEND.sh`（默认 dry-run） | 全断言 OK，13 RCPT，`Result: OK` |

注意：checkpatch 必须在**有完整提交历史的树**里跑——`/tmp/base-wt` 是死 worktree，
commit-title 反查全失败会报假 3E/1W；geekidos-linux 全历史下真值即 0E/0W（三个 sha
`cb55f39bf7b1`/`93c97bc8d85d`/`44784327815b` 均可反查）。

## 6. AI 披露

补丁正文与测量/决定由作者本人复核；本备料目录由 LLM 助手起草，作者发出前逐条对树核对
（项目规矩 = 全局 `AGENTS.md` 上游发信三条前提）。
