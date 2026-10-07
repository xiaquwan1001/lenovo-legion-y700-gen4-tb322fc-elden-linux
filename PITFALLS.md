# 踩坑总表（TB322FC / elden mainline Linux）

> 📇 **先看 `INDEX.md`**（文档地图 + 状态裁决）。
> **给下一个会话：先读 `INDEX.md`（文档分层），再扫本文件。** 这里全是花过代价换来的教训，按主题归类。
> **本文件 = 开发经验（踩坑）唯一入口**；**「谁执行、允不允许自动跑」的行为/授权标准在 `.pi/AGENT-OPS.md`**，本文件不定义授权边界。
> 最后更新：2026-10-07（**#131 = ★boot 镜像重打包必须 unpack 原镜像取 kernel（manifest kernel 列误导）**；**#130 = ★dma-buf 只加载 system_heap、绝不 cma_heap（DmaHeap 探测序 CMA 优先）**；**#129 = 华为 P40 Pro 热点 5 GHz 平板连不上/2.4 GHz 正常（仅记录）**；**#128 = ★使能 `mdss_dp0` 阻塞 `msm_drm_bind` → 背光亮无显示（已回退）**；**#127 = ★CDSP 用 stock split 固件且必须打进 initramfs（G1-11 已起，PAS id 假设否证）**；**#126 = 槽位元数据改用 `qbootctl`（+ slot_suffix/重扫两坑）**；**#125 = `ATH12K=m` 经 select 把 `PCI_PWRCTRL_PWRSEQ` 拉成 m ⇒ PCIe 起不来**；**#124 = 熄屏掉电判别法**；**#117 = WiFi 双管理器/NM DHCP 重激活（Q26）**；**#116 = 打包可复现（cpio `--reproducible` 不归零 mtime）＋initramfs 载具固化**；#109–#114 = init 固化/开机刷屏真因/slim 无固件/BT 新观测/口径更正清单；#108 = ★vk53/vk54 启动失败根因=使能 i2c0（本机无 NFC 硬件，三分层单变量定案）；#99–#103 = 持久根模块对齐 / PipeWire 占相机 / boot 接线 / `-dirty` 镜像不可信 / `gsettings` 需 session bus；#93 = 「RAM 启动」两种镜像之辨；**§0 新增零号纪律 4（无设备证据不得写「已修复」）**；**#115 = 归因分层（驱动/内核 vs initramfs/rootfs vs 用户态）**；**§15 = 过时/废弃/功能缺陷登记**；已收窄/被推翻的条目在正文内以「⛔superseded」标记，只保留当前判据与指针）。

---

## 0. 零号纪律（动手前先做这四件事）

1. **先查本地既有结论再取证**：`grep -rn -iE "unlock|解锁|rollback|testkey|GPT|EDL" ~/y700-elden/*.md archive/topics/*.md .pi/skills/*/references/*.md`（PITFALLS #87）。
2. **动分区/刷写前备份**：`fastboot fetch <分区>` + GPT 双表 dump；**写后读回校验**（不看"传输完成"）。
3. **单一远程通道的持久系统上不做自锁式实验**（电源/熄屏/网络）；用 `fastboot boot` **零写盘**验证，而非直接改 flash。
   ⚠️ **两种「RAM 启动」别混**（#92/#93）：`-ram` 纯 RAM 变体**不启桌面/会话服务**，只适合内核/引导/分区级验证；
   **功能/服务级测试（桌面、PipeWire、蓝牙音频、Waydroid、相机出流）必须 `fastboot boot` 持久变体**（RAM 内核 + 磁盘根，同样零写盘）。
4. **无设备证据不得写「已修复/已解决」**（2026-10-06 新增）：主机侧构建/编译/能进 BDS 一律只算「未上机验证」；间歇性故障**单次样本无效**（须同口径量化 + 单变量 + 长时窗）。见 `archive/topics/SESSION-AUDIT-2026-10-06.md` §3（F2/F4）。
   参 #87、#92、#93、复盘-持久化与睡眠。

> **行为/授权（谁手敲 fastboot、何时停下请用户物理干预、何时可自主执行）见 `.pi/AGENT-OPS.md` §1；本节只讲「动手前该掌握的事实」。**

## 一、引导 / fastboot / 重启交接

1. **A/B 槽会漂移**：进过 Android/TWRP/多次 `fastboot boot` 后，`current-slot` 可能 a↔b。
   假 dtbo 必须**两个槽都写**（`dtbo_a` 和 `dtbo_b`），否则卡 logo。
   排查：`fastboot getvar current-slot`。
   ★★ **Android 卡启动动画（动画还在动、机身发热、数据没坏）→ 十有八九只是漂到了「引导链不配套」的槽。**
   2026-09-29 实测：`current-slot=b` 卡动画，仅 `fastboot --set-active=a` + `fastboot reboot` 就完好进系统、数据无损。
   **所以「进不去 Android」第一步 = 切另一个槽试试，别急着重刷/清数据。** a/b 都试一遍。
   ⚠️ **主语**：`--set-active` 属设备写操作，按 `.pi/AGENT-OPS.md` §1「先备份 GPT + 记当前 slot 再执行」；不再限定谁执行。

2. **内核 `reboot` 后总落 fastboot，是 ABL 的正常回退**，不是故障：
   - ABL 对**当前 Android 槽**做 AVB 校验，`boot_b` 公钥不匹配 / `dtbo_b` hash 不匹配 → 无法启动 → 回退 **fastboot**。
   - 主线 reboot 走 **PSCI SYSTEM_RESET**，且**没有 `reboot-mode` DT 节点** → 不向 ABL 传启动原因。
   - **清空 `misc`(sda7) 里的 `bootonce-bootloader` 无效**（已验证）。
   - 可用交接 = `fastboot boot <img>`（RAM，跳过 AVB）。
   - ABL 日志在 `logfs`（`/dev/sde68` 的 `UefiLog1.txt`），能看到它识别假 dtbo：`Dtbo hdr magic mismatch ... D7B7AB1E`。
   - **AVB 公钥资源**：该产品线有公开现成资源（酷安提到），日后做 verified-boot / 双槽直启的候选。

3. **fastboot 不能跑批量脚本/连续命令**：这台机响应差、易卡。
   一律**拆成单条简单命令**（`fastboot flash dtbo_a ...` / `fastboot boot ...` 各自单独）。
   报 **`Write to device failed (No such file or directory)`** 时：先单条 `fastboot reboot bootloader`，等待，再单条 `fastboot boot`。
   （`cycle.sh` 已按此简化：`--soft`/`--dtbo`/`--recover`/`<img>`。）
   ★ **经验事实（非授权规则）**：`to-fastboot.sh`/`cycle.sh` 类**封装脚本代跑 fastboot** 在本机故障率高，属禁忌；
   「谁执行 fastboot」见 `.pi/AGENT-OPS.md` §1（自主优先；写前先备份，异常才上报）。

4. **`fastboot boot` 失败后 bootloader 会进"脏"状态**（连续报 `Load Error`）；`fastboot reboot bootloader` 可清。
   `fastboot boot` 报 `Failed to load/authenticate boot image: Load Error` 时同理。

5. **`kexec` 换内核：不可用（已定论；⛔superseded 中间态）**——`kexec -l`/`-s -l` 均装载成功，但 **`kexec -e` 失败**：早期「黑屏挂死」，补 trans_pgd（vk54/vk58）后转为**直接掉电**；**分支点未定位**（无存活 console + APSS 看门狗永久禁用，只剩物理 UART）。⇒ **不作迭代通道**，改用 `fastboot boot`/`--flash`。
   - 取证要点（勿再重复）：`console=ttyGS0` 是 USB gadget，kexec 时必断，**不能据「无输出」判挂死**；H2（CPU offline BUG_ON）已排除；运行期 VA=48 位却 `VA_BITS=52`。
   - ⚠️ **kexec/重启实验前先 `slot-attr.py mark-successful b`**，否则扣 `boot_b` retry，~7 次后 b 变 unbootable。
   - 全量证据：`archive/topics/KEXEC-ONDEVICE-2026-10-05.md`、`KEXEC-ONDEVICE-R2-2026-10-05.md`、`KEXEC-2026-10-05.md`、`RUNBOOK §8`。

6. **boot.img 必须 ≤96 MiB**（`boot_a`=0x6000000）；超了 `fastboot boot` 会 `Bad Buffer Size`。

7. **USB gadget 重枚举有延迟**：设备已进 Linux 但主机可能十几秒内看不到 `enx`/`ttyACM0`，等一下即恢复；别急着判定死机。

8. **SSH 失效时的救急通道**：串口 `/dev/ttyACM0`（CDC-ACM，getty on `ttyGS0`，直接 root shell）：
   ```bash
   stty -F /dev/ttyACM0 115200 raw -echo
   { printf '\r'; sleep 0.5; printf '<cmd>\r'; } > /dev/ttyACM0 & timeout 5 cat /dev/ttyACM0
   ```

---

## 二、内核 / DTS / 构建

9. **`make olddefconfig` 会删掉 `CONFIG_ARCH_QCOM` 整行！** 改 `.config` 后**绝不**跑它。
   用 `scripts/config -e/-d` 后直接 `make`，并每次 `grep ^CONFIG_ARCH_QCOM= .config` 验证。
   （`build.sh` 已内置校验。）

9b. **★ 编内核忘了 `export ARCH=arm64` 会毁掉 `.config`**（2026-09-30 实际踩到）：
  裸跑 `make Image.gz dtbs` 时 Kbuild 按**宿主机**（x86_64）解析，把 arm64 的 `.config` 当垃圾、
  弹一堆 `(NEW)` 提示并**覆盖写回**，然后报 `没有规则可制作目标 Image.gz`。
  **永远用 `./build.sh` 或 `scripts/build-kernel.sh`（内置 `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`）**，
  不要手敲 `make`。
  **恢复方法（已实测）**：设备上 `zcat /proc/config.gz > /tmp/device.config` 拉回**正在运行内核的精确配置**，
  覆盖 `linux/.config` 后按正确 ARCH 重编。
  （另有本地备份 `.config.bak-vk13-nosuspend` / `.config.old`，但 `device.config` 最权威。）

10. **ABL 会拿 stock dtbo overlay 我们的内嵌 DTB** → 卡 logo。解决：向两个槽写**假 dtbo**（4KB 全零）。
    假 dtbo 生效的迹象：ABL 日志 `Dtbo hdr magic mismatch`。

11. **`reserved-memory` 节点名 `splash-region`（连字符）→ ABL 找不到 `splash_region` 就关显示**；必须下划线。

12. **`&mdss_dp0` 必须 disabled**：DP 是无 ADSP 就永远 defer 的 DRM component，
    会卡住 `msm_drm_bind` → 没有 card0 → 黑屏。

13. **`CONFIG_PHY_NXP_PTN3222=y`（eUSB2 repeater 要内置，不能是 `=m`）**，否则 M31 PHY 起不来、无 USB。

14. **`CONFIG_BACKLIGHT_AW99706=y`**，否则 panel `Failed to get backlight`。

15. **不要打作者的 Mesa chip-id 补丁**（`...44050000`→`...44050001`）：本机内核报 `0xE844050000`（patchid **00**），
    正好匹配 Mesa **原版** wildcard；打补丁反而 unsupported。

16. **显示间歇性坏**：偶见 `drm_crtc_wait_one_vblank` call trace 刷屏（DPU 等不到 vblank → 只有背光无文字）。
    疑似 DSI/panel vblank 中断丢失，冷启/重来可恢复；暂未定位。

---

## 三、存储 / 分区 / 持久化

17. **LUN4 尾部 `last_parti` 的 Type-UUID 是全零** → 内核 GPT 解析器**跳过**它，不生成 `/dev/sde79`。
    解决：`fdisk /dev/sde` → `t 79` → 类型 `Linux filesystem` → `w`。只改类型 GUID，不动数据。
    （gdisk/fdisk/内核对它的口径不一致，以内核为准。）

18. **LUN0 无空闲**（userdata 到盘尾）；要加分区必须缩 super/userdata（有数据风险）。
    **`super`(sda10) 可直接读**：解析前 8MiB 的 LP 元数据 → 各分区 extent `{offset,len}`（单位 **512B** 扇区）→
    `losetup -o <off> --sizelimit <len> /dev/loop0 /dev/sda10`。映射见 `probe/result/lp-map.txt`。

19. **tar 拷贝会保留主机 uid（1000）** → sshd 报 `/var/empty must be owned by root` 拒绝启动，
    症状是 **ping 通、SSH `connection refused`**。
    修复：拷贝用 `tar --owner=0 --group=0`（或 cpio `--owner=0:0`），或事后 `find / -xdev -uid 1000 -exec chown 0:0 {} +`；
    init 已内置 `chown 0:0 /var/empty` 防御。

20. **持久 root**：initramfs 的 `init` 检测 cmdline `elden_root=LABEL=linux` → 挂载 → `switch_root` 到磁盘 `/init`。
    用 `stat -f -c %T /` 区分 initramfs(rootfs/tmpfs) 与磁盘(ext4)，磁盘模式跳过 `/persist` 与 switch_root（防递归）。
    打包：`EXTRA_CMDLINE="elden_root=LABEL=linux" ./pack.sh <rootfs> <img>`。

---

## 四、固件 / 外设（反提取 vendor 资源）

21. **ADSP 固件命名必须是 `qcom/sm8750/adsp.mdt`（+ `adsp.bXX` + `adsp_dtb.*`）**，
    不是 `adsp.mbn`。命名错的症状：`remoteproc: Direct firmware load for adsp.mdt failed -2` → 音频 deferred。
    （修复后 `adsp is now up`，音频宏 probe。）

22. **功放 aw88461 的 ACF**：vendor 的 `firmware/aw882xx_acf.bin` **内容就是 aw88461 的 ACF**（含 "aw88461" 字样）。
    拷成 DT 要的 `awinic/y700-gen4-speakers.bin` 即可（否则 `amplifier profile load failed`）。

23. **音频出声还需设备 tplg** `qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin`（mainline AudioReach 拓扑）。
    linux-firmware 的 `SM8750-MTP-tplg.bin` 能用但后端只有 WCD Codec-DMA、**没有 MI2S**，`speaker-test` 打不开（-EINVAL）。
    需自编（vendor `/etc/MM_audio_playback_capture_v2.0.cfg` 可参考）。

24. **WiFi = ath12k / PEACH（PCI 0x110e，不是 WCN7850/0x1107！）**，固件目录 `ath12k/PEACH/hw2.0/`。
    从 vendor `modem/image/peach/` 反提取的对应关系：
    | ath12k | vendor 文件 |
    |---|---|
    | `m3.bin` | **`phy_ucode20.elf`**（e_machine=0x03，与 linux m3 同类；换它后 MHI 进 mission、固件启动）|
    | `amss.bin` | `amss20.bin` |
    | `aux_ucode.bin` | `aux_ucode20.elf` |
    | `tmel.bin` | `image/tmel_peach_20.elf` |
    | `regdb.bin` | `peach/regdb.bin` |
    | `qdss_trace_config.bin` | `peach/qdss_trace_config_v2.cfg` ← ★**必放，否则不建网卡（见 §42）** |
    | `board.bin`（API1 raw BDF）| `bdwlan.elf` / `bdwlan.eXX` |
    注意：PEACH 是 `board_api1_only`，驱动**不用 board-2.bin**，直接加载 **`board.bin`**。
    **进度（★已更新 2026-09-29）**：固件链全通、`wlan0` 已建立可扫描；详见 §42-44。
    （旧结论“QDSS 一加就崩内核”已废弃——那是早期未配套固件时的现象。）

25. **触屏固件**：`novatek_ts_csot_3k_fw.bin`（vendor `firmware/`）。
26. **蓝牙**：`qca/brhbtfw20.tlv` + `brhbtnv20.bin` + `brhperifw20.tlv` + `qca/tmel_peach_20.elf`；
    顺序加载，成功标志 `QCA setup on UART is completed`。
27. **GPU zap 必须设备签名版**（vendor `gen80000_zap.mbn`），linux-firmware 版被 TZ 拒（-EINVAL）。

---

## 五、设备上装包 / 环境

28. **早前"瘦身"Mesa/LLVM 时手删了文件但 apk 数据库还在** → `apk add` 不恢复（认为已装）。
    修复：**`apk fix <pkg>`**（重装缺失文件），别用 `--reinstall`（Alpine apk 无此选项）。
    受影响的：`mesa-egl mesa-gles mesa-gbm mesa-dri-gallium llvm22-libs`。

29. **设备无外网**。让设备直连 apk：主机 `socat TCP-LISTEN:7898,fork,reuseaddr TCP:127.0.0.1:7897`（0.0.0.0:7898→本地 CN 代理），
    设备把 `/etc/apk/repositories` 改成 **http** 源（避开缺 CA 的 TLS 问题），再
    `export http_proxy=http://192.168.7.2:7898 https_proxy=...; apk update && apk add <pkg>`。

30. **`socat` 后台化时别 `pkill -f 'TCP-LISTEN:7898'`** —— 会匹配到自己的命令行把当前 shell 杀掉（现象：命令 exit 143 无输出）。

---

## 六、脚本 / 工具

31. **busybox tar 不支持 `--ignore-failed-read`**：probe.sh 里用它导致拷贝为空。用整目录 `tar czf`。
32. **主机编内核依赖**：`gcc-aarch64-linux-gnu flex bison libssl-dev libelf-dev libncurses-dev bc`。
33. **主机代理**：`http://127.0.0.1:7897`（env 已设）；GitHub 大文件易截断，走代理。
34. **`apk info -W <file>`** 可查文件属于哪个包；`apk fix` 重装。
94. **kexec 只能喂未压缩 `Image`**：arm64 `kexec_file_load` 拒绝 `Image.gz`（报 invalid image）。
    用 `linux/arch/arm64/boot/Image`（未压缩）；设备已有 `kexec-tools 2.0.32`。`CONFIG_KEXEC`（旧 syscall）未开，
    所以必须 file-based（`kexec -s`）。先 `scripts/kexec-boot.sh --load-only` 验加载（失败不切内核）。
    ⚠️ file-load **没有 DTB 形参**：`--dtb` 不进入新内核 DT（内核用运行内核 live DT 重建）⇒ DTB 迭代只能走 `--boot`/`--flash`。
95. **模块热载的 vermagic 必须匹配**：设备 `uname -r` ≠ 内核树 `make -s kernelrelease` 时，push 的 `.ko` insmod 会失败。
    `scripts/mod-loop.sh` 检测到不一致会**拒绝执行**——先 kexec/fastboot 到同源内核再做模块环。
96. **ccache 必须显式接入 `CROSS_COMPILE`**：装了 ccache 但 `CROSS_COMPILE=aarch64-linux-gnu-` 时缓存恒为 0。
    统一用 `scripts/env-build.sh`（`CROSS_COMPILE="ccache aarch64-linux-gnu-"`，缓存 `~/.cache/ccache-elden`）。
97. **模块化时 bool 子项会把父项拉回 `=y`**：如 `SND_SOC_WCD939X_SDW=y` select `SND_SOC_WCD939X` → 父项无法变 `=m`。
    翻 `=m` 必须连**所有 `=y` 的子项**一起翻（`fragment-modular*.config` 已用 merge_config+olddefconfig 实测）。
    例外：`BT_HCIUART_QCA` 是 **bool** 且 `select BT_QCA` → `BT_QCA` 无法模块化（hci_qca.c 仍内置）。
98. **不要在同一命令里混合长轮询与副作用**（见 #26）：`iterate.sh`/`to-fastboot.sh` 已把 `reboot`/`bboot`
    与等待拆成独立步骤；`kexec -e` 后 SSH 必断，等待期由脚本内部自限。
99. **★持久根没有与运行内核匹配的 `/lib/modules` → 相机/音频"消失"**（2026-10-05 实测修复，见 `archive/topics/KMOD-ALIGN-2026-10-05.md`）。
    - 现象：boot_b 跑 `7.2.0-debug-g4c68eb5ed4e3-dirty`，但 `/lib/modules/` 只有旧内核 `...gba28ec16f01f-dirty`；
      `modprobe qcom-camss` → "not found in directory"；`lsmod` 仅表头，`/dev/media0`、声卡控件全无 ⇒ 误判为功能回归。
    - 前提：`CONFIG_MODVERSIONS`/`MODULE_SIG` **未开** ⇒ 只要 **vermagic 精确匹配**即可加载，无需符号 CRC/签名。
    - 修法：从**运行内核**的 `/proc/config.gz` 取 config + worktree 检出对应 commit + **强制 LOCALVERSION** 重建模块集。
    - **构建陷阱**：`scripts/setlocalversion` 在**环境变量 `LOCALVERSION` 未设置**时会补一个 `+`（vermagic 变 `...-dirty+` ≠ 运行内核 `...-dirty`）
      ⇒ 构建时必须 `export LOCALVERSION=`（空但已设）+ 删 `include/config/kernel.release`/`include/generated/utsrelease.h` 重生成。
    - 新 worktree 无 `vmlinux` ⇒ 无 `Module.symvers` ⇒ modpost 报海量未解析符号；借主树 `Module.symvers` + `KBUILD_MODPOST_WARN=1` 通过（MODVERSIONS 关闭）。
    - **加载时机陷阱**：模块在开机很久后热载，`deferred_probe` 已超时 ⇒ `qcom-camss: Failed to configure power domains: -110`；
      `rmmod`+`modprobe`（或**开机时加载**）即好。
100. **★PipeWire/WirePlumber 占用 `/dev/media0` → 相机 `Resource busy`**（2026-10-05 实测）。
    - 持久桌面（Phosh/PipeWire）里 `wireplumber` 打开 `/dev/media0`、`/dev/video0` ⇒ `media-ctl --set-v4l2`/`-l` 报
      `Unable to parse link: Resource busy (16)`；**纯 RAM（无桌面）不存在此问题**。
    - 取证：`for p in /proc/[0-9]*; do for f in $p/fd/*; do readlink "$f"; done; done | grep -E 'media0|video0'`。
    - 临时解：停 wireplumber（先存 `/proc/<pid>/environ` 以便原环境重启）；根治：让 WirePlumber 忽略 V4L2/相机，或在取流前协调释放。
101. **★持久根 boot 不会自动加载相机模块——`/init` 需接线**（2026-10-05）。
    - 设备旧 `/init` 缺相机加载块（`rootfs/init` 已有），且 `modules` init.d 服务**不在任何 runlevel**（runlevels 全空，非标准 OpenRC 引导）⇒ `/etc/modules-load.d/camera.conf` 从未生效。
    - 修法：部署 `rootfs/init`（其相机块**未加 `on_initramfs` 守卫** ⇒ `switch_root` 后在持久根也会跑一次）+ `/usr/local/sbin/camera-modules-load.sh`。
102. **★`kernel_git_state=dirty` 的 boot 镜像无法从提交复现——卫生纪律（因果关系未证实）**（2026-10-05）。
    - 背景：追查「熄屏（DPMS off）→ 硬复位」时，boot_b 跑 `7.2.0-debug-g4c68eb5ed4e3-dirty`（脏树构建）；vk42 镜像与“干净重建”各 2 轮“免疫”，一度归因于脏构建。
    - **但刷入干净内核到 boot_b 后仍观察到复位** ⇒ **少样本观测不可信（间歇性）**，「dirty 构建是根因」的假设**未被证实**。见 `TASKS.md` Q24、`archive/topics/REBOOT-5MIN-2026-10-05.md` §7.9。
    - **2026-10-06 补充（用户）**：**运行中的 `vk47clean`（clean）本身也会「熄屏→关机」**，当前之所以不复现，只是因为用户在设置里**手动关闭了 5 分钟闲置自动熄屏**（`idle-delay=0`）。⇒ **该 bug 与内核 `-dirty` 无关**，「dirty 是根因」彻底排除；「干净重建免疫」也只是未触发熄屏。
    - 纪律（仍成立）：① 只烧 `kernel_git_state=clean` 的镜像；② manifest 必记 `kernel_git_state`（vk50 起已记）；③ **单次/2 轮观测不足以判定“免疫”**，须长时窗+多样本（参 G1-23/Q22）。
103. **★`gsettings set` 必须有活的 session bus，否则**静默不落盘**（2026-10-05，`dt-ui` 踩坑；#48 的补充）。
    - 现象：SSH 里裸 `gsettings set ...` 返回 rc=0，但**读回不变**（写到过期/不存在的总线）⇒ 据此得出的"改了也没变化"结论全部作废（手套误判）。
    - 可靠写法：`HOME=/root dbus-run-session -- gsettings set <schema> <key> <val>`；读回同样 `HOME=/root`。
    - 纪律：**不要用裸 `gsettings set` 判定 dconf 是否生效**；phosh 会话内的持久值应写 `/root/.config/dconf/user`（非 PID1 时代的 `/`）。见 `archive/topics/DT-UI-2026-10-05.md`。
104. **★DP/altmode 的第一道闸＝FSA4480 typec-mux 驱动**（2026-10-05 实测，G1-9）。
    - 现象：`pmic_glink.altmode.0` 永久 defer：`failed to acquire mode-switch for port: 0`（该文案由 `dev_err_probe` 记为 deferred 原因，**不是**即时打印的错误）。
    - 关键机制：`fwnode_typec_mux_get()` 会遍历连接器图里**所有**匹配（`TYPEC_MUX_MAX_DEVS`），**任何一个** mux 未注册就整体返回 `-EPROBE_DEFER` ⇒ QMP combo PHY 自己的 mux 即使已注册也不够，`&i2c5/typec-mux@42,43`（FSA4480）缺驱动就全卡。
    - `CONFIG_TYPEC_MUX_FSA4480=m` 但该 `.ko` **不在设备的 `/lib/modules/` 里**（持久根只部署了相机闭包 25 个）。验证：用**与运行内核同 vermagic**的 `fsa4480.ko` `insmod` → `5-0042/43` 绑定、`pmic_glink.altmode.0` 立即可绑定。
    - 纪律：设备上缺的 `.ko` 不要从头编整树——先 `zcat /proc/config.gz > .config` + 对应 `LOCALVERSION` 复现 vermagic（本树预编 `.ko` 是 vk50，与在跑的 vk47clean 不匹配）。
105. **★DP/altmode 的第二道闸＝DWC3 role switch + 第三道＝`mdss_dp0`**（2026-10-05，G1-9）。
    - `&usb { /delete-property/ usb-role-switch; }` 让 `dwc3_drd_init()` 跳过 `dwc3_setup_role_switch()` ⇒ 不注册 per-endpoint role switch；而端点上的 `usb-role-switch; mux-state=<n>` 正需要它（本树是定制双口 mux 补丁）。
    - 后果：UCSI 的 `usb_role_switch_at_endpoint()` 命中端点属性但查不到 role-switch 对象 → `ERR_PTR(-EPROBE_DEFER)` → `ucsi_init` 反复 defer → `PPM init failed, stop trying` → **无 `/sys/class/typec`**（DP HPD/连接态因此永远不触发）。
    - 第三道：`&mdss_dp0 { status="disabled" }` ⇒ `aux_bridge.aux_bridge.0: failed to acquire drm_bridge`；且 `mdss_dp0` 是 DRM 组件，贸然开而 altmode 未就绪会拖垮 `msm_drm_bind`（黑屏）。**修复顺序：先 mux → 再 role switch/UCSI → 最后 dp0**。
    - 相关：`archive/topics/DRIVER-MAINLINE-AUDIT-2026-10-02.md` §3/§4.4（旧口径写“DP 属 ADSP bring-up”，本轮定位到 DTS + 模块部署，非 ADSP 缺失）。
106. **★罕见「图形启动即挂」：进 GUI（Phosh/锁屏）时整机卡死——无 panic、SSH/网络不通（2026-10-05，两次，未定性）**。
    - 观测（用户）：**持久图形变体**启动时，一次卡在锁屏、一次卡在「CLI→图形亮屏」瞬间；整机无响应。
    - 已知边界：**纯 RAM 变体不启桌面**——RAM initramfs 的 `init` 在 `on_initramfs=1` 时只 `respawn ttyGS0/tty1`，**无 `start-desktop.sh`**；故无图形需求时用 `ROOTARGS=` 纯 RAM 即可绕开。
    - 未定性：历史偶发、次数少；疑属会话/合成器用户态（与 U1–U7、Q24 同类），**按「用户态冻结」策略暂不深挖**。
    - 相关硬事实：本机 **APSS 看门狗被永久禁用**（dmesg `Hard watchdog permanently disabled`）⇒ 这类死挂**不会自复位**，必须物理复位；取证优先用无 GUI 环境 + OOB 串口。
107. **★G1-30 slim 最小 initramfs 缺 `/bin/sh` —— 所有 slim 镜像从来起不来（2026-10-05 定位）**。
    - `build-boot.sh` 的 busybox 最小 initramfs 只放 `bin/busybox`，而 `initramfs/init` 是 `#!/bin/sh` ⇒ 内核 `Run /init … Failed to execute /init (error -2)`
      → `No working init found` → 15s panic 复位（也表现为“掉电重启”）。`vk52/54/56/57-slim` 全中；与内核无关。
    - 修：`build-boot.sh` 为 applet 建符号链接 + 新增 `initramfs/busybox-applets.txt`（272 项）。
      坑：设备 busybox 链接表里没有 `mount`/`mountpoint`（属 util-linux）、`ip`（属 iproute2），必须手工补。
    - 教训：slim 路径此前**从未真机验证**；任何 boot 打包改动都要有一次 `fastboot boot` 冒烟。
108. **★vk53/vk54「DTS 破坏启动」根因 = 使能了 `&i2c0`（本机无 NFC 硬件）——已定案（2026-10-06 单变量二分）**。
    - **二分链**（均 vk61 full 载具 + vk53 kernel，零写盘）：
      1. `vkX-dtb53`（vk53 DTB）挂 / `vkY-kern53`（vk53 kernel + vk47 DTB）起 ⇒ 元凶在 DTB，kernel/config 洗清。
      2. `vkD1-nfconly` 挂 / `vkD2-cdsponly` 起 ⇒ 元凶 = **NFC 组**（CDSP 清白）。
      3. `vkD1a-nfcpin`（仅 pinctrl 节点，无 i2c0）起 / `vkD1b-nfcdev`（仅 `&i2c0`+`nfc@8`）挂 ⇒ 不在 pinctrl。
      4. **`vkB1-bin`（仅 `&i2c0 { status="okay"; }`，无任何子设备）挂** ⇒ 元凶 = **使能 i2c0 本身**，与 NFC 驱动/GPIO 无关。
    - 现象：`fastboot boot` 报 OKAY 后**硬关机**（非 panic、非熄屏）；USB 串口来不及注册，抓不到日志。
    - **本机（TB322FC）无 NFC 硬件**（否掉 G1-10 的前提）：vendor 无 `android.hardware.nfc.xml`（feature 未声明）、vintf manifest（sun/tuna/kera/elden）无 NFC HAL、`/lib64(/hw)` 无 NFC HAL 库、`/firmware` 无 NFC 固件；原厂 Android 运行服务无 NFC；GSMArena 规格 `NFC: No`。`ro.nfc.port=I2C` 是通用 Qualcomm 属性；`elden.dts` 的 `st21nfc` 是**总线 `disabled` 的共用模板**，`stm_nfc_i2c.ko`/`st54spi_gpio` 为多 SKU 共用。
    - **教训**：① 使能本板不存在的 QUP/总线可致**硬关机**（比 panic 更难捕捉）；② 判断设备存在与否要看原厂 DTB 的 **`status`**，不看节点是否存在；③ 归因必须做单变量（本轮 3 层二分才落到 i2c0）。
    - 前两次口径（10-06 早「DTS 破坏启动」、后按用户口述改「坏 init+用户态」）**均已收窄/作废**：坏 init（#107/#110）确实干扰了 10-06 首轮矩阵，但**不是**本故障根因。
    - 仍成立的教训：`build-boot.sh`/`build-manifest.sh` 的 `KDIR` 原为硬编码 `linux/`，用外部 Image/DTB 打镜像会**静默用错内核**（首版 vk59 中招）；已改为 `KDIR=${KDIR:-…}` 并透传 manifest。
    - 证据：`archive/topics/DRIVER-VERIFY-2026-10-06.md` §7/§8、`ATTRIBUTION-AUDIT-2026-10-06.md` §4/§5；相关 `#104/#105/#106/#107/#110/#115`。
    - **★复发（2026-10-06/07 DP 工作中）**：`TASKS`/文档虽写「已从驱动批次移除」，但主树 DTS 的
      `&i2c0 { status="okay"; nfc@8{} }` **一直在**（未提交移除）⇒ 由本树构建的任何 DTB 启动必失败。
      dp1 镜像因此启动失败回退 boot_b，误导为「role-switch 破坏启动」。改 `disabled` 后 dp1b 正常。
      **纪律：改结论前先 `grep` 当前树核实，不信文档的「已移除」**。证据 `archive/topics/DP-2026-10-06.md` §1。
109. **★init 曾有「三份分叉 + awk 原地打补丁」——已固化（2026-10-06）**。
    - 旧状态：`initramfs/init`（boot 镜像用）、`rootfs/init`（磁盘根构建用）= 设备 `/init` 三者内容不同（相机预载/音频/`ttyGS1` 各不相同）；磁盘 `/init` 还是 `scripts/patch-init-*.sh` 在设备上 awk 原地拼出来的，不可复现。
    - 后果：改 boot 镜像的 init ≠ 改磁盘的 init；任何 init 加固只做一半就会分叉复发。
    - 固化（本轮）：唯一真源 = `initramfs/init`（两种 root 用 `on_initramfs` 分支共存）；`rootfs/init` 删除、`build-rootfs.sh` 改从 `initramfs/init` 安装 `/init`；6 个 `patch-init-*.sh` 退休；新增 `scripts/check-init.sh`（单一真源 / `dash -n`+`busybox ash -n` / applet 覆盖 / 挂钩存在性）。
    - 加固：`log()/warn()/fatal()` 同时写 console 与 `/dev/kmsg`（USB ACM 控制台要到 `usb-gadget` 才出现，早期 userspace 输出否则全丢）；`mnt()` 幂等+重试+失败告警；preflight 缺工具时 `rescue` 丢 shell 而非盲目继续（#107 的 userspace 版）；`switch_root` 失败显式告警并留在 RAM 根；`/var/log/elden-boot.log` 留可跨复位取证的开机快照。
    - 证据：`archive/topics/INIT-HARDEN-2026-10-06.md`；自检 `scripts/check-init.sh`。
110. **★开机刷屏 `/init: line 35: sleep: not found` + `/dev/null|/dev/kmsg: nonexistent directory` 的真因＝`switch_root` 与后台 `/persist` 任务竞态（2026-10-06 实机定位）**。
    - 现象：每次开机进桌面之前屏幕（VT）刷几十行 `/init: line 35: sleep: not found`，末尾 `line 36: can't create /dev/null`、`line 39: can't create /dev/kmsg`。看着像 init 坏了，实为无害噪音。
    - 根因：boot_b 的 RAM init（10-02 旧版）把「等 `/dev/sde79` 挂 `/persist`」的等待做成**后台子 shell**（`( … ) &`）；主流程随即 `exec switch_root`，initramfs 被释放——孤儿子 shell 还在旧根里找 `sleep`（已随 initramfs 删除）→ `not found`；重定向 `/dev/null`、`/dev/kmsg` 也已随 `mount --move /dev` 消失。
    - 为什么以前没发现：取证靠 USB ACM 串口，而 `ttyGS0` 要到 `usb-gadget` 起来（≈8.8s）才注册，刚好错过；**正确取证取 `/dev/vcsN` 屏幕缓冲**（`cat /dev/vcs1`），它保存了进桌面前的最后屏幕。
    - 修：`/persist` 改 **同步 + 有界等待**，且只在「纯 RAM 启动（`elden_root` 为空）」时执行（磁盘根启动本来就会 switch_root 掉它，挂了也白挂）。任何 `switch_root` 之前的 `&` 后台任务都要怀疑同类竞态。
    - 验证资产：`out/boot-elden-vk60.img`（内核+DTB 与 boot_b 逐字节相同，仅换最小 initramfs＋修好的 init）；备份 `out/boot_b-live.img`。
    - 证据：`archive/topics/INIT-HARDEN-2026-10-06.md` §7。
111. **★boot.img 的 kernel 载荷可能已经是 gzip，别再压一次（2026-10-06 vk60 首版卡 logo）**。
    - vk60 首版：我用 `unpack_bootimg.py` 从 boot_b 抽出 `kernel`，见 `file` 报 gzip 就以为是「压缩过的 Image」，`gzip -9` 再压一轮放进 boot.img ⇒ **双层压缩**；ABL 解一层得到的是 gzip 流而不是内核 ⇒ 卡在联想 logo、屏幕无输出。
    - 正确做法：抽出什么就放什么（`Image.gz` 位就放那个 gzip 文件）；**先 `gzip -dc` 解一层看是否为 `ARM64 boot executable Image`**，是则原文件就是已压缩内核。
    - 校验：新镜像 `unpack_bootimg.py` 后 `gzip -dc` 出来的 Image 应与 boot_b 的 `gzip -dc kernel` **逐字节相同**（vk60 终版已如此）。
112. **★`initramfs/busybox-applets.txt` 必须由二进制生成，不得手写；且 `busybox` 自身不能建自指链接（2026-10-06）**。
    - 旧名单 272 项与真实 busybox **不一致**：含两个不存在的小程序 `blkid`、`mountpoint`，又漏掉 40+ 真项（含 `findfs`）；而 G1-30 slim 的 LABEL 解析正靠 `findfs`，写错的名单会让 slim 永远 switch_root 失败。
    - 权威生成：`qemu-aarch64 initramfs/busybox --list | LC_ALL=C sort -u > initramfs/busybox-applets.txt`（282 项，已入 `scripts/check-init.sh` 一致性门）。
    - 坑：`--list` 含 `busybox` 自身；`ln -sf busybox bin/busybox` 会把真二进制替换成自指链接 ⇒ ramdisk 从 1.1 MB 缩成 **12 K** 且内核“找不到 init”。修：`build-boot.sh` 跳过 `busybox` + 建链后断言 `bin/busybox` 是常规文件。
    - 真机 busybox 1.38 无 `blkid`/`mountpoint`；`init` 因此改为 **`findfs` 主解析**、且 `mnt()` 用 `grep -qs " $target " /proc/mounts` 判已挂载（不再依赖 `mountpoint`）。
    - 证据：`archive/topics/INIT-HARDEN-2026-10-06.md` §9。
113. **★最小 initramfs 不带 `/lib/firmware` ⇒ 内置驱动早期探测全失败且不重试（2026-10-06 vk60 实机）**。
    - vk60（最小 busybox initramfs）能进 Phosh，但**触屏无响应、电池显 0、WiFi 不工作、无声音**。dmesg 铁证：1–3 s 内 `Direct firmware load for qcom/sm8750/adsp.mdt / awinic/*.bin / novatek_ts_*_fw.bin / ath12k/PEACH/hw2.0/amss.bin / qcom/gen80000_sqe.fw` 全部 `failed with error -2`。
    - 根因：这些驱动在 vk47clean 内核里是 **built-in（=y）**，在自己的 initcall 就探测；此时根还是最小 initramfs，`/lib/firmware` 不存在（本机共 **40 MB**：qcom 30 M + ath12k 9.3 M + awinic/novatek）。`-ENOENT` 后**不会重试**（只有 ath12k 有 `ath12k-retry.sh` 补探）。switch_root 后才有的 `/lib/firmware` 没用。
    - 结论：**“20 MB 超瘦 boot.img”与“开机即需要 40 MB 固件”不相容**（除非把 40 M 固件塞进 initramfs，那就不叫瘦了）。
    - 正确做法（vk61）：boot_b 替换版 = **原完整 ramdisk 只换 `/init`**（一个文件的最小 diff），内核/DTB/固件/模块全部保持已验证状态。
    - 取证方法：先在能用的系统上 `grep -iE "firmware|Direct firmware" dmesg` 建基线，与坏启动对比。
114. **★口径更正清单（防误导，2026-10-06 init 固化收尾）——发现旧文档/旧结论以下五处不准确，引用前先改口径**。
    1. **「boot.img 瘦身到 ~21 MB 是 G1-30 的成果、E5 待上机」→ 对日常启动不成立**（#113）。最小 initramfs 无 `/lib/firmware`（本机 40 MB），内置驱动 1–3 s 探测失败且不重试：能进桌面但触屏/电池/WiFi/音频全废。**slim 仅作无外设研究场景**，不作 boot_b。
    2. **「USB 串口（ttyGS0/ttyACM0）能取证早期启动」→ 错**（#110）。该 console 到 `usb-gadget` 起来（≈8.8 s）才注册，**早期输出/panic 前面那段它抓不到**；早期取证唯一可用通道是**读 `/dev/vcsN` 屏幕缓冲**。涉及 kexec/启动挂死「串口无输出」的旧结论要加此保留。
    3. **「最小 busybox 缺 `blkid` 所以加 `findfs` fallback」→ 口径反了**（#112）。真机 busybox 1.38 **有 `findfs`（可作主解析器）**、**没有 `blkid`/`mountpoint`**；旧 `busybox-applets.txt` 手写名单两项都是假的。名单必须用 `qemu-aarch64 busybox --list` 生成（主机有 qemu-aarch64 可直接跑）。
    4. **「`/init: line 35: sleep: not found` 是内核/VFS/init 损坏」→ 错**（#110）。它是**已退役的 `switch_root` × 后台 `/persist` 任务竞态**造成的无害噪音（boot_b 旧 RAM init 才有）；新 init 已改同步。
    5. **「BT 配对待收口 / 无法连接」→ vk61 上观测到恢复，但机制未证**（`TASKS.md` G1-7）。**不得写“已解决”**；需旧/新 RAM init 单变量 A/B 两次冷启复现。
    - 另：项目 `AGENTS.md` 原「进 fastboot 后先 `fastboot --set-active=a`」**已删除**（错误规则，本意是不动在用的 b 槽；已改为「不要改 active slot」）。
    - **推而广之的排查纪律**：① 任何 `switch_root` 之前的 `&` 后台任务都是竞态候选，必须同步化或显式确认已退出；② 换 initramfs/换启动方式后，先查内置驱动探测时刻缺不缺固件/模块与自己依赖的文件；③ 得出结论前先看「这个取证通道在故障发生的那一刻真的存在吗」（如 ttyGS0、/run）——不存在就得换通道（`/dev/vcsN`、落盘 kmsg）。

115. **★归因分层：报「驱动/内核坏」前先分清 initramfs/rootfs 打包 与 用户态配置（2026-10-06 复核）**。
    - 本项目多次把 **C 层（initramfs/rootfs 打包）** 或 **D 层（用户态）** 的问题记成 **A 层（驱动/内核）**，导致修错方向。复核表见 `archive/topics/ATTRIBUTION-AUDIT-2026-10-06.md`。
    - 典型：vk60 slim「驱动全废」= initramfs 缺 `/lib/firmware`（#113）；「没进桌面」= 刷了 `-ram` 变体（#92）；模块加载失败 = 内核↔模块/rootfs 不对齐（#99–#101）；相机 `-32` = media 链路配置（D）；音频 = tplg SD 线（B）。
    - **报「XX 驱动坏」前先问**：故障发生时根/固件/模块可见吗？cmdline 是哪种变体？模块与内核同构建吗？**报「内核 bug」前先排除用户态服务/配置**（Q24 熄屏→关机即未在「内核 DSI blank vs 用户态电源路径」之间裁决，不得记作驱动根因）。
    - 归因层：A 内核/驱动/DTS · B 固件与资源文件 · C initramfs/rootfs 打包 · D 用户态服务/配置 · E 工具/流程。

116. **★boot.img 连打两次 sha 不同＝不可复现打包；GNU cpio `--reproducible` 不归零 mtime（2026-10-06）**。
    - 现象：同一内核/DTB/内容连打两次，`out/boot-elden-*.img` sha 不同；manifest 的 `ramdisk_sha256` 每次都变。据此曾误把 vk59 矩阵里的 ramdisk 当作变量——实际内容逐文件相同（`diff -r --no-dereference` 零差异），只差打包元数据。
    - 根因三处：① GNU cpio 2.15 的 `--reproducible` 只归零 inode/设备号，**不归零 mtime**（旧 `build-boot.sh` 每跑一次 `sed`/`cp` 都刷新 mtime，字节偏差恰好落在 mtime 字段）；② `find` 未排序（readdir 顺序不保证）；③ `gzip` 默认写入时间戳/原名。
    - 修（`scripts/build-boot.sh`、`rootfs/build-rootfs.sh`）：全树 `touch -h -d @$SOURCE_DATE_EPOCH` + `find | LC_ALL=C sort -z` + `cpio --null --reproducible` + `gzip -n`。修后同输入两次 sha 一致；`scripts/check-init.sh` 加「内嵌 /init==真源 + 可复现重建」门（`CHECK_INIT_DEEP=1`）。
    - 纪律：版本台账的「唯一变量」只有在**打包可复现**时才成立；见「同输入不同 sha」先查这三处，别当成内容差异。

117. **★WiFi 双管理器并存（NM + 手动 wpa_supplicant）＋ NM DHCP 反复重激活（2026-10-06 实机）**。
    - 现象：开机后 `wlan0` **每 ~16–18 s 掉线一次**（`ath12k: failed to flush transmit queue, data pkts pending N` + `wlan0: Connection to AP 00:00:00:00:00:00 lost`），`nmcli` 恒 `getting IP configuration`，IPv4 到 ~140 s 才拿到（clean boot 28 s 已关联）。
    - 真因：`net-up.sh`（NM 版）等地址 80 s 超时后 `exec net-up-manual.sh` → 起**第二个** `wpa_supplicant -B -i wlan0`，与 NM 的 `wpa_supplicant -u` 抢同一接口；掉线周期 = NM 的 DHCP 重激活循环（`nmcli connection up … IP configuration could not be reserved`）。
    - 排除：`power_save`（关掉仍 5 次/80 s）、NM `dhcp=dhcpcd` 后端（仍 `could not be reserved`）。环境变量：手机热点 DHCP 后段也无 offer。
    - 纪律：**一张网卡只允许一个 supplicant/管理器**；回退路径必须在启动另一个之前先停掉前一个（`net-up-manual.sh` 应先停 NM）。
    - 另分叉：设备 `/usr/local/sbin/net-up.sh` = 仓库 `scripts/net-up-nm.sh`，而仓库 `scripts/net-up.sh` 是手动版（#109 同类），需对齐 SSOT。
    - 证据：`archive/topics/WIFI-SLOW-2026-10-06.md`；相关 #109/#113。

118. **★WiFi「到可用约 2 分钟」的真根因 = 固件 beacon-miss + 两条独立的拆链路径（2026-10-06，vk61 基线实机）**。
    - 现象：clean boot 28 s 关联成功，之后**每 ~16.4–17.7 s 掉线一次**（`Connection to AP 00:00:00:00:00:00 lost`，bssid 全零是 ath12k/MLO 不填 `vif.cfg.ap_addr` 的显示假象），~129 s 自行稳定；IPv4 因此要 ~2 min。
    - 直接推手：固件 `wmi roam event reason 2`（= `WMI_ROAM_REASON_BEACON_MISS`，`ath12k debug_mask=2` 可见）；ath12k 把它变成 **3 s `connection_loss_work`**（`ATH12K_CONNECTION_LOSS_HZ`），而该 work **只能被「真 beacon 交主机」取消**（`ath12k_mac_handle_beacon_iter`）。
    - 为什么会误报：主机在**关联后前 ~100 s 基本收不到 beacon**（`iw station dump` 的 `beacon rx: 1`，而固件的 `beacon signal avg` 却在更新），之后自行恢复（`beacon rx` → ~6–7/s，<10/s 但固件已容忍）。**换基础设施 AP（ustcnet）首 90 s 0 bmiss / 0 掉线 / beacon rx 9.3/s** ⇒ 触发条件在「手机热点 AP + WCN7850」这一组合。
    - **两条拆链路径可独立关闭**：①驱动 `connection_loss_work`（关掉后 `lost` 归零）；②mac80211 的 AP-probe 超时（不发 deauth、不打印 `lost`，因此**只看 `lost` 计数会误判「已修复」**）。实测只关 ①，关联次数照旧（6 次/200 s）。上游同症状修法是关 ① 且只针对 MLO（2026-08 ath12k 邮件列表，仍在 review）。
    - 已排除（单变量，各 45 s 窗口）：`power_save` 开/关（2 vs 2 次掉线）、持续流量（2–3 次）；**单次手动扫描在稳定链路上不触发 bmiss/掉线**（90 s 无新关联）。
    - 纪律：**「WiFi 慢/掉线」先看 `iw station dump` 的 `beacon rx` 与固件 roam reason，再谈 DHCP/管理器**；`nmcli getting IP configuration` 是受害者不是根因。
    - **★后续定位（同日追加）**：黑屏期的第一现场指标应是 **`beacon rx` 速率**（不是 `lost` 次数，后者会混入两条拆链路径）。5/6 轮复现：开机后前 ~130 s `beacon rx` ≈ **0.5/s**（固件对已关联 STA 的上送/睡眠调度受限），~130–150 s 自行校正到 5–10/s。
    - **PS 已用正确指标彻底排除**：关联前就 `802-11-wireless.powersave 2`（PS 关）重启，黑屏与恢复点**完全不变**。
    - **同一次开机**在黑屏窗口内扫描能得到 **33–41 个 BSS**（含该 AP 信道）⇒ **RF/beacon 接收本身正常**，坏的是「已关联 STA」这条路径。因此「开机扫一次」不能当修复（复测黑屏照旧）。
    - **被动扫描定案（2026-10-06 深夜）**：黑屏窗口内 `iw dev wlan0 scan passive`（只听 beacon）仍能听到该 AP（BSS=36）⇒ **AP 在发 beacon、射频无辜**；症结 = 固件对已关联 vdev 的休眠/唤醒调度（~2 s 拍子），~130 s 自校正。**换 stock 非-20 固件变体会让 MHI POWER_ON 直接 -110（不兼容）**；关联后补发 `BEACON_INTERVAL`/`DTIM_PERIOD` 亦无效。
    - 纪律：判「AP 是否在发 beacon」**必须用被动扫描**（`iw dev wlan0 scan passive`）；主动扫描会收到 probe response，会伪造「AP 正常」的结论。
    - 下一步方向（方法见专题 §13）：试 `CONFIG_ATH12K=m` 让 WCN **只探一次**（避开「首探失败 + 二次 bind + `qmi TME-L hardware-restricted`」的半初始化态）。
    - 证据：`archive/topics/WIFI-BMISS-2026-10-06.md`（§11/§12 追加、§13 下一步手册）；相关 #117/#109。

119. **★同 UTS 候选内核的启动验证：`uname -r` 不可用，要用 `uname -v`；`debug_mask=2` 会冲掉 dmesg 计数（2026-10-06）**。
    - 为保持 `/lib/modules` 的 vermagic 兼容，候选内核刻意锁同一 `UTS_RELEASE`（`7.2.0-debug-vk47clean-gbd114ca335e1`）⇒ `uname -r` 在 vk61 与各候选间**逐字相同**，不能用它证明「新内核已启动」。可用判别器 = `uname -v`（`#N SMP PREEMPT <构建时间戳>`，随每次 make 递增）。
    - 代价：**vermagic 兼容性依赖 LOCALVERSION 逐字对齐**；做法 = 用设备 `/proc/config.gz` 作构建配置（保留 `CONFIG_LOCALVERSION="-debug"`）+ `CONFIG_LOCALVERSION_AUTO=n` + `make LOCALVERSION=-vk47clean-gbd114ca335e1`，并保持 DTB/ramdisk 逐字节不变（单一变量）。
    - `ath12k debug_mask=2` 每个信道产 7–8 行 scan 事件，一次扫描上百行 ⇒ **`dmesg | grep -c` 的差分计数会因 ring buffer 回卷而变成负数**（本次实测 `assoc=-2`）。
    - 纪律：低音量指标（`wlan0: associated` / `Connection to AP`）可在开 debug 前先差分；高频指标一律用**时间窗口过滤**（`awk` 比较 `[ 1234.567]` 时间戳）或直接用 `iw station dump` 计数器，不要依赖累计 `grep -c` 的差值。
    - 另：`out/` 存在其他写者（本次 `out/boot-elden.img` 在无我方操作的情况下被改过），打包前先备份该别名、打包后按原样恢复。
    - 证据：`archive/topics/WIFI-BMISS-2026-10-06.md` §2/§7。

120. **★busybox `pgrep -x NAME` / `pkill -x NAME` 恒假阴性——它匹配的是 argv[0] 全串，不是 comm（2026-10-06）**。
    - 实证：`pgrep -x udevd` rc=1，而 `/proc/<pid>/comm` = `udevd`；`pgrep udevd`（无 `-x`）rc=0。因为进程以 `/sbin/udevd` 启动，`-x`（整串精确）对 `udevd` 不成立。GNU procps 的 `-x` 匹配 comm，语义**相反**。
    - 后果：`start-desktop.sh` 的 `pgrep -x udevd/seatd/elogind` 三条守卫**长期是空操作**（永不阻止二次启动）；`net-up-manual.sh` 的 `pkill -x wpa_supplicant` 杀不掉旧实例（正是 Q26「双 supplicant」的温床之一）。
    - 修：① 装 `procps-ng`（`/usr/bin/pgrep` 覆盖 busybox symlink，语义变 GNU）；② 脚本改 shell-agnostic：`ps -eo comm | grep -qx NAME`（busybox/procps 都成立），kill 用 `ps -eo pid,comm | awk '$2=="NAME"{print $1}'`。
    - 纪律：**设备脚本里出现 `pgrep -x`/`pkill -x` 一律当 bug**；`dpms-watch.sh` 早就注释过此坑，但只改了它自己。
    - 证据：`.pi/plans/2026-10-06-用户态查漏补缺.md` §0；2026-10-06 实机（U2）。

121. **★PID1（自研 `/init`）与 ssh 会话的 PATH 完全相同 ⇒ 装 GNU 工具会同时 shadow busybox 的 init 上下文（2026-10-06）**。
    - 实测 `/proc/1/environ` 的 PATH = `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`，与 ssh 一致；`/usr/bin` 在 `/bin` 之前 ⇒ `apk add coreutils grep sed findutils` 后 **`/init`、`start-desktop.sh` 也改用 GNU**。
    - 本例无害且通过（重启 ×2），但这是一条**通用风险**：任何装包改工具语义的动作都必须**重启回归**，不能只验 ssh 会话。
    - 纪律：设备「装包 → 重启 → 复核 PID1 起的服务」三步走；`chronyd` 这类依赖网络的服务的缺席不要与装包混淆（本次是**无默认路由**所致）。
    - 证据：`.pi/plans/2026-10-06-用户态查漏补缺.md` §1 P1。

122. **设备无默认路由时（WiFi 掉线），用主机代理给设备装包（2026-10-06）**。
    - 现象：`wlan0 DOWN/NO-CARRIER` + USB gadget 只有 `192.168.7.0/24` ⇒ **无 default route**；`apk add` 报 `DNS: transient error`（`apk update` 看似成功只因索引缓存）。
    - 无需 sudo/NAT 的绕行：主机代理监听在 `*:7897`（含 192.168.7.2）⇒ 设备侧 `http_proxy=http://192.168.7.2:7897 apk add …` 直接可用。
    - 附带后果：`time-sync.sh` 卡在“等网络”⇒ `chronyd` 不起、**时钟停 1970**、TLS/git 全废。**不要**把这归因到用户态/装包。
    - 纪律：在设备无路由时，先 `ip route show default` 确认，再决定“联网装包”还是“主机离线 fetch（qemu-aarch64 + apk --root，见 HINDSIGHT #771）”。

123. **★Alpine 的 OpenRC 装好了但不启用；把 PID1 交给 `busybox init` 才能修好关机链（2026-10-06）**。
    - 现象：`openrc 0.63.2` + 82 个 `/etc/init.d` + 全部 `*-openrc` 包**全已装**，但 `/etc/runlevels/*` **全空**、`rc-update show` 无输出、PID1 = 自研 `/bin/sh /init`（手工 `setsid` 拉 dbus/udev/seatd/elogind/greetd）。
    - 关键认知：Alpine 的 `openrc` 包**不含 `openrc-shutdown`**，关机链 = `/etc/inittab` 的 `::shutdown:/sbin/openrc shutdown` + **busybox init 收信号**（busybox `poweroff` 非-`f` → SIGUSR2 给 PID1）。**shell PID1 不实现该协议** ⇒ 只能靠 `busybox poweroff -f` 补丁（G1-25）。
    - 低风险交接：`/init` 先建好生命线（usb-gadget/usb0/sshd/ttyGS0），**最后**再 `exec /sbin/init`；并用磁盘标记 `/etc/elden-init-mode=openrc` 控制，出错可 SSH 改回 `legacy` 重启。**不要把 `exec` 放在写 boot log 之前**（否则 `elden-boot.log` 不刷新）。
    - 强制项：`LIBSEAT_BACKEND=seatd` 要同时给 **greetd 本身**（`/etc/conf.d/greetd`）与 session 脚本；否则 greetd 选 logind 后端 → deactivate session → phoc 释放 DRM → 面板黑（Q24 类）。
    - 白名单：**不** enable `networking/dhcpcd/wpa_supplicant`（Q26 双管理器）、`chronyd`（由 `time-sync.sh` 先步进 1970 时钟）、`sshd`（`/init` 保生命线）。
    - 证据：`scripts/openrc-enable.sh`、`TASKS.md` G1-32、`.pi/plans/2026-10-06-用户态查漏补缺.md` P3。

124. **★「熄屏→掉电」到底是用户态关机还是内核硬复位：必须用标记判别（2026-10-06）**。
    - 难处：USB 插着时 **VBUS 自动开机**，真关机/硬复位都表现为“又起来了”；pstore 对 DSI 硬复位也是空的。
    - 判别套件（已入库）：① `/sbin/{poweroff,reboot,halt}` = `elden-powerwrap` 在 exec 前写 `USERLAND-<action> <time> uptime=… boot_id=…` 到 `/root/powerlog.txt` 并 sync；② `/etc/init.d/elden-powerlog`（shutdown runlevel）写 `CLEAN-STOP` + 当时 `rc-status`；③ `blankspy.sh` 每秒把 dpms/亮度/phoc/phosh/session/电池 sync 到 `/root/blankspy.log`。
    - 判据：事件后 **有** `USERLAND-*`/`CLEAN-STOP` = 用户态发起的干净关机；**无** 且心跳截断 = 内核硬复位。
    - 实测（U2，2026-10-06）：① 全桌面 `wlr-randr --output DSI-1 --off` → 无标记、心跳止于 `dpms=On`；② **停 greetd（phoc/phosh/gsd 全无）后 `modetest -M msm -w 36:DPMS:3`** → 同样硬复位。⇒ **纯 DRM DSI blank 即复位 = 内核路径**，与合成器/会话/gsd/UPower/logind 无关。
    - 否掉的反假设：`/etc/elogind/logind.conf` 已 `HandlePowerKey=ignore`；UPower 98%/charging；`sleep-inactive-*-type=nothing`（无挂起）→ 与 2026-10-06 的 init/OpenRC 改动**无关**。
    - 附：旧结论「vk42/干净重建免疫」与本次“必复位”矛盾 ⇒ 必须长时窗+多样本（n≥3）验证，单次观测不作数。
    - 工具：`scripts/blankspy.sh`、`scripts/elden-powerlog.initd`、`scripts/fix-logind-poweroff.sh`。
    - **★更正（2026-10-06 用户实拔 USB 确认）：是「真关机」不是「硬复位」**。`boot_id` 变化不能当 reset 证据——那是 **VBUS 自动开机**造成的假象；标记得只能证明「**未走用户态关机**」。区分法：拔 USB 后触发，**保持关断**=真关机，**自行重启**=硬复位。
    - **进一步定位（U2）**：`kmsg -w` 持续落盘后复现，**内核在掉电前零输出**（最后一行是 wlan0 关联消息，离掉电 ~1s）⇒ 非 panic（pstore 也空）、非 thermal（会打日志）、非驱动打印；呈**瞬时断电**。
    - **E3 二分**：仅关背光（`echo 4 > /sys/class/backlight/aw99706-backlight/bl_power`，不动 DSI）**幸存** ⇒ 背光路无辜，嫌疑在 **DSI/面板 disable 序列**。
    - 面板 DT：`panel@0` = `csot,pp8807hb1-1`/`novatek,nt36536`，供电 `vsp-supply` / `vsn-supply` / `vddio-supply`；sysfs 可看到 `vreg_6v1_vsp` / `vreg_5v8_vsn` / `vreg_1v8_vddio` 均为 `enabled`。**下一步**：在面板 disable / regulator off 路径加 printk（需重建内核）+ 逐个拨供电以定位是哪条轨道拉低声造成整机断电。
    - 证据留档：`archive/evidence/kmsg-live-E1b-2026-10-06.log`（1191 行，掉电前无相关内核信息）。
    - **★方法学更正（2026-10-07，重要）**：本条的 E1/E2 用 `wlr-randr --off` / `modetest -w 36:DPMS:3` 触发 blank —— 实测这两个命令在本机**是空操作**（rc=0 但 `card0-DSI-1/dpms` 仍 `On`；`modetest -c` 的 DPMS value 仍 0）。⇒ **E1/E2 并未真正熄屏，其「blank 即复位」的结论不可信**。正确的真实路径 = `org.gnome.ScreenSaver.SetActive(true)`（gsd-screensaver，实测 dpms 变 Off）。用真实路径在 boot_b 上可稳定复现断电（瞬时、`powerlog` 空、无 kmsg、pstore 空）；但已排除 USB/VBUS/电池/DP 单变量，且**未判定**根因（唯一存活样本是 `fastboot boot sd-base`，未复现到 boot_b）。详见 `archive/topics/SLEEPDEATH-REALBLANK-2026-10-07.md`。工具 `scripts/g1-22-dpms-test.sh` 已改用真实触发。

125. **★`CONFIG_ATH12K=m` 会经 Kconfig `select` 把 `PCI_PWRCTRL_PWRSEQ` 拉成 `=m` ⇒ PCIe 起不来、wifi 全无（2026-10-06）**。
    - 现象：改了 `ATH12K=y→m` 并 `make olddefconfig`，启动进桌面、SSH 通，但 **`/sys/bus/pci/devices/` 空**，无 wlan0；极易误判成「wifi 驱动坏」。
    - 根因：`drivers/net/wireless/ath/ath12k/Kconfig: select PCI_PWRCTRL_PWRSEQ if HAVE_PWRCTRL`。Kconfig 里 `select` 由 `=m` 的选择者触发会把被选符号**压成 `m`（无法手工设 `y`，`olddefconfig` 会改回）**。于是 WCN 的 PCIe 电源序列驱动变模块，而内置 `qcom-pcie` 在 initcall 阶段 probe，模块尚未加载 ⇒ `1c00000.pcie  qcom-pcie: cannot initialize host`（deferred），无 PCI 设备。
    - 验证：把 `pci-pwrctrl-pwrseq.ko`(+`pwrseq-pcie-m2.ko`) `modprobe` 进去，deferred-probe 立即重试成功，`0000:00:00.0`/`0000:01:00.0` 出现、ath12k 正常 probe。
    - 纪律：**任何驱动 `=y→m` 后必须 `grep '^CONFIG_...'` 检查被它 `select` 的符号是否跟着降级**；PCIe/电源/时钟这类「早于模块加载就必须在」的供应商驱动，模块化后必须进 **initramfs**（早加载）或另找内置路径，不能只放磁盘 `/lib/modules`（#113 同类）。
    - 证据：`archive/topics/WIFI-ATHM-PROBE-2026-10-06.md` §2；`scripts/build-athm-probe.sh`。

126. **★槽位元数据改用 `qbootctl`（标准 boot_control HAL），别再手搓 `slot-attr.py`（2026-10-07 设备实测）**。
    - 背景：#88 要求 `slot-attr.py mark-successful b`。实测自研脚本的**常用操作**（读状态、mark successful）可由 Alpine 官方包 **`qbootctl`** 完全取代：扇区大小走 `ioctl(BLKSSZGET)`（4K 无误判）、**按盘提交**（支持 boot_a/b 在 LUN4 `/dev/sde`）、`-m` 同时改 primary+backup GPT + CRC，**不碰 UFS BSG**。
    - 实测（U2，`vk47clean`）：`apk add qbootctl`；只读 `qbootctl` vs `slot-attr.py show` **逐项一致**；`qbootctl -m b` 把 boot_b byte6 `0x0f`(retry=1) → `0x4f`(succ=1)，独立解析确认 primary idx44 与 backup idx44 都置位、boot_a 未动；内核重扫 78 分区无 CRC 错误。
    - **坑 1（危险）**：mainline cmdline 无 `androidboot.slot_suffix` ⇒ `getCurrentSlot()` 失败返 0，`qbootctl -m`/`-u` **不带槽位会作用到 slot a**。必须显式 `-m b`；已给 `scripts/build-boot.sh` 的 CMDLINE 加 `androidboot.slot_suffix=_b`（可 `SLOT_SUFFIX=` 覆盖）。
    - **坑 2（迷惑）**：qbootctl 写 GPT 会触发内核分区重扫，紧跟其后的 `qbootctl -n/-b` 可能瞬时报 `No slots found, is this an A/B device?`（by-partlabel 在重扫窗口暂不可见）；等 1–2 s 重读即正常，**非 GPT 损坏**。
    - 保留 `slot-attr.py`：**离线 dump 编辑**（`--image`）与 **retry 计数单改**（`set --retry`）qbootctl 没有。`-s`（set active，走 `/dev/sgY` 的 UFS boot-LUN BSG 切 xbl）本项目不需要、勿用。
    - 技能：`qbootctl-slot-management`；审计：`.pi/plans/2026-10-07-造轮子审计.md` §7.1。

127. **★CDSP 用 stock split 固件，且必须打进 initramfs（2026-10-07 实机，G1-11）**。
    - 现象：`remoteproc1(cdsp) state=offline`，`cdsp.mbn` 主固件能装载，但 `cdsp_dtb.mbn` 在 `qcom_scm_pas_init_image` 报 `-22 (EINVAL)`；ADSP 同 boot `running`。
    - 根因（两点，缺一不可）：
      1. **固件变体**：DTS 写了非 stock 的单文件 `cdsp.mbn`/`cdsp_dtb.mbn`。stock SunP DTS 用 **split** `cdsp.mdt`/`cdsp_dtb.mdt`；单文件 `cdsp_dtb.mbn` 不是本机签名镜像，TZ 拒。**不是 PAS id**——反汇编 stock `qcom_q6v5_pas.ko` 的 `sun_cdsp_resource` 得 pas_id=18 / dtb_pas_id=0x25，与主线 `sm8650_cdsp_resource` 一字不差。
      2. **载具**：固件由 **initramfs** 加载（switch_root 前 ~1.16 s）；磁盘 rootfs 的 `/lib/firmware` 副本不生效（原始 ramdisk 无 split 时即便磁盘有也 `-2` ENOENT）。
    - 修复：DTS `firmware-name = "qcom/sm8750/cdsp.mdt", "qcom/sm8750/cdsp_dtb.mdt";`（内核提交 `c132a1bc7`）+ `build-initramfs.sh full` 注入 split 文件。
    - 纪律：**改固件名/变体前先解编译 stock DTB（`backup/stock-elden/dtb/`）+ 反汇编 vendor `.ko`**，别猜 PAS id/格式。
    - 证据：`archive/topics/CDSP-FIX-2026-10-07.md`；对照 `archive/topics/CDSP-PROBE-2026-10-06.md`（其「PAS id 待定」被否证）。

128. **★使能 `mdss_dp0` 会阻塞 `msm_drm_bind` → 背光亮但无显示（2026-10-07 实机）**。
    - 现象：`&mdss_dp0 status="okay"` 的 DTB 启动后屏幕**背光亮但无画面**、SSH 极慢；dmesg 狂刷 `msm_dpu ae01000.display-controller: [drm] vblank wait timed out on crtc 0` + `drm_crtc_wait_one_vblank` WARNING（约 1/s）。
    - 根因：`msm_dp` 是 DRM 组件，ADSP UCSI/altmode 未起时**永久 defer** ⇒ `msm_drm_bind` 失败 ⇒ 无 `card0`。（该结论原本就写在 vk47clean DTS 注释里，DP2 实验时被去掉。）
    - 判据：`ls /sys/class/drm/` 有 `card0-DSI-1`；`dmesg | grep -c "vblank wait timed out"` = **0**；`pgrep phosh` 在。
    - 处置：主树 DTS `&mdss_dp0 status="disabled"`（回退，内核提交 `08791078c`）；**DP 实验走独立零写盘載具，不进 boot_b**。`usb-role-switch` 同步回退 `/delete-property/`。

129. **★WiFi 频段兼容性：华为 P40 Pro 热点 5 GHz 平板连不上，2.4 GHz 正常（2026-10-07，待根因）**。
    - 现象：P40 Pro 热点开在 5 GHz（ch149，信号 100）时，U2 的 `wlan0` 保持 **DOWN**，`nmcli con up "P40 Pro"` 报 `Connection activation failed: The base network connection was interrupted`，无默认路由。热点切到 **2.4 GHz 后连接正常**。
    - 对照：**vivo X200 Ultra** 热点 5 GHz / 2.4 GHz **两频段均可**连。⇒ 不是平板 ath12k 单方面禁 5 GHz，指向 AP/频段/信道/加密的特定组合。
    - 现状：**仅记录，未定位**（未抓 supplicant/dmesg 失败帧）。怀疑点：ch149 高信道 + 华为 AP 的 802.11 行为/带宽/WPA2 参数。
    - 排查入口：连 5 GHz 失败时看 `wpa_supplicant`/`ath12k` dmesg（关联失败 reason code）、`iw phy` 支持信道、AP 的 BW/HE/VHT 设置；参 `wifi-link-flap-triage` 技能。
    - 规避：设备联网改用 **2.4 GHz 热点**（或 vivo 热点）。

130. **★dma-buf heap：必须只加载 `system_heap`，绝不能加载 `cma_heap`（2026-10-07 实机，G1-5 相机）**。
    - 现象：libcamera 软件 ISP 两段报错——先 `Could not open any dma-buf provider`（无任何 heap 模块时），部署 `system_heap`+`cma_heap` 后变 `dma-heap allocation failure for frame-0`（ENOMEM）。
    - 根因：libcamera 0.7.1 `DmaHeap` 探测路径序是 **`linux,cma` → `reserved` → `system`**（strace 实证，`/dev/dma_heap/system` 第三个才被试）。`cma_heap.ko` 会为 DT reserved-memory 造出 `/dev/dma_heap/reserved`（本机仅 32 MiB CMA，可用 7168 页），它被优先选中后装不下 ~30 MiB 帧（req 7803 页）⇒ ENOMEM。
    - 修复：**只 modprobe `system_heap`**（`camera-modules-load.sh` 已改 + 从设备删去 `cma_heap.ko`）；libcamera 落到 `system` 即出帧。
    - 判据：`ls /dev/dma_heap/` 只有 `system`（+ 非探测序的 `adsp-rpc-remote-heap`）；`cam --capture=1` 出帧；strace 里 openat 命中 `system`。
    - 纪律：**给 libcamera 铺 dma-buf 时先 strace 看 DmaHeap 探测序**，别假设「system 优先」。

131. **★boot_b 真实内核 ≠ manifest 的 `kernel_sha256`；重打包必须 unpack 原镜像取 kernel（2026-10-07 实机事故）**。
    - 事故：按 build-boot.sh 默认 `KERNEL_IMG=linux/arch/arm64/boot/Image.gz` 重打包（只改 DTB）→ 刷入后设备跑 **g26cd13b1c4a2**（非 vk47clean），`/lib/modules` 无该版本 ⇒ 相机全废。
    - 根因：boot_b 实际打包的 kernel 是 build-boot 的 `--kernel` 覆盖路径（当时 `/tmp/vk47clean-unpack/kernel`，sha `2321e3b9…`），而 `build-manifest.sh` 的 `kernel_sha256`/`kernel=` 记录的是 **linux/ 树的 Image.gz**（sha `f5868d0a…` = g26cd13b1c，另一个内核）。即旧 manifest 的 kernel 列是误导性的——`kernel_uts` 是开箱取证、`kernel_sha256` 是树文件，两者指向不同内核。
    - 修复：从原镜像 `unpack_bootimg.py` 解出 kernel（sha=2321e3b9=vk47clean）+ 新 DTB + 原 ramdisk 重打包（`cdsp-vk47clean-camrot2`），实机 `uname -r`=vk47clean 恢复。
    - 纪律：**任何 boot 镜像重打包，kernel 来源必须 = 原镜像 unpack 出的 kernel（或同 sha 的可复现构建产物）；不得用「同一棵树」的 Image.gz 代替**。改 `build-manifest.sh`：`kernel=`/`kernel_sha256` 应记录实际打包的 kernel 文件。

---

## 七、Wayland / 桌面（weston）

35. **weston 14 的 drm-backend 不再接受 `--tty=1`**（VT 改由 libseat 管理）：
    报 `fatal: unhandled option: --tty=1`，**即使 DRM/输出/EGL 都已经初始化成功**——很迷惑。
    正确命令：`weston --backend=drm --idle-time=0`（配 `seatd -g root`）。
    （别信旧笔记里的 `--tty=1`，那是旧 weston 语法；`§17.1` 已改正。）

36. **`weston-screenshooter` 在无输入/无 shell 授权时返回 `Output capture error: unauthorized`**：
    weston 的 `weston_capture_v1` 需要 shell 授权，headless 下截图不通。
    要确认桌面是否真在显示，用 DRM debugfs（**权威**）：
    `cat /sys/kernel/debug/dri/0/state` → 看 `plane-0` 的 `allocated by = weston`、`crtc=crtc-0`、`format=XR24`、`size=1904x3040`。

37. **weston-terminal 需要真实字体**：只装 `fontconfig` 不够，必须装字体（`apk add font-dejavu`），
    否则 pango 无字形、终端一片空白。

38. **桌面自启**：磁盘 root 模式下（`on_initramfs=0`）`/init` 调用 `/usr/local/sbin/start-desktop.sh`
    取代 tty1 getty；RAM 模式仍保留 getty。
    **当前脚本拉起 Phosh**（`udevd` + `seatd` + `phosh-session` 循环；见 §十）。
    历史：早期是 weston（`/etc/xdg/weston/weston.ini`，`[core] require-input=false` 必须加，
    `--tty=1` 在 weston 14 已失效；旧脚本备份 `start-desktop.sh.weston.bak`）。

---

## 八、恢复 Android / 免解 BL root 资产（2026-09-29）

39. **1.5.10.259 免解 root 原理**：高版本固件改了分区签名；老法（改分区 + 旧签名）会**卡机**。
    社区重签包 = **改过的 `abl`（信任自签密钥）+ 自签 `vbmeta`/`vbmeta_system`**，让系统以为仍是原厂签名。
    → **abl 与 vbmeta 必须配套一起刷**，不能只刷一半。资产见 `restore-259/`。
    build 核对：三个 vbmeta 的 fingerprint 均 = `ZUXOS_1.5.10.259_260611_PRC`；分区描述符不带槽后缀。
    重签包里 `boot_a.img` 与官方 `boot.img` **sha256 相同**（没改 boot），真正改的是 `abl_a.img`。

40. **回 Android 两步走**：① 先 `fastboot --set-active=<另一槽>`（非破坏，见第 1 条）；
    ② 不行才按 `restore-259/README.md` 刷重签包（abl 有砖风险，需 qdl+`xbl_s_devprg_ns.melf` 兜底）。

41. **EDL 救砖链**：`fastboot oem edl` 或 `adb reboot edl` → `~/y700-elden/qdl/build/qdl -s ufs restore-259/xbl_s_devprg_ns.melf read/write <分区> <文件>`。
    原厂固件目录 `~/下载/tb322fc/`（**不含 dtbo/vendor_boot/recovery/super**，不能全量恢复，只能逐分区）。

### 八之二、Android 应用数据备份 / 解密（2026-09-29）

用 **adb 从运行中的 Android** 导出 `Android/data/<pkg>` 即得**明文**（FBE 已透明解密）；
**不要**用 raw 分区 dump（那是 FBE 密文）。

- 本机 Android 16 的 `adb shell` 属于 `ext_data_rw` 组，**无需 root 就能读** `Android/data`：
  `adb exec-out 'tar -C /sdcard/Android/data -cf - <pkg> 2>/tmp/err' > pkg.tar`
  （只有 `-rw-------` 的 `tombstone_*` 崩溃转储读不到）。
- **Hollow Knight**（`com.TeamCherry.HollowKnight`）：存档 = `<25B 头>+base64(AES-256-ECB(json))+0x0b`，
  密钥公开 `UKu52ePUBwetZ9wNX88o54dnfKRu0T1l`。工具 `scripts/hk-save-decrypt.py`，已验证**逐字节可逆**。
- **Limbus Company**（`com.ProjectMoon.LimbusCompany`）：本地 `save_slot_*.json` = BOM+base64(AES 密文)，
  密钥未公开、无社区解密器；但**存档在服务器**，本地只是缓存，备份价值在 17 GB 素材。
- 备份产物在 `~/android-backup/`（含 README / sha256 / decrypted）。

---

## 九、WiFi / ath12k / 装包（2026-09-29）

42. **WiFi(PEACH) 缺的不是 board-2.bin，而是 `qdss_trace_config.bin`**：本机 PEACH 定制 ath12k 在 TME-L 后
    强制下载 QDSS trace 配置，缺文件就 `qmi failed to download QDSS config: -2` 直接不建网卡。
    放 `vendor peach/qdss_trace_config_v2.cfg` → `/lib/firmware/ath12k/PEACH/hw2.0/qdss_trace_config.bin`。

43. **★禁区：在线 ath12k 设备绝不能 `remove`/`unbind`**：实测两次都把内核挂死→重启→fastboot。
    只能对「首探失败、已未绑定」的设备 `bind`。

44. **开机首探 MHI `-110` 是竞态**：ath12k 在 ~1.9s probe，WCN 未就绪→MHI 超时→设备留未绑定。
    用只 bind 不 unbind 的延迟重试脚本（`scripts/ath12k-retry.sh`，已挂 `/init`）解决。
    另有稳定性隐患：bind 成功后运行一段时间内核崩（待查）。

45. **主线能充电，不必改电源驱动**：`qcom-battmgr-bat STATUS=Charging`，“插着净掉电”只是 PC USB 口供电不足。

46. **USB 离线装包（推荐，避开设备侧代理超时）**：主机 qemu-aarch64 跑 rootfs 的 apk `fetch --recursive` →
    scp → 设备 `apk add --allow-untrusted --no-network`。
    ⚠️ 设备 `/etc/apk/world` 残留未装的包（如 epiphany）会让 `apk add` 去补整条依赖树→上百包，先摘掉。

47. **持久 root 只有 2.3 GiB**：Phosh(~900MB) 能装；Plasma Mobile(~1.6GB) 装不下。装大桌面前先看 `df /`。

---

## 十、桌面 / Phosh（2026-09-29）

48. **Phosh 锁屏默认要 PIN**：`sm.puri.phosh.lockscreen require-unlock` 默认 `true`；
    本镜像 `/etc/pam.d/` 几乎为空（只有 `polkit-1`），**任何 PIN/密码都不可能通过** → 卡死在锁屏。
    解法：schema override 把 `require-unlock=false`（滑一下直接解锁）。
    产物：`/usr/share/glib-2.0/schemas/99_elden.gschema.override`（改后 `glib-compile-schemas`）。
    ⚠️ 直接 `gsettings set` 会失败：`Cannot autolaunch D-Bus without X11 $DISPLAY`——
    ssh 里没有 session bus；要设就 `export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/<phosh-pid>/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')`，
    **或者**干脆用 override 文件（会话无关、可持久）。

49. **gdk-pixbuf 2.44 全走 glycin，glycin 的 bwrap 沙箱会让 loader `exit 1` → GTK 断言 → phosh abort**。
    glycin 自检（`sandbox.rs check_bwrap_syscalls_blocked`）遇到 bwrap 返回 SIGSYS / stderr 含
    `Creating new namespace failed` 时**自动切 NotSandboxed**；因此给 `bwrap` 装个打印该串并 `exit 1` 的 shim 即可
    （`scripts/glycin-bwrap-shim.sh`；`/init` 开机自动装）。
    ⚠️ **bwrap 完全不存在反而被判为可用**，删 bubblewrap 无效；glycin 无「关沙箱」环境变量。

50. **apk 说已装 ≠ 文件在**：`mesa-gl` 在包库里是 installed，但 `/usr/lib/libGL.so.1` 实际缺失
    → `gnome-session-check-accelerated` 的 gl-helper abort（`Couldn't open libGL.so.1`）
    → 加速检查失败 → **shell 根本不启动**。
    诊断要用 `ls`/`ldd`，别只信 `apk list -I`。修复：从 `pkgs-phosh/mesa-gl-*.apk` `tar -xzf -C /` 补回。

51. **gnome-session 必需组件失败 → fail whale**：`org.gnome.SettingsDaemon.Power` 在无 UPower/logind 时
    `exit 1`、`respawning too quickly` → `Unrecoverable failure in required component`。
    解法：从 `/usr/share/gnome-session/sessions/phosh.session` 的 `RequiredComponents` 里删掉 `org.gnome.SettingsDaemon.Power`
    （原文件备份 `phosh.session.orig`）。

52. **★ `pkill -f <模式>` 会匹配到自己的 ssh 命令行**：远程执行的 `sh -c '... pkill -f gnome-session-failed ...'`
    里本身含该字符串 → pkill 杀死自己的 shell（甚至整个会话，导致 phoc/phosh 一起退出）。
    用 **`pkill -x <精确进程名>`**，或把脚本写成文件再跑，绝不在 `-f` 模式里包含自己命令行的文本。

53. **Phosh 会话起来后要的东西**：`udevd`（libinput 认触屏，否则 phoc 报无设备）、`seatd`（libseat 拿 DRM/输入 seat）、
    `XDG_RUNTIME_DIR` 指向专用目录。启动脚本见 `scripts/start-desktop.sh`。

54. **截图取证**：Phosh 内置截图可直接 D-Bus 调用（无需 grim/phosh-screenshot）：
    `DBUS_SESSION_BUS_ADDRESS=... gdbus call --session --dest org.gnome.Shell.Screenshot --object-path /org/gnome/Shell/Screenshot --method org.gnome.Shell.Screenshot.Screenshot false false /tmp/x.png`。
    比看 DRM plane 更直观。

---

## 十一、存储 / TF 卡 / 扩分区（2026-09-29）

55. **TF 卡（`mmcblk0`, 58.2G "NCard"）写丢失的真相**：不是"完全不能写"，而是**部分写丢失**。
    - 现象：`mkfs.ext4` 后 `mount` 报 `Could not load journal inode`（`Superblock has an invalid journal (inode 8)`）；
      但 **`mkfs.ext4 -O ^has_journal` 能正常挂载**（53.3G）→ **日志区（inode 8 的数据块）的写没落盘**。
    - 严格测试方法（必用！）：写 → `sync` → `echo 3 > /proc/sys/vm/drop_caches` → 回读比对。
      **不 drop_caches 的读回会被 page cache 骗**（假阳性）。裸 dd 也要带 drop_caches。
    - 裸写回读：1/5/10/20/30/40/54 GiB 全部一致；50 GiB 第 1 次不一致、重试 3 次一致 → **偶发**写丢失。
    - 卡协商在 **SD high-speed（4-bit, 37.5MHz）**，未上 UHS（`/sys/kernel/debug/mmc0/ios`）。
    - 结论：`sdhci-msm`/ADMA 的 **flush/cache 一致性** 问题（写缓存不随 `sync` 落盘），
      与 CQE 无关（SD 卡无 CQE）。**要拿它当根分区，先修驱动**，或接受"偶发丢失 + rsync 冗余"。
    - ⚠️ `mount` 失败时若继续往挂载点写文件，会**静默写到根分区**（挂载点目录），别被"文件还在"骗到。

56. **扩分区只有三条路**（sda16 `userdata` = 211.4G 是唯一富余空间的内部区域；`sde` LUN4 总共才 4G）：
    - A. **TF 卡**（54G，零 Android 风险，但需先解决写丢失/或接受无日志 ext4）。
    - B. **缩小 `sda16 userdata` 尾部**（从磁盘尾部分一块给 Linux；要动 GPT + `resize2fs`，有 Android 数据风险）。
    - C. 不扩，裁剪根分区（590 包 / 919M，`/usr/lib` 693M）+ 只装必要应用应急。

---

## 十二、userdata 缩容（TWRP 路线实测结论，2026-09-29）

57. **Gen4 的 userdata 是 metadata 加密 f2fs**（`metadata_encryption=aes-256-xts:wrappedkey_v0`，
    key 在 `/metadata`、硬件包裹）→ **mainline/root 都拿不到裸密钥**，不能软件解密。
    但 **TWRP 能解 metadata 加密**（它有 keymaster + dm-default-key），`/data` 可挂载；
    FBE(fscrypt) 的 `/data/user/0`、`/sdcard` 仍需锁屏凭据，无凭据时显示加密名。

58. **★ TWRP 的 `resize.f2fs` 能缩容，但 ZUXOS 不认**：实测流程可行且数据在块层保留——
    卸载 `/data` → 手动 `mount -t f2fs`（**不带 `checkpoint=disable`**）再 `umount` 让 CP 变 clean →
    `/system_root/system/bin/resize.f2fs -s -t <4096B块数> /dev/block/dm-14`。
    `-t` 单位是 **4096B 块**（不是 512B）；**缩容必须 `-s`**。缩完 Android 能正常挂载、用量不变。
    ⚠️ **但 ZUXOS 会检测到 userdata 容量不对 → 反复重启卡 logo**（用户实测）。
    → 结论：**改 GPT 给 Linux 分区，只能用"GPT 手术 + 擦掉 userdata 让 Android 重建"**
    （与 2026-09-04 那次成功的做法一致），不要指望在线 resize 保数据。

59. **TWRP 启动条件**：`polygraphene TWRP-3.7.1-16-TB322FC-2026-04-04-2` **只有 current-slot=a 才能起**；
    之前多次启动失败其实是设备停在**损坏的 b 槽**（b 槽任何内核都 PMIC/SPMI 早死）。
    另外 **`fastboot boot` 100MiB 的 TWRP 会失败**（超缓冲），要 `fastboot flash recovery_a/b` 再
    `fastboot reboot recovery`（先 `--set-active=a`）。TWRP 的工具在 `/system_root/system/bin/`（需 TWRP 挂 system）。

---

## 十三、AVB / 免签 / KSU（2026-09-29 实测）

60. **`fastboot boot` 失败会让 `current-slot` 翻到 b**（本轮实测两次：`Booting FAILED (Status read failed
    (No such device))` 之后 `getvar current-slot` 就变成 `b`）。而 **b 槽的引导链是另一套固件/另一把密钥
    （`vbmeta_b` 用 `8fcb864f…`，a 槽是 `2597c218…`），b 槽永远起不来**。
    → **每次进 fastboot 后、任何操作前，先 `fastboot --set-active=a`**；
    `fastboot boot` 报 `Status read failed` 时，接 `fastboot reboot bootloader`，等 6~8 秒再单条重试。

61. **本机两个槽的 AVB 密钥不同**：a 槽 `vbmeta`/`boot`/`recovery` 用 `2597c218aae470a130f61162feaae70afd97f011`，
    b 槽 `vbmeta`/`vbmeta_system` 用 `8fcb864f11f53ed11284615fb67685522085d3a2`。
    社区"免签/KSU"包用的都是 `2597c218`（= a 槽本来就信任的 key）。
    而且 **a 槽原本就有一处 chain key 不一致**（`vbmeta_a` 说 recovery 是 `8fcb864f`，实际 `recovery_a` 是
    `2597c218`）却能正常启动 → 说明该机对 **hash descriptor 摘要不匹配**（init_boot/dtbo）和**部分 chain key 不一致**
    是宽容的，只有 `boot` 链的 key 不匹配才会致命（b 槽就这样）。
    用 `tools/avbtool.py`（LineageOS 版 `avbtool.py`）可离线核对：`info_image --image X`。

62. **本机 `init_boot_a` 早已是 KSU 补丁版**（`strings` 里有 `/data/adb/ksud`、`description=Android KernelSU`、
    `kernelsu.ko`、`KSU_FEATURE`），`init_boot_b` 是 **Magisk** 版。旧补丁与任何 vbmeta 都不配套。
    社区包 `restore-259/KSU/init_boot.img` + `KSU/vbmeta.img` 是**自洽的一对**
    （校验：`sha256(salt ‖ init_boot[:2850816])` = vbmeta 里 init_boot 描述符的 Digest）。
    注意 stock `vbmeta_a` 的 init_boot descriptor 是 **2465792** 字节（新补丁是 2850816），尺寸也会变。

63. **本机已 unlocked，AVB 本来就是宽松态**：ABL 传的 cmdline 含
    `androidboot.verifiedbootstate=orange`、`androidboot.veritymode=disabled`、
    `androidboot.vbmeta.device_state=unlocked`。社区"免签"的核心价值是**在锁定 BL 的机器上 root**；
    本机不需要刷改过的 `abl_a`（它同时是唯一砖点），只刷 a 槽的 `init_boot`/`vbmeta*`/`recovery` 即可。
    详见 `restore-259/AVB-KSU-2026-09-29.md`。

---

## 十四、睡眠 / 挂起（2026-09-29）

64. **`deep` 挂起把机器挂死**：`cat /sys/power/mem_sleep` = `s2idle [deep]`，`/sys/power/state` = `freeze mem disk`。
    主线 bring-up 阶段 PMIC / 电源域 / PSCI `SYSTEM_SUSPEND` 未完整支持 → 一旦真的进 `mem`（默认走 **deep**）
    机器挂死、屏幕不亮、只能长按电源重启。
    缓解（不用重编内核）：`echo s2idle > /sys/power/mem_sleep`（把 `mem` 变成 s2idle），
    并**取消桌面空闲灭屏/自动挂起**（`org.gnome.desktop.session idle-delay = 0`）。
    本机**没有 logind/elogind**，所以能触发挂起的只有：显式 `echo mem > /sys/power/state`、
    或 phosh 的电源菜单/电源键（若它直连内核）。

65. **b 槽直启打通后，`reboot -f` 不再回 fastboot**（之前是因为 a 槽 AVB 校验失败才回退 fastboot，
    见 §19）。所以 `cycle.sh --soft` 已经**不是**进 fastboot 的路；要 fastboot 用
    `cycle.sh --fastboot`（写 `misc` 的 BCB `bootonce-bootloader`）或物理键。
    改内核请用 `scripts/flash-b.sh`（自签 + `dd` 写 `boot_b` + 回读校验），全程不需要 fastboot。

66. **别把"熄屏"和"挂起"混为一谈**：实测把 `mem_sleep` 固定成 `s2idle` 后，桌面空闲 5 分钟
    （`idle-delay=300`）**确实会熄屏**（`card0-DSI-1/dpms=Off`、背光降到 511/4095）
    而**设备依然活着**（SSH/串口正常、`dmesg` 里 **0 条** `PM: suspend`）。
    → 熄屏本身不挂；挂死要么来自 `deep` 挂起，要么来自**唤醒**（resume）那条路。
    排查时一定要分开看"熄屏 / 挂起 / 唤醒"三个动作。

67. **本机"开机→SSH 就绪"实测时间线**（b 槽直启，2026-09-29，`dmesg` 单调秒）：
    `[5.17]` initramfs `/init` 起 → `[5.56]` switch_root → `[5.58]` 磁盘 `/init`（Alpine rootfs up）
    → `[5.62]` `[usb-gadget] bound` → `[5.63]` `usb0 up 192.168.7.1` + sshd。
    主机侧实测：**reboot 命令 → SSH 可用 ≈22 s**（其中引导器/ABL ≈13 s、内核 initcalls ≈5.2 s、
    我们 init 里 usb 部分 ≈0.5 s）；**SSH 在设备 uptime ≈6.7 s 就可用**（比桌面还早）。
    所以"开机后连不上 SSH 的那段等待"**不在设备端**；若现象是"桌面已出来但 ssh 不通"，
    往主机侧找（USB-NCM 重新枚举 / NetworkManager 重新应用 `elden-usb` 配置 / 串口 ACM 被占用）。
    小贴士：`pkill -f <模式>` 会杀掉自己这条命令行（§52）——清理串口抓包要用 `pkill -f "serial[-]log"`。

68. **忙盒（BusyBox）的 `pgrep/pkill -x` 在本机不可靠**：`/usr/bin/pgrep -> /bin/busybox`（v1.37.0）。
    实测 `cat /proc/<pid>/comm` = `phoc`，但 **`pgrep -x phoc` 匹配不到**（`pgrep phoc` 能）。
    所以"用 `pkill -x` 代替 `pkill -f` 以免杀掉自己"的招数在这里**会静默失效**。
    正确做法：查进程用 `ps -eo comm | grep -cx NAME`；杀进程用 `killall NAME` 或先 `ps` 取 PID 再 `kill`。
    ⚠️ 另外 `pkill -f "dpms[-]watch"` 仍然会杀掉自己——因为**同一条命令行里还有别的部分含 `dpms-watch.sh`**
    （正则匹配整条 cmdline，括号技巧只防"字面量自匹配"）。清理后台脚本时优先取 PID。

69. **熄屏是 phoc 干的**：`/run/phosh.log` 里能看到
    `phoc-wlroots-Message: ... [backend/drm/drm.c:984] connector DSI-1: Turning off`；
    同时 `/sys/class/drm/card0/card0-DSI-1/dpms` = `Off`、背光 `brightness=511`（max 4095）、
    `bl_power=4`（FB_BLANK_POWERDOWN）。**内核仍然活着**（SSH 正常、`dmesg` 无 `PM: suspend`）。
    从外面**改不回** dpms：`echo On > .../dpms` → `Permission denied`（DRM master 在 phoc 手上，
    即使 phoc 退出后该写入仍被内核拒绝）。
    查状态脚本：`scripts/dpms-watch.sh`（每秒采样 dpms/brightness/bl_power/phoc/phosh + phosh.log 末行）。

70. **phoc 退出后不一定能重启**：seatd 报
    `[seatd/seat.c:201] Could not add client: seat is VT-bound and has an active client`，
    phoc 接着 `No backend was able to open a seat` → 桌面起不来。
    另外 **`/run/seatd.sock` 会残留**，且通过 SSH 后台起的 `seatd` 容易随 ssh 会话结束被 SIGHUP 带走。
    → 这种情况**直接 `reboot -f` 最省事**（b 槽直启，~20 秒回到桌面），不要在现场跟 seatd 缠。

71. **槽位"启动失败重试计数"会被耗尽 → 停在 fastboot**（2026-09-30 已定位并给出根治）。
    **[2026-09-30 更正]** 重试计数**不在 `misc`**，而在 **GPT 里 `boot_a`/`boot_b` 分区项的 attribute
    第 6 字节**（AOSP/Qualcomm `gpt-utils.h`）：bit2=ACTIVE、**bit6=BOOT_SUCCESSFUL**、bit7=UNBOOTABLE、
    bit5..3=tries（默认 7）。ABL 每次启动尝试把**当前槽 `boot_*`** 的 tries **-1（-0x08）**，
    归 0 就置 bit7 → 停 fastboot（历史故障值 `0x87` = bit7 + retry0）。
    实测 b 槽 `0x37→0x2f→0x27→0x1f`（retry 6→5→4→3）；`misc`/`uefi` 跨重启 **0 字节差异**。
    根因：自编 mainline 不调 `markBootSuccessful` → bit6 恒 0 → 每次重启都倒计时。
    **根治**：`python3 scripts/slot-attr.py mark-successful b`（置 active+successful+retry7 → byte6=`0x7f`，
    同时修 primary/backup 的 entries+header CRC）。`fastboot --set-active=b` 只重置 retry **不置成功位**，
    只推迟不根治。详见 `archive/topics/GPT槽位元数据-2026-09-30.md`。
    还不行就 `fastboot boot out/boot-elden-vk13.img`（RAM，必可用）。
    动手前 `dd` 备份 LUN0 前/后各 34 扇区。

72. **熄屏后无法唤醒 = 系统总线没跑 + dbus launch-helper 权限错**（2026-09-30 已修复）。
    链路：无 `/run/dbus/system_bus_socket` → gsd-power 启动即退（code 1）→ 无熄屏/唤醒/电源键管理。
    修了总线后又卡 D-Bus 激活：Alpine 根镜像把 `/usr/libexec/dbus-daemon-launch-helper`
    装成 `root:root 4750`，dbus-daemon 以 messagebus 身份 exec 它 → EACCES
    （strace 实镣），upowerd/polkitd 全都激活不了。
    **修复**：① `mkdir -p /run/dbus && dbus-daemon --system`；
    ② `chown root:messagebus /usr/libexec/dbus-daemon-launch-helper && chmod 4750 …`。
    两条都已写进 `start-desktop.sh`（幂等，rootfs 重建后自动兑底）。
    修后：gsd-power + upowerd + polkitd 全部在跑，电源键双向（熄屏/唤醒）正常。
    诊断工具：`dd bs=24` 逐事件读 `/dev/input/event0`（hexdump 会 EINVAL）、
    `dpms-watch.sh` 每秒采样、strace attach dbus-daemon。

73. **PMIC RTC 只读 → 每次开机时间回到 1970，靠 NTP 步进**（2026-09-30 已落地）。
    `hwclock -r` 能读，但 `hwclock -w` 报 `ioctl(RTC_SET_TIME) ... No such device` —— 该 PMIC
    (`rtc-pm8xxx`) 对我们是只读的，**不要指望 `hwclock -w` 持久时钟**。
    1970 的时钟会让 TLS/HTTPS 全线失败（apk、git、网页），必须先校时。
    **做法**：`scripts/time-sync.sh`（装到 `/usr/local/sbin/`）等默认路由 → `chronyd -q "pool ntp.aliyun.com iburst"`
    步进 → 常驻 `chronyd` 维持；`tz=Asia/Shanghai`（软链 `/etc/localtime`）。
    挂接：`scripts/patch-init-time.sh`（幂等，紧跟 net-up 钩子写入 `/init`）——
    设备上的 `/init` 在持久根 `sda17` 上，可直接改，已同步回仓库 `initramfs/init`、`rootfs/init`。
    2026-09-30 实测：`1970-01-02T17:06 → 2026-09-30T05:36` 一次 step 成功；重启后 `time-sync.log` 显示 ~秒级完成。

74. **NetworkManager 接管 wlan0（状态栏 WiFi / Settings→Network）**（2026-09-30 落地）。
    `apk add networkmanager networkmanager-cli networkmanager-wifi networkmanager-tui`
    （依赖会带 **elogind/libnss/curl**，约 +100MB；elogind 只是 lib 依赖，**不要启动它的守护进程**，
    与现有 seatd 不冲突）。要点：
    - **usb0 必须 unmanaged**（SSH 生命线）：`/etc/NetworkManager/conf.d/99-unmanaged.conf`
      `[keyfile] unmanaged-devices=interface-name:usb0;interface-name:lo`。
    - 停掉手工链路：`pkill wpa_supplicant; pkill udhcpc`，再启 `NetworkManager`。
    - 建一次 profile 即自动重连：`nmcli device wifi connect "<ssid>" password "<psk>"`
      （存 `/etc/NetworkManager/system-connections/*.nmconnection`，autoconnect=yes）。
    - 开机：`net-up.sh` 改成 NM 版（先等 dbus socket → 起 NM → 等 wlan0 有 IP；
      80s 没 IP 就自动回退到 `net-up.sh`（manual wpa_supplicant+udhcpc 路径）。`scripts/net-up-nm.sh` 是规范副本。
    - 实测：重启后 ~16s（SSH 上线后）NM 已连上、能 ping 外网。手工备份在 `/root/net-backup-20260930/`。

75. **开机 D-Bus 竞态：两个脚本各起一个 `dbus-daemon --system` → 路径 socket 消失**
    （2026-09-30 踩到并修复）。net-up.sh 与 start-desktop.sh 都用
    `ps -eo comm | grep -qx dbus-daemon || dbus-daemon --system` 判断，并发执行时**都通过**了判断，
    起了两个；持有 `/run/dbus/system_bus_socket` 的那个后来退出并删掉 socket，剩下一个只有抽象 socket
    → 系统总线等于不存在 → **NM/UPower/polkit 全部起不来**（`nmcli` 报
    `Could not connect: No such file or directory`）。
    **修复**：① `/init` 里**早期、单点**启动系统 dbus（`mkdir -p /run/dbus` + helper 权限 +
    `setsid dbus-daemon --system` + `while [ ! -S ...socket ]` 等待），见 `scripts/patch-init-dbus.sh`；
    ② net-up.sh / start-desktop.sh 改为**检查 socket**（`[ -S /run/dbus/system_bus_socket ]`）而不是进程名，
    缺了才 `setsid` 补起。
    **教训**：判“服务是否已起”要看**它该产出的资源**（socket/文件），不要看进程名——进程名判断在并发下有 TOCTOU 漏洞。

76. **`/init` 没设 `HOME` → 会话 `HOME=/`，dconf 写错位置（“设置不持久”假象）**（2026-09-30 发现并修复）。
    内核给 PID1 的 `HOME=/`；`/init` 只 export 了 `PATH` → phosh/phoc/gsd-*/dconf-service 全继承 `HOME=/`，
    dconf 用户库写到 **`/.config/dconf/user`**，而 `gsettings get` / 人工检查看的 `/root/.config/dconf/user`
    是个陈旧文件 → 出现“改了深色模式不生效/不持久”的假象。
    **教训**：用户会话的 `HOME` 必须显式固定为真实家目录；验证配置持久化时先确认**服务实际用的 db 路径**
    （看进程 `/proc/<pid>/environ` 的 HOME/XDG），别默认 `$HOME` 就一定对。
    **修法**：`start-desktop.sh` 里 `export HOME=/root`；把 `/.config/dconf/user` 迁到 `/root/.config/dconf/user`。

77. **phoc 小数 scale 会被量化 → g-c-c「比例」恒显 100%；phoc.ini 不支持的值会被整个忽略**（2026-09-30）。
    phoc 只对**整数** scale 精确上报：请求 2.0→2.000000、4.0→4.000000（精确）；
    请求 2.667→2.66796875、3.2→3.19921875（像素网格量化），与 `Mutter.DisplayConfig` 对外宣称的
    `supported_scales`（float32 值：2.0/2.2857…/2.6667…/3.2/4.0）**不相等**；
    g-c-c 用这个 logical scale 去 supported 列表精确匹配，匹配不上就回退显示 **100%**。
    另外：`phoc.ini` 里写不在支持列表的值（如 `scale = 2.5`）会被**整个忽略**、回退默认 3.199。
    **做法**：用整数 scale（2 或 4）；`scripts/scale.sh 2`（含 `WAYLAND_DISPLAY=wayland-0`）+ 写 `/etc/phosh/phoc.ini`。

78. **★蓝牙：QCA WCN7861 驱动强制开启控制器 IBS 深度睡眠 → BR/EDR 高延迟+断连**（2026-09-30）。
    现象：配对正常，但 ACL 链路 RTT 30–190 ms、持续速率仅 ~1–2 包/秒，突发 20~50 包即
    `Disconnect Complete 0x13 (Remote User Terminated)`。多个对端（PC/手机）都复现。
    根因：`btqca.c` 对 WCN7861 的 NVM `EDL_TAG_ID_DEEP_SLEEP`(tag 27) 执行 `data[1] |= 0x01`
    （`hci_qca.c` peripheral 分支对 `brhperinv20.bin` 同理），**开启控制器侧 IBS 自动睡眠**；
    IBS 计数器显示控制器每包睡/醒 ~6 次（`/sys/kernel/debug/bluetooth/hci0/ibs/`），主机唤醒重传率 88%。
    排除项：2.4G WiFi 共存、链路 SNIFF（`hcitool lp <bd> RSWITCH`）、主机侧 IBS（`tx_idle_delay`）。
    **禁区**：不要靠改固件文件关 IBS —— 把 NVM tag 27 改 unknown tag 会让 `Peripheral setup failed: 5`
    （EIO）并卡死控制器（需 `reboot -f`）。**只能在驱动里改**。详见 `archive/topics/BT-2026-09-30.md`。

79. **★充电："插着净掉电"= USB `input_current_limit` 默认 100mA（不是驱动缺失）**（2026-09-30）。
    主线 `qcom_battmgr` 经 PMIC-GLINK 让 ADSP 管充电；ADSP 默认把 USB 输入电流限在 100mA。
    实测：limit=100000 → 电池 `current_now=-497mA`（净放电）；limit=current_max=900000 → `+398mA`（充电）。
    符号：`current_now` **正=充入电池**。旁路/充电上限用
    `qcom-battmgr-bat/charge_control_end_threshold`（内核夹 **55..100%**），设到 ≤当前电量即停充走适配器。
    工具 `scripts/charge-ctl.sh` + `charge-watch.sh`（/init 钩子自动拉满功率）。详见 `archive/topics/CHARGE-2026-09-30.md`。
    注：UCSI/Type-C PD 在主线 **probe 失败**（无 `/sys/class/typec`、`PPM init failed`），
    PD 快充/altmode 能否工作需插真 PD 充电器实测 ADSP 的 `current_max`。

80. **★流程坑：把"第几台机器"当成任务角色**（2026-10-02 复盘，已在文档层修正）。
    同型号（TB322FC/elden/SM8750P）多台设备**物理等价**，唯一差异 = **容量**（内存/UFS→GPT 数值）。
    按"新机/旧机"分派任务会导致：① 资产命名带相对称谓（`backup/new-tablet/`）→ 换机即失效；
    ② 把可移植资产（`env-pass` 过环境包、rootfs 归档、Mesa 包）误绑在某台；
    ③ 为"角色冲突"设计复杂方案（原"两轨分机"），而真实约束只是**单元当前状态**。
    **正解**：身份用 `(SN, hwboardid, 容量)`（`DEVICE.md`）；**按状态分派任务**；目录 `backup/<SN>-<容量档>/`；
    脚本运行时读实际 GPT/DT。跨容量档复用 GPT 二进制 = 必砖（见 `tb322fc-bootloop-gpt-mismatch`）。

81. **状态才是前置条件，不是机器**（2026-10-02）。例：AVF/`vm`/crosvm 实验的硬前置是
    "该单元处于 **stock Android + root + 大 `/data`**"，与它是第几台无关；一旦把它刷成 mainline，
    该实验就该换回处于 Android 状态的单元。**GPT 手术前先 `fastboot fetch` 备份 b 槽原厂三件套**，
    手术后 a 槽若要能用必须 `fastboot erase userdata && fastboot erase metadata` 重建（否则 f2fs 自认大容量 → bootloop）。

82. **解锁链与 AVB 链是两套密钥，别混为一谈；「必须先解锁才能推 G1」是错的**（2026-10-03 实物取证，U2=`HA2EXB0E` locked）。
    - **AVB 镜像链 = 谷歌公开的 AOSP testkey**：原厂 259 的 `vbmeta_a`/`boot_a`/`recovery_a` 全是
      pubkey sha1 `2597c218…`（`tools/avbtool.py info_image` 实测）⇒ 自签镜像本就被 ABL 认可（7/8 月记录一致）。
    - **解锁标志链 = Lenovo 自签证书**（serial `804940DE79164B1A`，subject `C=CN/ST=BEIJING/L=Lenovo/O=Android/OU=PAD`），
      **不是**谷歌 key；但三代工具箱实物证明解锁 blob 里 **SN 明文在偏移 `0x2048`、落在签名覆盖范围（前 `0x1000`）之外**
      ⇒ 一份通用模板改 8 字节 SN 即可解锁 = **免签**（不是「自己签」）。四代是否仍如此 = 一发可验证（`RUNBOOK` §0.5 路 A）。
    - **G1 不依赖解锁**：`qdl` 走 EDL 写分区不看 lock 位；「免解重签包」只给 root 不给 fastboot 写权限，
      但那是第三方改过的 `abl`（与原厂差 229109 B），与「只用自己引导链」冲突，只作应急。
    - 真要解锁仍首选官网 https://www.zui.com/iunlock 申请 `sn.img`（ZUX OS 必填 `ro.boot.bootload_sn`；1 号/年 3 台；
      Gmail 收不到附件）；`fastboot flash unlock` 的目标在 by-name 里**不存在**（ABL 特判）属正常。
    - 解锁的不可逆代价：擦 `/data` + 掉保修/FOTA + **Widevine L1→L3**；解锁前必跑
      `scripts/bl-preunlock-evidence.sh <SN>` 拍 locked 基线（否则 Q1/Q5 的“标准答案”永久不可得）。
    - 详见 `archive/topics/UNLOCK-BLOB-FORENSICS-2026-10-03.md`。
83. **解锁 blob 可自制，补丁字段是 `Bootloader_SN` 而非只有 SN**（2026-10-03，源自本项目 EDL 技能早先记录，我当时漏读）。
    - 官方 sn.img 有两条等价来源：官网申请 **或** 改模板 hex 的 `Bootloader_SN Part1+Part2`（生成器 jsfiddle.net/2uvz1fwn），
      值必须等于本机 `ro.boot.bootload_sn`（64 hex = 两段 32 hex）。三代工具箱改的是偏移 `0x2048` 的 `ro.serialno`（另一处校验点）。
    - 失败特征串 **`Download is not allowed on locked devices`** = 当前 ABL 不认此 blob → 先降级再试，不要重复刷。
    - 位置：`.pi/skills/qualcomm-edl-flashing/references/tb322fc-y700-gen4.md` §Unlock mechanics；取证 `archive/topics/UNLOCK-BLOB-FORENSICS-2026-10-03.md` §2.4。

84. **`fastboot flash unlock` 的 `OKAY` 不代表解锁文件生效；四代 blob 是另一种格式**（2026-10-03，U2 fastboot 实测）。
    - `Warning: skip copying unlock image avb footer (unlock partition size: 0 …)` + `Sending 'unlock' (0 KB) OKAY` + `Writing OKAY`
      = ABL 特判的**伪分区**，只把字节收进缓冲，**刷垃圾也是这串输出**；判定只在下一步 `fastboot oem unlock-go`
      （失败 → 报错且**不擦机不改锁**；成功 → 屏出 UNLOCK 菜单，须按键确认才擦 `/data`）⇒ 双重闸门，可放心试一发。
    - **四代 ZUX OS 的 blob = 356 B 新格式**（magic `1a2blenovo3c4d5e` + 36 B 头 + **64 B `Bootloader_SN` 明文** @`0x24`
      + **256 B RSA-2048 签名** @`0x64`），与三代 5386 B 的 PKCS#7 模板（SN 明文 @`0x2048`、签名只覆盖前 `0x1000`）**不是一种东西**
      ⇒ 拿三代模板改 `0x2048` 去解四代，大概率直接被拒；反之第三方签名服务的 356 B blob **不含证书**（公钥烧在 ABL 内）。
    - `lenovobl.neko.ink`（NekoYuzu）产出的是**真签名** blob，表单必须选 **ZUX OS** 并填 64 位 `ro.boot.bootload_sn`
      （选 ZUI 会按 ≤16 位 SN 生成 ⇒ 对四代无效）；用三代证书离线验签**验不过**（modulus `b7448bed…` 恢复块无 PKCS#1 结构），
      故「文件结构正确」≠「密钥被本机 ABL 信任」，只能一发判。取证 §5：`archive/topics/UNLOCK-BLOB-FORENSICS-2026-10-03.md`。
85. **locked b 槽链：现有 `bootslot-b/` 自造密钥链不适用，必须 testkey 重打全链**（2026-10-03）。
    - `bootslot-b/`（fc1e3b33 + flags3 + rollback 0）在 **U1 unlocked（orange 宽容）** 上能用；
      **locked/green** 态 ABL 要求 root-of-trust 验证：fc1e3b33 不在原厂受信集合 → vbmeta 过不了 → b 槽起不来。
    - **原厂结构（从 U1 stock dump 读出）**：vbmeta = testkey 2597c218、flags=1（原厂自己 disable hashtree）、
      rollback=0/location 0；chain boot:3（testkey）| recovery:1（**8fcb864f**）| vbmeta_system:2（8fcb864f）+ 14 条 props；
      boot footer = testkey + rollback 1738713600 + 3 条 boot props；**dtbo 无 descriptor**（只有 fingerprint prop）
      ⇒ fake 4KB 全零 dtbo locked 下也能被容忍。
    - **修法（管线已建）**：`scripts/build-locked-chain.sh`——从本单元 stock dump 自动读 rollback/props/flags，
      生成 testkey 全链（vbmeta_b 顶层 2597c218 + chain boot:3 + recovery:1/vbmeta_system:2 原样公钥 + 14 props）；
      `tools/avbtool.py verify_image --follow_chain_partitions` 验证全绿。
    - **avbtool 坑**：① `--chain_partition` 要 **.avbpubkey**（不是 PEM）——PEM 先 `extract_public_key`；
      ② AVB header 全字段 **big-endian**（'<Q' 解析全错）；③ 公钥 blob 在 256(header)+auth_block+pub_off
      （**要加 auth_block**，漏加 sha1 全错）；④ verify_image 默认要 chain 内容，加 `--follow_chain_partitions`。
      提取工具：`scripts/extract-avbpubkey.py`（自动搜 AVB0 magic，支持裸 vbmeta 与 hash-footer 两种布局）。
    - **fastboot boot（RAM 兜底）在 locked 下不可用** → locked 单元零写盘验收没了；b 槽写入 = 真写盘，
      失败靠 EDL 恢复（qdl + Phase 0 备份），a 槽 stock 原样不受影响。
86. **★联想四代「1.5 高版本堵解锁、降级 1.1 才放行」已实物验证**（2026-10-03，U2=HA2EXB0E 实测）。
    - 事实链：U2 出厂 259（1.5 系/Android16）状态下，第三方签名 `flash unlock` OKAY 但 `oem unlock-go` 失败（四代 ABL 换 key，社区 blob 无效）；**线刷降级到 `TB322FU_ZUXOS_1.1.11.073`
      （出厂 1.1/Android15）后，直接 `fastboot oem unlock` 一次 OKAY 成功**（无需 sn.img），`getvar unlocked: yes`、
      `oem device-info: Device unlocked: true / critical unlocked: true`（orange）。
    - 本地 7/8 月记录早已预警（`tb322fc-zuxos-ota-root.md` §解锁 3、`rom-ecosystem.md`）："若新版系统屏蔽了解锁 BL 指令，
      可回退旧版 ZUX OS 恢复解锁功能"；"甜点位 = 1.1 终版 + BL unlocked + Magisk"。
    - 代价：解锁 + 降级都擦 `/data`；Widevine **L1→L3**（L1 基线已提前拍）。
    - **AVB 参数跨版本不变**（1.1 与 259 一致）：vbmeta 顶层/boot chain key = **AOSP testkey 2597c218**
      （私钥在手）、boot rollback = **1738713600**、vbmeta rollback=0；差异只在：259 vbmeta flags=1/0，1.1 flags=0；
      chain vbmeta_system 的 key：259=8fcb864f，1.1=**cdbb7717**。
    - 降级包（完整恢复源，含全 6 LUN gpt/全部固件/super sparse）：`~/文档/TB322FU_ZUXOS_1.1.11.073/image/`。
87. **★流程坑：引导链问题先「本地检索」再「外部取证」再「自研」——解锁这事 7、8 月就答完了，10-03 重推了一遍**（2026-10-03 复盘）。
    - **机制**：`.pi/skills/*/references/*.md` 的正文**不会**在会话启动时加载（只有 SKILL.md 的描述行进上下文）
      ⇒ **不主动 grep 就等于这些结论不存在**。本次版本门（≤`1.1.11.073/.076` 才解锁得到）、
      `.120` 是 trap、失败特征串 `Download is not allowed on locked devices`、**以及本项目自己 2026-08-16 在同型号 U1 上已解成功一次**
      ——全都在 `tb322fc-y700-gen4.md` 里躺着，是在 259 上撞死一次之后才被检索到的。
    - **可避免成本**：第三方签名 blob 那一整轮（获取→刷→取证→判死）。**白花的是顺序，不是力气**
      （同轮建出的 `build-locked-chain.sh` / `bootslot-b-u2/` 是真资产）。
    - **纪律**：① 引导链（解锁/AVB/降级/GPT/EDL）类问题一律先跑
      `grep -rn -iE "unlock|解锁|sn\.img|1\.1\.11\.|rollback|testkey|073|\.120" .pi/skills/*/references/*.md *.md archive/topics/*.md`；
      ② 命中本地结论 ⇒ 本轮只允许「确认或推翻」，不允许从零重推；
      ③ 引用任何「以前成功过」的记录，**先查它属于哪台单元、当时什么固件/锁状态**（状态不同 ≠ 机型不同，见 #80/#81）；
      ④ 动手前先写下「期望判据 + 停手特征串 + 失败后走哪条」，别在失败之后才查。
    - 全文复盘：`archive/topics/复盘-2026-10-03-BL解锁.md`（含 7/8 月记录 ↔ 10-03 实测的逐条对照表）。

88. **★能力缺口：本机没有「Linux→fastboot」的可靠工具（2026-10-03 实测）**。
    - 现状：`cycle.sh --soft`（纯 `reboot -f`）在 b 槽主线可直启后**不再落 fastboot**（PITFALLS #65）；
      `cycle.sh --fastboot`（写 `misc` 的 BCB `bootonce-bootloader`）**未被 ABL 采纳**——
      2026-10-03 实测：misc 首 20 字节确为 `bootonce-bootloader`，`reboot -f` 后仍正常启 Linux；
      过去「reboot 必落 fastboot」是 a 槽 AVB 校验失败的副产物（HANDOFF §19），不是 BCB 生效。
      ⇒ 想进 fastboot，目前只有**物理键**（或从 fastboot 内的 `fastboot reboot bootloader`）。
    - **A/B 内核测试不需要这个能力**：用 `scripts/flash-b.sh <img> --reboot`（自签 + `dd` 写 `boot_b` + 回读校验 + 重启），
      全程不开 fastboot；每版 uname 唯一即可版本归属；复位后回退到**同一个**已烧内核（uname 不变，靠 uptime 判复位）。
    - **必须先做**：`python3 scripts/slot-attr.py mark-successful b`（给 b 槽 `boot_b` 置 `BOOT_SUCCESSFUL`），
      否则主线无 `markBootSuccessful`，retry 每次 -0x08，约 7 次后 `boot_b` 变 unbootable → 停在 fastboot（见 `GPT槽位元数据-2026-09-30.md`）。
    - 若要**造**这个能力（一般没必要）：候选 = ① ABL 认可的其它 BCB 命令；② IMEM `restart_reason`=fastboot 魔术（Android `reboot bootloader` 之道）；
      ③ 故意耗尽 `boot_b` retry 让 ABL 回退 fastboot（用 `slot-attr.py` 可控，但有风险）。**均需另立专项 + 保守实验**，不要在测试脚本里即兴。
    - 纪律：任何"从 Linux 切 fastboot"的记录，**先确认是物理键还是软件**，别把用户的手动操作误记成工具生效（本次即因此误判一次）。

89. **★关机/重启假成功：busybox `poweroff`/`reboot`/`halt` 不带 `-f` 只给 PID 1 发信号，而本机 PID 1 是 shell**（2026-10-03 实测，G1-25 真根因）。
    - 链路：elogind 执行**编译期绝对路径** helper `/sbin/{poweroff,reboot,halt}`（`meson poweroff-path`，**与 PATH 无关**）；
      Alpine 把它们做成 busybox applet 符号链接。busybox **不带 `-f` 时根本不调 `reboot(2)`**：
      `poweroff`→`kill(1,SIGUSR2)`、`reboot`→`kill(1,SIGTERM)`、`halt`→`kill(1,SIGUSR1)`，然后 **exit 0**。
      本机 PID 1 = `/init`（`sh` 脚本，非 busybox-init），不实现该协议 → 信号被忽略、**机器永不断电**。
      证据（`strace -e trace=reboot,kill`）：`kill(1, SIGUSR2) = 0; +++ exited with 0 +++`；dmesg 有
      `elogind: System is powering down.` 但**从无 `reboot: Power down`**（从未进内核关机路径）。
    - **连带假死**：elogind 对 poweroff/reboot/halt 这类**非 sleep** 动作，只在**子进程**里清 `action_job/delayed_action`，
      父进程的 SIGCHLD 清理分支要求 `sleep_operation != INVALID`（poweroff 恰为 INVALID）→ 父进程**永不复位**，
      之后所有 `PowerOff`/`PrepareForSleep` 都返回 `org.freedesktop.login1.OperationInProgress`（`PreparingForShutdown=true`），
      phosh 关机菜单表现为"无反应 / Operation was cancelled"。`kill -9` elogind 可暂时清，但下次假成功又卡。
    - **修复**：`scripts/fix-logind-poweroff.sh`（由 `start-desktop.sh` 在启动 elogind 前调用，幂等）
      把 `/sbin/{poweroff,reboot,halt}` 从 busybox 符号链接换成 `exec /bin/busybox <applet> -f "$@"` 包装脚本。
      用 `strace -e inject=reboot:error=EINVAL` 验证：现在直调 `reboot(...CMD_POWER_OFF/RESTART/HALT)`。
    - **坑**：`cat > /sbin/poweroff`（符号链接）会**穿透去截断 `/bin/busybox`**（报 `Text file busy` 才没坏）——必须先 `rm -f` 符号链接再写。
    - **另**：`HandlePowerKey=ignore`（`/etc/elogind/logind.conf`）保留——否则开机那一下电源键（`pmic_pwrkey` 会上报 KEY_POWER）
      就会触发真关机；桌面态交 phosh（持 `handle-power-key` block inhibitor，长按→电源菜单）。
    - **✅ 已验证（2026-10-03 深夜，U2）**：长按电源键 → phosh 菜单「立即关机」**真断电**（USB 拔掉后）；重启后包装持久（`start-desktop.sh` 幂等重装）。
      ⚠️ **USB 连着时 `loginctl poweroff` 会立即重启**（疑以 VBUS/充电检测触发自动开机）——关机前先断 USB。

90. **★音频无声：tplg 的 MI2S SD 数据线选错（SD0 vs 硬件 SD1）**（2026-10-04 实测修复）。
    - 现象：ALSA 直放（`speaker-test`）→ 整条 APM/DAPM 图全 On（`device18.i2s_rx1`、`Secondary MI2S Playback`、aw88461 全 On）、`SEC_MI2S_IBIT`=1.536MHz 在走、功放未静音/音量最大且 PLL+ready 就绪，**但一点声也没有**。
    - 根因：功放 I2S DIN 接在 **`gpio124 = i2s1_data1`（=SD1）**（主 DTS 与原厂 DT dump `probe/result/devicetree.dts:4636` 一致），
      但 tplg 是从 **Google SC7180 SEC-I2S 模板抄的 `SD_LINE_IDX_I2S_SD0`**（`audioreach.m4` 定义 SD0=1 / SD1=2）
      → ADSP 往 SD0/gpio122 发数据，功放挂在 SD1 永远收不到。
    - 定位关键指标：功放 **SYSST 的 bit8 = SWITCHING**。没数据时 SYSST=`0x0215`（SWITCHING=0），
      修好后变 **`0x2315`（SWITCHING=1）**。即：DAPM On + 时钟在跑 ≠ 有数据，要看 SWITCHING。
    - 修复：`scripts/audio-tplg/SM8750-Lenovo-Y700-Gen4.m4` 的 `DEVICE_SG_ADD` 改用 `SD_LINE_IDX_I2S_SD1`；
      产物 `scripts/audio-tplg/out/Lenovo-Y700-Gen4-tplg.bin` sha `db7e16e7…`（同尺寸 10436B）。
    - 部署：tplg 在 **boot 早期从 initramfs 加载**，故必须**冷启**；ramdisk（`out/rootfs-overlaid.cpio.gz`，可**字节级替换**同尺寸 tplg）
      + 持久 root `/lib/firmware/qcom/sm8750/` 两处都要换，重建 boot（vk43）。运行期 unbind/bind 重载会 ADSP 图残留，不可用。
    - 操作前提：冷启后 `amixer -c0 cset numid=8 on` + 音量 `numid=1/2=1023`（默认 0=静音）。
    - 详见 `archive/topics/AUDIO-SDLINE-2026-10-04.md`、`TASKS.md` G1-4。
    - **UI/应用音频（2026-10-04）**：装 `pipewire`/`pipewire-pulse`/`pipewire-alsa`/`wireplumber`（会替换 pulseaudio）。
      但本卡机器驱动无可用 port，ACP 只给 `Dummy Output`/`Pro Audio`；必须给 `Lenovo-Y700-Gen4` 写 **UCM2**
      （`scripts/audio-ucm/`：HiFi verb + Speaker device，自动 `cset` 开 numid8 路由 + 抬功放音量）。
      装了 UCM 后 `Active Profile=HiFi`、sink=`...HiFi__Speaker__sink`（GNOME 显示 "Built-in Audio Speaker playback"）。
      PipeWire 由 `/etc/xdg/autostart/pipewire.desktop` 自启；`install.sh` 由 `start-desktop.sh` 幂等调用。
      另：本卡**无 capture DAI**（`arecord -l` 空）→ 输入设备为空，麦克风是另立的 bring-up。

91. **★音频输入：本机麦克风不是 DMIC，是模拟麦接 WCD939x**（2026-10-04 实测，已打通）。
    - 我们按上游 SM8750-MTP 做了 **VA macro DMIC** 采集（DTS `va-dai-link` + `dmic01/23` pinmux + tplg 采集子图 + `vdd-micb`）：
      ALSA `MultiMedia3 Capture` 出现、APM/DAPM 图全 On、VA macro 寄存器 `084=0x1`（DMIC0 使能/DIV2）、LPASS pinmux gpio6-9 已 mux、`vdd-micb` 也 On，**但录音 4 通道全 0**。
    - 真根因（原厂设备树 `backup/stock-elden/elden.dts` line 16249）：原厂 `qcom,audio-routing` **全是模拟麦 `AMIC1..5`/`VA AMIC1..5` + `MIC BIAS1..4`，无一条 `VA DMIC`**。
      本机音频栈 = **Awinic smart PA（I2S）+ WCD939x 编解码器（SoundWire）**；麦是**模拟麦**，偏置由 **WCD939x MIC BIAS** 提供，ADC 在 WCD，经 SWR 给 ADSP。
    - **主线 DTS 未启用 WCD939x**（无 SWR master、无 wcd 节点）→ 输入必须另做 WCD939x bring-up（镜像 `sm8750-mtp.dts` 的 wcd939x + rx/va SWR master + 稳压 + capture dai-link + tplg + UCM）。详见 `archive/topics/AUDIO-INPUT-2026-10-04.md`。
    - **操作细节**：`arecord -D hw:0,2` 需先 `numid=15 MultiMedia3 Mixer VA_CODEC_DMA_TX_0=on`，否则 open EINVAL；UCM 加 `SectionDevice."Mic"` 会**弄坏 HiFi verb**（扬声器 sink 丢失），撤回后重启恢复——加 UCM 设备前先验证 verb 可解析。
    - **已于 2026-10-04 打通 ✅**：做 WCD939x bring-up（DTS codec+swr1/2+TX3 dai-link）后，**关键是设对采集路径的 DAPM mixer/mux 控件**（`ADC2_MIXER Switch`、`TX SMIC MUX0`、`TX DEC0 MUX`、`TX_AIF1_CAP Mixer DEC0`）——ADSP 图其实一直成功，只是 DAPM 未点亮。已固化到 UCM2 `SectionDevice."Mic"`。见 `archive/topics/WCD939X-2026-10-04.md`。
    - **UCM 加 capture 段的坑（ACP 探测）**：ACP/WirePlumber 会**探测 UCM profile**（实际打开 PCM）；DPCM 采集 PCM 在 **FE-BE 未连时打不开** → profile 被标 not supported（卡只剩 `off`/`pro-audio`，扬声器 sink 也没了）。解法：把采集 FE-BE 路由 cset（如 `MultiMedia3 Mixer TX_CODEC_DMA_TX_3 on`）+ 关键 mux 放进 **`SectionVerb.EnableSequence`**。

92. **★`build-boot.sh` 会把每次产物覆盖成 `out/boot-elden.img`——持久与 RAM 变体混用会刷错/启错镜像**（2026-10-04 实测）。
    - 现象：先 `VERSION=vk46` 建持久（cmdline 含 `elden_root=LABEL=linux17`），再 `VERSION=vk46-ram ROOTARGS=` 建 RAM（无 `elden_root`）→ `out/boot-elden.img` 变成 **RAM 变体**。据此 boot 后：`init` 检测到 `on_initramfs=1` 且无 `elden_root` → **不 switch_root、不启桌面**，串口停在 initramfs shell；`findmnt /`=`rootfs`、cmdline 无 `elden_root`。
    - 判断依据：串口/SSH `cat /proc/cmdline` **是否含 `elden_root=`**；`findmnt /` 是 `/dev/sda17` 还是 `rootfs`。
    - 纪律：建镜像用**显式文件名**（`VERSION=`），刷机用 `out/boot-elden-vkNN.img`（持久）而非 `out/boot-elden.img`；**零写盘选哪种镜像见 #93**（功能测试用持久变体，纯 RAM 只做内核/引导级验证）。

93. **★「RAM 启动」有歧义：`fastboot boot` 有两种镜像，选错得到「无桌面」环境**（2026-10-04 实测；音频 bring-up 曾据此误判）。
    - **A. 持久变体** `out/boot-elden-vkNN.img`（cmdline 含 `elden_root=LABEL=linux17`）：内核在 RAM，initramfs **挂磁盘根并 `switch_root`** → **桌面/Phosh、PipeWire、bluetoothd、Waydroid 等系统服务齐全**；**不写 flash**。
    - **B. 纯 RAM 变体** `out/boot-elden-vkNN-ram.img`（`ROOTARGS=`，无 `elden_root`）：停在 initramfs，`rootfs/init` 因 `on_initramfs=1` **只起 getty、不 `switch_root`、不启桌面**（`start-desktop.sh`/`bt-up.sh` 等条件均为 `on_initramfs=0`）。
    - **后果**：蓝牙音频、桌面音频栈、Waydroid、相机出流等**依赖会话/系统服务**的测试在 B 下必然失败，现象像「功能坏了」，实为环境缺失。
    - **选择规则**：内核/DTS/驱动早期验证、GPT/分区手术、首次 bring-up、防持久根污染 → **B**；**功能/服务级验收 → A（零写盘）**；长期固化 → `scripts/flash-b.sh out/boot-elden-vkNN.img` 写 b 槽。
    - 判断当前是哪种：`cat /proc/cmdline` 是否含 `elden_root=`；`findmnt /` 是 `/dev/sda17`（磁盘）还是 `rootfs`（RAM）。

---

## 十五、过时 / 废弃 / 功能缺陷登记（DEPRECATED）

> **用途**：登记已过时/废弃/被取代的**文件、会话、技能结论**，以及**已知功能缺陷**。
> **规则**：发现新的过时项就追加（不删，保留追溯）；引用其它内容前先看本节。
> **权威**：状态以 `TASKS.md`/`RESOURCES.md` 为准；本节只做「别再依赖」的索引。

### 15.1 已废弃 / 合并 / 删除的文档与文件

| 旧路径 | 处置 | 现在看 |
|---|---|---|
| `GAPS.md` | 并入 `TASKS.md` §5 | `TASKS.md` §5 |
| `ANDROID-COMPAT.md` | 并入 `TASKS.md` §6 | `TASKS.md` §6 |
| `FILES.md` | 并入 `RESOURCES.md` §3 | `RESOURCES.md` §3 |
| `SESSION-INDEX.md` | 并入 `RESOURCES.md` §4 | `RESOURCES.md` §4 |
| `LESSONS.md` | 删除（生成索引，冗余） | `PITFALLS.md` §0 + 正文 |
| `db/`（SQLite 知识库） | 删除（无原生查询需求） | `rg` + pi 会话选择器 |
| `archive/sessions-catalog-2026-10-03.jsonl` | 删除（db 数据源） | `RESOURCES.md` §4 |
| `archive/2026-10-02-merged/*` | 旧文档原文（证据，非废弃） | `INDEX.md` §6 |
| `.pi/pi-messenger.json` + `.pi/messenger/` + `scripts/{swarm,swarm-monitor,y700-swarm-reset,y700-harness-restart,start-y700-harness,apply-swarm-patch}.sh` + `patches/pi-messenger-swarm-*` | **插件 `pi-messenger-swarm` 已卸载**→脚本静默失效（`node …/server.js` ENOENT），**2026-10-06 工作流资产（脚本/补丁/运行时）已删除** | `archive/2026-10-04-retired-entrypoints/README.md`（入口副本+机器层登记；历史见 git） |
| `AGENTS.md` 旧「并行 subagent」段的 `swarm.py` 与 `.pi/messenger/agent-card.json` | 引用**从未存在的文件**，已改写为 `Agent` 工具 + `.pi/agents/` | `AGENTS.md` §协作 |
| `~/.local/bin/{flashing,eacndev,lob-remake}` | 三个 `cd` 包装（pi-profile-switch 时代命名），功能与 `cd <repo> && pi` 等价 → 已删除，副本留 `bin/` | `cd ~/y700-elden && pi` |
| `~/.pi-profile-switch/`（profile 机制） | 本机不存在；配置改为**按 cwd 叠加加载**，无需切 profile | `.pi/README.md` 首段 |
| `flashing-bundle/profile/flashing.json`、`backup/pi-assets-*/flashing.json` | 旧 profile 定义化石；**不要据此重建 profile** | `AGENTS.md` §协作 |

### 15.2 已迁移 / 退役的外部资产

| 来源 | 处置 | 日期 |
|---|---|---|
| `~/y700类原生安卓/` | 退役并入本 repo；文档进 `archive/topics/`；**类原生路线不做** | 2026-10-02 |
| profile/技能/会话 → `.pi/` | 内聚迁移（会话 `01a0f22e`） | 2026-09-30 |
| `backup/pi-assets-20260930-200129/`、`backup/pi-sessions-20260930/` | 迁移前备份（已 ignore） | 2026-09-30 |
| `flashing-bundle/` + `flashing-bundle-*.tar.gz` | 换机迁移包快照（已 ignore） | 2026-09-29 |
| `~/.pi/agent/pi-sessions/`(12 M) `~/.pi/wechat/`(1.1 M) `~/.pi/todos/` `~/.pi/agent/pi-agent-profiles/` `~/.pi/{session-control,_wtest}/` `~/.pi/agent/{_cron_backup,missions,git}/` | 已卸载插件的孤儿运行时目录，无任何已安装包引用（`grep` node_modules 无命中）→ **机器层待授权清理** | 2026-10-04 登记 |

### 15.3 被取代 / 无效的会话

| ID | 名称 | 状态 | 说明 |
|---|---|---|---|
| `01a0ed5b` | 分区：安卓GPT缩容与游戏备份 | superseded | 65G 缩容方案被持久根方案取代 |
| `01a100d9` | 解锁：sn.img 解密 blob 取证 | superseded | blob 路线未采用；解锁由降级 1.1 达成 |
| `01a101f3` | 引导：Linux→fastboot 能力核实 | superseded | 「能力不存在」被 PSCI vendor reset 推翻（见 `01a1021c`） |
| `01a0f533` | 会话：微信端汇报进度 | junk | 空会话 |
| `01a0f608` | 下载：续传（1T 盘暂缓） | junk | 无实质结论 |
| `01a0fa4b` | 会话：OK 测试 / 测试：仅回 OK | junk | 空（重复 2 条） |
| `01a0fabe` | 会话：测试 OK | junk | 空 |
| `01a101b5` | 会话：问候（空） | junk | 空 |

### 15.4 技能参考中已过时 / 待复核的结论

| 文件 | 过时点 | 现状 |
|---|---|---|
| `qualcomm-android-flashing/.../grub-uefi-dual-boot.md` | 把 `fastboot flash unlock sn.img` 当解锁法 | 四代 1.5.x 无效；改用降级 `1.1.11.073` + `oem unlock`（PITFALLS #86–87） |
| `qualcomm-android-flashing/.../tb321fu-region-lock.md`、`tb321fu-mod-package-boot.md` | TB321FU（Gen3）结论 | 仅作 Gen3 参考，**勿套 Gen4/TB322FC** |
| `qualcomm-android-flashing/.../community-tool-status-2026-08.md`、`qualcomm-edl-flashing/.../community-tool-status-2026-08.md` | 2026-08 社区工具状态 | 可能过期，引用前复核 |
| `gsi-device-adaptation/*` | 面向 **a 槽 Android/GSI** 的适配 | 项目已转容器路线（a 槽可弃）；仅历史参考 |

> 本表仅列**已知**项；其余 skill references 未逐篇审计。发现过时就补入。

### 15.5 已知功能缺陷（索引；详情见权威文档）

| 缺陷 | 状态 | 权威 |
|---|---|---|
| 桌面空闲熄屏 → 整机重启 | ⚠️ **未解 / 间歇性（2026-10-05）**：受控复现（DPMS off/电源键熄屏）；干净重建刷入后仍复位 ⇒ 假设未证实，已停止深究 | `TASKS.md` §5 Q24/G1-22；`PITFALLS` #102；`archive/topics/REBOOT-5MIN-2026-10-05.md` §7.9 |
| vk34 之后内核增量回归（vblank/PPM） | vblank 残留（不致复位）；主因已归 vk40 插桩 | `TASKS.md` §5 Q22 / G1-23 |
| 音频不可听 | ✅ 已出声（vk43）；输入端 ✅ 已打通（WCD939x AMIC1，UCM2 Mic） | `TASKS.md` G1-4 |
| 相机不出流 | ✅ 已出流（2026-10-05 G1-5，前后摄） | `TASKS.md` G1-5 / Q9 |
| TF 卡写丢失 | 未定性 | `TASKS.md` G1-6 |
| BT 配对 / 回连 | 未收口 | `TASKS.md` G1-7 |
| DP 输出（UCSI/altmode） | 未启用 | `TASKS.md` G1-9 |
| NFC | 未修 | `TASKS.md` G1-10 |
| CDSP | 未启用 | `TASKS.md` G1-11 |
| `reboot recovery`（进 TWRP） | 无 vendor reset，不可用 | `archive/topics/FLASHCTL-2026-10-03.md` |
| `reboot edl` | PSCI 已具备，未实测 | `TASKS.md` G1-24 |
| 60 Hz 切黑屏 | 面板固件仅适配 120 Hz | `PITFALLS.md` #10/#14 相关 |

### 15.6 已评估并排除的生态方案（勿重推，2026-10-07）

> 来源：`.pi/plans/2026-10-07-造轮子审计.md`（联网对比）。登记「已看过并否掉」的生态工具，避免日后当新发现重推（#87 同类代价）。

| 生态方案 | 结论 | 一句话理由 |
|---|---|---|
| **`qbootctl`** | ✅ **已采纳** | 取代 `slot-attr.py` 的读状态/mark-successful（#126） |
| Alpine `mkinitfs` | ❌ 不采用 | 本项目 initramfs 刻意不含模块/固件（switch_root 到磁盘根），其头号能力用不上；依赖 `nlplug-findfs`/`lddtree`/apk，与自定义 `/init` 冲突 |
| `pmbootstrap` / `pmaports` | ❌ 不迁移 | 可取代构建/刷写层，但与 lane/vk 版本体系、kexec/mod-loop 快环、自定义槽位处理冲突；除非目标改为发行镜像/上游进 pmaports |
| `alpine-make-rootfs` | ❌ 不引入（仅借思路） | 默认只给 x86_64 apk-tools，跨架构仍需自备；借鉴其 `apk --root --arch` 免 chroot 思路 |
| `msm-firmware-loader` | ❌ 不需要 | 固件已打包进 rootfs（pmOS 官方也更推打包） |
| `pil-squasher` | ❌ 反向 | 主线 qcom PIL 要的就是 `.mdt`+`.bXX` 拆分文件 |
| `casualsnek/waydroid_script` | ◐ G2 候选（待验） | GApps(A13 arm64，GitHub 源)/Magisk/MicroG 注入；**不改变 A13 arm64 无 Widevine L3 的判定**（arm64 仅 A11 有 prebuilt） |
| `FEX-Emu` | ◐ 仅对照 | G3 用 Box64 路线不变，可在基准里加对照 |
| `iio-sensor-proxy` + `libssc` | ◐ 未采纳（有意识） | 本项目明确不做 SLPI/QMI-SNS（`TASKS.md` §6①） |
