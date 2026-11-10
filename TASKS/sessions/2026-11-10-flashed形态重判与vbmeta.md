# 2026-11-10（下午/晚）— flashed 形态重判：计时判据失效 + logfs 盲区 + **金标准对照把矛头指到 `vbmeta_a`**

- **日期**：2026-11-10（同日第三段；前两段见 `2026-11-10-发送清理与p67上机p68备料.md` 与 `2026-11-10-UEFI落盘信标收口p63-p66.md`）
- **pi 会话 id**：本段会话（关键词「p69 计时判据 / 金标准 boot_a / vbmeta Flags」）
- **主题**：紧承 p67 待办的「把信标搬到最早阶段」⇒ 先用**启动耗时**做免屏判据（p69/R70），失败后改用**金标准对照**，
  最终把根因假设从「我们的件没跑到」改成「**`vbmeta_a` 校验失败 ⇒ ABL 不交棒**」
- **结论**：
  1. **R70 计时判据只成立为正控**：`fastboot boot` 54.5 s → 128.7 s（+74.3 s ≈ 3×25 s，停留确实执行）；
     flashed 28.9 s → 28.8 s（+0 s）**不能**当「没跑到」的反证 —— 该形态是**硬复位**（logo 一闪→掉电），复位把停留剪断。
     失败发寿命 ≈10 s（flashed 28.8 s − `_b` 基线 18 s）。
  2. **logfs 看不到失败那一发**：每发只有 slot0 变，内容是**成功 `_b`** 的记录；`_a` 尝试零记录。
     且旧 p67 报告把 logfs 数成 2 条（实为 **10 条**），blk1–9 是 `6.0.250606` 旧固件历史 ⇒ 其 §3 时间线作废。
     `oem sbread` **只在我们的 UEFI 里有**，stock fastboot 是 `unknown command` ⇒ bl 里读不到 logfs；恢复动作会覆盖 slot0。
  3. **金标准对照（本轮关键）**：把设备上 `boot_b`（`4e38bc2c…`）**逐字节**刷进 `boot_a`，仍然起不来 —— 但死法不同：
     「解锁警告 5 s 自续 → 无缝回 bl 不掉电（16 s），`unbootable=0`」 vs 我们 payload「logo 一闪→掉电，`unbootable=1`」。
     `/sys/fs/pstore` 空（无内核崩溃转储）。⇒ **flashed 失败与我们的固件无关**（`#588` 同族）。
  4. **唯一槽位级差异 = `vbmeta` 的 Flags**（`tools/avbtool.py info_image`）：
     `vbmeta_a` key `8fcb864f…` Aux 8000 **Flags 0**（原厂签名、原厂哈希）；`vbmeta_b` key `fc1e3b33…` Aux 2368 **Flags 3**
     （`VERIFICATION_DISABLED|HASHTREE_DISABLED`，我方 avb.key）。`_b` 每发都有 `Public key … rejected` 却照常交棒。
     ⇒ **根因假设**：我们替换后的 `boot_a` 过不了 `vbmeta_a` 的哈希校验，ABL 走「校验失败」分支（那 5 s 警告）⇒ 不交棒。
  5. **振动不能当判据**：我们的 FV（`SM8750_EFI.fd`）里 `haptic` 字符串**计数 0** ⇒ 用户听到的「一短一长」来自 **stock 固件**，
     只能当「发生了两次启动」的时钟。
- **证据指针**：
  - 正文 `reports/uefi-p69-flashed-and-vbmeta-20261110.md`
  - 试验目录 `reports/artifacts/uefi-flashed-20261110-{144350-p67-control,144523-p69-r70-timing,151425-p69-flashed-video2,152923-ctrl-known-good-into-boot_a}/`
    （各含 `pre.txt`/`post.txt`/`timing.txt`/`verdict.txt`/`logfs-sha256.txt`；8 MiB logfs 全量件按 `.gitignore` 本地保留）
  - 件/归档 `out/r21-sbstop-p69/uefi-preamble69-r1.img`（`38202e12…`）、`reports/artifacts/uefi-20261110R70-p69/`
  - 补丁 `patches/uefi/20261110R70-prepi-timing/`、配方 `patches/uefi/p69-recipe.txt`、工具 `scripts/uefi-flashed-trial.sh`
  - 对照备份 `backup/boot_b-live-vk184-20261110.img`（= `boot_b`）、回滚件 `backup/boot_a-pre-uefi-20261108.img`（`d4772c11…`）
  - vbmeta 快照 `/tmp/vbmeta_{a,b}.img`（`55929c15…` / `e974ebab…`）—— 建议尽快复制进 `backup/`
  - 坑 `PITFALLS #593/#594/#595/#596/#597`
- **★SSOT 待并入**：已并入 `TASKS/README.md` §0 G1-29 行 + §5 新块、`patches/uefi/README.md` §0、`PITFALLS/README.md` 索引
- **设备态**：U2 在 Linux（`7.3.1-debug-vk184-00003-gec74c4795a43`，`boot_b`）；**`boot_a` 当前 = 金标准件 `4e38bc2c…`**
  （未回滚到 `d4772c11…`）；槽位 `boot_a retry=6 succ=0 unbootable=0`、`boot_b retry=6 active=1 succ=1`
- **剩余（需人/需批）**：
  - 下一发 = 造 **Flags=3 / 我方密钥的 `vbmeta_a`** 并刷入（**写 `vbmeta_a`，需批准**；先备份 64 KiB）
  - `boot_a` 回滚到 `backup/boot_a-pre-uefi-20261108.img`（`d4772c11…`）
  - 录屏仍未收到（`reports/artifacts/uefi-video-20261110/` 为空）；若要做，目标已改为「logo→掉电的秒数」
