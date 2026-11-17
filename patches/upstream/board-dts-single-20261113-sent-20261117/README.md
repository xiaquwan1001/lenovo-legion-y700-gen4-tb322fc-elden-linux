# elden 板 DTS 单提交 —— 发信就绪版（**v7**，2026-11-17）

> 状态：**备料完成、未发**（发信需用户逐系列放行；本 lane 未发信、未 commit、未碰设备）。
> 原件 `../board-dts-single-20261113/` **未改动**；本目录是「发信要用的那一版」。
> 报告：`reports/主机侧-发信备料1-20261117.md` §1。

## 1. 版本号为什么是 v7（不是 v1、不是 v2）

| 事实 | 指针 |
|---|---|
| 板 DTS 上一次投递 = **v6 系列 4/5 + 5/5**（2026-11-04 03:26Z，`[PATCH v6 4/5]`/`[PATCH v6 5/5]`） | `../wl2868c-20261104-v6/README.md` |
| Krzysztof 对 5/5 的裁决：*"I do not understand why this is a separate patch. You add new hardware, so the commit is 'add new hardware'. One logical action, one commit."* | `<20261104-elfish-booby-of-awe-27d2b6@quoll>`（`reports/mail-triage-20261105.md` 第 7 行） |
| 此后板 DTS **再未投递**（v7/v8/v9 的 `wl2868c-*` 目录只含 regulator binding+driver，无板 DTS） | `../wl2868c-v7-20261106/`、`../wl2868c-v9-20261107/`、`../wl2868c-v11-20261113/` 文件清单 |
| 上游主线 `lenovo,elden` 0 命中 ⇒ 尚未被任何人的版本吸收 | `reports/upstream-replies-20261117.md` §5 |

⇒ 本轮是**同一系列的续版**（内容 = v6 的 4/5+5/5 合并），编号续 **v7**，单枚无 cover。

## 2. 相对上一版（v6 4/5+5/5）改了什么

1. **两枚合成一枚**（Krzysztof 的 one-logical-action 意见）：板骨架 + WL2868C 稳压器节点同在一个提交里。
   合并在 7.4-rc2 基点 `f66469d990` 上按 4/5→5/5 顺序 apply 后取 `git diff` 生成 ⇒ **树与 v6 两枚顺序应用完全一致**，无内容增删。
2. **标题/前缀**：`[PATCH]` → `[PATCH v7]`；标题沿用 Krzysztof 给的措辞（"add Lenovo Legion Y700 Gen4, a Qualcomm SM8750-based tablet"）。
3. **`---` 下方新增 `Changes in v7`**（两段 ASCII），并把 v6 线程里仍开放的两点（无 SPMI PMIC/RPMh/console 的「骨架板」判定）如实写进去。
4. 正文（commit message 上半部）与 v6 4/5 的说明文字一致，只补了「LDO6 未引出」之外无新论断。

## 3. 门禁（本轮实测，2026-11-17 12:38，基线 `/tmp/mailbase-wt` = master tip `666539eecd`）

| 门 | 命令 | 结果 |
|---|---|---|
| `git apply --check` | `git -C /tmp/mailbase-wt apply --check <本目录 0001>` | **rc=0** |
| `checkpatch --strict --no-signoff` | `cd /tmp/mailbase-wt && perl scripts/checkpatch.pl --strict --no-signoff <本目录 0001>` | **0E / 3W / 0C**（136 行） |
| 收件人 | `perl scripts/get_maintainer.pl --no-rolestats <0001>` | rc=0，见 §4 |
| 发送干跑 | `git send-email --dry-run …`（§4 原命令） | **Result: OK**，Subject 解折行正确 |

3 条 W 全为**树内缺件**，不是补丁文字问题（必须知道，直接影响能不能现在发）：

| # | W 原文 | 判读 |
|---|---|---|
| 1 | `added, moved or deleted file(s), does MAINTAINERS need updating?` | qcom 板级 dts 已由现有 MAINTAINERS 覆盖，提示性 |
| 2 | `DT compatible string "lenovo,elden" appears un-documented` | `Documentation/…/bindings/arm/qcom.yaml` 里还没有这一行（v6 3/5 那枚**没进后续系列**） |
| 3 | `DT compatible string "willsemi,wl2868c" appears un-documented` | `willsemi,wl2868c.yaml` 仍在飞（`../wl2868c-v11-20261113/v11-0001-*.patch` 未合） |

**结论（发信前提，必须在放行时一起决定）**：本枚**不能裸发**。两条路：
(a) 与 binding 两枚同批发（`../wl2868c-v11-20261113/v11-0001` + `../wl2868c-20261104-v6/v6-0003` 的 qcom.yaml 一行），
(b) 等 binding 合入后再单发。裸发会让 `dtbs_check`/checkpatch 直接指出两个未文档化 compatible，且 v6 线程里
Krzysztof/sashiko/Konrad 已同向质疑「骨架板 DT 别单发」（`archive/topics/upstream/upstream-status-20261105.md` v7 条件行）。

## 4. 发送命令（**exact**，已 `--dry-run` 验证；实发需用户放行）

```bash
cd /tmp/mailbase-wt   # 任意含 git 仓库的目录即可，件用绝对路径
timeout -k 5 120 git send-email --confirm=never --no-annotate --suppress-from \
  --to=linux-arm-msm@vger.kernel.org --to=devicetree@vger.kernel.org \
  --cc=linux-kernel@vger.kernel.org \
  --cc=andersson@kernel.org --cc=konradybcio@kernel.org --cc=abelvesa@kernel.org \
  --cc=robh@kernel.org --cc=krzk+dt@kernel.org --cc=conor+dt@kernel.org \
  /home/xuqianhui/y700-elden/patches/upstream/board-dts-single-20261113-sent-20261117/0001-*.patch
```

先跑同样一条加 `--dry-run`（放在 `git send-email` 之后即可）；`Result: OK` 后再去掉 `--dry-run`。

## 5. 收件人（get_maintainer 现算，非沿用旧表）

To：`linux-arm-msm@vger.kernel.org`、`devicetree@vger.kernel.org`
Cc：`linux-kernel@vger.kernel.org`、Bjorn Andersson <andersson@kernel.org>、Konrad Dybcio <konradybcio@kernel.org>、
Abel Vesa <abelvesa@kernel.org>、Rob Herring <robh@kernel.org>、Krzysztof Kozlowski <krzk+dt@kernel.org>、
Conor Dooley <conor+dt@kernel.org>

## 6. AI 披露（项目规矩：上游发信三条前提）

补丁正文与测量/决定由作者本人复核；本目录由 LLM 助手起草，作者在发出前逐条对树核对。
