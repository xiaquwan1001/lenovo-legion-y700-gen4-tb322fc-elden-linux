# y700-elden — 从全局记忆下沉的内核/设备条目（2026-11-28 审查 lane M2）

> 来源：`~/.pi/agent/memory/failures-{build,gateway,git}.md` 中判定为 y700 内核/设备专属的条目，2026-11-28 原样（或合并后）搬到此处；全局文件原位只留指针。
> 目标仓已有等价记录的条目（vermagic / UTS / kexec / cdsp / boot.img）未重复搬入，只搬判据不重复的。
> 纪律：每条一段、`---` 分隔；新条目按主题写进对应 `failures-kernel-*.md` 的正文件。

---

## 内核构建与构建身份

内核模块 vermagic 不匹配会导致 insmod 被拒，且报错信息不指向版本差异时容易误判成驱动/DT 问题；排查硬件功能缺失时先用 `modinfo <mod>.ko | grep vermagic` 对比设备 `uname -r` 是三秒检查。跨内核实版复用 .ko 必须重编。

---

内核构建身份保真（2026-10 反复踩坑，6 条合并）：① 单变量对照必须手工钉死 UTS —— `CONFIG_LOCALVERSION="-debug-g<sha>"` + `CONFIG_LOCALVERSION_AUTO=n`。② 只设 AUTO=n 不够：`scripts/setlocalversion` 里 `elif [ "${LOCALVERSION+set}" != "set" ]; then scm_version --short` ⇒ make 变量 LOCALVERSION **未定义**就追加 `-g<sha>`/`+`；**在 make 命令行显式传 `LOCALVERSION=`（空值也算 set）** 才得到精确 UTS（如 `7.3.0-rc7-debug-ged6f232d10e3`）。`scripts/env-build.sh` 的 `: "${LOCALVERSION:=}"` 只设 shell 变量、不 export，直接跑 `make` 而不走它的 kbuild() 就会踩到；判据 = `make -s ARCH=arm64 kernelrelease` 末尾有无 `+`。③ 树 dirty/未跟踪文件让 UTS 带 `-dirty`（vermagic 不匹配；模块目录 symlink 到无 -dirty 路径时 insmod 报 version magic mismatch / Exec format error）；提交时漏 `git add` 某 tracked 文件同样带 `+`，需 amend 后重编。④ 时机陷阱：树 HEAD ≠ 任何 tag 且工作树有改动时 setlocalversion 仍追加 `+`，要精确串就命令行传 `LOCALVERSION=`（推荐）或临时打 tag。⑤ 反向教训：同一源码树、同一 config、仅 LOCALVERSION/git sha 不同的两个构建身份就能翻转观测结果（GOOD ↔ NOCARD）⇒ 该 A/B 方法本身失效；自检用「sham 臂」（加一行无副作用 `pr_info`）与「empty 臂」（空提交，零代码改动只换 git sha），它们同样翻转即结论作废。判镜像是哪次构建看 `uname -v`（`#2 SMP PREEMPT <date>`），不是 `uname -r`。

---

内核 Kconfig `select` 会连带把子配置降级（`make olddefconfig` 也拉不回）：`CONFIG_ATH12K=m` 经 `drivers/net/wireless/ath/ath12k/Kconfig` 的 `select PCI_PWRCTRL_PWRSEQ if HAVE_PWRCTRL` 把 `CONFIG_PCI_PWRCTRL_PWRSEQ` 从 =y 拉成 =m，而 PCIe host 驱动内置、在模块加载前就 probe ⇒ `qcom-pcie 1c00000.pcie: cannot initialize host`、`ls /sys/bus/pci/devices/` 为空（无 0000:01:00.0）、ath12k 无从绑定（`gave up, no phy0`）。本质：PCIe 电源序列驱动必须在 host 之前就绪。判定链：dmesg 的 `cannot initialize host` → PCI 设备目录空 → `lsmod` 查被 select 降级成 =m 的依赖模块。修法：翻 =m 前先 grep Kconfig 的 select 链，把被 select 的驱动显式钉回 =y；免重编验证 = 在当前启动 `modprobe pci_pwrctrl_pwrseq`（+ pwrseq-pcie-m2）触发 deferred-probe 重试，PCIe 即可枚举、ath12k 首探成功（MHI `Power on setup success`，无 -110）。 — Failed: 翻 =m 做单变量探针时被 PCIe 电源序列连带降级污染，误判为设备/探针序列问题。

---

内核模块编译的 Module.symvers 覆盖度（3 条合并）：`make M=net/bridge`（单目录编译）不更新顶层 Module.symvers，跨目录依赖符号（`llc_mac_hdr_init` from net/llc、`stp_proto_register` from net/802）在 modpost 阶段报 undefined；`make path/to/foo.ko` 同因（"undefined symbols from sibling modules"）。正确顺序 = 先整树 `make modules`（或 `modules_prepare` + 全树构建）生成完整 Module.symvers，再做 M= 或单模块编译。

---

内核模块交叉编译铁律（2026-10-11 实锤）：`make modules_prepare` / `make <module>.ko` 必须带 `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`（或 source `scripts/env-build.sh`）。不带 ARCH 时 make 按 HOST 架构（x86）跑，会把 `.config` 覆盖为 x86 默认（sha 从 a383cdb9→5dee2b27），且 `include/generated/asm/compiler.h` 等架构特定头文件不会生成（报 `fatal error: asm/compiler.h: 没有那个文件或目录`）。恢复方法 = 从设备取回 `/boot/config-$(uname -r)` 覆盖回 `.config`（sha 校验回 a383cdb9），然后带正确 ARCH 重跑 modules_prepare。 — Failed: modules_prepare 不带 ARCH=arm64 被当 x86 原生跑，覆盖了 aarch64 的 .config 并导致后续编译失败 补充（2026-11-12，y700-elden 5 次重复踩）：漏 ARCH 是**静默**故障——无报错、只表现为后续外部模块/头文件全对不上；判据 = 命令回显 arch 非 arm64 或 `.config` 里 CONFIG_ARM64 消失。

---

linux 树里构建脚本的 .config 守卫（grep CONFIG_ARCH_QCOM）在本树已过时——合法 config 里该符号不存在/被重命名，会误报「corrupted by olddefconfig」拦下构建。判据：`grep -n 'ARCH_QCOM' linux/arch/arm64/Kconfig*` 有两个定义；直接显式 `CONFIG_ARCH_QCOM=y` 后构建通过。另外本树 `.config` 会被意外写坏（曾出现 `CONFIG_ARCH_QCOM is not set` 覆盖全 config），恢复源用 `.config.old`（与最近一次成功镜像 manifest 的 config_sha256 比对一致的才是对的）。 — Failed: build 守卫 grep 过期，误判合法 config 为损坏

---

内核探针写 `pll->pll_base` 会编译失败：`struct dsi_pll_7nm` 没有 `pll_base` 成员（3.93s 即 `error: 'struct dsi_pll_7nm' has no member named 'pll_base'`，只影响 dsi_phy_7nm.o）。正确写法 `pll->phy->pll_base`（`dsi_7nm_phy_enable()` 里只有 `phy`/`base`）。改完需 `--amend` 重提交再增量构建，否则 UTS 带 -dirty。

---

内核 patch 循环重试（F1/F2 风格）会让 init 时序恶化、且第二次起 MHI 报 -5「SECONDARY BOOTLOADER is not a valid EE」——正确做法是让 probe 返回 -EPROBE_DEFER（F3），把重发交给内核 probe 框架；有界 defer 计数（如 ATH12K_PCI_MAX_DEFER=4 + static atomic_t）防死循环。

---

kernel 构建脚本里 `git checkout <branch>` 后直接 `git apply <patch>` 会因残留的未提交 tracked 改动而 apply 失败（`error: 打补丁失败 ... 补丁未应用`）。正确顺序 = 先 `git checkout -- <files>` 清残留改动 → 再 apply。另：setlocalversion 在树有未跟踪改动/未提交改动时会追加 `-dirty` 到 UTS，进而使 vermagic 与模块目录不匹配（insmod 报 Exec format error），因此实验臂必须 commit 到独立分支而不是留在工作树。

---

构建配对的「单变量」内核臂时，三条约束缺任一条结果即不可信（2026-10-11 实锤）：① config 必须 pin 到指定 sha（build 前 `cp patches/config-before-fragment-20261004-155410.bak linux/.config` 并校验 sha256；否则 .config 漂移如 c1 fragment 会混入）；② patch 必须 commit 到独立分支（工作树留未提交改动会让 setlocalversion 追加 `-dirty`，vermagic 不匹配）；③ `git checkout <branch>` 前先 `git checkout -- .` 清残留 tracked 改动，否则 patch apply 失败。另有 ccache 陷阱：`scripts/env-build.sh` 必须 source 不能执行（历史教训：各 build 脚本各自设 CROSS_COMPILE 导致「装了 ccache 但 0 GiB 缓存」）。

---

内核树里用 `make LOCALVERSION= ... Image.gz` 在部分臂/worktree 会报 `make[1]: *** 没有规则可制作目标"Image.gz"。停止。`（rc=2）——通常是该 worktree 的 `.config` 未 `olddefconfig`/无 arch 选择或缺少 `ARCH=arm64` 环境；核对顺序 = 先 `. scripts/env-build.sh`、再 `make ARCH=arm64 olddefconfig`，然后再编。UTS 判据：`make -s kernelrelease` 显 `7.3.0-rc7-debug-ged6f232d10e3`，且 Image 内嵌串（`strings`/grep 'Linux version'）与之逐字一致才算身份对。

---

## 固件 / 无线 / 探针

从 boot.img 抽内核 UTS 的格式坑（两条合并）：`unpack_bootimg.py` 对某些镜像输出 `kernel_uts: (not found)`；用 python zlib 直接解抽出的 kernel 段会 `zlib.error: Error -5 while decompressing data: incomplete or truncated stream` —— 因为 mihomo/本地打包的 boot.img 里 kernel 载荷**本身已是 gzip**，应按镜像格式定位 kernel 段后再 gunzip，别手搓偏移。ground truth 取法 = 与 `scripts/build-manifest.sh` 同法（`re.search(rb'Linux version [0-9][^\x00]+', img)`）直接从镜像抽。另：pk 文件名里的版本号不可信（vk47a-ram 内核实为 ga923477be3a9-dirty；vk47-ram 才是 g4c68eb5ed4e-dirty），必须抽 UTS 定性。

---

mdt_loader 的单文件 vs split 固件格式差异（2026-10-07 分析）：单文件 cdsp_dtb.mbn（36664 B）与 vendor split 合并（37900 B）不同——ELF 的 metadata segment（ph2，3896 B 起始）内容不同（first diff at 200），且单文件 ph1 载荷比 split b01 多 104 字节。ELF header 层（phnum/phoff/phdr）两者一致。⇒ 单文件版与 split 版非同一构建的等同物，判 PAS id 时不能默认二者互换。

---

内核驱动日志「X init failed, stop trying」不等于底层通道坏——判断 UCSI/remoteproc 类失败时必须读源码确认 defer/超时的确切来源（ucsi_glink 的 PPM init failed 实为 ucsi_register_port 的 20×EPROBE_DEFER 耗尽，reset/capability 其实成功）。且该驱动在 ucsi_glink.c 里没有 dynamic debug 站点，靠 dynamic_debug 排查无效，只能读源码。

---

WiFi 掉线归因纪律（2026-10-06 验证，两条合并）：① 第一现场是 `iw station dump` 的 `beacon rx` 与 `connected time`；只看 `lost`/`deauthenticating` 计数会误判已修复——关掉驱动 connection_loss_work 的拆链路径后 `lost` 归零，但 mac80211 的 AP-probe 超时立刻接手（该路径不发 deauth、不打印 lost），掉线节奏与关联寿命不变。② 排查同 UTS 串的候选内核是否真启动，必须看 `uname -v` 的编译时间戳（`#2 SMP PREEMPT Tue Oct  6 19:18:07 CST 2026`），`uname -r` 相同不代表跑同一构建。③ `debug_mask=2` 会把 ring buffer 冲爆、差分计数变负。④ 被动扫描（passive scan）可定案 AP 无辜：黑屏窗口内 P40 命中 1、扫描 0 BSS / rc=240 ⇒ 射频路径本身在坏。⑤ PS on/off、持续流量、换 AP（ustcnet 开放 AP 仍复现）、清掉全部 interloper 单变量均已排除。 — Failed: 归因与证据纪律

---

构建 Wi-Fi/驱动候选时的清理判据：如果设备上只存了「手动 supplicant 进程仍在跑」这一状态，并不足以判定 Q26 修复有效——必须先清掉 interloper + 重启，再观察「关联寿命 + 稳定点」两个指标（因为 mac80211 AP-probe 路径会接管掉线、不打印 `lost`）。

---

qcom_cc_probe 驱动（drivers/clk/qcom/common.c）的 use_rpm 标志是 driver_data 编程的前置条件：`if (desc->use_rpm) { pm_runtime_resume_and_get(); }` 然后才跑 `driver_data->clk_regs_configure()`。删除 use_rpm 但保留 driver_data = 在 power domain 未 resume 时往寄存器写值 → 挂在总线上的 NoC 永久 hang（设备卡 bootloader logo、内核从未启动）。对 cambistmclkcc 等无 GDSC、无消费者的裸块尤其致命：use_rpm 是唯一保证 regmap 可写的机制。要改 PM 生命周期必须保留 use_rpm=true 并在 resume/suspend 回调里重排编程顺序，不能直接去掉。

---

build-manifest.sh 的 `kernel_sha256`/`kernel=` 记录的是 linux/ 树的 Image.gz，而实际打包可能是 build-boot.sh 的 `--kernel` 覆盖路径（如 /tmp/.../kernel），二者可以是不同内核 ⇒ manifest 的 kernel 列会误导（PITFALLS #131）。重打包 boot.img 必须 unpack 原镜像取 kernel，不能信 manifest 的 kernel 字段。已给 build-manifest.sh 增加 kernel_release / kernel_uts / kernel_payload_sha256 / kernel_packed_from / kernel_packed_sha256 自证字段。

---

**`kexec -l --dtb` 会被内核忽略**（2026-11 实测，y700 内核线）：`kexec_file_load` 路径由 `of_kexec_alloc_and_setup_fdt()` **重建 live DT**，传入的 `--dtb` 不生效；上游修复 `1537e55728ec` 之后才按参数走。判据：kexec 起来后 `/sys/firmware/devicetree` 与传入 dtb 不符 ⇒ 先查这条，别怀疑 dtb 编错。

---

## 设备侧脚本与取证

并发构建期间重生成版本账/身份表有抓到半写镜像的风险：做法是先改代码与文本、最后再生成，并连续生成两次比对（一致才安装）；生成前用 `pgrep -fa 'make -C .*Image.gz'` 确认是否有构建在跑。 — Failed: 并发 lane 在跑 make Image.gz 时直接重生成表可能纳入不完整产物

---

`scripts/build-kernel.sh` 的位置参数是 **make 目标名**（`Image.gz` / `dtbs` / `modules`），不是抽象 mode：传 `full` 会进 kernel 目录跑 `make full` → `make: *** 没有规则可制作目标"full"`（rc=2，直接失败）。正确用法 = 无参（默认 `Image.gz + dtbs`）或显式 target；含模块需三个目标全传或 `TARGETS="Image.gz dtbs modules"`。 — Failed: Agent 以为 "full" 是脚本预设 mode 名，实际被透传给 make

---

主机侧生成/校验复杂内核迭代脚本时，用 shell heredoc 套 `python3 - <<'PY'` 在脚本里跑 UTS 抽取：`re.search(rb'Linux version [^\x00]{0,120}', k)` 这类正则的转义在多层引号/续行中极易被打散（本次连续 4 次出现 `AttributeError: 'NoneType'`/`SyntaxError: unmatched`/`FileNotFoundError` 只因内容被 shell 截断，非内核问题）。稳妥做法=把 python 片段写成独立文件用 python3 <file> 调用或单引号 heredoc 内不放反斜杠转义。 — Failed: 多层引号+反斜杠转义导致脚本静默损坏，反复误判为抽取逻辑错误

---

C0 真 Android 基线的 root 专属补采项及其现状（backup/HA2EXB0E-16+512/c0-baseline/，U2 a 槽未 root）：`/proc/partitions` = Permission denied（但 `/dev/block/by-name/` 120 项可采，已作块设备证据）；`dumpsys drm` = Can't find service: drm；`sensor-list.txt` 可采（42 传感器，含 icm4x6xa 等）；packages.txt 322 行、getprop-all.txt 1052 行已采。⇒ U1（stock+root）补采的候选项 = /proc/partitions 全表 + 受保护 dumpsys（drm 等）。

---

内核源码树在浅克隆/不可达远端情况下重建 payload 的可靠路径 = 用官方 tarball 做 pristine 基线（cdn.kernel.org linux-7.x.tar.xz）+ 从现存下游树复制 payload + `git commit --allow-empty` 之类方式固化基线，而不是试图 cherry-pick 提交历史。payload 是「树状态差分」不是提交历史——下游树的历史提交在 shallow 仓里可能全部 MISSING（本次 237a1c39e8df/2e28b969d1/24a19b953e/ed6f232d10e3/c7da05b1d8 全部 MISSING），但树可逐字节重建。 — Failed: T3 重放 M1-7.3 线时发现下游历史提交大多不在本地 shallow 仓，只能靠树差分重建

---

内核 payload 重放到 7.3-rc7（cherry-pick 3-way）恰好产生 16 个冲突文件，与 reports/m1-rebase-7.3rc7-execution-20261013.md §2 的处置表逐条对应（dsi_host.c、dsi_manager.c、msm_iommu.c、panel/Kconfig、panel-novatek-nt36536.c、msm_fbdev.c、sound/soc/codecs/Makefile、q6apm-lpass-dais.c 等）。cherry-pick 3-way 会在非冲突文件上也自动合并（fs/crypto/keyring.c、f2fs/data.c、blk-crypto.h 等）——不是因为它们冲突，而是 git 自动合并。裁决口径以该表为准逐文件处理，不凭直觉改。

---

在浅克隆（.git/shallow）的内核仓里不能 push/fetch bundle 或远端 refs（报 `shallow update not allowed`），但可以从本地 worktree fetch：`git fetch <worktree路径> refs/heads/<b>:refs/heads/replay/<b>` + tag。需要旧 tag 树时直接 `git worktree add build/<name> <tag>` 起本地工作树做差分，不必 push。 取新 tag/ref 时另有形态：`拒绝 refs/tags/vkNN 因为浅克隆的根不允许被更新`。要真解浅化用 `git fetch --unshallow`（远端需允许）。

---

## 相机 / HIDL / libcamera

交叉编译 libcamera 的 meson 构建只换 `src/ipa/simple/ipa_soft_simple.so` 即生效：部署到设备 `/usr/lib/libcamera/ipa/ipa_soft_simple.so` 覆盖原文件，`.sign` 不校验（`IPAManager::isSignatureValid` 对开源模块只查存在/可读，RPi 的 .sign 也只是 256 字节占位）。DNS/增量重编只要 0.7s、全量 8.7s。 — Failed: 易误以为需要同步更新签名或整包重装

---

主机自编 HIDL/AIDL external camera service 的工具链坑（2026-10-18 实测，两条合并）：① `hidl-gen`（Ubuntu 包 10.0.0+r36-3.1build1）不能直接用 —— 动态依赖 android-lib{base,log,utils,cutils}，须把 .deb 解到同一 prefix（如 `~/.local/hidlgen`）并设 `LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/android`；`-r` 必须写 `<pkg>:<path>`（android.hardware:hw-interfaces + android.hidl:libhidl/transport），否则报 'must contain :'；含图形/相机两个包时**只能一个 android.hardware 根**（拆成 android.hardware + android.hardware.graphics 报 conflicting package roots）；生成的头要循环跑到数量不再增长（本次 195 个）。② AIDL 必须用 AOSP prebuilts 的 `linux-x86/bin/aidl`（Debian 包太旧不认 `@VintfStability`，prebuilt 缺 libc++.so 时需自带），参数 `--structured --stability vintf`，生成头须落在 `aidl/` 子目录下（源码写 `#include <aidl/android/...>`）否则找不到。③ include 路径分片：`libhidl/base/include`（hidl/）、`libhidl/transport/include`（hidl/LegacySupport.h、HidlBinderSupport.h）、`system/libhwbinder/include`（hwbinder/）、`libfmq/base` + `libfmq/include`（fmq/）、`frameworks-native/libs/gralloc/types/include`（gralloctypes/Gralloc4.h）、`system-core/private/camera/include`（camera_metadata_hidden.h）、`frameworks/native/libs/{utils,nativebase,binder,ui,sync}`。④ 编译用 NDK r25c 的 clang（`--target=aarch64-linux-android33 -std=gnu++17 -fPIC`）；NDK zip 首次解压 bad CRC = 下载不完整，重下后 `unzip -t` 干净。⑤ 产出 = 5 个 aarch64 .so + external-service（17184 B）于 dl-cam/out-cam。⑥ 本机 PATH 里的 `d8` 是 D8 v0.0.1 假货（`d8 --version` 现查），编 dex 要用 AOSP build-tools 的。 — Failed: 自编 camera HAL 期间每一条都真实挡住过编译

---

libcamera 软件 ISP 的 dma-buf provider 选择顺序是硬编码字符串序（`linux,cma` → `reserved` → `system`），不是「找到可用 heap 就用」——只要存在 `reserved` 堆就会被优先尝试，即使它太小；`/dev/dma_heap/system` 存在不代表会被选中。诊断手法：strace -f 看 `openat(/dev/dma_heap/...)` 序列 + `strings libcamera.so.0.7` 找候选表，再看 `dmesg | grep cma` 确认 ENOMEM 来自哪块。

---

手工构建的 HIDL passthrough service 二进制启动后报 `Could not get passthrough implementation for <pkg>::<IFace>/<instance>`：原因是 AOSP 的 `external-service.cpp` 走 `defaultPassthroughServiceImplementation<T>()`，它在服务二进制所链接的共享库里 dlopen 并找 `HIDL_FETCH_<IFace>` 符号，自编出的 `xxx@2.4-external.so` 不保证该符号落在二进制可见范围内。修法 = 额外写一个 shim（如 `external-fetch-shim.cpp`）显式导出 `extern "C" ICameraProvider* HIDL_FETCH_ICameraProvider(const char*)` 并链进服务二进制。 — Failed: 2026-10-18 自编 android.hardware.camera.provider@2.4-external-service 进容器后卡在这一步（service 进程能起、ICameraProvider 拿不到）

---

AOSP external camera HAL（android.hardware.camera.provider@2.4-external）默认只认 `kSupportedFourCCs = {V4L2_PIX_FMT_MJPEG, V4L2_PIX_FMT_Z16}`（UVC 世界假设）——喂它 YUYV 的 v4l2loopback 节点会被整块静默跳过（日志只有 `index:N,ret:-1`，无显式报错），最终表现为 `trimSupportedFormats: input format list is empty!` → `cannot find suitable cropping type!` → `Number of camera devices: 0`。修法 = 在 camera/device/3.4/default/ExternalCameraDevice.cpp 把 YUYV/NV12 加进 kSupportedFourCCs 并补 hasColor 分支（3.5/3.6 是 3.4 的薄封装，只改 3.4 即可）。2026-10-18 实测：改后日志出现 `index:0,ret:0, format:YUYV, w 1280, h 720, framerate 10.000000`，格式解析通过。 — Failed: 排查循环好几次才意识到白名单在最上面（先怀疑 ENUM_FRAMESIZES），因为被跳过的格式没有任何告警

---

「服务 running ≠ 可用」：VINTF vendor manifest 有一处结构错（duplicate `<hal>` 或 duplicate `<interface>` 条目）就**整份作废**，hwservicemanager 报 `VINTF parse error: Illformed file … Duplicated …`，之后所有 vendor HAL 注册失败、事务根本不投递——此时持续崩溃的服务在 `getprop | grep init.svc` 里显示 `running` 是假活。同一 interface 的多个实例必须合并进**同一个 `<interface>` 块**（additionally declared instances），不能拆成两个 `<hal>`。判 provider 是否真的可用看 `dumpsys media.camera` 的 device 计数/实际事务，不能看 init.svc。

---

自编 `ipa_soft_simple.so` 部署到 `/usr/lib/libcamera/ipa/` 后会被包管理覆盖：stock 版 198648 B，自编版（含 s5kjns/gc08a8 CameraSensorHelper + exposureTarget）292640 B。`apk upgrade libcamera*` 或重装 libcamera-ipa 会换回 stock，AE 立刻退回失控（黑帧/过曝）。升级后先用 `stat -c %s` 核大小再测相机，发现变回 198648 B 就重装自编版。

---

## GPT / 分区

GPT 工具的扇区大小口径（两条合并）：`sgdisk`/`gdisk` 对 4 KiB 逻辑扇区的 GPT dump 会当 512B 误读（实测 `sgdisk -p` 报 "Creating new GPT entries in memory"）；`sfdisk --sector-size 4096` 可直接按 4096 解析，要编辑可 `losetup -b 4096 <dump> /dev/loopN` 后交给 sgdisk/parted。而且不要信第一个匹配：内核暴露的 `/dev/sde` 等逻辑扇区为 4096B，而 `blockdev --getsz` 给的是 512B 扇区数（差 8 倍），独立校验 primary+backup 双表必须用分区号索引逐条读。

---

写 GPT（如 qbootctl -m）会触发内核分区重扫，重扫瞬间 `qbootctl -n b` 之类的读取会报 "No slots found" 假故障——这不是 GPT 损坏。判据：/dev/sde* 与 /dev/disk/by-partlabel/* 仍在、dmesg 显示分区重扫无 CRC 错误即可；稍后重读或用独立脚本核对 primary+backup 两张表。 — Failed: GPT 重扫瞬时竞态导致误判为分区损坏

---

## 技能库审计（pi skills）

跨项目「造轮子」审计的有效方法：先 grep 本地 skill references / archive 确认某能力是否已评估过（本轮发现 pmbootstrap/mkinitfs/qbootctl/rmtfs 等生态标准方案本地检索命中为 0 ⇒ 从未纳入候选），再联网做生态对比；判定时区分「代码轮子」（自研 GPT 编辑器/pack.sh/锁逻辑，可 DRY 或换标准工具）与「流程轮子」（PITFALLS #87：不先 grep 本地 skill references 就从业界重推引导链问题，白跑整轮）——后者成本远高于前者。

---

skill 会引用已不存在的外部 CLI/路径而悄然失效（本次实测 MISSING：blogwatcher、blogwatcher-cli、reccli-ts、pymupdf、marker-pdf、nano-pdf、llama-server、vllm、wandb、pygount、GUI.for.SingBox/sing-box；~/.blogwatcher*、~/.config/systemd/user/obsidian-wiki-sync.service、~/Documents/Obsidian、~/firefox-agent 等路径缺失）。核查 skill 时应同时验证其依赖的 CLI/路径是否还在，而不只是看正文。

---

精简 `~/.pi/agent/skills` 时 `rm -rf` 掉了 `mlops/evaluation/` 与 `mlops/inference/`（两条实测合并）：这两个顶层 `SKILL.md` 是 0 字节，只是分类占位，但目录内嵌套了真实子技能（weights-and-biases、evaluating-llms-harness、serving-llms-vllm 各含 SKILL.md + references/），且无 git / 无 trash / profile 副本均已不存在 ⇒ 不可恢复。教训：删技能目录前必须 `find <dir> -name SKILL.md` 或 `ls -R` 逐个核实内容再删；0 字节顶层 SKILL.md 是分类容器的正常形态，不是删除依据。
