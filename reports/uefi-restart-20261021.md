# UEFI 间接引导（G1-29）是否值得重启 — 2026-10-21

> 只读研究 + 规划。**本 lane 未做任何设备写操作**（设备停留 fastboot `HA2EXB0E`，全程仅主机侧读文件/检索）。
> 基线文档：`TASKS/README.md` §1 G1-29/G1-30 行、§5 Q25 行；`archive/topics/{BOOTCHAIN,UEFI-UFS-BRINGUP,UEFI-UFS-UPSTREAM-ASK}-2026-10-05.md`；
> 前一轮复查 `archive/plans-archive-2026-10-13/research-uefi-boot-2026-10-09.md`（**已定案部分本文只做确认/推翻**）。
> 证据等级：【已证实】= 本地文件/命令输出或可复核的上游页面；【未证实】= 有线索无定论；【推测】= 推理。

## 0. 结论先行（TL;DR）

> 状态：本节与 §B/§C/§D 由编排者在 lane 被强制收尾后**基于 §A 已取证据**补写（lane 原跑 70 min 仍在检索，进度停在 §A）。§A 全部为 lane 实测；§B/§C/§D 为编排者综合，缺证据处标【推测】。

1. **不建议现在重启 UEFI 路线（维持搁置）。** 两个独立理由：① 复起的**前置成本已不是 0**——`mu_wide_platforms`（1.0 G）、`uefi-firmware-backup`（1.3 G）、`edk2-*`（1.5 G）、7 个实验镜像**全部不在盘**（§A.1，换机未随迁，需重下 + 重建 clang-21/nuget 工具链）；② 阻塞**至少两层**：`0x402` 那条运行期注册表解引用（未映射 `0xD6ABB030`）**加上** `UFS.c+2326` 的 `UFSSmmuConfig` 失败（§A.2），修好前者仍撞后者。
2. **Q25 的原待办作废**：`0x402` 不是 `PlatformConfigurationMapLib` 的 config tag，是运行期注册表条目类型字段（§A.2）。同时 `CPU_Vectors` 已被上游 2026-08 删除、`UsbBusStart` 与本问题无关（§A.3）⇒ `TASKS:40` 的三项并列口径应予更正。
3. **收益侧已归零**：96 MiB 限制早由 G1-30/vk61 解决；UEFI 现在只提供「GRUB 菜单/多内核选择」，而**同样的能力 kexec 用 ~40 行补丁 + 6–8 轮零写盘就能拿到**（`reports/kexec-plan-20261021.md` §E）。**替代优先级：kexec > U-Boot > UEFI**（§C）。
4. **若将来重启，第一件事不是编译而是取证**：上游 issue #12 的答复是「固件版本相关」，需要的是**本机原厂 `uefi.elf`/`abl.elf` 里那份运行期注册表结构**的逆向（`~/下载/tb322fc/` 在盘，§A.1），不是再重下 1 G Mu 源码。
5. **本轮唯一可立即落地的产出**：把 §A.2 的 `0x402` 结论回帖到上游 issue #12（对方在等我们确认「不是 config tag」这一层），成本 10 分钟，不依赖任何重下。

## A. 失败层级精确化

### A.1 本机源码/二进制可用性（前置事实）

**结论：Mu 源码树在本机已不存在，全部需重下（1.0 G + 1.3 G）。这是复起的第一个实际成本，此前无人记录。**

| 资产 | 2026-10-05 状态 | 现在（2026-10-21） | 证据 |
|---|---|---|---|
| `mu_wide_platforms/`（fork `xiaquwan1001`） | 已落盘 1.0 G，含 `Platforms/PakalaPkg/Device/lenovo-y700g4/`（391 文件） | **不存在** | `ls -d ~/mu_wide_platforms` → `No such file or directory`；`find / -iname "*mu_wide*" -o -iname "MU_BASECORE*" -o -iname "*Pakala*" -o -iname "edk2*"` 全盘（`-xdev` + `/home /opt /srv /mnt`）**0 命中**；`.gitignore:19 /mu_wide_platforms/` ⇒ 从未入 git |
| `uefi-firmware-backup/` | 已落盘 1.3 G | **不存在** | 同上 find 0 命中 |
| `edk2-aarch64-gunyah` / `edk2-*` | 1.5 G（Gunyah 用） | **不存在** | 同上 find 0 命中；`.gitignore:16,17,103` |
| `out/local-exp/expB-ufs-unpatched.img` 等 7 个实验镜像 | 已产出（§4 矩阵） | **不存在** | `ls out/local-exp out/local-scale3` → `No such file or directory`；`out/` 只剩 `.manifest`（与 `RESOURCES/README.md:347` 的 MIGRATION-LOST 口径一致） |
| 原厂固件包 `~/下载/tb322fc/` | — | **在**（`uefi.elf` 5 242 880 B、`imagefv.elf` 2 097 152 B、`abl.elf` 1 048 576 B、`tools.fv` 1 048 576 B、`boot.img` 100 663 296 B） | `ls -la ~/下载/tb322fc/`；`scripts/grubfat-inspect.sh ~/下载/tb322fc/` 逐个解析成功（见 A.2） |
| 2026-10-05 的完整会话记录（含反汇编、补丁 diff、A–G 矩阵） | — | **在**（`.pi/sessions/2026-10-05T06-05-48-388Z_01a10aab-…jsonl`，2 719 092 B，27 处命中 `0x402`/`13120`/`228d8`） | 本文 A.2/A.3 的原始取证即从此文件复核（本轮重新下载二进制独立复算，见下） |

> 口径更正：`RESOURCES/README.md:347` 已把 `mu_wide_platforms` 归入「LOST-REDOWNLOADABLE」。**这意味着复起 UEFI 的「0 成本」前提不成立**——先要重下 1.0 G 源码 + 重建工具链（clang-21/nuget/mono 那套，见 `.pi/hermes-memory-mirror/MEMORY.md:15`），再重编 2m59s。

### A.2 UFSDxe ASSERT 的代码位置（本轮独立复算，非引用旧结论）

**方法**：从上游 `sunflower2333/mu_wide_platforms`（`main` 分支）重下 `PatchedBinaries/UFSDxe.efi` 与 `Binaries/QcomPkg/Drivers/UFSDxe/UFSDxe.efi`，`llvm-objdump-21 -d` 全量反汇编 + PE 节/重定位自解析。

**二进制身份**【已证实】
- `orig-UFSDxe.efi` 151 552 B，sha256 `dac620ac…`；`patched-UFSDxe.efi` 151 552 B，sha256 `00ae059f…`。
- 二者**只差 3 段、共 32 字节**（`python` 逐字节 diff）：

| 文件偏移 | 长度 | 原版 | 补丁版 | 语义 |
|---|---|---|---|---|
| `0xa998` | 8 B | `83050094 80fdff35` | `210080d2 cd050094` | `bl X; cbnz w0` → `mov x1,#1; bl Y` |
| `0x114c4` | 16 B | `c0000034 f603002a e00313aa e1038052` | `e00313aa 01008052 81fcff97 03000014` | `cbz w0; mov x22,x0; …` → `mov x0,x19; mov w1,#0; bl; b` |
| `0x1b080` | 8 B | `ff0301d1 fd7b01a9` | `00008052 c0035fd6` | 函数序言 → `mov w0,#0; ret`（**整函数打桩**） |

- PE 结构：`.text` RVA `0x1000`/size `0x1f000`、`.data` `0x20000`、`.reloc` `0x24000`；**RVA == 文件偏移**（`.text` 起 `0x1000`）⇒ 上表偏移可直接当 RVA 读反汇编。
- 补丁点**不在**崩溃点（`0x13224`）上 ⇒ **崩溃发生在原版代码里，不是补丁改出来的指令**。【已证实】

**`UFS.c +2326` ASSERT 的精确位置**【已证实】
- 全 `.text` 中 `mov w1, #0x916`（=2326）**只有一处**：`0x42f4`。
- 该处上下文（`llvm-objdump` 输出行 3268 附近）：

```
42e8: adrp x0, 0x1b000 ; 42f0: add x0, x0, #0x438   -> x0 = "UFS.c"     (RVA 0x1b438，实测字符串)
42f4: mov  w1, #0x916                            -> 行号 2326
42f8: add  x2, x2, #0x14e                          -> x2 = RVA 0x1c14e
42fc: bl   0x7608                                  -> ASSERT 打印例程
```
- RVA `0x1c14e` 的字符串实测 = **`!EFI_ERROR (((RETURN_STATUS)(0x8000000000000000ULL | (7))))`** ⇒ `Status = 0x8000000000000007 = EFI_DEVICE_ERROR`，与日志 `ASSERT_EFI_ERROR (Status = Device Error)` + `ASSERT UFS.c +2326` **逐字对上**。
- 该 ASSERT 的前置分支：`0x42c0` `mov w1,#0xd0` → `bl 0xa910`（分配 208 B）→ `str x0,[x19,#0x890]` → `cbz` → `bl 0xaacc(x0, sp+0x98)`；`w0 != 0` 即跳到 `0x4310` 打 `UFSSmmuConfig failed`（RVA `0x1c073` 实测字符串），随后 `0x4324`–`0x4338` 打 `UFS.c+2331` 的第二条 ASSERT。
- ⇒ **2326 这条 ASSERT 的直接含义 = 「208 B 的 UFS 上下文/配置块拿不到或 SMMU 配置失败」**，不是 UFS 协议层错误。这与日志里 `ufs_error_log: 11 / 3b / 55` 是**两个不同层**：`ufs_error_log` 来自另一条路径（字符串在 RVA `0x1e045`，调用点未逐一符号化，【未证实】其三个值语义）。

**`0x402` 是什么（Q25 原问题）**【已证实为「不是 PlatformConfigurationMapLib 的 tag」】
- 崩溃函数 = `0x13120`（唯一调用者 `0x12e94`）；崩溃指令 = `0x13224 ldr x9,[x0,#0x8]`，`x0` 由 `x20+4..+7` 的 **4 字节小端** 值零扩展而来（`0x13204`–`0x13218`），`0x1321c cbz w0` 保证非零。
- `0x131f4: cmp w12, #0x402` 中的 `w12` 同样由 `x20+0..+3` 4 字节小端拼出 ⇒ 这是 **`x20` 指向的运行时结构体的首字段**，不是配置表 tag。
- `x20` 的来源：`0x13174 mov x0,x21; bl 0x6cc8`；`0x6cc8` 实测为
  ```
  6cd4: adrp x8,0x22000 ; 6ce4: ldr x8,[x8,#0x8d8]  -> 全局对象指针 .data:0x228d8
  6ce8: ldr x8,[x8,#0x40]                          -> 取 vtable 方法
  6ce0: mov w0,#0x4                                -> 第 1 参数 = 4
  6cec: blr x8                                     -> 调 method(4, key, &out)
  ```
- **`.data:0x228d8` 在文件里是 0，且不在 92 条 DIR64 重定位目标内** ⇒ 它是**运行期由本模块写入**的全局（写入点实测只有 `0x89cc: str x8,[x9,#0x8d8]`）。
- 而 `0x6cc8` 的「`w0=4` + `&out` + 返回指针」形状，与 `Silicon/Qualcomm/QcomPkg/Library/ConfigurationMapHelperLib/ConfigurationMapHelperLib.c` 的 `LocateConfigurationEntry32(EntryName, EntryValue)` **不匹配**（后者取 `char*` 名字，不是 `4`）⇒ **`0x402` 与 `PlatformConfigurationMapLib` 无关**。
- 【推测，未证实】`0x402` 是某个 Qcom 运行期注册表（`w0=4` 为表 ID）里一个条目的类型字段；该条目 `+4` 的 32 位字段被当指针解引用，值 `0xD6ABB030`（日志 FAR=`0xD6ABB038`）在 Mu 的内存映射下未映射。

> **对 Q25 的裁决**：Q25 写的「对 `PlatformConfigurationMapLib` 给 UFSDxe 的 config tag `0x402` 解引用做静态定位」**已被本轮推翻**——`0x402` 不是 config tag，`PlatformConfigurationMapLib` 里的条目是 `{"Name", value}` 字符串对（实测 `dodgePkg/Library/ConfigurationMapLib/ConfigurationMapLib.c` 41 条，全部为 `EnableShell`/`NumCpus`/`EnableUfsIOC` 这类**命名键**，无 `0x402`）。**差量**：Q25 那条「静态定位」待办应当作废，替换为 A.3 的分层结论。

### A.3 三条早期错误的归类：配置 vs 代码

> 判据：**「配置」= 换一个表项/一行 PCD/一个 DTB 节点就能改观；「代码」= 需要改/写 C 或二进制补丁。**

| 日志行 | 出处（本轮实测字符串） | 归属 | 依据 |
|---|---|---|---|
| `mbox_os_init: Failed to locate SCM protocol for Mailbox 14` | 该串**不在** UFSDxe（`strings orig-UFSDxe.efi \| grep -c Mailbox` = 0）；UFSDxe 里只有 `Locate SCM protocol failed with return value of 0x%x` | **配置 + 依赖装配** | SCM protocol 是**另一个 DXE 提供的 protocol**，缺失 = 该 DXE 未加载/未发布 protocol，不是 UFSDxe 的 tag 问题。`mbox_os_init` 的 mailbox 编号 14 属平台常量 ⇒ 需先定位「谁该发 SCM protocol」并让它跑起来（装配/APRIORI），或补 mailbox 号（配置）。**两者都不在 UFSDxe 内**。 |
| `ERROR: Fail to init client handle to QBSS clock node` | 该串**不在** UFSDxe（`grep -c QBSS` = 0） | **配置** | NPA/QBSS 时钟节点名是**平台配置数据**（ClockDxe/NPA client 侧）。上游 issue #12 的 Q3 问的正是这个；Mu 侧 `dodgePkg` 的 `ConfigurationMapLib` 无 QBSS 相关键 ⇒ 缺的是**时钟节点描述**，属配置类。 |
| `ERROR: CPU_Vectors region not present in cfg file !` | 该串**不在** UFSDxe（`grep -c CPU_Vectors` = 0），也不在原厂 `uefi.elf`/`imagefv.elf`/`tools.fv` 的明文字符串里（各 0 命中） | **代码（已被上游删除）** | 上游 Mu-Silicium **2026-08-12 `6cb348a80479` “Qcom: Remove CPU Vector Memory Regions”**、v3.9 release note “Removed leftover `CPU Vector` Memory Regions” ⇒ 该 region **在较新的 Mu 里已被有意移除**。⇒ 这条 ERROR 是「用旧 Mu 基线时的时代错位」，**不是要补的缺口**；换新基线即消失（是否真的消失需上机验证，【未证实】）。 |
| `UsbBusStart: Init command not active` | 未在 UFSDxe 中命中 | **未证实** | 与 UFS 无直接关系（USB 栈），历史上被当作「同一批缺失」并列；本轮无新证据，**不应算进 UFS 阻塞**。 |

**分层结论（回答交付项 A）**

1. **UFS 硬阻塞不在 `PlatformConfigurationMapLib` 的 tag 上**（Q25 原假设推翻，见 A.2）。
2. 硬阻塞的直接形态 = `0x13120` 内对**运行期注册表条目 `+4` 的 32 位字段**做指针解引用，值 `0xD6ABB030` 未映射 ⇒ 属**「运行期数据结构/内存映射」层**，而不是「编译期配置表」层。
3. `UFS.c+2326` 的 `EFI_DEVICE_ERROR` 是**第二条独立失败**：208 B 上下文分配后 `SMMU 配置` 失败（`UFSSmmuConfig failed`）。⇒ **即使修好 `0x402` 那条崩溃，仍会撞这条 ASSERT**。这是本轮最重要的新增判断：**阻塞至少两层，不是单点**。
4. `CPU_Vectors` 属**已废弃项**（上游 2026-08 删除），`QBSS` 属**配置**，`SCM mailbox 14` 属**装配/配置**，`UsbBusStart` 与本问题无关。

**与原结论的关系**：`archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md` §5.1「Mu Pakala 移植层系统性缺口，非单点补丁可解」**方向正确、但分层不精确**；`TASKS/README.md:40`「SCM mailbox/QBSS/CPU_Vectors 缺失」把三项并列，其中一项（CPU_Vectors）已被上游删除、一项（UsbBusStart）无关。上游 2026-10-10 回复「固件版本相关，需 UFSDxe 专用补丁」与此**不矛盾**：`0x402` 那条注册表条目很可能就来自「固件版本相关的数据」。

## B. 上游回复之后的真实工作量估计

> 上游 2026-10-10 答复（`archive/topics/UEFI-UFS-UPSTREAM-ASK-2026-10-05.md` §回复）=「固件版本相关，需 UFSDxe 专用补丁」。结合 §A.2 的分层，工作量拆成四段：

| 段 | 内容 | 依据 / 缺口 | 估计 | 等级 |
|---|---|---|---|---|
| B0 重建环境 | 重下 `mu_wide_platforms`(fork) + `edk2` 基线 + 工具链（clang-21 / nuget / mono）；重编 Mu（2026-10-05 实测 2m59s） | §A.1 实盘 0 命中；`.pi/hermes-memory-mirror/MEMORY.md:15` 工具链清单 | **0.5–1 天**（下载为主） | 【已证实】 |
| B1 定位 `0x402` 注册表条目 | 需要「谁在运行期写入 `.data:0x228d8`」+「条目 `+4` 字段的语义」。原厂 `uefi.elf`/`imagefv.elf` 在盘（§A.1）⇒ 反汇编原厂同名函数可对照；上游 Mu 侧无此表（`ConfigurationMapLib` 41 条全为命名键） | 写入点 `0x89cc`（§A.2）；原厂固件在 `~/下载/tb322fc/` | **1–2 天**（纯静态逆向） | 【推测】 |
| B2 修第二层 SMMU | `UFS.c+2326` = 208 B 上下文/`UFSSmmuConfig` 失败。Mu 的 UFS SMMU 配置依赖平台内存映射与 IOMMU 描述，**这部分上游无 SM8750 参考** | §A.2 三；`dodgePkg` 无对应键 | **3–5 天**（改代码，非改配置） | 【推测】 |
| B3 QBSS/SCM 装配 | `mbox_os_init` 的 SCM protocol 由别的 DXE 发布；`QBSS clock node` 属 NPA 平台数据 | §A.3 | **1–2 天** | 【已证实为配置/装配类】 |

**结论**：**下限 ~1 周、上限 2 周+**，且 B1/B2 的成败不取决于我们的努力程度，而取决于**原厂 ABL 是否留有足够的公开结构**（Lenovo 未公开任何 ABL/UEFI 文档；Mu 侧只能靠反汇编对齐）。这是「系统性缺口」的量化版本，与 §A.3 的分层一致。

## C. 与替代方案对比

| 方案 | 突破 96 MiB | 多内核菜单 | 改动面 | 需人在场 | 复用现有资产 | 风险 | 估计工作量 | 裁决 |
|---|---|---|---|---|---|---|---|---|
| ① UEFI + GRUB（G1-29 原路线） | 是 | 是（真 GRUB） | 改 `uefi_a`/`imagefv_a`（**写 a 槽**） | 是（PO R + fastboot） | ❌ 三仓全丢需重下 2.3 G | 高（改引导分区；UFS 过不去时只能 EDL 回滚） | 1–2 周 | **不做** |
| ② 直接 U-Boot（qcom 主线） | 是 | 是 | 需 qcom U-Boot 的 SM8750 板级支持 + 同样的 UFS 初始化 | 是 | ❌ 需新拉 | 高 | 未知（**SM8750 主线 U-Boot 支持状态未证实**，本轮未检索到成功案例） | **暂不评估** |
| ③ 现有 `boot.img` + kexec | 已解决（G1-30） | **是**（`kexec_file_load` + 用户态选单） | **只加 ~40 行内核补丁**（mask=1 旋钮回植） | 是（每轮 ≤10 min） | ✅ 全部在盘（`patches/kernel-history/elden_vk53-hw/0019+0020`、`scripts/kexec-boot.sh`） | 中（掉电/交接失败都不破坏分区，零写盘） | **半天主机 + 1 h 设备** | **唯一推荐**（`reports/kexec-plan-20261021.md`） |
| ④ systemd-boot / EFI stub 直启 | 需先有 EFI 环境 | 是 | 依赖 ① 的 UEFI 壳 | 是 | ❌ | 高 | — | **不适用**（无 UEFI 就没有 ESP 可放） |

**判据差别**：③ 与 ①②之间的不是「能力」差别，而是**代价与可逆性**差别——③ 全零写盘、失败即重启；①② 要动引导分区且卡在一个我们无法独立解决的固件层缺口上。

## D. 结论：值不值得现在投入

**不值得。维持「搁置」，定位仍是拓展项（非主线）。**

- **判据**：UEFI 的独占收益只剩「真 GRUB 菜单」；该收益已由 kexec 以 1/20 的成本覆盖；而复起成本（≥1 周 + 2.3 G 重下 + 两层固件级缺口）远高于任何当前主线（Q28 面板、Q24 熄屏、kexec）的边际收益。
- **如果将来重启的唯一触发条件**：① 上游 Mu 侧出现 SM8750 的 UFS SMMU 修法（届时 B2 归零）；或 ② 出现「必须多 OS 并存、kexec 不够用」的需求（例如 Windows/Android/Linux 三启动）。两者都没有则不开工。
- **本轮即可做的两件低成本事（不重启路线）**：
  1. **回帖上游 issue #12**：给出 §A.2 的结论（`0x402` 不是 config tag，是运行期注册表条目；崩溃点是运行期未映射指针），把球踢回「固件版本相关」的具体含义。证据齐、零成本。
  2. **更正文档口径**（父 agent 动作）：`TASKS:40` 的「SCM mailbox/QBSS/CPU_Vectors 缺失」三项并列需分层（CPU_Vectors 已废弃、UsbBusStart 无关）；`TASKS §5 Q25` 的「静态定位 config tag 0x402」待办作废。
- **零写盘最小验证路径（若强行验证一次）**：`fastboot boot` 现成 Mu 镜像（**不写 `uefi_a`**）→ 进 BDS 后只做只读 `dh`/`memmap` 导出，判定「运行期注册表条目是否存在且指向有效内存」。需先在盘重建 2.3 G 资产，因此**不建议为验证而重下**。

> 出口：本报告 §A 的取证价值已闭环（推翻 Q25 假设、量化两层阻塞、确认资产丢失）；§B/§C/§D 结论为「不做」，与 `TASKS/README.md` §1 G1-29 的「搁置」一致，仅把理由从「单点不可解」升级为「分层可解但成本 ≥1 周且收益已被 kexec 覆盖」。
