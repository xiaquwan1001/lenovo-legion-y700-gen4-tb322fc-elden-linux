# Gunyah VM 线：重启复核（2026-11-11）

> 派工：Gunyah 线「能否重启」lane。**零设备动作**（未 ssh / 未 fastboot / 未重启），全部证据来自主机侧只读 + 联网原始页面。
> 复核对象：`reports/gunyah-decision-20261025.md`（终局裁决）+ `reports/gunyah-stage0-positive-20261024.md`（阶段 0/0b 阳性）。
> 抓取时间：**2026-11-11 UTC 08:20–09:50**（`date -u` = `2026-11-11 08:27:17 UTC`）。
> 上游树核对锚点：torvalds/linux `master` HEAD = `067c5c24cef2`（committer date **2026-11-10T16:58:21Z**，`page_alloc-for-7.4-rc2` 合并）。

## 0. 一句话结论（先数字）

**有条件重启。** 10-25 裁决的三条理由里：① 仍成立、② 成立但**其推论已被推翻**、③ **已被推翻（不是"在演"，是被 KVM 维护者明确拒绝的死路）**。
新出现第四条路且**已在与本机同 SoC（SM8750P）的主线 Linux 宿主上跑通**：`android17-6.18` 驱动栈的 7.2/7.3 移植 + crosvm Gunyah 后端 + edk2-gunyah 固件，公开可复现（§2）。
剩下的唯一未知量 = **tb322fc 这版 Lenovo 固件的 RM 策略**（piano/iceland 那两台允许 protected VM 创建，我们 10-25 的 pVM 尝试在 `VM_INIT` 被拒 `0xA`）；这**必须一次上机**才能判定，且我们当年缺的那份「RM 静默强制的 DTB 规则表」现在有了（§2.3）。

## 1. 上游主线现状（2026-11-11 现查）

### 1.1 `drivers/virt/gunyah`：**仍不在主线，也不在 linux-next**

| 树 | 判据 | 结果 |
|---|---|---|
| torvalds/linux `master` | `https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/virt`（2026-11-11 抓取，页面全文检索 `gunyah` = **False**）；目录项 = `Kconfig Makefile acrn coco fsl_hypervisor.c nitro_enclaves steal_governor.c vboxguest vmgenid.c` | ❌ 无 `gunyah/` |
| 同上（第二源） | `raw.githubusercontent.com/torvalds/linux/master/drivers/virt/{Kconfig,Makefile}`：Kconfig 里 `source` 行只有 `vboxguest/nitro_enclaves/acrn/coco`；Makefile `obj-*` 只有 `fsl_hypervisor/vmgenid/steal_governor/vboxguest/nitro_enclaves/acrn/coco` | ❌ 无 gunyah 行 |
| linux-next | `https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/tree/drivers/virt`（2026-11-11 抓取）全文检索 `gunyah` = **False**，目录项 = `Kconfig Makefile acrn coco fsl_hypervisor.c nitro_enclaves steal_governor.c vboxguest` | ❌ 无 |
| `virt/kvm` | torvalds 与 linux-next 两棵树的 `tree/virt/kvm` 页面检索 `gunyah` = **False / False** | ❌ KVM-in-EL1 代码零落地 |

### 1.2 lore 上 2026 年的 gunyah 邮件：**全是外围件，没有驱动主线化**

`https://lore.kernel.org/all/?q=gunyah`（2026-11-11 抓取，按相关度前 100 条）：

- `[PATCH] firmware: qcom: scm: Detect Gunyah by Qualcomm's hypervisor UID too` — Stanislav Aleksandrov，**2026-11-09 00:30 UTC**；Abel Vesa / Konrad Dybcio 当日回帖。补丁正文（patchwork API `patches/14962871` 的 `diff`）新增第二个 UUID：
  `qc_hyp_uuid = UUID_INIT(0xbd54bd19,0x1b57,0x370b,0x9b,0x60,0x6f,0x94,0xe6,0x9d,0x53,0x54)`，条件是
  `(!arm_smccc_hypervisor_has_uuid(&gunyah_uuid) && !arm_smccc_hypervisor_has_uuid(&qc_hyp_uuid))` 才 return。
  ⇒ 主线**愿意承认"我们在 Gunyah 下"这件事**（我们现在用的正是第一个 UUID `c1d58fcd-…`，阶段 0 命中路径不受影响），但仅限 watchdog 探测。
- `[PATCH] watchdog: gunyah_wdt: Re-enable the watchdog on resume` — 2026-11-09 08:26 UTC（Guenter Roeck 当日回帖）；
- `[PATCH] watchdog: gunyah: report system sleep operation failures` — 2026-10-08。
- **android-common 构建告警**（kernel test robot，2026-07→10 十余条）证实 `drivers/virt/gunyah` 在 AOSP **android17-6.18 / android16-6.12 / android15-6.6** 三个分支都活着（例：2026-10-30 `android16-6.12 3/3 drivers/virt/gunyah/vm_mgr.c:117`）。
- **Elliot Berman 的 v17 之后无 v18**：`?q="virt: gunyah"` 前 100 条里，Berman 的提交记录止于 `[PATCH v17 00/35]` **2024-02-22**。

### 1.3 KVM-in-EL1 RFC（10-02/10-25 口径里的"唯一在演路线"）：**只有 v0，且被明确拒绝**

`https://lore.kernel.org/all/?q="Gunyah Guests via KVM"` = 命中 **6 条**，全在 2025 年；`?q="KVM in EL1"` = 6 条。原文（lore Atom 抓取，逐字）：

- Oliver Upton（2025-04-24 15:35）：「The KVM arch interface is *internal* to KVM, not something to be (ab)used for cramming in a non-KVM hypervisor.」
- Marc Zyngier（2025-04-24 16:57）：「+1. KVM is not a generic interface for random third party hypervisors. … **But mixing the two is not happening, sorry.**」
- Karim Manaouil（同日 16:43）：「I very much expected this take …」；
- Trilok Soni（QUALCOMM，同日 16:13）：「**I agree, this is not the approach Qualcomm would like to use.** Our approach will be similar to Elliot Berman's patches (v17). We will revive that series once Faud's patches are accepted on guest_memfd.」
- David Woodhouse（2025-06-19）虽替"内核应提供统一虚拟化 API"辩护，但**没人接**；至 2026-11-11 **无 v2**（Karim 2026 年的 lore 活动全在 mm/compaction/dma 方向，`?q=Karim+Manaouil` 131 条中 2026 年 30 条无一涉及 gunyah/kvm）。
- Qualcomm 承诺的 "v17 revival"：lore 检索（`gunyah` / `virt: gunyah`）**未见**任何 2025-05 之后的 Berman/Qualcomm 驱动系列。

### 1.4 Gunyah 官方仓库（GH / RM）：**季度更新，且把"厂商 ABI"公开了**

| 仓库 | 最新提交 | 关键内容 |
|---|---|---|
| `quic/gunyah-hypervisor` | `25472774` **2026-05-29**（`contrib: gunyah-hypervisor update 03/2026`）；518★；pushed 2026-11-11 | 上一次 2025-10-07 → 季度节奏 |
| `quic/gunyah-resource-manager` | `7e934458` **2026-06-01**（`contrib: resource-manager update 03/2026`） | — |

**推翻 10-25 的一条子理由**：裁决说厂商用的是「主线未定义、无文档」的 `MEM_DONATE 0x51000010`。实际抓 `gunyah-resource-manager` @`develop` 的 `include/memparcel_msg.h`：

```
#define MEM_DONATE	    0x51000010U
#define MEM_ACCEPT	    0x51000011U
#define MEM_LEND	    0x51000012U
#define MEM_SHARE	    0x51000013U
#define MEM_RELEASE	    0x51000014U
#define MEM_RECLAIM	    0x51000015U
#define MEM_NOTIFY	    0x51000017U
#define MEM_APPEND	    0x51000018U
#define MEM_QCOM_LOOKUP_SGL 0x5100001AU
```

⇒ 该 id **是开源参考实现里的正式定义**，不是黑盒。另外 `include/vm_mgnt_message.h` / `vm_creation_message.h` 明确列出
`VM_SET_FIRMWARE_MEM 0x56000032`、`VM_SET_DEMAND_PAGING 0x56000033`、`VM_SET_ADDRESS_LAYOUT 0x56000034`、`VM_INIT 0x5600000b`
——即 10-25 反汇编说「vendor RM 没有 0x32/0x33/0x34」的那些，开源 RM **有**；**结论应改为「本机固件的 RM 比开源参考实现更老」，不是「ABI 无文档」**。
（RM 错误码也全部开源可查：`gunyah_rm_error` 枚举 `MEM_INVALID=0xA`、`IRQ_INUSE=0x10`，与 10-25 的读法一致 — `reference/gunyah-refs/g612/rsc_mgr.c:57-79`。）

## 2. 先例现状（严格区分宿主形态与 SoC）

### 2.1 纯 Linux 宿主 + Gunyah 客户机：**已成立，两台，其中一台就是 SM8750P**

| 项目 | 宿主形态 | SoC / 设备 | 状态 | 证据（抓取日期 2026-11-11） |
|---|---|---|---|---|
| **`yzddmr6/xiaomipad-8pro-mainline`** + `GunyahVM` | **主线 Ubuntu（GTK 桌面），crosvm 跑在宿主内核的 Gunyah 接口上** | **SM8750P** / 小米平板 8 Pro（piano） | ✅ 「命令行虚拟机 Gunyah / crosvm ✅ 可选功能」「图形虚拟机管理器 GunyahVM ✅ 预装」 | README 特性表第 173/174 行；`kernel/source.json` 锁 `v7.2.15` + `github.com/yzddmr6/linux-sm8750-piano` 分支 `piano/v1.2-features` commit `ff6cf0aa`，release `7.2.15-piano73`，配置片段含 **`arch/arm64/configs/piano-virt.config`**；该树 `drivers/virt/gunyah/` **18 个文件**（含 `gunyah_qtvm.c`、`vm_mgr_cma_mem.c`），最近 gunyah 提交 `bf42598a virt: gunyah: quarantine memory when APPEND rollback fails` **2026-11-03** |
| **`mzakamin-hub/iceland-gvm`**（+ `iceland-linux`、`iceland-vms`、`iceland-mainline`） | **主线 Linux + Fedora 44 桌面**（`gunyah.ko` 及其 9 个伴随模块，`/etc/modules-load.d/gunyah.conf`） | SM8850P / OnePlus Pad 4（iceland） | ✅ 内核 `7.3.0-next-20261020-iceland-00555`；「Virtual machines (Gunyah) ✅ Working」「Windows 11 ARM guest VM ✅ Working」「VM QEMU-Gunyah backend ✅ Working」 | `iceland-mainline` README 第 65/113-122 行；`iceland-gvm` README「on mainline Linux and Fedora 44」+「The host side, the Gunyah VM manager (`gunyah.ko` and its companions), is part of the kernel since iceland-linux q90m」；crosvm 实调 `--hypervisor gunyah --protected-vm-without-firmware --no-usb --no-balloon --swiotlb …`（`gvm/gvm.sh:160`），版本 `0.3-59`，最新提交 **2026-10-26** |
| `quic/gunyah-support-scripts` | Qualcomm Linux（dev kit，PVM=crosvm 宿主） | RB3/qcm6490 系 | 文档化流程 `svm_booting_linux.md`（`/usr/gunyah/svm.sh`） | 最新提交 **2026-06-01** |

### 2.2 Android 宿主（**不能**当"我们能做"的证据，仅作 ABI/GUI 参考）

| 项目 | 宿主 | SoC / 设备 | 最新活动 |
|---|---|---|---|
| `Droid-VM/DroidVM`（1057★） | **Android App**，`/dev/gunyah` | 多机（含 SM8750/8850） | pushed 2026-11-01 |
| `Droid-VM/edk2-gunyah`（26★） | Android 宿主 crosvm（README 的 run 命令是 `/apex/com.android.virt/bin/crosvm run --protected-vm-without-firmware …`） | **tested platforms 仍列 `tb322fc`**（SM8750）+ `myron`（SM8850） | 最新提交 **2026-10-10**（`fix(prepi): select firmware RAM and exclude standalone framebuffers`） |
| `Droid-VM/crosvm`（11★） | 同上 | — | 最新 **2026-10-10**（`fix(config): reject pseudo-unprotected mode outside Gunyah`） |
| `polygraphene/gunyah-on-sd-guide`（151★） | **Android 15 + root(APatch) 宿主**，`adb push` 到 `/data/local/tmp`，`LD_PRELOAD=libbinder*` | **tb322fc**（本机同型号） | 最后 push **2026-06-20** |
| `yzddmr6/GunyahVM` 的 **Windows** 支持 | 主线 Ubuntu 宿主 | 小米平板 8 Pro（SM8750）「system release 1.1.1 or later」 | pushed 2026-11-10 |

### 2.3 iceland 公开的「RM 静默强制规则」——我们 10-25 缺的就是这份

`patches/0014-q90m/0003-…-add-VM-smoke-test-and-record-verif.patch` 新增的 `Documentation/virt/gunyah/port_adaptations.md`（原文摘要）：

- **驱动来源不是 6.12**：`0001-virt-gunyah-import-Gunyah-hypervisor-drivers-from-an.patch` 标题即「import … from **android17-6.18**」，正文锁 tag `android17-6.18-2026-06_r1`，commit `30c0eaeef78d5c19f687ad8418c27b76353ab261`，含 `drivers/virt/gunyah/`（core+rsc_mgr+vm_mgr+vcpu+irqfd/ioeventfd+QCOM hooks+**QTVM auth manager**）、`arch/arm64/gunyah/`、`include/{linux,uapi}/linux/gunyah*.h`、DT binding、Documentation —— 共 9289 行补丁。
- **适配主线 7.2 只花 102 行**（7 文件：`android_kabi.h`→`__has_include`、vendor hooks→本地 stub、`set_direct_map_*` 在 `MODULE` 下编译掉、`of_fwnode_handle()` 改名），"Logic is unchanged"；硬件验证：`gunyah: Running under Gunyah hypervisor 51/v1`、`/dev/gunyah` 出现、`gh_rm_core` 注册、QCOM hooks 生效。
- **RM 在 `VM_INIT` 校验 VMM 提供的 DTB，失败返回 `VALIDATE_FAILED (8)`**，规则：`/gunyah-vm-config` 需 `image-name`/`os-type="linux"`/`vm-type="aarch64-guest"`/`memory{base-address,size-max}`/`interrupts{config="/intc"}`/`vcpus{affinity="proxy"}`/`vdevices{generate="/hypervisor"}`；**RAM 节点必须恰好是 `/memory`（`memory@80000000` 会被拒）**；`/cpus` `#address-cells=1 #size-cells=0`；GICv3 节点；`arm,armv8-timer` PPI CPU mask 必须**等于 vCPU 数**（1 个 vCPU 用 `0x108`，`0xf08` 不接受）。
- **固件限制（SM8850）**：只有 protected VM 能起，镜像 memparcel 必须 `LEND`（`GH_VM_ANDROID_LEND_USER_MEM`）；用户态 `SET_USER_MEM_REGION` → `VM_CONFIG_IMAGE` 回 `MAP_FAILED (9)` 且之后拒绝 deallocate（错误 20，**每次尝试丢一个 VMID**）；protected VM 不能把「镜像 LEND + 其余 SHARE」当透明 guest RAM（`addrspace_map` 回 `DENIED 30`）；RM log 未实现；**`fork()` 持 LEND 页的 VMM 会挂机**（FOLL_LONGTERM pin + dup_mmap 非 COW ⇒ 同步 external abort，曾实测死机一次）；4 KiB lend 会冻宿主（每页一次 TZ 调用，`GVM_HUGEPAGES=0` 仅调试用）。
- 最小可跑证明：`tools/virt/gunyah/gh_vmtest.py`（纯 python3，4 MiB LEND + 1 vCPU + 16 字节 payload）在 `off lend` 模式下「VM_START in ~2 ms，guest PSCI SYSTEM_OFF → EXITED，5/5 通过」。

## 3. 三条裁决理由逐条对账

| # | 10-25 / 10-02 理由 | 今日判定 | 依据 |
|---|---|---|---|
| ① | **设备侧 KVM 不可达**（XBL 在 secure-boot 链内加载 hyp，`-el2.dtb` overlay 只适用 dev kit） | ✅ **仍成立** | 2026 年新出现的"Linux 在 EL2 当宿主"证据全在 **dev kit / 笔电**侧：U-Boot `mach-snapdragon: Add early EL2 hypervisor switch support`（v5，2026-10-13，配 `configs: qualcomm: Enable Gunyah exit`）、`Peripheral Image Loader support for Qualcomm SoCs running Linux host at EL2`（v8，2025-12）、X1E/Radxa 的 `radxa,enable-kvm` SMC —— **消费机（含 tb322fc）无等效开关**；iceland 也是同样口径：「Gunyah owns EL2, so there is no KVM」 |
| ② | **独立 gunyah 驱动未进主线**（本树 `drivers/virt/` 无 gunyah） | ✅ **事实成立**；❌ **由它推出的"因此这条路走不通"不成立** | §1.1 三棵树核查仍无；但 §2.1 两台纯 Linux 宿主（**含 SM8750P**）用 7.2/7.3 out-of-tree 移植 + crosvm 已跑起 Linux/Windows 客户机，且移植成本被量化成 **102 行 API 适配** |
| ③ | **唯一新路 = KVM-in-EL1 + Gunyah backend（RFC 00/34，WIP）** | ❌ **已推翻（双重错）** | 其一，它**不是唯一**：真在演的是 standalone 驱动移植（§2）；其二，它**不是 WIP 而是死路**：KVM 维护者逐字拒绝「mixing the two is not happening, sorry」（§1.3），RFC 停留 v0 已 19 个月，Qualcomm 自己说「this is not the approach Qualcomm would like to use」。**10-25 裁决沿用这条口径 = 把最没希望的一条当成"唯一在演"，却没注意到旁边已经有可跑的先例** |
| 附 | 10-25 补充理由：「厂商路径依赖**主线不存在**的 `MEM_DONATE` + `gunyah_loader` hypercall 族，纯厂商内部 ABI、无文档」 | ⚠️ **部分被推翻** | `MEM_DONATE 0x51000010` / `MEM_APPEND 0x51000018` / `VM_SET_FIRMWARE_MEM|DEMAND_PAGING|ADDRESS_LAYOUT` 全在开源 `gunyah-resource-manager` 的头文件里（§1.4）。真正的门槛是**固件策略**（protected-only / lend-only / ACL），而不是"没文档" |
| 附 | 10-25 阶段推断：「`VM_INIT` 请求体只有 vmid ⇒ `0xA` 与 guest DTB 内容**完全无关**」 | ⚠️ **被削弱，需一次对照实验** | iceland 实测 RM **在 `VM_INIT` 校验 DTB**（失败码 `8 VALIDATE_FAILED`）。我们拿到的是 `0xA` 而非 `8`，所以不能直接说"我们的 DTB 被拒"，但「DTB 与 VM_INIT 无关」这个论断在原理上不成立；缺的对照 = 故意喂违规 DTB（`memory@80000000` / timer mask `0xf08`），看码是否变 `8` |

**有无新第四条路**：有，且是本轮最大的口径变化 ——
**第四条 = 直接复用已硬件验证的主线移植（`linux-sm8750-piano` 7.2.15 或 iceland q90m..q90x 的 android17-6.18 import）+ crosvm Gunyah 后端 + edk2-gunyah + 遵循 §2.3 的 RM 规则表**，目标不是"跑 VM"以外的任何东西，也不碰引导链。

## 4. 判定与首步

### 判定：**有条件重启**（不是无条件重启，也不是不重启）

| 条件 | 状态 |
|---|---|
| **C1** 存在"主线 Linux 宿主 + Gunyah 客户机"的可用移植，且已硬件验证 | ✅ **已满足**（SM8750P 的 piano 树 + SM8850P 的 iceland 队列，均公开、均为 7.2/7.3） |
| **C2** 本机（TB322FC）这版 Lenovo 固件的 RM 策略不低于 piano/iceland 那两台 | ❓ **未满足** — 三台是不同 OEM 的 hyp 配置；10-25 我们的 pVM 卡在 `VM_INIT 0xA`，而 piano/iceland 都在自己的机器上过了这一步 |
| **C3** 目标仍是「本机跑 Linux/Windows 子 VM」，且 Waydroid/Box64 覆盖不了 | ❓ **需用户确认**（10-25 裁决 §6 复启条件 3 就是这个；本轮不替用户拍板） |

C1 已翻盘 ⇒ **不再是"要不要投入研究"，而是"一次上机就能把 C2 变成二值结论"**。若 C2 为假（固件就是不给建 VM），则**永久关闭**这条线并保留 §5 的资产清单。

### 首步（≤3 条，每条带判据）

- **S1（零设备，主机静态对账，约 2–4 h）**：把 `yzddmr6/linux-sm8750-piano@piano/v1.2-features`（7.2.15，SM8750P）的 `drivers/virt/gunyah/` 与我们 10-25 用的 `reference/gunyah-refs/g612/`（android16-6.12）逐文件 diff，并对照 iceland `patches/0014-q90m…0023-q90v` 的 16 个 gunyah 补丁（其中 `0020-q90s/0005 Never release memory that may still be dirty`、`0023-q90v/0001 Refuse private anonymous memory for a protected VM`、`0018-q90q/0001 vm_mgr do not warn on module unload` 直接对应我们的失败面）。
  **判据**：产出 ≥3 条落在 `vm_mgr_mem.c` / `rsc_mgr_rpc.c` 的 lend / demand-paging / parcel 生命周期差异，且其中至少 1 条能解释"`VM_CONFIG_IMAGE` 成功但 `VM_INIT` 回 `0xA`"的机制（例如 parcel 状态机/APPEND 收尾/`private anon` 拒绝）。
  **副产品（同一步可做）**：静态核在机固件 `backup/stock-elden/vendor_ramdisk/gh_rm_drv.ko` 是否实现 `0x51000018`（MEM_APPEND）与 `0x56000032-34`，把「本机 RM 代次」变成数字。
- **S2（需设备，一次 `fastboot boot` 级；交总管排）**：按 iceland 的配方起一个 7.3 内核（驱动 = S1 选定的移植代次），**先跑 `gh_vmtest.py` 风格的最小探针**（4 MiB LEND + 1 vCPU + 16 字节 payload，不走 crosvm），再跑 crosvm `--hypervisor gunyah --protected-vm-without-firmware`。
  **判据**：①`gunyah: Running under Gunyah hypervisor <api>/v1` + `/dev/gunyah` + `gh_rm_core` 出现；②`gh_vmtest` 的 `VM_START` 是否返回 0（不是 `0xA`）；③如果是 `0xA`，记录**同一 vmid 连续两次**的错误（判断是否 VMID 泄漏型）——三条任一为真即 C2=真。
  **风险自限**：全程 `fastboot boot`（零写盘）；**不要** `fork()` 持 lend 页的进程（§2.3 已实测过死机），crosvm 单进程，`GVM_HUGEPAGES` 默认（避开 4 KiB lend 冻机）。
- **S3（跟 S2 同一次上机，二值对照）**：若 S2 仍回 `0xA`，喂一份**故意违规的 DTB**（RAM 节点写 `memory@80000000`、timer PPI mask 写 `0xf08`）。
  **判据**：错误码是否从 `0xA` 变 `8`。变 `8` ⇒ 10-25「DTB 内容与 VM_INIT 无关」结论作废，须按 §2.3 规则表重跑；仍是 `0xA` ⇒ 彻底排除 DTB 轴，把 10-25 的结论钉死，可据此**永久关闭**。

## 5. 证据级别表

| 级别 | 含义 | 本轮条目 |
|---|---|---|
| **A**（原始页面/仓库文件，带日期） | 直接抓取，可复跑命令 | ① torvalds/linux `drivers/virt` 树页 + `raw` Kconfig/Makefile + HEAD `067c5c24`（2026-11-11）；② linux-next `drivers/virt` 树页；③ 两棵树的 `virt/kvm`；④ lore Atom（RFC 00/34 全部 6 条回帖原文）；⑤ lore 搜索页（`gunyah` 100 条、`"virt: gunyah"` 133 条、`Karim Manaouil` 131 条）；⑥ GitHub API：`quic/gunyah-{hypervisor,resource-manager}` 提交元数据 + `include/memparcel_msg.h`、`include/vm_mgnt_message.h`、`include/vm_creation_message.h` 正文；⑦ `.tar.gz` 下载核对 `ghrm/include/{memparcel_msg,vm_creation_message,vm_mgnt_message}.h`；⑧ `yzddmr6/xiaomipad-8pro-mainline` README/`kernel/source.json`/`docs/VIRTUALIZATION.zh-CN.md`/`device/virtualization/patches/*`；⑨ `yzddmr6/linux-sm8750-piano` 的 `drivers/virt/gunyah` 文件表与提交史；⑩ `mzakamin-hub/iceland-{gvm,linux,mainline}` README + `patches/0014-q90m/{0001,0002,0003}` 补丁正文 + `gvm/gvm.sh:146-161`；⑪ `polygraphene/gunyah-on-sd-guide` README；⑫ `Droid-VM/{DroidVM,edk2-gunyah,crosvm}` README + 提交史 |
| **B** | 元数据/标题级，未逐字读全文 | patchwork API 的 `Gunyah hypervisor UID` 回帖清单；`watchdog: gunyah_wdt: Re-enable the watchdog on resume` 仅标题；iceland `0020-q90s/0023-q90v` 等 13 条 gunyah 补丁**仅文件名**（未读正文）；iceland-vms / iceland-qemu-gunyah 仅 README 提及 |
| **C** | 推断（未验证） | 「本机固件 RM 比开源参考实现更老」是由「vendor 无 0x32-0x34 ↔ 开源 RM 有」推出的；「piano/iceland 的 hyp 策略可能也适用于 tb322fc」是**待证假设**，不是事实；「10-25 的 `0xA` 可能源于 parcel 状态机差异」是 S1 要证/否的假设 |

**未采用**（明确不计入）：lore 搜索页的百分比相关度排序（不是命中全文，只作线索）；Firecrawl 通道报 `HTTP 402 配额耗尽`（未影响结论，全程有 AnySearch/官方 API 兜底）。

## 6. 未完成项 + ★SSOT 待并入

### 6.1 未完成项

1. **iceland q90m..q90v 的 16 个 gunyah 补丁正文未读**（只读了 0001/0002/0003）——S1 的第一件事就是把 `0020-q90s/0005`、`0023-q90v/0001`、`0015-q90n/0012`（vCPU timer 拆成 `gunyah_timer`）读透。
2. **piano 树的 gunyah 驱动从哪个 AOSP tag 来**未确认（iceland 明写 `android17-6.18-2026-06_r1`，piano 未找到同类声明；可用 `git log --follow drivers/virt/gunyah/gunyah.c` 第一条判断）。
3. **`gunyah_loader` / `gunyah_share` 的厂商 ABI** 本轮未继续逆向（10-25 已有反汇编；新增可用材料 = 开源 RM 的头文件，但仍缺 hypercall 表 `0x6045/0x604e…0x6065` 的对应）。
4. **QTVM（`auth_vm_mgr` / PAS ID）**：iceland 标「needs a signed image and a PAS ID; untested」；10-25 我们 pVM 尝试走到 `auth→PVM` 成功、死在 `VM_INIT`，所以 QTVM 不是当前瓶颈。
5. **未做**：设备侧任何动作（本 lane 明令零设备）。

### 6.2 ★待总管并入 SSOT（我不改）

**`TASKS/README.md` §2 行 C8** 建议改为（保留历史、追加本轮）：

> 🟡 **书面结论被部分推翻，转「有条件重启」**（2026-11-11，`reports/gunyah-restart-assessment-20261111.md`）：
> ①「KVM 不可达」仍成立；②「无驱动进主线」事实仍成立（torvalds `master`/linux-next 的 `drivers/virt` 与 `virt/kvm` 今日均无 `gunyah`，HEAD `067c5c24` 2026-11-10）**但"因此不可行"的推论已推翻**；③「唯一新路 = KVM-in-EL1 RFC 00/34」**被推翻**：KVM 维护者 2025-04-24 逐字拒绝（「mixing the two is not happening, sorry」），RFC 停 v0 已 19 个月。
> **新增第四条路（已硬件验证）**：`android17-6.18` 驱动栈的 7.2/7.3 移植（主线适配仅 102 行）+ crosvm Gunyah 后端 + edk2-gunyah；纯 Linux 宿主的先例两台 —— **`yzddmr6/linux-sm8750-piano`（SM8750P，Ubuntu，`drivers/virt/gunyah` 18 文件，gunyah 提交 2026-11-03）** 与 `mzakamin-hub/iceland-gvm`（SM8850P，Fedora 44，Linux+Windows 客户机 ✅）。另：`MEM_DONATE 0x51000010` 等在开源 `gunyah-resource-manager` 有正式定义（≠「无文档厂商 ABI」）。
> **唯一未知量 = 本机 Lenovo 固件 RM 策略**（10-25 pVM 在 `VM_INIT` 回 `0xA`；piano/iceland 未遇此码）⇒ **一次 `fastboot boot` 的最小探针 + 一次「坏 DTB 对照」即可二值定论**（判据见报告 §4 S2/S3）。**条件未满足前不排期、不占设备**。

**`TASKS/README.md` §4 行 N2 / §5 Q4** 同源追加一句：
> Q4 的②③口径需更正（②的推论、③的"唯一在演"），详见上；Q4 结论仍待用户答「拿它做什么」（C3 条件）。

**`RESOURCES/README.md` §1.5** 建议加两行（本轮新增资产，尚未落地本地）：

| 资源 | 关键点 | 我们用它的哪一块 |
|---|---|---|
| `yzddmr6/linux-sm8750-piano` @`piano/v1.2-features`（commit `ff6cf0aa`，7.2.15-piano73；gunyah 提交 2026-11-03） | **与本机同 SoC（SM8750P）** 的主线移植，`drivers/virt/gunyah/` 18 文件 + `arch/arm64/gunyah/` + `piano-virt.config` | C8 重启后的**移植基线**（替代 6.12 的 `reference/gunyah-refs/g612/`） |
| `mzakamin-hub/iceland-linux` `patches/0014-q90m`（import from `android17-6.18-2026-06_r1`，9289 行）+ `0015`–`0023` 队列 | 主线 7.2 适配 102 行；**RM 静默强制的 DTB 规则表**、protected-only/lend-only 固件限制、`fork()` 持 lend 页会挂机、4 KiB lend 冻宿主 | C8 的**配方与坑表**（下一步 S1 的对账面） |
