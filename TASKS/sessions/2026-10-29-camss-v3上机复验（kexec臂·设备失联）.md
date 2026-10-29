# 2026-10-29 camss v3 上机复验：kexec 臂设备失联（待物理确认）

- **日期**：2026-10-29 12:30–13:10
- **pi 会话 id**：`01a18576-f4bd-752d-bd55-ffff5dba9473`
- **主题**：给 M4 camss v3（锁 + write-then-clear）做一轮上机出流复验
- **结论（截至失联前）**：
  1. 构建侧**已完成且干净**：在 `build/vk-camssv3`（= `build/vk151` 日常树副本 + M4 v3 的
     `camss-csid.h` / `camss-csid-980.c` 两文件）`make -j26 Image dtbs` = **rc=0 / 0E0W / 34 s（增量，ccache 热）**；
     `Image` 60 127 744 B，`sm8750-lenovo-elden.dtb` 153 265 B；`reg_update_lock` 在 980 文件里 8 处命中。
  2. kexec `--load-only` 通过（相同 cmdline、相同 DTB）。
  3. `kexec-boot.sh` 执行后**设备从 USB 总线上消失**（`lsusb` 无 `05c6/18d1/1d6b:0104`），
     `192.168.7.1` 无应答、无 `192.168.42.x` 可连；主机侧仅剩华为手机 tethering（`192.168.42.97/24`）。
- **与既有坑的对应**：`PITFALLS #378b`（`mask=1` 跳 `device_shutdown` ⇒ 目标继承 dwc3 活态，**无网络无串口**）；
  `#378c` 目标复位回 `boot_b` 需 **+310~330 s**。本轮已等 >10 min 仍未回总线 ⇒ **超出该窗口，需物理确认**。
- **未证实**：目标内核是否真的跑起来（无网无法取 dmesg；`kexec_marker=1` 那条路要 `/init` 白名单支持且本轮未启用）。
- **下一步（需用户物理动作）**：确认屏幕/指示灯 → 长按电源 10–15 s 强制重启 → 回 `boot_b`（持久 vk172）；
  恢复后改用**带 `kexec_marker=1`** 的臂（写盘取证）或直接走持久内核（build-boot + fastboot，需物理 POR）。
- **产物**：`build/vk-camssv3/`（13 G 树副本 + Image/dtb，可复跑）、日志 `/tmp/camssv3-build.log`。
