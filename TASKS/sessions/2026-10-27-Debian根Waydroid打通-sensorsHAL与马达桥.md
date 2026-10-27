# 2026-10-27 · Debian 根 Waydroid 打通：sensors HAL（glibc 重编）+ 马达桥 + relay

- **日期**：2026-10-27
- **pi 会话 id**：见 `$PI_SESSION_ID`
- **主题**：承接 T19「② Waydroid 进 Debian 根 / Android 卡 bootanimation」，把三个"每 5 s 自杀"的服务修成常驻，
  并让 Android 真正 boot 完成；顺带把跨发行版（Alpine→Debian）三处硬编码收进仓库门禁。
- **结论（数字）**：
  1. **Android 起完了**：`sys.boot_completed=1`、`dumpsys sensorservice` = **Total 6 h/w sensors, 6 running**、
     `waydroid0` = 192.168.240.112、session/container 双 RUNNING。
  2. **传感器是真值不是假值**：容器内加速计 `1.42, 0.51, 9.50` 与宿主 `ssccli --sensor accelerometer`
     （`X=1.422156 Y=0.517148 Z=9.504981`）逐位一致（`last 50 events` 连续 50 条）。
  3. **马达桥恢复**：`elden-hapticd` active（restart counter 从 6796 停止增长），
     `cmd vibrator_manager synced oneshot 500` → 日志 `vibrate ON 500 ms amp=255/255` + `OFF`。
  4. **三个服务全部常驻**：`ssc-udp-relay` 5 路 `streaming (pid …)`、`elden-hapticd`、`waydroid-sensord`
     （`waydroid-sensord /dev/hwbinder`，由 Waydroid 自己拉起）。
  5. **门禁**：`stage.sh` FAIL=0 WARN=1（WARN = T14 债务 `elden-hapticd` 无 repo 源码）、
     `verify.sh` FAIL=0 WARN=1、`check-pkgmap.sh` FAIL=0 WARN=0（apt 115 包）、`check-doctor` FAIL=0 WARN=2。
- **根因三条（详见 `PITFALLS` #431–#435）**：
  - `waydroid-sensord` 是 **musl 动态**件 ⇒ glibc 根上 exec ENOENT，但 `which` 仍命中 ⇒ Waydroid 关掉 stub
    却没有 HAL ⇒ `sensorservice` 每秒重试 ⇒ 卡 bootanimation（**不是**镜像/配置问题）。
  - `elden-hapticd` 的 systemd `ExecStart` 用 `${HAPTIC_ARGS}` ⇒ systemd **不分词** ⇒ 整串变一个 argv ⇒ status=2。
  - `ssc-udp-relay` 缺 `ssccli`（Debian 在 `libssc-bin`，原 pkgmap 只映射了 `libssc2` + `-dev`）。
- **落地（仓库侧）**：
  - `scripts/deploy-sensord-routec-debian.sh`（新，幂等：依赖 → 编译 → 安装 → 重启 relay/容器 → 出判据）
  - `packaging/elden-userland/tools/render.py`：`_systemd_args()`（`${VAR}` → `$VAR`）
  - `packaging/elden-userland/files/usr/local/sbin/waydroid-{session,ui}.sh`：`XDG_RUNTIME_DIR` 探测
    （`/run/phosh` 写死 → Debian 上 session 起不来）+ `MANIFEST.tsv` sha 同步
  - `rootfs/debian/pkgmap.tsv`：`libssc → libssc2 libssc-bin`（dev 只在主机侧编 iio-sensor-proxy 用）
  - `rootfs/debian/import-waydroid.sh`：musl 件单独告警并指名修法；缺 `ssccli` 也告警
  - `rootfs/debian/stage.sh`：`lxc-net.service` mask 进 overlay（门禁 G 校验）
- **设备侧命令（可复跑）**：
  `bash scripts/deploy-sensord-routec-debian.sh` → `waydroid status` → `lxc-info -P /var/lib/waydroid/lxc -n waydroid` →
  `nsenter -t <pid> -m -p /system/bin/getprop sys.boot_completed` →
  `nsenter -t <pid> -m -p /system/bin/dumpsys sensorservice | head -2`
- **证据指针**：本文件 §结论 + `PITFALLS/sessions/104-*.md`、`reports/debian-waydroid-20261026.md`（上一轮 §3 三条卡点已销）
- **同日追加（第二段）**：
  6. **冷起自启成立**：`/etc/xdg/autostart/elden-waydroid.desktop` → `waydroid-session.sh`；
     `systemctl restart greetd` 后 **10 s 内** `waydroid status` = Session RUNNING、`boot_completed=1`、6 sensors。
     两个坑：Debian sid gnome-session 见到 `X-GNOME-Autostart-Phase` 就**不执行**该条目（日志 "no longer manages
     session services"）；`X-GNOME-Autostart-Delay` 同属失效机制 ⇒ 脚本必须自己等 wayland socket（≤30 s）⇒ PITFALLS #436/#437。
  7. **可重现性收紧**：部署脚本优先取 **主机 arm64 chroot** 产物（`out/sensord-host/waydroid-sensord-udp`，
     sha `22028ffd…`，由 `scripts/host-arm64-chroot.sh --build-sensord` 产出），目标根不再需要 g++/dev 包；
     设备上现装即该产物（旧 musl 件留档 `/usr/local/bin/waydroid-sensord.musl.bak`）；MANIFEST 两条 elf 改记此 sha。
- **同日追加（第三段：半死态与误判纠正）**：
  8. `restart waydroid-container` 后容器**不自起**是**设计**（`Type=dbus` + initializer 等会话握手），
     表现为 `Session RUNNING / Container STOPPED` 且 unit `active`；`waydroid-session.sh` 现在做半死态自愈
     （stop+start）+ 起会话前兜底建 `waydroid0`。判据：restart 容器服务 + 跑脚本 → **3/3 / 5 s 内 Container RUNNING**。
  9. `Container: FROZEN` = **正常省电**（Android suspend → `container_manager.freeze()`；app launch → `Unfreeze`）。
  10. **否证**：`KillMode=process` 的网桥竞态假设 —— 实测不解决且残留 `waydroid0`，已回退（不要重复试）。
- **★SSOT 待并入**：

  - ✅ 已并入：`TASKS/README.md` 新增 **T22**；`PITFALLS/README.md` 索引行 105。
  - ⬜ 待并入：`reports/debian-waydroid-20261026.md` §3 应标注「已解决」（下轮改）；G1-34 本体（SSC svc 400 注册表）不动。
- **未做 / 阻塞**：
  - 容器内 **App 实开相机预览**（C5/U7）仍需装 APK；
  - `hexagonrpcd` 的 SSC svc 400 未注册（`HasAccelerometer=false` 那条链）与本次 Waydroid 传感器无关（那条走 libssc/host relay）；
  - Debian 根上 `waydroid-container` 的 `restart` 竞争（#434）未做 unit 级防护（目前靠等待 / 手工 net start）。
