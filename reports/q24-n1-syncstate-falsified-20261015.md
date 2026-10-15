# Q24 N1 实验：`rpmhpd sync_state` 线**预测被否证**（2026-10-15 晚，实测）

> 动机：`reports/q24-causal-audit-20261015.md` §4 提出 N1（零构建、不熄屏），
> 用「配对加载前后读 `rpmhpd pending` + `pm_genpd` 状态」来验证新机制。
> 该报告 §3.3 明确指出此实验此前**被「无模块树」阻塞**；本轮 P0 已补齐模块树
> （`reports/m1-73-modules-p0-20261015.md`）⇒ **阻塞已解，本轮完成 N1**。
> 设备：U2 `HA2EXB0E`，`boot_b` = `m1-baseline-f3`（`7.3.0-rc7-debug-ged6f232d10e3`），
> **本发为 Q28 坏发**（`panel-init-fail=12`，与本文无关）。
> 安全：全程**不熄屏**（`idle-delay=0` / `ac=batt=0` / `lock=false`，`cam-mode.sh blank disable` 已存档）。

---

## 0. 一句话

**N1 的预测（"第二个 CC 绑定瞬间 pending 清零、轨按真实票重投"）被实测否证**：
两 CC 配对加载完成后，**没有任何新的 `sync_state` 消息、`mx/mxc/mmcx` 一个都没变**，
且 `camcc` 的 `state_synced` 读出是 **1**。⇒
`rpmhpd sync_state` 门控**不是**「配对加载」这个动作所释放的；
把「必须配对」升级为「投票簿记一次性事件」的**机制解释不成立**（至少不是这条路径）。

---

## 1. 实测数据（单变量 = 加载了哪些 CC）

| 阶段 | 已加载 CC | `dmesg | grep -c "rpmhpd.*pending"` | 新 sync_state 消息 | `mx` | `mxc` | `mmcx` | 存活 |
|---|---|---|---|---|---|---|---|---|
| **基线**（`elden_nocamera=1` + 黑名单，两 CC 均未加载） | 0 | **2** | — | `on` | `off-0` | `on` | ✅ |
| **只装 camcc**（`modprobe camcc-sm8750`） | 1 | **2** | **无新增** | `on` | `off-0` | `on` | ✅ |
| **配对完成**（再 `modprobe cambistmclkcc-sm8750`） | 2 | **2** | **无新增** | `on` | `off-0` | `on` | ✅（uptime 连续） |

补充实读：

```
$ dmesg | grep "rpmhpd.*pending"
[   18.173444] qcom-rpmhpd 16500000.rsc:power-controller: sync_state() pending due to ade0000.clock-controller
[   18.173546] qcom-rpmhpd 16500000.rsc:power-controller: sync_state() pending due to 1760000.clock-controller
```
⇒ 仅有的两条都带 **`t=18.17 s`（开机时刻）** 时间戳，**我们 modprobe 发生在 `t≈6300 s`**，
两条消息**没有任何新增**（不是"清零"、也不是"重投"）。

```
$ cat /sys/devices/platform/soc@0/ade0000.clock-controller/state_synced
1                                    ← camcc 的设备级 sync_state 已完成
$ ls -d /sys/bus/platform/drivers/*/ade0000.clock-controller      → camcc-sm8750/…
$ ls -d /sys/bus/platform/drivers/*/1760000.clock-controller      → cambistmclkcc-sm8750/…
```
⇒ 两 CC **确实都已 bound**（不是 probe 失败）；`1760000` 侧无 `state_synced` 属性可读。

---

## 2. 否证了什么 / 保留了什么

### 2.1 被否证（报告 §2/§4-N1 的预测）

| 预测（`q24-causal-audit-20261015.md`） | 实测 | 判定 |
|---|---|---|
| 「两个都装 ⇒ **触发** provider sync_state」 | 配对完成后无任何新消息 | ❌ **否证** |
| 「按真实票重投 ⇒ **批量投 0**」（`ebi/gfx/lcx/lmx/mss/nsp/nsp2/gmxc/mxc→0`） | `mx=on`/`mmcx=on` **原样**，其余轨也全部 `off-0` 无变化 | ❌ **否证** |
| 「第二个 CC 绑定瞬间 **pending 清零**」 | 计数仍 2（且那 2 条是老的开机消息） | ❌ **否证** |

### 2.2 仍然成立 / 未被本文触及

- **不触及**：配对触发（`PITFALLS #212`）、致死 = SoC 级复位 + 28–42 s 自恢复（`#209`）、
  PMIC PON 无记录 + 无 WDT（`#211`）、NoC/BCM 否证（`#210`）、DT 形状非杠杆（H1 否证，`#207` 一带）。
- **保留**：`sync_state` 作为**上游机制**本身是真实存在的（`rpmhpd.c:966/:1201` 代码事实不变）；
  本文只否证「**配对 modprobe 这个动作会释放它**」这一条**因果链**。
- **重要限定（不得过度解读）**：
  1. 本轮是 **Q28 坏发台架**，且**从未熄屏** ⇒ 本实验**只测「配对加载是否改变 RPMh 状态」**，
     **不测**「配对 + 熄屏是否会死」。后者是既有 `#212` 的结论，本文既不确认也不否认。
  2. 本次两 CC 是**运行期 modprobe**进来的；而历史配对触发场景多为**开机时自动加载**。
     「运行期 bind 与开机 bind 对 RPMh 投票的行为是否等价」**未验证** ⇒
     若要彻底关闭这条线，需要的是一次**开机态配对（去掉黑名单）**的对照（见 §3）。
  3. `pending` 消息是 **dmesg 字符串**，不是状态寄存器；"消息没新增"能证明**没打印**，
     但**不能单独证明** provider 的 `state_synced` 内部状态。`camcc` 侧 `state_synced=1` 是直接证据，
     `1760000`（cambist）侧**无该属性可读** ⇒ 该侧只能用间接推断，属**证据强度不对称**。

---

## 3. 下一步（把这条线要么关闭、要么救活）

| # | 动作 | 变量 | 判据 | 成本 |
|---|---|---|---|---|
| **N1b** | **开机态配对对照**：临时去掉 `zz-elden-nocamera.conf` 里两 CC 的黑名单 + 用 `CAM_FORCE=1`（或临时 cmdline 去 `elden_nocamera=1`），让两 CC 在**开机时**自动绑定，读同一组量 | 单变量 = 绑定时机（运行期 vs 开机） | 若**开机态**出现 pending 清零/轨重投 ⇒ 「时机」是杠杆，线**救活**；若同样无变化 ⇒ `rpmhpd sync_state` 线与 Q24 **无关**，**正式关闭该线** | 0 构建，1 次重启（**需注意**：开机态配对 = 相机栈常驻 ⇒ 若随后熄屏会触发 Q24；须全程禁熄屏） |
| **N1c** | 用 `/sys/kernel/debug/tracing` 抓 `rpmhpd_aggregate_corner()` 的实际入参（谁在投票、投了什么） | 观测 | 直接看投票，不再靠"消息有无"推断 | 0 构建 |
| **N2** | 两 CC `power/control=on` + 真熄屏（报告 §4 原案） | 单变量 | 存活 ⇒ 「票被丢」成立 | 0 构建；**含一次真熄屏**（死亡按 `#209` 自恢复，无需 POR） |

**编排者判断（供裁决）**：N1 已经**削弱**了 `sync_state` 这条线的价值——它的核心预测在**最容易成立的方向**上
（运行期配对）就没兑现。**建议优先做 N1b**（一次重启、单变量、可决定性关闭或救活），
而不是直接投入 N2（N2 建立在同一条未证实的机制之上，若 N1b 否证则 N2 无意义）。

---

## 4. ★★ N1c（RPMh trace 直读）：追加一条**比 N1 更强的否证**——且重新解释了「死前末票」

N1c 用 `rpmh_send_msg` tracepoint **直接看投票**（不再靠"消息有无"推断）。
tracepoint 确实存在（`/sys/kernel/debug/tracing/events/rpmh/{rpmh_send_msg,rpmh_tx_done}`）。

### 4.1 配对**加载**期间的投票（`t≈6493 s`，全程未熄屏、设备存活）

```
 modprobe-22711  6493.516710  rpmh_send_msg: apps_rsc: msgid: 0x10108 addr: 0x300a0 data: 0x2
 kworker/u34:3-… 6493.574743  rpmh_send_msg: apps_rsc: msgid: 0x10008 addr: 0x300a0 data: 0x0
```
**整段只有 2 条**，且**只碰 `0x300a0` 一条轨**。

### 4.2 配对**卸载**期间的投票（`t≈6517 s`，设备存活）

**54 条**，模式为 `0x300a0 data:0x2` ↔ `0x300a0 data:0x0` **反复振荡**，
**没有任何其它轨（`cx`/`mx`/`mmcx`/`MC0`/`SH*`）参与**。

### 4.3 ★ 地址解码：`0x300a0` = **`mxc.lvl`**

按 `reports/q24-r9-20261012.md` §2 的 cmd-db 实读映射：
`0x30000`=cx.lvl、`0x30010`=mx.lvl、`0x30080`=mmcx.lvl、**`0x300a0`=mxc.lvl**。

而 `reports/q24-repro-20261011.md` §2 把 **`mxc.lvl → 0x0`** 记为
**「死前最后一笔 RPMh 电源票」**（该报告 §0/§2 明确写作死因线索）。

### 4.4 ⇒ **「死前末票 = `mxc.lvl → 0`」不是死亡标志**

本轮在**完全健康的设备**上、**不熄屏**、仅在 `modprobe -r` 两 CC 的过程中，
就观察到 `mxc.lvl` 在 `0x2 ↔ 0x0` 间**振荡 54 次**，设备全程存活（uptime 连续、无复位）。

**推论（两条，均可证伪）**：
1. `mxc.lvl → 0` 是**相机 GDSC 轨的常规 runtime-PM 关轨行为**，不是死亡签名。
   ⇒ `q24-repro-20261011.md` 把"死前最后看到的投票"当成"致死原因"，属
   **post hoc ergo propter hoc**（事后归因）——它更可能是**伴随现象**，
   与 `q24-r9-20261012.md` §2 已给出的「死亡窗口与存活窗口**同址同型**」结论**一致**
   （该报告已把投票降级为伴随现象，本轮**独立复现并加强**了它）。
2. 它**顺带解释了** `PITFALLS #210`（NoC/BCM 靶否证）为什么成立：
   投票流本来就不区分死活。

**限定（不得过度解读）**：本轮**没有**复现死亡（全程未熄屏、也未配对+熄屏），
所以本文**不是**"Q24 已解"，而是**削掉了一条被当作死因线索的现象**。
真死因仍未被指名；`#209`（SoC 级复位 + 28–42 s 自恢复）、`#212`（配对触发）**不受影响**。

---

## 5. 证据与会话

- 设备只读/加载实读：本文 §1（`root@192.168.7.1`，2026-10-15 晚；`dmesg | grep rpmhpd`、`/sys/kernel/debug/pm_genpd/*/current_state`、`state_synced`）
- 被否证的原文：`reports/q24-causal-audit-20261015.md` §2 / §4 N1
- 解锁前置：`reports/m1-73-modules-p0-20261015.md`（模块树 P0）
- 安全工具：`scripts/cam-mode.sh`（本轮同时修了其 `off` 的反向激活缺陷，`PITFALLS #285`）
- 相关口径：`TASKS/README.md` §5 Q24、`PITFALLS #197–#212`、`#282–#285`
