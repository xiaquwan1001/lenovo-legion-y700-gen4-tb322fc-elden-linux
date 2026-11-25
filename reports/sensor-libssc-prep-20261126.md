# 传感器用户态备料：libssc + iio-sensor-proxy(SSC) arm64 包（lane L · 主机侧，零设备）

> 日期：2026-11-26 06:28–06:40 CST（主机）
> 边界：**本轮零设备动作**（未 ssh、未碰 `192.168.7.1`）。仓内唯一写入 = 本文件；无 git commit。
> 上游背景取自 `reports/sensor-claim-verify-20261126.md`（判据：缺口全在用户态，trixie 无 `libssc2`/`libssc-bin`，Debian `iio-sensor-proxy 3.7-3` 不带 SSC）。
> 构建目录（全在仓外）：`/tmp/ssc-prep/`。并发纪律：`pi-load --brief` 先看（当时 SATURATED，建议 -j1），
> `build-slot take y700-elden:libssc-prep --jobs 4`（id `063010-472556-y700-elden_libssc-prep`），全部构建命令套 `timeout -k`，收尾 `build-slot drop`。

---

## §1 结论

**能，而且比预期容易：本机成功交叉构建出 arm64 的 `libssc 0.4.4` 与 `ssc-enabled` 的 `iio-sensor-proxy 3.9`（含 `libssc.so.2` 依赖、4 个 ssc 驱动、可执行）。**
**但更短的路径已经出现：Debian testing/unstable 现在有官方 SSC 版包，二进制在 trixie 上 ABI 兼容，可以不构建直接装。**

| 路线 | 内容 | 判定 | 依据 |
|---|---|---|---|
| **A（推荐，零构建）** | 从 Debian testing/unstable 取 3 个 arm64 包直装：`libssc2 0.4.4-2.1` + `libssc-bin 0.4.4-2.1` + `iio-sensor-proxy 3.9-1` | **可行**（主机侧已全量核验 ABI/依赖，未上机） | 官方 3.9-1 `NEEDED libssc.so.2`、含 `ssc-accel/compass/light/proximity` 串；`Depends: libc6 (>= 2.38)`，trixie libc6 = **2.41**；libssc2 只要求 `libc6 >= 2.17`、`libglib2.0-0t64 >= 2.80`（trixie 2.84.4）、`libqmi-glib5 >= 1.34`（trixie 1.36.0） |
| **B（本文实测成功，作兜底/需打补丁时用）** | 源码交叉构建：libssc `v0.4.4` + iio-sensor-proxy `3.9`，`-Dssc-support=enabled`，产出 4 个本地 `.deb` | **PASS** | §3，退出码 0，两轮编译无 warning 阻塞；产物在 `/tmp/ssc-prep/out/` |
| C（原设想） | 用 trixie 自己的包 | **不成立** | trixie(deb13) 只有 `iio-sensor-proxy 3.7-3`（无 `ssc-support` 选项，`meson_options.txt` grep = 0）且**无 libssc 任何包**（`madison`：libssc 仅 testing/unstable） |

**卡点（都已在本轮绕开，是下一轮的上机前置）**：
1. **udev 属性仍是真缺口，且 3.9 官方规则也没修**：`80-iio-sensor-proxy.rules` 在 3.9（上游与 Debian 3.9-1 **都**）只打 `ssc-light ssc-compass`，
   `drv-ssc-accel.c:36` 仍 `drv_check_udev_sensor_type(device,"ssc-accel",NULL)`；上游 NEWS 3.9 明说加速计「experimental, enabled through udev rules」
   ⇒ 仓内 `81-libssc-elden.rules`（`ssc-accel` + `ACCEL_MOUNT_MATRIX`）**必须一起上机**（与 `PITFALLS #451` 一致，非库版本问题）。
2. 跨套件装包需 pin/hold，否则下次 `apt upgrade` 会回滚到 3.7-3（见 §5）。
3. 构建细节坑（路线 B 才遇到，已解决）：`protoc-gen-c` 不在本机、arm64 sysroot 需 `udev.pc`（来自 `systemd-dev`）、libssc 要 `--libdir=lib/aarch64-linux-gnu` 否则 `.pc` 落在 `/usr/lib/pkgconfig` 找不到。

---

## §2 上游现状表（URL + 查证日期 2026-11-26）

| 项 | 事实 | 来源 |
|---|---|---|
| **libssc 项目地址已迁移** | `gitlab.freedesktop.org/mobile-linux/libssc` = **404 Project Not Found**；现行上游 = **Codeberg** `https://codeberg.org/DylanVanAssche/libssc`（文档站 <https://libssc.dylanvanassche.be/docs/> 同此口径） | GitLab API(404) + 文档站 |
| libssc 最新 tag | **v0.4.4**，commit `0cf77b93b55752da34dca2dcecc06fca8665184b`，tag 日期 **2026-06-27** | `git ls-remote --tags` + `git log` |
| libssc 构建依赖 | meson **>= 1.4.0**；`glib-2.0 >= 2.56`、`gio-unix-2.0`、`gobject-2.0`、**`qmi-glib >= 1.33.4`**、`libprotobuf-c`、`m`；`protoc` + `protoc-gen-c`（protobuf-c）为主机工具；`gobject-introspection` **可选**（`required: false`） | `libssc/meson.build` L68–84、`src/meson.build` L95 |
| libssc SONAME / 包名 | `libssc.so.2`（soversion 2）⇒ Debian 侧对应 `libssc2`；`ssccli` 在 `libssc-bin`（呼应 `PITFALLS #433`） | 交叉产物 `objdump -p` |
| iio-sensor-proxy 上游 | `https://gitlab.freedesktop.org/hadess/iio-sensor-proxy`，默认分支 `master`（last activity **2026-11-13**）；最新 tag **3.9（2026-03-02）** | GitLab API |
| SSC 构建选项名 | **`ssc-support`**（`type: feature`，默认 `auto`）⇒ 启用写 **`-Dssc-support=enabled`**；上游 README 里没有 `-Dssc=true` 这种写法 | `meson_options.txt@3.9` |
| SSC 最低版本 | **3.9**（`3.8`/`3.7` 的 `meson_options.txt` 无 `ssc` 条目，grep=0） | API 取 3.8/3.7 options |
| iio-sensor-proxy 对 libssc 的版本要求 | `dependency('libssc', version: '>=0.2.1', required: get_option('ssc-support'))` | `meson.build@3.9` L49 |
| 沙箱注意 | 3.9 的 unit 自带 `RestrictAddressFamilies=… AF_QIPCRTR`（**不需要**像 `hexagonrpcd` 那样加放开 `AF_QIPCRTR` 的 drop-in） | `data/iio-sensor-proxy.service` |
| Debian：iio-sensor-proxy | stable(trixie)=**3.7-3**；testing(forky)/unstable=**3.9-1**（arm64 有，且**编了 SSC**：`NEEDED libssc.so.2` + `ssc-*` 串） | `api.ftp-master.debian.org/madison` + 拉包实测 |
| Debian：libssc | **trixie 无**；testing/unstable = **`libssc 0.4.4-2.1`**，二进制包 `libssc2` / `libssc-bin` / `libssc-dev`（arm64 有） | `madison` + pool 拉包实测 |
| 官方包 ABI 可行性 | `iio-sensor-proxy 3.9-1` 符号最高 `GLIBC_2.38`；`libssc.so.2（0.4.4-2.1）` 最高 `GLIBC_2.17`；trixie libc6 = **2.41-12+deb13u5** | `objdump -T` + sysroot 内 libc6 版本 |

---

## §3 实测构建（路线 B）：命令与输出

### 3.1 环境
- 主机：`meson 1.10.1` / `ninja 1.13.2` / `aarch64-linux-gnu-gcc 15.2.0`（Ubuntu 交叉工具链；`~/toolchains/aarch64-linux-musl-cross` 不适用，未使用）。
- 目标 sysroot：**Debian trixie arm64**，由 `/tmp/ssc-prep/mk-sysroot.sh` 无根生成
  （照 `packaging/debian/cross-arm64.sh` 的思路：私有 apt sources + 私有 `Dir::State`/空 status ⇒ 不改宿主 apt/dpkg 数据库；`--download-only` 让 apt 自己解依赖，101 个 .deb / 207 MB）。
  关键版本：`libqmi-glib 1.36.0`、`glib 2.84.4`、`libprotobuf-c 1.5.1`、`libc6 2.41-12+deb13u5`、`systemd/libudev 257.13`。
- 主机工具补齐（**无 root**）：`protobuf-c-compiler 1.5.1-1ubuntu2` 的 `.deb` 提到 `/tmp/ssc-prep/hosttools/root`，仅加 `PATH`。
- 交叉文件 `/tmp/ssc-prep/cross-aarch64-trixie.ini`（`[binaries] c/ar/strip`, `[host_machine] cpu_family=aarch64`, `[properties] sys_root + pkg_config_libdir=…/usr/lib/aarch64-linux-gnu/pkgconfig:…/usr/share/pkgconfig`）。

### 3.2 libssc 0.4.4（PASS）
```
timeout -k 10 300 meson setup libssc/_cross libssc \
  --cross-file cross-aarch64-trixie.ini --prefix=/usr --buildtype=release
timeout -k 10 600 build-slot run y700-elden:libssc-prep --jobs 4 -- \
  meson compile -C libssc/_cross -j 4            # [117/117] Linking target tests/tests-no-service，EXIT=0
timeout -k 10 240 meson configure libssc/_cross --libdir=lib/aarch64-linux-gnu
timeout -k 10 400 build-slot run y700-elden:libssc-prep --jobs 4 -- \
  meson install -C libssc/_cross --destdir /tmp/ssc-prep/stage-libssc2
```
- 依赖探测实况：`libprotobuf-c YES 1.5.1` / `qmi-glib YES 1.36.0` / `gio,gobject 2.84.4` / `gobject-introspection NO`（可选，缺省跳过 GIR，正合交叉场景）。
- 产物：`libssc.so.2`（171 272 B，`NEEDED: glib/gio/gobject/qmi-glib.so.5/qrtr-glib.so.0/protobuf-c.so.1`）、`ssccli`、headers、`libssc.pc`（`Version: 0.4.4`、`Requires: glib-2.0, gobject-2.0, gio-2.0, qmi-glib`）。
- **动态链接烟测（qemu-aarch64 + trixie sysroot，本机 binfmt 已有 qemu-aarch64）**：
  `qemu-aarch64 -L sysroot-work/sysroot stage-libssc2/usr/bin/ssccli --help` → 正常打印用法；
  `ssccli --sensor accelerometer --timeout 2` → **`Unable to initialize accelerometer sensor: SSC QMI Service not found`**（主机无 QRTR SSC 服务，属预期；关键是**优雅报错不崩**）。

### 3.3 iio-sensor-proxy 3.9 + SSC（PASS）
```
git clone --depth 1 -b 3.9 https://gitlab.freedesktop.org/hadess/iio-sensor-proxy.git   # 0085ddf8
meson setup iio-sensor-proxy/_cross iio-sensor-proxy --cross-file cross-aarch64-trixie.ini \
  --prefix=/usr --libdir=lib/aarch64-linux-gnu --buildtype=release -Dssc-support=enabled
meson compile -C iio-sensor-proxy/_cross -j 4     # [39/39] Linking target src/monitor-sensor，EXIT=0
meson install -C iio-sensor-proxy/_cross --destdir /tmp/ssc-prep/stage-iio
```
- 实况：`ssc-support: enabled`；编译进 `drv-ssc-{accel,compass,light,proximity}.c`；末行 `Linking target src/iio-sensor-proxy`。
- `objdump -p /usr/libexec/iio-sensor-proxy` → `NEEDED … libssc.so.2`（本地产物 sha256 `4b527201…db8faa`）；`strings` 命中 `ssc-accel/ssc-compass/ssc-light/ssc-proximity`，`ssc_` 前缀符号 44 个。
- qemu 烟测：`iio-sensor-proxy --help` / `monitor-sensor --help` 均正常。
- 踩坑与修法（可在下一轮复现时省时）：①`protoc-gen-c` 缺失 ⇒ 取 `protobuf-c-compiler` 静态提取；②`Run-time dependency udev found: NO` ⇒ trixie 的 `udev.pc` 在 **`systemd-dev`** 包里（装在 `/usr/share/pkgconfig/udev.pc`），补进 sysroot 才过；③libssc 默认 `libdir=lib` ⇒ `.pc` 落在 `/usr/lib/pkgconfig`，须 `--libdir=lib/aarch64-linux-gnu` 才能被 iio-sensor-proxy 的 pkg-config 找到。

### 3.4 产物（全部留在**仓外** `/tmp/ssc-prep/`，sha256 实测）

本地构建（路线 B，`Architecture: arm64`，`dpkg-deb --root-owner-group` 组装，无 debhelper）：

| 文件 | 大小 | sha256 |
|---|---|---|
| `/tmp/ssc-prep/out/libssc2_0.4.4-1_arm64.deb` | 30 476 | `fdea6df0f15106e81651d0782ea3b0a949dc4fe9cf09da0b75812ea40a99a692` |
| `/tmp/ssc-prep/out/libssc-bin_0.4.4-1_arm64.deb` | 14 594 | `c0396e135e3841ad0fc906df5627de143f3310b0d6df1b2b0309aa24157a789f` |
| `/tmp/ssc-prep/out/libssc-dev_0.4.4-1_arm64.deb` | 7 774 | `bbcd9b9761c269a9c7facdcc8f739687a1736768b01839ba4e90a5b6fbbd065a` |
| `/tmp/ssc-prep/out/iio-sensor-proxy_3.9-1elden_arm64.deb` | 43 576 | `24465ca1dbdd691db8adb9fa0b002ddb6afd25c20338b9b696f33d42a54ebc6f` |
| `…/stage-libssc2/usr/lib/aarch64-linux-gnu/libssc.so.2` | 171 272 | `d6be0ecedc8d76678a165769989e75810f6d9323ff7bba824810135e6bdcdc32` |
| `…/stage-libssc2/usr/bin/ssccli` | — | `bbd60117868dd98fea8a0cfe9f3b49e5ab54fe41bd921021d3e26e8b1e2fafab` |
| `…/stage-iio/usr/libexec/iio-sensor-proxy` | — | `4b52720126c5a78d8c317333d5fce6d10d3aa8664814465820b291e1e6db8faa` |

官方包（路线 A，从 `deb.debian.org` testing pool 拉取，未装未改）：

| 文件 | 大小 | sha256 |
|---|---|---|
| `/tmp/ssc-prep/debian-official/iio-3.9.deb`（= `iio-sensor-proxy_3.9-1_arm64.deb`） | 36 952 | `a72d111ca58c22dd7f2b71ed20001425fc180a5581df8c07c0420aaaeba61415` |
| `/tmp/ssc-prep/debian-official/libssc2_0.4.4-2.1_arm64.deb` | 37 720 | `a05d3fb33323183b847e9264f57485b278fbc42f9854119edfdcd20db1b589d0` |
| `/tmp/ssc-prep/debian-official/libssc-bin_0.4.4-2.1_arm64.deb` | 25 192 | `b1c2b9c0a3232f2b79b0fb7fbf517283c5c36d5662bb95974752ea4b82f592a8` |

复现脚本（仓外，可原样重跑）：`/tmp/ssc-prep/mk-sysroot.sh`、`/tmp/ssc-prep/cross-aarch64-trixie.ini`、`/tmp/ssc-prep/mk-debs.sh`。
**仓内无任何二进制/源码落盘**（`git status` 本 lane 只多本报告）。

---

## §4 下一轮最小验证步骤（设备侧；本轮未执行）

### 4.1 前置只读门禁（约 1 分钟，零风险）
```
ssh root@192.168.7.1 'dpkg -l libqmi-glib5 libqrtr-glib0 libprotobuf-c1 libglib2.0-0t64 libgudev-1.0-0 libpolkit-gobject-1-0 | tail -n +6
                       qrtr-lookup | grep -E "^ *400"
                       ls -l /dev/fastrpc-adsp; udevadm info -q property /dev/fastrpc-adsp | grep -E "IIO_SENSOR_PROXY_TYPE|ACCEL_MOUNT_MATRIX"
                       dpkg -l iio-sensor-proxy | tail -1'
```
判据：依赖 6 包均 ≥ 上表门槛（`libqmi-glib5` 需 ≥1.34）；`svc 400` 在册；`/dev/fastrpc-adsp` owner 已 `fastrpc:fastrpc`（`PITFALLS #692` 前置坑已消失）；规则属性**预期仍缺**（=待装 `81-libssc-elden.rules`）。

### 4.2 风险闸门（**必须先做，且属 #692 同类风险边界**）
任何“真正发 QMI/SSC 请求”的动作（`ssccli …`、重启后的 proxy 自动 poll）之前：
1. `nohup dmesg -w > /var/log/dmesg-ssc-attach.log &`（或物理串口）—— #692 现场特征是**无 Oops、journal 直接截断**，事后无从取证；
2. `scripts/device-lock.sh` 取锁；记录 `uptime`/`journalctl --list-boots` 以便区分新 boot；
3. **确认不启 `hexagonrpcd`**（本轮路线全程不需要它：libssc 走 `AF_QIPCRTR` socket，不 open `/dev/fastrpc-adsp`）。
   ⇒ **会触发 #692 的动作 = `systemctl start hexagonrpcd` / `hexagonrpcd-adsp-sensorspd`；不启它就不在已知崩溃面上**。
   剩余未知风险：向 ADSP SSC 服务首次发 QMI 时 DSP 侧 sns 唤醒 PD —— 与 hexagonrpcd attach 同一条唤醒链，**不能排除**，故 4.2 步骤不可省。

### 4.3 最小安装 + 判据（建议先 `ssccli`，再 proxy）
```
# ① 只装库 + CLI（不碰 proxy），验 SSC 通道
dpkg -i libssc2_0.4.4-2.1_arm64.deb libssc-bin_0.4.4-2.1_arm64.deb
ssccli --sensor accelerometer --timeout 5      # 期望：三轴数值滚动；失败信息形如 "SSC QMI Service not found"
# ② 换 SSC 版 proxy（3.9 会覆盖 3.7-3）
dpkg -i iio-sensor-proxy_3.9-1_arm64.deb
install -m644 81-libssc-elden.rules /etc/udev/rules.d/   # 源：仓内 packaging/elden-userland/files/etc/udev/rules.d/81-libssc-elden.rules
udevadm control --reload && udevadm trigger --subsystem-match=misc
udevadm info -q property /dev/fastrpc-adsp | grep -E "IIO_SENSOR_PROXY_TYPE|ACCEL_MOUNT_MATRIX"   # 必须含 ssc-accel
systemctl restart iio-sensor-proxy; monitor-sensor --accel
busctl introspect net.hadess.SensorProxy /net/hadess/SensorProxy | grep -E "HasAccelerometer|AccelerometerOrientation"
```
判据（沿用 `PITFALLS #451` 三真口径）：`HasAccelerometer=true` + `monitor-sensor` 有 accel 数值 + `AccelerometerTilt` 会变；
**`AccelerometerOrientation` 常态 undefined，不可用作判据**。

### 4.4 失败分诊
| 现象 | 指向 |
|---|---|
| `ssccli` 报 `SSC QMI Service not found` | QRTR 服务面（ADSP sns 未注册/PD 未起），回 `reports/sensor-claim-verify-20261126.md` §2.2，不是库问题 |
| `ssccli` 出数但 proxy 无 accel | udev 属性（3.9 官方规则仍缺 `ssc-accel`） |
| proxy 起来但 discover 只到 rotv/ambient_light | `PITFALLS #114/#451` 同名症状；注意 `PITFALLS #107` 记录过 libssc 0.4.3 vs 0.4.4 的 discover 差异（本轮包是 0.4.4，若真复现则换 0.4.3 交叉验证） |
| 整机掉电/自回 Linux | #692 类；停手，取 `dmesg-ssc-attach.log` + 串口 |

---

## §5 需用户/父代理放行项

1. **设备写入放行（一次批量）**：`dpkg -i` 3 个包（跨 suite 混装）+ 落 `81-libssc-elden.rules` + `udevadm trigger` + `systemctl restart iio-sensor-proxy`。
   需先按 `.pi/AGENT-OPS.md` 备份：`dpkg -l > /backup/…`、`cp -a /var/lib/dpkg/status`、记录 `iio-sensor-proxy 3.7-3` 以便回滚（`apt install iio-sensor-proxy=3.7-3`）。
2. **路线选择（A 还是 B）**：A = Debian testing 官方 3.9-1 + libssc2 0.4.4-2.1（**推荐**：签名来源、无自建包、ABI 已核；代价 = 从 sid 取包）；
   B = 本地构建的 4 个 `.deb`（代价 = 无签名、`3.9-1elden` 版本自持；优点 = 想改源码（如把 `ssc-accel` 打进发行版规则）时可控）。
3. **apt 覆盖防护**（写盘动作）：`apt-mark hold iio-sensor-proxy libssc2 libssc-bin`，或加 `/etc/apt/preferences.d/` pin（否则 `apt upgrade` 会把 proxy 拉回 3.7-3 = SSC 静默消失）。
4. **#692 取证通道**：跑 §4.2 之前必须有一条可用取证通道（物理串口优先；退路 = `dmesg -w` 落盘 + `pstore`/`ramoops` 窗口）。若都没就位，**请先修取证通道再上机**。
5. 是否要我把路线 B 的构建脚本（`mk-sysroot.sh` + cross-file + `mk-debs.sh`）**移入仓内** `packaging/sensors/`（本轮按派工单只写报告，未落仓）。

---

## 附：本轮命令台账（全部 `timeout -k` 包裹，可重跑）

```
pi-load --brief                      # SATURATED（28 核 load 74.73），建议 -j1 ⇒ 实际用 -j4 + 槽位
build-slot take y700-elden:libssc-prep --jobs 4 --ttl 3600
curl -sS https://gitlab.freedesktop.org/api/v4/projects/mobile-linux%2Flibssc   # → 404（已迁移 Codeberg）
git ls-remote --tags https://codeberg.org/DylanVanAssche/libssc.git             # → v0.4.4
curl -sS .../projects/hadess%2Fiio-sensor-proxy/repository/files/meson_options.txt?ref=3.9  # → ssc-support
curl -sS https://api.ftp-master.debian.org/madison?package=iio-sensor-proxy&table=all       # 3.9-1 testing/unstable
curl -sS https://api.ftp-master.debian.org/madison?package=libssc&table=all                 # 0.4.4-2.1 testing/unstable
/tmp/ssc-prep/mk-sysroot.sh                    # trixie arm64 sysroot，101 deb / 207 MB
meson setup|compile|install  libssc v0.4.4          # PASS
meson setup|compile|install  iio-sensor-proxy 3.9   # PASS，-Dssc-support=enabled
objdump -p …/iio-sensor-proxy | grep NEEDED     # → libssc.so.2
qemu-aarch64 -L <trixie-sysroot> …/ssccli --help / iio-sensor-proxy --help      # 均正常
/tmp/ssc-prep/mk-debs.sh                        # 4 个 .deb + sha256
build-slot drop 063010-472556-y700-elden_libssc-prep
```
