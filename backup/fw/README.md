# 已采集固件资产（2026-09-28，主机会话 B1）

来源：真机 mainline Alpine 内挂载 UFS 分区采集（`probe.sh`），以及主机 EDL 包。

| 目录 | 来源分区 | 关键文件 | 用途 |
|---|---|---|---|
| `vendor/` | super→vendor_a (ext4, 通过 losetup) | `firmware/novatek_ts_csot_3k_fw.bin`(+mp)、`firmware/wlan/qca_cld/*`、`firmware/100.._*_RTP.bin`(触觉)、`gpu/kbc`、`etc/wifi/*`、`build.prop` | 触屏固件、触觉(aw86927)、WiFi 配置 |
| `modem/` | LUN4 modem_a (vfat) `image/` | `adsp.mdt`+`adsp.bXX`+`adsp_dtb.*`、`cdsp.*`、`peach/amss.bin`+`tmel_peach_*.elf`+`bdwlan.eXX` | ADSP/CDSP 固件、WiFi(ath12k/Peach) 固件+BDF |
| `bluetooth/` | LUN4 bluetooth_a (vfat) `image/` | `brhbtfw20.tlv`、`brhbtnv20.bin`、`brhperifw20.*` | BT (WCN7861/brh) |
| `dspso/` | LUN4 dsp_a (ext4) | `adsp/`、`cdsp/`、`sdsp/`(共享库) | ADSP/CDSP 用户态库 |
| `gen80000_*` | 设备 vendor (TWRP 拉取) | GPU zap/sqe/gmu/aqe | Adreno 830 |

## 内核 DT 期望的固件路径（sm8750-lenovo-elden.dts）

- ADSP: `/lib/firmware/qcom/sm8750/adsp.mdt` + `adsp_dtb.mdt`（注意：现有 rootfs 放的是 `adsp.mbn.zst`，命名不符，音频未起可能因此）
- CDSP: `qcom/sm8750/LENOVO/elden/cdsp.mbn`（DT 里 `status=disabled`）
- 触屏: `novatek_ts_csot_3k_fw.bin`
- BT: `brhbtnv20.bin`, `brhbtfw20.tlv`
- 触觉/扬声器: `awinic/y700-gen4-haptic.bin`, `awinic/y700-gen4-speakers.bin`（vendor 里未找到同名，待核）
- WiFi: DT `wifi@0 compatible="pci17cb,110e"`（ath12k），需把 `peach/amss.bin` 等转成 ath12k 命名（`amss.bin`/`m3.bin`/`board-2.bin`），具体命名待验证

详细分区/LP 映射见 `~/y700-elden/probe/result/lp-map.txt` 与 `partitions.txt`。

## 补充：音频相关（2026-09-28 夜）

- **功放 ACF**：DT 要作者自定义 `awinic/y700-gen4-speakers.bin`；
  vendor 的 `firmware/aw882xx_acf.bin` **内容就是 aw88461 的 ACF**（含 "aw88461"/"A1901" 字样）。
  拷成 `awinic/y700-gen4-speakers.bin` 后两个 aw88461（i2c 9-0034/9-0037）probe 成功。
- **触觉**：`firmware/aw8697_haptic.bin` 喂 aw86927 驱动报 `-EINVAL sram init`（格式不符）；
  vendor 还有 `firmware/1xx_*_RTP.bin` 波形集合可作后续研究。
- **AudioReach 拓扑**：mainline 要 `qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin`（本地无，需自编）；
  暂以 linux-firmware 的 `SM8750-MTP-tplg.bin.zst` 顶替可创建 card0，但 `speaker-test` 打不开（缺 MI2S 后端）。
  vendor 参考：`/etc/MM_audio_playback_capture_v2.0.cfg`。
