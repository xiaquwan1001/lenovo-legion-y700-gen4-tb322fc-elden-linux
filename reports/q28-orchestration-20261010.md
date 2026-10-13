# Q28 编排轮 2026-10-10 — 整合报告与下一步方向
> ⚠ 已被取代：`reports/q28-DOSSIER.md` §g-1 + `PITFALLS #163`（本文 §0/§4 冷暖方向写反；vk84/取证数字以 DOSSIER C7–C9/C13/C16 为准） — 仅历史留痕，当前口径以领域层/ q28-DOSSIER 为准。

> 设备 U2(HA2EXB0E) 起始在 fastboot。编排：编译(Lane A) + 平板取证(Lane B) + 联网调查(Lane C) 并行；
> 优先级 = 调试开发便利 > 驱动检查/修 bug > 其他。结论先行，细节在后。

## 0. 一句话结论

- **Q28 有了明确根因候选**：上游 SM8750 DSI 6G v2.9 **byte-clock PLL re-lock** 竞态（本树停在未修态），现场数字与寄存器差分互相咬合。
- **口径更正（用户实机）**：Q28 **与时间无关、全天候发作**；真实变量是**冷/暖复位**（**冷起基本失败 ~60%、暖起基本成功**；PITFALLS #163）。本轮 A/B 全走**暖复位**且 8/8 好 = **测错了变量**（不是"下午不复现"，而是暖起本就不可复现）。
- **顺带挖出并修掉一个独立基础设施事故**：`make olddefconfig` 删 ARCH_QCOM → vk81/82/83 是**不带 QCOM 驱动的死内核**。

## 1. Lane C — 联网调查（命中，reports/q28-upstream-research-20261010.md）

上游 SM8750 DSI 6G v2.9 byte-clock PLL re-lock bug：
- Kavan Smith `6cd33b6f4155`（round 6G byte clk）破坏 Eliza/SM8750 → Kozlowski `bc484ede914d` revert。
- Dmitry Baryshkov `fix-eliza-dsi`(2026-09-03) 为正确版：把 round 移到 `dsi_link_clk_set_rate_6g()`（reparent 之后），且 **byte_intf 用取整后的 rate**，否则每次 transfer 都 retrigger PLL。
- **三者都不在本树**（`git cat-file -t` 逐一核 = NOT-IN-TREE）。
- 下游 vendor `trigger_command_dma()` 无等待，但靠 `DSI_CLK_CTRL=0x23F` + `DYNAMIC_FORCE_ON` + 更长初始化序列规避。上游从不读 `REG_DSI_CLK_STATUS`。

## 2. Lane B — 平板取证（好发现场，logs/q28-forensics-20261010-125030/，13 项）

设备 vk64 好发（`command DMA timeout`/`panel init failed` = 0，有桌面），只读取证：

- **计划步骤③「谁开 DYN pclk」已答**：clk_summary 里 DYN/pclk/byte 的消费者 = `ae94000.dsi` + `ae96000.dsi` **两个 DSI host 本身**（pixel/byte/iface/dsi_pll_pixel/dsi_pll_byte），**无第三方**。
- **好发 vs 坏发 clk_summary 完全一致**（dsi0vco 756.756 MHz、dsi_pll_byte 108.108 MHz、dsi_pll_pixel 378.378 MHz 都相同）→ 再次证明坏发**不是时钟树状态差异**，而是**同一份时钟状态下、首条命令 DMA 触发时 PLL 域仍在切换**（与寄存器差分只有 DYN_PCLK_ACTIVE/DYN_CMD_PCLK_ACTIVE 两位置位一致）。
- **取整缺口的直接数字**（坐实根因）：驱动**请求 byteclk 133.076 MHz**（timing 行 bitclk 1064606 kHz ÷ 8），**PLL 实际达成 108.108 MHz**，差 **24.97 MHz / 23.1%**。即 `clk_set_rate(dsi_pll_byte_clk, 未取整值)` 后 CCF 里 rate 永远对不上 → 研究说的"每次 transfer retrigger PLL"。
- `PLL(0) lock failed`(t≈0.88s)×8 = 开机 probe 期**既存噪声**，vk64/vk84/bad 三处都有，**非 Q28 判据**。

## 3. Lane A — 编译（被基础设施事故阻塞，父代接管）

worker 发现（父代已独立逐条核实）：
- `linux/.config` 与已知坏档 `.config.broken-20261008` **逐字节相同**（sha `ba0ab96e…`），`# CONFIG_ARCH_QCOM is not set`、`CONFIG_DRM_MSM` 整行不存在。
- 现存 System.map/Image.gz（10-10 11:53 = vk83 内核）里 `msm_dsi_host_bonded_cmd_trigger`/`gcc_sm8750`/`qcom_rpmh_probe` **全 0 符号** → **vk81/vk82/vk83 产物不带 QCOM 平台驱动，上机不可能点屏 = 死内核**（其短 manifest 无 config_sha256）。
- 成因 = `scripts/apply-kernel-fragment.sh:41 make olddefconfig` 删 ARCH_QCOM（与项目既有告诫一致，非超预期错误）。

父代处置：
- 恢复好档 `.config`（`patches/config-before-fragment-20261009-210432.bak`，sha a80cbabb，ARCH_QCOM=y+DRM_MSM=y），坏档另存 `.config.broken-20261010`。
- 用当前 HEAD(vk83, q24 线；dsi_host.c 与 vk79 Q28 诊断基线等价) 重编，UTS=`7.2.0-debug-vk84-g86193a58a095-dirty`，编后 System.map gcc_sm8750=11 符号 ✅。
- **基础设施修复（本轮沉淀）**：
  - `build-kernel.sh` 加**编后符号守卫**：System.map 缺 gcc_sm8750/msm_dsi_host_bonded_cmd_trigger/rpmh → exit 1（坏档编出来的死内核不再能悄悄产出）。
  - `apply-kernel-fragment.sh` olddefconfig 后**回钉** ARCH_QCOM/DRM_MSM/DRM_MSM_DSI/SMD_RPM/QCOM_RPMHPD，仍缺则回滚备份并 die。
  - failure 记忆已落。

产物（单变量 A/B 对，载荷 kernel+ramdisk+dtb **逐字节相同**，唯一差 = cmdline 22 字节文本 ` dsi_cmd_delay_us=1000`）：
- `out/boot-elden-vk84-q28delay-base.img`（sha 687ffdef…，delay=0，=现状）
- `out/boot-elden-vk84-q28delay-exp.img`（sha 3cabb06a…，cmdline `dsi_cmd_delay_us=1000`）
- 补丁 `patches/q28-cmd-dma-delay.patch`（50 行单文件：`early_param("dsi_cmd_delay_us")` + `msm_dsi_host_bonded_cmd_trigger()` 写 TRIG_DMA 前 usleep_range + pre/post CLK_STATUS dev_err；**默认 0 = 完全现状**）。

## 4. A/B 循环测试（父代直接跑，scripts/q28-ab-delay.sh）

`reboot2 bootloader`→`fastboot boot`(零写盘,RAM 不扣槽位)→SSH 取证→按 `command DMA timeout`/`panel init fail`/`dpms off` 判 GOOD/BAD。

| 组 | 结果 |
|---|---|
| BASE（delay=0） | **4 GOOD / 0 BAD / 0 ENV** |
| EXP（delay=1000us） | **4 GOOD / 0 BAD / 0 ENV** |

- smoke + 8 轮全 GOOD。**口径更正（用户实机，推翻初稿"时间相关"）**：Q28 与时间无关、全天候发作；真实变量 = **冷/暖复位**——**冷起基本失败（用户实机：有时能进桌）、暖起（reboot→fastboot boot）基本成功**；过去把暖起循环的连串 GOOD 当成"当前不发作/概率性好"是方法学错（暖起本就不触发）。
- ⇒ **本轮 A/B 测错了变量**：`reboot2 bootloader`→`fastboot boot` 全程**暖复位**，8/8 GOOD 只说明"暖复位+RAM 直启这条路径本发没撞上"，**不能**判 delay 有效/无效。后续 A/B 必须**固定复位类型或做冷/暖对照**（见 §5.1 修订）。
- 收尾：设备经 `reboot2 bootloader`→`fastboot reboot` 干净回 **boot_b=vk64 持久直启**（slot mark-successful，boot_b 分区从未被写）；串口 ttyACM0 后台抓取常驻。

## 5. 下一步方向（按优先级：调试便利 > 修 bug > 其他）

1. **【修 bug 收口】固定/对照复位类型跑判别性 A/B**（口径修订：变量是复位类型非时间）。
   - Q28 全天候发作，**坏发靠冷起触发**（用户物理断电/电源键，agent 不代做）；暖起（reboot2→fastboot boot）基本不复现。
   - 方案：**同镜像矩阵 = 暖启×冷启 × base/delay(/round)**。先坐实"持久 boot_b 连续暖启"能否复现坏发（本轮 RAM `fastboot boot` 暖启 8/8 好，这条路径可能本就规避——本身是要验证的观测）。
   - 判据：delay/round 组**暖启坏发率**显著低于 base ⇒ 确认"时钟域 settle 竞态"；无差 ⇒ 证伪。
2. **【真根治】Method B = 取整 byte-clock（移植 Dmitry 修复）**：在 `dsi_link_clk_set_rate_6g_v2_9()` 先 `clk_round_rate(dsi_pll_byte_clk, byte_clk_rate)`，把取整值回写 `byte_clk_rate` 并**派生 `byte_intf_clk_rate`**，使后续 `clk_set_rate` 在 CCF 里成 no-op、不再 retrigger PLL。
   - ⚠️ **正确性风险**：`esc_clk_rate`、`bitclk_rate(=byte*7/8)`、DSC pclk 多处派生自 `byte_clk_rate`，盲改会回归；本地上游 commit 读不到（lore 被反爬）。
   - 先做**最小安全版**：仅在 SM8750 分支取整 + 回写 byte_clk_rate/byte_intf_clk_rate，编 vk85，与 vk84 base/delay 一起进夜间 A/B 三臂对照。上游 patch 到手后据其校准。
3. **【基础设施/调试便利，已完成一半】**：符号守卫 + olddefconfig 回钉已落；待办：给 vk81/vk82/vk83 打 DEPRECATED 标记（`PITFALLS §15`），并把 `apply-kernel-fragment.sh` 的 olddefconfig 改成"带 ARCH_QCOM 保护"或彻底移除（构建路径本就不跑 olddefconfig）。
4. **【可选调试便利】Method A 变体**：把 delay 换成"触发前轮询 `REG_DSI_CLK_STATUS` 等 DYN 位清零"（研究方案 A），比固定 delay 更贴上游语义；同样进 A/B。
5. 顺带（不阻塞）：夜间同机可捎带 `#106` 卡死捕获（softlockup_panic+pstore-catch 已装弹，串口常驻）；C0 真 Android 对照取证仍待 U1 接入。

## 6. 边界与文件清单

- 取证边界：好发现场未复现坏发态（坏发 clk_summary 用历史 logs/q28-BAD-vk75dump-*/state.txt 对照）。
- 未做（避免盲改风险）：Method B 实际编辑/编译、vk81-83 DEPRECATED 落 PITFALLS（父代专属文件，待你点头或在整合进 TASKS 时一并落）。
- 新增/改动文件：`scripts/q28-ab-delay.sh`（新）、`scripts/build-kernel.sh`（+符号守卫）、`scripts/apply-kernel-fragment.sh`（+回钉/回滚）、`patches/q28-cmd-dma-delay.patch`（新）、`out/boot-elden-vk84-q28delay-{base,exp}.img`(+manifest)、`linux/.config` 恢复、`reports/q28-{upstream-research,delay-build,orchestration}-20261010.md`、`.pi/workflows/2026-10-10-q28-orchestrate.js`。
