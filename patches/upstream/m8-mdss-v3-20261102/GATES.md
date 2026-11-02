# M8 mdss v3 门禁（2026-11-02，编排者本轮实跑；不采信历史自报）

树：`build/m8-dispcc-v2` 分支 `m8/v3-20261102`（基点 pristine `24a19b953e` = v7.3-rc7），
三提交 `166ae8f55a` / `54ae578650` / `d35e3a06f9`。

## 1. 从前一版到本版的内容差

```
git diff q28-dispcc-v2-20261029 的工作树（v2 三枚） 	→ v3
0001 mdss-common.yaml      : -1 条 items description（MDSS RSC）
     qcom,sm8750-mdss.yaml : example 由 3 复位降为 2
0002 msm_mdss.c            : 删 11 行长注释（代码零变化）
0003 sm8750.dtsi           : resets 由 3 项降为 2 项
```

## 2. checkpatch（`--strict --no-tree`，目标树自带脚本）

```
0001: total: 0 errors, 0 warnings, 0 checks, 20 lines checked
0002: total: 0 errors, 0 warnings, 0 checks, 17 lines checked
0003: total: 0 errors, 0 warnings, 0 checks, 9 lines checked
```
⇒ 3/3 **0E/0W/0C**。

## 3. pristine 重放

```
git worktree add --detach /tmp/amtest-m8v3 24a19b953e
git am 0001 0002 0003            → 3/3 "应用"（无 fuzz）
git diff --stat m8/v3-20261102    → 空（终态逐字节一致）
```

## 4. binding（致命版三件套；`make dt_binding_check` 的 rc 不作证据）

```
dt-doc-validate -u Documentation/devicetree/bindings \
    .../mdss-common.yaml .../qcom,sm8750-mdss.yaml                       rc=0
~/.local/opt/dtschema-venv/bin/python scripts/dtc/dt-check-style <两文件>  rc=0
make ARCH=arm64 dt_binding_check DT_SCHEMA_FILES=display/msm/qcom,sm8750-mdss.yaml
    → 生成 qcom,sm8750-mdss.example.dtb（该 target 内部三步都带 `|| true`）
dt-validate -l qcom,sm8750-mdss.yaml -u Documentation/devicetree/bindings \
    -s Documentation/devicetree/bindings/processed-schema.json \
    .../qcom,sm8750-mdss.example.dtb                                     rc=0   （example = 2 复位）
# 向后兼容：临时把 example 改成单复位（<&disp_cc_mdss_core_bcr>）后重建 example.dtb
dt-validate ...（同上）                                                  rc=0   （example = 1 复位）
```
⇒ 两态 rc=0；「单复位老 DT 仍合法」现在有实测，不只是论证。验后 example 已还原。

## 5. 编译（W=1，`.config` = `build/m4-base/.config` 沿用本树既有配置）

```
export LOCALVERSION=
rm -f drivers/gpu/drm/msm/msm_mdss.o drivers/gpu/drm/msm/.msm_mdss.o.cmd drivers/gpu/drm/msm/msm.o
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 drivers/gpu/drm/msm/ -j26
→ rc=0；日志含 `CC [M] drivers/gpu/drm/msm/msm_mdss.o`、`LD [M] drivers/gpu/drm/msm/msm.o`
→ warning/error 计数 0（/tmp/m8v3-build2.log）
```

## 6. 未做（如实声明）

- **未上机**：v3 形状（数组 API + 两项复位）无真机样本；cover 已明写。
- 未跑 `dtbs_check`（sm8750 板级不在本系列）、未跑全量 arm64 编译。
- 未改 `dispcc-sm8750.c`（延续 v2 的「clk driver 零改动」）。
