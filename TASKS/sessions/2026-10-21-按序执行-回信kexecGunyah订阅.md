# 2026-10-21 · 按序执行六项裁决（回信 / kexec / Gunyah 探测 / f2fs 前置 / 订阅 / 上游 issue）

- **日期**：2026-10-21
- **pi 会话 id**：宿主会话（本文件由编排者写）
- **主题**：按 `reports/{mail-triage,kexec-plan,gunyah-roadmap,f2fs-plan,uefi-restart}-20261021.md` 的下一步顺序执行
- **结论**：6 步里 **5 步已落地**，1 步（kexec 目标进用户态）**拿到关键正结果但未收口**；另有 1 个新踩坑（重启卡死）与 1 个能力缺口（无 sudo 装 f2fs-tools）。

## 1. 执行结果

| # | 动作 | 结果 | 证据 |
|---|---|---|---|
| 1 | 回 Konrad 的 battmgr 澄清 | ✅ **已发并归档**（`<179259054168.209323…@mail.ustc.edu.cn>`，lore `/linux-pm/` 已见） | `reports/artifacts/reply-konrad-battmgr-20261021.txt`；lore 查询命中「Re: [PATCH] … do not report power_now on SM8750」 |
| 2 | kexec 控制组（C1） | 🟡 **重大正结果 + 未收口**：见 §2 | `reports/trials/20261021T141046Z-kexec-c1-initrd-vk134.json`、`…T140642Z-kexec-c1-nokaslr-vk134.json` |
| 3 | Gunyah 阶段 0 探测 | ✅ **阳性**：`/sys/bus/platform/devices/gunyah-wdt` 存在 ⇒ **EL2 上的 hypervisor 就是 Gunyah**（`qcom_scm` UUID 探测命中） | 设备 `ls /sys/bus/platform/devices/ \| grep gunyah` → `gunyah-wdt`（2026-10-21 22:0x） |
| 4 | f2fs 前置：`/init` fstype 通用化 | ✅ 代码已改（blkid 探测 + `elden_rootfstype=` 覆盖 + ext4 兜底）；`sh -n` 通过。**E0（主机 loop）被 sudo 阻断**（`sudo -n` 需交互密码，`f2fs-tools` 未装） | `initramfs/init` §`disk root requested` 段 |
| 5 | 邮件列表订阅动作 | ✅ 3 封请求已发（linux-usb 订阅 / linux-remoteproc 订阅 / devicetree 退订）；确认信**未回**（vger 灰名单，实测曾 5 min） | Sent Items [136][137][138] |
| 6 | 上游 `mu_wide_platforms#12` 回帖 | ✅ 已发 | https://github.com/sunflower2333/mu_wide_platforms/issues/12#issuecomment-6318155640 |

## 2. kexec：Q11 的「能不能用」已被回答 = **能**

**载具** `vk134` = `build/m1-73`（7.3-rc7）工作树 + `patches/kernel-history/elden_vk53-hw/{0019,0020}`（mask=1 旋钮 + `/sys/kernel/kexec_diag`），
`Image.gz` 20 928 610 B；镜像 `out/boot-elden-vk134.img` 85 712 896 B，sha256 `342ff216…`。
**刻意保持 UTS 不变**（`LOCALVERSION=-vk127` ⇒ UTS 仍 `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`），
这样在机 1497 个 `.ko` 的 vermagic 继续匹配，**省掉整棵模块树重编**；代价 = `uname -r` 不能区分 vk134，
判据改用 `/sys/kernel/kexec_diag` 是否存在 + `[KD]` 标记。

**两轮实测（均 `fastboot boot` 零写盘）**：

| 轮 | 目标 cmdline | 串口实际 | 判定 |
|---|---|---|---|
| R1 | 原 cmdline + `nokaslr`，**无 initrd** | `[KD] stage=10…14` → **`Starting new kernel`** → 串口 23 s 后重连，出现**全新 `[0.000000]` 时间线**（reserved-mem 全量 + 到 t=14.9 s 的 vblank trace）；live 内核 cmdline **无 `nokaslr`** ⇒ 目标未进用户态，约 16 s 后自复位回 ABL `boot_b`（与 `panic=15` 时标吻合 = H9） | **MID**（交接机制成立，目标确实起过） |
| R2 | 同上 + **Alpine ramdisk 64 MB**（sha `4d4834e6…`，与在机 vk127 同一份） | 同样到 `Starting new kernel`；串口 32 s 后重连、新时间线只有 vblank trace + `~ #`；live 仍无 `kexec_diag`、cmdline 无 `nokaslr` ⇒ 仍回 `boot_b` | **MID** |

⇒ **掉电规避（整段跳 `device_shutdown`）在 7.3 上成立**，交接走到 `machine_kexec` 之后；历史「跳转后 ~20 s 回 boot_b」现在有了机制解释（不是没跳，是跳过去活不下来）。
**未解**：目标为何在 R2（有 initrd）仍进不了用户态。首选假设仍是 **H1（SMMU 残留 stream 把目标早期内存踩坏）**，其次是 initrd 落点/大小问题；
下一步单变量是报告 §C 的 **C5（目标 cmdline `arm-smmu.disable_bypass=1`）**，一轮 ≤10 min、零写盘。

## 3. 新踩坑：显示/GPU 故障态下 `reboot2 bootloader` 会卡死

本次两次用 `eldroid-bootctl/reboot2 bootloader` 从 SSH 切 fastboot，**设备黑屏、`fastboot devices` 无响应，需用户手动重启**（第三次在干净启动态下 2 s 就进了 fastboot）。
事后串口显示该次 boot 之前已有 `msm_dpu … hangcheck recover!` + `gpu fault: … source=CP` ⇒ 与既有链**「DRM cleanup 卡住 ⇒ PSCI vendor reset 不执行」**一致（Q28 那条老链同源）。
**规避**：切 fastboot 前先看一眼 `dmesg | grep -cE 'hangcheck recover|gpu fault'`；非 0 就直接请用户手动重启，别连试。

## 4. 未做/受阻

- **E0（主机 f2fs loop 实验）**：`sudo` 需要交互密码 ⇒ `apt install f2fs-tools` 没跑成。需要用户执行一次：`sudo apt install -y f2fs-tools`。
- **订阅确认信**：发信后 5 min 内未到，需下一轮 `read-mail-ustc.py --days 1 --grep 'confirm,Welcome'` 跟进并回 Confirm（vger 灰名单）。
- **f2fs E1（只换 initramfs 零写盘验证）**：本次只改了仓库 `initramfs/init`，**在机 ramdisk 未重建**（重建会连带引入 16 行 `payload-modules-load` 预热段，需按单变量单独设计）。

## ★SSOT 待并入

- `TASKS/README.md` §2 **C8**：状态改为「**hyp = Gunyah 已实证**（`gunyah-wdt` 平台设备），驱动仍缺」（原「存在性未测」作废）。
- `TASKS/README.md` §4 第 10 条（kexec）：补一行「**2026-10-21 实测：mask=1 在 7.3 成立，到 `Starting new kernel`；目标未进用户态（R1 无 initrd / R2 有 initrd 都回 boot_b）⇒ 下一步 C5 单变量**」。
- `PITFALLS` §19（重启通道）：新增一条「显示/GPU 故障态下 `reboot2 bootloader` 卡死，需手动重启；切前先查 `hangcheck recover|gpu fault` 计数」。
- `TASKS/README.md` §4 T13 行：把「kexec 建议动手」改为「已动手，见本节 §2」。
