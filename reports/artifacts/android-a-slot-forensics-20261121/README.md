# a 槽取证归档（2026-11-21，只读 lane）

原件在 `logs/a-slot-forensics-20261121/`（`logs/` 被 .gitignore，大件不入库）；这里只放**小而确定**的判据件。
两个目录同名同 sha；`SHA256SUMS.txt` 只覆盖本目录。

| 件 | 字节 | 用途 |
|---|---|---|
| `super-head512k.bin` | 524288 | 在机 super 首 512 KiB（v1 指纹 `67ff7604…`；v3=`c6278f8e…`、原厂=`12c35980…`） |
| `misc-full-1M.bin` | 1048576 | misc 全量（`[0:32KiB]` 全 0；`0x8000` 5 B；`0x8080`/`0x80C0` 已被零化） |
| `userdata-head4k.bin` | 4096 | `/data` ext4 超级块块（`s_mnt_count=0`、`mkfs=2026-11-19T13:16:23Z`、无 `encrypt`） |
| `uefilog1-current.txt` | 65536 | logfs 的**活** 64 KiB 记录（b 槽 boot；判"logfs 只留一次启动"） |
| `gpt0-primary-lba0-33.bin` | 139264 | LUN0 主表（保护 MBR + GPT 头 + 32 项） |

**不入库的大件**（在 `logs/a-slot-forensics-20261121/`）：`logfs-now.bin`（8 MiB）、
`metadata-64M-pristine.bin`（64 MiB，`3f4934ee…`）、`metadata-64M.dumpf2fs-mutated.bin`（被 `dump.f2fs` 改过，反面教材）、
`super-tail4M.bin` / `metadata-tail4M.bin`（各 4 MiB，全零）、`abl_a.bin`（1 MiB，与原厂 `abl.elf` 同 sha）。

纪律：`dump.f2fs` **会写它 dump 的镜像**，取证件先复制；O_DIRECT 口径（`scripts/odirect-sha.py`）才作数。
