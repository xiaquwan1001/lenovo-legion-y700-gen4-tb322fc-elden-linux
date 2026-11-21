# T9 资源采样器在重建根后消失 —— 本轮恢复 + 固化 + 首条真数据

> 日期 2026-11-21（无人值守轮次，**设备在线**：`ssh elden-root` 通，up 9.1 h，`7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`，b 槽主启 Linux，`/` = `/dev/sda17` 189.9 G 用 7.1 G）。
> 本轮只做**加法**：装采样器 + 起 timer + 采数；不改桌面/不动 greeter/不重启会话。

## 0. 数字结论

| 项 | 结果 |
|---|---|
| 发现 | 11-19 重建根后 **T9 采样器三件全丢**：`/usr/local/sbin/suspend-resource-sample.sh` 无、`elden-resource-sample.timer/.service` 无、`/var/lib/elden/` **目录都不在** ⇒ 从 11-19 起 T9 一直是「没数据」，而"没数据"极易被读成"还没到下结论的时候"（真因 = 资产丢了，不是样本没攒够） |
| 恢复 | 脚本 + 两枚手写单元已装；`systemctl is-enabled/is-active elden-resource-sample.timer` = **enabled / active**；`/var/lib/elden/suspend-resource.tsv` 表头 + 行都在（**20 列**对齐） |
| 首条真数据 | `suspend_success/fail` 本 boot = **4/0**（本轮 1 次 `rtcwake -m mem -s 45` 从 3→4，`fail` 恒 0，`uptime` 只涨 11 s）；`capacity` = 100% Full、`procs` ≈ 333、`threads` ≈ 568 |
| 端到端验证 | 采样器在**一次真实 suspend/resume 窗口两侧各采一行**：`…/3/0` → `…/4/0`（这正好是 T9 要判的东西） |
| 门 | ① `deploy-desktop-shell.sh` 新增 **§12**（deploy + `--check`，四件判据：脚本在且 sha 与仓内一致 / timer enabled / timer active / TSV ≥1 行）；② `check-doctor` **§22** 新增 4 条「非包资产锚点」（deploy §12、unit 的 `OnUnitActiveSec=30min`、脚本 `tick)` 分支、`stage.sh` 的 `units-extra`）；③ 镜像构建侧 `rootfs/debian/stage.sh` **4d** 复制 `units-extra/*` 并建 timer 启用软链 |
| 全量回归 | `deploy-desktop-shell.sh --check` = **MISS=0**（§1–§12 全绿：桌面/greetd/音频 Speaker/触觉 ×2/启动队列 mask/T9） |

## 1. 为什么这是「资产丢」而不是「包丢」

`daily-baseline`/`apt` 从来不带这个采样器：它是我们自己写的 POSIX sh + 两枚手写 unit。
11-19 的根是「6 GiB minbase + `deploy-desktop-shell.sh` 补桌面」路线（`TASKS §4` 2026-11-19 条），
而 11-20 那次补的是**音频/触觉**（`PITFALLS #698`）——T9 采样器不在任何清单里，于是静默消失。
这与 `PITFALLS #689`（重建根丢的是非包状态：公钥/WiFi 档/dconf）同一族，但**判据不同**：
#689 的症状是「功能不可用」，本条的症状是「**看起来一切正常，只是没有数据**」。

## 2. 本轮落地的四处（都可离线复核）

| 位置 | 内容 |
|---|---|
| `scripts/suspend-resource-sample.sh` | 新增 **`tick [OUT]`** 模式（定时器用）：目录不在就建、表不存在先用表头初始化、再追加一行；顺带修一个真 bug —— 表头分隔符是字面 `\t`，必须 `printf '%b'` 展开，用 `%s` 会把 `ts\tup\t…` 原样写成一行不可分列（本轮实测踩到，已修并验证 `awk -F'\t'` 得 20 列） |
| `rootfs/debian/units-extra/elden-resource-sample.{service,timer}` | **手写**单元（不走 `render.py`：它的 class 词表只有 longrun/oneshot/shutdown，没有「timer 对」语义）：oneshot 跑 `tick`，`TimeoutStartSec=120`（`/sys/power/wakeup_count` 读会阻塞，见 #651）；timer `OnBootSec=10min` + `OnUnitActiveSec=30min`、`Persistent=false`（重启不补历史，避免把「重启后」语义混进趋势） |
| `rootfs/debian/stage.sh` **4d/6** | 镜像构建时复制 `units-extra/*` 到 `/usr/lib/systemd/system/` 并建 `timers.target.wants/` 软链（与 `systemctl enable` 等价、可离线） |
| `scripts/deploy-desktop-shell.sh` **§12** | live 设备部署 + `--check` 四件判据；`--check` 现在会当场报 `MISS T9 采样器未就绪（缺件数=4 …）`（本轮实测先红后绿） |

## 3. 实测记录（设备侧，逐条可复跑）

```
# 修前（--check）
== 12) T9 资源采样器（重启根必丢…）==
  MISS  T9 采样器未就绪（缺件数=4，脚本 sha 设备=无 仓内=eed1d354…）
结果: 未达标（MISS=1）

# 装 + 起 timer + 采首行（= 脚本 §12 run 路径的同一条命令序列）
systemctl enable --now elden-resource-sample.timer   # enabled / active
sh /usr/local/sbin/suspend-resource-sample.sh tick
awk -F'\t' '{print NR": cols="NF}' /var/lib/elden/suspend-resource.tsv   # 1: cols=20  2: cols=20  3: cols=20

# 一次真实 suspend/resume（45 s），采样器在窗口两侧各采一行
before: 3/0  up=32899
rtcwake -m mem -s 45        → rc=0
after : 4/0  up=32910
tail -2 … | cut -f1,2,9,15,16,17
1795221321  32899  …  Full  3/0  4840
1795221332  32910  …  Full  4/0  （wakeup_count 空 —— #651 同族，该列历史上已判作废）

# 修后（--check）
  ok    T9 采样器就绪（timer active，表 3 行）
结果: 达标（MISS=0）
```

## 4. 取数与判读口径（不改）

- 取数：`scp elden-root:/var/lib/elden/suspend-resource.tsv .`（timer 每 30 min 一行）。
- 判据纪律（用户 2026-11-13 定，2026-11-16 复核）：**同一 boot 内 ≥3 周期看趋势**；跨 boot 先对齐 UTS 与负载；
  单点无意义；`wakeup_count` 列作废（#651）；电池 `current_now/voltage_now` 只作同口径相对量，不换算功耗。
- 本轮样本量：**2 行有效（含 1 个 suspend 窗口）** ⇒ 仍**不**出趋势结论，只证「采样链路通了」。

## 5. 未做 / 下一步

- **真正的待机掉电率**仍未被测：本设备当前用户态策略是 `sleep-inactive-battery-type=nothing`、`idle-delay=0`
  （11-16 判读），没有自动待机窗 ⇒ 要出数必须显式造窗（`suspend-resource-sample.sh cycles N 45 OUT`
  或临时改电源策略，均属设备可见动作，需用户在场）。
- `deploy-desktop-shell.sh` 的 **run 模式 §12 未端到端跑**（run 模式会 `systemctl restart greetd`，
  本轮为不打断用户会话，改用手工等价命令 + `--check` 验证）；下次完整部署窗口再跑一次即可。
- 采样器尚未进 `packaging/elden-userland/MANIFEST.tsv`（那条路是 `sync-from-device.sh` 从设备镜像生成，
  属 userland 包化线）；当前固化点 = stage 4d + deploy §12，两条路都不依赖 MANIFEST。
