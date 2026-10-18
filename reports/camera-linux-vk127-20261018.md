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

---

## 5. ★重要更正（同一晚，用户就位明亮场景后复测）：出流 ≠ 可用

**结论**：驱动/V4L2 层没问题，**libcamera 的软件 ISP 只把第 0 帧写进输出缓冲**，其后全零 ⇒ **Linux 成像不可用（未解）**。
记录：`reports/trials/20261018T051918Z-cam-linux-vk127-imaging.json`（verdict=**FAIL**）。

### 5.1 判别式（逐帧看，别只看首帧）

| 路径 | 结果 |
|---|---|
| **裸 V4L2**：`v4l2-ctl -d /dev/video0 --stream-mmap --stream-count=3 --stream-to=/tmp/b.raw`（4080×3072 pgAA，15 667 200 B/帧） | **3/3 帧都有真实数据**：帧首 8 KB mean **25.59 / 20.53 / 20.68**，nonzero ≈ 95% |
| libcamera（默认，EGL debayer）`cam -c1 -C40` | 帧 0 mean **15.9**；**帧 1–39 全零**；`LIBCAMERA_LOG_LEVELS=*:DEBUG` 显示 debayer **每帧都在跑**（3/3 次，blackLevel 0.0627 / gamma 0.4545 参数正常） |
| libcamera + `LIBCAMERA_SOFTISP_MODE=cpu` | **帧 0–3 全零**（`bytesused` 变 50 036 736 = 4072 宽，说明换了路径） |
| libcamera + **stock IPA**（`/root/ipa-bak-20261017/ipa_soft_simple.so`，198 648 B） | **与自编 AE-fix IPA 完全一致**：帧 0 有数据、1+ 全零 ⇒ **不是自编 IPA 的问题** |

### 5.2 归因与下一步

- 已经排除：kernel/CSID/VFE（裸 V4L2 3/3 好）、sensor（同一次流）、自编 IPA（stock 同现象）、场景/曝光（裸路径有数据）。
- 剩余最可能：**libcamera `simple` pipeline 的 `SoftwareIsp` 输出回写**——EGL 路径只有第一个 `FrameBuffer` 被写，CPU 路径一个都不写；
  EGL 侧（`debayer_egl.cpp` 的 `setOutput()`/dmabuf → EGLImage 绑定）在多缓冲下的缓存/绑定失效，是最可疑点。
- 下一步（按代价）：
  1. 用 **libcamera 0.7.1 源码 + `SoftwareIsp` 单元测试**复现（host 侧即可部分复现）；
  2. 试 **更早/更新的 libcamera**（Alpine 包版本或自编 0.6/0.8）确认是否回归；
  3. 绕行：C5 的帧源改走**裸 V4L2 + 自己的 ISP/转换**（`v4l2src` 取 pgAA → host/GPU debayer → v4l2loopback），代价是丢掉 libcamera 的 AE。
- 设备收尾：IPA 已恢复为自编 AE-fix 版；`CAM-OFF`（模块 0 / 节点 0 / `blank` idle 300 + lock true）；桌面（phoc）与音频（wireplumber）均在跑。

---

## 6. 根因排查（按推荐顺序第 1 步：主机/设备侧最小复现）

### 6.1 已排除的三条假设（都有正/反证据）

| 假设 | 检验 | 结果 |
|---|---|---|
| **Mesa/EGL 对「同一个 texture 重绑新 EGLImage」不生效** | 设备侧 60 行最小程序（`/tmp/egltest.cpp`）：dma_heap 两块 dma-buf → 同一个 texture 依次绑 EGLImage → 各 clear 一种颜色 → `glFinish` → CPU mmap 读像素 | ❌ 假设错：`buf1←red (255,0,0)` / `buf2←green (0,255,0)` / `buf1←blue (0,0,255)` **全部正确**；`GL_RENDERER=Adreno (TM) 830 / freedreno / Mesa 26.1.6` |
| **GPU→CPU 的 dma-buf 可见性（cache 一致性）** | 同上程序在**硬件 GL**（freedreno）下读回 | ❌ 假设错：硬件 GL 下 CPU mmap 也能读到 GPU 写的新值 |
| **`egl.cpp` 里 `EGL_DMA_BUF_PLANE0_OFFSET_EXT` 硬编码 0**（libcamera 0.7.1 与 master 都是 0）导致所有帧写进 buffer 0 | 抓 `cam` 进程的 fd：`/proc/<pid>/fd` 有 **4 个独立 dma-buf**（`/dmabuf:frame-0…3`） | ❌ 假设不成立（每个 FrameBuffer 一个 fd、offset 均为 0） |

### 6.2 现象再确认（更硬的形式）

`cam -c1 -C5 --file='/tmp/fr_#.bin'`（**每帧一个文件**，排除 app 写单文件时的拼接问题）：
`fr_…000000.bin mean B=15.8`，`000001..000004 = 0.0` ⇒ **app 侧读取没问题，是 buffer 里真的没有数据**。
`LIBCAMERA_LOG_LEVELS=*:DEBUG` 显示 `DebayerEGL::debayerGPU` 的 `setShaderVariableValues` **每帧都执行**（3/3），且 `glGetError()==0`。

### 6.3 下一步（第 2 步，已确认可行）

设备上 **`meson`/`ninja`/`g++`/EGL+GLES 头全都在**，可以直接在设备上构建 libcamera 0.7.1（源码 1.9 MB 可取）：
在 `DebayerEGL::process()` 里加两处日志/回读：
1. `LOG << "out fd=" << out_fd << " offset=" << plane.offset << " len=" << plane.length`（对照 `/proc/pid/fd` 的 `frame-N`）；
2. `glFinish()` 后 **CPU 回读该 buffer 首 4 KB 的均值**并打日志。

判据：若 `process()` 里回读就是 0 ⇒ ISP 侧问题（FBO/EGLImage/管线）；若回读有数据而 app 读到 0 ⇒ 是 buffer 交付/映射环节（pipeline 把错误的 FrameBuffer 交给了 app）。
这一步能把「libcamera 内部 vs pipeline 交付」一次分开。
