# M1 干净上游资产树：组装 + 构建验证（2026-10-11）

> 任务：`TASKS.md §7 M1`。上游参考：`archive/topics/UPSTREAM-REVIEW-2026-10-04.md`、
> 清单 `.pi/plans/2026-10-10-M1-资产树清单.md`（本文件是其执行结果）。
> 本轮把 M1 从「清单」推进到「**物理树已建、干净构建通过**」；未做上机（不在本任务判据内）。

## 0. 结论

| 项 | 结果 |
|---|---|
| 干净树 | ✅ 已建：`git worktree` @ `build/m1-upstream/clean-tree`，分支 **`m1/clean-tree`**，base = `v7.2-elden`（`44137cb4e`） |
| payload 重放 | ✅ 2 个独立 patch（`git apply`）+ 10 个功能 cherry-pick + 1 个 2026-10-11 新增（ADSP non-secure） |
| 构建 | ✅ `Image.gz`（20.6 MB）+ `dtbs` 全绿；`arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb` 149 KB；内核 UTS=`7.2.0-debug-m1-gc73ff25222c7` |
| 判据「树能编出 vk 等价功能镜像」 | ✅ **能编出**（用 vk64 好 config a383cdb9 + c1 片段；`ARCH_QCOM`/`IP_ADVANCED_ROUTER` 保留）。**功能等价 = 按清单 §3 的逐域对照（argument），`fastboot boot` 上机对照未做** |

## 1. 树与分支

```bash
build/m1-upstream/clean-tree  ← git worktree, branch m1/clean-tree (11 commits over v7.2-elden)
```
base `v7.2-elden`(44137cb4e) → tip `c73ff2522`。**工作树在项目仓库 `build/`（gitignored），提交在 `geekidos-linux` 内核仓库**，指向 branch `m1/clean-tree`。

## 2. 提交序列（`44137cb4e..m1/clean-tree`）

```
c73ff2522 arm64: dts: qcom: sm8750: Add non-secure-domain to ADSP fastrpc   ← 2026-10-11 新增（PITFALLS #186）
563bbd787 dts: 相机 rotation +180（前 270→90 / 后 90→270）
7057ca414 elden: cdsp — split 固件 (cdsp.mdt/cdsp_dtb.mdt) 取代单文件 .mbn
14c19a1ef elden: vk53 — NFC ST21NFCA + CDSP 启用
ae3e0de16 elden: vk47 — WCD939x 采集（去 VA DMIC，单 WCD capture link）
47d590b4f elden: vk46 — WCD939x 编解码
4983ea6df elden: vk45 — VA macro vdd-micb + DMIC sample rate
fc08094ea elden: vk44 — DMIC capture（VA macro + VA Capture dai-link）
b46bea4aa elden: vk42 — 音频（MI2S start-at-prepare）+ 温控 trip
00f08bac6 m1: A3+B2 aw86927 SRAM/continuous（patches/0003）
0c02ca0b3 m1: A1 dpss GC gamma block（patches/0002）
```

## 3. cherry-pick 冲突与解决（本轮的「实做」部分）

| 提交 | 冲突文件 | 解决 |
|---|---|---|
| `eb432f18a` vk42 | `q6apm.c` | HEAD（base/GEKiDoS）已是**更新**的 `audioreach_alloc_apm_pkt(...)` 语义（含 GET_SPF_STATE 无 header 的注释），vk42 带的是旧 `..._cmd_pkt` ⇒ **取 HEAD**（旧改动冗余）。DTS 自动合并（768 插入，来自 vk42 全量 elden DTS）。 |
| `8481c5a61` DTS | `sm8750-lenovo-elden.dts` | 两处均为**注释差异**（`mdss_dp0 status=okay`、`usb-role-switch` 实际属性已由前面 cherry-pick 带入）⇒ 取 HEAD。 |
| `6c1376907` DP | 同上 | 同上（`dr_mode=otg`/`usb-role-switch`/`dp0 okay` 已在 HEAD，仅缺中文注释）⇒ 取 HEAD（**M1 树刻意不留中文注释**，M2–M4 逐补丁适配时重写）。 |

⇒ 最终树是 **D-class 剔除后的功能终态**；与 base 的差异集中在 `sm8750-lenovo-elden.dts`、`q6apm-lpass-dais.c`、`aw86927.c`、`dpu_hw_catalog.c`、`psci.c`（已在 base）、`sm8750.dtsi`（ADSP non-secure）。

## 4. 构建命令（可复现）

```bash
cd build/m1-upstream/clean-tree
cp ~/y700-elden/linux/.config .config          # vk64 好 config a383cdb9（含 c1 片段）
. ~/y700-elden/scripts/env-build.sh
make ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" olddefconfig
grep -q '^CONFIG_ARCH_QCOM=y' .config || echo 'CONFIG_ARCH_QCOM=y' >> .config
make -j"$(nproc)" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" LOCALVERSION=-m1 Image.gz dtbs
# 结果：rc=0；UTS=7.2.0-debug-m1-gc73ff25222c7（log logs/m1-build.log）
```
（`olddefconfig` 未再删 `ARCH_QCOM`；`IP_ADVANCED_ROUTER=y` 也在——见 §5。）

## 5. 与 vk64/c1 的关系

- M1 树同时收进了 2026-10-11 的 **ADSP fastrpc `qcom,non-secure-domain`**（传感器根修，PITFALLS #186）——它是「上游风格、应随 M3 提」的一条，故 M1 树必须含。
- `IP_ADVANCED_ROUTER` 属 config 层（C1），不在树里；M1 构建时随 config 带入。

## 6. 后续（M2–M5）

- **未做**：`fastboot boot` 上机对照（需模块 vermagic 对齐的 ramdisk；非 M1 判据）。
- **M2 首发小系列**：`A1 dpss GC`、`A2 battmgr`、`A3 aw86927`（树内已具备；staging 时 CHANGELOG/checkpatch）。
- **M3 板支持系列**：DTS + `qcom.yaml`；**先清 `usb@a600000` schema 红点**；把 M1 树里带中文注释/`elden` 内部命名的 hunk 规范化。
- **M4**：B8 camss / B6 ath12k PEACH / B3 hci_qca PERI 立项。
- **M5**：C2 dm-default-key 剥离。
