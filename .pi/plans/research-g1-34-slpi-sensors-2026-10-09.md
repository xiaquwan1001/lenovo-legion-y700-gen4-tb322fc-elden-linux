# 专题 G1-34：加速度计/重力传感器（SLPI 私有 I2C，AP 侧不可见）— 重新取证

> 机型 TB322FC / elden / SM8750P（骁龙 8 Elite 系）。只读调研，未动设备、未改领域文档。日期 2026-10-09。
> 关键更正：旧判定「架构性不可做」很可能被推翻，但要走的路不是 qcom_smgr。

## 结论（≤10行）
1. **qcom_smgr（QRTR-as-bus + Sensor Manager IIO）不适用 SM8750P**。作者与 pmaports 明确：Sensor Manager 只存在于 SSC 时代（MSM8996/8998）与 ADSP 时代（SDM6xx 等）；**SDM845 及以后不再提供 Sensor Manager，改走另一套接口**。
2. 正确路线 = **libssc（Dylan Van Assche）**：经 QRTR 服务 id **400 = sns_client_api_v01**、protobuf-over-QMI 访问 Snapdragon Sensor Core，再经 **iio-sensor-proxy** 暴露 accel/gyro/mag/prox/light/rotv。该栈面向「2018 及以后的 SoC」。
3. 用户态栈已成熟且**已进上游/发行版**：iio-sensor-proxy **3.9（2026-03）内置 SSC 支持**；Debian sid 的 iio-sensor-proxy 依赖 `libssc2 (>=0.4.2) [arm64]`。
4. 真正的拦路虎是 **内核侧把 SLPI 起来**：mainline `qcom_q6v5_pas.c` 只到 `qcom,sm8450-slpi-pas`，**SM8550/SM8650 无 `*-slpi-pas` 匹配项**（仅 adsp/cdsp/mpss）；现代芯片 SLPI 上电改由 **pd-mapper + subsmgr/PDR** 管，且仍在按 SoC 补映射。hypervisor 锁死传感器 I2C/GPIO，AP 侧 bit-bang 后备方案不可用。
5. 结论：判定应改为 **「架构上可做、但被 SM8550+ SLPI 上电这一内核前置卡住」**；先把 SLPI 跑起来 + QRTR 解析出 svc 400，是能否推进的唯一分水岭。

## 证据（每条带可核对 URL）
1. **Sensor Manager 仅 SSC/ADSP 时代；SDM845+ 不用它**。来源(LKML/pmaports，直接证据)：https://lwn.net/Articles/1029453/ ；https://gitlab.com/postmarketOS/pmaports/-/merge_requests/4118 （原文："SDM845 and later don't provide Sensor Manager, opting for an entirely different interface instead"）。置信度：高。
2. **qcom_smgr IIO 驱动本身**（v2, 2025-07，作者 Yassine Oudjana；覆盖 accel/gyro/mag/prox/pressure；截至取证时仍在评审、未进 mainline）。来源：https://patchew.org/linux/20250710-qcom-smgr-v2-0-f6e198b7aa8e@protonmail.com/ 。置信度：高（与本机 7.2 树缺该驱动一致）。
3. **libssc = 现代 SoC 正确接口**；支持 accel/mag/prox/light/rotv；依赖 libqmi≥1.33.4 + protobuf-c；经 AF_QIPCRTR。来源：https://libssc.dylanvanassche.be/docs/ ；仓库 https://codeberg.org/DylanVanAssche/libssc 。置信度：高。
4. **QRTR svc 400 = sns_client_api_v01**；前置= CONFIG_QRTR、SLPI 固件已加载、pd-mapper 运行、qrtr-ns 运行。来源(直接)：https://docs.rs/sensorbox-ssc/latest/sensorbox_ssc/ 。置信度：高。
5. **SDM845（libssc 路线）在 postmarketOS 已跑通并合入**（自动旋转/亮度/接近/罗盘），mount-matrix 走 udev。来源：https://gitlab.com/postmarketOS/pmaports/-/merge_requests/4050 （2023-12 合并）。置信度：高（但为 SDM845，非 SM8x 系，外推需谨慎）。
6. **iio-sensor-proxy 3.9 上游已含 SSC 支持；Debian 打包 libssc2[arm64]**。来源：https://tracker.debian.org/media/packages/i/iio-sensor-proxy/changelog-3.9-1 ；https://packages.debian.org/sid/iio-sensor-proxy 。置信度：高。**注意**：3.8-1.ssc0 记录「在 udev 规则中暂时禁用 SSC 的 accel 与 proximity，因其存在问题」——accel 走 SSC 仍有坑，置信度：中。
7. **上游 SLPI 上电断点在 SM8450 之后**。`qcom_q6v5_pas.c` 匹配表含 `qcom,sm8450-slpi-pas`，但 SM8550/SM8650 仅有 adsp/cdsp/mpss。来源(直接读源码)：https://github.com/torvalds/linux/blob/master/drivers/remoteproc/qcom_q6v5_pas.c ；SM8550 remoteproc 系列范围仅 adsp/cdsp/mpss：https://lwn.net/Articles/916349/ 。置信度：高。
8. **现代 SLPI PD 由 pd-mapper 管、仍在补**。来源：https://ratatoskr.run/lkml/2026/01/3394076/t （[PATCH v2] arm64: qcom: pd-mapper 增补，2026-03）。置信度：中高。
9. **hypervisor 禁止 AP 直接访问传感器**。来源(直接)：https://libssc.dylanvanassche.be/ 。置信度：高。
10. **registry 格式**：`/vendor/etc/sensors/sensor_def_qcomdev.conf`（明文 KV）→ 专有 `sensors.qti` 生成 `/persist/sensors/sns.reg`（二进制）；sns-reg 仓库有「二进制→明文」反向生成器。来源(直接)：https://gitlab.com/postmarketOS/pmaports/-/merge_requests/4118 ；https://gitlab.com/msm8996-mainline/sns-reg 。置信度：高。

## 候选路线/修复假设（按代价×把握排序）
- **R1（首选·中代价/中高把握）libssc 路线**：上游/自建树起 SLPI（补 SM8750 的 SLPI 上电）+ qrtr/qrtr-ns + libqmi(QRTR-only) + libssc + iio-sensor-proxy。把握来自 SDM845 已跑通 + iio-sensor-proxy 3.9 上游化；风险全压在「SM8750 SLPI 能否上电」。**推翻「架构性不可做」**。
- **R2（探路·低代价/不定把握）先取证不写码**：boot stock/CAF 内核，跑 `qrtr-lookup`/`qrtr-ns`，看 svc **400** 是否出现、能否 `ssccli accel`。这是判定 R1 可行性的最便宜分水岭。
- **R3（备胎·中代价/低把握）pd-mapper/subsmgr 路线**：走现代 PD 上电（pdr/subsmgr + qcom,pdm）载 SLPI 固件，而非 per-subsystem PAS。上游对 SM8550+ 仍不完整，工作量大。
- **R4（不适用）qcom_smgr / AP bit-bang**：qcom_smgr 只覆盖 SSC/ADSP 时代，SDM845+ 无 Sensor Manager；且 hypervisor 锁 I2C。**排除**。
- **R5（兜底·低代价/低价值）**：若仅需屏幕旋转，可用软件兜底（固定横屏/手动），不解决「功能完整」目标，仅为止痛。

## 落地步骤（取证 → 决策 → bring-up）
1. **器件确认（不改设备，读 stock）**：列 `/vendor/etc/sensors/config/`，看 JSON 文件名（`lsm6dso*.json` vs `icm4x6xx*.json`/`icm4x6xx_0.json`）——现代机型传感器配置已迁到按型号命名的 JSON，这是判 lsm6dso vs icm4x6xa 的最直接指纹；辅以 `/vendor/etc/sensors/sensor_def_qcomdev.conf`、`/persist/sensors/sns.reg`、下游 DTSI 中 SLPI(GPI/I2C) 段与 SLPI 自带 dtb。
2. **本机 blob 盘点**（我无 shell 工具，需父进程执行）：在 `archive/ stock-src/ backup/ mu_wide_platforms/` 下 `find` 是否存在 `slpi.mdt/bb`、`sensors/qcom,*sensors*.json`、`sns.reg`、`sensors.qti`，以及 SLPI 的 `*.dtb`/`sscrpcd`。
3. **可行性分水岭（R2）**：临时 boot 一个能起 SLPI 的内核（或 stock），`qrtr-lookup | grep 400`；出现即验证 libssc 路线，`ssccli accel` 直接看数。
4. **内核 bring-up**：确认 SM8750 SLPI 上电机制（PAS 还是 pd-mapper/subsmgr）；从 stock DT 取正确 PD 号/PAS id/时钟/电源域，落到 `qcom_q6v5_pas.c` 或 pd-mapper 映射；确保 CONFIG_QRTR、qrtr-ns、rmtfs、pd-mapper 就绪。
5. **registry/标定**：把 stock `sensor_def_qcomdev.conf`/JSON/`sns.reg` + 标定数据放到 libssc/sns-reg 期望路径。
6. **挂载矩阵**：按 elden 装姿写 `ACCEL_MOUNT_MATRIX` udev 规则（参照 axolotl `81-libssc-*.rules`）。
7. **桌面侧**：iio-sensor-proxy 3.9 + libssc2，`monitor-sensor` / `ssccli` 验收。

## 风险与未证实点
- **最大风险**：SM8550+（含 SM8750）SLPI 上电无现成 mainline 路径；若 hypervisor/PAS 认证拒绝加载我们提供的 SLPI 固件，整条线止步。未证实。
- **accel 走 SSC 的已知坑**：Debian 3.8 曾因「问题」在 udev 里禁用 SSC accel/prox；3.9 是否对 accel 完全修好未证实。
- **JSON registry 细节**：现代机型用 JSON（`/vendor/etc/sensors/config/*.json`）而非 `.conf`，libssc/sns-reg 主要按 `.conf`/`sns.reg` 取证——JSON→registry 的喂法需实测（属研究推断）。
- **器件身份未定**：lsm6dso vs icm4x6xa 尚未从 stock 证实（WHO_AM_I：lsm6dso=0x6C、icm-4x6xx≈0x09 属数据手册常识，作推断）。
- **矛盾/取舍**：qcom_smgr 作者把 SLPI 归到「SSC」类，但 pmaports !4050 与 libssc 又把 SDM845+ 的同一 SLPI 硬件用完全不同的 protobuf(sns_client) 接口暴露——两代接口不可互换，须认准 sns_client。
- **工具限制**：本会话无 shell/ls/find/glob，无法完成本机 blob 盘点（见步骤 2），仅凭 web 取证。

## 需父进程在设备上验证的项
1. stock 下 `ls /vendor/etc/sensors/config/` 与 `/vendor/etc/sensors/`、`/persist/sensors/`——确认器件（JSON 文件名判 lsm6dso / icm4x6xa）与是否有 `sns.reg`/标定。
2. 本机仓库 `find archive stock-src backup mu_wide_platforms -iname '*slpi*' -o -iname 'sns.reg' -o -iname '*sensors*.json'`——确认 SLPI 固件与 registry/标定是否已在手。
3. 起一个能加载 SLPI 的内核后：`qrtr-lookup`（服务 400 是否出现）、`qrtr-ns` 是否在跑、`remoteproc` 是否列出 SLPI、`pd-mapper`/`subsmgr` 状态。
4. stock DT/dtsi 里 SLPI 节点的 compatible、pas-id、PD/时钟、GPI/I2C 控制器与 GPIO 归属，用于判定走 PAS 还是 pd-mapper。
5. elden 屏幕装姿（供 mount-matrix）。
