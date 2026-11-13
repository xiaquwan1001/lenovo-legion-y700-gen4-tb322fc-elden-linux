# B18 闪光灯两缺口备料（2026-11-13，主机侧）

## 0001 — libcamera simple pipeline 暴露 flash 子设备（MEDIA_ENT_F_FLASH）

- 树 = libcamera v0.7.1（设备侧自编同版本，`patches/libcamera-20261018/build-on-device.sh`）。
- 门禁：`ninja pipeline_simple_simple.cpp.o ipa_soft_simple.so 的 .o` **rc=0，0 warning**（构建开 `-Werror`）。
  完整 `ninja` 库目标未全编（宿主缺 libevent 等 cam 依赖；改动面只在 simple.cpp，单 TU 编译已覆盖）。
- 机制：把 MEDIA_ENT_F_FLASH 实体绑到相机，V4L2 flash 控制并进 camera ControlInfoMap（自建 idmap），
  `queueRequestDevice()` 里把属于 flash 子设备的 request 控制直接 `setControls` 到子设备、不进 IPA。
- 判据（待上机）：`cam -l` 后 `cam -c1 --list-controls` 出现 `Flash LED Mode/Strobe/Torch Intensity…`；
  App 路径 = libcamerasrc/`cam --controls=...` 设 torch。**未上机**（C-U6）。

## 0002 — flash LED NTC thermal zone（DTS）

- 树 = `build/daily`（现役日常树，pmk8550.dtsi 已含 `pmk8550_vadc`）。
- 门禁：`CHECK_DTBS=y qcom/sm8750-lenovo-elden.dtb` **0 诊断**（注：zone 名受 thermal-zones schema
  `≤10 字符+`-thermal`` 限制，用 `flash-ntc-thermal`，与 stock 的 `flash-led-ntc` 名不同；HAL 的
  `sensor-listener-names` 如需精确名要另配）。
- 未证点（上机归 C-U6）：`0x145`（sid 1 / AMUX2 100k PU）映射在本板 ADC 读数是否合理（~室温）。
- 与 10-19 提案（`patches/0013-flash-led-ntc-thermal.patch`）的关系：同一设计的**可编译版**；
  提案里引用的旧树/旧行号已失效，本补丁按 build/daily 现行 dts 重写，原提案归档保留。

## 无缺口部分（不要再写补丁，照抄 10-19 结论）
见 `patches/0013-flash-led-ntc-thermal.patch` 尾表：leds_qcom_flash 绑定/led-sources/限流语义/
qcom,camera-flash 等价性/前摄无闪光灯——全部已定案。
