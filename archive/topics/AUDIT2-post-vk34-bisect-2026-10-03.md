# 审核（第二遍）：post-vk34 五个文件的逐 hunk 审计与二分实验（2026-10-03）

> 状态：**进行中（未收口）**。承接 `AUDIT-since-vk34-2026-10-03.md`（第一遍静态取证 + A/B 隔离准备）。
> 本文记录：① 第二遍逐 hunk 分类与实质问题；② 二分变体构建；③ 实机实验结果与**方法学坑**；④ 钩子副作用事件。
> 结论口径以六视角文档（`GAPS` Q21/Q22、`TASKS` G1-22/G1-23）为准；本文是过程证据。

---

## 0. 一句话结论

post-vk34 增量 = **DTS 分级热 trip + 4 个音频文件（含副作用型调试打印）**。
实机取得**可量化回归**：`vk40re` 在显示 on/off 提交后出现 `DPU vblank timeout`（计数 6）与 `UCSI PPM init failed`（1），
`vk34recon` 同操作 **0 / 0**。但**整机静默硬复位是间歇性的**（~1 min/次 与 稳定 400 s 都出现过），
单次观测**无统计意义**；V1（仅热区）/ V2（仅音频）是否引发该回归**尚未取到有效样本**。

---

## 1. 目的

延续用户 2026-10-03 议题：*「vk40 出现了以前没有的 bug；以最后一版有实机验证的版本为界，审核后续增量。」*
第一遍已把边界锁定到 `git diff elden/vk34-recon → elden/vk40-2026-10-03` 的 **5 个文件**（DTB 逐字节比对确认 recon 忠实）。
本遍目标：逐 hunk 分类、找实质隐患、并把"5 文件"进一步二分。

---

## 2. 静态审计：post-vk34 逐 hunk 分类

| 文件 | 功能性改动 | 纯调试 | 风险 |
|---|---|---|---|
| `sm8750-lenovo-elden.dts` | **24 个热区**全部改成 4 级 passive trip（70/82/90/105 ℃）+ 4 条 cooling-map | 0 | 🟡 纯策略，空闲低温不触发；从未单独验证 |
| `q6apm.c` | **3 处 GPR 命令** `alloc_apm_pkt` → `alloc_apm_cmd_pkt`（GET_SPF_STATE / SHARED_MEM_MAP / UNMAP，多 8 字节 APM cmd header） | 3（2 个有副作用） | 🔴 N1/N2 |
| `q6apm-lpass-dais.c` | 新增 `q6i2s_prepare`：**MI2S BE graph 提前到 prepare 启动** | 3 | 🟠 N3 |
| `audioreach.c` | **无**（13 行全是 print） | 3（含 `print_hex_dump` 整包） | 🟡 N4 |
| `q6prm.c` | **无**（`int ret` + 1 行 print） | 1 | 🟢 |

`git diff --stat`：5 files, +806/−105（DTS 占 733/95）。

### 实质问题（不是"未验证"，是隐患）

- **N1（副作用写进日志）**：`q6apm.c` 把 `q6apm_get_apm_state(apm)` 当作 `dev_info` 的实参调用，
  位于 `apm_probe` 与 `q6apm_graph_open`。即**每次 probe / 每开一次 graph 都额外向 ADSP 发一条 GET_SPF_STATE，并可能阻塞 5 s**。日志不该有副作用。
- **N2（最可疑）**：3 处命令换成 `alloc_apm_cmd_pkt`，给包**加了 8 字节 APM command header**；
  而 vk34 原注释白纸黑字写 *"GET_SPF_STATE has no APM command header or payload"*，vk40 直接推翻。
  这是**唯一会改变发给 ADSP 的字节流的改动**。
- **N3**：`q6i2s_prepare` 把 BE graph 启动从 trigger 挪到 prepare，`is_port_started` 语义随之改变；启动顺序/重复启动未验证。
- **N4**：`audioreach.c` 残留 `print_hex_dump` 整包 + 3 条 DBG；`q6apm-lpass-dais.c` 的 `set_sysclk` 用 `%px`。日志被灌爆。

---

## 3. 二分变体（已构建，可回滚）

`geekidos-linux` 新分支（基于 `elden/vk34-recon`，`.config` 共用且自 10-02 12:12 未变）：

| 变体 | 分支 | commit | uname | 镜像 | sha256(前16) |
|---|---|---|---|---|---|
| V1（仅热区） | `elden/v1-thermal-only` | `f681b616a` | `…-gf681b616a3af` | `out/boot-elden-v1-thermal.img` | `d6cb6e2b29a86718` |
| V2（仅音频） | `elden/v2-audio-only` | `951c5f1c2` | `…-g951c5f1c2ca5` | `out/boot-elden-v2-audio.img` | `5e6d71df1f687d7d` |

对照：`elden/vk34-recon`=`e72a036ed`（`out/boot-elden-vk34recon.img`, `5397af38cf55480c`）、
`elden/vk40-2026-10-03`=`6ef87e6a8`（`out/boot-elden-vk40re.img`, `1a2315b8450f1103`）。

校验（解析镜像内 gzip 流 + DTB）：V1 DTB 与 vk40re DTB **同 hash**（含热区）、V1 内核**无**音频 DBG；
V2 内核**有** DBG、V2 DTB 与 vk34recon 同 hash（无热区）。uname 唯一。

---

## 4. 实机实验与结果

### 4.1 触发方法（可复现）

不依赖串口：`fastboot boot <img>` → SSH `root@192.168.7.1`（USB NCM）→
```sh
export XDG_RUNTIME_DIR=/run/phosh
export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/$(pidof phosh)/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
wlr-randr --output DSI-1 --on; sleep 4; wlr-randr --output DSI-1 --off   # 真实合成器提交
dmesg | grep -cE 'vblank timeout|PPM init|crash detected|fatal notification'
```

### 4.2 结果表

| 内核 | vblank timeout | UCSI PPM init failed | ADSP crash | 备注 |
|---|---|---|---|---|
| **vk34recon**（基线） | **0** | **0** | 0 | 含一次真实显示 on/off 提交；稳定 |
| **vk40re** | **6** | **1** | 0 | 6 次 vblank（t≈14 s ×2、t≈289–291 s ×4，即 boot modeset + 手动提交）|
| V1（仅热区） | 未取到（卡死） | — | — | 见 §6 |
| V2（仅音频） | 未取到 | — | — | 早期曾稳定运行 5 min，但无同口径 dmesg 计数 |

**可复现的回归 = DPU `vblank timeout` + `UCSI PPM init failed`**（vk40 有、vk34 无）。
`drm/dpu_encoder_phys_vid_wait_for_commit_done:550` / `wait for commit done returned -110`。

### 4.3 静默硬复位（未解）

- 用户多次观察到 vk40re **~1 min 一次**的整机重启；本人另一次观测 vk40re **稳定 400 s**。
- 复位**无 kernel panic / 无 Oops / 无 watchdog 打印**（`watchdog: Hard watchdog permanently disabled`）→ 更像 PMIC/固件级硬复位。
- 因间歇性，**不能**据单次"某版没重启"下因果结论。

---

## 5. 方法学坑（本遍踩到的）

1. **`/dev/ttyACM1` 被主机 ModemManager 占用**（`OSError: [Errno 16] Device or resource busy`），USB 串口时通时断，
   且 AT 探测会污染采集。**改用 SSH（USB NCM, 192.168.7.1）读 dmesg 更可靠**。
2. **ramoops 已注册但无用**：DTB 确有 `/reserved-memory/ramoops@c2000000`（4 MB，console/pmsg 各 2 MB），
   dmesg 显示 `pstore: Registered ramoops as persistent store backend`；但最小 rootfs **从不挂载 `/sys/fs/pstore`**，
   手动 `mount -t pstore pstore …` 后目录仍为空。→ 静默复位拿不到上一世代日志（待修，或改用 per-boot kmsg 落盘）。
3. `fastboot fetch` 在本机/设备**不支持**（`Device does not support fetch command.`），不能直接取分区。
4. `pkill -f`/`awk '/pat/'` 会匹配到当前 shell 自身 → 命令中途 143（老坑，见 `PITFALLS`）。

---

## 6. 钩子副作用事件（用户质疑，已回退）

为捕获静默复位，曾在持久根装 per-boot 钩子：
- `/usr/local/sbin/eldroid-kmsg.sh`：`exec cat /dev/kmsg >> /var/log/kmsg-$(uname -r).log`
- 在 `/usr/local/sbin/start-desktop.sh` 的 `set -u` 后插入一行后台启动。

**用户质疑**：钩子（持续 UFS 写 + 一个 `/dev/kmsg` 读者）是否**改变了时序，使重启不再发生**？
观测上确有强时间相关（装钩子后 vk40re 从"~1 min 一次"变"400 s 稳定"）。**此confound无法排除**。
→ 已 `cp start-desktop.sh.bak-eldroid start-desktop.sh` 还原、删除 `eldroid-kmsg.sh`（已核验：`grep -c eldroid-kmsg`=0，`^set -u$`=1）。
→ 另有用户反馈：一次改动后**某版内核物理卡死**，只能物理复位；故**不再做未评估的持久系统改动**。

---

## 7. 设备残留（无害，可清理）

持久根（`/dev/sda17`）：
- `/usr/local/sbin/start-desktop.sh.bak-eldroid`（还原备份）
- `/var/log/kmsg-7.2.0-debug-{g6ef87e6a8868,gba28ec16f01f-dirty,ge72a036ed4be}.log`（取证文件）

---

## 8. 结论与下一步

**已确定**：
- post-vk34 增量就是那 5 个文件；其中 N1/N2/N3 是实质改动，N4 是残留调试打印。
- vk40 相对 vk34 有**可量化**回归：DPU vblank timeout + UCSI PPM init failed。

**未定（下一步，需谨慎、单变量、长时窗）**：
1. V1/V2 谁引发 vblank 回归（同口径 dmesg 计数，各 ≥1 次有效样本）。
2. 静默硬复位的触发条件（建议：**不改持久系统**，用 SSH 读 dmesg；必要时另建非侵入的跨复位日志方案）。
3. 若 V1 也出 vblank → 归因热区（70 ℃ 提前限频拖慢 DPU 提交）；若 V2 出 → 归因音频/DBG 打印。

> 纪律：设备当前不稳定且通信不可靠，任何上机前先确认可回滚（RAM 引导、不改持久根）。
