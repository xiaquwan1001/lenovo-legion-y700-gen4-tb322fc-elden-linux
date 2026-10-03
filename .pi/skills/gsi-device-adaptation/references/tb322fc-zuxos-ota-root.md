# 原厂 ZUX OS 调研：Y700 四代 (TB322FC) 1.5 更新决策 + OTA/root/BL 机制

2026-08 调研实录。用途：决定留在 1.1 终版还是升 1.5，以及升级对 root/BL 的影响；供与 GSI 方案对比。调查源：联想社区、ROM基地、smzdm、B站/抖音玩机 UP、Reddit/XDA。

## 版本线
- ZUI（一二三代旧系统）：口碑差（手势上滑误出 dock、操作逻辑怪），一直被玩家诟病。
- ZUXOS = ZUI X OS，2024-12 发布（官方话术"ZUI 史上最大规模底层革新"：灵境引擎八大 Turbo、天禧智能体 + DeepSeek R1、动画/触控/网络重做）。Y700 四代 2025-05 出厂即 ZUXOS 1.1。
- 出厂/早期版本：`ZUXOS_1.1.11.073_250612_PRC`（073 包，用户全刷恢复用）；OTA2 = 1.1.11.076（ZOL 报道，触控调节优化）。
- 四代 1.5 稳定版：**1.5.04.366**（Android 16；抖音实拍），后续 1.5.10.259（B站玩机 UP 教程标题）。三代同期 1.5.10.184 stable（Reddit）。内测 2025-07 开始、2026 年转正推送。

## 1.5 实际口碑（去官方宣传后）：负优化论调占上风
独立来源（抖音 / B站 / smzdm / 联想社区）：
- 抖音："y700四代安卓16完全就是负优化，三角洲画质太糊"、"出厂版本性能十分强大！再也不会掉帧卡顿了"。
- B站（送就到家，专做降级教程）："最近拯救者y700四代升级安卓16实在太卡了，解决方法就是降级出厂版本"。
- B站（BV1FMsCzPEys）："不推荐更新最新系统，触控调节没变化，性能不够激进"。
- smzdm 68 用户汇总：四代更新后多项负优化——删浮窗小白条、帧数显示失效、野兽模式 CPU 性能下降。
- 联想社区有"系统更新负优化拉满"标题帖（部分针对更早版本，须甄别机型/版本号再引用）。
- 正面证据弱：更新频繁、分屏/悬浮窗功能越更越多（疯疯 2026 视频）；待机掉电玄学（时快时慢）官方一直未修。
- 结论：**1.5 把性能调度整体调保守（为续航/发热妥协），游戏党（三角洲/崩铁等）感知明显。"出厂版本=性能巅峰"是玩机圈共识**，出现大量"降级回 043/出厂版"教程。

## OTA / root / BL 机制（联想系，多条独立来源）
1. **OTA 不重锁 BL**：AOSP 标准行为——解锁状态在重启/升级后保留；BL 状态存 bootloader 标志位，OTA 包不写。联想无 OTA 自动回锁传统（回锁都是用户手动 `fastboot oem lock`）。
2. **root 必丢且阻断 OTA**：联想 OTA 校验 boot/init_boot 完整性，改过 boot（Magisk/KSU patch）→ OTA 失败；须先刷回原版 boot 再升级，升后重新提取新版 init_boot 打补丁（CSDN 教程证实）。
3. **新系统可能屏蔽解锁通道**：ROM基地解锁教程明示"若新版系统屏蔽了解锁 BL 指令，可回退旧版 ZUX OS 恢复解锁功能"。→ 若 BL 未解锁且在意未来玩机自由度，先解锁再升级。
4. **降级可行**：1.5 稳定版可线刷降级（B站"四代降级 043 出厂版本"教程，LTBox/9008 途径）；内测版才"无法降级"（联想社区内测须知原话）。
5. **KSU vs Magisk**：KSU LKM 需匹配联想定制内核（GPL 源码放出慢；XDA 有人在做 TB322FC 内核构建但未成）→ 卡 logo 风险（见 SKILL.md §4 安全网）。**Magisk（patch init_boot）通用 → 本机推荐 Magisk**。
6. 联想官方解锁页声明"解锁后无法使用 FOTA"≈ 免责条款，实际指改 boot 后 OTA 校验失败，不是 BL 重锁。
7. 联想解锁方式（四代 TB322FC）：官网申请解锁文件 sn.img（大陆邮箱，ZUX OS 需填 `adb shell getprop ro.boot.bootload_sn` 的 bootloader_SN）→ `fastboot flash unlock sn.img` → `fastboot oem unlock-go`（会擦数据）。部分机型也可开发者选项 OEM 解锁 + `fastboot oem unlock-go`。
   - 2026-10-03 **重要更正**：官网申请**不是唯一**路径（取证 `archive/topics/UNLOCK-BLOB-FORENSICS-2026-10-03.md`）——
     ① **AVB 链**用谷歌公开 AOSP testkey（原厂 259 `vbmeta`/`boot`/`recovery` pubkey sha1 `2597c218…`）⇒ 自签镜像被 ABL 认可；
     ② **解锁标志链**用 Lenovo 自签证书（serial `804940DE79164B1A`），但三代工具箱实物表明解锁 blob 的 **SN 明文在偏移 `0x2048`、签名只覆盖前 `0x1000`** ⇒ 通用模板改 SN 即可解锁（**免签**，非自签）；
     ③ EDL 写分区不看 lock 位 ⇒ **G1 不必先解锁**。三代模板：`y700四代工具/解BL/Y700 三代解锁工具箱by某贼.zip` → `bin/res/sn.img`。
   - 2026-10-03 实测补充（U2=HA2EXB0E，ZUXOS 1.5.10.259，locked/green）：`ro.boot.bootload_sn` 是 64 位 hex（不是版本号）；
     **分区表/by-name 里没有 `unlock` 分区**，`fastboot flash unlock sn.img` 由 ABL 特殊处理，报“分区不存在”才是异常；
     解锁后 `verifiedbootstate=orange`、`flash.locked=0`；**Widevine L1 不可逆**（本机解锁前 `sys.lenovo.widevine_security_level=L1`，先取证）；
     sn.img **一机一码但可重复使用**（回锁/重刷后仍可拿去再解），当心一年 3 台限额。
   - “免解锁重签包”（如 `1.5.10.259免解锁重签.zip`）只给 root、不给 fastboot 写权限 → 做不了需要 `flash`/`boot` 的主线项目。
   - **2026-10-03 终局结论（两台单元各自实测：U1 08-16 / U2 10-03）**：四代解锁**只看 ROM 版本门**，
     **≤ 1.1.11.073/.076 才存在解锁命令**；1.1.11.120 = trap（显示成功但回滚）；**1.5.x = 通道被堵，
     官网 sn.img / 三代免签模板 / 第三方签名 blob 全无效**（四代 ABL 换内嵌 key）。
     正解只有一个：**全量降级到 1.1.11.073（含 GPT）→ `fastboot oem unlock`**（073 上连 sn.img 都不需要）。
     降级包与命令见 `qualcomm-edl-flashing/references/tb322fc-y700-gen4.md` §version gates + 项目 `RUNBOOK` §0.5。

## 原厂 vs LineageOS GSI（TB322FC 实测 + 调研）
| 维度 | ZUX OS 1.5 | LOS 23.2 GSI |
|---|---|---|
| 游戏调度 | 灵境引擎三档（节能/均衡/野兽），1.5 保守 | 裸 GKI 调度，无游戏模式 |
| 游戏特性 | 手机视野、游戏助手、临场振感、旁路充电 | 全丢 |
| 外设 | 双 C 口视频输出 + 电脑模式/扩展屏（私有实现） | GSI 基本不可用 |
| 影音 | 杜比 + 双扬声器调教 | vendor 层可能丢 |
| 应用兼容 | QQ/TIM 正常、相机正常、反作弊正常 | QQ/TIM 不认（characteristics=device + telephony）、相机 fishfood 空壳 |
| 更新 | 官方 OTA（可能"推送负优化"） | 手动刷 |
| root | 解锁后可，1.5 通道存疑 | 自由 |

结论：GSI 只适合纯折腾/裸跑场景；完整体验（旁路充电、电脑模式、杜比、QQ/TIM 兼容）必须留原厂。甜点位 = **1.1 终版 + BL unlocked + Magisk**。

## 本机 adb 连不上的根因（2026-08 实测）
- `lsusb` 有 `17ef:7f40 Lenovo 拯救者平板 Y700` 但 adb/fastboot 空 → 设备端 USB 角色是 PTP（`bInterfaceClass 6 Imaging`）。修：平板通知栏切「文件传输/调试」+ 确认开发者选项 USB 调试 + 解锁屏幕接受 RSA 弹窗。udev 规则本机已齐（`51-ltbox-qcom.rules` 覆盖 17ef 的 ADB/fastboot）。
- 定制版 fastboot 无 `-i <vid>` 参数（无法指定厂商 VID）→ 需要 platform-tools 原版。
