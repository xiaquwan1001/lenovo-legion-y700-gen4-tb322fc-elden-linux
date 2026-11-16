# vk192 上机 + 持久化（2026-11-16）

> 目的：把本日验证过的 **pstore/ram 守卫**（拒绝与 initrd 重叠的 ramoops zone）从「备料 + 真机试跑」变成
> **设备日常内核**（b 槽持久件）。上游件已投（`patches/upstream/pstore-ram-initrd-overlap-20261116/`，3×250）。
> 单轮判据沿用 `DEVICE/README.md` §1.1 的 G1 全绿清单。

## §0 结论（先数字）

| 项 | 值 |
|---|---|
| 版本 | **vk192**（`build/daily` `4bdf1711b5` + tag `vk192`；两枚提交 `5c72e9e838` init helper + `4bdf1711b5` pstore/ram 守卫） |
| UTS | `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`（**新 UTS ⇒ 整套模块树重编**，不能沿用 vk190 的 1499 .ko） |
| 空载件 | `out/boot-elden-vk192.img` `bdf47f5f…`（85 815 296 B）；kernel `a645d9ff…` / payload `0a55e52c…` / dtb `89c9336d…` / ramdisk `3282ae6c…`（同 vk190）/ config `cbcfd84e…` |
| b 槽签名件 | `bootslot-b/boot_b.img` `06c081ca…`（96 MiB，`flash-b` readback 一致；`bootslot-b/avb.key` 自签） |
| 模块树 | **1510 个 `.ko`** 部署到 `/lib/modules/<UTS>`（`deploy-modules.sh` 读回校验 1510/1510、抽样 sha 一致、`modules.dep` 1510 行） |
| 上机结果 | 零写盘 1 发 + 持久 1 发 + 重启复验 1 发，**全绿**；`qbootctl` = Active/Successful/Bootable 全 1，重启 32 s 回 SSH |

## §1 步骤（每步都有读回校验）

1. `scripts/build-kernel.sh modules`（-j26）→ 1510 `.ko`，UTS = 新串；
2. `VERSION=vk192 RAMDISK=out/ramdisk-vk181-working.cpio.gz scripts/build-boot.sh` → 空载件 + `.manifest`（sha/UTS/dtb/config 全记账）；
3. `scripts/deploy-modules.sh --from build/daily` → 设备 `/lib/modules/<新UTS>`（1510/1510 校验）；
4. **零写盘验证**：`ssh 'reboot bootloader'` → `fastboot boot out/boot-elden-vk192.img` → **16 s 到 SSH**；
5. **持久化**：`scripts/flash-b.sh out/boot-elden-vk192.img --reboot`（签名 → dd 流式写 boot_b → readback `06c081ca…` → 重启）；
6. `qbootctl` 核对 + `qbootctl -m`（已 success）→ **再整机重启一次**，仍回 vk192（持久性判据，32 s）。

## §2 判据（vk192 持久 boot 现查）

| 判据 | 观测 |
|---|---|
| DSI/DRM | `msm_dpu ae01000.display-controller: bound ae94000.dsi (ops dsi_ops)`、`[drm] fb0: msmdrmfb frame buffer device` |
| WiFi | `wlp1s0 UP`，`ustcnet` |
| fastrpc + SSC | `/dev/fastrpc-adsp` 存在；`qrtr-lookup` 有 `400 Snapdragon Sensor Core service` |
| 传感器 | `iio-sensor-proxy` active；SensorProxy `HasAccelerometer/HasProximity/HasAmbientLight = true`（数据走 FastRPC/SSC，不走 IIO sysfs ⇒ `/sys/bus/iio` 只有 `spmi-adc5-gen3`，属正常） |
| Waydroid/zram | `waydroid-container`、`zramswap` active |
| 模块 | `lsmod` 44 项；`/lib/modules/<UTS>` 1510 `.ko` |
| 待机 | `rtcwake -m mem -s 45` **3/3 rc=0**；`suspend_stats` `success=3 fail=0`；`/sys/power/mem_sleep` = `[s2idle] deep` |
| 槽位 | `qbootctl`：`_b` Active 1 / Successful 1 / Bootable 1；`/proc/cmdline` 带 ABL token（`verifiedbootstate=orange`…）⇒ 真走 b 槽，不是 UEFI 路径 |

## §3 守卫在本 boot 的表现

vk192 持久 boot 的 initrd 由 ABL 放在 ramoops 之外 ⇒ `printk: legacy console [ramoops-1] enabled`（守卫没被触发，属预期：
守卫只在真重叠时动作）。**守卫本身的真机证据在 a 槽 UEFI/GRUB 那一发**：initrd `0xc1ab0000-0xc584a5e0` 整段覆盖
`ramoops@c2000000` ⇒ 三段 zone 逐条 `ignoring … : it overlaps the initrd` + `every zone overlaps the initrd; ramoops disabled for this boot`，
随后 `Unpacking initramfs…` → `Run /init`（见 `reports/pstore-ram-initrd-guard-20261116.md` §5）。

## §4 现场与回滚

- 设备：b 槽持久 vk192；`boot_a` 未动（= UEFI 世代的 `1ca2b8e6…` pc1）；ESP 上是本日自打的嵌入菜单 GRUB（`cc6391b3…`，
  只为 pstore 守卫专测而装），历史 EFI 全在 ESP 上备份（`.grub-fixr2-20261116.bak` 等）。
- **回滚到 vk190**：`ssh 'reboot bootloader'` → `fastboot flash boot_b bootslot-b/boot_b-device-20261111.img`（或任一旧 `boot_b-*`），
  或从 `backup/HA2EXB0E-16+512/` 取原厂件。模块树回滚：`/var/tmp/modules-backup-<UTS>-*.tar.gz`（deploy 脚本留的）。
- 账：`versions/vk-registry.tsv` vk192 行、`versions/vk-kernel-identity.tsv`（重生成后 `--check` rc=0）、
  `out/boot-elden-vk192.manifest`、`DEVICE/README.md` §1.1。
