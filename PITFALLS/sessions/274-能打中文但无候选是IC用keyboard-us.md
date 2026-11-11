# #619 「能打中文但没有候选词」= fcitx5 当前 IC 用的是 `keyboard-us`，不是 Rime；且 phoc 上必须 `CurrentUI=kimpanel`

> 索引行见 `PITFALLS/README.md` 第 274 行。首次取证：2026-11-11 晚（用户报「中文能够打出，但是没有候选词。没有候选窗」）。
> 前置 `#615`（phoc 版本门）/ `#618`（`GTK_IM_MODULE=fcitx` 遮蔽 text-input-v3）见 `sessions/270-`、`sessions/273-`。
> 权威报告 `reports/ime-osk-firefox-rootcause-20261112.md`（§8 追加）、截图 `reports/artifacts/ime-candidates-20261111.png`。

## 现象

OSK 已能弹（`#618` 修完）、中文也能上屏，但：
- **没有候选窗**；
- 打 `nihao` 时，`org.kde.impanel2.SetLookupTable` 的候选数组**全是空**（9 次调用 0 个 string）。

## 根因（两层，彼此独立）

### 层 A：`CurrentUI = classicui` 在 phoc 上出不了窗

`fcitx5-diagnose` 显示 classicui 是**默认 UI**。classicui 需要合成器提供它要的窗口协议，
**在 phoc 上建不出候选窗**（用户看不到任何候选 UI），但 fcitx5 内部仍在算候选。

⇒ **必须把 UI 后端切到 `kimpanel`**，且 kimpanel 要有 owner（`elden-ime-focusd` 就是）：

```bash
# 判据
gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller \
  --method org.fcitx.Fcitx.Controller1.CurrentUI          # 期望 ('kimpanel',)
busctl --user list | grep 'org.kde.impanel '              # 期望有 owner（focusd）
# 切换（运行期）
gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller \
  --method org.fcitx.Fcitx.Controller1.SetAddonsState "[('classicui', false), ('kimpanel', true)]"
```

### 层 B：**新 IC 永远拿到 `keyboard-us`** ⇒ Rime 不参与，候选恒空

这是「能打中文但无候选」的**直接原因**。判据（一行定死）：

```bash
fcitx5-remote -n     # 全局：rime     ← 看着对
# 但打开任意新窗口（新 IC）后再问：
fcitx5-remote -n     # → keyboard-us  ← 这就是根因
```

`DebugInfo` 也能看到每个 IC 的 `program:...` 列表，但**不显示每个 IC 的 IM**，
所以必须用 `fcitx5-remote -n` 在**新 IC 有焦点时**采样。

机制：fcitx5 新 IC 取 **`profile` 里 `Items/0`** 作为默认 IM。原 profile：

```
[Groups/0/Items/0] Name=keyboard-us     ← 新 IC 拿这个
[Groups/0/Items/1] Name=rime
```

`DefaultIM=rime` **不能**改变「新 IC 用哪个」——它只影响组内切换的起点。

## 改 profile 的三个坑（都踩过）

- **fcitx5 退出时会把内存态写回 `profile`** ⇒ 在 fcitx5 运行时改文件，退出瞬间被覆盖。
- **`pkill -x fcitx5` 杀不掉**：`fcitx5.service`（systemd user unit）会立刻拉起。
   `systemctl --user stop` 也无效（旧实例仍在；`mask` 后 `pgrep` 还显示 alive，是**另一个**实例）。
- **`AddInputMethodGroup` 会污染 profile**：它会新建 `[Groups/1]`，而 `GroupOrder` 只列 `0=默认` ⇒
   组顺序错乱，`InputMethodGroupInfo` 读回仍是旧顺序。**不要用它改顺序。**

### 正确做法（实测通过）

```bash
# 1) 停 unit + 杀残留（两步都要）
systemctl --user stop fcitx5
for p in $(pgrep -x fcitx5); do kill -9 $p; done
sleep 2; pgrep -x fcitx5 | wc -l        # 必须 = 0

# 2) 此时才写 profile：rime 放 Items/0
cat > ~/.config/fcitx5/profile <<'EOF'
[Groups/0]
# Group Name
Name=默认
# Layout
Default Layout=us
# Default Input Method
DefaultIM=rime

[Groups/0/Items/0]
# Name
Name=rime
# Layout
# Layout=

[Groups/0/Items/1]
# Name
Name=keyboard-us
# Layout
# Layout=

[GroupOrder]
0=默认
EOF

# 3) 起 unit，读回验证
systemctl --user start fcitx5; sleep 8
gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller \
  --method org.fcitx.Fcitx.Controller1.InputMethodGroupInfo 默认
#   期望 ('us', [('rime', ''), ('keyboard-us', '')])
```

## 判据（全绿）

| 判据 | 命令 | 期望 |
|---|---|---|
| 组顺序 | `InputMethodGroupInfo 默认` | `('us', [('rime',''),('keyboard-us','')])` |
| 全局 IM | `fcitx5-remote -n` | `rime` |
| **新 IC IM** | 开新窗后 `fcitx5-remote -n` | **`rime`**（此前恒 `keyboard-us`） |
| 候选非空 | `dbus-monitor "interface='org.kde.impanel2'"` 抓 `SetLookupTable` | 第二/三个 array 里有真实汉字 |
| 目视 | `grim` 截图 | 候选窗可见（`reports/artifacts/ime-candidates-20261111.png`） |

实测（打 `nihao`，只敲到 `ni` 时抓到的候选）：
```
SetLookupTable
  array [ string "3 " string "4 " string "5 " ]        ← 页码/序号
  array [ string "你" string "那" string "呢" string "能" string "年" ]   ← 候选
```

## 副作用 / 注意

- 切到 kimpanel 后 **classicui 必须显式禁用**（否则两个 UI 抢），`SetAddonsState` 一次即可，
  但它**不持久**（fcitx5 重启后按 `~/.config/fcitx5/conf/` 的 addon 配置走）⇒ 长期做法是
  在 `/etc/xdg/fcitx5/addon/classicui.conf` 或用户配置里写 `Enabled=False`（本轮未落地，记为待办）。
- `kimpanel` 的候选窗由 `elden-ime-focusd` 提供时**只处理了 `SetRelativeSpotRect`**（用于弹 OSK），
  **候选窗本身仍由 fcitx5 侧渲染**——本轮的目视证据是用户确认「能看到候选词」，
  而 `SetLookupTable` 数据流已证明候选被送到 kimpanel。两者一致。
- `keyboard-us` 仍在组内（Items/1），用 `Ctrl+Space` / 胶囊点击可切回英文。

## 未闭环

- **`SetAddonsState` 不持久** —— 重启后要重新切（或改 addon conf）。判据 = 重启后 `CurrentUI` 仍 `kimpanel`。
- 候选窗位置/遮挡（与 stevia 键盘重叠）未目视确认。
- XWayland / Qt 客户端未验。
