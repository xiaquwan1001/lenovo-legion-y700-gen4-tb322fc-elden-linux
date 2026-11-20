# scripts/README.md 索引新鲜度门（check-doctor §24）— 2026-11-20

arch-audit P1#3 收尾件：本轮落了 `scripts/gen-scripts-index.py`（`--check` rc=1 = README 过期）
与生成的 `scripts/README.md`（334 入口，含本轮新增的门自身），本件防止它随脚本增改静默过期。

## 设计

- 新增 `scripts/doctor/24-scripts-index.sh`（委托 `gen-scripts-index.py --check`），注册进
  `scripts/check-doctor.sh`（编号 24，含头部注释，进 ALL 数组）。
- **只进全量档**：`--check` 全量重建引用语料，单次实跑 ~5 s（含反作弊共 ~10 s），不进 FAST 数组。
- **三态**：
  - `--check` rc=0 ⇒ `[ok]`；
  - rc≠0 ⇒ `[FAIL]`，提示「跑 python3 scripts/gen-scripts-index.py 重新生成」；
  - 环境缺 python3 ⇒ `[warn] SKIP`（不装成 PASS）；生成器/README 缺失 ⇒ `[FAIL]`。
- 附加廉价断言：README 存在且首行是生成器标记（`本文件由 …gen-scripts-index.py 生成`），
  手改/换件先在此拦截。

## 反作弊自检（照 §17/§23 口径：门自己空转 = 比没有门更糟）

- 实现：备份真件到临时文件 → `sed -i '12d'` 删掉正文一行 → 对真路径跑 `--check`，
  断言 rc≠0（判过期）→ `trap` + 显式 `mv` 双保险无条件还原。
  说明：`--check` 的对账目标路径固定为 `scripts/README.md`（`OUT_MD` 硬编码，不支持指向副本），
  所以坏副本只能就地替换真件、跑完立即还原；trap 兜底保证中途异常也不留坏件。
- 不许用「直接跳过」实现通过：自检失败即 `[FAIL] 门空转（恒真）`。
- 实测：坏副本 rc=1 被抓到 ⇒ `[ok] 反作弊自检通过`。

## 三态验证（原始输出）

1) 独立入口：`timeout -k 3 60 bash scripts/check-doctor.sh --only 24`
```
== 24. scripts/README.md 索引新鲜度（生成器 ↔ 磁盘对账） ==
  [ok]   反作弊自检通过（坏副本：删一行 ⇒ --check rc=1 判过期，门在读内容）
  [ok]   scripts/README.md 最新（OK scripts/README.md 最新（334 个入口））

== 汇总: FAIL=0  WARN=0 ==
```
2) 全量：`timeout -k 3 300 bash scripts/check-doctor.sh` ⇒ **FAIL=0，WARN=6**
   （6 条全为既有存量：geekidos-linux 已档身份暂不可核、vk 账本登记例外、内核段不可读、
   ABI/模块化门因无构建树跳过——§24 未新增任何 WARN/FAIL）
3) 负向（故意 `sed` 把「入口总数 334」改成 999）：
```
  [ok]   反作弊自检通过（坏副本：删一行 ⇒ --check rc=1 判过期，门在读内容）
  [FAIL] scripts/README.md 过期（rc=1）→ 跑 python3 scripts/gen-scripts-index.py 重新生成

== 汇总: FAIL=1  WARN=0 ==
```
   还原后重跑 ⇒ FAIL=0，且 `cmp` 确认与备份逐字一致。

## 误报防护

- 本门自身落盘（24 号脚本）会让索引 +1 ⇒ 需先 `python3 scripts/gen-scripts-index.py`
  重新生成（实测 334 个入口），生成器与门是自洽闭环：新增脚本 → 生成 → `--check` rc=0。
- 本报告自身曾被 §13 判「报告无人引用」WARN ⇒ 已在 `INDEX.md` §0 主机侧清单落指针（⑤），
  引用数变化后重新生成 README，全量复跑 WARN 回到 6 条存量。
- 还原路径双保险（显式 mv + trap），负向测试后真件逐字复原。
- 引用语料排除生成器与 README 自身（生成器内置），引用数与 mtime/时钟无关 ⇒ 判定确定、无抖动。

## 耗时

- 单独实跑（反作弊 + 对账）：~10.3 s（`--check` 单次 ~5 s × 2）。
- 全量 doctor 仍为 FAIL=0；FAST 档不受影响（24 不在 FAST 数组）。

## 追加（2026-11-20 grow-loop #5）：新鲜度判据从「全文重渲染比对」改为「结构指纹」

**问题（#4 实测踩两次）**：原 `--check` 比的是「重渲染全文 == 磁盘全文」，而渲染里含**引用计数**
（全仓文档提到该 basename 的行数）⇒ **任何文档改一行，索引就判过期**。门变成噪声，人会直接绕开。

**改法（`scripts/gen-scripts-index.py`）**：
- 新增 `structural_fp(entries)` = sha256(路径/分组/名字/shebang/头注释一句话)[:16]，写进 README 第 1 行注释；
- `--check` 走 `collect(scan_refs=False)`（**不扫引用语料**，耗时 ~10 s → ~2 s），只比结构指纹；
- 指纹不符时打印 `fp 旧 → 新` 并提示重新生成；指纹相符但引用计数漂移 ⇒ 仍 rc=0，附一句「引用计数已漂移，按设计不判过期」。

**三态实测**：

| 场景 | 结果 |
|---|---|
| 改一处无关文档（`PITFALLS/README.md` 末尾加一行 `<!-- probe: check-doctor.sh -->`） | `--check` **rc=0**（附「引用计数已漂移…」）⇒ 噪声消除 |
| 新增 `scripts/zz-probe.sh` | `--check` **rc=1**，`fp 8c15faee… → 004f2f79…` |
| 撤掉该脚本 | `--check` **rc=0** |
| §24 反作弊（改坏指纹 / 临时加脚本两方向） | 均 **rc≠0** 被抓到，撤掉后 rc=0 |

**代价**：结构指纹不含引用计数 ⇒ 「引用数变了但结构没变」时 README 里的数字会旧到下次重新生成为止（可接受，数字是参考量，不是判据）。
