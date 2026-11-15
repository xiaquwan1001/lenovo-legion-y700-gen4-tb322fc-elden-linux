# C3 Play Integrity 实测回包（SPIC v1.4.0，2026-11-15）

> 结论先行：**`deviceRecognitionVerdict` = `[]`（空数组）** ⇒ BASIC / DEVICE / STRONG **三档全部不满足**，
> 从 2026-11-10 的「书面判读」升级为**本机实测 RED**。判据表第 ① 种结果（三档全红 + 设备未认证）命中。
> 本轮只读/只装一个 APK，**未改镜像、未改 PIF、未改 fingerprint**。

## 0. 一句话数字

| 项 | 值 |
|---|---|
| 时间 | 2026-11-15 10:37–10:39（设备本地时间，UTC+8） |
| 设备 | TB322FC / elden，`uname -r` = `7.3.1-debug-vk189-suspend-00002-g4da9a8b69fc8-dirty` |
| 容器 | Waydroid，Android **13**（SDK 33），session RUNNING / container RUNNING，容器 IP `192.168.240.112` |
| APK | `herzhenr/spic-android` **v1.4.0**，11 219 447 B，sha256 `a9b0036e…3e471`（宿主直下需代理，见 §4） |
| 应用包名 | `com.henrikherzig.playintegritychecker`（SPIC = 该 app 的 fork，**同名包**；已装 v1.4.0，见 §2） |
| 请求 | `PlayCore IntegrityService.requestIntegrityToken`，nonce = `SXdGckdRT0haMXNBR1JXNzVBS0RHZktIdHdCVjU2ckFrTGZvNkJiU01ZcG5xcWJ6RWs=`，classic 档（device integrity） |
| 回包 | `deviceIntegrity.deviceRecognitionVerdict = []`（无任何 label）、`appIntegrity.appRecognitionVerdict = UNEVALUATED`、`accountDetails.appLicensingVerdict = UNEVALUATED` |
| 指纹 | `waydroid/lineage_waydroid_arm64_only/waydroid_arm64_only:13/TQ3A.230901.001/eng.aleast.20260927.073220:userdebug/test-keys` |
| GMS 账号 | `dumpsys account` 有 1 条 google 账号（登录态在） |

## 1. 原始回包（SPIC「Raw JSON」弹窗，逐字）

```json
{
  "accountDetails": { "appLicensingVerdict": "UNEVALUATED" },
  "appIntegrity": { "appRecognitionVerdict": "UNEVALUATED", "certificateSha256Digest": [] },
  "deviceIntegrity": { "deviceRecognitionVerdict": [] },
  "requestDetails": {
    "nonce": "SXdGckdRT0haMXNBR1JXNzVBS0RHZktIdHdCVjU2ckFrTGZvNkJiU01ZcG5xcWJ6RWs=",
    "requestPackageName": "com.henrikherzig.playintegritychecker",
    "timestampMillis": 1794710299098
  }
}
```

UI 侧呈现：Device Integrity = **NO_INTEGRITY**（三个红圈），App recognition / App licensing = UNEVALUATED。

## 2. 步骤与可复跑命令

```sh
# 0) 宿主：代理 + 暴露给设备（2026-11-15 现态：unit 未安装，须手工起）
bash scripts/host-net-proxy.sh            # 起 systemd-socket-proxyd：192.168.7.9:7897 -> 127.0.0.1:7890
bash scripts/host-net-proxy.sh --check    # rc=0 才算通（本轮起点是 PROBLEM: 未暴露）

# 1) APK（★ 直连已不可用，必须走代理；见 §4）
curl -sSL -o out/apk/spic-v1.4.0.apk \
  https://github.com/herzhenr/spic-android/releases/download/v1.4.0/spic-v1.4.0.apk
scp out/apk/spic-v1.4.0.apk elden-root:/tmp/

# 2) 容器会话（必须按会话用户 1001 起，root 起 UI 无窗口）
setpriv --reuid=1001 --regid=1001 --init-groups \
  env HOME=/home/xuqianhui1001 XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus setsid nohup /usr/local/sbin/waydroid-ui.sh &
waydroid status          # 要 Session/Container 双 RUNNING

# 3) 安装（★ 用会话用户身份，root 跑 app install 会报 "WayDroid session is stopped"）
setpriv --reuid=1001 --regid=1001 --init-groups env HOME=/home/xuqianhui1001 \
  XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus waydroid app install /tmp/spic-v1.4.0.apk

# 4) 起应用 + 点「Make Play Integrity Request」
waydroid shell -- am start -n com.henrikherzig.playintegritychecker/.MainActivity
waydroid shell -- input tap 954 681        # 按钮坐标（1902x2898 屏）

# 5) 取证：容器内截图后 base64 取出（宿主 /var/lib/waydroid 下不是普通目录，别去 find）
waydroid shell -- screencap -p /data/local/tmp/spic2.png
waydroid shell -- sh -c 'base64 -w0 /data/local/tmp/spic2.png' | base64 -d > spic-02-verdict.png
waydroid shell -- sh -c 'logcat -d -s PlayCore:V | tail'
```

产物（本仓已落）：`reports/artifacts/c3-spic-20261115/{spic-01-launch.png,spic-02-verdict.png,spic-03-rawjson-settings.png,spic-04-rawjson-settings.png}`。

## 3. 判读（对齐 `reports/c3-pi-tiers-closeout-20261110.md` 的判据表）

| 档 | 结论 | 实测支撑 |
|---|---|---|
| **BASIC** | **不满足** | `deviceRecognitionVerdict` 里没有 `MEETS_BASIC_INTEGRITY`；回包是**空数组**而不是"缺字段" |
| **DEVICE** | **不满足** | 同上；指纹 = `userdebug` + `test-keys` + Waydroid 非认证 build |
| **STRONG** | **不满足**（且结构性） | 空数组 + 容器内 keymaster 4.0 软实现（无 TEE）+ EL2 归签名 Gunyah |
| App / Licensing | UNEVALUATED | classic 档只请求 device integrity；不影响上面三档判读 |

⇒ 与 2026-11-10 的书面判读 **一致**；判据表第 ③ 种（全绿推翻）**未发生**。
⇒ 后续若要"少失败"，唯一可变项仍是 PIF 类伪装（窗口期产物，不可承诺），本轮**未做**（未装 PIF、未改 fingerprint）。

## 4. ★ 顺带推翻的一条旧口径（时间序裁决应用）

`reports/c3-pi-tiers-closeout-20261110.md` §5 写「GitHub **直连可达**；走代理会 403」。
**2026-11-15 实测相反**：`--noproxy '*'` 直连 **60 s 超时 / `unexpected eof`**（下行 <1 KB/s），
走 `http://127.0.0.1:7890` 代理 **2.25 s 下完 11 MiB（HTTP 200）**。
⇒ 口径更正：**取 GitHub release 一律走代理**；「直连可达」只在 2026-11-10 那一时点成立。
⇒ 另：`scripts/host-net-proxy.sh` 的 user systemd unit **当前未安装**（`--check` rc=1），
  容器出网前必须手工起一次 —— 否则 GMS/DroidGuard 报 `Connectivity error`（本轮 logcat 实见），
  回包会变成"网络失败"而不是"真 verdict"，**这一层必须先排除再看结论**。

## 5. 未做（明确记账）

- PIF + `pif.json` 伪装分支（报告 §5 附加变量 b）、未认证设备注册分支（c）—— 均需改镜像/改系统态，**未做**。
- Widevine：结论不变（ClearKey only），本轮无新增取证。
- Play 商店内「设备未认证」的 UI 截图：未取（回包已足够定性）。
