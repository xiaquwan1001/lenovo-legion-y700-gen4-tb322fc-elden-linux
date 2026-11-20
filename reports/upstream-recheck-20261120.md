# 上游系列现态复核（patchwork REST，2026-11-20）

数据源：patchwork.kernel.org API 1.2，project=linux-arm-msm，只看 API 字段（未抓 lore 正文）。
脚本：`/tmp/pw-elden.py`（临时，不在 scripts/）。说明：`q=` 搜索只匹配主题，不匹配投稿人姓名，
所以「我方全量」用 `q=sm8750`/`q=elden`/`q=dwc3`/`q=csiphy`/`q=fastrpc` 取并集后按投稿人 `Qianhui Xu` 过滤得到。

## ① 我方在档补丁总览（按关键词分组，只列最新代 + 计数）

| 系列 | 最新代 patch id | state | 日期 | 历史 |
|---|---|---|---|---|
| a. wl2868c（v12） | 14991614 / 14991615 | new | 2026-11-17 | v9–v11 均 superseded，v8 前共 24 条 |
| b. dwc3 双连接器共享 HS 总线（v9） | 14991612 / 14991613 | new | 2026-11-17 | v2–v8 约 20 条 superseded/handled-elsewhere |
| c. dispcc-sm8750 MDSS reset（RFC） | 14907944 | new | 2026-10-22 | 仅 RFC 一条（M8 v5 未发到 pw 上？见 ③） |
| d. camss SM8750（v2，9/9） | 14920901/14920904–14920909 | handled-elsewhere | 2026-10-28 | 首版 superseded；**v6 未在我名下出现在 patchwork** |
| e. CSIPHY 2.4.0（camss 系列内 [2/9]） | 14920901 | handled-elsewhere | 2026-10-28 | 无独立 RFC/v2 单发条目 |
| f. fastrpc non-secure-domain（v3） | 14971025 | new | 2026-11-11 | v1 14959877、v2 14966246 superseded |
| 其他在档 | elden DTS v7 = 14991580 (new)；MDSS resets [3/3] = 14980389 (new)；CCI = 14931350 (superseded)；battmgr = 14918451（handled-elsewhere，已并入他处）；dpu GC = 14983311 (new) | | 2026-10–11 | |

## ② 逐系列表

| 系列 | state | 最新活动 | 维护者回复 | 我方欠什么 | 主机侧可离线推进 |
|---|---|---|---|---|---|
| M-wl2868c v12 | new，无回复 | 2026-11-17 | 暂无（v12 刚发 3 天） | 等评审；无欠账 | 可（核对 v9→v12 改动清单备答） |
| M3 dwc3 v9 | new | 2026-11-17 | **Rob Herring 2026-11-18 已回**（binding 14991613，确认/追问需读原文） | 回应 Rob（若非纯 ack） | 部分（回信草拟可离线，需读评论文本） |
| M8 dispcc RFC | new | 2026-10-22 | **Taniya Das 已回**（10-22），我方 10-23/10-28 两次答复并承诺「drop the clock-side shape」 | **欠 v5/v6 正式版**（按 Taniya 意见去掉 clock 侧 shape 后重发） | 可（纯代码改+自测对照） |
| M4 camss（我方 v2） | handled-elsewhere，commit_ref 空 ⇒ **未进 mainline/next** | 2026-10-28 | Krzysztof Kozlowski 10-28 回过 bindings | 确认被并入哪条线：**Wenmeng Liu [v7,23]（2026-11-14，含 sm8750 camss/CSIPHY）为现行活线**，我方 v2 patchwork 上无 v6 | 可（比对 v7 与我方 v2 差异） |
| M4 CSIPHY 2.4.0 | 同上（随 camss 系列），未 mainline | 2026-10-28 | 无直接回复 | **已知卡点：还差一次上机出流回归**（v2 未能推进的既定原因） | 否（需上机） |
| M10 fastrpc non-secure-domain v3 | new，无回复 | 2026-11-11 | 暂无 | 等评审（同类 sm6350/sm8[456]50 先例均 accepted） | 可 |
| 附：battmgr power_now | handled-elsewhere | 2026-10-27 | pw 无评论（可能经 mail 直接收） | 无 | — |

state 计数（我方全部在档补丁，按最新代口径）：new 7（wl2868c×2、dwc3×2、dispcc RFC、fastrpc v3、elden v7）·
superseded 大量（旧代全部）· handled-elsewhere 5（camss v2 中仍存的 3 条 + battmgr + dpu GC 之前的 v8 代）· accepted/mainlined 0（commit_ref 全空）。

## ③ 未取到 / 中断

- people API 需要认证，无法按投稿人 id 一把拉全量；改用主题关键词并集 + 投稿人名过滤，2026-10-13 之前的更早补丁未逐一核对。
- **关键词 c 的「M8 v5」在 patchwork 上没有对应条目**（只有 RFC 14907944）——v5 可能未发/发后未入 pw，本轮不重复调研，仅如实标注。
- **我名下「camss v6」在 patchwork 无记录**；现场活线是 Hangxiang Ma 旧 v6（7 月，handled-elsewhere）与 Wenmeng Liu v7（11-14）。是否与 TASKS 背景所指同一「v6」未验证。
- 未抓 lore 正文，Rob Herring / Taniya Das 回复内容只确认了存在与日期，未逐句归纳。

## ④ 复现命令

```
curl -s 'https://patchwork.kernel.org/api/1.2/patches/?q=wl2868c&project=linux-arm-msm&per_page=100&order=-date'
curl -s 'https://patchwork.kernel.org/api/1.2/patches/?q=sm8750&project=linux-arm-msm&per_page=100&order=-date'   # 按 Qianhui Xu 过滤
curl -s 'https://patchwork.kernel.org/api/1.2/patches/14907944/'
curl -s 'https://patchwork.kernel.org/api/1.2/patches/14907944/comments/'
python3 /tmp/pw-elden.py
```

## ⑤ 主会话独立复核（2026-11-20 10:5x，patchwork API 现查，压过 §①–③ 中与本节冲突处）

§①–③ 由子代理产出、**范围偏差两处**，本节为主会话直查原文结果（命令附后）：

| 事实 | 证据（patchwork patch id / 字段） |
|---|---|
| **wl2868c 已到 v12**（不是 §7 台账里的 v11） | `14991614` `[v12,1/2] regulator: dt-bindings: willsemi,wl2868c: add the WL2868C camera PMIC` state=**new** 2026-11-17T05:22:56Z，submitter `Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>`，commit_ref=None |
| **dwc3 已到 v9**（§7 记 v8），且 **Rob Herring 2026-11-18 已回**在 binding 枚 | `14991612` `[v9,3/3] usb: dwc3: select the shared HS data bus with a mux controller` new 2026-11-17T05:21:37Z；comment on `14991613` by `Rob Herring (Arm)` 2026-11-18T15:34:57Z（正文以 ports/endpoints 语义起头） |
| **elden 板 DTS 已到 v7**（§7 无此代记录） | `14991580` `[v7] arm64: dts: qcom: sm8750-lenovo-elden: add Lenovo Legion Y700 Gen4 …` new 2026-11-17T05:20:28Z |
| **M10 fastrpc 已到 v3**（§7 记「1 封」= v1） | `14971025` `[v3] arm64: dts: qcom: sm8750: mark the ADSP fastrpc node as non-secure domain` new 2026-11-11T03:57:31Z |
| **M8 现役系列 = 「drm/msm/mdss: reset all block resets described in DT」3 枚（2026-11-13，v5）**，不是 clk dispcc RFC | arm-msm `14980387`(1/3 binding, handled-elsewhere) / `14980388`(2/3 mdss, handled-elsewhere) / `14980389`(3/3 DTS, **new**)；dri-devel 同系列 `14980395–14980400` 均 new（含 11-13 首轮与重投两批） |
| dispcc-sm8750 clk RFC 仍只有 10-22 那一版 | arm-msm `14907944` new、linux-clk `14907951` awaiting-upstream |
| camss 我方 v2 全部 `handled-elsewhere`、`commit_ref` 空 ⇒ **未进 mainline/next** | `14920901`/`14920904–14920909` handled-elsewhere，2026-10-28 |

**结论（对我方动作的影响）**：
1. `TASKS/README.md` §7 的 M3(wl2868c/dwc3)、M8、M10、M3-DTS 四行**已落后 1–2 代**，下一轮必须按本节回填（本轮只追加本节 + §7 头条指针，不逐行改，避免与正在跑的审查冲突）。
2. 唯一有「维护者未答问题」的是 **dwc3 v9 binding（Rob Herring 11-18）** ⇒ 下一轮第一件事读评论原文并判断是 ack 还是要改。
3. M4 CSIPHY 2.4.0 卡点不变（差一次上机出流回归）。

复现：
```
timeout 30 curl -s 'https://patchwork.kernel.org/api/1.2/patches/14991614/'
timeout 30 curl -s 'https://patchwork.kernel.org/api/1.2/patches/14991613/comments/'
timeout 30 curl -s 'https://patchwork.kernel.org/api/1.2/patches/?project=92&q=MDSS+reset&per_page=20&order=-date'
timeout 30 curl -s 'https://patchwork.kernel.org/api/1.2/patches/?project=331&q=dispcc-sm8750&per_page=20&order=-date'
```
