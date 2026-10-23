# 67 · 「面板 GOOD 但看起来像黑屏」= 背光被自动亮度压到 4%；顺手一个真发现：容器相机的 `/dev/video100` bind 从来没进持久配置

- 编号：**#372**（背光下限）、**#373**（容器相机 bind 丢失 + `cam-loopback.sh` 假阳性）
- 日期：2026-10-23
- 报告：`reports/closeout-q29-backlight-camera-20261023.md`

---

## #372 背光 4% 伪装成「设备没响应」

### 现象

设备一切正常 —— `card0-DSI-1=connected/enabled`、DSI 错误 0、`phoc`/`phosh` 在跑、会话 active、SSH 通 ——
但人看到的是黑屏、按键无反应。**本轮开头因此误判了一次设备状态。**

实测值：`/sys/class/backlight/aw99706-backlight/brightness = 160/4095 ≈ 4%`。

### 根因（两条叠加）

- 驱动初始亮度就是 160（低档）；
- `org.gnome.settings-daemon.plugins.power ambient-enabled = true`（自动亮度）在冷起后继续把亮度往下压。

### 判据（30 秒排除）

```sh
cat /sys/class/backlight/*/brightness /sys/class/backlight/*/max_brightness
cat /sys/class/drm/card0-DSI-1/status
```

`connected` + 亮度 < 12% ⇒ **先提亮度再怀疑设备**。写一个可见值（如 1024）即可确认面板是好的。

### 修法（已落地）

- `ambient-enabled = false`（dconf 持久）；
- OpenRC 服务 `backlight-floor`（`supervise-daemon`，20 s 轮询，`BACKLIGHT_FLOOR=1024`），
  只在**实际发生钳位**时写日志（否则每 20 s 一条会刷屏）。
- 源文件：`scripts/elden-backlight-floor.sh`、`rootfs/persistent-overlay/etc-initd-backlight-floor`、
  `rootfs/persistent-overlay/etc-conf.d-backlight-floor`。

### 教训

**「设备不响应」先看背光，不要先看 SSH/DRM。** 这一条与 `PITFALLS #251`（点亮判据必须面板实测）是一对：
判据要人眼确认，但**人眼看到的黑不一定是面板黑**。

---

## #373 容器相机 0 devices = bind 没进持久配置；`cam-loopback.sh` 的互斥检查 100% 假阳性

### 373a：`/dev/video100` 的 bind 从来没写进 `config_nodes`

2026-10-19 达成过 `Number of camera devices: 1`，但那次的 bind 是**会话内手工加在容器里的**，
`config_nodes` 里 `grep video` = **0**（连 `.bak` 也是 0）⇒ 容器一重启就回落 **0 devices**。

判据链（provider 其实是好的，别往 ABI 上想）：

```
init.svc.vendor.camera-provider-2-4-ext = running        # 没崩
lshal | grep ICameraProvider  → external/0  Y            # 已注册
dumpsys media.camera → "static info: 0 devices"          # 但 provider 看不到设备
容器内 ls /dev/video100 → 不存在                          # ← 就是这里
```

⇒ **`dumpsys` 说 0 devices 而 provider 在 running，第一个要查的是设备节点有没有绑进容器**，
不是 `.so` / vtable / manifest。

修法（持久）：`config_nodes` 加

```
lxc.mount.entry = /dev/video100 dev/video100 none bind,create=file,optional 0 0
```

`optional` 很重要：节点不存在时容器照常启动（否则 Q28 坏发/没插摄像头时容器起不来）。

**前后摄语义**：external HAL 只有 1 个 external 设备（`device@3.4/external/200`），
所谓「切换前后摄」= **换 loopback 生产者**（`cam-loopback.sh start front|rear`），不是换 Android camera id。

### 373b：`cam-loopback.sh start` 永远拒启动（假阳性）

旧互斥判据：

```sh
pgrep -af 'cam .*-c|captureScript|gnome-snapshot|snapshot'
```

**`snapshot` 命中内核线程 `[disp_snapshot]`**（display 快照，与相机毫无关系）⇒ 永远返回 1
⇒ `start` 永远 `REFUSE: 已有相机客户端在跑`。而这个线程**一直在**，所以这个检查等于永久禁用。

修法（只匹配用户态客户端；内核线程在 `ps` 里是 `[name]`，会被下面的 `\[.*\]` 排掉）：

```sh
ps -eo pid,args | grep -E '(^|[ /])(cam|captureScript|gnome-snapshot|snapshot)( |$)' \
  | grep -vE 'pgrep|grep|cam-loopback|\[.*\]' | wc -l
```

验收：新判据 0、旧判据 1（`[disp_snapshot]`）。

### 通用纪律

(1) **`pgrep -f '词'` 会命中内核线程**（`ps` 里显示成 `[词]`），凡是「有没有别的客户端在用」这类判据，
一律排除 `[.*]` 形态，或用 argv[0] 边界匹配。
(2) **只在会话里验证过的持久化前提，等于没验证**：`config_nodes`/udev rules/`/etc/modules` 这类「重启后还在吗」
的东西，验证方式必须是**重启后复查**，或直接 grep 持久配置文件本身。
(3) 「provider 在 running 但 0 devices」优先查**设备节点可见性**，再查 ABI。
