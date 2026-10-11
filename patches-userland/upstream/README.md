# 上游提交草案（phoc + phosh）

> 两个补丁都已对**上游 `main`（2026-10-11：phoc 0.58.0 / phosh）实测可干净 apply**。
> 本目录的 `.patch` 是 `git diff`（不含作者/S-o-b），便于你用自己身份重新 commit；草案文案如下。
>
> ⚠️ **需要你处理的部分**：GitLab 账号/fork、`Signed-off-by` 的真实姓名+邮箱、push 与点「Create MR」。
> agent 不代填凭据/账号（STANDING 规则）。

---

## 1. phoc — 只认 preferred mode，非 preferred 刷新率档被忽略

- 补丁：`phoc-output-honor-any-mode.patch`（1 行）
- 目标：https://gitlab.gnome.org/World/Phosh/phoc （`main`）
- 相关：issue #429（已 closed）、commit `47099669`（MR !771）、commit `c1ef0ea8`

### commit message（建议）

```
output: Honor any requested mode, not just the preferred one

phoc_output_config_head_to_output_config() only copies head->state.mode
into the internal PhocOutputConfig when that mode is the preferred one.
For any other mode it takes the else branch and reads head->state.custom_mode,
which is all-zero because a real mode was requested.  phoc_output_fill_state()
then sees oc->mode.width == 0 and falls back to the preferred mode, so a
request for any non-preferred refresh rate is silently ignored.

Commit 47099669 ("output: Actually handle preferred mode") made the
preferred case work again but left the non-preferred case broken.  The
correct predicate is simply whether a mode was requested at all;
custom_mode is only populated when no mode was given.

This is easy to reproduce on a panel that has a single preferred mode
(e.g. the Lenovo Legion Tab Y700 Gen4, 1904x3040, preferred 165 Hz):

    $ wlr-randr --output DSI-1 --mode 1904x3040@120.0
    $ wlr-randr | grep current
        1904x3040 px, 165.000000 Hz (preferred, current)

and the refresh rate row in Settings -> Displays has no effect.  On the
laptop in 47099669 both 120 Hz and 60 Hz were marked preferred, which is
why the fix there was sufficient.

Tested on the Y700 Gen4 (mainline Linux, phoc 0.55.1): switching to
144/120/90/60/40/30/24 Hz now works both via wlr-randr and via
gnome-control-center's ApplyMonitorsConfig path.

Fixes: 47099669291208324be9e24a6a9ad0584eb929f8 ("output: Actually handle preferred mode")
Closes: https://gitlab.gnome.org/World/Phosh/phoc/-/issues/429
```

### 先开 issue 再提 MR？（建议）

`#429` 已 closed，症状与我们的不同（它那台机两个档都是 preferred）。建议**新开一个 issue**「refresh rate switching only works for the preferred mode」，
正文用上面的复现段落 + 指出 `47099669` 只覆盖了「多 preferred」的情形，然后 `Closes: <新 issue>` 提 MR。

---

## 2. phosh — `GetCurrentState` 上报的 scale 不在 `supported_scales` 里 → Displays 显 100%

- 补丁：`phosh-report-supported-scale.patch`
- 目标：https://gitlab.gnome.org/World/Phosh/phosh （`main`）
- 相关：phoc commit `c1ef0ea8`；gnome-control-center `panels/display/cc-display-config.c`（精确匹配）

### commit message（建议）

```
monitor-manager: Report a scale that is in the advertised supported list

GetCurrentState() reports the logical monitor scale straight from
head->scale.  That value comes from the wlroots output-management
protocol, which carries the scale as a 24.8 fixed-point number, and phoc
additionally rounds it onto a 1/120 grid.  The supported_scales we
advertise for a mode are calculated from the panel resolution (e.g. 8/3 =
2.6666667461395264), so the value we read back does not appear in the
list we hand out.

gnome-control-center matches the current scale against that list with
G_APPROX_VALUE(..., DBL_EPSILON), i.e. exactly.  With no match the scale
row falls back to the first entry and shows "100%"; the scale is applied
correctly, only the UI is wrong.  Integer scales happen to be on the
1/256 grid, which is why they always worked.

Snap the reported scale onto the nearest supported scale when we are
within the quantization error (< 0.01).  This only affects the value
reported over D-Bus; the scale actually applied by the compositor stays
the exact value (phoc still rounds to 8/3).

Reproduced on the Lenovo Legion Tab Y700 Gen4 (1904x3040):
scale 8/3 is advertised as 2.6666667461395264 but reported as
2.66796875 before the fix.
```

---

## 3. 提交前需要你确认/处理

1. **身份**：`user.name`/`user.email`（用于 author + `Signed-off-by:`，需与 GitLab 账号一致）。
2. **fork**：在 gitlab.gnome.org fork `World/Phosh/{phoc,phosh}`，把 patch 以**单个 commit**推到分支。
   （`git am` 或 `git apply` + 手写 commit message；**不要**把这两个补丁合进同一个 commit——分属两个仓库。）
3. **新开 issue**（可选但推荐，尤其 phoc）并在 MR 里 `Closes:`。
4. CI：phoc/phosh 有 meson test；本机无法跑上游 CI（无 upstream 依赖版本），需等流水线。

agent 可以帮你：生成最终 `git format-patch`（给定姓名/邮箱后）、写 MR 描述/回复 reviewer、按反馈改补丁。
agent 不做：填账号密码/token、代点提交。
