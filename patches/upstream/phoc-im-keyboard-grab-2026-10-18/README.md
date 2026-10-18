# phoc: input-method keyboard grab 销毁时 NULL 解引用（上游提交件）

> 状态：**补丁已写好、已上机验证；MR 待推送**（GNOME GitLab 不允许 SSH 自动建 fork，见文末「待办」）。
> 归档日：2026-10-18。设备：TB322FC / Alpine 3.24.2 / phoc 0.55.1 / wlroots 0.20.0 / aarch64。

## 1. 缺陷

`src/input-method-relay.c` 的 `handle_im_keyboard_grab_destroy()` 把信号 data
无条件当作 `struct wlr_input_method_keyboard_grab_v2 *` 解引用：

```c
struct wlr_input_method_keyboard_grab_v2 *keyboard_grab = data;
...
if (keyboard_grab->keyboard) {        /* data == NULL 时崩 */
```

而 phoc 0.55.1 的 `subprojects/wlroots.wrap` 钉的是 **wlroots 0.20.0**，其中
`wlr_input_method_keyboard_grab_v2_destroy()` 已改为 `wl_signal_emit_mutable(..., NULL)`
（wlroots `06275103`，2025-10-09，同时把 `input_method->events.destroy/commit`、
`manager->events.destroy` 一并改成 NULL）。

⇒ **任何 IM 客户端销毁自己的 keyboard grab 都会让 phoc SIGSEGV**
（故障地址 = `NULL + offsetof(..., keyboard)` = `NULL+0x10` on aarch64），
greetd 随即重拉整条会话，用户看到「桌面崩溃重启」。

上游 phoc **v0.55.1 / v0.56 / v0.57 / main 至今同款代码，未修**（2026-10-18 核对）。

## 2. 补丁

文件：`0001-input-method-relay-Fix-NULL-deref-in-keyboard-grab-d.patch`

```c
+  /* wlroots emits this signal with the grab as data up to 0.19 and with NULL
+   * from 0.20 on (see wlroots commit 06275103). The grab is still attached to
+   * the input method when the signal is emitted so get it from there. */
+  if (keyboard_grab == NULL && relay->input_method != NULL)
+    keyboard_grab = relay->input_method->keyboard_grab;
+
   wl_list_remove (&relay->input_method_keyboard_grab_destroy.link);
 
-  if (keyboard_grab->keyboard) {
+  if (keyboard_grab && keyboard_grab->keyboard) {
```

要点：
- **不是简单加 NULL 判断**——那样会丢掉「把修饰键状态回送给原客户端」的行为。
- signal 触发时 `input_method->keyboard_grab` **仍然有效**（wlroots 在 emit 之后才清空），
  所以从 relay 反查既安全又保留原意。
- 对老版 wlroots（data 非 NULL）完全兼容。

## 3. 上机验证（A/B，设备实机）

构建：设备原生 `meson setup build -Dembed-wlroots=enabled -Dman=false -Dtests=false`，**14 s** 编完（720 targets）。
补丁二进制 sha256 `0a0982f6…`；原版（备份）`4eca6dc4…`。

最小复现器 `imtest`（`/tmp/imtest/imtest.c`，用 `input-method-unstable-v2` 建 IM → `grab_keyboard` → 2 s 后 release）：
**这是唯一能干净判定该 bug 的用例**——必须有客户端真正 grab 过键盘。

| 臂 | 条件 | 结果 |
|---|---|---|
| 原版 phoc | `imtest` 抢到槽（`acquired`） | **CRASH 2/2**（phoc PID 变，会话重启） |
| 原版 phoc | 槽被 fcitx5 占用（`unavailable`） | SURVIVED 2/2（不建 grab，故不触发） |
| 补丁 phoc | `imtest` 抢到槽（`acquired`） | **SURVIVED 5/5** |

⇒ 因果链闭合：**`acquired` 时原版必崩、补丁版必活**；`unavailable` 不作为崩溃样本
（这一点早期判错过——见 `PITFALLS` §48 §3 的教训）。

设备侧另加确认：崩溃点 PC 与符号偏移 `0x76014` 对得上（原版二进制
`handle_im_keyboard_grab_destroy: ldr x0, [x1, #16]`），且 gdb 栈为
`handle_im_keyboard_grab_destroy ← wl_signal_emit_mutable ← wlr_input_method_keyboard_grab_v2_destroy`。

## 4. 复现路径（别人怎么验）

```sh
# 1. 装 gdb 与调试符号
apk add gdb phoc-dbg

# 2. 取 input-method-unstable-v2.xml（phoc 源码 subprojects/wlroots/protocol/ 下有）
wayland-scanner client-header input-method-unstable-v2.xml im-v2.h
wayland-scanner private-code  input-method-unstable-v2.xml im-v2.c
cc -O0 -g -o imtest imtest.c im-v2.c -lwayland-client

# 3. 先杀掉所有 IM，确保 imtest 能拿到（每个 seat 只允许一个 IM）
pkill -x fcitx5; pkill -x squeekboard

# 4. 跑：客户端 grab 键盘后释放
WAYLAND_DISPLAY=wayland-0 ./imtest grab

# 5. 看 phoc 是否还活着
pgrep -ax phoc
```

`imtest.c` 关键几行：`zwp_input_method_manager_v2_get_input_method()` →
`zwp_input_method_v2_grab_keyboard()` → `sleep(2)` → `zwp_input_method_keyboard_grab_v2_release()`
→ `zwp_input_method_v2_destroy()`。

## 5. 待办（需要人在网页上做一次）

GNOME GitLab 侧：
- SSH 认证可通（`ssh -T git@gitlab.gnome.org` → `Welcome to GitLab, @xuqianhui1001!`），
  但对 `World/Phosh/phoc` 无 push 权限；
- `git push` 到 `git@gitlab.gnome.org:xuqianhui1001/phoc.git` 会被服务端拒绝：
  `Could not create project: Visibility level private has been restricted by your GitLab administrator`
  —— 即**不允许 SSH 自动建 fork（默认 private 被禁）**；
- 本机 `glab` 只配了 gitlab.com / git.ustc.edu.cn 的 token，**没有 gitlab.gnome.org 的 token**。

**只需要一次手工操作（任选其一）**：

1. **网页 fork**：<https://gitlab.gnome.org/World/Phosh/phoc/-/forks/new>
   选你自己的 namespace、**Visibility 选 Public**，创建后告诉我，我即可推送：
   ```sh
   cd <repo>
   git remote add fork git@gitlab.gnome.org:xuqianhui1001/phoc.git
   git push -u fork fix-im-keyboard-grab-null-deref
   ```
2. **或**给一个 GNOME GitLab Personal Access Token（`api` + `write_repository` scope），
   我用它建 fork + 推送 + 开 MR。**token 不要写进仓库/记忆文件**，只通过会话提供。

推送后开 MR 的标题/描述（可直接用）：

- 标题：`input-method-relay: Fix NULL deref in keyboard grab destroy handler`
- 描述：说明 wlroots 0.20 改成 NULL 的来龙去脉 + 上面的 A/B 实测表 + `Closes:` 关联 issue
  （若有 issue 编号，用 `Closes: <完整 URL>`）。

## 6. 顺带发现（与本补丁无关，但值得单独报）

1. **设备侧 `ca-certificates.crt` 为 0 字节**，根因是 `/etc/ca-certificates/update.d/certhash`
   是**内容为空的文件**（`file` 报 empty，执行报 `Exec format error`），导致
   `update-ca-certificates` 永远生成空 bundle ⇒ 设备上所有 HTTPS（git/curl/apk）全废。
   临时修法：`cat /usr/share/ca-certificates/mozilla/*.crt > /etc/ssl/certs/ca-certificates.crt`。
   这是 Alpine 包/本地镜像问题，不是 phoc 的。
2. `sm.puri.OSK0` 在本机 `/etc/xdg/autostart/sm.puri.OSK0.desktop` 被手工写成 `Hidden=true`
   （非包内文件），导致 squeekboard 不随会话启动、phosh 启动即报
   `Unable to toggle OSK: ... sm.puri.OSK0 was not provided by any .service files`。
   上游 squeekboard 本就不提供 DBus service，靠 `sm.puri.OSK0.desktop` autostart 拉起。
