# 收尾三项（2026-10-23 晚，无需物理 POR）：Q29 Mesa bind、背光下限、容器相机通路

> 本轮只做**不需要物理 POR** 的项；需要用户在机旁断电/开机的样本一律排在最后（见 §5）。
> 设备态：在机 `boot_b = vk152`（`uname -r` = `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`），全程未重启、未写盘。

---

## 0. 数字结论

| 项 | 结果 | 判据 |
|---|---|---|
| **Q29** Mesa bind 与镜像内 Mesa 是否重复 | **9/11 逐字节相同；2 个（`libgallium_dri.so`、`hw/vulkan.freedreno.so`）同尺寸但不同 build**（`.text`/`.rodata` **相同**，仅 `.eh_frame`/`.plt`/`.got.plt`/build-id 不同） | 段级：`objdump -s -j .text \| sha256` 两边相同；`readelf -n` build-id 不同 |
| Q29 删除全部 Mesa bind 后容器图形 | **正常**：`GLES: freedreno, Adreno (TM) 830, OpenGL ES 3.2 Mesa 26.1.8` | `dumpsys SurfaceFlinger` |
| **背光下限** | 已装 `backlight-floor` OpenRC 服务，`brightness 200 → 1024` 在 ≤25 s 内被钳回 | `--check` / `--once` / 篡改后复测 |
| **容器相机** | `/dev/video100` 未绑进容器时 `Number of camera devices: 0`；绑入后 **1**（`Device 0 maps to "200"`，Facing Front） | `dumpsys media.camera` |
| 前后摄（loopback 侧） | 前摄 / 后摄各出一帧序列：`Y mean 51.6→54.3`（前）、`19.6→19.6`（后） | `cam-loopback.sh test 10` |
| 容器内 App 级预览 | **未做**：镜像内无相机 App（`pm list packages` 仅 `com.android.cameraextensions`、`googlecamera.fishfood`），`am start STILL_IMAGE_CAMERA` 后 `Active Camera Clients: []` | 需要装 APK（用户决定） |

---

## 1. Q29：容器 vendor 镜像 Mesa vs 宿主 bind Mesa

### 1.1 取证方法（不启动容器也能比）

`vendor.img` 是 ext4；容器可停、可用 `debugfs` 只读抽文件：

```
debugfs -R "dump /lib64/libgallium_dri.so /tmp/q29b/lib64/libgallium_dri.so" $IMG
```

对 `config_nodes` 里 `waydroid-mesa-swap` 段涉及的 **11 个文件**逐个比对（镜像副本 vs `/root/wd/mesa/...`）：

| 文件 | 判定 | 说明 |
|---|---|---|
| `lib64/dri_gbm.so`、`lib64/egl/lib{EGL,GLESv1_CM,GLESv2,GLES}_mesa.so`、`lib64/hw/gralloc{,.minigbm_gbm_mesa}.so`、`lib64/libgbm_mesa{,_wrapper}.so` | **SAME**（7 个） | sha256 逐字相同 |
| `lib64/libgallium_dri.so` | **DIFF** | 同尺寸 18 970 896 B；`cmp -l` 差 91 002 字节；段级 `.text`/`.rodata` **相同**，仅 `.eh_frame*`/`.plt`/`.got.plt` 与 build-id 不同 |
| `lib64/hw/vulkan.freedreno.so` | **DIFF** | 同尺寸 13 749 400 B；`cmp -l` 差 1 769 283 字节；同样只在 unwinding/PLT 层不同 |

`strings` 的 Mesa 版本、freedreno 源路径两边完全一致（`Mesa 26.1.8`、`../src/freedreno/...`）
⇒ **同源两次独立构建**（不同构建环境导致的除代码段外的布局差异），不是两份不同版本。

### 1.2 处置：删 bind 并实测

`config_nodes` 备份到 `config_nodes.bak-q29-<ts>`，删掉 `waydroid-mesa-swap` 段全部 11 条 bind
（段标记保留为空段，便于回滚时定位），随后 `scripts/waydroid-cam-restart.sh` 起真实桌面会话：

```
Session: RUNNING   Container: RUNNING   Session user: xuqianhui1001(1000)   Wayland display: wayland-0
容器内：GLES: freedreno, Adreno (TM) 830, OpenGL ES 3.2 Mesa 26.1.8
/vendor/lib64/libgallium_dri.so       18970896 2026-10-13 12:03   ← 镜像内那份
/vendor/lib64/hw/vulkan.freedreno.so  13749400 2026-10-13 12:03
```

⇒ **Q29 关闭**：bind 冗余，已移除；容器图形栈直接用镜像内 Mesa 26.1.8（freedreno/Adreno 830 正常）。
**回滚**：`cp /var/lib/waydroid/lxc/waydroid/config_nodes.bak-q29-20261023-221233 config_nodes` 后重启容器。

> 注：`grep mesa /proc/mounts` 仍有 3 条命中，均为 `allocator.rc` / `vintf manifest` 路径名带 `gbm_mesa`，
> 与 Mesa 库无关（不是残留 bind）。

---

## 2. 背光下限（「面板 GOOD 但看起来像黑屏」）

### 2.1 现象与代价

2026-10-23 本会话开头即撞一次：设备一切正常（`card0-DSI-1=connected/enabled`、DSI 0 错误、
`phoc` 在跑、会话 active、SSH 通），但 `aw99706-backlight/brightness = 160/4095 ≈ 4%` ⇒ 人看到「没响应/黑屏」，
误判为设备状态异常。根因两条叠加：

1. 驱动默认 160（≈4%）；
2. `org.gnome.settings-daemon.plugins.power ambient-enabled = true`（自动亮度）会在冷起后把亮度压回低档。

### 2.2 修法（两层，落地）

| 层 | 内容 |
|---|---|
| 用户态 | `ambient-enabled` 置 **false**（dconf 持久写，`/home/xuqianhui1001/.config/dconf/user` 已确认含该键；重启保持） |
| 服务 | 新增 `scripts/elden-backlight-floor.sh` + OpenRC 服务 `backlight-floor`（`supervise-daemon`，20 s 轮询，只在**发生钳位**时写日志） |

```
# /etc/conf.d/backlight-floor
BACKLIGHT_FLOOR=1024      # 1024/4095 ≈ 25%
```

入库位置：`scripts/elden-backlight-floor.sh`、`rootfs/persistent-overlay/etc-initd-backlight-floor`、
`rootfs/persistent-overlay/etc-conf.d-backlight-floor`。

### 2.3 验收

```
$ elden-backlight-floor.sh --check
aw99706-backlight brightness=1024 max=4095 floor=1024
$ echo 200 > .../brightness ; sleep 25 ; cat .../brightness
1024
$ tail -1 /var/log/backlight-floor.log
aw99706-backlight: 200 -> 1024 (max 4095)      ← 只在实际钳位时写
```

主机侧干跑（临时 sysfs 替身）也验过三态：钳位、幂等（第二次 `unchanged`）、无设备 `rc=1`。

---

## 3. 容器相机：`/dev/video100` 没绑进容器 ⇒ 0 devices

C5 ②b 在 2026-10-19 达成的 `Number of camera devices: 1`，本轮重启容器后**回落成 0**。
排查结论：**不是 provider 坏了**（`init.svc.vendor.camera-provider-2-4-ext=running`、
`ICameraProvider/external/0` 在 `lshal` 里 `Y`），而是 `config_nodes` 里**从来没有 `/dev/video100` 的 bind**：

- 之前那次成功是**手工在会话里绑的**，重启即丢（`config_nodes` 里 `grep video` = 0，和 `.bak` 一致）；
- `dumpsys media.camera` 的 `Camera Provider HAL external/0-0 (v2.5, remote) static info: 0 devices:` 就是它。

### 修法（已写入持久配置）

```
lxc.mount.entry = /dev/video100 dev/video100 none bind,create=file,optional 0 0
```

（插在 `waydroid-mesa-swap` 段之前；`optional` ⇒ 节点不存在时容器照常启动。）

### 验收

```
主机： modprobe v4l2loopback exclusive_caps=1 video_nr=100 → /dev/video100
      scripts/cam-loopback.sh start front 1280x720 30
      scripts/cam-loopback.sh test 10 → frames 10 / Y mean 51.6→54.3
容器： dumpsys media.camera → Number of camera devices: 1 / Device 0 maps to "200" / Facing: Front
切后摄： cam-loopback.sh stop; start rear → test 10 → frames 10 / Y mean 19.6
```

⇒ **前后摄在 loopback 侧均可出帧**；external HAL 只有 1 个 external 设备（`device@3.4/external/200`），
所以「切换」= 换 loopback 生产者，**不是**换 Android 侧 camera id —— 这也是 U7 的语义结论。

### 顺带修掉的脚本假阳性（`cam-loopback.sh start` 曾 100% 拒启动）

旧互斥判据 `pgrep -af 'cam .*-c|captureScript|gnome-snapshot|snapshot'` **会命中内核线程 `[disp_snapshot]`**
（display 快照相关，与相机无关）⇒ 永远返回「已有相机客户端在跑」、`start` 永远 `REFUSE`。
改为只匹配用户态客户端（`ps -eo pid,args`，排除 `[...]` 形态的内核线程与本脚本/grep 自身）：

```
新判据命中数 0 ；旧判据命中数 1（[disp_snapshot]）
```

### U7 剩余（未做，如实记账）

- **容器内 App 实开预览**：镜像内没装相机 App。`am start -a android.media.action.STILL_IMAGE_CAMERA`
  后 `Active Camera Clients: []` ⇒ 需要装一个相机 APK（用户的决定，本轮不做）。
- 吞吐上限 ≈1.1 fps（原生）/ 2.0 fps（720p），软 ISP 瓶颈，未变。

---

## 4. 设备收尾态（安全）

| 项 | 状态 |
|---|---|
| `boot_b` | `vk152`，`qbootctl -m b` = successful，`card0-DSI-1=connected/enabled` |
| 背光 | `1024/4095`（下限守护在跑，`rc-service backlight-floor status` = started） |
| Waydroid | `Session: RUNNING` / `Container: RUNNING`，`Session user: xuqianhui1001(1000)`（真实桌面会话） |
| 相机 | 生产者已 `cam-loopback.sh stop`；`/dev/video100` 节点留在（模块未卸），无消费者 |
| 变更清单 | `config_nodes`（删 11 条 mesa bind + 新增 video100 bind，含 `.bak-q29-20261023-221233` 回滚件）、`/etc/init.d/backlight-floor` + `/etc/conf.d/backlight-floor`、`/usr/local/sbin/elden-backlight-floor.sh`、dconf `ambient-enabled=false` |

---

## 5. 剩下需要**物理 POR**的项（排在最后，用户在场时做）

| 顺序 | 项 | 为什么必须真 POR | 判据 |
|---|---|---|---|
| 1 | **`vk151`/`vk152` 日常候选 ≥8 发真 POR 冷起** | 暖复位会粘 Q28 坏态（`PITFALLS #166`），只有物理断电才算样本；当前只有 1 次上机核验（`DSI_PLL_lockfail=0`、`STORM=0`） | ≥8 发全 GOOD + `DSI_PLL_lockfail=0` + `failed to acquire mdss resets=0`；脚本 `scripts/q28-disp-ab-sample.sh vk151` 或直接 `q28-coldboot-collect.sh <round>`（boot_b 已是 vk152，无需 fastboot） |
| 2 | **Q28 `q28-clkdiag` 坏发样本** | 判据（pclk1/byte1 parent+rate、`ctl N reset failure`）只有在**坏启动**上取才有意义；好坏对照必须同口径冷起 | 好/坏各一份 `reports/artifacts/q28-clkdiag-r<round>-<bootid>.txt` |
| 3 | **N5b/T10 臂扩样（暂停中）** | 每轮要 `fastboot boot` vk64 RAM 内核 | 恢复条件 = Q28 v2 压掉坏 boot 类之后再对拍；当前按用户裁决暂停 |

**不需要 POR、但需要用户决定的**：容器内相机 App 预览（要装 APK）、C3 PI 检测 App（要 APK）、
T11 宿主内存（BIOS / memtest86+ / 单条排查，硬件侧动作）。

---

## 6. 复现命令清单

```bash
# Q29：任意时刻可复查（容器可停）
ssh root@192.168.7.1 'debugfs -R "dump /lib64/libgallium_dri.so /tmp/x.so" /var/lib/waydroid/images/vendor.img'
cmp -s /tmp/x.so /root/wd/mesa/lib64/libgallium_dri.so || echo DIFF

# 背光下限
ssh root@192.168.7.1 '/usr/local/sbin/elden-backlight-floor.sh --check; rc-service backlight-floor status'

# 容器相机端到端
scripts/cam-loopback.sh start front 1280x720 30 && scripts/cam-loopback.sh test 10
ssh root@192.168.7.1 'lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/sh -c "dumpsys media.camera | head -5"'
scripts/cam-loopback.sh stop        # ★ 收尾必须显式停，否则 Linux 侧任何相机客户端都会被 Resource busy
```
