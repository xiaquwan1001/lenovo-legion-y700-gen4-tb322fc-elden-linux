# 上游化补丁提交前门（checklist）

> 入口纪律 = `.pi/AGENT-OPS.md` §3「上游化三问门」；规则展开 = `reports/upstream-policy-20261013.md`；
> 分片与验收口径 = `reports/m3-series-plan-20261013.md` §0。本文件只放**每次发补丁前必跑的机械门**。
> 每个系列目录（`m2-*/`、`m3-*/` …）另带自己的 `README.md` 记录该系列的设计取舍与验收证据。

## 0. 三问（写任何一行代码前，人工判定）

| 问 | 动作 |
|---|---|
| Q1 主线上游有对应子系统吗？ | 有 ⇒ **必须**用它的框架（红线表见 policy §1）；没有才自己写 |
| Q2 上游有同类芯片驱动吗？ | 有 ⇒ 扩展/复用，**不新写**（查 `of_device_id`，不是 grep compatible） |
| Q3 这是硬件事实还是软件策略？ | 硬件事实 ⇒ 进 DT/数据表；软件策略 ⇒ 进 C |

## 1. 机械门（每系列全绿才可发送）

```sh
SER=patches/upstream/<series>
# 1) 风格：每补丁英文正文 + Signed-off-by，0E/0W
scripts/checkpatch.pl --strict --no-tree $SER/*.patch
# 2) binding 自检（改动/新增的 yaml）
dt-doc-validate <每个改动的 yaml>
# 3) DTS 编译 + schema（自带 binding 口径）
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dtbs
export PATH=~/venv-dtschema/bin:$PATH
dt-validate -s Documentation/devicetree/bindings <board>.dtb      # 期望 0 诊断
# 4) 编译门（改驱动的系列）
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- <改动子系统目录>/
# 5) 干净应用门
git -C <pristine-worktree> am --3way $SER/*.patch                 # rc=0
# 6) 收件人（必须在**树根**跑）
scripts/get_maintainer.pl --no-git-fallback --no-rolestats $SER/*.patch
# 7) 投递 dry-run（git 2.53 无 --no-confirm，用 --confirm=never）
git send-email --dry-run --confirm=never --to=... $SER/*.patch
```

## 2. Q3 违例扫描（发送前 grep，命中即拦）

见 `reports/upstream-policy-20261013.md` §9：`module_param`/调试插桩 → `of_device_is_compatible("qcom,...")` 散落判定 → 跨模块全局变量（`apm_src_port`）。当前违例清单：panel `force_hz`（已剥）、DSI `dev_info` 插桩、`btqca` IBS 全局禁用、`ath12k` MHI_TIMEOUT、aw86927 魔数、Q28 `dsi_cmd_delay_us` cmdline、vendor-only DT 属性。

## 3. 发送与归档纪律

> **⏸ 投递冻结（用户 2026-10-13 决定）**：**不再发上游邮件**——所有系列只做备料（补丁 + README + 验收证据），**等项目收盘统一投递**。唯一已发出的例外 = **M3-1**（用户当时批准）。后续任何投递需用户明确批准。


- 英文 commit/补丁正文；`Signed-off-by: Xu Qianhui <xiaqinghuan@mail.ustc.edu.cn>`。
- 投递后到 lore 复核归档（技能 `upstream-mail-ustc`）；未在 lore 见到即视为未送达。
- 系列 README.md 必须写：补丁清单、每枚的设计取舍、验收命令+原始输出、收件人、发送状态（就绪未发 / 已发 + Message-ID / 已进树 + 上游提交号）。

## 4. 现状索引

| 系列 | 目录 | 状态 |
|---|---|---|
| M2 首发小系列 | `m2-2026-10-13/` | A2 battmgr 在评审；A1 已撤稿；P3 gamma LUT OOB 已发 |
| M3-1 USB 双连接器 | `m3-2026-10-13/` | ✅ **已发送并归档**（cover+3 枚，`20261013102927.1141696-1..4`；linux-usb + linux-devicetree 各 4/4） |
| M3-3 音频（aw88461） | `m3-3-2026-10-13/` | 🔒 **备料封存**：2 枚（Q2 裁定「并入 aw88395 家族」） |
| M3-4 显示（panel） | `m3-4-2026-10-13/` | 🔒 **备料封存**：4 枚（H1 `to_primary_dsi` 阻断，见 `reports/m3-4-display-slice-20261013.md` §5） |
