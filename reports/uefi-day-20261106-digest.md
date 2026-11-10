# 2026-11-06 UEFI 线（G1-29）当日盘点：四次判据翻转，卡点收敛到「屏显写通道」

> ⚠ 本文件成稿于 21:51；随后 22:40 的 p25/p26 两发把「第三方二进制 DXE 驱动」推翻（PC 在 `LinuxLoader`
> 的 `SerialPortWrite` 内），以 `reports/uefi-flt-attribution-20261106.md` 与 `TASKS` §5「夜·二」块为准。

> 一站式读法：本文只做**当日合并视图**（4 段推进 + 5 条作废 + 稳定资产 + 未定三事）。
> 逐段权威仍在 `TASKS/README.md` §5 的 11-06 四个块；下批执行单在 `archive/plans-20261110/2026-11-06_uefi-batch-next.md`。
> 全程零写盘（agent 动作层面；`boot_b` retry 被 ABL 写见 `PITFALLS #525`），载荷 = 真内核 `out/boot-elden-vk172.img`（82 MB）。

## 1. 四段推进（每段都推翻前一段的一条结论）

| 时段 | 结论（当时） | 权威 |
|---|---|---|
| 上午 09:33 | **11-05 夜 10 发作废**：`VS_STOP` 判的 `SbStopStage` 只在 `BootLinux()` 内赋值，而 `LoadImageAndAuth()` 先被调用 ⇒ 那 10 发一次都没命中探针。修好后单变量定案：崩溃元凶 = `SerialPortWrite`（帧缓冲控制台）写穿 splash 前 ~448 KiB，不是 `gRT->SetVariable`。新通道 `sbprobe=3`（只记标记、不写屏、不写 NV），二分不再付断电代价 | `reports/uefi-vsstop-and-fbconsole-20261106.md`；`PITFALLS #514/#515/#516` |
| 午后 14:37 | **「34→27 窗口只剩 `MarkPtnActive()`」不唯一**：`FindBootableSlot()` 的 `out:` 收尾里躺着 2026-11-04R15 的**无条件** `SerialPortWrite`（未纳入 `sbprobe` 门控）⇒ "自己写穿"与"`MarkPtnActive` 崩"两种解释等价。另确认 `MarkPtnActive()` 在本树只跑内存属性循环（`IsUpdatePartitionAttributes()` 恒 FALSE，不落盘）。产出 `VS_STOP(35..38)`、p8/p9 世代 | `reports/uefi-vsstop35-tail-static-20261106.md`；`PITFALLS #522` |
| 傍晚 18:47 | **首次上机全场走通到跳内核**：门控住 `out:` 那条写后 `vs-18/19/26/27/28/35/36/37/38` 九档全回话，真载荷 `SB_STOP 1..6` 全回话 ⇒ 装载/DTB/ramdisk/释放全通。真件首次放行 = 递归 dump、PC `0xcfe98c38` 被读成「跳进堆」（后被推翻）。同时更正三条判据：EB 后宿主天然收不到（USB 栈被拆）、一会话一发、诊断模式 ≠ 真启动路径 | `reports/uefi-onboard-walkthrough-20261106.md`；`PITFALLS #523/#524` |
| 深夜 21:44 | **真启动必崩的真因 = 我们自己的探针写屏**：`LoadImageAndAuth()` 入口那行 `SbProbeMode = … : 0;` 无条件把 R4 设的默认 3（静默）重置为 0 ⇒ 真件（cmdline 无令牌）十几次 `SbVProbe` 直写帧缓冲。修法 `20261106R12-probemode-guard`（只有带 `sbstop=` 令牌才改模式）：p19 真件回 `ret-after-lia` 且设备存活；p20 全路径到宿主 `Booting OKAY [0.001s]` 后崩 `0xCFE98C4C`。真载荷阶梯 `VS 16/20/24/26/27/28/34..38` + `SB 1..6`、`40` 全回话；p21 排除 `FastbootUsbDeviceStop()`、p24 排除 EB。**崩溃 PC `0xCFE98C8x` 落在 LinuxLoader(`0xCFEB2000+0x45000`) 之下 ~0x1C000 ⇒ 崩在第三方二进制 DXE 驱动** | `TASKS/README.md` §5 顶块；`patches/uefi/README-p19-p20-NOTE.md`；`PITFALLS #525/#526` |

## 2. 当日作废的归因（5 条，别再引用）

1. **「跳进堆」** —— DXE Heap 是 `Conv` 内存，DXE 映像本就分配在其中（`DxeCore` 自身 `0xD4CA6000` 就在里面）。
2. **「`MarkPtnActive()` 崩」** —— 34→27 窗口里还有一条未门控的屏显写；p19/p20 证明真因是探针写屏。
3. **「`FastbootUsbDeviceStop()` 崩」** —— p21 跳过它仍崩同一 PC。
4. **「34→27 窗口只剩一个候选调用」** —— 静态上不唯一（见上表第 2 段）。
5. **递归 dump 里的 PC 序列**（`…DA8`/`…DA9` 每条差 1）—— 是垃圾；只有**非递归首行** PC 才是信号（本轮 `C38/C4C/C6C/C84/C94` 同处、随构建偏移）。

同时仍然成立的两条：① **诊断模式与真启动是两条路径**（`FastbootOkay`/`FastbootUsbDeviceStop`/`ResetBootDevImage` 只在真启动分支）；
② `[L] found=/[L] LoadImage=Success` 是 **BdsDxe** 在 `gBS->StartImage(LinuxLoader)` **之前**打的（`BdsEntry.c:758`），不能当"已进 fastboot 会话"的证据。

## 3. 现在到底走到哪一步（一句话定位）

真内核载荷在真启动路径上：**完整装载 → AVB/槽位/DTB/ramdisk/释放全通 → 越过 `LoadImageAndAuth`/`ExitMenuKeysDetection`/`FastbootOkay` → 宿主收到 `Booting OKAY` → 崩在**自己的屏显写函数 `SerialPortWrite`** 里**（PC `0xCFE98C8x`；22:40 的 p26 归因：`b=0xCFEA2000 z=0x45000 o=0x13C84` ⇒ LinuxLoader+`SerialPortWrite`；`[K] JUMP-BANNER` 始终未出现 ⇒ 打 banner 的那次打印自己先崩，**不等于**跳内核失败）。

## 4. 当日产出的可复用资产

- **通道三级制**：`sbprobe` 缺省/0 = 写屏（只在令牌件里用，真件必须静默）；`sbprobe=3` = 只记标记、随 fastboot 响应回宿主（二分不用断电）。真件默认静默靠 R12 门控保证。
- **脚本**：`scripts/uefi-oneshot.sh`（换会话→载 preamble→打一发→判读，解决「82 MB 真件一会话一发」）、`scripts/real-vs-ladder.sh`（真载荷阶梯，`PRE=` 指定 preamble）、`scripts/uefi-r21-p7-ladder.sh`（`--verify` rc=0，p7 仍逐字节可复现）、`scripts/uefi-sbstop-patch.py`（只改 cmdline 前 19–21 B ⇒ 单变量）。
- **配方**：`patches/uefi/p14…p24-recipe.txt`（42–44 条补丁按序）；补丁 `20261106R7…R16`，状态表 `versions/patches-uefi-status.tsv`。
- **镜像**：`out/r21-sbstop-p{14..24}/`（只留 preamble）、`out/real-ladder/`（真载荷阶梯件）。
- **判据账**：`reports/artifacts/real-vs-ladder-20261106T2*.tsv`（5 份，含 16/20/24/26/27/28/34..38、1..7、40 的逐档回话）。
- **纪律**：① 82 MB 真件一会话一发；② EB 之后只能看屏（`--scale 1` 一行 = 91 KiB，448 KiB 预算 ≈ 4 行）；③ 每轮崩后核 `slot info`（ABL 会写 retry）；④ 真件崩后设备会走"熄屏→recovery 警告→回落 Linux"自愈链，USB 短暂全消失 ≠ 硬件故障。

## 5. 未定 / 待取（下一批要闭合的三事）

1. **那个 DXE 驱动是谁** —— PC 归属未定。主机侧已能算出候选窗口（见计划 §2），但"紧邻 LinuxLoader"只是假设，必须上机取一次 ground truth。
2. **崩溃与跳内核的先后** —— banner 未出现只能证明「死在 banner 之前」，还不等于「跳内核调用本身有问题」。
3. **是否是我们自己 p2x 件的副作用** —— p24（跳过 EB）仍崩，至少排除 EB 内部；剩余嫌疑在第三方驱动自身或它被我们改动后的调用序列。
