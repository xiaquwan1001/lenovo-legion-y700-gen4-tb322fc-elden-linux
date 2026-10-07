# 熄屏掉电 — 真实路径复现 + 方法学更正（2026-10-07）

> 过程证据（archive，只增不改）；结论口径以 `TASKS.md` Q24 / `PITFALLS` #124 为准。
> 设备 U2 `HA2EXB0E`。本轮起点：用户报告"当前版本熄屏/锁屏不再关机"。

---

## 0. 结论摘要

1. **方法学更正（重要）**：`wlr-randr --output DSI-1 --off` 与 `modetest -M msm -w 36:DPMS:3`
   在本机**都是无效操作**——命令返回 rc=0，但读回 `card0-DSI-1/dpms` 仍 `On`（`modetest -c` 的 DPMS value 仍 0）。
   ⇒ 之前会话 E1/E2「wlr-randr/modetest 关 DSI → 复位」的测试**未真正 blank**，其结论不可信。
2. **真实 blank 路径 = `org.gnome.ScreenSaver.SetActive(true)`**（gsd-screensaver）→ 实测 `dpms` 变 `Off`，
   这是与"锁屏/熄屏"对应的路径。
3. 用真实路径在 **boot_b（vk61，vk47clean+openrc）** 上**稳定复现掉电**：触发后 ~6 s 断，
   `powerlog` 空（非用户态关机）、`blankspy` 心跳截断、`kmsg` 无输出、pstore 空 ⇒ **瞬时硬件断电**。
4. 掉电与以下条件**都不是单变量**（均复现掉电）：USB 数据线（legacy 与 openrc 两种模式）、
   **仅 VBUS**（gadget 已解绑）、**纯电池**（`usb online=0`）、**DP 显示器插着**。
5. **唯一存活数据点**：`fastboot boot out/boot-elden-sd-base.img`（vk47 基线，wt-sleepdeath 树，openrc）
   + 真实路径 **8/8 轮存活**（`dpms` Off→On，无断）。该结果在 boot_b 上**未复现**。
   ⇒ 存活/死亡的差异收敛到**镜像本身**（sd-base vs boot_b），待单变量确认。

## 1. 复现命令（真实路径）

```sh
# 设备上（需 phoc 的 session bus）
P=$(pidof phoc); D=$(tr '\0' '\n' < /proc/$P/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
export DBUS_SESSION_BUS_ADDRESS="$D" XDG_RUNTIME_DIR=/run/user/0
gdbus call --session --dest org.gnome.ScreenSaver \
  --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive true
# 判据：cat /sys/class/drm/card0-DSI-1/dpms  -> Off
```

**无效命令（勿再用作 blank 触发）**：
```
wlr-randr --output DSI-1 --off      # rc=0 但 Enabled: yes / dpms 仍 On
modetest -M msm -w 36:DPMS:3        # rc=0 但 value 仍 0
```

## 2. 数据矩阵（真实路径）

| # | 镜像/模式 | 外部供电 | DP | 结果 |
|---|---|---|---|---|
| S1 | `sd-base`（fastboot RAM，openrc） | 不明 | 插 | **存活 ×8** |
| D1 | legacy（vk47clean，boot_b） | USB 数据 | 无 | 断电 |
| D2 | openrc（vk47clean） | USB 数据 | 无 | 断电 |
| D3 | openrc（vk47clean） | 仅 VBUS（gadget 解绑） | 无 | 断电 |
| D4 | openrc（vk47clean） | 纯电池 | 无 | 断电 |
| D5 | openrc（vk47clean） | 纯电池 | 插 | 断电 |

D1–D5 均：`powerlog` 空、`blankspy` 截断、无内核输出 ⇒ 同一"瞬时断电"现象。
S1 与 D5 外设条件相同（DP 插、无 USB）而结果相反 ⇒ 变量在**镜像**，不在外设。

## 3. 待确认与假设

- **存活/死亡由镜像决定**：`sd-base`（wt-sleepdeath 树、UTS `sd-base`、磁盘上无该 UTS 模块目录
  ⇒ 相机等 `=m` 模块**不加载**）vs `boot_b`（vk47clean、相机 `=m` 模块**全加载**）。
- 头号假设：**某些 `=m` 模块（相机 camss/传感器/wl2868c 等）的加载改变了面板 disable 时的供电状态**。
  验证受阻：相机模块**在用时无法 `rmmod`**（绑定传感器）。改走「禁用加载+黑名单」后**仍被加载**（12 个）
  —— 黑名单 `modprobe --showconfig` 已生效（`blacklist qcom_camss` 在内）但模块依旧载入，
  说明加载路径不是可被 blacklist 拦住的 udev autoload（或来自 RAM initramfs），**未定位**。
- 次假设：RAM initramfs 的 `/init` 版本（sd-base 用旧 full ramdisk，boot_b=原 ramdisk 换新 `/init`）。

## 4. 誠实结论（未判定）

**本轮未能判定熄屏掉电的根因，也未能确认「存活/死亡由镜像决定」**。已知：
- 可靠复现器 = `ScreenSaver.SetActive(true)`（真实路径）；断电为瞬时、无用户态标记、无内核输出。
- 已排除「仅 USB / 仅 VBUS / 仅电池 / 仅 DP 显示器」作为单变量。
- 唯一存活样本 = `sd-base`（fastboot RAM，无相机模块）×8；**未能复现到 boot_b**，也未能隔离出
  sd-base 与 boot_b 的哪个差异（模块 / RAM-init / 内核构建）是关键。
- 相机模块假设未证实（无法控制其不加载）。
- **下一步建议**：用真实触发重跑项目自带 `sd-*` 二分（先修 `g1-22-dpms-test.sh`，已修）；
  或做「去掉相机模块的干净镜像」单变量。均需 `fastboot boot`（会引入 USB/VBUS，需注意）。

## 5. 工具/纪律

- 触发用 `ScreenSaver.SetActive`；取证用 `blankspy.sh` + `/root/powerlog.txt`（用户态关机标记）+ `kmsg`。
- 断电后：USB 插着会长按 VBUS **自动开机**（表现为"重启"）；纯电池则真关机，需物理按键。
- 每次切镜像都要插 USB（fastboot），这本身引入 VBUS —— 单变量时注意。
