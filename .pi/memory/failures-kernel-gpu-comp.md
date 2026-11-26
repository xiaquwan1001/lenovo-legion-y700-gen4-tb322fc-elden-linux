# y700-elden — 内核/引导类失败与洞察：GPU / Adreno / 合成器（phoc-phosh）/ Wayland

> 2026-11-26 从 `failures-kernel.md`（199 KB / 346 条）按主题机械拆分：**每条逐字搬移，未改一字**。
> 检索口径不变：`mem -t project <关键词>`（= `~/.pi/agent/projects-memory/<repo>/` 软链到本目录，`find -name '*.md'`），拆分不需改工具。
> 入口与本表 = `failures-kernel.md`（索引件）。

---

Linux /init 不 export HOME 时 PID1 继承 HOME=/，phosh/phoc/dconf-service 把用户库写进 /.config/dconf/user，表现为 gsettings/dconf 改了不持久。修法：会话启动脚本 export HOME=/root 并迁移该文件。
---
调试纪律：用户态服务类 bug 的排查应被主动延后并与内核态问题分开——先标出「哪些 bug 可能与用户态服务（elogind/seatd/phoc/gsettings/D-Bus 激活等）有关」并单独建 lane，避免混入内核/驱动 bring-up 的定位。
---
真实熄屏 A/B 必须先确认桌面会话真的起来了（`ps -eo comm | grep -E '^phoc$|^phosh$'` + gsd-power + /run/user/0 会话总线），否则 `org.gnome.ScreenSaver.SetActive(true)` 是空操作、样本无效；本轮就因桌面未起产生过一轮无效样本。
---
做熄屏 A/B 前必须先确认桌面真的起来了（phoc / phosh / gsd-power 在跑 + /run/user/0/bus 会话总线存在），否则 ScreenSaver.SetActive 是空操作、样本无效——本轮曾出现「桌面未起导致熄屏空操作」，另有 phoc <defunct> 僵尸（start-desktop.sh 循环拉起会重启）。设备侧 boot_b = camdp-nocam/vk62 形态时普通 `reboot` 可自动回受控 Linux（约 70s）。
---
排查方向错误被源码推翻的教训（G1-34 旋转 2026-10-09）：先假设「D-Bus 总线错配（系统 vs 会话）」→ 在设备上做在线实验（把 proxy 挪到会话总线）→ 失败 → 才去读 phosh 源码 → 发现 phosh 0.55 原生 rotation-manager 只读系统总线、gsd 50 根本没有 orientation 组件。教训 = 桌面栈行为（谁读谁、从哪读）必须**先读源码确认**再下根因假设，不能仅凭「gsd 管方向」的 GNOME 传统认知推断。Phosh ≠ GNOME 全栈，其子系统实现可能完全不同。 — Failed: 假设驱动而非源码驱动的排查导致做了一次无效在线实验（停服务→改总线→发现无用→恢复），浪费 10+ 分钟
---
phosh 桌面会话的 D-Bus session bus 路径**不是** `/run/user/1000/bus`（该 socket 不存在），而是 `/tmp/dbus-<随机>`（由 phoc 启动时 dbus-launch 创建）。主机侧 gsettings/dconf 操作必须从 phoc 进程 environ 读实际地址：`DBUS=$(tr '\0' '\n' < /proc/$(pgrep phoc)/environ | grep DBUS_SESSION_BUS_ADDRESS | cut -d= -f2-) && DBUS_SESSION_BUS_ADDRESS="$DBUS" gsettings set ...`。直接 `XDG_RUNTIME_DIR=/run/user/1000 gsettings` 报 `dconf-WARNING: Could not connect: No such file or directory`。 — Failed: gsettings/dconf 连不上 session bus，idle-delay 等设置看似成功实际未写入
---
设备侧 meson 构建 phoc/phosh 时默认 buildtype=debug（-O0）——合成器必须用 --buildtype=release，否则性能不可用。本轮首编即栽此坑（debug 版 8.5MB vs release 2.2MB），发现后重编。正确 meson setup 命令：`meson setup output --prefix=/usr --buildtype=release`。
---
phoc 构建时 wlroots subproject 的 `0001-Revert-layer-shell-error-on-0-dimension-without-anch.patch` 在 `meson setup` 阶段触发 `patch: File to patch: Skip this patch? [y]`（因 patch 文件路径与 subproject 目录结构不匹配），但 **不影响编译**（meson 静默 skip、wlroots 仍正常构建）。看到此输出不必中断构建流程。
---
设备上热替换 /usr/bin/phoc 或 /usr/libexec/phosh 会报 `Text file busy`（ETXTBSY）——因为 greetd→gnome-session→phoc→phosh 进程链正在持有这些二进制。正确顺序 = `rc-service greetd stop` → cp 新文件 → `rc-service greetd start`（完整重启会话，不能只 kill）。 — Failed: 直接 cp 到运行中的 phoc 报 Text file busy
---
GNOME GitLab (gitlab.gnome.org) 对本机出口 IP（USTC/CERNET 教育网段）拦截注册（2026-10-11 实测确认）。所有 GNOME 项目的上游提交（phoc/phosh/gnome-* 等）需等申诉通过或换出口。phoc/phosh 的 GitHub 镜像 PhoshMobi/{phoc,phosh} 是 read-only mirror（issues 关闭、viewerPermission=READ），不能开 PR/issue。gh CLI 无法提交到 gitlab.gnome.org（只能操作 GitHub）。 — Failed: 用户尝试用 gh CLI 和浏览器登录 gitlab.gnome.org 提交 phoc/phosh 补丁，注册被 IP 拦截
---
Q28 日常内核其实本来就 GOOD、不构成 Waydroid 阻塞（2026-10-11 十三发冷起 + 日常路径验证）：设备 boot_b 的 UTS 恰是 `7.2.0-debug-vk64-gd02658e63cf6`（会话初期已稳定跑 3h）。之前「Q28 挡路」= 实验内核自伤（任何重编都撞 NOCARD）。但注意：同 UTS 串**也会 STORM**（一次日常纯净冷起实测 storm=45、vblank wait timed out、phoc=1/phosh=0、greetd=2，无 wayland-0 无会话总线）⇒ STORM 是独立随机，GOOD 串不保证 GOOD。
---
Waydroid 容器启动的 UID/身份铁律（2026-10-11 实测）：`waydroid container start` 只起 DBus 管理服务（id.waydro.Container），真正的 LXC 容器由 `waydroid session start` 拉起；**会话必须以建立会话的普通用户（uid 1000）身份发起**，用 root 会因跨 UID 的 D-Bus 认证失败（NoReply）静默卡在 `container failed to start`（wait_for_running 超时）。正确姿势 = `setpriv --reuid=1000 --regid=1000 --init-groups env HOME=/home/xuqianhui1001 XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DBUS_SESSION_BUS_ADDRESS=<phosh 的 /tmp/dbus-*>`。容器设备侧控制脚本 scripts/wd-ctl.sh（state/start/stop/session/net/route/egress/log/elapsed）与 scripts/waydroid-proxy-setup.sh 已按此修。
---
「仪表先验证再计数」在本项目反复具现：Q24 熄屏触发实验必须先证明屏真的关了（GetActive=true / DPMS=Off / bl_power 变化 / RPMh trace 有事件），否则样本全是假阴性——本轮 phosh 0.55 上 SetActive(true)/Lock() 返回成功但 GetActive 恒 false、DPMS 恒 On、trace 零事件，三组 S3 样本全部无效。phoc 卡 D 态（wchan=rpm_resume，栈 adreno_get_param→__pm_runtime_resume）+ a6xx_gmu_set_oob/msm_gpu_fault_crashstate_capture 同批 D 态 ⇒ 暖复位路径会损坏台架（PITFALLS #198），必须物理 POR 冷起才能做熄屏实验。 — Failed: 熄屏类实验因控制通路静默失败产生整轮假阴性
---
hit Q24 第 3 轮要在「唤醒」阶段死（不是熄屏）：S3 真实熄屏后 +11s 仍存活，死亡发生在随后的唤醒，末票 = gfx.lvl(0x30050)=1 / gmxc.lvl(0x300d0)=1（GPU 域上电 + NoC 批），与历史 mxc→0 签名不同。方法学：空白-保持-唤醒必须分段记 DEATH_AT。
---
设备侧会话总线：root 直连报 `Connection is closed`，必须 `setpriv --reuid=1000 --regid=1000 --init-groups` 降 uid=1000 并从 `pidof phosh` 的 /proc/<pid>/environ 取 DBUS_SESSION_BUS_ADDRESS / XDG_RUNTIME_DIR。另：`org.gnome.ScreenSaver.GetActive` 是**方法**不是属性，直接取属性报 `No such property "Active"`。
---
在设备上以 root 直连用户的 phosh 会话总线（`DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/dbus-*`）会报 `Error connecting: The connection is closed` 或 `Cannot autolaunch D-Bus without X11 $DISPLAY`——**必须 `setpriv --reuid=1000 --regid=1000 --init-groups env HOME=... XDG_RUNTIME_DIR=... DBUS_SESSION_BUS_ADDRESS=...` 降到会话属主 uid**（见 PITFALLS #203）。另 `org.gnome.ScreenSaver` 的 `GetActive` 是**方法**不是属性（属性读会报 `No such property “Active”`）；SetActive 的返回需显式取布尔（写成 `(true,)` 形式），`dbus-run-session` 起的会话每次冷启路径不同 ⇒ 每次都要从 `pidof phosh` 的 environ 现取 DBUS 地址。 — Failed: 在设备上以 root 直连用户会话总线失败，导致仪表硬门假失败、Q24 实验作废
---
fcitx5-remote / fcitx5 通过 DBus 与 fcitx5 主进程通信，**必须以同一 uid（会话用户，如 uid 1000）运行**，否则报 `Failed to create dbus connection`（Aborted）。root 直连会失败；需 `setpriv --reuid=1000 --regid=1000 --init-groups` + 正确的 `DBUS_SESSION_BUS_ADDRESS`（phosh 会话的 /tmp/dbus-*，非 /run/user/1000/bus）与 `XDG_RUNTIME_DIR`。注意 `setpriv` 没有 `--env-dbus` 选项。
---
「某次启动 GOOD」在同硬件/同镜像上不可复现时必须先怀疑判据而非下结论：P2b 的 10-13 GOOD 只查了 card0+phoc/phosh（未看屏、未数风暴签名），10-14 同 sha 复测 196 次 kickoff reset failure ⇒ 伪阳性。纪律：写 verdict 前必须（a）设备端全 dmesg（不只 grep 一种签名）、（b）三类风暴签名全数、（c）目视或截图确认面板真的出图；缺失任一即标「未验证」而非 GOOD。
---
P4a DSC 1.2 补丁已否证（2026-10-14）：面板 csot_pp8807hb1_1 声明 .dsc_version_minor=2，上游只按 1.1 PRE-SCR 算 RC 参数且不给 first_line_bpg_offset，故移植 vendor 的 DSC-1.2 (SCR) RC 参数 + first_line_bpg_offset（+46/−2，分支 p4/p2c-dsc12）——健康发（L1=L2=0、phoc/phosh/wayland 全起、可交互、音量键有声、电源键可控背光）下屏幕仍纯黑 ⇒ DSC 不是缺口。
