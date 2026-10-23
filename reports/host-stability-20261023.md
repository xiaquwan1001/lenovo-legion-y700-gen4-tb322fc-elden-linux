# 宿主机稳定性排查记录（2026-10-23）：从 Godot 崩溃一路查到 CPU 侧

- **日期**：2026-10-23 09:40 → 21:10（接续 `host-memory-bitflip-rootcause-20261020.md`、`host-mem-stress-bios-round2-20261020.md`）
- **平台**：i7-14700KF + ASUS PRIME Z790-P D4（BIOS 1836, 2026-04-16, 微码 `0x133`）+ RTX 4060（驱动 595.99.02）
  + 2×32 GB `Corsair CM4X32GC3200C16K2E`（dual-rank，**Configured Speed = Speed = 2133 MT/s / 1.2 V ⇒ XMP 关、JEDEC 档**）
- **无 ECC**：`EDAC ie31200: No ECC support`
- **拓扑**：`cpu0–15` = 8 个 P 核（2 线程，max 5.2 GHz）；`cpu16–27` = 12 个 E 核（单线程，max 4.2 GHz）
- **RAPL**：`PL1 = 220 W / PL2 = 250 W`（不再是 10-22 记录的 4095 W 无限制档）
- **结论（一句话）**：Godot 崩溃是 Mesa 软件 GL 的确定性 bug（与硬件无关，已复现/已排除）；
  但**同一天内**这套硬件在「数学正确性」和「内核元数据完整性」两条独立战线都失败了，且第 12 次 panic 与第 4 次 **RIP 完全同偏移**。

---

## 0. 计时口径（重要）

本机 BIOS 处于高频迭代期，以下两类事件**不计入对当前配置的判决**：

1. **BIOS 调试窗内的崩溃**：10-17 10:52 → 10-22 11:02 的 11 次内核 panic、10-20 22:14 → 10-22 16:45 的 208 条
   corrected MCE，均落在调试期。
2. **每晚 23:30 固定断电**：例如 `boot -3`（10-22 18:18 → 23:29:14）是计划断电，不是崩溃。
3. **哨兵里 `10:22 segfault +1`** 是本人用 `/tmp/segtest` 造的测试信号，非真实故障。

判据只看「长跑窗口」与「BIOS 定版后窗口」。

---

## 1. Godot 崩溃（09:32:47）：**软件缺陷，不是硬件**

崩溃现场 `~/.local/share/godot/app_userdata/Lobotomy Corporation Remake/logs/godot2026-10-23T09.32.47.log`：

```
handle_crash: Program crashed with signal 11
[2]..[9] libgallium-26.0.8-1ubuntu0.3.so(+0x...)
[10] libgallium(...driCreateContextAttribs+0x32b)      ← Mesa GL context 创建
[11] libGLX_mesa.so.0 → [13] libGLX.so.0 → godot()
```

判定（最小工程 `/tmp/gltest`，空白 3D 场景对照）：

| 运行环境 | 结果 |
|---|---|
| `DISPLAY=:99`（Xvfb → Mesa llvmpipe/gallium） | **同样逐帧相同的 backtrace，SIGSEGV 于 `driCreateContextAttribs`** |
| `DISPLAY=:0`（真机 → NVIDIA 595.99.02） | 正常，`OpenGL 3.3.0 NVIDIA`，0 报错 |
| `GALLIUM_DRIVER=zink`（Xvfb + Vulkan） | 正常，`zink Vulkan 1.4 on RTX 4060` |

- `/tmp/r73-diag/t1.log … t4.log`、`probe_stdout.log` 里 **4–5 次运行的 backtrace 完全一致** ⇒ 确定性，不是随机位翻转。
- **结论**：跑 Xvfb 的无头 Godot 测试必须显式 `GALLIUM_DRIVER=zink`，默认 llvmpipe 路径必崩。与 BIOS/CPU/内存无关。

---

## 2. 建立观测哨兵（本次新增基础设施）

| 文件 | 作用 |
|---|---|
| `~/.local/bin/stability-sentinel.py` | 采集器（纯用户态，无 sudo） |
| `~/.config/systemd/user/stability-sentinel.{service,timer}` | 开机后 3 min 起，每 5 min 一次，`Persistent=true` |
| `~/.local/share/stability-sentinel/sentinel.csv` | 基线序列 |
| `~/.local/share/stability-sentinel/alerts.log` | **只在有增量时**追加，并 `notify-send -u critical` |

采集项（都是"累计值 + 增量"）：`mce_total` / `mce_last`（读 `/var/lib/rasdaemon/ras-mc_event.db`，644 可读）、
本次 boot 内核日志中 `segfault at` / `general protection fault` / `Oops:` / `BUG: unable to handle` / `Machine check events logged` 计数、
`/var/crash/` 的 kdump 目录数、apport `.crash` 报告数。换 boot 时只记"计数重置为新基线"，不误报。

验证：第 2 次运行静默；人为把 state 里 `mce_total` 减 2、`segfault` 减 1 后立刻产出
`segfault +1（本次boot累计 3）；MCE +2（累计 208…）`，之后已复原。

**core dump 通道变更**（用户执行）：装 `systemd-coredump`，`apport-core-dump-handler` 被卸载 ⇒
`kernel.core_pattern = |/usr/lib/systemd/systemd-coredump …`、`Storage=external`、`MaxUse=5G`；
副作用：**以后不再产生 `/var/crash/*.crash` 这类可读 apport 报告**（哨兵的 `apport_crashes` 列会停在 26）。
另：`/etc/sysctl.d/90-pi-cores.conf`（旧 `/var/lib/pi-cores`）已被 `99-coredump.conf` 覆盖，遗留一个 975 MB 旧 core。

---

## 3. 内核 panic 全谱（12 次，含本次新解出的 11 份 dmesg）

解密技巧（无需 sudo，适用于 `linux-image-*.crash`）：`VmCoreDmesg` 字段是**按行分块的 base64**，
逐行 `b64decode` 后**拼接再一次性 gunzip**（逐行解压会失败）。root-only 的 `dmesg.*` 只能 `sudo cp`。

| # | 时间 | comm | 崩溃时 uptime | RIP | 前置 MCE |
|---|---|---|---|---|---|
| 1 | 10-17 10:52 | ThreadPoolForeg | 9726 s | `lookup_swap_cgroup_id+0x49` GPF，非规范地址 `0x7d36a84574ffc` | 无 |
| 2 | 10-17 11:16 | stat | 1344 s | `__rb_insert_augmented+0x77`，CR2=`ffff889225577118` | 无 |
| 3 | 10-17 18:54 | Renderer | 23612 s | `nv_mem_pool_move_pages+0x61 [nvidia]`（Firefox WebRender） | 无 |
| 4 | 10-19 21:47 | MainThread | 6484 s | **`refill_obj_stock+0x83/0x270`** + `swap_put_entries_direct` + `Bad rss-counter MM_SWAPENTS val:-3` | 无 |
| 5 | 10-19 22:05 | rm | 821 s | `ext4_discard_preallocations+0xe3`，CR2=`0x40000000010` | 无 |
| 6 | 10-19 23:01 | bash | **42 s** | `blake2s_compress_ssse3+0xb9` | 无 |
| 7 | 10-20 10:37 | mprime | **70 s** | `__rmqueue_pcplist+0x54`，R15=**`dead000000000100`**（SLUB LIST_POISON）+ `__list_del_entry_valid` WARNING | 无 |
| 8 | 10-20 22:42 | rm | 4157 s | `BUG: unable to handle … ffffd0f94fb47d68` | **6 条** |
| 9 | 10-21 16:33 | stress | **69 s** | Oops | **4 条**（41/42/57/60 s） |
| 10 | 10-22 10:31 | bash | 262 s | `__anon_vma_interval_tree_remove+0x36` | **5 条** |
| 11 | 10-22 11:02 | mprime | **32 s** | `psi_task_switch+0x1a1`，CR2=`ffff8d7f5da7b011` | 无 |
| **12** | **10-23 20:31** | **kswapd0** | **42183 s（11.7 h）** | **`refill_obj_stock+0x83/0x270`** GPF，非规范地址 `0x7fff8afa6ab2fa00` | **无** |

**形态统计**：12 次里 **3 次落在 mm/slab/rbtree 元数据**（#2 红黑树、#4 与 #12 同一 per-CPU freelist 库存函数），
4 次在**开机 32–70 s 内**就崩（mprime/stress/bash/rm），只有 #3 落在 NVIDIA 驱动里（形态独立，另案）。

### 3.1 第 12 次（20:31:56）完整现场 —— 本次最关键一条

```
[42183.169336] Oops: general protection fault, probably for non-canonical address 0x7fff8afa6ab2fa00: 0000 [#1] SMP NOPTI
[42183.169346] CPU: 9  UID: 0  PID: 216  Comm: kswapd0
[42183.169352] RIP: 0010:refill_obj_stock+0x83/0x270
[42183.169362] R13: 7fff8afa6ab2fa00        ← 非规范地址（同帧合法内核指针是 ffff8b033f4b4d00 / ffff8b033ffd5280）
[42183.169366] CR2: 0000000034eec000
Call Trace:
  __memcg_slab_free_hook+0xfd → kmem_cache_free → free_buffer_head
  → try_to_free_buffers → jbd2_journal_try_to_free_buffers → ext4_release_folio
  → filemap_release_folio → shrink_folio_list → evict_folios → shrink_node → balance_pgdat → kswapd
```

- **与 #4 完全同偏移**（`refill_obj_stock+0x83`）：同一个 per-CPU slab 库存指针被写成垃圾值；
  一次发生在进程释放路径（#4），一次发生在 kswapd 回收 ext4 buffer_head 路径（#12）⇒ 不是单点驱动 bug。
- 崩前最后 4 条是无害的 `x86/split lock detection: #AC`（Unity 引擎 `LobotomyCorp.ex` / `UnityPreload`，
  地址 `0x6ffff93e/f0d1c`，20:30:29/30、20:31:43/43）；**没有** OOM / 分配失败 / 锁死预警。
- **零 MCE**：整份 dmesg 中 `mce: [Hardware Error]` = 0，哨兵同一时刻 `mce_total` 仍是 208（最后一条 10-22 16:45）。
  ⇒ 这次没有机器检查前兆，写坏的路径逃过了 MCA 上报。
- **此前"电压型硬挂"的假设被推翻**：没有任何 watchdog/lockup 记录，落点就是 slab 完成路径里的野指针。

---

## 4. MCE 记录（rasdaemon）

- 库：`/var/lib/rasdaemon/ras-mc_event.db`（644，用户可直接读；`ras-mc-ctl --errors/--summary` 亦可）
- **总数 208 条，全部 `Corrected_error`**，时间分布：10-20: 7｜10-21: 178｜10-22: 23｜**10-23: 0**
- 类型（bank 0）：`Internal parity error`、`Instruction TLB Level-0 Error`、`Instruction CACHE Level-0 Instruction-Fetch Error`
- CPU 分布：12(48+32)、8(43+26)、14(15+4)、10(14+3)、0(8+1)、4(5+1)、6(1+1) —— 集中在少数核
- 注意口径：10-20 22:14 之前 rasdaemon 尚未记录，所以 #1–#7 的"无 MCE"是**未观测**，不是已排除。
- `pstore`（`efi_pstore` 已加载）**为空**，无固件侧存档。

---

## 5. mprime 压测（10-23 两阶段，均在 LLC5 / −0.065 V 的旧配置上）

驱动脚本 `~/mprime/stab.sh`（`small` = 4–8 K FFT / `TortureMem=0`；`ram` = 512–4096 K；`blend` = 4–8192 K），
20 worker，`TortureHyperthreading=1` ⇒ **#1–8 = P 核（各 2 线程，#9–20 = E 核（各 1 线程）**。

### 5.1 阶段 1：`small`（纯核内计算）—— **PASS**

- `~/mprime/logs/20261023-103505/`：**56 min，20 worker 全 0 errors / 0 warnings**（#1–8 各 80 test，#9–20 各 18 test）
- 遥测 721 个样本：pkg/core 峰值 100 °C，但**仅 12 个样本 ≥100 °C，首次出现在 3391 s（尾段）**；
  `package_throttle_count` 0 → 20780（摊在 69 min）；频率区间 3472–5219 MHz
- 含义：在 220/250 W 档，**核内运算通路（L1/L2 内）56 min 无错**

### 5.2 阶段 2：`ram`（512 K 起，压 L3/IMC）—— **FAIL，且 mprime 自己被打死**

`~/mprime/logs/20261023-113123/`：

```
11:33 [Worker #13] FATAL ERROR: Rounding was 0.5, expected less than 0.4   (512K FFT)
11:34 [Worker #19] FATAL ERROR: Rounding was 0.5, expected less than 0.4   (512K FFT)
11:36:30 kernel: traps: mprime[410562] general protection fault ip:5964ba … in mprime
退出码 139（SIGSEGV），挂钟 313 s（请求 2700 s）；report.txt 只抓到 #13 一条，实际 2 个 worker 各错 1 次
```

遥测 35 个样本：**63 s 即触 100 °C**，10/35 样本 ≥100 °C，5 min 内 `pkg_thr` 92 → 20780（+20688），
频率掉到 4200 MHz ⇒ 这次是**高温 + 节流**与 FFT 失败混在一起，不能单独归因。

**但归因仍有强线索：历史 5 次 Rounding 全部落在 E 核**

| 日期 | 档位 | 出错 worker | 核类型 |
|---|---|---|---|
| 10-22 | blend | #18、#12、#19 | E |
| 10-23 | ram | #13、#19 | E |

P 核（#1–8）在所有轮次里**一次都没错**，512 K self-test 全部 `passed`。
512 K / 560 K FFT 工作集约 16 MB > E 核 L2（2 MB/簇），走共享 L3/ring ⇒
形态指向 **E 核集群在高 ring 流量下的 Vmin 不足**，与"内存条位翻转"（10-20 `stressapptest` 7 次 incidents）是两条不同战线。

---

## 6. 当天用户态崩溃（同属"上一次崩溃"的上下文）

| 时间 | 事件 | 备注 |
|---|---|---|
| 09:23:28 | `bash` segfault in `libc.so.6`（`rbx=0x74bf33a13580`，故障地址 = rbx+1；同帧 `rdi/rdx/rax=0x76bf33a14740`，高位字节 74bf≠76bf） | apport `_usr_bin_bash.1000.crash` 已存；命令是 `curl … \| python3 -c …` |
| 09:27:12 / 09:50:17 / 11:34:38 / 13:35 / 13:46 | `libxul.so` GPF/segfault 共 5 次（偏移集中在 `0x3f03d53 / 0x3f0504a / 0x3f0503a / 0x3536152`） | 11:34 是 `TaskCon~ller #0`，与 mprime 满载同期 |
| 11:59 | segfault +1（哨兵记） | |
| 13:19 / 13:35 | `python3.14`、`ptyxis`、`firefox-bin` apport 崩溃报告 | `/var/crash/_usr_*.crash` |

---

## 7. BIOS 参数变更与"通过 15 min"的那一版

| 版本 | 防掉压（LLC） | 负压偏移 | 备注 |
|---|---|---|---|
| 旧（10-23 08:49–20:31 在跑） | **5** | **−0.065 V** | 11:31 mprime `ram` FAIL + 20:31 内核 slab 损坏 |
| 新（20:36 重启后） | **4** | **−0.055 V**（整体 +10 mV） | 20:37–20:52 窄档 512–560 K **125 次 self-test 全过、0 错误** |

**净效果的判读（重要，别过度解读）**：

- 偏移 +10 mV 在**轻/中载确定变高**；
- ASUS LLC 编号越大补偿越强，**5 → 4 = vdroop 变大**，满载高电流下 Vcore 可能反而**更低**；
- ⇒ 若失败点在"高电流瞬间掉压"，这一改**未必是净增益**；若在"中低载 Vmin 不足"，正好对症。
- 想确证必须**实测 Vcore**：本板 `/sys/class/hwmon/…/in0`（nct6798，空闲 1.05 V）可采，满载时对比新旧两档即可判定 +10 mV 是否被 LLC 吃掉。

**15 min 不够的证据**：本机失败时间分布是**双峰**的 ——
快失败 32 s–35 min（mprime 512 K：10-22 在 22/27/31 min；10-23 在 1–2 min），
慢失败 11.7 h（20:31 的 kswapd 路径）。⇒ 需 **≥60 min 满载 + 数小时含游戏的日常负载** 两个维度都干净。

---

## 8. 散热（独立问题，判定电压稳定性的前提）

- 10-22 实测：满载启动 **6–12 s** 即 pkg/core 100 °C（253 W 级通常 30–90 s）⇒ 优先怀疑散热硬件（泵/风扇曲线被 BIOS 重置、扣具、硅脂、风道）
- 10-23 复测（`ram` 档）：**63 s** 破 100 °C；`small` 档 56 min 内只有尾段 12/721 样本 ≥100 °C
- `pkg_thr` 5 min 内 +20688 ⇒ 严重节流，此状态下做电压/频率判定会被高温放大且不可复现
- ASUS 该板在 Linux 下不暴露风扇 RPM（sensors 只有 nct6798 in/fan 通道，fan1/4/5 = 0 RPM 需在 BIOS 里核对）

---

## 9. 当前结论与判据

### 9.1 已确立

1. **Godot 崩溃与硬件无关**（Mesa llvmpipe 确定性 bug，用 zink 规避）。
2. **内核存在静默数据损坏**：12 次 panic 中 3 次在 mm/slab/rbtree 元数据，`refill_obj_stock+0x83` 两次同偏移。
3. **mprime 数学错误集中在 E 核**（5/5 次），P 核从未出错；核内小 FFT 56 min 干净。
4. **无 ECC 使损坏不可纠正**，且多数损坏逃过 MCA 上报（多种崩溃零 MCE）。
5. 旧配置（LLC5 / −0.065）在两条战线同时判不合格；新配置（LLC4 / −0.055）只有 15 min 正面数据。

### 9.2 合格判据（沿用 10-20 口径，并补充）

- `mprime`：`small` ≥60 min、`ram`/`blend` ≥60 min 且 **0 errors**（≥4 h 为强判据）
- `stressapptest`：`hardware incidents = 0`、`Status PASS`
- 多轮 clean 构建：无 ICE/SIGSEGV/SIGILL，产物逐对象 sha256 全一致
- **新增**：连续 uptime ≥12 h 内哨兵 `alerts.log` 无 MCE/段错误/panic 增量（覆盖 20:31 那条慢失败路径）
- **新增**：Steam + 《Lobotomy Corporation》连开 1–2 h 不崩（复现 20:31 场景：游戏 + 着色器缓存写入压力是 kswapd/ext4 回收路径的最佳触发器）

### 9.3 待办

1. 新配置下 `./stab.sh run ram 60`，同时采 Vcore（`in0`）对比新旧两档满载电压
2. 新配置下跑 1–2 h 游戏场景复现实验，事后 `cat ~/.local/share/stability-sentinel/alerts.log`
3. **单条内存对照**（只插 A2 → 只插 B2，各跑 60 min + 游戏负载）分离"条子 vs CPU/IMC"
4. 若新配置仍出现 slab 损坏或 Rounding ⇒ **走 Intel RMA**（14700KF，Vmin shift 重灾型号，保修已延至 5 年）；
   证据包 = 本文第 3 节 12 次 panic 指纹 + 第 5 节 mprime FAIL 日志 + 第 6 节用户态崩溃 + 无 ECC 说明
5. 若确认散热是主因（PL 回 253 W 后 30 s 内 ≤90 °C ⇒ 功耗问题；仍 10 s 破 100 °C ⇒ 散热器问题），先修散热再谈电压

### 9.4 备注/清理

- `/var/crash` 已占 **5.1 GB**，单份 vmcore 达 **1.8 GB**（`dump.202610232032`），确认 dmesg 已留存后可删大 dump
- 10-23 20:31 的 panic dmesg 已存 `/tmp/hwdiag/dmesg.202610232032`（重启会清空 `/tmp`，需要长期保留请挪到本目录）
- `pstore` 空；`/var/lib/pi-cores` 有 975 MB 旧 core 可清

---

## 10. 复现/取证命令速查

```bash
# 哨兵
systemctl --user list-timers stability-sentinel.timer
cat ~/.local/share/stability-sentinel/alerts.log
tail -3 ~/.local/share/stability-sentinel/sentinel.csv

# MCE
ras-mc-ctl --summary; ras-mc-ctl --errors | head
python3 -c "import sqlite3;print(sqlite3.connect('file:/var/lib/rasdaemon/ras-mc_event.db?mode=ro',uri=True).execute('select count(*) from mce_record').fetchone())"

# 解 apport 内核崩溃报告（无需 sudo）
python3 - <<'PY'
import base64, gzip, glob, os
for f in glob.glob('/var/crash/linux-image-*.crash'):
    lines = open(f, encoding='utf-8', errors='replace').read().split('\n')
    i = next(n for n, l in enumerate(lines) if l.startswith('VmCoreDmesg')) + 1
    blob = b''
    while i < len(lines) and lines[i].startswith(' '):
        s = lines[i].strip(); i += 1
        blob += base64.b64decode(s + '=' * (-len(s) % 4))
    open('/tmp/panic_' + os.path.basename(f) + '.dmesg', 'w').write(gzip.decompress(blob).decode('utf-8', 'replace'))
PY

# 温度 / 风扇 / 电压（nct6798 的 in0 = CPU Vcore，空闲约 1.05 V）
sensors | sed -n '/nct6798/,/^$/p'
# 节流计数与频率
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq
cat /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw
# mprime 自己的遥测（pkg_c/max_core_c/max_mhz/pkg_thr 列）
tail -5 ~/mprime/logs/<时间戳>/telemetry.csv
```

## 11. 相关文件索引

| 路径 | 内容 |
|---|---|
| `~/mprime/logs/20261023-103505/` | 阶段 1 `small` 56 min PASS（console/telemetry） |
| `~/mprime/logs/20261023-113123/` | 阶段 2 `ram` FAIL + mprime GPF（console/report/telemetry） |
| `~/mprime/logs/512k-E-2037.log` | 新 BIOS 下 512–560 K 窄档 15 min，125 self-test 全过 |
| `/var/crash/202610232032/dmesg.202610232032` | 第 12 次 panic 原文（root-only；副本 `/tmp/hwdiag/`） |
| `/var/lib/rasdaemon/ras-mc_event.db` | 208 条 corrected MCE |
| `~/.local/share/stability-sentinel/` | 哨兵 csv/state/alerts |
| `/var/log/kern.log`、`/var/log/syslog` | `adm` 组可读；panic 时日志在写一半处被截断（可作硬冻结标志） |
| `/tmp/r73-diag/` | Godot/Mesa 复现材料（`t1..t4.log`、`probe_*`） |
| `~/y700-elden/reports/artifacts/host-panic-20261023/dmesg.202610232032` | 第 12 次 panic dmesg 的长期副本（从 `/tmp/hwdiag` 拷出，防 `/tmp` 被清） |
