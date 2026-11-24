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

## §6 2026-11-24 上机前完整性复核（主机侧，零设备；只读）

设备窗口还没开，先把「这枚件到底是哪儿来的、能不能复现」钉死（11-19 磁盘清理后 `build/` 只剩部分树，
最怕的是「件在、配方没了」或者「DTB 与 DTS 已经不对应」）。全部命令可原样重放：

| # | 判据 | 命令 | 结果 |
|---|---|---|---|
| 1 | 归档自洽 | `cd out/g7-routeA-dtfix-20261123 && sha256sum -c SHA256SUMS` | 10/10 OK |
| 2 | **DTB 可复现** | `cpp -nostdinc -I build/g7a-tree/arch/arm64/boot/dts/qcom -I build/g7a-tree/include -undef -D__DTS__ -x assembler-with-cpp out/…/sm8750-lenovo-elden.dts -o /tmp/x.dts.pre && dtc -q -I dts -O dtb -o /tmp/x.dtb /tmp/x.dts.pre` | `/tmp/x.dtb` sha = **`dedc81bf…`**（与归档 DTB **逐字节相同**） |
| 3 | 归档 DTS == 树里 DTS | `sha256sum build/g7a-tree/.../sm8750-lenovo-elden.dts out/…/sm8750-lenovo-elden.dts` | 两处都是 `eeb78f0b…` |
| 4 | 镜像内载荷 == manifest | `python3 scripts/mkbootimg.py --unpack out/…/boot-elden-g7a2.img --unpack-dir /tmp/u` | dtb `dedc81bf…` / kernel(gz) `138dc1ad…` / ramdisk `3282ae6c…`，三者与 manifest 的 `dtb_sha256` / `kernel_sha256` / `ramdisk_sha256` **逐个相同** |
| 5 | 内核载荷解压后 == manifest | `gunzip -c /tmp/u/kernel \| sha256sum` | `a7a9068b…` = manifest `kernel_payload_sha256` |
| 6 | cmdline == manifest | `mkbootimg.py --unpack` 打印的 cmdline | 与 manifest `mkbootimg_args` 里的 `--cmdline` 逐字相同 |

结论：**这枚 `boot-elden-g7a2.img` 是可复现的**（DTS→DTB→镜像三级一致），上机只需 `fastboot boot`
（零写盘）；§3 的判据表不变。仍未做 = 真机上机（设备离线）。

## §7 flight-2 上机结果（2026-11-24，用户放行设备窗口；零写盘）

命令：`fastboot -s HA2EXB0E boot out/g7-routeA-dtfix-20261123/boot-elden-g7a2.img`（件 sha `79164085…` 与 §0 一致，
本轮再次 `sha256sum` 核对）。起机后采证，采完 `systemctl reboot` 回日常核（**已确认回到
`7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`、`/`=`sda17`**）。原始日志 = `artifacts/g7-flight2-20261124/`。

| 判据（§3） | 期望 | 实测（g7a2） | 日常核 vk189 对照 | 结论 |
|---|---|---|---|---|
| 0 起机 | `7.4.0-rc3-g7a-dwc3v11…` + `/`=`sda17` | ✅ `7.4.0-rc3-g7a-dwc3v11-20261121-dirty`、`/dev/sda17`、ssh 15 s 可达 | — | **通过** |
| 1 `Failed to create device link` | **= 0** | **7 条**（`qcom_pmic_glink` → `5-0042`/`5-0043`/`88e8000.phy`/`a600000.usb`，含两个 connector） | **8 条**（同类） | **未达成**（比基线少 1，但没清零；`Fixed dependency cycle(s)` 137 条属允许项） |
| 2 role switch | 两个 switch、`waiting_for_supplier` 全 0 | ✅ `a600000.usb-port0/port1-role-switch`，两者 `waiting_for_supplier=0` | 同样两个、同为 0 | **通过但不具区分力**（基线本来就 0） |
| 3 换口 → mux 切换 | mux state 翻转 | **未测**（要插拔线缆，需人工） | — | 待做 |
| 4 gadget | `/sys/class/udc` 有 `a600000.usb` | ✅ | 同 | **通过** |
| 5 Type-C 面 | `port0`/`port1` 在 | ✅ `port0`、`port0-partner`、`port1`（`data_role=host [device]`、`orientation` port0=reverse / port1=空） | 同三件 | 通过 |
| — mux 可观测性 | 能读 state | ✗ `/sys/class/mux/muxchip0` 只有 `device/of_node/power/...`，无 `mux_state`；`/sys/kernel/debug/mux/` 为空（debugfs 已挂） | — | 判据 3 的观测面本身要先补 |

### ★ 本轮发现（回归，优先级高于上面未达成项）

**内核 `WARNING` 计数：g7a2 = 42 条，vk189 基线 = 0 条**（基线的 1 条 "WARNING:" 是 initramfs 脚本打印的
`payload-modules-load failed/timed out`，不是内核 WARN）。42 条的构成（逐条归类，`grep "WARNING:" | sed | uniq -c`）：

| 条数 | 位置 | 触发面 |
|---|---|---|
| **34** | `drivers/gpu/drm/drm_vblank.c:1329` `drm_crtc_wait_one_vblank` | DPU/DSI vblank 等待超时（Q28 L2 家族；routeA 件显示栈本就没起来） |
| **8** | `drivers/clk/clk.c:1259`/`:1118` `clk_core_disable`/`clk_core_unprepare` | `dsi_phy_driver_probe` → `of_clk_add_hw_provider` → `clk_core_reparent_orphans_nolock` ⇒ **DSI PHY 注册自己的 clock provider 时重挂 orphan** 的上游已知形态 |
| （另 3 条非内核） | initramfs | `payload-modules-load` 1 + `binderfs unavailable` 2（Waydroid 相关，日常核同样有 1 条） |

首条 clk WARN 的完整栈（`artifacts/g7-flight2-20261124/g7a2-dmesg.txt`）：

```
WARNING: drivers/clk/clk.c:1259 at clk_core_disable+0x23c/0x250
Workqueue: events_unbound deferred_probe_work_func   （t=0.32 s，随后 clk_core_unprepare 同栈反复）
```

判读（2026-11-24 二次归因，从日志现查）：两类 WARN 是**同一个根的两种症状** —— 先看 dmesg 里的前置行：

```
[0.320314] DSI PLL(0) lock failed, status=0x00000000
[0.320327] dsi0_phy_pll_out_dsiclk already disabled
[0.320468]  dsi_phy_driver_probe+0x2f4/0x348
[0.320542]  mdss_probe+0x20c/0x3a0
[0.326036] DSI PLL(0) lock failed, status=0x00000000   （重复）
```

⇒ **DSI PLL 根本没锁上**（`status=0x0`）：
8 条 `clk_core_disable/unprepare` = PLL out clock 已 disabled/unprepared 时 `dsi_phy_driver_probe` 的收尾路径
再关一次（orphan 重挂只是它的栈形状）；34 条 `drm_crtc_wait_one_vblank` = DPU 在**没有可用 display pipe** 的
情况下等 vblank 超时。两者都是「本件显示面不带 bring-up」的必然结果，**不是 USB/mux 改动引入的回归**。
`mdss_probe` 那一栈还说明 mdss 侧 reset/时钟路径本身跑到了（与 M8 系列相关，可作旁证）。

⇒ 结论（本件不作上机候选继续）不变；「clk 引用错」的假设**撤回**。若要证死「PLL 锁不上是 routeA DTS 缺项」，
下一步应对比 routeA DTS 与 daily DTS 的 `dsi@ae94000`/`phy@ae95000` 子树（regulator、`vdda`-类 supply、
`assigned-clocks`），而不是先怀疑 clock consumer。

### ★ 2026-11-24 追加更正：判据 1 的期望值本身写错了

在同一天的日常核 vk189 上现查同一判据（`dmesg | grep "Failed to create device link"`）：

```
2× qcom_pmic_glink … with supplier a600000.usb
1× qcom_pmic_glink … with supplier 5-0042
1× qcom_pmic_glink … with supplier 5-0043
1× qcom_pmic_glink … with supplier 88e8000.phy
1× msm_dsi ae94000.dsi … with supplier ae96000.dsi
（合计 8 条，两个 boot 阶段各出现一次）
```

⇒ **这族 `Failed to create device link (0x180)` 在 downstream 日常核上本来就有**（含 `a600000.usb` 作 supplier
的那两条）。所以 §3 判据 1 写的「= 0」是**不可达的错期望**；正确判据应是**「不高于基线」**：

| 口径 | 基线 vk189 | 候选 g7a2 | 判定 |
|---|---|---|---|
| `Failed to create device link` 条数 | 8 | 7 | **无新增（少 1）** ⇒ 通过 |

### 结论与下一步（2026-11-24 更正后）

1. **flight-2 在 USB 判据上是通过的**：判据 0 / 1（按「不高于基线」口径）/ 2 / 4 / 5 全过；**只有判据 3（换口→mux 切换）未测**，
   因为观测面缺失（class 无 `mux_state`、debugfs 无输出）。
2. ~~本件不作为「可用上机候选」继续~~ ← 该结论作废。当前结论：**本件可作为 USB 面候选**，但要把显示侧 WARN 与判据 3 的观测面补齐。
2. **判据 3 的观测面已找到（2026-11-24 第二次上机验证，零写盘）** —— mux state 不进 sysfs/debugfs，
   但**选择线本身可读**：

   ```sh
   $ grep -E ' gpio29 ' /sys/kernel/debug/gpio
    gpio29  : out low  func0 2mA pull down       # = mux state 0（dwc3 侧 sysfs 只暴露 muxchip0，无 mux_state）
   ```

   即判据 3 的判法 = **插拔前/后各读一次该行**，`out low` ↔ `out high` 翻转即「换口 → mux 切换」成立；
   `typec` 侧的 `data_role` 两个 port 都显示 `host [device]`（无 partner 时的常态，不作出结论）。
   **注意**：别用 `echo … > /sys/class/typec/port0/data_role` 去模拟——角色一切换，`usb0` 上的 ssh 通道就断了，
   恢复要人工断电，不值当。

3. 主机侧下一步（不需要设备）：
   - 把 45 条 WARN 逐条归类（`grep -A2 "WARNING:"` 的调用栈前缀 → 哪个 driver 的 deferred probe），
     定位到具体 clock consumer，再在 routeA DTS/驱动侧修；
   - devlink 那 7 条要单列：它们与 flight-1 的 6 条同族（`qcom_pmic_glink` ↔ `fsa4480`/`dwc3`），
     §2 里「双向 endpoint 就能消掉」的判断**被本轮否证** —— 需要新的假设（例如 devlink 失败是
     supplier 尚未注册时的时序问题，而不是 DT 环）。
3. 判据 3（换口）要等 mux state 的观测面补上（class 无 `mux_state`，debugfs 也没输出）⇒ 先用
   `gpioget`/pinctrl 读 GPIO29 电平做代理判据。
