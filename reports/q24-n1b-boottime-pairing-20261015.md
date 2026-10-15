# Q24 N1b：**绑定时机**是 `rpmhpd sync_state` 线的真变量（2026-10-15 晚，真 POR 实测）

> 动机：`reports/q24-n1-syncstate-falsified-20261015.md` 的 N1/N1c 把
> `rpmhpd sync_state` 线的核心预测在**运行期配对**下否证了；该报告 §3 留了唯一的开口 ——
> **N1b：开机态配对**（绑定时机变量未验）。本轮用一次**真 POR**（用户物理重启到 fastboot 后 `fastboot reboot`）完成。
> 设备：U2 `HA2EXB0E`，`boot_b` = `m1-baseline-f3`（`7.3.0-rc7-debug-ged6f232d10e3`）。
> 安全：`idle-delay` 已用 **`/etc/dconf/db/local.d/` 系统级默认值**钉为 0（跨会话、跨重启生效），
> 且 `dpms=On`；两 CC 在位期间**全程未熄屏**。

---

## 0. 一句话

**N1b 推翻 N1 的结论**：把两 CC 改成**开机态自动绑定**后，
**`rpmhpd` provider 在整个 boot 里连一条 `sync_state() pending` 都没打印**（`dmesg | grep rpmhpd` **全空**），
而同期**其它 13 条 provider 的 pending 消息照常打印**。
⇒ **`rpmhpd sync_state` 的释放取决于"绑定时机"**：开机态配对会在 provider 求值前完成 ⇒ 直接进入已同步态；
运行期 `modprobe` 配对则**不会**再触发它。**N1 的否证只对"运行期"成立，不是对整条线成立。**

---

## 1. 对照表（单变量 = **绑定时机**）

| | **N1（运行期 modprobe）** | **N1b（开机态自动绑定）** |
|---|---|---|
| 两 CC 是否 bound | ✅ 2/2（`/sys/bus/platform/drivers/…`） | ✅ 2/2 |
| **`dmesg \| grep -c "rpmhpd.*pending"`** | **2**（且是 `t=18.17 s` 开机旧消息，modprobe 在 `t≈6300 s`） | **0**（**整个 boot 一条都没有**） |
| `dmesg \| grep rpmhpd` 是否为空 | 否（2 条） | **✅ 空** |
| 同 boot 其它 provider pending 数 | —（未计） | **13**（gpucc / qnoc×5 / gcc×2 / gxclkctl / camcc×3 / …） |
| `mx` / `mxc` / `mmcx` | `on` / `off-0` / `on` | `on` / `off-0` / `on` |
| `camcc` `state_synced` | `1` | **`0`** |
| 设备存活 | ✅ | ✅（uptime 连续增长，无复位） |

**读法**：`camcc` 自己的 `state_synced` 在 N1b 里是 `0`（它仍在等 ISP/CCI 这两个消费者，
日志里有 `camcc-sm8750 ade0000.clock-controller: sync_state() pending due to ad27000.isp / ac7c000.cci / ac7b000.cci`），
**但这与 `rpmhpd` 的同步状态是两套独立机制**（`reports/q24-causal-audit-20261015.md` §3.2 已提醒过别混）。
本轮的关键量是 **`rpmhpd` 侧**：N1b 下它**根本没进入 pending**。

---

## 2. 机制解读（与上游代码事实一致）

`drivers/pmdomain/qcom/rpmhpd.c`：
- provider 的 `.sync_state = rpmhpd_sync_state()`（:1201）由 **driver core 在所有消费者都 bound 之后**调用；
- 在它被调用**之前**，`rpmhpd_aggregate_corner()`（:966）走
  「`state_synced==false` ⇒ **夹到最高档**」分支（`mx/mxc/mmcx` 无 `presync_floor`）。

⇒ **两种时机的差别**：
- **N1b（开机态）**：两 CC 在 provider 求值**之前**就 bound ⇒ provider 认为消费者齐了 ⇒
  **直接进 `state_synced=true`**，按真实票投票，**不打印 pending**。
- **N1（运行期）**：provider 早已（在缺这两个消费者的情况下）完成过一次 sync_state 求值；
  之后运行期再 bind 消费者**不会重新触发** provider 的 `sync_state` ⇒ 日志不新增、轨不变。

**这解释了 N1 为什么"什么都没发生"**：不是机制不存在，而是**该机制是一次性的、只在开机窗口生效**。

---

## 3. 对 Q24 的意义（谨慎表述，不越界）

### 3.1 成立的部分

- **`sync_state` 门控是真实的、且时机敏感** —— N1b 给出了正向证据（provider 进入已同步态）。
  这**恢复了** `reports/q24-causal-audit-20261015.md` 提出的机制的可信度，但**修正了它的触发条件**：
  该报告 §2 表格里「两个都装 ⇒ 触发 provider sync_state」这一行，
  只在**开机态**成立；**运行期装载不触发**。
- **`PITFALLS #212`「最小触发 = camcc × cambist 配对」现在有了机理解释**：
  配对的两个 CC 是该 provider 的**最后两个消费者**，它们是否在开机窗口内绑定，
  决定了 provider 是"夹到最高档"还是"按真实票投票"。
  这是把**统计事实**升级为**机制解释**的第一步。

### 3.2 **不能**推出的部分（重要限定）

1. 本轮**没有复现死亡** —— 全程未熄屏（这是 N1/N1b 的安全前提）。
   ⇒ **不知道**"开机态配对（= provider 已同步/按真实票投票）"与"运行期配对（= 夹到最高档）"
   **哪一个才是 Q24 的致死构型**。甚至可能都不是。
2. `mx/mxc/mmcx` 在 N1b 与 N1 下**读数相同**（`on`/`off-0`/`on`）⇒ **当前 genpd 状态无法区分两种时机**，
   所以不能靠 `pm_genpd` 增量判断死活（与 `PITFALLS #279/#280` 的"pm_genpd 零判别力"一致）。
3. 这**不改变**「根治未成」口径，也**不替代**外部电气测量。

### 3.3 ★ 由此浮出的**新可测假设**（下一步的候选）

既然两种时机的差别是「**provider 已同步（按真实票投票）** vs **夹到最高档**」，
而 Q24 的死亡发生在**熄屏**（= 相机块下游关断、票被释放）时刻，
则最具判别力的实验是：

> **N2'：在 N1b（开机态配对、provider 已同步、按真实票投票）构型下，做一次真实熄屏。**

- 若**存活** ⇒ 说明致死构型是「夹到最高档」那一侧（即**运行期配对**），
  与 `reports/q24-repro-20261011.md` 的观察（完整栈运行期加载 + 熄屏 = 硬复位）**方向一致**，
  且给了 `sync_state` 线一个**可指名的因果**。
- 若**仍死** ⇒ `sync_state` 线与 Q24 **无关**，该线正式关闭，回到"外部电气测量"路线。

**风险控制**：死亡按 `PITFALLS #209` 为 **SoC 级复位 + 28–42 s 自动恢复，不需要物理 POR**
⇒ 该实验**不需要用户在场**；但会重启一次系统。**必须先退掉开机态配对**以免反复触发。

---

## 4. 证据与会话

- 设备实读（本文 §1/§2）：`root@192.168.7.1`，2026-10-15 晚，真 POR 后 `t≈66–135 s`
  - `dmesg | grep -iE "rpmhpd"` = **空**
  - `dmesg | grep -c "sync_state() pending"` = **13**（全是其它 provider）
  - `lsmod | grep -cE "camcc_sm8750|cambistmclkcc_sm8750"` = **2**
  - `/sys/devices/platform/soc@0/ade0000.clock-controller/state_synced` = `0`
- 被修正的原文：`reports/q24-causal-audit-20261015.md` §2 / §4 N1
- 前序否证（运行期）：`reports/q24-n1-syncstate-falsified-20261015.md`
- 上游代码事实：`drivers/pmdomain/qcom/rpmhpd.c`（:966 aggregate、:1201 sync_state）
- 安全基础设施：`/etc/dconf/db/local.d/00-elden-noblank` + `/etc/dconf/profile/user`（跨重启钉 `idle=0`）
- 相关口径：`TASKS/README.md` §5 Q24、`PITFALLS #212`、`#286`
