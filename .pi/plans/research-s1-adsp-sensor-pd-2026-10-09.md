# Research S1 — ADSP sensor PD（SSC/sns）如何被加载（elden / SM8750P）

> 调研 2026-10-09。只读：未动设备/未刷机/未改码/未改领域文档。全中文 ≤160 行。
> 关键纠正：让 sensor_pd「起来」的是 **FastRPC**，不是 pd-mapper/PDR 本身。

## 结论（≤10行）
1. 现代骁龙 SM8550/8650/**8750** 的传感器 PD（SSC/sns）都在 **ADSP 内**，加载/点亮机制 = **FastRPC**：内核 `drivers/misc/fastrpc.c`（`CONFIG_QCOM_FASTRPC`）为 sensor PD 注册 PDR 句柄 `sensors_pdr_adsp`→`msm/adsp/sensor_pd`；真正把 PD 拉起来的是 **FastRPC 用户态 `adsprpcd` 服务 "sensorspd"**。
2. **pd-mapper/PDR 只是「定位器/登记器」**（servreg，QRTR svc **66 / 0x42**），宣告「哪个 PD 承载哪个服务」，**不点亮 PD**。内核 `qcom_pd_mapper.c` 已把 `qcom,sm8750`/`sm8650`/`sm8550` → `sm8550_domains`，**该表含 `adsp_sensor_pd`**（`msm/adsp/sensor_pd`,instance 74）。
3. 故「PDR 只见 charger_pd/audio_pd、无 sensor_pd」根因大概率 = **ADSP 侧 FastRPC 未起来**：SM8750 的 ADSP fastrpc DT 支持 2026-01 才提交（RFT），且 qualcomm/fastrpc#146 记录 SM8750 上 `adsprpcd` 会触发复位；加上本机**没装 `adsprpcd` 用户态**、无 odm `json.lst` 供给 PD。
4. elden 内核侧已具备 `CONFIG_QCOM_FASTRPC=m`、`CONFIG_QCOM_RMTFS_MEM=m`；缺 **ADSP fastrpc glink-edge 节点 + reserved DMA**（若 DT 未带）与 **`adsprpcd`(sensorspd) + odm json.lst + persist registry**（后者项目已提取 pakala_* 全套）。
5. 同 SoC（SM8750）先例：piano-sensors（小米平板8 Pro）**已在主线跑通** accel/ALS/prox/compass，配方即 fastrpc→adsprpcd(sensorspd)→libssc→iio-sensor-proxy。

## 证据（带可核对 URL）
1. **内核 pd-mapper 表（master 源，直接证据，高）**：`qcom,sm8750`→`sm8550_domains`；`sm8550_domains[]={adsp_audio_pd,adsp_root_pd,adsp_charger_pd,adsp_sensor_pd,cdsp_root_pd,mpss_root_pd_gps}`；`adsp_sensor_pd={domain:"msm/adsp/sensor_pd",instance_id:74}`。对照：`qcom,sm8450`→`sm8350_domains`（仍用 `slpi_sensor_pd`），`x1e80100` 亦含 `adsp_sensor_pd`。in-kernel pd-mapper 靠 **机器根 compatible** `of_machine_get_match` 命中。
   https://raw.githubusercontent.com/torvalds/linux/master/drivers/soc/qcom/qcom_pd_mapper.c
2. **PD 映射来源 = 随 ADSP 出货的 jsn（直接证据，高）**：Neil Armstrong 在 pd-mapper v4 评审指出 SM8550 应为 `{audio,sensor,root,charger}`，「因为 SLPI 已并入 ADSP，且 root_pd 无 pdr_enabled」。
   https://www.mail-archive.com/linux-remoteproc@vger.kernel.org/msg00317.html
3. **fastrpc 直接跟踪 sensor_pd（直接证据，高）**：内核日志 `qcom,fastrpc …glink-edge.fastrpcglink-apps-dsp… fastrpc_pdr_cb: msm/adsp/sensor_pd (sensors_pdr_adsp) is up for PDR on adsp`。即 sensor_pd 的「出现在 PDR」由 fastrpc 驱动 + PD 真起来共同决定。
   https://mysupport.qualcomm.com/supportforums/s/question/0D5dK00000C3hd1SAB/no-reserved-dma-memory-for-fastrpc
4. **同 SoC 配方（直接证据，高）**：piano-sensors README——`fastrpc` 暴露 ADSP，Qualcomm `adsprpcd`（Debian `fastrpc-support`）「serves the sensors protection domain」；**PD 每次 ADSP 启动先读 odm `json.lst`，缺了就放弃（即便 persist registry 有效）**；还需 persist registry/calibration；栈 = fastrpc→adsprpcd→libssc→iio-sensor-proxy；自定义 `adsprpcd-sensorspd` 服务等 PD 发布所有 sensor。
   https://github.com/blu-sharky/piano-sensors
5. **SM8750 ADSP fastrpc 很新且有坑（直接+解读，中高）**：`[RFT PATCH v3] Adsp fastrpc support for sm8750`（2026-01，测试有 fail，作者称 adsprpcd 在 audio_pd 可用）；`qualcomm/fastrpc#146`：SM8750 上 `adsprpcd`+audiopd 域导致复位、需改非安全 `/dev/fastrpc-adsp-secure` 并去 rpcmem/dmabuf。
   https://ratatoskr.run/linux-arm-msm/2025-12-3328168/t ｜ https://github.com/qualcomm/fastrpc/issues/146
6. **机制背景（直接证据，高）**：emainline《Unlocking SSC P1》给出 `qrtr-lookup` 视图：svc **66 = Service registry notification（servreg）**；rmtfs 需 `qcom,rmtfs-mem`（client-id 1、vmid 15）保留区；sns 数据经 QRTR。libssc 经 `AF_QIPCRTR` 直连 QMI，依赖 libqmi/protobuf-c/qrtr（systemd 需放行 AF_QIPCRTR）。
   https://emainline.gitlab.io/2021/10/06/Unlocking_SSC_P1.html ｜ https://libssc.dylanvanassche.be/docs/
7. **hexagonrpcd 备胎（直接，中）**：SM8450 Galaxy Tab S8+ 用 hexagonrpcd+libssc 在主线出 accel/light/mag；nabu 亦 FastRPC/QRTR→libssc。
   https://github.com/aaronsb/sm-x800-linux/pull/37
8. **本机现状（本地，高）**：`patches/config-vk*`：`CONFIG_QCOM_FASTRPC=m`、`CONFIG_QCOM_RMTFS_MEM=m`；已提取 `backup/stock-elden/vendor-etc-sensors/sensors/`（139 JSON + `json.lst` + `sns_reg_config`，族 `pakala_*`）；`sm8750-lenovo-elden.dts` 有 reserved-memory（未见 ADSP fastrpc 子节点记录）。

## 候选路线（代价×把握排序）
- **R1 主线 FastRPC（piano 同款，SM8750 已证）— 代价中，把握高**：补 ADSP fastrpc DT 节点+DMA → 装 `adsprpcd`(fastrpc-support/libfastrpc1) 跑 sensorspd → 供 odm json.lst + persist registry → libssc/ssccli → iio-sensor-proxy。最贴合本机 SoC。
- **R2 社区 hexagonrpcd — 代价中，把握中**：若 stock `adsprpcd` 在 SM8750P 复位/签名/hyp 受限（#146），改 hexagonrpcd 提供 sensor PD。
- **R3 只补定位器（内核/用户态 pd-mapper + rmtfs）— 代价低，把握低（仅作辅助）**：不点亮 PD，单靠它出不了 sensor_pd/svc400。
- **误判纠正**：既有计划「起 pd-mapper 就出现 svc400」把「定位器」当「加载器」；pd-mapper 只负责让 PDR/QMI 客户端**找到** sns，不拉起 PD。

## 落地步骤
1. **设备核对 ADSP fastrpc（分水岭）**：`ls /dev/fastrpc-adsp*`；`dmesg|grep -iE 'fastrpc|sensor_pd|sensors_pdr'`；查 `/proc/device-tree/**/remoteproc@*/glink-edge/**fastrpcglink-apps-dsp` 是否存在；`/dev/dma_heap` 有无 fastrpc/sensor 用 DMA。缺节点 → 回合 arm-msm 的 SM8750 ADSP fastrpc 补丁 + reserved DMA。
2. **装用户态**：`fastrpc-support`/`libfastrpc1`（Debian trixie-backports contrib 1.0.7）、`libssc`、`iio-sensor-proxy 3.9`、`qrtr`、`libqmi`；参考 piano 的 `adsprpcd-sensorspd` 服务 + mount-matrix udev。
3. **喂 PD 输入**：把 pakala_* odm `json.lst` 及其列出的 JSON 放到 PD 询问路径；persist registry/calibration 以只读副本挂载（ADSP 写副本）。
4. **验证链**：`qrtr-lookup|grep -E '66|400'`（66=servreg，400=sns_client）→ `ssccli accel` 出数 → `monitor-sensor` → Phosh 自动旋转。
5. **失败兜底**：`/dev/fastrpc-adsp-secure`→非安全、去 rpcmem/dmabuf（#146）；或切 R2 hexagonrpcd。把与旧计划差异回写 S2/父核验。

## 风险与未证实点
- SM8750 ADSP fastrpc 主线化很新（2026-01 RFT 有测试失败）；adsprpcd+audiopd 触发复位（#146）。本机为 SM8750**P** 且可能带 Gunyah/额外签名，secure PD 或更受限。
- sensor PD 究竟走 **rmtfs-QMI 还是纯 FastRPC 文件服务**：piano 用 FastRPC 文件路径 + persist 副本、未强调 rmtfs 守护；本机 RMTFS_MEM=m 但 rmtfs 守护未装 → rmtfs 可能非必需。**未证实**。
- 「PDR 只见 charger/audio」三种可能（缺 ADSP fastrpc 节点 / 缺 adsprpcd / 缺 json.lst）**未区分**，需设备 dmesg/DT 定论。
- svc 号（66/400）与 instance(74) 沿用文献，未在 elden 实测。
- 工具限制：本会话 **`source_check` 未注册**，改用直接抓源核对（已抓 master 内核源文件 / piano README / pd-mapper 评审邮件 / SSC 博客）。

## 需父进程在设备上验证的项
1. `dmesg | grep -iE 'fastrpc|sensor_pd|sensors_pdr|pd.mapper|PD mapper'`：是否见 `fastrpcglink-apps-dsp`、`msm/adsp/sensor_pd … up for PDR`、内核 pd-mapper 是否报 `no support for the platform`。
2. `/proc/device-tree/**/remoteproc@**/glink-edge/**` 下有无 ADSP fastrpc 子节点；`/dev/fastrpc-adsp*` 是否存在。
3. 顶层 `/proc/device-tree/compatible` 是否含 `qcom,sm8750`（in-kernel pd-mapper 命中依赖）。
4. `/dev/dma_heap` 与 reserved-memory：是否给 fastrpc/sensor PD 预留 DMA；`rmtfs_mem` 是否存在。
5. 交叉编译 `qrtr-lookup` 拉全表，看 66（servreg）/400（sns_client）当前是否已在。

## Sources
- Kept：torvalds/linux `qcom_pd_mapper.c`（master，pd 表权威）；piano-sensors README（同 SoC 配方）；msg00317（jsn→表来源）；qualcomm#146 与 RFT sm8750 fastrpc（风险）；emainline SSC P1 + libssc docs（机制）；sm-x800 PR#37（hexagonrpcd 备胎）。
- Rejected/deprioritized：postmarketOS 包页/Debian ITP（仅证软件存在，非机制）；ST MEMS HAL 论坛、MX Linux 论坛（与本主线栈无关/噪声）。

## Next steps
- 回合/确认 SM8750 ADSP fastrpc DT（arm-msm 2025-12~2026-01 系列）在 elden 基线是否已在；
- 取 piano 的 `adsprpcd-sensorspd` unit + mount-matrix 规则，映射到 pakala_* registry；
- 与 S2 对齐：libssc/iio-sensor-proxy/qrtr 的 Alpine aarch64 包与 `AF_QIPCRTR` 放行。
