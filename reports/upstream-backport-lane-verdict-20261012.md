# 内核上游回移 lane 收尾 —— 裁决报告（elden/lane-upstream）

- 日期：2026-10-12 21:44–22:10（工作盒 40 min 内）
- 执行者：子代理「内核上游回移 lane 收尾」
- lane worktree：`/home/xuqianhui1001/y700-wt/wt-upstream-kernel`（分支 `elden/lane-upstream` @ `169d74806`）
- 基线：`clean/base` @ `5d01d3324`（主 worktree `/home/xuqianhui1001/y700-elden/geekidos-linux`）
- 纪律：**未**执行任何设备命令（无 fastboot/adb/ssh/EDL）；**未** push；**未** 合并任何 main/master；**未** 删除任何 lane 分支；tracked 文件改动数全程 = 0（`git status --porcelain | wc -l` = 0）。
- 方法：git 静态证据（ancestry/patch-id/range-diff/rebase）＋ 本地 vanilla 7.2 参照树（`build/m1-upstream/linux-7.2`）＋ `reference/upstream-pengyuluo/patches/`（上游 patch 原件）＋ arm64 交叉编译 + 本地 dtc 校验。

## 0. 仓库身份校验（第一条命令，原文照录）

```
$ cd /home/xuqianhui1001/y700-wt/wt-upstream-kernel && git rev-parse --show-toplevel && git remote -v | head -2 && git log -1 --format='%H %s'
/home/xuqianhui1001/y700-wt/wt-upstream-kernel
gitlab-archived	git@git.ustc.edu.cn:xqh/y700-elden-kernel.git (fetch)
gitlab-archived	no-push://archived-2026-10-08-shallow-frozen (push)
169d748060a1a4609b40cd1c4a42704575243c0d drm/msm: 回移 7.2.5-7.2.8 DSI/DPU/Adreno 稳定性补丁 + sm8750 参考板 PHY 供电
```

`head -2` 截到的是字母序第一的 `gitlab-archived`；完整 `git remote -v` 证明 **原点存在且相符**，无需判 mismatch：

```
$ git remote -v
gitlab-archived	git@git.ustc.edu.cn:xqh/y700-elden-kernel.git (fetch)
gitlab-archived	no-push://archived-2026-10-08-shallow-frozen (push)
origin	git@github.com:GEEKiDoS/linux.git (fetch)
origin	git@github.com:GEEKiDoS/linux.git (push)
$ git rev-parse --abbrev-ref HEAD
elden/lane-upstream
```

toplevel ✅ / origin = `git@github.com:GEEKiDoS/linux.git` ✅ / HEAD = `169d74806` ✅ ⇒ 通过，继续。

---

## 1. 逐 commit 判定

### 1.1 先把 lane 与基线的关系钉死

```
$ git log --oneline clean/base..elden/lane-upstream
169d74806 drm/msm: 回移 7.2.5-7.2.8 DSI/DPU/Adreno 稳定性补丁 + sm8750 参考板 PHY 供电
a00945de6 wireless/firmware: 回移 MHI SOC_RESET 刷新与 SCM tracepoint（7.2.6）
98fda55ca audio: 回移 7.2.6/7.2.10 上游音频补丁（q6apm 图计数/audioreach 零初始化/lpass-cpu DAI 索引）

$ git log --oneline elden/lane-upstream..clean/base      # 空 ⇒ 基线没有 lane 缺失的提交
$ git rev-parse clean/base elden/lane-upstream
5d01d3324d5ac5aa9a7c11c0268f8d3edb997d29
169d748060a1a4609b40cd1c4a42704575243c0d
```

逐 sha 的「是否已在基线」三元证据（`git log --all` 命中数 / `merge-base --is-ancestor`）：

```
for c in d02658e63 5d01d3324 98fda55ca a00945de6 169d74806; do
  n=$(git log --all --oneline | grep -c "^${c:0:9}")
  git merge-base --is-ancestor $c clean/base; a=$?
  printf '%-10s all_branches_hits=%s ancestor_of_clean/base=%s\n' "$c" "$n" "$a"
done
d02658e63  all_branches_hits=1 ancestor_of_clean/base=0   # 0 = 是祖先 ⇒ 已在基线
5d01d3324  all_branches_hits=1 ancestor_of_clean/base=0   # 同上（clean/base 的 tip 本身）
98fda55ca  all_branches_hits=1 ancestor_of_clean/base=1   # 1 = 不是祖先 ⇒ 新提交
a00945de6  all_branches_hits=1 ancestor_of_clean/base=1
169d74806  all_branches_hits=1 ancestor_of_clean/base=1
```

**结论 A**：`d02658e63`（Q28 面板 nt36536 retry）与 `5d01d3324`（sm8750 ADSP fastrpc non-secure-domain）
**已经是 clean/base 的祖先 ⇒ 已在基线树内**，本 lane 无需任何动作；本 lane 的净增量 = 后面 3 个 commit。

补丁级重复检查（patch-id 等价）：

```
$ git cherry -v clean/base elden/lane-upstream
+ 98fda55ca… audio: …
+ a00945de6… wireless/firmware: …
+ 169d74806… drm/msm: …
```

三条全为 `+`（基线中**不存在**等价 patch）⇒ 无「同一补丁两个来源」的重复风险。

### 1.2 `98fda55ca` audio（3 文件 +13/−7）

```
$ git show --stat 98fda55ca
 sound/soc/qcom/lpass-cpu.c       |  4 ++--
 sound/soc/qcom/qdsp6/q6apm-dai.c |  4 ++--
 sound/soc/qcom/qdsp6/q6apm.c     | 12 +++++++++---
```

（a）`q6apm.c`：把 `start_count` 语义收紧 —— 基线是「START 失败也照样 `start_count++` 并返回错误」，回移后是「START 失败立即 return，不动计数；`graph_stop` 在 `start_count==0` 时直接返回，不再下溢」。原文：

```
-	int ret = 0;
-	if (ar_graph->start_count == 0)
+	if (ar_graph->start_count == 0) {
 		ret = audioreach_graph_mgmt_cmd(ar_graph, APM_CMD_GRAPH_START);
+		if (ret)
+			return ret;
+	}
 	ar_graph->start_count++;
-	return ret;
+	return 0;
@@ q6apm_graph_stop
+	if (ar_graph->start_count == 0)
+		return 0;
+
 	if (--ar_graph->start_count > 0)
```
语义自洽（失败不再污染计数；stop 不再下溢），无副作用面。

（b）`q6apm-dai.c`：两处 `struct audioreach_module_config cfg;` → `= {}`（`:217`、`:813`）。
核对填充点：`:231-236` 与 `:834-841/866-871` **逐字段赋值齐全**（direction/sample_rate/num_channels/bit_width/fmt/channel_map（+codec memcpy））
⇒ 该 hunk 是**防御性**改动（零初始化未用字段/填充字节），不是行为修复，无回归风险。

（c）`lpass-cpu.c`：`variant->dai_driver[dai_id]` → `[i]`。树内一致性可证：同一循环里
`dai_id = variant->dai_driver[i].id;`，即 `[i]` 才是「正在被检查的那个 DAI」，而 `mi2s_playback_sd_mode[dai_id]` 是按 id 索引
⇒ 当某 variant 的 dai id 不连续（含 DP_RX 等）时原写法会改错条目，改后正确。

（d）与 vanilla 7.2 的关系（证明这些是 7.2 之后的 stable 修复、不是凭空发明）：

```
$ grep -n 'struct audioreach_module_config cfg;' build/m1-upstream/linux-7.2/sound/soc/qcom/qdsp6/q6apm-dai.c
217:	struct audioreach_module_config cfg;
813:	struct audioreach_module_config cfg;
```
（`rounded_byte_clk_rate`/`sched_initialized` 等 post-state 标记在 vanilla 7.2 全部 ABSENT，见 §1.4/§3。）

**判定：可合入**（编译通过、无冲突、逐 hunk 静态自洽）。唯一未尽事项：本仓库是浅快照，**无法本地比对上游对应 commit 文本**（见 §6），合并前建议用上游 7.2.6/7.2.10 的 commit 文本对一次 trailer/描述。

### 1.3 `a00945de6` wireless/firmware（+149）

```
$ git show --stat a00945de6
 drivers/bus/mhi/host/main.c            |   6 ++
 drivers/firmware/qcom/qcom_scm_trace.h | 143 +++++++++++++++++++++++++++++++++
```

（a）MHI 部分 —— 在 `mhi_soc_reset()` 写完 `MHI_SOC_RESET_REQ` 后回读一次以冲掉 posted write：

```
+	/* Flush the posted write to the device (ignore return value) */
+	ret = mhi_read_reg(mhi_cntrl, mhi_cntrl->regs, MHI_SOC_RESET_REQ_OFFSET,
+			   &tmp);
```
（`int __maybe_unused ret;` 只是为压掉 set-but-unused 告警；`Flush the posted write` 标记在 vanilla 7.2 = ABSENT ⇒ 7.2 之后的新改动。）方向合理、编译通过。

（b）**`qcom_scm_trace.h` = 死代码（本 lane 最硬的一处缺陷）**：

```
$ git grep -n 'qcom_scm_trace' elden/lane-upstream
elden/lane-upstream:drivers/firmware/qcom/qcom_scm_trace.h:140:#define TRACE_INCLUDE_FILE qcom_scm_trace

$ grep -rn 'trace_scm_\|CREATE_TRACE_POINTS\|qcom_scm_trace' drivers/firmware/qcom/qcom_scm.c drivers/firmware/qcom/Makefile
(无输出)
```

全树除文件自身的 `TRACE_INCLUDE_FILE` 外**没有任何引用**：`qcom_scm.c` 既没有 `#include "qcom_scm_trace.h"`，也没有 `CREATE_TRACE_POINTS`，更没有 `trace_scm_smc_request()/trace_scm_waitq_sleep()` 调用点，`Makefile` 也没拉它。
⇒ 该头文件**从未被编译**（所以「编译通过」对它没有任何证明力），也没有任何可观测功能；与 commit message 宣称的「SCM tracepoint 回移」不符（只搬了定义文件、丢了使用者）。

**判定：需修改** —— MHI hunk 可合入；`qcom_scm_trace.h` 要么删除，要么补齐 4 处联动（`qcom_scm.c` 的 include + `CREATE_TRACE_POINTS` + 各 trace 调用点，若上游还改了 `drivers/firmware/qcom/Makefile`/trace 目录则一并补）。**不可按现状合入**（零功能 + 死文件进入上游化清单会被 review 直接打回）。

### 1.4 `169d74806` drm/msm + DTS（11 文件 +35/−14）

vanilla 7.2 的 post-state 标记全为 ABSENT（证明这些都是 7.2 之后的新改动）：

```
PAT[rounded_byte_clk_rate]                  -> ABSENT
PAT[If we.re going offline]                 -> ABSENT
PAT[sched_initialized]                      -> ABSENT
PAT[Flush the posted write]                 -> ABSENT
PAT[!!test_and_clear_bit(GMU_STATUS_FW_START] -> ABSENT
PAT[gpu->funcs->recover]                    -> ABSENT
PAT[pm_runtime_dont_use_autosuspend]        -> PRESENT（但位置不同，见下）
PAT[pending_periph_flush_mask]              -> PRESENT（但清零处缺失，见下）
```

#### (1) `drivers/gpu/drm/msm/dsi/dsi_host.c` —— **致命项：回移了上游已回滚的补丁**

lane 的 hunk 与 `reference/upstream-pengyuluo/patches/6cd33b6f4155.patch`（Kavan Smith，
`drm/msm/dsi: round 6G byte clock rate to the PLL-achievable value`，`Cc: stable`）**逐字相同**：

```
# lane 提交 169d74806 的 dsi hunk（原文）
 int dsi_calc_clk_rate_6g(struct msm_dsi_host *msm_host, bool is_bonded_dsi)
 {
+	long rounded_byte_clk_rate;
 	...
 	dsi_calc_pclk(msm_host, is_bonded_dsi);
+
+	rounded_byte_clk_rate = clk_round_rate(msm_host->byte_clk,
+					       msm_host->byte_clk_rate);
+	if (rounded_byte_clk_rate < 0) {
+		pr_err("%s: failed to round byte clock rate, %ld\n", __func__, rounded_byte_clk_rate);
+		return rounded_byte_clk_rate;
+	}
+	msm_host->byte_clk_rate = rounded_byte_clk_rate;
 	msm_host->esc_clk_rate = clk_get_rate(msm_host->esc_clk);

# reference/upstream-pengyuluo/patches/6cd33b6f4155.patch（原文，一模一样，仅 hunk 行号不同）
@@ -670,12 +670,24 @@ static void dsi_calc_pclk(...)
 int dsi_calc_clk_rate_6g(struct msm_dsi_host *msm_host, bool is_bonded_dsi)
 {
+	long rounded_byte_clk_rate;
 	if (!msm_host->mode) { ... }
 	dsi_calc_pclk(msm_host, is_bonded_dsi);
+	rounded_byte_clk_rate = clk_round_rate(...);
+	...
+	msm_host->byte_clk_rate = rounded_byte_clk_rate;
 	msm_host->esc_clk_rate = clk_get_rate(msm_host->esc_clk);
```

而上游随后用 `2028280686f4`（Dmitry Baryshkov，2026-09-03）把它**搬走并判为回归**，patch 原件就在本仓库：

```
$ head -20 reference/upstream-pengyuluo/patches/2028280686f4.patch
Subject: drm/msm/dsi: round the byte clock rate after reparenting to the PHY PLL
... dsi_calc_clk_rate_6g() runs earlier, in order to compute the bit clock
request for the PHY. At that point the byte RCG still has its reset
parent (XO), so clk_round_rate() returns a bogus rate, which then ends up
in the PHY bit clock request and the PLL gets programmed to a wrong
frequency, breaking the panel.
Move the rounding to dsi_link_clk_set_rate_6g(), which is called after
the RCGs have been reparented to the PLL.
Fixes: 6cd33b6f4155 ("drm/msm/dsi: round 6G byte clock rate to the PLL-achievable value")
```

本仓库三处旁证（全部指向同一结论）：

```
$ for ref in clean/base elden/lane-upstream d02658e63 origin/v7.2-elden; do git grep -c clk_round_rate $ref -- drivers/gpu/drm/msm/dsi/dsi_host.c; done
clean/base                            0        # 基线无取整
elden/lane-upstream:…/dsi_host.c:1     # = 本 lane 新增（且只有这一处）
d02658e63                             0
origin/v7.2-elden                     0
$ grep -n 'clk_round_rate' drivers/gpu/drm/msm/dsi/dsi_host.c
720:	rounded_byte_clk_rate = clk_round_rate(msm_host->byte_clk,
```

- `reference/upstream-pengyuluo/README.md:39`：`2028280686f4` = **NOT-IN-TREE**（"＝Method B 要补"）。
- `reports/q28-upstream-static-20261012.md:11`：「把 `clk_round_rate()` 放在 **reparent 之前**…正是上游 `2028280686f4` 要修的时机错误 ⇒ **必须改**」；`:12` 记本树 `dsi_calc_clk_rate_6g()` **无取整**「= 上游 Fixes 后状态」；`:132` 明确 Method B 的正确落点 = `dsi_link_clk_set_rate_6g()`（reparent 之后）。
- `archive/topics/UPSTREAM-REPORT-q28-bonded-dsi-2026-10-12.md:13/48`：**上游的 byte-clk 取整修复（`2028280686f4`）在我们的镜像上无效**（按上游语义移植 → `vk114` → **仍坏，签名逐字同**）。

⇒ 本 lane 回移的是「被上游回滚的那一版」，且其**正确版**在本项目上已实测对 Q28 无效。这是「按 7.2.5→7.2.8 稳定版区间机械扫码」的典型陷阱（`Cc: stable` 让回归版进了稳定树，修复/revert 在其后）。

**判定：丢弃该 hunk（必须）** —— 它单独存在就是上游已确认的「把伪速率灌进 PHY bitclk → PLL 编错频 → 破屏」路径，且对 Q28 无收益；如需 byte-clk 取整，应改用 `2028280686f4` 等价实现（注意本树 `dsi_link_clk_set_rate_6g_v2_9()` 内有私有 `dev_pm_opp_set_rate` 前置块，patch 需按本树改锚点，见 `reports/q28-upstream-static-20261012.md` §2.1/`:89`）。

#### (2) 其余 10 个 hunk（逐项）

| 文件 / hunk | 代码级判定依据 | 判定 |
|---|---|---|
| `dpu_hw_ctl.c`：`dpu_hw_ctl_clear_pending_flush()` 补 `ctx->pending_periph_flush_mask = 0;` | vanilla 7.2 同函数（`:113-127`）**确实漏清这一位**（其他 6 个 mask 都清）；本树 struct 里该字段在 `dpu_hw_ctl.c:347` 被置位 ⇒ 漏清 = 残留 periph flush | ✅ 保留（真修复） |
| `dpu_core_perf.c`：`if (!clk_rate) return 0;`（在 trace 之后、`dev_pm_opp_set_rate` 之前） | 上下文完整读过：`clk_rate = _dpu_core_perf_get_core_clk_rate(kms)`，`clk_rate==0` 只在 crtc 全部 offline 时出现，注释「PM callbacks will disable the clocks instead」与分支一致；跳过的是 OPP 投票与 `kms->perf.core_clk_rate` 记账 | ⚠️ 保留但需上机（行为性） |
| `dp/dp_ctrl.c`：删除 3 处 `dev_pm_opp_set_rate(ctrl->dev, 0)` | vanilla 7.2 这三处**存在**（`:1958/:1985/:2576`）⇒ 属 7.2 之后的改动；删除后 OPP 由 PM 回调回收 | ⚠️ 保留但需上机（DP 已打通，属回归敏感面） |
| `adreno/a6xx_gmu.c`：`a6xx_rpmh_stop()` 条件由 `if (test_and_clear_bit(...)) return;` 改 `if (!…)` | 函数体完整读过：body = `REG_A6XX_GMU_RSCC_CONTROL_REQ=1` → 轮询 `RSC_STATUS0_DRV0` bitmask → 归 0 → `set_bit(PDC_SLEEP)`。原写法「FW 已启动就 return」会让 RSC **永不关机**；改后语义 = 「FW 未启动则无事可做，否则做关机握手」。vanilla 7.2 `:645` = 未反转版（本树基线同） | ✅ 保留（真修复，需上机确认关机路径） |
| `adreno/a6xx_gmu.c`：`a6xx_gmu_shutdown()` 中加 `gmu_write(gmu, REG_A6XX_GMU_CM3_SYSRESET, 1);` | 该寄存器在本文件已用于 `:307/:320`（上电序列）与 `:1158` ⇒ 符号存在、语义（halt CM3 核）与「shutdown」一致 | ✅ 保留 |
| `adreno/adreno_gpu.c`：`adreno_gpu_cleanup()` 加 `pm_runtime_dont_use_autosuspend(&gpu->pdev->dev);` | **本树已存在两处同类调用**（`a6xx_gpu.c:1586`、`a8xx_gpu.c:895`，vanilla 同）⇒ lane 之后变成 3 处 | ⚠️ 冗余（幂等、低风险）；上游该 commit 很可能是「搬移而非新增」，建议核对上游文本后决定是否删掉原两处之一 |
| `msm_gpu.c`：`recover_worker()` 中把 `gpu->funcs->recover(gpu)` 提到 `retire_submits(gpu)` **之前** | 纯顺序调整，fence 回收前先复位 HW；vanilla 7.2 无 `gpu->funcs->recover` | ⚠️ 保留但需上机（GPU 崩溃恢复路径） |
| `msm_ringbuffer.c`+`.h`：新增 `bool sched_initialized`，`drm_sched_init` 成功后置位，`msm_ringbuffer_destroy` 仅在已初始化时 `drm_sched_fini` | 明显的「失败路径不再 destroy 未初始化 sched」防御修复；字段新增与两处使用自洽 | ✅ 保留（真修复） |
| `sm8750-mtp.dts` / `sm8750-qrd.dts`：`usb_dp_qmpphy` 的 `vdda-phy-supply`/`vdda-pll-supply` 互换 | 兄弟板约定一致：`sm8650-mtp.dts:655-656`（`usb_dp_qmpphy` → `vreg_l1i_0p88` / `vreg_l3i_1p2`）、`sm8550-mtp.dts:950-951` ⇒ **vdda-phy = 0.88V 轨、vdda-pll = 1.2V 轨**；改后本板 = `vreg_l2d_0p88`(0.88V) / `vreg_l3g_1p2`(1.2V) ⇒ 与约定一致，改前为反接 | ✅ 保留（真修复），见 §3 DTB 复核 |

**判定：需修改** —— 仅 DSI hunk 必须处置（§1.4(1)）；其余 10 个文件可留（其中 4 项标 ⚠️ 属行为性改动，建议上机单变量验证）。

---

## 2. rebase 可行性

### 2.1 range-diff 原始输出（`clean/base` vs lane）

```
$ git range-diff clean/base...elden/lane-upstream
-:  --------- > 1:  98fda55ca audio: 回移 7.2.6/7.2.10 上游音频补丁（q6apm 图计数/audioreach 零初始化/lpass-cpu DAI 索引）
-:  --------- > 2:  a00945de6 wireless/firmware: 回移 MHI SOC_RESET 刷新与 SCM tracepoint（7.2.6）
-:  --------- > 3:  169d74806 drm/msm: 回移 7.2.5-7.2.8 DSI/DPU/Adreno 稳定性补丁 + sm8750 参考板 PHY 供电
```

读法：三行全是 `-: --------- > N:`（左侧空、右侧有）⇒ 基线侧在 `clean/base..lane` 内**没有对应提交**，
且**没有任何一行两侧都有** ⇒ **无「同一改动两种实现」的语义分叉、无重复、无冲突**。
配对的 `lane..clean/base` 为空（§1.1）⇒ lane 是 clean/base 的**严格后代**，rebase 到 clean/base 是 **no-op**。

### 2.2 合并冲突检查 + 临时分支 rebase 实测

```
$ git merge-tree --write-tree clean/base elden/lane-upstream
774d78fdd43a927ae2eec0daf765aac6a7ed916e
merge_tree_rc=0                       # 写出合并树、无冲突

$ git switch -c verify/lane-rebase-20261012 elden/lane-upstream
切换到一个新分支 'verify/lane-rebase-20261012'
$ git rebase --onto clean/base 5d01d3324
当前分支 verify/lane-rebase-20261012 是最新的。
after_rebase HEAD=169d748060a1a4609b40cd1c4a42704575243c0d    # SHA 未变 ⇒ 无重放、无冲突
```

**冲突文件：无。** 机制上必然如此：这 3 个 commit 的父提交就是 `clean/base`。

### 2.3 附加实验（对上游化更有意义）：重放到 vanilla `origin/v7.2-elden`

```
$ git switch -c verify/lane-on-vanilla-20261012 elden/lane-upstream
$ git rebase --onto origin/v7.2-elden 5d01d3324
正在变基（1/3）正在变基（2/3）正在变基（3/3）
成功变基并更新 refs/heads/verify/lane-on-vanilla-20261012。
conflicted_files=[]                   # 3/3 干净重放；新 tip = 7efd8bd14（SHA 变化 ⇒ 确为真实重放）
```

⇒ 这 3 个 commit **不依赖 elden 本地 DTS/驱动改动**，可直接落到底层上游基线上（对 G1 上游化有利）。

---

## 3. 构建验证（时间盒，未上机）

环境（与项目 `scripts/env-build.sh` 同款）：`ARCH=arm64`、
`CROSS_COMPILE="ccache aarch64-linux-gnu-"`、`CC="ccache aarch64-linux-gnu-gcc"`、`CCACHE_DIR=$HOME/.cache/ccache-elden`。
配置来源 = 项目 canonical 配置，**sha256 逐个相等**：

```
$ sha256sum .config /home/xuqianhui1001/y700-elden/linux/.config
f008aae441af6170b97c850cf4d6e371a872d204d6ef6b3d2d0ab00c45b9d7ea  .config
f008aae441af6170b97c850cf4d6e371a872d204d6ef6b3d2d0ab00c45b9d7ea  /home/xuqianhui1001/y700-elden/linux/.config
```

### 3.1 受影响 C 文件（12 个 .o 全量重编译，rc=0）

```
$ rm -f <12 个 .o>   # 强制重编译，避免“已是最新”假证据
$ make -j16 drivers/gpu/drm/msm/dsi/dsi_host.o drivers/gpu/drm/msm/disp/dpu1/dpu_core_perf.o \
        drivers/gpu/drm/msm/disp/dpu1/dpu_hw_ctl.o drivers/gpu/drm/msm/dp/dp_ctrl.o \
        drivers/gpu/drm/msm/adreno/a6xx_gmu.o drivers/gpu/drm/msm/adreno/adreno_gpu.o \
        drivers/gpu/drm/msm/msm_gpu.o drivers/gpu/drm/msm/msm_ringbuffer.o \
        drivers/bus/mhi/host/main.o sound/soc/qcom/qdsp6/q6apm.o \
        sound/soc/qcom/qdsp6/q6apm-dai.o sound/soc/qcom/lpass-cpu.o
  CC      drivers/bus/mhi/host/main.o
  CC [M]  sound/soc/qcom/lpass-cpu.o
  CC      sound/soc/qcom/qdsp6/q6apm.o
  CC      sound/soc/qcom/qdsp6/q6apm-dai.o
  CC      drivers/gpu/drm/msm/dsi/dsi_host.o
  CC      drivers/gpu/drm/msm/disp/dpu1/dpu_core_perf.o
  CC      drivers/gpu/drm/msm/disp/dpu1/dpu_hw_ctl.o
  CC      drivers/gpu/drm/msm/dp/dp_ctrl.o
  CC      drivers/gpu/drm/msm/adreno/a6xx_gmu.o
  CC      drivers/gpu/drm/msm/adreno/adreno_gpu.o
  drivers/gpu/drm/msm/msm_gpu.o
  drivers/gpu/drm/msm/msm_ringbuffer.o
rc=0                                   # 无 warning/无 error
```

关于 `.ko` 链接期的一次 modpost 报错（**与 lane 代码无关，需说明以免误读**）：

```
$ make -j16 sound/soc/qcom/snd-soc-lpass-cpu.ko
  MODPOST Module.symvers
ERROR: modpost: "asoc_qcom_lpass_platform_register" [sound/soc/qcom/snd-soc-lpass-cpu.ko] undefined!
$ ls Module.symvers
ls: cannot access 'Module.symvers': No such file or directory
```
原因：该符号由**另一个模块** `snd-soc-lpass-platform`（`CONFIG_SND_SOC_LPASS_PLATFORM=m`，`lpass-platform.c:1393` EXPORT）提供，
而本 worktree 从未跑过完整 `make modules`，顶层 `Module.symvers` 不存在 ⇒ modpost 对**任何**跨模块引用都会失败。
编译本 lane 改动的那一步（`CC [M] sound/soc/qcom/lpass-cpu.o`）成功，故这是构建状态问题而非代码缺陷。

### 3.2 DTS（`make dtbs` + 独立 dtc 管线 + blobs 内省）

```
$ make -j16 dtbs
  DTC     arch/arm64/boot/dts/qcom/sm8750-mtp.dtb
  DTC     arch/arm64/boot/dts/qcom/sm8750-qrd.dtb
$ ls -la arch/arm64/boot/dts/qcom/sm8750-mtp.dtb arch/arm64/boot/dts/qcom/sm8750-qrd.dtb
-rw-rw-r-- 1 xuqianhui1001 xuqianhui1001 127969 Oct 12 21:54 …/sm8750-mtp.dtb
-rw-rw-r-- 1 xuqianhui1001 xuqianhui1001 124353 Oct 12 21:54 …/sm8750-qrd.dtb
```

独立校验（`cpp` + 内核自带 `scripts/dtc/dtc`，即内核 cmd_dtc 同款管线）：

```
[sm8750-mtp] cpp_rc=0 cpp_err=0 ; dtc_rc=0 dtc_err_lines=16
[sm8750-qrd] cpp_rc=0 cpp_err=0 ; dtc_rc=0 dtc_err_lines=16
# 16 条 warning 全部落在未改动的 sm8750.dtsi 节点（dsi@ae94000/ae96000 的 addr_size、geniqup i2c/spi unit-address 重复），与本次改动无关
```

改动是否真的进了镜像（反编译 blobs 反解 phandle）：

```
$ dtc -I dtb -O dts sm8750-mtp.dtb | (python3 解析 regulator-name ↔ phandle)
vreg_l2d_0p88: phandle=0x9c      vreg_l3g_1p2: phandle=0x9d
vreg_l1f_0p88: phandle=0x125     vreg_l1j_0p91: phandle=0x127
node='phy@88e8000' phy=0x9c  pll=0x9d      # = usb_dp_qmpphy：vdda-phy=vreg_l2d_0p88(0.88V), vdda-pll=vreg_l3g_1p2(1.2V) ✅ 正是本 lane 改后的状态
node='phy@1c06000' phy=0x125 pll=0x9d      # 其他 PHY（未改）
node='phy@1d80000' phy=0x127 pll=0x9d
```
⇒ DTS 改动确认落进构建产物，且与兄弟板（`sm8650-mtp`/`sm8550-mtp` 的 `usb_dp_qmpphy`）约定一致。

### 3.3 构建副作用披露（自查，已修复）

我第一次尝试把 `export …; make …` 整体交给 `timeout` 封装，导致 `export` 未被 shell 执行 ⇒ 那几次 `make` 用了**宿主 ARCH=x86** 且触发 kconfig `--syncconfig` 重写
`.config`（sha 曾变为 `d3acf3ab…`，arm64-only 符号被丢弃，随后 `make dtbs` 出现 `CORESIGHT (NEW)` 交互提示失败）。
处置：从 canonical 配置 `cp` 恢复（sha 回到 `f008aae4…`，见 §3.0 校验）、重跑受影响 .o/DTB 编译；
`.config`/`include/config/*` 均为未跟踪构建产物，**tracked 文件全程 0 变更**（`git status --porcelain | wc -l` = 0）。
`make dtbs` 前被 `rm` 掉的 2 个 dtb 已在 §3.2 重建。另：$HOME 下/工作树内未留设备相关改动，未产生 boot 镜像。

### 3.4 未做的构建项

- 未做全量 `Image.gz`/`make modules`/boot 镜像（时间盒 + 非必需；累计编译 ≈ 3 min，远低于 25 min 上限）
- **未上机**（纪律）：无 fastboot/adb/ssh/EDL 调用

---

## 4. 明确裁决（逐 commit 一句）

| commit | 裁决 | 理由（一句） | 下一步 |
|---|---|---|---|
| `d02658e63` | **无需动作（已在基线）** | `git merge-base --is-ancestor d02658e63 clean/base` = 0（是祖先），且 `clean/base..lane` 不含它 | 无（Q28 面板 retry 已在基线内） |
| `5d01d3324` | **无需动作（已在基线）** | 它本身就是 `clean/base` 的 tip，属 lane 的父提交 | 无 |
| `98fda55ca` | **可合入** | 3 hunk 全部静态自洽（START 失败不再污染 `start_count`、`stop` 不下溢、`cfg` 字段填充本已齐全故为防御性、`dai_driver[i]` 与 `dai_id = …[i].id` 一致），vanilla 7.2 无这些标记 ⇒ 属 7.2 之后的修复，arm64 重编译 rc=0、rebase/merge 零冲突 | 合并前用上游 7.2.6/7.2.10 的 commit 文本核对一次；清掉 `Lane/Agent/Baseline/Task/VK` trailer |
| `a00945de6` | **需修改（不可按现状合入）** | MHI 回读冲写方向合理且编译通过；但 `qcom_scm_trace.h` 是**从未被编译、零引用的死文件**（全树只匹配到它自己的 `TRACE_INCLUDE_FILE`），宣称的 tracepoint 功能完全没实现 | 删掉该头文件，或补齐 `qcom_scm.c` 的 include + `CREATE_TRACE_POINTS` + `trace_scm_*` 调用点（及上游若有的 Makefile/trace 目录改动） |
| `169d74806` | **需修改（拆开：丢 1 保留 10）** | DSI hunk 与上游**已回滚**的 `6cd33b6f4155` 逐字相同（上游 `2028280686f4` 明文 `Fixes:` 它，理由=reparent 前取整得伪速率→PHY bitclk/PLL 编错频→破屏），且本项目 `vk114` 已实测其**修正版**对 Q28 无效；其余 10 文件为真修复/低风险（含 2 个 DTS 供电反接修正，已用构建出的 DTB 反解确认） | ①移除 `dsi_host.c` hunk；若确需取整，改用 `reference/upstream-pengyuluo/patches/2028280686f4.patch` 并按本树 `dsi_link_clk_set_rate_6g_v2_9()` 私有前置块调整锚点；②核对 `adreno_gpu_cleanup` 的 `pm_runtime_dont_use_autosuspend` 是否应为「搬移」（本树现有 3 处调用）；③4 个行为性 hunk（DP OPP、DPU clk_rate、a6xx_rpmh_stop、msm_gpu recover 顺序）待上机单变量验证 |

---

## 5. 与 `reference/` / `reports/` 已知结论的冲突（重点：Q28 DSI）

| # | 冲突点 | lane 的写法 | 既有结论 | 级别 |
|---|---|---|---|---|
| C1 | **byte-clk 取整落点** | 放在 `dsi_calc_clk_rate_6g()`（**reparent 之前**）——即上游 `6cd33b6f4155` | `reports/q28-upstream-static-20261012.md:11`：该落点「正是上游 `2028280686f4` 要修的**时机错误 ⇒ 必须改**」；`:12` 记本树正确状态 = `dsi_calc_clk_rate_6g()` **无取整**；`:132` 明确正确落点 = `dsi_link_clk_set_rate_6g()`（reparent 之后） | 🔴 直接冲突，**必须按既有结论处置** |
| C2 | **上游补丁版本** | 用了被 revert 的 `6cd33b6f4155` | `reference/upstream-pengyuluo/README.md:39`：`2028280686f4` = **NOT-IN-TREE**（Method B 待补）；`2028280686f4.patch` 原文自带 `Fixes: 6cd33b6f4155` | 🔴 直接冲突（lane 回移了上游已废弃版本） |
| C3 | **对 Q28 的价值** | 隐含「DSI 稳定性修复」 | `archive/topics/UPSTREAM-REPORT-q28-bonded-dsi-2026-10-12.md:13`：「上游的 byte-clk 取整修复（`2028280686f4`）在我们的镜像上**无效**」；`:48`：按上游语义移植 → `vk114` → **仍坏（签名逐字同）** | 🟠 收益=0（且风险≠0），加强「丢弃」结论 |
| C4 | `pm_runtime_dont_use_autosuspend` | 在 `adreno_gpu_cleanup()` **新增**第 3 处调用（`a6xx_gpu.c:1586`、`a8xx_gpu.c:895` 仍在） | 既有文档未讨论；vanilla 7.2 已存在那两处 ⇒ 疑为「应搬移而非新增」 | 🟡 无文档冲突，但与「回移=忠实搬运」的原则有出入 |
| C5 | 其余 | DPU `pending_periph_flush_mask`、`dai_driver[i]`、DTS 供电互换、`a6xx_rpmh_stop` 条件反转 | 与 Q24（`cambistmclkcc`）/Q28（DSI 闩锁）文档均**无交叉**；DP 相关改动与 `reports/` 里 DP 结论不冲突（那边只记 `mdss_dp0 okay` 与 role-switch） | 🟢 未见冲突 |

补充（未在既有文档中的新发现）：
- `qcom_scm_trace.h` 死代码（§1.3）——既有 `reports/` 未覆盖。
- 稳定版区间扫描陷阱：`Cc: stable` 的回归补丁会先进入 7.2.y、随后才被上游 revert ⇒ 「按 7.2.5→7.2.8 扫 drm/msm 修复」这类机械回移会捞到废补丁。建议沉淀为 PITFALLS 规则（本次未改任何文档）。

---

## 6. 限制与「未做」清单（如实）

1. **无上游历史可比**：本仓库是浅/嫁接快照（`git rev-list --count --all` = 95，根提交 = `ba28ec16f` `(grafted, origin/v7.2-elden)`）。
   因此「已在基线」的证明是**仓库内**证明（`--all` 命中 + ancestry + patch-id + range-diff），
   除 DSI 一处（有 patch 原件可比）外，**其余 hunk 的上游 commit 身份未做独立核验**（需联网 `git fetch`/patchwork）。
2. **未上机**：所有「修复 vs 回归」的行为性判断都是代码级推理（尤其 §1.4(2) 中标 ⚠️ 的 4 项）。
3. 未做全量镜像构建、未生成 boot 镜像、未跑任何测试套件（非本任务范围）。
4. 本地 vanilla 7.2 参照树（`build/m1-upstream/linux-7.2`）只能证明「这些改动不在 7.2 里」，不能证明「在 7.2.5-7.2.8 里」。

## 7. 环境副作用清单（供编排者核对）

- 临时分支（**保留**，未删）、`git branch -v`：
  - `verify/lane-rebase-20261012` = `169d74806`（clean/base 重放：no-op 证据）
  - `verify/lane-on-vanilla-20261012` = `7efd8bd14`（→ `origin/v7.2-elden` 的干净重放）
- lane 分支 `elden/lane-upstream` 仍 = `169d74806`（**未动**）；`git status --porcelain` 全程为空。
- 构建产物：`.config`（已恢复 canonical sha）、`include/config/*`、12 个 `.o`、`sm8750-mtp.dtb`/`sm8750-qrd.dtb` 等未跟踪文件；无 tracked 文件变化。
- 临时脚本：`/tmp/lane-build-verify.sh`、`/tmp/lane-final-verify.sh`、`/tmp/lane-git-verify.sh`、`/tmp/lane-code-ctx.sh`、`/tmp/lane-crosscheck.sh`、`/tmp/lane-vanilla.sh`、`/tmp/lane-dup.sh`、`/tmp/lane-phandle.sh`、`/tmp/lane-doc-cross.sh`。
- 未 push、未 merge、未删除任何 lane 分支、未触碰设备。
