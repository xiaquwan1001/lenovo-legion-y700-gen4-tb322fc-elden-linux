# Debian 根 ①：accounts-daemon 竞态 + ADSP fastrpc 非安全域（`/dev/fastrpc-adsp`）

> 2026-10-26 23:0x · 零写盘（`fastboot boot` vk177 + 现场改 overlay）· 设备 = U2 `HA2EXB0E`
>
> **★口径更正（2026-11-26）：本文件 §0 表末行与 §4 的「SSC svc 400 未在 QRTR 注册」作废。**
> 该说法只在 hexagonrpcd 未成功 attach 的那次启动里看到，且当轮 `qrtr-tools` 未装、pre hook 判据本身就不可信。
> 现行事实（实测两次）：① **2026-10-27** `qrtr-lookup` 有 `400 Snapdragon Sensor Core service`、`ssccli --sensor accelerometer` 出真值，
> `HasAccelerometer=false` 的真因是 **iio-sensor-proxy 3.9 的 SSC 发现没 accel**（`TASKS/sessions/2026-11-02-T1-T22-收口台账.md` T22 ⑩）；
> ② **2026-11-26** 在 `hexagonrpcd.service` 仍 **masked**、`journalctl -b \| grep -c hexagonrpcd = 0` 的条件下，`qrtr-lookup` 同样有
> `400 … Snapdragon Sensor Core service` ⇒ **svc 400 的注册不依赖我们的 hexagonrpcd**（`reports/sensor-claim-verify-20261126.md` §2.2）。
> 因此「传感器要恢复必须先解决 #692」这一因果也被削弱：可先用纯用户态 libssc 验出数。

## 0. 结论（先数字）

| 项 | 之前 | 现在 | 判据 |
|---|---|---|---|
| `accounts-daemon` | `failed`，`status=226/NAMESPACE` | **active**（`Result=success`，D-Bus 可查 `26.27.3`） | `systemctl is-active` + `busyctl get-property … DaemonVersion` |
| `/dev/fastrpc-adsp` | **不存在**（只有 `-adsp-secure`） | **存在** | `ls /dev/fastrpc-*` |
| `hexagonrpcd` | `failed`（`Could not open FastRPC node`） | **active**（常驻） | `systemctl is-active hexagonrpcd` |
| `iio-sensor-proxy` | failed/不动 | **active**，`HasAmbientLight=true` | `gdbus introspect … SensorProxy` |
| 加速度计/陀螺（SSC svc 400） | — | ⬜ **仍未上**（`HasAccelerometer=false`；**★2026-11-26 更正：svc 400 当时已注册，真因是 iio-sensor-proxy 无 accel 发现，见文首更正块**） | 同上 |

## 1. accounts-daemon：`/run/systemd/seats` 与 logind 的冷起竞态

```
accounts-daemon.service: Failed to set up mount namespacing: /run/systemd/seats: No such file or directory
accounts-daemon.service: Failed at step NAMESPACE spawning /usr/libexec/accounts-daemon
status=226/NAMESPACE
```

`/run/systemd/seats` **由 systemd-logind 创建**，而 Debian 的单元只写
`After=nss-user-lookup.target systemd-tmpfiles-setup.service` ⇒ 与 logind 无先后关系，冷起抢先。

修法（overlay drop-in `accounts-daemon.service.d/zz-elden.conf`）：
`After=/Wants=systemd-logind.service` + `Restart=on-failure`。实测立刻 active。

## 2. `/dev/fastrpc-adsp` 缺失 = **上游 sm8750.dtsi 少一个属性**

对照证据（同一内核 vk172、同一板 DTB，Alpine 根也一样）：

```
$ ls /dev/fastrpc*
/dev/fastrpc-adsp-secure  /dev/fastrpc-cdsp  /dev/fastrpc-cdsp-secure     ← 没有非安全的 adsp
```

DT 里两个 fastrpc 节点的属性集不同：

| 节点 | label | `qcom,non-secure-domain` |
|---|---|---|
| `remoteproc@32300000/glink-edge/fastrpc`（CDSP） | cdsp | **有** |
| `remoteproc@6800000/glink-edge/fastrpc`（ADSP） | adsp | **没有** ← 根因 |

而 **sm8550 / sm8650 的 ADSP 节点都有该属性**（`sm8550.dtsi:3175/6037`、`sm8650.dtsi:4512/7655`）
⇒ sm8750 是遗漏。补一行后 `dtbs` 重编，`/dev/fastrpc-adsp` 出现（`-adsp-secure` 随之变成非安全域）。
**这一条是纯上游件（DT 一行 + 注释），可直接进 M 系列补丁。**

## 3. hexagonrpcd 在 Debian 上要先过三关（全部是"静默失败"）

1. **沙箱**：Debian 包的单元 `RestrictAddressFamilies=none` + `PrivateNetwork=yes`
   ⇒ 建不了 **`AF_QIPCRTR`** socket ⇒ 必然失败。drop-in 放开为
   `AF_UNIX AF_NETLINK AF_QIPCRTR AF_INET AF_INET6`，`PrivateNetwork=no`。
2. **ordering cycle**：`iio-sensor-proxy` 的 `After=hexagonrpcd-adsp-sensorspd`（= hexagonrpcd 的别名）
   而它自己 `WantedBy=multi-user.target`；若再把 hexagonrpcd 挂 `multi-user.target.wants` 就成环
   （`Found ordering cycle … hexagonrpcd after multi-user.target after iio-sensor-proxy after hexagonrpcd`，
   两个服务都不启动）。⇒ 改挂 **`default.target.wants`**（正是包 `WantedBy=default.target` 的原意）。
3. **文件服务根路径**：`hexagonrpcd -R <root>`，但 SSC 固件请求的是 Android 绝对路径
   `/vendor/etc/sensors/config/*.json` 与 `/mnt/vendor/persist/sensors/registry`（后者要**可写**）。
   ⇒ 在 served root 里补两条链接（不复制 800 KB）：
   `…/TB322FC/vendor/etc/sensors/config -> ../../../sensors/config`、
   `…/TB322FC/mnt/vendor/persist/sensors/registry -> /var/lib/elden-sensors-registry`。
   过了这关 hexagonrpcd 从「起来就退出」变成 **active 常驻**。

## 4. 剩余（G1-34 本体，未收口）

- ~~**SSC svc 400 未在 QRTR 注册** ⇒ `HasAccelerometer=false`~~ **（2026-11-26 作废，见文首更正块：svc 400 实测已注册）**；`iio-sensor-proxy.pre` 打
  `QRTR svc 400 (SSC) not seen after 60s; starting anyway`。
- 早期日志里有 `Unexpected buffer count: 1f050100`（协议/版本不匹配的候选）与大量
  `Could not open /vendor/etc/sensors/config/*.json`（补了映射后仍在，说明 DSP 请求的文件名不在我们
  那份 `config/` 里 ⇒ 需要按本机 stock 分区再抽一份 registry/config 对齐）。
- 结论：**链路已从「节点都不存在」推进到「守护进程常驻、等待 SSC 上电/注册」**，剩余是固件/注册表对齐。

## 5. 复现清单（全部已入库）

- `build/vk151`：`arch/arm64/boot/dts/qcom/sm8750.dtsi` + `qcom,non-secure-domain;`（ADSP fastrpc）→ 镜像 `out/boot-elden-vk177.img`
- `rootfs/debian/stage.sh`：accounts-daemon drop-in、hexagonrpcd drop-in（沙箱 + fw/registry 路径）、
  `default.target.wants` 启用、served-root 两条链接
- 现场验证命令见 §0 判据列
