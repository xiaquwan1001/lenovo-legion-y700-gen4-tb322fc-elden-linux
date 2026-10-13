# research-driver-modularization-2026-10-09 — elden(TB322FC/SM8750P) 主线内核驱动模块化方案

> 面向 G1（完整 Linux + 上游化）：评估把 =y 驱动翻成 =m 的收益、约束与最小改动路径。
> 本文件只做分析与方案，不修改领域层文件；所有脚本/fragment 引用均为现有实现。

## 0. 现状取证（实测）

| 项 | 值 | 出处 |
|---|---|---|
| defconfig | `linux/arch/arm64/configs/defconfig`（上游多厂商 arm64 defconfig，1972 行）+ fragments（`qcom-*.config`、`hardening.config`、`f2fs-rootfs.config`、`tablet-input.config`…） | `scripts/build-kernel.sh`、`scripts/apply-kernel-fragment.sh` |
| 实际 `.config` | **=y 3449 项 / =m 1319 项**（已含大量上游 defconfig 默认 =m 的非 QCOM 驱动） | `linux/.config` |
| 已有模块化 fragment | `patches/fragment-modular.config`（音频 WCD939X/QDSP6、ATH12K、触屏 NVT36XXX、haptics AW86927、backlight AW99706 → =m，1319→1355 模块，实测干净翻转） | `patches/fragment-modular.config` |
| 可选 video fragment | `patches/fragment-modular-video.config`（DRM_MSM + NT36536 panel → =m，有显示回退风险，未默认采纳） | 同目录 |
| 内核 Image.gz | **20.5 MB**（2026-10-09 构建） | `linux/arch/arm64/boot/Image.gz` |
| boot 镜像 | vk75 = **85.3 MB** / 分区上限 **96 MiB（100663296 B）** → 余量 **~10.7 MB** | `out/boot-elden-vk75-q28ab.img`、`DEVICE.md` §boot 布局 |
| ramdisk | 完整 rootfs cpio 62–81 MB（主导 boot 体积）；slim initramfs 1.06 MB | `out/*.cpio.gz` |
| 模块热载机制 | `scripts/mod-loop.sh`（=m 驱动 30s 热改）、`scripts/camera-modules-load.sh`（init 阶段 modprobe 范式） | scripts/ |

## 1. 关键驱动分类表

分类标准：**必须=y**（挂根/早期 I/O/显示/平台骨架）｜**可=m 需 initramfs/早期加载**（启动早期要功能）｜**可=m rootfs 按需**（桌面起来后 udev/modprobe 自动加载）。

| 类别 | 驱动（CONFIG 前缀省略） | 现状 | 判定依据 |
|---|---|---|---|
| 必须=y | ARCH_QCOM、QCOM_SCM、Pinctrl MSM/QCOM_SPMI_PMIC、Serial MSM + GENI console、SPMI_MSM_PMIC_ARB、QCOM_WDT、RPMH/SMD_RPM regulator、COMMON_CLK_QCOM（GCC/GPUCC/DISPCC 8750 系）、INTERCONNECT_QCOM_SM8750、ARM_SMMU_QCOM、PDC/MPM、QCOM_SMEM/SMP2P/GLINK、USB_DWC3_QCOM、SDHCI_MSM + MMC_QCOM_DML、UFS_QCOM、PHY_QCOM_QMP_UFS/USB、PWRSEQ_QCOM_WCN、QCOM_RPMHPD/RPMPD | =y | 挂根（UFS/emmc）、串口 console、genpd/clock/interconnect 骨架、冷启链路。模块化任何一个都会让 rootfs/调试通道失效 |
| 可=m（早期：init 里 modprobe，模块随持久根 /lib/modules） | **ATH12K**（WCN7861 WiFi）、SND_SOC_QDSP6 + WCD939X/SDW + LPASS 宏（音频）、SoundWire_QCOM、QCOM_PD_MAPPER 依赖链 | =y（ATH12K=debug 也=y） | 启动中期要 WiFi/音频；`fragment-modular.config` 已覆盖，模块放持久根，init/系统服务加载（camera-modules-load.sh 同机制） |
| 可=m（rootfs 按需） | **VIDEO_QCOM_CAMSS/IRIS/VENUS、I2C_QCOM_CCI、相机 sensor（S5KJNS 等）**（已是 =m）、INPUT_AW86927/触觉、TOUCHSCREEN_NOVATEK_NVT36XXX_SPI、BACKLIGHT_AW99706、QCOM_PMIC_GLINK（电池/USB Type-C 事件，可后置但建议留 y）、QCOM_LMH/TSENS（热）| =m / =y | 桌面起来后 udev 自动 modprobe；触屏/haptics/backlight 已进 fragment-modular.config。QCOM_LMH 等热/电安全链建议保守留 y |
| **不建议模块化（Q28 敏感）** | DRM_MSM + MDSS/DPU、DSI host/PHY、DRM_PANEL_NOVATEK_NT36536 | =y | Q28 面板开机首次 modeset 间歇失败（13 boot 8 失败，见 `research-q28-dpu-powerup-race-2026-10-09.md`）。模块化显示会让首次 modeset 推迟到 modprobe 时刻，**可能掩盖也可能加剧竞态**，且「无显示=看似砖」、RAM-only 变体失效。`fragment-modular-video.config` 已实测可翻转，但明确标注回退风险，**Q28 根因定性前不采纳** |
| 天然=m（非 elden，上游 defconfig 遗产） | 其它 SoC 的 eth/wifi/drm/can/sca/crypto…（1319 项 =m 的绝大多数） | =m | 已是模块，不占 boot 镜像体积，只是 rootfs /lib/modules 变大 |

## 2. 体积预估

- boot.img 组成：Image.gz 20.5 MB + DTB ~0.2 MB + ramdisk（rootfs 62–81 MB 主导）。
- **=y→=m 对 Image.gz 的节省极小**：boot 大头是 ramdisk；内核 text 中 QCOM 平台骨架占的份额有限，估算把全部「可=m」组（WiFi+音频+触控+haptics）翻 =m 只省 **~1–2 MB Image.gz**（gzip 后更少）。
- **反方向成本**：模块进 rootfs ramdisk（overlaid cpio）会加体积；ATH12K firmware 必须在 initramfs 可达（slim initramfs 已证伪：无 /lib/firmware → 外设全废 ⇒ **模块化必须绑定完整/rootfs ramdisk，永不用 slim**）。
- 结论：**模块化在体积上无实质收益**（96 MiB 上限余量 10.7 MB，瓶颈在 ramdisk，不在内核）。
- kexec 快环：kexec_file_load 用**未压缩 Image**（`scripts/kexec-boot.sh`），内核=整段常驻 RAM；=m 模块不进 kexec 载荷，**对 kexec 内存足迹无收益**。真正的 kexec 意义是 `device_shutdown` 整段跳过（已证可行）——这与 =y/=m 无关。唯一间接收益：非骨架驱动模块化后，新内核快环上**模块与内核版本解耦**的风险上升（vermagic 必须一致），反而增加快环约束。
- Q28 影响：见 §3。

## 3. 关联分析（收益点不在体积，在迭代与上游化）

1. **迭代速度（最大收益）**：=y 驱动每次改动 = 重编 Image + 重打 boot + fastboot/reboot（~10–20 min）；=m 走 `mod-loop.sh` ~30 s。ATH12K/WCD939X/QDSP6/触屏（Q26 WiFi、音频、触觉排障高频区）已入 fragment-modular.config，收益已兑现一半。
2. **Q28**：显示栈保持 =y 是正确决定。模块化显示把首次 modeset 从「内核 init」移到「用户态 modprobe」，时序完全改变——Q28 竞态（ABL 遗留态/`clk_ignore_unused` 孤儿时钟/genpd 初值）尚未定性，先动时序会污染取证。**Q28 根因收窄并修复后，模块化显示可作为单独 A/B 实验**，且可能反而成为 Q28 的变参实验手段（不是修复手段）。
3. **上游化**：=y/=m 不影响补丁质量；但模块化让「改动仅触一个驱动」的验证面收窄，checkpatch/dtbs_check 流程更快。
4. **kexec 快环**：模块化无正收益；且 kexec 进新内核后需确认 /lib/modules 与新内核 release 匹配（mod-loop 已有 KV 比对，快环脚本尚未有）。

## 4. 最小改动最大收益路径（实施步骤）

1. **采纳（已完成大半，收尾）**：应用 `patches/fragment-modular.config`（ATH12K、QDSP6/WCD939X、NVT36XXX 触屏、AW86927/AW99706）→ `build-kernel.sh full && build-boot.sh`；音频/ATH12K 模块放持久根 /lib/modules，由系统服务/init 加载（camera-modules-load.sh 范式）。验证：boot 后 `lsmod` 全到、WiFi 关联、音频出声、触屏可用。
2. **白名单再加一批低风险按需项**（进 rootfs 按需加载）：`QCOM_FASTRPC`（若用户态 hexagon 用到再加载）、`VIDEO_QCOM_*` 已 =m、`BT_QCA` 不动（BT_HCIUART_QCA=bool 会 select 回 =y，`fragment-modular.config` 已注明；热改需 tristate 源码微补丁，**不做**，除非 BT 排障高频）。
3. **不做**：平台骨架/挂根/显示栈模块化；slim initramfs 路线（已证伪）；`DRM_MSM=m`（Q28 定性前冻结）。
4. **可选 A/B（Q28 之后）**：`fragment-modular-video.config` 单变量实验，持久根 + init 里显式 modprobe 显示栈；预期收益只是显示驱动 30s 迭代环，不作为默认配置。
5. **守护项**：`build-kernel.sh` 的 `CONFIG_ARCH_QCOM` guard 保留；mod-loop 的 KV 比对保留；kexec 快环脚本加 /lib/modules 版本校验。

## 5. 结论

- 模块化的收益是**迭代速度（30s 热载 vs 10–20 min 全量重建）**，不是 boot 体积（节省 ~1–2 MB / 96 MiB 上限）也不是 kexec（无内存收益，反而引入版本耦合）。
- 当前最优配置 = fragment-modular.config 已覆盖的「载荷驱动」=m + 全部平台骨架与显示栈 =y；显示栈在 Q28 定性前冻结为 =y。
