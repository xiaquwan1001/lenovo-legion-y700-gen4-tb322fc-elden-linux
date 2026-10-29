# USB 双口优先级归因（lane F，2026-10-29）— 中途收口说明

> ⚠ **本条 lane 未产出正文**：它在 21 轮、58 次工具调用后卡在长思考（thinking 增量持续但不再推进
> turn），最终由编排者 `stopped`。为避免误读，本文件只记录「它查到了什么方向」与「正文落在哪」。

## 结论去哪看

- **判据与执行清单**（用户唯一需要的东西）：`reports/usb-dual-port-test-protocol-20261029.md`
  - §2 主测试：长边接 PC（保持 SSH）+ 短边插 PD 充电器
  - §3 四种观测 → 四种归因（固件级单口 / 固件策略拒绝 / 系统 ABI 单口化 / 两口可并存）
  - §7 静态证据（已证项 + 未证实项分开）
- **系列级背景**：`archive/topics/CHARGE-2026-09-30.md` §7/§8（两 connector、两颗 SMB1501、ADSP 管充电）

## lane 实际查到的方向（未落盘，据其工具调用记录复原）

| 方向 | 命中的东西 | 是否已用进正文 |
|---|---|---|
| ADSP 固件字符串 | `aw35615_pd_set_pd_contract…`（PD 控制器 `aw35615`） | 未用（编排者未复核该字符串的含义） |
| 上游充电 ABI | `build/m1-73/drivers/power/supply/qcom_battmgr.c` 的 usb psy 单实例 | 已用 → 协议 §7.2 |
| dwc3 仲裁 | `dwc3` role-mux 的 `mux->ports[0].role` 判定 | 未用（属数据通路，不影响充电） |

## 已证事实基线（不变）

1. 内核**逐口建模**：两个 `usb-c-connector`、两个 `typec/port*`、两个 `ucsi-source-psy-*`、两颗 SMB1501。
2. 上游 `qcom_battmgr` **只注册一个 `usb_psy`** ⇒ 充电功率在 ABI 层没有第二口的位置。
3. **未证实**：ADSP 是否支持双口同时在线；`dl_flags 0x180` 那 4 条 device link 失败的后果；
   短边插 PD 时 ADSP 是否升压。⇒ 只能由物理测试判定。
