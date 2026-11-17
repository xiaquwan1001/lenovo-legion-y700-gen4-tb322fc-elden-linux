# B18 闪光灯两缺口备料（2026-11-17，主机侧）

报告：`reports/主机侧-B18-20261117.md`（结论数字表 + 全部门禁命令与输出）。
本目录是 2026-11-13 同目录的**重做版**（13 日两份补丁见 `patches/b18-flash-led-20261113/`，
保留归档；13 日 0001 的 `queueRequestDevice()` 注释与代码不符，本轮已修）。

| 文件 | 树 | 门禁（本轮亲自重跑） |
|---|---|---|
| `0001-libcamera-simple-expose-flash-subdevices-as-camera-controls.patch` | libcamera **v0.7.1**（`/tmp/lc-pristine/libcamera-0.7.1` 纯净基线，`/tmp/libcamera-src` 编译） | 单 TU 编译 `ninja -C build src/libcamera/libcamera.so.0.7.1.p/pipeline_simple_simple.cpp.o` → **rc=0，0 warning**（继承工程 `-Wall -Wextra -Werror -std=c++20`）；`git apply --check` on pristine → rc=0；apply 后与编译树**逐字节一致** |
| `0002-arm64-dts-qcom-sm8750-lenovo-elden-add-flash-LED-NTC.patch` | `build/daily` tip **`4bdf1711b5`**（临时 worktree `/tmp/b18-dtb-wt`，daily 工作树未改） | `git apply --check` rc=0；反向 check rc=0；`CHECK_DTBS=1` 编 dtb → **DTC [C]，rc=0，0 诊断**；DTB 153129 → **153488 B（+359 B）**；`M=drivers/leds modules` **rc=0**（含 `flash/leds-qcom-flash.ko`） |

## 0001 机制（3 处，均在 `src/libcamera/pipeline/simple/simple.cpp`）

1. `SimplePipelineHandler::match()`：把 `MEDIA_ENT_F_FLASH` 子设备纳入实体表并 `open()`（本来只走 sensor→video 链）。
2. `SimpleCameraData::init()`：把子设备 V4L2 控制并进 `controlInfo_`，配自建 `ControlIdMap`
   （0.7.1 没有 `Flash*` 控制 id，这是绕过点；上游形状见报告 §1.4）。
3. `SimplePipelineHandler::queueRequestDevice()`：属于 flash 子设备的请求控制直接 `setControls` 到子设备，
   并从递给 IPA 的控制表里**过滤掉**（不再依赖 IPA 忽略未知 id）。

判据（待上机）：`cam -c1 --list-controls | grep -i flash` 出现 `led_mode/intensity_torch_mode/...`；
`--controls` 设 `led_mode=2` 能点亮（设备控制面清单见报告 §1.4）。
**本 lane 未上机**（设备不在 USB）。

## 0002 与 `patches/0013-flash-led-ntc-thermal.patch` 的关系

`0013` 是 2026-10-19 的**提案文档**（邮件头 + markdown + ` ```diff ` 围栏），
`git apply --check` 对 daily tip **直接失败**（`补丁在第 58 行损坏`，围栏处），不可 apply。
`0002` = 同一设计的**纯补丁 rebase 版**：`flash-ntc-thermal` zone（schema 命名约束）+ `pmk8550_vadc channel@145`。
**未证点**：`0x145`（sid 1 / AMUX2 100k PU）在本板的 ADC 读数，需上机确认（恒 0/越界 ⇒ 改 sid）。

**上游依赖（2026-11-17 复核）**：`0002` 改的是 `sm8750-lenovo-elden.dts` —— 该文件**尚未上游**（板 DTS 系列 11-17 才以 `[PATCH v7]` 单提交发出）。
所以 `0002` 只能对「带板 DTS 的树」apply（B18 用的是 `build/daily` tip `4bdf1711b5`），对 mainline tip `666539eecdf4` 会报「没有那个文件」
（编排者实测 rc=1）⇒ 与 `dwc3 v9 0004` 同类，**等板 DTS 合入后再发**。

## 无缺口部分（不要再写补丁）

见 `patches/0013-flash-led-ntc-thermal.patch` 尾表与 `reports/front-camera-flash-20261019.md`：
`leds_qcom_flash` 绑定/`led-sources`/限流语义/`qcom,camera-flash` 等价性/前摄无闪光灯——全部已定案。
另：`flash-leds = <&rear_flash>`（dts:2322）与 ancillary link 已就绪，内核侧**不需要**新补丁。
