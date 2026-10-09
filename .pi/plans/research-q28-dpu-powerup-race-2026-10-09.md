# Q28 源码分析：DPU 上电/时钟 bring-up 间歇没跑 —— 根因假设 + 上游规范鲁棒化草案

> 生成 2026-10-09。**父进程亲自复验**（子代理连两次在"写报告"步退化成重复闭合标签、未落盘；证据从 `worker d869c01c` 的 output-0.log 捞回，行号全部父用 `git show d02658e63:<path>` 独立复核）。
> 分析基线 = commit `d02658e63`。只读，未 apply、未编译。

## 结论前置（一句话）
最可能近因 = **DPU 上电/时钟 bring-up 走的是 runtime-PM `pm_runtime_get_sync`，而这些关键调用点忽略了返回值**；温启竞态下底层 `runtime_resume`（含 DSI PLL 锁定 / mdss 时钟使能）瞬时返回错误被吞 → 上层继续往未上电的硬件写 → 无 vblank → `-110`。冷启无此竞态故稳。**这是有代码证据的假设，最终定性需下次上机的一锤定音实验（见 §5）。**

## 1. 首个 modeset 的上电函数链（父复验，file:line 以 d02658e63 为准）
atomic commit 使能阶段：
- `dpu_kms_enable_commit()` — `dpu_kms.c:444-448`，经 `.enable_commit`(`dpu_kms.c:1079`) 每次 commit 调用；体内 `:447 pm_runtime_get_sync(&dpu_kms->pdev->dev);` **返回值丢弃**（函数返回 void，无错误路径）。
- `dpu_crtc_enable()` — `dpu_crtc.c:1269`（`.atomic_enable` :1861），`:1279 pm_runtime_get_sync(crtc->dev->dev);` **返回值丢弃**。
- DSI 侧 `msm_dsi_host_power_on()` — `dsi_host.c:2989`：`regulator_bulk_enable()` 的 ret **有检查**（`:~3016` goto unlock），但紧随的 `:3022 pm_runtime_get_sync(&msm_host->pdev->dev);` **返回值丢弃**；随后 `dsi_link_clk_set_rate_6g_v2_9()`（PLL/byteclk）。
- runtime_resume 落点：`msm_dsi_runtime_resume()` `dsi_host.c:388`（bonded supplier 经 runtime-PM 边带动，非 worker 误报的 :308）。MDSS 层 `msm_mdss_enable()` `msm_mdss.c:231` **正确传播 ret**（`:258/:278 return ret`），`.runtime_resume`→`msm_mdss_enable` (`:444`) 这一层是 OK 的。

⇒ 薄弱点集中在 **dpu_kms / dpu_crtc / dsi_host_power_on 三处 `pm_runtime_get_sync` 忽略返回**；底层一旦瞬时失败即被静默吞掉。

## 2. 为什么能解释"整套 genpd+时钟都 off + vblank -110"
runtime-PM 的 `runtime_resume` 是真正把 `mdss_gdsc/gfx` genpd 上电 + `disp_cc_mdss_*` 使能的地方（`genpd_runtime_resume`→`genpd_power_on`；clk 经 `clk_prepare_enable`）。若该 resume 因温启遗留态（PLL 未锁 / orphan parent / prepare 计数与硬件不一致）瞬时失败并向上返回负值：
- 因上层忽略返回 → 不中止、继续配置未上电硬件 → 无 vblank → `wait_for_commit_done -110`；
- 失败后 usage_count 回落到 0 → genpd 被 suspend → 事后取证即 `mdss_gdsc off-0` + 时钟 enable=0 + `dsi1_isr=0`（Q28b 现场）。
**能解释**：坏发整套 off 且无显式错误打印（因为错误被吞）。冷启 resume 一次成功 → 不发。

## 3. 竞态来源逐一判定
- (a) **底层 runtime_resume 瞬时失败被上层吞**：能解释全部坏发现象（见 §2）。**主嫌**。触发源最可能是温启下 DSI PLL 锁定 / disp_cc_mdss_* 首使能失败（与 0.86s 早期 `PLL lock fail`/`orphan reparent -110` 同源，只是好发在 8.5s 真·modeset 时已恢复、坏发没恢复）。
- (b) **device-link 0x180 创建失败**：坏发是否加剧存疑，但**好发里同样出现且能出画面** ⇒ 单独不足以致坏；不作为主因，作为可能的时序放大器。
- (c) **ABL 遗留 clk_prepare 计数与硬件不一致**：温启可解释，但坏发 `dsi1vco prepare=0`（非 >0）削弱了"跳过 prepare"的具体形态；保留为"底层 resume 内部失败"的子机制之一，不单独定案。

## 4. 最小鲁棒化补丁草案（上游规范，未编译）
方向 = 让上电失败**可见且可中止**，不再往未上电硬件写；并优先对齐上游既有正确写法（同文件已有 `pm_runtime_resume_and_get` 会检查返回，见 `dsi_host.c:2399/:2655`）。
1) `dpu_kms_enable_commit()`（dpu_kms.c:444）：`ret = pm_runtime_resume_and_get(&dpu_kms->pdev->dev); if (ret) { DRM_ERROR("power up failed %d\n", ret); dpu_kms->commit_error = ret; }` —— 因 `.enable_commit` 是 void，落库到 kms 让后续 `wait_for_crtc_commit_done` 能即时失败（避免 400ms×n 空等）。风险低（只加日志/错误位，成功路径无变更）。
2) `dpu_crtc_enable()`（dpu_crtc.c:1269，void）：把 `pm_runtime_get_sync`→`pm_runtime_resume_and_get` 并 `if (ret) { DRM_ERROR(...); return; }`，失败即不使能（避免半使能态）。风险：需确保 return 前状态回滚，属上游会挑刺点，需配套 disable 对称。
3) `msm_dsi_host_power_on()`（dsi_host.c:3022）：已有 `ret`/`goto unlock_ret` 模式，直接 `ret = pm_runtime_resume_and_get(&msm_host->pdev->dev); if (ret) goto unlock_ret;`（与上面 regulator 失败同处理），并补齐 regulator 回滚。风险最低、最像上游会接受的改法。
4) 治本（若 §5 证实 resume 内部 PLL/clk 瞬时失败）：在 `msm_dsi_runtime_resume`/`dsi_link_clk_set_rate_*` 对 PLL 锁定加一次有界重试（温启遗留态二次尝试即锁），比只加日志更能**消除**坏发。checkpatch 友好（无尾随空白、行宽<100）。

## 5. 下次上机的一锤定音（只读优先，区分 三种态）
最优单点 = genpd 的 power_on 事件计数 + 让 resume 自报返回：
1. **genpd 是否从未 power_on vs 上后又 suspend**：读 `/sys/kernel/debug/pm_genpd/<mdss_gdsc>/` 的 `on_time`/`transitions`（或 `pm_genpd_summary` 计数）。上机坏发早期(首个 modeset 前)采一次、失败后采一次：
   - transitions 从未增加 ⇒ **从未 power_on**（resume 根本没被调/在更早处失败）；
   - 增加过又回到 off ⇒ **power_on 后又 suspend**（§2 情形，指向上层吞返回）。
2. **让被吞的返回现形**（需 vk74 诊断点，把打印从 cmd-DMA wait 移到 power-on 路径）：在 `dpu_kms_enable_commit` 捕获并 `DRM_ERROR` `pm_runtime_resume_and_get` 返回、在 `msm_mdss_enable`/`msm_dsi_runtime_resume` 入口/出口打印 ret。坏发若打出负 ret ⇒ 坐实 §3(a)。
3. **区分 supplier 没 resume**：坏发采 `cat /sys/bus/platform/devices/ae96000.dsi/power/runtime_status` 与 `usage_count`、`/sys/kernel/debug/devices_consuppliers`（本树无则 `power/device_link`）。若 ae94000 active 而 ae96000 suspended ⇒ (b) 放大器成立。
判定顺序：先看 1（0 成本、决定性 split），再决定是否需要 2/3。

## 6. 与既有诊断资产的关系
- regdump（vk73-q28diag）只在 **signature A（cmd-DMA -110）** 触发；本次根因若在 power-on 路径，**新诊断点应加在 `dpu_kms_enable_commit`/`msm_mdss_enable`/`msm_dsi_runtime_resume`**，一次好/坏温启即可用 §5 抓到被吞的 ret。
- 建议 vk74 = §4-3(低风险) + §5-2(诊断打印)，先证明"坏发确有被吞负 ret + transitions split"，再上 §4-4 治本重试，逐项最小化。
