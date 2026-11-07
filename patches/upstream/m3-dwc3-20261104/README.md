# M3-1 dwc3 — 单一自足系列（v6 备料，2026-11-04）

> 状态：**已投 `[PATCH 0/3]`（2026-11-04 03:27Z，4 封全 `Result: 250`，cover `<20261104032706.210042-1-xiaqinghuan@mail.ustc.edu.cn>`）**；报告 `reports/mail-send-20261104-wl2868c-v6-dwc3.md`；后续 v7/v8 见 `../m3-dwc3-v7-20261106/`。
> 本目录不含设备操作、不含主仓 commit。产物 = `0000-cover-letter.patch` + `0001..0003` + 本 README + `GATES.md` + `artifacts/`。

## 1. 这一版要解决的两条上游否决

| 谁 | 何时（UTC） | 原话要点 | 本系列的答复位置 |
|---|---|---|---|
| Krishna Kurapati `<ba544091-1da4-4616-b1d5-fe23f32679d9@oss.qualcomm.com>` | 2026-11-02 04:49:40 | v5 不能叠在 v4 上，必须把 v4 的改动包含进来 | cover §「Reply to the two procedural comments」第 1 段；**形态事实 = 本目录 3 枚补丁自身已含 v4 全部改动 + v5 全部修复** |
| Krzysztof Kozlowski `<20261102-armored-arcane-serval-43faf4@quoll>` | 2026-11-02 08:07:28 | misthreaded、缺 rest of patchset、去读 submitting-patches、改用 b4 | cover 同上第 2 段；形态事实 = 单线程 1 cover + 3 补丁、`In-Reply-To` 只挂本次 cover、`base-commit:` 尾行 |
| Krzysztof Kozlowski `<20261102-screeching-utopian-avocet-492500@quoll>` | 2026-11-02 08:13:26 | v4 1/3 **dropping** | cover 明写「v4 1/3 被 drop 无妨：本 1/3 取代它」 |

## 2. 系列构成（3 枚，替代 v4 1/3..3/3 + v5 1/2..2/2）

| 本目录补丁 | 内容 | = v4 | + v5 | 行数 |
|---|---|---|---|---|
| `0001-dt-bindings-usb-snps-dwc3-describe-two-connectors-sh.patch` | `snps,dwc3-common.yaml` 双连接器共享 HS 总线 | `patches/upstream/m3-v4-20261026/0001-dt-bindings-usb-snps-dwc3-two-connectors-hs-bus.patch` | `patches/upstream/m3v5-20261030/v5-0001-dt-bindings-usb-snps-dwc3-tighten-the-two-connect.patch` **全量** | 114+/2− |
| `0002-usb-roles-look-up-role-switches-attached-to-a-graph-.patch` | `usb_role_switch_at_endpoint()` | `patches/upstream/m3-v4-20261026/0002-usb-roles-at-endpoint-lookup.patch` | `m3v5-20261030/v5-0002` 的 `drivers/usb/roles/class.c` hunk | 45+ |
| `0003-usb-dwc3-support-two-connectors-sharing-one-HS-data-.patch` | DWC3 双连接器仲裁 | `patches/upstream/m3-v4-20261026/0003-usb-dwc3-two-connectors-shared-hs.patch` | `m3v5-20261030/v5-0002` 的 `core.c`/`core.h`/`drd.c` hunk | 342+/2− |

合计 6 文件 **501+/4−**（对 base）。**不含** `drivers/usb/typec/ucsi/ucsi.c`（v5 的 F2 相对 pristine 是无操作，见 `reports/m3v5-pristine-replay-20261030.md` §4-2）。

**为什么这样拼**：三个补丁的文件集互不重叠（yaml / `roles/class.c` / `dwc3/{core.c,core.h,debugfs.c,drd.c}`），
因此「v4+fixup」可以按文件级原位折叠，而不需要 reorder 或改语义。折叠后**没有任何"1/2 单独重投"**，
也不存在需要先应用别的系列的 base。

**相对上一版的两处 diff stat**：

- v6 vs **v4 tip**（`fd69bd54e3`，pristine+v4）：5 文件 **143+/80−**（= 折进去的 v5 增量 + 下述 1 处文档订正）。
- v6 vs **v5 tip**（`34865c8915`，pristine+v4+v5）：**3+/3−**，只有 `port-select-gpios` 的 description 一行三句。
  原因：v5 把形状改成 `port@0`+`port@2` 各一 endpoint 后，该 description 还写着「a numbered endpoint of port@0」，
  与实际 schema 矛盾；本轮改成「"port@0" 或 "port@2"，其 endpoint 携带 role-switch 与 mux-state」。**纯文档，零 schema 行为变化**。

## 3. base commit 与生成树（可复现）

- `base-commit: 24a19b953e2a3d0ea5a8c4951a0ab8f32720c907`（= `Linux 7.3-rc7`，torvalds tag `v7.3-rc7`）
- 生成树：`build/m3v6-dwc3`（`git -C build/m3v2-7.3rc7 worktree add --detach … 24a19b953e`），分支 `m3v6`
- 提交：`1e1e1560fc45…`（binding）/ `7d1d0ea9822f…`（roles）/ `fce197bb2e8c…`（dwc3）
- 折叠方法：先在 pristine 上 `git am` v4×3 + v5×2 得到终态树（6 文件 sha256 与 `build/m3v5-pristine` tip
  `34865c8915` **逐字节一致**，即 `reports/m3v5-pristine-replay-20261030.md` §3 记录的那组 sha256），
  再从该终态按文件集 `git checkout <final> -- <paths>` 分三次提交，使每枚补丁只碰自己的文件。
- 重出：`git format-patch -3 --cover-letter --no-signature -o patches/upstream/m3-dwc3-20261104/ HEAD`

## 4. 收件人（`scripts/get_maintainer.pl` 实跑 + 本项目列表口径）

- **To**：Greg Kroah-Hartman `<gregkh@linuxfoundation.org>`、Thinh Nguyen `<Thinh.Nguyen@synopsys.com>`、
  Rob Herring `<robh@kernel.org>`、Krzysztof Kozlowski `<krzk+dt@kernel.org>`、Conor Dooley `<conor+dt@kernel.org>`
- **Cc**：`linux-usb@vger.kernel.org`、`devicetree@vger.kernel.org`、`linux-arm-msm@vger.kernel.org`、`linux-kernel@vger.kernel.org`
- **地址纪律**（本项目已踩两次）：DT 列表只写 `devicetree@vger.kernel.org`，**没有** `linux-devicetree@`（vger 550）。
- `Felipe Balbi <balbi@kernel.org>` 由 get_maintainer 以 `(in file)` 给出；v4 未 Cc，本轮同样**不加**（避免对 inactive 维护者刷信）。

## 5. cover letter

正文 = `0000-cover-letter.patch`（含 AI 辅助披露、系列布局、对 Krishna/Krzysztof 的逐条答复、
对 sashiko 全部条目的处置、与上一版 diff stat、测试证据、两条诚实限制、`base-commit:` 尾行、链接。
**发信前请通读**：其中「Board behaviour」段用的是本板 daily 内核上的同源代码行为证据（12 次拔插），
并明写 pristine 血统内核在本板起不来（与本系列无关），以及「仲裁明细未做完整 per-port 值 trace ⇒ 未证」。

## 6. 发送（编排者执行，本 agent 未发）

首选 `b4`（Krzysztof 要求的工具；本机**未安装** `b4`，见 `GATES.md` §7）：

```sh
b4 send --dry-run patches/upstream/m3-dwc3-20261104/000[0-3]-*.patch   # 先看形态
b4 send patches/upstream/m3-dwc3-20261104/000[0-3]-*.patch             # 再发
```

退化路径 = 已实测 dry-run 通过的 `git send-email` 参数（见 `GATES.md` §6）：
`--thread --no-chain-reply-to`（= `In-Reply-To` 只挂 cover），`--to/--cc` 见 §4。

## 7. 未证 / 已知限制

1. **未上机**：本轮零设备操作。驱动行为证据来自本板 daily 内核的**同源代码**（12 次拔插，0 WARNING/BUG/lockdep），
   不是「pristine+本系列」镜像；pristine 血统内核在本板无法启动（缺下游平台/显示，见 `TASKS/README.md` §7 M3）。
2. **仲裁明细未证**：同时请求时谁胜出只有代码阅读 + stale-request 现场证据，没有完整 per-port 角色值 trace（cover 已如实写）。
3. **`b4 send --dry-run` 未跑**：本机无 `b4`（`command -v b4` 空、`~/.local/bin/b4` 不存在）。形态已用
   `git send-email --dry-run` 验证等价（单线程、MID 连续、IRT 只挂 cover、`base-commit` 尾行）。
4. **`make dt_binding_check` 的 rc 不可当判据**（PITFALLS #470/#471）：本目录记录的是「0 行输出 + 负对照会产生输出」
   两条一起看；真正的 binding 判据是 `dt-doc-validate` + `dt-validate` 形状探针（`GATES.md` §4/§5）。
5. **base 是 7.3-rc7**：若发信时上游已前进很多，`git am` 可能需 rebase；发信前按 `TASKS/README.md` §7 的 b4 流程在
   当前 `usb-next`/`master` 上复跑一次 `git am`（本目录未做，未联网取新树）。
