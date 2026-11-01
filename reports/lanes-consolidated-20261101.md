# 2026-11-01 四 lane 收口 + 设备现状（整理件）

> 性质：**整理/汇总**，不改 SSOT 正文。四条后台 lane 的产物与结论在这里合并成一页，
> 逐条给出「能不能直接执行」。设备侧另有本轮实验的现场事实（§5），**当前设备停在 fastboot，未恢复**。
> 各 lane 原始报告：`reports/asset-inventory-20261101.{md,tsv}`、`reports/doc-mail-audit-20261101.md`、
> `reports/research-horizontal-sm8750-20261101.md`、`reports/research-vertical-y700-lineage-20261101.md`（最后一个仍在写）。

---

## §0 一页结论

| lane | 状态 | 一句话结论 | 可立即执行的动作 |
|---|---|---|---|
| 资产整理 | ✅ 完成（91 行 + 215 行 tsv） | 项目总占用 ≈ **210 GiB**（`build/` 183 G 一家独大）；同 sha 重复件可省 **≈895 MiB**；34 个 artifacts 目录无报告引用 | 只做「重复件去重」一批（需批准），不要碰 `backup/`、`bootslot-b/` |
| 文档+邮件 | ✅ 完成（145 行） | 文档矛盾 **11 条（P0=4）**；`check-doc-assets` PASS、`check-doctor` **FAIL=1 / WARN=6**；**需回邮件 3 封**（Dmitry 两条 mdss 意见最硬） | ①改 TASKS §5 11-01 块两处；②DEVICE §1.1 加在机条；③mdss v3 必做 |
| 横向同芯片 | ✅ 完成（319 行） | **"SM8750 上 fastboot boot 不执行载荷"这个前提被外部证据推翻**（piano 用 `getvar product` 验证过 UEFI 在跑）；可见性正解 = **UEFI 侧 USB fastboot**（`oem ramlog/screenshot/status`）；UFS 靠 3 处字节级旁路；白屏 = ClockDxe 5 字节 | ①照抄「USB 可见性」通道方向；②UFS 三旁路已是本地设备包内容，可对照；③ClockDxe 5 字节可做对照臂 |
| 纵向同产品线 | ✅ 完成（299 行） | 五代同模具连续线（TB-9707F→TB323FU）；**Gen4 是唯一有主线板级 DT 提交的一代**（Pengyu v2，`changes-requested`，未合并）；**⚠ 我们的 WL2868C v4 里那 175 行同名 `sm8750-lenovo-elden.dts` 与 v2 的 1170 行撞名双来源** | ①上游化改「基于 v2 的增量」或等 v2；②Gen3 的 `vm-bootsys` 方案不可搬（Gen4 无该分区）；③面板供应商先统计别写死 |

---

## §1 资产整理（`reports/asset-inventory-20261101.*`）

**结论**
- 总占用 ≈ **210 GiB**：`build/` 183 G、`out/` 6.7 G、`env-pass/` 3.3 G（用途未核实）、`backup/` 3.2 G、
  `geekidos-linux/` 2.9 G、`dl-cam/` 2.7 G、`stock-src/` 2.0 G、`bootslot-b/` 1.3 G、`reports/artifacts/` 329 MiB。
- **同 sha256 重复 ≈895 MiB**（只比了 <200 MiB 的文件）：最大 `out/vk133-ramdisk.cpio.gz` 系列 3 份同 sha（123 MiB×3）、
  `out/boot-elden.img` == `boot-elden-m3v5-onboard-b.img`（84 MiB）、`vk141`==`vk142`（81 MiB）、
  `backup/stock-259/recovery_b.img` 重复份（100 MiB）、`out/ramdisk-vk181-working.cpio.gz` 两份（61 MiB）。
- **孤儿**：`reports/artifacts/` 34/80 目录无 `reports/*.md` 引用（多为 `q28-clkdiag-*`/`uefi-boot-20261101-*` 裸探针 txt）；
  `bootslot-b/boot_b-bb1.img` 无任何引用。
- 明确 **stale**：`out/` 3 个 `kernel-unreadable` 坏件（`boot-elden-dtbo3.img`、`boot-elden-gh612b.img`、`boot-elden-vk146-BADSUSPEND.img`）。

**判读纪律**
- `bootslot-b/boot_b.img` 是**可变工作副本**（本轮实测 `fb55997c…`），不能当内容源；权威件是 `boot_b-device-backup-20261101.img`（`aedae5f1…`）。
- ≥200 MiB 的文件（含 `build/` 内件、rawdump）只做了大小+mtime 对比，**没有 sha 结论**。
- `env-pass/`（3.3 G）未核实用途 ⇒ 暂不进清理名单。

## §2 文档 + 邮件（`reports/doc-mail-audit-20261101.md`）

**P0（4 条，建议本轮就改）**
1. `TASKS/README.md:312` 「干净 header 下 7/7 载荷被执行」已被同日 `reports/uefi-ddr-blackbox-20261101.md` §7/#481 二次作废
   （`usb_read failed` = ABL 接手 ≠ 载荷执行）。同块「1–2 s 掉电」口径也要改成「~20 s 复位回落」。
2. `TASKS/README.md:316–319` 「下轮顺序」三条（R2 目视 / PrePi pet wdog / header 逐字段夹死）前提全部失效。
3. `DEVICE/README.md §1.1` 首条仍写 10-31「全程零写盘」，与 11-01 三次重打包写盘（bb1/bb3/备份）矛盾 ⇒ 需新增在机条。
4. `TASKS/README.md:21` §0 运维行「2026-10-29 在机 = vk181」过期。

**P1（7 条）**：cleanheader 报告的「执行」字样（建议顶部勘误框，不改正文）；10-31「厂商 UFSDxe × cachefix shim」块缺回链；
`PITFALLS #477`「写 FB 致命」需降级注；`#479` 与 `#481` 层级冲突；observability-pivot 的「1–2 s = wdog」需重归因；
两份 10-31 报告需勘误框；`INDEX.md:18` UEFI 行指向过旧。
**建议新增 `#482`**：`fastboot boot` 接受/拒绝**非确定性**（同镜像三发三态；且与另一槽是否 bootable 相关）。

**邮件（近 4 天，需回 3）**
| # | 信件 | 必须动作 |
|---|---|---|
| 1 | Dmitry：mdss v2 2/3 —— 删 `msm_mdss_reset()` 上方新加长注释（他点名「AI agents like lengthy comments, useless」） | **v3 必做** |
| 2 | Dmitry：mdss v2 3/3 —— **drop the RSCC reset**（与 Konrad 10-31 意见一致） | **v3 必做** |
| 3 | `postmaster@qualcomm.com` 退信（线程错位引用 IPQ5018 PHY） | 人工核实收件地址，再决定是否重发 |
| 4 | issue #12（open，7 评论，最新 10-29 sunflower2333：「别用劣质 token 瞎猜；去弄 USB ACM Gadget」） | 建议简回（接受固件版本定性 + 说明实测重心已移到装载路径/判据 + 正面接 ACM 方向），无死线 |

**纪律**：Dmitry 对 LLM 味文本敏感 ⇒ v3 commit message 与回信要短，并按 `AGENTS.md` 披露 AI 辅助。

## §3 横向同芯片（`reports/research-horizontal-sm8750-20261101.md`）

**最硬的三条**
1. **「fastboot boot 到底执行不执行我们的载荷」已由外部证据判「执行」**：小米平板 8 Pro（`piano`，**同为 SM8750P**）
   的临时启动就是 `fastboot boot SunUEFI-UEFI-Fastboot.img`，验证方式是 `fastboot getvar product` 返回 `piano-sunuefi`；
   第二套实现（piano-uefi/Visor）用**无 AVB footer** 的自制 boot.img `fastboot boot` 也成了。
   ⇒ 问题不是「没执行」，而是「**看不见 + 活不长**」。
2. **可见性正解 = 把观测面搬到 USB**（不用屏、不用 UART）：UEFI 侧常驻 fastboot 服务
   `oem ramlog`（≤256 KiB 内存日志）/ `oem screenshot`（读 framebuffer 出 BMP）/ `oem status`；
   Visor 还能 `oem dump 81CE4000 10000` 读**原厂 bootloader 自己的启动日志**、`boot app.efi` 从 RAM 跑 EFI 应用。
3. **白屏定到指令级**：原厂 `ClockDxe` RVA `0xc784`（`BL`→`MOV w0,#0`，延后 CESTA/media）+ RVA `0x3ead0`（DCD 开关 1→0），**共 5 字节**。

**其它可用事实**
- 我们这台机的设备包第三方已建好（`mu_wide_platforms/…/lenovo-y700g4`，1904×3040 PCD + 7 个 patched 厂商 DXE）；
  `QcomWDogDxe` 在 5 个 Pakala 设备包里是**同一 blob** ⇒ 看门狗是平台级共性，不能靠换件。
- UFS 两层故障社区答案是**绕过**：`0xa998` Sleep→Wakeup、`0x114c4` 绕 gear 检查、`0x1b080` 把 `EnableUfsIOC` 整个 stub 成
  `mov w0,#0; ret`（= 让 `UFSSmmuConfig` 恒成功，正是我们 `UFS.c+2326` 断言的上游）。三处已本地逐字节复核。
- 上游 DTS：`torvalds/master` 只有 SoC 级 `sm8750*`/`kaanapali*`，**机型 DTS 0 个**（无 elden/piano）。

## §4 纵向同产品线（`reports/research-vertical-y700-lineage-20261101.md`）

**代际（已证）**：Gen1 `TB-9707F`(SD870) → Gen2 `TB320FC`(8+ Gen1) → Gen3 `TB321FU`(8 Gen3) →
Gen4 `TB322FC`(8 Elite，我们) → Gen5 `TB323FU`(8 Elite Gen5)。代号 Pike/Asphalt/Kirby/**Elden**/Baldur。
**「Legion Tab」不是独立线**，是 Y700 海外名；Gen2/Gen3 有全球版，**Gen4 没有**（2026-03 直接发 Gen5）。

**Linux 进展非单调**：Gen3 最完整（GUF296 非破坏性双启动 + Armada 两套移植）；Gen4 下游两条内核线 + 主线 DT 在审；
Gen2 只有 Android 侧（TWRP/LineageOS/GSI）；Gen1 无 Linux，但 Mu-Silicium **UEFI 能启 Windows**（全系唯一 WoA 记录）。

**上游（已证）**：板级提交**只有 Gen4 一份** —— Pengyu Luo `sm8750-lenovo-elden.dts` + `qcom.yaml`，`[PATCH v2 0/2]`，
patchwork `changes-requested`（Abel 2026-07-27、Konrad 2026-09-02），无 v3，`torvalds/master` 无此文件；Gen1/2/3/5 板级提交 **0**。

**可跨代搬的是流程**：UFS 6-LUN/4096 B、GPT 双表手术顺序、ABL slot-retry 7 次语义、EDL loader、fastbootd 二次进入、
96 MiB boot 上限、TWRP/LTBox/GSI。**断代点四个**：SoC 平台全换、**Gen4 删除 `vm-bootsys_a/b`**（Gen3 的 Linux boot-FAT 方案作废）、
Gen4 ABL 异类载荷 header 行为（v3 静默忽略 / v0 须 `--base 0x10000000`）、面板/触屏供应商与音频/触觉 codec 换代。

**五条对我们有用的（按可执行性）**
1. **⚠ 主线 board DTS 只留一个来源**：我们的 WL2868C v4（2026-10-31 已投）**新建了 175 行同名 `sm8750-lenovo-elden.dts`**，
   与 Pengyu v2 的 1170 行板级 DT **同名双来源**；sashiko 已指出它「lacks boot infrastructure」。
   ⇒ 二选一：改成「基于 v2 的增量」（写 `Depends-on: <v2 Message-ID>`），或只上游 WL2868C driver/binding、DTS 等 v2 落地后 rebase。
2. **不要照抄 Gen3 的 `vm-bootsys` 双启动**（Gen4 该分区不存在）；Gen4 现实路线仍是「`fastboot boot` 零写盘 / b 槽直启 mainline / 自研 UEFI（搁置）」。
3. 把 Gen3 验证过的跨代不变层固化成门禁（slot-retry 语义、fastbootd 二次进入、GPT 4096 B 双表、EDL `rs/ws` 4096 B 单位、`qfil` 静默漏写要逐分区读回）。
4. **面板/触屏供应商是 Gen4 最大的同代碎片化风险**：v2 写的是 CSOT `pp8807hb1-1` + Novatek `nt36536`，国行可能混装 ⇒
   DT 保留按 panel compatible 分支的能力，先设备侧采一批 `dmesg | grep -i panel` 统计再写死；别假设 Gen3 的 BOE 补丁能用在 Gen4。
5. 上游化排序：先「设备专属外设增量」（WL2868C / AW86927 触觉 / WCN7861+ath12k / NT36536 触屏 / CSOT 面板 / `qcom_battmgr`），
   后「board DTS 整体」；**WoA 不在 Gen4 路线内**（SM8750 无 WoA 栈），G3 继续走 Box64+Wine/Proton。

---

## §5 设备现状（本轮 UEFI「槽位正常启动」实验，2026-11-01 16:39–17:20）

**做了什么（都已落盘，可复核）**
1. `boot_b` 写入 `reports/artifacts/uefi-ddr-20261101/slotb-uefi-marks.img`（sha `769c3800…`，= ddrmarks shim + Mu FD 的 v0 boot.img），
   读回 sha 逐字节一致（`reports/artifacts/uefi-slotboot-20261101/flash-readback.txt`）。
2. Linux 侧 `reboot`（正常 boot 路径）→ **+14 s 直接进 fastboot**，从未出现 Android gadget。
3. 恢复链路：`fastboot flash boot_b bootslot-b/boot_b.img`（在机原件 `fb55997c…`）成功；`--set-active=b` + `fastboot reboot`
   → 仍在 6–8 s 后进 fastboot；改 `--set-active=a`（原厂槽，`slot-successful:a:yes`）→ 仍进 fastboot。
4. `fastboot continue` 对 **a / b 两槽均报** `Failed to load image from partition: Device Error`。
5. 按「BCB `bootonce-bootloader` 残留」假设清空 `misc` 前 2048 B（保留 0x8000 起的 15 B，镜像 `/tmp/misc-clearbcb.bin`）→ 仍进 fastboot。

**当前状态（实测）**
```
current-slot:b   slot-successful:b:no  retry:b:6  unbootable:no
                 slot-successful:a:no  retry:a:5  unbootable:no
USB = 18d1:d00d（fastboot）；ssh 192.168.7.1 不可达；无 Android gadget
```
关键判读：**两槽的 `reboot` 都让 retry-count 递减 ⇒ ABL 确实在尝试启动并失败**，
所以「进 fastboot」不是 BCB 强制的，而是**每次启动尝试都失败**（与 `continue` 报的 `Device Error` 吻合）。
`boot_b` 里现装的是**之前能正常启动的同一件**（`fb55997c…`，16:2x 还在跑 vk183），所以「镜像本身坏了」不成立。

**未做 / 待定**
- 未取得本次启动的 ABL 日志（`logfs` 只能在 Linux 侧读）⇒ 归因仍缺一手证据。
- 未尝试 EDL（9008）通道读回分区做逐字节对照。
- 未做物理断电（`PITFALLS #368` 类恢复）；用户已示意先停在这条线上，**恢复动作待定**。
- 相关脚本已入库：`scripts/slotboot-run.sh`（写盘+采样）、`scripts/logfs-decode.py`（ABL 10 段环形日志解码，新写并自测过 128/10 段识别）。
