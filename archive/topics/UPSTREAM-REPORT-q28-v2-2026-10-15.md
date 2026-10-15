To: linux-arm-msm@vger.kernel.org
Cc: dri-devel@lists.freedesktop.org, freedreno@lists.freedesktop.org, dmitry.baryshkov@oss.qualcomm.com, neil.armstrong@linaro.org, abelvesa@kernel.org, mitltlatltl@gmail.com
Subject: [REPORT v2] SM8750 bonded dual-DSI + NT36536: the command-DMA-timeout signature is not the invariant; dark panel is not recoverable in software

Hi,

This is a follow-up to our 2026-10-13 report on the same board.  We have since
run controlled single-variable experiments that force us to *correct* the
diagnosis in that report, and we think the corrected picture is more useful to
you.  Summary of what changed:

  - the "first DCS command-DMA timeout" (-110) is NOT the invariant.  We built
    an image that removes that signature entirely, and the panel still does not
    light up.
  - the failure is NOT a driver-side latch that could be cleared.  We built an
    image with a bounded retry instead of the permanent latch, and the retry
    does happen - the panel still does not light up.
  - the failure is NOT recoverable by re-running the modeset.  Restarting the
    compositor (which re-runs panel prepare + full atomic commit) while in the
    bad state fails again exactly the same way.

So we now believe the bad state is a *persistent hardware/power-domain* state
that survives everything we can reach from the DSI/DRM side, and that the
-110 message is a symptom rather than the root cause.  Details and evidence
below; questions at the end.

BOARD / SETUP

Lenovo Legion Y700 (2025), TB322FC, Qualcomm SM8750P.  Panel Novatek NT36536,
1904x3040, DSC, video mode, driven by bonded dual DSI (ae94000.dsi master,
ae96000.dsi peer).  Our tree is GEEKiDOS/linux (7.2-based) plus the bonded
command path; we have since rebased onto 7.3-rc7 and reproduced everything
there, so the observations below are not specific to the 7.2 tree.

All samples below are *cold* boots (power off -> bootloader -> boot).  We do not
use warm resets for these measurements: a warm reset does not clear the DSI
PHY/PLL state, and after a failure a warm reset tends to reproduce a
*different* failure mode (no card0 at all), which makes it useless for A/B
comparison.  Every sample quoted here is a real power-off.

1) THE -110 SIGNATURE IS NOT THE INVARIANT

   We built an image whose only difference is that the vendor bonded command
   write path is disabled, so DCS goes through the standard need_sync double
   write (dsi_manager.c, 3 hunks, single file).  Same config, DTB, ramdisk and
   cmdline, verified byte-identical; same UTS.

   Result on its bad boots: "command DMA timeout" 0 occurrences, "bonded
   command DMA failed" 0 occurrences, "Failed to initialize panel" 0
   occurrences, panel init reports success ("panel prepared").  The DPU side is
   fine too (crtc active, compositor renders, a framebuffer readback from the
   compositor contains real content, DPU frame counters advance).

   And the panel is *still dark*.  Confirmed by eye on the physical device:
   backlight on, power key controls the backlight, volume keys and audio work,
   but there is no image.

   So: removing the bonded command path removes the DMA-timeout message and
   does not fix the panel.  -110 and "panel dark" are separable.

   (Measurements that are "all normal" while the panel is dark, on this board:
   card0-DSI-1 status "connected", DPMS "On", connector "enabled", backlight
   non-zero and controllable, disp_cc_mdss_pclk0/1_clk_src = 172991986 Hz
   claimed by ae94000.dsi/ae96000.dsi, byte clocks claimed, crtc intf_mode 2,
   compositor screenshots succeed.  The only quantity we found that tracks the
   physical state is the DSI interrupt count: 41 when the panel is lit, 0 in
   every dark case.  We mention this because it cost us a false "GOOD" verdict:
   screenshots and frame counters prove the DPU is running, not that the panel
   received valid video.)

2) THE FAILURE IS NOT A DRIVER LATCH

   The tree latches a single bonded-command failure permanently
   (dsi_bonded_cmd_failed is only ever set true) and several bridge callbacks
   early-return on that latch, including power_off/post_disable - so after one
   failure the teardown is skipped as well.  That looked like a plausible
   "unrecoverable by construction" mechanism, so we changed exactly that, in
   two orthogonal ways, single file:

     (a) latch only after a bounded number of failures (3) instead of the
         first one, logging each attempt;
     (b) drop the cmd_failed() early-returns from power_off / pre_enable /
         post_disable so the normal teardown and re-power-up always run.

   On a bad boot the new log shows the retry budget working:

     dsi: bonded command failure 1/3 (command DMA timeout), will retry
     dsi: bonded command failure 2/3 (panel not prepared), will retry

   and "giving up" never appears - i.e. the latch never engages.  The teardown
   is no longer skipped.  The panel is *still dark*.

   Worth noting for the general case: making the failure non-fatal is necessary
   but not sufficient, because nothing re-issues the modeset afterwards.
   drm_panel_prepare() runs once per atomic commit, and after the failure no
   new commit is generated, so even a "retryable" error does not actually get
   retried.  We only got a second attempt by forcing one (next section).

3) THE STATE IS NOT RECOVERABLE BY RE-RUNNING THE MODESET

   While in the bad state we restarted the session (stop greetd, kill phoc,
   start greetd), which releases DRM master and produces a fresh atomic commit
   and a fresh modeset.  The compositor did restart (process count 1 -> 2), so
   the retry genuinely happened.  Result:

     before: panel_prepared 0, dsi interrupts 0, ctl reset failure 268
     after : panel_prepared 0, dsi interrupts 0, ctl reset failure 394

   i.e. the second attempt failed in exactly the same way, and the panel stayed
   dark (confirmed by eye).

   Control, to be fair to the mechanism: the *same* operation on a healthy boot
   is harmless - panel stays lit, DSI interrupts stay at 41, no new errors.  So
   re-running a modeset does not break a working link; it just cannot repair a
   failed one.

4) WHERE WE THINK THIS LEAVES US

   Combining 1-3: neither the command path, nor the driver latch, nor the
   modeset re-entry is the lever.  The bad state appears to be established
   during the first bring-up and to persist, and the DSI controller does not
   appear to be where it lives.  Consistent with your earlier suggestion we
   also checked the PHY clock-source selection (DSI_7nm_PHY_CMN_CLK_CFG1
   DSICLK_SEL and the resulting disp_cc_mdss_pclk*_clk_src): our tree already
   selects SEL=0 / pll_bit for this 30bpp 3-lane C-PHY case, matching the
   downstream driver, and the resulting pclk is correct (756839941/2 * 16/35 =
   172991986 Hz, matching the measured clock exactly).  So that particular
   select is not the gap on this board.

   What we can still see from the DSI registers, on a bad boot, is that
   CLK_STATUS ends up with the DYN_PCLK / DYN_CMD_PCLK bits set together with
   CMD_PCLK, STATUS0 = 0x20003 (engine|DMA busy), no DSI interrupts, and the
   pre-first-command registers are byte-identical to a good boot.  On the DPU
   side we get "hw recovery is not complete for ctl:1"
   (dpu_hw_ctl.c:459, i.e. the CTL soft reset never completes) repeated, with
   "ctl 1 reset failure: -22" and vblank/frame-done timeouts - but we read that
   as a downstream consequence, not a separate fault.

QUESTIONS

1. Given that the -110 command-DMA timeout can be made to disappear while the
   panel stays dark, is the DYN_PCLK / DYN_CMD_PCLK request handshake between
   DSI and dispcc/INTF supposed to be released by the client side?  Is there a
   known ordering requirement on SM8750 for the *first* command after PHY
   enable / PLL lock?  (Our engine latches with STATUS0 = 0x2200200 and the
   trigger never self-clears.)

2. Is there anything we can inspect outside the DSI register block to tell
   whether the pixel-clock domain actually came up - a dispcc/INTF status, a
   vote we can read back, or a documented way to distinguish "request
   asserted" from "request serviced"?  We cannot read MMIO directly from
   userspace here (STRICT_DEVMEM), so a driver-side suggestion would help.

3. Do you know of any SM8750 (or SM8650-family) erratum for cold-boot
   video-mode DSC bring-up on bonded DSI that would put the link into a state
   that only a full SoC reset clears?  We have ruled out the PLL re-lock series
   (6cd33b6f4155, 2028280686f4) as far as we can tell from the symptom.

4. Should a failure like this be surfaced differently by the driver?  Right now
   the failure is reported and then the panel is simply never prepared, while
   everything else reports success (connector connected, DPMS on, compositor
   fine).  If there is a preferred upstream shape for "panel init failed, do
   not pretend the output is up", we would rather implement that than keep
   experimenting locally.

5. Would you like the capture set?  We have full dmesg from lit and dark boots,
   the DSI/PHY register dumps, CLK_STATUS transitions, the probe scripts
   (cold-boot runner, three-state classifier) and both experimental patches
   (command-path removal, bounded retry + non-short-circuited teardown).  Happy
   to send any subset, and happy to test a patch on the device.

Thanks,
Xu Qianhui <xiaqinghuan@mail.ustc.edu.cn>

The bring-up tree is GEEKiDOS/linux plus local patches.  We can publish the
repro scripts and the failing-boot captures, and we can run any experiment you
suggest on the hardware.

---

## 投递复核（2026-10-15，编排者独立取回）

- 发送：2026-10-15T12:22:06Z（`smtp.ustc.edu.cn`），Message-ID
  `<179206690897.1177097.7309368787214649515@mail.ustc.edu.cn>`
- 收件：`To: linux-arm-msm@vger.kernel.org`；`Cc:` dri-devel / freedreno /
  dmitry.baryshkov / neil.armstrong / abelvesa / mitltlatltl（合计 7 个）
- **lore 归档已复核**：`https://lore.kernel.org/linux-arm-msm/?q=f:xiaqinghuan@mail.ustc.edu.cn`
  命中 `[REPORT v2] SM8750 bonded dual-DSI + NT36536: the command-DMA-timeout signature is not t…`
- **正文逐字节相同**：取回 `/raw` 后与本地发送版比对，
  sha256 前 32 位 `f0c87d967bab11f1fef4d4ef51f24e10` **两侧一致**（IDENTICAL: True）
- 邮件通道事实（复用既有结论）：USTC 通道 **Message-ID 逐字保真**；
  QQ 会改写 Message-ID、outlook basic auth 已被禁用 ⇒ 不要换通道重发
- **回信观察**（待办）：注意 USTC 会把列表信标 `[SPAM]`；查 INBOX + "Junk E-mail"，
  用 `read-mail-ustc.py --days 7 --replies-only` 过滤 In-Reply-To/References
