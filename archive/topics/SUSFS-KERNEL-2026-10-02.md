# SUSFS 自编内核 —— 完成报告（2026-10-02 夜）

> 承接 `ENV-PASS-2026-10-02.md`。目标：TB322FC 上带 **SUSFS** 的内核 + 更完整的「过环境」。
> **状态：已完成**。设备运行自编 `6.6.118 + ReSukiSU + SUSFS v2.3.0` 内核，Native Detector = normal。

---

## 0. 最终状态（实测）

| 项 | 状态 |
|---|---|
| `boot_a` | ✅ 自编 `6.6.118 + ReSukiSU + SUSFS v2.3.0`（AOSP testkey 重签过 AVB）|
| 系统启动 | ✅ `uname` 与原厂逐字节一致；vendor 模块 **488 个全加载** |
| SUSFS | ✅ `status=true`，v2.3.0 / GKI，全特性（SUS_PATH/SUS_MOUNT/SUS_KSTAT/SPOOF_UNAME/SPOOF_CMDLINE/OPEN_REDIRECT/SUS_MAP/HIDE_SYMBOLS）|
| SUSFS 规则 | ✅ `hide_sus_mnts_for_non_su_procs=true`、`avc_log_spoofing=true`、`sus_path={/data/adb/modules,/data/adb/ksu,/data/adb/ksud}`（已持久化）|
| root | ✅ `su -c id` = uid 0；`ksud` = **ReSukiSU 4.2.0-rc3 (uapi:4)**（与内核配套）|
| 管理器 | ✅ 只保留 `com.resukisu.resukisu`（旧的 `com.sukisu.ultra` 已卸）|
| Zygisk Next | ✅ `zn-daemon` + `zn-nsdaemon-zygote` 在跑，已加载 PIF |
| 属性伪装 | ✅ `verifiedbootstate=green`、`flash.locked=1`、`vbmeta.device_state=locked` |
| **Native Detector** | ✅ **The Environment is normal** |
| Securify | ⚠️ 2 项（USB 调试；REI 指纹不一致）—— 关调试即消 1 项，另一项为检测器瑕疵 |

---

## 1. 走过的关键坑

### 1.1 刷入自编 boot 被 ABL 拒绝（卡 fastboot、slot 被标 unbootable）
- 根因：stock `boot_a` 是 `vbmeta_a` 的 **chained AVB 分区**（受信 **AOSP testkey `2597c218`**，rollback index location 3）。
  CI 产出的 boot 用**另一把 key（`200b1722`）+ rollback=0** 签名 → ABL 拒绝。
- 修法（**必须**）：用 AOSP testkey 重签 + 补 AVB props + 与原厂一致的 rollback：
```bash
avbtool add_hash_footer --image <boot.img> --partition_size 100663296 --partition_name boot \
  --key env-pass/keys/testkey_rsa4096.pem --algorithm SHA256_RSA4096 --rollback_index 1738713600 \
  --prop com.android.build.boot.os_version:15 \
  --prop "com.android.build.boot.fingerprint:Lenovo/TB322FC_PRC/TB322FC:16/BQ2A.250610.001-BP2A.250605.031.A3/ZUXOS_1.5.10.259_260611_PRC:user/release-keys" \
  --prop com.android.build.boot.security_patch:2025-02-05
```
- 产物：`env-pass/build/boot-susfs-6.6.118-signed2.img`（sha256 `3fa5deab…`，**当前运行**）。
- 只加 testkey 不补 props 也失败（对照社区可用镜像 `ll1zt/...-droidspaces-boot.img` 才定位到 props/rollback）。

### 1.2 内置 KSU 内核 ↔ 用户态 ksud 不匹配
- 内置 ReSukiSU（uapi 4）配 SukiSU ksud（uapi 2）→ `zygisk_running` 上报 false、管理器不配套。
- 修法：把 ReSukiSU APK 的 `lib/arm64-v8a/libksud.so` 顶替 `/data/adb/ksud`，并装 `com.resukisu.resukisu`。

### 1.3 工具注意
- 本机 `adb shell su -c '<复杂命令>'` 会被吞/中断 → **用设备端 root 终端逐条执行**。

---

## 2. 资产

| 项 | 路径 |
|---|---|
| SUSFS 内核（**已刷**） | `env-pass/build/boot-susfs-6.6.118-signed2.img`（sha256 `3fa5deab…`）|
| 未签名原始 | `env-pass/build/boot-susfs-6.6.118.img`、`env-pass/kernel-susfs/…-boot.img` |
| AK3 恢复包 | `env-pass/kernel-susfs/android15-6.6.118-2026-01-AnyKernel3.zip` |
| AVB testkey | `env-pass/keys/testkey_rsa4096.pem`（公钥 sha1 `2597c218`，设备受信）|
| ReSukiSU 管理器/ksud | `env-pass/assets/ReSukiSU-v4.2.0-rc3-arm64.apk`；设备 `/data/local/tmp/envpass/ksud-resukisu` |
| 备份 | `backup/stock-259/{boot_a,init_boot_a}.img`；设备 `/data/adb/ksud.official.bak`、`ksud.sukisu.bak` |
| CI | `xiaquwan1001/tb322fc-r2-kernel-public-build`，workflow `…6.6.118 (SUSFS)`，run `36972722387` |

---

## 3. 回退

```bash
cd ~/y700-elden
fastboot --set-active=a
fastboot flash boot_a backup/stock-259/boot_a.img      # 回 stock 内核
fastboot reboot
```
- 设备端 ksud 回退：`cp /data/adb/ksud.sukisu.bak /data/adb/ksud`
- `slot-unbootable` 由 ABL 在失败启动时设置，一次成功启动即清。

---

## 4. 可选后续

1. 进游戏前关 USB 调试（消 Securify「调试模式」）：`settings put global adb_enabled 0`（会断 adb）。
2. 若要更强隐藏，可在 ReSukiSU 管理器 SUSFS 页继续加 `add_sus_path` / `add_sus_kstat` / `set_cmdline_or_bootconfig`。
3. 重跑/微调 CI 编译：`gh workflow run "TB322FC R2 ReSukiSU 6.6.118 (SUSFS)" --ref main`（约 28 分钟），出内核后按 §1.1 重签 AVB。

---

## 5. 关键事实

- 设备内核 = Qualcomm msm-kernel（GKI 基座 + `CONFIG_GKI_HIDDEN_*`），KMI `android15-6.6`；`MODULE_SIG_FORCE` 未开。
- `boot` 分区 **96 MiB**，内核为 **raw Image（MZ）**；**必须** AOSP testkey 重签 AVB 才能被 ABL 接受。
- 内置 KSU 内核**不需要** init_boot 里的 LKM（`init_boot_a` 现仍是 SukiSU LKM 版，ksuinit 自检跳过）。
- 设备原厂 kernel uname：`6.6.118-android15-8-g350f378eb496-ab14943902-4k`。
