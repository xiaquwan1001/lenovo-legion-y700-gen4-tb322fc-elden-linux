# #765 `ACCEL_MOUNT_MATRIX` 旧标定在本机是错的：平放屏幕朝上却报 `face-down`（tilt 反向）

- **日期**：2026-11-28（lane S2 定因，父代理复核 `busctl` 缓存值）
- **机器**：Y700 四代 TB322FC；`/etc/udev/rules.d/81-libssc-elden.rules` + 仓内副本
  `packaging/elden-userland/files/etc/udev/rules.d/81-libssc-elden.rules` 写的是 `-1, 0, 0; 0, -1, 0; 0, 0, 1`（Alpine 期 2026-10-09 标定）

## 现象

平板**平放、屏幕朝上**（旁证：ALS 读到 64–496 lux，光敏面未被桌面遮住），`AccelerometerTilt` 却 = **`face-down`**：

```sh
sudo busctl --system get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy AccelerometerTilt
# s "face-down"      ← 错
```

静态原始读数 `a_raw ≈ (−0.952, +0.354, −9.522)`（`ssccli --sensor accelerometer`）代入旧矩阵 ⇒
`a_app = (+0.952, −0.354, −9.522)` ⇒ `tilt = atan2(z, √(x²+y²)) = −84°` ⇒ face-down（判据：`z > 0` 才是 face-up）。

## 为什么旧标定不能沿用

旧值来自 Alpine 期环境；现在 SSC 的 registry/config 由 `/usr/local/bin/hexagonrpcd-patched -R /var/lib/hrpcd-root/` 供给，
**同一型号不同供给链下传感器原始帧不同** ⇒ 旧标定值不可直接搬。叠加用户实测「竖屏 180° 错向」，两约束联立后
带符号置换族（48 个）里**唯一解**：

```
ENV{ACCEL_MOUNT_MATRIX}="1, 0, 0; 0, -1, 0; 0, 0, -1"      # ★2026-11-28 用户实机目视后的最终值
```

> 迭代过程（别重走）：先按两条口述约束解出 `diag(1,1,-1)`，用户实测「竖屏正常、**横屏 180° 颠倒**」⇒ 按 `orientation.c`
> 的 `landscape_rotation=atan2(y,·)`（`>0→bottom-up(180°)`、`<0→normal(0°)`）判定**第 2 行符号反了** ⇒ 改 `diag(1,-1,-1)`（`det=+1`，真旋转）。
> 教训：姿态矩阵不要靠"两条口述约束联立"定案，必须**两种姿态各目视一次**（竖屏 + 横屏），因为竖屏只锁 x 行、横屏才锁 y 行。

诚实标注：`det = −1`（不是真旋转，是镜像）。代理不校验 det，orientation/tilt 判据不受影响、可用；
若要"必须真旋转"，则说明两条约束有一条不成立，需按 `reports/sensors-orientation-als-20261128.md` §2.4 的候选表做一次物理动作区分。

## 判据与上线顺序

- **①** 改 udev 规则（**设备侧与仓内副本同改**）→ `udevadm control --reload && udevadm trigger --action=change /sys/class/misc/fastrpc-adsp`。
- **② 必须先解 `#764`**（或不重启代理直接 `udevadm trigger` 后由新会话 claim），否则 `AccelerometerTilt` 是缓存值，验收是假绿。
- **③** 验收：平放 ⇒ `face-up`；竖持顶边朝上 ⇒ 画面正立（phosh `rotation-manager.c` 映射 `normal→0°/right-up→270°/bottom-up→180°/left-up→90°`）。

细节与推算 = `reports/sensors-orientation-als-20261128.md` §2；物理确认脚本在该报告 §2.5。
