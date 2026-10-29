# 审计报告：文档与事实一致性（Lane A，2026-10-29 待办口径）

> 只读审计。不改任何文件（本报告除外）。每条结论带「命令 + 原始输出片段」。
> 骨架先落盘，分节追加。

状态：进行中（骨架）

## 0. 审计范围与方法
## 1. 在机实测 vs TASKS §0 状态数字

### 1.1 在机实测快照（2026-10-29 17:06，ssh root@192.168.7.1，BatchMode 只读）

```
$ uname -a
Linux elden 7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172 #28 SMP PREEMPT Tue Oct 27 23:26:17 CST 2026 aarch64 GNU/Linux
$ cat /proc/cmdline   # 关键片段
… elden_root=LABEL=linux17 androidboot.slot_suffix=_b … elden_early_gadget=1 elden_q28_nowd …
$ uptime
 17:06:21 up  2:26,  2 users,  load average: 0.23, 0.11, 0.03
$ waydroid status
Session:	RUNNING
Container:	RUNNING
Vendor type:	MAINLINE
$ ls /lib/modules
7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk163
7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172
$ findmnt -n -o SOURCE,FSTYPE / && head -1 /etc/os-release
/dev/sda17 ext4
PRETTY_NAME="Debian GNU/Linux forky/sid"
$ 模块计数：vk163 树 = 1529 .ko；vk172 树 = 1639 .ko
```

### 1.2 vs TASKS/README.md §0「运维/资产」行

| §0 声明 | 实测 | 判定 |
|---|---|---|
| `boot_b` = `boot-elden-vk181-daily.img`（UTS `…-debug-vk172`，`uname -v #28`） | UTS/#28 逐字一致；boot_b 分区 sha256 `b72866ef…` = `bootslot-b/boot_b.img`（10-29 14:39），其 AVB 原镜像 84 520 960 B = `out/boot-elden-vk181-daily.img` 文件大小，manifest `version=vk181-daily`、`kernel_release=…-debug-vk172` | ✅ 一致 |
| 今日曾刷入 `vk182-camssv3` 后已回滚 | `out/boot-elden-vk182-camssv3.img` mtime 10-29 14:24 < `bootslot-b/boot_b.img` 10-29 14:39，时间线吻合 | ✅ 一致 |
| 行内残留：「在机 boot_b = `vk173`（2026-10-26 21:26 刷入…）」「根 = `f2fs @linux18` 96 GiB」「日常线仍 vk152 载荷 / 在机 f2fs-root」 | vk173 签后 sha `1a05a89d…` ≠ 在机 `b72866ef…`；cmdline `elden_root=LABEL=linux17`、`/` = `/dev/sda17 ext4`（Debian） | ❌ 不一致——同一段行内新旧口径并存未清理 |

### 1.3 vs DEVICE/README.md §1.1

- 10-27 条目「运行根 = linux17 ext4 Debian、uname -r = …-debug-vk172、Waydroid RUNNING」与实测**一致** ✅。
- 但该条目「`boot_b` 未改，仍是 `vk173`」**已过时**：在机 boot_b sha `b72866ef…` 是 vk181-daily 签名版（10-29 刷入），§1.1 无 10-28/10-29 刷写条目。而 TASKS §0 行尾又声明「在机 boot_b 口径 → ../DEVICE/README.md §1.1」⇒ **两文档互相指认对方为权威却给出不同答案**（TASKS §0 = vk181-daily ✓ 实测；DEVICE §1.1 = vk173 ✗ 过时）。这是本次审计最实质的一致性问题。
- 模块树计数偏差：vk172 树实测 **1639** .ko vs §1.1 记载 1638（差 1，疑 10-27 后追加部署）；vk163 树实测 **1529** .ko vs §1.1 记载 1539（差 10，疑 mod-loop 热换/后续增删，未在文档留痕）。

### 1.4 §0 完成度数字 vs §1 明细自洽性

- **G1 ~91%**：`30/33 = 90.9%` ✅；分母口径「36 扣 G1-10（❌取消）/G1-29·G1-30（⛔搁置）」与 §1 表可核对（G1-0…G1-36 共 37 ID，G1-1…36 = 36）✅。**但「30」的成员集合不能从 §1 唯一对账**：明确 ✅ 的明细 20 行 + 打包行 `✅ G1-12…21`（10 项）= 30；另有 G1-6（🟡新卡收口）/G1-8（🟢已出分）/G1-22（🟢根因指名）/G1-33（🟢结项）4 行未声明是否计入，而 §0 的 30 项描述**点名 G1-8**——若计入则 >30。判：**量级自洽、成员口径模糊**。
- **G2 ~65%**：§2 明细 C0…C11 共 12 ID；§0 称 12 完成/1 进行/1 未开始，粗算 12/14 ≈ 86% ≠ ~65%。全文件无 65% 的推导口径（疑按 §6 用例打分加权，但未注明）。判：**数字不可复算**。
- **G2 一处直接冲突**：§0 把「C9 用例集」列入已完成 12 项，而 §2 明细行 75 `| C9 | … | ⬜ 新增 |` 未同步（其完成依据实为 A15 行「✅ 已定稿 → `README.md §6` §5」）。
- **G3**：「PoC ✅ / Steam 登录界面 ✅」证据指针 `reports/g3-steam-20261028.md`、`reports/artifacts/c5-u7-l1d-shot-20261029.png`（32 325 B，10-29 11:58）、`reports/g3-steam-screenshot-paths-20261029.md` 均真实存在 ✅。

### 1.5 G1「30 项完成」抽查 5 项证据指针（全部真实存在）

| 抽查项 | 指针 | 结果 |
|---|---|---|
| G1-0 BL 解锁 | `archive/topics/复盘-2026-10-03-BL解锁.md` | EXISTS |
| G1-2 GPT 手术 | `backup/HA2EXB0E-16+512/gpt_main0.bin`（另有 gpt_backup0/gpt_new_*） | EXISTS |
| G1-8 基准 | `archive/topics/BENCH-2026-10-11.md` + `scripts/bench-run.sh`（logs 已自标 MIGRATION-LOST） | EXISTS |
| G1-23 残留复核 | `reports/g1-23-windows-20261026.md` | EXISTS |
| G1-36 WiFi 候选榜 | `reports/wifi-scan-stale-20261019.md` + `scripts/wifi-scan-refresh.sh` + `rootfs/persistent-overlay/etc-initd-wifi-scan-refresh` | EXISTS |

结论：§1 明细行的证据指针不是空话，5/5 落到真实文件。
## 2. 主机侧账本核对（out/ versions/ git）

### 2.1 原始输出

```
$ ls -t out/ | head -20
mail-20261029b  mail-20261029  boot-elden-vk182-camssv3.manifest  boot-elden.img
boot-elden-vk182-camssv3.img  dtbo-dummy.img  initramfs-slim.cpio.gz
ramdisk-vk181-working.cpio.gz  ramdisk-vk181-daily.cpio.gz  lane-camss-v6
mail-20261028  debian  stage-debian  boot-elden-vk181-daily.manifest
boot-elden-vk181-daily.img  boot-elden-vk180-b5step4b.manifest  boot-elden-vk180-b5step4b.img
boot-elden-vk179-b5step4a.manifest  boot-elden-vk179-b5step4a.img  (boot-elden-vk178-b5verify.manifest 截断)
（out/ 共 314 项）

$ ls versions/
cloud-backup-20261016.MANIFEST.sha256  manifest-incomplete-allowlist.txt
migration-gaps-2026-10-17.tsv  vk-identity-inflight.txt  vk-kernel-identity.tsv
vk-ledger-known-issues.tsv  vk-registry.tsv  vk-registry.tsv.lock  vk-triage.tsv

$ git log --oneline -5
6d2bd83 patchwork 收口：camss v1/v2 全置 superseded（token 存 keyring，不入仓库）
ca925ce docs: 2026-10-29 收官——SSOT 三处并入 + 会话总结
d810f2c TASKS §7 M6：用户裁决暂不启动 bonded 核心上游化（B5 维持备料封存）
333373e camss: 回信已发（引用上游 v23 并主动放弃 6 枚）；PITFALLS #469
143535d TASKS §7 M4 补回信草稿指针 + HISTORY 重生成

$ git status --porcelain   # 共 6 行，全部为 ?? 未跟踪
?? reports/artifacts/c5-u7-sf-20261029/   ?? reports/audit-20261029-crossdoc.md
?? reports/audit-20261029-pending-consistency.md  ?? reports/c5-u7-sf-skimage-20261029.md
?? reports/m4-camss-v3-plan-20261029.md   ?? reports/mail-triage-20261029b.md
```

### 2.2 §0 提到的镜像/账本逐项核对

| §0 声明 | 核对 | 判定 |
|---|---|---|
| `boot-elden-vk181-daily.img` 在 boot_b | 文件在（84 520 960 B，10-28 09:16）+ manifest（`version=vk181-daily`、`kernel_release_matches_image=yes`）；签后件 = `bootslot-b/boot_b.img`（10-29 14:39）与在机分区逐字一致 | ✅ |
| `vk182-camssv3` 已在 versions/ 三表登记（含 uts_dup/num_ne_tag 两条例外） | `vk-registry.tsv` 行 287 ✓、`vk-kernel-identity.tsv` 行 60 ✓、`vk-ledger-known-issues.tsv` 恰 2 行（`uts_dup`/`num_ne_tag`，理由引 PITFALLS #468）✓；镜像 + manifest 在 out/ | ✅ |
| vk181-daily 自身登记 | registry 行 286「B5 实验后还原日常线树重打的无标记镜像（设备复原用）」、identity 行 59（含 `num_ne_tag`\|`uts_dup6` 例外） | ✅ |
| 里程碑 vk84-q28delay「镜像 `out/boot-elden-vk84-q28delay-{base,exp}.img`+manifest」 | **两个 .img 均缺失**（仅 .manifest 在） | ❌ §0 声称的镜像不存在且未标 MIGRATION-LOST（vk90–93 臂已标，vk84 未标） |
| vk161/vk163/vk172/vk173 | `out/boot-elden-vk161.img`（22 MB）、vk163（85.8 MB）、vk172/vk173（84 525 056 B）均在 | ✅ |
| Q24 臂镜像 vk90–vk93 | §0 已自带 ⚠️MIGRATION-LOST 标注（本地已无） | ✅（声明与事实相符） |

### 2.3 判定

- versions/ 三表 + triage 表真实存在，vk181/vk182 登记完整，§0 主张的账本状态**与磁盘一致**。
- git 工作树干净（无已跟踪文件改动），HEAD = 10-29 收官提交，仅 6 个未跟踪的当日报告/工件（含本报告）——与「10-29 收官」声明相符。
- 唯一缺口：**vk84-q28delay 两个镜像缺失**（manifest 存留），§0 该句未像 vk90–93 一样标注 MIGRATION-LOST。
## 3. 10-28 / 10-29 会话「★SSOT 待并入」逐条核验
## 4. PITFALLS 索引行长度/编号撞车 + check-doctor WARN

### 4.1 check-doctor（实际 FAIL=0 WARN=3，与任务假设的 2 不符）

```
$ bash scripts/check-doctor.sh 2>&1 | tail -5
== 13. 文档引用的资产路径（委托 check-doc-assets.sh）==
  [ok]   文档资产路径齐全（checked=437）

== 汇总: FAIL=0  WARN=3 ==
```

三条 WARN 原文与判定：

1. `[warn] 账本已登记的例外（理由见 vk-ledger-known-issues.tsv）：dtbo1(uts_dup14) … vk181-daily(num_ne_tag(…),uts_dup6) vk182-camssv3(num_ne_tag(…),uts_dup6) vk64(uts_dup7)`（一长串，全部为 uts_dup/num_ne_tag 类）。
   **可接受**——这正是 `vk-ledger-known-issues.tsv` 白名单机制的设计输出（未登记同类才会 FAIL），§2 已核对该表在案且含 vk181/vk182 条目；PINUTS 刻意复用 UTS 的设计后果（PITFALLS #192/#195/#367），非事故。
2. `[warn] 无版本号构建拷贝 1 个（build-boot.sh 默认产物，不拦构建；收口时改名或删）：boot-elden.img`
   **可接受（低风险）**——脚本自述不拦构建；但该无身份镜像易被误当最新日常件刷写，建议列入收口待办（改名或删）。
3. `[warn] 报告无人引用（结论会随文件沉底，补一处指针到对应 README/TASKS 行）: reports/audit-20261029-pending-consistency.md; reports/m8-dispcc-v2-20261029.md; reports/usb-dual-port-attribution-20261029.md`
   **可接受**——10-29 当日新件尚未走 SSOT 并入轮；其中含本审计报告自身（自指 WARN）。与「WARN=2」预期的差异即此条：多出的是当日新报告触发，非回归。另两份（m8-dispcc-v2、usb-dual-port-attribution）并入轮需补指针，否则沉底。

### 4.2 PITFALLS 编号撞车现状

- **条目编号 `#NNN`：无撞车** ✅。全文 114 处 `#NNN` 引用、109 个唯一号（最大 #469）；5 个出现 2 次的号（#87/#92/#93/#391/#444）逐一核对均为**交叉引用**（总览段「参 #87、#92、#93」或条目内互引），非两条目同号。
- **索引第一列序号：撞车仍在** ❌。`doc-audit-20261026.md` L23 曾记录「`PITFALLS` 索引第一列撞车（59×2、69×3）+ 逆序」；实测现状**逐字相同未修**：

```
$ grep -E '^\| [0-9]+ \|' PITFALLS/README.md | … uniq -c（撞车）
      2 59
      3 69
$ 逆序对：line 89: 88→87、line 90: 87→86、line 92: 89→85（136 行索引，最大序号 133）
```

### 4.3 行长度（观察项）

- `PITFALLS/README.md` 最长行 **799 字符**（L173）、次长 797（L95）、792（L161）——均为 markdown 表格行；INDEX.md 中 PITFALLS 相关最长 326 字符。仓库无行长度规范声明，判**观察项非违规**（影响可读性/ diff 审阅）。

### 4.4 小结

check-doctor FAIL=0 健康面成立；3 条 WARN 全部可接受（2 条有在案机制兜底、1 条为当日新件自指）。PITFALLS 待修项 = 索引第一列 59/69 撞车 + 3 处逆序（10-26 已立项未动）；条目编号体系本身干净。
## 5. 跨文档矛盾清单
## 6. 当前真正待办清单（需要设备 / 仅主机）
## 7. 已做/未做/待用户拍板

A1-DONE
