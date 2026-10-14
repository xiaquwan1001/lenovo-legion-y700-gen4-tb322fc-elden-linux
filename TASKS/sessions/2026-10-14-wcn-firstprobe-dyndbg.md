# 会话记录 2026-10-14：WCN 首探失败根因（E3 dyndbg + E3a 30s 超时）

> 承接 TASKS §7「未决① WCN 首探时序」。设备 U2 `HA2EXB0E`（Linux / SSH 可达）。
> 证据：`reports/e3-wcn-dyndbg-20261014.md`、`logs/arm-e3-dyndbg/`、`logs/arm-e3a-mhi30/`。

## 0. 结论（数字先行）

| 实验 | 镜像 | 关键实测 |
|---|---|---|
| E3 dyndbg | `out/boot-elden-e3-dyndbg.img` | pwrseq probe **3.925 s**、rails on **3.972 s**（早于 ath12k probe 4.431 s）；首探 MHI 4.49→7.65 s −110（3 s 超时）；pwrseq off 35.1 s / on 86.2 s；retry 121.5 s 成功 |
| **E3a 30 s 超时（单变量）** | `out/boot-elden-e3a-mhi30.img` | 首探 MHI 4.43 s → **35.82 s 仍 −110（30 s 超时用满）**；pwrseq off 32.2 s / on 37.9 s；retry 50.07 s → chip_id 50.64 → phy0 55.6 → wlan0 56.5 s。**Q28 签名 0（好发）** |

## 1. 判定

- **H1（等得不够久）否证**：3 s→30 s 用满仍失败。
- **H2 成立**：首探失败与「上电晚 / probe 早」无关（pwrseq 先于 probe；`pci_pwrctrl_power_on_devices()` 设计上先上电后枚举）。
  **成功只出现在「重新发起的 MHI power-on（fresh re-probe）」**（`m1-baseline` 22.5 s、本发 50 s）。
  ⇒ 机制：首次 MHI/BHI power-on 在 WCN 未就绪时发起后不再被设备应答；必须重发。
- **附带观察**：首探等待窗口内 pwrseq 被 BT 侧释放（WCN 掉电）——需查 refcount（WLAN 消费方是否持引用）。

## 2. 变更资产

- 新工作树 `build/m1-73-e3`（分支 `m1-73/e3-mhi30`，tip = E3a 提交，单变量改 `ath12k/mhi.c: MHI_TIMEOUT_DEFAULT_MS 3000→30000`）。
- 镜像：`out/boot-elden-e3-dyndbg.img`（`43e7b888…`）、`out/boot-elden-e3a-mhi30.img`（`eebfe78a…`）。
- 免重编技巧：`dyndbg="file pwrseq-qcom-wcn.c +p"` 走 cmdline 即可对**内建**驱动开动态调试。
- 编译技巧：内核 release 需 **`make LOCALVERSION=`** 显式传空，才不追加 `+`（`setlocalversion` 见 `LOCALVERSION+set` 分支），否则 UTS 变 `…e3+` 与 ramdisk 模块 vermagic 失配。

## 3. 遗留（2026-10-14 晚收尾更新）

- ✅ E3c：fresh re-probe 最早 **11.4 s** 成功（`sleep 12→1`；重试由 OpenRC `/etc/local.d/elden-bringup.start` 拉起，非 /init；设备脚本已还原，md5 `826c96e3d24bc816e951ea9e118337e6`）。
- ✅ E3d：首探等待窗口内 WCN 被 pwrseq 掉电（BT 侧释放引用）；`/sys/kernel/debug/pwrseq` 稳态 `regulators-enable/clock-enable`=2，refcount 归属未决。
- ✅ 物理 POR 冷起：结果与 warm 逐字同 ⇒ 与复位类型无关。
- ✅ E4（首探延后 8.6 s 到 12.6 s）：**仍 −110 ⇒ 否证「延后/晚加载」**，分类 = 首次 vs 之后（`PITFALLS #263`）。
- ⏳ 正路修法：内核内重发（A）/ 延迟 work 重探（C）；`-EPROBE_DEFER`（B）重探时机不确定；用户态 daemon 提前（D）兜底。向上游报告「WCN MHI 首探不可恢复」。
