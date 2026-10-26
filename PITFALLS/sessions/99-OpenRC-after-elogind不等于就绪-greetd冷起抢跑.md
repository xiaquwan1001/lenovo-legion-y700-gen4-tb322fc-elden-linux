# 99 · OpenRC `after elogind` 不等于「elogind 已就绪」：冷起 greetd 抢跑 → 无桌面

- 日期：2026-10-26（vk163 刷 `boot_b` 后真 POR 实测）
- 现象：真 POR 冷起后 `card0-DSI-1=connected`、模块 65、`wlan0` 在，但**无桌面**；
  `pgrep phoc/phosh` = 0，`/var/log/greetd.log` 连续 `error: check_children: greeter exited without creating a session`
  （12+ 次，超过 `respawn_max=10` 后服务 stopped）；`rc-service greetd restart` 后 **phoc=1 / phosh=1**。
- 根因：`/etc/init.d/greetd` 的 `depend()` 只有 `after seatd elogind` —— **`after` 只定顺序，不保证 elogind 的
  D-Bus/seat 已可用**。POR 时 greetd 先起，`pam_elogind` 建会话失败 ⇒ greeter 立即退出；暖重启时序不同所以没暴露。
- 修法（本次落地）：
  - `start_pre()` 增加就绪等待：`loginctl show-seat seat0` 成功或 30 s 超时（超时只告警）；
  - 同步 `packaging/elden-userland/hooks/greetd.pre`（渲染源）+ `files/etc/init.d/greetd` + `rootfs/persistent-overlay/etc-initd-greetd`；
  - `MANIFEST.tsv` sha/size 同步（否则 `verify.sh` FAIL=1）。
- 判据：真 POR 后 `pgrep -c phoc` ≥1、`pgrep -c phosh` ≥1、`loginctl list-sessions` 有 session。
- 备注：`after` → `need` 也能加，但 OpenRC 的 `need` 仍只保证「started」，不保证 D-Bus ready，
  所以**就绪等待是必需的**，不能只改依赖关键字。
