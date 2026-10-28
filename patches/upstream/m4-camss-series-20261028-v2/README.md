# M4-2…M4-4 camss 驱动系列 **v2**（2026-10-28，回应 Sashiko 自动评审）

面向上游 `linux-media` 的 **camss SM8750 驱动主体**，9 提交。**v1 已投**（2026-10-28，
`[PATCH 0/9]` Message-ID `<20261028034105.326535-1..10@mail.ustc.edu.cn>`）。本目录 = **v2 候选，未发**，
修掉 Sashiko 自动评审（sashiko-bot@kernel.org）指出的 4 处真实问题。

- 源分支：`build/m4-base` @ **`m4/v2-20261028`**（tip `ca3d71e71`，9 提交 / 14 文件 / **+1938 −61**）
- 基线：pristine `24a19b953`（Linux 7.3-rc7）
- 评审原件：见 `reports/m4-sashiko-triage-20261028.md`

## v2 相对 v1 的改动（逐条对应 Sashiko finding）

| Patch | Sashiko 严重度 | 处理 | 改动 |
|---|---|---|---|
| 1/9 提交信息 | Medium | ✅ 改 | 提交信息计数改成与 schema 一致：**3 full + 2 lite CSID，3 full + 2 lite VFE**（原写「two full…two full plus one lite」） |
| 4/9 `dt_id = vc & 0x03` | **High** | ✅ 改 | 改成 **`port & 0x03`**（对齐 gen3 的 `ad136e52634d`）。原来 `vc` 恒为 0 ⇒ 所有 RDI 内部 CID 都是 0 ⇒ RDI>0 出流坏 |
| 4/9 `INFO_RUP_DONE` 未解掩码 | **High** | ✅ 改 | `csid_configure_stream()` 里把 `INFO_RUP_DONE` 一起使能（厂商确实使能 `rup_irq_mask=0x800000`）⇒ ISR 才能清软件 shadow |
| 5/9 `frame_started` 不回置 | Medium | ✅ 改 | `vfe_buf_done()` 消费后 `frame_started=false`；首帧前到 buffer 不再让 `sequence-1` 无符号下溢；「SOF 前完成」错误检测现在**每帧**生效 |
| 5/9 事件 ioctl 不一致 | Medium | ✅ 改 | `subscribe_event` 在无 `frame_start` 时返回 `-ENOIOCTLCMD`；删掉显式 `.unsubscribe_event`（交回 core 按 `FL_HAS_EVENTS` 回退） |
| 4/9、8/9 `aup/rup/reg_update` 竞态 | Medium | ⏸ 不改（回复） | **与 gen2/gen3 完全同形的既有上游模式**（`__csid_aup_rup_clear` 在 ISR 无锁 RMW，gen3 一字不差）。非本系列引入；要修须作为**独立的 camss 全局加锁补丁**，不塞进本系列 |
| 9/9 `csid_set_stream` 跳过 `configure_stream` | High | ⏸ 不改（回复） | 命中的是**上游既有** `camss-csid.c` 的 `need_vc_update` 门（pristine 就有，patch 9 只加 DTS）。停流时由 `v4l2_pipeline_pm_put → csid_set_power(0)` 掉电兜底；真要修属另一条 camss 修复线 |

> 说人话：**4 处真 bug 已改**（1 处 High `dt_id`、1 处 High `INFO_RUP_DONE`、2 处 Medium），另 3 处是「既有上游更广义问题」→ 回帖说明、不塞进本系列。

## 门禁（2026-10-28 全部重跑）

| 门 | 结果 |
|---|---|
| 逐提交 `make drivers/media/platform/qcom/camss/` | **9/9 rc=0、0 warning**（arm64；每次都到 `LD [M] qcom-camss.o`）。注：一条提交在 `-j26` 下撞到 **gcc-15 内部编译器崩溃**（`camss-tpg.o`，非本系列改动文件），**`-j8` 重跑即 OK** ⇒ 环境抖动非代码问题 |
| 终态 build | `LD [M] drivers/media/platform/qcom/camss/qcom-camss.o`，0 warning |
| `checkpatch.pl --strict` ×9 | **0 errors / 0 checks**；3 条 WARNING 全为同一假阳性（`added file(s), does MAINTAINERS need updating?`，patch 1/4/8） |
| pristine `git am` 9 枚 | **9/9 干净**（`/tmp/v2p`） |
| `dtbs_check` | 未重跑（schema/DTS 未改，沿用 v1 的 0 warning 结果） |
| **上机复验** | ✅ **2026-10-28 已做**：零写盘热换该 4 处修复的模块，front/rear 各 **90/90 帧、30.0–30.26 fps、错误计数 0→0**、像素正常（NONZERO 99.67%）⇒ 不回归。详见 `reports/m4-sashiko-triage-20261028.md` §5 |

## 发送

**未发。** 发送需用户按系列批准。上机复验已通过（§5）。若批准：先跑 `send-email --dry-run` 复核，再以 `[PATCH v2]` 新串（含 `Changes in v2`）。
