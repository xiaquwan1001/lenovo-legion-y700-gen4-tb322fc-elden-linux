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
dnl   format, min-rate, max-rate, min-ch, max-ch,
dnl   interface-type, interface-index, sd-line-idx, data-format,
dnl   sg-iid, cont-iid, mod-iid, dai-name)
DEVICE_SG_ADD(audioreach/subgraph-device-i2s-playback.m4, `Secondary', SECONDARY_MI2S_RX,
	`S16_LE', 48000, 48000, 2, 2,
	LPAIF_INTF_TYPE_LPAIF, I2S_INTF_TYPE_SECONDARY, SD_LINE_IDX_I2S_SD0, DATA_FORMAT_FIXED_POINT,
	0x00004005, 0x00004005, 0x00006050, `SECONDARY_MI2S_RX')
dnl
STREAM_DEVICE_PLAYBACK_MIXER(SECONDARY_MI2S_RX, ``SECONDARY_MI2S_RX'', ``MultiMedia1'', ``MultiMedia2'')
STREAM_DEVICE_PLAYBACK_ROUTE(SECONDARY_MI2S_RX, ``SECONDARY_MI2S_RX Audio Mixer'', ``MultiMedia1, stream0.logger1'', ``MultiMedia2, stream1.logger1'')
