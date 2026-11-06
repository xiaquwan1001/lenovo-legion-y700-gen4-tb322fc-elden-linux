# 门禁记录 — M3-1 dwc3 v7（2026-11-06）

> 全部在本机实跑，命令与输出摘自 `artifacts/`。判据按项目惯例：**不看 rc 的地方写明**
> （`dt-validate` rc 恒 0、`make dt_binding_check` 的 STYLE 段缺 `ruamel.yaml`，两者都不作判据 —— `PITFALLS #470/#471`）。
> 树 = `build/m3v2-7.3rc7`（分支 `m3v7`，tip `07ab397efd`），base = `24a19b953e2a3d0ea5a8c4951a0ab8f32720c907`。

## 0. 一页结论

| # | 门禁 | 结果 | 证据 |
|---|---|---|---|
| G1 | `checkpatch.pl --strict`（stdin 喂 mbox） | **PASS** 3/3：0 errors / 0 warnings / 0 checks（138 / 63 / **553** 行） | `artifacts/checkpatch.log` |
| G2 | `scripts/check-series-selfcontained.sh` | **PASS**：4 文件按序重放，`WARN=0` | `artifacts/selfcontained.log` |
| G3 | `make W=1`（dwc3 + roles，19 个 glue 全 `=m`） | **PASS**：rc=0，**0 warning / 0 error**（源文件 touch 后强制重编） | `artifacts/build-w1.log` |
| G4 | `dt-doc-validate`（binding 那枚，dtschema 2026.9） | **PASS**：rc=0，无输出 | `artifacts/dt-doc-validate.log` |
| G5 | pristine `git am` 逐枚 + 终态比对 | **PASS**：3/3 rc=0，终态与系列 tip **逐字节相同**（`git diff --stat` 空） | `artifacts/pristine-am.log` |
| G6 | `git send-email --dry-run`（只 dry-run） | **PASS**：rc=0，4 封（1 cover + 3 补丁）全 `Result: OK` | `artifacts/send-email-dry-run.log` |
| G7 | `make dt_binding_check DT_SCHEMA_FILES=…` | **不作判据**：`STYLE` 段 `ModuleNotFoundError: ruamel.yaml`（环境缺件，与补丁无关）；真正的 binding 判据 = G4 | 见 §4 |
| G8 | `b4 send --dry-run` | **未证（环境缺件）**：本机无 `b4` | — |

## 1. G1 checkpatch

```sh
cd build/m3v2-7.3rc7
for p in patches/upstream/m3-dwc3-v7-20261106/000[123]-*.patch; do
  cat "$p" | perl scripts/checkpatch.pl --strict --patch -
done
```

```
0001-dt-bindings-… : total: 0 errors, 0 warnings, 0 checks, 138 lines checked
0002-usb-roles-…    : total: 0 errors, 0 warnings, 0 checks, 63 lines checked
0003-usb-dwc3-…     : total: 0 errors, 0 warnings, 0 checks, 553 lines checked
```

（喂法为 `--patch -` + stdin，避免 `PITFALLS #474` 的文件参数伪 ERROR；v6 时 3/3 是 441 行，v7 因两条 High 的修复增至 553。）

## 2. G2 系列自足性

```sh
bash scripts/check-series-selfcontained.sh patches/upstream/m3-dwc3-v7-20261106 \
  24a19b953e2a3d0ea5a8c4951a0ab8f32720c907 --repo build/m3v2-7.3rc7
```

```
ok 0001 / ok 0002 / ok 0003
PASS  m3-dwc3-v7-20261106: 全部 4 个文件按序重放成功于 24a19b953e…
== 汇总: PASS=3 FAIL=0 WARN=0 退出码=0 ==
```

## 3. G3 编译

```sh
cd build/m3v2-7.3rc7
touch drivers/usb/dwc3/core.c drivers/usb/dwc3/drd.c drivers/usb/roles/class.c
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 \
     drivers/usb/dwc3/ drivers/usb/roles/
```

`rc=0`；`grep -icE 'warning:|error:'` = **0**；产出含 `dwc3.o`（含 `core.o`/`drd.o`/`debugfs.o`）与 `roles/built-in.a`。
`-j26`：主机 28 线程，按项目规则留 2 个 P 核给交互。

## 4. G4 / G7 binding

```sh
export PATH=$HOME/.local/opt/dtschema-venv/bin:$PATH
dt-doc-validate Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml   # rc=0，无输出
```

`make dt_binding_check` 在本机不可用（`scripts/dtc/dt-check-style` 需要 `ruamel.yaml`，未装）⇒ **只作参考、不作判据**；
1/3 相对 v6 **逐字节未变**（`git diff m3v6 m3v7 -- ...yaml` 为空），其形状探针结论沿用
`patches/upstream/m3-dwc3-20261104/GATES.md` §5（`boardshape` 0 行诊断、4 个负例全 REJECT）。

## 5. G5 pristine 重放

```sh
git worktree add --detach /tmp/amcheck2 24a19b953e
for p in …/000[123]-*.patch; do git am -q "$p"; done
git diff --stat 07ab397efd HEAD      # 空 ⇒ 终态与系列 tip 逐字节相同
```

```
am ok 0001 / am ok 0002 / am ok 0003
--- diff vs series tip:
(empty = identical)
```

## 6. G6 发信形态

```sh
git send-email --dry-run --thread --no-chain-reply-to --suppress-cc=all \
  --to=gregkh@linuxfoundation.org patches/upstream/m3-dwc3-v7-20261106/000[0-3]-*.patch
```

4 封全 `Result: OK`；`In-Reply-To`/`References` 只挂 cover（`<20261106110948.923409-1-…>`），MID 连续。

## 7. 与上一版的差异（唯一）

`git -C build/m3v2-7.3rc7 diff --stat m3v6 m3v7`：

```
 drivers/usb/dwc3/core.c | 48 ++++++++++++++++++++++++++++++--
 drivers/usb/dwc3/core.h |  4 ++++
 drivers/usb/dwc3/drd.c  | 51 +++++++++++++++++++++++++++++++++---------
 3 files changed, 92 insertions(+), 11 deletions(-)
```

⇒ 1/3、2/3 零变化；3/3 的变化**只有** H1/H2 两组修复。
