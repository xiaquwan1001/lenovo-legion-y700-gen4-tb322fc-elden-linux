# dispcc reset RFC v2 备料（B10 / A7）— 2026-11-13

> 状态：**备料完成，结论是「建议撤回 RFC 线程，不再单独立 v2 系列」**（发/撤的最终裁决 = A7，需用户放行）。
> 零发信、零设备动作；基线 `gh/master` = `9d66f26fef`（7.4-rc3 线），门禁在 `/tmp/g74` 做。

## 0. 结论（三条）

1. **「v2 备料」这件事已经做完了，而且是在 2026-10-29 就做完的**：
   三枚补丁（binding / driver / dtsi）+ 四项门禁全绿，落在
   `patches/upstream/q28-dispcc-v2-20261029/`（形状说明见 `reports/m8-dispcc-v2-20261029.md`）。
2. 这个 v2 形状**已经投出去了**——就是 2026-11-13 的 `drm/msm/mdss` **v4** 三连
   （`patches/upstream/m8-mdss-v4-20261113/`）：1/3（binding）在 v3 上已有 Rob 的 Ack、
   3/3（dts）带 Abel RV + Dmitry RV，2/3（driver）卡在 Dmitry 三问上（⇒ A1 / B3）。
   注：v4 的 0001 文件里**没有**把 Rob 的 Acked-by 带回来（`grep -c '^Acked-by' v4-0001` = 0，
   另两枚有/无需），下次 revision 时应补上——这条属 A1 的小尾巴，不影响本项结论。
   也就是说 **counter/dispcc 的 RFC 线程已经被 mdss 系列取代**，再发一个「dispcc v2」只会造成两条线并行。
3. 原承诺的第三件（**simple-framebuffer 在场对照**）**是测量、不是补丁**，且必须上机；
   本文件 §4 给出可直接执行的对照协议与只读判据，**今晚不做**（无设备）。

⇒ **建议**：在 A7 里选「撤」（回信指向 mdss 线程即可），**不**再产 clk 侧或第三枚 RSCC 的补丁；
若一定要留一条「v2」，那也只能是 mdss 线程里 2/3 的修订，而那已经是 A1 的工作。

## 1. 起点：RFC v1 的形状与两个否决

`patches/upstream/q28-dispcc-2026-10-22/0001-clk-qcom-dispcc-sm8750-reset-MDSS-blocks-at-probe.patch`
（patchwork `14909706`，2026-10-22）：

- 落点：`disp_cc_sm8750_probe()` 内、`clk_taycan_elu_pll_configure()` **之前**；
- 动作：`of_machine_is_compatible("lenovo,elden")` 门控下，`regmap_write()` 断言三枚 BCR
  （`0x8000` / `0xa000` / `0xc000`，逐位表见 `reports/mdss-int2-evidence-20261113.md` §1），
  `msleep(50)` 后**逆序**释放。

Taniya Das 2026-10-22 22:52 +0800 否决两点（转述，见 `reports/m8-dispcc-v2-20261029.md` §1.2）：
① 复位职责属显示 SW，不属 clk driver；② dispcc 整块复位 + PLL 重配会闪屏。
我方 2026-10-28 已回信接受并承诺改形状（同报告 §1.2）。

## 2. 承诺三件 vs 现状

| 承诺（11-13 口径） | 现状 | 证据 |
|---|---|---|
| ① 挪到 display 侧 | **已完成**：`msm_mdss_reset()` 改用 reset 数组 API，clk 侧 35 行改动归零 | `q28-dispcc-v2-20261029/0002-…patch`（`devm_reset_control_array_get(dev, RESET_CONTROL_OPTIONAL_EXCLUSIVE)`，删 `reset_control_put()`）；已作为 **mdss v4 2/3** 投出（patchwork `14931324`，state 现 `superseded`，v4 顶替） |
| ② 用 `reset_control_*` | **已完成**（同 ①）；optional 语义保留（DT 无 `resets` ⇒ 返回 NULL ⇒ 早退）；`msm_mdss_reset()` 仍是 `msm_mdss_init()` 第一行 | 同上；7.4-rc3 里调用点 `msm_mdss.c:388`，函数体 `:324-345` |
| ③ 补 simple-framebuffer 在场对照 | **未做，且只能上机做**；另附一个静态发现（§3） | §4 |

所以「再出一版 dispcc v2 补丁」在内容上与 mdss v4 **重复**（唯一差别是我方 10-29 版把 RSCC 也列进 DT，
而 v4 已按 Dmitry 要求**删掉 RSCC**）。

## 3. simple-framebuffer 对照：我们其实已经有半边证据

`build/daily/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts:1211-1216`（我们自己的板级 DT 注释）：

> The simple-framebuffer is deliberately NOT described here … its `DISP_CC_MDSS_CORE_BCR` reset
> pulls the ABL handover framebuffer out from under simple-framebuffer, so fbcon would bind to a dead fb.

⇒ **执行复位会打掉 bootloader 交接的 framebuffer** 这一点，在本板上是**已观测事实**（因此我们故意不描述该节点）。
静态影响面（7.4-rc3，`/tmp/g74`）：

| 事实 | 数字/位置 |
|---|---|
| 描述 `simple-framebuffer` 的 qcom 板级文件 | **52 个**（`rg -l "simple-framebuffer" arch/arm64/boot/dts/qcom/ \| wc -l`） |
| 其中与本系列最相关的 | `sm8650-valve-deckard.dts`（同世代 SoC，若将来把多复位推广到 sm8650，这会第一个受影响） |
| sm8750 的 mtp/qrd/elden | 都**没有**描述 `simple-framebuffer` |

这解释了为什么 v4 只动 sm8750：别的板子可能在用 simpledrm/fbcon，多复位会把启动画面打掉
（可解释但用户可见）。这条要写进回信，是「为什么不是无条件推广」的正面理由。

## 4. 对照实验协议（**未上机**，留给上机 lane）

- 目的：量化「复位 MDSS 块」在 **simple-framebuffer 在场**时造成的可见影响，以及两种交接形态下的收益。
- 两臂（同一内核，只改 DT）：
  - **arm S**：`elden.dts` 的 `chosen` 里**加**一个 `framebuffer@…` 节点（沿用 ABL 交接的地址/stride，
    即把注释里「故意不描述」的那段恢复），并把 fbcon 绑到 simpledrm；
  - **arm N**：现状（不描述）。
- 每次冷起（真 POR，`n ≥ 5/臂`）记：
  1. `dmesg -t | grep -E "simple-framebuffer|simpledrm|Console: switching|fb0"`（谁先注册、有没有被踢掉）；
  2. `ls /proc/fb`、`cat /sys/class/graphics/fb0/virtual_size`（arm S 期望有 `fb0`）；
  3. `dmesg -t | grep -cE "command DMA timeout"`（疗效，判据同 B3 §3.4）；
  4. 目视项（人）：复位发生到 DRM 接管之间有没有黑屏/闪一下，多久。
- 判据（预注册，避免事后解释）：
  - 若 arm S 出现「fb0 被 unregister + 目视黑屏 > 1 s」⇒ 复位对 simpledrm 平台的代价不可接受 ⇒
    多复位应改成 **DT opt-in**（或仅在无 `simple-framebuffer` 时启用），并把这个条件写进 binding 讨论；
  - 若 arm S 只见「一闪（< 200 ms）」且 fbcon 正常回到 DRM fbdev ⇒ 维持 v4 的无条件形状；
  - 两臂都必须 0 次 STORM 才算「复位有效」。
- 只读命令里不需要 root 的部分都可直接跑；**不要**用 `devmem` 读 MDSS 寄存器做本实验
  （无时钟访问可能 SError，见 B3 §3.4 的风险注记）。

## 4b. 本目录里的补丁文件

三枚 = `patches/upstream/q28-dispcc-v2-20261029/000{1,2,3}-*.patch` 的**逐字节副本**
（`SHA256SUMS` 与本目录外的原件对照过，全同），复制过来是为了让「在 7.4-rc3 上重跑的门禁」与补丁同目录可复核；
**原件仍是 `q28-dispcc-v2-20261029/`**（审计链不动）。

## 5. 门禁（在 `gh/master` 上重跑既有 v2 三枚；本机实测 2026-11-13）

之前（10-29）的门禁是在 7.3-rc7 `24a19b953e` 上做的；基线换到 7.4-rc3 后**重跑一遍**：

| 门禁 | 命令 | 结果 |
|---|---|---|
| `git am` ×3 | `/tmp/g74`（`gh/master` 导出 + base 提交），逐枚 `git am --3way` | **3/3 rc=0**（`36d515af2` / `89aebf53e` / `ac6bd5016`，无 fuzz 无冲突） |
| `checkpatch --strict` ×3 | `/tmp/g74/scripts/checkpatch.pl --strict --no-tree` | **均 0E / 0W / 0C**（22 / 31 / 10 行） |
| binding 文档校验 | `dt-doc-validate Documentation/devicetree/bindings/display/msm/mdss-common.yaml …/qcom,sm8750-mdss.yaml`（打上 0001 后） | **rc=0**（注：`make dt_binding_check` 在该树里所有子步带 `\|\| true`，非致命，不作为证据——沿用 10-29 报告 §4 的修正） |
| 目标文件编译 | `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j26 W=1 drivers/gpu/drm/msm/msm_mdss.o`（config = `build/m3v2-7.3rc7/.config` 副本） | **rc=0，0 warning / 0 error** |

（`dtbs_check` 该 need：DT 改动只把 mdss `resets` 从 1 项变 3 项，binding 已放宽；10-29 报告
已记「既有 dtsi 的 mdss 复位均 ≤1 项 ⇒ 不放宽也不影响他人」。本 lane 未跑全量 `dtbs_check`。）

## 6. 建议给的处置（A7 二选一）

- **推荐：撤。** 回信要点（不是正文）：① 接受 Taniya 的两点；② v2 形状已按承诺实现，并已作为
  `drm/msm/mdss` 系列（v4，patchwork `14931324`）投出，请在该线程继续；③ 本 RFC 不再单独出 v2，
  避免两条线并行；④ simple-framebuffer 对照的结论一旦上机拿到，会回到 mdss 线程补数据。
- 备选：若维护者更希望 clk 侧保留一个「handover 可复位」入口，那也不是 v2，而是**新的 RFC**
  （DT opt-in 属性 + mdss 侧驱动），需要重新走 A 类批准，本轮不做。

## 7. 不要再做的事（避免踩回去）

- **不要**重发 clk 侧 35 行（已被否决两次）；
- **不要**再加 RSCC 到 DT（v4 已按 Dmitry 要求删；A/B 的有效臂是三枚，但 v4 形状只两枚，这一点 v4 README 已如实记「未测」）；
- **不要**把「复位时刻在 PLL 之后」当作已验证的疗效——`m8-dispcc-v2` 报告 §5/§6 已把它列为开放问题 1，
  `TASKS/README.md` §5「M8 续测结果（2026-10-30）」也记：v2 是否治 Q28 **未证实**（坏发未复现、未刷 v2）。
