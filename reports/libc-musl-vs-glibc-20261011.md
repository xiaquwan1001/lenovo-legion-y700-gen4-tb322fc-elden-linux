# 调查：宿主 rootfs 是否需要从 musl(Alpine) 切 glibc（2026-10-11）

> 前提（不重复论证，2026-10-06 会话 `01a11132`/`01a111cd` 已定案）：Waydroid 容器跑 bionic、与宿主 libc 无关；G3 已有 glibc chroot `/root/glibc-rootfs`（Ubuntu 24.04, glibc 2.39）+ Box64 0.4.5 + Wine 9 PoC 成功；glibc 宿主的收益主要=预编译 aarch64 二进制省一层 chroot。本报告在此之上补新证据、针对 2026-10-11 当前卡点复核。

## 结论（先看这里）

**不切。** 当前活跃卡点（Q28 显示间歇、Q24 熄屏×相机、C4 Waydroid 传感器 HAL、Play 登录）**没有任何一个卡在 musl**——三个是内核/DT 问题，一个是 HAL 契约问题；且②的实测证明其用户态依赖在 Alpine aarch64 已全部有官方包（部分已在机）。切 glibc 零收益、只有重建成本与回退风险。何时再评估：仅当出现"确凿卡在 musl 的阻塞"或 G3 Steam 端到端阶段确认 chroot 维护成为高频摩擦时。

## ① 当前卡点逐一核对（是否真卡在 musl）

| 卡点 | 卡在 musl？ | 证据 |
|---|---|---|
| Q28 显示间歇（根因=bonded 双 DSI 首条 DCS 命令 DMA hang） | 否（内核） | `TASKS.md §5 Q28` / `reports/q28-DOSSIER.md`：根因在内核 DSI 命令通路，与 libc 无关 |
| Q24 熄屏×相机掉电（camcc+cambist 配对 × RPMh 电源域） | 否（内核/DT） | `TASKS §5 Q24`、`reports/q24-repro-20261011.md`、上游报告已发 linux-arm-msm |
| C4 Waydroid 传感器（自编 HIDL HAL 卡 SensorService） | 否（HAL 契约） | `reports/research-waydroid-sensors-hal-20261011.md`：卡点=DATA_INJECTION flag / poll 阻塞；且修复路线（上游 waydroid-sensord）**是宿主 Alpine 原生包**（见②），musl 恰好是最短路径 |
| Play 登录（C2/C3） | 否（用户凭据/上游链路） | `TASKS §5`：卡在凭据与代理，`TASKS.md` gplay 口径明示"由用户提供" |
| G1-34 传感器 userland（hexagonrpcd/libssc） | 否（已通） | 2026-10-11 vk94 实测 HasAccelerometer=true；且下述②显示这两个包已在机且来自 apk |
| 相机/显示调试工具 | 未观察到 musl 阻塞 | libcamera/GStreamer/Snapshot/v4l2-ctl 已在 apk 环境跑通（G1-5、G1-9） |
| 基准（G1-8） | 部分是 **Alpine 打包缺口**（非 musl ABI）：`glmark2` 只在 testing、未启用 repo；vkmark/sysbench/fio 正常出分（`TASKS §1 G1-8`，2026-10-11 vk64 实测）。加 testing repo 即解，无需 glibc |
| 上游提交的 phoc/phosh 用户态 | 否 | phoc/phosh 0.55 在 Alpine 上已构建、装机、自启（G1-1、G1-26/27/28、`reports/userland-auto-rotation-toggle-20261011.md` 实测）；Alpine 相关的 2 个 phosh 补丁随仓库走 |
| Geekbench 类 glibc-only 预编译二进制 | 是（真实但低频） | 唯一已确认的 musl 依赖项；已有 chroot 范式（`/root/glibc-rootfs`），`archive/topics/BENCH-2026-10-11.md` 未使用此类工具 |

## ② Alpine aarch64 包生态实测（2026-10-11，决定性证据）

上游 pkgs.alpinelinux.org + 设备 `ssh root@192.168.7.1` `apk search -x`（apk-tools 3.0.8，latest-stable main/community）双源核实：

| 包 | pkgs.alpinelinux.org (edge) | 设备 apk search（latest-stable） | 在机？ |
|---|---|---|---|
| hexagonrpcd | 0.4.0-r3 community | hexagonrpcd-0.4.0-r3 | ✅ `apk info -W /usr/bin/hexagonrpcd` = apk 装的 0.4.0-r3 |
| libssc | 0.4.4-r0 community | 0.4.3-r0 | ✅ 已装 |
| sensorfw | 0.15.2-r0 community | 0.15.1-r2 | ✅ 已装 |
| waydroid-sensors | 0.2.0-r2 community | 0.2.0-r2 | ⬜ 未装，一条 `apk add waydroid-sensors` 即得（v3.22 分支也有 0.2.0-r0） |
| libgbinder | 1.1.54-r0 community | 1.1.45-r0 | ✅ 已装 |
| libglibutil | 1.0.83-r0 community | 1.1.81 → 1.0.81-r0 | ✅ 已装 |
| waydroid | 1.6.3-r0 community | 已在用 | ✅ |
| glmark2 | 2023.01-r1 testing | （不在启用 repo） | ⬜ testing，可加 repo |
| vkmark | 2025.01-r2 community | 2025.01-r2 | ✅ 已装/出分 |
| box64 | 无包（任何分支） | 无 | glibc chroot 内源码装（现状不变） |

**判定**：C4 传感器路线、sensors userland、Waydroid 本身的全部宿主依赖在 Alpine aarch64 均有官方包，且大半已在机。musl 不再是这些功能的门槛。

## ③ 切 glibc 的代价 vs 替代方案

- **代价**：rootfs 全量重建（3.44 GB 归档解包 30852 项那一级的重做）+ 重放 2026-10-06 以来全部手工补装/修复（GNU 工具 shadow、OpenRC 化、elogind poweroff 修复、fstab nofail、aw99706/greetd 链、phoc/phosh 重编、Mesa 自编包、Waydroid bind-mount）；与**持久根/initramfs/模块 vermagic 管线**深度耦合——当前 vk 系迭代、模块化载荷 + `mod-loop` 热换、`/init` 生命线、q24 镜像脚本全部假设 Alpine rootfs。回退=再重建一次。风险高、无收益项对应。
- **替代（现状，已足够）**：glibc 需求走 `/root/glibc-rootfs` chroot（已建、PoC 已验证）；多 libc 共存无需改宿主；Alpine 打包缺口（glmark2）用 testing repo 解决。
- **中间选项**（若未来要 systemd/更多包）：postmarketOS（Alpine 基底+systemd，保留 apk）迁移成本远低于换 glibc 发行版——2026-10-06 会话已评估过此档，此处仅存档引用。

## 建议

**不切**；glibc 需求继续走现有 `/root/glibc-rootfs` chroot，C4 传感器直接 `apk add waydroid-sensors`（musl 原生路线）；仅当未来出现确凿卡在 musl 的阻塞项、或 G3 Steam 端到端确认 chroot 摩擦高频化时再重评。
