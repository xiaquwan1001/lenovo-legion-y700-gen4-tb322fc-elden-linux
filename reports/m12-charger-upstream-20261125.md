# M12 充电控制链上游化调研（2026-11-25，只读）

> 前提（已定因，不改写）：`reports/usb-charging-sdp-limit-20261125.md` —— 数据线（USB2 SDP）下 ADSP 判
> `usb_type=Unknown` ⇒ `input_current_limit` 钉在 100 mA；mainline `qcom_battmgr` 的 USB psy 只读。
> 内核源码基线：`build/elden-tree` = `v7.4-rc3`（`aebb727447`），下文所有 `file:line` 均在该树 `grep/sed` 实测。
> 本轮边界：禁止 ssh/上机、禁止发信/开 issue/MR、禁止改动既有文件；写入仅本文件与
> `patches/upstream/charger-icl-20261125/README.md`。

## 0. 一句话裁决

**上游没有 charger 控制链，但 `qcom_battmgr` 的协议层早就留了「USB 属性可写」的 opcode
（`BATTMGR_USB_PROPERTY_SET 0x33`，`qcom_battmgr.c:79`，全树无引用），只是没人把它接到 power_supply 的
`set_property`** ⇒ 三路径里 **B（扩 `qcom_battmgr` 让 `input_current_limit` 可写）** 成本最低、证据最全、
与本板痛点完全对齐；A 需要 ADSP 侧未文档化的私有协议，C 只能改「上报值」且改前要先证明它不影响 ADSP。

⚠ **本轮联网取证失败**：本会话的工具白名单里**没有** `web_search`/`web_fetch`；本地 headless Firefox 起不来
（`{"error":"firefox exited early (code 0)"}`）；`curl` 直连的归档站点全部被 Anubis WAF 拦在 JS 挑战页
（lore.kernel.org / patchwork.kernel.org / git.kernel.org 的 `?qt=` / elixir.bootlin.com 均返回
`Making sure you're not a bot!`；`www.mail-archive.com/search` = HTTP 404；`html.duckduckgo.com` 连接超时）。
⇒ **§1 与 Q2 的「引入 commit」标为「未核实」，附检索式与目标 URL 供下次一条命令复跑**；
其余结论全部由本地源码实测支撑，未经联网复核的部分一律显式标注。

---

## 1. 联网取证记录（全部 `未核实`，供下一轮复跑）

访问时间均为 **2026-11-25（尝试）**，失败原因统一为 **Anubis WAF / 工具不可用**，不是「查了没有」。

| # | 检索式（lore 公开收件箱 `https://lore.kernel.org/all/?q=<q>`） | 目标 | 结果 |
|---|---|---|---|
| Q1-a | `"pmic glink" charger` | linux-pm / linux-arm-msm | 未能读取（Anubis） |
| Q1-b | `qti_battery_charger` | all | 未能读取（Anubis） |
| Q1-c | `qcom_battmgr` | all | 未能读取（Anubis） |
| Q1-d | `usb_bc` | all | 未能读取（Anubis） |
| Q1-e | `input_current_limit qcom` | all | 未能读取（Anubis） |

patchwork 侧对应查询（`https://patchwork.kernel.org/api/1.2/patches/?project=linux-pm&q=pmic+glink&per_page=50`
与 `...&project=linux-arm-msm&q=charger`）：**API 已能返回 JSON（说明 WAF 单次可过），本轮未取得结果行**
—— 下一轮直接跑这两条即可，注意 Patchwork 的 `q=` 必须带 `project=`。

**因此「2025–2026 有没有人把 charger 作为 PMIC glink 客户端主线化」= 未核实。** 可用的间接判据（本地、可靠）：
`v7.4-rc3` 的 PMIC glink 客户端枚举只有三项（`drivers/soc/qcom/pmic_glink.c:20-24`
`PMIC_GLINK_CLIENT_BATT/ALTMODE/UCSI`），aux device 只会建
`"ucsi"`(:329)、`"altmode"`(:334)、`"power-supply"`(:340)；`include/linux/soc/qcom/pmic_glink.h:11-13`
的 owner id 只有 `BATTMGR 32778 / USBC 32779 / USBC_PAN 32780`，**没有 charger owner**。
⇒ 到 v7.4-rc3 为止，上游**确实不存在** charger 客户端通道（这点不依赖联网）。

## 2. `UCSI_TYPEC_DEFAULT_CURRENT 100` —— 本地可证部分

- 定义：`drivers/usb/typec/ucsi/ucsi.h:525` `#define UCSI_TYPEC_DEFAULT_CURRENT 100`（同组
  `:524 UCSI_TYPEC_VSAFE5V 5000`、`:526 1_5_CURRENT 1500`、`:527 3_0_CURRENT 3000`）。
- 使用点仅两处，语义是「UCSI 拿不到细分型号时给保守值」：
  `psy.c:172 ucsi_psy_get_current_max()` → `:204` 注释 *“UCSI can't tell b/w DCP/CDP or USB2/3x1/3x2 SDP
  chargers”* → `:206` 取 100 mA；`psy.c:212 ucsi_psy_get_current_now()` → `:232/:234` 同样 100 mA。
  这条注释本身就是「为什么不是 500」的答案：PPM 上报的 `PWR_OPMODE` 不区分 SDP 的 USB2/USB3 档位，
  100 mA 是 UCSI 规范里 Default-USB 的下界。
- **引入 commit 与理由：未核实。** 复跑式：
  `https://lore.kernel.org/all/?q=%22UCSI_TYPEC_DEFAULT_CURRENT%22`、
  `https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/log/drivers/usb/typec/ucsi/psy.c`、
  `git log -S'UCSI_TYPEC_DEFAULT_CURRENT' -- drivers/usb/typec/ucsi/`
  （本树 `.git/shallow` ⇒ 本地 `-S` 不可用，会落到 boundary merge commit，**已知不能作证据**）。
- **「默认 USB2 配置态应报 500 mA」有无上游讨论：未核实。** 复跑式：
  `https://lore.kernel.org/all/?q=ucsi+default+usb+current+500+mA`、
  `https://lore.kernel.org/linux-usb/?q=UCSI+TYPEC_DEFAULT_CURRENT`。
- 本地补充（重要，供讨论稿用）：上游 UCSI 驱动**没有** ICL 写入路径 —— `drivers/usb/typec/ucsi/ucsi.h:113-144`
  的 opcode 表里只有 `UCSI_SET_POWER_LEVEL 0x14` / `UCSI_READ_POWER_LEVEL 0x1e`，
  且仅在 `debugfs.c:39-40` 出现，正常路径不发；`ucsi.c` 全文件无 `SET_CURRENT_LIMIT`。
  UCSI psy 的 `power_supply_desc` 只有 `get_property`（`psy.c:326-335`，`:333`），因此
  「改 UCSI 上报值」**对 ADSP 的实际限流没有任何作用通道**，这是路径 C 的硬约束。

## 3. 本轮新增的硬事实：协议层写入口早在树内

| 事实 | 位置（v7.4-rc3，实测） |
|---|---|
| `BATTMGR_USB_PROPERTY_GET 0x32` 在用、`BATTMGR_USB_PROPERTY_SET 0x33` **已定义但全树零引用** | `drivers/power/supply/qcom_battmgr.c:78-79` |
| USB 属性编号里 `USB_INPUT_CURR_LIMIT` = 5 | 同上 `:85` |
| 通用属性读写报文结构（`battery/property/value`）已存在 | `:116-121` |
| 一次请求-响应的封装已存在 | `:344-362 qcom_battmgr_request()` / `:364-378 qcom_battmgr_request_property()` |
| 电池对象已有 writable 先例（`set_property` + `property_is_writeable`） | `:760 qcom_battmgr_bat_is_writeable()`、`:774 qcom_battmgr_bat_set_property()`、`:931-932`（x1e80100 desc） |
| USB 对象只读：`sm8350_usb_props` 有 ICL，desc 只有 `get_property` | `:1069-1077` 属性表、`:1079-1093` desc | 
| USB psy 注册点 | `:1730`（sm8350 变体）、`:1710`（sc8280xp） |

⇒ **路径 B 不是「新造通道」，而是「把已经存在的 `0x33` opcode 接到 power_supply 接口」**。
这同时解释了为什么下游 vendor 的 `qti_battery_charger` 能做到而我们做不到：它走的是另一套私有
owner/service（`pmic_glink.h` 里没有对应 owner id），而 `battmgr` 这条协议本来就有 set。

## 4. 三路径裁决

| 路径 | 改动面 | 工作量 | 上游接受度（判定依据） | 对本板价值 | 裁决 |
|---|---|---|---|---|---|
| **A** 新增 PMIC glink charger 客户端 | `include/linux/soc/qcom/pmic_glink.h` 加 owner id、`drivers/soc/qcom/pmic_glink.c` 加 client 枚举/aux、新驱动（≈1000 行量级） | 大 | **低**：需要 ADSP 侧私有报文的可公开依据；上游现有 `battmgr` 已覆盖同类功能，维护者会先问「为什么不用 `qcom_battmgr`」（政策 `Q2`：有同类就扩展，不新写） | 高（唯一能覆盖 `battmgr` 拿不到的控制项时） | **暂缓**，等 §1 复跑确认无人做，再按「有厂家文档才立项」处理 |
| **B** 扩 `qcom_battmgr`：USB psy 增 `set_property`/`property_is_writeable`，ICL 写入走 `BATTMGR_USB_PROPERTY_SET(0x33)` + `USB_INPUT_CURR_LIMIT(5)` | 单文件 `drivers/power/supply/qcom_battmgr.c`（约 40–60 行，含 variant 判定） | 小 | **中高**：复用树内既有 opcode 与报文结构，与电池 writable 先例同形；主要风险是「ADSP 是否接受、会不会被下一次充电器通知覆盖」——这正是需要实测证据的点 | **直接解决**本板 100 mA 钉死（前提：ADSP 接受 set） | **首选**（先做，随实测证据一起发） |
| **C** 只修 UCSI 上报（`UCSI_TYPEC_DEFAULT_CURRENT` 100→500 或按 `PWR_OPMODE` 细分） | `drivers/usb/typec/ucsi/ucsi.h` + `psy.c` | 最小 | **需先证伪**：① UCSI psy 无 set 路径（`psy.c:333`）、UCSI 驱动不发电流相关命令（`ucsi.c` 无 `SET_CURRENT_LIMIT`；`SET_POWER_LEVEL` 仅在 `debugfs.c:39`）⇒ 改上报值**不改变 ADSP 限流**；② 但会改变用户态（UPower/桌面「充电中/已接电源」判定与预算），属「上报语义修正」独立议题 | **仅语义**：能纠正 `ucsi-source-psy` 的 100 mA 假值，不改净放电 | **单独立项**（低风险讨论稿），不作 M12 主路径 |

对前提报告的补充修正：`reports/usb-charging-sdp-limit-20261125.md` §4 第 3 条「UCSI 默认值……只影响上报值」
方向正确，本轮补上**机制证据**（无 set 路径、无电流类 opcode），可把它从「推测」升级为「已证」。

## 5. 投递前必须补齐的证据（也是 B 的实验设计）

1. **ADSP 接受 set**：`echo 500000 > /sys/class/power_supply/qcom-battmgr-usb/input_current_limit`
   （B 实现后）⇒ 回读 `input_current_limit` = 500000，且 `current_now` 由 403 mA 升到 ≥500 mA（负载 800 mA 时
   净电流改善），`dmesg` 无 `pmic_glink` 超时/错误。反例：写成功但回读仍 100000 ⇒ ADSP 拒绝，需看 `battmgr->error`。
2. **不被覆盖**：写入后等一次充电器状态通知（插拔或 `NOTIF_USB_PROPERTY 0x32`，`:36`）再回读，确认限流保持；
   若被 ADSP 覆盖，需在 `qcom_battmgr.c` 的 notify 路径里重下发，并把这写进 commit message。
3. **无回归**：PD 充电器下 `qcom-battmgr-usb` 行为不变（`usb_type=PD`、ICL 由 ADSP 自己管），
   以及 sc8280xp/x1e80100 变体（`:1710`）不受影响（新代码只在 sm8350 变体生效或加显式 variant 判据）。

## 6. 未核实清单（下一轮一条命令各跑一次）

- Q1 五条 lore 检索 + 两条 patchwork `project=` 查询（§1 表格）。
- Q2 引入 commit 与「应报 500 mA」讨论（§2 三条复跑式）。
- `usb_bc`：本地树 `drivers/usb/typec/` 下**无** `usb_bc`/`bc12` 目录（实测 `ls`），
  上游是否有同名子系统化提案 = 未核实；复跑式 `https://lore.kernel.org/all/?q=usb_bc+typec`。
