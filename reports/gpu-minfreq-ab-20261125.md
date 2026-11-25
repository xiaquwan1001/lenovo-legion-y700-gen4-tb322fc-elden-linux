# GPU `min_freq` 525 → 160 MHz 的 A/B：**无收益**（2026-11-25 21:05，设备窗）

> 计划来源：`.pi/plans/2026-11-25-device-power-management.md` §3 S4 / `reports/power-on-demand-20261125.md`（H2「GPU 顶格」）。
> 方法：在机日常核 vk192，桌面空闲（load ≈0.0），USB 接 PC 的 SDP 口并**先把 ICL 抬到 900 mA**（`echo 900000 > qcom-battmgr-usb/input_current_limit`，
> 依据 = `reports/m12-daily-already-writable-20261125.md` §5 已验证可用），然后用 `qcom-battmgr-bat/current_now` 做功率代理。
> 原始数据：`reports/artifacts/gpu-minfreq-20261125/ab.txt`。

## 0. 结论

| 臂 | `3d00000.gpu/min_freq` | `current_now` 均值（12 样本/60 s） | 中位数 | 区间 |
|---|---|---|---|---|
| A | 525 MHz（我们的 tuner 现状） | **+288.0 mA** | +290 mA | 271–296 mA |
| B | **160 MHz**（OPP 表最低档） | **+289.3 mA** | +290.5 mA | 279–293 mA |

**差 1.3 mA（0.45%），落在噪声内 ⇒ 无收益。**
⇒ **H2「GPU 被我们钉在 525 MHz 所以费电」不成立**：`simple_ondemand` 在空闲时本来就把频率压到最低可用档，`min_freq` 只是下限护栏，空闲场景下 525 与 160 的实际频率轨迹相同（两臂 `cur_freq` 全程都停在各自的 min，说明 GPU 基本没被调度）。
⇒ **决定：不改日常 tuner**（保留 `deploy-desktop-shell.sh` §8 的 525 MHz + 10 ms polling），代价/收益不成立，也没有首绘卡顿风险需要换。

## 1. 顺带确认的三件事

1. **M12 的 ICL 写入在真实使用中有效**：本测试全程靠 `input_current_limit=900000` 把「SDP 净放电」扳成「+290 mA 充电」，否则 A/B 的电流代理会被放电基线淹没。
2. **`current_now` 在充电态可作相对比较**（同 ICL、同温度、同负载），但**不能当绝对功率**（`power_now` 为空、无 RAPL）——与既有口径一致。
3. **笔记本端 SDP 端口上限**：900 mA 档下电池只拿到 ≈+290 mA 净充（含系统自耗），说明该 PC 端口实际供给被顶在 ~500 mA 附近，这与 `reports/m12-upstream-test-20261125.md` 的观察一致。

## 2. 下一步（功耗线的真正抓手，按收益排序）

1. **屏灭/息屏态**（DSI off + 面板断电）：本机面板 resume 要重下固件（见 `reports/suspend-s2idle-20261125.md` §2），说明面板是常驻耗电大户 —— 应测「灭屏 5 min 的电流基线」而不是继续调 GPU。
2. **s2idle 驻留**已验（≈8 min 稳定），日常化即可把「锁屏 30 s 后挂起」做成默认策略，收益远大于任何 sysfs 微调。
3. `wifi-scan-refresh` 150 → 170 s、Waydroid 不用即停：纯策略项，零风险。

## 3. 复现

```sh
B=/sys/class/power_supply/qcom-battmgr-usb; P=/sys/class/power_supply/qcom-battmgr-bat; G=/sys/class/devfreq/3d00000.gpu
echo 900000 > $B/input_current_limit            # 先让电池进充电态，避免放电基线盖住差异
echo 525000000 > $G/min_freq; sleep 10; for i in $(seq 12); do cat $P/current_now; sleep 5; done
echo 160000000 > $G/min_freq; sleep 10; for i in $(seq 12); do cat $P/current_now; sleep 5; done
echo 525000000 > $G/min_freq                    # 还原
```
