# 键盘设置 GUI v1（y700-elden）

独立 GTK4/libadwaita 应用（形态 A，见 `.pi/plans/2026-11-25-keyboard-settings-gui.md`）。
设备侧需 `python3-gi`、`gir1.2-gtk-4.0`、`gir1.2-adw-1`（已装）。

## v1 范围（仅两项）

1. **震动强度/时长**：写 `/etc/elden-keyboard.conf`（`HAPTIC_MS`/`HAPTIC_MAG`），
   并调用 `elden-keyboard-apply` 把值并进 `/etc/environment`
   （`ELDEN_OSK_HAPTIC_MS`/`ELDEN_OSK_HAPTIC_MAG`）；`ELDEN_OSK_HAPTIC_DEV` 只读展示。
2. **词库引擎切换**：`gsettings sm.puri.phosh.osk.Completers default`（`rime|pipe|none`），
   实时生效。
   > 注意：schema id 是 `sm.puri.phosh.osk.Completers`（设计文档 §1.2、
   > `scripts/ime-single-stack.sh` C2、`out/osk-stub-rime-userdir-20261124/
   > sm.puri.phosh.osk.gschema.xml:71` 三处一致），不是派工单草稿里的 `sm.puri.OSK0`。

## 文件清单

| 文件 | 去向 |
|---|---|
| `elden-keyboard-settings.py` | `/usr/local/bin/elden-keyboard-settings`（chmod +x） |
| `elden-keyboard-settings.desktop` | `/usr/share/applications/` |
| `files/etc/elden-keyboard.conf` | `/etc/elden-keyboard.conf` |
| `files/usr/local/sbin/elden-keyboard-apply` | `/usr/local/sbin/`，root:0755 |

## 安装（设备上，本仓库内不执行）

```sh
install -m 755 elden-keyboard-settings.py /usr/local/bin/elden-keyboard-settings
install -m 644 elden-keyboard-settings.desktop /usr/share/applications/
install -m 644 files/etc/elden-keyboard.conf /etc/elden-keyboard.conf
install -m 755 files/usr/local/sbin/elden-keyboard-apply /usr/local/sbin/
```

## 写入链路与权限

`/etc/environment` 由 root 拥有（pam_env 在登录时注入），普通用户不可写。因此：

- 非 root 时应用经 **pkexec** 写 conf 与执行 apply（policykit 会弹认证）；
- root 直跑时直接写。

`elden-keyboard-apply` 是 POSIX sh、幂等（先删旧行再追加，重复执行结果一致）、
失败非零、支持 `--check` 只读预演。apply 失败时应用弹出可读错误（toast）。

## 生效时机（诚实口径）

- **引擎切换**：实时生效（osk-stub 有 `changed::default` 监听，`pos-completer-manager.c:246`）。
- **震动**：改的是 `/etc/environment` ⇒ **必须重新登录会话**才注入新 env；
  本应用**不**重启会话/greetd（硬约束，v1 不做任何重启动作）。

## 回滚

```sh
rm -f /usr/local/bin/elden-keyboard-settings /usr/share/applications/elden-keyboard-settings.desktop \
      /etc/elden-keyboard.conf /usr/local/sbin/elden-keyboard-apply
# /etc/environment 里的 ELDEN_OSK_HAPTIC_* 行如需还原，手动改回（或删除后重启会话）
```

## 判据（上机验收）

- 应用能启动，标题「键盘设置」，两组（震动/输入引擎）；
- 改震动 → `/etc/elden-keyboard.conf` 更新 → `elden-keyboard-apply --check` 显示新值 →
  （root/pkexec）后 `/etc/environment` 出现对应 `ELDEN_OSK_HAPTIC_*=…`；重登后
  `tr '\0' '\n' < /proc/$(pidof phosh-osk-stub)/environ | grep ELDEN_OSK_HAPTIC` 与设置一致；
- 切引擎 → `gsettings get sm.puri.phosh.osk.Completers default` 立即变化，osk 补全行为变化。

## 为什么 v1 不做按键声音与自定义功能键

- **按键声音**：0.46 源码无任何 sound/click 代码（设计文档 §1.3 grep 取证）；零补丁路径
  依赖 feedbackd 主题且 PoC-0（震动三角定位）尚未测通 feedbackd 链路，可行性未证实，不冒进。
- **自定义功能键**：`sm.puri.phosh.osk.Terminal shortcuts` 虽是 gsettings 实时项，但属于
  「快捷键条」功能面，与本 v1 的两项正交，刻意不扩张范围（防 scope creep）。
- 二者都留给 PoC-0/PoC-2 之后的 v2。
