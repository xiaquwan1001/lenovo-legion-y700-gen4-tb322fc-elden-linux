# 换机后 P0 抢救 + M1-7.3 线首个 Q28 坏发现场（2026-10-17）

> 触发：换机审计把「设备侧活资产 = 唯一副本」列为 P0；用户把 U2 留在 fastboot 态。
> 实机 = ✅（U2 `HA2EXB0E`）。**全部产物已入 `backup/HA2EXB0E-16+512/device-rescue-20261017/`。**

## 0. 数字结论

| 项 | 结果 |
|---|---|
| `boot_b`（`m1-baseline-f3`）抢救 | ✅ **100 663 296 B**，sha256 `78a2beb1e0f4a5eab638d2c0351cbec7b33aace44c846bc9c5de5b590d808f3b` = `DEVICE/README.md` §1.1 记录的**签名后写入 sha**（逐字节一致，设备侧/主机侧双向核对） |
| 模块树 | ✅ **1497 个 `.ko`**，`modules-7.3.0-rc7-debug-ged6f232d10e3.tar.zst`（19.1 MB）；**tar 流 sha256 双端一致** `ee3f059b5eb215718633ce383e538cb63efc2b7ae171d73b22b6dc2f8a2c5292`，解压后 ko 计数 1497 |
| 配置/脚本 | ✅ `device-config-20261017.tar.zst`（502 KB，207 项）：`/usr/local/sbin/*`（cam-mode.sh、camera-modules-load.sh、ath12k-retry.sh…）、`/root/q24bak/`（**原版** `cambistmclkcc-sm8750.ko`/`camcc-sm8750.ko`）、`/etc/{init.d,modules-load.d,conf.d,modprobe.d,elden-init-mode}`、`/proc/config.gz` |
| Q28 现场 | ✅ 完整 dmesg 1835 行 + `pm_genpd_summary`(97 行) + `clk_summary`(587 行) |
| 主机 root 依赖 | **0**：`sudo` 需密码，但**不需要**——设备 `usb0` 有 IPv6 链路本地地址，主机 `ssh -6 root@fe80::1e:5eff:feed:e101%enx021e5eede102` 直连即可（`elden-net.sh` 只为 IPv4 192.168.7.x 服务） |

**遗留**：`fastboot fetch` 不可用（#290），本次走 `ssh | dd` 流式取回；主机 `platform-tools` 已装到 `~/.local/opt/platform-tools`（37.0.1）。

## 1. 本次 Q28 坏发：M1-7.3 线首个完整现场

内核：`7.3.0-rc7-debug-ged6f232d10e3` `#11 SMP PREEMPT Thu Oct 15 10:02:06 CST 2026`（= `boot_b` 的 `m1-baseline-f3`，**7.3-rc7 血统**）。
启动方式：`fastboot reboot`（本文件记录时为 t+213 s，`boot_id e4151f6f…`）。

**形态判定 = STORM（不是 NOCARD）**：

| 判据 | 读数 |
|---|---|
| `card0` | **存在**（`/sys/class/drm/card0`）⇒ 非 NOCARD |
| `card0-DSI-1/status` | `connected` |
| phoc / phosh | 1 / 1（**用户态活着**）⇒ 非 `#231`「仅背光+无 SSH」形态 |
| 面板 | `panel-novatek-nt36536 ae94000.dsi.0: Failed to initialize panel: -110` |

**签名（与 vk64/7.2 线逐字同型）**：

```
[ 0.299295] DSI PLL(0) lock failed, status=0x00000000     ← ×4（0.299–0.315 s）
[12.241405] msm_dsi ae94000.dsi: command DMA timeout: status=0x2200200
[12.247150] msm_dsi ae96000.dsi: peer command DMA timeout: status=0x2200200
[12.247165] msm_dsi ae94000.dsi: bonded command DMA failed: master=-110 peer=-110
[12.247180] panel-novatek-nt36536 ae94000.dsi.0: Failed to initialize panel: -110
[13.814538] [drm:dpu_encoder_phys_vid_prepare_for_kickoff:576] [enc35 intf1 ctl 1 reset failure: -22  ← 之后 DPU 风暴
```

**这是重要新证据**：此前 Q28 坏发样本全部来自 **7.2 血统**（vk64/vk86/vk113/vk124…）。本次证明
**7.3-rc7 血统（m1-73/baseline + F3）同样会坏发**，且**签名逐字相同**（`status=0x2200200`、`master=-110 peer=-110`、`-110`→`-5`）。
⇒ 支持既有口径「Q28 与镜像/构建身份无关、属 DSI 命令路径竞态」，**削弱**「M1-7.3 重基碰巧避开 Q28」的侥幸解释。
（限定：单发样本；`reboot` 路径，非真 POR 冷起。）

**genpd / clk 现场（可供上游引用）**

| 项 | 值 |
|---|---|
| `mdss_gdsc` | **on**，usage 0 |
| `mdss_int2_gdsc` | off-0 |
| `mx` / `mmcx` / `cx` | on / on / on（usage 256 / 320 / 320） |
| `mxc` / `mxc_ao` / `mx_ao` / `mmcx_ao` / `cx_ao` | off-0（全部） |
| `dsi1vco_clk` rate | **0**（从机 DSI PLL 从未编程；`enable_cnt 0`） |
| `disp_cc_mdss_dptx0_*` | 全 0（DP 未接） |

⇒ 与 `reports/q28-DOSSIER.md` 的「从机 DSI PLL 未锁定 / 命令 DMA 引擎闩住」一致；**显示侧电源域是 on 的**，缺的是 PLL/命令通道，不是电源。

## 2. 本次**未**采到的（明确边界）

- Taniya Das（10-13）要的三件套里，`dmesg` / `pm_genpd_summary` / `clk_summary` **本次都已拿到**，但**语境不同**：
  她要的是 **Q24**（`camcc`+`cambistmclkcc` 配对加载 + **真实熄屏**）场景；本次是 **Q28 坏发**（相机 0 模块、`elden_nocamera=1`、显示从未点亮）。
  ⇒ 这份数据**不能**直接当 Q24 回复，只能作「显示电源转换基态」对照。**Q24 回复仍需**：加载相机栈 → 真实 `dpms Off` → 抓死前 dmesg/genpd/clk（致死会重启，需 `elden-powerlog` + 串口）。
- `logs/` 旧日志、`out/*.img` 历史镜像：本次抢救**不覆盖**（见 `reports/migration-rebuild-audit-20261017.md` L-B）。

## 3. 复现命令

```bash
# 主机侧（无需 root；设备 usb0 有 IPv6 LL）
IF=$(ip -br link | awk '/enx/{print $1}' | while read i; do ip -6 addr show dev $i | grep -q fe80 && echo $i; done | tail -1)
TAB="fe80::1e:5eff:feed:e101%$IF"
ssh -6 root@$TAB 'uname -r; cat /proc/sys/kernel/random/boot_id'
# boot_b 抢救（无 fastboot fetch，PITFALLS #290）
ssh -6 root@$TAB 'dd if=/dev/disk/by-partlabel/boot_b bs=1M 2>/dev/null' > boot_b.img
# 模块树
ssh -6 root@$TAB 'cd / && tar -cf - lib/modules/7.3.0-rc7-debug-ged6f232d10e3 | zstd -3 -T0 -q -c' > modules.tar.zst
```
