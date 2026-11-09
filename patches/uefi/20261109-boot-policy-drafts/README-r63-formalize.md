# r63 草案：ESP-first 默认启动路径「正式化」（G1-29 路线 B，TASKS §5 2026-11-08 深夜块 ④）

只读静态分析产物。**未编译、未上机、未改动主线树**（Mu 树 md5 与 patch 前一致）。
- 补丁：`0001-r63-formalize-esp-first-default.patch`（`git apply --check` 通过 = 针对当前工作区基线）
- 基线 = `/home/xuqianhui/y700-elden/build/uefi-woa-prep/repos/7-mu-lenovo` 的**未提交工作区**
  （R55/R56/R57/R58/R58b/R59/R60/R61-loader 全是手工改动 + R54/R61/R62 才是 patch 文件）。

## 0. 事实核对（先纠正三处口径）
1. Mu 树是**单提交浅克隆**（`.git/shallow`，`git log` 只有 `6b6ac42a`）⇒ **无法 git blame/log 查「为何写死」**，
   只能从代码形态判读：`LinuxLoader.c:755-761` 是 `GetKeyPress` 整段被注释后**残存的唯一活代码**
   （`//if (KeyPressed == SCAN_DOWN)` 下面紧跟裸 `BootIntoFastboot = TRUE;`）⇒ 上游移植者的开发约定：
   `fastboot boot <FD>` 后停在 UEFI fastboot 等宿主 `fastboot continue`。与 `PITFALLS #565` 一致。
2. **工作区脏**：`git status` 显示 5 个文件被改（LinuxLoader.c +557、VerifiedBoot.c +283、
   FrameBufferSerialPortLib.c +28、BootLib.inf +1、`Common/MU_TIANO` 子模块 m）⇒ **loader 侧源码真身只有工作区**，
   `patches/uefi/` 里**没有** R57/R58/R58b/R59/R60 的补丁目录（只有 R54/R55/R56/R61/R62）⇒
   正式化的第一步其实是「把这些脏改动冻结成 patch 目录」，否则不可复现。
3. `\menu.enable` 门控**在当前代码里已经不存在**（`LinuxLoader.c:845-850` 只剩解释性注释，
   grep 全树无 `menu.enable`）⇒ 任务书里「门控菜单」是 R64 的历史状态，现状是「无门控、被 #timeout 驱动」。

## 1. 逐条改动（文件:函数:当前行号）
| # | 位置 | 当前代码 | 期望行为 / 补丁做什么 |
|---|---|---|---|
| a | `LinuxLoader.c:758` `LinuxLoaderEntry()` | `BootIntoFastboot = TRUE;`（裸赋值，上游 223 行的等价物） | 换成 `if (LEspHasFile (ImageHandle, L"\\fastboot.force")) BootIntoFastboot = TRUE;`。默认 FALSE ⇒ 正常启动走 `LoadImageAndAuth`→`BootLinux`；开发态仍可用一个空文件回到老行为。ABL 的 `FASTBOOT_MODE/RECOVERY_MODE`（`:777`/switch）不动 |
| a′ | 同上，副作用必须写明 | `IsABRetryCountUpdateRequired()`（`:110`）因 `BootIntoFastboot` 恒 TRUE 而恒 FALSE | 改后正常启动会走 `FindBootableSlot()`（`PartitionTableUpdate.c:1641`）的扣 retry 分支，但**只在当前槽 `BootSuccess==0` 时才扣**；本机 `boot_b=succ1` ⇒ 不扣。历史坑 `PITFALLS #181` 不重演。ESP-first 路径在 `FindBootableSlot()` 之前早退（`VerifiedBoot.c:1969`）⇒ **ESP 路径完全不写 GPT** |
| b | `LinuxLoader.c:660-690` `LEspForceBoot()` + 调用 `:841-845` | 读 ESP `\espboot.force` ⇒ 强行 `BootIntoFastboot=FALSE; BootIntoRecovery=FALSE;` | **整段删除**。它的唯一存在理由就是抵消 a 的写死。`\espboot.force` 变成惰性文件（ESP 上留着无害，建议顺手删掉以免误读为开关）。恢复 recovery 意图靠补丁 #5 |
| c | `LinuxLoader.c:423` `LMenuLoad()` / `:479` | 无 `\menu.enable`；`#timeout` 未写时 `mLMenuTimeout=0` ⇒ 只取第 0 项、不登屏（多条目形同虚设） | 加 `mLMenuTimeoutSet` 标志：`#timeout=0`=显式零等待；**有 menu.cfg 且条目>1 但没写 #timeout ⇒ 默认 5 s**；无 menu.cfg ⇒ 单条目零等待（不变）。契约写进注释，供 ESP 上 menu.cfg 头注释复用 |
| d | `LinuxLoader.c` 新增 `LMenuResolveFallback()`，入口 `:851` 后调用 | ESP-first 只试菜单选中项；选中项不存在 ⇒ 直接落到分区路径 | 选中项在 ESP 上不存在时，**顺延到下一个真实存在的条目**（`LEspHasFile` 只读探测，不分配镜像、不进 AVB）。一个都不存在 ⇒ 保持原路径（行为与 R58b 逐字相同） |
| d′ | 回退链其他环 | BDS：R54 `R54TryEspBoot()` 失败/`StartImage` 返回 ⇒ `R13StartLinuxLoader()`（FV loader）；loader 内：ESP-first 失败 ⇒ 原分区路径 ⇒ 失败 `goto fastboot` | **不动**。链 = BDS ESP → ESP(菜单项/顺延) → 分区路径(活动槽) → UEFI fastboot(等宿主) → 无宿主时 ABL 扣 retry → 自动回 `boot_b`（`#572` 实测可用）。R61 rehook 位置（`R54TryEspBoot()` 之前）保持不变才好让 ESP 件崩了有 `[K] FLT` |
| e | `VerifiedBoot.c:1935-1955` `LoadImageAndAuth()` | ESP-first 无条件先试 | 加前置 `if (!Info->BootIntoRecovery)`。删了 `LEspForceBoot` 之后没人再清 `BootIntoRecovery`，否则「ABL 要 recovery」会被 ESP 上的正常系统静默顶掉。**位置必须仍在 `FindBootableSlot()` 之前**（零写盘语义） |

## 2. 「是否等 p61/R62 上机后再正式化」—— 结论：**不等，但只上零写盘形态；合并上机用 r63 = p61 + 本补丁**
- 不冲突：R62 改的是 `MdeModulePkg/Universal/BdsDxe/BdsEntry.c`（**能不能枚举到 ESP**），
  本补丁改的是 `LinuxLoader.c`/`VerifiedBoot.c`（**枚举到之后默认走哪条路**）。文件、函数、判据三者都不相交。
- 有依赖方向（单向）：flashed 形态下 ESP 枚举不到 ⇒ loader 的 ESP-first 根本进不去 ⇒ **本补丁在 flashed 形态的效果完全观察不到**。
  所以顺序应是「R62 让 ESP 可达」在前、「正式化改默认策略」在后验证；反过来先验证正式化只能靠 `fastboot boot` 形态。
- 因此建议：① 现在就把本补丁编成 `Loader-r63.efi`，用 `esp-put-loader.sh` 覆盖 ESP 的 `BOOTAA64.EFI`，
  `fastboot boot out/r21-sbstop-p61/uefi-preamble61-r1.img`（p61 已验证件、零写盘）→ 判据看 `\loader.log`；
  ② 通过后再谈写 `boot_a`（要 dd 备份 + `unbootable:a` 保留），此时 p61+loader-r63 才是「落地候选」。
- 唯一风险点：R62 的 `ConnectController(..., TRUE)` 全句柄连一遍 + 300 ms 是**flashed 形态专有**的，
  它不改变 loader 语义；但若 R62 修不好 `fs=1`，正式化本身也不会「让 flashed 形态变坏」——
  那时的失败链与今天逐字相同（`esp none` → FV loader → 读 `boot_a`=自身 → ABL 回 `boot_b`）。

## 3. 未上机 / 必须上机
**未上机可验证（主机侧静态/构建）**
- `git apply --check` 通过（已做）；`Loader.efi` 能编出来、`strings` 里有 `[L] menu fallback` / `menu keep` / `fastboot.force`；
  符号层面：`LEspForceBoot` 与 `espboot.force` 字符串应**从 .efi 里消失**；
  `menu.enable`/`espboot.force` 源码 grep = 0（注释除外）。
- 死代码检查：`Sel`/`Idx` 无重复声明、`-Werror` 构建零新增告警（本树 LTO + safe-stack 属性下尤其要过）。
**必须上机才能验证**
- 「不写 `\fastboot.force` ⇒ 直接进内核」这条（`\loader.log` 序列应为 `entry → pre-boardinit → boardinit st 0 →
  pre-vmdata → menu in → menu default/boot → bootfastboot 0 → pre-auth → post-auth st 0 → pre-bootlinux`，
  **不应再出现 `force-boot`**）。
- 菜单缺省 5 s 是否真的登屏 + 音量键可选（面板与 ConIn 是平台可疑通道，`#564/#567`）。
- `LMenuResolveFallback` 的顺延：把 ESP `\boot\boot.img` 改名 ⇒ 期望 `menu fallback 1` 并起 `boot2.img`。
- `\fastboot.force` 反向开关：放文件 ⇒ 期望 `to-fastboot` 且无 `pre-auth`（等价老行为）。
- recovery 意图：`fastboot oem` / 按键进 recovery ⇒ 期望**不**走 ESP-first（`post-auth st` 之后应有分区路径痕迹）。
- ESP-first 零写盘性：起完 `boot_b`/GPT 槽属性 sha 不变（`dd` 前后对比）。
- flashed 形态（需 R62）：`fs=1→fs≥2`、`esp ld=Success`、随后 `\loader.log` 落在 ESP 上。

## 4. 落地建议（另需批准，不在本草案范围）
1. 先把工作区脏改动（R55…R61-loader + 本补丁）冻结成 `patches/uefi/20261108R63-loader-formalize/`，
   并做 `p62-recipe.txt = p61 + R63`（R63 只改 Loader 源码，不影响 FD 的 BdsDxe 补丁顺序）。
2. `p62` 之前先单独验证 `Loader-r63.efi`（ESP 文件替换，零写盘），因为它的回归面只在 loader 内。
3. 真正「默认启动」= 写 `boot_a` 或 `uefi_a`，**必须**：dd 备份 + 保留 `unbootable` 保护 + 先过 R62。

## 5. 本目录里的另一份草案（并列，不是我的产物）
`0001-linuxloader-formalise-boot-policy.patch`（署名「2026-11-08R66」）+ `LinuxLoader.c.new`、`gen.py`、`body.diff`
是**同一任务的其他草案**，07:09 落盘，比本文件早。两点值得采纳进我的草案：
1. 反向开关用 **UEFI 变量 `EldenFastboot`（BOOT+RT+NV）** 而不是 ESP 上的 `\fastboot.force` 文件：
   flashed 形态 `fs=1` 时 FV loader 拿不到 FAT（`#571`）⇒ 文件型开关在那个形态下**不可用**，变量型可用。
   我的 #a 是本机唯一形态可验证的最小写法；若确定要长期保留「开发态 fastboot」后门，应改用变量。
2. 它把 `\menu.cfg` 门控写成「文件存在且 #timeout>0」；与我 #c 的差别只在「有条目但没写 #timeout」时是否默认 5 s
   （我选默认 5 s，理由：否则多条目形同虚设，`#571` 同族）。
两份草案都只动 loader 侧、都可与 R62 并存；**不要同时上机**（判据会互相掩盖）。
（注：原 README.md 被本文件覆盖，R66 草案的说明文字以其 patch 头为准。）
