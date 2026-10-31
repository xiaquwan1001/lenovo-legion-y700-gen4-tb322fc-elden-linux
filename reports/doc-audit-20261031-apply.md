# 应用清单复核 + 增量审计（2026-10-31）

> **角色** = 文档审计 Lead（L1 · `doc-audit-lead`）。**性质** = 纯主机、只读、只新建本文件。
> 未 ssh / adb / fastboot / 刷机 / 构建 / 未改任何既有文件 / 未提交 / 未碰设备。
> 基线 `scripts/check-doctor.sh`（开工）= **FAIL=0 WARN=3**；收尾复跑 = **FAIL=0 WARN=3**（未新增）。
> 上位：`reports/doc-audit-20261030-v2-applylist.md`（本文件是其「盘态复核」）。

---

## 0. 数字结论

| 项 | 数值 |
|---|---|
| applylist 可机械条目（P1 8 条/10 处 + P2 10 条/15 处） | 18 条 |
| **仍可以及需要机械应用** | **0 条** |
| **已被 10-31 提交自然修好（OLD anchor 不再存在，NEW 文本已落盘）** | **18 条 / 全部** |
| applylist DEFER 条目（状态未变） | 10 条（阻塞条件同原表） |
| **增量审计新问题** | **P0 = 0 / P1 = 1 / P2 = 2** |
| check-doctor 前 / 后 | FAIL=0 WARN=3 / FAIL=0 WARN=3 |

---

## 1. Applylist 逐条复核

> 每条验证方法：`grep -Fc -- '<OLD>' <file>`（期望 0 = OLD 消失 = 已修），再 `grep -n '<NEW-keyword>' <file>` 确认 NEW 落盘。
> 全部 18 条结果一致：**OLD 在盘上不存在、NEW 文本或等价改写已就位**。不再列重复的 OLD/NEW 对。

| ID | 文件 | 结论 | 证据 |
|---|---|---|---|
| R1 | RESOURCES:276 | ✅ FIXED（指向 10-23 bundle） | `grep -c 'kernel-git-repair-2026-10-23/elden-all-refs-66' RESOURCES/README.md` → 1 |
| R2 | RESOURCES | ✅ FIXED（去写死计数） | `grep -c '现 22 个 img' RESOURCES/README.md` → 0 |
| R3a | RESOURCES | ✅ FIXED | `grep -c '现查 5.4 G' RESOURCES/README.md` → 0 |
| R3b | RESOURCES | ✅ FIXED | `grep -c '现查 830 M' RESOURCES/README.md` → 0 |
| R3c | RESOURCES | ✅ FIXED | `grep -c '现查 19 M' RESOURCES/README.md` → 0 |
| T1 | TASKS:19 | ✅ FIXED（现查 67 img） | `grep -c 'out/\*.img. 仍为空' TASKS/README.md` → 0 |
| T2 | TASKS:14 | ✅ FIXED | `grep -c 'M1–M5' TASKS/README.md` → 0 |
| T3 | TASKS:25 | ✅ FIXED | 同 T2 |
| T4 | TASKS:328 | ✅ FIXED | `grep -c 'Q1–Q26、Q28、Q31–Q35' TASKS/README.md` → 0 |
| T5 | TASKS | ✅ FIXED（入站 ≥1） | `grep -rl 'shutdown-greetd-hang-plan' TASKS/README.md` → 1 |
| T6 | TASKS | ✅ FIXED | `grep -rl 'droidloom-build-device-plan' TASKS/README.md` → 1 |
| T7 | TASKS | ✅ FIXED | `grep -rl 'bootloader-alternatives-survey' TASKS/README.md` → 1 |
| T8 | TASKS | ✅ FIXED | `grep -rl 'uefi-n2-v0b-onboard' TASKS/README.md` → 1 |
| X1 | INDEX:129 | ✅ FIXED | `grep -c '未解（1 项）' INDEX.md` → 0 |
| X2 | INDEX/TASKS | ✅ FIXED（链接落在 TASKS:18 拓展行） | `grep -rl 'uefi-text-console-archaeology-plan' TASKS/README.md` → 1 |
| X3 | INDEX:15 | ✅ FIXED | `grep -c 'M1–M5' INDEX.md` → 0 |
| X4 | INDEX:91 | ✅ FIXED | 同 X3 |
| D1 | DEVICE:40 | ✅ FIXED | `grep -c '现为 m3v5-f2，sha' DEVICE/README.md` → 0 |
| D2 | DEVICE:45 | ✅ FIXED（指稳定件） | `grep -c '与签名件 `bootslot-b/boot_b.img`' DEVICE/README.md` → 0 |
| D3 | DEVICE:191 | ✅ FIXED | `grep -c '仲裁仍需独立验证' DEVICE/README.md` → 0 |
| P1-a | PITFALLS/sessions/98-*.md | ✅ FIXED | `head -1` → `# #418 · UEFI 异类载荷 repack v0…` |
| P1-b | PITFALLS/sessions/99-*.md | ✅ FIXED | `head -1` → `# #419 · OpenRC…` |
| P1-c | PITFALLS/sessions/135-*.md | ✅ FIXED | `head -1` → `# #471 · \`dt-validate\`…` |
| P2-a | PITFALLS:6 | ✅ FIXED | `grep -c '最后更新：2026-10-25' PITFALLS/README.md` → 0 |
| P2-b | PITFALLS/sessions/111-*.md:48 | ✅ FIXED | `grep -c '编号 110' PITFALLS/sessions/111-*.md` → 0 |

**结论：总管无需再机械应用 applylist 任何条目。**

### DEFER 10 条状态（未变）

同 `reports/doc-audit-20261030-v2-applylist.md` §A-DEFER 表（P1-D1…D3、P2-D4…D10）。
阻塞条件不变：需总管拍板规则/设备侧值/外部 sha/高触碰判断。

---

## 2. 增量审计（2026-10-31 新增/改动）

审计范围：commit `4400483`..`953ec24`（含 d0a9ae9 D5/D6、3ec9db2 mail、579653f DEVICE、a57023e tablet、eec62d7 PITFALLS #472、4400483 收口）。

### 2.1 P1（1 条）

| 严重度 | 位置 | 现状 | 证据 | 建议 |
|---|---|---|---|---|
| **P1** | `DEVICE/README.md:211`（U2 设备表行） | 声称 `/`=`f2fs @/dev/sda18`、"当前 boot_b=`f2fs-root`（2026-10-25 刷入…）"。该分区已于 2026-10-31 删除（`§3.3` 明确写"`linux18` 已删除，`by-partlabel` 只剩 `linux17`"）；当前根 = ext4 @ linux17 192 GiB，当前 boot_b = vk183-fastrpc (`aedae5f1`)。此行与 §1.1 首条（唯一权威）直接矛盾 | `grep -c 'f2fs @/dev/sda18' DEVICE/README.md` → 1；`grep -n 'linux18.*已删' DEVICE/README.md` → 284 | 把 U2 表的"mainline 持久直启"整段（从 `/`= 到 `基线回退`）更新为当前态：`/`= **ext4 @linux17 192 GiB Debian**，当前 boot_b = `vk183-fastrpc`（sha `aedae5f1…`），回退件 = `boot_b-vk181-daily-signed-20261029.img`；**或** 整段改为纯指针「设备当前态见本节首条 §1.1」与 §5 表头同策略 |

### 2.2 P2（2 条）

| 严重度 | 位置 | 现状 | 证据 | 建议 |
|---|---|---|---|---|
| **P2** | `TASKS/README.md:154`（T19 行尾） | 「`boot_b` 未改（回退 = 重启回 Alpine `linux18`）」——linux18 已删。虽属 T19 历史完成项内文（DEVICE §3.3 末尾自注「T19 旧口径作废」），但读者按行搜索可命中误导 | `grep -c '回退 = 重启回 Alpine' TASKS/README.md` → 1 | 该括号内追加 `（⚠ linux18 已 2026-10-31 删并入 linux17；见 DEVICE §3.3）` |
| **P2** | `PITFALLS/README.md` 序号列 59、69 重复 | 既有问题（applylist P2-D9），10-31 未引入新重复（136/137 序号正确）；仍与 D9/D10 DEFER 同处理 | `grep -oP '^\| \K\d+' PITFALLS/README.md \| sort -n \| uniq -d` → 59 69 | 同 DEFER P2-D9/D10 建议（高触碰，与 D9 一并处理） |

### 2.3 无问题项（已复核通过）

- **孤儿报告检查**：`camss-icc-table-fix-20261031.md`、`m4-camss-v2-20261031.md`、`patches/upstream/{m4-camss-v2-20261031,camss-icc-20261031}` **均有 TASKS/README.md 级入站**，非孤儿 ✓
- **PITFALLS 编号**：新增 #472（sessions/136）/ #473（sessions/137），正文首行含 `# #472`/`# #473`，索引 136→#472、137→#473 无悬空、无撞号 ✓
- **SSOT（状态数字）**：PROGRESS.md 三条 10-31 条目是带日期的历史时间线，非「当前态声明」，不违 §2 规则 7 ✓；§3.3 内提及新 boot_id 但未写死具体值（只说「新 boot_id」）✓
- **§5 表头**：line 328 = `编号以表内为准（Q27 从无此号；不在此写死连续区间）` ✓

---

## 3. 总管可执行清单（本轮增量）

仅需处理 **1 P1 + 1 可选 P2**（DEFER 10 条同前轮，不变）：

| # | 文件 | 精确操作 | 验证 |
|---|---|---|---|
| 1 | `DEVICE/README.md:211` | U2 表"mainline 持久直启"段 → 改指针到 §1.1 首条（或更新为当前值）。建议 NEW：`**mainline 持久直启**（当前态只读本节 §1.1 首条，本行不维护数字）` | `grep -c 'f2fs @/dev/sda18' DEVICE/README.md` → 0 |
| 2 | `TASKS/README.md:154`（可选） | T19 行尾 `回退 = 重启回 Alpine `linux18`` 后补 `（⚠ linux18 已 2026-10-31 删并入 linux17；见 DEVICE §3.3）` | `grep 'linux18.*删并入' TASKS/README.md` → 1 行 |

应用后重跑 `bash scripts/check-doctor.sh`，期望仍 FAIL=0 WARN≤3。

---

## 4. 门禁记录

| 时点 | FAIL | WARN | 备注 |
|---|---|---|---|
| 开工（本轮） | 0 | 3 | 与 applylist 基线同值 |
| 收尾（本轮） | 0 | 3 | 本文件不改任何 SSOT 文件 |

---

## 5. 复现命令

```bash
cd /home/xuqianhui/y700-elden

# A) 全部 OLD anchor 不存在（应全输出 0）
for pat in '现役可用备份 = `backup/kernel-git-repair-2026-10-08' '现 22 个 img' '现查 5.4 G' '现查 830 M' '现查 19 M' 'out/\*.img` 仍为空（重建见 §4 待办 T4）' '上游化 **M1–M5**（§7）' '**不含**上游化 M1–M5' '编号 Q1–Q26、Q28、Q31–Q35' '未解（1 项）' '§7 M1–M5）。' '**§7 上游化（M1–M5）**' '（**现为 m3v5-f2，sha `e6b1124c…`**）' '与签名件 `bootslot-b/boot_b.img` **逐字节一致**' '仲裁仍需独立验证' '> 最后更新：2026-10-25。'; do
  c=$(grep -Fc -- "$pat" TASKS/README.md INDEX.md RESOURCES/README.md DEVICE/README.md PITFALLS/README.md 2>/dev/null | awk -F: '{s+=$2}END{print s}')
  echo "$c | $pat"
done

# B) PITFALLS 锚点已补
for p in 98 99 135; do head -1 PITFALLS/sessions/${p}-*.md; done

# C) 5 篇孤儿入站
for r in shutdown-greetd-hang-plan droidloom-build-device-plan bootloader-alternatives-survey uefi-text-console-archaeology-plan uefi-n2-v0b-onboard; do echo "$r: $(grep -rl "$r" INDEX.md */README.md 2>/dev/null | wc -l)"; done

# D) 增量 P1 复现
grep -n 'f2fs @/dev/sda18' DEVICE/README.md
grep -n 'linux18.*已删' DEVICE/README.md

# E) 门禁
bash scripts/check-doctor.sh 2>&1 | tail -3
```
