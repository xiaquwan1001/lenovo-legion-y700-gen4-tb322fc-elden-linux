# T16：62 条误分类脚本重判（2026-11-27）

> 复核对象：`reports/scripts-ref-audit-20261127.md` 里被误判为「③保持私有」的 62 条
> （69 条真有调用点维持 ③ 不动；本报告只覆盖 ZERO 52 条 + MENTION 10 条）。
> 复现清单命令与父代理原样一致（grep -rn -F 到 scripts/packaging/rootfs/tools/initramfs，
> 排除自身与 scripts/README.md，注释行计 mention）。
> 判定口径三选一：① 退役（头加 RETIRED 行，不删文件）/ ② 补指针（RESOURCES §5）/ ③ 真内部件（需调用点证据）。

**总体结论**：62 条全部无真实调用点（含 10 条 MENTION，仅出现在别处注释里），
故本批 **0 条可判 ③**。最终：**① 退役 37 条**（一次性实验执行器/已被替代，配方均在 reports/ 有落点）、
**② 补指针 25 条**（可重跑的现役可用件，已进 `RESOURCES/README.md` §5，新增 4 个面：
桌面栈构建/调试、自检/门禁、主机环境、Win-x86 转译 PoC；UEFI/内核部署/Waydroid/取证等现有面各补若干行）。

「可复核」列 = `grep -rlF <脚本名> reports/` 的首条命中（证明配方/结论在 reports/ 有落点，可反查）。

## 逐条表

| 脚本 | 新分类 | 理由 | 动作 |
|---|---|---|---|
| `scripts/android-slim-v3-build.sh` | ① 退役 | v3 super 已写入并 EDL 读回校验通过（一次性构建器），配方与判据在 reports/android-slim-v3-20261119.md；替代/复核：该报告 §7/§8；可复核：reports/disk-audit-20261126.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/android-v3-bringup-walkthrough.sh` | ① 退役 | v3 首启验证 S1–S5 执行包，只服务 2026-11-19 那轮 bring-up，配方在 reports/android-slim-v3-20261119.md；可复核：reports/android-a-slot-mech-rejudge-20261121.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/arm-window-hunt.sh` | ① 退役 | 坏发窗口多臂交替的一次性取证执行器，配方与结论在 reports/ 显示臂相关报告；可复核：reports/scripts-hardening-2-20261121.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/b3b-session-retry.sh` | ① 退役 | B3-b 用户态重启会话对照，单次实验，判据与结果在 reports/q28-b1-firstsample-20261015.md；可复核：reports/script-cleanup-audit-20261112.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/b5-u2-atomic-timeline.sh` | ① 退役 | B5/U2 原子回调时序取证门，一次性取证，判据在 reports/b5-per-soc-cfg-design-20261027.md；可复核：reports/artifacts/tablet-offload-20261030/l2a-dep-grep-3.log | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/bb-magic-scan.py` | ① 退役 | DDR 黑匣子窗口魔数扫描的一次性取证执行器，配方在 reports/uefi-ddr-* 系列报告；可复核：reports/uefi-posctrl-20261103-summary.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/blackout-passive-scan.sh` | ① 退役 | 黑屏期 wlan0 beacon 被动扫描，单次诊断，结论已落 reports/；可复核：reports/audit-20261119/A3-scripts-audit.tsv | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/build-payload-hook.sh` | ① 退役 | vk77-modular ramdisk 补 payload 钩子的一次性打包器（教训已入 PITFALLS §0 纪律 4），配方在 reports/；可复核：reports/scripts-index-20261120.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/build-phosh-upstream-fix.sh` | ② 补指针（桌面栈构建/调试（新立面）） | 用上游 main 源树+本地补丁编 aarch64 phosh，验证 upstream 补丁可重跑 | RESOURCES/README.md §5「桌面栈构建/调试（新立面）」加一行 |
| `scripts/c1-iprule-build.sh` | ① 退役 | C1 策略路由内核（vk95 一发）一次性构建器，C1 已由 vk103/vk126 落地，配方在 TASKS/reports C1 记录；可复核：reports/c1-iprule-vk95-20261011.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/check-series-selfcontained.sh` | ② 补指针（自检/门禁（新立面）） | 补丁系列自足性门禁，带 --self-test，发上游前必过 | RESOURCES/README.md §5「自检/门禁（新立面）」加一行 |
| `scripts/deploy-camera-modules.sh` | ② 补指针（内核/模块/部署） | 不刷 boot 不重启部署相机栈的兜底路径，可重跑 | RESOURCES/README.md §5「内核/模块/部署」加一行 |
| `scripts/deskstack-sample.sh` | ① 退役 | A 臂熄屏状态机单次采样包，2026-11-14 对照已做完，配方在 reports/ 桌面栈对照报告；可复核：reports/scripts-index-20261120.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/deskstack-switch.sh` | ① 退役 | 0.58 vs 0.59 桌面栈整档 A/B 对照执行器，对照已完成，配方在 reports/；可复核：reports/scripts-index-20261120.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/device-window-collect.sh` | ① 退役 | 2026-10-31 执行单配套的一次性窗口取证采集包，产物已在 reports/artifacts/device-window-20261031/；可复核：reports/script-audit-ssh-20261118.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/devlogs.sh` | ② 补指针（取证/解码） | 设备日志快照统一入口 pull/pstore/tail，常驻可用 | RESOURCES/README.md §5「取证/解码」加一行 |
| `scripts/driver-snapshot-diff.sh` | ② 补指针（取证/解码） | driver-snapshot 输出的 A/B diff 配套件，随 snapshot 可重跑 | RESOURCES/README.md §5「取证/解码」加一行 |
| `scripts/driver-snapshot.sh` | ② 补指针（取证/解码） | 一次上机采齐驱动状态快照，A/B 对照通用 | RESOURCES/README.md §5「取证/解码」加一行 |
| `scripts/edl-peek.sh` | ① 退役 | 本机 loader 无 peek 支持必然失败（PITFALLS #486 定案，脚本头已注明），DDR 回读走 reports/uefi-ddr-fallback-plan-20261101.md §1.4 路径；替代：fastboot boot Linux + probes/blackbox；可复核：reports/ltbox-evaluation-20261118.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/fb-survey.py` | ① 退役 | BootShim splash_region 颜色轨迹的一次性事后取证（2026-11-04 M1–M3 已判读），配方在 reports/ UEFI shim 报告；可复核：reports/uefi-payload-execution-20261104.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/fetch-x86-assets.sh` | ② 补指针（Win-x86 转译 PoC（新立面）） | PoC 离线资产下载器，可重跑 | RESOURCES/README.md §5「Win-x86 转译 PoC（新立面）」加一行 |
| `scripts/gapps-mirror-setup.sh` | ② 补指针（Waydroid 容器） | GAPPS 镜像接入本地 OTA 源，重配 OTA 时用 | RESOURCES/README.md §5「Waydroid 容器」加一行 |
| `scripts/glycin-bwrap-shim.sh` | ② 补指针（桌面栈构建/调试（新立面）） | bwrap shim 修 gdk-pixbuf/glycin 断言杀 phosh，仍是现役修复件 | RESOURCES/README.md §5「桌面栈构建/调试（新立面）」加一行 |
| `scripts/grubfat-build-uefi-bootimg.sh` | ② 补指针（UEFI/ESP/GRUB） | UEFI 卷→boot.img 打壳构建器，路线 A 备料可重跑 | RESOURCES/README.md §5「UEFI/ESP/GRUB」加一行 |
| `scripts/gui-freeze-watch.sh` | ② 补指针（取证/解码） | GUI 冻结现行抓取（串口+心跳双通道），复发时直接挂上 | RESOURCES/README.md §5「取证/解码」加一行 |
| `scripts/hk-save-decrypt.py` | ② 补指针（取证/解码） | HK 存档解/加密工具，与设备无关但可重用 | RESOURCES/README.md §5「取证/解码」加一行 |
| `scripts/host-mem-build-stress.sh` | ② 补指针（主机环境（新立面）） | 真实构建内存压测（无 ECC 位翻转排查），复发时用 | RESOURCES/README.md §5「主机环境（新立面）」加一行 |
| `scripts/keep-awake.sh` | ② 补指针（设备体检/电源） | 设备保持清醒独立工具（不加载相机栈），脚本头已注明定位 | RESOURCES/README.md §5「设备体检/电源」加一行 |
| `scripts/kexec-bs-cycle.sh` | ① 退役 | kexec 掉电二分单轮执行器，二分已收敛，配方与结论在 reports/ kexec 系列报告；可复核：reports/script-redundancy-audit-20261112.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/kexec-diag-test.sh` | ① 退役 | vk65-m{0..3} 诊断内核定位 kexec 掉电阶段的一次性执行器，结论已落 reports/；可复核：reports/script-audit-ssh-20261118.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/lf2-expected.py` | ① 退役 | GRUB LF2 补丁期望值复算器，只服务 elden_lf2_* 补丁当时验证，根因定案在 reports/uefi-grub-initrd-rootcause-20261115.md；可复核：reports/pstore-ram-initrd-guard-20261116.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/mailbox-quota-reclaim-20261125.py` | ① 退役 | 2026-11-25 用户授权的一次性邮箱回收（文件名即日期戳），规则与执行结果见该轮会话记录；可复核：reports/arch-audit-20261127.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/make-gpt-only-xml.py` | ① 退役 | 「GPT 回原厂」对照用的一次性 xml 生成器，对照已完成（本仓六 LUN dump 在档），配方在 reports/；可复核：reports/script-audit-edl-20261118.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/manifest-from-image.py` | ② 补指针（内核/模块/部署） | 从镜像重建 .manifest 防假身份（PITFALLS #131/#162），树丢失时唯一正路 | RESOURCES/README.md §5「内核/模块/部署」加一行 |
| `scripts/n7-vk127-camera-blank.sh` | ① 退役 | N7 vk127 上复跑 Q24 配方的一次性对照执行器，结论已落 reports/；可复核：reports/主机侧-B13-20261117.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/net-egress.sh` | ② 补指针（主机环境（新立面）） | 主机出口选择/测速，常驻可用 | RESOURCES/README.md §5「主机环境（新立面）」加一行 |
| `scripts/oob-gs1-activate.sh` | ① 退役 | USB gadget acm.GS1 的一次性激活件（设备侧已激活完成，initramfs/usb-gadget 已含 GS1）；可复核：reports/audit-20261119/A3-scripts-audit.tsv | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/phoc-build-launch.sh` | ② 补指针（桌面栈构建/调试（新立面）） | root 独立 session 启动 phoc 构建，防连杀，可重跑 | RESOURCES/README.md §5「桌面栈构建/调试（新立面）」加一行 |
| `scripts/q28-coldboot-collect.sh` | ① 退役 | 等一次真 POR 冷起并归档 q28-clkdiag 的一次性取证执行器，产物已在 reports/artifacts/；可复核：reports/主机侧-B13-20261117.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/q28-disp-ab-sample.sh` | ① 退役 | Q28 显示初始化补丁 A/B 冷起采样执行器，各臂样本已做完，配方在 reports/q28-disp-init-ab-20261022.md；可复核：reports/q28-v2-mdss-reset-20261023.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/q32-arm.sh` | ① 退役 | Q32 暖起 vs 冷起三臂实验单发执行器，实验已完成，配方在 reports/q32-warm-vs-cold-preresearch-20261023.md；可复核：reports/主机侧-B13-20261117.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/qemu-ramoops-initrd-ab.sh` | ① 退役 | ramoops 盖 initrd 的 QEMU 单轮回归，根因与守卫已定案 reports/uefi-grub-initrd-rootcause-20261115.md；可复核：reports/pstore-ram-initrd-guard-20261116.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/real-vs-ladder.sh` | ① 退役 | VS_STOP 阶梯旧版执行器，已被现役 uefi-r21-sbstop-ladder.sh（宿主可读判据）取代；替代：scripts/uefi-r21-sbstop-ladder.sh；可复核：reports/script-cleanup-audit-20261112.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/sd-run-variant.sh` | ① 退役 | sleep-death 候选零写上机执行器，该轮变体实验已完成，配方在 reports/ sleepdeath 系列报告；可复核：reports/主机侧-B13-20261117.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/sd-variant-build.sh` | ① 退役 | sleep-death 候选内核/boot.img 一次性构建器（wt-sleepdeath worktree 口径），实验已完成；可复核：reports/artifacts/tablet-offload-20261030/l2a-offline-packages.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/send-upstream-report.py` | ① 退役 | cambistmclkcc 上游报告+patch 的一次性发送件（已发出），存档在 mail.ustc 与 reports/；可复核：reports/audit-20261119/A3-scripts-audit.tsv | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/skewcal-frame-stats.sh` | ① 退役 | M4 SKEW_CAL A/B 帧统计一次性测量件，结论已落 reports/ 相机系列报告；可复核：reports/audit-20261119/A3-scripts-audit.tsv | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/skewcal-measure.sh` | ① 退役 | M4 SKEW_CAL A/B 出流测量执行器（同上一轮一次性测量），结论已落 reports/；可复核：reports/audit-20261119/A3-scripts-audit.tsv | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/slotboot-run.sh` | ① 退役 | P2 槽位正常启动路径单次上机（2026-11-01），产物在 reports/artifacts/uefi-slotboot-20261101；可复核：reports/lanes-consolidated-20261101.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/t14-rebuild.sh` | ① 退役 | T14 Mobian 换根重建 recipe 可执行化，T14 已收口，配方权威在 reports/t14-userland-recipe-20261111.md §3；配方：reports/t14-userland-recipe-20261111.md；可复核：reports/scripts-index-20261120.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/t5-q24-capture.sh` | ① 退役 | 给 Taniya Das 的三件套一次性采集（2026-10 交付完成），产物已随上游线程存档；可复核：reports/script-cleanup-audit-20261112.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/test-bt-guard.sh` | ② 补指针（自检/门禁（新立面）） | BT guard 钩子注入式单元测试，改钩子后必跑 | RESOURCES/README.md §5「自检/门禁（新立面）」加一行 |
| `scripts/test-lib-wait.sh` | ② 补指针（自检/门禁（新立面）） | lib-wait/lib-ssh stub 自检，改等待语义后必跑 | RESOURCES/README.md §5「自检/门禁（新立面）」加一行 |
| `scripts/uefi-ddr-trial.sh` | ① 退役 | DDR 黑匣子上机循环，该轮取证已完成，配方与判据在 reports/uefi-ddr-* 系列报告；可复核：reports/doc-slim-20261102.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/uefi-oneshot.sh` | ② 补指针（UEFI/ESP/GRUB） | 真载荷单档一发判读，UEFI 阶梯复发时的现役执行器 | RESOURCES/README.md §5「UEFI/ESP/GRUB」加一行 |
| `scripts/uefi-r21-sbstop-ladder.sh` | ② 补指针（UEFI/ESP/GRUB） | R21 sbstop 阶梯宿主判读，是 real-vs-ladder 的现役替代 | RESOURCES/README.md §5「UEFI/ESP/GRUB」加一行 |
| `scripts/waydroid-cam-restart.sh` | ② 补指针（Waydroid 容器） | vendor 换件后真实桌面会话重启容器，标准路径 | RESOURCES/README.md §5「Waydroid 容器」加一行 |
| `scripts/waydroid-headless-start.sh` | ② 补指针（Waydroid 容器） | headless 应急启动（仅 Q28 坏发），头注已限定场景故保留+指针 | RESOURCES/README.md §5「Waydroid 容器」加一行 |
| `scripts/wd-c1-noworkaround.dev.sh` | ① 退役 | C1 验收一次性设备侧执行件，C1 已由 vk126+ 内核落地收口；可复核：reports/c1-noworkaround-20261013.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/wd-c1-verify.dev.sh` | ① 退役 | vk103 netd per-network 路由验证的一次性设备侧执行件，C1 已收口；可复核：reports/stale-alpine-audit-scripts-20261119.md | 脚本头已加 `# RETIRED 2026-11-27` 行（不删文件） |
| `scripts/win-x86-rootfs.sh` | ② 补指针（Win-x86 转译 PoC（新立面）） | PoC rootfs 构建/部署，可重跑 | RESOURCES/README.md §5「Win-x86 转译 PoC（新立面）」加一行 |
| `scripts/win-x86-run.sh` | ② 补指针（Win-x86 转译 PoC（新立面）） | chroot 内 Box64+Wine 执行入口，可重跑 | RESOURCES/README.md §5「Win-x86 转译 PoC（新立面）」加一行 |
## 计数（改前 / 改后）

| 分类 | 改前（误判为 ③） | 改后 |
|---|---|---|
| ① 退役 | 0 | 37 |
| ② 补指针 | 0 | 25 |
| ③ 真内部件 | 62 | 0（本批无真实调用点；原 69 条真 ③ 未动） |

改动面：37 个脚本各 +1 行 `# RETIRED 2026-11-27：…`（shebang 之后）；`RESOURCES/README.md` §5 +25 行、新立面 4 个。
未删任何脚本；未改 scripts/README.md、reports/README.md（生成物，已重生成）、TASKS/NEXT.md、INDEX.md、TASKS/README.md。

## 验收

- `bash scripts/check-doctor.sh`：FAIL=0
- `python3 scripts/reports-orphan-check.py --check --no-list`：rc=0
- `python3 scripts/gen-scripts-index.py --check`：rc=0
