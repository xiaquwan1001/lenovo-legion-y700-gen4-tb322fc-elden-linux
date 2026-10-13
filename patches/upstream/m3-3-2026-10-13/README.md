# M3-3 音频 + 温控片（2026-10-13）

上游基线：
- **pristine 参照 = tag 提交** `24a19b953e`（`Linux 7.3-rc7`）。
- 本片工作树 = `build/m3-3-worktree`（分支 `m3-3/audio`，pristine `24a19b953e`，tip `17507cd07242b291f331cf37b7eec5f0cbd63725`）。
- 规则 = `reports/upstream-policy-20261013.md`；依赖面 = `reports/m3-missing-support-matrix-20261013.md`；本片分析 = `reports/m3-3-audio-thermal-slice-20261013.md`。

## 补丁 —— 2 枚就绪（未发送）

| 补丁 | 主题 | 内容 |
|---|---|---|
| `0001-dt-bindings-sound-awinic-aw88395-add-AW88461-compati.patch` | `dt-bindings: sound: awinic,aw88395: add AW88461 compatible` | 家族 binding `awinic,aw88395.yaml` 的 `compatible` enum 增加 `awinic,aw88461`（1 行） |
| `0002-ASoC-codecs-aw88461-add-Awinic-AW88461-smart-amplifi.patch` | `ASoC: codecs: aw88461: add Awinic AW88461 smart amplifier driver` | `sound/soc/codecs/aw88461.c`（547 行，复用 `aw88395/` ACF 解析层）+ `Kconfig SND_SOC_AW88461`（`select SND_SOC_AW88395_LIB`）+ `Makefile` 两行 + `MAINTAINERS` 家族条目 |

commit：`e71bede6e6c2695d2f89e43ca4a6387c69494eb3`（0001）、`17507cd07242b291f331cf37b7eec5f0cbd63725`（0002）。
sha256：0001 = `91a51def4950e167c7def0d21263131ef92eaf7353b555271fe0d78b64068230`；0002 = `fd4de4a43e146f058a1e92e7a93789da1773bc202b3de25c377d8b165eb77ce1`。

## 验收证据（全部本机实跑）

| 门 | 命令 | 结果 |
|---|---|---|
| checkpatch | `build/m3-3-worktree/scripts/checkpatch.pl --strict --no-tree patches/upstream/m3-3-2026-10-13/*.patch` | 2/2 **0E/0W/0C**「ready for submission」 |
| binding 自检 | `PATH=~/venv-dtschema/bin:$PATH dt-doc-validate …/awinic,aw88395.yaml` | **rc=0** |
| 编译 | `make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- sound/soc/codecs/` | **rc=0**，`CC aw88461.o`，0 error/0 warning |
| 干净应用 | `git am`（pristine `24a19b953e`，临时树 `/tmp/m33-verify`） | **rc=0** |
| 无测试钩子 | `grep -nE 'module_param|MODULE_PARM|debugfs|printk(|dev_dbg' 0002*.patch` | 无匹配（EXIT=1） |

## Q2 结论（详见报告 §1）

**`awinic,aw88461` 判「并入 aw88395 家族」**，但按上游家族既有形态落地 = **家族成员文件 `aw88461.c` + 复用 `aw88395/` 共享 ACF 解析层 + 家族 binding 登记**，**不**把 aw88461 塞进 `aw88395_device.c` 的 chip_id switch（其 DSP/SRAM/校准序列与 aw88461 硬件不符，塞入=改造量过大 + 污染共享层）。上游 `aw88261.c`/`aw88399.c` 即此同一范式（各自 `select SND_SOC_AW88395_LIB`）。

## 设计取舍（供 review 与后续片复用）

- **驱动文件与 payload 逐字节相同**：payload 的 aw88461.c 本已是家族形态（include `aw88395/aw88395_device.h`、调用 `aw88395_dev_load_acf_check`/`aw88395_dev_cfg_load`），且无测试钩子/调试参数，故未改写。
- **MAINTAINERS 并入 0002**：上游原无 AW88395 家族条目，新增文件触发 checkpatch `MAINTAINERS need updating?` 警告，故一并补家族条目（`F: sound/soc/codecs/aw88*`）。若要求拆分可另立补丁。
- **DTS 不入本片**：板 DTS 的 `speaker_left/right`/`sound`/`wcd939x` 节点归 **M3-2 板基础片**（见报告 §3）。
- **后续项**：抽 `aw88461.h`（寄存器/位定义）与音量语义对齐需 PID 2308 硬件证据，见报告 §1.3 #3。

## 发送纪律

英文 commit + `Signed-off-by: Xu Qianhui <xiaqinghuan@mail.ustc.edu.cn>`；在**树根**跑 `scripts/get_maintainer.pl` 取收件人（binding 维护者 Weidong Wang <wangweidong.a@awinic.com>、linux-sound）；`git send-email --dry-run --confirm=never`（git 2.53 无 `--no-confirm`）通过后发送；lore 复核归档（技能 `upstream-mail-ustc`）。
