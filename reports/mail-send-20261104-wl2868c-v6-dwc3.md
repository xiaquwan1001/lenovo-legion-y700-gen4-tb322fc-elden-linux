# 上游投递 — 2026-11-04（wl2868c v6 + dwc3 正确形态重发）

> 用户 2026-11-04「可重发，都做」授权后的两次投递。两条系列均由子代理备料、**编排者独立复跑门禁后亲手发送**。
> 发送通道 = `git send-email`（`smtp.ustc.edu.cn:465`，Message-ID 逐字保真）；每条补丁 `Result: 250`。

## 0. 一句话

**两次投递各 N 封全部 250，patchwork 已索引到全部补丁，未出现任何退信（0 封 DSN）。**

| 系列 | 封数 | Message-ID 前缀 | patchwork 索引 | 退信 |
|---|---|---|---|---|
| **wl2868c v6 0/5**（base `05441d697f7f` = master 11-03） | 6（cover + 5） | `20261104032648.209747-1..6` | **5/5 命中**（`[v6,1/5]`..`[v6,5/5]`，state=new） | 0 |
| **dwc3 0/3**（base `24a19b953e2a` = v7.3-rc7） | 4（cover + 3） | `20261104032706.210042-1..4` | **3/3 命中**（`[1/3]`..`[3/3]`） | 0 |

## 1. wl2868c v6（`patches/upstream/wl2868c-20261104-v6/`）

- **为什么是 v6**：v5 被 Mark Brown 判「doesn't apply against current code」，根因已定位 = 板级补丁把
  `arch/arm64/boot/dts/qcom/Makefile` 的 hunk 锚在 `sm8650-qrd.dtb`，而主线随后在该位置插入
  `sm8650-valve-deckard.dtb`（`f905cb6e60`）。同一 base 上复现：v5 的 0004 `git am` rc=128（`Makefile:406`），v6 5/5 干净。
- **内容变化**（逐条对上 Conor/Konrad/sashiko/Mark Brown）：
  1. `arm/qcom.yaml` 独立成 3/5（Conor 要求，checkpatch 的 "should be a separate patch" 随之消失）；
  2. binding 新增 `vsys-supply` + `anyOf: [{required: vin7-supply}, {required: vsys-supply}]`，描述写明「internal control logic 由二者中较高者供电」（Conor 原话）；板级 supply 段落从 binding 提交信息删除；
  3. **SM8750 CCI 整枚移出**，让给 Hangxiang Ma 的 series（Konrad 的撞车警告），sashiko 的 `cci2`/`sleep-gpio` 两条随之只记录；
  4. driver 的 `enable` 改**整字节写**（维护「消费者已使能的 LDO 位集合」），修掉 sashiko Medium「SYS_EN 顺带点亮固件 preset 的其它 LDO」。
- **收件人**（本轮刻意纠正上一批的地址错误）：To = Liam Girdwood、Mark Brown；Cc = `devicetree@vger`、`linux-arm-msm@vger`、`linux-kernel@vger`、Bjorn Andersson、Konrad Dybcio、Rob Herring、Krzysztof Kozlowski、Conor Dooley。**`linux-regulator@vger` 不再使用**（该列表不存在，见 §3）。
- **编排者独立复跑**：checkpatch `--strict` stdin 5/5（0 error；2 条预期内 MAINTAINERS warning，均为新增文件）；
  `check-series-selfcontained.sh --repo build/wl-v2` = `PASS=5 FAIL=0 WARN=0`（base 命中）。
- **未证**：i2c10 probe / LDO 电压 / preset 位行为未上机；`VIN12/34/5/7` 的父 SPMI PMIC 不在本系列（VSYS 用无电压约束的 `regulator-fixed` 兜住 required）；`gpio-reserved-ranges` 沿用 v5 未重新取证；只跑单板 dtb。

## 2. dwc3 正确形态重发（`patches/upstream/m3-dwc3-20261104/`）

- **为什么要重发**：Krishna Kurapati（11-02 04:49Z）「v5 不能叠在 v4 上，必须把 v4 的改动包含进来」；
  Krzysztof（08:07Z）「misthreaded，缺 rest of patchset，请用 b4」；并在 08:13Z 对 v4 1/3 明确 `dropping`。
- **形态**：base 回退到**公开 tag `v7.3-rc7`**（`24a19b953e2a`），三枚**自足**补丁按文件集合并 v4+v5 全部改动
  （`yaml` / `roles/class.c` / `dwc3/{core.c,core.h,debugfs.c,drd.c}` 三组互不重叠）⇒ 无 reorder、无「1/2 单独重投」、无 base 依赖；对 base 501+/4−。
- **cover 逐条回应**：答 Krishna（不叠 v4，内容全含）、答 Krzysztof（认错 misthreaded、单线程、MID 连续、`In-Reply-To` 只挂 cover、b4 兼容形态）、sashiko 全部条目处置、与 v4/v5 的 diff stat、两条诚实限制。
- **收件人**：To = Greg KH、Thinh Nguyen、Rob Herring、Krzysztof、Conor；Cc = `linux-usb`、`devicetree`、`linux-arm-msm`、`linux-kernel`。**不含** `linux-devicetree@`（vger 550 历史坑）。
- **编排者独立复跑**：checkpatch 3/3 0E/0W/0C；`check-series-selfcontained.sh --repo linux` = `PASS=3 FAIL=0`（base 命中）。
- **未证**：未上机（行为证据来自本板 daily 内核同源代码 12 次拔插）；本机无 `b4`，`b4 send --dry-run` 未跑（用 `git send-email --dry-run` 等价验证）；未在 `usb-next` 重放。

## 3. 顺带纠正的地址纪律（本轮分诊产物）

`linux-regulator@vger.kernel.org` **不存在**（11-02 那批 6 封 550 全指向它；`linux/MAINTAINERS` 的 REGULATOR 段只有
`linux-kernel@vger.kernel.org`）。今后涉及 regulator 一律：**To 直接写维护者（Liam/Mark）+ Cc LKML**，不写该列表。
同类历史坑：`linux-devicetree@vger`（正确为 `devicetree@vger`）。

## 4. 复核方式说明（本轮环境变化）

`lore.kernel.org` 现被 Anubis JS 挑战拦截：`/<list>/<mid>/raw` 返 **HTTP 200 但内容是 7712 B 挑战页**
⇒ **不能再用 `/raw 200` 当归档证据**（上一批报告曾用）。本轮改用 **patchwork API**
（`patches/?submitter=…&since=…`）：两次投递的 8 枚补丁全部命中、`state=new`。
读回信仍走 IMAP（`read-mail-ustc.py`）：投递后 0 封 DSN / 0 封 postmaster 退信。

## 5. 下一步（盯 review）

| 系列 | 盯谁 | 我方欠什么 |
|---|---|---|
| wl2868c v6 | Mark Brown（apply 是否通过）、Conor（binding `vsys` 是否接受）、Rob/Krzysztof（yaml 拆分是否满意）、Konrad（板 DTS clocks 理由是否接受） | 无（等回信） |
| dwc3 0/3 | Krzysztof（形态是否合规）、Krishna（v4 内容是否完整）、Thinh/GregKH（仲裁逻辑） | 无（等回信）；若要求 b4 重发，先装 b4 |
