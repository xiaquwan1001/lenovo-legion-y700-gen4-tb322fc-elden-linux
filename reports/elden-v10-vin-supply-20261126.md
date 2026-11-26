# elden 板 DTS v9 2/2「缺 vin*-supply」定因 + v10 备料（2026-11-26）

> **纪律**：本文件是本轮**唯一**新增报告；**未发任何邮件**（`SEND.sh` 未执行）、
> **未 `git commit`** 仓库、未改 `TASKS/`、未改既有报告。产物在
> `patches/upstream/elden-dts-v10-20261126/`（`README.md` / `GATES.md` / `cover.txt` / `SEND.sh` / `logs/`）。
> 上游查证全部只读：`git.kernel.org` 的 `plain/`（内容级）与 `patch/?id=`（提交级）；
> 抓回来的两份原件留档在 `logs/merged-for-7.5-*`。

---

## 0. 结论（一句话）

**判定 (a)：真缺陷——属「描述/建模层」，不属「功能层」。** 根因 = 我们自己在
`willsemi,wl2868c` binding 里写了「一个输入只有在它所供的输出没被板子使用时才可以不描述」，
而本板把 LDO1/2/3/4/5/7 全用了却没写 `vin12/vin34/vin5/vin7-supply`：**schema 不强制
（`dtbs_check` 0 诊断），但 binding 正文的承诺没兑现**，因此 sashiko 这条站得住；
修法 = 四条输入轨全部指向 DT 里已有的那条常开系统轨（`&wl2868c_vsys`）。
`vin6` **不加**（LDO6 本板未引出，`ldo6` 节点也不存在）。

| 项 | 值 |
|---|---|
| 改动文件数 | **1**（`arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`）；另 1/2 只 bump 代次 |
| 门禁 | G0 apply **rc=0**｜G1 checkpatch 1/2 **0E/0W/0C**、2/2 **0E/1W/0C**｜G3 `dt_binding_check`（定向 qcom.yaml）**rc=0**｜G5 `dtbs_check`（无 binding）诊断 **1/0/0**｜G6（+binding）**0/0/0**｜G9 `git am` 2/2 干净、DTB md5 与 apply 路线一致 |
| 上游 | 未投；投递需按 `TASKS/UPSTREAM.md` §7 逐次放行 |

---

## 1. 定因链（判据原文 → 推理 → 结论）

### 1.1 sashiko 原文（v9 2/2，`sashiko-outbox-234477`，`2026-11-26T00:31:11Z`）

逐字（引自 `reports/comm-triage-20261126-d10.md` §3.2 第 3 条）：

> `missing vin*-supply properties on pmic@2f for active LDOs`
>
> The willsemi,wl2868c binding and driver map LDO1/LDO2 to vin12-supply,
> LDO3/LDO4 to vin34-supply, LDO5 to vin5-supply, and LDO7 to vin7-supply, and
> only allow omitting an input supply when the board does not use the outputs
> it feeds.

### 1.2 上游已合入的 binding（`84e67d2ee13f`，`regulator.git for-7.5`）

**取法（内容级，非旁证）**：

```bash
curl -sS 'https://git.kernel.org/pub/scm/linux/kernel/git/broonie/regulator.git/plain/Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml?h=for-7.5'
curl -sS 'https://git.kernel.org/pub/scm/linux/kernel/git/broonie/regulator.git/patch/?id=84e67d2ee13f'
```

- `plain/` 取回 **99 行**，与本地 `patches/upstream/wl2868c-v12-20261117/…` 的 binding **逐字节相同**（`diff` 空）⇒
  **合入的就是我们 v12 的那一版**，没有在合入过程中被改。留档：`logs/merged-for-7.5-willsemi,wl2868c.yaml`。
- `patch/?id=84e67d2ee13f` 头部确认：`From 84e67d2ee13ff7354f86967a64bb982ffa5ae037` / `Tue, 17 Nov 2026 13:22:56 +0800` /
  Subject `regulator: dt-bindings: willsemi,wl2868c: add the WL2868C camera PMIC`。留档：`logs/upstream-for-7.5-binding-commit-84e67d2ee13f.txt`。

**`vin*-supply` 是否 required？→ 都不是 required，只有「VIN7 或 VSYS 至少一个」是 required**（binding 第 66–75 行）：

```yaml
required:
  - compatible
  - reg
  - regulators

anyOf:
  - required:
      - vin7-supply
  - required:
      - vsys-supply
```

**正文（`description`，binding 第 18–21 行）原文**：

```yaml
  VIN7 and VSYS feed the internal control logic, which is powered from the
  higher of the two, so at least one of them has to be connected. The other
  inputs only feed LDOs, so an input may be left unconnected on a board that
  does not use the outputs it feeds, which is why they are not mandatory.
```

⇒ 这句话是 sashiko 那条意见的出处：**「输入可以不接」的成立条件是「它所供的输出版子不用」**。
本板 LDO1/2/3/4/5/7 全在用 ⇒ 条件不成立 ⇒ 该描述的四条输入轨没描述，**正是这条正文的反面**。

同时也要说清另一半事实：**schema 层没有把它写成硬约束**（没有 `dependencies`/`if-then` 把
「ldo 节点存在」和「对应 vin*-supply 存在」绑起来）。所以：

- `dtbs_check` **查不出来**：v9 自己的 G8 账（`patches/upstream/elden-dts-v9-20261126/GATES.md`
  的 G8、`logs/dtbs-check-3dtb-with-wl2868c-binding-20261126.log`）就是「加 binding 后 0 诊断」；
  本轮 v10 复跑同一门，仍是 **0/0/0**（§4 G6）。
- 也就是说：**sashiko 说的是正文承诺，不是 schema 规则**。这条要按「文档/建模完整性」判，
  不能按「是否有机器门」判。

### 1.3 driver（`602f57223457`）在缺 supply 时的行为——**不是 devm_regulator_get，是 dummy 兜住**

上游 `for-7.5` 的 `drivers/regulator/wl2868c-regulator.c`（301 行）与本地 v12 2/2 **逐字节相同**
（`diff` 空）。两处关键事实：

1. **七个 LDO 的 `supply_name` 就是 `vin12`/`vin34`/`vin5`/`vin6`/`vin7`**（第 137、149–155 行）：

```c
	.supply_name = _supply,				\
…
	WL2868C_LDO(1, "vin12", 496000, 128, 0x03, 0x7f, BIT(0)),
	…
	WL2868C_LDO(7, "vin7", 1504000, 256, 0x09, 0xff, BIT(6)),
```

2. **driver 自己只用 `devm_regulator_get_enable_optional()` 取控制供电**（第 176–189 行），
   并不对 `vin12/34/5` 做任何 `regulator_get`：

```c
	ret = devm_regulator_get_enable_optional(dev, "vsys");
	if (ret != -ENODEV)
		return ret;

	ret = devm_regulator_get_enable_optional(dev, "vin7");
```

那么「没有 `vin12-supply`」在内核里到底发生什么（`build/elden-tree` = v7.4-rc3，行号现查）：

- `regulator_register()` → `rdev->supply_name = regulator_desc->supply_name`（`core.c:6131-6133`）。
- `regulator_resolve_supply()`（`core.c:2191`）：先在 **regulator 子节点**（`ldo1`）上找
  `<supply_name>-supply`；找不到再退到 **`rdev->dev.parent`**（= i2c 设备 `pmic@2f`）上找
  （`core.c:2211-2217`；`rdev->dev.parent = config->dev` 见 `core.c:6136`）。
  ⇒ **`vin12-supply` 写在 `pmic@2f` 上是能被解析的**（这也是 `isl9305` 等既有 binding 的形状，见 1.5）。
- 两处都找不到时：`have_full_constraints()`（`core.c:131` = `has_full_constraints || of_have_populated_dt()`）
  在 DT 启动下恒真 ⇒ **用 `dummy_regulator_rdev` 代替，probe 不失败、也不打 warning**
  （`core.c:2226-2235`）。

⇒ **功能层零影响**：本板 LDO 照样能 enable（下游 vendorkernel 实测：`reports/trials/20261023T115447Z-q28disp-v2/dmesg.txt:818`
`[camera] loaded wl2868c-regulator`，且整份 dmesg **没有** `Failed to resolve *-supply` /
`supply vin* not found` 任何一行）。
⇒ 但**描述层**丢了信息：DT 没记「这四路输入从哪来」，内核把它们的父供电当 dummy，谁读 DT 都以为悬空。

留档：`logs/kernel-side-evidence-core.c.txt`（`core.c` 与 `of_regulator.c` 原文摘录 + 行号）。

### 1.4 我方 v9 2/2 的 `pmic@2f` 实况（逐条）

`patches/upstream/elden-dts-v9-20261126/v9-0002-…patch`：

| LDO 节点 | `regulator-min/max-microvolt` | 喂谁（2/2 提交信息） | 输入轨（driver `supply_name`） | v9 是否声明 |
|---|---|---|---|---|
| `ldo1` | 1128000 / 1128000 | 后摄 DVDD | `vin12` | **缺** |
| `ldo2` | 1288000 / 1288000 | 前摄 DVDD | `vin12` | **缺** |
| `ldo3` | 2816000 / 2816000 | 前摄 AVDD | `vin34` | **缺** |
| `ldo4` | 2824000 / 2824000 | 后摄 AVDD | `vin34` | **缺** |
| `ldo5` | 2808000 / 2808000 | VCM VDD | `vin5` | **缺** |
| `ldo6` | ——（节点不存在，本板未引出） | — | `vin6` | 不需要（正确） |
| `ldo7` | 1800000 / 1800000 | 两摄 DOVDD + VCM VDDIO | `vin7` | **缺** |
| `vsys-supply` | —（控制供电/ I2C） | — | `vsys` | **有**（`=&wl2868c_vsys`） |

⇒ 缺的正是 sashiko 点的四条：**`vin12` / `vin34` / `vin5` / `vin7`**；`vin6` 缺席是对的。

### 1.5 同类既有形状（证明「多个输入指同一个 always-on regulator」是 upstream 接受写法）

`build/elden-tree/Documentation/devicetree/bindings/regulator/isl9305.txt`（例子里四个输入全指
同一个 regulator，且都写在**设备节点**上、子 regulator 在 `regulators` 下）：

```
	pmic: isl9305@68 {
		compatible = "isil,isl9305";
		reg = <0x68>;

		VINDCD1-supply = <&system_power>;
		VINDCD2-supply = <&system_power>;
		VINLDO1-supply = <&system_power>;
		VINLDO2-supply = <&system_power>;

		regulators {
			dcd1 { … };
		};
	};
```

我们的 driver 结构（`desc->regulators_node = "regulators"` + `desc->supply_name`）与 `isl9305`
同类 ⇒ 写到 `pmic@2f` 上、四个指同一个 phandle，两个层面都有先例。

---

## 2. 判定：(a) 真缺陷，但不是功能 bug（判据逐条）

**支持 (a) 的判据**

1. 缺陷的**定义域**是 binding 正文：`"an input may be left unconnected on a board that does not
   use the outputs it feeds"`（§1.2 原文）。本板 LDO1–5、7 全用 ⇒ 前提不成立。**这是我们自己写的
   句子**，不能用「误报」反驳自己。
2. `dtbs_check` 干净只说明**schema 表达力不足**（无法表达「ldo 存在 ⇒ 输入必须存在」），
   不说明 DT 完整。把「机器门绿」当成「没问题」在这里是错的判据。
3. 补齐零成本、零行为变化（§1.3），且不补的代价是 DT 里永久留一条「来源不明」的供电。

**反对把它算成「功能缺陷」的判据（也写清，避免过度声称）**

1. driver 不 request `vin12/34/5`，只 request 控制供电（`vsys`→`vin7` 回退）；缺 supply 时
   `regulator_resolve_supply()` 用 dummy 兜住，**probe 不失败**（§1.3 代码 + 下游 dmesg 实测）。
2. 因此若有人只按「会不会坏」判，这条是 Low 而不是 Medium；但**报的是 DT 完整性**，
   Medium 也不算离谱。

**因此**：结论取 (a)，改动按「描述补齐」的最小形式做，**不引入任何新的供电/时序行为**。

---

## 3. v10 改动（1 个文件）

`patches/upstream/elden-dts-v10-20261126/v10-0002-…patch`，`sm8750-lenovo-elden.dts`：

```diff
 	pmic@2f {
 		…
 		pinctrl-0 = <&camera_pmic_default>;
+		vin12-supply = <&wl2868c_vsys>;
+		vin34-supply = <&wl2868c_vsys>;
+		vin5-supply = <&wl2868c_vsys>;
+		vin7-supply = <&wl2868c_vsys>;
 		vsys-supply = <&wl2868c_vsys>;
```

外加该 `regulator-fixed` 上注释扩写（原来只说 VSYS，现在说 VSYS + 四个 LDO 输入）：

```diff
-	 * VSYS of the camera PMIC is the always-on system rail of the tablet.
-	 * The SPMI PMICs that generate it are not described yet, so it is
-	 * modelled as a fixed regulator without a voltage constraint.
+	 * The camera PMIC is fed from the always-on system rail of the tablet:
+	 * VSYS, which powers its control logic and its I2C interface, and the
+	 * four LDO inputs.  The SPMI PMICs that generate this rail are not
+	 * described yet, so it is modelled as a fixed regulator without a
+	 * voltage constraint.
```

**为什么四条都指 `&wl2868c_vsys`（而不是另起节点/指向 PMIC 输出）**

- 本板这五路输入同属**一条常开系统轨**；DT 里这条轨**只被建模了一次**（`regulator-fixed`，
  因为生成它的 SPMI PMIC 还没描述——这条从 v6 起就是这么写的）。多起一个节点等于给同一条轨
  造两个身份。
- 形状有 upstream 先例：`isl9305` 的四个 `VIN*-supply` 全指 `&system_power`（§1.5）。
- 等 SPMI PMIC 描述后，`vsys-supply` 与这四条**一起**改指真实 regulator（一次动作，不是遗留 hack）。
- **不加 `vin6-supply`**：LDO6 未引出、`ldo6` 节点不存在，加了反而描述不存在的硬件。

---

## 4. 门禁（逐条跑，原始输出在 `patches/upstream/elden-dts-v10-20261126/logs/`）

槽位：`build-slot take y700-elden:elden-dts-v10 --jobs 8` → id `125018-1370009-y700-elden_elden-dts-v10`；结束已 `drop`。
基线：`build/elden-tree` 的 detached worktree `aebb72744764`（Linux 7.4-rc3，与 v8/v9 同基线）。

| 门 | 命令要点 | rc | 诊断数 / 关键输出 |
|---|---|---|---|
| G0 apply | `git apply --check -v` ×2 | **0** | 无 offset / 无 fuzz；`logs/apply-check-verbose-20261126.txt` |
| G1 blob | `git hash-object` | 0 | `a32cfb30a1` / `e0b65a36c5` / `d8e9ab1272` = 两枚 patch 的 `index` 右值 |
| G2 checkpatch | `perl scripts/checkpatch.pl --no-tree --strict --no-signoff - < <patch>` | 0 / 0 | 1/2 **0E/0W/0C**；2/2 **0E/1W/0C**（唯一 W = 新文件 "does MAINTAINERS need updating?"，`ARM/QUALCOMM SUPPORT` 已覆盖该目录，v7/v8/v9 同款不修） |
| G3 dt_binding_check | 定向 `DT_SCHEMA_FILES=…/arm/qcom.yaml`（1/2 改了 binding） | **0** | 静默；`logs/dt-binding-check-qcomyaml-20261126.log` |
| G4 dt-doc-validate | `dt-doc-validate …/arm/qcom.yaml` | **0** | 无输出 |
| G5 dtbs_check | `CHECK_DTBS=1` `qcom/sm8750-lenovo-elden.dtb qcom/sm8750-mtp.dtb qcom/sm8750-qrd.dtb`，**未**加 wl2868c binding | **0** | 3/3 `DTC [C]`；诊断 **1 / 0 / 0**（唯一那条 = v9 同款 `failed to match any schema with compatible: ['willsemi,wl2868c']`） |
| G6 同树 + binding 重跑 G5 | 先 `git apply` `wl2868c-v12` 1/2 | **0** | 3/3 `DTC [C]`；诊断 **0 / 0 / 0**（binding `additionalProperties: false`，属性名拼错会被点名 ⇒ 属性名与 merged binding 逐字一致由此门证过） |
| G7 DTB md5 | `md5sum` | — | elden `50f7cede1d01a45f9c1eb647b4577cc4`（v9 `4707d3defd057e70e3aa5216320ac777`，本机重编 v9 复现了该值）；mtp `ecc158767f04c8facf5fde6735b339da` **不变** |
| G8 DTB 反编译 diff | `dtc -I dtb -O dts` 两版后 `diff -u` | 1（有差异，如预期） | **只多 4 行 `vin*-supply`**，其余逐字节相同；`logs/dtb-decompile-diff-v9-vs-v10.txt` |
| G9 `git am` 路线 | `git am --keep-cr` ×2 + defconfig + 编单 dtb | **0** | 2/2 干净，日期 `2026-11-26 21:00:00 +0800`，DTB md5 与 G7 **逐字节相同** |
| G10 上机 | — | **未跑** | 板件无 SPMI/RPMh/console 描述，起不到 shell；本文件任何「通过」都不含启动 |
| G11 发信 | — | **未跑** | `SEND.sh` **未执行**（连 `--dry-run` 都没跑）；脚本 `bash -n` 语法过 |

G8 原始输出（去掉 dtc 对 `sm8750.dtsi` 的 18 条既有告警，两版完全相同）：

```
--- /tmp/v9-dtb.dts
+++ /tmp/v10-dtb.dts
@@ -794,6 +794,10 @@
 					reset-gpios = <0x36 0x7e 0x01>;
 					pinctrl-names = "default";
 					pinctrl-0 = <0x37>;
+					vin12-supply = <0x38>;
+					vin34-supply = <0x38>;
+					vin5-supply = <0x38>;
+					vin7-supply = <0x38>;
 					vsys-supply = <0x38>;
```

G5 / G6 原始输出：

```
# G5（无 binding）
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-mtp.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-qrd.dtb
arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb: /soc@0/geniqup@8c0000/i2c@888000/pmic@2f: failed to match any schema with compatible: ['willsemi,wl2868c']

# G6（+ wl2868c binding）
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-mtp.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-qrd.dtb
```

**未跑的门与理由**：全量 `dt_binding_check`（1/2 与 v9 1/2 diff 段逐字节相同，v9 已跑全量
rc=0 / 5420 `DTC [C]` / 0 err-warn；2/2 不动 binding ⇒ 只跑定向门）；上机（见 G10）。

---

## 5. v10 备料清单（`patches/upstream/elden-dts-v10-20261126/`）

| 文件 | 内容 |
|---|---|
| `v10-0000-cover-letter.patch` | cover：`Waiting on bindings`（Krzysztof 要求，仍在第 13 行）+ 新增 `What v10 changes in 2/2` + **逐条答 sashiko 三条** + `Changes since v9` + AI 披露 |
| `v10-0001-…qcom.yaml…patch` | 1/2：diff 段与 v9 1/2 逐字节相同，只 bump 代次 |
| `v10-0002-…sm8750-lenovo-elden…patch` | 2/2：四条 supply + 注释 + `Changes in v10` |
| `cover.txt` | cover 正文（纯文本，便于人工复用） |
| `README.md` / `GATES.md` / `SEND.sh` / `SHA256SUMS` / `logs/` | 备料说明 / 门禁账 / 投递脚本（默认 `local`，`--send` 才真发）/ 校验和 / 原始输出 |

**投递前需作者/编排者定的一件事**：`1/2` 的 `Acked-by: Krzysztof Kozlowski`（`2026-11-25T12:04:02Z`，
v9 投出前 12 h 给过）本轮**没写进补丁体**（任务口径 = 只改需要的那个文件）。要带就插在
`Signed-off-by` 后一行并重算 `SHA256SUMS`；不带也不影响 b4 自取。**本目录未做此步**。

---

## 6. 残余风险 / 未证（投递前应知道）

1. **无原理图**：VIN12/VIN34/VIN5/VIN7 具体接到哪条轨，是**由本板既有 DT 建模 + 电气可行性推断**
   （`wl2868c_vsys` 是本板唯一建模的常开系统轨；四路 LDO 输出 1.128–2.824 V 均可由该轨降压得到），
   **不是从原理图或 datasheet 的 pin 级连接读出来的**。若原理图显示某路输入来自别的常开轨
   （例如 PMIC 的某路 LDO），v10 这四条 phandle 就需改指——但那时同样是一次动作，
   不会比现在多花成本。
2. **VIN12 的输入上限未知**（本地没有 WL2868C datasheet 原件；binding 只描述输出范围）：
   若 VIN12 abs max 低于系统轨电压，则 VIN12 必然另有 1.8 V 类常开轨 ⇒ 落到风险 1。
   这一条**只有原理图/datasheet 能证伪**，本报告不假装证过。
3. **SPMI PMIC 未描述** ⇒ 五条 supply 全部指向 placeholder `regulator-fixed`；
   等 SPMI/RPMh 描述进树，需要一次性改指（cover 已如实写明这一点，避免以后被当成「写错」）。
4. **上游口味风险**：维护者也可能认为「inputs 既然 optional，就等 SPMI 描述完再补」。
   cover 已把理由与 isl9305 先例写出来，并说明功能上零变化，属于「给 reviewer 一个能点头的说法」。

---

## 6b. 父代理裁决（2026-11-26 晚，已落地）

- **措辞被改**：本报告 §6-1/§6-2 自己承认「无原理图、VIN12 上限未知」，因此补丁正文里
  「四路输入与 VSYS 同轨」的**推断**不能按事实写。已改为显式 stand-in（「SPMI PMIC 未描述，五条输入
  指向同一个 placeholder；板上实际连线不在本 DTS 的推导来源里」），DTS 注释同义改写。
- **顺带发现并修掉一个真缺陷**：改措辞后正文多 1 行但 `@@ -0,0 +1,135 @@` 未同步 ⇒ `git apply` 会吃掉
  文件末尾 `};`（`dtc: syntax error 135.4-136.1`，已复现）。计数改 `+1,136` 后 2/2 干净、136 行完整。
- **重跑判据**（父代理）：checkpatch 1/2 0E/0W/0C、2/2 0E/1W/0C；只重编 elden DTB 得
  `50f7cede1d01a45f9c1eb647b4577cc4` = 修订前 G7 值**逐字节相同** ⇒ 纯注释改动，`dtbs_check` 结论沿用。
  详账 = 目录内 `GATES.md` §12。

## 7. 推荐下一步

1. **不自动投**：投 v10 需按 `TASKS/UPSTREAM.md` §7 放行；放行前作者定 §5 那条 `Acked-by` 取舍。
2. 若能拿到原理图（或 WL2868C datasheet 的 VIN12 输入范围），把 §6-1/2 从「推断」升级为「实测」，
   再决定 v10 是否按现形投出。
3. 台账侧（本 lane 不写）：`TASKS/UPSTREAM.md` 的 elden 行、`TASKS/dim/D10.md` 应记
   「v10 备料完成、判定 (a)、未投」；`reports/comm-triage-20261126-d10.md` §7-1 的「待裁决」可据此关闭。
