# UEFI p47 → p49：去掉「写死 fastboot」后能走到跳转点，但「UEFI 交棒内核」仍未证实

> 线：G1-29。承接 `reports/uefi-p46-kernel-boot-success-20261107.md`（**该文「打通」结论已撤回**，
> 见其文首 ⛔ 更正块与 `PITFALLS #549`）。
> 本轮 = **3 发零写盘**（p47 / p48 / p49 各一发 `fastboot boot`），无任何分区/槽/固件写入。

---

## 0. 一句话结论

1. **p46 的「UEFI 间接引导打通」= 未证实，已撤回**（不是「确认误判」）。判据缺陷两条：
   ① 「内核起来」的旁证（主机 USB 事件）**不可归属** —— 同型号机 gadget iSerialNumber 是硬编码常量
   `HA2CB1KY`（`rootfs/usb-gadget:37`），对「哪台机」零信息量；`ssh 192.168.7.1` 也不区分机器。
   ② 唯一「走到跳转」的证据是易失 DDR 环，无法排除「跳转后复位、ABL 自己引导 `boot_b`」。
   详见 `PITFALLS #549`。
2. **R42（删掉漏删的裸语句 `BootIntoFastboot = TRUE`）确实生效**：p47/p48 的持久 logfs 记录里
   `[K] flags fb=0` → `[K] LIA st=Success` → `[K] pre-BL` → `[K] BL-in` → `[K] preeb-go`，
   即 **UEFI 自己走进了 `BootLinux()`，不再需要宿主发 `fastboot continue`**。
3. **p48 的屏上 dump 把「跳转点之后」的判据补全了一半**：`eb-ret st=Success` → `posteb-skip` →
   `EB-OK` → `pph-ok` → `JUMP-BANNER eb=Success` 全链出现 ⇒ 正常路径**能到 `LinuxKernel()` 调用点**。
   但同一发随即 `pc=0` IABT —— **那是 R43 v1 在 EB 之后调 `SbDumpLog()` 造成的**（`gBS` 已失效，
   同 `PITFALLS #543/#546`），不是内核跳转失败。
4. **仍未证实**：「`LinuxKernel()` 交棒后内核能否起来」。p49 已按 v2 修法（EB 后不碰 boot service，
   只保留 cmdline 排他令牌）构建待上机。

---

## 1. 三发的账（全部 `fastboot boot`，零写盘）

| 发 | 件 | 关键改动 | 结果 |
|---|---|---|---|
| p47 | `uefi-preamble47-r1.img`（`e9c1a328…`） | R42 = 删 `BootIntoFastboot = TRUE`（裸语句） | logfs：`flags fb=0` / `LIA st=Success` / `pre-BL` / `BL-in` / `preeb-go` ⇒ 进了 BootLinux；屏灭、USB 消失 |
| p48 | `uefi-preamble48-r1.img`（`ef9ab8dd…`） | R43 v1 = cmdline 令牌 + **跳转前 `SbDumpLog("jump")`** | 屏上全链到 `JUMP-BANNER eb=Success`，随后 `[K] dump-in jump` → `[K] FLT pc=00000000 esr=86000010`（**我方 dump 在 EB 后调 gBS**） |
| p49 | `uefi-preamble49-r1.img`（`15d0b778…`） | R43 v2 = **只留 cmdline 令牌**，删掉 EB 后 dump | **待上机**（设备需物理断电恢复后） |

## 2. p48 的屏上 dump（用户拍照转录，已归档）

见 `reports/artifacts/uefi-20261107R43-p48/screen-dump-p48-fault.txt`。要点：

```
[K] preeb-ok
[K] eb-go
[K] eb-ret st=Success
[K] bb4
[K] posteb-skip
[K] EB-OK st=Success
[K] pph-ok
[K] JUMP-BANNER eb=Success
[K] dump-in jump                       ← R43 v1 新增（EB 之后！）
[K] FLT pc=00000000 esr=86000010       ← IABT：blr 0
[K] x21=E3F04000  x30=CFCCB730 …（寄存器转储）
```

判读：`SbDumpLog()` 内 `AllocatePool` 走 `gBS`；`ExitBootServices()` 已执行 ⇒ 读出 0 ⇒ `blr 0`。
**与 `PITFALLS #543`（NoBs 链里仍在调 boot services）、`#546`（EB 后缓存 BlkIo 失效）同族**。
⇒ 结论：EB 之后只允许 `SerialPortWrite` / 纯内存标记（`SbBbMark`），任何 `gBS`/`BlkIo` 都会自杀。

## 3. 排他判据（R43 v2，p49 起生效）

`UpdateCmdLineParams()` 里先按 `CmdLineLen + len(tag) + 1` 扩容，再在末尾追加 ` elden_bootpath=uefi`：

| 现象 | 判定 |
|---|---|
| 内核起来且 `/proc/cmdline` 含 `elden_bootpath=uefi` | **UEFI 交棒成立**（ABL 引导不会出现该串） |
| 内核起来但没有该串 | 不是 UEFI 交棒（多半是 ABL 自己引导） |
| 不起来、屏上到 `JUMP-BANNER` 后黑 | 崩在 `LinuxKernel()` 之后（内核侧早期），需另立判据 |
| 不起来、屏上到不了 `JUMP-BANNER` | 崩在 `BootLinux` 前段/PPH |

静态复核（p49 构建产物）：`strings LinuxLoader.efi | grep elden_bootpath` 命中；
`grep -c jump-dump-ok` = 0（v1 的 dump 已删干净）。

## 4. 设备安全账

- 三发全是 `fastboot boot`（RAM 载荷），**`boot_b` 与槽位未动**（仍 `vk185-adsp`、`retry=7 succ=1`）。
- **副作用（新）**：R42 之后 UEFI 不再无条件进 fastboot ⇒ 失败时不再有「`fastboot continue` 可用」
  这条兜底；恢复路径 = 长按电源断电后正常开机（ABL 引导 `boot_b`）或键组合进 ABL fastboot。
- p47/p48 两次失败后设备均需**用户长按电源键 15–20 s** 恢复（agent 无法代做）。

## 5. 产物

| 项 | 路径 |
|---|---|
| 补丁 | `patches/uefi/20261107R42-normalboot/0001-drop-orphan-bootintofastboot.patch`、`patches/uefi/20261107R43-bootpath-proof/0001-bootpath-cmdline-tag.patch`（v2） |
| 配方 | `patches/uefi/p47-recipe.txt`（68）、`p48-recipe.txt`（69，v1 已作废）、`p49-recipe.txt`（69） |
| 镜像 | `out/r21-sbstop-p47/`、`out/r21-sbstop-p48/`、`out/r21-sbstop-p49/` |
| 构建归档 | `reports/artifacts/uefi-20261107R42-p47/`、`uefi-20261107R43-p48/`、`uefi-20261107R43b-p49/` |
| 持久证据 | p47 logfs 读回 `reports/artifacts/uefi-20261107R42-p47/logfs-read-after-p47.txt`；p48 屏上 dump（同目录 `uefi-20261107R43-p48/screen-dump-p48-fault.txt`） |
| 坑 | `PITFALLS #549`（判据归属/易失证据）、`#546`（EB 后 boot services） |

## 6. 下一发（p49，待设备恢复）

`fastboot boot out/r21-sbstop-p49/uefi-preamble49-r1.img`，**不发 `continue`**，30 s 后：

```bash
fastboot devices                      # 空 = 没停在 ABL fastboot
ssh root@192.168.7.1 'cat /proc/cmdline | tr " " "\n" | grep elden_bootpath'
```

判读按 §3 表；若起来但无令牌 ⇒ 必须按 SN 复核 USB 归属（`PITFALLS #549`），不得直接下结论。
