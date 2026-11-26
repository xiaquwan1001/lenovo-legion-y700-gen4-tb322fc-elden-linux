# #737 · ADSP 一停/一错就**静默硬复位整机**：CDSP 不会；「跑 `-s` 看崩不崩」不能当内核侧判据

- 日期：2026-11-26（22:37–23:12 CST，`out/fastrpc1-20261126/boot-elden-fastrpc1.img` 三次零写盘上机 + 在机 vk192 对照）
- 现象（全部实测，各 2–3 次可复现）：
  1. `hexagonrpcd -f /dev/fastrpc-adsp -d adsp -s`（带 `-s`，真二进制非 wrapper）⇒ **~1–2 s 内 SSH 全断、整机复位**，
     回来自动落在 `boot_b` 在机旧核（`…-00005-g4bdf1711b5c0`）。
     在**打了 2026-10-03 上游 remote-heap 补丁的试验核**上崩（3/3），在**未打补丁的在机 vk192** 上同样崩（1/1）
     ⇒ 该补丁**不改变**这个现象。
  2. `echo stop > /sys/class/remoteproc/remoteproc0/state`（**ADSP**，不跑任何 hexagonrpc）⇒ **同样静默硬复位**（2/2）。
     关键细节：`echo` 那行**自己没返回**（`write-rc` 从未打印）⇒ 卡在 `rproc_shutdown()` 的停止握手里，不是「先 panic 再重启」。
  3. 对照 `remoteproc1`（**CDSP**，空闲）：`stop` → `offline`、`start` → `running`，rc=0，整机无恙 ⇒ **不是「任何 remoteproc 都这样」**。
  4. 不带 `-s` 的 `hexagonrpcd -f /dev/fastrpc-adsp -d adsp` 正常返回 rc=0（打印 `Unexpected buffer count: 1f050100` 后退出），整机无恙。
- 取证结论（为什么「看不到任何内核输出」）：
  - 主机串口 relay（`elden-serial-logger.service` → `/var/log/elden-serial/ttyACM0.log`，`console=ttyGS0`）在崩前**可正常收发**
    （探针 `echo __serialprobe_… > /dev/ttyGS0` 1 s 内落到 relay 文件），崩时**一行都没有**：没有 panic、没有 `Unhandled context fault`、没有 WDT bark。
  - 设备侧 `nohup dmesg -w > /var/log/dmesg-s.log` 在复位后**文件为空**：根分区是写回缓存，**未回写的日志随复位蒸发**（同 #733 的「DDR 不跨复位」）。
  - `journalctl -b -1` 最后一行为复位前数秒的寻常 service 行；`pstore` 空；APSS 硬看门狗在启动时即被禁用（`watchdog: Hard watchdog permanently disabled`）。
    ⇒ 复位发生在 **Linux 之外**（PMIC/引导层看门狗或安全监控强制复位），且**ADSP 侧故障与 ADSP 停止共用这条路**。
- 判据（照抄可用）：
  - 判「ADSP 侧是否出错」**不能**用「跑 `-s` 看崩不崩」：任何 ADSP 故障都会表现为**同样的静默整机复位**，与内核侧改动无关（本次补丁就是活例）。
  - 复现命令（零写盘，复位后自回 `boot_b`，不写任何分区）：
    ```sh
    ssh elden-root 'ls -l /dev/fastrpc-adsp'            # 非 secure 节点在 = DTB 有 qcom,non-secure-domain
    ssh elden-root 'nohup setsid hexagonrpcd -f /dev/fastrpc-adsp -d adsp -s >/dev/null 2>&1 </dev/null &'
    # 之后 2 s 内 ssh 全断、设备自回在机核；串口 relay 无任何输出 = 本条的判据
    ```
  - **危险动作登记**：本机**不要** `echo stop > …/remoteproc0/state`（ADSP）；要验证 stop/start 语义请用 CDSP（remoteproc1）或带 PD 依赖的 PDR 路径。
- 备注：想拿 ADSP 侧证据必须走 **DSP 侧**（ramdump / QMI-PDR 原因）或多留一路**独立于 SoC 复位**的采集（本机 ttyGS0 也随复位断），
  仅靠再加一路 Linux 侧日志（文件/串口）**不可能**——这点已由「串口有产出但崩时零行 + 文件全丢」两侧实测钉死。
