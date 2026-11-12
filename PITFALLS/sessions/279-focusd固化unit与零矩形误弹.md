# #624 focusd 固化（systemd user unit）+ 「自动弹/收」四个真缺口

- 日期：2026-11-12
- pi 会话 id：本项目会话（11-12 晚）
- 主题：G1-38「OSK 自动弹出/收起没做好」的处置 (a) 落地与上机判据
- 静态取证全量：`reports/ime-osk-lifecycle-20261112.md`（§0–§5，平板当时在 Android，无 Linux 实测）

## 结论（四个缺口）

- **桥没固化**：现役 Debian 根里 `elden-ime-focusd` 原本没有任何自启安装点（无 unit、`out/stage-debian`
   无二进制/无 autostart；唯一 `.desktop` 属 Alpine+squeekboard 世代）⇒ 手工起的进程一重登就没了。
- **收起判据不全**：旧代码只认 `Fcitx.Controller1.State==0`；`State==1`（IC 仍在）不收起 ⇒ 同窗换到非输入控件、
   或 Alt+Tab 到另一个已建 IC 的窗口时**漏收**；`State==-1`（fcitx5 不在）旧代码**故意不收起** ⇒ 僵尸键盘永久悬浮。
- **零矩形误弹**：`SetRelativeSpotRect` 的矩形参数旧代码 `(void)params` 丢弃，fcitx5 建 IC 时那次
   `(0,0,0,0)` 也当「有人要打字」⇒ 误弹。
- **打字卡顿**：每次光标矩形更新都在 kimpanel 回调里做**同步** D-Bus `Get Visible`（500 ms 超时），
   `SetLookupTable` 被排队在后，且超时会把本地 `osk_visible` 误置 FALSE 后重发 show。

## 处置（已落地）

- 新 unit `rootfs/debian/ime/elden-ime-focusd.service`：`/etc/systemd/user/` + `graphical-session.target.wants`
  （照 `fcitx5.service` 的既有模式；`daily-baseline.sh` §3b2 负责安装/启用/巡检）。
- 源码四改（`patches-userland/zh-ime/elden-ime-focusd.c`）：
  ① 零矩形只记「疑似失焦」，持续 2 s 才收（避免打字抖动误收）；
  ② `Enable(false)` 立即收；③ `State==-1` 连续 5 次 ⇒ 收（fcitx5 崩了不留僵尸）；
  ④ 订阅 `sm.puri.OSK0` 的 `PropertiesChanged` 维护本地可见性，回调路径零 D-Bus 往返；
  ⑤ 兜底超时 `ELDEN_IME_IDLE_SEC`（默认 300 s）。
- 产物 `out/ime-host/elden-ime-focusd` sha `c76dbee7…`（72 776 B，arm64 glibc），`MANIFEST.tsv`/`sources.tsv` 已同步。

## unit 化的坑（本轮新踩）

旧 `~/.config/autostart/elden-ime-focusd.desktop` 仍会先抢 `org.kde.impanel`，而 `RequestName` 的
返回值旧代码**没看** ⇒ unit 里的进程注册失败退出，`Restart=always` 每 3 s 重拉一次（日志刷屏、状态反复）。
正解 = 退役旧 autostart（设备上改名为 `.disabled-20261112`）+ **检查 `RequestName` 的 `(u)` 结果**
（2/3 = 别人是主属主 ⇒ `return 0` 安静退出，别让 unit 空转；`Restart=always` 只对真崩溃生效）。

## 上机判据（2026-11-12 实测，设备 `7.3.1-debug-vk184-00002`）

| 判据 | 命令 | 结果 |
|---|---|---|
| unit 活着 | `systemctl --user is-active elden-ime-focusd` | `active` |
| 只有一个实例 | `pgrep -fc '^/usr/local/bin/elden-ime-focusd$'` | `1` |
| 桥拿到 kimpanel | `busctl --user status org.kde.impanel` | `PID` = unit 的进程 |
| 重登会自启 | `systemctl --user list-dependencies graphical-session.target` | 含 `elden-ime-focusd.service`；`is-enabled` = enabled |
| 崩溃自愈 | `kill -9 <pid>` 后 5 s | 自动拉起，`active` |
| 重复实例 | 手工再起一只 | `rc=0` + 日志 `already owned (result=2); exiting quietly` |
| 带矩形会弹 | `gdbus call … org.kde.impanel2.SetRelativeSpotRect 10 20 100 40` | `Visible=true` |
| 无 IC 会收 | 等 1–2 s（`State=0`） | `Visible=false` |
| 巡检 | `bash rootfs/debian/daily-baseline.sh --check` | §3b2 三项 ok、`MISS=0` |
| 重建性 | `packaging/elden-userland/tools/verify.sh --rebuildable` | `FAIL=0 WARN=0`，identical=4 |

### 真客户端端到端（同日晚补测，`firefox about:blank` 的 URL 栏自动获焦 = 真 IC）

| 场景 | 判据 | 结果 |
|---|---|---|
| 起 Firefox（URL 栏获焦） | `State` 0→1、`Visible` false→**true** | ✅ 日志 `show requested by SetRelativeSpotRect (0x72)` |
| 关 Firefox | `State`→0、2 s 内 `Visible`→false | ✅ 自动收 |
| 兜底超时（临时 drop-in `ELDEN_IME_IDLE_SEC=12`） | 有 IC 但 12 s 无 kimpanel 活动 | ✅ `hide requested by idle timeout`（随后 `set-environment` 复原 unit） |

**仍未验**：GTK3 / Qt 各一例、Alt+Tab 跨窗口切换时是否漏收、候选窗与 stevia 键盘是否重叠。

## 文件

- `rootfs/debian/ime/elden-ime-focusd.service`（新）
- `patches-userland/zh-ime/elden-ime-focusd.c`（改，四改 + RequestName 结果检查）
- `rootfs/debian/daily-baseline.sh`（§3b2 新增安装/启用/巡检块）
- `packaging/elden-userland/{MANIFEST.tsv,sources.tsv}`（sha/尺寸同步）
- 设备回退件：`/usr/local/bin/elden-ime-focusd.bak-20261112`、
  `~/.config/autostart/elden-ime-focusd.desktop.disabled-20261112`
