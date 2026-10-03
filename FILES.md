# 文件台账 — y700-elden 仓库整理

> 建立：2026-10-03。目的：把「项目大脑（文本/脚本/补丁/记忆）」与「大二进制资产」分开，
> 让版本控制只装前者；同时集中登记**可清理项**，避免每轮会话重复盘点。
> 清理详细方案与前置闸见 `RESOURCES.md` §2.5（本文件只做分类与状态标记）。

---

## 1. 版本控制边界（`.gitignore` 权威）

- **纳管（track）**：文档、脚本、内核补丁与 config、AI 记忆/技能/任务、小体积证据。
- **排除（ignore）**：上游 clone、构建产物、可再生成物、大二进制 dump、运行时状态、设备敏感数据。
- git 仓库根 = 本目录；分支 `main`。上游内核树 `geekidos-linux/` **不是** submodule，其进度以 `patches/` 为准。
- ⚠️ gitignore 注释必须独占一行（行尾 `#` 会被当作模式一部分，静默失效）。

## 2. 顶层台账

| 路径 | 体积 | 版本控制 | 说明 / 处置 |
|---|---|---|---|
| 领域层 `INDEX/DEVICE/TASKS/RESOURCES/GAPS/ANDROID-COMPAT/RUNBOOK.md` + `PITFALLS.md` + `AGENTS.md` | <200 K | ✅ track | 平面 1 领域层＝唯一维护面；分层与 SSOT 见 `INDEX.md` §2 |
| `.pi/{skills,memory,missions,agents}` `.pi/README.md` `.pi/settings.json` `.pi/pi-messenger.json` | ~1 M | ✅ track | AI 大脑：技能/持久记忆/任务卡/模型配置（分工见 `.pi/README.md`） |
| `.pi/sessions/`（51 个 jsonl） | 52 M | ignore | 会话轨迹；**整理候选**：旧会话归档（见 §3 H1） |
| `.pi/messenger/` | 748 K | ignore | 运行时状态 |
| `scripts/` | 448 K | ✅ track | 构建/刷机/GPT/温控/基准/容器脚本全集 |
| `patches/` | 3.7 M | ✅ track | 内核补丁 + config 快照 + **新：工作树全量 patch** |
| `archive/` | 752 K | ✅ track | 过程证据（49 篇专题 + 2 截图）+ `sessions-catalog-2026-10-03.jsonl`，不再更新 |
| `LESSONS.md` | 小 | ✅ track | 经验总入口（由 `db/build.py --lessons` 生成） |
| `SESSION-INDEX.md` | 21 K | ✅ track | 45 会话索引 + 内核实机验证边界 |
| `db/` | ~200 K | ✅ track | SQLite 知识库：schema.sql + build.py + README.md + elden.db（由文本源重建） |
| `initramfs/` | 2.0 M | ✅ track | init/脚本 + busybox（重建输入） |
| `rootfs/`（脚本/conf/init） | 小 | ✅ track | `alpine/ dl/ debs/`（176 M+）已 ignore |
| `env-pass/{scripts,tools}/` | 12 K | ✅ track | 过环境脚本 + 模块重打包工具 |
| `bootslot-b/README.md` `backup/fw/README.md` `restore-259/*.md` | ~15 K | ✅ track | 关键说明文档（其余二进制 ignore） |
| `net/ build/ waydroid-ota/` | <220 K | ✅ track | 小体积资产 |
| `linux -> geekidos-linux` | 符号链接 | ✅ track | 目录约定 |
| `geekidos-linux/` | 13 G | ignore | 上游 `GEEKiDoS/linux` v7.2-elden + 构建产物 |
| `Y700-elden-linux/` | 15 M | ignore | 旧迭代上游 clone |
| `stock-src/` | 350 M | ignore | 联想 GPL 源码 clone（可重下） |
| `qdl/` | 3.2 M | ignore | 上游 qdl（`qdl/build/qdl` 为构建物） |
| `tools/` | 14 M | ignore | `venv-avb` + 上游 `mkbootimg`（可重建） |
| `out/` | 4.6 G | ignore | boot 产物 / cpio / modules |
| `bootslot-b/` `bootslot-b-u2/` | 905 M | ignore | 自签 b 槽包（含 `avb.key` 私钥，禁止入库） |
| `backup/` | 1.5 G | ignore | 原厂分区/固件/GPT dump（不可替代，留盘） |
| `env-pass/`（余） | 3.8 G | ignore | 过环境栈 + rootfs 归档 |
| `logs/` | 86 M | ignore | 串口/构建/agent 日志 |
| `pkgs/ pkgs-phosh/ pkgs-x86/` | 639 M | ignore | apk/deb 缓存（可重下） |
| `probe/` `twrp/` `y700四代工具/` | 552 M | ignore | 探针数据 / TWRP 镜像 / 厂商工具 |
| `flashing-bundle/` + `flashing-bundle-*.tar.gz` | 19 M | ignore | 换机迁移包快照 |
| `restore-259/`（二进制） | 254 M | ignore | AVB/KSU/EDL 救砖资产 |
| `y700-elden-docs-*.tar.gz`（5 个） | 240 K | ignore | 旧文档快照（冗余） |
| `sn.img` | 356 B | ignore | **含本机序列号，禁止入库** |
| `l2 -> /mnt/Samsung/l2` | 45 G（外置） | ignore | 外置盘 super/system 镜像 |

## 3. 可清理标记（不动手，等确认）

编号对应 `RESOURCES.md` §2.5 的 P 级；状态：⬜ 未执行 / ✅ 已执行。

| 标记 | 目标 | 体积 | 前置闸 | 状态 |
|---|---|---|---|---|
| P0-a | `/mnt/Samsung/fiotest/` | 4.1 G | 无 | ⬜ |
| P0-b | `geekidos-linux/` 构建产物（`make clean`） | 13 G→1.6 G | **已解除**：工作树 13 文件已导出 `patches/elden-working-tree-ba28ec16f-2026-10-03.patch`（反向 apply 校验通过）+ config 已存 `patches/config-vk40-bringup` + HEAD=`ba28ec16f` | ⬜ |
| P1-a | `out/` `bootslot-b/` 旧 boot 镜像（留 vk40±ram、vk39） | 5.3 G→0.6 G | vk40 上机验收通过后才删 vk39 | ⬜ |
| P1-b | `pkgs/ pkgs-phosh/ pkgs-x86/` | 638 M | 无（`rootfs/debs-manifest.txt` 已记版本） | ⬜ |
| P2-a | `env-pass/{build,kernel-susfs}` 中间物 | 494 M | 保留 `env-pass/backup-20261002/linux17-rootfs.tar.gz` | ⬜ |
| P2-b | `backup/rawdump.img` 压缩 | 257 M→~30 M | 无 | ⬜ |
| P2-c | 重复快照（`flashing-bundle/`+tar、`y700-elden-docs-*.tar.gz`） | ~30 M | 保留最新一套 | ⬜ |
| P2-d | `backup/stock-259/` 13 分区 | 443 M | 须先核对云全量包含 abl/dtbo/recovery/vbmeta 且 =1.5.10.259 | ⬜ |
| P3-a | AOSP `.repo` 历史 + 工作树（外置） | 523 G | 决策 G2 是否自编 Waydroid；先导出 local_manifests | ⬜ |
| P3-b | `l2/` super/system 镜像 | 45 G | 先做 GAPS Q13 AVF 重提取 + 核验云包 | ⬜ |
| H1 | `.pi/sessions/` 旧会话 | 45 M | 归档非活跃会话（保留最近若干） | ⬜ **索引已完成（`SESSION-INDEX.md`）；删除待任务 #2 完成 + 用户确认** |

**纪律**：按 P0→P3 逐级、不并行；每级前后记 `df -h`；删前先导出独有内容；删后回改
`RESOURCES.md §2.5` 与本节状态、并记 `archive/topics/清理清单-<date>.md`。

## 4. 日常 git 工作流

```bash
cd ~/y700-elden
git status                      # 看改动（大文件已被 ignore，不会刷屏）
git add -A && git commit -m "..."   # 文档/脚本/补丁/记忆 改动
git log --oneline -10
```

- **内核改动**：在 `geekidos-linux/` 改完，务必回导补丁，否则进度只留在 dirty tree：
  `git -C geekidos-linux diff > patches/elden-working-tree-$(git -C geekidos-linux rev-parse --short HEAD)-$(date +%F).patch`
  并同步 `.config` → `patches/config-vkNN-*`。**这是本仓库版本控制覆盖不到的唯一边界。**
- **内核 per-version 提交（修 F1/F4，2026-10-03 起）**：内核仓库自身 git 已建分支
  `elden/vk40-2026-10-03`（现状）与 `elden/vk34-recon`（回退 post-vk34 增量）。
  `.config` 已开 `CONFIG_LOCALVERSION_AUTO=y` → **每版干净提交后 uname 自动带唯一 commit**
  （如 `7.2.0-debug-g6ef87e6a8868`），设备上可直接分辨在跑哪版。改内核后：
  `git -C geekidos-linux add -A && git commit -m "elden: vkN ..."`，从干净树构建。
- **不要** `git add -f` 大文件；确需留档走磁盘备份 / 云盘，不入 git。
