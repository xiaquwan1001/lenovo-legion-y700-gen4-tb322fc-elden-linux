## #663 以 root 跑「会话侧体检」会静默读到 root 的 HOME 与 root 的 D-Bus 总线：三类假阴性一次全中

2026-11-15 在 IME 候选体检脚本（`scripts/ime-candidates-check.sh`）实测：脚本以 `elden-root`（root）ssh 过去后直接
`cat "$HOME/...` / `systemctl --user` / `busctl --user`，得到的是 **root 的**视图，于是：

| 判据 | 假阴性表现 | 真因 |
|---|---|---|
| `profile Items/0 = rime` | 报 `keyboard-us` | `/root/.config/fcitx5/profile` 是 **#660 那次 root 第二实例**留下的陈旧件（mtime 06:10、244 B），与用户 251 B 的真实件不同 |
| `config CurrentUI = kimpanel` | 报 `<空>` | root 下没有 `~/.config/fcitx5/config` |
| `org.kde.impanel 有 owner` / `unit fcitx5 active` | 报「无 owner」「inactive」 | `--user` 落到 **root 的 user bus**（空）；真实总线上 `org.kde.impanel` 恒由 focusd 持有、fcitx5 单元 active |

**处置模板（任何以 root ssh 做的会话侧检查都要照做）**：

```sh
UID_=1001
UH=$(getent passwd "$UID_" | cut -d: -f6)
UR=/run/user/$UID_                      # ★ 必须写死，不能继承 XDG_RUNTIME_DIR
asuser() { setpriv --reuid="$UID_" --regid="$UID_" --init-groups \
  env HOME="$UH" XDG_RUNTIME_DIR="$UR" WAYLAND_DISPLAY=wayland-0 \
      DBUS_SESSION_BUS_ADDRESS=unix:path=$UR/bus "$@"; }
asuser systemctl --user is-active fcitx5
asuser busctl --user --no-pager list | grep org.kde.impanel
```

★ **继承 `XDG_RUNTIME_DIR` 是最阴的坑**：ssh 以 root 登录时 pam_systemd 已把它设成 `/run/user/0`，
照抄进 `asuser` 就会连到一个不存在/空的总线，**输出为空而不是报错**（本轮第一次修完仍全空，就是这个原因）。

证据：`TASKS/sessions/2026-11-15-IME候选回归台账.md` §3b（`PASS=6 FAIL=4 WARN=2` → `PASS=10 FAIL=1`）。
