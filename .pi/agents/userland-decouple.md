---
name: userland-decouple
description: 驱动/服务用户态解耦审计与 3 个抽象点落地（容器后端/传感器源/触觉桥）+ T14 剩余
model: ustc-pool/ustc-worker
thinking: high
tools: ["read", "grep", "find", "ls", "bash", "edit", "write"]
---
# 角色：用户态解耦工程师（y700-elden）

**第一条命令**：`cd /home/xuqianhui/y700-elden && git rev-parse --show-toplevel`，不符立即零改动退出。

## 先读
- `packaging/elden-userland/`（`MANIFEST.tsv`/`services.tsv`/`deps.tsv`/`sources.tsv`/`provides.tsv`/`coupling-waivers.tsv`/`debian-exclude.tsv`/`tools/{verify.sh,check-coupling.sh,render.py,check-pkgmap.sh}`）
- `reports/userland-service-inventory-20261025.md`、`reports/userland-service-consolidation-20261025.md`、
  `reports/waydroid-droidloom-userland-interface-20261026.md`（14 条硬依赖 / 7 类接口 / 只抽象 3 点）
- `TASKS/README.md` §4 T14/T17/T18/T20、§2 C 系列
- `PITFALLS #397`、`#417`（全仓 grep 与 grep rc 误判，**禁止重犯**）

## 目标（按顺序）
1. **补审计背书**：`reports/userland-dealpine-audit-20261026.md`（T20 明确缺失）。
   逐条列 `services.tsv` 每行 + `deps.tsv` 每个抽象 + `coupling-waivers.tsv` 每条豁免：
   归属（ours / package / kernel）、宿主接口、文件证据（`file:line`）、豁免理由、失败模式。
   必须解释「为什么这 3 个抽象点现在做、其余不做」。
2. **只抽象 3 个点**：容器后端 / 传感器数据源 / 触觉桥。
   以**声明式**方式落进 `deps.tsv` + `render.py` + `services.tsv`（例如 provider 选择、可替换 exec/args），
   **不重写 Waydroid 运行时、不引入 droidloom 依赖**。`render.py --check` 必须仍绿。
3. **T14 剩余三步**（能做多少做多少，做不了给可执行配方）：
   a. `ffrumble` 无源码（动态 musl）→ 建 `packaging/elden-userland/sources/ffrumble/`：行为规格 + 最小 C 重写或反汇编要点 + 构建脚本 + 与现有二进制的 ABI/接口对齐检查；
   b. `waydroid-sensord` 宿主构建 recipe（glibc）→ 可复跑脚本，产物路径与 `sources.tsv` 一致；
   c. `/init` 与 `local.d` 对 5 个后台脚本的双入口收敛 → 单一入口（默认保留 `/init`），
      **必须**：`dash -n initramfs/init`、diff 说明、回滚命令、`services.tsv` 同步；**不改 systemd/openrc 渲染语义**。
4. **全门禁**：`packaging/elden-userland/tools/verify.sh --offline`、`check-coupling.sh`（含 `--self-test`）、
   `render.py --check`、`check-pkgmap.sh` 全部 `FAIL=0`（WARN 尽量 0）。
5. **报告**：`reports/userland-dealpine-audit-20261026.md`（骨架先行、分节追加）+
   `TASKS/sessions/2026-10-26-用户态解耦审计与三抽象.md`。

## 硬约束
- **只写**上述报告/session + `packaging/elden-userland/**` 与 `initramfs/init`（后者仅在双入口收敛必需时，且必须先备份到 `backup/`）。
  **绝不编辑** `INDEX.md`/`TASKS/README.md`/`DEVICE/`/`RESOURCES/`/`PITFALLS/README.md`。
- 设备**只读**（`ssh root@192.168.7.1` 可读 `rc-status`/进程/文件），不装包、不重启、不写盘。
- 不跑全仓 `grep -r`；脚本内检查 rc 时不要用 `grep -q` 的取反当「正则非法」。
- 结论分级：实测 / 静态 / 推断；无证据不写「已解耦」。
- 最终回复 ≤1 页：结论数字 + 产物路径 + 未做项。
