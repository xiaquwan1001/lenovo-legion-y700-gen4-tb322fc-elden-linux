# #431 musl 件在 glibc 根上「存在但 exec ENOENT」⇒ Waydroid 卡 bootanimation；#432 systemd `${VAR}` 不分词

- **日期**：2026-10-27
- **场景**：Debian 根（linux17 / vk172）上 `waydroid-container` active、容器进程都在，但 Android 永远停在
  bootanimation，`sys.boot_completed` 拿不到；同时 `ssc-udp-relay` / `elden-hapticd` 每 5 s 退一次（restart counter 已 6 千+）
- **判据链**：`init.svc.vendor.sensors-hal-1-0=stopped` + logcat 每秒
  `Waited one second for android.hardware.sensors@1.0::ISensors/default` + `ctl.interface_start` `0x20`

## #431 Alpine 的 musl 大二进制搬到 glibc 根：`which` 命中 ≠ 能跑

`/usr/local/bin/waydroid-sensord`（Alpine 根那份，Oct 11）在 Debian 根上：

```
$ ldd /usr/local/bin/waydroid-sensord
	libgbinder.so.1 => /usr/lib/aarch64-linux-gnu/libgbinder.so.1   ← 看着都对
	libc.musl-aarch64.so.1 => not found                            ← 真凶
$ /usr/local/bin/waydroid-sensord /dev/hwbinder
bash: ...: No such file or directory        ← 缺 interpreter，报错文案完全不提 loader
```

危害不是"少了传感器"，而是**整机起不来**：Waydroid `container_manager.py:170` 用 `which("waydroid-sensord")`
判断"有 HAL"，`images.py:154` 因此**不再**设 `waydroid.stub_sensors_hal` ⇒ stub HAL 也不注册 ⇒
`sensorservice` 每秒重试 ISensors（framework 在 boot 阶段等它）⇒ Android 停在 bootanimation。
换句话说：**一个 exec 不起来的文件能把"容器卡住"伪装成配置/镜像问题**。

**修法**：用 glibc 重编同一份源码（Debian 有 `libgbinder1`/`libglibutil1`；dev 包按需装）：

```
bash scripts/deploy-sensord-routec-debian.sh      # 幂等：装依赖 → 编译 → 装 → 重启 relay/容器
```

实测判据：`dumpsys sensorservice` = `Total 6 h/w sensors, 6 running`、`sys.boot_completed=1`、
加速计读数 `1.42,0.51,9.50` 与 `ssccli --sensor accelerometer` 逐位一致。

**排查口径**：跨发行版搬任何 `/usr/local/bin` 件，先 `readelf -l … | grep interpreter` 看是不是
`ld-musl-*`；import 脚本（`rootfs/debian/import-waydroid.sh` [C] 段）现在会对 musl 件单独告警并指名修法。

## #432 systemd `ExecStart` 里 `${VAR}` **不分词**（`$VAR` 才分）

`services.tsv` 的 args 是按 shell 口径写的（OpenRC 侧靠 shell 分词）：

```
--dir /run/elden-haptic/leds/vibrator --verbose ${HAPTIC_ARGS}
```

渲染成 systemd 后：

```
$ /usr/local/bin/elden-hapticd … --verbose '--amp-a 0xffff --amp-b 0xffff'
/usr/local/bin/elden-hapticd: unrecognized option '--amp-a 0xffff --amp-b 0xffff'
usage: …                                                             ← exit 2
```

systemd 的规则：**`$VAR` 自成一词**才按空白切成多个参数；**`${VAR}` 整串作为一个参数**插入，
且不支持 `${VAR:-default}`。于是 `Restart=always` + `RestartSec=5` 把 status=2 变成无限重启
（`journalctl -u …` 只有 `Main process exited, code=status=2/INVALIDARGUMENT`，真错误在 `StandardOutput=append:` 的日志文件里）。

**修法**：`render.py` 新增 `_systemd_args()`，把 `${VAR}`/`${VAR:-…}` 统一降级成 `$VAR`（默认值由
`Environment=`/`EnvironmentFile=` 提供）。**别在 services.tsv 里为 systemd 改口径**——那是两种 init 的唯一真源。

## #433 `ssccli` 在 `libssc-bin`，不在 `libssc2`

```
$ ssc-udp-relay 日志：FATAL: ssccli not found (apk add libssc)
$ dpkg -L libssc2 | grep bin      →  空
$ apt-cache search libssc         →  libssc-bin - Qualcomm sensor core library - binaries
```

`pkgmap.tsv` 原来把 libssc 映射成 `libssc2 libssc-dev`（dev 是主机侧编 iio-sensor-proxy 用的），
**没有 CLI** ⇒ relay 立刻退出、HAL 只能拿到"无数据"⇒ 传感器列表有了但读数不动。
已改 `libssc2 libssc-bin`。

## #434 `lxc-info -n waydroid` 恒 "doesn't exist"；`restart waydroid-container` 可能留下无网桥

两个独立陷阱，都会把人带偏：

① **路径**：Waydroid 的 lxc state 在 `-P /var/lib/waydroid/lxc`。裸 `lxc-info -n waydroid` 查的是
   `/var/lib/lxc` ⇒ **恒** `waydroid doesn't exist`，而容器其实 RUNNING（`ps` 里 surfaceflinger/zygote 都在）。
   正确取 PID：`lxc-info -P /var/lib/waydroid/lxc -n waydroid -p`。
② **restart 竞争**：`systemctl restart waydroid-container` 时旧实例的 `waydroid-net.sh stop` 可能在新实例
   `waydroid-net.sh start` **之后**才跑完 ⇒ `waydroid0` 被删掉 ⇒ `lxc-start` 报
   `Failed to attach "vethXXXX" to bridge "waydroid0", bridge interface doesn't exist`
   ⇒ 容器 STOPPED 但 systemd unit 仍报 `active`（服务只是 dbus 名持有者）。
   恢复：`/usr/lib/waydroid/data/scripts/waydroid-net.sh start`，或再 `restart` 一次并**等 ≥20 s**；
   判据用 `ip -br link show waydroid0` + `lxc-info -P … -p` + `getprop sys.boot_completed`，别看 unit 状态。

## #435 `XDG_RUNTIME_DIR` 跨发行版不同：Alpine `/run/phosh` vs Debian `/run/user/<uid>`

`waydroid-session.sh` / `waydroid-ui.sh` 写死 `/run/phosh` ⇒ Debian 上直接
`Wayland socket '/run/phosh/wayland-0' doesn't exist; are you running a Wayland compositor?`。
两个脚本已改成**探测真实存在的 `wayland-0` socket**（`${XDG_RUNTIME_DIR}` → `/run/user/$(id -u)` →
`/run/phosh` → `/run/user/1001|1000|0`），失败时打印实际探测值。

## 附带修掉的一条

`lxc-net.service` 在 Debian 根**必然失败**（`ip6tables ... Could not fetch rule set generation id`），
而 Waydroid 自带 `waydroid-net.sh` 管 `waydroid0` ⇒ `stage.sh` 现在把 `lxc-net.service` **mask** 进 overlay
（`/etc/systemd/system/lxc-net.service → /dev/null`），门禁 G 段校验，避免每启一条失败单元污染判定。
