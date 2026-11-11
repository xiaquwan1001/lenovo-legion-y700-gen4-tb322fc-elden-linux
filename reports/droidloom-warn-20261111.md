# droidloom 告警收尾：doctor 全表 + invalid Android frame 定位（2026-11-11）

> 设备 = 在机 U（192.168.7.1，vk184-00002，boot 0 自 11-05 起）。全程只读 + 一次 adb 测试通知（无写盘、无账号、无重启）。
> 复现入口：`scripts/device-lock.sh -w 600 bash -c 'ssh root@192.168.7.1 "<cmd>"'`。
> 本轮原始输出快照：`/tmp/dl-doctor.txt`（主机侧，未入库）。

## 0. 一页结论

1. **doctor：13 PASS / 1 WARN / 0 BLOCK，`READY (0 blockers)`**（实测）。唯一 WARN = `Host LSM hardening`（非必需项，不阻塞）。
2. **「通知通道坏」现状 = 已自愈（实测）**：2026-11-11 15:38 / 15:41 两次 cell 会话 `Android connected` 后 0 次 `invalid Android frame`；16:19 adb 实发测试通知，宿主侧接收并落盘 `notifications.state`（mtime 16:19 实测）⇒ 通道端到端可用。紧循环只发生在 **12:40–13:53 那一次 cell 会话**（1919 次失败 / 2 s 周期，**≈0.5 次/秒，此前「1 次/秒」口径应更正**）。
3. **ABI 错配假设被实测否证**：Android 侧 logcat（`DroidloomNotifications` tag，pid 712）宣告 `DROIDLOOM_NOTIFICATIONS_ABI=3;`，与宿主二进制 strings 结果一致（均 3）。`reports/droidloom-notifications-abi-20261111.md` 的假设 A（宿主 3 / image 2）**不成立**。
4. **定性档位 = 「有源码可改（但需重编 + 先抓帧）」**：失败点在宿主侧 `Peer::ingest()`，错误被 `Err(_)` 吞掉（rev25 `notifications/mod.rs:531-533`），二进制内无详细日志开关 ⇒ 不重编无法看到具体被拒帧。当前通知内容可过校验，循环诱因 = 当时存在的某条特定通知（内容级，非协议级）。**非「无源码可对」**。

## 1. doctor 全表（实测，2026-11-11 16:0x，root 直跑）

```
Result: READY (0 blockers)
[PASS] Linux shared-kernel host / Architecture-matched native execution (aarch64)
[PASS] Required Linux namespaces (user,pid,mnt,ipc,uts,net,cgroup)
[PASS] Private Binder filesystem (CONFIG_ANDROID_BINDERFS + /proc/filesystems)
[PASS] Delegated cgroup v2 resource control (cpuset cpu io memory hugetlb pids 全齐)
[PASS] Cgroup v2 freezer
[PASS] Seccomp filtering (CONFIG_SECCOMP_FILTER + 8 actions)
[PASS] Dedicated Android UID/GID mapping range (100000 IDs 连续段)
[PASS] Private veth and nftables networking (CONFIG_VETH=module, CONFIG_NF_TABLES=y)
[PASS] DRM render-only GPU access (/dev/dri/renderD128, msm_dpu)
[PASS] DMA-BUF and sync_file primitives
[PASS] DMA-BUF heaps (CONFIG_DMABUF_HEAPS=y；注：提示 /dev/dma_heap exists: false 但仍 PASS——上游以 config+runtime 证据判定)
[PASS] Synthetic cell filesystem support
[WARN] Host LSM hardening — active LSMs: capability
```

统计：**PASS 13 / WARN 1 / BLOCK 0**。doctor 本体在 `/usr/bin/droidloom-doctor`，root 直跑成功，无需 `/opt/dl-test` 软链重试。

## 2. WARN 的源码出处（静态）

`Host LSM hardening` = `runtime/droidloom-doctor/src/lib.rs:767-791`（`fn check_lsm`）：
- 检查内容：读 `/sys/kernel/security/lsm` 或 `/proc/sys/kernel/lsm`，要求激活列表里含 `apparmor|selinux|landlock|bpf` 之一（`:771-775`）。
- 设备实测 `active LSMs: capability` ⇒ 不含任何上述 LSM ⇒ Warning。`:777` 第 4 参 `false` = **非 required**，故只警不 block。
- Remedy 原文：「Treat compromise of the full Android cell as outside the primary boundary until a host LSM policy …」。**定性：已知且接受的风险项，无需行动**（主线内核启用 AppArmor/SELinux 是另一个工程，不属于本 lane）。

## 3. invalid Android frame：定位与频率（实测）

### 3.1 频率与区间

| 量 | 值 | 证据 |
|---|---|---|
| 总次数（本 journal 保留窗） | invalid **1919** / connected **1921**（C12 行记 1924，journal 滚动导致 ±3） | `journalctl --no-pager \| grep -c` |
| 时间区间 | 12:49:05 – 13:53:06，连续 **64 min** | journalctl 首尾时间戳 |
| 周期 | **严格 2 s 一对**（connected→invalid 相邻秒） | 12:49:05/07/09/…、13:52:56…06 连续样本 |
| 折算频率 | **≈0.5 次/s 失败 + 0.5 次/s 重连**（Android 侧重连间隔 2000 ms，`NotificationBridge.java:127`） | 同上 |
| 15:00 之后 | invalid = **0**；两次 cell（15:38 pid 18685、15:41 pid 22237）均 connected 后静默 | `journalctl --since 15:00` |
| boot -1 / boot 0 其余时段 | invalid = 0 | `journalctl -b -1`、`-b 0` |

### 3.2 「宿主侧 vs Android 侧」判别（本轮新增实测）

| 检查 | 结果 | 定性 |
|---|---|---|
| 运行中二进制身份 | `/proc/22237/exe → /opt/dl-test/usr/bin/droidloom-wayland`；`/usr/bin/droidloom-wayland` 为其软链（12:41 建） | 实测 |
| 宿主 ABI 常量 | strings 唯一一处 `DROIDLOOM_NOTIFICATIONS_ABI=3;`（clipboard/direct_input/host_channels 均 `=1`） | 实测 |
| **Android 侧 ABI 常量** | **logcat `DroidloomNotifications: DROIDLOOM_NOTIFICATIONS_ABI=3;`（pid 712，15:41）** —— 前报告「logcat 没有 NotificationBridge」是因为当时 cell 未起；现 image 侧 SystemUI 确认同为 3 | 实测 |
| image/runtime 是否混装 | `system.img` 与 `droidloom-wayland` mtime 同为 2026-11-05 19:47:18，今天未换 | 实测 |
| 错误文案判别力 | `invalid Android frame; disconnected` 是 ingest **任何** Err 的统一出口（rev25 `mod.rs:531-533` `Err(_) =>`），二进制里另有 `invalid notification frame/sequence/snapshot`、`end outside snapshot` 等细分串但**均不上日志** ⇒ 文案无判别力 | 静态（rev25 源码）+ 实测（设备二进制含同组串） |
| 详细日志开关 | 二进制 strings 无 `RUST_LOG`/`env_logger`/自定义 verbose 开关；源码无 `tracing` 依赖 ⇒ **无现有手段打印被拒帧** | 静态 |

### 3.3 决定性实测：通道现在是好的

16:19 执行 `adb -s 10.177.0.2:5555 shell cmd notification post -S bigtext -t DLTest tag123 …`（rc=0，Android 侧回显 posting）：
- 之后 3 min 内 `invalid Android frame` = 0；
- `/run/user/1001/droidloom/notifications.state` **mtime 变为 16:19**，内容 `{"bus_id":"…","owner":":1.27","records":{}}` —— 宿主收到 post（及随后的 remove/自动消失）并成功落盘 ⇒ hello + snapshot 双向均通过。

### 3.4 根因边界（结论）

- **排除**：ABI 数字错配（两端实测均 3）；帧格式/长度前缀/字段命名（rev25 静态比对已证同构，且现网通知实测通过）；包混装（mtime 同批）。
- **剩余唯一解释（推断，可一次实验定死）**：12:40–13:53 会话里存在某条**特定内容的通知**（如某字段超限/`deny_unknown_fields` 命中未知字段/icon 尺寸不符），SystemUI 每次重连都重发 initial snapshot → 首个坏帧即断 → 2 s 循环；该通知在 13:53 后消失（超时/被移除/cell 重启后不复存在），之后所有通知（含实测样本）都能过。
- **判据（哪一步能定死）**：抓一次坏帧即可。两条路：
  1. `strace -f -s 4096 -e read,write -p <droidloom-wayland pid>` 挂在 `notifications.sock` 的 fd 上，等循环复现，直接看被拒帧 JSON；
  2. 重编时把 `mod.rs:531-533` 的 `Err(_)` 改为 `Err(e) => eprintln!("…: {e}")`（一行改动，错误串已在二进制里：`invalid notification frame/sequence/snapshot`、`end outside snapshot`、`notification delta before snapshot or over capacity`）。
  复现条件 = 重建当时那条通知（未知具体应用；journal 与 logcat 缓冲均已滚掉，无法回溯 12:49 时的通知清单）。

## 4. 三档定性

| 档 | 判定 |
|---|---|
| **有源码可改** ← **选这档（有保留）** | 依据：失败点在宿主 `ingest()` 的某个 Err 分支，细分错误串已存在于二进制；改一行日志即可定位，定位后大概率是一行校验/字段适配修复。**保留**：`build/droidloom` 快照是 rev25，设备是 rev30，改前须先取 rev30 源码（否则改错基线）。 |
| 只能等上游 | 不选：非上游缺陷证据不足（现网通道工作正常；即使真是 rev30 内部校验 bug，也属「可报告+可自修」）。 |
| 需自建 image | 不选：Android 侧帧内容与 host 同版自洽（两侧均 3 + 实测通过），无 image 侧证据。 |

**修复落地路径（方案，本轮未执行——禁重编）**：
1. 取上游 rev30 源码（GitHub tag/源码包），落到 `build/droidloom/`（按仓库规矩另立快照，勿覆盖 rev25 对照）；
2. `notifications/mod.rs` ingest 错误改为带错误串的日志（一行）；
3. `cargo build -p droidloom-wayland`（aarch64 target）替换 `/opt/dl-test/usr/bin/droidloom-wayland`（有回退：原文件 mtime 11-05，先留副本）；
4. 复现循环：需要一条会触发坏帧的通知；若无法复现，则保留一行日志改动等它自然复现（成本≈0，不刷屏）。

## 5. 降级方案（消除 1 Hz 循环污染）——本轮不需要，备案

**前提已消失**：循环只存在于 12:40–13:53 会话；当前通道工作正常 ⇒ **不执行降级**。若未来复发：
- 现状：**没有任何运行时开关**可关通知桥（静态：`main.rs:3065-3068` 无条件 `Bridge::start()`；`Bridge::start`（`mod.rs:33-80`）不接受 env/配置；二进制无 `DROIDLOOM_*DISABLE*` 串）。
- 可选降级（按侵入度）：
  a. **二进制补丁**（不重编）：把 `main.rs:3065` 调用点 `notifications::Bridge::start(...)` 的 call NOP 掉，或把 `mod.rs:531-533` 的 `eprintln!` 改成空——objdump 定位 `Droidloom notifications: invalid Android frame; disconnected` 字符串 xref 即可得补丁偏移；验证 = journal 0 次该文案 + 无其它回归；回退 = 换回原二进制。
  b. **重编关闭**：rev30 源码里给 `Bridge::start` 加 env 门（如 `DROIDLOOM_NOTIFICATIONS=0`）。
- 验证命令：`journalctl -f | grep -c 'invalid Android frame'`（应恒 0）；`droidloomctl applications` 与窗口 L4 判据不受影响（通知桥独立于 applications/clipboard 通道）。
- 回退：还原二进制/配置即可，无持久状态（socket 与 state 文件每次 start 重建）。

## 6. 未完成项 + ★SSOT 待并入

- ★ **TASKS/README C12 行③「通知通道仍坏」表述过时**：应更新为「2026-11-11 15:38 起 0 失败，实测 adb 通知端到端可达宿主；12:40–13:53 的 1919 次 2 s 循环为内容级瞬态（待 rev30 源码 + 一行日志定死）」，频率口径 1 次/s → **0.5 次/s（2 s 周期）**。
- ★ **reports/droidloom-notifications-abi-20261111.md 假设 A/B/C 判定更新**：A（3/2 错配）被 logcat 实测否证；「logcat 无 NotificationBridge」的前提失效（当时 cell 未起）。
- 未做：rev30 源码获取与重编（禁令内）；坏帧实抓（无法复现触发通知）；`/dev/dma_heap exists: false` 是否影响 media 解码（droidloomd 已另报 "no media DMA heap, apps cannot decode media"，属另一 lane）。
- PITFALLS 候补：**droidloom 通道疑难要先确认 cell 真的在跑**——本轮 3 个「查无异常」的旧前提都源于 cell 未起时的取证（logcat 空、system.img 无 ABI 串）。
