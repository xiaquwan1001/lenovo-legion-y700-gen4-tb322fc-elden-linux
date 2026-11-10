# 194 — `dtbo_a` 是「a 槽卡 logo」的真根因（flashed 形态三年全败的真正解释）

- 日期：2026-11-10（深夜）
- 关联：`TASKS/README.md` §5「2026-11-10（深夜，`dtbo_a` 真根因）」；正文 `reports/uefi-dtbo-a-rootcause-20261110.md`

## 现象与机理

- 同一份 Linux `boot.img`：`active=b` 一切正常；`active=a` **卡联想 logo**、USB 不枚举、无 pstore，约 10 s 后 ABL 放弃回落。
- **#600** 根因 = **`dtbo_a`**。原厂 `dtbo_a` 是合法 Android DTBO（magic `D7B7AB1E`、`total_size` 23 348 092 B），
  ABL 在 `BootLinux` 之后执行 `Apply Overlay`（日志 `Load Image dtbo_a` → `Apply Overlay total time: 175 ms`），
  把 Android 那套 overlay 合并进**我们自己带的** Linux DTB ⇒ 内核拿着被污染的设备树起不来。
  而 `dtbo_b` 早在 2026-10-03 就被本项目写成全 0（「假 dtbo」），ABL 对它只打印
  `Dtbo hdr magic mismatch 0, with D7B7AB1E` → `ApplyOverlay: ufdt apply overlay failed` 并**容忍继续**。
- **这是项目第一天的坑**：`PITFALLS/sessions/01-引导fastboot重启交接.md`「假 dtbo 必须**两个槽都写**（`dtbo_a` 和 `dtbo_b`），否则卡 logo」；
  `PITFALLS/sessions/02-内核DTS构建.md` 第 10 条「**ABL 会拿 stock dtbo overlay 我们的内嵌 DTB** → 卡 logo」。
  历史上只处理了 `_b`，2026-11-09/10 的 p60–p69 全部打在 `_a` 上 ⇒ **每发注定卡 logo**，与补丁、payload、`vbmeta` 全无关。

## 判据（可复现）

```bash
# a 槽 dtbo 清成全 0（32 MiB），vbmeta 不用动
truncate -s 33554432 /tmp/dtbo-blank.img
fastboot -s HA2EXB0E flash dtbo_a /tmp/dtbo-blank.img
# 同件 RAM 形态 34 s 起；flashed（写 boot_a + set_active a）27 s 起
```

- `dtbo_a` 原厂件备份 = `backup/dtbo_a.img`（`45f51790…`，写前与在机件逐字节核对过）。
- **#601** 判「从哪个槽、哪份件起的」**不能用 `androidboot.slot_suffix`**：我们的 `boot.img` 头里烤死了
  `androidboot.slot_suffix=_b`，而 ABL 对 Linux 件**不追加**自己的 suffix ⇒ 从 `boot_a` 起时 `/proc/cmdline` 仍只显示 `_b`。
  本轮一度据此误判「flashed 形态落到 `_b` 系统」。正解 = 在镜像头 cmdline 里埋唯一标记（`elden_nocamera=1` → `elden_bootmark=a`，
  同长度原地替换）再 `grep /proc/cmdline`；`uname -r` 也不可靠（两槽常是同一份件）。
  同批被否证的还有 `vbmeta_a` 假设：原厂 Flags 0（哈希必然不匹配）照样起 Linux ⇒ **解锁态下 ABL 不因哈希失败拒绝交棒**。
- **#602** `logfs` 对最近的启动**根本不再写**：16:14 的 flashed 失败发与 16:20 的成功 `_b` 启动前后，整个 8 MiB 分区 sha 完全相同
  （`9e614b36…`），17:2x/17:4x 四发亦未变 ⇒ 现有 10 个区段是 11-08/09 的残留，`#594/#597` 的「信标一字节未变 ⇒ 没跑到」不成立。
  只有**我们自己的 UEFI** 写 logfs 有效（p69 flashed 后新增 `R68LOG n=3 … s9:esp-ld-ok`）⇒ logfs 只能当
  「我们的固件跑没跑」的正控；要看 ABL/内核层行为，改看总耗时分级（R70 停留）与注入标记。

## 结论对流程的影响

- **纪律**：任何要在 `_a` 上做的启动试验，先 `dtbo_a` 清零；等价地说 —— **默认在 `_b` 上做试验**，动 `_a` 前先问 dtbo。
- G1-29 的 flashed 形态已闭环：`boot_a`=p69 UEFI + `dtbo_a` 全 0 ⇒ 129.2 s 起 Linux（基线 + 74.3 s 停留）、
  信标全绿、`elden_bootloader=esp`（内核从 ESP 的 `\boot\boot.img` 起）。
