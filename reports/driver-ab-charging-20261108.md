# 「ESP 启动不充电」A/B 取证：**与启动路径无关，也不是驱动没加载**（2026-11-08）

> 触发：用户报「走 ESP(路线 B) 启动时状态栏没有充电字样、电池不标注充电；直接启动（boot_b）会识别 USB 充电」。
> 方法：新写的一次性快照工具 `scripts/driver-snapshot.sh`（跨 9 个驱动面、29 项汇总），
> 在**同一台机、同一根线、同一个口**上分别于两种启动路径各采一次，再用 `scripts/driver-snapshot-diff.sh` 对比。
> 全程只读。

---

## 0. 结论

**两条启动路径在电源/充电面上完全一致，驱动也都齐** ⇒ 「不充电」不是路线 B 造成的，也不是模块没加载。

| 项 | A：ESP 启动（路线 B） | B：正常启动 `boot_b` |
|---|---|---|
| `uname -r` | `7.3.1-debug-vk184-00002` | `7.3.1-debug-vk184-00003` |
| `modules_loaded` | 42 | 42 |
| `module_problems`（vermagic/Unknown symbol） | **0** | **0** |
| `failed_units` | 1 | 0 |
| `battery_status` | `Charging` | `Charging` |
| `battery_current_uA` | −284 000 | −304 000 … −230 000 |
| **`charge_counter`** | **5 118 580** | **5 118 580（同一值）** |
| `usb_online` | 1 | 1 |
| **`usb_input_limit_uA` / `current_max`** | **500 000** | **500 000** |
| `typec power_role` | `sink` | `sink` |
| regulators / thermal / drm / iio / video / led | 52 / 55 / 4 / 1 / 17 / 2 | 完全相同 |

唯二真实差异 = 内核 release（设计如此，两者只差 1 个 commit：ADSP fastrpc non-secure-domain）
和 `sda18` 在 B 下被 automount 到 `/efi`（与充电无关）。

## 1. 那为什么「看起来没充电」

1. **口只给 500 mA**：`qcom-battmgr-usb` 的 `CURRENT_MAX = INPUT_CURRENT_LIMIT = 500 000 µA`（= SDP 标准下行口），
   PD 完全没协商上去。写 `input_current_limit=3000000` 被驱动静默拒绝（回读仍 500000）。
2. **亮屏 + 满载耗电 > 500 mA**：电池 `CURRENT_NOW ≈ −0.23…−0.30 A`，`charge_counter` 在 20 分钟内单调下降
   （5 394 480 → 5 118 580 µAh），这是**净放电**。
3. **`STATUS=Charging` 是 ADSP 侧的状态位，不等于有净电流进电池**；UPower 按电流/功率符号判，
   所以状态栏显示 `discharging`（我在两种启动下都验证了 `upower -i` = `discharging`）。

⇒ 「B 下会显示充电」最可能是**换过口/换过 PD 充电器**，或当时 `STATUS` 恰好翻转；同一口同一线在这两种启动下行为相同。

## 2. 真正可做的一件事（建议）

拿一个 **PD 充电器 / 支持 PD 的口**再跑一次同一条命令，看 `current_max` 能否 > 500 mA：

```bash
ssh root@192.168.7.1 'bash -s' < scripts/driver-snapshot.sh   # 只需看 summary.tsv 里 usb_input_limit_uA / usb_current_now_uA
```

- 若仍 500 mA ⇒ **PD 协商在主线没工作**（`ucsi_glink`/`qcom_battmgr` 与 ADSP `charger_pd` 的交界面），单独立项（驱动线）；
- 若跳到 1.5–3 A 且 `charge_counter` 增长 ⇒ 之前就是普通 500 mA 口，问题不存在。

## 3. 顺带发现（与本题无关但值得记）

- `sda18`（ESP）在 `boot_b` 启动下被 automount 到 `/efi`，在路线 B 启动下**不挂载** —— 后续脚本别再假设固定挂载点。
- `regulator.N` 的编号在两次启动间**会重排**（同一批稳压器换了序号）⇒ 用 `regulator.N` 做跨启动对比会假阳性，
  要比 `name`（脚本已同时抓 `name`/`state`）。
- `failed_units` 在 A 下 1 个（历史已知的 `pi-tablet-night.service`），B 下 0。
- `iio_devices=1`、`asound_cards=1` 两边一致 —— 传感器/音频在这两台启动下同样没有更多实例（与 `TASKS` 的 SSC 线状态一致）。

## 4. 工具

- `scripts/driver-snapshot.sh`：一次启动 = 一份快照（`meta/power_supply/typec/usb/power_domains/display/audio_sensor_input/net_bt_cam/storage_thermal/errors + summary.tsv`，29 项汇总行）
- `scripts/driver-snapshot-diff.sh`：两份快照逐项对比，只打变化行（`--full` 打完整 diff）
- 本次原始快照：`reports/artifacts/driver-ab-20261108/{snapA,snapB}/`
