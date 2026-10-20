# 五十一、触屏中文输入法：三处「看着在跑其实不通」

- 日期：2026-10-20
- 主题：Phosh 上把「点输入框 → 触屏键盘 → 拼音 → 候选 → 上屏中文」跑通的三个硬约束
- 结论：**① 没 `fcitx5-gtk` 中文完全不工作；② fcitx5 必须 `--disable waylandim`（把 IM 槽位让给 squeekboard）；
  ③ 自编候选条不需要**（候选由 `fcitx5-gtk` 的 IM 模块自绘）。完整验收见 `reports/zh-ime-touch-chinese-20261020.md`。

## 1. 「进程都在跑」≠「能用」

设备上 `fcitx5`、`wvkbd`、自编 `candidate-bar` 三个进程都在，候选条日志也有 `dbus ready`。
实测注入 `nihao`：输入框得到 **字面 `nihao`**，候选条 **0 次 `SetLookupTable`**。

判据：**只看「有没有进程」必错**，要看「按键有没有变成候选」。最小探针 =
`zwp_virtual_keyboard_v1` 注入字符串 + 一个 GTK `GtkEntry` 窗口回读文本
（工具：`patches-userland/zh-ime/vktype.c` + `enttest2.py` 型窗口）。

## 2. 坑 1：`fcitx5-gtk` 是硬依赖，缺它 `GTK_IM_MODULE=fcitx` 是空设

```
/usr/lib/gtk-3.0/3.0.0/immodules/   无 im-fcitx5.so
gtk-query-immodules-3.0            缓存里没有 fcitx
```
⇒ GTK 根本不加载 fcitx IM context，按键原样进控件。`apk add fcitx5-gtk3 fcitx5-gtk4` 后立刻正常
（缓存出现 3 条 `fcitx`/`fcitx5` 条目，locale 覆盖 `ja:ko:zh:*`）。

**装包时的一个陷阱**：`apk add fcitx5-gtk3` 曾报
`ERROR: fcitx5-gtk-5.1.6-r0: file format is invalid or inconsistent`（三个子包全错），但
`apk update` 的索引是好的、`curl` 拿 APKINDEX 也 200 ⇒ **索引通 ≠ 包体完整**。
换镜像（`mirrors.ustc.edu.cn`）+ 换无线网（用户切到 `ustcnet`）后成功。
判断方法：`apk fetch <pkg>` 后与 APKINDEX 里的 sha256 对比，或主机下载后 `scp` 过去装。

## 3. 坑 2：IM 槽位只有一个，fcitx5 抢走它 squeekboard 就哑了

`zwp_input_method_v2` 每个 seat 只允许一个 client（`PITFALLS` §48）。fcitx5 默认加载 `waylandim`
⇒ 抢到槽位 ⇒ squeekboard 收到 `unavailable` ⇒ **键盘不弹**。
⇒ fcitx5 必须 `--disable waylandim`；判据：

```sh
grep -c "Wayland native input method protocol: 1" /tmp/fcitx5.log   # 必须 0
```

## 4. 坑 3：自编候选条是**多余**的（且会崩）

杀掉 `candidate-bar` 后候选照常出现、`你好` 照常上屏 ⇒ **候选窗是 `fcitx5-gtk` 的 IM 模块自己画的**，
kimpanel 那条路完全不需要。而且自编条对 wlroots layer-shell 有 ack 竞态：
打字中途 `protocol error iface=zwlr_layer_surface_v1 code=2`（= `wrong configure serial`）后进程退出。
已整体移入 `patches-userland/zh-ime/withdrawn/`。

## 5. 补：「点输入框自动弹键盘」需要自己搭桥

squeekboard 靠 `zwp_text_input_v3` 的 activate 决定是否弹出，而本机中文走
`GTK_IM_MODULE=fcitx`（dbus 前端）⇒ **GTK 不用 text-input-v3** ⇒ phoc 永远不通知 squeekboard
⇒ 键盘只在启动时显示、或靠 `sm.puri.OSK0.SetVisible()` 手动控制。

桥 = `elden-ime-focusd`：占 `org.kde.impanel`，把 fcitx5 的
`SetRelativeSpotRect`（FocusIn / 光标矩形变化时**稳定**发；`Enable` 在本机 v5.1.19 反而不发）
当聚焦信号，调 `sm.puri.OSK0.SetVisible(true)`。
**自动收起没有可靠信号**（fcitx5 无 FocusOut 语义）⇒ 收起走触摸图标 / Phosh 入口，不硬凑。

## 6. 判据清单（下次一条命令验证）

```sh
bash scripts/deploy-zh-ime.sh     # 7 项：不留 waylandim / OSK0 有 owner / show / hide / toggle / focusd / gsettings
```

中文上屏（需 GUI 会话）：

```sh
VK_OFF=-8 <zh-ime>/vktype nihao && VK_OFF=-8 <zh-ime>/vktype 1   # 期望输入框出现「你好」
```
