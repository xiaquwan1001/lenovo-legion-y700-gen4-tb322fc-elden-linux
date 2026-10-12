# Q28 Method B — 上游静态校准报告（纯静态，未编译/未上机）

- 日期：2026-10-12
- 范围：只读分析 + 修订 `patches/q28-methodB-round-byteclk.patch`，未改内核树、未提交、未编译、未上机。
- 素材：`reference/upstream-pengyuluo/patches/{2028280686f4,6cd33b6f4155,e4eb11b34d6c,75a5dbd1f4f7}.patch`、`build/m1-upstream/linux-7.2.tar.xz`、本树 `geekidos-linux/**`。

## 0. 结论摘要（数字先行）

| # | 结论 | 关键证据 |
|---|---|---|
| 1 | 现有草稿把 `clk_round_rate()` 放在 **reparent 之前**（SM8750 分支内），正是上游 `2028280686f4` 要修的时机错误 ⇒ **必须改** | `patches/q28-methodB-round-byteclk.patch`（旧版）锚点 = `dsi_host.c:449` 分支；上游 `2028280686f4.patch` |
| 2 | 本树 `dsi_calc_clk_rate_6g()` **无取整**（= 上游 Fixes 后状态）；`dsi_link_clk_set_rate_6g()` 也 **无取整**（= Method B 缺口） | `dsi_host.c:709-719`、`dsi_host.c:401-432` |
| 3 | 本树 `byte_intf_clk_rate` 仍在，`byte_intf_clk_div_2` bool **不存在**；power_on 在取整前用未取整值算 byte_intf | `dsi_host.c:136`、`dsi_host.c:3008-3010` |
| 4 | SM8750 实际走 v2.9：`dsi_link_clk_set_rate_6g_v2_9()` + `dsi_clk_init_6g_v2_9()`，且本树由 **compatible 强制覆盖**（不靠速率阈值） | `dsi_host.c:449`、`dsi_host.c:363-364`、`dsi_host.c:3023-3029` |
| 5 | 调用点 byte RCG 的 parent **已 reparent 到 PHY PLL**（`dsi_link_clk_set_rate_6g()` 在 `clk_set_parent(byte_src…)` 之后被调用） | `dsi_host.c:459` → `dsi_host.c:471` |
| 6 | 本板是 **C-PHY**，而 C-PHY timing calc **不置** `byte_intf_clk_div_2` ⇒ 本板该值为 **false**（旧 NOTES 的「更正 =true」对本板是错的） | `sm8750-lenovo-elden.dts:2426`、`dsi_phy.c:471-521`（无赋值） vs `dsi_phy.c:355,461`（仅 D-PHY） |
| 7 | 本板 6G v2.9 byte-clk（per host, bonded, C-PHY）= **108.1 MHz**，bitclk = **756.8 MHz**，**均 < 1 GHz**；v2.9 选择靠 DSI 版本寄存器 V2_9_0，不是 >1 GHz 阈值 | 算式 §4；`dsi_cfg.c:348-349`；`dsi_host.c:243` |
| 8 | refgen：sm8750.dtsi 与 elden DTS **无 refgen 节点 / 无 `refgen-supply`**；`CONFIG_REGULATOR_QCOM_REFGEN=m`（模块，未编入本机内核，仅可加载） | §5 |
| 9 | 本树 PHY 已带 **私有** Q28 缓解：`dsi_pll_7nm_vco_set_rate()` 在 DECIMAL/FRAC 已匹配时跳过 `dsi_pll_commit` | `dsi_phy_7nm.c:368-390`（tree-local） |
| 10 | 修订后 patch 通过 `git apply --check` 与 `patch -p1 --dry-run`；checkpatch 仅报「缺 commit 元数据」 | §6 |

---

## 1. Method B 上游权威语义

### 1.1 `2028280686f4` 相对 `6cd33b6f4155` 的逐条差异

上游两 patch 都是 linux-7.2 之后的新提交；vanilla 7.2 仍是 `unsigned long byte_intf_clk_rate`、无取整（已核：`/tmp/q28-analy/linux-7.2/drivers/gpu/drm/msm/dsi/dsi_host.c:132`，无 `clk_round_rate`）。

`6cd33b6f4155`（Kavan，回归前身）只加一段：
- `dsi_calc_clk_rate_6g()` 内：`rounded_byte_clk_rate = clk_round_rate(msm_host->byte_clk, msm_host->byte_clk_rate)`，失败 `return`，否则 `msm_host->byte_clk_rate = rounded`。
- 其余不动；byte_intf 仍在 `msm_dsi_host_power_on()` 里由（此时已取整的）`byte_clk_rate` 推出。

`2028280686f4`（Dmitry，修复；`Fixes: 6cd33b6f4155`）四处改动：

| 序 | 文件/位置 | 6cd33b6f4155（错） | 2028280686f4（对） |
|---|---|---|---|
| 1 | `struct msm_dsi_host` | `unsigned long byte_intf_clk_rate;` | `bool byte_intf_clk_div_2;`（**删掉派生值字段**，改为存「是否 /2」的原始事实） |
| 2 | 取整位置 | `dsi_calc_clk_rate_6g()`（**reparent 之前**） | `dsi_link_clk_set_rate_6g()` 开头（**reparent 之后**） |
| 3 | byte_intf 推导 | `msm_dsi_host_power_on()`：`byte_intf = byte_clk_rate; if(div2) /=2` | `dsi_link_clk_set_rate_6g()`：`byte_intf_clk_rate = msm_host->byte_clk_rate; if (byte_intf_clk_div_2) /=2` —— 用**刚取整后**的 byte rate |
| 4 | power_on | 计算 `byte_intf_clk_rate` | 只存 `msm_host->byte_intf_clk_div_2 = phy_shared_timings->byte_intf_clk_div_2;` |

提交信息三条要点：
- 6G v2.9 主机（SM8650/SM8750/Kaanapali…）在 **PHY 使能之后**由 `dsi_link_clk_set_rate_6g_v2_9()` 运行时 reparent byte/pixel RCG 到 PHY PLL；
- `dsi_calc_clk_rate_6g()` 更早跑（为算 PHY 的 bit clock 请求），当时 byte RCG 还挂在 reset parent（XO）上，`clk_round_rate()` 返回**假值**，该假值进入 PHY bit-clock 请求 ⇒ **PLL 编错频**；
- 移到 reparent 后取整，后续 `link_clk_set_rate()` 在 CCF 里变 no-op；byte_intf 必须用取整后的 byte rate 推导，否则持续请求理想速率、**每次传输都重新触发 PLL**。

### 1.2 为什么「必须在 reparent 之后」

调用链（本树/上游同构）：`enable_phy()` → `msm_dsi_host_get_phy_clk_req()` → `calc_clk_rate()`（= `dsi_calc_clk_rate_6g`）算出 `byte_clk_rate` 并写入 `clk_req->bitclk_rate` → **PHY 使能/PLL 编程** → `msm_dsi_host_power_on()` → `link_clk_set_rate()` → `dsi_link_clk_set_rate_6g_v2_9()`：先 `clk_set_parent(byte_src_clk, dsi_pll_byte_clk)`，**然后**才 `dsi_link_clk_set_rate_6g()`。

- 在 `dsi_calc_clk_rate_6g()` 时刻：`byte_clk` 的祖先 `byte_src_clk` 仍挂 XO，`clk_round_rate(byte_clk, ideal)` 沿 XO 链路求整 → 返回「XO 可实现速率」而非「PLL 可实现速率」= 假值。假值被写回 → 进 `bitclk = byte*7/8` → PLL 编错频。
- 在 `dsi_link_clk_set_rate_6g()` 时刻：`byte_src_clk` 已 = `dsi_pll_byte_clk`（PHY PLL），`clk_round_rate` 沿 PLL 链路求整 → 返回真正可实现值；写回后后续 set_rate 命中 CCF 缓存 = no-op。
- 语义依据：`clk_round_rate()` 声明为 `long`，失败返回负 errno（`include/linux/clk.h:870`；`/tmp/q28-analy/linux-7.2/include/linux/clk.h:870`）。故上游用 `< 0` 判失败。

---

## 2. 本树落点核实（文件:行号 + 原码）

### 2.1 `dsi_calc_clk_rate_6g()` — 无取整（与上游 Fixes 后一致）

`geekidos-linux/drivers/gpu/drm/msm/dsi/dsi_host.c:709-719`
```c
709 int dsi_calc_clk_rate_6g(struct msm_dsi_host *msm_host, bool is_bonded_dsi)
710 {
711	if (!msm_host->mode) { ... return -EINVAL; }
716	dsi_calc_pclk(msm_host, is_bonded_dsi);
717	msm_host->esc_clk_rate = clk_get_rate(msm_host->esc_clk);
718	return 0;
719 }
```
⇒ 本树**没有任何取整**（既不在 6g，也不在 v2）。生产点在 `dsi_calc_pclk()`（`dsi_host.c:699-707`）：`byte_clk_rate = dsi_byte_clk_get_rate(...)`（`dsi_host.c:702`）。

### 2.2 `dsi_link_clk_set_rate_6g()` — 无取整（Method B 缺口）

`dsi_host.c:401-432`：开头直接 `dev_pm_opp_set_rate(dev, byte_clk_rate)`，byte_intf 块用 `msm_host->byte_intf_clk_rate`（`dsi_host.c:423`），**无任何 `clk_round_rate`**。

### 2.3 `dsi_link_clk_set_rate_6g_v2_9()` — reparent 顺序 + SM8750 专有前置 set_rate

`dsi_host.c:434-471`
```
449  if (of_device_is_compatible(dev->of_node, "qcom,sm8750-dsi-ctrl")) {
450  	ret = clk_set_rate(msm_host->dsi_pll_byte_clk, msm_host->byte_clk_rate);  // (1) reparent 之前，用未取整值编程 PLL 时钟
...
459  ret = clk_set_parent(msm_host->byte_src_clk, msm_host->dsi_pll_byte_clk);   // (2) reparent
465  ret = clk_set_parent(msm_host->pixel_src_clk, msm_host->dsi_pll_pixel_clk);
471  return dsi_link_clk_set_rate_6g(msm_host);                                   // (3) 调用点
```
(1) 是**本树私有**（上游 `2028280686f4` 的 v2_9 无此分支；vanilla 7.2 `/tmp/.../dsi_host.c:414-431` 也无）。它早于 reparent。

### 2.4 `msm_dsi_host_power_on()` — byte_intf 仍用未取整值

`dsi_host.c:3008-3010`
```c
3008	msm_host->byte_intf_clk_rate = msm_host->byte_clk_rate;
3009	if (phy_shared_timings->byte_intf_clk_div_2)
3010		msm_host->byte_intf_clk_rate /= 2;
```
调用点在 `dsi_host.c:3023-3029`（SM8750 强制 `dsi_link_clk_set_rate_6g_v2_9`，否则 `cfg_hnd->ops->link_clk_set_rate`）。

### 2.5 `struct msm_dsi_host` — 缺 bool

`dsi_host.c:135-136`
```c
135	unsigned long byte_clk_rate;
136	unsigned long byte_intf_clk_rate;   /* 无 byte_intf_clk_div_2 */
```

### 2.6 byte_intf/byte 的生产/消费点（本树）

| 位置 | 角色 | 证据 |
|---|---|---|
| `dsi_calc_pclk()` 设 `byte_clk_rate` | 生产（理想值，来自 pclk/bpp/lanes） | `dsi_host.c:699-707` |
| `get_phy_clk_req`：`bitclk = byte*7`(C-PHY)/`*8` | 消费（喂 PHY） | `dsi_host.c:2917-2920` |
| `dsi_link_clk_set_rate_6g` OPP vote | 消费 | `dsi_host.c:408-410` |
| `clk_set_rate(byte_intf_clk, byte_intf_clk_rate)` | 消费 | `dsi_host.c:422-430` |
| power_on 计算 `byte_intf_clk_rate` | 生产 | `dsi_host.c:3008-3010` |
| power_on 存 `link_byte_rate/link_intf_rate` | 镜像（供 stale 守卫） | `dsi_host.c:3047-3050` |
| `dsi_cmd_link_clk_set_rate` 比较 byte/intf | 消费（stale 守卫） | `dsi_host.c:2373-2375` |
| `phy_shared_timings->byte_intf_clk_div_2` | 来源 | `dsi.h:150`；生产在 `dsi_phy.c:355`（D-PHY v3）/`:461`（D-PHY v4） |

### 2.7 SM8750 走哪条分支（deliverable 2③）

- `dsi_cfg.c:348-349`：`{MSM_DSI_VER_MAJOR_6G, MSM_DSI_6G_VER_MINOR_V2_9_0, &sm8650_dsi_cfg, &msm_dsi_6g_v2_9_host_ops}`，`msm_dsi_6g_v2_9_host_ops.link_clk_set_rate = dsi_link_clk_set_rate_6g_v2_9`（`dsi_cfg.c:287-298`）。
- 版本由硬件寄存器读得：`dsi_get_version()` → `msm_dsi_cfg_get(major, minor)`（`dsi_host.c:243-247`）。
- 本树**另外按 compatible 强制覆盖**：`dsi_clk_init()` → `dsi_clk_init_6g_v2_9`（`dsi_host.c:363-364`）；`power_on` → `dsi_link_clk_set_rate_6g_v2_9`（`dsi_host.c:3023-3026`）。
- `byte_intf_clk_div_2` 对**本板 = false**：DT `phy-type = PHY_TYPE_CPHY`（`sm8750-lenovo-elden.dts:2426`）→ `phy->cphy_mode=true`（`dsi_phy.c:645-646`）→ `dsi_7nm_phy_enable` 走 `msm_dsi_cphy_timing_calc_v4()`（`dsi_phy_7nm.c:1015-1018`），而该函数（`dsi_phy.c:471-521`）**从不赋值** `byte_intf_clk_div_2`；`phy` 由 `devm_kzalloc` 分配（`dsi_phy.c:620`）⇒ 保持 0。`shared_timings` 由 `memcpy` 拷贝（`dsi_phy.c:780`）。
  - ⇒ 旧 `q28-methodB-NOTES.md` §更正「SM8750 3nm PHY 置 `byte_intf_clk_div_2=true`」**对本板（C-PHY）不成立**（`:461` 是 D-PHY v4 路径）。

### 2.8 调用点 byte RCG 的 parent 是否已 reparent（deliverable 2④）

是。`dsi_link_clk_set_rate_6g()` 仅从 `dsi_link_clk_set_rate_6g_v2_9()` 第 471 行调用，位置在 `clk_set_parent(byte_src_clk, dsi_pll_byte_clk)`（`:459`）之后。⇒ 上游 Method B 的取整放在 `dsi_link_clk_set_rate_6g()` 开头，本树即满足「reparent 之后」语义。

---

## 3. 校准后的 patch（deliverable 3）

文件：`patches/q28-methodB-round-byteclk.patch`（已重写，3 个 hunk）。

### 3.1 与现有草稿的差异及原因

| 项 | 旧草稿 | 修订后 | 原因 |
|---|---|---|---|
| 取整位置 | `dsi_link_clk_set_rate_6g_v2_9()` 的 SM8750 分支内、`clk_set_parent` **之前**（`dsi_host.c:449-457` 处） | `dsi_link_clk_set_rate_6g()` 开头（**reparent 之后**，`:471` 调用） | 旧位置 = 上游要修的时机错误；reparent 前 `clk_round_rate` 沿 XO 求整，返回假值 |
| 取整对象 | `msm_host->dsi_pll_byte_clk` | `msm_host->byte_clk` | 与上游 `2028280686f4` 一致；上游取整的是 RCG `byte_clk` |
| div2 判定 | 启发式 `intf && (intf != ideal)` | 权威 bool `phy_shared_timings->byte_intf_clk_div_2`（power_on 存入） | 启发式在「no-div2 但取整改速率」时误判；权威来源是 PHY shared timings |
| byte_intf 重算 | 在 SM8750 分支里按 `intf_div2 ? rounded/2 : rounded` 预写 | 在取整之后、消费点前按 bool 重算并回写 `byte_intf_clk_rate` | 上游要求 byte_intf 用**取整后** byte rate 推导，否则 retrigger PLL |
| `dsi_calc_clk_rate_6g` | 未动 | 未动 | 本树本就无取整 = 上游 Fixes 后状态，无需改 |
| struct | 未动 | 新增 `bool byte_intf_clk_div_2;`（**保留** `byte_intf_clk_rate`） | 本树有上游没有的 stale 守卫（`dsi_host.c:2373-2375`、`link_intf_rate`），删字段会扩大改动面 |

### 3.2 patch 内容（3 hunk）

- Hunk A `dsi_host.c:135-137`：新增 `bool byte_intf_clk_div_2;`
- Hunk B `dsi_host.c:401-451`：`dsi_link_clk_set_rate_6g()` 开头取整 `byte_clk`（失败 `pr_err` + `return`），byte_intf 块由取整后的 `byte_clk_rate` 按 bool 推导并回写 `byte_intf_clk_rate`
- Hunk C `dsi_host.c:3008-3010` → `dsi_host.c:3030`：power_on 改为只存 `byte_intf_clk_div_2 = phy_shared_timings->byte_intf_clk_div_2;`

### 3.3 验证（未编译、未应用）

```
geekidos-linux$ git apply --check -p1 ../patches/q28-methodB-round-byteclk.patch   # PASS
geekidos-linux$ patch -p1 --dry-run < ../patches/q28-methodB-round-byteclk.patch   # checking file ... PASS
geekidos-linux$ ./scripts/checkpatch.pl --strict --no-tree ...patch                # 1 error(Signed-off-by)+1 warning(commit description)，无代码风格缺陷
```

### 3.4 必需的前置事实（静态已核）

- 本板 `byte_intf_clk_div_2 == false`（§2.7）⇒ 修订后 byte_intf = byte_clk（不减半），与旧 NOTES「更正」相反。
- 本树 PHY 另有私有 no-op：`dsi_pll_7nm_vco_set_rate()` 在「已 `pll_on` 且 DECIMAL/FRAC 与目标 config 相同」时 `goto out_bias` 跳过 commit（`dsi_phy_7nm.c:368-390`，tree-local，vanilla 无）。⇒ 即便取整前后请求同一可实现速率，PLL 也不会重复 commit。

---

## 4. 6G 路径是否真被本机使用 + byte-clk 算式（deliverable 4）

**使用**：是。SM8750 的 DSI 版本为 6G v2.9 ⇒ `msm_dsi_6g_v2_9_host_ops`（`dsi_cfg.c:348-349`），且本树按 compatible 再强制（`dsi_host.c:363-364, 3023-3026`）。

**byte-clk 算式**（参数：`952*2 × 3040`，DSC bpc=10、compressed bpp=8，3 lanes，165 Hz，C-PHY，bonded；取自 `panel-novatek-nt36536.c` 首选 mode 与 DT `phy-type`/`dual-dsi-mode`）：

```
mode->clock = (952+50+16+16)*2 * (3040+26+4+50) * 165 / 1000 = 1 064 606 kHz (=1.0646 GHz)
DSC(bonded): h=952; new_hdisplay = ceil(952*8/(10*3)) = 254 → *2 = 508
             new_htotal = 2068-1904+508 = 672
pclk = 1 064 606 400 * 672/2068 = 345 945 470 Hz ; /2(bonded) = 172 972 735 Hz
byte(cphy) = pclk * bpp(30) / (16*lanes=48) = 172 972 735 * 30/48 = 108 108 000 Hz ≈ 108.1 MHz
bitclk     = byte * 7 (C-PHY)                = 756 800 000 Hz ≈ 756.8 MHz
```
（若忽略 bonded /2，byte = 216.2 MHz、bitclk = 1 513.5 MHz。）

**判定**：byte-clk ≈ **108 MHz**、bitclk ≈ **757 MHz**，**均 < 1 GHz**。因此**不存在**「byte-clk >1 GHz 才走 6G v2.9」这一速率阈值——v2.9 由 DSI 版本寄存器 `V2_9_0`（`dsi_host.c:243`→`dsi_cfg.c:348`）+ 本树 compatible 覆盖决定。任务假设的「>1 GHz 阈值」在本树代码中**未找到**（全 `dsi/` 仅 PHY config 的 `min_pll_rate`=600 MHz/1 GHz 与 `bitclk<=1.5 GHz` 分支，`dsi_phy_7nm.c:1048`）。

---

## 5. refgen 线索核验（deliverable 5）

| 检查 | 结果 | 证据 |
|---|---|---|
| vanilla linux-7.2 `sm8750.dtsi` 有 refgen 节点？ | 无（sm8750 不在 refgen 使用列表） | `/tmp/q28-analy` 未含 dtsi；本树 dtsi 无。旁证：`arch/arm64/boot/dts/qcom/` 使用 refgen 的 SoC 列表不含 sm8750 |
| 本树 `sm8750.dtsi` 有 refgen？ | **无**（grep 退出 1） | `grep -n refgen sm8750.dtsi` → 无 |
| DSI 节点有 `refgen-supply`？ | **无**（dsi0/dsi1/dsi0_phy/dsi1_phy 均无） | `sm8750.dtsi:3420-3507, 3509-3525, 3529-3616, 3594`；`sm8750-lenovo-elden.dts` 无 refgen |
| `qcom-refgen-regulator` 在内核 config？ | **=m**（模块，非 =y） | `geekidos-linux/.config:5243:CONFIG_REGULATOR_QCOM_REFGEN=m`；驱动源码 `drivers/regulator/qcom-refgen-regulator.c` |
| 结论 | refgen 线索对 sm8750 不适用（无节点→不 probe；硬件连线自行处理）；Pengyu「反复重启才有显示」与本机 STORM 现象近似，仅作候选线索保留 | 同上 |

---

## 6. panel 驱动函数级差异清单（deliverable 6）

本树 558 行 vs 上游 486 行（`diff -u reference/upstream-pengyuluo/panel-novatek-nt36536.c geekidos-linux/drivers/gpu/drm/panel/panel-novatek-nt36536.c`）。

| 函数/对象 | 差异 | 分类 |
|---|---|---|
| `to_primary_dsi()` | 上游 `is_dual_dsi ? ctx->dsi[1] : ctx->dsi[0]`；本树恒 `ctx->dsi[0]` | **elden 专有**（下游 bonded 命令 master 是 DSI0；README/PITFALLS #196 已证否为 Q28 杠杆，**勿改回 dsi[1]**） |
| `novatek_prepare()` | 本树加 `for tries` 重试（≤2 次，失败重 reset）、`accum_err` 复查、`goto power_off` 统一清理 | **elden 专有**（Q28 冷起 -110 缓解） |
| `novatek_enable()` | 本树新增：`return panel->prepared ? 0 : -EIO` | **elden 专有** |
| `novatek_off()` / `novatek_unprepare()` / `novatek_reset()` | 逐字节一致 | 已对齐 |
| `force_hz` module_param | 本树新增（测试钩子） | **elden 专有** |
| `novatek_get_modes()` | 本树加 `force_hz` 过滤 + `count` 变量（preferred 给首个被暴露 mode） | **elden 专有** |
| `novatek_panel_funcs` | 本树多 `.enable = novatek_enable` | **elden 专有** |
| `novatek_bl_update_status/_ops/create_backlight` | 一致 | 已对齐 |
| `csot_pp8807hb1_1_init_seq()` | 一致 | 已对齐 |
| `csot_pp8807hb1_1_dsc_cfg` | 一致（bpc=10, bpp=8, slice 476×20×2） | 已对齐 |
| `csot_pp8807hb1_1_modes[]` | 本树把 165 Hz 提前为首（preferred），并新增 40/24 Hz；上游首项为 120 Hz，无 40/24 | **elden 专有** |
| `novatek_probe()` | 本树把 backlight 创建移到 `devm_mipi_dsi_attach()` 之前（先解析 suppliers），并把「设 dsi 参数」与「attach」拆成两个循环 | **elden 专有**（probe 顺序，见 README） |
| `csot_pp8807hb1_1_desc` / `of_match` / driver / MODULE_* | 一致 | 已对齐 |

**上游对齐缺口：无实质项。** 唯一与上游不同的 `to_primary_dsi()` 是**有意的、被验证为 no-op** 的本树语义，不属对齐缺口。⇒ panel 驱动无需为 Q28/Method B 改动。

---

## 7. 与现有草稿差异汇总

1. 取整从「reparent 前（v2_9 SM8750 分支）」**移到**「reparent 后（`dsi_link_clk_set_rate_6g` 开头）」——唯一功能性纠正。
2. 取整对象由 `dsi_pll_byte_clk` 改为 `byte_clk`（与上游一致）。
3. div2 由启发式改为权威 bool；新增字段。
4. byte_intf 改为「取整后按 bool 重算」。
5. 旧草稿的旧版式（含 timestamp 头、单一 hunk）被替换为 3 hunk 的 `--- a/… +++ b/…` 标准 diff。

---

## 8. 未核 / 风险 / 建议

- **未核**：未上机、未编译，故 §4 数字为静态推算（依赖 DSI 版本寄存器在实机确为 6G v2.9；本树 compatible 覆盖使其即便版本读数不同也走 v2.9 链接率函数）。
- **风险 A**：本树在 reparent 前已用**未取整**值 `clk_set_rate(dsi_pll_byte_clk, byte_clk_rate)`（`dsi_host.c:450-451`）。修订后的取整发生在其后，PLL 时钟已按内部求整编程；因 PHY 会自行求整，二者一致，但若日后删掉该前置 set_rate 需重新评估。
- **风险 B**：本树 PHY 已带 no-op 守卫（`dsi_phy_7nm.c:368-390`）与 `dsi_cmd_link_clk_set_rate` stale 守卫（`dsi_host.c:2360-2392`），Method B 在本树的**净增益可能有限**；其价值是「存入的 byte 值为 PLL 可实现值 + byte_intf 一致」，是否真正改变 Q28 需上机验证。
- **建议下一步**：编排者独立复跑 `git apply --check`/`patch --dry-run`；若上机，先确认日志出现取整 DBG 行且 byte_intf==byte_clk（本板 div2=false），再判 Q28。
- 说明：`patches/q28-methodB-NOTES.md` 顶部已加「SUPERSEDED」状态块，避免旧单 hunk 描述误导；其历史正文保留。
