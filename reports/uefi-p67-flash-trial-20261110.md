# UEFI p67 上机：信标 v3（R68）——**flashed 形态连 BdsDxe 都没跑到**

> 世代 `p67` = `p66` + `20261110R68-trace`（信标 v3）。配方 `patches/uefi/p67-recipe.txt`（82 条）、
> 归档 `reports/artifacts/uefi-20261110R68-p67/`、镜像 `out/r21-sbstop-p67/uefi-preamble67-r1.img`（`d69b06e6…`）、
> 复现 `scripts/uefi-r21-p7-ladder.sh --gen p67 --mkimg-only --rebuild`。
> 取证目录 `reports/artifacts/uefi-p67-trial-20261110/`。设备已回滚（`boot_a`=`d4772c11…`，`active=_b`）。

## 0. 一句话

**同一份件**：`fastboot boot` 形态信标写出 **`s1 bds-in → s2 r54-in → s3 blk-enum → s4 blk-conn → s5 fs-enum → s9 esp-ld-ok`**（全链成功）；
**写进 `boot_a` 后信标一个字节都没变** ⇒ 我们固件**根本没执行到 BdsDxe**，失败点在更早的阶段（PrePi/DXE dispatch 或 ABL 侧的装载/跳转），
**不是**「flashed 形态下 ESP 枚举不到」——那条旧口径（p61/p62 起的「`fs=1`」）**没有一次是被本机证据直接证实的**。

## 1. R68 干了什么（判据终于不自欺）

| 缺陷（v2/R66） | R68 修法 |
|---|---|
| 写入位置与内容固定 ⇒ 读到 `st=8` 分不清「本发写的」还是「上一发残留」（`#586`） | 首次调用**清零 + 写头** `R68LOG n=<单调计数> b=<YYYYMMDDhhmmss> bs=<n>`，其后每 stage **追加** `s<n>:<tag>` 整块重写；`n` 从上一发读回 +1 ⇒ 任何一次写入都让 `n` 增长 |
| `R66Beacon (8, "fallback")` 在 `if (!Found)` **之前**（无条件，`#589`） | 移进 `if (!Found)` 并改名 `notfound`；`LoadImage` 成功后新增 `s9 esp-ld-ok` |
| `R66IsLogfs()` 与轨迹**共用** `m_R66Buf`（每次识别分区就把轨迹清掉，首测只留最后一个 stage） | 轨迹独立 `m_R68Buf` |

判读（Linux 侧）：`dd if=/dev/disk/by-partlabel/logfs bs=1M | grep -a R68LOG`，**先校验 dd 字节数 = 8 388 608**（`#587`）。

## 2. 两发对照（同日、同件、只差启动形态）

| | `fastboot boot`（零写盘） | 写 `boot_a`（flashed） |
|---|---|---|
| 结果 | 进桌面，`uname` = `vk184-00002`、cmdline 含 `elden_bootloader=esp` | 联想 logo 一闪 → 掉电 → 再亮 logo → 进 `boot_b`（`vk184-00003`）；`boot_a` `retry 7→6`、`succ=0 unbootable=1` |
| 信标 | `R68LOG b=20190100000053 … s1:s2:s3:s4:s5 **s9:esp-ld-ok**` | **与上一发的字节完全相同**（`b=` 同值、无 `n=`） |
| 读法 | R54 的 ESP-first **成功**（找到 SFS 卷、`LoadImage` 起 ESP loader） | 该发**没写任何信标** ⇒ BdsDxe 没执行 |

- 关键点：flashed 那一发用的是**带 `n=` 的 p67 最终件**，而读回内容里**没有 `n=`** ⇒ 不是「写了同样内容」，而是**根本没写**。
- 旁证：`fastboot boot` 那发的 logfs `SBLOG01 tag=preeb` 记录**未变** ⇒ 该形态下 FV `LinuxLoader` 没参与
  ⇒ 与独立复核（`reports/beacon-recheck-20261110.md` §命题 4）一致，**R54 ESP-first 是真通的**。

## 3. ABL 侧看到了什么（logfs 里的 `[<ms>]` 文本）

```
 2571 Booting from slot (_a)
 2767 Loaded Partition: boot / pvmfw
 3801 ERROR: Failed to set keys detection Timer: Invalid Parameter
 3806 BootLinux: factory_build = 1
 3806 Failed to add memory space :0x8088F000 0x1000
 3807 DP DTB: No Valid DTB in image
 3814 Override DTB: GetBlkIOHandles failed loading user_dtbo!
 3990 Apply Overlay total time: 176 ms
 4012 Final RAM Partitions
 4081 Update Device Tree total time: 70 ms
        ← 约 9 s 空白（我们的件在此窗口内跑/死）
12984 BootLinux: factory_build = 1        ← 第二次 = 回退到 _b
```

- ABL **确实**为 `_a` 走了 `BootLinux`（不是「没认这个分区」），随后有 ~9 s 的空窗，再走 `_b`。
- 两发都出现 `Failed to add memory space :0x8088F000 0x1000` / `DP DTB: No Valid DTB in image` /
  `Override DTB: … user_dtbo!` ⇒ 这三条**不是**我们的特有症状（`_b` 正常启动那发也有），不能当根因。

## 4. 结论与下一步（按代价排序）

**结论**：flashed 失败点位于 **BdsDxe 之前**。旧的「flashed 形态 ESP 枚举 `fs=1`」是 11-08 一次**屏读**留下的口径，
本轮首次有持久化证据，且证据说反了 —— 真正没发生的是「我们的固件跑到 BdsDxe」。

1. **把信标搬到最早阶段**（最便宜、最决定性）：`BootShim`/`PrePi` 里加同一套 `R68LOG` 写入（PrePi 已有 `[P01]…[P11]`
   屏上标记的补丁栈，可直接复用）；若 flashed 形态连 PrePi 标记都没有 ⇒ 问题在 BootShim 装载/跳转；
   若有 PrePi 标记但没有 BdsDxe 标记 ⇒ 问题在 DxeCore/dispatch（`UFSDxe`/`QcomWDogDxe` 之类）。
2. **屏上肉眼确认**（零成本，下次上机顺手做）：flashed 发里**是否出现过 `[P01]…` 那几行字**（不是只有联想 logo）。
3. **载荷尺寸假设**：我们的 `boot_a` 件 65 620 KB（UEFI preamble 4 MB + 内核/initrd）。第三方同机型（`retro98boy`）
   的 flashed 件带 **AVB footer**；可先试「把 payload 缩到最小（空内核段）」看 ABL 是否就不再回退 —— 能一刀切开
   「ABL 装载/校验」与「我们的固件早期阶段」。
4. 与 `#13`（UFS 修法）/ `StorageConnect.c` 相关的补丁**暂时都不是嫌疑**：它们都在 BdsDxe 内部，而 BdsDxe 没跑到。

## 5. 工具侧（本轮新增）

- `scripts/lib-fastboot.sh` 增 `wait_ssh_up [max_s] [iv_s]`：**一有响应就返回**（用户 2026-11-10 要求，别按固定时长空等）；
  每次探测都是独立短 ssh（`ConnectTimeout=2`），板子重启中途也不会卡到 `tcp_retries2`（`#585`）。
- `scripts/uefi-r21-p7-ladder.sh`：`--gen X --rebuild` 曾被「预置 BUILD_DIR」静默吃掉（只报「变体目录不存在」）⇒ 已修（`#590` 同族）。
- 坑 `#586`（固定 LBA 信标不能自证）、`#587`（dd 先验字节数）、`#589`（无条件检查点）、`#590`（等待循环自匹配 + 后台任务被连坐）、
  `#591`（信标与分区识别共用静态缓冲 ⇒ 轨迹被自己清掉）。

## 6. 备料：p68 = p67 + R69（PrePi 分级上屏停留，**已构建、未上机**）

BdsDxe 之前没有可用的持久化通道（`BlockIo` 要等 DXE 把 `UFSDxe` dispatch 完才存在），所以这一轮把判据交给**屏**：

| 屏上看到 | 结论 |
|---|---|
| 只有联想 logo（无 `[P00]`） | 我们的件**根本没进 PrePi**（ABL 侧装载/跳转，或 BootShim 就死） |
| `[P00]` 停 6 s 后黑掉 | 进了 PrePi，死在 PrePi 内部（看停在哪一级 `[Pxx]`） |
| 走到 `[P10]` | FV 解压完成，还没进 DxeCore |
| 走到 `[P11]` | DxeCore 已装载并交棒 ⇒ 问题在 dispatch（到 BdsDxe 之间） |
| 又出现 `R68LOG s1:bds-in` | 与 2026-11-10 结论矛盾，需重测 |

- 补丁 `patches/uefi/20261110R69-prepi-hold/0001-prepi-stage-hold.patch`：`CEntryPoint()` 起手 `SbMark("[P00]")` +
  `MicroSecondDelay(6 s)`；`[P10]`/`[P11]` 各停 3 s（共约 +12 s/次启动，定位完即摘）。
- 配方 `patches/uefi/p68-recipe.txt`（83 条）、`--gen p68` 已绑；归档 `reports/artifacts/uefi-20261110R69-p68/`；
  件 `out/r21-sbstop-p68/uefi-preamble68-r1.img`（`66bd4bab…`，67 194 880 B）；`[P00]` 字串已在 FD 内层（`grep -ac` = 1）。
- **状态：仅备料，未上机、未写盘**。回归 = 改用 `--gen p67`。
