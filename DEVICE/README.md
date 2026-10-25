> 会话进度见本目录 `sessions/`；本文件为该角度策展 SSOT。
# 设备描述与设备状态（DEVICE）

> 本角度文件夹的策展 SSOT（`README.md`）；`sessions/` 存以会话为单位的进度。标准见 `INDEX.md` §2。
> **本文件是设备层唯一权威**；旧专题文档中的设备结论以本文件为准。

---

## 1. 设备描述（机型唯一）

| 项 | 值 |
|---|---|
| 机型 | Lenovo Legion Tab **Y700 四代** = **TB322FC** = 代号 **elden** = `elden_prc_wifi`（国行 WiFi） |
| SoC | **SM8750(P)**（骁龙 8 至尊版 / 8 Elite），8 核 max 4.09 GHz；GPU **Adreno 830**（freedreno `gen80000`） |
| 屏 | LCD 1904×3040，双 DSI bonded + CPHY + DSC，CSOT PP8807HB1-1，Novatek **NT36536**（165 Hz 已默认） |
| 音频 | AudioReach（LPASS/q6apm）+ 双 **AW88461** 功放 + **AW86937** 双触觉 |
| 无线 | WCN7861 "PEACH"：WiFi 走 `ath12k`（pci 17cb:110e）/ BT 走 `hci_qca` |
| 相机 | 后 **Samsung S5KJNS** 50 MP（csiphy3）/ 前 **GC08A8** 8 MP（csiphy4）/ VCM GT9764 / PMIC WL2868C |
| 传感器 | 7 颗挂在 **SLPI/SSC 传感器核**私有 I2C（LSM6DSO、MMC56x3x、LPS22DF、SHT4x、SX932x、BU52053NVX、TMD3765）→ **AP 侧无引脚连** |
| 存储 | UFS 4.0（LUN0=`/dev/sda`，扇区 **4096 B**）+ TF 卡（`sdhci-msm`，有写丢失 bug） |
| Hypervisor | **签名 Gunyah 占 EL2**（内核只到 EL1）→ mainline **无 KVM**（`hyp` 分区受 XBL 签名校验） |
| 原厂 build | `TB322FC_CN_OPEN_USER_Q00041.1_W_ZUXOS_1.5.10.259_ST_260611`（Android 16） |
| BL | 已解锁；`boot` 是 **chained AVB** 分区：自签必须 **AOSP testkey（sha1 `2597c218`）+ rollback `1738713600` + 3 条 prop**，缺任一被 ABL 拒 |
| 主机 | `5700g-x8664`（Ubuntu 26.04），交叉链 gcc-15 / avbtool / mkbootimg / dtc 齐；设备地址 USB-NCM `192.168.7.1` |

### 1.1 内核与软件基线
- ★**2026-10-25（f2fs 路线 A 真机落地：根 = `f2fs @linux18`）** —— `boot_b` 已换成 `f2fs-root` 镜像（内核 = vk152 那份 `b6a074ff…`、ramdisk = 仓库 `/init`、cmdline `elden_root=LABEL=linux18`，签名件 sha `257266ec…`，写后读回一致）。
  **盘布局（4 KiB 扇区）**：`linux17` ext4 **96.0 GiB**（73 277 435..98 443 258，**留作回退根**，实测 `fastboot boot` 可起）+ `linux18` f2fs **96.0 GiB**（98 443 259..123 609 082）+ 尾部余 1024 MiB；GPT 双表写后 `cmp` 读回一致。
  **起根实测**：`/init` 打印 `root fstype: f2fs` → `switching root to /dev/sda18`；模块 37、`version magic` 错误 0、`phoc=1`、`card0-DSI-1=connected`、背光 511、`crashed` 0、`df / = 96G 31%`、`qbootctl -m b` → `succ=1`；首启后离线 `fsck.f2fs -f` 全 `[Ok..]`。
  **数据一致性**：同盘复制 216 882 → 216 876 文件（差 6 = socket），`tar -d`（含 xattr/ACL）**零差异**，硬链接 133 组保留。
  **已知噪声（两侧一致，非迁移引入）**：`rmtfs` failed（缺 `/dev/qcom_rmtfs_mem1`）、`rtkit` 偶报 `crashed` 但进程存活。
  细节 `TASKS/sessions/2026-10-25-f2fs路线A落地.md`、坑 `PITFALLS #400–#405`。
- ★**2026-10-25（用户态固化 + 入口收敛 + f2fs 预备；全零写盘/仅 rootfs 文件级改动）** ——
  `boot_b` **当时 = `vk152`**（该时段未写槽；当晚已切 `f2fs-root`，见上条）；根当时 = `/dev/sda17` ext4 / 189 G、用 28 G。**三处变化**：
  ① **disk `/init` 350 行旧版 → 仓库版 444 行**（`sha256 24074be1…`；旧件 `/root/bak/20261025-entry-consolidation/init.disk-old`）
     ⇒ `camera-modules-load.sh` 生效（**模块 0 → 37~47**），openrc 模式判定与「/init 只做挂根+模块+lifeline+交棒」口径一致；
  ② **服务单一归属**：`/etc/local.d/{elden-bringup,elden-bootlog}.start` 改 no-op，运行期脚本改由 OpenRC 服务负责
     （`ath12k-retry / charge-watch / time-sync / net-up / net-selfheal / bt-alias / q28-boot-watchdog / elden-bootlog / pstore-catch`），
     定义唯一真源 = `packaging/elden-userland/services.tsv`（21 行，20 启用），双 init 可渲染（18+ systemd/openrc）；冷起实测每脚本 **1 实例**；
  ③ **GPT 与切根物料已备好、未写盘**：`backup/HA2EXB0E-16+512/gpt-20261025/{main0,backup0}.bin`（写前基线）、
     `out/boot-elden-vk162-fstype.img`（fstype 检测，零写盘已验）、`out/boot-elden-vk162-rescue.img`（纯 RAM 救援）、
     `out/boot-elden-f2fs-root.img`（`elden_root=LABEL=linux18`，未写槽）；手术脚本 `scripts/f2fs-migrate.sh` + `RUNBOOK-BRINGUP/f2fs-migration.md`。
  **槽基线**：`boot_b retry=6 succ=1 unbootable=0`（未因本轮动作递减）。报告 `reports/{userland-service-inventory,g0-fstype-zero-write,f2fs-host-bench,userland-service-consolidation}-20261025.md`。
- ★**2026-10-23 深夜（收尾会话）：设备态与三项设备侧收尾** —— `boot_b` 仍 = `vk152`（未再刷写）；`qbootctl -m b` successful；`card0-DSI-1=connected/enabled`；**背光 1024/4095**（自动亮度 `ambient-enabled` 已关，新增 OpenRC 服务 `backlight-floor` 把亮度钳在下限，见 `PITFALLS #372`）；Waydroid `Session/Container = RUNNING`、`Session user=xuqianhui1001(1000)`（真实桌面 phoc）。三项收尾：① **Q29 关闭** —— `vendor.img` 内 Mesa 与 `/root/wd/mesa` 11 个文件中 9 个逐字节相同、2 个仅 `.eh_frame/.plt/.got.plt`+build-id 不同（`.text/.rodata` 相同）⇒ **删掉 `config_nodes` 的 `waydroid-mesa-swap` 段全部 bind**（备份 `config_nodes.bak-q29-20261023-221233`），容器实测 `GLES: freedreno, Adreno (TM) 830, Mesa 26.1.8`；② **容器相机恢复** —— 根因是 `/dev/video100` 的 bind **从未进持久 `config_nodes`**（10-19 那次是会话内手工绑的）⇒ 已写入（`optional`），`Number of camera devices` 回到 **1**；③ `cam-loopback.sh start` 的互斥判据命中内核线程 `[disp_snapshot]` 致永久拒启动，已修（`PITFALLS #373`）。报告 `reports/closeout-q29-backlight-camera-20261023.md`。
- ★**2026-10-23 晚：在机 `boot_b` 已换成 `vk152`**（= `vk151` 的全部功能 + Q11 `kexec_dbg=`/`/sys/kernel/kexec_diag` 旋钮；config/DTB/ramdisk(`out/rootfs-vk127.cpio.gz`)/cmdline 与 vk151 逐字相同）。签名件 `bootslot-b/boot_b-vk152.img` `sha256 d8e8074b…`，Linux 内 dd 写入后 **dd 读回逐字一致**；在机 `uname -r` = `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`，`qbootctl -m b` 已置 successful。上机核验：`card0-DSI-1=connected/enabled`、`DSI_PLL_lockfail=0`、`STORM=0`、mdss reset 失败 0、fastrpc/传感器正常。同日 a 槽往返（stock Android 取证）后已切回 b；**背光为 `aw99706-backlight`，注意 `brightness` 可能被自动亮度压到 ~4%（看起来像黑屏）**。见 `TASKS/sessions/2026-10-23-vk152日用载具与kexec复跑.md`、`reports/q28-dpu-intf-next-20261023.md`。
- ★**2026-10-22 深夜：在机 `boot_b` 已更新 = `vk145-q28daily`**（签名件 96 MiB，`sha256 53a546312d61…`，**写后读回一致**；写入走 `scripts/flash-b.sh` 的 ssh 流式通道）。组成 = `m1-73@24223e44ad80`（与 vk127 同源）+ **0154**（dispcc probe 断言/释放 `MDSS_CORE|CORE_INT2|RSCC` 三个 BCR，仅 `lenovo,elden`）+ **0155**（DSI PHY `DIGTOP_PWRDN_B` 随 PLL bias 置/清）+ **软件闩锁修**（`dsi_bonded_cmd_failed` 在 `bridge_power_on()` 成功路径清零；`power_off`/`post_disable` 不再因闩锁跳过 IRQ/power 清理）+ **`link_configured` 误清修**（仅 `!power_on` 时清）。UTS 与 vk127 **逐字相同**（`7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`，复用机内模块树），身份区分靠 manifest 的 `kernel_payload_sha256=e24c7d50…`。**冷起验收 8/8 GOOD**（同日 daily 对照 0/4，Fisher 双侧 p=0.002；`reports/q28-disp-init-ab-20261022.md` §10）；重启后自启实测 `card0-DSI-1=connected`、`phoc/phosh` 在、`device_link_fail=0`。**回退**：覆盖前分区内容 = `bootslot-b/boot_b-vk129.img`（`sha256 736bfe87…`，逐字节核对一致）、更早的 `bootslot-b/boot_b-vk127.img`。
- ★**2026-10-23：在机 `boot_b` = `vk147`**（用户持久化写入；`uname -v` = `#13 SMP PREEMPT Thu Oct 22 23:22:24 CST 2026`）。组成 = `m1-73@24223e44ad80` + **0154** + **kexec mask=1 旋钮**（`/sys/kernel/kexec_diag`，`kernel/kexec_core.c` + `kernel/reboot.c`，来自 `patches/kernel-history/elden_vk53-hw/0019+0020`）。config = **SSOT `patches/config-vk127-working-20261018`**（`CONFIG_SUSPEND` **未设**），`pahole` 核对 `struct device.of_node` @ **624**，与机内 `-abi-nosuspend` 模块树一致。UTS 仍钉 `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`（复用模块树）。镜像 `out/boot-elden-vk147.img`（`sha256 cc60adf5…`）。**实测**：面板 `card0-DSI-1=connected`、`phoc` 在、刷屏 0、`/dev/fastrpc-{adsp,cdsp,cdsp-secure}` 全在、`HasAccelerometer/AmbientLight/Proximity=true`、`monitor-sensor` 出实测值、相机 17 video nodes。**作废留证**：`out/boot-elden-vk146-BADSUSPEND.img`（用漂移的 `CONFIG_SUSPEND=y` config 编的，上机「背光亮一下即掉电」，vk128/vk129 同型）。
- ★**2026-10-23：fastrpc 刷屏根因已修（模块树 ABI）** —— `/lib/modules/<UTS>` 符号链接曾指向 `…-abi-suspend`（`CONFIG_SUSPEND=y` 编的，`struct device.of_node` @680），而在机内核 `SUSPEND=n`（@624）；**vermagic 只比 UTS 字符串拦不住**。修法 = 链接切回 `…-abi-nosuspend` + `depmod` + 重载 fastrpc；错树改名 `…-abi-suspend-DO-NOT-LINK` 防复发。另加 udev 规则 `/etc/udev/rules.d/82-fastrpc-perm.rules`（设备默认 `root:root 0600`，而 `hexagonrpcd` 以 `fastrpc` 用户跑）。门禁 = `scripts/check-abi-config.sh` + `assert-kernel-sane.sh` §1b + `check-doctor` §5f。详见 `reports/fastrpc-flood-rootcause-20261022.md`、`PITFALLS #367`。
- ✅**2026-10-23：SSH 免密已恢复** —— 当日曾出现 `root@192.168.7.1` 的 `id_rsa` 被拒（`/root/.ssh/authorized_keys` 里只剩一把 544 字节旧公钥，主机这把是 716 字节）；用 root 密码通道（pty 注入脚本 `/tmp/sshpass.py`，非持久，口令在环境变量 `SSHPASS`）追加本机 `~/.ssh/id_rsa.pub` 后 `ssh -o BatchMode=yes root@192.168.7.1 'id'` = `uid=0`。**全部自动化（`n5b-*`/`trial.sh`/`kexec-*`）依赖此通道**，再出现 `Permission denied (publickey,password)` 先查这一条。
- 内核树：`linux -> geekidos-linux`（GEEKiDoS/linux `v7.2-elden`，**Linux 7.2.0**）+ 本地补丁 `patches/0001–0011`；模块化片段已应用（`patches/config-vk50-modular`）。
- 配置快照：`patches/config-vk50-modular`（netd/XFRM + camera + thermal + audio 全合 + 模块化）；`config-vk40-bringup` 为历史基线。
- ⚠️MIGRATION-LOST(2026-10-17：`out/*.img` 未随迁 ⇒ 本地已无该镜像；在机 b 槽与 `backup/HA2EXB0E-16+512/` 历史 boot_b 仍在；见 `RESOURCES/README.md` §3.5) ★**2026-10-15 在机 boot_b = `out/boot-elden-m1-baseline-f3.img`**（sha `40e13f8a…`；签名后写入 sha `78a2beb1…`，写后读回一致）= **M1-7.3 功能基线 `m1-73/baseline` tip `ad5f03c43c`**（7.3-rc7 + DSI `PLL_SYSTEM_MUXES` 1 行 + ath12k MHI 超时 3 s + **F3 `-EPROBE_DEFER` WCN 自愈**）`Image.gz` `b5b1e17b…` + 73j ramdisk `4d4834e6…` + 树 DTB `c8018843…`；刷写 = `scripts/flash-b.sh`。**冷起（SysRq-b 后自启 boot_b，非 RAM 镜像）实测**：`Run /init` **7.667 s**；WCN **`-EPROBE_DEFER` 重探 3 于 11.767 s `chip_id 0x2` 成功**（用户态 `ath12k-retry` 21.8 s 醒来时已是 `phy0 up` ⇒ 未被用到）；`wlan0` **17.52 s 关联 ustc-guest**；**L1=0/L2=0 + `dsi_isr`=41 + `card0-DSI-1` connected/enabled + phoc/phosh ⇒ 面板 GOOD**（**用户 2026-10-15 目视确认：屏幕点亮、可触摸操作**，符合 `PITFALLS #251` 的目视判据）；`SLOT _b is marked successful`（OpenRC `qbootctl` 服务自动置位）。外设抽检：触屏 `NVTCapacitiveTouchScreen`(event4)、`hci0 UP RUNNING`、声卡 `sm8750`、`/dev/fastrpc-adsp`、电池、DP-1 disconnected（未插）全在。cmdline 仍 `elden_nocamera=1`（熄屏安全）。回退资产 = `backup/HA2EXB0E-16+512/boot_b-before-vk94-20261011.img`（vk94）等历史 boot_b 镜像。✅**该镜像已于 2026-10-17 抢救到主机**：`backup/HA2EXB0E-16+512/boot_b-m1-baseline-f3-20261017.img`（100 663 296 B，sha256 `78a2beb1e0f4…` 双端一致）+ 模块树 1497 `.ko`（tar 流 sha `ee3f059b…`）+ 207 项配置脚本，均在 `backup/HA2EXB0E-16+512/device-rescue-20261017/`。仍须记住回退纪律：**本机 ABL 无 `fastboot fetch`（`PITFALLS` #290），覆盖前用设备侧 `dd`**。见 `reports/device-rescue-and-q28-m1-badboot-20261017.md`。
- **（前身，2026-10-11）在机基线 = `vk94` boot_b**（2026-10-11 刷入；`uname` 仍 = `7.2.0-debug-vk64-gd02658e63cf6`）。**🆕 2026-10-12：候选替换镜像 `out/boot-elden-vk113-dailyid.img`（sha `54717ba7…`）= vk94 逐字节复刻 + 内核以 3 位构建身份重编（`#121`，治法见 `PITFALLS #195`/报告 `reports/q28-vk113-20261012.md`）；构建侧已复验，**2026-10-12 晚上机实测 = GOOD/L1FAIL 各一（3 位身份仍有残余坏发）⇒ 不写盘，`boot_b` 仍 = vk94**；当晚 7 发 4 坏/7（4 臂同率，上游 round 修复臂 `vk114` 亦坏），运行期重绑 DSI host 会拆掉 DRM（`PITFALLS #223/#224`）⇒ 显示恢复只能整机复位（关机重开）（`reports/q28-identity-retest-20261012.md`、`PITFALLS #217`）**；**🆕 10-12 深夜：新日常候选 = `out/boot-elden-vk124-merged.img`（上游回移 14 文件合入 `clean/base` `5b169d541`，同 UTS 身份 `#121`），冷起 **3/3 L1FAIL**（未过新验收口径「1 次 GOOD 冷起」），`boot_b` 仍 = `vk94`；**坏发兜底 = 设备侧 `q28-boot-watchdog`**（75 s 自动正常重启，可用性 ~50%→~75%；任何 Q28/Q24 实验前先 `q28-watchdog off`，见 `reports/q28-watchdog-20261012.md`）**——**= vk64 内核 + ADSP fastrpc `qcom,non-secure-domain` DTB（传感器恢复；`PITFALLS #186`）**。⚠️ 此前 vk64 v2 **缺该 DT 行** ⇒ `/dev/fastrpc-adsp` 缺失、SSC 传感器全废（G1-34 静默回退）；回退镜像 `backup/HA2EXB0E-16+512/boot_b-before-vk94-20261011.img`（sha `6b9e1746…`）。以下为 vk64 v2 历史记录：b 槽 boot_b 曾为 `vk64` v2（2026-10-08 烧录 + 启动健康 + `qbootctl -m b` mark successful）：**vk47clean 同款 config**（从镜像内 extract-ikconfig 恢复，与 vk63 内核 diff 0；v1 曾用 `.config.old` 构建 → 残缺不起内核已作废）+ **配套模块目录 `/lib/modules/7.2.0-debug-vk64-gd02658e63cf6`**（已部署持久盘，1610 个 .ko；vk63 的 uname=vk47clean 是巧合，vk64 需自己的目录）+ **H2 DTB**（cambist 单挂 `RPMHPD_MX`） + **panel nt36536 init retry on -110**（commit `d02658e63` = be79b256d H2 + retry） + 完整 ramdisk + 修好的 `/init` + split CDSP；cmdline 带 `elden_nocamera=1` 且 `/etc/modules-load.d/camera.conf` 置空 ⇒ **熄屏安全，DP 可用**（相机按需）。上机验证：面板 init 通过、card0/DSI-1/DP-1 全出、phoc/phosh 正常、fsa4480+全模块可加载、cam 抓帧成功。**已知问题：Q28 未根治——retry 补丁生效但不够（attempt1 `-110` → attempt2 `-5` ⇒ DSI host 首败后楔死，面板级 reset 救不回；真修 = msm_dsi 级复位，未立项）**；Q24 熄屏 H2 未根治（2026-10-08 扫测 3 轮 2 掉电）；**🆕 2026-10-11 封盘**：最小触发已重定为 `{camcc,cambist}` **配对** + 真实熄屏（历史「单模块」否证），三路变体（E4a/FIX-2/FIX-3）全败 ⇒ 运营默认口径 = 相机 ⇄ 熄屏互斥（**★2026-10-19 更正：不是绝对的** —— vk127/7.3 线完整相机栈在位 + 真实熄屏 41 发存活，致死仅见 vk64/7.2 血统，suspend 已能力级排除 ⇒ 「在位即常态掉电」作废，待 N5b 扩样定性；见 `TASKS` §1 G1-33 尾部与 `reports/q24-suspend-hypothesis-excluded-20261019.md`）；详见 `../TASKS/README.md` §5 Q24 / `reports/q24-repro-20261011.md`。**🆕 2026-10-11 稳定化（已应用 U2）**：`/etc/init.d/qbootctl` 原**不在任何 runlevel** ⇒ 每次启动不置 A/B 槽 `BOOT_SUCCESSFUL` ⇒ ABL 每启动一次 `tries_remaining` 减 1 ⇒ **~7 次重启后卡 fastboot**（`PITFALLS #181`）。已用 `scripts/fix-ab-mark-successful.sh` 修复（runlevel default + 显式 `start()`；实测 `succ=0→1` 且 retry 不动；当前 `boot_b retry=7 succ=1 unbootable=0`）。**新装/恢复 rootfs 后必须重跑该脚本。** **🆕 2026-10-12（Q24 重开）**：Q24 取证/进度见 `reports/q24-{ctl,stageA,s123,cseries,h1-dtarm,h1-result,mech,noc,r9}-20261012.md`。**★口径更正（第 8–9 轮，下午）**：**不需要物理 POR**——Q24 致死 = **SoC 级复位**，USB 掉线后约 30 s **自动重启回本 boot_b**（当日 5/5，`PITFALLS #209`）⇒ **首选台架 = 日常 boot_b 自身**（`SKIP_BOOT=1` 复用活台架）；`reboot2 bootloader` 暖复位粘坏态（`#166`）仍成立，干净无相机台架 `out/boot-elden-lv64-nocam.img` 仅在需要 RAM 镜像时才用，且**其「必须冷路径」仅对该路线成立**。**新增台架纪律（`PITFALLS #208`）**：① **日常 boot_b 本身即可当 Q24 复现台架**（`{camcc,cambist}` → 熄屏存活 → 唤醒致死，4/4；无需 RAM 镜像、无需 POR）；② 判活窗口 **≥60 s**（15 s 读数「活」后数十秒仍可能死）；③ trace 前先清 `events/*/enable`（否则 `power/cpu_idle` 产生 10⁶ 行噪声淹没有效帧）并先 `pkill -f 'trace_pi[p]e'` 清陈旧读者（否则 EBUSY 抓空文件）；④ `fastboot` 客户端不得接 `head`/`grep -q`（SIGPIPE 会卡死 gadget，`PITFALLS #199`）；⑤ **不要在设备上主动 `reboot` 取「正常重启」对照**（`reboot -f` 冷起会落在 Q28 STORM，设备约 11 min 不可达，`PITFALLS #215`），取复位对照直接用 Q24 致死本身；⑥ 跑测试**必须持续读 `/dev/ttyACM0`**，`kill` serial-logger 后要确认无孤儿 `cat` 占口（`PITFALLS #214`）。
  **设备侧注意**：持久根 `/lib/modules/<vk64KV>/drivers/clk/qcom/cambistmclkcc-sm8750.ko` 必须是**原版**（md5 `88a45177…`，备份 `/root/q24bak/`）——换入实验版会让任何自动加载相机的启动挂死（`PITFALLS #177`）。回退资产：`out/boot-elden-vk63.img`（sha `2f34e887…`）、`out/boot-elden-vk62.img`（H1）、`out/boot_b-before-cdsp-20261007.img`（sha `2b4aa291…`）、`bootslot-b/boot_b-clean.img`。**不用 min initramfs slim**（无固件→驱动全废，`PITFALLS` #113）。kexec 已定论不可用（见 `../TASKS/README.md` §4）。提交号：Linux 侧提交的唯一入口 = `../TASKS/README.md` §7。
- ★**2026-10-15 晚：M1-7.3 模块树已补齐并部署**（此前持久根 `/lib/modules/7.3.0-rc7-debug-ged6f232d10e3` **不存在** ⇒ 该内核下**所有 `=m` 驱动不可加载**、`cam-mode.sh`/`camera-modules-load.sh` 静默失效，`PITFALLS #282–#284`）。现状态：`/lib/modules/7.3.0-rc7-debug-ged6f232d10e3/` = **1497 个 `.ko`**（`depmod -a` 已跑），**vermagic 与 `uname -r` 逐字相等**；来源 tarball `out/m1-73-modules-7.3.0-rc7-debug-ged6f232d10e3.tar.gz`（20 MB，sha256 `c0702e56c5f5…`）；树侧 config 与设备 `/proc/config.gz` **diff=0**。**实测生效**：相机栈可加载（`/dev/media0` + 17 `/dev/video*`，双摄绑定）——**但出流仍失败**（`STREAMON` EINVAL/EPIPE，详见 `../TASKS/README.md` C5 与 `reports/m1-73-modules-p0-20261015.md`）。**构建侧两条硬规则**：① 该树改配置/编译**一律带 `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`**（裸 `make` 按 x86 求值会静默删 `ARCH_QCOM`）；② **必须 `export LOCALVERSION=`**，否则 git worktree 会让 vermagic 多一个 `+` ⇒ `depmod` 全绿但**上机必被拒**。
- ★**2026-10-18：冷起无桌面 = `greetd` 崩（已修）** —— 面板/DRM 正常（`card0-DSI-1=connected`）但 `loginctl` 无会话、`rc-status` 里 `greetd [crashed]`。修法：initd 补 `after seatd elogind` + `supervise-daemon` 守护（源文件入库 `rootfs/persistent-overlay/etc-initd-greetd`，设备备份 `/etc/init.d/greetd.bak-20261018`）。判据链与手工救场见 `PITFALLS #318`，报告 `reports/camera-linux-vk127-20261018.md` §2。
- ★**2026-10-19：WiFi 候选榜塔成「只剩已连接项」已修** —— 不是 ath12k 问题；NM 1.52 连通态**不做**周期扫描且 `bgscan` 写死 `simple:30:-70:86400`（连接级属性不被读取）⇒ supplicant BSS 缓存过期被清 ⇒ AP 对象被删。根因链与实测见 `PITFALLS §52 #354–#356`、`reports/wifi-scan-stale-20261019.md`、`TASKS` G1-36。**设备侧服务**：`wifi-scan-refresh`（OpenRC `default`，源文件 `scripts/wifi-scan-refresh.sh` + `rootfs/persistent-overlay/etc-initd-wifi-scan-refresh`），参数 `/etc/conf.d/wifi-scan-refresh` 的 `WIFI_SCAN_INTERVAL=150`（**必须 <180 s**，否则仍会被 supplicant 的 `bss_expiration_age` 清掉）；未连接时自动跳过（NM 自扫 ≤120 s）。判活：`/usr/local/sbin/wifi-scan-refresh.sh --check` + `grep -c 'requested scan' /var/log/wifi-scan-refresh.log`。
- ★**2026-10-17 晚：重放镜像 `vk127` 已通过冷起验收（仍未写盘）** —— `out/boot-elden-vk127.img`（sha `7515f6a4…`，85 585 920 B）=
  **7.3-rc7 + 下游 `vk64` 树 payload（cambist 回上游 parity）+ M1 DSI 1 行**，config = `config-daily-c1` + C1 片段；
  真 POR 冷起 **3/3 GOOD**（`l1=0`、`dsi_isr=41`、目视有桌面）+ 功能抽查全绿（WiFi/音频/fastrpc-adsp/SensorProxy）。
  **★2026-10-18 上午：`boot_b` 已刷写 = `vk127`（读回校验）** —— 签名件 `bootslot-b/boot_b.img`（100 663 296 B，`sha256 83d4e08add88abd2…`）与设备 `dd /dev/disk/by-partlabel/boot_b` 逐字节一致；在机 `uname -r` = `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`。
  ⚠️ **换机后 `tools/avbtool.py` 与 `bootslot-b/avb.key` 已丢失并重建**：新 AVB 公钥 `sha1 1e54e86ef19fad73…`（旧 `fc1e3b33…` 作废），`vbmeta_b` chain descriptor 已同步重签（`scripts/sign-boot-b.sh`；`PITFALLS #313`）。本轮冷起 Q28 **7 发坏 / 第 8 发 GOOD**。
  模块树 `/lib/modules/7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty/`（1497 `.ko`）已部署在持久根。
  ⚠️ **换新 UTS 内核必须先部署模块树再判显示**，否则 `lsmod` 空 ⇒ DP defer ⇒ 无 `card0`（`PITFALLS #293`）。配方 `reports/replay-2026-10-17-m1-73-vk127.md`。
- **2026-10-10 离线快照（Q28 调试轮收尾；本轮整理时 adb/fastboot 均无设备在场）**：boot_b **持久直启仍 = `vk64`（未动）**；本轮 vk74/vk84 仅 `fastboot boot` RAM 取证，**永不作 boot_b**。Q28 根因/双模式/判据/下一步见 `reports/q28-DOSSIER.md`、`../TASKS/README.md` §5 Q28。
- **主机串口 logger** = `scripts/serial-logger.sh`（pid 文件 `/tmp/q28_serial_logger.pid`，常驻；主机重启需重跑）。**判 Q28 显示不能只靠串口 logger**（重连会漏 0–20 s，盖住 NOCARD 的 0.86 s 现场），须 SSH 读全 dmesg + 查 `card0`。
- ★**2026-10-17 晚：相机 AE 正解 = libcamera 侧 sensor helper（用户态，与内核 UTS 无关）**：设备 `/usr/lib/libcamera/ipa/ipa_soft_simple.so` 已换成自编版（含 `s5kjns`/`gc08a8` 的增益模型 + 黑电平 4096；主机交叉编译，配方 `reports/camera-ae-helper-20261017.md` §2），原包备份 `/root/ipa-bak-20261017/`。**相机驱动 `.ko` 保持原版**（增益码语义未改，`/root/cam-ko-bak-20261017/` 里的补丁版只属 vk127 目录、未使用）。相机栈仍需 `CAM_FORCE=1 camera-modules-load.sh` 手动加载（cmdline `elden_nocamera=1`）。
- `CONFIG_LOCALVERSION` 一变，相机 20 个 `.ko` 必须整套重编（vermagic 耦合）；vk50 起模块化后驱动可单独重编。
- **容器（Waydroid）侧在机资产（2026-10-13，TASKS C10 三期）**：`/var/lib/waydroid/images/vendor.img` 已**固化**自编 AIDL V2 vibrator HAL（`/vendor/bin/hw/android.hardware.vibrator-service.elden` + rc + vintf fragment）与静态 RRO `EldenVibrationOverlay`（`/vendor/overlay`，把 Settings 振动强度档位 1→3）；运行期只剩宿主 daemon `elden-hapticd`（OpenRC + `/etc/conf.d`）与一条 `sys/class/leds` 桥挂载。**回退镜像** `/var/lib/waydroid/images/vendor.img.bak-elden-haptics-20261013-115055`；复现 `scripts/waydroid-haptics-bake-patch.py` + `bake-vendor.sh`；细节 `reports/waydroid-haptics-20261013.md`、踩坑 `PITFALLS #232–#246`。

### 1.2 固件清单与通路（"正常驱动原厂全部固件"的分解）

| 固件 | 来源分区 | 本地资产 | 主线通路 | 状态 |
|---|---|---|---|---|
| ADSP `adsp.mdt`+`adsp_dtb` | LUN4 `modem_a` | `backup/fw/modem/` | `qcom_q6v5_pas`；DT 期望 `/lib/firmware/qcom/sm8750/adsp.mdt` | ✅ 起（音频 graph 已通） |
| AudioReach **tplg** | vendor 自研 | 自编 `Lenovo-Y700-Gen4-tplg.bin` | ASoC `q6apm` + `patches/0011` | ✅ 出声+录音（G1-4） |
| CDSP `cdsp.mdt`+seg / `cdsp_dtb.mdt`+seg | `modem_a` | `backup/fw/modem/image/`（**split**；`cdsp_dtb.mbn` 单文件被 TZ 拒） | `qcom_q6v5_pas` + DTS `firmware-name`（split）；固件须在 **initramfs** | ✅ 起（`remoteproc1 running`，2026-10-07，G1-11） |
| WiFi Peach（`amss.bin`/`bdwlan`/BDF） | `modem_a/peach` | `backup/fw/modem/image/peach/`（两套：在用 `amss20.bin` sha `848a2f04…`；**非-20 `amss.bin` 不兼容**：MHI POWER_ON `-110`） | `ath12k` + MHI 重试补丁 | ✅（**Q26 已关闭**：2026-10-10 用户实机确认关联即可用，见 `TASKS` §5 Q26） |
| BT（`brhbtfw20.tlv`/`brhbtnv20.bin`） | `bluetooth_a` | `backup/fw/bluetooth/` | `hci_qca` + IBS 补丁 | ✅ 配对 + TWS 实听通过（用户 2026-10-06 实测） |
| GPU gen80000 `zap/sqe/gmu/aqe` | vendor | `backup/fw/gen80000_*` | `msm` + freedreno | ✅ |
| 触屏 `novatek_ts_csot_3k_fw.bin` | vendor | `backup/fw/vendor/` | `nt36536` | ✅ |
| 触觉 FW / 功放 ACF | vendor | 改名喂入 `awinic/y700-gen4-*.bin` | `aw86927` / `aw88461` | ✅ |
| SLPI 传感器固件 + QMI-SNS | `modem_a` | 仅 `.json` 配置 | **主线无栈 + AP 无私有 I2C 总线**（需 QRTR + `qcom_smgr`） | ⛔ 不阻塞主线：G2 走容器软传感器；Linux 原生侧为可选自研（`TASKS` G1-34，未开工） |
| Modem / SDSP / SPU / TEE / Gunyah hyp | 各分区 | 有 blob | 主线无客户端 | ➖ 不立项 |

### 1.3 驱动面与投入边界（数字：厂商 529 compatible / 297 `.ko`；主线 SM8750 覆盖 146 compatible）

> **本节只定“硬件面归类 + 要不要做”；具体功能状态（✅/🟡/⬜）一律看 `../TASKS/README.md` §0/§1，本表不维护状态。**

| 面 | 项 | 性质 / 边界 |
|---|---|---|
| **主线在跑** | CPU/GPU/显示/USB/PCIe/UFS/WiFi/BT/触屏/触觉/背光/充电旁路/温控分级/音频/相机驱动栈/CDSP/DP | 驱动均在树，无缺失 |
| **在树但需调** | TF 卡写稳定性；面板 init 竞态；熄屏×相机共存 | bug / DT 电源域，非缺驱动（G1-6/Q28/Q24） |
| **低优先增强** | 温控 OEM 层（`lenovo,sys-temp`/BCL/QMI cooling）；SLPI 传感器原生栈（G1-34） | 前者可用通用框架近似；后者需 QRTR+`qcom_smgr` 栈 |
| **不成立** | ~~NFC~~ | **本机无 NFC 硬件**（vendor 无 nfc feature/HAL/固件，`PITFALLS` #108） |
| **✗ 不投入** | TEE/SPU/hw-fence/mem-buf、FM RTC6226、ST54 SE、Gunyah/PMIH010x | 私有或无源码 |

---

## 2. 设备状态

### 2.1 设备等价原则（★）
1. **身份 = (SN, hwboardid, 容量)**，"新/旧"只是到货顺序，**不是角色**。
2. **物理等价** ⇒ 同一 boot 镜像 / 内核 / rootfs 归档 / GPT 生成器 / 验证脚本对任一单元都成立；
   唯一实质差异 = **容量 → GPT 数值**，故脚本一律运行时读实际 GPT。
3. **任务按单元当前状态分派**（§2.3），做完可回收复用。禁止把任务永久绑定到某台机器或把资产命名成"某机专用"。

### 2.2 单元台账（唯一登记处；刷机状态变化当场更新）

| ID | SN | hwboardid | 内存/UFS | a 槽 | b 槽 | LUN0 GPT | 可派任务（由状态决定） |
|---|---|---|---|---|---|---|---|
| **U1** | `HA2ABH62`（主线 gadget `HA2CB1KY`） | `TB322FC_SM8750P_12+256` | 12 G / 234 GiB | stock 259 **已 root**（SUSFS 6.6.118+KSU+ZN/Shamiko/PIF） | 原厂已刷回 | **已逆手术**：`linux17` 删、`/data` 回 211 GiB | Android 侧一切（AVF 勘察、固件对照、过环境）；mainline 需重做手术 |
| **U2** | `HA2EXB0E` | `SM8750P_16+512_13` | 16 G / ~476 GiB | **BL 已解锁** · stock **259**（Android 16；Widevine **L1**）。**进 Android = `fastboot --set-active=a` + `fastboot reboot`（无需刷 dtbo，实测 2026-10-11，HANDOFF §20 再次成立）**；未 root、无 Google 账号。C0 基线已采：`backup/HA2EXB0E-16+512/c0-baseline/` | **mainline 持久直启**（`/`=`/dev/sda17`，Phosh 自启；当前 boot_b=**`m1-baseline-f3`**（2026-10-15 刷入：M1-7.3 功能基线 + WCN `-EPROBE_DEFER` 自愈；冷起 GOOD——`Run /init` 7.667 s、WCN 11.77 s、`wlan0` 17.52 s、**L1=0/L2=0 面板 GOOD**、槽位 marked successful。前身（2026-10-11 刷入）：= vk64 内核 + ADSP fastrpc `qcom,non-secure-domain` DTB，**传感器恢复**，`PITFALLS #186`；前身 vk64 v2 2026-10-08 烧录+mark successful：vk47clean 同款 config + 配套模块目录 + H2 DTB + panel retry + split CDSP；cmdline `elden_nocamera=1` 不自动加载相机）；`recovery_b` 已刷 TWRP。**外设/驱动功能状态不在本表维护**，一律看 `../TASKS/README.md` §0/§1（当前未解：Q28 DSI host 楔死、Q24 熄屏×相机（权威 = `../TASKS/README.md` §0/§5）） | **已手术**：`linux17`=193.0 GiB（idx16）、`userdata`=256.7 GiB；双表 dump 在 `backup/HA2EXB0E-16+512/` | 当前在 **Linux**（b 槽持久直启，环境可 SSH）。基线回退：`out/boot_b-before-cdsp-20261007.img`、`bootslot-b/boot_b-clean.img` |

> **★ 熄屏→整机硬复位：未解（间歇性）**。根因已锁定为单模块 `cambistmclkcc-sm8750` × DT 电源域耦合（H1/D1/D2/H2 均未根治）；**无相机模块态安全**。设备侧规避（持久根现状，不得轻改）：cmdline `elden_nocamera=1` + `/etc/modules-load.d/camera.conf` 置空 + `idle-delay=0`。
> 状态/样本数以 `../TASKS/README.md` §5 Q24 为准；历史二分过程见 `archive/topics/G1-22-2026-10-05.md`、`REBOOT-5MIN-2026-10-05.md` §7.9。

> **口径纠正（2026-10-03）**：旧记录把 U2 现态写成「固件 1.1.11.073 / locked」，来自上轮 AI 未命中 7、8 月技能而留下的过时条目，**已作废**——以本表实机核验值为准（259 + unlocked）。

### 2.3 状态 → 可派任务（并行性来自状态不重合，不是机器身份）

| 前置状态 | 满足单元 | 可做 |
|---|---|---|
| mainline（b 槽直启 + 持久根） | **U2**（b 槽持久直启在跑；当前镜像版本看 §1.1） | U1 已逆手术，mainline 需重做手术 |
| stock Android + root | **U1** | 固件对照提取、过环境、AVF 资产复采（可选路线） |
| 原厂未动 + **BL locked** | （暂无） | 路 C（EDL 直写）不依赖解锁——管线 `scripts/build-locked-chain.sh` 保留作资产；**U2 已走完解锁，不再命中此行** |
| 原厂未动（**已解锁**，首次手术） | **U2** | GPT dump + 手术 + **RAM 零写盘验收**（`fastboot boot` 可用）；b 槽链已就绪 `bootslot-b-u2/` |
| 纯 RAM（不落盘） | 任一（刷 `bootslot-b/boot_b_vk40-ram.img`） | 采集/dump/验收，失败即回退 |

### 2.4 目标形态（★v3：不再要求两槽对称）

用户已定：**a 槽 Android 可以不要**——目标之一正是「**在没有 Android 的前提下**完成 ARM Linux 对安卓的兼容」。

```
最小目标形态（任一台单元）：
  b 槽 = mainline（自签 AVB 直启，~9s 进 Phosh）        ← G1/G2 的唯一工作系统
  Linux 分区 = 按项目体量定（见 §3），不再写死 65/128 GiB
  a 槽/Android 专属分区 = 可回收给 Linux（Phase B），或原样保留当回退保险
  回退保险 = EDL 全量包（~/下载/tb322fc/）+ qdl + backup/stock-259/（不再依赖槽位常驻）
```
- Phase A（现在）：只动 **b 槽 + GPT**，a 槽不动 → 零风险拿数据。
- Phase B（G1 稳定后）：回收 Android 专属分区（`super_a/b`、`boot_a`、`dtbo_a`、`recovery_a`、`metadata`、`misc`…）
  → 直接腾出**数十至上百 GiB** 给 Linux，这同时回答"容量不够"的问题。回收前必备 EDL 包与 stock 备份。

### 2.5 GPT 参数（容量档唯一体现；**禁止跨档复用 GPT 二进制**）

| 参数 | U1（234 GiB 实测） | U2（512 GiB 实测 2026-10-03） | 取法 |
|---|---|---|---|
| 扇区 | 4096 B | 4096 B | `blockdev --getss $BLK` |
| 主表 | LBA0..5 | LBA0..5 | `scripts/gpt-dump.sh` |
| `backup_lba` | `61390847` | **`123871231`**（现 dump；头 0x20 处 8B LE） | `gpt-dump.sh` 会打印 |
| `userdata` | 211.4 GiB | **256.7 GiB**（手术后；first=5972392 last=73277434） | `gpt-surgery-tb322fc.py list` |
| `linux17` | （已删） | **193.0 GiB**（idx16，first=73277435 last=123871226，`/dev/sda17`） | 同上 |
| free slots | 16–31（可加 16 个分区） | 17–31 | 同上 |
| boot/dtbo/vbmeta 大小 | 100663296 / 33554432 / 65536 | 同（同型号同布局） | `fastboot getvar partition-size:*` |
| 备份目录规范 | `backup/<SN>-<容量档>/`（**禁用 `new-tablet`**） | 同 | — |

---

## 3. ★ Linux 容量策略（按项目体量决定，不预设固定值）

### 3.1 体量估算表（设备侧占用组成；用于决定 `--linux-gib`）

| 组成 | 实测/估算 | 依据 |
|---|---|---|
| Linux rootfs（Alpine + 桌面 + Mesa + 工具） | 装开后 **15–20 GB**（归档规格见 `../RESOURCES/README.md` §2.2） | `env-pass/backup-20261002/linux17-rootfs-…tar.gz` |
| Waydroid（system+vendor+data+ART 缓存） | **30–50 GB**（压缩镜像 1.25 GB 在手） | `~/下载/` GAPPS `system.zip` 1.17 G + `vendor.zip` 77 M |
| x86 转译 chroot（Ubuntu base + Wine prefix） | **10–15 GB** | `pkgs-x86/`，PoC 已跑通 |
| guest VM 镜像（Debian / Android / Windows ARM） | **每镜像 20–60 GB** | AOSP AVF `custom_vm.md` 建议 ≥10 GB；Windows 更大 |
| 设备侧构建（内核树 + 模块 + ccache） | **25–40 GB** | 主机树 605 M + AOSP 树（体量见 `../RESOURCES/README.md` §2.3；AOSP 不在设备侧） |
| 基准/压测/日志（pstore、perf、worker 日志） | **5–15 GB** | `logs/agent-logs-2026-10-02/` 已 80 M/天 |
| **合计（全都要）** | **约 105–180 GB** | → 512 档可全放；256 档需取舍 |

### 3.2 决策规则（取代"65/128 GiB 固定值"）

1. **一次给足，不反复缩 `userdata`**：GPT 手术缩容不可逆（f2fs 需重建），二次扩容代价高 ⇒
   按 §3.1 的上界一次划足（**512 档建议 160–200 GiB；256 档建议 64–96 GiB**，若同时回收 Android 分区可再放大）。
2. **可再生的大对象不外置到设备**：内核/模块/镜像/归档留主机，用 `sshfs`/NFS/`scp` 按需取；TF 卡未修好前不指望它。
3. **回收 Android 分区是主要扩容手段**（§2.4 Phase B），不是二次缩 `userdata`。
4. 任何改动前先备份分区（**设备侧 `dd` / 官方线刷包解出 / EDL 读回——本机 ABL 无 `fastboot fetch`，`PITFALLS` #290**）+ GPT 双表 dump；改后**读回校验**（回读 md5/sha256，不看"传输完成"）。
