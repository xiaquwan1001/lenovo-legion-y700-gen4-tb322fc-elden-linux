# 会话交接：Gunyah RM 在主线跑通（/dev/gunyah + 真实 RM RPC），VMM 卡在 `VM_INIT → IRQ_INUSE`

- 日期：2026-10-24（深夜收尾）
- 主题：capid 取证（A 路）→ 运行时发现机制 → 厂商 DTBO overlay → RM 可用 → VMM 首次尝试
- 结论（一句话）：**Gunyah RM 已完全可用（`ioctl(GUNYAH_CREATE_VM)` 返回 fd = 真实 RM RPC 往返）**；
  **VMM 卡在 `GUNYAH_RM_RPC_VM_INIT` 返回 `IRQ_INUSE(0x10)`**，且**在 stock Android（厂商内核/驱动）上逐字相同** ⇒ 不是移植问题，是「普通子 VM」参数/策略不成立。

## 1. 设备当前状态

- **`boot_b` Linux vk127 在跑**（`7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`），slot b active/bootable；
- **`init_boot_a` 已还原原厂**（sha `e8206b81…`），`boot_a`/`vbmeta`/`boot_b` 全程未改；
- `/dev/gunyah` 现在**不存在**（槽启动的 DTB 没有 `__symbols__`，overlay 会 `-EINVAL`）—— 这是预期，不是故障。

## 2. 本轮闭环的事实（不要重复验证）

| 项 | 结论 |
|---|---|
| RM 节点真值 | `reg=<tx,rx>`（**每次开机新发**）、`interrupts=<0 0x3c0 1 0 0x3c1 1>`（SPI 960/961，恒定）、父节点 `compatible=qcom,gunyah-hypervisor*`+`simple-bus` |
| capid 发现通道 | **TZ SMC `0x02000609`**（`HYP_INFO_GET_HYP_DTB_ADDRESS`，param 0，无入参）→ `a1` = hyp boot info 物理地址 → magic `0xC06B0071` → `num_dtbos`/`dtbo_base[]` → 每份是 FDT overlay（dtbo[0] 就是 hypervisor 子树） |
| 结构体/协议定义在哪 | Mu 源里就有：`Platforms/QcomModulePkg/{Include/Library/HypervisorMvCalls.h,Include/Protocol/scm_sip_interface.h}`（**不需要逆向**） |
| 唯一硬前置 | 板 DTB 必须带 `__symbols__`（`DTC_FLAGS_sm8750-lenovo-elden.dtb := -@`，`patches/gunyah/0001-*.patch`）；否则 overlay 一律 `-EINVAL`（PITFALLS #389） |
| RM 可用判据 | `/dev/gunyah` 存在 + `gunyah_rsc_mgr` 绑 `hypervisor:qcom,resource-manager-rpc@…` + `ioctl(GUNYAH_CREATE_VM)` → fd |
| dtbo[1] | 厂商路径适配（`/soc/qcom,wdt@16410000` 禁用、`/firmware/qcom_scm` 加 max-queues/SPI 962、`arch_timer always-on`）⇒ 主线路径不同故 `-EINVAL`，与 RM 无关 |

## 3. VMM 卡点（下一轮从这里开始）

- harness：`tools/gunyah-modules/vmmtest/`（`vmmtest.c` + `stub.S` + `guest.dts`）。
- 进度：`CREATE_VM` → `SET_USER_MEM_REGION` → `SET_DTB_CONFIG` → `VM_ALLOC_VMID` → DTB parcel 共享 → `VM_CONFIG_IMAGE` → `VM_SET_ADDRESS_LAYOUT` **全过**；`VM_INIT` 失败 `IRQ_INUSE`。
- 已否证：IRQ 泄漏（冷起同样失败）；移植问题（**Android 上逐字相同**）。
- 已确认：本移植把 DTB 区域按 `GUNYAH_RM_RANGE_ID_IMAGE` 注册（端口里没有 `RANGE_ID_DTB`）；pVM 分支（`GH_VM_ANDROID_SET_FW_CONFIG`）先失败于 `Failed to allocate parcel for FW: -22`。
- **Android 侧关键线索**：AVF 走的是 **`/dev/qgunyah`**（`10,263`，`GH_ANDROID_IOCTL_TYPE='A'`），不是 `/dev/gunyah`；主线**没有**这个 misc 节点。
  AVF apex（`com.android.virt@3`）在，但 `com.android.virtualization.terminal` **无 launchable activity** ⇒ 未能实测 AVF 建 VM；`pvmfw_a/b` 分区存在。

### 下一轮候选（按成本）

1. **B**：复刻厂商 pVM —— 先给主线补 `/dev/qgunyah` 节点（照抄厂商 `gh_rm_drv` 的 misc 注册与 'A' ioctl 分派），再走 `SET_FW_CONFIG`（fw 独立 parcel）+ `LEND_USER_MEM` + `SET_DTB_CONFIG`。
2. **C**：改内核侧把 guest image 与 DTB 分开（`RANGE_ID_IMAGE` 放内核），对齐新版上游 gunyah API。
3. 若都不通：**G2 结论 = 该 firmware 下「自建 Linux 宿主 + Gunyah 子 VM」不可用**，回 Waydroid 主线（与本轮结论并列写进 TASKS §4）。

## 4. 可复现件（都在仓库里）

- `reports/gunyah-capid-forensics-20261024.md`（capid 取证）、`reports/gunyah-mainline-rm-up-20261024.md`（RM 跑通）、`reports/gunyah-vmm-first-attempt-20261024.md`（VMM 卡点 + 方案 A 结果）
- `scripts/gunyah-rm-bringup.sh`（构建/安装 `dtbo.ko`+`rmtest` → 拉起栈 → 验 RM RPC；`HOOK=1` 装开机自启）
- `tools/gunyah-modules/{hypprobe,dtbo,rmtest,vmmtest}/`、`patches/gunyah/0001-*.patch`、镜像 `out/boot-elden-dtbo1.img`（sha `5d6ba622…`）
- PITFALLS：`#387`（UEFI 载荷 v3/v0 与槽标记）、`#388`（运行时 DT 值每 boot 变）、`#389`（DTB 缺 `__symbols__` 导致 overlay `-EINVAL`；rmmod overlay provider 复位）

## 5. 工作区状态

`git status` 干净；`scripts/check-doctor.sh` FAIL=0；设备在 `boot_b` 日常 Linux。
