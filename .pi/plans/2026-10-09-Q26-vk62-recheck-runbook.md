# Q26 vk62 单变量复核包（A）——上机即执行 runbook

> 状态权威 `TASKS.md` §5 Q26。本包 = 主机侧脚本 `scripts/q26-recheck.sh` + 本判定表。
> 静态结论见 `.pi/plans/2026-10-08-Q26-static-prep.md`。本包**只读**（`fastboot boot` 零写盘），不改 boot_b。

## 0. 一句话
`fastboot boot out/boot-elden-vk62.img` → 采「关联→IPv4 时间 + beacon rx 速率 + bmiss 次数」；
vk62 干净 ⇒ 坐实回归在 vk61→vk62 的内核+initramfs 更换（非 DTB、非 vk62→vk63）。

## 1. 变量控制（`out/boot-elden-vk6{1,2}.manifest` 已核实）
| 项 | vk61（掉链时代） | vk62（本次复核） | vk63（已知干净基线） |
|---|---|---|---|
| kernel_sha256 | `2321e3b9…`(`/tmp/kdir-bootb`) | `1c0d3310…`(=`out/Image-vk47clean.gz`) | `1c0d3310…`（同 vk62） |
| ramdisk_sha256 | `0fadae6b…`(`bootb-rootfs-newinit`) | `35823240…`(`initramfs-full-elden`) | `35823240…`（同 vk62） |
| DTB | 裸 `elden.dtb` `9d46693b…` | `cambist-h1` `79397e95…` | `cambist-h2` `386cc9bd…` |
| 结论 | 双变量起点 | **单变量到 vk63（仅 DTB 1 处，不含 WiFi）** | 干净基线 |

⇒ vk62 与 vk63 只差 cambist 节点 1 处 power-domain（DTB 全量 diff 无 WiFi/PCIe/WCN，见静态包 §1.2）。

## 2. 判定表（vk61 基线现象 vs vk62 现象）
| 观测项 | vk61 掉链基线（TASKS Q26） | vk63 干净基线（TASKS Q26 2026-10-08） | **vk62 判定** |
|---|---|---|---|
| 关联→IPv4 时间 | ~140 s（`getting IP configuration`） | <60 s 拿到 IPv4 | **<60 s ⇒ 未复现回归（干净）；≈140 s ⇒ 复现回归** |
| beacon rx 速率（`iw station dump`） | 前 ~100 s ≈0.5/s（`beacon rx: 1` 级） | ≈10/s（`beacon rx:1623`） | **≥5/s ⇒ 未复现；≤1/s 起步 ⇒ 复现** |
| bmiss 次数（dmesg `BEACON_MISS`/`failed to flush transmit`/`Connection to AP …lost`） | 每 ~16–18 s 一次，窗内多次 | 0 | **0 ⇒ 未复现；≥2 次且 ~16 s 周期 ⇒ 复现** |
| 掉线周期 | ~16–18 s | 无 | 有 ⇒ 复现 |

**决策树（静态包 §2.1）**：
- vk62 **干净** ⇒ 证实「v63 干净非 v63 特有」⇒ 回归点 = **vk61→vk62 的内核 Image + initramfs 更换**；下一步做 A/B 交叉 ramdisk（静态包 §2.2）。
- vk62 **掉链** ⇒ 与「DTB 差量不含 WiFi」静态结论冲突 ⇒ cambist/H2 电源域与 WiFi 存在**间接耦合**（供电/时序），**优先取证、重估静态假设**。

## 3. 纪律（务必，来自本轮基础设施踩坑 + Q28）
1. **必须冷启起步**：先让设备**完全断电**（拔电/长按电源至黑屏 10 s）再进 fastboot；连续热重启会**累积**面板失败（Q28 `dsi_bonded_cmd_failed` 永久闩锁），失败态起步会污染本轮起机。
2. **失败态用 sysrq-b，不用 `reboot -f`**：面板失败 boot 上 `reboot -f` 会因 DPU 卡死挡关机路径而挂住 → 用 `echo b > /proc/sysrq-trigger` 强制复位。
3. **pkill 用 `-x`**：脚本内如清理进程用 `pkill -x <name>`，勿 `pkill -f <模式>`（会杀掉执行命令的远程 shell 自身，PITFALLS）。
4. **不写死序列号**：`fastboot -s "$FB"` 的 `FB` 来自 `fastboot devices` 探测；主线上联走 SSH（`root@192.168.7.1`），**不是 adb**。
5. 串行锁：脚本已 `device_lock_acquire`，与 mod-loop/kexec/to-fastboot 共用一把锁，勿并跑。

## 4. 命令
```bash
# 探测设备
fastboot devices                     # 应见序列号；无则先 reboot2 bootloader（见 runbook C）
# 复核 vk62
scripts/q26-recheck.sh               # 默认 IMG=out/boot-elden-vk62.img SSID="P40 Pro" OBSERVE=180
# 对照 vk63（已知干净，同一 AP 同一口径）
IMG=out/boot-elden-vk63.img scripts/q26-recheck.sh
```
落盘：`logs/q26-recheck-<img>-<ts>/`（`SUMMARY.txt` 有 assoc/ipv4 beacon bmiss scan 摘要）。

## 5. 产物
- `scripts/q26-recheck.sh`
- 判读日志目录 `logs/q26-recheck-*`
- 上游依据文件：`.pi/plans/2026-10-08-Q26-static-prep.md`、`TASKS.md` §5 Q26
