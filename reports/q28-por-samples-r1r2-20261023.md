# Q28 · vk152 真 POR 冷起样本 r1 / r2（2026-10-23 晚，收尾轮）

> 定位：`TASKS/README.md` §5 Q28 的「≥8 发真 POR 冷起」判据的**前 2 发**（用户在机旁断电，脚本自动取证）。
> **本会话只取这 2 发，剩余次数交用户完成。**
> 判据先定死（`reports/q28-dpu-intf-next-20261023.md` §2）：`DSI_PLL_lockfail` 预期 0、`failed to acquire mdss resets` 必须 0、
> 两路 `pclk/byte` parent+rate 与好基线一致。

---

## 0. 数字结论

| 发 | boot_id | uptime@取证 | VERDICT | `DSI_PLL_lockfail` | `device_link_fail` | `storm_sig` | mdss reset 失败 | card0-DSI-1 |
|---|---|---|---|---|---|---|---|---|
| **r1** | `0f0f772e` | 15.8 s | **GOOD** | **0** | 8 | **0** | **0** | connected / enabled / On |
| **r2** | `b6211ab4` | 17.9 s | **GOOD** | **0** | 8 | **0** | **0** | connected / enabled / On |

- 两发 `image_sha256` 相同（`1b4ec8f8…`），`reset_type=por`，`uname -r` 相同（`7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty #4`）。
- **两发的判据段逐字相同**（`diff` 空）：dmesg 签名 10 项全 0；`pclk0=pclk1=172972734 @ dsi0_phy_pll_out_dsiclk`、
  `byte0=byte1=108107958 @ dsi0_phy_pll_out_byteclk` ⇒ **bonded peer 时钟两路完全一致**（判据 1、2 通过）。
- 累计（vk151/vk152 线）：**3 发真 POR 全 GOOD**（含 2026-10-23 下午那次上机核验）⇒ 距 ≥8 发判据还差 **5 发**（交用户）。

---

## 1. 产物

| 类型 | 路径 |
|---|---|
| clkdiag 全量 | `reports/artifacts/q28-clkdiag-r1-0f0f772e.txt`、`reports/artifacts/q28-clkdiag-r2-b6211ab4.txt` |
| trial 记录 | `reports/trials/20261023T145818Z-q28por-r1.json`、`reports/trials/20261023T151810Z-q28por-r2.json` |
| 现场（dmesg/env/probe） | `reports/trials/20261023T145818Z-q28por-r1/`、`reports/trials/20261023T151810Z-q28por-r2/` |
| 取数脚本（新增） | `scripts/q28-por-rounds.sh`（连取 N 发真 POR，每发自动落 clkdiag + devprobe + trial json） |

---

## 2. 两发都 GOOD 意味着什么（克制读法）

- ✅ 支持「**vk152 在 POR 深度下是确定性 GOOD**」（2/2 且判据段逐字一致 ⇒ 不是运气）。
- ❌ **不能**推广成「Q28 已解」：样本只有 2 发，且此前的坏发（base 臂 5/9 STORM）都是在**没有 mdss reset 的镜像**上出现的；
  当前结论只到「带 M8 复位迁移 + 全软件修的 vk152，在真 POR 下连续 2 发无坏发」。
- ⚠️ 与 Q32 的关系：本次两发都是**同一种复位深度（真 POR）**，所以**回答不了暖/冷差异**。
  要让 Q32 有判别力必须**显式改变复位方式**（见 `reports/q32-warm-vs-cold-preresearch-20261023.md` §5 的三臂设计）。

---

## 3. 顺带核实的两项静态事实（Q32 用）

1. `dmesg | grep -ic 'simpledrm|simple-framebuffer'` = **0**；`/proc/device-tree/chosen/` 下**没有** `framebuffer` 节点
   ⇒ vk152（7.3 树）上 simpledrm **全程未参与**（`chosen/framebuffer` 被 DT 显式删掉了，理由见 DT 注释与 Q32 预研 §3）。
2. `dmesg | grep -ic 'psci: SYSTEM_RESET2'` = **0** ⇒ 这两发确实是**真 POR**（没有走 PSCI 复位路径）。
   ⇒ 这条打印可以直接当作「本次是不是真 POR」的判据，比看 uptime 更硬。

---

## 4. 剩余（交用户）

```bash
# 每次断电开机后跑一次（轮号往下排；boot_b 已是 vk152，不需要 fastboot）
scripts/q28-por-rounds.sh 1 2400 3     # r3
scripts/q28-por-rounds.sh 1 2400 4     # r4
# … 直到累计 ≥8 发
```

判据（每发都要满足）：`VERDICT=GOOD`、`DSI_PLL_lockfail=0`、`failed to acquire mdss resets=0`、两路 pclk/byte parent 相同。
任何一发出现 `STORM`/`NOCARD` ⇒ 立刻停、保留现场（`reports/trials/<ts>-q28por-rN/`），因为它同时是 Q32 的关键样本。
