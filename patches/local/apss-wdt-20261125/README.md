# apss-wdt-20261125 —— SM8750 APSS watchdog DT(+binding) 备料（**不投递**）

- **用途**：给 D19 遗留项补「硬件看门狗」候选件。D19 现状 = 测试核 hang 只能物理 POR；
  上一候选 `gunyah_wdt` 已上机证否（`reports/d19-gunyah-wdt-20261125.md` 父代理附节：hyp 侧空实现）。
  本目录只产 **DT + binding 备料**，不发信、不投递、不碰设备、不改 TASKS/INDEX。
- **基线**：上游 v7.4-rc3（`aebb72744764`，`build/elden-tree`）。两枚补丁按序 `git am` = **2/2 干净**
  （`evidence/gate-git-am-2of2.log`）；`build/elden-tree` 全程无改动（`evidence/gate-tree-state-after.log`）。
- **形状**：照 glymur / kaanapali / hawi（同族、`watchdog@17600000`）与 hamoa/x1e80100
  （`watchdog@17410000`，`status = "reserved"; /* Reserved by Gunyah */`）的节点写法：
  `compatible = "qcom,apss-wdt-sm8750", "qcom,kpss-wdt"` + `clocks = <&sleep_clk>` +
  `interrupts = <GIC_SPI 0 IRQ_TYPE_EDGE_RISING>`。**基址不用 0x17600000**，用 **0x16410000**，
  取证/冲突表/采信理由见报告 §1–§2（SM8750 的 APSS 寄存器块在 `0x1640_0000` 段，不在 `0x17xx_xxxx`）。
- **门禁**（命令与原始输出见 `evidence/`）：`checkpatch --strict --no-tree` 两枚 0E/0W/0C；
  `dtbs_check`（7.4-rc3 门树 + 日常树 `build/daily`）**0 诊断**；`dt_binding_check` 全量 rc=0（5420 `DTC [C]`）。
- **未做**：上机（本 lane 硬约束「不碰设备」）。上机判据与**先读后试**的安全顺序见
  `reports/d19-apss-wdt-prep-20261125.md` §5；**先别直接把 `status = "okay"` 的核起在设备上**
  （基址若属 hyp/TZ 保护区，`qcom_wdt` 在 probe 里读 `WDT_STS` 会同步外部中止）。
