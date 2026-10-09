# research-kexec-feasibility-2026-10-09：elden(TB322FC/SM8750P) kexec 快环可行性调查

> 承接 `archive/topics/KEXEC-DIAG-TEST-PLAN-2026-10-08.md` §8/§9（device_shutdown 掉电已定位并可用 mask=1 规避）。
> 本文只调查「目标内核 kexec 引导失败」这第二个、也是唯一拦路的问题。不修改领域层文件。

---

## 0. 结论（一句话）

**跳转路径本身（machine_kexec → cpu_soft_restart → Image 入口）与加载路径（kexec_file_load）在源码层均未见致命错误；
剩余失败点集中在「目标 Image 早期 boot」与「跳过 device_shutdown 后遗留的硬件状态（SMMU 活跃 stream / GIC LPI）」两大类。
本树确有一处已知上游 kexec 缺陷（trans_pgd VA_BITS_52，`1537e55728ec` 未修），但它只影响旧 syscall `kexec -l`（purgatory 路径），
对现在用的 `kexec_file_load`（IND_DONE in-place，不走 trans_pgd）**无关**——这是本轮对 2026-10-05 结论的一个重要修正。
最优先的下一步实验不是再碰 kexec -e，而是用 **kdump（crash kernel, SysRq-c）** 一次性隔离「目标早期 boot」与「关机遗留状态」。**

---

## 1. 跳转流程源码分析（本树 linux/，`kexec_file_load` 路径）

实际顺序（`kernel/kexec_core.c` + `arch/arm64/kernel/machine_kexec.c`）：

```
kexec_file_load → image_load (kexec_image.c)：
  - Image 装入 free memblock hole + text_offset，image->start = 物理地址
  - load_other_segments (machine_kexec_file.c)：initrd 装载、
    DTB 由 live DT 重建 (of_kexec_alloc_and_setup_fdt，2M 对齐，top-down)
  - file-loaded image 为 in-place：head |= IND_DONE
machine_kexec_post_load：IND_DONE 分支 → 仅 kexec_segment_flush（dcache clean 到 PoC）→ 返回
machine_kexec：
  local_daif_mask()
  → cpu_install_idmap()
  → cpu_soft_restart(is_hyp_nvhe(), kimage->start, kimage->arch.dtb_mem, 0, 0)
  → MMU off → 跳 Image 入口，x0 = dtb_mem（物理地址）
```

逐点检查结果：

| 检查点 | 结论 |
|---|---|
| segment flush 到 PoC | 有（`kexec_segment_flush`），Image/DTB/initrd 均清到 PoC，cache coherency 路径 OK |
| DTB 是否正确传递 | `kexec_file_load` 不接受用户 DTB（syscall 无此形参）；内核用**运行内核 live DT** 重建新 FDT：删旧 kaslr-seed、注入新随机 seed、写 `linux,booted-from-kexec`。`scripts/kexec-diag-test.sh` 里的 `--dtb` 参数对 file-load 是空操作（kexec-tools 静默接受）。live DT 含 ABL 注入的 /reserved-memory（hyp/cpusys/modem 等），内核装载避开 memblock reserved，**交接本身无缺陷** |
| initrd | 正常装载（`buf_max` 限制在 kernel 的 1G 窗口内），无问题 |
| entry/参数 | `image->start` = kernel 段物理地址 + text_offset；x0=dtb_mem、x1..x3=0，符合 booting.rst |
| is_hyp_nvhe / EL 级交接 | 本机 Linux 由 ABL 在 Gunyah(TZ/hyp) 之下以 EL1 启动 ⇒ `__boot_cpu_mode[0]=EL1` ⇒ `is_hyp_nvhe()=false`（不复制 el2_vectors、不走 `__hyp_set_vectors`）→ cpu_soft_restart 以 EL1 关 MMU 直接跳。设计上 EL1 kernel 重启 EL1 kernel 合法（trap 由 EL2 hyp 接住），**但 Gunyah 对此路径的处理行为不可见、不可证**（需真串口） |
| machine_kexec_mask_interrupts | **只在 crash 路径调用**（`machine_crash_shutdown`）。普通 kexec 路径不掩中断：GIC distributor/ITS、LPI 表保持原配置进入跳转（见 §2 H-C） |

### 1.1 修正：VA_BITS_52 trans_pgd 缺陷与本机路径的关系

- 本树 `arch/arm64/kernel/machine_kexec.c:132` 仍为 `trans_pgd_create_copy(..., PAGE_OFFSET, PAGE_END)`（编译期 VA52），
  上游修复 `1537e55728ec`（改用 `_PAGE_OFFSET(vabits_actual)`）**未打进本树**；本机 config：`CONFIG_ARM64_VA_BITS_52=y`、4K pages、5 级页表、`CONFIG_ARM64_LPA2=y`。
- 但该缺陷只在 `!IND_DONE`（purgatory relocation）路径执行；**`kexec_file_load` 是 IND_DONE in-place，`machine_kexec_post_load` 提前返回，完全不碰 trans_pgd_create_copy**。
- ⇒ 2026-10-05 文档 §2.2 里"本树唯一命中的已知 kexec 缺陷"对现路径**不构成风险**；仅在回归旧 syscall `kexec -l`（purgatory）时相关。
- 附：SM8750（Cortex-X925/A725，ARMv9.2）大概率实现 FEAT_LPA2，运行时 vabits_actual=52 的话该 bug 连旧路径也不触发。判据：`dmesg | grep '52-bit Virtual Addressing'`。

---

## 2. 目标内核引导失败的剩余可能性（排序）

> 已知事实（§8/§9）：mask=1 跳过后走到 `psci: CPU1..6 killed`（已进 machine_shutdown 之后）→ 约 20s 后设备经 ABL 以 **boot_b(vk64)** 回来（真实复位，非挂死），pstore 空。⇒ 跳转后某处触发了**真实复位**（PSCI SYSTEM_RESET / PMIC PON），不是静默挂死——这一点很关键。

| 序 | 假设 | 机制 | 佐证/反证 |
|---|---|---|---|
| **H-A** | **跳过 device_shutdown 的遗留状态：SMMU 活跃 stream / 在跑 DMA** | mask=1 = 什么都不关，USB/UFS/显示等外设仍活跃；目标内核早期 probe SMMU（arm-smmu-qcom/TCU）时旧 stream 配置仍在，残留 DMA 甚至可能写坏目标 Image 所在内存；SMMU context fault/stall + 中断状态混乱 → 早期异常 | **最强候选**：唯一人为引入的非默认状态就是"跳过全部关机"；20s 真实复位与早期异常→hyp/PMIC 复位链相容 |
| **H-B** | **GIC/ITS 状态未清理** | 普通 kexec 不调 `machine_kexec_mask_interrupts`；GICv3 ITS 的 LPI 表仍指向旧配置，活跃外设（因 H-A 未关）在新内核 ITS remap 前持续发 LPI → 早期 abort/异常 | 与 H-A 伴生；crash 路径有 mask_interrupts，kdump 实验可同时检验 H-A/H-B |
| **H-C** | **目标 Image 早期 boot 本身问题**（Gunyah 交接、cmdline、内存布局） | 新 Image 入口早期（`__primary_switched` 前）失败；Gunyah 对"EL1 二次入厂"的处理；目标 cmdline 复用了运行 cmdline（含 `panic=15`） | 20s ≈ panic=15+5s 量级，**不能排除新内核确实起了、然后 panic→15s 自复位→ABL 回 boot_b**。若如此，pstore 空仅因目标内核未挂 ramoops。这是被低估的分支：**失败点可能在更晚，只是无输出可见** |
| **H-D** | EL 级/Gunyah 交互异常 | §1 表 is_hyp_nvhe 分析；Gunyah 未见 EL1 重启先例 | 不可证，需真串口；低优先 |
| ~~H-E~~ | ~~VA_BITS_52 trans_pgd bug~~ | §1.1：file-load 路径不走 trans_pgd | **排除**（对现路径） |

补充：目标内核若早期成功、晚段失败（H-C），则真正的观察缺口是「目标内核早期输出」——本机无物理 UART，需在目标 DTB 预留 ramoops 并在目标 cmdline 挂 pstore（早期可读），这是无 UART 条件下唯一可见性手段。

---

## 3. 社区先例（来自 repo 已有记录，未联网核实——lore.kernel.org 在本环境 403）

- arm64 "Bye! 后无输出" 是社区最常见分支（B3）：NXP i.MX8MP/LS2160、RPi 论坛大量报告；多为 SMMU/GIC/earlycon 缺失（`KEXEC-2026-10-05.md` §7 已收录）。
- `kexec_file_load` 设计上不允许用户指定第二内核 DT（LWN 772126）——与 §1 一致。
- trans_pgd VA52 修复 `1537e55728ec`（Breno Leitao / Will Deacon，2026-09 合入 arm64 fixes）——本树未打，见 §1.1。
- Qualcomm mainline（SDM845 等）kexec 可用的先例存在；SM87xx 无已知公开成功案例，SMMU qcom TBU quirk 与 kexec 的交互无先例记录。

---

## 4. 最小推进实验（如果只能做一件事）

**SysRq-c 触发 kdump（crash kernel），隔离两大假设。**

理由：crash 路径（`machine_crash_shutdown`）**完全不经过 reboot notifier / device_shutdown / syscore**（Q11 掉电源因天然不适用），却走**同一个"跳进目标 Image 早期代码"的机制**（kexec_file_load 装载 crash kernel Image+DTB+elf headers 到预留区，直接跳）。且 crash 路径**有** `machine_kexec_mask_interrupts`。本机 config 已有 `CONFIG_CRASH_DUMP=y`。

步骤：
1. 目标（crash）内核 = 与运行内核**同源同 config** 的 Image；目标 cmdline 带 `earlycon keep_bootcon` + **在目标 DTB 预留 ramoops**（无 UART 下的可见性），`maxcpus=1 nokaslr` 先做单变量。
2. `kexec -s -p <Image> --command-line ...` 装载 crash kernel（预留区需 cmdline `crashkernel=`，重启一次生效）。
3. `echo c > /proc/sysrq-trigger`。
4. 判读：
   - **crash kernel 起来了**（pstore/ramoops 有记录）⇒ 排除 H-C（目标早期 boot 本身没病），矛头指向 **H-A/H-B**（device_shutdown 跳过的遗留状态）→ 下一步：在 mask=1 跳转前**选择性保持最小关机**（如仅关 SMMU 相关/USB controller）或给目标内核打 SMMU/GIC 状态清理 patch。
   - **crash kernel 也失败** ⇒ 排除 H-A/H-B（关机遗留状态不在场），问题在 **目标早期 boot/交接（H-C/H-D）** → 下一步：目标 DTB ramoops + `nokaslr maxcpus=1` 逐项单变量，并核对 Gunyah/hyp 状态交接。
5. 额外观察：若 crash kernel 起来后 20s 仍复位且 pstore 空 → 检查目标 cmdline 是否把 `panic=15` 带了过去（H-C 的"晚段失败"分支）。

成本：1–2 次上机，全程复用现有 `fastboot boot` 零写盘 + slot-attr 纪律（§5）。

---

## 5. 纪律（沿用）

- 每轮上机前 `python3 scripts/slot-attr.py mark-successful b`。
- `fastboot boot` 零写盘；掉电靠 VBUS 自动回 boot_b。
- crashkernel 预留需重启一次才生效，注意 `crashkernel=` 与现有 memmap/DT 预留不冲突。

---

## 6. 参考

- 本树源码：`arch/arm64/kernel/machine_kexec.c`（:132 trans_pgd、machine_kexec IND_DONE 分支、mask_interrupts 仅 crash 路径）、`arch/arm64/kernel/machine_kexec_file.c`（load_other_segments）、`arch/arm64/kernel/kexec_image.c`（image_load，image->start）、`drivers/of/kexec.c`（live-DT 重建 FDT）、`arch/arm64/include/asm/virt.h`（is_hyp_nvhe）。
- 项目内：`archive/topics/KEXEC-DIAG-TEST-PLAN-2026-10-08.md` §6/§8/§9（上机事实）、`archive/topics/KEXEC-2026-10-05.md`（源码级取证、console 坑）、`archive/topics/KEXEC-ONDEVICE-R2-2026-10-05.md`。
- 上游：`1537e55728ec`（trans_pgd VA52 修复，本树未打、现路径无关）；LWN 772126（kexec_file_load DT 语义）。
- config 证据：`linux/.config`（KEXEC_FILE=y、CRASH_DUMP=y、VA_BITS_52=y、LPA2=y、PGTABLE_LEVELS=5、无 KASAN）。

---

## §5 实机实验记录 (2026-10-09 21:41–21:50)

### 实验：kexec -p (crash kernel) + SysRq-c

**载具**：`vk77-modkdump`（`out/boot-elden-vk77-modkdump.img`，sha `c7868f47`）
- cmdline 含 `crashkernel=64M`（RAM 预留 @ 0xecc00000，dmesg 确认）
- `fastboot boot` 零写盘启动，内核版本 `7.2.0-debug-ge3c5e9fea66e`

**步骤**：
1. 确认 `crashkernel reserved: 0x00000000ecc00000 - 0x00000000f0c00000 (64 MB)` ✅
2. `kexec -p /var/tmp/kexec-diag/Image --dtb=/sys/firmware/fdt --append="... maxcpus=1 nr_cpus=1 irqpoll reset_devices panic=10 init=/bin/sh"` → rc=0 ✅
3. `/sys/kernel/kexec_crash_loaded = 1` ✅
4. `echo c > /proc/sysrq-trigger` → 触发

**结果**：
- SSH 连接断开（kernel crash，预期）
- 设备恢复 boot_b（vk64），从 crash 到 vk64 SSH 可达 ≈20–30 s（含 SSH timeout 窗口）
- pstore 空（ramoops 在 crash→ABL→boot_b 路径中丢失）
- 无 ttyGS0 串口观察 → **不确定 crash kernel 是否真的启动了**

**时间推断**：
- crash kernel 若成功启动 → `init=/bin/sh` 无 rootfs → panic → 10s reboot → ABL boot_b。总计 ≈ 3+10+2 = 15s 合理
- crash kernel 若失败 → 系统卡死（hard watchdog disabled）→ 无恢复 → 但设备确实恢复了
- 实际恢复时间无法精确分离（SSH timeout 20s 遮蔽了窗口）

### 结论

| 假设 | 判定 | 依据 |
|------|------|------|
| kexec crash kernel LOAD 路径可用 | ✅ | kexec -p rc=0, kexec_crash_loaded=1 |
| crash kernel 是否成功引导 | **不确定** | 缺串口观察；设备恢复了（可能 crash kernel panic→reboot） |
| crash 路径绕过 device_shutdown 问题 | ✅（机制上） | crash_kexec() 不调用 device_shutdown，代码保证 |
| 目标内核能否在无 device_shutdown 下引导 | **仍不确定** | 需串口证据 |

### 下次推进（串口观察）

需要条件：**OOB 串口（ttyGS0）在 crash kernel 启动时仍有输出**。
方案：vk78 = 同 vk77-modkdump + crash kernel cmdline 改用 `earlycon` + 主机开串口监听 → SysRq-c → 捕获 crash kernel 前 N 行。若主机无 USB 串口转接，可用 `screen /dev/ttyUSB0 115200`（若设备 OOB 串口通过 USB 暴露）。

替代方案（不需物理串口）：
- crash kernel 加 `ramoops`（需在 DTB chosen 里配 ramoops 参数给 crash kernel）
- 或 crash kernel 写文件到 UFS（需挂载，增加复杂度）

### §4 实验附带发现：模块化 boot 状态

vk77-modkdump 模块化验证：
- 内核编译正确（=m），boot.img 正常启动到用户态 ✅
- `lsmod` = 1（空）：持久根 `/lib/modules/` 无此版本 → 模块未加载
- 下一步：`make modules_install INSTALL_MOD_PATH=<linux17>/lib/modules/` + 重启
