# M3-1 v5 pristine 重放（投递前必修项）—— 2026-10-30

> 派工单：把 `m3v5-fix-20261030` 两枚（daily 基线 24223e44ad）重放到上游 pristine v7.3-rc7 之上，
> 终态与 `build/m3v5-fix` 对应文件逐字节一致，重出可投递的 v5 系列。
> **未编译整内核、未上机、未投递、未发邮件、未改主仓 main**（工作树内 2 个本地 commit，未 push）。
> 只写：`build/m3v5-pristine`（新建 worktree）、`patches/upstream/m3v5-20261030/`、本报告。

## §0 一页结论

| 项 | 结果 |
|---|---|
| pristine 重放 | **成功，无损**：pristine 24a19b953e + v4 三枚 + v5 增量 ⇒ 6 文件与 `build/m3v5-fix` **逐字节一致**（§3 表） |
| v5 增量相对 v4 | 0001 binding **55+/50−**（仅 `snps,dwc3-common.yaml`）；0002 driver **85+/27−**（core.c/core.h/drd.c/class.c，4 文件）；`debugfs.c` 与 `ucsi.c` **零增量**（§4 说明） |
| 重出补丁 | `patches/upstream/m3v5-20261030/v5-000{1,2}-*.patch`（185/310 行），0001 仅 binding / 0002 仅 driver |
| checkpatch --strict | v5-0001 **0E/0W/0C**（142 行）；v5-0002 **0E/0W/0C**（222 行） |
| dt-doc-validate | **rc=0，无输出** |
| 独立复放验证 | 在临时 worktree（fd69bd54e3 = pristine+v4 tip）上 `git apply` 两枚 v5 ⇒ 5 文件 SAME（§3） |
| 语义冲突 | **无**。唯一注意点：F2（ucsi.c）相对 pristine 是**无操作**（§4-2） |

**一句话**：v4 三枚在 pristine 上干净 am，v5 增量（402 行 diff）干净 apply，终态六文件与 fix 树逐字节一致；
重出的 v5 两枚补丁 0E/0W/0C、binding 元 schema 通过，可投递（投递本身仍需用户批准，不在本轮）。

## §1 版本谱系

| 目录 | 内容 | 基线 |
|---|---|---|
| `m3-2026-10-13`…`m3-6-*` | 首轮 M3 切片（历史） | — |
| `m3-v2-2026-10-17` | v2 两枚（sashiko 12 条） | pristine |
| `m3-v3-2026-10-19` | v3 形状 RFC 两枚 | pristine |
| `m3-v4-20261026` | **v4 三枚，已投递**（`<20261026123211.243224-1..4-…>`） | pristine 24a19b953e |
| `m3v5-fix-20261030` | v5 两枚（A–J + 形状改定 + F1） | **daily 24223e44ad**（不可直接投递） |
| `m3v5-20261030`（本轮） | **v5 两枚 pristine 重出** | pristine 24a19b953e + v4 三枚 |

语义边界（依 `reports/m3-v4-series-20261026.md`、`m3v5-fix-20261030.md` §2、`m3v5-binding-reshape-20261030.md` §1）：
v5 = v4 三枚 + ① binding 形状改定（两连接器 = `port@0`+`port@2`，各一 endpoint，`mux-state` 落 endpoint；
D/J-1/J-2 校验面收紧）+ ② driver A–J/F1 修复。daily 基点 24223e44ad 的六文件是 **v2 形状**
（payload v2 commit 0f1fb1c9c1 引入），故 `m3v5-fix` 的补丁含 v2→v4 重写；本轮在 pristine+v4 上只落真正的增量。

## §2 重放命令（全部 `timeout -k` 内执行）

```sh
# 1) pristine worktree（pristine 对象在 payload 内核仓 build/m3v2-7.3rc7/.git）
git -C build/m3v2-7.3rc7 worktree add --detach /home/xuqianhui/y700-elden/build/m3v5-pristine 24a19b953e
cd build/m3v5-pristine
# 2) v4 三枚干净 am
git am ../../patches/upstream/m3-v4-20261026/0001*.patch \
        ../../patches/upstream/m3-v4-20261026/0002*.patch \
        ../../patches/upstream/m3-v4-20261026/0003*.patch
# → 46bd127690 / a0a5d3f1f5 / fd69bd54e3，全部无冲突
# 3) v5 增量 = fix 树六文件 与 本树(v4) 六文件 的 diff（402 行），生成后 reset + apply：
#    /tmp/m3v5-delta-vs-v4.diff（六文件：yaml, roles/class.c, dwc3 core.c/core.h/drd.c/debugfs.c）
git apply --check /tmp/m3v5-delta-vs-v4.diff && git apply /tmp/m3v5-delta-vs-v4.diff
# 4) 两枚 commit（0001 仅 yaml / 0002 仅 4 个驱动文件；提交说明取自 m3v5-fix 同名提交 1da8f23155/7abd1781e9）
# 5) 重出
git format-patch -v5 -2 -o ../../patches/upstream/m3v5-20261030/
# 6) 门禁
perl scripts/checkpatch.pl --strict --no-tree ../../patches/upstream/m3v5-20261030/v5-000*.patch
~/.local/opt/dtschema-venv/bin/dt-doc-validate Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml
```

## §3 终态一致性证据（sha256，对 `build/m3v5-fix` 工作区文件）

| 文件 | sha256（前 16 位） | 判定 |
|---|---|---|
| `Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml` | f74763e2b32fb069 | **SAME** |
| `drivers/usb/roles/class.c` | 301464ac7ef81c8a | **SAME** |
| `drivers/usb/dwc3/core.c` | a0b5bb385f662a83 | **SAME** |
| `drivers/usb/dwc3/core.h` | 144ba2169861720f | **SAME** |
| `drivers/usb/dwc3/debugfs.c` | 7e3d62dcc0140677 | **SAME** |
| `drivers/usb/dwc3/drd.c` | c354808dd0892f23 | **SAME** |
| `drivers/usb/typec/ucsi/ucsi.c` | a9574a273c1ae705 | **DIFF（预期，见 §4-2）** |

独立复放（临时 worktree @ fd69bd54e3，仅 apply 两枚重出补丁，验毕已删）：五文件（yaml + 4 驱动文件）全部 **SAME**；
`debugfs.c` v4 已与 fix 树一致，v5 增量为零，未列入。

## §4 语义边界说明（关键差异点）

1. **`debugfs.c` 零增量**：`m3v5-fix-20261030` 的 0002 含 debugfs.c 一行注释改动，但那是 **v4 0003 已带**的内容
   （daily 基点是 v2 形状才显得它是新增）；pristine+v4 上终态已一致，v5-0002 不含该文件。
2. **F2（ucsi.c）相对 pristine 是无操作**：fix 树的 F2 = 删掉 `con->usb_role_sw = NULL;`（8+/1−，
   见 `build/m3v5-fix` 工作区 diff vs 24223e44ad）。但 pristine 的 `ucsi.c:1849-1851` 本来就是
   `if (IS_ERR(...)) return dev_err_probe(...)` 直接上抛——「置 NULL 继续」是 daily 下游基点引入的行为。
   ⇒ v5 系列在 pristine 语义下**不需要也不应含 ucsi.c 改动**；fix 树 ucsi.c 的其余差异
   （`ucsi_partner_has_usb()` 等）来自 payload v2 commit，与 M3-1 无关，不投递。
   该处已按派工单要求显式记录（文件以 `build/m3v5-fix` 当前内容为准）。
3. **三个 glue 签名适配（dwc3-qcom/imx/imx8mp 的 `pre_set_role` void 化）不进补丁**：
   pristine 本就是 void 签名，daily 基点才带 int 返回（`m3v5-fix-20261030.md` §3）。重放树上无此问题。
4. **binding 0001 的 EOF 空行**：pristine/v4 的 yaml 末尾带一个空行（daily 不带），
   重出补丁基于 pristine+v4，故 `new blank line at EOF` 提示不再出现（checkpatch 0 提示实证）。

## §5 门禁数字（本机实跑，2026-10-30）

| 门 | 对象 | 结果 |
|---|---|---|
| checkpatch --strict | `v5-0001-…patch` | `total: 0 errors, 0 warnings, 0 checks, 142 lines checked`，"ready for submission" |
| checkpatch --strict | `v5-0002-…patch` | `total: 0 errors, 0 warnings, 0 checks, 222 lines checked`，"ready for submission" |
| dt-doc-validate | `snps,dwc3-common.yaml`（重放树内） | rc=0，无输出 |

## §6 产物

| 内容 | 路径 / 值 |
|---|---|
| v5 补丁 | `patches/upstream/m3v5-20261030/v5-0001-…patch`（sha256 213c882cf75a1ea4…，185 行）；`v5-0002-…patch`（81d85749d101f34a…，310 行） |
| 重放树 | `build/m3v5-pristine`（detached：24a19b953e + v4 三枚 46bd1276/a0a5d3f1/fd69bd54 + v5 两枚 0edc5c33/34865c89；工作区干净） |
| 增量 diff 存档 | `/tmp/m3v5-delta-vs-v4.diff`（402 行，v4→v5 全部语义增量） |
| 上游基点 | pristine `24a19b953e`（Linux 7.3-rc7，对象在 `build/m3v2-7.3rc7/.git` 共享仓） |

## §7 未做 / 未证实

1. **未编译整内核**（派工单禁止；仅依赖静态一致性，driver 编译门禁由 fix 树 `make W=1` rc=0 记录间接覆盖——
   文件逐字节一致 ⇒ 编译结果等价，本轮未复跑编译）。
2. **未上机**：A/C/E/G 等运行期行为仍无设备证据（同 `m3v5-fix-20261030.md` §6）。
3. **未投递**：`patches/upstream/m3v5-20261030/` 仅供投递使用，发送需用户批准；cover letter 未写（v4→v5 增量说明可由本报告 §1/§4 提炼）。
4. **未证实项**：重放树未跑 `dtbs_check`/`make dt_binding_check`（同前几轮禁令）；binding 正确性证据 = dt-doc-validate + fix 树已有的 5 例 schema 探针（形状已改定，探针记录在 `m3v5-binding-reshape-20261030.md` §2）。
5. **无语义冲突**：v4→v5 增量在 pristine 上无损 apply，无需任何手工调和；`/tmp/m3v5-delta-vs-v4.diff` 即完整的语义增量，可逐 hunk 复核。
