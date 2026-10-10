# 分界线：clean/base（功能确认层 / 实验层）— 2026-10-10

> **一句话**：内核树从今起以 **`clean/base`（= vk64 内核源 `d02658e63`）为唯一功能基线**；
> 该提交**之上**的一切提交（Q28 round/delay/诊断、Q24 E4a/FIX、kexec 实验、sd-* 显示实验…）
> 一律为**实验层**，只能作实验引用，**不得当功能基线**。任何新测试从 `clean/base` 起步。
> 本文只回答「分界线在哪、两边是什么、为什么这么切」；进度/状态仍以 `TASKS.md` 为准。

---

## 0. 背景：为什么立这条线

用户观察：**高版本（后续 vkN）开发加入了很多功能，也带来了混乱**。评估结论：
**整合（清理）当前线收益远大于退到 vk34 另起**。两条独立证据：

1. **净代码差极小**：`elden/vk34-recon`（vk34 干净回退点）→ 当前实验线 HEAD 的**净内容差只有
   7 个文件 / +1043 −126 行**（其中 1011 行是 `sm8750-lenovo-elden.dts`；其余
   `psci.c` 43 / `dsi_host.c` 38 / `nt36536.c` 15 / `q6apm*.c` 50）。
   ⇒ 「功能」大头早在 GEEKiDoS 基线里，post-vk34 真增量很小；**高版树不是代码膨胀**。
2. **混乱在构建/身份管线，不在内核代码**：`check-doctor` 实测曾 `FAIL=4 WARN=16`，
   24 个镜像有身份硬错、9 个「包入的内核不是本树」、dead kernel 事故（vk81/82/83，`PITFALLS #162`）。
   这些都源自 **patch overlay + config 片段 + 手工 vk TSV**，**退到 vk34 也换不回干净**。

⇒ 正确的「干净」动作 = **在当前树上划一条分界线**，而不是重置内核版本号。
退到 vk34 的代价（丢 PSCI reset 钩子、Q28 全部诊断/单变量资产、kexec guard、NFC/audio codec
DTS、cdsp 固件名…）与收益（一个换不来的「干净」）不匹配，已否决。

---

## 1. 分界线（两个锚点）

| 锚点 | 提交 | ref | 含义 |
|---|---|---|---|
| **主分界线** | `d02658e63`（vk64 内核源） | 分支 `clean/base` + tag `baseline/clean-base` | 本提交**及全部祖先** = **功能确认层**（G1 驱动 bringup 完整 + Q24 已定案 H2 + Q28 面板重试）。其上为**实验层** |
| 纯功能顶端 | `6c1376907`（"DP 打通"） | tag `baseline/feature-only` | 最后一个**纯功能**提交，其后无任何 Q24/Q28 补丁。需要「无 Q24/Q28 补丁」的功能对照时从此点起分支 |

从 `ba28ec16f`（GEEKiDoS 基线）到 `clean/base` 共 **18 个提交**，线性，无分叉
（其后再加 2 个 Q28 实验提交到 `q28/vk86` HEAD，合计 20）：

```
ba28ec16f (GEEKiDoS v7.2-elden 基线)
 ├ 6ef87e6a8 vk40 现场状态（含未清理调试插桩）
 ├ e72a036ed vk34-recon（回退 vk34 后增量）
 ├ 4b643f169 vk41  PSCI SYSTEM_RESET2 reset 钩子（reboot2 bootloader）
 ├ eb432f18a vk42  音频 + 温控（干净重落）
 ├ 26cc186e9 vk44  DMIC capture
 ├ a923477be vk45
 ├ 4c68eb5ed vk46  WCD939x 音频编解码
 ├ bd114ca33 vk47  WCD939x 采集
 ├ 2b5badef0 vk53  硬件驱动批次（NFC ST21NFCA + CDSP）
 ├ 8481c5a61 DTS   i2c0 关闭 / usb-role-switch / mdss_dp0
 ├ c132a1bc7 cdsp  split 固件（cdsp.mdt/cdsp_dtb.mdt）
 ├ 08791078c DTS   mdss_dp0 回退 disabled
 ├ 8b69eb153 相机 rotation +180
 ├ 6c1376907 DP 打通（dr_mode=otg + usb-role-switch + mdss_dp0）   ← baseline/feature-only
 ├ 171de3ae0 exp(Q24) H1 DTS + use_rpm=false（实验提交，保留）
 ├ c53e471be exp(Q24) D1/D2 无改善、回退驱动；保留 H1 DTS
 ├ be79b256d arm64: dts: qcom: sm8750: bind cambistmclkcc to MX only（H2，已上游化）
 └ d02658e63 nt36536 bonded-DSI init 在 -110 上重试（Q28）          ← clean/base（vk64）
```

> 注：`clean/base` 之前的 `171de3ae0`/`c53e471be` 虽名为 `exp(Q24)`，但它们是**已定案并保留**
> 的 Q24 状态（H1 DTS 保留 + H2 上游修复叠加），属确认层；真正划在线上的是其后的**未定案实验**。

---

## 2. 实验层清单（线之上，不得当功能基线）

**A. Q28 round/遥测（`q28/vk86`）**：`71bc68462`、`a8c09a723`
→ 产物 `out/boot-elden-vk86-{base,round,round2}.img`、`vk87-round2-v64`、`vk88-base-v64`。
Q28 根因已定案（`reports/q28-DOSSIER.md`，L1 = bonded 双 DSI 首条 DCS 命令 DMA 引擎 hang，~60% 冷起）；
这些提交是修法实验，**未收口**。

**B. Q28 诊断 + Q24 修法 + kexec 实验（`elden/vk53-hw`，tip `392b4897e`）**：
- Q28：`ca81318f2`（传播 power-up 失败）、`e3c5e9fea`（成功侧 dump cmd-DMA）、`97b8ee3c7`（E0 诊断增强）
- Q24：`68e8ab2c0`（E4a FIX-1 MX→MXC）、`e1d2c658a`+`67fcff7f0`（FIX-3 ±revert）、`86193a58a`（FIX-2）
- kexec（Q11）：`6cbe1ffa7`、`e70d0b660`、`da0d8fe20`、`c583f4537`、`d912d3c00`、`1443f263a`、`0d4bedf55`
- Q28 round：`392b4897e`

**C. 独立实验分支（各自 merge-base 在确认层内，未合并）**：

| 分支 | 基点 | 主题 |
|---|---|---|
| `sd-n2fix` / `sd-noGC` / `sd-noN2` / `sd-noN2N3` / `sd-noN3` | `bd114ca33`(vk47) | 显示/AudioReach 补丁 ±revert 二分 |
| `wifitim` / `wifibmiss-v1v2` | `bd114ca33`(vk47) | ath12k 省电/掉链候选（Q26 已关闭） |
| `elden/v1-thermal-only` / `elden/v2-audio-only` | `e72a036ed`(vk34-recon) | vk34 后增量隔离 |
| `elden/vk54-kexec-va52` | `2b5badef0`(vk53) | kexec trans_pgd |
| `archive/*` | — | 留档（vk43 留白、vk63 tree/H2、wip stash） |

**D. 已绑定 tag 的实验提交**：`vk79`(97b8ee3c7)、`vk81`(68e8ab2c0，死内核作废)、
`vk82`(e1d2c658a，作废)、`vk83`(86193a58a)、`vk70`(0d4bedf55)。

> 这些提交**不删**（已上机取证价值 + `archive` 只增不改纪律），但**只作实验引用**。

---

## 3. 纪律（分界线的可执行含义）

1. **新测试从 `clean/base` 起步**。任何 Q28/Q24/kexec/显示实验，从 `clean/base` 开 `exp/*` 分支，
   **禁止直接在 `clean/base` 上堆实验提交**。
2. **实验进确认层需先验收**：实验有设备侧验收（trial record）且结论落入 `TASKS.md`/`PITFALLS.md` 后，
   才可用 fast-forward / cherry-pick 进确认层，并把 tag/registry 收口。
3. **构建身份**：`vkN` = 构建流水号，非内核版本；内核身份 = **源提交 + 镜像内核载荷 sha256**
   （`PITFALLS #135`）。新支线构建必须打 tag，否则 `num_ne_tag`/`uts_lvs` 硬拦。
4. **`clean/base` 只增不改**：不在其上 rebase / force-push；需要重排时新开分支。

---

## 4. 本次同时完成的安全动作

- **pre-boundary 全 ref 备份**：`backup/kernel-git-repair-2026-10-10/elden-all-refs-pre-boundary.bundle`
  （`git bundle verify` 判为完整历史）。
- 只**新增** ref（分支 1 + annotated tag 2），**未改写任何历史**；`linux` 工作树构建时保持 clean。

## 5. 关联

- 版本口径：`PITFALLS` #135；死内核事故：`PITFALLS` #162；Q28 定案：`reports/q28-DOSSIER.md`。
- 任务/进度权威：`TASKS.md` §0/§5；内核迭代通道：`TASKS.md` §4。
