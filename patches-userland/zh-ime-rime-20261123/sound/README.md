# osk-stub 0.46 按键声音（sound/0002）

## 为什么
上游 0.46 没有按键音（只有 X keymap 的 AudibleBell，wayland 下无效）。设备上 `pw-play` 可用，
音效资产由 `scripts/asset-install-linux.sh` 安装（PITFALLS #330）。本补丁照 haptic 补丁
（`haptic/0001`）同一形态，在 `src/pos-input-surface.c` 的
`pos_input_surface_notify_key_press()` 加一个 fire-and-forget 的 `g_spawn_command_line_async`。
选这个函数而非 `on_osk_key_symbol` 是因为它是 click hook / keypad / emoji / symbol 各按键
路径的公共汇聚点：一次按键恰好一次 spawn；且与 haptic 补丁 hunk（:387）不重叠，两补丁叠加共存。

## 环境变量（默认全关）
| 变量 | 默认 | 含义 |
|---|---|---|
| `ELDEN_OSK_SOUND` | 未设 = 关 | `1` 才启用 |
| `ELDEN_OSK_SOUND_CMD` | `/usr/local/bin/osk-keysound` | 薄包装（调 pw-play/paplay），由父代理落盘，补丁只认此路径 |
| `ELDEN_OSK_SOUND_VOL` | 交包装脚本 | 0-100，补丁透传到子进程 env `ELDEN_OSK_KEYSOUND_VOL` |

不阻塞、失败静默：spawn 失败只丢错误，不影响输入。

## 判据
- `ELDEN_OSK_SOUND=1` 时点 3 个键 ⇒ 应看到 3 个 `pw-play`/`paplay` 子进程
  （`pidof pw-play` 连点观察，或包装脚本里加日志），并能听到声音。
- `ELDEN_OSK_SOUND` 未设 ⇒ 行为与上游逐字节一致（无 spawn）。
- 出厂自检：`strings phosh-osk-stub | grep -c ELDEN_OSK_SOUND` ≥ 1（漏打补丁=0，BUILD.md 事故教训）。

## 回滚
`git apply -R sound/0002-osk-stub-keypress-sound-hook.patch` 重编；或直接还原
`/root/osk-stub-backup-20261124` 的备份件（见 BUILD.md 部署节）。运行时回滚 = unset `ELDEN_OSK_SOUND`。

## 2026-11-25 上机结果（用户确认）

- 产物：`out/osk-sound-20261125/phosh-osk-stub-v2`（aarch64；`strings` 里 `ELDEN_OSK_SOUND`=3、`ELDEN_OSK_HAPTIC`=3）
- 设备：已装到 `/usr/bin/phosh-osk-stub`（回退件 `/root/osk-stub-backup-20261125-v1`）
- 开关：`/etc/elden-keyboard.conf` 的 `SOUND=1` / `SOUND_VOL=60` —— **包装脚本每次按键现读该文件**，改完立刻生效（不需要重启会话）
- 用户实测：**有声音** ✅

## 编译要点（复现）

sysroot 里的 `glib-compile-resources` 是 aarch64 件，跑不起来（`qemu-aarch64: Could not open /lib/ld-linux-aarch64.so.1`）
⇒ meson 必须叠一个 overlay cross-file，把该工具指回宿主：

```sh
meson setup "$B" --cross-file /tmp/trixie-sysroot/cross.txt --cross-file /tmp/cross-hosttools.ini \
      -Drime=true -Dman=false -Dgtk_doc=false -Dtests=false
```

`/tmp/cross-hosttools.ini` 内容 = `[binaries] glib-compile-resources = '/usr/bin/glib-compile-resources'`
+ `c_args/c_link_args` 加 `--sysroot=/tmp/trixie-sysroot/root` 与
`-Wno-error=format-nonliteral -Wno-error=declaration-after-statement`（rime 补丁的既有告警，与本轮新代码无关）。
