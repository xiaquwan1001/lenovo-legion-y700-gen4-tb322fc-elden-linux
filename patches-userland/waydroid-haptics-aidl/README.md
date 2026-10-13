# waydroid-haptics-aidl — AIDL V2 vibrator HAL（elden）

替换 Waydroid 镜像自带的 HIDL 1.0 vibrator HAL（它写 AOSP `leds`/`timed_output` 节点，
主线没有这些节点、而且它不检查写失败 ⇒ Android 侧全绿、马达不动；并且 HIDL 1.0 在 A13
下既无幅度控制、`cancel` 也不会更早调 `off()`）。

本 HAL 把请求写成宿主桥文件（见 `scripts/elden-hapticd.c`）：

| 文件 | 语义 |
|---|---|
| `/sys/class/leds/vibrator/state` | 1/0（信息） |
| `.../duration` | ms |
| `.../amplitude` | 0..255（`setAmplitude` / `perform` 强度映射） |
| `.../activate` | 1=起振、0=停振（**最后写**，daemon 以此为触发边沿） |

能力：`CAP_AMPLITUDE_CONTROL`（Android 强度滑杆生效）、`off()` 真停（framework `cancel` 生效）、
`perform()` 支持 CLICK/TICK/THUD/POP/DOUBLE_CLICK/HEAVY_CLICK；未实现的能力一律
`EX_UNSUPPORTED_OPERATION`（不谎报）。

## 编译（waydroid-build 树）

```bash
cp -r patches-userland/waydroid-haptics-aidl /mnt/Samsung/waydroid-build/hardware/waydroid/vibrator-aidl
cd /mnt/Samsung/waydroid-build
export CCACHE_DIR=/mnt/Samsung/ccache USE_CCACHE=1
source build/envsetup.sh && lunch lineage_waydroid_arm64_only-userdebug
mmm hardware/waydroid/vibrator-aidl
```

产物：`out/target/product/waydroid_arm64_only/vendor/bin/hw/android.hardware.vibrator-service.elden`
+ `.../vendor/etc/vintf/manifest/android.hardware.vibrator.elden.xml`。

## 部署

见 `scripts/waydroid-haptics-aidl-deploy.sh`（零写盘：把二进制 bind 到镜像里那条 HIDL 服务路径上，
把 vintf fragment 目录 bind 到容器 `/vendor/etc/vintf/manifest`）。
回退 = 删掉两条 `lxc.mount.entry` + 全量重启容器。

## 实测结果（2026-10-13，U2 `HA2EXB0E` / `vk124-merged` 零写盘台）

| 项 | 命令 | 结果 |
|---|---|---|
| 框架识别 | `waydroid shell dumpsys vibrator_manager` | `mCapabilities=[AMPLITUDE_CONTROL]`、`mSupportedEffects=[CLICK, DOUBLE_CLICK, TICK, THUD, POP, HEAVY_CLICK]` |
| Android 幅度 | `cmd vibrator_manager synced oneshot -a 300 160`（**`-a` 必须写**） | daemon `amp=160/255`；HAL logcat `vibrator amplitude -> 160` |
| 每侧强度叠加 | daemon `--amp-a 0xffff --amp-b 0x4000` + `oneshot -a 300 128` | `A=0x8080 B=0x2020`（有效幅值 = 侧上限 × Android 幅度） |
| 预定义效果 | `synced prebaked 0/2/5`（整数 id） | `perform()` 10 / 5 / 16 ms |
| cancel | `synced -B oneshot 8000` + 1.2 s 后 `cancel`（**`-B` 必须写**） | 同秒 `off()` → daemon `vibrate OFF`（立即停） |

坑（详见 `PITFALLS #239–#242`）：CLI 的 `-a`/整数 effect id/`-B` 三个假阴性；servicemanager 强制 VINTF 声明；
框架 `cancel` 是 graceful（是否立即停看 `CompleteEffectVibratorStep`）；换二进制前必须先停容器（ETXTBSY）。
