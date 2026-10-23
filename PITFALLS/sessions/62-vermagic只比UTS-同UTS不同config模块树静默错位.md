## 六十二、`vermagic` 只比 UTS 字符串——**同 UTS 不同 config 的模块树会静默用错 struct 偏移**（#367，2026-10-23 实受）

### 现象

7.3 线上 `fastrpc` 用 `-22` 刷屏（23 min 内 **2941 行**，稳态约 2 行/秒），三联：
```
qcom,fastrpc …: FastRPC Domain not specified in DT
qcom,fastrpc …: rpmsg_dev_probe: failed: -22
qcom,fastrpc …: probe with driver qcom,fastrpc failed with error -22
```
同时 **`/dev/fastrpc-adsp` / `/dev/fastrpc-cdsp` 根本不存在** ⇒ SSC 传感器全废
（`HasAccelerometer=false`、`monitor-sensor` 报 "Failed to claim accelerometer"）。

此前该现象被记录为「7.3 线既有刷屏，与显示无关」并**低估了严重程度**——实际是 fastrpc 从未 probe 成功。

### 取证路径（kprobe，设备侧零构建）

`qcom_glink_work` → `rpmsg_register_device()` → `device_add()` → `rpmsg_dev_probe()` → `fastrpc_rpmsg_probe()`。

```bash
D=/sys/kernel/debug/tracing
: > $D/kprobe_events
echo 'p:fp fastrpc_rpmsg_probe rpdev=$arg1 of=+680($arg1):x64' >> $D/kprobe_events
echo 'p:ofp of_property_read_string node=$arg1 prop=+0($arg2):string' >> $D/kprobe_events
echo 'r:ofpr of_property_read_string ret=$retval' >> $D/kprobe_events
# 开 events/kprobes/{fp,ofp,ofpr}/enable + events/kprobes/enable，读 $D/trace
```

实测（矛盾点）：
- `qcom_glink_work` 对某 DT 节点读 `"qcom,glink-channels"` → **ret=0（成功）**
- `fastrpc_rpmsg_probe` 对同一节点读 `"label"` → **ret=-EINVAL**
- `fastrpc_rpmsg_probe` 入口处 `+680` = `0x0`

**同一节点、同一函数、两种结果** ⇒ 不是节点问题，是**偏移问题**。

反汇编确认：
```
# build/m1-73/vmlinux（SUSPEND=n）
ffffffff... <fastrpc_rpmsg_probe>:  ldr x0, [x21, #624]     ← 内核自己的 offsetof(of_node)

# 部署在设备的 fastrpc.ko（-abi-suspend 那套）
d84:  ldr x0, [x21, #680]                                    ← 模块假设的偏移
```

### 根因

```
/lib/modules/7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty
   -> …-abi-suspend        ← 错：CONFIG_SUSPEND=y 编的，of_node @ 680
```

`CONFIG_SUSPEND=y` 让 `struct dev_pm_info` 变大 ⇒ `struct device` 里 `of_node` 从 **624 → 680**（+56 B）。

来历：2026-10-18 vk128/vk129 做「开 CONFIG_SUSPEND」实验时建了 `-abi-suspend` 模块树并切链接，
实验失败作废后 **内核回到 `SUSPEND=n`，但链接没切回来**。

**`vermagic` 拦不住**：它只比 UTS 字符串（`7.3.0-rc7-debug-vk127-…`），
而两套模块树用同一 PINUTS 策略、UTS **逐字相同**。

### 同一根源的第二个症状

`build/m1-73/.config` 也遗留了 `CONFIG_SUSPEND=y`（同一次实验没还原）。
用它编出的 `vk146` 上机 = **「背光亮一下即掉电」**，与 vk128/vk129 逐字同型。
差点被误判成「fastboot boot 假成功」。

### 判据（怎么快速确认是这个坑）

- `dmesg | grep -c "<某 driver> … failed"` 持续增长（不是开机一次性）
- 该驱动对应的 `/dev/*` 节点不存在，但模块 `lsmod` 在
- 决定性：`pahole -C <struct> vmlinux | grep <field>` 取偏移，
   与该 `.ko` 里 `ldr … [reg, #N]` 的 N 对比；或用 kprobe 同时探「同一字段 + 正常工作的调用方」

### 治法

```bash
KV=/lib/modules/$(uname -r)
ln -sfn ${KV}-abi-nosuspend $KV        # 切到与在机内核 config 一致的那套
depmod -a $(uname -r)
modprobe -r fastrpc && modprobe fastrpc
```

并把**错树改名**防复发：`mv ${KV}-abi-suspend ${KV}-abi-suspend-DO-NOT-LINK`。

### 门禁（已落地）

- `scripts/check-abi-config.sh`：比对 `.config` 的 27 项 ABI 敏感项（`SUSPEND`/`PM_SLEEP`/`LOCKDEP`/
  `NUMA`/`PREEMPT`/`VA_BITS`/页大小/`MODVERSIONS` …）与 SSOT 参考 config。
- 接入 `scripts/assert-kernel-sane.sh` §1b：**打包前**不一致即拒绝出镜像。
- 接入 `scripts/check-doctor.sh` §5f：构建树 `.config` 漂移 FAIL；并打印
  `pahole` 得到的 `struct device.of_node` 偏移，供与模块树对照。

### 与既有 config-ABI 条目的区别

- 早先那条「改 config 会改 ABI ⇒ 模块不重编早期 panic」——症状是直接崩。
- 早先那条 `make olddefconfig` 不带 ARCH 把 config 写成 x86。
- **#367**（本条）：**模块树链接指向了另一套 ABI 的树**，两份都"能装能用"，只是**字段读错位**。
  比早先那条隐蔽：不崩、不警告，只是某个驱动永远 probe 失败。
