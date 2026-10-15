# Q24 因果复核：rpmhpd sync_state 门控（2026-10-15）

> 动机：用户要求复核 Q24 成因，并判断「符合上游规范」能否给出新思路。
> 口径：状态/样本数 SSOT 仍是 `TASKS/README.md` §5 / §7；本文只做**因果链复核**与**新机制**。
> 证据：主机静态（`build/m1-upstream/clean-tree-73` = 7.3-rc7 + baseline）+ 设备只读取证（`root@192.168.7.1`，`7.3.0-rc7-debug-ged6f232d10e3`，日常 `boot_b`，`elden_nocamera=1`）。

---

## 0. 一句话

前 8–9 轮把 Q24 定性为「靶点已是电气/时序级，软件侧盲试到此为止」。本轮复核发现**一个此前从未被识别的上游机制**：**`rpmhpd` 电源域 provider 的 `sync_state` 门控**。
它把「**必须 camcc + cambist 配对才触发**」从统计事实升级为**投票簿记的一次性事件**，并给出**纯软件层**的定向判据——**不需要外部仪器**。

## 1. 新证据（本次设备只读，非致命）

```
[   18.228861] qcom-rpmhpd 16500000.rsc:power-controller: sync_state() pending due to ade0000.clock-controller   # camcc
[   18.229244] qcom-rpmhpd 16500000.rsc:power-controller: sync_state() pending due to 1760000.clock-controller  # cambistmclkcc
```

要点：**整机 RPMh 电源域 provider 的 `sync_state` 只被这两个 clock-controller 卡住**（`dmesg | grep "rpmhpd.*pending"` 全天候只有这 2 条）。同一次读取里 `gcc-sm8750`、`qnoc-*` 的 pending 清单也列出 `ade0000/1760000`，但那是 **clock/interconnect provider**，与本文机制不同层。

## 2. 机制（上游代码事实）

`drivers/pmdomain/qcom/rpmhpd.c`：

- `rpmhpd_aggregate_corner()`（:966）：
  ```
  if (pd->state_synced)       to_active_sleep(pd, corner, ...);              /* 真实票 */
  else if (pd->presync_floor) to_active_sleep(pd, max(corner, enable)...);  /* 夹到最低功能档 */
  else { /* Clamp to highest corner if sync_state hasn't happened */         /* ★ 夹到最高档 */
         this_active_corner = pd->level_count - 1; this_sleep_corner = ... - 1; }
  ```
- `rpmhpd_sync_state()`（:1201，provider 的 `.sync_state`，由 driver core 在**所有消费者设备都绑定后**调用）：把**每个** `pd->state_synced = true`，再按**真实票**重投（未使能 ⇒ 0）。
- `presync_floor = true` **只**在 `gfx` / `gmxc`（GPU 轨）上；`mx / mxc / mmcx` **没有** ⇒ 它们走「夹到最高档」分支。

**推论（可逐条对照 F8 记录）**：设 camcc / cambist 是该 provider 最后两个未绑定消费者时——

| 状态 | provider sync_state | 全轨实际票 | 观测 |
|---|---|---|---|
| camcc 与 cambist 都不装（`elden_nocamera=1`） | **永 pending** | 夹到 **MAX** | 系统「健康」 |
| 只装其一 | 仍 pending（另一个未绑定） | 夹到 **MAX** | 存活 ✅（= 历史「单挂任一存活」） |
| **两个都装** | **触发** | 按真实票重投 ⇒ **批量投 0** | `ebi/gfx/lcx/lmx/mss/nsp/nsp2/gmxc/mxc→0, mmcx→6, mx→5` ⇒ **= `PITFALLS #197`/F8 记录的原始现象** |

⇒ **`PITFALLS #212`「最小触发 = 配对」不是 camcc×cambist 的"电学配对"，而是"该 provider 的最后两个消费者"**；也解释了为什么「不装相机 → 熄屏安全」：clamp 从未被释放。

## 3. 对既有口径的修正（三处，均为"审计发现"）

### 3.1 「第二 CC probe 时 RPMh 批量投 0 = probe 常规行为」→ 不完整
`#197` 正确指出它**不是死因**，但把它归为「cambist 注册 genpd 子域的常规重报」。更准确：这是 **`rpmhpd_sync_state()` 一次性释放 clamp**，可用 `dmesg | grep "rpmhpd.*pending"` 前后对比**断言**，而不是靠 trace 猜。

### 3.2 RFC v3 §Q1「bare clock controller with no GDSC **and no consumer**」在 DT 层不成立
`sm8750-lenovo-elden.dts` 里两颗 sensor（`samsung,s5kjns` 后摄、`galaxycore,gc08a8` 前摄，均 `okay`）**同时**是：
- **cambist 的时钟消费者**：`clocks = <&cambistmclkcc CAM_BIST_MCLK_CC_MCLK{3,4}_CLK>` + `assigned-clock-rates = <19200000>`（驱动 probe 时 `clk_prepare_enable(sensor->xclk)` 并断言 19.2 MHz）；
- **camcc 的 GDSC 消费者**：`power-domains = <&camcc CAM_CC_TITAN_TOP_GDSC>`。

⇒ 正确表述应是「**无 power-domain(GDSC) provider、但有时钟 consumer**」。上游会据此质疑问题描述。这也是为什么 `camcc` 的 **clock provider** `sync_state()` 长期 pending（`due to ad27000.isp / ac7b000.cci / ac7c000.cci`）——与本文的 **rpmhpd** sync_state 是两套独立机制，别混。

### 3.3 「只能靠外部仪器」→ 至少还剩一个纯软件靶点
本轮给出的 N1/N2（§4）**不需要仪器**，只需一版**带 `/lib/modules` 的镜像**（现日常 `boot_b` 的 `/lib/modules/7.3.0-rc7-debug-ged6f232d10e3` 不存在 ⇒ 无法 `modprobe`，两 CC 亦在 `/etc/modprobe.d/zz-elden-nocamera.conf` 黑名单）。

## 4. 符合上游规范的新思路（按性价比）

| # | 实验/动作 | 变量 | 判据 | 成本 |
|---|---|---|---|---|
| **N1** | 配对加载前后取 `dmesg | grep "rpmhpd.*pending"` + `/sys/kernel/debug/pm_genpd/{mx,mxc,mmcx,…}/current_state` + RPMh trace；**不熄屏** | 无（观测） | 预测：第二个 CC 绑定瞬间 pending 清零、轨按真实票重投 | 0 构建；**不熄屏**（历史 S2 配对不熄屏 300 s 存活） |
| **N2** | 两 CC `power/control=on`（保持 runtime-resumed，保住其 `required-opps=low_svs` 票）后再**真熄屏** | 单变量 | 存活 ⇒ 证实「票被丢」；仍是死 ⇒ 坍缩不在 CC 自身域 | 0 构建；可回退（`echo auto`） |
| **N3** | 上游正解：让**需要该域 min corner 的块**有真实消费者投票；或把域建模为 active-only peer（`RPMHPD_MMCX_AO/MXC_AO`）；或取消 `use_rpm` | 需定"谁需要" | 上游可接受形态（非 DT hack），同时回答 RFC v3 §Q4 | 构建 + 上机 |
| **N4** | 删 cambist 空转的 `#power-domain-cells = <1>`（Kaanapali 同族节点没有；全树无 `<&cambistmclkcc N>`；desc 无 `gdscs`） | 零行为 | `dtbs_check` 绿；可并入任意上游补丁 | 0 |

**上游规范视角的一句话**：`state_synced` 是上游**刻意设计**的"所有消费者就位前全轨保底、就位后交给真实票"的机制。它被释放后系统崩，说明**某个仍需该域的块没有任何驱动为它投票** —— 按上游规范，缺的是**消费者/性能态建模**（`required-opps` / `dev_pm_genpd_set_performance_state` / `_AO` peer），而不是更多 DT 变体或 workaround。

## 5. 与既有结论的关系

**不推翻**：配对触发（#212）、致死 = SoC 级复位 + 28–42 s 自恢复（#209）、PMIC PON 无记录 + 无 WDT（#211）、NoC/BCM 否证（#210）、DT 形状非杠杆（H1 否证）、GPU runtime-PM 无关（#207）。
**改写**：触发的**机理**（sync_state 门控）；「cambist 无 consumer」的口径；「只能靠外部仪器」的收口判断。

## 6. 需拍板

1. 是否做 **N1**（需先刷一版带模块树的镜像）。
2. N1 成立后是否直接做 **N2**（含一次真熄屏；死亡按 #209 自动恢复，无需 POR）。
3. **N4** 是否立即并入待发补丁（零风险，纯上游 nit）。

## 7. 证据指针

- 设备只读：本文 §1 的 dmesg（`root@192.168.7.1`，2026-10-15；`dmesg | grep -E "rpmhpd.*pending"`）
- 上游代码：`drivers/pmdomain/qcom/rpmhpd.c`（:966 aggregate、:1201 sync_state、:123/:237 presync_floor）
- 消费者事实：`arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`（sensor 节点 :2280/:2318）、`drivers/media/i2c/{s5kjns,gc08a8}.c`
- 旧口径：`reports/q24-r9-20261012.md`（F8 矩阵）、`PITFALLS #197/#209/#210/#211/#212`
- 对照：`reports/upstream-q24-q28-standard-20261015.md` §3.5、`reports/local-cleanup-q24-q28-20261015.md` §4
