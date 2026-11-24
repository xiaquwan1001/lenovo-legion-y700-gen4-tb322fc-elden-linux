# #715 设备上「agent 不能注入触摸」已过时：`/dev/uinput` + ydotool + 自建虚拟触摸屏都能用（但虚拟**键盘**会压住 OSK）

> 2026-11-24 设备窗轮实测（TB322FC / vk189 / Debian trixie / phosh 0.46）。
> 推翻的口径：此前多处文档（`INDEX.md` §0 2026-11-19 条、`TASKS` §4、`PITFALLS` #685 一族）写「内核未开 `CONFIG_INPUT_UINPUT`、
> 无 `/dev/uinput` ⇒ 锁屏必须人手滑开、agent 无法做桌面内验证」。**现在这四条都不成立。**

## 现态（现查判据）

```sh
ls -l /dev/uinput          # crw-rw----+ root input；ACL 里 user:xuqianhui1001:rw-
zcat /proc/config.gz | grep INPUT_UINPUT      # CONFIG_INPUT_UINPUT=m（uinput.ko 已加载）
ps -eo args | grep '[y]dotoold'               # ydotoold --socket-path=/tmp/ydotool.sock --socket-perm=0666
command -v ydotool wtype grim                  # 三个都在
```

## 三种注入能力（实测）

| 手段 | 能做什么 | 注意 |
|---|---|---|
| `wtype`（zwp_virtual_keyboard） | **真键盘文本**（会话用户 + `WAYLAND_DISPLAY`）：Ctrl+L 聚焦 URL 栏后 `wtype nihao` ⇒ 屏幕上出现 `nihao` | 只在有焦点时有效；**它算硬件键盘**（见下） |
| `YDOTOOL_SOCKET=/tmp/ydotool.sock ydotool mousemove --absolute -x X -y Y` + `click 1` | 指针移动/点击 | **绝对坐标是 0..65535**，要自己换算：`x_abs = x_px*65535/1904`、`y_abs = y_px*65535/3042`。直接把像素当参数会点到左上角（本轮先踩了） |
| **自建虚拟触摸屏** `uinput-touch.c`（gcc 在设备上现编） | **真实触摸事件**（`INPUT_PROP_DIRECT` + `ABS_MT_*`）⇒ phosh 认作触摸输入 | 源码 `tools/uinput-touch.c`（已入库；用法 `cc -O2 -o /tmp/uinput-touch tools/uinput-touch.c`，在设备上用会话用户跑）；用会话用户跑即可（ACL 已授权） |

`uinput-touch` 配方要点：`UI_SET_EVBIT(EV_ABS/EV_KEY)`、`UI_SET_PROPBIT(INPUT_PROP_DIRECT)`、
`ABS_MT_SLOT/TRACKING_ID/POSITION_X/POSITION_Y` + `ABS_X/Y` 上限 65535、`UI_DEV_SETUP(name="elden-virtual-touch")`、
创建后 `usleep(400ms)` 让 libinput 认到；注入序列 = slot0/TRACKING_ID=1/坐标/BTN_TOUCH=1/SYN → 移动 → TRACKING_ID=-1/BTN_TOUCH=0/SYN。

## 关键坑：**虚拟键盘会把 OSK 压住**

phosh 在「检测到硬件键盘」时不展开 OSK，而 `ydotoold virtual device` 在 `/proc/bus/input/devices` 里就是
`Handlers=sysrq rfkill kbd mouse1`（键盘）⇒ 只要 ydotool 在用，OSK 永不展开。处置两条：

- **（a）** `gsettings set sm.puri.phosh.osk ignore-hw-keyboards true`（**实测本机设了仍不展开** ⇒ 疑似需 phosh 重启才生效，未验证）；
- **（b）** 只用**自建虚拟触摸屏**（不造键盘设备）⇒ 触摸点击有效（本轮实测：触摸点 URL 栏后 Firefox 下拉展开、点后导航到 Bing）。

因此「屏上 OSK 打字/候选条」这类判据目前仍偏人手，但**解锁之外的点击/滚动/输入框聚焦已可自动化**。

## 别做的两件

- **不要用 `loginctl unlock-sessions` 想解锁**：实测无效（`LockedHint` 都不回），锁屏仍需真实滑动/手势。
- 注入前先想清楚「最后一次输入是触摸还是键盘」——phosh 的 OSK 展开策略依赖它。
