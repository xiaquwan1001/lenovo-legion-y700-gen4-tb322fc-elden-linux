# Gunyah capid 与 DT：**节点存在、内容不可读、值不在任何本地固件里**（2026-10-24）

> 目标：拿到 RM 的 capid（`TASKS` §4 N2 唯一硬前置）。
> 做法：按用户批准切 stock Android（a 槽）读 `/proc/device-tree`，之后切回 Linux（b 槽，`boot_b` 已置 succ）。
> 结论：**节点在**（`/hypervisor/qcom,resource-manager-rpc@93ddea6be110409a`），**但 shell 读不到内容**（SELinux），
> 且该节点**不在任何本地固件 blob 里**（静态 DT 只有 `gh-watchdog`）⇒ 值是**启动链运行时生成**的。

## 1. 实测（stock Android 16，`ZUXOS 1.5.10.259`，未 root）

`ls /proc/device-tree/hypervisor`：

```
#address-cells  #size-cells  compatible  name  phandle
qcom,gh-watchdog
qcom,gunyah-vm            → compatible, name, qcom,vendor, qcom,vmid
qcom,resource-manager-rpc@93ddea6be110409a
                          → compatible, interrupts, name, qcom,free-irq-start, qcom,is-full-duplex,
                            qcom,rx-message-size, qcom,rx-queue-depth,
                            qcom,tx-message-size, qcom,tx-queue-depth, reg
```

- **`reg` 就是 capid**（v17/AOSP 的口径：`reg = <capid_tx capid_rx>` 一类）；
- 读内容时 `cat` 一律 `Permission denied`（`ls -l` 也 `-?????????` ⇒ SELinux 拒绝 stat，不是普通 DAC）；
- Android 侧无 `su`（`user` build，`ro.debuggable=0`，2026-10-11 C0 已记）。

**静态 DT 里没有这些节点**：`backup/stock-elden/dtb/10_…SunP_SoC.dtb`（= SM8750P stock DT 转储）
`dtc -I dtb -O dts` 只有 `hypervisor { qcom,gh-watchdog }`，没有 `gunyah-vm` / `resource-manager-rpc`。
`dtbo_a`（32 MB / 76 个 FDT）、`vendor_boot_a`（100 MB）里 `cap_id`/`resource-manager` 全 0 命中。

## 2. 谁在运行时造出这个节点：**厂商 UEFI 的 `RmVmDxe`**

从 `uefi.elf` 第二个内嵌 FV（3 194 888 B，109 个模块）里找到唯一含 `/hypervisor/qcom,resource-manager-rpc` 的模块：

| 项 | 值 |
|---|---|
| 文件 | `/tmp/dxefv2/1d9cc582-DXE_DRIVER-PE32.bin`（57 344 B） |
| 名 | **`RmVmDxe`**（strings 含 `RmVmDxe.c`、构建路径 `…/QcomPkg/Drivers/RmVmDxe/…`） |
| hypercall | `hvc #0x6012`（doorbell）、`#0x601b`/`#0x601c`（msgq send/recv） |
| SCM | 3 处 `smc #0`（`QcomScm` 协议：`ScmSipSysCall` / `HypAssignMem`） |
| 字符串 | `VmGetHypResources` / `VmGetID` / `MemShare` / `FwSetVmFirmware` / `SetFwMilestone` / `Hyp Assign` / `Skipping RmVmProtocol Install` / `Gunyah interface init error` |

⇒ **UEFI 侧自己就是 RM 的客户端**（doorbell+msgq+SCM mem assign），并且它**读写这个 DT 节点**。
节点名后缀 `0x93ddea6be110409a` 在**全部本地固件**（`~/下载/tb322fc/*`、`backup/stock-elden/**`、Mu 仓库）里 **0 命中** ⇒ 不是常量、是运行时生成。

## 3. 这对「拿 capid」意味着什么（三条路，按成本）

| 路 | 做法 | 成本/风险 | 说明 |
|---|---|---|---|
| **A. 零写盘 root 读 DT** | `fastboot boot` 一个 Magisk 打过补丁的 **stock boot_a 镜像**（只 RAM 生效，不写分区）→ `cat /proc/device-tree/hypervisor/.../reg` | 中（要下 Magisk APK + magiskboot）；**零写盘** | 最直接，能同时把 `interrupts`/`free-irq-start`/队列深度全取下 |
| **B. 走厂商 UEFI 引导 Linux** | 用 vendor UEFI（或 Mu）引导内核 → UEFI 的 `RmVmDxe` 会把同一节点补进 DT | 中高（回到 G1-29 UEFI 线，Mu 的 UFS 仍有 issue #12） | 副产品：UEFI 线本来也要解决 |
| **C. 复刻 `RmVmDxe` 的发现逻辑** | 反汇编它拿 cap 的那段（`VmGetHypResources` 前后），看是从 SCM 拿到还是从 XBL 的 `hyp` 配置区读 | 高（纯逆向） | 一旦成功，mainline 可在自己 DTB 里静态补节点 → 最彻底 |

**建议**：先 A（一次拿到真值，后续 port 用它做常量验证），再决定是否 C（为了上游化整洁）。

## 4. 本轮副作用与回退

- 槽切换：`a`（Android 16 正常启动，`getprop ro.product.device=TB322FC`）→ 回 `b`（Linux，SSH 12 s 上线）；
  `qbootctl -m b` 已执行（`SLOT _b: is marked successful`），`boot_b` 不会被扣 retry。
- 只读动作：仅 `ls` / `cat`（后者被 SELinux 拒）/ `tar of /proc/device-tree`（被截断，未用于结论）。
- 产物：`reports/artifacts/gunyah-dt-20261024/`（节点名清单 + 被拒的 cat 输出，作为「不可读」证据）。

## 5. 顺带结论（对 mainline 侧）

- 我们自己的 DTB **不需要**这些节点就能 boot；但 `drivers/virt/gunyah` 移植后**必须**有它们（否则 msgq/dbl 没有 capid）。
- 因此 mainline 侧的 gunyah 驱动接入方式有两条：① DT 里静态写死 capid（如果值稳定）；② 写一个小的 DT fixup（或驱动内 fallback）
  通过 SCM 向 hyp 查询 —— 具体走哪条取决于 A 拿到的值是否每次启动都相同（**下次切 Android 时可直接验证：再读一次比后缀**）。
