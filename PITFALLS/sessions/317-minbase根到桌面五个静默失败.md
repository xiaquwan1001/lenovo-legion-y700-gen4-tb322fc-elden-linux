# #681–#685 minbase 根到桌面的五个静默失败（2026-11-19 实测）

同一台 U2（HA2EXB0E）、同一个 6 GiB minbase 根（Debian 13 trixie），从「只有背光」到「锁屏可用」
一共踩到五个静默失败。它们的共同点：**每一步的失败现象都指向下一层（像内核坏/像显示器坏/像源坏了），
而真因都在上一层**。溯源手册 = `RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md`，驱动脚本 = `scripts/deploy-desktop-shell.sh`。

## #681 minbase 根缺 `udev` ⇒ 模块零自动加载 ⇒ DPU 聚合永不 bind

- 现象：`/sys/class/drm` 只有 `version`、只有背光；`device_component/ae01000.display-controller` = `aggregate not bound`，
  `ae94000/ae96000.dsi` not bound，`af54000.displayport-controller` 在 `devices_deferred`（`aux_bridge: failed to acquire drm_bridge`）。
- 真因：`systemd-udevd` 不存在 ⇒ 没有任何模块被 modalias 自动加载 ⇒ fastrpc/ath12k/音频链全缺 ⇒
  DP 组件一直 defer，把 DPU master 拖死。
- 判据：`systemctl is-active systemd-udevd` = active；`apt install udev` 后 `modprobe fastprc`… 逐个到齐；
  `dmesg | grep -c 'bound ae94000.dsi'` ≥ 1、`/dev/dri/card0` + `/dev/fb0` 在。
- 处置：`apt install udev && systemctl enable --now systemd-udevd`（minbase 档必须进包清单）。

## #682 phosh 会话必需 `sm.puri.OSK0`（Debian 包 `phosh-osk-stub`）

- 现象：greetd 反复重启（`check_children: greeter exited without creating a session`），
  `gnome-session-failed --allow-logout` 常驻，截图 = 黑底 + 一个转圈。
- 真因：`/usr/share/gnome-session/sessions/phosh.session` 的 `RequiredComponents` 里有 `sm.puri.OSK0`，
  没装 `phosh-osk-stub`（或 squeekboard）时 gnome-session 直接判会话失败。
- 判据：`journalctl -b _SYSTEMD_SESSION=<n>` 里 `WARNING: Unable to find required component 'sm.puri.OSK0'`；
  装包后 `ps -eo comm | grep phosh-osk-stub` 有进程、`phosh` 起来。
- 处置：`apt install phosh-osk-stub`（`--no-install-recommends` 装 phosh 不会带上它）。

## #683 trixie 自带 Mesa 25.0.7 的 freedreno 不认 Adreno 830

- 现象：`journalctl -t phoc` = `MESA: error: fd_pipe_new2:49: unsupported GPU id 0x0 / chip id 0xe844050000`
  + `libEGL warning: egl: failed to create dri2 screen`；phoc 起即退，greetd 5 次后 `start-limit-hit`。
- 根因：Adreno 830 = a8xx，freedreno 的 a8xx 支持在 Mesa 25.1+ 才有；trixie 是 25.0.7。
- 两条处置（都实测过）：
  1. `touch /etc/elden-soft-render` ⇒ phoc 走 **pixman 软合成** + `GSK_RENDERER=cairo`：桌面起得来，**但帧率低**
     （1904×3040 ≈ 5.8 Mpixel 全 CPU 拷贝，用户当场反馈「帧率很低」）；
  2. **推荐**：`trixie-backports` 的 **Mesa 26.1.6** ⇒ `eglinfo` = `Adreno (TM) 830` / `OpenGL ES 3.2`，
     phoc 打开 `renderD128`，`glmark2-es2-wayland -b :duration=4 build` = **Score 2594**。
- 判据：`ls -l /proc/$(pidof phoc)/fd | grep -c renderD128` ≥ 1（软合成时为 0）。

## #684 RTC 只读 + 冷起给「镜像构建日」（2026-04-13，不是 1970）

- 现象：冷起 `date -u` = 2026-04-13；apt 报 `certificate verify failed`（看起来像镜像源坏了）。
- 根因：PMIC RTC 对我们只读（`hwclock -w` → ENODEV）；镜像里的文件时间/内核构建日是 2026-04-13，
  所以「日期阈值判 1970」那类判据**永远不成立**。
- 处置（`time-sync.sh` 三处修）：
  ① 先 `systemctl stop chronyd`（否则 `chronyd -q` 报 `Another chronyd may already be running`、一步不跳）；
  ② 重试 12×20 s，**判据用 `chronyd -q` 退出码**，不用日期阈值；
  ③ 全失败退 HTTP `Date:` 头（`mirrors.ustc.edu.cn`）。
  + `flock /run/time-sync.lock` 串行化（`/init` 冷起一次 + 路由就位补跑一次）；末尾 `systemctl start chronyd` 交回服务。
- 判据：`date -u` = 现时；`chronyc tracking` stratum > 0；冷起模拟（删路由 + 回拨时钟 + 重启路由服务）25 s 内自愈。

## #685 usb0 只有地址、没有默认网关（主机侧地址还会随 gadget 重建消失）

- 现象：`ping 192.168.7.3` 通、`curl` 全 `Network is unreachable`；`resolvectl query` 报
  `All attempts to contact name servers or networks failed`。
- 根因：设备侧 udhcpd **故意不发默认网关**（避免宿主上网流量走进平板）；主机侧 `ip addr add 192.168.7.3/24`
  会在每次设备重启（gadget 重建）后消失；minbase 的 `systemd-resolved` 只有 stub、没有上游。
- 处置：设备侧 `usb0-host-route.service`（**常驻自愈循环**，15 s 一轮：缺默认路由 + 宿主 ping 通 ⇒ `ip route replace`；
  路由一到位就顺手补跑 `time-sync.sh`）+ `/etc/systemd/resolved.conf.d/99-usb-dns.conf`。
  一次性 oneshot 不够（实测：宿主地址晚到 20 s 就永久没路由）。
- 判据：`ip route show default` 有 `via 192.168.7.3`；设备 `curl -s -o /dev/null -w '%{http_code}' http://deb.debian.org/debian/` = 200。
