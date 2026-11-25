# 「Firefox 刚刚崩溃」取证：**不是 Firefox 的 bug，是合成器/会话先死了**（2026-11-25）

> 用户 2026-11-24 23:2x 报「firefox 刚刚的崩溃」。本轮用 minidump 的崩溃注解读出真因，
> 并顺着 `journalctl -b -1` 找到会话消失的时刻。
> 设备：TB322FC U2 · vk189 · Debian trixie · phosh/phoc 0.46 · Firefox 160.0.1。

## 0. 一页结论

| 项 | 结论 |
|---|---|
| Firefox 崩溃原因 | `MozCrashReason = () Error reading events from display: 断开的管道 Proxy: WP:E WP:RT …` ⇒ **Wayland 连接被对端关闭（EPIPE）**，Firefox 主动 abort。**不是** segfault / OOM（内核 dmesg 无 oops，`oom`/`segfault` 计数 = 0） |
| 谁先死 | 会话在 **23:27:00** 整体消失：`greetd[69782]: session closed` → `greetd: check_children: greeter exited without creating a session` → systemd 重拉 greetd（restart counter=1）→ 新 phoc/phosh（79909/79980） |
| 为什么会话消失 | 强相关证据 = 23:2x 我在同一会话里**反复 `pkill -x phosh-osk-stub`**（换件测试）；`phosh.session` 的 `RequiredComponents` 含 `sm.puri.OSK0`，gnome-session 把它当必需组件，连续死亡会放弃并结束会话（同轮另一次已实测过 "Oh no! Something has gone wrong."，需 `systemctl restart greetd` 才能恢复）。⚠ 本轮未能拿到 gnome-session 逐条「component X crashed / giving up」日志（该进程随会话一起消失），按时间线判**高置信、非定论** |
| 与 OSK 无关的部分 | 崩溃时 `GraphicsNumRenderers=0`、`GpuSandboxLevel=0`、`AdapterDriverVendor=mesa/msm`、`AdapterDriverVersion=26.1.6.0` ⇒ 当时没有 GPU 渲染器活着，不指向 GPU/Mesa 崩 |
| 结论定性 | **环境性崩溃（我方操作副作用）**，Firefox 本身未复现任何自身缺陷；用户可见感受「Firefox 崩了」是现象层 |

## 1. 证据（可复跑）

```sh
U=xuqianhui1001
CR=/home/$U/.config/mozilla/firefox/Crash\ Reports
ls -lt "$CR/pending"                     # 4bf17d15-….dmp + .extra（1160 KB / 16 KB）
python3 - "$CR/pending/4bf17d15-….extra" <<'PY'   # 单行 JSON，取崩溃注解
import json,sys; d=json.load(open(sys.argv[1]))
for k in ('ProcessType','MozCrashReason','CrashTime','UptimeTS','AdapterDriverVendor','AdapterDriverVersion','GraphicsNumRenderers','IsWayland','Version'):
    print(k,'=',d.get(k))
PY
journalctl -b -1 --since "2026-11-24 23:20" --until "2026-11-24 23:28" | grep -iE 'greetd|gnome-session|osk|Oh no'
```

实测输出要点：
- `ProcessType=main`、`MozCrashReason=() Error reading events from display: 断开的管道 Proxy: WP:E WP:RT WP:CA WP:CR WP:CPCA WP:CPCF`
- `CrashTime=1795534023`（= 2026-11-24 23:27:03 CST）、`UptimeTS=3717.9`
- `23:27:00 greetd[69782]: pam_unix(greetd-greeter:session): session closed` →
  `23:27:00 greetd[69767]: error: check_children: greeter exited without creating a session` →
  `23:27:01 systemd: greetd.service: Scheduled restart job, restart counter is at 1`
- 23:27:03 还有一次 `firefox --backgroundtask crashrep`（崩后上报任务；UI 起不来因为 `crashreporter` app-id 没装）

## 2. 为什么「断电」和这次崩溃不是一回事

- 上一 boot 的结束是**干净关机**：`systemd[1004]: Reached target shutdown.target` → `systemd-exit.service`（23:33:21），
  **不是**掉电；用户说的「断电」大概是那之后（23:33 之后设备停到今天 08:56 才起来）。
- 崩溃发生在 23:27，**早于**关机 6 分钟，两者独立。

## 3. 处置 / 纪律（已写进 `PITFALLS #716` 与 `ime-single-stack.sh`）

1. **同一会话里 `pkill -x phosh-osk-stub` ≤ 1 次**（换件就一次 + 立刻手动拉起）；要多次迭代就
   `systemctl restart greetd`（代价：会话重来），别把 gnome-session 的重启预算打光。
2. 换 osk-stub 件的正确节奏：`install` 新件 → `pkill` 一次 → 立刻 `setsid nohup /usr/bin/phosh-osk-stub &`
   （phosh 会用这颗新件；D-Bus 名被我们占住，phosh 不会再起第二份）。
3. 观察「是不是会话死了」看 `journalctl --list-boots` + `greetd` 的 `session closed`；Firefox 侧只看
   `.extra` 的 `MozCrashReason`，别凭「Firefox 崩了」就开始查 Firefox。

## 4. 未做（留给下次真复现）

- 若要证明 gnome-session 的放弃机制，可在测试机上加 `gnome-session --debug` 或给 `phosh.session`
  的 `RequiredComponents` 临时去掉 `sm.puri.OSK0` 做 A/B（会影响 OSK 自动拉起，需在非日用轮做）。
- Firefox 自身渲染路径（Mesa 26 + a830）的健康度另算：本条崩溃证据里 GPU 渲染器为 0，未覆盖 GPU 崩溃场景。
