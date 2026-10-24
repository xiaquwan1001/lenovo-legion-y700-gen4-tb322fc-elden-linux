# Gunyah RM 探测（方向 B 首轮）：**API v1 + doorbell/msgq/vcpu/memextent 全在**（2026-10-24）

> 目标（用户 2026-10-24 定）：**在这块板子上跑 Windows on ARM**；同芯片其他平板已有先例，开源项目正在做（`AnyLaySys/edk2-aarch64-gunyah` 等）。
> 路线 = Gunyah 上起 VM（不是裸机 UEFI 直启）。本文件只回答第一个二值问题：**RM 通道在不在**。
> 前序：`reports/gunyah-stage0-positive-20261024.md`（已在 Gunyah guest 里 + SMCCC 可用）。
> 产物：`reports/artifacts/gunyah-probe-20261024/{identify.txt,gunyah_identify.ko}`；探针源码 `probes/gunyah-identify/gunyah_identify.c`。

## 0. 结论（先数字）

| 量 | 实测值 | 含义 |
|---|---|---|
| `api_info` | `0x5100000000008001` | **API version = 1**、`is_64bit=1`、`big_endian=0`、`variant=0x51`(81) |
| `flags[0]` | `0x0000000010010fff` | 位 1/2/5/6 全置：**DOORBELL=1 MSGQUEUE=1 VCPU=1 MEMEXTENT=1** |
| `flags[1]` | `0x0000000000000002` | 保留/扩展位 |
| `flags[2]` | `0` | — |
| 调用形式 | `hvc #0x6000` **与** `hvc #0`+`x0=0xc6008000` **都返回同一组值** | 产品固件同时接受 integrity 形式与 SMCCC 形式 |

**⇒ hyp 层把 VM 生命周期需要的四件套（doorbell / msgq / vcpu / memextent）全部声明为支持**；
「Gunyah 上跑 VM」在**hypervisor 侧没有任何缺口**，剩下的全是 Linux 侧（capid 获取 + 驱动 + VMM + guest 固件）。

## 1. 探针做法（只读、无副作用）

`probes/gunyah-identify/gunyah_identify.c`：`insmod` 时调一次 **HYP_IDENTIFY**（不需要任何 capability）→ 打印 api_info/flags → 模块立即返回 0（不常驻）。

- 为什么安全：厂商自己的 `gh_ctrl.ko` 在 probe 阶段就调 `hvc #0x6000`（`backup/stock-elden/vendor_ramdisk/gh_ctrl.ko` 反汇编 `98: d40c0002 hvc #0x6000`），
  在同一台机器上跑了整个 Android 生命周期 ⇒ 该调用**已证明无副作用**。
- 设备侧证据：`reports/artifacts/gunyah-probe-20261024/identify.txt`（原始 dmesg，含两条调用形式的返回值）。
- 构建配方与坑见 `PITFALLS #381`；模块 vermagic 与在机 `uname -r` 逐字一致。

## 2. 厂商 hypercall 表（反汇编 `backup/stock-elden/vendor_ramdisk/*.ko` 得到）

| 模块 | `hvc #` 立即数 | 对应 AOSP fnid | 语义（AOSP 命名） |
|---|---|---|---|
| `gh_ctrl` | `#0x6000`、`#0x603f` | 0x8000、0x803f | HYP_IDENTIFY、… |
| `gh_dbl` | `#0x6012` `#0x6013` `#0x6014` `#0x6015` | 0x8012–0x8015 | BELL_SEND / BELL_SET_MASK 等 |
| `gh_msgq` | `#0x601b` `#0x601c` | 0x801b、0x801c | **MSGQ_SEND / MSGQ_RECV** |
| `gh_rm_booster` | `#0x603d` | 0x803d | — |
| `gunyah_loader` | `#0x6045 #0x604e–0x6054 #0x6063 #0x6065` | 0x8045–0x8065 | VM 生命周期 / VCPU_RUN(0x8065) 等 |

**映射规律**：产品固件用 `hvc #0x60XX`，其中 `XX = (AOSP fnid & 0xffff) - 0x8000 + 0x6000`。
（本轮实测两种形式返回值完全相同 ⇒ 后续移植可直接用上游 `arm_smccc_1_1_hvc()`，不必写裸 asm。）

## 3. RM 的 capid 从哪来（**下一个必须回答的问题**）

cap 不是算命得来的，必须由平台给出。已排查：

| 来源 | 结果 |
|---|---|
| 本机 mainline DT（`/proc/device-tree`） | 只有 `reserved-memory/gunyah-hyp@80000000`，无 msgq/dbl 节点 |
| `reference/stock-elden.dts`（stock 内核 DT 转储） | 只有 `pmic-pon-log: depends-on-supply = <&gh_watchdog>`，无 RM 节点 |
| **`dtbo_a` 分区**（设备上 dd 下来 32 MB，76 个 FDT） | `qcom,oemvm` / `cap_id_low` / `gunyah` / `resource-manager` **全 0 命中** |
| **`vendor_boot_a` 分区**（100 MB 流式 grep） | `cap_id_low`/`resource-manager` 0 命中；`gunyah` 72 行（= vendor ramdisk 里的 `.ko`，已备份） |
| 厂商模块字符串 | `gh_rm_drv.ko` 含 `qcom,oemvm` / `qcom,trustedvm` / `qcom,cpusysvm` / `qcom,owner-vmid` / `qcom,image-name` / `qcom,peers` / `cap_id_high` / `cap_id_low` ⇒ **capid 是 DT 属性** |
| stock `boot.img` | 含 `gunyah_rm_call`、`gunyah_rm_notifier_register`、`gunyah-resource-manager` 等符号 ⇒ **stock 内核里 gunyah 是 built-in**，其 DT 由 stock 启动链提供 |

**结论**：capid 在 **stock Android 启动时的 DT** 里（我们 mainline 启动用的是自己的 DTB，所以看不到）。
下一步最省事的三条取证路径（按成本）：

1. **进 stock Android 一次**（切 a 槽），`adb shell su -c 'dtc -I fs -O dts /proc/device-tree' | grep -n -A8 -i 'gunyah\|resource-manager'` —— 直接拿到节点与 capid（**需用户同意切槽**，不写分区）。
2. 从 `xbl_s.melf` / ABL 里找 UEFI 传给 Linux 的 DTB（XBL 打包体，成本较高）。
3. 反汇编 stock 内核里的 `gunyah_rm_call` 调用链，看它读的 compatible/属性名（`cap_id_high/low` 已给出），再据此在我们 DTB 里**手工补节点 + 猜 capid 位域**（不推荐，capid 是整数句柄，猜不中）。

## 4. 对 WoaA 路线的影响（口径）

- **hypervisor 侧：无缺口**（本轮闭环）。原来「找不到 Gunyah、无法立项」的判断正式作废。
- **Linux 侧缺口清单**（都可自建）：capid 获取 → `drivers/virt/gunyah` 移植（源码已在 `reference/gunyah-android15-6.6/`，~4.4 kLOC）→ RM RPC 打通 → VMM（crosvm / `qemu-for-gunyah`）→ guest 固件（`AnyLaySys/edk2-aarch64-gunyah`，已派后台 lane 下载）。
- **仍要回答的 3 个二值事实**（后台调研 lane 正在做）：① 同 SoC 是否已有「Windows on ARM 跑起来」的公开案例与其虚拟化方式；② Gunyah 下 USB 直通怎么实现（crosvm usb 后端 / virtio-usb / SCM mem-lend + DT 直通）；③ 受保护 VM 是否必需（Windows 不是 protected VM，理论上走 unprotected）。

## 5. 复现

```bash
# 设备侧（模块已在产物目录）
scp reports/artifacts/gunyah-probe-20261024/gunyah_identify.ko root@192.168.7.1:/tmp/
ssh root@192.168.7.1 'insmod /tmp/gunyah_identify.ko; dmesg | grep gunyah_identify; rmmod gunyah_identify'
# 厂商 hypercall 表
for m in gh_ctrl gh_dbl gh_msgq gh_rm_booster gunyah_loader; do
  printf "%-18s " $m; aarch64-linux-gnu-objdump -d backup/stock-elden/vendor_ramdisk/$m.ko |
    grep -oE 'hvc\s+#0x[0-9a-f]+' | awk '{print $2}' | sort -u | tr '\n' ' '; echo; done
```
