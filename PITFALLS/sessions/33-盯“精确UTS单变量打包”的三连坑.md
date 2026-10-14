## 三十三、盯“精确 UTS / 单变量打包”的三连坑（2026-10-14 E1 实测）

纯 ramdisk 臂必须让内核 UTS 与 ramdisk 内模块 vermagic 逐字相同，否则 `=m` 驱动全不加载（`#248` 的姊妹坑）：

- `CONFIG_LOCALVERSION_AUTO=n` **仍会**被 `scripts/setlocalversion --short` 追加 `+`（HEAD 不在 annotated tag 上时）⇒ UTS 变 `...-ged6f232d10e3+`，模块路径与 vermagic 全失配。
- 改完 `.config` 后 `make kernelrelease` 若已有缓存 `include/config/kernel.release` **会继续报旧串**（先 `rm -f` + `syncconfig`）。
- `LOCALVERSION=...` 环境变量是**追加**不是覆盖（会得到 `-debug-debug-...-dirty`）。

可用解法：`CONFIG_LOCALVERSION="-debug-<sha>"` + `CONFIG_LOCALVERSION_AUTO=n`，**且**给 HEAD 打一个 **annotated** tag `v7.3-rc7`（`try_tag` 命中且 count=0 ⇒ 不输出 scm 段）⇒ UTS 精确；**构建完立即 `git tag -d`**，否则污染其它 worktree 的 `git describe` 与后续构建身份。

单变量打包同理：**ramdisk/DTB 必须逐字节复用参考成品镜像里的组件**——本树 `out/rootfs-m1-73.cpio.gz`（`1a5c0bc8...`）**不等于** `73j` 镜像内 ramdisk（`4d4834e6...`），混用即引入第二个变量（应从参考镜像 `unpack_bootimg` 取）。

内核探针写 `pll->pll_base` 直接编译失败：`dsi_7nm_phy_enable()` 里只有 `phy`/`base`，正确写法 `pll->phy->pll_base`（本次 3.93 s 早失败的教训——先小样本编译再全量）。

258. **★★`reboot2 bootloader`（PSCI vendor reset）会「整机冻死」，结构性原因 = 该复位被注册为 *restart handler*，永远排在 `device_shutdown()` 之后（2026-10-14 复核定案；用户指示主会话停用该路径）。**
    - 机制链：`rootfs/reboot2.c` → `syscall(__NR_reboot, …, LINUX_REBOOT_CMD_RESTART2, "bootloader")` → `kernel_restart()`（`kernel/reboot.c:287`）→ `kernel_restart_prepare()`（reboot notifier + `usermodehelper_disable()` + **`device_shutdown()`**，`:100-106`）→ `syscore_shutdown()` → `machine_restart()`（`arch/arm64/kernel/process.c:130`）→ `do_kernel_restart()`（`:245`）→ `atomic_notifier_call_chain(&restart_handler_list)` → 我们的钩子 `psci_elden_try_vendor_reset()`（`drivers/firmware/psci/psci.c:325-347`，`register_restart_handler` @:725 priority 129）→ SMC `SYSTEM_RESET2 0x80010001/0x2`。三树（`geekidos-linux`/`clean-tree-73`/`clean-tree`）同段。
    - **推论**：只要 `device_shutdown()`（显示/DRM/GPU 清理，`#253`/`#106` 那类挂死）或 `syscore_shutdown()` 卡住，**SMC 根本发不出来** ⇒ 症状 = 屏幕冻在当前画面 + USB 全无响应，只能物理 POR。与 `#225`（未就绪发 reboot2 ⇒ 全 USB 通道消失）、`#143` 同型。
    - **另一条同症状路径**：若 SMC 返回而未复位，`machine_restart()` 末尾打印 `Reboot failed -- System halted` 并 `while(1)`（中断已关）。⇒ 区分判据 = 冻结瞬间有无该行；**但仓内 4 份近期串口日志对 `SYSTEM_RESET2 vendor reset` 全 0（reader 都早于 reboot2 关闭）⇒ 目前无直接证据定 H1/H2**，须在串口 reader 存活时故意复现一次。
    - **纪律**：`reboot2 bootloader` 一律不用（进 fastboot 只走物理 POR）；若确要复活该能力，修法方向 ① 提到 reboot notifier（`device_shutdown()` 之前）② 或改走 stock 通道（misc BCB `bootonce-bootloader` / SDAM `restart@48`，见 TWRP `libboot_control_qti.so`）③ 上游 `psci-reboot-mode`（须核对其是否同样落在 restart handler）。证据：`reports/lane-reboot2-audit-20261014.md`（含编排者独立复核节）。

259. **判「boot 慢」必须先分内核/用户态：只看 init 脚本或钩子日志会把内核 async-probe 等待误判成脚本阻塞（2026-10-14 实测 + 自纠）。**
    - 症状：M1-7.3 树 boot 到出画面 ~100 s，看着像 initramfs 钩子在阻塞。**实测决定性判据 = 内核行 `Run /init as init process` 的时间戳**（伴随 `Freeing unused kernel memory`）：E1e 发为 **96.50 s** ⇒ 用户态此刻才起，钩子 `hook start @96.91s` 是结果不是原因。
    - 真因（该发）：WCN(WiFi) 的 MHI 等待超时——`[4.90] mhi mhi0: Wait for device to enter SBL or Mission mode` → `[96.08] ath12k: failed to set mhi state: POWER_ON(2)`（`-110`）⇒ `kernel_init` 在 `async_synchronize_full()`（`init/main.c:1567`）等 probe ⇒ init 到 96.5 s。日常 vk94 对照：ath12k 探针 **23.09 s** 起、**23.66 s** 拿到 `chip_id/fw_version`（等 0.4 s）⇒ 无停滞；M1 树 **4.42 s** 就枚举、chip 不应答、91 s 超时（之后靠用户态 `ath12k-retry` 在 ~311 s 才把 `wlan0` 拉起）。
    - **不要用的代理**：`ps -o etimes -p 1`（本次给出 423 s ≈ uptime 的误导结果）、钩子/脚本自报时间戳（它们本来就晚）。`CONFIG_TYPEC_MUX_FSA4480=y` 修的是**显示**（面板 95.3 s → 4.05 s），与 init 停滞无关，别把两件事混为一谈。
    - 证据：`reports/m1-73-boot-stall-20261014.md`（含本条更正）；`logs/arm-e1e-20261014-130838/console.log`；`logs/arm-vk94ctrl-20261014-090947/console.log`。

260. **7.3 的 ath12k 拆成两个模块：PCI driver 在 `wifi7/` 子模块里——只装 core 等于没装（2026-10-14 实测）。**
    - `ath12k.ko`（core）只 `EXPORT_SYMBOL(ath12k_pci_register_driver)`；**真正注册 PCI driver `ath12k_wifi7_pci` 的是 `drivers/net/wireless/ath/ath12k/wifi7/ath12k_wifi7.ko`**（`depends: ath12k`）。只 insmod core ⇒ `/sys/bus/pci/drivers/` 里没有 ath 项，设备的 `/sys/module/ath12k` 存在但无任何 probe。
    - 连带：设备侧既有 `ath12k-retry.sh` 靠写 `/sys/bus/pci/drivers/ath12k_wifi7_pci/bind` 恢复，驱动目录不存在时只会无限刷 `bind write failed: nonexistent directory`（`existing` 检查只看设备有无 driver ⇒ 一直重试）。
    - **纪律**：把 ath12k 做成 `=m` 时，ramdisk/restore 必须同时提供 `ath12k.ko` + `wifi7/ath12k_wifi7.ko`；且**必须后台加载**（`( insmod … ) &`），否则首探 ~91 s MHI 等待会把 init 堵回去（本条与 #259 同源）。

261. **M1-7.3 boot 时间随「发质量」分档：好发 `Run /init` 4.49 s、坏发 ~48.5 s（2026-10-14 实测）。**
    - 坏发时面板首帧 DCS 就 `-110`（Q28），随后 DRM/DPU 的 `vblank timeout`/`frame done timeout` 风暴打满 call trace，**这些同样落在 `kernel_init` 的 `wait_for_device_probe()` 等待里** ⇒ init 被拖到 ~48 s（E1h），好发则 4.49 s（E1g，同内核同 ramdisk 结构）。
    - **纪律**：M1 的「boot 时间」必须按发分档（好/坏）记录，单发不能当基线；比较 boot 时间要同时报 L1/L2/`dsi_isr`。
    - 附带未决（**样本不足，勿当结论**）：`CONFIG_TYPEC_MUX_FSA4480=y` 把面板 bring-up 从 95.3 s 提前到 ~4.0–4.3 s，4 发里 3 发落 Q28 坏发（E1c 无 L1 但 `dsi_isr`=0；E1d/E1h L1=3；E1g 好发）——「过早 bring-up 是否抬高坏发率」需并列采样。
    - 证据：`reports/m1-73-boot-stall-20261014.md` §6。
