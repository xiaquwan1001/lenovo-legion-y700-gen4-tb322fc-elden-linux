# phosh MR 提交材料（T20 / 2026-11-14）

> 用途：把 `monitor: Keep power save state consistent when output power setup fails`
> 推成 GNOME GitLab MR。补丁与提交信息已就绪，只差**能推的仓库**（见 §4）。

## 1. 结论（这次上游要说什么）

**phosh 自身的问题（本 MR 修）**：`zwlr_output_power_v1` 握手失败时，phosh 只打一行 warning，
`PhoshMonitor.power_mode` 停在初始 `PHOSH_MONITOR_POWER_SAVE_MODE_OFF`（语义 = 屏已关），
而 `PhoshScreenSaverManager` 的 `active = (mode == OFF)` ⇒ 会话一启动就认为屏已关、
`active` 恒 TRUE、`on_power_button_pressed()` 的 press/release 两支全短路：
电源键短按无反应、空闲不熄屏、`GetActive` 恒 true 且 `GetActiveTime` 恒 0；
而电源菜单「挂起」正常（走 logind，不查 `active`），所以极难自诊断。

**不是 phosh 的问题（另一条线，不在本 MR）**：为什么会握手失败 —— 我们这台机器上，
`droidloom-wayland` 先拿走了 DSI-1 的 power 对象，phosh 作为第二个请求者被 wlroots
`send_failed` 且**服务端资源被销毁**（wlroots 是「每 output 一个 power 对象」语义）。
我们本地给内嵌 wlroots 打了「允许第二请求者」的补丁后，真正关屏能力恢复。
本 MR 只保证在这种情形下 phosh 的状态机不崩。

## 2. 复现与证据（可复现，命令都在）

环境：联想 Y700 四代（SM8750P，主线 Linux 7.3.1），Debian sid + Phosh 0.58/0.59rc1 + phoc 0.59rc1，
面板 DSI-1，会话由 greetd 起（`Class=greeter`，与 bug 无关，已单独证否）。
触发条件：**另一个客户端先持有该输出的 `zwlr_output_power_v1`**（本例 = `droidloom-wayland`，
任何绑定该全局的客户端都可以复现）。

| 判据 | 修复前 | 修复后 |
|---|---|---|
| `org.gnome.ScreenSaver.GetActive()` | 恒 `true`（`SetActive false` 无效） | `false` |
| `GetActiveTime()` | 恒 `0` | 正常递增 |
| 短按电源键 | 无任何反应（`journalctl` 只有 logind 的 `Power key pressed short.`） | 熄屏；再按亮屏回锁屏 |
| 空闲熄屏（`idle-delay=300`） | 永不发生 | 正常 |
| 电源菜单「挂起」 | 正常（对照项：走 logind） | 正常 |

关键日志（phoc 侧加临时日志后取得；说明「请求从未到达合成器」）：

```
polyw: get_output_power client=0x…52590 pid=926212 output=…(DSI-1)          # droidloom-wayland
polyw: send mode 1 for DSI-1 (enabled=1)
polyw: get_output_power client=0x…73400 pid=926242 output=…(DSI-1)          # phosh
polyw: DSI-1 already has an object …                                          # 旧代码：此处 send_failed + 销毁资源
```

修复前按电源键时，phosh 自己是有动作的：

```
phosh: Power button released, activating screensaver
phosh: Activating screen saver: 1, lock: 0, lock_delay: 0
phosh: Entering power save mode: 1      ← set_power_save_mode(OFF)
```

但 phoc 侧 **0 行** `Request to set output power mode`、`strace -e trace=ioctl` 45 s 内
**0 次 `DRM_IOCTL_MODE_ATOMIC`** ⇒ proxy 已死，请求消失。

## 3. 补丁

- 文件：`patches-userland/upstream/0001-monitor-keep-power-save-state-consistent.patch`（= 仓库内 `git format-patch` 产物）
- 分支/提交：`monitor-power-mode-unavailable`，`88a0e237`，`Signed-off-by: Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>`
- 改动：`src/monitor/monitor.{c,h}`，+35 行
  - 新增 `PhoshMonitor.output_power_unavailable`
  - `wlr_output_power_handle_failed()`：置位该标记，并把 `power_mode` 设为 `ON`（notify）
  - `phosh_monitor_set_power_save_mode()`：不可用时**只更新本地状态**，不再对死 proxy 发请求
  - 抽出 `phosh_monitor_set_power_mode()` helper（两处复用）
- 已在设备上实测（**同一补丁打在 0.58 基线**、另一种是上游 main 源树编译通过）：
  `GetActive=false`、短按熄屏/亮屏、空闲熄屏、挂起不受影响。

## 4. 投递结果（2026-11-14 晚已发出）

**MR !2005** — <https://gitlab.gnome.org/World/Phosh/phosh/-/merge_requests/2005>

- 状态 `opened`；source = fork `xuqianhui1001/phosh:monitor-power-mode-unavailable` @ `88a0e237`，
  target = `World/Phosh/phosh:main`，2026-11-14 20:2x 提交，CI pipeline 1146543/1146542 已触发。

建 MR 的两个细节（下次省时间）：

- **对上游项目** `POST /projects/16747/merge_requests` **会 403**（提交者不是上游成员）。
  正确做法 = 对 **fork 项目**建 MR 并带 `target_project_id`：
  `POST /projects/41528/merge_requests` + `{"target_project_id":16747,…}`。
- HTTP 必须 **`--noproxy '*'`**：走代理会被 Fastly 拦成 406（API/网页都一样，且按 URL 缓存，
  随机 query 参数也绕不过）。
- 凭据来源 = `secret-tool lookup protocol https user xuqianhui1001 host gitlab.gnome.org`
  （scope 含 `api`，到期 2027-06-01）；只在命令里传入，未落任何文件、未写记忆。

## 5. 上一轮 MR（!820）的评审结果与口径（以后照这个来）

phoc **!820 `input-method-relay: Fix NULL deref in keyboard grab destroy handler`**
**已于 2026-10-31 21:22 合并**（merge commit `1ef2711f`，进 0.59 线）。过程有代价：

- 维护者 guidog 原话：**"please continue without AI, this is too verbose. We're happy to help
  with the code but don't want to talk to AI"**；并要求「short sentence + `Fixes:` tag instead of a
  wall of text」「把旧的 data 取法也一并修掉」「能不能为它写个测试」。
- 他**自己重写了整个 MR**（v2：删掉 AI 样板话、补 `tests/` 用例、提交信息改成「what changed when」），
  然后 "All quiet, merging." 交 marge-bot 合并。

→ **本项目以后提 GNOME 上游的固定口径**：

1. 描述短、事实性：问题 → 症状 → 改法 → 测试环境，各 1–3 句；不写段落式样板话；
2. 末尾**一行**如实交代 AI 辅助（作者本人复核/实测）；
3. 能加测试就加（`tests/` + meson 一条）；
4. 同类旧写法顺手一并改掉，别只修一处；
5. 提交信息写清「改了什么、什么时候变的」，需要时带 `Fixes:`。

## 6. 原卡点记录（历史，已解决）


现状（2026-11-14 实测）：

- `git@gitlab.gnome.org` **SSH 通**，身份 = `xuqianhui1001`（`ssh -T` 返回欢迎语）。
- HTTP/API **走代理一律 406**（Fastly 按出口 IP 拦），**直连可用**：
  `curl --noproxy '*' https://gitlab.gnome.org/api/v4/projects?...` → 200；
  但未认证时 `projects/xuqianhui1001%2Fphosh` = 404 ⇒ **该账号下还没有 fork**。
- 创建 fork / 建 MR 需要 authenticated API 或网页。

两条可选路径（任选其一，我来执行）：

1. **给一个 GNOME GitLab PAT（scope: `api`）** →
   `curl --noproxy '*' -H 'PRIVATE-TOKEN: …' -X POST 'https://gitlab.gnome.org/api/v4/projects/42/fork'`
   （先查 `World/Phosh/phosh` 的 id），再 push 分支 + `curl … /merge_requests` 建 MR。
   ⚠️ 凭据按项目纪律**只经环境变量传入命令**，不写进任何文件/记忆/仓库。
2. **你在浏览器里先建 fork**（`https://gitlab.gnome.org/World/Phosh/phosh/-/forks/new`），
   之后我只需 `git push -o merge_request.create -o merge_request.target=main …` 一条命令即可，
   不需要任何 token。

推之前请确认：作者署名用 `Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>`（与 USTC 邮箱线一致），
MR 描述里如实写「实机为联想 Y700 四代 / Debian sid，报告与补丁由 AI 辅助整理、作者本人复核与实测」。
