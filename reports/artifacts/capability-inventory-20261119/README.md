# 2026-11-19 晚 · 重建根能力盘点（U2 HA2EXB0E，在机 = 自建最小 Debian 13 trixie + vk192）

> 取证时间 2026-11-19 晚（会话重启后重跑）。命令全部只读，逐条现跑现记。
> 结论用途：**「重建 ≠ 恢复」的能力缺口清单**，作为今天上机测试的作业面。

## 0. 已达标的（有判据）

| 项 | 判据 | 值 |
|---|---|---|
| 起机/系统 | `ps -p1 -o comm=` / `systemctl is-system-running` | `systemd` / `running`；`systemctl --failed` **空**；46 个 service unit |
| 内核 | `uname -r` | `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`（vk192） |
| 根 | `findmnt /` / `df -h /` | `/dev/sda17` ext4 / **190 GiB（用 5.8 G）** |
| 显示 | `/sys/class/drm/` | `card0` `card0-DP-1` `card0-DSI-1` `card0-Writeback-1` `renderD128` |
| 桌面 | `deploy-desktop-shell.sh --check` | **MISS=0**（greetd+phoc+phosh+osk 三进程，GPU 渲染） |
| 链自检 | `zero-to-desktop-check.sh` | **S5–S12 全 ok** |
| 日用基线 | `mobian-daily-baseline.sh --check` | **MISS=0**（本轮修好：补 6 件 IME 用户态件） |
| WiFi | `nmcli -t -f DEVICE,STATE` + 独立出网 | `wlan0:connected:ustcnet`，`curl --interface wlan0` → **200**（IPv6 出口 `2001:da8:…`） |
| BT | `/sys/class/bluetooth/hci0` + `systemctl is-active bluetooth` | 在 / `active` |
| 睡眠 | `/sys/power/mem_sleep` | `[s2idle] deep`（s2idle 可用，未跑 3/3 回归） |
| 时钟 | `zero-to-desktop-check` S8 | 与主机差 **0 s** |

## 1. 缺口（本轮实测，「重建后没恢复」的用户态能力）

| # | 能力 | 证据 | 判断 |
|---|---|---|---|
| 1 | **音频（G1-4）** | `/proc/asound/cards` **空**；`dmesg`: `snd-sc8280xp sound: ASoC: Parent card not yet available, widget card binding deferred`；tplg 件在（`/lib/firmware/qcom/sm8750` 96 个）；`pipewire`/`wireplumber` 已装（12 包）但 **inactive** | 内核侧 APM/GPR 未就绪 ⇒ 声卡 deferred；用户态 PipeWire 无会话。**待查**：ADSP audio PD / `q6apm` 是否需用户态拉动 |
| 2 | **传感器（G1-34）** | `/dev/fastrpc-adsp` **在**、`remoteproc0/1 = running`；但 **`hexagonrpcd` 未安装**（dpkg 计数 0）、`iio-sensor-proxy` **inactive**、`busctl … HasAccelerometer` 无返回 | 链路只差 **用户态**（hexagonrpcd + iio-sensor-proxy 的 QRTR 400 等待）⇒ 包/服务级修复 |
| 3 | **触觉（G1-12…21）** | `/sys/class/leds/` 只有 `mmc0::` 与 `white:flash`；无 `aw869x` 模块；`elden-hapticd` **inactive** | 模块未载 + hapticd 未部署（同一类「非包/用户态」） |
| 4 | **相机采集栈（G1-5）** | `/dev/video0…16` 在、camss 相关模块 11 个；但 **`cam` 工具无**、`libcamera` 包计数 **0** | 内核出流面在，**采集/预览栈未装** ⇒ camss 30 fps 回归做不了，先装栈 |
| 5 | **Waydroid（G2）** | `waydroid-container` inactive | 未迁移/未启（重建前的主链现在为空） |
| 6 | zram | `zramswap` 可用但未启用（`daily-baseline` 只在缺模块时 mask） | 低优先 |

## 2. 与「丢东西的三个闸」的对应

上表全部属第三闸（**非包状态**，PITFALLS `#689`）：包可以 apt 装回来，但 ① 服务未 enable、② 自研件未部署、③ 配置未写 → 表现为「功能没了但系统看起来正常」。

**结论**：重建后的收尾不能只跑 `deploy-desktop-shell.sh --check`（它只管「桌面壳」），
需要一张**能力清单**（本文件）逐项过；今天的上机测试就按 §1 的 1→5 修。
