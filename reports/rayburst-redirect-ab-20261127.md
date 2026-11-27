# rayburst / aria2-next「GitHub release 302→Azure SAS 空等 0 字节」三档 A/B（D20，2026-11-27）

承接 `reports/rayburst-redirect-hang-20261126.md`（只读取证）与 `reports/rayburst-ab-20261127.md`（64 MB 资产、未达 ≥100 MB 门槛）。
本轮**纯主机侧**：不碰设备、不 git commit、**未改任何持久配置**（仅 RPC 运行时全局项做了一次可逆试改，已回滚）。所有下载落在 `/tmp/d20r/`，结束已删。

## 0. 一页结论

| 判据 | 结果 |
|---|---|
| 测试资产 | `AppFlowy-0.15.1-linux-x86_64.deb` = **150,423,076 B（143.5 MiB，≥100 MB 达标）**，`github.com` 302 → `release-assets.githubusercontent.com`（Azure Blob SAS，`se=2026-11-27T06:39:06Z`） |
| ① 默认档（split=20 / max-conn=20） | **通** · 10.0 s、11.0 s（2/2）· sha256 一致 · `errorMessage=''` |
| ② 单连接档（split=1 / max-conn=1，RPC 覆盖） | **通** · 11.0 s、10.0 s（2/2）· sha256 一致 · `errorMessage=''` |
| ③ 单连接 curl 对照 | **通** · 9.38 s · sha256 与 ①②**逐字节相同**，且 = GitHub API `digest` |
| 「降连接数即通」这个假设 | **否证**。20 连接与 1 连接都 4/4 成功，150 MB 全量、sha256 全对，**连接数不是根因** |
| 真正能复现「空等 0 字节」的机制 | **HTTP 403（SAS 失效） + `max-tries=0`（无限重试）**：`status=active`、`completedLength=0`、`totalLength=0`、`connections=0`、**`errorMessage` 恒为 `''`（RPC 层面完全看不到错）**，日志每 10 s 一条 `connection failed (HTTP 403), attempt N`，永不收敛 ⇒ 与用户「0 字节空等」症状完全一致 |
| 落地修法 | 把 `maxTries` 从 0 改成有限值（建议 `5`，`retryWait=10`）：同一条 403 URL 在 `max-tries=2` 下 **5–10 s 内转 `status=error`, `errorCode=22`, `errorMessage='HTTP 403'`**，GUI 立刻看得见并可重开任务（重开即重新走 302 拿新 SAS）。**不要**改 split / max-connection-per-server |

一句话：**不是「连接太多打死 SAS」，是「SAS 一过期引擎无限重试且 RPC 装作正常」**；修的是重试上限与可观测性，不是并发度。

## 1. 环境（现查）

- `aria2-next version 3.1.0`（pid 1257492），`--conf-path=…/dev.aninsomniacy.rayburst/engine/aria2.conf`；RPC `127.0.0.1:29100`（仅 loopback + `[::1]`）。
- 关键现行值：`all-proxy=http://127.0.0.1:7890`、`split=20`、`max-connection-per-server=20`、**`max-tries=0`**、`retry-wait=10`、`timeout=10`、`connect-timeout=10`、UA=Chrome/147、`file-allocation=trunc`。
- 出口：`127.0.0.1:7890` 在听（代理内核；进程属主当前不可见，非本轮结论依赖项）。测试时段内 curl 8 MiB Range：代理 206 / 9.4 MB/s，直连 206 / 7.9 MB/s ⇒ **网络面健康**。
- SAS 时效：302 目标 `se=…T06:39:06Z`，本机时刻 13:59 CST(=05:59 UTC) ⇒ 每次 `addUri` 都重新走 302，三档用的都是新 SAS，无过期干扰。

## 2. 三档实测原始数据

文件 `/tmp/d20r/{A,A2,B,B2,C}/`；`stat -c%s` + `sha256sum` + `cmp` 全部现算。

| 档 | run | gid | 连接数（峰值） | 完成字节 | 耗时 | 磁盘 sha256 | vs 对照 |
|---|---|---|---|---|---|---|---|
| ① 默认 | 1 | f1ba3def7f65f5fa | 19 | 150,423,076 | **10.01 s** | `3580a660…f4f10d07` | `cmp` 相同 |
| ① 默认 | 2 | — | 19 | 150,423,076 | **11.01 s** | 同上 | 相同 |
| ② split=1/max-conn=1 | 1 | 1442337f528220db | 1 | 150,423,076 | **11.01 s** | 同上 | `cmp` 相同 |
| ② split=1/max-conn=1 | 2 | — | 1 | 150,423,076 | **10.01 s** | 同上 | 相同 |
| ③ curl 单连接（`-L`，经 7890） | 1 | — | 1 | 150,423,076 | **9.38 s**（ttfb 0.47 s，16.0 MB/s） | 同上 | 基准 |
| — GitHub API 独立对照 | — | — | — | 150,423,076 | — | `sha256:3580a660…f4f10d07` | 全部一致 |

**三档 `tellStatus.errorMessage` 均为 `''`（空），`errorCode` 均无；无 0 字节空等，无 stall。**

### 2.1 ① 默认档（节选，1 s 采样）

```
gid f1ba3def7f65f5fa opts {'dir': '/tmp/d20r/A'}
t=  0.0s status=active   conn=  0 compl=         0/ 150423076 spd=                 0 err=''
t=  2.0s status=active   conn= 19 compl=  29711974/ 150423076 spd=          14803051 err=''
t=  6.0s status=active   conn= 17 compl= 103640780/ 150423076 spd=          21062678 err=''
t=  9.0s status=active   conn=  8 compl= 143709156/ 150423076 spd=          14006956 err=''
t= 10.0s status=complete conn=  0 compl= 150423076/ 150423076 spd=                 0 err=''
DURATION 10.01s FINAL status=complete compl=150423076 total=150423076 err=''
ON_DISK size=150423076 sha256=3580a660bcb0dbe562b5af0feeb51c7b6b30aed212d31c716ddcf3d6f4f10d07
```

### 2.2 ② 单连接档（`split=1`, `max-connection-per-server=1` 作为 per-download 选项）

```
gid 1442337f528220db opts {'split': '1', 'max-connection-per-server': '1', 'dir': '/tmp/d20r/B'}
t=  1.0s status=active   conn=  1 compl=  12415040/ 150423076 spd=          12408547 err=''
t=  6.0s status=active   conn=  1 compl=  77232430/ 150423076 spd=          11502273 err=''
t= 10.0s status=active   conn=  1 compl= 142061111/ 150423076 spd=          15282403 err=''
t= 11.0s status=complete conn=  0 compl= 150423076/ 150423076 spd=                 0 err=''
DURATION 11.01s FINAL status=complete compl=150423076 total=150423076 err=''
ON_DISK size=150423076 sha256=3580a660bcb0dbe562b5af0feeb51c7b6b30aed212d31c716ddcf3d6f4f10d07
```

（② 第二跑 10.01 s 同结果；`max-conn=1` 只是把 12–16 MB/s 摊到一条连接，没有 hang、没有 403。）

### 2.3 ③ curl 单连接对照

```
CURL code=200 redirects=1 bytes=150423076 speed_Bps=16043035 time=9.376223 ttfb=0.465376
real 0m9.383s
3580a660bcb0dbe562b5af0feeb51c7b6b30aed212d31c716ddcf3d6f4f10d07  prop.deb
```

### 2.4 引擎日志（成功三档）

```
13:59:27 [notice] Download complete: /tmp/d20r/A/AppFlowy-0.15.1-linux-x86_64.deb
13:59:50 [notice] Download complete: /tmp/d20r/B/AppFlowy-0.15.1-linux-x86_64.deb
14:00:37 [notice] Download complete: /tmp/d20r/A2/AppFlowy-0.15.1-linux-x86_64.deb
14:00:58 [notice] Download complete: /tmp/d20r/B2/AppFlowy-0.15.1-linux-x86_64.deb
```

## 3. 「空等 0 字节」机制的定向复现（本轮新增，直击症状）

三档都通，说明用户那次 0 字节空等不是并发度问题。于是按「SAS 失效」假设做**零字节**定向实验：把 302 目标的 blob 容器名改成不存在的，得到稳定 403 URL（`curl -sI` = 403），再投给同一个引擎。

### 3.1 现行配置（`max-tries=0` ⇒ 无限重试）

```
t=  0.0 status=active compl=0 total=0 conn=0 errCode=None err=''
t= 20.0 status=active compl=0 total=0 conn=0 errCode=None err=''
t= 40.0 status=active compl=0 total=0 conn=0 errCode=None err=''
日志：
14:02:35 [info] …: connection failed (HTTP 403), attempt 1, retry in 10000 ms
14:02:45 [info] …: connection failed (HTTP 403), attempt 2, retry in 10000 ms
14:02:56 [info] …: connection failed (HTTP 403), attempt 3, retry in 10000 ms
14:03:06 [info] …: connection failed (HTTP 403), attempt 4, retry in 10000 ms
14:03:17 [info] …: connection failed (HTTP 403), attempt 5, retry in 10000 ms
```

⇒ **这就是用户看到的现象**：`status` 一直 `active`、0 字节、0 连接、`errorMessage` 空、`totalLength=0`（连 Content-Length 都没拿到），GUI 只能显示"卡住/无效"，**错误只在日志里**。

### 3.2 反向验证（有限重试 ⇒ 立刻可诊断）

per-download 选项 `max-tries=2, retry-wait=5`：

```
t=  0.0 status=active compl=0 total=0 conn=0 errCode=None err=''
t=  5.0 status=active compl=0 total=0 conn=0 errCode=None err=''
t= 10.0 status=error  compl=0 total=0 conn=0 errCode=22 err='HTTP 403'
日志：… attempt 2, retry in 5000 ms / [notice] Download … failed: HTTP 403
```

运行时全局项路径同样验证（`aria2.changeGlobalOption {max-tries:2, retry-wait:5}` → 5 s 内 `error/22/HTTP 403`），随后**已回滚**为 `max-tries=0, retry-wait=10`（`getGlobalOption` 回读确认，见 §5）。

## 4. 落地建议（配置路径 / 键值 / 影响面 / 回退）

### 4.1 修法（推荐，唯一必要改动）

GUI 层是真相源（`engine/aria2.conf` 首行写着 `Generated by Rayburst. Do not edit. / Rebuilt before every Aria2 Next start.`，**直接改 conf 会在下次启动被覆盖**）：

- 文件：`~/.local/share/dev.aninsomniacy.rayburst/config.json` → `preferences.maxTries`（当前 `0`）
- 同步生成物：`…/system.json` 的 `"max-tries"`、`…/engine/aria2.conf` 的 `max-tries`（改 config.json 后由 rayburst 重写，无需手改）
- 建议值：**`maxTries: 5`**（配 `retryWait: 10` 不变）⇒ 最坏 ~50 s 内必出终态错误，而不是无限空等。若偏好更快失败可设 `3`。
- 首选做法：rayburst GUI 设置里的「最大重试次数/重试」项直接改为 5（等价于上述 JSON 键；改完重启 rayburst 让引擎按新 conf 起）。

**不改的键（本轮有反证）**：`split` / `max-connection-per-server` 保持 20——单连接与 20 连接均 4/4 成功、sha256 全对，降并发只会把 150 MB 从 10 s 拖到 11 s 并牺牲其他源的速度，**不解决 SAS 过期**。

### 4.2 影响面

- 有限重试影响**所有**协议任务（HTTP/BT/ED2K 的 HTTP 段），语义变化仅是"永久重试"→"重试 N 次后报错"。BT 走 peer 重连逻辑，不受 `max-tries` 直接约束，风险低。
- 对 SAS 类直链是净收益：失败可见 ⇒ 用户重开任务 ⇒ 重新走 302 拿**新** SAS（不能复用旧 URL 重试，这是原有铁律）。
- 不涉及代理/出口/UA/头，不需要动 `all-proxy`。

### 4.3 回退（二选一，均即时）

```bash
# A. GUI 里把「最大重试次数」改回 0；或
# B. 直接改 JSON 后重启 rayburst：
sed -i 's/"maxTries": 5/"maxTries": 0/' ~/.local/share/dev.aninsomniacy.rayburst/config.json
# 运行时不重启的临时回退（引擎重启后失效）：
python3 - <<'PY'
import json,urllib.request
S=[l.split('=',1)[1].strip() for l in open('/home/xuqianhui/.local/share/dev.aninsomniacy.rayburst/engine/aria2.conf') if l.startswith('rpc-secret=')][0]
b=json.dumps({"jsonrpc":"2.0","id":"r","method":"aria2.changeGlobalOption","params":["token:"+S,{"max-tries":"0","retry-wait":"10"}]}).encode()
print(urllib.request.urlopen(urllib.request.Request("http://127.0.0.1:29100/jsonrpc",data=b,headers={"Content-Type":"application/json"})).read().decode())
PY
```

### 4.4 本轮对配置的实际影响：**净零**（如实标注）

- 唯一一次改动是 §3.2 的 `changeGlobalOption {max-tries:2, retry-wait:5}`，**已回滚**；`aria2.getGlobalOption` 现回读 `max-tries=0, retry-wait=10`。
- 回滚触发了 rayburst 的配置持久化：`config.json` / `system.json` mtime 变为 14:03:5x，但内容核对为原值（`maxTries=0`、`retryWait=10`、`split=20`、`max-connection-per-server=20`、`proxy.server=http://127.0.0.1:7890` 均未变；JSON 合法，144 个 preferences 键）。`engine/aria2.conf` mtime 仍 09:09:05（未重写），其中 `max-tries=0`。
- 因未改持久配置，无需 `/tmp` 备份；若要按 §4.1 落地，先备份：
  `cp ~/.local/share/dev.aninsomniacy.rayburst/config.json /tmp/rayburst-config.json.bak.$(date +%s)`
  还原：`cp /tmp/rayburst-config.json.bak.<ts> ~/.local/share/dev.aninsomniacy.rayburst/config.json && pkill -f 'rayburst --autostart'`（下次自启按原配置起）。

## 5. 复现命令

```bash
# 0) 判活（先确认网络面/302/SAS 时效）
U='https://github.com/AppFlowy-IO/AppFlowy/releases/download/0.15.1/AppFlowy-0.15.1-linux-x86_64.deb'
curl -sIL --max-time 25 -o /dev/null -w 'code=%{http_code} redirects=%{num_redirects}\n' "$U"
curl -sIL --max-time 25 -o /dev/null -w '%{url_effective}\n' "$U" | grep -o 'se=[^&]*'   # SAS 过期时刻

# ① 默认档 / ② 单连接档（RPC，见 /tmp/d20r 的 rpc.py + run.py；密钥运行时从 conf 读）
python3 /tmp/d20r/run.py A  /tmp/d20r/A 240 '{}'
python3 /tmp/d20r/run.py B  /tmp/d20r/B 330 '{"split":"1","max-connection-per-server":"1"}'

# ③ curl 单连接对照（经引擎同一出口）
curl -sS -L --proxy http://127.0.0.1:7890 -o /tmp/d20r/C/prop.deb \
  -w 'code=%{http_code} bytes=%{size_download} time=%{time_total}\n' "$U"

# ④ 三方 sha256 + 磁盘字节 + API 独立 digest
sha256sum /tmp/d20r/{A,B}/*.deb /tmp/d20r/C/prop.deb; stat -c '%s %n' /tmp/d20r/*/*.deb
gh api repos/AppFlowy-IO/AppFlowy/releases/tags/0.15.1 \
  --jq '.assets[]|select(.name=="AppFlowy-0.15.1-linux-x86_64.deb")|"\(.size) \(.digest)"'

# ⑤ 403 空等的定向复现（把 302 目标的容器名改成不存在 ⇒ 稳定 403）
python3 - <<'PY'   # 生成 403 URL 后交给 run.py / addUri（max-tries 缺省与 =2 各跑一次对比）
u=open('/tmp/d20r/sas.txt').read().strip().replace('github-production-release-asset','nonexistent-container-xyz')
open('/tmp/d20r/diag_url.txt','w').write(u)
PY
grep -a 'HTTP 403' ~/.local/share/dev.aninsomniacy.rayburst/logs/aria2-next.log | tail
```

## 6. 置信度与残留

| 结论 | 置信度 | 依据 |
|---|---|---|
| 该资产在该时刻 302→SAS 链路上，20 连接与 1 连接都能完整下完且 sha256 正确 | **高** | 4/4 全量 150 MB、`cmp` + GitHub API digest 三方一致 |
| 「降连接数即通」为假 | **高** | 默认档比单连接档还快，无一失败 |
| 用户「0 字节空等」= SAS 失效 + `max-tries=0` 无限静默重试 | **中高** | 用稳定 403 完整复现了症状（active/0 B/0 conn/`errorMessage` 空 + 日志 403 循环），但**仍未拿到用户当时那次的引擎日志/SAS URL**（现场已过） |
| SAS 过期是唯一触发源 | **中** | 另有两条已知等价触发：①`all-proxy` 失效/空导致的 0 连接挂死（见 `rayburst-ab-20261127.md` §三，本轮未复跑）；②代理侧 TLS `unexpected eof` 瞬时断链（有 `retry` 兜底，通常自愈）。三者症状相同，`max-tries` 有限化对三者都有益（都会转成可见错误） |

**残留风险**：`maxTries=5` 后，若某次长任务恰好在 SAS 1 h 时效上过期且已下 99%，重试耗尽会失败——但 aria2 会保留 `.aria2` 控制文件，重开即可续传（新 SAS），不丢已下载数据。（本轮未实测"边下边过期"的续传，属未证实项。）

## 7. 清理

- `/tmp/d20r/{A,A2,B,B2,C}/*.deb`（5×150 MB）已删；`/tmp/d20r/{rpc.py,run.py}`（复现用，<4 KB）保留。
- 全部 RPC 测试任务 `forceRemove` + `removeDownloadResult`；`getGlobalStat` = `numActive 0 / numWaiting 0 / numStopped 0`。
- 未改设备、未 git commit、未改持久配置。
