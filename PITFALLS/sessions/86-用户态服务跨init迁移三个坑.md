# 86 · 用户态服务跨 init 迁移的三个静默坑（#397）

**日期**：2026-10-25 · **pi 会话 id**：宿主会话 · **主题**：`packaging/elden-userland/` 落地时实测踩到的三个「不报错、只失效」坑
**证据**：`reports/userland-service-inventory-20261025.md` §3.3/§3.4、`packaging/elden-userland/tools/{render.py,verify.sh}`

## #397a OpenRC 服务名 ≠ systemd 单元名（依赖被静默忽略）

`Requires=localmount` / `After=seatd dbus elogind networkmanager lxc` 在 systemd 上**语法合法但不报错地忽略**
（`systemd-analyze verify` 输出 `Failed to add dependency on localmount, ignoring: 无效的参数`）。
后果 = 服务乱序：greetd 早于 seatd ⇒ 无桌面（复现 `PITFALLS #318`），但日志里看不到任何 error。

正确映射（本项目实测）：`localmount→local-fs.target`、`dbus→dbus.service`、`seatd→seatd.service`、
`elogind→elogind.service`、`networkmanager→NetworkManager.service`、`bluetooth→bluetooth.service`、
`udev→systemd-udevd.service`、`lxc→lxc.service`、`modules→systemd-modules-load.service`。

**门禁**：`render.py` 对未映射的依赖名直接抛错（映射表 `UNIT_MAP` + 本包服务名白名单），
`verify.sh §D` 再跑一遍 `systemd-analyze verify`（滤掉离线路径不存在）。

## #397b `bash` 不接受「函数体里只有注释」

```
$ printf 'f() {\n\t# c\n}\n' | bash -n
bash: 行 3: 未预期的记号 "}" 附近有语法错误
```
生成 OpenRC 的 `depend() { }` 时若依赖集为空、只塞了一行注释，产物就是语法错误（rc=2），
服务起不来。**修法**：空分支必须留一个真语句，例如 `: # 无依赖`。

## #397c `while read` 循环里裸调 `ssh` 会吞掉循环的 stdin

`while IFS=... read -r ...; do got=$(ssh host cmd); done < file` 只会处理**第一行**——
`ssh` 吃掉剩余 stdin。本项目的症状最阴：设备漂移比对从 66 条缩成「ok 1 条」，看起来是**全绿**。
**修法**：`ssh -n`（或 `< /dev/null`）。同理适用于 `ffmpeg`、`git` 等会读 stdin 的命令。
