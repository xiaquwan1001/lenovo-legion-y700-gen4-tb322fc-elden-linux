# 退役脚本（2026-10-15）

一次性的 Q24 / Q28 调查脚本，已从 `scripts/` 移出。移出理由：它们是**逐轮实验的驱动脚本**，每轮结论已固化进 `reports/q24-*-20261012.md` / `reports/q28-*-20261012.md` 与 `PITFALLS/`，脚本本身不再复用；留在 `scripts/` 里会让真正在用的工具淹没在 32 个一次性件里。

## 移出的 32 个

- `q24-*`（18）：`build-h1-dtarm`、`cseries-run`、`dev-blank`、`dev-dstate`、`dev-keepawake`、`dev-sess`、`dev-snap`、`dev-trace-on`、`instrument-check`、`kill`、`mech-run`、`mxnom-sweep`、`noc-run`、`pmic-cycle`、`pmic-diff`、`pmic-dump`、`rebuild-arms`、`s123-run`
- `q28*`（14）：`ab-delay`、`boot-cycle`、`build-arm-lv64`、`build-daily-id`、`build-oldrep-pin`、`cold-run`、`layout-ab`、`layout-experiment`、`layout-one`、`por-queue`、`race-hunt`、`verdict`、`warm-vk117-loop`、`q28diag-forensic`

## 保留在 `scripts/` 的 3 个（仍在用）

| 脚本 | 为什么留 |
|---|---|
| `q28-watchdog.sh` | 运营兜底（坏发自动重启），日常 boot_b 用 |
| `q28-devprobe.sh` | 被 `scripts/trial.sh` 调用（开机判据探针） |
| `q28-devprobe2.sh` | 三态判据（NOCARD/STORM/GOOD）现行探针 |

## 注意

- 归档后的脚本内部仍写 `scripts/xxx.sh` / `$ROOT/scripts/...` 路径，**不能直接原样重跑**；需要时把它们复制回 `scripts/` 或改路径。
- `scripts/lib-boot-ready.sh` 的消息引用已改指本目录。
- 历史报告（`reports/q24-*.md`、`reports/q28-*.md` 等）里出现的 `scripts/q24-*` / `scripts/q28-*` 路径按当时状态记录，未回改。
