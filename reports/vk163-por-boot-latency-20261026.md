# vk163 真 POR 冷起：启动时延拆解与两处修复（2026-10-26）

> 设备 HA2EXB0E，`boot_b` = vk163（签后 sha `65ae2ff0…`），根 `f2fs linux18`。
> 触发：用户报告「启动前三十秒刷屏、卡了一会」。以下为真 POR / 暖复位多种子的实测拆解。

## 0. 结论（数字）

| 版本 | dbus 启动 | elogind | phoc/phosh | 备注 |
|---|---|---|---|---|
| 修复前（真 POR） | 20 s | **50 s** | 无（greetd 失败） | 5425 行 `wcd939x` ASoC 错误刷屏；`bt-alias` oneshot `sleep 30` 阻塞 default runlevel |
| 修复后（暖复位复核） | 26 s | **27 s** | **29 / 30 s** | `phoc=1 / phosh=1`、`loginctl` 有 `c1 seat0 tty7 active` |

- 5425 行 `wcd939x_codec ... ASoC error (-16)` 集中在 **t=9.5 → 29.3 s**，每行 ~3.7 ms ⇒ 约 **20 s** 是驱动读寄存器重试本身，不是 tty0 打印（改 console loglevel 不改变耗时，只消除刷屏）。
- 启动链上另一处 **30 s** = `bt-alias` oneshot 同步 `sleep 30`，它排在 default runlevel，阻塞后续 elogind/greetd。

## 1. 已修

1. **`bt-alias` 不再阻塞 runlevel**（`packaging/elden-userland/extra/usr/local/sbin/elden-bt-alias.sh`）：
   等待 `hci0 UP RUNNING`（≤60 s）+ `bluetoothctl` 全部放后台子 shell，oneshot 立即 `exit 0`。
   实测后台子 shell 在 oneshot 退出后存活（`bluetoothctl system-alias elden` 正常执行）。
2. **console 刷屏**：`/init` 的 `echo 8 > printk` 改为 `elden_console_loglevel`（默认 **1**，只 emerg/alert），
   `greetd` 启动后恢复 `7`。dmesg 仍全量保留（5425 行仍在），只是不上 tty0。
   ⚠ 这**不减少** 20 s 耗时，只是把「刷屏」消掉。
3. **greetd 冷起抢跑**：`start_pre` 等 `loginctl show-seat seat0`（≤30 s），见 `PITFALLS #419`。

## 2. 未解（下轮）

- **WCD939X 冷起 5425 行 `-16`（EBUSY）读重试**：寄存器先 `0x3125`，后 `0x3017/0x3018/0x34c5`，任务 T139
  （音频卡初始化上下文）。音频最终可用（`aplay -l` 有 card0），但这段重试吃掉 20 s。
  方向：查 `soc_component_read_no_lock()` 的 EBUSY 来源（regmap 在 runtime-suspend 时读）与调用循环
  （jack/micbias/`wcd939x` component probe）；修好后可再去掉 console 降噪。
- **bluetoothd 冷起偶发 crash**：本次冷起 `bluetooth [crashed]`，`rc-service bluetooth stop/start` 后正常
  （`bluetoothd 5.86`、`hci0` 正常）。怀疑与 dbus 名抢占/启动顺序有关，待复现后加 restart 或调序。

## 3. 复现/测量命令

```bash
# 每个进程相对开机的时间（秒）
up=$(cut -d. -f1 /proc/uptime); hz=$(getconf CLK_TCK)
for p in dbus-daemon elogind greetd phoc phosh; do
  pid=$(pgrep -x $p|head -1); st=$(awk '{print $22}' /proc/$pid/stat); echo "$p $((st/hz))s"
done
dmesg | grep -c wcd939x
cat /proc/sys/kernel/printk     # 期望 boot 早期 1 4 1 7，greetd 后 7 4 1 7
```

## 4. 回退

- `bt-alias`：`/root/bak-20261026/elden-bt-alias.sh`；`/init`：`/root/bak-20261026/init`；
  `greetd initd`：`/root/bak-20261026/greetd-initd`。
- 仓库侧：`packaging/elden-userland/{extra/usr/local/sbin/elden-bt-alias.sh,files/init,files/etc/init.d/greetd,hooks/greetd.pre}` + `initramfs/init` + `rootfs/persistent-overlay/{init,etc-initd-greetd}`。
