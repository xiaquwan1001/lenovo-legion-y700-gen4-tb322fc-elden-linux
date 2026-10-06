# 退役任务线与 lane 规划归档（2026-10-06）

> 证据层 · 只增不改。承接 2026-10-06「目标重心上移 + 裁切项目级规则」：
> 把**已丢失上下文**的活跃文档段落移出只读档，正文只留指针，避免误导新会话。
> 权威现状仍在 `TASKS.md` §0/§1 与 `INDEX.md` §1。

---

## 1. 已作废/合并的旧任务线（原文 = `TASKS.md` §3，2026-10-06 前）

| 旧 ID | 现状 |
|---|---|
| swarm `task-1…13`（2026-10-02 那轮 13 项） | **12/13 完成**，仅 task-7 基准未派 → 并入 **G1-8**；日志 `logs/agent-logs-2026-10-02/`、复盘 `archive/topics/复盘-2026-10-02-swarm.md` |
| `task-14…17`（D 轨 AVF） | 改 **C8**（且因"无 Android"新前提降级为低优先调研） |
| `PLAN-NODEV` A 轨/B 轨 | A 轨并入 §2.1；B 轨并入 `RUNBOOK-BRINGUP.md` + G1-1…3 |
| 「两轨分机」路线决定 | 作废（设备等价）；技术结论并入 `DEVICE.md` §1.2/`TASKS.md` §6 |
| 「新机 = mainline、旧机 = D 轨宿主」角色表 | 作废 → 按状态分派（`DEVICE.md` §2.3） |

> 背景：以上均属 2026-09-30…10-02 的设备角色/规划框架，`设备等价` 原则（`INDEX.md` §1.2）确立后全部作废。
> 旧任务书原文另见 `archive/2026-10-02-merged/`。

---

## 2. 过时 lane 规划（原文 = `.pi/CONCURRENCY.md` §5，2026-10-05）

| lane | 任务 | 路径归属（只写这些） | 设备 | 执行者 |
|---|---|---|---|---|
| `c3-id` | C3 身份/DRM 取证 + 社区对照 | `archive/topics/c3-*.md`、`.pi/drafts/` | 无 | gplay |
| `c7-slot` | C7 slot 切换脚本 + A16 `new-tablet` 参数化 | `scripts/`（新文件为主） | 无 | general |
| `upstream` | M1–M5 上游化补丁整理 | `patches/` | 无 | general |
| `dt-ui` | **G1-26/27/28** 深色模式 · 主题配色 · 亮度滑块 · 电源菜单图标 | `rootfs/`、`scripts/dt-*.sh`、lane 内 `archive/topics/` | **U2** | dt-ui |
| `bootchain` | **G1-29** 间接引导层（GRUB 类/UEFI）摆脱 boot.img 96 MiB | lane 内 `archive/topics/`、`.pi/drafts/`、`scripts/grubfat-*.sh` | 只读 | bootchain |
| （设备 lane） | G1-22 二分 / BT H1·H2 / G1-8 基准 / C1 Waydroid | 内核 worktree + `scripts/` | **U2 串行** | 父协调 |

> 背景：该表是 2026-10-05 一次性排产，`dt-ui`（用户态三问，根因已定）与 `bootchain`（UEFI，已搁置）两 lane 均结束；
> `c7-slot`/`upstream` 未实际开跑。**lane 是"需要并发时才用"的工具，不是常设分工**——具体派发时现列，
> 方法（基线+fork/trailer/vk 分配）见 `.pi/CONCURRENCY.md` §1–§4/§6。
