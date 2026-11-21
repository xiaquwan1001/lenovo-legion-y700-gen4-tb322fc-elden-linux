# 历史最佳状态 · 现状差距 · 补全清单（主机侧只读分析，2026-11-21 深夜）

> **lanes**：best-state-recall（主机侧只读）。**零设备接触**：本文件未运行任何 `fastboot`/`adb`/`ssh`/`qdl`，
> 未跑 `scripts/vk-identity.py`，未删 `build/*`，未做 git 写，只写本文件。
> 设备「现在」一律引主会话 2026-11-21 16:05–16:20 的实测（`reports/session-plan-20261121-night.md` §1）与
> `reports/bootloader-slotguid-brick-20261121.md`，**本文不重新取证设备**。
> 状态真源仍按层级：`INDEX.md` §0 > `TASKS/README.md` > `DEVICE/README.md` §1.1；本文件只是「回顾 + 差距 + 清单」的汇合页。
> 判断不了的写 **证据不足**，不猜。

---

## §结论

### A. 「现在」到底是什么状态（两句话）

1. **设备停在 BL，ABL 半挂**：`fastboot devices` 能看见 `HA2EXB0E`、`getvar` 无回包；根因是 XBL 自报
   `ValidateSlotGuids: BootableSlot _b does not have valid guids` ⇒ `FindBootableSlot()` → `LoadImageAndAuth()` Device Error
   → `Launching fastboot`（证据：`reports/bootloader-slotguid-brick-20261121.md` §1，XBL `UEFILOG1.TXT` 行 437–449）。
   触发机制 = 本轮反复 `fastboot --set-active` 搬 partition type GUID，留下「GUID 侧 ≠ ACTIVE 位」半完成态（同文件 §2）。
2. **历史最佳 = 2026-11-20 23:10 那个态**（`DEVICE/README.md` §1.1 首条）：
   b 槽持久主启 Linux（三次冷起 ~25 s 直进）、`qbootctl` `_b` Active/Successful/Bootable 全 1、vk192
   （`7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`）、`/`=`/dev/sda17` 190 G / 1260 包 / Mesa 26.1.6、
   四进程桌面、`wlan0` 出网 + `usb0` SSH、音频 Speaker 出声 + 两侧马达震动（用户实测）、
   `deploy-desktop-shell.sh --check` = MISS=0、`suspend_stats` 4/0（`fail=0`）。
   **⇒ 与「现在」的差 = 一张 GPT 表 + 一次 boot_b 内容纠错，不是能力丢失。**

### B. 五条主结论（本次回顾最有价值的部分）

| # | 结论 | 证据指针 |
|---|---|---|
| 1 | **最佳状态是三件套，不是某个镜像**：同一 vk192 内核 + 190 G Debian 根 + 幂等部署脚本 `deploy-desktop-shell.sh`（`--check` = MISS=0 是唯一收尾判据）。历史最佳≠最全功能，而是「可复现 + 门绿」。 | `reports/audit-20261119/A2-best-state.md` §2.1；`scripts/deploy-desktop-shell.sh` §1–§12；`reports/t9-sampler-restored-20261121.md` §0 末行 |
| 2 | **★新发现（本文首次成文）：`bootslot-b/boot_b.img` 与现役根 label 不匹配，恢复时若按「常识」刷它会再失败一次。** `boot_b.img`（`06c081ca…`）内 cmdline = `elden_root=LABEL=linux17`；而 11-19 重建后的根 label 是 `linux`（`boot_b-minbase-labellinux-20261119.img` = `740d431b…`，cmdline `LABEL=linux`）。两者 sha 均已复核（见 §C 表脚注）。brick 报告 §4 记录本轮「换 vk192 签名件仍同败」时刷的正是 `boot_b.img` ⇒ **GUID 修好后还会撞 root 挂载失败**（与 11-18 RAM 启动失败同一条历史坑）。 | 本文 §C 脚注 ①；`reports/bootloader-slotguid-brick-20261121.md` §4 首行；`INDEX.md` §0「11-19 下午」条（`linux17` vs `linux` 是 11-18 两次 RAM 启动失败真因） |
| 3 | **11-19 重建根把用户态层冲回 stock trixie，只有被「机械化进脚本」的东西活下来。** 实测（`reports/ime-osk-zero-to-usable-20261121.md` §0.1）：phoc **0.46.0-1** / phosh **0.46.0-3**（我们自编的 0.59~rc1 / 0.58.0 不在机）、squeekboard 未装、fcitx5 手工起、`elden-ime-focusd` enabled 但 inactive。⇒ T20 电源键修复、phoc syncobj（droidloom L2）、IME T1/T2/T4、相机 IPA helper、waydroid 容器等 **全部按「非包资产丢失」回归**。这与 `PITFALLS` #689/#698/#700 是同一族，只是这次丢的是一整层。 | `PITFALLS/README.md:364`（#689）、`:373`（#698）、`:375`（#700）；`reports/ime-osk-zero-to-usable-20261121.md` §0.1 |
| 4 | **两条「只差一个内核/镜像改动」的大项被宿主机事实挡住**：uinput（`patches/config-daily-c3-uinput-20261113` 里已是 `CONFIG_INPUT_UINPUT=m`，现役 vk192 用的是 c2 口径、仍是 `not set`）+ 任何内核重编，都要求先恢复内核源树 —— `build/` 37 G 内核树与 `geekidos-linux/` 已于 11-19 删除（`versions/layout.tsv:42-49` 记录恢复三命令，bundle 在盘：`backup/git-slim-20261113/geekidos-all-20261113.bundle` 315 MB）。盘上现在唯一的内核树是 `build/elden-tree` = **pristine 7.4-rc3 上游**（`git describe` = `v7.4-rc3`），不含 daily payload/DTS。 | 本文 §C 脚注 ②；`versions/layout.tsv:42-49`；`patches/config-daily-c3-uinput-20261113:3675` |
| 5 | **a 槽（安卓）不是「镜像坏了」，是「super 内容假设 H2 仍存活 + 观测口缺」**：11-21 三发对照逐字同现象，H5（`vbmeta_a`）与「`/data` 是 ext4」两个单变量已排除，`pstore` 空 ⇒ 失败点在 ramdisk 之后/上层，没有日志证据（`reports/a-slot-h5-three-way-20261121.md` §1/§2）。按用户裁决本轮不盲试。 | `reports/a-slot-h5-three-way-20261121.md` §0 表、§2；`PITFALLS/README.md:378`（#703） |

### C. 功能矩阵（最佳过的时间点 → 现在）

图例：**现值** = 最佳之后是否仍成立（`在` 未回退 / `回退` 已丢失 / `未知` 证据不足）；**因** = `已知(<指针>)` / `未知`。
「vk」= 该最佳态当时内核版本号；「关键配置」只写与该项耦合的非默认项。

| 项 | 最佳时间点 | 证据指针 | 当时 vk | 关键配置 | 现值 | 因 |
|---|---|---|---|---|---|---|
| G1-1/2/3 基线起机（b 槽直启 + 190 G 根） | 2026-11-20 23:10（三次冷起 ~25 s） | `DEVICE/README.md` §1.1 首条；`INDEX.md` §0「11-20 22:00」条 | vk192 | `boot_b`=`740d431b…`(cmdline `LABEL=linux`)、`config-daily-c2-suspend` | **回退**（起不来，BL 半挂） | 已知：GPT GUID 半完成态（brick §1）+ 结论 2 的 label 陷阱 |
| G1-4 音频（播放 + 麦克风） | 2026-11-20（用户实测出声） | `PITFALLS/README.md:373`(#698)；`INDEX.md` §0「11-20」条音频段 | vk192 | 自编 tplg 进 `/lib/firmware/qcom/sm8750/` + UCM2 两文件 + `alsa-utils`；`deploy-desktop-shell.sh` §10 | 未知（设备起不来） | 已知：部署面已机械化 §10（可一条命令复验） |
| G1-5 相机出流 + AE | 2026-10-18（后 30.06 fps / 前 30.26 fps） | `TASKS/README.md:70`（G1-5 行）；`reports/camera-linux-vk127-20261018-agc-rootcause.md` | **vk127（7.3-rc7）** | `CAM_FORCE=1 camera-modules-load.sh` 手载 20 个 `.ko`；自编 `ipa_soft_simple.so`（增益模型 + 黑电平 4096） | **回退**（重建根丢 IPA helper；端口在但零流验证） | 已知：非包资产丢失（`DEVICE/README.md` §1.1「AE 正解 = libcamera 侧 sensor helper」条）+ 需选内核基线（vk127 vs vk192 模块树不通用） |
| G1-6 TF 卡写稳定 | 2026-10-26（新卡 CBADS 58.6 GiB，`tf-stress --fsck -r 3` 不一致 0） | `TASKS/README.md` G1-6 行 | vk 无关（驱动层） | — | 未知（未插卡复测） | 未知 |
| G1-7 BT 配对 | 2026-10-06（用户实测 TWS 实听） | `TASKS/README.md` G1-7 行 | vk64 代 | WCN7861 固件 | 未知（新根 `bluez` 状态未取证） | 未知 |
| G1-8 CPU/GPU 基准 | 2026-10-11（vkmark ~25532 / es2gears ~164 FPS） | `TASKS/README.md:73` | vk64 | — | 未知（未重跑） | 未知（仅口径可复用） |
| G1-9 DP 外接输出 | 2026-10-07（dp5 载具 + 用户目视出画面）；11-19 复现 `af54000.displayport-controller` bound | `TASKS/README.md:45`；`INDEX.md` §0「11-19 下午」条 | vk40→vk192 | UCSI/PPM 走 ADSP；fw_devlink 修复 | 未知（起不来） | 未知（驱动面随 vk192 在内核里） |
| G1-11 CDSP | 2026-10-07（`remoteproc1 state=running`） | `TASKS/README.md:47` | vk40 代 | `/lib/firmware/qcom/sm8750/cdsp.mdt` 分片布局 | 未知 | 未知 |
| G1-12…21 显示 165 Hz / A830 / 触屏 / WiFi / BT / 充电+旁路 / 温控 / 带外串口 / 触觉 | 触觉 2026-11-20（用户实测两侧震）；其余 2026-10 各点 | `TASKS/README.md:77`（聚合行）；触觉见 `PITFALLS:373` | 触觉 = vk192 | 触觉 = `aw86927` + haptics-v3 + `ffrumble`（`deploy §11`）；165 Hz 面板默认 | 触觉 **在**（部署面已机械化）；165 Hz/充电/温控 **未知** | 未知（面板参数在 DTB，随 vk192 在） |
| G1-22/33 熄屏×相机（Q24） | 2026-10-23 结项（上游 `rpmhpd: skip retention` 已含） | `TASKS/README.md:47`(G1-22 行) | ≥7.3 | 不需本地补丁 | 在（口径层面） | — |
| G1-24 Linux→fastboot（软路径） | 2026-10-03 深夜（`elden/vk41-psci-reboot` + `scripts/eldroid-bootctl`） | `TASKS/README.md:48` | **vk41 分支（未进日常线）** | PSCI `SYSTEM_RESET2` vendor reset | **回退**（vk192 零 vendor reset handler；`misc` BCB ABL 不采纳；`qbootctl -u` 失败） | 已知：`PITFALLS/README.md:365`(#690)、`:376`(#701)（`-s` 仍可用，见 #707） |
| G1-29/拓展 UEFI（flashed + 间接 GRUB 两形态） | 2026-11-16 14:03（a 槽暖启 44 s / POR 冷启菜单正常；pstore 守卫真机 A/B 成立） | `INDEX.md` §0「下一步」第 5 条；`reports/pstore-ram-initrd-guard-20261116.md` §5 | vk192（守卫核 `0a55e52c…`） | ESP `/EFI/BOOT/BOOTAA64.EFI` = 嵌入菜单 GRUB v10；`/boot/{Image,initrd.img,elden.dtb}` | **回退**（`vendor_boot_b` 已写回原厂 ⇒ b 槽 ESP 形态丢失；`boot_a` 内容演进过） | 已知：`bootloader-slotguid-brick-20261121.md` §4 末行 |
| G1-34 传感器（SSC/QRTR） | 2026-11-13（vk190）/ 11-16（vk192）：`/dev/fastrpc-adsp` + qrtr 400 + SensorProxy 三项 true | `DEVICE/README.md` §1.1「历史：在机 = vk192」条；`TASKS/README.md:29` | vk190 / vk192 | DT `qcom,non-secure-domain` + fork/sid 级 `iio-sensor-proxy`+`libssc2` | **回退**（`/sys/bus/qrtr` 不存在、`hexagonrpcd` masked） | 已知：`PITFALLS:367`(#692) 硬崩 + 11-19 根无 `libssc2`；`reports/audit-20261119/A8-device-state.md` §6 |
| G1-35/36 网络自愈 / WiFi 候选榜 | 2026-11-20（`wlan0` 默认路由 + `usb0` SSH 并存） | `INDEX.md` §0「11-19 22:5x」条与「11-20」条；`TASKS/README.md:60` | vk192 | `wifi-scan-refresh.service`、`ath12k-rescan.service`（enabled） | 部分 **在**（两 service 已固化），凭据层 **缺**（NM 连接档为空 = 人项） | 已知：`PITFALLS:364`(#689) 非包状态丢失；`DEVICE/README.md` §1.1「WiFi 现态」条 |
| G1-37 日用基线（1256–1260 包） | 2026-11-20（1260 包） | `DEVICE/README.md` §1.1 首条 | vk192 | `deploy-desktop-shell.sh` §2 包盘点 | 未知（`--check` 未跑） | 未知 |
| G1-38 OSK/中文输入 | 2026-11-13（主链通）/ 2026-10-20（C11 上机验收） | `TASKS/README.md` G1-38 行；`reports/ime-osk-zero-to-usable-20261121.md` §0.1 | vk184 / vk127 | 自编 phoc/phosh + `elden-ime-focusd` + `GTK_IM_MODULE` 决策 | **回退**（focusd inactive、T1/T2/T4 三项修复丢失、`graphical-session.target` inactive） | 已知（结论 3）；待用户拍板 GTK_IM_MODULE 二选一（`TASKS/README.md` §4 2026-11-21 ⑦） |
| 桌面壳 / GPU（Phosh + Mesa 26.1.6 A830，glmark2 2594） | 2026-11-20（冷起 MISS=0） | `INDEX.md` §0「11-19 13:20」条；`DEVICE/README.md` §1.1 | vk192 | Mesa trixie-backports；GPU devfreq 525 MHz/10 ms（`deploy §8`） | 未知（设备起不来；重建根后 11-19 起**确曾**绿过） | 未知 |
| 桌面层两回归（T20 电源键 / syncobj） | 2026-11-14 晚（T20 上机验收）/ 2026-11-11（syncobj 57 全局） | `INDEX.md` §0 第 5 条；`TASKS/README.md` C12 行 | vk189/vk192 用户态 | 自编 phoc 0.59~rc1 + phosh 0.58.0，`dpkg-divert` + `apt-mark hold` | **回退**（现机 phoc/phosh = 0.46.0 发行版） | 已知：重建根 + 自编件未机械化（`PITFALLS #654` 同类风险） |
| 电源 s2idle | 2026-11-16（3/3 rc=0、`fail=0`）→ 2026-11-21（4/0，采样器端到端） | `DEVICE/README.md` §1.1；`reports/t9-sampler-restored-20261121.md` §0 | vk192 | `CONFIG_SUSPEND=y`（`config-daily-c2-suspend`）；`elden-resource-sample.timer` | 未知（起不来；采样器已装过但随根/时间待复核） | 未知 |
| G2 容器 C1（Waydroid 端到端） | 2026-10-11 治本（vk103 `CONFIG_IPV6_MULTIPLE_TABLES`，容器 `curl baidu=200`） | `TASKS/README.md` C1 行 | vk103 | 内核 `IPV6_MULTIPLE_TABLES`（现 c1/c2 均 `=y`，内核侧已具备） | **未知**（新根是否装了 waydroid 未取证；A8/A2 均未列） | 未知（若缺 = 只缺部署，容器镜像件在 `backup/` 与 `versions/out-images-sha256-*`） |
| G2 C2 GMS 登录 | 2026-10-11（用户人工验证登录成功） | `TASKS/README.md` C2 行 | vk103 | 容器经宿主代理出网（PC `192.168.7.9:7897`） | 未知（同 C1 前置） | 未知 + 依赖外部上行 |
| G2 C3 完整性等级 | 2026-11-15 实测收口 `deviceRecognitionVerdict=[]` | `TASKS/README.md:90`；`reports/c3-spic-verdict-20261115.md` | vk127 代 | — | 在（结论不随根变化，只需重装容器即可复验） | 结构性（无 TEE） |
| G2 C4 传感器注入 HAL | 2026-10-11（6 传感器 running） | `TASKS/README.md:91` | vk103 代 | `eldroid-sensord` UDP + overlay 部署（`scripts/deploy-sensors-hal.sh`） | 未知（依赖 waydroid 在机） | 未知 |
| G2 C5 相机共享 | 2026-10-28（容器 1 个设备、HAL 稳定）；2026-11-12 v4l2loopback v0.15.4 | `TASKS/README.md:92` | vk127 / vk184 | `v4l2loopback 0.15.4` + `lxc.mount.entry /dev/video100` + NV12 源 | 未知（多重前置） | 未知；剩余 = U7 App 预览（🟡 未收口） |
| G2 C6 容器音频 | 2026-10-11（闹钟出声 + 开机持久） | `TASKS/README.md:93` | vk103 代 | 四层镜像修复（vendor manifest/dma_heap…） | 未知 | 未知 |
| G2 C10 马达透传 | 2026-10-13（+10-17 amplitude 255）；11-20 宿主侧两侧震动实测 | `TASKS/README.md:97`；`DEVICE/README.md` §1.1 | vk124/vk127/vk192 | `vendor.img` 固化自编 vibrator HAL + RRO；宿主 `elden-hapticd` + `sys/class/leds` 桥 | 宿主侧 **在**；容器侧 **未知**（`/var/lib/waydroid` 随根重建丢失） | 已知（结论 3 同族） |
| G2 C11 中文 IME（容器/桌面） | 2026-10-20（Phosh 0.55 / phoc 0.55.1 / squeekboard + fcitx5 Rime） | `TASKS/README.md:98` | vk127 | squeekboard + `sm.puri.OSK0` + `fcitx5 --disable waylandim` | **回退**（squeekboard 未装、phoc/phosh 0.46） | 已知（结论 3） |
| G2 C12 droidloom | 2026-11-11（L1–L4 全绿，用户目视窗口；依赖 phoc syncobj 自编件） | `TASKS/README.md:99` | **vk187b**（`CONFIG_NF_TABLES`） | phoc 自编（syncobj）+ subuid/祖先属主契约 | **回退**（phoc 0.46 无 syncobj ⇒ L2 结构性不可达；nftables 在 c2 已 `=y`） | 已知（结论 3） |
| G3 Steam 登录界面 | 2026-10-28（设备实测 3/3） | `TASKS/README.md` §0 G3 行；`reports/g3-steam-20261028.md` | vk 无关 | Box64/Wine 层 | 未知（未重跑） | 未知 |
| 双槽（A/B 往返） | 2026-10-11（`slot-switch.sh` 全路径）；11-20 `_b` 全 1 | `TASKS/README.md` C7 行 | vk192 | `qbootctl`/`slot-attr.py` 直写 LUN4 | **回退**（`_b` GUID 非法；a 槽 `Bootable 0`） | 已知：brick §1/§2；`PITFALLS:372`(#697) |
| 安卓 a 槽可用 | 2026-11-18 19:0x（`super_min` v1 两发 `boot_completed=1`） | `INDEX.md` §0「11-18」条；`TASKS/README.md:88` | 安卓 GKI 6.6.118 | `super`=v1 slim + `boot_a` 原厂 + `vbmeta_a` flags1 | **回退**（11-21 三发同现象失败） | 已知分层：H5/H6a 排除、H2/H7 存活（`a-slot-h5-three-way` §2） |

**§C 脚注**
① 本轮复核的 sha 与 cmdline（ODIRECT/buffered 均一致；命令形态见 §补全清单 A1 判据）：
`bootslot-b/boot_b-minbase-labellinux-20261119.img` = `740d431b2577f95a421adca53551b1afd293811c2c8fad3ed535fe0c71d275e4`，cmdline `… elden_root=LABEL=linux …`；
`bootslot-b/boot_b.img` = `06c081ca4af94915339bf02a0209dbe374fe5cd7111c29588e7de8773807dc8b`，cmdline `… elden_root=LABEL=linux17 …`；
`out/boot-elden-vk192.img` 同 `06c081ca…` 的 label（`LABEL=linux17`，见 `out/boot-elden-vk192.manifest` cmdline 行）。
② `patches/config-daily-c3-uinput-20261113:3675` = `CONFIG_INPUT_UINPUT=m`；`patches/config-daily-c2-suspend-20261113:3675` = `# CONFIG_INPUT_UINPUT is not set`；
`out/boot-elden-vk192.manifest` 的 `config_sha256=cbcfd84e…` 属 c2 口径（c3 是后出的快照，未进 vk 账）。

### D. 回退成因三分类（决定「补」的成本）

| 类型 | 判据 | 命中项 | 补的成本 |
|---|---|---|---|
| **D1 一次性事件**（不补就回不来，补一次即恢复） | 只因 GPT/槽属性/一次误刷 | 起机、`_b` GUID、a 槽属性、`boot_b` 内容错配 | 一个设备窗口（~30 min，含物理键） |
| **D2 非包资产丢失**（重建根/重建件必丢，已被 `PITFALLS` 反复记录） | 不在任何脚本清单里 | phoc/phosh 自编件、IPA helper、IME T1/T2/T4、waydroid 容器+vendor.img、T9（已机械化）、WiFi 凭据 | 需**逐项机械化**进部署脚本，否则下次重建再丢 |
| **D3 能力本来就缺**（从未有过或结构性） | 历史最佳也没有 | uinput（从未开）、T19 撕裂（缺 mesa 26.2.5）、Play Integrity STRONG（无 TEE）、Widevine arm64、NFC（无硬件）、Linux→fastboot 软路径（vk192 无 PSCI 钩子） | 见 §补全清单 ②③④ |

---

## §补全清单

四类口径：**① 只缺部署**（件都在盘上/设备上，缺的是「照做一次」）· **② 缺一个内核/镜像改动**（要动内核、boot.img、rootfs 造件）·
**③ 缺上游修复**（等上游/需上游形态）· **④ 缺硬件/外部资源**（人项或物理不可得）。
「窗口」= 预计**设备在线时间**（不含主机准备）；「判据」给出可复跑的形态，`【需设备】` 标注必须设备在线的部分（本文未执行）。
回退件一律给**盘上存在的路径**；不存在写「无（需重造）」。

### A. ① 只缺部署

| # | 事项 | 判据（可复跑） | 窗口 | 回退件 |
|---|---|---|---|---|
| A1 | **修槽位 GUID 半完成态**（本清单的最高优先，一切的前提）：物理长按断电 → `fastboot oem edl` → `qdl read 4/0+7` → 与 11-20 基线**逐分区比 type GUID** → 不同则整对写回、只 ACTIVE 位不同则 `gpt-slot-flip-active.py --activate b`；写盘统一 `scripts/linux-gpt-apply.sh --lun 4 … --apply`（内建写前 dump + 写后 O_DIRECT 读回） | 主机：`python3 - <<'EOF'`（比对两表 type GUID，见 brick §3 步骤 2）；`【需设备】` 写后 `qbootctl -a` = `_b` Active/Succ/Bootable 全 1 | ~25（含物理键与一次冷起） | `backup/HA2EXB0E-16+512/edl-20261120-2208/gpt4-{primary,backup}.bin`（当时 b 槽能起 Linux） |
| A2 | **刷对 boot_b**（结论 2）：恢复后**不要**刷 `bootslot-b/boot_b.img`（label `linux17`），改刷 `boot_b-minbase-labellinux-20261119.img`（`740d431b…`）；若坚持用 `out/boot-elden-vk192.img`，必须先用 `scripts/boot-img-cmdline.py` 把 `elden_root` 改成 `LABEL=linux` 并重签 | 主机：解析 header v2 cmdline（本文 §C 脚注 ① 的取法）+ `sha256sum` 命中 `740d431b…`；`【需设备】` 起机后 `findmnt -no SOURCE,LABEL /` 应为 `/dev/sda17` `linux` | 5 | 同文件本身（`740d431b…`）；再往前 = `out/min-restore-20261119/`（同代根件，`versions/out-artifacts.tsv` 标 verified） |
| A3 | **起机后立刻做三件收尾**：`fix-ab-mark-successful` 落盘（或 `qbootctl -m`）、`deploy-desktop-shell.sh --check`（MISS=0）、T9 timer active | `【需设备】` `systemctl is-active elden-resource-sample.timer`；`bash scripts/deploy-desktop-shell.sh --check`（§1–§12） | 5 | 无（只读判据） |
| A4 | **桌面层自编件回归**（T20 电源键 + syncobj）：`scripts/phoc-install.sh` 装 0.59~rc1/0.58.0 两枚自编件（`build/phoc-src-0.59~rc1`、`build/phosh-src-0.58.0` 在盘） | `【需设备】` `dpkg-divert --list \| grep -E 'phoc\|phosh'`；`command -v wayland-info && wayland-info \| grep -c syncobj_manager_v1`（期望 1） | ~20（含 greetd 重启 + 目视） | `phoc.orig*`（divert 目标，脚本自动留）；`scripts/phoc-install.sh` 自带 `--revert` 口径见脚本头 |
| A5 | **IME/OSK 三修 + focusd + 候选窗**：按 `reports/ime-osk-zero-to-usable-20261121.md` P1/P2/P3 执行（`scripts/deploy-zh-ime.sh`、`scripts/ime-candidates-check.sh`）；**GTK_IM_MODULE 二选一需用户拍板** | `【需设备】` `bash scripts/ime-candidates-check.sh`（历史判据 11 PASS / 0 FAIL）；`systemctl --user is-active elden-ime-focusd` | ~25 | 无（全是配置/包，`/etc/environment.d/50-elden-ime.conf` 改前留 `.bak-<date>`） |
| A6 | **相机栈部署**：`scripts/deploy-camera-modules.sh` + `camera-modules-load.sh`（`CAM_FORCE=1`）+ 自编 `ipa_soft_simple.so`（配方 `reports/camera-ae-helper-20261017.md` §2） | `【需设备】` `ls /dev/video*`（应 ≥17 个）+ `camera-stream-up.sh`（后摄 ≥25 fps）；回退判据 = 无该 `.so` 时 `libcamera` 退回发行版（AE 不收敛但不出错） | ~30（含 30 fps 出流回归） | 设备侧 `/root/ipa-bak-20261017/`（**该目录随 11-19 重建根丢失，需按配方重编 = 主机侧活**）；`/root/cam-ko-bak-20261017/` 同 |
| A7 | **Waydroid 栈重装 + 容器资产回刷**（C1/C2/C4/C5/C6/C10/C11 的共同前置）：装 `waydroid`+`lxc`（`rootfs/debian/stage.sh` 的清单口径）→ `waydroid init` → 回刷 `vendor.img`（相机 gralloc + vibrator HAL + RRO 版）→ `scripts/deploy-sensors-hal.sh` + `scripts/waydroid-haptics-setup.sh` + `scripts/waydroid-cam-restart.sh` | `【需设备】` `waydroid status`（RUNNING）；`waydroid shell dumpsys media.camera \| grep -c 'Number of camera devices'`；`waydroid shell curl -x <proxy> https://www.google.com`（302） | ~60–90 | 镜像 sha 账 `versions/out-images-sha256-20261105.tsv`；设备历史回退名 `vendor.img.bak-l1d-20261029-103701` / `.bak-elden-haptics-20261013-115055`（**均随根丢失，需按账重造**） |
| A8 | **WiFi 连接档 + 时钟**（人项：SSID 凭据） | `【需设备】` `nmcli connection show`（应有非 lo 项）；`timedatectl` 与主机差 < 1 天 | 10 | 无（`deploy §4b/§7` 会自动补路由/DNS） |
| A9 | **UEFI b 槽 ESP 形态重建**（11-21 被写回原厂）：`out/uefi-bslot-20261121/` 四件 + 重新把 `vendor_boot_b` 做成 FAT32 `ELDENESP` | `【需设备】` `fastboot getvar partition-type:vendor_boot_b` 或读回分区头 vs `backup/official-rom-15.10.259/vendor_boot.img`；ESP 判据 = cmdline 出现 `elden_esp_grub=<token>`（**不要**用 `elden_bootpath=uefi`，`PITFALLS:383` #708） | ~15 | 原厂件 `backup/official-rom-15.10.259/vendor_boot.img`（本轮已写回的即是它） |
| A10 | **a 槽安卓最小单变量实验**（仅在用户放行后）：按 `scripts/android-v3-bringup-walkthrough.sh` S1–S5（清 BCB → 读回 → `metadata` → 原厂 `super` 对照 → 带 `console=ttyGS0` 取证件） | `【需设备】` 每发后 `qbootctl -a` + `adb wait-for-device` 4 min 采样（判据表 `a-slot-h5-three-way` §0） | ~60（4 发 × 15） | `out/android-min-20261118`（v1，pending 禁删）、`out/android-v3-bringup-20261120`（S5 两件） |
| A11 | **zramswap 基线**（G1-37 收口项之一） | `【需设备】` `swapon --show` 应见 `/dev/zram0`；`modprobe zram; zramswap start`（发行版脚本） | 5 | 无 |

### B. ② 缺一个内核 / 镜像改动

| # | 事项 | 判据 | 窗口 | 回退件 |
|---|---|---|---|---|
| B0 | **前置（纯主机，不占设备）：恢复内核源树**。`versions/layout.tsv:42-49` 三条命令（bundle 在盘 315 MB）；恢复后 `versions/kernel-src-archive.tsv` 应清空、`vk-identity` 的 76 行 WARN 自动消 | 主机：`git -C geekidos-linux describe --tags` 有输出；`bash scripts/check-doctor.sh` §5d 不再 WARN | 0（设备无） | `backup/git-slim-20261113/{geekidos-all,m3v2-all,main-all}-20261113.bundle` |
| B1 | **开 `CONFIG_INPUT_UINPUT`**（解锁「桌面内自动验证」：锁屏可注入触摸，agent 不必人手滑开）：用现成快照 `patches/config-daily-c3-uinput-20261113` 走 `scripts/build-kernel.sh` 整套 + 部署**整套** `/lib/modules/<新UTS>` | `【需设备】` `ls -l /dev/uinput`；`deploy-desktop-shell.sh --check` MISS=0 | ~40（编译在主机，设备只刷 b 槽 + 模块树 + 冷起） | `boot_b-minbase-labellinux-20261119.img`（`740d431b…`）；模块树无主机归档（**需当场从设备 tar 备份**，见 B0 之后） |
| B2 | **把「非包资产」机械化进 rootfs/deploy 清单**（治 D2 根因）：至少 `phoc/phosh` 自编件 + `divert`、IPA helper、IME 三修、waydroid 容器三件、T9（已做 §12）、WiFi 档（人项除外） | 主机：`bash scripts/check-doctor.sh`（§22 非包锚点门扩展）；`rootfs/debian/stage.sh` 4d 同类锚点 | 0（主机） | 逐个 `.bak-<date>`；仓内脚本均有 `--revert`/`--check` |
| B3 | **相机在 vk192 上的出流回归**（决定 G1-5 要不要退回 vk127 基线）：vk127 与 vk192 的模块树不通用（UTS 不同），要先在 vk192 上跑一次 30 fps | `【需设备】` `camera-stream-up.sh` 两路 fps + dmesg 零 `camss/vfe/EPIPE` | 30 | `bootslot-b/boot_b-vk127.img`（10-18 件，在盘）——但换 vk127 会丢 s2idle/守卫核 ⇒ 属互斥项（见下） |
| B4 | **UEFI XOR 修复固化进日常核**（若还要走 GRUB 直载）：pstore/ram 守卫已在 vk192 内（`5c72e9e838`+`4bdf1711b5`），**无需再改**；此条只登记「已具备」 | 主机：`git -C <daily> tag --points-at 4bdf1711b5` = `vk192` | 0 | — |
| B5 | **安卓 super 侧改动**（若 H2 存活后仍要精简）：v3（7.1 GiB）/v2b（9.2 GiB）件已在盘、`pending` 禁删 | `【需设备】` 首启 `adb shell getprop sys.boot_completed` = 1 | 30/发 | `out/android-min-20261118`（v1，`e3d0d26f…` 逐字节） |

### C. ③ 缺上游修复

| # | 事项 | 判据 | 窗口 | 回退件 |
|---|---|---|---|---|
| C1 | **T19 撕裂** = 带 modifier 的 dmabuf 导入，缺 mesa **26.2.5** A/B | 主机：`reports/tearing-*`/`TASKS/README.md:318` 口径；`【需设备】` 滚动 `gnome-software` 目视 | 15 | 现役 Mesa 26.1.6（`scripts/mesa-deploy.sh`） |
| C2 | **传感器 SSC** = 上游 M10 形态（`qcom,non-secure-domain`，已投 1×250）+ 需要 fork/sid 级 `libssc2`（Debian 13 没有） | `【需设备】` `ls /sys/bus/qrtr/devices`；`qrtr-lookup` 见 `400 Snapdragon Sensor Core`；`hexagonrpcd` 起后**不许硬崩**（`PITFALLS:367` #692） | 20（风险高，需串口/ramoops 取证窗） | `boot_b` 现役件（crash 只会回 Linux）；mask 状态可 `systemctl unmask` 回退 |
| C3 | **camss CSIPHY 2.4.0 v2**（6 门全绿、只缺一次 30 fps 实测；等 Qualcomm SM8750 CAMSS v8 落地定形状） | 主机：`patches/upstream/camss-csiphy-24-v2-20261117/` 的 6 门；上游：`git log --oneline v6..` 是否进 tree | 30（与 B3 同一窗口） | 不投即无风险（在档） |
| C4 | **dwc3 v10**（已投 4 封 250）：缺 mux 实际切换/双口枚举上机验证 | `【需设备】` 两口各插一次看 `lsusb` 枚举 + `dmesg` mux 切换 | 20 | `PITFALLS:381`(#696) 记录 GPIO 极性无硬件证据；软件回退 = 不加 mux 的 v9 形状 |
| C5 | **Mobian 路线**：内核 LTS 版本账（我们是 7.3/7.4，Mobian 只收 6.1/6.6/6.12/6.18）——不碰内核的第一件可提交物 = `droid-juicer` 配置 + `wip.toml` | 主机：`reports/distro-upstream-feasibility-20261121.md` §结论；`reports/mobian-upstream-firstpr-20261121.md` | 0（主机） | — |
| C6 | **fastrpc `qcom,nsessions` 已被上游废弃合入**（`641dd7dd0f68`）⇒ 板级 DTS 若仍写该属性要删/改写 | 主机：`rg -n 'qcom,nsessions' patches/ build/ 2>/dev/null` | 0 | — |
| C7 | **kexec LPI（M9）已被 Marc Zyngier 否决并撤回** ⇒ 本机 kexec 拿不到显示，**不要再规划 kexec 路线** | 主机：`TASKS/README.md` §7 M9 行 | — | — |

### D. ④ 缺硬件 / 外部资源

| # | 事项 | 判据 | 说明 |
|---|---|---|---|
| D1 | **进 fastboot 只能物理键**（vk192 零 vendor reset handler；BCB ABL 不采纳；`qbootctl -u` 失败）⇒ **每个设备窗口都需要人在场** | `PITFALLS:365`(#690)、`:376`(#701)；反例边界 `:382`(#707)（`qbootctl -s` 与 `dd` 写分区**不需要**物理键） | 影响所有窗口的排期，不是技术债 |
| D2 | **Play Integrity BASIC/DEVICE/STRONG 三档全红**（无 TEE、keymaster 软实现、解锁态） | `reports/c3-spic-verdict-20261115.md` | 结构性；PIF 伪装未做、不承诺 |
| D3 | **Widevine**：arm64 只有 ClearKey（比 L3 更低；arm64 L3 仅 A11 有） | `TASKS/README.md:90` C3 行 | 外部库不可得 |
| D4 | **NFC**：本机无硬件（vendor 无 HAL/manifest/固件） | `TASKS/README.md:46`（G1-10） | 已取消，永不补 |
| D5 | **RTC 不可写**（`ioctl(RTC_SET_TIME)` 无设备）⇒ 依赖 `fake-hwclock` | `DEVICE/README.md` §1.1「2026-11-16 新增 fake-hwclock」条 | 硬件限制 |
| D6 | **G2 出网**：容器经宿主代理 + 校园网/代理上行（C2 的前置） | `TASKS/README.md` C2 行 | 外部 |
| D7 | **G3 x86 游戏端到端**：FEX/box64 层 + Steam 运行库（PoC 与登录界面已过） | `TASKS/README.md` §0 G3 行 | 外部资源/时间 |

### E. 互斥项（**动手前必须先选基线**，选错等于白跑一个窗口）

| 互斥组 | 选项 | 互斥点 | 选择建议（依据） |
|---|---|---|---|
| **M1 内核基线** | ① vk192（7.3.1 + s2idle + pstore 守卫，当前最佳）② vk127（7.3-rc7 + 相机 30 fps 历史最佳）③ 新编（c3-uinput / 新 config） | UTS 不同 ⇒ 模块树整套不同（1510 `.ko`），且换核要重刷 `boot_b` | **默认 vk192**：s2idle/守卫/桌面/音频/触觉全在它上面；相机先在 vk192 上复验（B3），失败才谈② |
| **M2 根 label** | ① `linux`（11-19 起现役）② `linux17`（11-18 前） | boot 件 cmdline 硬绑，错配 = 起不来（11-18 两次 RAM 启动失败真因） | **`linux`**；任何新 boot 件必须先改 cmdline（A2 判据） |
| **M3 分区布局** | ① GPT-minimal 2026-11-18（`linux` 起点 90504，**覆盖 `super`** ⇒ a 槽永不可起）② 双轨 11-19（`linux17` @73277435 + `userdata` 256.7 G，安卓面保留） | 同一 LUN0 只能一套表；①一旦落地不可逆（真回退 = 写旧表 + 重刷官方 `super` ~20 min） | **②（双轨）**，现役即是；`backup/official-rom-15.10.259` 保留为唯一回退 |
| **M4 槽位归属** | ① b=Linux / a=安卓（现役）② b=Linux / a=UEFI+GRUB ③ a=安卓 / b=UEFI | 每个槽只能放一份 `boot_*`；`boot_a` 历史上有 3 种内容（原厂 / UEFI pc1 / 最小安卓） | **①为主**，UEFI 只做零写盘或 b 槽 ESP（A9），避免动 `boot_a` |
| **M5 super 内容** | ① 原厂 14.5 GiB ② v1 slim 8.28（在机）③ v3 7.1 ④ v2b 9.2 | 同一 `super` 只能一份；`vbmeta_system_a` 仍是原厂 ⇒ 自建 super 必开 verity-off | **暂不动**（H2 未定论）；若动，先在原厂 `super` 上做对照发（S3） |
| **M6 rootfs 代** | ① Alpine（`linux18`，**已不存在**）② minbase 6 G（11-18 件）③ 现役 190 G 日用根（11-19 重建 + 11-20 补音频触觉 + 11-21 补 T9） | 同一 `linux17` 只能一版；且**用户态层非包资产不在任何镜像里** | **③**；任何重装必须重跑 A3–A7 全套，否则再回 D2 |
| **M7 phoc/phosh 代** | ① 发行版 0.46（现机）② 自编 0.59~rc1 / 0.58.0 + divert | `dpkg-divert` 二选一；T20 修复与 syncobj 只在② | 要 T20 熄屏/长按或 droidloom L2 ⇒ **必须②**；只要日常桌面 ⇒ ① 够用 |
| **M8 a 槽 vs b 槽的 ESP 承载** | ① `boot_a`=UEFI（flashed 形态）② `vendor_boot_b`=FAT32 ESP（纯 b 槽基建） | 两者都占 96 MiB 分区，同一时刻只能一处生效；②不碰现有引导，①会挤掉安卓 a 槽 | **②**（11-21 已落地过，A9 重建）；①留作对照 |

---

## §证据不足（本文判断不了的，显式列出）

| # | 项 | 为什么判不了 | 复核形态 |
|---|---|---|---|
| 1 | 现役 190 G 根里 **waydroid 是否已装** | 设备起不来；11-19 之后的报告（`A8-device-state.md` §6、`INDEX.md` §0 11-20 条）都没列 waydroid；`deploy-desktop-shell.sh` 的 `PKGS` 也不含它 ⇒ **既不能断言在，也不能断言不在** | 起机后 `command -v waydroid; systemctl is-enabled waydroid-container` |
| 2 | 165 Hz 刷新率、充电旁路、温控分级在新根是否仍生效 | 这三项只在 2026-10 的历史行里，11-19 之后无复测记录 | `【需设备】` `cat /sys/class/drm/card0-*/modes`、面板 DT 参数、`/sys/class/power_supply/*/status` |
| 3 | BT（G1-7）在新根的包/服务状态 | 同上；`bluez` 未在任何部署清单里核对过 | `【需设备】` `systemctl is-active bluetooth; bluetoothctl show` |
| 4 | G1-8 基准分、G3 Steam 在新根是否复现 | 需重新跑，属「未重跑」不是「已回退」 | 各自脚本 |
| 5 | `b` 槽当前 GUID 侧到底搬到了哪一侧 | 需 EDL 现读 LUN4 主备表（本文只读、不碰设备） | A1 步骤 1–2 |
| 6 | a 槽失败点（H2 `super` 内容 vs H7 ramdisk 早段） | 三发对照只排除了 H5/H6a，`pstore` 空 ⇒ 无日志证据 | A10 的 S5（`console=ttyGS0` 取证件已能造：`out/android-v3-bringup-20261120/boot-ttygs0-*.img`） |
| 7 | 内核源树恢复后 `vk-kernel-identity.tsv` 76 行能否全部转绿 | 需实际重克隆 + 重跑核对（**禁**跑 `scripts/vk-identity.py` 全量写表） | B0 判据 |
| 8 | `build/elden-tree`（7.4-rc3 pristine）是否含 elden 板 DTS | 只看了 `git describe` 与 Makefile，未 ls DTS | `ls build/elden-tree/arch/arm64/boot/dts/qcom/*elden*` |

---

收尾: 出 `reports/best-state-and-gap-20261122.md`（最佳态 = 2026-11-20 23:10 vk192 三件套；与现在的差 = 一张 GPT 表 + 一处 boot_b label 错配；已给四类补全清单 30 条 + 8 组互斥项）。
