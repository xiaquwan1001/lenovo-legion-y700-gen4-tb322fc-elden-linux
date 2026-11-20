# A5 分叉点梳理：根因 / 目的 / 互斥性 / 可整合性

审计代理: A5-forks（只读 lane） / 2026-11-19T22:2x+08:00 / 只读

> 口径：全部结论先给判据再给解释。**只读**（零 git 写、零设备接触、零安装）。仓库根已核 `git rev-parse --show-toplevel` = `/home/xuqianhui/y700-elden`；本文写作时 HEAD = `4542020e`。
> 证据层级：`INDEX.md` §0 / `TASKS/README.md` / `PITFALLS/README.md` 为 SSOT；`reports/` 为证据层；最近会话（`.pi/sessions/` mtime 排序首位 = `2026-11-19T13-52-39-003Z_01a1f414-…jsonl`）权重最高。凡「文档声明日期」未经 git 提交史逐条核对的，本文标 `[声明]`。

---

## 0. 一页结论

1. **共 14 个分叉点**：**在用/并行 8**、**已废或被取代 4**（两轨分机、GPT-minimal、7.2-elden 下游树、day-1 rootfs）、**纯备胎 1**（redroid）、**双套历史 1**（archive / reports，属治理性分叉、非技术分叉）。
2. **只有 3 个真·物理互斥**（同一时刻只能选一个，且换向要写盘）：① GPT-minimal ↔ 共存契约（同一 LBA 段）；② slim v1/v2/v3（同一 `super` 分区）；③ boot_a ↔ boot_b（同一 `active` 槽 + 同一 retry 计数）。其余都是**并行/分层**或**已被取代**。
3. **最容易误当「并行」的其实是互斥**：`rootfs` 多代（day-1 / minbase / 190 GiB）——同一 `linux17` 只能装一版；判据 `RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md:32`（S9 在线 `resize2fs` 6 GiB→190 GiB）。
4. **最大治理风险 = 文档层双轨**：`reports/` 已 559 篇 md（`reports/README.md:7`，目录项 581），`archive/topics/` 110 篇；同一事实有「多代快照」并存（如 `upstream-status-20261026/27/29/20261105/20261113`），靠人记「哪个是当前一页」。
5. **推荐收束 = 3 条主线 + 1 张写盘纪律表**（§3）：主线 = ① Linux 日常栈（`boot_b` + `linux17` + minbase→daily-baseline）② G2 容器（Waydroid 主力 / redroid 备胎不动）③ 上游化 M 系列（新上游基线 + patch 重放）。可立即合并的 5 项全在主机侧（零设备风险）。

### 总览表

| # | 分叉点 | 首次出现 | 现态 | 互斥对象 | 可整合 |
|---|---|---|---|---|---|
| 1 | 两轨分机 → 设备等价(U1/U2) | ≤2026-09-30 `[声明]` | 旧口径**已废**、新口径在用 | 无 | 已完成（文档层） |
| 2 | RAM 启动 vs 刷写启动 | 2026-10-03 | **并行分层**，都在用 | 单次启动形态二选一 | 是（同一件两形态） |
| 3 | UEFI flashed vs 间接(GRUB) | 2026-11-08 / 11-10 | **并行**，均通；日常不启用 | 同一 `boot` 槽、同上一次启动 | 是（可选臂） |
| 4 | GPT-minimal vs 共存契约 | 2026-11-17 / 11-19 | 前者**已废禁写**，后者**冻结在用** | ★物理互斥 | 否（二选一已定） |
| 5 | boot_a / boot_b 双槽与槽属性 | 2026-10-03 | 在用，分工固定 | ★物理互斥（active/retry 单点） | 否（只能规范化） |
| 6 | Waydroid vs redroid | 2026-10 早 | 主力在用 / 备胎从未安装 | 无（不同宿主栈） | 否（刻意保留备胎） |
| 7 | 自编 phoc/phosh vs 发行版包 | 2026-11-11 / 11-14 | **并行且必须共存** | 同名路径互斥（同一文件） | 部分（divert+hold 已机制化） |
| 8 | M1 下游重放(7.2-elden) vs 新上游基线 | 2026-10-11 | 下游树**已删/被取代** | 树血统互斥 | 否（已实际取代） |
| 9 | KernelSU 支线 | 2026-11-18 | 造件完成、**未上机** | 与 super 不互斥（只动 init_boot_a/vbmeta_a） | 是（并一次窗口） |
| 10 | dtbo_dummy | 2026-10-03（项目第一天坑） | 在用（b 槽固定件） | dtbo_a 归 Android | 否（安全阀） |
| 11 | rootfs 多代（day-1 / minbase 6G / 190GiB 桌面） | 2026-10-02 / 11-18 / 11-19 | 前两代为**历史/中间态**，190 GiB 现役 | ★同一 `linux17` 只能一版 | 是（已有唯一链） |
| 12 | 安卓 slim v1/v2/v3 | 2026-11-18 / 11-19 | v1 现役、v3 已写未采用、v2 仅方案 | ★同一 `super` | 是（v3 待取证） |
| 13 | QEMU 对照 vs 真机 | 2026-11-12 定口径 `[声明]` | **互补分层** | 无 | 不适用（应保留） |
| 14 | archive/ vs reports/ 两套历史 | 迁移期（≤2026-10-15） | 职责已分，但存在重复快照 | 无（同事实双写） | 部分（过期快照归位） |

---

## 1. 逐个分叉点

### 1.1 两轨分机 → 设备等价（U1/U2）

- **首次出现**：旧口径「两轨分机 / 新机-旧机角色表」= 2026-09-30…10-02 的旧任务线批次 `[声明]`；作废日 = **2026-10-06**（`TASKS/README.md:117-118`）。
- **触发原因**：两台单元被当成不同角色（一台专用跑 mainline、一台专用留 Android），导致资产命名「某机专用」、脚本写死路径；实际同型号物理等价，唯一差异 = 容量。
- **原始目的**：并行推进互不干扰（旧认知：一机试验、一机保命）。
- **当前状态**：**旧口径已废、新口径在用**。判据：`AGENTS.md:23`（身份 = `(SN, hwboardid, 容量)`）、`DEVICE/README.md:304`（§2.1 三条等价原则）、`DEVICE/README.md:315`（U1/U2 台账按状态派任务）、`AGENTS.md:25` 与 `INDEX.md:151` 明文禁用「两轨分机」/`new-tablet`；退役原文 `archive/topics/RETIRED-PLANS-2026-10-06.md:16`。
- **互斥**：无（纯治理口径）。
- **能否整合**：**已是整合态**。残余动作 = 脚本默认路径彻底去 `new-tablet`（已核仅剩 1 处注释反面示例，`TASKS/README.md:109`）。

### 1.2 RAM 启动 vs 刷写启动

- **首次出现**：**2026-10-03**，`TASKS/README.md:41`（G1-1「b 槽刷 blank dtbo + vk40 RAM 直启，后切持久版」）。
- **触发原因**：`boot.img` 96 MiB 限制 + 改错即变砖的风险；`fastboot boot` 零写盘可反复试。
- **原始目的**：零写盘验证内核/DTB/引导链，失败即复位回退。
- **当前状态**：**并行分层，两者都在用**。
  - RAM 臂 = 零写盘试验/对照（2026-11-19 下午控制臂 2/2 实证 RAM 路径本身是好的，`TASKS/README.md:164`；`INDEX.md:50` 记录 11-18 两次失败的**真因是 cmdline 根标签 `linux17` vs 实际 `linux`**，不是 RAM 路径）。
  - 刷写臂 = `boot_b` 持久件（`bootslot-b/boot_b.img` 读回 `06c081ca…`，`DEVICE/README.md:52-55`）。
  - **必须区分的子分叉**：`-ram` 纯 RAM 变体（不启桌面/会话）vs「RAM 内核 + 磁盘根」变体（可做功能测试）——`PITFALLS/README.md:19`（#92/#93）。混用会导致「DSP 离线、电源管理全废」的假故障。
- **互斥**：同一次启动只能是一种形态（互斥的是**本次**，不是路线）。
- **能否整合**：**是**。同一份 `boot` 件既可 `fastboot boot`（RAM 臂）也可 `fastboot flash boot_b`（持久臂）；判据 = 同 sha 双形态。代价 = 每次 RAM 臂后要显式 `mark-successful` + 补 retry（`PITFALLS/README.md:351` #672）。风险 = 误把「纯 RAM 变体」当功能测试件。

### 1.3 UEFI flashed 形态 vs 间接(GRUB)形态

- **首次出现**：零写盘形态 **2026-11-08**；flashed 形态打通 **2026-11-10** 深夜（`TASKS/README.md:51` G1-29）。
- **触发原因**：要摆脱 `boot.img` 96 MiB 上限（>64 MB initrd / 多菜单）。
- **原始目的**：把引导层从 ABL 直载内核改为「ABL → 我们的 UEFI → GRUB/菜单 → 内核」。
- **当前状态**：**两形态均通、并行**，但**日常不用**——现役是 `boot_b` 自签直启。
  - flashed 真根因已定 = 原厂 `dtbo_a` 的 Android DTBO 被 ABL 合进我们的 DTB（`PITFALLS/README.md:297` #600；`reports/uefi-dtbo-a-rootcause-20261110.md`）。
  - 间接形态断点已定 = Mu UEFI 把 initrd 分配进 `ramoops` 保留区，内核自己把 initrd 覆盖（`INDEX.md:91`；`reports/uefi-grub-initrd-rootcause-20261115.md`）；修法已做 2 枚可上游系列并真机 A/B 验证。
- **互斥**：同一 `boot` 槽、同一次启动只能一种形态。**且枚举结论不得跨形态横移**——同一 Mu 固件 `fastboot boot` 时 `SimpleFileSystem=8`，从 `boot_a` flash 启动时只有 1（`PITFALLS/README.md:268` #571）。
- **能否整合**：**是（作为可选臂）**。做法 = `boot_a` 固定为 UEFI 干净世代、`boot_b` 固定 mainline 直启；菜单只在 `set_active a` 时生效。代价 = ESP 需同步维护（`\EFI\BOOT\BOOTAA64.EFI` sha `244c5f65…`）+ 每次改菜单要重打 EFI（`DEVICE/README.md:142`、`INDEX.md:128`）。风险 = ESP FAT 写坏（需 `sync`+`fsck.vfat -n`）；`dtbo_a` 必须保持全 0，否则必卡 logo。

### 1.4 GPT-minimal（LBA 90504 单 `linux` 分区）vs 共存契约

- **首次出现**：GPT-minimal 路线定案 **2026-11-17 22:0x**（`INDEX.md:105`），造件 2026-11-18；共存契约 **2026-11-19 立**（`DEVICE/README.md:279` §1.7）。
- **触发原因**：GPT-minimal 的动机 = 原厂恢复把 `linux17` 条目 + 数据全毁，与其「抢救条目」不如「重装最小 + EDL 直写」；共存契约的动机 = **11-17/18 的覆盖事故形状**——单 `linux` 从 LBA 90504（= 原 `super` 起点）起，头 6 GiB 直接盖掉 `super` ⇒ Android a 槽不再可起。
- **原始目的**：
  - GPT-minimal：一条最简表（LUN0 10 项，`linux` LBA 90504..123871226 = 472.19 GiB）+ 最小 rootfs，把盘一次给足 Linux；
  - 共存契约：Android 住前段、Linux 住后段，两边各自可写、互不覆盖。
- **当前状态**：**GPT-minimal 已废并被明文禁止**，**共存契约冻结在用**。判据：
  - `DEVICE/README.md:279-289`：**禁止**再用「单 `linux` 从 LBA 90504 起」的设计；
  - 现场 EDL 读回 LUN0 主表 16 条目**两两不重叠**、无单 `linux` 分区，`scripts/android-linux-coexist-check.py` rc=0（`DEVICE/README.md:288` 现态条、`reports/android-slim-v3-20261119.md:14` 结论 1）；
  - 实测共存：刷安卓 3 次 Linux 全程可登（`INDEX.md:12`）。
- **互斥**：★**物理互斥**——两者对 LBA 90504 起同一段主张不同边界；换向 = 写表 + 重刷 `super`（~20 min，`INDEX.md:105` 回退口径）。
- **能否整合**：**否**（只能二选一，已选共存契约）。可整合的只是**术语**：把 `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md` 与 `ZERO-TO-DESKTOP.md` 里矿存的 `linux` 标签改写成 `linux17` + `LABEL=linux` 双口径（当前 `ZERO-TO-DESKTOP.md:101` 仍写 `write $BLK/73277435 …`，LBA 正确、标签需核）。

### 1.5 boot_a / boot_b 双槽用途与槽属性

- **首次出现**：2026-10-03（`TASKS/README.md:41` b 槽切持久版；`DEVICE/README.md:315` 台账）。
- **触发原因**：Qualcomm A/B 机制（`qbootctl` / LUN4 GPT 属性）；一台机器要同时容纳 Android（a）与 mainline（b）。
- **原始目的**：不破坏 Android 回退能力地用 mainline 直启。
- **当前状态**：**在用，分工已固定**：`boot_a` = Android / UEFI 干净世代（`pc1`，分区 sha `1ca2b8e69167…`）；`boot_b` = mainline 持久件；`DEVICE/README.md:332` §2.4 目标形态明确「a 槽 Android 可以不要」但不要求两槽对称。
  - 槽属性现态：2026-11-19 下午 `boot_b` 0x3f→0x7f 打补丁后 `getvar slot-successful:b` = yes（`INDEX.md:43`）；`boot_a` 曾因 `byte6=0xf7`（UNBOOTABLE 位）导致整轮试装全是「ABL 拒绝」而非镜像问题（`PITFALLS/README.md:351` #672）。
- **互斥**：★**物理互斥 + 状态共享**：一次只有一个 `active`，且 `retry` 计数按槽共用语义——打断启动 = 记失败、7 次即 UNBOOTABLE（`PITFALLS/README.md:358` #679）。
- **能否整合**：**否**（硬件机制）。可规范化 = 在 `DEVICE/README.md` §1.7 下补一张「槽位归属表」（a=Android/UEFI、b=Linux、recovery_b=TWRP）+ 每次实验收尾三件套（`mark-successful` + 补 retry + 贴 `slot-attr.py show` 原始行）。风险 = 任何未 `mark-successful` 的实验都会静默消耗 retry。

### 1.6 Waydroid vs redroid

- **首次出现**：2026-10 早期选型（`TASKS/README.md:426` R1 / `:427` R1'）。
- **触发原因**：G2 要求「不依赖 Android 宿主」跑安卓应用，需要容器方案。
- **原始目的**：Waydroid 主力（LXC + AIDL/HAL + 我们自己的 freedreno）；redroid 作备胎（Docker/podman，图形/HAL 受阻时切换验证）。
- **当前状态**：**Waydroid 在用（主力，C1–C12 大部分已收口）**；**redroid 从未安装**（`TASKS/README.md:427` 明确「⬜ 未装」）。判据：`AGENTS.md:15` 主/备胎明文；C3 已实测收口（三档全不满足，`TASKS/README.md:88`）。
- **互斥**：无（不同宿主栈，可共存；只是没必要同时装）。注意 R3 droidloom 与本两者是「形态」分叉，2026-11-11 已 L1–L4 全绿但**定位是隔离试验，不替换 Waydroid**（`TASKS/README.md:97`）。
- **能否整合**：**否，且不建议合并**——备胎的价值就是「主路线崩了能立刻切」。代价 = 0（未装即零维护）。风险 = 长期不验证导致「备胎实际不可用」；建议只在 G2 主线受阻时用一次设备窗口验证。

### 1.7 自编 phoc/phosh 件 vs 发行版包

- **首次出现**：**2026-11-11**（`phoc` syncobj 补丁件 `out/phoc-syncobj-arm64-20261111/phoc-0.58.0-syncobj` sha `863731b0…`，`TASKS/README.md:97`）；**2026-11-14** 两枚 T20 件（`INDEX.md:94`）。
- **触发原因**：发行版 phoc 0.58/0.59-rc1 **全树不调用** `wlr_linux_drm_syncobj_manager_v1_create`（升级解决不了）；T20 电源键不熄屏需 phoc 放行多请求者 + phosh 失败回退 ON。
- **原始目的**：补发行版缺的行为，同时不 fork 整个桌面栈。
- **当前状态**：**并行且必须共存**——自编件覆盖发行版同名二进制。判据：`scripts/phoc-install.sh` 已机制化 `dpkg-divert --divert <bin>.dpkg-dist` + `apt-mark hold`；根因记录 `PITFALLS/README.md:334`（#654：只 `install` 会被 apt 静默冲刷，功能消失而进程/桌面全正常）。
- **互斥**：同一路径只能一个二进制（物理互斥），但**路线可并行**（源码级 patch + 发行版基线）。
- **能否整合**：**部分**。可做 = ① 把两枚补丁往上游/发行版送（phoc syncobj 已是上游特性、phosh power 回退是 bug fix）；② 在 `daily-baseline.sh --check` 加一条「自编件 sha 仍在位」门。代价 = 每次 apt 升级 phoc/phosh 都要重编重装。风险 = 未 hold 的机器会被静默换回原件（已发生过一次）。

### 1.8 M1 下游重放（7.2-elden）vs 新上游基线（7.3 / 7.4）

- **首次出现**：M1 干净树 **2026-10-11**（`TASKS/README.md:574`）；7.3.1 重基 2026-11-07（`TASKS/README.md:262`）。
- **触发原因**：下游 7.2-elden 树带 vendor payload（125 改 + 11 新文件 ≈12.4k 行）+ vk 历史，无法直接上游化；需要「干净上游 tip + payload 重放」的资产树。
- **原始目的**：① 证明只靠可上游 payload 能编出 vk 等价功能镜像；② 给 §7 各系列一个可 apply 的基线。
- **当前状态**：**下游树已被取代且物理消失**。判据：`TASKS/README.md:574` 行首 `⚠️MIGRATION-LOST(2026-10-17：build/ 与 m1/* refs 未随迁)`；`INDEX.md:309` 与 `TASKS/README.md:18` 记录 **2026-11-19 磁盘清理已删 `build/` 内核树与 `geekidos-linux/`+软链 `linux`**，影响 = §5d 内核身份表 75 行「暂不可核」，登记 `versions/kernel-src-archive.tsv`、处置 `reports/disk-cleanup-20261119-validation-impact.md`。
  - 现役血统 = `v7.3.1` + payload replay（`boot_b` UTS `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`，`DEVICE/README.md:52`）。
  - 上游化基线 = mainline **7.4-rc3 `aebb727447`**，全部待发系列已在其上顺序 apply 通过（`INDEX.md:112`、`reports/artifacts/apply-check-7.4rc3-20261116/`）。
- **互斥**：树血统互斥（同一工作区只能一条基线；7.2 下游与 7.3/7.4 上游的 config/API 不兼容）。
- **能否整合**：**否，已被取代**。可做 = 把「7.2-elden 重放」整条降级为**方法学留档**（技能 `kernel-downstream-replay` 已承接：payload 基点丢失后的替代重建）；主线只保留「新上游基线 + 逐系列 patch」一条。代价 = 需要一次全量重建内核树（`versions/layout.tsv` 表头有命令）。风险 = 旧证据里的树路径行仍大量存在，容易被下一轮误引。

### 1.9 KernelSU 支线

- **首次出现**：**2026-11-18** 登记为待办（`INDEX.md:77`、`TASKS/README.md:207` 待办 ②）；造件完成 2026-11-18/19。
- **触发原因**：安卓侧需要一个可回退的 root（GKI LKM 路线），用于取 vendor 侧证据 / 过环境。
- **原始目的**：`magiskboot` + `kernelsu.ko` + `avbtool` 重签，替换 `init_boot_a` 与 `vbmeta_a`，**不动 `super`**。
- **当前状态**：**造件完成、未上机**。判据：`TASKS/README.md:213`（`out/android-root-20261119/`：`init_boot_ksu.img` `e30ce75d…`、`vbmeta_a_root.img` `5d93ba43…`、SHA256SUMS 8/8、`scripts/android-ksu-avb-build.py`、刷写脚本默认 dry-run）；v3 报告结论 6 明确 **KSU 未并入 v3**（`reports/android-slim-v3-20261119.md:20`）。
- **互斥**：**与 `super` 不互斥**（只动 init_boot_a + vbmeta_a），但**与「原厂 AVB 绿灯」互斥**（Flags=1 即 verity disabled；且 `boot` 链必须保持 OEM key `8fcb864f…`，改链 key 即致命——`TASKS/README.md:213` 硬事实 ②）。
- **能否整合**：**是**。动作 = 排进同一次设备窗口（清 BCB → v3 首启取证 → KSU 一发 → revert 演练）。代价 = 1 发刷写 + 1 发回退。风险 = 与 v3 首启取证互相污染（两个变量同窗 ⇒ 违反单变量）。

### 1.10 dtbo_dummy

- **首次出现**：**2026-10-03**（项目第一天的坑：「假 dtbo 必须两个槽都写」，`PITFALLS/README.md:297` 引 `PITFALLS/sessions/01`）。
- **触发原因**：ABL 在 `BootLinux` 后会把 `dtbo_<slot>` 里的 Android DTBO overlay 合进**我们的** Linux DTB ⇒ 卡联想 logo、USB 不枚举、~10 s 回落。`dtbo_b` 早在 10-03 就写成全 0 ⇒「`_b` 一直好、`_a` 一直坏」。
- **原始目的**：给 b 槽一个「空 overlay」的合法 dtbo 分区内容。
- **当前状态**：**在用**。件 = `out/dtbo-dummy.img`（**4096 B 全零**，sha256 `ad7facb2586fc6e966c004d7d1d16b024f5805ff7cb47c7a85dabd8b48892ca7`，`xxd -l 48` 全 0；生成器 `scripts/build-boot.sh:76`；带 hash footer 打成 33 554 432 B，`bootslot-b/README.md:26`；自检门 `scripts/linux-state-audit.sh:83`）。
- **互斥**：`dtbo_a` 归 Android（拍原厂件）、`dtbo_b` 归 Linux（dummy）——同一分区不能两用。flashed UEFI 形态另要求 `dtbo_a` **全 0 32 MiB**（`TASKS/README.md:51`）。
- **能否整合**：**否**（安全阀，必须与 Android 槽严格分离）。可做 = 把「`dtbo_b`=dummy、`dtbo_a`=原厂/dummy 二态」写进 `DEVICE/README.md` §1.7 纪律表，减少下一轮重复踩。
  - **口径注**：`dtbo-dummy.img` = 4 KiB 全零，不是 32 MiB 全零；刷 `dtbo_a` 的配方是 `truncate -s 33554432` 另做（两者不是同一件，勿混）。

### 1.11 rootfs 多代（minbase 6 GiB / 190 GiB 桌面 / day-1）

- **首次出现**：day-1 = **2026-10-02**（`env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz`，Alpine 期全量归档，3.44 GB / 30852 项，`TASKS/README.md:42` G1-3）；minbase = **2026-11-18**（`out/p2-minbase-20261118/rootfs-minbase-20261118.ext4.img` 6 GiB 稀疏/实占 2.1 G、label=`linux`、160 包、sha `d22c6a00…`，`INDEX.md:105`）；190 GiB 桌面 = **2026-11-19 13:20**（`resize2fs` 6.25 GB → 190 GiB，`INDEX.md:28`）。
- **触发原因**：day-1 = 首代持久根；minbase = `linux17` 数据被原厂 `userdata` 覆盖后需「EDL 直写最小根」重建；190 GiB = 6 GiB 装不下桌面栈（1253 包）。
- **原始目的**：三代其实是**同一条恢复链的三个阶段**（写最小 → 扩到目标容量 → 装日用基线）。
- **当前状态**：**day-1 已作废、minbase 是中间态、190 GiB 现役**。判据：`RUNBOOK-BRINGUP/README.md:56`（day-1 归档「⛔ 作废，已不在盘」）；`RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md:42-43`（minbase 165 包「只是中间态，不是目标态」，目标态 = S10–S12，现态 1253 包）；`ZERO-TO-DESKTOP.md:32,177-183`（S9 扩容判据 `df -h /` ≈ 193 GiB 分区 ⇒ 190 GiB fs）。
- **互斥**：★同一 `linux17` 只能装一版（换版 = 重写或 `debugfs`/`e2fsck` 回滚，`ZERO-TO-DESKTOP.md:274`）。
- **能否整合**：**是，且已整合成唯一链**。动作 = 明确宣布「`rootfs-minbase-build.sh` → EDL 写 → `resize2fs` → `daily-baseline.sh`」为唯一造根路径（`RUNBOOK-BRINGUP/README.md:47,352`）；把 day-1 归档指针标 `⛔` 并停止出现在恢复链里（已做）。代价 = 0。风险 = minbase 缺 `udev` 曾导致「模块零加载 ⇒ 显示挂死」整条假故障链（`INDEX.md:33`、`ROOBOOK` 见 `ZERO-TO-DESKTOP.md:287`）——中间态不能被当成目标态。

### 1.12 安卓 slim v1 / v2 / v3

- **首次出现**：v1 = **2026-11-18**（`super_min.img` 8481.5 MiB / `system_a` 5.0 GiB，上机两次 `boot_completed=1`，`TASKS/README.md:207` 判据行）；v2 = **2026-11-19**（**仅方案与体积模型**，A 变体 super 8864 MiB / B 变体 8480 MiB，`reports/android-slim-v2-20261119.md:21` 结论 8，无成品件）；v3 = **2026-11-19**（`system_a` 3920 MiB / `super_min_v3.img` 7109 MiB，`reports/android-slim-v3-20261119.md:15` 结论 2）。
- **触发原因**：原厂 `system` 11.43 GiB 里 5 GiB 是预装池；v1 卡 ZUXOS 动画，静态定因到「桌面占位 + 空目录/SELinux + launcher.db 47 行」三面（v2 报告结论 3–5）；v3 = 三面同办的彻底版。
- **原始目的**：把 `super` 压到最小，为 Linux 让出后端空间（共存契约下 `super` 仍占 22 GiB 跨度，但镜像可小）。
- **当前状态**：**v1 现役**（`super` = `e3d0d26f…` 8481.5 MiB，`DEVICE/README.md:288` 现态句）；**v3 已造件 + EDL 写入 + 读回逐字节一致，但卡 ZUXOS 动画未采用**（`51eae107…`；`reports/android-slim-v3-20261119.md:18` 结论 5 记录 `qdl reset` 后设备未重新枚举、首启未取证）；v2 **不出件**（被 v3 取代）。
- **互斥**：★同一 `super` 分区只能一版；且每次替换都要重跑 AVB 判据（现役 `vbmeta_a` Flags=1，换尺寸不触发重签，`reports/android-slim-v2-20261119.md:22` 结论 9）。
- **能否整合**：**是**。动作 = 把 v2 标为「不出件的中间方案」只留档，主线只保留 v1（现役）/v3（候补）；v3 采用与否由 §0 已列的顺序取证（S1 清 BCB → S2 原厂 metadata → S3 原厂 super 对照 → S4 二分 → S5 `console=ttyGS0`）决定。代价 = 1–2 次 EDL 写盘（每次 ~2 min 48 s @42.2 MiB/s）。风险 = BCB 污染产生假失败样本（`INDEX.md:14`：后两发很可能是启 recovery，**不算 Android 失败**）。

### 1.13 QEMU 对照 vs 真机

- **首次出现**：口径化 **2026-11-12** `[声明]`（`AGENTS.md:29-30`；调研 `reports/qemu-usage-survey-20261112.md`）。
- **触发原因**：真机验证贵（写盘/人肉看屏/断电风险），需要低成本对照。
- **原始目的**：「凡要烧设备/看屏的验证，先写一条 QEMU 对照」；QEMU 判不了的面（真外设、EFI-stub 差异、电源域）显式写「需上机」。
- **当前状态**：**互补分层、在用**。判据：`scripts/qemu-full-chain-smoke.sh`（单轮 ~35 s）、`scripts/qemu-ramoops-initrd-ab.sh` 的 A/B 曾定案 pstore 守卫（`INDEX.md:128`、`TASKS/README.md:247`）；QEMU 装法陷阱登记 `PITFALLS/README.md:344`（#666：`-dtb` 与 initrd 同址冲突、必须 `-device loader` 装 initrd）；反面样例 `PITFALLS/README.md:343`（#659：QEMU 6.45 s 解包成功 vs 设备 36 ms 失败 ⇒ 断点在 GRUB 交接，QEMU 恰好帮定位）。
- **互斥**：无（不同验证平面）。
- **能否整合**：**不适用**——这是应当保留的分层，不是需要收束的分叉。可做 = 把「哪些面 QEMU 判不了」写成清单（已有：真外设/EFI-stub/电源域/槽属性/ABL 行为）。

### 1.14 archive/ 与 reports/ 两套历史

- **首次出现**：迁移期（`archive/2026-10-04-*`、`-10-08-*` 等批次目录存在即 2026-10 上旬）；`SESSIONS/` 冻结 = 2026-10-15 起（`INDEX.md:246`）。
- **触发原因**：文档收敛（12→6 角度）+ 旧入口/旧计划/退役脚本需要地方放，同时 `reports/` 变成「专题证据」主目录。
- **原始目的**：`reports/` = 证据层（md 入库、大件 ignore）；`archive/` = 退役件（旧计划、旧脚本批次、历史快照）。
- **当前状态**：**职责已分但内容重叠**。判据：`INDEX.md:250`（顶层布局 4 区 + `archive/` 归「角度文档」track；`reports/` 归「证据/备份」）；`reports/README.md:1-7`（**机器生成勿手改**，559 篇）；`ls archive/topics | wc -l` = **110**；同事实多代快照并存 = `archive/topics/upstream/upstream-status-{20261026,20261027,20261029,20261105}.md` + 现役 `reports/upstream-status-20261113.md`。
- **互斥**：无物理互斥；风险是**同一结论两处写、两处漂**（`INDEX.md` §2「时间序裁决」即为此立的规则）。
- **能否整合**：**部分**。动作 = ① 把 `reports/` 里已被取代的「当前一页」类快照（`upstream-status-20261029/20261105`、`reports/uefi-*` 的已被根因报告取代的中间件）移入 `archive/topics/` 同子目录（已有先例）；② 在 `reports/README.md` 保持机器生成的前提下，加一个 `scripts/reports-index.py` 的「superseded-by」字段（若脚本不支持则记 TODO，不手改生成物）。代价 = 1 次批量移动 + 修若干死链。风险 = 移动破坏历史会话里的路径引用（`PITFALLS` 正文大量引用 `archive/topics/...`）——移动前必须 `grep -rn <文件名>` 查引用再加软链或留 stub。

---

## 2. 互斥矩阵（只列真互斥 / 强耦合）

| 组合 | 类型 | 判据 | 换向代价 |
|---|---|---|---|
| GPT-minimal ↔ 共存契约 | ★物理互斥（同一 LBA 段） | `DEVICE/README.md:279-289` | 写表 + 重刷 `super`（~20 min） |
| slim v1 ↔ v3 ↔ 原厂 super | ★物理互斥（同一 `super`） | `reports/android-slim-v3-20261119.md:15-19` | EDL 写 7109–8481 MiB（~3 min） |
| boot_a ↔ boot_b | ★物理互斥（`active` + retry 单点） | `PITFALLS/README.md:351,358` | `set_active` + `mark-successful` + 补 retry |
| rootfs day-1 ↔ minbase ↔ 190 GiB | ★同一 `linux17` | `ZERO-TO-DESKTOP.md:32,177` | 重写 / `resize2fs` 只增不减 |
| UEFI flashed ↔ 间接 GRUB | 单次启动互斥（枚举结论不可横移） | `PITFALLS/README.md:268` | `set_active` + ESP 维护 |
| RAM 启动 ↔ 刷写启动 | 单次启动互斥（路线不互斥） | `PITFALLS/README.md:19` | 零写盘，最便宜 |
| 自编 phoc/phosh ↔ 发行版包 | 同路径互斥 | `PITFALLS/README.md:334` | 重编重装（~10 min） |
| KSU ↔ 原厂 AVB 绿灯 | 判据互斥（不同时成立） | `TASKS/README.md:213` | `--revert` 件已在 `out/android-root-20261119/revert/` |

---

## 3. 推荐收束方案

### 3.1 保留 3 条主线（其余全部降为支线/留档）

| 主线 | 内容 | 唯一入口 | 现状判据 |
|---|---|---|---|
| **L（Linux 日常栈）** | `boot_b` 自签直启 + `linux17` + minbase→`resize2fs`→`daily-baseline` + 桌面壳（自编 phoc/phosh 两件） | `RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md`、`DEVICE/README.md` §1.1/§1.7 | 1253 包 / `/` 190 GiB / GPU `Adreno 830` GLES 3.2 / `glmark2-es2` 2594（`INDEX.md:28`） |
| **A（Android 共存与精简）** | 共存契约（冻结）+ `super` 精简（v1 现役 / v3 候补）+ KSU 支线（同窗口） | `DEVICE/README.md` §1.7、`reports/android-slim-v3-20261119.md` | 契约 rc=0；v1 `super` `e3d0d26f…` 上机 2/2 `boot_completed=1` |
| **U（上游化 M 系列）** | 新上游基线（7.4-rc3 `aebb727447`）+ 逐系列 patch + 按系列逐次批准投递 | `TASKS/README.md` §7、`reports/upstream-status-20261113.md` | 17 封全 250（11-17 批次）；唯一在档未发件已清零（`INDEX.md:97`） |

**为什么不保留第 4 条**：UEFI 两形态、QEMU、droidloom、redroid、Gunyah 都是「有触发条件才启用」的**可选臂**，任一都不需要日常维护成本；把它们写成「臂」而不是「线」，可以避免再次出现「两轨分机」式的角色固化。

### 3.2 可立即合并（主机侧，零设备风险，建议本周期做）

| # | 动作 | 判据/验收 | 风险 |
|---|---|---|---|
| M-1 | 统一「造根唯一链」：`rootfs-minbase-build.sh` → EDL → `resize2fs` → `daily-baseline.sh`；day-1 归档指针全部标 `⛔` | `grep -rn "linux17-rootfs-20261002" .` 只命中 ⛔ 行 | 低 |
| M-2 | `DEVICE/README.md` §1.7 增补两张小表：**槽位归属表**（a/b/recovery_b）+ **dtbo 用法表**（`dtbo_b`=4 KiB dummy→带 footer；`dtbo_a`=原厂 or 32 MiB 全零，二态） | 新会话不必再 grep `PITFALLS #600` | 低（纯文档） |
| M-3 | 把 `reports/` 内已被取代的「当前一页」类快照移入 `archive/topics/`（先 `grep -rn` 查引用） | 移动后 `scripts/check-doctor.sh` FAIL=0、死链 0 | 中（死链） |
| M-4 | 在 `TASKS/README.md` §7 M1 行加**明确 dead pointer 抬头**（树已删、方法学转技能 `kernel-downstream-replay`） | 行首已有 `⚠️MIGRATION-LOST`；补「不再恢复」一句 | 低 |
| M-5 | `reports/android-slim-v2-20261119.md` 顶部标「**不出件的中间方案，已被 v3 取代**」 | 与 v3 报告的 #6/#8 口径一致 | 低 |

### 3.3 必须等设备窗口（一次窗口只带 1 个变量）

1. **v3 首启取证**（按 `INDEX.md:14` 的 S1–S5 顺序：清 BCB → `qbootctl -a` → 原厂 `metadata` → 原厂 `super` 对照 → 二分 v2b → `console=ttyGS0`）——**这是 Android 侧唯一在飞的判据缺口**（`reports/android-slim-v3-20261119.md:18`「首启未上机」）。
2. **KSU 一发 + revert 演练**（与 ① 分开窗口；`scripts/android-ksu-flash.sh` 默认 dry-run）。
3. **UEFI 臂常规化**（可选，非阻塞）：GRUB 嵌入菜单重打 + `set_active a` 冷起回归。仅在「需要 >64 MB initrd 或多菜单」时才值得。
4. ~~槽位 `mark-successful` 收口~~ **已做（2026-11-19 下午）**：`getvar slot-successful:b` = yes。

### 3.4 只留档（不再作为工作面）

- 两轨分机 / `new-tablet` 角色表（`archive/topics/RETIRED-PLANS-2026-10-06.md`）——已废，仅需保持 `grep` 反面示例。
- GPT-minimal 设计（`RUNBOOK-BRINGUP/GPT-MINIMAL-DESIGN.md` + `out/gpt-minimal-20261118/`）——**留档并加「⛔ 已禁」抬头**，防止下一轮照做（`DEVICE/README.md:285` 已明禁）。
- 7.2-elden 下游重放整条（`TASKS/README.md:574` + 技能 `kernel-downstream-replay`）——方法学留，树路径全部 dead。
- day-1 rootfs 归档（`env-pass/backup-20261002/`）——已不在盘，指针留史。
- slim v2 方案——不出件。
- redroid / droidloom / Gunyah / QEMU-full-fidelity——**支线留档 + 触发条件**（分别：G2 受阻 / 上游一等支持 + 合成器满足 / 上游合 gunyah 驱动 / 需无真机判定）。

---

## 4. 未取证 / 存疑（不编造）

1. **各分叉「首次出现日期」多为文档声明日期**，未逐条对齐 git 提交史（本审计不写 git）。可核方式：`git log --diff-filter=A --format='%ad %h %s' -- <路径>`。已核实的日期：2026-10-06（两轨作废，`TASKS/README.md:117`）、2026-11-10（UEFI flashed，`TASKS/README.md:51`）、2026-11-17 22:0x（GPT-minimal 定案，`INDEX.md:105`）、2026-11-19（共存契约，`DEVICE/README.md:279`）。
2. **v3 首启是否真的「卡 ZUXOS 动画」**：目前只有「EDL 写入后设备未重新枚举 + BCB=`boot-recovery`」两条实测（`reports/android-slim-v3-20261119.md:18-19`），首启判据**未取得**——本文把 v3 记为「候补」而非「失败」。
3. **`reports/` 篇数口径**：`reports/README.md:7` 报 559（md），`ls reports` 得 581（含 `.tsv` 与 `artifacts/`）。两者不矛盾但不可混用，本文两个数都标了来源。
4. **`archive/README.md` 与 `archive/topics/README.md` 均不存在**（两次 `head` 输出为空）⇒ `archive/` 的目录级规则目前只在 `INDEX.md:250` 与 `RESOURCES/README.md` §3 里，属文档缺口（非 SSOT 违规，但影响 M-3 的可执行判据）。
5. **`dtbo_dummy` 与「32 MiB 全零 dtbo_a」是两件不同的东西**：前者 4096 B（`scripts/build-boot.sh:76`），后者由 `truncate -s 33554432` 现做（`TASKS/README.md:51`）。历史文档里两者常被混称「dtbo 全 0」，本文按实测尺寸区分。

---

收尾: A5 分叉点梳理完成 —— 14 个分叉（3 真物理互斥 / 8 在用并行 / 4 已废或被取代 / 1 双套历史），推荐收束为 L/A/U 三条主线 + 5 项主机侧可立即合并动作，产出 `reports/audit-20261119/A5-forks.md`（零改动、仅此一文件）。
