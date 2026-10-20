# 用 TWRP device tree 校准我们的刷机/槽位通道 —— 并顺手修好 EDL（2026-10-20）

> 输入：`~/下载/android_device_lenovo_TB322FC-twrp-16.0.1.zip`（成熟 TWRP device tree + 预编译 QTI 二进制）。
> 目的：把我们手写且不稳定的「重启 / 切槽 / 槽计数 / EDL」与设备厂商实现对齐。
> 前置：`reports/lane-reboot2-audit-20261014.md` 已做过一次只读对照（只给方向）；本轮把结论**变成可用实现**。

---

## 0. 数字结论

| 能力 | TWRP/stock 的做法 | 我们的做法 | 判定 |
|---|---|---|---|
| **切槽 / 槽计数** | `libboot_control_qti.so`：GPT attribute byte 6 | `scripts/slot-attr.py`：同一套位定义 | ✅ **逐位等价**（见 §2），无需替换 |
| **重启到 fastboot/recovery** | BCB 写 `/misc` + PMIC SDAM `restart_reason` | PSCI `SYSTEM_RESET2` vendor reset | ⚠️ 机制不同，ABL 对 BCB **实测不采纳**（#88/#143）；我们的通道已能用，但**执行点在 `device_shutdown()` 之后**（#H1 风险） |
| **EDL（9008）** | `TW_HAS_EDL_MODE := true` + qdlrs 外部工具 | **原本判「本机不支持」** | ❌→✅ **本轮修好根因**：DT 缺 `qcom,dload-mode` |
| **recovery** | BCB `boot-recovery` | 无（只能借道 fastboot） | ⏳ 未做，路径依赖 BCB，与上面同一条否决 |

**净结果：4 项里 1 项本来就对（槽位）、1 项机制不同但可用（重启）、1 项找到并修好根因（EDL）、1 项维持不做（recovery）。**

---

## 1. ★ EDL 的真实根因（本轮唯一实质修复）

一直以来的口径是「本机 DT 无 `mode-edl` ⇒ EDL 不支持」。**这个归因是错的**：

- `/sys/module/qcom_scm/parameters/download_mode` 在机上**存在**（值 `off`）⇒ `CONFIG_QCOM_SCM=y` 且该路径编译进去了。
- `drivers/firmware/qcom/qcom_scm.c` 的 EDL 通道**不是** reboot-mode magic，而是：
  - probe 时 `qcom_scm_find_dload_address()` 按 DT `qcom,dload-mode = <&tcsr offset>` 算出地址；
  - `qcom_scm_set_download_mode()` 对该地址做 RMW，写 `QCOM_DLOAD_MASK`（bits 5..4）；
  - 没有该 DT 属性时退回 SCM `QCOM_SCM_BOOT_SET_DLOAD_MODE`；两者都没有就打印
    `"No available mechanism for setting download mode"`。
- 我们的 `sm8750.dtsi` **既没有 `qcom,dload-mode`，也没有 TCSR 块节点** ⇒ 地址恒 0、SMC 兜底也不可用 ⇒ 永远不支持。

**对照证据（三源一致）**：

| 来源 | 内容 |
|---|---|
| 原厂 DTB（`backup/stock-elden/dtb/10_..._SunP_SoC.dtb` 反编译） | `qcom_scm { qcom,dload-mode = <0x02 0x19000>; }`，phandle `0x02` = **`syscon@1fc0000`，reg `<0x1fc0000 0x30000>`** |
| 上游同族 SoC（`kaanapali.dtsi` = SM8750 参考平台） | `qcom,dload-mode = <&tcsr 0x19000>`，`tcsr: clock-controller@1fc0000`，reg `<0x1fc0000 0x30000>` |
| 上游其它族（hamoa / lemans / milos / kodiak） | 同一位置 `0x1fc0000`，窗口 `0x30000` |

**关键辨析**：`sm8750.dtsi` 里已有的 `tcsrcc@f204008`（`compatible = "qcom,sm8750-tcsr", "syscon"`，**窗口只有 0x3004**）**不是**那个 TCSR 块 —— 它是时钟控制器；
`0x19000` 相对它越界（`0xf204008 + 0x19000 = 0xf21d008`）。所以**不能照抄「把 dload-mode 挂到 tcsrcc 上」**。

**修复**（`patches/edl-dload-20261020/`）：

1. 新增 `tcsr: syscon@1fc0000`（`reg <0x1fc0000 0x30000>`）；因为 `qcom,sm8750-tcsr` 这个 compatible 已被时钟节点占用，这里用 `qcom,sm8750-tcsr-mfd` + `syscon`，并在 `Documentation/devicetree/bindings/mfd/qcom,tcsr.yaml` 的枚举里补一项。
2. `scm` 节点加 `qcom,dload-mode = <&tcsr 0x19000>`。

**门（全部主机侧可复现）**：

| 门 | 结果 |
|---|---|
| `make … dtbs` | rc=0；板 DTB 153101 → **153233 B** |
| DTB 反编译核对 | `qcom,dload-mode = <0x15 0x19000>`（phandle 指向新 syscon）✅ |
| `make … CHECK_DTBS=1 qcom/sm8750-lenovo-elden.dtb` | **0 诊断**（先前自造 `qcom,tcsr` compatible 时曾报 `failed to match any schema`，已按正规做法修掉） |
| 设备侧 dry-run（新 `eldroid-bootctl reboot edl --dry-run`） | ✅ 识别到参数文件，当前值 `off` |

**未做**：真机 EDL 触发验证（要刷新 DTB 的内核 + 接受一次进 9008 的风险）。按 `AGENT-OPS` 需先备份、且 9008 后要靠 qdlrs/EDL 才能出来 —— 留作下一步，不在本轮。

---

## 2. 槽位/计数：与 QTI 实现**逐位等价**（不需要换）

`libboot_control_qti.so` 与 QTI 公开头 `gpt-utils.h` 的定义：

```c
#define AB_FLAG_OFFSET (ATTRIBUTE_FLAG_OFFSET + 6)   /* attribute byte 6 */
#define AB_PARTITION_ATTR_SLOT_ACTIVE      (0x1<<2)  /* 0x04 */
#define AB_PARTITION_ATTR_BOOT_SUCCESSFUL  (0x1<<6)  /* 0x40 */
#define AB_PARTITION_ATTR_UNBOOTABLE       (0x1<<7)  /* 0x80 */
#define AB_SLOT_ACTIVE_VAL                 0x3F
```

我们的 `scripts/slot-attr.py`：`AB_OFF = 6`、`ACTIVE = 0x04`、`SUCCESSFUL = 0x40`、`UNBOOTABLE = 0x80`、
`RETRY_MASK = 0x38`（bits 3..5）、`ACTIVE` 时同时置 bits 0..1 —— **逐项相同**。
⇒ 「重置槽位次数」这件事我们**已经**是厂商语义，无需替换实现（TWRP 的 `qbootctl`/`update_slot_attribute` 只是同一套位的另一个实现）。

设备实测（2026-10-20）：`boot_b byte6=0x7f retry=7 active=1 succ=1 unbootable=0`，与 `qbootctl` 读到的
`Current slot: _b / _b: Active 1 Successful 1 Bootable 1` **一致**（两条独立实现互证）。

---

## 3. 重启通道：机制差异与「不替换」的理由

TWRP 用 `property_set("sys.android_reboot", "reboot,bootloader")` → AOSP init：
- `bootloader` → 写 BCB `bootonce-bootloader` 到 `/misc`，再 `ANDROID_RB_RESTART2`；
- `recovery` → 写 BCB `boot-recovery`；
- `edl` → 走 `reboot,edl`（QTI init 扩展，最终仍是 SDAM/SCM dload）。

本机实测：
- BCB `bootonce-bootloader` **未被 ABL 采纳**（#88 已验证；今天实测 `/misc` 首 32 B 就是 `boot-fastboot`，而设备正常从 b 槽 Linux 起来了 ⇒ 该字段即便残留也不决定引导目标）；
- PMIC SDAM `reboot-reason@48` + `nvmem-reboot-mode`（`mode-bootloader=0x02`）**同样未被采纳**（FLASHCTL §8.1）；
- 我们自己的 **PSCI `SYSTEM_RESET2` vendor reset**（`0x80010001/0x2`）是**唯一实测可用**的 Linux→fastboot 通道。

⇒ 「换成 TWRP 的写法」在本机**会退化**（BCB 不被采纳）。真正值得从参考实现借的是两点，本轮已吸收：

1. **EDL 走 `qcom_scm` download_mode 而不是 reboot-mode magic**（§1，已修）；
2. **「先写好引导意图、再复位」的顺序纪律** —— TWRP 也是先写 BCB 再 reboot；我们对应的是
   「先写 `download_mode`，再 warm `RESTART`（不用 `RESTART2`，避免 reason 覆盖）」，已固化进 `eldroid-bootctl`。

**遗留风险（不是本轮引入）**：PSCI 钩子注册在 `restart_handler` ⇒ 执行点在 `device_shutdown()` **之后**；
未就绪/坏显示态下调用会卡死（#225：`uptime<25 s` 2/2 全挂）。`reports/lane-reboot2-audit-20261014.md` §4.2 的
「方向 A：把 vendor reset 提到 reboot notifier」仍未做 —— 这是**替代 TWRP 写法之外仍然值得做的一条**，但改动在关机链，需单独立项。

---

## 4. 产物

- `patches/edl-dload-20261020/0001-arm64-dts-qcom-sm8750-describe-the-TCSR-block-so-EDL.patch`
- `scripts/eldroid-bootctl`：`reboot edl` 从「占位报错」改为真实实现（写 `download_mode=full` → warm reset，含 dry-run 与失败诊断）
- `stock-src/twrp-tb322fc/`：TWRP device tree 解包（只读参考，不入构建）
- 设备 DTB 重建：`build/m1-73` 树，`dtbs` rc=0

## 5. 下一步

1. **真机验 EDL**（需用户同意承担一次 9008）：刷带新 DTB 的内核 → `eldroid-bootctl reboot edl` → `lsusb` 看 `05c6:9008`。
   前提是先把 EDL 出口准备好（`qdlrs`/`edl.py` + `xbl_s_devprg_ns.melf` 等 loader，见 TWRP README）。
2. 若要 **recovery**：本机 ABL 不认 BCB，只能走「fastboot 刷/启 recovery 镜像」；TWRP 已给出可用镜像与分区（`recovery_a/b`，各 100 MiB）。
3. PSCI 钩子提前到 reboot notifier（见 §3 遗留风险），需单独评估 `sync` 语义。

## 6. 关联

- `reports/lane-reboot2-audit-20261014.md`（上一轮只读对照）
- `archive/topics/FLASHCTL-2026-10-03.md`（重启通道史）
- `PITFALLS` #88 / #143 / #225（BCB 不采纳、未就绪窗口卡死）
- `TASKS/README.md` §5 Q23
