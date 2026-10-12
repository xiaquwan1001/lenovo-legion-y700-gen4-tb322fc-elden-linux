# 上游命中审计复核 —— 对 `reports/upstream-hits-20261012.md`（lane/upstream 53fbe5a）的独立核对

- 日期：2026-10-12（本审计工作盒 ≤30 min）
- 审计者：子代理「上游命中审计 lane 收尾」
- 被审对象：项目仓 `lane/upstream` @ `53fbe5a`（未并入 main）新增的 `reports/upstream-hits-20261012.md`（118 行）
- 审计对象（内核）：`/home/xuqianhui1001/y700-wt/wt-upstream-kernel`（分支 `elden/lane-upstream` @ `169d74806`）；主 worktree `/home/xuqianhui1001/y700-elden/geekidos-linux`（`clean/base` @ `5d01d3324`）
- 纪律：**未**执行任何设备操作（无 fastboot/adb/ssh/EDL）；**未** merge/push；**未**改 main 分支；本次仅在 `reports/` **新增本文件**（untracked，未提交）。
- 审计期间 main 被其它会话推进（`a10e853` → `168cee5`），本审计不涉及。

## 0. 身份校验与审计方法（原始输出）

```
$ cd /home/xuqianhui1001/y700-elden && git rev-parse --show-toplevel && git log -1 --format='%H %s'
/home/xuqianhui1001/y700-elden
a10e85313f28b427909e25c0186b9dc5dc79879c q28: SSOT 收束（TASKS §5 Q28 现状 + PITFALLS #226 今日否证清单与判别量）

$ git log --oneline -3 lane/upstream
53fbe5a upstream: 7.2.y/7.3/lore 上游命中与回移审计报告
3727144 q28: vk114(上游 round 修复) 冷起 L1FAIL ⇒ PITFALLS #223（臂非主导变量，会话/复位条件可疑）

$ git show --stat 53fbe5a   # reports/upstream-hits-20261012.md | 118 ++++++++++++++++++++++
$ cd /home/xuqianhui1001/y700-wt/wt-upstream-kernel && git log -1 --format='%H %s'
169d748060a1a4609b40cd1c4a42704575243c0d drm/msm: 回移 7.2.5-7.2.8 DSI/DPU/Adreno 稳定性补丁 + sm8750 参考板 PHY 供电
```

独立数据源（**不采信报告自述**）：

| 源 | 可达性（实测） | 用途 |
|---|---|---|
| `cdn.kernel.org/pub/linux/kernel/v7.x/ChangeLog-7.2.{5,6,8,10}` | HTTP 200（0.87/2.60/0.71/0.70 MB，558/1816/438/426 提交） | 逐条核 $A/$B 的 7.2.y SHA + 主题 + `[ Upstream commit X ]` 主线映射 |
| `api.github.com/repos/torvalds/linux/commits/<sha>` | HTTP 200 | 核 7.3 侧 SHA（ChangeLog 尚无 7.3）＋取上游 patch 正文 |
| `raw.githubusercontent.com/torvalds/linux/v7.3-rc7/...` | 200/404 逐路径实测 | 核 §E「已在 v7.3-rc7」类声明（含行数/字节比对） |
| `gitlab.freedesktop.org/drm/misc/kernel/-/commit/f11277810402` | HTTP 200 | 核 §C nt36536 Kconfig 补丁 |
| `lore.kernel.org` | **HTTP 403（本机不可达）** | §C/§F 的 lore 类声明**无法独立复核**（见 §3 局限） |
| 本地内核仓 | 仅 95 commits（`git rev-list --all --count`），**无任何上游历史** | $A 的「已在树」只能靠**内容**核对，不能靠 ancestry |
| `reference/upstream-pengyuluo/patches/` | 本地原始 patch 原件 | 交叉核对主线 SHA/主题 |

关键前提（必须写明）：**14 条被引用的上游 SHA 全部 `ABSENT` 于本仓**（`git log --all --oneline | grep <sha>` 0 命中，`git merge-base --is-ancestor` 非祖先）。这不是报告错误——本仓是 95 提交的厂商树+本地补丁，不含上游历史；报告确实是把它们当**出处**（provenance）引用的。因此本审计对每条给出三重判定：**① 上游 SHA 是否真实存在且主题相符 ② 回移内容是否在 lane 树 ③ 是否在 main 树**。

## 1. §A「已回移并提交」14 条 —— 逐条独立核对

回移提交本体（lane 树，真实存在）：

```
$ git show --stat 98fda55ca   # 3 files, 13 insertions(+), 7 deletions(-)
$ git show --stat a00945de6   # main.c 6 +, qcom_scm_trace.h 143 +   → 149 insertions(+)
$ git show --stat 169d74806   # 11 files, 35 insertions(+), 14 deletions(-)
$ git merge-base --is-ancestor 169d74806 HEAD && echo ANCESTOR-OF-HEAD     # 三条均 ANCESTOR-OF-HEAD（lane）
$ git -C geekidos-linux merge-base --is-ancestor 169d74806 HEAD            # 非祖先 ⇒ 不含 main 树
$ git cat-file -e clean/base:drivers/firmware/qcom/qcom_scm_trace.h        # NO（main 树无）
$ git show clean/base:.../msm_ringbuffer.h | grep -c sched_initialized     # 0
```

| # | 报告声明（出处 SHA · 主题 · 声称状态） | 独立核对结果（方法 → 证据） | 判定 |
|---|---|---|---|
| A1 | 7.2.6 `78ac8fc2` q6apm keep the graph start count in sync（`q6apm.c`）· 已回移 | ChangeLog-7.2.6 命中，主题**逐字相同**；`[ Upstream commit daa7ffd765ae... ]` **实证**报告「=7.3 `daa7ffd76`」；上游 patch 与本树 hunk +/- 行集合 **MATCH(18/18)** | 上游存在✓ 主题✓ 已在 lane 树✓（main 树无） |
| A2 | 7.3 `9c9fb79f` Zero-initialize AudioReach module config（`q6apm-dai.c`） | 7.2.{5,6,8,10} 均无（**与报告称「7.3」一致**）；GitHub API：`9c9fb79f9769 / ASoC: qcom: qdsp6: Zero-initialize...`，files=`q6apm-dai.c`；hunk **MATCH(4/4)** | 上游存在✓ 主题✓ 已在 lane 树✓ |
| A3 | 7.2.10 `f11336e6` lpass-cpu DAI table index（`lpass-cpu.c`） | ChangeLog-7.2.10 命中，主题逐字相同；该提交本身即主线提交（API 直查同名 SHA 亦命中）；hunk **MATCH(5/5)** | 上游存在✓ 主题✓ 已在 lane 树✓ |
| A4 | 7.2.6 `84e713a8` mhi flush posted write（`host/main.c`） | ChangeLog-7.2.6 命中；上游映射 `24f4423cbc89...`；hunk **MATCH(8/8)** | 上游存在✓ 主题✓ 已在 lane 树✓ |
| A5 | 7.2.6 `0e93bb22` qcom scm trace events（`qcom_scm_trace.h` 新增 143 行）· 已回移 | ChangeLog-7.2.6 命中；上游映射 `f6bb2daa4584...`，API 文件清单=**仅 `qcom_scm_trace.h`(+143)**；本树该文件 **143 行、diff MATCH(143/143)** | 上游存在✓ 主题✓ 已在 lane 树✓ — **但为死代码**（见 E2） |
| A6 | 7.2.5 `d152b582` round 6G byte clock rate to PLL-achievable（`dsi_host.c`） | ChangeLog-7.2.5 命中，主题**逐字相同**；hunk **MATCH(14/14)**（`dsi_calc_clk_rate_6g` 内 `clk_round_rate`，本树第 711–728 行）；主线对应件另有原件 `6cd33b6f4155`（报告未给，非错） | 上游存在✓ 主题✓ 已在 lane 树✓ |
| A7 | 7.2.6 `e532b800` dp Drop dev_pm_opp_set_rate(0)（`dp_ctrl.c`） | ChangeLog-7.2.6 命中；上游映射 `cebfa9909e27...`；上游 patch 3 处删除（reinitialize/deinitialize/off_link）+1 空白，**本树同 3 处删除**（off 函数名不同）；差异仅上下文行号/函数名，**集合比对对称差为空** | 上游存在✓ 主题✓ 已在 lane 树✓（残留 1 处 `dp_ctrl.c:2574 msm_dp_ctrl_off_link_stream`，该补丁本就只删 3 处） |
| A8 | 7.2.6 `54b17a85` dpu Drop sneaky opp(0)（`dpu_core_perf.c`） | 命中；映射 `811c38907eab...`；hunk **MATCH(6/6)** | 上游存在✓ 主题✓ 已在 lane 树✓ |
| A9 | 7.2.6 `09b360eb` Only fini scheduler after successful init（`msm_ringbuffer.c/.h`） | 命中；映射 `e2332abed2a4...`；hunk **MATCH(12/12)**（本树新增 `bool sched_initialized`） | 上游存在✓ 主题✓ 已在 lane 树✓ |
| A10 | 7.2.6 `dc64cf9d` Recover HW before retire hung submit（`msm_gpu.c`） | 命中；映射 `b303e1d52811...`；hunk **MATCH(6/6)**（`gpu->funcs->recover()` 移到 `retire_submits()` 之前） | 上游存在✓ 主题✓ 已在 lane 树✓ |
| A11 | 7.2.8 `fd25668f` dpu clear pending peripheral flush state（`dpu_hw_ctl.c`） | ChangeLog-7.2.8 命中；hunk **MATCH(1/1)**（`pending_periph_flush_mask = 0`） | 上游存在✓ 主题✓ 已在 lane 树✓ |
| A12 | 7.2.8 `ebc273b4` adreno autosuspend cleanup（`adreno_gpu.c`） | 命中；hunk **MATCH(4/4)**（`pm_runtime_dont_use_autosuspend()`） | 上游存在✓ 主题✓ 已在 lane 树✓ |
| A13 | 7.2.6 `51fcee9d` a6xx stale rpmh votes（`a6xx_gmu.c`） | 命中；映射 `d9108bfdb746...`；上游 commit log 原文含 “**also move GMU to reset state**” ⇒ 本树 `CM3_SYSRESET` hunk 属该补丁本身、非账外改动；hunk **MATCH(9/9)** | 上游存在✓ 主题✓ 已在 lane 树✓ |
| A14 | 7.2.6 `407b05cf` sm8750 swapped USB QMP PHY supplies（`sm8750-{mtp,qrd}.dts`） | 命中（主题含 `vdda-phy/vdda-pll supplies`）；映射 `50c9658bc622...`；hunk **MATCH(6/6)**；本树仅动 mtp/qrd、**未动 elden** ✓ 与报告「仅参考板」一致 | 上游存在✓ 主题✓ 已在 lane 树✓ |

**§A 汇总：14/14 上游 SHA 真实、主题逐字相符、回移内容在 lane 树逐行一致；3 个回移 commit 均非 `clean/base` 祖先（确实只在 lane）；`+197 行` =`13+149+35` ✓、`14 补丁` =`3+2+9` ✓。**

## 2. §B / §E 核对

| 条目 | 报告声明 | 独立核对 | 判定 |
|---|---|---|---|
| B1 `c59e4a90` | 7.2.8 round byte clk **after reparenting**（主线 `202828068`）· 冲突待 rebase | ChangeLog-7.2.8 命中、主题逐字；`[ Upstream commit 2028280686f4fa78... ]` ⇒ **报告的主线号正确**；原件 `reference/upstream-pengyuluo/patches/2028280686f4.patch` 主题一致；本树 `patches/q28-methodB-round-byteclk.patch` 存在（2189 B, 10-12 09:16） | 声明✓；“冲突”本身未复跑（需 rebase 试验，超本工作盒） |
| B2–B4 `00008e6f`/`713abac5`/`8fc6a356` | 7.2.6/7.2.8 三条冲突 | 三者 SHA 均命中、主题逐字（dsi Drop opp / msm RCU-free ring / a6xx IRQ storm during msm_recovery test）；映射 `06b7ba20...`/`bc024d325e...`；`8fc6a356` 内容为「recovery 期间 mask GPU error IRQ」⇒ 与 A10 同文件冲突的说法自洽 | 声明✓；冲突细节未复跑 |
| B5 `c374d710` | 7.2.10 lpass-wsa「未取到正文（cgit 503）」 | ChangeLog-7.2.10 命中、主题逐字 | 声明✓ |
| E-1 | `75a5dbd1f4f7` 已进主线；`panel-novatek-nt36536.c` 上游 486 行、本树 558 行（衍生版） | GitHub API：`75a5dbd1f4f7 / drm/panel: Add Novatek NT36536 panel driver`，files=Kconfig/Makefile/.c；`raw v7.3-rc7` 该 .c **HTTP 200 = 486 行**；本树 **558 行**（diff 132 行）⇒ 486/558 两个数字**都准确** | 声明✓ |
| E-2 | `novatek,nt36536.yaml` 亦在 v7.3-rc7 | `raw v7.3-rc7` **HTTP 200 = 1909 B**，与本树同名文件 **IDENTICAL**（`diff -q` 无差异） | 声明✓（且本树绑定=上游原件） |
| E-3 | `2c4ddee5c903`（intel-lab-lkp）DTS+Makefile、v7.3-rc7 无 elden | GitHub API（intel-lab-lkp/linux）：主题 `arm64: dts: qcom: sm8750: Add Lenovo Legion Y700 Gen4`，files=Makefile + `sm8750-lenovo-elden.dts`；`raw v7.3-rc7` 与 `master` 该 DTS 均 **HTTP 404** | 声明✓（并补充：审计时 master 亦无） |
| E-4 | LKP 报 `backlight@76 (awinic,aw99706): 'enable-gpios'` 失败 ⇒「我们的本地 DTS 若同源需同步修」 | 本树 binding 要求 `enable-gpios`（`required:` 含之，examples 亦然）；**本树 DTS 已用 `enable-gpios`**（`sm8750-lenovo-elden.dts:2203`）⇒ 合规；**用错拼写的是上游 Pengyu 版**（`reference/upstream-pengyuluo/sm8750-lenovo-elden.dts:787` = `enable-gpio`） | **报告写错（方向反了）** → 见 E1 |
| E-5 | `registry vk115 已占位` | `versions/vk-registry.tsv:207` = `vk115\tupstream\t2026-10-12\t上游回移审计批次（7.2.y/7.3 候选补丁）` | 声明✓ |

## 3. 汇总：准确率、错误清单、更正建议

### 3.1 准确率

- **可独立核对的硬声明（§A 14 + §B 5 + §E 5 = 24 项）**：
  - SHA 存在性 + 主题逐字相符：**24/24**（§E-4 属解释错误，其 SHA/主题不含在内）
  - 回移内容「已在 lane 树且与上游逐行一致」：**14/14**
  - 数字类声明（`+197 行`、`14 补丁`、`486/558 行`、`143 行`、`v7.3-rc7 收录`、`registry vk115 占位`）：**6/6 全部复算通过**
  - **解释/行动项错误：1 项（E-4 aw99706 方向）**
  - **遗漏标注：1 项（A5 trace 死代码）**
- **§C/§F 的 lore 类声明（约 18 主题、ath12k 撤回、DPU slave-encoder 在途、U-Boot/其它）**：本机 `lore.kernel.org` **HTTP 403**，**全部未独立复核**，不计入分母。其中 2 条有替代源且已核：
  - nt36536 Kconfig 补丁 `f11277810402` → gitlab.freedesktop.org 页面标题 `drm/panel: fix novatek-nt36536 dependencies (f1127781)` ✓
  - `2c4ddee5c903` → 见 E-3 ✓
- 结论口径：报告**没有编造 SHA/主题**（0 项），错在 1 处归因方向 + 1 处完整性标注缺失 + 一批不可本机复核的 lore 断言未加「未复核」标记。

### 3.2 错误清单与更正建议

| 编号 | 问题 | 证据 | 更正建议 |
|---|---|---|---|
| **E1（必须改）** | §E LKP 条目结论「我们的本地 DTS 若同源需同步修」**方向相反** | 本树 binding 必填 `enable-gpios`；本树 DTS `:2203` 已是 `enable-gpios`（合规）；上游 Pengyu DTS `:787` 为 `enable-gpio`（才会被 LKP 判失败） | 改为：「本树 DTS 已合规、**无需改动**；待修的是上游 Pengyu v2 DTS（`enable-gpio` → `enable-gpios`），可作为向其反馈/或上游化补差的素材」。**并入 main 前务必改掉，否则会诱出无谓改动** |
| **E2（应标注）** | §A 把 `firmware: qcom: scm: add trace events` 列为已完成回移，未说明其在**本树不生效** | `grep -rn qcom_scm_trace drivers/firmware/qcom/` 仅命中头文件自身；全树无 `CREATE_TRACE_POINTS`、无 `#include "qcom_scm_trace.h"`；上游同一提交（`f6bb2daa`）也只加头文件（143 行） | 加一句：「该回移当前为**未注册的 tracepoint 头文件**（含上游亦然），需消费端补丁才可用；不要据此声称已获得 SCM trace 能力」 |
| **E3（可追溯性）** | §A 只给 9 位短 SHA、未给 lane HEAD；`/tmp/vk115-build.log` 中**无任何 vk115/UTS 身份标记** | `grep -aoE "vk115|LOCALVERSION=|Kernel: ... is ready" /tmp/vk115-build.log` → **0 命中**（日志可证 0 error/0 warning 且产出 `DTC .../sm8750-lenovo-elden.dtb` + `GZIP arch/arm64/boot/Image.gz`，但无法与 vk115 源码身份绑定） | 补全 `98fda55ca/a00945de6/169d74806` 全长 SHA + lane HEAD；若要主张「编译验证」，构建须带 `LOCALVERSION=-vk115-upstream`（并在日志里记录 UTS/banner），否则只能写「存在一份构建日志，身份未证据化」 |
| **E4（标注）** | §C/§F lore 断言未标注可核性 | `curl lore.kernel.org` → **HTTP 403**（本机） | 给 §C/§F 加「来源：lore 检索快照（本机 403，未二次复核）」标记；将来并入 SSOT 时不得当作已核实事实 |
| **E5（极小）** | §B「冲突点」为自述，未附复现 | 本次未跑 rebase 试验（超工作盒） | 保留但注「未复跑」；或按 `git cherry-pick -n` 逐条记录冲突 hunk |

### 3.3 已核实的「值得采信」要点（供 main 直接引用）

- $A 整表可作为**回移台账**直接采信（含 `[ Upstream commit ]` 级映射，A1=A13 等主线号均已核）。
- §E 的「上游已有同题作者线」结论成立且有硬证据：`75a5dbd1f4f7`（driver，v7.3-rc7 200/486 行）、binding 与上游 **逐字节相同**、`2c4ddee5c903`（elden DTS，v7.3-rc7/master 均 404 ⇒ 尚未进主线）。
- 「本树为该驱动上游版的**衍生版**」有量化证据：driver diff **132 行**，本树多 72 行。

## 4. 裁决：该报告可否并入 main

**结论：可以并入 main（作为 lane 资料/台账），但必须先落 E1 更正、并加 E2/E4 标注；不得在未修正前当作 §E 行动依据。**

理由：

1. **硬内容零虚构**：24/24 可核硬声明（SHA、主题、文件、行数、数量算术）独立复核全部正确；14/14 回移内容与上游 patch 逐行一致；3 个回移 commit 真实存在于 `elden/lane-upstream` 且**确未进入 main**（`clean/base`）。
2. **风险等级**：纯 `reports/` 新增文档，不改代码、不触碰设备与 SSOT（`INDEX.md/TASKS.md/DEVICE.md` 未引用它），并入 main 无功能风险；且它是 `lane/upstream` 唯一产出的可追溯记录，**不并入则丢证据**。
3. **但存在 1 处会误导行动的归因错误（E1）与 1 处能力夸大（E2）**：若把 §E 结论当成「本树 DTS 待修」的依据，会产生无谓改动甚至误改合规属性；若把 A5 当成「已有 SCM trace 能力」，会误判调试手段可用性。
4. 操作建议（供主线会话执行，均可审）：`git cherry-pick 53fbe5a`（或直接落文件）→ 按 E1 改一行、按 E2/E4 各加一句标注 → 在 `reports/` 保留原文 118 行为准，不重写。
5. **不建议**据该报告直接开启 §E 的「① 拆 elden 增量为对 `75a5dbd1f4f7` 的补丁 ② 以 `2c4ddee5c903` 为基线补 DTS 差量」两条路线：方向正确，但均属跨 lane 的大工程，且 §E 已含一处错误结论，须与 Q28/Q24 lane 对齐后再立立项。

## 附：原始命令输出摘录（关键行）

```
# 1) 上游 SHA 在 7.2.y ChangeLog 的命中（cdn.kernel.org，逐条 grep）
78ac8fc2 in cl-7.2.6.txt   upstream-ref=daa7ffd765ae67a83e77dae32c66ce2d6d995d19  [Upstream 行]
f11336e6 in cl-7.2.10.txt  SUBJ: ASoC: qcom: lpass-cpu: use DAI table index for playback constraints
84e713a8 in cl-7.2.6.txt   upstream-ref=24f4423cbc89548def2b05ae86de6175086dbf94
0e93bb22 in cl-7.2.6.txt   upstream-ref=f6bb2daa4584229af155c2488b83151999315293
d152b582 in cl-7.2.5.txt   SUBJ: drm/msm/dsi: round 6G byte clock rate to the PLL-achievable value
e532b800 in cl-7.2.6.txt   upstream-ref=cebfa9909e27ec7b7cbaec25ee5516cf886baa39
54b17a85 in cl-7.2.6.txt   upstream-ref=811c38907eab0f66c22c5e5708e6f8eab14d76fa
09b360eb in cl-7.2.6.txt   upstream-ref=e2332abed2a4d3caa59052095dc16e4ce44791ea
dc64cf9d in cl-7.2.6.txt   upstream-ref=b303e1d52811de7d1bcf793560754d4df68d4a1c
fd25668f in cl-7.2.8.txt   SUBJ: drm/msm/dpu: clear pending peripheral flush state
ebc273b4 in cl-7.2.8.txt   SUBJ: drm/msm/adreno: fix autosuspend cleanup during teardown
51fcee9d in cl-7.2.6.txt   upstream-ref=d9108bfdb746edacdb05bd27959a4ae63c6c7f3f
407b05cf in cl-7.2.6.txt   upstream-ref=50c9658bc622888f9664a052fd98ef6026883ea5
c59e4a90 in cl-7.2.8.txt   upstream-ref=2028280686f4fa78e2f1f6dede4b6c1fd782b9e3
00008e6f in cl-7.2.6.txt   upstream-ref=06b7ba206561619bb34116f49e0ef26b867ce3aa
713abac5 in cl-7.2.8.txt   SUBJ: drm/msm: RCU-free the scheduler-containing ring and VM objects
8fc6a356 in cl-7.2.6.txt   upstream-ref=bc024d325e98b6b2806e00455e030622fb8e1820
c374d710 in cl-7.2.10.txt  SUBJ: ASoC: codecs: lpass-wsa-macro: rewrite the interpolator volume after enabling clocks

# 2) 逐补丁内容比对（上游 patch 正文 vs 本树回移 hunk，+/- 行集合）
A1 MATCH 18/18   A2 MATCH 4/4   A3 MATCH 5/5   A4 MATCH 8/8   A5 MATCH 143/143
A6 MATCH 14/14   A7 对称差为空（3 删除同处，仅函数名/行号不同）      A8 MATCH 6/6
A9 MATCH 12/12   A10 MATCH 6/6  A11 MATCH 1/1  A12 MATCH 4/4  A13 MATCH 9/9  A14 MATCH 6/6

# 3) 本仓无上游历史（故 SHA 本体不可能"在树"）
$ git rev-list --all --count → 95 ; 所有 20 个上游 SHA → ABSENT / not-ancestor-of-HEAD

# 4) main 树确实不含回移内容
$ git -C geekidos-linux merge-base --is-ancestor 169d74806 HEAD      → 非祖先
$ git cat-file -e clean/base:drivers/firmware/qcom/qcom_scm_trace.h  → 不存在
$ git show clean/base:.../msm_ringbuffer.h | grep -c sched_initialized → 0
$ git show clean/base:.../dsi_host.c | sed -n '705,730p' | grep clk_round_rate → 无

# 5) 7.3 / 主线侧（GitHub API、raw v7.3-rc7）
9c9fb79f9769 | ASoC: qcom: qdsp6: Zero-initialize AudioReach module config        files:[q6apm-dai.c]
75a5dbd1f4f7 | drm/panel: Add Novatek NT36536 panel driver                       files:[Kconfig, Makefile, .c]
v7.3-rc7 panel-novatek-nt36536.c → HTTP 200, 486 行（本树 558 行，diff 132 行）
v7.3-rc7 novatek,nt36536.yaml   → HTTP 200, 1909 B（与本树 diff -q = IDENTICAL）
v7.3-rc7 / master sm8750-lenovo-elden.dts → HTTP 404 / 404
2c4ddee5c903 | arm64: dts: qcom: sm8750: Add Lenovo Legion Y700 Gen4（intel-lab-lkp/linux，files=Makefile+elden.dts）

# 6) E1 方向证据
本树 binding: required 含 enable-gpios，example 用 enable-gpios
本树 DTS   sm8750-lenovo-elden.dts:2203   enable-gpios = <&tlmm 88 GPIO_ACTIVE_HIGH>;   ← 合规
上游 DTS   reference/upstream-pengyuluo/sm8750-lenovo-elden.dts:787  enable-gpio = <&tlmm 88 ...>;  ← 错拼

# 7) E2 死代码证据
$ grep -rn "qcom_scm_trace" drivers/firmware/qcom/ → 仅头文件自身（:140 TRACE_INCLUDE_FILE）
$ grep -rn "CREATE_TRACE_POINTS" drivers/firmware/qcom/*.c → 0 命中

# 8) E3 构建日志身份
$ grep -aoE "vk115[a-z-]*|LOCALVERSION=[^ ]*|Kernel: .*is ready" /tmp/vk115-build.log → 0 命中
$ grep -cE "^(ERROR|error:|.*Error [0-9])" /tmp/vk115-build.log → 0 ; warnings → 0
日志尾部：DTC arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb ; GZIP arch/arm64/boot/Image.gz

# 9) 环境局限
$ curl lore.kernel.org/all/?q=sm8750+elden → HTTP 403（§C/§F 无法本机复核）
```
