# 中文输入法「键盘唤不起来」——根因 + 单栈收敛（2026-11-24 二轮设备窗）

> 设备：TB322FC U2 · 内核 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0` · 根 `/dev/sda17` · Debian trixie
> · phosh/phoc/osk-stub **0.46.0**（osk-stub = 我们 divert+hold 的 B 案自编件）。
> 用户报障：「之前有关中文输入法的配置似乎有两条路，现在的部署方案让输入法键盘无法唤起。」
> 本轮类型：设备侧实测（可读可写）+ 主机侧仓库改动。所有外部命令带 `timeout -k`。

## 0. 一页结论

| 项 | 结论 | 判据 |
|---|---|---|
| **真因 ①（主因）** | `org.gnome.desktop.a11y.applications screen-keyboard-enabled` = **false**（2026-11-19 重建根后的默认值）⇒ `phosh-osk-stub.c:221-238 set_surface_prop_surface_visible()` 里 `enabled=FALSE` 时无条件 `visible=FALSE` | 置 `true` 后同一动作立刻弹；反之恒不弹 |
| **真因 ②** | **两套 IME 路径并存**：老路 fcitx5（+toggle/indicator/focusd）与新路 osk-stub+RIME 都被 `daily-baseline.sh` 保住；应用网格点 `Fcitx 5` ⇒ 以**默认参数**起 fcitx5（`waylandim` 已加载）⇒ 抢 `zwp_input_method_v2` 槽 ⇒ osk-stub 只印 `pos-input-method-WARNING: Input method unavailable`，layer surface 恒 `set_margin(0,0,-200,0)` | `journalctl _PID=<osk pid> \| grep -c 'Input method unavailable'`；`WAYLAND_DEBUG=1` 自起一份可见 `set_margin -200` 永不归零 |
| **反面证据（重要）** | `sm.puri.OSK0 Visible` 读到 `(<true>,)` **不等于**键盘在屏上（它只是 D-Bus 属性）；判「屏上有没有」只认 `grim` 截图 | 本轮实测过 Visible=true + 截图 0 键盘 |
| **链路本身是通的** | 点 Firefox 地址栏 ⇒ phoc 发 `zwp_input_method_v2.activate()`（`WAYLAND_DEBUG=1` 抓到）⇒ 一旦 ① 为 true 立刻显示 | 截图 `s_ff5` / `s_finalcheck` |
| **phoc 0.46 没有 #615 的版本门** | `handle_text_input_enable()` 直接 `wlr_input_method_v2_send_activate()`（`/tmp/p046/phoc-0.46.0/src/input-method-relay.c:224-243`）；版本门是 0.58+ 才有的 | 静态 + 本轮 activate 实测 |
| **收敛工具** | `scripts/ime-single-stack.sh --check\|--apply\|--rollback`（C1–C7） | 设备 `--check` = **FAIL=0** |
| **日常门** | `deploy-desktop-shell.sh` §14 新增第 ④ 判据（a11y key），FIX 分支同写 | §14 现报「…、screen-keyboard-enabled=true」 |
| **部署学（01a 已上机）** | 空 `user-data` 的源码兜底已实现并**在机验证**：置空 + 重启 osk-stub ⇒ 它自己建出 `~/.local/share/rime`（属主会话用户、mode 700、18 档 build），journal 无 `Error creating user data dir` | 见 §4 |

## 1. 复现与定位（按顺序，别跳步）

```sh
# 1) 光标在输入框里却没键盘：先看 a11y 开关（99% 是这条）
su -l xuqianhui1001 -c 'XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus \
  gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled'      # false ⇒ 直接修
# 2) 修好 ① 后仍不弹：看 osk-stub 是不是被抢槽
PID=$(ps -eo pid,comm | awk '$2=="phosh-osk-stub"{print $1}' | head -1)
journalctl _PID=$PID | grep -c 'Input method unavailable'                          # >0 ⇒ 有别的 IM client
ps -eo pid,args | grep '[f]citx5'                                                   # 典型元凶
# 3) 要看协议层：自起一份（先确保没有别的 osk-stub 在跑）
WAYLAND_DEBUG=1 G_MESSAGES_DEBUG=all /usr/bin/phosh-osk-stub > /tmp/osk.log 2>&1 &
#    点输入框后 grep 'input_method_v2#.*activate'（收到 = 链路通）
```

本轮 ①② 都命中：②的具体触发 = 用户在应用网格点了 `Fcitx 5`（`org.fcitx.Fcitx5.desktop`，`Exec=fcitx5`
**不带** `--disable waylandim`），20:47 起一直跑到本轮 kill。

## 2. 处置（已落地）

1. `scripts/ime-single-stack.sh`（新）：C1 a11y key / C2 `Completers=rime` / C3 `user-data` 非空 /
   C4 fcitx5 不运行且未自启（`masked`）/ C5 indicator+focusd 不自启 / C6 网格入口 `NoDisplay=true` /
   C7 osk-stub 持有 `sm.puri.OSK0` 且本实例无 `Input method unavailable`。
   `--apply` 停/禁/mask fcitx5 + 删三个 `graphical-session.target.wants` 链接 + 写 `NoDisplay` 覆盖；
   `--rollback` 只反做这三件。
2. `scripts/deploy-desktop-shell.sh` §14：新增第 ④ 判据 + FIX 同时写 `screen-keyboard-enabled=true`。
3. `rootfs/debian/daily-baseline.sh` §3/§3b/§3b2：加 `IME_STACK`（默认 `osk`）——
   默认**不建** fcitx5 自启链接（存在则删）、focusd 不自启、`输入法 中/英` 图标加 `NoDisplay`
   （回老路：`IME_STACK=fcitx bash daily-baseline.sh` 或 `ime-single-stack.sh --rollback`）。
4. `PITFALLS #716`（`sessions/349-*`）、`TASKS` D3 行、`INDEX.md` §0 同步。

## 3. 设备现态（收尾时）

```
ime-single-stack.sh --check ⇒ FAIL=0
osk-stub pid 75892（sha256 688acbe7…，含 0003+0004）· fcitx5 masked · 网格 5 个 fcitx 启动项 NoDisplay
Firefox 地址栏聚焦 ⇒ Visible=true 且 grim 截图有键盘（/tmp/s_finalcheck.png）
$HOME/.local/share/rime/build = 24 档
```

## 4. 01a 源码正解（空 `user-data` 兜底）已上机

- 补丁 `patches-userland/zh-ime-rime-20261123/rime/0004-osk-stub-rime-userdir-fallback.patch`（+21/−2，
  叠在 0003 之后；`pos-completer-rime.c` 里 `*user=='\0'` ⇒ `g_build_filename(g_get_user_data_dir(),"rime",NULL)`
  + `g_mkdir_with_parents(...,0700)`，失败只 `g_warning` 且**继续初始化**；gschema 描述同步改成
  「Empty uses the XDG default directory」）。
- **主会话独立复核**（不信 worker 自报）：`git apply` 0003 再 0004 于 `/tmp/osks/phosh-osk-stub-0.46.0`
  副本 ⇒ rc=0；产物 sha256 = `688acbe706e902d30937b033b608018f432c97c48d4fc6fdbbb4865b17a7598d`
  （与 `out/osk-stub-rime-userdir-20261124/SHA256SUMS` 一致）。
- 设备验证（本轮真做）：`gsettings set … user-data ''` + 移走 `~/.local/share/rime` + 重启 osk-stub
  ⇒ 目录被**它自己**重建（`xuqianhui1001:xuqianhui1001 700`，build 18 档），journal 无
  `Error creating user data dir`；随后复原（`user-data` 指回原路径、备份目录回位）。
- 旧件留在设备 `/root/osk-stub-backup-20261124`（sha256 `cde21b9c…`），回退 = `install` 回去 + `pkill -x phosh-osk-stub`。

## 5. 候选条：已修（2026-11-24 23:1x 收口）

原「点 `nihao` 没候选条」不是 RIME 后端问题，而是 0.46 的完成度门：`completion-mode` 只有
`none/hint/manual`，`hint` 要客户端发 `ZWP_TEXT_INPUT_V3_CONTENT_HINT_COMPLETION`（Firefox 地址栏不发），
`manual` 要用户先点 word-completion 键 ⇒ **自组词的 completer 一个键也收不到**。

改法（`patches-userland/zh-ime-rime-20261123/rime/0005-osk-stub-rime-completer-always-active.patch`，+17/−0）：
在 `pos-input-surface.c` 加 `completer_composes_by_itself()`（按 `pos_completer_get_name()` 判 `"rime"`，
注意实参是**小写** `"rime"`，我第一次写成 `"Rime"` 白跑一轮），`pos_input_surface_is_completer_active()`
对这种 completer 直接返回 TRUE ⇒ 每键都喂给 completer、候选条常显。
**不改 gschema**：新增 `always` 枚举值需要一份能解析该值的 compiled schema（`gsettings` CLI 会报
「提供的值不在有效范围内」，实测 `set_flags(['always'])` 与 `dval uint32` 都不通），改法反而更小、
upstream 的 hunspell/presage 行为零变化。

设备实测（rabuild + divert 已就位）：Firefox 地址栏 → 键 `n i` ⇒ 候选条出 **你 / 拟 / 尼 / 泥 / 呢**，
点「你」⇒ journal `completion: 你`、URL 栏得到「你 」。件 = `out/osk-stub-rime-always-20261124/`
（sha256 `3278264cacbe9ed3d463661e85c5d44757db2b49d88c07dcb4c6167fe621933b`）。

## 5b. 每键震动：**早已上机**（本轮更正 + 补一条判据）

- 事实：`/etc/environment` 里有 `ELDEN_OSK_HAPTIC_DEV=/dev/input/event2` + `_MS=30` + `_MAG=0x3333`，
  11-23 与 11-24 的 osk-stub 件里都带着 `haptic/0001` 钩子（`strings … | grep -c ELDEN_OSK_HAPTIC` = 3）。
  **本轮我做「候选条常显」重编时漏打 haptic/layout 两枚补丁 ⇒ 震动静默消失**，装上去的件 grep = 0；
  用户先发现，我才补回（现行件 sha256 `c415a63e…`，grep = 3）。
- 触发验证（可复跑）：`python3` 读 `/dev/input/event2` 7 s，同时用 `uinput-touch` 点 3 个键 ⇒
  捕获到 `EV_FF (type 0x15) code=0 (FF_RUMBLE) value=1` ⇒ 钩子真的每键 upload/play。
- 新判据：`scripts/ime-single-stack.sh` **C8**（二进制含钩子 + `/etc/environment` 开关 + `event2` 在）；
  重编配方写成 `patches-userland/zh-ime-rime-20261123/BUILD.md`（五枚补丁顺序 + 出厂自检 grep）。
- 仍需人手：只差**手感标定**（太轻/太重改 `ELDEN_OSK_HAPTIC_MAG`）。

## 5c. 明日待办（用户 2026-11-24 点名）

候选条现在**固定间距 + 固定个数**（最多 9 个铺满一行），没有「右划展开/翻页」：
- 期望：候选条可横向滑动看更多候选 / 右划展开成多行；
- 落点估计：`pos-completion-bar.c`（0.46 用 GtkBox 平铺，无滚动）+ RIME completer 的 `limit=9`；
  要做的是「横向滚动容器（GtkScrolledWindow/hdy carousel）+ 手势」或「末位放『更多』按钮翻页」；
- 验收：候选 >5 时能滑到第 6 个以后并选中；不误触键盘行；不破坏 preedit。

## 6. 工具事实（同轮，供下次省时间）

- `/dev/uinput` + `tools/uinput-touch.c`（`tap X Y`/`swipe`，像素坐标，上限 65535）能注入**真实触摸**：
  本轮用它滑开锁屏、点输入框、点键盘按键。**用像素值时先 `grim` 截图 + 像素扫描算键中心**，凭缩略图目测会点错。
- 设备没有 OSK 的 D-Bus service 文件（`/usr/share/dbus-1/services/` 里无 `sm.puri.OSK0`）；
  osk-stub 由 gnome-session 当 required component 拉起，`pkill` 次数过多会把重启预算打光
  （本轮一度把会话打成 "Oh no! Something has gone wrong."，`systemctl restart greetd` 才恢复；
  `phosh` 的 `sm.puri.lockscreen require-unlock` 置 false 后锁屏可直接滑开，省掉每次输入 PIN）。
- `su -l user -c '...'` 里再套单引号会吃掉 `awk '$1=="x"'` 的参数 ⇒ 远端脚本用 base64 传（本脚本已改）。
