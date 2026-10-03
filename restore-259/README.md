# restore-259 — Y700 四代 (TB322FC) ZUXOS 1.5.10.259 恢复/免解 root 资产

> 来源：社区「免解 BL root」重签包（123pan 分享/B站「悲伤的压缩包」教程）。
> 本目录只放**与 build `ZUXOS_1.5.10.259_260611_PRC` 配套**的镜像；原 zip 在 `_zips/`。
> 核对：三个 vbmeta 的 build fingerprint 均为 `Lenovo/TB322FC[_PRC]/TB322FC:16/.../ZUXOS_1.5.10.259_260611_PRC:user/release-keys`。

## 目录

```
restore-259/
├── README.md                      ← 本文件
├── xbl_s_devprg_ns.melf           ← EDL 引导（救砖）；qdl 用
├── 重签包/
│   ├── abl_a.img          1 MiB   ← ★改过的引导器（免解关键，有风险）
│   ├── boot_a.img        96 MiB   ← 与官方 boot.img 完全一致（sha256 同）
│   ├── recovery_a.img   100 MiB
│   ├── vbmeta_a.img         12 KiB ← 自签；管 boot dtbo init_boot recovery vendor vendor_boot
│   └── vbmeta_system_a.img   4 KiB ← 自签；管 system product system_ext pvmfw
├── KSU/
│   ├── init_boot.img      8 MiB   ← KSU 补过的 init_boot
│   ├── vbmeta.img        12 KiB   ← KSU 版自签 vbmeta（配 init_boot）
│   └── KernelSU_v3.2.5_32525-release.apk
└── _zips/                         ← 原始压缩包（备份）
```

## ★ 最重要的一条：Android 卡动画时**先试另一个槽**

2026-09-29 实测：主线折腾后设备 `current-slot=b`，Android 卡在启动动画（动画还在动、机身发热），
**并没有坏** —— 只是漂到的 b 槽引导链不配套。一条命令解决：

```bash
fastboot --set-active=a
fastboot reboot
```

→ 进系统、数据完好。**所以「Android 卡动画/进不去」第一步永远是切槽试试，别急着重刷/清数据。**
（`fastboot getvar current-slot`；a/b 都试一次。）

## 免解 BL root（build 1.5.10.259）

原理：用**改过的 `abl`（信任自签密钥）+ 自签 `vbmeta`/`vbmeta_system`**，让系统以为仍是原厂签名。
所以 **abl 与 vbmeta 必须配套一起刷**，不能只刷一半。

### 步骤（务必逐条、每条确认 OKAY）

先切到 a 槽（本包按 a 槽做）：

```bash
cd ~/y700-elden/restore-259
fastboot --set-active=a
fastboot flash abl_a            重签包/abl_a.img
fastboot flash boot_a           重签包/boot_a.img
fastboot flash recovery_a        重签包/recovery_a.img
fastboot flash vbmeta_a          重签包/vbmeta_a.img
fastboot flash vbmeta_system_a   重签包/vbmeta_system_a.img
fastboot reboot
```

进系统后，再刷 KSU 两个文件：

```bash
fastboot flash init_boot_a KSU/init_boot.img
fastboot flash vbmeta_a    KSU/vbmeta.img
fastboot reboot
```

最后手动安装 `KSU/KernelSU_v3.2.5_32525-release.apk`。

### 回退 / 救砖

- **回原厂 Android**：重刷原厂 `boot`/`init_boot`/`vbmeta`（见 `~/下载/tb322fc/`）+ 原厂 dtbo（`backup/dtbo_a.img`），或切回另一槽。
- **abl 刷坏（起不来）**：EDL 救回
  ```bash
  ~/y700-elden/qdl/build/qdl -s ufs restore-259/xbl_s_devprg_ns.melf write abl_a 重签包/abl_a.img
  # 或写回原厂 abl.elf
  ```
  进 EDL：`fastboot oem edl`（fastboot 下）或 `adb reboot edl`（Android 下）。

⚠️ `abl_a.img` 是改过的引导器，**这是唯一有砖风险的步骤**；刷它前确认 qdl 救砖链路可用。

## 关键事实（备忘）

- `boot_a.img` sha256 = `d4772c1189b5d4385718ef0db84ce4f32a6ef2629a32497554b65fba91705886`（= 官方 `boot.img`）。
- `abl_a.img` sha256 ≠ 官方 `abl.elf`（确实是补丁版）。
- 分区描述符不带槽后缀（只写 `boot`/`recovery`…）→ 刷 a 或 b 都行，AVB 自动加后缀。
- 设备分区大小：`abl`=1M、`vbmeta`=64K、`vbmeta_system`=64K、`init_boot`=8M、`recovery`=100M、`boot`=96M。

## 配套工具（在 `../y700四代工具/`）

- `工具/`：紫罗兰工具箱 V3.2、高通工具箱、刷机匣、OPPO 售后驱动（Windows）。
- `引导/`：二代/三代/四代/五代/无极 的 devprg（`xbl_s_devprg_ns.melf` 等）。
- `解BL/`：各代解锁工具箱（Windows）。
