# 上游邮件增量分诊 — 2026-11-08

> 基线：`reports/mail-triage-20261105.md`（窗口止 **2026-11-05 02:40Z**，已处理）。
> **本轮窗口**：2026-11-05 02:40Z → **2026-11-08 05:21Z**（抓取时刻，UTC）。
> 只读：`M.select(box, readonly=True)`（EXAMINE）+ `BODY.PEEK[]`/`BODY.PEEK[HEADER.FIELDS …]`；**无 STORE/COPY/EXPUNGE/MOVE**、**未发信**、未投递、未碰设备、未改 SSOT 文件。
> 口令只从 keyring 取（`service smtp` / `smtp.ustc.edu.cn:465`），未落盘。

---

## §0 口径与结论

| 项 | 值 | 命令/证据 |
|---|---|---|
| **新信数** | 窗口内三处共 **2481 条头**（INBOX 2409 / Junk 53 / Sent 19）；其中 **外部回信 10 封唯一 MID**（sashiko 8 + 人类 2）；**我方外发 18 封**（11-06 v7/v8 两轮 + 11-07 v9 + M10） | `/tmp/laneB/scan.py 25-Oct-2026` → `hdr.json`（10174 条）后按 `email.utils.parsedate_to_datetime` 切窗口 |
| 退信 / DSN | **0**（`From|Subject` ~ `postmaster|mailer-daemon|undeliverable`） | 同上过滤 |
| Junk 命中我方线程 | **0**（11-05 之后 Junk 全是 libcamera/mali-c55 他人线程） | 同上 |
| **行动数** | **4 组共 10 条技术待办**（A dwc3 binding 3M+1L；B wl2868c driver 3M；C wl2868c binding 2L；D M10 1L） | §1、§2 |
| **阻塞数** | **1**：M10 的 `Fixes: be9d54c35312` 需在含该提交的树上核对（本机 4 棵树 `cat-file -t` 全 `none`）——不影响评审，影响 v2 正确性 | `git -C {linux,build/base-7.2,build/daily,build/m3v2-7.3rc7} cat-file -t be9d54c35312` |
| 人工评审新增 | **0**：v8 / v9 / M10 在 patchwork 上 **tags 全空**（无 Acked/Reviewed/Tested），state 全是 `new` / `needs-ack` / `handled-elsewhere`（后者 = 该 patch 属别的 project，**不是已接收**） | patchwork API `?submitter=xiaqinghuan@…` |
| 我方外发 | 11-08 全天 **0 封上游邮件**（Sent[276] 是课程作业）；本轮**只起草，不投递** | Sent Items 全表 |

**一页结论**：窗口内 10 封回信里，人类 2 封（Rob Herring、Conor Dooley）**已被 11-07 的 v9 覆盖**（v9 cover 逐条说明）；
真正的新欠账全部来自 **sashiko 对 v7/v8 的机器评审**——它们在 11-05 基线里**只被记了 dwc3 的两条 High**，
本轮把 **wl2868c driver 3 Medium、wl2868c binding 2 Low、dwc3 binding 3 Medium + 1 Low、M10 1 Low** 补全并逐条在本地源码上确认**仍然存在**。

---

## §1 分线程状态表（窗口内 10 封外部回信，全表）

| # | 时间(UTC) | 发件人 | 针对 | 结论 | 在 v8/v9 里**已**解决？ | 证据 |
|---|---|---|---|---|---|---|
| 1 | 11-06 11:35 | sashiko | v7 dwc3 `2/3` | **no issues** | — | `<sashiko-outbox-201319@kernel.org>` |
| 2 | 11-06 11:40 | sashiko | v7 dwc3 `3/3` | **no issues**（11-04 两 High 的修复被确认） | ✅ | `<sashiko-outbox-201328@kernel.org>` |
| 3 | 11-06 11:44 | sashiko | v7 wl2868c `2/2`（driver） | **3 × Medium**：① `vsys` 在 reset 释放**之后**才 enable（芯片无电时跑完 1 ms 延时，随后无启动延时就读 DEVICE_ID；且 devres 逆序 ⇒ unbind 先关 vsys 再拉 reset）② 只 `devm_regulator_get_enable("vsys")`，`vin7-supply` 板（binding 允许二选一）拿到 dummy regulator，控制逻辑无电 ③ `chip->enabled` 用 `LDO_ENABLE` 整字节播种，未判 `SYS_EN` ⇒ 第一次 enable 任何一路会把固件预置位全带上 | ❌ **全部仍在**（v9 2/2 与 v8/v7 逐字节同） | `<sashiko-outbox-201353@kernel.org>`；`v9-0002*.patch:262,270,284,304` |
| 4 | 11-06 11:46 | sashiko | v7 wl2868c `1/2`（binding） | **2 × Low**：① example 里 `ldo1` 被启用但只给 `vsys-supply`，缺 `vin12-supply`；另外 provider 节点 `vsys_reg` 该删 ② `MAINTAINERS` 的 `F: drivers/regulator/wl2868c-regulator.c` 写在 1/2，而该文件在 2/2 才创建（`get_maintainer.pl --self-test=patterns` 会告警） | ① provider **已删**、`vin12` **仍缺**；② **仍在** | `<sashiko-outbox-201357@kernel.org>`；`v9-0001*.patch:121,124,145` |
| 5 | 11-06 11:47 | sashiko | v8 dwc3 `2/3` | **no issues** | ✅ | `<sashiko-outbox-201358@kernel.org>` |
| 6 | 11-06 11:49 | sashiko | v8 dwc3 `1/3`（binding） | **3 × Medium + 1 × Low**：M1 `hs-port`/`oneOf` 未 `required` `endpoint`、`mux-state` ⇒ 漏写也能过校验、运行时 `-EINVAL`；M2 `hs-port` 的 `'^endpoint(@…)?$'` 允许多个/编号 endpoint，与只看未编号 `endpoint` 的 `oneOf` 不一致（既可两个 port 同 mux-state 而通过，也可两个 port 都用 `endpoint@0` 使两支空匹配）；M3 顶层 `ports.properties` 只有 `port@0`/`port@1`，缺 `port@2`；L1 把共享 HS mux 建模成 `port@2`+私有 `port-select-gpios`/`mux-state`，且 description 引用 Linux 内部符号（`usb_role_switch_at_endpoint()`、`dwc3_*`）与「`port@1` 由 snps,dwc3.yaml 描述」的错误出处 | ❌ **4 条全在**（v8 只改了 3/3） | `<sashiko-outbox-201360@kernel.org>`；`m3-dwc3-v7-20261106/v8-0001*.patch:75-81,108,177,182` |
| 7 | 11-06 11:52 | sashiko | v8 dwc3 `3/3` | **no issues** | ✅ | `<sashiko-outbox-201364@kernel.org>` |
| 8 | 11-06 14:10 | **Rob Herring**（人） | v6 wl2868c `1/5` | 两点：多段 description 要 `>` 块修饰符；example 不要放 provider（`vsys_reg: regulator-vsys` "Drop"） | ✅ **v9 两条都改了** | `<20261106141036.GA2921668-robh@kernel.org>`；`v9-0001*.patch:45,65,80,85`（`>`）+ example 无 `regulator-fixed` |
| 9 | 11-06 17:12 | **Conor Dooley**（人） | v8 wl2868c `1/2` | `pw-bot: changes-requested`，理由「Rob 对 v6 的意见被忽略」 | ✅ 属**时序竞态**（v8 11:42Z 发出，Rob 14:10Z 才到）；v9 cover 已单设一节说明 | `<20261106-lucrative-sadden-741ffe6c43e9@spud>`；`v9-0000-cover-letter.patch`「About the pw-bot…」节 |
| 10 | 11-07 03:33 | sashiko | M10 ADSP fastrpc | **1 × Low**：应补 `Fixes: be9d54c35312 ("arm64: dts: qcom: sm8750: add ADSP fastrpc-compute-cb nodes")` | ❌ 单封补丁，尚无 v2 | `<sashiko-outbox-202531@kernel.org>` |

### §1a 复核（lore + patchwork，2026-11-08 实拉）

- **lore 归档**（按 Message-ID，`lore-query.py`，注意 devicetree inbox = `/linux-devicetree/`）：
  `20261106114208.987284-1` → `/linux-usb/` ✅（线程下含 #5/#7 两封回复）；
  `20261107015014.22374-1` → `/linux-arm-msm/` ✅、`-2` → `/linux-devicetree/` ✅；
  `20261107032646.32363-1` → `/linux-arm-msm/` ✅。**v9 之后（11-07 01:50Z 起）全 `all/` 无任何新回复**（人类与 bot 都 0）。
- **patchwork 状态**（`?submitter=xiaqinghuan@mail.ustc.edu.cn&since=2026-11-04`，50 条）：
  dwc3 v8 = `linux-usb: 1/3,2/3,3/3 = new` + `devicetree: 1/3 needs-ack`；
  wl2868c v9 = `devicetree: 1/2 needs-ack`、`arm-msm: handled-elsewhere`（**= 该 patch 归属别的 project，非已接收**）；
  M10 = `arm-msm: new`。**全部 0 个 Acked/Reviewed/Tested 标签**。
- **与基线一致、无需重做**：11-04 的 2 High 已由 v8 修掉（#2/#7 「no issues」）；Krzysztof 两条（5/5 合并、3/5 措辞）已由「板 DTS 整段拆出 + commit message 改写」覆盖。

### §1b 派工单「再 `--days 14 --replies-only`」的坑（写下来免得下次再踩）

`read-mail-ustc.py` 的 `--replies-only` 用**脚本里硬编码的 3 个 10 月 Message-ID**（`OUR_IDS`，第 21–23 行）匹配
`In-Reply-To`/`References`，对 11-06/11-07 的 `20261106114208…`、`20261107015014…` **必然 0 命中**。
本轮改用「`References|In-Reply-To` 含 `mail.ustc.edu.cn`」判归属（`/tmp/laneB/scan.py`），才拿到 10 封。

---

## §2 待用户按批放行的投递清单（本轮**只起草，未投**）

草稿目录：`out/mail-20261108/`（`README.md` + 3 份草稿 + `claims.tsv` + `self-review.md`）。
每份都带 **AI 辅助披露**、**逐条回应**、**claims.tsv 可复现证据**（三件必备）。

| # | 对象 | 待办（技术） | 草稿 | 需用户 |
|---|---|---|---|---|
| **A** | dwc3 `[PATCH v8 1/3]` binding（回复 `<sashiko-outbox-201360@kernel.org>`） | M1 `hs-port` 单 `endpoint` + `required: [usb-role-switch, mux-state]`；M2 去掉 `patternProperties` 的编号/多 endpoint 歧义；M3 顶层 `ports.properties` 补 `port@2`；L1 删 description 里的 Linux 内部符号、修正 `port@1` 出处，并给出「为何是 `port@2` 而非 `port@0` 的多 endpoint」的理由 | `cover-dwc3-v9-draft.txt` | ① 生成 v9 补丁并重跑门禁 ② 批准投递 |
| **B** | wl2868c `[PATCH v9 2/2]` driver（回复 `<sashiko-outbox-201353@kernel.org>`） | ① `devm_regulator_get_enable("vsys")` 提到 reset 释放**之前**（并让 devres 逆序 = 先拉 reset 再关 supply）；② `vsys` 取不到时回落 `vin7`（`devm_regulator_get_enable_optional`）并保证其一常开；③ 仅在 `value & WL2868C_SYS_ENABLE` 时才用 `LDO_ENABLE` 播种 `chip->enabled` | `cover-wl2868c-v10-draft.txt` | 同上 |
| **C** | wl2868c `[PATCH v9 1/2]` binding（回复 `<sashiko-outbox-201357@kernel.org>`） | ① example 加 `vin12-supply = <&vreg_vin12>`（provider 节点不加，遵 Rob）；② `F: drivers/regulator/wl2868c-regulator.c` 从 1/2 移到 2/2 的 MAINTAINERS hunk | 同 B 的 cover（一并出 v10） | 同上 |
| **D** | M10 ADSP fastrpc（回复 `<sashiko-outbox-202531@kernel.org>`） | 补 `Fixes:` trailer（**先核对 hash 与 subject**，本机无该提交） | `m10-v2-note-draft.txt` | 同上 |
| **E** | 等人工评审 | v8/v9/M10 零人工标签；**不 ping**（§7 口径：不单独催） | — | 否 |

**本轮不建议做的**：追发 ping、改订阅、给 sashiko 单独发「谢谢」类回信（无信息量，且会被当噪声）。

---

## §3 复跑命令

```bash
# 1) 只读头表（EXAMINE + PEEK；输出 /tmp/laneB/hdr.json）
python3 /tmp/laneB/scan.py 25-Oct-2026
# 2) 窗口内外部回信（10 封）
python3 - <<'EOF'
import json,email.utils,datetime
d=json.load(open('/tmp/laneB/hdr.json'))
def dt(s):
    x=email.utils.parsedate_to_datetime(s); return x if x.tzinfo else x.replace(tzinfo=datetime.timezone.utc)
b=datetime.datetime(2026,11,5,2,40,tzinfo=datetime.timezone.utc); O='xiaqinghuan@mail.ustc.edu.cn'
for r in sorted([r for r in d if dt(r['date'])>b and O not in r['frm'] and O in r['irt']+r['refs']],
                key=lambda r: dt(r['date'])):
    print(dt(r['date']).astimezone(datetime.timezone.utc), r['frm'][:34], '|', r['subj'][:60], '|', r['mid'])
EOF
# 3) 正文（示例：dwc3 v8 1/3 的 sashiko 回信）
python3 /tmp/laneB/body.py '<sashiko-outbox-201360@kernel.org>'
# 4) patchwork 状态
curl -s 'https://patchwork.kernel.org/api/1.2/patches/?submitter=xiaqinghuan@mail.ustc.edu.cn&since=2026-11-04T00:00:00&per_page=80'
# 5) lore 归档
python3 ~/.local/bin/lore-query.py "https://lore.kernel.org/linux-usb/?q=20261106114208.987284-1-xiaqinghuan@mail.ustc.edu.cn"
```

DONE-MAILTRIAGE-20261108
