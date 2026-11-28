# #752 反向接线（数据线短边 + PD 长边）下 `usb_type` 仍写 `[SDP]`；且假 `v_bus` 样本与「充满后 ICL 写 EINVAL」都会让 `charge-watch` 静默跑偏

**场景**：2026-11-28 早，按 D14③ 反向接线（数据线插短边、PD 插长边）后上机。PD 供电**成立**（9 V 契约、`input_current_limit=5 000 000`、电池 +1.679 A），但 `/run/charge-watch.log` 里出现一段
`SAG v_bus=80000 uV < 4400000 x3 -> drop ICL to 500000 uA` 之后每 2 s 一条 `3000000 -> 500000` 的空转（约 70 s）。

**三条事实（都是本机实测，别再猜）**：
- **A. `usb_type` 不能用来判 PD**：`qcom-battmgr-usb` 报的是**数据口**类型。反向接线下数据口是短边 SDP ⇒ `usb_type` 恒为 `Unknown [SDP] …`，**即使长边在 9 V PD 供电**。判 PD 只认 `voltage_now`（或 `voltage_max`）：>5 V 即不可能是普通 5 V 口。
- **B. `v_bus` 会读到物理不可能的瞬态样本**：插拔/PD 重谈期间实测读到 `80000 µV`（80 mV）。凡「连续 N 次低电压就降档」的判据都必须先过滤 `< 3 V` 的样本，否则一次重谈就能把 ICL 打到 floor。
- **C. 电池 `status=Full` 后 ICL 写返回 `EINVAL`**：`echo 3000000/5000000/900000 > input_current_limit` 三条全失败、读回不变。任何「只在写成功时记日志」的脚本，此时表现为**完全静默**（本案空转段末尾就是这样）。

**判据 / 处置**（已落 `scripts/charge-watch.sh` + 镜像副本，thin: 见 `reports/d14-reverse-wiring-20261128.md`）：
- 读 `v_bus` 后立刻分类：`< 3 V` = 无效样本（不准计入任何判据）；`≥ 5.5 V` = PD 源（只跟随 `current_max`，不跑 SDP 洼地状态机）；其余才进洼地/恢复状态机。
- ICL 写失败要有界记账（首次 + 每 N 次），别让「写不动」静默。
- 自测 13 条断言 + 阴性控制（去掉任一过滤都会红）：`sh scripts/charge-watch.sh --selftest`。

**一句话**：`usb_type` 描述的是**数据口**，PD 描述的是**供电口**；两者在双口接线下本来就可以不一致 —— 判电源只看 `voltage_now`，判数据看 `udc state`。
