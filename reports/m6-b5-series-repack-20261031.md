# M6/B5 —— 按「0002 表驱动 + 0005 只做命名」重出可投序列

- 日期：2026-10-31
- 执行：叶级 worker（M6/B5 派工单），时间盒内完成
- 基树：`build/vk151`，base commit `0f1fb1c9c1`；全程只在 `/tmp/m6-repack/wt` 临时 worktree 操作，未写 `build/vk151` 工作树

## §0 结论

**PASS**。5 枚补丁已在 `patches/local/b5-resoc-20261027/` 全部重出（旧的裸 diff 0004 与旧 0005 已覆盖，仍为 5 枚），
三道门禁全绿：self-contained PASS=5 FAIL=0 WARN=1（仅缺 cover）、每枚 checkpatch --strict 0E/0W/0C、
arm64 `make -j26 W=1 drivers/gpu/drm/msm/` 0 error / 0 warning。

## §1 序列终态（5 枚 Subject）

| # | Subject | 文件 |
|---|---|---|
| 0001 | drm/msm/dsi: move bonded command failure flag into dsi manager state | dsi_manager.c |
| 0002 | drm/msm/dsi: add per-SoC bonded command-path config | dsi_cfg.c/h、dsi_host.c |
| 0003 | drm/msm/dsi: route the bonded command path through host ops | dsi.h、dsi_host.c |
| 0004 | drm/msm/dsi: take bonded DSI master cfg from per-SoC config | dsi.h、dsi_host.c、dsi_manager.c |
| 0005 | drm/msm/dsi: name the FIFO error bits of the bonded command path | dsi_cfg.c |

临时 worktree 顶 5 行（完整见 artifacts）：

```
95eec158c8 drm/msm/dsi: name the FIFO error bits of the bonded command path
996eae17e3 drm/msm/dsi: take bonded DSI master cfg from per-SoC config
ea85fbd29a drm/msm/dsi: route the bonded command path through host ops
88e0b6cec7 drm/msm/dsi: add per-SoC bonded command-path config
5969660291 drm/msm/dsi: move bonded command failure flag into dsi manager state
```

## §2 新 0005（命名岗）做了什么

只改 `dsi_cfg.c`（+26 −4），**不引入新数据路径、不绕过 `bonded->` 字段**：

- 在 `sm8750_dsi_bonded_cfg` 表前定义两组宏，均带出处注释：
  - `DSI_ERR_INT_MASK0_FIFO_ERRORS = GENMASK(20,16) | BIT(9)`（mask 侧；dsi.xml 无该寄存器布局，
    bit16..19 = DLN0..3 HS FIFO overflow，**bit20 随组、无公开名字**，bit9 = cmd DMA FIFO underflow；
    分组出处 = vendor `mask_error_intr()`，注释写明"not guessed"）；
  - `DSI_FIFO_STATUS_FIFO_ERRORS` = 五个 dsi.xml 有名的 W1C 位之或
    （`CMD_DMA_FIFO_UNDERFLOW` bit10 + `DLN0..3_HS_FIFO_OVERFLOW` bit18/22/26/30）。
- 表初值改为 `.err_clear_bits = DSI_ERR_INT_MASK0_FIFO_ERRORS`、
  `.err_cleanup_bits = DSI_FIFO_STATUS_FIFO_ERRORS`；两组宏均展开回原字面量（0x001f0200 / 0x44440400），无功能变化。
- **删除** 0002 留下的 `TODO(doc): … dsi.xml does not describe` 注释（出处已进宏注释）。

## §3 与旧版差异

- **旧 0005**：直接在 `dsi_host.c` 里给内联魔数加宏并改名，与 0002 的表驱动冲突（其旧侧上下文是 0002 改前的 `{ u32 val; …}`），不可重放。
- **新 0005**：落在 0002 的 per-SoC 表上（dsi_cfg.c），`dsi_host.c` 继续只消费 `bonded->err_clear_bits/err_cleanup_bits`；
  宏名与旧版一致（`DSI_ERR_INT_MASK0_FIFO_ERRORS` / `DSI_FIFO_STATUS_FIFO_ERRORS`），出处注释更完整（bit20 随组说明）。
- **旧 0004**：裸 `diff --git`，无 `From` 头，不能 `git am`。**新 0004**：format-patch 形态，作者
  `Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>`（按项目口径）；commit message 为按补丁内容新撰（裸 diff 无原文可考，
  正文写明"从 per-SoC 表解析 master、无表回落 DT、SM8750 无功能变化"），已在报告中标注。
- 0001–0003 补上 `Signed-off-by:`（原版缺，checkpatch --strict 报 Missing Signed-off-by）。

## §4 门禁（原文在 `reports/artifacts/m6-repack-20261031/`）

| 门禁 | 结果 | 落盘 |
|---|---|---|
| `bash scripts/check-series-selfcontained.sh patches/local/b5-resoc-20261027 0f1fb1c9c1 --repo build/vk151` | **PASS=5 FAIL=0 WARN=1**（仅"缺 cover letter"） | selfcontained.log |
| 每枚 `cat x.patch \| perl build/vk151/scripts/checkpatch.pl --strict -` | **5 枚全部 0E/0W/0C** | checkpatch-000*.log ×5 |
| `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- make -j26 W=1 O=<tmp>/kb drivers/gpu/drm/msm/`（config 取自 `build/b5-resoc/.config` + olddefconfig） | **rc=0，0 error / 0 warning**，dsi_cfg.o/dsi_host.o/dsi_manager.o 实际重编 | kbuild.log |

注：编译门为全量 `drivers/gpu/drm/msm/` 目录、arm64 交叉编译，非 x86 host 全内核构建。

## §5 复现命令

```sh
git -C build/vk151 worktree add --detach /tmp/m6-repack/wt 0f1fb1c9c1
cd /tmp/m6-repack/wt
git am ../../<abs>/patches/local/b5-resoc-20261027/000{1,2,3}-*.patch   # 前 3 枚
git am 0004 0005（新版均为 format-patch 形态，可直接 am）
git format-patch -5 --base=0f1fb1c9c1 -o /tmp/m6-repack/out4
bash scripts/check-series-selfcontained.sh patches/local/b5-resoc-20261027 0f1fb1c9c1 --repo build/vk151
for f in patches/local/b5-resoc-20261027/*.patch; do cat $f | perl build/vk151/scripts/checkpatch.pl --strict -; done
ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- make -j26 W=1 O=<tmp>/kb drivers/gpu/drm/msm/
```

## §6 备忘

- 0001–0003 的正文尾部仍带内部 trailer（`Lane:/Agent:/Baseline:/Task:`，0002/0003 有）——本轮只按裁决修 0004/0005，
  投递前是否剥离这些 trailer 留给总管裁决。
- 临时 worktree 已从 vk151 注销（`worktree remove` + prune），未留残余。

---

## 6. 总管独立复核（2026-10-31）

| 判据 | 复核命令 | 实测 |
|---|---|---|
| 序列自足 | `check-series-selfcontained.sh patches/local/b5-resoc-20261027 0f1fb1c9c1 --repo build/vk151` | 5 枚全 `ok`、**PASS=5 FAIL=0 WARN=1**（唯缺 cover）✅ |
| checkpatch(stdin) | 逐枚 `perl …/checkpatch.pl --strict - < 000N-*.patch` | **5/5 "no obvious style problems and is ready for submission"** ✅ |
| 编译门（总管自跑，独立 tree） | 临时 worktree@`0f1fb1c9c1` + `git am` 5 枚 + 拷 `build/vk151/.config` + `olddefconfig` + `make -j26 W=1 drivers/gpu/drm/msm/` | **rc=0、`warning:`/`error:` 计数 0**、`dsi_cfg.o`/`dsi_host.o`/`dsi_manager.o` 实生成 ✅ |
| 设计合规（表驱动 + 只命名） | `sed -n '1,60p' 0005-*.patch` | 0005 只动 `dsi_cfg.c`：定义 `DSI_ERR_INT_MASK0_FIFO_ERRORS`(GENMASK(20,16)\|BIT(9)) 与 `DSI_FIFO_STATUS_FIFO_ERRORS`（五个有名 W1C 位）、表初值改宏、删 `TODO(doc)`；**未绕 `bonded->err_*` 字段** ✅ |

**踩到的工具坑（不是代码问题）**：第一次 `make` 直接用了宿主 gcc ⇒ `-mlittle-endian`/`-msign-return-address` 报错。交叉编译必须走项目口径（`source scripts/env-build.sh` 的 `CROSS_COMPILE="ccache aarch64-linux-gnu-"` + `CC`/`HOSTCC`）。已记入本报告，避免下次误判为"补丁编译不过"。

**遗留 3 项（已派单 `impl-worker`，单号 = 本报告 §7）**：① 0001–0003 混入 `Lane:/Agent:/Baseline:/Task:` 记账 trailer（非上游标签，投递前剥）；② 缺 cover（门禁唯一 WARN）；③ 0004 的 commit message 把"FIFO error mask"塞进 master 归属的说明里，归因不准。
