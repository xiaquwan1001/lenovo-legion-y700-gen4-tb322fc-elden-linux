# 中文输入法可用性收口（2026-11-09）：配置器打不开、没有顶栏指示、切不到中文

> 用户报障三连：①「始终找不到中文输入法进入方式」②「Fcitx5 也没有状态栏图标/提示」
> ③「配置文件的程序 icon 无法真的跳转到配置文件」；随后追加 ④「点开 Firefox，输入法无法自动唤起」。
> 本报告 = 根因 + 已做改动 + 验收方式 + 未收口项。设备侧改动都可回退，备份在 `/root/ime-bak-20261109/`。

## 1. 三个独立根因（都不是「fcitx5 坏了」）

| 现象 | 根因 | 证据 |
|---|---|---|
| ③ 配置图标点了没反应 | **只装了 `fcitx5-configtool` 薄壳，缺真 UI 包 `fcitx5-config-qt`**（它带上 `libfcitx5-qt6-1` + KF6 依赖）。`fcitx5-configtool` 只是转发器 | 装包前 `dpkg -l fcitx5-config-qt` 空；`apt install fcitx5-config-qt` 后 `org.fcitx.fcitx5-config-qt` 出现在会话总线上（`session-146.scope`），窗口可开（用户当场确认） |
| ② 顶栏没有输入法图标 | **Phosh/phoc 不实现 StatusNotifierItem（SNI）** ⇒ fcitx5 的 `kimpanel`（SNI 客户端）永远等不到宿主；`classicui` 在 Wayland 下只打了 `Created classicui for wayland display:`，屏上无任何面板 | `fcitx5 --verbose '*'` 日志；Phosh 0.59 无托盘 API（社区结论一致：只有 GNOME Shell 有 AppIndicator 扩展） |
| ① 找不到切中文的入口 | 同上（没有托盘就没有「点击切引擎」），而触屏没有 Ctrl+Space 可用 | — |

④ `Firefox` 里不自动出输入法，是**架构二选一**的后果，见 §3。

## 2. 已落地的四件事（全部可回退、幂等）

| # | 内容 | 落点（仓库 / 设备） |
|---|---|---|
| 1 | `fcitx5-config-qt` 装进日用基线（配置器可用） | `rootfs/debian/daily-baseline.tsv`（P1） |
| 2 | **应用网格图标**「输入法 中/英 切换」= `fcitx5-remote -t` + 桌面通知回显 | `rootfs/debian/ime/fcitx5-ime-toggle{,.desktop}` → `~/.local/bin/`、`~/.local/share/applications/` |
| 3 | **顶栏指示胶囊**（GTK4 + layer-shell，右上角显示「中·rime / EN」，点一下切换） | `rootfs/debian/ime/fcitx5-indicator.py` + `fcitx5-indicator.service` → `~/.local/lib/elden/`、`~/.config/systemd/user/`（`graphical-session.target` 下 enable） |
| 4 | fcitx5 profile：组内有 `keyboard-us` + `rime`，`DefaultIM=rime` | `rootfs/debian/daily-baseline.sh` §3b（构建 chroot 与设备同一份） |

依赖：`libgtk4-layer-shell0` + `gir1.2-gtk4layershell-1.0`（已进 tsv）。

**两个实现坑**（都进 `PITFALLS`）：
- `fcitx5-remote` 在 **systemd user service 作用域**里常返回 `0`（closed，无输入上下文），而**从图形会话启动**它能返回 1/2
  ⇒ 「用 SSH 跑一遍看状态」不能当判据，必须从 GUI 触发（图标/胶囊）。
- `gtk4-layer-shell` 在 Python 进程里有**链接顺序**问题（`libwayland-client` 先载入 ⇒ layer surface 初始化失败、
  每条 `set_*` 都警告 `GtkWindow is not a layer surface`）⇒ 单元里必须
  `Environment=LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libgtk4-layer-shell.so.0`。

## 3. ④ 的正解是「二选一」，不是都开

Wayland 的输入法槽位（`text-input-v3`）**同一时刻只能有一个客户端**：

| 模式 | fcitx5 启动参数 | 谁提供屏幕键盘 | 谁能组词 |
|---|---|---|---|
| **A（当前）** | `fcitx5 -r --disable waylandim` | `phosh-osk-stevia`（`--allow-replacement`，OSK 正常弹出） | GTK3/Qt 应用经 **IM 模块**（`GTK_IM_MODULE=fcitx`）；Wayland 原生应用（Firefox 的 Wayland 后端、GTK4）拿不到 `text-input-v3` ⇒ **可能只剩字面输入** |
| **B（今天先试过，已回退）** | `fcitx5 -r`（waylandim 开） | **没有**（stevia 让位给 fcitx5，而 fcitx5 不画键盘） | 所有 Wayland 原生应用都能组词（日志 `Using Wayland native input method protocol: 1`） |

- 12:28 曾切到 B（能组词、但**屏幕键盘消失**），13:21 已回退到 A —— 当前在机 = **A**。
- Firefox 建议先确认它是 **XWayland** 还是 Wayland 后端：`about:support` 的「Window Protocol」。
  * XWayland（`x11`）⇒ 走 `XIM`/GTK IM 模块，A 模式下可组词；
  * Wayland 原生 ⇒ A 模式下没有 `text-input-v3` 给 fcitx5，**只能字面输入**；要么切 B（牺牲 OSK），
    要么把 Firefox 固定到 XWayland（`MOZ_ENABLE_WAYLAND=0`，代价是渲染路径变化）。
- 这条取舍**没有免费解**：Phosh 生态里 OSK 与 IM 一体（`phosh-osk-stevia`），fcitx5 只能二选一占位。

## 4. 用户侧怎么用（当前 A 模式）

1. 顶栏右上角（Phosh 顶栏下方）会有一个小胶囊：**「EN」或「中·rime」** —— 点它就在中/英之间切（等同 `fcitx5-remote -t`，会有横幅提示）。
2. 应用网格里同名图标「**输入法 中/英 切换**」做同样的事（长按可「打开 Fcitx5 配置」）。
3. 点输入框 → 屏幕键盘（stevia）弹出 → 若胶囊显示「中·rime」，敲 `nihao` 应出候选。

## 5. 验收（可复跑）

```bash
ssh root@192.168.7.1 'bash /tmp/db.sh --check | sed -n "/3b\./,\$p"'     # 基线门：应全部 ok
ssh root@192.168.7.1 'su - xuqianhui1001 -c "export XDG_RUNTIME_DIR=/run/user/1001; systemctl --user is-active fcitx5-indicator"'  # active
ssh root@192.168.7.1 'tail -3 /home/xuqianhui1001/.local/state/fcitx5-ime-toggle.log'  # 点击后 after=2 im=rime
```

## 6. 未收口

1. **屏上确认**（需人眼）：胶囊是否在右上角可见、点击是否切换、Firefox 里是否能出候选。
2. Firefox 走 Wayland 还是 XWayland 未定（决定 A/B 哪条对它有效）。
3. `fcitx5-remote` 在 service 作用域返回 0 的机理未深挖（不影响使用，只影响 SSH 侧取证口径）。
4. 构建侧未重建镜像验证（`daily-baseline.sh` §3b 是新增段，chroot 路径靠 `--root` 生效，尚未实跑）。
