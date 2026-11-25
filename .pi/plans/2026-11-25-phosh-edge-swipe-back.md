# 2026-11-25 · Phosh/Phoc「边缘内滑 = Back / pop 当前应用」方案（只读规划 lane）

> **§0 是现在的执行口径（2026-11-25 更新：路线① 已实现并在设备端到端 PASS）；§1–§5 是原始规划与取证，保留不改，冲突时以 §0 为准。**

> **数字**：现查社区/上游项目 **14 个**（上游 2 = phoc/phosh；社区 4 = phosh-overlay-gestures/lisgd/sxmo-utils/pmOS；补充 8 = wlrctl/dotool/wtype/wvkbd/ikit/niri/sway/gnome-shell）；上游 phoc/phosh **MR·issue 21 个**（12 issue + 9 MR，全部给 URL/日期）；候选路线 **3 条**；推荐 **1 条**（路线 ①：lisgd + 最小 uinput KEY_BACK + phoc 既有 close keybinding，30 分钟 PoC）。
>
> **口径**
> - 设备现役：Debian trixie、**phoc 0.46.0-1 / phosh 0.46.0-3**、纯触屏 1904×3042、无硬件返回键/导航栏、`/dev/uinput` 可用、osk-stub 单栈（`scripts/ime-single-stack.sh`）。
> - 源码取证基于本机缓存 **`/tmp/ph046/phoc-0.46.0/`、`/tmp/ph046/phosh-0.46.0/`**（0.46.0 原版；`/tmp` 可能被清，见 §5 风险 R6）。`external/phoc-work/phoc` 是 **0.55.1**（Alpine 线，`patches-userland/build-phoc-phosh.sh` 的 `PHOC_VER=0.55.1`），行号与 0.46 不同，勿混用。
> - 所有外部 URL **访问日期 = 2026-11-25**。GitLab 走本机代理（`--noproxy '*'` 对 gitlab.gnome.org 会 406/重置）；sourcehut 的 `/log`、`/commit` 页被 Anubis 拦（418），只能取到 refs 页的相对时间，已如实标注。
> - 本 lane **未 ssh、未改既有文件、未发信**；本文件是唯一新增物。

---

## 0. 执行口径（当前状态，2026-11-25 更新）

### 0.1 目标

设备 TB322FC / SM8750P（Debian trixie，**phoc 0.46.0-1 / phosh 0.46.0-3**）纯触屏、无硬件返回键、无导航栏：
**屏幕左（或右）边缘向内单指滑动 = 关闭当前焦点窗口**，覆盖 Firefox / foot / Waydroid 容器窗口。

明确**不做**：不是浏览器「页面后退」（Firefox 不认 `KEY_BACK`，要后退只能在应用层做）；不是 Android「返回一层」（容器内 back = 路线③，未并入）；不碰 top/bottom 边缘（phosh 的 top-panel/home bar 拖拽已占用，见 §2 路线②冲突面）。

### 0.2 走哪条路线、为什么（结论未变 = 路线①）

**路线①（零 phoc 改动）**：`lisgd` 旁路读触摸屏 evdev 判边缘滑动 → `uinput-back`（uinput 设备，**只广告 `KEY_BACK`+`EV_SYN`**）→ xkb 把 evdev 158 映射为 `XF86Back` → 命中 phoc 既有 `org.gnome.desktop.wm.keybindings close` → `phoc_view_close()`。

理由：① 不动 phoc/phosh ⇒ 回退 = 停一个服务 + 还原一条 gsettings，phoc 升级不用 rebase；② 全链路已实测 GREEN（见 0.3），不需要试错预算；③ 它同时把「要不要上路线②」的三个判据（双动作 / 误触 / OSK 被压）变成可测的量。
路线②（phoc 内部手势，`cursor.c` 挂点见 §2/附录 C、~120–200 行 C + 重编 phoc + `dpkg-divert`）**不上**：上游 phoc **#125 自 2020-04-09 open 至今无对应 MR**，且设备版是 0.46 而仓内 `PHOC_VER=0.55.1`（行号不同、需另取源码）。
路线③（`waydroid shell -- input keyevent 4`，需 root helper）**不上为默认**：只覆盖容器、焦点误判会把 Back 发错目标；宿主 `KEY_BACK` 是否被 Waydroid 转发成 Android back 仍未实测（见 0.6 R6）。

### 0.3 现状：已实现 + 已验（仓内件 / 设备实测）

| 环节 | 件 | 状态 |
|---|---|---|
| 注入器 | `tools/uinput-back.c` + `tools/uinput-back-build.sh`（aarch64 static） | 已入库；`libinput debug-events --show-keycodes` 见 `elden-back KEYBOARD_KEY KEY_BACK(158) pressed/released` |
| 触摸注入测试器 | `tools/uinput-touch.c`（`tap` / `swipe` / **`hold-swipe X1 Y1 X2 Y2 [attach_ms] [steps]`**，默认 attach 6000 ms） | 已入库 |
| 手势 daemon | `packaging/elden-userland/files/usr/local/bin/lisgd-edge-swipe`（按 `N: Name=` 找触摸屏节点、按 DRM modes 读分辨率，`ELDEN_TOUCH_NODE`/`ELDEN_SCREEN_GEOM`/`ELDEN_SWIPE_EDGES` 可覆盖） | 已入库；`systemctl is-active lisgd-edge-swipe` = active+enabled |
| unit | `packaging/elden-userland/out/units/{systemd,openrc}/lisgd-edge-swipe`（源 = `services.tsv`；日志 `/var/log/lisgd-edge-swipe.log`） | 已入库 |
| 键绑定并入 | `scripts/deploy-desktop-shell.sh §15`（幂等把 `XF86Back` 并进 `close`，读回用 GVariant 解析，字串子串不算命中；并判 `lisgd`/`uinput-back` 在位） | 已入库 |

实测结论（设备，2026-11-25）：
- **计划里的关键前提当年写错了**：`gsettings get …wm.keybindings close` 实际 = **`['<Alt>F4']`**（不含 `XF86Back`）⇒ 只发 `KEY_BACK` 时 foot 窗口 **1→1（不关）**；把 `close` 改成 `['<Alt>F4','XF86Back']` 后同一次发键 **2→1（关了）** ⇒ phoc 0.46 的 xkb keymap 确实把 158 映射成 `XF86Back`，binding 也吃得下。**「先验 A1 再验手势」这一步因此是必需的，不是形式。**
- **端到端**：`lisgd -d <触摸屏节点> -g "1,LR,L,*,R,/usr/local/bin/uinput-back"`，用 `hold-swipe` 从左边缘 (8,1500)→(700,1500) 一扫 ⇒ lisgd 日志 `Swipe distance=[691.98]; degrees=[90.00] … Execute /usr/local/bin/uinput-back` ⇒ foot **1→0**。
- **左右两侧都开**：helper 手势表 = `1,LR,L,*` + `1,RL,R,*`；注入复验：右边缘 RL **1→0**、左边缘 LR **1→0**、中部竖划 **1→1（不误触）**。
- 服务级复验 PASS（把 `ELDEN_TOUCH_NODE` 指到注入设备跑一遍）。

### 0.4 零 phoc 改动的 30 分钟 PoC（命令级，可原样复跑=回归跑）

前置：设备上以**会话用户 1001**执行（`XDG_RUNTIME_DIR=/run/user/1001`、`DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus`）。
⚠️ **设备 reboot 会清 `/tmp`** ⇒ 测试工具必须装在 `/usr/local/bin`，否则注入变**静默 no-op**，症状看起来像「手势失效」（已在设备上踩过）。

**步骤 0（2 min）取证 + 备份原值**
```sh
gsettings get org.gnome.desktop.wm.keybindings close      # 记原值，出厂 = ['<Alt>F4']
gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled   # 必须 true（PITFALLS #716 成因①）
dpkg -l phoc phosh | tail -n +6                            # 期望 0.46.0-1 / 0.46.0-3
dpkg -l lisgd | tail -1                                   # 实测 0.3.7-1+b1
command -v lisgd uinput-back                              # 缺则先跑 tools/uinput-back-build.sh + 部署
grep -A6 'N: Name="NVTCapacitiveTouchScreen"' /proc/bus/input/devices   # 期望 Handlers 含 event4
```

**步骤 1（3 min）把 `XF86Back` 幂等并入 `close`**
```sh
python3 - <<'EOF'
import subprocess, ast
k, s = "org.gnome.desktop.wm.keybindings", "close"
cur = ast.literal_eval(subprocess.check_output(["gsettings", "get", k, s]).decode().strip())
if "XF86Back" not in cur:
    cur.append("XF86Back")
    subprocess.check_call(["gsettings", "set", k, s, str(cur)])
print(cur)
EOF
gsettings get org.gnome.desktop.wm.keybindings close        # 期望 ['<Alt>F4', 'XF86Back']
```
（同一逻辑的仓内实现在 `scripts/deploy-desktop-shell.sh §15`。）

**步骤 2（5 min）先验「发 KEY_BACK 就能关窗」（不涉及手势；**失败即止步**，说明注入/绑定问题不是手势问题）**
```sh
uinput-back --list                    # 只打印将广告的能力：应只有 KEY_BACK / EV_SYN
wlrctl toplevel list > /tmp/before
uinput-back && sleep 0.5
wlrctl toplevel list > /tmp/after
diff /tmp/before /tmp/after           # 期望目标 title 消失、行数 -1（实测 foot 2→1）
```
失败时：查 `gsettings` 是否跑在**会话总线**（不是 root 的 dconf）；再试 `uinput-back --combo alt-f4`（只广告 `KEY_LEFTALT`+`KEY_F4`，同样不算 hw keyboard）。

**步骤 3（10 min）接 lisgd，用注入触摸端到端跑**
```sh
# 前台跑便于看日志；-d 必须是步骤 0 找到的触摸屏节点
lisgd -d /dev/input/event4 -w 1904 -h 3042 -t 60 -m 800 -v \
      -g "1,LR,L,*,R,/usr/local/bin/uinput-back"
# 另一路注入设备；hold-swipe = 先建虚拟触摸屏等 attach（默认 6000 ms）再划
tools/uinput-touch hold-swipe 8 1500 700 1500 8000
```
期望：lisgd 打印 `Swipe distance=[691.98]; degrees=[90.00] … Execute …`，`wlrctl toplevel list` 行数 -1。
> ⚠️ **attach 窗口要对齐**：lisgd 刚启动还没认到新设备时给 10 s 不够，**给 20 s 才稳**（服务刚重启时尤其）。

**步骤 4（5 min）固化态校验（已在位则只做校验）**
```sh
systemctl is-enabled lisgd-edge-swipe; systemctl is-active lisgd-edge-swipe  # enabled / active
tail -n 20 /var/log/lisgd-edge-swipe.log      # 期望 node=/dev/input/event4 geom=1904x3042
cat /etc/conf.d/lisgd-edge-swipe 2>/dev/null  # ELDEN_SWIPE_EDGES 默认 LR（左右都开）
```

**步骤 5（5 min）不误触 + 回退演练**
```sh
tools/uinput-touch hold-swipe 900 1500 900 400 8000   # 中部竖划：期望 foot 1→1（实测 PASS）
systemctl disable --now lisgd-edge-swipe              # 回退演练（演练完恢复）
gsettings set org.gnome.desktop.wm.keybindings close "['<Alt>F4']"
```

**失败判据（出现即停，别硬撑）**

| 现象 | 判据 | 处置 |
|---|---|---|
| 步骤 2 不关窗 | A1 失败，且 `--combo alt-f4` 也失败 | gsettings 未在会话总线生效 / `close` 未注册 ⇒ 转路线② |
| lisgd 打不开设备 | stderr `EACCES` / `EBUSY` / `No such device` | `EACCES` ⇒ `input` 组或 udev 规则；`EBUSY` ⇒ 设备被独占（`PITFALLS #656` 同源）⇒ 路线①不可行 |
| A1 过但手势不过 | 手势日志有 Execute 但窗口不关 | 应用抢焦点/双动作 ⇒ 改 `P`（pressed）+`-T 60`，或路线②吞事件 |
| OSK 不再弹 | `journalctl -b \| grep "elden-back.*a keyboard device"` 有输出 | 设备被 udev 标成 `ID_INPUT_KEYBOARD` ⇒ 修 uinput 能力位；别用 `ignore-hw-keyboards` 硬扛（`PITFALLS #715` 实测未即时生效） |

### 0.5 验收判据（可自动判的部分；当前全绿）

| ID | 判据 | 命令 | 期望 / 实测 |
|---|---|---|---|
| **A0** | 前提在位 | `close` 经 GVariant 解析后**含** `XF86Back`（字串子串不算，`['<Control>XF86BackX']` 必须判 MISS）；`dpkg -l phoc` = 0.46.0-1；`command -v lisgd uinput-back` | 0 退出 |
| **A1** | 直接注入能关焦点窗 | `wlrctl toplevel list` 前后 diff + `uinput-back` | 行数 -1（**实测 PASS**） |
| **A2a** | 左边缘手势能关 | `hold-swipe 8 1500 700 1500 8000` + lisgd `degrees=[90.00]` | 行数 -1（**实测 PASS**，foot 1→0） |
| **A2b** | 右边缘手势能关 | `hold-swipe 1900 1500 1200 1500` | 行数 -1（**实测 PASS**，1→0） |
| **A3** | 不误触：中部竖划 | `hold-swipe 900 1500 900 400 8000`，lisgd 不打印 Execute | 行数不变（**实测 PASS**，1→1） |
| **A4** | 注入设备不算 hw keyboard | 开 `phoc-input-device` 日志域（`gdbus call --session --dest mobi.phosh.Phoc.DebugControl … LogDomains`）后跑 `uinput-back`，`journalctl -b \| grep "elden-back"` | **not** a keyboard device |
| **A5** | 服务态 | `systemctl is-enabled/is-active lisgd-edge-swipe`；日志有 node/geom 行 | enabled / active（**实测 PASS**） |
| **A6** | 无崩溃 | `coredumpctl list --since "-10 min" \| grep -c phoc` | 0 |

> A4 的「udev 归类」主机侧已实测只打 `ID_INPUT_KEY`（无 `ID_INPUT_KEYBOARD`），设备侧仍需复核一次。

### 0.6 回退办法（按代价从小到大）

```sh
systemctl disable --now lisgd-edge-swipe                                      # 1) 停手势 daemon
gsettings set org.gnome.desktop.wm.keybindings close "['<Alt>F4']"              # 2) 还原绑定（保留 Alt+F4）
rm -f /usr/local/bin/{uinput-back,lisgd-edge-swipe,elden-swipe-back,elden-swipe-back-left,elden-swipe-back-right}   # 3) 卸件
```
4) 判据自检：重跑 `scripts/deploy-desktop-shell.sh §15` 会报 MISS（A0 红），**不会静默留半套**。
回退**不需要**重装 phoc/phosh —— 本方案根本没改它们（这是选路线①的主要理由）。

### 0.7 需要人做的部分（**仅剩这三条**）

| ID | 场景 | 通过标准 |
|---|---|---|
| **H1** | 真人真机：左边缘（≤10 px 起手）内滑 60–120 px，再右边缘一次 | 窗口关闭；无黑屏/白屏残留；确认手感（左右两侧已注入验过） |
| **H2** | 点输入框弹出 OSK 后：① 在 OSK 键区左边缘滑 ② 屏幕左侧空白区滑 | ① 不关窗、OSK 不消失 ② 关窗后重点输入框 OSK **仍能弹**（证明无 KEYBOARD 能力残留） |
| **H3** | 全屏视频/全屏 Firefox 播放中内滑；锁屏 / 概览 / 无焦点时内滑 | 关的是播放窗口（不是暂停/只退全屏）；锁屏与概览下**无任何动作** |

### 0.8 风险与未决

- **R1 语义**：实现的是「关当前窗口」= Alt+F4 等价，不是页面后退、不是 Android 返回一层。
- **R2 双动作**：lisgd 不消费触摸 ⇒ 应用仍收到这次滑动（Firefox 页面横移、GTK 侧栏/轮播被拖、地图平移）。缓解 = 收窄起手区（`-s`）；根治需路线②吞事件。
- **R3 旋转/缩放**：lisgd `-w/-h` 与 phoc scale 不一致时边缘/阈值要重算；`-o` 只支持 90° 步进。helper 已改成按 DRM modes 读分辨率，旋转后仍需复核。
- **R4 设备生命周期**：suspend/resume、event 节点编号变化 ⇒ helper 每次启动按 `N: Name=` 重找节点（已实现），仍需 unit `Restart=` 兜底。
- **R5 attach 时序**：注入设备存活期 vs lisgd 认设备的延迟要对齐（10 s 不够、20 s 稳）。
- **R6 Waydroid**：宿主 `KEY_BACK` 是否被转发成 Android back **未实测**；若不转发只能走路线③（需 root helper，是否常驻要人拍板）。
- **R7 许可**：lisgd = MIT（可用可改）；`vacuumbeef/phosh-overlay-gestures` **无 LICENSE**（只读思路，不可复制代码）；sxmo-utils = AGPL-3.0（只参考配置思路）。
- **R8 上游**：phoc #125 是唯一合适锚点、5 年半无实现；若上游化要先谈设计（边缘宽/阈值/关对话框还是关 toplevel/是否可配），且须基于 Debian 0.46 而非仓内 `PHOC_VER=0.55.1` 的件。

---

## 1. 上游 / 社区现状（现查）

### 1.1 上游 phoc / phosh：**没有可用的 edge-swipe-back**，只有一个 2020 年开到现在的 feature issue

| # | 项目/条目 | 结论（能否直接用 / 需什么适配 / 许可证 / 最近活动） | 证据（URL + 访问日） |
|---|---|---|---|
| 1 | **phoc**（合成器本体） | **不能直接用**：0.46/0.59 都没有「边缘内滑 → 关闭当前 view」；有完整 `PhocGesture*` 触摸手势框架，但 `on_swipe` 只服务可拖 layer（shell 折叠/展开）。phoc 内实现是路线 ②。**GPL-3.0-or-later**；`main` 最后提交 **2026-11-15**（`Merge branch 'rel-0.59.0'`）。 | https://gitlab.gnome.org/World/Phosh/phoc ；commits API `.../repository/commits?per_page=1` |
| 2 | **phosh**（shell） | **不能直接用**：只有 top-panel / bottom home bar 的自上而下/自下而上拖动（`PhoshDragSurface`），以及概览里「上滑关应用」。左/右边缘无全局手势。**GPL-3.0-or-later**；`main` 最后提交 **2026-11-22**。 | https://gitlab.gnome.org/World/Phosh/phosh |
| 3 | **phoc #125**「Have a back gesture to close dialogs」 | **opened（2020-04-09 建，最后更新 2023-02-17）**：与本任务最接近的上游需求；描述是「像 libhandy 的 back gesture，但是在 shell 层关对话框」。**没有对应 MR**（我按 gesture/swipe/back/edge 搜了 MR，见 1.2）。 | https://gitlab.gnome.org/World/Phosh/phoc/-/work_items/125 |
| 4 | **phoc #82**「Implement global gestures」 | **closed（2019-10-01 → 2022-05-31）**：结论是全局手势由 phosh 的 draggable layer 实现（MR !344），**不含 back**。 | https://gitlab.gnome.org/World/Phosh/phoc/-/work_items/82 |
| 5 | **phoc #128**「Allow to inject fake input events」 | **opened（2020-04-17）**：上游也认为「测试/手势需要注入输入」，倾向 wlroots input backend；至今未做 ⇒ 路线 ① 的 uinput 注入是社区现实解。 | https://gitlab.gnome.org/World/Phosh/phoc/-/work_items/128 |
| 6 | **phoc #400 / #385** | #400 closed「Implement switching apps by swiping left or right on the bottom bar」；#385 opened「Bottom bar gesture…」。**都是底部栏，不是左边缘**。 | https://gitlab.gnome.org/World/Phosh/phoc/-/work_items/400 · `.../385` |
| 7 | **phosh #995**「design: new gesture input for hiding/closing」 | **opened（2023-10-04，最后更新 2023-11-07）**：讨论把「关闭/隐藏」统一到 2 指手势；**只是设计讨论，无实现**。 | https://gitlab.gnome.org/World/Phosh/phosh/-/work_items/995 |
| 8 | **phosh #1251 / #1252**「Add a way to go back to the previous app」 | **closed（均 2025-08-16 创建、当天关闭；notes 为空）** ⇒ 不能引用为「上游已有方案」。 | https://gitlab.gnome.org/World/Phosh/phosh/-/work_items/1251 · `.../1252` |
| 9 | **phosh #296**「Have a back gesture to close dialogs」 | **closed（2020-04-09 当天关闭）**；与 phoc #125 同文。 | https://gitlab.gnome.org/World/Phosh/phosh/-/work_items/296 |
| 10 | **phosh #1137 / #882 / #866** | #1137（closed，2024-11-01）「force quit/close 更易达」；#882（opened，2023-01-09）「底栏加关闭按钮」；#866（opened，2022-12-01）「top/bottom 手势阈值可配」⇒ **上游痛点是「关闭可达性」，但没落到边缘手势**。 | 对应 `/-/work_items/{1137,882,866}` |

### 1.2 上游 MR 检索（`state=all`，关键词 gesture/swipe/back/edge，均 2026-11-25 现查）

| MR | 状态 | 标题 / 与 back 的关系 |
|---|---|---|
| phoc **!344** | merged 2022-05-18 | Gestures and dragable layer surfaces —— 现有触摸手势框架的来源；**不含 back** |
| phoc **!346** | merged 2022-05-30 | gestures: Cancel touch gestures |
| phoc **!828** | **opened 2026-11-20** | layer-shell-effects: Compensate for offset when accepting drag gesture（最近仍活跃） |
| phoc **!58** | merged 2019-11-18 | Add a way to reveal shell on a fullscreen surface（全屏下的「露出 shell」，不是 back） |
| phoc **!294** | opened 2025-10-22 | phosh-private: Add set_exclusive_zone_anchor request |
| phosh **!934** | merged 2022-06-02 | Use swipe gestures to open top-panel and overview |
| phosh **!1078** | closed 2023-12-20 | home: enable home bar app switching using swipe gestures（Draft 关闭） |
| phosh **!655** | merged 2020-12-03 | Swipe to close apps（**概览内上滑关应用**，不是边缘） |
| phosh **!1341** | opened 2026-07-31 | Draft: Implement powerbar app switching |
| phosh **!1942** | merged 2026-08-08 | Zoom to overview - Part 1 |

> **结论**：上游**没有**已合并/在审的 edge-swipe-back；phoc #125 是最合适的上游锚点，但 5 年半无人实现 ⇒ 路线 ② 若做，需要先在上游 issue 里对设计（阈值/边缘宽/关对话框还是关 toplevel/是否可配）。

### 1.3 社区项目逐个评估（14 个里的其余 4 个）

| # | 项目 | 能否直接用 / 需什么适配 / 许可证 / 最近提交 | 证据 |
|---|---|---|---|
| 11 | **vacuumbeef/phosh-overlay-gestures** | **做法可直接抄，代码不建议直接收**：lisgd + `wtype` 发 Alt+F4；用 eww 造透明窄条「挡住右边缘」防手势透传给应用。README 明确「made for Droidian/Phosh」。**许可证：仓库无 LICENSE、GitHub `license=None` ⇒ 默认版权保留，不可再分发**。最后 push **2023-12-13**。 | https://github.com/vacuumbeef/phosh-overlay-gestures （API `/repos/...`、`/contents/README.md`） |
| 12 | **lisgd**（`~mil/lisgd`） | **能直接用（推荐）**：libinput **合成手势** daemon，读 `/dev/input/event*`，按 `nfingers,gesture,edge,distance,actmode,command` 跑命令；`edge=L` 判据 = 起点或终点在左边 50 px 内（`config.def.h:35-38`，可用 `-s` 缩放）；`-t` 为识别阈值 px（默认 125），`-r` 角度容差（默认 15°），`-m` 超时 ms，`-w/-h` 屏幕宽高。**MIT/X Consortium**。master `506ef438`，refs 页显示「1 year, 2 months ago」（≈2024-09，精确日期被 Anubis 拦）；**Debian trixie main 有包 `0.3.7-1`**，Alpine edge 也有包。 | https://git.sr.ht/~mil/lisgd · `.../blob/master/README.md`、`config.def.h`、`LICENSE` · https://sources.debian.org/api/src/lisgd/ · https://pkgs.alpinelinux.org/packages?name=lisgd&branch=edge |
| 13 | **sxmo-utils**（Sxmo） | **不能直接装到 Phosh**，但它是 lisgd 的成熟用法参考：`sxmo_hook_inputhandler.sh` 开头写「This script handles input actions, it is called by lisgd for gestures」。**AGPL-3.0**；`master` 最后提交 **14 小时前**（`63465f8c`，2026-11-25 现查）⇒ 极活跃。注意 AGPL 只影响「分发修改版」，抄配置思路无碍、不要链入闭源分发。 | https://git.sr.ht/~mil/sxmo-utils · `.../blob/master/LICENSE`、`.../configs/default_hooks/sxmo_hook_inputhandler.sh` |
| 14 | **postmarketOS「gesture daemon」** | **未找到独立 daemon**。pmOS wiki 搜索 `gesture` / `lisgd` 均 0 命中（`api.php?action=query&list=search&srsearch=gesture`，2026-11-25）；pmOS 的现实做法就是打包 lisgd（Alpine edge 有包）。**结论：不存在需要评估的 pmOS 专属手势组件。** | https://wiki.postmarketos.org/api.php?action=query&list=search&srsearch=lisgd · https://pkgs.alpinelinux.org/packages?name=lisgd&branch=edge |

### 1.4 其余工具/合成器（补充评估，含「不能用」的原因）

| 项目 | 结论 | 证据 |
|---|---|---|
| **wlrctl** | **不能做手势检测**，只能做注入/查询：`toplevel list/focus/fullscreen`、`keyboard type`、`pointer move`。**MIT**；master `c6bc6082`（refs 页「2 months ago」≈2026-09），v0.2.2；**Debian trixie main 0.2.2-2**。用途：验收时数窗口、PoC 失败时用 `wlrctl keyboard type` 验证「虚拟键盘 = 硬件键盘」路径。 | https://git.sr.ht/~brocellous/wlrctl · https://sources.debian.org/api/src/wlrctl/ |
| **dotool** | **不建议**：GPL-3.0，master `27ec57e5`（「9 months ago」≈2026-02），v1.6；从 stdin 读动作、用 uinput，但会造**完整键盘**（含字母键）⇒ phoc 判为 hw keyboard ⇒ osk-stub `allow_active=false`，OSK 被压（`PITFALLS #715` 同源）。**没有手势识别**。 | https://git.sr.ht/~geb/dotool · `.../blob/master/LICENSE` |
| **wtype** | **只能注入**，MIT，最后 push 2026-10-20；是 `zwp_virtual_keyboard_v1` 客户端 ⇒ phoc `seat_has_keyboard()` 对非 libinput 键盘**无条件 TRUE**（`seat.c:746-762`）⇒ device-state KEYBOARD 能力 ⇒ OSK 被压（退出后能力撤销，但 osk-stub 不会自动重弹）。**PoC 只把它当对照/应急，不作为长期注入器。** | https://github.com/atx/wtype · `/tmp/ph046/phoc-0.46.0/src/seat.c:746` |
| **wvkbd** | **不能当手势 daemon**：GPL-3.0，master `4ae78249`（9 天前，≈2026-11-16），v0.21；它是 OSK（`sm.puri.OSK0` 同类），只能作为「OSK 里加 Back 键」的备选（现役是 osk-stub，不用它）。 | https://git.sr.ht/~proycon/wvkbd · https://github.com/jjsullivan5196/wvkbd |
| **ikit** | **未找到**与 Wayland 输入/手势相关的项目。检索式：GitHub `search/repositories?q=ikit`、`q=ikit wayland keyboard`、`q=ikit compositor`（2026-11-25）——只有同名无关库（CanIKit/iKit 等）。**若你指的是 sxmo 的 `sxmo_keyboard.sh`，那不是独立项目，见 sxmo 行。** | https://api.github.com/search/repositories?q=ikit |
| **niri** | **不能用于 phoc**（独立合成器）。**GPL-3.0**，push 2026-11-24；手势是 touchpad/workspace 级别，没有「触摸屏左边缘 back」。 | https://github.com/niri-wm/niri |
| **sway** | **不能用于 phoc**。**MIT**，push 2026-11-22；`bindgesture` 只覆盖 touchpad（pinch/swipe），触摸屏手势要自己喂 libinput；可作实现参考，不能直接搬。 | https://github.com/swaywm/sway |
| **gnome-shell** | **不能用于 phoc**。**GPL-2.0**，push 2026-11-24；有 touchpad 手势与触摸屏 overview 手势，但绑定在 Mutter/Clutter 上，无法在 phoc 下复用；只能读设计。 | https://github.com/GNOME/gnome-shell |

---

## 2. 三条候选路线

### 路线 ①（推荐）：外部 daemon 读 `/dev/input` → 注入 KEY_BACK（映射到 phoc 既有 `close` keybinding）

**机制**
1. `lisgd` 直接读**触摸屏** `/dev/input/eventN`（libinput，非 grab；和 phoc 并行读同一 evdev 是允许的，phosh-overlay-gestures 在 Droidian/Phosh 上已这样做）。
2. 命中 `1,LR,L,*,R,<命令>`（1 指、左→右、起点/终点在左边缘 50 px 内、释放即触发）后跑注入器。
3. 注入器**不是** wtype/ydotool，而是一个**只广告 `KEY_BACK` 的 uinput 设备**（无字母/回车/空格键）：
   - 0.46 的 `phoc_input_device_get_is_keyboard()` 判据 = `KEY_A && KEY_ENTER && KEY_SPACE` 或 udev `ID_INPUT_KEYBOARD`（`src/input-device.c:304-341`）⇒ 只带 `KEY_BACK` 的设备**不会**被算作 hw keyboard ⇒ 不会给 `zphoc_device_state_v1` 打 `CAPABILITY_KEYBOARD` ⇒ osk-stub 的 `PosHwTracker` 保持 `allow_active=true`（`src/pos-hw-tracker.c:52-66`、`phosh-osk-stub.c:224-240`）⇒ **OSK 不被压**。这是与 `PITFALLS #715`（ydotool/wtype 虚拟键盘压 OSK）的关键区别。
   - **主机侧对照实验（2026-11-25，本机 Ubuntu + libinput 1.31.1）**：同一份「只广告 `KEY_BACK`」的 uinput 探针创建后，`/proc/bus/input/devices` = `Handlers=kbd eventN`，udev 属性只有 `ID_INPUT=1` / `ID_INPUT_KEY=1`（**没有** `ID_INPUT_KEYBOARD`），`libinput list-devices` = `Capabilities: keyboard` ⇒ 设备会被 libinput/wlr 当键盘建出来并送 key，但按 phoc 0.46 的三项判据推断 `is_keyboard=false`（设备侧仍需 A5 复核，见 R2）。
4. 按键到达 phoc 后，`KEY_BACK`（evdev 158）在默认 xkb keymap 里是 `<I166> = 166`、`inet(evdev)` 映射为 **`XF86Back`**（本机 `/usr/share/X11/xkb/keycodes/evdev:241`、`symbols/inet:138`）。phoc 0.46 的 `org.gnome.desktop.wm.keybindings close` 绑定（`src/keybindings.c:588`）解析 `XF86Back`（`phoc_parse_accelerator` 先试 `Back` 失败、再试 `XF86Back`，`src/keybindings.c:389-410`）⇒ 走进 `handle_close`（`:156-163`）⇒ `phoc_view_close(view)`（`src/view.c:2255`）。**keybinding 命中后事件被消费、不再转给应用**（`src/keyboard.c:421-456`）。
5. 所以「KEY_BACK → pop」成立，**前提是把 `close` 扩成 `['<Alt>F4','XF86Back']`**（只加不删，保留硬件键盘 Alt+F4）。**不改 phoc、不重编。**

**lisgd 手势配置长什么样**（语法取自 lisgd README/config.def.h，已核对 `lisgd.c`）：
```sh
lisgd -d /dev/input/eventN -w 1904 -h 3042 -t 60 -m 400 -r 20 \
  -g "1,LR,L,*,R,/usr/local/bin/elden-back"
```
- `1` = 单指；`LR` = 左→右；`L` = 左边缘（起点或终点距左边 ≤ `50 * -s` px）；`*` = 距离档不筛；`R` = 抬手触发。`-t 60` = 位移 ≥60 px 才识别（满足「内滑 60 px」）；`-r 20` = 方向容差 ±20°（防斜滑误触）；`-m 400` = 400 ms 内完成。
- 若想「按下即触发」（不等抬手），用 `P` + `-T 60`（pressed 阈值），但会牺牲「滑动中取消」的手感，**PoC 先用 R**。

**改动量级**：新增 1 个 ~60 行 C（`tools/uinput-back.c`）+ 1 个 5 行 wrapper/命令 + 1 个 systemd user unit + 1 条 gsettings；**不动 phoc/phosh**。
**能否上游**：作为 phoc 补丁不能；作为「发行版/设备侧 daemon」可以独立存在（phosh-overlay-gestures 的先例，但它无许可证，不能直接复用其代码）。若要进上游，属于 phosh 生态的「外部工具」，需另立项目/文档，不必等 phoc。
**回归面**：
- `close` keybinding 扩一条 ⇒ 硬件键盘按 `XF86Back` 也会关窗（多数键盘没有该键；有则行为改变，可接受但需记录）。
- 应用仍会收到这次触摸（lisgd 只旁路读，不消费）⇒ **可能双动作**：Firefox 页面横移、GTK 侧栏/轮播被拖、地图平移。缓解：从最左 5–10 px 起手（应用通常在此不响应），或路线 ② 由 phoc 吞掉。
- lisgd 对设备节点权限（`input` 组）、suspend/resume 后设备重建（需重启 lisgd）、屏幕旋转（`-o`）敏感。
- 注入器若被 udev 标成 `ID_INPUT_KEYBOARD` ⇒ OSK 被压；主机侧已实测不会（见上），设备侧仍用 §3 A5 复核。

### 路线 ②：phoc 内部实现（新增一个边缘 swipe gesture，直接 `phoc_view_close()`）

**机制**：phoc 0.46 已经把触摸事件喂进手势系统：
- `src/cursor.c:1540`（TOUCH_BEGIN）、`:1628`（TOUCH_UPDATE）、`:1591`（TOUCH_END）调用 `handle_gestures_for_event_at()`（`:681`）；
- 手势对象在 `phoc_cursor_init()` 创建（`src/cursor.c:1169-1194`）：现有 `PhocGestureDrag` + `PhocGestureSwipe`；`on_swipe`（`:1126-1163`）只处理 draggable layer 的 fling。
- 关闭入口：`phoc_seat_get_focus_view()`（`src/seat.c:1248`）→ `phoc_view_close()`（`src/view.c:2255`）。
- 吞事件：像 `on_drag_update` 一样在越过阈值后 `send_touch_cancel()`（`src/cursor.c:1082-1091`），应用收到 down+cancel 而不是完整 swipe。

**建议挂点（最小 patch）**
1. `src/cursor.c:1169-1194`：再建一个 `PhocGestureDrag`（或新增 `PhocGestureEdgeBack`），接 `drag-begin/update/end/cancel`。
2. `begin`：记录起点 `(lx,ly)`；若 `lx > EDGE_PX`（如 60）直接 `phoc_gesture_set_state(..., DENIED)`；若起点命中 layer surface（`phoc_desktop_layer_surface_at`）也 DENIED（**OSK 弹出时左边缘落在 OSK 区域就不触发**）。
3. `update`：`off_x >= 60 && fabs(off_y) <= off_x * 0.5` → `phoc_view_close(phoc_seat_get_focus_view(seat))` + `send_touch_cancel()` + 标记已触发（防重复）。
4. `end/cancel`：清理。
5. 可配化：`sm.puri.phoc.gschema.xml` 加 `edge-back-width`/`edge-back-threshold`（上游化必需，否则硬编码不接受）；或先读 `PHOC_EDGE_BACK_*` 环境变量做 PoC。

**冲突面（必须逐条测）**
- 现有 `PhocGestureSwipe`（draggable layer fling）：左边缘一般没有 layer，但 **OSK** 是 `namespace=="osk"` 的 layer（`src/layer-shell.c:258`），且会被 phoc 提升到 overlay（`src/layer-shell.c:452-501`）⇒ 起点在 OSK 上时必须让行。
- phosh 的 top-panel / home bar 拖动是 **draggable layer surface** 路径（phosh `src/drag-surface.c`，top-panel `:39/436`，home `:31/730`）⇒ 上下边缘已占用，**别碰 top/bottom**。
- `phoc_handle_shell_reveal()`（`src/cursor.c:778`）在全屏 surface 上负责「露出 shell」，也是触摸路径，别把它的判定顺序打乱。
- 手势 claim 与 `wlr_seat_touch` grab 的交互（0.46 有 `should_ignore_touch_grab`，`src/cursor.c:356-368`）⇒ 需要确认 cancel 不会误伤 OSK 的 grab。

**改动量级**：~120–200 行 C + 可能 1 个 gschema key；要重编 phoc、`dpkg-divert` + `apt-mark hold`（`scripts/phoc-install.sh`）。
**能否上游**：**可以**（phoc #125 就是它），但上游 5 年半没做，预期需要先讨论设计（边缘宽度/阈值/关「对话框」还是「toplevel」/是否可配/是否只对全屏生效）。当前 `build-phoc-phosh.sh` 构建的是 **0.55.1（Alpine 线）**，设备是 **0.46.0-1**，需另取 Debian 0.46 源码（`apt-get source phoc=0.46.0-1` 或本机 `/tmp/ph046/phoc-0.46.0.tar.xz`），**不能拿 0.55.1 的件硬塞**。
**回归面**：最大。触摸输入、shell reveal、OSK 提升、draggable layer、窗口焦点/关闭语义全部在改动路径上；每次 phoc 升级都要 rebase。

### 路线 ③：Waydroid 容器内 Back 的单独通路

**机制**：Waydroid 在 phoc 眼里是**一个** Wayland toplevel（Android 内部窗口栈对宿主不可见）⇒ `phoc_view_close()` 会关掉整个容器 UI，**不是** Android back。因此需要：
- 宿主 daemon 判断「当前焦点窗口是 Waydroid」：`wlrctl toplevel list` 看 app-id/title（phoc 0.46 有 `wlr_foreign_toplevel_manager_v1`，`src/desktop.c:657`）；
- 是则执行 `waydroid shell -- input keyevent 4`（Android `input` 命令；等价的 `KEYCODE_BACK`=4）。仓库已有 `waydroid shell -- …` 的大量先例（`scripts/waydroid-proxy-setup.sh`、`scripts/waydroid-haptics-bake-vendor.sh`）。
- 约束：`waydroid shell` 走 `lxc-attach`，**需要 root**；会话用户 1001 不能直接跑 ⇒ 需要 root helper（Unix socket / systemd service / 已配置的 adb `adb shell input keyevent 4`，adb 路径参考 `scripts/waydroid-proxy-setup.sh:77-81`）。
- **待实测**：宿主注入的 `KEY_BACK` 是否会被 Waydroid 的 Wayland 客户端转发成 Android back（若会，路线 ① 直接覆盖 Waydroid，路线 ③ 就只剩「Android 内 IME/弹窗的 back」边界情况）。
**改动量级**：1 个 wrapper 脚本 + 1 个 root helper（~30 行）；**不改 phoc**。
**能否上游**：不需要上游；这是设备侧适配（Waydroid 自身已有 `input keyevent` 能力）。
**回归面**：小，但**只能覆盖容器**；误判（焦点判断错）会把 Back 发给 Android 而不是关闭原生窗口 ⇒ 需严格按 app-id 判断，判不到就回落路线 ①。

---

## 3. 验收判据（原始规划；**以 §0.5 为准**，本条保留 A4/A7 等更细的取证写法）

### 3.1 可脚本化（自动）

设备上以**会话用户 1001**执行（`XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus`）。

| ID | 判据 | 命令/证据 |
|---|---|---|
| **A0** | 前置：`close` 键绑定含 `XF86Back`，且 phoc 是 0.46 发行版件 | `gsettings get org.gnome.desktop.wm.keybindings close` 输出含 `XF86Back`；`dpkg -l phoc` = `0.46.0-1` |
| **A1** | **直接注入**（不经手势）能关焦点窗口 | `wlrctl toplevel list > /tmp/before`；`/usr/local/bin/uinput-back`；`sleep 0.5`；`wlrctl toplevel list > /tmp/after`；`diff` 显示目标 title 消失、行数 -1 |
| **A2** | **手势**（lisgd）能关焦点窗口 | 先起持久虚拟触摸屏（见 §4 步骤 4），`lisgd -d <该 event 节点> -t 60 …`，`uinput-touch swipe 20 1500 400 1500 20 1904 3042`，重复 A1 的 `wlrctl` 对比 |
| **A3** | **不误触**：左边缘纵向滚动不关窗 | 同 A2 但 `uinput-touch swipe 20 1500 20 1200`（dy=300, dx=0）；`wlrctl` 行数不变；lisgd `-v` 打印的识别方向不是 `LR` |
| **A4** | 阈值：50 px 不触发、70 px 触发 | `swipe 20 1500 70 1500` 不关；`swipe 20 1500 100 1500` 关（注意 `-t 60` 与起点 x=20 ⇒ 位移 50/80） |
| **A5** | **注入设备不被算 hw keyboard**（OSK 硬前提） | 先 `gdbus call --session --dest mobi.phosh.Phoc.DebugControl --object-path /mobi/phosh/Phoc/DebugControl --method org.freedesktop.DBus.Properties.Set mobi.phosh.Phoc.DebugControl LogDomains "<['phoc-input-device']>"`，再跑 `uinput-back`，`journalctl -b \| grep -E "elden-back.*(not )?a keyboard device"` 应为 **not a keyboard device**；同时 `gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled` = true，Focus 输入框后 OSK 仍可见 |
| **A6** | 无崩溃/无核心转储 | `coredumpctl list --since "-5 min" \| grep -c phoc` = 0；`journalctl -b -p err \| grep -i phoc` 无新增 |
| **A7** | suspend/resume 后仍可用（lisgd 要能重连设备） | 手动 suspend→resume，再跑 A2；失败则 systemd unit 需 `Restart=always` + udev `add` 触发重启 |

### 3.2 需人手（H）

| ID | 场景 | 通过标准 |
|---|---|---|
| **H1** | 真手指：全屏 Firefox 内，从左边缘（≤10 px 起手）向右滑 60–120 px | 窗口消失，回到上一窗口或概览；无白屏/黑屏残留；无「只关了一半」的输入法残留 |
| **H2** | 同一位置**上下滚动**网页；斜 30° 滑 | 页面正常滚动，不关窗（lisgd `-r 20` 不应命中 LR） |
| **H3** | 点地址栏弹出 OSK 后：① 在 OSK 键区左边缘滑；② 在屏幕左侧空白区滑 | ① 不关窗、OSK 不消失；② 关窗后再次点输入框，OSK **仍能弹**（证明没有 hw-keyboard 能力残留） |
| **H4** | 全屏视频（Firefox/播放器）播放中内滑 | 关闭播放窗口（不是暂停/退出全屏）；进度不残留后台播放 |
| **H5** | 锁屏、概览、无焦点桌面：左边缘内滑 | 无任何动作；不误触发「解锁/切应用」 |
| **H6** | Waydroid 前台 | 接入路线 ③ 时：Android 返回一层；未接入时：不应误杀容器窗口（应无动作或按设计回落到路线 ①） |

---

## 4. 推荐路线 + 30 分钟 PoC（原始规划；**以 §0.4 为准**，本条保留当时的失败判据与 udev 兜底讨论）

**推荐：路线 ①**。理由：不动 phoc/phosh（回退 = 停 daemon + 恢复 gsettings），能 30 分钟内证伪/证实核心假设，且可把「是否值得上路线 ②」的判据（双动作/误触/OSK）先量出来。

### 4.1 30 分钟时间盒

**0–5 min：前置与备份**
```sh
export XDG_RUNTIME_DIR=/run/user/1001
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus
gsettings get org.gnome.desktop.wm.keybindings close    # 记下原值（通常 ['<Alt>F4']）
gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled   # 必须 true
dpkg -l phoc phosh | tail -n +6                          # 期望 0.46.0-1 / 0.46.0-3
# 触摸屏 event 节点：
for e in /dev/input/event*; do
  udevadm info -q property -n "$e" 2>/dev/null | grep -q '^ID_INPUT_TOUCHSCREEN=1' && \
    echo "$e  $(cat /sys/class/input/$(basename $e)/device/name 2>/dev/null)"
done
```

**5–15 min：验证「KEY_BACK ⇒ close」这条链（不涉及手势）**
```sh
gsettings set org.gnome.desktop.wm.keybindings close "['<Alt>F4', 'XF86Back']"
gsettings get  org.gnome.desktop.wm.keybindings close
# 造注入器（源码见附录 B；先放 /tmp 编，验证后再入库）
cc -O2 -o /usr/local/bin/uinput-back /tmp/uinput-back.c
# 打开两个窗口（任一已安装终端/Firefox），确认焦点在目标窗口：
wlrctl toplevel list
uinput-back
sleep 0.5
wlrctl toplevel list          # 目标 title 应消失
```
- **通过** ⇒ 链路成立，继续手势。
- **失败** ⇒ 先看 `journalctl -b | grep -i "keyboard\|XF86\|close"`；再试「注入 Alt+F4」变体（`uinput-back --combo alt-f4`，设备只广告 `KEY_LEFTALT`+`KEY_F4`，同样没有字母/回车/空格 ⇒ 仍不算 hw keyboard）；仍失败则 phoc 的 gsettings 热更新没生效（`gsettings` 必须在会话总线上跑，`PITFALLS #103`），重启会话再试。**这一步失败就不要往下做手势**（说明注入/绑定有问题，不是手势问题）。

**15–25 min：接 lisgd（真人手指验证）**
```sh
apt-get install -y --no-install-recommends lisgd     # trixie main 0.3.7-1
# 直接前台跑，便于看日志；-d 用上面找到的触摸屏节点
lisgd -d /dev/input/eventN -w 1904 -h 3042 -t 60 -m 400 -r 20 -v \
  -g "1,LR,L,*,R,/usr/local/bin/uinput-back"
```
- 真人：左边缘内滑 60–120 px → 窗口关；纵向滚 → 不关；OSK 场景见 H3。
- 若 `-w/-h` 与实际逻辑尺寸不符（phoc 可能开了 scale），用 `wlr-randr` 查逻辑尺寸后替换；`-s` 可缩放 50 px 边缘宽。

**25–30 min：固化 + 回退**
```sh
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/elden-edge-back.service <<'EOF'
[Unit]
Description=Left-edge swipe to Back (lisgd + uinput KEY_BACK)
After=graphical-session.target
PartOf=graphical-session.target

[Service]
ExecStart=/usr/bin/lisgd -d /dev/input/eventN -w 1904 -h 3042 -t 60 -m 400 -r 20 -g "1,LR,L,*,R,/usr/local/bin/uinput-back"
Restart=always
RestartSec=2

[Install]
WantedBy=graphical-session.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now elden-edge-back.service
systemctl --user status elden-edge-back.service --no-pager
```
回退：
```sh
systemctl --user disable --now elden-edge-back.service
gsettings set org.gnome.desktop.wm.keybindings close "['<Alt>F4']"
```
> `-d` 写死 event 节点在 suspend/热插拔后会失效（R4）；PoC 先用 udev `add` 触发 `systemctl --user restart` 的规则兜底，稳定后再考虑用 `/dev/input/by-id/...`（触摸屏一般没有 by-id，则只能靠 udev 规则）。

### 4.2 失败判据（什么时候放弃路线 ①）

| 现象 | 判据 | 处置 |
|---|---|---|
| `uinput-back` 单独不关窗 | A1 失败，且 Alt+F4 变体也失败 | 查 gsettings 是否热生效；查 `phoc` 是否真的注册了 `close`（`gsettings` 在**会话总线**、不是 root 的 dconf）；仍失败 ⇒ 路线 ② |
| lisgd 打不开设备 | stderr `EACCES`/`EBUSY`/`No such device`；`ls -l /dev/input/eventN` 非 `input` 组可读 | 加 `input` 组/udev 规则；`EBUSY` 说明被独占（`PITFALLS #656`），路线 ① 不可行 |
| 手势触发但应用不关 | A2 失败而 A1 通过 | 说明「应用收到触摸后抢了手势/焦点变了」；改用 `P`（pressed）+ `-T 60`，或路线 ② 吞事件 |
| OSK 不再弹 | A5 失败（日志出现 `a keyboard device`） | 注入器被 udev 标了 `ID_INPUT_KEYBOARD`；用 `sm.puri.phosh.osk ignore-hw-keyboards true` 兜底（`PITFALLS #715` 说未即时生效）或路线 ② |
| 应用双动作（页面横向拖动 + 关窗） | H1 观察到页面位移/侧栏被拖 | 收窄边缘起手区（`-s 0.2` → 10 px）或路线 ② |
| 全屏视频不关 / 只退出全屏 | H4 失败 | 记录 app-id；可能是该应用对 `xdg_toplevel.close` 的处理差异，改用 `phoc` 内 `phoc_view_close`（路线 ②）或 `wlrctl` 查 app-id 后定向处理 |

---

## 5. 风险与未决（本 lane 不替你拍板的点）

- **R1（语义）**：本方案实现的是「**关闭当前窗口/应用**」，不是浏览器「页面后退」、也不是 Android「返回一层」。Firefox/终端上等价于 Alt+F4；Waydroid 需要路线 ③。若你要的是「页面后退」，必须在应用层（Firefox `Alt+Left`？Firefox 不认 KEY_BACK）另做，不在本方案。
- **R2（上机面）**：本 lane 不能 ssh ⇒ 「设备侧 udev 是否同样只打 `ID_INPUT_KEY` 而不打 `ID_INPUT_KEYBOARD`（主机侧已测得这一结果，但设备是 Debian trixie）」「lisgd 能否与 phoc 并行读同一 evdev」「Waydroid 是否转发宿主 KEY_BACK」三条**未实测**；A5/H6 是它们的判据。
- **R3（双动作）**：lisgd 不消费触摸，应用仍会收到这次滑动。这是路线 ① 相对路线 ② 的结构性缺点；H1/H2 是判据。
- **R4（设备生命周期）**：suspend/resume、`/dev/input/eventN` 编号变化会让写死 `-d` 的 lisgd 失效；需要 udev `add`/`systemd` 兜底（A7）。
- **R5（旋转/缩放）**：lisgd 的 `-o` 是 90° 步进，phoc 的 scale 会让 `-w/-h` 与实际逻辑尺寸不一致 ⇒ 边缘/阈值在竖横屏切换后要复核（H1 加做横屏一次）。
- **R6（源码/构建）**：`/tmp/ph046` 是缓存，可能被清；仓内 `build-phoc-src-0.5*` 是 **0.55/0.58/0.59**，不是设备 0.46。路线 ② 开工前必须先取得 Debian `0.46.0-1` 源码并确认 `patches-userland/build-phoc-phosh.sh` 的版本口径（它现在写 0.55.1）。
- **R7（上游/许可）**：`phosh-overlay-gestures` **无许可证**，只能读思路、不能复制代码；lisgd 是 MIT，可放心用/改；sxmo-utils 是 AGPL-3.0，**只参考配置思路**，不要把其脚本并进本项目分发。
- **R8（Waydroid root）**：路线 ③ 需要 root helper；设备当前是否允许 1001 免密 sudo / 是否愿意常驻 root 服务，未定（本 lane 不替你定）。

---

## 附录 A：lisgd 手势字段（已按 `lisgd.c` 核对）

```
-g "nfingers,gesture,edge,distance,actmode,command"
  nfingers : 1..n
  gesture  : LR RL DU UD DLUR URDL ULDR DRUL
  edge     : * N L R T B TL TR BL BR
             （判据 = 起点或终点在边内；左右边宽 = edgesizeleft/right * -s，默认 50 px）
  distance : * S M L（按屏幕宽/对角线 33%/66% 分档；不是像素）
  actmode  : R（抬手）| P（按下；默认值，可省略）
command   : shell 命令
其他：-t 识别阈值 px（默认 125）、-T pressed 阈值（默认 60）、-r 角度容差（默认 15°）、
      -m 超时 ms（默认 800）、-o 旋转 0..3、-w/-h 屏幕宽高、-s 边缘缩放
```

## 附录 B：`tools/uinput-back.c` 最初草案（**已实现并入库**，现役件见 `tools/uinput-back.c`：多了 `--repeat/--delay-ms/--list/--dry-run`，`CREATE_SETTLE_MS=400`）

```c
/* uinput-back — 只广告 KEY_BACK 的虚拟键盘，按一次即销毁。
 * 为什么不广告 KEY_A/ENTER/SPACE：phoc 0.46 的 is_keyboard 判据要求这三键
 * （src/input-device.c:304-341），否则 device-state 会打 KEYBOARD 能力，osk-stub 压掉 OSK。
 * 用法: uinput-back [--combo alt-f4]
 */
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <linux/uinput.h>
#include <sys/ioctl.h>

static int fd;
static void emit(int t, int c, int v) {
    struct input_event e = {0};
    e.type = t; e.code = c; e.value = v;
    if (write(fd, &e, sizeof e) != sizeof e) perror("write");
}
static void syn(void) { emit(EV_SYN, SYN_REPORT, 0); }

int main(int argc, char **argv) {
    int combo = argc > 1 && !strcmp(argv[1], "--combo");
    fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) { perror("open /dev/uinput"); return 1; }
    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    ioctl(fd, UI_SET_EVBIT, EV_SYN);
    if (combo) { ioctl(fd, UI_SET_KEYBIT, KEY_LEFTALT); ioctl(fd, UI_SET_KEYBIT, KEY_F4); }
    else       { ioctl(fd, UI_SET_KEYBIT, KEY_BACK); }

    struct uinput_setup us = {0};
    snprintf(us.name, UINPUT_MAX_NAME_SIZE, "elden-back");
    us.id.bustype = BUS_VIRTUAL; us.id.vendor = 0x1; us.id.product = 0x3;
    ioctl(fd, UI_DEV_SETUP, &us);
    if (ioctl(fd, UI_DEV_CREATE) < 0) { perror("UI_DEV_CREATE"); return 1; }
    usleep(400000);              /* 等 libinput/phoc 认到设备并装好 keymap */

    if (combo) {
        emit(EV_KEY, KEY_LEFTALT, 1); syn();
        emit(EV_KEY, KEY_F4, 1); syn();
        emit(EV_KEY, KEY_F4, 0); syn();
        emit(EV_KEY, KEY_LEFTALT, 0); syn();
    } else {
        emit(EV_KEY, KEY_BACK, 1); syn();
        emit(EV_KEY, KEY_BACK, 0); syn();
    }
    usleep(100000);
    ioctl(fd, UI_DEV_DESTROY);
    close(fd);
    return 0;
}
```

> 注意：PoC 阶段把 `elden-back` 建成**短生命周期**设备（每次手势创建+销毁）；若实测 `UI_DEV_CREATE→key` 之间 400 ms 不够（phoc 未装好 keymap），把 sleep 加到 800 ms 或改成常驻设备（常驻就要确保不被 udev 标 `ID_INPUT_KEYBOARD`，A5 判据覆盖）。

## 附录 C：0.46 源码 file:line 索引（本文件引用的全部点位）

| 事实 | 位置 |
|---|---|
| 触摸 down/up/motion 入口 | `phoc/src/seat.c:215 / 233 / 247`；listener 连接 `:646-653` |
| 触摸已喂手势系统 | `phoc/src/cursor.c:1540 / 1591 / 1628`；`handle_gestures_for_event_at()` `:681` |
| 手势对象创建（drag/swipe） | `phoc/src/cursor.c:1169-1194` |
| 现有 swipe 只做 layer fling | `phoc/src/cursor.c:1126-1163` |
| 吞触摸的既有做法 | `phoc/src/cursor.c:1082-1091`（`send_touch_cancel`） |
| `should_ignore_touch_grab` | `phoc/src/cursor.c:356-368` |
| shell reveal | `phoc/src/cursor.c:778`；阈值 `src/cursor.h:31` |
| 关闭窗口 API | `phoc/src/view.c:2255` |
| 焦点 view | `phoc/src/seat.c:1248` |
| `close` keybinding 注册 | `phoc/src/keybindings.c:588`；`handle_close` `:156-163`；解析 `:389-410` |
| 绑定命中后不转发 | `phoc/src/keyboard.c:421-456` |
| hw keyboard 判定 | `phoc/src/input-device.c:304-341`；`seat_has_keyboard()` `src/seat.c:746-762` |
| device-state KEYBOARD 能力 | `phoc/src/device-state.c:395-440` |
| OSK layer 识别/提升 | `phoc/src/layer-shell.c:258`、`:452-501` |
| foreign-toplevel | `phoc/src/desktop.c:657` |
| DebugControl（TouchPoints/LogDomains） | `phoc/src/dbus/mobi.phosh.Phoc.DebugControl.xml:14-30`；`src/server.c:750-765` |
| osk-stub 压 OSK 的分支 | `phosh-osk-stub/src/phosh-osk-stub.c:224-240`；`src/pos-hw-tracker.c:52-66` |
| phosh 上/下边缘拖动 | `phosh/src/top-panel.c:39,436`；`phosh/src/home.c:31,730`；`phosh/src/drag-surface.c` |
| phosh 无 back D-Bus | `phosh/src/dbus/org.gnome.Shell.xml`（只有 ShowOSD/GrabAccelerator/Screenshot 等，无 close/back） |
