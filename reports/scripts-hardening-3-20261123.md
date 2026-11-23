# reports/scripts-hardening-3-20261123.md — 脚本整改批 3（D5：3 个未修 P0/P1 + gpt-restore fail-closed 表指纹门）

输入：`reports/scripts-audit-20261122.md` §2 抽样表（行 1/2/7/13）与 §3/§5 批 1–2 未落地项、
`out/audit/scripts-audit-20261122.tsv`、`reports/scripts-hardening-1-20261121.md`（门样式：`--expect-fingerprint`/`--force`/`--apply`）、
`-2-20261121.md`（#701 门 + 假命令用例表口径）、`PITFALLS` #584 / #699 / #701。

性质：**主机侧静态 + 假命令验证；零设备接触**（未跑 ssh/fastboot/adb/qdl；所有 ssh/fastboot 调用都被 `PATH` 前置的 dummy 拦下）。
**未 git commit**（派工单明令）。工作树改动只在本批 4 个脚本 + 本报告。

---

## §0 结论数字（先行）

| 项 | 数字 | 判据 |
|---|---|---|
| 改动文件 | **4 个脚本**（`ath12k-load.sh` / `arm-console-run.sh` / `q28-por-rounds.sh` / `gpt-restore-tb322fc.py`） | `git status` 仅这 4 个 `M` + 本报告 |
| 改动量 | **+245 −41 行 / +13 693 B**（逐文件见 §1 表） | `git diff --numstat` |
| 用例 | **17/17 PASS = 11 反例（必须被拒）+ 6 正例（必须放行）** | `bash /tmp/verify-b3.sh` → `== 汇总：PASS=17 FAIL=0 ==` |
| 附加断言 | **23/23 PASS**（内容级：写入的是设备名、stderr 未吞、§device 5 条 dd、反例零产出件等） | 同上日志 `^      PASS` 23 行 |
| `bash -n` / `sh -n` | `bash -n` **3/3 OK**（arm/q28 + ath12k 也能过 bash -n）、`sh -n ath12k-load.sh` **OK** | 见 §4 |
| `py_compile` | **OK** | `python3 -m py_compile scripts/gpt-restore-tb322fc.py` |
| 残留门文案 `grep -c` | `table-gate\|表指纹门` **7**（gpt）/ `INVALID-PROBE` **4**（q28）/ `q28-devprobe2` **3**（含 v1 仅剩 1 处注释）/ `#584` **1**（arm，纯注释）/ `判据：` **1**（ath12k） | §4 |
| #584 模式残留（4 个目标文件） | **0 实代码 + 0 注释命中** | `grep -cE '(fastboot\|adb)[^\|]*\|[[:space:]]*(grep\|head\|wc)'` = 0/0/0 |
| #584 模式残留（全 `scripts/*.sh`） | **17 处 / 12 文件**，全部在本批写域之外 | §3 未做项 1 |

**结论：PASS**（3 个未修 P0/P1 全部落地；gpt-restore 表指纹门 fail-closed，反例零产出件、零 dd 行）。

---

## §1 before → after（逐文件）

| 文件 | 字节 | 行 | 改动要点 |
|---|---|---|---|
| `scripts/ath12k-load.sh` | 2232 → 3330（+1098） | +20 −6 | bind 写**设备名**、去掉 `2>/dev/null`、写失败即带判据 `exit 1`；顺带不吞 modprobe stderr |
| `scripts/arm-console-run.sh` | 2157 → 3234（+1077） | +24 −8 | `fastboot devices \| grep -q .` → 取值式门（127/124/无设备三分支）；`grep -c …\|\| echo 0` 污染 verdict 的相邻 bug |
| `scripts/q28-por-rounds.sh` | 6285 → 7633（+1348） | +22 −7 | 喂 v2 取样器 + `l1=/l2=` 字段门 + `VERDICT` 取值式（含 `GOOD-NOSESSION`）+ 无效样本不入 trial 表 |
| `scripts/gpt-restore-tb322fc.py` | 11344 → 21514（+10170） | +179 −20 | **TB322FC 表指纹门**（分区名/大小/数量）+ `--force` 旁路 + 设备侧 dd 步骤移出门后打印（含写前读回门） |

### 1.1 `ath12k-load.sh`（P0 原样，审计 §2 行 1）

**Before**（`$DEV` = `/sys/bus/pci/devices/0000:01:00.0`，bind 只吃设备名 ⇒ EINVAL 被 `2>/dev/null` 吞掉）：

```sh
	if [ ! -e "$DEV/driver" ]; then
		echo "$DEV" > "$DRV/bind" 2>/dev/null && log "re-bound $DEV (try $i)"
	fi
```

**After**：

```sh
DEVNAME=$(basename "$DEV")          # bind 收设备名（PCI 地址），不是路径
...
		if err=$(printf '%s' "$DEVNAME" > "$DRV/bind" 2>&1); then
			log "re-bound $DEVNAME (try $i)"
		else
			log "bind 写入失败：$DRV/bind <= \"$DEVNAME\"（stderr：${err:-<空>}）"
			log "判据：ls -l $DRV 应见 $DEVNAME 软链；ls $DEV/driver 应存在；dmesg | grep -i ath12k 应无 probe 失败"
			log "常见原因：设备名写成路径（旧 bug）/ 已被其它驱动占用 / 固件缺失（/lib/firmware/ath12k/PEACH/hw2.0/）"
			exit 1
		fi
```

- 退役门（批 1 的 `ATH12K_LOAD_ALLOW=1`，rc=2）**保留**；头注与门文案同步改成「已就地修掉 bind 写法，退役决定不变」——否则门里的理由会变成假话。
- 语义偏离披露：`ath12k-retry.sh`（真源）失败后继续重试，这里**写失败即停**（派工单要求「失败非零退出并打印判据」；该脚本 0 调用点、已退役，失败 60×5 s 空转才是原 P0 的症状）。

### 1.2 `arm-console-run.sh:14`（P0 #584 SIGPIPE）

**Before**：

```bash
if ! fastboot devices 2>/dev/null | grep -q .; then
	echo "[arm] ❌ 设备不在 fastboot（需要物理 POR / Vol-+Power）" >&2; exit 2
fi
timeout -k 2 10 fastboot devices | tee "$OUT/fastboot-before.txt"
```

**After**（取值式 + 三分支 + 一次调用两用）：

```bash
FB_OUT=$(timeout -k 5 10 fastboot devices 2>&1); FB_RC=$?
case "$FB_OUT" in
*fastboot*) : ;;
*)
	case "$FB_RC" in
	127) echo "[arm] ❌ 宿主机找不到 fastboot（#699：在 ~/.local/opt/platform-tools/fastboot）" >&2 ;;
	124) echo "[arm] ❌ fastboot devices 超时（10 s）——USB/bulk 通道卡住，先物理 POR 再试" >&2 ;;
	*)   echo "[arm] ❌ 设备不在 fastboot（需要物理 POR / Vol-+Power）" >&2 ;;
	esac
	printf 'rc=%s raw=%s\n' "$FB_RC" "${FB_OUT:-<空>}" >&2
	exit 2 ;;
esac
printf '%s\n' "$FB_OUT" > "$OUT/fastboot-before.txt"
```

- 顺带修同文件相邻 bug（同一类文本处理）：`L1=$(grep -Ec … || echo 0)` 在无命中时得到 `"0\n0"`，使 `[ "$L1" -gt 0 ]` 报「需要整数」且 `verdict.txt` 写出 `L1=0⏎0`（判据被污染）。改为 `… ; [ -n "$L1" ] || L1=0`。

### 1.3 `q28-por-rounds.sh:99`（P1）

**Before**（v1 取样器，`storm_sig` 把 L1/L2 混计 ⇒ POR 轮次判据失真；`VERDICT` 取值还走 `grep -oE … | head -1`）：

```bash
	$SSH "$T" 'sh -s' < "$ROOT/scripts/q28-devprobe.sh" > "$LOGDIR/probe.txt" 2>&1
	VERDICT=$(grep -oE 'VERDICT=[A-Z]+' "$LOGDIR/probe.txt" | head -1 | cut -d= -f2)
	[ -n "$VERDICT" ] || VERDICT=UNKNOWN
```

**After**：

```bash
	$SSH "$T" 'sh -s' < "$ROOT/scripts/q28-devprobe2.sh" > "$LOGDIR/probe.txt" 2>&1
	if ! grep -qE 'l1=[0-9]+' "$LOGDIR/probe.txt" … || ! grep -qE 'l2=[0-9]+' …; then
		VERDICT=INVALID-PROBE        # 字段门：取样器没跑起来 ⇒ 本发不算样本
	else
		VERDICT=$(awk 'match($0,/VERDICT=[A-Z][A-Z-]*/){print substr($0,RSTART+8,RLENGTH-8); exit}' "$LOGDIR/probe.txt")
	fi
	L1=$(awk 'match($0,/l1=[0-9]+/){print substr($0,RSTART+3,RLENGTH-3); exit}' "$LOGDIR/probe.txt")
	L2=$(awk 'match($0,/l2=[0-9]+/){print substr($0,RSTART+3,RLENGTH-3); exit}' "$LOGDIR/probe.txt")
```

- `INVALID-PROBE` 的发**不写 trial 表**（否则坏样本照样污染 `reports/trials`），原始件留在 `$LOGDIR`。
- 判据修：旧式 `[A-Z]+` 把 v2 的 `VERDICT=GOOD-NOSESSION` 截成 `GOOD`（实测见 §2 用例）；`[A-Z-]+` 保留完整值。
- 汇总循环里同类的 `grep … | head -1 | cut -d=` 一并换成单进程 `awk`（#584 同类管道写法）。
- ⚠ 口径说明：派工单写「:99 同样处理 #584 模式或 #701 的无效路径」，但 `:99` 的实际缺陷是**审计 §2 行 7 / §5 批 2 第 7 条**的 v1 取样器（本文件没有 `fastboot|grep`，也没有 `reboot2` 实代码——它本来就是「用户物理断电」口径，天然符合 #701）。故按审计 P1 落地，并把同文件里真正存在的 #584 同类管道（`| head -1`）一并改掉。

### 1.4 `gpt-restore-tb322fc.py`（新增 fail-closed 表指纹门）

**Before**：批 1 只锁了「输入件 sha256」（`--expect-fingerprint`），**表本身像不像 TB322FC 不检**；docstring 里内嵌可复制的设备侧 dd 配方（删 linux 分区），等于绕过门直接照抄。

**After**（三道结构 + 指纹常量 + `--force`）：

```python
TB_NENTS, TB_ENDSZ, TB_ENT_LBA, TB_FIRST_USABLE = 32, 128, 2, 6
TB_USERDATA_FIRST = 5972392
TB_N_USED = 17          # 15 stock + userdata + 尾部 linux*（现机叫 linux17）
TB_CORE = ((0,"proinfo",6,773), … (14,"pstoredump",5939624,5972391))   # 名字/起始/大小/序号全锁
TB_CORE_FP = "4d00c64e28cb37b4…dc1d4"
TB_LAST_USABLE = {123871226: "512 GB（现机 HA2EXB0E 16+512）", 61390842: "256 GB/234 GiB 旧布局（未复核）"}
```

门判据（`tb322fc_table_gate()`，任一条不过 ⇒ 无 `--force` 就 `sys.exit` 且**不出镜像**）：

1. 几何：`nents/entsz/ent_lba/first_usable` 逐项等于期望；`last_usable` ∈ 已知容量集合；
2. **核心 15 条指纹**：名字/序号/`first..last`（=大小）算 `core_fp`，必须等于 `TB_CORE_FP`（差异逐条列出「期望 → 实算」）；
3. **数量**：在用条目数 = 17；`userdata.first` = 5972392；
4. 尾部关系：`userdata` 之后**恰有 1 条**待删分区、起点 `= userdata.last+1`、终点 = `last_usable`；
5. `--linux-name` 若点名，必须就是那条尾部（防「删中间某条」）。

指纹**不含 A/B 属性字节**（`tries_remaining`/`successful` 每次开机被 ABL 改写，含进去会把好表判死）——这是与批 1「整件 sha256」刻意分层的地方。

设备侧 dd 步骤**从 docstring 移到 `print_device_procedure()`**：只有两道门都过的 build 才打印，且新增强制**写前读回门**（现表 sha256 必须 == 本次输入主表 sha256，否则镜像作废）：

```
  ① 写前门（必须先过；不过就停手 —— 现表已与本次输入不同，镜像作废）：
     dd if=/dev/block/sda bs=4096 count=6 | sha256sum
     必须 == 6766acbdc38a513a…9917f3
  ② 写（删 linux 分区 + userdata 扩回 last_usable）：  … seek=0 / seek=123871227 …
  ③ 写后读回（两发都必须与产出件 sha256 一致，否则立即停手报障，不要再重启）
```

- `--linux-name` 默认由 `"linux"` 改为 **None = 自动取 userdata 之后那条**：本机现表叫 `linux17`，旧默认在本机**永远** `assert linux partition not found`（实测：拿 11-20 真机表 dump 直接 rc=1）——顺手修掉。
- 输入件指纹门（`--expect-fingerprint`，批 1）**保留且在表门之前**，两门互不代替；`--force` 只旁路表门，**不**旁路 sha256 门。

---

## §2 用例表（11 反 + 6 正，全过）

| # | 文件 | 用例 | 期望 | 实测 |
|---|---|---|---|---|
| 1 | ath12k | **反** bind 不可写（fake sysfs 树，dir 只读） | rc=1 + 判据三行 | rc=1，打印 `判据：ls -l …` ✔ |
| 2 | ath12k | **反** 不带 `ATH12K_LOAD_ALLOW` | rc=2（退役门） | rc=2 ✔ |
| 3 | ath12k | **正** bind 可写 | 写入内容 = `0000:01:00.0`，日志 `re-bound 0000:01:00.0` | `bind 内容='0000:01:00.0'` ✔（旧代码写的是整条路径） |
| 4 | arm | **反** `fastboot devices` 空输出 | rc=2「不在 fastboot」 | rc=2 ✔ |
| 5 | arm | **反** 宿主无 fastboot（PATH 无该二进制） | rc=2 且点名 #699 | rc=2 `raw=timeout: failed to execute process…` ✔ |
| 6 | arm | **反** `fastboot devices` 挂住 12 s | rc=2 且判据 124 | rc=2 ✔ |
| 7 | arm | **正** 已在 fastboot | rc=0，门不误拦，`fastboot-before.txt` 由同一发写落 | rc=0，文件含 `HA2EXB0E	fastboot`，`verdict.txt` = `L1=0 L2=0 panel_prepared=0` ✔ |
| 8 | q28 | **反** 取样器输出无 `l1=/l2=`（v1 形态夹具） | 判 `INVALID-PROBE` 且 **trial json 数不变** | INVALID-PROBE，json 1→1 ✔ |
| 9 | q28 | **正** v2 取样器（假 ssh 把管道脚本本地跑） | 打印 `VERDICT=… L1=0 L2=0`，trial 落 1 条 | `[POR] VERDICT=NOCARD  L1=0 L2=0`，json=1 ✔ |
| 10 | q28 | 判据解析 `VERDICT=GOOD-NOSESSION` | 旧=GOOD / 新=完整 | 旧 `GOOD`（丢后缀）/ 新 `GOOD-NOSESSION` ✔ |
| 11 | gpt | **正** 真机 11-20 LUN0 表对（`backup/HA2EXB0E-16+512/edl-20261120-2235/gpt0-{primary,backup}.bin`） | rc=0、表门通过、打印 §device 5 条 dd | rc=0，`core_fp=4d00c64e…`，5 条 dd ✔ |
| 12 | gpt | **反** `metadata` 大小 +1（CRC 自洽的合成表） | rc≠0、零 dd 行、零产出件 | rc=1，`12:metadata:5857704-5874087 → …-5874088` ✔ |
| 13 | gpt | **反** 尾部 linux 被删（16 条在用） | rc≠0 | rc=1（数量 16≠17 + 尾部 0 条）✔ |
| 14 | gpt | **反** 拿 **LUN4** 表当 LUN0 | rc≠0 | rc=1（nents 96≠32、last_usable 1048570 不在集合、核心 15 条全缺）✔ |
| 15 | gpt | **反** `--linux-name userdata`（点名非尾部） | rc≠0 | rc=1 ✔ |
| 16 | gpt | **反** 缺 `--expect-fingerprint`（批 1 门回归） | rc≠0 | rc=1 ✔ |
| 17 | gpt | **正** 尾部改名 `linux17→linux`（几何不变） | 放行（门不咬尾巴名字） | rc=0，`linux : idx 16 … -> REMOVED` ✔ |
| 18 | gpt | **正** `--force` 旁路被改表 | rc=0 且先打印全部偏差 | rc=0，产出件 1 份，日志含 `[force] WARN` ✔ |

正例 11 的实跑原文（摘）：

```
[fingerprint] main=6766acbdc38a513a… backup=081d63804492f922… 与 --expect-fingerprint 一致
[table-gate] TB322FC 表指纹通过：核心 15 条名字/大小/序号一致，在用 17 条，last_usable=123871226（512 GB（现机 HA2EXB0E 16+512））
[table-gate] 表指纹 2a1f7dd0b05093f9…03bfba（核心指纹 4d00c64e28cb37b4…dc1d4）
userdata: 5972392..73277434 (256.7 GiB)   linux: idx 16 73277435..123871226 -> REMOVED
wrote ok_main0.bin (24576 B), ok_backup0.bin (20480 B); self-check OK; backup write offset = 123871227
```

反例 12 的原文（摘）：

```
FAIL: 目标盘分区表**不符 TB322FC 期望**（fail-closed 表指纹门）
  核心指纹 期望 4d00c64e…dc1d4   实算 8f47df31…dbef
  偏差：
    - 核心分区起始/大小不符（期望 → 实算）：12:metadata:5857704-5874087 → 12:metadata:5857704-5874088
  确认真要在非 TB322FC 期望表上跑：加 --force（后果自负）        rc=1，dd 行 0，无产出件
```

---

## §3 未做项与原因

1. **`scripts/` 其余 17 处 #584 模式未动**（12 文件：`android-ksu-flash.sh`、`android-slim-v2-plan.sh`、`uefi-ddr-trial.sh`、`android-v3-bringup-walkthrough.sh`、`sleep-sweep.sh`、`lib-wait.sh`、`arm-window-hunt.sh`、`bl-unlock.sh`、`trial.sh`、`linux-state-audit.sh`、`t2-stock-lun45.sh` …）——写域只有本批 4 个文件；其中 `trial.sh:252 fastboot getvar … | head -1`、`lib-wait.sh` 是「库/编排层」，动它们会牵到批 2 的 #701 门，需要单独一轮 + 真机窗口复核。建议下一轮把该模式做成 `gen-scripts-index` 同级静态检查项。
2. **`arm-console-run.sh` 未接 `lib-hosttools.sh`**（#699 通则）：本批只做到「127 分支点名正确路径」，没做 `hosttool_resolve` 前置 PATH。原因 = 会引入 source 依赖与 `FB_BIN` 全量替换（超出「最小改」且要重测 `fastboot boot` 分支）。
3. **未在真机上跑任何一条**：零设备接触是硬约束；`ath12k`/`arm`/`q28` 的门只由假命令覆盖，`gpt` 表门只由真机 dump（只读）与合成表覆盖。**未证实**：真机 `bind` 写入成功路径（EINVAL 已按 NOTE 修，但「写设备名就一定能绑上」需要一次 ath12k 窗口）、`q28` v2 在真机冷起上的 `L1=/L2=` 分布。
4. **`last_usable=61390842`（256 GB / 234 GiB 旧布局）只按 2026-10 记录列入期望集合**，未取得对应 dump 复核 ⇒ 该容量下核心 15 条几何是否与 512 GB 件一致未证实（若不一致，门会拒并要求 `--force`——方向安全）。
5. **`gpt-restore` 产物里没有烧进表指纹戳**（只在打印与 `entries_crc` 里可见）；要「镜像自带门印」得改产物格式/加旁注文件，属职责扩张，未做。反例/正例的分辨靠 build 日志（本批已把全表指纹打进日志）。
6. **未 `git commit`**（派工单明令）；未碰 `build/`、`out/`、`TASKS/`、`PITFALLS/`、其他 `reports/`；未改 `scripts/README.md`（索引计数刷新属索引 owner）。
7. **审计报告/TSV 未回写**：本批后 `reports/scripts-audit-20261122.md` 的「3 个未修 P0/P1」应改为 0，建议由总管在合并 lane 时统一改（非本批写域）。

---

## §4 Verify（可复跑，全主机侧）

```bash
cd /home/xuqianhui/y700-elden
# 0) 一键：17 用例 + 23 断言（本会话内脚本，全部 fake，零设备）
bash /tmp/verify-b3.sh        # → == 汇总：PASS=17 FAIL=0 ==

# 1) 语法
sh   -n scripts/ath12k-load.sh
bash -n scripts/arm-console-run.sh
bash -n scripts/q28-por-rounds.sh
python3 -m py_compile scripts/gpt-restore-tb322fc.py

# 2) 残留门文案计数
grep -c 'table-gate\|表指纹门' scripts/gpt-restore-tb322fc.py          # 7
grep -c 'INVALID-PROBE' scripts/q28-por-rounds.sh                      # 4
grep -c 'q28-devprobe2' scripts/q28-por-rounds.sh                      # 3（v1 仅剩 1 处注释）
grep -c '#584' scripts/arm-console-run.sh                              # 1（注释）
grep -c '判据：' scripts/ath12k-load.sh                                 # 1
grep -cE '(fastboot|adb)[^|]*\|[[:space:]]*(grep|head|wc)' \
        scripts/ath12k-load.sh scripts/arm-console-run.sh scripts/q28-por-rounds.sh   # 0/0/0

# 3) gpt 表门（真机 dump 只读 + 出厂即用的两发：正例 / 反例各一）
D=backup/HA2EXB0E-16+512/edl-20261120-2235   # 11-20 EDL 只读 dump（本机已有）
FP="$(sha256sum $D/gpt0-primary.bin | cut -d' ' -f1),$(sha256sum $D/gpt0-backup.bin | cut -d' ' -f1)"
python3 scripts/gpt-restore-tb322fc.py build --main $D/gpt0-primary.bin --backup $D/gpt0-backup.bin \
        --out-prefix /tmp/gpt3/ok --expect-fingerprint "$FP"            # rc=0 + §device 5 条 dd
python3 scripts/gpt-restore-tb322fc.py build --main $D/gpt4-primary.bin --backup $D/gpt4-backup.bin \
        --out-prefix /tmp/gpt3/L4 \
        --expect-fingerprint "$(sha256sum $D/gpt4-primary.bin|cut -d' ' -f1),$(sha256sum $D/gpt4-backup.bin|cut -d' ' -f1)"
                                                                        # rc=1（LUN4 表不是 LUN0），dd 行 0

# 4) arm #584 门（三个 dummy fastboot：空输出 / 缺席 / 挂住；一个在 fastboot）
mkdir -p /tmp/fk-arm/{p_none,p_present,p_hang} /tmp/arm-t/scripts
cp scripts/arm-console-run.sh /tmp/arm-t/scripts/; printf 'FAKE-IMG\n' > /tmp/fake.img
printf '#!/bin/sh\nexit 0\n' > /tmp/fk-arm/p_none/fastboot
printf '#!/bin/sh\nif [ "${1:-}" = devices ]; then printf "HA2EXB0E\\tfastboot\\n"; else echo OKAY; fi\nexit 0\n' > /tmp/fk-arm/p_present/fastboot
printf '#!/bin/sh\nsleep 12\n' > /tmp/fk-arm/p_hang/fastboot
chmod +x /tmp/fk-arm/p_*/fastboot
cd /tmp/arm-t
PATH=/tmp/fk-arm/p_none:/usr/bin:/bin     TTY=/dev/null bash scripts/arm-console-run.sh /tmp/fake.img n1 0  # rc=2
PATH=/usr/bin:/bin                        TTY=/dev/null bash scripts/arm-console-run.sh /tmp/fake.img n2 0  # rc=2 + #699
PATH=/tmp/fk-arm/p_hang:/usr/bin:/bin     TTY=/dev/null bash scripts/arm-console-run.sh /tmp/fake.img n3 0  # rc=2 + 124
PATH=/tmp/fk-arm/p_present:/usr/bin:/bin  TTY=/dev/null bash scripts/arm-console-run.sh /tmp/fake.img p1 0  # rc=0
```

`q28` 的端到端复跑需要假 `ssh`（它会写 `reports/artifacts/`，故本批在 `/tmp/q28t` 的脚本副本里跑，见 `/tmp/verify-b3.sh` §4 段；dummy ssh 只认
`boot_id` / `proc/uptime` / `q28-clkdiag` / `q32-boot` / `uname` / `dmesg` / `bash -s` / `sh -s` 七条命令）。

---

## §5 边界

- 本轮**零设备接触**：无 ssh/fastboot/adb/qdl 真调用（`which -a ssh` 仍有真件，但每个用例都 `PATH=` 前置 dummy；`command -v fastboot` 命中的系统件也全被 dummy 覆盖）。
- 夹具与日志全在 `/tmp`（`/tmp/ath-t`、`/tmp/arm-t`、`/tmp/q28t`、`/tmp/gpt3`、`/tmp/fk*`、`/tmp/verify-b3.sh`），不进仓。
- 工作树：`scripts/` 4 个 `M` + 本报告；`INDEX.md`/`TASKS/README.md`/`reports/README.md`/`patches/distro/` 的改动属并行 lane（C/D/E），本批未碰。
