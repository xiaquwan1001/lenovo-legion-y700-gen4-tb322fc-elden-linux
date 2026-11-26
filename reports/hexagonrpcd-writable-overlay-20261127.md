# ★ 可写 overlay 落地：DSP 的 registry 写入**真落盘**（+ 传感器仍全绿）

> 2026-11-27 续轮（承接 WIP 报告，现为交付版）。目标：DSP 对 `/persist/sensors/registry/**` 的写不再"假成功"。

## 0. 结果（设备实测）

```
elden-sensorspd  active   NRestarts=0        iio-sensor-proxy active
HasAccelerometer=true  HasAmbientLight=true  HasProximity=true
ssccli --sensor accelerometer → X=-1.18 Y=-0.62 Z=9.52 m/s²（连续）
systemctl --failed → 0

/var/lib/hexagonrpc （overlay，72 KB，4 个非空文件）
  mnt/vendor/persist/sensors/cam_registry_dump.txt      18628 B
  mnt/vendor/persist/sensors/registry/fstempfile        14328 B
  mnt/vendor/persist/sensors/registry/sns_reg_version       9 B   ("version=3")
  mnt/vendor/persist/sensors/registry/registry/DIR          3 B   ("DIR")
```

## 1. 关键两处（都踩过）

1. **`fwrite` 的 def 不能多写一个 WORD**：`in sequence<byte>` 的 **size word 就在 prim buffer 里**，
   def 应为 `WORD(fd) + BLOB_SEQ + OUT_BLOB + OUT_BLOB`。之前写成 `WORD, WORD, BLOB_SEQ, …` ⇒ DSP 实测
   `Method 5 invoked with less arguments than expected`（本轮用带方法号的诊断一发定位）。
2. **签名不匹配不该 abort 监听循环**：原实现 `return 1` 会结束 `run_fastrpc_listener`，DSP 停在半 attach（三属性 false）。
   改成「回 `AEE_EBADPARM` + 4 字节零 outbuf + 继续服务」后，猜错签名只是该方法失败，不影响整体；也正是靠这条才迭代出正确 def。

顺带把方法表改成**指定下标初始化**（`[N] = {…}`），彻底避免 `PITFALLS #742` 的索引漂移。

## 2. overlay 设计（`-O DIR`）

- 写模式打开：`apps_std_copyup()` 先把 mapped 树里原文件内容拷进 overlay（不存在则建空文件），再 `open(O_RDWR[|O_APPEND])`；
  返回 fd + `OVERLAY_FD_BASE(1000)` 与虚拟 fd 区分。
- `fread/fwrite/fseek/fclose/fsync` 按 fd 区间分派；`fremove/frename/mkdir/rmdir/ftrunc/ftell/flen/fileExists` 走 overlay。
- 覆盖目录 `/var/lib/hexagonrpc`（`fastrpc:fastrpc`），可备份/可回滚；`-R` 树保持只读。

## 3. 判据（照抄）

```sh
ssh elden 'systemctl is-active elden-sensorspd; systemctl show -p NRestarts elden-sensorspd'   # active / 0
ssh elden 'find /var/lib/hexagonrpc -type f -size +0c | wc -l'                                  # ≥3
ssh elden 'busctl get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasAccelerometer'  # b true
```

## 4. 残留 / 下一步

- `fstempfile` 每 boot 会重新生成（DSP 写临时文件→rename 提交；我们已实现 `frename`，但临时文件是否清理取决于 DSP 流程），**不视为缺陷**。
- 仍未实现：`mkdir/rmdir/ftrunc` 的 def 未验证（已写实现，未进表），若 DSP 后续报 `Method 29/30/32 … mismatch` 再逐个补 + 上机验。
- 上游：#29 仍 open；我们现在有「0 字节占位 + 扁平 `-R` + `fwrite` 签名 + 可写 overlay」四条一手经验，**回帖需用户放行**。
