# #734 「插着线却充不进电」先查 charge-watch **unit 是否在设备上**（脚本在 ≠ 服务在）

## 现场（2026-11-26，U1 在机，长边数据线 + 短边 PD 线）

用户报：**长边 USB 数据线（连 PC，SSH 走它）+ 短边 PD 充电线**，默认设置下电量往下掉。
设备只读读数（30 s × 6，全稳）：

- `qcom-battmgr-usb/usb_type` = `Unknown [SDP] …`（现场值 **SDP**，`#726`）
- `input_current_limit = 100000`，`current_max = 900000`
- `qcom-battmgr-bat/current_now` = **−748 … −804 mA**，`capacity` 25%，而 `status` 仍写 `Charging`（该字段别信）
- `typec/port0-partner`（长边/PC）`supports_usb_power_delivery=no`；`port1-partner`（短边/PD）`=yes`
  但 `ucsi-source-psy-pmic_glink.ucsi.02` 是 `current_max=0 / voltage_now=0` ⇒ **PD 契约在、不取电**（Q35 口径：ADSP 只吃长边）

## 根因（不是缺能力，是接线丢了）

设备上 `charge-watch.sh` / `charge-ctl.sh` **逐字节等于仓内 `scripts/`**，但：

```
systemctl is-enabled charge-watch.service  → not-found
systemctl is-active  charge-watch.service  → inactive
/run/charge-watch.log                      → 不存在
```

⇒ 脚本注释里的启动路径是 **Alpine 的 `/init` + `patch-init-charge.sh`**；并根到 Debian+systemd 后没有任何 unit 接它
（同族：`#689`/`#700` 重建根丢「启动接线」，脚本本身还在）。于是 ADSP 默认的 100 mA 没人顶回 ⇒ 净放电。

## 判据（三档 A/B，同一根线同一台 PC）

| ICL | USB 取电 | 电池电流 | 结论 |
|---|---|---|---|
| 100 mA（默认） | 403 mA @ 5.53 V | −770 mA | 净放电 |
| 500 mA（USB 规范 SDP 上限） | 494 mA @ 4.74 V | **−270 mA** | **按规范设也不够**（系统负载 ≈0.77–1.0 A） |
| 900 mA（= `current_max`） | 891 mA @ 4.52–4.57 V | **+126 … +137 mA** | 转正、180 s 稳定 |

⚠ 900 mA 档是**超 SDP 规范取电**，`v_bus` 洼到 4.52 V（< 4.75 V 下限）⇒ 该 PC 端口在超载；换限流更严的端口可能被掐。

## 处置

- **①** 装 unit 并启用（已执行，2026-11-26 10:58 CST）：
   `install -m 644 packaging/elden-userland/out/units/systemd/charge-watch.service /etc/systemd/system/` →
   `systemctl daemon-reload && systemctl enable --now charge-watch.service`
- **②** 验证：`is-enabled=enabled` / `is-active=active`；日志 `input_current_limit 100000 -> 900000 uA`；
   **手工按回 100000 后 ≤2 s 被顶回 900000**（等价于重插重置），电池电流转 +。
- **③** 还没做：把该 unit 纳入 `deploy-desktop-shell.sh`/`stage.sh` 部署面（否则下次重建根再丢一次）+ 电压洼地保护。

## 通则

「功能有脚本、行为却不发生」时，先查 **`systemctl is-enabled/is-active` 与 `/etc/systemd/system/*.wants/`**，
不要查驱动、不要查 ADSP；并根/换 init 系统之后，所有「由 `/init` 拉起」的脚本都要重新接一遍 systemd。

详情与命令块：`reports/usb-charging-dualport-20261126.md`；上游侧（ICL 可写来源）= `reports/m12-daily-already-writable-20261125.md`。

## 追加（同日 11:2x，同一条链的第二课）：洼地阈值不能用「USB 规范电压」当门

第一版 sag guard 写「连续 3 次 `v_bus` < **4.60 V** 就降档」⇒ 上机立刻触发：

```
SAG v_bus=4470000 uV < 4600000 x3 -> drop ICL to 700000 uA (protect host port)
```

降档后电池又回到 **−284 mA**（净放电），而同一根线 900 mA 档已稳定跑 3 min、`v_bus` 4.47–4.52 V 从未被端口掐断
⇒ **4.5 V 附近是这台 PC 端口在 891 mA 下的稳态 droop，不是塌陷**。

- 处置：`SAG_UV=4.40 V`（真塌陷才算）、`ICL_FLOOR=500 mA`（端口优先，此档可能仍净放电 = 已知代价）、
  `RECOVER_UV=4.60 V × 15 次`、`MAX_TRIES=2`。改后 60 s × 12 采样：ICL 恒定 900 mA、零降档、电池 +32…75 mA。
- 判据自证：`bash scripts/charge-watch.sh --selftest`（假 sysfs 驱动真状态机，7 组 10 断言全 PASS）。
- 部署面：`deploy-desktop-shell.sh` **§17**（脚本逐字节一致 / unit enabled+active / online 时 ICL≥500000），
  设备 `--check` MISS 3→0 且幂等。
- 通则：**保护阈值必须用本机实测的「坏」分布定**，照规范值（4.75/4.60 V）定会把正常负载判成故障，
  而误降档的代价（净放电）比它要防的风险（端口 OCP）更常发生。

## 追加（2026-11-26 20:2x，整理轮复核）：三档表只对 **SDP-only** 成立，短边 PD 在位时是另一档

本页与 `INDEX.md` §0 ⑨ 记的「900 mA 上限 / `v_bus` 4.40 V floor」是**长边数据线（SDP）单口**的实测档。
当晚复核时是**双口同插**（长边数据 + 短边 PD），现查设备读数与三档表不同：

```
usb_type = Unknown [SDP] … C PD PD_DRP PD_PPS      ← PD 契约在
input_current_limit = 2000000  current_max = 2000000  voltage_now = 5681000   ← PD 5.68 V 顶档
bat.current_now = +80000 µA  bat.capacity = 98%                            ← 正在充
```

⇒ **判据**：读「充不充得进」前先看 `usb_type` 里有没有 `PD`。有 PD 时 ADSP 走 PD 契约（5 V 以上、2 A 顶档），
`charge-watch` 的 SDP 阶梯（100/500/900 mA）与 4.40 V sag guard **都不是决定项**；
拿三档表去套 PD 现场会误判成「门坏了」。`charge-watch` 日志佐证：`17:20:19 usb node appeared after 0 s`。
