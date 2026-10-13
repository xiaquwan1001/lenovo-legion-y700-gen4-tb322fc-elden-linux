# M3 缺口矩阵 — 板 DTS 依赖项的上游支持面（2026-10-13）

> 证据层档案。规则 = `reports/upstream-policy-20261013.md`；M3 分片 = `reports/m3-series-plan-20261013.md`；M 系列状态权威 = `TASKS.md §7`。
> **来源说明**：本报告由**主会话**用脚本化 grep 重建（原 lane-C worker 被 Fabric 恢复看门狗杀于 600 s 无输出、未落盘任何产物 ⇒ 其"数据齐了"的自述无产物可核）。判定基准 = **pristine 提交 `24a19b953e`**（`Linux 7.3-rc7`）对比 payload 树 `build/m1-upstream/clean-tree`。

## 0. 数字结论

| 类别 | 项数 | 含义 |
|---|---|---|
| **上游齐**（binding + 驱动都在上游） | **14** | 板 DTS 直接引用即可，M3 只需把节点写对 |
| **上游有基座，payload 在改** | **6** | 属"扩展现有驱动"（Q2 正确姿势），但要按改动性质拆：修 bug / 加芯片 / 加特性 |
| **payload 新写**（上游无 binding 或驱动） | **9** | 新驱动须挂对应子系统；其中 2 项是 Q2 偏离候选 |
| 其中 **Q2 偏离候选** | 2 | `awinic,aw88461`（另写独立驱动而非扩展 aw88395 家族）、`pwrseq-qcom-wcn`（591 行等于重写上游文件） |

## 1. 逐条矩阵

| compatible | 上游 binding | 上游驱动 | payload 文件 | payload 对上游改动 | 缺口性质 | 归片 | 建议动作 |
|---|---|---|---|---|---|---|---|
| `qcom,wcd9390-codec` | `sound/qcom,wcd939x.yaml` ✅ | `sound/soc/codecs/wcd939x.c` ✅ | 同上 | **binding diff = 0** | 无缺口 | M3-3 | 直接用；板 DTS 只需 enable + dai-link |
| `qcom,sm8750-sndcard` | `sound/qcom,sm8250.yaml` ✅ | `sound/soc/qcom/sc8280xp.c` ✅ | 同上 | — | 无缺口 | M3-3 | 机器驱动已支持；确认 dai-link 组合 |
| `qcom,wcn7861-bt` | —（用 `qcom,wcn7850-bt.yaml`） | `drivers/bluetooth/hci_qca.c` ✅（无 WCN7861） | `hci_qca.c` | **393 行**（PERI 固件下载协议） | 新芯片 + 私有协议 | M3-6 / **B3** | 先与 linux-bluetooth 谈接口；或推动固件走 wcn7850 上游路径 |
| `qcom,wcn7861-pmu` | `regulator/qcom,qca6390-pmu.yaml`（payload 改 46 行） | `drivers/power/sequencing/pwrseq-qcom-wcn.c` ✅ | 同左 | **591 行**（≈重写） | **Q2 偏离候选** | M3-6 / **B7** | 拆成"新芯片时序数据 + 必要框架扩展"，逐段解释 591 行的必要性；否则先做最小子集 |
| `awinic,aw86927`（基座） | `input/awinic,aw86927.yaml` ✅ | `drivers/input/misc/aw86927.c` ✅ | 同左 | **363 行**（AW86937/938 SRAM 窗口、连续模式魔数） | 加芯片（AW86937/938） | M3-？/ **B2/A3** | 扩展上游驱动 + binding 加 compatible；**魔数必须 DT 化**（`reports/upstream-policy-20261013.md` §3） |
| `pci17cb,110e`（ath12k PEACH） | — | 上游 ath12k **无 PEACH/WCN7861** | `drivers/net/wireless/ath/ath12k/` | ~800 行 | 新 HW 支持 | M3-6 / **B6（M4）** | 按 ath12k 维护者接受的类型拆：框架扩展（tmel/board_api1）与 PEACH 数据表分开 |
| `novatek,nt36536`（面板） | `display/panel/novatek,nt36536.yaml` ✅ | `drivers/gpu/drm/panel/panel-novatek-nt36536.c` ✅ | 同左 | **74 行** | 改动（含测试钩子） | M3-4 | 先剥 `force_hz` 测试钩子（D2），只留功能修正 |
| `novatek,nt36536-ts`（触屏） | ❌ | ❌ | `bindings/input/touchscreen/` + `drivers/input/touchscreen/novatek-nvt36xxx-spi.c` | 新驱动 | 新写 | M3-4 | 挂 SPI + input；binding 需新写并过 `dt-doc-validate` |
| `samsung,s5kjns` | ❌ | ❌ | `drivers/media/i2c/s5kjns.c` + binding | 新驱动 | 新写 | M3-5 | 挂 V4L2 subdev；`media/i2c` 规范 |
| `galaxycore,gc08a8` | ❌ | ❌ | `drivers/media/i2c/gc08a8.c` + binding | 新驱动 | 新写 | M3-5 | 同上 |
| `giantec,gt9764` | ❌（review 亦指出缺） | ❌ | `drivers/media/i2c/gt9764.c` | 新驱动 | 新写 | M3-5 | V4L2 actuator；binding 必须补 |
| `willsemi,wl2868c` | ❌ | ❌ | `drivers/regulator/wl2868c-regulator.c` + binding | 新驱动 | 新写 | M3-5 | 挂 regulator 框架 |
| `awinic,aw88461` | 🔶 上游 aw88395 家族存在、**未列 aw88461** | 上游 `sound/soc/codecs/aw88395/` 存在 | `sound/soc/codecs/aw88461.c`（**547 行、自带 of_device_id 的独立驱动**） | 新文件 | **Q2 偏离候选** | M3-3 | 评估并入 aw88395 家族（共用 `aw88395_device.c`）vs 独立驱动；独立需给理由 |
| camss `qcom,sm8750-camss`（csid/vfe） | 🔶 上游无 sm8750 代际（仅有 sm8750-iris ISP binding） | 上游 camss 有 csid-340/680、gen2/gen3，**无 gen4/980** | 新增 `camss-csid-980.c`、`camss-vfe-gen4.c` + `camss.c`/csiphy 改动 | 新代际 | **M4 大件（B8）** | M3-5（+M4） | 数据化新代际 + 过 media 审查；本片只负责 DTS/binding 面 |
| 其余 14 项（pm8550 regulators、pmic-glink、`qcom,sm8750`、fsa4480、ptn3222、aw99706、csot pp8807hb1、gpio-keys、ramoops、fixed/fixed-factor-clock、regulator-fixed、simple-framebuffer、usb-c-connector、sdw20217010e00…） | ✅ | ✅ | — | — | 无缺口 | M3-2 | 直接引用；M3-2 板基础片主体 |

**上游文件对照（关键 6 项 payload 改动规模）**：panel 74 行 / aw86927 363 / hci_qca 393 / pwrseq-qcom-wcn 591 / qca6390-pmu.yaml 46 / wcd939x.yaml **0**。

## 2. 两条需要决策的 Q2 偏离

1. **`awinic,aw88461`**：上游已有 aw88395 家族（`sound/soc/codecs/aw88395/`，含 `aw88395_device.c` 共用层），payload 却另起独立驱动 547 行。按 Q2 应先评估并入家族（新增芯片分支），独立驱动需给出技术理由（寄存器差异/固件格式）。
2. **`pwrseq-qcom-wcn` 591 行**：上游该文件存在且是 WCN 上电时序的通用实现；591 行 ≈ 重写。必须拆成"WCN7861 新芯片时序数据（可上游）"与"框架扩展（需论证）"两段，否则 review 必拦。

## 3. 核验方法（可复现）

```sh
R=/home/xuqianhui1001/y700-elden/geekidos-linux ; P=24a19b953e   # pristine = tag 提交
# binding / 驱动是否上游（注意：grep 命中 enum/const 列表也算命中）
git -C $R grep -l -- '<compatible>' $P -- Documentation/devicetree/bindings
git -C $R grep -l -- '<compatible>' $P -- drivers/ sound/
# payload 侧文件
grep -rl -- '<compatible>' build/m1-upstream/clean-tree/Documentation/devicetree/bindings
# 改动规模（上游有同名文件时）
git -C $R show $P:<path> > /tmp/a && diff -u /tmp/a build/m1-upstream/clean-tree/<path> | grep -c '^[+-][^+-]'
```

**注意**：仅按字面 grep compatible 会漏判（面板 `novatek,nt36536` 曾被我方启发式误判为"无上游驱动"，实际上游有 `panel-novatek-nt36536.c`）⇒ 判断"上游是否已有驱动"必须查 `of_device_id`/`device_id` 表，不能只 grep 字符串。
