# Q28 复核（2026-10-10 夜）：失效是**按内核二进制确定性**的，不是「冷/暖」也不是随机

> **⚠️ 本文结论已于同日被溯源审计降级——见 `reports/q28-binary-determinism-provenance-20261010.md`、`PITFALLS #171`。**
> 要点：① 21 发台账只有 7 发有原始日志（GOOD×2 vk64；NOCARD×5 vk89/vk89-plain），§1 表中另外 14 发无证据、`.img` 已删；
> ② §3 的「5,040,884 B(8%) 二进制差」主要是**版本串长度导致的 4 字节 `.rodata` 平移假象**（区间 94.72% 满足 `b[i]==a[i-4]`），`.text` 仅 26 个 word 不同且全为地址立即数，无指令语义改变；
> ③ 同一 `vk64.img` 在冷 POR/冷 fastboot 路径 3/3=STORM ⇒「不是冷/暖」不成立，且固定路径 `reboot2` 正是 `#166` 的 NOCARD 粘态机制。
> ⇒ 现口径：在 reboot2 暖路径上 vk64 亮、vk89/vk64c 不亮，真因未定。下文仅作旧记录保留。

> 触发：用户提出「冷/暖无法定性，怀疑冷/暖这套说法本身可靠」；于是抛开标签，固定路径
> **Linux → `reboot2 bootloader` → `fastboot boot <img>`** 反复观察。
> 结论：在本机当前状态下，**同一内核对每次该路径都给出相同结果**，且结果随**内核二进制**翻转——
> 不是 cold/warm，也不像「~60% 随机」。

## 1. 观察台账（全部走同一路径，SSH 读 `card0`）

| 镜像 | 内核来源 | config | ramdisk | 结果 |
|---|---|---|---|---|
| `out/boot-elden-vk64.img`（Oct-8 原镜像） | Oct-8 内核 `8efb2731` | a383cdb9 | vk64 原 | **GOOD ×6** |
| `boot-elden-vk64-tok.img`（同上内核 + cmdline token） | Oct-8 内核 | a383cdb9 | vk64 原 | **GOOD ×1**（token 证明确为 RAM 起） |
| `boot-elden-vk64-kbin.img`（Oct-8 内核重打） | Oct-8 内核 | a383cdb9 | vk64 原 | 与 vk64.img **逐字节同** |
| `boot-elden-vk89.img`（clean/base 模块化） | vk89 新编 | 2a940612（模块化） | 模块化 overlay | **NOCARD ×5** |
| `boot-elden-vk89-plain.img` | vk89 新编 | 2a940612 | 当前 base | **NOCARD ×2** |
| `boot-elden-vk64c.img`（vk64 config 新编） | vk64c 新编 | a383cdb9 | 当前 base | **NOCARD ×2** |
| `boot-elden-vk64c-oldrd.img` | vk64c 新编 | a383cdb9 | **vk64 原** | **NOCARD ×2** |
| `boot-elden-vk64c-clean.img`（`make clean` 全量重编） | vk64c 新编 | a383cdb9 | vk64 原 | **NOCARD ×3** |

判定：`card0` 在 = GOOD；`/sys/class/drm` 只有 `version` = NOCARD。

## 2. 关键对照（变量逐个钉死）

- **路径**：token 测试证明 `fastboot boot` 确实是 RAM 起（`/proc/cmdline` 有 `elden_probe=FBK64`），
  不会回退 boot_b。→ 路径不是变量。
- **ramdisk**：`vk64c-oldrd` 用**和 vk64.img 逐字节相同的 ramdisk**，仍 NOCARD；`vk64c-clean` 亦然。
  → ramdisk 不是变量。
- **config**：从 `vk64.img` 内核里 `extract-ikconfig` 得的 config 与本次用的 `a383cdb9` **0 差异**；
  `vk64c` 用同一 config 仍 NOCARD。→ config 不是变量。
- **陈旧对象**：`make clean` 后全量重编，仍 NOCARD。→ 不是增量构建的锅。
- **工具链**：两内核 banner 都是 `gcc 15.2.0-16ubuntu1 / ld 2.46`。→ 工具链不是变量。
- **源码提交**：两边 `uname` 都是 `-g d02658e63cf6`、无 `-dirty` → 同一提交 `d02658e63`。

## 3. 唯一剩下的差异 = 内核二进制本体

| | Oct-8 内核 | 本次 clean 重编 |
|---|---|---|
| `Image` 大小 | 62,540,288 B | 62,540,288 B（**同**） |
| payload sha256 | `8efb2731efb6…` | `ccc0a2843f68…` |
| 字节差异 | — | **5,040,884 B（~8%）** |

差异**高度集中**在 Image 的 32–44 MiB 区（5.04M/5.04M），其余区段仅个位/百位字节；
且该区段的**字符串集合完全一致**（仅 version/build-time 串不同），差异字节多为相邻小偏移
（±4/±16）→ 形态更像**数据/指针重定位（布局漂移）**，代码本身未必不同。

## 4. 结论与含义

1. **在当前设备/环境，Q28 的表现对「同一个内核二进制」是确定性的**：不是每次开机 ~60% 随机，
   也不是「冷/暖」二值。**用户对「冷/暖」说法的怀疑成立**——至少它不是当前的判别变量。
2. **翻转变量的粒度是「内核二进制」**（同源同 config 的两次构建可一个 GOOD 一个 NOCARD），
   指向 Q28 = **对内存/时序极敏感的首发竞态**：内核镜像布局的微小漂移即可把它推到 GOOD 或 NOCARD 一侧。
3. Oct-8 的 `vk64.img` 恰好落在 GOOD 侧 → 应作为 **Q28 的 GOOD 参照**保留；新编镜像默认在 NOCARD 侧。

## 5. 下一步（供裁决）

- **A. 定位机制**：分别 dump 两个内核的 `/proc/kallsyms`，找 32–44 MiB 区里地址发生位移的函数/表
  （`.rodata`/`__ksymtab`/`exception table` vs `.text`），判定是「纯布局」还是「真代码差」。
- **B. 利用 A/B 做变量搜索**：以「同源两构建 ⇒ 一 GOOD 一 NOCARD」为现象，改变单个构建因素
  （`make clean`、`-j`、`.config` 里某个无害项、`KBUILD_BUILD_TIMESTAMP`）看能否把新编推到 GOOD 侧，
  从而逼近真因。
- **C. 记录**：本现象已推翻/收窄 DOSSIER 的「冷起 ~60%」口径（至少在当前设备状态），需回填
  `reports/q28-DOSSIER.md` 与 `PITFALLS`。

## 6. 工具修复

`scripts/assert-kernel-sane.sh` 第 4 项（KIMG mtime < System.map → 判陈旧）当时对
**外部 `KERNEL_IMG=`** 误伤：该判据只在 KIMG 是本树默认 `Image.gz` 时成立。已改为
「仅当 KIMG == 树默认路径才做 mtime 陈旧检测」，外部预编内核改由 UTS 对齐保证身份。
