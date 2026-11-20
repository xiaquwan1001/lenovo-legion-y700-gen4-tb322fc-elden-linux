# #698 「驱动在、功能没了」——重建根丢的是**资产**（tplg / UCM2 / 取证工具），不是驱动

- 日期：2026-11-20 23:20–23:30（U2 HA2EXB0E）
- 触发：用户指出「恢复历史最佳还包括驱动，比如现在缺马达和音频」。

## 1. 音频：卡在、声不在（三层缺件）

现状（修前）：`/proc/asound/card0` = `LenovoY700Gen4`、`snd-sc8280xp` bound、`wcd939x_codec` 绑上 SoundWire，
但 PipeWire 只有一个 Sink = **`虚拟输出`**（`auto_null` 兜底），`amixer -c0 controls` = **0**，dmesg 出

```
MultiMedia1 Playback: ASoC: no backend DAIs enabled for MultiMedia1 Playback,
   possibly missing ALSA mixer-based routing or UCM profile
```

三件缺件（全部是**自研资产**，发行版包不含）：

| 缺件 | 正确位置 | 来源 |
|---|---|---|
| AudioReach topology | `/lib/firmware/qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin` | `scripts/audio-tplg/out/`（18 236 B，含 SD0→SD1 修正，PITFALLS #90） |
| UCM2 verb/设备的 conf | `/usr/share/alsa/ucm2/Qualcomm/sm8750/Lenovo-Y700-Gen4/HiFi.conf` + `…/conf.d/sm8750/Lenovo-Y700-Gen4.conf` | `scripts/audio-ucm/`（`install.sh` 头注原话：「A rebuilt rootfs needs this again」） |
| `alsa-utils`（`amixer`） | 包 | `audio-alsa-init.sh` 的 `cset` 全靠它；缺了只打 WARN 不失败 ⇒ **静默跳过全部路由** |

补后判据（实测）：`wpctl status` 的 Sink = `内置音频 Speaker playback`（vol 0.40）、Source = `Internal analog
microphone (WCD939x AMIC1)`；`audio-alsa-init.sh` 输出 `mode=all mm1[on,off] L[400] R[400]`；
`pw-play tone.wav` rc=0。冷起后仍在（UCM/tplg 落盘即持久，不需要 initramfs hook——tplg 是开图时按需加载的）。

## 2. 触觉：驱动在、工具不在（且芯片名与驱动名不同）

- 驱动 = `aw86927` + 上游 `haptics-v3-20261118` 系列（**硬件是 AW86937**，见 `patches/upstream/haptics-v3-…/0004-*`），
  内核注册两枚 `aw86927-haptics` 的 input 节点（`/sys/class/input/event{2,3}`，`capabilities/ff` 有 FF）。
- 缺的是**宿主基线工具** `ffrumble`（`scripts/ffrumble.c` / `scripts/build-ffrumble.sh`）——重建根后 `/usr/local/bin` 空。
- 判据：`ffrumble /dev/input/event{2,3} 400 0xffff` 两次都打印 `rumble ON …`（阳性对照成立）。
  物理震感需人耳/手感确认（本项属「需人」判据）。

## 3. 机械化（防再丢）

`scripts/deploy-desktop-shell.sh` 新增两节，都按**多件同验**而不是「文件在不在」：

- **§10 音频**：tplg 在 + UCM 两文件在 + `amixer` 可用 + `wpctl` 的 Sink 名含 `Speaker`；
  缺则 scp 三件 + `audio-ucm/install.sh` + `apt-get install alsa-utils` + `audio-alsa-init.sh` + 重启 wireplumber/pipewire。
- **§11 触觉**：`aw86927-haptics` 节点 ≥2 + `/usr/local/bin/ffrumble` 在；缺则 `build-ffrumble.sh` + scp。

冷起复验：25 s 直进 Linux、Sink=`内置音频 Speaker playback`、`event2/3` 都在、`audio-share-client` active。
