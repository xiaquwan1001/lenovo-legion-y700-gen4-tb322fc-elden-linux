# 四十八、输入法「唤起即崩桌面」根因：phoc 0.55.1 与内嵌 wlroots 0.20.0 的 signal data 约定不一致（2026-10-18 实测）

- 日期：2026-10-18
- 主题：Phosh 桌面敲输入法 → **phoc（合成器）SIGSEGV** → 整个会话被 greetd 重拉（现象像"桌面崩溃重启"，非内核）
- 结论：**phoc 上游 bug，不是配置错**。降级/换 IM 只是绕过触发路径，不是根治。

## 1. 现象与判据

- 用户口径：「输入法无法弹起，在试图唤起输入法的时候桌面 phosh 会崩溃重启，不是内核。」
- 设备实测复现签名：
  - `phoc` PID 变化 + `gnome-session-binary`/`phosh` 同时换 PID（greetd respawn 整条会话）
  - **`/var/log/dmesg` 无 `traps:`/`segfault` 行** ⇒ 用户态崩溃，不是内核 oops
  - gdb 挂 `phoc` 抓到：`Thread 1 "phoc" received signal SIGSEGV` → `#0 handle_im_keyboard_grab_destroy ()`

## 2. #337 根因（代码级闭环）

`phoc 0.55.1` 的 `src/input-method-relay.c`：

```c
static void
handle_im_keyboard_grab_destroy (struct wl_listener *listener, void *data)
{
  PhocInputMethodRelay *relay =
    wl_container_of (listener, relay, input_method_keyboard_grab_destroy);
  struct wlr_input_method_keyboard_grab_v2 *keyboard_grab = data;   /* ← data 现在是 NULL */

  wl_list_remove (&relay->input_method_keyboard_grab_destroy.link);

  if (keyboard_grab->keyboard) {   /* ← NULL + 0x10 解引用 → SIGSEGV */
    ...
  }
}
```

而 phoc 0.55.1 的 `subprojects/wlroots.wrap` 钉的是 **wlroots 0.20.0**，其中
`wlr_input_method_keyboard_grab_v2_destroy()` 已改为：

```c
wl_signal_emit_mutable(&keyboard_grab->events.destroy, NULL);   /* 旧版传 keyboard_grab */
```

（wlroots 提交 `06275103`「input-method-v2: Destroy keyboard grab before input method」，
2025-10-09；同源提交 `102a6bd4`「input-method: use NULL when emitting signals」把
`input_method->events.destroy/commit`、`manager->events.destroy` 也改成 NULL。）

**实机二进制取证**（phoc 静态链了 wlroots）：

```
/usr/bin/phoc  0xd08c0 <wlr_input_method_keyboard_grab_v2_destroy>:
  d08c8:  mov  x1, #0x0                 ; ← data 传 NULL
  d08dc:  bl   wl_signal_emit_mutable
/usr/bin/phoc  0x76000 <handle_im_keyboard_grab_destroy>:
  76014:  ldr  x0, [x1, #16]            ; ← x1 = data = NULL ⇒ fault @0x10
```

崩溃 PC `0xaaaab7fe6014` − 符号偏移 `0x76014` = 加载基址，逐字对上，
**SIGSEGV 地址 = NULL+0x10**，与「`keyboard_grab->keyboard`（结构体偏移 16）」完全一致。

⇒ 只要 IM 客户端（fcitx5 或 squeekboard）释放 keyboard grab，phoc 必崩。
**上游 phoc v0.55.1 / v0.56 / v0.57 / main 至今同款代码，未修。**

## 3. 触发路径（本机两台 IM 抢同一 seat）

`zwp_input_method_v2` **每个 seat 只允许一个 client**（wlroots relay 的
`relay_handle_new_input_method()`：第二个直接 `wlr_input_method_v2_send_unavailable`）。
本机默认同时存在：

| 来源 | 说明 |
|---|---|
| `fcitx5`（`/etc/xdg/autostart/org.fcitx.Fcitx5.desktop`） | 带 `libwaylandim.so`，启动即抢 slot（日志 `Using Wayland native input method protocol: 1`） |
| `squeekboard`（`/usr/share/applications/sm.puri.OSK0.desktop`，Phosh 的 OSK） | 也实现 `zwp_input_method_manager_v2` |

实测日志签名（`/var/log/phosh-session.log`）：

```
phoc-input-method-relay-DEBUG: Input method available: 0xffff...
phoc-input-method-relay-DEBUG: Attempted to connect second input method to a seat   ← 第二个被拒
```

被拒的一方仍会建/销毁 keyboard grab ⇒ 走 §2 的崩溃路径。
另外 `fcitx5` 抢到 slot 后，**squeekboard 拿不到 slot → 虚拟键盘永远弹不起来**，
这解释了用户的前半句「输入法无法弹起」。

补充事实：
- 本机 `/etc/xdg/autostart/sm.puri.OSK0.desktop`（**非包内文件**，2026-10-13 手工加的）内容只有 `Hidden=true`
  ⇒ **squeekboard 根本不随会话启动**，`sm.puri.OSK0` 无 owner
  ⇒ phosh 启动即 `Unable to toggle OSK: The name sm.puri.OSK0 was not provided by any .service files`
  ⇒ 系统里也没有 `sm.puri.OSK0.service`（上游 squeekboard 本来就不提供 DBus service，靠
  gnome-session 的 `RequiredComponents=…;sm.puri.OSK0;` + autostart 启动）。
- gsettings `org.gnome.desktop.a11y.applications screen-keyboard-enabled = true`（开关是开的，但服务不存在）。

## 4. 取证方法（可复用）

```sh
# 1) #338 会话日志落盘（默认 phoc/phosh 的 stderr 全进 /dev/tty7，等于丢失）
#    把 greetd session 命令包一层重定向 + 留 core：
#    /usr/local/sbin/elden-session-user 末尾
#      ulimit -c unlimited
#      exec /bin/sh -c "exec /usr/bin/phosh-session" >>/var/log/phosh-session.log 2>&1

# 2) 打开 phoc 的 IM relay 调试域（运行时，无需重启）
BUS=$(tr '\0' '\n' < /proc/$(pgrep -x phosh)/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
gdbus call --session --dest mobi.phosh.Phoc.DebugControl \
  --object-path /mobi/phosh/Phoc/DebugControl \
  --method org.freedesktop.DBus.Properties.Set \
  mobi.phosh.Phoc.DebugControl LogDomains "<[\"phoc-input-method-relay\"]>"

# 3) 挂 gdb 抓栈（要 apk add gdb phoc-dbg phosh-dbg）
gdb -p $(pgrep -x phoc) -batch -ex 'set confirm off' \
  -ex 'handle SIGPIPE nostop noprint pass' -ex 'handle SIGUSR1 nostop noprint pass' \
  -ex 'handle SIGSEGV stop print pass' -ex continue \
  -ex 'echo \n==SEGV==\n' -ex 'bt 12' -ex 'info registers x0 x1'
```

坑（#339）：`gdbus` 的 variant 参数必须写成 `<["a","b"]>`（字符串要带引号、整体加 `<>`），
写成 `<[a,b]>` 会报 `unknown keyword`。

## 5. 结论与去向

- **不能靠改配置真正修好**：只要有任何 IM 客户端建/销毁 keyboard grab，phoc 0.55.1 就有 NULL deref 窗口。
- 可行动作（按优先级）：
  1. **升级 phoc 到修好的版本 / 或 Alpine 打补丁**（Alpine aports 已是 0.57.0，但 0.57.0 源码同款 bug ⇒ 必须
     自己 patch：`keyboard_grab = data;` 改为从 `relay->input_method->keyboard_grab` 取，或对 `data` 加 NULL 判断）。
     最小补丁：

     ```c
     if (keyboard_grab && keyboard_grab->keyboard) { ... }
     ```
  2. 向上游报告（World/Phosh/phoc）：wlroots 0.20.0 起 `keyboard_grab->events.destroy` 的 data 是 NULL，
     `input-method-relay.c` 需同步。
  3. 临时规避（只降触发概率，不根治）：**只保留一个 IM**。建议 squeekboard 作 OSK + `fcitx5 --disable waylandim`
     （实测 fcitx5 侧日志变 `Using Wayland native input method protocol: 0`，slot 让给 squeekboard，
     `Attempted to connect second input method` 消失），或反之只要 fcitx5、彻底不启动 squeekboard
     （但那就没有虚拟键盘了，触屏机型不可接受）。
     注意：`fcitx5 --disable waylandim` 只切断「作为 Wayland IM」这条路径，GTK/Qt 的 `GTK_IM_MODULE=fcitx`
     im-module 通道仍在，中文输入不受影响。
- **本次已还原**所有临时改动（`/etc/xdg/autostart/{org.fcitx.Fcitx5,sm.puri.OSK0}.desktop`、
  `/usr/local/sbin/elden-session-user`），备份在设备 `/root/im-fix-backup-20261018/`。
  取证副本在设备 `/tmp/im-evidence/`。
- 设备侧额外装了 `gdb`、`phoc-dbg`、`phosh-dbg`、`grim`（诊断用，未卸载）。

## 6. 补丁与上游提交（2026-10-18 已完成，MR 待推送）

- **补丁产物**：`patches/upstream/phoc-im-keyboard-grab-2026-10-18/`
  - `0001-input-method-relay-Fix-NULL-deref-in-keyboard-grab-d.patch`（正式 git 补丁，带完整 commit message）
  - `imtest.c`（**最小复现器**，见下）
  - `README.md`（缺陷/验证/复现步骤/待办全在里面）
- **上机 A/B**（设备原生构建 14 s，补丁二进制 sha256 `0a0982f6…`）：
  | 臂 | 槽状态 | 结果 |
  |---|---|---|
  | 原版 phoc | `acquired` | **CRASH 2/2** |
  | 原版 phoc | `unavailable` | SURVIVED 2/2（不建 grab） |
  | 补丁 phoc | `acquired` | **SURVIVED 5/5** |
- **★ 判据陷阱（这次差点判错）**：用 `fcitx5`/`squeekboard` 起停来"复现"是不可靠的——
  squeekboard **根本不 grab keyboard**（源码核过），且第二个 IM 会被判 `unavailable` 而**不建 grab**，
  两种情况下原版 phoc 也「存活」，会误判成"没 bug"。
  **唯一可靠判据 = 自己 grab**：`imtest grab`（`zwp_input_method_v2_grab_keyboard()` → release）。
  槽必须为空（先 `pkill -x fcitx5; pkill -x squeekboard`）才能拿到 `acquired`。
- **上游状态**：GNOME GitLab SSH 认证可通（`@xuqianhui1001`），但**服务端禁止 SSH 自动建 fork**
  （`Could not create project: Visibility level private has been restricted by your GitLab administrator`），
  本机也无 `gitlab.gnome.org` 的 API token ⇒ **需要人网页 fork 一次（Visibility 选 Public）或提供 PAT**。
- **顺带发现**：设备 `/etc/ca-certificates/update.d/certhash` 是**空文件** ⇒
  `update-ca-certificates` 永远写出 0 字节 bundle ⇒ 设备全站 HTTPS 失效（git/curl/apk 全废）。
  临时修法 `cat /usr/share/ca-certificates/mozilla/*.crt > /etc/ssl/certs/ca-certificates.crt`。
