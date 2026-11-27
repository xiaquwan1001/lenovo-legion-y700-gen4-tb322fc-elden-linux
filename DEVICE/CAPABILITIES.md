# 硬件能力集合（CAPABILITIES）— 这块板子「应该有什么、现在到哪一步」

> **口径**：一行 = 一个**硬件块**；五桶 = ①无驱动 ②有驱动未部署（CONFIG/DT/服务） ③未模块化（=m/=y 之争） ④未上游化（树外/未投） ⑤已达成。
> **最后核实**：2026-11-27（vk189 / `7.3.1-debug-vk189-suspend` / Debian 13 磁盘根 + systemd）。
> **真源（细节与逐条证据只在报告里，本文件不复述）**：
> - 驱动/DT 面 = `reports/hw-capability-drivers-20261127.md`（vendor DT 枚举 × 主线对照 × 五桶）
> - 固件面 = `reports/hw-capability-firmware-20261127.md`（27 条请求路径 × 本机 × linux-firmware × 可否分发）
> - 单元/镜像状态 = `DEVICE/README.md` §1.1/§1.2；任务台账 = `TASKS/GAPS.md`（Q34/Q36…）
> **为什么要这张表**：`DEVICE/README.md` 记「设备是什么」，`TASKS/` 记「要做什么」，本表记**「哪些硬件能力还没接通、为什么」**——查漏补缺时先看这里，再进报告。

## 0. 数字（现查自两张报告 §0）

| 桶 | 块数 | 内容 |
|---|---|---|
| ① 无驱动 | **4** | SPSS/SPU 安全核、SOCCOP remoteproc、PMIC `hv-haptics`、vendor `bl@11`/`bias@3e`（用途未知）——**四块均已裁决不投入**，见 §5 |
| ② 有驱动未部署 | **5** | iris(VPU)、硬件 TRNG、CTCU、Coresight TPDM/TNOC、传感器中枢(SLPI/QRMI)（NFC 移出见 §3 C6；**QCE 移出见 §3 C7**） |
| ⏳ 已开 CONFIG 待上机 | **4** | TRNG / CTCU / TPDM / TNOC 已于 2026-11-27 编进 vk194（`=m` + 模块已部署），**只差一次真机启动验收** |
| ③ 未模块化 | **1** | 相机 CC/PLL 家族 `=y` 与其余 `=m` 混编（`ATH12K=y` 经裁决保留，见 §3 C8） |
| ④ 未上游化 | **8 类** | iris DTS、novatek 触屏、aw88461 功放、WCN7861(WiFi+BT)、GPS/`gmu@3d37000` 形态、传感器 fastrpc 1 行、tplg、相机 sm8750 camss |
| ⑤ 已达成 | **17** | 见 §1 |
| 固件 | 请求 **27/27 在位**；linux-firmware 逐字覆盖 **5/27**；**3 块 16 件不可分发**（WCN7861 全家/触屏/awinic 本机 ACF）|

**一句话**：**能用的都已经在用**；剩下的缺口集中在「**没开 CONFIG**（5 分钟级）」与「**树外补丁待上游**（周级）」，而不是「驱动不存在」。

## 1. 总表（块 × 五桶）

| # | 硬件块 | 驱动/部署现状 | 固件 | 上游化 | 桶 |
|---|---|---|---|---|---|
| 1 | 相机整栈（CAMSS+2×CCI+CSIPHY+s5kjns/gc08a8/gt9764+wl2868c+闪光灯+camcc） | 已绑定，17 `/dev/video*` + 1 media，`cam-mode-off.service` disabled | 无 | camss sm8750 树外（M4 系列） | ⑤+④ |
| 2 | 硬件视频解码 iris（`video-codec@aa00000`） | `CONFIG_VIDEO_QCOM_IRIS=m` 在位；**DT `status=disabled`** | `qcom/vpu/vpu35_p4.mbn` 在位（本机 rel0030，上游 `VIDEO.VPU.3.5-0040` 同名可替） | 板级 DTS 未提交 | **②+④** |
| 3 | GPU（adreno + GMU `3d37000.gmu`） | 已绑定（GMU 由 adreno 消费，无独立 driver 属设计） | `qcom/gen80000_{gmu,sqe,aqe}` 与上游同 sha | 本板 `gmu@3d37000/0x68000` 与上游 `3d6c000` 不同（跟随 vendor，未证） | ⑤ |
| 4 | 显示（MDSS/DPU/DSI×2/PHY×2/panel/背光） | `card0-DSI-1=connected`，`aw99706-backlight` | 无 | — | ⑤（Q28 坏发为既有风险，见 `reports/q28-DOSSIER.md`） |
| 5 | 触屏 novatek NT36536 | `spi0.0→novatek-nvt36xxx-spi`，`event4` | `novatek_ts_csot_3k_fw.bin`（厂商批次件，不可分发） | 驱动/binding 上游 404 ⇒ 扩展主线 `novatek-nvt-ts` | ⑤+④ |
| 6 | 触觉 aw86927 ×2 | `6-005a/6-005b`→`aw86927-haptics` | `awinic/y700-gen4-haptic.bin`（自定 profile） | 驱动 v4 线程在飞 | ⑤+④ |
| 7 | 扬声器功放 aw88461 ×2 | `9-0034/9-0037`→`aw88461` | `awinic/y700-gen4-speakers.bin`（vendor ACF 改名） | 上游 404 ⇒ 并入 `aw88395` 家族 | ⑤+④ |
| 8 | WSA884x 功放 | 本板 DT 全 `disabled`（与 vendor 一致） | 无需求 | — | ⑤（无该硬件） |
| 9 | 音频编解码 WCD9390/95 + RX/TX/VA/WSA 宏 | 声卡 `Lenovo-Y700-Gen4` 在跑 | tplg 自编 `Lenovo-Y700-Gen4-tplg.bin` | tplg 可投 linux-firmware（建议 `qcom/sm8750/LENOVO/…`） | ⑤+④ |
| 10 | 相机 PMIC wl2868c | `10-002f`→`wl2868c` | 无 | 已进 linux-next | ⑤ |
| 11 | 闪光灯 PM8550 flash LED | 主线节点 okay | 无 | — | ⑤ |
| 12 | ~~NFC ST21NFCA~~ | **不成立：本机无 NFC 硬件**（G1-10 取证五条：vendor 无 `android.hardware.nfc.xml`、无 HAL 库/固件、`elden.dts` 的 `st21nfc` 是总线 disabled 的共用模板）。`CONFIG_NFC_ST21NFCA*` 未开、DT `i2c@a80000` 两边都 disabled 与此一致 | 无 | 驱动在树（mac80211 之外的上游件） | ❌ 取消（不是桶②） |
| 13 | 硬件 TRNG（`10c3000.rng`） | `CONFIG_HW_RANDOM_QCOM=m` **已开**（vk194，模块已部署）；在机仍是 `smccc_trng` 兜底 | 无 | 无 | ⏳ 待上机（判据 `rng_current=qcom_trng`） |
| 14 | ~~QCE 加密引擎（`1dfa000.crypto`）~~ | **上游 BROKEN**：`depends on (BROKEN && ARCH_QCOM) \|\| COMPILE_TEST`（`drivers/crypto/Kconfig:529`）⇒ 真机开不出来 | 无 | 无 | ⛔ 不是缺口（见 §3 C7） |
| 15 | CTCU（`10001000.ctcu`） | `CONFIG_CORESIGHT_CTCU=m` **已开**（vk194） | 无 | 无 | ⏳ 待上机 |
| 16 | Coresight TPDM/TPDA/TNOC（28 amba 设备） | `CONFIG_CORESIGHT_{TPDM,TNOC}=m` **已开**（vk194） | 无 | 无 | ⏳ 待上机（诊断能力） |
| 17 | Modem（`remoteproc@4080000`） | DT disabled，本机 `baseband=apq`，无 modem 固件 | 无 | — | 不足（不投入） |
| 18 | SPSS/SPU 安全核 | 主线无任何 spss 驱动 | — | — | **①**（不投入） |
| 19 | SOCCOP remoteproc | `q6v5_pas` 无 sm8750 compatible | — | — | **①**（无消费方） |
| 20 | PMIC hv-haptics（pmih010x） | 主线无驱动；本机触觉走 aw86927 | — | — | **①**（先证贴装） |
| 21 | vendor `bl@11`/`bias@3e` | 任何树都无匹配驱动 | — | — | **①**（需原理图） |
| 22 | 传感器中枢（SLPI + QMI） | AP 侧 iio 只有 `spmi-adc5-gen3`；`hexagonrpcd`/`iio-sensor-proxy` 未起 | SSC registry 在 `/var/lib/hrpcd-root`（旧路径 `/usr/share/qcom` 已不存在） | fastrpc 1 行补丁未上游 | **②+④** |
| 23 | USB dwc3 + Type-C/DP altmode（fsa4480×2、ptn3222、UCSI） | 全部绑定，双连接器件 v16 在飞 | 无 | dwc3 v16 / DTS v10 在飞 | ⑤+④ |
| 24 | UFS | `1d84000.ufs`→`ufshcd-qcom` | 无 | — | ⑤ |
| 25 | microSD | `mmc0` 在册 | 无 | — | ⑤ |
| 26 | PCIe + WiFi（ath12k / WCN7861 PEACH） | `01:00.0`→`ath12k_wifi7_pci`，`wlan0` up；`CONFIG_ATH12K=y`（**已裁决保持 `=y`**，见 §3 C8） | `ath12k/PEACH/hw2.0/*` 8 件（厂商 BDF，**不可分发**） | WCN7861 支持树外 | ⑤+④ |
| 27 | 蓝牙 WCN7861（BRAHMA） | `hci0` 起，`QCA setup on UART is completed` | `qca/brh*` 5 件（不可分发，Q34 已闭环） | btqca/hci_qca 树外 | ⑤+④ |
| 28 | PMIC/regulator/thermal/ADC/RTC | 55 thermal zone、`qcom-rpmh-regulator`×6、`rtc-pm8xxx` | 无 | — | ⑤ |
| 29 | ADSP/CDSP + FastRPC（17 cb） | `remoteproc0/1 running` | split `.mdt` 全在；ADSP 与上游**不同构建**、CDSP **同 sha** | `non-secure-domain` 1 行在飞（M10） | ⑤+④ |
| 30 | Gunyah | `CONFIG_GUNYAH=m`，9 个 `.ko` 在盘均未加载 | — | 主线无 gunyah | ②+④（已裁决不投入） |
| 31 | 充电输入限流（SDP → ≥500 mA） | 按 §7 M12 台账上游件已被收；本机读 `input_current_limit=2000000`、`usb_type=SDP` | 无 | 已上游（`be5e7367bceb`） | ⑤（写侧待一次上机） |

## 2. 可执行下一步（按成本升序）

- **开 CONFIG（第一批 ✅ 已编进 vk194，2026-11-27）**：`CONFIG_HW_RANDOM_QCOM=m` + `CONFIG_CORESIGHT_{CTCU,TPDM,TNOC}=m`（片段 `patches/config-capbatch-20261127.fragment`，报告 `reports/capbatch-vk194-20261127.md`）。**剩余动作 = 一次真机启动验收**（判据见报告 §4；`scripts/capability-audit.sh config` 现应只剩 **0 条** `MISSING`）。
  ⚠ 先 `make olddefconfig` 再读符号：在机 `build/daily/.config` 是 **11-16** 生成的，而 `st21nfca` 文件 **11-25** 才进树 ⇒ 现在跑 `grep ST21NFCA .config` 是 `(absent)`，属于「config 早于树内容」而不是「树里没驱动」（`scripts/capability-audit.sh` 已把这两种成因分开提示）。
- ~~NFC~~：**不投入** —— 本机无 NFC 硬件（G1-10 已取消）。别再因为「DT 里有 `nfc@8` 节点」去开 CONFIG（那是多 SKU 共用模板，且 `&i2c0` 使能曾致硬关机 `PITFALLS #108`）。
- **iris**：把工作树里 `&iris{okay}` 的板级覆盖提交进 DTS 系列，并换用上游 `vpu35_p4.mbn`（同文件名）后做一次上机验 TZ 签名（Q36 三件套的 ③）。
- **固件门禁（已落地 2026-11-27）**：A2 曾因默认 `KDIR=build/vk151` 消失而**静默失效**（覆盖面 3/27）⇒ 现为 `MODULE_FIRMWARE ∪ required-firmware.tsv`（31 条），KDIR 三级解析、失败打 **`SKIP A2`**（不再假装通过），三态 `ok / MISS / MISS(vendor)`；门有牙齿已自测（删 `qca/tmel_peach_20.elf` ⇒ 恰好 1 条 MISS、rc=1）。清单 = `rootfs/debian/elden-firmware/required-firmware.tsv`（加硬件只改它），报告 `reports/firmware-gate-a2-20261127.md`。
- **不投入（已有裁决，逐项理由与重开条件见 §5）**：TEE/SPU、Gunyah、PMIH010x、FM/ST54、NFC、Modem、SOCCOP、vendor `bl@11`/`bias@3e`、双口快充选口、suspend 掉电率量化。

## 3. 本轮纠错（对 11-27 两份旧审计，别再用旧结论）

| 旧口径 | 现查 |
|---|---|
| 相机被 `cam-mode-off` 主动卸载、`/dev/video*`=0 | **相机栈常驻**：cam 模块 10 个在 `lsmod`、17 video + 1 media、服务 disabled |
| 「树内没有 st21nfca 驱动」 | **驱动在树**（`drivers/nfc/st21nfca/` 7 文件），缺的是 CONFIG + DT |
| `aw99706` / `phy-nxp-ptn3222` 未上游 | **均已在 torvalds master**（2026-11-27 现取 200），④ 只剩本地 delta |
| Q36「`/dev/video*` 零个 ⇒ 无硬件解码」 | 17 个 video **全是相机**；`dmesg\|grep -ci iris`=0 ⇒ iris 仍不可用，但**判据要换成 DT status + iris 日志** |
| lane A 把 NFC 记为「桶② 有驱动未部署」 | **推翻**：本机**无 NFC 硬件**（`TASKS/G1.md` G1-10 = ❌，五条取证 + `PITFALLS #108`；vendor DT 里 `st21nfc` 是**总线 disabled 的共用模板**）⇒ 该行改 ❌，桶② 计数 7→6 |
| CAPABILITIES 曾把 QCE 记为「桶② 未开 CONFIG」 | **降级**：上游 `CRYPTO_DEV_QCE` 明确 `depends on (BROKEN && ARCH_QCOM)`（`drivers/crypto/Kconfig:529`，注释写与 secure world 抢硬件）⇒ **真机开不出来**，属上游 BROKEN，不是我们的缺口（`reports/capbatch-vk194-20261127.md` §0） |
| CAPABILITIES 曾建议 `ATH12K y→m` | **撤回**：WiFi 需开机即起（initramfs 不装模块），改 `=m` 会把时序风险搬进 early boot；MHI 竞态已有 `ath12k-load.sh` 兜底 ⇒ **保持 `=y`** |
| 我方 `gmu@3d37000/0x68000` 疑为 payload bug | **vendor DT 就是这个值**；差异方向反了（该问主线 `3d6c000` 是否适用本板） |

## 4. 复现入口

```bash
# 驱动/DT 面（只读设备）
bash scripts/capability-audit.sh                   # 全部（CONFIG/绑定/固件三段，只读）
bash scripts/capability-audit.sh --tsv             # 机读
bash scripts/capability-audit.sh config|bind|fw    # 单段
# 固件面
bash rootfs/debian/elden-firmware/build.sh --check-fw-only   # A2 固件门禁（31 条，含厂商件三态）
bash rootfs/debian/elden-firmware/build.sh --check-fw-only SRC=<本地固件目录>   # 离线
# 门禁
bash scripts/check-doctor.sh
```

## 5. 已裁决「不投入」的硬件面（勿重推）

> 判据：**私有/无源码/无消费方** 三者之一 + 用户或台账已裁决。要重开必须给出「新增证据」，不是「再试一次」。

| 项 | 硬件证据 | 不投入的理由（真源） | 重开条件 |
|---|---|---|---|
| **TEE / SPU / hw-fence / mem-buf** | vendor `remoteproc-spss@1880000` + `spss_utils`，节点 `ok`；主线无 spss 驱动 | 私有协议、无源码；主线无客户端与服务面（`TASKS/GAPS.md` §2「明确不投入」、`DEVICE/README.md` §1.3 ✗ 行） | 上游出现 SPU 客户端（如 qcomtee 上游化并有用例） |
| **Gunyah（高通 hypervisor 做 VM）** | `CONFIG_GUNYAH=m` + 9 个 `.ko` 在盘，**均未加载**；mainline 无 gunyah | 2026-10-25 终局裁决不做；2026-11-11 改「有条件重启」而**条件未满足** ⇒ 视同不投入；`drivers/virt/gunyah` 只作 G1 上游补丁素材封存（loader 逆向/参考 VMM 差值/pVM 参数再试**三项均停**） | `reports/gunyah-restart-assessment-20261111.md` 里的条件成立（否则不排期、不占设备时间） |
| **PMIH010x（PMIC 上的 hv-haptics 等）** | 主线无 `hv-haptics` 驱动；本机触觉实际由 `aw86927` 承担（`event2/3` 在跑） | 私有、且**未被使用**；`pmih0108.dtsi` 无对应节点 ⇒ 无消费方 | 原理图/实测证明该 PMIC 的相关模块真被使用 |
| **FM 收音（RTC6226）** | 器件/驱动均无主线路径 | 私有；无主线 tuner 驱动可对齐（`DEVICE/README.md` §1.3 ✗ 行） | 上游出现对应 tuner 驱动且硬件确认在位 |
| **ST54 SE（安全元件/NFC-eSE）** | 随 NFC 一并不成立 | 无 NFC 硬件 ⇒ 无 SE 通路；私有协议 | 同 NFC：先证贴装 |
| **NFC（ST21NFCA）** | 本机**无** NFC 硬件（五条取证，`G1-10` ❌、`PITFALLS #108`） | 不是「缺驱动」；`&i2c0` 使能曾致**硬关机** | 拆机/原理图证到贴装（目前证据全是「没有」） |
| **Modem（`remoteproc@4080000`）** | DT `disabled`；本机 `baseband=apq`；无 modem 固件 | 本机是 WiFi-only 配置（APQ 变体），无 modem 硬件可驱动 | 换到带 modem 的硬件变体 |
| **SOCCOP remoteproc（`a3380000`）** | vendor 节点 `ok`，主线 `q6v5_pas` 只匹配 kaanapali/glymur | 无任何消费方（vendor 仅自用），投入产出为零 | 出现需要 SOCCOP 的用例 |
| **vendor `bl@11`（i2c-backlight）/ `bias@3e`** | 两 compatible 在任何树都无匹配驱动 | 用途未知（无原理图/无用户），且背光实际走 `aw99706` 已工作 | 拿到原理图定位用途 |
| **双口「长边数据 + 短边快充」** | 物理可行（短边 PD 单独插时 12.2 A / ≈46 W） | **被 ADSP 选口策略挡住**，AP 侧无控制面（`TASKS/GAPS.md` Q35 = 已判定不再投入） | ADSP 侧出现选口接口（vendor 新固件/上游 charger 链） |
| **suspend 掉电率量化** | — | 2026-10-28 用户裁决：**最低优先、暂不排期**（不是否定可行性，是排序） | 有独立窗口时按 Q/T9 历史口径恢复 |
| **SLPI 传感器原生栈（G1-34）** | AP 侧无私有 I2C 总线，需 QRTR + `qcom_smgr` | 「可选自研、未开工」；**G2 不等它**（容器走虚拟传感器）。注：传感器出数已于 2026-11-27 用 ADSP SSC 路线拿到，本项只剩「原生栈」形态 | 真要脱离 ADSP 固件栈时 |
| **温控 OEM 层（`lenovo,sys-temp`/BCL/QMI cooling）** | 厂商私有 | 通用 thermal 框架已给 4 级 trip（55 zone 在跑），只需长负载复核壳温 | 长负载实测出现限频/过热问题 |
