---
name: "wifi-link-flap-triage"
description: "y700-elden 设备上排查 WiFi 慢/周期性掉线/bmiss/flapping（beacon rx 速率、roam reason、被动扫描、two-manager）、以及用 reboot2+fastboot 做零写盘 A/B 启动的方法。"
version: 1
created: "2026-10-06"
updated: "2026-10-06"
---
## When to Use
当用户报「WiFi 到可用很慢」「WiFi 每隔十几秒掉一次」「nmcli 一直 getting IP configuration」「ath12k failed to flush transmit queue」「Connection to AP 00:00:00:00:00:00 lost」，或需要在 TB322FC 上做内核/固件的零写盘对照启动时使用。不适用于：纯 DHCP/代理配置问题、Waydroid 容器网络。

## Procedure
1. 先用 `iw dev wlan0 station dump` 的 `beacon rx` / `connected time` 做第一现场指标（10 s 一次采样），**不要**用 `Connection to AP ... lost` 或 `nmcli` 状态当主指标（前者混入两条拆链路径，后者是下游症状）。判读：≈0.5/s = 固件每 2 s 醒一次（时序不对）；5-10/s = 正常（AP beacon int 100 TU + dtim 2）。
2. 开 `echo 2 > /sys/module/ath12k/parameters/debug_mask` 看固件 roam 事件：`wmi roam event vdev 0 reason 2` = WMI_ROAM_REASON_BEACON_MISS；同时看 `failed to flush transmit queue`（vdev teardown）。**debug_mask 会让每个信道 7-8 行 scan 事件，一次扫描上百行，累计 `dmesg | grep -c` 差分会被 ring buffer 回卷冲成负数** —— 高频指标改用时间戳过滤或 `iw` 计数器。
3. 判定「AP 是否在发 beacon」：黑屏窗口内跑 `iw dev wlan0 scan passive`（只听 beacon，不发 probe request），并加一次恢复后的对照。命中 AP ⇒ AP 无辜，问题在客户端已关联 STA 路径。（主动扫描会收到 probe response，会伪造「AP 正常」。）
4. 判定是否为自拆链：看是否打印 `Connection to AP ... lost`（= ath12k 3 s `connection_loss_work`）或静默重关联（= mac80211 AP-probe 超时）。两条路径可独立关闭（见 patches/0012），但用户可见掉线节奏可能不变。
5. 零写盘 A/B 启动（agent 自己做）：`ssh root@192.168.7.1 'sync; setsid /usr/local/sbin/reboot2 bootloader'` → 等 ~20 s → `fastboot devices`（应见 HA2EXB0E）→ `fastboot boot out/boot-elden-<candidate>.img`。别用 `/sbin/reboot bootloader`（被包装成 busybox reboot -f，不进 fastboot）。
6. 构建候选镜像保持单一变量：`git worktree add --detach ~/wt-x <base-commit>` + 设备 `/proc/config.gz` 作配置 + `CONFIG_LOCALVERSION_AUTO=n` + `make LOCALVERSION=-vk47clean-gbd114ca335e1`（UTS 逐字一致 ⇒ `/lib/modules` 的 vermagic 兼容）；DTB/ramdisk 用 `RAMDISK_KIND=full` 载具保持不变；打包后校验 manifest 的 `kernel_uts`。
7. 运行期区分候选（`uname -r` 各候选相同）：用 `uname -v` 的构建时间戳（`#N SMP PREEMPT <时间>`）。
8. 把受控侧脚本 scp 到设备 `/tmp` 再 `sh /tmp/x.sh`；注意 `/tmp` 是 tmpfs，**每次启动清空**，需重新拷贝。

## Pitfalls
- 只看 `lost` 计数会误判「已修复」：关掉 ath12k 强制拆链后 mac80211 的 probe 超时照旧拆链，且不留日志。
- 用「掉线次数」做 PS/扫描假设的 A/B 会返工：PS 的正确判据是 `beacon rx` 速率（关联前就把 `802-11-wireless.powersave` 设成 2 再重启）。
- 开机后前 ~100 s 才有黑屏，且 ~130 s 自愈 ⇒ 测试窗口只有首 ~130 s，必须在 `fastboot boot` 后立刻采样，否则拿到的是「已经好了」的假象。
- 别在稳定链路上判定「扫描是元凶」：实测单次手动扫描不触发 bmiss/掉线（90 s 无新关联）。
- `out/` 有其它写者：`out/boot-elden.img` 等别名文件可能被别的会话改；打包前备份、打包后按原样恢复。
- 换 PEACH 固件变体有风险：stock 非-20 变体（amss.bin 7041088）会让 MHI POWER_ON 直接 -110、19 次 bind 全失败；换前先备份到设备 `/root/fw-backup/` 并在 usb0 可用前提下操作。
- 设备 `/sbin/reboot` 是 `busybox reboot -f` 包装，`reboot bootloader` 不会进 fastboot。

## Verification
1. 首窗口（关联后 0-130 s）`beacon rx` 在 ~10 s 内达到 ≥5/s，且 0 次 `Connection to AP 00:00` / `failed to flush transmit`。
2. `nmcli -f GENERAL.STATE,IP4.ADDRESS device show wlan0` 在 ~40 s 内 connected + 有 IPv4（基线要 130-150 s）。
3. 设备侧管理器唯一：`ps -eo args | grep -c '[w]pa_supplicant'` = 1、`[u]dhcpc` = 0。
4. 候选内核启动确认：`uname -v` 等于 manifest 构建时记录的 `#N SMP PREEMPT <时间>`。
5. 无回归：相机等 `=m` 模块能加载（vermagic 未变），Phosh 存活。