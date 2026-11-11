# T18 补充：充电与开机时序（2026-11-11 深夜，用户提示「USB 不充电/充电和开机有关」）

> 消费者：`TASKS/README.md` §4 T18、`reports/t18-usb-charging-triage-20261111.md`。
> 本轮只读，零写盘零重启。

## §0 结论（4 行）

| 项 | 结论 |
|---|---|
| **充电功能本身坏了吗？** | **没有**。本轮实测 `status=Charging`、`capacity=100`、`charge_counter=6900000`（满）、`input_current_limit=2000000`、`usb_type=[SDP][PD]`、`power_operation_mode=3.0A` ⇒ **正在充电** |
| **「和开机有关」的机制是什么？** | **充电策略全在 ADSP，AP 侧只是随动**。时序：ADSP 起来 **1.247 s** → **58 ms 后** `charger_pd` 报 UP（`0x1FFFFFFF` = `SERVREG_SERVICE_STATE_UP`）→ 但 **`qcom-battmgr-usb` 设备到 12.840 s 才被 healthd 发现**。**中间 11.6 s 的窗口里，AP 侧没有任何充电状态可读** |
| **那窗口里用户看到什么？** | 图标无状态/不亮。如果这期间还叠加「ADSP 侧 ICL 被拉到 0/250 mA」（见 `t18-usb-charging-triage-20261111.md` 的 `charge-watch.log` 证据），就表现为「插着不充电」 |
| **日志为何只有一行 `started`** | `/run` 是 tmpfs（每次 boot 新 inode），但当前 `charge-watch` 是 **systemd（11-05 那次）**拉起的，写的是旧 inode；`stat` 看到的是新文件 ⇒ **日志断链**，不能据「只有一行」判脚本没跑（脚本实测在跑，PID 663） |
| **我上一轮的错** | 我曾把 `state: 0x1fffffff` 读成「DOWN」并说「ADSP 起来就关掉充电」——**错的**。查 `include/linux/soc/qcom/pdr.h:13-19`：`0x0FFFFFFF`=DOWN、**`0x1FFFFFFF`=UP**、`0x2FFFFFFF`=EARLY_DOWN、`0x7FFFFFFF`=UNINIT。`0x1fffffff` 是**服务就绪** |

## §1 实测时序（本 boot，逐行原文）

```
[    0.319863] remoteproc remoteproc0: adsp is available
[    0.579728] remoteproc remoteproc0: powering up adsp
[    0.579742] remoteproc remoteproc0: Booting fw image qcom/sm8750/adsp.mdt, size 8364
[    1.247262] remoteproc remoteproc0: remote processor adsp is now up     ← ADSP 就绪
[    1.305017] PDR: Indication received from msm/adsp/charger_pd, state: 0x1fffffff, trans-id: 1
                                                                          ← 58 ms 后 charger PD UP
[   12.840297] healthd: Discovered new charger device ucsi-source-psy-pmic_glink.ucsi.02
[   12.840326] healthd: Discovered new charger device ucsi-source-psy-pmic_glink.ucsi.01
[   12.840356] healthd: Discovered new charger device qcom-battmgr-wls
[   12.840479] healthd: Discovered new charger device qcom-battmgr-usb      ← 12.84 s 才有 AP 侧节点
```

**关键窗口 = 1.305 s → 12.840 s（11.6 s）**：ADSP 的 charger PD 已 UP，但 AP 侧 power_supply 设备尚未创建
⇒ 这 11.6 s 内任何「读充电状态」的用户态（UPower / phosh 图标）都拿不到数据。

### 另一处设备链接失败（同一批，值得查）

```
[    0.327094] qcom_pmic_glink pmic-glink: Failed to create device link (0x180) with supplier 88e8000.phy for /pmic-glink/connector@0
[    0.684150] qcom_pmic_glink pmic-glink: Failed to create device link (0x180) with supplier 5-0042 for /pmic-glink/connector@1
[    0.684182] qcom_pmic_glink pmic-glink: Failed to create device link (0x180) with supplier 5-0043 for /pmic-glink/connector@0
[    3.913511] qcom_pmic_glink pmic-glink: Failed to create device link (0x180) with supplier a600000.usb for /pmic-glink/connector@1
[    3.913546] qcom_pmic_glink pmic-glink: Failed to create device link (0x180) with supplier a600000.usb for /pmic-glink/connector@0
```

`0x180` = `DL_FLAG_PM_RUNTIME | DL_FLAG_RPM_ACTIVE`。**两个 connector 都拿不到 usb/phy/typec-mux 的 device link**
⇒ 这正好解释「为什么充电状态的上游是 ADSP 而不是 AP 的 typec」：**AP 侧的 typec→usb 链接根本没建立**。

## §2 typec 现状（本轮）

```
[port0] data_role=host [device]  power_role=source [sink]  power_operation_mode=3.0A   partner=port0-partner
[port1] data_role=host [device]  power_role=source [sink]  power_operation_mode=default
```

两个端口都是 `source [sink]` —— 方括号里是**当前生效**的 role，即 **sink（受电）**，符合「正在充电」。
`port0` 有 partner（插着 PD 充电器），`port1` 无 partner（空口）。

## §3 「充电/不充电随开机变化」的三个可能机制（按可验证性排序）

| # | 机制 | 支撑 | 判据 |
|---|---|---|---|
| 1 | **ADSP 侧充电策略随 ADSP 固件启动时机变化**：`charger_pd` 在 1.305 s 就 UP，但 AP 节点 12.84 s 才有；如果 ADSP 在这 11.6 s 内按自己的默认策略（SDP 500 mA / 或 0）动作，AP 无法干预 | 时序硬证据（§1） | 连续多 boot 采样 `input_current_limit` 在 1–13 s 区间的值；需要串口或早启脚本 |
| 2 | **`pmic-glink` 的 device link 全部失败** ⇒ AP 侧 typec/usb 与 connector 没有关联 ⇒ 插拔事件可能丢失或延迟 | §1 的 5 条 `Failed to create device link` | 修 DT（补 `#power-domain-cells`/supply 或去掉该 link），看 5 条是否消失 |
| 3 | **`charge-watch` 的启动时机晚于 battmgr 节点，且轮询周期 10 s ⇒ 插电后最长 ~20 s 无人顶回 ICL** | **实测**：`/proc/663/stat` starttime=947 ticks / HZ=100 ⇒ **boot 后 9.0 s 启动**；而 `qcom-battmgr-usb` 节点 **12.84 s** 才出现 ⇒ 首轮读不到（空转），下一轮在 **~19 s**；若此刻 ADSP 把 ICL 拉到 100 mA，从插电到被顶回最长 **~20 s**。脚本注释原文自证：「the ADSP defaults it to 100 mA, which makes the tablet net-discharge even while plugged in」 | 判据 = 插电后立刻读 `input_current_limit`，若 ≤500000 且 20 s 内被改成 `current_max` ⇒ 本条成立 |

> 机制 3 是新发现且成本最低：**如果 `charge-watch` 没在跑，那么「ADSP 把 ICL 拉到 0」就没人顶回**，
> 这正好解释「插着不充电」而不需要假设固件计时器。

## §4 下一发（用户参与）

1. **确认 `charge-watch` 是否在跑**（只读）：
   `pgrep -af charge-watch; systemctl status charge-watch 2>&1 | head`
2. **复现「不充电」时立刻抓这 4 个数**（30 秒内）：
   ```sh
   for f in online input_current_limit current_now usb_type; do
     echo "$f=$(cat /sys/class/power_supply/qcom-battmgr-usb/$f)"; done
   cat /sys/class/power_supply/qcom-battmgr-bat/status
   cat /sys/class/power_supply/qcom-battmgr-bat/charge_counter
   ```
3. **判据**：若 `online=1` 但 `input_current_limit` ≤ 500000 ⇒ 机制 1/3（ADSP 拉低 + 无人顶回）；
   若 `online=0` ⇒ 机制 2（link 失败导致事件丢失）。

## §5 未做

- 未做多 boot 时序统计（需要串口抓 1–13 s 窗口，本机无串口接线）。
- 未验证 DT 修法（`pmic-glink` 的 5 条 link 失败）。
- 未改动任何服务/配置。


---

## §6 已落地的修复（2026-11-11 23:10，用户批准「3 可以修」）

### 6.1 `charge-watch.sh` 两处改动

```sh
# 1) 首轮前先阻塞等节点（原来是空转，下一轮要等 sleep 10）
wait_for_usb() {
    i=0
    while [ ! -e "$USB/online" ] && [ "$i" -lt 600 ]; do i=$((i+1)); sleep 0.2; done
    ...
}
wait_for_usb

# 2) 轮询 10 s -> 2 s
sleep 2
```

### 6.2 新增事件驱动兜底（不依赖轮询）

- `rootfs/debian/udev/90-elden-charge.rules`
  ```
  ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="USB", RUN+="/usr/local/sbin/charge-icl-fix.sh"
  ACTION=="add",    SUBSYSTEM=="power_supply", ATTR{type}=="USB", RUN+="/usr/local/sbin/charge-icl-fix.sh"
  ```
- `rootfs/debian/usr-local-sbin/charge-icl-fix.sh`（只做一次，不常驻；与 charge-watch 互补）

> 注：写 sysfs 用 `RUN+=` 调脚本，**不能**用 `ATTR{...}=` 赋值——power_supply 的属性是函数，
> 必须走 store 回调。

### 6.3 上机验证（本机实测）

```
== 部署后 ==
systemctl is-active charge-watch  -> active
online=1  icl=2000000  max=2000000      # 判据满足
/run/charge-watch.log:
  23:09:29 started
  23:09:29 usb node appeared after 0 s   # 新的 wait_for_usb 生效
```

**逻辑验证（用假 sysfs 模拟 cur<max）**：
```
before: 100000
after : 3000000   (期望 3000000)   -> 通过
```

**未能做的负向测试**：`echo 100000 > input_current_limit` 报 `I/O error`
（驱动拒绝手动降档），所以「ADSP 拉低后能否顶回」只能等真实重插事件复现。

## §7 顺带修掉的干扰源（用户要求「免得老是干扰判断」）

`patches/dt/0001-...-ramoops-record-size.patch`（项目里 **2026-10-22 就写好了**、注释推理与本次完全一致）
**从未应用到 `build/daily`**。本轮已：

1. `git apply` 到 `build/daily`（干净应用）；
2. 重建 DTB：`ramoops` 从 4 MiB / 无 `record-size` → **8 MiB + `record-size=0x200000` + `pmsg-size=0x400000`**
   ⇒ `dump_mem_sz` 从 **0** 变成 **2 MiB**，`persistent_ram_write` 有了合法目标区；
3. 重打包镜像 `build/exp-cmdline/boot-elden-vk187b-ramoopsfix.img`
   （kernel / ramdisk **逐字节不变**，只换 DTB，脚本自证 `SAME/SAME/SAME`）。

**这直接针对三臂崩溃点**（`free_initmem` → `ramoops_pstore_write` → `memcpy_toio` 写坏地址）。
