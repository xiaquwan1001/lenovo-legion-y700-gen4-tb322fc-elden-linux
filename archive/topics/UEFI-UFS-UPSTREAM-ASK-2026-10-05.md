# 上游问题草稿 — SM8750(Pakala) UFS 初始化（2026-10-05）

> ✅ 已发送（2026-10-05）：https://github.com/sunflower2333/mu_wide_platforms/issues/12 (xiaquwan1001)

目标仓库：`sunflower2333/mu_wide_platforms`（我们的 `upstream`，公开、Issues 已启用）
发布账号：`xiaquwan1001`

---

**Title:** SM8750 (Pakala) Lenovo Y700 Gen4: vendor UFSDxe fails UEFI_DEVICE_ERROR — which platform config is it missing?

**Body:**

Hi, thanks for `mu_wide_platforms`.

We're bringing up a new SM8750 device on `PakalaPkg`: **Lenovo Legion Y700 Gen4 (TB322FC)**, device package `Platforms/PakalaPkg/Device/lenovo-y700g4` (not upstream). Local build works and our UEFI now reaches BDS, but **UFS never initializes**, so there is no bootable device.

**Environment**
- fork of this repo, built locally (clang-21 / `CLANGPDB`), `TARGET=DEBUG`, NOSB via `PlatformBuildNoSb.py`.
- booted with `fastboot boot lenovo-y700g4_NOSB.img` (ABL accepts the BootShim+FD shell fine).

**Symptom** (unpatched vendor UFSDxe):
```
Loading driver ... UFSDxe.efi
ufs_error_log: 11
ufs_error_log: 3b
ufs_error_log: 55
ASSERT_EFI_ERROR (Status = Device Error)
ASSERT UFS.c +2326: !EFI_ERROR (EFI_DEVICE_ERROR)
```
Earlier in DXE:
```
mbox_os_init: Failed to locate SCM protocol for Mailbox 14
ERROR: Fail to init client handle to QBSS clock node
ERROR: CPU_Vectors region not present in cfg file !
UsbBusStart: Init command not active   (repeated)
```
BDS then reports no usable boot device.

**What we tried** (each = fresh NOSB build + `fastboot boot`):
- Mu's `PatchedBinaries/UFSDxe.efi` → `Synchronous Exception` at `UFSDxe+0x13224` (data abort, X0 bad pointer, FAR=X0+8).
- Unpatched vendor UFSDxe (and the xiaomi-piano UFSDxe) → no crash, but the `UFS.c +2326` ASSERT above.
- lenovo's own original ClockDxe **and** oneplus-dodge's original ClockDxe → crashes earlier (after `ArmTimerDxe`).
- `EnableMultiThreading=1` + `EnableMultiCoreFvDecompression=1` (matching oneplus-dodge) → hangs at `StartSchedulerFunc`.

**Observations**
- lenovo `PlatformMemoryMapLib.c` / `PlatformConfigurationMapLib.c` are byte-identical to `xiaomi-piano` / `oneplus-dodge` (only the two multithreading switches differ).
- SM8750 `PlatformPrePiLib/PlatformUtils.c` does **not** call `MmuDetach()` (so the SMMU-detach workaround isn't involved).
- `DeviceTreeBlob/Linux/linux-y700g4.dtb` is the 6-byte `dummy` placeholder, same as xiaomi-piano.
- `Binaries/RawFiles/uefiplat.cfg` is the stub ("moved to device tree").

**Questions**
1. Is UFS known to work on Pakala/SM8750 (e.g. oneplus-dodge) with this repo? Which device/config should we diff against?
2. Where is the vendor UFSDxe supposed to get its config from — `PlatformConfigurationMapLib` (InfoBlk / ConfigLib), the embedded `uefiplat.cfg`, or a device tree? Is a non-dummy DT required?
3. Are `CPU_Vectors` / `QBSS` / SCM-mailbox entries supposed to exist in the device config map? None of the Pakala device maps contain them.
4. Is the patched `ClockDxe` intentional and required on SM8750, and is there a known-good ClockDxe/UFSDxe pairing?

Happy to provide full DEBUG logs, the experiment matrix and image sha256.

---

## 发布命令（用户确认后执行）

```bash
cd ~/y700-elden/mu_wide_platforms
gh issue create --repo sunflower2333/mu_wide_platforms \
  --title "SM8750 (Pakala) Lenovo Y700 Gen4: vendor UFSDxe fails UEFI_DEVICE_ERROR — which platform config is it missing?" \
  --body-file <(sed -n '/^\*\*Title:/,/^---$/p' ~/y700-elden/archive/topics/UEFI-UFS-UPSTREAM-ASK-2026-10-05.md | tail -n +2 | head -n -1)
```
