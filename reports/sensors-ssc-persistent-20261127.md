# 传感器"开机自动恢复"落地 + 一个已知堆损坏（`free(): invalid next size`）

> 2026-11-27 续轮（承接 `reports/sensors-ssc-restored-20261127.md`）。目标：把上一轮的手工 attach 变成**每次开机自动生效**。

## 0. 结论

1. **已落地并验收（真重启后）**：设备 `systemctl reboot` → 起来后
   `elden-sensorspd` **active**、`iio-sensor-proxy` **active**、`HasAccelerometer/HasAmbientLight/HasProximity` 三 **true**、
   `ssccli --sensor accelerometer` 连续出值（Z≈9.52）。**不再需要手工 attach。**
2. **已知缺陷（不影响出数，但会重启一次服务）**：attach 流程末尾 `free(): invalid next size (fast)`（`SIGABRT`），
   systemd `Restart=on-failure` 拉起重来（`NRestarts=1`，之后稳定）。触发点紧跟在
   `Opening /mnt/vendor/persist/sensors/cam_registry_dump.txt for writing (writes are discarded)` + `Could not open …: No such file or directory` 之后 ⇒
   **怀疑在我们的 `fopen_with_env()` 写模式失败路径**（`apps_std.c`）。下一轮用 aarch64 `-fsanitize=address` 构建定位。
   （同一 boot 内二次 attach 会 `Could not register ADSP default listener`，所以这条重启路径**不能**依赖——目前是靠第一次就成功。）
3. **补丁又扩了三个方法**：`fopen_fd`(34)/`fclose_fd`(35)/`fopen_with_env_fd`(36) + `apps_std_interface.n_procs` 32→57
   （DSP 在 attach 末尾必调 36；未实现即 `Unsupported method: 36 (1f050100)` ⇒ 服务退出）。
   仓库补丁已更新：`patches/userland/hexagonrpc-write-20261127/`（369 行 diff / 约 190 行代码），本机 `ninja` 与 `meson test 3/3` 全绿。

## 1. 装了什么（都在仓库里有副本，设备上已生效）

| 件 | 位置 | 说明 |
|---|---|---|
| 二进制 | `/usr/local/bin/hexagonrpcd-patched`（sha256 `38162cc2…`） | v0.5.0 + 补丁；不碰 Debian 的 `/usr/bin/hexagonrpcd` 包装器（`PITFALLS #654`） |
| `-R` 树 | `/var/lib/hrpcd-root/`（`sensors/{config,registry,sns_reg.conf}`、`dsp/adsp`、`socinfo`） | 扁平布局（`PITFALLS #741`），config 来自官方 ROM 的真文件 |
| unit | `/etc/systemd/system/elden-sensorspd.service`（仓库副本 `packaging/elden-userland/files/etc/systemd/system/`，已进 `MANIFEST.tsv`） | `Type=simple` + `Restart=on-failure` + `StartLimitBurst=5/120 s`（防 `PITFALLS #732` 那类开机硬崩循环）；`ExecStartPre` 最多等 60 s 的 `/dev/fastrpc-adsp`（首次写 unit 时用了 `ConditionPathExists`，实测**开机时该节点还没出现**⇒ unit 被跳过，已改） |
| udev | `/etc/udev/rules.d/81-libssc-elden.rules`（仓库副本 `packaging/elden-userland/files/etc/udev/rules.d/`） | `ssc-accel ssc-proximity ssc-light ssc-compass` + `ACCEL_MOUNT_MATRIX`（`PITFALLS #451`） |
| 代理 | `iio-sensor-proxy.service` **enabled**（原为 masked） | 挂 multi-user（实测无需 `graphical.target` 也能起；`#453` 的 ordering cycle 只在它 `After=` 那个 sensorspd 单元时出现，本机新 unit 不带该依赖） |

## 2. 判据（照抄可用）

```sh
ssh elden 'systemctl is-active elden-sensorspd iio-sensor-proxy'      # 两个 active
ssh elden 'busctl get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasAccelerometer'   # b true
ssh elden 'ssccli --sensor accelerometer | head -2'                    # 连续出值，Z≈9.5
ssh elden 'systemctl show -p NRestarts elden-sensorspd'                # 目前 =1（堆损坏重启一次），>3 要查
```

## 3. 下一轮（按序）

1. **修堆损坏**：aarch64 ASan 构建（`-Db_sanitize=address`）→ 复现 → 定位到 `apps_std.c` 具体写越界的 out buffer；
   临时缓解已经有效（`Restart=on-failure`），但**不该留在设备上**。
2. **真写后端**（registry 持久化）：`hexagonfs_mapped` 只读 ⇒ copy-on-write 到 `/var/lib/hexagonrpc/`；`fwrite/ftrunc/fremove/frename/mkdir/rmdir/fsync` 真实现。
3. 上游：#29 仍 open；我们现在的「0 字节占位 + 扁平布局 + 真配置」三条经验可直接回帖（**需用户放行**）。

---

## 修订（2026-11-27 20:1x，接续轮）：unit 改 **oneshot + 有界等待**，禁止重启循环

**现场**：设备被换到内核 `7.3.1-debug-vk189-suspend-g4da9a8b69fc8-dirty`（`build/daily` 直出）后，**`/dev/fastrpc-adsp` 不存在**
（该构建的 DTB 没有 adsp fastrpc 的 `qcom,non-secure-domain`，即 G1-34/vk190 修过的那条回归），
原 unit 的 `ExecStartPre` 等 60 s 后 `exit 1` ⇒ `Restart=on-failure` 每 ~65 s 重启一次，**实测累积 `NRestarts=47`**。

**改法**（已落到设备与仓库副本）：
- `Type=oneshot` + `RemainAfterExit=yes` + `Type` 之外新增启动脚本 `/usr/local/sbin/elden-sensorspd-start`：
  最多等 **90 s** 的 `/dev/fastrpc-adsp`，等到就 `exec hexagonrpcd-patched … -s -R … -O …`；
  等不到就打印一行「kernel DT lacks adsp fastrpc non-secure-domain? - skipping attach」并 **`exit 0`**（成功结束，不进失败态）。
- `Restart=on-failure` + `RestartPreventExitStatus=1` + `StartLimitBurst=3/300 s`：真正的失败也不会打成无限循环。
- 验收（设备现态）：`systemctl is-active elden-sensorspd` = `active (exited)`、`NRestarts=0`、`Result=success`、`--failed` = 0，
  日志明确写下缺节点的原因。

**含义**：传感器现在**不起来**，因为当前内核没有该设备节点——这不是 sensor 栈回归，而是**内核 DT 缺项**（G1-34 的已知回归形态）。
换回带 `qcom,non-secure-domain` 的内核（或给该构建补上该节点）后，本 unit 会在开机自动 attach（脚本等节点，最多 90 s），
无需任何手工步骤。
