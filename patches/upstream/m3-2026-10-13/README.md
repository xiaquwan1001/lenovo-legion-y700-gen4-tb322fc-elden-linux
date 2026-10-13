# M3 板支持系列（2026-10-13）

上游基线：`torvalds/v7.3-rc7`（`24a19b953e`）；工作树 = `build/m2-worktree`，分支 `m3/usb-psy-name`。
规则 = `reports/upstream-policy-20261013.md`；分片与验收口径 = `reports/m3-series-plan-20261013.md`。

## 已备（未发送）

| 补丁 | 主题 | 状态 | 证据 |
|---|---|---|---|
| `0001-dt-bindings-usb-snps-dwc3-document-usb-psy-name.patch` | `dt-bindings: usb: snps,dwc3: document usb-psy-name` | ✅ 就绪（`checkpatch --strict` 0E/0W；`dt-doc-validate` rc=0） | 上游 `drivers/usb/dwc3/core.c` 读该属性而 `Documentation/` 无任何描述 ⇒ 用它的 DTS 必被 `dtbs_check` 拒；本补丁补文档。实测把板 DTB 对纯上游 binding 的 382 条诊断降到 380 |

## 待做（同片续作）

| 补丁 | 内容 | 说明 |
|---|---|---|
| 0002+ | `usb: dwc3: support two connectors sharing one HS bus` | 本地特性：`drd.c` 的 `dwc3_mux_role_set`/role-mux（+182 行）+ 端点 `mux-state` + `port-select-gpios` + 板 DTS `&usb` 段。需从 payload 移植到 v7.3-rc7 并拆成「binding → 驱动 → DTS」三段。属 Q2 合规（扩展既有 dwc3 drd），不新造子系统 |

## 发送纪律

英文 commit + `Signed-off-by: Xu Qianhui <xiaqinghuan@mail.ustc.edu.cn>`；`git send-email --dry-run` 通过后按 `get_maintainer.pl` 收件人发送；lore 复核归档（流程见技能 `upstream-mail-ustc`）。
