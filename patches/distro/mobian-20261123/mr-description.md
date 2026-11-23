# MR description draft — droid-juicer `configs/lenovo,elden.toml`

> 草稿（2026-11-23）。目标仓 `gitlab.com/mobian1/droid-juicer`，基线 master（0.4.3）。
> **本文不是已提交的 MR**：投递是用户放行后的动作（禁 fork/push/MR 维持中）。
> 分支名建议：`lenovo-elden-config`；commit message 见文末。

---

## configs: add Lenovo Legion Y700 Gen4 (TB322FC)

### Motivation

Add droid-juicer firmware-extraction support for the Lenovo Legion Y700 Gen4
(TB322FC, DT compatible `"lenovo,elden"`, Qualcomm SM8750). This is one of the
pieces needed to boot Mobian on this tablet; the firmware files are extracted
from the stock Android partitions (modem / bluetooth / super->vendor / persist)
into the paths the mainline drivers request.

Board support is being upstreamed separately (SM8750 SoC support and the board
DTS are work in progress on the mainline lists), so this config has **not been
tested on hardware running a mainline kernel yet**. It has been validated
offline against the stock partition contents and the in-device device tree.

### Board summary

| | |
|---|---|
| Device | Lenovo Legion Y700 Gen4 (TB322FC), codename *elden*, China WiFi variant |
| SoC | Qualcomm SM8750 (Snapdragon 8 Elite), Adreno 830 |
| DT compatible | `"lenovo,elden", "qcom,sm8750"` (read from the on-device DTB) |
| Wireless | WCN7861 "PEACH": WiFi via ath12k (pci 17cb:110e), BT via hci_qca |
| Audio | AudioReach (q6apm) + 2× AW88461 smart amps |
| Touch | Novatek NT36536 (CSOT panel) |
| Sensors | SLPI/SSC sensor core, userspace via hexagonrpcd |

### Source partitions (stock GPT partlabels)

- `modem` (slot `_a`): `image/peach/` (WCN7861 WiFi), `image/tmel_peach_20.elf`
- `bluetooth` (slot `_a`): `image/` ("brh" family)
- `super` (dynpart) → `vendor` (ext4, dynamic): `firmware/`, `etc/sensors/`
- `persist`: `sensors/registry/registry`

All `partition` values are base names; droid-juicer resolves `<part>_a` on this
device.

### Per-entry notes

- **GPU (gen80000_*)**: board DT `zap-shader` firmware-name is
  `qcom/sm8750/gen80000_zap.mbn`; adreno requests gmu/sqe/aqe by fixed name.
- **Touch**: nt36536 DT firmware-name `novatek_ts_csot_3k_fw.bin` (firmware root).
- **Speaker amps**: the aw88461 driver requests
  `awinic/y700-gen4-speakers.bin`; the stock vendor file is `aw882xx_acf.bin`
  (same ACF content, renamed).
- **WiFi**: the DT wifi node has no firmware-name, so ath12k uses its default
  `ath12k/PEACH/hw2.0/` paths; the stock files use `-20`-suffixed names and are
  renamed. `board-2.bin` (assembled from `bdwlan.e01`..`e41`) cannot be
  produced by droid-juicer, so only `board.bin` (= `bdwlan.elf`) is extracted;
  `board-2.bin` will come from a board firmware package.
- **Bluetooth**: btqca hardcodes the `qca/` prefix; the 5th file
  (`tmel_peach_20.elf`, in the modem partition) is required for the controller
  to register.
- **ADSP / CDSP are deliberately NOT listed**: their DT firmware names use the
  split `qcom/sm8750/{adsp,cdsp}.mdt` + `*_dtb.mdt` form on this board, and a
  single-file `cdsp_dtb.mbn` (what droid-juicer would produce by squashing a
  `.mdt` input) is rejected by the secure world on this hardware. The split
  blobs are shipped by a board firmware package instead.
- **Sensors DSP tree** (`/usr/share/qcom/sm8750/LENOVO/TB322FC`): absolute
  destinations on purpose — this is the hexagonrpcd served-files root, same
  shape as the existing `/var/lib/droid-juicer/sensors` usage in
  `configs/shift,axolotl.toml`.
- **Deliberately not covered** (self-authored / derived assets, not vendor
  extractable): `awinic/y700-gen4-haptic.bin`,
  `ath12k/PEACH/hw2.0/board-2.bin`, `qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin`.

### AI-assistance disclosure

This configuration was prepared with AI assistance (AI-assisted analysis of the
stock partition contents, the device tree and the droid-juicer source); the
device facts were taken from on-device reads (GPT, DTB, stock firmware files)
and reviewed by a human. Disclosed up front per the project's upstream policy.

### Known limitations / risks

- **Not tested on hardware yet** (mainline kernel bring-up in progress). No
  Tested-by is implied.
- The sensors entries assume `sns_reg_config` and `etc/sensors/config` live in
  the `vendor` dynamic partition; on some devices they sit in `odm`. This has
  not been confirmed by listing the mounted partitions yet (see question 2).
- The `ath12k/PEACH/hw2.0` directory name is derived from the ath12k hw
  params/stock layout; it should be confirmed against dmesg
  (`Direct firmware load` requests) once the board runs a mainline kernel.
- On the Debian side, droid-juicer packaging currently lives in a (hopefully
  temporary) fork branch whose description says *"until droid-juicer supports
  upstream kernels again"* — see question 1.

### Questions for the maintainers

1. **Debian packaging fork**: the Debian packaging branch (`packaging/forky`)
   is described as a temporary fork *"until droid-juicer supports upstream
   kernels again"*. What are the current limitations for devices running
   upstream (non-Android) kernels — is the `droid-juicer.service` first-boot
   flow expected to work as-is, or should new device configs hold off until
   the fork is resolved?
2. **vendor vs odm for sensors**: is there a preferred way to handle
   `etc/sensors` content that may live in either the `vendor` or the `odm`
   dynamic partition depending on the device — would you rather see two
   entries (one per partition), or is a single `vendor` entry with a follow-up
   fix acceptable?

---

### Commit message (suggestion)

```
configs: add Lenovo Legion Y700 Gen4 (TB322FC)

SM8750 board, DT compatible "lenovo,elden". Firmware is taken from the
stock modem/bluetooth/persist partitions plus the dynamic "vendor"
partition of "super"; sensors DSP tree is placed under
/usr/share/qcom/sm8750/LENOVO/TB322FC where hexagonrpcd expects it.

ADSP and CDSP are intentionally not extracted: the board DT uses the
split .mdt form and a single-file *_dtb.mbn is rejected by the secure
world on this board, so those blobs ship with a board firmware package.

Not tested on this device yet (board support is being upstreamed).
```

### Pre-submission self-checks (already run offline)

| # | check | result |
|---|---|---|
| 1 | `tomllib` parse | OK (single `[juicer]` table, keys `dynpart/firmware/folders`) |
| 2 | schema keys ⊆ `dynpart/firmware/folders/partdump` (`src/firmware.rs:81-87`) | OK |
| 3 | `partition` = GPT partlabel base names (parsed from stock GPT dumps) | OK (`modem`,`bluetooth`,`super`,`persist` all present) |
| 4 | every `files[].name` exists in the captured stock partitions | 18/19 OK; 1 TODO (`vendor/etc/sensors/sns_reg_config`, not captured locally) |
| 5 | `destination` matches DT `firmware-name` / driver hardcoded paths | OK (GPU/touch/amp from DTB; `qca/` from btqca; `ath12k/PEACH/hw2.0` default) |
| 6 | no self-authored asset disguised as extraction | OK (3 items listed as deliberate exclusions) |
| 7 | single new file, no other device touched | OK |
| 8 | no `.mdt` file entries in the config (comments only) | 0 occurrences of `name = "...mdt"` |
| 9 | "not tested on hardware" + "split firmware ships via board package" stated | this description |
