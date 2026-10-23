# #369 「显示栈已坏」的 boot 上 `phoc` DBus 全超时 + `reboot2 bootloader` 静默无效（device_shutdown 挂住）

## 症状（2026-10-23 实测，vk64 RAM 内核）

一类 boot 上：

- `phoc` 进程在（`Sl+`，`wchan=futex_do_wait`），但 `gdbus ... GetActive` **一律 `Error: Timeout was reached`**；
- `dmesg | grep -cE 'vblank timeout|reset failure'` = **507**（另一发 = 15，同族）；
- `echo off > /sys/class/drm/card0/card0-DSI-1/dpms` ⇒ **`Permission denied`**（非 DRM master，写不进去）；
- `reboot2 bootloader` **返回后设备不重启**：`boot_id` 不变、`uptime` 继续涨、SSH 仍可用 ⇒ reboot 路径卡在某设备 `.shutdown()`；
- **逃生通道 = SysRq-b**：`sync; echo b > /proc/sysrq-trigger` → 立刻复位并回到 fastboot（实测 25 s 内 `fastboot devices` 出现 `HA2EXB0E`）。

## 判别（不要和 Q24 混）

| 现象 | 含义 |
|---|---|
| `dpms` 读数**空** + `boot_id` 变 | 真死亡（Q24 硬复位） |
| `dpms` 恒 `On` + `SetActive(true)` 无效果 + **DBus 超时 / dpu_err 高** | **显示栈已坏 + 会话卡死**（Q28 坏发的一种），熄屏根本发不出去 |
| `dpms` 恒 `On` + DBus 正常 + dpu_err=0 | 真 no-op（少见，需重试） |

⇒ 任何「熄屏实验」在触发前必须先过**显示健康门**：`dmesg` 的 dpu 错误计数 + 一次 `GetActive` 探活。

## 规则

- 熄屏触发前查 `dpu_err`（>50 直接判该 boot 作废）与 `GetActive` 是否响应；二者任一异常 = 该 boot 作废重开，**不要**记成 `INVALID-NO-BLANK`。
- `reboot2 bootloader` 后必须**在 90 s 内看到 fastboot**；看不到且 SSH 还活着 = reboot 挂住，改用 `SysRq-b`。
- `SysRq-b` 是**无 sync 的硬复位**（已先 `sync`），仅用于「reboot 路径挂住」的逃生；它会丢掉未落盘的页缓存。

## 相关

- `scripts/n5b-vk64-death-rate.sh`（已加显示健康门 + `force_reboot_vk64`，本轮先手测出 SysRq-b 通道）
- `PITFALLS #368`（reboot2 早期下发把 USB 打没）、`#150–#152`（SysRq-b/reboot 纪律）、`reports/q24-n5b-20261023.md`
