# 马达（aw86927/aw86937 haptics）为何不工作 — vk127 上机诊断（2026-10-17）

镜像 vk127（UTS `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`），零写盘 `fastboot boot`，SSH 在线。
原始证据：`logs/vk127-stress-20261017/s7/motor-*.txt`。

## 1. 内核侧：完全正常（逐项证据）

| 检查 | 结果 |
|---|---|
| i2c 设备 | `6-005a`、`6-005b` 均 bound 到驱动 `aw86927-haptics`（`i2cdetect -y 6` 显示 `UU`） |
| CHIPID（0x57/0x58） | **`0x9370` = AW86937**（两颗都是） |
| input 设备 | `input3`→`event2`（A=6-005a）、`input4`→`event3`（B=6-005b），capabilities `ev=0x200001`（EV_FF）、`ff=0x107030000`（FF_RUMBLE 等） |
| 驱动代码 | `build/m1-73/drivers/input/misc/aw86927.c` 与**能震的 7.2 日常线** `build/vk83-tree/...`（含 2026-09-30 的 `0003 SRAM 窗口修复 + 厂商 CONT 模式`）**逐字节相同**（`diff` 无输出） |
| DT 节点 | vk127 与 vk83-tree 的 `haptic-controller@5a/5b` **逐行相同**（`awinic,aw86937`、`ram-waveform-index=<4>`、reset-gpios tlmm127/119、irq 99/95） |
| probe 报错 | 无（dmesg 只有两行 `input: aw86927-haptics as …`） |
| FF 触发 | kprobe `aw86927_haptics_play` / `_play_work` 命中，无 `Failed to execute work command` 等错误 |

### 播放时寄存器回读（马达 A，`ffrumble 8s 0xffff` 期间）

```
reg08 PLAYCFG3 = 0x16   -> [1:0]=2 连续模式, bit2=1, bit4=1(AUTO_BST)  ✅ 厂商 CONT 序列生效
reg1d CONTCFG6 = 0x7f   -> bit7=0, 驱动电平 0x7f                        ✅
reg1e/20/21    = 04/ff/08                                              ✅
reg4c VBATCTRL = 0x40   -> bit6=1                                      ✅
reg3f GLBRD5   = 0x06   -> 状态机**不在 standby**（0=standby）           ✅ 芯片确实进了播放态
reg02 SYSINT   = 0x01   -> DONEI（播放完成）；**无 UVLI/OCDI/OTI/BST_OVP** ✅ 无欠压/过流/过温
播放结束      GLBRD5 = 0x00（回 standby）
```

⇒ **内核到芯片的数字链路完全走通、芯片真的执行了播放**。剩下的可能性只有：① 用户态没发出请求（桥/幅度问题，见 §3）；② 模拟侧（LRA 供电/驱动能力）不出声——只能靠手感确认。

## 2. 需要人手的唯一判据

本会话已多次全幅触发（`ffrumble /dev/input/event2|event3 <ms> 0xffff`，含 A 3 s、B 3 s 两发）。
**只有「摸得到震动吗」能定案**。历史记录里 09-30 的修复也只做到「用户确认」这一步。

## 3. 用户态链路：两个真缺陷（与手感无关，但会让 Android 侧静音）

链路本身是通的：`elden-hapticd` 服务在跑（`/etc/runlevels/default/elden-hapticd`、pid 2288），桥目录/文件齐（`/run/elden-haptic/leds/vibrator/{activate,duration,state,amplitude}`，0666），`lxc.mount.entry` 两条都在，`vendor.img` 是 10-13 固化过 HAL 的那份（`vendor.img.bak-elden-haptics-20261013-115055` 备份在），手动写桥文件 → daemon 日志 → FF 全链路通。

**缺陷 1（会静音）**：`elden-hapticd.initd` 的 `start_pre()` 把 4 个桥文件（含 **`amplitude`**）都 `echo 0`。daemon 用 `effective_mag = --amp × amplitude/255`，`amplitude=0` ⇒ FF `strong_magnitude=0` ⇒ 驱动的 `aw86927_haptics_play()` 里 `level=0` 且与旧值相同 → **直接 return，play_work 都不排**（不是「震得轻」，是「完全不震」）。

kprobe A/B（写桥文件走 daemon，同一次开机、同一颗马达）：

| 桥 `amplitude` | `aw86927_haptics_play_work` 命中 |
|---|---|
| `0`（开机默认态） | **0** |
| `255` | **4**（2 马达 × 开/停） |
| 直接 FF `0xffff`（绕过 daemon） | 2 |

**缺陷 2（幅度中途变更不生效）**：daemon 主循环里 `activate` 保持 1、只有 `amplitude` 变化时，只打 `vibrate re-triggered` 日志，**不重新 `play_all(1)`**；而 AIDL HAL 的框架路径是「先 on(duration) 再 setAmplitude()」，所以文档里承诺的「运行中改幅值会重新上传 FF」实际不成立。

> 注：HAL 自身 `mAmplitude255 = 255`，且 `start()` 在写 `activate=1` **之前**就写 `amplitude`，所以走 HAL 的正常 Android 请求**大概率仍会震**（桥文件被 HAL 覆写成 255）；缺陷 1 命中的是「HAL 之外」或「HAL 未跑」的路径，缺陷 2 命中「运行中改强度」。两处都应修（初始化改 255 + 变更时重新上传）。

## 5. 手感复测（2026-10-17 晚，s8 GOOD 发，用户在场）★ 结案

用户结论：**摸到了，两侧均正常**。此前「不工作」是误判，两个原因：

1. **长震是「前强后弱」**：用户明确描述「长时间震动的右侧仅第一下强度大，后续强度小」。
   - 厂商 `haptic.ko`（`backup/stock-elden/vendor_dlkm/haptic.ko`，带符号）反汇编 `aw8693x_cont_config`（地址 `0x13688`）逐条还原后确认：
     `0x08=2`(CONT) → `0x08 bit2` → `0x06 bit5=0` → `0x4c bit6=1` → `0x1d=drv1_lvl` → `0x1e=cont_drv1_time` → `0x20=0xff` → `0x09=1`(GO)；
     与 mainline 驱动 `aw8693x_cont_play()` **逐寄存器一致**，DT 参数（`cont_drv1_lvl=0x7f`、`cont_drv1_time=0x04`）也对得上（归档 `archive/topics/STOCK-KERNEL-2026-09-30.md`）。
   - 因此「强起始段 + 低维持段」是**厂商设计的驱动包络**，不是我方漏写序列。唯一两家都不写的寄存器 `0x1f`（现场 `0x04`）已做在机 A/B（见 `logs/vk127-stress-20261017/s8-motor-0x1f-ab.txt`）。
2. **桥的幅度默认 0**（见 §3 缺陷 1）——不经 HAL 的触发会完全静音。

### 已修复并上机验证（2026-10-17 19:49，`logs/vk127-stress-20261017/s8-bridge-fix-verify.txt`）

| 修复 | 内容 | 验证结果 |
|---|---|---|
| `rootfs/persistent-overlay/elden-hapticd.initd` | `amplitude` 启动默认值 `0 → 255`（其余三个仍 0） | 起服务后桥文件 `amplitude=255`；**只写 duration+activate 时 `aw86927_haptics_play_work` 命中 = 4**（修复前 = 0） |
| `scripts/elden-hapticd.c` | 运行中幅度变化时重新 `play_all(1)`（原来是只打日志） | 改幅 255→80 后命中 2 → **6**，日志 `rumble ON (amplitude=80/255) A=0x5050` |

设备侧已部署（`/usr/local/bin/elden-hapticd`、`/etc/init.d/elden-hapticd`，旧件备份 `*.bak-20261017`），服务 started。

---

## 6. 结论与下一步

1. **不是内核/DT/驱动问题**（三者与已知能震的 7.2 线逐字节一致，且芯片确实进 CONT 播放态）。
2. **两侧马达都能震**（用户手感确认）；Android/容器路径的两个桥缺陷已修复并验证。
3. 「长震前强后弱」= 厂商驱动包络（反汇编级证明），**不建议再改**；若要更长的等强维持，属于产品调参（drv1/drv2 包络），需单独立项。
4. 仍待补：容器内端到端（`waydroid session start` + `cmd vibrator_manager synced oneshot 500` 手感确认）。

## 7. 容器内端到端验收（2026-10-17 夜，`logs/vk127-stress-20261017/s8-waydroid-vib-e2e.txt`、`s8-waydroid-kprobe3.txt`）

台架：`wd-ctl.sh start` + `session` → `waydroid status` = Session/Container **RUNNING**（IP 192.168.240.112）。

| 项 | 结果 |
|---|---|
| HAL 来源 | `pid 92` → `/proc/92/exe -> /vendor/bin/hw/android.hardware.vibrator-service.elden`（三期固化版，无 bind 挂载） |
| 能力 | `mCapabilities=[AMPLITUDE_CONTROL]`、`mSupportedEffects=[CLICK,DOUBLE_CLICK,TICK,THUD,POP,HEAVY_CLICK]` |
| leds 桥 | 容器内 `/sys/class/leds/vibrator/{activate,duration,state,amplitude,trigger}` 在位（0666/0664） |
| **内核级链路** | 容器 `cmd vibrator_manager synced oneshot 900` → trace 里 `elden-hapticd-5844: awplay → kworker: awwork`，**awplay=6 / awwork=4**（阳性对照宿主 ffrumble = 2/2） |
| 幅度透传 | daemon 逐发正确：`amp=255/255`（默认）、`-a 40` → `amplitude=40` + `A=0x2020 B=0x2020`、`-a 200` → `A=0xc8c8` |
| cancel | `-B oneshot 6000` + 1.5 s `cancel` → daemon `rumble OFF` + `vibrate OFF`（未等满 6 s） |
| 轻触连击 | 3×`oneshot -a 120 200` → 每发独立 `vibrate ON 120 ms` + `AUTO-OFF` |

⇒ **C10 全链路（Android 框架 → AIDL V2 HAL → 桥 → daemon → aw86937 CONT 播放）端到端通**；物理手感由用户在机上确认。

### 7.1 时长阶梯（客观）

容器内 `synced oneshot -a <ms> 255`，看 daemon 起停时刻：

| 请求 | daemon ON → OFF | 实际时长 |
|---|---|---|
| 500 ms | 10:09:02 → 10:09:02 | 0.5 s |
| 2000 ms | 10:09:09 → 10:09:11 | 2.0 s |
| 5000 ms | 10:09:19 → 10:09:24 | 5.0 s |

⇒ 时长语义**逐发正确**（不是“被截成短震”）。

### 7.2 「长震感觉像短震」的解释（留待验证）

用户反馈「都是短震」。内核/链路侧时长正确，差异只可能在**驱动包络**：厂商 CONT 模式是「短强起始段 + 长低维持段」（DT `cont_drv1_time=0x04` 很小），而厂商日常振动实际上走 **RTP 波形文件**（`haptic.ko` 内含上百个 `*_RTP.bin`；见 `archive/topics/STOCK-KERNEL-2026-09-30.md` §3），并不用 CONT 做普通振动。⇒ 若原厂 Android 的长震明显更“持续”，则我们要补的是 **RTP 播放路径**，而不是调 CONT 参数。验证顺序：① 用户机器上分辨 0.5/2/5 s 三发；② 切 Android 槽同操作对照手感。

**取证踩坑**：`/sys/kernel/tracing/tracing_on` 被置 0 后 `trace` 恒空（阳性对照也是 0 命中），会误判成「链路断了」。判 trace 是否活着必须先跑阳性对照（宿主 `ffrumble`）。
