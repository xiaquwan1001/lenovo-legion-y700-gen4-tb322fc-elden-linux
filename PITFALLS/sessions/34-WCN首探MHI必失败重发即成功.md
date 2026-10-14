## 三十四、WCN MHI 首探必然失败、重发（fresh re-probe）即成功（2026-10-14 E3/E3a/E3c/E4 实测）

M1-7.3 树下 ath12k 首次 PCI probe 的 MHI power-on 在 **4.4 s** 发起后必然 `-110`；**任何「第二次」power-on 都在 0.5–1 s 内成功**。

263. **★WCN 首探失败与「上电晚 / 等得不够久 / 复位类型」都无关；真正的分类 = 首次 vs 之后。**
    - 否证链：pwrseq **3.9 s** 上电早于 ath12k probe **4.4 s**（非时序；`pci_pwrctrl_power_on_devices()` 设计上先上电后枚举）；MHI 超时 **3 s→30 s 用满仍 −110**（E3a；旧 90 s 单样本同向）；把首探**延后 8.6 s 到 12.6 s 仍 −110**（E4）；物理 POR 冷起与 warm 结果逐字同（与复位类型无关）。
    - 正证：E3c 好发上 re-probe **11.4 s** 发起、**11.92 s 成功**（0.55 s）；`m1-baseline` 22.5 s、E3a 50 s 亦成功——**全部是「第二次」**。
    - 机制：host 等的是芯片进入 AMSS/mission mode（`mhi_sync_power_up()` = `mhi_async_power_up()` + `wait_event_timeout(MHI_IN_MISSION_MODE || MHI_PM_FATAL_ERROR)`，超时即 `mhi_power_down()` + `-ETIMEDOUT`）；首次布防后**设备不再向已布防的 host 宣告就绪**，重新 power-on 才握手成功。上游参考 DT 无 host 侧 pwrseq（芯片由 bootloader 常供电、Linux probe 时已 boot 完）⇒ 本树新增 `wcn7861-pmu` pwrseq 引入差异。
    - 附带未决：首探等待窗口内 WCN 被 pwrseq 掉电（BT 侧释放引用）；`/sys/kernel/debug/pwrseq` 稳态 `regulators-enable/clock-enable`=2，WLAN 消费方是否持引用未定。
    - **修法**：A 内核内重发（MHI 超时 ⇒ `power_down` ⇒ 重试）/ C 延迟 work 重探（不阻塞 init）；B `-EPROBE_DEFER` 重探时机不确定；D 用户态 `ath12k-retry` 提前到 /init 早期（最小改动兜底，~11 s 已证可用）。**别再用「加大超时 / 延后首探」**（均已否证）；`CONFIG_ATH12K=m` + 后台 insmod（#259/#260）只绕开 init 阻塞，**不解决首探失败**。
    - 纪律：判「首探 vs 重发」必须看 **probe 序号**，任何时间戳上的成功都可能是重发。
    - 证据：`reports/e3-wcn-dyndbg-20261014.md`（§0–§9）、`TASKS/sessions/2026-10-14-wcn-firstprobe-dyndbg.md`、`logs/arm-e3-dyndbg/`、`logs/arm-e3a-mhi30/`。
