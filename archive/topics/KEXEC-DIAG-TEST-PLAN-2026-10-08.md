# KEXEC-DIAG-TEST-PLAN-2026-10-08：vk65 诊断内核上机方案（P0 阶段二分）

> 承接 `KEXEC-ONDEVICE-R2-2026-10-05.md`。目标：不用 UART，用「阶段标记 + 本地落盘」把
> TB322FC `kexec -e` 的静默掉电点定位到 **notifier / device_shutdown / syscore** 三段之一。

---

## 0. 判据（掉电点定位）

`kernel_kexec()` 非 preserve_context 路径的实际顺序（本内核 `kexec_core.c` + `reboot.c`）：

```
stage=10  enter kernel_kexec
          kernel_restart_prepare("kexec reboot")
stage=11a   before device_shutdown      ← 网络 teardown 在此之前的 reboot_notifier 已跑完
stage=11b   after  device_shutdown
stage=12  after migrate_to_reboot_cpu
stage=13  before syscore_shutdown
stage=14  after  syscore_shutdown
          pr_notice("Starting new kernel")   ← R1/R2 从未见到 = 掉电在其之前
```

`kmsg_dump` 在整个 else 块之外（machine_kexec 前才调），故掉电在 syscore 内时 pstore 也拿不到 —— 这解释了 R1 的 `dmesg-ramoops-0` 空。

**读 `kmsg-diag.log` 最后一行 `[KD] stage=` 即定位：**
| 最后标记 | 结论 | 下一步 |
|---|---|---|
| 停在 `stage=10`/无 11a | notifier 链里掉电（SYS_RESTART 回调） | 逐个 `pr_info` 拆 notifier |
| 停在 `stage=11a` | `device_shutdown()` 内掉电 | 见 §3 设备级二分 |
| 停在 `stage=11b`/`12` | migrate/CPU offline 附近 | 查 PSCI CPU_stop |
| 停在 `stage=13` | `syscore_shutdown()` 内掉电 | m2 跳过验证 |
| 走到 `14` 且见 `Starting new kernel` | 掉电在 machine_kexec 之后 | 跳 trans_pgd/二阶段 |

---

## 1. 测试矩阵（4 个 boot.img，仅 cmdline 差别，全部零写盘）

内核同源 commit `6cbe1ffa7`（exp(kexec) diag hook），镜像 `out/boot-elden-vk65-m{0,1,2,3}.img`。

| 变体 | `kexec_dbg` | 作用 | 期望产出 |
|---|---|---|---|
| **m0** | 0 | 不跳任何阶段，只打 `[KD]` 标记 | **首选**：定位最后到达的 stage |
| **m2** | 2 | 跳 `syscore_shutdown` | 若 m0 停在 13 → m2 应能 kexec 成功 |
| **m1** | 1 | 跳 `device_shutdown` | 若 m0 停在 11a → m1 应能 kexec 成功 |
| **m3** | 3 | 两段都跳 | 兜底：确认是否 notifier 之前 |

**执行顺序：先 m0**（拿到 stage 分布，信息量最大），再按 §0 表选 m1 或 m2 做「跳过即修复」的反证，m3 兜底。

---

## 2. 上机流程（每变体一遍）

物理动作（连线/长按/插拔 VBUS）由用户执行；其余 agent 跑。

```
A. [用户] 设备进 fastboot（或已在此态）
B. [agent] fastboot boot out/boot-elden-vk65-mX.img        # 零写盘，掉电自动回 boot_b
C. [agent] 等 boot_b→linux17 根、SSH 通（root@192.168.7.1）
D. [agent] 校验 uname / dmesg 有 "[KD] kexec_dbg=X"
E. [agent] adb push scripts/kexec-diag-test.sh /root/;  push out/kexec-diag/{Image.kd,elden.dtb} /root/
F. [agent] adb shell 'setsid nohup sh /root/kexec-diag-test.sh >/root/kexec-diag.out 2>&1 &'
         （dumper setsid 脱离 SSH，逐行 fsync 到 /root/kmsg-diag.log）
G. 触发 kexec -e（脚本内）→ 预期掉电 → VBUS 自动开机回 boot_b
H. [agent] 重连后 adb pull /root/kmsg-diag.log → 读最后 [KD] stage=
```

> 关键：dumper 必须 `setsid` 脱离 SSH 会话（R2 的 python 是 SSH 子进程，SYS_RESTART
> 网络 teardown 时随 SSH 一起被杀，故只抓到 wlan deauth）。本地 setsid + 每行 fsync 后，
> 只要掉电点在 UFS host 被关（`device_shutdown` 里 ufshcd .shutdown）之前，就能落盘。
> UFS 是早期 probe 设备，`device_shutdown` 反向遍历里**最后**关 → 有充足窗口。

---

## 3. 若定位到 device_shutdown 内（最可能）：设备级二分预案

`device_shutdown()` 反向遍历所有 `.shutdown()`。UFS 最后关 → 可在 `drivers/base/core.c`
的 `device_shutdown` 循环里对每个 dev 打 `dev_name()`，同样靠本地落盘抓到「最后一个还在、
下一个就没回来」的设备名。**待 §0 确认是 11a 后再做**（避免过早改树）。

---

## 4. 资源清单

- 内核提交：`6cbe1ffa7`（geekidos-linux，树曾干净，基于 `d02658e63`）
- 改动：`kernel/kexec_core.c`（diag 解析 + 阶段标记 + syscore 跳过）、
  `kernel/reboot.c`（device_shutdown 跳过守卫）、`include/linux/kexec.h`（宏 + extern + 非 KEXEC stub）
- 镜像：`out/boot-elden-vk65-m{0,1,2,3}.img`（各 101 MB，manifest 同名 `.manifest`）
- 目标载荷：`out/kexec-diag/Image.kd`（未压缩 Image，kexec 目标）、`out/kexec-diag/elden.dtb`
- 脚本：`scripts/kexec-diag-test.sh`（设备端 dumper + load + jump 编排）
- 运行内核 = 诊断内核本身（R2 §1 教训：`kernel_restart_prepare`/`syscore_shutdown` 在**运行**内核执行，非目标 Image）

## 5. 纪律

- 每轮上机前 `python3 scripts/slot-attr.py mark-successful b`（`boot_b` 维持 0x7f，防 retry 耗尽）。
- `fastboot boot` 零写盘；掉电靠 VBUS 自动开机回 boot_b。
- 长跑上机段设 `timeout` 盒，`pgrep` 核实进程退出。
