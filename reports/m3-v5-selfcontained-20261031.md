# M3 v5 系列自足性门禁 + cover letter — 2026-10-31

> 派工单：把 10-31 投递前门禁发现的两形态缺陷（「对 pristine 不自足」「无 cover letter」）变成可复用门禁 + 补齐的投递件。
> 纯主机侧：未 commit / 未发信 / 未碰设备 / 未改 `patches/` 实发件 / 未改 SSOT。
> 证据日志：`reports/artifacts/m3v5-gate-20261031/`（每条关键命令 `2>&1 | tee`）。

## 0. 结论

| 项 | 判定 |
|---|---|
| `scripts/check-series-selfcontained.sh` 落地 + `--self-test` | ✅ **PASS**（正例 2 枚含 cover 重放成功；负例删 0001 后在 0002 处 FAIL + WARN 缺 cover，退出码 1） |
| `patches/upstream/m3v5-20261030`（2 枚）对 **pristine `24a19b953e`** | ❌ **FAIL**（v5-0001 `apply --check` 失败——已知事实复现，v5 需 v4×3 打底） |
| `patches/upstream/m3v5-20261030`（2 枚）对 **v4-0003 tip `fd69bd54e3`** | ✅ **PASS**（2/2 按序重放成功）+ **WARN 缺 cover** |
| `patches/upstream/m3v5-fix-20261030`（2 枚）对 daily `24223e44ad` | ✅ **PASS**（2/2）+ WARN 缺 cover（**该目录是 daily 基线工作件，非投递件**，见 §2.3） |
| `patches/upstream/q28-dispcc-v2-20261029`（3 枚）对 pristine `24a19b953e` | ✅ **PASS**（3/3）+ WARN 缺 cover（cover 以 `README.md`/`SENT.md` 形式存档，无 `0000-*.patch` 落盘，见 §2.4） |
| cover 草稿 | ✅ `out/mail-20261031-c/0000-cover-letter.txt`（113 行，AI 披露在开头、sashiko v4 三份 12 条逐条回应、每论断带证据指针） |
| **现在能否投** | **🔴 不能——仍差两项硬项**：① 目录里没有 `0000-cover-letter.patch`（cover 草稿在 `out/`，投递前须以 `git format-patch --cover-letter` 重出为 `v5-0000-*` 并入目录再过一遍本门禁）；② 建议重出时加 `--base`（v5 两枚均无 `base-commit:` 尾注，base = v4-0003 tip，reviewer 只能靠 lore v4 串定位）。其余静态门（重放/checkpatch/binding/编译）此前已全绿（`reports/code-boundary-preinject-20261031.md` §1.1/§1.3），本轮未发现新代码缺陷 |

## 1. 门禁脚本与自测

- 脚本：`scripts/check-series-selfcontained.sh <patch-dir> [<base-ref>] [--repo <kernel-repo>]`
  - 干净临时 worktree：`git worktree add --detach /tmp/cssc-XXXXXX <base>`，收尾 `worktree remove --force` + `prune`；
  - 对每个 `*.patch` 按文件名序先 `git apply --check` 再 `git am --3way`，任一枚失败即判「对当前 base/序列状态不自足」；
  - cover 判定：文件名匹配 `*0000*`/`*cover*`，缺则 **WARN**（不置 1）；`*0000*`/`*cover*` 文件不进 apply 循环；
  - `--repo` 解析顺序：显式 `--repo` → `$CSSC_REPO` → 当前 git toplevel（base 可 verify）→ `build/*/`（base 可 verify）；本项目 docs 仓 toplevel 不含内核 base，实测走 `build/` 搜索；
  - `--self-test`：全部在 `/tmp` 临时仓库自建（正例 2 枚 + cover 对 base PASS；负例删 0001、0002 改 0001 引入的文件 → FAIL 停在 0002），**不碰本仓库、不联网**。
- 落地过程中修掉的 3 个实现缺陷（自测+手测抓出）：① 负例补丁无真依赖（改为 0002 修改 0001 引入的 `f1`）；② cover 被当作补丁 apply（改为跳过）；③ `git -C <wt>` 会把**相对路径**补丁解析到 worktree 内（报「无法打开补丁」假失败，改为 `readlink -f` 绝对路径进循环）。

`--self-test` 输出（全文 `reports/artifacts/m3v5-gate-20261031/self-test.log`）：

```
SELF-TEST: PASS
```

复现：`bash scripts/check-series-selfcontained.sh --self-test`

## 2. 三目录门禁结果（日志原文路径逐条标注）

### 2.1 `patches/upstream/m3v5-20261030` 对 pristine `24a19b953e`（负向，预期 FAIL）
`reports/artifacts/m3v5-gate-20261031/gate-m3v5-pristine.log`

```
FAIL  v5-0001-...patch: git apply --check 失败（对当前序列状态不自足）
WARN  缺 cover letter（*0000*/*cover*）
== 汇总: PASS=0 FAIL=1 WARN=1 退出码=1 ==
```
与 `reports/code-boundary-preinject-20261031.md` §1.4 负向测试（git am rc=128，`snps,dwc3-common.yaml:31` 未应用）同向，独立复现成立。

### 2.2 `patches/upstream/m3v5-20261030` 对 v4-0003 tip `fd69bd54e3`（正向）
`reports/artifacts/m3v5-gate-20261031/gate-m3v5-v4tip.log`

```
  ok    v5-0001-dt-bindings-usb-snps-dwc3-tighten-the-two-connect.patch
  ok    v5-0002-usb-dwc3-fix-the-two-connector-shared-HS-bus-role.patch
  WARN  缺 cover letter（*0000*/*cover*）
PASS  m3v5-20261030: 全部 2 个文件按序重放成功于 fd69bd54e3
== 汇总: PASS=2 FAIL=0 WARN=1 退出码=0 ==
```

⚠ **基点勘误**：`reports/code-boundary-preinject-20261031.md` §1.4 写「m3 base = 24a19b953e + v4×3」正确，但同文引用的 tip `34865c8915` 实为 **v5 系列自身 0002 的 commit**（`git log 34865c8915 -5`：34865c8915→0edc5c3326→fd69bd54e3→a0a5d3f1f5→46bd127690）。把 34865c8915 当 base 会假 FAIL（补丁内容已存在）。**正确 base = v4-0003 tip `fd69bd54e3`**（build/m3v2-7.3rc7 分支 m3v4 线）。此为门禁脚本首跑抓出的报告数字错误，非补丁缺陷。

### 2.3 `patches/upstream/m3v5-fix-20261030` 对 daily `24223e44ad`
`reports/artifacts/m3v5-gate-20261031/gate-m3v5fix.log` — **PASS 2/2，WARN 缺 cover**。
该目录是 daily 基线（`24223e44ad`）上的修复工作件（`reports/m3v5-fix-20261030.md`），补丁内容与 2.2 的投递件不同基，**不直接投**；列出仅证明目录自身对标注基点自足。

### 2.4 `patches/upstream/q28-dispcc-v2-20261029` 对 pristine `24a19b953e`
`reports/artifacts/m3v5-gate-20261031/gate-q28.log` — **PASS 3/3，WARN 缺 cover**。
WARN 属**存档形态问题**：该系列 2026-10-29 已投（cover 已发出，见目录 `SENT.md`），cover 未以 `0000-cover-letter.patch` 落盘于补丁目录。门禁只看目录内 `.patch` 文件，故如实 WARN；不影响已投状态。

复现（三合一）：
```
bash scripts/check-series-selfcontained.sh patches/upstream/m3v5-20261030 fd69bd54e3 --repo build/m3v2-7.3rc7
bash scripts/check-series-selfcontained.sh patches/upstream/m3v5-20261030 24a19b953e --repo build/m3v2-7.3rc7
bash scripts/check-series-selfcontained.sh patches/upstream/q28-dispcc-v2-20261029 24a19b953e --repo build/q28-disp-73
```

## 3. cover letter 要点（`out/mail-20261031-c/0000-cover-letter.txt`）

1. **开头如实披露 AI 辅助**（author reviewed/tested/responsible，按项目「上游发信」三前提）。
2. **定位**：v5 = v4 之上的 fixup 系列（**不取代** v4 1/3–3/3）：1/2 收紧 v4 1/3 binding、2/2 修 v4 3/3 driver + 顺修 v4 2/3 的 `usb_role_switch_at_endpoint()`；明确依赖 v4（helper 不在 7.3-rc7）。
3. **sashiko v4 三份 12 条逐条回应**（Message-ID 已对原始存档核实，`out/mail-20261029b/bodies/sashiko-outbox-1852{47,54,99}_kernel.org.txt`）：
   - 1/3 三条 Medium（endpoint pattern 逃逸 / 顶层 `usb-role-switch` / mux-state 互补）→ 1/2 全修，并给出 driver 侧机制理由（无 `usb-role-switch` 时 `dwc3_get_dr_mode()` 回退 peripheral）；
   - 2/3 一条 High（`-EPROBE_DEFER` 被吞）→ 2/2 末 hunk 修，并连到上机根因；
   - 3/3 五 High+三 Medium（自死锁/glue 通知/同角色换口 SUSPHY/注册竞态/fwnode 泄漏/sticky error + `role_get()` 隐藏 pending 请求）→ 逐条对应 2/2。
   - `mux-controls` 标准属性之问：保留 per-endpoint 形态 + 理由（per-connector 身份、`drivers/usb/` 无 mux_control 先例），明示愿按 DT 维护者意见重塑。
4. **证据指针**：checkpatch 0E/0W/0C（preinject §1.1）、`dt-doc-validate` 0 字节、`make W=1` 0 warning、上机 12 次插拔 `usb_role_switch_set_role→dwc3_mux_role_set→dwc3_set_mode` 零 WARNING（`TASKS/README.md` M3-1 v5 段、`reports/m3v5-f2-onboard-20261030.md`）、binding 形状结论（`reports/m3v5-binding-reshape-20261030.md`；port@1 被 QMP SuperSpeed 通路占用）。
5. **未证实项如实声明**：仲裁明细（每口角色值）数据集未齐，已布 kprobe 等自动落数。
6. **自曝缺 `base-commit:`**，承诺下次 `--base`。

## 4. 失败项最小修法（投递前 checklist）

1. **补目录内 cover**：以 `git format-patch --cover-letter --base=fd69bd54e3` 在 `m3v4`+v5 分支上重出 v5 系列为 `v5-0000..0002`，`0000-cover-letter.patch` 内容取自 §3 草稿（Subject 行去掉 From/署名块后并入）；
2. 重出后**复跑本门禁**：`bash scripts/check-series-selfcontained.sh patches/upstream/m3v5-20261030 fd69bd54e3 --repo build/m3v2-7.3rc7`，预期 `PASS=3 FAIL=0 WARN=0 退出码=0`；
3. 投递动作仍按 `TASKS/README.md` §7 由用户按批放行；cover 含 AI 披露，属 2026-10-31 用户授权范围。

## 5. 边界遵守声明

只读主线补丁与内核树（仅 /tmp worktree）；写入 = `scripts/check-series-selfcontained.sh`、本报告、`reports/artifacts/m3v5-gate-20261031/`（4 份日志）、`out/mail-20261031-c/`（cover 草稿）。未 commit、未发信、未碰设备、未改 `patches/` 与 SSOT。

---

## 6. 总管独立复核（2026-10-31）

| 主张 | 复核命令 | 实测 |
|---|---|---|
| 门禁自测通过 | `bash scripts/check-series-selfcontained.sh --self-test` | 正例 3/3 PASS、负例在 0002 处 FAIL 且退出码 1、`SELF-TEST: PASS` ✅ |
| m3v5 对 pristine 不自足 | `… patches/upstream/m3v5-20261030 24a19b953e --repo build/m3v2-7.3rc7` | `FAIL` 在 v5-0001（PASS=0 FAIL=1）✅ |
| m3v5 对 v4 tip 自足 | 同命令 base=`fd69bd54e3` | `PASS=2 FAIL=0 WARN=1`（缺 cover）✅ |
| 既有报告 base 指错 | `git -C build/m3v5-pristine log --oneline -1 34865c8915` | `34865c8915` = **v5 自身 tip**（其 2 提交即 v5 两枚）⇒ `reports/code-boundary-preinject-20261031.md:63` 把它当 base 属自指；正确 base = **`fd69bd54e3`** ✅ |
| cover 草稿含 AI 披露 | `head -18 out/mail-20261031-c/0000-cover-letter.txt` | 第 4 段起 `*** AI-assistance disclosure ***` + 作者校对/证据可复现 ✅ |

**另修（总管）**：门禁把裸 diff 的 `git am` 格式失败误报为"不自足"，已区分 `format-patch` vs 裸 diff（裸 diff 走 `apply` + WARN「不能直接投递」）。该修复对 M3/Q28 目录结论无影响（两目录均为 format-patch 形态），但对 `patches/local/*` 这类本地序列是关键判别。

**能否投：仍不能**（与 lane 结论一致）：目录内缺 `v5-0000-cover-letter.patch`；两枚缺 `base-commit:`（重出时 `--base=fd69bd54e3`）。
