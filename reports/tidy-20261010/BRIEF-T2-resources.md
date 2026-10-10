# T2 任务简报 — RESOURCES.md 资产台账/会话索引同步 + 磁盘清理建议（提案模式）

你是 y700-elden 项目（cwd /home/xuqianhui1001/y700-elden）的资产/资源整理提案子代理。
**领域层文档（INDEX/TASKS/DEVICE/RESOURCES/PITFALLS）与 versions/ 是父代理（integrator）专属，你绝对不可修改。**
产出只写入两个新文件：`reports/tidy-20261010/resources-edits.md` 与 `reports/tidy-20261010/cleanup-candidates.md`。

## 任务
把 RESOURCES.md（§1 外部参考 / §2 本地资源与脚本清单 / §3 文件与资产台账 / §4 会话索引）同步到 2026-10-10 实况，并给出一份磁盘清理建议清单（**只建议、不删任何东西**）。

## 输入
- RESOURCES.md 全文（86KB，分段 read 直到读完）。
- `git log --oneline -25`；对比 `ls scripts/ patches/ reports/ versions/` 与文档登记面。
- 2026-10-09 起新增未登记：scripts/q28-{ab-delay,devprobe,verdict,boot-cycle,race-hunt}.sh、scripts/serial-logger.sh、patches/q28-*.patch 六个（含 q28-methodB-NOTES.md）、reports/q28-*.md 九个 + reports/local-cleanup-audit-20261010.md（**先读它**——可能已有部分审计结论，避免重复劳动并注明可吸收内容）、out/boot-elden-vk84-q28delay-{base,exp}.img+manifest。
- `ls -lt .pi/sessions/*.jsonl | head -8` 核对 §4 缺哪些会话：至少 10-09 深夜 01a12302（Q28 密集取证/vk74-76）、10-10 上午主会话 01a1241b（死内核事故+vk84+Q28 定案）、10-10 当前会话 01a12529（本轮整理）。一行主题从 git log 与 reports/ 文件头提炼。
- versions/vk-identity-inflight.txt：vk71-mxc/mxnom 已按用户裁决收口、vk74/vk84 仍在途——§3 若有相关口径需一致。

## 产出 1：resources-edits.md
每个修改一节：位置、理由，然后格式：

<<<OLD file=RESOURCES.md
（逐字节一致原文，≤1200 字符，写前 grep -F 验证全文件唯一）
===
（替换文本）
>>>

必须覆盖：
1. §2 脚本清单登记新 q28 脚本与 serial-logger.sh（读脚本头部注释确认一句话用途）。
2. §3 台账：新增顶层目录 **reports/** 定位=『活跃主题的工作区证据（活跃期可读可改；主题定案后整体迁 archive/topics/，归档层只增不改）』，并列入现有 q28 文件；patches/q28-* 系列（哪些已上机验证/哪些是草稿——从 patches/q28-methodB-NOTES.md 与 reports/q28-handoff-20261010.md 读）；**/build/（约 4GB、2026-10-10 起新内核构建目录、.gitignore 暂未忽略、父将补）**与 out/ 现状。
3. §4 会话索引补 10-09/10-10 会话行（格式照该节现有行；无产出/冒烟的标 junk）。
4. §1 外部参考中过时/疑似死链条目：只登记到产出 2 并标『待核』，不删。

## 产出 2：cleanup-candidates.md
`du -sh` 实测每个顶层大目录（build out logs rootfs backup env-pass pkgs pkgs-phosh pkgs-x86 probe tools edk2* mu_wide_platforms uefi-firmware-backup stock-src qdl restore-259 waydroid-ota 等），逐条给处置建议。每条：路径、大小、判定依据、建议（删/留/迁）。要点：
- build/ = 可再生构建目录；
- out/ 历史测试镜像（vk71-mxc/mxnom 已判死可删；vk74-q28power、vk84-q28delay-* 仍在途保留；out/boot-elden.img=无名构建待父处置）；
- logs/q28-* 取证目录保留；
- backup/、restore-259/、uefi-firmware-backup/ 备份类不动。
**绝不执行删除。**

## 禁令
不修改任何既有文件；不执行 git 写命令；不碰设备（adb/fastboot/ssh）；不跑构建/check-doctor；du 不进 l2（外接盘符号链接，跳过并注记）。

## 完成回报
产出文件、每节验证结果、发现的文档-实况不一致清单。
