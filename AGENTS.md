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
- b 槽不是裸写：`scripts/sign-boot-b.sh`（`bootslot-b/avb.key` + `tools/avbtool.py`）签成 96 MiB 后 flash，读回 sha 必须逐字一致。
- RAM 起自编内核（`fastboot boot`）前必须先部署 `/lib/modules/<新UTS>`（1497 个 .ko ≈85M）→ 否则 lsmod 空、DP 控制器 defer、无 card0、看门狗 84.9s 重启；判据顺序 = lsmod 条数 → `dmesg | grep 'bound ae94000.dsi'` → 再看 L1 签名。
- Q28 坏发不污染 Q24/相机结论：7.3 线累计 30 发存活、vk64 线 1 死/2 发 → 显示态是协变量不是判别量。诊断前先 `scripts/q28-watchdog.sh off`。
- 内核构建必须走 `scripts/build-kernel.sh`（ARCH=arm64、CROSS_COMPILE=aarch64-linux-gnu-）：裸 make 会按宿主 x86 重写 .config；LOCALVERSION 叠加报 `exceeds 64 characters` = include/config 残留。
- 双层压缩陷阱：boot 分区 kernel 载荷本身是 gzip，再包 Image.gz → ABL 解一层拿到 gzip 流、卡联想 logo；判据 kernel payload magic `1f8b 0800`（好）vs `1f8b 0808`（坏）。
- kexec 取证：`--dtb` 对 kexec_file_load 是空操作；ttyGS0 在 kexec 时必断；ramoops@c2000000 缺 record-size/max-reason 才拿不到跨 kexec dump。
- 设备侧脚本必须 POSIX sh：整文件 `scp` 到 /tmp 再 `sh /tmp/x.sh`，禁长 inline ssh 单引号/多行块；busybox `pgrep -x` 恒假阴性 → 用 `ps -eo comm | grep -cx NAME`。
- `pkill -f`/`pgrep -f` 会自匹配打死自己的 shell → 模式写字符组（`[t]tyACM`）+ `grep -vw $$`，先 `pgrep -af` 只列不杀。
- 不要在本机平板上编译（过热 → 断电重启到 BL）：内核用 aarch64-linux-gnu，musl 用户态用 `~/toolchains/aarch64-linux-musl-cross` + 设备 sysroot。
- `.pi/trash/` 受 harness 保护不可 rm；删 `build/*` 前逐棵 `git bundle --all` 并同步改 `patches/current-tree`、让 check-doctor 动态发现 `build/*/.config`。
- PITFALLS 编号只补不重排；PITFALLS 正文行首 `N. ` 会被当成条目定义 → 有序列表写 `- **…**`；条目标题必须含 `## #NNN`。
- 内核仓 geekidos-linux 是浅克隆：`git fetch`/bundle 一律被拒 → 从本地 worktree `git fetch <wt> refs/heads/...`，或 `git worktree add build/<tag>-tree` 做文件级差分。
- 顶层布局登记：每个根目录条目先进 `versions/layout.tsv` + INDEX §2 同源渲染，门 = `scripts/check-layout.sh`。
- 「收尾」= 产物落盘 + SSOT 同步（INDEX/TASKS/DEVICE/PITFALLS）+ 设备安全态 + check-doctor FAIL=0/WARN=0 + 工作区 clean；文档不得要求 AI 写 summary。
- 子代理网关 = nexavlinks（`custom-nexavlinks-com` / `deepseek-v4.1-flash`），不走 ustc-pool；2026-10-15 起允许 agent 直接 flash。
- EDL 工具链单根 `~/edl/`：`qdl`（刷写主力，无 printgpt）、edl-ng（GPT 取证 `printgpt -u 4`）、bkerler（peek 备胎，不作写路径）。
- 细节**不放这里**：显示/相机/Waydroid/刷写/寄存器级判据见 `.pi/memory/notes-display.md`、`failures-device.md`、`failures-kernel.md`。

## 细节

- vk127 baseline / 相机 AE / Waydroid 固化 / EDL / layout / git 修复的成对事实与脚本指针：`.pi/memory/MEMORY.md`。
- 94 条设备侧细粒度坑（Alpine/busybox、Waydroid 容器状态机、codec/audio/camera、SSH 部署）：`.pi/memory/failures-device.md`。
- 355 条刷机/AVB/kexec/EDK2-Mu/UEFI/内核打包证据与寄存器级细节：`.pi/memory/failures-kernel.md`。
- 协作口径（物理 POR、目视纠正、按字母顺序执行、电话/观测节奏）：`.pi/memory/USER.md`。
