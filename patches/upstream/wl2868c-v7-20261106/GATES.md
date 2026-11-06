# 门禁记录 — wl2868c v7（2026-11-06）

> 树 = `build/m3v2-7.3rc7`，分支 `wl7b`（tip `10555ad6cc`），base = `24a19b953e2a3d0ea5a8c4951a0ab8f32720c907`。
> 板件（held-back）在分支 `wl7board`（`8de8a5a52b`），单独记在 §7。

## 0. 一页结论

| # | 门禁 | 结果 | 证据 |
|---|---|---|---|
| G1 | `checkpatch.pl --strict`（stdin 喂 mbox） | **PASS**：1/2 = 0/0/0（117 行）；2/2 = **0 errors / 0 warnings**（270 行）+ 1 条 `FILE_PATH_CHANGES` 说明见 §1 | `artifacts/checkpatch.log` |
| G2 | `scripts/check-series-selfcontained.sh` | **PASS**：3 文件（含 cover）按序重放，`WARN=0` | `artifacts/selfcontained.log` |
| G3 | `make W=1`（`drivers/regulator/`，`CONFIG_REGULATOR_WL2868C=m`） | **PASS**：rc=0，0 warning / 0 error，`wl2868c-regulator.o` 产出 | `artifacts/build-w1.log` |
| G4 | `dt-doc-validate`（binding，dtschema 2026.9） | **PASS**：rc=0，无输出 | `artifacts/dt-doc-validate.log` |
| G5 | pristine `git am` 逐枚 + 终态比对 | **PASS**：2/2 rc=0，终态与 tip **逐字节相同** | `artifacts/pristine-am.log` |
| G6 | `git send-email --dry-run` | **PASS**：rc=0，3 封全 `Result: OK` | `artifacts/send-email-dry-run.log` |
| G7 | held-back 板件 checkpatch / dtc | checkpatch **0 errors**（2 warnings：MAINTAINERS 启发式 + `willsemi,wl2868c` 未在本树（binding 不在这条分支）） | `artifacts/checkpatch-heldback.log` |

## 1. G1 checkpatch 与那条 `FILE_PATH_CHANGES`

```
0001-… : total: 0 errors, 0 warnings, 0 checks, 117 lines checked
0002-… : WARNING: added, moved or deleted file(s), does MAINTAINERS need updating?
         total: 0 errors, 1 warnings, 0 checks, 270 lines checked
```

checkpatch 的这条是**按补丁**判断的启发式：`scripts/checkpatch.pl:3073-3077` 只在**同一枚补丁**的 diffstat 里
出现 `MAINTAINERS |` 时才抑制它。本系列的 MAINTAINERS 条目在 **1/2**（与 yaml 同枚），2/2 又新增了 `.c` ⇒ 必然触发一次。
换成「MAINTAINERS 放 2/2」只是把这个警告挪到 1/2，除非把两枚并成一枚。
⇒ **记录为已知良性警告**，cover letter 里也写明，不作为缺陷。

## 2. G2 自足性

```sh
bash scripts/check-series-selfcontained.sh patches/upstream/wl2868c-v7-20261106 \
  24a19b953e2a3d0ea5a8c4951a0ab8f32720c907 --repo build/m3v2-7.3rc7
```

```
ok 0001 / ok 0002
PASS  wl2868c-v7-20261106: 全部 3 个文件按序重放成功于 24a19b953e…
== 汇总: PASS=2 FAIL=0 WARN=0 退出码=0 ==
```

## 3. G3 编译

```sh
cd build/m3v2-7.3rc7
scripts/config --file .config -m REGULATOR_WL2868C
make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
rm -f drivers/regulator/wl2868c-regulator.o
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 drivers/regulator/
```

`rc=0`；`CC [M] drivers/regulator/wl2868c-regulator.o`；`grep -icE 'warning:|error:'` = **0**。

## 4. G4 binding

```sh
export PATH=$HOME/.local/opt/dtschema-venv/bin:$PATH
dt-doc-validate Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml   # rc=0，无输出
```

## 5. G5 pristine 重放

```sh
git worktree add --detach /tmp/amwl 24a19b953e
for p in …/000[12]-*.patch; do git am -q "$p"; done
git diff --stat 10555ad6cc HEAD     # 空 ⇒ 逐字节相同
```

## 6. G6 发信形态

`git send-email --dry-run --thread --no-chain-reply-to --suppress-cc=all …` → 3 封 `Result: OK`（1 cover + 2 补丁）。

## 7. G7 held-back 板件（`wl7board`，`8de8a5a52b`）

```sh
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/sm8750-lenovo-elden.dtb
# → DTC arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb（通过）
```

checkpatch：`0 errors, 2 warnings` —— 两条都不是缺陷：
① `FILE_PATH_CHANGES`（同 §1 的启发式）；② `"willsemi,wl2868c" appears un-documented`
（这条分支上**没有** binding 文件，因为它属于 1/2；两枚合起来看是自洽的）。

**与 v6 的差别（重要）**：v6 的 4/5 把 `Makefile` 插入点写在 `sm8650-valve-deckard.dtb` 之后，
而 `v7.3-rc7` 的 `Makefile` **没有 deckard 这一行**（`grep -c sm8650-valve-deckard` = 0）⇒
**v6 4/5 对其声明的 base 不可 apply**。本版改为插在 `sm8750-mtp.dtb` 之前，`dtc` 通过。

## 8. 发信前重基到 torvalds master + 复跑（2026-11-06 11:4x）

- 新 base = `f66469d9905b39d2c260a15d7d6db450f4db67c1`（`git fetch --depth 1 torvalds master`，2026-11-06，7.4-rc2 线）
- `git rebase --onto torvalds/master 24a19b953e2a3d0ea5a8c4951a0ab8f32720c907 <branch>` ⇒ **无冲突**
- 复跑结果：checkpatch 同上（0 errors）；自足性 **PASS**（base 换成新 sha）；`make W=1` **0 warning**；
  `dt-doc-validate` rc=0；pristine `git am` **逐字节等价**（`git diff --stat` 空）
- **实发版本号 = `v8`**（首轮 11:28/11:30 那批 `format-patch` 漏 `-vN`，逐枚 Subject 无版本号 ⇒ 已重投并说明）
- 投递记录：`out/mail-20261106/REPORT.md`
