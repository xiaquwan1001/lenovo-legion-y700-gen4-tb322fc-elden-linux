# #728 零写盘旧件的根标签漂移停在 initramfs（2026-11-25）

## 现象
`fastboot boot out/boot-elden-vk192.img`（11-16 打的件）→ 设备**只有背光**、桌面不来；
USB gadget 正常枚举（主机 `lsusb` 见 `1d6b:0104`），但主机网卡没 IP（后来发现是主机侧没配 `.3`），
SSH 上去后：
- `uname -r` = 期望的在机核（`…-00005-g4bdf1711b5c0`）
- `command -v systemctl` **空**、`/sys/class/drm` **无 card0**、`ls /` 是 initramfs 布局
- `cat /proc/cmdline` → `elden_root=LABEL=linux17`
- `blkid /dev/sda17` → `LABEL="linux"`（2026-11-18 磁盘重建时改的名）

## 根因
initramfs 按 `elden_root` 找根，找不到就**故意**留在 shell（这是设计行为，不是 hang）；
画面只有背光是因为用户态从没起来、DRM 从未 modeset。

## 判据（30 秒区分 Q28 / 本坑）
- `cat /proc/cmdline | tr ' ' '\n' | grep elden_root`
- `blkid /dev/sda17`（或 `findfs LABEL=linux17`，`rc=1` 即不匹配）
- `command -v systemctl`（空 = initramfs）

## 处置
- 只改 cmdline 重打包：`python3 scripts/boot-img-cmdline.py <img> --set "<新 cmdline>" -o <new.img>`（自带三段 sha 自证）
- 或者 `reboot -f` 让 `boot_b` 起（其 cmdline 已是 `LABEL=linux`）
- **长期**：`scripts/build-boot.sh` 的默认 cmdline 与磁盘 LABEL 应有单点真源（当前靠人工记忆），建议下次动打包脚本时把它参数化。

## 连带事实
- 主机侧 NCM 网卡每次设备重启都会重建，且**新 boot 可能不带 .3 地址** ⇒ `sudo scripts/ncm-host-up.sh`（幂等）；漏了这步会误判「系统没起来」。
- 候选核件（UTS 不同）零写盘 boot 时，`CONFIG_INPUT_UINPUT=m` 等模块加载不到 ⇒ `lisgd-edge-swipe`/`ydotool` 会失败数十次并刷 journal，属预期，不是回归。
