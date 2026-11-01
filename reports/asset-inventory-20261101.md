# 资产盘点报告 2026-11-01（只读盘点）

> 方法：纯只读（du/find/stat/sha256sum/rg），未删除、未移动任何文件。
> 明细见同目录 `asset-inventory-20261101.tsv`（214 行）。临时脚本在 /tmp，未入库。

## 0. 总占用（结论先行）

- **项目总占用 ≈ 210 GiB**，其中：
  - `build/` **183 GiB**（内核构建树，本报告只记录未深查）；
  - `out/` **6.7 GiB**（构建产物，含 69 个 boot img）；
  - `env-pass/` **3.3 GiB**、`geekidos-linux/` 2.9 GiB、`dl-cam/` 2.7 GiB、`stock-src/` 2.0 GiB、`backup/` 3.2 GiB、`bootslot-b/` 1.3 GiB（15 个 boot img）；
  - `reports/artifacts/` 329 MiB（**80 个目录 + 38 个散件**，共 118 条目）；
  - 其余（archive/probes/patches/reference/rootfs/waydroid-ota/logs 等）合计 < 25 MiB。
- **同 sha256 重复件（<200 MiB 全量比对）潜在可省 ≈ 895 MiB**，最大单组 123 MiB（ramdisk）。
- **明确孤儿**：`reports/artifacts/` 34/80 目录无任何 reports/*.md 引用（多为 q28-clkdiag/q32-boot 裸 txt 探针数据 + 已有正式报告的 raw 件）。

## 1. 可安全清理 Top10（建议，仅列出，未动）

| # | 对象 | 大小 | 理由 |
|---|---|---|---|
| 1 | `out/boot-elden.img` | 84 MiB | 与 `out/boot-elden-m3v5-onboard-b.img` 逐字节相同（sha a144e5ce1b37），且是 flash-b.sh 脚本惯用参数名，删副本留正名更稳（二选一） |
| 2 | `out/boot-elden-vk141-q28disp73.img` 或 vk142 | 81 MiB | 两者 sha 相同（10a38c4e7bab），留其一 |
| 3 | `out/m3v5-onboard/boot-elden-m3v5-onboard.img` 副本 | 80 MiB | 与 `out/boot-elden-m3v5-onboard.img` 同 sha，子目录内重复 |
| 4 | `out/vk133-ramdisk.cpio.gz` 重复两份 | 123 MiB×2 | 三份同 sha ramdisk，留一份 |
| 5 | `out/ramdisk-vk181-working.cpio.gz` 副本 | 61 MiB | 两份同 sha |
| 6 | `backup/stock-259/recovery_b.img` 重复份 | 100 MiB | 与另一份同 sha，留一份 |
| 7 | `reports/artifacts/uefi-boot-20261101-*`（约 19 个目录） | ~数 MiB | 全部 gate.txt/post-mode.txt 同 sha 的空转记录，正式证据已在对应报告 |
| 8 | `reports/artifacts/` 34 个无引用目录（q28-clkdiag*/q32-boot* txt 群） | ~几 MiB | 无 reports/*.md 引用；删前抽查一次即可 |
| 9 | `out/stage-debian/` | ~数十 MiB 重复 | 与 `out/debian/firmware-root/`、`out/modstage-vk163/` 大量同 sha（固件/模块 staging 副本），如 stage 已合并可去重 |
| 10 | `patches/kernel-history/` 7 个变体目录中重复的同一系列 | ~小 | 0001~0008 系列在 elden_sd-*/elden_vk42-*/elden_wifitim 七处完全同 sha |

潜在合计（含跨出上述表外小件）：**≈ 895 MiB**（不含 >200 MiB 大文件，它们只做了大小+mtime 对比）。

## 2. 建议保留 Top10

1. `bootslot-b/boot_b-device-backup-20261101.img`（aedae5f1…）= **当前在机 vk183-fastrpc 的分区备份**，DEVICE/README §1.1 唯一权威。
2. `bootslot-b/boot_b-pre-vk183-20261030.img`（e6b1124c…）= 官方指定回退件。
3. `bootslot-b/boot_b-vk181-daily-signed-20261029.img`（b72866ef…）= 日常内核签名件（回退目标之一）。
4. `bootslot-b/boot_b.img` = flash-b.sh 工作副本（内容随刷写变化，保留但禁止当内容源）。
5. `out/boot-elden-vk183-fastrpc.img` = 当前在机内核源镜像。
6. `backup/HA2EXB0E-16+512/`（含 device-rescue-20261017、c0-baseline、gpt 手术 dump）= 设备等价纪律下的唯一整机备份。
7. `backup/stock-259/`（boot_b/vbmeta_b/dtbo_b 原厂件 + recovery_b）= 回 Android 的原始槽件。
8. `backup/fw/` + `out/debian/firmware-root/` = 原厂固件链（ADSP/CDSP/GPU/ath12k…），G1 依赖。
9. `versions/vk-kernel-identity.tsv` + `vk-registry.tsv` = img 身份 SSOT。
10. `reports/artifacts/` 中被引用的 46 个目录（b5/g3/uefi-ddr/m3v5-onboard/m8ab/por 等）= 正式报告证据链。

## 3. 孤儿件清单（无 reports/*.md 引用）

- **目录 34 个**（见 TSV referenced_by=unreferenced），代表：`c3-spic-20261027`、`display-drop-20261027`、`q28-clkdiag-*`（多为散 txt）、`uefi-boot-20261101-*`×19。
- **散件 38 个**（reports/artifacts/ 顶层）：q28-clkdiag/q32-boot txt 群、reply-konrad/pengyu 邮件稿、vk129 截屏 txt、`0001-pci-qcom-*.patch`、`uefi-mu-submodules log` 等。
- `bootslot-b/boot_b-bb1.img`：无任何引用，身份不明（96 MiB）。

## 4. bootslot-b（15 个 img，1.3 GiB）

当前在机 = **vk183-fastrpc**（分区 sha aedae5f1…，与 `boot_b-device-backup-20261101.img` 一致）。
回退件 = `boot_b-pre-vk183-20261030.img`；日常 = `boot_b-vk181-daily-signed-20261029.img`。
其余 vk127/128/129/145/151/152/163/m3v5-daily/pre-vk151 = 历史；`boot_b-bb1.img` 孤儿；`boot_b.img` = 可变工作副本（本次实测 sha fb55997c…，≠ 分区值，符合「随刷写变动」口径）。
逐件 sha12 见 TSV。

## 5. out/ img 与已知坏件

69 个 img。**3 个坏件（kernel-unreadable，versions/vk-kernel-identity.tsv 确认）**：
`boot-elden-dtbo3.img`、`boot-elden-gh612b.img`、`boot-elden-vk146-BADSUSPEND.img` → verdict=stale。
重复 2 对：`boot-elden.img`==`boot-elden-m3v5-onboard-b.img`（a144e5ce1b37）、
`boot-elden-vk141-q28disp73.img`==`vk142-q28disp73dt.img`（10a38c4e7bab）。
其余均在 vk-kernel-identity.tsv 有身份记录（uts/kbin_sha），verdict=history。

## 6. 顶层大目录速判

| 目录 | 条目 | 大小 | 判断 |
|---|---|---|---|
| archive/ | 13 | 2.6M | 已退役脚本/计划/topics 归档，按日期命名，健康 |
| probes/ | 5 | 2.4M | 一次性探针脚本，小 |
| patches/ | 107 | 13M | 内核补丁 + kernel-history 七套变体（内部大量重复系列） |
| dl-cam/ | 23 | 2.7G | 相机 bring-up 上游源（AOSP/donor），G1 相机线依赖 |
| stock-src/ | 3 | 2.0G | stock 内核源码树（lenovo sm8750），参考用 |
| reference/ | 11 | 6.1M | 外部参考仓库（gunyah-refs 等） |
| waydroid-ota/ | 2 | 48K | Waydroid OTA 记录/stub |
| rootfs/ | 25 | 836K | rootfs 构建脚本 + debian overlay 入口，活跃 |
| backup/ | 25 | 3.2G | 设备/原厂备份（GPT/固件/槽镜像/救援件），**勿动** |
| env-pass/ | 3 | 3.3G | 大体积快照，本报告未深查，建议下一轮单独审计 |
| geekidos-linux/ | 43 | 2.9G | geekidos 发行树，非当前主线 |
| y700四代工具/ | 4 | 271M | 联想官方工具留存 |

## 7. 风险与备注

- 大文件（≥200 MiB，如 rawdump.img、build/ 内件）只做大小+mtime 对比，未算 sha。
- `env-pass/` 3.3 GiB 用途未核实，清缓名单暂不纳入。
- 所有建议仅是建议；执行清理需另行批准，本 lane 未动任何既有文件。

DONE
