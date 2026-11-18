# 设备恢复自动化两个缺口补齐（A5，2026-11-18，主机侧）

> lane：只改本仓 `scripts/` + 本报告 + RUNBOOK §8 指针。**未接设备、未写任何分区**
> （平板不在线）。所有验证都是 **`bash -n` + dry-run / build-only / 负例**。
> 判据（`RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md:243-250`）：两条命令能把「2 次人工」降为 0。

## 结论（数字）

- 两个脚本都落地：`scripts/linux-gpt-apply.sh`（增强）+ `scripts/esp-apply.sh`（新建，209 行）。
- 离线自测 **8 项全过**，含 3 个负例（表不一致 / 缺必需件 / 镜像内自查失败路径）。

## 1. `scripts/linux-gpt-apply.sh`（写 GPT 双表）

原有能力：`--main/--backup`、从主表头取 `alt_lba`、写主备双表 + 读回 sha256。
本轮补的是「**写前把表本身验一遍**」，因为写错一半的表比不写更贵：

| 新增 | 说明 |
|---|---|
| `--gpt <main>` | A5 口径的别名（与 `--main` 等价）；`--help` 行号同步 |
| `--dry-run` | 显式 dry-run（默认本来就是 dry-run，加了便于脚本统一/自证） |
| 双表校验 | `header CRC` + `entries CRC` + **两表互指**（`primary.alt == backup/my`、`backup.alt == primary/my`）+ **entries 区逐字节相等**；任一不符 ⇒ rc≠0，不写盘 |
| 打印 | 计划里多一行 `表校验 = OK(双表 CRC+互指+entries 一致)` |

自测（真实 dump，`backup/HA2EXB0E-16+512/edl-20261118/`）：

```
$ bash -n scripts/linux-gpt-apply.sh                      → OK
$ scripts/linux-gpt-apply.sh --lun 0 \
    --gpt .../edl-20261118/gpt0-primary.bin \
    --backup .../edl-20261118/gpt0-backup.bin --dry-run
  主表 写入 LBA 0..5            gpt0-primary.bin  24576 B
  备表 写入 LBA 123871227..123871231  gpt0-backup.bin  20480 B
  分区数（新表有效条目）= 16   扇区 = 4096 B
  表校验 = OK(双表 CRC+互指+entries 一致)                 → rc=0
# 负例：bl-stuck 的 primary 配 edl-20261118 的 backup（不是同一对）
  两表 entries 区不一致（备份表不是这张主表的备份）        → rc=1
```

## 2. `scripts/esp-apply.sh`（S5 ESP 组装 + 写 eldenesp）

一条命令 = 查分区 LBA → 必需件校验 → 组装 FAT32 → 镜像内逐文件 sha 自查 → 写 + 读回对账。

| 步骤 | 实现要点 |
|---|---|
| 定位分区 | 从 `--gpt` 的 LUN0 主表（24576 B，LBA0–5）按**名字** `eldenesp` 取 `start / size`，打印 `LBA start..end` |
| 必需件 | `EFI/BOOT/BOOTAA64.EFI`、`EFI/elden/Loader.efi`、`boot/boot.img`、`menu.cfg`；缺件 dry-run 即失败。`grubenv`/`*.pf2` 为可选（缺了 WARN） |
| 镜像尺寸 | `max(--min-mib=64, 内容×1.3)`，**必须是 4096 整数倍**；只写镜像自身占用的扇区，不格式化整个分区（512 MiB 分区只写 64 MiB） |
| 组装 | `mkfs.fat -F32 -n ELDENESP -i 1a2b3c4d`（固定卷 ID ⇒ 可重复组装）+ `mmd` 逐级建目录 + `mcopy` |
| 自查 | 每个文件用 `mtype ::/path \| sha256sum` 与源文件比，任一不符 ⇒ **不写盘** |
| 台账 | 镜像根多写 `/esp-manifest.txt`（逐文件 sha256 + 尺寸 + 时间戳），设备侧/读回件可直接对账 |
| 写盘 | `qdl write <lun>/<start> <img>` 后同会话 `read` 回来比 sha256；不一致 rc=1 |

自测（`reports/artifacts/bl-stuck-20261118/edl-read/gpt0-primary.bin` 是**唯一**还带
`linux17`/`eldenesp` 条目的现成 dump）：

```
$ bash -n scripts/esp-apply.sh                            → OK
$ scripts/esp-apply.sh --esp-dir /tmp/esp-test --gpt .../gpt0-primary.bin --img /tmp/esp-test-out/eldenesp.img
  分区区间 LBA 123609088..123740159（131072 扇区 = 512 MiB）
  镜像 /tmp/esp-test-out/eldenesp.img 67108864 B（64 MiB）写在 LBA 123609088..123625471
  清单 6 个文件（含 fonts/unicode.pf2、grubenv 的 WARN 路径）   → rc=0（dry-run）
$ ... --build-only
  [build] 镜像组装完成  + 6/6 `OK <path> sha=…`              → rc=0
  mdir ::/ 可见 EFI/ boot/ fonts/ grubenv menu.cfg esp-manifest.txt
  mtype ::/esp-manifest.txt 首行 = "# eldenesp manifest …"
# 负例：删掉 boot/boot.img 再 dry-run
  !! 缺必需件 boot/boot.img / 必需件不齐 ⇒ 不组装、不写盘    → rc=1
```

## 3. 依赖与坑（下轮别再踩）

- **mtools 本机原本没装**（`dpkg -l mtools` = `un`）。为不引入 sudo，本轮用
  `apt-get download mtools`（203 kB）+ `dpkg-deb -x` 解到 `~/.local/opt/mtools/`
  （`mcopy/mtype/mdir/mmd` 4.0.49 可用）；脚本默认先查 `PATH`，再查该目录，也可 `--mtools-dir`。
  **换机/重装后要复现**：`cd /tmp && apt-get download mtools && dpkg-deb -x mtools_*.deb ~/.local/opt/mtools`。
- `mmd`（4.0.49）**没有 `-p`**，且**不会建父目录** ⇒ 脚本逐级 `mmd ::/a`、`::/a/b`。
- `mcopy` 的 target 带完整路径可以，但父目录必须先存在，否则 `no match for target`。
- `--img` 传显式路径时脚本会自己 `mkdir -p` 父目录（首轮漏了，已修）。
- 卷 ID 固定为 `1a2b3c4d`，同一源目录重复组装应得到同一镜像（时间戳只进 `esp-manifest.txt`，故 **sha 不会完全一致**；
  要逐字节可复现就改用固定时间戳，本轮未做）。

## 4. 未做 / 边界（如实）

- **未上机**：`--apply` 路径（qdl 写 + 读回）本轮**一次都没跑**；设备不在线，且禁则不碰 fastboot/EDL。
  在上机前它仍是「按现有 `qdl` 用法写的脚本」，不是「已验证的写盘路径」。
- `esp-apply.sh` 不校验 `eldenesp` 分区**当前内容**是否与原厂 ESP 不同；回滚依赖事先手工保存的旧镜像
  （脚本只在失败时打 print，不自动回滚）。
- 未处理 ESP 上的 `attrib`/EFI 启动项（`bcd` 类）；GRUB 的 `grubenv` 只按普通文件复制。
- `linux-gpt-apply.sh` 只做 CRC/一致性校验，不校验「新表与原厂 GPT 的差异是否只落在预期分区」
  （那一步仍由 `scripts/gpt-audit-tb322fc.py --dev --stock` 负责）。

## 5. 上机验收清单（设备回线后照抄）

1. `scripts/esp-apply.sh --esp-dir <dir> --gpt <dump>` → 记下 LBA 区间；`--build-only` 自查全 OK。
2. `scripts/linux-gpt-apply.sh --gpt <main> --backup <backup> --dry-run` → `表校验 = OK`。
3. 设备在 Linux 侧时：`scripts/linux-gpt-dump.sh` 先备份当前表（脚本不替你备份）。
4. 先跑 `linux-gpt-apply.sh --apply`（写 GPT），再 `esp-apply.sh --apply`（写 ESP），各自看
   `OK 读回逐字节一致`；读回件入 `backup/HA2EXB0E-16+512/`。
5. 任一步 FAIL ⇒ 用同名目录里的读回件/旧 dump 回滚，别继续下一步。

收尾: A5 两脚本落地并经 8 项离线自测（含 3 负例），未上机；RUNBOOK §8 已同步指针。
