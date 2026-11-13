# 设备会话 — 2026-11-13 夜：vk191 ramdisk 零写盘验证 + s2idle 复测

> 设备 = U2（`HA2EXB0E`，16+512）；全程**零写盘**（未 flash、未改任何分区），结束态 = RAM 启动在 `vk191`。
> 相关坑：`PITFALLS #650`（暖复位后立刻 `fastboot boot` 不可靠）。

## §0 结论数字

| 判据 | 结果 |
|---|---|
| `vk191` 零写盘启动 | ✅ 一次通过（`ssh elden-root 'reboot bootloader'` → `fastboot boot`，SSH 20 s 内回） |
| `Unpacking initramfs...` / `no cpio magic` | ✅ 解包正常、**无** `no cpio magic`（旧 ramdisk 的 602 字节全 0 问题不再出现） |
| `Run /init as init process` | ✅ `[ 7.671104]`，随后 `[init] root fs type=ext2/ext3 on_initramfs=0` ⇒ `switch_root` 成功 |
| gadget `iSerialNumber` | ✅ `HA2EXB0E`（= 原厂 SN，非旧模板 `HA2CB1KY`） |
| DSI / WiFi / fastrpc / 传感器 / Waydroid | `connected` / `up` / `/dev/fastrpc-adsp` 在 / `iio-sensor-proxy active` / `waydroid-container active`；声卡 2 张；zram 7.79 GB |
| s2idle `rtcwake -m mem -s 45` | **3/3 rc=0**，uptime 连续（151→199→249→299），唤醒后 DSI connected / WiFi up / 33.8 °C |
| `ASoC error (-16)`（Q33 冷起症状） | 本 boot **0 次**（历史冷起曾 5425 行） |
| 内核 panic | 0 |

## §1 做了什么（可按序复现）

```bash
# 1) 主机侧：修 ramdisk（真因 = build_full 只换 /init，不换 usb-gadget）
#    scripts/build-initramfs.sh 两处修：BASE 相对路径失效；build_full 现在同步 usr/local/sbin/usb-gadget
scripts/build-initramfs.sh full out/ramdisk-vk181-working.cpio.gz   # → out/initramfs-full-elden.cpio.gz（sha 17cbcab1…）

# 2) 单变量打包：vk190 的 kernel+dtb 原样，只换 ramdisk
python3 scripts/mkbootimg.py --unpack out/boot-elden-vk190.img --unpack-dir /tmp/cmp190
python3 scripts/mkbootimg.py --header_version 2 --os_version 15.0.0 --os_patch_level 2025-08 \
  --kernel /tmp/cmp190/kernel --ramdisk out/initramfs-full-elden.cpio.gz --dtb /tmp/cmp190/dtb \
  --cmdline "<vk190 的 cmdline 原文>" --base 0x0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 \
  --second_offset 0xf00000 --tags_offset 0x100 --dtb_offset 0x1f00000 --pagesize 4096 \
  -o out/boot-elden-vk191.img
# 校验：kernel/dtb 与 vk190 逐字节相同，只有 ramdisk 不同（selftest PASS）

# 3) 上机（零写盘）
ssh elden-root 'sync; reboot bootloader'; fastboot devices; fastboot boot out/boot-elden-vk191.img
```

**注意**：`scripts/build-boot.sh` 直出会连带换 DTB（`build/daily` 现有 DTB ≠ vk190 内嵌的），
所以本轮用 `mkbootimg.py` 显式取 vk190 的 kernel/dtb，保证单变量。

## §2 一次事故与定因（`PITFALLS #650`）

第一发用 `scripts/to-fastboot.sh --boot out/boot-elden-vk191.img`：设备进了 fastboot，
`fastboot boot` 之后**立刻黑屏**，随后出现「系统崩坏 + core dump」类告警，几十秒后自行回正常槽位启动。

- 对照：**同一镜像**改用 `ssh elden-root 'sync; reboot bootloader'`（systemd 正常关机路径）后 `fastboot boot` ⇒ **一次通过**。
- 差异点：`to-fastboot.sh` 用 `eldroid-bootctl reboot bootloader` = `SYS_reboot(RESTART2,"bootloader")`
  = PSCI 厂商**暖复位**，跳过 systemd 关机序列（服务不停、UFS/PMIC 不做有序下电）。
- 处置：上机默认改 systemd 路径；`scripts/to-fastboot.sh` 头部已加 WARNING，`--boot` 标不推荐。
- **未解释**：屏上原文只有人目击，`/sys/fs/pstore` 为空（ramoops 存在但未落盘）⇒ 不据此断言镜像坏；同镜像对照已否证。

## §3 本轮顺带查实的三条事实

1. **本机 DT 没有 `serial-number` 节点**（`/proc/device-tree/` 只有 `chassis-type`）⇒ `initramfs/usb-gadget`
   的首选来源恒为空，实际走第二源 `cmdline:androidboot.serialno`。不是 bug，但**判据要按这条写**
   （`grep serial-number /proc/device-tree` 无输出属正常）。
2. **电源节点名 = `qcom-battmgr-bat`**（不是 `battery`）：`capacity=100`、`status=Charging`。
   「充电抖动」类排查要按这个路径取数（`/sys/class/power_supply/battery` 不存在）。
3. **`dmesg | grep -ci 'arm-smmu.*fault'` 会假阳性**：它命中 cmdline 里的 `arm-smmu.disable_bypass=0`。
   正确判据 = `dmesg | grep -i smmu | grep -i fault` 并排除 `Kernel command line` 行。

## §4 未做 / 下一步

- 未 flash `boot_b`（本轮零写盘）；`vk191` 只是 ramdisk 化，**不入版本账**（仅作 A10/C-U1 的载具验证）。
- A10 的 UEFI 侧两发（`vk188b` + A2 臂 pstore 复测）仍需 UEFI 路径（`set_active a` 或物理 POR 选菜单）。
- B6（dwc3 v9）/B18（闪光灯）需要先按补丁建树出镜像，今晚无窗口。
- C-I1 待机功耗仍只有「短窗计数 3/3」，**无电流实测**（需要外接表）。

## §5 件与位置（不入 `out/`，避免撞 vk 账）

| 件 | sha256 | 位置 |
|---|---|---|
| `boot-elden-vk191.img`（单变量：vk190 kernel/dtb + 新 ramdisk） | `c14dc3e54cb7ec42e25a106ce039fbdfcff4ffff51a184e97c110601cb4bfe8e` | `backup/device-test-20261113/`（+ `.manifest`） |
| `boot-elden-vk191-rd.img`（`build-boot.sh` 直出，**DTB 已变**，只作对照，未上机） | `d7498f2ae6447c8ffa1dbe907b4e75cec1bd7c69bc424393b47b89b64af177a4` | 同上 |
| `initramfs-full-elden.cpio.gz`（含动态 SN 的 usr/local/sbin/usb-gadget） | `17cbcab1dc1ed165…`（`build-initramfs.sh verify` 可复现 OK） | `out/`（资产，随可复现门） |
