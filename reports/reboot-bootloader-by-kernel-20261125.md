# vk189/vk192 能不能 `reboot bootloader`：**与内核版本无关**，卡在「systemd → `reboot(2)`」这半段

> 只读历史调查（2026-11-25）。**零 ssh/上机/发信**，唯一改动 = 新建本文件。
> 一句话裁决：**内核版本不是变量**——在机这枚核（UTS `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`）
> 的 config 与已打包 DTB **都带全** reboot-reason 链（`CONFIG_NVMEM_REBOOT_MODE=y` + `/reboot-mode{mode-bootloader=0x02}`），
> 且同一 UTS 的内核在 2026-11-23 已实测进 fastboot（`PITFALLS #712` 行 3/5）；
> 今天「设备没动」= **前半段被吞**（`systemctl reboot bootloader` 在 systemd 257 上位置参数被拒，`reboot(2)` 从未发生），
> 不是「后半段没映射」，也不是缺 PSCI vendor-reset 钩子。

---

## 1. 现场矛盾的解释（先给结论）

| 观察 | 解释 | 证据 |
|---|---|---|
| 今天 `systemctl reboot bootloader` 后 `boot_id` 不变、uptime 连续 | **SoC 根本没复位** ⇒ 失败点在 `reboot(2)` 之前或 `device_shutdown()` 之前 | 判别法见 §4/§5；systemd 257 行为见下 |
| `elden-to-bootloader` 打印「内核 PSCI vendor-reset 钩子: **无**」 | 这只是**能力自检的一行打印**，从 2026-11-23 起就**不是门**（`scripts/elden-to-bootloader.sh:68,73,78`）；无钩子核实测一样进 fastboot | `PITFALLS #712`（`PITFALLS/sessions/345-…:9-16`） |
| `PITFALLS #712` 说 vk192（无钩子）同样进 fastboot | 与今天不矛盾：那几发发的是**带 reason 的 reboot**，且当时位置参数还没被 systemd 拒/或用了新形态 | `PITFALLS/sessions/345-…:31-45` |
| `scripts/to-bootloader.sh` 等 120 s「既没 fastboot 也没回 Linux」 | 三态判据的 rc=11 分支本来就覆盖「设备没动」；它**不会重部署已存在的设备侧工具**，旧副本（11-23 版，位置参数）会复现今天的现象 | `scripts/to-bootloader.sh:69-76`（`test -x` 才部署） |

**决定性的版本事实**：2026-11-24 实机在同一台设备（同一 Debian trixie 根）上抓到
`systemctl reboot bootloader` → `Too many arguments.`、rc=1、**设备不动**；
`systemctl reboot --reboot-argument=bootloader` → rc=0、**~9 s 进 fastboot**。
（`PITFALLS/sessions/345-…:33-45`；`INDEX.md:95`；`scripts/lib-soft-bootloader.sh:4-7`）

⇒ 今天这条命令**恰好就是被 systemd 257 拒绝的那一种写法**。设备没动是「命令没发出去」，与内核无关。

**设备侧旧副本的实锤**：11-23 部署到设备的那版工具（提交 `3a24483f`）里是
`exec systemctl reboot bootloader`（`git show 3a24483f:scripts/elden-to-bootloader.sh:84`，dry-run 打印见 `:80`）；
11-24 才改成 `--reboot-argument` 形态（`git show f349413d:scripts/elden-to-bootloader.sh:86-88`）。
若今天走 `to-bootloader.sh`（它只对**缺失**的工具做部署，`scripts/to-bootloader.sh:69-76`），
旧副本会打印「钩子: 无」然后 `exec` 那条被 systemd 257 拒绝的位置参数命令 ⇒ **完全复现今天的现象**。

---

## 2. 时间线：每一次 `reboot bootloader` 实测

| 日期 | 内核 / vk | 钩子 | 发出的命令 | 结果 | 判据 | 证据 |
|---|---|---|---|---|---|---|
| 2026-10-03 | `vk47clean` `bd114ca33`（`elden/vk41-psci-reboot` 起） | 有 | `reboot2 bootloader` | **22 s 进 fastboot** → `fastboot reboot` 回 Linux | `fastboot devices` 见 `HA2EXB0E` | `TASKS/README.md:48`（G1-24） |
| 2026-10-03 | vk40re（RAM） | 无（当时用 SDAM 路） | `reboot recovery`（同族，SDAM `mode-recovery=0x01`） | **回 Linux**（cell 复位 `0x00`） | 目视「正常重启」 | `archive/topics/FLASHCTL-2026-10-03.md:183` |
| 2026-10-08 起 | 任意带钩子核 | 有 | `eldroid-bootctl reboot bootloader` + `sysrq-b` | 进 fastboot（组合拳） | uptime 归零/`fastboot devices` | `.pi/memory/failures-kernel.md:233,243` |
| 2026-10-24 | Q32 W1 臂（带钩子） | 有 | `eldroid-bootctl reboot bootloader`（`reset_type=0x80010001`） | **2/2 GOOD** | `SYSTEM_RESET2 vendor reset_type=0x80010001` 日志 + 起机 | `reports/q32-matrix-20261024.md:12` |
| 2026-10-31 | 带钩子核 | 有 | `reboot bootloader` | **8–12 s 进 fastboot**，零写盘 | `fastboot devices` | `reports/uefi-swap-x1x2-20261031.md:29,70` |
| 2026-11-08/10 | 带钩子核 | 有 | `ssh … eldroid-bootctl reboot bootloader` | 进 fastboot（UEFI 实验前置） | 运行日志 `ssh -> reboot bootloader` | `reports/uefi-espboot-r58b-success-20261108.md:102`；`reports/artifacts/uefi-boot-20261107-205704/run.log:6` |
| 2026-11-19 | vk192 `7.3.1-debug-vk189-suspend-…` | **无** | `sync; systemctl reboot bootloader` | **设备没动**（当时判「软路径不存在」） | kallsyms 0 个 vendor reset handler + dmesg 无 `SYSTEM_RESET2 vendor` | `PITFALLS/sessions/322-…:3-16`（#690；**结论已作废**） |
| 2026-11-21 | vk192（同上） | 无 | 臂 A：`reboot bootloader`（静态判死，**很可能没真发**）；臂 B：BCB `bootonce-bootloader` | A：无结论；B：**回 Linux**（`uptime 33245 s → 18 s`） | uptime 变小 + 用户目视 | `reports/linux-to-fastboot-20261121.md:9-16`（#701；臂 A 已作废） |
| 2026-11-23 | 7.4-rc3 **带**补丁 | 有 | `reboot bootloader` | **21 s 进 fastboot** | `fastboot devices` | `reports/linux-to-bl-vendor-reset-20261123.md:10` |
| 2026-11-23 | 7.4-rc3 **stash 补丁重编** | 无 | `reboot bootloader` | **进 fastboot** | 同上 | `…:11` |
| 2026-11-23 | **vk192 日常核**（`7.3.1-debug-vk189-suspend…`） | 无 | `reboot bootloader` | **30 s 内进 fastboot** | 同上 | `…:12`；`PITFALLS/sessions/345-…:11` |
| 2026-11-23 | 同上，**同启动内对照** | 无 | 先 `systemctl reboot` → 再 `reboot bootloader` | **回 Linux** → **进 fastboot** | `up 0 minutes`、UTS 不变；第二发 fastboot | `…:13-16`（唯一变量 = cmd 字符串） |
| 2026-11-24 | 同上（systemd 257） | 无 | `systemctl reboot bootloader`（位置参数） | **`Too many arguments.` rc=1，设备不动** | stderr + rc | `PITFALLS/sessions/345-…:35-45` |
| 2026-11-24 | 同上 | 无 | `systemctl reboot --reboot-argument=bootloader` | **rc=0，~9 s 进 fastboot** | `HA2EXB0E` 出现在 `fastboot devices` | 同上 |
| **2026-11-25（今天）** | **在机 UTS 00005** | 无（自检打印） | `systemctl reboot bootloader` | **没重启、没进 fastboot**（`boot_id` 不变、uptime 连续） | 父会话口述（仓库无落盘） | 见 §7「未找到」 |

旁证（同一「没动」形态的历史成因，用来排除误判）：
- `#368`（2026-10-23）：`reboot2 bootloader` **早期下发** ⇒ 进不了 fastboot 且 **USB 全不枚举**，10 min 不恢复，要长按 15 s（`PITFALLS/sessions/63-…:5-9`）。
- `.pi/memory/failures-kernel.md:233,243`：多次 kexec 把 RESTART2/SDAM 写通路写坏后，`reboot bootloader` **干净返回但 uptime 持续增长**（= 命令到了内核、SoC 没复位）；恢复 = `echo b > /proc/sysrq-trigger`。
  ⚠ 这条只对**带钩子核**有意义（钩子在 `psci_sys_reset` 里先发 vendor reset）；今天自检显示无钩子 ⇒ 不适用。
- `.pi/memory/failures-kernel.md:257`：`reboot2` **无参默认 `mode=bootloader`**（Alpine 期件的坑；现役根没有 `reboot2`）。

---

## 3. 依赖链（源码实证）：前半段 / 后半段各自需要什么

### 3.1 全链（在 7.4-rc3 `build/elden-tree` 上逐行核对）

```
systemctl reboot --reboot-argument=bootloader
  └─ logind → reboot(2)  LINUX_REBOOT_CMD_RESTART2 + arg="bootloader"
       kernel/reboot.c:797-805        strncpy_from_user(buffer, arg) → kernel_restart(buffer)
  └─ kernel_restart(cmd)
       kernel/reboot.c:297-308        kernel_restart_prepare(cmd) → … → pr_emerg("Restarting system with command '%s'") → machine_restart(cmd)
        └─ kernel_restart_prepare()   kernel/reboot.c:110-114  blocking_notifier_call_chain(&reboot_notifier_list, SYS_RESTART, cmd)
             └─ reboot_mode_notify()  drivers/power/reset/reboot-mode.c:104-118
                  get_reboot_mode_magic(cmd)   reboot-mode.c:75-100   "bootloader" → magic 0x02
                  reboot->write(reboot, magic) reboot-mode.c:113
                  └─ nvmem_reboot_mode_write  drivers/power/reset/nvmem-reboot-mode.c:30-50
                       nvmem_cell_write(&magic)  → PMIC SDAM cell
        └─ machine_restart(cmd) → do_kernel_restart(cmd) → psci_sys_reset()
             drivers/firmware/psci/psci.c:309-325   **不看 cmd**；发 architectural SYSTEM_RESET（或 warm 的 SYSTEM_RESET2 reset_type=0）
  └─ XBL/ABL 读 PMIC SDAM reboot-reason（DT `mode-bootloader = <0x02>`）⇒ 进 fastboot
```

- **前半段 A（用户态 → `reboot(2)`）**：只依赖 **systemd 版本/命令形态**。systemd ≥257 位置参数被移除，必须 `--reboot-argument=`（`scripts/lib-soft-bootloader.sh:4-7,44-58`）。
- **前半段 B（`reboot(2)` → 内核写 reboot reason）**：依赖 `CONFIG_NVMEM_REBOOT_MODE=y`、DT `/reboot-mode` 节点 + PMIC SDAM cell。**不需要**任何 Qualcomm 私有钩子。
- **后半段（内核 → BL）**：`psci_sys_reset` 只做标准复位（`psci.c:309-325`，`grep -c bootloader drivers/firmware/psci/psci.c` = **0**，2026-11-25 现查），**ABL 只看 SDAM 里的 magic**，不看字符串。
  ⇒ 2026-11-23 报告 `reports/linux-to-bl-vendor-reset-20261123.md:18-23` 写的「ABL 依字符串选路」是**推断且不准确**；准确说法是「kernel 的 reboot-mode 驱动把字符串翻成 magic 写 SDAM，ABL 读 magic」。
- **PSCI vendor-reset 钩子（`patches/kernel-history/*/0003-elden-vk41-…patch` / `patches/local/psci-vendor-reset-20261123/0001-…patch`）**：在 `psci_sys_reset` 里**额外**发 `SYSTEM_RESET2 reset_type=0x80010001`（bootloader）/`0x80000000`（edl）。它是**另一条并行路**，不是进 fastboot 的必要条件（#712 行 2/3 已用「无钩子核」证伪必要性）。

### 3.2 在机这枚核「链是否完整」——静态实证（不用上机）

| 环节 | 现查结果 | 证据 |
|---|---|---|
| 内核身份 | 今天 `uname -r` = `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`，与 `out/boot-elden-vk192.img` 的 `kernel_uts` 逐字相同（`kernel_git_head=4bdf1711b5c0`） | `out/boot-elden-vk192.manifest:7-9,27` |
| config | 该件的 `config_sha256=cbcfd84e0bbf9c8a…` = `patches/config-daily-c3-uinput-20261113` 的 sha256（`sha256sum` 现算） | `out/boot-elden-vk192.manifest:22`；该 config `:4647 CONFIG_POWER_RESET_QCOM_PON=y`、`:4659 CONFIG_REBOOT_MODE=y`、`:4661 CONFIG_NVMEM_REBOOT_MODE=y` |
| DTB | 从 `out/boot-elden-vk192.img` 解出 DTB（magic @ offset 85659648, size 153129）反编译：`/reboot-mode { compatible="nvmem-reboot-mode"; nvmem-cells=<&reboot_reason>; mode-recovery=<0x01>; mode-bootloader=<0x02>; }`；`reboot_reason` = `reboot-reason@48 { reg=<0x48 0x01>; bits=<0x01 0x07>; }` | 本报告 §9 复现命令；对照 `build/elden-tree/arch/arm64/boot/dts/qcom/pmk8550.dtsi:13-19,62-66` |
| 驱动 | `drivers/power/reset/nvmem-reboot-mode.c`（compatible `nvmem-reboot-mode`，`:71`）、`drivers/power/reset/reboot-mode.c`（notifier + mode 匹配，`:75-118,214`） | `build/elden-tree` 现查 |
| PON 节点本身 | `pon@1300` **没有** `mode-*`（`qcom-pon` 自身的 reboot-mode 列表为空，写不写无所谓）；真正写 SDAM 的是 `/reboot-mode`（nvmem 路径） | 解出的 DTB（`pon@1300` 段无 `mode-*`）；`drivers/power/reset/qcom-pon.c:55-93` |

⇒ **结论：今天这枚核的 reboot-reason 链在二进制层面是完整的**；不存在「vk189 少了什么补丁」。

> 注：`out/boot-elden-vk189.img` 的 manifest 是 `00002-g4da9a8b69fc8-dirty`，**与今天的 uname 不符**；
> 「vk189 / vk192」在本项目里是**编号混用**（`INDEX.md:196`、`PITFALLS/sessions/336-…:49`），
> 今天实际跑的就是 UTS 00005 那一支（= manifest 标 vk192 的件）。本报告按 UTS 判定，不按标签。

### 3.3 2026-10-03「SDAM 不采纳」怎么解释（不要让旧结论误导）

`archive/topics/FLASHCTL-2026-10-03.md:183` 写「PMIC SDAM `reboot-reason@48` ❌ 不采纳」，
但**测的 reason 是 `recovery`（`mode-recovery=0x01`）**，不是 `bootloader`（`0x02`）。
同一文档 `:16,25-28` 明确记录：DT 节点、`nvmem-reboot-mode` 驱动绑定、SDAM cell 当时**都在位**。
⇒ 旧结论只能说「**recovery 值**没被 ABL 采纳」，**不能推广到 bootloader**；
`#712` 的同启动内对照（`systemctl reboot` 回 Linux vs `reboot bootloader` 进 fastboot）才是 bootloader 值的直接证据。
（这是本报告的推断：ABL 可能只认 0x02 / 或 `recovery` 那发另有原因；但 bootloader 值有效这点有实测。）

---

## 4. 今天「无反应」是哪一段？可证伪的判断

| 形态 | 判别特征（只读或单条命令） | 归属 |
|---|---|---|
| **① 命令被 systemd 吞掉**（首选） | `systemctl reboot bootloader; echo rc=$?` → stderr `Too many arguments.`、`rc=1`；`journalctl` 无 logind 重启记录；`dmesg` 无 `Restarting system with command` | 前半段 A |
| ② `reboot(2)` 到了内核，但卡在 `device_shutdown()`（DRM/UFS） | `rc=0`（logind 已接受），但 uptime 连续；`dmesg` 有 `[KD] before device_shutdown` 类进度、**无** `Restarting system with command 'bootloader'`；`sysrq-b` 能复位 | 前半段 B |
| ③ 内核写通路 wedged（仅带钩子核，今天不适用） | `rc=0`、uptime 连续，但能用 `sysrq-b` 复位，且复位后**进 fastboot**（SDAM magic 已写、RESTART2 卡住） | 前半段 B（`failures-kernel.md:233,243`） |
| ④ 复位了但 ABL 没选 fastboot | `boot_id` 变、uptime 归零、~25 s 后回 Linux（`systemctl reboot` 现象） | 后半段 |
| ⑤ 进了 BL 但 USB 没枚举 | `boot_id` 变、uptime 归零；`ssh` 断 >30 s；`lsusb -d 18d1:` 空、`/dev/ttyACM*` 无；**用户目视屏上是 fastboot 界面** | 后半段（`PITFALLS` #368；`PITFALLS/sessions/327-…`） |

**今天的证据（`boot_id` 不变 + uptime 连续）直接排除 ④⑤**：SoC 从未复位 ⇒ 不可能是「进了 BL 没枚举」。
在 ①/② 之间，**① 是首选**，因为：
1. 现场用的正是 systemd 257 已实测会拒绝的**位置参数**写法（`345-…:33-45`）；
2. 若是 ②（关机路径挂起），`systemctl` 会 rc=0 且 logind 日志里有「System is rebooting」，多半还能看到 `sync`/`device_shutdown` 尾巴——今天没有这类记录；
3. `to-bootloader.sh` 只在设备**缺**工具时才部署（`scripts/to-bootloader.sh:69-76`），而 11-23 版设备侧工具用的是**位置参数**（`PITFALLS/sessions/345-…:26` 的 `--auto` = `systemctl reboot bootloader`），11-24 的修正**没有证据表明重新部署过**（§7）。

**一次就分清 ①/②/③ 的判据（dmesg 里必须出现/不出现的那一行）**：
- `kernel/reboot.c:306`：`pr_emerg("Restarting system with command 'bootloader'")`。
  这行**出现** ⇒ `kernel_restart()` 已走到 `machine_restart()` 之前（前半段全部完成）。
  下一个 boot 里查：`journalctl -k -b -1 | grep "Restarting system"`（`kmsg_dump(KMSG_DUMP_SHUTDOWN)` 在 `:307`，pstore/ramoops 能留；ramoops 在本核 DTB 里是 8 MiB、`record-size=2 MiB`，见 §9）。
  这行**不出现** + 无 `Too many arguments` ⇒ ②（关机链挂起）；这行不出现 + 有 `Too many arguments` ⇒ ①。

---

## 5. 设备上只读判据清单（不写盘、不重启）

```sh
# 0) 身份（先钉内核，别按标签）
uname -r; cat /proc/version
cat /proc/sys/kernel/random/boot_id; cut -d. -f1 /proc/uptime   # 测前/测后各一次

# 1) 前半段 A：systemd 形态
systemd --version
systemctl reboot --help 2>/dev/null | grep -n -- --reboot-argument   # 有 ⇒ 必须用 --reboot-argument=
command -v reboot; ls -l "$(command -v reboot)"                      # 是否 systemctl 符号链接

# 2) 前半段 B：内核侧 reboot-reason 链
zcat /proc/config.gz 2>/dev/null | grep -E 'CONFIG_(NVMEM_REBOOT_MODE|REBOOT_MODE|POWER_RESET_QCOM_PON)='
ls -l /sys/bus/platform/drivers/nvmem-reboot-mode/                   # 期望 reboot-mode -> …/devices/platform/reboot-mode
cat /sys/class/reboot-mode/nvmem-reboot-mode/reboot_modes 2>/dev/null # 期望 "recovery bootloader"
ls /proc/device-tree/reboot-mode/
od -An -tx1 /proc/device-tree/reboot-mode/mode-bootloader            # 期望 00 00 00 02（BE u32）
od -An -tx1 /proc/device-tree/reboot-mode/nvmem-cell-names           # 期望 reboot-mode\0

# 3) 后半段：PSCI 静态面（只做旁证，不再当门）
cat /proc/sys/kernel/sysrq                                            # 非 0 才能用 sysrq-b 兜底
dmesg | grep -iE 'PSCI|reset2|reboot' | tail -30
grep -cE 'psci_elden_try_vendor_reset' /proc/kallsyms                 # 有钩子核才会 ≥1

# 4) 工具版本（避免旧副本）
sha256sum /usr/local/sbin/elden-to-bootloader; grep -c 'reboot-argument' /usr/local/sbin/elden-to-bootloader
sha256sum /home/xuqianhui/y700-elden/scripts/elden-to-bootloader.sh   # 主机侧比对
```

判读：
- `reboot_modes` 里没有 `bootloader` 或 `nvmem-reboot-mode` 没绑定 ⇒ 前半段 B 断（此时才需要查 DT/config，与内核版本有关）；
- `--reboot-argument` 选项存在但现场用的是位置参数 ⇒ 前半段 A 断（与内核无关）；
- 两段都正常 ⇒ 问题在后半段（ABL/USB），走 §5 的「⑤」判据。

---

## 6. 结论 + 对 M12 上机的建议

**结论**
1. **能不能**：能。在机 UTS 00005 的 config/DTB/驱动链完整；同一 UTS 于 2026-11-23 实测进 fastboot（#712 行 3/5）。
2. **与内核版本有关吗**：**无关**（7.3.1 日常核 / 7.4-rc3 带钩子 / 7.4-rc3 无钩子三种都成功）；**与 systemd 版本有关**（257 起位置参数被移除）。
3. **今天失败在哪段**：**前半段 A**（`reboot(2)` 之前被吞）。可证伪判据 = 原始命令的 stderr/rc + 「`Restarting system with command` 是否出现」（§4）。
4. **要不要补钩子**：不需要。钩子只对 `reboot edl`（TCSR/EDL）可能仍有用，与 fastboot 无关（`reports/linux-to-bl-vendor-reset-20261123.md:38`、`patches/local/psci-vendor-reset-20261123/README`）。

**M12（USB 充电控制链，`TASKS/README.md:519`）上机路径**：
M12 的上机形态是 `fastboot boot` 一个带充电补丁的 boot 件（零写盘），**进 fastboot 这一步不需要重编**——
先把设备上的 `/usr/local/sbin/elden-to-bootloader` 重部署成仓内 2026-11-24 版（或直接
`ssh … 'sync; systemctl reboot --reboot-argument=bootloader'`）即可，~9 s；**补钩子重编纯属浪费**（一次内核重建 + 整套模块部署）；
物理键（长按电源 10 s → **音量下 + 电源**）只留作兜底（`PITFALLS/sessions/322-…` 更正段的口径）。
另：若现场仍看到「设备没动」，**先看那条命令的 rc/stderr**，别再把「没发命令」读成「内核不支持」。

---

## 7. 未找到 / 检索式（诚实边界）

- **未找到** 2026-11-25 今天这发的原始记录（命令全文、stderr、`boot_id` 数值、`dmesg` 尾巴）落盘。
  检索式：`rg -n "boot_id|reboot bootloader|bootloader" reports/*20261125*.md HISTORY/days/2026-11-25.md` → 0 命中。
- **未找到** 2026-11-24 之后对设备 `/usr/local/sbin/elden-to-bootloader` 的**再部署记录**。
  检索式：`rg -n "elden-to-bootloader" reports/ HISTORY/days/2026-11-2*.md .pi/memory/` → 只有 11-21 部署、11-23 部署两处；11-24 提交 `f349413d` 只改仓内脚本。
  ⇒ 设备上副本版本**未知**，§5 第 4 项可现查（`grep -c reboot-argument`：0 = 旧版，即 `3a24483f:scripts/elden-to-bootloader.sh:84` 那种 `exec systemctl reboot bootloader`）。
- **未找到** `vk189`（`00002-g4da9a8b69fc8-dirty`）这枚件的 `reboot bootloader` 实测记录；#712 行 3/5 用的是 **00005**（= 今天的 uname）。
- **未找到** 今天的构建树 `build/daily`（已清理）；因此 §3.2 用 `out/boot-elden-vk192.img` 内**已打包 DTB** 反解代替源码 DTB（这是更强的证据：验的是设备上真正跑的那一份）。
- 没用串口/`pstore` 实证 SDAM 的写入时刻（需上机，按纪律不做）；§3.1 的写入路径是**源码**实证，§3.2 的「链完整」是**产物**实证，两者的连接由 `#712` 的端到端实测兜住。

---

## 8. 引用索引（file:line / commit）

- `PITFALLS/sessions/345-Linux到BL一直可用-推翻只能物理键.md:9-16,26,31-45`（#712 证据矩阵 + systemd 257 补充）
- `PITFALLS/README.md:365,376,386`（#690 / #701 / #712 行）
- `PITFALLS/sessions/322-主线核无vendor-restart2软路径不存在.md:3-16`（#690 现场，已作废）
- `PITFALLS/sessions/63-reboot2早期下发致设备USB不枚举.md:5-9`（#368「USB 全不枚举」前例）
- `PITFALLS/sessions/327-a槽起不来先查boot_a的GPT属性.md`（#695：复位后 60 s 内零 USB 枚举的先例）
- `TASKS/README.md:48`（G1-24）、`:252`（Q23）、`:519`（M12）
- `reports/linux-to-bl-vendor-reset-20261123.md:8-19,38`（#712 报告；`:18-23` 的「字符串」推断本报告修正）
- `reports/linux-to-fastboot-20261121.md:9-16`（#701 三臂）
- `reports/q32-matrix-20261024.md:12`、`reports/uefi-swap-x1x2-20261031.md:29,70`、`reports/uefi-espboot-r58b-success-20261108.md:102`（带钩子核的历史成功）
- `archive/topics/FLASHCTL-2026-10-03.md:16,25-28,183,188`（SDAM/驱动在绑 vs recovery 值不采纳）
- `.pi/memory/failures-kernel.md:233,243`（RESTART2/SDAM 写通路 wedged）、`:257`（`reboot2` 默认 bootloader）
- `scripts/elden-to-bootloader.sh:62-90`、`scripts/lib-soft-bootloader.sh:4-7,44-58`、`scripts/to-bootloader.sh:31,69-76`
- `build/elden-tree`（v7.4-rc3, `aebb727447`）：`kernel/reboot.c:110-114,297-308,776-805`、`drivers/firmware/psci/psci.c:309-325`、`drivers/power/reset/reboot-mode.c:75-118,214-215`、`drivers/power/reset/nvmem-reboot-mode.c:30-50,57,63,71`、`arch/arm64/boot/dts/qcom/pmk8550.dtsi:13-19,62-66`
- `patches/local/psci-vendor-reset-20261123/0001-psci-minimal-SYSTEM_RESET2-vendor-reset-hook.patch`、`patches/kernel-history/elden_vk41-psci-reboot/0003-…patch`
- 提交：`44137cb4e`（钩子进入 `v7.2-elden`）、`3a24483f`（#712 脚本落地，设备侧那版用位置参数）、`f349413d`（systemd 257 形态修正）、`6d6e000a`（fastboot 探测修复）
- `out/boot-elden-vk192.manifest:7-9,22,27`（UTS 00005 + config sha + kernel git head）

---

## 9. 复现命令（本报告静态实证部分）

```sh
cd /home/xuqianhui/y700-elden
sha256sum patches/config-daily-c3-uinput-20261113        # = cbcfd84e0bbf9c8a…（manifest config_sha256）
python3 - <<'EOF'
data=open('out/boot-elden-vk192.img','rb').read(); m=b'\xd0\x0d\xfe\xed'
i=data.find(m); ts=int.from_bytes(data[i+4:i+8],'big')
open('/tmp/vk192.dtb','wb').write(data[i:i+ts]); print(i,ts)
EOF
dtc -I dtb -O dts /tmp/vk192.dtb 2>/dev/null | grep -A7 'reboot-mode {'
dtc -I dtb -O dts /tmp/vk192.dtb 2>/dev/null | grep -A4 'reboot-reason@48'
cd build/elden-tree && grep -c bootloader drivers/firmware/psci/psci.c
```

期望：config sha 命中；DTB 里 `compatible="nvmem-reboot-mode"`、`mode-bootloader=<0x02>`；
`reboot-reason@48 { reg=<0x48 0x01>; bits=<0x01 0x07>; }`；`grep -c` = `0`。
