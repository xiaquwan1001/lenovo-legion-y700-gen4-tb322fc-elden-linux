# Q26 WiFi Step A（`CONFIG_ATH12K=m` 单次干净探测）— 证伪（2026-10-06 深夜）

> 过程证据（archive，只增不改）；结论口径以 `TASKS.md` §5 Q26 为准。
> 上一轮收口手册：`WIFI-BMISS-2026-10-06.md` §13.3 Step A。
> 设备：U2 `HA2EXB0E`（fastboot），本实验全程 `fastboot boot` **零写盘**。

---

## 0. 结论摘要（数字）

- **Step A 假设证伪**：`ath12k=m` 使内置首探消失、WCN 在芯片就绪后**只探一次且 MHI POWER_ON 首次成功**
  （`mhi0: Power on setup success`，无 `-110`），但连 `P40 Pro` 后 **bmiss 拆链仍每 ~16 s 一次**，
  `beacon rx` 仍 ≈1，130 s 无 IPv4。⇒ 「半初始化态 = 2 s 拍子根因」不成立。
- 根因与探测时序无关，回到 §13.2 既有结论：**固件对已关联 vdev 的休眠/唤醒调度**（AP 组合相关）。
- **新踩坑（重要）**：`ath12k=m` 经 Kconfig `select PCI_PWRCTRL_PWRSEQ if HAVE_PWRCTRL` **连带**把
  PCIe 电源序列驱动降为 `=m`；而内置 `qcom-pcie` 在 initcall 阶段 probe，此时模块未加载
  ⇒ **PCIe host init 失败、无任何 PCI 设备、wifi 完全没有**（易被误判成「wifi 驱动坏」）。
  详见 `PITFALLS` #125。

---

## 1. 构建与启动（可复现）

| 项 | 值 |
|---|---|
| 源码 | `bd114ca33`（= vk47clean）；worktree `~/wt-athm`（detached） |
| config | `~/wt-wifibmiss/.config` + `CONFIG_ATH12K=m`（LOCALVERSION_AUTO 关） |
| LOCALVERSION | `-vk47clean-gbd114ca335e1`（与磁盘 `/lib/modules/<UTS>/` 对齐） |
| UTS | `7.2.0-debug-vk47clean-gbd114ca335e1` |
| ramdisk | `out/initramfs-full-elden.cpio.gz`（含固件） |
| boot.img | `out/boot-elden-athm.img` sha256 `3f74dc0f646022ea…`（83 042 304 B） |
| 构建脚本 | `scripts/build-athm-probe.sh athm`（`timeout -k 30 2700`，MAKE_EXIT=0，0 error） |

启动：`fastboot boot out/boot-elden-athm.img`（第一次报 `Failed to load/authenticate boot image: Load Error`，
`fastboot reboot bootloader` 后重试即 OK —— 与本镜像本身无关）。

## 2. 第一次启动：PCIe 失败（配置连带 bug）

- 现象：进桌面、SSH 通，但 `/sys/bus/pci/devices/` **空**；`/sys/kernel/debug/devices_deferred` 有
  `1c00000.pcie  qcom-pcie: cannot initialize host`；boot log 里 `qcom-pcie` host bridge 反复 probe（13 次）。
- 根因：`make olddefconfig` 因 `ATH12K=m` 把 `CONFIG_PCI_PWRCTRL_PWRSEQ` 由 `=y` 改成 `=m`
  （`drivers/net/wireless/ath/ath12k/Kconfig: select PCI_PWRCTRL_PWRSEQ if HAVE_PWRCTRL`）。
- **免重建验证**：把 `pci-pwrctrl-pwrseq.ko`（+`pwrseq-pcie-m2.ko`）scp 到设备 `/lib/modules/<UTS>/`、
  `depmod -a`、`modprobe` ⇒ `qcom-pcie` deferred-probe 重试成功，PCIe 枚举 `0000:00:00.0` + `0000:01:00.0`，
  `ath12k_wifi7_pci` 立即 probe。

## 3. ath12k 探测时序（干净单次，证据）

```
[  532.413] mhi mhi0: Requested to power ON
[  532.413] mhi mhi0: Power on setup success          <-- 首次成功（旧 boot 此处 -110 超时）
[  532.937] ath12k_wifi7_pci 0000:01:00.0: chip_id 0x2 chip_family 0x4 board_id 0xff soc_id 0x40210200
[  532.937] ... fw_version 0x100effff ... WLAN.GNG.1.0-03869-...
[  532.957] qmi TME-L power-on hardware-restricted (stock-compatible, continuing)
[  533.045] qmi FW_INIT_DONE received ...
[  538.970] wlan0: authenticate with 1e:31:5d:c7:98:8e    <-- ~7 s 后关联
[  539.016] wlan0: associated
```

## 4. 关联后 130 s 观测（判据失败）

AP = `P40 Pro`（5 GHz，5745 MHz，BSS `1e:31:5d:c7:98:8e`，-52 dBm）。

| t | beacon_rx | lost（累计 dmesg） | IPv4 |
|---|---|---|---|
| +0 s | 1 | 4 | 无 |
| +53 s | ~1 | 7 | 无 |
| +106 s | ~1 | 13 | 无 |
| +126 s | ~1 | 15 | 无 |

掉线样本（每 ~16 s 一次，与旧结论一致）：

```
[ 790.240] ath12k_wifi7_pci 0000:01:00.0: failed to flush transmit queue, data pkts pending 1
[ 790.378] wlan0: Connection to AP 00:00:00:00:00:00 lost
[ 807.904] ath12k_wifi7_pci 0000:01:00.0: failed to flush transmit queue, data pkts pending 1
[ 808.022] wlan0: Connection to AP 00:00:00:00:00:00 lost
```

⇒ 与内置首探的旧 boot **逐现象一致**。Step A 无可见收益。

## 5. 处置

- 按 §13.3：「Step A 失败 ⇒ 进 Step B」；但 Step B（remove/rescan 或改「首探后不二次 bind」）针对的仍是
  探测时序，而本实验已证**探测时序不是变量** ⇒ Step B 无意义，直接走 **Step C（按 AP 组合已知限制归档）**。
- 日常使用真 AP（`ustcnet` 首 90 s 0 bmiss，2026-10-06 已实测）；不新增第二套 supplicant（#117）。
- 遗留资产：`out/boot-elden-athm.img`（可复现）；设备 `/lib/modules/<UTS>/` 新增
  `ath12k.ko`/`ath12k_wifi7.ko`/`pci-pwrctrl-pwrseq.ko`/`pwrseq-pcie-m2.ko`（零写盘 boot 内容，重启不保留；
  若后续持久根清理需移除）。

## 6. 追加活证据：换 AP 即恢复（2026-10-06 深夜，用户现场）

同一 `athm` 启动会话内，用户临时开启 **`vivo X200 Ultra`** 热点，平板**立刻连上并拿到 IP**：

| 指标 | P40 Pro（5 GHz） | vivo X200 Ultra（2.4 GHz） |
|---|---|---|
| IPv4 | **无**（130 s+） | **`10.191.87.31/24`** + IPv6（秒级） |
| signal | -52 dBm | -17 dBm |
| `beacon rx` | ≈1（几乎不动） | 154（持续增长） |
| 关联后 dmesg | `failed to flush transmit queue` + `Connection to AP 00:00…lost` 每 ~16 s | 仅一次 `DEAUTH_LEAVING (Reason 3)` 本地重连，无 bmiss 拆链 |

⇒ **同一内核、同一模块、同一探测路径**，AP 一换即正常。**坐实「P40 Pro 热点组合已知限制」**，与驱动/探测时序无关。
（注：`vivo` 会话内 `beacon loss: 24` 为累计计数，含切换时的重连；`beacon interval=100`。）


---

## ⚠️ 2026-10-08 口径更正（只增不改，目标结论以 `TASKS.md §5 Q26` 为准）

本文结论「坐实『P40 Pro 热点组合已知限制』，与驱动/探测时序无关」**已撤销**：用户指出同一 P40 Pro 在早期版本可正常连接 ⇒ 现假设为**版本/DTB 增量连带副作用**（详见 `TASKS.md §5 Q26`）。本文有效保留部分 = **`CONFIG_ATH12K=m` / 探测时序不是变量**（该证伪成立），不再据此推出「AP 组合限制」。
