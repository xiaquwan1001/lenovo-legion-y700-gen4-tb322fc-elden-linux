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
