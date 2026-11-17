# dwc3 v10 备料（2026-11-18，**未发送**）

> 来源 = sashiko 对 v9 的 3 封机器评审（2026-11-17 05:27/05:37/05:40 UTC，lore
> `sashiko-outbox-218205/218216/218217@kernel.org`）。本目录只做「答完 2×High + 1×Medium + 2×Low」，
> **未发信**（发信需用户按系列逐次批准；见 `TASKS/README.md` §7）。

## 1. 提问 ↔ 改动对照（逐条，含代码位置）

| # | sashiko 严重度 | 原文要点 | 判定 | v10 改动 | 文件:函数 |
|---|---|---|---|---|---|
| H1 | **High** | `__dwc3_set_mode()` 里 `mux_control_deselect()` 不配对：初始 mode 请求时 `active_port == -1`、mux 从未 select，deselect 会 up 未取的信号量；`mux_control_select()` 失败后 `active_port` 仍留旧值 ⇒ 下次切换会跳过 select 或重复 deselect | **成立**（v9 代码确实无条件 deselect） | `active_port` 在取 `desired_port` 的同一把锁里读出并作为局部量；只有 `active_port >= 0` 才 deselect；select 失败时 `active_port = -1` | `core.c: __dwc3_set_mode()` |
| H2 | **High** | `dwc3_drd_exit()` 没 deselect：`devm_mux_control_get()` 只 `mux_control_put()`，不恢复 idle state，卸载后 mux 锁不释放，下次 probe/其他 consumer 会阻塞 | **成立** | 新增 `dwc3_role_mux_deselect()`，在 `cancel_work_sync(&dwc->drd_work)` **之后**调用（此时不可能再有 switch 去 select）；`dwc3_role_mux_init()` 的 error path 在 drain 后同样调用 | `drd.c: dwc3_role_mux_deselect(), dwc3_drd_exit(), dwc3_role_mux_init()` |
| M1 | **Medium** | `port@0` 无条件套 `hs-port`（要求 `#address-cells`/`#size-cells`/`endpoint@0`/`endpoint@1`）⇒ 拒绝 `qcom/sm8250.dtsi` 一类单 endpoint 板；且无 mux 时 `else` 禁止 `mux-state`，使 `oneOf` 两支都空匹配、port@0 无法通过 | **成立** | `hs-port` 的两 endpoint/地址单元**不再无条件 required**：`then`（`mux-controls` 存在）里只加 `required`；互斥 `oneOf` 仅在**两个 endpoint 都在**时求值（`if: required: [endpoint@0, endpoint@1]`）；无 mux 的 `else` 回到 `graph.yaml#/properties/port` | `snps,dwc3-common.yaml: $defs/hs-port, allOf[2]` |
| L1 | **Low** | 两个 endpoint 可只写 `endpoint@0` 的 `usb-role-switch`/`mux-state`，`endpoint@1` 全缺也能过（`oneOf` 空匹配） | **成立** | `hs-port` 的 `endpoint@0/@1` 均 `required: [reg, usb-role-switch, mux-state]` | 同上 |
| L2 | **Low** | binding commit message 写成 v8→v9 变更日志（提到 baseline 没有的 `port@2`/`port-select-gpios`） | **成立** | 正文改成「相对基线新增的双 connector 描述」，变更日志移到 `---` 之后 | `v10-0001` commit message |

## 2. 门禁（全部在 patch 文件 `git am` 出的 pristine 树上跑）

见 `GATES.md`：`git am 3/3` · checkpatch `--strict` **0E/0W/0C ×3** · `W=1` **0 warning** ·
`dt_binding_check` **rc=0** · 非 mux 板 `CHECK_DTBS` rc=0 · 正样例 PASS / 负样例 4 类全拒。

## 3. 文件清单与「发信前还差什么」

- `v10-0000-cover-letter.patch`（含逐条回答 + 门禁摘要）
- `v10-0001-dt-bindings-usb-snps-dwc3-describe-two-connectors-on.patch`
- `v10-0002-usb-roles-look-up-role-switches-attached-to-a-graph-.patch`（v9 原样，sashiko 无意见）
- `v10-0003-usb-dwc3-select-the-shared-HS-data-bus-with-a-mux-co.patch`
- `GATES.md`

**SENT 前一步（未做，等用户放行）**：

1. 收件人沿用 v9：Thinh Nguyen / Rob Herring / krzk+dt / conor+dt / Greg KH + `linux-usb` `linux-devicetree` `linux-arm-msm` `lkml`（MAINTAINERS 现查 dwc3 的 M 仍是 Thinh Nguyen；`upstream-delta-20261118.md` §6）。
2. `git send-email --dry-run` 一次（`--dry-run` 不发信，仅核对收件人/编码）。
3. 覆盖 v9 的线程：`In-Reply-To`/`References` 指 v9 cover `<20261117052137.32833-1-xiaqinghuan@mail.ustc.edu.cn>`（`--in-reply-to`）。
4. 0004（board DTS，GPIO 29 + 双 endpoint）继续 hold —— 依赖未上游的 `sm8750-lenovo-elden.dts`。
5. 发信后补 `SENT.md`（MID 清单 + lore 复核），再改 `TASKS` §7 `dwc3` 行。
