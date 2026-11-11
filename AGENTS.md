# y700-elden — 项目说明

> **项目描述只在本文件。** 做事规范见 **`.pi/AGENT-OPS.md`**（agent 行为/授权唯一入口）；
> 踩坑经验见 **`PITFALLS/README.md`**（开发经验唯一入口）；文档地图与状态见 **`INDEX.md`**（唯一入口）。

**机型唯一**：联想拯救者 Y700 四代 = **TB322FC** = 代号 **elden** = SoC **SM8750(P)**。
研究面 = **让这块板子在主线 Linux 上功能完整**（固件/驱动为主；刷写只是手段）。

## 目标（按优先级）

- **G1 完整 Linux + 上游化**：主线 Linux **功能特性完整**，**正确驱动全部原厂固件**（ADSP/CDSP/WCN7861/GPU/触屏/触觉/功放/tplg/相机…）。
  代码达到上游规范后**按模块向上游提交**（checkpatch/DTC/`dtbs_check` 绿；分级与顺序见 `TASKS/README.md` §7 的 M 系列，以 §7 为准）。
- **G2 安卓容器**：**不依赖 Android 宿主**运行安卓应用（主路线 Waydroid，备胎 redroid）。
  核心验收 = **可用性 + 风控/完整性等级**：GMS 登录、**Play Integrity / SafetyNet**、Widevine 能做到哪一级
  （**取证判定，不预设"不可能"也不承诺**；见 `RESOURCES/README.md` §1.3、`TASKS/README.md` §5 Q1/§6）。
- **G3 x86 模拟运行**：以 **Steam 游戏**为验收载体，跑通 x86 用户态/游戏（Box64 + Wine/Proton 线）。
- **拓展（非主线，不阻塞 G1–G3）**：**UEFI 间接引导**、**Gunyah 高通虚拟化做 VM**。现状/裁决见 `TASKS/README.md` §4/§5、`archive/topics/`。

## 核心原则

- **设备等价**：同型号多台单元**物理地位完全等价**，唯一差异 = 容量；身份 = **(SN, hwboardid, 容量)**（`DEVICE/README.md`）。
  任务按单元**当前状态**分派，产出必须**设备无关**（运行时读实际 GPT/DT）。设备称 **U1 / U2**。
- **存储**：Linux 容量按项目体量一次给足（`DEVICE/README.md` §3），扩容首选回收 Android 专属分区；不写死配置。
- **文档 SSOT**：唯一入口 `INDEX.md`；分层与清单见 `INDEX.md` §2。
- **构建限并发**：主机 28 线程，但**编译一律保留 2 个 P 核给交互** ⇒ `make -j26` 起步（内核/模块/大型构建都一样，别用裸 `-j`）。
- **上游发信（2026-10-31 用户授权，已实测一次）**：**允许 agent 代写回信/cover**（含回应维护者「not with LLM」那类线程），**前提三件**：
  ① 开头如实披露 AI 辅助（作者本人校对；内容/测量/决定归作者）；② 每条论断附可复现证据（引用 + 命令/数据）；③ 逐条回应 reviewer 意见，不遗漏、不说套话。
  投递仍按 `TASKS/README.md` §7「按系列逐次批准」；范例 = `out/mail-20261031/{re-krzysztof-wl2868c.txt,claims.tsv,self-review.md}`（Sent[207]）。

---

> API 限流 / 模型选择见全局 `~/.pi/agent/AGENTS.md`「API 网关与限流」（本文件不重复）。

## 项目记忆（2026-11-11 整理）

- 版本账耦合：`versions/vk-kernel-identity.tsv` 的 image 列只有 basename，check-doctor §5d 拿「现扫 `out/*.img` 生成的表」逐行比对 → **禁重跑 `scripts/vk-identity.py`**（镜像缺失会清空整表）；清镜像只能走 `scripts/out-archive.py`（默认 dry-run），不直接删文件。
- boot.img 打包用 `scripts/mkbootimg.py`（v2 头，pack/unpack/--selftest）：magic `ANDROID!`、name@48、cmdline@64、id@576（20B sha1 必须补零到 32B）、header_size=1660；ramdisk 可从基线 boot_b 原位抽。
- b 槽不是裸写：`scripts/sign-boot-b.sh`（`bootslot-b/avb.key` + `tools/avbtool.py`）签成 96 MiB 后 flash，读回 sha 必须逐字一致。
- RAM 起自编内核（`fastboot boot`）前必须先部署 `/lib/modules/<新UTS>`（1497 个 .ko ≈85M）→ 否则 lsmod 空、DP 控制器 defer、无 card0、看门狗 84.9s 重启；判据顺序 = lsmod 条数 → `dmesg | grep 'bound ae94000.dsi'` → 再看 L1 签名。
- Q28 判据：GOOD = `L1=0` + `dsi_isr=41` + card0-DSI-1 connected + dmesg `panel prepared: scheduling firmware upload`；BAD 含 `command DMA timeout: status=0x2200200` / `bonded ... master=-110 peer=-110` / `dcs data ff 20 failed: -110 或 -5`。坏发按会话成簇，软件 reboot 不解除，只有真 POR 能恢复。
- Q28 坏发不污染 Q24/相机结论：7.3 线累计 30 发存活、vk64 线 1 死/2 发 → 显示态是协变量不是判别量。诊断前先 `scripts/q28-watchdog.sh off`。
- 桌面/熄屏判据：`/sys/class/drm/card0-DSI-1/dpms` 是 0644 只读、写入需 ~2.5s 生效 → 必须带延时 + 回读校验，否则整轮样本是假 INVALID-NO-BLANK；判桌面在不在要抓帧看亮度，不能只看 pgrep phoc。
- 冷起无桌面根因 = greetd 崩溃 → initd 补 `after seatd elogind` + 交给 `supervise-daemon` 托管；应急旁路 `setsid /usr/sbin/greetd --config /etc/greetd/config.toml ... &`。
- M1-7.3 内核重放 = 7.3-rc7(`24a19b953`) + payload v2（**取 vk64 树**）+ 上游 `PLL_SYSTEM_MUXES` → 稳定 16 个冲突；DTB 保真判据 = `sm8750-lenovo-elden.dtb` 153101 B 与基线相同、仅剩 q6apm/q6prm 8 行差异；资产 `patches/replay-2026-10-17/`。
- 内核构建必须走 `scripts/build-kernel.sh`（ARCH=arm64、CROSS_COMPILE=aarch64-linux-gnu-）：裸 make 会按宿主 x86 重写 .config；LOCALVERSION 叠加报 `exceeds 64 characters` = include/config 残留。
- 双层压缩陷阱：boot 分区 kernel 载荷本身是 gzip，再包 Image.gz → ABL 解一层拿到 gzip 流、卡联想 logo；判据 kernel payload magic `1f8b 0800`（好）vs `1f8b 0808`（坏）。
- kexec 取证：`--dtb` 对 kexec_file_load 是空操作；ttyGS0 在 kexec 时必断；ramoops@c2000000 缺 record-size/max-reason 才拿不到跨 kexec dump。
- a 槽跑自研件卡 logo = 原厂 `dtbo_a` 的 Android DTBO 被 ABL 合进我们的 DTB → `truncate -s 33554432` 全 0 刷 dtbo_a（`scripts/uefi-a-slot-prepare.sh`）；判槽不能看 `androidboot.slot_suffix`（boot.img 头烤死 `_b`），要在 cmdline 埋唯一标记。
- 设备侧脚本必须 POSIX sh：整文件 `scp` 到 /tmp 再 `sh /tmp/x.sh`，禁长 inline ssh 单引号/多行块；busybox `pgrep -x` 恒假阴性 → 用 `ps -eo comm | grep -cx NAME`。
- `pkill -f`/`pgrep -f` 会自匹配打死自己的 shell → 模式写字符组（`[t]tyACM`）+ `grep -vw $$`，先 `pgrep -af` 只列不杀。
- 设备失联判读：enx 接口消失 + `lsusb` 出现 `18d1:d00d` = 在 fastboot → `fastboot reboot` 零写盘恢复。
- 设备时钟停在 1970 ⇒ HTTPS 全 rc=60、apk 报 index 无效；校园网把 HTTP 劫持到 202.141.180.1 → 先 `date -s`/time-sync，apk 走 https 或宿主中继；`ssh -R 7890` 会失败，用主机 python 中继。
- `fastboot fetch` 是幻觉（本机 ABL 不支持）→ 分区备份只有三条路：设备侧 `dd if=/dev/disk/by-partlabel/<part>`、EDL(9008)、已有副本。
- Waydroid 走 OpenRC 非 systemd：`rc-service waydroid-container start` → `waydroid session start`；Q28 坏态无 phoc 用 `scripts/waydroid-headless-start.sh`（weston headless + session dbus）。
- 容器 codec list=0 的真根因 = waydroid `lxc.py` 硬编码 `debug.stagefright.ccodec=0` → `waydroid prop set debug.stagefright.ccodec 4`（得 53 个 codec）。
- vendor.img：`resize2fs` 只扩块不扩 inode（496 inode 恒满）→ 必须 `mke2fs -N 8192` 重建并 `sif` 改属主 0:2000；容器内文件覆盖优先 LXC bind-mount。
- 容器 HAL A/B：自编 64bit camera provider 注册成功但首笔 binder 事务 SIGSEGV → 属容器/HIDL-ABI 层；资产 `patches/waydroid-camera-64bit-20261018/`。
- 相机判真出流看 STREAMON rc + 字节数，不看首帧均值；后摄「黑」= libcamera 0.7.1 缺 s5kjns/gc08a8 `CameraSensorHelper` + pedestal 4096 未扣 → `patches/camera-ae-fix-20261017/`（AGC exposureTarget 可调，yaml 设 0.22）；真实持续帧率 30 fps。
- 相机故障分层：`CSID reset timeout` / `Failed to power up pipeline: -110` = CSID/VFE 复位失败；`media-ctl ... Resource busy (16)` = 上次 stream 未释放，需重载 camss 模块（先 `killall wireplumber`）。
- 不要在本机平板上编译（过热 → 断电重启到 BL）：内核用 aarch64-linux-gnu，musl 用户态用 `~/toolchains/aarch64-linux-musl-cross` + 设备 sysroot。
- 主机静默损坏史：镜像/产物 sha 一律 `dd iflag=direct` 复算；`git fsck` 一律 `--full`；`echo 3 > /proc/sys/vm/drop_caches` 在本机直接卡死自动重启。
- `.pi/trash/` 受 harness 保护不可 rm；删 `build/*` 前逐棵 `git bundle --all` 并同步改 `patches/current-tree`、让 check-doctor 动态发现 `build/*/.config`。
- PITFALLS 编号只补不重排；PITFALLS 正文行首 `N. ` 会被当成条目定义 → 有序列表写 `- **…**`；条目标题必须含 `## #NNN`。
- 内核仓 geekidos-linux 是浅克隆：`git fetch`/bundle 一律被拒 → 从本地 worktree `git fetch <wt> refs/heads/...`，或 `git worktree add build/<tag>-tree` 做文件级差分。
- 顶层布局登记：每个根目录条目先进 `versions/layout.tsv` + INDEX §2 同源渲染，门 = `scripts/check-layout.sh`。
- 「收尾」= 产物落盘 + SSOT 同步（INDEX/TASKS/DEVICE/PITFALLS）+ 设备安全态 + check-doctor FAIL=0/WARN=0 + 工作区 clean；文档不得要求 AI 写 summary。
- 子代理网关 = nexavlinks（`custom-nexavlinks-com` / `deepseek-v4.1-flash`），不走 ustc-pool；2026-10-15 起允许 agent 直接 flash。
- 设备侧抢资产：`ssh root@<ip> 'tar -C / -cf - <绝对路径> | zstd'`（必须绝对路径 + `-C /`），解压后 sha 双端对账。
- EDL 工具链单根 `~/edl/`：`qdl`（刷写主力，无 printgpt）、edl-ng（GPT 取证 `printgpt -u 4`）、bkerler（peek 备胎，不作写路径）。
- 用户口径：优先「尽可能利用上游、减少下游补丁」；多变量连续失败立即停手归档；可能阻塞的命令一律 `timeout -k`；用户目视/体感报告优先于脚本读数。

## 细节

- vk127 baseline / 相机 AE / Waydroid 固化 / EDL / layout / git 修复的成对事实与脚本指针：`.pi/memory/MEMORY.md`。
- 94 条设备侧细粒度坑（Alpine/busybox、Waydroid 容器状态机、codec/audio/camera、SSH 部署）：`.pi/memory/failures-device.md`。
- 355 条刷机/AVB/kexec/EDK2-Mu/UEFI/内核打包证据与寄存器级细节：`.pi/memory/failures-kernel.md`。
- 协作口径（物理 POR、目视纠正、按字母顺序执行、电话/观测节奏）：`.pi/memory/USER.md`。
