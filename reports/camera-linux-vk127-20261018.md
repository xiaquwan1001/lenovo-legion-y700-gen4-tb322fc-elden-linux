# Linux 侧相机在 7.3 vk127 上出流成功 + 冷起无桌面（greetd 崩）修复（2026-10-18）

> 背景：`TASKS` G1-5「相机出流」的既有记录停在 2026-10-07（7.2 vk47clean）；M1-7.3 树上 2026-10-15 只记到
> 「相机栈加载成功但 `STREAMON` 失败（`vfe4_rdi3` EINVAL / `vfe0_rdi0` EPIPE）」。
> 本轮在**在机 vk127（7.3-rc7 + 下游 payload 重放）**上实测：**双摄均出流 30 fps，无 dmesg 错误**。
> 同时修掉「冷起无桌面」（greetd 崩溃）。
> 记录：`reports/trials/20261018T050452Z-cam-linux-vk127-rear.json`、`…050458Z-…-front.json`。

---

## 1. 结论（数字先）

| 项 | 结果 |
|---|---|
| 后摄 `s5kjns`（`cci@ac7b000` i2c 0x56） | `cam -c1 -C2`：seq 0/1，**30.06 fps**，`bytesused 50 331 648` = **4072×3072 ABGR8888** |
| 前摄 `gc08a8`（`cci@ac7c000` i2c 0x31） | `cam -c2 -C20`：**30.26 fps**，`bytesused 31 961 088` = **3264×2448 ABGR8888**，20 帧全收 |
| dmesg | 全程 **0** 条 `camss/vfe/csid/EPIPE/EINVAL` |
| media-ctl | `s5kjns`/`gc08a8` → `msm_vfe{0,1}_rdi*` 链路 **ENABLED**；`/dev/media0` + 17 个 `/dev/video*` |
| libcamera | v0.7.1，pipeline `simple`，软 ISP `ipa_soft_simple.so` 正常起 worker |
| 亮度 | 单帧/20 帧末帧 mean ≈ **0.2–16**（std ≤7.6）⇒ **画面是暗的**（设备平放在桌、镜头朝下/无光源，且 AE 统计每 4 帧一次、只跑了几帧）——**「有没有成像」不能用这组样本判**，见 §3 |
| 桌面 | 修好：`greetd` 守护化后 `Session c4 / tty7 active`、`phoc` + `gnome-session` 在跑、`grim` 截图 = phosh 锁屏（时钟已校时 13:06） |
| 设备收尾 | 相机模块 **0**、`/dev/media*` `/dev/video*` **0**、`blank` 恢复存档值（idle 300 / lock true）、wireplumber 已拉回（pactl 正常） |

## 2. 「冷起没有桌面」= greetd 崩了（已修）

- 现象：SSH 可用、`card0-DSI-1=connected`、面板 GOOD，但 `loginctl` **无会话**、`phoc/phosh` 不存在；
  `rc-status` 里 **`greetd [crashed]`**（同一 boot 里 `seatd`/`elogind` 都 started）。
- 判据链（下次直接照这个查）：
  ```
  rc-status | grep -i greet        # crashed?
  loginctl list-sessions           # 空
  pgrep -af 'phoc|gnome-session'   # 空
  ls /run/user/1000 | grep wayland # 无 wayland-0
  ```
- 根因（未逐字取证，但修复后 3/3 复起）：上游 initd 的 `depend()` 只有 `need localmount`，
  **没有 `after seatd elogind`**，冷起时 seat/PAM 未就绪 → greetd 退出后 openrc 不再重试（`command_background=yes` 无守护）。
- 修法（已部署到设备，源文件入库 `rootfs/persistent-overlay/etc-initd-greetd`）：
  - `depend() { need localmount; after seatd elogind; provide display-manager; }`
  - 交给 **`supervise-daemon`** 守护：`respawn_delay_seconds=5`、`respawn_max=10`、`output_log=/var/log/greetd.log`
  - 备份：设备侧 `/etc/init.d/greetd.bak-20261018`
- 手工救场（无需重启）：`setsid /usr/sbin/greetd --config /etc/greetd/config.toml &` → 15 s 内 phoc+phosh 起来。

## 3. 关于「成像质量」的诚实边界

- 本轮只证明 **驱动/管线出流**（帧率 + 满帧 `bytesused` + 零 dmesg 错误 + media link ENABLED），
  **没有**证明画面内容正确（亮度 0.2–16，等同全黑）。
- 原因叠加：① 设备平放、镜头朝桌面/无光；② 软 ISP 的 AE 统计**每 4 帧一次**（`PITFALLS #303`），
  2–20 帧远未收敛；③ `exposureTarget` 之前调成 0.22（明亮场景未复测）。
- **下一步（需一次物理动作）**：对着明亮场景（窗/灯）跑 `cam -c2 -C120 --file=/tmp/f.jpg`，
  看末帧 mean 是否落到 60–180 区间、且随场景变化；再顺手把 `tuning` 的 `exposureTarget` 做 0.18/0.22 A/B。

## 4. 与 C5（容器相机）的关系

C5 的前置 ①（主机侧 V4L2 loopback + libcamera 软 ISP 帧源）**已在 2026-10-17 完成并被本轮再次证实**（软 ISP 30 fps 满帧）。
容器侧 ②b 的阻塞与相机无关（外来 64-bit HIDL 进程在容器里碰 `getRawServiceInternal` 即崩，见
`reports/waydroid-camera-provider-64bit-20261018.md` §9、`PITFALLS #316/#317`）。
