#!/usr/bin/env python3
"""kimpanel 探针：以 org.kde.impanel owner 身份起一个最小 panel 桩，打印收到的所有方法调用。

用途：判定 fcitx5 在「输入上下文 FocusIn / 光标矩形变化」时是否真的向后端 panel 发
D-Bus 调用（`SetRelativeSpotRect` 等）——这是 `elden-ime-focusd` 的触发信号前提。

用法（设备上，GUI 用户身份）：
    setpriv --reuid=1001 --regid=1001 --init-groups \
      env XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 \
      GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx \
      python3 kimpanel-probe.py 25

背景见 reports/ime-osk-pop-20261111.md 与 patches-userland/zh-ime/elden-ime-focusd.c。
"""
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

# 接口面按 fcitx5 的 kimpanel 模块实际调用面向抄（org.kde.impanel2 + 兼容 org.kde.impanel）。
XML = """
<node>
 <interface name='org.kde.impanel2'>
  <method name='SetRelativeSpotRect'><arg type='i' direction='in'/><arg type='i' direction='in'/><arg type='i' direction='in'/><arg type='i' direction='in'/></method>
  <method name='SetSpotRect'><arg type='i' direction='in'/><arg type='i' direction='in'/><arg type='i' direction='in'/><arg type='i' direction='in'/></method>
  <method name='Enable'><arg type='b' direction='in'/></method>
  <method name='ShowAux'><arg type='b' direction='in'/></method>
  <method name='ShowLookupTable'><arg type='b' direction='in'/></method>
  <method name='ShowPreedit'><arg type='b' direction='in'/></method>
  <method name='UpdateLookupTableCursor'><arg type='i' direction='in'/></method>
  <method name='UpdateLookupTable'><arg type='av' direction='in'/></method>
  <method name='UpdatePreeditText'><arg type='s' direction='in'/><arg type='b' direction='in'/></method>
  <method name='UpdateProperty'><arg type='av' direction='in'/></method>
  <method name='UpdateSpotLocation'><arg type='i' direction='in'/><arg type='i' direction='in'/></method>
  <method name='UpdateCursor'><arg type='i' direction='in'/></method>
  <method name='RegisterProperties'><arg type='av' direction='in'/></method>
  <method name='ExecMenu'><arg type='as' direction='in'/></method>
  <method name='PanelCreatedFromDbus'/>
  <signal name='Exit'/>
  <signal name='ReloadConfig'/>
  <signal name='MovePreeditCaret'><arg type='i'/></signal>
  <signal name='SelectCandidate'><arg type='i'/></signal>
  <signal name='TriggerProperty'><arg type='i'/></signal>
  <signal name='PanelCreated'/>
  <signal name='PanelExited'/>
  <signal name='TriggerKey'><arg type='u'/><arg type='u'/></signal>
 </interface>
</node>"""

count = {"n": 0}


def on_call(conn, sender, path, iface, method, params, inv):
    count["n"] += 1
    print(f"CALL[{count['n']}] {iface}.{method} {params.unpack()}", flush=True)
    inv.return_value(None)


def main():
    seconds = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    info = Gio.DBusNodeInfo.new_for_xml(XML)
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    bus.register_object("/org/kde/impanel", info.interfaces[0], on_call, None, None)
    print("registered /org/kde/impanel; owning org.kde.impanel ...", flush=True)
    Gio.bus_own_name_on_connection(
        bus, "org.kde.impanel", Gio.BusNameOwnerFlags.NONE, None, None
    )
    loop = GLib.MainLoop()
    GLib.timeout_add_seconds(seconds, lambda: (loop.quit(), False)[1])
    loop.run()
    print(f"TOTAL CALLS = {count['n']}", flush=True)


if __name__ == "__main__":
    main()
