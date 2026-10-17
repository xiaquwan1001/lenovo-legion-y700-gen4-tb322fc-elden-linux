# 四十一、设备侧熄屏自动化两坑：`dpms` sysfs 只读、坏发 boot 上会话「先崩后稳」

> 2026-10-17 晚实测。收录 **#294–#295**。场景：Q24/N7 在 `vk127` 上跑「完整相机栈 × 真实熄屏」。
> 主报告：`reports/q24-n7-vk127-20261017.md`。

## #294 `/sys/class/drm/card0-DSI-1/dpms` 是**只读**的（`-r--r--r--`），root 也写不进

- **现象**：`echo Off > /sys/class/drm/card0-DSI-1/dpms` → `bash: … Permission denied`；
  随后读回仍是 `On`。
- **后果**：想「不依赖桌面会话、直接用内核 DPMS 制造显示断电」的做法在本机**不可行**。
  设备侧自动熄屏只有两条路：
  1. `org.gnome.ScreenSaver.SetActive(true)`（走 phoc 的会话总线；历史 Q24 配方就是这条）；
  2. `modetest`/libdrm ioctl（要单独装工具）。
- **坑中坑**：写失败时 `echo` 的退出码在一个 `ssh '…'` 串里容易被吞掉，于是 harness 若只看
  「命令发出去没报错」就会把 `On->On` 当成「已熄屏」⇒ **假阴性**。
  ⇒ 熄屏必须**读回 `dpms` 并校验 `On -> Off` 跃迁**，否则该发记 `INVALID`（见 `#288` 的假 ALIVE 教训）。
- **附带**：`dpms` 只读但 `status`/`enabled` 正常可读，判断连接器状态不受影响。

## #295 Q28 坏发 boot 上的 `phoc` 会 crash-loop，约 3 分钟后才稳定

- **现象**：坏发 boot（`command DMA timeout` + `bonded command DMA failed`，`dsi_isr=0`）后，
  `phoc` 起来 → 死 → `greetd` 拉起 → 再死；`dmesg` 里是
  `drm_crtc_wait_one_vblank → drm_client_modeset_wait_for_vblank → drm_fb_helper_damage_work` 的 trace。
  `loginctl list-sessions` 一开始为空，`uptime≈190 s` 后才稳定出会话（`phoc`+`phosh`）。
- **坑**：在崩溃窗口里抓会话总线，会拿到**已死 phoc 的** `DBUS_SESSION_BUS_ADDRESS`，
  之后所有 `gdbus` 调用报 `Error connecting: The given address is empty` / 无对象，
  看起来像「ScreenSaver 不存在」，实际只是总线过期。
  ⇒ 取值方式必须是**当前 `pidof phoc` 的 `/proc/<pid>/environ`**，并在调用失败时先确认 pid 没变。
- **可用的副产品**：坏发 boot 上「熄屏 → 唤醒」每次都重新走一遍失败的板端初始化，
  `Q28sig`（`command DMA timeout|Failed to initialize panel` 计数）**逐发递增**（本次 4→9）。
  这既是「坏发 = 持续性 down-state」的量化证据，也证明唤醒路径**真的被执行**（不是 no-op）。
- **纪律**：坏发上做任何会话侧实验，先等 `pidof phoc` 稳定（本次 ≈190 s），
  并且每发都打印当前总线前 30 字符，便于事后判断是不是抓到了旧会话。
