# G7 换口实测（rev2，RAM 启动，2026-11-23 21:10–21:14）

> 上机件：`out/g7-routeA-dtfix-20261123/boot-elden-g7a2.img`（sha `791640856a99…`），`fastboot boot` 零写盘。
> 内核：`7.4.0-rc3-g7a-dwc3v11-20261121-dirty`。取证日志在 `reports/artifacts/g7-flip-20261123/`。

## 0. 数字结论

| 判据 | 结果 |
|---|---|
| **换口后 USB 数据通路自动跟随** | ✅ **PASS** —— 线从 port0 移到 port1 后 **4 s 重连**，`UDC state=configured`、`current_speed=high-speed`、`port1-partner` 出现，uptime 连续（无重启） |
| 断连/重连的直接证据 | ✅ dwc3 `request ... was not queued to ep3in` 恰在 115.2 s（拔出）与 146.3 s（插入）各一条 |
| UCSI PPM | ✅ `PPM init succeeded after 2 attempts`（flight-2 是 `failed` ⇒ rev2 有真实改善） |
| gpio-mux | ✅ `gpio-mux mux-controller: 2-way mux-controller registered` |
| **role switch 消费者** | ❌ 两个 `usb-role-switch` 仍 `waiting_for_supplier`、`role` 为空；`Failed to create device link (0x180)` 7 次（connector↔fsa4480 ×2 / ↔phy / ↔usb ×2 + 重放） |
| `Fixed dependency cycle` | 137 条（含 regulators 组与 connector↔typec-mux@42/43）⇒ **rev2 的 DTS 环修复没有根除**（原有的 connector↔mux 环仍在） |

**⇒ 换口这条主判据达成（数据面），role-switch 面仍待修。**

## 1. 观测面（before → after）

| 项 | before（port0 在位） | after（换到 port1） |
|---|---|---|
| typec | `port0 data=[device] power=[sink] partner=0` · `port1 ... partner=0` | `port0 ... partner=0` · **`port1 ... partner=1`** |
| UDC | `a600000.usb configured` | `configured`（speed `high-speed`） |
| role switches | `port0-role-switch`/`port1-role-switch` 均 `role=[]`、`waiting_for_supplier=1` | **不变**（仍 waiting） |
| port1-partner | — | `supports_usb_power_delivery=no`（接的是普通 PC 口）、`usb_power_delivery_revision=0.0` |

## 2. 未解决（下一轮 DTS/驱动方向）

1. `0x180` devlink 失败 → 两个 role switch 停在 `waiting_for_supplier`：消费者（dwc3 drd / 上层 role）拿不到 supplier，**role 不会跟随口变化**；数据面因 dr_mode 走 peripheral 而未受影响。
2. `connector@0/1 ↔ typec-mux@42/43` 环仍在（rev2 只处理了 `connector ↔ usb` 与 `connector ↔ phy` 的方向，未去 `connector → mux → connector` 回路）。
3. vblank WARN 每秒刷屏（`drm_crtc_wait_one_vblank` / `drm_fb_helper_damage_work`，CPU#3/#5）—— Q28 同源族，显示可用但等 vblank 超时；RAM 件无 B5 修复。

## 3. 顺带发现

- 本件 DTB 里 `dtc -I fs` 统计 `status="okay"` 返回 0（fs 下解析差异，非判据失效；实际 display/UFS/usb 均正常）。
- 设备侧落盘监听写在 `/var/tmp/g7flip/`（disk，非 tmpfs）⇒ 掉线不丢证；下次同类换口/热插拔测试照此办。
- `pkill -f "dmesg -w"` 自匹配（本次实踩）⇒ 必须写字符组 `dmesg [-]w`（PITFALLS 已有条目）。
