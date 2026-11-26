# 取证通道（ramoops/pstore + 串口）实测结论：**本机 DDR 内容不跨复位存活 ⇒ ramoops 不可用作崩溃取证**

> 日期：2026-11-26 09:0x–09:4x（用户放行「可以修复，先修取证」后执行）
> 设备：U2 `HA2EXB0E`，在机日常核 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`
> 结论先行：**ramoops 已注册、panic 能写、但读回来全是垃圾** —— 试了两个基址、开了 ECC（16 B）后
> 两份 dump 都报 **`ECC: 0 Corrected bytes, 780 unrecoverable blocks`** ⇒ 不是「ring 指针错位」也不是「地址选得不好」，
> 是**这段 DDR 内容在复位后整体失效**（最可能是该平台开了 DDR 加密/重初始化）。⇒ **pstore 在本机不能当证据通道**，
> 需要换路线（见 §5）。

---

## 1. 实测矩阵（每条都跑了真机）

| # | 变量 | 结果 | 证据 |
|---|---|---|---|
| 1 | 现状（flashed 日常核，DT 8 MiB @0xc2000000，record/console 2 MiB、pmsg 4 MiB，**ecc 0**） | `ramoops` 注册成功；`/sys/fs/pstore` 空；`/var/lib/systemd/pstore/console-ramoops-0` 108206 B，**内容按字节错乱**（`Li*tx ver3i/n 73.!)dabug` 这种） | `reports/artifacts/evidence-channel-20261126/console-ramoops-0.prev` |
| 2 | 受控 panic（`echo c > /proc/sysrq-trigger`，panic=120） | **串口只到 `sysrq: Trigger a crash`**，之后既无 `Kernel panic - not syncing` 也无栈；设备约 50 s 后被复位（不是 panic=120 的定时）⇒ **panic 路径卡在 ttyGS0 输出**（USB gadget console 在 panic 上下文里写不动） | `/var/log/elden-serial/ttyACM0.log`（09:12:56 段） |
| 3 | cmdline 加 `ramoops.ecc=1 / ramoops.dump_oops=1 / ramoops.max_reason=4` | 参数被**静默忽略**（`ramoops: using 0x800000@0xc2000000, ecc: 0`）—— 本内核 ECC 走 **DT `ecc-size`** 而不是 `ecc` 布尔，且 built-in 驱动以 DT 为准 | `dmesg`（09:06 段） |
| 4 | 改 **boot.img 里的 DTB**：`ecc-size = <0x10>; max-reason = <0x5>;` | 生效：`ramoops: using 0x800000@0xc2000000, ecc: 16`；`/proc/device-tree/.../ramoops@c2000000/` 里确有 `ecc-size`、`max-reason` | `dmesg`（09:33 段） |
| 5 | 开 ECC 后受控 panic（console **只有 tty0**，去掉 ttyGS0） | panic 真跑了（dump 里能抓到 `sysrq` 调用栈片段），**并且 dump 末尾自带 ECC 报告：`ECC: 0 Corrected bytes, 780 unrecoverable blocks`** | `reports/artifacts/evidence-channel-20261126/console-ramoops-0.ecc16` |
| 6 | 换基址重试：ramoops 挪到 **0x88000000**（8 GiB 内存区起点，同样 8 MiB、ecc 16） | 一模一样的 **780 unrecoverable blocks**，且写进去的 marker（`RAMOOPS-PROBE-0x88000000`）读回 **0 命中** | `/tmp/ramoops-addr-probe.sh` 输出；同上目录 |
| 7 | pmsg 通道（写 `/dev/pmsg0`，干净 `systemctl reboot`） | 写 rc=0，重启后 `pmsg-ramoops-0` 内容**不是**我们写的 marker（是远古 initramfs 文本） | `pmsg-ramoops-0.prev` |

## 2. 为什么 780/780 全坏（判读）

- ECC 校验块本身也在这段 DDR 里；若只是 ring 指针错位，ECC 会报「corrected」或分区错位而不会**全部 block 不可恢复**。
- 换基址（0xc2000000 → 0x88000000，跨 1 GiB 以上）结果逐字相同 ⇒ 不是「撞了个坏地址」。
- 与平台特征吻合：SM8750 + Gunyah 保留下（`gunyah-hyp@80000000`），**复位期间 DDR 内容不被保留**（加密/重初始化）。
- 这同时解释了历史现象：`PITFALLS #414/#500/#620` 反复记「pstore 恒空 / 内容是 oops 但判读可疑」——
  之前一直以为是「没触发 dump」，实际是 **dump 写了但读回被毁**。

## 3. 附带修好的东西（仍然有用）

- `/etc/sysctl.d/99-evidence.conf`（设备侧，已落盘）：`kernel.panic=15`、`kernel.panic_on_oops=1`、`kernel.softlockup_panic=1`
  ⇒ 以后「静默冻死」会**变成 panic**（至少面板上能看到栈，人能拍照），而不是无声挂死等长按电源。
  注：`hardlockup_panic`/`hung_task_panic` 在本核**不存在**（`CONFIG_HARDLOCKUP_DETECTOR`/`DETECT_HUNG_TASK` 未开）⇒ 若要 NMI 级看门狗需改内核配置。
- `scripts/serial-cmd.py`：串口交互取证小工具（本轮救援/取证都用它）。
- 保留的零写盘镜像与 sha（`out/evidence-20261126/`，仓外 gitignore 面，仅记账）：

```
3ccdd68b…  boot-evidence-ecc16.img      # cmdline 加 ramoops.*（未生效，留档）
e759edd4…  boot-evidence-dtb-ecc.img    # DTB 加 ecc-size=16 / max-reason=5（生效）
b1e190af…  boot-evidence-tty0only.img   # console 只剩 tty0（panic 能落 dump 的前提）
8aac7d3b…  boot-evidence-ecc.img        # 最早那版（cmdline-only）
```

## 4. 现在的设备状态（已复核）

`systemctl is-system-running` = **running**、`systemctl --failed` = **0**、在机核仍是 flashed 的 `vk189-suspend`（所有实验都是零写盘 `fastboot boot`）。
`hexagonrpcd*` / `iio-sensor-proxy` 仍 **masked**（安全态，见 `reports/sensor-ssc-deploy-20261126.md`）。

## 5. 结论与下一步（取证只能走这三条之一）

| 路线 | 能抓什么 | 代价 | 备注 |
|---|---|---|---|
| **A. 面板 + `console=tty0`（人肉）** | panic/oops 栈（人拍照） | 0（已可做） | 非无人值守；`softlockup_panic=1` 已让它变成 panic |
| **B. kdump / crashkernel（推荐，唯一无人值守可存盘）** | panic、oops、softlockup 的 vmcore（写盘，跨复位存活） | 中：`CONFIG_CRASH_DUMP`+`KEXEC`、reserve `crashkernel=`、装 `kexec-tools`、做 crash 内核 | 项目已有 kexec 经验（§7 M9）；**硬掉电（#692 类）仍抓不到**，但能抓 panic |
| **C. 物理 UART** | 一切（含硬复位前最后一屏） | 高：要拆机找点 | 本机目前无 OOB UART |
| ~~D. ramoops/pstore~~ | ~~一切~~ | — | **已证否：DDR 内容不跨复位存活（ECC 780/780 不可恢复）** |

⇒ 我建议先做 **B（kdump）**：它是唯一能把崩溃现场**自动存到磁盘**的通道，且直接服务于 #692 的二分实验（能抓到 panic 时）
与日常「静默冻死」定位。要我现在就起这条线吗（需要一次内核配置 + 一次 `crashkernel=` 方案验证，全程可用零写盘 fastboot 迭代）。
