# 上游邮件增量分诊 — 2026-11-11（b 轮，窗口 → 2026-11-11T08:08Z）

> 基线：`reports/mail-status-20261111.md`（窗口止 11-11 上午，含 dwc3 v8 / wl2868c v9 / M10 v2 三分表）。
> 本轮**窗口** = 2026-11-10T00:00Z → 2026-11-11T08:08Z（最后一次 IMAP 扫描时刻）；
> 另给「11-11 当日切片」= 2026-11-11T00:00Z → 08:08Z。
> 只读：IMAP 全用 `EXAMINE` + `BODY.PEEK[...]`（无 STORE/COPY/MOVE/EXPUNGE）；**零发信**
> （未调 `git send-email` / `send-mail-ustc.py`）、未动设备、未改任何 SSOT 或版本账、无 git commit。
> 凭据只从 keyring 取（`keyring.get_password('smtp', …)`，未打印、未落盘）。

## §1 收信统计

扫描器：本轮现写的只读脚本 `/tmp/mailio-scan.py`（每个文件夹重新登录，避开「Coremail 同连接切夹返回
`BAD [Request not ending with]`」的坑，见 `reports/mail-triage-20261109.md` §1b-3）。`SINCE 08-Nov-2026`，
INBOX 2685 + Junk 37 + Sent Items 2 = **2724 行 / 2456 唯一 Message-ID**（list 副本 + 直接 Cc 副本会重复入箱）。

| 项 | 值 | 说明 |
|---|---|---|
| 窗口内行数 | **1224** | `Date` 落在 2026-11-10T00:00Z–11-11T08:08Z |
| 窗口内唯一 Message-ID | **1155** | 去重口径同上（INBOX 1152 + Junk 3） |
| 外部回信（给我方线程） | **3 条 / 3 个唯一 MID** | 判据 = `In-Reply-To`/`References` 含 `xiaqinghuan@mail.ustc.edu.cn` 或 From 是我方；三条**全部**是 To 只有我（非 list 直投） |
| 其中人类署名 | **2**（Rob Herring ×2） | 另 1 条 = sashiko-bot |
| 退信（mailer-daemon/postmaster/undeliverable） | **0** | `grep -iE 'mailer-daemon|postmaster|undeliver'` 全窗口 0 命中 |
| Junk 命中我方线程 | **0** | Junk 37 行里 3 行落窗口，均非我方线程 |
| 我方外发（Sent Items） | **2** | 11-10T02:31Z M10 v2、11-11T03:57Z M10 v3（与 `out/mail-20261011*` 记录一致） |
| **11-11 当日切片** | 202 行 / 195 唯一 MID | 与我方相关的只有 **1 条 = 我们自己发的 M10 v3**（03:57Z）⇒ **v3 尚无任何回复** |

复现：
```sh
timeout -k 20 600 python3 /tmp/mailio-scan.py 08-Nov-2026   # 写出 /tmp/mailio-hdr.json
python3 - <<'EOF'   # 去重 + 窗口过滤（原始数字见上表）
import json,email.utils,datetime
rows=json.load(open('/tmp/mailio-hdr.json'))
EOF
```
> 注：`read-mail-ustc.py --days 4` 已按要求跑过（`rc=0`，输出 `/tmp/mailio-raw.txt`，152 行），
> 但它是**逐封列表 + 每夹 limit 40**，INBOX 在窗口内有 3152 封（SINCE 07-Nov），既不能给去重计数也不能给退信计数
> ⇒ 统计改用上面同一个 IMAP、同一套 `BODY.PEEK` 头的自写扫描（**没有**换协议、没有换账号）。

## §2 回信逐条（窗口内全部 3 条外部回信）

| # | 发件人 | 日期(UTC) | MID | 一句话要点 |
|---|---|---|---|---|
| 1 | sashiko-bot | 2026-11-10 02:41:29 | `<sashiko-outbox-206060@kernel.org>` | 对 **M10 v2** 两条 Low：① v2 的 changelog 段必须放到 `---` 线下（否则进永久 commit log）；② `Fixes:` 用 12 位哈希 `be9d54c35312`。原文另含 v2 正文里那段的逐行引用（证据见 §3） |
| 2 | Rob Herring | 2026-11-10 16:36:40 | `<20261110163640.GA85824-robh@kernel.org>` | 对 **dwc3 v8 0/3** 两点：① `port-select-gpios` → 「Use the gpio mux binding.」；② 「ports are for separate data streams. Endpoints are for mux'ed data streams. This looks like the latter, so **port@0 should have 2 endpoints and port@2 dropped**.」 |
| 3 | Rob Herring (Arm) | 2026-11-10 19:27:44 | `<179433886406.1494254.12130093452944735192.robh@kernel.org>` | 对 **mdss v3 1/3**（`<20261102055026.438521-2-…>`，2026-11-02 发出，**上一份状态报告未登记这条系列**）：整封正文只有一行 **`Acked-by: Rob Herring (Arm) <robh@kernel.org>`**（patchwork 侧同一时刻的 comment 原文可复现，见 §4） |

**额外（窗口外但属欠账）**：`Abel Vesa <abel.vesa@oss.qualcomm.com>` 2026-11-02T13:17:55Z 对
**mdss v3 3/3** 的回信整封只有一行 **`Reviewed-by: Abel Vesa <abel.vesa@oss.qualcomm.com>`**
（`/all/buaeo5m3ozihgl5t6767jvu72umwbzqx2debegmzvkuigwwqki@zbtoarlnnihe/raw`）。
上一份 `mail-status-20261111.md` §6 的「只有 wl2868c 1/2 有 tag」**不成立**，见 §3 表。

## §3 lore 原文核对表

抓取器：`scripts/lore-fetch-raw.py`（自动过 Anubis PoW，`difficulty=4`，本轮 1 次挑战已解）；
线程成员用 `/all/<mid>/t.mbox.gz`（**必须按二进制取再 `gzip.decompress`**，用文本模式会毁掉 gzip 流）。

```sh
python3 scripts/lore-fetch-raw.py all \
  20261111035731.940893-1-xiaqinghuan@mail.ustc.edu.cn \
  20261110023153.84262-1-xiaqinghuan@mail.ustc.edu.cn \
  20261107015014.22374-{1,2,3}-xiaqinghuan@mail.ustc.edu.cn \
  20261106114208.987284-{1,2}-xiaqinghuan@mail.ustc.edu.cn \
  20261102055026.438521-{1,2}-xiaqinghuan@mail.ustc.edu.cn -o /tmp/lore-m1111
# → 9/9 全部 200，字节数 7421–20029 B
```

| Message-ID | 归档 | 线程内封数 | 最新一封(UTC) | 评审标签（原文行） |
|---|---|---|---|---|
| `<20261111035731.940893-1-…>` **M10 v3** | ✅ 进 archive（7539 B） | 6（本线程 v1→v3 单线程，`In-Reply-To` 指向 v1 cover） | 2026-11-11 03:57:31（我方 v3 本身） | 无 |
| `<20261110023153.84262-1-…>` M10 v2 | ✅（7421 B） | 同上 | 2026-11-10 02:41:29（sashiko） | 无；patchwork 已置 `superseded` |
| `<20261107015014.22374-1/2/3-…>` wl2868c v9 0/2+1/2+2/2 | ✅ 3/3（8242/9686/16339 B） | 9（含 v8 三封） | 2026-11-09 20:13:59（sashiko，对 2/2） | **1/2 = `Reviewed-by: Rob Herring (Arm) <robh@kernel.org>`**（`<179423604384.3146607.887205491604475162.robh@kernel.org>` raw 正文唯一一行） |
| `<20261106114208.987284-1/2-…>` dwc3 v8 0/3+1/3 | ✅ 2/2（20029/11949 B） | 7 | 2026-11-10 16:36:40（Rob） | **无**（Rob 那封是 changes-requested，不是 tag） |
| `<20261102055026.438521-1/2-…>` mdss v3 0/3+1/3 | ✅ 2/2（8219/7408 B） | 6 | 2026-11-10 19:27:44（Rob ack） | **1/3 = `Acked-by: Rob Herring (Arm)`**；**3/3 = `Reviewed-by: Abel Vesa`**（11-02T13:17Z）；**2/3 无 tag** |

M10 v3 正文逐条对账（`/tmp/lore-m1111/1.raw`，与本地补丁一致）：
- `---` 线下才是 changelog ⇒ 已满足 sashiko/Konrad 的 Low：
  ```
  Signed-off-by: Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>
  ---
  v3: move the changelog below the --- line, use a 12-character Fixes hash and
      place the new property after memory-region, as requested in review.
  v2: add the Fixes tag requested in the sashiko review
  ```
- `Fixes: be9d54c35312 ("arm64: dts: qcom: sm8750: add ADSP fastrpc-compute-cb nodes")`（12 位）
- hunk：`+ qcom,non-secure-domain;` 落在 `memory-region` 之后、`qcom,vmids` 之前。

## §4 patchwork 现查表（上一轮欠账，本轮补上）

API：`https://patchwork.kernel.org/api/1.2/patches/?submitter=xiaqinghuan%40mail.ustc.edu.cn&since=2026-11-01T00:00:00&per_page=100&order=-date`
→ **HTTP 200，70 条**（不加 `order=-date` 只回最早 5 条，是个坑）。`tags` 字段在**全部 70 条上都是空 `{}`**
（patchwork 不把 Acked-by/Reviewed-by 解析进 `tags`，tag 只存在 comment 正文里 ⇒ 判接收只能读 comment）。

| 系列 | patchwork 条目（project:id） | state | 是否有 review tag（comment 证据） | applied? |
|---|---|---|---|---|
| **M10 v3** | arm-msm `14971025` | `new` | 无 comment | `commit_ref=None`、`archived=False` |
| M10 v2 | arm-msm `14966246` | `superseded`（被 v3 顶掉） | 无 | — |
| M10 v1 | arm-msm `14959877` | `superseded` | 无 | — |
| **wl2868c v9 1/2** | arm-msm `14959745` / devicetree `14959749` | `handled-elsewhere` / **`not-applicable`** | **有**：`14959745` 的 comment 2026-11-09T14:54:04 `robh@kernel.org`（正文即 `Reviewed-by: Rob Herring (Arm)`） | `commit_ref=None` |
| wl2868c v9 2/2 | arm-msm `14959744` / devicetree `14959748` | 均 `handled-elsewhere` | 无（sashiko 三条 Medium 挂在 lore 线程，未进 patchwork comment） | `commit_ref=None` |
| **dwc3 v8 1/3** | linux-usb `14957383` / devicetree `14957399` | `new` / `needs-ack` | **无 comment**（Rob 的结构性意见回在 **cover 0/3** 上，cover 不是 patch，patchwork 不挂） | `commit_ref=None` |
| dwc3 v8 2/3、3/3 | linux-usb `14957384`、`14957385` | 均 `new` | 只有 sashiko comment（11-06 11:47:57 / 11:52:05） | `commit_ref=None` |
| **mdss v3 1/3** | dri-devel `14931320` / arm-msm `14931323` / devicetree `14931334` | `new` / `handled-elsewhere` / `not-applicable` | **有**：`14931320` comment 2026-11-10T19:27:44 `robh@kernel.org`（=Ack） | `commit_ref=None`、`archived=True` |
| mdss v3 2/3 | dri-devel `14931321` / arm-msm `14931324` | `new` / `handled-elsewhere` | 无 | — |
| mdss v3 3/3 | dri-devel `14931322` / arm-msm `14931325` | `new` | **有**：`14931322` comment 2026-11-02T13:17:55 `abel.vesa@oss.qualcomm.com`（=Reviewed-by） | — |

**结论层判据**：`state=accepted` 一个都没有，`commit_ref` 全为 `None` ⇒ **四系列都未进任何 maintainer 树**；
`handled-elsewhere` 只表示「该系列被拆到别的 project」，不是接收。
另：`dwc3 v8 1/3` 的 devicetree 副本仍是 `needs-ack`，而 Rob 已在 lore 上给出**结构性 changes-requested**
⇒ **patchwork state 会低估进展**，判读必须以 lore comment 为准（这条以后再遇到「patchwork 说 needs-ack，是不是没事」直接引用本节）。

## §5 逐系列处置 + 需批准项

| 系列 | 最新判定（本轮证据） | 下一步 | 需用户批准? |
|---|---|---|---|
| **mdss v3（0/3–3/3）**（上一份报告漏登记） | 🟢 **最接近可收**：1/3 `Acked-by: Rob Herring`（11-10 19:27Z）+ 3/3 `Reviewed-by: Abel Vesa`（11-02T13:17Z）；2/3（drm/msm 代码）**无 tag、无新回信** | ① 若要继续：等多媒体/Dmitry 对 2/3 的意见，或按「已获 DT Ack + DTS Reviewed」发**一次 ping**（不建议，`TASKS/README.md:149`「agent 不等回复」）；② 若 2/3 有意改，则 1/3 的 Ack 与 3/3 的 Reviewed 会作废 | 否（本轮无动作）；若发 ping/新版本 ⇒ **是** |
| **M10 v3** | 🟡 **在等**：11-11T03:57Z 投出，lore 已归档（7539 B，`In-Reply-To` 保持 v1 线程），patchwork `new`；**至今 0 回复**（11-11 切片 202 封里无一封相关）；v2 已 `superseded` | 无需动作；v3 已逐条满足 Konrad(11-09)+sashiko(11-10) 两条 Low | 否 |
| **wl2868c v9 1/2** | ✅ **已被接受（DT 侧）**：Rob `Reviewed-by`（11-09 14:54Z）；patchwork devicetree 副本被置 `not-applicable`（= 该副本不再跟） | 保持；**若 v10 动 1/2 则 tag 作废** | 否 |
| **wl2868c v9 2/2 driver** | 🔴 **需回应**：sashiko 2026-11-09 20:13:59Z 三条 Medium（reset 早于 vsys 使能 / 只有 `vin7-supply` 的板子 / `chip->enabled` 未校验 SYS_EN bit7）仍未处理，与 `reports/mail-triage-20261109.md` §2 B1–B3 同源 | 出 **v10**（B1–B3 + 1/2 的 C1–C2 一并） | **是**（新版本） |
| **dwc3 v8 0/3** | 🔴 **需回应（结构性 changes-requested）**：Rob 11-10 16:36Z ⇒ `port@0` 双 endpoint + 删 `port@2` + `port-select-gpios`→gpio mux | **本轮已出 v9 binding 草案并跑门禁**（§6 / `patches/upstream/dwc3-v9-draft-20261111/`）：`dt-doc-validate` rc=0、`make dt_binding_check` rc=0、正样例 PASS、三个负样例全被拒 | **是**（v9 = 新版本；且 driver/DTS 还没改完，暂不可发） |

作废声明（沿用并强化）：`reports/mail-triage-20261109.md` §2-A3「补 `port@2`」**作废**
（被 Rob 11-10T16:36Z 直接否掉）；`TASKS/README.md:1040` 里「两个 HS 连接器 = 两个 port（`port@0`+`port@2`）」
**同样作废**（总管需改 SSOT，我不改）。

### 需用户批准的动作清单（按 §7 逐系列放行；本轮全部未执行）

1. **wl2868c v10**（1/2 + 2/2，落 B1–B3 + C1–C2；1/2 改动会作废 Rob 的 Reviewed-by）。
2. **dwc3 v9**（binding + driver + DTS 三件）；当前只有 binding 草案，driver/DTS 未动 ⇒ **暂不具备投递条件**。
3. 任何**纯回信**（不带新版本）—— 同属发信，需批准。
4. **不建议**：三系列 resend/ping（M10 v3 才 4 h、wl2868c 最新意见 2 天、dwc3 已在本轮出草案）。

## §6 dwc3 v9 binding 返工草案（零投递备料，不需批准）

产物目录 `patches/upstream/dwc3-v9-draft-20261111/`：`README.md`（Rob 意见 ↔ v8 yaml 行号差异表）、
`snps,dwc3-common.v9.yaml`（草案全文 544 行）、`v9-0001-…patch`（对上游 pristine 的 diff，+118/−2）、
`gates/`（6 个门的原始日志 + 4 个测试 dts/dtb）。

关键改动（行号 = **v8 已发版本**的 544 行 yaml）：
- `:77-80` 那句「so two connectors are two ports, not two endpoints of one port / lands on port@2」**整段删除**；
  `:81` `required: [port@0, port@2]` → `ports: required: [port@0]`；
- `hs-port` 改为**一个 port 两个 endpoint**：`required: ['#address-cells','#size-cells', endpoint@0, endpoint@1]`，
  两个 endpoint 各 `required: [reg]`（顺带消化 sashiko M2 对「任意编号 pattern」的批评）；
- `:136-142` `port-select-gpios` → `mux-controls: maxItems 1`（→ `compatible = "gpio-mux"` 的 mux controller，
  `#mux-control-cells = <0>`，见 `Documentation/devicetree/bindings/mux/gpio-mux.yaml`）；`:64` 的 `if` 条件同步改；
- 两个 connector 的 mux 状态互斥仍由 `oneOf` 强制（作用对象改为同一 port 的两个 endpoint）。

门禁（树 `build/m3v2-7.3rc7`，跑完 `git checkout --` 还原，`git status --porcelain` 已核实为空）：

| 门 | 结果 |
|---|---|
| `dt-doc-validate --verbose` | **rc=0**，无输出 |
| `make dt_binding_check DT_SCHEMA_FILES=<fd>` | **rc=0**，SCHEMA/CHKDT/LINT/STYLE 无诊断 |
| 正样例（双 endpoint + mux-controls + gpio-mux） | **PASS**（仅 root-node 缺 `compatible/model` 的 harness 噪声） |
| 负样例①两 endpoint 同 `mux-state` | **被拒** `'oneOf' conditional failed` |
| 负样例②只剩一个 endpoint | **被拒** `'endpoint@1' is a required property` |
| 负样例③legacy v8 形状（port@2+port-select-gpios） | **被拒** `'#address-cells' is a required property` 等 |

## §6b 未完成项

1. **driver（3/3）与 DTS 未改**：`drivers/usb/dwc3/drd.c` 仍走 `gpiod_get`，需换 `devm_mux_control_get` +
   `mux_control_select(mux, endpoint->mux_state)`；`mux_control_select` 持锁到 `mux_control_deselect`，
   与 role-switch 回调（可能中断上下文）的兼容性**未评估**。因此 **v9 目前不可投**。
2. **wl2868c v10 的 driver 改动未做**（本轮按派工只做最便宜的一件 = dwc3 binding 草案）。
3. **`TASKS/sessions/` 新记录未写**：本轮只写本报告与草案目录（派工单指定产出），§7 口径/状态行由总管并入。
4. **`TASKS/README.md:1040` 的「两 port」结论已作废但未改**（SSOT 归总管）。
5. **mdss v3 之前的收信状态无从追溯**：上一份报告未登记该系列，故「Abel 的 Reviewed-by 是否曾被分诊过」查不到
   （本地 `reports/` 无 11-02–11-06 的 mdss 分诊记录，本轮只补了 tag 事实）。
6. lore `web_fetch` 仍不可用（Anubis，`PITFALLS #444`），本轮全程用仓库脚本 + `lore-query.py` 原语；
   线程成员用 `t.mbox.gz`（二进制读取 + `gzip.decompress`）—— 这是本轮新增的可复现路径。
