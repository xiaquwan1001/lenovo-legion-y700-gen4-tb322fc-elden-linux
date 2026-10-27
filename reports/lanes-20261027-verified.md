# 三条 lane 收口：编排者独立复核（2026-10-27，模型 `custom-nexavlinks-com/deepseek-v4.1-flash`）

> 本文只记**编排者自己重跑过的**判据（不采信 worker 自报）。派工单 = `.pi/lanes/*-brief.md`
> （含第二节「续跑状态」，为上一轮被中断后补写的实测现状）。三条 lane 均**未 push、未投递、未改 SSOT**。

## §0 结论（数字）

| lane | lane tip | 内核树 | 产物 | 独立复核 |
|---|---|---|---|---|
| `b5-resoc` | `ea6c518` | `build/b5-resoc` `768b7c11d`（3 commit） | 3 枚补丁 + 报告 139 行 | ✅ 判据 5/5 达标；**逐提交**编译 rc=0/0 warning（`-W=1`） |
| `aw86927-series` | `41f9996` | `build/aw-series` `409beee0a`（5 commit） | 5 枚补丁 + README 59 行 + 报告 192 行 | ✅ checkpatch 5/5 = 0E/0W/0C；`dt-doc-validate` rc=0；`aw86927.o` rc=0/0 warning；逐枚 `git apply` 全成功 |
| `devcam-ab` | `72acfd3` | 设备载荷树 `build/vk151`（仅热换，未留 diff） | 报告 201 行 + 4 行 patch + 2 trial record | ✅ 源码已复原（`git status` 空）；设备运行模块 build-id 回到原始 `2dd23e54…`；4 行复读回 `0x54` |

## §1 `b5-resoc`（B5 bonded-DSI 第 1–3 步，行为中性）

判据（编排者本机重跑，目录 `build/b5-resoc`）：

| 判据 | 要求 | 实测 |
|---|---|---|
| `grep -c 'static bool dsi_bonded_cmd_failed' dsi_manager.c` | =0 | **0** |
| `grep -c '0x001f0200' dsi_host.c` | =0 | **0** |
| `grep -c '0x44440400' dsi_host.c` | =0 | **0** |
| `grep -c 'msm_dsi_host_bonded' dsi.h` | ≤3 | **2** |
| `git grep -c 'msm_dsi_host_bonded_' dsi_manager.c` | 只剩 ops 调用点 | **0 直调** |

编译门（`CCACHE_DISABLE=1`，显式 `aarch64-linux-gnu-gcc`，`-j26`）：

```
5a3edf6e2 rc=0 warnings=0 errors=0     # 提交 1
fb8f38d95 rc=0 warnings=0 errors=0     # 提交 2
768b7c11d rc=0 warnings=0 errors=0     # 提交 3
```
另跑一次 `make drivers/gpu/drm/msm/`（W=1，全目录）rc=0、`warning:` 计数 **0**。

值保持等价：`err_clear_bits=0x001f0200`、`err_cleanup_bits=0x44440400`、`poll_timeout_us=5000`
逐字搬进 `dsi_cfg.c` 的 `sm8750_dsi_bonded_cfg`（带 `TODO(doc)` 注释指向 RFC-SCOPE R1），
`dsi_host.c` 全部改读 `bonded->*`，**没有**把魔数换个地方留在实现里。

**需人工拍板的一点**：bonded 表挂在既有 `sm8650_dsi_cfg` 上（SM8750 报 DSI 6G v2.9、
`io_start` 只有该表能匹配），靠 `qcom,sm8750-dsi-ctrl` compatible 闸门限制使用范围。
真 SM8650 因此不受影响，但"SM8750 的数据挂在 SM8650 表项上"这层结构在评审时会被问——
若要彻底干净，需要在设计稿第 4 步里拆出独立 SM8750 表项。

## §2 `aw86927-series`（U4，5 提交上游系列草案）

`perl scripts/checkpatch.pl --strict --no-tree`（编排者重跑）：

| 补丁 | total |
|---|---|
| `0001-dt-bindings…` | 0 errors, 0 warnings, 0 checks, 42 lines |
| `0002-…chip-data-table` | 0 errors, 0 warnings, 0 checks, 132 lines |
| `0003-…RAM-waveform` | 0 errors, 0 warnings, 0 checks, 186 lines |
| `0004-…AW8693X-play-boost` | 0 errors, 0 warnings, 0 checks, 114 lines |
| `0005-…suspend-shutdown` | 0 errors, 0 warnings, 0 checks, 140 lines |

其余门：`dt-doc-validate …/awinic,aw86927.yaml` **rc=0**；`rm aw86927.o` 后
`make W=1 drivers/input/misc/aw86927.o` **rc=0 / 0 warning**；
5 枚补丁从 pristine `24a19b953` 依次 `git apply --check` + `apply` **全部成功**（临时 worktree）。

红线自查（编排者 grep）：`aw8693x_cont_play` 0 命中、`CONTCFG6/7/9` 0 命中、`AW8693X_TMCFG` 0 命中、
`0x5e` 0 命中、`elden|sm8750|tb322|lenovo` 在驱动与 yaml 里 0 命中。
（`CONTCFG1/5/10/13` 命中的是**上游 7.3-rc7 原有**的 braking 定义，不是我们移植的连续模式。）

**三处需评审注意的偏离**（worker 已自报，编排者确认存在）：
① 第 2 提交顺带把 `BASEADDRH/L_VAL` 收入 chip 表；② 第 3 提交额外 `select FW_LOADER`；
③ 第 4 提交顺手修了 pristine 的 `AW86938_PLAYCFG1_BST_7000MV 0x11 → 0x09`（用厂商
`set_bst_vol()` 公式反推：`0x11` = 9 V、`0x09` = 7 V）。第 ③ 条是**对既有上游代码的行为修正**，
按内核惯例应拆成独立 fix 并单列 `Fixes:`，不要埋在新特性提交里。

## §3 `devcam-ab`（M4 R1 剩余 4 条：SKEW_CAL A/B）

| 指标 | A 臂 `0x54`（3 次） | B 臂 `0x00`（3 次） |
|---|---|---|
| 成功帧 | 90/90 ×3 | 90/90 ×3 |
| 90 帧耗时 | 3.144 / 3.154 / 3.156 s（σ=0.0064） | 3.147 / 3.149 / 3.150 s（σ=0.0015） |
| v4l2 自报 fps | 30.26 ×3 | 30.26 ×3 |
| dmesg 错误计数 | 0 ×3 | 0 ×3 |
| 帧 STDDEV（3 帧抽查） | 53.81 | 53.78 |

判定 = **无差异**（Δ −0.08 %，远小于 A 臂自身 σ；fps 已顶 sensor 30 fps 上限，指标对 SKEW_CAL 天然不敏感）。

编排者复核：`build/vk151` 该文件 `git status` 为空、4 行复读回到 `0x54`；
设备 `modinfo -n qcom_camss` 指回 `kernel/…/qcom-camss.ko`，运行中模块 build-id
`2dd23e5446174f7a382c1b8b65ba0c7d8f787ecc` = 原始基线（`updates/` 已清空）。
两枚 trial record 的 `reset_type` 均为 `warm`（未整机重启），口径正确。

**M4 R1 处置建议**：不回退成本地改动，改为**上游化时以厂商值 `0x00` 提交并注明"本机无差异"**。
依据 = 0x54 在厂商 82 张表里无来源（`reports/m4-csiphy-vendor-provenance-20261027.md` §2），属无出处魔数。

## §4 工具侧缺陷（本轮新发现，建议修）

1. **`scripts/mod-loop.sh --reload` 对含下划线的模块名静默失败**：它用 `lsmod | grep -q '^$m '`
   对比传入的 `qcom-camss`（连字符）与 lsmod 里的 `qcom_camss`（下划线）⇒ 匹配不到、
   `modprobe qcom-camss` 失败被 `2>/dev/null` 吞掉，**仍打印 `[mod] reloaded qcom-camss`**。
   ⇒ 修法：名字归一化 `tr '-' '_'`，modprobe 失败必须非零退出。
   连带教训：`mod-loop` 的 "reloaded" 不能当证据，必须用 build-id 校验。
2. **`mod-loop.sh` 依赖陈旧的 `include/config/kernel.release`**：`M=… modules_install` 的落点来自该文件，
   `M=` 构建不刷新它 ⇒ 模块被装到 `…-dirty+/updates/`（错误 KV），热载静默无效。
   ⇒ 修法：install 前显式 `make include/config/kernel.release`。
3. 两条都表现为"静默成功"，建议在 `PITFALLS` 里落一条（父 agent 待办）。

## §5 产物清单

| 路径 | 说明 |
|---|---|
| `.pi/lanes/{b5-resoc,aw86927-series,devcam-ab}.{md,tsv}` | 派工单 + 续跑状态 + 登记表（`status=done`，含 tip） |
| `wt-b5-resoc/reports/b5-resoc-20261027.md`（139）· `patches/local/b5-resoc-20261027/000{1,2,3}` | B5 三步 |
| `wt-aw86927-series/reports/aw86927-series-20261027.md`（192）· `patches/upstream/aw86927-20261027/000{1..5}` + README（59） | U4 五提交 |
| `wt-devcam-ab/reports/m4-skewcal-ab-20261027.md`（201）· `reports/artifacts/…/b-arm-skewcal-…patch`（40）· `scripts/skewcal-{measure,frame-stats}.sh` · `reports/trials/20261027T120121Z-m4-skewcal-arm{A,B}-*.json` | SKEW_CAL A/B |
