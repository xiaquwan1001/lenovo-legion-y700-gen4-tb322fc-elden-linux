# p61（R62 ESP 重扫）flashed 形态上机一发：仍 `fs=1`，`fs2=` 标记未出现（2026-11-09）

- 结论 **负结果**（不是崩砖）：`boot_a` 换成 p61 后 ABL 认件并跳到它，UEFI 跑起来、R54 的 ESP 尝试照旧
  `[K] esp fs=1` → `[K] esp ld=Not Found i=0` → `[K] esp none`，随后回退 FV loader 读 `boot_a`（=固件本身）当内核失败，
  一次 PSHOLD 硬复位后 ABL 切回 `_b`。**R62 的判据行 `[K] esp fs2=` 在整份 logfs 里 0 命中**。
- 设备已完全恢复：`boot_a` 回灌 `backup/boot_a-pre-uefi-20261108.img`（`d4772c11…`）、`slot` 回 `_b`、
  `boot_b` `mark-successful`（retry 6→7）、`boot_b` sha 全程 `4e38bc2c…` 未变、`uefi_a/imagefv_a/abl_a/xbl_a/GPT` 未动。

## 1. 动作与时间线（原始记录在 `reports/artifacts/uefi-p61-flash-20261109/`）

| 步骤 | 证据 |
|---|---|
| 前置态 | `pre.txt`：`7.3.1-debug-vk184-00003`、`slot_suffix=_b`、`boot_b` sha `4e38bc2c…`、`boot_a` `retry=7 succ=0 unbootable=0` |
| 进 fastboot | `eldroid-bootctl reboot bootloader` → `fastboot devices` = `HA2EXB0E`，`product: elden_prc_wifi`（`fbdev.txt`） |
| 刷写 | `fastboot flash boot_a out/r21-sbstop-p61/uefi-preamble61-r1.img`（`Sending 65620 KB OKAY`，`flash.txt`） |
| 切槽/重启 | `--set-active=a` + `reboot` |
| 现场观感（用户） | **联想 logo 很短 ⇒ 掉电 ⇒ 第二次上电**（= UEFI 走到失败点后整机复位，ABL 重新上电并换槽） |
| 起来 | 24 s 后 SSH 可用，但 `uname -r` = `…vk184-00003`、`slot_suffix=_b` ⇒ **起的是 `boot_b`**（`wait.txt`/`post.txt`） |
| 固件日志 | `abl-log.txt`：`PM: Reset by PSHOLD` + `PM: PON by SYSOK`（= 上一发是一次硬复位）；`dd /dev/sde68` 的 8 MiB 全量 → `SBLOG01 tag=preeb len=8192` 段 |
| 回滚 | `flash boot_a backup/boot_a-pre-uefi-20261108.img`（`restore.txt`）→ `--set-active=b` → `boot_b` 起来后 `mark-successful b`（`0x77→0x7f`） |

**刷进去的件是 p61，已用读回逐字节证明**：
`dd if=/dev/disk/by-partlabel/boot_a bs=4096 count=16405 | head -c 67194880 | sha256sum` = `b8a87c0d…` = 主机件。
（踩坑：先用 `bs=1M count=64` 读 ⇒ 少 8192 字节，误判「刷进去的不是 p61」；见 `PITFALLS #575`。）

## 2. 判据读数（logfs 里 `tag=preeb` 段，按出现顺序）

```
[K] esp fs=1
[K] esp ld=Not Found i=0
[K] esp none
[L] found=1 size=0x2E600      ← 回退 FV 内 LinuxLoader
[L] LoadImage=Success
[L] cpu-hook=ok
[K] cmdline len=308 tag=1 tail=… elden_bootpath=uefi …
[K] preeb-go
```

- **`fs2=` 0 命中**（全 8 MiB logfs 都搜过），而按补丁它应在 `fs=1` 之后**无条件**打印（`Count < 2` 成立）。
- `[K] esp blk=` 这一行也不在（它是同一函数里更早的一行）⇒ 8 KiB 环形窗口**把最早的行挤掉了**
  （`PITFALLS #575`）⇒ 本轮的「存在性判据」只能用于**在窗口内更靠后**的那些行。

## 3. 能得出的结论 / 不能得出的结论

- **能**：flashed 形态下 ESP 仍然找不到（`fs=1`），路线 B 的落地缺口**没有**被这一发修好；失败链与 11-08 那一发同型
  （`#571/#572`），ABL 自动兜底、无需救砖。
- **不能**：不能断言「ConnectController + Stall + 重扫无效」—— 因为 R62 的标记行没出现，存在两种解释：
  ① 补丁没进被执行的那份 BdsDxe；② 分支没被执行（理论上 `Count<2` 必成立）。
  两解释都要求下一发先给**函数入口无条件标记**（例如 `[K] esp in n=<Count>` 放在 `R54TryEspBoot` 第一行），
  再谈 R62 有效无效。

## 4. 下一步（主机侧，已按报告 §4 的顺序重排）

1. **先验「补丁确实进了执行的二进制」**：给 `R54TryEspBoot` 入口加一行无条件标记，出新世代 `p62`
   （`p62-recipe.txt = p61 + R54marker`），**零写盘 `fastboot boot` 一发**即可看到该行（fastboot 形态 `fs=8`，
   不影响原判据）——这一步不需要再写 `boot_a`。
2. 若入口标记出现而 `fs2=` 仍不出现 ⇒ R62 的插入点/条件有问题，改在**入口**做重扫；
   若入口标记也不出现 ⇒ 打印通道/编译落点问题，先解决「代码在不在」。
3. 上面成立后再考虑报告里那条根治路线（按 GPT 名 `eldenesp` 找 `BlockIo` → 手工读 FAT 引导扇区，绕开 `SimpleFileSystem` 枚举）。

## 5. 原始件

- `reports/artifacts/uefi-p61-flash-20261109/`：`pre.txt` `fbpre.txt` `flash.txt` `wait.txt` `post.txt`
  `abl-log.txt`（原始，含 NUL）`abl-log.clean.txt` `logfs-whole.bin`（8 MiB）`restore.txt`
- 坑：`PITFALLS #575`（logfs 环形窗口会挤掉最早行 + `dd bs=1M` 读回少 8 KiB 的误判）
