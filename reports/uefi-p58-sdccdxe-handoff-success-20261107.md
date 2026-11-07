# UEFI p58：**间接引导打通** —— 真因是 `SdccDxe` 抢初始化 SD 主控，不是看门狗

> 线：G1-29。设备 = U2 `HA2EXB0E`。一发 `fastboot boot`，零写盘，`boot_b`/槽位未动。
> 承接 `reports/uefi-p54-p57-wdog-negative-20261107.md`（三条「关看门狗」全证伪 + 「复位不是独立定时器」反证）。

---

## 0. 结论

1. **UEFI 交棒 → 内核跑满 → 用户态，通了**。本次 `fastboot boot` 的镜像就是 p58；
   设备 23:17:56 起（`up 6+ min`）跑在 `elden_bootpath=uefi` 的内核上：

   ```
   $ tr ' ' '\n' </proc/cmdline | grep elden_bootpath
   elden_bootpath=uefi
   $ uname -a        → 7.3.1-debug-vk184-00003-gec74c4795a43  aarch64
   $ uptime          → up 6 min, 2 users
   $ systemctl is-system-running → degraded（唯一失败单元 = 宿主侧 pi-tablet-night.service，与本线无关）
   $ loginctl        → c1 1001 seat0 tty7 yes（桌面会话在位）
   $ ip -br addr     → wlp1s0 UP / waydroid0 UP / usb0 UP
   $ lsblk           → mmcblk0 58.6G（SD 卡）
   ```

2. **真因 = UEFI 的 `SdccDxe` 把 SD 主控（`8804000.mmc`）初始化了、交接时没收拾**：
   - p50–p55 那些死亡现场里 3/6 发最后一行是 `mmc0: ADMA error: 0x02000000`，而且
     `ADMA Ptr: 0x0000000ffffff224`（一个荒谬的物理地址）；
   - 同一内核由 **ABL** 引导时 `mmc0` 一切正常（`new high speed SDXC card @3.96 s`）；
   - p58 只是把 `SdccDxe` 从 FV **真的**摘掉（R46 原本只改 `DXE.inc`，漏了 `APRIORI.inc`/`DXE.dsc.inc`
     ⇒ R53 补齐三处），内核接手时主控是干净的：`mmc0: SDHCI controller … using ADMA 64-bit` →
     `new high speed SDXC card` → `mmcblk0: 58.6 GiB` → **probe returned 0**，没有任何 ADMA 错误。

3. **「看门狗」假设彻底作废**，并且是**在 p54–p57 三路证伪 + fault-handler 自旋 15 min 的反证**之后才排除的：
   那枚「~4 s 就咬」的定时器根本不存在；复位是**内核在 mmc0 上打到坏 ADMA 描述符**之后整机硬复位
   （`PM: Reset by PSHOLD / Hard Reset` + `PM: PON by SYSOK` 只是记录「AP 侧拉低 PS_HOLD」这条路径）。

4. **判据（本轮）**：`scripts/uefi-boot-trial.sh` 直接给 `VERDICT(final)=HANDOFF_TAGGED`
   （`post-OS mode=linux` 且该 boot 的 `/proc/cmdline` **含** `elden_bootpath=uefi`）——
   这是 R43 令牌判据第一次给出「真」的结果。

## 1. 这一发的账

| 项 | 值 |
|---|---|
| 镜像 | `out/r21-sbstop-p58/uefi-preamble58-r1.img`（`d76ede27…`，67 219 456 B） |
| 配方 | `patches/uefi/p58-recipe.txt`（76 补丁 = p54 配方 + R46 + R53） |
| 补丁 | `20261107R46-nosdcc/`（DXE.inc，原本的备料）+ `20261107R53-nosdcc-all/`（APRIORI.inc + DXE.dsc.inc） |
| 构建归档 | `reports/artifacts/uefi-20261107R46R53-p58/`（FV 内 `Ffs/` 与清单已核**无** `SdccDxe`） |
| 上机证据 | `reports/artifacts/uefi-boot-20261107-231716/`、`reports/artifacts/uefi-p58-handoff-success-*/` |
| trial record | `reports/trials/20261107T151955Z-uefi-p58-nosdcc.json`（`verdict=HANDOFF_TAGGED`） |
| 本次内核 cmdline | `… elden_nocamera=1 androidboot.serialno=51318dc0 androidboot.baseband=apq elden_bootpath=uefi initcall_debug` |

## 2. 为什么「只改 DXE.inc」不够（R53）

`SdccDxe.inf` 在这台机的三个清单里都出现过：

| 文件 | 作用 | R46 | R53 |
|---|---|---|---|
| `Device/lenovo-y700g4/APRIORI.inc:75` | APRIORI FV 的文件清单 | — | ✅ 注掉 |
| `Device/lenovo-y700g4/DXE.inc` | 主 FV 文件清单 | ✅ 注掉 | — |
| `Device/lenovo-y700g4/DXE.dsc.inc:41` | `[Components]`（是否编） | — | ✅ 注掉 |

只注 `DXE.inc` ⇒ 它仍被 APRIORI 拉进 FV 并 dispatch，单变量白做。
**纪律**：摘一个 DXE 件，三处都要动（与 p55 摘 `QcomWDogDxe` 同一条）。

## 3. 顺带发现（identity 相关，重要）

本次 UEFI 引导的内核 cmdline 里 **`androidboot.serialno=51318dc0`**，而
`fastboot getvar serialno` 是 `HA2EXB0E`。也就是说：**UEFI 路径写进 cmdline 的序列号不是 Lenovo SN**。
任何「按 `androidboot.serialno` 认机器」的逻辑（含 `PITFALLS #549` 的口径）在 UEFI 引导下都会指错，
要么统一改用 `getvar serialno`，要么把 UEFI 侧填的 serialno 改对。已记 `PITFALLS #555`。

## 4. 稳定性观察

- 23:17:56 起机，至本报告落盘（23:26）已连续运行 8+ min，无复位、无新 `ramoops` 记录；
- `/sys/fs/pstore/` 与 `/var/lib/systemd/pstore/` 均空（本次 boot 没有崩溃记录）；
- 桌面会话（`tty7`）、`wlp1s0`、Waydroid（`waydroid0` + `loop0/loop1`）、SD 卡全在位；
- `dmesg | grep -i watchdog` 只有内核 lockup 检测器的两行老消息，**没有任何 WDT 咬痕**。

## 5. G1-29 剩余项（核心门槛已达成）

- **BDS/GRUB 启动菜单** 与「直接从 FAT/EXT4 读 kernel+initrd」这两项仍未做（原始验收的另一半）；
- 现在仍是 `fastboot boot` 一次性件；要变成「开机就走 UEFI」还得决定落地方式
  （写 `uefi_a` 分区 / 走 BDS 默认项），属**写盘**动作，按 `.pi/AGENT-OPS.md` §2 先备份再动；
- 把 `SdccDxe` 剔除固化进「默认世代」配方（现在只在新世代 p58 里）；
- 顺带查 `SdccDxe` 到底把主控留成什么状态（想上游化就得知道它漏了哪步收尾），
  但这条不影响当前可用性。

## 6. 产物

见 §1 表；另 `reports/artifacts/uefi-p58-handoff-success-*/{onboard-state.txt,dmesg.txt}` 为设备侧当场快照。
