# 触屏中文输入法（唤起 / 折叠隐藏）——上机验收报告

- 日期：2026-10-20
- 设备：TB322FC（U2）· `7.3.0-rc7-debug-vk127` · Alpine 3.24.2 · Phosh 0.55.0 / phoc 0.55.1（内嵌 wlroots 0.20.0）
- 结论：**可用**。点输入框自动弹出触屏键盘 → 拼音 → 候选 → 上屏「你好」；应用网格「键盘」图标 / `elden-ime-toggle` 可唤起与折叠。
- 部署：`bash scripts/deploy-zh-ime.sh`（7/7 自检 OK）
- 组件源码：`patches-userland/zh-ime/`
- 相关：`reports/ime-osk0-dbus-spec-20261020.md`（控制面源码取证）、`PITFALLS` §48 §50

---

## 1. 一页结论

| # | 事实 | 证据 |
|---|---|---|
| 1 | 上一轮留在设备上的 zh-ime 栈**中文其实不可用** | 注入 `nihao` → 输入框得到**字面** `ENTRY=[nihao]`，候选条 0 次 `SetLookupTable` |
| 2 | 真因 = **没装 `fcitx5-gtk3/gtk4`** | `/usr/lib/gtk-3.0/3.0.0/immodules/` 无 `im-fcitx5.so`；`GTK_IM_MODULE=fcitx` 是空设 |
| 3 | 装上后中文立通 | `nihao` + `1` → `ENTRY=[你好]`；截图为 Rime 候选 `1 你好 2 妳好 3 逆號 4 擬好 5 你` |
| 4 | **自编候选条 `candidate-bar` 完全不需要** | 杀掉它之后候选照常出现、`你好` 照常上屏（`ENTRY=[你好你好]`） ⇒ 候选窗由 fcitx5-gtk IM 模块自己画 |
| 5 | fcitx5 若带 `waylandim` 会抢走 IM 槽位 ⇒ squeekboard 被判 `unavailable` ⇒ 键盘不弹 | 必须 `--disable waylandim`；判据 `grep -c 'Wayland native input method protocol: 1' /tmp/fcitx5.log` = 0 |
| 6 | squeekboard 的 `sm.puri.OSK0` 是可靠的**双向**控制面 | `SetVisible(false)` 底部亮度 169→0；`SetVisible(true)` → 169；`Visible` 只读属性同步 |
| 7 | squeekboard **不会**因 GTK 聚焦而自动弹（本机配置下） | 收起后点同一输入框无反应；根因 = GTK 走 fcitx dbus 前端，phoc 收不到 text-input 激活 |
| 8 | 用 fcitx5 kimpanel 的 `SetRelativeSpotRect` 当聚焦信号可补上自动弹出 | `elden-ime-focusd` 日志：`show requested by SetRelativeSpotRect` → `SetVisible(1)`；实测 hide 后新起输入框自动 `Visible=true` |

## 2. 最终架构

```
点输入框 ──► fcitx5 FocusIn ──► kimpanel SetRelativeSpotRect ──► elden-ime-focusd
                                                                     │
                                                                     ▼
                                          sm.puri.OSK0.SetVisible(true)
                                                                     │
                                                                     ▼
                                                     squeekboard 弹出触屏键盘
                                                                     │
                        键盘按键 ──► input-method-v2 ──► 焦点窗口 ──► fcitx5+Rime
                                                                     │
                                    候选（由 fcitx5-gtk 的 IM 模块绘制）→ 上屏中文
```

折叠：`elden-ime-toggle`（应用网格「键盘」图标）→ `SetVisible(false)`；或用 Phosh 自带入口
（长按电源条；据 `reports/ime-osk0-dbus-spec-20261020.md` §2，Phosh 0.55 只有 3 个调用点：
上锁强制收起、电源条长按切换、`available` 变假）。

## 3. 逐个判据的原始证据

### 3.1 缺 fcitx5-gtk（修复前）

```
$ VK_OFF=-8 /tmp/vktype nihao      # 通过 zwp_virtual_keyboard_v1 注入
entry=ENTRY=[nihao]                # 字面字母，fcitx5 未参与
$ ls /usr/lib/gtk-3.0/3.0.0/immodules/ | grep fcitx   # 空
```

安装：`apk add fcitx5-gtk3 fcitx5-gtk4`。装后：

```
immodules/im-fcitx5.so            ← GTK3
gtk-4.0/4.0.0/immodules/libim-fcitx5.so   ← GTK4
/usr/bin/gtk-query-immodules-3.0 → 缓存含 3 条 fcitx 条目（"ja:ko:zh:*"）
```

### 3.2 中文上屏（修复后）

```
$ VK_OFF=-8 /tmp/vktype nihao
$ VK_OFF=-8 /tmp/vktype 1
entry=ENTRY=[你好]
```

截图（`/tmp/final.png`，1904×3040）输入框内容 = `你好`；候选态截图（`/tmp/shot2.png`）显示
`1 你好 2 妳好 3 逆號 4 擬好 5 你 ◀▶`。

### 3.3 自编候选条不必要的证明

```
$ kill <fcitx5-candbar pid>
$ grep -c SetLookupTable /tmp/fcitx5-candbar.log   → 0
$ VK_OFF=-8 /tmp/vktype nihao ; VK_OFF=-8 /tmp/vktype 1
entry=ENTRY=[你好你好]       ← 候选条进程不在，中文照常
```

### 3.4 唤起 / 折叠

```
$ elden-ime-toggle hide  → Visible=(<false>,)  底部亮度 169.1 → 0.0
$ elden-ime-toggle show  → Visible=(<true>,)   底部亮度 → 169.1
$ elden-ime-toggle toggle→ 从 false 翻到 true
$ (hide 后新起输入框)     → Visible 自动 true   ← 触屏唤起
```

`elden-ime-focusd` 日志：

```
=== start pid=11101
ready: owns org.kde.impanel
show requested by SetRelativeSpotRect
SetVisible(1)
```

## 4. 踩到的坑（均已进 PITFALLS）

| # | 坑 |
|---|---|
| 1 | `apk add fcitx5-gtk3` 先报 `file format is invalid or inconsistent`（镜像侧包体坏/截断），换成 `mirrors.ustc.edu.cn` + 用户切到 `ustcnet` 后成功；索引正常不代表包体正常 |
| 2 | **`pkill -f` 自杀**：在 `ssh host 'bash -c ...'` 里写 `pkill -f enttest` 会把执行脚本的 shell 一起杀掉（exit 143，看起来像“设备抽风”） |
| 3 | 自编候选条对 layer-shell 有竞态：`zwlr_layer_surface_v1 code=2 "wrong configure serial"`，打字中途崩 |
| 4 | `zwlr_virtual_pointer` 的绝对坐标要按**逻辑**尺寸（952×1520）给，给 1904×3040 会落到键盘右下角（表现为“敲出 。 ”） |
| 5 | `zwp_virtual_keyboard_v1` 的 keycode 与本机 phoc 有 **-8 偏移**（`VK_OFF=-8`），否则字母全错 |

## 5. 未做 / 边界（诚实标注）

- **自动收起未做**：fcitx5 没有可靠的 FocusOut 信号，`focusd` 只负责唤起。折叠靠触摸图标/Phosh 入口。
- **同一输入框重弹**：键盘手动收起后，再点**同一个已聚焦**输入框不会重弹（无新的 FocusIn）；换输入框或点图标即可。
- **Qt / Waydroid 应用未验**：候选窗是 fcitx5-gtk 画的，Qt 应用需要 `fcitx5-qt`（`apk add` 失败过，见坑 1）；Waydroid 容器内 IME 是另一条线（Android 侧）。
- **冷启动未验**：本轮只做了当前会话内的重启（`squeekboard`/`fcitx5`/`focusd`），**整机重启后的自启未验**（自启项已装：`/etc/xdg/autostart/{elden-ime-focusd,org.fcitx.Fcitx5}.desktop` + `~/.config/autostart/squeekboard.desktop`）。
- **未做上游化**：`focusd` 是本地胶水（fcitx5 kimpanel 缺 FocusOut 语义），不进上游。
