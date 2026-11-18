# GPT 最小化设计（TB322FC / `elden`）：分区表「少而可控」+ 逐分区理由 + 最小 Debian 刷机清单

> 目标（用户口径，2026-11-17）：**精简掉不必要分区，降低调试负担**；只要 **Debian 派系最小系统**（无 Phosh 等桌面用户态）；
> 从 **EDL/fastboot 冷启**能复现到「持久化 Linux」。
> 工具：`scripts/gpt-minimal-build.py`（生成表，`--lun 0|4`）+ `scripts/gpt-audit-tb322fc.py`（逐字节对账）+ `scripts/linux-state-audit.sh`（体检）。
> 复现步骤 = `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md`；本文件只讲「表怎么简化」「每项为什么不能删」「要备哪些件」。

---

## 0. 结论（数字）

| 项 | 现状 | `minimal-v1`（推荐） | `minimal-v2`（激进，需设备窗口验证） |
|---|---|---|---|
LUN0 分区数 | 18 | **10**（9 个固件/身份区 + 1 个 `linux`） | 10（无法再减，见 §2.2） |
LUN4 分区数 | 78 | **74**（只删 Android GKI 4 项） | **57**（再删 17 个候选，逐项需单变量验证） |
LUN5 分区数 | 5 | 5（modem NV，见 §2.6） | 5→0（WiFi-only 无蜂窝时才考虑） |
Linux 分区 | `linux17` 192 GiB | **`linux` = LBA 90504..123871226 = 472.19 GiB**（一次划死） | 同 |
主机侧必备件 | 原厂 16 GB 包 + 1.5 GB bootslot-b | **约 700 MB**（原厂包只用于回 Android/救砖） | 同 |

**核心思路（三条）**：
1. **删条目 ≠ 删数据** ⇒ 实验可逆（旧 GPT 备份写回即可），所以敢先删后验；
2. **保留分区的 LBA 一个都不动** ⇒ 零数据搬迁（工具已保证）；
3. **收益/风险比决定去留**：`super`+`userdata` 472 GiB（删）、`modem` 700 MiB（未验证，先留）、`boot_a`/`dtbo_a` 128 MiB（留着当回退槽）。

---

## 1. 现状盘点（2026-11-17 18:53 六 LUN dump；`reports/artifacts/bl-stuck-20261118/edl-read/`）

| LUN | 分区数 | 合计占用 | 性质 |
|---|---|---|---|
| 0 | 18 | 472.0 GiB | 用户数据 + Android 容器 + 身份/元数据 |
| 1 / 2 | 5 / 5 | 各 ~4 MiB | `xbl_*` 引导 LUN（**与 A/B 槽绑定**，`PITFALLS #484`） |
| 3 | 3 | 1.2 MiB | `cdt` / `ddr` / 对齐填充 |
| 4 | 78 | 1.6 GiB | 全芯片固件 A/B + boot 链 + 少量设备数据 |
| 5 | 5 | 12.3 MiB | modem NV 数据 |

---

## 2. 逐分区理由（**这是本文件的核心**）

理由码：**R1** 引导链按名读取（XBL/ABL/UEFI 自己取）· **R2** 固件源（PIL/remoteproc 加载到协处理器）·
**R3** 设备唯一数据（原厂包**不**恢复，丢了不可复得）· **R4** 项目实测功能依赖（我们的 Linux 用到）·
**R5** A/B 回退槽 · **C** 理论上可删但**未验证**（默认保留）· **D** Android/GKI 专用（可删）。
证据强度：`实测` = 我们设备上跑过/读过 · `机制` = 芯片引导链/代码路径决定 · `推断` = 按名称与官方包分类，**未单变量验证**。

### 2.1 LUN0 —— 必留 9 项（353.5 MiB）

| 分区 | 大小 | 码 | 证据 | 为什么不能删 |
|---|---|---|---|---|
| `proinfo` | 3 MiB | R3 R1 | 实测/机制 | 出厂产品信息（机型/区域/序列相关）；Lenovo 工具与部分校准读它；原厂 `rawprogram` 里 `filename=""`（**不刷**）⇒ 云端包恢复不了 |
| `lenovolock` | 512 KiB | R3 R1 | 实测 | Lenovo 区域锁/解锁状态；官方包里同样留空不刷 ⇒ 删了不可再得 |
| `lenovocust` | 300 MiB | R3 R2 | 实测 | Lenovo 定制分区（区域配置/定制件）；官方包内是 `lenovocust_1.img`，但**设备侧写入后的值**是唯一现网态 |
| `lenovoraw` | 16 MiB | R3 R1 | 实测 | Lenovo raw 配置；与解锁/区域相关（`restore-259/README.md` 记录其签名语义），官方包会写 → 但现网值才是"该机"的 |
| `ssd` | 8 KiB | R3 R2 | 实测/机制 | TEE 安全存储描述符；原厂留空不刷 |
| `persist` | 32 MiB | R3 R2 | 实测 | 传感器/射频/触控校准（Linux 侧驱动与 sensor HAL 会读）；官方包留空 ⇒ **唯一副本**（`backup/<SN>/unique/` 已 dump） |
| `misc` | 1 MiB | R1 | 实测 | **BCB**：ABL 每次启动读（`ffbm-*`/`boot-recovery`/`boot-fastboot`）。2026-11-17 实测「清 BCB 内容 ≠ 删分区」，删了 ABL 读失败风险高，收益 1 MiB |
| `keystore` | 512 KiB | R2 R3 | 机制/实测 | keymaster/TEE 密钥材料（Android 侧写）；官方留空不刷 |
| `frp` | 512 KiB | R1 R3 | 机制 | 工厂重置保护状态；ABL/UEFI 会读 |

### 2.2 LUN0 —— 删 7 类（472.19 GiB）

| 分区 | 大小 | 码 | 依据 |
|---|---|---|---|
| `super` / `elden-super` | 22 GiB | D | Android 动态分区容器（system/vendor/product/odm）；ABL 启动 Linux 不读，Linux 也不需要 |
| `userdata` / `elden-data` | 256.7 GiB | D | Android `/data` |
| `metadata` | 64 MiB | D | Android 加密/apex 元数据（init 第二阶段才用） |
| `vbmeta_system_a/b` | 各 64 KiB | D | Android system 的 AVB 链节点；我们只签 `vbmeta`（见 §2.4 `vbmeta_b` 实测只有 `chain:boot`+`hash:dtbo`） |
| `rawdump` | 256 MiB | D | Android ramdump 落盘；Linux 用 **ramoops 保留内存**（`elden.dtb` 的 `/reserved-memory`），不用分区 |
| `pstoredump` / `pstoredu` | 128 MiB | D | 同上 |
| `linux17` / `eldenesp` / `elden-su` | 192.5 GiB | — | 我方历史布局，被单个 `linux` 取代（**ESP 链路同时退役**，见 §3.3；需要时 `--keep-esp-gib 0.5` 加回） |

### 2.3 LUN4 —— 74 项全留的逐条理由（1453.1 MiB）

**A. 引导链本体（R1，删了直接开不了机）**

| 分区 | 大小 | 证据 | 说明 |
|---|---|---|---|
| `boot_a` / `boot_b` | 96 MiB ×2 | 实测 | ABL 按槽读它加载内核（我们的 `boot.img` 就写这里）；**A/B 双份 = 回退槽**（R5） |
| `dtbo_a` / `dtbo_b` | 32 MiB ×2 | 实测 | ABL 在 `BootLinux` 后 `Apply Overlay`；原厂 Android DTBO 会把我们的 DTB 污染（`#600–#602`）⇒ 保留但写 4 KiB 假件 |
| `vbmeta_a` / `vbmeta_b` | 64 KiB ×2 | 实测 | ABL 的 AVB 入口；`vbmeta_b` 实测含 `chain:boot`+`hash:dtbo`（`avbtool info_image`） |
| `recovery_a` / `recovery_b` | 100 MiB ×2 | 机制 | Android recovery（ABL 的 `boot-recovery` 目标）；留着 = 现场有 `fastbootd`/`adb recovery` 可用，删了省 200 MiB 但少一条救援通道（R5） |
| `uefi_a` / `uefi_b` | 5 MiB ×2 | 实测 | Qualcomm UEFI 固件本体（XBL 之后第二个 EL）；我们刷过 39 分区里就包含它（`39/39` 校验） |
| `imagefv_a` / `imagefv_b` | 2 MiB ×2 | 实测 | UEFI 的 FV 镜像（UEFI 驱动/应用打包）；与 `uefi` 配套 |
| `uefisecapp_a/b` | 2 MiB ×2 | 机制 | UEFI SecureApp（安全启动策略执行） |
| `toolsfv` | 1 MiB | 机制 | UEFI 工具 FV（非 A/B，单独一份） |
| `devinfo` | 4 KiB | 实测 | **解锁/设备信息**（`unlocked:yes` 的源头）；删了锁状态语义不可控 |
| `uefivarstore` | 512 KiB | 实测 | **UEFI 变量存储（含启动项）**：我们 ESP/UEFI 链路改的 boot entry 存在这里（`android-required-resources-audit` 把它列为"必提"） |
| `logfs` | 8 MiB | 实测 | ABL 成功交接的段日志（我们唯一能拿到的"ABL 真的尝试过"正控，`#485`/`#594`/`#602`） |
| `xbl_sc_logs`、`xbl_sc_test_mode` | 128 KiB / 64 KiB | 机制 | XBL 二级引导日志/测试模式；实测长期全 0（未启用），但属于引导链读取面 |

**B. 安全/密钥/身份（R2+R3，设备唯一或 TEE 依赖）**

| 分区 | 大小 | 证据 | 说明 |
|---|---|---|---|
| `tz_a/b` | 5 MiB ×2 | 实测 | TrustZone 固件（`39/39` 之一） |
| `hyp_a/b` | 8 MiB ×2 | 实测 | Hypervisor（Gunyah）固件 |
| `keymaster_a/b` | 512 KiB ×2 | 机制 | Keymaster TA（TEE 密钥服务） |
| `devcfg_a/b` | 128 KiB ×2 | 实测 | 设备配置/熔丝相关的安全配置 |
| `qupfw_a/b` | 128 KiB ×2 | 机制 | QUP 固件（I2C/SPI/UART 控制器）——**触控/传感器总线依赖**（R4） |
| `featenabler_a/b` | 64 KiB ×2 | 机制 | 特性开关/DRM 使能数据 |
| `storsec` | 128 KiB | 机制/R3 | 安全存储（storage security）数据 |
| `secdata` | 28 KiB | **R3** | 安全数据（设备唯一，原厂留空不刷） |
| `connsec` | 128 KiB | **R3** | 连接安全数据（设备唯一） |
| `tzsc` | 128 KiB | **R3** | TZ 安全配置（设备唯一） |
| `spunvm` | 32 MiB | **R3** | SPU（Secure Processing Unit）NVM——**设备唯一数据**，官方包不恢复 |
| `qweslicstore_a/b` | 128 KiB ×2 | R3 | QWES license 存储（设备唯一） |
| `dpm` | 8 KiB | R3/C | DPM 数据；体积可忽略，无脑保留 |
| `mdcompress` | 20 MiB | R3 | modem 压缩数据（设备唯一；WiFi-only 机器上可能是历史残留，见 §2.5） |

**C. 协处理器固件（R2，功能来源）**

| 分区 | 大小 | 证据 | 说明 / 我们的依赖 |
|---|---|---|---|
| `dsp_a/b` | 64 MiB ×2 | **R4 实测** | ADSP 固件（`qcom_q6v5_pas` 加载）——**传感器（SSC）、音频、触觉**都靠它；`/dev/fastrpc-adsp` 与 `qrtr svc 400` 的判据见 `DEVICE` §1.1 |
| `modem_a/b` | 350 MiB ×2 | R2 / 见 §2.5 | MPSS 蜂窝固件。本机 `product=elden_prc_wifi`（WiFi-only）⇒ **理论上可删**，但未验证（`minimal-v2` 候选） |
| `bluetooth_a/b` | 8 MiB ×2 | R2/R4 | BT 固件/NVM（WCN7861 的 BT 侧数据） |
| `aop_a/b`、`aop_config_a/b` | 512 KiB ×2 各 | R2 实测 | Always-On Processor（睡眠/唤醒、传感器低功耗路径）+ 配置 |
| `cpucp_a/b`、`cpucp_dtb_a/b` | 1 MiB / 128 KiB ×2 | R2 机制 | CPUCP 协处理器（功耗/热管理）+ 其 DTB |
| `shrm_a/b` | 192 KiB ×2 | R2 机制 | Shared Resource Manager（内存共享/boot 期协同） |
| `pvmfw_a/b` | 1 MiB ×2 | R2 推断 | Protected VM 固件（Gunyah pVM；`reports/gunyah-pvm-attempt-20261025.md` 用过真 pvmfw）⇒ 只在 VM 路线用；因 Gunyah 非主线 ⇒ 若确认不碰可进 `minimal-v2` |
| `spuservice_a/b` | 64 KiB ×2 | C 推断 | SPU service 固件（**0 篇项目文档**，纯名称推断） |
| `soccp_debug_a/b`、`soccp_dcd_a/b` | 512 KiB / 16 KiB ×2 | C 推断 | SOCCP 子系统的调试/DCD 数据（未验证） |
| `pdp_a/b`、`pdp_cdb_a/b` | 128 KiB / 64 KiB ×2 | C 推断 | PDP/CDB（未验证；与 Qualcomm debug policy 相关） |
| `xbl_ramdump_a/b` | 2 MiB ×2 | C 推断 | XBL ramdump 落盘区（非运行依赖，体积 4 MiB） |

**D. LUN4 明确可删（4 项 / 208 MiB，`minimal-v1` 已删）**

| 分区 | 大小 | 依据 |
|---|---|---|
| `vendor_boot_a/b` | 96 MiB ×2 | Android GKI 第二段（vendor ramdisk/bootconfig）；自建 `boot.img` 自带 DTB+initramfs，不需要 |
| `init_boot_a/b` | 8 MiB ×2 | Android 13+ 的 init ramdisk 专用槽；同上 |
| 已验证不破 AVB | — | `vbmeta_b` 只有 `chain:boot` + `hash:dtbo`(4096 B) **两个描述符** ⇒ 不含 `vendor_boot`/`init_boot` |

### 2.4 LUN1 / LUN2（各 5 项，全留）—— 引导 LUN，与槽绑定

| 分区 | 大小 | 码 | 理由 |
|---|---|---|---|
| `xbl_a`（LUN1）/ `xbl_b`（LUN2） | 3.5 MiB ×2 | R1 实测 | 第一级引导（Sahara/Firehose 之外的正常引导链起点）。`#484` 定案：**ABL 按活动槽选 boot LUN**（`_a`→LUN1，`_b`→LUN2），两代固件曾并存导致"只能进 fastboot" ⇒ 两槽都必须保留且代次一致 |
| `xbl_config_a/b` | 320 KiB ×2 | R1 实测 | XBL 配置（与 `xbl` 配套；`39/39` 之一） |
| `multiimgqti_a/b`、`multiimgoem_a/b` | 16 KiB ×2 | R1 机制 | XBL 多镜像/QTI-OEM 元数据 |
| `apdp` / `apdpb` | 192 KiB ×2 | R2/R3 机制 | 调试策略/供应数据（APDP）；原厂包会写，但含机器相关信息 ⇒ 留 |

### 2.5 LUN3（3 项全留）

| 分区 | 大小 | 码 | 理由 |
|---|---|---|---|
| `cdt` | 128 KiB | R2 机制 | Config Data Table（平台/板级配置，XBL 读） |
| `ddr` | 1 MiB | R1/R3 实测 | DDR 训练/序列数据。官方 `rawprogram3` 写的是 `zeros_5sectors.bin`（= 全 0）⇒ 出厂态就是 0；我们 2026-11-17 按官方配方清零后**现象无变化**（那条"清零"证据的另一半）。留 1 MiB，别在这上面做文章 |
| `ALIGN_TO_128K_1` | 64 KiB | R1 机制 | 128 KiB 对齐填充（GPT 布局要求） |

### 2.6 LUN5（5 项）—— modem NV，WiFi-only 机器的「待定」

| 分区 | 大小 | 码 | 理由 |
|---|---|---|---|
| `modemst1` / `modemst2` | 4 MiB ×2 | **R3** | modem NV（IMEI/射频校准类数据）。**设备唯一**，原厂包留空不刷 ⇒ 删了不可恢复。WiFi-only 机器上不用蜂窝 ⇒ 功能上可删，但"删掉唯一的 NV 备份"没有收益（8 MiB） |
| `fsg` / `fsc` | 4 MiB / 128 KiB | R3 | modem FS + 缓存，同上 |
| `ALIGN_TO_128K_2` | 64 KiB | R1 | 对齐填充 |

### 2.7 `minimal-v2` 候选（**默认一个都不删**，17 项 / 约 0.77 GiB）

`modem_a/b`(700 MiB) `qmcs`(30) `spunvm`(32) `mdcompress`(20) `xbl_ramdump_a/b`(4) `soccp_debug_a/b`(1) `soccp_dcd_a/b` `pdp_a/b`(0.25) `pdp_cdb_a/b` `spuservice_a/b` `qweslicstore_a/b` + （LUN5 若确认不用蜂窝）`modemst1/2`/`fsg`/`fsc`。

**收益**：分区数 74→57，空间 ≈ 0.77 GiB（对 472 GiB 的 Linux 分区毫无影响）。
**成本**：每一项都要一次单变量上机验证（§4 P6），其中 `spunvm`/`secdata`/`mdcompress` 等还是**设备唯一数据** ⇒ 删了要永久丢。
⇒ **结论：优先级最低，只在 v1 稳定运行 ≥ 1 周且确实被"条目太多"困扰时才做**。

---

## 3. 最小刷机资料清单（EDL/fastboot → 持久化 Debian）

### 3.1 主机侧必备（约 700 MB；原厂 16 GB 包只在回 Android/救砖时需要）

| # | 件 | 大小 | 怎么来 | 写到哪 |
|---|---|---|---|---|
| 1 | EDL loader `xbl_s_devprg_ns.melf` | 1.7 MB | `backup/fw/tb322fc-edl/` | Sahara（内存） |
| 2 | `qdl` v2.9（自建） | — | `~/edl/qdl/build/qdl` | 主机 |
| 3 | 最小 GPT（main+backup，LUN0+LUN4） | 24+20 KB ×2 | `scripts/gpt-minimal-build.py --lun 0 / --lun 4` | LUN0/LUN4 LBA0..5 / 备表 |
| 4 | `boot.img`（kernel+DTB+initramfs） | ~86 MiB | `scripts/build-boot.sh`（`build-kernel.sh` 编译） | `boot_b`（回退槽 `boot_a` 可选） |
| 5 | `vbmeta_b`（`Flags=3` 关校验） | 4 KiB | `backup/vbmeta_b-20261110.img`（或用 `tools/avbtool.py make_vbmeta_image` 重签） | `vbmeta_b` |
| 6 | `dtbo` 假件（4 KiB 全零） | 4 KiB | `out/dtbo-dummy.img`（`ad7facb2…`） | `dtbo_b`（a 槽同理） |
| 7 | rootfs ext4 镜像（最小档，**模块+固件已含在内**） | 6 GiB（实占 2.1 G） | ✅ `scripts/rootfs-minbase-build.sh`（debootstrap trixie minbase + 21 包 + `stage-min-*` + `mke2fs -d`）→ `out/p2-minbase-20261118/rootfs-minbase-20261118.ext4.img`（label=`linux`，sha256 `d22c6a00…`） | `linux`（ext4，`LABEL=linux`） |
| 8 | 模块包（**同 UTS**） | ✅ 已在 7 内（1510 个 `.ko`，UTS `7.3.1-debug-vk189-…-g4bdf1711b5c0`） | `out/stage-min-20261118/lib/modules/` | 同上 |
| 9 | 固件 blob（`/lib/firmware`） | ✅ 已在 7 内（44 MB，含 `Lenovo-Y700-Gen4-tplg.bin`） | `out/stage-debian/lib/firmware`（原厂 vendor 提取） | 同上 |

**不需要**：原厂全量包（除回 Android）、`bootslot-b/` 历史镜像（只留台账那一件）、ESP/GRUB 四件（§3.3）。

### 3.2 最小 Debian 用户态（无桌面）——细化到命令

> **✅ 2026-11-18：下面这套已落成脚本，不要手跑** —— `scripts/rootfs-minbase-build.sh`（需 root；`--dry-run` 可先看计划，`--background` 自分离 + `/tmp/elden-minbase-build.log`）。
> 内部 = `rootfs/debian/build-rootfs.sh` 的最小档（`APTLIST=apt-list-min.txt` `SUITE=trixie` `SKIP_DESKTOP=1` `GATE_MIN=1` `ROOTSPEC=LABEL=linux` `IMG_MIB=6144`）。
> 实测：debootstrap+qemu 约 15 min、160 包、根 2.0 G、1510 个 `.ko`、15 项门禁全绿、`mke2fs -d` 出 6 GiB 镜像。
> 两个坑：① 门禁取样模块不能写死 `ath12k.ko`（vk189/vk192 里是 built-in ⇒ 已改动态取 .ko）；② 必须真 root（`sudo`）——`proot`+`fakeroot` 路线已实测失败（`base-passwd` 处 signal 11 + `libfakeroot payload not recognized`）。

```sh
# 主机侧（arm64 目标，用 debootstrap 的 foreign/second stage 或 chroot+qemu）
debootstrap --arch=arm64 --variant=minbase --include=systemd,systemd-sysv,kmod,iproute2,openssh-server,ca-certificates \
            trixie /mnt/rootfs https://mirrors.ustc.edu.cn/debian
# 网络（二选一，推荐 iwd 更省）
chroot /mnt/rootfs apt install -y iwd systemd-resolved rfkill
# 可选调试件：vim-tiny htop strace tcpdump
```
必备配置（缺一不可，都是踩过的坑）：

| 项 | 内容 | 为什么 |
|---|---|---|
| `/etc/fstab` | `LABEL=linux / ext4 defaults,noatime 0 1`（**用 LABEL 不用 PARTLABEL**） | `init` 解析 `elden_root=` 走 busybox `findfs`：支持 `LABEL=`/`UUID=`，**不支持 `PARTLABEL=`**（那里只回退到 `blkid -t`，RAM 阶段未必有）；GPT 变过多次 ⇒ 名字比 `/dev/sdaN` 稳 |
| cmdline | `elden_root=LABEL=linux`（initramfs 用；`root=` 是给无 initramfs 的内核用） | 见 `out/p2-minbase-20261118/boot-minbase-labellinux.img`；`scripts/build-boot.sh` 的 `ROOTARGS=` 可覆盖
| 模块 | `/lib/modules/<UTS>` 整套 + `depmod -b` | 与内核 UTS 严格同源（`PITFALLS` 内核条） |
| 网络 | `systemd-networkd` + `iwd`（或 `wpa_supplicant`），hostname/ssh key | S8 验收要 `ssh` 通 |
| 自编件 | 若装自编 `phoc` 等：`dpkg-divert` + `apt-mark hold` | `PITFALLS #654`：只 `install` 会被 apt 静默冲回 |

### 3.3 为什么连 ESP/GRUB 也省掉

原链路（ESP → GRUB → Loader.efi → `\boot\boot.img`）是为了**多臂菜单与无主机启动**。最小系统直接 **ABL → `boot_b`**：
内核 + DTB + initramfs 全在 86 MiB 的 `boot.img` 内，少 1 个分区（`eldenesp` 512 MiB）+ 4 个件（GRUB/Loader/`menu.cfg`/`grubenv`）。
需要多臂菜单时：`--keep-esp-gib 0.5` 加回分区，再按 `DEVICE/README.md` §1.1 的现役件清单还原。

---

## 4. 实验计划（单变量、可逆；**删条目 ≠ 删数据**）

| 阶段 | 动作 | 判据（全绿才进下一步） | 回退 |
|---|---|---|---|
| **P0** | ✅ **已完成（2026-11-17 22:0x）**：原厂 Android 16 在线复核 + EDL 只读 dump 六 LUN 主备表（`backup/HA2EXB0E-16+512/edl-20261118/`，12 件 + `SHA256SUMS.txt`；主备条目逐字节相等、头/条目 CRC 全 OK） | `linux-state-audit.sh --device` = 1 DRIFT / 2 WARN；`gpt-audit` 退出码 1（仅 LUN0 17 字节差异：`userdata` 延到 LBA 123871226） | — |
| **P1** | 写 LUN0 最小表（`--lun 0`）：**表已生成** `out/gpt-minimal-20261118/lun0_{main0,backup0}.bin`（10 项、`linux` = LBA 90504..123871226 = 472.19 GiB，双表 CRC 自检通过） | 仍能进 fastboot；EDL 读回 `gpt-audit` 显示「9 项 + linux」 | 写回 `backup/HA2EXB0E-16+512/edl-20261118/gpt0-{primary,backup}.bin`（4 KiB 扇区：主表 LBA0..5、备表 LBA 123871227+5） |
| **P2** | ✅ **前置件已齐（2026-11-18 11:29）**：① 镜像 `out/p2-minbase-20261118/rootfs-minbase-20261118.ext4.img`（6 GiB 稀疏、实占 2.1 G、label=`linux`、sha256 `d22c6a00d5c27c71…`）② `out/p2-minbase-20261118/boot-minbase-labellinux.img`（同 vk192 核/DTB/initrd，唯一差异 = cmdline `elden_root=LABEL=linux`，sha `7ea9370b…`）③ `out/dtbo-dummy.img` ④ `backup/vbmeta_b-20261110.img` ⑤ 两张最小表。动作 = `qdl -s ufs $L write 0/90504 <img>` → 上台 `resize2fs /dev/disk/by-label/linux` → 刷 `boot_b`/`dtbo_b`/`vbmeta_b` | **冷起进 Debian + `ssh` 通 + `findmnt /` = `LABEL=linux`** | ⚠️ **不是** `fastboot --set-active=a`（本行旧口径作废）：`linux` 起点 LBA 90504 = 原 `super` 起点，P2 写入的头 6 GiB 会覆盖 `super` ⇒ **P2 之后 Android a 槽不再可起**。真回退 = 写回 `edl-20261118/gpt0-*` 旧表 **+ 重刷官方 `super`**（`backup/official-rom-15.10.259`；2026-11-17 已实测走通一次，~20 min）。「删条目 ≠ 删数据」在这里**不成立**（数据已被 P2 覆盖） |
| **P3** | 写 LUN4 最小表（`--lun 4`，删 4 项）：**表已生成** `out/gpt-minimal-20261118/lun4_{main4,backup4}.bin`（74 项） | 冷起仍进 Debian；`fastboot continue` 无 `Device Error` | 写回 `edl-20261118/gpt4-{primary,backup}.bin` |
| **P4** | `slot-attr.py mark-successful b`（+`--set-active=b`） | 连起 8 次仍在 `_b`（`#181` 的 7 次耗尽线） | `--set-active=a` |
| **P5**（可选） | 单槽化（腾 a 槽固件） | — **不做**：1.6 GiB 换一整条退路 | — |
| **P6**（低优先） | `minimal-v2` 逐批删（每批 ≤3 项，含 1 项"设备唯一"时单独成批） | 每批都跑 P2 判据 + 复查 `dmesg` 无 `-EPROBE_DEFER`/固件加载失败 | 写回旧 LUN4 表（数据仍在盘上） |

每步记录三件事：① `getvar` 全量；② EDL 读回 + `gpt-audit`；③ 冷起后的 `adb`/`ssh` 判据。
**判据纪律**（`LINUX-STATE-REPRO.md` §1.2）：硬件结论四道门；错误串自变（`#482`）、`poke`（`#486`）不算证据。

---

## 5. 使用规则（让表「可控」的纪律）

1. **只允许一个 Linux 分区叫 `linux`**；禁止再造 `linux17/18`、`elden-*`（历史 `elden-super/elden-data/eldenesp` 已删）。
2. **LUN0 条目上限 12**（现 10）；新增分区前先问「能不能放进 `linux` 的文件系统」。
3. **任何 GPT 变更三步**：`gpt-minimal-build.py`（或 `gpt-surgery`）→ 写入 → **读回 + `gpt-audit`**；三步缺一不算完成。
4. **保留域不许改**：`proinfo/lenovolock/lenovoraw/ssd/persist/misc/keystore/frp` + LUN4 的 `devinfo/uefivarstore/logfs`；改动前先 `backup/` dump。
5. **A/B 双份固件保留**：`--set-active` 是唯一零成本回退手段（`#484` 槽↔LUN 绑定，两槽代次必须一致）。
   ⚠️ 例外 = **P2 之后**：`linux` 覆盖了原 `super` 区间 ⇒ Android a 槽不再是零成本退路，回退要重刷 `super`（见 §4 P2 回退列）。
6. **实验可逆性的前提**：每次写表前，把**当前**主备表 dump 进 `backup/<SN>-16+512/` 并更新 `SHA256SUMS`。

---

## 6. 与既有文档的关系（避免两套说法）

- `DEVICE/README.md` §2.4「Phase B 回收 Android 专属分区」= 旧口径（曾列 `misc`/`boot_a`/`dtbo_a`/`recovery_a` 可删）。
  **本文件取代它**：`misc`/`devinfo` 必留，`boot_a`/`dtbo_a`/`recovery_a` 属 A/B 回退槽保留（回退价值 > 1 GiB）。
- `DEVICE/README.md` §3 容量策略在本设计下退化为一句：Linux = 除固件与身份区之外的全部剩余盘（472 GiB），不再需要容量估算。
- 复现步骤以 `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md` 为准；本文件只改「表」与「件清单」。

---

## 7. 待补（按优先级）

1. **`linux-gpt-apply.sh`**：EDL 直写双表（自动算 `backup_lba`）+ 写后读回对账（现在分两步手工）。
2. **rootfs 归档缺失**（唯一硬缺口）：最小系统定型后产出 `out/rootfs-debian-minbase-<date>.tar.zst` 并入账。
3. ~~**LUN4 备表 dump** 未入库~~ → **已完成（2026-11-17 22:0x）**：`backup/HA2EXB0E-16+512/edl-20261118/gpt4-backup.bin`（LBA 1048571+5，条目与主表逐字节相等）。
4. **`minimal-v2` 的逐项判据表**（每项：预期影响 / 观测命令 / 通过标准）——等 v1 稳定后再写。
