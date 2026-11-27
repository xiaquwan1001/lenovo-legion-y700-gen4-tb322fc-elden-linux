# #749 `reboot2` 早该退役，但二进制还在 PATH 里 —— 只写「已停用」挡不住下一次手滑

- 日期：2026-11-27　设备：U1（TB322FC）　性质：工具卫生 / 上机纪律
- 关联：#368（`reboot2 bootloader` 后 USB 全不枚举）、#542（停用裁决）、#229（旧构建无参=进 fastboot）、
  #712（`systemctl reboot bootloader` 本来就是正确入口）、#650

## 现象（2026-11-27 晚，上一轮）

为进 fastboot 直接 `ssh elden-root 'sudo -n reboot2'`（无参）⇒ 主机侧 18:56:28 `USB disconnect`，
此后 `lsusb` 无 `18d1/05c6/1d6b`、`/dev/ttyACM*` 消失、SSH 超时；用户现场看到 **phosh 已出现、随后整机卡死**。
处置 = 停手 + 用户长按电源 ≥15 s（#368 的停手判据）。

## 根因不是「忘了口径」，是「口径只写在文档里」

`PITFALLS #368/#542` 与 `scripts/to-fastboot.sh` 头注都写了「reboot2 停用、唯一入口 = systemd」，
但 `/usr/local/sbin/reboot2` 仍然是一个 709 368 B 的可用 ELF（sha256 `0c68ee5f…`）⇒ 任何凭记忆
写命令的人都能再踩一次，且失败形态是「看起来重启了、其实挂死」。

## 处置（可复现）

`scripts/retire-reboot2.sh`（幂等，带 device-lock）：

- **留档**：真件 → `/var/lib/elden/retired/reboot2-20261127`（+ `.sha256`）与
  `/usr/local/sbin/reboot2.retired-20261127`；
- **换壳**：`/usr/local/sbin/reboot2` 换成 810 B 的 **拒绝壳**（sh，`rc=1`，打印正确入口）；
- **现机复核**：

```
$ ls -l /usr/local/sbin/reboot2*
-rwxr-xr-x 1 root root    810 11月27日 19:16 /usr/local/sbin/reboot2          # 壳
-rwxr-xr-x 1 1000 1000 709368 11月27日 19:16 /usr/local/sbin/reboot2.retired-20261127
$ reboot2; echo rc=$?
reboot2: RETIRED (2026-11-27) — 用 systemctl reboot --reboot-argument=bootloader
rc=1
$ sha256sum /var/lib/elden/retired/reboot2-20261127
0c68ee5fb3720caa849c7e3fa52d3615da2d4f29bce3b6f91f5f03c8f1294d05
```

## 判据与坑

- **判据** = `reboot2` 返回非 0 且提示正确入口；真件 sha 可查；`command -v reboot2` 仍命中（故意保留，
  让残留调用可见地失败，而不是 `command not found` 让人换成 `reboot -f`）。
- **重建会装回**：`rootfs/build-overlay.sh`、`rootfs/build-rootfs.sh`、`rootfs/configure-ubuntu.sh`
  都会 `gcc … reboot2.c` 生成真件 ⇒ **rootfs/镜像重建后必须重跑 `scripts/retire-reboot2.sh`**
  （`rootfs/persistent-overlay/restore.sh` 的旧构建自检也就此失效，属预期）。
- `q28-boot-watchdog.sh`（现机 disabled）的能力自检 `reboot2 -h | grep 'no argument = normal reboot'`
  拿不到旧 banner ⇒ 回退 `sysrq-b`，方向安全。
- **正确入口**（写死）：
  `ssh elden-root 'sync; systemctl reboot --reboot-argument=bootloader'`（systemd ≥257；
  老版本用位置参数）→ `scripts/to-fastboot.sh` / `scripts/elden-to-bootloader.sh` 是唯一封装。
