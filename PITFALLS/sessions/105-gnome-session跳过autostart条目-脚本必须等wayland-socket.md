# #436 gnome-session 见到 X-GNOME-Autostart-Phase 就「不执行」该条目；#437 autostart 早于 wayland socket 必须等

- **日期**：2026-10-27
- **场景**：Debian 根（linux17）上想把 Waydroid session 做成冷起自动（appliance），
  写了 `/etc/xdg/autostart/elden-waydroid.desktop`（`Exec=/usr/local/sbin/waydroid-session.sh`）。
  结果：**greetd 重启 → phosh 起来 → session 一直 STOPPED**，phoc/phosh 进程都在。

## #436 判据链

`journalctl` 里只有这一行（容易被当成无关 warning）：

```
gnome-session-service[…]: App elden-waydroid.desktop sets X-GNOME-Autostart-Phase,
                          but gnome-session no longer manages session services
```

`at-spi-dbus-bus.desktop` / `xdg-user-dirs.desktop` 也打同一行，但它们是**别处**起来的
（at-spi 走 D-Bus 激活），所以不能拿"别的条目也这么打、但它是好的"来反推我们的条目没事。

**结论**：Debian sid 的 gnome-session 把带 `X-GNOME-Autostart-Phase` 的条目当成
"session service" 从而**不再管理/不执行**。删掉 `X-GNOME-Autostart-Phase`
（和同样属于旧机制的 `X-GNOME-Autostart-Delay`）后，同一次 `systemctl restart greetd`
**10 s 内** session 变 RUNNING。

⇒ autostart 条目的判据只能是「**条目本身被执行过**」：脚本里加一行写日志，
或看 `waydroid status`；只看 `desktop-file-validate` 通过、看 unit active 都不算数。

## #437 delay 也没用 ⇒ 启动脚本必须自己等 socket

`X-GNOME-Autostart-Delay` 同属旧机制（一并失效）⇒ 条目可能在 phoc 建 `wayland-0`
**之前**就执行。原脚本"探测不到 socket 就 exit 1"，于是 autostart 永远失败。
改成**等 ≤30 s**（0.5 s 步进）后，无需任何 delay 键就稳：

```sh
i=0
while :; do
	RT=$(pick_runtime_dir) && break
	i=$((i + 1)); [ "$i" -ge 60 ] && { echo "no wayland-0 socket after 30s" >&2; exit 1; }
	sleep 0.5
done
```

## 副产品

`pkgmap.tsv` / `stage.sh` 的门禁之外，这类"用户会话级"自启没有 systemd unit 可查，
所以门槛写在脚本自身：`waydroid-session.sh` 现在自带探测 + 等待 + 明确报错值，
`/etc/xdg/autostart/elden-waydroid.desktop` 只负责 `Exec`，两者都在
`packaging/elden-userland/MANIFEST.tsv` 里带 sha 固定。
