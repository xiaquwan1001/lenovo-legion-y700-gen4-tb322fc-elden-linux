# 过时 Alpine 条目审计 — 脚本/可执行层（2026-11-19，只读）

判据（背景事实）：设备现态 = 自建最小 Debian 13 trixie 根（systemd PID1、1253 包、/lib/modules 整套、greetd+phoc+phosh）+ 主线内核 vk192。Alpine 时代的 `reboot2`、`eldroid-bootctl`、OpenRC（`rc-service`/`rc-update`）、`apk`、busybox applet 假成功、`doas`、`/sbin/openrc` 等在现态设备上**已不存在**。

**计数：C 类 29 条（28 行，其中 wd-c1-verify.dev.sh / wd-net-baseline.dev.sh 合并 1 行） / B 类 10 条 / A 类 7 条。**

范围 = scripts/（含 scripts/doctor/）、packaging/、rootfs/、initramfs/、cycle.sh。方法 = 全量 grep `apk|rc-service|rc-update|openrc|busybox|reboot2|doas|eldroid-bootctl` 后逐条看上下文区分主路径 / if 兜底 / 注释。scripts/doctor/ 与 check-doctor.sh 全绿（无命中）。initramfs/init 为唯一真源、其 openrc/systemd 分支是现行设计（stage.sh 写 `/etc/elden-init-mode=systemd`），不列过时。

## C 类 — 仍是可执行步骤，照跑会出错/静默做无用功（最高优先级）

| 类别 | 文件:行 | 原文片段 | 为什么过时 | 建议处置 |
|---|---|---|---|---|
| C | scripts/to-fastboot.sh:54 | `timeout -k 5 12 $SSH 'sync; eldroid-bootctl reboot bootloader' >/dev/null 2>&1 \|\| true` | 设备上已无 eldroid-bootctl；`|| true` 静默吞掉失败，脚本继续等 fastboot，失败原因被掩盖 | 主路径改 `ssh … 'reboot bootloader'`（systemd 正常关机，脚本头部注释本就推荐此路），或先重部署 eldroid-bootctl |
| C | scripts/slot-switch.sh:96-98 | `'/usr/local/bin/eldroid-bootctl reboot bootloader 2>/dev/null \|\| eldroid-bootctl reboot bootloader 2>/dev/null'` | 两级兜底都是同一个不存在的件，等效无兜底 | 兜底改为 `systemctl reboot --boot-loader-entry=…` 或 `reboot bootloader`；status 分支 159 行已有 `qbootctl` 兜底可保留 |
| C | scripts/arm-window-hunt.sh:18,28 | `timeout 20 $SSH 'reboot2 bootloader'` | reboot2 已不存在；每次 hunt 都走 21 行 SysRq-b 兜底，主路径恒失效 | 改 `reboot bootloader`（systemd）或删除 reboot2 分支 |
| C | scripts/n5b-vk64-death-rate.sh:131,167,177 | `SSH 'reboot2 bootloader' >/dev/null 2>&1 \|\| true` | 三处全部静默 no-op ⇒ 死亡率采样循环实际不会重启设备，数据全错 | 换 systemd `reboot bootloader`，且失败不要 `|| true` 吞掉 |
| C | scripts/kexec-bs-cycle.sh:22 | `timeout 12 $SSH 'sync; eldroid-bootctl reboot bootloader' >/dev/null 2>&1 \|\| true` | 同 to-fastboot，静默 no-op | 同上 |
| C | scripts/sd-run-variant.sh:35 | `timeout 15 $SSH 'sync; eldroid-bootctl reboot bootloader' \|\| true   # 无 reason 的 busybox reboot 不作兜底` | 注释里「busybox reboot」是 Alpine 时代理由；现态是 systemd，`reboot bootloader` 是正确件 | 主路径换 `reboot bootloader` |
| C | scripts/q32-arm.sh:165 | `S 'eldroid-bootctl reboot bootloader' 15 \|\| true` | 同上 | 同上 |
| C | scripts/flash-recovery.sh:63 | `$SSHO "$TAB" 'eldroid-bootctl reboot recovery' \|\| true` | 件不存在，recovery 重启静默失败 | 换 systemd 途径或重部署工具 |
| C | scripts/uefi-oneshot.sh:42 | `"${TAB:-root@192.168.7.1}" 'eldroid-bootctl reboot bootloader' >/dev/null 2>&1` | 同上 | 同上 |
| C | scripts/uefi-flashed-trial.sh:217 | `sshc 'nohup /usr/local/bin/eldroid-bootctl reboot bootloader >/dev/null 2>&1 \|\| true' 15 \|\| true` | 双层吞错，完全静默 | 同上 |
| C | scripts/uefi-ddr-trial.sh:39 | `timeout 30 $SSH 'nohup eldroid-bootctl reboot bootloader >/dev/null 2>&1 & true'` | 同上 | 同上 |
| C | scripts/uefi-r21-sbstop-ladder.sh:225 | `ssh … 'sync; eldroid-bootctl reboot bootloader'` | 同上 | 同上 |
| C | scripts/uefi-boot-trial.sh:120-121 | `S 'sync; eldroid-bootctl reboot bootloader'` | 同上 | 同上 |
| C | scripts/uefi-a-slot-prepare.sh:82 | `'nohup /usr/local/bin/eldroid-bootctl reboot bootloader >/dev/null 2>&1 \|\| true'` | 同上 | 同上 |
| C | scripts/deploy-sensord-routec.sh:31,44,53 | `apk add --no-cache libgbinder-dev …`；`apk del waydroid-sensors`；`rc-update add ssc-udp-relay default …; rc-service ssc-udp-relay restart` | 设备无 apk/OpenRC；整条部署链失效（且 /etc/init.d/ssc-udp-relay 不存在） | 改 apt 装 libglibutil/gbinder-dev + systemd unit（packaging/elden-userland/out/units/systemd 已有 ssc-udp-relay 可复用） |
| C | scripts/bench-install.sh:11-13 | `command -v apk >/dev/null 2>&1 \|\| { echo "not Alpine (no apk)" >&2; exit 1; }`；`apk update; apk add …` | 在 Debian 上直接 exit 1，基准工具装不上；有自守卫所以不致破坏，但功能失效 | 改 apt 装 sysbench/stress-ng/fio/7zip/iperf3（vkmark/glmark2 换 Debian 源或自编） |
| C | rootfs/persistent-overlay/restore.sh:16,45,61,82,107-116,123 | `apk add --no-interactive $(tr … <apk-world.txt)`；`rc-update add …`；`/usr/local/sbin/openrc-enable.sh enable` | 头注宣称「replay this snapshot onto a freshly built persistent root」——现态持久根是 Debian+systemd，整脚本会把 OpenRC/initd/busybox /sbin wrapper 灌进去，直接破坏现态 | 头部加「仅适用 Alpine 时代根，Debian 现态禁跑」硬门禁（检测 /etc/elden-init-mode 或 /sbin/openrc），或归档退休 |
| C | scripts/fix-logind-poweroff.sh:28 起 | 把 elogind 的 /sbin/{poweroff,reboot,halt} 换成直调 reboot(2) 的 wrapper（针对「Alpine busybox applet 不调 reboot(2)」） | Debian 上 /sbin/reboot 是 systemctl 的符号链接、由 systemd 正常关机；照跑会把 systemctl 链接替换掉、破坏关机/重启链 | 加 rootfs 判别守卫（systemd 现态直接退出），MANIFEST 不再往 Debian 根部署 |
| C | scripts/openrc-enable.sh（全文件） | 「switch … to native Alpine OpenRC」；写 /etc/elden-init-mode=openrc + runlevels | 设备现态 systemd；但 MANIFEST.tsv 仍登记部署到 /usr/local/sbin/openrc-enable.sh，误跑会把 init-mode 切到 openrc 而设备无 /sbin/openrc ⇒ PID1 交接失败 | 从 Debian 部署清单剔除或加 init-system 守卫 |
| C | scripts/setup-session-greetd.sh:17（用法）/正文 | `setup-session-greetd.sh install    # apk add + config + mode=greetd` | 设备侧跑 install 会 apk add 失败；该脚本仍随 MANIFEST 部署 | 改 apt 依赖清单或标注 Debian 侧等效步骤 |
| C | scripts/fix-ab-mark-successful.sh（全文件） | 修 Alpine `/etc/init.d/qbootctl`（OpenRC init.d 语法 ebegin/eend） | Debian 用 systemd unit（stage.sh 门禁 E：qbootctl 默认 enable 已覆盖）；误跑会在 Debian 上建无用的 init.d 文件 | 归档为 Alpine 历史，或加守卫 |
| C | scripts/deploy-zh-ime.sh:33 | `if apk list -I 2>/dev/null \| grep -q "^$p-"; then … else echo "  MISS $p   <-- apk add $p"` | 依赖检查恒 MISS，提示的命令照抄会失败 | 换 `dpkg -s` 检查 + apt 提示 |
| C | scripts/b3b-session-retry.sh:41,48 | `rc-service greetd stop … / rc-service greetd start` | 设备无 rc-service；greetd 现由 systemd 管（`systemctl restart greetd`） | 换 systemctl |
| C | scripts/waydroid-haptics-setup.sh:41 | `rc-update show … \|\| rc-update add elden-hapticd default` | 无 rc-update；hapticd 现为 systemd unit | 换 `systemctl enable --now elden-hapticd` |
| C | scripts/waydroid-headless-restart.sh:11,16 | `rc-service waydroid-container stop/start/status` | 同类；现态容器由 systemd unit 管 | 换 systemctl |
| C | scripts/wd-c1-verify.dev.sh:9、scripts/wd-net-baseline.dev.sh:9 | `rc-service waydroid-container start >/dev/null 2>&1` | 设备侧 dev 脚本，rc-service 不存在 ⇒ 前置步骤恒失败、后续测量在错误前提下跑 | 换 `systemctl start waydroid-container` |
| C | scripts/waydroid-proxy-setup.sh:73 | `command -v adb >/dev/null 2>&1 \|\| apk add --no-cache android-tools` | 兜底用的是 apk；Debian 上恒失败（且设备侧不需要 adb 时才走） | 换 `apt-get install -y android-tools` |
| C | scripts/net-selfheal.sh:6-10,27-33 | 主逻辑 = 修 `.apk-new` 零字节活文件；注释「`apk fix <pkg>` 修不了」 | 仍随 MANIFEST 部署到 Debian 根；在 Debian 上 find 无结果 = 纯 no-op，但读者以为它在起作用（真正要防的 Alpine 坑在 Debian 不存在） | 从 Debian 部署清单剔除，或注明仅 Alpine 根生效 |

## B 类 — 陈述当前态但已过时（读者会以为今天还这样）

| 类别 | 文件:行 | 原文片段 | 为什么过时 | 建议处置 |
|---|---|---|---|---|
| B | scripts/build-boot.sh:8 | `# 说明：设备实际启动用的是 **Alpine rootfs 当 initramfs**（与 vk27 一致：` | 现态 = Debian 磁盘根 + initramfs/init（busybox 小 initramfs）+ vk192；「Alpine rootfs 当 initramfs」是 ramdisk-kind 里的历史分支 | 注释改为「默认 rootfs-ramdisk 仅作 recovery；日常启动 = 磁盘 Debian 根」 |
| B | scripts/bench-run.sh:8,66,128 | `# 用法（设备上 root，Alpine busybox sh）：`；`(no sysbench; 可 apk add sysbench)` | 运行主体不依赖 apk，但用法行与提示会把人引向 apk | 用法行改 Debian；提示改 apt |
| B | scripts/bt-up.sh:19 | `log "bluetoothd not installed (apk add bluez)"` | 报错提示指向 apk | 改 `apt install bluez` |
| B | scripts/deploy-sensord-routec.sh:16,60,66 | `# Prereqs on device: apk add libgbinder-dev …`；`rc-service waydroid-container restart`；Rollback 提示 rc-service | 注释/回滚指引全是 Alpine 口径 | 同步改 apt/systemctl |
| B | scripts/start-desktop.sh:7-9 | 「Runs on the persistent (disk) root only; /init launches it when $on_initramfs = 0」+ 手拉 dbus/udev/seatd | 该 ad-hoc 手拉模式只在 `elden-init-mode=legacy` 生效；现态 mode=systemd、由 systemd 单元接管 | 头注标明「仅 legacy 模式使用；现态 systemd 不会走这里」 |
| B | scripts/greetd-initial-session.sh / scripts/setup-session-greetd.sh 头注 | 「TB322FC session "path A"…（postmarketOS 25.12 model）」「switch the TB322FC Alpine session」 | 会话栈现态已是 Debian 的 greetd+phoc+phosh（systemd），这些是迁移期工具 | 头注加现态说明 |
| B | scripts/test-init-preflight.sh:8-9 | 「Debian 根的 `/init` 在 preflight 第一屏就把自己判成『根不完整』…根因 = 旧 preflight…」 | 此处已写明是历史事故，但「Debian 的 busybox 包只装 /bin/busybox」描述的是 Mobian 根；现态最小 trixie 根情况未复核 | 登记即可（低风险） |
| B | rootfs/persistent-overlay/（apk-world.txt、openrc-runlevels.txt、etc-initd-*、elden-hapticd.initd、sbin-poweroff/reboot/halt、init、STATE.txt） | 整目录为 Alpine 持久根快照 | 目录未标「Alpine 时代快照」，STATE.txt 读者易当成现态 | README/STATE 顶部加现态声明（restore.sh 本体已列 C） |
| B | packaging/elden-userland/files/etc/init.d/*、out/units/openrc/*、templates/openrc-initd.in | OpenRC initd 模板与产物 | 双 init 目标设计，stage.sh 只发 systemd 单元；但 MANIFEST.tsv 同时登记 `usr/local/sbin/openrc-enable.sh`、`fix-logind-poweroff.sh`、`net-selfheal.sh` 等往 Debian 根部署（stage.sh:13 「MANIFEST.tsv 里 repo_src != "-" 的行」） | MANIFEST 增加目标 init 列（systemd-only 的行不再发往 Debian 根），与 stage.sh 门禁 D 呼应 |
| B | scripts/eldroid-bootctl 与 packaging/elden-userland/MANIFEST.tsv:2 | MANIFEST 仍登记 `/usr/local/bin/eldroid-bootctl … 14032` 要部署 | 按判据设备现态无此件 ⇒ 「要部署清单」与「现态」两处口径矛盾（要么现态其实有、要么 MANIFEST 未再发） | 核实一次设备（下轮上机时 `ls /usr/local/bin/eldroid-bootctl`），再决定是删 MANIFEST 行还是恢复部署；host 脚本群大量依赖它（见下节） |

## A 类 — 历史/沿革（登记不改）

| 类别 | 文件:行 | 原文片段 | 说明 |
|---|---|---|---|
| A | rootfs/build-rootfs.sh:2-3 | 「Build an in-RAM Alpine rootfs (aarch64)…」 | Alpine 恢复 ramdisk 构建器，路径自洽（产出 out/rootfs.cpio.gz），现态不依赖 |
| A | rootfs/build-overlay.sh:2-4、rootfs/build-camera-overlay.sh:3-6 | 「Layer local tweaks onto the prebuilt Alpine image…」 | 同上，基于旧 out 产物的 overlay 叠层，未声称现态 |
| A | scripts/build-boot-slim.sh:4 | 「瓶颈是 ramdisk（完整 Alpine rootfs ~80 MB）」 | 历史优化脚本，busybox-kind ramdisk 仍是合法产物 |
| A | rootfs/configure-ubuntu.sh / build-sysroot.sh / build-mesa-a830.sh / install-mesa-a830.sh / collect-mesa-deps.sh | Ubuntu 26.04 resolute / Mesa a830 交叉链 | Ubuntu 时代（介于 Alpine 与 Debian 之间）的产物，未声称现态 |
| A | initramfs/init:272-286、666-667 | openrc/systemd/legacy 三分支注释 | 现行设计（mode=systemd），openrc 分支保留为恢复通道，不算过时 |
| A | scripts/fix-ab-mark-successful.sh:4-7、scripts/fix-logind-poweroff.sh 头注、scripts/openrc-enable.sh 头注 | 大段「为什么（2026-10-11 实测…）」历史 | 历史动机部分保留有价值；问题在可执行本体（已列 C） |
| A | scripts/elden-powerlog.initd、scripts/deploy-sensord-routec.sh 引用的 /etc/init.d/ssc-udp-relay | OpenRC initd 文件（repo 内） | 供 openrc 目标模板使用，stage 门禁保证不进 systemd 根 |

## 附：脚本引用但设备上已不存在的件（指名会静默失败的 host 脚本）

- **`reboot2`（/usr/local/sbin/reboot2 或 /usr/local/bin/reboot2）**
  引用者：`scripts/arm-window-hunt.sh`（有 SysRq-b 兜底，失效但可继续）、`scripts/n5b-vk64-death-rate.sh`（`|| true` ⇒ **完全静默**，采样循环不重启，数据无效）、`scripts/f2fs-migrate.sh:319`（仅 die 提示文本，误导）、`rootfs/persistent-overlay/restore.sh:82-84`（自检分支，恒跳过）。
- **`eldroid-bootctl`（/usr/local/bin/eldroid-bootctl）**
  引用者（全部 `|| true`/timeout 吞错 ⇒ **全部静默 no-op，脚本继续走后续等待/判定**）：`scripts/to-fastboot.sh`、`scripts/slot-switch.sh`、`scripts/kexec-bs-cycle.sh`、`scripts/sd-run-variant.sh`、`scripts/q32-arm.sh`、`scripts/flash-recovery.sh`、`scripts/uefi-oneshot.sh`、`scripts/uefi-flashed-trial.sh`、`scripts/uefi-ddr-trial.sh`、`scripts/uefi-r21-sbstop-ladder.sh`、`scripts/uefi-boot-trial.sh`、`scripts/uefi-a-slot-prepare.sh`。这是本轮最大的一类风险：**所有「Linux→fastboot/切槽」入口共用同一失效件**。
- **`rc-service` / `rc-update` / `/sbin/openrc` / `apk`（设备侧）**
  引用者：`scripts/deploy-sensord-routec.sh`、`rootfs/persistent-overlay/restore.sh`、`scripts/openrc-enable.sh`、`scripts/fix-ab-mark-successful.sh`、`scripts/setup-session-greetd.sh`、`scripts/deploy-zh-ime.sh`、`scripts/bench-install.sh`（自守卫 exit 1）、`scripts/b3b-session-retry.sh`、`scripts/waydroid-haptics-setup.sh`、`scripts/waydroid-headless-restart.sh`、`scripts/wd-c1-verify.dev.sh`、`scripts/wd-net-baseline.dev.sh`、`scripts/waydroid-proxy-setup.sh`（apk 兜底）。
- 备注：`doas` 在范围内零命中；`scripts/doctor/` 与 `scripts/check-doctor.sh` 零命中；`cycle.sh` 仅第 30 行注释提到 openrc/busybox，无执行路径命中。

■ 结束
