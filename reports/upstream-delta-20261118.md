# 上游变化侦察（窗口 2026-11-13 → 2026-11-17，写于 2026-11-17 UTC）

口径：只读。基线 = 我们的 **7.4-rc3 `aebb727447`**（已用 cgit tag 页核对：`aebb7274476403040d582c61478df8f4a7bf9cd3`，
https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tag/?h=v7.4-rc3 ，200，2026-11-17 取）。
「已合入」= 已进 **linux-next（next-20261116）**；7.4-rc3 之后 master 只收了 1 处与我们相关的修复（见 §1.4）。
文件级判据 = 同路径 blob 在 `refs/tags/v7.4-rc3` vs `refs/heads/master`(torvalds) vs `refs/heads/master`(linux-next) 是否同 id
（kernel.googlesource.com `?format=JSON`）。逐条 URL 见行内。

## 0. 结论先行

1. **最重要的变化不在我们 4 个在飞系列上，而在相机路线**：Qualcomm 的 `Add CAMSS support for SM8750 and Eliza` **v7（23 枚，2026-11-14）**
   把 SM8750 CSIPHY **binding 与驱动全都自己做掉了** —— 与我们 `patches/upstream/camss-csiphy-24-v2-20261117/` 的 0001/0002 **正面重叠**。
   我方 v2 的「删 0001、只补 lane 表」前提现在成立得更彻底：`0002` 也需重新定位（对方把 sm8750 直接绑到 kaanapali cfg）。
2. **Kaanapali CSIPHY 驱动已进 linux-next（phy for-next）**：`00926bc50707 phy: qcom-mipi-csi2: Add Kaanapali support`（相对年龄 4 天，≈11-13）。
   我方 v2 已按它重基（patch 里 `index 165e3d0..` = next 的 `phy-qcom-mipi-csi2-core.c` blob），**无需再重基**，但 `.h` 新增 `common_status_offset` 字段已固化。
3. **`qcom,nsessions` 废弃已在 linux-next，未进 7.4-rc3**：`641dd7dd0f68` cgit 提交页 200（next），v7.4-rc3 的
   `qcom,fastrpc.yaml` 无 `deprecated: true`，next 有（第 104 行）⇒ 板级 DTS 若仍写该属性，在 7.5 会报废弃。
4. **qcom for-next 已合 7.5 的一批 sm8750.dtsi 改动**（4 枚，11-07~11-12 提交）：含 `snps,resume-hs-terminations`、
   APSS watchdog、**ADSP remote heap 由 `reusable` 改 `no-map`**、**CDSP compute CB 的 iommu stream-id mask 修正** —— 后两条直撞我们的 ADSP fastrpc / pstore 叙事。
5. 我们 6 个 11-17 新投系列 + pstore + mdss v5 + dsi-phy v2 **零人工回复**（窗口内新增评论全是 `sashiko-bot@kernel.org`）。
6. 维护者层面只有一处变动，且是 **dwc2** 不是 dwc3：`DESIGNWARE USB2 DRD IP DRIVER` 的 M 从 Minas Harutyunyan 换成 **Thinh Nguyen**，
   同时删掉 `T: git balbi/usb.git`。**dwc3 段（`DESIGNWARE USB3 DRD IP DRIVER`）M 仍是 Thinh Nguyen**，收件人不变。

## 1. 已合入（都在 linux-next / for-next，不在 7.4-rc3）

| # | 变化 | 证据 | 影响我们的哪个目录 |
|---|---|---|---|
| 1.1 | `phy: qcom-mipi-csi2: Add Kaanapali support` + `Parametrise the common status register offset`（Hangxiang Ma，phy tree） | commit `00926bc50707`，https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/log/drivers/phy/qualcomm/phy-qcom-mipi-csi2-core.c （2026-11-17 取，"4 days"）；patchwork `[v25,01/15] ... Add Kaanapali CSI2 PHY` state=**accepted** | `camss-csiphy-24-v2-20261117/`（**已重基，仅需确认**）；新增 `common_status_offset`、`mipi_csi2_dphy_3nm_kaanapali` |
| 1.2 | sm8750.dtsi 四枚：`sm8750: Set snps,resume-hs-terminations`(Peter Chen)、`sm8750: Add watchdog node`(Komal Bajaj)、`sm8750: Make the ADSP remote heap no-map`(Jianping Li)、`sm8750: Fix iommu stream ID masks for CDSP compute CBs`(Vinayak Katoch) | https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/log/arch/arm64/boot/dts/qcom/sm8750.dtsi （"9 days"/"10 days" 行）；顶层 `5 days \| Merge branches 'arm32-for-7.5'... \| Bjorn Andersson` | `board-dts-single-*`（新文件，仅上下文）、`m8-mdss-v5-20261114/0003`（sm8750.dtsi 上下文）、ADSP non-secure 系列、dwc3-v9 的 0004 |
| 1.3 | 树wide 头文件清理（`Merge branch 'headers' of git://git.infradead.org/users/willy/pagecache.git`，18 小时前）+ `treewide: Convert devm_kmalloc() family to devm_kmalloc_obj()`（Kees Cook，11 天前） | https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/log/drivers/input/misc/aw86927.c ；实测 diff：next 的 `aw86927.c` 仅多一行 `#include <linux/interrupt.h>`（第 15 行） | `haptics-v2-20261117/`（0001 首个 hunk `@@ -48,7` 之后整体 +1 行偏移，`git am` 带 offset 可过） |
| 1.4 | **7.4-rc3 之后进 master 的唯一相关修复**：`usb: dwc3: gadget: Wait for End Transfer completion on ep disable`（Thinh Nguyen）——改 `core.h`（新增 `DWC3_EP_PENDING_NOOP_START`、`dwc3_remove_requests()` 多一个 `bool` 形参） | blob：`core.h` rc3 `f3dabb37f806` → master/next `267c922ca11b`（DIFF）；其余 `core.c/debugfs.c/drd.c` rc3=master **同 id** | `dwc3-v9-20261117/`：命中点在 771/1696 行，我方 hunk 在 1008/1306 行 ⇒ **无文本冲突** |

附：`next-20261116` 已是当前 next 版本（releases.json，2026-11-16）。

## 2. 有改动需重基 / 需重新定位

| # | 对象 | 事实 | 处置建议（不执行） |
|---|---|---|---|
| 2.1 | **`camss-csiphy-24-v2` 两枚** | Qualcomm `Add CAMSS support for SM8750 and Eliza` **v7 23 枚（2026-11-14）**：`[01/23] dt-bindings: phy: qcom,x1e80100-csi2-phy: Add SM8750 CSI2 PHY`（同一文件、同一 compatible）与 `[06/23] phy: qcom-mipi-csi2: Add SM8750 support`（把 `qcom,sm8750-csi2-phy` **直接指向 `mipi_csi2_dphy_3nm_kaanapali`**）。见我方的两处：<https://patchwork.kernel.org/series/1211298/>、<https://patchwork.kernel.org/project/linux-phy/patch/20261114-add-support-for-camss-on-sm8750-v7-1-8ff2a11835f6@oss.qualcomm.com/>、<...v7-6-...@oss.qualcomm.com/> | 我方 `0001` 与该 v7 `[01/23]` **重复**（Krzysztof 11-14 18:11 已判「Does not apply, so should be squashed with dependency」，Bryan 11-15 12:05 追问 C-PHY/D-PHY/combo，Wenmeng 11-16 02:38/02:39 回「ACK. Will update in next version」）⇒ 等 v8 落地再决定我方是否只保留「2.4.0 lane 表」；若 v8 仍用 kaanapali cfg，我方 0002 的正确形状 = 改那一行 `.data`，不是新增 cfg |
| 2.2 | **`camss-csiphy-24-v2` 前置①** | 「SM8750 CAMSS v6 1/7 已进 tree」= **否**。series `1131656`（v6，7 枚，2026-07-21）7 枚 state 全 `new`；并且 v7 已取代它。<https://patchwork.kernel.org/series/1131656/>、<https://patchwork.kernel.org/series/1211298/>。树侧：`Documentation/devicetree/bindings/media/qcom,sm8750-camss.yaml` 在 next/master 均 **404**（kernel.googlesource `?format=TEXT`） | 我方 README 里「进 tree 则删 0001」的条件**未触发**；但「v7 合并则删 0001」的条件**已近触发** |
| 2.3 | `m8-mdss-v5-20261114/0003`（sm8750.dtsi 那枚） | sm8750.dtsi 在 next 已 diff（§1.2）；`msm_mdss.c` / `mdss-common.yaml` / `qcom,sm8750-mdss.yaml` 三者 rc3=master=next **同 blob** | 只需 rebase dts 上下文；MDSS 侧零冲突。（12 小时内有一条竞争串 `[v3,03/11] dt-bindings: display/msm: Document Nord MDSS`（11-16），但按文件清单未触 `mdss-common.yaml`） |
| 2.4 | ADSP fastrpc non-secure 系列 | `sm8750: Fix iommu stream ID masks for CDSP compute CBs`（Vinayak Katoch）与 `Make the ADSP remote heap no-map`（Jianping Li）在 next；`qcom,nsessions` 已 `deprecated: true`（next 版 yaml 第 104 行，rc3 无） | 论证里「我们改 domain 属性」的对照证据与寄存器口径需按这两条重核；板 DTS 若写 `qcom,nsessions` 需删 |
| 2.5 | `haptics-v2-20261117/` | `aw86927.c` 在 next 多一行 include（§1.3）；binding `awinic,aw86927.yaml` rc3=master=next **同 blob** | 重发 v3 前对 `refs/heads/master` 重跑一次 `git am --3way` 即可（预期 offset 1 行） |
| 2.6 | `dwc3-v9-20261117/` | §1.4 的 `core.h` 形参变化 | 无文本冲突；但语义上「ep disable 等 End Transfer 完成」会改 role-mux 切角色时的时序假设，需在 cover/答复里显式说明未受影响 |

## 3. 无变化（判定依据：rc3 = master = next，同 blob id）

- **pstore ram/initrd 守卫**：`fs/pstore/ram.c` `fs/init/`… 实际三件 `fs/pstore/ram.c`、`init/initramfs.c`、`include/linux/initrd.h` **全部同 blob** ⇒ 未合、也未被别人改。
  另：lkml 侧窗口内只有我们自己两封、**无回复**（marc.info 检索 `pstore initrd`：仅 `[PATCH 0/2]`/`[PATCH 2/2]` 两条，2026-11-16，无 `Re:`；
  https://marc.info/?l=linux-kernel&w=2&r=1&s=pstore+initrd&q=b ）。patchwork 上 `[2/2]` 在 linux-arm-msm 记 `handled-elsewhere`，但树侧未变 ⇒ **不是已合入**。
- **wl2868c v12**：`willsemi,wl2868c.yaml` 与 `wl2868c-regulator.c` 均 404/同 blob（未合）；v12 两枚 patchwork 无新评论（只有 v11 的 Rob 11-16 15:10 补 R-b）。
- **dsi-phy PLL_SYSTEM_MUXES**：`drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c` rc3=master=next **同 blob**，窗口内无 DSI 补丁触及它（cgit log 最新仍是 2026-07-12 的 Revert）。
- **dpu gamma LUT**：`dpu_crtc.c` 同 blob；dri-devel 窗口内只多了一条 rockchip gamma 串（与我们无关）。
- **mdss v5 三枚**：`msm_mdss.c`、`mdss-common.yaml`、`qcom,sm8750-mdss.yaml` 同 blob；无人工回复。
- **elden 板 DTS**：无同名文件被他人提交；`arch/arm64/boot/dts/qcom/Makefile` 有 diff 但 **sm8750-* 段零改动**
  （diff 里只有 eliza/hamoa/glymur 等行的增删）⇒ 我方 `+dtb-...sm8750-lenovo-elden.dtb` 上下文仍在。
- **usb roles class.c**：同 blob（`edec139b`），dwc3 v9 的 roles 侧无冲突。

## 4. 查不到 / 取证受限（如实记录）

1. **lore.kernel.org 全线 403**：`curl -sSL https://lore.kernel.org/all/?q=wl2868c&x=A` → `403 Forbidden`（nginx，146 B）；
   `/linux-arm-msm/` 同样 403（2026-11-17 实测，与 11-13 报告的 Anubis 判断一致）⇒ 本报告一律用 **patchwork REST**（同源）+ **cgit** + **marc.info** 替代，未引用 lore 深链。
2. **patchwork 全局搜索被禁**：`/api/1.2/patches/?q=...` 不带 project 返回 `400 Searches must be limited with one of these parameters: project, series` ⇒ 只能逐项目检索（92/21/363/17/401/4/429 已扫）。
3. **linux-next 的 git log JSON API 需鉴权**（`kernel.googlesource.com/+log/...?format=JSON` → `401`），改用 cgit 的 `log/<path>` HTML；
   该站 TLS 间歇性 `unexpected eof`（需重试 4-6 次），属传输失败、非「查无」。
4. **SM8750 CAMSS v7 是否会被 Bryan 合入**：无法从公开状态判断，最新事实只到 Wenmeng 11-16 02:38「Will update in next version」。
5. **`phy: qcom-mipi-csi2: Parametrise the common status register offset` 的 commit id** 未单独取到（cgit 只取了同页前两条），仅确认 subject/作者/相对时间（4 天）。

## 5. 五个关键前置的直接回答

| 前置 | 结论 | 证据 |
|---|---|---|
| ① SM8750 CAMSS「v6 1/7」已进 tree？ | **否**（v6 全 7 枚 `new`；v7 23 枚取代之且也未合；`qcom,sm8750-camss.yaml` 404） | series 1131656 / 1211298；googlesource 404 |
| ② `641dd7dd0f68`（nsessions 废弃）在主线/next？ | **在 linux-next，未在 7.4-rc3**（next yaml 有 `deprecated: true`，rc3 无；cgit next 提交页 200，torvalds 侧 404） | https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/commit/?id=641dd7dd0f68 |
| ③ Kaanapali PHY（phy-next）现状 | **已合入 phy for-next**，随之进 next-20261116；驱动侧两枚 + `common_status_offset` 参数化 | commit `00926bc50707`；patchwork `[v25,01/15]` accepted |
| ④ 新 CSIPHY/dsi 补丁触及我们要改的文件？ | **CSIPHY 有**（v7 `[01/23]`、`[06/23]`，均未合，但同文件同 compatible）；**DSI 无** | 上表 2.1；dsi_phy_7nm.c 同 blob |
| ⑤ 7.4 周期进展 | mainline **7.4-rc3（2026-11-15）**，stable **7.3.5（2026-11-17）**，linux-next **next-20261116**；rc4 尚未发布 | https://www.kernel.org/releases.json （2026-11-17 取） |

## 6. 维护者 / 收件人变动

- `DESIGNWARE USB2 DRD IP DRIVER`：`-M: Minas Harutyunyan` → `+M: Thinh Nguyen <Thinh.Nguyen@synopsys.com>`，并删除 `-T: git git://git.kernel.org/pub/scm/linux/kernel/git/balbi/usb.git`
  （MAINTAINERS rc3 第 7594 行区 vs next 对应段）。**dwc2 专属，不影响我方 dwc3 收件人。**
- `DESIGNWARE USB3 DRD IP DRIVER`：M 仍为 **Thinh Nguyen**，`F: drivers/usb/dwc3/`（next MAINTAINERS，2026-11-17 取）⇒ 收件人不变。
- 其余我们发信涉及的段（`ARM/QUALCOMM SUPPORT`、`QUALCOMM CAMERA SUBSYSTEM DRIVER`、`GENERIC PHY FRAMEWORK`、`PSTORE FILESYSTEM`、`USB SUBSYSTEM`）
  M/R/L 名单 **逐字未变**（同一脚本解析 rc3 与 next 的 MAINTAINERS 段落 diff，输出为空）。
- 窗口内 MAINTAINERS 全文件共 379 行变动，均为新增驱动段/新 binding `F:` 行，未触及上述 5 段。

## 7. 建议（不执行，等批准）

1. `camss-csiphy-24-v2` **暂不投**：等 v7 → v8；届时 0001 大概率删除，0002 收敛为「`.data` 指向 2.4.0 表」的一处改动 + 一次上机出流回归。
2. 所有 11-17 已投系列的 rebase 目标从 `aebb727447` 改为 **`refs/heads/master`（7.4-rc4 前的 against-7.4）**，并对 next 跑一遍 `git am --3way` 作为 7.5 预演（预期只有 haptics 的 1 行 offset、mdss 0003 的 dts 上下文）。
3. 板 DTS 侧核 `qcom,nsessions`（7.5 起废弃）与 ADSP remote heap `no-map` 后，我方 fastrpc 论证补一句「remote heap 已 no-map」以免与主线冲突。
4. 全部维持「不发信」：窗口内零人工回复，没有需要回应的 reviewer 意见。

---

## 8. 勘误（2026-11-18 主会话复核，§4「取证受限」的其中 3 条已被判定为「客户端缺口」，不是网站限制）

| §4 条目 | 原判 | 复核实测（2026-11-18） | 处置 |
|---|---|---|---|
| 1. lore 全线 403 | 认为只能改用 patchwork/cgit/marc | `curl` 确实 403（Anubis nginx 页），但 **`~/.local/bin/lore-query.py` 搜索与 `/raw` 正文都能取到（200）** | **已闭环**：脚本原只解 1 轮挑战（`/raw` 会连发 2 轮）⇒ 改成最多 4 轮循环；`&x=A` 只加到 `?q=` |
| 2. patchwork 全局搜索被禁 | 只能逐项目 | 设计如此（必须带 `project=`），逐项目实测 200 | 不是限制；按项目批量扫即可（约 10 个项目） |
| 3. googlesource JSON 401 | 只能读 cgit HTML | 401 只出现在 `+log/...?format=JSON`；**blob 的 `?format=TEXT` 200**（本报告文件级判据本来就是用它） | 内容核对已够；提交历史用 cgit `log/<path>` |
| 4. TLS 间歇 eof | — | 重试可解 | 保留：重试 3–6 次 |

**仍属真限制的只有「不可知类」**：上游何时合入、维护者是否接受（v7→v8 何时落地）——这类不能靠取证解决，只能等。
