# 显示/相机/Waydroid/刷写细节（2026-11-11 从 AGENTS.md 下沉）

- boot.img 打包用 `scripts/mkbootimg.py`（v2 头，pack/unpack/--selftest）：magic `ANDROID!`、name@48、cmdline@64、id@576（20B sha1 必须补零到 32B）、header_size=1660；ramdisk 可从基线 boot_b 原位抽。
- Q28 判据：GOOD = `L1=0` + `dsi_isr=41` + card0-DSI-1 connected + dmesg `panel prepared: scheduling firmware upload`；BAD 含 `command DMA timeout: status=0x2200200` / `bonded ... master=-110 peer=-110` / `dcs data ff 20 failed: -110 或 -5`。坏发按会话成簇，软件 reboot 不解除，只有真 POR 能恢复。
- 桌面/熄屏判据：`/sys/class/drm/card0-DSI-1/dpms` 是 0644 只读、写入需 ~2.5s 生效 → 必须带延时 + 回读校验，否则整轮样本是假 INVALID-NO-BLANK；判桌面在不在要抓帧看亮度，不能只看 pgrep phoc。
- 冷起无桌面根因 = greetd 崩溃 → initd 补 `after seatd elogind` + 交给 `supervise-daemon` 托管；应急旁路 `setsid /usr/sbin/greetd --config /etc/greetd/config.toml ... &`。
- M1-7.3 内核重放 = 7.3-rc7(`24a19b953`) + payload v2（**取 vk64 树**）+ 上游 `PLL_SYSTEM_MUXES` → 稳定 16 个冲突；DTB 保真判据 = `sm8750-lenovo-elden.dtb` 153101 B 与基线相同、仅剩 q6apm/q6prm 8 行差异；资产 `patches/replay-2026-10-17/`。
- a 槽跑自研件卡 logo = 原厂 `dtbo_a` 的 Android DTBO 被 ABL 合进我们的 DTB → `truncate -s 33554432` 全 0 刷 dtbo_a（`scripts/uefi-a-slot-prepare.sh`）；判槽不能看 `androidboot.slot_suffix`（boot.img 头烤死 `_b`），要在 cmdline 埋唯一标记。
- 设备失联判读：enx 接口消失 + `lsusb` 出现 `18d1:d00d` = 在 fastboot → `fastboot reboot` 零写盘恢复。
- 设备时钟停在 1970 ⇒ HTTPS 全 rc=60、apk 报 index 无效；校园网把 HTTP 劫持到 202.141.180.1 → 先 `date -s`/time-sync，apk 走 https 或宿主中继；`ssh -R 7890` 会失败，用主机 python 中继。
- `fastboot fetch` 是幻觉（本机 ABL 不支持）→ 分区备份只有三条路：设备侧 `dd if=/dev/disk/by-partlabel/<part>`、EDL(9008)、已有副本。
- Waydroid 走 OpenRC 非 systemd：`rc-service waydroid-container start` → `waydroid session start`；Q28 坏态无 phoc 用 `scripts/waydroid-headless-start.sh`（weston headless + session dbus）。
- 容器 codec list=0 的真根因 = waydroid `lxc.py` 硬编码 `debug.stagefright.ccodec=0` → `waydroid prop set debug.stagefright.ccodec 4`（得 53 个 codec）。
- vendor.img：`resize2fs` 只扩块不扩 inode（496 inode 恒满）→ 必须 `mke2fs -N 8192` 重建并 `sif` 改属主 0:2000；容器内文件覆盖优先 LXC bind-mount。
- 容器 HAL A/B：自编 64bit camera provider 注册成功但首笔 binder 事务 SIGSEGV → 属容器/HIDL-ABI 层；资产 `patches/waydroid-camera-64bit-20261018/`。
- 相机判真出流看 STREAMON rc + 字节数，不看首帧均值；后摄「黑」= libcamera 0.7.1 缺 s5kjns/gc08a8 `CameraSensorHelper` + pedestal 4096 未扣 → `patches/camera-ae-fix-20261017/`（AGC exposureTarget 可调，yaml 设 0.22）；真实持续帧率 30 fps。
- 相机故障分层：`CSID reset timeout` / `Failed to power up pipeline: -110` = CSID/VFE 复位失败；`media-ctl ... Resource busy (16)` = 上次 stream 未释放，需重载 camss 模块（先 `killall wireplumber`）。
- 主机静默损坏史：镜像/产物 sha 一律 `dd iflag=direct` 复算；`git fsck` 一律 `--full`；`echo 3 > /proc/sys/vm/drop_caches` 在本机直接卡死自动重启。
- 设备侧抢资产：`ssh root@<ip> 'tar -C / -cf - <绝对路径> | zstd'`（必须绝对路径 + `-C /`），解压后 sha 双端对账。
- 用户口径：优先「尽可能利用上游、减少下游补丁」；多变量连续失败立即停手归档；可能阻塞的命令一律 `timeout -k`；用户目视/体感报告优先于脚本读数。

