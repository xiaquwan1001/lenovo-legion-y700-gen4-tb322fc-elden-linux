#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 pre-vk34 回填历史的 plan.tsv（不写工作树/索引）。"""
import hashlib, os, subprocess, sys

ROOT = os.path.expanduser("~/y700-elden")
OUT = os.path.join(ROOT, "out")
ARCH = os.path.join(OUT, "archive")

def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()

def ep(path):
    return int(os.stat(path).st_mtime)

# (img path, tag, subject, body-extra)
# body-extra 每项为已含 \n 的字符串
V = []

def add(img, tag, subject, extra):
    V.append((img, tag, subject, extra))

A = lambda n: os.path.join(ARCH, n)
O = lambda n: os.path.join(OUT, n)

add(A("boot-elden-base1.img"), "base1",
    "bringup: 首次打包内核+busybox initramfs（build-boot.sh）",
    "首次复用作者 build-boot.sh，--base 0x10000000；仅用于 ABL/加载地址实验，未进 userspace。")
add(A("boot-elden-diag6.img"), "diag",
    "diag: 诊断 initramfs 暴露出 olddefconfig 误删 ARCH_QCOM",
    "diag..diag6 五连：initramfs 内置 elden_diag_reboot 自重启取证。根因=改 config 后跑 olddefconfig 连带删掉 CONFIG_ARCH_QCOM，显示/USB/UFS 全灭，白跑多轮；此后禁用 olddefconfig 并在 build.sh 内置校验。")
add(A("boot-elden-fixed3.img"), "fixed3",
    "bringup: 恢复 ARCH_QCOM/splash_region/eUSB2/背光 → 首次进 userspace+USB+UFS",
    "恢复 .config.panel；DTS splash-region→splash_region；PHY_NXP_PTN3222=y；BACKLIGHT_AW99706=y。首次决定性成功：Linux 7.2.0 进 userspace、/dev/ttyACM0 串口 shell、UFS sda1..sda15、背光 probe 成功。")
add(A("boot-elden-fixed4.img"), "fixed4",
    "display: 禁用 &mdss_dp0 解 DRM 绑定死锁 → 显示打通",
    "&mdss_dp0 status=disabled：无 ADSP 时 DP 作为 DRM component 永远 defer，卡死 msm_drm_bind→无 card0。改后 logo→闪→Linux 终端页。")
add(A("boot-elden-alpine.img"), "alpine",
    "rootfs: 换 Alpine in-RAM 根，USB-NCM 192.168.7.1 + 免密 SSH",
    "作者 init/usb-gadget/reboot2 + Alpine rootfs（15.7MB）。USB-NCM 网络与免密 SSH 可用，bash/tmux/strace/i2c 就位。")
add(A("boot-elden-gpu3.img"), "gpu3",
    "gpu: 换设备签名 gen80000 固件 → GMU v5.1.25 + renderD128",
    "rootfs 放设备 vendor 签名版 gen80000_{zap.mbn,sqe.fw,gmu.bin,aqe.fw}：Loaded GMU firmware v5.1.25、设备签名 zap 被 TZ 接受、renderD128 出现。此前初次卡 logo 因 A/B 槽假 dtbo 只写 a，两槽都写后起来。")
add(A("boot-elden-vk.img"), "vk1",
    "gpu: Alpine+Turnip 窄 rootfs 首版（chip-id 补丁误伤）",
    "Vulkan-only（删 libgallium/libLLVM/GL，31MB），打了作者 Mesa chip-id 补丁（…44050000→…44050001）。实测 Turnip 报 chip_id=E844050000 unsupported——本机 A830=0x44050000 匹配原版 wildcard，补丁反而错。")
add(A("boot-elden-vk2.img"), "vk2",
    "gpu: 撤销 Mesa chip-id 补丁 → Turnip Vulkan 1.4.354（Adreno 830）",
    "原版 wildcard；内建 GPU/ADSP 固件。vulkaninfo：Adreno 830 / turnip / Vulkan 1.4.354；ADSP 起（adsp.mbn.zst 命名不符 mdt，仍 deferred）。")
add(A("boot-elden-vk3.img"), "vk3",
    "firmware: rootfs 内建触屏/BT/ADSP 固件，开机自动 probe",
    "触屏 fw 1a.01、『QCA setup on UART is completed』、『adsp is now up』全部开机自动。")
add(A("boot-elden-vk4.img"), "vk4",
    "rootfs: init 自动挂载 /persist（sde79 ext4）",
    "init 加 /persist 自动挂载（等 /dev/sde79 → ext4 rw,noatime）；开机自动挂载、跨重启写保留。")
add(A("boot-elden-vk5.img"), "vk5",
    "audio: 功放 ACF + MTP tplg + alsa-utils（card0 建立，speaker EINVAL）",
    "加入功放 ACF（awinic/y700-gen4-speakers.bin，实为 vendor aw882xx_acf.bin）+ MTP tplg 顶替 Lenovo-Y700-Gen4-tplg.bin + alsa-utils。两个 aw88461 bind、card0 创建；speaker-test -EINVAL（MTP tplg 无 MI2S 后端）。")
add(A("boot-elden-vk6.img"), "vk6",
    "rootfs: init 支持 elden_root=LABEL=linux 切磁盘根（首次持久根）",
    "init 支持 elden_root=LABEL=linux → switch_root 到 sde79 磁盘根；cmdline 加 elden_root。首次持久 root 引导（字体/固件/数据落盘）。")
add(O("boot-elden-vk7.img"), "vk7",
    "rootfs: 持久根基线（/dev/sde79）+ init 硬化（uid=0）",
    "vk6 + init 硬化（启动前 chown 0:0 /var/empty；拷贝改 --owner=0:0）；pack.sh 支持 EXTRA_CMDLINE。持久 root 基线：/ = /dev/sde79，sshd 自启、数据持久。")
add(O("boot-elden-vk8.img"), "vk8",
    "wifi: ATH12K=m 模块化，启动 99s→8s（PCIe 链路未起）",
    "CONFIG_ATH12K=m（模块），/init 改用 ath12k-load.sh（modprobe ath12k_wifi7），init 备份 init.bak-vk8-<ts>。启动 99s→8s（不再阻塞 initcall）；但 PCIe 链路不起来（WCN 上电依赖 built-in probe/ABL 状态）→ WiFi 无。")
add(O("boot-elden-vk9.img"), "vk9",
    "wifi: 0001 ath12k MHI 超时 90s→3s，WiFi 打通（phy0/wlan0）",
    "还原 ATH12K=y；patches/0001-ath12k-shorten-mhi-timeout.patch（mhi.c MHI_TIMEOUT_DEFAULT_MS 90000→3000）；/init 用 ath12k-retry.sh。init ~5s 起、gadget ~26s；手动/脚本只 bind 未绑定 PCI 设备 → phy0 + wlan0，WiFi 通。")
add(O("boot-elden-vk10.img"), "vk10",
    "wifi: 冷启 WiFi 全自动 + DTB sdhc_2 no-1-8-v（TF 降速试验）",
    "同 vk9 内核；DTB 重编（&sdhc_2 no-1-8-v TF 降速试验）；initramfs 进 ath12k-retry.sh（只 bind 不 unbind）+ net-up.sh（wpa_supplicant+后台 udhcpc）。冷启 WiFi 全自动：bind ok@18s→phy0@23s→dhcp@26.8s→wlan0 有 IP；TF 卡 mkfs 后挂载失败。")
add(O("boot-elden-vk11.img"), "vk11",
    "desktop: glycin bwrap shim 修 phosh abort → Phosh 冷启全自动",
    "ramdisk=新 init：elden_root 分支写 glycin bwrap shim（让 glycin 自检命中『内核挡 bwrap』→切 NotSandboxed），修 phosh abort；另修 libGL 缺失/删 gsd-power/pkill -x 四坑。Phosh 冷启全自动（udevd+seatd+phosh-session，锁屏滑解锁、无 PIN）。")
add(O("boot-elden-vk12.img"), "vk12",
    "gpt: userdata 缩容 + 新增 sda17 linux17(65GiB)，持久根切换",
    "GPT 手术：userdata 缩到 146.4GiB，新增 sda17 linux17 65GiB ext4；cmdline 改 elden_root=LABEL=linux17。从 /dev/sda17(63.4G) 起，phoc/phosh 自启；/dev/sde79 留后备。")
add(O("boot-elden-vk13.img"), "vk13",
    "power: 关 SUSPEND/HIBERNATION + 自签 boot_b 直启 Linux",
    "scripts/config -d SUSPEND -d HIBERNATION（CONFIG_PM_SLEEP=n，.config.bak-vk13-nosuspend 备份）；其余同 vk12；经 sign-boot-b.sh + flash-b.sh dd 写 boot_b。/sys/power/state 空、无 mem_sleep；b 槽自签 AVB 直启 Linux（~9s，不需 fastboot）。")
add(O("boot-elden-vk14.img"), "vk14",
    "display: 0002 dspp .gc gamma → Night Light 可用",
    "sm8750_dspp_sblk catalog 补 .gc = {.base=0x17c0,.len=0x40,.version=0x10008}（DSPP GAMMA_LUT），patches/0002。Night Light 面板出现、可调、按钮可用。踩坑：裸 make 覆坏 linux/.config，用设备 zcat /proc/config.gz 拉回修复（PITFALLS #9b）。")
add(O("boot-elden-vk15.img"), "vk15",
    "haptics: 0003 aw86927 SRAM 窗口修复（probe 过但不震）",
    "aw86927.c SRAM 上界修复（固件超 4KB 被写死窗口拒；按型号区分 SRAM 窗口，初版补丁名 0003-…-sram-window.patch）。probe 无报错，但不震（回退 vk14）。")
add(O("boot-elden-vk16.img"), "vk16",
    "haptics: aw86927 play work 加 debug 打印（定位）",
    "aw86927_haptics_play_work 加临时 dev_info debug 打印；播放路径执行、寄存器可见，仍不震。")
add(O("boot-elden-vk17.img"), "vk17",
    "haptics: aw86927 寄存器级 debug（命令执行但不震）",
    "加深寄存器级 debug（play 路径逐寄存器）；播放命令确实执行，马达不动。")
add(O("boot-elden-vk18.img"), "vk18",
    "haptics: 移植厂商 AW86937 CONT 模式 → 马达震动",
    "从厂商 haptic.ko 反汇编移植 AW86937 CONT 连续模式序列（PLAYCFG3[1:0]=2、VBATCTRL bit6、CONTCFG 等）；用户确认马达震动（FF path 执行）。")
add(O("boot-elden-vk19.img"), "vk19",
    "haptics: 0003 定稿（SRAM+CONT），vk19 干净基线",
    "去 debug 打印，补丁定稿 patches/0003-aw86927-aw86937-haptics.patch（SRAM 8K 窗口 + CONT）。左右马达均 rumble ON；成为后续基线（dd 进 boot_b）。B1 夜灯 + C3 触觉同此版冻结。")
add(O("boot-elden-vk20-debug.img"), "vk20",
    "debug: 开启 ftrace/kprobes/kgdb/DWARF5（config-vk20-debug）",
    "开 FTRACE/DYNAMIC_FTRACE/KPROBES/KGDB/SND_DEBUG/DEBUG_INFO_DWARF5/DEBUG_LIST，LOCALVERSION=-debug；不跑 olddefconfig。配置存 patches/config-vk20-debug；上机用于音频 ftrace/kprobe。")
add(O("boot-elden-vk21-dma32.img"), "vk21",
    "audio: 尝试 DMA 32-bit 掩码（地址未受限，否定）",
    "q6apm_dai_probe 加 dma_set_mask_and_coherent(dev, DMA_BIT_MASK(32))；实测地址仍 0x1fff00000（mask 返回 0 但分配未受限）→ 否定。")
add(O("boot-elden-vk22-audiomem.img"), "vk22",
    "audio: DT <4GiB shared-dma-pool + memory-region（未生效，否定）",
    "DT 加 <4GiB shared-dma-pool（q6apm-audio-mem,16MiB@0xf1c00000）+ memory-region + of_reserved_mem_device_init()；池已建、节点带 memory-region，地址仍 0x1fff00000，dma_mem=0 → 否定。")
add(O("boot-elden-vk23-dbg.img"), "vk23",
    "audio: 加 DBG 打印纠正地址/SID 误读",
    "probe+memory_map 加 DBG 打印：关键纠正 addr=0xfff00000(<4GiB)、sid=1、coherent=0xffffffff(32bit 生效)、dma_mem=0；前次『8.6GiB』是 addr|sid<<32 误读。")
add(O("boot-elden-vk24-nosid.img"), "vk24",
    "audio: 强制 sid=-1（DSP 仍报错，否定）",
    "强制 pdata->sid=-1（phys=addr,msw=0，厂商编码）；仍『DSP returned error[100100c] status=1』→ 地址/SID 均非根因。")
add(O("boot-elden-vk25.img"), "vk25",
    "bt: 0004 btqca WCN7861 关 IBS 深睡（控制器睡眠↓，链路无效）",
    "patches/0004：btqca.c WCN7861 分支 data[1] |= 0x01 → &= ~0x01（关主 NVM 的 IBS 深度睡眠）。控制器 ibs_recv_sleeps 2121→40（睡眠风暴消除），但 RTT 44–97ms、突发掉包无改善 → 保留补丁，蓝牙另立项。")
add(O("boot-elden-vk26.img"), "vk26",
    "container: binderfs/PSI/netfilter NAT 内核前置（binderfs 可用）",
    "ANDROID_BINDER_IPC/BINDERFS/ANDROID_BINDER_DEVICES、PSI=y、IP_NF_IPTABLES/NF_NAT/XT_TARGET_MASQUERADE=y，存 patches/config-vk26-android-container。内核 #21：/proc/filesystems 有 binder、挂 binderfs 出 binder/hwbinder/vndbinder、/proc/pressure 可用；用户态装 waydroid/lxc/iptables。")
add(O("boot-elden-vk27.img"), "vk27",
    "container: netfilter legacy + waydroid0/dnsmasq（SF 图形仍崩）",
    "NETFILTER_XTABLES_LEGACY=y + IP_NF_{IPTABLES_LEGACY,FILTER,NAT,MANGLE,RAW}=y + IPv6 同套 + XT_TARGET_CHECKSUM=y，存 patches/config-vk27-container-netfilter。内核 #22：容器 waydroid0 192.168.240.1 + dnsmasq 起来；netfilter legacy 生效；SF 图形仍崩（Mesa 26.0.8 缺 A830 DRM chip_id）。")
add(O("boot-elden-vk28.img"), "vk28",
    "net: netd IPv6/XFRM 片段（IP6_NF_*/XFRM_USER）",
    "fragment-netd-ipv6-xfrm.config（IP6_NF_*、XFRM_USER、XT_MATCH_POLICY 全 =y），存 patches/config-vk28-netd-ipv6-xfrm。仅构建+RAM fastboot boot；用 vk27 原内核跑新脚本复现=逐字节相同。修 build-boot.sh 默认 ramdisk 回归 Alpine rootfs。")
add(O("boot-elden-vk29.img"), "vk29",
    "audio: 0005 q6apm 可配置 APM 源端口（service@1→3,2→7）",
    "patches/0005：audioreach.c/.h 新增可配置 APM 源端口（audioreach_set/get_apm_src_port），q6apm.c 跟随 DT reg；sm8750.dtsi q6apm service@1→3、q6prm service@2→7；同时还原 vk21–24 的 sid/DBG/reserved-pool 遗留。内核 #26：gprsvc:2:3 / 2:7、APM 源端口 kprobe=3；card0 出现 MM1/MM2 playback；但 GET_SPF_STATE 仍超时、SHARED_MEM_MAP_REGIONS 仍 status=1、aplay EINVAL。")
add(O("boot-elden-vk30.img"), "vk30",
    "panel: 0006 DSI 时序诊断 + 0007 force_hz 钩子（冷启 165Hz 无报错）",
    "patches/0006（dsi_timing_setup dev_info 打印 htotal/vtotal/压缩时序）+ 0007（force_hz 测试钩子，cmdline panel_novatek_nt36536.force_hz=165）。测试 A：冷启强制 165Hz，pclk/byte/bit 与离线预测逐位吻合，CRTC 扫描出图，phoc+Xwayland+GNOME 正常，DSI 报错 0；背光 511。")
add(O("boot-elden-vk31.img"), "vk31",
    "panel: force_hz=0 暴露 8 档 / preferred=120Hz（phoc 钉 preferred）",
    "同 0006+0007，force_hz=0 暴露全部 8 档、preferred=120Hz。测试 B：wlr-randr 切 165 返回 rc=0，但 phoc 始终 Modesetting @120（合成器钉 preferred）；无 DSI 报错。")
add(O("boot-elden-vk32.img"), "vk32",
    "panel: 0008 165Hz 档移至 modes 首位 → 165Hz 默认",
    "patches/0008：把 csot_pp8807hb1_1_modes[] 的 165Hz 档移到数组首位（count==0→PREFERRED）。内核 #28：modetest -c #0 = 165 preferred（8 档全在），phoc Modesetting @165，DSI 报错 0，运行 2 min 复核 0。165Hz 成为设备默认。")
add(O("boot-elden-vk33.img"), "vk33",
    "audio: kprobe 抓 GPR GET_SPF_STATE（24B vs 上游 40B）",
    "0006+0007+0008 + kprobe 追踪（无新源码补丁）：抓 gpr_send_pkt GPR 往返，抓到 ADSP 应答 apmrx op=0x02001007(GET_SPF_STATE)；发现本树 GET_SPF_STATE 包 24B（无 16B APM 头）vs 上游/piano 40B。")
add(O("boot-elden-vk34.img"), "vk34",
    "audio: 0009 alloc_apm_cmd_pkt 带 APM 头 → GET_SPF_STATE 应答、超时消除",
    "patches/0009：q6apm_get_apm_state / __q6apm_map_memory_fixed_region / __q6apm_unmap_memory_fixed_region 三处 alloc_apm_pkt→alloc_apm_cmd_pkt（带 APM 命令头）。内核 #30：loopback 应答 0x02001007（6.88s 超时消除）；冷启无 Error 0x0100100c，声卡完整注册。新阻塞：tplg 的 I2S 设备子图未注册 → no backend DAIs enabled / aplay EINVAL。")
# ---- 桥接 vk35..vk40（10-02，git 纳管前，仅存文字记录）----
add(O("boot-elden-vk35.img"), "vk35",
    "thermal: 过热限频会话（ss h 读数）",
    "10-02 01:40。温控限频会话前后构建；仅 ssh 读数，未见明确 vk35 在跑确认。记录 archive/topics/THERMAL-2026-10-02.md。")
add(O("boot-elden-vk36.img"), "vk36",
    "thermal: 0010 分级 trips",
    "patches/0010-thermal-graded-trips：CPU 热区由单一 passive trip=105℃ 改为分级 trips，补 cdev 绑定以便有效降温。记录 archive/topics/THERMAL-2026-10-02.md。")
add(O("boot-elden-vk36debug.img"), "vk36debug",
    "thermal: vk36 debug 变体",
    "vk36 的调试变体（保留 debug 配置），用于温控 trip/cdev 验证。")
add(O("boot-elden-vk37.img"), "vk37",
    "audio: 0011 q6apm MI2S prepare 时启动图",
    "patches/0011-q6apm-mi2s-start-graph-at-prepare：把 MI2S 子图启动从 hw_params 提前到 prepare，推进 tplg FE→BE 路由。记录 archive/topics/AUDIO-2026-10-02.md。")
add(O("boot-elden-vk38debug.img"), "vk38debug",
    "audio: vk38 debug 变体",
    "vk37/38 音频线的调试变体（含 0011），用于 tplg/DAPM 出图排查。")
add(O("boot-elden-vk39.img"), "vk39",
    "bringup: vk39 基线（thermal 0010 + MI2S 0011）",
    "整合 0010+0011 的基线镜像。RESOURCES §3 记 INDEX 曾称『最后在机基线 vk39』但无会话级确认。")
add(O("boot-elden-vk40.img"), "vk40",
    "bringup: vk40 配置（config-vk40-bringup）",
    "vk39 之后 + config-vk40-bringup 片段。10-03 上机（U2 持久 Phosh），但曝熄屏即重启等新 bug；此后成为 vk34 回归隔离的对照点。")
add(O("boot-elden-vk40-ram.img"), "vk40-ram",
    "bringup: vk40 RAM-only 变体（救援/回退）",
    "vk40 的 RAM-only 变体（无持久根），供救援/回退与零写盘测试。")

# ---- 显式归属提示：把可唯一辨识的 patch/config 钉到引入它的版本 ----
HINTS = {
    "vk9":  ["patches/0001-ath12k-shorten-mhi-timeout.patch"],
    "vk14": ["patches/0002-sm8750-dspp-gc-gamma.patch"],
    "vk15": ["patches/0003-aw86927-aw86937-haptics.patch"],
    "vk25": ["patches/0004-qca-wcn7861-disable-ibs-deepsleep.patch"],
    "vk29": ["patches/0005-q6apm-gpr-downstream-client-ports.patch"],
    "vk30": ["patches/0006-dsi-timing-diag.patch", "patches/0007-panel-force-hz-test-hook.patch"],
    "vk32": ["patches/0008-panel-165hz-default.patch", "patches/config-vk32-camera-base.bak"],
    "vk34": ["patches/0009-q6apm-apm-cmd-header.patch"],
    "vk36": ["patches/0010-thermal-graded-trips.patch"],
    "vk37": ["patches/0011-q6apm-mi2s-start-graph-at-prepare.patch"],
    "vk20": ["patches/config-vk20-debug"],
    "vk26": ["patches/config-vk26-android-container"],
    "vk27": ["patches/config-vk27-container-netfilter"],
    "vk28": ["patches/config-vk28-netd-ipv6-xfrm", "patches/fragment-netd-ipv6-xfrm.config"],
    "vk38debug": ["patches/config-vk38-camera"],
    "vk40": ["patches/config-vk40-bringup", "patches/fragment-camera-sensors.config"],
}

# ---- 输出 ----
lines = []
for img, tag, subj, extra in V:
    if not os.path.exists(img):
        print("MISSING IMAGE:", img, file=sys.stderr)
        continue
    e = ep(img)
    body = "\\n".join([
        "日期: " + __import__("time").strftime("%Y-%m-%d %H:%M", __import__("time").localtime(e)) + " (CST)",
        "镜像: " + os.path.relpath(img, ROOT) + "  sha256:" + sha(img),
        "改动/结果: " + extra,
        "记录: RESOURCES.md §3；archive/topics/ 相关专题。",
    ])
    hints = " ".join(HINTS.get(tag, []))
    lines.append("\t".join(("1", str(e), tag, subj, body, hints)))

# 桥接提交：吸收 10-02 19:43 ~ 10-03 19:30 的文件
bridge_ep = 1791027074  # e3ec468 提交 (1791046275) 前 1s
bridge_body = "\\n".join([
    "日期: 2026-10-02 ~ 2026-10-03（git 纳管前）",
    "改动/结果: vk40 之后至 git init(e3ec468) 之前的收尾工作：U2 上机与 GPT 手术、BL 降级解锁、容器/温控/驱动审计、持久化与睡眠取证等，均只存于文字记录（见 archive/topics/ 与 RESOURCES.md §3/§4）。",
    "说明: 本提交为桥接提交，把该时间窗内的项目文件并入回填历史，使 e3ec468 可平滑 graft。",
])
lines.append("\t".join(("1", str(bridge_ep), "-", "pre-git: 10-02~10-03 收尾（vk40 之后至 git 纳管前）", bridge_body, "")))

with open("/tmp/plan.tsv", "w") as f:
    f.write("\n".join(lines) + "\n")

print("wrote /tmp/plan.tsv with", len(lines), "commits", file=sys.stderr)
for i, l in enumerate(lines):
    print(i+1, "\t", l.split("\t")[1], l.split("\t")[2], l.split("\t")[3], file=sys.stderr)
