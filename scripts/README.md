<!-- 结构指纹 fp=dca89da155d1d8f4（--check 只比这个；引用计数不进指纹、随生成刷新） -->
<!-- 本文件由 scripts/gen-scripts-index.py 生成；不要手改。
     重新生成：python3 scripts/gen-scripts-index.py
     过期检查：python3 scripts/gen-scripts-index.py --check   (rc=1 = 需要重新生成) -->

# scripts/ 索引

`scripts/` 是「命名即接口」的命令层：**没有统一 dispatch**，每个任务一个脚本。本索引给地图，不是规范。设计与统计口径见 `reports/scripts-index-20261120.md`（arch-audit P1#3）。

- 入口总数：**348**（`scripts/*.sh|*.py` 或带 shebang 的可执行文本 + 一层子目录 `scripts/{doctor,bisect,audio-tplg,audio-ucm,wd-audio-test}/*`）
- 分组：门禁 78 / 设备操作 107 / 造件 71 / 取证 46 / 一次性 2 / 公共库 7 / 其它 37
- 引用数为 0 的孤立件：**1**（判定口径见下）

## 判据（怎么读这张表）

- **引用数** = 仓库受版本控制文本文件里提到该 basename 的**行**数（`脚本↔脚本` + `文档↔脚本`，已扣除脚本自身）。**0 = 没有任何脚本/文档提到它** ⇒ 可疑孤立件（可能是过期一次性工具，也可能是人手跑的入口）。
- **门禁类**：名字或头注释命中 `check-/verify/preflight/assert/sanity`；聚合门禁 = `scripts/check-doctor.sh`（FAIL=0 才收尾）。
- **一次性**：只认**自报**（首个注释行写「一次性脚本/工具/任务」或 one-shot/退役/已过期）或**文件名带日期**（`-YYYYMMDD.py` 这类单次产物）；误判率低于按内容猜。
- **其它**：五类都不贴的主机侧杂项（会话检索 `sess.sh`/`recent-sessions.sh`、并发 `lane.sh`、邮件 `mail-*`、镜像/分区解析小工具 `partlun.py`/`dump-verdict.py` 等）。「其它」多不等于脚本乱，只说明它不属于设备/造件/取证链。
- **公共库**：`lib-*.sh`，只被 `source`，不单独执行。
- 分组靠名字/头注释正则（`gen-scripts-index.py` 的 `GROUPS`），错组就改那条正则，别手改本文件。
- **同名入口**（basename 撞车 ⇒ 引用数是这几条的合计，偏高；别据此判「活」）：
  - `build.sh`：`scripts/audio-tplg/build.sh`、`scripts/wd-audio-test/build.sh`

> 本文件由生成器重写，**手改会被下一次生成覆盖**；要改内容就改被索引脚本的头注释，要改分组就改 `gen-scripts-index.py` 的 `GROUPS`。

## 门禁（78）

| 入口 | 用途 | 引用 |
|---|---|---|
| `scripts/doctor/04-retired.sh` | §4 已退场入口不得复辟（2026-10-04 清理）。 | 5 |
| `scripts/doctor/05-vk.sh` | §5 vk 版本账 + §5d 内核身份表（同一次全量扫描产出两节）。 | 7 |
| `scripts/doctor/05e-manifest.sh` | §5e manifest 完整性（构建产物身份可对账）。 | 5 |
| `scripts/doctor/05f-abi.sh` | §5f ABI 敏感项一致性（内核 ↔ 模块树）。 | 7 |
| `scripts/doctor/06-hygiene.sh` | §6 静态卫生（防造轮回退）：设备锁单一真源 + bashism + 死脚本。 | 12 |
| `scripts/doctor/09-sessions.sh` | §9 SESSIONS/ 快照一致性（委托 scripts/check-sessions.sh）。 | 7 |
| `scripts/doctor/10-history.sh` | §10 HISTORY 对账（<0.1 s）。 | 7 |
| `scripts/doctor/11-hooks.sh` | §11 提交钩子生效性（hooksPath 必须指向 .githooks）。 | 7 |
| `scripts/doctor/12-modular.sh` | §12 驱动模块化门禁（锚点不回退 / olddefconfig 幂等 / tristate 自洽）。 | 6 |
| `scripts/doctor/13-assets.sh` | §13 文档引用的资产路径存在性（委托 scripts/check-doc-assets.sh）。 | 7 |
| `scripts/doctor/14-layout.sh` | §14 顶层布局注册表（委托 scripts/check-layout.sh）。 | 7 |
| `scripts/doctor/15-timeline.sh` | §15 时间序健康：INDEX.md §0「现在一页」是否存在且没落后于最新会话证据。 | 11 |
| `scripts/doctor/17-shell-hygiene.sh` | §17 设备命令静态卫生（委托 scripts/check-shell-hygiene.py）。 | 4 |
| `scripts/doctor/18-flashpkg-geometry.sh` | §18 线刷包几何自检（委托 scripts/rawprogram-preflight.py） | 4 |
| `scripts/doctor/19-slotattr-selftest.sh` | §19 槽位属性工具自检（委托 slot-attr.py --selftest） | 4 |
| `scripts/doctor/20-rootfs-image.sh` | §20 磁盘根镜像「起得来 / 登得入」写前门（委托 scripts/rootfs-image-check.py） | 3 |
| `scripts/doctor/21-write-precheck.sh` | §21 写前预检两道门（委托 scripts/gpt-preflight.py / dump-verdict.py） | 4 |
| `scripts/doctor/22-desktop-chain.py` | check-doctor §22：「零到桌面」链路的静态一致性门。 | 10 |
| `scripts/doctor/23-out-manifest.sh` | §23 out/ 造件「报告↔镜像」账本门（委托 scripts/out-manifest-check.py）。 | 5 |
| `scripts/doctor/24-scripts-index.sh` | §24 scripts/README.md 索引新鲜度门（委托 scripts/gen-scripts-index.py --check）。 | 4 |
| `scripts/doctor/25-out-status.sh` | §25 out/ 造件生命周期账本门（委托 scripts/out-status.py --check）。 | 4 |
| `scripts/doctor/26-vbmeta-b-chain.sh` | §26 b 槽自签 AVB 链一致性门（委托 scripts/build-vbmeta-b.sh --check）。 | 5 |
| `scripts/doctor/27-bootimg-cmdline.sh` | §27 boot/vendor_boot cmdline 改写器自检门（委托脚本自带 --selftest）。 | 4 |
| `scripts/doctor/_lib.sh` | shellcheck shell=bash | 25 |
| `scripts/doctor/ab-bench.sh` | bench.sh — check-doctor 新旧 A/B（2026-11-05 脚本审计的验收装置） | 6 |
| `scripts/android-apk-pkgname.py` | 从 apk 里读 package 名（纯主机侧，无 aapt/jadx 依赖）。 | 4 |
| `scripts/android-ksu-avb-build.py` | 造 KernelSU(LKM) 修补的 init_boot + 与之自洽的 vbmeta_a。 | 9 |
| `scripts/android-launcher-db-check.py` | 校验「桌面默认布局里不再引用已删包」。 | 5 |
| `scripts/android-linux-coexist-check.py` | 安卓/Linux「共存分区契约」核对（纯主机侧，只读 GPT 主表 dump）。 | 26 |
| `scripts/android-slim-v3-build.sh` | 安卓「彻底精简 + 无占位 + 可共存」system/super 构建器（主机侧，需 root） | 10 |
| `scripts/assert-kernel-sane.sh` | 打包前的「内核身份 / 存活」硬门（pack-time gate）。 | 33 |
| `scripts/cam-load-verify.sh` | 在设备上当 root 跑：加载相机模块栈并做前后对拍（Q24 口径：加载后不要燄屏）。 | 8 |
| `scripts/check-abi-config.sh` | 内核 .config 的 ABI 敏感项门禁（build/pack-time gate）。 | 37 |
| `scripts/check-doc-assets.sh` | 文档里用反引号写出的资产路径必须真实存在。 | 45 |
| `scripts/check-doctor.sh` | elden 项目医生 — 机器账自检（只读，不改任何文件） | 308 |
| `scripts/check-init.sh` | init 单一真源 / 可运行性自检（主机侧，只读） | 12 |
| `scripts/check-layout.sh` | 顶层布局注册表门（versions/layout.tsv ↔ 磁盘 ↔ INDEX.md） | 24 |
| `scripts/check-modular-config.sh` | 模块化 config 门禁（第二层，2026-10-26） | 28 |
| `scripts/check-progress-counts.sh` | 从 TASKS/README.md §1/§2 的行内状态标记现算完成度 | 76 |
| `scripts/check-project-memory.sh` | 校验「项目记忆就在仓库里」这条链路没断 | 8 |
| `scripts/check-series-selfcontained.sh` | 补丁系列自足性门禁（派工单 M3-v5 2026-10-31） | 38 |
| `scripts/check-sessions.sh` | 独立校验 SESSIONS/（不依赖 gen-sessions.py 的实现细节） | 23 |
| `scripts/check-shell-hygiene.py` | 设备命令静态卫生门（2026-11-18，来自四板块脚本审查） | 14 |
| `scripts/deploy-bt-suspend-guard.sh` | 把 BT suspend 保护钩子部署到设备并验证。 | 8 |
| `scripts/driver-snapshot-diff.sh` | 比对两次 driver-snapshot.sh 的输出，按「变了什么」排序输出。 | 5 |
| `scripts/dump-verdict.py` | 「这次 dump 失败了吗？还是分区真的不存在？」的唯一判据。 | 15 |
| `scripts/elden-to-bootloader.sh` | 设备侧「Linux → bootloader(fastboot)」单一入口（POSIX sh，可独立跑） | 6 |
| `scripts/gen-scripts-index.py` | 生成 scripts/ 索引（scripts/README.md + 机读 TSV），可重跑、可挂门。 | 41 |
| `scripts/gpt-audit-tb322fc.py` | 把设备 GPT 主表 dump（EDL 只读得到）与官方 259 包逐字节对账。 | 19 |
| `scripts/gpt-preflight.py` | 写盘前的 GPT「快照复验」（纯主机、无 USB、不碰设备）。 | 17 |
| `scripts/hide-android-partitions-selftest.sh` | 离线自测（全部在 /tmp 沙盒里跑，不碰 /etc、不碰设备） | 5 |
| `scripts/host-net-proxy.sh` | 把主机的本地代理暴露给设备（USB-NCM 侧），幂等 | 37 |
| `scripts/ime-candidates-check.sh` | 中文候选窗「可出候选」判据的只读体检（2026-11-15 立） | 11 |
| `scripts/kbuild-sanity.sh` | build-sanity.sh — 构建前后 mandatory 健康门（内核/任意 git 树）。 | 26 |
| `scripts/lib-dump-verdict.sh` | EDL/`dd` dump 的**三值判定**（present / absent / error）单一真源。 | 3 |
| `scripts/linux-state-audit.sh` | 「Linux 进度」8 项状态的只读体检（主机侧 + 设备侧），永不做写操作。 | 29 |
| `scripts/mail-draft-check.py` | 投递前静态核对 `send-mail-ustc.py` 草稿（离线，零网络）。 | 25 |
| `scripts/mobian-daily-baseline.sh` | 把 Debian/Mobian 目标根补齐到「日用可用」（幂等；主机侧驱动） | 34 |
| `scripts/out-archive.py` | out/*.img 归档器 —— out/ 只留在用件与取证件，历史镜像 mv 到 backup/out-history-<date>/。 | 31 |
| `scripts/out-manifest-check.py` | out/ 造件「报告↔镜像」账本门（2026-11-20，arch-audit P0#2） | 15 |
| `scripts/rawprogram-preflight.py` | 线刷包 rawprogram XML 的**写前**几何预检（纯主机、无 USB）。 | 16 |
| `scripts/rootfs-image-check.py` | 磁盘根 ext4 镜像「能不能起 / 能不能登入」的写前门（主机侧，只读） | 7 |
| `scripts/doctor/s07-08-docs.py` | check-doctor §7/§8 入口文档与索引对账（纯文本判据）。 | 32 |
| `scripts/doctor/s16-tasks-counts.py` | check-doctor §16：TASKS §0 手写数字 ↔ 计数脚本自动比对。 | 14 |
| `scripts/sleep-policy.sh` | 设备「待机策略」开关：待机（关屏）时是否允许 SSH/网络继续可用 | 1 |
| `scripts/slot-switch.sh` | A/B 槽位「一键往返切换 + 槽属性自检」（../TASKS/README.md §2 C7） | 64 |
| `scripts/t14-rebuild.sh` | T14「Mobian 换根重建 recipe」可执行化（2026-11-13，主机侧，零设备动作） | 3 |
| `scripts/test-bt-guard.sh` | 对 50-elden-bt-guard 做注入式单元测试（不需要真机、不动本机 BT） | 3 |
| `scripts/test-init-preflight.sh` | `initramfs/init` 的 preflight 回归测试（免 root、离线） | 5 |
| `scripts/test-lib-wait.sh` | scripts/lib-wait.sh + lib-ssh.sh 的自检（不需要设备） | 7 |
| `scripts/to-bootloader.sh` | 主机侧「Linux → bootloader」驱动 + 判据（配套设备侧 elden-to-bootloader） | 12 |
| `scripts/trial.sh` | 统一的「一次设备实验」闸门与记录（无 record 不得写 verdict）。 | 97 |
| `scripts/uefi-boot-trial.sh` | 一次「UEFI 异类载荷 fastboot boot」上机实验的全过程取证（G1-29 线） | 31 |
| `scripts/uefi-fv-strings.py` | 在 UEFI FD 的**内层（LZMA 压缩的）FVMAIN** 里搜 ASCII 字串。 | 20 |
| `scripts/verify-tree-integrity.py` | 校验某个 git 工作树/仓库里所有 tracked 文件的内容完整性。 | 16 |
| `scripts/vk-identity.py` | 构建号(vkN/语义名) ↔ 内核二进制 ↔ 内核源提交 的对齐表生成器。 | 100 |
| `scripts/wd-c1-verify.dev.sh` | RUN ON DEVICE (as root). 验证 vk103（IPv4+IPv6 多路由表）下 | 6 |
| `scripts/zero-to-desktop-check.sh` | 「起机 → 桌面」这一段（RUNBOOK S5–S12）的一条命令自检 | 18 |

## 设备操作（107）

| 入口 | 用途 | 引用 |
|---|---|---|
| `scripts/acm-sh.py` | 通过 USB ACM 的 OOB root shell（/dev/ttyACM1）在设备上跑命令。 | 9 |
| `scripts/android-ksu-flash.sh` | 刷/回退「KernelSU(LKM) init_boot + 自洽 vbmeta_a」（TB322FC / elden / 259） | 14 |
| `scripts/arm-window-hunt.sh` | 在坏发成簇的窗口里交替试多个显示臂，直到出现"健康发"。 | 19 |
| `scripts/as-client-deploy.sh` | 把 Audio Share 的「Linux 客户端」装到平板（TB322FC 主线 Debian） | 2 |
| `scripts/ath12k-load.sh` | ★★★ RETIRED（2026-11-22 脚本审计批 1，reports/scripts-audit-20261122.md §3）★★★ | 32 |
| `scripts/ath12k-retry.sh` | ath12k (WCN7861 "Peach") boot-time re-probe. | 51 |
| `scripts/audio-alsa-init.sh` | put the Lenovo-Y700-Gen4 (TB322FC/elden) sound card into | 23 |
| `scripts/bl-preunlock-evidence.sh` | 解锁前（locked 状态）零风险取证 + 解锁申请表所需参数打印。 | 11 |
| `scripts/bl-unlock.sh` | ⚠ 适用前提（2026-10-03 定稿）：**只有 ROM ≤ 1.1.11.073/.076 才存在解锁命令**； | 11 |
| `scripts/bt-link-test.sh` | BR/EDR 数据链路只读诊断（y700-elden / WCN7861 Brahma v2） | 14 |
| `scripts/bt-up.sh` | bring up Bluetooth at boot on the TB322FC (elden). | 15 |
| `scripts/build-hapticd.sh` | 交叉编译 elden-hapticd（Waydroid 马达透传宿主 daemon） | 10 |
| `scripts/cam-loopback.sh` | 把 mainline 相机（libcamera 软 ISP）转发到一个 v4l2loopback 节点。 | 47 |
| `scripts/cam-mode.sh` | elden 上「相机 ⇄ 熄屏」互斥的操作口径（在设备上当 root 跑） | 91 |
| `scripts/camera-modules-load.sh` | bring up the mainline camera stack on TB322FC. | 69 |
| `scripts/camera-stream-up.sh` | 在设备上把 camss 采集链路配置到可出流（幂等）。 | 26 |
| `scripts/charge-ctl.sh` | battery / charger control for TB322FC (elden), qcom-battmgr. | 27 |
| `scripts/charge-watch.sh` | keep the qcom-battmgr charger settings applied. | 23 |
| `scripts/deploy-camera-modules.sh` | 收口指针（script-redundancy-audit S15 + B13 §2，2026-11-17）：设备侧模块 tar 的**传输/备份/解包/depmod/读回校验** | 24 |
| `scripts/deploy-desktop-shell.sh` | 把「minbase 根」补成能起 Phosh 桌面的 appliance（主机侧驱动，幂等） | 104 |
| `scripts/deploy-modules.sh` | 把 `<构建树>/lib/modules/<UTS>` 部署到设备 `/lib/modules/<UTS>` | 36 |
| `scripts/deploy-sensord-routec-debian.sh` | 在 **Debian/glibc 根**上安装路线 C 的 Waydroid sensor HAL | 13 |
| `scripts/deploy-sensord-routec.sh` | build & install the route-C Waydroid sensor HAL | 16 |
| `scripts/deploy-sensors-hal.sh` | 部署 elden UDP 传感器 HAL 到 Waydroid 容器（C4） | 14 |
| `scripts/deploy-v4l2loopback.sh` | 为**当前在机内核**（读设备 uname -r）构建并部署 v4l2loopback | 19 |
| `scripts/deploy-zh-ime.sh` | 部署「触屏唤起的中文输入法」到设备（幂等） | 35 |
| `scripts/dev-userdata-relabel.sh` | 设备侧（POSIX sh）：把 Android userdata（sda16）就地转成 Linux 数据分区 | 12 |
| `scripts/device-lock.sh` | serialize exclusive access to the tablet across concurrent agents. | 112 |
| `scripts/device-window-collect.sh` | 设备窗口只读采集包（2026-10-31 执行单配套） | 18 |
| `scripts/dpms-watch.sh` | Sample the panel / compositor state once a second into /root/dpms-watch.log. | 10 |
| `scripts/driver-snapshot.sh` | 一次上机采集「尽可能多驱动」的状态快照，供两次启动（A/B）之间做 diff。 | 7 |
| `scripts/edl-peek.sh` | 经 bkerler python edl 的 Firehose peek 读物理内存（只读工具，无 poke） | 8 |
| `scripts/elden-powerlog.initd` | write a durable marker when OpenRC enters the shutdown | 24 |
| `scripts/eldroid-bootctl` | Linux 侧刷机控制（reboot reason + A/B 槽位元数据）。 | 223 |
| `scripts/f2fs-migrate.sh` | 路线 A：**缩小 linux17(ext4) + 尾部新建 linux18(f2fs) + 本地复制**（零大文件传输） | 33 |
| `scripts/fix-fstab-samsung.sh` | 给 /mnt/Samsung 的 fstab 条目补 nofail（掉盘不卡开机） | 6 |
| `scripts/fix-logind-poweroff.sh` | make logind's Power Off / Restart helpers actually | 29 |
| `scripts/flash-b.sh` | Flash a mainline boot image into slot b *from inside Linux* — no fastboot needed. | 102 |
| `scripts/flash-recovery.sh` | 从 Linux 里把镜像写进 recovery 分区（默认 recovery_b），无需 fastboot。 | 29 |
| `scripts/g1-22-dpms-test.sh` | 在设备上定量测试「熄屏（DPMS off）→ 回归」。 | 16 |
| `scripts/gpt-dump.sh` | 在设备（mainline Linux）上 dump LUN0 GPT 主/备表 | 30 |
| `scripts/gpt-minimal-build.py` | 生成「最小可控」GPT（LUN0 减分区 + 单 Linux 大分区；LUN4 只删 Android GKI）。 | 12 |
| `scripts/gpt-restore-tb322fc.py` | REVERSE the dual-boot GPT surgery on TB322FC LUN0: | 15 |
| `scripts/gpt-slot-flip-active.py` | 在一对 GPT 表（主表 6 扇区 + 备表 5 扇区）上只改 boot_a/boot_b 的 | 17 |
| `scripts/gpt-slot-swap-guids.py` | 把 A/B 槽的 **partition type GUID 侧** 搬到指定槽，并按 MarkPtnActive 语义修属性位。 | 8 |
| `scripts/gpt-surgery-tb322fc.py` | shrink `userdata` and append partition(s) on the | 42 |
| `scripts/greetd-initial-session.sh` | TB322FC session "path A": greetd [initial_session] | 16 |
| `scripts/host-arm64-chroot.sh` | 在主机上建一个 **arm64 Debian(sid) 构建 chroot**，并可选在里面编 sensord | 15 |
| `scripts/install-serial-logger.sh` | 一次性装一个常驻的串口日志服务（需 sudo）。 | 8 |
| `scripts/keep-awake.sh` | 临时：把会话的熄屏/挂起全部关掉（Q24：相机模块加载后熄屏有硬复位风险）。 | 17 |
| `scripts/kexec-boot.sh` | hot-reload a new kernel WITHOUT fastboot/ABL/AVB. | 34 |
| `scripts/kexec-bs-cycle.sh` | elden kexec 二分单轮。进 fastboot 只走一个入口：`eldroid-bootctl reboot bootloader` | 25 |
| `scripts/kexec-diag-test.sh` | 在设备上跑，用 vk65-m{0,1,2,3} 诊断内核定位 kexec 掉电阶段。 | 8 |
| `scripts/linux-gpt-apply.sh` | 把一对 GPT 表（主表 6 扇区 + 备表 5 扇区）写进指定 LUN，**写后读回对账**。 | 60 |
| `scripts/linux-gpt-dump.sh` | EDL 只读 dump 六 LUN 的 GPT 主表 + 备表（零写盘），并更新 SHA256SUMS。 | 14 |
| `scripts/m1-73-modules-overlay.sh` | 收口指针（script-redundancy-audit S15，2026-11-13）：设备侧整目录部署的统一实现 = scripts/deploy-modules.sh | 10 |
| `scripts/make-gpt-only-xml.py` | 从官方 rawprogram*.xml 里**只保留 GPT 两行**，生成「只改分区表」的 xml。 | 6 |
| `scripts/mesa-deploy.sh` | 把 extract-mesa-libs.sh 打好的 Mesa 包推到 Y700 设备并安装 | 15 |
| `scripts/mod-loop.sh` | 收口指针（script-redundancy-audit S15，2026-11-13）：设备侧整目录部署的统一实现 = scripts/deploy-modules.sh | 41 |
| `scripts/n7-vk127-camera-blank.sh` | N7：在 vk127（7.3-rc7 重放线）上跑 Q24 配方 | 3 |
| `scripts/ncm-host-up.sh` | 主机侧把「设备的 USB-NCM 网卡」配成 192.168.7.3/24（幂等，需 root）。 | 23 |
| `scripts/net-egress.sh` | 选择上网出口：教育网有线 enp6s0（快）vs wifi 热点 wlp5s0（慢） | 9 |
| `scripts/net-selfheal.sh` | 设备侧网络自愈（HTTPS 信任链 + PMTU 黑洞缓解） | 46 |
| `scripts/net-up-manual.sh` | WiFi bring-up without NetworkManager (fallback path). | 29 |
| `scripts/net-up.sh` | net-up.sh (NM) — bring up WiFi at boot via NetworkManager, with the old | 40 |
| `scripts/oob-gs1-activate.sh` | 在设备上把 USB gadget 重新 bind，启用第二个 ACM(acm.GS1) | 5 |
| `scripts/package-camera-modules.sh` | build out/camera-modules-<KV>.tar.gz from a | 13 |
| `scripts/payload-modules-load.sh` | load the modularized payload drivers (ATH12K, QDSP6 | 32 |
| `scripts/probe-camera-sensors.sh` | TB322FC (elden/SM8750) 相机 + 传感器 只读探测 | 8 |
| `scripts/q26-recheck.sh` | Q26 vk62 单变量复核（主机侧，零写盘 fastboot boot）。 | 20 |
| `scripts/recover-lun4-slotguid.sh` | 修「ABL 报 ValidateSlotGuids: BootableSlot _<x> does not have valid guids ⇒ 掉 fastboot」。 | 4 |
| `scripts/rootfs-minbase-build.sh` | 最小 Debian 根（GPT-minimal 路线的 A6 前置件）驱动脚本 | 13 |
| `scripts/serial-capture.sh` | 等 USB 串口节点出现后把内容落盘（给「设备 boot 起来但不知道卡在哪」用） | 6 |
| `scripts/serial-fanout.sh` | 读一个 tty 并把内容追加到文件（供 systemd 常驻运行）。 | 8 |
| `scripts/serial-log.sh` | Capture the tablet's serial console (kernel printk goes to ttyGS0 -> host /dev/ttyACM0). | 11 |
| `scripts/serial-logger.sh` | 跨重启自动重连抓取平板调试串口 (ttyACM)。 | 41 |
| `scripts/serial-probe.sh` | 独占串口并「敲一下」：把当前 ttyACM0 的输出与回声抓下来 | 6 |
| `scripts/serial-run.sh` | 通过设备 USB CDC-ACM 串口 (/dev/ttyACM0) 执行一条命令并打印回显 | 18 |
| `scripts/serial-sysrq.py` | 通过 USB 串口控制台发 SysRq（免物理断电复位/取栈）。 | 5 |
| `scripts/serial-tap.py` | 稳定的设备串口落盘（替代 serial-logger.sh 的 cat 循环） | 18 |
| `scripts/sleep-bisect.sh` | 在设备上做「相机模块 ⇄ 熄屏掉电」最小模块集二分。 | 12 |
| `scripts/sleep-cumulative.sh` | 累积式加载相机模块组，每加一组就真实熄屏一次。 | 9 |
| `scripts/sleep-sweep.sh` | 主机侧自动扫掠：设 camera.conf → 反复重启 → 每次真实熄屏 → 记 存活/掉电。 | 23 |
| `scripts/slot-attr.py` | read/patch the A/B slot metadata stored in the GPT | 289 |
| `scripts/slotboot-run.sh` | P2「槽位正常启动路径」最小形态上机（2026-11-01） | 19 |
| `scripts/start-desktop.sh` | Phosh (Wayland) desktop on the TB322FC panel. | 71 |
| `scripts/to-fastboot.sh` | reliable Linux → fastboot, using the PSCI vendor-reset hook. | 115 |
| `scripts/uefi-a-slot-prepare.sh` | 让 **a 槽**能跑自研件（G1-29 flashed 形态的前置；幂等） | 41 |
| `scripts/uefi-flashed-trial.sh` | flashed 形态（写 boot_a）一发的**免屏计时判据**取证（G1-29 线） | 36 |
| `scripts/uefi-usb-gap.py` | 用 USB 出现/消失时刻给「fastboot boot 之后到底发生了什么」计时。 | 5 |
| `scripts/waydroid-cam-restart.sh` | restart the Waydroid stack after a vendor.img swap. | 17 |
| `scripts/waydroid-camera-bake.sh` | bake the self-built 64-bit external camera provider into | 17 |
| `scripts/waydroid-cmdline-fix.sh` | 让 Waydroid 容器不受宿主 `androidboot.mode=charger` 影响 | 6 |
| `scripts/waydroid-haptics-aidl-deploy.sh` | 部署 AIDL V2 vibrator HAL（TASKS C10 二期：幅度 + cancel） | 12 |
| `scripts/waydroid-haptics-bake-patch.py` | 幂等打「马达透传固化」的产品配置补丁（TASKS C10 三期） | 9 |
| `scripts/waydroid-haptics-bake-vendor.sh` | 马达透传**固化**进容器 vendor 镜像（TASKS C10 三期） | 5 |
| `scripts/waydroid-haptics-setup.sh` | 部署「Waydroid 马达透传」桥（TASKS §6 ⑤） | 16 |
| `scripts/waydroid-headless-restart.sh` | Clean restart of the headless Waydroid stack (Q28-bad boots, no compositor). | 7 |
| `scripts/waydroid-headless-start.sh` | Start Waydroid headless: headless weston + waydroid session + container. | 6 |
| `scripts/waydroid-mesa-swap.sh` | 在 Y700 设备上把新编的 Mesa/gralloc 库 bind-mount 进 Waydroid 容器 | 16 |
| `scripts/waydroid-ota-serve.sh` | Serve local Waydroid OTA (system+vendor) to the tablet over USB-Net. | 6 |
| `scripts/waydroid-proxy-setup.sh` | 让 Waydroid 容器可访问 Google（复用主机 Clash 代理） | 10 |
| `scripts/wd-c1-noworkaround.dev.sh` | C1 验收（**在设备上以 root 运行**） | 6 |
| `scripts/wd-ctl.sh` | Waydroid 设备端控制/查询（**全部快速返回，绝不长等待**） | 33 |
| `scripts/wd-net-baseline.dev.sh` | RUN ON DEVICE (as root). 起 Waydroid 并取容器网络基线(A)。 | 7 |
| `scripts/wd.sh` | 主机侧 Waydroid 快捷控制（**每次 <15s 返回，绝不长等待**） | 11 |
| `scripts/win-x86-rootfs.sh` | 构建/部署 glibc aarch64 rootfs（Win-x86 转译 PoC 阶段A） | 14 |

## 造件（71）

| 入口 | 用途 | 引用 |
|---|---|---|
| `scripts/android-ext4-slim-test.py` | 在**副本**上删掉指定的 Android 分区子树，量出真实可回收块数。 | 4 |
| `scripts/android-img-grepmap.py` | 在 ext4 镜像里按字面串定位「哪个文件含有它」，不需要 root/loop。 | 3 |
| `scripts/android-img-inventory.py` | 只读遍历 Android ext4 分区镜像，输出 TSV 清单（路径/类型/权限/大小）。 | 5 |
| `scripts/android-img-lswalk.py` | 用 debugfs 只读递归列目录，输出 TSV（type/mode/uid/gid/size/path）。 | 6 |
| `scripts/android-min-build.sh` | 「最小安卓全量线刷包」构建器（主机侧；stage 化，可重入） | 4 |
| `scripts/android-rom-segassemble.py` | 把线刷包里「一个分区被拆成多段」的 img 按 XML 拼回整分区镜像。 | 5 |
| `scripts/android-slim-v2-plan.sh` | 「安卓干净瘦身 v2」计划器（主机侧；默认只打印，不写任何东西） | 10 |
| `scripts/android-super-scan.py` | forensic scan of a super partition that was shipped as | 11 |
| `scripts/android-super.py` | read/inspect Android dynamic-partition ("super") images. | 58 |
| `scripts/apply-kernel-fragment.sh` | 把配置片段合并进内核树 .config，并导出新快照 | 33 |
| `scripts/asset-install-linux.sh` | 把 assets/android-20261119/ 里的原厂安卓资产装到 Linux 桌面 | 11 |
| `scripts/b3b-session-retry.sh` | 零构建实验：在坏发台上重走一次 modeset，看面板是否点亮。 | 7 |
| `scripts/bench-install.sh` | 设备侧：安装可选基准工具（需要网络） | 11 |
| `scripts/boot-img-cmdline.py` | 从一个已存在的 boot.img 里取出 kernel/ramdisk/dtb， | 51 |
| `scripts/bootimg-replace-kernel.py` | 只替换 Android boot image 的内核段，其余逐字节保留。 | 10 |
| `scripts/build-athm-probe.sh` | Q26 Step A probe: CONFIG_ATH12K=m single-shot build. | 3 |
| `scripts/build-boot-slim.sh` | G1-30（= G1-29 路线 C）：最小 initramfs 版 boot.img | 10 |
| `scripts/build-boot.sh` | 打包 fastboot 可启动 boot.img（kernel + Alpine rootfs ramdisk + DTB） | 150 |
| `scripts/build-ffrumble.sh` | 交叉编译 ffrumble（aw86927 FF_RUMBLE 宿主侧阳性对照工具） | 12 |
| `scripts/build-initramfs.sh` | 可复现地构建 initramfs 资产（唯一真源 = initramfs/init） | 31 |
| `scripts/build-kernel.sh` | rebuild kernel/DTB for TB322FC (elden), with ccache. | 86 |
| `scripts/build-locked-chain.sh` | 为 **BL locked** 单元生成 b 槽 mainline 自洽链（AOSP testkey） | 25 |
| `scripts/build-manifest.sh` | record everything needed to identify/rebuild a boot image. | 28 |
| `scripts/build-modular-overlay.sh` | layer the modularized payload driver bundle | 13 |
| `scripts/build-payload-hook.sh` | 往已有 ramdisk 追加「payload 加载钩子」最小层 | 3 |
| `scripts/build-phoc-arm64.sh` | 产出「广告 wp_linux_drm_syncobj_manager_v1」的 aarch64 phoc（C12 L2） | 16 |
| `scripts/build-phosh-arm64.sh` | 产出带「output power 失败即视为屏亮」修复的 aarch64 phosh | 6 |
| `scripts/build-phosh-upstream-fix.sh` | 用「上游 main 源树 + 本地补丁」编 aarch64 phosh（验证上游补丁用） | 3 |
| `scripts/build-sensord.sh` | 编译 eldroid-sensord（C4 数据源 daemon）： | 11 |
| `scripts/build-vbmeta-b.sh` | 重签 b 槽自签 AVB vbmeta（自签链，把 chain `boot` 指向**现役** avb.key） | 14 |
| `scripts/audio-tplg/build.sh` | 构建 TB322FC 的 AudioReach topology (Lenovo-Y700-Gen4-tplg.bin) | 87 |
| `scripts/wd-audio-test/build.sh` | Build the Waydroid container-audio test dexes (TestAudio / TestCodec / ListCodecs). | 87 |
| `scripts/c1-iprule-build.sh` | build the vk95 kernel that enables policy routing | 4 |
| `scripts/detect-memory-corruption.py` | 找出「页缓存里的内容 ≠ 磁盘上的内容」的文件。 | 14 |
| `scripts/dev-super-relabel.sh` | 设备侧（POSIX sh）：把 Android `super`（sda10，22 GiB 动态分区容器）转成 Linux 分区 | 16 |
| `scripts/env-build.sh` | shared host build environment for the elden kernel tree. | 55 |
| `scripts/esp-apply.sh` | 把主机侧目录树「一条命令」组装成 FAT32 镜像并写进 eldenesp 分区（S5 自动化）。 | 23 |
| `scripts/esp-install-grub.sh` | 把主机侧造好的 standalone GRUB（arm64-efi）装上 ESP 的 \EFI\BOOT\BOOTAA64.EFI | 36 |
| `scripts/extract-avbpubkey.py` | 从带 AVB vbmeta header 的镜像提取 public key blob（.avbpubkey）。 | 6 |
| `scripts/extract-avf-assets.sh` | 从原厂 system 镜像离线提取 AVF（Android Virtualization | 8 |
| `scripts/extract-mesa-libs.sh` | 从 Waydroid AOSP 构建产物里抽出 Mesa/gralloc 动态库（方案 B 用） | 16 |
| `scripts/fetch-x86-assets.sh` | 主机侧下载 Win-x86 转译 PoC 所需离线资产到 pkgs-x86/ | 7 |
| `scripts/ffs-extract.py` | 解厂商 UEFI 固件（FV/FFS/section 递归 + LZMA/GUID 段） | 20 |
| `scripts/gapps-mirror-setup.sh` | 把 GAPPS system 镜像接入本地 OTA 源（生成 GAPPS.json + 软链） | 5 |
| `scripts/gen-history.sh` | 从 git log 机械生成 HISTORY/days/*.md，并现查统计。 | 130 |
| `scripts/gen-pinyin-lexicon.py` | 从 CC-CEDICT 生成「拼音 → 词」候选词库（供 elden-pinyin-completer 用）。 | 0 |
| `scripts/gen-sessions.py` | 从 git show <REV>:RESOURCES.md 的 §4 会话索引机械生成 SESSIONS/ 角度文件夹。 | 21 |
| `scripts/grub-arm64-arming-build.sh` | 用「嵌入菜单」重打 arm64 GRUB（UEFI 复测用），带自校验 | 12 |
| `scripts/grub-arm64-cjk-font.sh` | 给 GRUB 嵌入菜单造「中文可用」的主字体（pf2） | 5 |
| `scripts/grubfat-build-uefi-bootimg.sh` | 把"可自举 UEFI 卷"包成 Android boot.img（间接引导层·路线 A 的打壳步骤） | 7 |
| `scripts/gunyah-rm-bringup.sh` | 在机内核上把 Gunyah RM 栈拉起来并验证一次真实 RM RPC。 | 9 |
| `scripts/host-mem-build-stress.sh` | 用真实构建压测宿主内存（无 ECC 机器专用） | 5 |
| `scripts/audio-ucm/install.sh` | deploy the ALSA UCM2 config for Lenovo-Y700-Gen4 (TB322FC/elden). | 16 |
| `scripts/lore-fetch-raw.py` | 按 Message-ID 直接从 lore 取 raw（自动过 Anubis PoW）。 | 42 |
| `scripts/manifest-from-image.py` | 从**镜像本身**重建 `.manifest`（源树已删/丢失时用）。 | 8 |
| `scripts/mesa-build.sh` | 只构建 Waydroid vendor 需要的 Mesa/gralloc 模块（比 make vendorimage 快得多） | 18 |
| `scripts/mkbootimg.py` | minimal AOSP boot image v2 builder (elden project vendored copy). | 74 |
| `scripts/pack-cloud-backup.sh` | 把「本机独有、不可重下」的二进制整理成一个可直接上传云盘的目录 | 9 |
| `scripts/phoc-build-launch.sh` | 以 root 在**独立 session** 里启动 build-phoc-arm64.sh（脱离调用者的进程组， | 3 |
| `scripts/phoc-install.sh` | 把自编 phoc 装到设备并**钉住**，防 apt 覆盖（PITFALLS #654） | 19 |
| `scripts/phosh-install.sh` | 把自编 phosh 装到设备并**钉住**，防 apt 覆盖（同 PITFALLS #654 的 phoc 做法） | 4 |
| `scripts/rambuild.sh` | 内存盘构建区（RAM build scratch）辅助（见 .pi/plans/2026-10-15_081500-内存盘构建区规划.md） | 4 |
| `scripts/rebuild-vk64-image.sh` | 重建 Q24/N5b 台架镜像 out/boot-elden-vk64.img | 24 |
| `scripts/reports-index.py` | 由文件名 + 首个 `# ` 标题生成 `reports/README.md`（只读报告，只写这一个文件）。 | 16 |
| `scripts/sd-variant-build.sh` | build one sleep-death (熄屏→关机) candidate kernel + boot.img. | 5 |
| `scripts/setup-session-greetd.sh` | switch the TB322FC Alpine session between the | 23 |
| `scripts/sign-boot-b.sh` | Sign a mainline boot image for slot b (self-signed AVB, see bootslot-b/README.md). | 45 |
| `scripts/uefi-bootimg-dump-v0.py` | dump Android boot image v0 header fields (one line per field) + summary. | 6 |
| `scripts/uefi-build-variant.sh` | 在 7-mu-lenovo 树上构建一个 **可追溯的 UEFI 变体**（G1-29 线） | 41 |
| `scripts/uefi-r21-p7-ladder.sh` | UEFI R21「p7 / preamble7」一族镜像的**唯一重建入口**（G1-29 线，纯主机侧） | 154 |
| `scripts/uefi-repack-v2aligned.py` | 把 UEFI payload（BootShim + FD）打成一个 **ABL 会真跳进去** 的 boot.img。 | 22 |

## 取证（46）

| 入口 | 用途 | 引用 |
|---|---|---|
| `scripts/abl-log.sh` | 从在机 Linux 读 ABL/PBL 启动日志（logfs 分区里的 UEFILOG1.TXT） | 13 |
| `scripts/android-lpdump.py` | 只读解析 Qualcomm 线刷包里的「分段 super」（LP metadata + extents）。 | 13 |
| `scripts/arm-console-run.sh` | 零写盘启动一个显示臂，用串口内核控制台取证（不依赖 SSH）。 | 21 |
| `scripts/b5-u2-atomic-timeline.sh` | M6/B5 **U2** 取证门：原子回调时序（零写盘、可复跑） | 8 |
| `scripts/backup-triage.sh` | backup/ 去重与分级处置（默认 dry-run） | 5 |
| `scripts/bb-magic-scan.py` | DDR 窗口魔数扫描（0xA5A5A5A5 连续段）。 | 3 |
| `scripts/bench-run.sh` | 设备侧 CPU/GPU/内存/磁盘 基准（task-7，工具自适应，缺少的自动跳过） | 25 |
| `scripts/blackout-passive-scan.sh` | 黑屏期诊断：被动扫描（只听 beacon）能否听到该 AP | 6 |
| `scripts/blankspy.sh` | one-second forensic heartbeat around screen blank (G1-22/Q24). | 14 |
| `scripts/c0-android-evidence.sh` | C0「真 Android 对照取证」采集器 | 12 |
| `scripts/deskstack-sample.sh` | A 臂采样：屏幕保护状态机 + 背光/DPMS + 按键计数。POSIX sh，整文件 scp 到 /tmp 再跑。 | 3 |
| `scripts/devlogs.sh` | runtime log capture for feature bring-up/verification. | 11 |
| `scripts/display-drop-forensics.sh` | 设备侧「桌面显示栈自发掉线」一次抓全 | 3 |
| `scripts/f2fs-host-bench.sh` | f2fs vs ext4 的主机 loop 台架（G1，零设备写盘） | 3 |
| `scripts/fb-survey.py` | 事后从 DRAM 读回 splash_region，还原 shim 的「整屏纯色」执行轨迹。 | 4 |
| `scripts/grubfat-inspect.sh` | 引导链取证（四代 TB322FC / 三代 TB321FU 通用，可参考 BOOTCHAIN-2026-10-05） | 12 |
| `scripts/gui-freeze-watch.sh` | 抓 PITFALLS #106「进 GUI 后整机卡死」的现行。 | 6 |
| `scripts/gui-stress.sh` | 给 PITFALLS #106「进桌面后整机卡死」造**真实** GUI/GPU 负载。 | 7 |
| `scripts/iterate.sh` | 统一迭代入口（日常用它；已于 2026-11 取代并删除根目录 build.sh/pack.sh/cycle.sh）。 | 71 |
| `scripts/kmsgspy.sh` | capture kernel log to disk with line buffering + frequent sync, so the last | 8 |
| `scripts/logfs-decode.py` | 解析 `logfs` 分区（8 MiB = 10 × 64 KiB 环形 ABL 日志）。 | 12 |
| `scripts/n5b-vk64-death-rate.sh` | N5b：在 vk64（7.2 血统）RAM 内核上重复 | 32 |
| `scripts/out-status.py` | out/ 造件生命周期账本门（2026-11-20，arch-audit P1#6） | 14 |
| `scripts/q28-clkdiag.sh` | 设备侧**只读**取证：一次冷起后立刻跑，用来区分 | 18 |
| `scripts/q28-coldboot-collect.sh` | 等一次**真实 POR 冷起**，起来后立刻跑 q28-clkdiag.sh 并归档。 | 9 |
| `scripts/q28-devprobe.sh` | 设备端三态判定 Q28 冷起显示结果。POSIX sh。 | 58 |
| `scripts/q28-devprobe2.sh` | device-side Q28 classification, L1/L2-separated (POSIX sh). | 49 |
| `scripts/q28-disp-ab-sample.sh` | 取「一发」Q28 显示初始化补丁 A/B 冷起样本。 | 8 |
| `scripts/q28-por-rounds.sh` | 取 N 发**真实 POR 冷起**的 Q28 同口径样本（每发 = 用户一次断电开机）。 | 23 |
| `scripts/q28-watchdog.sh` | 主机侧管理：把 Q28 运营兜底看门狗装到设备/开关/查状态。 | 42 |
| `scripts/q32-boot-evidence.sh` | Q32（暖起 vs 冷起）**只读取证**：把「本次启动的复位深度」与 | 10 |
| `scripts/qemu-full-chain-smoke.sh` | QEMU 复刻「AAVMF → GRUB → EFI-stub → vk188 内核 → 串口 dmesg」全链 | 12 |
| `scripts/skewcal-frame-stats.sh` | 在锁内抓 N 帧存设备 /tmp，再用 python3 统计（distinct/stddev/非零占比）。 | 4 |
| `scripts/skewcal-measure.sh` | 一次 M4 SKEW_CAL A/B 出流测量（设备是唯一串行资源 → 单次测量整体包在 device-lock 内）。 | 4 |
| `scripts/static-scan.py` | check-doctor §6 的静态卫生扫描（bashism / 死脚本）。 | 35 |
| `scripts/suspend-boot-panic-capture.sh` | 把「CONFIG_SUSPEND=y 后启动即死」(vk128/vk129) 变成可判定的 panic 栈 | 7 |
| `scripts/suspend-resource-sample.sh` | 待机/唤醒的「间接资源测量」采样器（设备侧，POSIX sh） | 28 |
| `scripts/t5-q24-capture.sh` | T5：给 Taniya Das（Q24 语境）的三件套采集 | 6 |
| `scripts/tf-stress.sh` | TF 卡（SDHCI/SDC2）写稳定性压测（在设备上以 root 运行） | 7 |
| `scripts/thermal-stress.sh` | 温控压测驱动（在设备上运行） | 12 |
| `scripts/thermal-watch.sh` | 用户态温控监控守护 (SM8750 / TB322FC "elden") | 23 |
| `scripts/uefi-grubcfg-arming.sh` | 把设备 /boot/grub/grub.cfg 的「默认臂」改成可诊断的 UEFI 复测臂 | 4 |
| `scripts/uefi-logfs-read.py` | 经 fastboot `oem sbread` 读回 UEFI 持久化诊断日志（logfs 尾部 16 KiB 窗口）。 | 11 |
| `scripts/uefi-r21-sbstop-ladder.sh` | R21 诊断阶梯：**宿主侧**定位 DXE→BootLinux 的随机同步异常落点 | 10 |
| `scripts/uefi-sbstop-patch.py` | 把 boot.img v2 头里的 cmdline 换成 `sbstop=N`，用于 R21 诊断阶梯。 | 11 |
| `scripts/wifi-scan-refresh.sh` | 连通态周期扫描：让「可用 WiFi 候选榜」不掉成只剩已连接那一项 | 24 |

## 一次性（2）

| 入口 | 用途 | 引用 |
|---|---|---|
| `scripts/android-assets-extract-20261119.py` | 从已上机的精简 system_a.img 提取安卓原厂资产 → assets/android-20261119/ + MANIFEST.tsv | 10 |
| `scripts/mailbox-cleanup-20261102.py` | USTC mailbox cleanup 2026-11-02. | 13 |

## 公共库（7）

| 入口 | 用途 | 引用 |
|---|---|---|
| `scripts/lib-boot-ready.sh` | 「复位/进 fastboot 前的系统就绪门」（host 侧，经 SSH 判定当前运行的系统） | 34 |
| `scripts/lib-device-lock.sh` | the SINGLE source of the tablet device lock. | 52 |
| `scripts/lib-fastboot.sh` | fastboot / ssh 设备调用的安全封装（2026-11-09 工具挂死调查产物） | 33 |
| `scripts/lib-hosttools.sh` | 主机侧外部工具（fastboot / adb）落点解析（2026-11-21） | 10 |
| `scripts/lib-serial-source.sh` | 串口日志的唯一采集实现（被 suspend/n5b 等采集脚本 source）。 | 11 |
| `scripts/lib-ssh.sh` | 设备 SSH 调用的单一实现（选项统一 + 一次往返批量取状态） | 25 |
| `scripts/lib-wait.sh` | 「等设备到某个状态」的单一实现（check-first + 指数退避 + 换代判据） | 35 |

## 其它（37）

| 入口 | 用途 | 引用 |
|---|---|---|
| `scripts/android-launcher-db-trim.py` | 裁剪 /system/etc/launcher.db 的默认桌面布局（纯主机侧、不用 root）。 | 6 |
| `scripts/android-v3-bringup-walkthrough.sh` | 安卓精简 v3「首启验证」上机执行包（S1–S5，默认 dry-run） | 26 |
| `scripts/blackbox.py` | UEFI 早期可见性「DDR 黑匣子」读写/解码工具（主机侧，经 ssh 走设备）。 | 26 |
| `scripts/deskstack-switch.sh` | 桌面栈整档切换（phoc + phosh 全套），用于 T20/T19 的 A/B 对照 | 3 |
| `scripts/elden-backlight-floor.sh` | 背光下限守护（防止「看起来像黑屏」） | 19 |
| `scripts/bisect/eldtest.sh` | vk34→vk40 回归的「渐进触发」自动化测试（2026-10-03） | 12 |
| `scripts/esp-put-loader.sh` | 把一份 Loader.efi（Mu LinuxLoader 变体）放到设备 ESP 的 /EFI/elden/， | 19 |
| `scripts/fix-ab-mark-successful.sh` | 让设备每次启动都把自己所在的 A/B 槽标记为「启动成功」。 | 43 |
| `scripts/glycin-bwrap-shim.sh` | let glycin run its image loaders without the bwrap sandbox. | 4 |
| `scripts/grub-arm64-standalone.sh` | 主机侧造 arm64-efi 的 standalone GRUB（G1-29「启动菜单」载荷） | 20 |
| `scripts/grub-bootfiles.sh` | 从 Android boot.img 取出「GRUB 直接启动」所需三件，并（可选）落到设备 /boot | 14 |
| `scripts/grubenv-set.sh` | 在**设备**上直接改 GRUB 的 grubenv（不依赖设备装 grub-editenv） | 14 |
| `scripts/hide-android-partitions.sh` | 让 GNOME/GTK 文件管理器（Nautilus、GTK 文件选择器、Phosh 栈里的任何 | 14 |
| `scripts/hk-save-decrypt.py` | decrypt/encrypt Hollow Knight user*.dat saves. | 4 |
| `scripts/lane.sh` | baseline+fork workflow for concurrent agents (see .pi/CONCURRENCY.md). | 34 |
| `scripts/lf2-expected.py` | 复算 GRUB LoadFile2 补丁（elden_lf2_*）对同一份 initrd 的期望值。 | 8 |
| `scripts/mail-append-sent.py` | 把「已发出但 Sent Items 没有账」的邮件补写进 IMAP `Sent Items`。 | 15 |
| `scripts/mailbox-cleanup-weekly.sh` | 每周邮箱整理（2026-11-02 用户批准）：只删「非我方线程 + 非直接发我 + 早于 7 天」的列表流水。 | 3 |
| `scripts/odirect-sha.py` | 绕过页缓存（O_DIRECT）算 sha256 的硬门工具。 | 54 |
| `scripts/openrc-enable.sh` | switch the TB322FC (elden) persistent root from the ad-hoc | 39 |
| `scripts/partlun.py` | TB322FC 分区名 → UFS LUN 的**静态归属表** + 「同名歧义拒绝」。 | 11 |
| `scripts/q28-reboot-until-good.sh` | Reboot the tablet until the panel actually inits (Q28 GOOD boot) — bounded. | 7 |
| `scripts/q32-arm.sh` | Q32 三臂实验的单发执行器（暖起 vs 冷起）。 | 23 |
| `scripts/qemu-ramoops-initrd-ab.sh` | QEMU 复现「ramoops zone 盖住 initrd ⇒ 内核自己的 console | 11 |
| `scripts/real-vs-ladder.sh` | 在**真内核载荷**上跑 VS_STOP 阶梯（p17 件，零写盘） | 5 |
| `scripts/recent-sessions.sh` | 开工前核实「最近 N 轮会话进度 vs 文档」的一步入口。 | 25 |
| `scripts/scale.sh` | Live scale change for DSI-1 via wlr-randr (no phoc restart needed). | 9 |
| `scripts/sd-run-variant.sh` | boot one sleep-death (熄屏→关机) candidate zero-write and | 15 |
| `scripts/send-upstream-report.py` | 发送 cambistmclkcc 上游报告 + patch 到 linux-arm-msm | 3 |
| `scripts/sess.sh` | 本项目（y700-elden）的会话检索入口。 | 29 |
| `scripts/suspend-drain-rate.sh` | 量化「相机栈在位 + 真 suspend」的掉电率（%/h） | 8 |
| `scripts/switch-kernel-abi.sh` | 在内核「ABI 变体」之间原子切换（内核镜像 + 模块树一起换） | 11 |
| `scripts/t2-stock-lun45.sh` | T2: 按 LUN 刷原厂（LUN4 全套 + LUN0 全套），日志到 artifacts/bl-stuck-20261118/flash/T2.log | 24 |
| `scripts/time-sync.sh` | wait for network, step the clock from NTP, then keep chronyd | 41 |
| `scripts/uefi-ddr-trial.sh` | DDR 黑匣子专用上机循环（多条重复，只统计真正交棒的发次） | 22 |
| `scripts/uefi-oneshot.sh` | 真载荷单档一发：换新 UEFI 会话 → 载 preamble → 打一个 stage → 判读 | 18 |
| `scripts/win-x86-run.sh` | 在设备 glibc-rootfs chroot 内运行 Win-x86（Box64+Wine）命令 | 11 |

## 孤立件（引用数 = 0）

没有脚本、也没有文档提到这些 basename。**不等于可删**：很多是人手跑的入口。处置建议 = 要么在 `TASKS/README.md` 或某报告里落一条指针（变活），要么标「一次性」并说明留档理由。

- `scripts/gen-pinyin-lexicon.py` — 从 CC-CEDICT 生成「拼音 → 词」候选词库（供 elden-pinyin-completer 用）。
