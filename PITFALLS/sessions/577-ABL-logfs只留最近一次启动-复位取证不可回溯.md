# #738 · ABL `logfs` 只留**最近一次**启动的日志，且 `Reset by PSHOLD` 与正常重启同款 ⇒ 复位取证必须「复位后第一发即读」

- 日期：2026-11-27（无人值守轮，只读采集）
- 事实（本机现态实测）：
  1. `ssh elden-root 'dd if=/dev/sde68 bs=1M count=8'` 取回 8 MiB（sha256 `f3d98a3b…`，留档
     `reports/artifacts/sensors-692-logfs-20261127/logfs-sde68.img`），`scripts/logfs-decode.py --tsv` 得到 **10 段**
     每段都有 `QC_IMAGE_VERSION_STRING`（段内偏移固定 `0x7087`）。
  2. 但 FAT12 目录项 `UEFILOG1.TXT` 的 **size = 65536（= 1 段 64 KiB）**，且整个分区只有 **1 个** `UEFILOG` 目录项
     ⇒ 当前只表达「最近一次启动」；其余 9 段是**陈旧残留**（全部 `Booting from slot (_a)`、VBAT 3.9–4.0 V 的时期）。
  3. 段 0 = 2026-11-26 23:11:29 那次启动（= `#737` 最后复位后的回落启动，`_b` 槽），它记的上一发复位是
     `PM: Reset by PSHOLD` + `PM: Reset Type: Hard Reset`，`PM: PON by` **空**。
- 判据（照抄可用）：
  - **不要**把「10 段环形」当回溯能力（`reports/uefi-observability-pivot-20261101.md` §1.1 的结论在本机现态已不成立）。
    要拿「崩的那一发」的 ABL 记录，只能**复位后设备一起来就去读**，晚一发就被覆盖。
  - `Reset by PSHOLD` / `Reset Type: Hard Reset` 与**正常重启同款**（`#184`/`#182`）⇒ 该字段**不能**判根因，
    也不能用来区分「PMIC/AOP 硬复位」与「内核 reboot」。它是「AP 侧 PS_HOLD 被拉低」的**路径**记录，不是**来源**记录。
  - 读取链：`scripts/logfs-decode.py <img> --tsv`（每段一行）/ `--segment N`（整段正文）；取件 `ssh elden-root 'dd if=/dev/sde68 bs=1M count=8'`。
- 指针：`reports/artifacts/sensors-692-logfs-20261127/README.md`（采集上下文与同轮 PD/PDR 现态）、
  `reports/sensors-692-backport-test-20261126.md` §8（`#737` 的实测基线）。
