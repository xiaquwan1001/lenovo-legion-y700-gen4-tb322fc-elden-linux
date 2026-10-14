# 会话记录 2026-10-14：M1-7.3 功能基线机上验收（一发通过）

> 承接 `2026-10-14-m1-73-baseline-consolidation.md`（基线分支收敛）。设备 U2 `HA2EXB0E`。
> 证据层 = `logs/arm-m1-baseline-20261014-195235/`（console.log / dmesg.txt / grim.png / verdict.txt）+ `reports/trials/20261014T115840Z-m1-baseline.json`。

## 0. 数字先行（一发：`fastboot boot` 零写盘，reset=cold）

| 项 | 实测 | 对照 |
|---|---|---|
| 镜像 | `out/boot-elden-m1-baseline.img` sha `1254324a…`，85 581 824 B | < 96 MiB 限 |
| 内核 UTS | `7.3.0-rc7-debug-ged6f232d10e3` | = ramdisk 模块 vermagic |
| **`Run /init as init process`** | **7.67 s** | 旧 M1 树 96 s（WCN 停滞）/ E2 坏发 30.8 s |
| ath12k 首探 | 4.53 s 起 → **7.66 s 失败 −110**（等 2.75 s = 3 s 超时生效） | 对照 E1e 同路径等 **91 s** |
| ath12k retry | 22.6 s bind（try 1）→ `chip_id 0x2` → **28.1 s phy0 up** | — |
| **WiFi** | `wlan0` 关联 `ustc-guest` 5805 MHz，**−48 dBm，458/516 Mbit/s**，IPv4 `202.141.191.182` | ✅ |
| **显示签名** | **L1=0 / L2=0**（无 Q28 坏发签名） | 本时段此前 6 连坏 |
| card0 | `card0`+`card0-DSI-1`(**connected**)+`card0-DP-1`；`phoc`+`phosh` 在跑 | ✅ |
| 面板/触屏驱动 | `novatek… registered as panel follower`；`msm_dpu` 绑定 2×DSI(dsi_ops)+DP+GPU | ✅ |
| 模块 | `fsa4480`(8)+`fastrpc`(0) 已载；`/dev/fastrpc-adsp` 在 | ✅ |
| grim | 1904×3040 PNG **106 KB**（早前「只背光」坏发为 39 KB） | 非终判 |
| **面板实测** | **用户实机确认：有桌面内容 + 触屏可操作** | ★终判 |

trial record：`reports/trials/20261014T115840Z-m1-baseline.json`（VERDICT=GOOD / reset=cold）。

## 1. 结论

1. **M1-7.3 功能基线一发通过**：单次干净 boot 同时取到「快启动（`Run /init` 7.67 s）+ 面板有内容可操作 + WiFi 通」——
   这是 E 系列（`2026-10-14-m1-73-mainlining.md` §5/§6）**未能**在同一发里取得的组合（当时受限坏发簇）。
2. **两个改动均确证有效**：
   - 显示：E1b（`dsi_7nm_phy_enable()` 补 `PLL_SYSTEM_MUXES=0xc0`）⇒ 面板出内容（本镜像已含该 1 行）。
   - 启动：补丁 `0001-ath12k-shorten-mhi-timeout` ⇒ `Run /init` 7.67 s（ath12k 首探 2.75 s 快速失败，用户态 retry 22.6 s 成功）。
3. **本发为 Q28 GOOD** ⇒ 落在好发窗内（与前一坏发簇相反）；**单次样本**，Q28 本身未解决、`boot_b` 仍 `vk94`。
4. **可操作性**：用户实机确认面板可操作 ⇒ 基线镜像可作后续实验的「好台架」。

## 2. 镜像形态（单变量 vs E2）

`Image.gz`（基线树 `m1-73/baseline` tip `c7da05b1d8`）+ `ramdisk`（73j，sha `4d4834e6…`）+ `DTB`（树，sha `c801884334…`）+ 73j 同款 cmdline（`elden_root=LABEL=linux17 … elden_nocamera=1`）。
打包前用临时 annotated tag 钉死 UTS 为 `…ged6f232d10e3`（`scripts/setlocalversion` 的 dirty `+` 抑制），故与 ramdisk 内 `fsa4480.ko`/`fastrpc.ko` vermagic 逐字对齐。

## 3. 遗留 / 下一步

1. **未写 `boot_b`**：本发是零写盘 `fastboot boot`；若要让基线上机常驻需用户在场写盘 + 备份（未做）。
2. **Q28 单样本**：本发 GOOD 不能作为「Q28 已修」；Q28 状态与 `boot_b=vk94` 不变（见 §5 Q28）。
3. manifest 记 `kernel_release=…e3+`（树侧 `make kernelrelease` 无 tag）vs 镜像 `…e3` ⇒ `kernel_release_matches_image=no`，与 E 臂同类（`uts_dup`）。
