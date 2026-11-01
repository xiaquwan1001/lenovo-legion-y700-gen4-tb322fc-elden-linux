# 文档一致性审计 + 邮件分诊（2026-11-01，只读 lane）

> 性质：只读 + 起草。未改任何 SSOT 文档、未发任何邮件、未碰设备、未 commit。
> 输入 = INDEX.md、TASKS/README.md（§0/§4/§5 的 10-31/11-01 各块）、最新 5 份 UEFI 报告、DEVICE/README.md §1.1、PITFALLS/README.md、两份自检脚本输出、`read-mail-ustc.py --days 4 --limit 60`（INBOX/Junk/Sent）、`gh api repos/sunflower2333/mu_wide_platforms/issues/12`。

---

## §0 结论先行

| 维度 | 数字 |
|---|---|
| 文档矛盾/过期条目（§1–§2） | **11 条**（P0 = 4，P1 = 7） |
| 必须修的 P0 | **4 条**：① TASKS §5 11-01 纠正块「7/7 载荷被执行」已被当日 DDR 黑匣子轮二次作废；② TASKS §5 11-01「下轮顺序」三条全部过时；③ DEVICE §1.1 首条（10-31 19:59 vk183「全程零写盘」）与 11-01 三次重打包写盘（bb1/bb3/备份）矛盾；④ TASKS §0 运维行「2026-10-29 在机 = vk181」过期 |
| 自检脚本 | `check-doc-assets.sh` PASS（checked=519 missing=0）；`check-doctor.sh` **FAIL=1 / WARN=6**（归因见 §3） |
| 邮件（近 4 天窗口） | INBOX/Junk/Sent 拉取正常；**相关新来信/事件 4 条，需回 3 条**（Dmitry mdss v2 两条意见 = 必须 v3、qualcomm 退信 = 核实、issue #12 新评论 = 建议简回） |
| issue #12 | state = **open**，7 条评论，最新 = sunflower2333 2026-10-29（「别用劣质 token 瞎猜；调试用 UEFI USB ACM Gadget」） |

---

## §1 任务 A1：文档矛盾清单（file:line + 建议 diff）

### P0（必须修）

**P0-1 ｜ TASKS/README.md:312 「干净 header 下 7/7 载荷被执行」——已被同日更晚的 DDR 黑匣子轮作废**
11-01 早间的 cleanheader 轮把 `usb_read failed` + USB 消失当「载荷被执行」；同日 15:20–15:45（`reports/uefi-ddr-blackbox-20261101.md` §7/§8，`PITFALLS #481`）用 50 ms USB 计时证明该口径下载荷**从未被执行**（自旋臂与对照臂黑屏间隙都是 ~20 s），并新增第三类终态「挂 logo」。
建议 diff（不执行）：
```diff
- **干净 header 下 7/7 载荷被执行**（纯 Mu / dodge UFSDxe / PrePi 红条插桩 / A2 原件 / A2 重建 / 自写 shim / 入口改 `b .`）
- ⇒ 10-30/31 的「厂商 UFSDxe × cachefix shim」「E1/X1/X2 换件」「早期写 FB 致命」全部**作废（不是测到变量）**。
+ **干净 header 下 7/7 发被 ABL 接手（`usb_read failed`）**——⚠ 同日晚间已被 `reports/uefi-ddr-blackbox-20261101.md` §7 + `PITFALLS #481` 二次作废：
+   「接手」≠ 载荷执行；判执行必须有独立通道（DDR 标记/UART/EUD/屏上输出）。10-30/31 的「厂商 UFSDxe × cachefix shim」
+   「E1/X1/X2 换件」「早期写 FB 致命」全部作废（不是测到变量），且 header 差分路线整体放弃（接受与否非 header 唯一函数）。
```
同时该块的「判据污染」段（:306–311）与「ABL 跳转后 ~1–2 s 整机掉电」（:313 附近）也应加同源勘误：1–2 s 掉电发生在 header 污染期的目视口径，现行口径 = `fastboot boot` 后 ~20 s 复位回落（#481）。

**P0-2 ｜ TASKS/README.md:316–319 「下轮顺序」三条全部过时**
① R2-repack 补目视——已被 #481 推翻（载荷未执行，红条永远不会出现）；② PrePi pet/disable wdog——同样失去前提；③ 旧 header 接受/拒绝规则——被 §6.1 非确定性（同一镜像三次结果不同、与另一槽是否 bootable 相关）判死，「不能再用 header 差分去追」。
建议 diff：
```diff
- **下轮顺序**（用户 2026-11-01 决定…）：
-   ① R2-repack 补一发专门目视/手机录像定 J1；② 若仍无红条 ⇒ PrePi 最早期 pet/disable boot watchdog；
-   ③ 旧 header 的接受/拒绝规则逐字段回改夹死。
+ **下轮顺序（已被 `reports/uefi-ddr-blackbox-20261101.md` §6.4/§7/§10 取代）**：
+   ① `fastboot boot` 判定只能统计式（同镜像多发、只取真 HANDOFF 发次）；② 保持 slot a unbootable 以免回落 Android 覆盖窗口；
+   ③ 改走「槽位正常启动」路径（P2 合体 BOOT 最小形态：ddrmarks 载荷签进 boot_b，走 ABL 正常 boot 路径）。
```

**P0-3 ｜ DEVICE/README.md:27–32 §1.1 首条（10-31 19:59「当前在机状态，唯一权威」）与 11-01 写盘事实矛盾**
该条写「仍是 `vk183-fastrpc`（`boot_b` sha `aedae5f1…`，**全程零写盘**）」。但 `reports/uefi-ddr-blackbox-20261101.md` §0 记录 11-01 **`boot_b` 三次重打包写盘**（bb1、bb3、原份备份 `boot_b-device-backup-20261101.img`，sha `aedae5f1…` 逐字节等于原在机件），预期恢复后在机 = **bb3（vk183 + `memmap` 保留窗）**；且 §6.3 记录 14:07 后设备**无 fastboot/无 ssh**，需用户物理长按断电恢复（§6.2 已把 slot a 标 unbootable）。
建议：在 §1.1 顶部**新增一条**（不改旧条）：
```diff
+ - ★**2026-11-01（当前在机状态，唯一权威）** —— `boot_b` 已于 11-01 三次重打包写盘（bb1→bb3；备份
+   `bootslot-b/boot_b-device-backup-20261101.img` = 原 `aedae5f1…`）；当前件 = **bb3（vk183 载荷 + `memmap` DDR 保留窗）**。
+   ⚠ 14:07 撞 `PITFALLS #368`（USB 全不枚举），**需用户物理长按电源 ~10 s 断电**恢复；恢复后先 `qbootctl -m a` 把 Android 槽
+   恢复 bootable。slot a 现被标 unbootable（`reports/artifacts/uefi-ddr-20261101/slot-backup/misc.bin` 有备份）。
```

**P0-4 ｜ TASKS/README.md:21（§0 运维/资产行）「2026-10-29 在机状态：`boot_b` = vk181-daily」过期**
已被 10-30 vk183、10-31 转正、11-01 bb3 三轮取代；该行自称「在机状态」却停在 10-29。建议在该行开头加一句指针：「★在机状态以 `DEVICE/README.md` §1.1 首条为准（本行时间为 2026-10-29 快照）」，或整行降级为「历史快照」。

### P1（应修，含「已知核对点」逐项）

**P1-1 ｜ ①「交棒 = 载荷被执行」残留**——`reports/uefi-cleanheader-reframe-20261101.md` 内多处：
- :11 「交棒（= 载荷被 ABL 接受并开始启动）」、:41 表内「载荷被执行」、:89 「R2-repack 已证载荷被执行」、:18/:88 「7/7 接受/被接受」。报告本身已被 §7 推翻，建议**不动正文**，在报告顶部加一行勘误框（保持「允许带日期的最小修订」纪律）：
```diff
+ > ⚠ **2026-11-01 勘误（见 reports/uefi-ddr-blackbox-20261101.md §7）**：本报告的「HANDOFF=载荷被执行」判据已被 USB 间隙计时
+ > 对照推翻——ABL 接手 ≠ 载荷执行；本报告全部「执行」字样读作「被 ABL 接手并校验」。
```

**P1-2 ｜ ②「交棒条件 = 厂商 UFSDxe × cachefix shim」残留**——`TASKS/README.md:381`（小节标题「交棒需『厂商 UFSDxe × cachefix shim 基座』」）与 :384–390 结论块、以及 10-31 晚控制组块 :334–346（「交棒条件可复现」「两个独立故障」）。cleanheader 轮 :313 已宣布作废，但这些 10-31 块本身没有回链勘误。建议各块标题后加「（⚠ 2026-11-01 已被 header 污染纠正块 + #481 整体作废）」一句。

**P1-3 ｜ ③「早期写 FB 致命」当前口径不一致**——三处三种口径：
- `PITFALLS #477`（:182）仍写「**上机两次都致命**（…均不交棒）」= 陈述既成事实；
- `uefi-observability-pivot-20261101.md` §4 表写「保留为**未复现的候选**：那两发处于 header 污染期，变量未真正测到」；
- `TASKS/README.md:328`（10-31 待办 2）已改判「前提被否证（R1/R2 从未被执行）」。
建议把 #477 索引行末尾追加：「**2026-11-01 降级**：R1/R2 两发载荷从未被执行（#481），『写 FB 致命』降级为未复现候选；静态推理纪律不变」。正文 session 文件 141 同步一句。

**P1-4 ｜ ④ fastboot boot 三态口径已正确落 #481**（`PITFALLS/README.md:186`），但 `PITFALLS #479`（:184）末句「只有 `usb_read failed` + USB 消失才是『ABL 开始启动』」与 #481 的「`usb_read failed` 只是 ABL 接手，不判执行/终态」存在层级冲突。建议 #479 加一句：「**2026-11-01 晚升级**：`usb_read failed` 仅 = ABL 接手，终态有三类（拒/复位回落/挂 logo，见 #481）」。另 §6.1 的「同一干净 header 镜像连打三次结果不同（含 `Invalid Parameter` 拒绝）」建议并入 #479 或新条（见 §2）。

**P1-5 ｜ `reports/uefi-observability-pivot-20261101.md` §0-4/§1.2/§3-P1 的「1–2 s 掉电 = wdog」链路被 #481 削弱**：该报告在 §4 已把「早期写 FB」降级，但其 §0-2/§0-4「`b .` 自旋臂 1–2 s 复位、只有看门狗能复位死循环」的观察本身发生在「载荷未执行」的世界里（#481），wdog 复位发生在 ABL 侧（ABL 日志 `HW Wdog Setting from PCD : Enabled` 仍成立）。建议顶部加勘误：「§0-4/§1.2 中『载荷侧 1–2 s 窗口』的量测被 #481 重归因：复位发生在 ABL/槽位路径，不是我们的载荷；ABL 侧 wdog Enabled 的文字证据仍然有效」。注意该报告 §0-1（logfs 10 段环形）、§2.2（UFSDxe 3 变体）、§3-P0/P2（DDR 黑匣子、合体 BOOT）均与 ddr-blackbox 轮一致，无需动。

**P1-6 ｜ `uefi-vis-control-20261031.md`、`uefi-swap-x1x2-20261031.md` 整体是已被作废结论的正文**（2×2 判读 §2.1、§1「两个独立故障」）：按「带日期最小修订」纪律，各加顶部勘误框指向 cleanheader + #481 即可，不改结论段。

**P1-7 ｜ INDEX.md:18 拓展行**「UEFI 路线 A 搁置，复启条件见 §4 N1」——方向没错，但当前 UEFI 线实际处于「11-01 恢复推进 + 判据两次改写」状态，且复启条件的载体（G1-29/Q25）描述停在 10-29 反汇编定论。属轻度过期，建议改为「UEFI 线 2026-11-01 恢复推进（判据纠正见 §5 2026-11-01 块）」，指向 TASKS §5。

---

## §2 任务 A3：PITFALLS #477/#479/#480/#481 核对与缺条

| 条 | 与最新实测是否一致 | 处置 |
|---|---|---|
| #477（早期写 FB） | ❌ 部分过期：「上机两次都致命」陈述的两发载荷从未被执行（#481） | 追加降级注（P1-3 的 diff） |
| #479（header 污染判据） | ⚠ 半过期：「干净 header 即可」成立一半——干净 header 下接受与否**非确定性**（ddr-blackbox §6.1 同镜像 r1 HANDOFF / r2 NOJUMP / r3/r4 `Invalid Parameter`），且 `usb_read failed` 仅 = ABL 接手 | 追加升级注（P1-4） |
| #480（1–2 s 掉电） | ❌ 头部结论「掉电是系统层固定行为…异类载荷观测窗口只有 1–2 s」建立在「载荷被执行」前提上，该前提已倒 | 建议追加：「2026-11-01 晚：USB 间隙对照显示复位发生在 ABL/槽位路径（~20 s 后 Android gadget 重现），1–2 s 掉电从未发生在我们的载荷上；wdog 证据仍指 ABL 侧」 |
| #481（三态） | ✅ 与 ddr-blackbox §7/§8 一致，是现行权威 | 不动 |

**建议新增 #482**（缺的正是「fastboot boot 判定非确定性」这条）：
```
| 146 | **#482** `fastboot boot` 的接受/拒绝**非确定性**：同一份未改动镜像（sha `423188a0…`）连发出现 HANDOFF / NOJUMP(~10.1s) / `Failed to load/authenticate boot image: Invalid Parameter` 三种结果；且拒绝与「另一槽是否 bootable」相关（slot a unbootable 后连拒）。⇒ ① 不能用 header 逐字段差分去追接受规则；② 判据必须是「同镜像重复 N 发、统计接受率」，且每发先以 `usb_read failed` + USB 消失确认本次真的被接手；③ 82 MB 级镜像走 `fastboot boot` 会让 ABL 挂死在 logo（#481 第三态），该路径不适合承载大内核+ramdisk | [146-fastboot-boot判定非确定性与挂logo.md](sessions/146-....md) |
```
（可选 #483：DRAM 跨 PS_HOLD 复位不保真、判据必须单调编码 + `oem-vm` 受保护 carveout 写入疑触发复位——见 ddr-blackbox §2/§5；若下轮继续黑匣子线，建议落条。）

---

## §3 任务 A4：自检脚本结果（只记录，不修）

- `scripts/check-doc-assets.sh`：**PASS**（`checked=519 missing=0 skipped=13 files=5`）。无需归因。
- `scripts/check-doctor.sh`：**FAIL=1 / WARN=6**
  - FAIL 1：§5d「内核身份表已过期 → 跑 `scripts/vk-identity.py > versions/vk-kernel-identity.tsv` 并重提交」。归因：11-01 UEFI 轮的写盘（bb1/bb3）改变了 boot_b，未重生成身份表（属 SSOT 更新，留给 SSOT lane）。
  - WARN 6：① 历史镜像 vk183-fastrpc 无 manifest（registry 前历史留白，已知）；② 62 个账本已登记例外（`uts_dup`/`num_ne_tag`，均有审查理由，见 `vk-ledger-known-issues.tsv`）；③ `boot-elden.img` 无版本号构建拷贝 1 个；④ 疑似死脚本 `uefi-ddr-trial.sh`（11-01 ddr 轮改用 `blackbox.py` + `uefi-boot-trial.sh`，核实后可标 legacy）；⑤ `reports/asset-inventory-20261101.md` 无人引用；⑥ `HISTORY/days` 落后（需跑 `gen-history.sh`，生成物，不属本 lane）。

---

## §4 任务 B1：邮件分诊（只读，近 4 天窗口，截至 11-01 晚）

> 拉取：`read-mail-ustc.py --days 4 --limit 60`；INBOX 2436 封中窗口内 ~60 封、Junk 138、Sent 63。
> 窗口内与我方系列相关的**新**事件（排除我方自发自收的 INBOX 回环）如下。无截止压力（均无 merge window 硬死线；7.4 merge window 事件未涉及我方系列）。

| # | 来信 | 是否相关/新 | 要不要回 | 回信要点（≤3 行） | 截止 |
|---|---|---|---|---|---|
| 1 | **Dmitry Baryshkov → [PATCH v2 2/3] drm/msm/mdss: reset all block resets**（INBOX 16141，+0200 10-31 23:47 = CST 11-01 05:47） | ✅ 我方 mdss v2，新意见 | **必须回（v3 落地）** | ① 删 `msm_mdss_reset()` 上方新加的长注释（他点名「AI agents like lengthy comments, useless」）；② 保留 `devm_reset_control_array_get` 改法（未反对 API 本身）；③ v3 一并落 RSCC 删除 | 中（v3 越早越好，但无死线） |
| 2 | **Dmitry → [PATCH v2 3/3] sm8750: describe all MDSS block resets**（INBOX 16143，同批） | ✅ 新意见：**「Please drop the RSCC reset」** | **必须回（v3）** | ① 删 `DISP_CC_MDSS_RSCC_BCR`，只留 CORE/INT2；② 与 Konrad 10-31「MDSS RSC is not part of MDSS itself」意见一致，cover letter 里合并说明；③ 判据不依赖 RSC（Q28 复现是 CORE+INT2 未复位） | 中 |
| 3 | （16142/16144 为 16141/16143 的列表重复投递，同内容，非独立事件） | 重复 | 不回 | — | — |
| 4 | **postmaster@qualcomm.com Undeliverable**（Junk [414]，10-30 22:27 −0700） | ⚠ 退信 | 核实（人工） | 退信主题串到我方 mdss-common v2 1/3，但正文引用的是 IPQ5018 PHY 补丁（线程错位）；收件人疑似 `@oss.qualcomm.com`/outlook 段。需人工打开原信确认哪个收件地址被弹、是否需重发 mdss-common binding | 低 |
| 5 | wl2868c / M3-1 dwc3 v5 / M6 B5 / M8 RSC / camss：窗口内**无维护者新回信**（sashiko 未再评新版本；Sent 219–223 = v4 四枚 10-31 14:55、224–232 = dwc3 v5 + DSI bonded 五枚 10-31 23:01 均已发出；INBOX 侧仅我方自收回环） | — | 不回，继续等 | — | — |
| 6 | Junk 内 libcamera 大流量（Ray Strode/Jacopo/Laurent 等）与我方系列无关（我方 camss 已收敛为 fix-only，libcamera 非我方面） | 无关 | 不回 | — | — |

**回信纪律提醒**（写回信前适用，不在本 lane 执行）： Dmitry 点名「AI agents like to insert lengthy comments」——回应与 v3 更正信开头必须按 `AGENTS.md` 上游发信三件套披露 AI 辅助，并逐条给证据；他这条措辞说明该维护者对 LLM 味文本敏感，v3 的 commit message 与回信要短。

---

## §5 任务 B2：mu_wide_platforms issue #12 状态（gh api 实测）

- state = **open**；comments = 7；最后更新 = **2026-10-29T04:19:30Z**。
- 时序：sunflower2333 10-09「固件版本相关，需 UFSDxe 专用补丁」→ 我方 10-21（0x402 静态定论）→ 10-28（logfs/UEFI_BASE 证据）→ sunflower2333 10-28「UFS link state 在 Sleep，写 tiny DXE 拉起来」→ 我方 10-28/10-29 两轮澄清 → **最新（10-29）：sunflower2333「别的设备当然可以用，我都说了是你系统版本问题。别用劣质 token 瞎猜了。你要是没有办法把屏幕拍给 AI 调试，就去弄个 UEFI 的 USB ACM Gadget。」**
- **要不要回**：建议回（简短、低优先）。要点：
  1. 接受「固件版本相关」定性，不再争 UFSDxe 件本身；
  2. 说明我方 11-01 的实测重心已移到「ABL 装载路径/执行判据」（`fastboot boot` 三态 + 判执行需独立通道），UFS 线挂起；
  3. 对「USB ACM Gadget」建议正面接：已有 ttyGS0 串口通道（内核侧），UEFI 侧可评估 `QcomGeniSerialPortLib`/ACM 方向，给一句可行性答复即可。
  - 无截止压力；不回也不阻塞任何主线任务。
- 注意：作者语气对「AI 生成内容」反感明显，回帖若由 agent 起草，须极简、披露 AI 辅助、作者校对（同 §4 纪律）。

---

DONE
