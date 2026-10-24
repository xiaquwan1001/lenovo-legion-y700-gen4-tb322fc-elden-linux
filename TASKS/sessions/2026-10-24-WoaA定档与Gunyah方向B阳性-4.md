# WoaA 路线定档 + Gunyah 方向 B 首轮阳性 + 后台两条备料 lane

- 日期：2026-10-24
- pi 会话 id：$PI_SESSION_ID
- 主题：用户明确目标 = 本机跑 Windows on ARM（Gunyah VM）；先做方向 B 探测，后台派 UEFI/WoA 备料
- 结论（一句话）：**方向 B 阳性 —— Gunyah API v1，doorbell/msgq/vcpu/memextent 四项特性全支持（`flags[0]=0x10010fff`），hypervisor 侧对「起 VM」已无缺口**；剩下唯一硬前置是 **capid 的来源**（只在 stock Android 的 DT 里，本机 mainline DT / `dtbo_a` / `vendor_boot_a` 都没有）。
- 证据指针：`reports/gunyah-rm-probe-20261024.md`、`probes/gunyah-identify/gunyah_identify.c`、
  `reports/artifacts/gunyah-probe-20261024/{identify.txt,gunyah_identify.ko}`
- ★SSOT 待并入：`TASKS/README.md` §4 N2（已就地写）

## 1. 本轮实测（数字）

| 量 | 值 |
|---|---|
| `api_info` | `0x5100000000008001` → **API v1**、64-bit、variant `0x51` |
| `flags[0]` | `0x0000000010010fff` → **DOORBELL=1 MSGQUEUE=1 VCPU=1 MEMEXTENT=1** |
| 调用形式 | `hvc #0x6000` 与 `hvc #0`+`x0=0xc6008000` **返回值完全相同** |

厂商 hypercall 表（反汇编 `backup/stock-elden/vendor_ramdisk/*.ko`）：`gh_ctrl` 0x6000/0x603f、`gh_dbl` 0x6012–0x6015、
`gh_msgq` 0x601b/0x601c、`gh_rm_booster` 0x603d、`gunyah_loader` 0x6045/0x604e–0x6054/0x6063/0x6065（含 VCPU_RUN=0x8065）。
映射规律：产品固件 `hvc #0x60XX` ≡ AOSP fnid `0x80XX`（SMCCC 0xc60080XX）。

## 2. capid 排查结果（下一个必须回答的问题）

| 来源 | 结论 |
|---|---|
| mainline `/proc/device-tree` | 只有 `gunyah-hyp@80000000` 保留区 |
| `reference/stock-elden.dts` | 只有 `gh_watchdog` 引用 |
| `dtbo_a`（32 MB / 76 个 FDT） | `cap_id_low`/`qcom,oemvm`/`gunyah`/`resource-manager` **0 命中** |
| `vendor_boot_a`（100 MB 流式 grep） | 同上；`gunyah` 72 行 = vendor ramdisk 的 `.ko` |
| 厂商模块字符串 | `gh_rm_drv.ko` 有 `qcom,oemvm`/`qcom,trustedvm`/`qcom,owner-vmid`/`cap_id_high`/`cap_id_low` ⇒ **capid 是 DT 属性** |
| stock `boot.img` | 有 `gunyah_rm_call` 等符号 ⇒ stock 内核 gunyah 是 built-in，DT 由 stock 启动链给 |

⇒ 要拿 capid，最省事 = **切 a 槽进 stock Android 一次**（`dtc -I fs /proc/device-tree` 过滤 gunyah），**需用户同意**（不写分区，仅 `slot-switch.sh` 往返）。

## 3. 后台 lane（已派，跑完会通知）

| lane | id | 任务 | 交付 |
|---|---|---|---|
| u1 | `4241566e…` | 重下 UEFI/WoA 资源（`AnyLaySys/edk2-aarch64-gunyah` 等 5 仓）+ 工具链（lld/iasl/nasm/mono/nuget/cargo、UEFITool、uefi_firmware） | `reports/uefi-woa-prep-20261024.md` |
| u2 | `4e427a19…` | WoaA/Gunyah/USB 直通 现状调研（同 SoC 案例、crosvm/qemu-gunyah、capid/RM、最短路径与 3 个二值事实） | `reports/woa-gunyah-survey-20261024.md` |

## 4. 下一步顺序

1.（需用户）切 stock 取 Gunyah DT 节点/capid；2. 同期把 `reference/gunyah-android15-6.6/` 移植进 7.3 树（不需要 capid 也能编译/静态审查）；3. VMM + guest 固件用 lane u1 的产物。
