# #690 现役主线核（vk192）**没有** vendor RESTART2 钩子 ⇒ Linux→fastboot/EDL 的软路径不存在（旧脚本全部静默空等）

## 现场（2026-11-19 上机实测，设备在 Linux 未动）

发 `ssh elden-root 'sync; systemctl reboot bootloader'`，**设备直接没进 fastboot**（用户观察「设备在 linux 没动」）。
排查顺序与结论：

```
/dev/kallsyms:  psci_sys_reset ✔   psci_system_reset2_supported ✔
                qcom_reboot / vendor reset handler / restart2  ✘（0 命中）
dmesg:          PSCIv1.1 detected；OSI mode supported（= 主线标准 PSCI，不转发 vendor reset_type）
```

即：主线 `psci_sys_reset` 只发 **architectural SYSTEM_RESET**；把 `bootloader`/`edl` 映射成
PSCI `SYSTEM_RESET2` + **vendor reset_type** 的那段是 G1-24 的设备侧钩子（分支 `elden/vk41-psci-reboot`），
**从未进上游、也不在现役 vk192 主线核里**。

## 后果（比"少个功能"更糟的形态）

| 旧入口 | 真实行为 |
|---|---|
| `eldroid-bootctl reboot bootloader` | 该件是 **Alpine 期 python3 脚本，设备上已不存在**（minbase 无 python3） |
| `scripts/to-fastboot.sh` | `… || true` 吞掉 not found ⇒ 干等 fastboot **90 s** 后报 timeout，像 USB/按键问题（实为软路径不存在） |
| `scripts/slot-switch.sh` | 两级兜底都是同一个不存在的件 ⇒ **等效无兜底** |
| `reboot2`（n5b / kexec-bs-cycle / arm-window-hunt / uefi-* 六件） | 同样静默 no-op（死亡率采样循环根本没重启过 ⇒ 那几份历史数据口径要重看） |
| `cycle.sh --soft`（INDEX 快速入口） | 只是 `echo b > /proc/sysrq-trigger`，到不了 ABL |

## 处置（本轮已落）

- `scripts/to-fastboot.sh`：默认**拒绝**软路径并打印手动作业；只有显式 `ALLOW_SOFT_RESET=1`（换回带钩子的核）才发命令。
- `scripts/slot-switch.sh`：Linux 分支同样显式报错 + 手动作业，不再 `|| true`。
- 手动作业（唯一可靠路径）：**长按电源 10 s 关机 → 按住【音量上 + 电源】至 fastboot 屏**；
  EDL 同理（`fastboot oem edl` 只能在 fastboot 里发）。
- 判据写清：**"能软进 fastboot" 只对带 `psci` vendor-reset 钩子的内核成立**，换核/上游化前不要假设。

## 通则

凡是跨「内核能力」的脚本入口（reboot/EDL/suspend/zram…），**先在内核侧取证再写脚本兜底**；
`|| true` 在设备侧命令上是反模式——它把「这条路径不存在」变成「超时」，而超时会被读成硬件问题（#658 的同类）。
