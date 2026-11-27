# 硬件能力集合 × 驱动面审计（lane A）— 2026-11-27

> 边界：主机侧只读 + `ssh elden` 只读（`/sys`、`/proc`、`dmesg`、`lsmod`、`/proc/config.gz`、`systemctl is-enabled`）。
> **未做**：`modprobe`、写 `/sys`、`systemctl start`、任何重启、任何发信、`git commit`。唯一写入 = 本文件。
> 设备：`TB322FC`／SM8750P／`Linux 7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`／Debian 13 trixie，审计时 uptime 16 min（主机钟 `date` = 2026-11-27 16:26 CST）。
> 基线（不重做）：`reports/driver-gap-device-audit-20261127.md`（A）、`reports/driver-upstream-audit-20261127.md`（B）、`reports/mainline-upstream-audit-20261122.md`、`TASKS/GAPS.md` Q36、`TASKS/dim/D2/D22`、`TASKS/UPSTREAM.md`。
> **本轮增量** = ①③④ 三桶 + **Android(vendor) DT 硬件枚举**（§1）。

---

## §0 一页结论表

### 0.1 本轮纠错（与既有报告相反，先列）

| # | 既有口径 | 本轮实测 | 影响 |
|---|---|---|---|
| C1 | A 报告 §0 #1「相机栈驱动齐全但被 `cam-mode-off.service`（enabled）主动卸载，当前视频节点 0」 | 相机栈**已在运行**：`qcom_camss`/`i2c_qcom_cci`/`camcc_sm8750`/`cambistmclkcc_sm8750` 在 `lsmod`，`isp@ad27000`、`cci@ac7b/ac7c` 均有 driver 链接，`/dev/video*`=**17**、`/dev/media0`=**1**，`cam-mode-off.service: **disabled**` | 相机从「②已部署默认停机」升级为 **⑤正常**，不再是任何桶的缺口 |
| C2 | A 报告 §3.4「树内没有 st21nfca 驱动」 | **驱动在树内**：`build/daily/drivers/nfc/st21nfca/{i2c.c,core.c,Kconfig}` 齐，上游 200（`.../st21nfca/i2c.c`）；缺的只是 `CONFIG_NFC_ST21NFCA_I2C` 未开 + DT disabled | NFC 从「无驱动」降为 **②（CONFIG）**，「驱动缺口」表述作废 |
| C3 | B 报告 §3「aw99706 / phy-nxp-ptn3222 均 404＝未上游」 | **两者已在 torvalds master**：`drivers/video/backlight/aw99706.c` 200（含 `awinic,aw99706`，:457）、`drivers/phy/phy-nxp-ptn3222.c` 200（含 `nxp,ptn3222`，:106），比 11-27 变了 | ④ 只剩「本地增量 delta」，不是「整份驱动待投」 |
| C4 | Q36「`/dev/video*` 零个 ⇒ 无硬件解码」 | `/dev/video*` 现在 **17 个，但全是相机**（`video0 = msm_vfe0_video0`），`dmesg\|grep -ci iris` = **0**，`video-codec@aa00000 status=disabled` | 「零个」是相机未加载时代的表述；iris 仍不可用，结论不变、判据要改 |
| C5 | B 报告 §0.2 / §5「我方 DT `gmu@3d37000/0x68000` 与主线 `3d6c000/0x32000` 不同，疑为 payload bug」 | **vendor DT 就是 `gmu@3d37000 reg=<0x3d37000 0x68000 0x3d40000 0x10000>`**（merged.dts:37602-37619）；主线 master `sm8750.dtsi:2367 gmu@3d6c000` | 差异方向反了：我方跟随 vendor，疑点转到「主线值是否适用本板」，仍属未证实（§4） |

### 0.2 结论表（块 × 桶 × 判定 × 下一步）

| # | 硬件块 | 桶 | 判定 | 一句话下一步 |
|---|---|---|---|---|
| 1 | 相机整栈（CAMSS+2×CCI+CSIPHY+s5kjns/gc08a8/gt9764+wl2868c+flash LED+camcc） | **⑤** | 驱动/DT/模块全就位并已绑定，17 video + 1 media | 只差一次出流复验（Q9 曾有 30 fps 记录） |
| 2 | 硬件视频解码 iris（`video-codec@aa00000`） | **②+④** | 在机 DT `disabled`；`CONFIG_VIDEO_QCOM_IRIS=m`、`qcom-iris.ko` 在盘；工作树已 `&iris{okay}` **未提交** | 提交板级 DTS + 重编上机验 TZ 签名（Q36） |
| 3 | GPU（adreno）+ GMU 子节点 | ⑤ | `3d00000.gpu→adreno`；`3d37000.gmu` 无 driver 属设计（父驱动消费） | 无 |
| 4 | 显示（MDSS/DPU/DSI×2/DSI-PHY×2/panel/backlight） | ⑤ | `card0-DSI-1=connected`；`aw99706-backlight 2108/4095` | 无（Q28 坏发为运行期既有风险） |
| 5 | 触屏 novatek NT36536 | **⑤+④** | `spi0.0→novatek-nvt36xxx-spi`，`event4=NVTCapacitiveTouchScreen`；驱动/binding 上游 404 | 上游化路线 = 扩展主线 `novatek-nvt-ts`（不自带固件） |
| 6 | 触觉 aw86927 ×2 | **⑤+④** | `6-005a/6-005b→aw86927-haptics`，`event2/3`；上游驱动在，chipdata/v4 系列在飞 | 盯 aw86927 v4 线程 |
| 7 | 扬声器功放 aw88461 ×2 | **⑤+④** | `9-0034/9-0037→aw88461`，声卡在跑；上游 404（须并入 aw88395 家族） | 出 aw88395 家族扩展补丁 |
| 8 | WSA 功放（swr0/swr3、wsa884x） | ⑤（无该硬件） | vendor DT 里 `wsa-macro`/`wsa884x` 全部 `disabled`，与主线一致 | 无需动作；换变体才写板级 DTS |
| 9 | 音频编解码 WCD9390/9395 + WSA/RX/TX/VA 宏 | ⑤ | `/proc/asound/cards` 有 `Lenovo-Y700-Gen4`；wcd939x 在 swr 上绑定 | 无 |
| 10 | 相机 PMIC wl2868c | **⑤+④** | `10-002f→wl2868c`；驱动已进 linux-next（torvalds master 仍 404） | 等合并窗口，无动作 |
| 11 | 闪光灯 PM8550 flash LED | ⑤ | 主线 `led-controller@ee00 status=okay`，vendor 同名节点 `ok` | 无 |
| 12 | NFC ST21NFCA | **②** | `# CONFIG_NFC_ST21NFCA* is not set`；DT `i2c@a80000` **两边都 disabled**（vendor 也 disabled） | 先证物理在位，再开 CONFIG+DT；不建议盲开 |
| 13 | 硬件 TRNG（`qcom,sm8750-trng`） | **②** | `# CONFIG_HW_RANDOM_QCOM is not set`（defconfig 为 `=m`）；`rng_current=smccc_trng` 兜底 | 开 `=m` 即得真随机源 |
| 14 | QCE 加密引擎（`1dfa000.crypto`） | **②** | `CONFIG_CRYPTO_DEV_QCE` 三处（.config/defconfig/fragment）**均无此符号** | 加 `=m` + `CRYPTO_DEV_QCE_*`，验收 `sync_state pending due to 1dfa000.crypto` 消失 |
| 15 | CTCU（`10001000.ctcu`） | **②** | `# CONFIG_CORESIGHT_CTCU is not set`；驱动在树（`coresight-ctcu-core.c`） | 开 `=m`（与 CORESIGHT=m 家族一致） |
| 16 | Coresight TPDM/TPDA/TNOC（28 个 amba 设备） | **②** | `# CONFIG_CORESIGHT_TPDM/TNOC is not set`；`amba total=41 unbound=28`；dmesg `109ab000.tn: deferred probe pending` | 开 `=m`；诊断能力，非用户功能 |
| 17 | Modem（`remoteproc@4080000`） | N/A（无硬件） | 在机 `disabled`；vendor DT 为 `ok` 但本机 `baseband=apq`、`/lib/firmware/qcom/sm8750` 无 modem 固件 | 不投入（与 B §2.2 一致） |
| 18 | SPSS 安全处理器（vendor `remoteproc-spss@1880000`、`spss_utils`） | **①** | 主线**无任何 spss 驱动**；vendor 节点为 `ok` | 不投入（GAPS §2「SPU 明确不投入」） |
| 19 | SOCCOP remoteproc（vendor `remoteproc-soccp@a3380000`） | **①** | `qcom_q6v5_pas` 只匹配 `kaanapali/glymur-soccp-pas`，无 sm8750 compatible，主线 DT 无节点 | 不投入（无消费方） |
| 20 | PMIC 触觉（vendor `pmih010x qcom,hv-haptics@f000`） | **①** | 主线无 `hv-haptics` 驱动（`drivers/input/misc` 无），`pmih0108.dtsi` 无节点 | 先证贴装；本机触觉走 aw86927，大概率未用 |
| 21 | vendor `bl@11`（`i2c-backlight`）、`bias@3e`（`bias`） | **①** | 两 compatible 在任何树都无匹配驱动；主线无节点 | 需 vendor 源码/原理图才能定用途 |
| 22 | 传感器中枢（SLPI/QMI：vendor `qmi-ts-sensors`） | **②+④** | AP 侧 iio 只有 `spmi-adc5-gen3`；`hexagonrpcd masked`、`iio-sensor-proxy static`；内核侧 fastrpc 1 行补丁未上游 | 先建取证通道再谈 `-s`（D22 硬门） |
| 23 | USB dwc3 + Type-C/DP altmode（fsa4480×2、ptn3222、UCSI） | **⑤+④** | `5-0042/5-0043→fsa4480`、`5-004f→ptn3222`、`ucsi-source-psy-*`×2；双连接器系列 v16 在飞 | 盯 dwc3 v16 / elden DTS v10 |
| 24 | UFS | ⑤ | `1d84000.ufs→ufshcd-qcom`，`/dev/sda` | 无 |
| 25 | microSD（sdhci） | ⑤ | vendor `sdhci@8804000` `ok`，主线 `mmc@8804000` okay，设备 `mmc0` 在册 | 无（坏卡问题已定性为卡） |
| 26 | PCIe + WiFi（ath12k / vendor cnss-peach） | **⑤+③+④** | `01:00.0→ath12k_wifi7_pci`，`wlan0 up`；但 `CONFIG_ATH12K=y`（defconfig `=m`）；WCN7861 支持是树外改动 | 掉到 `=m` 便于模块重载规避 MHI 竞态 |
| 27 | 蓝牙 WCN7861 | **⑤+④** | `hci0` 起、`QCA setup on UART is completed`；btqca/hci_qca 的 7861 改动树外 | 上游化 hci_qca/btqca 增量 |
| 28 | PMIC/regulator/thermal/ADC/RTC（含 55 thermal zone） | ⑤ | `qcom-rpmh-regulator`×6、`qcom-tsens`×4、`rtc-pm8xxx`、`spmi-adc5-gen3` | 无 |
| 29 | ADSP/CDSP + fastrpc（17 compute-cb） | ⑤ | `remoteproc0/1 running`；`fastrpc` 绑定 | `non-secure-domain` 1 行仍在飞（M10） |
| 30 | Gunyah（vendor `gh-*` 节点） | **②+④** | `CONFIG_GUNYAH=m` 且 9 个 `.ko` 在盘，**均未加载**；主线无 gunyah | 维持不投入（D21 已裁决） |
| 31 | 充电输入限流（SDP ≥500 mA） | **⑤（写未验）** | 按 `TASKS` §7 M12 台账：Joonhoe Kim 件已被收为 `be5e7367bceb` 且上机验过（`reports/m12-upstream-test-20261125.md`）；本机本轮只读到 `input_current_limit=2000000`、`usb_type=Unknown [SDP]` | 需一次写测试（本 lane 无写权限） |

**数字汇总**：①=4 块 · ②=7 块（含 iris/传感器共享）· ③=2 条真差异 · ④=8 类在飞/树外 · ⑤=17 块。

---

## §1 能力集合总表（vendor DT 枚举 × 主线对照）

### 1.1 枚举方法与数字（命令见 §3）

| 项 | 值 | 说明 |
|---|---|---|
| vendor 基座 DTB | `backup/stock-elden/dtb/10_dtbdump_Qualcomm_Technologies,_Inc._SunP_SoC.dtb`（msm-id `639 65536`=0x27f/SM8750P，board-id `0 0`） | 仓库既有 13 张 SoC DTB 之一（SunP = SM8750P；Kera/Tuna 非本机） |
| vendor 板级 overlay | `backup/stock-elden/elden_overlay.dtb`；可复现源 = `reference/stock-elden.dts`（`qcom,board-id = <0x2000b 0>` = 131083） | `dtc -@` 重编后 `fdtoverlay` 合并结果与既有 `.dtb` **逐节点一致**（两棵 983 行输出 diff 为空） |
| vendor 合并树规模 | 含 `compatible` 节点 **983**；启用 **844**（`okay`=752 + `ok`=92）、`disabled`=**138**（+1 个 `disable` 拼写） | 「有效状态」= 自身或任一祖先 disabled 即 disabled；DT 规范里 `ok`/`okay` 等价 |
| 主线对照树 | `build/daily/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb`（构建于 2026-11-27 14:39） | = 主线 7.3.1 + payload（非 pristine）；pristine 行号一律用 master 抓取 |
| 主线树规模 | 含 `compatible` 节点 **317**；`okay`=**275**、`disabled`=**42** | payload 已往 `sm8750.dtsi` 加 539 行、板级 +3168 行 |
| 外部外设叶节点 | vendor **16**（含 3 个走 pmic-glink 的 debug i2c）+ 2 个 `cam-sensor`；主线 **13**（geni i2c/spi 10 + CCI 上 3） | 见 §1.2 |

### 1.2 三列差集（只列硬件块，不列 PMIC/NOC/SMMU 内部节点）

图例：`✔` 有且 okay；`✘` 无节点；`(d)` disabled；箭头 = 语义等价但 compatible 不同。

| 硬件块 | vendor DT | 主线 DT | 差集判定 |
|---|---|---|---|
| 触屏 | `spi@a90000/novatek@0` = `novatek,NVT-ts-spi` ✔ | `spi@a90000/touchscreen@0` = `novatek,nt36536-ts` ✔ | 两边都有（串不同）；主线驱动是树外件 |
| 背光 #1 | `i2c@888000/bl@76` = `i2c-backlight` ✔ | `i2c@888000/backlight@76` = `awinic,aw99706` ✔ | 两边都有（vendor 用泛型串） |
| 背光 #2 / bias | `i2c@888000/bl@11`（`i2c-backlight` @0x11）✔、`bias@3e`（`bias` @0x3e）✔ | ✘ / ✘ | **vendor 有主线无**（用途未明，无驱动） |
| 触觉（AP 侧） | `i2c@a98000/haptic_hv_l@5A`、`haptic_hv_r@5B`（`awinic,haptic_hv_*`）✔ | `haptic-controller@5a/@5b` = `awinic,aw86937` ✔ | 两边都有 |
| 触觉（PMIC） | `pmih010x@7/qcom,hv-haptics@f000` ✔ | ✘ | **vendor 有主线无**（无驱动；贴装未证） |
| 扬声器功放 | `i2c@884000/aw882xx_smartpa@34,@37` ✔ | `amplifier@34,@37` = `awinic,aw88461` ✔ | 两边都有 |
| WSA 功放 | `wsa-macro@6B00000`(d)、`wsa2-macro@6AA0000`(d)、`wsa884x@…`(d) ×4 | `soundwire@6b10000`(d)、`soundwire@6ab0000`(d) | **两边都 disabled**（本板无该硬件，一致） |
| 音频编解码 | `i2c@a8c000`(启用)/`wcd939x_i2c@e` ✔、`swr` 上 `wcd939x-rx/tx-slave` ✔、`wcd939x-codec` ✔ | `i2c@a8c000`(d, 无子节点)、`audio-codec` = `qcom,wcd9395-codec` ✔、`swr` 上 `sdw20217010e00` ✔ | 两边都有（发声走 SWR）；**vendor 多一个 I2C 控制节点**（主线总线 disabled，不影响发声） |
| 蓝牙音频 SWR | `lpass_bt_swr@6CA0000` + `btfmswr_slave` ✔ | ✘ | **vendor 有主线无**（BT 音频通路，未建） |
| 相机框架 | `qcom,cci0/1@ac7b/ac7c000` + `cam-cpas/cam-icp/cam-isp/cam-csiphy/cam-jpeg/cam-cdm` 全套下游节点 ✔ | `cci@ac7b000/@ac7c000` + `isp@ad27000`=`qcom,sm8750-camss` ✔ | 两边都有（框架/命名不同） |
| 相机 sensor/lens | `qcom,cam-sensor0/1`（`qcom,cam-sensor`）✔ + actuator/eeprom ✔ | `camera@56`(s5kjns)、`camera@31`(gc08a8)、`lens@c`(gt9764) ✔ | 两边都有 |
| 相机 PMIC | `i2c@888000/i2c_wl2868c@2F` = `will,wl2868c` ✔ | `pmic@2f` = `willsemi,wl2868c` ✔ | 两边都有（binding 已合） |
| 闪光灯 | `pm8550@1/qcom,flash_led@ee00`（`qti-pm8350c-flash-led`）✔ + `camera-flash1` ✔ | `pm8550_flash/led-controller@ee00`（`qcom,pm8550-flash-led`）✔ | 两边都有 |
| Redriver | `i2c@a94000/eusb2_repeater@4f` = `nxp,eusb2-repeater` ✔ | `redriver@4f` = `nxp,ptn3222` ✔ | 两边都有（型号标注不同，同一器件） |
| Type-C mux | `fsa4480_i2c@43`、`fsa4480_sub_i2c@42` ✔ | `typec-mux@42/@43` = `fcs,fsa4480` ✔ | 两边都有 |
| USB-C 连接器 | `usb_port0/1_connector` ✔ | `/pmic-glink/connector@0/@1` ✔ | 两边都有 |
| USB 控制器/PHY | `ssusb@a600000` + `dwc3` + `hsphy@88e3000` + `ssphy@88e8000` ✔ | `usb@a600000` + `phy@88e3000` + `phy@88e8000` ✔ | 两边都有 |
| eUSB2 repeater(PMIC) | `pmih010x@7/eusb2-repeater@fd00` ✔ | `pmic@7/phy@fd00` = `qcom,pm8550b-eusb2-repeater` ✔ | 两边都有 |
| 充电器（ADSP 侧） | `pmic_glink_debug/i2c@106`：`smb1501@68/@69`、`idt9418@3b` ✔ | ✘ | **vendor 有主线无**（AP 无控制面，见 §2.1 说明） |
| NFC | `i2c@a80000`(d) + `st21nfc@08`(d) | `i2c@a80000`(d) + `nfc@8`(d) | **两边都 disabled**（vendor 也不开） |
| WiFi | `pcie@1c00000` + `cnss-peach@b0000000` ✔ | `pcie@1c00000` + `wifi@0`=`pci17cb,110e` ✔ | 两边都有（驱动路线不同） |
| 视频解码 | `vidc@aa00000` = `qcom,sm8750-vidc` ✔ | `video-codec@aa00000` = `qcom,sm8750-iris` ✔（**在机 disabled**） | 两边都有；**mainline 在机 disabled** |
| Modem | `remoteproc-mss@04080000` = `ok` | `remoteproc@4080000`(d) | **两边节点在，主线 disabled**（无固件，§0 #17） |
| SPSS / SOCCP | `remoteproc-spss@1880000`、`remoteproc-soccp@a3380000` = `ok` | ✘ / ✘ | **vendor 有主线无**（§0 #18/#19） |
| Gunyah | `gh-dbl/gh-rm-booster/gh-secure-vm-loader/gh-msgq-test…` ✔ | ✘ | **vendor 有主线无**（gunyah 未进主线） |
| 传感器 | `qmi-ts-sensors` ✔（QMI 服务，无 AP i2c 器件） | ✘ | **vendor 有主线无**（设计：SLPI 私有总线） |
| HDMI/DP 音频 | `msm-ext-disp-audio-codec-rx` ✔ | 无 DT 节点（`hdmi-audio-codec.2.auto` 由 msm DP 驱动注册：`dp_drm.c:327 bridge->hdmi_audio_dev`） | 等效 |
| Coresight 诊断 | `tpdm@…`/`tpda@…` 节点在，多为 `disabled`（`arm,primecell`） | `tpdm@…`/`tpda@…`/`tn@…` = `qcom,coresight-tpdm/tpda/tnoc` **okay** | 两边都有节点；**vendor 多数 disabled、主线 okay**（差在 DT 状态） |
| PMIC 组合 | `pm8010@c/@d`、`pmd802x@4`（+`amoled-ecm@f900`）、`pmr735d@a`、`pm8550vs@2-6` 等 ✔（vs 多为 disabled，pm8010/pmd802x/pmr735d 为启用） | 8 个 pmic 节点：`pm8550@0/@1/@8`、`pm8550ve@3/5/6`、`pmih0108@7`、`pm8550vs@9` | **vendor 有主线无**：pm8010 / pmd802x(AMOLED rail) / pmr735d（贴装未证；框架支持在上游） |

---

## §2 五桶明细

### 2.1 ① 有硬件但没有驱动（树内/上游都没有）

| 硬件 | vendor 证据 | 主机侧证据 | 判定/下一步 |
|---|---|---|---|
| SPSS（secure processor subsystem） | `/soc/remoteproc-spss@1880000` = `qcom,sun-spss-pas` `ok`、`/soc/qcom,spss_utils` `ok` | `grep -rn spss drivers/{remoteproc,soc/qcom}` = 0；`grep -n 'config QCOM_SPSS' drivers/soc/qcom/Kconfig` 无 | 不投入（GAPS §2 私有件） |
| SOCCOP remoteproc | `/soc/remoteproc-soccp@a3380000` = `qcom,sun-soccp-pas` `ok` | `q6v5_pas.c` 只有 `glymur/kaanapali-soccp-pas`（:1829/:1830），无 sm8750；主线 `sm8750.dtsi` 无 soccp 节点 | 不投入（无消费方） |
| PMIC 触觉 | `pmih010x@7/qcom,hv-haptics@f000` `ok` | 上游 404：`drivers/input/misc/qcom-hv-haptics.c`、`qcom_pmic_haptics.c`；`drivers/input/misc/` 无相关文件；`pmih0108.dtsi` 无节点 | 先证贴装；实际触觉路 = aw86927 |
| `bl@11` / `bias@3e` | `/soc/qcom,qupv3_2_geni_se@8c0000/i2c@888000/bl@11`（`i2c-backlight`）、`bias@3e`（`bias`）均 `okay` | 全树无这两个 compatible 的驱动；主线 DT 无节点 | 需 vendor 源码/原理图定用途 |

> 说明（不算 ①）：`pmic_glink_debug/i2c@106` 的 `smb1501@68/@69`、`idt9418@3b` 是**ADSP 侧**充电器节点，AP 本来就不该有驱动（`qcom_battmgr` 走 glink 暴露 `input_current_limit`）。归 ⑤ 的「充电链」行。

### 2.2 ② 有驱动但当前没部署

| 硬件 | 缺什么 | 证据（命令 + 原文） |
|---|---|---|
| iris 硬件解码 | 在机 DT `status=disabled`（+ 板级覆盖未提交） | `cat /sys/firmware/devicetree/base/soc@0/video-codec@aa00000/status` → `disabled`；`zcat /proc/config.gz \| grep VIDEO_QCOM_IRIS` → `CONFIG_VIDEO_QCOM_IRIS=m`；`find /lib/modules/$(uname -r) -name qcom-iris.ko` 命中 |
| 硬件 TRNG | `CONFIG_HW_RANDOM_QCOM` 未设 | `# CONFIG_HW_RANDOM_QCOM is not set`（defconfig `arch/arm64/configs/defconfig:606 CONFIG_HW_RANDOM_QCOM=m`）；`10c3000.rng` 无 driver 链接；`rng_current=smccc_trng` |
| QCE | `CONFIG_CRYPTO_DEV_QCE` 全仓未启用 | 设备 `zcat /proc/config.gz \| grep CRYPTO_DEV_QCE` 无输出（rc=0 但无行）；build/daily `.config` 同样无；符号存在于 `drivers/crypto/Kconfig:529` |
| CTCU | `CONFIG_CORESIGHT_CTCU` 未设 | `# CONFIG_CORESIGHT_CTCU is not set`；`10001000.ctcu` 无 driver 链接；驱动在树 `coresight-ctcu-core.c` |
| TPDM/TPDA/TNOC（28 设备） | `CONFIG_CORESIGHT_TPDM/TNOC` 未设 | `# CONFIG_CORESIGHT_TPDM is not set`、`# CONFIG_CORESIGHT_TNOC is not set`；`amba total=41 unbound=28`；`dmesg: amba 109ab000.tn: deferred probe pending` |
| NFC ST21NFCA | `CONFIG_NFC_ST21NFCA*` 未设 + `i2c@a80000` disabled（两边） | `zcat /proc/config.gz \| grep NFC_ST21NFCA` 无输出；`NFC_NCI=m` 但在；`drivers/nfc/st21nfca/Kconfig:2 config NFC_ST21NFCA`（tristate，需 `NFC_HCI && NFC_SHDLC`，二者也未设） |
| 传感器用户态栈 | 服务 masked | `hexagonrpcd.service: masked`；`hexagonrpcd-adsp-sensorspd.service: not-found`；`iio-sensor-proxy.service: static`；`/sys/bus/iio/devices` 只有 `iio:device0` |
| Gunyah | 模块未加载（策略） | `CONFIG_GUNYAH=m` 等；`lsmod \| grep gunyah` 空；`/dev/gunyah*` 不存在；`gunyah*.ko`×9 在盘 |

### 2.3 ③ 有但没有模块化（=m/=y 取舍）

| 项 | 当前值 | 参照值 | 哪边更对 / 下一步 |
|---|---|---|---|
| **ATH12K** | `=y`（built-in） | `arch/arm64/configs/defconfig:508 CONFIG_ATH12K=m` | **=m 更对**：本机有 MHI `-110` 启动竞态，`=m` 才可 `rmmod/insmod` 重试；built-in 把固件加载绑进 boot 关键路径 |
| **PHY_NXP_PTN3222** | `=y` | `defconfig:1759 CONFIG_PHY_NXP_PTN3222=m` | **=m 更对**：与 USB 角色切换解耦，probe 失败可重载；当前 `=y` 是本地偏离，非上游默认 |
| VIDEO_QCOM_CAMSS / I2C_QCOM_CCI / SM_CAMCC_8750 | 均 `=m` | `defconfig:933/631` 同为 `=m`；但 `arch/arm64/configs/qcom-camera.config:3` 写 `=y` | **=m 更对（现状即可）**：相机非 boot 关键；`qcom-camera.config` 是 camera 开发用 fragment，不必跟 |
| INPUT_AW86927 / SND_SOC_AW88461 / BACKLIGHT_AW99706 | 均 `=y` | 驱动不在上游（aw88461/aw86927-chipdata）或上游无 defconfig 条目 | **=y 合理**：触屏/功放/背光是 UI 必需，built-in 少一层 initramfs 依赖；不列为缺陷 |
| CORESIGHT 家族（CTCU/TPDM/TNOC 若开启） | 现全 off | `defconfig` 里同族均 `=m`（`:1972-1979`） | **若开则应用 `=m`**（与家族一致）；见 §2.2 |
| QCOM_Q6V5_PAS | `=y` | — | **=y 合理**：ADSP/CDSP 在 boot 就要起来 |

### 2.4 ④ 有但没有上游化（树外/在飞/未提交）

判据：`curl .../plain/<path>` 的 HTTP 码（本轮现拉（主机日期 2026-11-27））+ 仓内目录状态。

| 件 | 上游状态 | 本机形态 | 下一步 |
|---|---|---|---|
| 触屏 `novatek-nvt36xxx-spi.c` + `novatek,nt36536-ts.yaml` | 驱动 404、binding 404（主线只有 `novatek-nvt-ts.c` 的 `nt11205/nt36672a`） | payload 926 行 + 私有固件上传，已绑定 | 改为扩展 `novatek-nvt-ts`（不搬固件） |
| 功放 `aw88461.c` + aw88395 binding 追加 | 驱动 404；`aw88395_device.c` 内 `88461` 命中 0 | payload 547 行，已绑定 | 出「aw88395 家族扩展」补丁（Q2 裁定） |
| 相机 `camss` SM8750（`camss.c`/`camss-csid-980.c`/`camss-vfe-gen4.c` + yaml） | master `camss.c` `sm8750` 命中 **0**、binding 404 | payload，已绑定出 17 video | 维持「盯在飞系列」（m4-camss-v2 + Hangxiang v5/v6） |
| CCI SM8750 | master `i2c-qcom-cci.c` `sm8750` 命中 **0**（靠 `msm8996-cci` 回退） | payload 已 enable 且挂 sensor | 随 camss 系列一起走 |
| 相机 sensor/lens `gc08a8.c`/`s5kjns.c`/`gt9764.c` + 3 份 yaml | 三者 404 | payload，已绑定 | 依赖 camss 先合 |
| ath12k WCN7861（`qmi.c` +644 行、`wifi7/pci.c` 等） | 上游只有 WCN7850；PEACH 无 | payload，`wlan0 up` | 按模块向上游拆（B §3 结论不变） |
| `hci_qca.c` +387 / `btqca.c` +60（WCN7861/PERI） | 上游 0 命中 | payload，BT 已起 | 同上 |
| `aw99706.c` 本地增量 11 行（enable-gpio 提前 + `devm_kzalloc`） | **驱动已上游**（200）；差异 = 本地把 `hwen_gpio` 移到 chip-id 读之前 | payload 仍带改动 | 核对上游时序是否等价，等价则丢弃本地改动 |
| `phy-nxp-ptn3222.c` 本地增量（`override_sequence` + regmap 写） | **驱动已上游**（200，Linaro 版）；上游无 override-seq | payload 有额外能力，`5-004f` 用它 | 把 override-seq 作为独立 delta 投（不要重投整份） |
| `aw86927.c` chipdata（+405 行） | 上游驱动在；v4 系列 2026-11-24 已投 | payload 带 chipdata | 盯 v4 线程 |
| fastrpc `qcom,non-secure-domain`（`sm8750.dtsi` 1 行） | 未进 mainline/next（M10） | payload 有 | 等 Konrad/Srini |
| iris 板级 `&iris{okay}` | 上游 mtp/qrd 已有先例 | **build/daily 未提交改动**（`git status`: `M arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`） | 随 elden DTS 一起提交 |
| elden 板 DTS v10（2 枚，含 dwc3 双连接器 v16 3 枚） | 在飞（11-26 投） | DT 与上游不同步 | 盯 Krzysztof/Rob |
| DSI PLL `PLL_SYSTEM_MUXES`（M6 v3）、mdss 块复位（M8 v5） | 在飞 | payload/本地补丁 | 盯回信 |

### 2.5 ⑤ 正常已达成（各一条硬证据）

| 功能 | 证据 |
|---|---|
| GPU | `/sys/devices/platform/soc@0/3d00000.gpu → adreno` |
| 显示 | `/sys/class/drm/card0-DSI-1/status = connected` |
| 背光 | `/sys/class/backlight/aw99706-backlight/brightness = 2108 / max 4095` |
| 触屏 | `/sys/bus/spi/devices/spi0.0 → novatek-nvt36xxx-spi`；`event4 = NVTCapacitiveTouchScreen` |
| 触觉 | `/sys/bus/i2c/devices/6-005a,6-005b → aw86927-haptics`；`event2/3` |
| 相机 | `ad27000.isp→qcom-camss`、`ac7b/ac7c.cci→i2c-qcom-cci`；`/dev/video*`=17、`/dev/media0`；`video0=msm_vfe0_video0` |
| 相机 PMIC | `/sys/bus/i2c/devices/10-002f → wl2868c` |
| 音频 | `/proc/asound/cards` → `card 0 [LenovoY700Gen4] : sm8750 - Lenovo-Y700-Gen4` |
| 功放 | `/sys/bus/i2c/devices/9-0034,9-0037 → aw88461` |
| 蓝牙 | `/sys/class/bluetooth/hci0`；`dmesg: hci0: QCA setup on UART is completed` |
| WiFi | `/sys/class/net/wlan0/operstate = up`；`ath12k_wifi7_pci 0000:01:00.0: fw_version 0x100effff` |
| USB/Type-C | `i2c 5-0042/5-0043 → fsa4480`、`5-004f → ptn3222`；`/sys/class/power_supply/ucsi-source-psy-*`×2；`usb0` 在 |
| UFS | `/dev/sda` + `1d84000.ufs → ufshcd-qcom` |
| microSD | `/sys/bus/mmc/devices/mmc0:b368 → mmcblk` |
| 热/PMIC | `/sys/class/thermal/thermal_zone0..54`；`qcom-tsens`×4；`qcom-rpmh-regulator`×6 |
| 远程处理器 | `remoteproc0=adsp running`、`remoteproc1=cdsp running`；`fastrpc` 绑定 17 个 `compute-cb` |
| 充电读数 | `/sys/class/power_supply/qcom-battmgr-bat/status = Full`、`capacity = 99`（10 min 前读到 100） |

---

## §3 复现命令清单（全部只读）

```bash
# A. vendor DT 枚举（主机侧，仓库内文件可复现）
fdtoverlay -i backup/stock-elden/dtb/10_dtbdump_Qualcomm_Technologies,_Inc._SunP_SoC.dtb \
           -o /tmp/merged.dtb backup/stock-elden/elden_overlay.dtb
dtc -I dtb -O dts /tmp/merged.dtb -o /tmp/merged.dts
dtc -I dtb -O dts build/daily/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb -o /tmp/ml.dts
cat > /tmp/parse.py <<'PY'   # 取 (有效状态, 路径, compatible)；有效状态 = 自身或祖先 disabled 即 disabled
import re,sys
def walk(fn):
    t=re.sub(r'/\*.*?\*/','',open(fn).read(),flags=re.S); t=re.sub(r'//[^\n]*','',t)
    st=[{'n':'/','s':None,'p':None,'c':None}]; out=[]
    for l in t.splitlines():
        s=l.strip()
        if not s: continue
        if s.endswith('{'):
            nm=re.sub(r'^[A-Za-z0-9_]+:\s*','',s[:-1].strip())
            st.append({'n':nm,'s':None,'p':st[-1],'c':None})
        elif s=='};':
            out.append(st.pop())
        else:
            m=re.match(r'^([A-Za-z0-9,._#+-]+)\s*=\s*(.*);$',s)
            if m:
                if m.group(1)=='status': st[-1]['s']=m.group(2).strip('"')
                elif m.group(1)=='compatible': st[-1]['c']=m.group(2)
    for n in out:
        if not n['c']: continue
        eff=n['s']; q=n
        while q:
            if q['s']=='disabled': eff='disabled'; break
            q=q['p']
        print((eff or 'okay')+'\t'+n['n']+'\t'+n['c'])
walk(sys.argv[1])
PY
python3 /tmp/parse.py /tmp/merged.dts | cut -f1 | sort | uniq -c   # 752 okay + 92 ok = 启用 844 / 138 disabled / 1 disable
python3 /tmp/parse.py /tmp/ml.dts     | cut -f1 | sort | uniq -c   # 275 okay / 42 disabled

# B. 设备侧（只读）
timeout -k 5 25 ssh elden 'uname -r; lsmod | wc -l; ls /dev/video* | wc -l; ls /dev/media* 2>/dev/null'
timeout -k 5 40 ssh elden 'for n in video-codec@aa00000 remoteproc@4080000 soundwire@6ab0000 soundwire@6b10000 geniqup@9c0000; do printf "%s: " "$n"; cat /sys/firmware/devicetree/base/soc@0/$n/status; done'
timeout -k 5 40 ssh elden 'zcat /proc/config.gz | grep -E "HW_RANDOM_QCOM|CRYPTO_DEV_QCE|CORESIGHT_CTCU|CORESIGHT_TPDM|CORESIGHT_TNOC|NFC_ST21NFCA|ATH12K=|PHY_NXP_PTN3222|VIDEO_QCOM_IRIS|VIDEO_QCOM_CAMSS|I2C_QCOM_CCI|SM_CAMCC_8750"'
timeout -k 5 40 ssh elden 'for d in /sys/bus/platform/devices/*; do [ -L $d/driver ] || echo "UNBOUND $(basename $d)"; done; for d in /sys/bus/amba/devices/*; do [ -L $d/driver ] || echo "AMBA-UNBOUND $(basename $d)"; done | wc -l'
timeout -k 5 40 ssh elden 'for d in /sys/bus/i2c/devices/*; do printf "%s|%s|%s\n" "$(basename $d)" "$(cat $d/name 2>/dev/null)" "$(basename $(readlink $d/driver 2>/dev/null) 2>/dev/null)"; done'
timeout -k 5 40 ssh elden 'for s in cam-mode-off.service hexagonrpcd.service hexagonrpcd-adsp-sensorspd.service iio-sensor-proxy.service; do printf "%s: %s\n" $s "$(systemctl is-enabled $s 2>&1)"; done'
timeout -k 5 40 ssh elden 'cat /sys/class/drm/card0-DSI-1/status; cat /sys/class/backlight/aw99706-backlight/brightness; head -8 /proc/asound/cards; cat /sys/class/net/wlan0/operstate'

# C. 上游状态（本轮现拉，超时 20-25s）
B=https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain
for p in drivers/input/touchscreen/novatek-nvt36xxx-spi.c sound/soc/codecs/aw88461.c \
         drivers/video/backlight/aw99706.c drivers/phy/phy-nxp-ptn3222.c \
         drivers/media/platform/qcom/camss/camss.c drivers/i2c/busses/i2c-qcom-cci.c \
         drivers/nfc/st21nfca/i2c.c drivers/char/hw_random/qcom-rng.c drivers/crypto/qce/core.c \
         drivers/hwtracing/coresight/coresight-tpdm.c drivers/hwtracing/coresight/coresight-tnoc.c \
         drivers/hwtracing/coresight/coresight-ctcu-core.c drivers/input/misc/aw86927.c; do
  printf '%s %s\n' "$(timeout -k 5 25 curl -s -o /dev/null -w '%{http_code}' "$B/$p")" "$p"; done
timeout -k 5 25 curl -s "$B/drivers/media/platform/qcom/camss/camss.c" | grep -c sm8750   # 0
timeout -k 5 25 curl -s "$B/drivers/i2c/busses/i2c-qcom-cci.c" | grep -c sm8750            # 0
timeout -k 5 25 curl -s "$B/arch/arm64/boot/dts/qcom/sm8750.dtsi" | grep -n 'gmu@'        # 2367 gmu@3d6c000
timeout -k 5 25 curl -s "https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/plain/drivers/regulator/wl2868c-regulator.c" -o /dev/null -w '%{http_code}\n'  # 200
```

---

## §4 未取得证据 / 盲区

1. **vendor 基座选择**：`dtb/` 有 13 张 SoC DTB（Kera/KeraP/Sun/SunP/Tuna…）。本报告按 `SM8750P=SunP` 取 `10_SunP_SoC.dtb`；`09_SunP_v2_SoC.dtb`（msm-id `639 131072`）未做逐节点 diff，若实际启动用 v2 基座，个别节点可能增减（本报告的板级结论全部来自 overlay，不受影响）。
2. **overlay 来源**：`reference/stock-elden.dts` 根节点写 `model = "Qualcomm Technologies, Inc. Sun QRD SKU2 V8 Power Grid"`，即 **QRD 公共 overlay + Lenovo 差分**的形态；Lenovo 私有件（`lenovo,sys-temp` 等）只在其中，不能排除「vendor 在其它 overlay 里还声明了本报告未见的硬件」。dtbo 分区 32 条目未逐条解。
3. **DT 声明 ≠ 物理贴装**：pm8010/pmd802x/pmr735d、PMIC hv-haptics、`bl@11`、`bias@3e`、spss/soccp 都只是 vendor 声明；没有原理图/Android 侧 `dmesg` 对照，本报告标「存在性未证实」，**不能当缺口硬需求**。
4. **供应商节点的 compatible 不可直接比对**：vendor 用 `qcom,cam-*`/`awinic,haptic_hv_*`/`wsa884x` 等下游命名，与主线不同名；本报告用人工语义映射（§1.2），机器 diff 会产生 300+ 假阳性（`vendor-only 381 / mainline-only 215`），**不可直接引用**。
5. **写类验证全部未做**：`input_current_limit` 只读（`2000000`），是否可写、`usb_type` 能否从 `Unknown [SDP]` 修正均未测（本 lane 无写授权，M12 曾在他件上验过）。
6. **功能面复验未做**：相机出流（17 节点在≠出帧）、iris 签名门、传感器 `-s` 起服务（已知会撞 #692 硬崩）、DP 外接显示均未做；§2.5 的 ⑤ 只证「枚举/绑定正确」。
7. **`modprobe -R` 本 lane 未重跑成功**：直接传 `of:N*C…` 被 shell 展开成字面量后报 `Module of:N*C... not found`（正确用法需给 pattern 加引号，见 A 报告 §5）；本报告的「有无驱动」结论不依赖它，一律用 `.config` + 源文件 + `/sys` driver 链接三证。
8. **上游状态是时间快照**：`aw99706`/`ptn3222` 从 11-27 的 404 变 200，说明 mainline 每天在动；引用时以本轮日期为准。
