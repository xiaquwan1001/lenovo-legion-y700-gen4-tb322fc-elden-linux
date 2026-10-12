# Q28「构建身份治法」真机复测（2026-10-12 晚）：3 位身份是**偏置**，不是**解**

> 触发：按 `PITFALLS #195` 治法重建的日常候选 `vk113-dailyid`（3 位构建身份 `#121`），在**真实 POR 冷起**上第一次上机复测。
> 本文件是**否证记录**；结论已同步 `PITFALLS #217`、`TASKS.md §5 Q28`、`INDEX.md §3`、`DEVICE.md §1.1`、`reports/q28-vk113-20261012.md`。
> 判据：`scripts/q28-cold-run.sh`（`fastboot boot` 冷路径 + `q28-devprobe2.sh` 三态 + 65 s 存活门 + `trial.sh record`）。

---

## 0. 一页结论（数字先行）

| # | 事实 | 数字 |
|---|---|---|
| 1 | **3 位身份臂出现坏发** | `vk113-dailyid`（`#121`）4 发中 **1 次 L1FAIL**（另 1 GOOD） |
| 2 | **`#60` 臂同会话也坏** | `vk94`（现役日常，`#60`）1 发 **L1FAIL** |
| 3 | **昨日 GOOD 臂今日仍 GOOD** | `vk104-base-pin`（3 位，10-11 晚 GOOD 2/2）1 发 **GOOD** |
| 4 | **坏发签名与历史 STORM 逐字一致** | `command DMA timeout: status=0x2200200` → `bonded command DMA failed: master=-110 peer=-110` → `sending dcs data ff 20 failed: -110` → `Failed to initialize panel: -5`（t≈9.0 s，`l1=7 l2=26`，`session=0`，`card0=1`） |
| 5 | **累计（含 10-11/10-12 审计样本）** | `#60` 臂 **5 坏 / 7**；3 位臂 **1 坏 / 23**；Fisher 单侧 **p≈8.3e-4** |
| 6 | **3 位臂残余坏发率** | 点估 **4.3%**，精确 95% 上界 **21.9%** ⇒ **不能视为 0** |
| 7 | **对收尾的影响** | `vk113-dailyid` **不刷 boot_b**；**Q28 仍未收尾**；「3 位重编 = 治好」的口径作废 |

**一句话**：构建身份与坏发率**强相关**（`#60` 明显更差），但**不是充分条件**——3 位身份下仍有可观残余坏发率，Q28（冷起首条 DCS 命令 DMA 竞态）本身没有修掉。

---

## 1. 逐样本证据（2026-10-12 16:30–16:45，全部真实 POR → fastboot）

| 序 | 镜像 | 内核身份 | 结果 | `l1/l2` | session | 记录 |
|---|---|---|---|---|---|---|
| 1 | `vk113-dailyid` | 3 位 `#121` | **GOOD**（+65 s 存活） | 0 / 0 | 1 | `reports/trials/20261012T083222Z-vk113-cold1.json` |
| 2 | `vk113-dailyid` | 3 位 `#121` | **L1FAIL** | 7 / 28 | 0 | `…T083731Z-vk113-cold2.json` |
| 3 | `vk94`（现役日常） | 2 位 `#60` | **L1FAIL** | 7 / 26 | 0 | `…T084144Z-vk94-ctl1.json` |
| 4 | `vk104-base-pin` | 3 位（`#111`–`#120` 族） | **GOOD**（+65 s 存活） | 0 / 0 | 1 | `…T084545Z-vk104-ctl2.json` |

原始日志（每个样本一份 `probe.txt`/`dmesg.txt`/`env.txt`/`survive.txt`）：`logs/q28-cold-20261012-163043-vk113-cold1/`、`…-163540-vk113-cold2/`、`…-163951-vk94-ctl1/`、`…-164405-vk104-ctl2/`。

坏发设备侧时间线（vk113-cold2 与 vk94-ctl1 同构）：

```
[  9.032148] msm_dsi ae94000.dsi: command DMA timeout: status=0x2200200
[  9.037910] msm_dsi ae96000.dsi: peer command DMA timeout: status=0x2200200
[  9.037912] msm_dsi ae94000.dsi: bonded command DMA failed: master=-110 peer=-110
[  9.037914] panel-novatek-nt36536 ae94000.dsi.0: sending dcs data ff 20 failed: -110
[  9.096078] panel-novatek-nt36536 ae94000.dsi.0: Failed to initialize panel: -5
[  9.102187] [dpu error]enc35 intf1 ctl 1 reset failure: -22
[ 10.176852] msm_dpu ae01000.display-controller: vblank wait timed out on crtc 0
```

GOOD 样本在同一步做的是 `panel prepared: scheduling firmware upload`（vk104-ctl2: `[11.17] novatek-nvt36xxx-spi spi0.0: panel prepared …`）⇒ 好坏差别**只在首条 DCS 是否超时**，与 `#164/#165` 定案的 L1 一致。

---

## 2. 统计口径与不确定性

| 数据集 | `#60`（2 位） | 3 位 | Fisher 单侧 p |
|---|---|---|---|
| 10-11/10-12 审计（`q28-storm-bias-audit`） | 4 坏 / 6 | 0 坏 / 20 | 0.0010 |
| **并入本晚 4 发** | **5 坏 / 7** | **1 坏 / 23** | **0.00083** |
| 仅本晚会话 | 1 坏 / 1 | 1 坏 / 3 | 0.50 |

解读（不夸大）：

1. **身份效应在合并样本里依然显著**（p≈8e-4），方向与 `#195` 一致 ⇒ 「3 位身份降险」这条**保留**（日常镜像仍应使用 3 位身份）。
2. 但 **3 位臂残余坏发率不能当 0**：1/23 的精确 95% 上界 ≈ **21.9%**（点估 4.3%）。⇒ 需要「Q28 已解决」的场合，必须按**真实冷起样本**说话，不能用「0 坏/20+」外推。
3. 本晚会话 n 太小（4 发），单独看不足以推翻身份效应；它的作用是**给出 3 位臂的反例**，从而把结论从「治好」降级为「降险」。

**残余混淆项（诚实列出）**：
- **POR 质量**（物理断电时长/顺序）未仪器化确认；样本由人工执行，只能靠「用户确认为 POR」；
- **面板/PHY 残留态**（前一次启动的 PLL/rail 状态、连败“粘态”）——本晚两次坏发**连续**，与审计「坏发都在 Round 1 且连续」的观察同型；
- **温度/时间**（本晚会话为傍晚，审计 GOOD 样本多在夜间/早晨）；
- **镜像组合差异**：`vk113` = 日常组合（完整 ramdisk + ADSP DTB + `elden_nocamera=1`）；`vk104` = 模块化 ramdisk + 无 ADSP DTB。两者在 E2 臂（`vk109/vk110`）里已各自被排除过（DTB 翻转不改变结果、旧 ramdisk 恒 GOOD），但**没有被同时隔离**。

---

## 3. 对既有文档的更正

| 位置 | 原口径 | 更正后 |
|---|---|---|
| `PITFALLS #195` | 「3 位构建号 ⇒ STORM 消失（0 坏/20+），治法=3 位重编」 | 保留「`#60` 显著更差、3 位降险」，**新增反例**：3 位臂实测 1/23 坏发 ⇒ 非充分条件（见 `#217`） |
| `INDEX §3` / `DEVICE §1.1` | 「Q28 不阻塞日常与 G2」（基于身份论） | 改为：**Q28 是残余间歇坏发**（3 位身份下点估 4.3%、上界 21.9%），日常仍可能开机只见背光；恢复方式 = 关机重开（不自恢复） |
| `TASKS §5 Q28` | 收尾中（构建侧完成，待 3× 冷起） | **未收尾**：候选 `vk113` 出现 L1FAIL，**不刷 boot_b** |
| `reports/q28-vk113-20261012.md` | 「待上机」 | 已上机：1 GOOD / 1 L1FAIL；**不上线**，保持 `verification=NOT_TESTED_ON_DEVICE`→改为实测记录 |

---

## 4. 下一步候选（按信息量排序）

1. **同会话内配对采样（最便宜、最关键）**：交替 `vk94`(#60) 与 `vk104`(3 位) 各 2–3 发真实 POR。
   - 若 `#60` 仍显著多坏 ⇒ 身份效应在**今天**依然成立，「降险」结论稳；
   - 若两组都 ~50% ⇒ 身份效应可能是**跨会话/环境**的表观相关，须整体重写 Q28 口径。
2. **机制修复（真正的解）**：把上游对 SM8750 DSI 6G v2.9 byte-clock PLL re-lock 的修复 / Method B（`dsi_link_clk_set_rate_6g()` 取整）落到**日常组合**（新 `vk114`），再做 3 发冷起；机制 + 冷起样本双证据才谈得上「修好」。
3. **把残余现象报上游**（`dri-devel`/nt36536 线程）：附本文件的 4 发证据与 `status=0x2200200` 现场，问冷起竞态是否与 Dmitry 的 PLL re-lock 系列同源。

---

## 5. 复现命令

```bash
# 每次样本：用户物理 POR → fastboot 就绪后
bash scripts/q28-cold-run.sh out/boot-elden-vk113-dailyid.img vk113-coldN   # 候选
bash scripts/q28-cold-run.sh out/boot-elden-vk94.img        vk94-ctlN      # #60 对照
bash scripts/q28-cold-run.sh out/boot-elden-vk104-base-pin.img vk104-ctlN  # 3 位对照
# 判据：probe.txt 里 VERDICT + l1/l2 + session + 65 s 存活门；每发自动落 reports/trials/
```

---

## 6. 当晚完整会话（7 发）与「时间成簇」分析（2026-10-12 16:30–17:50）

| 序 | 时刻 | 镜像 | 臂性质 | 结果 |
|---|---|---|---|---|
| 1 | 16:30 | vk113-dailyid | 3 位身份 + 日常组合 | GOOD |
| 2 | 16:35 | vk113-dailyid | 同上 | **L1FAIL** |
| 3 | 16:39 | vk94 | `#60` + 日常组合（现役） | **L1FAIL** |
| 4 | 16:44 | vk104-base-pin | 3 位 + 模块化组合 | GOOD |
| 5 | 16:55 | vk94 | `#60` | GOOD |
| 6 | 17:41 | vk114-dailyid-round | 日常组合 **+ 上游 round 补丁** | **L1FAIL** |
| 7 | 17:47 | vk113-dailyid | 3 位 + 日常（严格 POR：断电 30 s） | **L1FAIL** |

**观察 1（臂无关）**：4 个不同臂、**4 坏 / 7（57%）**，签名逐字相同（`command DMA timeout: status=0x2200200`，t≈9.0 s）。第 6 发（`vk114`）证明**上游 byte-clk 取整修复不修我们的 STORM**；第 7 发（严格 POR）说明**断电时长不是原因**。

**观察 2（坏发按时间成簇）**：`reports/trials/index.tsv` 全部记录里，Q28 的 L1FAIL/STORM 从不单独出现，总成对/成簇：

| 坏发簇（UTC） | 样本 |
|---|---|
| 10-11 15:24–15:27 | `C1`, `D1` |
| 10-12 00:02–00:09 | `E2-110a`, `E1p-v111` |
| 10-12 08:37–08:41 | `vk113-cold2`, `vk94-ctl1` |
| 10-12 09:43–09:48 | `vk114-cold1`, `vk113-cold3` |

而**无 L1FAIL 的时间窗**里可以连续跑出成串 GOOD/NOCARD：10-11 11:51–14:51 的 PINUTS 系列 = 10 GOOD / 6 NOCARD / **0 L1FAIL**；10-11 23:14–23:26 = 4/4 GOOD。
⇒ 「3 位身份 0 坏 / 20+」这一证据**恰好落在无 L1FAIL 的时间窗内**；结合今晚同臂 57% 坏发，**更简约的解释 = 坏发率随会话/环境状态漂移（时间成簇），而非由镜像构建身份决定**。

**观察 3（运行期无法救回）**：在 L1FAIL 活台架上重绑 panel / `msm_dsi` host ⇒ `card0` 消失、fb 切 dummy、GPU hangcheck lockup，显示未恢复（`PITFALLS #224`、`logs/q28-rebind-20261012/`）。

---

## 7. 当晚结论（覆盖 §4 的候选排序）

1. **Q28 的缓解不在镜像层**：身份、round 补丁、复位时长都不改变坏发率；从 `PITFALLS #195` 派生的「3 位重编 = 治法」**作废**（「降险」仅作弱先验，不足以决策）。
2. **根治路径 = 驱动内机制**：bonded 双 DSI 首条 DCS 的 cmd-DMA 引擎在坏发时自锁（`status=0x2200200`）；下一步应写「encoder enable 失败 → `msm_dsi_host_power_off/on`（含 PHY/PLL 复位）→ 重试 panel init」的**驱动内自恢复**补丁，判据 = 坏发 boot 能自己出画面（不靠 POR）。注意本树 = `GEEKiDOS/linux`，`bonded command DMA failed`/`peer command DMA timeout` 这条路径为本树自带 ⇒ 同时向该上游/维护者报告。
3. **运营口径**：日常仍可能开机只见背光（当晚 4/7）；恢复 = 关机重开（暖复位在坏态可能粘住；运行期重绑无效）。相机 ⇄ 熄屏互斥（Q24）不变。

**重绑实验原始行（`logs/q28-rebind-20261012/dmesg-after-rebind.txt`，host-only 未入库）：**

```
[  141.760734] [    C5] msm_dpu ae01000.display-controller: [drm:hangcheck_handler] *ERROR* 44050000: hangcheck detected gpu lockup rb 0!
[  141.763483] [  T778] msm_dpu ae01000.display-controller: [drm:recover_worker] *ERROR* 44050000: hangcheck recover!
[  141.765286] [  T778] msm_dpu ae01000.display-controller: [drm:recover_worker] *ERROR* 44050000: offending task: phoc (/usr/bin/phoc -v -S -C /etc/phosh/phoc.ini -E gnome-session --session=phosh)
[  154.733700] [ T3357] Console: switching to colour dummy device 80x25
```

（`/sys/class/drm/` 重绑后只剩 `version`，`card0` 消失；panel unbind 写入时调用挂住数秒。）
