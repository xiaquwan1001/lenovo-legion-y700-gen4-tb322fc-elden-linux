# Swarm 并发方案与任务队列 — 2026-10-02

> 本轮引入 `pi-messenger-swarm` 真子代理编排。本文是本轮的**并发预算 + 任务队列 + 纪律**。
> 入口见 `INDEX.md`。

## 0. 并发预算

- 主机：16 核 / 61 GB，负载 <2；子代理主要是 LLM+文件/网络，不是 CPU 密集，故**并发上限由 token/冲突/设备共享决定**。
- **子代理并发上限 = 3**（`.pi/pi-messenger.json` 的 `maxConcurrentSpawns`；改后须重启 harness）。
  - **限流约束**：ustc_ai 每 api_key **20 请求/滚动窗口**（实测 429）。并发越高越容易打爆；已调 `retry.maxRetries=8 / baseDelayMs=3000 / maxAgentDelayMs=60000` 令 pi 能等过窗口。新派 worker 才带新配置。
- **设备锁（硬约束）**：只有一台平板（`ssh root@192.168.7.1`）。
  - **会重启/刷写设备**的任务（刷 boot、性能测试、Waydroid 镜像替换）**同一时刻只允许一个**。
  - 只读探测/源码分析可并行。
  - 取消设备锁：任务内 `send SageYak` 报备，等确认。

## 1. 本轮任务全景

| ID | 任务 | 类型 | 设备 | 状态 |
|----|------|------|------|------|
| task-2 | Win x86 转译可行性（Steam） | 调研/主机 | 否 | 🔄 TrueIce |
| task-3 | EL2 硬件虚拟化逆向（可选） | 调研/主机 | 只读 | ✅ DarkGrove |
| task-4 | 原厂相机 + 重力计驱动拆解 | 分析/主机+只读 | 只读 | 🔄 HappyNova |
| task-5 | Waydroid Google Play 认证 + 登录 | 集成 | 会改容器 | 🔄 JadeOwl |
| task-6 | 音频出声：tplg 设备子图 | 内核 | 会刷 boot | 🔄 EpicDragon |
| task-7 | CPU/GPU 性能基准（GL/Vulkan） | 压测 | 会占设备 | ⏳ 待派（等设备槽） |
| task-8 | 音频续：APM_CMD_GRAPH_OPEN | 内核 | 会刷 boot | 🔄 AudioPilot3 |
| task-9 | 相机主线移植（评估→最小可跑） | 内核/DT | 会刷 boot | ⏳ 待派 |
| task-10 | Win x86 PoC（Box64+Wine） | 主机+设备 | 占设备 CPU | ⏳ 待派 |
| task-11 | Waydroid 容器网络（代理共享） | 容器 | 容器配置 | 🔄 NetPilot2 |
| task-13 | SM8750 温控（trip/GPU/monitor） | 内核/DT | 压测+刷 boot | 🔄 ThermalPilot2 |

> **设备热约束（2026-10-02 用户要求）**：单平板同时只允许一个刷 boot / 压测任务；压测与刷写前先 `send SageYak` 报备。设备曾冲到 103°C，已临时限频降温（`policy0`/`policy6`），并立项 task-13 做正式温控。

> 已完成的历史：task-1 是冒烟探针（可忽略）。

## 2. 派发策略（为什么这样并行）

- **第 1 波（4 个）**：3 个主机型（EL2 / Win-x86 / 相机重力计）+ 1 个容器型（Google Play）。
  互相不碰 boot 分区，能立即满并发。
- **音频**在 task-3 完成后补入（它要刷 boot，须独占设备；安排时 Google Play 只做下载/准备阶段，尚未切镜像）。
- **性能基准**等设备真正空出（音频或 Google Play 任一段收尾）再派，避免刷机重启打断压测。
- 主会话负责：协调、复核子代理产出（自报成功不可信）、维护设备锁、回收 task-3 结论、写文档。

## 3. Swarm 运维纪律（本机）

- 调用统一走 `scripts/swarm.sh`（已固定 y700 专属端口 9878 + 独立数据目录，且**每次钉回会话桶 `.pi/messenger/session-id`**；`PI_AGENT_NAME` 用 `${..:-SageYak}` 不硬编码，避免 worker 经该脚本冒充协调者）。
- **已打 LOCAL PATCH**（`scripts/apply-swarm-patch.sh`）：worker `spawn` 改为 **detached + stdout 落文件**，可扛住 harness 重启（旧行为：harness 被跨项目 SIGTERM 后管道断裂 → worker SIGPIPE 秒退）。
- **重启 harness 只用 `kill -TERM <pid>`（preserve 语义）或 `--restart`**；**不要用 `--stop`**（走 `/quit` 不带 preserve，会主动杀掉所有 worker）。改配置后需**换进程**重启才生效（软重启不重载模块）。
- 根因与验证见 `复盘-2026-10-02-swarm.md`。
- 任务板按 (cwd, sessionId) 存储；`scripts/swarm.sh` 已固定协调会话，避免"task not found"。
- 子代理结论必须写进 `task progress` / `task done`（协调者只看任务板，不看其回复文本）。
- 复核闸门：子代理 `task done` ≠ 完成；协调者须用文档/命令证据独立复核（尤其涉及"已修好/已出声"的声明）。

## 4. 设备操作要点（子代理共享）

- 设备 IP 固定 `192.168.7.1`（USB gadget 网）；带外串口 `/dev/ttyACM0`（内核日志）、`/dev/ttyACM1`（root shell），工具 `scripts/serial-run.sh`。
- 内核迭代不刷 fastboot：`scripts/flash-b.sh <img> --reboot`（写 boot_b 并重启）。
- SSH 禁用长 `sleep`：后台 `nohup ... &`，再短命令轮询。
