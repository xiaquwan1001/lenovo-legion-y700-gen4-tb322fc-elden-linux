# G1-29 flashed 形态真根因 = `dtbo_a`（Android DTBO overlay），不是 `vbmeta_a`；flashed 形态已打通

- 日期：2026-11-10（同日第四段，接 p69/R70 那条「vbmeta 假设」之后）
- 设备：U2（`HA2EXB0E`，256 GB / 12 GB，SM8750P_12+256_12）
- 结论：**flashed 形态（写 `boot_a`、`active=a`）可以起 Linux，且可以起我们的 UEFI 从 ESP 载内核**；
  之前 p60–p69 与「金标准对照」的全部失败 = **ABL 把 `dtbo_a` 里的 Android DTBO overlay 套到我们的 Linux DTB 上**，
  **不是** `vbmeta_a` 校验、**不是** 我们的固件跑到哪、**也不是** ESP 枚举。

---

## 0. 一句话判据表

| 实验 | `dtbo_a` | `vbmeta_a` | `boot_a` 内容 | 起法 | 结果 |
|---|---|---|---|---|---|
| A（本日前半段，已推翻的解释） | Android DTBO | Flags 3（我方 key） | = `boot_b` 逐字节（`4e38bc2c…`） | `fastboot reboot` | **回 fastboot / 卡 logo** |
| B | Android DTBO | 原厂 Flags 0 | 原厂 Android 件（`d4772c11…`） | `fastboot reboot` | ✅ 原厂 Android 16 起（`_a`, boot_completed=1） |
| C | Android DTBO | 任意 | 我们的 Linux 件 | `fastboot boot`（active=a） | ❌ **卡联想 logo**（用户目视） |
| D | **全 0** | Flags 3 | 我们的 Linux 件 | `fastboot boot`（active=a） | ✅ Linux **34 s** 起 |
| E | 全 0 | Flags 3 | `boot_a` = 带 `elden_bootmark=a` 的 Linux 件 | `fastboot reboot`（flashed） | ✅ **27 s**，cmdline 有 `elden_bootmark=a` ⇒ 确实从 `boot_a` 起 |
| F（负控） | 全 0 | **原厂 Flags 0** | 同 E | flashed | ✅ **29 s** 起 ⇒ **Flags=3 不是必要条件** |
| G（正题） | 全 0 | 原厂 Flags 0 | **p69 UEFI**（`uefi-preamble69-r1.img`, `38202e12…`） | flashed | ✅ **129.2 s**；logfs 信标 `n=3 s1:bds-in s2:r54-in s3:blk-enum s4:blk-conn s5:fs-enum s9:esp-ld-ok`；落地 `elden_bootloader=esp` + 内核 `vk184-00002-g4da9a8b69fc8` |

实验 D/E/F/G 的取证目录：`reports/artifacts/uefi-dtbo-a-blank-20261110/`、`uefi-flashed-20261110-174041-bootmark-a-discriminator/`、
`uefi-flashed-20261110-174233-ctrl-vbmeta-a-orig-flags0/`、`uefi-flashed-20261110-174442-p69-flashed-dtbo-blank/`、
`uefi-slot-a-stock-android-20261110/`、`uefi-slot-a-ramboot-context-20261110/`、`uefi-fastbootboot-control-20261110/`。

## 1. 机理

ABL（stock，`UEFI Ver 6.0.260611`）在 `BootLinux` 之后、交棒之前会做 **`Apply Overlay`**：
把 `dtbo_<slot>` 的 overlay 合并进它手里的 DTB。原厂 `dtbo_a` 是**合法 Android DTBO**
（magic `D7B7AB1E`、`total_size` 23 348 092 B），`dtbo_b` 早在 2026-10-03 就被本项目写成全 0（「假 dtbo」）。

- `_b` 的 ABL 日志：`Dtbo hdr magic mismatch 0, with D7B7AB1E` → `ApplyOverlay: ufdt apply overlay failed` → **容忍、继续**；
- `_a` 的 ABL 日志：`Load Image dtbo_a total time: 12 ms` → `Apply Overlay total time: 175 ms`（**真的合并成功**）

合并到我们自己的 Linux DTB 上之后：屏幕停在联想 logo、USB 不枚举、无 pstore、约 10 s 后 ABL 放弃并回落（回 fastboot 或 `_b`）。

⇒ 这是 **项目第一天的坑**（`PITFALLS/sessions/01-引导fastboot重启交接.md`「假 dtbo 必须**两个槽都写**，否则卡 logo」、
`PITFALLS/sessions/02-内核DTS构建.md` 第 10 条「**ABL 会拿 stock dtbo overlay 我们的内嵌 DTB** → 卡 logo」），
当时只处理了 `_b`；2026-11-09/10 的 p60–p69 全部打在 `_a` 上，于是**每一发都注定卡 logo**。

## 2. 为什么之前那一串结论都错了

1. **`vbmeta_a` 假设（`PITFALLS #598`）被否证**：`vbmeta_a` 恢复原厂 Flags 0（哈希必然与我们的件不匹配）
   照样起 Linux（实验 F），且原厂 Android 也在 Flags 0 下从 `_a` 起（实验 B）⇒ 解锁态（orange）下 ABL 不因哈希失败拒绝交棒。
2. **「金标准件刷 `boot_a` 也起不来 ⇒ 与我们固件无关」结论方向对、归因错**：真正原因是两个槽的 `dtbo` 不同，
   与 payload、vbmeta 都无关（`PITFALLS #599` 的「两条死法」其实是「卡 logo 后回落 fastboot」与「卡 logo 后回落 `_b`」）。
3. **`logfs` 判据（`#594/#597`）失效更深一层**：现在实测 **logfs 对这些启动根本不写**
   （16:14 失败发与 16:20 成功 `_b` 启动前后 sha 完全相同 `9e614b36…`）⇒ 现有 10 个区段是 11-08/09 时代的残留，
   「信标一字节未变 ⇒ 没跑到」这类推论**不成立**（`PITFALLS #602`）。我们的 UEFI 自己能写 logfs（实验 G 的 `n=3` 就是证据），
   但 ABL 不再写。
4. **`androidboot.slot_suffix` 不能当槽位判据**：我们的 `boot.img` 头里**烤死**了 `androidboot.slot_suffix=_b`，
   ABL 对 Linux 件**不追加**自己的 suffix ⇒ 从 `boot_a` 起时 cmdline 仍然只显示 `_b`。
   本日一度据此误判「flashed 形态落到 `_b` 系统」（`PITFALLS #601`），改用 cmdline 里埋 `elden_bootmark=a` 才判定清楚。

## 3. 复现/使用配方（a 槽跑我们的东西）

```bash
# 0) 备份（首次）：dd 出 dtbo_a / vbmeta_a / boot_a 三份
# 1) 把 a 槽 dtbo 清成和 b 槽一样的「假 dtbo」（32 MiB 全 0）
truncate -s 33554432 /tmp/dtbo-blank.img
fastboot -s HA2EXB0E flash dtbo_a /tmp/dtbo-blank.img
# 2) vbmeta 不用动（原厂 Flags 0 也放行，实验 F）
# 3) 载荷：我们的 Linux boot.img 或 UEFI（p69 及以上）
SER=HA2EXB0E scripts/uefi-flashed-trial.sh --part boot_a --image out/r21-sbstop-p69/uefi-preamble69-r1.img --label p69-flashed
```

**判据（免屏）**：
- UEFI 件 ⇒ 总耗时 ≈ 无停留基线 + Σ(R70 停留)，且 logfs 里出现 `R68LOG n=<+1> … s9:esp-ld-ok`；
- Linux 件 ⇒ 在镜像头 cmdline 里埋唯一标记（`elden_bootmark=a` 这类），起来后 `grep /proc/cmdline`，**别用 `slot_suffix`**。

## 4. 当前设备状态（本报告结束时）

- `active=a`；`boot_a` = p69 UEFI（`f4024ba2…`，写盘后读回）；`dtbo_a` = 全 0（`83ee4724…`）；`vbmeta_a` = **原厂 Flags 0**（`55929c15…`）
- 在机：`7.3.1-debug-vk184-00002-g4da9a8b69fc8`，cmdline 带 `elden_bootloader=esp`（**从 `boot_a` → UEFI → ESP 的 `\boot\boot.img`**）
- `boot_b` 未动（日常线，`4e38bc2c…`，`set_active b` 即可回）

**回滚（恢复「a 槽 Android / b 槽日常」）**：

```bash
fastboot -s HA2EXB0E flash dtbo_a backup/dtbo_a.img          # 原厂 Android DTBO（45f51790…）
fastboot -s HA2EXB0E flash boot_a backup/boot_a-pre-uefi-20261108.img
fastboot -s HA2EXB0E set_active b
```

## 5. 对 G1-29 的意义

- 「flashed 形态」不再是门槛：**写 `boot_a` → 我们的 UEFI → BdsDxe → ESP 内核** 已实测闭环（129.2 s，三级停留都在）。
- 与 `PITFALLS #571`（同件两形态 ESP 枚举 8 vs 1）的关系：flashed 形态下枚举不全的最可能原因同样是 DTB 被 Android overlay 污染；
  现在 flashed 形态 `s9:esp-ld-ok` 已全绿，`#571` 的「候选：枚举时机/顺序 或 ABL 传参（DTB/dtbo_a）」中 **dtbo_a 已被证实**。
- 剩余（不属于本报告）：BDS 菜单交互、`root=LABEL=linux17` 从 flashed 形态的冷启动回归、把「a 槽 dtbo 清零」写进设备分派脚本。
