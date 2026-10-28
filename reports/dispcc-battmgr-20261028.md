# dispcc RFC 回信（Taniya Das）+ battmgr vendor repo 核查回信（Konrad Dybcio）— 2026-10-28

lane 子代理，范围 = **仅两条轻量线程**：§A dispcc（Q28/M-显示线）、§B battmgr（M2-A2）。
来源分诊：`reports/mail-triage-20261028.md` #6（dispcc）、#8（battmgr）。
**不碰** camss / wl2868c 目录，不改 SSOT README，不动 main，不 merge。

写路径（单写者）：本报告、`TASKS/sessions/2026-10-28-dispcc与battmgr回信.md`、`out/mail-20261028/`。

结论口径：只允许「已证 / 未证实 / 未上机」。

---

## §0 结论（先数字）

| 项 | 结果 |
|---|---|
| A. dispcc 方向 | **接受** Taniya Das 的否决（复位不由 clk driver 驱动）⇒ RFC 原形状作废，改落点 |
| A. 后续形状 | 复位动作移到显示 SW（`msm_mdss_reset()`，已有 upstream 落点）；`lenovo,elden` 闸门随之下沉到显示侧或删除 |
| A. 未解 | 探测顺序约束（dispcc 是 mdss 的 clock/power-domain 提供者 ⇒ mdss 复位发生在 PLL 编程**之后**）—— 回信如实列为开放问题 |
| B. vendor repo 含 QBG/battery？ | **有**（已证）。9 个相关文件在 `HEAD=210981a0ad74` 的 `drivers/power/supply/` |
| B. 我方旧结论「drop 不含该子系统」 | **推翻**。原因是**我方自己的 sparse-checkout 没拉这个目录**，不是厂商没放 |
| B. 厂商 SM8750 真通道 | **`CONFIG_QTI_BATTERY_CHARGER=m`**（`sun_perf/sun_le.config`）；`CONFIG_BATTERY_QCOM_BATTMGR=m` 只在通用 `defconfig` |
| B. 属性重映射？ | **未见重映射**：downstream 的 `BATT_POWER_NOW` 枚举值 = **22**，与 upstream `qcom_battmgr` 的 `BATT_POWER_NOW` **同一个 id** |
| B. power_now 值是否可信 | **仍未证实**。厂商通道存在只证明「固件会应答 slot 22」，不证明该值是真功率 |

---

## §A dispcc-sm8750 RFC（Q28 / 显示线）

### A.1 对方原话（Taniya Das，2026-10-22 22:52 +0800）

Message-ID `<22a87c51-4f8c-49c0-a13a-c11767f10e85@oss.qualcomm.com>`，
`In-Reply-To: <20261022140811.469417-1-xiaqinghuan@mail.ustc.edu.cn>`（我方 RFC 原件）。

> These resets if required should be taken care or triggered from the Display SW driver.
> It is not on to the clock driver to drive these resets. If these are done the complete
> dispcc would be reset and when the PLLs gets reconfigured there should be a flicker
> observed on the display.

两点：① 复位职责属显示 SW，不属 clk driver；② 整块 dispcc 复位 + PLL 重配 ⇒ 闪屏。

### A.2 我方 RFC 原形状（作废）

`patches/upstream/q28-dispcc-2026-10-22/0001-*.patch`：在 `disp_cc_sm8750_probe()` 里
`of_machine_is_compatible("lenovo,elden")` 闸门下直接 `regmap_write()` 三个 BCR
（`DISP_CC_MDSS_CORE_BCR` 0x8000 / `CORE_INT2_BCR` 0xa000 / `RSCC_BCR` 0xc000），
`msleep(50)` 后反序释放，位置在 `clk_taycan_elu_pll_configure()` **之前**。
理由：厂商 bootloader 交棒时 dispcc PLL 已锁、三个块已出复位，内核在**活状态**上再配 PLL
⇒ 冷起 command DMA 超时（`status=0x2200200`）+ 面板 init `-5`。

### A.3 已证：upstream 已有显示侧的复位落点

| 事实 | 证据 |
|---|---|
| `msm_mdss_reset()` 已存在，`assert → msleep(20) → deassert` | `build/m4-base/drivers/gpu/drm/msm/msm_mdss.c:309`（`msm_mdss_init()` 第 372 行调用） |
| 该复位的来源就是 mdss 节点的 `resets` 属性 | `build/m4-base/arch/arm64/boot/dts/qcom/sm8750.dtsi:3074` `resets = <&dispcc DISP_CC_MDSS_CORE_BCR>;` |
| 「持一拍再放」的时序论证 upstream 已接受过 | 同一函数注释：`make it one frame in a typical system`，`msleep(20)` |

⇒ 我方 RFC 的「持 50 ms 再放」并不是新论证，只是已有 upstream 惯例的重复；真正的争议点只有**位置**，
而位置正是 Taniya 指出的地方。**这一条对回信有用**：可以说明我方并非要求在 clk 层另起机制。

### A.4 未解：探测顺序约束（回信如实列为开放问题）

`sm8750.dtsi` 里 mdss 依赖 `&dispcc`（`clocks` + `power-domains = <&dispcc MDSS_GDSC>`）
⇒ **dispcc probe 必然早于 mdss probe**。因此：

- 现在 PLL 编程发生在 dispcc probe 内（`disp_cc_sm8750_probe()` 第 1922–1924 行）；
- 若复位移到 `msm_mdss_reset()`，它跑在 **PLL 编程之后** ⇒ 复位会把刚配好的 PLL 一起打掉，
  正是 Taniya 说的闪屏路径。

三条候选（**均未上机**，不在本轮裁决范围）：

1. 只保留 `CORE_BCR` 单复位（现在 DT 就是这么写的），复位后由 clk 框架按需重配 PLL；
2. 放弃「整块复位」，改在 DPU/DSI 的 **enable 路径**上做 per-encoder 复位（避开 PLL 段）；
3. 放弃内核侧方案，交回 bootloader（`DisableDisplayHW`），内核侧只记录设备树需求。

回信里明确：**不承诺日期**，只确认方向 + 说明形状 + 抛出上面这个顺序问题。

---

## §B battmgr（M2-A2）

### B.1 对方原话（Konrad Dybcio）

三封，`2026-10-22 16:16 +0200` / `2026-10-23 15:55 +0200`（×2 重复投递）/ `2026-10-23 15:57 +0200`：

| Message-ID | 要点 |
|---|---|
| `<52fc4222-508d-4acf-b38a-7b4e5aeff3cb@oss.qualcomm.com>` | 追问 downstream 源码 / 属性是否被重映射 / `power_now` 是否也被禁 |
| `<625f7af0-5977-41e3-a76d-fde8f998ed97@oss.qualcomm.com>` | 「厂商有 GPL2 义务，别打客服」 |
| `<84483ae1-1fbb-4219-a829-5867feb8bb17@oss.qualcomm.com>` | 原话：`Not sure if that's official but i see the drivers are here?` + `https://github.com/lenovo-basements/android_kernel_lenovo_sm8750` |

我方 10-23 那封的说法（已发出，`179276342356.98176…`）是：

> It does NOT contain the battery/QBG path - there is no drivers/power/supply vendor code
> and no qti_battery_charger in the drop at all

**这句是错的**，本轮更正。

### B.2 已证：repo 里有 QBG/battery 路径（GitHub API 单文件核实，未 clone 整仓）

证据文件：`out/mail-20261028/battmgr-verify/`
（`evidence-github-api.txt`、`local-lstree.txt`、`repo.json`、`supply-qcom.json`、`supply_Makefile`、`supply_Kconfig`、`sun_perf.config`、`sun_le.config`、`defconfig`、`qcom_battmgr.c`）。

**仓库元数据**（`GET /repos/lenovo-basements/android_kernel_lenovo_sm8750`）：
`default_branch=main`、`pushed_at=2025-11-09T08:17:15Z`、`size=3485369`、`private=false`、`fork=false`。

**`GET /contents/drivers/power/supply/qcom?ref=main`** → 54 个文件，含
`qti-qbg.c`(78872) `qbg-core.h`(7804) `qbg-sdam.c` `qbg-battery-profile.c` `qbg-iio.h`
`battery.c`(61623) `qpnp-qg.c` `qpnp-smb5.c` `smb5-lib.c` `step-chg-jeita.c` …

**单文件 HTTP 探测**（200 = 存在，404 = 不存在）：

```
200  drivers/power/supply/qti_battery_charger.c     (70657 B, blob 76dcfaca10d4)
200  drivers/power/supply/qcom_battmgr.c            (39375 B, blob 190e8a4cfa97)
200  drivers/power/supply/qcom/qti-qbg.c
200  drivers/power/supply/qcom/qbg-core.h
200  drivers/power/supply/qcom/battery.c
200  drivers/soc/qcom/pmic_glink.c
404  drivers/power/supply/qcom/qti_battery_charger.c   (不在 qcom/ 子目录)
404  drivers/power/supply/qcom/qcom_battmgr.c          (不在 qcom/ 子目录)
```

注意布局：`qti_battery_charger.c` 与 `qcom_battmgr.c` 在 **`drivers/power/supply/` 根**，
QBG 一族在 `drivers/power/supply/qcom/`。

**本地 `git ls-tree`（同一 commit）**：`stock-src/android_kernel_lenovo_sm8750`
`HEAD=210981a0ad749c30080b853d31bc009d9db0592d`（= GitHub `main` tip），
`git ls-tree -r HEAD drivers/power/supply/` 命中 9 个文件（含上面两个 + 7 个 QBG）：

```
drivers/power/supply/qcom/qbg-battery-profile.c  3e86b9f77970
drivers/power/supply/qcom/qbg-battery-profile.h  dcacc3fb4051
drivers/power/supply/qcom/qbg-core.h             c496f4d85c21
drivers/power/supply/qcom/qbg-iio.h              d0afbdf459b8
drivers/power/supply/qcom/qbg-sdam.c             29798d52f549
drivers/power/supply/qcom/qbg-sdam.h             4f2589b44756
drivers/power/supply/qcom/qti-qbg.c              57628645431a
drivers/power/supply/qcom_battmgr.c              190e8a4cfa97
drivers/power/supply/qti_battery_charger.c       76dcfaca10d4
```

### B.3 已证：旧结论错在哪 —— 我方自己的 sparse-checkout

`stock-src/android_kernel_lenovo_sm8750/.git/info/sparse-checkout` 的 cone 只有：

```
/drivers/gpu/drm/msm/  /drivers/mmc/  /arch/arm64/boot/dts/qcom/  /sound/soc/
```

⇒ 工作区 `ls drivers/` 只有 `gpu mmc Kconfig Makefile`，**`drivers/power/` 根本没落地**。
所以「drop 里没有 `drivers/power/supply`」是**我方的检出配置造成的观测假象**，
不是仓库内容缺失。这是一次**观测错误**，不是判断错误的分歧。

### B.4 已证：厂商 SM8750 变体真正用的通道

`arch/arm64/configs/vendor/sun_perf.config:265` 与 `sun_le.config:266`：

```
CONFIG_QTI_BATTERY_CHARGER=m
CONFIG_QTI_BATTERY_GLINK_DEBUG=m
```

`CONFIG_BATTERY_QCOM_BATTMGR=m` 只出现在通用 `arch/arm64/configs/defconfig:286`。
`drivers/power/supply/Makefile`：第 36 行挂 `qcom_battmgr.o`、第 113 行挂 `qti_battery_charger.o`；
`Kconfig`：`config BATTERY_QCOM_BATTMGR`（177）、`config QTI_BATTERY_CHARGER`（425）。

⇒ 厂商 SM8750（`sun` = SM8750）实际编的是 **downstream `qti_battery_charger`**，
upstream 形状的 `qcom_battmgr` 只是留在通用 defconfig 里。

### B.5 已证：属性 id 未见重映射（回答 Konrad 第二问）

`qti_battery_charger.c`：

- `enum battery_property_id { ... BATT_RESISTANCE, BATT_POWER_NOW, BATT_POWER_AVG, ... }`
  ⇒ `BATT_POWER_NOW` = **22**（第 97 行，按枚举顺序数）；
- `batt_prop_map[]` 第 307 行：`[BATT_POWER_NOW] = POWER_SUPPLY_PROP_POWER_NOW`；
- 对用户态 advertise：`battery_props[]` 第 1474 行 `POWER_SUPPLY_PROP_POWER_NOW`；
- 取值路径：`battery_psy_get_prop()` → `get_property_id(pst, prop)` → `read_property_id()`
  → PMIC GLINK `MSG_OWNER_BC` / `pst->opcode_get` 请求，**属性 id 原样发出**，无偏移/无查表重映射。

对比 upstream `qcom_battmgr.c`：`#define BATT_POWER_NOW 22`（第 65 行），
`sm8350_bat_prop_map[POWER_SUPPLY_PROP_POWER_NOW] = BATT_POWER_NOW`（第 420 行），
响应处理 `case BATT_POWER_NOW: battmgr->status.power_now = le32_to_cpu(...)`（第 1173 行）。

⇒ **两条通道用同一个 property id 22**。这支持「没有厂商侧重映射」的说法，
但**不能**推出「slot 22 在本机是真功率」——两者是不同命题。

### B.6 未证实：`power_now` 值本身

厂商通道存在只证明**固件会应答 slot 22**，不证明该值随负载变化。
本轮**无新增设备证据**（未上机）。原提案不变：在 `qcom_battmgr_bat_get_property()` 里
一次性打印 raw slot 22 + `current_now` + `voltage_now` 同一采样，看 raw 是否随负载变化。

### B.7 厂商自己的 `qcom_battmgr.c` 仍是旧副本（旧结论此部分成立）

`out/mail-20261028/battmgr-verify/qcom_battmgr.c`（raw 取回，1416 行）：

```c
enum qcom_battmgr_variant {
	QCOM_BATTMGR_SM8350,
	QCOM_BATTMGR_SC8280XP,
};
```

`grep -c sm8750` = **0**。⇒ 厂商那份 upstream 形状的驱动**没有 SM8750 variant**，
这一点 10-26 的核对结论不变；变的只是「仓库里没有这个子系统」那一句。

### B.8 对 A2 补丁论证的影响

| 旧论证 | 本轮裁决 |
|---|---|
| 「无厂商通道」 | 早已更正（10-26） |
| 「drop 不含该子系统」 | **推翻**（§B.3，我方检出配置所致） |
| 「厂商通道 downstream-only（依赖 `qti_pmic_glink.h`/`battery_charger.h`/`panel_event_notifier.h`），上游 `qcom_battmgr` 无法复用」 | **成立**（`qti_battery_charger.c` 第 23–25 行三个 include；本地 `build/vk151`、`build/base-7.2` 无这些头） |
| 「厂商自己的 `qcom_battmgr.c` 无 SM8750 variant ⇒ 无可参考实现」 | **成立**（§B.7） |
| 补丁形状（保守版：加 SM8750 variant、不注册 `POWER_NOW`） | **不变**，仍待 Konrad 表态 |

---

## §C 发送记录（用户已批准；两封均已发出并归档）

发送通道：USTC（`send-mail-ustc.py --send`，`smtp.ustc.edu.cn:465`，Message-ID 保真）。
草稿文件在 `out/mail-20261028/`，Sent Items 回读原件在 `out/mail-20261028/sent-verify/`。

### C.1 回 Taniya Das（dispcc）

| 项 | 值 |
|---|---|
| 草稿 | `out/mail-20261028/re-taniya-dispcc.txt`（49 行 / 2230 B / 纯 ASCII） |
| To | Taniya Das `<taniya.das@oss.qualcomm.com>`、`linux-arm-msm@vger.kernel.org` |
| Cc | `linux-clk`、`dri-devel`、Bjorn Andersson、Konrad Dybcio、Dmitry Baryshkov、Michael Turquette、Stephen Boyd（按原信头 9 个收件人） |
| In-Reply-To | `<22a87c51-4f8c-49c0-a13a-c11767f10e85@oss.qualcomm.com>` |
| References | `<20261022140811.469417-1-xiaqinghuan@mail.ustc.edu.cn> <22a87c51-…>` |
| **Message-ID** | **`<179318866835.88849.1485640983989491497@mail.ustc.edu.cn>`** |
| Result | **`已发送 OK`**（`2026-10-28 19:57:48 +0800`） |
| Sent Items 回读 | ✅ 命中 Sent Items #190，Message-ID / To / In-Reply-To 逐字一致 |
| lore 归档 | ✅ `/linux-arm-msm/` 命中，时间戳 `2026-10-28T11:57:57Z` |

正文要点：① 接受否决，**RFC 原形状撤回、不再以该形式重发**；② 指出 upstream 已有显示侧落点
（`msm_mdss_reset()` + `sm8750.dtsi` 的 `resets`），我方并未要求新机制，只是挪了位置；
③ 如实给出**顺序约束**（dispcc 是 mdss 的 clock/power-domain 提供者 ⇒ PLL 编程早于 mdss 复位）；
④ 列三个候选形状请她指一个不会被直接否的；⑤ **明确不承诺日期**（"rather come back with measurements than with a schedule"）。

### C.2 回 Konrad Dybcio（battmgr）

| 项 | 值 |
|---|---|
| 草稿 | `out/mail-20261028/re-konrad-battmgr-20261028.txt`（68 行 / 3177 B / 纯 ASCII） |
| To | Konrad Dybcio `<konrad.dybcio@oss.qualcomm.com>`、`linux-pm@vger.kernel.org` |
| Cc | Sebastian Reichel、`linux-arm-msm`、`linux-kernel` |
| In-Reply-To | `<84483ae1-1fbb-4219-a829-5867feb8bb17@oss.qualcomm.com>`（给 repo 的那封） |
| References | 该线程完整链 7 项，末项 = `<84483ae1-…>` |
| **Message-ID** | **`<179318867727.88971.13007415873000488463@mail.ustc.edu.cn>`** |
| Result | **`已发送 OK`**（`2026-10-28 19:57:57 +0800`） |
| Sent Items 回读 | ✅ 命中 Sent Items #191，Message-ID / To / In-Reply-To 逐字一致 |
| lore 归档 | ✅ `/linux-pm/` 命中，时间戳 `2026-10-28T11:57:58Z` |

正文要点：① **明确认错**并给出原因（我方 sparse-checkout 未拉 `drivers/power`）；
② 列 API 核实到的 7 个文件（含 size）；③ 回答「厂商编的是哪条通道」（`QTI_BATTERY_CHARGER=m`）；
④ 回答「是否重映射」（**否**，两条通道都是 property id 22）；
⑤ 明确**不**把「slot 22 有应答」外推成「值可信」；
⑥ 重申两条不变结论（厂商 `qcom_battmgr.c` 无 SM8750 variant；downstream-only 依赖三个上游不收的头）；
⑦ 再问一次保守版取舍，并主动提供「先给 raw 数字」的选项。

### C.3 本轮未做 / 遗留

- `linux-clk` 侧归档未单独确认（Anubis 403 挡 raw；该列表是 Cc 且 `linux-arm-msm` 已归档，同一 Message-ID 已证投递）。
- 两条线程的**技术后续**（dispcc 落点选型、battmgr raw slot 22 采样）均**未上机 / 未证实**，不在本 lane 范围。
- `patches/upstream/q28-dispcc-2026-10-22/README.md` 的「已发送」状态未改（属 SSOT 面，本 lane 单写者边界外）。
