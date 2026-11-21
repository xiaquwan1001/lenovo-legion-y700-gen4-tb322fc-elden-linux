# a 槽 S2/S3 一页执行单（2026-11-21，self-contained）

> 用户/父代理照着敲即可。**总预算：A 线（新主推）≈ 25–40 min；B 线（原计划的 S2+S3）≈ 35–50 min。**
> 依据：`reports/android-a-slot-mech-rejudge-20261121.md`（机制重判）、`reports/android-a-slot-materials-20261121.md`（材料/现态）。
> 脚本：`scripts/android-v3-bringup-walkthrough.sh`（本轮已按 fail-closed 修过，见机制重判 §7）。
>
> **状态标注口径**：`[已验证]` = 本 lane 在只读侧真跑过或语法/参数校验过；`[未验证]` = 学上机才知道；
> `[人项]` = 物理键/插拔/断电，**只能由用户做**。

### ★ 两条必须用户做的（人项）

1. **A1：物理键进 fastboot** —— 长按电源 10 s 断电 → 按住【音量上 + 电源】到 fastboot 屏。
   （软路径三条已实测全灭：`reports/linux-to-fastboot-20261121.md`、`PITFALLS #690/#701`。）
2. **A5 选项①（若走）在 stock recovery 屏上选 *Wipe data/factory reset*** —— 屏上按键只能人来；
   以及**收尾回 Linux 时再进一次 fastboot**（同样物理键）。其余命令全部 agent 可跑。

---

## 0. 先读这四条（决定要不要跑 B 线）

1. **在机 super = v1**（head512k `67ff7604…`）、**a 槽启动链 6/7 件与原厂逐字节相同**、**S2 已在 11-20 20:26 跑过且是 no-op**
   ⇒ 原计划的「S2 → S3（原厂 super 对照）」**不是当前失败的分辨实验**（它判的是「我们的 v1 vs 原厂」）。
2. 现有唯一有效样本（11-21 09:17，n=1）显示：**Android 的 init 挂过 `/metadata`，但 `/data` 从未被挂载**
   （`s_mnt_count=0`），且无内核 panic ⇒ 失败点在 **init 的 `/metadata` → `/data`** 之间。
3. `/data` 是**主机 e2fsprogs 风格的空 ext4（无 `encrypt` 特性）**、`/metadata` 是**空 f2fs（无 vold key）**；
   而那个 ext4 的 mkfs 时间正好 = 11-19 21:16（`fastboot -w` 那一分钟）⇒ **重复 `fastboot -w` 很可能只是复现现态**。
4. ⇒ **先跑 A 线的「零写取证」**（只切槽 + 启一发，在 recovery 里 `exec-out` 抓 `/proc/cmdline` + logfs + `/tmp/recovery.log`）：
   它一刀分开「ABL/BCB 面」vs「userspace（主要是 /data）面」；分叉之后再花时间做 `/data` 处置或 B 线。

---

## A 线（新主推，≈ 25–40 min）：只切槽 + 启一发 + recovery 当场取证 → 再按分叉处置

### A0. 只读前置（主机，2 min）`[已验证]`

```sh
cd /home/xuqianhui/y700-elden
. scripts/lib-hosttools.sh && ensure_hosttools --quiet      # 本机 fastboot 不在 PATH（PITFALLS #699）
timeout 15 "$FB_BIN" devices                                 # 期望：HA2EXB0E	fastboot（否则先做 A1）
timeout 20 ssh -o BatchMode=yes elden-root 'uname -r; qbootctl -a'   # 期望：vk189…/ Active slot: _b
timeout 60 ssh -o BatchMode=yes elden-root 'dd if=/dev/disk/by-partlabel/super bs=4096 count=128 iflag=direct 2>/dev/null' \
  | sha256sum
# 判据：必须是 67ff7604e59f5b70343846572f492d1d0b405a914fda9e4d86a1982affc47479（= v1 在机）
#       若是 c6278f8e…（v3）或 12c35980…（原厂）⇒ 先别往下走，回报现状
```

### A1. `[人项]` 进 fastboot（约 1–2 min）

> **软路径全灭**（`reports/linux-to-fastboot-20261121.md`：PSCI 无钩子 / BCB `bootonce-bootloader` ABL 不采纳 / `qbootctl -u` 写失败）。

1. 长按电源 **10 s** 直到黑屏断电；
2. 按住 **音量上 + 电源** 至出现 fastboot/引导屏；
3. 主机确认：`timeout 15 "$FB_BIN" devices` → **`HA2EXB0E	fastboot`**。

**失败处置**：25 s 内仍空 ⇒ 停手，不反复试（`PITFALLS #690/#701`），请用户再来一次。

### A2. fastboot 侧：清 BCB、复位 `boot_a` 属性、置 active=a（3 min）`[已验证语法与参数；真跑=本次窗口首次]`

```sh
S=HA2EXB0E; FB="$FB_BIN"
timeout 20 "$FB" -s $S getvar current-slot                  # 记下现值
head -c 4096 /dev/zero > /tmp/zero4k.bin
timeout 60 "$FB" -s $S flash misc /tmp/zero4k.bin           # 判据：OKAY（ABL 只认 misc 头 4 KiB）
timeout 30 "$FB" -s $S --set-active=a                       # 判据：OKAY；ABL 会同时补 retry=7 并清 UNBOOTABLE（PITFALLS #677）
timeout 20 "$FB" -s $S getvar current-slot                  # 判据：a
timeout 20 "$FB" -s $S getvar slot-unbootable:a             # 判据：no
timeout 20 "$FB" -s $S getvar slot-retry-count:a            # 判据：≥6
```

**判据不满足就停**（不要 reboot）：`current-slot` 仍 `b` ⇒ `--set-active=a` 没生效（记下输出回报）。
**回退**：`timeout 30 "$FB" -s $S --set-active=b`（super/userdata 零改动）。

### A3. 【零写】启 a 槽并观察（10–20 min，含取证）

```sh
timeout 30 "$FB" -s $S reboot
# 观察（与脚本同口径）：每 10 s 采一次状态，最多 600 s
for i in $(seq 1 60); do
  st=$(timeout 10 adb devices 2>/dev/null | awk -v s=$S '$1==s{print $2}')
  echo "[$(date +%T)] adb=$st"
  case "$st" in
    device)   break ;;
    recovery) echo "★落 recovery ⇒ 立刻做 A4（**不要重启**）"; break ;;
  esac
  timeout 10 ssh -o BatchMode=yes -o ConnectTimeout=5 elden-root 'true' 2>/dev/null && { echo "落回 Linux(b)"; break; }
  sleep 10
done
```

**判据（三条缺一不算成功）**：
```sh
timeout 20 adb -s $S shell getprop sys.boot_completed                                   # ① 1
timeout 20 adb -s $S shell 'dumpsys window | grep -m2 -E "mCurrentFocus|EnableScreen"'  # ② 含 launcher
timeout 10 adb -s $S devices | awk '{print $2}'                                         # ③ 不是 recovery
```
**首发若很慢别急**：Android 首启可能要格式化 256 GiB `/data` 并建 FBE key；`logcat -d` 里 `vold`/`fs_mgr`/`keystore`
的行是判「在格式化」还是「卡死」的直接依据。落 `recovery` 就先做 A4，再谈 A5。

### A4. 【必须】若落 recovery：**当场取证**（1 min，只读）`[已验证命令形状；`adb exec-out` 是唯一可用通道]`

> logfs 只保留最近一次启动（64 KiB），**一重启就没了**；本机 recovery 里 `adb shell` 会
> `SIGABRT (shell_service.cpp:380 Could not set SELinux context for subprocess)`，**只能用 `exec-out`**。

```sh
D=logs/android-a-slot-recovery-$(date +%Y%m%d-%H%M%S); mkdir -p $D
timeout 30 adb -s $S exec-out 'cat /proc/cmdline'                              > $D/cmdline.txt
timeout 60 adb -s $S exec-out 'dd if=/dev/block/by-name/logfs bs=4096 count=16' > $D/logfs-live.bin
timeout 30 adb -s $S exec-out 'cat /tmp/recovery.log'                          > $D/recovery.log
timeout 30 adb -s $S exec-out 'getprop | grep -E "^\[ro.boot\."'               > $D/props.txt
strings -n 6 $D/logfs-live.bin | grep -aE 'UEFI Ver|Booting Into|Booting from slot|Boot lun|Recovery:|Fastboot=|Loaded Partition'
grep -o 'force_normal_boot=[01]' $D/cmdline.txt || echo "cmdline 里没有 force_normal_boot"
```

**判读（决定性）**：
- `force_normal_boot=0` **或** logfs 里 `Booting Into Recovery…` ⇒ **ABL/BCB 面**（不是 /data 问题）⇒ 转 B 线并查 `misc` 全 1 MiB。
- 否则（`=1` 或无该键）⇒ **userspace 面**；再看 `recovery.log` 是否出现
  `--prompt_and_wipe_data` / `Can't load Android system` / `fs_mgr` / `vold` 字样 ⇒ 就是 `/data` 挂不上（H6）。
- 然后把 `$D` 目录路径回报（脚本同名分支已自动化同一套动作）。

### A5. 若 A4 判为「userspace 面」（大概率）：`/data` 处置三选一（按代价）

> 前提：`/data` 现在是主机 e2fsprogs 风格的空 ext4（无 `encrypt`），`/metadata` 是空 f2fs。
> **目标不是「擦掉」而是「让 Android 自己格式化」**（`make_f2fs`/`mke2fs -O encrypt` + 在 `/metadata` 建 FBE key）。

| 选 | 命令 | 代价 | 预期 | 回退 |
|---|---|---|---|---|
| ① **stock recovery 擦 data（推荐）** | `timeout 300 "$FB" -s $S boot backup/official-rom-15.10.259/recovery.img`（**零写盘**）→ 屏上选 *Wipe data/factory reset* `[人项]` | 5–10 min + 按键 | Android 原生格式化（f2fs/FBE + key），最接近出厂态 | 不必回退（擦后仍是可重建态）；不刷任何分区 |
| ② `fastboot -w` | `timeout 900 "$FB" -s $S -w` | 3–10 min | **可能只是复现现态**（那个 ext4 很可能就是它的产物，**未验证**） | 无（本来就是空件） |
| ③ 裸擦（不格式化） | `timeout 120 "$FB" -s $S erase metadata` 然后 `erase userdata`（若它仍去 host-format，则退回 ②） | 2–5 min | 留零区域，逼 Android 首启自建 | 无 |

每一条之后都重跑 **A3（启 + 观察）+ A4（recovery 取证）**，并且**只在拿到 `/tmp/recovery.log` 或 `logcat` 之后**才下结论。
**全程零改动**：`super`/`boot_*`/`vbmeta_*`/`linux17` 一律不写。

### A6. 收尾（设备留在可用态）

```sh
# 若 A 线成功：保持 active=a（Android）。要回 Linux：
#   在 Android 里 adb reboot bootloader → 下一行；或直接物理键进 fastboot
timeout 30 "$FB" -s $S --set-active=b && timeout 30 "$FB" -s $S reboot
# 回 Linux 后只读复核
timeout 20 ssh -o BatchMode=yes elden-root 'qbootctl; qbootctl -a; grep -E "sda1[0-9]" /proc/mounts'
```

---

## B 线（原计划 S2 → S3，≈ 35–50 min；**只在 A 线失败或要判「v1 vs 原厂」时跑**）

> 前提：设备在 **fastboot** 且 `current-slot: a`（A2 已做）。**S2 可跳过**（11-20 20:26 已跑，写前=写后=原厂件）。
> 机械形态：`bash scripts/android-v3-bringup-walkthrough.sh --apply --step S2`/`S3`（本轮已加
> `require_active_a` + `observe` 返回值判据 + recovery 取证；`--dry-run` 可先看全量命令）。

### B1. S2（原厂 metadata 28 MiB，≈ 5–8 min；**预期 no-op**）

```sh
QDL="$HOME/edl/qdl/build/qdl"; L="$HOME/下载/tb322fc/xbl_s_devprg_ns.melf"; S=HA2EXB0E; FB="$FB_BIN"
timeout 60 "$FB" -s $S oem edl && sleep 3 && lsusb -d 05c6:9008        # 判据：9008 枚举
timeout 120 "$QDL" -s ufs -R "$L" read 0/0+6 /tmp/gpt0.bin
python3 scripts/android-linux-coexist-check.py --gpt /tmp/gpt0.bin      # 判据：gate super/metadata OK
timeout 120 "$QDL" -s ufs -R "$L" read 0/5857704+7171 /tmp/metadata-pre.bin
sha256sum /tmp/metadata-pre.bin
#   判据：若 = a735fbc7…（原厂件）⇒ 与在机相同，可**跳过写**（no-op）；不同才继续写
timeout 1800 "$QDL" -s ufs -R "$L" write 0/5857704 \
    out/android-v3-bringup-20261120/metadata_stock.img sha256 0/5857704+7171 \
    read 0/5857704+4096 /tmp/rb-head.bin read 0/5860779+4096 /tmp/rb-tail.bin
#   判据：设备端 sha = a735fbc7…；head/tail 与件 cmp 一致
timeout 120 "$QDL" -s ufs -R "$L" write 0/89992 /tmp/zero4k.bin read 0/89992+1 /tmp/bcb-after.bin
#   判据：/tmp/bcb-after.bin 全 0
timeout 120 "$QDL" -s ufs "$L" reset        # 注意：reset 单独一发，不带 -R（PITFALLS #674/#675）
```

**失败处置**：`SAHARA: failed to read request` ⇒ 上一条 qdl 漏了 `-R`（不是件坏）；
sha 不符 ⇒ 先怀疑主机读路径（`scripts/odirect-sha.py` / `pcache-wash`），再怀疑设备；
BCB 读回非 0 ⇒ **不要 reset**。
**回退**：`timeout 1800 "$QDL" -s ufs -R "$L" write 0/5857704 /tmp/metadata-pre.bin`（写前已 dump）。

### B2. S3（原厂 super 14.54 GiB，≈ 14–18 min）

```sh
# ① 拼装（主机，约 2–4 min；稀疏落盘 ~12.2 GiB；工作区余 188 GiB）
timeout 900 python3 scripts/android-super.py assemble \
  --xml backup/official-rom-15.10.259/rawprogram_save_persist_unsparse0.xml \
  --label super -o out/android-v3-bringup-20261120/super_stock_contig.img
stat -c%s out/android-v3-bringup-20261120/super_stock_contig.img    # 判据：15607586816
timeout 300 python3 scripts/odirect-sha.py out/android-v3-bringup-20261120/super_stock_contig.img   # 记下 sha（写后要比）
head -c 524288 out/android-v3-bringup-20261120/super_stock_contig.img | sha256sum
#   判据：12c35980e1e809dbb621c6be9dabb51cad777e18fc944bcc4ffec228a611c23d（原厂指纹）
# ② 进 EDL + 写前门
timeout 60 "$FB" -s $S oem edl && sleep 3 && lsusb -d 05c6:9008
timeout 120 "$QDL" -s ufs -R "$L" read 0/0+6 /tmp/gpt0.bin
python3 scripts/android-linux-coexist-check.py --gpt /tmp/gpt0.bin \
  --super-img out/android-v3-bringup-20261120/super_stock_contig.img     # 判据：OK，否则不写
# ③ 回退快照（当前在机 = v1，全量件主机已有；这里只留 512 KiB 头作快速对照）
timeout 120 "$QDL" -s ufs -R "$L" read 0/90504+128 /tmp/super-head512k-pre.bin
sha256sum /tmp/super-head512k-pre.bin        # 判据：67ff7604…（确认写前是 v1）
# ④ 写 14.54 GiB（约 6–12 min @ ~42 MiB/s）
timeout 1800 "$QDL" -s ufs -R "$L" write 0/90504 \
  out/android-v3-bringup-20261120/super_stock_contig.img sha256 0/90504+3810446 \
  read 0/90504+4096 /tmp/rb-head.bin read 0/3896854+4096 /tmp/rb-tail.bin
#   判据：设备端 sha = ② 记下的值；head/tail 与件 cmp 一致
# ⑤ 清 BCB + reset（单独一发）
timeout 120 "$QDL" -s ufs -R "$L" write 0/89992 /tmp/zero4k.bin read 0/89992+1 /tmp/bcb-after.bin
timeout 120 "$QDL" -s ufs "$L" reset
```

**判读（这一条的结论必须写清）**：
- 原厂 super **能进桌面** ⇒ 变量在我们的 super 内容（**是 v1 的问题，不是 v3**；v3 至今零样本）。
- 原厂 super **也不进** ⇒ 排除 super 内容；**先查三件事**再谈其他：`current-slot=a`？BCB=0？落点是不是又 recovery（做 A4）？
- **回退**：`timeout 1800 "$QDL" -s ufs -R "$L" write 0/90504 out/android-min-20261118/pkg/super_min.img`
  （v1，2 171 264 扇区，`e3d0d26f…`）+ 清 BCB + reset。

---

## 时间预算与回退总表

| 步 | 内容 | 预算 | 需要谁 | 回退 |
|---|---|---|---|---|
| A0 | 只读前置（super 指纹/槽位） | 2 min | agent | — |
| A1 | **物理键进 fastboot** | 1–2 min | **用户** | 再试一次；仍不行 = 停手 |
| A2 | 清 BCB + `--set-active=a` | 3 min | agent | `--set-active=b`（super 零改动） |
| A3 | 启 a 槽 + 三条判据 +（若 recovery）取证挂钩 | 10–20 min | agent | 落 recovery ⇒ A4；落 Linux ⇒ 查槽位 |
| A4 | recovery 当场取证 | 1 min | agent | — |
| A5 | `/data` 处置（①/②/③ 选一） | 5–10 min | ① 需**用户**按键 | 无需回退（都是空件） |
| B1 | S2 原厂 metadata | 5–8 min | agent | 写前 dump `/tmp/metadata-pre.bin` 回写 |
| B2 | S3 原厂 super | 14–18 min | agent | v1 件回写（`super_min.img`） |
| — | 全程设备锁 | — | agent | `scripts/lib-device-lock.sh`（`--apply` 时自动取） |

**我已验证/未验证清单**

| 项 | 状态 |
|---|---|
| super/metadata/misc/userdata 只读 dd + sha + 解析 | **[已验证]**（本 lane 真跑，见材料报告 §C） |
| `fastboot devices`/`getvar`/`flash misc`/`--set-active` 用法与参数 | **[已验证]**（11-21 早 09:0x–09:2x 已实际用过，`logs/android-v3-S1-20261121-091754/commands.log`） |
| `fastboot -w` 在本机可用 | **[已验证]**（11-19 21:1x 实跑：`Erasing 'userdata'/'metadata' OKAY`，见 `TASKS/sessions/2026-11-19-安卓共存契约与v3精简上机.md`） |
| `fastboot boot <recovery.img>`（零写盘进 stock recovery） | **[未验证]**（`fastboot boot boot.img` 已验证可用；recovery.img 同类但未试） |
| qdl 写 metadata/super 命令形状（`-R` + `sha256` + head/tail 读回） | **[已验证]**（11-20 20:26 的 S2 实跑日志 `logs/android-v3-S2-20261120-202620/qdl.log`） |
| `--step S2/S3` 脚本改动（`require_active_a` 等） | **[已验证]** 语法 + `--dry-run` rc=0；**真跑 = 本次窗口首次** |
| 「`fastboot -w` 后能进桌面」 | **[未验证]**，且很可能**只是复现现态**（见 §0 第 3 条） |
| `adb exec-out` 在本机 recovery 里能取字节 | **[未验证]**（仅验证了 `adb shell` 会 SIGABRT；exec-out 是设计与 11-21 观察推得） |
| 落 recovery 的根因 = `/data` 挂不上 | **[未验证]**（高置信推断；A4 判读给出二选一） |

---

## 附：不要做的事

- **不要**用 `qbootctl -s/-u` 切槽（`PITFALLS #701`：还要改 UFS 启动 LUN，Linux 侧必失败）。
- **不要**在 Linux 侧 `dd` 写 `misc` 就以为清了 BCB：ABL 在 `misc` 的 `0x8000` 起还有自己的状态区（材料报告 §C.4）。
- **不要**把 8 MiB logfs 里"看起来像 a 槽"的记录当证据（活记录只有 64 KiB；`UEFI Ver` 必须先核对固件代次）。
- **不要**在 recovery 里 `adb reboot bootloader` 之后直接下结论：那一步会把 `misc` 写成 `bootonce-bootloader`（`PITFALLS #702`），先清 BCB 再谈样本。
- **不要**跑 `dump.f2fs` 在取证件上（它会改写超级块，见材料报告 §C.6）。
