# 本地清理与 Q24/Q28「干净解」可行性分析（2026-10-15）

> 动机：用户要求「清理和精简下游代码」——先确认 Q24/Q28 对应的**需求**，再判断能否用干净的新方式解决（不考虑上游汇报）。
> 口径：**状态/样本数 SSOT 仍是 `TASKS/README.md` §5/§7**；本文只做「需求 → 代码 → 干净解」的对应与成本核算。
> 证据层：`reports/p2b-retest-20261014.md`、`reports/m1-display-rootcause-analysis-20261014.md`、`reports/q28-dispcc-static-20261012.md`、`reports/q28-dsi-recover-20261012.md`、`reports/Q24-Q28-INDEX.md`。

## 0. 数字结论

| 项 | 数 |
|---|---|
| 下游 DSI 显示增量（M1 树 vs pristine `24a19b953e`） | 8 文件 **+976 / −100**（dsi_host.c +570、dsi_manager.c +249、phy/dsi_phy_7nm.c +109、dpu_encoder.c +72、dpu_encoder_phys_vid.c +44…） |
| 其中 **Q28 专有**（vendor 命令协议） | **≈500–550 行**（H23 单 hunk **+324**、H45 **+128**、其余 H01/H02/H12/H19/H20/H26/H34/H37–H42/H46 分散） |
| Q24 可归因的**内核代码** | **0 行**（H1/H2/D1/D2/use_rpm/critical_cbcrs 全部否证或撤回） |
| Q24 策略/脚本件 | cmdline 1（`elden_nocamera=1`）+ `initramfs/init` 1 处门控 + 常驻脚本 3（`cam-mode.sh`/`camera-modules-load.sh`/`keep-awake.sh`）+ **一次性调查脚本 35**（`q24-*` 18 + `q28*` 17） |
| 「上游 DSI 点不亮面板」否证的**时效** | ⚠️ **已过期**：P2b/P2c/P4a 三臂都在 **2026-10-13/14 上午**取得，而 M1 树的显示回归 **2026-10-14 12:40 才由 E1b 修复** ⇒ 那批结论被「M1 树本身点不亮」混淆 |

## 1. 需求确认（去掉技术名词）

### Q28 需求
**冷启动后内屏必须被正确初始化并进入桌面；失败时要能自恢复，不需要用户物理断电。**

- 需求 a：**面板 bring-up 成功**——判据是「面板有内容」（实测），不是 card0/connector/背光（`PITFALLS #251/#255`）。
- 需求 b：**失败可恢复**——现状是坏发即放弃 + 看门狗整机重启（~50% → ~75%）。

### Q24 需求
**相机栈可用（模块在位、能出帧）时，熄屏/DPMS off 不得导致整机复位；且不需要用户手动在「相机」与「熄屏」之间切换。**

## 2. 现状：需求 ↔ 下游代码映射

| 需求 | 当前实现 | 性质 |
|---|---|---|
| Q28-a | vendor bonded 命令协议（broadcast + master 触发 + 轮询，H01/H02/H12/H19/H20/H23/H26/H34/H37–H42/H45/H46） | **绕开**（未定根因的策略态） |
| Q28-a | vendor 硬件增量：C-PHY timing DT 数组、PHY PLL/vreg、`msm_dsi_host_enable` 时机（H39/H40） | **硬件事实**（保留候选） |
| Q28-a | E1b 1 行（`PLL_SYSTEM_MUXES`） | **真修复**（上游 revert 的缺口） |
| Q28-b | `q28-watchdog.sh`（坏发 → 整机重启） | **兜底**（运营） |
| Q24 | 无内核代码；`elden_nocamera=1` + `/init` 门控 + `cam-mode.sh`（互斥二选一） | **策略** |

## 3. Q28：三个干净解（按性价比）

### 方案 A ★ 删掉 vendor 命令协议，回到标准 bonded 流程
**假设**：面板不需要 vendor 的自定义 broadcast 协议；标准 `IS_SYNC_NEEDED()` 双写路径（**仍在树内**，`dsi_manager.c:msm_dsi_manager_cmd_xfer()` 的 `need_sync` 分支）就够。

- **为什么现在值得试**：唯一的反证（「上游 DSI host 点不亮面板」，P2b/P2c）**被 M1 显示回归污染**（见 §0 末行），且从未在 E1b 修复后复测。
- **做法**：单一变量——`dsi_mgr_uses_bonded_cmd()` 置 `false` + `msm_dsi_manager_cmd_xfer_trigger()` 还原上游（`need_sync` 双写、返回 `bool`），保留 H39/H40 使能时机与 PHY 硬件增量。
- **成本**：1 次构建 + N 次冷起（**N 次需要用户物理 POR**，`PITFALLS #166`）。
- **收益**：
  - 亮 ⇒ **删 ≈500 行**，且 Q28 的 vendor 签名（`command DMA timeout` / `bonded command DMA failed`）**从源头消失**（协议没有了，故障模式随之改变）。
  - 不亮 ⇒ 把「缺口」精确收缩到 H39/H40（使能时机）或 PHY，可只保留那几行。
- **判据**：`card0-DSI-1 connected` + `dsi_isr` 增长 + **用户目视面板有内容/可触摸**。

### 方案 B 把「回避」改成「可恢复」（A 失败时的兜底重设计）
- 已否证：DSI ctrl+PHY 复位**救不回**（vk116–vk122）⇒ 恢复必须发生在**更高层**。
- 干净形态：panel prepare 失败时返回可重试错误，由 DRM/用户态**重走一次 modeset**（而不是整机重启）。需先验证「重走 modeset」与冷启是否等价。
- 注意：现状 `dsi_mgr_*_pre_enable/enable/post_disable` 是「坏发即 `return`」（H37/H38/H41/H19）——**这正是把可恢复变成不可恢复的地方**，删它比加它更干净。

### 方案 C 找到真因（一行修）
- 上游 Pengyu 指路：**DPU 的 DSI clock source select（10-bit C-PHY plane）**（`reports/m1-display-rootcause-analysis-20261014.md` §2）。
- 若命中 ⇒ 一行修复，方案 A/B 都不需要。
- 现状：**未立项、未实验**。

### 建议顺序
**A（1 构建 + N 启，先做）→ C（静态+1 实验）→ B（仅在 A 显示「仍间歇坏发」时才需要）**。

## 4. Q24：干净解分析

**结论：没有可用的代码解；可做的只有「把互斥策略机制化 + 一次未试过的结构假设」。**

1. **策略机制化（低风险、纯清理）**：把 `elden_nocamera=1`（cmdline 配置态）+ `/init` 门控 + `cam-mode.sh` 三处，收敛成**一处按需加载**（相机打开时 modprobe，关闭时 unload）⇒ 恒不触发配对，熄屏恒安全。
   - 收益：删除 cmdline 开关与 `/init` 特判；`cam-mode.sh` 从「互斥提醒」变成真正的生命周期管理。
2. **未试过的结构假设（可能真解）**：Q24 的最小触发是 **`camcc-sm8750` + `cambistmclkcc-sm8750` 配对**（单挂任一存活）。
   - 两个驱动**都在树内**（`drivers/clk/qcom/camcc-sm8750.c`、`cambistmclkcc-sm8750.c`）。
   - 已否证的是「cambist 自己的 `power-domains` 变体」（H1/H2）。**没试过**的是：把 cambist 变成 **camcc GDSC 的 consumer**（`power-domains = <&camcc …>`）或 DT 子节点——即「cambist 的寄存器块在 camcc 电源岛里，必须由 camcc 的 GDSC 保活/排序」。
   - 若成立 ⇒ **1 处 DT 改动**即可让「相机在位 + 熄屏」安全。
3. **电气/时序根因**：需外部测量（仪器+人手），本地无法推进。

## 5. 清理与精简建议（不依赖上面的实验结论，可直接做）

| # | 动作 | 收益 |
|---|---|---|
| 1 | 归档一次性调查脚本：`scripts/q24-*`（18）+`scripts/q28*`（17）→ `archive/2026-10-15-retired-scripts/`；保留 `q28-watchdog.sh`、`q28-devprobe2.sh`、`cam-mode.sh`、`camera-modules-load.sh` | `scripts/` 去掉 33 个一次性件 |
| 2 | 统一 camera 加载路径（§4-1） | `initramfs/init` 少一处特判 + cmdline 少一个开关 |
| 3 | 若方案 A 通过：删 vendor bonded 协议（≈500 行） | 下游 DSI 增量从 +976 降到 ≈+450 |
| 4 | 把「坏发即 return」（H19/H37/H38/H41）列入**必删清单**（它把可恢复变成不可恢复） | 无论 A 成不成，删了都更干净 |

## 6. 待拍板

1. 是否执行 **方案 A**（1 构建 + N 次冷起；冷起需用户物理 POR 在场）？
2. 是否先做 **§5 的 1/2/4**（纯清理，零风险，不等实验）？
3. Q24 是否试 **§4-2 的 camcc GDSC consumer** 假设（1 处 DT + 1 次构建 + 冷起）？

## 7. 本次已落地的产物（2026-10-15）

| 项 | 状态 |
|---|---|
| **方案 A 镜像** | `out/boot-elden-armA-nobonded.img`，sha `5c25576f83f0…`，载荷 `1fe8d416a5…`，85 581 824 B；UTS `7.3.0-rc7-debug-ged6f232d10e3`（与 ramdisk 模块 vermagic 一致） |
| 源码臂 | `build/m1-upstream/clean-tree-73` 分支 **`m1-73/armA-upstreamcmd`** 提交 `95c899a885`（单文件 `drivers/gpu/drm/msm/dsi/dsi_manager.c`，3 处：`dsi_mgr_uses_bonded_cmd()`→`false`、`_xfer_trigger()`→上游实现、`_xfer()` 补 `id==DSI_0` 早退） |
| 打包配方 | 已实测**可复现到逐字节**：`tools/mkbootimg/mkbootimg.py --header_version 2 --os_version 15.0.0 --os_patch_level 2025-08 --base **0x10000000** --kernel_offset 0x8000 --ramdisk_offset 0x1000000 --second_offset 0xf00000 --tags_offset 0x100 --dtb_offset 0x1f00000 --pagesize 4096`（注意 `scripts/build-boot.sh` 里的 `--base 0x00000000` 与实际镜像不符）；ramdisk/DTB/cmdline 从 `out/boot-elden-m1-baseline-f3.img` 解出后原样复用 |
| 清理 | `scripts/` 移出 **32** 个一次性脚本 → `archive/2026-10-15-retired-scripts/`（保留 `q28-watchdog.sh`/`q28-devprobe.sh`/`q28-devprobe2.sh`）；`scripts/lib-boot-ready.sh` 引用已改指；`check-doctor.sh` **FAIL=0** |
| 机器账 | `versions/vk-ledger-known-issues.tsv` 登记 `armA-nobonded`（`uts_dup`）；`versions/vk-kernel-identity.tsv` 已重生成 |

### 尚未做

- **未上机**（`verification=NOT_TESTED_ON_DEVICE`）：需用户在场做真实 POR 冷起 ×N，判据 = 用户目视面板有内容/可触摸 + `dsi_isr` 增长 + **无** `command DMA timeout`/`bonded command DMA failed` 签名。
- §5 的 2/4（统一 camera 加载路径、删「坏发即 return」）未动。
- `m1-73/baseline` 与 `boot_b` **未受影响**（arm A 只在新分支上）。
