# 经验总入口（LESSONS）

> 新会话**动手前先读本文件**；它是散落在 `PITFALLS.md`、`.pi/memory/*`、`archive/topics/复盘-*`、
> `GAPS.md` 风险登记、`.pi/skills/*/references/` 里的踩坑经验的**统一入口**。
> 由 `db/build.py --lessons` 从 `PITFALLS.md` 生成索引；正文与细节仍以原文为准。

---

## 0. 零号纪律（先做这三件事）

1. **先查本地既有结论再取证**：`grep -rn -iE "unlock|解锁|rollback|testkey|GPT|EDL" ~/y700-elden/*.md archive/topics/*.md .pi/skills/*/references/*.md`（`PITFALLS` #87）。
2. **动分区/刷写前备份**：`fastboot fetch <分区>` + GPT 双表 dump；**写后读回校验**（不看"传输完成"）。
3. **单一远程通道的持久系统上不做自锁式实验**（电源/熄屏/网络）；先 RAM 引导验证（`PITFALLS` #87、复盘-持久化与睡眠）。

## 1. 其他经验来源（一并扫）

| 来源 | 内容 |
|---|---|
| `PITFALLS.md` | 本文件索引的正文（#1–#87，按主题） |
| `.pi/memory/FAILURES.md` | 反复踩的环境/工具类坑（pgrep 自杀、adb root 吞命令…） |
| `.pi/memory/HINDSIGHT.md` | 阶段性 hindsight 与决策（含 API 限流、swarm 补丁） |
| `GAPS.md` §4 风险登记 | 高影响风险与缓解 |
| `archive/topics/复盘-*.md` | 逐轮操作史与根因 |
| `.pi/skills/*/references/*.md` | 机型/刷写专项经验（正文不入上下文，需 grep） |

## 2. PITFALLS 分类索引

### 一、引导 / fastboot / 重启交接

- **#1** A/B 槽会漂移：进过 Android/TWRP/多次 fastboot boot 后，current-slot 可能 a↔b。
- **#2** 内核 reboot 后总落 fastboot，是 ABL 的正常回退，不是故障：
- **#3** fastboot 不能跑批量脚本/连续命令：这台机响应差、易卡。
- **#4** fastboot boot 失败后 bootloader 会进"脏"状态（连续报 Load Error）；fastboot reboot bootloader 可清。
- **#5** 不要指望 kexec 换内核：CONFIG_KEXEC=y，kexec -l/-s -l 都能装载成功，
- **#6** boot.img 必须 ≤96 MiB（boot_a=0x6000000）；超了 fastboot boot 会 Bad Buffer Size。
- **#7** USB gadget 重枚举有延迟：设备已进 Linux 但主机可能十几秒内看不到 enx/ttyACM0，等一下即恢复；别急着判定死机。
- **#8** SSH 失效时的救急通道：串口 /dev/ttyACM0（CDC-ACM，getty on ttyGS0，直接 root shell）：

### 二、内核 / DTS / 构建

- **#9** make olddefconfig 会删掉 CONFIG_ARCH_QCOM 整行！ 改 .config 后绝不跑它。
- **#9b** ★ 编内核忘了 export ARCH=arm64 会毁掉 .config（2026-09-30 实际踩到）：
- **#10** ABL 会拿 stock dtbo overlay 我们的内嵌 DTB → 卡 logo。解决：向两个槽写假 dtbo（4KB 全零）。
- **#11** reserved-memory 节点名 splash-region（连字符）→ ABL 找不到 splash_region 就关显示；必须下划线。
- **#12** &mdss_dp0 必须 disabled：DP 是无 ADSP 就永远 defer 的 DRM component，
- **#13** CONFIG_PHY_NXP_PTN3222=y（eUSB2 repeater 要内置，不能是 =m），否则 M31 PHY 起不来、无 USB。
- **#14** CONFIG_BACKLIGHT_AW99706=y，否则 panel Failed to get backlight。
- **#15** 不要打作者的 Mesa chip-id 补丁（...44050000→...44050001）：本机内核报 0xE844050000（patchid 00），
- **#16** 显示间歇性坏：偶见 drm_crtc_wait_one_vblank call trace 刷屏（DPU 等不到 vblank → 只有背光无文字）。

### 三、存储 / 分区 / 持久化

- **#17** LUN4 尾部 last_parti 的 Type-UUID 是全零 → 内核 GPT 解析器跳过它，不生成 /dev/sde79。
- **#18** LUN0 无空闲（userdata 到盘尾）；要加分区必须缩 super/userdata（有数据风险）。
- **#19** tar 拷贝会保留主机 uid（1000） → sshd 报 /var/empty must be owned by root 拒绝启动，
- **#20** 持久 root：initramfs 的 init 检测 cmdline elden_root=LABEL=linux → 挂载 → switch_root 到磁盘 /init。

### 四、固件 / 外设（反提取 vendor 资源）

- **#21** ADSP 固件命名必须是 qcom/sm8750/adsp.mdt（+ adsp.bXX + adsp_dtb.*），
- **#22** 功放 aw88461 的 ACF：vendor 的 firmware/aw882xx_acf.bin 内容就是 aw88461 的 ACF（含 "aw88461" 字样）。
- **#23** 音频出声还需设备 tplg qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin（mainline AudioReach 拓扑）。
- **#24** WiFi = ath12k / PEACH（PCI 0x110e，不是 WCN7850/0x1107！），固件目录 ath12k/PEACH/hw2.0/。
- **#25** 触屏固件：novatek_ts_csot_3k_fw.bin（vendor firmware/）。
- **#26** 蓝牙：qca/brhbtfw20.tlv + brhbtnv20.bin + brhperifw20.tlv + qca/tmel_peach_20.elf；
- **#27** GPU zap 必须设备签名版（vendor gen80000_zap.mbn），linux-firmware 版被 TZ 拒（-EINVAL）。

### 五、设备上装包 / 环境

- **#28** 早前"瘦身"Mesa/LLVM 时手删了文件但 apk 数据库还在 → apk add 不恢复（认为已装）。
- **#29** 设备无外网。让设备直连 apk：主机 socat TCP-LISTEN:7898,fork,reuseaddr TCP:127.0.0.1:7897（0.0.0.0:7898→本地 CN 代理），
- **#30** socat 后台化时别 pkill -f 'TCP-LISTEN:7898' —— 会匹配到自己的命令行把当前 shell 杀掉（现象：命令 exit 143 无输出）。

### 六、脚本 / 工具

- **#31** busybox tar 不支持 --ignore-failed-read：probe.sh 里用它导致拷贝为空。用整目录 tar czf。
- **#32** 主机编内核依赖：gcc-aarch64-linux-gnu flex bison libssl-dev libelf-dev libncurses-dev bc。
- **#33** 主机代理：http://127.0.0.1:7897（env 已设）；GitHub 大文件易截断，走代理。
- **#34** apk info -W <file> 可查文件属于哪个包；apk fix 重装。

### 七、Wayland / 桌面（weston）

- **#35** weston 14 的 drm-backend 不再接受 --tty=1（VT 改由 libseat 管理）：
- **#36** weston-screenshooter 在无输入/无 shell 授权时返回 Output capture error: unauthorized：
- **#37** weston-terminal 需要真实字体：只装 fontconfig 不够，必须装字体（apk add font-dejavu），
- **#38** 桌面自启：磁盘 root 模式下（on_initramfs=0）/init 调用 /usr/local/sbin/start-desktop.sh

### 八、恢复 Android / 免解 BL root 资产（2026-09-29）

- **#39** 1.5.10.259 免解 root 原理：高版本固件改了分区签名；老法（改分区 + 旧签名）会卡机。
- **#40** 回 Android 两步走：① 先 fastboot --set-active=<另一槽>（非破坏，见第 1 条）；
- **#41** EDL 救砖链：fastboot oem edl 或 adb reboot edl → ~/y700-elden/qdl/build/qdl -s ufs restore-259/xbl_s_devprg_ns.melf read/write <分区> <文件>。

### 九、WiFi / ath12k / 装包（2026-09-29）

- **#42** WiFi(PEACH) 缺的不是 board-2.bin，而是 qdss_trace_config.bin：本机 PEACH 定制 ath12k 在 TME-L 后
- **#43** ★禁区：在线 ath12k 设备绝不能 remove/unbind：实测两次都把内核挂死→重启→fastboot。
- **#44** 开机首探 MHI -110 是竞态：ath12k 在 ~1.9s probe，WCN 未就绪→MHI 超时→设备留未绑定。
- **#45** 主线能充电，不必改电源驱动：qcom-battmgr-bat STATUS=Charging，“插着净掉电”只是 PC USB 口供电不足。
- **#46** USB 离线装包（推荐，避开设备侧代理超时）：主机 qemu-aarch64 跑 rootfs 的 apk fetch --recursive →
- **#47** 持久 root 只有 2.3 GiB：Phosh(~900MB) 能装；Plasma Mobile(~1.6GB) 装不下。装大桌面前先看 df /。

### 十、桌面 / Phosh（2026-09-29）

- **#48** Phosh 锁屏默认要 PIN：sm.puri.phosh.lockscreen require-unlock 默认 true；
- **#49** gdk-pixbuf 2.44 全走 glycin，glycin 的 bwrap 沙箱会让 loader exit 1 → GTK 断言 → phosh abort。
- **#50** apk 说已装 ≠ 文件在：mesa-gl 在包库里是 installed，但 /usr/lib/libGL.so.1 实际缺失
- **#51** gnome-session 必需组件失败 → fail whale：org.gnome.SettingsDaemon.Power 在无 UPower/logind 时
- **#52** ★ pkill -f <模式> 会匹配到自己的 ssh 命令行：远程执行的 sh -c '... pkill -f gnome-session-failed ...'
- **#53** Phosh 会话起来后要的东西：udevd（libinput 认触屏，否则 phoc 报无设备）、seatd（libseat 拿 DRM/输入 seat）、
- **#54** 截图取证：Phosh 内置截图可直接 D-Bus 调用（无需 grim/phosh-screenshot）：

### 十一、存储 / TF 卡 / 扩分区（2026-09-29）

- **#55** TF 卡（mmcblk0, 58.2G "NCard"）写丢失的真相：不是"完全不能写"，而是部分写丢失。
- **#56** 扩分区只有三条路（sda16 userdata = 211.4G 是唯一富余空间的内部区域；sde LUN4 总共才 4G）：

### 十二、userdata 缩容（TWRP 路线实测结论，2026-09-29）

- **#57** Gen4 的 userdata 是 metadata 加密 f2fs（metadata_encryption=aes-256-xts:wrappedkey_v0，
- **#58** ★ TWRP 的 resize.f2fs 能缩容，但 ZUXOS 不认：实测流程可行且数据在块层保留——
- **#59** TWRP 启动条件：polygraphene TWRP-3.7.1-16-TB322FC-2026-04-04-2 只有 current-slot=a 才能起；

### 十三、AVB / 免签 / KSU（2026-09-29 实测）

- **#60** fastboot boot 失败会让 current-slot 翻到 b（本轮实测两次：Booting FAILED (Status read failed
- **#61** 本机两个槽的 AVB 密钥不同：a 槽 vbmeta/boot/recovery 用 2597c218aae470a130f61162feaae70afd97f011，
- **#62** 本机 init_boot_a 早已是 KSU 补丁版（strings 里有 /data/adb/ksud、description=Android KernelSU、
- **#63** 本机已 unlocked，AVB 本来就是宽松态：ABL 传的 cmdline 含

### 十四、睡眠 / 挂起（2026-09-29）

- **#64** deep 挂起把机器挂死：cat /sys/power/mem_sleep = s2idle [deep]，/sys/power/state = freeze mem disk。
- **#65** b 槽直启打通后，reboot -f 不再回 fastboot（之前是因为 a 槽 AVB 校验失败才回退 fastboot，
- **#66** 别把"熄屏"和"挂起"混为一谈：实测把 mem_sleep 固定成 s2idle 后，桌面空闲 5 分钟
- **#67** 本机"开机→SSH 就绪"实测时间线（b 槽直启，2026-09-29，dmesg 单调秒）：
- **#68** 忙盒（BusyBox）的 pgrep/pkill -x 在本机不可靠：/usr/bin/pgrep -> /bin/busybox（v1.37.0）。
- **#69** 熄屏是 phoc 干的：/run/phosh.log 里能看到
- **#70** phoc 退出后不一定能重启：seatd 报
- **#71** 槽位"启动失败重试计数"会被耗尽 → 停在 fastboot（2026-09-30 已定位并给出根治）。
- **#72** 熄屏后无法唤醒 = 系统总线没跑 + dbus launch-helper 权限错（2026-09-30 已修复）。
- **#73** PMIC RTC 只读 → 每次开机时间回到 1970，靠 NTP 步进（2026-09-30 已落地）。
- **#74** NetworkManager 接管 wlan0（状态栏 WiFi / Settings→Network）（2026-09-30 落地）。
- **#75** 开机 D-Bus 竞态：两个脚本各起一个 dbus-daemon --system → 路径 socket 消失
- **#76** /init 没设 HOME → 会话 HOME=/，dconf 写错位置（“设置不持久”假象）（2026-09-30 发现并修复）。
- **#77** phoc 小数 scale 会被量化 → g-c-c「比例」恒显 100%；phoc.ini 不支持的值会被整个忽略（2026-09-30）。
- **#78** ★蓝牙：QCA WCN7861 驱动强制开启控制器 IBS 深度睡眠 → BR/EDR 高延迟+断连（2026-09-30）。
- **#79** ★充电："插着净掉电"= USB input_current_limit 默认 100mA（不是驱动缺失）（2026-09-30）。
- **#80** ★流程坑：把"第几台机器"当成任务角色（2026-10-02 复盘，已在文档层修正）。
- **#81** 状态才是前置条件，不是机器（2026-10-02）。例：AVF/vm/crosvm 实验的硬前置是
- **#82** 解锁链与 AVB 链是两套密钥，别混为一谈；「必须先解锁才能推 G1」是错的（2026-10-03 实物取证，U2=HA2EXB0E locked）。
- **#83** 解锁 blob 可自制，补丁字段是 Bootloader_SN 而非只有 SN（2026-10-03，源自本项目 EDL 技能早先记录，我当时漏读）。
- **#84** fastboot flash unlock 的 OKAY 不代表解锁文件生效；四代 blob 是另一种格式（2026-10-03，U2 fastboot 实测）。
- **#85** locked b 槽链：现有 bootslot-b/ 自造密钥链不适用，必须 testkey 重打全链（2026-10-03）。
- **#86** ★联想四代「1.5 高版本堵解锁、降级 1.1 才放行」已实物验证（2026-10-03，U2=HA2EXB0E 实测）。
- **#87** ★流程坑：引导链问题先「本地检索」再「外部取证」再「自研」——解锁这事 7、8 月就答完了，10-03 重推了一遍（2026-10-03 复盘）。

> 查询：`sqlite3 db/elden.db "SELECT num,title FROM pitfalls WHERE body LIKE '%关键词%'"`
