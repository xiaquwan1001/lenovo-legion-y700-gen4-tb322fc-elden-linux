# M1-7.3（7.3-rc7 重基树）上机取证 — 2026-10-13 深夜

> 证据层。状态权威 = `TASKS.md` §7「M1-7.3（7.3-rc7 重基树）首次上机 bringup」表与结论块；教训 = `PITFALLS.md` §三十一（#248–#250）。
> 设备：U2 `HA2EXB0E`（`192.168.7.1`，USB-NCM/ACM gadget + SSH）。
> 全程**零写盘**（`fastboot boot`），未刷任何分区。

## 1. 结论（一句话）
「新内核外设全废」= **纯 ramdisk 镜像没带 `=m` 模块**（非代码回归）：
- 缺 `fsa4480` ⇒ 无 typec mode-switch ⇒ `pmic_glink.altmode` defer ⇒ `af54000.displayport-controller` 永久 defer ⇒ `disp_cc-sm8750 sync_state()` pending ⇒ **阻塞 `msm_drm_bind`** ⇒ 无 `card0`。
- 缺 `fastrpc` ⇒ 无 `/dev/fastrpc-adsp` ⇒ 传感器链断。
补上后 DRM/DP/传感器恢复；**但亮屏仍无好发**（面板 init 命中 Q28 签名）。

## 2. 证据链

### 2.1 黑匣子首次落盘（取证通道打通）
- `73h` ramdisk 第二段 cpio 覆盖 `/init`，后台子进程等 `LABEL=linux17` → 挂 `/mnt/dbg` → 每 3 s 追加 `dmesg` + `sync`（≤400 轮，独立于正常启动流程、switch_root 后 fd 仍有效）。
- 首次成功：`logs/m173-test-*/newkernel/blackbox.txt`（74 KB，含 0.0 s 起全量 dmesg）。此前失败（0 字节）是加了 `sync` 前的旧版。

### 2.2 缺模块的因果（运行时 insmod 单模块归因）
- 73h（纯 ramdisk）→ `/sys/class/drm` 仅 `version`；`dmesg`：`pmic_glink.altmode ... failed to acquire mode-switch for port 0` + `af54000.displayport-controller: deferred probe pending` + `disp_cc-sm8750 sync_state() pending due to af54000.displayport-controller`。
- `insmod fsa4480.ko`（13.7 KB，vermagic 匹配）后立即：`/sys/class/drm/` = `card0` / `card0-DP-1` / `card0-DSI-1` / `renderD128`；`dmesg: msm_dpu ae01000.display-controller: bound af54000.displayport-controller`。
- `insmod fastrpc.ko` 后：`/dev/fastrpc-adsp` + `qrtr-lookup` 出现 `400 Snapdragon Sensor Core service`。

### 2.3 对照镜像
- `73i` = 73h + DTB `&mdss_dp0 disabled`（单变量）：`card0-DSI-1=connected`、`greetd started`、`phoc` 在跑 → 证明「DP 阻塞 DRM」；**但用户实机确认屏幕未亮**。
- `73j` = 73h 的 DTB（dp0 enabled）+ ramdisk 内置 `fsa4480`/`fastrpc` + `/init` 加载钩子（`scripts/m1-73-modules-overlay.sh`）：切根正常、模块自动加载（`[m1-73j] loaded fsa4480` / `loaded fastrpc`）、`card0`+`card0-DP-1`+`card0-DSI-1`、`/dev/fastrpc-adsp`+QRTR svc400 传感器；**2/2 命中 Q28 坏发**（`command DMA timeout` / `sending dcs data ff 20 failed` / `Failed to initialize panel`）⇒ 未亮屏。

### 2.4 慢启动
- `Run /init as init process` 时间戳 ~95 s（daily `clean/base` ~5 s）；同 boot 内 `ath12k ... POWER_ON(2) -110` 也落在 95 s。疑阻塞内核 init，**未定位**。

## 3. 产物
- 镜像：`out/boot-elden-m1-73j.img`（功能镜像，零写盘）、`out/boot-elden-m1-73i.img`（dp0 关对照）；均带 `.manifest`。
- 脚本：`scripts/m1-73-modules-overlay.sh`。
- 日志：`logs/m173-test-*/`、`logs/m173i-test-*/`、`logs/m173j-test-*/`。

## 4. 未解 / 下一步
1. **亮屏**：M1-7.3 面板 init 仍随 Q28 概率失败（与 daily 同源）——本树无好发记录。
2. **慢启动**（~95 s）定位。
3. **全功能验收**：音频/马达/触屏/传感器/DP 逐项出证据。
