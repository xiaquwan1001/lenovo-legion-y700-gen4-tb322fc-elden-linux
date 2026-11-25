# Gunyah 线：静态推进（主机侧，2026-11-26）

> **派工**：lane G —— gunyah 静态推进。硬约束：**零设备写**（本轮对设备只做只读 ssh：`uname -r` / `ls` / `cat` / `dmesg`；
> 未 `insmod`、未 `fastboot`、未写任何槽/分区）、**不发邮件**、不改 `TASKS/README.md` 正文、不 commit。
> **本轮唯一写入路径** = 本文件。
> **取证窗口**：`2026-11-25T22:07Z – 22:22Z`（CST 2026-11-26 06:07–06:22）。下文的「时间」一律 UTC（+08 = CST）。
> **口径基线**：`TASKS/README.md` §2 行 C8、§4.0 行 D7/D19、§4 N2（已下沉 `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-19/§4-20）、
> §5 行 Q4、§7 行 M9；报告 `gunyah-decision-20261025.md`、`gunyah-restart-assessment-20261111.md`、`d19-gunyah-wdt-20261125.md`、
> `gunyah-612-samebuild-20261025.md`、`gunyah-73-port-20261112.md`、`gunyah-b15-iceland-rmdrv-20261113.md`。

---

## §1 一页结论

### 1.1 三句话

1. **「本 firmware 下用主线 `drivers/virt/gunyah` 自建子 VM」= 已结项，不再投入**（2026-10-25 终局裁决；2026-11-11 改「有条件重启」，
   但两个条件至今未满足：C2 = 本机 Lenovo 固件的 RM 策略未测、C3 = 用户未确认「一定要在本机跑 Linux/Windows 子 VM」）。
2. **`gunyah_wdt` 这条 D19 解 = 已证否并归档**：2026-11-25 20:1x 上机实测驱动能绑、SMCCC 全返回 0，但 `GUNYAH_WDT_STATUS`
   的秒数恒 0、停喂 45 s 不复位 ⇒ **本机 hyp 侧是空实现**；并且**该驱动早已在主线**（本轮再核，见 §2 F7/F9/F10）⇒ 既没有
   「上游化」价值，也不能当看门狗用。
3. **本机 gunyah 唯一还活着的资产是「素材」，不是「代码在跑」**：`drivers/virt/gunyah` 仍不在 torvalds/linux-next（§2 F6），
   我们手里的 g612/piano/iceland 代次 + 移植方法学在仓里（§2 F13），但**移植工作树 `build/gunyah-port` 与 `out/gunyah-73`
   已在 2026-11-25 磁盘清理中消失**（§2 F13/L5）⇒ 任何「上机读回」都先要重建（半天级），不是「翻出来就能跑」。

### 1.2 现在能做 / 不能做 / 最小下一步

| | 内容 | 成本 | 依据 |
|---|---|---|---|
| **能做（本轮已做）** | ① 上游现状内容级复核（virt/gunyah 无、gunyah_wdt 有、SCM 第二个 UID 未合入）；② 本机候选件与在机内核的同源性核对（**非同源**）；③ 仓内素材清单 + 缺口（移植树已删） | 0（只读） | §2 |
| **能做（下一步，主机侧）** | 把 g612/piano 素材按 §7 纪律拆成**可独立 review 的 G1 补丁素材包**（不含 vendor hook 的模块优先：`vm_mgr` / `vm_mgr_mem`） | 1–2 天（**需先重建移植树**） | §3-A |
| **能做（下一步，设备窗）** | **一次上机读回**把 C2 变二值：`/dev/gunyah` 出现 + `gh_vmtest` 的 `VM_START` 是否 0；若仍 `0xA` 再喂违规 DTB 看是否变 `8` | 主机 ~1 h + 设备 ~30 min（+重建树半天） | §3-B |
| **不能做** | ① 不在设备窗内判定 C2（纯静态已到顶：10-25/11-11/11-13 三轮把能静态判的都判完了）；② 不投 `drivers/virt/gunyah`（**没有接收面**：主线无目录、无 maintainer 入口、无在审系列）；③ 不用 `gunyah_wdt` 解决 D19 hang 类实验 | — | §2 F6/F9/F11、`d19-gunyah-wdt-20261125.md` 附节 |

### 1.3 「已结项」与「有条件后续」的分界（写死，避免下一轮重复判）

| 子线 | 状态 | 判据来源 |
|---|---|---|
| Gunyah 子 VM（本 firmware / 主线驱动 / RM 路径） | **已结项**（终局裁决 + 11-11 复核后的「有条件重启」= 条件未满足即等同结项） | `gunyah-decision-20261025.md` §1/§6、`gunyah-restart-assessment-20261111.md` §4 |
| `gunyah_wdt` 作为 D19 看门狗 | **已结项（否）**：hyp 侧空实现；且主线已有此驱动，无上游化空间 | `d19-gunyah-wdt-20261125.md` 父代理附节 + 本报告 §2 F7/F9/F10 |
| `drivers/virt/gunyah` 6.12/piano/iceland 素材 | **有条件后续**（封存，不排期、不占设备）：仅作 G1 补丁素材 | `gunyah-decision-20261025.md` §5、本报告 §3-A |
| 本机固件 RM 策略（C2）二值判定 | **有条件后续**（需设备窗 + 用户确认 C3） | `gunyah-restart-assessment-20261111.md` §4 |
| gunyah 相关 DTS（`gunyah-hyp` 保留区 / EL1 节点） | **上游自己在动，我们不投**（内容级证据仅到「上游 RFC 在整理 EL1 dtsi」） | 本报告 §2 F12 |

---

## §2 事实表（命令/URL + 原始输出摘录 + 时间）

> 每条都是本轮现跑/现抓。命令行原样给出，输出只截取判读所需片段；`ssh` 均为**只读**命令。

### F1 候选件目录在位、sha 与 manifest 逐字一致

```
22:17Z  $ ls -l out/gunyah-wdt-20261125/
-rw-rw-r-- 21057216 Nov 25 19:33 Image.gz
-rw-rw-r-- 85815296 Nov 25 19:39 boot-elden-gunyah-wdt.img
-rw-rw-r--     4668 Nov 25 19:41 boot-elden-gunyah-wdt.manifest
-rw-rw-r--   353320 Nov 25 19:33 gunyah_wdt.ko
-rw-rw-r--   153089 Nov 25 19:33 sm8750-lenovo-elden.dtb
-rw-rw-r--   167136 Nov 25 19:33 gunyah-wdt-modules.list
-rw-rw-r--   327234 Nov 25 19:33 config-before-wdt.bak
-rw-rw-r--   327223 Nov 25 19:34 config-with-gunyah-wdt
-rw-rw-r--     2048 Nov 25 19:39 structure-verify.txt
$ sha256sum out/gunyah-wdt-20261125/{boot-elden-gunyah-wdt.img,Image.gz,gunyah_wdt.ko,sm8750-lenovo-elden.dtb}
cf5605d3dd64c91e5455a5043281c3bb1105b31e4c287d74f25032f909616545  boot-elden-gunyah-wdt.img
6b20ace780e6856c3ea9cadd6f503d422ff728a11e624ecbfcdb969af22019bf  Image.gz
5333824b2d63969c165736561ca90b0a96e87653f18716982b53c03bea659d46  gunyah_wdt.ko
df00cb19b643897a5df8c8290fe1bdc9b626d115997a14e1b2859772441adcf1  sm8750-lenovo-elden.dtb
```
四条 sha 与 `boot-elden-gunyah-wdt.manifest` 里 `image_sha256 / kernel_sha256 / module_sha256 / dtb_rebuilt_sha256` **逐字相同**
⇒ 候选件自 11-25 打包后未被改动（`structure-verify.txt` 亦在位）。

### F2 **候选件内核 ≠ 在机内核（非同源）**

```
22:17Z  $ ssh root@192.168.7.1 'uname -r'          →  7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0
        manifest: kernel_release=7.3.1-debug-vk189-suspend-g4da9a8b69fc8
                  kernel_git_head=4da9a8b69fc85fb1dd100c63f5a1b02eb730571a
```
判读：候选 = `…-suspend-g4da9a8b69fc8`（**在 tag 上**，`git describe` 无 `-NNNNN-` 计数）；在机 = `…-00005-g4bdf1711b5c0`
（**tag 之后 5 个提交**）。两者 `describe` 哈希不同、提交计数不同 ⇒ **不是同一构建**。
另：`4bdf1711b5c0` 在本仓 `build/daily` 里 `git cat-file -t` = `Not a valid object name`（浅/部分克隆，父提交不可遍历：
`git describe --tags` 报 `Could not read a2795d9c…`）⇒ **既不能证明同源，也不能反证**；能确定的只有「UTS 不同源」。

### F3 树与 SSOT 配置干净（候选件的构建前提仍成立）

```
22:17Z  $ git -C build/daily rev-parse HEAD      → 4da9a8b69fc85fb1dd100c63f5a1b02eb730571a
        $ git -C build/daily tag --points-at HEAD → vk184
        $ sha256sum build/daily/.config           → 34c7d658d4eee4aa073ecf2f2ed9ca5d58c5ad22caca794334c007e468aa34fe
        $ git -C build/daily status --short | wc -l → 0
```
`.config` = `d19-gunyah-wdt-20261125.md` §2.4 记录的 SSOT sha，树 0 改动 ⇒ 「配置已复原、树未漂」这条仍然成立。

### F4 设备侧只读现状：平台设备在、驱动未绑、无 `/dev/watchdog*`、无 `/dev/gunyah`

```
22:17Z  $ ssh root@192.168.7.1 '...'
uname_r: 7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0
uptime: 24627.23 197060.49
watchdog_dev: ls: 无法访问 '/dev/watchdog*': 没有那个文件或目录
platdev: /sys/bus/platform/devices/gunyah-wdt
drv_grep_rc: 0                                  # ls /sys/bus/platform/drivers | grep -c -i gunyah
modalias: platform:gunyah-wdt
wdt_ko: ls: 无法访问 '…/kernel/drivers/watchdog/gunyah_wdt.ko': 没有那个文件或目录
virt_gunyah: gunyah_ioeventfd.ko gunyah_irqfd.ko gunyah.ko gunyah_platform_hooks.ko gunyah_qcom.ko gunyah_qtvm.ko gunyah_rsc_mgr.ko gunyah_vcpu.ko
lsmod: 0
dev_gunyah: ls: 无法访问 '/dev/gunyah': 没有那个文件或目录
dmesg: [0.000000] OF: reserved mem: 0x0000000080000000..0x0000000080dfffff (14336 KiB) nomap non-reusable gunyah-hyp@80000000
cmdline_root: elden_root=LABEL=linux androidboot.slot_suffix=_b
```
判读三条：
1. `qcom_scm` 的 UUID 探测**仍命中**（平台设备 `gunyah-wdt` 在，`modalias=platform:gunyah-wdt`）⇒ 「我们跑在 Gunyah guest 里」这条**没有变化**；
2. 但**没有驱动绑定**（`drivers/` 下无 `gunyah-wdt`）、**没有 `/dev/watchdog*`**、**没有 `/dev/gunyah`** ⇒ 本机当前的 gunyah 面 = **纯探测态**，零功能；
3. `dmesg` 只有 `gunyah-hyp@80000000` 保留区一行 ⇒ 没有 `Running under Gunyah hypervisor <api>/v1` 之类的主线驱动打印（驱动没加载，符合预期）。

### F5 10-25 的 6.12 驱动集**仍在设备盘上、未加载**（休眠资产，不是运行栈）

```
22:1xZ  $ ssh root@192.168.7.1 'ls -l /lib/modules/$(uname -r)/kernel/drivers/virt/gunyah/'
-rw-rw-r-- 316016 11月17日 22:14 gunyah_ioeventfd.ko
-rw-rw-r-- 328904 11月17日 22:14 gunyah_irqfd.ko
-rw-rw-r-- 180672 11月17日 22:14 gunyah.ko
-rw-rw-r-- 333216 11月17日 22:14 gunyah_platform_hooks.ko
-rw-rw-r-- 346552 11月17日 22:14 gunyah_qcom.ko
-rw-rw-r-- 394520 11月17日 22:14 gunyah_qtvm.ko
-rw-rw-r-- 1555184 11月17日 22:14 gunyah_rsc_mgr.ko
-rw-rw-r-- 739608 11月17日 22:14 gunyah_vcpu.ko
```
判读：8 个 `.ko`（11-17 部署），但 `lsmod` 0 命中、`/dev/gunyah` 不存在 ⇒ **没有开机加载钩子**。原文核对：

```
22:22Z  $ ssh root@192.168.7.1 'ls /etc/local.d/; grep -rl -i gunyah /etc/local.d /etc/modules-load.d /etc/modules; grep -rl -i gunyah /etc/systemd/system'
ls: 无法访问 '/etc/local.d/': 没有那个文件或目录          # 10-25 那套 /etc/local.d/50-gunyah.start 已不在当前根里
（后两条 grep 均无输出 ⇒ modules-load.d / modules / systemd 单元里都没有 gunyah 字样）
```

⇒ 「设备上已经有能跑的 gunyah 栈」**不成立**，只能算「模块文件还在」。

### F6 上游 torvalds / linux-next：`drivers/virt` **仍无 gunyah**

| 树 | URL（本轮抓取 22:05–22:06Z） | 目录项（原文） | gunyah |
|---|---|---|---|
| torvalds/linux `master` | `https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/virt` | `Kconfig Makefile acrn coco fsl_hypervisor.c nitro_enclaves steal_governor.c vboxguest vmgenid.c` | **无** |
| linux-next | `https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/tree/drivers/virt` | 同上（Kconfig 2111 B vs torvalds 2101 B，差异不在 gunyah：无 gunyah 目录/条目） | **无** |

（这与 2026-11-11 那次复核（`gunyah-restart-assessment-20261111.md` §1.1）**结论一致**：14 天无变化。）

### F7 上游 `drivers/watchdog`：**`gunyah_wdt` 已在主线**

```
22:08Z  $ curl -sS https://git.kernel.org/…/torvalds/linux.git/plain/drivers/watchdog/Makefile | rg -n -i gunyah
107:obj-$(CONFIG_GUNYAH_WATCHDOG) += gunyah_wdt.o
22:08Z  $ curl -sS …/plain/drivers/watchdog/Kconfig | rg -n -i -A6 gunyah
2382:config GUNYAH_WATCHDOG
2383:	tristate "Qualcomm Gunyah Watchdog"
2384:	depends on ARCH_QCOM || COMPILE_TEST
2390:	  to interact with Gunyah Watchdog.
22:08Z  $ curl -sS …/plain/drivers/watchdog/gunyah_wdt.c  → 6767 B
        max_timeout = 32 / watchdog_set_restart_priority(wdd, 0) / static int gunyah_wdt_resume(...)
```
与 `build/daily`（7.3.1）同文件比：`sha256 c4163cb9…` vs 主线 `e142a2e4…`，diff = `+15 / −10` 行，实质差异 =
主线把 `start()` 拆出 `gunyah_wdt_enable()`（resume 走 enable，**不再在 resume 时先 DISABLE**）。
⇒ 结论：**这条驱动没有「上游化」可做**；候选件里那颗 `.ko` 编的是 7.3.1 版本（少 11-09 的 resume 修正，但该修正与本机阴性结论无关）。

### F8 上游 `qcom_scm` 的 gunyah 探测形状（与 APSS 候选互斥 —— 本轮再核）

```
22:09Z  $ curl -sS …/plain/drivers/firmware/qcom/qcom_scm.c  (77380 B)  → rg -n -i 'gunyah|qc_hyp_uuid'
2428: static void qcom_scm_gunyah_wdt_init(struct qcom_scm *scm)
2434:   static const uuid_t gunyah_uuid = UUID_INIT(0xc1d58fcd, 0xa453, 0x5fdb, …)
2444:   !arm_smccc_hypervisor_has_uuid(&gunyah_uuid)
2448-2459: of_wdt_compatible[] = { "qcom,kpss-wdt", "arm,sbsa-gwdt" };  若 DT 里有且 available ⇒ return
2459:   platform_device_register_simple("gunyah-wdt", -1, NULL, 0)
```
判读：① 只认 `c1d58fcd-…` 这一个 UUID（**`qc_hyp_uuid` 不在主线**，见 F11）；② **DT 里出现可用 `qcom,kpss-wdt`
或 `arm,sbsa-gwdt` 就 bail** ⇒ `patches/local/apss-wdt-20261125/` 一旦上机使能，`gunyah-wdt` 平台设备**会消失**，
两个候选**互斥**（D19 行已记，本轮确认上游代码形状未变）。

### F9 lore `gunyah-wdt` 检索（68 条，最新一条是 2026-11-25 的 stable 队列）

`https://lore.kernel.org/all/?q=gunyah-wdt`（22:07Z 抓取，页面原文摘要）：

```
 1. [PATCH 7.3 0733/1005] watchdog: gunyah_wdt: Re-enable the watchdog on resume  — Greg Kroah-Hartman @ 2026-11-25 14:34 UTC
 2. Re: [PATCH] watchdog: gunyah_wdt: Re-enable the watchdog on resume            — Guenter Roeck @ 2026-11-09 23:00 UTC
 3. [PATCH] watchdog: gunyah_wdt: Re-enable the watchdog on resume                — Stanislav Aleksandrov @ 2026-11-09 08:26 UTC
 …
 7. Re: [PATCH RESEND v8 2/2] watchdog: Add driver for Gunyah Watchdog            — Bjorn Andersson @ 2026-03-30 14:11 UTC
 8. [PATCH RESEND v8 2/2] watchdog: Add driver for Gunyah Watchdog                — Pavankumar Kondeti @ 2026-03-11 05:46 UTC
 9. [PATCH RESEND v8 1/2] firmware: qcom: scm: Register gunyah watchdog device    — Pavankumar Kondeti @ 2026-03-11 05:46 UTC
Results 1-68 of 68
```
（Message-ID / patchwork 页见 F10；`curl` 直取 lore 的 `?q=…&x=A` 被 **403 Forbidden（nginx）**，故 lore 只用页面渲染 + patchwork API 两源。）

### F10 patchwork：驱动系列 `mainlined`、resume 修正 `accepted`、SCM 第二 UUID `new`

```
22:12Z  项目 linux-watchdog，q=gunyah，按日期倒序：
  2026-11-09T08:26:52 | accepted          | watchdog: gunyah_wdt: Re-enable the watchdog on resume
    msgid <20261109-gunyah-wdt-resume-v1-1-fbd84545ce92@gmail.com>
    https://patchwork.kernel.org/project/linux-watchdog/patch/20261109-gunyah-wdt-resume-v1-1-fbd84545ce92@gmail.com/
  2026-10-08T22:34:46 | changes-requested | watchdog: gunyah: report system sleep operation failures
  2026-03-11T05:46:31 | accepted          | [RESEND,v8,2/2] watchdog: Add driver for Gunyah Watchdog
    msgid <20260311-gunyah_watchdog-v8-2-4c1c0689de22@oss.qualcomm.com>
22:16Z  项目 linux-arm-msm：
  2026-11-09T08:26:52 | mainlined | watchdog: gunyah_wdt: Re-enable the watchdog on resume
  2026-11-09T00:30:23 | new       | firmware: qcom: scm: Detect Gunyah by Qualcomm's hypervisor UID too
    msgid <20261109-qcom-scm-gunyah-uid-v1-1-2776343f9a3b@gmail.com>
```
交叉判读：resume 修正已在 torvalds（F7 里主线 `gunyah_wdt.c` 含 `gunyah_wdt_enable()` + `resume→enable`）；
SCM 第二 UUID 补丁 `state=new` **且主线 `qcom_scm.c` 无 `qc_hyp_uuid`**（F8）⇒ **未合入**。
「report system sleep operation failures」`changes-requested`、主线 `suspend/resume` 里失败仍 `return 0`
（`gunyah_wdt_suspend(): if (watchdog_active(wdd)) gunyah_wdt_stop(wdd); return 0;`）⇒ 也**未合入**。

### F11 `drivers/virt/gunyah` 的系列史：**最新仍是 2024-02-22 v17，2026 年零新系列**

```
22:12Z  项目 linux-arm-msm，series?q=gunyah（按日期倒序，前 20 条）：
2026-11-09 watchdog: gunyah_wdt: Re-enable the watchdog on resume            (n=1)
2026-11-09 firmware: qcom: scm: Detect Gunyah by Qualcomm's hypervisor UID too (n=1)
2026-10-08 watchdog: gunyah: report system sleep operation failures          (n=1)
2026-03-11 Add support for Gunyah Watchdog                                   (n=2)
2026-03-02 arm64: dts: qcom: monaco: Reserve full Gunyah metadata region     (n=1)
2025-12-29 [1/2] arm64: dts: qcom: agatti: Fix IOMMU DT properties           (n=2，含 Gunyah 内存对齐)
2025-11-18 … 2025-09-03 Add support for Gunyah Watchdog (v8…v1)
2025-04-24 Running Qualcomm's Gunyah Guests via KVM in EL1                   (n=34)
2024-02-22 Drivers for Gunyah hypervisor                                      (n=35)   ← v17，driver 侧最后一代
```
⇒ `drivers/virt/gunyah` **没有在审/新投系列**（v17 停在 2024-02-22），2026 年 gunyah 面上的动作**全在外围**
（watchdog / SCM 探测 / DTS 元数据）。

### F12 上游 dt 侧新动向（内容级）：2026-11-13 RFC 里出现 `sm8650-el1.dtsi`

```
22:15Z  patchwork 14980980 | [RFC,20/23] arm64: dts: qcom: sm8650: move EL1 Gunyah nodes to sm8650-el1.dtsi
        date 2026-11-13T18:38:34 | state superseded
        msgid <20261113-topic-sm8650-el2-v1-20-5183f6aab9fc@linaro.org>
        series: "arm64: qcom: enable SM8650 audio without ADSP firmware" (23 封, v1)
        diff: 新增 arch/arm64/boot/dts/qcom/sm8650-el1.dtsi（775 行），并在 5 块板 dts 里 +include
```
判读（保守）：**标题级 + 文件级**证据表明上游在把「Linux 在 EL1（Gunyah 之下）」的 DT 节点单独成文件；
diff 正文里**没有** `gunyah` 字样（移动的是 EL1 侧节点），所以**不能**据此说「virt/gunyah 要进主线」。
对我们唯一有用的信息：**本机「EL2 归签名 Gunyah」不是独有形态**，但上游仍只处理 DT/固件侧，不碰 `drivers/virt/gunyah`。

### F13 仓内素材清单（`rg -n -i gunyah` 限定路径 + 目录核对）

```
22:17Z  $ ls reference/gunyah-refs/        → DroidVM  crosvm-gunyah-slice  g612  g612-hdrs  gunyah_host_mod
        $ ls reference/gunyah-refs/g612 | wc -l → 18   （含 Kconfig/Makefile/gunyah*.c/rsc_mgr*.c/vm_mgr*.c/urls.txt）
        $ ls tools/gunyah-modules/         → README.md  dtbo  hypprobe  rmtest  vmmtest
        $ ls patches/gunyah/               → 0001-arm64-dts-qcom-elden-enable-dtc-symbols.patch
        $ ls -l out/gunyah-modules-gunyah1.tar.gz → 1370044 B, Oct 24 19:33
        $ ls -l patches/config-gunyah-wdt-20261125.fragment → 1679 B, Nov 25 19:28
        $ ls -d build/gunyah-port out/gunyah-73 → 两个都 No such file or directory
        $ rg -l -i gunyah patches/ → 15 个文件；.pi/ → 18 个文件；rootfs/ → 0；reports/ → 198 个文件
```
判读：
- **在的**：g612 驱动 18 文件 + 头文件、`gunyah_host_mod`（`gh_unmovable`/`gunyah_host_share`/`gunyah_kvcalloc`）、
  `crosvm-gunyah-slice`（Rust 侧 `gunyah.rs`）、`DroidVM` 切片、最小 VMM harness（`vmmtest`/`rmtest`/`hypprobe`/`dtbo`）、
  DTC `__symbols__` 补丁、gunyah_wdt 配置片段、10-24 的模块 tar。
- **没的**：`build/gunyah-port`（11-12 的 piano→7.3.1 移植树、10 `.ko`）与 `out/gunyah-73`（移植产物）**都已不在**
  ——与 `TASKS/README.md` §4.1 H1「2026-11-25 磁盘清理删 `build/` 链接产物」对得上。⇒ **重启 S2 必须先重建移植（或直接对新树重跑 §2 的 102 行适配）**。

### F14 D19 的下一候选（APSS watchdog）备料在位、未上机

```
22:18Z  $ ls -l patches/local/apss-wdt-20261125/
0001-dt-bindings-watchdog-qcom-add-sm8750-apss-wdt.patch   1194 B
0002-arm64-dts-qcom-sm8750-add-apss-watchdog.patch         1313 B
README.md                                                  1752 B
evidence/   13 份日志：gate-git-am-2of2.log / gate-tree-state-after.log / checkpatch-000{1,2}-*.log /
            gate-patched-dtbscheck-sm8750-mtp.log / gate-daily-patched-dtbscheck-3dtb.log / gate-patched-bindingcheck-*.log 等
$ grep -c watchdog build/daily/arch/arm64/boot/dts/qcom/sm8750.dtsi → 0
```
⇒ 「上游 `qcom-wdt` + 一篇 DT/binding」这条路**素材齐、机械门绿、未上机**；它是 D19 的现役下一候选（本报告 §3-B 的**更便宜前置**）。

### F15 本轮**没有**做的事（避免误读）

- **零设备写**：未 `insmod`/`rmmod`、未 `fastboot`、未写槽/分区；ssh 只跑 `uname/ls/cat/dmesg`。
- **零邮件动作**：未读邮箱、未发信、未 `git send-email`、未改订阅（本 lane 不需要通信面）。
- **未改任何台账/文档**：`TASKS/README.md`、`INDEX.md`、`DEVICE/`、`RESOURCES/`、`PITFALLS/` 一字未动；未 `git commit`。
- **未跑全仓 `grep -r`**：一律 `rg` + 限定路径（`patches/ rootfs/ reports/ .pi/ reference/ tools/ out/`）。

---

## §3 三个候选动作：代价 / 判据 / 风险

### A 上游化素材（把 gunyah 驱动集拆成 G1 补丁素材）

**口径更正（重要）**：任务里写的「§7 M9：gunyah 驱动集作 G1 补丁素材」在台账里**对不上**——
`TASKS/README.md` §7 的 **M9 = kexec 的 gic-v3-its LPI 认领**（已被 Marc Zyngier 否，2026-10-26 撤回），**没有 gunyah 行**；
「6.12 驱动分层作 G1 补丁素材」的原话出自 `reports/gunyah-decision-20261025.md` **§5**。⇒ 若要让台账可检索，需新增一行（见 §4 建议 M13）。

| 项 | 内容 |
|---|---|
| 目标形态 | 按「P4 可独立 review」拆：① `vm_mgr` / `vm_mgr_mem`（与设备无关、结构最干净）；② `rsc_mgr` / `rsc_mgr_rpc`（RPC 面，含 APPEND/parcel 生命周期）；③ `gunyah_qtvm`（auth manager 样板）；④ `gunyah_qcom` / `gunyah_platform_hooks` = vendor hook ⇒ **不进包**（只留本地） |
| 代价 | **先重建移植树**（`build/gunyah-port` 已删，F13）：sparse clone piano `ff6cf0aa` 或 iceland `iceland-7.3-rc7-next` → 重跑 102 行 API 适配（`vma_interval_tree_foreach`→`mapping_rmap_tree_foreach` 等，`gunyah-73-port-20261112.md` §2 有清单）→ ~0.5 天；拆分 + 每片 `git am`/`checkpatch --strict`/目标文件编译 → 1–1.5 天。合计 **1.5–2 天**，**零设备**。 |
| 判据 | 每片：`git am` 1/1 干净；`checkpatch.pl --strict` 0E/0W/0C；在 7.4-rc3（`build/elden-tree`）或 daily 上 `make drivers/virt/gunyah/` 目标文件 0 warning；**不依赖** `CONFIG_ANDROID_VENDOR_HOOKS`（走 no-op shim）；片内不含 vendor 私有 msg-id（`0x51000017/1a`、`0x56000009/0a`）除非单独注记 |
| 风险 | ① **没有接收面**：主线 `drivers/virt` 无 gunyah（F6）、driver 系列停在 2024-02-22 v17（F11）⇒ 产出只能是「素材包」，**不可投递**；② **重复劳动**：iceland（q90m 起 9289 行 import + 16 个修正）与 piano 已把同一素材做到「硬件验证 + 主线适配 102 行」，我们重做一遍的边际价值低；③ 我方素材是 6.12 代次（`reference/gunyah-refs/g612`），**比 piano/iceland 的 android17-6.18 代次旧**（S1 已证 g612 有 APPEND/unpin 真 bug，`gunyah-s1-static-diff-20261111.md`）⇒ 若真做，应换 piano 代次，别拿 g612 交差 |
| 建议 | **暂不做**（有条件后续）。触发条件：主线出现 virt/gunyah 接收面（v18 / 新 maintainer 表态 / iceland 队列被接收），或有人明确要「我们自己的」补丁素材。 |

### B 上机读回（一次设备窗把 C2 变二值）

| 项 | 内容 |
|---|---|
| 目标 | 判 C2 = 「本机 Lenovo 固件 RM 是否允许（pVM/正常 VM）建 VM」：① `/dev/gunyah` + `gh_rm_core` 出现；② `gh_vmtest`（4 MiB LEND + 1 vCPU + 16 B，不走 crosvm）的 `VM_START` 是否 **0**；③ 若仍 `0xA`，喂**故意违规 DTB**（`memory@80000000` / timer PPI mask `0xf08`）看是否变 `8 VALIDATE_FAILED` |
| 代价 | 主机：重建移植树（同 A，0.5 天）+ 打包零写盘件（~0.5 h）；设备：`fastboot boot` + 模块部署 + 探针 ≈ 30 min（一次窗）。**合计 ≈1 个工作日 + 一个设备窗** |
| 判据 | 二值，且**必须能区分三态**：`VM_START=0` ⇒ C2 真（⇒ 重启立项，按 iceland 配方接 crosvm）；`0xA` + 违规 DTB 变 `8` ⇒ C2 未定但 DTB 轴复活（10-25 结论作废）；`0xA` 且违 DTB 仍 `0xA` ⇒ **永久关闭**（把 10-25 结论钉死） |
| 风险 | ① `fork()` 持 LEND 页会**同步 external abort 挂机**（iceland 实测）、4 KiB LEND 会冻宿主 ⇒ 必须单进程、`GVM_HUGEPAGES` 默认、**不要在无人循环里跑**；② 候选核 UTS 与在机模块树不同（F2）⇒ 要么部署整套模块树，要么接受 WiFi/uinput 缺位（`d19-gunyah-wdt-20261125.md` 附节已记该坑）；③ **与 APSS watchdog 读回争同一设备窗**，而 APSS 解的是 D19「hang 只能物理 POR」这个**正在流血**的阻塞 ⇒ 排期上必须让 APSS 先 |
| 建议 | **有条件后续**：需 ①用户确认 C3（“一定要在本机跑子 VM”）②设备窗；否则不做。做的话按 `gunyah-restart-assessment-20261111.md` §4 S2/S3 原样执行（含风险自限），**不要临时加变量**。 |

### C 归档结项，不再投入

| 项 | 内容 |
|---|---|
| 动作 | 把「子 VM 已结项」「gunyah_wdt 已否」「素材封存」三句话写进台账（§4 给出文本）；本报告与既有 6 份报告即为完整证据链 |
| 代价 | **0**（已基本完成，只差台账一行口径） |
| 判据 | `TASKS` 里任意入口（§2 C8 / §4.0 D7 / §5 Q4）读到的都是「有条件重启 + 条件未满足」而不是「已结项」或「在推进」二义；`rg -n gunyah TASKS/README.md` 不再出现「唯一新路线 = KVM-in-EL1」这种已推翻的口径（现 §5 Q4 仍留着） |
| 风险 | ① 复启条件若被满足（新固件不再依赖 `MEM_DONATE` / 上游出开源 loader ABI / 用户要子 VM）需重开 —— 素材在仓（F13），重开成本 = 重建移植树，已量化；② 归类过狠会让后续 lane 把「素材」也当死资产删掉 ⇒ 建议在归档文本里**显式保留** `reference/gunyah-refs/**`、`tools/gunyah-modules/**`、`patches/gunyah/0001` |

### 推荐顺序（成本 × 收益）

1. **C（今天就能收口，0 成本）** —— 台账口径统一，防止下一轮再重新判一遍。
2. **D19 的 APSS 读回**（不在本 lane 范围，但同一设备窗更该先做；F14 备料已在位）——解的是「hang 类实验不能进无人循环」。
3. **B**（需用户 C3 + 设备窗）——一次二值，别做第二次。
4. **A**（仅在主线出现接收面后）——现在做等于给自己造一个不能投的包。

---

## §4 给父代理的台账改动建议（只出文本，**本 lane 未改任何文件**）

### 4.1 `TASKS/README.md` §4.0 行 **D7**（UEFI / Gunyah）

现文：「…Gunyah 已结项」。建议改为（保留 UEFI 部分原文，只动 Gunyah 半句）：

```
Gunyah = **有条件重启（2026-11-11）≠ 已结项，但条件未满足 ⇒ 视同不投入**（`reports/gunyah-restart-assessment-20261111.md`）；
2026-11-26 静态复核（`reports/gunyah-lane-20261126.md`）：主线 torvalds/linux-next `drivers/virt` **仍无 gunyah**（14 天无变化）、
driver 系列仍停 2024-02-22 v17、2026 年 gunyah 动作全在外围（watchdog/SCM/DTS）；`gunyah_wdt` **已在主线**且本机 hyp 空实现 ⇒ D19 此路否；
6.12/piano 素材在仓（`reference/gunyah-refs/`、`tools/gunyah-modules/`），但移植树 `build/gunyah-port` 与 `out/gunyah-73` 已于 11-25 清理删除
⇒ 任何上机读回需先重建（≈0.5 天）。**当前不排期、不占设备**。
```

### 4.2 新增 §4.0 行 **D21（gunyah 线，封存）** —— 仅当父代理认为 D7 太杂时启用

```
| **D21** | **Gunyah 线（子 VM / 驱动素材 / 看门狗）** | 🟢 **已收口为「封存」**：子 VM = 2026-10-25 终局裁决 + 11-11 有条件重启（C2 未测、C3 未确认）；`gunyah_wdt` = 11-25 上机否（hyp 空实现）+ 主线已有该驱动（无上游化空间）；主线 `drivers/virt` 仍无 gunyah（11-26 复核） | ① 素材封存不删（`reference/gunyah-refs/**`、`tools/gunyah-modules/**`、`patches/gunyah/0001`）；② 若要重启 = 一次上机读回（判据见 `reports/gunyah-lane-20261126.md` §3-B），需用户确认「本机跑子 VM」+ 设备窗；③ **不要**再拿 `gunyah_wdt` 当 D19 解 | 否（重启需设备窗） | `reports/gunyah-lane-20261126.md`、`reports/gunyah-decision-20261025.md`、`reports/gunyah-restart-assessment-20261111.md`、`reports/d19-gunyah-wdt-20261125.md` |
```

### 4.3 `TASKS/README.md` §5 行 **Q4**

建议在「关联任务」格或结论尾部**追加一句**（不要删历史）：

```
**2026-11-26 再核**：③ 的「唯一新路线 = KVM-in-EL1」口径**已作废**（KVM 维护者 2025-04-24 明确拒绝，RFC 停 v0）；
主线 `drivers/virt` 仍无 gunyah、driver 系列停 v17(2024-02-22) ⇒ 现状不是「有路要选」，而是「**无接收面 + 本机固件未验**」，
详见 `reports/gunyah-lane-20261126.md` §1/§3。
```

### 4.4 `TASKS/README.md` §7（M 系列）

**(a) M9 行加注**（M9 是 gic-its，与 gunyah 无关，防止再被错引）：

```
※ 注：M9 仅指「kexec 的 gic-v3-its 认领继承 LPI 表」（已撤回）。**Gunyah 驱动素材不在 M9**，原话在
`reports/gunyah-decision-20261025.md` §5；若要单列见 M13。
```

**(b) 新增 M13 行**（素材封存，不投）：

```
| **M13** | **Gunyah 驱动集素材（`drivers/virt/gunyah`）**——2026-11-26 立项为「封存项」 | ⛔ **封存不投**：主线 `drivers/virt` 无 gunyah（torvalds + linux-next，2026-11-26 抓取）、driver 系列停 2024-02-22 v17、**零接收面**；我方素材为 6.12 代次（`reference/gunyah-refs/g612`，S1 已证有 APPEND/unpin 真 bug），piano/iceland 的 android17-6.18 代次更完整且已硬件验证 ⇒ 我们重做边际价值低。**若重启**：按模块拆 `vm_mgr`/`vm_mgr_mem` → `rsc_mgr*` → `qtvm`，vendor hook 模块（`gunyah_qcom`/`platform_hooks`）不进包；先重建移植树（`build/gunyah-port` 已删） | —（不阻塞） | 不适用（无接收面，无可投判据）；触发条件 = 主线出现 virt/gunyah 接收面 | `reports/gunyah-lane-20261126.md` §3-A、`reports/gunyah-decision-20261025.md` §5、`reports/gunyah-s1-static-diff-20261111.md` |
```

### 4.5 `TASKS/README.md` §4.0 行 **D19**（补两句硬事实）

```
· 候选件复核（2026-11-26）：`out/gunyah-wdt-20261125/` 四件 sha 与 manifest 逐字一致；但**候选核 UTS `…-suspend-g4da9a8b69fc8`
  与在机内核 `…-suspend-00005-g4bdf1711b5c0` 非同源**（`git describe` 哈希/计数皆不同），UTS 不匹配类副作用按旧口径读。
· 在机现状（只读）：`gunyah-wdt` 平台设备在、**无驱动绑定**、无 `/dev/watchdog*`、无 `/dev/gunyah`；`/lib/modules/<UTS>/kernel/drivers/virt/gunyah/`
  8 个 .ko 仍在（11-17）但 `lsmod` 0 命中 ⇒ 「设备上有 gunyah 栈」不成立。证据 `reports/gunyah-lane-20261126.md` §2 F2/F4/F5。
```

### 4.6 `reports/README.md` / `INDEX`（如需要）

```
新增 reports/gunyah-lane-20261126.md —— gunyah 线静态推进（唯一写入路径；含上游内容级复核 + 本机只读事实 + 三候选动作裁定 + 台账建议）。
```

---

## §5 复现命令（下轮只读复跑，全绿即「结论未过期」）

```bash
cd /home/xuqianhui/y700-elden
# 1) 候选件身份（应逐字命中 manifest）
sha256sum out/gunyah-wdt-20261125/{boot-elden-gunyah-wdt.img,Image.gz,gunyah_wdt.ko}
grep -E '^(kernel_release|kernel_git_head|config_sha256)=' out/gunyah-wdt-20261125/boot-elden-gunyah-wdt.manifest
# 2) 在机内核（只读；预期每次随日常核变化 ⇒ 与候选件不同源是常态）
timeout -k 5 20 ssh -o BatchMode=yes root@192.168.7.1 'uname -r; ls /dev/watchdog* ; ls /sys/bus/platform/devices | grep gunyah'
# 2b) 「设备上有没有 gunyah 加载钩子」（预期：local.d 不存在 / grep 无输出）
timeout -k 5 20 ssh -o BatchMode=yes root@192.168.7.1 'ls /etc/local.d/; grep -rl -i gunyah /etc/local.d /etc/modules-load.d /etc/modules /etc/systemd/system'
# 3) 上游（内容级；三处都须「无 gunyah 目录」）
curl -sS --max-time 20 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/virt | grep -c gunyah          # 0
curl -sS --max-time 20 https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/tree/drivers/virt | grep -c gunyah       # 0
curl -sS --max-time 20 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/drivers/watchdog/Makefile | grep gunyah # obj-$(CONFIG_GUNYAH_WATCHDOG) += gunyah_wdt.o
# 4) 系列史（应为 2024-02-22 v17 仍是最新 driver 系列）
curl -sS --max-time 20 'https://patchwork.kernel.org/api/1.2/series/?project=linux-arm-msm&q=gunyah&per_page=20&order=-date'
# 5) 素材在位 / 移植树不在
ls reference/gunyah-refs/ tools/gunyah-modules/ patches/gunyah/
ls -d build/gunyah-port out/gunyah-73 2>&1     # 两个都应 No such file or directory
```

---

## §6 残余风险（本 lane 口径）

1. **「非同源」只到 UTS 级**：`4bdf1711b5c0` 不在本仓（浅克隆），无法做 `git merge-base` 级证明；若将来有人要「严格同源判定」，
   需拿到在机内核的完整 `linux_banner`/`/proc/version` + 构建树（或 `scripts/verify-kernel-identity` 类工具）再对。
2. **上游判定有盲区**（沿用 §7 头三条限定）：本报告用「内容级 = 树里有没有文件/条目」判定，**不用** patchwork `state`/`commit_ref`
   单独定死；但「维护者直接取件合入而不回信」这类盲区对 `virt/gunyah` 同样存在——只是 v17 系列 0 合入、且主线无目录，
   双重独立证据已足够。
3. **iceland/piano 侧变化未跟踪**：本轮**没有**复核这两个第三方树的新提交（不在派工范围）；若它们继续演进（例如把驱动送上游），
   本报告 §3-A 的「无接收面」结论会随时间失效 ⇒ 建议任何重启评估先跑一次这两棵树的 `git log drivers/virt/gunyah`。
4. **D19 APSS 候选与 `gunyah-wdt` 互斥**（F8 上游代码形状）：上机使能 APSS 后 `/sys/bus/platform/devices/gunyah-wdt` 会消失，
   若后续有人拿「设备上还有 gunyah-wdt 节点」当证据会误判 —— 建议 D19 行把这句写死（已在 §4.5 建议里）。
