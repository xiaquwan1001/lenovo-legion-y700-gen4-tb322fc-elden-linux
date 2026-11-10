# M3-1 dwc3 正确形态重发（A3q 备料）— 2026-11-04

> 任务：只备料 + 过门禁，**不发信**（发信由编排者执行）。不 commit 主仓、不碰设备。
> 产物：`patches/upstream/m3-dwc3-20261104/`（3 枚补丁 + cover + `README.md` + `GATES.md` + `artifacts/`）+ 本文件。
> 构建树：`build/m3v6-dwc3`（`build/` 已 gitignore，不入主仓）。

## 0. 动机（上游两条否决，必须同时满足）

| 来件 | 时间（UTC） | 要求 | 本方案如何满足 |
|---|---|---|---|
| Krishna Kurapati `<ba544091-1da4-4616-b1d5-fe23f32679d9@oss.qualcomm.com>` | 2026-11-02 04:49:40 | **v5 不得叠在 v4 上**，必须把 v4 一起包含 | 3 枚补丁**逐枚原位折叠**（v4 内容 + v5 修复同一补丁），系列自身即完整，无 base 依赖 |
| Krzysztof Kozlowski `<20261102-armored-arcane-serval-43faf4@quoll>` | 2026-11-02 08:07:28 | misthreaded、缺 rest of patchset、读 submitting-patches、改用 **b4** | 单线程 1 cover + 3 补丁；`In-Reply-To` 只挂本次 cover；`base-commit:` 尾行；cover 逐条答复；发信走 b4（本机未装 ⇒ `GATES.md` §10 记「未证」） |
| Krzysztof Kozlowski `<20261102-screeching-utopian-avocet-492500@quoll>` | 2026-11-02 08:13:26 | v4 1/3 **dropping**（「Unanswered Sashiko comments + 重复投 v5 却不带 rest」） | cover 明写「drop 无妨，本 1/3 取代它」；sashiko 全部条目在 cover 逐条列为已并入 |

## 1. 版本沿革与本次形态

### 1.1 沿革（每一版指到仓库里的具体文件）

| 版本 | 目录 / 文件 | 枚数 | 基线 | 结局 |
|---|---|---|---|---|
| 首轮 M3-1 切片 | `patches/upstream/m3-2026-10-13/0001-dt-bindings-usb-snps-dwc3-document-usb-psy-name.patch`、`0002-dt-bindings-usb-snps-dwc3-describe-the-two-connector.patch`、`0003-usb-dwc3-support-two-connectors-sharing-one-HS-data-.patch` | 3 | pristine | 被 v2 取代（含 `usb-psy-name` 按名查找，后被驳回） |
| **v2** | `patches/upstream/m3-v2-2026-10-17/0001-dt-bindings-usb-snps-dwc3-describe-the-two-connector.patch`、`0002-usb-dwc3-support-two-connectors-sharing-one-HS-data.patch` | 2 | pristine | sashiko 12 条；被 v3/v4 取代 |
| **v3**（形状 RFC） | `patches/upstream/m3-v3-2026-10-19/0001-dt-bindings-usb-snps-dwc3-describe-two-connectors-sh.patch`、`0002-usb-roles-look-up-role-switches-attached-to-a-graph-.patch` | 2 | pristine | RFC，错挂 v2 线程（v4 cover 已道歉） |
| **v4**（已投 10-26） | `patches/upstream/m3-v4-20261026/0001-dt-bindings-usb-snps-dwc3-two-connectors-hs-bus.patch`、`0002-usb-roles-at-endpoint-lookup.patch`、`0003-usb-dwc3-two-connectors-shared-hs.patch` | 3 | pristine `24a19b953e` | 投递 4 封 250（`<20261026123211.243224-1..4@mail.ustc.edu.cn>`）；11-02 被 Krzysztof **dropping**（1/3） |
| v5（daily 基线，不可投） | `patches/upstream/m3v5-fix-20261030/0001-…tighten-the-two-connector-.patch`、`0002-…role-ha.patch` | 2 | **daily `24223e44ad`** | 含 v2→v4 形状重写，只作工作树记录 |
| **v5**（pristine 重出，已投 10-31） | `patches/upstream/m3v5-20261030/v5-0001-dt-bindings-usb-snps-dwc3-tighten-the-two-connect.patch`、`v5-0002-usb-dwc3-fix-the-two-connector-shared-HS-bus-role.patch`（+ `v5-0000-cover-letter.patch`） | 2 | pristine **+ v4 三枚**（`fd69bd54e3`） | 投递 3 封 250（`<20261031150154.1106455-1..3@…>`）；**形态致命**：fixup 叠在 v4 上 ⇒ Krishna 否决 |
| **11-02 半枚补投** | `patches/upstream/m3-1-v5-dt-resend-20261102/0001-dt-bindings-usb-snps-dwc3-tighten-the-two-connector-shared-HS-bus.patch` | 1 | 无（独立单封） | **就是这次事故**：只重投 v5 1/2、无 cover、无 rest ⇒ Krzysztof「misthreaded - missing rest of patchset」；**此文件不得再用** |
| **本次 v6（备料）** | `patches/upstream/m3-dwc3-20261104/0000-cover-letter.patch` + `0001-dt-bindings-usb-snps-dwc3-describe-two-connectors-sh.patch` + `0002-usb-roles-look-up-role-switches-attached-to-a-graph-.patch` + `0003-usb-dwc3-support-two-connectors-sharing-one-HS-data-.patch` | **3（自足）** | pristine `24a19b953e2a3d0ea5a8c4951a0ab8f32720c907` | 门禁全绿、未发信 |

补充：v5 的三封 10-31 投递里有一封因地址写成 `linux-devicetree@vger.kernel.org`（vger 550）而未进 DT 列表，
这才是 11-02 只补投 1/2 的起因；正确地址 = `devicetree@vger.kernel.org`（已在 `README.md` §4 固化）。

### 1.2 本次系列的构成（提交级）

折叠＝**按文件集原位重放，不做 reorder**：v4 三枚与 v5 两枚的文件集互不重叠，因此：

| 本次补丁 | 文件集 | = v4 | + v5 | 提交 |
|---|---|---|---|---|
| 1/3 | `Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml` | `m3-v4-20261026/0001` 全量 | `m3v5-20261030/v5-0001` 全量 | `1e1e1560fc45…` |
| 2/3 | `drivers/usb/roles/class.c` | `m3-v4-20261026/0002` 全量 | `v5-0002` 的 `roles/class.c` hunk（`-EPROBE_DEFER` 上抛） | `7d1d0ea9822f…` |
| 3/3 | `drivers/usb/dwc3/{core.c,core.h,debugfs.c,drd.c}` | `m3-v4-20261026/0003` 全量 | `v5-0002` 的其余 hunk | `fce197bb2e8c…` |

做法（可复现）：
1. `build/m3v2-7.3rc7` 上 `git worktree add --detach build/m3v6-dwc3 24a19b953e`；
2. 依次 `git am` v4×3 + v5×2（全 rc=0）⇒ 终态 6 文件 sha256 与 `build/m3v5-pristine` tip `34865c8915` **逐字节一致**
   （= `reports/m3v5-pristine-replay-20261030.md` §3 的 `f74763e2…/301464ac…/a0b5bb38…/144ba216…/7e3d62dc…/c354808d…`）；
3. 从 base 建分支 `m3v6`，按上表文件集 `git checkout <终态> -- <paths>` 分三次提交（每枚只碰自己的文件）；
4. `git format-patch -3 --cover-letter --no-signature` 出到 `patches/upstream/m3-dwc3-20261104/`；
5. cover 正文手写（`0000-cover-letter.patch`），`base-commit:` 置于**末尾**（b4/format-patch 的规范位置）。

唯一的内容订正（属本次新增，已在 cover 与 README 明说）：`port-select-gpios` 的 description 在 v5 把形状改成
`port@0`+`port@2` 后仍写着「a numbered endpoint of port@0」，与之矛盾 ⇒ 改为「"port@0" 或 "port@2"，其 endpoint
携带 role-switch 与 mux-state」。**纯描述，schema 行为零变化**（`GATES.md` §5 探针矩阵与 10-30 结论逐条一致）。

**为什么这样拼**（一句话）：唯一能同时满足两位维护者的形态是「一个自足、单线程、逐枚都能独立评审的 3 枚系列」；
文件集不重叠使原位折叠零冲突，且能保证「不含 1/2 单独重投」——因为不存在任何 fixup 补丁，
每个补丁的 commit message 描述的也是**最终代码**（不回放 v2→v5 的历史修订记录，那属于 cover）。

## 2. 门禁（详见 `patches/upstream/m3-dwc3-20261104/GATES.md`）

| 门 | 结果 |
|---|---|
| `checkpatch --strict`（stdin） | 3/3 **0E/0W/0C**（138/63/441 行 checked） |
| `check-series-selfcontained.sh`（base `24a19b953e…`） | **PASS**，3/3 重放，WARN=0 |
| `make W=1`（dwc3 + roles，19 glue `=m`） | **rc=0，0 warning / 0 error**，26 个 `.o` |
| `dt-doc-validate` | **rc=0 无输出** |
| `dt-validate` 形状探针（带 `DT_SCHEMA_PATH`） | `boardshape` **0 行**；`n_dup0/n_extra/n_port1/nomuxprop` **全 REJECT** |
| pristine `git am` 逐枚 | 3/3 rc=0，终态树与系列 tip **相同**（diff 空） |
| `git send-email --dry-run` | rc=0，`Dry-OK`；MID `-1..-4` 连续，IRT/References **只挂 cover** |
| `make dt_binding_check` | 0 行输出 + 负对照有输出（rc 不作判据，#470/#471） |
| phy 文件 `W=1` | **N/A**：6 个改动文件无一在 `drivers/phy/` |
| `b4 send --dry-run` | **未证**：本机无 `b4` |

## 3. 未证 / 待编排者决定

1. 未上机（零设备操作）；行为证据来自本板 daily 内核的**同源代码**（12 次拔插，0 WARNING/BUG/lockdep）。
2. 未在最新 `usb-next`/`master` 重放（base 固定 7.3-rc7，未联网取新树）——发信前建议按 b4 流程复跑一次 `git am`。
3. `b4` 未安装 ⇒ `b4 send --dry-run` 未跑。
4. 仲裁明细（同时请求谁胜）无完整 per-port 角色值 trace，cover 已如实写为限制。

## 4. 发信前 checklist（≤6 条）

1. **用 b4 发**：`b4 send --dry-run` 先看形态再发；b4 未装先 `python3 -m pip install --user b4`。
2. **不跨线程**：新系列新线程，`In-Reply-To`/`References` **只挂本次 cover**（`--no-chain-reply-to`/b4 默认），
   不引用 v4/v5 任何 Message-ID 作为 References。
3. **不再单发子集**：4 个文件（0000 + 0001..0003）一次发完；禁止再出现 `m3-1-v5-dt-resend-20261102` 那种单枚重投。
4. **Message-ID 连续**：`-1..-4` 同批次（同一次 send 调用生成），发后核对 4/4 都是 250、lore 4/4 命中。
5. **地址**：DT 列表只写 `devicetree@vger.kernel.org`（**不存在** `linux-devicetree@`，vger 550）；To/Cc 见 `README.md` §4。
6. **发送前把 cover 与 `base-commit` 再核一遍**：cover 里「Board behaviour / 两条限制」不许加强（无新上机证据），
   `base-commit:` 必须在正文末尾、40 位齐全。

DONE-DWC3
