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
