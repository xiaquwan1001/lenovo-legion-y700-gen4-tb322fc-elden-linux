# UEFI ① 前置：排除「回落 stock Android 覆盖 DDR 标记窗口」+ 打通不依赖屏幕的取证通道

> 2026-11-01 22:4x–23:5x CST。性质：**主机侧静态 + 设备只读（ssh）**，本轮零写盘、无 fastboot、无 reboot。
> 设备：U2（SN `HA2EXB0E`），在机 Linux `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172`。
> 证据分级：`已证` = 今日命令输出 / file:line；`档案` = 本仓历史报告/复盘（注明出处）；`未证` = 推断。
> 关联：`reports/uefi-ddr-blackbox-20261101.md`（§0 六条、§6.2 回落可控已跑通一半）、`reports/uefi-observability-pivot-20261101.md`、
> `reports/uefi-slotboot-stuck-fastboot-20261101.md` §8、`PITFALLS` #484/#485。

---

## §0 结论（先看这里）

1. **能绕开回落覆盖**，且不只有一条路：
   ① **EDL Firehose `peek` 物理内存读**：bkerler python edl 有完整 peek/poke 族（`edl.py:33-36` + `firehose.py:1671`），
      设备进 9008 后可直接按物理地址读 DDR——**不经过任何分区加载，天然不受回落启动干扰**；edl-ng 没有 peek。
   ② **「a 槽 unbootable ⇒ 回落停在 fastboot」**：本日早前已实测（`uefi-ddr-blackbox-20261101.md` §6.2，`qbootctl -u a`），
      Android 不再启动，读窗口走 `--set-active=b` + reboot 回 Linux（~15 s 回 ssh，已证）。
2. **推荐方案 = 方案 a′（a 的保守组合）**：保持 a 槽 unbootable（已备份 misc + GPT 前提下），载荷崩溃后设备停 fastboot，
   再 `fastboot oem edl` 进 9008，用 **python edl `peekqword`/`peek`** 读候选 PA。整条链不改变 boot 分区内容、不依赖屏幕、
   回退只需 `qbootctl -m a`。方案 b（挑 Android/XBL 都零填的窗）作为**并行对照**（零写盘风险，但解释力弱，见 §3）。
3. **peek 能否被本机 loader 接受 = 上机一发才能定**（§1.1）：loader 二进制里明文有
   `"Peek is disabled on secure boot devices%c"` ⇒ peek 已实现但按安全启动状态门控；本机为商用熔丝件，**可能被拒**。
   静态能查到「门控存在」，查不到「本机是否被门控」。最低成本判定：`peekqword 0x<已知非零地址>`。
4. 免按键进 EDL：`fastboot oem edl` 在**本机已验证可用**（档案：`archive/topics/复盘.md:63`，2026-10-03），
   且 EDL 进入不依赖 `fastboot continue` 的分区加载，与 #147 的 `Device Error` 不冲突（§2）。
5. 窗口审计（§3）：`splash_region` 尾部（0xFEF00000）与 `dsm-partition-2`（0x89300000）都是 **no-map** 保留，
   Linux 侧绝不分配；`oem-vm` 0xF7C00000 起（此前 0xF7D00000 写入疑似触发复位）**继续列为禁写**；
   `video`（0x9C300000）会被 Android venus 使用 ⇒ 回落时必被覆盖，只适合「回落已被切断」后的场景。

## §1 EDL 通道能力

### 1.1 python edl `peek` 的前置条件（1a）

调用链（全部 file:line 已证）：

| 环节 | 位置 | 语义 |
|---|---|---|
| CLI 分发 | `edl.py:33-36`（usage）、`edl.py:183`（cmd 白名单含 `peek/peekhex/peekdword/peekqword/memtbl/poke*/memcpy`） | 入口存在 |
| 参数解析 | `edlclient/Library/utils.py:346-357` | `<offset> <length> <filename>` 直通 |
| **能力检查** | `edlclient/Library/firehose_client.py:522-527`：`check_cmd("peek")`；`check_cmd` 实现在 `firehose_client.py:133-139` | 若 `supported_functions` 非空且不含 `peek` ⇒ 直接报 `"Peek command isn't supported by edl loader"` 并拒绝 |
| **supported_functions 来源** | `edlclient/Library/firehose.py:1106-1149 get_supported_functions()`：向 loader 发 `cmd_nop()`，解析其回的 `Supported Functions` 列表；若 loader 回不出（`firehose.py:1111-1113` / `1146-1149` 两处 fallback），则**默认列表里含 peek** | loader 是否声明 peek 决定第一次检查结果 |
| **实际执行** | `edlclient/Library/firehose.py:1671-1705 cmd_peek()`：发 `<?xml?><data><peek address64="…" size_in_bytes="…"/></data>`；对大小写两种属性名各试一次（`firehose.py:1684-1702`），loader 回 `Invalid parameters`/`address … can't` 则失败 | Firehose 物理内存读，与存储/LUN 无关 |
| **loader 侧门控** | `xbl_s_devprg_ns.melf` 内明文（strings 实测）：`"Peek is disabled on secure boot devices%c"`、`"size in bytes is %d, nothing to peek/poke"`、`"Supported Functions (%d):"`、`"End of supported functions %d"`；**没有**独立的 `peek`/`poke` 裸命令串 | peek 在 loader 内**已实现但被 secboot 状态门控**；安全启动熔丝件上大概率直接拒绝 |
| 流式模式备注 | `edlclient/Library/streaming.py:819` `"Unpatched loader detected. Using standard QC mode. Limited methods supported: peek"` | 这句属于 **streaming/NAND 路径**（ Sahara 流式模式），与本机 UFS + Firehose 路径**无关**，不构成对我们 peek 的限制 |

**结论（1a）**：我们的 `xbl_s_devprg_ns.melf` 能不能 peek = **「可能」**——
静态能确定：① host 侧命令存在且实现完整；② loader 有 peek 处理代码与两条错误文案；③ 门控条件是「secure boot 设备」。
必须上机才能定：① loader 的 Supported Functions 列表里是否列 `peek`（决定 `check_cmd`）；② secboot 门控是否在本机触发。
一发 `peekqword` 即可同时回答两者（被 `check_cmd` 拦则看 host 报错；放行后被 loader NAK 则看 XML 回包）。

### 1.2 peek 确切命令行（1b）

```bash
cd ~/edl-tool/bkerler-edl-1cda1a6
L=~/下载/tb322fc/xbl_s_devprg_ns.melf
# 单步探活（推荐第一发）：读 8 字节 QWORD
python3 edl.py --loader=$L --memory=Ufs peekqword 0xFEF00000
# 正式读：1 MiB 窗口到文件
python3 edl.py --loader=$L --memory=Ufs --skipstorageinit peek 0xFEF00000 0x100000 /tmp/peek_fef00000.bin
```

- **单位**：offset/length 均为**字节**；`getint()`（`firehose_client.py:389-395`）接受十进制或 `0x` 十六进制。
  XML 里第一发是十进制字符串、被拒后自动重发 hex 形式（`firehose.py:1684/1699`）。
- **`--lun` 不适用**：peek XML 无 lun 属性，操作对象是物理地址，与 UFS LUN 无关。
- **`--memory=Ufs`**：必填与否——省略时 `firehose_client.py:100-105` 会从 `supported_functions` 里猜 `ufs`，猜不中回退 eMMC；
  显式给出可消除歧义。它只进 configure 的 memoryName，不影响 peek 本身。
- **是否需要 configure**：**configure 总会跑**（`firehose_client.py:78 connect() → firehose.connect() → firehose.configure(0)`，
  `firehose_client.py:117`），`--skipstorageinit` 只是让 configure XML 里带 `SkipStorageInit=true`（`firehose_client.py:58`）。
  读 DDR 建议带 `--skipstorageinit`（跳过存储初始化，缩短在 9008 停留时间、符合只读意图；不改变 peek 行为）。
- **探活替代地址**：若 `0xFEF00000` 读回全 0 不能区分「成功读到 0」vs「门控拒」，先用**已知非零**地址探活，如 `0x81D00000`（smem，DT 已证存在）。

### 1.3 edl-ng vs python edl 能力对照（1c）

| 能力 | edl-ng 1.6.0（`/usr/local/bin/edl-ng`，.NET AOT） | bkerler python edl（本目录） |
|---|---|---|
| 分区读 / 扇区读 / 整 LUN 读 | ✅ `read-part` / `read-sector <start> <n> [-u lun]` / `read-lun` | ✅ `r` / `rs` / `rf`（`--lun`） |
| GPT 打印 / dump | ✅ `printgpt`（省略 `-u` 扫全部 LUN）/ `dump-rawprogram` | ✅ `printgpt` / `gpt` |
| 写 / 擦 | ✅ `write-part` / `write-sector` / `erase-part` / `erase-sector` / `erase-all` / `rawprogram` | ✅ `w/wl/wf/ws` / `e/es/ep` |
| 槽 / loader 管理 | ✅ `upload-loader` / `reset` / `provision` | ✅ `--loader` / `reset [--resetmode=edl]` / `provision` / `setactiveslot` |
| ramdump（0x900E） | ✅ `ramdump` | ✅ `memorydump` 模式（sahara） |
| XML 直通 | ✅（rawprogram） | ✅ `send` / `xml` / `rawxml`（**可用它手发 `<peek …/>`**，即使 `check_cmd` 拦截也能绕） |
| **物理内存读（peek/poke 族）** | ❌ **没有**（strings 里 "Peek/TryPeek" 是 .NET `ConcurrentQueue` 的，非 Firehose 命令） | ✅ `peek/peekhex/peekdword/peekqword/poke*/memtbl/memcpy` |

**硬结论**：**edl-ng 对存储/GPT/写擦够用但缺 peek**——「绕开回落覆盖读 DDR」的唯一现成通道是 python edl 的 peek 族
（或 python edl `rawxml` 手发 `<peek>`）。-loader 与 udev 前置已就绪：`/etc/udev/rules.d/99-edl.rules`（05c6:9008 MODE=0666 plugdev），
编排者今晚已 root 执行 `udevadm control --reload-rules` + `udevadm trigger --subsystem-match=usb --action=change`。`已证`（编排者回执）

## §2 免按键 EDL 判据

- **`fastboot oem edl` 在本机可用**：档案 `已证` —— `archive/topics/复盘.md:63`（2026-10-03）
  「`fastboot oem edl` **可用**（fastboot 直接进 9008，不用 adb）——以后进 EDL 优先用它」，同文件 ：121 重复确认；
  `RUNBOOK-BRINGUP/README.md:118` 把它列为 EDL 路的标准入口。`已证(档案)`
- **反例口径**：`.pi/skills/qualcomm-edl-flashing/SKILL.md:31` 说该命令 "usually unsupported (unknown command)"
  ——那是**跨设备/三代**口径，与本机 2026-10-03 实测冲突；按「本机档案优先」采信可用，但**上机时若回 `unknown command` 不算异常**，
  回退到物理进 EDL（关机 → 长按 Vol+ 插线，见 skill）。`外部(项目技能)`
- **静态字符串**：`backup/stock-259/abl_{a,b}.img`（1 MiB，ELF）前 256 KiB 为正文、其余为 0，明文里**没有** fastboot 命令表
  （`fastboot/oem/edl/reboot` 全 0 命中）⇒ 命令表大概率在压缩段/间接表中，**静态无法确认或否认**。`未证`
- **与 `fastboot continue` 的 `Device Error` 的关系**：`oem edl` 走的是 ABL 内 reboot-to-download-mode 路径
  （等价 `adb reboot edl` / `reboot bootloader` 类），**不经过「从分区加载镜像」**；#147 的
  `Failed to load image from partition: Device Error` 只发生在 continue→启动分区加载，两者不共享失败点。`未证（机制推断）`
  上机判据：`fastboot oem edl` 后主机 `lsusb` 应见 `05c6:9008`（#147 §1 已有同款先例）。
- 若 loader 放行 peek，则还可用 `edl.py reset --resetmode=edl` 在 9008 内再进 9008（`edl.py:93`），但本轮不需要。

## §3 窗口 × 清除者对照表

来源：设备 DT（`/sys/firmware/devicetree/base/reserved-memory/*`，今日 ssh 只读实测 `od` reg 解码）+ `/proc/iomem` + 既有报告。

| 窗口 | 基址/大小（DT reg，已证） | no-map | Linux 侧 | ABL/XBL 侧 | Android 回落时 | 本轮用途 |
|---|---|---|---|---|---|---|
| `splash_region` 尾 | 0xFC800000 + 0x02B00000（尾 4 MiB = **0xFEF00000–0xFF300000**） | ✅ | **绝不分配**（reserved，无-map；`/proc/iomem` 无对应行） | ABL 开机把 splash 帧缓冲画进此区（**是否清零整段未证**）；`qcom,m-die-id` 等 XBL 消费者未证实 | fb 使用者覆盖，尾部是否被清 = 未证（r4/r5 读到干净 0 的两种解释仍并存） | **首选写窗**（仅在切断回落/EDL 读取前提下） |
| `dsm-partition-2` | **0x89300000** + 0x00A80000（10.5 MiB） | ✅ | 绝不分配 | DSM dump 通道，XBL/ABL 崩溃路径才写；正常启动是否清零未证 | 干净 0（r4/r5 实测）——同为两解释并存 | 备选写窗 |
| `oem-vm` | 0xF7C00000 + 0x04C00000（76 MiB） | ✅ | 绝不分配；**写它疑似直接触发复位**（blackbox §3 r3/r4/r5） | Gunyah/pVM 域管辖（推断） | 覆盖成低熵（实测） | **禁写** |
| `video` | 0x9C300000 + 0x00800000（8 MiB） | ✅ | 绝不分配 | venus 视频堆 | **Android venus 必用 ⇒ 必被覆盖** | 只适合「回落已切断」场景；不推荐 |
| `xbl-ramdump` | 0xB8000000 + 0x01C00000（28 MiB） | ✅ | 绝不分配 | XBL ramdump 专用 | 仅崩溃转储时写（多轮 handoff 后 mdcompress/xbl_sc_logs 全 0，见 pivot §0.3） | 备选（语义干净，但可能被 XBL 崩溃路径清） |
| `trust-ui-vm` | 0xF3800000 + 0x04400000 | ✅ | 绝不分配 | 安全 VM（TZ 管辖，推断） | 未知 | **禁写**（同 oem-vm 类保护域风险） |
| Mu PrePi 可用区 | 普通System RAM（如 0xE3F00000） | — | 已用 `memmap=1M$PA` 保留（在机 cmdline 已证） | PrePi 之前是 XBL 的 free pool | **Android 随便分配 ⇒ 必覆盖** | 仅在「回落停 fastboot / EDL 直读」下有效；已是现状基线 |

`未证`（对照表通条）：splash 尾 / dsm-2 的「干净 0」到底是「写没执行」还是「回落启动清零」——**本报告的全部意义就是用 §4 实验拆开这个二选一**。

## §1.4 ★编排者实测更正（2026-11-01 23:0x，上机一发，**本报告 §1.1 的「可能」已定案 = 不能**）

上述 §1.1 的静态推断经上机一发改判：**本机 loader 不放行 peek，EDL 读 DDR 不可行**。逐条证据（本次实测）：

1. **loader 的 Supported Functions 列表里没有 peek**（`firehose_client - Supported functions:` 原样输出）：
   `program,read,nop,patch,configure,setbootablestoragedrive,erase,power,firmwarewrite,getstorageinfo,benchmark,emmc,ufs,fixgpt,getsha256digest`
   ⇒ `check_cmd("peek")` 直接拒绝：`Peek command isn't supported by edl loader`。
2. **绕过 `check_cmd` 用 `rawxml` 手发 `<peek>` 也不通**（两发：`size_in_bytes="8"` 与 `SizeInBytes="0x8"`，
   `address64="0x81D00000"` 已知非零 smem 探活）：两发均 `failed.` + 空回包 `[]` ⇒ loader 侧不实现/被 secboot 门控。
   按纪律未再重试。
3. **顺带坐实的四条正向事实**（本次实测，均可复用）：
   - `fastboot oem edl` **可用**（`OKAY [0.001s]`，4 s 后 `lsusb` = `05c6:9008`）⇒ 免按键进 9008 首次拿到实测证据（此前只有 2026-10-03 档案）。
   - **udev 规则生效**：`/dev/bus/usb/001/044` = `crw-rw-rw- root plugdev` ⇒ 无需 sudo。
   - **edl-ng 在本机可用**：`edl-ng printgpt -u 4 -l <melf> --memory Ufs` 正常列出 LUN4 全表（含 `spunvm`/`xbl_sc_logs`/`dpm`）⇒ 存储侧以 edl-ng 为准。
   - **`edl-ng reset` 从 9008 回 Linux 正常**：约 9 s 后 ssh 上来，`boot_id fb08d9d7…`，槽位未变。
4. **对 §0 结论的修正**：①「EDL peek 读 DDR」**作废**；→ ① 只剩「**切断回落**」一条路，且判据链改为：
   a 槽 unbootable ⇒ 载荷崩溃后 ABL 停 fastboot（无 Android 启动）⇒ **`fastboot boot <Linux boot.img>`**（零写盘）
   ⇒ Linux 里用 `probes/blackbox` 读窗口。这样「谁清零了窗口」的二选一仍能被拆开，且全程零写盘（除 GPT 属性位）。
   `scripts/edl-peek.sh` 保留但标注「本机 loader 不支持，勿再试」。record：`reports/trials/20261101T150336Z-edl-peek-probe-r1.json`。

## §4 三案实验单

> 通用前置（三案共同）：① `scripts/gpt-dump.sh` + LUN4 GPT 双表 dump；② `qbootctl` 状态与 `misc` 备份
> （先例：`reports/artifacts/uefi-ddr-20261101/slot-backup/misc.bin`）；③ logfs seg0 基线抓取（`PITFALLS #484`：
> 跨代次切槽会撞 LUN 错配，动槽位前必须有 logfs 基线）；④ 全部 fastboot/edl 命令**逐条**跑（`PITFALLS #3`）。
> 所有「读窗口」动作在设备回到 9008 或 Linux 后执行；**禁止** `fastboot boot/flash`、`reboot` 之外任何写。

### 方案 a′（推荐）：a 槽 unbootable 停 fastboot → `oem edl` → firehose peek

- **前置备份**：`misc`（`dd if=/dev/disk/by-partlabel/misc`）、LUN0/LUN4 GPT 双表、logfs 全 8 MiB、`qbootctl -h` 输出存档。
- **命令（单条）**：
  1. （在机 Linux）`qbootctl -u a`（把 a 槽标 unbootable；本日 §6.2 已验证过一次，机制就绪）
  2. 载荷实验照旧（`fastboot boot` ddrmarks 变体，零写盘）
  3. 崩溃后设备应停 **fastboot**（不再落 Android）——判据：主机 fastboot 可枚举 + `getvar current-slot`
  4. `fastboot oem edl` → `lsusb` 应见 `05c6:9008`
  5. `cd ~/edl-tool/bkerler-edl-1cda1a6 && python3 edl.py --loader=$L --memory=Ufs peekqword 0x81D00000`（探活）
  6. `python3 edl.py --loader=$L --memory=Ufs --skipstorageinit peek 0xFEF00000 0x100000 /tmp/p1.bin`
  7. `python3 edl.py --loader=$L --memory=Ufs --skipstorageinit peek 0x89300000 0x100000 /tmp/p2.bin`
  8. 回 Linux：`python3 edl.py --loader=$L reset`（9008 内软复位）→ 正常起 b 槽 Linux → `qbootctl -m a`（恢复 a 槽 bootable）
- **预期现象**：第 3 步不再出现 Android gadget；第 4 步 USB 换 05c6:9008；第 5/6 步见 XML ACK 与数据。
- **判据**：p1/p2 中出现 stage1/stage2 页 ⇒ **「回落覆盖」解释被排除**，marker 写入真的没执行；仍全 0 ⇒ 转向「写地址不可用/一写即复位」。
- **回退**：9008 内 `reset`；若设备不回 Linux，走 `RUNBOOK-BRINGUP` §0.5（`--set-active=b` + reboot）。
- **风险**：中。`qbootctl -u a` 是 GPT 属性写（已有先例+备份流程）；peek 只读；`oem edl` 不改任何分区。

### 方案 b：不动回落，只挑「回落也不碰」的窗口

- 思路：回落启动（XBL+Android）对 splash 尾/dsm-2 若**只清不写**，则「干净 0」与「从没写」仍不可分——方案 b 的可判定窗只剩
  **Android/XBL 都确定零填的窗**。从 §3 表看：`xbl-ramdump`（0xB8000000，崩溃转储才写）与 `dsm-partition-2` 是仅有的两个候选；
  但 XBL 是否在上电时清零 xbl-ramdump **未证**。
- **命令**：同现状（照常 `fastboot boot` + reboot 回 Linux + `scripts/blackbox.py read`），仅换 marker 目标为 0xB8000000+0x100000。
- **判据**：若窗内出现 stage1 ⇒ 回落不清该窗，且写入成功；若仍干净 0 ⇒ 与 splash/dsm 一致，问题在写入侧。
- **回退**：无（零配置改动）。**风险**：低，但**解释力弱**（仍可能被「XBL 上电清零」污染），只作并行对照。

### 方案 c：借「槽位正常启动」崩后进 fastboot 读

- 思路：载荷崩溃 → retry 耗尽 → ABL 停 fastboot（需 `misc`/retry 状态保证不落 Android）→ **不进 EDL**，
  直接 `fastboot continue` 或 `--set-active=b` + reboot 回 Linux 读窗。
- **前置备份**：同方案 a′ 第①组；另加 `boot_b` 在机件 hash（PITFALLS #147 教训：写前抓全基线）。
- **命令**：1. 照常载荷实验；2. 崩后确认 fastboot；3. `fastboot --set-active=b`（单条）；4. `fastboot reboot`（单条）；5. ssh 回来 `scripts/blackbox.py read --pa <PA>`。
- **判据**：若 retry 递减路径把我们带回 Linux（黑箱 §6.2 已验证 ~15 s），读窗有效。
- **回退**：`qbootctl -s b` + `--set-active=b`（已有流程）。
- **风险**：中——#481/#482/#147 同族风险（切槽/重试状态跨代次撞 LUN 错配）；依赖「ABL 失败后停 fastboot 而不落 a」这个**当前只在
  §6.2 被动验证过**的行为，主动依赖它比方案 a′ 多一层不确定性。**不推荐为首选，可作 a′ 的读回路径**（即 a′ 第 8 步的替代）。

## §5 风险与回退

| 动作 | 风险 | 回退 |
|---|---|---|
| `qbootctl -u a` / `-m a` | GPT 属性写；#484 跨代次 LUN 错配 | 动槽前抓 logfs seg0 + GPT 双表 + misc 备份；恢复 = `-m a` + `--set-active=b`（RUNBOOK §0.5） |
| `fastboot oem edl` | 不写分区；若 ABL 无此命令回 `unknown command`（不算异常，§2） | 物理进 EDL（关机→长按 Vol+ 插线） |
| python edl peek | 只读；最大风险 = loader secboot 门控拒绝（§1.1） | 无需回退；改走 `rawxml` 手发 `<peek>` 或判「通道不存在」 |
| 9008 `reset` | 软复位可能落 fastboot 而非 b 槽 | `--set-active=b` + `fastboot reboot`（已验证） |
| peek/poke 族误用 poke | **写物理内存** | 本轮禁止任何 poke；仅 peek。若未来用，写前先 peek 同地址留底 |

设备遗留安全态要求：实验结束必须回到「b 槽 Linux 正常起 + a 槽 bootable 恢复 + GPT/misc 与备份一致」。

## §6 未证清单

1. `xbl_s_devprg_ns.melf` 的 Supported Functions 是否含 `peek`（上机 nop 回包可证；host `check_cmd` 行为随之定）。`未证`
2. 本机 secboot 熔丝状态是否触发 loader 的 `"Peek is disabled on secure boot devices"`。`未证`（一发 peekqword 即可判）
3. `fastboot oem edl` 在**当前** ABL（设备现处 stuck-fastboot 态，ABL 与 10-03 同代）是否仍可用。`未证`
4. ABL/XBL 是否在上电路径清零 `splash_region` 尾 / `dsm-partition-2` / `xbl-ramdump`。`未证`（§4 判据就是为拆它）
5. `oem edl` 与 `continue` 的 `Device Error` 不共享失败点——机制推断，无直接证据。`未证`
6. edl-ng 能力表来自编排者 `--help` 实测回执，本 lane 未独立复核 `-u` 全 LUN 扫描行为。`未证(转述)`
