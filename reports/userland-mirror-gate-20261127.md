# 用户态镜像一致性门（T9，A9/A10）— 2026-11-27

## 交付物

| 件 | 说明 |
|---|---|
| `scripts/check-userland-mirror.sh` | 新增。三态门：`--check`（默认，只读比对）/ `--diff <名>`（逐字 diff）/ `--selftest`（临时目录正反样本）。退出码 0=配对/白名单豁免，1=白名单外漂移，2=SKIP |
| `scripts/doctor/32-userland-mirror.sh` | 新增。doctor §32 = §32a 镜像门 + §32b `verify.sh --offline`，只进全量档 |
| `scripts/check-doctor.sh` | 仅追加：子门清单加 `32-userland-mirror.sh` + 两行注释（§31 已被 2026-11-26 的 reports-index 占用，故编号顺延为 32） |

未改动任何 `packaging/elden-userland/files/**` 与 `scripts/**` 现有文件内容。

## 三态判据

对 `packaging/elden-userland/files/**` 每个文件，在 `scripts/**` + `rootfs/persistent-overlay/**` 找同名副本：

- 同 sha 副本存在 ⇒ **OK**（配对 20 对，本次实测）
- 同名但全部不同 sha：
  - 文件名在脚本内置 `WHITELIST`（13 组，每条注明「待用户裁定权威归属」）⇒ **WARN**，exit 仍 0
  - 不在白名单 ⇒ **FAIL**，exit 1（同内容对日后漂移必中此分支，防门空转）
- 无同名副本 ⇒ 设备专有件（合法，本次 78 个）
- 缺 `packaging/elden-userland/files/` 或缺 `sha256sum` ⇒ **SKIP（exit 2）**，不得计成 PASS

## 本次 --check 实测（2026-11-27）

```
同 sha 配对 20 ｜ 白名单漂移(WARN) 14 ｜ 白名单外漂移(FAIL) 0 ｜ 设备专有件(无副本) 78
```
14 个漂移对 = 13 组（`slot-attr.py` 在 files 内部 bin/sbin 两份同 sha，对应 A9 表）。

## 13 组漂移逐组（现状 / 哪边看着更新 / 待裁定问题）

| # | 文件 | 差异行 | files/ mtime | 对侧 mtime | 哪边看着更新 | 待裁定问题 |
|---|---|---|---|---|---|---|
| 1 | `init` | **380** | 10-26 22:49 | 10-26 18:42 (rootfs) | files/（同日晚 4h） | 两份不同代的 `/init`；装错即起不来。哪份是设备上现在跑的？以哪份为权威重生成另一侧？ |
| 2 | `charge-watch.sh` | **189** | 11-12 21:03 | **11-26 11:21** (scripts) | **scripts/ 更新 14 天** | 已上线充电服务件；scripts/ 侧的 2026-11-26 改动是否已部署到设备？ |
| 3 | `q28-watchdog.sh` | 52 | 11-16 16:20 | **11-17 12:36** (scripts) | scripts/ 更新 1 天 | 已上线看门狗；同上，scripts/ 新版部署状态不明 |
| 4 | `time-sync.sh` | 43 | **11-19 13:03** | 10-17 10:08 (scripts) | **files/ 更新**（含 flock 串行化 + 先停 chronyd，注释落款 2026-11-19） | 设备快照反而更新：scripts/ 权威源落后于设备，需回灌 |
| 5 | `net-up.sh` | 38 | 10-26 22:26 | 10-17 10:08 (scripts) | files/ 更新 9 天 | 同上，scripts/ 落后 |
| 6 | `ath12k-load.sh` | 34 | epoch-0（1970，tar 无 mtime） | **11-23 09:38** (scripts) | scripts/ 更新 | 已上线 Wi-Fi 固件装载件；files/ 无可靠 mtime，需按内容裁定 |
| 7 | `q28-boot-watchdog.sh` | 20 | 11-16 16:20 | 10-17 10:08 (rootfs) | files/ 更新（arch-audit B4） | 三处副本（scripts 侧未计入本组）到底哪份在设备上跑？ |
| 8 | `scale.sh` | 10 | 09-30 16:15 | **10-17 10:08** (scripts) | scripts/ 更新 | 小件，方向：scripts 新 |
| 9 | `slot-attr.py` | 25 | 11-18 18:54 | **11-19 13:42** (scripts) | scripts/ 更新 | scripts 新；另需裁定 files 内 bin/sbin 两份同 sha 是否都保留 |
| 10 | `openrc-enable.sh` | 8 | 10-13 11:12 | **10-19 20:03** (scripts) | scripts/ 更新 | scripts 新 |
| 11 | `sleep-bisect.sh` | 9 | epoch-0 | **11-23 10:52** (scripts) | scripts/ 更新 | 调试件；files/ 无可靠 mtime |
| 12 | `sleep-cumulative.sh` | 8 | epoch-0 | **11-23 10:52** (scripts) | scripts/ 更新 | 同上 |
| 13 | `camera-modules-load.sh` | 3 | epoch-0 | 10-17 10:08 (scripts) | scripts/ 更新 | 仅 3 行差，最小代价先归并 |

**方向统计**：scripts/（权威源名义上）更新 9 组；files/（设备快照）反而更新 3 组（`init`、`time-sync.sh`、`net-up.sh`）——即「`scripts/` 是权威副本」这句 README 口述在至少 3 组上是反的，须逐组裁定后回灌或重部署。

## selftest 输出（摘录）

```
--- selftest 反样本（未登记漂移 rogue.sh + 白名单漂移 charge-watch.sh）exit=1 ---
  [FAIL] DRIFT(未登记) rogue.sh：…内容不同且不在白名单
  [warn] DRIFT(白名单) charge-watch.sh：…
汇总：同 sha 配对 1 ｜ 白名单漂移(WARN) 1 ｜ 白名单外漂移(FAIL) 1 ｜ 设备专有件(无副本) 1
--- selftest 正样本（rogue.sh 修成同 sha）exit=0 ---
汇总：同 sha 配对 2 ｜ 白名单漂移(WARN) 1 ｜ 白名单外漂移(FAIL) 0 ｜ …
SELFTEST OK：反样本 FAIL=1 / 正样本 PASS=0，退出码符合契约
```

## verify.sh --offline 接线核查（A10）

- `verify.sh` **确有 `--offline` 档**（F 段整段跳过：`ok "--offline：跳过"`），A–E + G 全跑，实测 **FAIL=0 WARN=0**（23 服务 / 118 行 MANIFEST / 19+19 unit）。
- **零写盘核查**：无设备连接（F 段跳过，无 ssh）；`git status` 前后逐字节一致。唯一副作用 = D 段 `render.py` 把派生目录 `out/units/`（**已入 git 跟踪**）幂等再生成，mtime 更新但内容与 HEAD 逐字相同 —— 非内容写盘，判定可接。
- doctor §32b 即跑该档，退出码 0 ⇒ `[ok]`。

## doctor 新节 §32 输出

```
== 32-userland-mirror.sh ==
  [ok] 镜像一致性门 PASS（同 sha 配对 20 ｜ 白名单漂移(WARN) 14 ｜ 白名单外漂移(FAIL) 0 ｜ 设备专有件(无副本) 78）
  [ok] packaging verify.sh --offline：FAIL=0（41 条 ok，A–E/G 段）
```

## 关于 doctor WARN 计数的说明（唯一例外申报）

镜像门自身把 13 组漂移记为 `[warn]`（14 行），但 doctor §32a **有意不透传**为 doctor 级 `[warn]`，只打 `[ok]` + 两条 `info` 指引——否则 doctor WARN 会从 3 涨到 17。理由：这 14 行全部是**已显式登记、待用户裁定**的存量漂移（本报告逐组列出），不是新增异常；异常（白名单外漂移）走 `[FAIL]` 通道，doctor 仍会 FAIL。存量 WARN=3 不变。

最终全量复跑：`bash scripts/check-doctor.sh --json` ⇒ `{"fail":1,"warn":3,"profile":"full",…含 32-userland-mirror.sh}`，与基线逐字一致（存量 fail=1 为 §13 `scripts/checkpatch.pl` 资产引用，非本任务引入）。

## 复现命令

```bash
bash scripts/check-userland-mirror.sh            # --check
bash scripts/check-userland-mirror.sh --diff charge-watch.sh
bash scripts/check-userland-mirror.sh --selftest
bash scripts/check-doctor.sh --only 32
bash scripts/check-doctor.sh --json | tail -1    # fail/warn 对账
```
