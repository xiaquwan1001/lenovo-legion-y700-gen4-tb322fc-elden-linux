# Waydroid 马达透传（vibrator HAL → aw86927 FF）— 2026-10-13 实测

> 触发：用户「选一版本地能够亮屏的，我们开始做 waydroid 马达透传」。
> 上游口径：`TASKS.md` §6 兼容层设计 ⑤「马达走 `aw86927` + 容器 `vibrator` shim」。
> 踩坑编号：`PITFALLS #232–#238`（§二十八）。

## 0. 结论（先数字）

| 项 | 结果 |
|---|---|
| 本次上机镜像 | `out/boot-elden-vk124-merged.img`（sha256 `7f2136ae…`）**零写盘 RAM 直启**；**第 1 次冷起 = STORM**（操作者观察：只有背光无桌面）→ **操作者手动 POR 后第 2 次冷起 = GOOD**（`card0-DSI-1 connected dpms=On`、`bright=511`、`phoc/phosh` 在跑）⇒ 亮屏版本选定；本报告全部取证均在**第 2 次启动**的会话上 |
| 容器 | Waydroid Session/Container **RUNNING**（`wd-ctl.sh state`）；HIDL `android.hardware.vibrator@1.0::IVibrator/default` 在册（`lshal`，PID 89） |
| 透传链路 | Android `cmd vibrator_manager synced oneshot <ms>` → HAL 写桥文件 → 宿主 `elden-hapticd` → 内核 `aw86927_haptics_play` **kprobe 命中** |
| 单发 500 ms | 命中 6（2 马达）；`+2 s` 与 `+6 s` 计数相同 ⇒ 无自触发环 |
| 连击 20 ms × 8 | 命中 48（按键触觉级短振可跟随） |
| 未验证 | **物理手感/强度**（需人手确认）；~~幅度、`cancel`~~ → **二期 AIDL HAL 已实现并实测（见 §7）** |

## 1. 问题定位：HAL 在写不存在的节点，且失败无声

镜像 `vendor.img` **自带** vibrator HAL（不需要自己写）：

```
/vendor/bin/hw/android.hardware.vibrator@1.0-service.waydroid   (+ .rc: class hal, user system)
/vendor/lib64/hw/vibrator.default.so, /vendor/lib64/libvibrator.so
/vendor/etc/vintf/manifest.xml: android.hardware.vibrator@1.0 IVibrator/default
```

源码 = `/mnt/Samsung/waydroid-build/hardware/waydroid/vibrator/Vibrator.cpp`，`on()/off()` 就是写文件：

```
/sys/devices/virtual/timed_output/vibrator/enable   ← timeout_ms / 0
/sys/class/leds/vibrator/state      = 1
/sys/class/leds/vibrator/duration   = timeout_ms
/sys/class/leds/vibrator/activate   = 1 / 0
```

`set()` 用 `std::ofstream` 且**不检查返回值**；`on()` 无条件 `return Status::OK`。
主线 elden 的 `/sys/class/leds/` 只有 `mmc0::`、也没有 `timed_output` class ⇒ 全部写入失败，**Android 层完全看不出来**（`lshal`/`dumpsys vibrator_manager`/`cmd vibrator_manager list` 都正常）。

宿主侧真正的执行者是主线 aw86927 haptics 驱动：每个马达一个 input 设备 `aw86927-haptics`（`/dev/input/event2`、`event3`），能力 `EV_FF + FF_RUMBLE`（`input_ff_create_memless`），回调 `aw86927_haptics_play()`。

## 2. 桥的设计（不改镜像、不碰 `/vendor`、可逆）

```
 Android VibratorManagerService
   └─ HIDL IVibrator/default（容器内，user system = uid 1000）
        └─ 写 /sys/class/leds/vibrator/{state,duration,activate}
             │  ← lxc.mount.entry 把宿主目录 bind 到容器 /sys/class/leds（只读 sysfs 只能在已存在目录上 bind）
             ▼
        宿主 /run/elden-haptic/leds/vibrator/{state,duration,activate}  (0666, tmpfs)
             │  ← elden-hapticd 轮询 3 ms：上升沿起振 / 0 停振 / 自超时兜底
             ▼
        /dev/input/event2,3（aw86927-haptics）EVIOCSFF(FF_RUMBLE) + EV_FF write
```

为什么不是别的路：

- **overlay 自编 HAL**（C4 传感器路线 B）：要重编 arm64 HIDL service（build 树在 `/mnt/Samsung/waydroid-build`，但改动大、还要开 `mount_overlays`）；而 vendor HAL 已存在，只缺 sysfs 节点。
- **内核侧加 `leds`/`timed_output` 驱动**：能做成「零用户态」，但要改驱动 + 出镜像（Q28 期不便）；且 `leds-qpnp-vibrator` 那套 `activate/duration/state` 是非 mainline 自定义 ABI。
- 结论：**用户态桥 + bind mount** 最短、零写盘、删掉即可回退。

## 3. 资产清单（本轮新增）

| 文件 | 作用 |
|---|---|
| `scripts/elden-hapticd.c` | 宿主 daemon：找 `aw86927-haptics` FF 设备 + 轮询桥文件 + 起停 FF_RUMBLE（`--amp/--poll/--verbose`、15 s 安全上限、自清 `activate`） |
| `scripts/build-hapticd.sh` | `aarch64-linux-gnu-gcc -static` 交叉编译（产物 `out/hapticd/elden-hapticd`） |
| `scripts/waydroid-haptics-setup.sh` | 幂等部署：编译/上传 daemon（先停服务防 ETXTBSY）、装 init 脚本、加 lxc 挂载项（带备份）、全量重启容器、端到端验证（含 kprobe 取证）；`--restart` / `--verify` |
| `rootfs/persistent-overlay/elden-hapticd.initd` | OpenRC 服务：建桥目录/文件（0666 给容器 uid 1000）、起 daemon、`before waydroid-container` |
| 设备侧 | `/usr/local/bin/elden-hapticd`、`/etc/init.d/elden-hapticd`（default runlevel）、`/var/lib/waydroid/lxc/waydroid/config` 末尾两条挂载项（备份 `config.bak-elden-haptics`） |

## 4. 关键证据

1. **容器内可见/可写**：`waydroid shell ls -l /sys/class/leds/vibrator/` → `activate/duration/state`（owner `system`）。
2. **容器内写入 → 内核命中**（清 trace 后）：

```
container: echo 1 > .../state; echo 400 > .../duration; echo 1 > .../activate
kprobe aw86927_haptics_play hits: 16
daemon: [11:07:25] vibrate ON 400 ms (activate=1 duration=400)
```

3. **Android 框架级触发**：`cmd vibrator_manager list` → `0`；`synced oneshot 500` →

```
daemon: [11:08:04] vibrate ON 500 ms → [11:08:05] vibrate OFF (activate=0)   ← framework 自己调了 off()
kprobe: +2 s = 6, +6 s = 6（相等 ⇒ 无自触发环）; activate 文件回到 0
```

4. **短振连击**：8 × `oneshot 20` ⇒ 48 命中（每发一开一停 × 2 马达 + memless 重排）。
5. **基线（宿主侧）**：既有 `/usr/local/bin/vibrate 200`（ffrumble 封装）→ kprobe 4 命中，证明宿主 FF 路径本身可用。

## 5. 限制与后续

- **物理确认缺人手**：内核已收到并执行 FF 播放（kprobe + 驱动 work 命中），但「马达是否真的震」需用户确认（09-30 的 haptics 修复也是「用户确认」验收）。
- ~~HIDL 1.0：`supportsAmplitudeControl=false`、`cancel` 不提前停~~ → **二期已用自编 AIDL V2 HAL 解决（见 §7）**。
- 双马达目前**同强度同启停**（Android 只有 1 个 vibrator id）；将来可做左右差异（`--amp` 或按通道映射）。
- 依赖顺序：桥目录必须**先于容器启动**存在（OpenRC `before waydroid-container`；`lxc.mount.entry` 带 `optional`，缺了只是不挂、不会让容器起不来）。
- 冷启回归未做（避免无谓重启与 Q28 风险）；重装 rootfs 后靠 `restore.sh`（已加 `elden-hapticd` 段）恢复服务登记。

## 6. 复现

```bash
cd ~/y700-elden
# 1) 选一个能亮屏的本地镜像（本轮：vk124-merged，零写盘 RAM 直启）
fastboot boot out/boot-elden-vk124-merged.img
# 2) 部署桥（含全量重启容器 + kprobe 端到端取证）
bash scripts/waydroid-haptics-setup.sh --restart
# 3) 触发（Android 框架级）
ssh root@192.168.7.1 'waydroid shell cmd vibrator_manager synced oneshot 500'
# 4) 只验证
bash scripts/waydroid-haptics-setup.sh --verify
```

---

## 7. 二期：自编 AIDL V2 vibrator HAL（幅度 + cancel + 每侧强度，2026-10-13 下午）

一期桥已能打通「Android 振动 → 马达」，但镜像自带的 HIDL 1.0 HAL 有两个天花板：`supportsAmplitudeControl=false`（无强度控制）、`cancel` 不会提前把 `off()` 下发。二期把这层换掉。

### 7.1 做法

| 项 | 内容 |
|---|---|
| 新 HAL | `patches-userland/waydroid-haptics-aidl/`（AIDL V2，ndk binder；源码树 `hardware/waydroid/vibrator-aidl/`，`mmm` 约 47 s 出产物） |
| 部署 | **不碰 overlay**：把自编二进制 bind 到镜像里**已存在**的 HIDL 服务路径 `/vendor/bin/hw/android.hardware.vibrator@1.0-service.waydroid`，镜像的 rc 照旧拉起它；另把「镜像原 fragment + 我们的 fragment」目录 bind 到 `/vendor/etc/vintf/manifest` |
| 为什么必须改 VINTF | servicemanager **强制**校验声明：未声明时 `AServiceManager_addService` 直接失败（logcat `Could not find android.hardware.vibrator.IVibrator/default in the VINTF manifest`，返回 -3） |
| 桥 ABI 扩展 | 新增 `.../amplitude`（0..255）；`activate` 仍是**最后写入的触发边沿**，daemon 读到的 `duration`/`amplitude` 一定是最新值 |
| 能力声明 | `getCapabilities()=CAP_AMPLITUDE_CONTROL`；`getSupportedEffects()=CLICK/DOUBLE_CLICK/TICK/THUD/POP/HEAVY_CLICK`；其余一律 `EX_UNSUPPORTED_OPERATION`（不谎报） |
| 关键实现点 | 框架 `SetAmplitudeVibratorStep` 是**先 `on(duration)` 再 `setAmplitude()`** ⇒ `setAmplitude` 必须在运行中改写 `amplitude` 文件（daemon 会带新幅值重新上传 FF 效果），否则强度永远停在最初值（此坑已修） |

### 7.2 实测（同一台架，容器内 `waydroid shell`）

| 项 | 命令 | 结果 |
|---|---|---|
| 框架识别 | `dumpsys vibrator_manager` | `mCapabilities=[AMPLITUDE_CONTROL]`、`mSupportedEffects=[CLICK, DOUBLE_CLICK, TICK, THUD, POP, HEAVY_CLICK]` |
| Android 幅度 | `synced oneshot -a 300 160` / `-a 300 40` | daemon：`amp=160/255` / `amp=40/255`（HAL 侧 logcat：`vibrator amplitude -> 160 / -> 40`） |
| 每侧强度 × Android 幅度 | daemon `--amp-a 0xffff --amp-b 0x4000` + `oneshot -a 300 255` / `-a 300 128` | `A=0xffff B=0x4000` / `A=0x8080 B=0x2020`（叠加正确） |
| `perform()` 预定义效果 | `synced prebaked 0` / `2` / `5` | 10 ms / 5 ms / 16 ms（CLICK/TICK/HEAVY_CLICK） |
| **cancel** | `synced -B oneshot 8000`，1.2 s 后 `cancel` | `11:36:13` 起振 → `11:36:14` HAL `vibrator off` + daemon `vibrate OFF`（**立即停**；HIDL 1.0 时代做不到） |

### 7.3 残留与纪律

- **物理手感仍需人手确认**（框架/内核侧的整数与时序证据已齐）。
- CLI 参数陷阱（`PITFALLS #239`）：`oneshot` 必须写 `-a` 才会带幅度参数；`prebaked` 收**整数 effect id**；`cancel` 只对 `-B`（后台）振动有效（token = service）。第一轮「幅度没生效」全是这三条造成的假阴性。
- 部署顺序（`PITFALLS #235`）：**先停容器再 `scp`**，否则 bind 目标正在跑 → `ETXTBSY`。
- 回退：删 `/var/lib/waydroid/lxc/waydroid/config` 里 `# >>> elden-haptics aidl` 段的两条 `mount.entry` → 全量重启容器 ⇒ 立刻回到镜像原 HIDL 1.0 HAL（一期桥仍可用）。

---

## 8. 三期：固化进容器 vendor 镜像 + 补上「振动强度」UI（2026-10-13 下午）

### 8.1 为什么还要固化

二期靠两条 `lxc.mount.entry`（HAL 二进制 + vintf fragment 目录）实现，**能跑但依赖运行时挂载**；而且 LineageOS/Waydroid 的 Settings **看不到「振动强度」调节**。三期把 HAL 与相关补丁**做进镜像**，并补上强度档位。

### 8.2 强度 UI 缺失的真因（与 HAL 无关）

| 层 | 事实 |
|---|---|
| Settings 资源 | `packages/apps/Settings/res/values/config.xml`: `config_vibration_supported_intensity_levels = 1` |
| 控制器 | `VibrationIntensityPreferenceController.getMax() = min(VIBRATION_INTENSITY_HIGH=3, 该资源)`、`getMin() = OFF=0` ⇒ 上限 1，滑杆退化成「关/低」 |
| 本树 | `grep -rn config_vibration_supported_intensity_levels device/ vendor/` **无覆盖**（真机通常由 device overlay/RRO 提到 3） |
| 修法 | **静态 RRO** `EldenVibrationOverlay`（`targetPackage=com.android.settings`、`isStatic=true`、装 `/vendor/overlay`）只覆盖这一个整数 |

### 8.3 固化内容与实测

镜像内（零运行时挂载）：

```
/vendor/bin/hw/android.hardware.vibrator-service.elden        # 自编 AIDL V2 HAL
/vendor/etc/init/vibrator-elden.rc                            # 自带 rc
/vendor/etc/vintf/manifest/android.hardware.vibrator.elden.xml # vintf fragment
/vendor/overlay/EldenVibrationOverlay.apk                     # 静态 RRO（强度档位=3）
（原 HIDL HAL 及其 manifest 声明已从产品配置中删除）
```

| 验证项 | 结果 |
|---|---|
| HAL 来源 | 容器内 `ls -l /proc/<pid>/exe` → `/vendor/bin/hw/android.hardware.vibrator-service.elden`；`grep -c vibrator /proc/mounts` = **0**（无 bind） |
| 能力 | `mCapabilities=[AMPLITUDE_CONTROL]`、`mSupportedEffects=[CLICK, DOUBLE_CLICK, TICK, THUD, POP, HEAVY_CLICK]` |
| 静态 RRO | `cmd overlay list` → `[x] com.elden.vibration.overlay`；`cmd overlay lookup com.android.settings com.android.settings:integer/config_vibration_supported_intensity_levels` = **3** |
| 幅度 | `synced oneshot -a 300 160` → daemon `amp=160/255`（`A=0xa0a0 B=0xa0a0`） |
| cancel | `synced -B oneshot 8000` + 1.2 s `cancel` → 同秒 `off()` |

### 8.4 还剩什么、怎么回退

- **仅剩**：宿主侧 `elden-hapticd`（OpenRC 服务 + `/etc/conf.d`）+ 一条 `sys/class/leds` 桥挂载（把假 `leds` 类目录塞进容器）。它们都在持久根/overlay 快照里（`restore.sh` 覆盖）。
- 想彻底零挂载 ⇒ 走**内核侧**方案（在 aw86927 驱动里直接实现 AOSP leds-class `vibrator` ABI），见 `TASKS.md` C10 的「下一步」。
- 回退镜像：`/var/lib/waydroid/images/vendor.img.bak-elden-haptics-20261013-115055`（打补丁前的原镜像）。
- 复现：`scripts/waydroid-haptics-bake-patch.py`（幂等打产品配置补丁）+ `scripts/waydroid-haptics-bake-vendor.sh`（`m vendorimage` → 推设备 → 摘挂载 → 验证）。
