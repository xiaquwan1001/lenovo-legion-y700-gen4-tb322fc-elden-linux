## #661 「GitHub release 直连可达」已失效：`--noproxy '*'` 会 60 s 超时；而容器出网前必须先手工起 `host-net-proxy`

判据与处置（2026-11-15 实测，取 SPIC APK 时撞到）：

- **宿主取 GitHub release 走代理，不要 `--noproxy '*' `**：直连实测下行 <1 KB/s、60 s 后 `curl: (28) ... unexpected eof while reading`；
  走 `http://127.0.0.1:7890` 同一文件 **2.25 s / 11 219 447 B / HTTP 200**。
  ⇒ 2026-11-10 报告里的「GitHub 直连可达、走代理会 403」**只在那一时点成立**，已作废（时间序裁决）。
- **`scripts/host-net-proxy.sh` 的 user systemd unit 没装时，容器出网是「假通」**：`waydroid shell -- ping www.gstatic.com` 回 1 包、
  `www.google.com` 还能 302，但 **`playintegrity.googleapis.com` / `android.clients.google.com` / `droidguard.googleapis.com` 全 `000`**，
  GMS 的 DroidGuard 报 `DGFRR ... Connectivity error`。⇒ 这时取 Play Integrity 回包拿到的是**网络失败**，不是 verdict。
  处置：`bash scripts/host-net-proxy.sh` 起，`--check` rc=0 后再测（从容器带 `-x http://192.168.7.9:7897` 应得 404/200 而不是 000）。
- 关联两条同源小坑（本轮同一次操作踩到）：`waydroid app install` 必须**以会话用户 1001 身份**跑（root 跑恒报
  `WayDroid session is stopped`，即使 `waydroid status` 双 RUNNING）；容器截图往外取不能找 `/var/lib/waydroid/data/...`，
  用 `waydroid shell -- screencap -p /data/local/tmp/x.png` + `base64 -w0` 取出。

证据：`reports/c3-spic-verdict-20261115.md` §2/§4。
