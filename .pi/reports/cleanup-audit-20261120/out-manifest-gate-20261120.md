# out/ 造件 manifest 门禁（arch-audit P0#2）落地报告 — 2026-11-20

## 0. 数字结论

- check-doctor 全量：**FAIL=0，WARN=8**（基线 6，+2 均为存量环境漂移：§5 HISTORY 落后、§15 INDEX §0 日期落后；**§23 本门贡献 0 WARN**）
- `out-manifest-check.py --selftest`：rc=0（4 类合成样本全过）
- 现有树实跑：触发门禁的 out/ 目录 **10** 个，**10 过 / 0 WARN / 1 豁免**（android-slim-v2b-20261119）
- 产物：`scripts/out-manifest-check.py`、`scripts/doctor/23-out-manifest.sh`、`scripts/out-manifest-exempt.tsv`；未删/未移任何 out/ 文件，未改造件脚本

## 1. 规则（防误报口径）

对 `out/<name>/`（仅一级目录）：

- **触发条件**（两者任一）：目录内有 **>200 MB** 的文件，或 **.img 文件数 >1**。
  单个小目录、单个 .img（如 diag-20261119、vk188-bootfiles）不触发——这些是随手产物，强求报告会误报。
- **判据**：`reports/<name>.md` 存在，**或** `reports/*.md` 任一引用了 `out/<name>` 字样。
  满足 ⇒ ok；不满足 ⇒ **WARN（不 FAIL）**——本门是防误删的账本提醒，不阻塞提交。
- **豁免**：`scripts/out-manifest-exempt.tsv`，每行 `路径<TAB>理由`（理由 ≥10 字，canonical 路径 `out/<name>` 或短名均可）。
  **空理由/短理由必须 FAIL**（照 §17 shell-hygiene 反作弊口径：不许「删理由保平安」）。
  豁免条目仍计入账本统计（`--tsv` 标 `EXEMPT-OK`），是「如实登记中间方案」的账，不是遮羞布。
- 触发扫描遵循符号链接不跟随（大件/镜像按 `stat` 实体文件计）。

## 2. 反作弊（门不空转）

`scripts/doctor/23-out-manifest.sh` 先跑 `--selftest`（4 类合成样本，临时树不碰仓库）：

1. 有报告（reports/<name>.md）→ 过
2. 无报告 → warn
3. 豁免带理由（且被另一份报告引用双保险）→ 过
4. 豁免空理由 → **FAIL**（load_exempt 拒收，门检测到会显式报「空理由豁免未被拒」）

## 3. 初始豁免表（1 条）

| 路径 | 体量 | 理由 |
|---|---|---|
| out/android-slim-v2b-20261119 | 11G（8 大件 + 3 img） | 中间方案，已被 android-slim-v3-20261119 取代，仅留作 v3 对照基线（arch-audit 20261120 如实登记） |

其余 9 个触发目录全部有报告命中（reports/<name>.md 直命中 3 个；被其他报告引用 6 个，
如 android-min-20261118 ← reports/android-assets-20261119.md）。审计提到的
「android-min-20261118 无报告」实际是「无同名报告、但有引用」，按 §5 #5 口径判过。

## 4. 命令原始输出摘录

### python3 scripts/out-manifest-check.py --selftest

```
== selftest: 4 类合成样本 ==
  [ok]   out/exempted ← reports/ref-in-other.md（2 个 .img）
  [ok]   out/has-report ← reports/has-report.md（2 个 .img）
  [warn] out/no-report 无报告且未豁免（2 个 .img）→ 删除/瘦身前必须先补 reports/no-report.md
  [ok]   空理由豁免 → FAIL（反作弊生效）
  [ok]   selftest 通过（3 实跑样本 + 1 空理由反作弊）
rc=0
----
== 23. out/ 造件账本门（>200MB 或 >1 .img 必须有报告，arch-audit P0#2）==
  [ok]   out/android-assets-20261119 ← reports/android-assets-20261119.md（大件 ZuiWallpaperSetting.apk (271MB)）
  [ok]   out/android-min-20261118 ← reports/android-assets-20261119.md（大件 super_min.img (8481MB)）
  [ok]   out/android-min-avb-20261118 ← reports/android-min-avb-facts-20261118.md（大件 product_a.img (992MB)）
  [ok]   out/android-root-20261119 ← reports/android-ksu-avb-20261119.md（8 个 .img）
  [ok]   out/android-slim-v2b-20261119 已豁免登记（scripts/out-manifest-exempt.tsv:3）
  [ok]   out/android-slim-v3-20261119 ← reports/android-slim-v3-20261119.md（大件 super_rb.img (7109MB)）
  [ok]   out/min-restore-20261119 ← reports/device-status-20261119.md（大件 rootfs-minbase-gadget-20261119.ext4.img (6144MB)）
  [ok]   out/p2-minbase-20261118 ← reports/hide-android-partitions-20261119.md（大件 rootfs-minbase-20261118.ext4.img (6144MB)）
  [ok]   out/uefi-ddrmarks-clean-20261102 ← reports/bl-stuck-20261117-device-window.md（2 个 .img）
  [ok]   out/uefi-ddrmarks-sysram-20261102 ← reports/uefi-ddrcut-fallback-20261101.md（2 个 .img）
  [info] 触发门禁的 out/ 目录 10 个，WARN 0 条，豁免登记 1 条
rc=0

```

### timeout -k 3 180 bash scripts/check-doctor.sh（§23 段 + 汇总）

```
== 23. out/ 造件账本门（大件/多镜像 ↔ 报告） ==
  [ok]   selftest 通过（4 类合成样本：报告命中 / 无报告 warn / 带理由豁免 / 空理由 FAIL）
  [ok]   现有树实跑过（触发 10 个，WARN 0 条，豁免 1 条）

== 汇总: FAIL=0  WARN=8 ==

```

## 5. 后续可选（§5 #6 STATUS 文件方案）——建议，本轮不实现

- 在 `out/<name>/STATUS` 写一行 `active|superseded:<vX>|verified:<date>`，造件脚本收尾时即写；
- 门禁第二阶段把 STATUS 读进账本：`superseded` 且无引用的目录在瘦身时归入「可回收候选」，
  `active` 目录删除动作前强制查 `reports/<name>.md` 首启判据；
- 免全量考古：`out-manifest-check.py --tsv` 已是机读账，STATUS 方案落地后 tsv 加一列状态即可。

## 6. 遗留 WARN（非本门引入，逐条归类）

| WARN | 归类 |
|---|---|
| §5 vk 身份「源树已档 geekidos-linux/ 不在盘」×2 + 内核段不可读 + C=2 降级 | C 类存量豁免（versions/kernel-src-archive.tsv 已登记） |
| §5f 未找到 .config / §12 无构建树 | C 类存量（2026-11-19 清理后不可核，reports/disk-cleanup-20261119-validation-impact.md） |
| §10 HISTORY 落后 | 本轮不修（跑 gen-history.sh 即消，属父代理收尾轮动作） |
| §15 INDEX §0 日期落后 | 本轮不修（同上） |
