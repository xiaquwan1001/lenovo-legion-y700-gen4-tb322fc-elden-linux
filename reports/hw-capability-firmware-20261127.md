# 硬件能力集合补完 × 固件面审计（lane B）— 2026-11-27

> 边界：`ssh elden` **只读**（`ls`/`find`/`dmesg`/`/sys`/`sha256sum`/`zstd -dc`）+ 主机侧只读（内核树 `git grep`、打包脚本、`gitlab.com` API/raw 取 linux-firmware `WHENCE`）。
> **未做**：`modprobe`、写设备、重启、发信、`git commit`。唯一写入 = 本文件。
> 设备：`TB322FC`/SM8750P，`Linux 7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`，Debian 13 trixie（usrmerge：`/lib`→`/usr/lib`）。
> 内核树基线：`build/daily` @ `4da9a8b69fc85`（7.3.1，`CONFIG_LOCALVERSION="-debug-vk189-suspend"`）= 生成在机内核的构建树（与 `reports/hwdec-iris-sm8750-feasibility-20261127.md` §1 同口径）。
> 上游基线：`gitlab.com/kernel-firmware/linux-firmware` `main`（`WHENCE` 542574 B，抓于本轮）。
> 不重做：lane A `reports/hw-capability-drivers-20261127.md`（驱动/DT 面）、`DEVICE/README.md` §1.2（固件台账）、`TASKS/GAPS.md` Q34/Q36。本轮增量 = **逐文件三方对账 + 上游同名/同版本判定 + 门禁实测**。

---

## §0 一页结论表

### 0.1 数字结论

1. 在机 `/lib/firmware` 共 **121 个文件**：`ath12k` 8、`awinic` 2、`qca` 5、`qcom` 100（`qcom/sm8750` 96 / `qcom/vpu` 1 / `qcom` 顶层 3 个 `.zst`）、根目录 6。
2. 「需要固件的硬件」共 **14 个块 / 27 个文件路径**（§2.3 脚本输出）。本机 **27/27 在位**，**没有一条 `Direct firmware load ... failed`**（除 `regulatory.db` 一条，见 §3.9）。
3. 上游 linux-firmware 按**请求名逐字**覆盖 **5/27**：`qcom/gen80000_{gmu.bin,sqe.fw,aqe.fw}`、`qcom/sm8750/gen80000_zap.mbn`、`qcom/vpu/vpu35_p4.mbn`（经 `Link:` 别名）。另 4 条只有**单文件同族形态**（`qcom/sm8750/{adsp,cdsp,adsp_dtb,cdsp_dtb}.mbn`，驱动不读）。
4. 上游 **完全没有** 的三块 = **WCN7861 全家**（ath12k `PEACH/hw2.0/*` 8 件 + `qca/brh*`/`tmel_peach_20.elf` 5 件）、**触屏 novatek**、**awinic 本机 ACF**。这 3 块 16 个文件只能来自厂商分区（不可再分发）。
5. **`MODULE_FIRMWARE()` 只声明了 3 条**（全是 `qca/`），而真实请求集是 27 条 ⇒ 现行门禁 A2 的覆盖面 **3/27 = 11%**。
6. 门禁 A2 当前 **静默失效**：默认 `KDIR=$ROOT/build/vk151` 已不存在（`ls: cannot access 'build/vk151'`）⇒ 走 `WARN ... A2 无法校验` + `return 0`（实测输出见 §4.1）。
7. **CDSP 与上游逐字节相同**（`cdsp.mbn` sha `e046b64b…`、`cdsp_dtb.mbn` sha `6531a722…`），ADSP **不同构建**（本机 `LPAIDSP.HT.1.2.c1-00450-PAKALA-2` vs 上游 `c2-00080-PAKALA-1`）。
8. iris 唯一硬阻塞不是固件：`qcom/vpu/vpu35_p4.mbn` 已在机、上游也有更新版；阻塞是 DT `status=disabled`（`dmesg|grep -ci iris` = 0）。

### 0.2 结论表（硬件块 | 需要的固件 | 本机 | 上游 | 来源 | 判定与下一步）

| # | 硬件块 | 需要的固件（精确名） | 本机 | 上游 | 来源 | 判定与下一步 |
|---|---|---|---|---|---|---|
| 1 | ADSP（`remoteproc0`） | `qcom/sm8750/adsp.mdt` + `adsp.bNN`(55) + `qcom/sm8750/adsp_dtb.mdt` + `adsp_dtb.bNN`(3) | ✅ running | 🟡 仅有单文件 `adsp.mbn`/`adsp_dtb.mbn`，**版本不同** | 厂商签名（stock LUN4 `modem_a`） | ✅ 已起；上游 `.mbn` 能否替代本机 split **未验证**（TZ 对单文件 `cdsp_dtb.mbn` 曾返 -22，见 §3.4） |
| 2 | CDSP（`remoteproc1`） | `qcom/sm8750/cdsp.mdt` + `cdsp.bNN`(15) + `cdsp_dtb.mdt` + `cdsp_dtb.bNN`(3) | ✅ running | ✅ **同内容** | 厂商（=上游字节相同） | ✅ 已起；可改为从 linux-firmware 取（许可更干净） |
| 3 | GPU GMU/SQE/AQE | `qcom/gen80000_gmu.bin`、`gen80000_sqe.fw`、`gen80000_aqe.fw` | ✅（`.zst`，已解） | ✅ **同 sha** | 上游/vendor 同源 | ✅ 无需动作。⚠ 在机 `qcom/sm8750/gen80000_*` 另有一份同名副本（`sqe`/`aqe` 为旧版），驱动**不读**（§3.5） |
| 4 | GPU ZAP | `qcom/sm8750/gen80000_zap.mbn` | ✅ | ✅（不同 build，同尺寸 12088 B） | vendor 分区 `gpu/` | ✅ 无需动作 |
| 5 | WiFi ath12k `PEACH/hw2.0` | `amss.bin` `m3.bin` `board-2.bin` `board.bin` `regdb.bin` `tmel.bin` `aux_ucode.bin` `qdss_trace_config.bin` | ✅（8/8） | ❌ **无目录**（上游只有 `IPQ5424/QCC2072/QCN9274/WCN7850`） | stock `modem_a/image/peach`（signed amss + 厂商 BDF） | ✅ 起（MHI 重试，`wlan0` 在）；**上游缺口**：WCN7861/PEACH 无 linux-firmware 包，BDF 不可分发 |
| 6 | BT `hci_qca`（WCN7861 `brh`/BRAHMA） | `qca/brhbtfw20.tlv` `brhbtnv20.bin` `brhperifw20.tlv` `brhperinv20.bin` `tmel_peach_20.elf` | ✅（5/5） | ❌ **全无**（上游 WCN7850 = `hmt*`/HAMILTON） | stock `bluetooth_a` + `modem_a/image/tmel_*` | ✅ `hci0` 有 BD（`22:22:62:9C:97:58`，本次 DOWN 只是服务未起）；Q34 已闭环，**上游缺口仍在** |
| 7 | 视频解码 iris / VPU 3.5 | `qcom/vpu/vpu35_p4.mbn` | ✅（11-27 放入） | ✅ `vpu35_p4_s7.mbn` + `Link: qcom/vpu/vpu35_p4.mbn -> vpu35_p4_s7.mbn`，`VIDEO.VPU.3.5-0040` | 本机 vpu 件 = vendor `vpu35_4v.mbn` 改名（`rel0030`） | ⛔ **阻塞在 DT**（`video-codec@aa00000 status=disabled`，Q36）。建议改用上游件（同名、更新、可再分发）后再上机验 TZ |
| 8 | AudioReach tplg | `qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin` | ✅（18236 B） | ❌（上游只有 `SM8750-MTP/QRD-tplg.bin`） | **自编**（`scripts/audio-tplg/`） | ✅ 出声；可投 linux-firmware（建议 `qcom/sm8750/LENOVO/<model>/…` 布局）。⚠ 包内副本是旧版（§4.3） |
| 9 | 触屏 NT36536 | `novatek_ts_csot_3k_fw.bin`（根目录） | ✅ | ❌ 上游 `WHENCE` 无 `novatek` 字样 | stock `vendor/firmware/` 同名 | ✅ 在跑（`firmware version 1a.01`）；不可分发 |
| 10 | 触觉 aw86937 ×2 | `awinic/y700-gen4-haptic.bin` | ✅ | ❌（上游只有 `awinic/aw88399_acf_*`） | **自定/无源件**（vendor 无同名） | ✅ 在跑；上游化时须一并把自造 profile 的合法性说清 |
| 11 | 功放 aw88461 ×2 | `awinic/y700-gen4-speakers.bin` | ✅ | ❌ | vendor `aw882xx_acf.bin` **改名**（内容即 aw88461 ACF） | ✅ 在跑；不可分发 |
| 12 | WSA 宏 / WCD939x | **无固件需求**（register defaults 在驱动内） | — | — | — | 不需动作（且本板 WSA884x 节点 disabled，lane A #8） |
| 13 | 背光 aw99706 / PM8550 flash | **无固件需求** | — | — | — | 不需动作 |
| 14 | IPA（`CONFIG_QCOM_IPA=m`，默认 `ipa_fws.mdt`） | `ipa_fws.mdt` | 无 | 🟡 只有 `qcom/qcm6490/ipa_fws.mbn` | — | **非当前需求**：`sm8750.dtsi` 无 ipa 节点、`lsmod` 无 ipa（§6.3） |
| 15 | SSC 传感器 registry（`sns_reg.conf` + `config/` + `registry/`） | `/usr/share/qcom/sm8750/LENOVO/TB322FC/sensors/**`（**不在 /lib/firmware**） | ⚠ 该路径**不存在**；实件在 `/var/lib/hrpcd-root`（880 K） | ❌ | stock `modem_a`（厂商 registry） | 布局已漂移，门禁 A' 仍查旧路径（§3.8） |
| 16 | cfg80211 法规库 | `regulatory.db` + `regulatory.db.p7s` | ✅ 符号链 → `regulatory.db-debian` | —（属 wireless-regdb，不属 linux-firmware） | Debian 包 | ⚠ 启动时 `-2`（§3.9）：**不是缺件**，是时序/符号链 |

---

## §1 设备侧现状（全部只读，命令附原文）

### 1.1 `/lib/firmware` 结构（121 文件）

```
$ ssh elden 'cd /lib/firmware && for d in ath12k awinic qca qcom qcom/sm8750 qcom/vpu; do printf "%s %s\n" "$d" "$(find $d -type f|wc -l)"; done'
ath12k 8 / awinic 2 / qca 5 / qcom 100 / qcom/sm8750 96 / qcom/vpu 1
$ ssh elden 'cd /lib/firmware/qcom/sm8750 && echo "adsp.bNN=$(ls adsp.b[0-9][0-9]|wc -l) adsp_dtb.bNN=$(ls adsp_dtb.b[0-9][0-9]|wc -l) cdsp.bNN=$(ls cdsp.b[0-9][0-9]|wc -l) cdsp_dtb.bNN=$(ls cdsp_dtb.b[0-9][0-9]|wc -l)"'
adsp.bNN=55 adsp_dtb.bNN=3 cdsp.bNN=15 cdsp_dtb.bNN=3
```

逐块清单（`ls -lR` 原文摘要）：

| 目录 | 文件 | 备注 |
|---|---|---|
| `ath12k/PEACH/hw2.0/` | `amss.bin` 6959168、`aux_ucode.bin` 61440、`board-2.bin` 2253964、`board.bin` 125420、`m3.bin` 290816、`qdss_trace_config.bin` 6237、`regdb.bin` 24278、`tmel.bin` 56752 | 8/8 齐；`tmel.bin` 与 `qca/tmel_peach_20.elf` **同 sha** |
| `awinic/` | `y700-gen4-haptic.bin` 5881、`y700-gen4-speakers.bin` 1792 | 两个都 9月28日 23:19 落盘 |
| `qca/` | `brhbtfw20.tlv` 219296、`brhbtnv20.bin` 13319、`brhperifw20.tlv` 19884、`brhperinv20.bin` 741、`tmel_peach_20.elf` 56752 | 5/5（`tmel_peach_20.elf` 10月28日 09:55 补入 = Q34 处置） |
| `qcom/`（顶层） | `gen80000_aqe.fw.zst`、`gen80000_gmu.bin.zst`、`gen80000_sqe.fw.zst`、`sm8750/`、`vpu/` | 3 个 `.zst` 是驱动**实际读到**的路径（§1.2） |
| `qcom/sm8750/` | `adsp.mdt`+`adsp.b00..b56`(55)+`adsp.mbn.zst`、`adsp_dtb.mdt`+`adsp_dtb.bNN`(3)+`adsp_dtb.mbn.zst`、`adspr/adsps/adspua/adspuo.jsn`、`cdsp.mdt`+`cdsp.bNN`(15)+`cdsp.mbn.zst`、`cdsp_dtb.mdt`+`cdsp_dtb.bNN`(3)+`cdsp_dtb.mbn.zst`、`cdspr.jsn`、`gen80000_aqe.fw`/`gen80000_gmu.bin`/`gen80000_sqe.fw`/`gen80000_zap.mbn`、`Lenovo-Y700-Gen4-tplg.bin` 18236、`SM8750-MTP-tplg.bin.zst`、`SM8750-QRD-tplg.bin.zst` | 96 件 |
| `qcom/vpu/` | `vpu35_p4.mbn` 2392776（11月27日 14:24） | 1 件 |
| 根目录 | `novatek_ts_csot_3k_fw.bin` 253952、`regulatory.db`(链)、`regulatory.db.p7s`(链)、`-debian`/`-upstream` 各 2、`skl_hda_dsp_generic-tplg.bin` 67152 | `skl_hda_dsp_generic-tplg.bin` = **Intel 遗留杂物**，与本机无关 |

### 1.2 真实固件请求原文（`dmesg`，共 1034 行）

```
[   0.253960] qcom_scm firmware:scm: qseecom: found qseecom with version 0x1402000
[   3.992732] faux_driver regulatory: Direct firmware load for regulatory.db failed with error -2   ← 全局唯一一条失败（§3.9）
[   3.992740] cfg80211: failed to load regulatory.db
[   4.407543] Bluetooth: hci0: QCA Downloading qca/brhbtfw20.tlv
[  27.162800] Bluetooth: hci0: QCA Downloading qca/brhbtnv20.bin
[  27.443736] Bluetooth: hci0: QCA FW build version: BTFW.BRAHMA.2.0.0-00306-PATCHZ-1_DEF NVM_LABEL:BTFW.BRAHMA.2.0.0-00262-PATCHZ-1_DEF
[  27.444165] Bluetooth: hci0: QCA setup on UART is completed          ← tmel_peach_20.elf 阶段通过（Q34 闭环）
[   0.605293] remoteproc remoteproc1: Booting fw image qcom/sm8750/cdsp.mdt, size 5084
[   0.605368] remoteproc remoteproc0: Booting fw image qcom/sm8750/adsp.mdt, size 8364
[   0.794837] remoteproc remoteproc1: remote processor cdsp is now up
[   1.234865] remoteproc remoteproc0: remote processor adsp is now up
[  10.531406] [drm:adreno_request_fw] loaded qcom/gen80000_sqe.fw from new location
[  10.531978] [drm:adreno_request_fw] loaded qcom/gen80000_gmu.bin from new location
[  10.532136] [drm:adreno_request_fw] loaded qcom/gen80000_aqe.fw from new location
[  10.532611] [drm] Loaded GMU firmware v5.1.25
[  10.816759] novatek-nvt36xxx-spi spi0.0: chip identified: starting firmware download
[  11.010755] novatek-nvt36xxx-spi spi0.0: firmware version 1a.01 event protocol f1 PID 6097
[   4.495135] ath12k_wifi7_pci 0000:01:00.0: MSI vectors: 32
[   7.648677] ath12k_wifi7_pci 0000:01:00.0: failed to init core: -110        ← 第一次 MHI 失败
[  33.748294] ath12k_wifi7_pci 0000:01:00.0: fw_version 0x100effff ... QC_IMAGE_VERSION_STRING=WLAN.GNG.1.0-03869-...
[  33.764730] ath12k_wifi7_pci 0000:01:00.0: qmi TME-L power-on hardware-restricted (stock-compatible, continuing)
```

状态机侧（`/sys/class/remoteproc`）：

```
remoteproc0: name=adsp fw=qcom/sm8750/adsp.mdt state=running
remoteproc1: name=cdsp fw=qcom/sm8750/cdsp.mdt state=running
```

iris 面：`cat /proc/device-tree/soc@0/video-codec@aa00000/status` → `disabled`；`dmesg|grep -ci iris` → `0`（固件在机但 DT 不开，Q36 不变）。
蓝牙面：`hciconfig hci0` → `BD Address: 22:22:62:9C:97:58 ... DOWN`（**BD 非全 0 ⇒ 固件链已通**，DOWN 是服务态）。WiFi：`ls /sys/class/net` → `wlan0` 在。

### 1.3 关键 sha256（设备侧实测，全 64 位见 §5 命令）

| 文件 | 设备 sha256（前 16） | 上游/对照 |
|---|---|---|
| `qcom/sm8750/adsp.mbn`（`.zst` 解压） | `bb6f9ea404c6ff52` | 上游 `8572943d99d7f80f`（**不同**） |
| `qcom/sm8750/cdsp.mbn`（`.zst` 解压） | `e046b64ba8a9604c` | 上游 `e046b64ba8a9604c`（**相同**） |
| `qcom/sm8750/adsp_dtb.mbn`（解压） | `1ce7d14a1d7e78af` | 上游 `d4e02b0ee656fd7a`（不同） |
| `qcom/sm8750/cdsp_dtb.mbn`（解压） | `6531a722d3eb6f67` | 上游 `6531a722d3eb6f67`（**相同**） |
| `qcom/gen80000_gmu.bin`（解压） | `1ad8175e6cd01ea7` | 上游 `1ad8175e6cd01ea7`（**相同**） |
| `qcom/gen80000_sqe.fw`（解压） | `30ee3301534f9579` | 上游 `30ee3301534f9579`（**相同**） |
| `qcom/gen80000_aqe.fw`（解压） | `67562ad5baae3a13` | 上游 `67562ad5baae3a13`（**相同**） |
| `qcom/sm8750/gen80000_zap.mbn` | `8cf4191428da9720` | 上游 `0e3ae03f7dd31706`（不同 build，同 12088 B） |
| `qcom/vpu/vpu35_p4.mbn` | `9f6352d526f39bc3` | 上游 `vpu35_p4_s7.mbn` `26c92bd0e62a131e`（2409160 B，**不同/更新**） |
| `qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin` | `c6fffdbc86fbc063` | 无上游；**包内旧版** `3bd05394e92e982f`（16860 B） |
| `ath12k/PEACH/hw2.0/amss.bin` | `848a2f049ccfcdf4` | 无上游（厂商） |
| `ath12k/PEACH/hw2.0/board-2.bin` | `1abee7132dbccb52` | 无上游（厂商 BDF） |
| `ath12k/PEACH/hw2.0/tmel.bin` = `qca/tmel_peach_20.elf` | `a175c8d9d0e6b38b`（两份同 sha） | 无上游 |
| `qca/brhbtfw20.tlv` / `brhbtnv20.bin` / `awinic/y700-gen4-{haptic,speakers}.bin` | `837aea39d33e95a4` / `f91354b0872f1f76` / `6413c0c0eed1edf4` / `9f2a14b4148c7dc4` | 无上游 |
| `novatek_ts_csot_3k_fw.bin` | `413216d0e8738078` | 无上游 |

---

## §2 三方对照（脚本生成）

### 2.1 脚本（本报告唯一工具，`/tmp` 内运行，未入库）

```bash
#!/bin/bash
# fwmatrix.sh — 固件三方对照（需求声明 / 本机 / linux-firmware）
set -u
REPO=${REPO:-/home/xuqianhui/y700-elden}; KDIR=${KDIR:-$REPO/build/daily}; DEV=${DEV:-elden}
WH=/tmp/fwaudit/WHENCE
[ -s "$WH" ] || curl -s -o "$WH" https://gitlab.com/kernel-firmware/linux-firmware/-/raw/main/WHENCE
printf '%-46s %-10s %-6s %s\n' FILE SOURCE DEVICE UPSTREAM
emit() {  # $1=path $2=依据
  local p=$1 why=$2 dev up
  dev=$(ssh -o ConnectTimeout=8 -n "$DEV" "[ -f /lib/firmware/$p ] || [ -f /lib/firmware/$p.zst ] && echo yes || echo no")
  if grep -qxF "File: $p" "$WH" || grep -q "^Link: $p " "$WH"; then up=yes; else up=no; fi
  printf '%-46s %-10s %-6s %s\n' "$p" "$why" "${dev:-?}" "$up"
}
echo "### A. MODULE_FIRMWARE()（唯一权威=内核树）"
( cd "$KDIR" && git grep -h -o 'MODULE_FIRMWARE("[^"]*")' -- drivers/ \
  | sed 's/MODULE_FIRMWARE("//;s/")$//' | grep -E '^(qca/|qcom/|ath12k/|awinic/|novatek)' | sort -u ) \
  | while read -r f; do emit "$f" MODULE_FW; done
( cd "$KDIR" && git grep -h -o 'MODULE_FIRMWARE(ATH12K_FW_DIR "[^"]*")' -- drivers/ \
  | sed 's|MODULE_FIRMWARE(ATH12K_FW_DIR "||;s|")$||' ) | while read -r f; do
  printf '%-46s %-14s %-6s %s\n' "ath12k$f" "MODULE_FW(glob)" "(glob)" "$(grep -q "$f" "$WH" && echo yes || echo no)"; done
echo "### B. DT firmware-name / 驱动写死名 / 用户态名（真实请求集）"
while IFS=' ' read -r p why; do emit "$p" "$why"; done <<'LIST'
qcom/sm8750/gen80000_zap.mbn DT-zap
qcom/gen80000_gmu.bin adreno-catalog
qcom/gen80000_sqe.fw adreno-catalog
qcom/gen80000_aqe.fw adreno-catalog
qcom/vpu/vpu35_p4.mbn iris-desc
qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin audioreach-tplg
awinic/y700-gen4-haptic.bin DT-haptic
awinic/y700-gen4-speakers.bin DT-amp
novatek_ts_csot_3k_fw.bin DT-touch
regulatory.db cfg80211
LIST
for p in adsp adsp_dtb cdsp cdsp_dtb; do emit "qcom/sm8750/$p.mdt" DT-PAS; done
for n in amss m3 board-2 board regdb tmel aux_ucode qdss_trace_config; do emit "ath12k/PEACH/hw2.0/$n.bin" ath12k-hwdir; done
for n in brhbtfw20.tlv brhbtnv20.bin brhperifw20.tlv brhperinv20.bin tmel_peach_20.elf; do emit "qca/$n" bt-code; done
```

依据来源（逐条可查）：`sm8750-lenovo-elden.dts:2084/2098/2118/2128/2586-2587/2646-2647/2671/3030`（DT `firmware-name`）、`sm8750.dtsi:3795`（zap）、`a6xx_catalog.c:2712-2714`（GMU/SQE/AQE）、`iris_platform_vpu3x.c:45-48`（iris desc）、`ath12k/wifi7/hw.c:813-816`（`PEACH/hw2.0`）、`ath12k/hw.h:94-101` + `qmi.h:39`（文件名）、`hci_qca.c:3224-3226` + `btqca` 硬编码（`qca/brhbtfw20.tlv`）、`ipa_main.c:71`（IPA，见 §6.3）。

### 2.2 A 段实测输出（`MODULE_FIRMWARE` 权威集 = 仅 3 条 + 3 条宏拼接 glob）

```
qca/brhperifw20.tlv            MODULE_FW      yes    no
qca/brhperinv20.bin            MODULE_FW      yes    no
qca/tmel_peach_20.elf          MODULE_FW      yes    no
ath12k/QCN9274/hw2.0/*         MODULE_FW(glob) (glob) yes
ath12k/WCN7850/hw2.0/*         MODULE_FW(glob) (glob) yes
ath12k/PEACH/hw2.0/*           MODULE_FW(glob) (glob) no
```

要害：**`qca/brhbtfw20.tlv` / `brhbtnv20.bin` 不在 `MODULE_FIRMWARE` 里**（名字写死在 `btqca` 代码路径），**msm 驱动一条 `MODULE_FIRMWARE` 都没有**，**iris 用平台数据里的 `fwname` 字符串**，**tplg 由用户态读**。⇒ 靠 `MODULE_FIRMWARE` 做门禁最多覆盖 3/27。

### 2.3 B 段实测输出（真实请求集 27 条，本机全在）

```
qcom/sm8750/{adsp,adsp_dtb}.mdt            DT-adsp        yes  no      (上游只有单文件 adsp[_dtb].mbn: yes)
qcom/sm8750/{cdsp,cdsp_dtb}.mdt            DT-cdsp        yes  no      (上游只有单文件 cdsp[_dtb].mbn: yes)
qcom/sm8750/gen80000_zap.mbn             DT-zap         yes  yes
qcom/gen80000_gmu.bin                    adreno-catalog yes  yes
qcom/gen80000_sqe.fw                     adreno-catalog yes  yes
qcom/gen80000_aqe.fw                     adreno-catalog yes  yes
qcom/vpu/vpu35_p4.mbn                    iris-desc      yes  yes   ← 上游经 Link 提供
qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin    audioreach-tplg yes no
ath12k/PEACH/hw2.0/{amss,m3,board-2,board,regdb,tmel,aux_ucode,qdss_trace_config}.bin
                                         ath12k-hwdir   yes  no    （8 条全 yes/no）
qca/{brhbtfw20.tlv,brhbtnv20.bin,brhperifw20.tlv,brhperinv20.bin,tmel_peach_20.elf}
                                         bt-code        yes  no    （5 条全 yes/no）
awinic/y700-gen4-{haptic,speakers}.bin   DT-haptic/amp  yes  no
novatek_ts_csot_3k_fw.bin                DT-touch       yes  no
regulatory.db                            cfg80211       yes  no    ← 属 wireless-regdb，不属 linux-firmware
```

上游明文（`WHENCE` 原文，逐条可 grep）：
`qcom/gen80000_aqe.fw`/`qcom/gen80000_gmu.bin`/`qcom/gen80000_sqe.fw`（:7342-7346，`qcom/sm8750/gen80000_zap.mbn` v0.02 :7348）、
`qcom/vpu/vpu35_p4_s7.mbn` + `Link: qcom/vpu/vpu35_p4.mbn -> vpu35_p4_s7.mbn` + `Version: VIDEO.VPU.3.5-0040`（:7188-7191）、
`qcom/sm8750/adsp.mbn`(LPAIDSP.HT.1.2.c2-00080-PAKALA-1)+`cdsp.mbn`(CDSP.HT.3.1-00889-PAKALA-1)（:7700-7711）、
ath12k 只有 `IPQ5424/QCC2072/QCN9274/WCN7850`（API tree 实测），**无 `PEACH`**；`qca` 段 WCN7850 = `hmtbtfw20.tlv`/`hmtnv20.bin`（HAMILTON，:5499-5507），**无 `brh*`、全库无 `tmel`**；`awinic` 只有 8 个 `aw88399_acf_17aa39*`；**全库无 `novatek`**。

### 2.4 版本差异三点（必须点名）

| 项 | 本机 | 上游 | 处理 |
|---|---|---|---|
| ADSP 构建 | `LPAIDSP.HT.1.2.c1-00450-PAKALA-2`（`20260223_215447`） | `LPAIDSP.HT.1.2.c2-00080-PAKALA-1` | 版本分支不同；本机件已被 TZ 接受并起，**不要盲换** |
| ADSP DTB | `1ce7d14a…`（split 分段） | `d4e02b0e…`（167736 B） | 与 ADSP 主体同步差异，成对替换才有意义 |
| iris VPU | `vfw-3.5:rel0030`（2392776 B） | `VIDEO.VPU.3.5-0040`（2409160 B） | 上游更新一代同代固件，且**用驱动要的同一文件名**（Link） |

---

## §3 缺失/不一致逐项定因（9 项）

**3.1 ath12k `PEACH/hw2.0/*`（8 件）— 厂商签名 + 设备专属 BDF，上游无路径**
驱动 `wifi7/hw.c:816` 硬编码 `.dir = "PEACH/hw2.0"`，`pci.c:1859` 还给了 `MODULE_FIRMWARE(... "/PEACH/hw2.0/*")` 的 glob，但 linux-firmware **没有 `ath12k/PEACH` 目录**（只有 WCN7850/IPQ5424/QCN9274/QCC2072）⇒ 这是「上游驱动已支持 PEACH、上游固件未跟进」的真缺口。
来源：stock `modem_a/image/peach/`（`amss20.bin`→`amss.bin`、`phy_ucode20.elf`→`m3.bin`、`bdwlan.*`→`board-2.bin`/`board.bin`、`tmel_peach_20.elf`→`tmel.bin`）。**`board-2.bin` 是设备专属校准 BDF（2253964 B，与上游 WCN7850 的通用 BDF 不是一件东西），不可分发**。
判定：**可取（本机）+ 不可分发（对外）**。对外只登记缺口（`TASKS/README.md` §7 口径），不做「用 WCN7850 通用 BDF 顶替」的尝试（`amss.bin` 的 `-20` 后缀版本就不兼容，DEVICE §1.2 已记 `-110` 实录）。

**3.2 `qca/` WCN7861（BRAHMA）5 件 — 上游无同名、无 tmel**
`WHENCE` 里 WCN7850 段是 `hmt*`（HAMILTON），`ath12k` 段也无 brahma；**全库 `grep -i tmel` 只有 atmel/wilc1000**（同名巧合）。本机 `qca/` 5 件全部来自 stock（`bluetooth_a/image/`+`modem_a/image/tmel_peach_20.elf`）。
判定：**厂商签名不可分发**；Q34 的「补文件」只解决本机可用性，上游缺口照旧（登记为待办，非本报告范围）。

**3.3 触屏 `novatek_ts_csot_3k_fw.bin` — 上游全库无 novatek**
如需上游化，触屏固件不可能进 linux-firmware（面板批次专属、不可再分发）⇒ 上游方向只能是「驱动允许包外提供/允许无固件运行」，已在 lane A #5 的「扩展主线 `novatek-nvt-ts`」路线里。

**3.4 ADSP/CDSP 形态差异（split `.mdt` vs 单文件 `.mbn`）**
- 本机用 split（`.mdt` + `.bNN`）——这是 **stock 的实际形态**，且 DEVICE §1.2 有实录：单文件 `cdsp_dtb.mbn` 被 TZ 以 **-22（PAS init on DTB）** 拒绝。
- 上游 linux-firmware 只提供**单文件** `adsp.mbn`/`cdsp.mbn`/`*_dtb.mbn`；我们**也**在盘里放了 stock 单文件（`adsp.mbn.zst` 等）但**驱动不读**（DT 指名 `.mdt`）。
- CDSP/CDSP_DTB 与上游**逐字节相同**⇒ 上游件就是同一份厂商构建；ADSP 不同分支。
判定：**不是缺件、不是名字错**，是「TZ 只吃 split」+「上游只发单文件」的结构性差异。改 `firmware-name` 指向 `.mbn` 需一次上机验证（有 -22 的先例，风险已知）。

**3.5 GPU 同名文件两份、其中一份驱动不读（路径陷阱）**
设备 dmesg 明写 `loaded qcom/gen80000_{sqe,gmu,aqe} from new location` ⇒ 生效的是 `qcom/*.zst`。而 `qcom/sm8750/gen80000_{sqe.fw,aqe.fw}` 是**另一份旧版**（sqe: `9c8f009bea112d7c` 111892 B，= `backup/fw/gen80000_sqe.fw`；生效件解压后 111476 B = `30ee3301534f9579` 与上游相同），`adreno_request_fw` 的 legacy 回退是 **`gen80000_gmu.bin`（无 `qcom/` 前缀）**，**永远不是 `qcom/sm8750/gen80000_gmu.bin`**。
⇒ `patches/distro/mobian-20261123/droid-juicer/lenovo,elden.toml` 把 gmu/sqe/aqe 的 `destination` 写成 **`qcom/sm8750`** 是**错的**（只有 zap 在那个目录，因为 DT 点名）；纯 droid-juicer 装机（无 elden-firmware）会**GPU 起不来**。修法：`destination = "qcom"`（或保留两处，但注释写清只有 `qcom/` 生效）。

**3.6 `awinic/y700-gen4-haptic.bin` 是自定件（无厂商源件）**
`backup/fw/README.md` 原文：「`awinic/y700-gen4-haptic.bin`, `awinic/y700-gen4-speakers.bin`（vendor 里未找到同名，待核）」；`patches/distro/mobian-20261121/droid-juicer/README.md` §C3 列为**自定/自编资产**（不属抽取）。⇒ 该文件**不由 droid-juicer 生产**，必须由我方包分发；上游无对应条目（awinic 只有 aw88399 的 8 个 ACF）。speakers 件则是 vendor `aw882xx_acf.bin` 改名（内容含 `aw88461`）。

**3.7 tplg 自编 + 版本漂移**
本机 18236 B（11月20日重建，sha `c6fffdbc…`）；包内 16860 B（sha `3bd05394…`）。上游只有 `SM8750-MTP/QRD-tplg.bin`（非本板音路）。
判定：**自制、可上游**（建议布局 `qcom/sm8750/LENOVO/<model>/…-tplg.bin` + 顶层 Link，与 x1e80100/sc8280xp 同风格）；当前包是旧版，**重打包装车前必须 re-stage**。

**3.8 SSC 传感器 registry：在机布局已漂移，打包门禁查的是旧路径**
- 打包脚本 `rootfs/debian/elden-firmware/build.sh` 的 `qcom_stage()` 硬查 `$STAGE/usr/share/qcom/sm8750/LENOVO/TB322FC/sensors/{sns_reg.conf,config/,registry/}`（门禁 A'），deb（10-28）里也确实有 **148 个** `/usr/share/qcom` 条目。
- 在机实测：`ls -ld /usr/share/qcom` → **没有那个文件或目录**；`hexagonrpcd-patched` 的 cmdline 是 **`-R /var/lib/hrpcd-root/`**，实件 `du -sh` = **880 K**，`sensors/registry/registry/` 下有 `pakala_icm4x6xa_0.json.*`、`sx932x`、`mmc56x3x`… 等真实 registry。
⇒ 门禁 A' 现在校验的是**一个在机上不存在的路径**（重打包装车会把 148 个文件放到没人读的位置），且**真正被读的 `/var/lib/hrpcd-root` 完全不在任何门禁里**。这是本轮发现的**打包面实缺口**（不影响当前运行，只影响重装可复现）。

**3.9 `regulatory.db` 启动 `-2`：不是缺件**
`readlink -f /lib/firmware/regulatory.db` → `/usr/lib/firmware/regulatory.db-debian`（**存在**，6380 B）。失败发生在 `[3.992732]`，与 `[3.992949] No soundcards found` 同一秒，早于 root switch/服务起来；符号链两跳（`/lib/firmware/regulatory.db` → `/etc/alternatives/regulatory.db` → `/lib/firmware/regulatory.db-debian`）。
定因（**未证实，两选一**）：① 请求发生在 initramfs 阶段，`/etc/alternatives` 那跳当时不存在；② `firmware_class` 对该两跳链的解析时机问题。
影响：`cfg80211` 退回内置 world regdomain（信道/功率受限，不是致命）。验证法见 §5.6（`iw reg get` 需先装 `iw`）。

---

## §4 打包与门禁现状（A2 实测）

### 4.1 门禁 A2 当前**静默失效**（P1 级）

```
$ timeout 120 bash rootfs/debian/elden-firmware/build.sh --check
源树文件数: 122
  （remote 模式：A2 在 stage/deb 阶段对暂存树校验）
```

- `build.sh:234` `local tree=${KDIR:-$ROOT/build/vk151}`；实测 `ls -d build/vk151` → **`No such file or directory`**（当前树是 `build/daily`、`elden-tree`、`g7-tree`、`g7a-tree`、`g7b-vk185`）。
- 于是 `driver_required()` 走 `if [ ! -e "$tree/.git" ]; then say "WARN ... A2 无法校验"; return 0; fi` ⇒ **A2 恒「通过」**。这正是该函数注释里警告过的「门禁自己静默跳过，比没有门禁更危险」的同一类问题再次发生（只是换了触发原因：路径漂移而非 worktree 判断）。
- 修法（最小）：`KDIR` 默认值改为 `$ROOT/build/daily`，并在 `--check` 的 remote 模式下**显式打印 A2 状态**（现在是「在 stage/deb 阶段校验」一句带过，`--check` 单独跑看不到 A2 结果）。

### 4.2 门禁覆盖面（实测 `driver_required()` 输出 = 3 条）

| 门禁 | 依据 | 覆盖条数 | 覆盖的 | **不覆盖** |
|---|---|---|---|---|
| **A**（DT `firmware-name`） | `sm8750-lenovo-elden.dts` + `sm8750.dtsi` + `name-map.tsv` | 10 | `adsp.mdt`/`adsp_dtb.mdt`/`cdsp.mdt`/`cdsp_dtb.mdt`/`gen80000_zap.mbn`/`novatek_*`/`awinic/*2`/`brhbtnv20.bin`+`brhbtfw20.tlv`（经 name-map） | GPU gmu/sqe/aqe、ath12k 8 件、iris vpu、tplg、`qca/{brhperifw,brhperinv,tmel_peach}`（DT 只写 2 个 BT 名） |
| **A2**（`MODULE_FIRMWARE`） | `hci_qca.c:3224-3226` | **3** | `qca/brhperifw20.tlv`、`brhperinv20.bin`、`tmel_peach_20.elf` | 见 §2.2：msm 零声明、iris 用 desc 字符串、ath12k 用**宏拼接 glob**（现正则抓不到）、brhbtfw/brhbtnv 写死在代码 |
| **A'**（传感器树） | `paths-qcom.txt` | 1 树（3 项） | `/usr/share/qcom/sm8750/LENOVO/TB322FC/sensors/**` | 在机真实路径 `/var/lib/hrpcd-root`（§3.8） |
| B/C/D（无 `.bak`/条目数/解包复检） | — | — | 结构完整性 | 与固件集合无关 |

⇒ **27 条真实需求里，三条门禁并集只覆盖 13 条，14 条无人管**：`qcom/gen80000_{gmu.bin,sqe.fw,aqe.fw}`、`ath12k/PEACH/hw2.0/*`（8）、`qcom/vpu/vpu35_p4.mbn`、`qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin`、`regulatory.db`。建议把 A2 换成「**需求集清单文件**（本报告 §2.3 的 27 行）+ 每条写依据来源」，脚本按清单逐条查在否 —— 比猜 `MODULE_FIRMWARE` 覆盖得全，也便于 review。

### 4.3 在机状态 vs `out/debian/elden-firmware_1.0~20261028_all.deb`

```
$ dpkg -S /lib/firmware/qcom/sm8750/adsp.mdt      → dpkg-query: 没有找到…相匹配的路径
$ dpkg -l | grep -i elden                          → （空）
$ comm 设备清单(121) 包内清单(122，含 7 个目录条目)
  仅在机有: qcom/vpu/vpu35_p4.mbn, regulatory.db*, skl_hda_dsp_generic-tplg.bin
  仅包内有: （仅 7 个目录条目）
```

结论：**在机 `/lib/firmware` 是 rsync/脚本手工铺的，deb 从未安装**（无 dpkg 归属）。内容上两者对齐，**唯一差异 = `qcom/vpu/vpu35_p4.mbn`（11-27 手工放入，包内没有）**，另加 **tplg 同路径不同内容**（§3.7）。

---

## §5 复现命令

```bash
# 5.1 设备只读清单 / 请求原文 / 状态机
ssh elden 'cd /lib/firmware && find . -type f | sed "s|^\./||" | LC_ALL=C sort'
ssh elden 'dmesg | grep -iE "firmware|Direct firmware load|Booting fw image|adreno_request_fw"; dmesg | grep -ci iris'
ssh elden 'cd /lib/firmware/qcom/sm8750 && ls adsp.b[0-9][0-9] | wc -l; cat /proc/device-tree/soc@0/video-codec@aa00000/status'
ssh elden 'for d in /sys/class/remoteproc/*; do echo "$d $(cat $d/name) $(cat $d/firmware) $(cat $d/state)"; done'
# 5.2 sha256（含 .zst 解压后比对上游）
ssh elden 'cd /lib/firmware && sha256sum qcom/sm8750/gen80000_zap.mbn qcom/vpu/vpu35_p4.mbn \
  ath12k/PEACH/hw2.0/{amss,m3,board-2,board,regdb,tmel,aux_ucode}.bin qca/* awinic/* novatek_ts_csot_3k_fw.bin'
ssh elden 'cd /lib/firmware/qcom/sm8750 && for f in adsp.mbn.zst cdsp.mbn.zst adsp_dtb.mbn.zst cdsp_dtb.mbn.zst; do
  printf "%s " $f; zstd -dc $f | sha256sum | cut -d" " -f1; done'
ssh elden 'cd /lib/firmware/qcom/sm8750 && zstd -dc adsp.mbn.zst | strings | grep -m1 QC_IMAGE_VERSION_STRING'
# 5.3 上游对照（linux-firmware）
curl -s -o /tmp/WHENCE https://gitlab.com/kernel-firmware/linux-firmware/-/raw/main/WHENCE
grep -nE 'vpu35_p4|gen80000|qcom/sm8750/|PEACH|WCN7850|brh|novatek|awinic' /tmp/WHENCE
curl -s "https://gitlab.com/api/v4/projects/kernel-firmware%2Flinux-firmware/repository/tree?path=ath12k&per_page=100&ref=main"
# 5.4 三方矩阵（脚本见 §2.1）：bash /tmp/fwaudit/fwmatrix.sh
# 5.5 门禁实态
bash rootfs/debian/elden-firmware/build.sh --check
cd build/daily && git grep -h -o 'MODULE_FIRMWARE("[^"]*")' -- drivers/ \
  | sed 's/MODULE_FIRMWARE("//;s/")$//' | grep -E '^(qca/|qcom/|ath12k/|awinic/|novatek)' | sort -u
ls -d build/vk151 || echo "A2 默认 KDIR 不存在 ⇒ A2 静默跳过"    # 在仓库根跑
# 5.6 regulatory.db 定因（需在设备装 iw）
ssh elden 'readlink -f /lib/firmware/regulatory.db; ls -l /etc/alternatives/regulatory.db'
ssh elden 'dmesg | grep -iE "regulatory|regdb"'
# 5.7 传感器树布局
ssh elden 'ls -ld /usr/share/qcom; tr "\0" " " < /proc/$(pgrep -x hexagonrpcd-pat|head -1)/cmdline; echo; du -sh /var/lib/hrpcd-root'
```

---

## §6 盲区

1. **上游单文件 `.mbn` 能否在本机 TZ 下替代 split `.mdt`** —— 未验证（有 `cdsp_dtb.mbn` 单文件被 TZ 拒 -22 的先例）。要证只能上机（改 DT `firmware-name` + 重编 DTB + 一次重启）；风险 = 起不来需回滚 boot.img。
2. **iris 上游件（`VIDEO.VPU.3.5-0040`）与本机 TZ 的签名兼容性** —— 只能上机（Q36 路径）；本轮只确认「同代、同名、可再分发，且比本机 vendor 件新」。HFI 版本是否匹配驱动仍无主机侧判据（驱动不校验，只会 1000 ms 超时）。
3. **IPA 固件** —— `CONFIG_QCOM_IPA=m` 且默认名 `ipa_fws.mdt`，但 `sm8750.dtsi` **无 ipa 节点**、`lsmod` 无 `ipa`、`/lib/firmware` 无该件；上游也只有 `qcom/qcm6490/ipa_fws.mbn`。**只要不把 IPA 节点 enable 就不构成需求**，enable 那天就是新缺口（本报告未立项）。
4. **`ath12k/PEACH/hw2.0/qdss_trace_config.bin`（6237 B，可执行位）** 来源未逐字节溯源（droid-juicer toml 写 `qdss_trace_config_v2.cfg` 改名）；它只影响 coredump 抓取，不影响连通，本轮未深挖。
5. **`regulatory.db` 失败机理**未坐实（§3.9 两选一）；缺 `iw` 无法看 `iw reg get`，本轮不做设备写入/装包。
6. **`qcom/sm8750/{adspr,adsps,adspua,adspuo}.jsn` 与 `cdspr.jsn`** 上游同名同件（`RawFile:`），未逐字节比对（只比了 adsp/cdsp 主体与 dtb）；PDR 域数量差异的后果未评估。
7. **其它单元（U2）** 的固件差异未验（只在 U1/`elden` 上取证）；按「设备等价」原则应一致，但 `board-2.bin` 这类校准件**可能按单元不同**（未取证）。
8. **固件许可合规面**（对外分发 WCN7861/novatek/awinic 件的法律边界）只做「不可再分发」标注，未做法务级判定。
