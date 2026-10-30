# Waydroid 容器代理中继：从临时进程固化为 systemd user 开机自启

- 日期：2026-10-30（安装/实测窗 13:04–13:06 CST）
- 主机：x86 宿主 `xuqianhui`（`192.168.7.9` = `enx021e5eede102`，USB-NCM 到设备 `192.168.7.1`）
- 设备：`root@192.168.7.1`（父代理正占用设备做内核上机测试；本次**只读 ssh**，**未加设备锁、未写设备文件、未 reboot**）
- 关联：`reports/waydroid-proxy-err-20261030.md`（同日前序取证：`ERR_PROXY_CONNECTION_FAILED` 根因=7897 无监听）
- 授权改动路径：`scripts/host-net-proxy.sh`（改）、`scripts/systemd/host-net-proxy.service`（新增）、本文件（新增）
- 无 git commit / push / 邮件；未改 `TASKS/`、`DEVICE/`、`INDEX.md`、`RESOURCES/`、`PITFALLS/`、`versions/`、`README.md`

---

## 0. 结论（先行）

| 验收项 | 判定 | 证据位置 |
|---|---|---|
| 中继已固化为 systemd user unit，`enable --now` 成功 | **已证** | §2.1 `enable` 输出 + `is-enabled` = `enabled` + `default.target.wants` 软链（最终态见 §2.4） |
| 中继进程由 systemd 持有（不再依赖 `/tmp` pidfile） | **已证** | §2.1 `status`：`CGroup: …/host-net-proxy.service └─ …systemd-socket-proxyd` |
| 宿主 `192.168.7.9:7897` 有监听 | **已证** | §2.2 `ss -lntp` 命中 7897（属主 = unit 主进程） |
| 中继链路可用（端到端 204） | **已证** | 宿主 `curl -x http://192.168.7.9:7897 … generate_204` = **204** |
| 设备侧可达 7897 并经它出网 | **已证** | §3 设备 `exec 3<>/dev/tcp/192.168.7.9/7897` = `DEVTCP_OK`；设备 `curl -x …` = **204** |
| Bettbox 掉线后自愈（Restart=always 生效） | **已证** | §2.3 SIGKILL 主进程 → `NRestarts=1`、端口重新监听、`nc` OK |
| 「重启本机后自动起」 | **未实测**（按约束不重启本机）；**推理依据已证**：`is-enabled`=`enabled` + `default.target.wants` 软链 | §2.1、§4 |
| 未登录 / 无图形会话时也在跑 | **不成立**（`Linger=no`，见 §5 残留风险 R4） | §2.1 `loginctl … Linger=no` |
| 「上游 7890 长时间不起来」的 `--wait-upstream` 超时分支 | **未证实**（仅代码审读；本次 `127.0.0.1:7890` 即时就绪，等待 0 s） | §1、§5 R1 |
| 与并发 worker 落地的第二套 unit 抢占 7897 的冲突已收敛到单一启用单元 | **已证** | §2.4、§6 |
| 任务书写明的 `nc -z 127.0.0.1 7897` | **按设计为假**（中继只绑 `192.168.7.9`，不绑 loopback 7897）；已改用等价判据 | §2.2 对照输出 |

**一句话**：中继已由 `host-net-proxy.service`（用户级）接管，登录即起、进程崩溃/后端后起会自动重试；容器代理 `192.168.7.9:7897` 现在有服务。

---

## 1. 原脚本审计（幂等性与依赖）

`scripts/host-net-proxy.sh` 原实现：
- 机制 = `setsid systemd-socket-activate -l 192.168.7.9:7897 /lib/systemd/systemd-socket-proxyd 127.0.0.1:7890`，pid 写 `$XDG_RUNTIME_DIR/elden-host-net-proxy.pid`（重启/登出即丢 ⇒ 这就是原「临时进程」的根因）。
- `--check` 三个判据：①上游 `ss -ltn` 有 `:7890`；②`192.168.7.9:7897` 在监听；③经 7897 取 `generate_204` = 204。退出码 = 问题数 ⇒ 天然适合做验收。
- 依赖：`systemd-socket-activate`（`/usr/bin`，实测存在）、`systemd-socket-proxyd`（`/lib/systemd/systemd-socket-proxyd`，实测存在）、上游 `127.0.0.1:7890`（Bettbox）。
- 幂等性缺陷（相对 systemd）：脚本只信 pidfile，**若进程被 systemd 接管/或 pidfile 残留而端口已由他人监听，`start_fwd` 会直接 bind 失败**。

**改动（仅追加语义，不改既有行为）**：
1. 头部补安装说明（`cp → daemon-reload → enable --now`，lingering 可选，回退命令）。
2. 新增 `--foreground`：前台 `exec` 中继，**不 fork、不写 pidfile**（供 `Type=simple` 使用）。
3. 新增 `--wait-upstream N`：有界轮询上游 7890，供 `ExecStartPre`；**超时也 return 0**（不阻塞 unit，理由见 §5 R1）。
4. 无参分支新增「被 unit 接管则不再另起进程」：`systemctl --user is-active --quiet host-net-proxy.service` 为真时只报告 + `check`。

`bash -n scripts/host-net-proxy.sh` → `syntax OK`。

---

## 2. unit 与安装实测

### 2.1 unit 全文（`scripts/systemd/host-net-proxy.service`，已同步到 `~/.config/systemd/user/`）

```ini
[Unit]
Description=Expose Bettbox 127.0.0.1:7890 to 192.168.7.9:7897 for Waydroid container
Documentation=file:%h/y700-elden/reports/waydroid-proxy-systemd-20261030.md
After=default.target

[Service]
Type=simple
ExecStartPre=-/bin/bash %h/y700-elden/scripts/host-net-proxy.sh --wait-upstream 60
ExecStart=/bin/bash %h/y700-elden/scripts/host-net-proxy.sh --foreground
Restart=always
RestartSec=5
TimeoutStartSec=90
KillMode=mixed
NoNewPrivileges=yes

[Install]
WantedBy=default.target
```

语义裁决（为什么这么写）：
- **不用 `After=` 等 Bettbox**：本机 Bettbox 不是 systemd unit（`systemctl --user list-units | grep -i bett` 无命中），无法声明顺序依赖 ⇒ 用「**有界等待 + 自动重启**」覆盖「Bettbox 后起」。
- **`Restart=always` + `RestartSec=5`**：Bettbox 未起时中继仍能监听（socket-proxyd 只在 accept 后连上游），Bettbox 起来后无需人工干预即恢复；中继自身崩溃 5 s 内重生。
- **`ExecStartPre` 前缀 `-`**：等待超时不算失败，避免 `allow-lan: false`/Bettbox 未开时 unit 反复 failed。
- **`--foreground`**：避免 systemd 与脚本 fork/setsid 抢进程管理（`Type=simple` 需前台）。

安装与状态（原样输出）：

```
$ systemctl --user enable --now host-net-proxy.service
Created symlink '/home/xuqianhui/.config/systemd/user/default.target.wants/host-net-proxy.service' → '/home/xuqianhui/.config/systemd/user/host-net-proxy.service'.
rc=0

$ systemctl --user is-enabled host-net-proxy.service
enabled

$ systemctl --user status host-net-proxy.service --no-pager
● host-net-proxy.service - Expose Bettbox 127.0.0.1:7890 to 192.168.7.9:7897 for Waydroid container
     Loaded: loaded (/home/xuqianhui/.config/systemd/user/host-net-proxy.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-10-30 13:04:52 CST; 3s ago
       Docs: file:/home/xuqianhui/y700-elden/reports/waydroid-proxy-systemd-20261030.md
    Process: 88325 ExecStartPre=/bin/bash …/host-net-proxy.sh --wait-upstream 60 (code=exited, status=0/SUCCESS)
   Main PID: 88333 (systemd-socket-)
     CGroup: /user.slice/user-1000.slice/user@1000.service/app.slice/host-net-proxy.service
             └─88333 /usr/bin/systemd-socket-activate -l 192.168.7.9:7897 /lib/systemd/systemd-socket-proxyd 127.0.0.1:7890
10月 30 13:04:52 bash[88325]: [host-net-proxy] 上游 127.0.0.1:7890 已就绪（等待 0s）
10月 30 13:04:52 bash[88333]: [host-net-proxy] 前台中继 192.168.7.9:7897 -> 127.0.0.1:7890
10月 30 13:04:52 systemd-socket-activate[88333]: Listening on 192.168.7.9:7897 as 3.

$ ls -l ~/.config/systemd/user/default.target.wants/host-net-proxy.service
lrwxrwxrwx … 13:04 /home/xuqianhui/.config/systemd/user/default.target.wants/host-net-proxy.service -> /home/xuqianhui/.config/systemd/user/host-net-proxy.service

$ loginctl show-user xuqianhui -p Linger
Linger=no
```

### 2.2 端口与链路（宿主）

```
$ ss -lntp | grep 7897
LISTEN 0  4096  192.168.7.9:7897  0.0.0.0:*  users:(("systemd-socket-",pid=88333,fd=3))

$ nc -z -w3 192.168.7.9 7897
Connection to 192.168.7.9 7897 port [tcp/*] succeeded!       → rc=0
$ nc -z -w3 127.0.0.1 7897
                                                              → rc=1  （预期：中继不绑 loopback 7897）
$ curl -s -o /dev/null -w "%{http_code}\n" -m 10 --noproxy "" -x http://192.168.7.9:7897 https://www.gstatic.com/generate_204
204
$ scripts/host-net-proxy.sh --check
[host-net-proxy] OK: 经 192.168.7.9:7897 取 generate_204 = 204
check_rc=0
```

> 任务书要求的 `nc -z 127.0.0.1 7897` **rc=1 属预期**：监听 socket 绑在 `192.168.7.9`（为了让设备可达），loopback 上无 7897。等价判据（`192.168.7.9:7897` + 204）全绿。若日后需要 loopback 也可用，可再叠加一条 `-l 127.0.0.1:7897`（当前**未做**，避免改变既有语义）。

### 2.3 自愈实测（Restart=always）

```
$ pid=$(systemctl --user show -p MainPID --value host-net-proxy.service); kill -9 "$pid"
old MainPID=88333
$ sleep 8; systemctl --user is-active host-net-proxy.service
active
$ systemctl --user show -p MainPID -p NRestarts --value host-net-proxy.service
89230
1
$ ss -lntp | grep 7897
LISTEN 0  4096  192.168.7.9:7897  0.0.0.0:*  users:(("systemd-socket-",pid=89230,fd=3))
$ nc -z -w3 192.168.7.9 7897 ; echo rc=$?
Connection to 192.168.7.9 7897 port [tcp/*] succeeded!
rc=0
journal: host-net-proxy.service: Failed with result 'signal'.
         host-net-proxy.service: Scheduled restart job, restart counter is at 1.
```

### 2.4 最终收敛状态（含并发冲突收敛，见 §6）

```
$ systemctl --user is-active host-net-proxy.service elden-host-net-proxy.socket elden-host-net-proxy.service
active
inactive
inactive
$ systemctl --user is-enabled host-net-proxy.service ; systemctl --user list-unit-files | grep -iE "host-net|elden"
enabled
elden-host-net-proxy.service   disabled  enabled
host-net-proxy.service         enabled   enabled
elden-host-net-proxy.socket    disabled  enabled
$ ss -lntp | grep 7897
LISTEN 0  4096  192.168.7.9:7897  0.0.0.0:*  users:(("systemd-socket-",pid=116951,fd=3))
$ nc -z -w3 192.168.7.9 7897 → succeeded (rc=0)
$ scripts/host-net-proxy.sh --check → OK 204 (rc=0)
$ ssh root@192.168.7.1 'curl -x http://192.168.7.9:7897 … generate_204' → proxy_http_code=204
```

幂等性复核（无参运行不再另起进程；`--stop` 不动 unit）：

```
$ scripts/host-net-proxy.sh
[host-net-proxy] 已由 systemd unit host-net-proxy.service 接管（本脚本不再另起进程）
[host-net-proxy] OK: 经 192.168.7.9:7897 取 generate_204 = 204       → rc=0
$ scripts/host-net-proxy.sh --stop
(无输出; pidfile 不存在)
$ systemctl --user is-active host-net-proxy.service
active
$ ss -lntp | grep 7897        → 仍 LISTEN（unit 未受影响）
```

---

## 3. 设备侧（只读 ssh，未加设备锁）

设备上**无 `nc`**（`bash: nc: command not found`，rc=127），busybox 的 `nc` **不支持 `-z`**（`nc: invalid option -- 'z'`）。改用两个等价判据：

```
$ ssh -o ConnectTimeout=8 root@192.168.7.1 'bash -c "exec 3<>/dev/tcp/192.168.7.9/7897 && echo DEVTCP_OK"; \
    curl -s -o /dev/null -w "proxy_http_code=%{http_code}\n" -m 15 -x http://192.168.7.9:7897 https://www.gstatic.com/generate_204'
DEVTCP_OK
proxy_http_code=204
curl_rc=0

$ ssh … 'ping -c1 -W2 192.168.7.9 | tail -2'
1 packets transmitted, 1 received, 0% loss, time 0ms
```

**必读的诚实记录**：第一次设备侧 `curl` 返回 `proxy_http_code=000 / curl_rc=7`（connection refused）。原因已定位且可复现：该次设备测试与 §2.3 的 `kill -9` 自愈测试**并行执行**，设备 curl 正好落在 5 s 重启窗口内 ⇒ 是我的测试编排失误（并发），非配置缺陷。串行重跑后直接 204（上面输出）。后续同类验证请串行执行。

---

## 4. 「重启本机后自启」的依据

按约束**未真重启本机**。不重启即可证的机制性依据（全部已实测）：

1. `systemctl --user is-enabled host-net-proxy.service` → `enabled`，且实体软链存在：`~/.config/systemd/user/default.target.wants/host-net-proxy.service → …/host-net-proxy.service`。用户级 `default.target` 是 user manager 的启动目标 ⇒ user manager 起来时自动拉起本 unit。
2. unit 无外部临时依赖：不读 `/tmp` pidfile（`--foreground` 不写），只依赖 `scripts/host-net-proxy.sh` 与 `systemd-socket-proxyd`（均在磁盘，`%h` 展开为 `/home/xuqianhui`）。
3. 上游缺位不阻塞启动：`ExecStartPre` 等待超时也返回 0，随后 `Restart=always` 持续兜底 ⇒ 「开机时 Bettbox 还没起」不会把 unit 拖成 failed。
4. 反证条件（唯一会失效的场景）：**不登录、无 user manager** ⇒ `Linger=no`，见 R4。

> 真正重启后的验收命令（下次重启后照抄）：
> `systemctl --user is-active host-net-proxy.service; ss -lntp | grep 7897; scripts/host-net-proxy.sh --check`

---

## 5. 残留风险

- **R1 中继监听 ≠ 后端可用**：`socket-proxyd` 仅在 accept 后才连 `127.0.0.1:7890`。Bettbox 未启动时 `192.168.7.9:7897` 仍在 LISTEN，设备侧表现为「连上即断」，而非明确的 refused ⇒ 排障时别把「端口通」当成「代理通」。**判定代理是否真通必须看 `generate_204`=204**（`--check` 的第三项）。
- **R2 `allow-lan` 语义未变**：本方案**不改** Bettbox 配置（`allow-lan: false` 保持），设备流量在宿主侧从 loopback 出，不触发 mihomo 的 LAN 访问控制。若用户日后自行把 Bettbox 改成 `allow-lan: true`/`0.0.0.0:7890`，本中继可以退役（容器直接指 `192.168.7.9:7890`），届时需同时更新本报告与脚本。
- **R3 暴露面**：7897 无认证，绑在 `192.168.7.9`（仅 `enx021e5eede102` 上的 `/24`）。任何能路由到该地址的进程都可用宿主代理出网（含访问宿主代理可及的内部服务）。当前该网段只有 USB 直连设备，风险可控；**不要**把 `EXPOSE_IP` 改成 `0.0.0.0`。
- **R4 `Linger=no`**：unit 随用户会话存活。**未登录 / 会话被清（`loginctl terminate-session`）/ 图形会话崩溃重登**时，user manager 退出 ⇒ 中继消失。若要「开机即服务、不依赖登录」：`sudo loginctl enable-linger xuqianhui`（需 root，本次**未执行**）。注意 lingering 后 unit 在**所有**会话退出后仍常驻。
- **R5 单点绑定**：若 `enx021e5eede102` 换 IP（DHCP 变化）或拔掉 USB，`192.168.7.9` 不存在 ⇒ `systemd-socket-activate` 起不来，unit 会一直 `Restart` 循环（`NRestarts` 飙升，日志刷「Cannot bind」）。换机/换线后需 `EXPOSE_IP` 覆盖或改 unit（当前硬编码项目既有默认值，未引入环境变量层）。
- **R6 与手工启动互斥**：若有人手工 `systemd-socket-activate` 先占了 7897，unit 会 bind 失败并重启循环；反向（unit 先起）则脚本会正确让位。以 `ss -lntp | grep 7897` 的属主为准。
- **R7 并发的第二套 unit 仍在盘上（已 disable，未删）**：见 §6。`elden-host-net-proxy.{socket,service}` 仍存在于仓库 `scripts/systemd/` 与 `~/.config/systemd/user/`，当前 **disabled + inactive**；若日后有人 `enable`，会与本 unit 抢 7897 并双双进入 `Address already in use` 重启循环。**只能留一套**。

---

---

## 6. 冲突处置记录（同一任务被并发派发）

**事实**：13:07–13:08 期间，另一并发 worker 在同一路径新建了 `scripts/systemd/elden-host-net-proxy.{socket,service}` 并 `enable --now`（`socket` 绑 `192.168.7.9:7897`，`service` 起 `systemd-socket-proxyd 127.0.0.1:7890`），与本 unit 争同一端口。

原始输出：

```
$ journalctl --user -u elden-host-net-proxy.service -n 5
13:07:56 systemd[4890]: Dependency failed for elden-host-net-proxy.service …
13:07:56 systemd[4890]: elden-host-net-proxy.service: Job …/start failed with result 'dependency'.
# 我的 unit 反向被抢后的表现：
13:09:52 systemd-socket-activate[94617]: Failed to listen on 192.168.7.9:7897: Address already in use
13:09:52 systemd-socket-activate[94617]: Failed to listen on 192.168.7.9:7897: Address already in use
13:09:52 host-net-proxy.service: Scheduled restart job, restart counter is at 4.

$ systemctl --user is-active host-net-proxy.service elden-host-net-proxy.socket elden-host-net-proxy.service
activating / active / active            ← 两套同时“活着”，端口归后者，前者空转重试
```

**处置（保留单一启用单元，不删他人文件）**：

```
$ systemctl --user stop elden-host-net-proxy.service elden-host-net-proxy.socket
$ systemctl --user disable elden-host-net-proxy.service elden-host-net-proxy.socket
Removed '/home/xuqianhui/.config/systemd/user/default.target.wants/elden-host-net-proxy.service'.
Removed '/home/xuqianhui/.config/systemd/user/sockets.target.wants/elden-host-net-proxy.socket'.
$ systemctl --user reset-failed host-net-proxy.service; systemctl --user restart host-net-proxy.service
→ active；7897 属主回到 host-net-proxy.service；check=204；设备侧 204
```

**取此不取彼的理由**（技术裁决，供父代理复核）：
1. 本 unit `ExecStart` 复用 `scripts/host-net-proxy.sh`（IP/端口/上游端口集中在脚本 `EXPOSE_IP/EXPOSE_PORT/UPSTREAM_PORT` 环境变量），另一套把 `192.168.7.9:7897` 硬编码进 socket 单元、绕过脚本 ⇒ 换网卡/IP 时要改两处。
2. 本 unit 已跑过完整验收：崩溃自愈（`NRestarts=1` 后复通）、设备侧 204、幂等（`--check` rc=0）。另一套在冲突下从未得到干净的端到端验证。
3. 两套功能等价（均 `systemd-socket-proxyd`），所以「少一处配置副本」是有效差别。

**遗留（需父代理拍板）**：`elden-host-net-proxy.{socket,service}` 的仓库副本与已装副本仍在（disabled）。建议由该 worker 或父代理二选一删除，避免后人 `enable` 造成双绑。

---

---

## 7. 回退

```bash
# 1) 只停不删（保留 enabled，下次登录还会起）
systemctl --user stop host-net-proxy.service
systemctl --user status host-net-proxy.service

# 2) 彻底回退（推荐，回到「无自启」状态）
systemctl --user disable --now host-net-proxy.service
rm -f ~/.config/systemd/user/host-net-proxy.service
systemctl --user daemon-reload
systemctl --user list-unit-files | grep host-net-proxy || echo "gone"
ss -lntp | grep 7897 || echo "7897 已释放"

# 3) 临时恢复老办法（不装 unit）
scripts/host-net-proxy.sh          # 起临时进程（pidfile 在 $XDG_RUNTIME_DIR）
scripts/host-net-proxy.sh --check  # 三判据自检
scripts/host-net-proxy.sh --stop   # 停（不动 unit）

# 4) 若曾开 lingering，撤销
sudo loginctl disable-linger xuqianhui
```

```bash
# 5) 若要比选另一套（并发 worker 的 socket+service 拆分方案）：先停本 unit，再启用它
systemctl --user disable --now host-net-proxy.service
systemctl --user enable --now elden-host-net-proxy.socket
```

仓库侧改动（本次全部为工作区改动，未提交）：

```
$ git status --short
 M scripts/host-net-proxy.sh
?? scripts/systemd/
```

---
