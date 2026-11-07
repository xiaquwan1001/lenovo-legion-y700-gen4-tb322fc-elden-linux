# UEFI p54→p57：三条「关硬件看门狗」的路全部证伪（+ 一条反证：复位不是独立定时器）

> 线：G1-29。承接 `reports/uefi-p52-p53-handoff-confirmed-20261107.md`（交棒成立；卡点 = 交棒的
> 那个内核 4–10 s 后整机硬复位；最强元凶 = UEFI 自开 HW WDT）。
> 设备 = U2 `HA2EXB0E`。全部 `fastboot boot`，零写盘，`boot_b`/槽位未动。

---

## 0. 结论（4 条，逐条带证据）

1. **UEFI 标准看门狗 arch protocol 存在、也确实关掉了 —— 但它不是咬人的那枚**
   p54（R49）的 logfs：`[K] wdog-arch loc=ok set=Success`（`EFI_WATCHDOG_TIMER_ARCH_PROTOCOL->SetTimerPeriod(0)`）。
   内核仍 **4.1077 s** 硬复位（`console-ramoops-0` 里 `Kernel command line: … elden_bootpath=uefi initcall_debug`）。

2. **TZ 侧 secure wdog 关不掉**：同一发 `[K] wdog-scm loc=ok st=Device Error rsp=-4`，
   环里还有 `tz_armv8_smc_call failed, TzStatus = 0xFFFFFFFE, SmcId = 0x2000107`
   ⇒ `TZ_SECURE_WDOG_DISABLE_ID`（SIP `0x2000107`）在这版 TZ 上**不可用**（头文件写明 debug 关掉即 NOP）。

3. **我们 FV 里的 `QcomWDogDxe` 也不是（唯一）武装者**：p55（R50）把它从
   `APRIORI.inc` / `DXE.inc` / `DXE.dsc.inc` 三处同步摘掉（构建目录 FV 清单里已无该件），
   内核仍在 **3.9038 s** 硬复位，形态不变（`mmc0 ADMA` 分支），ABL 仍记
   `PM: Reset by PSHOLD / Hard Reset` + `PM: PON by SYSOK`。

4. **反证：那不是「没人喂就必咬」的独立定时器**。p56（R51）探测寄存器时踩到
   `esr=96000010 far=17410014`（同步外部中止）进了 fault handler，整机**在 fault handler 里活了 15 分钟以上
   没有复位** ⇒ 交棒后 ~4 s 的那次复位，更像「某个东西正好在 `ExitBootServices` 时一起停了」。
   p54/p55 的 UEFI 阶段本身也都跑满 10 s+（`fastboot boot` 11.6 s + preamble）无复位。

5. **APSS 看门狗窗口在 SM8750 上不是 `0x17410000`**（p56/p57 两发都吃外部中止：
   p56 `far=17410014`，p57 逐条读时**第一个字** `far=17410000` 就中止）⇒ 该地址在本机总线上无实现。
   盲探太贵（每次中止都要人工长按断电），**停止盲探**。

---

## 1. 四发的账

| 发 | 件（sha256 前 8） | 改动 | 结果 | 关键判据 |
|---|---|---|---|---|
| **p54** | `uefi-preamble54-r1`（`214bf5ff`） | **R49** = `SetTimerPeriod(0)`（本地定义 GUID，MdePkg 的符号会链接失败）+ SCM `TZ_SECURE_WDOG_DISABLE_ID`，各打一行 EFI_STATUS | 交棒成立，**4.1077 s** 硬复位 | `[K] wdog-arch loc=ok set=Success`；`[K] wdog-scm loc=ok st=Device Error rsp=-4`；`tz_armv8_smc_call failed, TzStatus=0xFFFFFFFE, SmcId=0x2000107` |
| **p55** | `uefi-preamble55-r1`（`1659e515`） | **R50** = 摘掉 `QcomWDogDxe`（三处） | 交棒成立，**3.9038 s** 硬复位 | FV 清单/Ffs 目录无该件；console 带令牌；`Reset by PSHOLD` |
| **p56** | `uefi-preamble56-r1`（`9d808b52`） | **R51** = 只读探测 `0x17410000`/`0x17C10000` 各 6 字（一次读、一次打印） | **未跳内核**：`esr=96000010 far=17410014`，卡在 fault handler（后由用户长按断电） | 屏上只有 `[K] wdg-arch …`/`[K] wdg-scm …` 与 `[K] FLT …`；**没有** `[K] wdt…` 行（值随异常丢失） |
| **p57** | `uefi-preamble57-r1`（`88790b66`） | **R52** = 逐条读（读一个打一个）、避开 `0x14`、只读 `0x0/0x4/0x8/0xC` | **未跳内核**：`far=17410000` 第一个字即外部中止，卡 fault handler（待断电） | 同上 |

> **纪律说明**：p56/p57 是被中断的 trial，**没有 `reports/trials/*.json` record** ⇒ 按
> `.pi/AGENT-OPS.md` §3 不写 verdict，只记现象（屏上 dump 由用户目视记录；文本见本文件 §4）。

## 2. 为什么「复位不是独立定时器」这条反证值钱

p52/p53 那轮的解释是「WDT bite ≈10 s，最后一次 pet 离跳转多近决定咬在几秒后」（R48 的注释）。
若成立，则**任何**交棒后的自旋都会在同样时间内被咬。p56 的 fault handler 自旋了 15 分钟没被咬
⇒ 该解释不成立。剩下两种形态：

- **A｜petter 在 UEFI 侧**：pet 由 UEFI 的定时事件/驱动做（fault handler 期间定时器仍在跑 ⇒ 不咬），
  `ExitBootServices` 一停 ⇒ 无人喂 ⇒ 咬。若如此，「摘掉 `QcomWDogDxe` 也没变化」说明 petter 是**别的** DXE 件。
- **B｜复位由内核侧动作触发**：内核在 ~4 s 走到某一步（`mmc0` 探测 / glink+UCSI 链）时**自己**把
  PS_HOLD 拉低（PMIC 写的副作用 / SoC 复位块），所以与「有没有人喂」无关，也与 UEFI 侧的框架无关。

区分 A/B 的下一步（见 §5）不需要再盲探 MMIO。

## 3. 判据纪律（本轮新增）

- **EFI 的 GUID 引用可能链接不到**：`gEfiWatchdogTimerArchProtocolGuid` 在 `LinuxLoader` 里是
  `lld-link: undefined symbol`（MdePkg 定义没被拉进来）⇒ 本地写 `STATIC CONST EFI_GUID` + `(EFI_GUID *)` 强转。
- **arch protocol 的方法名是 `SetTimerPeriod`**（`TimerPeriod==0` 即关），不是 `SetTimer`（编译期就拒）。
- **一次读多个 MMIO 字 + 一次 `AsciiSPrint`**：只要其中一个字中止，整行的值全丢（p56 实证）⇒ 探测必须「读一个打一个」。
- **盲探 MMIO 的代价 = 一次人工长按断电**：本项目判据里这是「物理动作」，必须计入试验成本，不做大范围试探。
- **`PM: Reset by PSHOLD` + `PM: PON by SYSOK`** 是 PMIC/PON 侧记录的「AP 侧拉低 PS_HOLD」复位路径
  （与 APSS 看门狗、SoC 复位块、PMIC wdog 都能对上，**不能**单凭它指名某一枚看门狗）。

## 4. p56/p57 屏上 dump（用户目视，两个会话各一份）

p56（R51）：
```
[K] wdg-arch loc=ok set=Success
[K] tz_armv8_smc_call failed, TZstatus = 0xFFFFFFFE, SmcId = 0x2000107
[K] wdg-scm loc=ok st=Device Error rsp=-4
[K] FLT pc=CFC9FFA8 img=- b=CFC9A000 z=4C000 o=5FA8 esr=96000010 far=17410014
[K] sp=0x7640DB0 spsr=80000305 far=17410014
[K] x00=0 x01=1614800 x02=CFCC7E50 / x06=0 x07=D2BAA82E x08=17410004 x09=17410000 …
```
p57（R52）：同型，`far=17410000`、`esr=96000010`、`pc=CFC9FF9C`（**第一个字就读不了**）。

## 5. 下一步（按可做性排序，都不再盲探 MMIO）

1. **p58 = R46「nosdcc」备料终于用上**：把 `mmc0`（SDHCI）在 DT 里 `status=disabled`，看死点是否移动/消失。
   3/6 次死亡现场都是 `mmc0: ADMA error: 0x02000000` + **荒谬的 `ADMA Ptr: 0x0000000ffffff224`**
   ⇒ 若与 UEFI 交棒后的 SMMU/DMA 状态有关，这一发一刀切；若死点不变，形态 B（内核自触发）也随之收窄。
2. **从 `uefi_a` 分区取 stock `KernelInterfaceDxe`**：已确认 `uefi_a`（5 MiB，设备侧只读 dd 到
   `/tmp/uefi_a.bin`）里的 PrePi 含 `Error: KernelInterfaceInit failed` 字符串 ⇒ stock 固件**有**这个组件
   （ABL 就是靠它 `WdogDisable()`）。取到后与 `QcomWDogDxe` 一起进 FV，R47/R48 的 `WdogDisable()` 才会真正执行。
   卡点：`scripts/ffs-extract.py` 只走到 4 个 FFS（SEC/SMM_CORE），主 DXE FV 是**压缩后再拼进**的，需要扩展解包器。
3. **PMIC/PON 侧**：`HW Wdog Setting from PCD : Enabled` 是 ABL 自己 log 里的行（**属 ABL，不是我们的 UEFI**，
   这条归属要更正），PON/PS_HOLD 复位路径的最后一环可能就在 PMIC 的 PON wdog；需要 SPMI 寄存器级证据。
4. **反证 A 的直接检验**：在 UEFI 里 `ExitBootServices` 之后**不跳内核**（`CpuDeadLoop`）看是否 ~4 s 被咬；
   若被咬 ⇒ petter 确实在 UEFI 侧（A），若不被咬 ⇒ B。这是最便宜的一发（R18 的 `CpuDeadLoop` 归档仍在）。

## 6. 产物

| 项 | 路径 |
|---|---|
| 补丁 | `20261107R49-wdogarchscm/`、`20261107R50-nowdog/`、`20261107R51-wdtprobe/`、`20261107R52-wdtprobe2/` |
| 配方 | `p54-recipe.txt`(74)、`p55-recipe.txt`(75)、`p56-recipe.txt`(75)、`p57-recipe.txt`(75) |
| 镜像 | `out/r21-sbstop-p54`…`p57`（`uefi-preamble5{4,5,6,7}-r1.img`） |
| 构建归档 | `reports/artifacts/uefi-20261107R49-p54/`、`…R50-p55/`、`…R51-p56/`、`…R52-p57/` |
| 失败内核 console | `reports/artifacts/uefi-p54-wdog-console/console-ramoops-0.bin`、`uefi-p55-nowdog-console/…` |
| logfs 16 KiB（p54） | `reports/artifacts/uefi-p54-wdog-console/logfs-preeb-16k.txt` |
| 上机证据 | `reports/artifacts/uefi-boot-20261107-{220032,221322,223554,225215}/` |
| trial | `reports/trials/20261107T140318Z-uefi-p54-wdog-arch-scm.json`、`20261107T141608Z-uefi-p55-nowdog.json`（p56/p57 中断，无 record） |
| stock UEFI 取证 | `/tmp/uefi_a.bin`（设备 `uefi_a` 只读 dd）、`/tmp/uefi_a_ffs/8af09f13-SEC-TE.bin`（含 `KernelInterfaceInit` 字符串） |
