# 上游 RFC：dispcc-sm8750 在 probe 复位 MDSS 块（2026-10-22）

- **状态**：✅ **已发送并归档（2026-10-22 22:08:10 +0800）**。
  - `checkpatch.pl --no-tree --strict`：**0 errors / 0 warnings / 0 checks**。
  - `git send-email`（USTC，250 OK），Message-ID **`20261022140811.469417-1-xiaqinghuan@mail.ustc.edu.cn`**。
  - 归档复核：`/linux-arm-msm/`、`/linux-clk/` 均按 Message-ID 取 raw 成功，**正文 diff 与本地逐字节相同**
    （sha256 `289c065c17867c7a…`）；`dri-devel`（lists.freedesktop.org，非 vger）归档暂未出现，待复核。
  - 历史：发送前主机 `perl-base` 曾被写坏（`Tie/Hash.pm` 内容错乱）⇒ `checkpatch`/`git send-email` 全部不可用，重装后恢复。
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
