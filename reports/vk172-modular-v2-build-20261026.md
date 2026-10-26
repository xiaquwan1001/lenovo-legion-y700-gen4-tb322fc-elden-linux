# vk172（模块化 v2）构建结果（2026-10-26）

> 目的：把 `patches/fragment-modular-v2.config`（第二层模块化）做成可上机件，验证 **MMC/TF 整链可 `=m`**（root 在 UFS）。
> 树 = `build/vk151` @ `24223e44a`（+ 5 个未提交的显示/DT 改动，与 vk163 同源）。

## 0. 结论

| 项 | 结果 |
|---|---|
| config 门禁 | `scripts/check-modular-config.sh` **PASS**（27 锚点全 `=y`、`olddefconfig` 幂等、tristate=y 无 `=m` 依赖） |
| 配置规模 | `.config` 中 **`=m` 1463 项**（vk163 为 1462；v2 把 MMC 整链翻 `=m`） |
| 构建 | `Image.gz + dtbs + modules` **rc=0，0 error / 0 warning**（5889 个 `CC [M]`） |
| UTS | `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172` |
| 模块 | **1638 个 `.ko`**，`modinfo -F vermagic` **1638/1638 逐字相同** |
| 关键 `=m` | `CONFIG_MMC=m` / `MMC_BLOCK=m` / `MMC_SDHCI=m` / `MMC_SDHCI_MSM=m`（`mmc_core.ko`/`mmc_block.ko`/`sdhci.ko` 均产出）；`CONFIG_DRM_MSM=y` 保持不变 |
| 镜像 | `out/boot-elden-vk172.img` **84 525 056 B**，sha256 `70d550a74d45dcb05f1f8d0be0e3af2d1105544f8af75c92c3cba760842186f9` |
| manifest | `kernel_release_matches_image=yes`、`ramdisk=out/initramfs-full-elden.cpio.gz`（日用 62 MB ramdisk，非 slim） |
| 设备侧模块树 | `/lib/modules/<UTS>` **1638 `.ko`** + `depmod -a` 完成 |

## 1. 构建过程中踩到的两件事

1. **主机 19:38 硬重启**（另一个 agent 正在查硬件稳定性）⇒ 两个构建被中断，`/tmp` 被清；重启后对 `build/vk151` 先 `make clean` 再全量，
   否则崩在半途留下的截断 `.o` 会让 `modpost` 报 `nouveau.ko: symbol 'nvkm_fifo_pause' undefined`（假失败）。
2. **日志不再写 `/tmp`**（`logs/` 下），否则 tmpfs 被清就丢证据。

## 2. 上机验证

见本文件 §3（待填）。

## 3. 上机验证（2026-10-26 20:13，零写盘 `fastboot boot`）

设备 `HA2EXB0E`，`fastboot boot out/boot-elden-vk172.img` → `OKAY [10.1 s]`，SSH 36 s 上线。

| 判据 | 实测 | 结论 |
|---|---|---|
| UTS | `…-debug-vk172`（与模块 vermagic 逐字一致） | ✅ |
| 根 | `/dev/sda18  f2fs`（生产根，非 RAM 根） | ✅ |
| 模块数 | `lsmod` **106**（vk163 对照 64 —— 差异全部来自新翻 `=m` 的 MMC/TF 链） | ✅ |
| **MMC/TF 整链 `=m`** | `mmc_core` / `mmc_block` / `sdhci` / `sdhci_msm` 全 `Live`；`mmc0: new high speed SDXC card … CBADS 58.6 GiB`；`mmcblk0p1` ext4 挂载（`recovery complete`）；`dd` 读 64 MiB = **17.9 MB/s** 无报错 | ✅ **v2 的核心主张成立** |
| 载荷模块 | `ath12k`/`ath12k_wifi7`、`snd_q6apm`、`snd_soc_sc8280xp`、`snd_soc_wcd939x`、`aw86927`、`novatek_nvt36xxx_spi`、`aw99706` 全 `Live` | ✅ |
| 模块错误 | `failed to load module|unknown symbol|vermagic` = **0** | ✅ |
| Q28 签名 | `command DMA timeout|dsi_bonded_cmd_failed|Failed to initialize panel` = **0**（本次为 GOOD 发） | ✅ |
| 显示 | `card0-DSI-1 = connected`、`phoc=1`/`phosh=1`、背光 511 | ✅ |
| 无线/蓝牙 | `wlan0` 在、`rfkill` 两路 `Soft/Hard blocked: no`；`hci0 UP RUNNING`、QCA 固件 `BTFW.BRAHMA.2.0.0-00306` 下载完成、BD address 已设 | ✅ |
| 音频 | `card 0 [LenovoY700Gen4]` 在位 | ✅ |
| 相机 | `/dev/video*` 17 个 | ✅ |

## 4. 结论

- **模块化 v2 可以作日常线候选**：把 MMC/TF 整链从 `=y` 降到 `=m` 没有引入任何可观察回归（root 在 UFS 是该决策的前提）。
- 收益：以后改 MMC/SDHCI 只要换 `.ko`（`mod-loop` 秒级），不需要重编内核 + 重做镜像 + 重启。
- 未做：**未写 `boot_b`**（是否把日常线从 vk163 换到 vk172 由用户裁决）；G1-23 的三窗口是在 vk163 上跑的（见 `reports/g1-23-windows-20261026.md`）。

## 5. vk173 = vk172 载荷 + RTC offset DTB（已写 `boot_b`，日常线切换）

动机：vk163/vk172 的板 DTB 都没有 `patches/dt/0002`（pmk8550 rtc offset）⇒ `hwclock -r` = 1970-01-09，每次开机时间被覆盖。
只改 DTB 就没必要重编内核 ⇒ **vk173 = 复用 vk172 内核载荷 + 新 DTB**（与 vk167–vk171「只改 cmdline/ramdisk」同一惯例，身份由 manifest `dtb_sha256` 区分）。

| 项 | 值 |
|---|---|
| DTB | 153 253 B（vk172 为 153 137），sha256 `05c0b89660e779e1012e0c41f5e12d5aceccc5918370f4547467adcb02718344` |
| 镜像 | `out/boot-elden-vk173.img` 84 525 056 B |
| 签后 | `1a05a89de98aa6a9637d51e0c81fb93856d6bda4f09c05c9e817df3e223fb675`（96 MiB，`bootslot-b/avb.key`） |
| 写入 | `scripts/flash-b.sh out/boot-elden-vk173.img` → **读回 sha 一致** |
| 回退件 | `bootslot-b/boot_b-vk163-signed-20261026.img`（sha `65ae2ff0…`，写盘前从设备 dd 备份） |

**真 POR（正常 `reboot`，非 fastboot）后判据**（`reports/artifacts/baseline-20261027/vk173-flash-verify.txt`）：

| 判据 | 修前（vk163） | 现在（vk173） |
|---|---|---|
| `/proc/device-tree/…/rtc@6100/` | 无 `nvmem-cells` | **有 `nvmem-cells` + `nvmem-cell-names`** |
| `hwclock -r` | `1970-01-09` | **`2026-10-26 20:26:46`** |
| `hwclock -w` | `-ENODEV` | **rc=0** |
| 跨重启 | 每次回 1970 | **重启后 `date` 正确**（`boot_id 92a4b9e7`，uptime 20 s 时已对） |
| 其余 | — | `f2fs /dev/sda18`、`lsmod` 106、`mmc0=CBADS`、DSI connected、phoc/phosh=1、`moderr=0`、Q28 签名 0、`boot_b` sha `1a05a89d…` |

⇒ `T16-补`（RTC 回退登记）**已闭环**；日常线 = **vk173**。
