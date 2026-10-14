## 十九、重启通道 / A/B 槽位 / ramdisk 层叠 / Q28 判据（2026-10-09 深夜实测）

150. **★坏发（DPU vblank 风暴）时 `reboot` 和 `reboot -f` 一起失效**：`reboot`、包装脚本 `reboot -f`、
     `busybox reboot -f` 全都挂住不动（ssh 卡住、设备不重启，实测 uptime 继续涨）。`-f` 躲不掉是因为
     卡的不是用户态 init，而是**内核 restart 路径**（reboot notifier / device_shutdown 被 DRM 风暴占死）。
     ⇒ 坏发现场只有两条活路：`echo b > /proc/sysrq-trigger`（实测 25 s 回来；常驻装弹已把 sysrq 置 1）
     或 **`/usr/local/sbin/reboot2 <mode>`**（直接 `reboot(LINUX_REBOOT_CMD_RESTART2)` syscall，实测 5 s 进 fastboot，
     坏发下照样管用，**不经过关机链**）。⇒ 温启循环脚本应当用 `reboot2`，不要再用 `reboot`。
151. **`reboot bootloader` 在 OpenRC 模式下不进 fastboot**：`/sbin/reboot` 包装 → `busybox reboot bootloader`
     → openrc 走的是 **halt**（powerlog 里出现 `USERLAND-halt`）→ **USB VBUS 自动开机回 boot_b**，
     现象=「发了进 fastboot 的命令却回到 Linux」。这大概率就是 #143「`reboot2 bootloader` 后设备从 USB 完全消失」
     的真身（那次只是 VBUS 没把它叫醒 ⇒ 看起来像死机）。另：**`reboot2` 不带参数**会被 ABL 当成"进 fastboot"，
     设备就停在 fastboot 不动（本轮被误判成"启动次数耗尽"）。⇒ 要进 fastboot 用 `reboot2 bootloader`；
     要离开 fastboot 用 **`fastboot reboot`**（正常引导 current slot）。
152. **★RAM 直启既不扣 tries 也不置 successful ⇒ 真开机次数被 RAM 实验吃掉**：`fastboot getvar` 报
     `slot-retry-count:b:7`，而设备侧 GPT 实测 `boot_b byte6=0x37`（**retry=6、succ=0**）——ABL 每次**真**开机
     扣 1，`fastboot boot` 不扣也不置 succ；整轮 Q28 连打十几次温启 ⇒ **再 6 次就归零被置 UNBOOTABLE 永久停 fastboot**。
     ⇒ ① 救援通道：`fastboot boot <img>` **不看槽位属性**，用它进 Linux 后
     `python3 /usr/local/sbin/slot-attr.py mark-successful b`（写 primary+backup 并重算 CRC）+ `set b --retry 7`，
     并**自己解析两表条目复核**（别只看脚本自报）；② 写之前先备份 LUN4 两表（`/dev/sde`，4096 B/扇区，
     头 34 + 尾 34 扇区）；③ **任何温启循环脚本每轮开头必须自带 mark-successful 或 retry-count 预检**（<3 就停）。
     附坑：设备侧 busybox `dd` 的 `skip` 按 512 B 计（`bs=4096 skip=N` 报 `cannot skip: Invalid argument`）、
     `/usr/bin/dd` 不存在 ⇒ 读尾部扇区直接用 `python3` + `os.lseek`，别跟 dd 较劲。
     **更正（同日半夜实测）**：ABL **只在 succ=0 时**才扣 tries（`slot-attr.py` 自己的文档串就写了 unless bit6，
     我没读完就下结论）——把 boot_b 置成 `succ=1` 后连续七次真开机 retry **一直是 7**。⇒ 真正的风脸不是
     “RAM 实验偷次数”，而是 **“succ=0 这个状态本身”**：只要它掉到 0，之后每次开机都在倒计时。
     处置也从“补 retry”改成“**保证 succ=1**”（一次就永久止血，除非再被 RAM 启动覆盖）。
153. **ramdisk 层叠构建里「钩子在 /init」≠「脚本在包里」**：vk77-modular 的 `lsmod` 空，上一轮归因成
     "持久根没有该版本模块"，真因是 **ramdisk 里没有 `/usr/local/sbin/payload-modules-load.sh`**（`/init` 的
     `[ -x … ]` 判假 ⇒ 静默跳过，一点错误都不留）。⇒ 层叠 cpio 打包后必须**从产物镜像读回**断言
     （`scripts/build-payload-hook.sh` 已内置：解 boot.img → 走 cpio → 断言 `/init` 钩子 + loader + `.ko` 数量）。
     同类：`M=<dir> modules_install` 对单目录**不产出 `kernel/` 前缀**，`mod-loop.sh` 原来的
     `tar czf … kernel` 因此报 `kernel：无法 stat`；按相对路径 `find -name '*.ko' -print0 | tar --null -T -` 才对。
     另：`lsmod` 里模块名是**下划线**，用带连字符的名字 grep 会漏计（loader 的收尾计数就这么把 7 报成 4）。
155. **命令模式 DSI 面板空闲时不推帧 ⇒ `/proc/interrupts` 的 dsi_isr **增量**不能判屏幕死活**：
     nt36536 是 command-mode + DSC，DPU 只在有新帧时 trigger，桌面静止时 vsync 中断恒为 0（好发也一样）。
     本轮差点把一发好发误判成坏发（要求 delta>100 结果只 41）。正确读法：用**累计值**（实测好发 41、
     坏发 **0**，开机就没出过一帧）或直接靠 dmesg 判据（#164 STORM 共现签名；原引 #154 系编号未落条）。要拿增量做实验，得先强制持续重绘。
     另：`ScreenSaver.SetActive true` 不一定真熄屏（本轮 dpms 仍是 On，被抑制策略/活动会话挡了），
     别把“发了 D-Bus 命令”当“屏已变”。
156. **`grep -c pattern /dev/kmsg` 会永久挂住**：/dev/kmsg 是流式设备，读了就跟着日志一直读下去，
     把整条 ssh 命令卡到超时（本轮一次取证因此丢掉了后半段输出）。统计用 `dmesg | grep -c`，
     要实时跟随才用 /dev/kmsg，且必须配 `head -c`/`timeout`。：好发也出现过 4 条，正常**熄屏**也会产生（实测 `dpms=Off` 时新增）。
     可靠判据是 `command DMA timeout` + `panel init attempt … failed`（同批 7 样本零误报，见
     `.pi/plans/2026-10-09-深夜-Q28寄存器差分-模块化在机验证-槽位险情.md` §1）。老脚本 `q28-boot-cycle.sh`
     用 `VB+PU+PI` 三者相加判 BAD，方向没错但会把"熄屏产生的 vblank 噪声"记成失败 ⇒ 计数要分开看。

