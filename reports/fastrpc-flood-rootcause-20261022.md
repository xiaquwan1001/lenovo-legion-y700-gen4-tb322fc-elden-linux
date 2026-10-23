# fastrpc `-22` 刷屏根因：模块树 ABI 与内核不匹配（2026-10-22）

> 任务来源：`TASKS/README.md` §5 Q28 遗留项「7.3 线 `fastrpc` `-22` 刷屏（300+ 行/发）未修」。
> 结论：**不是 fastrpc 驱动 bug，也不是 DT 缺属性；是 `/lib/modules/<UTS>` 符号链接指到了错误 ABI 的模块树。**

## 1. 现象（修前）

- `dmesg` 里 `FastRPC Domain not specified in DT` + `rpmsg_dev_probe: failed: -22` 持续刷屏。
  实测 **23 min 内 2941 行**（约 2 行/s 稳态），每行三联（`Domain not specified` / `rpmsg_dev_probe: failed` / `probe with driver ... failed`）。
- **`/dev/fastrpc-adsp`、`/dev/fastrpc-cdsp` 根本不存在** ⇒ SSC 传感器全废（`HasAccelerometer=false`）。
- 之前被记录为「刷屏，与显示无关」——**严重程度被低估**：它其实是 fastrpc 从未 probe 成功。

## 2. 取证（kprobe，设备侧零构建）

`qcom_glink_work` → `rpmsg_register_device()` → `device_add()` → `rpmsg_dev_probe()` → `fastrpc_rpmsg_probe()`，
在 `fastrpc_rpmsg_probe` 入口读 `rpdev->dev` 的字段：

| 探针 | 值 | 含义 |
|---|---|---|
| `+624` | `0xffff000b7e12c860` | 真实 DT 节点指针（`fastrpc` 节点，带 `label="adsp"`） |
| `+680` | `0x0` | **驱动读的「of_node」= NULL** |
| `+688` | `0xffffbd35ddd286e8` | 非空 |

同一批 trace 里 `qcom_glink_work` 对 `+624` 那个节点调 `of_property_read_string(…, "qcom,glink-channels")` **返回 0（成功）**，
而 `fastrpc_rpmsg_probe` 读 `label` 返回 `-EINVAL`。**同一节点、同一函数、两种结果** ⇒ 不是节点问题，是**偏移问题**。

反汇编确认：
- 在机内核 `vmlinux`（`CONFIG_SUSPEND` **未设**）：`struct device.of_node` 在 **624**（pahole 一致）。
- 部署的 `fastrpc.ko`（`-abi-suspend` 那套）：`ldr x0, [x21, #680]`。

## 3. 根因

```
/lib/modules/7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty
   -> ...-abi-suspend          ← 错：CONFIG_SUSPEND=y 编的，struct device.of_node = 680
```

`CONFIG_SUSPEND=y` 让 `struct dev_pm_info` 变大，`struct device` 里 `of_node` 从 624 后移到 **680**（+56 B）。

来历：2026-10-18 vk128/vk129 做「开 CONFIG_SUSPEND」实验时建了 `-abi-suspend` 模块树并切了链接；
实验失败作废后 **vk127/vk145 都回到 `SUSPEND=n`，但链接没切回来**。

**vermagic 拦不住**：它只比 UTS 字符串（`7.3.0-rc7-debug-vk127-…`），而两套模块树的 UTS 是**逐字相同**的（同一 PINUTS 策略）。
⇒ 这是「模块树 ABI 与内核 config 不一致」的静默失败，比 vermagic 失配更隐蔽。

## 4. 修法（已在机执行）

```bash
KV=/lib/modules/7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty
ln -sfn ${KV}-abi-nosuspend $KV
depmod -a 7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty
modprobe -r fastrpc; modprobe fastrpc
```

另加 udev 规则持久化设备权限（默认 `root:root 0600`，而 `hexagonrpcd` 以 `fastrpc` 用户跑）：

```
# /etc/udev/rules.d/82-fastrpc-perm.rules
SUBSYSTEM=="misc", KERNEL=="fastrpc-*", GROUP="fastrpc", MODE="0660"
```

## 5. 验收（修后实测）

| 项 | 修前 | 修后 |
|---|---|---|
| `Domain not specified` 增长 | ~6 行/5 s | **0 行/6 s** |
| `/dev/fastrpc-adsp` | 不存在 | **存在** |
| `/dev/fastrpc-cdsp{,‑secure}` | 不存在 | **存在** |
| `hexagonrpcd-adsp-sensorspd` | failed | **started** |
| `iio-sensor-proxy` | failed | **started** |
| `HasAccelerometer` / `HasAmbientLight` / `HasProximity` | false | **true / true / true** |
| `monitor-sensor` | 「Waiting…」后失败 | `Has accelerometer (tilt: face-up)` **实时出值** |
| 相机栈 `camera-modules-load.sh` | — | `1 media, 17 video nodes` |

## 6. 遗留 / 需并入 SSOT

1. **`SMR mask 0x20 out of range for SMMU (0x2)`**（CDSP `compute-cb@14`，12 次，**不增长**）
   —— 修后仍在，属 CDSP 侧既有 DT/驱动问题，与本次 ABI 无关，未处理。
2. **同型隐患**：任何「同 UTS 不同 config」的模块树都会静默失效。建议在 `scripts/check-doctor.sh`
   加一条硬门：比对 `/proc/config.gz` 与模块树来源 config 的关键 ABI 项（至少 `CONFIG_SUSPEND`、`CONFIG_PREEMPT`、
   `CONFIG_DEBUG_LOCK_ALLOC`、`CONFIG_LOCKDEP`、`CONFIG_NUMA`）。
3. 建议把 `-abi-suspend` 目录改名加 `DO-NOT-LINK` 前缀，防止再次误切。
