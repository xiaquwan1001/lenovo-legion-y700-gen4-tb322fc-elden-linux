# M4 camss v3 返工前置（Lane D）— SoB/Author 整改 + CSIPHY 迁移评估

> lane：只做主机侧，**不投递**、不发邮件。写路径仅本报告 + `patches/upstream/m4-camss-series-20261029/`。
> 判据口径：**已证** = 命令 + 原始输出；**未证实** = 只有推理；**未上机** = 无设备证据。

## 0. 结论摘要

> （施工中，两块完成后回填）

## 块 1 SoB 与 Author 整改

### 1.1 三枚取用补丁的上游原始件取证（2026-10-29 实取）

三枚原始件全部取到**邮件原件**（lore raw，Anubis PoW 已过），元数据逐字摘录：

**① hx SM8750 v6 #2**（我方 0001 binding 的来源）
原件：`out/mail-20261028/hx-v6/0002.patch`（lore，2026-07-21 投递）

```
From: Hangxiang Ma <hangxiang.ma@oss.qualcomm.com>
Subject: [PATCH v6 2/7] media: dt-bindings: Add CAMSS device for SM8750
Message-Id: <20260721-add-support-for-camss-on-sm8750-v6-2-a5f841061d18@oss.qualcomm.com>

Reviewed-by: Bryan O'Donoghue <bryan.odonoghue@linaro.org>
Reviewed-by: Krzysztof Kozlowski <krzysztof.kozlowski@oss.qualcomm.com>
Signed-off-by: Hangxiang Ma <hangxiang.ma@oss.qualcomm.com>
```

> ⚠️ 原件带 **2 个 Reviewed-by**（Bryan、Krzysztof），v3 若以他原文为基底，这两个 R-by
> **必须保留**（评审意见属于原提交，不能顺手抹掉）。

**② hx SM8750 v6 #5**（我方 0004 csid-980 的来源）
原件：`out/mail-20261028/hx-v6/0005.patch`（lore，2026-07-21 投递）

```
From: Hangxiang Ma <hangxiang.ma@oss.qualcomm.com>
Subject: [PATCH v6 5/7] media: qcom: camss: csid: Add support for CSID 980
Message-Id: <20260721-add-support-for-camss-on-sm8750-v6-5-a5f841061d18@oss.qualcomm.com>

Co-developed-by: Atiya Kailany <atiya.kailany@oss.qualcomm.com>
Signed-off-by: Atiya Kailany <atiya.kailany@oss.qualcomm.com>
Signed-off-by: Hangxiang Ma <hangxiang.ma@oss.qualcomm.com>
```

**③ hx Kaanapali v22 #9**（我方 0008 vfe-gen4 的来源）
原件：本轮新取 `lore all <20261024-kaanapali-camss-v22-9-7da3ea49c8a1@oss.qualcomm.com>/raw`
→ `/tmp/kaanapali/1.raw`（50,341 B，Subject `[PATCH v22 09/14] media: qcom: camss: vfe: Add
support for VFE 1080`）

```
From: Hangxiang Ma <hangxiang.ma@oss.qualcomm.com>
Subject: [PATCH v22 09/14] media: qcom: camss: vfe: Add support for VFE 1080
Message-Id: <20261024-kaanapali-camss-v22-9-7da3ea49c8a1@oss.qualcomm.com>

Co-developed-by: Atiya Kailany <atiya.kailany@oss.qualcomm.com>
Signed-off-by: Atiya Kailany <atiya.kailany@oss.qualcomm.com>
Signed-off-by: Hangxiang Ma <hangxiang.ma@oss.qualcomm.com>
```

> ⚠️ **修正 L6 报告（camss-upstream-response-20261028.md §2.1）**：其 0008 方案链里漏了
> `Co-developed-by: Atiya Kailany` + 他的 `Signed-off-by` —— Kaanapali v22 #9 原件**就有**
> Atiya 的 Co-dev/SoB 对，v3 必须继承。


### 1.2 v2 三枚当前元数据 vs 必须继承的证据

| 补丁 | v2 现状 | 原件要求继承 | 差额 |
|---|---|---|---|
| 0001 binding | `From: Qianhui Xu` + 仅自身 SoB | hx 的 From + 2×R-by + hx SoB | **hx 作者头 + 2 R-by 全丢** |
| 0004 csid-980 | `From: Qianhui Xu` + 仅自身 SoB | hx 的 From + **Atiya Co-dev/SoB** + hx SoB | **hx 作者头、Atiya 链全丢** |
| 0008 vfe-gen4 | `From: Qianhui Xu` + 仅自身 SoB | hx 的 From + **Atiya Co-dev/SoB** + hx SoB（Kaanapali v22 #9） | 同上，**且来源系列在 commit message 里只字未提** |

核实命令（可复跑）：

```sh
grep -m6 -E "^From:|^Subject:|^Co-developed-by:|^Signed-off-by:|^Message-Id:" \
  /home/xuqianhui/y700-elden/out/mail-20261028/hx-v6/{0002,0005}.patch
grep -m6 -E "^From:|^Subject:|^Co-developed-by:|^Signed-off-by:|^Message-Id:" /tmp/kaanapali/1.raw
```

输出（2026-10-29 实跑）：三枚原件头如 §1.1 摘录；我方 v2 三枚头部 `From: Qianhui Xu
<xiaqinghuan@mail.ustc.edu.cn>` + 单条 `Signed-off-by`（`patches/upstream/m4-camss-series-20261028-v2/
000{1,4,8}*.patch` 头 12 行）。

### 1.3 linux-next 核实上游提交 hash（块 1 关键证据）

> （fetch 进行中，核实后回填）

## 块 2 CSIPHY 迁移评估

> ⚠ **lane 在 78 轮后 `timed_out` 收尾，本节未完成**（编排者注，2026-10-29 19:30）。
> 已确证的需求侧事实：Vladimir Zapolskiy 要求 CSIPHY 改走 `phy-qcom-mipi-csi2-core`
> （据 `reports/camss-upstream-response-20261028.md`），我方 csiphy 2.4.0 的 103 条寄存器表
> 与 common status `0x138`（= 厂商 `csiphy_v2_4_0[+4]=0x1138`）的出处见
> `reports/m4-csiphy-vendor-provenance-20261027.md`。
> **未完成** = 该 phy 驱动在 7.3-rc7/linux-next 的实际 API、SM8750 2.4.0 支持度、逐项可迁移性判定、
> 补丁拆分与工作量估计。下次开工时从「读 `drivers/phy/qualcomm/phy-qcom-mipi-csi2*.c` 的
> ops 与 DT binding」起。

## 收尾：已做 / 未做 / 待拍板

- **已做**：① 三枚取用补丁的上游原件取证（lore raw，逐字元数据，见 §1.1）；② 九枚系列按 10-29
  公开承诺降为 **3 枚通用修复**（`patches/upstream/m4-camss-fixes-20261029/`，编排者独立复跑门禁 = 见该目录 `GATES.md`）。
- **未做**：CSIPHY 迁移评估（见块 2 注）；3 枚的 SoB 链最终改写（原件带 Bryan/Krzysztof 的
  `Reviewed-by`，若以他人原文为基底**必须**保留原作者与 R-by，不能替换成我方 SoB）。
- **待拍板**：3 枚是否现在就投（考虑信誉事件，A2/B 两 lane 均建议「先修提交形态再发」）。
