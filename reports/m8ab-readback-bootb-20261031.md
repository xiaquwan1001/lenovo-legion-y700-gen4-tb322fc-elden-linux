# M8 收尾：boot_b 完整读回备份（2026-10-31）

> 只读操作；全部命令经 `scripts/device-lock.sh -w 600` 包裹；未执行恢复写入。

## 结论（数字）

| 项 | 值 |
|---|---|
| 读回方式 | 分段 6×16 MiB（`dd iflag=skip_bytes,count_bytes`，ssh 单段 timeout -k 10 85 s） |
| 总耗时 | **87 s**（单次 dd 90 s 截断问题的绕过方式得到验证） |
| 读回文件大小 | **100 663 296 B**（= 分区原大小，逐字节无缺口） |
| 读回 sha256 | **`aedae5f121ecbe5cc6f5de59a14ae5ba3680229d619c49cedee0d6cf8b9b4765`** |
| 参照值来源（reports/m8ab-restart-20261030.md §3 与总管实测） | 基线臂 `2ba252cc…`（10-30 上午刷入臂）；总管本轮实测在机 `aedae5f1…`（boot_id 84e8602c） |
| 判定 | 读回 = **在机当前实际值** `aedae5f1…` ✓；≠ 基线臂 `2ba252cc…`（boot_b 在 10-30 晚间已被后续 daily 刷入覆盖，属预期演进） |

## bootslot-b 各镜像 sha 对账

| 文件 | sha256 |
|---|---|
| `bootslot-b/boot_b-vk181-daily-signed-20261029.img` | `b72866ef6e6c8248a617c4b39b7fb1a5db07903bfc2ffa711e9223f0ea67d1e9`（= 10-29 报告记录 ✓，文件完整） |
| `bootslot-b/boot_b.img`（10-30 19:04 最新） | `aedae5f1…`（= 在机当前值 = 本次读回 ✓） |
| `bootslot-b/boot_b-m3v5-daily-signed-20261030.img` | `55d06551…` |
| `bootslot-b/boot_b-pre-vk183-20261030.img` | `e6b1124c…` |
| `backup/.../boot_b-before.img`（M8 刷前） | `caaa171c…`（= §3 记录 ✓） |
| `backup/.../boot_b-base-before-restore.img`（10-30 中断的截断件） | `2ba252cc…`（= 基线臂，完整无缺；此前以为截断 32 KiB，实测该文件 sha 已等于基线臂——但本次新读回为准） |

## 「能否安全恢复 vk181」一句话结论

**能**：`bootslot-b/boot_b-vk181-daily-signed-20261029.img` 完整且 sha 与 10-29 记录一致，随时可
`fastboot flash boot_b bootslot-b/boot_b-vk181-daily-signed-20261029.img`（或 EDL/dd）整块写回 `boot_b` 后读回校验 sha=`b72866ef…`；
恢复前建议先把本次读回的当前分区镜像（`aedae5f1…`，已存档）作为回退件。

## 复现命令

```bash
# 分段读（每段 16 MiB，ssh 单段 ≤85 s）
for s in 0 16777216 33554432 50331648 67108864 83886080; do
  ssh root@192.168.7.1 "dd if=/dev/disk/by-partlabel/boot_b iflag=skip_bytes,count_bytes skip=$s count=16777216 bs=1M" >> boot_b-readback.img
done
sha256sum boot_b-readback.img   # 期望 = 在机实际值
```

产物：`backup/HA2EXB0E-16+512/m8ab-restart-20261030/boot_b-readback-20261031.img`（100 663 296 B）。
