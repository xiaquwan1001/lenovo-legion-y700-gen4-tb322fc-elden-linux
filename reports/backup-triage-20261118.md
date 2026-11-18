# backup-triage-20261118 — backup/ 整理归类、去重、精简合并（dry-run，未删任何东西）

> 执行面：静态盘点 + sha256 定量比对。**主代理已复核并执行其中三步（见 §0.1）；git bundle 那一步仍挂起。**
> 交付：`scripts/backup-triage.sh`（默认 dry-run，`--apply` 才动，journal + 回收目录可回滚）+
> `versions/backup-manifest.tsv`（逐项台账）。本报告不改 `RESOURCES/README.md` 等既有文档。

## 0. 数字结论

- backup/ 总量 **≈ 28 GiB**（`du -sb` = 30.18e9 B，3387 个文件；官方包 16 G + out-history 7.6 G 占 88%）。
  （初版写的 23.6 GiB / 25.3e9 B 是子代理算错，主代理 2026-11-18 17:13 实测纠正。）
- **净可回收 ≈ 1.31 GiB**：boot 重复 100 MiB + tb322fc-edl 硬链接去重 467 MiB + git bundle 789 MiB + 空目录 3 个。
  **实测已回收 467 MiB（硬链接，df 可见）**；另 100 MiB 在 `backup/.triage-trash-*`（可回滚，确认后清）。

### 0.1 主代理复核与执行（2026-11-18 17:10–17:14）

1. **独立复验三条 sha 结论全部成立**：`boot_a-pre-uefi ≡ stock-259/boot_a ≡ fw/tb322fc-edl/boot.img`（`d4772c11…`）；
   `fw/tb322fc-edl/NON-HLOS.bin ≡ official-rom/NON-HLOS.bin`（`5d411ac0…`）；bundle tip `18e6b78c` 与 `refs/original` 一致。
2. **发现并修了脚本的 P0 缺陷**：所有动作在 `bash -c` 子进程里跑，而 `APPLY/JOURNAL/TRASH` **没有 export**
   ⇒ `--apply` **静默退化成 dry-run**（首轮三次 apply 全部空转、`journal` 文件都没生成）。已加 `export` + APPLY 末尾自检
   （无 journal 条目就 WARN/报错）。**这是“dry-run/apply 开关失效”的第 N 次复发（#669 / #654 同族），已进审计判据。**
3. **已执行**：`dedup-hardlink`（59 个硬链接，467 MiB）、`delete-dup`（boot 重复件已进 trash）、`delete-empty`（3 个空目录已删）。
4. **未执行**：`merge-bundles`（789 MiB）——按 AGENTS.md「backup/ 不可再生件删前须云盘/bundle 兜底」，
   等 `git-slim-20261113` 上云后再跑（那两份 pre-rewrite bundle 是改史前唯一副本）。
- **真重复（sha256 定量）**：4 组，见 §2。
- **引用漂移（P1，3 处）**：文档引用的 3 个 backup/ 大件已不在盘，见 §4。
- **恢复 U2（fastboot + boot_a UNBOOTABLE）所需件**：见 §5，全部在盘且无删改。

## 1. 逐项分级（明细 = versions/backup-manifest.tsv）

| class | 件数 | 代表 |
|---|---|---|
| KEEP-CRITICAL（不可再生或唯一副本） | 16 | HA2EXB0E-16+512、git-slim-20261113、gpt/gpt-20261031/lun4-gpt、misc、slot-probe、rawdump.img、sde-gpt-{head,tail}.bin、boot_b-live-vk184、stock-259、vbmeta_a/b、artifacts-bundle、build-bundles、out-history-20261105 |
| KEEP-REF（可再生但重取成本高） | 6 | official-rom-15.10.259（官网可重下，~16 G）、fw、avf、stock-elden、device-test-20261113、m1-73-config、doctor-scripts、uefi-builds-20261106 |
| KEEP（证据/标记） | 4 | corrupt-20261103（与 out/ 同 inode，0 成本）、elden-dump.txt、f2fs-migrate×3、dtbo_a-pre-uefi（硬链接） |
| MERGE | 1 | git-history-rewrite-20261112（被 main-all bundle 覆盖） |
| DELETE | 6 | boot_a-pre-uefi-20261108.img（重复）、3 个空目录、2 份 pre-rewrite bundle（合并后删） |

## 2. 真重复（sha256 定量，非文件名推断）

1. **boot_a-pre-uefi-20261108.img ≡ stock-259/boot_a.img ≡ fw/tb322fc-edl/boot.img**
   sha256 `d4772c1189b5d438…` 三处逐字节相同 → 删顶名 1 份，回收 **100,663,296 B**。
2. **fw/tb322fc-edl/ 65 件中 61 件 ≡ official-rom-15.10.259/ 同名件**（DIFF 仅 boot.img、vbmeta.img）。
   逐 sha 比对，相同字节合计 **490,357,833 B (467 MiB)** → 同盘 `ln -f` 硬链接，0 语义损失；独有件保留：
   `gpt_main0..5.bin`/`gpt_backup0..5.bin`（EDL 侧 GPT 全 LUN 表）、`*.dec`、`四代旧版abl.elf`、`out/`、`imagefv.elf.dec`、`uefi.elf.dec`。
3. **out-history-20261105/boot-elden-vk141 ≡ vk142**（同 inode 硬链接，双名=账目语义，0 成本，保留双名）。
4. **f2fs-migrate 三目录**：`gpt_before_{main,backup}0.bin` 三份 sha 相同 → hardlink；`gpt_after_*` 三目录各唯一（写盘往返状态），**保留三目录**（RESOURCES §3:167 点名留档）。
5. dtbo_a.img ≡ dtbo_a-pre-uefi-20261110.img ≡ official-rom-15.10.259/dtbo.img（sha `45f51790…`；前两者已同 inode）。

## 3. 分级处置与替代源

- **DELETE boot_a-pre-uefi-20261108.img**：替代源 `backup/stock-259/boot_a.img`（sha 已验同）。回滚 = journal 内 sha 比对 + trash 目录 mv 回。
- **DELETE 空目录** git-history-rewrite-20261103 / git-repair-20261105 / m3v5-onboard-20261031：`find -type f`=0。
- **MERGE git-history-rewrite-20261112 → 删两份 bundle（789 MiB）**：
  - `pre-rewrite-main-2.bundle` tip `18e6b78cab` ≡ `git-slim-20261113/main-all-20261113.bundle` 的 `refs/original/refs/heads/main`（实测同 sha）；
  - `pre-rewrite-main.bundle` tip `264073bf` 经临时仓 fetch + `merge-base --is-ancestor` 验证**是 `18e6b78cab` 的祖先**，无独有悬空提交；
  - 脚本在 `--apply` 时仍会重做 tip 匹配 + fetch 试取，不匹配即 ABORT 不删。
  - ⚠ 前置：先把 `git-slim-20261113/`（1.24 G）上云（技能 `ustc-cloud-drive`），删本地重复才有"第二副本"兜底。
- **hardlink 去重** tb322fc-edl ↔ official-rom：不删任何数据，`ln -f` 同 inode，省 467 MiB；journal 记 HARDLINK 行。
- **明确不删**：
  - out-history-20261105：114 件全在 `versions/vk-kernel-identity.tsv` 有行（B3 账闸），删任何一件都会毁账目一致性；真回收须先 tar.zst 或上云，本轮不做。
  - stock-259：设备原厂分区态，ROM 包内 boot.img（`b428a31d…`）与设备 boot_a（`d4772c11…`）**sha 不同** ⇒ 不能纯靠重下 ROM 复原设备态。
  - corrupt-20261103：与 out/ 同 inode，删它 0 收益，还丢取证标记语义。

## 4. 引用漂移（文档引用的大件已不在盘 — P1，需修文档或补备份）

1. `RESOURCES/README.md` §360：`backup/kernel-git-repair-2026-10-23/elden-all-refs-66.bundle`（290 M，67 heads，vk34→vk127 唯一 git 备份）**已不存在**。现役替代 = `git-slim-20261113/*.bundle`（main/geekidos/m3v2 全 refs）。悬空提交 `f61b4b82ca` 是否被新 bundle 覆盖**未验证**，修文档前须核。
2. `RESOURCES/README.md` B1（§325）：`backup/build-bundles/m3v2-7.3rc7-git-20261105.tar.zst`（1.33 G，142 未推送提交）**已不存在**；现 build-bundles/ 仅 606 KB（MANIFEST + dirty diffs）。需确认 tar 去向或补 bundle。
3. `versions/cloud-backup-20261016.MANIFEST.sha256` 引用的 `kernel-git-repair-2026-10-08/10-10` 目录已不在盘（云包内应有，若云在则无损失）。

## 5. 恢复 U2 需要哪几件（当前：fastboot，boot_a UNBOOTABLE）

| 步骤 | 用件 | 路径 |
|---|---|---|
| 0. 槽位读态/复位（清 UNBOOTABLE、补 retry） | scripts/slot-attr.py（权威头注释） | scripts/ |
| 1. LUN4 GPT 修复/对照 | LUN4 主备表 | `backup/lun4-gpt-20261101/{lun4-gpt-primary,lun4-gpt-backup}.bin`（SHA256SUMS 在） |
| 2. LUN0 GPT 对照 | `backup/sde-gpt-{head,tail}.bin`、`backup/gpt-20261031/`（512 档手术前双表） | 同 |
| 3. fastboot 刷原厂件 | `backup/stock-259/`（boot_a/b、dtbo、vbmeta、abl、recovery、init_boot，SHA256SUMS 在）+ `backup/vbmeta_a-orig-20261110.img`、`backup/vbmeta_b-20261110.img`、`backup/boot_b-live-vk184-20261110.img`（现役 b 槽状态） | 同 |
| 4. EDL 兜底（9008 救砖） | `backup/fw/tb322fc-edl/`（firehose/rawprogram/patch + 全 LUN GPT）+ `backup/official-rom-15.10.259/`（全量）+ `backup/rawdump.img` | 同 |
| 5. U2 独有分区（EDL 不刷） | `backup/HA2EXB0E-16+512/unique/part-*.bin`（persist/modemst/keystore 等 21 件，md5 账在 MANIFEST.txt） | 同 |
| 6. 现役 Linux boot 回退 | `backup/out-history-20261105/boot-elden-vk184*.img` 时代件 + `boot_b-live-vk184-20261110.img` | 同 |

⇒ **§3 的 DELETE/MERGE 动作不触碰上表任何一件**（boot_a-pre-uefi 有等价副本在 stock-259）。

## 6. 执行与回滚

```
scripts/backup-triage.sh            # dry-run：逐条打印动作与字节数，不写盘
scripts/backup-triage.sh --apply    # 执行：journal=backup/.triage-journal-*.tsv，删除件进 backup/.triage-trash-*/
# 回滚：按 journal TRASH 行把 .triage-trash-*/<rel> mv 回原路径（sha 已在 journal，可复核）
# --only delete-empty|delete-dup|dedup-hardlink|merge-bundles 可分步执行
```

删除前二次校验：delete-dup 比对 sha 不匹配即 ABORT；merge-bundles 做 tip 匹配 + 临时仓 fetch 试取；hardlink 只在 sha 相同且同盘时执行。
**建议执行顺序**：① `git-slim-20261113/` 上云 → ② `--only dedup-hardlink` → ③ `--only delete-empty,delete-dup` → ④ `--only merge-bundles`。①未完成前不要跑 ④。

## 7. 收尾状态

- 本轮零删除、零改动既有文件；新增 3 文件：本报告、`scripts/backup-triage.sh`、`versions/backup-manifest.tsv`（注意：新增脚本需在 versions/layout.tsv 已有 backup/scripts 登记范围内，无需改表）。
- 未尽事项：vbmeta_a-orig/vbmeta_b 与 stock-259 对应件的 sha 核对（64 KB，留待下一轮）；RESOURCES 3 处引用漂移修正（属既有文件修改，本轮禁改，需单独一轮）。
