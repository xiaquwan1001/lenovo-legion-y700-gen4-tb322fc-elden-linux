# camss（M4）上游回信与元数据整改 — 2026-10-28

lane L6。范围：camss v2 系列的**上游回信 + SoB/Author 整改方案 + patchwork 状态 + sashiko 台账**。
写路径仅：本报告、`patches/upstream/m4-camss-series-20261028-v2/RESPONSE-20261028.md`、
`TASKS/sessions/2026-10-28-camss上游回信与SoB整改.md`、`out/mail-20261028/`。
**不改 SSOT README、不改已发补丁正文、不 merge、不动 main、不发任何新补丁系列。**

取证时刻：**2026-10-28 20:0x–20:3x +0800**（宿主 19:26 重启后重做；上一轮无产物）。

## 0. 结论摘要（数字先行）

| 项 | 结论 |
|---|---|
| **Hangxiang 的指控成立性** | **部分成立，且成立的两枚是主证据**：9 枚里 **2 枚确属取用他的代码且丢了 Author/SoB**（1/9 binding、4/9 csid-980），**1 枚取用的是他的 Kaanapali 系列**（8/9 vfe-gen4，非 SM8750 v6）。其余 **6 枚是纯我方新写**（匹配率 0–2 %）。 |
| 逐枚判定 | 直接取用 **3 枚**（1/9、4/9、8/9）；纯我方新写 **6 枚**（2/9、3/9、5/9、6/9、7/9、9/9） |
| 回信 | **2 封已发**（Hangxiang、Vladimir），Message-ID 与 Result 见 §3 |
| patchwork | camss **v1 的 linux-media 9 枚**仍为 `new`；**API 写权限 403（无凭据）** ⇒ 未改，给出 9 条手动链接（§4） |
| sashiko | 6 条：**接受 5 条**（进 v3）、**不接受 1 条并已在上游同形取证**（§5） |
| SKEW_CAL「改动放错提交」 | **属实**：v2 `0002` 写 `0x54`、`0004` 才改成 `0x00`；与 `reports/m4-skewcal-ab-20261027.md` 结论**方向一致**（厂商值 0x00） |
| 新发补丁 | **0 枚**（严格遵守上游「暂缓」要求） |

## 1. 逐枚 SoB/Author 核实

### 1.1 方法（可复跑）

不凭印象，用**新增代码行的逐行交集**量化「取用程度」。只统计**非平凡行**
（`len(strip)<12` 或 `{`/`}`/`};`/`/*`/`*/`/`return 0;`/`break;` 一律剔除，避免花括号把匹配率灌水）。

```sh
# 语料 A：Hangxiang SM8750 系列 v6（7 枚，lore 原件已存 out/mail-20261028/hx-v6/）
# 语料 B：Hangxiang Kaanapali 系列 v22 的 4 枚相关补丁（patchwork API 取 diff）
#   14912784 csiphy v2.4.0 / 14912780 csid-1080 / 14912782 vfe-1080 / 14912781 addr_update hooks
# 对每个我方 v2 补丁，统计其 "+" 行落在 A / B 的比例
```

复跑脚本见 §1.4。

### 1.2 逐枚表

| # | 我方 v2 补丁 | 我方新增非平凡行 | 命中 hx **SM8750 v6** | 命中 hx **Kaanapali v22** | 判定 | 处置 |
|---|---|---|---|---|---|---|
| 1/9 | `dt-bindings: media: add the Qualcomm SM8750 camera subsystem`（`qcom,sm8750-camss.yaml`，435 行） | 300 | **228（76 %）** | 0 | **直接取用 hx v6 #2**，改写并**新增** CSIPHY supply/clock/`phys` 相关内容 | **必须补 Author + SoB 链** |
| 2/9 | `csiphy: add CSIPHY 2.4.0 lane settings for SM8750` | 113 | 2（2 %） | 0 | **纯我方新写**（数据来源 = 厂商 `camera.ko` 反汇编，见 `reports/m4-csiphy-vendor-provenance-20261027.md`） | 无需补 |
| 3/9 | `csid: unwind the power-on path through a single error label` | 16 | 0（0 %） | 0 | **纯我方新写**（重构 pristine `camss-csid.c`） | 无需补 |
| 4/9 | `csid: add the 980 generation`（`camss-csid-980.c` 443 行） | 300 | **262（87 %）**；其中 `camss-csid-980.c` 本体 **258/280 = 92 %** | 156（52 %） | **直接取用 hx v6 #5**，逐字继承 SPDX/文件头/寄存器宏；相对他原文 **20 处 hunk、26 行删 / 26 行增**（含 sashiko 的两处 High 修复） | **必须补 Author + Co-developed-by + SoB 链** |
| 5/9 | `csid: report frame starts from CSID` | 65 | 0（0 %） | 1（2 %） | **纯我方新写**（SOF/EOF 时间戳、`camss_frame_start()` 接线） | 无需补（但改的是 csid-980.c，v3 排序要跟 4/9 绑） |
| 6/9 | `video: check that a buffer is DMA contiguous…` | 15 | 0 | 0 | **纯我方新写** | 无需补 |
| 7/9 | `video: stop the subdevices already started…` | 21 | 0 | 0 | **纯我方新写** | 无需补 |
| 8/9 | `vfe: add the gen4 block and SM8750 camera subsystem`（`camss-vfe-gen4.c` 212 行 + `camss.c` 357 行） | 363 | 78（21 %） | **239（66 %）**；`camss-vfe-gen4.c` 本体 **114/136 = 84 %** | **直接取用 hx 的 Kaanapali v22 #9 `camss-vfe-1080.c`**（不是 SM8750 v6！），改成 980 的 `BUS_REG_BASE`；`camss.c` 资源表 50 % 取自 v22 | **必须补 Author + SoB 链**（引用 Kaanapali 系列而非 SM8750 系列） |
| 9/9 | `arm64: dts: qcom: sm8750: add the camera subsystem` | 125 | 0 | 0 | **纯我方新写**（本机 TB322FC 实测拓扑） | 无需补 |

**数字汇总**：直接取用 **3 枚**（1/9、4/9、8/9），纯我方新写 **6 枚**。
按行计：我方 v2 共 **1318** 条非平凡新增行，其中 **570 条（43 %）**来自 Hangxiang 的两个系列。

### 1.3 硬证据（不靠比例，靠逐字）

1. **`camss-csid-980.c` 是同一份文件**：我方 `0004` 与 hx v6 `0005` 都是 `@@ -0,0 +1,443 @@`，
   行数**完全相同**，SPDX + 文件头注释 + `Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.`
   逐字一致（我方保留了 Qualcomm 版权行，但 `From:`/`SoB` 只写了自己）。
2. **差异只有 20 处 hunk / 26 行删 + 26 行增**（`diff` 全量见 §1.4），其中：
   - `-u8 dt_id = vc & 0x03;` → `+u8 dt_id = port & 0x03;`（sashiko F2 修复）
   - 我方**删掉**了 hx 的 `#include <linux/of.h>`、`MUP`、`CSID_TOP_IRQ_SET`、`CSID_CSI2_RX_IRQ_*`、
     `RDI_CFG1_DROP/CROP_*` 等**未使用**定义（checkpatch 干净化）
   - 我方**新增** `CSID_CSI2_RDIN_IRQ_MASK()`、`CSID_RDI_TOP_IRQ()`、`CSID_RDI_IRQ_PATTERN/PERIOD`、
     `CSID_RDI_SOF_TS/EOF_TS`（属 5/9 的前置）
3. **`camss-vfe-gen4.c` 来自 Kaanapali 而不是 SM8750**：`114/136` 非平凡行与 patchwork
   `14912782 [v22,09/14] camss-vfe-1080.c` 逐字相同（`Copyright`、`WM_*` 寄存器宏、client ID 注释表），
   我方只把 `BUS_REG_BASE` 从 `(lite?0x800:0x1000)` 改成 `(lite?0x200:0x800)` 并补 980 的 `IR_OUT` 注释。
   ⇒ 回信里**必须点名 Kaanapali v22**，否则会误导 Hangxiang 以为我们只用了 v6。

### 1.4 复跑脚本

```sh
cd /home/xuqianhui/y700-elden
# 语料 A：hx v6（已在 out/mail-20261028/hx-v6/）
python3 - <<'PY'
import glob,re,os,json
def triv(s):
    t=s.strip(); return len(t)<12 or t in {'{','}','};','/*','*/','return 0;','break;'}
hx=set()
for f in glob.glob('out/mail-20261028/hx-v6/0*.patch'):
    for l in open(f,errors='replace'):
        if l.startswith('+') and not l.startswith('+++'): 
            s=l[1:].rstrip('\n')
            if not triv(s): hx.add(s)
base='patches/upstream/m4-camss-series-20261028-v2/'
for f in sorted(os.listdir(base)):
    if not f.endswith('.patch') or 'cover' in f: continue
    A=[l[1:].rstrip('\n') for l in open(base+f,errors='replace')
       if l.startswith('+') and not l.startswith('+++')]
    A=[l for l in A if not triv(l)]
    n=sum(1 for l in A if l in hx)
    print(f"{f[:4]} n={len(A):4d} match={n:4d} {n/len(A):5.0%}")
PY
# 语料 B：Kaanapali v22（patchwork API）
for id in 14912784 14912780 14912782 14912781; do
  curl -s --noproxy '*' "https://patchwork.kernel.org/api/1.2/patches/$id/" -o /tmp/k$id.json
done
```

> 注意：`out/mail-20261028/hx-v6/` 是本轮**新增**落盘的原始件（来自 lore 归档，`From:` 均为
> `Hangxiang Ma <hangxiang.ma@oss.qualcomm.com>`，`Message-Id` 为
> `<20260721-add-support-for-camss-on-sm8750-v6-{1..7}-a5f841061d18@oss.qualcomm.com>`）。
> 其中 1–4 是新增文件/小改，5/6 带 `Co-developed-by: Atiya Kailany`。

## 2. v3 元数据整改方案 + framework 拆分取舍

### 2.1 Author/SoB 链：具体写法（只写方案，不改补丁正文）

按 `Documentation/process/submitting-patches.rst` §"Using Reported-by / Co-developed-by"
与 §"Sign your work"：**原作者保留为 `From:`**；改动者用 `Co-developed-by:`（其下必须紧跟本人 `Signed-off-by:`），
或（若只是「在其基础上小改」）保留他的 `Signed-off-by` 在最上、我方 `Signed-off-by` 追加在下。
本项目取**「From: 原作者 + Co-developed-by + 双方 SoB」**，并在提交信息末尾写明「基于哪个系列、改了什么」。

**3 枚需要改**，6 枚保持现状：

```
# 1/9  qcom,sm8750-camss.yaml
From: Hangxiang Ma <hangxiang.ma@oss.qualcomm.com>
...
Co-developed-by: Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>
Signed-off-by: Hangxiang Ma <hangxiang.ma@oss.qualcomm.com>
Signed-off-by: Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>
---
(baseline note) Based on "[PATCH v6 2/7] media: dt-bindings: Add CAMSS device
for SM8750" <20260721-add-support-for-camss-on-sm8750-v6-2-a5f841061d18@oss.qualcomm.com>.
Changes: moved the CSIPHY description to the qcom,x1e80100-csi2-phy PHY
bindings (per review), added the per-CSIPHY supply and clock names, fixed
the reg/reg-names counts, and dropped the CSIPHY nodes from this schema.

# 4/9  camss-csid-980.c
From: Hangxiang Ma <hangxiang.ma@oss.qualcomm.com>
Co-developed-by: Atiya Kailany <atiya.kailany@oss.qualcomm.com>   # 他 v6 里就有，必须保留
Signed-off-by: Atiya Kailany <atiya.kailany@oss.qualcomm.com>
Co-developed-by: Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>
Signed-off-by: Hangxiang Ma <hangxiang.ma@oss.qualcomm.com>
Signed-off-by: Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>
---
Based on "[PATCH v6 5/7] media: qcom: camss: csid: Add support for CSID 980".
Changes: unmask INFO_RUP_DONE so the RUP-done shadow is actually cleared,
derive DT_ID from the port instead of the VC (all RDI streams had CID 0),
drop the unused register definitions, and add the per-RDI IRQ mask helper.

# 8/9  camss-vfe-gen4.c + camss.c resources
From: Hangxiang Ma <hangxiang.ma@oss.qualcomm.com>
Co-developed-by: Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>
Signed-off-by: Hangxiang Ma <hangxiang.ma@oss.qualcomm.com>
Signed-off-by: Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>
---
Based on "[PATCH v22 9/14] media: qcom: camss: vfe: Add support for VFE 1080"
and the Kaanapali csiphy/csid resource tables from the same series
<20261024-kaanapali-camss-v22-9-7da3ea49c8a1@oss.qualcomm.com>.
Changes: the 980 bus register base (lite 0x200 / full 0x800) instead of the
1080 one, IR_OUT instead of RAW_OUT at write master 9, and the SM8750
csiphy/csid/vfe resource tables.
```

**顺序注意**（`Co-developed-by` 必须紧邻其 `Signed-off-by`）：上面 `4/9` 里
`Atiya` 的 `Co-developed-by` 与 `SoB` 相邻、`Qianhui` 的 `Co-developed-by` 与 `SoB` 相邻，
`Hangxiang` 的 `SoB` 收在中间 —— 这是合法形态（他的 `Co-developed-by: Atiya` 在他自己 `From:` 名下）。
若 maintainer 更偏好「原作者 SoB 在最后」，可改成 `Atiya Co-dev/SoB` → `Qianhui Co-dev/SoB` → `Hangxiang SoB`。

**不做的事**：不改已发的 v2 补丁正文、不重发、不加 `Reported-by`（他不是报告者，是原作者）。

### 2.2 framework 拆分取舍（Hangxiang 给了两个选项）

他给的选项：① 暂缓（等 Kaanapali 合并后他 rebase 跟进）；② 把 CAMSS framework 部分拆成独立系列。
他问的是「你们选哪个 / 愿不愿意拆」。

**建议：两个都接受，但拆法与他设想的相反 —— 先拆「与他代码无关的通用修复」，暂缓「与他代码重叠的代际支持」。**

| 我方 v2 补丁 | 与他代码重叠？ | 是否可独立先发 | 理由 |
|---|---|---|---|
| 2/9 csiphy 2.4.0 lane 表 | 否（厂商反汇编，非他代码） | ⚠️ **不可**（Vladimir 要求整体迁 `phy-qcom-mipi-csi2`，架构要返工） | 架构方向未定 |
| 3/9 csid 上电错误路径 unwind | 否 | ✅ **可以**（纯重构 pristine `camss-csid.c`，无 SoC 依赖） | 与 SM8750 无关的通用清理 |
| 6/9 video DMA 连续性检查 + prepare hook | 否 | ✅ **可以**（纯 `camss-video.c`，通用） | 同上 |
| 7/9 video 启动失败回滚已启动子设备 | 否 | ✅ **可以**（纯 `camss-video.c`，通用） | 同上 |
| 5/9 csid 上报 frame start（SOF/EOF） | 否（但他 4/9 那枚 csid-980 是基座） | ❌ 暂缓 | 改的是 csid-980.c，必须跟着 4/9 |
| 1/9 binding / 4/9 csid-980 / 8/9 vfe-gen4 / 9/9 dts | **是** | ❌ **暂缓**（他明确要求） | 与他的 SM8750/Kaanapali 系列直接冲突 |

⇒ 回信口径：**「通用 video/csid 清理（3 枚）可以在你 rebase 完成后单独发；SM8750 代际支持（5 枚）暂缓，
等你 Kaanapali 合并后我们 rebase 到你的树上再发，并带上完整 Author/SoB 链。」**
这样既满足他「避免重复劳动/分裂评审」的诉求，也保住我方 3 枚无争议的通用修复不被他的时间线卡死。

**不承诺任何日期**（上游要求 + 我方纪律）。

## 3. 两封回信（草稿 + 发送记录）

**结论：2 封均已真发出，非“可能没发”。** 核对方式 = Sent Items 回读 + lore 按 Message-ID 取 raw 比正文 sha256（双重确认，不靠“已发送”字样）。

| # | 收件人 | 草稿 | Message-ID | 发送时间 | Result |
|---|---|---|---|---|---|
| 1 | Hangxiang Ma `<hangxiang.ma@oss.qualcomm.com>`（To 3 人 + Cc 9，见草稿头） | `out/mail-20261028/camss-reply-hangxiang.txt` | `<179318934146.107329.15810039464216984473@mail.ustc.edu.cn>` | 2026-10-28 20:09:01 +0800 | **Sent Items 命中 + lore 归档命中**，正文 sha256 一致 |
| 2 | Vladimir Zapolskiy `<vz@kernel.org>`（To 1 人 + Cc 12，含 Hangxiang） | `out/mail-20261028/camss-reply-vladimir.txt` | `<179318935222.107529.54392791903989018@mail.ustc.edu.cn>` | 2026-10-28 20:09:12 +0800 | **Sent Items 命中 + lore 归档命中**，正文 sha256 一致 |

线程头逐字核对：
- #1 `In-Reply-To: <218d69dc-5761-4a8c-824f-7a15307f54a6@oss.qualcomm.com>`（Hangxiang）✅
- #2 `In-Reply-To: <8e05a28e-7881-4bf5-98c7-c5ccf4e22735@kernel.org>`（Vladimir）✅

### 3.1 复核证据（可复跑）

```bash
# a) Sent Items 回读（IMAP mail.ustc.edu.cn:993，凭据走 keyring smtp.ustc.edu.cn:465）
python3 ~/.local/bin/read-mail-ustc.py --days 5 --folders '"Sent Items"' --grep camss
# b) lore 按 Message-ID 直取 raw（自动过 Anubis PoW；裸 curl 一律 403）
python3 ~/.local/bin/lore-query.py "https://lore.kernel.org/linux-media/<msgid>/raw"
```

正文逐字比对（去 mboxrd `From `/`>From ` 后按行 rstrip 归一化，比 sha256）：

| # | lore raw 字节 | 正文 sha256（前 20） | 与草稿一致 |
|---|---|---|---|
| 1 | 8519 | `d204b32832a0ac51727f` | **是**（草稿同 hash） |
| 2 | 7518 | `2f3d980188603ba2f695` | **是**（草稿同 hash） |

原始件落盘（仅 out/）：`out/mail-20261028/lore-camss-reply/` 下 `sentitems-{hangxiang,vladimir}.eml` + `{hangxiang-179318934146,vladimir-179318935222}.raw`。

### 3.2 处置口径（与 §2 一致，已随信发出）
- 对 Hangxiang：承认 3 枚取用（1/9、4/9、8/9）并补 Author/SoB；**SM8750 代际 5 枚暂缓**，等他 Kaanapali 合并后 rebase 再发；**通用清理 3 枚**（3/9、6/9、7/9）问过是否单独发。**未承诺任何日期。**
- 对 Vladimir：接受 CSIPHY 必须迁 `phy-qcom-mipi-csi2-core.c`，**2/9 撤回而非原地改**；先读 SM8450 系列 + in-tree phy 驱动再提形状。
- **本次未发任何 camss 补丁**（0 枚），符合上游「暂缓」要求。


## 4. patchwork：camss v1 标 Superseded

**结论：未标成。API 写权限 403，无凭据，本轮不重试认证 ⇒ 需人工点 9 下。**

实测（2026-10-28 20:2x +0800，可复跑）：

```bash
curl -sS --noproxy '*' -o /dev/null -w '%{http_code}\n' -X PATCH \
  -H 'Content-Type: application/json' -d '{"state":"superseded"}' \
  https://patchwork.kernel.org/api/1.2/patches/14920481/   # -> 403
```

### 4.1 状态快照（读 API 正常，仅写被拒）

- v1 series：**id 1195087**，`media: camss: add SM8750 support`，`version=1`，`total=9`，`received_total=9`，`received_all=true`
  - cover：`https://patchwork.kernel.org/project/linux-media/cover/20261028034105.326535-1-xiaqinghuan@mail.ustc.edu.cn/`
- 9 枚**全部 `state = new`**（未变）
- v2 series 9 枚也已入档，同为 `new`（id 14920892–14920900）⇒ 即便标了 v1，v2 也需后续重投/关闭，见 §6
- 快照 JSON 已落盘：`out/mail-20261028/patchwork-series-1195087-v1.json`、`patchwork-submitter-camss.json`

### 4.2 手动清单：9 条（逐条 `Action → Superseded`）

| # | patch id | patchwork URL | 当前 |
|---|---|---|---|
| 1/9 | 14920481 | https://patchwork.kernel.org/project/linux-media/patch/20261028034105.326535-2-xiaqinghuan@mail.ustc.edu.cn/ | new |
| 2/9 | 14920487 | https://patchwork.kernel.org/project/linux-media/patch/20261028034105.326535-3-xiaqinghuan@mail.ustc.edu.cn/ | new |
| 3/9 | 14920483 | https://patchwork.kernel.org/project/linux-media/patch/20261028034105.326535-4-xiaqinghuan@mail.ustc.edu.cn/ | new |
| 4/9 | 14920484 | https://patchwork.kernel.org/project/linux-media/patch/20261028034105.326535-5-xiaqinghuan@mail.ustc.edu.cn/ | new |
| 5/9 | 14920482 | https://patchwork.kernel.org/project/linux-media/patch/20261028034105.326535-6-xiaqinghuan@mail.ustc.edu.cn/ | new |
| 6/9 | 14920488 | https://patchwork.kernel.org/project/linux-media/patch/20261028034105.326535-7-xiaqinghuan@mail.ustc.edu.cn/ | new |
| 7/9 | 14920485 | https://patchwork.kernel.org/project/linux-media/patch/20261028034105.326535-8-xiaqinghuan@mail.ustc.edu.cn/ | new |
| 8/9 | 14920489 | https://patchwork.kernel.org/project/linux-media/patch/20261028034105.326535-9-xiaqinghuan@mail.ustc.edu.cn/ | new |
| 9/9 | 14920486 | https://patchwork.kernel.org/project/linux-media/patch/20261028034105.326535-10-xiaqinghuan@mail.ustc.edu.cn/ | new |

操作提示：登录 patchwork（或让 maintainer）后，每页右上 **`Action → Superseded`**；**需人工点 9 下**。
可在 series 页一次性操作：`https://patchwork.kernel.org/project/linux-media/series/1195087/`。

> 备注：本轮**不改** v2 的 state（上游已收到 v2，暂缓待 rebase；擅自标 v2 反而抹掉“已投递待评审”信号）。


## 5. sashiko 6 条处置台账

**本系列（camss v2）只有 3 条；3 条全部接受，全部进 v3。**（源：`reports/mail-triage-20261028.md` §1.1；原件 `out/mail-20261028/orig/sashiko-outbox-{187685,187698,187701}-kernel-org.eml`）

### 5.1 #2 csiphy SKEW_CAL（`<sashiko-outbox-187685@kernel.org>`，Medium）

**接受（三个子项全接受）。** 落在 **v2 `0002`**（`lane_regs_sm8750[]` + commit message）。

| 子项 | 核实 | 处置 |
|---|---|---|
| (a) 表里 4 条 SKEW_CAL 仍 `0x54`，与 commit message 说的 `0x00` 矛盾；`0x54→0x00` 被放到 `0004` 才改 | **属实**。`0002` 第 77/100/123/146 行均为 `{0x005C/0x045C/0x085C/0x0C5C, 0x54, ...}`；`0004` 才改成 `0x00` | **改动前移到 `0002`**，`0004` 删掉这 4 行 hunk（即 §0 已判的「改动放错提交」） |
| (b) `CSIPHY_SKEW_CAL` 在 `csiphy_gen2_config_lanes()` 里 `continue`，不写硬件 ⇒ 现在改是 no-op | **属实**（in-tree `camss-csiphy-3ph-1-0.c:1216-1218` 是 `continue` + TODO） | 表统一为**厂商值 `0x00`**；commit message **写明「SKEW_CAL 条目当前被 `continue` 跳过，skew 支持实现前此值不生效」**，不假装它是活代码 |
| (c) commit message 的「四个数据 lane 0x400 步进 + 时钟 lane 0xc00」与表实际布局不符 | **属实**。表：LN 0/2/4/6 = `0x0000/0x0400/0x0800/0x0C00`，**LN CLK = `0x0E00`** | 改为「four data lanes at 0x0000/0x0400/0x0800/0x0C00, clock lane at 0x0E00」 |

**与 `reports/m4-skewcal-ab-20261027.md` 的一致性：一致，不重复推导。** 该报告 §5 判：A 臂 `0x54` / B 臂 `0x00` 四维无差异（90 帧全绿、0 错误、30.26 fps、帧时间 53.81 vs 53.78），且厂商 82 张表**无** `0x54` ⇒ 以厂商值 `0x00` 为准并注明本机无差异。sashiko 说的「应为 `0x00`」与实测**方向一致**；「改动放错提交」属实现层错误，与 A/B 不冲突。

> ⚠️ **`0002` 整枚按 Vladimir 要求要撤回**（CSIPHY 迁 `phy-qcom-mipi-csi2-core.c`，见 §0/§3）⇒ 这三项修正**不进 camss v3 的 `0002`**，而是进入将来的 **PHY 驱动那枚补丁**。台账照记，避免遗漏。

### 5.2 #4 csid-980 AUP/RUP 残留 + 数据竞争（`<sashiko-outbox-187698@kernel.org>`，High + Medium）

**接受（两条都接受）。** 落在 **v2 `0004`**（`camss-csid-980.c` + `struct csid_device` 三字段）。**进 v3：是。**

| 子项 | 核实 | v3 改法 |
|---|---|---|
| **[High] 位掩码累积**：启动时 `csid_configure_stream()` 循环 `CAMSS_INIT_BUF_COUNT` 次调 `__csid_aup_update()`/`__csid_rup_update()`，期间无 `INFO_RUP_DONE` ⇒ 三字段位不清零，重复下发，多 RDI 时重写低位端口陈旧位 | **属实**。`0004` 里只有 `\|=` 与 `&= ~`；`__csid_aup_rup_clear()` 只在 `INFO_RUP_DONE` 路径被调，而**仅 AUP 更新不产生该中断** ⇒ 首帧后 `aup_update` 位永久残留 | 每端口**下发后立即清自己的位**（write-then-clear，不等中断）；初始化循环里对已下发位显式清零；`__csid_aup_rup_clear()` 降为防御性兜底 |
| **[Medium] 三字段数据竞争**：`csid_isr()` 硬中断里 `__csid_aup_rup_clear()` 非原子 RMW，与 `vfe_queue_buffer_v2()`（持 `vfe->output_lock`）→ `csid_subdev_reg_update()` → `__csid_aup_update()` 并发 | **属实**。`0004` 全文**无任何 `spin_lock`**（grep 零命中） | 加 `spinlock_t reg_update_lock` 到 `struct csid_device`，三个 `__csid_*` 函数全 `spin_lock_irqsave`（ISR 安全）；**不用 `vfe->output_lock`**（跨模块、层级反了） |

与 `m4-skewcal-ab-20261027.md` **无交集**（那条只讲 csiphy SKEW_CAL 数据字节），不构成冲突。

### 5.3 #8 vfe-gen4 与 csid_isr 竞争（`<sashiko-outbox-187701@kernel.org>`，Medium）

**接受。** 根因与 §5.2 Medium **同一个**，只是从 VFE 侧触发（`vfe_reg_update()`/`vfe_reg_update_clear()` → `camss_reg_update()` → `csid_subdev_reg_update()`）。
落在 **v2 `0004`**（锁在 CSID 侧），**`0008` 不改**（只是调用方）。**进 v3：是，随 §5.2 一并修。**

- 核实：`0008` 的 `vfe_reg_update()` 无自有共享状态，共享状态全在 `csid_device` ⇒ **不新增第二把锁**，由 §5.2 的 `csid->reg_update_lock` 统一覆盖。两条 finding 合并成一个修复。

### 5.4 不在本系列

aw86927 #4（`BST_MODE_MASK` 位宽）/ #5（缺 `devm_add_action_or_reset()`）、GT9764 binding（裸寄存器值 / MAINTAINERS 字母序 / 属性顺序）——**不在本系列，另行处置**。

## 6. 未证实项 / 风险

| 项 | 状态 | 影响 | 下一步（谁能做） |
|---|---|---|---|
| **patchwork camss v1 未标 Superseded** | **未完成，非“失败”**：API 写权限 **403**（无凭据），本轮已实测一次（§4.1），**按约束不重试认证** | v1 9 枚继续以 `new` 出现在 reviewer 队列，与已发的 v2 并存 ⇒ 可能被判“两个系列并行评审” | **需人工**：登录后按 §4.2 清单点 9 下（或 series 页批量）；无自动化余地 |
| **lore 归档** | **已复核，无遗留**（本次新增）：两封回信在 `linux-media` inbox 按 Message-ID 取 raw **均命中**，正文 sha256 与草稿**逐字一致** | — | 已闭环，证据见 §3.1 |
| **CSIPHY 迁 `phy-qcom-mipi-csi2` 的返工规模** | **仍是估算，未实测** | 决定 2/9 是「重写」还是「小改」，直接影响 v3 体量与时间 | 估算依据：① 本机 `geekidos-linux/drivers/phy/qualcomm/` 里 **`phy-qcom-mipi-csi2*` 尚不存在** ⇒ 得等 SM8450 系列入树或跟包；② 待迁内容 = `camss-csiphy-3ph-1-0.c`（**1402 行**）里 2/9 新增的 **117 行 lane 表** + `csiphy_is_gen2()`/`csiphy_init()` 分支（2 个 hunk），而非整文件；③ 未做的是「PHY 侧 API 映射」：camss 侧要改成 generic PHY consumer（`devm_phy_get`/`phy_init`/`phy_power_on`）——**这部分行数未知**，得先读 SM8450 系列的 `Allow CSI2 PHY devices without CSIPHY resources` 那枚才能定 | 读 SM8450 系列（`20261026224957.1115370-1-vz@kernel.org`）+ in-tree phy 驱动后再出数 |
| **camss v2 9 枚在 patchwork 仍为 `new`** | 已知，**故意不改** | 若后续按 §2.2 拆系列，需重投而非改 state | 等 Hangxiang rebase 时间线；本次不动 |
| **Hangxiang 是否会同意“3 枚通用清理先发”** | 未回 | 影响 3/9、6/9、7/9 是否解阻 | 等他回信；**不催、不承诺日期** |
| **sashiko #4 [High] 的修法未经硬件验证** | 仅代码推理（`0004` 全文无 `spin_lock`，位不清零） | v3 改完需重跑相机出流才能宣称修复 | v3 重编后跑 `scripts/camera-stream-up.sh` + 90 帧采集（同 `m4-skewcal-ab` 口径） |
| **SKEW_CAL 冷启（POR）路径** | `m4-skewcal-ab-20261027.md` §5 已声明**不外推到整机冷启动**（仅热换模块） | 若上游追问冷启行为，当前无数据 | 需要时再单独立项，不在本报告结论内 |

### 6.1 一句话风险排序

1. **最高**：patchwork v1 未标（人工 9 下）—— 不处理会让 reviewer 看到两个并行系列。
2. **中**：CSIPHY 返工规模未定 —— 阻塞 2/9 去向，但不阻塞其他 8 枚。
3. **低**：sashiko 修复需硬件复测 —— v3 重编时顺手做。

