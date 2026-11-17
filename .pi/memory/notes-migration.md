# y700-elden — 迁移/换机/重建（2026-11-17 从 MEMORY.md 按域拆出，原样搬运）

2026-10-17 换机恢复期的缺口登记、抢救通道与重建配方。

---
y700-elden 迁移缺口登记与标记约定（2026-10-17 立）：所有"未随迁"资料一律用可 grep 标记 `⚠️MIGRATION-LOST` 内联标注；机器可查登记 = `versions/migration-gaps-2026-10-17.tsv`（status: LOST / LOST-REDOWNLOADABLE / EXPECTED-ABSENT / RESTORED），说明正文 = `RESOURCES/README.md` §3.5，入口指针 = `INDEX.md` §3。云盘包 `cloud-backup-y700-elden-20261016.tar.zst`(5.1G) 已按包内 MANIFEST 全量校验（3608/3609 OK、0 缺失；唯一差异 = mnt/Samsung/l2/dump-super.sh 本地新机路径版）后**删除**，清单留档 `versions/cloud-backup-20261016.MANIFEST.sha256`；补回 `.pi/sessions/`(311 文件/391M)、`~/mnt/Samsung/mesa-out/`、`backup/fw/.../wlan/*`；`~/下载/migration-2026-10.tar.xz`(490M dotfiles/secrets) 未动。⚠ 一条纪律：设备独有资产（sn.img / GPT / unique/*.bin / 两个 boot_b）现只剩本地一份。
---
y700-elden 迁移重建审计结论（2026-10-17 实测）：可重建度=文档/补丁/配置近乎无损，损失集中在提交史+镜像产物。① 内核身份表 117 行中源提交仍在本地 58 行、缺失 56 行（M1-7.3 线 27 行同源 ed6f232d10e3 + 上游显示实验线 9 行 + 13 个 vk 号 vk54/58/79/80/84/86/90/91/92/95/96/98/101 + 杂项）；② out/*.img = 0 个（只剩 153 个 .manifest，身份可查但台架不可复跑）；③ 内核仓在（2.3G shallow，62 refs，最高 tag vk83，HEAD ba28ec16f），bundle 只到 q28/vk86（10-10，43 refs）；④ patches/ 七系列完整。重建路线见 reports/migration-rebuild-audit-20261017.md 与 session 2026-10-17-换机后重建审计-邮箱分诊.md。
---
y700-elden 换机后（2026-10-17）两条最紧约束：① check-doctor §5d「内核身份表已过期」FAIL 是迁移假信号，禁重跑 scripts/vk-identity.py（见本文件 vk-identity/out-archive 条与 AGENTS.md 项目记忆第 1 条）；② 设备独有资产（sn.img / GPT / unique/*.bin / 两个 boot_b）只剩本地 + 一份抢救副本（清单与 sha 见本文件「设备侧抢救通道与资产清单」条）。
---
y700-elden 换机后待办重置 T1–T7（2026-10-17，commit 8fad99a 已 push origin+github；T1 M3-1 v2 + T2 凭据正规化已完成，commit f7a8738）：M3-1 已有 3 条上游回信（Konrad 质疑 / Krzysztof binding 否决 / lkp 告警）⇒ 状态应为「需 v2」；Taniya 10-13 明确要 Q24 的 genpd/clk/dmesg 三件套（M7 待办原缺，现已登记）。台账更新落在 TASKS/README.md §4/§5/§7、DEVICE/README.md、INDEX.md。
---
y700-elden 迁移重建 payload 缺 3 个关键参照提交（本地仓库已不可达）：upstream-v7.2=`237a1c39e8df`(Linux 7.2)、payload 压缩提交=`2e28b969d1`（父=upstream-v7.2）、M1-7.3 基线=`ed6f232d10e3`；本地在的只有 `24a19b953e`(Linux 7.3-rc7 pristine)。geekidos-linux 现存 refs 最高 tag = vk70/79/81/82/83，HEAD=ba28ec16f。构建差分只能靠 7.2 tarball 重建基线、不能靠这些丢失提交。
---
y700-elden 迁移缺口修复 —— `scripts/mkbootimg.py`（v2 头，支持 pack/unpack/--selftest）已补回并纳入受管路径：原 `tools/mkbootimg/` 随换机丢失是因为 `/tools/` 在 .gitignore:15（`/out/*` 在 :26）。引用点已全部改指：`scripts/build-boot.sh:16 MKBOOTIMG=${MKBOOTIMG:-$ROOT/scripts/mkbootimg.py}`、`scripts/build-initramfs.sh:30 UNPACK=${UNPACK:-$ROOT/scripts/mkbootimg.py}`（原调 `tools/mkbootimg/unpack_bootimg.py`）。自校验 = 用真实镜像复刻逐字节比对，已对 `boot_b-m1-baseline-f3-20261017.img`(85581824 B) 与 `boot_b-before-vk94-20261011.img`(85319680 B) 双 PASS。ramdisk 可从基线 boot_b 原位抽出（kernel 偏移 4096，ramdisk 紧随 kernel，ramdisk_size=64622358）。