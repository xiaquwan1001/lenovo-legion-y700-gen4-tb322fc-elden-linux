# 上游 RFC：dispcc-sm8750 在 probe 复位 MDSS 块（2026-10-22）

- **状态**：**未发送**。主机 perl 运行时损坏（`/usr/lib/x86_64-linux-gnu/perl-base/Tie/Hash.pm` 被写坏，
  `perl -e 'use POSIX'` 直接编译失败）⇒ `scripts/checkpatch.pl` 与 `git send-email`（均为 Perl）都跑不起来。
  等系统 `perl-base` 重装后：先 `checkpatch.pl --strict`，再按 `upstream-mail-ustc` 技能发送与 lore 复核。
- **内容**：`0001-*.patch` 是完整邮件（含 `From:`/`Subject:`/正文/`Signed-off-by`/diff），
  基于 `build/q28-disp-73`（m1-73 `24223e44ad80`）的 dispcc 改动，已用 `git apply --check --reverse` 验证、
  并单独编译通过（`make drivers/clk/qcom/dispcc-sm8750.o`）；已手工核对 80 列 / 行尾空白。
- **拟收件人**：`To: linux-arm-msm@vger.kernel.org`；`Cc: linux-clk@vger.kernel.org`、
  `dri-devel@lists.freedesktop.org`、Bjorn Andersson、Konrad Dybcio、Dmitry Baryshkov、clk 维护者（Michael Turquette / Stephen Boyd）。
- **正文要点**：①冷起 command DMA 超时（`0x2200200`）+ 面板 init `-5`，仅背光；②跨 9/15 发真实 POR 的对照数字；
  ③问两件事（是否该做成 DT 属性/无条件在 dispcc 或 mdss 做、以及是否应交给 bootloader 的 `DisableDisplayHW`）；
  ④给 Baryshkov 的 DIGTOP 系列的独立佐证：DIGTOP 修复让 `DSI PLL(0) lock failed` 从每启 4 次降到 0（10/10），
  但**不改变** command DMA 失败（仅带该改动的镜像 3/4 冷起仍失败，且 PLL 是锁上的）。
- **发送通道**：USTC（`sendmail.smtpServer=smtp.ustc.edu.cn:465`，Message-ID 保真）见 `.pi/skills/upstream-mail-ustc`。
