# D5⑤：build-kernel.sh DSI 守卫 pristine 上游树假阳性 — 修复回执（2026-11-24）

## 结论：PASS（增量修正，非从零修复）

守卫三分支结构（B5 名 → 上游锚点 → 判死）与 `--selftest 4/4` 已在 commit `5f326d77`
落地；本轮做的是**树内核实 + 修正上游符号表中一个不存在的名字**，使上游分支真正对
7.4-rc3 pristine 树生效。

## 符号树内核实（未凭记忆，rg 于树内）

- pristine 上游 7.4-rc3（`build/elden-tree`，Makefile `VERSION=7 PATCHLEVEL=0 EXTRAVERSION=-rc3`）：
  - `drivers/gpu/drm/msm/dsi/dsi_host.c:2007  int msm_dsi_host_init(...)`
  - `drivers/gpu/drm/msm/dsi/dsi.c:171    static int dsi_dev_probe(...)`（static，System.map 中以小写 `t` 出现）
  - `drivers/gpu/drm/msm/dsi/dsi.c:235    int msm_dsi_modeset_init(...)`
  - `drivers/gpu/drm/msm/dsi/dsi.h:69     void msm_dsi_host_cmd_xfer_commit(...)`
  - **无** `msm_dsi_host_bonded_*`；`msm_dsi_host_xfer_commit`（旧表里的名字）也不存在，真实名是
    `msm_dsi_host_cmd_xfer_commit`（差一个 `cmd_`，锚定行尾 ERE 下旧名永不命中）。
- B5 侧（`build/g7b-vk185`，7.3 + patches）含 `msm_dsi_host_bonded_*`，原判据名正确。
- 7.3 pristine（`build/g7b-vk185` 未叠 B5 的同名锚点）同样有 `msm_dsi_host_init / dsi_dev_probe / msm_dsi_modeset_init`。

## 改动（仅 scripts/build-kernel.sh，3 处）

1. `SYM_DSI_UP` / `SYM_DSI_UP_NAMES`：`msm_dsi_host_xfer_commit` → `msm_dsi_host_cmd_xfer_commit`（B5 判据不动，不降级）。
2. 文件头注释补树内核实出处。
3. selftest `upstream.map` 同步改名为真实上游符号。

## 自检输出（`bash scripts/build-kernel.sh --selftest`，全部真跑）

```
[selftest] daily     guard rc=0 expect=0 PASS   # B5 名存在 ⇒ 过
[selftest] upstream  guard rc=0 expect=0 PASS   # 只有上游符号 ⇒ 过，且打印命中 msm_dsi_host_init
[selftest] dead      guard rc=1 expect=1 PASS   # qcom 符号缺失 ⇒ 死
[selftest] nodrm     guard rc=1 expect=1 PASS   # 平台在但 DRM_MSM 丢 ⇒ 死
== selftest 4/4 PASS ==
```

两分支均证明；错误信息打印两套判据全文，命中时打印实际命中的符号名。

## 边界说明

- 「树没有 dsi 目录 vs 有目录但符号缺失」区分：守卫输入是 System.map（编译产物），
  天然无「目录」概念；「有 gcc/rpmh 但无任何 DSI 锚点」分支（nodrm 场景）即等价于
  「目标树但 DSI 缺失」= 真失败，已覆盖。未动守卫自检脚本（selftest 内嵌，随主脚本改）。
- 未跑 make、未动内核源树与 out/。新文件仅本报告。

## Verify（可独立重跑）

```bash
bash -n scripts/build-kernel.sh
bash scripts/build-kernel.sh --selftest
grep -n 'SYM_DSI_UP=' scripts/build-kernel.sh
```
