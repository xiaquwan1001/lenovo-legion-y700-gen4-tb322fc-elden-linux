# 驱动上游化审计 — SM8750 / vk189（2026-11-27）

lane：`driver-upstream-audit`　边界：**纯主机侧**。设备只做只读 ssh（192.168.7.1，在机 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`）；未编译、未刷机、未 reboot、未改设备文件、未 commit。
唯一写入 = 本文件。

**证据源（三路，都可复核）**

1. **主线** = `https://git.kernel.org/.../torvalds/linux.git/plain/<path>`（本日抓取，HTTP 码 + 行号见下；下称「master」）。
2. **仓内构建树** `build/daily` = 生成设备内核的树（Linux 7.3.1 + payload，HEAD `4da9a8b69fc85`）。
3. **设备实况** = `/sys/firmware/devicetree/base`（DT 属性）+ `/sys/bus/platform|i2c`（绑定态）+ `dmesg` + `/proc/config.gz` + `/lib/firmware`。

> 注意：`build/daily` **不是** pristine 主线（它自带 payload 提交，如 `elden payload v2`），因此凡「在主线」结论一律以 **master 抓取的 HTTP 200 + 行号** 为准，`build/daily` 只用于「我们树里有什么」。

---

## 0. 一页结论表

### 0.1 DT 里 `status = "disabled"` 的 5 个节点（设备已逐节点 `cat status` 复核）

| 项 | 主线现状 | 绑定缺什么 | 能不能开 | 上游化形态 |
|---|---|---|---|---|
| `video-codec@aa00000` `qcom,sm8750-iris` | **在**：`drivers/media/platform/qcom/iris/iris_probe.c:450`；binding `media/qcom,sm8750-iris.yaml` 200 | 不缺驱动、不缺 binding；只缺**板级 `status=okay`**（主线 `sm8750.dtsi:3288` disabled，注释 3284-3287「固件厂商签名，只在有签约固件的板子开」）。固件 `qcom/vpu/vpu35_p4.mbn` **已就位**（设备实测）；TZ 验签未证 | **能开**（一行板级 DTS，工作树已加 `&iris{okay}`）；签名门只能上机 | ①**纯板级 DTS**（先例：主线 `sm8750-mtp.dts:982`、`sm8750-qrd.dts:869` 均已 `&iris`；上飞线程 `[PATCH v4 0/3] sm8750: Add Iris VPU v3.5` 已 Applied，commit `c0d11ff90475`） |
| `remoteproc@4080000` `qcom,sm8750-mpss-pas` | **在**：`drivers/remoteproc/qcom_q6v5_pas.c:1881`（`sm8750_mpss_resource`）+ `:2075` of_match；binding `remoteproc/qcom,sm8550-pas.yaml:28` | 不缺驱动/binding。缺 `modem.mdt` 固件（设备 `/lib/firmware/qcom/sm8750` 96 个文件里**无** `modem.*`/`mba.*`）；且本机 `androidboot.baseband=apq` ⇒ **AP-only SKU** | **不能开（本机无 modem 硬件/固件）**；另上游作者自述「modem 起来后仍崩」（`[PATCH RFC v2]` 2025-02 线程） | ④**不进上游**（无硬件可验，没有板级动作） |
| `soundwire@6ab0000`（swr3/WSA2）、`soundwire@6b10000`（swr0/WSA）`qcom,soundwire-v2.1.0` + `v2.0.0` | **在**：`drivers/soundwire/qcom.c:1911`（`v2.0.0` 回退）；binding `soundwire/qcom,soundwire.yaml:30/32` 列 `v2.1.0`+`v2.0.0` | 不缺驱动。缺**下游 codec**：本机 WSA 总线上无 `wsa883x/884x`，喇叭是 I2C 智能功放 `awinic,aw88461`（`i2c-9: 0034/0037`，已 bound）。DT 现状 = 主线 `sm8750.dtsi:2689/2800` disabled | **不能开（无硬件：本板无 WSA 功放）** | ②/①视变体：有 WSA 功放的变体 = **纯板级 DTS**（先例 `sm8750-mtp.dts:1211 &swr0` + `wsa883x`、`glymur-asus…dts:897/925`） |
| `geniqup@9c0000` `qcom,geni-se-i2c-master-hub` | **在**：`drivers/soc/qcom/qcom-geni-se.c:1688` + 子节点驱动 `drivers/i2c/busses/i2c-qcom-geni.c:1374`；binding `soc/qcom/qcom,geni-se.yaml:24` | 不缺驱动/binding。缺**下游设备**：主线 `sm8750.dtsi:1248` disabled，10 个 `i2c@98x` 子节点全 disabled，设备实测同样（无 device 生成） | **不能开（无已知下游设备）** | ①**纯板级 DTS**（将来若有设备才动；主线无任何板子启用它） |

### 0.2 有 of_node、无驱动绑定的平台设备（设备实测 9 个）

| 项 | 主线现状 | 绑定缺什么（设备证据） | 能不能开 | 上游化形态 |
|---|---|---|---|---|
| `3d37000.gmu` `qcom,adreno-gmu-830.1` | **不是独立平台驱动**：主线 GMU 由父 GPU 驱动按子节点消费（`a6xx_gpu.c:2775 a6xx_gmu_init(a6xx_gpu, node)`）；binding `display/msm/gmu.yaml:24` 的 pattern 覆盖 `830.1` | 不是「缺失」——设计如此。**但**我方 DT 与主线不一致：主线 `sm8750.dtsi:2367 gmu@3d6c000 reg 0x32000`，我方 `build/daily:3914 / live-fdt:3914 gmu@3d37000 reg 0x68000` | **已在工作**（dmesg：`Loaded GMU firmware v5.1.25`、`Initialized msm 1.13.0`）。地址差异**未证实**是否等价 → 见 §3 动作 3 | ①**板级/SoC DTS 对齐**（先核对再决定；不影响功能则无需动作） |
| `ad27000.isp` `qcom,sm8750-camss` | **未在主线**：master `camss/camss.c` 里 `sm8750` 命中 **0**；binding `media/qcom,sm8750-camss.yaml` **404**；我方 `build/daily camss.c:6136` | 缺模块加载：CONFIG_VIDEO_QCOM_CAMSS=m 但 `qcom_camss` **不在 lsmod**、`/sys/bus/platform/drivers` 无该驱动 | **能开**（加载 `qcom_camss`；模块已完成、`modules.alias:9076` 有 `qcom,sm8750-camss` 别名；还有 `modules.alias` 缺 coldplug 的时间差） | ②**驱动补丁系列（在飞）**：我方 `m4-camss-v2-20261031`（patchwork linux-media state=`new`）；另有 Hangxiang `[PATCH v5 0/5] camss: Add SM8750 support`、`[PATCH v2 0/3] Add CCI and CAMSS support for SM8750`（2026-06/08） |
| `ac7b000.cci` / `ac7c000.cci` `qcom,sm8750-cci`, `qcom,msm8996-cci` | **驱动在**（回退匹配 `i2c-qcom-cci.c:861`）；binding `i2c/qcom,i2c-cci.yaml:46/144` 已列 `sm8750-cci`；master `sm8750.dtsi` **无 cci 节点**（属在飞系列） | 缺模块加载：`qcom_cci` 不在 lsmod；且上游 supplier `ade0000.clock-controller`(camcc) 也没加载 | **能开**（先 `camcc-sm8750` 再 `qcom_cci`；板级 DT 已 enable 且挂了 `camera@56`、`camera@31` 两个 sensor） | ②**纯板级 DTS 已被系列覆盖**（binding 已合入；DT 节点随我方 camss/cci 系列进树上） |
| `ade0000.clock-controller` `qcom,sm8750-camcc` | **在**：master `drivers/clk/qcom/camcc-sm8750.c`（200，2709 行）；binding `clock/qcom,sm8450-camcc.yaml:37` | 缺模块加载：CONFIG_SM_CAMCC_8750=m，`camcc-sm8750.ko` 在盘上（`modules.dep:235`）但 **未加载** | **能开**（`modprobe camcc-sm8750`，或按 `arch/arm64/configs/qcom-camera.config` 重编为 `=y`） | ——已在主线；**零驱动工作量** |
| `1760000.clock-controller` `qcom,sm8750-cambistmclkcc` | **在**：master `drivers/clk/qcom/cambistmclkcc-sm8750.c`（200）；与 camcc 同模块（`build/daily clk/qcom/Makefile:167 obj-$(CONFIG_SM_CAMCC_8750) += cambistmclkcc-sm8750.o camcc-sm8750.o`） | 同上（同模块未加载） | **能开**（同上，加载 camcc-sm8750 一并注册） | ——已在主线；**零工作量** |
| `10001000.ctcu` `qcom,sm8750-ctcu`, `qcom,sa8775p-ctcu` | **在**：`coresight-ctcu-core.c:295`（`sa8775p` 回退）；binding `arm/qcom,coresight-ctcu.yaml:36` 已列 `sm8750-ctcu`；主线 `sm8750.dtsi:4431` 节点 okay | 纯配置：`# CONFIG_CORESIGHT_CTCU is not set`（设备 `/proc/config.gz`） | **能开**（`CONFIG_CORESIGHT_CTCU=y`） | ——已在主线（binding+DT 由 Jie Gan `[PATCH v3 0/3] Enable CTCU and ETR for …` 合入）；零工作量 |
| `10c3000.rng` `qcom,sm8750-trng`, `qcom,trng` | **在**：`drivers/char/hw_random/qcom-rng.c:153`（`qcom,trng`）；binding `crypto/qcom,prng.yaml:38`；主线 `sm8750.dtsi:2060` 节点 okay | 纯配置：`# CONFIG_HW_RANDOM_QCOM is not set` | **能开**（`CONFIG_HW_RANDOM_QCOM=y`；驱动未加载所以 `waiting_for_supplier`） | ——已在主线（binding 2025 起即列）；零工作量 |
| `1dfa000.crypto` `qcom,sm8750-qce`, `qcom,sm8150-qce`, `qcom,qce` | **在**：`drivers/crypto/qce/core.c:335`（`qcom,qce`）；binding `crypto/qcom-qce.yaml:64`；主线 `sm8750.dtsi:2165` 节点 okay | 纯配置：`CONFIG_CRYPTO_DEV_QCE` **未设**（`drivers/crypto/Kconfig:529` 有此符号，设备 config 无） | **能开**（`CONFIG_CRYPTO_DEV_QCE=y` + `cryptobam` DMA；`dmesg: interconnect sync_state pending due to 1dfa000.crypto` 正是「设备在、驱动不在」） | ——已在主线（binding 由 Melody Olvera `[PATCH 0/6]…crypto support for SM8750` 合入）；零工作量 |

> 合计 5 + 9 = 14 个 DT 侧对象，覆盖派工单列的 17 项（camss 一族按 5 个物理节点拆开，`ac7*` 两条 CCI 单列）。

---

## 1. 复核命令（照抄可跑）

```sh
# A. 主线（每项一条，200=在，404=不在）
B=https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain
curl -s -o /dev/null -w '%{http_code}\n' $B/drivers/media/platform/qcom/iris/iris_probe.c
curl -s $B/drivers/media/platform/qcom/iris/iris_probe.c | grep -n '"qcom,sm8750-iris"'        # 450
curl -s $B/drivers/remoteproc/qcom_q6v5_pas.c      | grep -n 'sm8750_mpss_resource'            # 1881 / 2075
curl -s $B/drivers/soundwire/qcom.c                | grep -n 'soundwire-v2\.0\.0'               # 1911
curl -s $B/drivers/soc/qcom/qcom-geni-se.c         | grep -n 'i2c-master-hub'                   # 1688
curl -s $B/drivers/i2c/busses/i2c-qcom-geni.c      | grep -n 'geni-i2c-master-hub'              # 1374
curl -s $B/drivers/char/hw_random/qcom-rng.c       | grep -n 'qcom,trng'                        # 153
curl -s $B/drivers/crypto/qce/core.c               | grep -n 'compatible = "qcom,qce"'          # 335
curl -s $B/drivers/i2c/busses/i2c-qcom-cci.c       | grep -n 'msm8996-cci'                      # 861（无 sm8750，靠回退）
curl -s $B/drivers/hwtracing/coresight/coresight-ctcu-core.c | grep -n 'sa8775p-ctcu'          # 295
curl -s -o /dev/null -w '%{http_code}\n' $B/drivers/media/platform/qcom/camss/camss.c           # 200 但 sm8750 命中 0
curl -s -o /dev/null -w '%{http_code}\n' $B/Documentation/devicetree/bindings/media/qcom,sm8750-camss.yaml  # 404
curl -s $B/arch/arm64/boot/dts/qcom/sm8750.dtsi | grep -n 'gmu@3d6c000\|video-codec@aa00000\|remoteproc@4080000\|soundwire@6ab0000\|soundwire@6b10000\|geniqup@9c0000'

# B. 设备（只读）
ssh elden 'for n in video-codec@aa00000 remoteproc@4080000 soundwire@6ab0000 soundwire@6b10000 geniqup@9c0000; do echo -n "$n "; cat /sys/firmware/devicetree/base/soc@0/$n/status; done'
ssh elden 'lsmod | grep -E "camcc|camss|cci|qce|ctcu|iris"'          # 只有 qcom_iris
ssh elden 'dmesg | grep -iE "gmu firmware|Initialized msm|sync_state.*pending|soundwire|wsa_macro"'
ssh elden 'zcat /proc/config.gz | grep -E "HW_RANDOM_QCOM|CORESIGHT_CTCU|CRYPTO_DEV_QCE|SM_CAMCC_8750"'
ssh elden 'ls /lib/firmware/qcom/vpu/; ls /lib/firmware/qcom/sm8750 | grep -E "^(modem|mba)"; cat /proc/cmdline | tr " " "\n" | grep baseband'
```

**关键数字（本日实测）**：master 抓取 11 个驱动/绑定文件全部 200（`sm8750-camss.yaml` 404）；`build/daily`/设备 config 里 `HW_RANDOM_QCOM`、`CORESIGHT_CTCU`、`CRYPTO_DEV_QCE` 三项 **not set**；`SM_CAMCC_8750=m`、`VIDEO_QCOM_CAMSS=m`、`I2C_QCOM_CCI=m`；设备 lsmod 中相机/密码学/跟踪 **0 个**模块；`/lib/firmware/qcom/sm8750` 96 文件（有 adsp/cdsp，无 modem）；`/lib/firmware/qcom/vpu/vpu35_p4.mbn` 在位。

---

## 2. 逐项依据（只写「为什么是这个结论」）

### 2.1 iris（硬件视频解码）
- 主线驱动/binding 齐（master 行号见 §1）。**上游已由板级 DTS 打开**：`sm8750-mtp.dts:982 &iris`、`sm8750-qrd.dts:869 &iris`；驱动系列 `[PATCH v4 0/3] arm64: dts: qcom: sm8750: Add Iris VPU v3.5` 已 Applied（`c0d11ff90475` / mtp `10d764c8cb1b`），见 <https://ratatoskr.run/lkml/2026/01/3354247/t>。
- 设备侧：`status=disabled`（模板 `sm8750.dtsi:3288` 带「固件厂签」注释）；`qcom_iris` 模块已加载（176128，refcount 0）但 `/sys/bus/platform/drivers/qcom-iris/` 无 bound 设备；dmesg 无一条 iris。
- 固件：`/lib/firmware/qcom/vpu/vpu35_p4.mbn` 在（= 官方 ROM `vpu35_4v.mbn` 改名，见 `reports/hwdec-iris-sm8750-feasibility-20261127.md` §1）。
- 结论：**纯板级 DTS 即可**；唯一未知门 = PAS ID 9 的 TZ 验签（只能上机）。

### 2.2 mpss（调制解调器）
- 主线 `sm8750_mpss_resource`（`qcom_q6v5_pas.c:1881`，`firmware_name = "modem.mdt"`）与 binding（`qcom,sm8550-pas.yaml:28`）都在；板级先例 `milos-fairphone-fp6.dts` 写 `firmware-name = "qcom/milos/fairphone/fp6/modem.mbn"` + `status=okay`。
- 本机：`/lib/firmware/qcom/sm8750` 里 `modem.*`/`mba.*` **0 个**；cmdline `androidboot.baseband=apq`（APQ = 无 modem 的 SoC 变体）。
- 结论：**不能开**（无硬件/固件）；形态 = 不进上游。

### 2.3 swr0 / swr3（WSA SoundWire）
- 驱动/binding 在（见 §1）。设备上 4 个 SWR 控制器里只有 `6ad0000` 与 `7630000` bound（`qcom-soundwire`）；dmesg `wcd939x_codec … bound sdw:2 / sdw:3`、`wsa_macro 6aa0000/6b00000.codec`（宏单元在跑）。
- 但 WSA 总线上**没有任何 `wsa883x/884x` codec**，喇叭由 `awinic,aw88461` I2C 功放驱动（`i2c-9:0034/0037 → aw88461`）。
- 结论：本板 **不能开（无硬件）**；若换有 WSA 功放的变体 = 纯板级 DTS（先例 `sm8750-mtp.dts:1211`、`glymur-…:897/925`）。

### 2.4 geniqup@9c0000（I2C master hub）
- 主、子驱动与 binding 全在（§1）。主线 `sm8750.dtsi:1248` disabled，10 个 `i2c@98x` 全 disabled；设备实测节点存在、状态 disabled、无子设备。
- 结论：**不能开（无已知下游设备）**；有设备时 = 纯板级 DTS。

### 2.5 gmu（3d37000 vs 3d6c000）
- 主线没有独立的 `qcom,adreno-gmu` 平台驱动（tree-wide grep 只命中 SMMU 特例 `arm-smmu-qcom.c:38`），GMU 是 GPU 驱动的子节点：`a6xx_gpu.c:2775 a6xx_gmu_init(a6xx_gpu, node)`。所以「unbound」不是缺陷。
- dmesg 证明在跑：`[drm:adreno_request_fw] loaded qcom/gen80000_gmu.bin` → `Loaded GMU firmware v5.1.25` → `Initialized msm 1.13.0`。
- **风险（新发现）**：我方 DT `gmu@3d37000 reg 0x68000`（`build/daily:3914`，`reports/artifacts/uefi-eud-20261101/live-fdt.dts:3914`）与主线 `gmu@3d6c000 reg 0x32000`（master `sm8750.dtsi:2367`）**不同**；仓内另一份主线基线 `reports/artifacts/b17-20261117/mainline/sm8750.dtsi:2367` 与 `out/g7-routeA-20261121/sm8750-lenovo-elden.dts:1897` 都是 `3d6c000`。功能上当前可用（GPU 正常出图），但**不能据此判定 3d37000 合法** → 列为 §3 动作 3（用主线值重编 DTB 对比 GMU 固件版本/DPU 初始化，二者都过才确认）。

### 2.6 camcc / cambistmclkcc / ctcu / rng / qce（5 个「只差配置」）
- 驱动+binding 均在主线（§1 行号）；`camcc`/`cambist` 同模块；`ctcu`/`rng`/`qce` 靠回退 compatible 即可绑定。
- 设备侧仅 `CONFIG_*` 未开或模块未加载；`dmesg` 的 `sync_state() pending due to ad27000.isp / 3d37000.gmu / 1dfa000.crypto` 就是「设备在、消费者驱动不在」的指纹。
- 结论：**零代码**，改 config 或 `modprobe` 即可；仓内 `build/daily/arch/arm64/configs/qcom-camera.config` 已把相机侧写成 `=y`（`CONFIG_VIDEO_QCOM_CAMSS=y`、`CONFIG_I2C_QCOM_CCI=y`、`CONFIG_SM_CAMCC_8750=y`），说明重编路径已备好；`HW_RANDOM_QCOM` / `CRYPTO_DEV_QCE` / `CORESIGHT_CTCU` 三项**尚未**进任何 fragment。

### 2.7 camss / cci（相机一族，唯一「驱动未在主线上」的一族）
- master `camss.c` 无 `sm8750`（命中 0），`media/qcom,sm8750-camss.yaml` 404 ⇒ **未合入**。我方 `build/daily camss.c:6136 { .compatible = "qcom,sm8750-camss" }` 是 payload。
- 在飞出处：我方 `patches/upstream/m4-camss-v2-20261031`（patchwork linux-media state=`new`，`reports/camss-upstream-response-20261028.md` §0）；同赛道 Hangxiang `[PATCH v5 0/5] media: qcom: camss: Add SM8750 support`（2026-06）与 `[PATCH v2 0/3] Add CCI and CAMSS support for SM8750`（2026-08-31，含 CCI binding 合入部分）。
- 设备侧：`isp@ad27000 status=okay`（我方 dtsi/板级已 enable 并挂了 `camera@56`/`camera@31`），模块未加载 ⇒ 未绑定。
- 结论：**能开**（加载模块）；上游形态 = **驱动补丁系列**（binding 已有在飞版本）。

---

## 3. 我方在树外携带的驱动（`patches/local/*` + `scripts/` + `PITFALLS` + `build/daily` 实文件）

判据：`curl …/plain/<path>` 的 HTTP 码（404 = 主线没有）+ binding 是否在 `Documentation/devicetree/bindings/`。

| 件 | 在主线？ | 形态 | 上游化难度（一句话） |
|---|---|---|---|
| 触屏 `novatek-nvt36xxx-spi.c`（`build/daily/drivers/input/touchscreen/`，compatible `novatek,nt36536-ts`） | **不在**（404）；主线只有 `novatek-nvt-ts.c`，of_match 仅 `nt11205-ts`/`nt36672a-ts`（`:322/323`），binding `novatek,nvt-ts.yaml:18/19` 同样只有这两款 | **整份驱动**（+ NT36536 no-flash 固件上传 + Lenovo 私有固件，见文件头注释 :6-8），**无 binding**（仓内也没有 `nvt36xxx` yaml） | 高：需新 driver + 新 binding + 私有固件改走 opt-in；现实路线是「改用主线 `novatek,nvt-ts` 扩展，不装固件」。设备侧已 bound（`NVTCapacitiveTouchScreen`） |
| 触觉 `aw86927`（`drivers/input/misc/aw86927.c`）+ 我们 chipdata 补丁 | **在**（master 200，882 行；binding `input/awinic,aw86927.yaml`）；设备上 `6-005a/6-005b → aw86927-haptics`（AW86937 双芯片） | **驱动补丁系列**：v2 **已投**（`patches/upstream/aw86927-20261027-v2`，MID `20261027132929.242158-1..6`，patchwork linux-input 5/5 在档）；v3→v4 备料未投（`aw86927-v4-prep-20261124/README.md`：基线 7.4-rc3，G1–G6 全绿，等放行） | 低-中：只差投递 + 复审；本地 chipdata 重构（`patches/local/aw86927-chipdata-20261027`）只能作系列第 2 提交 |
| 功放 `aw88461`（`build/daily/sound/soc/codecs/aw88461.c`，PID 0x2308） | **驱动不在**（404）；binding 只我方 `awinic,aw88395.yaml:26` 加了 `awinic,aw88461`（主线该 yaml 里 88461 命中 0） | **驱动补丁系列**（M3-3 备料：`patches/upstream/m3-3-2026-10-13`，Q2 裁定「并入 aw88395 家族」，封存未投）；设备 `i2c-9:0034/0037 → aw88461` 已 bound、声卡在跑 | 中：必须按 aw88395 家族扩展（复用 lib/device 层），且要先接受 binding 追加 |
| 背光 `aw99706`（`build/daily/drivers/video/backlight/aw99706.c`，作者 Junjie Cao/Pengyu Luo） | **不在**（404） | **整份驱动**（+ 我方 `bindings/leds/backlight/awinic,aw99706.yaml`）；设备 `i2c-10:0076 → aw99706` 已 bound | 中：第三方已写成上游风格，可独立投；需确认是否已有在飞系列，避免重复 |
| redriver `ptn3222`（`build/daily/drivers/phy/phy-nxp-ptn3222.c`） | **不在**（404）；主线只有 typec mux `ptn36502.c`（`nxp,ptn36502`） | **整份驱动**（+ `bindings/phy/nxp,ptn3222.yaml`） | 中-高：同类芯片主线是 mux 框架、我们是 phy 框架，需先对齐子系统选择（Q1）。设备 `i2c-5:004f → ptn3222` **已 bound**（被 `88e3000.phy` 消费），即功能可用、只差上游 |
| 相机 sensor `gc08a8` / `s5kjns` / `gt9764`（+ 各自 yaml） | **不在**（三者 404，yaml 在我方树） | **整份驱动** ×3 | 高：必须先有 camss/cci（§2.7）合入，否则「no user」；且 sensor 驱动要按 media 框架重审 |
| `fsa4480`（Type-C mux） | **在**（master `drivers/usb/typec/mux/fsa4480.c` 200；binding `usb/fcs,fsa4480.yaml`）；设备 `5-0042/5-0043 → fsa4480` | **纯 DT** | 无：板上已 bound，无驱动工作 |
| 传感器链路 `hexagonrpc` / SSC | **用户态项目**（`github.com/linux-msm/hexagonrpc`），不在内核树；内核侧仅 1 行 `drivers/misc/fastrpc.c` 补丁 | 用户态 PR + 内核 1 行回移件：`patches/local/fastrpc-sensorspd-20261126`（上游 **未合入**，lore `20261003150559.6926-2`，R-b Baryshkov；patchwork `handled-elsewhere` 但树上无痕）；守护进程侧 `patches/userland/hexagonrpc-pr31-20261127`（6 枚，对应上游 issue #29） | 中：内核 1 行迟早会被上游收（等 char-misc）；真正的坑在 hexagonrpcd 无 registry 写（上游 issue #29 open） |

---

## 4. 按上游化难度排序的动作清单

1. **零代码（改 config / 加载模块）** —— 一次性收益最大
   - `CONFIG_HW_RANDOM_QCOM=y`（rng）、`CONFIG_CRYPTO_DEV_QCE=y`（qce）、`CONFIG_CORESIGHT_CTCU=y`（ctcu）；这三项**当前不在任何 fragment**，需新增到 `arch/arm64/configs/*.config` 并在设备 config 里复核。
   - 运行期：`modprobe camcc-sm8750 qcom_cci qcom_camss`（顺序：camcc 先，cci/isp 后）。验收：`/sys/bus/platform/drivers/{camcc-sm8750,qcom_cci,qcom_camss}` 出现，`dmesg` 里 `sync_state() pending due to ad27000.isp/1dfa000.crypto/3d37000.gmu` 三行消失。
2. **纯板级 DTS（一行）** —— iris
   - `&iris { status = "okay"; }`（`build/daily` 工作树已加，未提交）；重编 DTB → 验证 PAS ID 9 验签 + `HFI gen2` 版本。上游化：直接进 elden 板级 DTS 即可（主线 mtp/qrd 已有先例，无需任何 binding/驱动动作）。
3. **核对而非改动** —— gmu 地址分歧
   - 用主线值（`gmu@3d6c000`/`0x32000`）重编一份 DTB 上机对比；若 GMU 固件版本/DPU 初始化都正常，则把 payload 的 `3d37000/0x68000` 视为 bug 并改回主线值（这是**送上游前必须清掉的差异**，否则 review 会直接指出）。
4. **盯在飞系列** —— camss + cci
   - 我方 `m4-camss-v2-20261031`（patchwork `new`）+ Hangxiang v5/v6；一旦 camss binding 合入，我们的 DTS 节点（`sm8750.dtsi` cci/isp + 板级 camera@56/31）就是**纯板级 DTS** 上游件。当前工作 = 每轮 linux-next 复核 + 回信，不再新写。
5. **只差投递** —— aw86927 v4
   - `patches/upstream/aw86927-v4-prep-20261124`（G1–G6 全绿，基线 7.4-rc3，未投）；投前先在 linux-next 复跑 G1。
6. **驱动补丁（需先接受 binding 追加）** —— aw88461、aw99706、ptn3222
   - aw88461 必须按 aw88395 家族扩展（Q2）；aw99706 先查是否已有他人系列；ptn3222 先做 Q1 子系统裁定（phy vs typec-mux）。
7. **高难度（新 binding + 私有固件）** —— 触屏 nt36536
   - 建议路线：把「事件帧格式」做成主线 `novatek-nvt-ts` 的扩展（不搬 firmware upload），固件上传留在 out-of-tree；否则「私有固件 + 无 binding」两个理由都会被否。
8. **不进上游（明确写出原因）**
   - mpss：本机 `baseband=apq` 无 modem 硬件、无 `modem.mdt`（签名固件）⇒ 没有可验证对象。
   - swr0/swr3：本板无 WSA 功放（喇叭是 I2C aw88461）⇒ 无硬件。
   - hexagonrpc 内核 1 行：不是我们的补丁（Robin Snyders 原作），等上游；我们只维护回移件。

---

## 5. 未证实 / 风险

1. **iris 签名门**：vpu35_p4.mbn 是原厂签名件，但 PAS ID 9 的 TZ 验签主机侧不可判（`reports/hwdec-iris-sm8750-feasibility-20261127.md` §0 同结论）。
2. **gmu 地址**：3d37000 vs 3d6c000 的等价性未证实（仅「当前功能正常」）。
3. **模块未加载的根因**：设备 config 是 `=m`、`.ko` 与 `modules.alias` 都在盘上、`systemd-udevd` active，但 lsmod 只有 31 个模块；判定为「镜像更新后未重新 coldplug / 不在永久层」，**未上机验证** `modprobe` 是否即可（本 lane 无设备写授权）。
4. **`build/daily` 历史不可用**：`git log` 因缺对象（`a2795d9c65bd…`）无法逐文件溯源，所以所有「在主线」结论都改用 master 抓取，而不是靠树内 git 历史。
