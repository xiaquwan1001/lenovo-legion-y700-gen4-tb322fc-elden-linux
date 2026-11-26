# Gunyah 进「日常线」的可行性裁决（2026-11-26，lane G）

> **来源**：lane G（researcher / `custom.ustc-pool/ustc-dsf`）本轮产出；父代理已逐条独立复核 §1/§2 的关键判据（见 §9「父代理复核」）。
> **投递/授权**：零设备写、零设备命令、未发信、未改 `TASKS/`/`INDEX.md`/`PITFALLS/`、未 commit。
> **工单**：用户 2026-11-26「gunyah 始终没法进日常线」⇒ 判「要不要/怎么才能进」。
> **基线**：`reports/gunyah-lane-20261126.md`（同日静态面 §1/§2/§3）、`reports/gunyah-decision-20261025.md`（终局裁决）、`reports/gunyah-73-port-20261112.md`、`reports/gunyah-b15-iceland-rmdrv-20261113.md`。


> **落盘口径**：本文件是工单 G 的唯一产出；正文可直接以 `reports/gunyah-daily-line-20261126.md` 落盘（标题/正文无需改动）。
> **取证性质**：**零设备写、零设备命令**。本轮为纯主机侧只读取证（GitHub Contents API / kernel.org cgit / patchwork API / lore / raw 文件），未 `ssh`、未 `insmod`、未 `fastboot`。
> 设备侧事实沿用同日只读结果 `reports/gunyah-lane-20261126.md` §2 F4/F5（未重新采，文中已标注）。
> **未做**：未改 `TASKS/` / `INDEX.md` / `PITFALLS/`，未 `git commit`，未发邮件。
> **证据分级**：`[直证]` = 本轮抓到的原文/目录项；`[解读]` = 对直证的推理；`[推断]` = 研究者推断（无直接证据）。
> **时间戳**：本轮无 shell 工具，抓取时刻未逐条记录，故**不编造时间**；每条给出可复跑 URL（§6）。凡复核 `2026-11-26` 报告（`gunyah-lane-20261126.md`）结论者，逐条标「仍成立」。

---

## §0 回执：一页结论表

**一句话**：Gunyah 进不了日常线**不是技术卡点，是结构事实**——日常线 = `build/daily` 的上游 7.3.1 树，而 `drivers/virt/gunyah` **从未进过上游**（本轮内容级再证）；本地唯一能让它出现在树里的是 out-of-tree 移植树 `build/gunyah-port`，已于 2026-11-25 清理删除；而"跑子 VM"这个目的在 2026-10-25 已终局裁决不可行。**建议：不做（止损），明确不进日常线。**

| 维度 | 判断 | 内容（证据见 §1–§3） | 成本 / 数量级 |
|---|---|---|---|
| **上游化（投 `drivers/virt/gunyah`）** | ⛔ **不能** | torvalds `master` 与 linux-next 的 `drivers/virt` **无 gunyah**（目录项 + `/contents` 404 双证）；`drivers/virt/Kconfig` 全文无 `GUNYAH` 符号；linux-virtualization patchwork 的 `q=gunyah` 系列数 = **0**；driver 系列最后一代仍 **2024-02-22 v17** | **无接收面**（不是"贵"，是"没处投"） |
| **进日常线（本地树里带 gunyah）** | ⚠️ **能做，但只值 ≈0.5 人日，且不建议做** | 只需重建移植树 + 接线（`build/daily/drivers/virt/Makefile` 现无 `obj-$(CONFIG_GUNYAH)`，树内无 `drivers/virt/gunyah/`） | 0.5 人日重建 + 每级内核 0.3–0.5 人日重放 |
| **长期维持 out-of-tree（日常组件）** | ⛔ **不建议** | 移植面 = 18 文件 / ≈184 KB（≈5.5k 行，量级判断）+ `arch/arm64/gunyah` + 4 个头；每升一级内核要重放 API 适配、**整套重编 10 个 `.ko` + 全量部署模块树**（vermagic 耦合）、并再占一个设备窗 | 每级内核 0.3–0.5 人日（编译）+ 1 设备窗（验证）；iceland 每内核重做一版（q89b…q91n）是"持续支出"的旁证 |
| **等上游** | ⛔ **不建议（期望值≈0）** | v17（2024-02-22）后 2 年零新版本；2026 年 gunyah 动作**全在外围**（watchdog / SCM 探测 / DTS 元数据）；且**上游合并也不解决本机**（病因在固件 RM 世代 + 厂商 `MEM_DONATE`/`loader` 不在主线） | 无限期；即便成功，收益仍为 0 |
| **本地等价替代（真目的 = 跑子 VM）** | ⛔ **KVM / PKVM 不可达** | EL2 被签名 Gunyah 占住，ABL 之上无法替换（C8/Q4 结论，本轮核对**仍成立**）；主线 `arch/arm64/kvm` 无 gunyah 后端 | 0（无路） |
| **真能交付用户目的的路（非 gunyah）** | ✅ **已走** | G2 = Waydroid（redroid 备胎）；G3 = Box64 + Wine/Proton | 已在主线上 |
| **`gunyah_wdt`** | ⛔ **已否 + 无上游化空间** | 主线 `drivers/watchdog/Makefile` 有 `obj-$(CONFIG_GUNYAH_WATCHDOG) += gunyah_wdt.o`（直证）；本机 hyp 侧空实现（D19 上机否证，11-26 复核仍成立） | — |

**关键数字**：`0`（上游 `drivers/virt` 中 gunyah 目录数）· `0`（linux-virtualization patchwork gunyah 系列数）· `2024-02-22`（driver 系列最后一代 v17）· `18`（piano gunyah 目录文件数）· `≈184 KB`（目录文件字节数之和，≈5.5k 行）· `1`（7.3 上真实代码改动处数）· `0.5 人日`（重建移植树）· `1.25 人日 + 1 设备窗`（重建 → C2 二值判定全链）· `9289 / +16`（iceland 整栈 import 行数 / 后续修正系列数）。

---

## §1 问题 1：上游现状（内容级现查）

### 1.1 torvalds/linux `master`：`drivers/virt` 无 gunyah（三重内容级证据）

| # | 检查 | 结果 | 证据 |
|---|---|---|---|
| a | `GET /repos/torvalds/linux/contents/drivers/virt?ref=master` 目录项枚举 | 返回 **9 项**：`Kconfig`、`Makefile`、`acrn/`、`coco/`、`fsl_hypervisor.c`、`nitro_enclaves/`、`steal_governor.c`、`vboxguest/`、`vmgenid.c` ⇒ **无 gunyah** | `[直证]` <https://api.github.com/repos/torvalds/linux/contents/drivers/virt?ref=master> |
| b | `GET .../contents/drivers/virt/gunyah?ref=master` | **HTTP 404 `Not Found`** | `[直证]` <https://api.github.com/repos/torvalds/linux/contents/drivers/virt/gunyah?ref=master> |
| c | `drivers/virt/Kconfig` 原文全文 | 只有 `VMGENID` / `FSL_HV_MANAGER` / `STEAL_GOVERNOR` + `vboxguest`/`nitro_enclaves`/`acrn`/`coco` 的 `source` 行；**无 `GUNYAH` 符号、无 `source "drivers/virt/gunyah/Kconfig"`** | `[直证]` <https://raw.githubusercontent.com/torvalds/linux/master/drivers/virt/Kconfig> |

> `[解读]` 三证互相独立（目录列表 / 路径存在性 / 接线文件正文）⇒ **上游没有 gunyah 驱动**，与 `gunyah-lane-20261126.md` §2 F6 **一致**；本轮把证据强度从"cgit 页面渲染"升到"API 目录项 + 404 + Kconfig 正文"。

### 1.2 linux-next：同样没有（内容级目录项）

`[直证]` <https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/tree/drivers/virt> 的 tree 表逐行为：
`Kconfig(2111)`、`Makefile(353)`、`acrn/`、`coco/`、`fsl_hypervisor.c(23598)`、`nitro_enclaves/`、`steal_governor.c(7953)`、`vboxguest/`、`vmgenid.c(4517)` ⇒ **无 gunyah**。
（GitHub 无 `next/linux-next` 镜像：`/repos/next/linux-next/contents/...` 返回 404，故 linux-next 走 kernel.org cgit tree 表——仍是**目录项级**，不是标题级。）
`[解读]` 与 1.1 交叉：torvalds 与 linux-next 条目集合逐字相同 ⇒ "**连 next 都没有人排**"。

### 1.3 `gunyah_wdt`：在（D19 结论仍成立）

`[直证]` <https://raw.githubusercontent.com/torvalds/linux/master/drivers/watchdog/Makefile> 原文含：

```
obj-$(CONFIG_GUNYAH_WATCHDOG) += gunyah_wdt.o
```

（位于 ARM 段，`obj-$(CONFIG_MARVELL_GTI_WDT)` 与 `obj-$(CONFIG_MA35D1_WDT)` 之间。）
`[解读]` ⇒ 该驱动**在主线**，"上游化"这件事没有可做的对象；其 resume 修正（2026-11-09）也已 mainlined（见 1.4 第 1 条）。

### 1.4 在审系列 / 维护者入口：**零**

| 检查 | 结果 | 证据 |
|---|---|---|
| patchwork 项目 **linux-virtualization**，`q=gunyah`，按日期倒序 | **HTTP 200，返回 `[]`（空数组）** ⇒ 该项目 gunyah 系列数 = **0** | `[直证]` <https://patchwork.kernel.org/api/1.2/series/?project=linux-virtualization&q=gunyah&per_page=10&order=-date> |
| patchwork 项目 **linux-arm-msm**，`q=gunyah`，最新 20 条 | 最新三条：① `watchdog: gunyah_wdt: Re-enable the watchdog on resume`（2026-11-09）② `firmware: qcom: scm: Detect Gunyah by Qualcomm's hypervisor UID too`（2026-11-09）③ `watchdog: gunyah: report system sleep operation failures`（2026-10-08）；其后 2026-03-11 `Add support for Gunyah Watchdog v8`、2026-03-02 `monaco: Reserve full Gunyah metadata region`。**无 `drivers/virt/gunyah` 系列** | `[直证]` <https://patchwork.kernel.org/api/1.2/series/?project=linux-arm-msm&q=gunyah&per_page=20&order=-date> |
| lore 全文 `q=gunyah` 最新条目 | 第 1 条 = `[PATCH 7.3 0733/1005] watchdog: gunyah_wdt: Re-enable the watchdog on resume`（Greg Kroah-Hartman，7.3-stable 队列），正文是 `gunyah_wdt_enable()` 拆分（suspend/resume 修正），**与 `drivers/virt/gunyah` 无关** | `[直证]` <https://lore.kernel.org/all/?q=gunyah&x=A> |

> `[解读]` **近 3 个月 gunyah 动作全在外围**：watchdog 的 resume/休眠失败上报、SCM 的第二 UUID 探测、DTS 元数据保留区、EL1 DT 整理。**driver 侧零动作**，这与 `gunyah-lane-20261126.md` §2 F11（driver 系列最后一代 = 2024-02-22 v17）**一致**。所谓"没有维护者入口"，内容级表现就是：**没有在审系列、没有 patchwork 项目归属、没有树内目录**。
> 盲区如实标注：patchwork 只覆盖有项目映射的列表；若有人只投 lkml 则不进 patchwork。但 lore 全文检索（覆盖 lkml）同样未见 2026 年的 `Drivers for Gunyah` 系列，两源独立且同向。

---

## §2 问题 2：本机素材现状（含"能否从公开源重取"）

### 2.1 仓内素材：在

| 路径 | 状态 | 证据 |
|---|---|---|
| `reference/gunyah-refs/g612/` | **在**（18 文件）；`Kconfig` 原文含 `config GUNYAH` / `GUNYAH_PLATFORM_HOOKS` / `GUNYAH_QCOM_PLATFORM` / `GUNYAH_IRQFD` 等完整符号 | `[直证]` 本轮实际打开 `reference/gunyah-refs/g612/Kconfig` |
| `reference/gunyah-refs/g612/urls.txt` | **在**，17 条下载 URL 全部指向 `android.googlesource.com/kernel/common/+/refs/heads/android16-6.12/drivers/virt/gunyah/<file>?format=TEXT`（含 `gunyah_qtvm.c`、`vm_mgr_mem.c`、`vm_mgr_cma_mem.c`、`trace_vcpu.h`、`Kconfig`、`Makefile`） | `[直证]` 本轮实际打开该文件 |
| `tools/gunyah-modules/` | **在**：`hypprobe/`（`arm_smccc_smc(0x02000609)` 只读探针 + HBI/DTBO hexdump）、`dtbo/`（`of_overlay_fdt_apply` 正式件）、`rmtest/`（`open("/dev/gunyah")` + `GUNYAH_CREATE_VM` 一次真实 RM RPC） | `[直证]` 读 `tools/gunyah-modules/README.md`（并记：构建/部署走 `scripts/gunyah-rm-bringup.sh`，前置 = 板 DTB 带 `__symbols__`，`patches/gunyah/0001-…dtc-symbols.patch`，PITFALLS #389） |

### 2.2 移植树 / 产物：**已删**（本轮直接命中 ENOENT）

| 路径 | 结果 |
|---|---|
| `build/gunyah-port/drivers/virt/gunyah/vm_mgr.c` | `ENOENT: no such file or directory` `[直证]` |
| `out/gunyah-73/vm_mgr.ko` | `ENOENT: no such file or directory` `[直证]` |
| `build/daily/drivers/virt/gunyah/Kconfig` | `ENOENT` `[直证]` ⇒ **日常线树里确实没有 gunyah 源** |
| `build/daily/drivers/virt/Makefile` 全文 | 只有 `fsl_hypervisor.o` / `vmgenid.o` / `vboxguest/` / `nitro_enclaves/` / `acrn/` / `coco/`，**无 `obj-$(CONFIG_GUNYAH) += gunyah/`** `[直证]` |

> 与 `gunyah-lane-20261126.md` §2 F13 **一致**（11-25 磁盘清理删 `build/` 链接产物）。**结论：日常线不含 gunyah，不是 `.config` 的问题，是树里没有源、Makefile 里没有接线。**

### 2.3 能否由公开源重新取：**能，且有多条独立路径**（内容级验证）

| 源 | 可达性 | 内容级证据 |
|---|---|---|
| **piano**（`yzddmr6/linux-sm8750`，分支 `piano/v1.2-features`） | ✅ 在 | `[直证]` 分支表含 `piano/v1.2-features` → `ff6cf0aafb8fd28c464c90e6fe9419960911f3a6`（与 `gunyah-73-port-20261112.md` 所用 commit **逐字相同** ⇒ 该树未漂）；`/contents/drivers/virt/gunyah?ref=piano/v1.2-features` 返回 **18 项**，含 `gunyah.c`(3144 B)、`gunyah_vcpu.c`(17852)、`rsc_mgr.c`(28239)、`rsc_mgr_rpc.c`(21148)、`vm_mgr.c`(33296)、`vm_mgr_mem.c`(26753)、`vm_mgr_cma_mem.c`(11823)、`vm_mgr.h`(12330)、`gunyah_qtvm.c`(6809)、`gunyah_qcom.c`(6472)、`gunyah_platform_hooks.c`(3172)、`gunyah_vendor_hooks.h`、`trace_vcpu.h`、`Kconfig`(1910)、`Makefile`(523) |
| **iceland**（`mzakamin-hub/iceland-linux`） | ✅ 在，**且已推进到 v7.4-rc1** | `[直证]` 分支表含 `iceland-7.4-rc1` → `63570e2c53ea8a8ff4689f84af3962686b0022fe`，commit 日期 **2026-11-14T10:23:39Z**（作者 `mzak`）；`patches/0014-q90m/` 仍在该队列内（gunyah 整栈 import 系列）；README 原文：queue **q91n**、kernel release `7.4.0-rc1-iceland-00743-g06b3ff1eede5`、`patches/0028-q91/ … /0040-q91n/` |
| **AOSP**（`android.googlesource.com` `android16-6.12`） | 配方在仓（`?format=TEXT` 逐文件取） | `[直证]` URL 清单 = `reference/gunyah-refs/g612/urls.txt`；本轮未逐条 HTTP 验证，见 §7 风险 1 |

> `[解读]` **素材完全可再生**，本地 tar（`out/gunyah-modules-gunyah1.tar.gz`）不是唯一来源 ⇒ 任何"重启"都**不被素材可用性阻塞**，只被"值不值得"阻塞。
> 附带新事实（`[直证]` + `[解读]`）：iceland 的分支/队列形态（`iceland-7.3-rc6-q89b…q89g`、`rc7-q89e/f/g`、`iceland-7.4-rc1` + `q91…q91n`，每队列一 tag，README 逐队列列"自上一队列新增什么"）表明**这套 out-of-tree 栈每个内核版本被第三方重放一次**。这既是"重放成本真实存在"的旁证，也是"我们可以只取件、不自己维护"的依据。

---

## §3 问题 3：二值结论 + 成本

### 3.a out-of-tree 移植树长期维持的成本

**规模（直证数字）**：piano `drivers/virt/gunyah/` **18 文件**，按 GitHub API 报的 `size` 求和 ≈ **184 KB**（主体段落 3–33 KB）；另加 `arch/arm64/gunyah/`（hypercall + timer 两层）、`include/linux/gunyah.h`、`include/linux/gunyah_qtvm.h`、`include/uapi/linux/gunyah.h`、`arch/arm64/include/asm/gunyah.h`。`[解读]` 按 40–60 B/行估 ≈ **5k–6k 行**（仅量级，不作精确值）。

**7.3.1 上的真实代码改动只有 1 处**：`vm_mgr.h` 的 `vma_interval_tree_foreach` → `mapping_rmap_tree_foreach`（`gunyah-73-port-20261112.md` §2.1）。其余全是"拷文件 + 接线"：4 个头文件拷入、Kbuild 3 处（`drivers/virt/Kconfig`、`drivers/virt/Makefile`、`arch/arm64/Kbuild`）、`.config` 9 项 `=m`、以及因 `SYS_HYPERVISOR=y` 打开而**重链一次 vmlinux**（`hypervisor_kobj` 未导出 ⇒ modpost `symbol undefined`）。

**每升一级内核的固定支出**（`[解读]`，依据 re-port 记录 + 项目既有坑）：
1. 重放 API 适配（7.2→7.3 = 1 处；典型 0–5 处，`folio`/`rmap`/`kmap_local`/`of_fwnode_handle`/`android_kabi` 类漂移）—— 0.1–0.3 人日；
2. 重编 10 个 `.ko` + **整套模块树部署**（UTS/vermagic 耦合；项目硬规则：RAM 起新核前必须部署整套 `/lib/modules/<UTS>`）—— 0.2 人日 + 设备窗；
3. 每次验证都要**设备窗**（稀缺资源：D19「hang 只能物理 POR」正在流血，APSS watchdog 读回排在前面）。
⇒ **每级内核 ≈0.3–0.5 人日 + 1 设备窗**。日常线还在滚（在机 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`）⇒ 这是**周期性**支出，不是一次性。

**外部旁证**（`[直证]` + `[解读]`）：iceland 每内核重做一版（`q89b…q90v`、`rc6/rc7`、`q91…q91n` 至 `v7.4-rc1`），说明重放确有其事；同时说明**这件事有第三方在做**，我们不必自建。

### 3.b 等上游的成本与不确定性

- **节奏**：driver 系列 v10（2023-02）→ v15（2023-12）→ **v17（2024-02-22，最后一版）**；其后 **2 年零新版本**（`gunyah-lane-20261126.md` §2 F11 系列史 + 本轮 §1.4 复核）。
- **2026 年 gunyah 全部动作 = 外围**：watchdog（已 mainlined）、SCM 第二 UUID（`state=new`，未合入）、DTS 元数据保留区、EL1 DT 整理（上游只碰 DT/固件侧，**不碰 `drivers/virt/gunyah`**）。
- **即便明天合入，也不解决本机**（`[解读]`，依 2026-10-25 裁决链 + `gunyah-b15-iceland-rmdrv-20261113.md` §2 反汇编）：本机 `VM_INIT` 恒 `0xA MEM_INVALID` 的病因指向**固件 RM 世代**——stock `gh_rm_drv.ko` 用 `MEM_DONATE 0x51000010` 与老 boot 流程 `0x56000009/0a`，**完全不用**主线 boot-context 流程的 `0x56000032/33/34`，且带 `gh_feature_use_scm_assign` 回退；`gunyah_loader` 的 `hvc #0x6045…` 族也不在主线。⇒ **"上游有驱动" ≠ "本机能建 VM"**。
- **不确定性量化**（`[解读]`）：给定"2 年零新版 + 无 patchwork 项目归属 + 无树内目录"，等上游的期望值 ≈ **0**；且等待期间日常线继续滚核，等到那天还要重新取件。

### 3.c 本地等价替代（真目的 = 跑子 VM）——只核对是否仍成立，不重论证

| 路线 | 门槛 | 现状（本轮核对） |
|---|---|---|
| **KVM（EL1 host 常规）** | 需要 EL2 | ⛔ 本机 EL2 = **签名 Gunyah**（dmesg `gunyah-hyp@80000000` nomap 保留区；`qcom_scm` 的 gunyah UUID 探测命中 ⇒ 平台设备 `gunyah-wdt` 存在 —— 设备事实沿用 `gunyah-lane-20261126.md` §2 F4），hyp 加载点在 ABL 之上 ⇒ 主线 `-el2.dtb` overlay 只适用 Qualcomm dev kit，重签 ABL 也救不了 ⇒ **不可达**（Q4 ①，**仍成立**）。主线侧也无"KVM 跑在 Gunyah 上"的后端：`arch/arm64/kvm` 目录项中**无 gunyah 文件**（`[直证]` <https://api.github.com/repos/torvalds/linux/contents/arch/arm64/kvm?ref=master>：`arm.c/arch_timer.c/at.c/config.c/debug.c/emulate-nested.c/fpsimd.c/guest.c/handle_exit.c/hyp/…/pkvm.c` …） |
| **KVM-in-EL1 + Gunyah backend（Linaro RFC 2025-04）** | 需 WIP 系列 + `qemu-for-gunyah` | ⛔ Q4 记「KVM 维护者 2025-04-24 明确拒绝，RFC 停 v0」；`gunyah-lane-20261126.md` §4.3 已把「唯一新路线 = KVM-in-EL1」列为**作废口径** ⇒ **仍不成立** |
| **PKVM（protected KVM）** | pKVM 自身必须占 EL2 | ⛔ **不可达** `[推断]`（依据：pKVM 是 EL2 层 + 本机 EL2 已被 Gunyah 占）。此条为架构推断，未做上机实验，也不建议做。 |
| **Waydroid / redroid（G2）** | 容器 | ✅ 已在线。覆盖"跑安卓应用"，**不覆盖**"本机跑 Linux/Windows 子 VM" |
| **Box64 + Wine/Proton（G3）** | 用户态翻译 | ✅ 已在线。覆盖 x86 游戏，**不覆盖**子 VM |

> `[解读]` **用户真实目的里，"跑子 VM"这一支没有任何可达路径**（gunyah 驱动不可行、KVM/PKVM 不可达、上游不接收）；可达的两支（G2/G3）**已在主线上且与 gunyah 无关**。这才是"不必投"的根本理由——不是舍不得 1.25 人日，而是投完不产生任何可达能力。

### 3.d 二值结论

**不做**（含"不进日常线"：日常线应保持"纯净上游 7.3.1 + 项目必要本地补丁"，`drivers/virt/gunyah` 属"无接收面 + 无收益 + 周期性支出"的 out-of-tree 负担，不应进入）。

---

## §4 建议：不做 / 等——止损判据与复盘口径（写死，防下轮重复判）

### 4.1 止损判据（任一成立才允许重开，且**必须先跑 §6 的三条只读命令**）

- **R1（上游出现接收面）**：torvalds 或 linux-next 的 `drivers/virt/` **目录项里出现 `gunyah`**（§6 命令 1：`/contents` 返回目录列表而非 404；或 `drivers/virt/Kconfig` 出现 `source "drivers/virt/gunyah/Kconfig"`）；**或** linux-virtualization patchwork 出现 `drivers/virt/gunyah` 系列且 state ∉ {superseded, rejected}。
- **R2（本机固件换代）**：`backup/stock-elden/vendor_ramdisk/gh_rm_drv.ko` 反汇编出现 `0x56000032/33/34`，或不再用 `0x51000010 MEM_DONATE`（= 2026-10-25 裁决 §6 条件 1，**未变**）。
- **R3（用户改需求）**：用户明确「必须在**本机**跑 Linux/Windows 子 VM」且 Waydroid/Box64 都覆盖不了（= C3，**至今未确认**）。

三条全不成立 ⇒ **维持"不做"**：不开论证、不排设备窗、不重建移植树。

### 4.2 复盘口径（下一轮只允许这样判）

1. **只跑 §6 的 3 条只读命令**（上游目录 / patchwork 系列 / 设备 `dmesg`+`/dev/gunyah`）；全负 ⇒ 直接引本文件 §0 表结案，**不许重开成本评估**。
2. **禁止**再以「`gunyah_wdt` 解 D19 hang」立项（2026-11-25 上机否证：`GUNYAH_WDT_STATUS` 秒数恒 0、停喂 45 s 不复位 ⇒ hyp 侧空实现；且该驱动已在主线）。
3. **禁止**拿「设备上还有 8 个 `gunyah*.ko`」当"有可用栈"的证据（`gunyah-lane-20261126.md` §2 F5：11-17 部署、`lsmod` 0 命中、无 `/dev/gunyah`、无加载钩子）。
4. 若 R1 成立 ⇒ **改用 iceland 当前队列取件**（`iceland-7.4-rc1` + `patches/0014-q90m/`），**不再自建移植树**、也不再从 g612 起（`gunyah-s1-static-diff-20261111.md` 已证 g612 有 APPEND/unpin 真 bug）。
5. 改判必须**同时**给「上游内容级证据 + 本机固件侧证据」，缺一不得改判（防"看到 RFC 标题就以为要进主线"，参见 `gunyah-lane-20261126.md` §2 F12 的保守判读）。

---

## §5 若将来"做"：最小任务分解（**仅备档，不派发**）

> 触发前提：R1 成立，且 R2/R3 至少一条成立。

**Step 0 — 重建移植树（0.5 人日，零设备）**
- 路径 A（推荐，代次最新 = android17-6.18 / 7.4）：
  ```bash
  git clone --filter=blob:none --sparse https://github.com/mzakamin-hub/iceland-linux /tmp/iceland-gunyah
  cd /tmp/iceland-gunyah
  git checkout iceland-7.4-rc1 -- patches/0014-q90m patches/0015-q90n patches/0016-q90o \
      patches/0018-q90q patches/0020-q90s patches/0022-q90u patches/0023-q90v
  # 目标树按序 git am；iceland README 的 scripts/prepare.sh 是同一套流程
  ```
- 路径 B（与 2026-11-12 记录逐字同源，便于对账）：
  ```bash
  git clone --depth 1 -b piano/v1.2-features --filter=blob:none --sparse \
      https://github.com/yzddmr6/linux-sm8750 /tmp/piano-gunyah   # HEAD 应 = ff6cf0aafb8fd28c464c90e6fe9419960911f3a6
  cd /tmp/piano-gunyah && git sparse-checkout set \
      drivers/virt/gunyah include/linux include/uapi/linux arch/arm64/gunyah \
      arch/arm64/include/asm drivers/watchdog
  ```
- 判据：`make drivers/virt/gunyah/` **0 error / 0 warning**；10 个 `.ko` 的 vermagic 与在机 `uname -r` **逐字相同**；`modinfo` 无 unresolved symbol（`hypervisor_kobj` 需 `SYS_HYPERVISOR=y` **且**已重链 vmlinux）。

**Step 1 — 只读读回 hyp 世代（0.25 人日 + 设备窗 30 min）**
- 判据：`/dev/gunyah` 出现；`dmesg | grep -i "Running under Gunyah"` 得到 `NN/vN`（iceland/piano 实测 `51/v1`；本机值未知，**这比 msg-id 更直接**）。

**Step 2 — C2 二值（0.5 人日 + 同一设备窗）**
- 判据三态（必须能区分）：`gh_vmtest` 的 `VM_START = 0` ⇒ C2 真（才进 Step 3）；`0xA` + 违规 DTB 变 `8 VALIDATE_FAILED` ⇒ DTB 轴复活；`0xA` 且违规 DTB 仍 `0xA` ⇒ **永久关闭**（把 10-25 结论钉死）。
- 风险自限（不变）：单进程、`GVM_HUGEPAGES` 默认、**不要 `fork()` 持 LEND 页**（iceland 实测同步 external abort 挂机）、不在无人循环里跑。

**Step 3 —（仅当 C2 真）接 crosvm-gunyah 起最小 guest（2–3 人日）**
**Step 4 —（仅当 R1 成立）把取件结果按模块拆成可 review 素材（1.5–2 人日；`vm_mgr`/`vm_mgr_mem` → `rsc_mgr*` → `qtvm`；`gunyah_qcom`/`platform_hooks` 不进包）**

**合计（Step 0–2）= ≈1.25 人日 + 1 个设备窗**，且必须排在 D19 的 APSS watchdog 读回**之后**（设备窗冲突时，流血项优先）。

---

## §6 复现命令（只读）

```bash
# 1) 上游「有没有」——三处都必须是「无」
curl -sS --max-time 20 'https://api.github.com/repos/torvalds/linux/contents/drivers/virt?ref=master' | grep -c '"name": "gunyah"'   # 0
curl -sS --max-time 20 -o /dev/null -w '%{http_code}\n' 'https://api.github.com/repos/torvalds/linux/contents/drivers/virt/gunyah?ref=master'  # 404
curl -sS --max-time 20 'https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/tree/drivers/virt' | grep -c gunyah   # 0
curl -sS --max-time 20 'https://raw.githubusercontent.com/torvalds/linux/master/drivers/virt/Kconfig' | grep -c -i gunyah          # 0

# 1b) gunyah_wdt 仍在主线（应命中 1 行）
curl -sS --max-time 20 'https://raw.githubusercontent.com/torvalds/linux/master/drivers/watchdog/Makefile' | grep gunyah_wdt

# 2) 在审系列（应为空数组 / 无 virt-gunyah 系列）
curl -sS --max-time 20 'https://patchwork.kernel.org/api/1.2/series/?project=linux-virtualization&q=gunyah&per_page=10&order=-date'
curl -sS --max-time 20 'https://patchwork.kernel.org/api/1.2/series/?project=linux-arm-msm&q=gunyah&per_page=20&order=-date' | grep -c '"name": "Drivers for Gunyah'   # 0

# 3) 本地：移植树/产物不存在；素材在；日常线树内无 gunyah
ls -d build/gunyah-port out/gunyah-73 2>&1        # 两个 No such file or directory
ls reference/gunyah-refs/ tools/gunyah-modules/ patches/gunyah/
ls build/daily/drivers/virt/gunyah 2>&1           # No such file or directory
grep -c -i gunyah build/daily/drivers/virt/Makefile build/daily/drivers/virt/Kconfig   # 0 / 0

# 4) 公开源仍可取
curl -sS --max-time 20 'https://api.github.com/repos/yzddmr6/linux-sm8750/branches?per_page=20' | grep -A2 'piano/v1.2-features'
curl -sS --max-time 20 'https://api.github.com/repos/yzddmr6/linux-sm8750/contents/drivers/virt/gunyah?ref=piano/v1.2-features' | grep -c '"name"'
curl -sS --max-time 20 'https://api.github.com/repos/mzakamin-hub/iceland-linux/contents/patches?ref=iceland-7.4-rc1' | grep -c 'q90m'

# 5) 设备侧（只读；R1/R2 判定时跑）
timeout -k 5 20 ssh -o BatchMode=yes elden-root 'uname -r; ls -l /dev/gunyah; dmesg | grep -i gunyah | head; ls /sys/bus/platform/devices | grep gunyah'
```

---

## §7 残余风险 / 未验证（如实）

1. **AOSP `android16-6.12` 的 URL 未逐条 HTTP 验证**：本轮只确认仓内 `urls.txt` 的配方形态 + piano/iceland 两条 GitHub 源可达且内容在。真要取 AOSP 原件，先 `curl -o /dev/null -w '%{http_code}'` 验一条。
2. **linux-next 用的是 cgit tree 表，不是 `git ls-tree`**：语义等价（目录项枚举），但不是本地 git 命令；要"最硬"证据可在主机补 `git ls-remote` + 浅树 `git ls-tree`。
3. **patchwork 覆盖盲区**：只覆盖有项目映射的列表；只投 lkml 会漏。本轮用 lore 全文检索做第二源，两源同向，但仍不能证明"绝对没有私下排队"。
4. **iceland 各分支提交时间未逐个核**：只核 `iceland-7.4-rc1` HEAD = `2026-11-14T10:23:39Z`（README 的 q91n 说明）。"每内核重放一次"是由分支命名 + README 队列表推出（`[直证]`+`[解读]`），未做 git log 直证。
5. **设备侧未重新采**：`gunyah-hyp@80000000` 保留区、`gunyah-wdt` 平台设备在/未绑、无 `/dev/gunyah` 等，全部沿用同日 `gunyah-lane-20261126.md` §2 F4/F5（同日、只读；可信但非本轮亲测）。
6. **本机 hyp 版本 `NN/vN` 与 `/dev/gunyah` 是否存在仍未知**：这是 Step 1 的唯一目的；说明"本机 RM 世代"这条**只能靠设备窗证伪/证实**（10-25 / 11-11 / 11-13 / 11-26 四轮已把能静态判的判完，本轮静态面再次确认到顶）。
7. **`out/`、`backup/` 未做目录枚举**（本轮无 shell）：只核了两个已知路径（`build/gunyah-port`、`out/gunyah-73`）的 ENOENT，其余以 `gunyah-lane-20261126.md` F13 的同日清单为准。

---

## §8 来源

- **Kept（直证，本轮亲自抓）**
  - GitHub Contents API：`torvalds/linux` `drivers/virt`（目录项，9 项无 gunyah）/ `drivers/virt/gunyah`（404）/ `drivers/virt/Kconfig`（无 GUNYAH）/ `drivers/watchdog/Makefile`（有 `gunyah_wdt.o`）/ `arch/arm64/kvm`（无 gunyah 后端）——"上游有没有"的硬证据。
  - kernel.org cgit：`next/linux-next.git/tree/drivers/virt`（目录项，无 gunyah）。
  - patchwork API：`linux-virtualization` `q=gunyah` → `[]`；`linux-arm-msm` `q=gunyah` 最新 20 条（外围系列，无 driver 系列）。
  - lore：`?q=gunyah` 最新条目 = 7.3-stable 的 `gunyah_wdt` resume 补丁（外围）。
  - GitHub API：`yzddmr6/linux-sm8750` 分支表 + `drivers/virt/gunyah` 18 项（含各文件字节数）；`mzakamin-hub/iceland-linux` 分支表 + `iceland-7.4-rc1` HEAD commit（2026-11-14）+ `patches/0014-q90m` 在列。
  - 本地文件：`reference/gunyah-refs/g612/{Kconfig,urls.txt}`、`tools/gunyah-modules/README.md`、`build/daily/drivers/virt/Makefile`（无 gunyah 接线）、三个 ENOENT 命中。
- **Kept（仓内既有，作基线，非本轮重证）**
  - `reports/gunyah-lane-20261126.md`（同日静态面：§1 分界、§2 F1–F14、§3-A/B/C）
  - `reports/gunyah-decision-20261025.md`（终局裁决 + §6 复启条件）
  - `reports/gunyah-73-port-20261112.md`（7.3 上唯一真实 API 适配 + 4 处接线）
  - `reports/gunyah-b15-iceland-rmdrv-20261113.md`（本机 `gh_rm_drv.ko` msg-id 表：`0x51000010`/`0x56000009-0a` 在用、`32/33/34` 缺）
  - `TASKS/dim/D21.md`、`TASKS/GAPS.md` Q4 行（C8/Q4：KVM 不可达 + 「唯一新路线」口径已作废）
- **Rejected / deprioritized**
  - LWN 与 patchew 上的 v10–v17 系列页：**仅作历史节奏参考**（2023-02 v10 … 2024-02 v17），不用于"当前在审"判定（陈旧）。
  - qemu 的 Gunyah accelerator RFC（2024-05，Srivatsa）：与内核接收面无关，且自述"NOT YET READY"，不采用。
  - 2026-11-13 `sm8650-el1.dtsi` RFC：`superseded`，且只动 DT ⇒ **不能**推出"virt/gunyah 要进主线"（沿用 11-26 报告的保守判读）。

---

## §9 父代理复核（2026-11-26T06:5xZ，独立重跑，未采信自报）

| 判据 | lane G 自报 | 父代理现跑 | 结论 |
|---|---|---|---|
| torvalds `drivers/virt` 无 gunyah | 目录 9 项、无 gunyah | `curl api.github.com/.../contents/drivers/virt?ref=master \| grep -c '"name": "gunyah"'` = **0** | 一致 |
| `drivers/virt/gunyah` 路径不存在 | 404 | HTTP **404** | 一致 |
| `gunyah_wdt` 在主线 | Makefile 第 107 行 | `curl raw .../drivers/watchdog/Makefile \| grep` 命中 `obj-$(CONFIG_GUNYAH_WATCHDOG) += gunyah_wdt.o`（首次抓取遇到一次性超时，重试后为 9441 B 全文） | 一致（**注意**：单次 curl 可能拿到截断体，判据必须看重试后的 size） |
| linux-virtualization patchwork `q=gunyah` 无系列 | `[]` | 返回 `[]` | 一致 |
| 日常线树内无 gunyah | `build/daily/drivers/virt/` 无目录、Makefile/Kconfig `grep -c -i gunyah` = 0/0 | 实测同上（目录只有 acrn/coco/nitro_enclaves/vboxguest + 3 个 .c） | 一致 |
| 移植树/产物已删 | `build/gunyah-port`、`out/gunyah-73` ENOENT | 实测两个 `No such file or directory` | 一致 |
| 素材仍在仓 | `reference/gunyah-refs/g612/` 18 文件 | `ls reference/gunyah-refs/g612` 有 Kconfig/Makefile/gunyah.c/… | 一致 |

**父代理裁定（2026-11-26）**：接受 lane G 的结论 = **不做、不进日常线**；止损判据按其 §4.1 R1/R2/R3，复盘口径按其 §4.2。
本条不改 `TASKS/GAPS.md` Q4、`TASKS/NEXT.md` D21 的既有 ✅ 状态；D21 增一行指针指向本文件（父代理同轮补）。
