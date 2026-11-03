# UEFI 线：**载荷首次被真正执行**（2026-11-03 晚 ~ 11-04）——判据、通道与死点定位

> 性质：主机侧构建 + **设备侧 7 发零写盘 `fastboot boot`**（无一次写分区/槽位/GPT）。
> 前序：`reports/uefi-posctrl-20261103-summary.md`（11-03 下午：DDR 正控 + 头对齐假设）。
> 设备：HA2EXB0E（U2），在机 `boot_b` = `fb55997c…`（全程未改动，收尾核验 `succ=1/unbootable=no`）。

---

## §0 结论（先数字）

| # | 结论 | 证据 |
|---|---|---|
| 1 | **载荷被执行了 —— 这是本线第一次**。`v2 base0` 打包 + `Image` 头对齐（`text_offset=0` / `image_size`=解压真实长 / `flags=0xa`）后，ABL 从「0.056 s 拒绝」变成 `Sending 1.49 s` + `Booting OKAY 10.108 s` | `reports/artifacts/uefi-boot-20261103-182412/{boot.txt,run.log}`、11-04 各发 |
| 2 | **屏上可见性达成（J1 首次）**：shim 直接把 `splash_region` 涂色，屏幕上肉眼可见逐段推进 | 用户目视 4 次 |
| 3 | **屏幕通道地址已验证**：设备 DT `reserved-memory/splash_region` = `0xFC800000` / `0x02B00000`（`no-map`） | `/proc/device-tree/reserved-memory/splash_region/reg`（只读） |
| 4 | **整屏填充会挂死 SoC**：43 MiB 全填，屏上红到约 137 行后整机无响应 | 11-04 19:22 一发 |
| 5 | **FD 4 MiB 已全部拷到 `0xFF300000`**：进度色带走到 4/4（绿）+ M2 绿带（绿带宽 = 红带 2 倍） | 11-04 20:0x 一发（prog 变体） |
| 6 | **死点在 M2 之后、M3 之前** ⇒ 只剩 `dc civac` 扫 4 MiB 那段 cache 维护 | 同上；下一发 `nocivac` 变体待发 |
| 7 | **`0xFF300000` 是真 DRAM**：从 Linux 侧写 `0x42` 读回 `0x42`（`0xFF300000/0xFF600000/0xFF7FF000` 三处全过） | 11-04 20:0x 写入自检 |
| 8 | **「1.9 GB 0xFF 大填充」是我们自己的载荷造成的**（不是 ABL/启动路径）：同一 `fastboot boot` 路径启动**真内核**后三窗仍是 `0x00` | `reports/artifacts/uefi-readback-20261103-184958/control-plainboot.txt`（纯重启）+ 11-04 20:0x 真内核对照 |
| 9 | ⇒ **DDR 标记通道在本类「载荷被执行」场景下不可用**：shim 写的 stage 页会被后面的大填充抹掉（三窗读回恒为 100% `0xFF`） | 11-03 19:51、11-04 19:5x 两次读回 |

## §1 判据的三次收敛（这是本轮方法论产出）

| 判据 | 时代 | 现在 |
|---|---|---|
| `usb_read failed` = 交棒 | 11-01～11-03 | ❌ 作废（自旋探针同样触发） |
| `Booting OKAY 10.1 s` = 交棒 | 11-03 下午 | ✅ 保留，但只说明「ABL 接受了镜像并跳了」，不说明走到哪 |
| 屏上色带 | 11-04 | ✅ **实时、可靠、肉眼可判**；缺点是 ABL 下次启动会清屏，不能事后取证 |
| DDR stage 标记 | 11-01～11-04 | ❌ 在「载荷被执行」类里被 0xFF 大填充抹掉 |

## §2 屏幕通道的三条硬约束（本轮踩出来的）

1. **地址**：`0xFC800000`（DT `splash_region`，`no-map`）——不是 Mu 的 `Display Reserved` 之外的猜测值，DT 原文可查。
2. **可写范围有限**：整屏 43 MiB 填充会在中途挂死（第一发红到 ~137 行）；**实测可安全写的是前 448 KiB**（0～0x70000）；从 Linux 侧写入自检 `0xFC840000` 也通过。
   ⇒ 所有标记必须落在**前 192～448 KiB**内，且**不要**碰更高偏移。
3. **ABL 下次启动会把 splash 清零**（11-04 19:49 读回：前 448 KiB 全 `0x00`）⇒ 屏幕通道只能「实时看」，不能「事后读回」判读。

## §3 本轮变体序列（全部 `fastboot boot`，零写盘）

| # | 镜像 | shim 变体 | 屏上结果 | 判读 |
|---|---|---|---|---|
| 1 | `out/uefi-20261103-v2aligned.img` `3724ce34…` | stock+marks（v0 时代产物） | — | `Sending 1.49 s` + `Booting OKAY 10.107 s`；随后无 USB/网络；三窗事后全 `0xFF` |
| 2 | `out/uefi-20261104-fbfill.img` `fca136d9…` | **整屏**填红/绿/蓝/黄 | 红，自上而下推进到约 137 行后停 | 整屏填充撞不可访问地址挂死；M1 已证执行 |
| 3 | `out/uefi-20261104-fbband.img` `23f1cbdb…` | 顶部 7 条 64 KiB 色带（红/青/品红/白/绿/蓝/黄） | 红→青→品红→白 | 拷到 3 MiB |
| 4 | `out/uefi-20261104-dual.img` `351640e2…` | 色带 + DDR 分级 1..7 | 同 3 | DDR 读回仍 100% `0xFF`（通道被抹） |
| 5 | `out/uefi-20261104-m3block.img` `e18f0be4…` | M3 改成「前 192 KiB 整块蓝」 | 红→青→品红→白，**无蓝** | 没到 `br` 之前 |
| 6 | `out/uefi-20261104-prog.img` `ce3292d4…` | 进度改「同一块换色」（青/品红/白/绿） | 红，然后**绿，绿≈红两倍宽** | =4/4 拷完 + M2 绿带 ⇒ **FD 4 MiB 拷完**；死点在 M2→M3 之间 |
| 7 | `out/uefi-20261104-nocivac.img` `daf8d891…` | 去掉 `dc civac` 4 MiB 扫描 | 待发 | 判据：出现**整块蓝** ⇒ 死点确认为 cache 维护循环，且已 `br` 进 UEFI |

## §4 「1.9 GB 0xFF 大填充」——本轮定性的取证

- **现象**：载荷跑过之后，低 4 GiB 里 `0x82600000`～`0xf37fffff` 大片区域 ~85% 字节为 `0xFF`（其余为单比特衰减 `0xDF/0xFD/0x7F/0xF7/0xBF`，即「写了 0xFF 后掉 1 位」），三块 DSV/carveout 窗同样整窗 `0xFF`。
- **不是读通道问题**：`prep`（写 0）后立刻读回全 `0x00`；`0x42` 写读自检通过。
- **不是 ABL/启动路径**：① 清零后**纯重启**到 Linux，四窗仍 `0x00`；② **同一 `fastboot boot` 路径启动真内核**，三窗仍 `0x00`（`0x84A00000/0x9C300000/0x89300000` 全 0% `0xFF`）。
- ⇒ **只能来自我们的载荷**（shim 之后、或 UEFI 内部）。规模 ~1.9 GB，非 shim 的 448 KiB 色带能解释 ⇒ 指向 **Mu PrePi/内存初始化阶段**（待下一轮用 Mu 侧插桩确认：在 `ArmPlatformPkg/PrePi` 与 `ArchSec.c` 加同样色带/标记）。
- **副作用**：这条通道现在不能用 —— 它把 shim 早期写的 stage 页一起抹掉。

## §5 复现（主机侧全部可重跑）

```bash
# 1) 构建变体（示例：nocivac）
scripts/uefi-build-variant.sh reports/artifacts/uefi-nocivac-20261104 \
  --ufsdxe mu --rmvmdxe mu --shim stock \
  --patch $PWD/patches/uefi/20261103-posctrl/0002-bootshim-text-offset-zero-plus-marks.patch \
  --patch $PWD/patches/uefi/20261104-fbband/0001-bootshim-fb-band-milestones.patch \
  --patch $PWD/patches/uefi/20261104-m3block/0001-bootshim-m3-full-block-marker.patch \
  --patch $PWD/patches/uefi/20261104-prog/0001-bootshim-copy-progress-same-band.patch \
  --patch $PWD/patches/uefi/20261104-nocivac/0001-bootshim-skip-fd-civac-sweep.patch

# 2) 打包成「ABL 会跳进去」的 boot.img（v2 base0 + Image 头对齐）
scripts/uefi-repack-v2aligned.py --build-dir reports/artifacts/uefi-nocivac-20261104 \
  -o out/uefi-20261104-nocivac.img

# 3) 上机（零写盘）
fastboot boot out/uefi-20261104-nocivac.img
```

## §6 证据与产物

- 报告：本文件、`reports/uefi-posctrl-20261103-summary.md`、`reports/uefi-posctrl-linux-entry-20261103.md`
- 构建产物：`reports/artifacts/uefi-{fbfill,fbband,dual,m3block,prog,nocivac}-20261104/`（各含 `BootShim.bin`/`SM8750_EFI.fd`/`payload-v2aligned.bin(.gz)`/`manifest.txt`/`SHA256SUMS`）
- 补丁：`patches/uefi/20261104-{fbfill,fbband,dual,m3block,prog,nocivac}/`、`patches/uefi/20261103-posctrl/0002-*`
- 工具：`scripts/uefi-repack-v2aligned.py`（v2 base0 + Image 头对齐打包，含 `only-kernel-differs` 断言）、`scripts/fb-survey.py`（FB 区颜色普查）
- 读回取证：`reports/artifacts/uefi-readback-20261103-184958/`（三窗读回、iomem、0xFF 覆盖扫描 `ffscan.txt`、**纯重启对照** `control-plainboot.txt`）

## §7 追加（同日更晚）：**Mu UEFI 全流程跑到 DXE** —— 屏上串口把 PrePi 走通了

判据来自屏上串口（`FrameBufferSerialPortLib`，`USE_SCREEN_FOR_SERIAL_OUTPUT=1` 本机已开）：

| 观察 | 含义 |
|---|---|
| 屏上出现 `UEFI firmware (version … built at … on …)` | `Platforms/AndromedaPkg/PrePi/PrePi.c:133-143` 的 `SerialPortWrite` —— **Mu PrePi 已执行，且屏上串口输出生效**（字符串在本机 FD 内 `strings` 命中） |
| 插桩后依次出现 `[P01]`…`[P08]`、`[P10]`、`[P11]`（`[P09]` 未布点，非漏执行） | `ArmPlatformInitialize`→`ArchInitialize`→`SerialPortInitialize`→**`MemoryPeim`**→`BuildStackHob`→`BuildCpuHob`→`PlatformPeim`→`ProcessLibraryConstructorList`→**`DecompressFirstFv`**→**`LoadDxeCoreFromFv`** 全部返回 |

⇒ **PrePi 整段走完，已把控制交给 DXE Core**（`LoadDxeCoreFromFv` 返回后才打的 `[P11]`）。
这同时解释了 §4 的 1.9 GB `0xFF` 大填充：它发生在 PrePi 侧（`MemoryPeim`/MMU/内存 HOB 这段），不是 shim。

插桩与镜像：
- `patches/uefi/20261104-prepi/0001-prepi-screen-serial-step-marks.patch`（`SbMark()`，每步一行 `[Pnn]`）
- `out/uefi-20261104-prepi.img`（`e5aa7164…`，FD `53b5bdad…`）
- 前置：`patches/uefi/20261103-posctrl/0002-*` + `20261104-{fbband,m3block,prog,nocivac}/*`

**下一步（唯一）**：把同样的屏上串口插桩打进 **DXE Core**（`MU_BASECORE/MdeModulePkg/Core/Dxe/DxeMain/DxeMain.c` 的 9 个相位点 + `Dispatcher/Dispatcher.c` 每 dispatch 一个 `>`），
判据 = `[D00]`…`[D08]` 与 dispatch 进度点；能打到 `[D08]`（`gBds->Entry`）就说明 DXE 全量 dispatch 完成、进 BDS 菜单。
注意：`MU_BASECORE` 是 **submodule**，改文件后还原要在子模块里 `git checkout --`（主仓 `git checkout` 不认这两个路径）。
