# m-gic-its-claim-20261024 — irqchip/gic-v3-its：kexec 继承 LPI 表要「认领」而不是「重来」

> 状态：**已投递（2026-10-24，用户批准）** `<20261024075856.835932-1-xiaqinghuan@mail.ustc.edu.cn>`；`/lkml/` 与 `/linux-arm-kernel/` 均已归档
> 关联：`reports/kexec-target-boots-20261024.md` §7/§8、`TASKS/sessions/2026-10-24-kexec-its-lpi-claim.md`、`PITFALLS #378/#379`

## 0. 一句话

kexec 到「LPIs 已使能」的内核时，incoming 内核按现状会试图**清 LPI 再重建表**；但 SM8750 上
`GICR_CTLR.EnableLPIs` 是 **RES1**（写 0 无效）、而 DT 启动又没有任何持久保留机制（`fdt_add_mem_rsv` 实测
`-FDT_ERR_NOSPACE`），于是 `its_cpu_init()` 直接短路、LPI 永不重配、ITS 命令全部等超时
（99×1.25 s，`/init` 126 s）。补丁把「重建」改成「**认领**继承的表」（`memblock_reserve`），走既有
`RDIST_FLAGS_RD_TABLES_PREALLOCATED` 路径：`/init` 回到 **1.31 s**。

## 1. 补丁清单

| # | 文件 | 内容 |
|---|---|---|
| 1 | `0001-irqchip-gic-v3-its-Claim-LPI-tables-inherited-across.patch` | `gic_check_reserved_range()` 拆成纯查询 `gic_range_is_reserved()` + 认领助手 `gic_claim_inherited_lpi_table()`；`enabled_lpis_allowed()` 与 `its_cpu_init_lpis()` 的 preallocated 分支改为「未保留则 `memblock_reserve` 认领」，claim 失败才 taint |

## 2. 设计取舍

- **为什么不是退出侧 quiesce 就够**：vk153 实测只把 99→33 次超时（`/init` 126→43 s），因为根因在 incoming 侧。
- **为什么不发 `fdt_add_mem_rsv`**：vk159 打点实测 `ret=-3 (-FDT_ERR_NOSPACE)`，ABL 的 live DTB `rsv 0->0`
  且无余量；且 kexec 在 `kexec -l` 时就克隆完 FDT，跳转时再改已晚。
- **为什么 `memblock_reserve` 合法**：`enabled_lpis_allowed()` 在 `its_init()`（`of_irq_init()` 阶段）调用，
  早于 `memblock_free_all()`，页尚未进入 buddy；性质待发表在 CPU bring-up 时认领，属尽力而为（见 §5 局限）。
- **对普通启动惰性**：`enabled_lpis_allowed()` 只在「进来时 `EnableLPIs=1`」被调用；preallocated 分支只在该 flag
  存在时进入 ⇒ 冷启动路径零行为变化。这是可上游化的前提。
- **不再 taint**：原代码在「表未保留」时 `add_taint(TAINT_CRAP)`；现在这种情况是**可恢复且常见**（DT+kexec），
  改为认领；只有认领失败才 taint。

## 3. 机械门（`.pi`/`patches/upstream/README.md` §1）逐条结果

| 门 | 命令 | 结果 |
|---|---|---|
| 1 风格 | `checkpatch.pl --strict --no-tree` | **0 errors, 0 warnings, 0 checks**（73 行） |
| 2 binding | — | N/A（无 DT/yaml 改动） |
| 3 DTS | — | N/A |
| 4 编译 | `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- drivers/irqchip/irq-gic-v3-its.o`（7.2.0 + 补丁、vk151 config） | `CC` 通过，**0 warning**（首版有 `-Wunused-function`，已把旧函数并入新助手消掉） |
| 5 干净应用 | `git am --3way`（干净 worktree @ `ba28ec16f0`） | rc=0，提交 `643dd8383f` |
| 6 收件人 | `get_maintainer.pl --no-git-fallback --no-rolestats` | **To** Thomas Gleixner；**Cc** Marc Zyngier / linux-arm-kernel / linux-kernel |
| 7 投递 dry-run | `git send-email --dry-run --confirm=never` | `Result: OK`，预生成 `Message-ID: <20261024073343.795643-1-xiaqinghuan@mail.ustc.edu.cn>` |

## 4. 上机证据（硬件侧，判据只有这一条）

| 判据 | 修前 | 修后 |
|---|---|---|
| `ITS queue timeout` | 99 | **0** |
| `Failed to disable LPIs` | 8 | **0** |
| `Using preallocated redistributor tables` | 无 | **有** |
| `claiming inherited LPI …table` | — | 9 次（属性表 1 + 待发表 8） |
| 到 `/init` | 126.35 s | **1.31 s** |

复现：`reports/artifacts/kexec-pstore-probe-20261024/k16-*`（目标逐字 dmesg，由 initramfs 在 `switch_root`
之前写盘）；对照 `k15-*`（vk158，未生效）。

## 5. 已知局限（预期 reviewer 会问）

1. **待发表的认领发生在 CPU bring-up**（`its_cpu_init_lpis()`），此时 `memblock_free_all()` 可能已执行，
   `memblock_reserve()` 可能只是记账而非真把页取回。属性表的认领（决定性的一步，决定
   `RDIST_FLAGS_RD_TABLES_PREALLOCATED`）发生在 `its_init()`，是有效的。若 reviewer 要求严格，
   v2 可改为在 `its_init()` 里遍历 redistributor 帧、按 `GICR_PENDBASER` 一次性认领待发表。
2. **前提是「表内容仍然有效」**：只有从「LPIs 已使能的内核」kexec 才成立；若中间被非内核代码改过，
   仍可能坏。补丁不改变这一前提，只是不再把有效表丢掉。
3. 只在 SM8750 / TB322FC 上实测（`GICR_CTLR.EnableLPIs` RES1 的实现）；对 EFI 启动路径无影响。

## 6. 投递记录

- 2026-10-24 15:58 (+0800)：`git send-email`（USTC 通道）**已发**，SMTP `Result: 250`；
  Message-ID **`<20261024075856.835932-1-xiaqinghuan@mail.ustc.edu.cn>`**。
  To Thomas Gleixner；Cc Marc Zyngier + linux-arm-kernel + linux-kernel。
- **归档复核（2026-10-24）**：`https://lore.kernel.org/lkml/<MID>/raw` 与
  `https://lore.kernel.org/linux-arm-kernel/<MID>/raw` **均取到全文**（LKML 带
  `X-Mailing-List: linux-kernel@vger.kernel.org`，arm-kernel 带 `List-Id: <linux-arm-kernel.lists.infradead.org>`）；
  正文与本地补丁逐 hunk 一致（`index 6f5811aae5..6dcd903e9f`、结尾 `-- \n2.53.0` 相同）。
  ⚠ 工具说明：`~/.local/bin/lore-query.py` 对当前 Anubis（v1.26.2，`algorithm: fast`）**过不去**（`pass-challenge` 404）；
  本轮改用 `web_fetch(provider=firecrawl)` 取 raw 成功 —— 下次优先用这条。
- 上机确认（投递前用**最终补丁文本**重做）：vk161，目标 `ITS queue timeout` **0**、
  `Failed to disable LPIs` **0**、claim 属性表 1 + 待发表 1、`/init` **1.275 s**。
