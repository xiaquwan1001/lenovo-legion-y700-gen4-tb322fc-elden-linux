# WiFi「到可用约 2 分钟 / 周期性掉线」根因调查（2026-10-06，vk61 基线）

> 证据层 · 只增不改。结论口径见 `TASKS.md §5 Q26`、`PITFALLS` #117/#118；
> 上游对照见本文 §1，实验矩阵见 §3–§6，资产见 §8。
> 触发：`TASKS.md §5 Q26`（用户明确仍需排查）+ 换到 vk61 载具后复现。

---

## 0. 一句话结论

1. **掉线的直接推手 = 固件 `WMI_ROAM_REASON_BEACON_MISS`（reason 2）**，每 ~16.4–17.7 s 一次；
   它被 ath12k 的 **3 s `connection_loss_work`** 变成硬拆链（`wlan0: Connection to AP … lost`）。
2. **该 bmiss 是「真的」：主机在前 ~100 s 基本收不到 AP 的 beacon**（`beacon rx: 1`），
   之后自行恢复（`beacon rx` 涨到 ~6–7/s），**每次启动都在 ~129 s 附近稳定下来**。
   ⇒ 现象是「关联上但收不到（beacon/ACK）→ 报 bmiss → 拆链」的循环，**不是** DHCP、不是省电、不是双管理器。
3. **两版驱动候选补丁都没能解决**（§5/§6）：v1 判据太松（固件在关联瞬间会送 1 个 beacon）；
   v2 判据收紧后 `Connection to AP … lost` 归零，但 mac80211 的 AP-probe 超时接手，**用户可见掉线节奏不变**。
4. **换真 AP 立刻干净**：`ustcnet`（校园基础设施 AP）首 90 s **0 bmiss / 0 掉线**，`beacon rx` 9.3/s。
   ⇒ 触发条件在 **P40 Pro 手机热点这一侧**（或它与 WCN7850 的交互）。

---

## 1. 上游 / 社区：找到同症状报告（2026-08，ath12k 邮件列表）

- **[PATCH v2 3/3] wifi: ath12k: skip connection_loss_work for MLO beacon miss**
  （Jose Ignacio Tornos Martinez，2026-08-04，WCN7850 实测；2026-09-17 仍在 review）
  原文：*“the firmware does not reliably forward beacon frames to the host via WMI, making the
  cancellation path ineffective. The result is a **full VIF disconnect every ~16 seconds**”*。
  **与我们实测的 17.66 s 周期、`beacon rx: 1` 完全同构**；他们的修法 = 对 MLO **不挂** `connection_loss_work`，
  只靠 mac80211 的 AP probe（mt76/rtw89 本就没有这个备用拆链定时器）。
- 该系列另含「固件崩溃恢复」「恢复期禁扫描」两个补丁（同作者）；均针对 MLO。
- 本树里的相关代码正是上游 **2024-04 v3（WCN7850 beacon-miss 处理）** 引入的；
  「只能靠 beacon 取消」是该补丁的原始设计，其作者当时也注明 *“Firmware doesn't report beacon loss
  events repeatedly”* —— 我们这台固件的实际行为与该假设不符。
- 其他社区同类线索：wlanpi-kernel issue #65（WCN7850 强制重关联后扫描全空，**只能重启/PCIe reload 恢复**，
  本次**未命中**：扫描正常返回 40 BSS）；ratatoskr 2026-04（beacon-loss 状态粘住直到重启）；
  wlanpi issue #54（ath12k 不上报 signal avg，本机 `beacon signal avg` 正常更新，未命中）。

---

## 2. 载具与不变式

- 载具 = `out/boot-elden-vk61.img`（内核/DTB/固件 = 在机 boot_b 逐字节，仅换 `/init`）；
  候选 = 同载具 + 换内核（`RAMDISK_KIND=full`，ramdisk sha 恒为 `98ffc6221191f930…`）。
- **唯一变量**：内核（DTB sha `9d46693b…` 与 ramdisk sha 全程不变）。
- UTS 锁定 `-vk47clean-gbd114ca335e1`（与在机 `/lib/modules/7.2.0-debug-vk47clean-gbd114ca335e1` 一致）；
  运行期区分靠 `uname -v`（构建时间戳），因为 `uname -r` 各候选**完全相同**。

---

## 3. 实验一：换 AP（决定性，2026-10-06）

| AP | 频点/信号 | 90 s 内 bmiss | 90 s 内掉线 | `beacon rx` |
|---|---|---|---|---|
| **P40 Pro**（手机热点） | 5745 MHz / −32 dBm | 每 16.4–17.7 s | 每轮 1 次 | **≈1 / 次关联** |
| **ustcnet**（基础设施 AP） | 5805 MHz / −49 dBm | **0** | **0** | 167→866（**9.3/s** = 100 ms 周期） |

⇒ 触发因素是 AP 侧（或该 AP 与 WCN7850 的交互），不是「PEACH 固件一律不转发 beacon」。
（实测中曾切回 P40 Pro 后 NM 一度停在 `need authentication`(reason 8) 约 2 min，
`nmcli device disconnect/connect` 一次恢复；扫描仍正常 ⇒ 非 wlanpi#65 的 wedge。）

---

## 4. 实验二：单变量（P40 Pro，各 45 s 窗口）

| 阶段 | 条件 | 掉线次数 |
|---|---|---|
| A | power_save=on，无流量 | 2 |
| B | power_save=off，无流量 | 2 |
| C | power_save=off + 持续 ping | 3 |
| D | power_save=on + 持续 ping | 2 |

⇒ **省电模式无关**（与 2026-10-06 早先结论一致，本次为干净单变量）；
**持续流量也不能压制** ⇒ 不是 inactivity 触发。
（注：ping 本身 100% loss —— P40 热点不回应自身 ICMP，但 802.11 层 TX 持续。）

---

## 5. 实验三：驱动候选 v1（`out/boot-elden-wifi-bmiss-1.img`）—— 失败

- 内核 `a87287633`，`uname -v` = `#1 SMP PREEMPT Tue Oct  6 18:50:19 CST 2026`（已确认启动）。
- 改法：仅当「关联后见过 beacon」才挂 `connection_loss_work`（`beacon_seen` 布尔）。
- 结果：**掉线照旧** —— 28.5 assoc → 40.5 / 58.2 / 75.9 / 99.8 / 117.8 各掉一次（与前基线同节奏）。
- 原因：固件**在关联瞬间会转发 1 个 beacon**（= 实测的 `beacon rx: 1`），布尔判据当场被满足。

## 6. 实验四：驱动候选 v2（`out/boot-elden-wifi-bmiss-2.img`）—— 机制生效、用户可见无改善

- 内核 `5e173b60`，`uname -v` = `#2 SMP PREEMPT Tue Oct  6 19:18:07 CST 2026`。
- 改法：改为 **3 s 新鲜窗口**（`ATH12K_BEACON_FRESH_MSECS=3000` + `last_beacon_jiffies`，关联/去关联清零）。
- 结果（首 200 s）：
  - `Connection to AP … lost` = **0**（v1/基线是 5 次）⇒ **驱动侧强制拆链被切断**；
  - `deauthenticating` = 0；`failed to flush transmit queue` 仅 1 次（58.1 s）；
  - 但 **关联次数不变**：28.5 / 46.5 / 64.2 / 80.1 / 98.2 / 129.3（6 次）⇒
    **拆链改由 mac80211 的 AP-probe 超时完成**（该路径不发 deauth、不打印 `lost`，故计数上看不见）；
  - 稳定点仍在 **~129 s**；`beacon rx` 从 ~1 涨到 437/67 s（6.5/s）。
- ⇒ v2 对**本 AP** 用户可见收益 ≈ 0（链路照旧每 ~17 s 重建一次），但**无回归**，
  且证明了「ath12k 强制拆链」与「mac80211 probe 超时」是两条可独立关闭的路径。

---

## 7. 实验五：扫描不是充分原因 / 仍在持续扫描

- 首 ~4 min 扫描风暴：`scan event started` 17 次 / `completed` 17 / `abort` 1；
  每秒事件密度在 58–127 s 达 **10–27/s**（单次扫描约 6–15 s），`iw dev wlan0 scan` 取到 **EBUSY**；
  到 637 s 时扫描仍在继续（30 s 窗口内仍有大量事件，ring buffer 被冲掉而计数转负）。
- 但 **单变量反证**：在已稳定的链路上手动跑一次扫描（503→518 s，15 s 全程离频），
  之后 90 s 内 **无新关联、无 bmiss、无掉线**，`beacon rx` 从 2580 连续涨到 3085
  ⇒ **扫描本身不足以触发 bmiss/掉线**。
- 现状旁证：稳定期 `beacon rx` 仅 ~6.9/s（< 10/s）而**无** bmiss ⇒ 固件对「少量丢 beacon」是容忍的，
  早期黑屏期（`beacon rx≈1`）才会报 bmiss。

---

## 8. 独立 bug：boot 期回退仍起第二套管理器（设备仍是旧脚本）

- 本次三连启动（vk61 / v1 / v2）**每轮都在 ~115 s 复现**：NM 版 `net-up.sh` 等地址 80 s 超时
  → `exec net-up-manual.sh`（设备上的**旧版**）→ `pkill wpa_supplicant` 杀掉 NM 的实例
  → NM 0.75 s 内重新拉起 + 手动实例 + `udhcpc` ⇒ 一卡两 supplicant。
- 仓库侧已修（提交 `6719e90`，`scripts/net-up-manual.sh` 接管前先 `nmcli device disconnect` +
  `managed no`，命名 SSOT 对齐），**但尚未部署到设备 / 未重打 ramdisk**。

---

## 9. 资产

| 资产 | 内容 | 判定 |
|---|---|---|
| `out/boot-elden-wifi-bmiss-1.img` | vk47clean + `beacon_seen` 布尔判据 | ❌ 实测无效（判据太松） |
| `out/boot-elden-wifi-bmiss-2.img` | vk47clean + 3 s 新鲜窗口 | ⚠️ 机制生效、可见收益为 0；保留备查（无回归） |
| `patches/0012-ath12k-arm-connection-loss-timer-only-if-beacons-are-forwarded.patch` | 两版合并后的补丁（对 bd114ca33 的 diff） | 候选，**不宜按现状提交上游** |
| `~/wt-wifibmiss`（worktree @ bd114ca33 + `a87287633` + `5e173b60`） | 内核构建树（可复跑） | — |
| 提交 `6719e90` | `net-up-manual.sh` 安全接管 + 命名 SSOT 对齐 | ✅ 待部署 |

---

## 10. 未解问题（下一步）

1. **为什么前 ~100 s 收不到 beacon？**（客户端 RX/固件初始化 vs AP 侧行为）
   - 判别手段：换真 AP 已验证「另一个 AP 不吃这个亏」；下一步建议 **手机热点换 2.4 GHz** 或
     用第二台客户端同期对照同一 AP（AP 侧抓包/客户端列表）。
2. **谁在持续扫描？**（NM 激活/重连扫描 vs gnome-shell/Phosh 的 AP 列表刷新 vs wpa_supplicant 重连扫描）
   - 已知：`iw`/手动单次扫描不是充分原因；`wpa_supplicant.conf` 无 `bgscan`；NM 1.52.2 无 `bgscan` 属性。
   - 建议：给 profile 固定 `802-11-wireless.bssid`（跳过「扫描选 AP」）后复测首个 200 s 的
     `scan started` 计数与掉线次数（单变量）。
3. 是否值得保留「驱动不强制拆链」这条路？（v2 无可见收益）——若第 1 项定位到「客户端 RX 黑屏期」，
   则应优先解决 RX，而不是继续在 bmiss 语义上打补丁。
