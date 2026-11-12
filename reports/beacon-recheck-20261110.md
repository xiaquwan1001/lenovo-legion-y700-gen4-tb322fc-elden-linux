# UEFI「落盘信标」线独立复核 — 2026-11-10


<!-- pitfalls-entries -->
> **本报告承载的 PITFALLS 条目正文锚点**（索引行在 `PITFALLS/README.md`；此处给 #NNN 定义，避免索引悬空）：
> `#587`、`#589`

复核人：独立子代理（只读；未用 fastboot，仅 2 条 ssh 只读命令核实分区现状）。
材料：`reports/artifacts/uefi-p63-flash-20261109/`、`reports/artifacts/uefi-p62-flash-20261109/`、
`patches/uefi/20261109R64..R67/`、`patches/uefi/p63/p65/p66-recipe.txt`、
会话记录 `.pi/sessions/2026-11-09T06-09-58-*.jsonl`（用于钉死 dump↔启动形态的对应关系）。

## 0. dump ↔ 启动形态对应（先钉死，后面引用）

按 mtime + 会话记录（jsonl 行号）：

| 文件 | mtime | 对应启动 | 记录区(0x7FC000..0x800000) sha16 |
|---|---|---|---|
| logfs-whole.bin | 20:10 | p63 flashed（第 1 发）后 | 382a99c5dbdc7794 |
| logfs-run3.bin | 22:00 | p63 flashed（第 2 发）后 | 382a99c5dbdc7794 |
| logfs-p60-control.bin | 21:06 | p60 对照件 flashed 后 | 382a99c5dbdc7794 |
| logfs-beacon.bin | 22:40 | p64(R65) flashed 后 | 382a99c5dbdc7794 |
| logfs-beacon-fb.boot | 22:47 | R65 `fastboot boot`（已证能跑通的形态，起 vk184-00002 + elden_bootloader=esp）后 | 382a99c5dbdc7794 |
| logfs-beacon2-fb.boot | 23:02 | p65(R66) `fastboot boot` 后 | 234bf434c5973982 |
| logfs-beacon-flash.bin | 23:09 | p65(R66) **flashed** 后 | 234bf434c5973982 |
| logfs-beacon-p66.bin | 23:22 | p66 flashed 后 | （文件截断，无记录区） |

校验事实（后续反复引用）：
- **历史基准记录区**（sha 382a…）在 6 个 dump 中**逐字节相同**；p62 的 dump 与 p63 的 dump 整文件 cmp 只差 ~950 B，全在 FAT 区（脏位/目录项，如字节 12375 起），**记录区 16 KiB 完全相同**。
- 234bf434 与 382a99c5 的差异**只在 0x7FD000 一个 4096 B 块**（= R66 信标块），SBLOG 记录头块 0x7FC000 逐字节未变。

---

## 命题 1：p63 flashed 失败，且与 p62 表现一致 —— **成立**

- 判据：flashed 后 logfs 记录区无任何新内容 + 设备回退 `_b`（未起我们的链）。
- 证据：
  - `uefi-p63-flash/logfs-whole.bin` 与 `uefi-p62-flash/logfs-whole.bin`：记录区 16 KiB `cmp -l` 零差异（均只有历史 `SBLOG01 tag=preeb` @0x7FC000，`R65STG/R66STG` 均 0 命中）。
  - `run3.bin`（p63 第二发）记录区 sha 同样 = 382a99c5。
  - `post.txt`/`post2.txt`：uname `vk184-00003`、`androidboot.slot_suffix=_b`、boot_a `byte6=0xb2 … unbootable=1`；`/efi/loader.log` md5 `3350166c…` 与 pre 相同 ⇒ ESP loader 没跑过。
- 结论：p63（= p60+R64，recipe 确认不含 R62）flashed 形态没走到 FV LinuxLoader（#580：logfs 只由它写），表现与 p62 完全一致。

## 命题 2：p60 对照件 flashed 也失败 —— **成立**

- 判据：同上。
- 证据：`logfs-p60-control.bin` 记录区 sha16 = 382a99c5（= 历史基准，无新记录）；`post-p60-control.txt`：slot `_b`、boot_a unbootable、loader.log md5 不变；`flash-p60-control.txt` 确认确实刷了 boot_a。
- 结论：失败与 R62/R63/R64 无关，是 **flashed 形态本身**的问题（连未加任何 11-09 补丁的 p60 都一样）。

## 命题 3：R65 v1 在已知能跑通的 fastboot boot 形态下 0 命中 ⇒ 按容量认分区选错 —— **成立（前提确凿；「选错分区」是最佳解释，唯「写入失败」未 100% 排除，但被旁证压倒）**

- 证据（前提）：
  - `logfs-beacon-fb.boot`（22:47，R65 fastboot boot，设备确已起 ESP 链：会话 L1991 `vk184-00002` + `elden_bootloader=esp`）：`grep R65STG` = 0 命中；且随后 sde7/sde40/sde68 三个 8 MiB 分区全查，均无（会话 L2005）。
  - `logfs-beacon.bin`（R65 flashed）同样 0 命中。
- 归因核实（2026-11-10 设备只读实测）：4–16 MiB 区间候选分区**多达 11 个**（5 MiB：uefi_a/uefi_b/tz_a/tz_b；8 MiB：hyp_a/b、bluetooth_a/b、init_boot_a/b、logfs）。R65 代码（`20261109R65-beacon/*.patch`）取**第一个**满足 `(LastBlock+1)*BlockSize ∈ [4MiB,16MiB]` 的 BlockIo 且 `break`，不看内容不看名字 ⇒ 极可能落在 uefi_a(5 MiB) 等非 logfs 分区（当时也没 dump 过这些）。
- 旁证：R66 改内容指纹后**同一条 WriteBlocks 路径立刻成功**（见命题 4）⇒ 写入通道没问题，缺陷在目标识别/选择。
- 结论：成立。严格说「写到非 logfs 的候选分区」与「首候选写入失败」都不能仅凭现有 dump 唯一排除，但 R66 的成功使后者几乎不成立。

## 命题 4：R66 在 fastboot boot 形态命中 `st=8 tag=fallback` ⇒ BdsDxe 走了 fallback、真起内核的是 FV LinuxLoader —— **不成立（前半成立，后半解释错误）**

- 前半（字符串存在）：成立。`logfs-beacon2-fb.boot` @0x7FD000：`R66STG st=8 tag=fallback bs=4096`（xxd 核实）。
- 后半（解释）：**不成立**，两个独立反证：
  1. **st=8 是无条件检查点**：R65/R66 patch 中 `R66Beacon (8, "fallback")` 位于 `if (!Found)` **之前**、LoadImage 尝试之后 —— 无论 ESP-first 成功与否都会写 st=8；"fallback" 只是标签名，不是「走了 fallback」的判据。（另注意检查点表缺 st=6。）
  2. **fastboot boot 后 logfs 记录区（除信标块外）逐字节未变**：`beacon2-fb.boot` 的 0x7FC000 SBLOG 头块与历史基准 cmp 零差异，16 KiB 区差异仅在 0x7FD000。若真走了 fallback → R13StartLinuxLoader → FV LinuxLoader，按 #580 必然重写 logfs（出现 tag=entry/preeb 新记录）—— 没有。
- 结论：fastboot 形态下证据指向**相反方向**：R54 的 ESP-first **成功了**（Found=TRUE，LoadImage 起了 ESP loader），FV LinuxLoader 未参与。会话记录里 L2111–L2118 的「R54 失败、靠 LinuxLoader ESP 路径起内核」的推断是对 st=8 语义的误读，应当修正。

## 命题 5：p66 flashed 后 logfs 无新增 SBLOG 记录 ⇒ 能否判「p66 跑到 st=8」—— **不能判**（且命题的措辞有两处张冠李戴）

- 措辞修正：
  - 「仍只有 1 条 tag=preeb @0x7FC000」描述的是 **p65 flashed** 的 dump（`logfs-beacon-flash.bin`）；p66 flashed 的 dump（`logfs-beacon-p66.bin`）**根本没有记录区**（见命题 6），连「仍有 preeb」都无法评估。
  - 「无新增 SBLOG 记录」本身是**设计使然**：R66 信标不是 SBLOG 格式，且只写 0x7FD000 一个固定块、刻意保留 SBLOG 头。
- R66 写入位置核实（读 patch）：**固定 LBA** = `(Total−16384)/4096 + 1` = 2045（字节 0x7FD000，记录区第 2 块）；内容 = `R66STG st=<n> tag=<tag> bs=4096\n` 补零。位置固定、**内容只随 stage 变化**。
- 核心歧义：`logfs-beacon-flash.bin`（p65 flashed，23:09）里的 `st=8 fallback bs=4096` 与 23:02 fastboot run 写下的**逐字节相同**（两个文件记录区 sha16 同为 234bf434）。固定位置 + 相同内容 ⇒ 无法区分：
  1. flashed run 跑到 st=8 并重写（内容相同）；或
  2. flashed run 完全没跑/在 stage 1 之前就死，st=8 纯属 fastboot run 残留；或
  3. flashed run 跑了但 BlockIo 写入失败。
  只有「跑到 st=1–5 且写入成功」才能与残留区分（会写出更低 st）—— 未观察到，但观察不到 ≠ 没跑。
- **明确回答：这条证据不能判「p66 固件跑到了 st=8」。** p66 的 dump 还截断了，双重不可判。

## 命题 6：logfs-beacon-p66.bin 不是 logfs；/dev/sde68 跨启动不稳定 —— **「不可用」成立；「不是 logfs」的归因不成立；「sde68 不稳定」未证实**

- 尺寸：8 355 840 B ≠ 8 388 608 B ✓；缺的恰好是尾部 32 KiB ⇒ **记录区（0x7FC000+）根本不在文件里**，全盘 grep `SBLOG/R66STG/tag=` 均 0 命中 ⇒ 作为「p66 后的 logfs 证据」不可用 ✓。
- 但「内容不是 logfs（FAT12 'MSDOS5.0'）」这一归因**错了**：logfs 本身就是 FAT12/vfat —— 所有正常 dump（含 logfs-whole.bin）偏移 3 处同样是 `MSDOS5.0`；且 `beacon-p66.bin` 前 4096 B 与 `logfs-whole.bin` **逐字节相同**（同一卷序列号 d27355ea）。该文件是 logfs 的**短读**（ssh/dd 中断，少读 12 个 4096 块），不是别的分区。
- `/dev/sde68` 现状（2026-11-10 ssh 只读）：`by-partlabel/logfs → ../../sde68`，`/sys/class/block/sde68/size` = 16384 扇区 × 512 B = **8 388 608 B = 8 MiB** ✓。现有材料无法证实「跨启动不稳定」：若分区号真漂移，短读文件应带别的卷序列号，实际与 logfs 一致 ⇒ 更像传输中断。判：**不确定（倾向不成立）**，下次 dump 应校验字节数后重试。

---

## 下一发怎么设计才能无歧义（具体到补丁）

核心病灶：R66 信标 = **固定 LBA + 内容只随 stage 变 + 单块覆写** ⇒ 跨 boot 残留不可区分。改 `patches/uefi/20261109R66-beacon2/0001-*.patch` 中 `R66Beacon()`：

1. **每 boot 唯一 nonce + 累积式轨迹**：
   - 静态 `m_R66Log[R66_BUF_SZ]`；新增 `R66BeaconInit()`：读 0x7FD000 块，若前 6 字节 ≠ `"R66LOG"` 则 `ZeroMem` 并写入 `R66LOG boot=<nonce>\n`，否则解析上一条轨迹长度续写。
   - nonce 取 Arm generic timer `GetPerformanceCounter()`（DXE 期必然可用）或 `gRT->GetTime()` 微秒低 32 位 —— 两 boot 相同 nonce 概率≈0。
   - 每个 stage 只做 `AsciiSPrint` 追加 `st=<n> tag=<t>\n` 到 `m_R66Log`，然后把**整块**重写到 0x7FD000。这样一块里就是完整轨迹 + 每 boot 唯一标识： flashed 跑没跑、跑到哪，一发 dump 即可裁决，残留问题消失。
2. **修 stage 8 语义**：把 `R66Beacon(8,…)` 移进 `if (!Found)` 内（或改名 `"tail"`），并新增 `st=9 "esp-ld-ok"` 在 `LoadImage` 成功后 —— 成功/回退从此可判（本次复核证明 "fallback" 标签是误导，且 fastboot 形态实际是 R54 成功）。
3. **双通道冗余**：R67 的屏显 + 10 s hold 保留（拍照片即零依赖证据）；信标块写失败时（`WriteBlocks` 返回非 SUCCESS）把 status 记进 `m_R66Log` 下次再试，别静默丢。
4. **dump 纪律（宿主侧）**：`dd` 后校验 `stat -c%s == 8388608`，不满足立即重试（本次 23:22 的短读浪费了 p66 唯一一发证据）；分析前先 cmp 0x7FC000 头块确认读的是 logfs 本尊。
5. 顺手把 `reports/` 与 PITFALLS #580 相关表述里的「st=8 fallback ⇒ 走了 fallback」更正掉，避免下一轮复核再踩。

## 结论速览

| # | 命题 | 判定 |
|---|---|---|
| 1 | p63 flashed 失败且与 p62 一致 | 成立 |
| 2 | p60 对照 flashed 也失败（锅在 flashed 形态本身） | 成立 |
| 3 | R65 v1 在能跑通的形态下 0 命中；按容量认分区选错 | 成立（「写入失败」备选被 R66 成功旁证压倒） |
| 4 | R66 st=8 fallback ⇒ BdsDxe 走了 fallback | **不成立**（st=8 无条件打印 + logfs 未变 ⇒ fastboot 形态 R54 实为成功） |
| 5 | p66 flashed 无新 SBLOG ⇒ 判「跑到 st=8」 | **不能判**（固定 LBA + 内容同残留；p66 dump 还截断） |
| 6 | beacon-p66 不是 logfs / sde68 不稳定 | dump 不可用成立；「不是 logfs」归因错（是短读）；「sde68 不稳定」未证实（现状 = sde68, 8 MiB ✓） |
