# 上游邮件增量分诊 — 2026-11-09

> 基线：`reports/mail-triage-20261108.md`（窗口止 **2026-11-08 05:21Z**，其 §2 的 A–D 四条待办全部未动）。
> 口径旁参：`reports/uefi-*-2026110*.md`（G1-29/路线 B 线，本轮**零相关邮件**，见 §1c）。
> **本轮窗口**：2026-11-08 05:21Z → **2026-11-09 06:29Z**（UTC，抓取时刻；共 ~25 h）。
> 只读：`M.select(box, readonly=True)`（EXAMINE）+ `BODY.PEEK[HEADER.FIELDS …]` / `BODY.PEEK[]`；
> **无 STORE/COPY/MOVE/EXPUNGE**、**未发信**、未投递、未碰设备、**未改任何 SSOT**（`TASKS/README.md`、`INDEX.md` 均未触碰）。
> 口令只从 keyring 取（`keyring.get_password('smtp'|'imap', 'xiaqinghuan@mail.ustc.edu.cn')`），未落盘、未打印。

---

## §0 一页结论

| 项 | 值 | 证据 |
|---|---|---|
| 窗口内新信 | **637 行 / 533 唯一 MID**（消息因「list 副本 + Cc 直投」重复入箱，故行数 > MID 数） | `/tmp/laneC/scan2.py 05-Nov-2026` → `/tmp/laneC/hdr.json`（3898 行）按 `parsedate_to_datetime` 切窗口 |
| **外部回信（给我方线程）** | **0**（唯一 MID 0；`In-Reply-To`/`References` 含我方地址者 0） | 同上去重后过滤 `O in irt+refs` |
| 直接寄给我（To 只有我、非 list） | **0** | 同上 |
| DSN / 退信 | **0**（`postmaster|mailer-daemon|undeliverable` 全窗 0） | 同上 |
| Junk 命中我方线程 | **0**（Junk 53 行全部 ≤ 11-06 21:33Z，窗口内 0 行） | 同上 |
| **我方外发** | **0**（Sent Items 最晚一封 = 11-07 10:41Z 图形学作业） | 同上 |
| patchwork 状态变化 | **0**：50 条 patch 状态与 11-08 快照逐条一致，**Acked/Reviewed/Tested 标签仍全空** | `GET /api/1.2/patches/?submitter=xiaqinghuan@mail.ustc.edu.cn&since=2026-11-04`（§1a） |
| lore 新回复 | **0**：dwc3 v8 / wl2868c v9 / M10 三线程最新一封仍是 **11-07 03:33Z** | `lore-query.py …?q=<各 cover MID>`（§1a） |
| **新增技术待办** | **0**（本窗口没有任何针对我方补丁的技术意见进来） | §1、§2 |
| 结转待办 | **10 条 / 4 组**（A dwc3 binding 4 条、B wl2868c driver 3 条、C wl2868c binding 2 条、D M10 1 条）——全部**仍存在于当前最新版本代码里**（本轮逐条重核，见 §1 证据列） | §1、§2 |
| **阻塞项** | **0**：11-08 唯一的阻塞（M10 `Fixes:` 哈希无法本地核对）**已解除**，`be9d54c35312` = `be9d54c35312479ed92c85aec3cd43153513210d`，subject 逐字匹配 | §3 |
| 人工评审 | **仍 0**：v8 dwc3 = `new`（usb）+ `needs-ack`（dt）；v9 wl2868c = `needs-ack`（dt）+ `handled-elsewhere`（arm-msm）；M10 = `new` | patchwork，同上 |

**一页结论**：**本窗口对我方零增量**。25 小时内 533 封唯一上游邮件里，没有一封是回我们的，
patchwork 上没有一封被加标签或被 apply，lore 上三条线程自 11-07 起完全静止（v9 已 53 h、M10 已 51 h 无 bot 也无人工）。
11-08 记的 10 条技术欠账因此**一条没减、也没有新增**，唯一实质进展是**把最后一个阻塞（M10 的 `Fixes:` 哈希）在 lore 上核实掉了**：
`be9d54c35312479ed92c85aec3cd43153513210d`（Alexey Klimov 的 `[RFT PATCH v3 2/2]`，Bjorn 2026-01-21 applied，进 v6.20 DT pull），
subject 与 sashiko 给的字符串逐字相同 ⇒ **M10 v2 现在可以直接发，只剩用户批准**。
顺带把 11-08 报告里「四棵树 `cat-file -t` 全 `none`」这个疑点解释清楚了（§1b）：那不是「上游没这个提交」，
而是本机四棵树的 `rev-list --count` 只有 1–3（压缩导入，无上游历史），本来就查不到任意上游哈希。

---

## §1 分线程状态表（我方 4 条在册线程，全表）

| # | 线程（最新版本） | 最新一封（UTC） | 发件人 | 本窗口新信 | 已解决？ | 证据（本轮重核处，行号 = patch 文件内行号） |
|---|---|---|---|---|---|---|
| 1 | `[PATCH v8 1/3] dt-bindings: usb: snps,dwc3`（`<20261106114208.987284-2-…>`） | 11-06 11:49Z `<sashiko-outbox-201360@kernel.org>` | sashiko | **0** | ❌ **4 条（3M+1L）全在**：M1 `hs-port` 未 `required` `endpoint`/`mux-state`（只靠 `dependentRequired`）；M2 `'^endpoint(@[0-9a-f]+)?$'` 编号 pattern 仍在；M3 顶层 `ports.properties` 仍只有 `port@0/port@1`（缺 `port@2`）；L1 description 仍引用 Linux 内部符号 + `port@1` 出处错 | `patches/upstream/m3-dwc3-v7-20261106/v8-0001-*.patch`：`:79`（hs-port `patternProperties`）、`:108-110`（mux 分支只写 `port@0/port@2`）、`:150-161`（else 分支嵌套 `patternProperties`）；M3 在 `Documentation/…/snps,dwc3.yaml` 顶层（11-08 审计结论） |
| 2 | `[PATCH v9 2/2] regulator: willsemi,wl2868c` driver（`<20261107015014.22374-3-…>`） | 11-06 11:44Z `<sashiko-outbox-201353@kernel.org>` | sashiko | **0** | ❌ **3 条 Medium 全在**：① 电源次序（reset 处理 `:261-271` + `fsleep(1000)` 都在 `devm_regulator_get_enable(dev,"vsys")` `:284` **之前**，读 DEVICE_ID 前无上电延时）；② 只取 `vsys`，无 `vin7` 回落（`:284` 单点）；③ `chip->enabled = value & WL2868C_LDO_ENABLE_MASK`（`:304`）**不看 `SYS_EN`** 就播种 | `patches/upstream/wl2868c-v9-20261107/v9-0002-*.patch`:261,271,284,304（本轮 `grep -n` 实查，与 11-08 引用一致） |
| 3 | `[PATCH v9 1/2] dt-bindings: willsemi,wl2868c`（`<20261107015014.22374-2-…>`） | 11-06 11:46Z `<sashiko-outbox-201357@kernel.org>` | sashiko | **0** | ① provider 节点**已删**（Rob 要求已遵），但 example 里 `ldo1` 仍只给 `vsys-supply`、**无 `vin12-supply`**（`:67` 定义、`:108-121` example）；② `F: drivers/regulator/wl2868c-regulator.c` 仍在 1/2 的 MAINTAINERS hunk（`:145`），该文件 2/2 才创建 ⇒ **2 条 Low 全在** | 同目录 `v9-0001-*.patch`:67,108,121,145（本轮实查） |
| 4 | `[PATCH] arm64: dts: qcom: sm8750: mark the ADSP fastrpc node as non-secure domain`（`<20261107032646.32363-1-…>`） | 11-07 03:33Z `<sashiko-outbox-202531@kernel.org>` | sashiko | **0** | ❌ 单封补丁，**尚无 v2**；`Fixes:` trailer 未补（草稿在 `out/mail-20261108/m10-v2-note-draft.txt`，哈希待填——**本轮已核实，见 §3**） | `patches/upstream/sm8750-adsp-nonsecure-20261107/0001-*.patch`；本轮 `git apply --check` 对 `build/m3v2-7.3rc7`、`build/base-7.2` 均 **APPLIES CLEAN** ⇒ diff 本身无需改动 |

> 行 1–4 的「已解决？」列结论 = **均未解决**，且原因不是评审没看，而是**我们自 11-07 之后没有再发新版本**（无 v9 dwc3、无 v10 wl2868c、无 M10 v2）。

### §1a 复核（lore + patchwork，2026-11-09 06:2xZ 实拉）

```
# lore：三条线程各自最新一封仍是 11-07（此后 all/ 无任何新回复，人类与 bot 都 0）
lore-query.py "https://lore.kernel.org/all/?q=20261107015014.22374-1"   → 仅 v9 0/2 本体（11-07 01:50:18Z）
lore-query.py "https://lore.kernel.org/all/?q=20261106114208.987284-1"  → v8 0/3 + sashiko 201358/201364（≤11-06 11:52Z）
lore-query.py "https://lore.kernel.org/all/?q=20261107032646.32363-1"   → M10 本体 + sashiko 202531（11-07 03:33:43Z）

# patchwork：状态与 11-08 快照逐条相同，0 个标签
GET /api/1.2/patches/?submitter=xiaqinghuan@mail.ustc.edu.cn&since=2026-11-04T00:00:00&per_page=100  → 50 条
  v8 dwc3  : Linux USB 1/3,2/3,3/3 = new   | Devicetree 1/3 = needs-ack, 2/3,3/3 = handled-elsewhere
  v9 wl2868c: Devicetree 1/2 = needs-ack, 2/2 = handled-elsewhere | arm-msm 1/2,2/2 = handled-elsewhere
  M10      : Linux ARM MSM = new
  tags（Acked/Reviewed/Tested）= [] × 50
```

**注意**：`handled-elsewhere` 只表示该 patch 被归到另一个 project（同系列多 project 拆收），**不是「已接收」**；判定接收只能靠 `Acked/Reviewed/Tested` 或 `state=accepted`，两者皆无。

### §1b 三个坑（写下来免得下次再踩）

1. **「四棵树 `cat-file -t` 全 `none`」≠ 上游没这个提交。** `git -C build/m3v2-7.3rc7 rev-list --count HEAD` = **3**、
   `build/base-7.2` = 2、`linux` = 1 —— 都是压缩/合成导入树，没有上游历史，对任意上游哈希必然 `none`。
   核对上游提交要查 lore（`b4` applied 回信里的 `commit:` 行最可靠），不要用 `cat-file` 反证。
   本轮即用此法确认 `be9d54c35312` 存在（§3）。
2. **`read-mail-ustc.py --replies-only` 仍不可用**：脚本内 `OUR_IDS`（第 21–23 行）硬编码的是 3 个 10 月 Message-ID，
   对 11-06/11-07 的 `20261106112811…`、`20261106114208…`、`20261107015014…`、`20261107032646…` 必然 0 命中。
   本轮改用「`In-Reply-To`/`References` 含 `mail.ustc.edu.cn`」判归属。
3. **Coremail 同一封信可能入箱 2–3 次**（list 副本 + 直接 Cc 副本，Message-ID 相同）：
   窗口 637 行 vs **533 唯一 MID**。统计一律先去重，否则「新信数」会虚高 ~20%。
   另：`M.select('"Sent Items"')` 在同一连接上紧跟 Junk 之后会返回 `BAD [Request not ending with]`，
   本脚本改为**每个夹重新登录**（`scan2.py`）即稳定。

### §1c 相邻线程（窗口内的上游动静，与本项目的关系）

| 时间(UTC) | 线程 | 结论 | 对本项目 |
|---|---|---|---|
| 11-08 20:20 | Bjorn applied `[PATCH v2 0/2] arm64: dts: qcom: sm8750: Add watchdog support` → `6554c11efd6d` | **applied** | 改 `sm8750.dtsi`，**发生在我方 M10（11-07 03:26Z）之后** ⇒ M10 v2 合入前需按此重生成（内容级 `apply --check` 已过，见 §1 行 4） |
| 11-08 20:21 | Bjorn applied `[PATCH] arm64: dts: qcom: sm8750: Fix iommu stream ID masks for CDSP compute CBs` → `afe52f52d645` | **applied** | 同上，改的是 `compute-cb@12/@14` 的 `iommus`，与 M10 同文件同区域，**同一提醒** |
| 11-09 00:33 | Stanislav Aleksandrov `[PATCH 07/17] dt-bindings: usb: qcom,snps-dwc3: Add Halliday` + 11-09 00:42 sashiko「no issues」 | 新设备枚举，**不冲突** | 改的是 `qcom,snps-dwc3.yaml`（3 处 enum 追加）；我方 dwc3 改的是 `snps,dwc3.yaml`，**无 hunk 重叠** |
| 11-09 03:55 | mkp applied `scsi: ufs: qcom: Reprogram ESI after a host controller reset` | **applied** | G1 UFS 稳定性旁证，与本轮补丁无关 |
| 11-08 07:22 | Akash Kumar `Re: [PATCH v2] usb: dwc3: Update nominal max votes for qcom usb` | 他人线程 | 同为 dwc3 但走 `dwc3-qcom.c` 互联投票，**与我方 3/3 无文件重叠** |
| 全窗 | `qseecom|uefi|edk2|mu_wide|pakala|gunyah` 关键词 | **0 封** | G1-29 线（`reports/uefi-*-2026110*.md`）**零相关邮件**，无需处理 |

---

## §2 待办分组（按系列；逐条给具体修改点）

> 全部为 **11-08 结转**，本轮**无新增**。应用顺序建议：D（1 封、最便宜）→ B+C（同一 v10）→ A（v9 三封）。
> 每条都标注「文件:行（现状）」与「改成什么」。**均未落地**：`patches/upstream/` 下最新仍为 `m3-dwc3-v7-20261106`、`wl2868c-v9-20261107`、`sm8750-adsp-nonsecure-20261107`。

### A. dwc3 `[PATCH v9 0/3]`（回复 `<sashiko-outbox-201360@kernel.org>`；只有 1/3 变，2/3、3/3 与 v8 逐字节相同）

| # | 严重度 | 现状（`v8-0001-*.patch`） | 改法 |
|---|---|---|---|
| A1 | Medium | `:74-81` `hs-port` 只有 `patternProperties`，`endpoint`/`mux-state` 靠 `dependentRequired` 互锁，单写一个/都不写仍能过校验 | 改成单节点 `endpoint:` + `required: [usb-role-switch, mux-state]`（并在 `oneOf` 两支的 `port@0`/`port@2` 各自 `required: [endpoint]`） |
| A2 | Medium | `:79` `'^endpoint(@[0-9a-f]+)?$'` 允许 `endpoint@0`/多 endpoint，与只看未编号 `endpoint` 的 `oneOf` 不一致 | 删掉编号 pattern，只描述一个名为 `endpoint` 的节点 |
| A3 | Medium | 顶层 `ports.properties`（`snps,dwc3.yaml`）只有 `port@0`/`port@1` | 补 `port@2`（否则 `ports:port@2` 会被判 `additionalProperties`） |
| A4 | Low | `:150-161` else 分支仍用嵌套 `patternProperties`；description 引用 `usb_role_switch_at_endpoint()`/`dwc3_*` 内部符号，并称「`port@1` 由 `snps,dwc3.yaml` 描述」 | 改为 `endpoint` 单节点；description 去掉 Linux 符号、改成 DT 语义，并把 `port@2` 的**存在理由**（为何不是 `port@0` 的两个 endpoint）写清楚 |

草稿：`out/mail-20261108/cover-dwc3-v9-draft.txt`（含 AI 披露 + `claims.tsv` 证据位；两处 `(TODO)` 待生成补丁后回填 dt-validate 正/负输出）。

### B. wl2868c `[PATCH v10 2/2]` driver（回复 `<sashiko-outbox-201353@kernel.org>`）

| # | 严重度 | 现状（`v9-0002-*.patch`） | 改法 |
|---|---|---|---|
| B1 | Medium | `:261-271` reset 处理 + `fsleep(1000)` 在 `:284` 使能 `vsys` **之前** ⇒ 延时发生在芯片无电时；且 devres 逆序 ⇒ unbind 先关 `vsys` 再拉 reset | 把 `devm_regulator_get_enable(dev, "vsys")` 提到 reset 处理**之前**，把上电后的 1 ms 稳定延时挪到 `regmap_read(DEVICE_ID)` 之前；这样 devres 逆序自然变成「先拉 reset、后关 supply」 |
| B2 | Medium | `:284` 只 `devm_regulator_get_enable(dev, "vsys")`；binding 允许 `vin7-supply` 二选一 ⇒ vin7 板拿到 dummy regulator，控制逻辑无电 | 用 `devm_regulator_get_enable_optional(dev, "vsys")`，失败则回落 `vin7`，并保证二者之一常开 |
| B3 | Medium | `:304` `chip->enabled = value & WL2868C_LDO_ENABLE_MASK`，不判 `SYS_EN` ⇒ 固件预置位被当成「已使能」带上 | 仅当 `value & WL2868C_SYS_ENABLE` 时才播种，否则 `chip->enabled = 0` |

### C. wl2868c `[PATCH v10 1/2]` binding（回复 `<sashiko-outbox-201357@kernel.org>`，与 B 同一封 v10）

| # | 严重度 | 现状（`v9-0001-*.patch`） | 改法 |
|---|---|---|---|
| C1 | Low | `:67` 定义了 `vin12-supply`，但 `:108-121` example 的 `ldo1` 只给 `vsys-supply` | example 补 `vin12-supply = <&vreg_vin12>`；**不**加回 provider 节点（遵 Rob 11-06 意见） |
| C2 | Low | `:145` `F: drivers/regulator/wl2868c-regulator.c` 在 1/2 的 MAINTAINERS hunk，而该文件 2/2 才创建 | 把 MAINTAINERS 改动整体移到 2/2 |

草稿：`out/mail-20261108/cover-wl2868c-v10-draft.txt`。

### D. M10（`sm8750` ADSP fastrpc non-secure-domain）→ v2 单封重发

| # | 现状 | 改法 |
|---|---|---|
| D1 | 单封补丁无 `Fixes:` | 加 `Fixes: be9d54c35312479ed92c85aec3cd43153513210d ("arm64: dts: qcom: sm8750: add ADSP fastrpc-compute-cb nodes")`（**哈希/subject 本轮已核实，见 §3**），放在 `Signed-off-by` 之前；diff 不变 |

草稿：`out/mail-20261108/m10-v2-note-draft.txt`（把 `(TODO)` 行替换成上面这行即可投）。

### E. 等人工评审（无动作）

- 零人工标签已 53 h+；按 `TASKS/README.md` §7 口径 **不 ping、不催**。
- 可注意但不必动作：v9 发出后 **sashiko 也没再审**（v7/v8 是分钟级）。合理推断是 v9 与 v8 的 diff 只落在 1/1 的 schema 形状上、且未触发新规则；
  若 v10 发出后 24 h 仍无 bot 回音，再考虑是否 resend（那时按 §7 走用户批准）。

---

## §3 阻塞项

**阻塞数 = 0**（11-08 的 1 项已解除）。

| 原阻塞 | 状态 | 证据 |
|---|---|---|
| M10 的 `Fixes: be9d54c35312` 在本机四棵树 `cat-file -t` 全 `none`，无法核对哈希与 subject | ✅ **已解除** | lore `…/all/176902536623.1171053.13192258652095595279.b4-ty@kernel.org/raw`（Bjorn 2026-01-21 applied）：`[2/2] arm64: dts: qcom: sm8750: add ADSP fastrpc-compute-cb nodes  commit: be9d54c35312479ed92c85aec3cd43153513210d`；同系列 `[1/2]` = `0bcf9ca23a87…`；并进 `[GIT PULL] More Qualcomm Arm64 DeviceTree updates for v6.20` ⇒ 提交在 v6.20 起的主线上，`Fixes:` 合法 |
| 上述「全 none」的**根因** | 已查明（非阻塞） | `git rev-list --count HEAD`：`build/m3v2-7.3rc7`=3、`build/base-7.2`=2、`linux`=1 ⇒ 压缩导入树，无上游历史 |

**仍需用户动作（不是技术阻塞，是放行）**：`TASKS/README.md` §7「按系列逐次批准」——A/B+C/D 三批投递需用户逐批放行；本轮**未发任何信**。

**已知的验证边界（写清以免误判）**：
- 本地无法对 dwc3/wl2868c 做「上游 for-next 上的 rebase 验证」（树无上游历史）；但 M10 已用 `git apply --check` 在两个树上确认 diff 干净。
- 本窗口统计基于**我方邮箱收件**：若 vger/subspace 丢信，邮箱会漏；本轮已用 lore 三线程独立复核，结论与邮箱一致（0 新回复），故「零增量」可信。

---

## §4 复跑命令

```bash
# 1) 只读头表（EXAMINE + PEEK，每夹重登录；输出 /tmp/laneC/hdr.json）
python3 /tmp/laneC/scan2.py 05-Nov-2026

# 2) 窗口内「回我们的信」+ 去重计数（当前 = 0）
python3 - <<'EOF'
import json,email.utils,datetime
d=json.load(open('/tmp/laneC/hdr.json'))
def dt(s): return email.utils.parsedate_to_datetime(s).astimezone(datetime.timezone.utc)
B=datetime.datetime(2026,11,8,5,21,tzinfo=datetime.timezone.utc)
O='xiaqinghuan@mail.ustc.edu.cn'
w={r['mid']:r for r in d if dt(r['date'])>B}
print("rows",sum(1 for r in d if dt(r['date'])>B),"unique MID",len(w))
for r in sorted([r for r in w.values() if O not in r['frm'] and O in r['irt']+r['refs']],key=lambda r:dt(r['date'])):
    print(dt(r['date']),r['frm'][:32],'|',r['subj'][:60],'|',r['mid'])
EOF

# 3) 取正文（按 Message-ID）
python3 /tmp/laneC/body.py '<sashiko-outbox-201360@kernel.org>'

# 4) patchwork 状态
curl -s 'https://patchwork.kernel.org/api/1.2/patches/?submitter=xiaqinghuan@mail.ustc.edu.cn&since=2026-11-04T00:00:00&per_page=100'

# 5) lore 线程最新一封 + 上游提交哈希（绕过 raw 403：用 lore-query.py 的 get()）
python3 ~/.local/bin/lore-query.py "https://lore.kernel.org/all/?q=20261107015014.22374-1"
```

DONE-MAILTRIAGE-20261109
