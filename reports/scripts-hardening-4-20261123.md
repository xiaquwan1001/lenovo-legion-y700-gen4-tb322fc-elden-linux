# reports/scripts-hardening-4-20261123.md — 脚本整改批 4（D5：STALE 15 收口 + O_DIRECT 硬门 ×6）

输入：`reports/scripts-audit-20261122.md` §5 批 3 第 10–12 条、`out/audit/scripts-audit-20261122.tsv`（kind=STALE 15 行）、
`PITFALLS/README.md` #513（页缓存位翻转 + drop_caches 卡死）、`scripts/odirect-sha.py`（硬门工具）、
`reports/odirect-sha-gate-20261120.md`（取证）、既有门样式 `reports/scripts-hardening-{1,2,3}-2026*.md`。

性质：**主机侧静态 + 假命令验证；零设备接触**（未跑 ssh/fastboot/adb/qdl；无任何设备写）。
**未 git commit**（派工单明令）。工作树改动只在本批 7 个文件（§1）+ 本报告；
另有 lane G2 在改 `rootfs/debian/*` 与 `TASKS/README.md`，不在本报告范围、未纳入任何统计。

---

## §0 结论数字（先行）

| 项 | 数字 | 判据 |
|---|---|---|
| STALE 总数（2026-11-22 审计 TSV） | **15** | `awk -F'\t' '$2=="STALE"' out/audit/scripts-audit-20261122.tsv \| wc -l` |
| → 归档（首批 223ed114 已落，字节不变） | **3**：`m1-73-modules-overlay.sh` / `deploy-sensord-routec.sh` / `waydroid-headless-restart.sh` | `archive/scripts-stale-20261123/MANIFEST.tsv`（3 行，sha256 逐条复核 = 归档前 commit 父版本的 git blob，全 OK） |
| → 留 + 头注（首批 11 + 本批复核新增确认 1 = 12） | **12**（逐条判据见 §2） | 每件头注都引用本报告路径；`grep -rl 'reports/scripts-hardening-4-20261123.md' scripts/` 命中 16 文件（12 头注 + 6 O_DIRECT 门有重叠） |
| STALE 第二批新增归档 | **0**（15/15 在首批已全部处置；本批为逐条独立复核，零翻案、零新归档） | §2 逐条证据 |
| 唯一真孤儿（全仓 0 活引用，非 STALE 列表成员） | `scripts/gen-pinyin-lexicon.py` — **留**：pinyin v3 词库活生成器，`--check` rc=0 | §2.13 |
| O_DIRECT 硬门 | **6/6 脚本接上**（`odirect-sha.py` 加 `--require-odirect` + 6 个调用方；派工单要求 ≥5） | §3 逐文件 |
| 工具级反例 | 非可 O_DIRECT 文件（`/proc/version`）→ **拒绝、rc=90、零产出** | `python3 scripts/odirect-sha.py --tsv --require-odirect /proc/version; echo $?` = 90 |
| 脚本级反例 | 6/6：`sha_direct /proc/version`（模拟非 O_DIRECT 读）→ **REFUSE + rc=90**；`ODIRECT_SHA_ALLOW_BUFFERED=1` 降级 → WARN + buffered 值 | §4 用例表 |
| 脚本级正例 | 6/6：`sha_direct README.md` = `sha256sum` 参考值（O_DIRECT 直读） | §4 用例表 |
| `bash -n` | 6 个 .sh 改动文件**全 OK** | `for f in …; do bash -n $f; done`（§4） |
| `sh -n`（dash，linux-state-audit 是 `/bin/sh` 件） | **OK**（纯 POSIX：无 `local`，`set -u` 下无未绑定变量） | `sh -n scripts/linux-state-audit.sh` |
| `py_compile` | `odirect-sha.py` **OK** + `--selftest` PASS（5255225 B，O_DIRECT=buffered=参考值，含 fadvise 干扰复测） | `python3 -m py_compile scripts/odirect-sha.py && python3 scripts/odirect-sha.py --selftest` |

**结论：PASS**（STALE 15 全部收口 = 3 归档 + 12 留头注；O_DIRECT 硬门 6/6，反例全部被拒、零静默降级）。

---

## §1 before → after（本批 7 个文件）

| 文件 | 改动要点 | 回退命令（单文件） |
|---|---|---|
| `scripts/odirect-sha.py` | 新增 `--require-odirect`：任一文件只能 buffered ⇒ 不输出该行、stderr `REFUSE …`、**rc=90**（工具层硬门；默认 WARN+回退行为不变，向后兼容） | `git checkout -- scripts/odirect-sha.py` |
| `scripts/flash-b.sh` | `sha_direct()`（默认拒绝 rc=90 / `ODIRECT_SHA_ALLOW_BUFFERED=1` 降级告警）+ image sha 改走 O_DIRECT（拿不到不刷，`exit 90`）；读回行加「设备侧仍 buffered」残留风险标注 | `git checkout -- scripts/flash-b.sh` |
| `scripts/trial.sh` | 同款 `sha_direct()`；`record` 的 `image_sha256`（身份字段）改走 O_DIRECT，拿不到**不写 record**（`exit 90`） | `git checkout -- scripts/trial.sh` |
| `scripts/build-boot.sh` | 同款 `sha_direct()`；产物 sha 打印行改走 O_DIRECT（拿不到 rc=90，不发布身份） | `git checkout -- scripts/build-boot.sh` |
| `scripts/uefi-flashed-trial.sh` | 同款 `sha_direct()`；`IMGSHA`（刷写身份，进 timing.txt/报告）改走 O_DIRECT，拿不到**不刷不记**（`exit 90`） | `git checkout -- scripts/uefi-flashed-trial.sh` |
| `scripts/linux-state-audit.sh` | 同款（**纯 POSIX sh** 版，dash 兼容）；`sha8()` 拿不到 O_DIRECT ⇒ `NO-ODIRECT`，`check_file` 报 UNKNOWN（**不下 DRIFT 结论**）；EDL 读回 sha 同口径 | `git checkout -- scripts/linux-state-audit.sh` |
| `scripts/n5b-vk64-death-rate.sh` | 同款；`--check` 预检的镜像 sha（上机身份）改走 O_DIRECT | `git checkout -- scripts/n5b-vk64-death-rate.sh` |

合计 +211 −13 行（`git diff --numstat scripts/`）。选型 = 派工单判据「调用点最多的 ≥5 个高频读设备镜像/产物算 sha 的脚本」：
先全仓盘点 69 个含 `sha256sum` 的脚本 ×（活引用数 × 已带门 × 判据性质），得未设门的判据类热点 top8 =
build-boot(40) / trial(24) / flash-b(21) / uefi-build-variant(19) / rambuild(18) / linux-state-audit(18) / uefi-flashed-trial(12) / n5b-vk64(19)；
从中取 6 个「sha 直接当写盘门/台账判据/刷写身份」的（rambuild/uefi-build-variant 的 sha 只进 bench TSV，判据性质弱，本批不接，见 §3 残留）。

**公共门语义（6 处一致）**：

```
sha_direct <file>
  文件不存在            → 空（调用方自判）
  O_DIRECT 拿到 64 位值  → 输出（= odirect-sha.py --tsv --require-odirect 第 3 列）
  拿不到（rc=90 路径）   → 默认：stderr REFUSE + return 90（调用方 exit 90 / 报 UNKNOWN）
                          ODIRECT_SHA_ALLOW_BUFFERED=1：stderr WARN + buffered 值（只能当线索）
```

- 拒绝而非告警的理由：`PITFALLS #513` 实测 buffered 会给「稳定但错」的页缓存副本（v1 件 637a9965… vs 真值 e3d0d26f…），
  默认 WARN+回退 = 错值静默进判据；硬门把「读不到真值」变成显式失败（rc=90）。
- ⚠ 本机实测（ext4 与 tmpfs 均 `O_DIRECT open OK`，kernel 7.0.0-44-generic），真实反例用**不可 O_DIRECT 的节点**（`/proc/*`）构造；
  tmpfs 场景（#513 里 O_DIRECT 不可用的典型）在本机不复现，门对它的保护逻辑同路径（工具层 `ok=False → rc=90`）。
- ⚠ 修掉一个自测中发现的接缝 bug：`flash-b.sh` 原 `$(dirname "$0")` 在被 source 时取到调用方 `$0` ⇒ `ODIRECT_SHA` 解析错路径；
  改 `${BASH_SOURCE[0]:-$0}`。其余 5 件用 `$ROOT`（脚本内自有锚点），source-from-elsewhere 场景全部复验 OK。

---

## §2 STALE 15 逐条复核（首批 223ed114 的核对 + 第二批复判）

### §2.0 首批核对结论

- 3 个归档件字节**逐字节未变**：`MANIFEST.tsv` 第 6 列 sha256 与 `git show 223ed114^:scripts/<name>` 管道 sha256 三方一致（§0 表判据）。
- 3 个归档件归档后**无新的活指针悬挂**：`INDEX/DEVICE/TASKS/RESOURCES/RUNBOOK/packaging/rootfs/scripts/` 里只剩
  `scripts/deploy-modules.sh:7-10`（已就地改成「已归档 → archive/…，勿再当活入口」）与历史 reports（按「历史账不追改」保留）。
- 11 个头注件 + 1 个本批补注件（`serial-logger.sh`，理由见 §2.7）：头注全部引用本报告路径 `reports/scripts-hardening-4-20261123.md`（本件），
  无悬空引用；`bash -n`/`sh -n`/`py_compile` 全过（§0）。
- 误改来源检查：`git show 223ed114 -- scripts/` 逐文件过目——改动全部是头注/判据修复类，**未发现误改**；
  `ath12k-load.sh`/`arm-console-run.sh`/`q28-por-rounds.sh`/`gpt-restore-tb322fc.py` 属批 3 已验收内容（不在本批范围）。

### §2.1–§2.12 「留 + 头注」12 件：逐条判据（可复核）

判据格式：调用点 = `grep -rln <name>`（scripts/packaging/rootfs/initramfs 里的活引用，排除 README 索引与 reports/历史账）；
supersede = 谁接替了它；绑死 = 是否绑死旧机/旧根路径。

| # | 文件 | 判定 | 调用点（活） | supersede / 绑死判定 | 头注要点 |
|---|---|---|---|---|---|
| 1 | `android-assets-extract-20261119.py` | **留**（否掉 TSV「归档」） | `scripts/asset-install-linux.sh:108`（报错文案直接要求先跑本件） | 无 supersede；`assets/android-20261119/`（319 MB，gitignore）唯一重建路径 | 归档后 assets 树丢失即无法重建 |
| 2 | `android-slim-v2-plan.sh` | **留** | `DEVICE/README.md:288`（apply 类清单流程范例）+ TASKS/sessions ×2 | supersede = `android-slim-v3-build.sh`（v3 才是出件构建器）；本件是「只打印不落盘」计划器 + dry-run 标杆 | 头注写 SUPERSEDED-BY + 仍可只读重跑 |
| 3 | `linux-state-audit.sh` | **留** | `INDEX.md:239,260,358` + RUNBOOK-BRINGUP ×3 + `.pi/memory/failures-device.md` | 无 supersede（活体检入口）；绑死 `backup/HA2EXB0E-16+512`（:86-91，U1）= 债务，头注已披露，参数化留待单独一轮 | 本批顺带给它接 O_DIRECT 门（§3） |
| 4 | `mailbox-cleanup-20261102.py` | **留**（否掉 TSV「归档」） | `scripts/mailbox-cleanup-weekly.sh:24,28`（--backup / --delete --aggressive 两处活调用） | 无 supersede；文件名日期是历史命名 | 归档 = 周度清理脑死 |
| 5 | `pack-cloud-backup.sh` | **留** | `RESOURCES/README.md:259`（云盘打包唯一指针） | 无 supersede；T1/T2 清单绑死 `HA2EXB0E-16+512`（U1）= 头注披露「换单元必须手改清单」 | 参数化属审计批 2 第 9 条，未在本批 |
| 6 | `serial-log.sh` | **留** | `scripts/devlogs.sh:77`（`exec scripts/serial-log.sh`，活依赖） | 取证 supersede = `serial-tap.py`（#622 家族：cat 循环漏帧假阴性） | 头注写「勿用于 panic 取证」+ 真源指针 |
| 7 | `serial-logger.sh` | **留**（**本批唯一新增头注**：首批漏做，TSV 明确要求「RETIRED-for-forensics 头注」） | 活引用 6 处（lib-serial-source/serial-fanout/q32-arm/install-serial-logger 等）+ DEVICE/README.md:176 | 取证 supersede = `serial-tap.py`（#622：open/close 狂抖 = 假阴性 + 孤儿 cat 占口）；DEVICE/README.md:176 指针未修 = 写域外，头注披露 | 头注 = RETIRED-for-forensics，保留文件（DEVICE 文档还指着它） |
| 8 | `sleep-bisect.sh` | **留** | `packaging/elden-userland/MANIFEST.tsv:64` + `files/usr/local/sbin/` + `tools/sync-from-device.sh:36`（随 rootfs 发设备） | 新扫测 supersede = `sleep-sweep.sh`（PITFALLS §15.2，2026-10-08 legacy 登记）；保留 = 设备侧真机二分工具 + 装机面依赖 | 头注 = LEGACY + 装机面证据 |
| 9 | `sleep-cumulative.sh` | **留** | `packaging/elden-userland/MANIFEST.tsv:65` + sync-from-device.sh:36 + rootfs/debian/svc-deps.tsv | 同上 §15.2；另绑死 `/sys/class/drm/card0`（PITFALLS/sessions/303）已在头注披露 | 同上 |
| 10 | `t2-stock-lun45.sh` | **留** | `TASKS/README.md:40` + `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md:146`（卡 BL 一条命令恢复入口） | 无 supersede；2026-11-17/18 真恢复成功的现场驱动（不可重建经验）；qdl 全 LUN 覆写 = 最高危 ⇒ 头注硬约束「再启用必过 rawprogram-preflight.py + 写前六 LUN GPT dump」 | 头注 = 取证指针 + 硬约束 |
| 11 | `waydroid-headless-start.sh` | **留** | `.pi/memory/notes-display.md:12` + notes-camera-waydroid.md:62（Q28 坏态起容器实测记录） | 正常态 supersede = `waydroid-cam-restart.sh`（headless weston = 空合成器错路）；场景限定「Q28 坏发无合成器」 | 头注 = 场景限定 + 已知局限（内联 ssh / XDG_RUNTIME_DIR 写死） |
| 12 | `q28-por-rounds.sh` | **留**（属批 3 已修，本批复核无新问题） | `TASKS/README.md` + `RUNBOOK-BRINGUP/f2fs-migration.md` | v1 取样器 supersede 已落（:99 → `q28-devprobe2.sh` + `l1=/l2=` 字段门，批 3 §1.3） | 无需新头注 |

### §2.13 唯一真孤儿

`scripts/gen-pinyin-lexicon.py` — **留**：pinyin v3 词库活生成器，`--check` rc=0。
全仓活引用 0（只有 scripts/README.md 索引 2 行），但 `packaging/elden-userland/rootfs-overlay/usr/bin/elden-pinyin-completer`
头注释明词库「由 `scripts/gen-pinyin-lexicon.py` 生成」（TASKS 2026-11-21 会话 + 报告词库 v3 段），换词库就要重跑它；一次性工具 ≠ 死件。

### §2.14 第二批复核方法与边界

- 三判据逐条跑：① `grep -rn <name>` 调用点（scripts/packaging/rootfs/initramfs = 活；reports/TASKS/sessions/PITFALLS = 历史账）；② supersede（头注 + INDEX 现态）；③ 绑死旧机路径（apk/OpenRC/旧 SN/旧树）。
- 15 件全部在首批处置完毕 ⇒ 第二批「归档 N = 0」。全仓再扫一遍（69 sha 脚本 + 全部 `.sh/.py` 按「0 活引用」孤儿判定）只出 §2.13 一个新候选，判定为留。
- 边界：`scripts/bisect/eldtest.sh`、`audio-tplg/`、`packaging templates` 未逐行深读（沿 2026-11-22 审计的「未验证」标注，本轮未扩权）。

---

## §3 O_DIRECT 硬门（PITFALLS #513）

**为什么**：#513 实测页缓存副本含翻转字节（`out/boot-elden-vk158.img` 普通读 `932ea232…` vs `dd iflag=direct` `b882abcd…`=基线），
且 `echo 3 > /proc/sys/vm/drop_caches` 在本机直接卡死重启（禁用）⇒ 唯一安全口径 = 基线/身份校验一律 O_DIRECT。
既有 `odirect-sha.py` 的默认行为是「WARN + 退回 buffered」——对**线索**够用，对**判据**是漏洞。

**接法（两层）**：

1. 工具层：`odirect-sha.py --require-odirect`（新增 flag，见 §1）。
2. 调用方层：6 个脚本各加同款 `sha_direct()` 包装（拒绝 rc=90 / `ODIRECT_SHA_ALLOW_BUFFERED=1` 显式降级告警），
   每处只改「把 sha256sum 的值吃进判据」的那 1–2 行，行为外其他逻辑零变更。

| 脚本 | 判据位置（改前 → 改后） | 反例用例（非 O_DIRECT 读 → 拒绝/告警） |
|---|---|---|
| `flash-b.sh` | `:29` image sha（与设备读回比对的写盘门）→ `sha_direct` + `exit 90` | `sha_direct /proc/version` → REFUSE + rc=90（§4） |
| `trial.sh` | `record` 的 `image_sha256` 身份字段 → `sha_direct`，拿不到不写 record | 同上，rc=90 |
| `build-boot.sh` | 产物 sha 打印（fastboot/kexec 即将上机的那一个件）→ `sha_direct` | 同上，rc=90 |
| `uefi-flashed-trial.sh` | `IMGSHA`（刷写身份 → timing.txt/报告）→ `sha_direct`，不刷不记 | 同上，rc=90 |
| `linux-state-audit.sh` | `sha8()`（台账 DRIFT 判据）+ EDL 读回 sha → O_DIRECT，拿不到报 UNKNOWN 不下结论 | 同上，rc=90 |
| `n5b-vk64-death-rate.sh` | `--check` 镜像 sha（上机身份）→ `sha_direct` | 同上，rc=90 |

**判据强度排序落选说明**（非遗漏）：`rambuild.sh`（bench TSV 的 img_sha16）、`uefi-build-variant.sh`（SHA256SUMS 汇总）、
`uefi-flashed-trial.sh` 内 `logfs` 侧件等——sha 只进过程记录/不强分支，先不接门（避免把 bench 跑挂）；后续如升为判据再按同款接入。

**设备侧残留**（写域外，披露）：`flash-b.sh` 设备读回段 `dd if=$D … | sha256sum` 与 `uefi-flashed-trial.sh` 的 ssh 段
`sha256sum /dev/disk/by-partlabel/boot_*` 仍是 buffered 口径（#513 的「读设备镜像」面）。主机侧门已把送进门的本地值变真值；
设备侧若要同强度，需要设备内核/裸 dd 支持 `iflag=direct`——留给设备侧 owner，不属本批写域（`scripts/` 之外的设备命令内嵌串不改）。

---

## §4 用例与验证（全部命令可原样重放）

```sh
cd /home/xuqianhui/y700-elden

# 1) 语法门
for f in scripts/flash-b.sh scripts/trial.sh scripts/build-boot.sh \
         scripts/uefi-flashed-trial.sh scripts/linux-state-audit.sh scripts/n5b-vk64-death-rate.sh; do
  bash -n "$f" || echo "FAIL $f"
done            # → 全静默 = 6/6 OK
sh -n scripts/linux-state-audit.sh          # dash 口径 OK
python3 -m py_compile scripts/odirect-sha.py
python3 scripts/odirect-sha.py --selftest  # → selftest OK: size=5255225 … odirect=buffered=ref（含 fadvise 干扰复测）

# 2) 工具级反例（非 O_DIRECT 读 → 拒绝 rc=90，零产出行）
python3 scripts/odirect-sha.py --tsv --require-odirect /proc/version; echo "rc=$?"
# → WARN odirect-sha: /proc/version O_DIRECT 不可用（[Errno 22] …），退回 buffered
#   REFUSE odirect-sha: /proc/version 只能 buffered 读 ⇒ 不作判据（要降级请去掉 --require-odirect；那时值只能当线索）
#   rc=90

# 3) 工具级正例
python3 scripts/odirect-sha.py --tsv --require-odirect README.md; echo "rc=$?"
# → README.md  9325  b099a103…  rc=0（= sha256sum 参考值）

# 4) 脚本级（source 接缝，不进各自主流程：ODIRECT_SHA_LIB_ONLY=1）
for s in flash-b trial build-boot uefi-flashed-trial linux-state-audit n5b-vk64-death-rate; do
  # 反例：非 O_DIRECT 读 → 必须 REFUSE + rc=90
  ( cd scripts && ODIRECT_SHA_LIB_ONLY=1 bash -c ". ./$s.sh; sha_direct /proc/version" >/dev/null 2>&1 )
  echo "$s refuse-rc=$?"        # → 全部 90
  # 降级开关 → WARN + buffered 值（rc=0）
  ( cd scripts && ODIRECT_SHA_LIB_ONLY=1 ODIRECT_SHA_ALLOW_BUFFERED=1 \
      bash -c ". ./$s.sh; sha_direct /proc/version" 2>&1 | head -1 )
  # → WARN sha_direct: … buffered 值 dc0d20e5…（ODIRECT_SHA_ALLOW_BUFFERED=1；判据不可信，#513）
  # 正例：真文件 → O_DIRECT 值 == sha256sum 参考值（用独立 caller 脚本 source，
  # 保证 BASH_SOURCE 锚定仓库路径 —— 交互式 bash -c ". …" 的 BASH_SOURCE 锚不到本仓，属测试接缝限制，见 §5）
  cat > /tmp/od-gate-pos-$s.sh <<'EOP'
#!/bin/bash
set -uo pipefail
ODIRECT_SHA_LIB_ONLY=1
source /home/xuqianhui/y700-elden/scripts/SCRIPT_NAME
sha_direct /home/xuqianhui/y700-elden/README.md
EOP
  sed -i "s/SCRIPT_NAME/$s.sh/" /tmp/od-gate-pos-$s.sh
  bash /tmp/od-gate-pos-$s.sh 2>/dev/null | tail -1
  # → b099a103…（6/6 一致）
done

# 5) 归档完整性
awk -F'\t' '$1!~/^#/ && $1!="原名" {print $1"\t"$6}' archive/scripts-stale-20261123/MANIFEST.tsv \
 | while IFS=$'\t' read -r n sha; do
     got=$(sha256sum "archive/scripts-stale-20261123/$n" | cut -d' ' -f1)
     prev=$(git show 223ed114^:scripts/$n | sha256sum | cut -d' ' -f1)
     [ "$got" = "$sha" ] && [ "$got" = "$prev" ] && echo "OK $n" || echo "FAIL $n"
   done                          # → OK ×3
python3 scripts/gen-scripts-index.py --check   # → 仅报 scripts/README.md 结构指纹过期（索引 owner 职责，见 §5）
```

---

## §5 残留与未做项

1. `scripts/README.md` 结构指纹过期（`gen-scripts-index.py --check` 报 346 入口 fp 漂移）——索引 owner 的职责，
   本轮不代跑（归档/头注都会触发，跑一次即收敛），留给 lane 收口。
2. ~~`DEVICE/README.md:176` serial-logger 指针未改 serial-tap.py~~ **已收口（2026-11-24）**：DEVICE 指针改 serial-tap.py，serial-logger 头注同步。
3. 设备侧读回仍 buffered（§3 残留段）；`rambuild.sh`/`uefi-build-variant.sh` 未接门（判据强度弱，§3 落选说明）。
4. ~~`linux-state-audit.sh`/`pack-cloud-backup.sh` 的 U1 路径参数化（审计批 2 第 9 条）仍未做~~ **已落（2026-11-24）**：
   两件都改为运行时发现 `backup/*+*/`（= `<SN>-<容量档>`）并逐单元展开；新增单元零改动即进清单。
   离线验证：`pack-cloud-backup.sh --list` 与 `linux-state-audit.sh --host` 在真单元输出与改前一致；
   临时造 `backup/TESTSN-8+128/` 后两件都按新单元逐项列出（含 MISSING），验后已删。真机复核仍待设备上线。
5. O_DIRECT 在本机 ext4/tmpfs 均可用 ⇒ 「O_DIRECT 不可用」的拒真反例只能用 /proc 节点构造；
   tmpfs 场景的保护逻辑与 /proc 同一代码路径（工具层 `ok=False → rc=90`），但未在本机实测到 tmpfs 拒绝的现场。
6. 测试接缝限制：交互式 `bash -c ". ./flash-b.sh"`（无 caller 文件）里 `${BASH_SOURCE[0]:-$0}` 锚不到本仓
   ⇒ 正例用例用独立 caller 脚本 source（§4 命令已这样写）；真实执行路径（`bash scripts/flash-b.sh`、
   source 自 caller）均验过 OK。反例用例不受影响（拒绝路径不依赖锚点正确性——反而更早拒绝）。

## §6 回退（整批）

```sh
git checkout -- scripts/odirect-sha.py scripts/flash-b.sh scripts/trial.sh scripts/build-boot.sh \
                scripts/uefi-flashed-trial.sh scripts/linux-state-audit.sh scripts/n5b-vk64-death-rate.sh
# 归档 3 件（如需）：
awk -F'\t' '$1!~/^#/ && $1!="原名"{print "mv archive/scripts-stale-20261123/"$1" scripts/"$1}' \
  archive/scripts-stale-20261123/MANIFEST.tsv | sh
# serial-logger.sh 头注（唯一新增头注）：git checkout -- scripts/serial-logger.sh
```
