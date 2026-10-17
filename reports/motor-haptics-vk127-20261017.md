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

## 4. 结论与下一步

1. **不是内核/DT/驱动问题**（三者与已知能震的 7.2 线逐字节一致，且芯片确实进 CONT 播放态）。
2. **不是 Waydroid 桥完全没接通**（服务、挂载、端到端写→FF 都通），但桥的 `amplitude` 默认 0 会让不经 HAL 的触发**静音**。
3. 待用户手感确认后分叉：
   - 有震 ⇒ 用户遇到的「不工作」在 Android/容器路径 → 修缺陷 1/2（改 initd + daemon 重新上传），再在容器内 `cmd vibrator_manager synced oneshot 500` 端到端验收。
   - 不震 ⇒ 走向 LRA/供电侧（芯片 SYSINT 无 UVLO/OVP 报错，需外部电流/电压或与 Android 侧对照）。
