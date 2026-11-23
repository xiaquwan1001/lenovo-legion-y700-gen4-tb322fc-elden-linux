# G7 路线 A · DTS devlink 环修复（g7a2 · rev2）—— 2026-11-23

> 纯主机侧产出：零设备动作（无 ssh/adb/fastboot/qdl）、项目仓零 `git commit`、零发信。
> 上机件 = `out/g7-routeA-dtfix-20261123/boot-elden-g7a2.img`（rev2，sha `79164085…`）。
> 上一版（one-way 变体，sha `1899f71d…`）**未过出口门，已废弃**，见 §2。

## §0 数字表

| 判据 | 值 | 出处 |
|---|---|---|
| dtbs_check 诊断总数（`CHECK_DTBS=y`，基线 before=36 条） | **32 条**（比 before **少 4**，新增 **0**） | `dtbscheck-after.log`（rev2 覆盖）vs `dtbscheck-before.log` |
| 其中 `Warning (graph_endpoint)` | **0** | `grep -c graph_endpoint dtbscheck-after.log` = 0 |
| 连接器子图「无环」判据（rev2 口径） | **ALL CHECKS PASS**（含上游基线对照） | `phandle-graph-check.txt`，`dtgraph-check.py` rc=0 |
| DTB `okay` 节点计数 | **34**（`dtc -I dtb -O dts` 后 `grep -c 'status = "okay"'`） | 反解 `/tmp` + `sm8750-lenovo-elden.dts.solved` |
| 镜像 sha256 | `791640856a9978e7a983dc726032f703574cfe6a772ec1129d6152c43271801d`（85 929 984 B） | `SHA256SUMS`（10 件全 OK） |
| DTB sha256 | `dedc81bfdd3830bb8496bf9acbc797098edc93db77d1c7a7d6631e52462c41c6` | 同上 |
| 板 DTS 源 sha256 | `eeb78f0be6a8cf0e24513123331f57e7309b995ad2bb9ef826869a614f245ca6` | 同上 |
| 内核（未重编） | `Image.gz` sha `138dc1adc9…`（payload `a7a9068b…`），UTS `7.4.0-rc3-g7a-dwc3v11-20261121-dirty` | `boot-elden-g7a2.manifest` |
| 上机验证 | **NOT_TESTED_ON_DEVICE**（零设备接触） | manifest `verification=` |

诊断明细（diff before→after，唯一变化）：删 4 条 `usb@a600000 ports:port@0 … required`（endpoint@0/@1 重构后 schema 不再报）；`usb-psy-name` 1 条 保留（before 也有一条同文）。**新增 = 0，删除 = 4。**

## §1 上一版为何失败（one-way 变体，sha `1899f71d…`）

上一版把 connector→mux/phy/dwc3 的 5 条 `remote-endpoint` 改成单向，理由是「双向 = fw_devlink 环」。实测否掉这个做法：

1. **dtc 的 `graph_endpoint` 规则就是「指向别人的 endpoint 必须被指回来」**。最小 DTS 实验验证：单向 → `Warning (graph_endpoint): graph connection to node '…' is not bidirectional`；双向 → 0 警告。没有第三种形状：dwc3 v11 的 role-switch 查找（`drivers/usb/roles/class.c`，v11 补丁 2）和 typec mux/switch 获取都**只走 OF graph**，不能改成普通 phandle。
2. 上游同款板全是双向：`sm8750-mtp.dts:226/234` ↔ `sm8750.dtsi:3217`（`usb_dwc3_hs` 空 endpoint）/`:3119`（`usb_dp_qmpphy_out`），`sm8650-hdk.dts:111/119/127` ↔ `:1605/1625/927`。对树内 `sm8750-mtp.dtb` 跑同一图检查脚本，同样报 connector↔dwc3/phy/mux 的 2-环，而它 `CHECK_DTBS=y` **全绿**。
3. 结论：上一版把门判据定得比上游更严（「子图无任何环」），连 dtbs_check 全绿的上游板 DTS 都过不了 ⇒ 两半门互斥，**不是 DTS 能修的，是判据错了**。主会话裁决：走上游形状（双向），脚本判据改为「上游等价」。

## §2 本次形状（rev2）与上游出处

5 对 **双向** `remote-endpoint`（file:line 均为本树 `build/g7a-tree`，v11 补丁后的 `sm8750-lenovo-elden.dts`）：

| 链路 | 板 DTS 侧 | 写域行号 | 上游同款出处 |
|---|---|---|---|
| connector@0 port@0 ↔ dwc3 HS endpoint@0 | `pmic_glink_hs_in` ↔ `usb_dwc3_hs`（`mux-state=<0>`，`usb-role-switch`） | :1333 ↔ :3011 | sm8750-mtp.dts:226 ↔ sm8750.dtsi:3217 |
| connector@1 port@0 ↔ dwc3 HS endpoint@1 | `pmic_glink_hs_c2_in` ↔ `usb_dwc3_hs2`（`mux-state=<1>`） | :1371 ↔ :3020 | （v11 binding：snps,dwc3-common.yaml endpoint@0/@1 + mux-state；无上游双连接器板，v11 补丁 1/3 定义） |
| connector@0 port@1 ↔ QMP SS PHY port@0 | `pmic_glink_ss_in` ↔ `usb_dp_qmpphy_out` | :1341 ↔ :3043 | sm8750-mtp.dts:234 ↔ sm8750.dtsi:3119；sm8650-hdk.dts:119↔1625 |
| connector@0 port@2 ↔ typec-mux@43 | `pmic_glink_sbu` ↔ `fsa4480_sbu_mux` | :1349 ↔ :2074 | sm8650-hdk.dts:127↔927（wcd_usbss 同形） |
| connector@1 port@1 ↔ typec-mux@42 | `pmic_glink_hs_sbu` ↔ `fsa4480_hs_sbu_mux` | :1379 ↔ :2058 | 同上（fsa4480 带 `mode-switch`/`orientation-switch`，connector 靠 graph endpoint 找 mux，:2049/:2065） |

mux 切换面不变：`&usb` `mux-controls = <&usb_hs_mux>`（:2979）+ 根节点 `gpio-mux`（GPIO29，2 states），dwc3 port@0 两个 endpoint 各带 `usb-role-switch` + `mux-state`（v11 补丁 1/3 的绑定与驱动语义）。

**为什么双向不再是上机失败原因**：flight-1 的 `Failed to create device link (0x180)` 来自 devlink 环被拒。上游对这些成对 graph 依赖的处理是 `__fwnode_link_cycle()` 打 `FWLINK_FLAG_CYCLE`（drivers/base/core.c:135 的 `Fixed dependency cycle(s)` 打印）→ `fw_devlink_get_flags()` 返回 `FW_DEVLINK_FLAGS_PERMISSIVE | DL_FLAG_CYCLE`（core.c:1781）→ `device_link_add()` 照常建链。dmesg 里会重新出现 `Fixed dependency cycle(s)`，**这不是失败信号**；失败信号只有 §3 的 ①。

## §3 第二次上机判据（主会话执行；本件零写盘）

```sh
timeout -k 5 120 fastboot boot out/g7-routeA-dtfix-20261123/boot-elden-g7a2.img
# 回退：fastboot reboot（零写盘，不动 boot_b）
```

| # | 判据 | 命令 | 通过值 |
|---|---|---|---|
| 0 | 起机 | `uname -r` | `7.4.0-rc3-g7a-dwc3v11-20261121-dirty`，`/` = `/dev/sda17` |
| 1 | **devlink 环修复（本件主判据）** | `dmesg \| grep -c 'Failed to create device link'` | **= 0**（flight-1 的 6 条 0x180 消失；`Fixed dependency cycle(s)` 允许存在，见 §2） |
| 2 | role switch 就绪 | `cat /sys/class/usb_role/*role-switch/waiting_for_supplier` | 全 0；`/sys/class/usb_role/` 仍为两个 switch |
| 3 | **换口 → mux 切换** | 两个口各插拔一次；`dmesg \| grep -iE 'fsa4480\|typec\|mux\|role'`；GPIO29 电平（`gpioget gpiochip0 29` 或 debugfs） | 换口时 mux state 翻转（0↔1），当前口的 role switch 收到 attach |
| 4 | gadget 存活 | `ls /sys/class/udc`；宿主 `lsusb` | `a600000.usb`；`1d6b:0104` |
| 5 | SBU/音频面（如有线耳机在手） | 插耳机 `dmesg \| grep -i fsa4480` | fsa4480 probe 成功、无 `Failed to create` |

采集后回退 `reboot`（回 vk192 日用态），按 `reports/g7-routeA-ondevice-20261121.md` §2 同样留 snapshot。

## §4 回退

- **主机件层面**：上一可用上机件 = `out/g7-routeA-20261121/boot-elden-g7a.img`（sha `d0c127ca…`），或直接回在机 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`（`fastboot reboot` 即可，本件零写盘）。
- **DTS 层面**：`out/g7-routeA-dtfix-20261123/dtfix.diff`（对 `board-dts-g7a.dts` 的 diff，48 行）；撤销 = `git -C build/g7a-tree checkout -- arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts` 后按 routeA-20261121 重建（或直接用其 DTB）。
- 树仍为 dirty worktree（9 modified + 1 untracked），未 commit；回退只需删/换这个 untracked 文件。

## §5 判据出处与两版对照

- 出口门脚本 `dtgraph-check.py`（rev2）四条断言：① 子图内 `remote-endpoint` 无单向（dtc graph_endpoint 规则）；② 子图非 graph 依赖无环；③ dwc3 endpoint@0/@1 + mux-state 0/1 + 每个 connector 指向自己的 dwc3 endpoint / SS PHY（仅 connector@0）/ 自己的 typec mux；④ **同一段代码在树内上游 `sm8750-mtp.dtb`、`sm8650-hdk.dtb` 上也全 PASS**（基线对照，防止判据比上游严）。文件头写明判据出处（dtc 规则 + `DL_FLAG_CYCLE` 放行 + 上游同款）。
- 两版 dtbs 日志：`dtbscheck-before.log`（routeA-20261121 基线，36 条）、`dtbscheck-after.log`（rev2，32 条，graph_endpoint=0）。one-way 变体的 32 条日志已被 rev2 覆盖（其 5 条 graph_endpoint 新增即失败原因，见 §1）。
- **单向变体被否的记录**：单向虽能让旧脚本（「子图无环」口径）绿，但违反 dtc graph 约定、上游不可接受（M 系列/§7 门），且 dtbs 新增 5 条诊断 ⇒ 否。双向变体 dtbs 32 < 基线 36、上游同形 ⇒ 采纳（主会话 2026-11-23 裁决）。
