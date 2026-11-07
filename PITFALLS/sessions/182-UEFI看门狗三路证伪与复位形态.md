# #552 · UEFI 交棒后 ~4 s 硬复位：三条「关看门狗」的路全证伪，且复位**不是**独立定时器

- 日期：2026-11-07（深夜·二，G1-29，U2 `HA2EXB0E`，四发零写盘）
- 发现场景：`reports/uefi-p54-p57-wdog-negative-20261107.md`

## 事实（每条都有 logfs / ramoops / ABL log 证据）

| 试过什么 | 结果 |
|---|---|
| `EFI_WATCHDOG_TIMER_ARCH_PROTOCOL->SetTimerPeriod(0)`（p54，R49） | `[K] wdog-arch loc=ok set=Success`，内核仍 4.1077 s 硬复位 |
| SCM SIP `TZ_SECURE_WDOG_DISABLE_ID`（同发） | `st=Device Error rsp=-4` + `tz_armv8_smc_call failed, TzStatus=0xFFFFFFFE, SmcId=0x2000107` ⇒ **该 TZ 不支持** |
| 把 `QcomWDogDxe` 从 FV 摘掉（p55，R50，三处同步） | 仍 3.9038 s 硬复位（FV 清单已核无该件） |
| **反证**：p56 探测触发异常进 fault handler | **15 分钟没被复位** ⇒ 不存在「无人喂必咬」的独立定时器 |

推论：那枚看门狗要么由 UEFI 侧**定时事件**在喂、`ExitBootServices` 一停就断粮（形态 A），
要么复位本就是**内核侧动作**触发（写 PMIC/复位块的副作用，形态 B）。`PM: Reset by PSHOLD` /
`PM: PON by SYSOK` 两种都能对上，**不能**单凭它指名某一枚看门狗。

## 附带更正

`HW Wdog Setting from PCD : Enabled` 是 **ABL 自己**的 log 行（读的是 `logfs` 分区里 ABL 的
`UEFILOG1.TXT`），**不能**当作「我们的 Mu UEFI 打开了 WDT」的证据（p51–p53 轮曾这样用过）。

## 判据纪律

- EFI GUID 引用可能 `lld-link: undefined symbol`（MdePkg 的 `gEfiWatchdogTimerArchProtocolGuid` 没被拉进来）
  ⇒ 本地 `STATIC CONST EFI_GUID` + `(EFI_GUID *)` 强转。
- arch protocol 方法名 = `SetTimerPeriod`（`0` 即关），**不是** `SetTimer`。
- 「交棒后 XX 秒复位」这类时间形态，必须有**自旋对照**才能推「定时器咬人」；本轮 fault handler 自旋 15 min 就是那个对照。
