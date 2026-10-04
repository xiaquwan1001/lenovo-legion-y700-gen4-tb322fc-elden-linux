# BT BR/EDR 高延迟根因排查（静态分析轮）— 2026-10-04

> 范围：**仅主机侧静态代码分析 + 补丁/测试资产准备**。本轮**未上机、未刷机、未写设备**，
> 设备 U2(HA2EXB0E) 停在 fastboot，Linux 未运行。所有"实测"数字均引自
> `archive/topics/BT-2026-09-30.md`，本文件不新增实测结论。
> 本文件只增不改；不改根目录 6 份维护文档；未 commit。

---

## 0. 一句话结论

既有证据链（vk25 关掉控制器 SLEEP_IND 后 RTT 无改善）与本轮新读到的代码事实
（**主机 TX 侧 idle 超时是 2000 ms 而非 100 ms**，因此 l2ping 期间主机侧 IBS 握手
根本不在每包路径上）合起来指向：**延迟不在主机的 IBS 状态机，而在控制器侧的
"自身深睡/唤醒"或 UART/流控**。据此给出 4 个可判别补丁 + 1 个上机测试脚本；
**首要推荐实验是不用改内核的 `KEEPALIVE=1`**（若 RTT 塌回 <10 ms 即坐实控制器深睡）。

---

## 1. 已确认的代码事实（file:line，均已本轮核对）

| # | 事实 | 位置 | 意义 |
|---|---|---|---|
| F1 | `IBS_WAKE_RETRANS_TIMEOUT_MS = 100` | `hci_qca.c:78` | 唤醒重传超时 100 ms；archive 里 `wake_retrans 100/113`≈88% 即"100 ms 内没等到 WAKE_ACK" |
| F2 | `IBS_HOST_TX_IDLE_TIMEOUT_MS = 2000` | `hci_qca.c:80` | **主机 TX 侧要空闲 2 s 才回 ASLEEP**（archive 曾按 100 ms 理解） |
| F3 | `qca_enqueue()` 在 `TX_AWAKE` 分支每次发包都 `mod_timer(tx_idle_timer, +tx_idle_delay)` | `hci_qca.c` `qca_enqueue()` | 以 `l2ping -i 0.2` 打，主机 TX **全程保持 AWAKE** ⇒ 主机→控制器唤醒握手不在每包路径 |
| F4 | vk25 后控制器不再发 SLEEP_IND（`ibs_recv_slps` 2121→40）⇒ 主机 `rx_ibs_state` 不再被置 ASLEEP | `device_want_to_sleep()` `hci_qca.c:~838` | 主机 RX 恒 AWAKE ⇒ 控制器的 WAKE_IND 由 `device_want_to_wakeup()` **内联立即回 ACK**，不在每包路径 |
| F5 | `__serial_clock_on/off()` 是空 TODO 桩 | `hci_qca.c`（两函数体仅注释） | 主机的 IBS 时钟投票**对硬件无任何作用** ⇒ 排除"主机侧时钟门控"假设 |
| F6 | archive 实测：vk25（清 `EDL_TAG_ID_DEEP_SLEEP` bit0）后 `ibs_recv_sleeps` 2121→40，但 `l2ping` RTT 仍 44–97 ms | BT-2026-09-30 §6/§7 | 控制器**只是不再"通报"睡眠，实际仍在睡**：`ibs_recv_wakes` 仍在涨 |
| F7 | WCN7861 走**自定义 PERI 协议**：`qca_peripheral_setup()` 里硬编码把线路切到 8 Mbps | `hci_qca.c:2159,2178` | 运行速率由 PERI 决定，字面量 `0x15 = QCA_BAUDRATE_8000000`（`btqca.h:78`） |
| F8 | `qca_wcn7861_uses_current_baudrate()`：命中 (soc_id,rom_ver,product_id) 时**跳过** `qca_set_speed(QCA_OPER_SPEED)`(VS 0xfc48) | `hci_qca.c:2020-2029`, 调用点 `:2347` | **DT `max-speed` 可能只被用来填 NVM baud 索引，不影响线路速率**（取决于该 helper 返回值） |
| F9 | `qca_port_reopen()` 注释"Without this, we will have RTS and CTS synchronization issues" | `hci_qca.c:1849-1874` | 但它**只在 wcn399x/6750 的 `qca_regulator_init()` 路径被调用**（`:1941`）；WCN7861/Peach 走 `qca_power_on()`+PERI，**从不调用** |
| F10 | `qca_peripheral_request()` 在切 8 Mbps 后 `hci_uart_set_flow_control(hu, false)` 打开硬件流控，此后无任何代码复核 | `hci_qca.c:2032-2067` | 流控是否真生效无日志、无回读 |
| F11 | `hci_uart_set_flow_control(hu, true)` 的语义是**关闭**硬件流控 | `hci_ldisc.c:329-338`（`serdev_device_set_flow_control(hu->serdev, !enable)`） | 补丁里 toggle 的语义别搞反 |
| F12 | `btqca.h:58-80` 波特率索引表含 3000000(=14/0x0e)、4000000、3200000、8000000(=0x15) | `btqca.h` | 3 Mbps 档位控制器侧支持，H1 补丁有据 |
| F13 | geni RTS 修复（upstream `0b57d096a223`）已在树内；BT 的 cts 引脚带 `bias-pull-up`、rts 为 `output-high` | `sm8750.dtsi:4522-4537` + `qcom_geni_serial.c` | 静态看 RTS/CTS 引脚配置正确 |
| F14 | 本机 DTS：`max-speed = <8000000>` | `sm8750-lenovo-elden.dts:3004` | 激进档；上游大量 QCA 板用 3000000 |

---

## 2. 根因假设排序（按"当前证据支持度"降序）

### H4（**首推**）控制器固件自身深睡：清 NVM bit 只停了"通报"，没停"睡觉"
- **主张**：WCN7861 Brahma v2 固件在本板上自行进入深睡（唤醒需数十 ms），
  vk25 清 `EDL_TAG_ID_DEEP_SLEEP` bit0 只让固件不再发 SLEEP_IND，睡眠本身照旧。
- **支持**：F4+F6——主机两侧 IBS 握手都已不在每包路径，RTT 仍 44–97 ms；
  `ibs_recv_wakes` 仍在涨说明控制器仍在主动唤醒；
  RTT 呈"30–190 ms 展宽"而非固定量化，符合"控制器偶发不可服务"。
- **反对**：无直接反证；但缺"控制器睡眠时长 vs RTT"的直接时间线证据。
- **判别实验（**零内核改动**）**：`KEEPALIVE=1 scripts/bt-link-test.sh` —— ping 期间
  每 50 ms 发一条 `Read_Local_Version`，把控制器钉在清醒。RTT 塌回 <10 ms ⇒ H4 成立。
- **若成立的对策方向**（本轮不实现）：找一个运行期 VS 命令真正关自动睡眠；
  或接受"保活"作为可用性缓解。**不要**再试改 NVM 字节（archive 已实测 → PERI EIO）。

### H2（次推）控制器 CTS 反拉导致 geni TX 停顿
- **主张**：控制器在自身 UART RX 忙时把 CTS 拉低，geni TX 引擎停顿数十 ms，
  恰好解释"RTT 展宽大、与 IBS 改动无关"。
- **支持**：F9（该 SoC 从没做 `qca_port_reopen` 的 RTS/CTS 同步）、F10（流控无复核）、
  `qca_port_reopen` 注释本身点明该同步问题的存在。
- **反对**：若 CTS 真被拉低很久，突发写会冲垮控制器 RX 出现 HCI 乱序，
  但 archive 记录 `hciconfig errors=0`（不过静默重传仍可能 0 错误）。
- **判别实验**：补丁 `candidate-bt-no-flow-control.patch`（关硬件流控）跑 l2ping；
  RTT 收敛到常态快 ⇒ H2 成立（同时要盯 hciconfig errors 是否上升）。
- **风险**：可能在突发时冲垮控制器 RX ⇒ 只作一次性判别。

### H1（三推）8 Mbps 时钟余量不足 / 偶发误码
- **主张**：主机 geni 时钟与控制器 PLL 独立，8 Mbps 下微小频差累积成偶发字节错，
  HCI 静默重传 ⇒ 延迟 + 突发丢包。
- **支持**：F7/F8/F12/F14——速率由 PERI 硬编码 8 Mbps，档位偏高，3 Mbps 档存在。
- **反对（重要）**：PERI 阶段（brhperifw20/inv20/tmel）与随后 BT 固件下载**都是 8 Mbps
  完成的且带校验**，说明 8 Mbps 在"持续大块传输"下是通的 ⇒ 余量问题被削弱。
- **判别实验**：补丁 `candidate-bt-maxspeed-3000k.patch`（同时改 PERI 字面量+实参+DTS）。
  RTT 从"常态慢"变成"常态快" ⇒ H1；形状不变 ⇒ H1 否。
- **风险**：控制器若不支持 0x0e 档，PERI 返回非 1 ⇒ BT 初始化失败（hci0 不出现）——
  可预期、重启即回退。

### H3（大概率已排除）主机侧 IBS 唤醒握手
- **主张**：每包付一次 WAKE_IND→WAKE_ACK（100 ms 重传超时）。
- **支持**：`wake_retrans 100/113`≈88%、`ibs_recv_wakes +128/20包`（archive）。
- **反对（决定性）**：F2/F3/F4——l2ping 期间主机 TX 恒 AWAKE、主机 RX 恒 AWAKE，
  两侧握手都不在每包路径；且 archive 实测调大 `tx_idle_delay` 无效（该实验实际上
  接近空操作，因为默认已是 2000 ms）。
- **判别实验**：**不需要补丁**——新脚本直接比较 `l2ping` 前后的
  `ibs_sent_wakes` 与（可选补丁的）`tx_wait_cnt`；≈0 ⇒ H3 正式否。
  补丁 `candidate-bt-host-ibs-awake.patch` 只是把"恒 AWAKE"显式化以便排除残差。

### H6（低概率）geni RX DMA/水位导致的入站延迟
- **主张**：短 HCI event 要等 `RX_DMA_DONE|RX_EOT`（`qcom_geni_serial.c:1117-1120`）才上交，
  内部控制字符小包被延迟。
- **支持**：驱动确实按 DMA 完成/EOT 触发；IBS 控制字符是小包。
- **反对**：DMA 有 EOT/超时，延迟量级应是 µs–ms，不含 100 ms。
- **判别实验**：`btmon.snoop` 里看**主机侧**收到 event 的时间间隔（脚本已抓）。

### 已排除（不重复）
2.4G WiFi 共存、链路层 SNIFF、配对鉴权、固件未加载/波特率过低（archive §2/§3）。
`vddrfa*` 供电、`bt_en` GPIO 时序、PERI 固件名（均 archive 已确认可用）。

---

## 3. 候选补丁清单（均 `git apply --check` 通过；**未改 `linux/` 树、未 commit**）

| 补丁 | 改什么 | 区分哪个假设 | 主要风险 |
|---|---|---|---|
| `patches/candidate-bt-maxspeed-3000k.patch` | PERI `baud[]` 0x15→0x0e + PERI 实参 8000000→3000000 + DTS `max-speed` 8000000→3000000（两文件三处） | **H1** | 控制器不支持 3 Mbps 档 ⇒ PERI EIO、hci0 不出现（重启回退） |
| `patches/candidate-bt-no-flow-control.patch` | `qca_setup()` 成功后显式关硬件 RTS/CTS + 打日志 | **H2** | 突发时冲垮控制器 RX ⇒ HCI 乱序/断连，需盯 errors |
| `patches/candidate-bt-host-ibs-awake.patch` | `qca_open()` 初始 `tx_ibs_state` 由 ASLEEP 改 AWAKE | **H3 残差** | 空闲功耗略增；若 RTT 不变即彻底排除该方向 |
| `patches/candidate-bt-ibs-wait-stats.patch` | 新增 `qca->tx_wait_start/tx_wait_ms/tx_wait_cnt` 与 debugfs `ibs/tx_wait_ms`、`ibs/tx_wait_cnt` | **H3 量化**（每帧在 `tx_wait_q` 里到底等了多久/多少次） | 纯诊断，零功能风险 |
| `scripts/bt-link-test.sh` | 上机只读测试脚本（见 §4） | 全部 | 见脚本内约束 |

补丁使用（**由用户执行**，助手不碰设备）：

```sh
cd ~/y700-elden/linux
git apply --check ../patches/candidate-bt-maxspeed-3000k.patch   # 先干跑
git apply          ../patches/candidate-bt-maxspeed-3000k.patch
# 编译须加锁（若确需编译验证）：
flock /tmp/y700-kbuild.lock -c 'make ARCH=arm64 ... -j$(nproc)'
# 回退：
git checkout -- arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts drivers/bluetooth/hci_qca.c
```

---

## 4. 上机测试脚本 `scripts/bt-link-test.sh`

**只在设备上运行（用户执行）**；幂等、`timeout` 自限（默认总时长 60 s）、
只读为主、不留后台进程（btmon/keepalive 均 `timeout` 包裹 + `trap` 兜底清理）。

```sh
# 设备上（或 ssh root@192.168.7.1 'sh -s' < scripts/bt-link-test.sh）
PEER=AA:BB:CC:DD:EE:FF scripts/bt-link-test.sh
PEER=... KEEPALIVE=1 scripts/bt-link-test.sh      # 测 H4：保活 vs 不保活
PEER=... RUN_BTMON=0 scripts/bt-link-test.sh      # 跳过 btmon
PEER=... IBS_TX_IDLE=600000 scripts/bt-link-test.sh  # 临时改主机 idle，退出恢复
```

输出：`METRIC\tVALUE` 数字表（l2ping sent/recv/loss/RTT、hciconfig 错误计数、
`ibs_*` 计数器前后差值、`tx_wait_*`、keepalive 标志）+ `btmon.snoop` 原始件
（保留在 `/tmp/bt-link-test.XXXXXX/`）。脚本同时 dump `dmesg` 里 QCA 的
Product/SoC/ROM ID 行——**这是判定 F8 那个 helper 是否命中、从而判定 DT
波特率改动是否有效的必要输入**。

判读顺序（建议）：
1. `KEEPALIVE=0` 跑一次，记 RTT/loss 与 `ibs_sent_wakes_delta`、`tx_wait_cnt_delta`。
2. `ibs_sent_wakes_delta≈0 && tx_wait_cnt_delta≈0` ⇒ **H3 结案（否）**。
3. `KEEPALIVE=1` 再跑：RTT 塌回 <10 ms ⇒ **H4 成立**；否则看下一步。
4. 上 H2 补丁（关流控）跑一次 ⇒ 变快 = H2；不变再上 H1 补丁（3 Mbps）。
5. 全程用第 1 步的 RTT/loss 作基线做 A/B。

---

## 5. 剩余未知 / 需用户在设备上确认

1. **U2 的 (soc_id, rom_ver, product_id)**：决定 `qca_wcn7861_uses_current_baudrate()`
   是否返回 true ⇒ 决定 H1 补丁里 **DTS 那部分是否有效**（PERI 那部分无论如何有效）。
   由脚本的 `dmesg` 段给出。
2. **控制器是否仍在深睡**：只有 `KEEPALIVE` A/B 能回答，无需改内核。
3. **硬件流控是否真在生效**：`hci_uart_set_flow_control` 对 serdev 在 geni 上的回读
   目前没有接口；需要一个更小的诊断补丁（或改 geni 加 debugfs），本轮未做。
4. **btmon 时间线**：`btmon.snoop` 需在主机侧解析（`btmon -r`）才能区分
   "主机迟发"（H1/H2/H6）与"控制器迟回"（H4）。本轮未在无设备状态下解析。
5. **控制器固件是否有"关自动睡眠"的运行期 VS 命令**：本轮未在树内找到。
   上游/Google 未见针对 WCN7861(Brahma v2) IBS 延迟的公开修复（检索到的
   geni RTS 修复 `0b57d096a223` 已在树内）。若 H4 成立，需专项调研
   Qualcomm Peach/Brahma HAL 的电源模式命令。

---

## 6. 与既有结论的关系

- 不推翻 `archive/topics/BT-2026-09-30.md`：其"vk25 实测无效"是本轮的出发点之一。
- 新增两点对旧理解的**修正**：
  - `IBS_HOST_TX_IDLE_TIMEOUT_MS` 是 **2000 ms**（非 100 ms），所以"调大 tx_idle_delay
    无效"这个实验接近空操作，不能据此认为主机睡眠已被充分测试（F2/F3）。
  - WCN7861 的运行波特率由 **PERI 协议**决定，DT `max-speed` 可能不起作用（F7/F8）。
- 相关文件：`patches/candidate-bt-*.patch`（4）、`scripts/bt-link-test.sh`（1）。
