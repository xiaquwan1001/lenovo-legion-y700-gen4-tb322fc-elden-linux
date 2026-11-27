# SENT —— SM8750 TNOC periphid v1（2026-11-27T11:31Z / 19:31 CST）

- 发件人：Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>（USTC smtp 通道）
- 收件人：`TO` andersson@kernel.org；`Cc` konradybcio@kernel.org, robh@kernel.org,
  krzk+dt@kernel.org, conor+dt@kernel.org, linux-arm-msm@vger.kernel.org,
  devicetree@vger.kernel.org, linux-kernel@vger.kernel.org
- 日志：`logs/sent-20261127-193158.txt`

| # | Subject | Message-ID | Result |
|---|---|---|---|
| 0/2 | [PATCH 0/2] arm64: dts: qcom: sm8750: describe the TNOC AMBA periphid | `<20261127113158.932414-1-xiaqinghuan@mail.ustc.edu.cn>` | 250 |
| 1/2 | dt-bindings: arm: qcom,coresight-tnoc: allow the AMBA periphid | `<20261127113158.932414-2-…>` | 250 |
| 2/2 | arm64: dts: qcom: sm8750: describe the TNOC AMBA periphid | `<20261127113158.932414-3-…>` | 250 |

## lore 复核（2026-11-27T12:30Z 实测回填 —— **归档实证**）

**结论**：cover + 1/2 + 2/2 **三封全部进 lore 归档**，Subject **逐字未改写**，成串；patchwork **两个 project 均已摄取**
（`linux-arm-msm` 两封 `new`；`devicetree` 副本 `1/2 needs-ack` / `2/2 handled-elsewhere`）。
**已有 1 条回复**：sashiko AI 评审 bot 于 **2026-11-27T11:41:59Z** 在 `devicetree` 列表回了一封，1 条 [Low] 意见 ——
建议补 `Fixes: ebd1eb365cae ("arm64: qcom: dts: sm8750: add coresight nodes")` 尾标。**两封均未进** linux-next / torvalds（v7.4-rc4 现查）。

### 可用端点（关键：UA 决定命运）

| 端点 | HTTP | 特征 |
|---|---|---|
| `GET /all/<cover-MID>/t.mbox.gz`（**默认 curl UA**） | **200** | `application/gzip` 8214 B → 24495 B mbox，**4 封**（我们 3 + sashiko 1） ✔ |
| 同上换成浏览器 UA | 200 | Anubis 挑战页（7746 B，非 JSON/非 mbox） |
| `GET /all/<MID>/`·`/raw`·`/t/` | **403** | `nginx` 裸 403，146 B |
| `GET /linux-arm-msm/<cover-MID>/t.mbox.gz` | 200 | 6453 B（主列表命中） |
| `GET /lkml/<cover-MID>/t.mbox.gz`（`/linux-kernel/` 302→`lkml`） | 200 | 6473 B |
| `GET /devicetree/<任意 dt 补丁 MID>/t.mbox.gz` | 404 | **路径不可用**（拿上游同名单 jie.gan 补丁也 404）⇒ 不能据此判未投 |
| `GET /all/<伪造 MID>/t.mbox.gz` | 404 | 标定：403≠不存在，404 才是 |

证据串（实测）：
```
$ curl -sS -o tnoc.mbox.gz -w '%{http_code} %{size_download} %{content_type}\n' \
    https://lore.kernel.org/all/20261127113158.932414-1-xiaqinghuan@mail.ustc.edu.cn/t.mbox.gz
200 8214 application/gzip
$ gunzip -c tnoc.mbox.gz | grep -c '^From mboxrd'   -> 4
Subject: [PATCH 0/2] arm64: dts: qcom: sm8750: describe the TNOC AMBA periphid  (19:31:56 +0800, List-Id linux-arm-msm)
Subject: [PATCH 1/2] dt-bindings: arm: qcom,coresight-tnoc: allow the AMBA periphid (19:31:57, In-Reply-To <...-1->)
Subject: [PATCH 2/2] arm64: dts: qcom: sm8750: describe the TNOC AMBA periphid (19:31:58, In-Reply-To <...-1->)
Message-ID: <sashiko-outbox-237264@kernel.org>  From: sashiko-bot@kernel.org  11:41:59 +0000  List-Id: <devicetree.vger.kernel.org>
Subject: Re: [PATCH 2/2] arm64: dts: qcom: sm8750: describe the TNOC AMBA periphid
```

### patchwork（**已摄取**）

| 对象 | id | state | 链接 |
|---|---|---|---|
| series（`linux-arm-msm`, project 92） | **1224353** | v1, total 2, `received_all: true` | <https://patchwork.kernel.org/series/1224353/> |
| cover（arm-msm） | 14177380 | cover（API 1.2 不记 state） | <https://patchwork.kernel.org/project/linux-arm-msm/cover/20261127113158.932414-1-xiaqinghuan@mail.ustc.edu.cn/> |
| 1/2 dt-bindings | **15029446** | **new** | <https://patchwork.kernel.org/project/linux-arm-msm/patch/20261127113158.932414-2-xiaqinghuan@mail.ustc.edu.cn/> |
| 2/2 dts sm8750 | **15029445** | **new** | <https://patchwork.kernel.org/project/linux-arm-msm/patch/20261127113158.932414-3-xiaqinghuan@mail.ustc.edu.cn/> |
| series（`devicetree`, project 429） | **1224354** | v1, total 2, `received_all: true` | <https://patchwork.kernel.org/series/1224354/> |
| cover（dt） | 14177381 | cover | <https://patchwork.kernel.org/project/devicetree/cover/20261127113158.932414-1-xiaqinghuan@mail.ustc.edu.cn/> |
| 1/2 dt-bindings（dt 副本） | **15029448** | **needs-ack** | <https://patchwork.kernel.org/project/devicetree/patch/20261127113158.932414-2-xiaqinghuan@mail.ustc.edu.cn/> |
| 2/2 dts sm8750（dt 副本） | **15029447** | **handled-elsewhere** | <https://patchwork.kernel.org/project/devicetree/patch/20261127113158.932414-3-xiaqinghuan@mail.ustc.edu.cn/> |

> `handled-elsewhere` 是 patchwork 的**自动分类**（与上面 sashiko 的 `Fixes:` 意见无关），不代表已被接。

### 进树状态（**未进**，2026-11-27T12:35Z 查 cgit `plain`）

- `arch/arm64/boot/dts/qcom/sm8750.dtsi`（torvalds **与** linux-next 均 `v7.4-rc4`）：`tn@109ab000` 节只到
  `clocks/clock-names`，**无 `arm,primecell-periphid`**；`grep -n 'tn@109ab000' -A12 | grep periphid` → 无输出。

### ⚠ 重复工作告警（必读）

上游 **已有同改动的在评审线程**：Jie Gan（`jie.gan@oss.qualcomm.com`）**2026-11-18 15:01+0800** 发
`[PATCH 0/4] Fix the TraceNoC probe issue on QCOM platform`，其 `[3/4] arm64: dts: qcom: sm8750: add periphid for traceNoC`
往 **同一个** `tn@109ab000` 加的是**同一个值** `arm,primecell-periphid = <0x000f0c00>`；`[1/4] dt-bindings: arm: coresight-tnoc: Allow arm,primecell-periphid`
覆盖本系列 1/2 的绑定改动。该系列**已有 Suzuki K Poulose（11-20）与 Abel Vesa 回复**（patchwork `linux-arm-msm` state = `new`，
[lore 线程 11 封](https://lore.kernel.org/all/20261118-fix-tracenoc-probe-v1-0-0298dc5f05ac@oss.qualcomm.com/))。
⇒ **本系列（B）与它正面重叠**，v2 前需决定：撤回 / 降为「给 Jie Gan 系列补 SM8750 数据点」/ 明确差异化（例如只提交未被其覆盖的部分）。
详见 `reports/upstream-sent-backfill-20261127.md` §5。

> 复核脚本化提示：`curl -sS https://lore.kernel.org/all/<MID>/t.mbox.gz`（**别带浏览器 UA/header**，否则吃 Anubis）；
> 判命中用 gzip magic + `grep -c '^From mboxrd'`。完整逐项证据 = `reports/upstream-sent-backfill-20261127.md`。

## 后续：自认 superseded（2026-11-27T13:23Z / 21:23 CST，用户放行后发出）

- 裁决：用户 2026-11-27 晚选「① 只回自己线程自认 superseded」。
- 事实：Jie Gan `<jie.gan@oss.qualcomm.com>` 的 `[PATCH 0/4] Fix the TraceNoC probe issue on QCOM platform`
  （2026-11-18，patchwork series **1214623**：`14995780` binding 放开 / `14995781` kaanapali / `14995782` sm8750 / `14995783` glymur）
  与我们这两封**同节点同值**（`tn@109ab000` + `arm,primecell-periphid = <0x000f0c00>`）。父代理独立 pull 了该 series 四封确认。
- 发出件：`out/mail-20261127/re-superseded-sm8750-tnoc-periphid.txt`（To: Jie Gan；Cc: 原线程维护者 + 列表；
  含 AI 披露；附带一条可复用数据 = 本板加了该属性后 CoreSight AMBA 未绑定 28→0）。**未发 v2**。
- Message-ID `<179578582079.1094405.15142623585619157958@mail.ustc.edu.cn>`（SMTP 250）；
  lore 线程复核：`GET /all/<该 MID>/t.mbox.gz` = **200，10277 B，线程 5 封**（cover + 1/2 + 2/2 + sashiko `[Low]` + 本回帖）。
- 草稿原件留档：`DRAFT-superseded-reply.txt`（与实发件同文，仅缺首部）。
