# UEFI 落地：`fastboot boot` 形态 ≠ flash 形态；槽自动回退是真的（2026-11-08 夜一发）

日期 2026-11-08 · 主题 把 Mu 固件写进 flash 的 boot 槽（持久化） · 结论 见下两条

## #571 同一份固件：`fastboot boot` 里 `SimpleFileSystem = 8`，从 `boot_a` 起时只有 `1`

- 动作：`fastboot flash boot_a out/r21-sbstop-p60/uefi-preamble60-r1.img`（67 MB）+ `--set-active=a` + reboot。
- 结果：ABL **确实**跳到我们的件（ABL 日志 `Booting from slot (_a)` → `Loading Image boot_a`），
  固件也跑到 BDS；但 BDS 侧环形日志是
  `[K] esp fs=1` → `[K] esp ld=Not Found i=0` → `[K] esp none`，
  而同一份固件用 `fastboot boot` 起时是 `[K] esp blk=120 / fs=8 / ld=Success i=1`。
  同一个 `[L] found=1 size=0x2E600`（FV 内 LinuxLoader）回退分支随即被走 ⇒ 去读 `boot_a`（= 固件本身）当内核，必失败。
- ⇒ **判据不能跨形态横移**：任何「ESP/分区枚举」结论必须标注是 `fastboot boot` 还是 flash 启动得到的；
  写盘前要假设枚举结果会变。候选解释（未区分）：① 枚举时机/顺序（flash 启动无 USB 传输前摇）；
  ② ABL 传参不同（DTB / `dtbo_a` / 槽相关）。下一轮先加逐句柄 DevicePath + `Stall` 后二次重扫。
- 附带实测：`fs=1` 时**不是** `esp blk` 变少那么简单 —— 扫的是 `SimpleFileSystem`，而它是
  `ConnectController(BlockIo)` 之后才被绑出来的，所以「blk 多但 fs 少」是可能的中间态。

## #572 ABL 的槽回退会自己兜住「boot_a 装了不能起的东西」

- 实测：`slot-retry-count:a` 每失败一次减一，减到 **6** 时被置 `slot-unbootable:a=yes`，
  随后自动 `Booting from slot (_b)`（`slot-successful:b=yes`）⇒ 设备回到能用状态，**不需要人工救砖**。
- 但**没有断电也不行**：本轮 7 次尝试 = 我一次 `reboot` + 用户一次掉电 + ABL 自己的重试
  ⇒ 判据里「一次失败 = 一次重试」不成立，评估风险别按次数算。
- 恢复口径：`fastboot flash boot_a backup/boot_a-pre-uefi-20261108.img`（sha `d4772c11…`，100 663 296 B）
  之后 `slot a` **故意**留 `unbootable=yes`，防误 `set_active a`；要用先显式 `--set-active=a`。
- 纪律：走 boot 槽落地时**永远先 dd 备份该槽**（96 MiB，几十秒），并且 `uefi_a`/`imagefv_a`/`abl_a`/`xbl_a`/GPT 一律不动。
