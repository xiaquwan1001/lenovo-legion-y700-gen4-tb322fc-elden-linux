# UEFI：10-05 出字配方 × 干净 v0 header 复测（构建侧，2026-11-01）

> Lane：派工 C（UEFI ④）。本 lane 只构建/打包/报告，**未上机**（上机由总管执行）。
> 证据分级：**已证** = 今日命令输出 / file:line；**外部** = 历史报告/档案原文；**未证** = 推断。
> 构建/打包现场：`reports/artifacts/uefi-1005recipe-20261101/`（manifest、build.log、SHA256SUMS、header-dump、fv/）。

## §0 结论

- **镜像**：`out/uefi-20261101-1005recipe-v0.img`　2 441 216 B　sha256 = `97c95cc12f2c8af9cd06b62b7de617006f04e5f00477244ac104ac95376b6470`
- **FD**：`SM8750_EFI.fd` 4 194 304 B　sha256 = `c91afcc96c873736d4b84ce4daec3d36f0b592799aff666ae9ee08cae1ea71bf`（Build/PakalaPkg/RELEASE_CLANGPDB/FV/FVMAIN_COMPACT.Fv 同源）
- **与 10-05 同源判定**：**配方级同源**（同 commit `6b6ac42a` + 同 DSC/RELEASE/SCALE_FACTOR 3/未补丁 UFSDxe/stock shim），**非字节级同源**——本机 clang 21.1.8 vs CI clang-18、且为今日全新构建（构建时间串不同），与 10-31 a2-replay 的经验一致（同源重建仅差构建时刻字符串）。未与 10-05 原件（已不在盘）做字节对比。
- 干净 v0 header 口径满足：v0 / kernel_addr=0x10008000 / pagesize 4096 / 其余字段全零（§4 dump），与 11-01 7/7 被 ABL 接受的那批同构（`reports/uefi-cleanheader-reframe-20261101.md`）。
- 无任何 instrument / 无写 FB 的标记代码（§1、§2：`patches=none`、`shim=stock`）。
- **上机判据（一行）**：`fastboot boot` 后屏上出现可辨认 ASCII（`Synchronous Exception at …` / BDS 文本）= J1 达成；回退 = `fastboot reboot`。

## §1 复原的配方（逐项 + 来源）

| 项 | 值 | 来源 |
|---|---|---|
| DSC | `PakalaPkg/PakalaNoSb.dsc`（NoSb，`build_uefi.py` 非默认走 `PlatformBuildNoSb.py`，对应 CI `*_NOSB.img`） | 已证：`build_uefi.py:195-201`（secureboot=0 → NoSb）；外部：`reports/uefi-observability-pivot-20261101.md` §0-8 |
| buildtype | `-t RELEASE` | 同上（10-05 CI 发①即 RELEASE） |
| SCALE_FACTOR | `font5x12.h` 1→3 | 外部：`archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md:24`；`uefi-text-console-archaeology-plan-20261030.md:242` |
| UFSDxe | **未补丁厂商件** = 树内 `Binaries/QcomPkg/Drivers/UFSDxe/UFSDxe.efi`（sha `dac620ac…`），装入 `PatchedBinaries/` | 外部：archaeology plan §4.1 G2（期望 `dac620ac…ce750`） |
| RmVmDxe | 树默认（`.orig-mu` 复原，本 lane 未动） | 已证：manifest `variant.rmvmdxe=mu` |
| BootShim | **stock（无 cache 维护）**，112 B，sha `054e114d…`（10-05 口径 = 无 `dc civac/ic iallu`） | 已证：今日 `SHA256SUMS`；外部：archaeology plan §4.1 G4「期望 112 B / 054e114d」 |
| 其他补丁 | 无（`patches=none`）——10-05 后加的 faultline/末屏重印**不复用**（archaeology U6：系可见性辅助，干净对照更好） | 已证：manifest |
| 编译器 | Ubuntu clang 21.1.8 / Python 3.14.4（与 10-24 起本机链一致；CI 当年 = clang-18） | 已证：manifest |
| commit | `7-mu-lenovo` HEAD `6b6ac42a7edc…`（2026-10-05 提交） | 已证：manifest + `git log -1` |
| 构建命令 | `scripts/uefi-build-variant.sh <out> --ufsdxe treevendor --scale3 --clean`（本轮新增两参数，见 §2）；并发经 `taskset -c 0-11` 限 ≤12 | 已证：本轮执行 |

## §2 构建结果

- 全量（`--clean`）构建 **0 error**；`grep -c ' error:' build.log` = **0**。
- `grep -c ' warning:'` = 620，与 10-31 基线 `a2-replay/build.log.gz` **逐条相同**（540 条 DSC `Unrecognized content` 等，树固有告警，非本轮增量）——故按「无新增 warning」口径记 0E/0W-增量。
- 产物（`reports/artifacts/uefi-1005recipe-20261101/SHA256SUMS`）：
  - `SM8750_EFI.fd` `c91afcc9…`
  - `BootShim.bin` `054e114d…`（112 B，stock）
  - `kernel.bin`（gzip payload）`5c4f9a47…`，2 437 036 B
  - `uefi-v0.img` `97c95cc1…`（= out/ 镜像）
- 载荷指纹：`_FVH@152` ✓；NoSb FB-console 字模硬指纹 `@43648`（>0，说明 `PakalaNoSb.dsc` 可见性通道确实编进去了）✓。
- 树收尾已还原：`git status --porcelain` = 仅有基线的 `M Common/MU_TIANO` + 2 个 `.orig-mu` 未跟踪件（`font5x12.h`/`UFSDxe.efi` 均还原）。
- 脚本变更（增量、不改既有行为）：`scripts/uefi-build-variant.sh` 新增 `--ufsdxe treevendor`（取树内 Binaries 厂商件）与 `--scale3`（font5x12.h 1→3 并随 trap 还原）；`bash -n` 通过；既有 `mu|vendor|stock|cachefix|markers|ddrmarks` 路径未动。

## §3 UFSDxe 身份

| 件 | sha256 前 16 | FV 内落地 PE32 |
|---|---|---|
| **FV 内 UFSDxe（本轮）** | `dac620aca276e735`（全：`dac620aca276e735361d8b747fe0218b6125eae004116391270f32a72e6ce750`，151 552 B） | **是树内厂商原厂件**（`Binaries/.../UFSDxe.efi` 逐字节相等，已证：`sec[4:] == treevendor`） |
| `reports/artifacts/uefi-dxe-20261024/vendor-UFSDxe.efi` | `fa561bf11eb18f14`（151 552 B） | **不是它**（fa561bf1 是 10-24 那批的另一份厂商拷贝，与 dac620ac 同尺寸不同字节） |
| dodge 件 | `e76b555f…`（155 648 B） | **不是** |

- FFS 段存档：`reports/artifacts/uefi-1005recipe-20261101/fv/UFSDxe-in-FV-SEC2.pe32`（FFS `9494dee0…`，SEC2 PE32 头 `04 50 02 10`）。
- ⇒ 本轮载荷里是 **10-05 实验同款「未补丁」厂商 UFSDxe（dac620ac）**，既非 dodge 件也非 10-24 的 fa561bf1 拷贝。

## §4 header 逐字段 dump

`reports/artifacts/uefi-1005recipe-20261101/header-dump.txt`（由新增 `scripts/uefi-bootimg-dump-v0.py` 生成，自测通过）：

```
magic=ANDROID!
kernel_size=2437036
kernel_addr=0x10008000
ramdisk_size=0x00000000
ramdisk_addr=0x00000000
second_size=0x00000000
second_addr=0x00000000
tags_addr=0x10000100
page_size=4096
header_version=0
os_version=0x00000000
boot_name=
cmdline=
id_sha1=5bf0f992a0e4270e520636bb4828f1dd9833e941
extra_cmdline=
file_size=2441216
sha256=97c95cc12f2c8af9cd06b62b7de617006f04e5f00477244ac104ac95376b6470
```

- 与 11-01「干净 header」家族一致（v0 / 0x10008000 / 4096 / 其余零；`tags_addr=0x10000100` 为 mkbootimg base+默认 tags_offset，11-01 对照表的接受侧同样带此值）；`id_sha1` 为打包工具自动生成，11-01 已证 **不参与判定**。

## §5 上机实验单（给总管，6 行）

1. 就绪门：`ssh root@192.168.7.1 'uname -v'` 通 → `reboot2 bootloader`，等 12 s，`fastboot devices` 出序列号才继续。
2. **用户开始录像（对整屏，≥60 s）**。
3. `sha256sum out/uefi-20261101-1005recipe-v0.img` 核对 `97c95cc1…` 后：`fastboot boot out/uefi-20261101-1005recipe-v0.img`（零写盘）。
4. 判据（二值）：`FAILED (usb_read failed)` + USB 掉线 = ABL 交棒；`OKAY [~10.1s]` 且 USB 持续 `18d1:d00d` = 未交棒。
5. **J1 主判据 = 屏上是否出现可辨认文字/色块**（本轮 SCALE_FACTOR=3，字高 36 px；`Synchronous Exception at …` = 通道①；FrontPage/「无可启动设备」= 通道②）。若交棒但屏无字且 ~1–2 s 掉电 → 记「交棒后早死零输出」，与 11-01 §0-4 窗口约束一致。
6. 回退：`fastboot reboot`（回落 stock）；若卡 fastboot/槽位异常，先抓 logfs seg0 基线再按 `reports/uefi-slotboot-stuck-fastboot-20261101.md` §8 与 PITFALLS #484 处理。

## §6 未证 / 风险

1. **J1 本身未证**：本 lane 只证明「配方已按 10-05 口径重建并打包为干净 v0 header」；屏上是否出字只能上机回答。10-05 的出字案例全是 **v3 header**（当年那面真跳过），v0 + 此配方**从未同框测过**——这正是本轮要回答的变量。
2. **clang 代次差**：本机 clang 21.1.8 ≠ CI clang-18，10-05 的 ②③ 经验是地址会变；若出字，崩溃地址将与 `UFSDxe+0x13224` 不同（机制相同、地址漂移），比对时勿按字面匹配。
3. **2 s 掉电窗口**：11-01 §0-4——ABL 跳转后 ~1–2 s 整机掉电；若 10-05 的出字发生在 2 s 之后（BDS 阶段），本轮可能「被执行但来不及出字」。结果为「交棒+零输出」时，优先怀疑窗口而非配方失效。
4. **未与 10-05 原件字节对比**：原件不在盘（archaeology §1.2）；如需字节级溯源可试 `gh api` 拉 CI artifact（archaeology §4.0，未做，非本轮必需）。
5. 构建告警 620 条按「与基线逐条相同」记零增量；未做逐条 diff 证明（只比了计数与 top 类型分布）。
