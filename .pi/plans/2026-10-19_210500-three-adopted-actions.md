# 2026-10-19 三项采纳项 — 执行计划

> 依据：`reports/mail-triage-20261019.md` §5 第 2/4/5 位 + 用户 2026-10-19 「三个推荐均采纳」。
> 范围：① M1 `PLL_SYSTEM_MUXES` 解冻投递；② 联系 Joonhoe Kim（信息性）；③ M3-1 v3 按 sashiko 重做。
> 纪律：`.pi/AGENT-OPS.md` §1/§3/§5（先备份、一次正反判断、无设备证据不写已解决、收尾五项）。

## 0. 目标与总判据

| # | 目标 | 完成判据（可核） |
|---|---|---|
| A | M1 补丁进上游归档 | `/linux-arm-msm/` 与 `/dri-devel/` 各 1/1 归档 + Message-ID 记录 + 本仓 README 状态改「已投递」 |
| B | Joonhoe Kim 线程建立 | 1 封纯信息邮件已发（无索取、无未公开信息），lore/邮箱可回读；结论落 `reports/` |
| C | M3-1 v3 备料完成（是否发送见 C4） | `patches/upstream/m3-v3-2026-10-2x/` 2 枚、checkpatch 0/0/0、`dt-doc-validate` rc=0、`W=1` 全量 dwc3 0 warn、pristine `git am` rc=0 |

串联顺序：**A（最快，先做）→ B（需 10 min 设备窗口做一次测量）→ C（主机长活，可并行起草）**。
并行度：A/B/C 可三路并行，但 **B 的设备测量与任何设备实验互斥**（`scripts/device-lock.sh`）。

---

## A. M1 `PLL_SYSTEM_MUXES` 投递（主机 + 邮件）

**现状**：`patches/upstream/m1-2026-10-14/0001-…patch` 净 9 行；门已全绿（checkpatch 0E/1W/0C，
唯一 W = partial clone 缺 `44784327815b`，良性）；`build/m1-73` = `24a19b953 (v7.3-rc7)` + 2 提交，
板 DTB 与在机 `vk127` 逐字节同。

### A1 投递前复核（15 min）
1. 取上游最新：`git -C build/m1-73 fetch --tags origin`（或 linux.git）确认 **7.3-rc7 之后
   `drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c` 无冲突改动**；若有，rebase 到最新 -rc 并重跑 A2 全部门。
2. 重生成补丁：`git -C build/m1-73 format-patch -1 24223e44a --stdout > /tmp/m1-v2.patch`，
   与 `patches/upstream/m1-2026-10-14/0001-*.patch` 比对（应仅时间戳/索引行差异）。
3. 确认「无板级私有信息」：正文只引用 `93c97bc8d85d` / `44784327815b` 与通用的
   `pll_enable_cnt` 语义；**不得**出现 TB322FC/elden/vk 号/我们的 DTB。

### A2 门（沿用并复跑）
```bash
scripts/checkpatch.pl --strict --no-tree /tmp/m1-v2.patch        # 0E/0W/0C 期望
git -C build/m1-73 worktree add --detach /tmp/m1-verify 24a19b953
git -C /tmp/m1-verify am /tmp/m1-v2.patch                        # rc=0
make -C /tmp/m1-verify -j16 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 \
     drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.o                   # rc=0 / 0 warn
```

### A3 投递
- 通道：`git send-email`（`smtp.ustc.edu.cn:465`，技能 `upstream-mail-ustc`）。
- To：Dmitry Baryshkov、Abhinav Kumar、Jessica Zhang（按 `get_maintainer.pl` 现查为准）。
- Cc：`dri-devel@lists.freedesktop.org`、`linux-arm-msm@vger.kernel.org`、`freedreno@lists.freedesktop.org`、
  `linux-kernel@vger.kernel.org`，并 Cc revert 作者（`44784327815b` 的 author，现查）。
- 版本：**v1**（首次投稿），Subject 形如
  `[PATCH] drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable`。
- 正文要点：上游 revert 造成的确定性缺失；为何把写入放回 `dsi_7nm_phy_enable()` 预置块而不动
  refcount 语义（避免再以「破坏非 bonded」被 revert）；实测平台（只说 SM8750 + bonded dual-DSI，
  不点名机型）。

### A4 复核与入库
1. `read-mail-ustc.py --days 1 --grep PLL_SYSTEM_MUXES` 与
   `lore-query.py "https://lore.kernel.org/linux-arm-msm/?q=s:PLL_SYSTEM_MUXES"`、`/dri-devel/` 各复核一次。
2. 把 Message-ID + 归档链接写进 `patches/upstream/m1-2026-10-14/README.md`（状态：**已投递 2026-10-19**）。
3. `TASKS/README.md` §7 M6 L1 行「已备料未发送」→「已投递（Message-ID …）」。
4. 新会话记录：`TASKS/sessions/2026-10-19-m1-投递.md`。

**风险**：邮件不可撤回；若 A1 发现上游已自行修复（grep `PLL_SYSTEM_MUXES.*0xc0` 在最新 -rc），
**立即停止投递**，改记为「上游已修，我们撤回」。

---

## B. 联系 Joonhoe Kim（设备 10 min + 主机起草/发送）

**背景**：他在 `drm/msm/dsi: fix AHB clock staying enabled across suspend` 线程公开（`<20261016125036.1069-1-26rote@gmail.com>`）：
Y700 **Gen5 / SM8850 / bonded DSI / v7.3-rc4；读 `clk_summary` 会 runtime-resume 时钟控制器；
「显示关、系统醒」时 probe 期 `clk_prepare` 使 dispcc 常 runtime active + MMCX 常 on；30 次 DPMS off/on 未死。**

### B1 先取我们自己的可对照观测（10 min，单设备窗口）
在 `vk127`（当前 GOOD 台）上，**只读**采集（先 `scripts/device-lock.sh`）：
1. `cat /sys/devices/platform/soc@0/*/power/runtime_status`（定位 dispcc / mdss / dsi 控制器节点），
   记录**显示开**时状态；
2. `ScreenSaver.SetActive(true)`（`PITFALLS #294`：`dpms` sysfs 只读）→ 等 5 s → 再读同一批 `runtime_status`；
3. 同时取 `dmesg | tail`、`/sys/kernel/debug/clk/clk_summary` **最后读**（已知副作用，标注「读取动作本身会 resume」）；
4. **恢复显示** `SetActive(false)`；核对 `boot_id` 未变（Q24 安全判据）。
> 若 B1 因任何原因触发异常（should not，7.3 线 41/41 安全），停止 B 并保留现场，不上报机型信息。

### B2 起草（不做承诺、不索取数据、不透露 G2/G3）
- 主题：`Re: drm/msm/dsi: fix AHB clock staying enabled across suspend`（`In-Reply-To: <20261016125036.1069-1-26rote@gmail.com>`）。
- 内容 4 段：① 我们平台（SM8750P + bonded dual-DSI NT36536，v7.3-rc7）与他的观察对应；② 我们**实测**的
  dispcc/MMCX runtime 状态（B1 数据，注明 `clk_summary` 副作用）；③ 我们在坏启动（面板 init 失败）时
  观测到 DPU `core_irq` 3 s 内冻结（`reports/q28-DOSSIER.md`），与「dispcc 残留 active」是否并存**仅作观察陈述**；
  ④ 问一个**低负担**问题：他的 v7.3-rc4 台架在「显示关、系统醒」时是否也看到 dispcc 残留 runtime active。
- 明确写：**不需要他提供日志**、我们不是要 patch review。
- 纯 ASCII、无附件（技能 `upstream-mail-ustc` §1）。

### B3 发送与入库
1. `send-mail-ustc.py <draft>` dry-run（核对头/行数/非 ASCII）→ `--send`。
2. `read-mail-ustc.py --days 2 --grep Joonhoe` 回读确认已发。
3. 产物：`reports/joonhoe-kim-contact-20261019.md`（含 B1 数据、邮件全文、Message-ID）+ 会话记录一行。

**用户确认点**：发送前把草稿正文贴给用户过目（对外发言；用户已原则批准，但正文需一眼确认）。

---

## C. M3-1 v3（按 sashiko 12 条重做）— 主机长活

**输入**：`patches/upstream/m3-v2-2026-10-17/`（2 枚，v2 已投、人类 0 回复）、
`reports/mail-triage-20261019.md` §5 第 2 位（sashiko 摘要）、sashiko 原文（`/tmp/mailfocus3/`，如已清则从邮箱重取）。

### C0 先做**一次正反判断**（30–45 min，产出结论再动手）
命题：**binding 形状是否改用标准 `mux` 子系统**（`mux-controller` + `gpio-mux`/`reg-mux` +
`muxes` 属性），而不是自定义 `port-select-gpios`。

判据（按顺序，任一为「是」⇒ 采纳标准 mux）：
1. 上游 `drivers/usb/dwc3/` 或 `drivers/usb/typec/` 已有消费 `mux_control` 的先例（`grep -rn "mux_get\|mux_control"`）；
2. DT schema 里 `snps,dwc3` 或其父节点已有 `muxes` 可用位（查 `Documentation/devicetree/bindings/usb/`）；
3. sashiko 的 binding 5 条中「是否改用标准 mux」被明确点名（是）。

产出：`reports/m3-v3-binding-decision-20261019.md`（≤1 页：选 A/B、理由、对驱动改动量的估计）。
**若选标准 mux**：驱动侧从自写 `dwc3_role_mux` 改为 `mux_control` ⇒ 代码量下降，但 binding 重写、
cover letter 需重新回答 Konrad 的 topology 质疑。
**若维持自定义**：必须逐条回答 sashiko 的 binding 5 条（`port@2` 语义、`usb-role-switch` 位置、
`port-select-gpios` 条件、两 port 同 `mux-state` 约束）。

### C1 修 sashiko 12 条（按优先级）
- **Critical**：`dwc3_role_mux_init()` 错误路径未 `cancel_delayed_work(&drd_work)`。
- **High**：① `port->stamp` 只在 `NONE→非NONE` 更新（in-place swap 不得丢总线；`time_before` MAX_LONG 回绕）；
  ② 释放锁后 `dwc3_set_mode()` 的 `desired_port`/`desired_dr_role` 竞争（合并同一临界区）；
  ③ role switch 不注册在 endpoint fwnode 上。
- **Medium**：fwnode 泄漏；`error` + `desired_dr_role` 未被读（删或真上报）；补 `dwc3_pre_set_role()`。
- **binding 5 条**：按 C0 结论统一改写。
- 每改一条在 `reports/m3-v3-sashiko-ledger.md` 记「条目 → 改法 → 对应 diff 行 → 验证方式」。

### C2 门（必须全量，不接受「相关目录编译过」）
```bash
./scripts/checkpatch.pl --strict --no-tree patches/upstream/m3-v3-*/000*.patch   # 全部 0E/0W/0C
dt-doc-validate Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml      # rc=0
make -j16 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 drivers/usb/dwc3/      # 0 warning
# 全量门：在 pristine 24a19b953 上 git am 两枚 + make Image.gz dtbs（0 err / 0 warn）
```

### C3 产物
`patches/upstream/m3-v3-2026-10-2x/{0000-cover-letter,0001,0002}.patch` + `README.md`（变更表 + 门结果 + 复现命令）。

### C4 投递决定
- v3 属 M3-1 同系列延续（M3-1 是唯一已解冻例外）⇒ **默认投递**，作为 v3 回复原线程
  （`In-Reply-To` v2 cover Message-ID `20261017081320.220525-1-xiaqinghuan@mail.ustc.edu.cn`）。
- 但若 C0 改了 binding 形状（标准 mux）⇒ **先只发 cover + binding（RFC 口吻）问形状**，
  不一次押上驱动实现；等 Konrad/Krzysztof 一句「形状 OK」再发 v4。**这一点在 C0 结束时给用户确认**。

---

## D. 排期与资源

| 时段 | 内容 | 执行 |
|---|---|---|
| T+0 | A1–A2（M1 复核 + 门） | 主 agent |
| T+0 ∥ | C0 正反判断（读上游源码） | 子代理（DeepSeek flash）+ 主 agent 审 |
| T+30 min | A3 投递 → A4 复核 | 主 agent |
| T+40 min | B1 设备测量（独占设备窗口 10 min） | 主 agent（设备写/读） |
| T+50 min | B2 起草 → 用户过目 → B3 发送 | 主 agent |
| T+60 min | C1 按 ledger 改代码（2 枚补丁） | 子代理实现 + 主 agent 全量门 |
| 收尾 | `check-doctor` FAIL=0、`git commit`、工作区干净 | 主 agent |

并发上限按 `fabric.json`（8）；C1 实现 lane 与 B1 设备窗**不同时**。

## E. 涉及文件（预计）

- `patches/upstream/m1-2026-10-14/README.md`（状态更新）
- `patches/upstream/m3-v3-2026-10-2x/**`（新建）
- `reports/joonhoe-kim-contact-20261019.md`、`reports/m3-v3-binding-decision-20261019.md`、`reports/m3-v3-sashiko-ledger.md`
- `TASKS/README.md`（§7 M6 L1 行、§1 M3-1 行）
- `TASKS/sessions/2026-10-19-{m1-投递,m3-v3,joonhoe-contact}.md`（按需合并为 1–2 个）
- 可能：`PITFALLS/`（若出现新坑）

## F. 风险 / 待确认

1. **M1**：上游 7.3-rc7 之后可能已变动或已被别人修 → A1 有硬停条件（不投）。
2. **B**：对外发言；正文须用户过目；不得提 G2/G3、不得写入设备 SN/IP。
3. **C0 结论会改变工作量**：标准 mux 路线可能让 v3 变成「binding 重写 + 驱动删减」，周期从 1 天到 2–3 天。
   若倾向「先发形状 RFC」，投递节奏变成两段式。
4. **设备窗口**：B1 需要显示一次开/关；当前 `vk127` 在 7.3 线 41/41 安全，但仍是 Q24 未解语境，
   操作前先确认 `boot_id` 记录，异常即停并保留现场。
5. **M3 v3 与 M3-2 板 DTS**：v3 仍不带板文件；若 binding 改为标准 mux，M3-2 的板 DTS 也要跟着改，
   需同步更新 `TASKS/README.md` §7 的 M3 顺序。

## G. 用户需拍板的 2 个点

- **G1**：B2 草稿正文（发送前过目）。
- **G2**：C0 出结论后，若需要改 binding 形状 → 走「先 RFC 问形状」还是「直接 v3 全量」。
