# wl2868c v6（2026-11-04）— 系列说明与答复要点

> **状态：已投 `[PATCH v6 0/5]`（2026-11-04 03:26Z，6 封全 `Result: 250`，cover `<20261104032648.209747-1-xiaqinghuan@mail.ustc.edu.cn>`）**；报告 `reports/mail-send-20261104-wl2868c-v6-dwc3.md`；后续 v7/v8/v9 见 `../wl2868c-v7-20261106/`、`../wl2868c-v9-20261107/`。
> 本轮未 commit 主仓、未 `git send-email`、未碰设备、未改 SSOT 文档。
> 分支：`build/wl-v2` @ `wl2868c-v6`（不在主仓）。
> base commit（40 位）：**`05441d697f7f9a927264f4058cbbc6a03dfcac9d`**（torvalds master，`v7.3-20183-g05441d697f7f`，2026-11-03）。
> 系列 tip（40 位）：`2a533369566710c78ff82d545fb17454ea332df8`。

## 1. 系列构成（5 枚，+466 行 / 8 文件）

| # | 主题 | 文件 | 行 |
|---|---|---|---|
| 1/5 | `regulator: dt-bindings: willsemi,wl2868c: add the WL2868C camera PMIC` | `…/bindings/regulator/willsemi,wl2868c.yaml`（新） | +104 |
| 2/5 | `regulator: willsemi,wl2868c: add the WL2868C camera PMIC driver` | `drivers/regulator/wl2868c-regulator.c`（新）、Kconfig、Makefile、MAINTAINERS | +231 |
| 3/5 | `dt-bindings: arm: qcom: document the Lenovo Legion Y700 Gen4` | `…/bindings/arm/qcom.yaml` | +1 |
| 4/5 | `arm64: dts: qcom: sm8750-lenovo-elden: add the Lenovo Legion Y700 Gen4` | 板 DTS（新）+ dts Makefile | +51 |
| 5/5 | `arm64: dts: qcom: sm8750-lenovo-elden: describe the WL2868C regulators` | 板 DTS | +79 |

对照 v5 的结构变化：
- **删掉 sm8750 CCI 那一枚**（v5 3/4，+156 行）⇒ 系列从 4 枚变 5 枚（净少 CCI、拆出 qcom.yaml、板 DTS 拆骨架+PMIC）。
- **`arm/qcom.yaml` 独立成 3/5**（Conor #2）。
- **板 DTS 拆两枚**：4/5 骨架（compatible/chassis-type/reserved GPIO/board clocks），5/5 WL2868C 节点与 LDO。
- 相机消费节点（`giantec,gt9764`、`samsung,s5kjns`、endpoint、`rear_camera_default` pinctrl）**全部移出**——它们挂在 `cci0_i2c0` 上，而 CCI 已让路。

## 2. cover 草稿

见 `v6-0000-cover-letter.patch`（`git format-patch --cover-letter` 生成，正文已填好，可直接 `git send-email`）。
要点顺序：AI 披露 → 系列简介 → `Changes in v6` 六条（重定 base/CCI 让路/qcom.yaml 拆出/binding 增 vsys/驱动整字节写/板 DTS 拆分 + board clocks 理由 + VSYS 说明）→ 验证声明 → 「未上机」声明。

发送注意（沿用 11-04 分诊 §1d/§3 B10 的地址纪律）：
- regulator 补丁**不要**再发 `linux-regulator@vger.kernel.org`（该 vger 列表不存在，v5 因此吃了 5 封 550）；按 `linux/MAINTAINERS` 的「VOLTAGE AND CURRENT REGULATOR FRAMEWORK」走 **LKML** + 维护者 Cc。
- 建议收件：`To: linux-kernel@vger.kernel.org`（regulator 1–2/5 必须）；`To: linux-arm-msm@vger.kernel.org` + `devicetree@vger.kernel.org`（3–5/5）；Cc Liam Girdwood、Mark Brown、Konrad Dybcio、Bjorn Andersson、Rob Herring、Conor Dooley、Krzysztof Kozlowski（均用现用地址）。**具体收件由编排者按 §7 逐次批准执行。**

## 3. 逐条答复要点（发信时直接取用）

### 3.1 给 Mark Brown（apply 失败，`<0b7aa07e-…@sirena.org.uk>`）

> v5 确实 apply 不上：板 DTS 那枚的 `arch/arm64/boot/dts/qcom/Makefile` hunk 以上下文 `sm8650-qrd.dtb` 锚定，而 `sm8650-valve-deckard.dtb`（`f905cb6e60`，"arm64: dts: qcom: sm8650: Add initial Valve Deckard devicetree"）后来被插到同位置，上下文整体失配。
> 复现：在 `05441d697f7f` 上重放 v5 → 0001–0003 rc=0、**0004 `error: 打补丁失败：arch/arm64/boot/dts/qcom/Makefile:406`**；v6 同一 base 上 `git am` 5/5 干净通过（`git diff --quiet` 终态与分支 tip 同树）。
> v6 已重切到 current master（base = `05441d697f7f9a927264f4058cbbc6a03dfcac9d`），并且不再有 CCI 那一枚（见 Konrad 那条）。

### 3.2 给 Conor Dooley（v4 1/4 changes-requested，`<20261102-hedge-parchment-da1dbb0b60be@spud>`）

四条逐条：

1. **「板级 supply 段落与 binding 无关」→ 已删。** binding 提交信息里整段「哪个板子的摄像头吃哪个 LDO」删掉；board 侧内容只在 4/5、5/5 出现。
2. **「`arm/qcom.yaml` 必须拆出」→ 已拆。** 独立成 3/5（`dt-bindings: arm: qcom: document the Lenovo Legion Y700 Gen4`），checkpatch 的 "DT binding docs should be a separate patch" 告警随之消失。
3. **「输入 supply 为什么不是 required」→ 已在 binding description 里写明理由。** 依据：`VIN12/VIN34/VIN5/VIN6/VIN7` 只给 LDO 供电，板上不用对应输出时该输入可悬空，因此只有控制逻辑供电是强制的；这一点写进了 `description`（"an input may be left unconnected on a board that does not use the outputs it feeds"）。
4. **「漏了 `vsys`，`vin7`/`vsys` 至少一个 required」→ 已改。** 新增 `vsys-supply`，并加 `anyOf: [{required: [vin7-supply]}, {required: [vsys-supply]}]`；两处描述都写「internal control logic 由二者中较高者供电」，与你原话一致。板上实际给的是 `vsys-supply = <&wl2868c_vsys>`（常开系统轨，fixed-regulator）。

### 3.3 给 Konrad Dybcio（两条）

1. **CCI 撞车（`<c1e1f708-…@oss.qualcomm.com>`）→ 让路。** SM8750 CCI 那一枚已从系列移除；`sm8750.dtsi` 的 CCI 节点归 Hangxiang Ma 的 series（`<20260618-pakala-camera-v2-2-9fbb729fd242@oss.qualcomm.com>`）。本系列板 DTS 也不再引用 `&cci0`/`&cci0_i2c0`，相机消费节点随该系列一起走。
2. **「板 DTS 为什么重复 bindings 例子里的内容」（board clocks）→ 保留，理由：** 该 `clocks` 段不是 binding 例子的复制——本例子里根本没有 clock 节点；这四个 fixed-clock（`xo_board`、`sleep_clk`、`bi_tcxo_div2`、`bi_tcxo_ao_div2`）是 `sm8750.dtsi` 直接消费的板级输入，任何 SM8750 板文件都必须提供（与 `sm8750-mtp.dts` 同构）。已写进 4/5 的提交信息。

### 3.4 关于 sashiko（bot，不需回信，只并入改动/记录）

- **driver Medium（SYS_EN 顺带点亮别的 LDO）→ 已修。** `wl2868c_enable()` 不再 `regmap_update_bits`，改成整字节写：驱动维护「消费者已使能的 LDO 位集合」，写入 `SYS_EN | 该集合`，因此固件 preset 的其它 LDO 位不会被 SYS_EN 带起来；`disable` 同理，只有最后一个输出关闭时才清 SYS_EN。编译证据：`make W=1 drivers/regulator/` rc=0、0 warning（见 `GATES.md` #4）。
- **CCI 两条（cci2 缺失 / sleep 状态改 `gpio`）→ 只做记录，不改。** CCI 整片已移出本系列，这两条属于 Hangxiang 的 series。
- **gt9764/s5kjns 未进树 + endpoint 无 remote-endpoint → 本系列不再出现这些节点**（随 CCI 让路移出）；对应 binding 已单独投递、仍待合。
- **板 DT 缺 boot 基础设施（SPMI/console/存储，父 supply 是 dummy）→ 未修，未证。** SPMI PMIC 不在本系列（无法上机验证），已在 5/5 提交信息与 cover 里如实写明；VSYS 用 fixed-regulator 兜住 binding 的 required，`VIN*` 干脆不描述而不是造假电压。

## 4. 门禁结果（摘要，逐条命令与输出见 `GATES.md` 与 `gates.log`）

| 门禁 | 结果 |
|---|---|
| checkpatch --strict（stdin） | 5/5 **0 ERROR**；2 条预期内 W（两枚新增文件的 MAINTAINERS 提示） |
| check-series-selfcontained.sh | `PASS=5 FAIL=0 WARN=0`，退出码 0 |
| pristine `git am` 逐枚 | 5/5 rc=0，终态 == 分支 tip（`git diff --quiet`） |
| 驱动 W=1 编译 | rc=0，0 warning（`drivers/regulator/` 与单 .o 均跑） |
| 板 DTB 构建（W=1） | rc=0，0 error，104 044 B；2 条告警来自上游 `sm8750.dtsi` 的 dsi 节点 |
| dt-validate（board dtb） | rc=0，**0 诊断** |
| dt-doc-validate / dt-check-style / dt_binding_check（该 binding） | 全 rc=0 |

## 5. 未证 / 待问

1. **未上机**：i2c10 probe、regulator 注册、LDO 电压、preset 位行为均未实测；driver 修复的证据边界 = 编译 + 代码路径自洽。
2. **VSYS 电压与父 PMIC 未证**：VSYS 建模为无电压约束的 `regulator-fixed`（常开系统轨）；`VIN12/34/5/7` 未描述（父 SPMI PMIC 不在本系列，且未测量）。若维护者要求，只能等板级 PMIC 系列。
3. **`gpio-reserved-ranges = <39 1>, <74 1>`** 沿用 v5（下游板 DTS 口径），本轮未重新取证。
4. **未跑全量 `dtbs_check`**：只跑单板 dtb，避免被无关板既有告警淹没。
5. **收件地址未定稿**：regulator 走 LKML（不走不存在的 `linux-regulator@`）；具体 To/Cc 由编排者批准。

DONE-WL2868C
