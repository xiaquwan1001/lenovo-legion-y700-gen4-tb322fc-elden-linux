# Q28 类现象 — 邮件与外部资料档（B 卷）

> 范围：只读取证。数据源 = 本机 USTC 邮箱（IMAP，`read-mail-ustc.py`）、`out/mail-*/`、`reports/upstream-status-*.md`、
> `archive/topics/UPSTREAM-REPORT-*`，以及公共网络（lore / mail-archive / patchwork REST / git.kernel.org plain）。
> 取证时刻：**2026-11-16 15:5x–16:2x CST**（`date` = `2026年 11月 16日 星期一 15:51:17 CST`）。
> 本文只做归档与判定，不改代码、不碰设备、不发信。

---

## ① 一句话结论

**上游没有 Q28 类现象（冷起「只有背光」、首条 DCS 命令 DMA 超时、DYN pclk 域闩住）的对应修复，也没有可对标的公开 bug**：
上游 master（7.4.0-rc3）**根本没有 bonded 命令路径**（`BROADCAST_EN` 从不置位），所以我们那条 `bonded command DMA failed`
签名在上游不可能出现；我们唯一一次实质外部回应来自 Pengyu Luo（「面板驱动已上游，**DPU 可能不支持**」），
而 2026-10-15 的 REPORT v2（自我更正版）**三个月内零回复**；真正把 STORM 从 4/9 压到 15/15 的修法（MDSS 块复位）
**是我们自己的 M8 系列**，已投到 v5（2026-11-13 23:56 +0800，lore 有归档），**至今未被合入、也从未有人正面评估过其 Q28 证据链**。

---

## ② 时间线（外部/邮件侧，全部带证据）

| 日期（+0800） | 事件 | 证据 |
|---|---|---|
| 2026-07-03 / 07-09 | Pengyu Luo `drm/panel: Add Novatek NT36536`（v1/v2/v3），目标即 Y700 Gen4 的 CSOT PP8807HB1-1 双联面板；已进 mainline | `https://ratatoskr.run/linux-devicetree/2026/07/17190958/t`、`…/17215421/t`、`…/17237134/t`；现 master 文件存在：`curl …/plain/drivers/gpu/drm/msm/dsi/…` 同法取 `panel-novatek-nt36536.c` = **486 行**，含 `csot_pp8807hb1_1_init_seq`、`csot_pp8807hb1_1_desc`（`/tmp/p.c:212,451,464,470`） |
| 10-13 07:53:51 | 我方 **[REPORT] SM8750 bonded dual-DSI + NT36536…**（v1）发出，MID `<179184923104.248043.14168731037113716140@mail.ustc.edu.cn>` | `read-mail-ustc.py` 扫 Sent Items：`uid=95 … [REPORT] SM8750 bonded dual-DSI + NT36536: first DCS command-DMA timeout…` |
| 10-13 07:53+ | 该报告进入公共归档 | `http://www.mail-archive.com/freedreno@lists.freedesktop.org/msg47768.html`；lore 查询 `?q="bonded" s:"drm/msm/dsi"` 亦命中我方一串 |
| 10-13 12:34:58 | **Pengyu Luo 唯一实质回应**：「In a word, the panel driver is supported, the DPU may not be.」+ 说明 DPU 双 DSI/双 DSC 需 hack `dsi clk source select`，他无时间跟进 | INBOX `uid=387`（`Message-ID: <CAH2e8h6_pACX_j8YBDhhSZzbfs45waF-Y6KJo82_2c6BT0suEg@mail.gmail.com>`）；公共副本 `msg47750/47751` |
| 10-13 12:38:20 | 同一线程补 LKML 10bpc/DPU 讨论链接（`lore.kernel.org/all/CAH2e8h4Vp9fJYAUUbOmoHSKB25wakPBvmpwa62BTRqgRQbMWuw@mail.gmail.com`） | INBOX `uid=389` |
| 10-15 20:21:48 | 我方 **[REPORT v2]**（「-110 不是不变量；暗屏软件不可恢复」），MID `<179206690897.1177097.7309368787214649515@mail.ustc.edu.cn>` | Sent Items `uid=113`；公共：`freedreno msg47798`、lore `2026-10-15 12:21 UTC` |
| 10-15 → 今 | **v2 零回复**：lore 查「the command-DMA-timeout signature is not the invariant」= `Results 1-1 of 1`（只有报告本身）；IMAP 全 INBOX（15 092 封，10-01 起）按引用链扫描无任何回信 | 命令见 §⑦ ⑦-3 |
| 10-19 21:00 | 我方 `[PATCH] drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable` | Sent `uid=129` |
| 10-22 22:52 | **Taniya Das** 回 `[RFC PATCH] clk: qcom: dispcc-sm8750: reset the MDSS blocks at probe…`（架构反对：复位属 display、整块复位再配 PLL 会闪屏；实质见项目报告转述） | INBOX `uid=5843`；转述与采纳 = `reports/q28-v2-mdss-reset-20261023.md:3-4` |
| 10-23 15:52 | 我方回 Taniya（接受架构判断 + 给 A/B 数据 + 三问） | Sent `uid=143`；草稿档 `out/mail-20261023/README.md:10-24` |
| 10-22/23 | **Q28-STORM 唯一测得有效的修法落地**：0154（dispcc probe 复位 MDSS 三枚 BCR）+ 0155（DIGTOP 上电）A/B：exp 5/5、base 3/5→扩样后**含 0154 两臂合并 15/15 vs base 4/9，Fisher 双侧 p=0.003** | `reports/q28-disp-init-ab-20261022.md:106,124,163,176` |
| 10-23 21:49 | 我方回 Pengyu（附 23 发冷起 A/B 数据 + DT 协调 + 索要下游源码），MID `<179276337975.97444.18043862696501391672@mail.ustc.edu.cn>` | Sent `uid=147` |
| 10-26 00:56 | Pengyu 回：「You can squash them and send the whole thing your way」；**「No public repo」**（本地 6.19.6 树未公开，半年未更新） | INBOX `uid=6360` |
| 10-29 20:32 | 我方 `[PATCH v2 0/3] drm/msm/mdss: reset all MDSS block resets described in DT`（M8，Q28 修法的上游形态） | Sent `uid=203-206` |
| 10-31 23:03 | 我方 `[PATCH 0/5] drm/msm/dsi: collect bonded command-path data into per-SoC config`（M6） | Sent `uid=227-232` |
| 10-31 22:21–22:31 | **Dmitry Baryshkov 四连评**：「I'd prefer to see the reason for the changes. **The bonded DSI is seemingly working today.**」；并要求解释 per-SoC 数据、澄清 master 由 DT 而非 probe 顺序 | INBOX `uid=8493,8495,8497,8499` |
| 10-31 23:47–23:48 | Dmitry 评 M8 v2：2/3 追问（「Is it an interrupt controller? What is the side effect? How was it tested?」）、3/3 给方向 | INBOX `uid=8504,8506` |
| 11-02 13:40 | 我方逐一回 Dmitry 四条（披露 AI 辅助；承认 2/5、4/5 指摘；承诺 v2 在 torvalds master 重切） | Sent `uid=234`（INBOX `uid=8640` 同封） |
| 11-02 之后 | **M6 五补丁零回复**；patchwork 五枚全 `state=handled-elsewhere`、无任何 Ack/Reviewed 标签 | patchwork REST：`series 1197790` → 5 patches 全 `handled-elsewhere` |
| 11-10 13:27 | Rob Herring 对 M8 `1/3` 给 `Acked-by` | INBOX `uid=13699` |
| 11-11 16:18/16:19 | Dmitry 对 M8 `3/3` 给 `Reviewed-by`，对 `2/3` 提两问（是否中断控制器 / 副作用与测法） | INBOX `uid=14281,14284` |
| 11-11 19:09 | Dmitry 对 `PLL_SYSTEM_MUXES` 唯一意见：「This belongs to the commit message rather than the code.」⇒ 待 v2 | INBOX `uid=14408`（同文重投 `14413`） |
| 11-13 08:55–09:42 | sashiko 提 Medium（0xa000 是 dispcc 独立域、mdss 未 attach）；Konrad 给 v4 `3/3` `Reviewed-by` | INBOX `uid=14901,14903`（sashiko）、`uid=14892`（Konrad） |
| 11-13 23:56:35 | **M8 v5 四封发出（4×`Result: 250`）**，3/3 只收窄 message、三枚 R-b 全保留；lore 归档 `2026-11-13 15:56 UTC` | `out/mail-20261114/send-mdss-v5.log`（末行 `Result: 250`，`Message-ID: <20261113155635.1677541-4-xiaqinghuan@mail.ustc.edu.cn>`）；lore `?q="reset all block resets described in DT"` 命中 `[PATCH v5 0/3] … 2026-11-13 15:56 UTC`。**注意：本批在 Sent Items 里查不到**（见 §⑤-3） |
| 11-13 → 11-16 | **v5 无任何回复**（INBOX 11-13 起 266 封按引用链扫 `20261113155635` = 0 命中） | 命令见 §⑦ ⑦-4 |
| 11-16 14:46 | POR 冷起**再现真实 Q28 坏发**（「屏全白 → 只剩背光」、msm 未 bind、一个 `cardN` 都没有） | `reports/artifacts/uefi-daily-v8-20261116/README.md:50-52` |
| 项目侧口径 | Q28 于 **2026-10-24 用户裁决「已规避·结项」**（运营线 8/8 无坏发、补采样门槛作废） | `TASKS/README.md:390`、`INDEX.md:50` |

**闭环判定（一句话/线程）**

| 线程 | 日期 | 结论 | 闭环? |
|---|---|---|---|
| `[REPORT] SM8750 bonded…`（v1） | 10-13 | Pengyu：面板驱动在上游、DPU 可能不支持；无根因、无修法 | **否**（收到定性答复即停，仅一次往返 + 10-23/10-26 的 DT/下游源码支线收尾） |
| `[REPORT v2] …not the invariant` | 10-15 | 无人回应 | **否（零回复）** |
| `[Regression v3] cambist+camcc`（Q24，非 Q28） | 10-12 起 | Taniya/Konrad 参与，最后落到上游 `rpmhpd skip retention` 结论 | 是（Q24 侧） |
| `[PATCH 0/5] bonded command-path`（M6） | 10-31 | Dmitry 要求给改动理由（「bonded DSI 现在看着能用」） | **否**（我方 11-02 回复后零回应，patch 全 `handled-elsewhere`） |
| `[PATCH v1..v5] mdss block resets`（M8） | 10-29→11-13 | 三枚 R-b + Rob Acked-by；sashiko 0xa000 质疑已答（v5） | **未闭环**（等维护者，未合入） |
| `[PATCH] dsi/phy PLL_SYSTEM_MUXES` | 10-19 | Dmitry：解释进 commit message ⇒ v2 | **否**（v2 未发） |
| `[RFC PATCH] dispcc 复位 MDSS` | 10-22 | Taniya 架构反对 + sashiko 3 Medium；我方已按「搬 display 侧」出 M8 取代 | **是（被自身 v2..v5 取代）** |
| `[PATCH] drm/msm/dsi: fix AHB clock staying enabled across suspend` | 10 月 | 仅 Arpit Saini / Joonhoe Kim 两条非结论性回帖 | 否（非 Q28 主线） |

---

## ③ 症状族与判据（本项目实测 + 邮件原文）

| 族 | 现象 | 硬判据（可机读） | 出处 |
|---|---|---|---|
| **A. 面板 init 超时、系统活着** | `card0` 在、DSI-1 `connected`、SSH 可达、**只有背光**；5 行签名：`command DMA timeout: status=0x2200200` / `peer command DMA timeout` / `bonded command DMA failed: master=-110 peer=-110` / `sending dcs data ff 20 failed: -110` / `Failed to initialize panel: -5`，随后 `intf1 ctl 1 reset failure: -22` + `vblank wait timed out on crtc 0` | `dmesg` 命中上述 5 行（任意 1 行即 A 族嫌疑）；`card0` 存在 | 报告 v1 正文（Sent `uid=95`）；公共 `msg47768` |
| **B. 无 card0** | DSI host probe 更早失败 | 无任何 `cardN` | 同上（「(b) no card0 at all」） |
| **C. 连用户态都没有** | bootloader ACK 了镜像，30+ min 无 SSH/无 fastboot，只有背光；看门狗无法自救 | 无 SSH + 无 fastboot + 背光 | 同上（「(c) *new* 2026-10-13」） |
| **D. 坏发不可恢复态（DYN pclk 域闩住）** | 健康发 `CLK_STATUS=0x343 →(op=0x92) 0x743 →(op=0xb2) 0x343`（DYN_PCLK_ACTIVE 按命令瞬时开/放）；坏发 `0x1743`/`0x3743` **永不释放**，`STATUS0=0x20003`（ENGINE_BUSY\|DMA_BUSY），**DSI 中断计数 0**，`PLL_UNLOCKED` 未置（PLL 是锁的） | `clk-status-change` 全程只出现 1 次 + DYN 位不回落 | `reports/q28-dsi-recover-20261012.md:219,246,275,369,391` |
| **E. 面板暗但 DPU 全绿（最容易误判 GOOD）** | 截图有内容、frame counter 增加、DPMS `On`、connector `enabled`、背光非零可控、`disp_cc_mdss_pclk0/1_clk_src=172991986 Hz` 已被 DSI 持有 —— **仍无画面** | **唯一的物理判据 = DSI 中断计数**（亮 41 / 暗 0）+ 面板目视 | 报告 v2 §1（Sent `uid=113`）；公共 `msg47798` |
| **F. 路径相关的假坏发** | UEFI/GRUB 路径下 efifb 先注册 `card0` 再注销，msm 拿到 `card1` ⇒ 只认 `card0` 的看门狗误判 Q28 并重启两次 | `msm` 绑定在 `cardN`（N≥1） | `reports/artifacts/uefi-daily-v8-20261116/README.md:46-48`、`PITFALLS #667` |
| **G. 时间成簇** | 坏发按时间成簇（会话级）、逐启动随机、约 50%；**与镜像/构建身份无关** | 同会话交替配对采样，禁止跨会话比比例 | `reports/Q24-Q28-INDEX.md:8`、`TASKS/README.md:390` |

---

## ④ 已否证假设（每条带证伪证据）

1. **「上游有 bonded 命令路径 / 上游已有对应修复」→ 否证。**
   `curl …/plain/drivers/gpu/drm/msm/dsi/dsi_host.c`（git.kernel.org，master = 7.4.0-rc3，`/tmp/up3.c` 2 713 行）→ `grep -c BROADCAST_EN` = **0**；
   `dsi_manager.c`（`/tmp/up2.c` 621 行）无 `dsi_mgr_bonded_cmd_xfer`、无 `dsi_bonded_cmd_failed`。
   对照本仓 `linux/drivers/gpu/drm/msm/dsi/dsi_host.c:2444,2519,2560` 与 `dsi_manager.c:40,41,590` 有该路径 ⇒ **该路径是本树/下游私有**。
2. **「`-110` 命令 DMA 超时是根因」→ 已被我方自身否证。**
   去掉 bonded 路径后 `command DMA timeout`/`Failed to initialize panel` 计数 0、面板 init 报成功，**面板仍暗**（报告 v2 §1；`Sent uid=113`）。
3. **「DSI 控制器内部闩锁，DSI 侧复位可清」→ 否证。**
   坏发 `before-reset CTRL=0x175 STATUS0=0x20…` → 复位后 **DYN 位保留**、重试逐字复现（`reports/q28-dsi-recover-20261012.md:219,275`）。
4. **「用静态 force-on 绕开 DYN 握手可解」→ 首样本否证。**
   force-on 确实保持，但 `DYN_PCLK_ACTIVE`/`DYN_CMD_PCLK_ACTIVE` 仍置（`reports/q28-dsi-recover-20261012.md:434`）。
5. **「构建身份/`#N` 布局决定某次冷起成败」→ 作废（项目自撤）。**
   `reports/Q24-Q28-INDEX.md:8`「旧『构建身份伪影』定案**作废**」；七臂 vk116–vk123 全否证（同文件同日条目）。
6. **「上游 SM8750/Eliza 的破屏修法（`6cd33b6f4155`/`2028280686f4`）能治本」→ 否证（症状不同）。**
   该修复是 **byte clock 取整时机**（reparent 到 PHY PLL 后再取整），治的是 `dsi_link_clk_set_rate_6g: Failed to set rate pixel clk, -22`
   （`https://ratatoskr.run/dri-devel/2026/09/17504052/t`）；**该语义已在 master**：`/tmp/up3.c:386-397`（`clk_round_rate` 后回写 `byte_clk_rate`，注释在 `:437` 说 PLL 必须先使能才能 reparent）。
   它不解释「逐启动随机、按时间成簇、DSI 中断 0」这一族。
7. **「Pengyu 有可核对的下游树」→ 否证。**
   INBOX `uid=6360`（10-26）：「No public repo, my local tree … hasn't updated for about half a year (i.e. the 6.19.6 tree)」。
8. **「按 Taniya 的意见把复位留在 dispcc probe」→ 项目自己否证（架构）。**
   `reports/q28-v2-mdss-reset-20261023.md:3-4,26,176`：搬到 display 侧后仍 **5/5 真 POR 冷起 GOOD**，并入合并组 15/15 vs 4/9（p=0.003）。
9. **「外部已有人报同一现象（可抄答案）」→ 未找到。**
   多组检索（见 §⑦ ⑦-8/⑦-9）只命中我们自己的两份报告；postmarketOS / ubports / LWN / regzbot 对「SM8750 + bonded DSI + 冷起首条 DCS 超时」**0 命中**。
   最接近的公开案例是另一块板（Samsung gts7xllite）的 **DPU/DSI DSC `slice_per_pkt` 不一致 → vblank timeout**（`https://github.com/Marker284/samsung-gts7xllite-display-touch`），机制不同（那是 PPS/槽数不匹配，不是冷起随机坏发）。
10. **「`DYN pclk` 有公开讨论」→ 未找到。** `DYN_PCLK_ACTIVE`/`DYN_CMD_PCLK_ACTIVE` 只出现在寄存器描述 `linux/drivers/gpu/drm/msm/registers/display/dsi.xml`（`grep -n BROADCAST_EN` 同文件 `:190,191`），公开邮件列表无按此位诊断的案例。

---

## ⑤ 未解决缺口

1. **上游没有任何人正面评估过 Q28 证据链**：v1 只换到 Pengyu 的一句定性（「DPU 可能不支持」），v2（自我更正的关键一篇）**零回复**；
   M6（bonded 命令路径数据化）被 Dmitry 拦在「先给理由」，而我们给的理由（v1/v2 报告）他没回。⇒ **「是否是上游缺陷」至今无第三方判定**。
2. **修法与症状族的对应关系只在一句 commit message 里**：M8 v5 3/3 只写「5 of 9 cold PORs → 15/15」，
   没引用 v1/v2 报告 MID、没有症状族判据、没有 DYN pclk 位证据（`out/mail-20261114/v5-3of3-message.txt:20-27`）。
3. **邮件账不完整**：M8 v5 四封在 **Sent Items 查不到**（`SEARCH SUBJECT "v5 0/3"` → Sent Items 0 命中；INBOX 亦 0），
   但 `out/mail-20261114/send-mdss-v5.log` 显示 4×`Result: 250` 且 lore 有 `2026-11-13 15:56 UTC` 归档 ⇒ 送达可信，
   **本地 IMAP 副本缺失（APPEND 未做）**，与 `reports/upstream-status-20261113.md:12` 自称的「v5 4×250（2026-11-14）」日期也不一致（lore 是 11-13 23:56 +0800）。
4. **`PLL_SYSTEM_MUXES` 补丁是否仍有 delta 未核实**：master `dsi/phy/dsi_phy_7nm.c:439` 已有 `writel(0xc0, … PLL_SYSTEM_MUXES)`
   （disable 侧 `:417` 写 0），与我方补丁「代码只留 `writel(0xc0, …)`」高度重叠 ⇒ **未做 diff 前不能主张该补丁仍有内容**（未找到证据 = 未做，不是「已冗余」）。
5. **`DIGTOP_PWRDN_B`（armadaos 0155，Q28 相邻的 PLL 锁修法）在上游不存在**：`/tmp/p7.c`（master 1 566 行）`grep -n "DIGTOP"` = **0 命中** ⇒ 仍是下游私有，未被上游化，也未被外部评审。
6. **M8 自身两条测量边界**（自曝、未补）：15/15 用的是**三枚**形状（含 RSCC），v4/v5 只剩两枚 ⇒ **两枚形状从未上机**；`0xa000` **从未单变量**。
   出处：`out/mail-20261114/re-sashiko-mdss-v4.txt` 与 `reports/mail-send-20261114-mdss-v5.md:19-24`。
7. **「结项」与事实并存**：Q28 于 10-24 判「已规避·结项」（`TASKS/README.md:390`），但 11-16 冷起又出现**真实**坏发一例
   （`reports/artifacts/uefi-daily-v8-20261116/README.md:50-52`）⇒ 结项是**运营口径**（看门狗兜底），**根因仍未指名**。
8. **无第三方复现**：没有任何外部单位/个人在本板或他板上报同一「只有背光 + DSI 中断 0」现象；外部也无人验证我们的 15/15。

---

## ⑥ 下一步实验（可执行命令 + 判据）

> 全部只读或只发本机命令；涉及发信/上机的都在判据里写明「需用户放行」。

1. **核 `PLL_SYSTEM_MUXES` 是否还有 delta（只读网络 + 本地 patch）**
   ```sh
   curl -sS --max-time 35 "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c" -o /tmp/p7.c
   grep -n "PLL_SYSTEM_MUXES\|DIGTOP\|pll_bias" /tmp/p7.c
   git -C linux apply --stat patches/upstream/m1-2026-10-14/0001-* 2>/dev/null; ls patches/upstream/ | grep -i muxes
   ```
   判据：若 `apply --check` 在 master 上失败且 `:439` 的 `writel(0xc0)` 语义等价 ⇒ **改投 DIGTOP 版或撤回 v1**；若能干净 apply ⇒ 发 v2（只搬注释）。

2. **把 Q28 症状族 + 0154 A/B 正式回帖到既有报告线程（需用户放行发信）**
   ```sh
   # 线程 = [REPORT v2] MID <179206690897.1177097.7309368787214649515@mail.ustc.edu.cn>
   grep -n "In-Reply-To\|References" out/mail-20261023/re-taniya-q28-dispcc.txt   # 取线程链后按 scripts/send-mail-ustc.py 流程 dry-run
   ```
   判据：lore `/linux-arm-msm/` 归档命中新 MID + 90 天内收到 ≥1 位维护者（Dmitry/Pengyu/Konrad/Taniya）的定性回复；
   若仍零回复 ⇒ 归档为「上游不感兴趣」，Q28 收尾只走「已规避」口径。

3. **复核 v2 的物理判据（只读 SSH，设备已在良性态）**
   ```sh
   ssh <u2> 'dmesg | grep -cE "command DMA timeout|bonded command DMA failed"; \
             grep -c . /proc/interrupts >/dev/null; \
             cat /sys/class/drm/card*/card0-DSI-1/status 2>/dev/null; \
             cat /sys/class/drm/card*/card0-DSI-1/dpms'
   ```
   判据：面板**亮**的样本必须 `command DMA timeout` 计数 0 **且** DSI 中断计数 >0（历史上亮 41 / 暗 0，`Sent uid=113`）；
   若出现「dmesg 干净但中断 0 + 只有背光」⇒ 复现 v2 的「-110 与暗屏可分离」核心事实，可作为回帖的硬证据。

4. **核 v5 是否真的无回信（只读 IMAP）**
   ```sh
   python3 ~/.local/bin/read-mail-ustc.py --days 5 --folders 'INBOX,"Junk E-mail"' --grep mdss,sm8750,reset
   ```
   判据：出现 `Re: [PATCH v5 …]` 即为有新评审；零命中 ⇒ 维持「等维护者」口径。

5. **M8 自曝边界补齐（需上机 + 用户放行 POR）**
   交替配对采样：`两枚形状(v4/v5)` vs `三枚形状(0154)` 各 ≥3 发、同会话交替（`scripts/q28-cold-run.sh`，每次真实 POR）。
   判据：Fisher 双侧 p<0.05 才可写「两枚等价」；否则 v5 3/3 的措辞必须再收窄（当前已声明「未重复」）。
6. **`0xa000` 单变量（需上机）**：只 assert `CORE_BCR` vs `CORE_BCR+CORE_INT2_BCR`，各 ≥3 发冷起。
   判据：`0xa000` 贡献若为 0 ⇒ v5 3/3 可只留一枚（更易合入）；若非 0 ⇒ 补 sashiko 质疑方的实测回答。

---

## ⑦ 引用清单

**邮件（本机 IMAP，2026-11-16 读取）**

1. Sent Items `uid=95` — `[REPORT] SM8750 bonded dual-DSI + NT36536: first DCS command-DMA timeout on cold boot`，`2026-10-13 07:53:51 +0800`，MID `<179184923104.248043.14168731037113716140@mail.ustc.edu.cn>`。命令：`read-mail-ustc.py --days 45 --folders 'INBOX,"Sent Items"' --grep q28,dsi,panel,pclk,vblank,dma,nt365`
2. Sent Items `uid=113` — `[REPORT v2] … the command-DMA-timeout signature is not the invariant; dark panel is not recoverable in software`，`2026-10-15 20:21:48 +0800`，MID `<179206690897.1177097.7309368787214649515@mail.ustc.edu.cn>`
3. INBOX `uid=387/389` — Pengyu Luo，`2026-10-13 12:34:58 / 12:38:20`，MID `<CAH2e8h6_pACX_j8YBDhhSZzbfs45waF-Y6KJo82_2c6BT0suEg@mail.gmail.com>` / `<CAH2e8h7H5-DzTj1zwejYQyNNtupurgzYq4t6gKPZoZw=7EQvrA@mail.gmail.com>`
4. Sent Items `uid=147` — 我方回 Pengyu，`2026-10-23 21:49:39 +0800`，MID `<179276337975.97444.18043862696501391672@mail.ustc.edu.cn>`
5. INBOX `uid=6360` — Pengyu Luo，`2026-10-26 00:56:37 +0800`，MID `<CAH2e8h4wFH5Q_biepZzQuerydvmwbUOsEMRRzs4y-c-0WbjYrw@mail.gmail.com>`
6. INBOX `uid=8493/8495/8497/8499` — Dmitry Baryshkov 评 M6 五补丁，`2026-10-31 22:21–22:31 +0200`；Sent `uid=234`（我方 `2026-11-02 13:40:54 +0800` 回复）
7. INBOX `uid=5821/5843` — sashiko / Taniya Das 评 `[RFC PATCH] clk: qcom: dispcc-sm8750: reset the MDSS blocks at probe…`，`2026-10-22`；Sent `uid=143`（我方 `2026-10-23 15:52:50 +0800` 回复）
8. INBOX `uid=14408`（+`14413` 重投）— Dmitry 评 `PLL_SYSTEM_MUXES`，`2026-11-11 19:09:07 +0200`；Sent `uid=129`（`2026-10-19 21:00:41 +0800`）
9. INBOX `uid=8227/8504/8506/13699/14281/14284/14892/14901/14903` — M8 mdss 块复位系列评审：Konrad（10-30 binding）、Dmitry 2/3+3/3（10-31、11-11）、Rob `Acked-by`（11-10）、Konrad `Reviewed-by`（11-13）、sashiko 0xa000 Medium（11-13）
10. `out/mail-20261114/send-mdss-v5.log` — v5 四封 sendmail 记录，末封 `Date: Fri, 13 Nov 2026 23:56:35 +0800`、`Message-ID: <20261113155635.1677541-4-xiaqinghuan@mail.ustc.edu.cn>`、`Result: 250`
11. `out/mail-20261114/v5-3of3-message.txt:20-27` — 唯一提到 Q28 症状的 upstream 正文（「5 of 9 cold PORs … 15 out of 15」+ 两条测量边界）
12. `out/mail-20261023/README.md:10-24`、`out/mail-20261023/re-taniya-q28-dispcc.txt` — 回 Taniya 的 Q28 A/B 数据与三问草稿
13. `out/mail-20261031-b/re-konrad-mdss-rsc.txt`、`out/mail-20261102-b5/re-dmitry-b5-4items.txt`、`out/mail-20261113/re-mdss-3q.txt`、`out/mail-20261114/re-sashiko-mdss-v4.txt` — 相关回信原件

**项目文档**

14. `reports/Q24-Q28-INDEX.md:8` — Q28 当前口径（坏发 ~50%、按时间成簇、构建身份作废）
15. `TASKS/README.md:390` — Q28 行：2026-10-24 用户裁决「已规避·结项」、8/8 结项样本
16. `INDEX.md:50` — 「已结项、勿重推：Q28/Q32 = 已规避」
17. `reports/q28-dsi-recover-20261012.md:219,246,275,369,391,434` — DYN pclk 域生命周期判据、force-on 否证、七臂结论
18. `reports/q28-disp-init-ab-20261022.md:106,124,163,176,249` — 0154/0155 A/B（15/15 vs 4/9，p=0.003）
19. `reports/q28-v2-mdss-reset-20261023.md:3-4,19-26,176` — 复位搬到 display 侧、5/5 真 POR GOOD
20. `reports/upstream-status-20261113.md:12,23,24,26` — mdss v4→v5 / dsi/phy 待 v2 / counter-dispcc RFC 无回信
21. `reports/mail-send-20261114-mdss-v5.md:1-24` — v5 发出账与 sashiko 质疑处置
22. `reports/artifacts/uefi-daily-v8-20261116/README.md:46-48,50-52` — #667 看门狗误判（card1）与 11-16 真实 Q28 坏发
23. `reports/q28-community-cases-20261012.md:1-60` — 既有社区检索档（nt36536 上游化、`2028280686f4`、rm69299 拆分 DCS）

**外部**

24. `http://www.mail-archive.com/freedreno@lists.freedesktop.org/msg47768.html`（v1）、`…/msg47798.html`（v2）、`…/msg47750.html`、`…/msg47751.html`（Pengyu 回帖）
25. lore 检索：`https://lore.kernel.org/all/?q="bonded" s:"drm/msm/dsi"`（我方 5 补丁 + Dmitry 四条 + 历史 bonded 线程）；`?q="the command-DMA-timeout signature is not the invariant"` → `Results 1-1 of 1`（**零回复**）；`?q="reset all block resets described in DT"` → 含 `[PATCH v5 0/3] … 2026-11-13 15:56 UTC`
26. patchwork REST：`https://patchwork.kernel.org/api/1.2/patches/?series=1197790&project=linux-arm-msm` → 5 枚全 `handled-elsewhere`、无 tags
27. 上游源码（git.kernel.org plain，master = `7.4.0-rc3`，`curl …/plain/Makefile`）：`dsi/dsi_host.c`（`/tmp/up3.c`，`grep -c BROADCAST_EN` = 0）、`dsi/dsi_manager.c`（`/tmp/up2.c`，无 `*_bonded_cmd_*`）、`msm_mdss.c`（`/tmp/u_msm_mdss.c:324-343` 只取一枚无名 reset）、`dsi/phy/dsi_phy_7nm.c`（`/tmp/p7.c:417,439` 有 `PLL_SYSTEM_MUXES` 写 0/0xc0；`grep -c DIGTOP` = 0）、`panel/panel-novatek-nt36536.c`（`/tmp/p.c` 486 行，`csot,pp8807hb1-1` 已在，无 retry）
28. `https://ratatoskr.run/dri-devel/2026/09/17504052/t`（Krzysztof：revert `6cd33b6f4155`，byte clock 取整时机错 → Eliza/SM8750 破屏）
29. `https://ratatoskr.run/linux-devicetree/2026/07/17190958/t`、`…/17215421/t`、`…/17237134/t`（nt36536 v1/v2/v3）
30. `https://github.com/Marker284/samsung-gts7xllite-display-touch`（他板 vblank timeout 的可比案例：DPU/DSI DSC `slice_per_pkt` 不一致；机制不同）

**未找到（诚实声明）**

- 未找到任何**上游/外部**针对「SM8750 + bonded dual DSI + 冷起首条 DCS 命令 DMA 超时 / 只有背光 / DYN pclk 域闩住」的 bug 报告、补丁或 issue（lore、patchwork、mail-archive、regzbot、postmarketOS、ubports 均 0 命中）。
- 未找到 `0x2200200`（CMD DMA 超时 status）在公开邮件列表中的第二例。
- 未找到有人对我们 REPORT v2（2026-10-15）或 M8 v5（2026-11-13）的任何回复（截至 2026-11-16 16:2x CST）。
- 未找到 nt36536 面板侧 `-110` 重试逻辑的上游对应物（现 master `panel-novatek-nt36536.c` 无 retry；本仓 `novatek_prepare()` 的 retry 是 elden 自有，见 `reports/q28-community-cases-20261012.md:21`）。
