# User Memory — elden（y700-elden）

## 刷机操作偏好
- fastboot/EDL 类断联场景：用户偏好**亲自执行命令**、助手只做分析（避开工具断联）。
- 复杂刷写/GUI 工具（如 LTBox）：用户亲自操作，助手准备资产并给精确步骤。
- 动手前先确认不破坏当前可用系统。
- 长任务反复失败无进展时：先写复盘记录（操作史/根因/文件清单）再切换方案。
- 先查社区现成资源与本地已有等效资产，避免重复下载大文件。

## 通用工作风格
- 减少反复的同质化思考，每种方案/推理/建议只需一次正反判断。
- 环境/网络/镜像类疑难问题倾向派子代理专项调查。
- 中文交流。


## Memory - 2026-09-30

本机有 Motrix-next 下载加速器：RPC 端口 29100，密钥 "motrix"（aria2 JSON-RPC，http://127.0.0.1:29100/jsonrpc，params 首项 "token:motrix"）。大文件下载优先用它，默认目录 ~/下载/。


## Memory - 2026-10-03

y700-elden 文档架构偏好（2026-10-03 用户定）：入口越少越好。根目录只保留 6 份维护文档——唯一入口 INDEX.md + DEVICE/TASKS/RESOURCES/RUNBOOK-BRINGUP/PITFALLS；不引入第二索引、生成物或 SQLite（db/、LESSONS.md 已删除）。查询用 `rg`，会话回忆用 pi 原生会话选择器 + `rg .pi/sessions`，结构一致性用 `scripts/check-doctor.sh`。新证据只进 archive/（只增不改）。


## Memory - 2026-10-04

y700-elden 音频测试：扬声器硬件增益满值 1023 在无软件衰减(裸 ALSA)时非常吵，用户明确要求"控制音量"。任何放音测试/默认增益用保守值（脚本默认 400，可用 ALSA_PLAYBACK_VOLUME 覆盖）；测试前先调低再播。


## Memory - 2026-10-04

y700-elden：fastboot 控制不要用封装脚本（to-fastboot.sh/cycle.sh 等）——fastboot 支持命令有限、深层嵌套行为难预测、增加故障率。助手应给出可直接手敲的单条 fastboot 命令，由用户/助手直接执行；脚本只用于主机侧构建/打包。
