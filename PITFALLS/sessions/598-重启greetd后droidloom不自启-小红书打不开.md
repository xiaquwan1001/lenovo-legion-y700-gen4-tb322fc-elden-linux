# #759 换 phoc/重启 greetd 后 `droidloom.service` 不会自己回来（症状 = 小红书打不开、catalog 每 2 s 报 `No such file or directory`）

- 日期：2026-11-28（phoc 0.46+edge-swipe 上机时踩到；`reports/phoc-046-edge-swipe-deploy-20261128.md` §3）
- 现象：换完 phoc 重启 greetd，桌面正常、`systemctl --failed` 干净，但 **Android 应用全打不开**；
  `journalctl` 里 `droidloom-applications` 每 2 s 一条
  `droidloom-applications: subscription deferred: connect catalog subscription: No such file or directory (os error 2)`。
  第一反应容易误判成「新 phoc 把 droidloom 弄坏了」——**无关**：phoc 只是把会话撕掉了。
- 根因（可复核）：`/usr/lib/systemd/user/droidloom.service` 同时是
  `PartOf=graphical-session.target` 和 `WantedBy=graphical-session.target`。
  `restart greetd` ⇒ 旧会话结束 ⇒ 15:13:56 `droidloom.service: Main process exited, code=exited, status=1/FAILURE` 后被 stop；
  新会话起来后 **`graphical-session.target` 仍是 `inactive`（`is-enabled` = `static`）**，
  没有任何组件再 `start` 它 ⇒ `WantedBy` 不会被重新拉取，`Restart=on-failure` 也不生效（它是被显式 stop 的）。
- 现修（一步）：`systemctl --user start droidloom.service`（约 20–60 s 到 `Android is ready`）；
  验：`droidloomctl status` ⇒ `cell u1001 is running … Android is ready`、`adb devices` 有 `10.177.0.2:5555`。
- 纪律：**换 phoc/phosh 或任何 `systemctl restart greetd` 之后，必须把 droidloom 一起拉起来再判功能**；
  「Android 应用打不开」先查 `ps -eo comm | grep -c droidloom` 与 `systemctl --user is-active droidloom.service`，
  不要先怀疑刚换的合成器。
- 缺口（待补，已登记 `TASKS/NEXT.md` T46）：让它在会话重建后自动回来（候选：phosh 的 xdg-autostart 里
  `systemctl --user start graphical-session.target`，或给 droidloom 加 `Wants=`/`BindsTo=` 到 phosh 会话目标）。
- 出处：`reports/phoc-046-edge-swipe-deploy-20261128.md` §3。
