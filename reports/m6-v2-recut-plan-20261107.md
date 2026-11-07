# M6 B5 v2 重切（Q28 上游化）静态备料报告 — 2026-11-07

- 性质：**只读备料**。未改内核树、未 commit、未发信、未碰设备。
- 检查基点（当前上游 master）：
  - 树：`build/m3v2-7.3rc7`（torvalds remote，blob:none partial clone）
  - master HEAD = `d48723711bae9b8cdc56719c448ba42fef28cbee`（2026-11-06 13:18 -0800，`Merge tag 'arm64-fixes' …`）
  - v2 备料原 base = `6628e7d4c6`（Linux 7.4-rc1），本次对照更新后的 master 重验。

## §0 一句话结论

**v2 备料 4 枚按序整列 apply 到 2026-11-06 的 torvalds master `d48723711b` 全部通过（4/4，零冲突，未落地）；单独检查时 0003/0004 依赖前枚不独立可 apply。建议维持 4 枚不重切（v2 本身已是"每枚一个逻辑动作"），复启仍卡复启条件 (a) = elden 板级 DTS 同线程，报告见本文件。**

（§1 备料核对表 / §2 切分方案 / §3 风险与前置 / §4 复现命令逐节追加于下。）

## §1 备料核对表（`patches/upstream/m6-b5-v2-20261102/`，4 枚 + cover，未投）

| # | Subject | 行数 | 触及文件（+行数） | 子系统 |
|---|---|---|---|---|
| 0001 | add per-SoC bonded command-path config | +121/−3 | `dsi_cfg.c`(+75/1)、`dsi_cfg.h`(+24/1)、`dsi_host.c`(1/1)、`registers/display/dsi.xml`(+21) | msm DSI cfg 分层 + 寄存器 XML |
| 0002 | add the bonded command broadcast host ops | +409/−3 | `dsi_host.c`(+396/3)、`dsi_cfg.h`(+8)、`dsi_cfg.c`(+2)、`dsi.h`(+3) | DSI host 核心（broadcast 命令路径本体） |
| 0003 | route bonded commands through the DSI manager | +130/−0 | `dsi_manager.c`(+109)、`dsi_host.c`(+17)、`dsi.h`(+4) | DSI manager 路由 + gate |
| 0004 | reject bonded commands issued on the peer | +15/−2 | `dsi_manager.c`(15/2) | manager 用法拒绝（peer 链路） |

- cover 0000：含 AI-assistance disclosure、动机（`BROADCAST` 命中 0）、门禁声明（checkpatch 4/4 0E/0W、`W=1` 编译 rc=0、`git am` 4/4）。
- 总净 diff：6 文件 +673 −6（仅 `drivers/gpu/drm/msm/`）。

### apply 核对（`git apply --check`，未落地；worktree = master `d48723711b`）

| 检查方式 | 结果 |
|---|---|
| 按序整列 0001→0002→0003→0004 | **4/4 全部 APPLIED（--check 通过，零冲突）** |
| 单枚独立 --check | 0001 ✅、0002 ✅、0003 ❌（`dsi_host.c:2228` 依赖 0002 的新增函数区）、0004 ❌（`dsi_manager.c:564` 依赖 0003）——**符合设计：3/4、4/4 本就是叠在 2/4 上的增量** |
| 与 7.4-rc1 原 base 的 diff | 无需 rebase 调整：master 自 7.4-rc1 以来未动 `drivers/gpu/drm/msm/dsi/`（4 枚上下文全部原样命中） |

结论：**base 漂移目前为 0，`GATES.md` §5 的三步复跑（rebase+checkpatch+selfcontained）暂不必跑**；投递前再复跑一次即可。


## §2 v2 重切方案（建议）

**建议 = 维持现有 4 枚切分，不重新拆分。** 理由：v2（2026-11-02 收尾版）已满足"每枚一个逻辑动作"：
①per-SoC 数据声明（纯声明，不改行为）→ ②broadcast 主机 ops 本体 → ③manager 路由 + 使用者 gate → ④peer 用法拒绝（防御）。拆得更细会把 ② 的大函数体（`dsi_host.c` +396）人为截断；拆得更粗会把"数据"与"行为"混进一枚，重蹈 v1 被 Dmitry 质疑"改的是公开树不存在的路径"的覆辙。

若评审中被迫重切，备用顺序（唯一合理变体）= 把 0004 并入 0003（同文件、同为 manager 侧语义，`git am` 依赖也一致），成为 3 枚；0001/0002 不动。

| 枚 | 逻辑动作 | 目标文件 | 关键 hunk |
|---|---|---|---|
| 1/4 | 声明 SM8750 独立 per-SoC bonded cfg（`compatible = "qcom,sm8750-dsi-ctrl"` 选表，SM8650 保持 `bonded == NULL`）；补回 7.4-rc1 被删的 21 行 `dsi.xml` 寄存器 | `dsi_cfg.c/h`、`dsi_host.c`(getter 一行)、`dsi.xml` | `dsi_cfg.c @@194`（sm8750 条目 + regulators）、`@@343`（handler 表加 compatible 字段）；`dsi.xml @@188/206/233/314` |
| 2/4 | broadcast 命令路径本体：`bonded_cmd_xfer` host op + 双链路发送/错误清，op 存在 ∧ per-SoC 数据非空才生效（修 SM8650 门控缺陷，PITFALLS #489） | `dsi_host.c`、`dsi_cfg.c/h`、`dsi.h` | `dsi_host.c @@2164→2228,335`（核心函数体）、`@@755`（intr）、`@@1686`（dsi_error）、`@@153/182`（flag+mutex 进 `msm_dsim_glb`） |
| 3/4 | manager 路由：面板 DCS 写经 gate（op 存在 ∧ `get_bonded_cfg()` 非空 ∧ dual-dsi + command-mode）走 bonded xfer | `dsi_manager.c`、`dsi_host.c`(getter)、`dsi.h` | `dsi_manager.c @@493`（`dsi_mgr_use_bonded_write`）、`@@505`（`msm_dsi_manager_cmd_xfer` 入口）、`@@25`（`bonded_cmd_failed` + mutex） |
| 4/4 | 在 peer 链路发 bonded 命令 → `dev_err`（带两条链路号）+ 拒绝 | `dsi_manager.c` | `@@564/574/608` |

### 复启条件 (a) —— elden DTS 板级前提（需同线程附带）

主线树目前 6 块 `qcom,dual-dsi-mode` 板无一 SM8750、无一块 command-mode bonded ⇒ 4 枚在树内**无使用者**（11-04 裁决不投的第一理由）。eldens 板级系列需提供：

1. `sm8750-lenovo-elden.dts`：两颗 DSI host 节点 `qcom,dual-dsi-mode` + master 侧 `qcom,master-dsi = <0>`（master 由 DT 独裁，v2 已删 probe-order 表述）；
2. 面板子节点走 command-mode（`qcom,mdss-dsi-panel-name` 类上游 panel driver 或 panel 描述节点），且 panel 驱动实际经 `mipi_dsi_*` 发 DCS；
3. C-PHY + DSC 属性如实声明（1904x3040 bonded C-PHY + DSC）——这是树上第一个 C-PHY bonded 使用者，评审复杂度要预估；
4. 板级件与核心件**同线程**投（`In-Reply-To` 本系列 cover），否则 0001–0004 仍是孤儿。

### 与 B5 现有讨论线程的引用关系（Re:）

- v1 系列（已投，linux-arm-msm 6/6 在档）：`<20261031150305.1107572-1@mail.ustc.edu.cn>`（`..-6`）。
- Dmitry 追问（0/5 上的四条质疑）：`<j5ixobskknatvusosmhgvvmnze4q67iyfwk6gsa3y5goovx4z4@mhumd2vsnfkm>`（10-31 20:31Z，最后一条上游回信）。
- 我方 11-02 回信四条（承诺 v2 在 torvalds master 重切）：`out/mail-20261102-b5/re-dmitry-b5-4items.txt`（In-Reply-To 上条）。
- v2 投出时：cover `In-Reply-To` = 上条 Dmitry Message-ID（延续同线程），正文引用 11-02 回信的承诺口径 "this series is the data half of proposing that path"。


## §3 风险与前置

### A. 依赖下游 payload、不能上游化的部分（隔离在系列外）

| 项 | 说明 | 处置 |
|---|---|---|
| cambist / `cambistmclkcc-sm8750` clk 补丁 | Q24 已定性其与 DT 电源域耦合（`TASKS §2`）；属本地 payload（`0f1fb1c9c1` squashed 载荷），不在 v2 4 枚内，也不应进 M6 | 保持下游；只作为机上验证前提（vk74+ 线） |
| `err_clear_bits` / FIFO 位命名（v1 0005） | 与 v2 0002 的表驱动设计分叉已裁决：保留 0002 表驱动，0005 只做命名（`reports/m6-dsi-errmask0-20261031.md §5`）；**v2 已折进 0001 新表（无魔数）**，无需独立枚 | 已消化，无遗留动作 |
| v1 1/5 flag 移动、4/5 master-from-cfg | 公开树无可移对象；v2 已按 DT 独裁重做（§2 表） | 无遗留动作 |

### B. 纯 DSI 核心改动（本系列全部 4 枚）

- 全部落 `drivers/gpu/drm/msm/dsi/{dsi_cfg.c,dsi_cfg.h,dsi_host.c,dsi_manager.c,dsi.h}` + `dsi.xml`；**不触及** clk/PHY/cambiss/panel 驱动。对 SM8650 双 DSI 板行为中性由 3/4 的 gate 保证（op 存在 ∧ per-SoC 数据非空）。
- 既有 SM8650/8550 等板的回归面 = `dsi_mgr_use_bonded_write()` 对 op 的探测路径，需在 cover/commit 里保留 11-02 收尾那条门控理由（已写进 3/4 commit message 与 cover）。

### C. 需先等上游先例 / 复启条件（任一满足才复启投递，2026-11-04 裁决）

1. **(a) elden 板级 DTS 进树或进同线程评审** —— 当前唯一可由我方主动创造的条件；依赖 M3-3 板 DTS / M4-1 之后的 DT 进树排期。本报告 §2 已给出板级前提清单。
2. **(b) 上游出现第二个 SM8750 command-mode bonded 需求** —— 被动跟踪（lore/patchwork 扫 `sm8750` + `dual-dsi`）。
3. **(c) Dmitry/Taniya 主动索要** —— 被动跟踪（linux-arm-msm 收件箱分诊）。
4. SM8750 command-mode bonded 在上游**无先例**：若评审中 Dmitry 要求"先有 command-mode bonded 的通用先例"，我方只能以 elden 板级件 + 命令级测量（`ff 20` 三连 -22、`STATUS0=0x20003`，见 `RFC-SCOPE.md`）作证据，不预设结果。

### D. 时效风险

- 门禁绿状态不因时间失效，**只有 base 会漂**（`GATES.md §5`：rebase + 4×checkpatch + check-series-selfcontained，实测 ≤30 min）。当前（2026-11-06 master）实测 apply 漂移 = 0；投递日复跑一次即可。

## §4 复现命令

```bash
# 0) 树基点记录
cd /home/xuqianhui/y700-elden/build/m3v2-7.3rc7
git log -1 --format='%H %cd' FETCH_HEAD          # d48723711bae… 2026-11-06 master

# 1) 建临时 worktree（不落地任何东西到项目树）
git worktree add --detach /tmp/m6-v2-check d48723711bae
cd /tmp/m6-v2-check
D=/home/xuqianhui/y700-elden/patches/upstream/m6-b5-v2-20261102

# 2) 按序整列 apply 检查（不落地）
for p in 0001 0002 0003 0004; do f=$(ls $D/${p}-*.patch); git apply --check "$f" && echo "$p OK"; done

# 3) 单枚独立性（预期 0003/0004 失败 = 依赖前枚）
git worktree remove --force /tmp/m6-v2-check
git worktree add --detach /tmp/m6-v2-check d48723711bae && cd /tmp/m6-v2-check
for p in 0001 0002 0003 0004; do f=$(ls $D/${p}-*.patch); git apply --check "$f" 2>&1 | head -1; done
git worktree remove --force /tmp/m6-v2-check

# 4) 行数/文件核对
for p in 0001 0002 0003 0004; do git -C /home/xuqianhui/y700-elden apply --numstat $D/${p}-*.patch 2>/dev/null || \
  git apply --numstat $(ls $D/${p}-*.patch); done   # 在任一 git 树内跑 --numstat
```

---
- 生成：2026-11-07，agent 静态备料；只读 + 仅本文件一个新产物。
