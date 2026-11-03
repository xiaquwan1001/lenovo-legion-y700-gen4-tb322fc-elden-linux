# 外部发现扫描：SM8750(P)/Pakala UEFI 引导 Linux — 2026-11-03

Lane：外部发现 · 时间盒 15 分钟 · 检索日期 2026-11-03
判据：只收「有出处的新发现」(URL+日期)；无出处推测标「未证实」。

## 1 UFS/SMMU 上游（Mu-Silicium / mu_wide_platforms / UfsDxe）

（待填）

## 2 同芯片设备案例（OnePlus Pad 3 / Xiaomi Pad 7 Ultra / Tab S10 / 红魔等）

（待填）

## 3 内核侧替代路线（kexec / U-Boot via ABL fastboot / boot-image v4 大 payload）

（待填）

## 4 无新发现项

（待填）

### 1.1 UniXNU-dada（Xiaomi 15, SM8750）— Mu-Silicium UFS 已通（新发现，未标日期）
- URL: https://github.com/7Night-kqx/UniXNU-dada
- 「Mu-Silicium boots dada to a framebuffer, a UEFI menu, UFS and USB device mode」——即小米 15 (SM8750) 上 Mu-Silicium 的 **UFS 已初始化成功**（与本项目 UFSDxe/SMMU 卡点直接相关）。仓库自述 work-in-progress，commit 日期待核实。

### 1.2 UniXNU-Pagani_SM8750（OnePlus 13T pagani）UEFI 侧存在
- URL: https://github.com/IssacL04/UniXNU-Pagani_SM8750
- 含 `Platforms/OnePlus/oneplus13tPkg`（Mu-Silicium 结构），有 payload_host 测试构建；具体 UFS/引导进度未证实。

### 1.3 OnePlus Pad 2 Pro（erhai/OPD2413，SM8750P）UniXNU 设备仓（新）
- URL: https://github.com/wally001012-cyber/UniXNU-erhai 、 https://github.com/xuqian-git/UniXNU-erhai
- 结构派生自 IssacL04/UniXNU-Sun_SM8750（一加 13T，同 SM8750/"sun" 平台），目标是把 XNU payload 送入 UEFI 入口（S1..S6 里程碑）；配置里「无 UFS/AES/GPU」——即 XNU 路线暂不依赖 UFS。日期待核实。

## 3 内核侧替代路线

### 3.1 U-Boot 经 ABL 以 Android boot image 加载（通用文档，非 SM8750 新增）
- URL: https://docs.u-boot.org/en/stable/board/qualcomm/board.html
- 上游 U-Boot stable 文档：支持以 Android boot image 形式经高通 UEFI ABL 加载（DTB 追加在 U-Boot 镜像后）。属既有通用机制，未发现 2026-10 后针对 SM8750 的新增支持记录。
- Linaro 初始发布公告（2024-08）：https://www.linaro.org/blog/initial-u-boot-release-for-qualcomm-platforms/ （旧闻，仅作背景）。

### 3.2 Android boot image v4 头 + 大 payload：UniXNU-dada 已有验证补丁（新）
- URL: https://github.com/7Night-kqx/UniXNU-dada
- 仓库含 `docs/patches/unixnu-bootimg-header-v4.patch`（「Adds the v3/v4 verification path」），即在 SM8750 设备上做 boot-image v3/v4 头校验路径 + embed_payload 的具体实践，可作本项目大 payload 绕过 ABL 校验的参考。

### 1.4 UniXNU-dada README 细读（2026-10-27 最后 commit）——对本项目最相关的硬信息
- URL: https://github.com/7Night-kqx/UniXNU-dada （最后 commit 2026-10-27）
- **UFS 已在 Mu-Silicium 侧工作**：Stage 1「UEFI firmware, framebuffer, menu, UFS, side buttons, UART7 — works in Mu-Silicium (Mu-dada.img)」；但 Stage 6 UFS root 仍需 `qcom,sm8750-ufshc` binding。作者另有 UFS 观察记录 `edk2-msm/ufs-info-dada.txt`。
- **boot image v4 大 payload 具体方案已 host 侧验证**：BootShim(112B) + gzip(0x300000 FV) + DTB(966,281B)，Android v4 头共 2,195,456 B；`fastboot boot` 尚未在真机运行。
- 已知缺口：GPU(Adreno 830 无驱动)、USB host role switch 在 SM8750 不工作、触屏/WiFi/BT/音频全无。

## 2 同芯片设备案例

### 2.1 OnePlus 13T（pagani）/SM8750：UniXNU-Pagani_SM8750（新，活跃）
- URL: https://github.com/IssacL04/UniXNU-Pagani_SM8750 （最后 commit **2026-11-02**）
- 含 oneplus13tPkg（Mu-Silicium 结构）+ BootPayloadDxe 测试；是把 UniXNU/DarwinBoot 接入 SM8750 UEFI 的活跃工作。Linux/Windows 引导未见证实。

### 2.2 OnePlus Pad 2 Pro（erhai/OPD2413，SM8750P）：两个 UniXNU 设备仓（新）
- URL: https://github.com/wally001012-cyber/UniXNU-erhai （最后 commit **2026-10-22**）、fork: https://github.com/xuqian-git/UniXNU-erhai
- 平板同芯片（SM8750P，与 TB322FC 同平台家族）；派生自 UniXNU-Sun_SM8750；defconfig「无 UFS/AES/GPU」。
- OnePlus Pad 3 / Xiaomi Pad 7 Ultra / Tab S10 未见 2026-10 后 UEFI 新进展（XDA Pad 3 Windows 双系统帖为 2025-08 旧帖）。

## 4 无新发现项

- **UFS SMMU / UFSDxe 上游 commit/issue/release（2026-10 后）**：未检索到 Mu-Silicium 主仓（Project-Silicium/Mu-Silicium）针对 SM8750 UFS 的新 release/commit 公告；dada 仓仅证实「UFS 在其固件里已工作」，具体驱动来源待进一步核对（未证实）。
- **kexec / GRUB-as-kexec 路线**：无 2026-10 后新出处。
- **U-Boot SM8750 专属支持**：无；上游文档仍为通用 Qualcomm ABL 加载流程。
- **SteamOS-ARM-Port Issue #75（SM8750 Pakala low-level boot 报告）**：约 2026-10 中发布，但属分析汇编报告而非可复现 bring-up（URL: https://github.com/hashtagbasit/SteamOS-ARM-Port/issues/75），仅作参考。
