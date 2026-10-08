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

---

## 6. 上机结果（2026-10-08 深夜，U2/HA2EXB0E）—— P0 达成

内核：m0/m1b = `g6cbe1ffa7622`；m1c（带 sysfs 开关）= `ge70d0b660b74`。
落盘通道：`setsid nohup python3 kd-dump.py`（脱离 SSH，逐行 fsync 到 linux17 磁盘根）→ **成功抓到掉电点**（修复了 R2「SSH 子进程随 SYS_RESTART 被杀」的致命伤）。

### 6.1 m0（mask=0，全跑）：掉电点在 device_shutdown 内部
最后标记停在 `[KD] stage=11a before device_shutdown`，**无 11b**。尾迹：
```
stage=10 → 11a before device_shutdown
→ dwc3-qcom usb teardown → sd 0:0:0:0 [sda] Synchronizing SCSI cache → （掉电）
```
即 `device_shutdown()` 反向遍历到 UFS/SCSI 附近时触发整机掉电。

### 6.2 m1c（sysfs 设 mask=1，跳 device_shutdown）：整条路径全通 🎯
```
stage=10 skip_mask=1 → 11a SKIP device_shutdown → 11 → 12(migrate)
→ 13 before syscore → 14 after syscore → "Starting new kernel"
→ psci: CPU1..6 killed   （已进入 machine_kexec）
```
`Starting new kernel` 是 R1/R2 从未越过的里程碑，本次首次到达。

### 6.3 结论（Q11 关机阶段掉电 = 已定位并给出规避）
1. **`device_shutdown()` 是静默掉电的唯一触发点**。跳过它即走通 notifier→migrate→syscore→CPU offline→machine_kexec 全程。
2. **`syscore_shutdown` 无罪**（stage=14 干净通过）。
3. kexec 机器本身正常（trans_pgd、CPU offline 均对）。
4. `kexec_dbg=` cmdline 解析在本树不生效（回显 mask=0）；改用 sysfs `/sys/kernel/kexec_diag/kexec_diag` 运行时设定+读回（`g e70d0b660`）。

### 6.4 遗留（第二个、更窄的正交问题，非 Q11 本体）
mask=1 跳转后设备约 20s 以 **vk64(boot_b 持久)**回来（经 ABL，非 kexec 落地），pstore 空
⇒ 目标内核（Image.kd）在跳转后早期失败/复位，未起来。这与「关机阶段掉电」是两码事，
属「kexec 二阶段/目标早期」问题，需单独立项排查（候选：目标 cmdline/内存/KASLR/DTB 交接）。

### 6.5 资产更新
- 内核 `e70d0b660`（sysfs 开关 + 加固解析）；`out/boot-elden-vk65b.img`；`out/kexec-diag/{Image.kd,elden.dtb,kmsg-*.log}`
- 落盘 dumper：设备 `/root/kd-dump.py`（setsid 版）。

---

## 7. device_shutdown 逐设备 trace（vk66 `da0d8fe20`，mask=0）—— 撞观测墙

给 `device_shutdown()` 循环加 `[KD] SD-start/SD-done: <dev_name>`（pr_warn，仅 kexec 路径），本地落盘。结果：

- **117 个设备 SD-start / SD-done 完美配对、无孤立**；反向遍历先关后 probe 的外设（`hwmon57/wlan0/phy0/displayport-controller/vcs*…`），
  一路干净关到最后一个 **`sde51`**，然后设备 **#118 的 SD-start 都没落盘** → 掉电/断流。
- **UFS host controller `1d84000.ufs` 与 `sda..sdf` 均不在这 117 里** → 遍历死在到达它们之前，#118 属**基础驱动区**（interconnect/regulator/clock/pinctrl/iommu 一类），非外设。
- m0 已证 device_shutdown 未返回（无 11b）→ 掉电发生在 **#118 的 `.shutdown()` 内**，且快到其前置 `pr_warn` 都来不及被 python dumper 下一轮 read+fsync 抓到。

### 7.1 观测墙（为何盘日志到此为止）
本地 dumper 写 **UFS**、ramoops 在 **DRAM**，两者都不抗 PMIC 整机掉电；而 #118 的 `.shutdown()` 是「微秒级即时掉电」型，**任何 RAM/存储背书的日志都无法可靠抓到触发掉电那一行的设备名**。→ 要继续必须用**抗掉电通道**。

### 7.2 两个可选的下一步（二选一或都要）
- **A. PON 备用寄存器心跳**：`device_shutdown` 每步把递增计数写 PMIC `PON_SOFT_RB_SPARE`（qcom-pon regmap，always-on 域，抗整机掉电）；重启后读回计数 → 直接得到 #118 的序号，再与 1-117 的名字序列对齐即锁定元凶。需在 core.c 拿 PMIC regmap（qcom-pon 是 module，不能直接链接，需按 compatible 运行时取 regmap）。
- **B. 选择性 skip 二分（推荐，无需抗掉电通道）**：给 `device_shutdown` 加 `skip_glob` sysfs；`mask=0`（让 device_shutdown 正常跑）+ `skip=<候选>`，**判据 = kexec 是否成功（稳、无日志竞态）**。按类二分（interconnect / regulator / clock / pinctrl / iommu / ufs…）即可在几次内锁定含元凶的类，再细分到设备。

### 7.3 现实评估
`device_shutdown` 整段跳过（sysfs mask=1）已能让 kexec 走通到 machine_kexec，是**可用的 kexec 快环修复**；§7.2 是为「更干净的上游修法 + 搞清是哪块硬件」而做，属锦上添花。

---

## §8 实机二分结果（vk65–vk69，2026-10-08，判据=kexec 是否跳转 + 本地 kmsg 落盘）

内核诊断设施：`kexec_diag`(跳 syscore/device_shutdown 掩码) + `stop_after`(device_shutdown 只真关前 N 个,其余跳过) + `settle_ms`(每个真关机后 msleep) 三个 sysfs 旋钮；本地 `kd-dump.py` 落盘 kmsg 到 UFS（抗 kexec 会话中断）。

| 变体 | 配置 | 结果 |
|---|---|---|
| vk65 | mask 跳过 device_shutdown | kexec 跳转成功（`Starting new kernel`） |
| vk66 | 逐设备 SD trace | 117 个真关机干净配对，日志停在 ~#118 |
| vk67 | stop_after=117 | 遍历 117 真+458 跳过仅 **130ms**；掉电落在 idx576（异步落电时刻，红鲱鱼）；**跳过 #118(sde50) 不阻止掉电** |
| vk68 | +settle_ms=250 | **我引入的自旋锁双重加锁死锁**（msleep 块误 spin_unlock/lock，撞上循环底 spin_lock）→ CPU5 lockup、背光常亮挂起 |
| vk69 | 修死锁 +settle=250 | **117 个真关机全部完成**（各自 250ms 内不掉电、无单设备阻塞>2s）；掉电落在 skip-walk idx318（`wcn7861-pmu`/regulator 一带，均被跳过）；11a→掉电 ~30s |

### 8.1 排除项（本轮钉死）
- **非单设备即时/短延迟关机**：117 个真关机各自 settle 250ms 均未掉电。
- **非看门狗**：设备无 `/dev/watchdog`，`watchdog: Hard watchdog permanently disabled`。
- **非 panic**：停点无 panic 回溯；`panic=15` 未触发重启特征。

### 8.2 现象规律
掉电只在 **[1,117] 真关机跑过之后**发生（跳全部→不掉电、能跳转），且与 device_shutdown **墙钟耗时相关**（无 settle 0.13s 掉电、有 settle 30s 掉电，掉电点随遍历进度浮动）→ 指向**多设备关机的累积/延迟效应**（疑似某 regulator 软关后 rail 延时跌落致 PMIC 掉电），非单点同步触发。

### 8.3 ★关键路径判断
**跳过整个 device_shutdown 已能让 kexec 跳转（m1/vk65 到 `Starting new kernel`），但目标内核 `Image.kd` 仍起不来 → 约 20s 回 vk64。** 故 **device_shutdown 掉电不在"kexec 真正可用"的关键路径上**；真正的拦路虎是**目标内核经 kexec 引导失败**（§6.4 遗留）。继续二分 device_shutdown 元凶只服务「更干净的上游修法 + 硬件理解」，不解锁可用 kexec。

### 8.4 遗留二问题
1. device_shutdown 累积/延迟掉电的确切触发设备类（需 `stop_after` 二分 [1,117]，约 7 轮；或 PON 备存寄存器心跳）。
2. **目标内核 kexec 引导失败**（关键路径；需早期串口可见性：DT 预留 pstore/ramoops 让目标早期挂载，或物理 UART）。
