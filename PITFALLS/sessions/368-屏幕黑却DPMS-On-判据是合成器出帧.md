# #735 屏幕「黑」不等于面板熄/DPMS 关：判据是合成器能不能出帧，唤醒靠注入输入事件

**现场（2026-11-26 19:0xZ）**：`adb exec-out screencap` 全黑、宿主 `grim` 报 `failed to copy output DSI-1`，
cell 正常、`dmesg` 无 DPU/DSI 报错，而 **`/sys/class/drm/card0-DSI-1/dpms = On`、`status = connected`、
`/sys/class/backlight/*/bl_power = 0`（= 开）** ⇒ 三条 sysfs 判据全部指向「屏是亮的」，与现场相反。

**真因**：phoc（合成器）在 idle 时把输出停帧，**不改 DRM DPMS 与背光**。所以「屏亮不亮」的可用判据只有一条：
**合成器能不能出帧** —— `grim /tmp/x.png` 成功且 PNG > 60 KB（本机亮屏 130–180 KB、全黑 < 40 KB）；
`adb screencap` 只能证明 **Android 侧**在出帧，不能证明面板被点亮（本次实测黑屏时 screencap=140 KB 仍「成功」）。

**唤醒**：给 phoc 一个真实输入事件即可 —— `ydotoold` 常驻、`ydotool mousemove -- 500 500` 之后 `grim` 立刻恢复（实测 178 KB）。

**已固化**：`scripts/wake-screen.sh`（`--check` 只读体检 / 默认唤醒 / `--selftest` 判据自证）
+ 设备侧 `/usr/local/bin/elden-wake` + `elden-wake.path` + `elden-wake.service`（enabled）⇒
`ssh elden 'elden-wake'` 或 `ssh elden-root 'touch /run/elden-wake.trigger'` 都能亮屏。

**两个连带坑**：① path unit 若不在服务里删触发文件（`ExecStartPost=-/bin/rm -f /run/elden-wake.trigger`）会
`Start request repeated too quickly` → `unit-start-limit-hit`；② 判据别用 `grim` 的 rc 单独判 —— 全黑图也可能写出成功，
要带体积门槛。
