# USERLAND-STACK-2026-10-05：用户态发行版/桌面选型复核 + 用户态服务 bug 分类

> 承接本会话前两问（Alpine+Phosh 选型史、boot 分区内容、UEFI 是否值得）之后续。
> 目标：①评估"Phosh 栈陈旧 / Alpine 用户态弱"是否成立；②判断**换更大发行版能否避免**部分 bug；
> ③把**可能与用户态服务有关的 bug 单列并延迟排查**，避免与内核态问题混淆。
> **本会话纯主机侧，未上机、未改设备**。结论以领域层（`TASKS.md`/`PITFALLS.md`）为准；本文为过程证据，只增不改。
> 证据来源：本地 `PITFALLS.md` #48–#53/#70–#77/#89/#100/#103、`archive/topics/DT-UI-2026-10-05.md`、
> `TASKS.md` G1-26/27/28、Q24；上游 Phosh/Alpine/pmOS/KDE 发布页 + 两个 Qualcomm DSI 公开案例（§7）。

---

## 0. 一句话结论

- **Phosh 不"陈旧"，是被发行版钉住**：Alpine stable 3.24 = Phosh **0.55.0（2026-05-17）**，上游最新 **0.57.0（2026-08-19）**，
  Alpine **edge 已有 0.57.0-r3**；GTK3→GTK4 移植在推进但**未成为默认**。
- **不需要换大发行版**：已知 ~14 个用户态 bug 中 ~7 个属"会话/PAM/logind/busybox"类，**换 systemd+logind+greetd 一次清掉**——
  而 **postmarketOS 已在 Alpine(musl) 上用 `greetd+phrog+logind` 解决**（25.12 起，26.06 用 systemd 261）。
  我们缺的是**会话管理**，不是 Ubuntu。
- **~3 个 bug 换发行版无效**（GTK3 主题语义、phoc 小数 scale、glycin 打包），只能靠升 Phosh / 改配置 / 打补丁。
- **Q24 熄屏→硬复位必须隔离**：既有"内核 DSI blank 挂总线→APSS watchdog"的公开同类案例，也有"UPower 假低电→logind PowerOff→USB 自启"的用户态假设；
  在隔离实验前**既不当内核 bug 深挖，也不列入用户态 bug 单**。

---

## 1. 范围与背景

- 历史选型：Alpine+Phosh 是"照参考仓库 `Y700-elden-linux` 复现 + 被当时 2.3 GiB 持久根限制"的结果（见 `archive/topics/复盘.md`、`HANDOFF.md` §21.5/§22.8）。
- 现状桌面：U2 持久直启，**Alpine 3.24.2 + Phosh 0.55.0 + phoc 0.55.1 + GTK3 3.24.52 + libadwaita 1.9.2 + gnome-session 48.0 + gsd 50.1 + elogind 255.24 + seatd**；
  **无 systemd、无登录会话**（`loginctl list-sessions` 为空）。
- 已知用户态故障集中在"会话/登录/PAM/总线/电源"这一圈，且**大量是自研 `/init` + 手工拉起会话**造成，不是内核问题。

---

## 2. 桌面栈新鲜度（数字）

| 组件 | 本机/ Alpine stable 3.24 | Alpine edge | 上游最新 | 备注 |
|---|---|---|---|---|
| Phosh | 0.55.0（2026-05-17） | **0.57.0-r3（2026-09-18）** | **0.57.0（2026-08-19）** | 6 周一个版本；**GTK4 移植进行中，未默认**（仍发 GTK3 stable 线） |
| phoc | 0.55.1 | edge 同步 | 随 Phosh | wlroots 合成器 |
| GTK | 3.24.52 | — | — | 旧主因是 Phosh/phoc 用 GTK3 |
| Plasma Mobile | 6.6.6（6.6 末版，2026-07） | **6.7.5（2026-09-09）** | 6.7.x（2026-06 起） | Qt6/KF6，栈新、平板手感好 |
| postmarketOS | 26.06：systemd 261 / Phosh 0.55 / Plasma 6.6 | — | — | 25.12 起切 **greetd+phrog**；Phosh 走 **systemd-logind**（OpenRC 则为 elogind） |

**判读**：
- "Phosh 陈旧"成立的部分 = **GTK3 外壳 + GNOME 守护进程链**（gsd/gnome-session 依赖 UPower/logind），这是用户态 bug 的温床。
- "陈旧"不成立的部分 = Phosh 自身活跃（0.57、GTK4 在推）、Alpine **stable 钉版**是可以自己升 edge 解决的。
- Plasma Mobile 栈更新更现代，但换它 = 换 **KWin** 合成器，本机（SM8750/双 DSI/DSC）**无任何验证**，且同样依赖 logind 会话。

---

## 3. 用户态服务 bug 清单（★建议全部延后，勿与内核态混）

> 判据：根因在**用户态服务链**（PAM/logind/session bus/busybox/GTK/phoc/PipeWire），而非内核驱动。
> "换发行版"列：✅=会被 systemd+logind+greetd 类发行版清掉；◐=看打包；❌=换发行版无效。

| ID | 现象 | 本地证据 | 归因层 | 换 systemd/logind/greetd |
|---|---|---|---|---|
| U1 | **亮度滑块无效**（G1-28） | `DT-UI` §4：elogind `Session.SetBrightness` 恒 `EISDIR`；`loginctl list-sessions` 空、无 VT/active tty0 | elogind 无 session/VT | ✅ 高（greetd/logind 建真实会话；或 phosh sysfs 后端） |
| U2 | **锁屏 PIN 永远不过**（#48） | minirootfs `/etc/pam.d` 几乎为空（仅 polkit-1） | PAM 配置缺失 | ✅ 高 |
| U3 | **熄屏后无法唤醒**（#72） | 无 `/run/dbus/system_bus_socket`→gsd-power 退；`dbus-daemon-launch-helper` 装成 `root:root 4750`（应 root:messagebus） | Alpine 打包 + 系统 bus 未起 | ✅ 高 |
| U4 | **gnome-session fail whale**（#51） | `org.gnome.SettingsDaemon.Power` 无 UPower/logind→`exit 1`→required component 失败 | 守护进程依赖缺失 | ✅ 高 |
| U5 | **phoc 退出后起不来**（#70） | seatd `seat is VT-bound and has an active client`；`/run/seatd.sock` 残留 | 无会话管理 | ✅ 高 |
| U6 | **关机/重启"假成功"**（#89） | busybox 符号链接的 `poweroff/reboot/halt` 不带 `-f` 只 `kill(1,…)`；PID1=sh 不响应 | Alpine busybox + 自研 PID1 | ✅ 高（已有本地 wrapper 兜底） |
| U7 | **dconf 不持久 / HOME=/**（#76、#103） | `/init` 未 export HOME→dconf 写 `/.config`；裸 `gsettings set` 无 session bus 静默失效 | 自研 init + 无会话 bus | ✅ 中（PAM 设 HOME；自研 init 仍可能干扰） |
| U8 | **深色无效 / 图标反色 / accent 不变**（G1-26/27） | `DT-UI` §2/§3：GTK3 `Adwaita-dark` 解析回退浅色；phosh 对 `theme=='Adwaita-dark'` 提前 return | GTK3 主题名语义 + phosh guard | ❌ 升 Phosh/GTK4，或改 `gtk-theme='Adwaita'` |
| U9 | **小数 scale 量化→g-c-c 恒显 100%**（#77） | phoc 只精确上报整数 scale；不在支持列表的 phoc.ini 值被忽略 | phoc/wlroots | ❌ |
| U10 | **glycin/bwrap→phosh abort**（#49） | gdk-pixbuf 2.44 全走 glycin，bwrap 沙盒 loader `exit 1` | 打包 + 内核 openat2 | ◐ 看发行版打包（Debian/Arch 可能已修） |
| U11 | **apk 说已装但文件缺**（#50） | `mesa-gl` installed 但 `libGL.so.1` 缺失 | 我们手删 Mesa 的**自伤** | ❌ 非 bug |
| U12 | **PipeWire 占 `/dev/media0`→相机 busy**（#100） | PipeWire/WirePlumber 默认占 media 节点 | 用户态媒体栈 | ◐ 发行版无关；pmOS/libcamera 集成或不同 |
| U13 | **Waydroid bionic Mesa 不认 A830 chip-id** | project 记忆：容器 bionic Mesa 26.0.8 不认 0x0/0xe844050000 | 容器内 bionic Mesa（G2） | ◐ 需换 Waydroid vendor 镜像，与宿主发行版无关 |
| U14 | **开机时间回 1970**（#73） | PMIC `rtc-pm8xxx` 只读，`hwclock -w` 报 `No such device` | 硬件 RTC + NTP 兜底 | ❌ 硬件；任何用户态都要 NTP |

**内核/驱动类（不得混入上表，也不要用用户态手段归因）**：
Q24 熄屏→硬复位（见 §5）、vblank 超时/显示间歇（#16）、ath12k bind 后崩（#44）、TF 卡写丢失（#55）、
BT IBS 深度睡眠（#78）、充电限流（#79）、kexec `-e` 硬挂、`deep` suspend 挂死（#64）。

---

## 4. 切换更大发行版能否避免？——能，但**不必整体换**

| 方案 | 一次清掉 | 成本/风险 | 结论 |
|---|---|---|---|
| **现 Alpine + greetd+phrog+elogind 会话**（照 pmOS 25.12 做法） | **U1–U7** | 低：只改会话启动链，不动内核/DT；Alpine edge 已有 `greetd-phrog`、`phosh-systemd` | ★首选 |
| **rootfs 升 Alpine edge** | U8 部分（Phosh 0.57 修主题/accent）、Plasma 6.7.5 | 低（主机重打 rootfs） | 建议 |
| **postmarketOS**（Alpine+systemd+greetd+phrog） | U1–U7 + 现成移动集成 | 中：以 pmaports 设备包方式适配，或复用其用户态包 | 备选 1 |
| **Mobian / Debian+Phosh** | U1–U7（systemd+logind+PAM 原生） | 中高：debootstrap 重建、包版本与构建流程全换 | 备选 2 |
| **Ubuntu** | U1–U7 | 高：无 Phosh 移动集成、内核/用户态漂移大（Ubuntu Touch 走 Lomiri） | 不划算 |
| **Plasma Mobile（任一发行版）** | 不解决上述（同样要 logind 会话） | 高：换 KWin，本机未验证，同一 DSI blank 风险 | 暂不 |

**桌面去留建议**：**现在不换桌面**。Phoc/wlroots 已在本机跑通（DRM plane = phoc），先做会话 overhaul（收益最大、风险最低）；
若 overhaul 后 Phosh 的 GTK3 工具链问题仍突出，再评估 Plasma Mobile（届时需为 KWin 单独立 bring-up 项）。

---

## 5. Q24（熄屏→硬复位）用户态/内核隔离协议 ★

> 目的：把"用户态触发 + 内核故障"与"纯用户态电源动作"分开；**在隔离完成前不定级、不深挖**。

已知两个可信先例：
- **内核类**：高通 DSI 屏 + DPMS off/blanking → DSI 总线挂死 → **APSS watchdog 复位**（~60–90s、无 panic、pstore 空），
  与 Q24 现象一致；对策在 DSI/panel blank/ULPS 路径（见 §7 Marker284 案例）。
- **用户态类**：UPower 因电量算法缺失报 `capacity=-1`→critical，经系统 bus 调 `login1 PowerOff(false)`；
  **USB 在插时 VBUS 会触发自动开机**，表现也像"硬复位"、pstore 同样为空（见 §7 xiaomi-thunder 案例）。

最小隔离实验（待上机，单变量）：
1. **纯 DRM 触发**：最小会话（不跑 phoc/gsd/UPower）用 `drmModeSetCrtc`/`wlr-randr --off` 关 DSI connector。
   仍复位 ⇒ 内核 DSI/panel blank 路径。
2. **用户态触发**：仅在 phosh+logind+UPower 路径下熄屏，同时监控 `upowerd`/`logind` 是否发 `PowerOff`。
   仅此路复位 ⇒ 用户态电源动作（假低电）。
3. 判据：仅 1 = 内核；仅 2 = 用户态；都复现 = 两个独立 bug。

> 与既有决定一致：**Q24 仍"停止深究"**；若续须长时窗+多样本+单变量（见 `TASKS.md` Q24 / `archive/topics/REBOOT-5MIN-2026-10-05.md` §7.9）。

---

## 6. 建议动作（主机侧可做，不占设备）

1. 建 **userland-service backlog**（U1–U14），**全部冻结**，直到驱动主线结束；只保留"会话 overhaul"作为前置。
2. 出 **greetd+phrog+elogind 会话切换方案**（Alpine 侧最小改动），预期一次清 U1–U7；
   注意 `LIBSEAT_BACKEND=seatd`（有案例：logind 后端会 deactivate session → phoc 释放显示 → 关 CRTC 挂面板）。
3. 评估 **rootfs 升 Alpine edge（phosh 0.57）** 的代价与回退。
4. 登记 **Q24 隔离实验**（§5）到待上机最小实验清单。
5. 不新建桌面/发行版迁移工作，除非 §6.2 之后仍有阻塞。

---

## 7. 证据与出处

**本地**：`PITFALLS.md`（#48–#53、#70–#77、#89、#100、#103）；`archive/topics/DT-UI-2026-10-05.md`；
`TASKS.md`（G1-26/27/28、Q24）；`archive/topics/复盘.md` / `HANDOFF.md` §21.5/§22.8（选型史）。

**上游（本轮检索，2026-10-05）**：
- Phosh 发布页 `phosh.mobi/releases/`（0.57.0 / 2026-08-19；GTK4 移植在推）。
- Alpine 包库 `pkgs.alpinelinux.org`：`edge/community/aarch64/phosh`=**0.57.0-r3**、`plasma-mobile`=**6.7.5**；
  `phosh` 依赖/被依赖含 `polkit-elogind`、`greetd-phrog`，子包含 `phosh-systemd`。
- postmarketOS 25.12 发布说明（切 greetd+phrog）、26.06（systemd 261）；Nura(postmarketOS) Wiki Phosh
  （"Phosh 用 `systemd-logind`（OpenRC 为 elogind）+ greetd + phrog 启动"）。
- `samcday/phrog`（移动 greeter）。
- `vitoramaral10/pmos-xiaomi-thunder#7`："Bring up the Phosh greeter"——列举 seatd/logind、bubblewrap/openat2、glib faccessat、
  UPower critical→PowerOff、blanking 释放 buffer 等整类用户态阻塞；并给出 `LIBSEAT_BACKEND=seatd` 的关键教训。
- `Marker284/samsung-gts7xllite-display-touch`："90-Second Screen Blanking / DPMS Trap"——DSI blank 挂总线→APSS watchdog 复位。

---

## 8. 待办（交接）

- [ ] greetd+phrog+elogind 会话方案（先主机侧出步骤与回退）。
- [ ] Alpine edge Phosh 0.57 rootfs 升级评估。
- [ ] userland-service backlog 建表并在领域层登记"延后"。
- [ ] Q24 隔离实验（纯 DRM vs phosh 路径）排期。

---

## 附录：同会话前置结论（速记，详见他处）

- **Alpine+Phosh 由来**：照 `Y700-elden-linux` 复现 + 2.3 GiB 持久根限制（Phosh 0.9 G 能装 / Plasma 1.6 G 装不下）→ 详 `HANDOFF.md` §21.5/§22.8。
- **boot 分区**：`boot_a/b`、`dtbo`、`vbmeta`、`init_boot`、`vendor_boot`、`recovery` 在 **LUN4 `/dev/sde`**（`boot_b=sde45`），分区 **96 MiB**；
  现值 `boot_b` 内塞了**整套 Alpine rootfs ramdisk（~62.6 MB）**，应只留 **kernel `Image.gz` + ~1 MB busybox initramfs + DTB**（`out/boot-elden-vk52-slim.img`=**20.8 MiB**）；
  rootfs/模块/固件放 `linux17`；**内核版本必须与 `linux17:/lib/modules` 一致**。
- **UEFI**：**当前不值得/已搁置**。路线 A 卡 Mu Pakala **UFS 初始化**（系统性移植缺口，上游 issue 已发）；路线 B 在 `secure:yes` 下风险高；
  其要解决的 96 MiB 限制已被 slim(路线 C) 解决。仅当 Mu Pakala UFS 上游修复或出现多系统/TF 引导需求时再启。
