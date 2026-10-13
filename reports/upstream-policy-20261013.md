# 上游化策略 — 三问审计与「mainline + 薄下游层」落地（2026-10-13）

> 证据层档案。**本文只定规则与清单、不改代码**；结论指针 = `TASKS.md §7`（M 系列）、`.pi/AGENT-OPS.md` §3（纪律）。
> 输入：`archive/topics/UPSTREAM-REVIEW-2026-10-04.md`（A/B/C/D 分级与 125+11 文件边界）、`patches/`、`patches/upstream/m2-2026-10-13/`、`reports/upstream-{hits-review,lane-merge,m1-clean-tree}-2026*.md`。
> 基线口径：上游 `v7.2-elden`/`v7.3-rc7`；M1 干净树 = `build/m1-upstream/clean-tree` @ `m1/clean-tree`。

## 0. 一句话原则

**能用主线框架的绝不自造；能进设备树的绝不写进 C 代码；能复用已有驱动的绝不新写一个。**

## 1. 提交前门（三问，写任何一行代码前）

| 问 | 判断 | 动作 |
|---|---|---|
| **Q1** 这个硬件功能，主线里有没有对应**子系统**？ | 有 | 必须用它的框架（见 §5 强制项表），不得自造 |
| | 没有 | 才考虑自己写 |
| **Q2** 主线里有没有已支持的**同类芯片**？ | 有 | 优先扩展/复用该驱动，不新写 |
| | 没有 | 新写，但必须按子系统规范写 |
| **Q3** 这段逻辑是**硬件事实**还是**软件策略**？ | 硬件事实（寄存器序列、时序、电压） | 放设备树 / 数据表 |
| | 软件策略（流程、状态机） | 放驱动代码，且尽量通用 |

**强制框架（红线，无选择题）**：clk · regulator · genpd/power-domain · pinctrl+gpio · irqchip · reset · i2c/spi/uart · DRM/KMS+drm_panel · backlight/leds · input · iio · ASoC · V4L2/media · mmc/ufs/nvme · netdev/phy · usb/typec/phy。

**可以自己写**：主线没有的具体芯片驱动（挂对应子系统下）；板级差异（走 DT）；初始化序列/校准数据（DT 或数据表）；无标准框架的厂商私有外设（独立模块、尽量少）。
**可以自己写 ≠ 可以随便写**：仍须内核风格 + 标准 API。

## 2. 审计结果（相对主线 payload）

| 指标 | 值 | 来源 |
|---|---|---|
| 改动文件 / 行数 | 125 个 / ≈7077 行 | 审查 §0 |
| 新增驱动/DTS 文件 / 行数 | 11 个 / ≈5300 行 | 同上 |
| 方向正确的硬件缺口 | ≈60%（DTS/camss/ath12k/panel/codec/regulator） | 同上 |
| 结构需重做后再发（B 类） | ≈25%（psci / DSI 一族 / 音频全局变量） | 同上 |
| 永不进上游（D 类） | ≈15% | 同上 |
| 机械检查 | 新驱动 9 文件 `checkpatch --strict` **0E/0W/2C**；binding 19 改+6 新全过 `dt-doc-validate`；板 DTS `dtc` 0 warning、`dt-validate` **仅 1 红点**（`usb@a600000`） | 审查 §0/§3 |

**判定**：payload ≈ 一个标准「新 Qualcomm 平板上游化」工程，主干合规；问题集中在**少量 Q3 违例**与**结构性偏离**，不是方向错误。

## 3. Q3 违例清单（把「策略 / 未定根因」当硬件事实写进代码）— 发上游前必须清

| 条目 | 位置 | 为什么是违例 | 归属 / 动作 |
|---|---|---|---|
| panel `force_hz` module_param | `patches/0007-panel-force-hz-test-hook.patch` | 测试钩子进驱动 = 策略 | **删**；刷新率走 panel mode table（`0008-panel-165hz-default.patch` 才是正解） |
| DSI timing `dev_info` 打印（D1） | `dsi_host.c` +7 | 调试插桩 | 删 |
| `btqca.c` `tlv_nvm->data[1] &= ~0x01`（D3） | WCN7861 IBS 全局禁用 | **根因未定**（bt-link H4/H2 未判别完）且改变**所有** WCN7861 板行为 | 收回实验区，**不进任何包**；根因定案后再谈 |
| `ath12k/mhi.c` `MHI_TIMEOUT 90000→3000`（D4） | 全局超时 | 掩盖 WCN 上电时序（注释自承靠 bind 重探） | 删；正确解 = `probe defer` |
| aw86927 连续模式 `0x7f/0x04/0xff`（B2） | 反汇编厂商 ko 得的魔数 | 硬件事实写进 C | 提升为 **DT 属性 + binding**；`haptic_hv_l/r` 已在 DTS |
| Q28 `dsi_cmd_delay_us` cmdline 参数 | `patches/q28-cmd-dma-delay.patch` | 控制器侧 workaround 走全局 cmdline | 若属面板时序事实 → 进 panel mode data；否则走 **quirk + 上游 RFC 说明** |
| vendor-only DT 属性（D7）+ `usb@a600000` 红点 | 板 DTS / `snps,dwc3-common.yaml` | 容器节点塞 vendor 属性；改错了 schema 层（应改 qcom wrapper） | 清理 + 修正 schema 用法 ⇒ 上游 CI 才能绿 |

## 4. Q1/Q2 结构性偏离（用了框架但结构不合规）

| 条目 | 现状 | 上游姿势 |
|---|---|---|
| **B1** `psci.c` +37 板级硬编码 vendor `SYSTEM_RESET2` | 通用文件里塞板级钩子 | 本应 `reboot-mode` driver + DT；上游 13-patch 系列**未合并** ⇒ **当下游过渡层保留 + TODO「上游合入即替换」**（G1-24 依赖它） |
| **B5** DSI 一族 ~940 行散落 `of_device_is_compatible("qcom,sm8750-dsi-ctrl")` | 逐处 compat 判定 | 收进 **per-SoC cfg 结构**，拆 3–4 个功能补丁（也是 Q28 主战场） |
| **C1** `audioreach.c` 全局 `apm_src_port` setter/getter | 跨模块全局变量 | 收进 `struct q6apm` + per-SoC compat（根因 = 本机 ADSP 属下游 SPF 行为） |
| **A3 分类更正** | `aw86927.c` SRAM 窗口 0x1000→0x2000 | 上游 v7.3-rc7 该驱动**无 firmware 波形装载路径** ⇒ 无对应代码可修，**降为 B/C**，不进 M2 |
| **A1 撤稿** | DPU GC 块目录 | 与已在 msm 树的 `3389406e6a03`（v7.4）**重复** ⇒ 已发撤稿 |

## 5. 合规面（保持，勿在重构中破坏）

| payload 组件 | 强制框架 | 状态 |
|---|---|---|
| `panel-novatek-nt36536` | DRM/KMS + `drm_panel` | ✅（需先剥 §3 的 `force_hz`） |
| `novatek-nvt36xxx-spi` | SPI + input | ✅ |
| `wl2868c-regulator` | regulator | ✅ |
| `aw86927`（AW8693X 窗口） | input FF（上游驱动已存在 ⇒ Q2 复用） | ✅（魔数须 DT 化） |
| `s5kjns` / `gc08a8` / `camss-*` | V4L2 / media controller | ✅ |
| `pwrseq-qcom-wcn` + binding | pwrseq | ✅（须与 `qca6390-pmu.yaml` 配套说明） |
| `hci_qca` PERI 固件下载（B3） | bluetooth | 协议为高通下游私有 ⇒ 先谈接口 |
| 板 DTS `sm8750-lenovo-elden.dts`（A5） | devicetree | ✅ `dtc` 0 warning（红点见 §3） |

## 6. 无法主线化 → 隔离，而不是消灭（薄下游层清单）

| 下游项 | 性质 | 隔离方式 |
|---|---|---|
| `dm-default-key` + fscrypt wrappedkey ABI（C2，**G2 必需**） | 上游不收 hfscrypt 风格 vendor key ABI | **out-of-tree patchset**（= M5），永不进上游包 |
| 高通私有 DPU/DSC/PHY 逻辑、GGX 寄存器 init（C3）、闭源固件（ADSP/CDSP/WCN/GPU zap） | 私有/无公开文档 | 独立模块 / 数据表 + 说明；**隔离不消灭** |
| 框架级 C4（clk orphan reparent、gdsc、dma-iommu fixed MSI IOVA、arm-smmu） | 需通用复现与论证 | 先查是否已被上游新补丁取代；否则挂账 |
| B1 reboot 钩子、C1 ADSP SPF 分支、D3 待定根因项 | 过渡 | 下游 patchset + 「待上游 X 合入即替换」标记 |
| 11 个发行版 `configs/*.config` 片段（D6）、vk 实验历史（D5）、Q24/Q28 诊断补丁 | 本地实验/发行版 | **从不进上游树**；M1 树已剔除 |

**目标形态**

```
upstream tip（M1 树已就绪：m1/clean-tree，Image.gz + dtbs 全绿，未上机对照）
  + 板 DTS / binding（M3，先修 usb@a600000 红点）
  + 少量新驱动（按子系统分批：A → B5 DSI → B8 camss → B6 ath12k / B3 bt）
  + 下游 patchset（M5：wrappedkey、psci 过渡、私有寄存器块）
  + 实验层（永不进包）
```
**下游层预算**：按审查 D 类 ≈15% 与 C 类挂账推得的量级 = **1–2k 行**（估算，非实测）；超过即说明有东西没被 DT 化或没复用现成驱动。

## 7. 与 M1–M5 的衔接

- M1 已完成「剔 D 类 + 重放」⇒ 本清单 §3/§6 的实验与发行版内容**不在 M1 树内**，符合预期；M1 缺的是**上机功能对照**。
- M2 已投两枚独立补丁（A1 后撤稿 / A2 在评审 / P3 gamma LUT OOB 已发）。
- M3 = §3 的 D7 + 红点清理 ⇒ 后续所有子系统补丁的地基。
- M4 = B8（camss，最大件）与 B6（ath12k）；B5 建议与 Q28 合并做（结构合规化顺带把动态时钟取证整理成可上游形态，一次投入两份收益）。
- M5 = §6 第一行。

## 8. 下一步（按性价比）

1. **把 §1 三问 + §3 违例扫描项固化为提交前门**（`patches/upstream/README.md` 的 checklist；纪律指针在 `.pi/AGENT-OPS.md` §3）。
2. **M3 板支持系列先发**（A5 + D7 清理 + 红点修复）——地基 + `dtbs_check` 硬门。
3. **B5 与 Q28 合并**；B8 camss 单独立项。

## 9. 可执行的合规自检（提交前跑）

```sh
# 1) 逐处 SoC compat 判定（应为 per-SoC cfg，不该散落）
grep -rn 'of_device_is_compatible("qcom,' drivers/ | grep -v 'static const'
# 2) 测试钩子/调试参数（Q3 违例嫌疑）
grep -rn "module_param\|MODULE_PARM_DESC" drivers/ | grep -vE "core|framework"
# 3) 跨模块全局变量（上游必 NAK）
grep -rn "^[a-z].*\bapm_src_port\b" sound/soc/qcom/
# 4) 机械门
scripts/checkpatch.pl --strict --no-tree <series>/*.patch
dtc -@ -I dts -O dtb <board>.dts >/dev/null && dt-validate -s Documentation/devicetree/bindings <board>.dtb
```

## 10. 与其他文档的关系

| 文档 | 关系 |
|---|---|
| `archive/topics/UPSTREAM-REVIEW-2026-10-04.md` | 分级数据源（只增不改）；本文是其**规则化 + 隔离清单化** |
| `TASKS.md` §7 | M1–M5 状态唯一权威；本文只给规则与清单 |
| `.pi/AGENT-OPS.md` §3 | 「主线优先」纪律的入口；本文为其展开 |
| `patches/upstream/m2-2026-10-13/README.md` | M2 投递细节与 checklist 落点 |
