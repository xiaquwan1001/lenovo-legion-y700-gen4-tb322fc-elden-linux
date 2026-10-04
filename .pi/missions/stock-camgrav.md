# 任务（已收官，墓碑）：原厂相机 + 重力计拆解

**本任务书不再执行。** 两模块的器件识别与移植评估已完成，全文：`archive/topics/STOCK-CAMERA-GRAVITY-2026-10-02.md`（配套 `STOCK-DRIVERS-2026-09-30.md`、`STOCK-KERNEL-2026-09-30.md`）。

- 相机 → 后续工作（出流）：`.pi/missions/camera.md`（TASKS G1-5）。
- 传感器/重力计 → 已演化为 C4 传感器注入链（UDP HAL + `scripts/deploy-sensors-hal.sh` + `scripts/build-sensord.sh`），待上机部署验证：`TASKS.md` §2 C4、`archive/topics/SENSORS-WAYDROID-STUB-2026-10-03.md`。
