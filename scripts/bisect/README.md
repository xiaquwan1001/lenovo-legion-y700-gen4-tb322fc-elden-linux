# scripts/bisect — vk34→vk40 回归二分（渐进触发式）

配套文档：`archive/topics/AUDIT3-polling-sideeffects-2026-10-03.md`（为什么这么设计）、
`archive/topics/AUDIT2-post-vk34-bisect-2026-10-03.md`（静态审计 N1–N4）。

## 版本矩阵（已备，uname 唯一）

| label | 镜像 | 期望 uname | 含义 |
|---|---|---|---|
| `vk34recon` | `out/boot-elden-vk34recon.img` | `ge72a036ed4be` | **基线**（回退 post-vk34 全部增量） |
| `v1-thermal` | `out/boot-elden-v1-thermal.img` | `gf681b616a3af` | 仅 DTS 分级热 trip |
| `v2-audio` | `out/boot-elden-v2-audio.img` | `g951c5f1c2ca5` | 仅音频 4 文件 |
| `vk40re` | `out/boot-elden-vk40re.img` | `g6ef87e6a8868` | 两者都有（复现回归） |

## 前置：把持久 b 槽换成已知基线

当前 `boot_b` 烧的是 **vk40 现场内核**（kernel payload `d16ab35ce4a57afa`），
任何复位都会回退到 vk40，污染「复位」的版本归因。先换成 vk34recon：

```bash
scripts/bisect/eldtest.sh baseline      # 打印精确步骤（你亲自执行）
```

## 重要：本机没有可靠的 Linux→fastboot 工具（PITFALLS #88）

- `cycle.sh --soft`（`reboot -f`）不再落 fastboot；`misc` BCB `bootonce-bootloader` **未被 ABL 采纳**（实测）。
- 进 fastboot 只有**物理键**。
- **A/B 测试不依赖它**：用 `flash` 子命令（`flash-b.sh` 写 `boot_b` + 重启，全程不开 fastboot）。
- **前置必做**：`python3 scripts/slot-attr.py mark-successful b`（否则 b 槽 retry 耗尽会停在 fastboot）。

## 跑一轮

```bash
# 从 Linux：把测试内核写进 b 槽 + 重启 + 渐进触发观测（推荐，不需要 fastboot）
scripts/bisect/eldtest.sh flash vk40re

# 备选：设备已在 fastboot（你手动进去）时 RAM 引导 + 观测
scripts/bisect/eldtest.sh one vk40re

# 或你手动 boot 好之后，只跑观测
scripts/bisect/eldtest.sh observe vk40re
```

渐进触发级别（每级之间读一次 dmesg 计数）：

| 级 | 动作 | 等待 |
|---|---|---|
| idle0 | 什么都不做 | 45 s |
| on | 单次 `wlr-randr --on` | 15 s |
| off | 单次 `wlr-randr --off` | 15 s |
| onoff5 | on/off ×5 | 20 s |
| idle2 | 纯空闲 | 120 s |

结果：`logs/bisect/<ts>/results.tsv` + `journal.log` + `console.log`。
判据：`vblank timeout` / `PPM init` / `crash|fatal` 计数，以及是否发生复位（uname 变化 / uptime 回退 / SSH 断）。

## 纪律（AUDIT3 教训）

- 一条命令只做一件事；`fastboot boot` 单独成步。**不把 reboot/boot 放进任何等待循环**。
- 等待启动用 **事件驱动**（console 出现 uname 横幅），不用 tight `fastboot devices` 轮询。
- 每版 **≥3 轮、每轮长时窗**；单次「没复现」不算结论（间歇性故障）。
- 版本归属只认 `uname -r`，不认文件名。
