# UEFI flashed 形态重判（2026-11-10 下午/晚）：计时判据失效、logfs 盲区、**金标准对照把矛头指到 `vbmeta_a`**

> ⚠ **已被 2026-11-10 深夜的 `reports/uefi-dtbo-a-rootcause-20261110.md` 取代**：本报告的根因假设（`vbmeta_a` 校验失败）
> 与 logfs 判据解释均已被否证，真根因 = **`dtbo_a` 的 Android DTBO overlay**（清掉后 p69 写 `boot_a` 直接闭环）。
> 保留本文件作「被推翻的记录」，勿据此继续实验。


> 设备 U2（`HA2EXB0E`）。件：`p69` = `p68` + `20261110R70-prepi-timing`（PrePi `[P00]`/`[P08]`/`[P10]` 各停 25 s），
> 镜像 `out/r21-sbstop-p69/uefi-preamble69-r1.img`（`38202e129af58cc9d20881115de192d5f988e05e08ed50a39992a761940c4fcc`，67 194 880 B），
> 归档 `reports/artifacts/uefi-20261110R70-p69/`，复现 `scripts/uefi-r21-p7-ladder.sh --gen p69 --mkimg-only --rebuild`。
> 上机工具 `scripts/uefi-flashed-trial.sh`（本轮新建）。取证目录 `reports/artifacts/uefi-flashed-20261110-*`。

## 0. 一句话

**「flashed 形态我们的固件没跑到 BdsDxe」仍然成立，但它的上游原因被本轮换掉了**：同一份 `boot_b` 镜像
**逐字节**刷进 `boot_a` 也起不来，而两种失败形态（掉电 / 无缝回 bl）指向**两条不同的 ABL 分支**；
`avbtool` 取证给出唯一已知的槽位级差异 —— **`vbmeta_a` Flags=0（校验开启、原厂哈希）而 `vbmeta_b` Flags=3（校验关闭、我方密钥）**。

## 1. R70「计时判据」：成立为正控，**失效为反证**（本轮最重要的方法论纠正）

| 形态 | 件 | 到 SSH 可用 | 相对 |
|---|---|---|---|
| `fastboot boot`（零写盘） | p67（无停留） | **54.5 s** | 基线 |
| `fastboot boot` | p69（3×25 s 停留） | **128.7 s** | **+74.3 s ≈ 75 s ⇒ 三个停留确实执行** |
| 写 `boot_a` | p67（对照） | **28.9 s** | 基线 |
| 写 `boot_a` | p69（3×25 s 停留） | **28.8 s** | **+0 s** |

- 「`fastboot boot` +74 s」证明**仪器是好的**（`MicroSecondDelay` 在早于库构造函数的 `[P00]` 也生效）。
- 但「flashed +0 s」**不能**推出「代码没跑」：这一发是**硬复位**（用户实测：logo 一闪 → 掉电），
  复位会把 25 s 停留**整段剪掉**，总耗时自然回到基线。⇒ **计时只能作正控，不能作反证。**
- 顺带测出失败发寿命：`set_active b` 后直接 `fastboot reboot` 到 SSH 只要 **≈18 s**，
  而 flashed 试验是 **28.8 s** ⇒ **失败那发消耗 ≈10 s**。这个数正好复现旧记录里 `[3806]BootLinux → [12984]` 的 9.2 s，
  但它**不是**「一次启动里的回退空窗」，而是**一发失败尝试的完整寿命**（见 §2 的记录更正）。

## 2. logfs 的盲区：它**看不到**失败那一发，而且本轮被误读过

- 每发试验前后各抓一次整分区 8 MiB（`logfs-pre.bin` / `logfs-post.bin`，sha 见各目录 `logfs-sha256.txt`）：
  **只有 slot0（前 64 KiB）变化**，其余逐字节相同；而 slot0 的内容是**成功那发 `_b`** 的记录
  （`Booting from slot (_b)` … `Start EBS [13423]`）。**`_a` 的失败尝试没有留下任何记录。**
- **记录数量与版本的更正**：本轮早先把 `reports/artifacts/uefi-p67-trial-20261110/logfs-p67-flashed.bin`
  数成「2 条记录、`[3806]` 与 `[12984]` 属同一次启动」——实为 **10 条**；且 blk1–blk9 的
  `UEFI Ver = 6.0.250606…` 与当前固件 `6.0.260611…` 不同 ⇒ **那 9 条是旧固件的历史记录，不是本轮任何一发**。
  ⇒ `reports/uefi-p67-flash-trial-20261110.md` §3 的时间线（「~9 s 空窗后回退 `_b`」）**作废**，判读按本节。
- **`oem sbread` 在 stock fastboot 里不存在**（`FAILED (remote: 'unknown command')`；两种调用形式都试过）——
  它是**我们自己 UEFI** 的 host-visible diag 命令 ⇒ **在 bl 里读不到 logfs**，只有回到 Linux 才能 `dd`。
- 因此「写标记 → 尝试 → 读回」的探针**在本机走不通**（读的时刻只能是在 bl，而 bl 读不到）；
  且**恢复动作（`set_active b` + `reboot`）会先把 slot0 覆盖掉** —— 本轮两次踩到，证据两次丢失。
  ⇒ 纪律：**失败发之后，先在设备侧留下 logfs 副本，再恢复设备**（`PITFALLS #594`）。

## 3. 金标准对照：`boot_a` == `boot_b` 也起不来，但**死法不同**

对照件 = 直接从设备读回的 `boot_b`（`4e38bc2cd46a45b9…`，100 663 296 B，存 `backup/boot_b-live-vk184-20261110.img`），
原样刷入 `boot_a` 后两槽**逐字节相同**：

| 件 | 现象 | 槽位记账 |
|---|---|---|
| 我们的 Mu payload（p67/p69） | logo 一闪 → **掉电** → 再开机 → `_b` | `retry 7→6`，**`unbootable=1`** |
| 金标准 mainline（= `boot_b` 内容） | 正常「解锁」警告（5 s 自续，用户实测未按键）→ **无缝回 bl，不掉电**（≈16 s） | `retry 7→6`，**`unbootable=0`** |

- 「无缝回 bl 不掉电」= **软复位**特征；「掉电」= **硬复位**特征 ⇒ 两条不同的死法，不能混谈。
- `/sys/fs/pstore` 为 **空** ⇒ 该发没有内核崩溃转储（ramoops 未写），偏向「内核没起来」而非「起来后崩」。
- 配套分区两侧都有内容（非空分区）；`vbmeta/dtbo/pvmfw/init_boot/vendor_boot/recovery` 的 `_a` 与 `_b` 哈希都不同（槽位专属，正常）。

## 4. `avbtool` 取证：槽位级差异只有一处 —— `vbmeta_a` 与 `vbmeta_b` 的 **Flags**

```
vbmeta_a: key sha1 8fcb864f11f53ed11284615fb67685522085d3a2  Aux 8000  Flags 0
          Chain: boot / recovery / vbmeta_system（同 key）+ 原厂 Lenovo props（ZUXOS_1.5.10.259_260611_PRC）
vbmeta_b: key sha1 fc1e3b33f76b269c5ad5e570a4f776eb8701f24d  Aux 2368  Flags 3   ← VERIFICATION_DISABLED|HASHTREE_DISABLED
          Chain: boot（我方 key）+ Hash descriptor（dtbo）
```

- `_b` 每次启动都有一行 `avb_slot_verify.c:913: ERROR: vbmeta_b: Public key used to sign data rejected.`，
  然后**照常** `Load Image boot_b` → `BootLinux` → `Start EBS` ⇒ **`_b` 是「校验被关闭/公钥被拒」被放行**。
- `_a` 的 `vbmeta_a` **仍是原厂签名**、且记录的是**原始 `boot_a` 的哈希**；我们把 `boot_a` 换成别的镜像后，
  它走的是「**哈希不匹配 = 校验失败**」分支（用户看到的 5 s 警告即该分支的提示）⇒ **不交棒**。
- ⇒ **根因假设（本轮唯一自洽的解释）**：flashed 线所有失败（p60 对照件、p61–p66、p67、p69、以及金标准件）
  都先卡在 **`vbmeta_a` 校验失败**这一步；「我们的件跑到哪」这个问题**在通过这一步之前无法回答**。
- 佐证：金标准件（内容与我们 payload 无关）在 `_a` 上同样失败 ⇒ **失败与我们的固件无关**（与 `PITFALLS #588` 一致）。

## 5. 工具（本轮新建/修正）

- **新建 `scripts/uefi-flashed-trial.sh`**：锁目标（`SER` 或 `product` 唯一匹配）→ 前置态（uname/cmdline/分区 sha/槽位属性）+
  logfs 快照（**短读重试 3 次**）→ Linux→fastboot（**可见轮询**，每 3 s 一行）→ `flash boot_a` → `set_active a` →
  `t0 = fastboot reboot` → 轮询 SSH（**一有响应即返回**）→ 后置态 + `timing.txt` + `verdict.txt`。
- `scripts/uefi-r21-p7-ladder.sh`：新增 `--gen p69`；修 **`_out` 从未被使用**（p69 的件曾默默落进 `out/r21-sbstop/` 与 p7 混放）。
- 坑：`fastboot devices` 每行是 `SN\tfastboot` 两列，直接 `read -r ser` 会拿到整行（`PITFALLS #597` 同族）；
  重启后 `/tmp/slot-attr.py` 消失需重推；ssh 不包 `timeout` 会卡到 `tcp_retries2`（`#585` 复发）。

## 6. 下一步（按代价）

1. **验证 §4 假设**：备份 `vbmeta_a`（64 KiB）→ 用 `tools/avbtool.py` 造一个 **Flags=3 / 我方 `bootslot-b/avb.key`** 的 `vbmeta_a`
   → 刷入 → `set_active a` + 重启，看是否从 `_a` 起到 Linux。若通 ⇒ flashed 线当场跨越「不交棒」这道墙，
   后续才是「我们的件跑到哪」。
2. 若 (1) 仍不交棒：把**同一条**验证做在 `_b` 上（刷同样的 vbmeta 风格）作为正控，确认「Flags=3 是被放行的原因」。
3. 通过 (1) 后再回到 p67/p69 的信标路线（此时 `_a` 才可能真的跑到 BdsDxe）。
