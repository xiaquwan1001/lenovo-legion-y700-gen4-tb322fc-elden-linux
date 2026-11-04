# wl2868c v6 — 门禁记录（GATES）

> 复跑入口：`bash /tmp/gate-v6.sh`（脚本与 `gates.log` 同批生成；`gates.log` = 本文件全部输出的原始日志）。
> 判定：**全绿**（0 ERROR；2 条预期内 WARNING，见 §2）。所有输出均为 2026-11-04 03:14Z 在本机实跑。

| 项 | 值 |
|---|---|
| base commit | `05441d697f7f9a927264f4058cbbc6a03dfcac9d`（torvalds master，`v7.3-20183-g05441d697f7f`，2026-11-03 08:36:32 -0800） |
| 系列 tip | `2a533369566710c78ff82d545fb17454ea332df8`（分支 `build/wl-v2` @ `wl2868c-v6`） |
| 系列枚数 | 5（cover + 5 补丁，+466 行 / 8 文件） |
| 产物 | `patches/upstream/wl2868c-20261104-v6/v6-000{0..5}-*.patch` |

## 1. 门禁总表

| # | 门禁 | 命令 | 结果 |
|---|---|---|---|
| 1 | checkpatch --strict（**stdin** 喂，PITFALLS #474） | `cat v6-000N-*.patch \| perl <tree>/scripts/checkpatch.pl --strict --no-signoff -` | 5/5 枚 **0 ERROR**；WARNING 合计 2 条（0001、0004，均 "MAINTAINERS need updating?"，见 §2） |
| 2 | 系列自足性 | `scripts/check-series-selfcontained.sh patches/upstream/wl2868c-20261104-v6 05441d697f… --repo build/wl-v2` | `PASS=5 FAIL=0 WARN=0`，退出码 0（6 文件按序重放成功） |
| 3 | pristine `git am` 逐枚（**无 --3way**） | 新 worktree `--detach 05441d697f…`，逐枚 `git am` | 5/5 rc=0；终态 `git diff --quiet 2a53336956` ⇒ **与分支 tip 同树** |
| 4 | 驱动编译 W=1 | `make O=/tmp/wlv6-out -j26 W=1 drivers/regulator/` 及 `… drivers/regulator/wl2868c-regulator.o` | rc=0，**0 warning**（`CC [M] drivers/regulator/wl2868c-regulator.o`） |
| 5 | DTB 构建 | `make O=/tmp/wlv6-out -j26 W=1 qcom/sm8750-lenovo-elden.dtb` | rc=0，**0 error**；2 条 WARNING 全部来自上游 `sm8750.dtsi` 的两个 dsi 节点（`avoid_unnecessary_addr_size`，非本系列）；产物 104 044 B |
| 6 | dt-validate（board dtb） | `dt-validate -m -s Documentation/devicetree/bindings …/sm8750-lenovo-elden.dtb` | rc=0，**零输出 = 0 诊断**（v5 同口径下是 6 行，因本系列已移除 gt9764/s5kjns 节点） |
| 7 | dt-doc-validate（只跑该 binding） | `dt-doc-validate …/regulator/willsemi,wl2868c.yaml` | rc=0，0 字节输出 |
| 8 | dt-check-style（该 binding） | `python scripts/dtc/dt-check-style --mode=strict …/willsemi,wl2868c.yaml` | rc=0，0 字节输出 |
| 9 | dt_binding_check（该 binding，含 example 编译 + 校验） | `make O=/tmp/wlv6-out dt_binding_check DT_SCHEMA_FILES=…/willsemi,wl2868c.yaml` | rc=0（SCHEMA/LINT/STYLE/DTEX/DTC 全过） |
| 10 | apply 失败根因复现 | 同一 base 上重放 v5 4 枚 | 0001–0003 rc=0、**0004 rc=128 `补丁失败：arch/arm64/boot/dts/qcom/Makefile:406`** |

## 2. 两条预期内 WARNING（逐条给解释，不是"已修"）

1. **0001 "added, moved or deleted file(s), does MAINTAINERS need updating?"** — 该枚只新增 `willsemi,wl2868c.yaml`，而 MAINTAINERS 条目随驱动的 `wl2868c-regulator.c` 落在 0002。checkpatch 的这条只看「本枚是否新增文件」，无法跨枚满足；把 MAINTAINERS 挪进 binding 枚反而是错放。
2. **0004 同一条** — 该枚新增板 DTS + Makefile 一行；板文件没有需要维护的 MAINTAINERS 模式（`arch/arm64/boot/dts/qcom/` 由 ARM/Qualcomm 平台条目覆盖，无逐板条目）。

对照 v5：v5 0001 的 "DT binding docs and includes should be a separate patch" 1 条 W **已消失**（`arm/qcom.yaml` 拆成独立 0003），0004 的 3 条 W（binding 同枚 + MAINTAINERS + gt9764/s5kjns 未文档化）全部消失。

## 3. cover-letter 的 checkpatch（仅记录，不作门禁）

`cat v6-0000-cover-letter.patch | checkpatch --strict -` 输出：
- `ERROR: Does not appear to be a unified-diff format patch` —— cover 本身无 diff，任何 cover 都会报，**预期**；
- `WARNING: Prefer a maximum 75 chars per line` —— 唯一 >75 字符的行是 `git format-patch` 自动生成的 diffstat 行 `create mode 100644 Documentation/…wl2868c.yaml`（85 字符），不可改。

## 4. 未证（本机无法在这轮给出证据的）

1. **硬件未验证**：i2c10 probe、regulator 注册、cci 引脚复用、LDO 电压与 preset 位行为均未上机（本任务禁碰设备）。driver 修复的证据只到「编译通过 + 代码路径自洽」。
2. **VSYS 电压 / 父 PMIC 未证**：板 DTS 把 VSYS 建模为无电压约束的 `regulator-fixed`（系统常开轨），因为生成它的 SPMI PMIC 不在本系列、也未经测量确认。`VIN12/VIN34/VIN5/VIN7` 同理未描述。
3. **`gpio-reserved-ranges = <39 1>, <74 1>`** 沿用 v5（来自我们自己的下游板 DTS），未在本轮重新取证。
4. **CI 验证未跑**：没有 `b4`/`make dtbs_check` 全量（只跑单板 dtb + 单 binding），未跑全量 dtbs_check 以免被无关板的既有告警淹没。
