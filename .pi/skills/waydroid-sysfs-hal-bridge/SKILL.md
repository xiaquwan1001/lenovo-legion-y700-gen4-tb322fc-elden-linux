---
name: "waydroid-sysfs-hal-bridge"
description: "Waydroid 硬件透传：容器 HAL 只写「主线不存在的 sysfs 节点」导致功能静默失效时，用宿主桥目录 + lxc.mount.entry 覆盖容器 /sys/class/*，再由宿主 daemon 转成主线驱动动作，并用 kprobe 取证。触发词：waydroid 马达/振动不生效、vibrator HAL 起了但没反应、leds/timed_output 节点不存在、容器 /sys 只读没法建节点、lxc.mount.entry 挂 sysfs、透传怎么验证、dumpsys 正常但硬件不动。"
version: 2
created: "2026-10-13"
updated: "2026-10-13"
---
## When to Use
当容器里某个 HAL 功能（马达/灯/背光/传感器类）「HAL 在册、dumpsys 无报错」但硬件毫无反应，而 mainline 缺它期望的 sysfs/设备节点时。

## Procedure
1. 先定位 HAL 到底写什么：读取像里的 HAL 二进制/源码（`strings /vendor/bin/hw/<hal> | grep -E "^/sys|timed_output|leds"`），或直接在 waydroid-build 树里读 `hardware/waydroid/<x>/`。
2. 判断「静默失败」：若 HAL 用 ofstream/fopen 写节点且不检查返回值、状态无条件返回 OK，则 Android 侧永远看不出问题 ⇒ 不能用 dumpsys/lshal 当判据。
3. 在宿主建桥目录（如 /run/<name>/leds/vibrator/{state,duration,activate}，mode 0666，容器内 uid 1000=system 要能写），由 OpenRC 服务 start_pre 创建（/run 是 tmpfs）。
4. 用 lxc.mount.entry 覆盖：`lxc.mount.entry = /run/<name>/leds sys/class/leds none bind,create=dir,optional 0 0`。只能覆盖「已存在」的目录（容器 /sys 是只读 sysfs，不能 mkdir）；父目录不存在的路径（如 /sys/devices/virtual/timed_output/...）不可桥。要事后 nsenter 补挂，再补一条把宿主目录绑到容器 /run 的 entry。
5. 宿主 daemon 轮询桥文件 → 调主线驱动。起停都必须有安全上限，且**自己超时停振后要把触发文件写回 0**，否则下一轮 poll 会重新起振（自触发环）。
6. 改容器前先备份 `/var/lib/waydroid/lxc/waydroid/config`；Waydroid「全量重启」= `for p in $(pgrep -f "usr/bin/waydroi[d]"); do kill -9 $p; done` + `lxc-stop -k` + `waydroid container start` + `wd-ctl.sh session`（只 stop/start 会留残留 session，容器不再拉起）。
7. 覆盖设备侧正在运行的二进制：先 `停服务 → scp → 起服务`（否则 ETXTBSY: dest open ... Failure）。

## Pitfalls
- AIDL HAL 想在容器里注册：servicemanager **强制**校验 VINTF 声明——未声明时 `AServiceManager_addService` 返回 -3（logcat: `Could not find <iface> in the VINTF manifest`）。加 fragment 到 `/vendor/etc/vintf/manifest/*.xml`（bind 整个目录），且**必须重启容器**（servicemanager 启动时读）。
- 替换镜像里的 vendor HAL **不用 overlay**：把自编二进制 bind 到镜像中**已存在**的同名/同位置服务路径（如原 HIDL 服务的 `/vendor/bin/hw/...`），镜像的 rc 会照旧拉起它——省掉 mount_overlays 与 init 改动，回退只需删挂载项。
- 换二进制前**先停容器**：bind 目标正在运行 ⇒ `scp` 报 `ETXTBSY`（`dest open ...: Failure`）；顺序 stop → scp → start。
- `rm -rf` 对外挂盘（如 `/mnt/Samsung/...`）会 EXDEV（本环境删除走 `~/y700-elden/.pi/trash/`）⇒ 用 `/bin/rm -rf`。
- 框架侧时序：`SetAmplitudeVibratorStep` **先 `on(duration)` 再 `setAmplitude()`** ⇒ HAL 的 setAmplitude 必须在「运行中」改写 amplitude 通道，否则强度永远停在最初值。
- 框架 `cancel` 是 graceful（`notifyCancelled(..., immediate=false)`）：是否立即 `off()` 取决于 `CompleteEffectVibratorStep`（ramp 时长 vs step 时长）。HIDL 1.0 时代这条路径到不了 HAL；AIDL HAL 才有 `off()`。
- CLI 验证陷阱：`cmd vibrator_manager synced oneshot` 必须写 `-a` 才带幅度参数；`prebaked` 要**整数** effect id（0=CLICK…5=HEAVY_CLICK）；`cancel` 只对 `-B`（后台）振动有效（token=service）。
- HAL 日志用 `#define LOG_TAG` 固定，否则 tag 随运行时的文件名/路径变化，logcat 过滤会漏。
## Verification
1. 容器内 `ls -l /sys/class/leds/vibrator/` 可见且属主为 system；`echo` 写入无 EACCES。
2. 清 trace → `echo 1 > tracing_on` → kprobe 挂 `aw86927_haptics_play` → 触发一次：命中数 >0，且 `+2 s` 与 `+6 s` 计数相等（无自触发环）。
3. 框架级触发：`waydroid shell cmd vibrator_manager list`（有 id）→ `synced oneshot 500` → daemon 日志出现一次 ON/OFF，桥文件 `activate` 回到 0。
4. 物理手感仍需人手确认（内核证据只证明「命令到了驱动」）。