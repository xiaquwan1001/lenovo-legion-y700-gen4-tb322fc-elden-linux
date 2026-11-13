# WITHDRAWN 2026-11-13 —— 见 PITFALLS #646：
#   本浮条上机实测会打断焦点/输入上下文（页面被顶掉再回来、组字缓冲被直接提交），
#   已从 daily-baseline.sh 撤下、设备上已 disable。重做要求：layer-surface **全程不 unmap**，
#   只用透明度/内容切换，并先在合成器侧证明不抢焦点。
#!/usr/bin/env python3
"""elden-ime-candidates — kimpanel 候选/preedit 浮条（GTK4 + layer-shell）

为什么需要它（2026-11-13，PITFALLS #645）：
  fcitx5 同一时刻只有一个 UI addon 生效。本机 `CurrentUI=kimpanel`（classicui 在 phoc 上建不出窗，
  见 #619），于是 **preedit 与候选窗必须由「面板」自己画** —— 而面板是 elden-ime-focusd，
  它只负责把 kimpanel 的 SetRelativeSpotRect 翻成 sm.puri.OSK0.SetVisible（弹/收虚拟键盘），
  从来不渲染任何东西 ⇒ 用户「中文能上屏但看不见组字、也看不见候选」。

本进程就是那个「画」的部分：focusd 把 kimpanel 收到的内容转发成自己的信号
（`org.elden.ImePanel` on `org.kde.impanel`, path `/org/elden/ImePanel`）：
  Lookup(s preedit, as items, i cursor) / Show(b) / Spot(iiii)
本脚本订阅后画一条贴光标位置的浮条：上行 preedit（组字串），下行候选（当前项高亮）。

判据（自己就能查）：
  * `systemctl --user is-active elden-ime-candidates` = active
  * 在 Firefox/GTK 输入框里打 `ni` ⇒ 屏上出现 `ni` + `1 你 2 那 3 呢 …`（截图为准）
  * 收起键盘（或失焦）⇒ 浮条一起消失
  * 日志：`~/.local/state/elden-ime-candidates.log`

依赖：`python3-gi gir1.2-gtk-4.0 libgtk4-layer-shell0 gir1.2-gtk4layershell-1.0`（daily-baseline.tsv 已含）
"""
import os
import sys

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")

try:
    gi.require_version("Gtk4LayerShell", "1.0")
    from gi.repository import Gtk4LayerShell as LayerShell
    HAVE_LAYER = True
except (ValueError, ImportError):
    HAVE_LAYER = False

from gi.repository import Gdk, Gio, GLib, Gtk  # noqa: E402

LOG = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
                   "elden-ime-candidates.log")


def log(msg: str) -> None:
    try:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as fh:
            fh.write(msg + "\n")
    except OSError:
        pass


XML = """
<node>
  <interface name="org.elden.ImePanel">
    <signal name="Lookup">
      <arg type="s" name="preedit"/>
      <arg type="as" name="items"/>
      <arg type="i" name="cursor"/>
    </signal>
    <signal name="Show"><arg type="b" name="visible"/></signal>
    <signal name="Spot">
      <arg type="i" name="x"/><arg type="i" name="y"/>
      <arg type="i" name="w"/><arg type="i" name="h"/>
    </signal>
  </interface>
</node>
"""


class Strip(Gtk.Window):
    def __init__(self) -> None:
        super().__init__()
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_can_focus(False)
        self.set_focusable(False)
        # 内容清空时不留一个 20x12 的小黑点（实测 2026-11-13）
        self.set_size_request(240, 56)

        self.preedit = Gtk.Label(label="")
        self.preedit.set_xalign(0.0)
        self.preedit.add_css_class("preedit")
        self.items_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.items_box.set_halign(Gtk.Align.START)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        box.set_margin_top(6)
        box.set_margin_bottom(6)
        box.set_margin_start(10)
        box.set_margin_end(10)
        box.append(self.preedit)
        box.append(self.items_box)
        self.set_child(box)

        css = Gtk.CssProvider()
        css.load_from_data(b"""
        window { background: alpha(#1b1b1f, 0.92); border-radius: 10px; }
        label.preedit { font-size: 15px; color: #c8c8cc; }
        label.cand { font-size: 17px; color: #f5f5f7; padding: 2px 6px; border-radius: 6px; }
        label.cand.cur { background: alpha(#3584e4, 0.85); color: #ffffff; }
        """)
        Gtk.StyleContext.add_provider_for_display(self.get_display(), css,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self.spot = (0, 0, 0, 0)
        self.cand_labels = []
        # fcitx5 在同一段组字里会「有候选 / 空候选」交替发（实测 2026-11-13，单 IC 也一样），
        # 直接跟最后一条事件会闪成不可见 ⇒ Show(false) 延迟 400 ms 生效，期间来 Show(true) 就取消。
        self._hide_src = 0
        if HAVE_LAYER:
            LayerShell.init_for_window(self)
            LayerShell.set_namespace(self, "elden-ime-candidates")
            LayerShell.set_layer(self, LayerShell.Layer.OVERLAY)
            LayerShell.set_anchor(self, LayerShell.Edge.TOP, True)
            LayerShell.set_anchor(self, LayerShell.Edge.LEFT, True)
            LayerShell.set_exclusive_zone(self, 0)
            LayerShell.set_keyboard_mode(self, LayerShell.KeyboardMode.NONE)
        else:
            log("warn: no Gtk4LayerShell → 普通窗口（位置会不准）")

    # ---- 位置：kimpanel 给的是「相对焦点窗口」的光标矩形，这里当屏幕坐标用并夹到屏内 ----
    def _apply_spot(self) -> None:
        x, y, w, h = self.spot
        mon = Gdk.Display.get_default().get_monitors().get_item(0)
        if mon is None:
            return
        geo = mon.get_geometry()
        px = max(0, min(x, geo.width - 40))
        py = max(0, min(y + h + 6, geo.height - 120))
        if HAVE_LAYER:
            LayerShell.set_margin(self, LayerShell.Edge.LEFT, int(px))
            LayerShell.set_margin(self, LayerShell.Edge.TOP, int(py))

    def on_lookup(self, _conn, _sender, _path, _iface, _signal, params) -> None:
        preedit, items, cursor = params.unpack()
        items = list(items)
        if not items and not preedit:
            # fcitx5 每个按键都会穿插「空 lookup」事件（实测 2026-11-13）；空事件不清屏，
            # 收起统一由 Show(false) 决定（那里有 400 ms 去抖）。
            return
        log("Lookup preedit=%r items=%r cursor=%d" % (preedit, items[:6], cursor))
        if preedit:
            self.preedit.set_text(preedit)
            self.preedit.set_visible(True)
        elif items:
            pass            # 有候选但 preedit 空：保留上一次的组字串，别把上行清空造成闪跳
        else:
            self.preedit.set_text("")
            self.preedit.set_visible(False)
        for lb in self.cand_labels:
            self.items_box.remove(lb)
        self.cand_labels = []
        for i, text in enumerate(items):
            lb = Gtk.Label(label=text)
            lb.add_css_class("cand")
            if i == cursor:
                lb.add_css_class("cur")
            self.items_box.append(lb)
            self.cand_labels.append(lb)
        self._apply_spot()

    def on_show(self, _c, _s, _p, _i, _sig, params) -> None:
        (vis,) = params.unpack()
        log("Show(%s) spot=%s" % (vis, self.spot))
        if vis:
            if self._hide_src:
                GLib.source_remove(self._hide_src)
                self._hide_src = 0
            self._apply_spot()
            self.set_visible(True)
            self.present()
            GLib.timeout_add(300, self._diag)
        else:
            if self._hide_src:
                return
            self._hide_src = GLib.timeout_add(400, self._hide_now)

    def _hide_now(self) -> bool:
        self._hide_src = 0
        self.set_visible(False)
        return False

    def _diag(self) -> bool:
        log("diag mapped=%s size=%sx%s" % (self.get_mapped(), self.get_width(), self.get_height()))
        return False

    def on_spot(self, _c, _s, _p, _i, _sig, params) -> None:
        self.spot = params.unpack()
        log("Spot %s" % (self.spot,))
        self._apply_spot()


def main() -> int:
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    node = Gio.DBusNodeInfo.new_for_xml(XML)
    win = Strip()
    # 先 bind 再订阅（GDBusConnection.signal_subscribe 不需要 node，但保留以便将来启用手势）
    _ = node
    for sig, cb in (("Lookup", win.on_lookup), ("Show", win.on_show), ("Spot", win.on_spot)):
        # sender=None：路径+接口是我们专用（/org/elden/ImePanel + org.elden.ImePanel），
        # 不绑死发送方名反而便于主机侧用 `busctl emit` 做无输入法的渲染自检。
        bus.signal_subscribe(None, "org.elden.ImePanel", sig,
                             "/org/elden/ImePanel", None,
                             Gio.DBusSignalFlags.NONE, cb)
    log("strip ready (layer=%s)" % HAVE_LAYER)
    GLib.MainLoop().run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
