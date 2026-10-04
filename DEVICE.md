# 设备描述与设备状态（DEVICE）

> 领域层活文档之一；文档分三层（领域 / 元 / 证据），定义与 SSOT 见 `INDEX.md` §2。
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
- 内核树：`linux -> geekidos-linux`（GEEKiDoS/linux `v7.2-elden`，**Linux 7.2.0**）+ 本地补丁 `patches/0001–0011`。
- 配置快照：`patches/config-vk40-bringup`（netd/XFRM + camera + thermal + audio 全合）。
- 待上机新基线 **vk40**：`out/boot-elden-vk40.img`（持久根）/ `out/boot-elden-vk40-ram.img`（纯 RAM）+ 1484 个 `.ko`。
- **最后在机基线 vk39**（音频修复；U1 已逆手术回 stock，**当前无单元在机 mainline**）；`CONFIG_LOCALVERSION` 一变，相机 20 个 `.ko` 必须整套重编（vermagic 耦合）。

### 1.2 固件清单与通路（"正常驱动原厂全部固件"的分解）

| 固件 | 来源分区 | 本地资产 | 主线通路 | 状态 |
|---|---|---|---|---|
| ADSP `adsp.mdt`+`adsp_dtb` | LUN4 `modem_a` | `backup/fw/modem/` | `qcom_q6v5_pas`；DT 期望 `/lib/firmware/qcom/sm8750/adsp.mdt` | ✅ 起（音频 graph 已通） |
| AudioReach **tplg** | vendor 自研 | 自编 `Lenovo-Y700-Gen4-tplg.bin` | ASoC `q6apm` + `patches/0011` | 🟡 `GRAPH_START status=0`，**待听声** |
| CDSP `cdsp.mbn` | `modem_a` | `backup/fw/modem/` | DT `status=disabled` | ➖ 未启用（G1 加分项） |
| WiFi Peach（`amss.bin`/`bdwlan`/BDF） | `modem_a/peach` | `backup/fw/modem/peach/` | `ath12k` + MHI 重试补丁 | ✅ |
| BT（`brhbtfw20.tlv`/`brhbtnv20.bin`） | `bluetooth_a` | `backup/fw/bluetooth/` | `hci_qca` + IBS 补丁 | ✅ 起（配对待收口） |
| GPU gen80000 `zap/sqe/gmu/aqe` | vendor | `backup/fw/gen80000_*` | `msm` + freedreno | ✅ |
| 触屏 `novatek_ts_csot_3k_fw.bin` | vendor | `backup/fw/vendor/` | `nt36536` | ✅ |
| 触觉 FW / 功放 ACF | vendor | 改名喂入 `awinic/y700-gen4-*.bin` | `aw86927` / `aw88461` | ✅ |
| SLPI 传感器固件 + QMI-SNS | `modem_a` | 仅 `.json` 配置 | **主线无栈 + AP 无总线** | ⛔ 架构性放弃（G2 用软传感器补） |
| Modem / SDSP / SPU / TEE / Gunyah hyp | 各分区 | 有 blob | 主线无客户端 | ➖ 不立项 |

### 1.3 驱动矩阵（数字：厂商 529 compatible / 297 `.ko`；主线 SM8750 覆盖 146 compatible）

| 级别 | 项 | 性质 |
|---|---|---|
| **已通** | CPU/GPU/显示/USB/PCIe/UFS/WiFi/BT/触屏/触觉/背光/充电旁路/相机驱动栈/温控分级 | — |
| **P0** | 相机出流（camss + s5kjns + gc08a8 + wl2868c + flash） | 只差 config/部署 |
| **P1** | 音频可听+麦克风；TF 卡写稳定性；DP 输出（驱动在树被 `disabled`，缺 ADSP altmode/UCSI） | bug / bring-up |
| **P2** | NFC（主线 `st21nfca` 在，改 compatible）、BT 配对收口 | 小 |
| **P3** | 温控 OEM 增强（`lenovo,sys-temp`/BCL/QMI cooling） | 可用通用框架近似 |
| **✗ 不投入** | SLPI 7 传感器、TEE/SPU/hw-fence/mem-buf、FM RTC6226、ST54 SE、Gunyah/PMIH010x | 架构性/无源码 |

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
| **U2** | `HA2EXB0E` | `SM8750P_16+512_13` | 16 G / ~476 GiB | **BL 已解锁** · a 槽 stock **259** · b 槽 **mainline `vk47`（audio+thermal+WCD939x采集）持久直启**（`/`=`/dev/sda17`，Phosh 自启；**Linux→fastboot 已打通** `eldroid-bootctl reboot bootloader`）——**音频播放 + 桌面 PipeWire 扬声器 sink** ✅（G1-4，tplg SD1 + UCM2）、**温控四级 trip** ✅、**WCD939x 编解码器已枚举**（RX/TX bound，声卡注册、播放不受影响）、**但 WCD 采集 `arecord`=I/O error（未打通）**；已去 VA DMIC（硬件伪）；G1-22/G1-23 增量已重落、**桌面关机/重启已修**（`PITFALLS` #89）；**「熄屏→重启」**未解；`recovery_b` 已刷 TWRP | 原厂未动 | **已手术**：`linux17`=193.0 GiB（idx16）、`userdata`=256.7 GiB；双表 dump 在 `backup/HA2EXB0E-16+512/` | 当前在 **Linux**（b 槽持久直启，环境可 SSH）。基线回退：`bootslot-b/boot_b-vk34recon.img` |

> **★ 未解故障（2026-10-03）**：桌面空闲**熄屏（DPMS blank）→ 整机重启**（用户描述“直接关机并重启”）。
> 串口证据：重启前 `ucsi_glink … PPM init failed`，**无 kernel panic 打印**。
> `CONFIG_SUSPEND=n`（无 `mem_sleep`）；规避=**禁止空闲熄屏**（`idle-delay=0` 或 caffeine 常开），
> 早期版本可能正是靠这个“绕开”（`PITFALLS` §64–66）。详见 `GAPS` Q21、复盘 `archive/topics/复盘-2026-10-03-持久化与睡眠.md`。

> **口径纠正（2026-10-03）**：旧记录把 U2 现态写成「固件 1.1.11.073 / locked」，来自上轮 AI 未命中 7、8 月技能而留下的过时条目，**已作废**——以本表实机核验值为准（259 + unlocked）。

### 2.3 状态 → 可派任务（并行性来自状态不重合，不是机器身份）

| 前置状态 | 满足单元 | 可做 |
|---|---|---|
| mainline（b 槽直启 + 持久根） | **暂无**（U1 逆手术、U2 未动） | G1 上机项、G2 容器路线 |
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
| Linux rootfs（Alpine + 桌面 + Mesa + 工具） | 归档实测 **3.44 GB** → 装开后 **15–20 GB** | `env-pass/backup-20261002/linux17-rootfs-…tar.gz`（30852 项） |
| Waydroid（system+vendor+data+ART 缓存） | **30–50 GB**（压缩镜像 1.25 GB 在手） | `~/下载/` GAPPS `system.zip` 1.17 G + `vendor.zip` 77 M |
| x86 转译 chroot（Ubuntu base + Wine prefix） | **10–15 GB** | `pkgs-x86/`，PoC 已跑通 |
| guest VM 镜像（Debian / Android / Windows ARM） | **每镜像 20–60 GB** | AOSP AVF `custom_vm.md` 建议 ≥10 GB；Windows 更大 |
| 设备侧构建（内核树 + 模块 + ccache） | **25–40 GB** | 主机树 605 M + Android 树 550 G（AOSP 不在设备侧） |
| 基准/压测/日志（pstore、perf、worker 日志） | **5–15 GB** | `logs/agent-logs-2026-10-02/` 已 80 M/天 |
| **合计（全都要）** | **约 105–180 GB** | → 512 档可全放；256 档需取舍 |

### 3.2 决策规则（取代"65/128 GiB 固定值"）

1. **一次给足，不反复缩 `userdata`**：GPT 手术缩容不可逆（f2fs 需重建），二次扩容代价高 ⇒
   按 §3.1 的上界一次划足（**512 档建议 160–200 GiB；256 档建议 64–96 GiB**，若同时回收 Android 分区可再放大）。
2. **可再生的大对象不外置到设备**：内核/模块/镜像/归档留主机，用 `sshfs`/NFS/`scp` 按需取；TF 卡未修好前不指望它。
3. **回收 Android 分区是主要扩容手段**（§2.4 Phase B），不是二次缩 `userdata`。
4. 任何改动前先 `fastboot fetch` 备份 + GPT 双表 dump；改后**读回校验**（回读 md5/sha256，不看"传输完成"）。
