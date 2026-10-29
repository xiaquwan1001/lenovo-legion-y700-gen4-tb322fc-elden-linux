# G3 Steam 判据②「截图」路径清单 + captive-portal 绕过草案（2026-10-29，纯主机）

> lane: g3-steam-shots · **纯主机任务，全程未碰设备（无 ssh / 无 adb / 无 fastboot）**
> 背景：`reports/g3-steam-20261028.md` §6.3 + `PITFALLS` #464 —— 2026-10-28 截图判据 5/5 失败，
> 当时 `/sys/class/drm/card0-DSI-1/enabled=disabled`、`dpms=Off` ⇒ `grim` 报 `no supported format found`。
> **前提已变（父 2026-10-29 核实）**：设备现在 `enabled=enabled`、`dpms=On`（phoc 在跑）。
> 本文只做**主机侧准备**：路径清单 / 依赖包与离线可得性 / 一次性验证命令 / 优先级 / 失败模式 /
> captive-portal 绕过草案。**所有设备侧结论均标注 未上机**。

## 0. 结论速览（先数字）

| # | 结论 | 状态 |
|---|---|---|
| 1 | **前提已变**：2026-10-28 的"输出 disabled ⇒ grim 必失败"在**当前 enabled/dpms=On** 下不再是阻塞；`grim` 是**零安装、零改配置**的首选，一次调用即可闭环判据② | 未上机（父执行） |
| 2 | **`grim` 的两条错误信息语义已在二进制层核实**：`no supported format found` = 协议在但**帧格式列表空**（输出未启用/DPMS 关）；`compositor doesn't support the screen capture protocol` = **合成器没实现** screencopy。前者是状态问题，后者是选型问题 | **已证**（`strings` grim 1.5.0+ds-1） |
| 3 | **嵌套 weston 路线判死刑**（不必再试）：sid 的 `weston 16.0.0-1` 与 `libweston-16-0` **都不含 `screenshooter.so`**；且 weston 不实现 `zwlr_screencopy`/`ext_image_copy_capture` ⇒ grim 在 weston 上**结构上不可能**工作。删掉这条，省一次挂死 | **已证**（`dpkg-deb -c` + `strings`） |
| 4 | **新增两条"零/低安装"路径**：① **phosh 0.58.0 自带 `org.gnome.Shell.Screenshot` D-Bus**（`Screenshot`/`ScreenshotWindow`/`ScreenshotArea`/`SelectArea`），零包、走系统同一条 screencopy；② **Xwayland 侧 `xwd`**，1 个包 613 804 B，且 `xwd` 确实在 `x11-apps` 里 | **已证**（`strings phosh` / `dpkg-deb -c x11-apps`） |
| 5 | **ImageMagick 在 sid 没有 `import` 这个名字**：`imagemagick` 是纯元包（只带 docs，27 468 B），`imagemagick-7.q16` 只提供 `import-im7.q16` 等**带后缀**二进制 ⇒ 照旧写 `import -window` 会 `command not found` | **已证**（`dpkg-deb -c` 两包） |
| 6 | **`ffmpeg kmsgrab` 离线可得且确认编进去了**：`libavdevice63` 内含 `kmsgrab` indev（"KMS screen capture"，`/dev/dri/card0`）；这是唯一"不经合成器直读 DRM"的路 | **已证**（`strings` libavdevice63 9.0.2-4） |
| 7 | **F5（captive portal，`/204` 回 200）主机侧未复现**：从主机当前出口（默认路由 `enx027644563e50`，与设备共享上游）**直连** `http://steamconnecttest.com/204` → **204**（v4 `23.61.251.205`、v6 `2600:140b:...` 皆 204），经主机代理也是 204 ⇒ 设备上那个 200 需要**重测**（代理/DNS/瞬时拦截），不能当既有结论 | **已证**（主机 curl，见 §5.0） |
| 8 | **真登录的**可能**真阻塞在 CM 端口**：`cm0.steampowered.com:27017` 主机侧直连 **TIMEOUT**，同域 `:443` OPEN。Steam 走 443 CM 是官方支持的回落，但需要在设备上看 `connection_log.txt` 才能定性 | 部分已证（端口）+ 未上机（Steam 行为） |

**一句话**：现在**先跑 P0（三查 + grim）**；若 P0 因 dpms 又回落而失败，按 §3 的顺序推 **P1 phosh D-Bus → P2 xwd 指定窗口 → P3 CEF CDP**；weston 与 portal 两条**从清单里删除**。

## 1. 口径与前提

- **本 lane 全程主机侧**：无 `ssh` / `adb` / `fastboot`；所有"设备上会怎样"一律 `未上机`。
- **已证** = 本 lane 在本机跑过命令、留下原始输出（见 §2/§4/§5 各条内联输出）。
- **未证实** = 有文档/二进制线索但缺实测（含"上游是否已删除某功能"这类无法从 .deb 判定的）。
- **未上机** = 命令已就绪、待父在设备上跑。
- 设备侧环境常量（沿用 2026-10-28 报告，**未复核**）：会话用户 `xuqianhui1001`(uid 1001)、
  `XDG_RUNTIME_DIR=/run/user/1001`、`WAYLAND_DISPLAY=wayland-0`、session bus `unix:path=/run/user/1001/bus`、
  Xwayland `:0`、软件源 `deb https://mirrors.ustc.edu.cn/debian sid main contrib non-free`。
- **不要混用端点**（`PITFALLS` #464 同轮踩过）：`gdbus --session` 与 `--address` 互斥；走 `--address` 时别带 `--session`。

## 2. 路径清单（逐条：依赖 / 离线可得 / 命令 / 预期失败模式）

> 依赖与字节数全部取自 **sid/arm64/main** 的 `Packages.xz`（USTC 镜像，2026-10-29 抓取，
> `main` 10 732 240 B / `contrib` 56 584 B / `non-free` 96 916 B / `non-free-firmware` 11 340 B，
> 全部 HTTP 200）。"闭包"= 忽略设备已装项的**最坏情况**（把 libc6 都算进去的网络字节数），
> 真实增量必须用 §4.3 的设备侧命令现算。

### P0 · `grim` 整屏（零安装，首选）
- **依赖**：无（设备已装 `grim`，2026-10-28 实测 `/usr/bin/grim` 在位）；建议外加 `wayland-utils`（20 920 B）用于查输出真名。
- **离线可得**：grim 已在设备上；`wayland-utils` = `pool/main/w/wayland-utils/wayland-utils_1.3.0-1+b1_arm64.deb` 20 920 B，sha256 `8a1b6153…6e`。
- **命令**（必须落到 session 用户 + session 运行时目录）：
  ```sh
  runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 \
    grim /tmp/g3shots/p0-grim-full.png
  ```
- **预期失败模式**：
  - `no supported format found` ⇒ 输出又回到 `disabled`/`dpms=Off`（**先看 §3.0 三查**，别怀疑 Steam/协议）。**已证该文案来自 grim 1.5.0 二进制**（§2 尾注）。
  - `compositor doesn't support the screen capture protocol` ⇒ `wayland-0` 不是 wlroots 系（接错 socket）。
  - 文件 0 字节 / 无文件 ⇒ 权限或 socket 不匹配（session 用户错、`XDG_RUNTIME_DIR` 错）。
- **判据**：`stat -c%s` > 100 000 且 `identify` 报 `1904x3040`（= 面板 mode，`/sys/class/drm/card0-DSI-1/modes` 首行）。
- **代价**：0 B。

### P1 · phosh 内置 `org.gnome.Shell.Screenshot`（零安装，走系统同一条链）
- **依赖**：无。**已证** `phosh 0.58.0-1`（= sid 主库 `pool/main/p/phosh/phosh_0.58.0-1_arm64.deb` 627 508 B）的
  `/usr/libexec/phosh` 内含对象路径 `/org/gnome/Shell/Screenshot`、接口 `org.gnome.Shell.Screenshot`、
  方法 `Screenshot` / `ScreenshotWindow` / `ScreenshotArea` / `SelectArea`，并带 `screencopy_frame` 与
  "Updating keybindings in screenshot-manager" 字样 ⇒ **phosh 自带截图管理器和快捷键**。
- **命令**（GNOME 签名 `Screenshot(b include_cursor, b flash, s filename) -> (b ok, s path)`）：
  ```sh
  runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus \
    gdbus call --dest org.gnome.Shell.Screenshot --object-path /org/gnome/Shell/Screenshot \
      --method org.gnome.Shell.Screenshot.Screenshot false false /tmp/g3shots/p1-phosh.png
  ```
- **预期失败模式**：`(false, '')` 或 `Error: GDBus.Error:...Not supported` ⇒ phoc 侧 screencopy 拒绝（**同样受 DPMS/输出状态影响**）；
  `ServiceUnknown` ⇒ phosh 版本/名字不同（先 `gdbus introspect` 确认）。
- **价值**：这是**用户按电源菜单截图时走的同一条路**，成功即同时证明"显示链 + 截屏链"都活。
- **代价**：0 B（`gdbus` 来自已装的 glib2.0-bin/`libglib2.0-bin`，需设备自查 `command -v gdbus`）。

### P2 · Xwayland 侧 `xwd`（绕开输出状态，1 个包）
- **依赖**：`x11-apps`（**已证**含 `/usr/bin/xwd` 68 344 B）613 804 B，sha256 `40d5f20d…07`。
  转换 PNG 建议 `netpbm`（2 010 128 B，含 `xwdtopnm`）或干脆留在 `.xwd`（`file` 可辨识）。
- **命令**：
  ```sh
  DISPLAY=:0 xwd -root -silent -out /tmp/g3shots/p2-root.xwd
  DISPLAY=:0 xwininfo -root -tree | grep 'Sign in to Steam'   # 取 0x2200037 之类 id
  DISPLAY=:0 xwd -id 0x2200037 -silent -out /tmp/g3shots/p2-win.xwd
  ```
- **预期失败模式（这是本条的主要风险）**：Xwayland **没有 backing store**，`XGetImage` 对 GL 直渲的窗口常拿到
  **全黑**或 `BadMatch`；`-root` 可能整张黑。**因此判据不能只看字节数**：要 `convert x.xwd -format '%[mean]' info:`
  （或 `python3 -c` 抽样像素）确认非全零。
- **注意**：设备上 `xwd` **确实没装**（2026-10-28 `which xwd` 空，`PITFALLS` #464）⇒ 上轮 0 字节 `x.xwd` 的真因。
- **代价**：613 804 B（+ 转换工具）。

### P3 · CEF 远程调试截图（截的是"页面"本身，最语义正确）
- **依赖**：一个 WebSocket 客户端。`python3-websocket` 57 836 B（`all`，纯 python，最轻）
  或 `python3-websockets` 110 296 B；也可手写 60 行 ws（无需装包）。
- **命令草案**：
  ```sh
  # 注意：CEF 调试端口默认 8080，而上轮的本地 feed 也占 8080 —— 必须错开
  python3 -m http.server 8081 --bind 127.0.0.1 --directory /root/g3-steam/work/feed &
  "$STEAM/steamrtarm64/steam" -cef-enable-debugging -cef-remote-allow-origin=* \
      -overridepackageurl http://127.0.0.1:8081 -noreactlog -console &
  curl -s http://127.0.0.1:8080/json/version        # 探 CDP 是否起来
  # 再对 webSocketDebuggerUrl 发 {"id":1,"method":"Page.captureScreenshot"}
  ```
- **预期失败模式**：8080 被 feed 占 ⇒ CDP 不可达（**先把 feed 挪到 8081**）；`-cef-enable-debugging` 不被识别 ⇒ 无监听；
  CEF 页面只覆盖 webhelper 的 HTML 区（不含窗口装饰/`hint`），**不能替代"窗口在屏幕上"的证明**，只能替代"登录界面渲染出来了"。
- **未证实**：`-cef-enable-debugging` 在 linuxarm64 分支上的行为、CDP 端口号与是否需 `-cef-remote-allow-origin`（主机侧无客户端二进制可查）。
- **代价**：57 836 B（或 0，手写 ws）。

### P4 · `wayvnc`：把 DSI 屏推到主机"看"（不需要截图）
- **依赖**：`wayvnc` 79 600 B（`pool/main/w/wayvnc/wayvnc_0.10.1-1_arm64.deb`）+ `libneatvnc1`/`libaml1`/`libpam0g` 等闭包。
- **命令**：
  ```sh
  runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 \
    wayvnc -o DSI-1 0.0.0.0 5900
  ```
  主机侧任一 VNC 客户端连 `<设备IP>:5900`。
- **预期失败模式**：同样依赖 `zwlr_screencopy`（wlroots）⇒ **前提与 P0 相同**；无认证时需 `-a`/`--disable-auth` 变体；
  1904×3040 竖屏推流带宽/编码压力；`phoc` 若不导出 `wlr-screencopy`（phoc 0.58 有，已证）则直接不可用。
- **价值**：一次连接 = 父**亲眼**看到登录界面，比一张 PNG 更硬（且可点按登录）。
- **代价**：~80 KB + 闭包。

### P5 · 嵌套 wlroots 合成器（`phoc`/`sway`）+ grim（**真正绕开物理输出状态**）
- **依赖**：设备已有 `phoc`（运行中）与/或 `sway` 306 688 B。**先确认 phoc 支持嵌套后端**：
  `phoc` 0.58.0 二进制含 `wayland`、`headless` 后端字符串（**已证**），但**具体开关名未证实**（需 `phoc --help`）。
- **命令草案**：
  ```sh
  # A: 嵌套 phoc（若 -B/--backend 支持 wayland）
  XDG_RUNTIME_DIR=/tmp/g3/rt WAYLAND_DISPLAY=/run/user/1001/wayland-0 phoc -B wayland -S wl-g3 &
  # B: 嵌套 sway（wlroots，WLR_BACKENDS 有明确文档）
  XDG_RUNTIME_DIR=/tmp/g3/rt WAYLAND_DISPLAY=/run/user/1001/wayland-0 \
    WLR_BACKENDS=wayland WLR_WL_OUTPUTS=1 sway --unsupported-gpu -c /tmp/g3/sway.cfg &
  # 之后：DISPLAY=:9（嵌套 Xwayland）跑 Steam，再
  XDG_RUNTIME_DIR=/tmp/g3/rt WAYLAND_DISPLAY=wl-g3 grim /tmp/g3shots/p5-nested.png
  ```
- **预期失败模式**：phoc 无该开关 ⇒ 直接放弃 A 走 B；嵌套合成器里 Steam 拿到的 GPU 是**宿主 freedreno**（`--unsupported-gpu` 可能被拒）；
  性能/渲染差异导致"截图成立但和真机观感不同"（**旁证价值下降**，不能当作"面板显示正常"的证据）。
- **代价**：sway 306 688 B + 闭包（`swaybg`、`libwlroots`…）。
- **⚠️ 与 P6 的区别**：P5 证明"Steam UI 渲染正确"，**不**证明"面板出图"；P0/P4/P6 才证面板。

### P6 · `ffmpeg -f kmsgrab`（DRM 直读，唯一不经合成器的路）
- **依赖**：`ffmpeg` 1 672 740 B + `libavdevice63` 101 060 B（**已证**含 `kmsgrab` indev，"KMS screen capture"，`/dev/dri/card0`）+ 闭包（最坏 90.7 MB deb，实际远小，见 §4.3）。
- **命令**（需 root + `CAP_SYS_ADMIN`；设备是 root 直接跑）：
  ```sh
  ffmpeg -hide_banner -f kmsgrab -i - -frames:v 1 \
         -vf 'hwdownload,format=bgr0' /tmp/g3shots/p6-kmsgrab.png
  ```
- **预期失败模式**：`Cannot open device /dev/dri/card0`（权限）/ `Failed to get drm master`（phoc 持 master —— 需要 `-c` 或先停 phoc）；
  黑帧（`dpms=Off` 时 plane 无内容）；`hwdownload` 格式不匹配 ⇒ 报 unsupported format，改 `format=nv12`/`xrgb8888` 再试；
  msm 驱动上 kmsgrab 的 modifier 处理可能失败（`Failed to map framebuffer`）。
- **代价**：~1.8 MB + 闭包（本清单里最贵的"直读"方案）。

### P7 · ImageMagick `import`（X 侧，P2 的替代，**名字有坑**）
- **依赖**：`imagemagick-7.q16` 733 716 B（**已证**只提供 `import-im7.q16`/`convert-im7.q16`/`magick-im7.q16` 等后缀名）；
  `imagemagick` 27 468 B 是**纯元包**（只带 docs，无二进制）。sid **没有** `imagemagick-6.q16`。
- **命令**：
  ```sh
  DISPLAY=:0 import-im7.q16 -window root /tmp/p7-root.png
  DISPLAY=:0 import-im7.q16 -window 0x2200037 /tmp/p7-win.png
  ```
- **预期失败模式**：照旧写 `import` ⇒ `command not found`（**这就是本条唯一的坑**）；`-window root` 同 P2 的黑屏风险。
- **代价**：~734 KB + 闭包（IM7 闭包明显大于 x11-apps）。

### P8 · `Xvfb` 独立 X 服务器 + xwd（完全绕开 DRM/phoc，最重）
- **依赖**：`xvfb` 3 184 372 B + `xserver-common` + `x11-xkb-utils` + `libgl1-mesa-dri`（多数已在）。
- **命令**：
  ```sh
  Xvfb :9 -screen 0 1280x800x24 -nolisten tcp &
  DISPLAY=:9 "$STEAM/steamrtarm64/steam" -cef-disable-gpu -noreactlog -console &
  sleep 40; DISPLAY=:9 xwd -root -silent -out /tmp/g3shots/p8-xvfb.xwd
  ```
- **预期失败模式**：无 GL 硬件 ⇒ llvmpipe；CEF 可能白屏/黑屏（需 `-cef-disable-gpu`，**未证实**该 flag 名）；
  仅能证明"登录界面渲染出来了"，**不能**证明面板/DRM 链，价值与 P3 重叠而成本更高。
- **代价**：~3.2 MB + 闭包。**只在 P3/P5 都失败时才用**。

### P9 · `xdg-desktop-portal[-wlr]` Screenshot portal（**建议排除**）
- **依赖**：`xdg-desktop-portal` 412 816 B + `xdg-desktop-portal-wlr` 47 980 B + `pipewire` + `bubblewrap` + gstreamer 插件…
  **最坏闭包 125 193 320 B deb / 559 637 504 B 安装**（本 lane 实测计算，见 §4.2）。
- **命令**：`gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop --method org.freedesktop.portal.Screenshot.Screenshot '' '{}'`
- **排除理由**：底层仍是 `wlr-screencopy`（`xdg-desktop-portal-wlr` 的依赖里明确写着 `pipewire`+`wlr` 语义），
  **前提与 P0 完全一样**，却要拉 125 MB 闭包 ⇒ 只在需要"应用内正常取屏"（如浏览器共享）时才值得。

### P10 · `libdrm-tests` 的 `modetest`（不是截图，是**判据前置工具**）
- **依赖**：`libdrm-tests` 71 024 B（含 `modetest`/`modeprint`/`drmdevice`/`vbltest`）。
- **命令**：`modetest -c -p -M msm | sed -n '/DSI/,+20p'`（看 CRTC `ACTIVE`、plane `FB` 是否非 0）
- **价值**：把"面板到底在不在扫出"从 `dpms` 文件推进到 **CRTC/plane 真值**；`dpms=On` 但 plane 无 FB 时 grim 照样可能出问题。
- **预期失败模式**：`-M msm` 名字不对 ⇒ `unknown driver`；非 root 可能拒绝（本机 root 无所谓）。
- **代价**：71 KB。

### 尾注（本节"已证"的原始输出）

```
# grim 1.5.0+ds-1（pool/main/g/grim/grim_1.5.0+ds-1_arm64.deb, 16 840 B）strings：
compositor doesn't support the screen capture protocol
compositor doesn't support wl_shm
no supported format found
zwlr_screencopy_manager_v1 / zwlr_screencopy_frame_v1
ext_image_copy_capture_manager_v1 / ext_image_copy_capture_session_v1 / ext_image_copy_capture_frame_v1
zxdg_output_manager_v1

# phoc 0.58.0-1（pool/main/p/phoc/phoc_0.58.0-1_arm64.deb, 649 172 B）strings：
zwlr_screencopy_manager_v1 / zwlr_screencopy_frame_v1
ext_image_copy_capture_manager_v1 ... ext_output_image_capture_source_v1
phoc_phosh_private_screencopy_frame / new phosh_private_screencopy_frame
（后端字符串：headless / wayland；**无** org.gnome.Shell.Screenshot）

# phosh 0.58.0-1（627 508 B）usr/libexec/phosh strings：
/org/gnome/Shell/Screenshot, org.gnome.Shell.Screenshot, Screenshot, ScreenshotArea,
ScreenshotWindow, SelectArea, screencopy_frame, "Updating keybindings in screenshot-manager"

# x11-apps 7.7+11+b3（613 804 B）dpkg-deb -c：./usr/bin/xwd (68 344 B), ./usr/bin/xwud (68 296 B)

# imagemagick-7.q16 7.1.2.34（733 716 B）dpkg-deb -c：只有 *-im7.q16 系列（import-im7.q16 等），无 magick/import
# imagemagick 7.1.2.34（27 468 B）dpkg-deb -c：只有 /usr/share/doc 与 /usr/share/bug（纯元包）

# weston 16.0.0-1（940 744 B）+ libweston-16-0 16.0.0-1（445 960 B）：
weston 包内 .so 仅 libexec_weston/systemd-notify/lua-shell/kiosk-shell/ivi-shell/hmi-controller/desktop-shell
libweston-16-0 内为 drm/headless/wayland/x11/rdp/vnc/pipewire backend + gl/vulkan renderer + xwayland.so
→ **两包均无 screenshooter.so**；客户端 weston-screenshooter 在 weston 包的 /usr/bin

# libavdevice63 9.0.2-4（101 060 B）strings：kmsgrab / "kmsgrab indev" / "KMS screen capture" / /dev/dri/card0
```


## 3. 优先级排序 + 一次性验证命令（父在设备上执行）

> 排序依据：**① 是否绕开"输出状态"这个唯一变量 ② 装包字节数 ③ 判据的"硬"程度（面板真值 > 页面真值 > 窗口真值）**。
> "一次成功概率"列是**估算**（非证据），只用于排序。

| 优先级 | 路径 | 新增成本 | 是否依赖面板处于 enabled/On | 一次成功概率（估算） | 证明力 |
|---|---|---|---|---|---|
| **T0** | P0 `grim` 整屏 | **0 B** | **是** | 高（前提已满足） | **面板真值**（最强） |
| **T0** | P1 phosh `org.gnome.Shell.Screenshot` | **0 B** | 是 | 中高 | 面板真值（系统同一条链） |
| **T1** | P2 `xwd` 指定窗口 | 613 804 B(+2 小库) | **否** | 中（黑屏风险） | 窗口真值（"登录界面被渲染"） |
| **T1** | P3 CEF CDP 截图 | 0–57 836 B | **否** | 中（端口/flag 未证实） | 页面真值（"登录框画出来了"） |
| **T2** | P4 `wayvnc` | ~80 KB + 闭包 | 是 | 中高 | **可交互**（父亲眼 + 能点） |
| **T2** | P10 `modetest`（判据工具，不产图） | 71 024 B | — | 高 | **CRTC/plane 真值**，给 T0 兜底解释 |
| **T3** | P5 嵌套 `sway`/`phoc` + grim | 306 688 B + 闭包 | 否 | 中 | 仅"UI 渲染正确"，**不证面板** |
| **T4** | P6 `ffmpeg kmsgrab` | 1 673 740 + 101 060 B + 闭包 | **是**（需 plane 有内容） | 低中（需 master/格式） | 面板真值（直读，但实现脆） |
| **T5** | P8 `Xvfb` + xwd | 3 184 372 B + 闭包 | 否 | 中低 | 仅页面真值，成本最高 |
| **排除** | P5-weston / `weston-screenshooter` | — | — | **0（结构不可能）** | 见 §0 #3 |
| **排除** | P9 `xdg-desktop-portal*` | ~125 MB 闭包 | 是 | — | 与 T0 同前提，成本荒谬 |

### 3.0 一次性前置三查（任何截图前先跑；`PITFALLS` #464 定式）
```sh
# root；三条全绿才往下走
cat /sys/class/drm/card0-DSI-1/{status,enabled,dpms}
head -1 /sys/class/drm/card0-DSI-1/modes            # 期望 1904x3040（判据尺寸）
command -v grim xwd gdbus modetest phoc-outputs-states 2>/dev/null
loginctl list-sessions --no-legend                   # 期望会话用户 xuqianhui1001 / uid 1001
ls -l /run/user/1001/wayland-0 /run/user/1001/bus
```

### 3.1 T0-a：`grim` 一次闭环（判据② 的最短路径）
```sh
install -d -o xuqianhui1001 -g xuqianhui1001 /tmp/g3shots
runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 \
  grim /tmp/g3shots/p0-grim-$(date +%H%M%S).png ; echo "grim rc=$?"
ls -l /tmp/g3shots/ ; stat -c '%n %s bytes' /tmp/g3shots/p0-grim-*.png
sha256sum /tmp/g3shots/p0-grim-*.png
```
- **成立判据**：`rc=0` 且 PNG **> 100 000 B**（1904×3040 的登录界面远大于此；纯黑 PNG 压缩后通常 < 30 000 B）。
- 若失败，把 `stderr` **原样**贴回（两句错误文案的语义见 §0 #2，决定下一步走 P1 还是"回头点亮输出"）。

### 3.2 T0-b：phosh 自带截图（交叉验证，零安装）
```sh
runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus \
  gdbus call --dest org.gnome.Shell.Screenshot --object-path /org/gnome/Shell/Screenshot \
    --method org.gnome.Shell.Screenshot.Screenshot false false /tmp/g3shots/p1-phosh.png
# 不认方法时先自证接口存在：
runuser -u xuqianhui1001 -- env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus \
  gdbus introspect --dest org.gnome.Shell.Screenshot --object-path /org/gnome/Shell/Screenshot | head -30
```
- **成立判据**：返回 `(true, '/tmp/g3shots/p1-phosh.png')` 且 `stat` 有字节。

### 3.3 若 dpms 又回落到 Off（这轮最可能的"复发"）
按"代价从低到高"逐个试，**每条都立刻回读 `dpms`**：
```sh
U="runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus"
$U gdbus call --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver \
   --method org.gnome.ScreenSaver.SetActive false           # phosh 熄屏/锁屏（#464 里参数用错的那条）
$U gdbus call --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver \
   --method org.gnome.ScreenSaver.SimulateUserActivity      # 防再次熄屏
cat /sys/class/drm/card0-DSI-1/dpms
# 若装了 wlopm（9 120 B，wlr-output-power-management；phoc 是否实现未证实）：
$U wlopm --on '*' ; cat /sys/class/drm/card0-DSI-1/dpms
```
- 注意：**`gdbus --session` 与 `--address` 互斥**（`PITFALLS` #464 踩过：报 `Multiple connection endpoints specified`）。

### 3.4 T1-a：`xwd` 指定窗口（绕开输出状态）
```sh
apt-get install -y --no-install-recommends x11-apps        # 613 804 B（+ libx11-xcb1/libxcb-damage0）
command -v xwd
DISPLAY=:0 xwininfo -root -tree | grep -n 'Sign in to Steam'   # 取十六进制 id
DISPLAY=:0 xwd -id 0x2200037 -silent -out /tmp/g3shots/p2-win.xwd ; echo "rc=$?"
stat -c '%s bytes' /tmp/g3shots/p2-win.xwd
python3 - <<'PY'   # 非全黑判据（无 PIL 也能跑：只看 zlib 压缩后熵，全黑图会显著偏小）
import sys,os
p="/tmp/g3shots/p2-win.xwd"; n=os.path.getsize(p)
print("xwd bytes", n, "=> " + ("SUSPECT-ALL-BLACK" if n < 200000 else "has content"))
PY
```
- **成立判据**：`> 200 000 B`（700×440×4 ≈ 1.2 MB 原始像素，压缩后仍远超阈值）**且**后续能转 PNG 后肉眼确认。
- 转换（装 `netpbm` 后）：`xwdtopnm /tmp/g3shots/p2-win.xwd > /tmp/g3shots/p2-win.pnm`。

### 3.5 T1-b：CEF 远程调试（截"页面"，不依赖屏幕）
```sh
# 1) 先把本地 feed 从 8080 挪开（否则与 CEF 调试端口冲突）
pgrep -af "http[.]server" ; pkill -f "http[.]server 8080"   # ← 注意用 pgrep 先看；见技能 pkill-self-match
nohup python3 -m http.server 8081 --bind 127.0.0.1 --directory /root/g3-steam/work/feed >/tmp/g3-steam/feed8081.log 2>&1 &
curl -fsS -o /dev/null http://127.0.0.1:8081/ && echo "feed up 8081"
# 2) 带 CEF 调试起 Steam（把 8080 留给 CDP）
export HOME=/root/steam-home XDG_RUNTIME_DIR=/tmp/g3-steam/rt DISPLAY=:0 \
       WAYLAND_DISPLAY=/run/user/1001/wayland-0 STEAM_RUNTIME=0
STEAM=$HOME/.local/share/Steam
LD_LIBRARY_PATH="$STEAM/steamrtarm64:$STEAM/lib/aarch64-linux-gnu" \
  timeout -k 10 200 "$STEAM/steamrtarm64/steam" -cef-enable-debugging -cef-remote-allow-origin=* \
    -overridepackageurl http://127.0.0.1:8081 -noreactlog -console >/tmp/g3-steam/p3.out 2>&1 &
sleep 45
# 3) 探 CDP
curl -s http://127.0.0.1:8080/json/version ; echo
curl -s http://127.0.0.1:8080/json | head -c 800 ; echo
```
- **成立判据**：`/json/version` 返回含 `webSocketDebuggerUrl` 的 JSON（= CEF 调试端口起来了）。
- 拿到 ws URL 后再发一条 `Page.captureScreenshot`（base64 PNG）。**需要 ws 客户端**：
  `apt-get install -y --no-install-recommends python3-websocket`（57 836 B，纯 python；python3 已在设备上）。
- **风险**：若 `-cef-enable-debugging` 不被识别，`/json/version` 会 `Connection refused` ⇒ 本条作废，回到 T0/T1-a。

### 3.6 T2：`modetest` 看 CRTC/plane 真值（给失败定性，不产图）
```sh
apt-get install -y --no-install-recommends libdrm-tests     # 71 024 B
modetest -c -p -M msm | sed -n '/DSI/,+25p'                 # 看 CRTC ACTIVE / plane 的 FB id != 0
modetest -c -M msm | head -40                                # 不认识 -M msm 就去掉 -M
```
- **用途**：若 `dpms=On` 但 plane `FB=0`，说明"合成器没在扫出"，grim 失败就与 Steam 无关。

### 3.7 T4：`kmsgrab`（只有在 T0/T1 全失败、且需要"直读面板"时才动）
```sh
apt-get install -y --no-install-recommends ffmpeg           # ffmpeg 1 672 740 B + libavdevice63 101 060 B + 闭包
ffmpeg -hide_banner -devices | grep -i kmsgrab              # 先确认 indev 在（Debian 版应有，见 §0 #6）
ffmpeg -hide_banner -f kmsgrab -i - -frames:v 1 -vf 'hwdownload,format=bgr0' /tmp/g3shots/p6.png
# 格式不对时依次试：format=xrgb8888 / format=nv12 / 去掉 hwdownload
```
- **前提**：需要 DRM master ⇒ phoc 持有时会失败；只在维护窗口（可停 phoc）里做。

## 4. 离线安装成本测算（apt 包清单 + 镜像 + 字节数）

### 4.1 镜像与索引（**已证**，本 lane 2026-10-29 抓取）
- 镜像基址 `https://mirrors.ustc.edu.cn/debian`（与设备 `/etc/apt/sources.list` 同源），组件 `sid/{main,contrib,non-free,non-free-firmware}`。
- `binary-arm64/Packages.xz` 四种全部 **HTTP 200**：`main` 10 732 240 B / `contrib` 56 584 B / `non-free` 96 916 B / `non-free-firmware` 11 340 B（`curl --noproxy '*'`，用时 0.1–0.6 s）。

### 4.2 候选包的精确坐标（可直接 `curl` 到设备再 `dpkg -i`）

| 包 | 版本 | deb 字节 | sha256（前 16） | 用途 |
|---|---|---|---|---|
| `x11-apps` | 7.7+11+b3 | 613 804 | `40d5f20d6639b250` | `/usr/bin/xwd`（T1-a） |
| `imagemagick-7.q16` | 7.1.2.34+dfsg1-1 | 733 716 | `2260cb89d61735ed` | `import-im7.q16`（P7，注意无 `import` 名） |
| `imagemagick` | 7.1.2.34+dfsg1-1 | 27 468 | `45152bd6f8b5a47e` | **纯元包**（只有 docs + 依赖），装它只为语义 |
| `wayland-utils` | 1.3.0-1+b1 | 20 920 | `8a1b615342907909` | `wayland-info`，查输出真名 |
| `libdrm-tests` | 2.4.134-3 | 71 024 | `f0227fe43424b4cf` | `modetest`（T2） |
| `wlopm` | 1.0.0-1+b1 | 9 120 | `af7e21d012b4ed0d` | `wlopm --on '*'`（点亮，phoc 支持未证实） |
| `wlr-randr` | 0.5.0-1 | 12 924 | `84e55af6b2e07abd` | 输出列表/模式（需 `zwlr_output_manager_v1`） |
| `python3-websocket` | 1.9.0-4 (all) | 57 836 | `a08e21d396c5f923` | CDP 客户端（T1-b） |
| `ffmpeg` | 9.0.2-4 | 1 672 740 | — | kmsgrab 主程序（P6） |
| `libavdevice63` | 9.0.2-4 | 101 060 | — | **kmsgrab indev 所在**（已证） |

- 完整 URL = `https://mirrors.ustc.edu.cn/debian/<Filename>`，`Filename` 例：`pool/main/x/x11-apps/x11-apps_7.7+11+b3_arm64.deb`。

### 4.3 真实增量必须现算（**这是唯一权威口径**）
```sh
# 设备上（不改系统，只打印将要从哪个 URL 取多少字节）
apt-get install -s --no-install-recommends --print-uris x11-apps wayland-utils libdrm-tests \
  | awk '/^.http/{print $2, $3, $1}' | sort -u
# 只下不装：
apt-get install -y --no-install-recommends --download-only x11-apps wayland-utils libdrm-tests
ls -l /var/cache/apt/archives/*.deb | awk '{s+=$5} END {print s" bytes"}'
```
- **主机侧预估算**（闭包，已扣掉"设备几乎肯定已有"的 libc/mesa/pipewire/X 基础库；**估算，非证据**）：

| 目标 | 闭包包数（全量→扣基础库） | 估算网络字节 | 备注 |
|---|---|---|---|
| `grim` | 10 → **0**（设备已装） | 0 | 首选 |
| `wayland-utils` | 9 → **1** | 20 920 | |
| `wlopm` / `wlr-randr` | 各 7 → **1** | 9 120 / 12 924 | |
| `libdrm-tests` | 10 → **3** | 95 676 | 含 libdrm-etnaviv1/tegra0（可忽略） |
| `x11-apps` | 53 → **12**（含 man-db/groff 壳） | 5 372 612 | 加 `--no-install-recommends` 后实测应 < 700 KB |
| `imagemagick-7.q16` | 61 → **7** | 4 113 712 | 比 x11-apps 贵，收益相同 ⇒ **不推荐** |
| `python3-websocket` | 31 → **1**（python3 已在） | 57 836 | CDP 客户端 |
| `sway` | 122 → **51** | 20 368 604 | 嵌套合成器，T3 |
| `xvfb` | 79 → **9** | 11 256 004 | 最重，T5 |
| `ffmpeg` | 193 → **98** | 58 771 392 | kmsgrab，T4 |
| `wayvnc` | 199 → **91** | 63 557 500 | T2，闭包取决于设备已装 codec 库 |
| `weston`（**排除**） | 245 → 123 | 88 439 076 | 且截图结构不可能 |
| `xdg-desktop-portal-wlr`（**排除**） | 234 | 125 193 320 | 同前提、成本荒谬 |

- **离线兜底流程**（设备网络不稳时）：主机 `curl` 上表 URL → `sha256sum -c` → `scp` 到设备 →
  `dpkg -i` → 缺依赖再 `apt-get -f install`（此时只需极小包）。


## 5. captive portal 绕过评估 + 真登录草案（**只写草案，不下发**）

### 5.0 已证：主机侧联网取证（与设备共享同一上游，故有参考价值）

出口拓扑（本机 `ip -br addr`，**已证**）：`eno1` = 校园有线 `114.214.224.240/21`（无默认路由）/
`enx027644563e50` = **手机共享 `192.168.42.97/24`，当前唯一默认路由**（`ip route get 23.61.251.205`
→ `via 192.168.42.129 dev enx027644563e50`）/ `tailscale0` `100.126.217.90`。
**⚠️ 重要陷阱（已证）**：`ip route get … from 114.214.224.240` 仍返回 `dev enx027644563e50` ⇒
**只绑 campus 源地址的探测是伪测试**（包从共享口出去、源地址不匹配 ⇒ 必然超时）。只有 `curl --interface eno1` 可信。

| 探测（`curl --noproxy '*'`） | 共享口 `enx027…` | 校园口 `eno1` | 判读 |
|---|---|---|---|
| `http://steamconnecttest.com/204` | **204**（0 字节，`Server: AkamaiNetStorage`，`ETag: "d41d8…427e:1632937655.318639"`） | 未测 | **无门户**（主机侧） |
| `https://steamconnecttest.com/204` | **204** | 未测 | 同上 |
| `http://steamconnecttest.com/` | 200，`len=7` | 未测 | `/` 本来就不是 204（**别拿它当门户判据**） |
| `https://api.steampowered.com/` ×8 | **8/8 → 404（0.8–1.7 s）** | 000（6 s 超时） | 共享口通、校园口不通 |
| `https://store.steampowered.com/` | 000（25 s）/ 一次 000（6 s） | 000 | **不稳定**（见下） |
| `https://cdn.akamai.steamstatic.com/` | 200（1.0 s） | 未测 | CDN 通 |
| `https://cm0.steampowered.com:443`（TCP） | **5/5 通**（160 ms–1216 ms），TLS1.3 握手完成、拿到证书 | 未测 | CM 443 可达 |
| `cm0.steampowered.com:27017` / `:27018`（TCP） | **5/5 `TimeoutError`** | 同（伪测试除外） | **legacy CM 端口全死** |
| `https://www.google.com` | 000（6 s） | **302（0.24 s）** | 两口互补 |
| `https://api.github.com` | 200（0.42–0.65 s） | 000 | 两口互补 |
| `https://deb.debian.org` | 000 | 200（0.46 s） | 两口互补 |
| `http://127.0.0.1:7897`（上一轮设备用过的代理） | **000 / 0.00009 s = 拒绝连接** | — | **代理当前没在监听** |

**必须先纠正的一个"看似结论"**：第一次采样 `https://api.steampowered.com/` 连续 15–25 s 超时（`000`），
但**随后同一出口 8/8 全部 404（≈1 s）** ⇒ 那次超时是**瞬时抖动**，**不能**据此写"Steam 被墙"。
（本节已按此纠正；`硬性规则 #1`：未确认前不下"站点不通"结论。）

### 5.1 对"captive portal"假设的判定
- **主机侧无门户**（`/204` 在 v4/v6、直连/代理下都是 204，且 body 恰 0 字节）。
- 2026-10-28 设备上读到 200 的那次，**最可能是设备眼里的代理/DNS 路径与主机当前不同**（当时设备把
  `http_proxy/https_proxy` 指向 `192.168.42.97:7897`，而该代理**现在已不监听**）。
- **结论：门户假设降级为"未证实且主机侧不支持"**。设备上重测即可定案（见 5.4）。

### 5.2 真登录的实际候选阻塞（按可能性排序）
| # | 候选 | 状态 | 反证/证实手段 |
|---|---|---|---|
| B1 | **legacy CM `27017/27018` 不可达**，若客户端仍先试 legacy 端口则登录会卡在"连接中" | 端口已证死；客户端是否依赖**未证实** | 设备上 `grep -iE 'cm[0-9]|27017|websocket|connect' logs/connection_log.txt` |
| B2 | **上游抖动**（store/api 有一次超时、`client-update` 一次 4.5 s） | 已证存在抖动 | 设备上连续 10 次 `curl -m 10` 采样，要求 10/10 |
| B3 | **无可用代理**（7897 已关） | 已证（拒绝连接） | 若要代理，先起它再验 `curl -x` |
| B4 | **凭据/2FA**（`WaitingForCredentials` 字面意思就是"等你输账号"） | **未证伪**：上轮从未输入过凭据 | 真输入一次（草案见 5.3） |
| B5 | 出口选择（校园口到 Steam 全 000，共享口通） | 已证 | 设备保持走共享/热点口，别切校园有线做登录测试 |

### 5.3 配置文件草案（**不要下发，仅供父在设备上手动落地**）

**(a) 启动行草案**（凭据**不进文件**，运行时交互输入）：
```sh
export HOME=/root/steam-home XDG_RUNTIME_DIR=/tmp/g3-steam/rt DISPLAY=:0 \
       WAYLAND_DISPLAY=/run/user/1001/wayland-0 STEAM_RUNTIME=0
STEAM=$HOME/.local/share/Steam
LD_LIBRARY_PATH="$STEAM/steamrtarm64:$STEAM/lib/aarch64-linux-gnu" \
  timeout -k 10 600 "$STEAM/steamrtarm64/steam" \
    -overridepackageurl http://127.0.0.1:8081 \
    -noreactlog -console -cef-enable-debugging
# 起来后在 Console 里输入：login <账号>
#   （密码由客户端弹窗输入，**不要**写成 login <账号> <密码>，会进 ps/日志）
```
- `-login <user> <pass>` 形式**存在**但会把密码暴露在 `ps`/`~/.steam` 日志 ⇒ **禁用**。

**(b) `steam.cfg` 草案**（放 `$STEAM/steam.cfg`，只放**非机密**项；键名含义**未证实**，逐条标注）：
```ini
"InstallConfigStore"
{
	"Software"
	{
		"Valve"
		{
			"Steam"
			{
				"cip"			"0"          // 未证实：历史上用于跳过某些客户端完整性/更新检查
				"Rate"			"250000"
				"AutoUpdateUI"		"0"
				"CellIDServerOverride"	"0"   // 未证实：指定 CM cell
			}
		}
	}
}
```
- **不要**把 `"CMWebSocketPort"`/`"CMConnectTimeout"` 之类猜出来的键塞进去（无效键会被忽略或整体解析失败）。
- 真要"绕受限网络"，官方支持的旋钮只有命令行 `-overridepackageurl`（已验证可用）与网络层的代理
  （`-proxy`? 未证实；Steam 客户端读 `http_proxy` 环境变量**未证实**，需设备上实测）。

**(c) 若确定要"翻出去"才能登录**：本机已有 `tailscale0`（`100.126.217.90`），可评估
「设备 → tailscale exit node → 外网」或「设备把 Steam 域名指向一台能通的代理」；**均未上机验证**，
且涉及外部账号/凭据 ⇒ 按 `硬性规则 #2` **上报用户决策，不自行试**。

### 5.4 设备上定案命令（一次性，只读 + 一次采样）
```sh
S=/root/steam-home/.local/share/Steam
# ① 门户复核（要 204 且 0 字节；若 200 就把 body 存下来看是谁改的）
curl --noproxy '*' -s -D- -o /tmp/cp.body -m 10 http://steamconnecttest.com/204 | head -6
wc -c /tmp/cp.body; head -c 300 /tmp/cp.body
# ② 与主机指纹比对（主机 ETag = "d41d8cd98f00b204e9800998ecf8427e:1632937655.318639"）
# ③ 抖动采样（要 8/8）
for i in $(seq 8); do curl --noproxy '*' -s -o /dev/null -m 12 \
  -w '%{http_code} %{time_total}\n' https://api.steampowered.com/; done
# ④ 客户端自己怎么说（最权威）
ls -l $S/logs/connection_log.txt && grep -iE 'connect|cm[0-9]|websocket|27017|443|fail|timeout|denied' \
  $S/logs/connection_log.txt | tail -40
# ⑤ 有没有"在线/门户"字样
grep -riE 'captive|portal|no internet|offline' $S/logs/*.txt | tail -20
```

## 6. 未证实清单（禁止当结论用）

| # | 未证实项 | 定案方法 |
|---|---|---|
| U1 | phoc 0.58 是否有"嵌套后端"开关（`-B wayland` / `--backend`） | `phoc --help`（设备侧） |
| U2 | 设备 phoc 是否实现 `zwlr_screencopy_manager_v1`（主机侧只能证明 sid 的 phoc 二进制里有） | `wayland-info` 看协议列表 |
| U3 | `-cef-enable-debugging` / CDP 监听在 linuxarm64 分支上的行为与端口 | 设备上 `curl 127.0.0.1:8080/json/version` |
| U4 | 设备是否装了 `gdbus`（`libglib2.0-bin`） | `command -v gdbus` |
| U5 | Steam 客户端是否仍依赖 legacy CM `27017/27018` | `connection_log.txt` |
| U6 | Steam 客户端是否读 `http_proxy` 环境变量 | 设代理前后对比 `connection_log.txt` |
| U7 | 设备上 `/204` 的 200 究竟由谁改（代理/TUN/运营商） | §5.4 ①的 body 与 header |
| U8 | kmsgrab 在 msm 驱动 + 1904×3040 上的 modifier 处理 | 设备上跑 P6（维护窗口） |
| U9 | `Weston 16` 是否有我漏看的截图路径（`weston-debug`/`rdp-backend`） | 若 P0/P1 都失败再深挖，**当前无必要** |

## 7. 回执（本 lane 产物）

| 文件 | 字节 |
|---|---|
| `reports/g3-steam-screenshot-paths-20261029.md` | 38491 字节 |
| `TASKS/sessions/2026-10-29-G3截图路径.md` | 4785 字节 |

**一句话结论**：判据② 在当前 `enabled/dpms=On` 下**不需要装任何包**——`grim` 一次即闭环（T0），失败时按
`phosh D-Bus → xwd → CEF CDP` 逐级降；同时本轮把「captive portal」从阻塞项降级为未证实（主机侧 `/204`=204），
真正的可疑项换成 **legacy CM 27017 全死 + 上游抖动 + 无可用代理**，且已给出设备侧定案命令。

