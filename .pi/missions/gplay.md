# 任务：Waydroid 内 Google Play 登录 + 认证等级取证（C2/C3）——阻塞在用户侧上行

> 状态与进度的**唯一权威 = `../../TASKS/README.md` §2 行 C2/C3**；本任务书只是派工背景。2026-10-04 现代化。

你是 y700-elden 的容器集成工程师。工作目录 `~/y700-elden`。

## 现状（勿重做）
- 容器图景：Waydroid Session/Container 可 RUNNING（Mesa 26.1.8 解 A830 + GAPPS 镜像在手 + **代理通路已闭环**）。历史与根因：`archive/topics/WAYDROID-2026-10-01.md`、`WAYDROID-AOSP-AUDIT-2026-10-01.md`、`GPLAY-2026-10-02.md`、`PROXY-WAYDROID-2026-10-02.md`。
- **C2 硬前提在用户手里**：可用上行（代理）+ Google 凭据。二者缺任何一样 → 只做主机侧准备工作，**不要自行尝试登录或找免费代理**。

## 前置与目标（按序）
1. **C1 复跑**：vk47 持久根上 Waydroid 端到端（去掉旧 bind-mount workaround），`waydroid status` 有 IP、SurfaceFlinger running、桌面可点。
2. **C3 身份取证**（可与 C1 并行，主机侧部分现在就能做）：社区先例（redroid / waydroid_script `certified` / WayDroid-ATV / PlayIntegrityFork）× 本机可测项 → 出「能做到哪一级」对照表；**不预设不可能，也不承诺能做**。
3. **C2 登录收口**（仅当用户给出上行+凭据）：Play 登录 + 装 3 个目标 App 验证。

## 纪律（2026-10-04 约定）
- 改 Waydroid 镜像/配置前先备份（`backup/` 或 `.bak-<date>`）；涉及设备侧读配置走 `scripts/device-lock.sh`。
- 一条命令只做一件事；SSH 禁长 sleep（后台 `nohup ... &` + 短命令轮询）。
- 凭据/账号/上行 = 用户决策项，只上报不自行解决。
- 最终回复即交付物（命令+原始日志）；**不改 `../../TASKS/README.md`**；证据追加 `archive/topics/gplay-<YYYY-MM-DD>-subagent.md`。
