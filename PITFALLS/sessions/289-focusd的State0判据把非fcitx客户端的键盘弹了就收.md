# #653 focusd 的 `State==0 ⇒ 收起` 会把非 fcitx 客户端的键盘弹了又立刻收

- 日期：2026-11-13
- 场景：C-U7 上机（phoc 0.59~rc1 + phosh 0.59~rc1）后测 OSK：`sm.puri.OSK0.Visible` 始终 `false`，截图里键盘一闪即没。
- 判据链（逐个证伪，最后一条才是真因）：
  1. phoc 版本门已去？✅ 本机二进制由我们补丁构建（版本门那行源码 `grep -c` = 0），客户端 `WAYLAND_DEBUG` 里 `zwp_text_input_v3.enable()` + `commit()` 确实发出。
  2. stevia 本身能显示？✅ 手工 `busctl --user call sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true` → `t1: true`（但 `t2: false`）。
  3. 谁在收？✅ `/tmp/elden-ime-focusd.log` 里成对出现：`Visible->1 (signal)` → `hide requested by fcitx State=0` → `SetVisible(0)`。
  4. 为什么 `State` 恒 0？✅ `busctl call org.fcitx.Fcitx5 /controller …State` 在有焦点时也返回 `i 0`；`DebugInfo` 里只有 `program:phosh` 的 IC，**GTK3 客户端根本没进 fcitx**（无论 `GTK_IM_MODULE=fcitx` 还是 `wayland`，`fcitx5-frontend-gtk3` 装了、`im-fcitx5.so` 依赖齐，仍不建 IC）。
- **真因**：`elden-ime-focusd` 的 `idle_check()` 里 `if (st == 0) osk_hide("fcitx State=0")` **无条件生效**，而源码自己的注释写的是「`GTK_IM_MODULE=wayland` 时 State 恒 0 ⇒ **不会**误收起」——实现与注释相反。任何不经过 fcitx 前端的客户端（GTK3 wayland text-input-v3 / 探针 / 将来 Qt）都会 `State` 恒 0 ⇒ 每次 kimpanel 信号弹起后 1 s 内被自己收掉。
- **处置**（已上机验证）：加 `fcitx_seen_active` 闸门——**只有本 IC 曾观测到 `State == 1`，才允许用 `State == 0` 当收起判据**；`osk_hide()` 里重置该标志。其余三条收起判据（零矩形 400 ms / 空闲超时 / `State == -1` 连续 5 次）不变。
  - 判据（复现命令）：`busctl --user call org.kde.impanel /org/kde/impanel org.kde.impanel2 SetRelativeSpotRect iiii 100 200 300 400` → 日志只出现 `show requested by SetRelativeSpotRect (300x400)` + `SetVisible(1)`，**无 hide**；`Visible` 连续 6 次（8 s）保持 `true`；截图底部可见完整 stevia 键盘。
  - 产物 `out/ime-host/elden-ime-focusd`（sha256 `5cf98e1d7294fe64…`），设备备份 `/usr/local/bin/elden-ime-focusd.prev-20261113`（`8bfab82e2d872cd5…`）。
- 附：`org.kde.impanel` 的**接口名是 `org.kde.impanel2`**（对象路径 `/org/kde/impanel`）；用 `org.kde.impanel` 调会报 `No such interface`，别据此判「桥没实现」。
- 遗留（未解，非本坑）：GTK3 在 phoc 0.59~rc1 + fcitx5 下**不建立 fcitx IC**（`DebugInfo` 只有 `program:phosh`）⇒ 中文组词链路仍未打通；`PITFALLS #618` 里「`GTK_IM_MODULE=wayland` → `Visible=true`」的旧判据在 0.59 栈上**不再成立**。
