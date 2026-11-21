# 主线上游化审计与评估（四态总账 + 72h 投递顺序）2026-11-22

> 性质：**主机侧只读审计**。零设备、零发信、零 fork/push、零 `git commit`。所有外部命令带 `timeout -k`。
> 输入：`TASKS/README.md` §7（M 系列，行内即权威）· `patches/upstream/*`（README/SENT.md/GATES）· `reports/upstream-queue-prep-20261121.md` · `reports/upstream-status-20261113.md` · `reports/upstream-recheck-20261120.md` · `reports/mail-inbox-20261121.md` · `reports/distro-upstream-feasibility-20261121.md`。
> **本轮的增量 = 现查（2026-11-22）**：① `wl2868c` 进树**独立复核**（不是抄 11-21 结论）；② 8 个在飞系列的 18 枚补丁按 series 直查 `state`/`commit_ref`，其中 9 个代表 id 逐条查 `comments`；③ 发现 **dwc3 v10 投后 12 min 就吃 sashiko 1×Medium + 3 条（1M/2L）**，这是 72h 内唯一「新出现且必须处置」的意见；④ 把「可投未投」与「结构上不可投」用文件级判据分开。

---

## §结论（数字先行）

| 项 | 数字 | 判据 |
|---|---|---|
| **已进树** | **1 个系列 / 2 枚 commit**（`wl2868c v12` → `regulator.git for-7.5`） | §1.1：cgit `log/?h=for-7.5` 现拉，见 `0216753490ff` merge + `84e67d2ee13f`/`602f57223457` |
| **SENT 待回** | **8 个系列 / 18 枚补丁**（dwc3 v10 3 枚、elden DTS v7 1、dsi-phy v2 1、dpu gamma v2 1、haptics v2 6、fastrpc v3 1、mdss v5 3、pstore v1 2） | §1.2；patchwork 直查全部 `state=new`、`commit_ref=None` |
| **可投未投** | **4 件**（elden DTS v8 = 2 枚；haptics v3 = 6 枚；camss CSIPHY 2.4.0 v2 = 2 枚；dwc3 v10 的板件 0004 = 1 枚 hold） | §1.3 |
| **不可投 / 已放弃** | **6 类**（M9 gic-its、Q28 dispcc RFC、M6 b5-p4、camss 自建 9 枚串、M3-3 音频、M3-4 panel、M5 dm-default-key、gunyah） | §1.4 |
| **在飞零人类回复** | **7/8 系列**（8 个在飞系列里只有 `dwc3` 收到人回（Rob ×2，11-18）；其余 7 个只有 sashiko 或全静默） | `reports/mail-inbox-20261121.md` §2；本轮 patchwork comments 直查 |
| **本轮新意见** | **2 条 Medium + 2 条 Low**（dwc3 v10：`dwc3_drd_exit()` 过早 deselect；binding 无条件 `hs-port`/schema 风格/`dr_mode` 覆盖默认） | §1.2 dwc3 行；patchwork `15007993`/`15007992` comments（2026-11-21T02:33/02:40Z） |
| **1–2 轮内可落地** | **3 件**：elden DTS v8（纯增量、门已全绿）、dwc3 v11（答 sashiko 4 条，工作量 < 1 天）、haptics v3（已备料，只需放行） | §2 |
| **必须设备实测才能投** | **2 件**：camss CSIPHY v2（Bryan 明确要 on-list 基线 + 我们无出流实测）、dwc3 板件 0004 + G7（运行期 mux/双口枚举） | §2 |
| **该放弃** | **4 类**：M9 gic-its（Marc Zyngier 逐条否）、Q28 dispcc RFC（自承应撤）、M6 b5-p4（冻结草案）、gunyah（上游 2023 起无进展） | §2 |

---

## §1 四态总账

### 口径（先说清哪些是「内容级」哪些是「间接」）

- **`state=new` / `commit_ref=None` 不构成「未合并」证据**——本项目已有实发反例：`wl2868c v12` 的 arm-msm 副本今天仍 `new`，而它已在 `for-7.5`（`TASKS/README.md` §7 头 2026-11-21 条）。判合并只看**维护者自己的树**或 linux-next 内容级。
- 反过来，`state=superseded` 是可靠的（说明有更新代次被摄取）。
- 本轮现查命令（全部 rc=0）：

```bash
# patchwork：逐系列（series id 见各行）
timeout -k 5 40 curl -sS --noproxy '*' "https://patchwork.kernel.org/api/1.2/patches/?series=<ID>&per_page=50"
timeout -k 5 40 curl -sS --noproxy '*' "https://patchwork.kernel.org/api/1.2/patches/<patch_id>/comments/"
# 维护者树（内容级）：cgit log 页对 curl 可用（plain 取单文件在本轮 404，改用 log 页抽 commit 标题）
timeout -k 5 40 curl -sS --noproxy '*' "https://git.kernel.org/pub/scm/linux/kernel/git/broonie/regulator.git/log/?h=for-7.5"
```

### 1.1 已进树（1）

| 系列 | 代次 | 树内证据（本轮现查） | 后续责任 |
|---|---|---|---|
| `regulator: willsemi,wl2868c`（M3/M4） | **v12**（`14991614/14991615`，arm-msm，仍 `new`） | `broonie/regulator.git` **`for-7.5`** log 页（2026-11-22 现拉）逐行命中：`0216753490ff regulator: add the Will Semiconductor WL2868C camera PMIC`（merge）+ `84e67d2ee13f`（binding）+ `602f57223457`（driver）；Mark Brown 11-17 `b4-ty` 通知原文在 `reports/mail-inbox-20261121.md` §2.1 H2 | **只剩文档回填**；今后改动只能发增量补丁 + CC 列表（H2 原话）。板件/fastrpc 引用该 binding 时按「已在树」处理 |

> 工具坑（本轮实测）：`…/plain/drivers/regulator/wl2868c.c?h=for-7.5` 返回 **404**（HTML 错误页 5458 B），而 `log/?h=for-7.5` 返回 200 且正文含 `wl2868c` ⇒ **判「文件是否在树」不要用 cgit plain 单文件端点**，用 log 页 + 提交 id。

### 1.2 SENT 待回（8 系列 / 18 枚）

| 系列 | 最新代 / patchwork id | 门禁状态（末次实测） | 卡点（谁在等什么） | 证据指针 |
|---|---|---|---|---|
| **dwc3 双连接器**（M3） | **v10**：`15007992`(1/3) `15007993`(3/3) `15007994`(2/3)，linux-usb `1217901` + arm-msm `1217902` 两副本，均 `new` | G0–G6 全绿（`git am` 3/3、checkpatch 0E/0W/0C×3、`W=1` rc=0/0 warn/22 `.o`、`dt_binding_check` rc=0、`dtbs_check` 4/4 `DTC [C]` 新增 0、负样例 4 类全拒）；**G7 上机未做**（cover 明写 "No runtime testing is claimed"） | **新：sashiko 11-21T02:33Z 1×Medium**（`dwc3_drd_exit()` 里 `dwc3_role_mux_deselect()` 放在 role teardown **之前** ⇒ idle-state mux 会在 host/gadget 还在跑时把 HS 线切走；对照 `__dwc3_set_mode()` 的顺序是先 exit 再 deselect）+ **02:40Z 1M/2L**（binding：`hs-port` 无条件 `$ref` 破坏非 mux 的 `port@0`；schema 风格未吸收维护者意见；`dr_mode` required 覆盖 `usb-drd.yaml` 默认）。人类维度：Rob 两封（11-18）已在 v10 逐条落实，**现在只欠把 sashiko 4 条判真伪** | `patches/upstream/dwc3-v10-20261120/{SENT.md,GATES-20261121.md}`；patchwork comments 本轮直查 |
| **elden 板 DTS**（M3-DTS） | **v7** 单提交 `14991580`，`new`，**0 条 comment** | 上一版门：`dtbs_check` 3/3 0 诊断（v8 备料里复跑）；残留 3 条 checkpatch W（`MAINTAINERS`/`lenovo,elden` 未文档化/`willsemi,wl2868c` 未文档化——后者**已随 wl2868c 进树消解**） | 无人回。sashiko 11-17 的 4 条里，`willsemi` 那条已自解；**剩 `lenovo,elden` 缺 `arm/qcom.yaml` 条目 + `&i2c10` 字母序**，v8 备料已含 | `patches/upstream/board-dts-single-20261113-sent-20261117/`、`elden-dts-v8-prep-20261121/README.md` §0 |
| **dsi/phy PLL_SYSTEM_MUXES**（M6） | **v2** `14991582`，`new`，**0 人回 0 bot** | `git am` rc=0、checkpatch 0 error、代码与在机 vk192 逐字相同 | 纯静默；可能被 dsi 维护者队列埋没 | `reports/upstream-status-20261113.md` §1b；`reports/mail-inbox-20261121.md` §3 |
| **dpu gamma LUT**（M2） | **v2** `14991581`，`new`，**0 回** | 备料门绿（v2 目录） | 纯静默 | 同上 |
| **haptics aw86937**（M3） | **v2** 6 枚 `14991595`–`14991600`，`new` | `git am` 7/7、checkpatch 0E、bindings 有 Krzysztof Acked-by | sashiko 6/6 的 High（`aw86927_close()`/unbind 竞态）**已在本地 v3 修掉但未发** | `patches/upstream/haptics-v3-20261118/README.md` §1 |
| **fastrpc ADSP non-secure**（M10） | **v3** `14971025`，`new`，0 comment | 单行补丁，上下文在 7.4-rc3 仍逐行一致；驱动仍读该属性（`drivers/misc/fastrpc.c:2754`） | **静默 11 天**；Konrad 11-09 两条要求 v3 已落实 ⇒ 只欠一次礼貌 ping | `reports/upstream-queue-prep-20261121.md` §2 |
| **mdss 块复位**（M8） | **v5** 3 枚：`14980387`(1/3 handled-elsewhere) `14980388`(2/3 handled-elsewhere) `14980389`(3/3 new) | 3 枚形状 `dtbs_check` 绿；证据帖 11-17 已发（23 发 POR，Fisher p=0.003） | sashiko 11-13 **3 份报告未逐条判别**（我方 11-17 只补了 cover 证据）；两枚形状上机未做、`0xa000` 单变量未做 | `reports/upstream-status-20261113.md` §2；`mdss-v5-q28-evidence-20261116/README.md` |
| **pstore/ram initrd 重叠**（UEFI 线） | v1 2 枚，11-16 投出 | 门禁：apply 2/2、checkpatch 0E、QEMU A/B、真机 UEFI/GRUB 守卫**已生效** | patchwork **查不到**（`q=initrd_phys_range` 在 lkml/arm-msm 均 0 命中）⇒ 归档侧状态**未验证**；无人回 | `patches/upstream/pstore-ram-initrd-overlap-20261116/README.md`（状态段） |

### 1.3 可投未投（4 件）

| 件 | 目录 | 为什么算「可投」 | 缺什么才算「能投」 | 代价 |
|---|---|---|---|---|
| **elden DTS v8（2 枚）** = `qcom.yaml` +1 行 + v7 原文 | `patches/upstream/elden-dts-v8-prep-20261121/`（`0000`/`0001`） | `git am` 4/4 干净；新增两枚 checkpatch **0E/0W/0C**；`dtbs_check` 3/3 `DTC [C]` 0 诊断；负样例 5/8 被拒 | 只缺**用户放行发信**（把 v8 挂 v7 线程下） | 1 封邮件，30 min |
| **elden DTS v9（USB 部分，3 枚：dtsi label + 板件 mux + connector）** | 同上目录 `0002` + `dwc3-v10-20261120/elden-dts/` | 带上 v10 binding 后 `dtbs_check` 0 诊断（dtb md5 `2d2d9266…`） | **依赖 dwc3 v10 1/3 binding 进树**（否则 8 条诊断、5 条 mux 相关） | 等 v10，无额外工作 |
| **haptics v3（6 枚）** | `patches/upstream/haptics-v3-20261118/` | 已逐条答 sashiko High+Low；`0001`–`0005` 与 v2 逐字节相同 | 放行 | 1 封邮件 |
| **camss CSIPHY 2.4.0 v2（2 枚）** | `patches/upstream/camss-csiphy-24-v2-20261117/` | 6 道**静态**门全绿（apply/checkpatch/W=1/dt_binding_check/表对账 13/13、103/103） | ⛔ **Bryan 要求「先基于 on-list v25/v7」+ 我方零出流实测**；README 自己写明「不得写 Tested-by」 | 需设备 + 一段 30 fps 出流判据 |

### 1.4 不可投 / 已放弃（6 类，写清判据免得再被重提）

| 项 | 判据 |
|---|---|
| **M9 gic-v3-its 认领继承 LPI 表** | Marc Zyngier 2026-10-24 逐条否（「*nothing* works at all」「Either it works always, or it doesn't at all」）⇒ 我方已决定撤回（`TASKS` §7 M9-收口） |
| **Q28 dispcc clk RFC** | 备料结论就是「建议撤回 RFC 线程、不再单独立 v2」（`patches/upstream/dispcc-reset-v2-20261113/README.md:3`）；现役 M8 已改为 mdss 块复位 3 枚 |
| **M6 b5-p4（DSI per-SoC cfg / command DMA）** | `patches/upstream/m6-b5-p4-20261026/README.md:3`「DRAFT，冻结不发」；`m6-b5-v2-20261102`「未发送」 |
| **camss 自建 9 枚串** | 已被 Qualcomm v6 路线取代（`m4-camss-series-20261028-v2/README.md:3` ⛔）；我方只保留「CSIPHY 2.4.0 lane 表 delta」这一条缝 |
| **M3-3 音频（aw88461）/ M3-4 panel** | Q2 裁定并入 aw88395 家族、H1 `to_primary_dsi` 阻断 ⇒ 目录状态即「备料封存」 |
| **M5 dm-default-key / gunyah / ath12k-PEACH / hci_qca-PERI** | M5 = 上游有 `dm-inlinecrypt` 且三份 `.config` 零命中（死代码）；gunyah 主线停在 2023-03 v11；ath12k/hci_qca 上游 0 命中（只有 WCN7850）⇒ 维持自维护，不进上游 |

---

## §2 分档评估：1–2 轮可落地 / 需设备 / 该放弃

### 2.1 1–2 轮内可落地（主机侧即可闭环）

| 件 | 为什么能快 | 门是否已绿 | 风险 |
|---|---|---|---|
| **dwc3 v11**（答 sashiko 4 条） | 4 条里 3 条是 binding 措辞/局限，1 条是 `dwc3_drd_exit()` 顺序（把 `dwc3_role_mux_deselect()` 挪到 `switch (current_dr_role)` teardown 之后，与 `__dwc3_set_mode()` 对齐） | G0–G6 已在 v10 全绿，只需重跑同样 6 条 | 若把 1/3 的 `port@0` 改成条件 `$ref`，需重跑 `dt_binding_check` + 4 份 `dtbs_check`（半小时量级） |
| **elden DTS v8**（2 枚） | 纯增量 + 已备料 | `git am` 4/4、checkpatch 0E/0W/0C、dtbs_check 0 诊断 | 低；唯一不确定是维护者是否接受与 v7 同批挂线程 |
| **haptics v3** | 只需放行；High 修复已写 | v3 目录自述门禁 | 中：High 是竞态修复，理想需一次 bind/unbind 冒烟（主机侧可用 QEMU? 不可——这是 I2C 触觉器件，只能静态） |

### 2.2 必须设备实测

| 件 | 要验什么 | 判据（可直接抄 `upstream-queue-prep` §3.3） |
|---|---|---|
| **dwc3 板件 0004 + G7** | mux 真切换、两口各自枚举、角色切换不走错口 | `/sys/class/usb_role/` 出现 `…-port0`/`-port1`；`echo host > role` 后该口枚举；换口时 `gpio-29` 单次跳变无中间态；`/sys/kernel/debug/dwc3.*/mode` 写失败 = `-EBUSY` |
| **camss CSIPHY v2** | 一次真实出流（`v4l2-ctl --stream-mmap`，≥30 fps）+ `dmesg` 无 CSID 错 | 现在**零**实测 ⇒ 不满足 Bryan 的收敛前提，投了也会被打回 |
| **mdss v5** | 两枚形状的上机验证 + `0xa000` 单变量 | `reports/mdss-int2-evidence-20261113.md` §2.3 的未证项 |
| **pstore v1** | （已做过真机 UEFI/GRUB 守卫；只欠归档核对） | lore/patchwork 按 MID 复核 |

### 2.3 该放弃 / 降级

见 §1.4。补充一条**降级**：`dispcc-sm8750` clk RFC 若仍想保留存在感，正确动作是**在 M8 线程里一句话说明「clk 侧另案」**，不发 v2。

---

## §3 下一个 72h 投递顺序（带理由与证据指针）

> 前提：**发信仍按系列逐次由用户批准**（`TASKS` §7 投递口径）。下面是「批准后的执行顺序」，不是已批准的投递。

| 顺位 | 动作 | 理由（为什么排这里） | 证据指针 | 代价 |
|---|---|---|---|---|
| **1（T+0，最高优先）** | **dwc3 v11**：答 sashiko 1×Medium（`dwc3_drd_exit()` 顺序）+ binding 1M/2L，`--in-reply-to` 挂 v10 cover | 唯一「**新出现、且维护者在等**」的意见；同一线程内 v11 成本最低（改 3 处 + 重跑 6 门）。拖久了 v10 会被 patchwork 判 stale | §1.2 dwc3 行；v10 门禁 `GATES-20261121.md` | 0.5–1 天主机 |
| **2（T+0 并行）** | **elden DTS v8（2 枚）**挂 v7 线程 | 消掉 v7 的两条实债（`arm/qcom.yaml` 条目 + 字母序），且**零依赖**；同时给 dwc3 v9 的「板件 hold」铺路 | `elden-dts-v8-prep-20261121/README.md` §0/§1.2 | 30 min |
| **3（T+1）** | **fastrpc v3 礼貌 ping**（不催结论，只问「v3 是否可进 7.5」；To 加已进线程的 Ekansh/Dmitry/Srini） | 静默 11 天、技术欠账 0；这是**唯一「零工作量、可能直接收单」**的动作 | `reports/upstream-queue-prep-20261121.md` §2.4 | 15 min |
| **4（T+1）** | **haptics v3（6 枚）** | 唯一的 High 已修，v2 已被 bot 打过；v3 不发则 v2 永远停在 `new` | `haptics-v3-20261118/README.md` §1 | 1 封 |
| **5（T+2）** | **mdss v5 的 sashiko 三份逐条判别**（真/假/已覆盖）→ 只对「真」项在**同线程**回一封证据短帖，不重发系列 | 三份报告积压 9 天；判别成本低（都是可静态核对的断言），且不做会让 3/3 的 `new` 更难推进 | `reports/mail-inbox-20261121.md` §2.2 备注、§5 | 0.5 天 |
| **6（T+2，条件触发）** | **elden DTS v9（USB 部）**：仅当 v11 的 1/3 binding 已进树/被接受 | 依赖单向：不带 v10 binding 时板件会被打 8 条诊断（5 条 mux 相关） | `elden-dts-v8-prep-20261121/README.md` §1.2 | 30 min |
| **7（T+3，需用户/设备）** | **dwc3 G7 上机**（造 vk193 = 7.4-rc3 + v10 + v8 DTS，`fastboot boot` 零写盘） | 唯一能把「No runtime testing is claimed」变成实测的路径；但它**不是发信阻塞项**（G7 可以晚于 v11） | `reports/upstream-queue-prep-20261121.md` §3.1–§3.3 | 半日设备窗口 + 全量模块重编（`build/daily` 已不在 ⇒ 只能 7.4 全量） |
| **暂不排** | camss CSIPHY v2（需出流实测）、pstore 归档复核（先查 patchwork 归属）、dsi-phy/gamma（纯静默，不催） | 前者缺硬前提，后两者催了也没有信息增量 | §2.2 | — |

**为什么不按「系列大小」排**：本轮唯一改变排序的事实是 **dwc3 v10 已被机器评审点名 2 条 Medium**（§1.2）。在维护者眼里，一个「刚发就被指出顺序 bug」的系列，**回得快**比「再发一个新系列」更能保住 reviewer 注意力；而 elden DTS v8/fastrpc/haptics 都是「已备料、零新增风险」的补位件。

---

## §4 与文档的差异（本轮发现，供回填 SSOT）

| # | 文档现状 | 本轮实测 | 建议 |
|---|---|---|---|
| 1 | `TASKS` §7 M10 行写「只欠一次礼貌 ping」（11-21） | 仍成立（v3 至今 0 comment，本轮直查） | 无需改，进 §3 顺位 3 |
| 2 | `reports/mail-inbox-20261121.md` 未记 dwc3 v10 的 sashiko 4 条 | **新**：11-21T02:33/02:40Z 两条 comment（1M + 1M/2L） | 收尾时回填到 §7 dwc3 行 |
| 3 | `patches/upstream/README.md` §3 仍写「⏸ 投递冻结（2026-10-13）」 | 事实早已解冻（11-17 整批 6 系列、11-21 v10） | 该段落已过时，建议标「作废（口径以 `TASKS` §7 为准）」 |
| 4 | `patches/upstream/README.md` §4 现状索引只到 M3-4 | 索引表停在 2026-10-13 代次 | 建议改为指向 `reports/mainline-upstream-audit-20261122.md` |

---

## §下一步可执行清单（带代价/判据）

| # | 动作 | 代价 | 判据 |
|---|---|---|---|
| 1 | 写 dwc3 v11：`dwc3_role_mux_deselect()` 移到 `switch (current_dr_role)` teardown 之后；binding 的 `port@0` `$ref` 改条件；`dr_mode` 不再 required；`patternProperties` 保留 | 0.5–1 天主机 | 6 门重跑：`git am` 3/3、checkpatch 0E/0W/0C×3、`W=1` 0 warn、`dt_binding_check` rc=0、`dtbs_check` 4/4 0 新增、负样例仍全拒 |
| 2 | 发 v11（需用户放行） | 1 封邮件 | patchwork 出现 v11 且 v10 转 superseded；lore `linux-usb` 线程页含 v11 |
| 3 | 发 elden DTS v8（2 枚，挂 v7 线程） | 30 min + 放行 | patchwork `14991580` 转 superseded，新 id 出现；`qcom.yaml` 条目在 diff 里 |
| 4 | 发 fastrpc v3 ping | 15 min + 放行 | 线程新增 1 条我方消息；`reports/mail-inbox-*.md` 下次核查能看到 |
| 5 | 发 haptics v3 | 1 封 + 放行 | 7/7 归档 |
| 6 | mdss v5 三份 sashiko 判别表（真/假/已覆盖）落 `reports/mdss-sashiko-triage-20261122.md` | 0.5 天主机 | 每条都有「代码/文档引用 + 判定」，不含猜测 |
| 7 | （条件）v9 板件 USB 部：先确认 v11 1/3 状态 | 30 min | `dtbs_check` 带 binding 0 诊断（已知 dtb md5 `2d2d9266…`） |
| 8 | （需设备）G7：`build/elden-tree`(7.4-rc3) + v10/v11 + v8 → `out/boot-elden-vk193.img` → `fastboot boot` → T1–T8 | 半日 + 全量模块 | `/sys/class/usb_role/` 两个 port、`echo host` 后枚举、换口单次跳变 |
| 9 | 回填 SSOT：§4 表四条 | 20 min | `TASKS` §7 dwc3 行含 sashiko 4 条；`patches/upstream/README.md` 冻结段标作废 |

**不做**：camss CSIPHY v2 投递（缺出流实测）、Q28 dispcc v2、M9 任何形式重提、6.18 LTS 重基。
