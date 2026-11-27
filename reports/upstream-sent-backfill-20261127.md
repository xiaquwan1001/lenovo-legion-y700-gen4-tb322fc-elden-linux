# 上游投递 SENT.md 按 MID 复核回填（2026-11-27T12:30Z）

> 对象：2026-11-27T11:31Z 两封上游投递（各 3×250）
> - **A** = `coresight-moduletable-20261127`（coresight CTCU/TPDA `MODULE_DEVICE_TABLE`）
> - **B** = `sm8750-tnoc-periphid-20261127`（SM8750 TNOC AMBA periphid）
>
> 范围：只读外网 + 回填两个 `SENT.md` + 本报告；未改其它仓库文件、未动 patch 内容、未对外发信。
> 判定三态：**归档实证**（拿到归档本身）/ **仅旁证**（第三方页面/API 提到，但未拿到归档本体）/ **不可核**。

---

## 0. 一页结论

| 问题 | A（coresight） | B（TNOC） |
|---|---|---|
| 三封是否进 lore 归档 | **归档实证**：3/3 命中（`/t.mbox.gz` 200 gzip，解出 3 封） | **归档实证**：3/3 命中（4 封 = 我们 3 + sashiko 1 回复） |
| Subject 是否被改写 | **未改写**（与 `SENT.md` 表格逐字一致） | **未改写** |
| 线程是否成串 | **成串**：两封 `In-Reply-To`/`References` → cover | **成串**：同 |
| patchwork 是否摄取 | **已摄取**：series 1224350，1/2=`15029441` **new**，2/2=`15029442` **new** | **已摄取**：`linux-arm-msm` series 1224353（两封 **new**）+ `devicetree` series 1224354（`needs-ack` / `handled-elsewhere`） |
| 是否进 linux-next / torvalds | **未进**（两树均 `v7.4-rc4` 现查） | **未进**（同） |
| 回复 | 截至 12:30Z **无** | **1 封**：sashiko bot 11:41:59Z 提 1 条 [Low]（补 `Fixes:` 尾标） |
| 额外风险 | — | **与 Jie Gan（Qualcomm）2026-11-18 的 [PATCH 0/4] 正面重叠**（同节点同值同绑定），该系列已有维护者回复 → 见 §5 |

**方法论要点（本轮最大收获）**：lore 的可达性**不由路径决定，由 User-Agent 决定**。
默认 `curl` UA 打到 `/all/<MID>/t.mbox.gz` → **200 真 gzip**；同一路径带浏览器 UA/完整 header → **200 Anubis 挑战页**（看起来成功，其实是 HTML）。
HTML 路径（`/all/<MID>/`、`/raw`、`/t/`）在默认 UA 下一律 **nginx 403**。
⇒ **凡用 HTTP 200 判「已归档」的脚本都是假的**；必须判 gzip magic + mbox 封数。这条已写进两个 `SENT.md` 的复核提示。

---

## 1. 端点矩阵（raw 证据）

MID：
- A cover = `<20261127113137.931578-1-xiaqinghuan@mail.ustc.edu.cn>`
- B cover = `<20261127113158.932414-1-xiaqinghuan@mail.ustc.edu.cn>`
- 伪造标定 MID = `<20260101000000.999999-1-nobody@example.invalid>`

### 1.1 失败端点原文（浏览器 UA，`Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0`）

```
### https://lore.kernel.org/all/20261127113137.931578-1-xiaqinghuan@mail.ustc.edu.cn/
HTTP 200 | text/html; charset=utf-8 | 7769B
<!doctype html><html lang="en"><head><title>Making sure you&#39;re not a bot!</title>
<link rel="stylesheet" href="/.within.website/x/xess/xess.min.css?cachebuster=v1.26.2">

### https://lore.kernel.org/r/20261127113137.931578-1-xiaqinghuan@mail.ustc.edu.cn
HTTP 302 | text/html | 138B     (→ /all/<MID>/ ，随后仍吃 Anubis)

### https://lore.kernel.org/all/20261127113137.931578-1-xiaqinghuan@mail.ustc.edu.cn/raw
HTTP 200 | text/html; charset=utf-8 | 7746B   （Anubis 挑战页，不是 patch 正文！）

### https://lore.kernel.org/all/20261127113137.931578-1-xiaqinghuan@mail.ustc.edu.cn/t/
HTTP 200 | text/html; charset=utf-8 | 7746B   （Anubis）

### https://lore.kernel.org/all/20260101000000.999999-1-nobody@example.invalid/     ← 伪造 MID
HTTP 200 | text/html; charset=utf-8 | 7769B   （Anubis，与真 MID 完全同形 ⇒ 200 无判别力）

### https://lore.kernel.org/all/?q=931578-1-xiaqinghuan
HTTP 200 | text/html; charset=utf-8 | 7746B   （Anubis）

### https://lore.kernel.org/linux-arm-kernel/?q=932414
HTTP 200 | text/html; charset=utf-8 | 7768B   （Anubis）

### https://lore.kernel.org/linux-arm-msm/?q=tnoc+periphid
HTTP 200 | text/html; charset=utf-8 | 7769B   （Anubis）
```

### 1.2 失败端点原文（**默认** curl UA）

```
### https://lore.kernel.org/all/20261127113137.931578-1-xiaqinghuan@mail.ustc.edu.cn/
HTTP 403 | text/html; charset=utf-8 | 146B
<html><head><title>403 Forbidden</title></head><body><center><h1>403 Forbidden</h1></center><hr><center>nginx</center></body></html>

### 同 URL + /raw        → HTTP 403  146B  同为 nginx 裸 403
### 同 URL + /t/         → HTTP 403  146B
### https://lore.kernel.org/all/ （首页）→ HTTP 403  146B
### 伪造 MID /all/<...>/     → HTTP 403  146B   ← 与真 MID 同码 ⇒ 403 也不是「不存在」信号
```

加 `--noproxy '*'` 直连（绕开 `http_proxy=127.0.0.1:7890`）结果不变：`403`。
⇒ 结论：**403 是 lore 对「无 Anubis cookie 的 HTML 访问」的统一处置，与消息是否存在无关**。上一轮 `SENT.md` 里
「`/all/<MID>/` 403 (Anubis)」的描述正确，但当时**没有**找到一个能穿透的端点，本轮找到了（§1.3）。

### 1.3 成功端点（默认 curl UA，`Accept` 不改）

```bash
$ curl -sS -o ctc.mbox.gz -w '%{http_code} %{size_download} %{content_type}\n' \
    https://lore.kernel.org/all/20261127113137.931578-1-xiaqinghuan@mail.ustc.edu.cn/t.mbox.gz
200 6951 application/gzip

$ curl -sS -o tnoc.mbox.gz -w '%{http_code} %{size_download} %{content_type}\n' \
    https://lore.kernel.org/all/20261127113158.932414-1-xiaqinghuan@mail.ustc.edu.cn/t.mbox.gz
200 8214 application/gzip

$ curl -sS -o /dev/null -w '%{http_code}\n' \
    https://lore.kernel.org/all/20260101000000.999999-1-nobody@example.invalid/t.mbox.gz
404                      # ★ 标定：伪造 MID 在**同一端点**得 404 ⇒ 上面的 200 是真命中

$ file ctc.mbox.gz   → gzip compressed data, original size 19534
$ file tnoc.mbox.gz  → gzip compressed data, original size 24495
$ gunzip -c ctc.mbox.gz  | grep -c '^From mboxrd'   → 3
$ gunzip -c tnoc.mbox.gz | grep -c '^From mboxrd'   → 4
```

`/t.mbox.gz` 挂在**任一线程成员**的 MID 上都返回整条线程（实测 A 的 `-3` 与 `-1` 都是 6951 B；B 的 `-2` 是 8214 B），
所以只需 cover MID 即可。

### 1.4 逐列表可达性（同一 `/t.mbox.gz` 机制）

| 列表路径 | A | B | 判读 |
|---|---|---|---|
| `/all/` | 200 · 6951 B | 200 · 8214 B | **总归档命中** |
| `/linux-arm-kernel/` | 200 · 6932 B | — | A 主列表命中 ✔ |
| `/linux-arm-msm/` | — | 200 · 6453 B | B 主列表命中 ✔ |
| `/linux-kernel/` → 302 → `/lkml/` | 200 · 6951 B | 200 · 6473 B | 两系列都在 LKML 归档里（都 Cc 了 lkml） |
| `/coresight/` | **404** | — | lore 无此列表路径（**不可据此判未投**） |
| `/devicetree/` | — | **404** | 同上：拿上游同名单补丁（jie.gan `20261118-...-1-...`）在 `/devicetree/` **也是 404** ⇒ 路径本身不可用，非未投 |

⇒ 列表级「是否到齐」**只认 `/all/` + 主列表 200**；`/devicetree/` 与 `/coresight/` 一律记为 **不可核（路径缺失）**，
但 patchwork 的 project 归属（`devicetree` project 429 收了 B 的两封）是更强的旁证。

---

## 2. 逐封核对（Subject / 线程 / 归档）

### 2.1 A —— coresight MODULE_DEVICE_TABLE（`/all/<cover>/t.mbox.gz` 解出 3 封）

| # | 归档里的 Subject（原样） | Message-ID | Date | In-Reply-To |
|---|---|---|---|---|
| 0/2 | `[PATCH 0/2] coresight: add missing MODULE_DEVICE_TABLE() for CTCU and TPDA` | `<20261127113137.931578-1-…>` | Fri, 27 Nov 2026 19:31:35 +0800 | — |
| 1/2 | `[PATCH 1/2] coresight: ctcu: add missing MODULE_DEVICE_TABLE()` | `<…-2-…>` | 19:31:36 +0800 | `<…-1-…>` |
| 2/2 | `[PATCH 2/2] coresight: tpda: add missing MODULE_DEVICE_TABLE()` | `<…-3-…>` | 19:31:37 +0800 | `<…-1-…>` |

- `List-Id: <linux-kernel.vger.kernel.org>`（三封同）；ARC 头在：`Authentication-Results: smtp.subspace.kernel.org; arc=none smtp.remote-ip=202.38.64.46`。
- **Subject 与 `SENT.md` 表逐字一致**（含 `()` 结尾、`coresight:` 前缀）：**未被 lore/patchwork 改写**。
- **线程成串**：两封 patch 的 `References` 均只指 cover，`In-Reply-To` 均指 cover；lore 把它们聚成同一条 thread ✔。
- 截至 12:30Z（发出后 ~59 min）**无回复**。

### 2.2 B —— SM8750 TNOC periphid（`/all/<cover>/t.mbox.gz` 解出 4 封）

| # | 归档里的 Subject | Message-ID | Date |
|---|---|---|---|
| 0/2 | `[PATCH 0/2] arm64: dts: qcom: sm8750: describe the TNOC AMBA periphid` | `<20261127113158.932414-1-…>` | Fri, 27 Nov 2026 19:31:56 +0800 |
| 1/2 | `[PATCH 1/2] dt-bindings: arm: qcom,coresight-tnoc: allow the AMBA periphid` | `<…-2-…>` | 19:31:57 +0800 |
| 2/2 | `[PATCH 2/2] arm64: dts: qcom: sm8750: describe the TNOC AMBA periphid` | `<…-3-…>` | 19:31:58 +0800 |
| ↩ | `Re: [PATCH 2/2] arm64: dts: qcom: sm8750: describe the TNOC AMBA periphid` | `<sashiko-outbox-237264@kernel.org>` | Fri, 27 Nov 2026 11:41:59 +0000 |

- 三封 `List-Id: <linux-arm-msm.vger.kernel.org>`；回复 `List-Id: <devicetree.vger.kernel.org>`。
- **Subject 未改写**，**成串**（回复 `References` = cover + `-3`）。
- **回复内容（sashiko AI 评审，全文要点）**：

```
Thank you for your contribution! Sashiko AI review found 1 potential issue to consider:
- [Low] arm64: dts: qcom: sm8750: missing Fixes trailer for tn@109ab000 probe fix
...
This fixes probing of the tn@109ab000 node on SM8750.  Should this include:
  Fixes: ebd1eb365cae ("arm64: qcom: dts: sm8750: add coresight nodes")
--=20
Sashiko AI review · https://sashiko.dev/#/patchset/20261127113158.932414-1-xiaqinghuan@mail.ustc.edu.cn?part=2
```

⇒ 唯一待办项：**v2 给 2/2 补 `Fixes: ebd1eb365cae ("arm64: qcom: dts: sm8750: add coresight nodes")`**。

---

## 3. patchwork（**已摄取**；`?msgid=` 是假过滤器 —— 重要坑）

**所有请求的 HTTP 都是 200；Anubis 挑战页在这里表现为 `200 text/html`**，所以每次都断言 `content_type: application/json` + `json.loads` 成功才算数（本轮全部通过）。

```
$ curl -sS 'https://patchwork.kernel.org/api/1.2/patches/?msgid=20261127113137.931578-1-xiaqinghuan@mail.ustc.edu.cn'
200 application/json  []
```

`[]` 曾被我误读成「未摄取」。**标定**：拿一条确实存在的旧补丁（id 13983596）取它的 `msgid` 再查同一参数：

```
known patch msgid: <20250220-trace-noc-driver-v1-3-15d78bd48e12@quicinc.com>
msgid filter -> []
```

⇒ **patchwork API 1.2 的 `msgid` 参数不生效**（静默返回空表，不报 400）——这是本轮第二个「看起来没投/没摄」的假象来源。
**有效过滤是 `project=` + `q=`（+ `series=`）**，`q` 只搜 Subject：

| 查询 | 命中 |
|---|---|
| `?project=62&q=MODULE_DEVICE_TABLE` | `15029442`（2/2 tpda, **new**）、`15029441`（1/2 ctcu, **new**），2026-11-27T11:31:36/37 |
| `?project=92&q=periphid` | `15029445`（2/2 dts, **new**）、`15029446`（1/2 bindings, **new**） |
| `?project=429&q=periphid` | `15029447`（2/2 dts, **handled-elsewhere**）、`15029448`（1/2 bindings, **needs-ack**） |
| `?q=ctcu`（无 project/series） | **400** `{"detail":"Searches must be limited with one of these parameters: project, series"}` |

### 3.1 series 级明细

```
A: series 1224350  project=linux-arm-kernel(62)  v1  total=2  received_all=True
   cover 14177379  <20261127113137.931578-1-…>
   patch 15029441  new  <…-2-…>   [1/2] coresight: ctcu: add missing MODULE_DEVICE_TABLE()
   patch 15029442  new  <…-3-…>   [2/2] coresight: tpda: add missing MODULE_DEVICE_TABLE()

B: series 1224353  project=linux-arm-msm(92)     v1  total=2  received_all=True
   cover 14177380  <20261127113158.932414-1-…>
   patch 15029446  new  <…-2-…>   [1/2] dt-bindings: arm: qcom,coresight-tnoc: allow the AMBA periphid
   patch 15029445  new  <…-3-…>   [2/2] arm64: dts: qcom: sm8750: describe the TNOC AMBA periphid

B: series 1224354  project=devicetree(429)       v1  total=2  received_all=True
   cover 14177381  <20261127113158.932414-1-…>
   patch 15029448  needs-ack           <…-2-…>
   patch 15029447  handled-elsewhere   <…-3-…>
```

注：`/api/1.2/series/<id>/` 的 `cover_letter` 对象**没有 `state` 字段**（cover 不参与状态机），别拿它 KeyError 当「没摄」。
`handled-elsewhere` 是 patchwork 的自动归类（该 patch 也被 arm-msm project 收），**不是**已被上游采纳；`needs-ack` = 等 dt-binding 维护者 ack。

patchwork 幂等链接（可直接点）：<https://patchwork.kernel.org/series/1224350/>、<https://patchwork.kernel.org/series/1224353/>、<https://patchwork.kernel.org/series/1224354/>

---

## 4. 进树状态（**未进**；2026-11-27T12:35Z）

本地 `~/elden-cache/src/geekidos-linux` **无工作树**（只有 `scripts/`、`wt/`(空)，HEAD `44137cb4e929` = 2026-10-03），
且 `build/` 内核树按 `TASKS/README.md` 已清理 ⇒ **本地内容级检查不可行**，改走 cgit `plain`（实测可达，`/plain/Makefile` → 200）。

| 树 | 版本 | `coresight-ctcu-core.c` | `coresight-tpda.c` | `sm8750.dtsi` |
|---|---|---|---|---|
| torvalds/linux.git | `v7.4-rc4`（`NAME = Baby Opossum Posse`） | `ctcu_match[]` @294，**无** `MODULE_DEVICE_TABLE`（全文 0 处） | `tpda_ids[]` @618，**无** `MODULE_DEVICE_TABLE` | `tn@109ab000`（@5175）无 `arm,primecell-periphid` |
| next/linux-next.git | `v7.4-rc4` | 同上，**无** | 同上，**无** | 同上，**无** |

```bash
$ curl -sS https://git.kernel.org/pub/scm/linux/kernel/git/{torvalds/linux,next/linux-next}.git/plain/drivers/hwtracing/coresight/coresight-ctcu-core.c | grep -c MODULE_DEVICE_TABLE
0
$ curl -sS …/plain/drivers/hwtracing/coresight/coresight-tpda.c | grep -c MODULE_DEVICE_TABLE
0
$ grep -n 'tn@109ab000' -A12 sm8750.dtsi | grep periphid   # 无输出
5175:		tn@109ab000 {
5176-			compatible = "qcom,coresight-tnoc", "arm,primecell";
5177-			reg = <0x0 0x109ab000 0x0 0x4200>;
```

顺带核实（避免 v2 打空）：本轮补丁改的 `coresight-ctcu-core.c` **确实是上游现名**（torvalds 树里没有 `coresight-ctcu.c`，只有
`coresight-ctcu-core.c`），所以 A 的 1/2 路径与上游一致 ✔。

**判读**：发出后 ~1 h 未进树是**预期**（coresight 与 qcom 的树都要 next 周期，且 A 尚无 ack）。此项**不构成问题**，
但需注意 §5 的重叠线索——即使将来树里出现 `arm,primecell-periphid = <0x000f0c00>`，也**不能**当成「我们的 B 被采纳」。

---

## 5. ⚠ 重复工作告警：B 系列与 Jie Gan 的 [PATCH 0/4] 正面重叠

这是本轮回填里唯一**需要决策**的发现。

- 上游线程：`[PATCH 0/4] Fix the TraceNoC probe issue on QCOM platform`，**Jie Gan <jie.gan@oss.qualcomm.com>**，2026-11-18 15:01+0800
  <https://lore.kernel.org/all/20261118-fix-tracenoc-probe-v1-0-0298dc5f05ac@oss.qualcomm.com/>（lore 线程 **11 封**，含维护者回复）。
- 逐项对照：
  - `[1/4] dt-bindings: arm: coresight-tnoc: Allow arm,primecell-periphid` ↔ 我们 B 的 1/2（同绑定放开）
  - `[3/4] arm64: dts: qcom: sm8750: add periphid for traceNoC` ↔ 我们 B 的 2/2：**同一节点** `tn@109ab000`、**同一属性同一值**
    `arm,primecell-periphid = <0x000f0c00>`（其 patchwork diff 原文已核，见下）
  - 另含 `[2/4] kaanapali`、`[4/4] glymur use Aggregator TNOC`（我们未覆盖）
- patchwork：`linux-arm-msm` `[3/4]` = id **14995782**，**state `new`**；`[1/4]` = 14995780（arm-msm）/ 14995784（devicetree，`needs-ack`）。
- 已有人回：**Suzuki K Poulose 2026-11-20 10:39 +0200**、**Abel Vesa**（同一线程）。
- Jie Gan 的 cover 自述：本系列是「把 traceNoC 改到 platform bus」那版（v7，`20261110-fix-trace-noc-probe-issue-v7`）的**替代方案**，改用 `arm,primecell-periphid` 绕过无效 CID，只动 DT。

```
$ curl -sS 'https://patchwork.kernel.org/api/1.2/patches/14995782/' | jq -r .diff
@@ -5179,6 +5179,8 @@ tn@109ab000 {
 			clocks = <&aoss_qmp>;
 			clock-names = "apb_pclk";
 
+			arm,primecell-periphid = <0x000f0c00>;
+
 			in-ports {
```

⇒ **我们的 B（2026-11-27）比它晚 9 天，内容实质重复。** v2 之前需要拍板（本 lane 不擅自决定）：
1. **撤回/自缩**：B 只留「给 Jie Gan 系列补 SM8750 实测数据点（`0x000f0c00` 在本机 verify 过）+ ack/Tested-by」，把绑定与 dts 改动让给已在上游评审的系列；
2. **保留但显式差异化**：在 cover 里点名 Jie Gan 系列并说明差异（例如值来源不同、或只补其未覆盖的单元），否则极易被判 duplicate/被维护者要求 rebase；
3. 观察 1–2 个 next 周期：若 Jie Gan 系列先合，则 B 直接转为「已 upstream，参见该 commit」并在台账关行。
（本条已同步写进 `patches/upstream/sm8750-tnoc-periphid-20261127/SENT.md` 的同名告警节。）

A 系列**无**此问题：`MODULE_DEVICE_TABLE(of, ctcu_match)` / `(amba, tpda_ids)` 在 patchwork `q=MODULE_DEVICE_TABLE` + `q=ctcu` 的
近 60 天命中里只有别人的无关补丁（mediatek clk、turris-omnia-mcu 等），未见重复者。

---

## 6. 复现命令（可直接跑，约 30 s）

```bash
A='20261127113137.931578-1-xiaqinghuan@mail.ustc.edu.cn'
B='20261127113158.932414-1-xiaqinghuan@mail.ustc.edu.cn'
# 1) 归档实证（★ 不要带浏览器 UA / 不 extra header）
for m in "$A" "$B"; do
  curl -sS -o /tmp/x.gz -w "%{http_code} %{content_type} %{size_download}\n" \
    "https://lore.kernel.org/all/$m/t.mbox.gz"
  gunzip -c /tmp/x.gz | grep -c '^From mboxrd'
done
# 2) 标定（伪造 MID 必须 404）
curl -sS -o /dev/null -w '%{http_code}\n' \
  'https://lore.kernel.org/all/20260101000000.999999-1-nobody@example.invalid/t.mbox.gz'
# 3) patchwork（只认 project= + q=）
curl -sS 'https://patchwork.kernel.org/api/1.2/series/1224350/?format=json'
curl -sS 'https://patchwork.kernel.org/api/1.2/series/1224353/?format=json'
curl -sS 'https://patchwork.kernel.org/api/1.2/series/1224354/?format=json'
# 4) 进树
for t in torvalds/linux next/linux-next; do
  curl -sS "https://git.kernel.org/pub/scm/linux/kernel/git/$t.git/plain/drivers/hwtracing/coresight/coresight-ctcu-core.c" | grep -c MODULE_DEVICE_TABLE
done
```

---

## 7. 改动清单

| 文件 | 改动 |
|---|---|
| `patches/upstream/coresight-moduletable-20261127/SENT.md` | 「lore 复核（待回填）」→ 实测回填（端点矩阵 + 证据串 + patchwork id/state + 进树状态） |
| `patches/upstream/sm8750-tnoc-periphid-20261127/SENT.md` | 同上 + sashiko 回复原文要点 + **§重复工作告警** |
| `reports/upstream-sent-backfill-20261127.md` | 本文件（新建） |

未改：patch 内容、`SEND.sh`、`GATES.md`、`INDEX.md`、`TASKS/README.md`（按任务约束「不改其它文件」；
若父级要求登记 SSOT，需要另行授权改 `INDEX.md`/`TASKS` 台账行）。
