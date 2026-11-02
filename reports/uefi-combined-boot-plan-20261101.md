# UEFI 合体 BOOT 路径可行性（SunUEFI 机制 → 本机 y700g4 落地评估）

> 2026-11-01。派工 B lane。只读静态分析 + 外部取证，零设备写入。
> 证据分级：`已证`（今日命令输出/file:line）/ `外部`（上游原文引用）/ `未证`（推断）。

---

## §0 结论（⚠ 本 lane 于 2026-11-01 23:2x 中止，未完成 —— 骨架保留供续作）

- **状态**：派工 B 的第 9 轮后 `status=stopped / error="Agent stopped"`（12 次工具调用、0 字正文），
  卡在 `/tmp/SunUEFI`（已 clone 成功）的 `git restore` 之后；**未产出任何结论**，本文件 §1–§6 仍为骨架。
- **留下的可复用资产**：SunUEFI 仓库副本已从 `/tmp`（tmpfs，易失）搬到 **`~/ext-repos/sunuefi`**（20 MB，含 `build.sh`/`android/`/`AGENTS.md`）。
- **续作入口（下轮按此三点做，别重头摸）**：
  1. `~/ext-repos/sunuefi/build.sh` + `android/` —— 合体 BOOT 的打包脚本与 kernel 段内容，`file:line` 级取证；
  2. 本机 ABL 加载语义：`reports/artifacts/uefi-edl-read-20261101/abl_{a,b}.bin` 静态（`kernel_addr`/上限/是否校验 Image magic）；
  3. `build/uefi-woa-prep/repos/7-mu-lenovo` 里 `xiaomi-piano` vs `lenovo-y700g4` 按文件 delta（DSC/FDF/APRIORI/UFSDxe/显示）。
- 中止原因分类：**非设备/非限流**，属 lane 自身在某步卡住后被 runner 收掉（该轮 device 同时被编排者占用，无关）。

---

## §1 SunUEFI 打包机制（外部取证，file:line）

（待填）

## §2 本机 ABL 加载语义（abl_a/abl_b 静态取证）

（待填）

## §3 piano vs y700g4 设备包 delta（Mu 树静态对比）

（待填）

## §4 最小 boot.img 布局与上机判据

（待填）

## §5 工作量与风险

（待填）

## §6 未证事项

（待填）
