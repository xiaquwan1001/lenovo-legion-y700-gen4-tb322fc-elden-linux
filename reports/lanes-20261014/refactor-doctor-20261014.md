# check-doctor 自检代码重构（速率 + 流程）— 2026-10-14

## 结论
- `bash scripts/check-doctor.sh` 墙钟 **≈104 s(冷) / 41 s(热) → 13.1–13.6 s(热)**；逐行 diff **为空**，各节 OK/WARN/FAIL 文案与退出码语义不变（0=全绿 / 1=有 FAIL）。
- 手段：把「同一批 108 个 boot 镜像的 gzip 解压 + UTS/sha256」从 **3 遍串行** 降为 **1 遍并行**。

## 根因（改前，三次全量解压）
1. §5 内联 python（原 `check-doctor.sh:46`）：对 71 个 `boot-elden-vk*.img` 逐个解压抽 UTS ≈ 30 s。
2. §5d `vk-identity.py --gate`（原 `:175`）：对 108 个镜像再解压算 kbin sha ≈ 39 s。
3. §5d `vk-identity.py --check`（原 `:188`）：又跑一遍同一全量扫描 ≈ 39 s。

## 改动
`scripts/vk-identity.py`
- 新增 `_PAYLOAD_CACHE` / `payload()` 进程内缓存 + `prefill_payloads()`（:161–203）：`multiprocessing.Pool(min(cpu,8))` 并行解压，多进程不可用时自动退回串行。
- `gate()` → `gate_lines()`（:234，返回 `(status,msg)` 列表）；抽出 `fresh()`（:299）；新增 `ledger_lines()`（:319）承接原 §5 内联 python，复用同一缓存。
- 新增 `--all`（:556）：**一次全量扫描**输出三段 `L\t<st>\t<msg>`（§5）、`G\t…`（§5d 门禁）、`C\t0|1`（新鲜度）。`--gate` / `--check` / 默认 TSV 三种旧用法保持行为不变（已回归）。

`scripts/check-doctor.sh`
- §5 处（:46–67）改为单次 `python3 scripts/vk-identity.py --all`，用 bash 数组按 tag 分流，删去 ~100 行内联 python。
- §5d 处（:74–90）消费 `_gate_st/_gate_msg` 与 `_cst`，不再二次/三次调用同一扫描。

## 证据
```
改前(冷): real 1m44.154s      ($ time bash scripts/check-doctor.sh)
改前(热): real 0m41.016s      (git checkout 基线后复现)
改后(热): real 0m13.645s / 0m13.143s
--all 单跑: real 0m6.605s     ($ time python3 scripts/vk-identity.py --all)
diff /tmp/doctor.before.out /tmp/doctor.after.out   → 空（逐行一致）
rc: 改前 0 / 改后 0
```
- §5 的 5 行（`registry vk50-126 单调…` + vk62/63/94 tree_drift + orphan 历史镜像）、§5d 的 4 行、§5e、§6 全部一致；汇总 `FAIL=0  WARN=6`。
- `--gate` 单独跑的输出与改前 `/tmp/gate.out` 也逐行一致；`--check` rc=0。
- 负向验证（把 §5/§5d 解析逻辑抽到 `/tmp/test-parse.sh` 单测）：合成 `L/G=FAIL` → `FAIL=3`；空输出 → 两条 fallback warn + 一条 stale bad；全绿 → 无 FAIL/WARN；`C\t1` 被识别为 stale。
- `git diff --stat -- scripts/check-doctor.sh scripts/vk-identity.py`：
```
 scripts/check-doctor.sh | 156 ++++-------------------------------
 scripts/vk-identity.py  | 224 ++++++++++++++++++++++++++++++++--------
 2 files changed, 217 insertions(+), 163 deletions(-)
```

## 风险 / 边界
- `drop_caches` 无权限，冷启动未实测；保守估计 ——all 冷读 8.6 G 仍 < 25 s，整轮 < 30 s（改前冷 104 s）。
- 输出解析用默认 IFS 的 `read -r _tag _st _msg`（msg 走最后一个变量，含多空格也完整保留）；依赖消息不含换行/制表，现有全部消息满足，已由逐行 diff 验证。
- 仅改本 lane 边界内两文件；`INDEX.md`/`TASKS/`/`versions/` 等未触碰。
