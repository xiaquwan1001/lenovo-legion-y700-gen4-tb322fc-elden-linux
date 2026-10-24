# 会话交接：Gunyah 全链路已通到「只差 DT 节点」，UEFI 三个实验镜像就绪待上机

- 日期：2026-10-24（收尾）
- pi 会话 id：$PI_SESSION_ID
- 主题：Gunyah（WoaA 路线）阶段 0/0b/方向 B + 驱动移植 + 零写盘上机；UEFI 备料与三镜像构建
- 结论（一句话）：**Gunyah 侧 hypervisor 与 VMM 前置全部打通**（API v1 四特性齐全、9 个模块 insmod 成功、驱动注册），**只剩 DT 节点里的 `reg`(capid)+`interrupts` 两组数**；**UEFI 侧 N/A/C 三个 NOSB 镜像已构建并逐枚 PE 复核**，等一次零写盘 `fastboot boot` 验证。
- 证据指针：`reports/gunyah-rm-probe-20261024.md`、`reports/gunyah-port-20261024.md`、`reports/gunyah-boot-test-20261024.md`、
  `reports/gunyah-dt-capid-20261024.md`、`reports/gunyah-kernel-build-20261024.md`、`reports/uefi-experiment-build-20261024.md`、
  `reports/uefi-runtime-table-provider-20261024.md`、`reports/woa-gunyah-survey-20261024.md`
- ★SSOT 待并入：无（`TASKS` §4 N1/N2、C8、§0 均已就地更新）

## 1. 设备当前状态（重要）

**设备停在 fastboot**（`fastboot devices` = `HA2EXB0E`），不是 Linux。ESN/RNDIS 没有 IP 是正常现象。
下次可直接 `fastboot boot <镜像>`，或 `fastboot reboot` 回 `boot_b`（`boot_b` 上次已置 succ）。

## 2. 已就绪、可直接跑的东西

| 项 | 路径 / 命令 | 判据 |
|---|---|---|
| **UEFI 镜像 A**（Mu + 厂商 UFSDxe `fa561bf1…`） | `reports/artifacts/uefi-built-20261024/lenovo-y700g4-A.img` | BDS 出现 UFS 启动设备；`UFS.c+2326` ASSERT 消失 |
| **UEFI 镜像 C**（A + 厂商 RmVmDxe `aed61cb1…`） | 同目录 `-C.img` | 若 UEFI 能引导 Linux：`/proc/device-tree/hypervisor/` 出现 `qcom,resource-manager-rpc@…`（= capid 节点） |
| **UEFI 基线 N** | 同目录 `-N.img` | 对照（应仍复现 issue #12） |
| **Gunyah 内核镜像** | `out/boot-elden-gunyah1.img`（sha `4d97e7e7…`）+ `out/gunyah-modules-gunyah1.tar.gz`（sha `753de11d…`） | 5 模块 insmod 通、`/sys/bus/platform/drivers/{gunyah,gunyah_rsc_mgr}` 在（已验） |
| Gunyah 探针模块 | `reports/artifacts/gunyah-probe-20261024/{gunyah_identify.ko,gunyah_wdt.ko}` | `HYP_IDENTIFY` → api v1 + 四特性 |

上机顺序建议：**A →（若通过）C**，两者都是 `fastboot boot` 零写盘；UEFI 起不来就 `fastboot reboot` 回 `boot_b`。

## 3. 已知事实（本轮闭环，不要重复验证）

- 本机**运行在 Gunyah guest 里**：`/sys/bus/platform/devices/gunyah-wdt` 存在；自编 `gunyah_wdt.ko` probe 通过。
- **HYP_IDENTIFY**：`api_info=0x5100000000008001`（API v1）、`flags[0]=0x10010fff` ⇒ DOORBELL/MSGQUEUE/VCPU/MEMEXTENT 全支持；`hvc #0x60XX` 与 SMCCC 形式等价。
- 厂商 hvc 表：`gh_msgq`=0x601b/0x601c、`gh_dbl`=0x6012–0x6015、`gh_rm_booster`=0x603d、`gunyah_loader`=0x6045…0x6065。
- **Gunyah 驱动移植完成**：`build/gunyah-port` @ `24223e4`，API 漂移 7 处全功能等价，8 个 `.ko` 0 error/0 warning、vermagic 与在机一致；硬缺口 `set_direct_map_*` 未导出已由 2 行 export 补上并进镜像。
- **零写盘上机已验**：5 模块 insmod OK（含 `rsc_mgr`）、驱动注册 OK；**无 `/dev/gunyah`** = 缺 DT 节点（驱动要 `gunyah-hypervisor` / `gunyah-resource-manager`）。
- **关键对齐**：`rsc_mgr.c:709-720` 只吃节点上的 `reg`（index0=tx capid、index1=rx capid）+ 两条 `interrupts`，**厂商运行时节点属性集正好满足**⇒ 不需要任何厂商 ABI 适配。
- **capid 溯源**：stock Android 运行时 `/proc/device-tree/hypervisor/` 有 `qcom,gunyah-vm` 与 `qcom,resource-manager-rpc@93ddea6be110409a`（SELinux 拒读内容）；
  静态 DT 只有 `gh-watchdog`，`dtbo_a`/`vendor_boot_a` 0 命中，节点名后缀在所有本地固件里 0 命中 ⇒ **运行时生成**；注入者 = 厂商 UEFI 的 `RmVmDxe`（含 `MergeRmDtbo`/`fdt_set_blob_handle`，PE 内无 FDT 模版）。
- **WoaA 裁决**：裸机零成功；Gunyah VM 有本机型第三方先例（`Droid-VM/edk2-gunyah` 测过 tb322fc）；**用户裁决走纯 Linux 宿主自建，Android/AVF 只作材料，最终回收 Android 分区**；USB 直通唯一实现 = `Droid-VM/crosvm fb86c7b0` 仿真 xHCI + usbfs。

## 4. 下次的第一件事（按顺序）

1. **A 上机**（设备已在 fastboot）：`fastboot boot reports/artifacts/uefi-built-20261024/lenovo-y700g4-A.img`；记录 BDS 日志/是否出现 UFS 设备。失败就记录并回 `boot_b`。
2. **C 上机**（A 通过后再做）：同法；若进 Linux，立刻抓 `/proc/device-tree/hypervisor/`。
3. **若 C 也没补出节点 ⇒ capid 只剩两条路**：
   - A 路：Magisk 补丁 stock boot（零写盘 root）读 `reg`+`interrupts` 一次；
   - C 路：继续逆向 `RmVmDxe` 的 cap 来源（`VmGetHypResources` 前后 + `ScmSipSysCall`）。
4. captid 到手后：在我们的 DTB 里加 `gunyah-hypervisor` + `gunyah-resource-manager` 两个节点 → `modprobe` → `/dev/gunyah` → RM RPC → 再谈 VMM（`qemu-for-gunyah` out-of-tree / crosvm-glibc）。

## 5. 本轮沉淀的坑（都已在 PITFALLS）

`#381` 单模块构建四连坑 · `#382` EFI GUID_DEFINED 段 DataOffset 差 4 字节导致反向错误结论 · `#383` Gunyah 移植两坑（`if VIRT_DRIVERS` 门 + `set_direct_map_*` 未导出） · `#384` manifest 尾部 `+` 假阴性 · `#385` 模块进持久根被 udev 自动加载（「零写盘」只保证不写分区） · `#386` 全局 git `insteadOf`→SSH + **嵌套子模块丢 `-c`**（PATH wrapper）。

## 6. 工作区状态

`git status` 干净；`scripts/check-doctor.sh` **FAIL=0**（WARN 3 条为既有产物类）；`build/vk151`（日用树）未被改动；设备在 fastboot、`boot_b` 已成功标记。
