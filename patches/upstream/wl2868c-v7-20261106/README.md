# wl2868c — v7 备料（2026-11-06）

> 状态：**备料完成、门禁全绿、未发信**（发信仍由用户按批放行）。
> 上一版 = `patches/upstream/wl2868c-20261104-v6/`（11-04 实投 `[PATCH v6 0/5]`）。
> **本版只有 2 枚**：binding + driver。板 DTS（v6 4/5、5/5）**主动拆出**，内容存 `held-back/`。

## 1. 为什么要拆（这是本轮最重要的判断）

11-04 的 v6 是 5 枚：binding / driver / `arm/qcom.yaml` / 板 DTS / 板上的 WL2868C 稳压器。
三个来源同向否掉了后两枚：

| 谁 | 原话要点 | 指向 |
|---|---|---|
| Krzysztof Kozlowski（11-04 10:30Z） | *"I do not understand why this is a separate patch… One logical action, one commit"* | 5/5 应并入 4/5 |
| Krzysztof Kozlowski（11-04 10:31Z） | *"Board cannot be shipped with such compatible… 'Add Lenovo Legion Y700 Gen4, an Qualcomm SM8750-based tablet'"* | 板 DTS 的定位/措辞 |
| sashiko（`196620`） | 板 DT 是「未验证骨架」：只有 clocks + gpio-reserved-ranges，缺 SPMI/RPMh/console/存储 | 别单发骨架板 DT |
| sashiko（`196621`） | `vin12/34/5/7` 父 supply 未描述 ⇒ 六路 LDO 落 dummy 父 | 板 DT 缺 PMIC |

⇒ v7 的判断：**板使能不是「加这颗芯片的驱动」这一件事**，且它在 PMIC 未描述前无法成立 ⇒ **整段拆出**，
v7 = binding + driver。`arm/qcom.yaml` 的 compatible 与那句 commit message 随板系列一起走（届时就是 Krzysztof 要的措辞）。

## 2. 驱动三处状态一致性修复（sashiko `196615`，3 × Medium）

| # | 原问题 | 修法 |
|---|---|---|
| M1 | `chip->enabled` 从 0 起（`devm_kzalloc`），而硬件 `LDO_ENABLE` 的 per-LDO 位可能已被固件预置 ⇒ **第一次 enable 会把 boot 已开的 LDO 写清** | probe 里读 `WL2868C_LDO_ENABLE` 并把 LDO 位种子进 `chip->enabled`；此后 enable/disable 都携带它 |
| M2 | `vsys-supply` 从未 request/enable（binding 里是 required） | probe 在**读 device ID 之前** `devm_regulator_get_enable(dev, "vsys")`；不是形式问题——I2C 接口由 VIN7/VSYS 中较高者供电，没电则器件根本不应答 |
| M3 | `disable()` 先清 `chip->enabled` 再写寄存器；写失败 ⇒ core 的 use_count 已减、驱动却丢了这一位 ⇒ **下一次 enable 会把仍开着的输出关掉** | 先算新位集 → 写寄存器 → **写成功才提交** `chip->enabled` |

## 3. 系列构成

| 补丁 | 内容 | 相对 v6 |
|---|---|---|
| `0001-regulator-dt-bindings-willsemi-wl2868c-add-the-WL286.patch` | `willsemi,wl2868c.yaml`（七路 LDO、`vin*`/`vsys`、`reset-gpios`、`ldo1..7` 子节点）+ **MAINTAINERS 条目** | 内容未变；MAINTAINERS 从 2/5 挪到 1/2 |
| `0002-regulator-willsemi-wl2868c-add-the-WL2868C-camera-PM.patch` | Kconfig / Makefile / `wl2868c-regulator.c` | 三处修复 + commit message 重写 |

合计 **5 文件 369+/0−**。
`held-back/0001-arm64-dts-qcom-sm8750-lenovo-elden-add-the-Lenovo-Le.patch` = v6 4/5 + 5/5 **合并成一枚**（板 DTS + 稳压器节点 + `arm/qcom.yaml` compatible），
已能在 pristine 上 `dtc` 出 `.dtb`，但**不可单发**（VIN 父 supply 与消费者仍缺）。

## 4. base commit 与生成树

- `base-commit: 24a19b953e2a3d0ea5a8c4951a0ab8f32720c907`（`v7.3-rc7`）
- 树 = `build/m3v2-7.3rc7`，分支 **`wl7b`**（tip `10555ad6cc`）；板系列在 **`wl7board`**（`8de8a5a52b`）
- 重出：`git format-patch -2 --cover-letter --no-signature -o patches/upstream/wl2868c-v7-20261106 HEAD`
  （**cover 需手工补** `Subject: [PATCH v7 0/2] …` 与末尾 `base-commit:`）
- 板件：`git format-patch -1 --no-signature -o …/held-back wl7board`

## 5. ⚠ 顺带查到的 v6 事实（值得记一笔）

v6 的 **4/5 对声明的 base 不可 apply**：它的 `Makefile` 插入点写的是
`dtb-… += sm8650-valve-deckard.dtb` 之后，而 **`v7.3-rc7` 的 `Makefile` 里没有 deckard 这一行**
（`grep -c sm8650-valve-deckard` = 0）⇒ 那一版 4/5 在干净树上 `git am` 必然失败。
本轮重出 held-back 时已改成插在 `sm8750-mtp.dtb` 之前，`dtc` 通过。
（教训：系列必须从 pristine base 生成并跑 `check-series-selfcontained.sh`；v6 4/5 当时没有跑过这一关。）

## 6. 收件人与发送（编排者执行，本 agent 未发）

- **To**：Liam Girdwood、Mark Brown、Rob Herring、Krzysztof Kozlowski、Conor Dooley
- **Cc**：`linux-kernel@vger.kernel.org`、`devicetree@vger.kernel.org`、`linux-arm-msm@vger.kernel.org`
- **不要**再抄 `linux-regulator@vger.kernel.org`（该地址不存在，11-02 批 6 封 550 就是这个坑）
- 发信前：`git send-email --dry-run` 已通过；`b4` 本机仍缺

## 7. 未证 / 已知限制

1. **base 仍是 7.3-rc7**（上游已 `7.4-rc1`）；发信前按 `TASKS` §7 在当前 `regulator/for-next` 上复跑 `git am`。
2. **驱动无 in-tree 用户**（板 DTS 拆出）——cover 已如实写明，并用「板子上跑了几周」的实测作证据；若维护者要求必须带用户，则先落板系列。
3. 三处修复都是状态一致性，**没有 fault-injection 运行期证据**（静态论证 + 编译 + 门禁）。
