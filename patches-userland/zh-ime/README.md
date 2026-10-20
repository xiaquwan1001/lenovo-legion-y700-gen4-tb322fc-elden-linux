# zh-ime — 触屏中文输入法（唤起 / 折叠隐藏）

> 状态：**已上机验收（2026-10-20，TB322FC / vk127 / Alpine 3.24 / Phosh 0.55.0 / phoc 0.55.1）**
> 部署：`bash scripts/deploy-zh-ime.sh`（幂等，自带 7 项自检）
> 报告：`reports/zh-ime-touch-chinese-20261020.md`

## 1. 最终栈（三个组件，各司其职）

```
 手指点输入框
      │
      ├─(A) elden-ime-focusd  ── 监听 kimpanel 的 SetRelativeSpotRect（fcitx5 聚焦信号）
      │                         └─► sm.puri.OSK0.SetVisible(true) ──► squeekboard 弹出
      │
      ├─(B) squeekboard ── 触屏键盘：占 Wayland input-method 槽位、实现 sm.puri.OSK0
      │                    （SetVisible(true/false) 是唯一控制面；属性 Visible 只读）
      │
      └─(C) fcitx5 + Rime ── 中文引擎：拼音 → 候选 → 上屏
                             **必须 `--disable waylandim`**（把槽位让给 squeekboard）
```

| 组件 | 路径 | 作用 |
|---|---|---|
| squeekboard | `/usr/bin/squeekboard` | 触屏键盘 + seat 的键盘设备（`wl_seat.capabilities` 4→7，见 `PITFALLS` §50） |
| fcitx5 + Rime | `/usr/bin/fcitx5 --disable waylandim` | 中文组词；候选窗由 **fcitx5-gtk3/4 的 IM 模块**自己画 |
| fcitx5-gtk3 / gtk4 | `/usr/lib/gtk-{3,4}.0/*/immodules/*fcitx5*` | **缺它中文完全不工作**（见 §5 坑 1） |
| elden-ime-focusd | `/usr/local/bin/elden-ime-focusd`（源码 `elden-ime-focusd.c`） | 焦点 → 唤起键盘的桥 |
| elden-ime-toggle | `/usr/local/bin/elden-ime-toggle` + 应用网格「键盘」图标 | 手动 唤起/折叠 |

## 2. 用法

- **唤起**：手指点任意输入框 → 键盘自动弹出（新输入框获得焦点时）。
  键盘已被手动收起、且点的还是**同一个**已聚焦输入框时不会重弹（fcitx5 不再发聚焦事件），
  此时用下面任一方式：点应用网格「键盘」图标 / 长按电源条（Phosh 自带）。
- **折叠**：点应用网格里的**「键盘 / Keyboard」**图标（`elden-ime-toggle`），命令行 `elden-ime-toggle hide|show|toggle`。
- **打字**：键盘敲拼音（如 `nihao`）→ 输入框上方出现候选条 → 点候选或按数字键 → 上屏中文。
  中英切换：`Ctrl`+`Space`（squeekboard 有 Ctrl 键）。

## 3. 验收（可复现，2026-10-20 实测）

```sh
bash scripts/deploy-zh-ime.sh        # 自带自检：7/7 OK
```

| 判据 | 命令 / 做法 | 实测结果 |
|---|---|---|
| fcitx5 不抢槽位 | `grep -c 'Wayland native input method protocol: 1' /tmp/fcitx5.log` | **0** ✅ |
| OSK 服务在位 | `gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method org.freedesktop.DBus.Properties.Get sm.puri.OSK0 Visible` | `(<true>,)` ✅ |
| 折叠 | `elden-ime-toggle hide` → 读 `Visible` | `false`，屏幕底部亮度 169→0 ✅ |
| 手动唤起 | `elden-ime-toggle show` → 读 `Visible` | `true`，键盘可见 ✅ |
| **触屏唤起** | `hide` 后新起一个输入框（FocusIn） | `Visible` 自动变 `true` ✅ |
| **中文上屏** | 注入 `nihao` → 候选出现 → 注入 `1` | 输入框内容 = **`你好`** ✅ |
| 候选条 | 截图 | 输入框下方 `1 你好 2 妳好 3 逆號 4 擬好 5 你 ◀▶` ✅ |

## 4. 参数 / 调优

| 项 | 位置 | 说明 |
|---|---|---|
| 焦点去抖 | `elden-ime-focusd.c` 的 `400000`（µs） | 避免候选每次刷新都调一次 SetVisible |
| 日志 | `/tmp/elden-ime-focusd.log`、`/tmp/fcitx5.log`、`/tmp/squeekboard.log` | 排障先看这三个 |
| 输入法 | `~/.config/fcitx5/profile`（`DefaultIM=rime`） | 换引擎用 `fcitx5-configtool` |

## 5. 关键坑（都在 `PITFALLS` 有正式条目）

1. **`fcitx5-gtk` 没装 ⇒ 中文完全不工作**：`GTK_IM_MODULE=fcitx` 只是空设，
   按键以**字面字母**进应用（`ENTRY=[nihao]`）。装 `fcitx5-gtk3`/`fcitx5-gtk4` 后立即正常。
2. **两个 IM 抢一个 seat 槽位**：fcitx5 若带 `waylandim`（默认开）会抢走槽位 ⇒ squeekboard 被判
   `unavailable` ⇒ 键盘不弹。必须 `--disable waylandim`。**这不是配置口味，是硬约束。**
3. **自编候选条（上一轮 `candidate-bar.c`）整条不需要**：候选窗是 **fcitx5-gtk 的 IM 模块自己画的**。
   证据：杀掉 `candidate-bar` 后候选照常、`你好` 照常上屏。已移入 `withdrawn/`。
   同批废弃：`wvkbd`（不再需要，键盘由 squeekboard 提供）、`zh-osk`、`osk-toggle`。
4. **`phoc` 必须已打 `input-method-relay` NULL deref 补丁**（`patches/upstream/phoc-im-keyboard-grab-2026-10-18/`）。
   本机 `/usr/bin/phoc` sha256 `0a0982f6…` = 补丁版；原版在 `/root/im-fix-backup-20261018/phoc.orig`。
5. **`gsettings screen-keyboard-enabled` 必须为 `true`**：旧 `zh-osk` 曾把它设 `false` 来压 squeekboard，
   残留会导致键盘永不出现。

## 6. 回滚

```sh
rm /usr/local/bin/elden-ime-focusd /usr/local/bin/elden-ime-toggle
rm /etc/xdg/autostart/elden-ime-focusd.desktop /etc/xdg/autostart/org.fcitx.Fcitx5.desktop
rm ~/.config/autostart/org.fcitx.Fcitx5.desktop
rm /usr/share/applications/elden-ime-toggle.desktop
# 恢复旧的 wvkbd 方案：见 withdrawn/
```

## 7. 目录

| 文件 | 说明 |
|---|---|
| `elden-ime-focusd.c` | 焦点桥（glib/gio，~200 行） |
| `elden-ime-toggle` | 唤起/折叠 CLI |
| `elden-ime-toggle.desktop` | 应用网格图标（触屏入口） |
| `org.fcitx.Fcitx5.desktop` | fcitx5 自启项（强制 `--disable waylandim`） |
| `elden-ime-focusd.desktop` | focusd 自启项 |
| `build-elden-ime.sh` | 设备上编译 focusd |
| `vktype.c` / `vk*.h` / `vk*.xml` | 测试工具：用 `zwp_virtual_keyboard_v1` 注入字符串（`VK_OFF=-8` 是本机实测的 keycode 偏移） |
| `vp.c` / `vp*.h` | 测试工具：`zwlr_virtual_pointer` 点击/长按（`VP_HOLD=<µs>`；坐标用**逻辑**尺寸 952×1520） |
| `withdrawn/` | 已废弃：`candidate-bar.c` + layer-shell/XDG 绑定、`wvkbd` 时代的 `zh-osk`/`osk-toggle`、未采用的 `osk-ime.c` 原型 |
