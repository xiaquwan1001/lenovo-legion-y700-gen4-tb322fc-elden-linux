# C0「真 Android 对照基线」取证（U2 a 槽 stock，2026-10-11）

> 目的：在覆盖 a 槽之前，从**真 Android** 采一份兼容层「标准答案」（Q5）。
> 设备：**U2 `HA2EXB0E`**（16+512，`SM8750P_16+512_13`），a 槽 stock。
> 采集器：`scripts/c0-android-evidence.sh HA2EXB0E`（+ 本轮补充采集）。
> 产物：`backup/HA2EXB0E-16+512/c0-baseline/`（含 `SHA256SUMS`，244 KB）。

## 0. 一句话结论

**U2 的 a 槽是真 Android 16（build `ZUXOS_1.5.10.259_260611`）、BL 已解锁、Widevine `L1`、HDCP 2.3，但未 root 且无任何 Google 账号登录**。
进 Android 只需 `fastboot --set-active=a` + `fastboot reboot`（**无需刷 dtbo**，dtbo_a 有效）；返回 Linux 用 `fastboot --set-active=b`。

## 1. 关键数字（对照表）

| 项 | 真 Android（U2 a 槽，本轮） | 备注 |
|---|---|---|
| build | `TB322FC_CN_OPEN_USER_Q00041.1_W_ZUXOS_1.5.10.259_ST_260611` | Android 16 |
| fingerprint | `Lenovo/TB322FC_PRC/TB322FC:16/BQ2A.250610.001-BP2A.250605.031.A3/ZUXOS_1.5.10.259_260611_PRC:user/release-keys` | `user`/`release-keys` |
| hwboardid | `SM8750P_16+512_13` | — |
| boot | `flash.locked=0`、`verifiedbootstate=orange`、`slot_suffix=_a` | BL 解锁 |
| **Widevine** | **`L1`**（`dumpsys IDrmFactory/widevine`：`default_security_level: L1`，CDM `19.0.1@AV1A.241014.001`，OEMCrypto API 19.2，`provisioning_model=BootCertificateChain`，`device_id`/`provisioning_id` 已下发） | 容器侧 U5 上限的对照 |
| HDCP | `hdcp_level_max: HDCP-2.3` | — |
| root | ❌ 无 `su`（`user` build，`ro.debuggable=0`） | 故 `/proc/partitions`、部分 dumpsys 取不到 |
| Google 账号 | `dumpsys account` → `Accounts: 0` | a 槽为解锁后新态，未登录 |
| GMS | `com.google.android.gms` `25.24.31`；`com.android.vending` `22.7.54-23` | 有 GMS/Play，未登录 |
| 传感器 | `42 h/w sensors`（含 accel/mag/gyro/ALS/prox/gravity/rotation_vector…，TDK icm4x6xa + qst qmc6308 + eminent ALS/prox） | 见 `sensor-list.txt` |
| AVF/virt | `com.android.virt.apex` 87.8 MB；`/apex/.../bin` 有 `crosvm`/`virtualizationservice`/`virtmgr`/`vm` | C8 侧对照；本树无 gunyah 驱动 |
| 分区 | `by-name.txt`（boot_a→sde12, dtbo_a→sde16, vbmeta_a→sde15 …） | — |

## 2. 采集到的文件清单

见 `backup/HA2EXB0E-16+512/c0-baseline/SHA256SUMS`（22 个文件）：
`getprop-all.txt`、`getprop-dalvik.txt`、`key-props.txt`、`widevine-props.txt`、
`dumpsys-drmFactory-widevine.txt`、`dumpsys-media.drm.txt`(服务不存在)、`dumpsys-drmManager.txt`(空)、
`dumpsys-sensorservice.txt`、`sensor-list.txt`、`by-name.txt`、`packages.txt`、`slot-props.txt`、
`virt-*.txt`、`keystore-props.txt`、`dumpsys-account.txt`、`gms-version.txt`、`vending-version.txt`。

## 3. 未自动化 / 待补（需人工或另需条件）

1. **7 颗传感器 30 s 采样 CSV**：`cmd sensorservice` 无采样子命令，需设备侧 App（如 Termux/sensor 工具）逐颗录 CSV。
2. **5 个目标 App 关键流程录屏**：`adb shell screenrecord` + `adb pull`。
3. **Play Integrity 判定**：需装 PI 检测 App + 登录 Google 账号（当前 `Accounts: 0`）。
4. **root 项**：`/proc/partitions`、受保护 dumpsys（本 a 槽 `user` build 未 root 取不到）。

## 4. 本次操作史（可复现）

```
fastboot getvar all                → slot=b succ=yes / slot=a unbootable=no retry=7
fastboot --set-active=a            → current-slot: a
fastboot reboot                    → adb device 约 105 s 上线
adb shell getprop sys.boot_completed → 1（约 45 s）
scripts/c0-android-evidence.sh HA2EXB0E   （+ 本轮补充采集）
```
- **未做任何写分区操作**（未刷 dtbo_a/boot_a）——HANDOFF §20「多数情况只切槽就够」在本机再次成立。
- 采集脚本 bug 已修：容量档解析 `SM8750P_16+512_13` 曾被截成 `13`，现用 `grep -oE '[0-9]+\+[0-9]+'`。

## 5. 对 G2 的意义

- 容器侧 Widevine **L3** 是硬上限（arm64 无 L1 库），真机对照 = **L1** ⇒ `TASKS.md §6 §1` 的 DRM 维可据实打分。
- 真机 PI 期望 = 已解锁(`orange`)+未 root 的 stock ⇒ 容器要达到「等价」需绕过/硬化；本基线给出**未 root 的 stock 参考态**。
- 传感器 42 个（含 wakeup 变体），容器侧 C4 目标是「列出 elden 的 5 类物理传感器」——对照尺子已就位。
