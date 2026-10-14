## 二十九、Waydroid 马达透传（vibrator HAL → aw86927 FF）（2026-10-13 实测）

232. **★容器 vibrator HAL 是「写文件成功 = 成功」——主线没这两个节点时它静默失败，绝不能拿「HAL 已注册 / dumpsys 无报错」当可用判据。**
    - 事实：`hardware/waydroid/vibrator/Vibrator.cpp`（= 镜像里 `/vendor/bin/hw/android.hardware.vibrator@1.0-service.waydroid`）的 `on()/off()` 就是 `std::ofstream(path) << value` 写 4 个 AOSP LED-trigger/timed_output 路径；`set()` **不检查 open/write 是否成功**，`on()` 无条件返回 `Status::OK`。
    - 主线 elden 既无 `leds` class 的 `vibrator`（`/sys/class/leds/` 只有 `mmc0::`）也无 `timed_output` class ⇒ 写入全失败；Android 侧却一切正常：`lshal` 有 `android.hardware.vibrator@1.0::IVibrator/default`、`dumpsys vibrator_manager` 无报错、`cmd vibrator_manager list` 出 id 0，**但马达不动**。
    - 规约：判「透传通了」只认内核证据（`kprobe aw86927_haptics_play` 命中）+ 人手确认；HAL 侧任何 OK/无报错都不算。与相机 #157–#159 / G1-34 同型「静默失败」教训。
    - 证据：`reports/waydroid-haptics-20261013.md` §1。

233. **容器内 `/sys` 是只读 sysfs：不能 mkdir ⇒ 只能 bind 到「已存在」的目录；`/sys/class/leds`（整类目录）是唯一可行靶点。**
    - `lxc.mount.entry = /run/<dir>/leds sys/class/leds none bind,create=dir,optional 0 0` 实测有效（容器内 `/sys/class/leds/vibrator/{activate,duration,state}` 可见且可写）；宿主侧 `mount --bind /tmp/x /sys/class/leds` 也验证过可行。
    - 反例：`/sys/devices/virtual/timed_output/vibrator/enable` 的父目录在 sysfs 里不存在、无法创建 ⇒ 那条路径永远失败（HAL 不检查，无实际影响）。
    - 取舍：容器里看不到宿主真实 leds class（本机只有 `mmc0::`，无影响）；`optional` 必须有，否则宿主目录缺失会让 LXC 起不来。
    - 另一条腿：容器 `/run` 是自建 tmpfs，宿主路径在容器内不存在 ⇒ 想事后 `nsenter -m` 补挂，需要再加一条把宿主目录绑到容器 `/run/...` 的 entry（本仓两条都加了）。

234. **kprobe 取证前必须确认 `tracing_on=1`：本机默认是 0，否则命中恒 0，会把「路径根本没走到」误判成「驱动问题」。**
    - 本轮首次取证（`vibrate 200` 明明打出 `rumble ON`）就是 `tracing_on=0` + 事件 enable ⇒ `grep -c` = 0；置 1 后同命令立刻 4 命中（`aw86927_haptics_play` + `_play_work`，一开一停）。
    - 另外 `aw86927_play_sine` **不在** `available_filter_functions` 里（kprobe 挂它会 `Invalid argument`）——挂点先用 `grep available_filter_functions` 核对。

235. **覆盖「正在运行」的设备侧二进制：`scp` 报 `dest open "/usr/local/bin/...": Failure`（ETXTBSY）。**
    - 顺序必须是 `停服务 → scp → 起服务`；本轮先 scp 后停服务，白折腾一轮。`scripts/waydroid-haptics-setup.sh` 已按此序。

236. **Waydroid「伪重启」：`wd-ctl.sh stop` 不停 session/container 两个 python daemon ⇒ 残留 session 让容器再也拉不起来。**
    - 症状链：`wd-ctl.sh stop`（只 `pkill 'waydroid container start'` + `lxc-stop`）→ 下次 `wd-ctl.sh session` 输出 **`Session is already running`**、`lxc-info` 恒 `STOPPED`，而 `waydroid status` 仍显示旧状态 ⇒ 看起来像「加了 `lxc.mount.entry` 把容器弄坏了」，其实是残留 daemon。
    - 全量重启（脚本已实现）：`for p in $(pgrep -f 'usr/bin/waydroi[d]'); do kill -9 $p; done`（**`[d]` 防 pgrep 命中自己**，见技能 `pkill-self-match`）→ `lxc-stop -k` → `setsid nohup waydroid container start &` → `wd-ctl.sh session` → 等 25 s。

237. **桥必须自清 `activate`：否则 daemon 自触发环（每 duration 一次无限震动）。**
    - 机制：HAL 只在 on/off 时写 `activate=1/0`；daemon 若因自己的安全超时停振却不把文件写回 0，下一轮 poll 又见 1 ⇒ 重新起振，日志呈「每秒一次 400 ms」。本轮实测到该环（kprobe 命中持续增长）才发现。
    - 修法：`AUTO-OFF` 分支写 `0` 回 `activate`（Android 从不读回这三个文件，写安全）；判据 = 同一触发后 `+2 s` 与 `+6 s` 的命中数相等。

238. **已达成的能力边界（HIDL 1.0 vibrator 的固有限制，别当成桥的 bug）：无幅度控制、`cmd vibrator_manager cancel` 不能提前停。**（**2026-10-13 二期已解决**：自编 AIDL V2 HAL 提供 `CAP_AMPLITUDE_CONTROL`、`off()` 在 `cancel` 时立即下发 —— 见 #239–#243 与 `../../TASKS/README.md` C10 二期）
    - → [二期已解决：自编 AIDL V2 HAL（#239–#243，TASKS C10）；HIDL 1.0 固有限制（无幅度控制、cancel 不能提前停）仅在回退 HIDL 时仍成立。证据 `reports/waydroid-haptics-20261013.md` §5]
---

