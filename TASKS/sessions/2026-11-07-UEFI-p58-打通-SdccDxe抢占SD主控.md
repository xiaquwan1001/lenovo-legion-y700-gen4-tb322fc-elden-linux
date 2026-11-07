# 2026-11-07（深夜·三）— UEFI p58：**间接引导打通**；真因 = `SdccDxe` 抢初始化 SD 主控

- **日期**：2026-11-07（深夜·三，接 p54→p57「看门狗三路证伪」轮）
- **pi 会话 id**：见 `.pi/sessions/*.jsonl`（关键词「p58 nosdcc HANDOFF_TAGGED / SdccDxe 三处清单」）
- **主题**：用户「就绪，在 fastboot」⇒ 把 p58（= p54 配方 + R46 + R53「真摘掉 SdccDxe」）上机
- **结论**：
  1. **打通**：`scripts/uefi-boot-trial.sh` 给出 `VERDICT(final)=HANDOFF_TAGGED`；设备 23:17:56 起跑在
     `elden_bootpath=uefi` 的内核上，`up 8+ min`、桌面会话（`tty7`/seat0）、`wlp1s0`、Waydroid、SD 卡全在，
     `/proc/cmdline` 含令牌，`/sys/fs/pstore` 与 `/var/lib/systemd/pstore` 均空（无崩溃）。
  2. **真因**：UEFI 的 `SdccDxe` 初始化了 `8804000.mmc` 却没在交接前收尾 ⇒ 内核接手后
     `mmc0: ADMA error: 0x02000000` + `ADMA Ptr: 0x0000000ffffff224`（荒谬物理地址）⇒ 整机硬复位。
     摘掉 `SdccDxe` 后同一内核 `new high speed SDXC card @4.0 s`、`mmcblk0 58.6 GiB`、`probe returned 0`。
  3. **「看门狗」假设彻底作废**：p54–p57 三路证伪 + fault-handler 自旋 15 min 的反证先排除了它；
     本次只用一发单变量就闭环。**「交棒后 ~4 s 硬复位」= 内核在 mmc0 上打到坏 ADMA 描述符**。
  4. **R46 漏了两处**：`SdccDxe.inf` 同时出现在 `APRIORI.inc:75` 与 `DXE.dsc.inc:41`，只注 `DXE.inc`
     它仍被 APRIORI 拉进 FV 并 dispatch ⇒ R53 补齐（纪律：摘 DXE 件三处都要动）。
  5. **顺带发现**：UEFI 引导的内核 cmdline 里 `androidboot.serialno=51318dc0`（**不是** Lenovo SN
     `HA2EXB0E`）⇒ 按该字段认机器会指错（`PITFALLS #555`）。
- **下一步**：① 把 `SdccDxe` 剔除（R46+R53）固化进默认世代配方；② G1-29 剩余项 = BDS/GRUB 菜单 +
  直接从 FAT/EXT4 读 kernel/initrd + 决定落地方式（写 `uefi_a` 属写盘，先备份）；③ 想上游化再查
  `SdccDxe` 到底漏了哪步收尾。
- **证据指针**：
  - `reports/uefi-p58-sdccdxe-handoff-success-20261107.md`（正文）
  - `reports/artifacts/uefi-p58-handoff-success-*/{onboard-state.txt,dmesg.txt}`（设备侧当场快照）
  - `reports/artifacts/uefi-boot-20261107-231716/`、`reports/trials/20261107T151955Z-uefi-p58-nosdcc.json`
  - 补丁 `patches/uefi/20261107R46-nosdcc/`、`patches/uefi/20261107R53-nosdcc-all/`；配方 `p58-recipe.txt`（76）
  - 镜像 `out/r21-sbstop-p58/uefi-preamble58-r1.img`（`d76ede27…`）；构建归档 `reports/artifacts/uefi-20261107R46R53-p58/`
  - 坑 `PITFALLS #554`（真因）/`#555`（UEFI 下的 serialno）
- **★SSOT 待并入**：`TASKS/README.md` §1 G1-29 行 + §5「2026-11-07（深夜·三，p58）」块（已并入）；
  `INDEX.md` §3（已改）；`PITFALLS` 索引 #554/#555（已并入）
- **设备态**：U2 正在跑 p58 的 UEFI 引导内核（`boot_b` 未动，零写盘）
