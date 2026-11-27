# D16 — `verify.sh` 在线档 34 条「设备上不存在」逐条分类（2026-11-27）

**范围/口径**：纯主机侧 + 设备**只读**取证（`ssh elden` + `sudo -n`；未安装/未启动/未停止任何服务、未 reboot、未 commit）。
**时点**：2026-11-27 14:0x CST（设备 uptime 3h，内核 `7.3.1-debug-vk189-suspend-00005`，Debian 13 trixie，根画像 systemd）。
**门禁现状**：`bash packaging/elden-userland/tools/verify.sh` → `FAIL=0 WARN=34`（本次复跑，原文见 §5）。

> **与派工单数字的偏差（先纠偏）**：派工单写「20 条单元 + 14 条文件」，实测是 **15 条单元 + 19 条文件 = 34**。
> 逐条以门禁输出为准（§5.1 原文），下表 34 行与输出**一一对应**，无遗漏无新增。

## 1. 一页结论表（34 行）

判据列一律给「设备实测命令 → 实测输出」；拿不到证据的写「判不了，需上机确认」。

### 1.1 渲染单元（15 条，期望路径 `/etc/systemd/system/<name>.service`）

| # | 名字 | 它干什么（读 unit/脚本头注） | Debian 根上是否还需要（判据 → 实测） | 处置 |
|---|---|---|---|---|
| 1 | `ath12k-retry` | 冷起首次 ath12k PCI 探测失败（MHI POWER_ON -110）后，把**仍无驱动**的设备重新 bind，让 phy0/wlan0 出现 | **已被 `ath12k-rescan.service` 取代**：`systemctl status ath12k-rescan` → `enabled; Active: inactive (dead) since 11:07:17; ExecStart=echo 1 > /sys/bus/pci/devices/0000:01:00.0/remove; sleep 2; echo 1 > /sys/bus/pci/rescan (status=0/SUCCESS)`，且 `nmcli -t device status` → `wlan0:wifi:connected:ustcnet`（dmesg 仍见首探 -110 ⇒ 恢复机制确实生效） | **登记豁免**（设备侧已有等价单元；⚠ 该单元只在设备上、不在仓库 → 见 §6 风险 R1） |
| 2 | `backlight-floor` | 把 AW99706 背光钳在 FLOOR（1024/4095）之上，防「GOOD 面板被误判成黑屏」 | **还需要，且实测缺口在**：`cat /sys/class/backlight/aw99706-backlight/{max_brightness,brightness}` → `4095` / `486`（≈11.9% < 1024）；`ps -eo args \| grep backlight-floor` → 空；`/var/log/backlight-floor.log` 不存在；连续两次采样 `446 → 527 → 486`（亮度自己在变，说明无人钳） | **部署** |
| 3 | `bt-alias` | btqca 固件下载完后设适配器 alias 并上电（oneshot，后台等下 hci0） | **部分已被取代 + 一部分当前被刻意关闭**：`bluetoothctl show` → `Name: elden / Alias: elden`（alias 已在 `/var/lib/bluetooth/22:22:62:9C:97:58` 持久化）；`sudo -n rfkill list` → `0: hci0: Bluetooth Soft blocked: yes`，`Powered: no / PowerState: off-blocked` ⇒ 上电一节与当前受限状态冲突，需人裁定 | **登记豁免**（裁定 BT 需求前不部署） |
| 4 | `elden-bootlog` | 每次启动写一份带 `boot_id` 的证据快照 `/var/log/dmesg-$id.txt` | **还需要**（唯一功能未被覆盖）：`ls /var/log/elden-boot*` → 只有 `/var/log/elden-boot.log`（单文件、被 /init 每启动覆盖、73920 字节，无 boot_id 分档）；脚本本体缺失 ⇒ 历史启动证据留不下来 | **部署**（unit + 脚本） |
| 5 | `elden-hapticd` | Waydroid vibrator 透传桥：把容器对 `/sys/class/leds/vibrator/*` 的写入翻成 aw86927 FF_RUMBLE | **还需要**（≠ 被 `ffrumble` 取代：`ffrumble` 是 EV_FF 客户端，本件是容器→宿主 LED 接口的桥）：`ls /usr/local/bin/elden-hapticd` → 不存在；`/usr/local/libexec/elden/elden-hapticd.pre` **存在**（hook 已铺、二进制没铺）；`waydroid status` → `Waydroid is not initialized` ⇒ 容器侧无法验收 | **部署**（先按 `sources.tsv` 重建二进制；验收依赖 waydroid init） |
| 6 | `elden-powerlog` | 关机前写 `/root/powerlog.txt` 干净关机标记（Q24/G1-22 唯一可靠判别器） | **还需要**：`sudo -n ls /root/powerlog.txt` → `没有那个文件或目录`；`/var/log/powerlog*` 也不存在；脚本本体缺失 ⇒ 当前没有任何干净/脏关机判别依据 | **部署**（unit + 脚本） |
| 7 | `gunyah-modprobe` | 加载 Gunyah RM 驱动栈（`services.tsv` 里 `enabled=0`，2026-10-25 裁决 BLOCKED） | **不需要（有意不部署）**：`ls /lib/modules/$(uname -r)/kernel/drivers/gunyah` → 不存在（模块树里没有 gunyah）；`lsmod \| grep gunyah` → 空 | **登记豁免**（保留定义 + `enabled=0`；门禁应跳过） |
| 8 | `net-selfheal` | 三件事：0 字节 `/etc` 配置自愈、CA 信任链修复、**wlan0 PMTU 钳到 1400 + 关 power_save**（热点上游黑洞） | **还需要，且 PMTU 缺口实测在**：`ip -d link show wlan0` → `mtu 1500`（>1400）；`curl https://github.com` → `code=000 time=10.0s`（超时），而 `https://mirrors.ustc.edu.cn` → `200 0.09s`（境内正常）；`ps` 无 net-selfheal ⇒ 无人钳。信任链一节当前**无缺口**：`/etc/ssl/certs/ca-certificates.crt` = 224449 字节、`/etc/ca-certificates.conf` 161 行 | **部署**（`/usr/local/libexec/elden/net-selfheal.pre` 已在设备上） |
| 9 | `net-up` | 开机经 NetworkManager 把 wlan0 拉起来（Alpine 期 /init 不走 systemd 时的替身） | **已被 NetworkManager autoconnect 取代**：`nmcli -t device status` → `wlan0:wifi:connected:ustcnet`；`nmcli -t -f NAME,DEVICE connection show --active` → `ustcnet:wlan0`；且 `/init:617` 该脚本调用被 `[ "$init_mode" = legacy ]` 门住，systemd 根上**根本不执行** | **登记豁免**（真需要手动排障时用设备已有的 `net-up-manual.sh`/`net-up-nm.sh`） |
| 10 | `pstore-catch` | 开机把 ramoops 里「上次死挂」记录归档到 `/var/log/pstore`（ramoops 一断电就没） | **还需要**：`sudo -n dmesg \| grep ramoops` → `reserved mem ... ramoops@c2000000`、`pstore: Using crash dump compression: deflate`（ramoops 确实注册）；`sudo -n ls /sys/fs/pstore` → 空目录；`/var/log/pstore` → 不存在；脚本本体缺失 ⇒ 死挂证据从没落过盘 | **部署**（unit + 脚本） |
| 11 | `q28-boot-watchdog` | Q28「冷起只有背光」运营兜底：判坏发自动重启（上限跨启动计数），PITFALLS #228 | **还需要**：`systemctl list-unit-files \| grep q28` → 空；`ps`/journal 均无该服务；只有脚本 `/usr/local/sbin/q28-boot-watchdog.sh` 在、且无人调用（`grep -n q28-boot-watchdog /init` → 空，`/init` 只在 legacy 分支拉同类件） | **部署** |
| 12 | `ssc-udp-relay` | 每传感器一条 `ssccli` 流，翻成 UDP 文本喂 Waydroid sensor HAL（`127.0.0.1:52012`） | **还需要（消费者缺席，无法端到端验收）**：`/usr/bin/ssccli` 在、`/usr/bin/python3` 在，但 `/usr/local/bin/ssc-udp-relay.py` 不存在；`ss -lunp \| grep 52012` → 无监听；`waydroid status` → `Waydroid is not initialized` | **部署**（脚本 + unit；验收待 waydroid init） |
| 13 | `time-sync` | 等网络就位后从 NTP 步进时钟（PMIC RTC 对我们只读，冷起 1970 破坏 TLS） | **已被 `chrony.service` 取代**：`systemctl is-enabled chrony` → `enabled`；`is-active` → `active`；`timedatectl` → `System clock synchronized: yes / NTP service: active`；`chronyc tracking` → `Reference ID CA264011 (ipv6dns.ustc.edu.cn) / Stratum 3 / System time 0.000378s fast`。且 `/init:636` 的调用同样只在 legacy 分支 | **登记豁免** |
| 14 | `waydroid-ipv6` | 维持 waydroid0 双栈：宿主 ULA `fd00:240::/64` + NAT66 + 容器两张策略路由表 | **判不了，需上机确认**：`ip -br addr show waydroid0` → `Device "waydroid0" does not exist`；`waydroid status` → `not initialized` ⇒ 无活体可验，缺口/冗余都证不了。语义（容器 netd 策略路由需要 eth0/eth0_local 表默认路由）来自脚本头注，非实测 | **部署（挂起验收）**（脚本 + unit 先落地，waydroid init 后再判是否真生效） |
| 15 | `wifi-scan-refresh` | 连通态周期扫描（170 s），防 NM 连通后停扫导致 AP 候选榜塌成只剩当前项（PITFALLS #354） | **还需要（当前未观测到症状，机制缺口成立）**：`ps \| grep wifi-scan-refresh` → 空；`/var/log/wifi-scan-refresh.log` 不存在；`nmcli -f SSID,IN-USE device wifi list` → 15 项（含非当前 AP）= 此刻**未塌**。但设备上确实没有任何进程在周期扫描（NM 1.52 的 bgscan 写死逻辑见脚本头注），且 `/usr/local/libexec/elden/wifi-scan-refresh.pre` 已在设备上 | **部署**（语义红线：间隔 170 s < 180 s） |

### 1.2 MANIFEST 文件（19 条）

| # | 路径 | 它干什么（读文件头注） | Debian 根上是否还需要（判据 → 实测） | 处置 |
|---|---|---|---|---|
| 16 | `/etc/conf.d/backlight-floor` | `backlight-floor` 的环境文件（`BACKLIGHT_FLOOR=1024`） | **还需要**：`ls /etc/conf.d/backlight-floor` → 不存在；unit 的 `EnvironmentFile=-/etc/conf.d/backlight-floor` 是可选但当前无任何途径覆盖默认值 | **部署**（随 #2） |
| 17 | `/etc/conf.d/elden-hapticd` | `elden-hapticd` 参数（`--amp-a/--amp-b 0xffff`，README 红线：默认必须 255=0xffff） | **还需要**：设备不存在；`/usr/local/libexec/elden/elden-hapticd.pre` 已在 | **部署**（随 #5） |
| 18 | `/etc/conf.d/greetd` | 我们渲染 greetd unit 用的 `LIBSEAT_BACKEND=seatd` | **已被发行版 unit 取代**：`/usr/lib/systemd/system/greetd.service:12` → `Environment="LIBSEAT_BACKEND=seatd"`（发行版自带）；`systemctl is-active greetd` → `active`、`seatd` → `active` | **登记豁免**（仅当部署我们渲染的 greetd unit 时才需要） |
| 19 | `/etc/xdg/autostart/elden-waydroid.desktop` | 在 Phosh 会话里 autostart `waydroid-session.sh`（拉起 Android 会话） | **还需要**：`ls /etc/xdg/autostart/` → 无任何 elden-waydroid 项；`grep -rn waydroid-session /etc/xdg /etc/greetd /root/.config` → 无命中（消费者脚本 `/usr/local/sbin/waydroid-session.sh` **在**，却没有启动入口） | **部署** |
| 20 | `/usr/local/bin/bwrap` | glycin sandbox 探测 shim（假装 namespace 失败，让 gdk-pixbuf 直接跑 loader，避免 phosh 图标断言崩溃） | **当前未观测到症状 ⇒ 暂不需要**：`/usr/bin/bwrap` 真实二进制在；`journalctl -b \| grep -icE 'gtkiconhelper\|gdk-pixbuf\|glycin'` → **0**；phosh 已稳定跑 3h（`pgrep -a phosh` → 1486）。且本根 `/init` 里 `grep glycin\|bwrap` → 空（旧 init 的自动铺 shim 逻辑不在本代） | **登记豁免**（复现图标崩溃时再上；处置权给用户） |
| 21 | `/usr/local/bin/elden-ime-mode` | 在 `term`(fcitx5 占 waylandim)/`osk`(让给 **squeekboard**) 两种模式间切 | **仅 squeekboard 期产物**：`dpkg -l squeekboard` → `un (未安装)`；`command -v squeekboard` → 空；`pgrep -a squeekboard` → 空；脚本 `restart_all()` 直接 `pkill squeekboard` + `setsid /usr/bin/squeekboard` ⇒ 在本根上是坏路径。当前 OSK owner = `phosh-osk-stub`(1803) | **应当退役**（脚本头加 RETIRED，注明「squeekboard 未进入 Debian 根；OSK 由 phosh-osk-stub 承担」） |
| 22 | `/usr/local/bin/elden-ime-toggle` | 触屏入口：调 `sm.puri.OSK0.SetVisible` 唤起/折叠 OSK | **判不了（功能可达，需求未定）**：`busctl --user --address=unix:path=/run/user/1001/bus list` → `sm.puri.OSK0  1803 phosh-osk-stub`（接口 owner 实测在，SetVisible 路径应仍有效）；但 `ls /usr/share/applications \| grep ime` → 无 `elden-ime-toggle.desktop`，仓库内也无调用者 ⇒ 是否要这个按钮由用户定 | **登记豁免**（保留候选；需用户裁定是否要「触屏键盘」入口） |
| 23 | `/usr/local/bin/eldroid-bootctl` | Linux 侧刷机控制（reboot reason + A/B 槽位元数据，py3） | **已被取代（仓库已判退场）**：`scripts/to-fastboot.sh:7` → 「旧路径 `eldroid-bootctl` 已随 Alpine 根退场」；`scripts/doctor/28-soft-bl-selftest.sh:43` → 反回归门「不许再调设备侧 eldroid-bootctl」；现役路径 = `systemctl reboot bootloader`（`/usr/local/sbin/elden-to-bootloader` 在设备上）+ `ab-mark-successful`（enabled，`multi-user.target.wants`） | **应当退役** |
| 24 | `/usr/local/bin/feedback` | 往会话总线发 feedbackd 事件（`org.sigxcpu.Feedback.TriggerFeedback`） | **消费者不存在 ⇒ 死代码**：`dpkg -l feedbackd` → `un (未安装)`；`busctl list \| grep -i sigxcpu` → 空；`ls /usr/share/dbus-1/services \| grep feedback` → 空 | **应当退役** |
| 25 | `/usr/local/bin/q28-race-hunt.sh` | Q28 显示上电竞态（背光亮无画面 / vblank -110）密集复现 + rpm/ftrace 取证脚本 | **是人手工具，不是服务**：仓库内无调用者；设备上不存在（跑过一次即可弃）；Q28 已转入运营兜底（#11） | **登记豁免**（调试件；需要时从 `files/` 现拷） |
| 26 | `/usr/local/bin/ssc-udp-relay.py` | 见 #12（`ssccli` → UDP 文本协议翻译器） | **还需要**：设备不存在；`ss -lunp \| grep 52012` → 无；`ssccli`/`python3` 均在 | **部署**（随 #12） |
| 27 | `/usr/local/bin/vibrate` | 手感测试件：对 aw86927 的 input event 连发 N 次 `/usr/local/bin/ffrumble <e> <ms> 0xffff` | **人手测试件**：`ffrumble` 在设备上（EF_FF 客户端，运行时路径已固化）；本件仅一次性手感校准，仓库/设备均无调用者 | **登记豁免** |
| 28 | `/usr/local/sbin/elden-bootlog.sh` | 见 #4 | **还需要**（单文件 `/var/log/elden-boot.log` 覆盖式，无 boot_id 归档） | **部署** |
| 29 | `/usr/local/sbin/elden-bt-alias.sh` | 见 #3 | **随 #3 裁定**：alias 已持久化、上电被 rfkill soft-block 屏蔽 | **登记豁免** |
| 30 | `/usr/local/sbin/elden-powerlog-mark.sh` | 见 #6 | **还需要**：`sudo -n ls /root/powerlog.txt` → 不存在 | **部署** |
| 31 | `/usr/local/sbin/gunyah-modprobe.sh` | 见 #7 | **不需要（有意不部署）**：模块树无 gunyah | **登记豁免** |
| 32 | `/usr/local/sbin/pstore-catch.sh` | 见 #10 | **还需要**：ramoops 在、`/var/log/pstore` 不存在 | **部署** |
| 33 | `/usr/local/sbin/waydroid-ipv6` | 见 #14 | **判不了，需上机确认**（waydroid0 不存在） | **部署（挂起验收）** |
| 34 | `/usr/share/elden-pinyin/META.json` | 拼音词库元数据指纹（`gen-pinyin-lexicon.py` 产出：CC-CEDICT / 80127 keys / 23 shards） | **运行时无消费者**：`/usr/share/elden-pinyin/shards/` 23 个分片**已在设备上**；`strings /usr/local/bin/elden-pinyin-completer` → 只引用 `/usr/share/elden-pinyin/shards/<..>` 与 `/var/cache/elden-pinyin/index.json`，**无 META.json** | **登记豁免**（可选随 shards 一起部署，作词库版本指纹） |

**处置汇总**：部署 **18**（unit 10 + 文件 8）｜登记豁免 **13**｜应当退役 **3**。

## 2. 「需要部署」清单（可直接照做；键位 = 上表 #）

| # | 目标路径 | 来源（仓库） | 权限/属主 | 关联单元依赖 | 落地后验收判据（只读） |
|---|---|---|---|---|---|
| 2 | `/etc/systemd/system/backlight-floor.service` | `out/units/systemd/backlight-floor.service` | `644 root:root` | `Requires=local-fs.target`，`WantedBy=multi-user.target` | `systemctl is-enabled/is-active`；`cat /sys/class/backlight/aw99706-backlight/brightness` ≥1024；`/var/log/backlight-floor.log` 出现 |
| 16 | `/etc/conf.d/backlight-floor` | `files/etc/conf.d/backlight-floor` | `644 root:root` | 同上（`EnvironmentFile=-`） | `systemctl show -p Environment backlight-floor` 后续实测钳位值 |
| 8 | `/etc/systemd/system/net-selfheal.service` | `out/units/systemd/net-selfheal.service` | `644 root:root` | `Requires=local-fs.target`、`After=NetworkManager.service`、`ExecStartPre=/usr/local/libexec/elden/net-selfheal.pre`（**已在设备**） | `ip -d link show wlan0` → `mtu 1400`；`curl https://github.com` → 200 |
| 15 | `/etc/systemd/system/wifi-scan-refresh.service` | 同上 | `644` | `Requires=dbus.service`、`After=NetworkManager.service`、pre hook **已在** | `systemctl is-active`；`nmcli device wifi list` 项数在 3 min 后仍 >1 |
| 11 | `/etc/systemd/system/q28-boot-watchdog.service` | 同上 | `644` | `Requires=local-fs.target`、`After=greetd.service` | `systemctl is-enabled`；`/var/log/q28-watchdog.log` 有本次启动记录 |
| 4 | `/etc/systemd/system/elden-bootlog.service` + `/usr/local/sbin/elden-bootlog.sh` | unit + `files/usr/local/sbin/elden-bootlog.sh` | `644` / `755 root:root` | `Requires=local-fs.target` | `ls /var/log/dmesg-$(cat /proc/sys/kernel/random/boot_id).txt` 存在 |
| 6 | `/etc/systemd/system/elden-powerlog.service` + `/usr/local/sbin/elden-powerlog-mark.sh` | unit + `files/usr/local/sbin/elden-powerlog-mark.sh` | `644` / `755` | `DefaultDependencies=no`、`Before=shutdown.target`，`WantedBy=poweroff/reboot/halt.target` | 一次干净重启后 `sudo ls -l /root/powerlog.txt` |
| 10 | `/etc/systemd/system/pstore-catch.service` + `/usr/local/sbin/pstore-catch.sh` | unit + `files/usr/local/sbin/pstore-catch.sh` | `644` / `755` | `Requires=local-fs.target` | 下次死挂后 `ls /var/log/pstore` 非空 |
| 5 | `/etc/systemd/system/elden-hapticd.service` + `/usr/local/bin/elden-hapticd` + `/etc/conf.d/elden-hapticd` | unit + **二进制按 `sources.tsv:10` 重建**（`bash scripts/build-hapticd.sh` → `out/hapticd/elden-hapticd`）+ `files/etc/conf.d/elden-hapticd` | `644` / `755` / `644` | `Before=waydroid-container.service`、`ExecStartPre=/usr/local/libexec/elden/elden-hapticd.pre`（**已在设备**）；红线：amp 默认 `0xffff` | `systemctl is-active`；`waydroid shell cmd vibrator_manager vibrate 500`（**需先 `waydroid init`**） |
| 12 | `/etc/systemd/system/ssc-udp-relay.service` + `/usr/local/bin/ssc-udp-relay.py` | unit + `files/usr/local/bin/ssc-udp-relay.py` | `644` / `755` | `Requires=dbus.service`；依赖 `ssccli`（在，`apt-list` 提供者见 `svc-deps.tsv` 同族） | `ss -lunp \| grep 52012` 有监听；`journalctl -u ssc-udp-relay` 无 `ssccli not found` |
| 14 | `/etc/systemd/system/waydroid-ipv6.service` + `/usr/local/sbin/waydroid-ipv6` | unit + `files/usr/local/sbin/waydroid-ipv6` | `644` / `755` | `Requires=waydroid-container.service`、`After=NetworkManager.service` | `waydroid init` 后：`ip -6 addr show waydroid0` 有 `fd00:240::/64`；`ip -6 route show table eth0_local` 有默认路由 |
| 19 | `/etc/xdg/autostart/elden-waydroid.desktop` | `files/etc/xdg/autostart/elden-waydroid.desktop` | `644` | 消费者 `/usr/local/sbin/waydroid-session.sh`（**已在设备**） | 会话内 `pgrep -a waydroid`；`waydroid status` 不再 `not initialized` |

**部署顺序建议**：2/16 → 8 → 15 → 4/6/10（低风险 oneshot/longrun，可先落地） → 12/14/5/19（依赖 `waydroid init` 才能验收）。
**注意**：本线**不做**设备写入；上表只是 parent 落地依据。落地后必须重跑 `bash packaging/elden-userland/tools/verify.sh`（预期 WARN 从 34 掉到 ~16：豁免项需同步登记进 `services.tsv`/豁免表，退役项 WARN 消失）。

## 3. 登记豁免清单（写进 `services.tsv` 或 `verify.sh` 豁免表）

| # | 名字 | 豁免理由（一句话，全部带上面实测判据） |
|---|---|---|
| 1 | `ath12k-retry` | 设备侧 `ath12k-rescan.service`（enabled，11:07:17 status=0/SUCCESS）+ wlan0 connected 已覆盖同一目标 |
| 3 | `bt-alias` | alias 已持久化（`Alias: elden`），power-on 与 `rfkill soft blocked: yes` 现状冲突，等用户裁定 BT 需求 |
| 7 / 31 | `gunyah-modprobe`（unit + 脚本） | `enabled=0` + 本内核模块树无 gunyah，属有意不部署 |
| 9 | `net-up` | NM autoconnect 实测已拉起 wlan0；`/init` 该调用仅 legacy 分支 |
| 13 | `time-sync` | `chrony.service` enabled+active、`timedatectl synchronized: yes`、`chronyc tracking` stratum 3 |
| 18 | `/etc/conf.d/greetd` | 发行版 `greetd.service:12` 自带 `LIBSEAT_BACKEND=seatd` |
| 20 | `/usr/local/bin/bwrap` | 本 boot journal 无 glycin/gdk-pixbuf 症状（0 命中），phosh 稳定运行 |
| 22 | `elden-ime-toggle` | `sm.puri.OSK0` owner 存在但无调用者/`.desktop`，是否要入口待裁定 |
| 25 | `q28-race-hunt.sh` | 人手取证工具，非服务，无常驻消费者 |
| 27 | `vibrate` | 人手手感校准件，运行时由 `ffrumble` 承担 |
| 29 | `elden-bt-alias.sh` | 随 #3 |
| 34 | `/usr/share/elden-pinyin/META.json` | 运行时（`elden-pinyin-completer`）只读 `shards/` + `/var/cache` 索引，不读 META.json |

## 4. 应当退役（3 条，建议在文件头加 `RETIRED` 注释 + 从 MANIFEST 摘除）

| # | 名字 | 退役依据 |
|---|---|---|
| 21 | `/usr/local/bin/elden-ime-mode` | 硬依赖 `squeekboard`（`dpkg -l` = `un` 未安装）；本根 OSK = `phosh-osk-stub`(1803) |
| 23 | `/usr/local/bin/eldroid-bootctl` | `scripts/to-fastboot.sh:7` 已判退场；`doctor/28` 有反回归门禁禁止再调；现役 = `elden-to-bootloader` + `ab-mark-successful` |
| 24 | `/usr/local/bin/feedback` | 目标 daemon `feedbackd` 未安装（`dpkg -l` = `un`），`org.sigxcpu.Feedback` 无 owner |

## 5. 设备只读取证原文摘录

### 5.1 门禁（本次复跑，节选 F 段与汇总）
```
[F. 设备逐字比对]
  根画像 systemd（init-mode=systemd / overlay=无）
  WARN  /etc/conf.d/backlight-floor: 设备上不存在（期望来源 MANIFEST）
  ...（共 19 条 MANIFEST 文件）
  WARN  /etc/systemd/system/ath12k-retry.service: 设备上不存在（期望来源 unit）
  ...（共 15 条 unit）
  DIFF  /usr/local/bin/elden-ime-focusd: 设备 5cf98e1d… ≠ 清单 8bfab82e…（重编？）
  DIFF  /usr/local/bin/ffrumble: 设备 28a20d11… ≠ 清单 cdff41ab…（重编？）
==== verify: FAIL=0 WARN=34 ====
```

### 5.2 单元/文件存在性（一次性 ssh，逐条）
```
=== UNITFILES (ours-ish) ===
cam-mode-off.service  enabled  |  charge-watch.service enabled  |  greetd.service enabled
lisgd-edge-swipe.service enabled  |  qbootctl.service enabled  |  time-sync.target static
=== 15 条目标单元 is-enabled / is-active ===
ath12k-retry … wifi-scan-refresh（15 行）：enabled=not-found  active=inactive
=== FILES EXIST（19 条）===
ABSENT /etc/conf.d/backlight-floor … ABSENT /usr/share/elden-pinyin/META.json   ← 19/19 全 ABSENT
```
对照：设备 `/usr/local/sbin` 里 **8 个脚本在**（`elden-backlight-floor.sh` `wifi-scan-refresh.sh` `net-selfheal.sh` `net-up.sh` `q28-boot-watchdog.sh` `ath12k-retry.sh` `time-sync.sh` `charge-watch.sh`），且 `/usr/local/libexec/elden/` 6 个 pre/stop hook **全在**（`11月25日 13:16`）——即「脚本与 hook 已铺、unit 从未装」。

### 5.3 为什么 unit 从未运行（不是「跑过又坏了」）
```
ps -eo pid,etime,args | grep -E "backlight-floor|wifi-scan-refresh|time-sync|net-up|net-selfheal|q28-boot-watchdog|..."
  634  02:59:32 /bin/sh /usr/local/sbin/charge-watch.sh        ← 只有 charge-watch（它有 unit，enabled）
journalctl -b -u <15 个名字>.service | wc -l   → 全部 0 行
ls /var/log | grep -E "backlight|wifi|time-sync|net-selfheal|q28|haptic|ssc|bootlog|pstore"  → 只有 charge-watch.log
```
`/init` 里这些脚本的调用全部被 `[ "$init_mode" = legacy ]` 门住（`/init:617`，行 634–636 实证），本根 `init_mode=systemd`（`/etc/elden-init-mode` = systemd）⇒ **systemd 根上没有任何东西会拉起它们**。

### 5.4 关键判据命令（原文）
```
nmcli -t device status                    → wlan0:wifi:connected:ustcnet / usb0:ethernet:unmanaged
systemctl is-enabled chrony; is-active    → enabled / active
timedatectl | grep -E "synchronized|NTP"  → System clock synchronized: yes / NTP service: active
chronyc tracking | head -4                → Reference ID CA264011 (ipv6dns.ustc.edu.cn) / Stratum 3 / 0.000378s fast
ip -d link show wlan0 | head -1           → ... mtu 1500 ... UP ...
curl https://github.com                   → 000 10.002768     （境外 TLS 黑洞）
curl https://mirrors.ustc.edu.cn          → 200 0.095769     （境内正常）
cat /sys/class/backlight/aw99706-backlight/{max,brightness} → 4095 / 486（两次采样 446→527→486）
systemctl status ath12k-rescan.service    → enabled; Active: inactive (dead) since 11:07:17; ExecStart=...rescan (status=0/SUCCESS)
dmesg | grep ath12k                       → failed to start mhi: -110 / failed to power up :-110（首探仍失败）
bluetoothctl show                         → Name: elden / Alias: elden / Powered: no / PowerState: off-blocked
sudo -n rfkill list                       → 0: hci0: Bluetooth  Soft blocked: yes
dpkg -l squeekboard / feedbackd           → un（均未安装）
pgrep -a phoc / phosh / phosh-osk-stub    → 1373 / 1486 / 1803 phosh-osk-stub --allow-replacement
busctl --user --address=unix:path=/run/user/1001/bus list | grep -iE "sm.puri|fcitx"
   → sm.puri.OSK0   1803 phosh-osk-stub    /  org.fcitx.Fcitx5 (activatable)
sudo -n dmesg | grep -i ramoops           → reserved mem ... ramoops@c2000000 / pstore: Using crash dump compression: deflate
sudo -n ls /sys/fs/pstore                 → （空目录）        ls /var/log/pstore → 不存在
sudo -n ls /root/powerlog.txt             → 没有那个文件或目录
sudo -n ls /lib/modules/$(uname -r)/kernel/drivers/gunyah → 不存在
waydroid status                           → Waydroid is not initialized, run "waydroid init"
ip -br addr show waydroid0                → Device "waydroid0" does not exist
journalctl -b | grep -icE "gtkiconhelper|gdk-pixbuf|glycin"  → 0
```

## 6. 残余风险 / 判不了项

- **R1（真风险）**：`ath12k-rescan.service` 只在设备 `/etc/systemd/system`，**不在仓库**（`grep -r ath12k-rescan` 仓库仅本报告）。换根/重装即丢 ath12k 恢复能力 → 建议后续 lane 把它固化进 `services.tsv`（本线不改 `services.tsv`）。
- **R2**：`wifi-scan-refresh` 与 `waydroid-ipv6` 的缺口是**机制性**（无人常驻），当前无可见症状（候选项 15 个、waydroid 未 init）⇒ 部署后需连续观测才能证收益。
- **R3（判不了）**：`waydroid-ipv6`（#14/#33）在 `waydroid init` 之前**无法**判「还需不需要」，只能挂起验收。
- **R4（判不了）**：`bt-alias` 的 `Powered: no` 是刻意（rfkill soft-block）还是漏配，本线无证据，需用户裁定。
- **R5**：`elden-hapticd` 二进制不在 git（`sources.tsv` 有重建命令），部署需先 `bash scripts/build-hapticd.sh`；本线未构建（不改产物）。
- **R6**：门禁两条 `DIFF`（`elden-ime-focusd` / `ffrumble` 设备 sha ≠ 清单）仍在，属重编件，本线未处理（不在本次判据范围）。
