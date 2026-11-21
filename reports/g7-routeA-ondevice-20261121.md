# G7 上机实测 #1 —— 路线 A 件（`boot-elden-g7a.img`）· 2026-11-21 23:13–23:35 CST

> 件：`out/g7-routeA-20261121/boot-elden-g7a.img`，sha256 `d0c127ca96973a01fc0db62ddcd20921cc3b934aafaacfdb46b9ec504c083c78`（下发前 `odirect-sha.py` 复核一致）
> 方式：**零写盘** —— `fastboot boot`（10.1 s 完成），全程未 touch `boot_b`；回退 = `reboot`（已回 vk192 日用态）
> 现场：设备在 BL 就绪由用户确认（`fastboot devices` = **HA2EXB0E**）；用户在场。

## §0 结论（数字先行）

| 判据（报告 §3 的 8 条） | 结果 |
|---|---|
| 起机 | **PASS**：`fastboot boot` 12 s 内完成，**6 s 内 ssh 通**，`uname -r` = `7.4.0-rc3-g7a-dwc3v11-20261121-dirty` |
| 根 | **PASS**：`/` = `/dev/sda17`（LABEL=linux）；`/proc/device-tree/model` = `Lenovo Legion Y700 Gen4` |
| 1 两个 port 注册 | **PASS**：`/sys/class/usb_role/` = `a600000.usb-port0-role-switch`、`-port1-role-switch` |
| 1' mux 控制器 | **PASS**：dmesg `gpio-mux mux-controller: 2-way mux-controller registered`；`/sys/bus/platform/drivers/gpio-mux` 有绑定 |
| 7 gadget 存活 | **PASS**：`/sys/class/udc` = `a600000.usb`；`usb0 UP 192.168.7.1/24`；宿主 `lsusb` = `1d6b:0104 Multifunction Composite Gadget` |
| 2/4 role 可读 | **N/A（非缺陷）**：`role` 属性只在 `allow_userspace_control=1` 时可见；v11 的 port switch deliberately 不开放用户态控制 ⇒ 无 `role` 文件是设计行为，不是寄存器失败 |
| **3 换口（Type-C 消费者）** | **BLOCKED**：`qcom_pmic_glink: Failed to create device link (0x180) with supplier a600000.usb for /pmic-glink/connector@{0,1}`，供应商 `5-0042`/`5-0043`（typec-mux@42/43）与 `88e8000.phy` 同样失败 ⇒ **connector 与 dwc3 / mux 的 devlink 未建立**，两个 role switch 停在 `waiting_for_supplier` ⇒ 换口不会自动传播（未做物理换口，省得白折腾线缆） |
| 5 unbind 次序 / 6 debugfs 拒绝 | **未测**：consumer 链路未闭合，deb 前无意义；`/sys/kernel/debug` 下无 dwc3 目录（本 config 未开 dwc3 debugfs） |
| 8 DSI | **不达标（已知）**：`/sys/class/drm/` 只有 `version`，无 `card0`；dmesg 有 `dsi_phy_driver_probe` 触发的 `dsi0_phy_pll_out_dsiclk already disabled`（`clk.c:1259` WARNING）+ `aux_bridge … failed to acquire drm_bridge` ⇒ 7.4-rc3 上游显示栈缺 daily 的 B5 重构，**本件本就不判显示**（屏幕黑属预期） |

**一句话**：路线 A 件把「起不来」变成「起得来且 USB 端口层结构正确」，但 **Type-C 消费者链路（devlink）没闭合** ⇒ G7 的「换口→mux 切换」这条主判据还没被打到。

## §1 根因线索（可复现）

1. **DT 成环**（dmesg 原文）：
   ```
   /soc@0/geniqup@ac0000/i2c@a94000/typec-mux@43: Fixed dependency cycle(s) with /pmic-glink/connector@0
   /pmic-glink/connector@0: Fixed dependency cycle(s) with /soc@0/geniqup@ac0000/i2c@a94000/typec-mux@43
   /soc@0/geniqup@ac0000/i2c@a94000/typec-mux@42: Fixed dependency cycle(s) with /pmic-glink/connector@1
   ```
   ⇒ `connector@N` 与 `typec-mux@4N` 互为 supplier，fw_devlink 断链 ⇒ `Failed to create device link (0x180)`。
2. 报错同时点名 `a600000.usb`（dwc3）与 `88e8000.phy`（QMP PHY）⇒ 这两个也要从 connector 侧解依赖（典型修法：connector 不直接 `usb-role-switch` 指到 controller，而由 v11 的 port endpoint 承载；或 mux 节点去掉对 connector 的 phandle）。
3. 18 条 `WARNING`（`clk_core_disable` 撞 `already disabled`，`dsi0_phy_pll_out_dsiclk`/`byteclk`）—— 与 Q28 家族同源，属显示栈初始化次序问题，不是 USB 面。

## §2 证据文件

- 全量 dmesg：`out/g7-routeA-20261121/ondevice/dmesg-full.txt`（1390 行，`WARNING|cut here` 命中 18）
- 快照（uname/cmdline/findmnt/usb_role/udc/usb0/dmesg-usb）：`out/g7-routeA-20261121/ondevice/snapshot-1.txt`
- 回退后复核：`uname -r` = `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`、`/` = `/dev/sda17`、`qbootctl -n b` = marked successful、**零写盘**（只 `fastboot boot` + `reboot`）

## §3 下一步（主机侧，无需设备）

1. **修 DT devlink 环**：从 daily vk185 板 DTS 移植时，`typec-mux@42/43` 与 `pmic-glink/connector@0/1` 的相互引用要按 7.4-rc3 的 `usb-role-switch` + `port@N/endpoint` 形状重排（v11 的绑定允许 connector 走 endpoint 找 switch，不必直连 controller）。出口门 = dmesg 里 `Fixed dependency cycle(s)` 与 `Failed to create device link (0x180)` **双双归零**，且两个 port switch 的 `waiting_for_supplier` 消失。
2. 再出一发（仍可复用同一 config/树，只改 DTS ⇒ `dtbs` 秒级 + 重打包），第二次上机即可真正打「换口 → mux 切换」。
3. 显示面单独立项（B5 重构搬 7.4-rc3），不混进 USB 判据。
