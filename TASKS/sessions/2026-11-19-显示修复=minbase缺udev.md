# 2026-11-19（下午）显示修复 = minbase 缺 udev，整链一次闭环

> 上一篇 = `2026-11-19-显示nodp实验与RAM路径复核.md`（nodp 实验「只有背光」负结果）。
> 本篇 = **真因找到并修复，显示全链 bound，屏幕出字（用户目视确认）**。

## 根因链（单变量证据）

1. `build/` 树已清理 ⇒ DTB 实验改走镜像内 DTB 手术（沿用上篇产物）。
2. nodp 实验件仍「只有背光」+ 挂死不 panic ⇒ 排除「图连接是充分修复」，转查环境。
3. **设备内取证**：`systemd-udevd` inactive、`ps` 里 0 个 udevd、`dpkg -l udev` = **未安装**
   ⇒ minbase 构建漏了 udev ⇒ 模块零自动加载 ⇒ fastrpc/ath12k/音频链全缺。
4. 修复（全部有判据）：
   - 主机开 NAT（`ip_forward=1` + MASQUERADE；第一发误加 eno1，实测默认路由走
     手机热点 `enx027644563e50` metric 100 ⇒ 补正确出口，tcpdump 定位）；
   - 设备时钟错（2026-04-13）⇒ TLS 全废 ⇒ `date -s` + `hwclock -w`；
   - `apt-get install udev` → `systemctl enable --now systemd-udevd` → active；
   - `modprobe fastrpc` → **`/dev/fastrpc-adsp`/`-cdsp` 出现**（ADSP/CDSP remoteproc 本就 running）；
   - ath12k 早启 `-110` 是时序问题 ⇒ **PCI remove+rescan 即复活**（`wlan0` 出现）
     ⇒ 固化 `/etc/systemd/system/ath12k-rescan.service`（oneshot，已 enable）。
5. **控制实验（决定性）**：`fastboot reboot` 从持久 `boot_b`（= 上篇控制件 `740d431b…`，未改内核/DTB）
   冷走一遍 ⇒ **`ae01000.display-controller` aggregate = bound，ae94000/ae96000.dsi、
   af54000 DP、3d00000.gpu 全 bound**；`/dev/dri/card0` + `fb0`（1904×3040）+ `fbcon` 在；
   deferred 只剩无关的 `109ab000.tn`；**用户目视：屏幕有字**。
   ⇒ 上篇的 nodp 补丁**不需要**（DP 不用摘）；「DP 拖死 DPU」是 udev 缺失的下游症状。
6. 顺带：音频卡 `LenovoY700Gen4` 出现（此前 snd deferred）——同一根因的下游。

## 槽位收口（上篇遗留 ③ 已闭环）

- 设备无 python3 ⇒ 走「dd 出 LUN4 主备 GPT 34 LBA → 主机 `slot-attr.py --image` 打补丁
  （`boot_b` 0x3f→0x7f，双表 + CRC 重算 + 读回验证）→ dd 写回 + cmp 读回」。
- **ABL 侧终验**：`fastboot getvar slot-successful:b` = **yes**、unbootable=no、retry=7。
- 件 = `reports/artifacts/slotattr-20261119/`（原表/补丁表 sha 全记）。

## 环态（收尾时）

- 设备 = 持久 `boot_b` 自签件（740d431b…）正常起 Linux，ssh 可用；
  `lsmod` 36 个、wlan0 在（DOWN，待连网）、音频卡在、显示 bound + fbcon 出字。
- 遗留小项：设备 RTC 不保持（重启回到 4-13，`hwclock -w` 不持久或 RTC 无电）⇒
  下次装 chrony/timesync 或在 `/init` 加 date 恢复；fbcon 有字但未起 Phosh（桌面面下一slice）。

## 下一步（按价值）

1. 桌面：`resize2fs /dev/sda17`（193 GiB）+ `daily-baseline.tsv`（Phosh/IME/音频 UCM）→ 复回 G1-37 日用面。
2. `ath12k-rescan` 跨重启回归（下次重启确认 wlan0 自动在）；WiFi 连网。
3. nodp 实验件标记为历史（`out/min-restore-20261119/boot-nodp-linux.img` 留档勿用）。
