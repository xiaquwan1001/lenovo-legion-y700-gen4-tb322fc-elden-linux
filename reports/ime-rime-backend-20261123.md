# RIME 候选后端 + OSK 震动 + 方向键 —— lane H 收尾报告（2026-11-23）

> lane 类型：主机侧（交叉编译 + 上游源码只读核实）。**未接触设备**（零 ssh/fastboot）。
> 承接：`reports/ime-osk-zh-matrix-20261122.md`（下称 M，C4/C8/R1 结论不重推）、
> `reports/ime-osk-zero-to-usable-20261121.md`（下称 Z）。骨架于 `857047b3` 入库，本轮补齐三目录 + 报告。
> 上游源码基线：phosh-osk-stub **0.46.0**（= 设备现役 Debian 包版本，M §0.1），本机 `/tmp/osks/phosh-osk-stub-0.46.0`。
> 所有外部命令带 `timeout -k`；凡未在真机跑过的一律标 **需上机**。

---

## 0. 一页结论（做到哪一步 / 需上机判据数）

| # | 事项 | 做到哪一步 | 级别 | 需上机判据 |
|---|---|---|---|---|
| **1** | RIME 候选后端（A/B 两案 + 骨架） | **A/B 双案代码全写完，A 方案两件套对象级编译过（aarch64）+ 主机行为级验证过**（薄客户端无守护时输出恰一个空行、exit 0；守护 oneshot 路径主机可跑，缺 librime 运行库只差 `-lrime` 链接）。B 方案 `pos-completer-rime.c` 语法级过（`-fsyntax-only`，含 glib + osk-stub 全部头）。报告 §1 | 实测（编译/行为）+ 静态（与 OSK 协议对齐） | 5 条（§5 R1–R4） |
| **2** | 触屏打字震动 | **方案定稿 + 补丁文件 + 部署/回退命令 + 60 s 验证脚本**全齐；phosh-osk-stub 0.46 源码核实**无任何 haptic 钩子**（grep `haptic\|rumble\|vibrat\|EV_FF` = 0）；FF 链路（aw86927 ×2 + ffrumble）本仓已证实可用（M/PITFALLS:373，deploy §11） | 静态（源码 + 既有实测） | 3 条（haptic/README §3） |
| **3** | OSK 方向键 | **现状查明**（方向键驱动侧在、布局侧 0 命中；Home/End 连符号表都没有）+ **最小补丁**（terminal.json F 层加 ←↑↓→ + vk-driver 2 行 Home/End） | 静态（file:line 见 §3） | 2 条（§5 L1–L2） |

一句话：**三件事的"能主机侧做的"全部做完（编译/协议/补丁/脚本/部署配方），剩下的全部是"人手摸设备"型判据，每条都给了确切命令。**

---

## 1. RIME 方案对比与主推实现

### 1.1 两案对比

| | **A：独立 rime 守护 + pipe completer** | **B：patch 直连 librime** |
|---|---|---|
| 上游改动 | **零**（phosh-osk-stub 0.46 的 `pipe` completer 原生支持外部命令，M C4） | `pos-completer-manager.c`、`src/meson.build`、gschema、gresource 全要动 |
| 空格/数字选词 | ✗（pipe 协议里空格必然把原串提交：`pos-completer-pipe.c:341` 走 `pos_completer_add_preedit()` 的"分隔符⇒原样 commit"分支） | ✓（`pos-completer-rime.c:184-232` 空格=选首选、1..9=选第 N 个、退格=RIME 原生音节回退） |
| 每键成本 | spawn 薄客户端 + 1 次 unix RPC（C 客户端 ~2 ms 量级，见 §1.6） | 1 次 `process_key()`（最优） |
| 失败模式 | 守护死 ⇒ 静默无候选，**英文照打** | librime 初始化失败 ⇒ 整个 completer 起不来（有 `POS_COMPLETER_ERROR_ENGINE_INIT` 兜底） |
| 部署 | 拷 2 个二进制 + 1 个 user unit + 3 条 gsettings | 重编 phosh-osk-stub + divert+hold（PITFALLS #654），每次上游升级重打 |
| 回退 | 删 3 条 gsettings 即回原生 hunspell | 必须 dpkg-divert 反做 |

**主推：A 先行（本周可上机），B 作为 A 稳定后的体验升级。**
理由：M 的 R1 路线判据链（`completion-mode=always` → pipe → helper）已经打通到"只差 helper"，
A 完全复用该链；B 的独有收益（空格选词）在 A 里可以用"先上机确认 pipe 路径可用"之后再做，
且 B 的补丁面（4 个上游文件）与 M §5.1 ④ 的"选中追加空格"补丁同属一个重编批次，可合并做。

### 1.2 已有骨架逐文件说明（`rime/`，全部 `857047b3` 入库，本轮核验）

| 文件 | 内容 | 完成度 |
|---|---|---|
| `rime-ipc.h` (54) | A 案 IPC 协议：请求 `<preedit>\n`，响应按行候选 + **空行结束**；socket 路径 `$ELDEN_RIME_SOCK` → `$XDG_RUNTIME_DIR` → `/run/user/<uid>`。空行语义与上游空 stdout UB 对齐（`pos-completer-pipe.c:305-310` 在 stdout 空串时取 `stdout_buf[-1]`） | ✅ 完整，header-only |
| `librime-piped.c` (442) | A 案守护：单线程 poll + accept；**增量喂键**（追加只喂新字符 / 缩短发 BackSpace / 分叉全量重放，`feed_preedit()`）；`--oneshot`（判据/bench 用，0 候选 exit 3）；`--idle-exit`；librime ≥1.6 只走 `rime_get_api()` 函数表 | ✅ 完整 |
| `elden-rime-completer.c` (190) | A 案薄客户端（OSK 的 `Pipe.command` 指向它）：stdin 一行 → connect → 读候选 → stdout；**一切错误都输出一个空行 + exit 0**（不阻塞打字） | ✅ 完整 |
| `pos-completer-rime.{c,h}` (418) | B 案 completer：`PosCompleter` 接口全实现（feed_symbol/set_preedit/get_preedit + GObject property 五件套），librime session 生命周期、简体开关、GSettings `Completers.Rime.{shared-data,user-data,schema}` | ✅ 主链完整；**缺**：接线补丁本体（manager/meson/gschema 的 diff 未落文件，配方在其头注释里） |

### 1.3 编译验证（本轮实测）

依赖现状：`librime-dev` 未安装（`apt-cache policy`：候选 1.16.1+dfsg1-1build1，universe）。
**不硬装**（会拉 librime + marisa + opencc 全家桶），改为只拉上游头文件：
`verify/include/rime_api.h` = librime 1.16.1 tag 原版（594 行，BSD-3，curl 实拉）。

```sh
# ① aarch64 对象级（守护 + 薄客户端，只需 libc + rime_api.h）——实测通过，0 warning
aarch64-linux-gnu-gcc -static -O2 -Wall -Wextra -I verify/include -c rime/librime-piped.c -o verify/aarch64/librime-piped.o
aarch64-linux-gnu-gcc -static -O2 -Wall -Wextra -I rime -c rime/elden-rime-completer.c -o verify/aarch64/elden-rime-completer.o
# ② aarch64 完整链接（薄客户端不依赖 librime）——实测通过
aarch64-linux-gnu-gcc -static -O2 -Wall -Wextra -I rime rime/elden-rime-completer.c -o verify/aarch64/elden-rime-completer
#    → ELF 64-bit LSB executable, ARM aarch64, statically linked（产物在 verify/aarch64/）
# ③ B 案语法级（需 glib + osk-stub 内部头）——实测通过
gcc -fsyntax-only -Wall -I verify/include -I /tmp/osks/phosh-osk-stub-0.46.0/src \
    $(pkg-config --cflags glib-2.0 gio-2.0) rime/pos-completer-rime.c
# ④ 主机行为级：薄客户端"无守护静默退化"——实测通过
gcc -O2 -Wall -Wextra -I rime rime/elden-rime-completer.c -o /tmp/erc-host
echo nihao | /tmp/erc-host | xxd      →  0a（恰一个空行，exit 0，无零字节 UB）
/tmp/erc-host --selftest | xxd        →  0a
```

打包路线（aarch64，写清不装）：Debian 侧 `apt install librime1 librime-data`（运行库，
设备上装，非编译依赖）+ 拷 `verify/aarch64/{librime-piped,elden-rime-completer}` →
`/usr/local/bin/`。若要在设备/容器里重编 B 案，才需要 `librime-dev`（build-dep 一行）。

### 1.4 systemd user unit

`rime/elden-rime.service`：`WantedBy=default.target`（**不是** graphical-session.target——
本栈它不 active，Z §0.3 第 2 步已实测）+ `Restart=on-failure` + `--idle-exit 1800`。
不做 systemd socket-activation（守护自己 listen；客户端对守护缺席是静默退化，不阻塞输入）。

### 1.5 部署步骤（A 案全量）

```sh
scp verify/aarch64/librime-piped verify/aarch64/elden-rime-completer \
    rime/elden-rime.service  root@192.168.7.1:/usr/local/bin/…   # + unit 到 /etc/systemd/user/
# 设备（su 到桌面用户）：
apt install librime1 librime-data
gsettings set sm.puri.phosh.osk completion-mode "['hint','manual']"   # 勘误 2026-11-23：0.46 枚举仅 none/hint/manual，无 always（PITFALLS #709；原 ['always'] 照抄静默无效）；manual 的开关在 OSK 菜单 "Word completion"。详见 reports/ime-native-audit-20261123.md §4
gsettings set sm.puri.phosh.osk.Completers default "pipe"
gsettings set sm.puri.phosh.osk.Completers.Pipe command "/usr/local/bin/elden-rime-completer"
systemctl --user daemon-reload && systemctl --user enable --now elden-rime
```

### 1.6 判据（详细命令见 §5；热启动 <100 ms 的机理）

守护首次启动做一次词库编译（数秒），之后 session/词典驻留内存；薄客户端只有
connect+read+write+exit，不触碰 librime ⇒ 热路径 <100 ms 的余量极大，判据用
`date +%s%N` 差值实测（§5 R2）。

## 2. 触屏震动方案

**现状**：硬件链路完全可用（`aw86927-haptics` 两枚 FF 节点 event2/event3 + `ffrumble`，
2026-11-20 用户实测两侧震；`reports/best-state-and-gap-20261122.md:52`、
`scripts/deploy-desktop-shell.sh:392-406`）；但 **phosh-osk-stub 0.46 源码里没有 OSK 按键 →
FF 的任何通路**（`src/*.c` grep `haptic|rumble|vibrat|EV_FF` = 0 命中，本轮核实）。
按键不产生内核事件（virtual-keyboard 协议直达合成器），外部进程拿不到 per-key 信号
⇒ 必须在 OSK 内部挂点。

**最小方案**（`haptic/0001-osk-stub-keypress-haptic-hook.patch`，~12 行）：
唯一汇聚点 `on_osk_key_symbol()`（`pos-input-surface.c:380`）加 env-gated spawn：
`ELDEN_OSK_HAPTIC_DEV` 未设 ⇒ 与上游逐字节一致；设了 ⇒ 每键
`ffrumble $DEV ${ELDEN_OSK_HAPTIC_MS:-30} ${ELDEN_OSK_HAPTIC_MAG:-0x3333}`。
- 默认幅度 0x3333（≈20%，ffrumble 的 strong=weak 同幅，`scripts/ffrumble.c:83-84`）、30 ms：
  短于该值可能低于可感阈值（aw86927 CONT 模式下限经验值），长则拖打字节奏——**具体手感需上机标定**；
- 开关 = 环境变量（user drop-in `Environment=`，haptic/README §2），无需新 GSettings schema；
- 部署/回退：divert+hold（haptic/README §2/§4），`haptic/haptic-verify-60s.sh` 三判据。

## 3. 方向键现状与补丁

- **方向键**：驱动侧已支持——`KEY_LEFT/RIGHT/UP/DOWN` 在 `pos-vk-driver.c:54-57` 的
  `keycodes_common[]`；布局侧 **55 个 json 0 命中**（含 terminal.json），即"写进布局就能用但没人写"。
- **Home/End**：`pos-vk-driver.c:277,281` 的 case 列表里有（那是 electron 过滤），但
  `keycodes_common[]` **无符号条目** ⇒ 布局写了也不映射，需 2 行补丁。
- **切入方式**：terminal.json 的 level 2/3 是 `mode: locked`（连点 shift 锁定进入），无需新 UI 开关。
- 补丁：`layout/0002-osk-stub-terminal-arrows.patch`（terminal.json F 层第 4 行
  `< > 空格 , .` → `⇱ ← ↑ ↓ → ⇲ 空格 , .`；`<`/`>` 在数字层与 F 层第 2 行均有等价替代，不丢符号；
  vk-driver 补 `KEY_HOME`/`KEY_END` 两行查表）。按键对象结构与现役布局里
  `{"symbol":"KEY_TAB","label":"⭾","style":"sys"}` 完全同构，解析器无需改动。
- 布局 json 编进 gresource ⇒ 需重编，与 §2 的 haptic patch 同批 divert 部署。

## 4. 部署清单与回退（总表）

| 组件 | 部署 | 回退 |
|---|---|---|
| A 案 RIME | 2 二进制 + 1 unit + 3 gsettings + `apt install librime1 librime-data` | `gsettings reset` 三键（回 hunspell）+ `systemctl --user disable --now elden-rime` |
| B 案 RIME（后续） | 重编 osk-stub（4 文件 diff）+ divert+hold | divert 反做 |
| OSK 震动 | osk-stub 补丁同批 + drop-in env | 删 drop-in + divert 反做（env 没了 = 上游行为） |
| 方向键 | terminal.json + vk-driver 补丁同批 | divert 反做 |

共同纪律：phosh-osk-stub 是 Debian 包，任何重编件走 divert+hold（PITFALLS #654），
上游升级时先 `dpkg-divert --list` 盘点。

## 5. 需上机验证清单（每条：命令 / 看什么）

| # | 命令 | 看什么 |
|---|---|---|
| **R1 判据主链** | 设备上 `echo nihao \| /usr/local/bin/elden-rime-completer`（守护起着，§1.5） | ≥1 行候选且含「你好」（`verify/ime-zh-rime-verify.sh` 自动判） |
| **R2 热启动** | `verify/ime-zh-rime-verify.sh` 的 R2 段（两次 oneshot 取第 2 次 `date +%s%N` 差） | <100 ms；≥100 ⇒ user-data 缓存没命中（查 `$XDG_DATA_HOME/elden-rime`） |
| **R3 端到端** | 守护起着，OSK 里打 `nihao` | 键盘上方候选条出现汉字；`journalctl --user -u phosh-osk-stub \| grep 'Looking up'` 有 pipe 日志（M R1-5） |
| **R4 上屏** | 点第一个候选 | 输入框 = `你好`；空格提交不吞空格位 |
| **R5 守护缺席退化** | `systemctl --user stop elden-rime` 后打字 | 英文/手打照常、无候选条、无卡顿（客户端 400 ms 超时兜底） |
| **H1 震动基线** | `ffrumble /dev/input/event2 300 0xffff` | 人手可感（链路对照，应过——2026-11-20 已实测过） |
| **H2 每键触发** | OSK 打字时另一路 `timeout -k 3 8 getevent -c 3 /dev/input/event2` | 每键一组 FF SYN_REPORT |
| **H3 手感标定** | `ELDEN_OSK_HAPTIC_MAG` ∈ {0x2000, 0x3333, 0x6666} 三档 | 人选一档定默认 |
| **L1 方向键** | terminal 布局下连点 shift → F 层，点 ← | 光标左移一格（shell/文本框） |
| **L2 Home/End** | 同上点 ⇱/⇲ | 光标跳行首/行尾 |

## 6. 与背景报告的一致性核对

- M C4/C8/R1：本报告完全沿用（pipe 协议行号、gsettings 三键、`always` 前置条件），无改口径。
- Z §0.2 C 档「候选窗 classicui 画不出」：不冲突——本方案候选条画在 OSK 自己的
  `pos-completion-bar`（M C4），不经 fcitx5 classicui。
- M §5.1 ④「选中追加空格」：A 案**仍存在**该问题（pipe 协议客户端控制不了 OSK 的 commit 行为），
  已列入 B 案收益；A 案上机时按 M R1-6 观察即可。
