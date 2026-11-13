# #652 greetd 重启后会话「不存在」≠ 崩了：是**没解锁**

- 日期：2026-11-13
- 触发场景：为 C-U7 换 `/usr/bin/phoc` 后 `systemctl restart greetd`，立即跑 `wayland-info` 得到 **0 个全局**、`grim` 失败、GTK 起不来（`Gtk couldn't be initialized`）。当轮我据此写了「A 臂会话还没起来」并差点判成 phoc 崩。
- 事实（用户现场纠正）：**会话起来了，只是 greetd 还停在解锁界面**，两次都是用户亲手输入密码解锁后才进 Phosh。解锁前 `wayland-0` socket 存在但没有合成器在服务 ⇒ `wayland-info` 输出 0 个 interface、客户端一律初始化失败。
- 判据（换合成器/重启 greetd 后必须按这个顺序走）：
  1. `systemctl is-active greetd` = `active` **只说明登录器在跑**，不说明合成器在跑。
  2. `ps -eo comm | grep -cx phoc` = **1 才是合成器真起来了**；= 0 时先怀疑未解锁，别怀疑崩溃。
  3. `loginctl list-sessions --no-legend` 里出现 `1001 xuqianhui1001 … user` 且 `TYPE`/`CLASS` 正常，才说明已登录。
  4. 只有在上述两个条件都满足后才跑 `wayland-info` / `grim` / GUI 客户端；否则 0 全局是**假阴性**。
- 处置：远程做 GUI 类判据前，要么请用户解锁，要么先用 `ps -eo comm | grep -cx phoc` 判「有没有会话可测」；判定链里禁止把「`wayland-info` 0 个全局」写成「合成器崩溃 / 会话没起来」。
- 同族注意：`su <user> -c '... wayland-info'` 在未解锁时**不报错**（socket 在），所以这条假阴性很隐蔽；`grim`/GTK 会报出具体错误，那两个才是可靠信号。
