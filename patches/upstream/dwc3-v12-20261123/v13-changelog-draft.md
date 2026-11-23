# v13 备料 —— changelog 历代补全草稿（2026-11-23）

> 起因：Greg Kroah-Hartman 2026-11-23T08:20Z 对 v11 3/3 的回信
> `<2026112313-skied-crock-7374@gregkh>`：「What about all the previous versions?
> Please always include them all, right? thanks, greg k-h」
> ⇒ v13 cover 的 changelog 必须列全此前所有版本（本系列 lore 可见 v4/v5/v7/v8/v9/v10/v11/v12）。
> 本文件只是**草稿**；v13 的裁切与投递 = 等 sashiko 对 v12 的报告（若来）+ 用户放行，按 §7 批准制。

## 拟放进 v13 cover 的完整 changelog（倒序，草稿）

Changes since v12
- (placeholder — sashiko/maintainer comments on v12, if any; plus: the
  changelog itself now covers every previous version, per greg k-h's
  2026-11-23 request.)

Changes since v11
- Posting shape only, at krzk's request: AI-assistance disclosure moved from
  the commit messages below the '---' separator, and the series is posted as
  a new thread instead of a follow-up to v10.  The cover letter states that
  no runtime testing is claimed for the mux path.
  (Code identical to v11, which itself was identical to v10 apart from the
  three changes listed below.)

Changes since v10
- 3/3: dwc3_role_mux_deselect() is called after the switch
  (dwc->current_dr_role) block, so the shared High Speed lines are released
  to the mux' idle state only after the active host/gadget instance exited.
- 1/3: "port@0" keeps the generic graph port at the top level; the two
  numbered endpoints, their "usb-role-switch"/"mux-state" and the cell
  properties are required by the "mux-controls" branch only, so
  single-connector controllers are described exactly as before.
- 1/3: the endpoint schema is inlined through patternProperties
  ('^endpoint@[01]$'); the local "$defs" section is gone.

Changes since v9
- 1/3: answered Rob Herring's 2026-11-18 review: dropped the local $defs,
  switched to patternProperties '^endpoint@[01]$', removed driver
  implementation details from the binding, dropped the redundant $ref.
- 3/3: commit message rewritten to answer "why" (why a mux is needed, why
  the first mode request claims state 0, why mux calls happen only from the
  mode worker and after cancel_work_sync()); implementation-change notes
  moved below the '---'.
- fixed the v9 build/packaging defects: 1/3 regains its "diff --git" header
  and the DRAFT note after the separator is gone.
- carried over from static review of v9: [High] unbalanced
  mux_control_deselect() (only a selected mux is deselected; a failed
  select records nothing).

Changes since v8
- rebased onto torvalds master (7.4-rc2 line); content unchanged from the
  2026-11-04 posting apart from that.

Changes since v7
- 1/3: the two connectors are described as two mux'ed data streams of one
  High Speed bus: "port@0" carries two endpoints with "mux-state" 0/1, the
  Super Speed port keeps its own node; the private "port-select-gpios"
  property is replaced by "mux-controls" (phandle to a mux controller,
  e.g. "gpio-mux").
- 3/3: the shared data path is driven through the mux controller API
  (devm_mux_control_get()/mux_control_select()); mux_control_select() may
  sleep and is only called from the mode worker.
- 2/3 (usb: roles): role-switch lookup extended to switches attached to a
  graph endpoint, which the two-endpoint binding needs.

Changes since v5 (v6 was not posted; v4/v5 superseded in full)
- v4 (2026-10-26) first posted the series with "port-select-gpios" and
  separate port@0/port@2 nodes; v5 (2026-10-31) was a fixup round.  Both
  were folded into the v7 rewrite above and are superseded.

## 事实核对指针（草稿依据，全部在仓内）
- v7 cover（v4/v5 折叠声明、GPIO/mux 形状）: patches/upstream/m3-dwc3-20261104/0000-cover-letter.patch
- v9 cover（Rob 11-10 意见四条）: patches/upstream/dwc3-v9-20261117/v9-0000-cover-letter.patch
- v10 cover（Rob 11-18 四条 + sashiko High 修复）: patches/upstream/dwc3-v10-20261120/v10-0000-cover-letter.patch
- v11 三处改动: patches/upstream/dwc3-v11-20261121/（cover "Changes since v10"）
- v12 投法（新线程 + 披露入 ---）: patches/upstream/dwc3-v12-20261123/SENT.md
- Greg 原话: reports/comm-triage-20261123-b.md §1
- ⚠ 待办：v13 裁切前逐条与各代 cover 原文比对（本稿为二手概括）；v8 是否另有独立内容需查 m3-dwc3-v7-20261106/。
