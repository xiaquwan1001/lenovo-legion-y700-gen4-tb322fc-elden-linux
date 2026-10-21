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

## 5. 追加：C5 单变量（`arm-smmu.disable_bypass=1`）两轮 —— 仍不存活

| 轮 | 目标 cmdline | 结果 | trial |
|---|---|---|---|
| C5 | `disable_bypass=0→1` + initrd + `nokaslr` | 到 `Starting new kernel`；串口 32 s 后重连，目标新时间线后又丢 **65 104 B**；live 无 `/sys/kernel/kexec_diag`、`/proc/device-tree/chosen/` **无 `linux,booted-from-kexec`** ⇒ 回来的不是目标 | `20261021T143106Z-kexec-c5-bypass1-vk134.json` |
| C5b | 同 C5 + `quiet loglevel=4`（降串口丢包） | 同上仍回 boot_b；`/sys/fs/pstore/` **无 recovered 记录**（ramoops 已注册但没留下目标的东西） | `20261021T143106Z-kexec-c5b-bypass1-quiet-vk134.json` |

**判读**：
- **H1（SMMU 残留 stream 直通踩内存）单变量未救活** ⇒ bypass=1 不是解；H1 既未证实也未排除（改成 FAULT 也许只是把踩内存换成 fault 风暴）。
- **`linux,booted-from-kexec` 是本轮新加的确定性判据**（比 `uname` 有效，因为 UTS 刻意相同）：目标活着就一定有该属性。C5/C5b 均无 ⇒ **目标未存活到用户态**（或存活极短）。
- **可见性仍是唯一硬阻塞**：115200 的 gadget console 在开机最吵的 20–40 s 里会丢 65 KB（连 panic 都丢），而 pstore 没接住。下一轮必须先解决观测：报告 §D3 的「第二个 ramoops 节点只给目标用」或把 console 降到 `quiet loglevel=3` 并用独立串口文件。
- **另加一条设备纪律（已写入本次踩坑）**：`SysRq-b`（`echo b > /proc/sysrq-trigger`）在 DRM 楔死态下能干净冷启（实测 0 hangcheck、DSI enabled），是 `reboot2 bootloader` 卡死时的正确逃生口。

## 6. 观测改造 + 本轮设备实测（23:00–23:30）

**新增 opt-in 观测（`initramfs/init`，仅在 cmdline 显式打开时生效）**：
`kexec_marker=1` → 挂 `kexec_marker_dev`（默认 /dev/sda17，含 20 s 等设备节点）→ 写 `/var/tmp/kexec-marker.txt`（uptime/kernel/UTC/cmdline）；
`kexec_marker_reboot=1` → 写完 `reboot -f` 自回默认槽。目的：kexec 目标在纯 RAM initramfs 里**没有可用观测面**（无 NCM 地址、console gadget 太晚枚举），
该文件是"目标确实执行过 init 代码"的持久证据，且能让设备自己回到可达状态。

**本轮实测（4 轮，每轮 `fastboot boot vk134` 零写盘）**：
| 轮 | 目标 initrd | 观察 | 判定 |
|---|---|---|---|
| slim（无标记） | 1 MB busybox | 串口静默、SSH 不通、fastboot 不通，但 **USB gadget 在 23:14 重新枚举**（新 `/dev/ttyACM0`+`ACM1`） | 【推测】目标活着停在 initramfs（ABL 回 boot_b 的话 SSH 必通）；无法直证 |
| slim v2（blkid 缺 applet） | 1 MB | 无标记文件 | 标记块执行了但 `blkid` 不存在（slim 无该 applet）⇒ 改显式设备 |
| slim v3（含等节点） | 1 MB | 无标记文件，设备掉电重启（用户目视） | 仍未取到标记；`/dev/sda17` 或许在那一刻还没枚举完 |
| 全 rootfs（R2/C5） | 64 MB | 回 boot_b，无 `linux,booted-from-kexec` | 【已证实】未存活到用户态 |

**结论口径**：`kexec` 到 `Starting new kernel` 100% 成立（4/4）；**目标内核是否进入用户态仍未证实**（正证据只到"gadget 被重新初始化"这种间接层面）。
下一步若要收口，必须先让目标可观测，优先级：① 标记文件（已实现，等一轮干净复跑）；② 目标专用第二个 ramoops（DTS 8 行）；③ 硬件 UART（不具备）。

## 7. f2fs E0 主机实验（已完成，含关键限制）

镜像：`/home/xuqianhui/f2e0.img`（8 GiB, loop0），`mkfs.f2fs -O extra_attr,inode_checksum,sb_checksum,compression`，挂 `/mnt/f2`。

| 项 | 结果 |
|---|---|
| mkfs / fsck | format successful（overprovision 1.67%、GC 预留 66 段）；`fsck.f2fs -f` **0 错误** |
| 4K+fsync ×200 @3% 占用 | avg **6.046** ms / p50 6.009 / p95 6.123 / max 10.2 |
| 顺序写 512 MiB + fsync | 0.36 s（≈1.5 GB/s） |
| 填盘到 100% | 7.8 GiB / 4.3 s 后 `ENOSPC`（符合 f2fs 预留语义） |
| 4K+fsync ×200 @93.2% 占用 | avg **6.053** ms / p95 6.144 ⇒ **无退化** |
| `free_segments` @93% | 342（GC 仍有充足余量） |

**限制（必须写进结论，别当性能结论用）**：台架是 **loop 文件叠在 NVMe/ext4 上**，6 ms 地板由 loop+host fsync 决定，不是 f2fs 本身；
且 342 个空闲段意味着**没触发高利用率 GC 悬崖**（文献那套 97.5%→−30% 需要持续写入把 GC 逼到回收站）。⇒ E0 只证明「工具链/参数/挂载语义正常」，
不能证明「f2fs 在这颗 UFS 上快/慢」。要测 GC 必须上跑真块设备（E2，有写盘风险）。
