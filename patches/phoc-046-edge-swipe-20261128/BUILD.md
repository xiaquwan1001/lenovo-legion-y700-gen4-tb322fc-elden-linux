# phoc 0.46.0 edge-swipe backport（回移自上游 MR !829）

- 上游 MR: https://gitlab.gnome.org/World/Phosh/phoc/-/merge_requests/829（基于 main / 0.59.0）
- 本目录补丁: `0001-cursor-Add-an-edge-swipe-back-gesture.patch`，目标 = 设备在版 phoc **0.46.0**（Debian trixie，动态链接 **libwlroots-0.18.so**）
- 验证树: `build/phoc046-edge-swipe/`（= `/tmp/ph046/phoc-0.46.0` 副本 + 本补丁；其 `subprojects/wlroots` 为 **0.18.2**，与设备在版 wlroots 同主版本）

## ① 0.46(main 0.59) API 差异清单（逐条核对，未猜）

逐个 grep 过的 API，在 0.46.0 源码中的真实位置与签名：

| API | 0.46.0 位置 | 与上游 MR 假设的差异 |
|---|---|---|
| `PhocGestureSingle` 基类 | `src/gesture-single.h`（存在，`PHOC_TYPE_GESTURE_SINGLE`） | 无差异，直接沿用 |
| `handle_event`/`filter_event` vfunc | `src/gesture.h:29` / `gesture.h:34`（签名相同：`(PhocGesture*, const PhocEvent*, double lx, double ly)` / `(PhocGesture*, const PhocEvent*)`） | 无差异 |
| `phoc_gesture_get_last_updated_sequence` | `src/gesture.h:75`，实现 `src/gesture.c:996` | **存在**（任务担心的缺失项不存在），无差异 |
| `phoc_gesture_is_active` / `phoc_gesture_reset` | `src/gesture.h:54` / `:55` | 无差异 |
| `PhocEvent` 结构 / 触摸事件枚举 | `src/event.h:118-143`（`touch_down/touch_up/touch_motion/touch_cancel` 均在 union，`PHOC_EVENT_TOUCH_*` 同名） | 无差异 |
| **touch sequence ↔ touch_id 映射** | `src/event.c:145`：`return GUINT_TO_POINTER (event->touch_up.touch_id);` | **唯一实质差异**：上游 MR 补丁用 `GINT_TO_POINTER`/`GPOINTER_TO_INT`；0.46 用 `GUINT_TO_POINTER`，故移植版在 `gesture-edge-swipe.c`（handle_event）与 `cursor.c`（`on_edge_swipe_back` 里查 `wlr_seat_touch_get_point`）改为 `GUINT_TO_POINTER`/`GPOINTER_TO_UINT`。wlroots 0.18.2 的 `touch_id` 为 `int32_t`（`subprojects/wlroots/include/wlr/types/wlr_seat.h:585`），uint 往返无损 |
| `phoc_cursor_add_gesture` | `src/cursor.h:129`，实现 `src/cursor.c:1903` | 无差异 |
| `send_touch_cancel` | `src/cursor.c:554`（static，`(PhocSeat*, struct wlr_surface*)`） | 无差异（同文件内调用） |
| `phoc_seat_get_focus_view` | `src/seat.h:137` | 无差异 |
| `phoc_view_close` | `src/view.h:178` | 无差异 |
| `phoc_server_get_desktop` / `phoc_desktop_layout_get_output` | `src/server.h:71` / `src/desktop.h:120` | 无差异 |
| `wlr_output_layout_get_box` | 0.46 0.18.2 内嵌 wlroots 与 main 用的 0.20 均为 `(layout, output, &box)` | 无差异 |
| `wlr_seat_touch_get_point` | 0.18.2：`(struct wlr_seat*, int32_t touch_id)` | 无差异 |

结论：**1 条实质差异**（sequence 的 GUINT/GINT 映射），其余 API 0.46 与 main 同名同形。

## ② 将来在 trixie arm64 chroot 里真编设备件的配方

目标：产一个与设备在版形态一致的 arm64 release 件（动态链接系统 `libwlroots-0.18.so`）。**注意**：本次 API 验证是在宿主 x86_64 + embed-wlroots(0.18.2 static) 做的（见下「本次验证」），chroot 编译尚未执行。

```sh
# 需要一个 Debian trixie arm64 chroot（含 build-essential meson ninja
# libwlroots-0.18-dev libgnome-desktop-3-dev libglib2.0-dev 等）。
# 以 /opt/elden/arm64-sid 为例（如需 trixie 请另建 chroot）：
CH=/opt/elden/arm64-trixie
SRC=<本仓库>/build/phoc046-edge-swipe
DEST=$CH/build-phoc046-edge-swipe
rm -rf "$DEST" && mkdir -p "$DEST"
tar -C "$SRC" --exclude=./build-host --exclude=./.git --exclude=./subprojects/wlroots/subprojects -cf - . | tar -C "$DEST" -xf -
chroot "$CH" /bin/sh -c "cd /build-phoc046-edge-swipe && \
  meson setup build --buildtype=release -Dembed-wlroots=disabled -Dtests=false && \
  ninja -C build src/phoc"
# 产物：$DEST/build/src/phoc
objdump -p $DEST/build/src/phoc | awk '/NEEDED/{print $2}'   # 必含 libwlroots-0.18.so
objdump -T $DEST/build/src/phoc | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -1   # ≤ 2.41
```

要点：`--buildtype=release`（设备件不要 debug 宏）、`-Dembed-wlroots=disabled`（链接系统 wlroots 0.18）、trixie 的 glibc 2.41 决定可移植下限。

## ③ 设备安装 / 回滚步骤（参考 scripts/phoc-install.sh，设备上 root 执行）

```sh
# 0) 备份判定：记录在版原件指纹
sha256sum /usr/bin/phoc > ~/phoc-046-orig.sha256

# 1) 建立 divert（把发行版原件挪到 .dpkg-dist，之后 apt 重装也覆盖不了 /usr/bin/phoc）
dpkg-divert --package elden-phoc-override --divert /usr/bin/phoc.dpkg-dist --rename /usr/bin/phoc

# 2) 安装新件
install -m 0755 <新编译的 phoc> /usr/bin/phoc

# 3) 钉住，防止版本升级换掉 .dpkg-dist
apt-mark hold phoc

# 4) 重启会话（greetd 拉起 phoc）
systemctl restart greetd
```

回滚：

```sh
apt-mark unhold phoc
dpkg-divert --package elden-phoc-override --rename --remove /usr/bin/phoc
# ↑ 会把 .dpkg-dist 原件挪回 /usr/bin/phoc；若 divert 记录已丢，手工恢复：
#   cp -a /usr/bin/phoc.dpkg-dist /usr/bin/phoc
sha256sum -c ~/phoc-046-orig.sha256   # 校验回到在版原件
systemctl restart greetd
```

## ④ 安装前必过的判据（全部满足才允许上设备）

1. `objdump -p <new-phoc> | awk '/NEEDED/{print $2}'` 必须包含 **`libwlroots-0.18.so`**（否则链接形态与在版不符，拒绝安装）；
2. `objdump -T <new-phoc> | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -1` 的 max GLIBC 符号版本 **≤ 2.41**（trixie 在版 glibc）；
3. `dpkg-divert --list | grep elden-phoc-override` 与 `apt-mark showhold | grep -qx phoc` 均在位（参照 scripts/phoc-install.sh 双层防护，缺一即回退）；
4. `sha256sum /usr/bin/phoc.dpkg-dist` 与安装前记录的原件指纹一致（.dpkg-dist 必须是发行版原件，否则回滚无门）。

## 本次验证（API 级编译）

- 树：`build/phoc046-edge-swipe`（0.46.0 副本 + 补丁），`git apply --check` 到 `/tmp/ph046/phoc-0.46.0` 原树 **通过**。
- 宿主 x86_64 编译（**非 arm64、非设备二进制**，wlroots 用内嵌 0.18.2 static，与设备同 wlroots 主版本）：
  `meson setup build-host -Dembed-wlroots=enabled -Dwlroots:default_library=static -Dwlroots:renderers=gles2 -Dwlroots:backends=drm,libinput -Dwlroots:werror=false -Dxwayland=disabled -Dtests=false && ninja -C build-host src/phoc` → **成功链接 `build-host/src/phoc`**（BuildID cdc90f16…）。
  为让内嵌 wlroots 在宿主可编，向 `subprojects/wlroots/subprojects/` 加了 seatd/libdisplay-info 两个 wrap，并关掉 wlroots 的 `werror`（新 GCC 的既有 const 告警），均为验证树内临时件、不在补丁内。
- **卡点**：arm64 chroot（`/opt/elden/arm64-sid`）编译需要 root chroot 权限，本 worker 无 sudo（`sudo_exec` 仅主会话可用），故 arm64 维度未跑；按②配方由主会话补跑即可。
