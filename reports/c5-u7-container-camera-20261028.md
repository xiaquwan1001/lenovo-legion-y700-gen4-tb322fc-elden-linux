# C5/U7 容器相机：从「需装 APK」推进到「HAL 静态元数据为空」——真卡点换人（2026-10-28）

> 触发：`继续任务` 按顺序的第 3 项（C5/U7 容器相机 App 预览）。原口径「剩 App 侧停帧，需装 APK」。
> 性质：**有设备写**（容器重启、`modprobe/rmmod v4l2loopback`、`/usr/local/sbin/cam-mode.sh` 替换），**未刷写、未重启整机**。
> 收尾已把设备恢复日常态：CAM-OFF（相机模块 0）、`v4l2loopback` 已卸、`dpms=On`、seat0 会话 `c1`、失败单元 0。

## §0 结论（数字）

| 项 | 结果 |
|---|---|
| 是否需要装 APK | ❌ **不需要**：镜像里已有 `net.sourceforge.opencamera`（OpenCamera）与 `com.google.android.apps.googlecamera.fishfood` |
| 之前 `Number of camera devices: 0` 的真因 | **容器启动时主机没有 `/dev/video100`**，LXC 的 `create=file` bind 于是造了一个 **0 字节普通文件**（`----------`，不是字符设备）⇒ 容器里永远看不到相机；之后 `modprobe v4l2loopback` 也不会自愈，**必须重启容器** |
| 修好后 | `Number of camera devices: 1`；external provider `@2.4` 枚举出 `1280x720@30` |
| 三种像素格式 | NV12 → `initOutputCharsKeys: format NV12 is not supported!`；YUYV → `not supported!` + `advertising YUV streams for YUYV`（兜底分支）；**MJPG → 正常枚举、零告警** |
| App 行为（三格式都一样） | OpenCamera `Camera 200: Opened` 后**立刻 disconnect**，伴随 `E/camera_metadata: validate_camera_metadata_structure: metadata is null!` + `E/Camera2-Metadata: acquire: Failed to validate metadata structure 0x0` ⇒ **cameraserver 拿到的 static metadata 是空的** |
| ⇒ 真卡点 | **不是像素格式、不是 App**，是容器侧 external HAL 的 **`getCameraCharacteristics` 返回空 metadata** |

## §1 复现链（可复跑）

```sh
# 1) 主机侧：造出 loopback 节点（buffers/格式按 scripts/cam-loopback.sh 头注释）
modprobe v4l2loopback video_nr=100 max_buffers=8 exclusive_caps=1
bash scripts/cam-loopback.sh start front 1280x720 30      # libcamerasrc → v4l2-ctl --stream-out-mmap=8
#    → 30.2 fps，`v4l2-ctl -d /dev/video100 --get-fmt-video` 显示 1280x720 NV12

# 2) 容器侧：**必须重启容器**才吃到新节点（见坑 1）
setsid nohup runuser -u <会话用户> -- env XDG_RUNTIME_DIR=/run/user/<uid> WAYLAND_DISPLAY=wayland-0 \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/<uid>/bus waydroid session start &

# 3) 容器内取证（`waydroid shell` 传不了 `sh -c`，见坑 2）
lxc-attach -P /var/lib/waydroid/lxc -n waydroid -e -- /system/bin/sh -c 'dumpsys media.camera | grep -m1 Number'
lxc-attach ... -c 'logcat -d -v brief -s CamPrvdr@2.4-external:*'      # 枚举过程
lxc-attach ... -c 'am start -n net.sourceforge.opencamera/.MainActivity'
lxc-attach ... -c 'logcat -d -v brief' | grep -E 'Camera2-Metadata|Opened|disconnect'
```

## §2 三种格式的 HAL 行为（逐字日志）

| 生产者格式 | HAL 日志 | 结论 |
|---|---|---|
| NV12 | `W/ExtCamDev@3.4: initOutputCharsKeys: format NV12 is not supported!` | 该 HAL 的格式映射表**不含 NV12**（与 `cam-loopback.sh` 头注释「必须 NV12」的旧结论冲突，见 §4） |
| YUYV | `… format YUYV is not supported!` + `I/…: advertising YUV streams for YUYV` | 走 YUV **兜底**分支 |
| MJPG | 无告警，正常枚举 | 唯一「干净」分支 |

三种格式下 App 的结局相同（`metadata is null`）⇒ 换格式**不能**解决 C5/U7。

## §3 顺带修掉的两个真实缺陷（`scripts/cam-mode.sh`）

| 缺陷 | 后果 | 修法 |
|---|---|---|
| 会话用户写死 `uid 1000` / `xuqianhui1001` | Alpine 根是 `1000/xuqianhui`，**Debian 根是 `1001/xuqianhui1001`** ⇒ `find_bus` 永远空 | 现查：`loginctl list-sessions` 的 seat0 用户 + `id -u` |
| 提权工具写死 `sudo -u` | **Debian 根没有 `sudo`**（`command not found`）⇒ `GS()` 把 stderr 吞掉后只看 stdout ⇒ **blank 守卫静默变空操作**，而 status 照常打印 CAM-ON/CAM-OFF | 按可用性选 `sudo` / `runuser`，都没有则**明确报错**（守卫不静默） |

修前 `cam-mode.sh status`：`idle-delay = `（空）；修后：`idle-delay = uint32 300`。脚本已同步到设备。

## §4 旧结论更正

`scripts/cam-loopback.sh` 头注释写「★格式必须是 **NV12**：Android 的 external camera HAL 只把 NV12 映射成 YCbCr_420_888；YUYV 走兜底分支 ⇒ `generated preview size list is empty` ⇒ 相机打不开」。
本轮实测：**在本镜像（2026-10-19 构建，`camera.device@3.4-external-impl.so`）的 HAL 里 NV12 才是"不支持"的那个**，MJPG 枚举最干净。
⇒ 该注释的格式结论**与当前镜像不符**，下次动 loopback 前先按 §2 的方法重新测一遍，不要照抄。

## §5 下一步（C5/U7 真卡点的最短路径）

1. **打印缺失键**：用 AOSP `external camera HAL` 源码对照本镜像版本（`/vendor/lib64/hw/camera.device@3.4-external-impl.so`，2026-10-19），
   确认 `getCameraCharacteristics` 返回空是「某个必需键缺失」还是「HAL 直接回错误」。
2. **换 provider 版本**：镜像内同时有 `camera.provider@2.5-external.so`，但 `/vendor/bin/hw/` 只有 **2.4** 的 service 二进制、init rc 也只声明 2.4
   ⇒ 要么补 2.5 的 service，要么回退到镜像自带的 2.4 已知好组合（需确认 T22 当时那版镜像的行为）。
3. 备选：把 `ANDROID_SENSOR_INFO_*` / `SCALER_AVAILABLE_STREAM_CONFIGURATIONS` 通过 HAL 的 `--camera-id-list`/配置文件补进去（需先知道 HAL 支持的注入方式）。
4. 记住**顺序**：先确认 `Number of camera devices`，再看 `Camera2-Metadata`，最后才看 App —— 三者混在一起会误判成「App 停帧」。

## §6 产物

- 本报告；`scripts/cam-mode.sh`（会话用户/提权工具现查）；设备侧脚本已同步。
- 证据链日志：本轮 `logcat` 关键行已逐字引在 §2/§0（未落盘成文件；复跑命令见 §1）。
