# S2 用户态侧调研：Alpine/pmOS 传感器栈 + 重力旋转（2026-10-09）

> 只读调研，未动设备。前置：Alpine 根、内核 QRTR/PDR/QMI 就绪、目标 QRTR svc **400 = sns_client_api_v01**、相关用户态全未装。
> 姊妹篇：`.pi/plans/research-g1-34-slpi-sensors-2026-10-09.md`（内核侧 SLPI 上电）。

## 结论（≤10 行）

1. **Alpine edge/community aarch64 已把大部分轮子备齐**：`qrtr`/`qrtr-libs`、`rmtfs`(+`-openrc`/`-udev`)、`qmi-utils`(含 `qmicli`)+`libqmi`、`libssc 0.4.4`（提供 `cmd:ssccli`+`so:libssc.so.2`）、`iio-sensor-proxy 3.9-r2`（`/etc/init.d/iio-sensor-proxy`、`80-iio-sensor-proxy.rules`、`monitor-sensor`）、**`hexagonrpcd 0.4.0-r3`**（OpenRC 里直接有 **`hexagonrpcd-adsp-sensorspd`**、`10-fastrpc.rules`）。**唯一缺 `pd-mapper`**（Alpine 无，需 pmaports 或自编）。
2. **关键架构修正**：SM8750 一代的 SSC/sensors **PD 挂在 ADSP 上、用 FastRPC 起**（`adsprpcd sensorspd` / `hexagonrpcd-adsp-sensorspd`），udev 匹配 `SUBSYSTEM=="misc", KERNEL=="fastrpc-adsp*"`。**svc 400 只有在 sensors PD 起来之后才会出现**——「只装 qrtr-ns + rmtfs 就能扫到 400」的假设不成立。
3. **registry 不要我们自己生成，也不要解析 JSON**：PD 通过 FastRPC 反向文件通道（HexagonFS）向 AP 要文件；把原厂文件按映射表喂进去即可（`sensors/sns_reg.conf`←`/vendor/etc/sensors/sns_reg_config`，`sensors/config`←`/odm|/vendor/etc/sensors/config`（含 `json.lst`，**整目录**拷），`sensors/registry`←`/mnt/vendor/persist/sensors/registry/registry`）。
4. **同代已有可复制先例**：Xiaomi Pad 8 Pro（**SM8750**，piano，Debian trixie）已跑通 accel/light/proximity/compass 并驱动自动旋转；并给出两条必踩的坑补丁（registry 竞态、开机不旋转）。
5. **顺序是硬约束**：ADSP 上电 → 起 sensors PD → PD 发布完传感器 → 才启 `iio-sensor-proxy`（只查一次；libssc 30 s 拿不到 `registry` 传感器就放弃）。

## 证据（可核对）

- E1 Alpine edge aarch64 包存在性与子包：
  `libssc 0.4.4-r0` provides `cmd:ssccli`/`so:libssc.so.2`，被 `iio-sensor-proxy` 依赖 — https://pkgs.alpinelinux.org/package/edge/community/aarch64/libssc
  `iio-sensor-proxy 3.9-r2`（`-openrc`→`/etc/init.d/iio-sensor-proxy`，`-udev`→`/usr/lib/udev/rules.d/80-iio-sensor-proxy.rules`，`cmd:monitor-sensor`）— https://pkgs.alpinelinux.org/package/edge/community/aarch64/iio-sensor-proxy 、https://pkgs.alpinelinux.org/contents?file=&path=&name=iio-sensor-proxy*&branch=edge&arch=aarch64
  `qrtr 1.2-r1`（子包 qrtr/-dev/-doc/**-libs**，**无 -openrc**）— https://pkgs.alpinelinux.org/packages?name=qrtr*&branch=edge&arch=aarch64
  `rmtfs 1.3-r0`(+`-openrc`/`-udev`/`-doc`) — https://pkgs.alpinelinux.org/packages?name=rmtfs*&branch=edge&arch=aarch64
  `qmicli` = 包 **`qmi-utils`** — https://pkgs.alpinelinux.org/contents?file=qmicli&branch=edge&arch=aarch64
  **`hexagonrpcd 0.4.0-r3`**：`/etc/init.d/hexagonrpcd-adsp-rootpd`、**`/etc/init.d/hexagonrpcd-adsp-sensorspd`**、`/etc/init.d/hexagonrpcd-sdsp`、`/usr/lib/udev/rules.d/10-fastrpc.rules` — https://pkgs.alpinelinux.org/contents?file=&path=&name=hexagonrpcd*&branch=edge&arch=aarch64
  `pd-mapper` 只在 **postmarketOS** 仓（`pd-mapper`+`pd-mapper-openrc`，v0_git20201110-r3）— https://pkgs.postmarketos.org/package/master/postmarketos/aarch64/pd-mapper （Alpine 同名搜索 0 命中，**直接证据**）
- E2 **SM8750 直接先例（决定性）**：`blu-sharky/piano-sensors`（Xiaomi Pad 8 Pro / **SM8750** / Debian trixie arm64）——「SSC 在 ADSP 上；`fastrpc` 驱动暴露 ADSP，`adsprpcd`（Debian `fastrpc-support`）服务 sensors PD，libssc 说 QMI，iio-sensor-proxy 交给桌面」；libssc 0.4.4-2、iio-sensor-proxy 3.9-1 从 unstable 重建 — https://github.com/blu-sharky/piano-sensors
- E3 **registry/JSON 喂法（strace 级直接证据）**：piano PR !1 —— `strace adsprpcd sensorspd`：ADSP 重启后 PD **只**请求 `/vendor/etc/sensors/sns_reg_config` 与 `/odm/etc/sensors/config/json.lst`（全 ENOENT），从不打开 persist registry，iio-sensor-proxy 报 `'registry' sensor unavailable after 30s`；补齐整目录（60 文件，与 odm_a 校验一致）后 `monitor-sensor` 报出 accel/100 lux/proximity/compass。且「整目录拷、不只 `json.lst` 列的 16 个缺失项」— https://github.com/blu-sharky/piano-sensors/pull/1
- E4 **HexagonFS 映射表（权威）**（hexagonrpc 上游 README，根目录默认 `/usr/share/qcom`，约定 `-R /usr/share/qcom/<soc>/<VENDOR>/<device>`）：
  `sensors/config`→`/vendor/etc/sensors/config`；`sensors/registry`→`/mnt/vendor/persist/sensors/registry/registry`；`sensors/sns_reg.conf`→`/vendor/etc/sensors/sns_reg_config`；另有 `dsp`→`/vendor/dsp`、`acdb`、`socinfo`。反向隧道 `apps_std` 负责给 DSP 送文件 — https://github.com/MeowArch-open/MeowArchMobile_hexagonrpc
  同仓标题即说明动机：**「HexagonFS write-path patch so the ADSP sensor PD can regenerate its registry」**⇒ PD 要**写** registry（故须给可写副本，而非只读挂载）。
- E5 **udev/mount-matrix 写法（同代实值）**：`SUBSYSTEM=="misc", KERNEL=="fastrpc-adsp*", ENV{IIO_SENSOR_PROXY_TYPE}+="ssc-accel ssc-proximity", ENV{ACCEL_MOUNT_MATRIX}="0, 1, 0; -1, 0, 0; 0, 0, 1"`（注释：`80-iio-sensor-proxy.rules` 已加 light+compass；该机 x/y 相对面板自然横向是互换的）— https://raw.githubusercontent.com/blu-sharky/piano-sensors/main/piano-sensors/debian/piano-sensors.udev
  对照 axolotl(SDM845, SLPI 代)：`KERNEL=="fastrpc-*"`, `ACCEL_MOUNT_MATRIX="-1, 0, 0; 0, -1, 0; 0, 0, -1"` — https://gitlab.com/postmarketOS/pmaports/-/issues/2451
- E6 **竞态补丁**：`ssc-claim-race.patch`（iio-sensor-proxy 3.9）——SSC 后端开传感器时跑嵌套主循环，其间 g-s-d 的 claim 被记录但**不切轮询** ⇒ 方向一直 `undefined`、亮度 0；补丁在每个 driver open 后对已有 client 的类型补开 `driver_set_polling(TRUE)` — https://raw.githubusercontent.com/blu-sharky/piano-sensors/main/patches/iio-sensor-proxy/ssc-claim-race.patch
- E7 **服务顺序**：`adsprpcd-sensorspd.service`：`After=` ADSP 服务、`Before=iio-sensor-proxy.service`、`modprobe fastrpc` + 等 `/dev/fastrpc-adsp-secure`、`ExecStart=/usr/sbin/adsprpcd sensorspd`、`ExecStartPost=…-wait`（「PD 发布完才起 proxy，proxy 只查一次」）；iio-sensor-proxy drop-in `Wants/After=adsprpcd-sensorspd`（注释：libssc 30 s 等不到 registry 就放弃）— https://raw.githubusercontent.com/blu-sharky/piano-sensors/main/piano-sensors/debian/piano-sensors.adsprpcd-sensorspd.service 、…/iio-sensor-proxy-piano.conf
  上游 hexagonrpcd 服务用 `ConditionPathExists=/dev/fastrpc-adsp` 守卫（ADSP 探测后才创建该节点，实测 t≈77 s）— https://github.com/utsugi-pmos/utsugi-pmaports/pull/1
- E8 **SDM845/SLPI 老一代已量产化**（pmaports !5099 已合并，beryllium/OP6/axolotl/odin 用 hexagonrpcd 新路径 + firmware 包内传感器文件 + mount matrix）；Dylan Van Assche 实测 POCOPHONE F1：light/prox/accel/compass 全可用，**「第一次开机 Phosh 未自动开启自动旋转，第二次重启才好」** — https://gitlab.com/postmarketOS/pmaports/-/merge_requests/5099
- E9 libssc 自身：依赖 `libqmi>=1.33.4`/glib/protobuf-c，经 `AF_QIPCRTR`；**hypervisor 禁止 AP 直连传感器**；支持 `light/proximity/magn/accel/rotv` — https://libssc.dylanvanassche.be/docs/ 、https://codeberg.org/DylanVanAssche/libssc/raw/branch/main/README.md
- E10 主线内核自带 QRTR 名称服务，**不需要用户态 qrtr 守护**（「Mainline devices do not need the userspace qrtr daemon as it has been integrated into the kernel」）— https://gitlab.com/postmarketOS/pmaports/-/merge_requests/1806
- E11 X1E 上开发者仍在用 i2c bit-bang 凑 accel，并明确「等 SSC 支持落地就换掉，bit-bang 会**抢 ADSP 的 GPIO、破坏 SSC 初始化**」⇒ 反证：现代高通平台正解是 hexagonrpcd/libssc，不是 AP 直驱 — https://ratatoskr.run/linux-arm-msm/2026-03-3491214/t

## 候选路线（代价 × 把握）

| 序 | 路线 | 代价 | 把握 | 说明 |
|---|---|---|---|---|
| R1 | **FastRPC sensors-PD 路线**：ADSP 起 → `hexagonrpcd-adsp-sensorspd`（或自 build `adsprpcd sensorspd`）+ HexagonFS 喂原厂 config/registry + `libssc` + `iio-sensor-proxy` | 中（要造 `/usr/share/qcom/...` 目录、udev、OpenRC 依赖序、proxy 补丁） | **中高** | 与 SM8750 同 SoC 的 piano 已跑通；Alpine 侧包基本齐；**推荐主攻** |
| R2 | **纯 QRTR 路线**：只 `qrtr-ns/rmtfs/pd-mapper`，指望 SLPI 独立上电后 svc 400 出现 | 低（1 小时取证） | **低-中** | 与 S1 报告同一卡点（SM8550+ SLPI PAS 缺失）；作为**分水岭探针**仍值得先做 |
| R3 | hexagonrpcd 的 **SLPI/SDM845 形态**（老映射，非 ADSP PD） | 中 | 低 | 老架构路径，SM8750 上 E3/E4 已给出新路径；仅在 R1 失败时回看 |
| R4 | **桌面侧伪传感器**（uinput/iio 软 accel + 我们现成 `eldroid-sensord` 值源 + `IIO_SENSOR_PROXY_TYPE=iio-buffer-accel`） | 低 | 高（能「会旋转」） | 不是真 SSC，标定/功耗/接近光全缺；仅作解锁 G2 体验的兜底 |
| R5 | 维持现状（`TASKS §6①` 不做 SLPI/QMI-SNS） | 0 | — | 若不追求 Linux 原生传感器 |

## 落地步骤（从零到 `monitor-sensor` 出数）

**包清单（Alpine edge）**
```
apk add qrtr qrtr-libs libqmi qmi-utils rmtfs rmtfs-openrc rmtfs-udev \
        hexagonrpcd hexagonrpcd-openrc hexagonrpcd-udev \
        libssc iio-sensor-proxy iio-sensor-proxy-openrc iio-sensor-proxy-udev \
        e2fsprogs-libs erofs-utils dmsetup strace
```
（`pd-mapper` 无包：从 https://github.com/andersson/pd-mapper / pmaports `device/*/pd-mapper` APKBUILD 自编；R1 下非必需，见 E1/E10。）

1. **先取证（R2，10 分钟，不改任何东西）**：内核树起 ADSP/SLPI 后 `qrtr-lookup | grep -E '^ *400 '`；空 ⇒ 说明 PD/SLPI 未上电，转 R1。
2. **提取原厂三件套**（stock 只读提取，禁写）：`/odm/etc/sensors/config/`（含 `json.lst`，**整目录**，E3）、`/vendor/etc/sensors/sns_reg_config`、`/mnt/vendor/persist/sensors/registry/registry`（可写副本，E4）。
3. **建 HexagonFS 根**：`/usr/share/qcom/<soc>/LENOVO/TB322FC/` 下 `sensors/{config,sns_reg.conf,registry}` 按 E4 映射摆放；`dsp/` 放 ADSP/SSC 侧需要的 `.so`/`.pd`（若原厂用 `/vendor/dsp`）。hexagonrpcd 传 `-R /usr/share/qcom/sm8750/LENOVO/TB322FC`。
4. **起 PD**：`rc-update add hexagonrpcd-adsp-sensorspd`；在其 OpenRC 脚本里加依赖：ADSP 已上电 + `Condition`-等价的 `[ -e /dev/fastrpc-adsp ]` 轮询（E7）；若 Alpine 0.4.0 的 sensorspd 不适配 SM8750，退到自 build 高通 `fastrpc` 用户态并照抄 `adsprpcd sensorspd` 语义（E2/E7）。
5. **udev**：写 `/etc/udev/rules.d/81-libssc-elden.rules`（模板 E5），先**只**打 `ENV{IIO_SENSOR_PROXY_TYPE}+="ssc-accel ssc-proximity"`，矩阵暂填单位阵。
6. **起 proxy**：`rc-update add iio-sensor-proxy`，顺序在 4 之后（E6/E7：proxy 只查一次）；顺手 backport `ssc-claim-race.patch`。
7. **验收链**：`ssccli --sensor accel`（裸数）→ `monitor-sensor`（D-Bus）→ 桌面旋转。
8. **标定 mount matrix（经验法，勿抄别人值）**：`ssccli --sensor accel` 记 4 个姿态（屏朝上平放、竖屏顶边朝上、顶边朝左、顶边朝右），要求 iio-sensor-proxy 输出 `normal / left-up / right-up / bottom-up / flat` 与实姿一致；由此解 3×3（每行是设备轴在传感器轴上的符号）。Y700 四代是**横向自然姿**的平板，预期形如 piano 的 x/y 互换矩阵（**推断，需实测定值**）。
9. **桌面侧**：Phosh/gnome-settings-daemon claim accel（g-s-d 负责方向）；亮度联动需 g-s-d power 插件读 `AmbientLight`；注意 pmOS 已知现象「首次开机 Phosh 不开自动旋转、二次重启才好」（E8）——排障时别误判为驱动坏了。

## 风险与未证实点

- **未证实**：Alpine `hexagonrpcd 0.4.0-r3` 的 `-adsp-sensorspd` 是否已覆盖 SM8750/SM8750P（其上游 SDM845/SDM670 出身；piano 作者用的是 Debian `fastrpc-support`/`adsprpcd` 而非 hexagonrpcd，原因未说明）。
- **未证实**：SM8750P 上 SSC/sensors PD 的确切镜像名与加载方式（`sensors.pd` vs SLPI 独立上电）；与 S1 报告「SM8550+ 无 `*-slpi-pas`」需合读——两条路（FastRPC PD vs SLPI PAS）谁真起效仍未定。
- **未证实**：Alpine `80-iio-sensor-proxy.rules` 是否已含 `fastrpc` 的 light/compass 条目（piano 注释如此说，本次取 Alpine 源文件 404/被反爬挡住）。
- **未证实**：iio-sensor-proxy 3.9 的传感器/设备**白名单配置**是否需要在 Alpine 上额外放行 SSC（piano 的 drop-in 只处理 systemd 顺序，Alpine 用 OpenRC 需自己实现同等顺序）。
- **矛盾记录**：S1/G1-34 报告按「QRTR svc 400 + SLPI」叙述；本次 E2/E3/E4 显示同代实际走 **ADSP FastRPC PD**。二者不是互斥而是**两代/两条上电路径**，本次不推翻 S1 的内核结论，但把用户态首选路径改到 R1。
- 副作用风险：抢 ADSP GPIO 会破坏 SSC（E11）；ADSP 崩溃会连带拖死 PD/传感器与依赖它的 I/O（utsugi 案例）。

## 需父进程在设备上验证的项

1. `ls -l /odm/etc/sensors/config/ /vendor/etc/sensors/ /mnt/vendor/persist/sensors/registry/`（stock 侧，只读）——确认 TB322FC 是否有 `json.lst`+`sns_reg_config`+persist registry；这是 R1 的**唯一硬前置**。
2. JSON 文件名判器件（`lsm6dso*` vs `icm4x6xx*`）并记录 `json.lst` 条目数（piano：odm 缺 16 项，故须整目录拷）。
3. 内核侧：`ls /dev/fastrpc-adsp*`、`modprobe fastrpc` 后节点是否出现、ADSP 是否已由我们的栈上电。
4. `qrtr-lookup | grep 400` 前后对照（起 PD 前/后），把 R2 分水岭钉死。
5. Alpine 上 `apk add hexagonrpcd-openrc` 后 `cat /etc/init.d/hexagonrpcd-adsp-sensorspd` 与其期望的 `-R` 路径/配置项；确认能否直接复用。
6. `cat /usr/lib/udev/rules.d/80-iio-sensor-proxy.rules` 是否已含 fastrpc 条目（决定第 5 步要不要自己加 light/compass）。
7. 拿到 accel 裸数据后回传 4 姿态读数，由我这边解 `ACCEL_MOUNT_MATRIX`。
