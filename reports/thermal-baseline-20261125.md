# 设备发热基线（2026-11-25 首次受控采样）

> 用户 2026-11-24 报「设备发热大」。本轮先做**受控采样**拿到基线，再给假设与下一步 A/B。
> 设备：TB322FC U2 · vk189（`7.3.1-debug-vk189-suspend-00005`）· Debian trixie · phosh 0.46 ·
> Mesa `rm -f` 不动、`/etc/elden-soft-render` **不存在** ⇒ phoc 走 GL（`GSK_RENDERER=gl`、
> `MESA_EXTENSION_OVERRIDE=-EGL_EXT_image_dma_buf_import_modifiers`，见 `elden-session-user` T19 段）。

## 0. 一页数据

| 场景 | cpuss 温度 | 电池温度 | load | cpu0 频率 |
|---|---|---|---|---|
| 空载（无 GUI 活动，仅 SSH） | **39.9–40.3 °C** | 32.1 °C | 1.1–1.2 | 2.2–3.5 GHz 跳动（`time_in_state` 显示 95% 时间在 556 MHz） |
| Firefox 打开静置 3 min | **39.2–44.2 °C** | 33→34.9 °C（在充电） | 1.05–1.45 | 2.4 GHz 上下 |
| 上一轮「重度交互」（连续截图/注入/换件，11-24 23:2x） | **54–59 °C**（cpuss-0-0 59.2） | 37.9 °C | 1.8 | — |

结论：**空载/轻度使用不烫**（40 °C 级）；上一晚的「烫」出现在我连续注入触摸 + 反复起停 Firefox/
osk-stub 的重度交互窗口（59 °C）。也就是说「发热大」目前是**负载相关**，不是稳定态异常。

## 1. 排除项（本轮已查）

- **调频没坏**：`policy0` gov=schedutil，`time_in_state` 显示 3.33M jiffies 停在 **556800**，
  3532800 只有 10 629 ⇒ 之前看到的「`scaling_cur_freq` = max」是采样瞬间（被 SSH/工具拉起）。
- **无限流/无 trip 触发**：`dmesg | grep -iE 'throttl|cooling|thermal.*trip'` 空。
- **无失控进程**：`ps --sort=-pcpu` 前几名 = 我自己的 `sshd-session`(6.6%)、`kworker/u32:3-ring0`(3.3%)，
  GUI 侧 `phosh` 0.1%、`gnome-control-c` 0.2% ⇒ 桌面空闲时几乎没有常驻热源。
- **电池**：`Charging 19%→…`，`qcom-battmgr-bat` 30.7–34.9 °C；充电中温度上行属正常。

## 2. 仍待查的三条假设（下次按此顺序）

1. **H1 渲染路径放大**（最可能）：T19 组合里 `MESA_EXTENSION_OVERRIDE` 关了 dmabuf modifier
   导入 ⇒ 客户端首帧回拷、滚动/视频会走 CPU 合成（`GSK_RENDERER=gl` 但 import 被禁）。
   A/B：临时 `unset MESA_EXTENSION_OVERRIDE`（重启 phoc 会话）→ 同一页面滚动 2 min，比 cpuss 温度
   与 `load`；副作用是 T19 的撕裂/鬼影会回来，仅作测量。
2. **H2 GPU 频率策略**：查 `/sys/class/devfreq/*/cur_freq` + `gpu_stats` 在视频/滚动下是否长期顶格
   （a830 + Mesa 26 的 ifreq 策略若频繁顶格 ⇒ 热）。
3. **H3 Firefox 的 WebRender 后端**：`about:support` 里 `Compositing`/`WebRender` 是否落在
   software/LLVMpipe；若是，等同于「滚动 = CPU 烧」，与 H1 叠加。

## 3. 采样协议（下次照抄，保证可比）

```sh
# 空载 3 分钟
for i in $(seq 1 18); do
  printf '%s load=%s cpu0=%s ' "$(date +%T)" "$(cut -d' ' -f1 /proc/loadavg)" "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)"
  for z in /sys/class/thermal/thermal_zone*/; do t=$(cat $z/type)
    case $t in cpuss-0-0-thermal|gpuss7-thermal|qcom-battmgr-bat) printf '%s=%s ' "$t" "$(cat $z/temp)";; esac
  done; echo; sleep 10
done
```
判据：同一负载档（`load` 差 <0.3）下比 `cpuss-0-0` 峰值与稳态；**先记 load 再记温度**，否则会把
"我在跑 ssh" 的热算到设备头上。

## 4. 同时记下的两件运维事实

- 2026-11-24 23:33 的「断电」= **干净关机**（`Reached target shutdown.target`），电量当时已低；
  本轮开机时电池 **19%**。⇒ 设备跑长时间 GUI 实验前先确认充电，避免再次中断（本轮开头就是被这个打断的）。
- `gsettings` 写的 `screen-keyboard-enabled=true` **断电后回落到 false**（键盘再次弹不出来）⇒ 已改用
  dconf `system-db` + key lock 钉死（`/etc/dconf/db/local.d/{00-elden-ime,locks/00-elden-ime}` +
  `dconf update`，需 `dconf-cli`）⇒ `gsettings set … false` 现在报「键不可写」。
