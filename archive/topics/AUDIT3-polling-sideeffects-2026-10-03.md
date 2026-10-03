# 审核（第三遍）：前序 session 工具调用中「轮询 + 副作用」的审计（2026-10-03）

> 触发：用户 2026-10-03 晚质疑——「AI 习惯用轮询查设备状态，但脚本可能把重启/刷内核等有副作用的行为
> 放进轮询内部；不确定这是否干扰了判断。」本遍**只审查工具调用与脚本**，并顺带用镜像/串口日志核验版本归属。
> 方法：解析 `~/y700-elden/.pi/sessions/**/*.jsonl` 全部 49 个会话文件的 bash toolCall（脚本见本文件末），
> 对 `for/while/until … do … done` 循环体与 `fastboot boot/flash/reboot`、`reboot -f`、写 `misc` 交叉匹配；
> 再扫仓库全部 `*.sh/*.py`；最后逐镜像解出内核 payload 指纹核验「谁在跑」。

---

## 0. 一句话结论

1. **没有任何一次「副作用写在轮询循环体（`do…done`）内部」**——这个具体嫌疑可排除。
2. 但存在同源的真隐患：**「副作用（写 misc + `reboot -f` 或 `fastboot boot`）与轮询写在同一条 bash 命令里，
   且该命令被 harness 超时杀死（`Command aborted`）」**。共 10 条此类命令，**4 条被中断**。副作用到底发没发、
   有没有在 `fastboot boot` 传输中途被打断，**无法判定**。
3. 更严重、且独立于轮询的混淆被查出：**设备持久槽 `boot_b` 里烧的就是疑似有 bug 的 `vk40` 内核**
   （内核 payload 与 `out/boot-elden-vk40.img` **逐字节相同**），而 vk30–vk40 所有镜像共用同一个
   uname `7.2.0-debug-gba28ec16f01f-dirty`。因此**任何复位/回退都落回 vk40**，
   「复位次数/复位后行为」的版本归因天然被污染。

---

## 1. 审计①：副作用是否在轮询循环内部

对 49 个 session 文件统计：

| 指标 | 数量 |
|---|---|
| 含副作用的 bash 命令（fastboot boot/flash/reboot、`reboot -f`、写 misc、`bootonce-bootloader`） | 132 |
| 同时含「循环」与「副作用」的命令 | 69 |
| **副作用字面出现在 `do…done` 循环体内** | **0**（仅 4 条正则假阳性：grep 自身模式、`adb dd` 备份 uefivarstore/devinfo） |

仓库脚本同样为 0：`cycle.sh` 的 `wait_fastboot()/wait_linux()`、`scripts/serial-log.sh`、`scripts/dpms-watch.sh`、
`scripts/thermal-watch.sh`、`/tmp/cap-loop.sh` **全是纯读/纯探测**；`iterate.sh` 是「先 `cycle.sh --soft` 再
`cycle.sh <img>`」的线性两步（含重启+引导，但不在循环里）；`flash-b.sh --reboot` 是「先刷、后轮询 SSH」。
没有任何脚本把「刷/重启」放进自己的循环体。

**判定：用户担心的「轮询里反复重启/刷机」没有发生。**

---

## 2. 审计②：真正的隐患形态——「轮询 + 副作用」同处一条会被杀的命令

本次 vk 二分会话（`2026-10-03T12-31-04…`，与 `13-22-37…` 同源）里，AI 反复用这种模式：

```
[SSH/serial] 写 misc BCB + reboot -f        # 副作用①
for i in $(seq 1 40); do … fastboot devices … done   # 轮询
[ $OK = 1 ] && timeout 120 fastboot boot <img>       # 副作用②
```

harness 对单次 bash 有超时（这里 60–400 s），超时即 `Command aborted`（进程被杀）。结果：

| cmd# | 结构 | 结果 | 歧义 |
|---|---|---|---|
| #68 | reboot(V1) → 轮询 → boot **V2** | 成功（`fastboot ok ~48s`） | 无 |
| #77 | reboot(V2) → 轮询 → boot **vk40re** | **Command aborted** | reboot 是否发出？`fastboot boot` 是否执行？未知 |
| #80 | 纯轮询（无副作用） | **Command aborted** | 无副作用，仅丢样本 |
| #104 | reboot → 轮询 → boot **vk40re** | `Command exited 1`（首条 serial-run 失败） | reboot 是否真的发出？未知 |
| #113 | 轮询 → boot **vk34recon** | **Command aborted** | boot 是否执行？未知 |
| #127 | reboot → 轮询 → boot **v1-thermal** → 轮询 SSH → 测 dpms | **Command aborted** | 同 #77 |

- **不是「重复执行」**（没有循环重刷），而是**「执行点不可判定」**：被 SIGTERM 时可能停在轮询中
  （boot 没发），也可能停在 `fastboot boot` 传输中（半途中断）。
- 被中断后 AI 靠后续命令（#108/#114/#120/#121/#124）重新 `uname`/查状态把设备拉回，才没有更坏结果。
- 附带踩坑：`scripts/serial-run.sh` 的解析用 `sed -n '2p'` 会取到回显提示行而非输出（#69/#70/#77 都出现
  `~ # [6n... ` 而不是数值），使「副作用是否生效」的日志更难读。

**改进（已建议进协议）**：一条 bash 只做一件事；轮询命令内部自加 `timeout` 自限，绝不让 harness 来杀；
`reboot`/`fastboot boot` 各自单独一条命令。

---

## 3. 审计③（新发现，影响更大）：持久槽 boot_b 跑的是 vk40，且版本归因被 `-dirty` 抹平

### 3.1 镜像指纹

解出每个镜像的内核 payload（gzip 流）sha256 前 16：

| 镜像 | uname | kernel payload sha256 |
|---|---|---|
| `out/boot-elden-vk34.img` … `vk40.img` 全体 | `7.2.0-debug-gba28ec16f01f-dirty` | — |
| `out/boot-elden-vk40.img` / `vk40-ram.img` | `…gba28ec16f01f-dirty` | **d16ab35ce4a57afa** |
| **`bootslot-b/boot_b.img`（当前 b 槽）** | `…gba28ec16f01f-dirty` | **d16ab35ce4a57afa** |
| **`bootslot-b/boot_b_vk40-ram.img`（10-03 实烧）** | `…gba28ec16f01f-dirty` | **d16ab35ce4a57afa** |
| `out/boot-elden-vk40re.img`（commit 6ef87e6a8 重建） | `…g6ef87e6a8868` | f20830016d63b754 |
| `out/boot-elden-vk34recon.img` | `…ge72a036ed4be` | ecfa53db763c57fe |
| `out/boot-elden-v1-thermal.img` | `…gf681b616a3af` | a1d20c45dc520e4f |
| `out/boot-elden-v2-audio.img` | `…g951c5f1c2ca5` | 7e28d84ed0bd8ae4 |

⇒ **b 槽当前烧的就是 vk40 现场内核**（`d16ab35ce4a57afa`，与 `out/boot-elden-vk40.img` 同一 payload）。
⇒ `vk30…vk40` 全是同一 commit `ba28ec16f` 的 dirty 构建，uname 无法区分——正是此前 F1/F4。

### 3.2 串口捕获的启动普查（`logs/console-v1-1003-204530.log`，20:45:30–21:01）

| 次序 | 内核 | 该次存活 |
|---|---|---|
| 1 | `gf681b616a3af`（V1 热区） | 130 s（被 AI `reboot` 结束） |
| 2 | `gba28ec16f01f-dirty`（**=vk40**） | 28 s |
| 3 | `g951c5f1c2ca5`（V2 音频） | 324 s（末尾 `ucsi … PPM init failed` 后复位） |
| 4–7 | `gba28ec16f01f-dirty`（**=vk40**）×4 | 各 20.8 / 23.5 / 20.8 / 40.0 s |
| 8 | `ge72a036ed4be`（vk34recon） | 28.8 s（捕获结束时仍在跑） |

⇒ 16 分钟内启动 8 次，**其中 5 次是 vk40 dirty**；且 vk40 每次只活 20–40 s。
结合 3.1：**设备正常启动/回退的内核 = vk40**。所以：
- 被 RAM 引导的测试内核一旦复位，**下一跳必然是 vk40**；此后若继续观察「又复位了」，测的已经是 vk40 而非测试内核。
- 这正是 AUDIT2 记录的「静默硬复位间歇、单次无统计意义」的**结构性原因**之一，AUDIT2 当时未识别。

---

## 4. 对现有结论的裁决

| 结论 | 裁决 | 依据 |
|---|---|---|
| post-vk34 增量 = 5 文件（DTS 热 trip + 4 音频文件） | ✅ 可信 | 第一遍 DTB 逐字节比对 |
| `vk40re` 显示 on/off 后 `vblank timeout`=6、`PPM init`=1；`vk34recon`=0/0 | ✅ **版本归属可信** | per-version kmsg 文件按 uname 命名：`…g6ef87e6a8868.log` 1764 行含 6/1；`…ge72a036ed4be.log` 1502 行含 0/0 |
| 「vk40 会静默硬复位 / vk34recon 不会」 | ⚠️ **存疑** | 复位后回退到 vk40，无法区分「测试内核在跑时复位」与「已在 vk40 上复位」；且 3.2 显示 vk40 自身 20–40 s 级不稳定 |
| V1/V2 谁引发 vblank | ⛔ 未取到 | AUDIT2 已承认；#127 中断使 V1 无数据 |
| 「`vk40` 与 `vk40re` 是两个对照」 | ❌ 命名误导 | 两者源码均为 commit `6ef87e6a8`，仅重新打包（payload 不同来自构建差异），**同一内核** |

**未被污染的部分**：`vblank timeout` / `PPM init failed` 的**内核版本归属**（靠 uname 命名文件）。
**被污染的部分**：所有「复位次数/复位时序/复位后设备表现」的跨版本比较。

---

## 5. 干净协议（下一刀）

1. **先给持久 b 槽一个已知基线**：把 `vk34recon` 烧进 `boot_b`（资产已备好，host 侧、可回滚）：
   - `bootslot-b/boot_b-vk34recon.img`（96 MiB，已用 `bootslot-b/avb.key` 签名，sha256 前 16 `53e5857a581e77a3`）
   - 烧写前先 `fastboot fetch`/备份现 `boot_b`（或用 `bootslot-b/boot_b.img` = 现 vk40 原件）；
     写后 **读回校验**（`fastboot fetch boot_b` 或设备内 `dd|sha256sum`），不只看「传输完成」。
   - 目的：让**任何回退都落到已知基线**，而不是 vk40。
2. 只用 **SSH `root@192.168.7.1`** 读 `dmesg`（USB NCM 比 ttyACM 稳）；每次测前先 `uname -r` 确认在跑哪版。
3. **单变量、长时窗（≥10 min）、每版 ≥3 轮**；判据 = 同口径 dmesg 计数（vblank / PPM / crash）+ 复位次数。
4. **命令纪律**：一条 bash 只做一件事；`fastboot boot` 单独；轮询单独且内部 `timeout` 自限；
   **绝不把 reboot/boot 与长轮询塞进同一条命令**。这样即使被 harness 中断也不产生不可判定的副作用。
5. 跨复位取证优先**串口 console 捕获（不写持久根）**，报告里以 uname banner 切分每个 boot 段。

---

## 6. 本遍复现脚本

```bash
# ① 副作用是否在循环体内
python3 - <<'PY'
import json,glob,re
side=re.compile(r'fastboot\s+(boot|flash|reboot|set-active|erase|delete)|reboot\s+-f|bootonce-bootloader|dd\s+[^\n]*misc')
body=re.compile(r'\b(?:for|while|until)\b[^\n]*\bdo\b(.*?)\bdone\b', re.S)
hits=0; tot=0
for f in glob.glob('**/*.jsonl', recursive=True):
    for line in open(f, errors='ignore'):
        try: o=json.loads(line)
        except: continue
        if o.get('type')!='message' or o['message'].get('role')!='assistant': continue
        for b in o['message'].get('content') or []:
            if isinstance(b,dict) and b.get('type')=='toolCall' and b.get('name')=='bash':
                c=b['arguments'].get('command','')
                if side.search(c): tot+=1
                for m in body.finditer(c):
                    if side.search(m.group(1)): hits+=1
print('commands with side effect:',tot,'| inside do..done:',hits)
PY

# ② 内核 payload 指纹（谁在跑）
python3 - <<'PY'
import zlib,hashlib,glob,os
def kh(p):
    d=open(p,'rb').read(); out=zlib.decompressobj(16+zlib.MAX_WBITS).decompress(d[d.find(b'\x1f\x8b'):])
    return hashlib.sha256(out).hexdigest()[:16]
for f in ['bootslot-b/boot_b.img','out/boot-elden-vk40.img','out/boot-elden-vk34recon.img']:
    print(f, kh(f))
PY
```

（第一遍脚本输出的 4 条「循环体内」命中经逐条核对全为假阳性；命中原文见会话
`2026-10-03T12-31-04…` cmd#16 与 `2026-09-30T12-13-51…` cmd#32/#33。）
