# V2 取证（`#692`/`#737` 复位源）：PMIC PON reason 通道在本机**不存在**，且它判不了根因

> 工单 = `reports/sensors-adsp-pd-pdr-20261127.md` §9 的 P3 / T6 下一步「只读取证 PMIC PON reason / PON 安全监控配置」。
> 执行：2026-11-27 无人值守轮，**全程只读**（设备在机 vk192 核，boot_id `95f5a0fc-…`）。无构建、无刷写、无复位。

## 0. 结论（三行）

1. **主线 7.3.1 的 `qcom-pon` 不读任何 reason 寄存器**（只写 `PON_SOFT_RB_SPARE` 的 reboot-mode magic，`drivers/power/reset/qcom-pon.c`），
   也没有 sysfs/debugfs 暴露 PON reason；**用户态也没有别的路**——`/sys/kernel/debug/regmap/0-00` **没有 `access` 文件**
   （内核未开 `CONFIG_REGMAP_ALLOW_WRITE_DEBUGFS`），`registers` 只吐缓存值（PON 段 256 条全非 `XX`，但含 `0xc4` 这类重复值 ⇒ **不能当新鲜读数**）。
2. **现有唯一证据 = ABL 的 `PM: Reset by PSHOLD / Hard Reset`**（`reports/artifacts/sensors-692-logfs-20261127/`）。按 Qualcomm RB5
   平台手册与下游 `qpnp-power-on.c` 的位定义，`WARM_RESET_REASON1` 里 **`0x02 = PS_HOLD`（「SoC 拉低 PS_HOLD」= 正常重启同款）**、
   **`0x04 = PMIC_WD`（PMIC 看门狗）** ⇒ 该记录**不含 PMIC_WD 位**，可**排除「PMIC 看门狗把整机拉复位」**这一支；但 PS_HOLD
   无法区分「AOP / TZ / 内核」谁拉的低 ⇒ **H2a（AOP）与 H3（TZ）本质不可由 PMIC 侧区分**。
3. **动作**：这条取证路（PMIC/PON 侧）**到此为止**——判不了根因，不再投入。`#737` 若要继续只剩 DSP 侧（ramdump / QMI-PDR）
   或板外采集，均需预算/授权。另：主线**缺 PON reason ABI**是真缺口（通用 ABI `include/linux/power/power_on_reason.h` 已存在，
   目前只有 at91/mcf 用），但 `qcom-pon` 正被上游 SPMI sub-device 系列大改（v8→v10，2026-05..07）⇒ **现在不动手**，登记为 M 系列候选。

## 1. 主线现状（逐条可复核，树 = `build/daily`，mainline 7.3.1，worktree `4da9a8b69fc8`）

| 项 | 事实 | 判据 |
|---|---|---|
| `qcom-pon` 只做什么 | `qcom_pon_reboot_mode_write()` → `regmap_update_bits(base + 0x8f, GENMASK(7,shift), magic << shift)`；无任何 reason 读取 | `drivers/power/reset/qcom-pon.c:22-46`（`PON_SOFT_RB_SPARE 0x8f`） |
| 支持的 compatible | `pm8916-pon`/`pm8941-pon`/`pms405-pon`（GEN1）、`pm8998-pon`/`pmk8350-pon`（GEN2） | 同上 `:89-93` |
| 是否有 reason ABI | 无。通用 ABI 已有：`POWER_ON_REASON_{REGULAR,RTC,WATCHDOG,SOFTWARE,RST_BTN,CPU_CLK_FAIL,XTAL_FAIL,BROWN_OUT,UNKNOWN}`，用户仅 `at91-reset.c`、`mcf-rcm-reset.c` | `include/linux/power/power_on_reason.h` 全文；`grep -rn power_on_reason` 仅这两处 |
| 是否有 qcom 侧读取 | `grep -rn "WARM_RESET_REASON\|PON_REASON" drivers/ arch/arm64/ include/` = **0 命中**（只有无关的 `rti_wdt.c`/`ath12k`） | 同命令 |

## 2. 寄存器语义（引用，非本机实测）

来源：① 下游 `qpnp-power-on.c`（android.googlesource / LineageOS 镜像）里的偏移宏；② Qualcomm *Robotics RB5* 手册
「PMIC PON reset status」的位表（`docs.qualcomm.com/doc/80-88500-4`）。

- 子系统：`PERPH_TYPE`(0x04)=`0x01` PON、`PERPH_SUBTYPE`(0x05)（本机实测 = **`0x09` = PON_GEN3_HLOS`**）。
- 偏移（下游宏 `PON_OFFSET`，Gen1 = +0x8/0xA/0xC；Gen2/Gen3 = +0xC0/0xC2/0xC5）：
  `PON_REASON1`、`WARM_RESET_REASON1`、`POFF_REASON1`、`PON_WARM_RESET_REASON2`、`PON_OFF_REASON`(0xC7)、`FAULT_REASON1`(0xC8)、`S3_RESET_REASON`(0xCA)。
- `WARM_RESET_REASON1` 位：7 KPDPWR_N · 6 RESIN_N · 5 KPDPWR_AND_RESIN · 4/3 GP2/GP1 · **2 PMIC_WD** · **1 PS_HOLD** · 0 SOFT。
- `PON_REASON1` 位（冷启动）：7 KPDPWR_N · 6 CBLPWR_N · 5 PON1 · 4 USB_CHG · 3 DC_CHG · 2 RTC · 1 SMPL · 0 Hard reset。
- `PON_ON_REASON`：bit7 PON_SEQ（冷）/ bit6 WARM_SEQ（暖）。
- ⚠ **未取证**：ABL 那句 `PM: Reset by PSHOLD` 到底取自哪个寄存器（`WARM_RESET_REASON1.bit1` 还是 `POFF` 路径），
  仅能说**与该位一致**；本报告据此下的「排除 PMIC_WD」结论以「ABL 取的是 warm-reset 原因」为前提，标 **前提性结论**。

## 3. 本机现态（只读实测）

```
# 设备 PON 节点（DT）
/proc/device-tree/soc@0/spmi@c400000/pmic@0/pon@1300/compatible = "qcom,pmk8350-pon"
reg names = "hlos"(0x1300) "pbs"(0x800)；子节点 pwrkey/resin 都在
dmesg: input: pmic_pwrkey / pmic_resin 各 1（驱动已 probe）

# 用户态读寄存器：不可行
ls /sys/kernel/debug/regmap/0-00  → name range registers     # 没有 access
zcat /proc/config.gz | grep REGMAP_ALLOW_WRITE → 无该符号（= 未开）
grep -E "^13..:" registers | grep -vc XX → 256                # 全非 XX 也≠新鲜：0x130a/0x130b 同为 0xc4、0x1311..0x1316 多为 0xc0
```

⇒ 想在**不改内核**的前提下读 PON reason：**无路**。（`access` 文件只在 `CONFIG_REGMAP_ALLOW_WRITE_DEBUGFS=y` 时才生成；
本机未开，且开它意味着给用户态任意写 PMIC 寄存器的能力，属危险配置，不建议为取证而开。）

## 4. 上游缺口（真缺口，但**现在不动手**）

- 缺口：SM8750 这类 Gen2/Gen3 PON 的 **reason 无任何主线出口**（冷/暖、PMIC_WD、PS_HOLD、SMPL、FAULT_REASON1 全在 register 里但没人读）。
- 已有通用 ABI 可直接复用（`power_on_reason` sysfs 约定），实现量小（读 3–4 个寄存器 + 映射字符串，≈80–120 行）。
- **冲突风险**：`qcom-pon` 正在被上游 SPMI sub-device 迁移系列重写（`[PATCH v8 00/10]` 2026-05、`v10 00/11` 2026-07，
  含 "Migrate to devm_spmi_subdevice_alloc_and_add()" 与新的 `regmap_config`）。现在提 = 必撞。
- 处置：**登记为 M 系列候选（不立项、不提）**，触发条件 = 上述系列进主线后（现查 `qcom-pon.c` 仍是 `dev_get_regmap(pdev->dev.parent)` 旧写法）。

## 5. 对上位问题（`#737`「谁复位了整机」）的净收益

| 假说 | 本报告后的状态 |
|---|---|
| ① PMIC 看门狗（PMIC_WD）拉复位 | **可排除**（ABL 记的是 PS_HOLD；PMIC_WD 位不在）——前提性结论，见 §2 ⚠ |
| ② AOP/PMIC PBS 安全监控（H2） | **仍可能**，且它同样以「拉 PS_HOLD」收场 ⇒ 与 ③ 在 PMIC 侧不可分 |
| ③ TZ 把 ADSP SSR 升级成整机复位（H3） | 同上，不可分 |
| ④ PBL/硬件 | 无证据 |

⇒ **PMIC/PON 通道已榨干**：它能排除一支、不能分辨另两支。要分辨只能看 **DSP 侧（ramdump / QMI-PDR）** 或板外采集。

## 6. 下一步（按性价比）

1. **停**：不再在 PMIC/PON 侧投入（本报告即收口）。
2. 若要继续 `#737`：唯一实质通道 = **ADSP ramdump**（需下载 `adsp.mbn` 对应调试固件 + 复用 Qualcomm QMI-PDR/`qcom_rproc_...` 链路；
   mainline 无现成链路，工作量大、需预算）——**需用户明确放行**。
3. 与传感器主线解耦：`#692` 的**用户态**侧（hexagonrpc registry 写支持 / listener 256 B 输入缓冲）可离线推进，
   但验收**禁止**用 `-s`（`PITFALLS #737`）。
