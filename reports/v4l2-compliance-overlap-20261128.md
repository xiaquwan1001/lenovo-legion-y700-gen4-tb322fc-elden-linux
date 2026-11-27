# v4l2-compliance 3 贴（已发系列 1224591）Fixes/Cc-stable/残项核定（2026-11-28，限时简报）

- **性质**：只读核定，主机侧；树 `~/elden-cache/build/daily`（HEAD `4da9a8b6`）**只读未改**。
- **前提更正**：该系列**已发出**（2026-11-27T15:20Z，series **1224591**「media: iris: fix v4l2-compliance format and cap issues」，patch id 15030665/66/67，lore 4 封归档）。Bryan O'Donoghue 2026-11-27T16:04Z 在 1/3 回帖：`Please add an appropriate Fixes: and Cc: stable@vger.kernel.org`（MID `<6505dda0-f534-4705-bcea-ecf5f6b9ec30@kernel.org>`）。2/3、3/3 暂无回帖。
- **方法**：本地树 `git show HEAD:<file>` 看基线；提交归属走 GitHub API（`GEEKiDoS/linux`，`/commits?path=` + `/commits/<sha>` 的 diff / raw 内容），因**本地 `git log -S` 在截断历史上会给出假归属**（实测报错 `cannot simplify commit 79a9076…`，且会把 iris 的行挂到 merge 上）——凡本地不可判者本文直接写「本地不可判」。

## 1. 三贴的 Fixes 候选

| 贴 | 我方改动 | Fixes 候选 | 判据（一句话） | 状态 |
|---|---|---|---|---|
| 1/3 | `iris_vidc.c` `"plat:%s:%s"` → `"platform:%s:%s"` | **`94ef75095d5e`** "media: iris: Enumerate cap->bus_info to differentiate between encoder and decoder"（Bryan O'Donoghue，2026-06-02） | 该提交 diff 逐字新增 `snprintf(cap->bus_info, …, "plat:%s:%s", dev_name(core->dev), info);`，此前 `iris_querycap()` 根本不填 bus_info。 | **确定**；另有第三方同族贴 `14755835`（Vishnu Reddy，2026-08-18）用**同一个** Fixes 标签且已 `Reviewed-by: Vikash Garodia`，仍 `new` ⇒ **1/3 与列表在途工作重复** |
| 2/3 | `iris_vdec.c` colorspace/xfer_func/ycbcr_enc/quantization：CAPTURE 默认 + OUTPUT `*_DEFAULT` → BT.709/LIM_RANGE，并在 S_FMT 里补归一 | **`b530b95de22c`** "media: iris: implement s_fmt, g_fmt and try_fmt ioctls"（2025-02-07） | 该提交建立 `iris_vdec_s_fmt()` 并引入 `fmt->fmt.pix_mp.colorspace = f->fmt.pix_mp.colorspace;`（及 `output_fmt` 四行同拷贝），把客户端送来的 `V4L2_COLORSPACE_DEFAULT`（=0）原样存下、G_FMT/TRY_FMT 原样回吐，从此永不归一。 | **确定（与父代理一致）**。**注意**：`iris_vdec_inst_init()` 里显式写 `V4L2_COLORSPACE_DEFAULT` 等 4 行在 2025-02-07 的 v1 系列快照里已存在（`38fc8beaba55` 版文件已含 1 处），早于我按路径能列到的历史 ⇒ 那 4 行的**精确引入提交本地不可判**；贴里应在 cover 注明「DEFAULT 初始化更早，本贴统一在 S_FMT/默认值处归一」 |
| 3/3 | `iris_vdec.c` 给 `inst->crop` clamp 段加「未 seed 时回退 CAPTURE 尺寸」 | **无合法 Fixes（不给）** | 基线 HEAD 的 `S_FMT(CAPTURE)` 分支是**无条件 seed**：`inst->crop.{left,top}=0; .width/.height=f…`（HEAD 行 299–304），0x0 crop **打不出来**；只有套上 1222157 的 **07/11**「keep the visible rectangle on S_FMT(CAPTURE)」把 seed 换成 `min()` clamp 后才出现 ⇒ 引入点是**未合入的上游系列**，不是任何已合主线提交。 | **不给 Fixes / 不给 Cc: stable**；应写「depends on the 'decoder source change, seek and START sequences' series (patchwork 1222157)」，或直接并入那系列的回帖 |

- 分歧记录：父代理报 1/3 重复主线 `1facae9bc3c1`；我独立核到的是**引入点** `94ef75095d5e` + 列表重复贴 `14755835`——两条不矛盾（`1facae9bc3c1` 我**未独立核**，标「采信父代理」。`94ef75095d5e` 是否已进 mainline 我未做 `compare` 校验，建议 v2 前用 `git describe --contains` 或 GitHub `compare/<sha>...master` 复核）。父代理称 3/3 已被 v7.4-rc3 的「s_fmt 无条件 crop seed」取代：**我未独立核**（未查 v7.4-rc3），但与我核到的「引入点是未合入系列」不冲突。

## 2. Cc: stable 逐个判据（只给判据，不发信）

| 贴 | 是否 Cc stable | 判据 |
|---|---|---|
| 1/3 bus_info | **可以加** | 纯 ABI 字符串修正（`plat:`→`platform:`），影响任何用 bus_info 识别设备的应用与 v4l2-compliance；改动 1 行、无行为副作用；且同族在途贴 `14755835` 已带 `Cc: stable`，口径对齐。风险：若维护者取在途贴而非本贴，本贴会被 superseded。 |
| 2/3 colorspace | **可以加（有条件）** | 缺陷是「G/S/TRY_FMT 往返 `colorspace==0`」，影响任何遍历/比对格式的用户态（不填 colorspace 的 m2m 客户端会拿到 0，且 S_FMT(G_FMT) 不幂等）。但修复含**主观默认值选择**（BT.709/LIM_RANGE），语义上是「合理默认」而非「还原正确色彩」⇒ Cc: stable 只在维护者接受该默认值后成立；否则应先当 RFC。 |
| 3/3 crop seed | **不加** | bug 只在未合入的 1222157 之上出现，主线用户不受影响，stable 规则（`Documentation/process/stable-kernel-rules.rst`：必须是主线已存在的 bug）不满足。 |

## 3. 残项 `V4L2_CID_MIN_BUFFERS_FOR_CAPTURE`（compliance `controls.cpp(1180)`）—— 核到哪一步

- **代码事实（已核，本地树）**：`drivers/media/platform/qcom/iris/iris_ctrls.c:354-405` 在 **per-instance** `inst->ctrl_handler` 上用 `v4l2_ctrl_new_std(&inst->ctrl_handler, NULL, V4L2_CID_MIN_BUFFERS_FOR_CAPTURE, 1, 32, 1, 4)` 创建（`num_ctrls + 1` 预留位）；`NULL` ctrl ops ⇒ 呈现为 read-only、`v4l2-ctl --list-ctrls` 可见（前一轮已记录 `0x00980927 … flags=read-only, has-min-max`）。
- **未核到**：本机**没有** v4l2-compliance 源码（`/usr` 下无 `v4l2-test-controls.cpp`），无法读 `(1180)` 到底是「排除只读控件」还是「只遍历 `ctrl_handler` 挂接的 std 控件」；`ssh elden` 只读查询本轮无输出（未取得证据）。
- **结论**：①只读控件被排除 / ②ctrl_handler 挂接 —— **两条都没有证据**，维持「不臆造补丁」。要定论所需一步：取 v4l2-utils 源码看 `controls.cpp(1180)` 上下文（是 `node->controls` 集合的来源），或设备上 `v4l2-compliance -d /dev/video17 -v` 的 event 子测试段原文。

## 4. v2 该写什么（一句话建议）

1/3 回 Bryan：给 `Fixes: 94ef75095d5e` + `Cc: stable@vger.kernel.org`，并**主动声明**与在途贴 `14755835`（Vishnu Reddy，已 Reviewed-by Vikash）重复、请维护者择一；2/3 保留，补同款 Fixes + Cc stable 并在 cover 写明 inst_init 的 DEFAULT 更早、本贴只做归一；3/3 **不给 Fixes/stable**，改写成「depends on 1222157-07」或直接并入 Neil 系列回帖；残项 MIN_BUFFERS 不发补丁，只在 cover 里记「已知、待确认」。

## 残留风险

- 我的一次 `git cat-file` 若触发 lazy fetch，可能在共享 `.git` 留下 `objects/pack/tmp_pack_*`（fetch 前该目录**已有** 5 个同类垃圾包）；未改 ref/worktree/工作树内容。
- 未独立复核：`1facae9bc3c1`（父代理给的重复主线提交）、`94ef75095d5e` 是否已进 mainline、v7.4-rc3 取代 3/3。
