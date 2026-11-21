# 相机栈恢复（stock trixie 回退后，2026-11-21 22:0x–22:1x）

> 触发：D3④/D1 回归发现「整机无 libcamera」（`dpkg -l | grep -c libcamera` = 0），相机栈随 stock trixie 回退整体丢失。
> 环境：设备 vk192 日用态（7.3.1-debug-vk189-suspend…）、Debian 13 trixie、`ssh elden` 通、零物理动作。

## 结论（数字）

| 判据 | 结果 |
|---|---|
| 包恢复 | `libcamera-tools` / `libcamera-ipa` / `libcamera-v4l2` / `gstreamer1.0-libcamera` = **0.4.0-7**（trixie stable；backports 有 0.5.2，未用） |
| `cam --list`（root） | **2 台**：`Internal back camera`（cci@ac7b000/i2c-bus@0/camera@56 = s5kjns）、`Internal front camera`（cci@ac7c000→camera@31 = gc08a8） |
| 出流 | `cam --camera 1 --capture=3` = **32.3 / 30.1 fps**，帧 50036736 B（50 MB，16-bit 4096×3072 口径），采样 **mean=110.6 / nonzero=100%** ⇒ 非黑帧 |
| 唯一缺口 | `/dev/dma_heap/system` 是 **0600 root:root** ⇒ 非 root 的 libcamera 报 `Could not open any dma-buf provider` 并禁用 soft ISP（debayer）；root 下正常 |
| 修法（已上机并固化） | udev 规则 `SUBSYSTEM=="dma_heap", GROUP="video", MODE="0660"` → `/dev/dma_heap/system` 变 `crw-rw---- root video`；再以普通用户跑 `cam --list` = **2 台**（复现判据） |
| 内核侧 | 相机模块本就在机（`lsmod` 命中 camss/csiphy/cci 10 项）；`system_heap` 由打包件 `camera-modules-load.sh` 加载，无需新动作 |

## 固化为「重装即恢复」

| 文件 | 内容 |
|---|---|
| `packaging/elden-userland/files/etc/udev/rules.d/70-elden-dma-heap.rules`（新） | dma_heap → group `video` / 0660 |
| `packaging/elden-userland/files/etc/modules-load.d/elden-dma-heap.conf`（新） | 开机加载 `system_heap`（软 ISP 的 dma-buf provider） |
| `packaging/elden-userland/MANIFEST.tsv` | 上述两项登记（sha256/size/mode/repo_src），`tools/verify.sh` 的清单一致性门覆盖它们 |
| 包清单 | `rootfs/debian/apt-list.txt` 已有 `libcamera-tools` / `gstreamer1.0-libcamera`；**本机实测另外需要 `libcamera-ipa` 与 `libcamera-v4l2`**（软 ISP 与 v4l2 兼容层），建议下一轮补进 apt-list |

## 未做 / 风险

- **未做视觉效果确认**（用户目视）：本报告只证明「2 台相机可见 + 30 fps 非黑帧」；App 侧（预览/前后摄切换）未验。
- **未跑 AE 修正件**：`patches/libcamera-ae-totalfix-20261018/` 是 Alpine 0.7.1 世代的软 ISP 修正（Agc 曝光目标/增益步进/helper 身份增益）；trixie 0.4.0 的 soft ISP 表现是否同样，需在有视觉窗口时再判。
- **Q24 口径**：相机常驻 + 长时空闲的掉电风险只在 7.2 血统复现过，7.3 日常线免疫；本轮只做短时出流（<1 min）。
- **`tools/verify.sh` 另有存量 FAIL（设备 vs 仓副本 sha 漂移 ~10 文件：greetd/config.toml、cam-mode.sh、net-up.sh、q28-*.sh、slot-attr.py、time-sync.sh…）**：与本轮无关，属设备漂移待收口。
