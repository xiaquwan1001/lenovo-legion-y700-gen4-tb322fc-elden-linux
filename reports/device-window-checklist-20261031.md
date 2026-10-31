# 设备窗口执行单（B 类阻塞合并）— 2026-10-31

> 把散在 TASKS/DEVICE/reports 里「需人在场或一次物理动作」的判据合成**一次设备窗口**执行单。
> 全部命令可复制；证据一律 `2>&1 | tee reports/artifacts/device-window-20261031/<gate>.log`。
> 采集脚本：`scripts/device-window-collect.sh`（只读，支持 `--dry-run`）。
> 设备基线：**vk183-fastrpc**（`boot_b` sha `aedae5f1…`，根 `/dev/sda17` ext4，Debian，`root@192.168.7.1`；见 `DEVICE/README.md` §1.1）。
> 纪律：所有 ssh 命令经 `scripts/device-lock.sh`；物理动作（断电/按键）= 用户执行；fastboot 逐条跑。

## 0. 结论速览（条目计数：7 条 = 1 条已完成 / 4 条待执行 / 1 条 BLOCKED（W5 上游 v4）/ 1 条非本窗口（W7））

| ID | 条目 | 状态 | 窗口位置 |
|---|---|---|---|
| W1 | vk183 转正 | ✅ **已完成（2026-10-31 15:29 真 POR，判据全绿**，`TASKS/README.md:394`、trial `reports/trials/20261031T073414Z-vk183-daily-por-r1.json`）→ 本窗口只做**关机路径复核**（与 W2 合并采 Q28 签名/vermagic） | T1 开机即采 |
| W2 | T14 真关机路径 1 次 | 待执行（greetd P0 drop-in 已装且生效，需 1 次真样本） | **T3 收尾**（本窗口最后一次动作） |
| W3 | C5-U7 容器 App 实开相机预览 | 待执行（前置：MJPG 喂帧 + Binary Eye APK） | T2 中段 |
| W4 | C3 Play Integrity 三档回包 | 待执行（容器内装 PI Checker） | T2 中段（与 W3 同一容器会话） |
| W5 | wl2868c i2c10 运行时验证 | **vk183 上下游证据已有**（`/dev/i2c-10`、`camera_ldo1..5,7`，`TASKS/README.md:406`）；**上游 v4 系列的验证需先刷 v4 镜像 ⇒ 本窗口标 `BLOCKED`（缺 v4 签名镜像/刷写批准）**，只给只读验证命令 | T1 采集（vk183 现状）/ 刷 v4 后复采 |
| W6 | 平板夜间通道 `USTC_API_KEY` | 待用户填一次（凭据，需用户操作） | 任意时刻（1 min） |
| W7 | T11 宿主内存 BIOS | **非本窗口**（用户进 BIOS 动作，单列 §8） | — |

---

## 窗口编排（先读这段再动手）

**同一次启动内完成（顺序 T1→T2）：**

- **T1 开机即做（≤10 min，全只读）**：跑 `scripts/device-window-collect.sh`（§7）采齐基线：dmesg 关键行、`/proc/cmdline`、UTS/`boot_id`、dpms/面板、`systemctl --failed`、模块计数、Q28 签名计数、相机设备、i2c10/wl2868c 现状（W1 复核 + W5 vk183 侧证据）。
- **T2 容器会话（同一启动，约 30–45 min）**：Waydroid 起会话 → W3 相机（先起 MJPG 生产者，再装/启动 Binary Eye）→ W4 PI Checker（装 APK、触发三次检查、抓回包）。两者共用同一容器会话，做完再继续。

**必须重启/关机的：**

- **T3 收尾（唯一关机动作，兼 W1 复核 + W2 唯一样本）**：`systemctl poweroff` 计时；**下一次开机后**按 §W2 判据取 `journalctl -b -1`。若用户愿意多做一次断电，可再叠加一次真 POR 复采（可选，非必需）。

**物理动作（用户）：** T3 的触发本身在 ssh 内即可（`systemctl poweroff`），无需按键；仅当系统卡死时才长按电源（逃生，不算样本）。若做可选 POR 复采 = 物理断电一次。

**启动次数合计：最少 1 次关机 + 1 次开机（T2/T1 在关机前的同一启动内完成）。**

---

## W1 vk183 转正（已完成 → 复核）

| 字段 | 内容 |
|---|---|
| ID | W1 |
| 前置 | 在机 = vk183（`boot_b` sha `aedae5f1…`）；镜像 ≥ vk183 |
| 状态 | ✅ 主判据已过（2026-10-31 15:29 真 POR：Q28 7 项全 0、面板 On、1639 `.ko`、失败单元 0、传感器 face-up）。本窗口只复核**签名未漂** |
| 命令 | `scripts/device-lock.sh ssh root@192.168.7.1 "dd if=/dev/disk/by-partlabel/boot_b bs=4M 2>/dev/null \| sha256sum \| cut -c1-8; uname -r; uname -v"` |
| 判据 | sha 前 8 = `aedae5f1`；`uname -r` = `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172`；`uname -v` 含 `#1 … 19:00:42` |
| 期望现象 | 与 `DEVICE/README.md` §1.1 首条逐字一致 |
| 失败处置 | sha 不符 ⇒ **停手保现场**，回总管（PITFALLS §0；勿再刷写） |
| 耗时 | 1 min |

## W2 T14 真关机路径 1 次（本窗口收尾动作）

| 字段 | 内容 |
|---|---|
| ID | W2 |
| 前置 | greetd P0 drop-in 已装且生效（`reports/greetd-stop-verify-20261031.md` ①②：`TimeoutStopUSec=5s`、`ExecStop=greetd.stop`）——**关机前先跑下面前置确认** |
| 前置确认 | `scripts/device-lock.sh ssh root@192.168.7.1 "systemctl show greetd -p TimeoutStopUSec -p ExecStop; systemctl cat greetd \| grep -E 'ExecStop\|TimeoutStopSec'"` → 期望 `TimeoutStopUSec=5s`、`ExecStop={ path=/usr/local/libexec/elden/greetd.stop …}`；不符 ⇒ 本条无效，先查生成链（**旧 P0 drop-in `zz-stop.conf` 已于 2026-10-31 移除并退役，停止语义现由 `stop.tsv`→`render.py` 渲染进 unit 本身**，`systemctl cat` 能直接看到） |
| 命令 | 触发（设备 ssh 内）：`t0=$(date +%s); systemctl poweroff; echo "trigger→cmd-return $(( $(date +%s)-t0 ))s"`（ssh 会断，属预期）<br>**下次开机后取证**：`scripts/device-lock.sh ssh root@192.168.7.1 "journalctl -b -1 -o short-unix --no-pager \| grep -E 'Stopping greetd\|Stopped greetd\|timed out\. Killing\|Failed with result\|System is powering off\|final.target'" 2>&1 \| tee reports/artifacts/device-window-20261031/w2-poweroff-b-1.log` |
| 判据（`reports/shutdown-greetd-hang-plan-20261030.md` §4.4） | ① `Stopping greetd`→`Stopped greetd` **≤2 s**（旧基线 90.027–90.233 s）；② `stop-sigterm' timed out` 计数 = **0**；③ 无 `Failed with result 'timeout'`；④ 触发→`final.target` **≤5 s**（现状 90.2 s）；⑤ 回归：`grep -c "timed out. Killing"` 其它单元 = 0 |
| 期望现象 | 用户侧：从下关机命令到屏幕灭 ≤5 s（原 ~90 s） |
| 失败处置 | 仍 90 s/超时 ⇒ **回滚 = 恢复设备 `/root/greetd-backup-20261031/` 原件**（或临时删掉 `greetd.service` 里的 `ExecStop=`/`TimeoutStopSec=` 两行）→ `systemctl daemon-reload`；**不要**再找 `zz-stop.conf`（已退役）→ 存档该 boot 的 journal + `/var/log/greetd.log` stat → 按 plan §2.4/§2.6 复查第二顺位（PAM close） |
| 耗时 | 5 min（关机 ~5 s）+ 下次开机取证 3 min |

## W3 C5-U7 容器内 App 实开相机预览（前置 `/dev/video100` bind 持久化已具备）

| 字段 | 内容 |
|---|---|
| ID | W3 |
| 前置 | 在机 vk183（`v4l2loopback` 用 `patches/extmod/0002`（depth 16）版 `.ko`，`scripts/deploy-v4l2loopback.sh` 幂等）；容器镜像带 Binary Eye（若无 ⇒ 按 `PITFALLS #467` 推 APK）；已知坑：`#459`（容器启动时无 `/dev/video100` → 0 字节文件，须重启容器）、`#465`（`androidboot.mode=charger` 毒化）、`#373`（硬件管线互斥） |
| 命令 | ① `scripts/device-lock.sh ssh root@192.168.7.1 "modprobe v4l2loopback exclusive_caps=1 video_nr=100; ls -l /dev/video100"` → 判据：`crw-rw-rw- 81,0`<br>② `scripts/device-lock.sh ssh root@192.168.7.1 "scripts/waydroid-cam-restart.sh; waydroid status"` → Session user = `xuqianhui1001(1000)`（PITFALLS #353）<br>③ 生产者（MJPG，唯一被 HAL 接受格式）：`scripts/cam-loopback.sh start front`（内部走 mjpgfeed）<br>④ App：容器内 `am start -n com.gmail.mappz.binaryeye/.activity.SplashActivity`（或桌面点开 Binary Eye），**用前置摄像头对准任意物体看实时预览**<br>⑤ 取证：`scripts/device-lock.sh ssh root@192.168.7.1 "waydroid shell logcat -d \| grep -E 'Camera 200\|start V4L2 streaming\|ProcessCaptureRequest\|Active Camera Clients' \| tail -30; dumpsys media.camera \| grep -E 'Number of camera devices\|Device 0 maps'" 2>&1 \| tee reports/artifacts/device-window-20261031/w3-app-preview.log` |
| 判据 | ① 容器内 App **屏幕上出现实时预览画面**（用户目视确认）；② `start V4L2 streaming 1280x720@30fps` + `ProcessCaptureRequest latency histogram` 样本数持续增长（>50 帧，突破 10-29 的「97 帧后停」）；③ provider 进程存活：`pidof camera-provider-2-4-ext` 前后一致、无新 tombstone（`ls /data/tombstones` 计数不变）；④ surfaceflinger 不 SIGABRT（无 `Unable to generate SkImage`） |
| 期望现象 | Binary Eye 取景框出画面（若其解码条码成功 = 预览双保险证据） |
| 失败处置 | `metadata is null`/`-38` ⇒ 格式/depth 坑（`PITFALLS #460`、`patches/extmod/0002` 未打）；provider SEGV ⇒ gralloc 回退件 `vendor.img.bak-l1d-20261029-103701`；SF SkImage 崩 ⇒ 记录 tombstone 后停（超出本窗口，回总管）；硬件管线忙 ⇒ `cam-loopback.sh stop` 后重试 |
| 耗时 | 15–25 min |

## W4 C3 Play Integrity Checker 三档回包

| 字段 | 内容 |
|---|---|
| ID | W4 |
| 前置 | 容器 = GAPPS A13（`sys.boot_completed=1`）、GMS 已登录（`reports/c3-identity-drm-20261013.md` §0）、代理通（gstatic 204）；**预期先验**：`test-keys`+userdebug build 未做指纹伪装时 device integrity 必失败——本条为**取证判定，不预设通过** |
| 命令 | ① 装 Checker（APK 主机侧备好；无则用 Play 商店搜 "Play Integrity API Checker"）：先 `adb push <apk> /tmp/playintegrity-checker.apk`（或 `scp` 到设备），再 `scripts/device-lock.sh ssh root@192.168.7.1 "waydroid app install /tmp/playintegrity-checker.apk"`<br>② App 内点 **Request integrity verdict** 三次（间隔 ≥30 s，观察 standard/经典两判定）；<br>③ 取证：`scripts/device-lock.sh ssh root@192.168.7.1 "waydroid shell logcat -d \| grep -iE 'integrity\|verdict\|meets_\|droidguard\|DroidGuard' \| tail -60" 2>&1 \| tee reports/artifacts/device-window-20261031/w4-integrity.log` |
| 判据 | 三档记表：`MEETS_DEVICE_INTEGRITY` / `MEETS_BASIC_INTEGRITY` / `MEETS_STRONG_INTEGRITY` 各 = true/false/无回包；无回包时记录 DroidGuard 报错原文（超时/`general-errors` 等） |
| 期望现象 | 预期 = basic 可能 true、device false（test-keys）、strong 无；**以实测回包为准** |
| 失败处置 | 无回包 ⇒ 查容器代理（`curl -m12 https://www.gstatic.com/generate_204` 应 204）与 DroidGuard 进程（`ps -A \| grep droidguard`）；仍无 ⇒ 记「未取得 API 回包」收尾（与 2026-10-13 同状态，属有效取证结论） |
| 耗时 | 10–15 min |

## W5 wl2868c / i2c10 运行时验证（上游 v4 ⇒ BLOCKED）

| 字段 | 内容 |
|---|---|
| ID | W5 |
| 前置 | **vk183（下游板 DTS）侧证据已有**：`/dev/i2c-10`、`10-002f`、`camera_ldo1..5,7` 已注册（`TASKS/README.md:406`）。**上游 v4 系列**（`patches/upstream/wl2868c-v4-20261031/`）的 `&qupv3_2`/`&gpi_dma2`/`&i2c10` 全 okay 需要**刷 v4 镜像** ⇒ 本窗口缺已签名 v4 镜像与刷写批准，标 **`BLOCKED`（缺：v4 签名 boot 镜像 + 刷写动作放行）** |
| 命令（vk183 只读复核，本窗口可做） | `scripts/device-lock.sh ssh root@192.168.7.1 "ls -l /dev/i2c-10 /sys/bus/i2c/devices/10-002f 2>/dev/null; ls /sys/class/regulator \| wc -l; dmesg \| grep -E 'geni_i2c 888000\.i2c\|wl2868c' \| tail -5" 2>&1 \| tee reports/artifacts/device-window-20261031/w5-i2c10-vk183.log` |
| 判据（vk183 复核） | `/dev/i2c-10` 在、`10-002f` 目录在、dmesg 含 `geni_i2c 888000.i2c` + `[camera] loaded wl2868c-regulator` |
| 判据（**刷 v4 后**，期望 dmesg 行——留给下个窗口） | `geni_i2c 888000.i2c: Adding to i2c adapter`（qupv3_2/gpi_dma2 使能后 i2c10 实例化）；`wl2868c-regulator 10-002f: chip id 0x82`（探测）；`regulator_get: camera_ldo1 … registered`；负判据（若父节点仍 disabled）：无任何 `888000.i2c` 行 ⇒ `geni_se_probe()` 未跑 |
| 失败处置 | v4 上 `888000.i2c` 不出现 ⇒ 查 `sm8750.dtsi:695 gpi_dma2 / :721 qupv3_2 / :870 i2c10` 三处 status 是否全 okay（`mail-triage-20261031b.md` §4.2 High 条） |
| 耗时 | 复核 2 min（本窗口）；v4 上机另窗 |

## W6 平板夜间通道 `USTC_API_KEY`（用户填一次）

| 字段 | 内容 |
|---|---|
| ID | W6 |
| 前置 | 无（`reports/tablet-night-runner-dryrun-20261031.md`：runner/队列/单元均就绪，只缺 key） |
| 命令（用户在设备上） | `ssh root@192.168.7.1` 后：`install -d -m700 /root/.config; vi /root/.config/pi-tablet-night.env` 写一行 `USTC_API_KEY=<key>`；`chmod 600 /root/.config/pi-tablet-night.env` |
| 校验 | `scripts/device-lock.sh ssh root@192.168.7.1 "cd /root/y700-elden && DRY_RUN=1 RUN=0 TABLET_RSYNC_TARGET= bash .pi/plans/tablet-night-runner.sh .pi/plans/tablet-queue.jsonl" 2>&1 \| tail -5` → 期望 rc≠5（API 探活通过）；或 `ssh root@192.168.7.1 "grep -c USTC_API_KEY /root/.config/pi-tablet-night.env"` = 1 且权限 `-rw-------` |
| 期望现象 | DRY_RUN 不再以 `API 探活失败` 终止 |
| 失败处置 | 探活仍失败 ⇒ 按 `.pi/AGENT-OPS.md` 凭据纪律上报用户，不自行重试 key |
| 耗时 | 2 min（凭据 = 用户操作，agent 不得接触 key 值） |

## W7 T11 宿主内存（**非本窗口，单列**）

用户需进 BIOS 的动作（改内存频率/时序或 XMP 相关，属 `TASKS/README.md` T11），与平板窗口无关、不占本窗口时间。标记：**非本窗口**——待用户另约时间，不阻塞 W1–W6。

---

## §9 采集包

`scripts/device-window-collect.sh`（只读；`--dry-run` 仅打印将执行的命令，本机无设备可跑，rc=0）：
一次采齐所有读回型判据 → `reports/artifacts/device-window-20261031/`（T1 开机即跑；T3 关机后的 `journalctl -b -1` 取证在脚本里单独一段 `--post-shutdown`）。

## §10 复现

```bash
bash -n scripts/device-window-collect.sh && scripts/device-window-collect.sh --dry-run
# 设备窗口当天：
scripts/device-window-collect.sh                 # T1 基线（W1/W5 复核）
scripts/device-window-collect.sh --post-shutdown # T3 次日取证（W2 判据）
```
