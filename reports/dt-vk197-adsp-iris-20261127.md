# vk197 —— DT 单变量（ADSP fastrpc non-secure + 板级 iris）：传感器解阻 + iris 绑定，解码未通（2026-11-27 晚，父代理上机）

- **性质**：`Image.gz` 与 vk196 **逐字节相同**（`9728a751…`），只换 DTB（153124 → 153136 B，`ce27003e…` → `d3d766d2…`）⇒ 单变量。
- **首见 `fastboot boot`（零写盘）→ 回归 → `scripts/flash-b.sh` 持久化 → 真重启复验**，全程未动 boot_a / 其它分区。
- **产物**：`out/boot-elden-vk197.img`（sha `12eb016a…` 未签 / `6341a981…` 签名后，96 MiB，写 boot_b 读回一致）、`out/boot-elden-vk197.manifest`。账 = `versions/vk-registry.tsv` 的 vk197 行。

## 0. 一页结论

| # | 判据 | 结果 |
|---|---|---|
| 1 | `/dev/fastrpc-adsp` 是否出现（= 传感器栈的前置门） | ✅ **出现**（`crw-rw---- fastrpc`）；旧 DTB 下 **缺** ⇒ 这正是 `elden-sensorspd` 90 s 后 `skipping attach` 的原因 |
| 2 | 传感器是否出真值 | ✅ `ssccli --sensor accelerometer --timeout 6` 连续出值：`X≈-1.23 Y≈0.79 Z≈-9.48 m/s²` |
| 3 | iio-sensor-proxy 三属性 | 🟡 **重启后 true，开机后不 true**：冷启后 `HasAccelerometer=false`（`HasAmbientLight/Proximity=true`），`systemctl restart iio-sensor-proxy` 后三样全 true ⇒ **D16 的「proxy 先于传感器就绪」竞态仍在**（本轮给出现成判据与临时处置） |
| 4 | CoreSight AMBA 绑定（vk195/196 判据回归） | ✅ `amba unbound=0 / 41` |
| 5 | iris 是否绑定并出节点（Q36 的①） | ✅ `aa00000.video-codec` → 驱动 `qcom-iris`，`v4l2-ctl --list-devices`：`Iris Decoder /dev/video17`、`Iris Encoder /dev/video18`，格式 = H264/HEVC/VP90/AV01 |
| 6 | 硬件解码是否真能用（Q36 的②） | ❌ **未通**：`ffmpeg -c:v h264_v4l2m2m` 报 `[h264_v4l2m2m] capture: driver decode error` + `corrupt decoded frame`，输出仅 `frame=1`；H.264 baseline/main/high **三档同现象** |
| 7 | 系统回归 | ✅ DSI `connected`、`wlan0 UP`（114.214.233.60/22 + IPv6）、声卡 1、phoc 1 / phosh 1、电池 `Charging`、dmesg 无 BUG/Oops（grep 命中的 5 条全是 `ramoops` 字样） |

## 1. 改了什么（三处，全部 DT）

| # | 文件 | 改动 | 理由 |
|---|---|---|---|
| 1 | `arch/arm64/boot/dts/qcom/sm8750.dtsi`（ADSP `fastrpc` 节点） | `+ qcom,non-secure-domain;` | 与 CDSP 同构；`fastrpc.c` 只认这个属性才建 `fastrpc-adsp` 字符设备。**等价于上游 M10 v3**（`patches/upstream/sm8750-adsp-nonsecure-20261107/`）的板级镜像 |
| 2 | `arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`（板级） | `+ &iris { status = "okay" };` | 上游 sm8750.dtsi 默认 `disabled`（iris 固件厂商签名，只在有签名固件的板子开） |
| 3 | 同 dtsi（TNOC） | `arm,primecell-periphid = <0x000f0c00>` | vk195 既有改动，本版沿用（`amba unbound` 判据用） |

固件侧**没有新增文件**：`/lib/firmware/qcom/vpu/vpu35_p4.mbn`（2 392 776 B，signed，`vfw-3.5:rel0030`）在 11-27 白天已装（`reports/hwdec-iris-sm8750-feasibility-20261127.md`）。

## 2. 上机过程（可复跑）

```sh
# 1) 只重编 DT（Image.gz 不动）
build-slot take y700-elden:dt-adsp-iris --jobs 4
bash scripts/build-kernel.sh dtbs                              # DTB 153136 B
KDIR=~/y700-elden/build/daily VERSION=vk197 \
  RAMDISK=~/y700-elden/out/ramdisk-vk181-working.cpio.gz bash scripts/build-boot.sh
build-slot drop 204752-672543-y700-elden_dt-adsp-iris

# 2) 零写盘首启
sudo systemctl reboot --reboot-argument=bootloader      # 设备内；~40 s 进 fastboot
fastboot -s HA2EXB0E boot out/boot-elden-vk197.img        # 12 s（Sending 1.9 s + Booting 10.1 s）
# 3) 回归 + 判据（见 §0 表）
# 4) 持久化
bash scripts/flash-b.sh out/boot-elden-vk197.img          # AVB 重签 + boot_b dd + 读回 sha 一致
sudo systemctl reboot                                     # 真重启复验：qbootctl -c = _b、uname 不变、/dev/fastrpc-adsp 在
```

> ⚠ `build-boot.sh` 的默认 ramdisk 候选表里**没有** `out/ramdisk-vk181-working.cpio.gz`，不显式给 `RAMDISK=` 会静默退化成 1.1 MB 的 busybox slim initramfs（首次打包就踩了；该退化不会报错，只在 manifest 里留痕）。

## 3. Q36 的下一步判别（本轮没做，留给下一轮）

三条互斥假设，各有一条 10 分钟判据：

| 假设 | 判据 | 预期 |
|---|---|---|
| A. 只 H.264 包装层问题（ffmpeg v4l2m2m 用法/尺寸协商） | 换 **VP9/HEVC** 片源各一次（`hevc_v4l2m2m` 已存在）；再跑 `v4l2-compliance -d /dev/video17` | A 成立 ⇒ HEVC/VP9 能出帧，或 compliance 指出协商缺陷 |
| B. 固件 HFI 版本与驱动期望不一致 | 读 `iris_hfi_gen2_response.c` 的错误码路径，把 `-debug` 的 HFI 响应码打出来（`dynamic_debug` 已可开 `file drivers/media/platform/qcom/iris/* +p`） | B 成立 ⇒ 响应码是 unsupported/params 类，需要 `vpu35_p4` 的另一份 rel |
| C. 上游驱动对 SM8750 尚不成熟 | 查 lore/patchwork `iris` + `sm8750`（2026-11 后是否有修复系列） | C 成立 ⇒ 按项目原则转「上游能力缺口」立项 |

本轮已排除 / 已确立的事实（供上面三条判断复用）：

- 固件**确实起来了**：驱动状态机打出 `sub_state 0→22→66`（= `LOAD_RESOURCES|DRC_LAST|DRC` → `OUTPUT_PAUSE|DRC`）⇒ HFI 命令通道活着，不是「固件没下载」。
- 不是分辨率/像素格式问题：320x240 与 640x480 同现象。
- 不是 profile 问题：baseline/main/high 三档同现象。
- `qcom_iris` **开机不自动加载**（访问 `/dev/video17` 前必须 `modprobe qcom_iris`）：模块有 `of:N*T*Cqcom,sm8750-irisC*` alias，但 udev 冷插没触发 ⇒ 待查（低优先，先记）。

## 4. 顺带确立的两条设备事实

1. **锁屏 + DPMS Off 会让一切读屏手段变黑**：`wlr-randr --output DSI-1 --on` 回 DPMS，解锁要在**宿主合成器层注入触摸**（仓库现成件 `tools/uinput-touch.c`：`tap X Y` / `swipe X1 Y1 X2 Y2`，默认 1904x3042；注释里写明「phosh 只在最后一次输入是触摸时展开 OSK」）。`adb input tap` 只到 Android 侧，解不了宿主锁屏。
2. **传感器「不起」有两种形态**：`/dev/fastrpc-adsp` 缺 = DTB 门（本轮解决）；设备在、但 proxy 先起 = D16 竞态（本轮仍是 `restart iio-sensor-proxy` 才能三 true）。

## 5. 回滚

- 内核：`bash scripts/flash-b.sh bootslot-b/boot_b-device-20261127-vk192.img`（11-27 存档件，sha `68d3dc46…`）或任一 vk195/196 镜像。
- DT 三处改动都在 `build/daily` 工作树（未提交到内核树远端；`git -C build/daily status` 可见），`git checkout -- arch/arm64/boot/dts/qcom/` 即回滚。

## 6. T25 首轮判别结果（2026-11-27 21:0x，同一 vk197 上机窗口）

| 假设 | 做了什么 | 结果 |
|---|---|---|
| A 包装层/协商 | `hevc_v4l2m2m` 解 HEVC（`libx265` 现编 640x480）；`vp9_v4l2m2m` 试 VP9 | HEVC **同现象**（`capture: driver decode error` + `corrupt decoded frame`）；VP9 的 ffmpeg 包装在本机不存在（`ffmpeg -decoders` 无 `vp9_v4l2m2m`）⇒ A 的证据不支持「只是 H.264 包装问题」 |
| A' 驱动质量面 | `v4l2-compliance -d /dev/video17` | **41 过 / 7 败**：`VIDIOC_(UN)SUBSCRIBE_EVENT` FAIL、`G/S/TRY_FMT` FAIL（`!colorspace`，pix_mp.colorspace 未填）、`REQBUFS` FAIL（`q2.reqbufs != EBUSY`）、缺 `V4L2_CID_MIN_BUFFERS_FOR_CAPTURE` 控制项 ⇒ **主线上游质量缺口**（与解码失败不同层，但可独立成补丁） |
| 编码侧旁证 | `h264_v4l2m2m` 编码（`/dev/video18`） | `Could not open encoder`（-22 EINVAL）⇒ 编码器路径连开启都不过 |
| B 固件 HFI 版本 | 开 `dynamic_debug`（`file …/iris/* +p`）+ `dmesg -C` 后重解 | **开了但没出 HFI 报文**（连 `firmware version:` 的 dev_dbg 都没有 ⇒ 该 dynamic_debug 写法在本模块上没生效，下一轮改用 `echo 'module qcom_iris +p'`） |
| C 上游成熟度 | 未查 | 下一轮 `lore`/`patchwork` 关键词 `iris` + `sm8750`（2026-11 后是否已有修复系列） |

**状态机观察（供 B/C 用）**：一次失败解码的完整序列（dmesg，单实例）= `0→1`（input streaming）→ `1→2`（output streaming）→ **`2→4`（ERROR）** → `4→3` → `3→1` → `1→0`；同时 `sub_state 0→22`（`LOAD_RESOURCES|DRC_LAST|DRC`）→ `66`（`OUTPUT_PAUSE|DRC`）。**没有任何 `dev_err`**（`session error received` / `unsupported content` 都未打）⇒ 错误不是固件显式回错的常规路径，更像「固件发来 DRC/暂停事件后驱动自己判错」。这条要对着 `iris_common.c` / `iris_hfi_gen2_response.c` 的 DRC 路径读，是下一轮 30 分钟能定位的点。

> 结论：**Q36 当前最可能是 B/C（固件代次或驱动对 SM8750 的 DRC 路径）**，不是 A 的 ffmpeg 包装层；`v4l2-compliance` 的 7 条失败可另立「driver quality」小系列（与解码失败解耦）。
