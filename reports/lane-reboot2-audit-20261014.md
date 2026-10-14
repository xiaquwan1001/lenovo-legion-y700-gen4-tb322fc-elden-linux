# reboot2（Linux → bootloader/fastboot）硬卡死审计 — lane-reboot2-audit — 2026-10-14

> 任务：**只读调查**，硬约束：未运行 adb/fastboot/ssh/scp、未写盘、未改仓库任何文件（本报告除外）。
> 结论分级：**已证 / 强候选 / 待查**；每条附「命令+原始输出」或「文件:行号+原文片段」。
> 机型口径：TB322FC = elden = SM8750(P)。

---

## 0. 摘要（先给结论）

1. **机制链已证**：reboot2 走 `reboot(2) RESTART2`，mainline 内核里由 `elden/vk41` 加的**设备侧 PSCI SYSTEM_RESET2 vendor-reset 钩子**把 reason 字符串映射成 SM8750 vendor reset，交 TZ/ABL 进 fastboot。该钩子以 **restart handler**（`priority=129`）注册，因此**在 `device_shutdown()` 之后**才执行。
2. **「整机硬卡死、屏幕+USB 全无响应、只能 POR」与仓内一条已记录现象逐字同型且可重复**：**未就绪（uptime<25 s、桌面未起）时发 `reboot2 bootloader`** ⇒ 全 USB 通道消失（PITFALLS **#225** 2/2 复现、**#143** 同型）。**H1（卡在 device_shutdown/未就绪窗口）为强候选**；**H2（SMC/TZ wedge）同为强候选**。二者只需一条现场证据即可区分（见 §3）。
3. **安全绕过（已证可行）**：物理 POR 是唯一可靠恢复；进 fastboot 前必须过 `scripts/lib-boot-ready.sh` 就绪门（`uptime>=90s` + `phoc/phosh`）；失败即停，禁止无人值守温启循环。
4. **参考实现（TWRP/stock）与我们的做法根本不同**：stock/TWRP 走 **BCB `bootonce-bootloader` 写 misc**（`libboot_control_qti.so`）与 **PMIC SDAM `restart_reason@48`**（`qcom,reboot-reason`）；我们用 **PSCI vendor reset**，绕开了这两条被 ABL 真正读取的通道。

---

## 1. reboot2 完整机制链（逐环节）

### 1.1 用户态：`reboot2 <mode>`（源码 + 部署二进制）

`rootfs/reboot2.c`（全文 44 行）：

- L19：`const char *mode = argc > 1 ? argv[1] : NULL;`
- L21-27：`-h/--help` 返回 2；用法自报 `no argument = normal reboot`、`modes: bootloader|recovery`。
- L29：`sync();`
- L35-37（显式传参）：
  `syscall(__NR_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2, LINUX_REBOOT_CMD_RESTART2, mode);`
- L38-40（无参）：
  `syscall(..., LINUX_REBOOT_CMD_RESTART, 0);` —— 无参**不再**默认 bootloader（#229 的修复）。

部署/构建：

- `rootfs/build-overlay.sh:31-33`：

```
# BusyBox reboot cannot pass a reason string, so "reboot2 bootloader" is the
# only way from this rootfs back into fastboot.
aarch64-linux-gnu-gcc -static -Os -o "$OVL/usr/local/sbin/reboot2" "$R/reboot2.c"
```

- `rootfs/build-rootfs.sh:68`：`aarch64-linux-gnu-gcc -static -Os -o $ROOT/usr/local/sbin/reboot2 $R/reboot2.c`

二进制一致性（主机侧）：

- 命令：`sha256sum rootfs/alpine/usr/local/sbin/reboot2 out/reboot2-fixed`
  输出（两条相同）：`0c68ee5fb3720caa849c7e3fa52d3615da2d4f29bce3b6f91f5f03c8f1294d05`
- `stat`：两者均 `709368` 字节；`strings` 均含 `no argument = normal reboot`。
- ⇒ 仓内**部署件与修复件同 sha**（PITFALLS #229 已收口）；但**设备上实际跑的是哪一版未验证**（见 §5）。

**注意（与 #229 相关）**：PITFALLS #229（`PITFALLS.md:1719`）记旧件为 709320 B、无参=fastboot 的旧构建；凡以裸 `reboot2` 当「普通重启」的脚本会把设备打进 fastboot。这不是本次硬卡死，但会污染现场判定。

### 1.2 内核：RESTART2 → restart handler → PSCI SYSTEM_RESET2 vendor reset

钩子源码 `geekidos-linux/drivers/firmware/psci/psci.c:310-347`（**已证**，当前树与 M1 树同）：

```
310 /*
311  * SM8750 (Lenovo "elden" TB322FC) reboot-mode -> PSCI SYSTEM_RESET2 vendor resets.
...
316  * reset_type/cookie values match the upstream sm8750 DT
...
319  * If the SMC returns (firmware rejected or ignored the vendor reset) we fall
320  * through to the normal reboot path, so an unsupported type cannot wedge boot.
321  */
322 #define PSCI_ELDEN_RESET_TYPE_EDL      0x80000000
323 #define PSCI_ELDEN_RESET_TYPE_BOOTLOADER 0x80010001
324
325 static void psci_elden_try_vendor_reset(const char *cmd)
...
332  if (!strcmp(cmd, "edl")) { reset_type = ...EDL; cookie = 0x1; }
335  } else if (!strcmp(cmd, "bootloader")) { reset_type = ...BOOTLOADER; cookie = 0x2; }
338  } else { return; }
342  pr_info("psci: SYSTEM_RESET2 vendor reset_type=0x%08x cookie=0x%x (cmd=%s)\n",
344  invoke_psci_fn(PSCI_FN_NATIVE(1_1, SYSTEM_RESET2), reset_type, cookie, 0);
346  /* Only reached if firmware did not reset the SoC. */
347 }
349 static int psci_sys_reset(struct notifier_block *nb, unsigned long action,
350        void *data)
351 {
352  if (psci_system_reset2_supported)
353    psci_elden_try_vendor_reset(data);
355  if ((reboot_mode == REBOOT_WARM || reboot_mode == REBOOT_SOFT) && ...) {
362    invoke_psci_fn(PSCI_FN_NATIVE(1_1, SYSTEM_RESET2), 0, 0, 0);
363  } else {
364    invoke_psci_fn(PSCI_0_2_FN_SYSTEM_RESET, 0, 0, 0);
365  }
367  return NOTIFY_DONE;
368 }
370 static struct notifier_block psci_sys_reset_nb = {
371  .notifier_call = psci_sys_reset,
372  .priority = 129,
```

注册点（**已证**）：`psci.c:725` `register_restart_handler(&psci_sys_reset_nb);`（位于 `psci_0_2_set_functions()`）。

**关键执行序（已证）**：

- `kernel/reboot.c:100-106` `kernel_restart_prepare()`：`blocking_notifier_call_chain(&reboot_notifier_list, SYS_RESTART, cmd)` → `device_shutdown();`
- `kernel/reboot.c:287-299` `kernel_restart()`：`kernel_restart_prepare` → `do_kernel_restart_prepare()` → `migrate_to_reboot_cpu()` → `syscore_shutdown()` → `machine_restart(cmd)`
- `arch/arm64/kernel/process.c:130-150` `machine_restart(cmd)`：`local_irq_disable(); smp_send_stop(); ... do_kernel_restart(cmd);`
- `kernel/reboot.c:245-248` `do_kernel_restart(cmd)`：`atomic_notifier_call_chain(&restart_handler_list, reboot_mode, cmd);`

⇒ **`psci_sys_reset`（含 vendor reset 的 `invoke_psci_fn`）是在 `device_shutdown()` / `syscore_shutdown()` 之后才跑**。若 `device_shutdown()` 阶段被卡死，`machine_restart`（以及其中的 vendor reset）**根本不会执行**——设备表现为「无复位」，与「屏幕+USB 全无响应」一致。

内核版本/血缘：

- 提交：`44137cb4e` `elden: vk41 — minimal PSCI SYSTEM_RESET2 vendor-reset hook for reboot bootloader/edl`（`git show --stat`：`drivers/firmware/psci/psci.c | 43 +++++++++`）。
- 含该提交的分支：`v7.2-elden`、`m1/clean-tree`（`git branch -a --contains 44137cb4e`）；工作分支 `elden/vk41-psci-reboot` @ `4b643f169`。
- `clean/base` 也含同钩子（`git show clean/base:drivers/firmware/psci/psci.c` 命中 `psci_elden_try_vendor_reset` 等）。
- **M1 7.3 树同钩子已证**：`build/m1-upstream/clean-tree-73/drivers/firmware/psci/psci.c` 命中 311/315/335/342/344 行同一文本（`grep -n "SYSTEM_RESET2..."`）。

被否掉的旧通道（文档已证，非本次主链）：

- PMIC **SDAM `reboot-reason@48` + `nvmem-reboot-mode`**（DT 绑了 `mode-bootloader=0x02`/`mode-recovery=0x01`，`pmk8550.dtsi:12-17,61`）：实测**未被 ABL 采纳**（`archive/topics/FLASHCTL-2026-10-03.md` §8.1 表）。
- `misc` BCB `bootonce-bootloader` / `boot-recovery`：实测**未采纳**（PITFALLS #88，`PITFALLS.md:877-887`）。

### 1.3 TZ/ABL → fastboot

- `eldroid-bootctl reboot bootloader` 与 reboot2 同语义（`scripts/eldroid-bootctl`，ctypes `libc.syscall(SYS_REBOOT=142, MAGIC1, MAGIC2, RESTART2, reason)`；文件头 docstring 把机制写成 nvmem SDAM，**文档口径已过时**，实际生效的是 PSCI 钩子）。
- 期望结果（历史实测，FLASHCTL §9）：`fastboot devices` → `HA2EXB0E  fastboot`，`getvar current-slot` = `b`，约 22 s 出现。
- 若 SMC 返回（固件不支持/忽略）：钩子注释 L319-320 声称「回退普通重启」。**但该前提只在 SMC 确实返回时成立**；若 SMC 不返回或被固件半处理，注释所说的安全兜底不成立（见 §3 H2）。

---

## 2. 与 TWRP / stock 参考实现的逐项对照

参考源：`/home/xuqianhui1001/下载/android_device_lenovo_TB322FC-twrp-16.0.zip` → 解压 `/tmp/twrp16/android_device_lenovo_TB322FC-twrp-16.0`（**只读分析**；该包是 TWRP device tree + **预编译二进制**，无 Android 系统 init/recovery 源码）。证据方式：`strings -a` 读符号/字符串（非源码级，故部分条目标「推断」）。

| 维度 | 本项目（mainline elden） | TWRP/stock 参考（zip 实测字符串） | 差异/判定 |
|---|---|---|---|
| 请求进 bootloader | `reboot(2) RESTART2 "bootloader"` → **PSCI SYSTEM_RESET2 vendor reset** `0x80010001/0x2` | `libboot_control_qti.so` 导出 `write_reboot_bootloader(...)`，字符串 **`bootonce-bootloader`**、`bootable/recovery/bootloader_message/bootloader_message.cpp` | **完全不同**：参考走 **BCB/misc**，我们走 PSCI。已证 |
| BCB / misc | 曾试写 misc `bootonce-bootloader`，**未采纳**（#88） | fstab 显式挂 misc：`/dev/block/bootdevice/by-name/misc /misc emmc defaults`（`recovery.fstab`） | 参考保留 misc 通道；本机 ABL 对 BCB 不响应。已证 |
| 引导原因持久化 | mainline `nvmem-reboot-mode`（`pmk8550.dtsi:12-17`，写 SDAM）、或 PSCI | stock DT 有 **`qcom,reboot-reason`** 节点消费 **SDAM `restart@48`**（`reference/stock-elden.dts:1835` `restart_reason: restart@48 { reg=<0x48 0x01>; bits=<0x01 0x07>; }`；`:2380-2381` `compatible="qcom,reboot-reason"; nvmem-cells=<&restart_reason>`） | 参考用 **vendor `qcom,reboot-reason` 驱动**写 ABL 真正读的 SDAM 值；mainline 用 `nvmem-reboot-mode` 的 magic，实测未被采纳。已证（DT/字符串） |
| 槽位 active/successful/retry | `scripts/slot-attr.py` 手改 GPT 分区项 attribute byte6（`/dev/sde` LUN4）；或 Alpine 官方 `qbootctl` | `libboot_control_qti.so` 导出 `update_slot_attribute`、`get_partition_attribute`、`gpt_utils_get_partition_map/set_xbl_boot_partition`、`gpt_ufs_bsg`（`ufs_bsg_read/write`）、`multiimgqti` | **机制相同**（均为 GPT attribute + 按盘提交），参考另用 UFS BSG 通道。已证（符号字符串） |
| 进 recovery | 无 recovery vendor reset（FLASHCTL §8.2），只能 bootloader→`fastboot reboot recovery` | BCB 字符串另含 **`boot-recovery`**（同 `libboot_control_qti.so`） | 参考有 BCB boot-recovery；主线的 `mode-recovery`（SDAM）路径未生效。已证 |
| TEE/ABL 依赖 | 依赖 **TZ/ABL 对 vendor reset type 的支持**（未在该机 XBL 上核对 0x80010001/0x2） | TWRP 带完整 QSEE 栈：`qseecomd`、`keymint`/`gatekeeper`(spu)、`sec_nvm`、`spunvm`、`libspukeymint*`；AVB key `testkey_rsa4096`（`BoardConfig.mk` `BOARD_AVB_*`） | 参考强依赖 TEE 做密钥/AVB/解密；我们用 PSCI 绕过引导链，不依赖 TEE 写 key。已证（文件/字符串） |
| EDL | 计划用 vendor reset `0x80000000/0x1`（FLASHCTL §8.2，**未测**） | `BoardConfig.mk`：`TW_HAS_EDL_MODE := true`；README 用 **EDL/qdlrs 写 recovery** | 参考有 EDL 工具链；主线 EDL 未验证。已证/待查（主线侧） |
| 进 fastboot 显示/USB | XBL 负责 fastboot UI + USB 枚举 | 同（XBL/ABL） | 一致 |

结论：**参考实现的「请求进 bootloader」是 BCB（misc）+ vendor `qcom,reboot-reason`（SDAM）两套 ABL 认可通道；本项目用 PSCI vendor reset 完成了同一目标，因此完全绕过了参考通道**。参考通道在本机是否可用，唯 BCB 已实测否定（#88）；vendor `qcom,reboot-reason` 通道本机未复刻验证（**待查**）。

---

## 3. 「为何整机硬卡死（屏幕+USB 全无响应，只能物理 POR）」假设清单

排序 = 可能性。每条给**判定方法**（主机或设备 SSH 下可执行的具体命令）+ **期望输出**。区分 H1/H2 的**唯一黄金证据 = 常驻串口/console 是否出现钩子的 `pr_info`**。

> 判定前置：主机常驻串口 logger：`cat /dev/ttyACM0`（CDC-ACM 内核控制台，`console=ttyGS0,115200`，PITFALLS #254）。**硬卡死现场若串口也静默**，才说明连内核 printk 都出不来。

### H1【强候选】未就绪窗口内 reboot2 → 卡在 `device_shutdown()`/重启路径，vendor reset 从未发出
- 依据：#225（`PITFALLS.md:1690`）「`uptime<25 s` 全挂、`uptime>100 s` 全活」2/2 vs 3/3；#143（`PITFALLS.md:1089`）「90 s 内无 fastboot、SSH 不通、`lsusb` 无 18d1/05c6」；机制上 vendor reset 在 `device_shutdown()` **之后**（§1.2）。
- **判定方法**：
  1. 串口/console 抓复位全过程；复现后检查是否出现 `psci: SYSTEM_RESET2 vendor reset_type=0x00010001 cookie=0x2 (cmd=bootloader)` 或 `Restarting system with command 'bootloader'`。
  2. 未复现时用就绪门对照：`cut -d. -f1 /proc/uptime` + `ps -eo comm | grep -cx phoc`（复刻 `scripts/lib-boot-ready.sh` 判据）。
- **期望输出**：H1 成立 ⇒ **无** `pr_info`、**无** `Restarting system` 行；console 停在 device shutdown 早期或 DRM/USB 相关点。就绪态（uptime>120 s、桌面在）对照 ⇒ 出现 `pr_info` 且约 22 s 进 fastboot。

### H2【强候选】SMC/TZ vendor reset 被「半处理」：SMC 不返回或返回后仍不复位 → SoC 被 TZ 卡住
- 依据：钩子注释 L319-320 假设「返回即安全回退」，但**未验证该机 TZ 对 `0x80010001/0x2` 的行为**；reset_type/cookie 取自上游 sm8750 DT（L316-317），非本机实测。
- **判定方法**：console 已出现 `psci: SYSTEM_RESET2 vendor reset...` 行之后再看 2 分钟；同时主机 `lsusb` 轮询（`for i in $(seq 1 60); do date; lsusb | grep -iE '05c6|18d1'; sleep 2; done`）。
- **期望输出**：H2 成立 ⇒ `pr_info` 有、之后**完全静默、无复位**；`lsusb` 全程无 05c6/18d1（连 EDL 9008 也没有）；设备不重启。
- **亚型 H2b**：vendor reset 被接受但 reset_type/cookie 语义错误（未进 fastboot 也未回退普通重启）。

### H3【候选】复位实际落成断电/halt，USB 未把设备叫醒（#151 的竞争解释）
- 依据：#151（`PITFALLS.md:1169`）「`/sbin/reboot` 包装 → openrc halt → USB VBUS 自动开机」；审计文档也列此竞争解释（`reports/audit-early-reboot-20261012.md:71`）。
- **判定方法**：① 手感/热像判断是否**已断电**（无发热、USB 口无电流）；② 长按电源 20 s 后再短按：若**立即**点亮 = 之前是断电；③ 主机 `dmesg` USB 端口掉线时刻 vs 设备是否重新枚举。
- **期望输出**：H3 成立 ⇒ 设备无发热、立刻可再上电；`lsusb` 无枚举（因为已断电）。**注意区分**：H1 是内核存活但未复位（会发热/无复位）。

### H4【候选】坏显示态下的 DRM cleanup 卡死（#166/#253 族）
- 依据：`scripts/arm-window-hunt.sh` 的 `to_fastboot()` 注释直接写「显示坏态下 reboot2 会挂 DRM cleanup（PITFALLS #253）」；#253（`PITFALLS.md:1852`）实测 `reboot`/`reboot2`/`eldroid-bootctl reboot system` 全挂在 DRM cleanup（进程不退、uptime 继续涨）；#166（`PITFALLS.md:1239`）reboot2=暖复位不清 DSI PHY/PLL。
- **判定方法**：复位前在设备上 `dmesg | grep -cE 'vblank wait timed out|command DMA timeout|Failed to initialize panel'`；对照 `scripts/q28-devprobe.sh` 三态。
- **期望输出**：H4 成立 ⇒ storm 签名 >0；此时**任何软复位都不可靠**，只能物理 POR（#150/#170 纪律）。

### H5【候选】XBL/ABL fastboot 阶段 USB/显示初始化挂起（PHY/eUSB2 残留态）
- **判定方法**：等待期换另一台主机/OS 观察枚举；拔插 USB；观察 60–90 s 内是否偶发出现 `fastboot devices`。
- **期望输出**：H5 成立 ⇒ 重插/换主机后可能枚举成功（说明设备到了 fastboot，只是本机枚举失败）；否则 H1/H2。

### H6【待查】现场身份：设备上 reboot2 版本 / 现役内核是否含 vk41 钩子
- **判定方法**：设备 `reboot2 -h`（自报 `no argument = normal reboot` 即修复版）；`uname -r`；`dmesg | grep 'SYSTEM_RESET2 vendor reset'`（有过则含钩子）。
- **期望输出**：若设备跑旧构建或无钩子内核，则本次「reboot2」机制与本文 §1 不同（旧构建无参=fastboot，见 #229），需另判。

---

## 4. 结论：安全绕过 + 若要修的最小改动方向

### 4.1 主会话应如何安全绕过（**已证可行**，本会话已临时停用该路径）

1. **恢复唯一可靠手段 = 物理 POR**（长按电源 20 s；**别带音量键**，否则又进 fastboot，PITFALLS #143 末句）。
2. **进 fastboot 只用「就绪 + 单发」**：
   - 复位前过 `scripts/lib-boot-ready.sh:boot_ready_or_die`（SSH 现问现答 + `uptime>=90 s` + `phoc/phosh` 已起，fail-closed；逃生阀 `ELDEN_FORCE_REBOOT=1`）。
   - 就绪窗口（实测 `uptime>100–138 s`、桌面已起）执行 `reboot2 bootloader` 单发（#225：>100 s 3/3 全活）。
   - **失败即停**，不要连打、不要无人值守循环（#143 纪律）。
3. **已在 fastboot 时**用 `fastboot reboot bootloader` 清脏态（#4）；离开 fastboot 用 `fastboot reboot`。
4. **不要在坏显示态/storm 态发任何软复位**（#150/#253）：改用 `echo b > /proc/sysrq-trigger` 或直接物理 POR。
5. 自动化脚本：把就绪门接在**所有** `reboot2` 之前（`q28-boot-cycle.sh`/`q28-layout-*.sh` 已接；`to-fastboot.sh`/`slot-switch.sh` 等仍缺，`reports/audit-early-reboot-20261012.md:113-115` 已列出待接清单）。

### 4.2 若要修：最小改动方向（**只给方向，未直接改文件**）

- **方向 A（内核，针对 H1，最小）**：把 vendor reset 的触发点从 **restart handler** 提到 **reboot notifier**（`register_reboot_notifier`，在 `device_shutdown()` 之前），使 `device_shutdown()` 卡死时 vendor reset 仍能发出。对应代码 `geekidos-linux/drivers/firmware/psci/psci.c:325-372`。风险：绕过关机链（与 #150 经验一致），需评估存储 `sync` 语义（reboot2 已在 L29 `sync()`）。
- **方向 B（内核，上游规范形态）**：改用上游 `psci-reboot-mode` 驱动 + DT `reboot-mode { mode-bootloader=<0x80010001 0x2>; mode-edl=<0x80000000 0x1>; }`（FLASHCTL §2 列出 13 补丁系列，7.2 未合并）；把 reset_type/cookie 与**本机 XBL 实测**对齐（现值取自上游 sm8750 DT，未本机核对）。
- **方向 C（对齐 stock，针对 H2/ABL 语义）**：复刻 stock 的 **`qcom,reboot-reason` → SDAM `restart@48`** 通道（`reference/stock-elden.dts:1835,2380`），确认 ABL 真正读取的 cell/值；与现有 `nvmem-reboot-mode`（未被采纳）区分开。可先只读验证 ABL 是否读该 cell。
- **方向 D（兜底）**：内核/引导级超时兜底（用户态看门狗覆盖不了硬卡，见 #231 对 #228 的更正）。
- **上线纪律**：任何内核改动先在就绪窗口**单发冒烟**（串口常驻，确认 `pr_info` + ~22 s 进 fastboot）再考虑自动化；改动前小样本编译（#256 教训）。

---

# 编排者独立复核（2026-10-14，主会话）

> 本文件由子代理 `ustc-pool/ustc-research`（run `b992b63e…`）产出；以下为编排者**独立重跑/重读**的核对结果，不采信自报。

## 已由编排者独立确认

1. `rootfs/reboot2.c`：`syscall(__NR_reboot, MAGIC1, MAGIC2, LINUX_REBOOT_CMD_RESTART2, mode)`；无参 = 普通 restart（文件内自带 SAFETY 注释）。✅ 与子代理一致。
2. 内核钩子（`geekidos-linux/drivers/firmware/psci/psci.c`）：`PSCI_ELDEN_RESET_TYPE_BOOTLOADER 0x80010001`（:323）、`pr_info("psci: SYSTEM_RESET2 vendor reset_type=…")`（:342）、`invoke_psci_fn(SYSTEM_RESET2…)`（:344）、注释「Only reached if firmware did not reset the SoC」；`register_restart_handler(&psci_sys_reset_nb)`（:725，`.priority = 129` :372）。**三树同段**：`geekidos-linux` / `build/m1-upstream/clean-tree-73` / `build/m1-upstream/clean-tree` 各命中 1 处。✅
3. **★顺序（结构性根因，子代理列为 H1，我把它坐实为机制）**：`kernel_restart()`（`kernel/reboot.c:287`）先 `kernel_restart_prepare()` → `blocking_notifier_call_chain(&reboot_notifier_list)` + `usermodehelper_disable()` + **`device_shutdown()`**（:100-106），随后 `syscore_shutdown()`，最后 `machine_restart(cmd)` → `do_kernel_restart(cmd)`（:245 → `atomic_notifier_call_chain(&restart_handler_list…)`，`arch/arm64/kernel/process.c:130-149`）。⇒ **vendor reset 是 restart handler，永远排在 `device_shutdown()` 之后**；只要 `device_shutdown()`（显示/DRM/GPU 清理，见 `PITFALLS #253`、GUI 卡死 `#106`）或 `syscore_shutdown()` 挂住，SMC **根本不会发出** ⇒ 设备表现为「屏幕冻在当前画面 + USB 全无响应」，只能 POR。**这与用户 2026-10-14 复现的症状（屏幕停在桌面加载初期、USB 全无）逐项吻合。**
4. `machine_restart()` 末尾：若 `do_kernel_restart()` 返回（固件未复位），内核打印 `Reboot failed -- System halted` 并 `while(1)` 死循环（中断已关）⇒ **另一条同症状路径（子代理 H2）**。区分判据 = 冻结点屏幕/串口是否出现该行：**出现 ⇒ H2（SMC 返回不复位）；不出现 ⇒ H1（卡在 device_shutdown 之前）**。
5. `PITFALLS #225`（未就绪发 reboot2 ⇒ 全 USB 通道消失；uptime<25 s 2/2 挂、>100 s 3/3 活）逐字存在，与本节结论同向；`#143` 同型。
6. TWRP 参考包：`recovery/root/vendor/lib64/libboot_control_qti.so` 存在，字符串含 `bootloader_message`/`BootloaderControl*LECRC`/`*MiscVirtualAb*` ⇒ stock/TWRP 侧走 **misc BCB + GPT slot 属性**通道（子代理「字符串级」限定属实）。`reference/stock-elden.dts` 只有 `sdam@7000`…（未见 `qcom,reboot-reason` 直命中，子代理给的 1835/2380 行号**未复现**，标「待查」）。

## 我**无法**确认（与子代理 §5 一致，并补充）

- 仓内 **没有任何** console 日志包含 `SYSTEM_RESET2 vendor reset` 行（4 份近期 M1 串口日志全 0）⇒ 缺**正向对照**，因此「冻结时是否发出过 SMC」目前**无直接证据**（既有日志的 reader 都已在 reboot2 之前关闭）。要定 H1/H2 必须在**串口 reader 存活**时故意复现一次。
- 子代理列出的设备侧二进制身份、TZ/ABL 实际行为未验证。

## 结论与处置

- **主会话处置（已执行，用户指示）**：停用 `reboot2 bootloader` 进 fastboot，一律物理 POR；`scripts/arm-window-hunt.sh:to_fastboot()` 不再使用；项目记忆已记。
- **最小修法方向（不改设备，先设计）**：① 把 vendor reset 提到 **reboot notifier**（`kernel_restart_prepare()` 内、`device_shutdown()` 之前），代价=跳过干净卸载（对「进 fastboot」这是期望行为，且 `reboot2` 已 `sync()`）；② 或改用 stock 通道（misc BCB `bootonce-bootloader` / SDAM `restart@48`），使复位不依赖内核清理路径；③ 或切上游 `psci-reboot-mode`（需核对其是否同样落在 restart handler —— 若同，则不解决本问题）。
- **待做（需用户 POR 兜底）**：串口 reader 存活下故意 `reboot2 bootloader` 一次，取「有无 `SYSTEM_RESET2 vendor reset` 行 / 有无 `Reboot failed -- System halted`」以定 H1/H2；再据此实现修法。

## 5. 我没有验证 / 无法验证的点（明确列出）

1. **未接触设备**（硬约束）：无法确认
   - 设备上 `/usr/local/sbin/reboot2` 的实际 sha（是否修复版）、
   - 现役内核是否含 vk41 钩子（`dmesg` 有无 `SYSTEM_RESET2 vendor reset` 行）、
   - 硬卡死瞬间的 console/dmesg 内容、`lsusb` 枚举、发热/电流、`uptime`。
2. **无法区分 H1 / H2**：缺现场串口证据；本文只给出判定方法，未执行。
3. **未验证 TZ/ABL 对 `0x80010001/0x2` 的实际处理**（是否返回、是否复位、是否进 fastboot）。
4. **未验证 #151 的 VBUS 竞争解释**，也未复现 #225 的 `uptime` 因果对照（该对照仅本仓一次会话记录）。
5. **TWRP 参考是从预编译二进制 `strings` 推断**（符号名 + 字符串），非源码级；zip 内**没有** stock 系统 init/recovery 源码，也没有 `qbootctl` 源。
6. **未确认 stock 系统 `adb reboot bootloader` 究竟走 BCB 还是 IMEM/`restart_reason`**；TWRP 里只见 BCB 路径（`write_reboot_bootloader`）。
7. **未确认 misc/BCB 在主线下的写路径与 ABL 采纳条件**（#88 已实测「不采纳」，但未穷举其它 BCB command/值）。
8. **未验证 `reboot2`/`eldroid-bootctl` 的 `reason` 字符串与内核钩子的完整匹配边界**（如 `recovery` 在钩子里直接 `return`，只落到普通/暖复位）。

---

## 附：本次只读命令清单（可复核）

- `sha256sum rootfs/alpine/usr/local/sbin/reboot2 out/reboot2-fixed`
- `grep -n "" rootfs/reboot2.c`；`grep -n "reboot2" rootfs/build-overlay.sh rootfs/build-rootfs.sh`
- `sed -n '308,372p' geekidos-linux/drivers/firmware/psci/psci.c`；`grep -n "register_restart_handler|do_kernel_restart|kernel_restart_prepare" -r kernel/reboot.c arch/arm64/kernel/process.c`
- `grep -n "SYSTEM_RESET2|mode-bootloader" build/m1-upstream/clean-tree-73/drivers/firmware/psci/psci.c`
- `git log --oneline --all | grep 44137cb4e`；`git show --stat 44137cb4e`
- `grep -nE "^ (88|143|150|151|166|215|225|228|229|253)\\. \\*\\*" PITFALLS.md`
- `unzip -o ... /tmp/twrp16`；`strings -a libboot_control_qti.so | grep ...`；`sed -n` 读 `BoardConfig.mk`/`recovery.fstab`/`init.recovery.qcom.rc`
- `grep -n "restart_reason|reboot-reason" reference/stock-elden.dts`
