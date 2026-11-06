# M3-1 dwc3 — v7 备料（2026-11-06）

> 状态：**备料完成、门禁全绿、未发信**（发信仍由用户按批放行）。
> 本目录只做主机侧：不含设备操作、不含主仓 commit。
> 上一版 = `patches/upstream/m3-dwc3-20261104/`（11-04 实投 `[PATCH 0/3]`）。

## 1. 这一版只做一件事：答 11-04 批的两条 High

来源 `<sashiko-outbox-196628@kernel.org>`（对 3/3 的评审，投递后 17 分钟到达）。

| # | sashiko 原话要点 | 真因 | 修法（全在 3/3） |
|---|---|---|---|
| H1 | **torn port and role state in `dwc3_mux_role_set()`**：`mux->desired_port` 在 `dwc->lock` 下写、放锁跨 `dwc3_pre_set_role()`（可睡眠）、再由 `dwc3_set_mode()` 重新取锁写 `dwc->desired_dr_role`；已挂起的 worker 会读到「新端口 + 旧角色」，把 GPIO 搬到新连接器却按旧角色初始化 | 端口选择与模式请求**分两次临界区发布** | 新增 `dwc3_set_mode_port(dwc, mode, port)`：`desired_dr_role` 与 `mux->desired_port` 在**同一次 `dwc->lock`** 内写入，且在 `dwc3_pre_set_role()` **之后**发布 ⇒ worker 既看不到半更新，也不可能在 glue 通知前启动。顺带：`queue_work()` 对**正在运行**的 work 返回 false（新请求会丢）⇒ `__dwc3_set_mode()` 结尾按快照比对，有更新就自排队；比对基准是快照，所以**失败的端口切换不会死循环重试** |
| H2 | **race and reversed teardown order in `dwc3_role_mux_init()`**：port0 注册成功后连接器即可 `set()`；port1 注册失败时 err 路径先 `cancel_work_sync()` 再 `usb_role_switch_unregister()` ⇒ 该调用可在 drain 之后排队 work、在 mux 半拆状态下运行；且 `dwc3_role_mux_exit()` 不与 `mux->lock` 同步 ⇒ 可能读到被置 NULL 的 `dwc->role_mux` | ① 初始化期无「未就绪」门；② 拆除顺序反；③ `role_mux` 置 NULL 本身制造了 NULL 解引用面 | ① 新增 `mux->ready`：`set()` 在 `mux->lock` 内检查，未就绪直接 `-ENODEV`（不再与初始模式请求竞争，也不留下需要回收的 host/gadget 实例）；② 拆除顺序改为 **清 `ready`（持 `mux->lock`，因此无在飞请求）→ 反注册开关 → `cancel_work_sync()`**；③ **不再清 `dwc->role_mux`**（devm 管理，清掉只会把迟到请求变成 NULL 解引用） |

## 2. 系列构成（3 枚，与 11-04 版同形）

| 补丁 | 内容 | 相对 11-04 版 |
|---|---|---|
| `0001-dt-bindings-usb-snps-dwc3-describe-two-connectors-sh.patch` | `snps,dwc3-common.yaml`：`port-select-gpios` + 每连接器一个 HS port（`port@0`/`port@2`）+ 端点上的 `mux-state`/`usb-role-switch` | **未变**（138 行 checked） |
| `0002-usb-roles-look-up-role-switches-attached-to-a-graph-.patch` | `usb_role_switch_at_endpoint()`（含 `-EPROBE_DEFER` 上抛） | **未变**（63 行） |
| `0003-usb-dwc3-support-two-connectors-sharing-one-HS-data-.patch` | DWC3 双连接器仲裁 + 上面两条 High 的修复 | **+92/−11**，仅 `core.c`/`core.h`/`drd.c`（553 行） |

合计 6 文件 **583+/5−**（对 base）。`0000-cover-letter.patch` 新增 §「Response to the review of the 11-04 posting」逐条回答 H1/H2。

## 3. base commit 与生成树

- `base-commit: 24a19b953e2a3d0ea5a8c4951a0ab8f32720c907`（= `v7.3-rc7`，与 11-04 版相同，**未 rebase**）
- 树 = `build/m3v2-7.3rc7`，分支 **`m3v7`**（从 `m3v6` 切出，`git commit --amend` 改 3/3 一枚）
- 提交：`1e1e1560fc45`（binding）/ `7d1d0ea9822f`（roles）/ **`07ab397efd`**（dwc3，v7）
- 重出：`git -C build/m3v2-7.3rc7 format-patch -3 --cover-letter --no-signature -o patches/upstream/m3-dwc3-v7-20261106 HEAD`
  （**cover 需手工补**：`Subject: [PATCH v7 0/3] …` 与末尾 `base-commit:` 尾行）

## 4. 收件人与发送（编排者执行，本 agent 未发）

- **To**：Greg Kroah-Hartman、Thinh Nguyen、Rob Herring、Krzysztof Kozlowski、Conor Dooley
- **Cc**：`linux-usb@vger.kernel.org`、`devicetree@vger.kernel.org`、`linux-arm-msm@vger.kernel.org`、`linux-kernel@vger.kernel.org`
- 地址纪律：DT 列表只写 `devicetree@vger.kernel.org`（**没有** `linux-devicetree@`，vger 550）
- 首选 `b4`（Krzysztof 指定；本机仍**未装** `b4`）；退化路径 = 已 dry-run 通过的 `git send-email`：

```sh
git send-email --thread --no-chain-reply-to \
  --to=gregkh@linuxfoundation.org --to=Thinh.Nguyen@synopsys.com \
  --to=robh@kernel.org --to=krzk+dt@kernel.org --to=conor+dt@kernel.org \
  --cc=linux-usb@vger.kernel.org --cc=devicetree@vger.kernel.org \
  --cc=linux-arm-msm@vger.kernel.org --cc=linux-kernel@vger.kernel.org \
  patches/upstream/m3-dwc3-v7-20261106/000[0-3]-*.patch
```

## 5. 未证 / 已知限制（发信前必读）

1. **base 仍是 7.3-rc7**；发信时上游已到 `7.4-rc1`（2026-11-01）。**发信前**按 `TASKS` §7 流程在当前 `usb-next`/`master` 上复跑一次 `git am`（本目录未联网取新树）。
2. **未上机**：本轮零设备操作。上一版 cover 里那段「12 次拔插、0 WARNING/BUG/lockdep」仍是**日常内核同源代码**的证据，不是「pristine + 本系列」镜像（pristine 血统内核在本板起不来，与本系列无关）。
3. **H1/H2 的修复本身没有运行期证据**：都是并发/错误路径，静态论证 + 编译 + 门禁，没有复现器。cover 里已如实写明（若维护者要，我可以写一个 fault-injection 复现脚本）。
4. `b4 send --dry-run` 仍未跑（环境缺件）；`git send-email --dry-run` 通过。
