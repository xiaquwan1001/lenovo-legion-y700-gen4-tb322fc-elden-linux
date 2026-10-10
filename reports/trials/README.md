# reports/trials/ — 设备实验记录（机器可读）

> 由 `scripts/trial.sh` 写入。每次上机实验 = 一个 JSON record + 一行 `index.tsv`。
> 纪律：**无 record 不得在文档里写 verdict**（见 `scripts/trial.sh` 头部、`.pi/plans/2026-10-10-迭代流程优化.md`）。

## 文件

- `<UTC时间戳>-<label>.json`：一条实验记录（字段见下）。
- `index.tsv`：`ts label vk reset deploy verdict image_sha log_dir`，供 `rg`/`awk` 快速筛选。
- `<UTC时间戳>-<label>/`：原始证据目录（`dmesg.txt` / `probe.txt` / `env.txt`）。

## record 字段

| 字段 | 含义 |
|---|---|
| `vk` / `image` / `image_sha256` | 构建号与镜像指纹 |
| `manifest` / `kernel_uts` / `kernel_payload_sha256` / `config_sha256` / `dtb_packed_sha256` | 从 manifest 取的身份四元组（缺 manifest 则为空 → 不可复现） |
| `reset_type` | `por`（真断电）\| `cold`（冷 fastboot）\| `warm`（暖复位）——**复位敏感问题禁 `warm`**（PITFALLS #166） |
| `deploy` | `none` / `fastboot-boot` / …（谁载入的） |
| `probe` / `verdict` | 探针与判定（如 `q28` → `GOOD`/`STORM`/`NOCARD`/`NOROUTE`） |
| `log_dir` / `note` | 证据目录与备注 |

写法示例：

```bash
scripts/trial.sh gate                                  # 前置：查 boot_b succ/retry
scripts/trial.sh run --label q28-det --image out/boot-elden-vk86-round2.img \
  --reset por --deploy fastboot-boot --probe q28 --note "确定性门 1/2"

# 已有日志目录时（不碰设备）
scripts/trial.sh record --label sleep-sweep-1 --image out/boot-elden-vk64.img \
  --reset por --verdict STORM --logdir logs/sleep-sweep-xxx
```
