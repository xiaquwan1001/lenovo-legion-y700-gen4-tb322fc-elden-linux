# 2026-10-23 · 上游回信（Konrad/Pengyu）+ stock Android 取证 + Q28 下一变量收口

- **日期**：2026-10-23
- **pi 会话 id**：见 `$PI_SESSION_ID`（本项目 `.pi/sessions/`）
- **主题**：① 按序执行：回 Konrad → 对齐 Pengyu → Q28 下一变量 ② 设备侧 stock Android 取证 ③ 事故与门禁（误发 adb / 背光 4%）
- **结论（一句话）**：两封信已发（含 1 封更正）；**stock Android 侧取证完成**（QBG 共享量一致、Android 栈无 `power_now`、user 版无法读下游 sysfs）；**Q28 下一变量已定量口径**并出了只读取证脚本 + 好启动基线；**3 轮冷起采样按用户决定暂缓**。
- **证据指针**：`reports/artifacts/reply-konrad-vendor-20261023.txt`、`…-addendum-…`、`reports/artifacts/reply-pengyu-dt-coord-20261023.txt`、`reports/q28-dpu-intf-next-20261023.md`、`reports/artifacts/q28-clkdiag-good-20261023.txt`、`PITFALLS #371`
- **★SSOT 待并入**：无（`DEVICE/README.md` §1.1、`TASKS/README.md` §5 Q28 行已就地更新）

---

## 1. 邮件（已发，各自 Message-ID）

| 对象 | 主题/线程 | 关键内容 |
|---|---|---|
| Konrad Dybcio（+linux-pm/sre/arm-msm/lkml） | `Re: [PATCH] qcom_battmgr: do not report power_now on SM8750` | 答「有没有联系厂商」= 没有；给出 stock Android 取证与主线的同口径对照；明确 user 版无 root/SELinux 拒绝 sysfs ⇒ 下游 `power_now` 读不到 |
| 同上（短更正） | 同线程 | 更正「没有任何厂商源码」→ 有 OEM GPL drop（display/touch/camera/wlan/audio），**但无 `drivers/power/supply`/QBG**，故该线程结论不变 |
| Pengyu Luo（+arm-msm） | `Re: [REPORT] SM8750 bonded dual-DSI + NT36536` | ① `sm8750-lenovo-elden.dts` 同名冲突：请求以他 v2 为基、我们发 delta（按子系统拆）② 问他有没有 TB322FC 下游源码 ③ 给他 23 发 POR A/B 与两条负结论 ④ 问他 "10-bit C-PHY clk source select" 具体寄存器 |

## 2. stock Android 取证（同一台、同一块电池）

a 槽往返（`fastboot --set-active=a` → boot Android → 读值 → 切回 b），全程只改活动槽元数据，`boot_b` 内容未动。

| 量 | stock Android（`ZUXOS_1.5.10.259_260611`, user/release-keys） | 主线 vk152（分钟后同机） |
|---|---|---|
| charge_counter | 6 439 000 µAh | 6 489 760 µAh |
| voltage | 4 309 mV | 4 285 000 µV |
| temperature | 32.3 °C | 32.1 °C |
| capacity | 94% | 94% |
| `power_now` | **Android 栈无此字段**（`dumpsys battery` 无、logcat 0 命中）；`/sys/class/power_supply` 被 SELinux 拒给 shell，且 user 版无 adb root | 我方 daily **不暴露该属性**（SM8750 desc 少最后一项） |

⇒ 共享 QBG 值一致（0.8% / 24 mV / 0.2 °C），差异只在 `POWER_NOW`；「下游是否也禁用」在 user 版上无解。

## 3. Q28：下一变量已定量口径（详见 `reports/q28-dpu-intf-next-20261023.md`）

- 新资产：**OEM 显示驱动源码** `stock-src/…-modules/qcom/opensource/display-drivers/`（`dsi_clk_manager.c`、`dsi_phy_hw_v5_0.c`、`sde/`）。
- 对照结论：`DSICLK_SEL` 一层我方已与 OEM 一致（OEM 整寄存器写 `CLK_CFG1=data<<2` ⇒ SEL/BITCLK 清 0；我方 sm8750-3nm 显式 `SEL(0)`）；
  **bonded peer 时钟挂 master PLL 是 OEM 的显式设计**（`dsi_clk_update_parent()`），我方好启动实测一致 ⇒ 排除「peer 时钟没起来」的默认假设。
- 已备：`scripts/q28-clkdiag.sh`（只读）+ 好启动基线 `reports/artifacts/q28-clkdiag-good-20261023.txt`；
  判据 = `pclk1/byte1` 的 parent+rate、`ctl N reset failure` 序号、DSI 错误计数、`dri/0/summary`。
- **3 轮冷起采样：用户决定暂缓**（收集器已停；无新样本）。

## 4. 事故与门禁

| 事项 | 事实 | 处置 |
|---|---|---|
| **误把命令发给另一台手机** | `slot-switch.sh` 用裸 `adb get-state` 判断「在不在 Android」；总线上唯一 adb 设备是 vivo ⇒ 对 vivo 发了 `adb reboot bootloader`（无任何写入） | 脚本改为**必须显式序列号**（fastboot 侧唯一且 product 匹配 `elden`；adb 永不猜；`adbx` 用 `9>&-` 关掉锁 fd）；`PITFALLS #371` |
| **设备锁被 adb fork-server 持有** | 该次 adb 客户端把 fd 9 继承给常驻 `adb fork-server` ⇒ 后续脚本 `flock` 卡 300 s | 同上；判据 `fuser <lockfile>` |
| **「设备没响应」= 背光 4%** | `aw99706-backlight` `brightness=160/4095`，DSI connected/enabled、0 错误、会话 active | 提到 2048 后恢复；本次冷起后又回到 511（自动亮度 `ambient-enabled=true`）⇒ 建议加亮度下限或关 ambient（未做） |
| **Linux→fastboot 未响应** | 两次 `slot-switch a --reboot` 的 `eldroid-bootctl reboot bootloader` 路径没把设备带进 fastboot（用户手动复位进 fastboot） | 未定因；下次改**先看 `psci: SYSTEM_RESET2 vendor reset_type=…` 是否打印**再判；暂记 |

## 5. 设备现状（安全态）

`boot_b = vk152` 运行中（`boot_id 1de638da…`），`qbootctl -m b` 已置 successful，`card0-DSI-1=connected/enabled`，
背光 511/4095（可见但偏暗），a 槽 = stock Android 保持可引导（`fastboot --set-active=a` 即可）。

## 6. 遗留

1. **3 轮冷起采样未做**（用户 2026-10-23 决定暂缓）；脚本与好启动基线已就绪，恢复时只需 `scripts/q28-coldboot-collect.sh <round>`。
2. 等 Taniya（v2 三问）、Konrad（是否要 root 级下游读数）、Pengyu（clk-src 具体位置 / 下游源码）。
3. 背光下限/自动亮度策略未处理。
4. `reports/host-stability-20261023.md`、`reports/dmesg.202610232032` 非本会话产物，未纳入提交。
