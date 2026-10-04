#!/bin/sh
# audio-alsa-init.sh — put the Lenovo-Y700-Gen4 (TB322FC/elden) sound card into
# a usable default state for *bare ALSA*, i.e. when no PipeWire/UCM session is
# running (RAM/initramfs bring-up, headless testing, recovery shell).
#
# Without this, every DAPM/mixer control comes up muted/off on a fresh boot and
# a plain `aplay`/`arecord -D hw:0,0` is silent, even though the card registers.
#
# This only sets controls; it does not open any PCM, so it is safe to run
# alongside PipeWire/ UCM (which re-apply the same values per device).  It is
# idempotent and quiet.
#
# Audio topology (see archive/topics/AUDIO-SDLINE-2026-10-04.md):
#   playback: MultiMedia1 -> SECONDARY_MI2S_RX -> 2x Awinic AW88461 speakers
#   capture : WCD939x analog mic AMIC1 -> ADC2 -> DEC0 -> SWR mic -> TX3
#
# Usage: audio-alsa-init.sh [playback|capture|all]   (default: all)
set -u

MODE="${1:-all}"
CARD="${ALSA_CARD:-0}"

# Playback gain applied by default.  The AW88461 hardware range is 0..1023,
# but with no PipeWire software attenuator in the bare-ALSA case 1023 is very
# loud on the tablet speakers; keep a conservative default.
PLAYBACK_VOLUME="${ALSA_PLAYBACK_VOLUME:-400}"

# Wait for the card to be registered (modules are async on some boots).
i=0
while [ ! -r "/proc/asound/card${CARD}/id" ] && [ "$i" -lt 100 ]; do
	sleep 0.1; i=$((i + 1))
done
if [ ! -r "/proc/asound/card${CARD}/id" ]; then
	echo "[audio-alsa-init] card${CARD} not present, nothing to do" >&2
	exit 0
fi

# cset: apply a control by name; never fail the script if a control is absent.
cset() {
	if ! amixer -c "$CARD" -q cset name="$1" "$2" >/dev/null 2>&1; then
		echo "[audio-alsa-init] WARN: control '$1' -> '$2' failed" >&2
	fi
}

playback() {
	# Connect the Secondary MI2S playback backend and lift the AW88461 gains.
	# NB: the 'Audio Mixer MultiMediaX' route controls are stereo booleans whose
	# channel-0 write is what the ASoC route keys on; setting the single value
	# 'on' is the verified-working form (matches the UCM EnableSequence).
	cset "SECONDARY_MI2S_RX Audio Mixer MultiMedia1" on
	cset "Left Playback Volume" "$PLAYBACK_VOLUME"
	cset "Right Playback Volume" "$PLAYBACK_VOLUME"
}

# getv: read back a control by name (amixer sget-by-name is unreliable for the
# DAPM controls on this card, so resolve the numid from the control list).
getv() {
	n=$(amixer -c "$CARD" controls 2>/dev/null | grep "name='$1'" | head -n1 \
		| sed -n 's/^numid=\([0-9]*\).*/\1/p')
	[ -n "$n" ] && amixer -c "$CARD" cget numid="$n" 2>/dev/null \
		| sed -n 's/^[[:space:]]*: values=//p' | head -n1
}

capture() {
	# WCD939x AMIC1 -> ADC2 -> DEC0 -> TX SMIC MUX0 -> TX3 (MultiMedia3).
	cset "MultiMedia3 Mixer TX_CODEC_DMA_TX_3" on
	cset "ADC2 MUX" "CH2_AMIC1"
	cset "ADC2 Switch" on
	cset "ADC2_MIXER Switch" on
	cset "ADC2 Volume" 20
	cset "TX DEC0 MUX" "SWR_MIC"
	cset "TX SMIC MUX0" "SWR_MIC1"
	cset "TX_AIF1_CAP Mixer DEC0" on
}

case "$MODE" in
	playback) playback ;;
	capture)  capture  ;;
	all)      playback; capture ;;
	*) echo "usage: $0 [playback|capture|all]" >&2; exit 2 ;;
esac

# Show the resulting playback route as a one-line health marker.
mm1=$(getv "SECONDARY_MI2S_RX Audio Mixer MultiMedia1")
l=$(getv "Left Playback Volume")
r=$(getv "Right Playback Volume")
echo "[audio-alsa-init] mode=$MODE mm1[$mm1] L[$l] R[$r]"
