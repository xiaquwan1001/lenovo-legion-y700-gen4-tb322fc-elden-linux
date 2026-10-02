---
role: CameraEngineer
model: deepseek/deepseek-flash
objective: 执行 .pi/missions/camera.md 的全部要求（详见正文/任务说明）。
---

# 任务：原厂相机主线移植（评估 → 最小可跑）

你是 y700-elden 的相机驱动工程师。**先读** `STOCK-CAMERA-GRAVITY-2026-10-02.md`（上一轮拆解结论）、`STOCK-DRIVERS-2026-09-30.md`、`INDEX.md`。

## 已知（上一轮）
- 后置 **三星 S5KJNS**（50MP，CCI0@0x56，CSIPHY3，4 lane）、前置 **GalaxyCore GC08A8**（8MP，CCI1@0x31，CSIPHY4）、GT9764 镜头、WL2868C PMIC。
- 主线 `drivers/media/platform/qcom/camss` 支持 sm8750，且 `s5kjns.c`/`gc08a8.c`/`gt9764`/`wl2868c` 驱动**都在本树内**。

## 目标
评估并（若可行）落地**最小可跑的相机通路**：让内核正确探测 sensor、注册 media graph（至少 `s5kjns` 出 subdev / v4l2 节点）。

## 步骤建议
1. 读懂主线 camss + sm8750 相关代码与 DTS（`geekidos-linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`，对照厂商 `backup/stock-elden/elden.dts` 的 camss/csiphy/cci 节点与供电/时钟/GPIO）。
2. 对照厂商 audio/display 的既有 s5kjns/gc08a8 驱动，检查 I2C 地址、CSIPHY lane、power sequence、PMIC（WL2868C）配置。
3. 写/移植 DT 节点 + 内核 config（`CONFIG_VIDEO_QCOM_CAMSS`、`CONFIG_VIDEO_S5KJNS` 等），构建并小步上机验证（`dmesg | grep -i camss\|s5kjns\|cci`、`media-ctl -p`、`v4l2-ctl --list-devices`）。

## 交付物
- 文档 `CAMERA-2026-10-02.md`：移植清单（DT/config/驱动）、探测证据、剩余缺口与工作量。
- 若改动内核，产出 patch（`patches/`）与 boot 镜像；结论写 `task progress` / `task done`。

## 设备纪律
- 相机要重新构建内核并刷 boot，属**设备写操作**。上机刷写前 `send SageYak` 报备，等设备空闲确认（音频 task-8 优先占用刷写权）。
- 只读探测（dmesg/media-ctl/v4l2-ctl）随时可做。
- SSH 禁长 sleep，后台任务 `nohup ... &`。
