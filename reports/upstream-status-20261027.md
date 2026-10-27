# 上游化状态（2026-10-27）—— M 系列一页 + 门禁 + 残留

> 取代 `reports/upstream-status-20261026.md` 作为**当前页**（该文件保留作 10-26 快照）。
> 口径：**投递按系列逐次由用户批准**（2026-10-13 的「全面投递冻结」已于 2026-10-19 起逐案放开，
> `TASKS/README.md` §7 头部已同步）；本页只记**事实 + 下一步**，不复述各系列设计。
> 本轮**未扫邮箱**（用户口径「邮件不盯」）；最后一次邮件差量 = `reports/mail-triage-20261026.md`
> （窗口 10-23 00:00Z → 10-26 05:36Z）。lore 直查受 Anubis 反爬限制，回包事实以订阅 INBOX 为准。

## §0 一页状态表

| 系列 | 状态 | 最后动作 | 卡在谁 | 下一步 |
|---|---|---|---|---|
| **M3-1**（USB 双连接器 / dwc3） | 🟡 等 review | 2026-10-26 12:32Z 投**正式 `[PATCH v4 0/3]`**（binding + `usb_role_switch_at_endpoint()` + 驱动），4 封 250、lore 双列表归档 | Krzysztof / Konrad / USB 维护者 | 等回包；有 review 即出 v5（不再自行加料） |
| **M4-1**（camss 三枚 binding：gt9764 / s5kjns / wl2868c） | 🟡 等 review | 2026-10-27 投两条线程（media `[PATCH 0/2]` + regulator 单枚），lore 已归档 | Mauro / Mark Brown | 常见回包 = 「要驱动同发」⇒ 见 M4-2…M4-4 |
| **M4-2…M4-4**（camss 驱动主体） | ⬜ 备料完成，**未投** | 2026-10-27 `patches/upstream/m4-camss-series-20261027/`（7 提交 / +1760 −61；checkpatch 7/7 0E；逐提交可编译） | **硬项**：R1 数值出处 → 🟡 **已降级**（厂商 `camera.ko` 数据段对账：lane 表 99/103 一致）/ R2 `0x138` → ✅ **已解决**（厂商 `csiphy_v2_4_0[+4]=0x1138`）/ R3 SOF 迁移应单立 RFC（不变） | R1 剩余 = 4 条 SKEW_CAL 偏离（`0x54` vs 厂商 `0x00`）需上机 A/B；R3 拆 RFC；见 `reports/m4-csiphy-vendor-provenance-20261027.md` |
| **M4-5**（ath12k PEACH、hci_qca PERI） | ⬜ **未备料** | — | 只有 M3-6 的拆解清单 | 排在 camss 之后 |
| **M8**（dispcc MDSS 复位 RFC） | 🟡 等 maintainer | 2026-10-22 投 RFC；Taniya 反对复位归属，我方 10-23 已回（接受搬 `msm_mdss_reset()`） | clk 维护者 | 等回包；必要时转正式系列（含 DT 属性） |
| **M6 L1**（DSI `PLL_SYSTEM_MUXES` 1 行） | 🟡 等 review | 2026-10-19 投，已归档 | arm-msm 维护者 | 随 M6 系列走 |
| **M6 B5-P1/重构**（bonded DSI per-SoC cfg） | ⬜ **设计稿已出**（2026-10-27） | `reports/b5-per-soc-cfg-design-20261027.md`：现状 = bonded 增量 **+902 −76**（四文件）而 per-SoC 侧 **0 行改动**；方案 = 数据进 `msm_dsi_config` + 行为进 `host_cfg_ops`；拆 5 步（前 3 步行为中性） | 第 4 步（master 不由 bind 顺序决定）需上机；第 5 步（`0x001f0200/0x44440400` 魔数）无文档 ⇒ 永久隔离 | 先做 1–3（主机侧、`grep` 可判），再谈 4 的上机 |
| **M6 B5-P4**（Q28 bonded DSI） | ⬜ RFC 备料，未发 | 2026-10-27 `patches/upstream/m6-b5-p4-rfc-20261027/RFC-SCOPE.md`（建议拆 3 提交 + 4 条接受风险） | 需上机对照（P4 会移动 Q28 坏发率） | 先做 H39/H40 使能时机对照，再定 RFC 文本 |
| **M2 A2**（battmgr `power_now`） | 🟡 球在我方 | 2026-10-26 vendor repo 已核对（`reports/m2-a2-vendor-repo-check-20261026.md`） | Konrad 要求基线换 `linux-next/master` | ① A2 与 linux-next 逐 hunk 比对（是否已被覆盖）② 开发基线切 linux-next |
| **M2 A1 / P3** | ✅ A1 撤稿（与上游 `3389406e6a03` 重复）；P3 gamma LUT OOB 修复已投 | — | — | 无 |
| **M3-3 / M3-4 / M3-6**（音频 aw88461 / 显示 4 枚 / WCN pwrseq） | ⬜ 封存备料 | 2026-10-13 | 用户尚未批准投递 | 按 M3-1 收口后再逐片投 |
| **M5**（`dm-default-key` → 出树 patchset） | ⬜ 立项完，patchset 未交付 | 2026-10-13 报告 + 隔离已在上游树完成 | — | 交付「能力用上游 `dm-inlinecrypt` + patchset 封存」两件 |
| **M7**（Q24 rpmhpd retention） | ✅ **关闭** | 上游修复已在 7.3 线 ⇒ 无需我方补丁 | — | 可选：把 debugfs/cmd-db 观测数据回给 Konrad/Taniya（纯观测） |
| **U3**（`rpmhpd` `presync_floor`） | ✅ **关闭（删除）** | 2026-10-27：本机 `gfx`/`gmxc` consumer = 0 ⇒ 分支不可达；删后与 pristine 逐字节相同（D13） | — | 不立项；若将来 DTS 给这两域挂消费者再按报告 §3 议 |
| **U4**（`aw86927` SRAM 窗口） | 🟡 本地收口，上游化并入待建系列 | 2026-10-27 数据表重构（+39 −25，`W=1` 0 warning，行为等价） | 需先建 5 提交系列（binding → chip 数据 → 固件装载 → AW86937 差异 → 双控） | 见 `reports/u4-aw86927-sramwindow-20261027.md` §1；风险 = 维护者可能主张「用驱动内波形、不要固件」 |
| **M1-U6**（`qcom_q6v5_pas` DTB 固件泄漏） | ⬜ 补丁已备，**未投** | 2026-10-27 `patches/upstream/m1-pas-dtbfw-20261027/`（+5 −4，0E/0W/0C） | 用户批准 | 投 `linux-remoteproc`（Bjorn Andersson）；建议同时合进 M1 树 |
| **M9**（ITS/LPI kexec 认领） | ✅ **已撤回** | Marc Zyngier 否方案；回信 2026-10-26 已发并回读 | — | 不做；正解在 loader/EFI 侧（与本项目当前主线无关） |

## §1 本轮（10-27）新增的三件事

1. **M4-1 投出**（用户批准）：两条线程、三枚 binding，实发件留档
   `patches/upstream/m4-camss-2026-10-13/sent-20261027/`（投递前修掉占位身份 `Elden Mainline Agent <…@localhost>`
   → `Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>`，并把原捆一个系列的写法拆成 media / regulator 两条线程）。
2. **M4-2…M4-4 驱动系列备料完成**：把本地功能树里「一次性提交」的整块 camss 重切成 7 个**逐条可编译**的提交；
   相对下游树的两处有意改动 = 匿名 `union{reg_update; rup_update; aup_update}` → 显式字段、
   两处 `CAMSS_8750` 特判隔离成 `NOT FOR UPSTREAM` 提交。风险清单见该目录 `README.md` §4（R1–R7）。
3. **M1-U6 终审（新增）**：`qcom_q6v5_pas` 的 DTB 固件在成功路径泄漏，D6「上游 release 路径取代」的依据被推翻；
   补丁 `patches/upstream/m1-pas-dtbfw-20261027/`（+5 −4，0E/0W/0C，**未投**），证据
   `reports/m1-u6-pas-dtbfw-leak-20261027.md`。**D 类未决 9 → 8 条**（U6 结项；另 U8 `CONFIG_FS_ENCRYPTION` 核查为「当前不编译」，同批结项）。

## §2 机械门（可复用，本轮原始结果）

```sh
# 风格（必须在内核树内跑，用目标树自带 checkpatch）
cd build/m4-base && perl scripts/checkpatch.pl --strict --no-tree \
  /home/xuqianhui/y700-elden/patches/upstream/m4-camss-series-20261027/*.patch
# → 7 枚：0 errors；3 条 WARNING 全是 MAINTAINERS 整目录 glob 假阳性

# binding schema
dt-doc-validate Documentation/devicetree/bindings/media/qcom,sm8750-camss.yaml   # rc=0

# 逐提交可编译（arm64 defconfig，CONFIG_VIDEO_QCOM_CAMSS=m）
for c in $(git rev-list --reverse 24a19b953..HEAD); do
  git checkout -q $c && make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
    drivers/media/platform/qcom/camss/ || echo "FAIL $c"; done               # → 7/7 OK
```

## §3 依旧存在的上游化残留（不属任何已投系列）

| 残留 | 说明 |
|---|---|
| **D 类剔除未终审（4 条未决）** | M1 重基树里 DSI 一族（B5/Q28 相关）仍留树内待重构，见 `TASKS` §7 M1 行与 `reports/m1-rebase-7.3rc7-execution-20261013.md` §4。**2026-10-27 三次更新**：U6 = 真 bug 补丁已备（`reports/m1-u6-pas-dtbfw-leak-20261027.md`）· U4 = 本地数据表收口（`reports/u4-aw86927-sramwindow-20261027.md`）· U3 = **删除**（`reports/u3-rpmhpd-presync-floor-20261027.md`，D13）· U8 = 现不编译 ⇒ 未决 **9 → 4**（剩 U1/U2/U5 DSI bonded 一族、U7 双控触觉上机） |
| **M1 新树未上机对照** | `build/m1-upstream/clean-tree-73` 只有「构建通过 + 逐域 argument」，没有等机功能对照记录 |
| **基线代次** | 全部系列基线仍是 7.3-rc7（`24a19b953`）；Konrad 已要求 A2 换 `linux-next/master`，其余系列未跟进 |
| **封存件无人推进** | M3-3 / M3-4 / M3-6 / M5 四件都停在「备料完成」，需要一次投递裁决 |
