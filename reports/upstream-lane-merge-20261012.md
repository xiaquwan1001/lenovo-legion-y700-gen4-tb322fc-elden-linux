# 上游回移 lane 收尾：按裁决清洗 + 合入基线 + 出日常镜像 — 2026-10-12

> 承接 `reports/upstream-backport-lane-verdict-20261012.md`（子代理裁决）与 `reports/upstream-hits-review-20261012.md`。
> 本轮 = 按裁决**清洗** lane（删死文件、丢已 revert 的 hunk）→ **合入功能基线** → **出日常镜像 vk124**。

## 0. 结论（数字先行）

| # | 项 | 值 |
|---|---|---|
| 1 | 清洗后分支 | `elden/lane-upstream-clean` @ `5b169d541`（3 commit） |
| 2 | 清洗内容 | ① `a00945de6`：**删** `drivers/firmware/qcom/qcom_scm_trace.h`（零引用死文件）；② `169d74806`：**丢** `dsi_host.c` 的 byte-clk 取整 hunk（上游已 revert 的 `6cd33b6f4155`） |
| 3 | delta 文件数 | 14 个（原 15 个）——`dsi_host.c` 与 `qcom_scm_trace.h` 均不在 delta ✅ |
| 4 | 独立构建复验 | **编排者自跑**：canonical config `f008aae4`（全程未变）+ `ARCH=arm64` + ccache 交叉编译，受影响 `.o` 全部 `CC` 重编 **rc=0**；`make dtbs` 重建 sm8750-mtp/qrd **rc=0**；`git status --porcelain` 空 |
| 5 | 合并 | `clean/base` **fast-forward** `5d01d3324` → `5b169d541`（与 lane-clean 逐字一致） |
| 6 | 新日常镜像 | `out/boot-elden-vk124-merged.img` sha `7f2136ae…`，85 319 680 B；内核载荷 `059a83f5…`；**DTB `5d658a2c` / ramdisk `35823240` / cmdline / UTS 身份 `#121` 与 vk113/vk123 逐字同** ⇒ 唯一变量 = 这 3 个回移 commit |
| 7 | 状态 | `verification=NOT_TESTED_ON_DEVICE`（未上机；写 boot_b 前按协议要 3× 真实 POR 冷起全 GOOD） |

## 1. 清洗到位的依据（复核）

- `git diff --name-only clean/base..elden/lane-upstream-clean | grep -E 'dsi_host.c|qcom_scm_trace'` ⇒ 空。
- 死文件判断复核：全树 grep `qcom_scm_trace` 只命中它自身的 `TRACE_INCLUDE_FILE`（无 `CREATE_TRACE_POINTS`/无 include/无调用点）。
- 丢弃依据复核：lane 的 `dsi_host.c` 增删行集合与 `reference/upstream-pengyuluo/patches/6cd33b6f4155.patch` **完全相同**（该提交被 revert，后由 `2028280686f4` 修正；本项目 vk114 实测修正版对 Q28 亦无效）。

## 2. 保留内容清单（14 文件）

| 组 | 文件 |
|---|---|
| audio | `sound/soc/qcom/lpass-cpu.c`、`qdsp6/q6apm.c`、`qdsp6/q6apm-dai.c` |
| wireless/firmware | `drivers/bus/mhi/host/main.c`（**仅 SOC_RESET 刷新**，SCM tracepoint 未实现故随死文件一并去掉） |
| drm/msm | `adreno/a6xx_gmu.c`、`adreno/adreno_gpu.c`、`disp/dpu1/dpu_core_perf.c`、`disp/dpu1/dpu_hw_ctl.c`、`dp/dp_ctrl.c`、`msm_gpu.c`、`msm_ringbuffer.c`、`msm_ringbuffer.h` |
| DTS（参考板） | `sm8750-mtp.dts`、`sm8750-qrd.dts`（PHY 供电） |

## 3. 未做 / 边界

- **未上机**：`vk124-merged` 只是构建产物；**写 boot_b 需先 3× 真实 POR 冷起全 GOOD**（`scripts/q28-cold-run.sh` + `q28-devprobe2.sh` 三态 + ≥65 s 存活门），当前 boot_b 仍 = `vk94`。
- **Q28 未修**：本镜像**不含**任何 Q28 修复；日常可用性靠看门狗兜底（`reports/q28-watchdog-20261012.md`）。
- 上游文本核对（子代理提示的「未尽事项」）未做：本仓是浅快照，无法本地比对 7.2.5–7.2.10 的 commit 文本；如需向上游提交回移，再单独核 trailer/描述。
- 原 `elden/lane-upstream` 分支保留未删（可回溯）；`verify/lane-rebase-20261012`、`verify/lane-on-vanilla-20261012` 亦保留。
