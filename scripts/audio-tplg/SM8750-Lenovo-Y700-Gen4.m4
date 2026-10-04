# TB322FC (elden/SM8750) — AudioReach topology: Lenovo-Y700-Gen4
# SPDX-License-Identifier: BSD-3-Clause
#
# 目标：让 MultiMedia1 (FE) 播放经 ADSP 图输出到 Secondary MI2S (BE)，
# 外接两片 Awinic AW88461 (I2S 功放) 出声。
# 参考：linux-msm/audioreach-topology 的
#   Google-SC7180-WSA-Speakers-SEC-I2S-VA-DMIC-WCD-TX3.m4（SECONDARY_MI2S_RX 用法）
#   SM8550-HDK.m4（SM8750 系列被 CMake 复用为该 base）
# 设备 DT：link-name "Secondary MI2S"，cpu=<&q6apmbedai SECONDARY_MI2S_RX>，codec=<aw88461 L/R>
include(`audioreach/audioreach.m4')
include(`audioreach/stream-subgraph.m4')
include(`audioreach/device-subgraph.m4')
include(`util/route.m4')
include(`util/mixer.m4')
include(`audioreach/tokens.m4')
#
# Stream SubGraph for PCM Playback (MultiMedia1)
#   [WR_SH] -> [PCM DEC] -> [PCM CONV] -> [VOL] -> [LOG]
#
STREAM_SG_PCM_ADD(audioreach/subgraph-stream-vol-playback.m4, FRONTEND_DAI_MULTIMEDIA1,
	`S16_LE', 48000, 48000, 2, 2,
	0x00004001, 0x00004001, 0x00006001, `110000')
dnl
dnl Stream SubGraph for PCM Playback (MultiMedia2) — 备用第二路
STREAM_SG_PCM_ADD(audioreach/subgraph-stream-vol-playback.m4, FRONTEND_DAI_MULTIMEDIA2,
	`S16_LE', 48000, 48000, 2, 2,
	0x00004002, 0x00004002, 0x00006010, `110000')
#
# Device SubGraph for Secondary MI2S RX (BE)
#   Mixer -> [LOG] -> [I2S EP]
#
dnl DEVICE_SG_ADD(m4, stream-name, stream-dai-id,
#	dnl   format, min-rate, max-rate, min-ch, max-ch,
#	dnl   interface-type, interface-index, sd-line-idx, data-format,
#	dnl   sg-iid, cont-iid, mod-iid, dai-name)
# SD line: the amp I2S DIN is on gpio124 = i2s1_data1 = SD1 (confirmed by the
# stock DT dump, probe/result/devicetree.dts).  The original SD0 copy from the
# Google SC7180 template drove gpio122 instead -> amp received no data.
DEVICE_SG_ADD(audioreach/subgraph-device-i2s-playback.m4, `Secondary', SECONDARY_MI2S_RX,
	`S16_LE', 48000, 48000, 2, 2,
	LPAIF_INTF_TYPE_LPAIF, I2S_INTF_TYPE_SECONDARY, SD_LINE_IDX_I2S_SD1, DATA_FORMAT_FIXED_POINT,
	0x00004005, 0x00004005, 0x00006050, `SECONDARY_MI2S_RX')
dnl
#
# Device SubGraph for WCD939x RX (headphone/earpiece) — RX_CODEC_DMA_RX_0
#   Mixer -> [LOG] -> [CODEC_DMA RX0 EP] -> RX macro (swr1) -> WCD939x DAC -> HPHL/HPHR
#   interface LPAIF_INTF_TYPE_RXTX / CODEC_INTF_IDX_RX0, as in the upstream
#   Google-SC7180-...-WCD-TX3.m4 and SM8750-MTP.
DEVICE_SG_ADD(audioreach/subgraph-device-codec-dma-playback.m4, `RX_CODEC_DMA_RX_0', RX_CODEC_DMA_RX_0,
	`S16_LE', 48000, 48000, 2, 2,
	LPAIF_INTF_TYPE_RXTX, CODEC_INTF_IDX_RX0, 0, DATA_FORMAT_FIXED_POINT,
	0x00004006, 0x00004006, 0x00006060, `RX_CODEC_DMA_RX_0')
dnl
STREAM_DEVICE_PLAYBACK_MIXER(SECONDARY_MI2S_RX, ``SECONDARY_MI2S_RX'', ``MultiMedia1'', ``MultiMedia2'')
STREAM_DEVICE_PLAYBACK_MIXER(RX_CODEC_DMA_RX_0, ``RX_CODEC_DMA_RX_0'', ``MultiMedia1'', ``MultiMedia2'')
STREAM_DEVICE_PLAYBACK_ROUTE(SECONDARY_MI2S_RX, ``SECONDARY_MI2S_RX Audio Mixer'', ``MultiMedia1, stream0.logger1'', ``MultiMedia2, stream1.logger1'')
STREAM_DEVICE_PLAYBACK_ROUTE(RX_CODEC_DMA_RX_0, ``RX_CODEC_DMA_RX_0 Audio Mixer'', ``MultiMedia1, stream0.logger1'', ``MultiMedia2, stream1.logger1'')

#
# Capture: 4x DMIC on the VA macro (FE MultiMedia3)
#   [RD_SH] <- [PCM ENC] <- [PCM CONV] <- [MFC] <- [LOG]  - Mixer -
#   -> VA codec-DMA TX0 -> DMIC
#
STREAM_SG_PCM_ADD(audioreach/subgraph-stream-capture.m4, FRONTEND_DAI_MULTIMEDIA3,
	`S16_LE', 48000, 48000, 2, 2,
	0x00004003, 0x00004003, 0x00006020, `110000')
dnl
dnl WCD939x TX3 Capture (built-in analog mic: AMIC -> WCD ADC -> SWR2 -> TX macro)
dnl   interface LPAIF_INTF_TYPE_RXTX / CODEC_INTF_IDX_TX3, as in SM8550-HDK.m4
dnl   (VA DMIC path removed: this board has no DMIC, mic is analog on WCD939x)
DEVICE_SG_ADD(audioreach/subgraph-device-codec-dma-capture.m4, `TX_CODEC_DMA_TX_3', TX_CODEC_DMA_TX_3,
	`S16_LE', 48000, 48000, 1, 2,
	LPAIF_INTF_TYPE_RXTX, CODEC_INTF_IDX_TX3, 0, DATA_FORMAT_FIXED_POINT,
	0x00004008, 0x00004008, 0x00006080, `TX_CODEC_DMA_TX_3')
dnl
STREAM_DEVICE_CAPTURE_MIXER(FRONTEND_DAI_MULTIMEDIA3, ``TX_CODEC_DMA_TX_3'')
STREAM_DEVICE_CAPTURE_ROUTE(FRONTEND_DAI_MULTIMEDIA3, ``MultiMedia3 Mixer'', ``TX_CODEC_DMA_TX_3, device120.logger1'')
