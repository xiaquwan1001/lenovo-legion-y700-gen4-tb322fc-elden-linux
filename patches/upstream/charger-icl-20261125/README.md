# charger-icl-20261125 —— `qcom_battmgr` USB 输入限流可写（**备料完成，未投递，等放行**）

> 状态：**v1 系列已成型，只等放行**。投递冻结期 = `../README.md` §3；真发要用户按
> `TASKS/README.md` §7「按系列逐次批准」放行。投递动作 = `bash SEND.sh`（默认 dry-run）→
> 放行后 `bash SEND.sh --yes`。
> 定因：`reports/usb-charging-sdp-limit-20261125.md`；三路径裁决 = `reports/m12-charger-upstream-20261125.md`（选 B）。
> 源码基线：`build/elden-tree` = `v7.4-rc3`（`aebb727447`）。

## 1. 系列内容

| 件 | 说明 |
|---|---|
| `0000-cover-letter.patch` | `[PATCH 0/1]`；正文 = what/why + 上机 A/B 原始样本 + **三条边界** + 未证清单 + 两个 open question；**AI 披露段在 `---` tearline 之下** |
| `0001-power-supply-qcom_battmgr-allow-writing-input-current-limit.patch` | 唯一代码件，**+63/−0**，只动 `drivers/power/supply/qcom_battmgr.c`（本轮未改一字） |
| `GATES.md` | 门禁账（本轮现跑；含与 `TASKS` 记录不一致的两条） |
| `SEND.sh` | 投递脚本，默认 dry-run，`--yes` 真发 |

本稿相对上一版 README（「先 issue 后 `[RFC PATCH]`」口径）的改动，全部来自本轮任务口径：

- 形式从 `[RFC PATCH]` 单枚改为**正式 `[PATCH 0/1]` 系列**（cover + 1 枚）。
- 取消 `linux-usb` 抄送：改动面只在 `drivers/power/supply`，UCSI 那条路为什么不改已写进 cover 正文。
- 收件地址以**现跑** `get_maintainer.pl` 为准 = `sre@kernel.org`（上一版写的是 Collabora 地址；见 `GATES.md` G6）。

补丁做了什么（`0001`，不复述全文）：

1. `sm8350_usb_psy_desc` 加 `.set_property` / `.property_is_writeable`，只放行
   `POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT`。
2. 写入走 `qcom_battmgr_request_property(battmgr, BATTMGR_USB_PROPERTY_SET(0x33), USB_INPUT_CURR_LIMIT(5), limit)`。
3. 值 clamp 到 `[500 mA, max(usb.current_max, 900 mA)]`（µA）；成功后刷 `battmgr->usb.current_limit` 缓存，
   ADSP 的 `battmgr->error` 透传成 errno。
4. `sc8280xp/x1e80100` 变体显式返回 `-EINVAL`（这两家的 USB psy 本来就不暴露 ICL）。
5. 两个变体回调的 switch 都补 `case BATTMGR_USB_PROPERTY_SET`（原先落 `dev_warn("unknown message %#x")`，
   `qcom_battmgr.c:1387/1591`），使应答被识别、错误码不丢。

设计取舍（给评审看的，也是唯一有争议的点）：

- **clamp 下界 = 500 mA**：USB 2.0 已配置 SDP 的允许值，也是本板痛点的目标值。写成驱动策略的代价是
  「用户态想设更低」做不到 —— 已在 cover 的 open questions 里主动问了。
- **不改 UCSI 那条路**：UCSI psy 无 set 路径（`ucsi.c` 无电流类 opcode，`SET_POWER_LEVEL` 只在
  `debugfs.c`），改 `UCSI_TYPEC_DEFAULT_CURRENT` 只改「上报值」，不动 ADSP 实际限流（证据 =
  `reports/m12-charger-upstream-20261125.md` §2）。
- **不新造 PMIC glink charger 客户端**（路径 A）：需要未公开 owner/service，维护者第一问就是
  「为什么不用 `qcom_battmgr`」，暂缓。

## 2. 上机证据（2026-11-25，零写盘 `fastboot boot` 测试核 = **非日常核**）

写-读与 clamp（`/sys/class/power_supply/qcom-battmgr-usb/input_current_limit`）：

| 写入 | 回读 | 说明 |
|---|---|---|
| 1500000 | 900000 | 上限 clamp（`current_max` = 900000）生效 |
| 250000 | 500000 | 下限 clamp 生效 |
| 900000 / 500000 | 同值 | 写路径通；`dmesg \| grep -c "unknown message"` = **0** |

A/B（同一颗测试核；交替 500000 / 900000 各两次，每档 `current_now` 采样 5 次、间隔 4 s；
原始日志在设备 `/var/log/m12-icl-ab.log`，**未回仓**，数值见 `TASKS/README.md` §7 M12 行与本轮
会话复读原文）：

```
usb_type=Unknown [SDP] ...  current_max=900000  bat_status=Charging cap=81
--- set 500000 (read 500000)   cur = -155,    0, -115, -166, -160 mA
--- set 900000 (read 900000)   cur = -161, -274, -482, -488, -495 mA
--- set 500000 (read 500000)   cur = -492, -204, -102, -139, -140 mA
--- set 900000 (read 900000)   cur = -152, -362, -505, -523, -527 mA
unknown_msg=0
```

⇒ **ADSP 不只接受 opcode，限流真的改变了充电行为**（两轮方向一致、可重复）。

⚠ **解读口径（本轮新发现；cover 已按保守口径收窄）**：`TASKS` §7 记作「500 mA 档 ~100–166 mA、
900 mA 档 ~480–527 mA」，但原始样本里 `current_now` **符号全为负**（按 D14 报告 §1.1 的实证，负 = 净放电），
即更高限流档给出**更大负向幅度**；且 900 mA 档第 5 个样本仍在滑动（−495 → −523 → −527），20 s 采样窗
未到稳态。因此 cover 只声称「固件行为随请求档位可重复地变化」，**不**声称「充电电流随档位单调变好 /
净放电被消除」。这条分歧**不改 `0001`、不改 `TASKS`**，留给父代理/用户裁决是否补记。

## 3. 收件人草稿（`get_maintainer.pl` 本轮现跑，原文见 `GATES.md` G6）

| 位置 | 地址 | 依据 |
|---|---|---|
| To | `sre@kernel.org`（Sebastian Reichel） | 现跑唯一 M: 命中（power supply 子系统） |
| Cc | `linux-pm@vger.kernel.org` | 主列表 |
| Cc | `linux-arm-msm@vger.kernel.org` | 平台列表 |
| Cc | `linux-kernel@vger.kernel.org` | `get_maintainer.pl` 默认带 |
| **待裁决** | Bjorn Andersson `<andersson@kernel.org>` / Konrad Dybcio | `get_maintainer.pl` **不**返回（`MAINTAINERS` 无 `qcom_battmgr` 专列），但 Bjorn 是 `qcom_battmgr` 作者 / PMIC glink 协议知情人 ⇒ 抄不抄由用户定；`SEND.sh` 里留了注释行 |

**不发单独 issue**：`qcom_battmgr` 有明确维护者与列表，issue 会分散讨论；cover 正文承担 issue 角色
（问题描述 + 复现 + 拟解）。若被打回「协议层不该由 OS 改」，转 `linux-pm` 讨论贴（不带 patch），
不另开 bugzilla/GitHub issue。

## 4. 与 `TASKS/README.md` §7 记录的矛盾（只标，不改）

| # | `TASKS` 记录 | 本轮实测 | 处理 |
|---|---|---|---|
| C1 | `checkpatch --no-tree -f` **0 error 0 warning**（1824 行） | 同口径 `-f` = **1 error**（trailing whitespace，扫到 diff 上下文行的**假阳性**）/ 0 warning；**正法**（临时空目录、patch 模式）= **0 errors / 1 warning**（`acknowledgement` 拼写建议，落在 commit message） | 记录的「0E/0W」= `-f` 文件模式跳过 patch 级检查的**假绿**（`../README.md` §1 那条坑）。**G2 现为 0E/1W** ⇒ 处置见 `GATES.md` G2 的 P0 |
| C2 | 补丁 **+51 行** | `git show --stat` = **+63/−0**（1 file） | +51 应是 v1（未补 ack case 前）的体量；不改记录 |
| C3 | 补丁 Subject = `[PATCH v2]` | 本系列**从未投递过**（冻结期），首投带 `v2` 会被要求给 v1 链接；cover 按任务要求写 `[PATCH 0/1]` | 首投前用 `git format-patch` 重生成两件（编号自动成 `0/1`、`1/1`，无版本号）⇒ `GATES.md` G7 的 P0；**不改 `0001` 正文** |
| C4 | `0001` commit message 写「reported as 100 mA on **several devices**」 | 我们只在 TB322FC 上实测过 | 未证表述；投前建议收窄成「on this device」（一并进 P0，需放行） |
| C5 | `0001` **没有** AI 披露段（`---` 之下即接 diff） | 项目惯例（`../dwc3-v14-20261124/`、`../sm8750-adsp-nonsecure-20261107/`）= 每枚补丁 `---` 之下带同一段披露 | 一并进 P0（在 `---` 与 diff 之间加披露段，不动 commit body 与 diff） |
| C6 | 上一版 README §4/§5 是「提纲 + 待补证据」占位（含「把结论写在此处，不写预计」） | 上机 A/B 已完成 | 本文件已用实测数据替换；`0001` 未动 |

`0001` **正文（commit message + diff）本轮一个字未改**；所有修订项集中列在 `GATES.md` G7「P0 投前一步」，
放行时一次性做完。

## 5. 还缺什么（真发前必须清的 3 项）

1. **P0 重新生成**（`GATES.md` G7）：`git am` → 改 commit message（拼写 + C4 措辞 + C5 披露段）→
   `git format-patch --cover-letter` ⇒ 用生成件覆盖本目录两枚，再跑 `SEND.sh`。**需放行改 commit message。**
2. **抄送名单裁决**：Bjorn / Konrad 抄不抄（§3「待裁决」行）。
3. **用户放行投递**。放行后：`bash SEND.sh --yes` → 记 `SENT.md`（cover MID + 1 封 Result + lore 命中）→
   更新 `TASKS` §7 M12 行与 `patches/upstream/README.md` §4 索引。

不需要、也**没有**做的：设备侧动作、联网取证、发信、git commit/push（本轮只读主机 + 本目录内新增文件）。

## 6. 复现与回退

- 门禁复跑命令：`GATES.md` §2（均可本机复跑；编译门先 `build-slot take`）。
- 回退：**整目录删除**即可 —— 系列内文件都是新增，仓内其它文件未改；`build/elden-tree` 未被写
  （门禁在 `/tmp/m12-gates` worktree + `O=/tmp/kb-m12` 里做，收尾已清理）。
