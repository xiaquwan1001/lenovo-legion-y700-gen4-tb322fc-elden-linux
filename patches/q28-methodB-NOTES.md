# Q28 Method B — round DSI byte-clk to PLL-achievable rate (SM8750 port)

Status: **SUPERSEDED 2026-10-12** — §2/§3 below describe the old single-hunk
edition that rounded *before* reparent (inside the SM8750 branch of
`dsi_link_clk_set_rate_6g_v2_9()`). That timing is exactly the upstream bug
(`6cd33b6f4155`) that `2028280686f4` fixes. `q28-methodB-round-byteclk.patch`
has been recalibrated to the upstream semantics (round in
`dsi_link_clk_set_rate_6g()` *after* reparent; authorititative bool
`byte_intf_clk_div_2`). See
`reports/q28-upstream-static-20261012.md` for the authoritative analysis.
The rest of this file is kept as history.

Original status (superseded): **draft only**. Not compiled, not applied to the
tree, not committed, not flashed. The tree copy of
`drivers/gpu/drm/msm/dsi/dsi_host.c` is unchanged; this is a standalone
`patches/q28-methodB-round-byteclk.patch` verified only with `git apply --check`
/ `patch --dry-run`.

## 1. Root-cause model this patch targets (from PITFALLS #163 + upstream)

- Q28 = first command-DMA trigger intermittently hangs (`CMD_MODE_ENGINE_BUSY`
  never clears → `-110`); bad dump additionally shows `DYN_PCLK_ACTIVE |
  DYN_CMD_PCLK_ACTIVE` in CLK_STATUS, good/bad `clk_summary` identical.
- Real variable = **reset type**, not time-of-day: **cold boot ≈ always fails,
  warm reset ≈ always succeeds**. Warm reset preserves the DSI PLL/PHY lock
  state, so the first modeset skips the fragile PLL re-lock path; cold boot has
  to re-lock, and that re-lock races the cmd-DMA trigger.
- Upstream line of attack (matches the symptom): the byte clock handed to the
  PLL is the **unrounded, pixel-derived** value. If the requested rate differs
  from what the PLL can lock, every `clk_set_rate()` re-evaluates the parent
  and can retrigger a PLL re-lock. Round it once to the PLL-achievable value so
  `clk_set_rate()` is a CCF no-op after the PLL is locked.

## 2. What the patch changes (single hunk)

File: `drivers/gpu/drm/msm/dsi/dsi_host.c`
Function: `dsi_link_clk_set_rate_6g_v2_9()` — **only** the
`of_device_is_compatible(..., "qcom,sm8750-dsi-ctrl")` branch
(currently around line 484).

Behaviour added, in this order, inside the SM8750-only branch:
1. `rounded = clk_round_rate(msm_host->dsi_pll_byte_clk, ideal)` where
   `ideal = msm_host->byte_clk_rate` (the unrounded value coming from
   `dsi_calc_pclk()`).
2. If `rounded > 0 && rounded != ideal`, write back
   `msm_host->byte_clk_rate = rounded`, and keep
   `msm_host->byte_intf_clk_rate` in lock-step: `rounded` when the PHY did not
   request `byte_intf_clk_div_2`, else `rounded / 2`.
3. Then the existing `clk_set_rate(msm_host->dsi_pll_byte_clk, byte_clk_rate)`
   now sees the already-achievable rate → it locks the PLL once and any repeat
   call matches CCF's cached rate → no-op (no re-trigger).

`long clk_round_rate(struct clk *, unsigned long)` returns a negative errno on
failure (confirmed against `include/linux/clk.h` of this tree). The guard
`rounded > 0 && rounded != ideal` means a round failure (`< 0`) or an
already-exact rate (`== ideal`) leaves every field untouched → **falls back to
the current behaviour**. There is no path where a zero/negative rate is written
back.

## 3. Correctness analysis of the derived quantities (step 2 of the task)

`msm_host->byte_clk_rate` is consumed / mirrored at these points (grepped across
`dsi_host.c`):

| Site | Line (approx) | Relation to byte_clk_rate | Touched? | Why |
|------|---------------|---------------------------|----------|-----|
| `dsi_calc_pclk()` assigns byte_clk_rate | ~737 | producer (ideal, from pclk/bpp/lanes) | no | this is the value we round |
| OPP vote `dev_pm_opp_set_rate(dev, byte_clk_rate)` in `dsi_link_clk_set_rate_6g()` | ~442-445 | direct consumer | yes, indirectly | now gets the achievable rate; OPP table lookup rounds to nearest OPP; a *lower* byte rate is a safe/cheaper OPP, never exceeds the PLL that actually locked |
| `clk_set_rate(byte_intf_clk, byte_intf_clk_rate)` | ~458 | direct consumer | yes | byte_intf is a DISPCC divider whose parent chain reaches the PLL; leaving it at the ideal rate could pull the just-locked PLL back → re-lock. Syncing it is required for the no-op goal. |
| `byte_intf_clk_rate = byte_clk_rate [/2]` | ~3236-3238 | producer | mirror-update | we preserve the /2 ratio; SM8750 3nm PHY does **not** set `byte_intf_clk_div_2` (only 28nm/14nm/10nm set it true in `dsi_phy.c`), so for this board `byte_intf == byte_clk` |
| `bitclk = byte_clk_rate * 8` (A-PHY) / `*7` (C-PHY) in `msm_dsi_host_get_phy_clk_req()` | ~3146-3148 | consumer feeding PHY | **no** | see below |
| `esc_clk_rate` | ~752 (6g path) | `clk_get_rate(esc_clk)`, NOT derived from byte | no | the 6g/SM8750 path reads the existing esc rate; the byte/esc_div math is only in `dsi_calc_clk_rate_v2()` (non-6g), not used by SM8750 |
| `link_byte_rate / link_intf_rate` mirror | ~3287-3289 | store of byte/intf after enable | no (auto) | stores the already-rounded values → stays consistent with the `-ESTALE` guard |
| DSC / pixel_clk_rate | from mode via `dsi_calc_pclk()` | independent | no | pixel path unrelated to byte rounding |

### Why `bitclk` is intentionally **not** rewritten
`msm_dsi_host_get_phy_clk_req()` computes `bitclk = byte_clk_rate * 8` and hands
it to the 7nm/3nm PHY PLL driver, which internally rounds to the achievable VCO
using the **same** PLL rate table that `clk_round_rate(msm_host->dsi_pll_byte_clk,
ideal)` consults here. So the PLL the PHY programs and the PLL rate this patch
feeds to `clk_set_rate()` land on the identical achievable value — they are
already consistent by construction. Rewriting `bitclk_rate` inside
`dsi_link_clk_set_rate_6g_v2_9()` would not propagate back to the PHY (the PHY
consumes its own `clk_req` copy) and would only desync the host's view from the
PHY's. Leaving it is the safer, minimal choice.

### Why `esc` / DSC / pixel are not touched
SM8750 uses the 6g clock path (`dsi_calc_clk_rate_6g()`), where `esc_clk_rate`
is `clk_get_rate(esc_clk)` — a read, not a byte-derived division. The
`byte/esc_div` division that would need re-derivation lives in
`dsi_calc_clk_rate_v2()` (older non-6g path) and is not on this board's path.
Pixel/DSC pclk come straight from the mode and are unrelated.

## 4. Risk register

- **Risk A (low):** OPP vote now uses a possibly lower byte rate. OPP lookup
  rounds to a supported operating point; a lower byte rate selects an equal or
  lower OPP → never a voltage/frequency under-vote relative to what the PLL
  actually produced. Watch for any `dev_pm_opp_set_rate failed` on boot.
- **Risk B (must verify on device):** the whole premise — that feeding the PLL
  the achievable rate removes the cold-boot re-lock race — is the upstream
  *hypothesis*, not yet proven on this panel. If Q28 persists after this patch,
  the cause is elsewhere (e.g. PHY `restore_pll_state`/`save_pll_state`, CMD
  engine programming order, `dsi_cmd_link_clk_set_rate` stale-guard). This patch
  does not regress warm resets; it aims to make cold boot take the warm path.
- **Risk C (low):** if `clk_round_rate()` on `dsi_pll_byte_clk` is not yet valid
  before the PLL is enabled, it could return an unexpected value. Mitigated by
  the `> 0` guard and by the fact this branch already calls `clk_set_rate()` on
  the same clock (so the clock is expected to be usable here). Verify the
  `DBG("round dsi byte clk …")` line in a real log.
- **Risk D (scope):** SM8750-only branch. No other SoC path is altered. The
  `intf_div2` detection is defensive; on this board `byte_intf == byte_clk`.

## 5. Static-check checklist before flashing (mandatory)

1. `git apply --check patches/q28-methodB-round-byteclk.patch` from the linux tree root (already passed in this run).
2. Confirm the SM8750 DT ctrl is actually `qcom,sm8750-dsi-ctrl` so the branch
   is taken, and the PHY is `qcom,sm8750-dsi-phy-3nm` (→ `DSI_PHY_7NM_QUIRK_V7_2`).
3. Confirm on this board `phy_shared_timings.byte_intf_clk_div_2 == false`
   (3nm PHY never sets it) → `byte_intf_clk_rate == byte_clk_rate`. If a future
   PHY sets it, the `intf_div2` path must be exercised.
4. After build+flash with `CONFIG_DRM_MSM_DEBUG`/DBG on, read the
   `round dsi byte clk <ideal> -> <rounded>` line and confirm `rounded` matches
   the PLL rate in `clk_summary` (`dsi_pll_byte` / `byte_src`). They must be
   equal, and `byte_intf` must equal the same value.
5. Confirm the cold-boot cmd-DMA no longer shows `CMD_MODE_ENGINE_BUSY` /
   `-110`, and that CLK_STATUS bad-case bits
   (`DYN_PCLK_ACTIVE|DYN_CMD_PCLK_ACTIVE`) disappear. If they persist, this
   hypothesis is disproven — do **not** stack more clock changes.
6. Check `dsi_cmd_link_clk_set_rate()` `-ESTALE` path: after rounding at enable
   time, `byte_clk_rate == link_byte_rate` and
   `byte_intf_clk_rate == link_intf_rate` must hold (both now the rounded value),
   so no spurious `stale link configuration` on later command transfers.
7. Run `checkpatch.pl --strict` on the patch (line lengths, comment style).

## 6. Why this is minimal

- One hunk, one SoC branch, no new files, no signature changes, no new structs.
- Reuses existing `clk_round_rate`, `msm_host->byte_clk_rate`,
  `msm_host->byte_intf_clk_rate`, and the existing `clk_set_rate` call.
- Falls back to current behaviour on round failure / already-exact rate.
- Deliberately does **not** touch bitclk, esc, pixel, DSC, OPP table, PHY PLL
  drivers, or the CMD path.

## 7. Generation base & checkpatch status

- Generated against the **working-tree** `drivers/gpu/drm/msm/dsi/dsi_host.c`
  (the symlinked `geekidos-linux` checkout), which already carries pre-existing
  **uncommitted** SM8750/Q28 work (`git status` shows `M` on that file with ~50
  inserted lines that contain the SM8750 v2_9 branch this patch anchors to).
  `git apply --check` and `patch -p1 --dry-run` both pass against that working
  tree. This matches the task instruction "基于当前 linux 树". If the parent
  rebases onto a different base, re-run `git apply --3way` to confirm the anchor.
- `checkpatch.pl --strict`: only remaining findings are
  `ERROR: Missing Signed-off-by` and `WARNING: Missing commit description` —
  both are commit-metadata artifacts of a header-less draft and are intentionally
  left for the parent to add after calibrating with the upstream diff. No
  code-style defects remain (the earlier filename-in-comment warning was fixed).

---

## ⚠️ 2026-10-10 更正（第二会话静态审查）

本文档第 3 节表格里「SM8750 3nm PHY **不**设 `byte_intf_clk_div_2`」是**错的**。实测代码链：
SM8750 → `dsi_phy_3nm_8750_cfgs` → `msm_dsi_dphy_timing_calc_v4`（`dsi_phy_7nm.c:1018`）
→ `dsi_phy.c:461` **置 `byte_intf_clk_div_2 = true`**。

⇒ 实际落地补丁 `q28-round-vk86.patch` 的 `intf != byte → /2` 在 SM8750 上**产出正确的
`byte_intf = rounded/2`**。（该写法对“no-div2 + 取整改速率”的板仍会错误减半，属通用脆弱。）
本文件其余内容为历史草稿；当前口径以 `reports/q28-DOSSIER.md` §j / §j-附 为准。
