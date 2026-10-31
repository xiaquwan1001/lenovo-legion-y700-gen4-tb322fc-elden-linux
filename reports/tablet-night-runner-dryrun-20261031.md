# 平板夜间通道干跑（2026-10-31）

> 只读设备侧操作 + runner 自带 DRY_RUN；未执行 RUN=1，未碰主线任何文件。

## 结论（数字）

| 项 | 值 |
|---|---|
| runner 是否支持 dry-run | **支持**：`.pi/plans/tablet-night-runner.sh` 默认 `RUN=0`（DRY_RUN），只打印计划/校验，不调用 pi（源码 L31/L95/L112） |
| 队列校验 | `tablet-queue.jsonl` **6 个任务**全部通过 JSON/字段/白名单校验（needs_device=false、SSOT 黑名单均过） |
| DRY_RUN 实跑结果 | rc=5：**API 探活失败终止队列**——设备 `/root/.config/pi-tablet-night.env` 未配置 `USTC_API_KEY`（DRY_RUN 也会跑探活，此为设计行为，非故障） |
| 执行模式 mock | `nice -n 19 ionice -c 3 timeout -k 60 30 bash -c 'echo ok'` → `ok`，rc=0，无残留进程 ⇒ 截止盒/低优先级链路在设备上工作正常 |
| 设备侧容量 | nproc=**8**；内存 14 871 MiB（available 10 601）；根分区 `/dev/sda17` 188 G 已用 21 G（12%）⇒ 低 CPU 队列容量充足 |
| 服务单元 | `pi-tablet-night.service`（system 级，**static**，WorkingDirectory=/root/y700-elden，TimeoutStartSec=8h，Nice=19）；`pi-tablet-night.timer` **enabled**（每日定时） |
| 仓库位置 | 平板端在 `/root/y700-elden`（非 uid 1001 home；uid 1001 存在但无仓库） |
| 边界遵守 | 未搬项目、未删 linux18（符合 reports/tablet-offload-plan-20261030.md） |

## 差距（上真跑前需补）

1. 配置 `/root/.config/pi-tablet-night.env`（`USTC_API_KEY=...`，chmod 600）——属凭据，需用户操作。
2. `WorkingDirectory=/root/y700-elden` 依赖 `git pull --ff-only origin main`（ExecStartPre）；主机侧未 push 的计划文件需先同步（`tablet-sync.sh --push-tablet`）。
3. DRY_RUN 的「总结：done=1」计数与实际（0 done，全部因 API 探活终止）不符——runner 收尾统计的显示小 bug，不影响执行语义，留给后续 L2 修正。

## 复现命令

```bash
scripts/device-lock.sh -w 300 ssh root@192.168.7.1 \
  "cd /root/y700-elden && DRY_RUN=1 RUN=0 TABLET_RSYNC_TARGET= bash .pi/plans/tablet-night-runner.sh .pi/plans/tablet-queue.jsonl"
scripts/device-lock.sh -w 300 ssh root@192.168.7.1 \
  "nice -n 19 ionice -c 3 timeout -k 60 30 bash -c 'echo ok'"
```
