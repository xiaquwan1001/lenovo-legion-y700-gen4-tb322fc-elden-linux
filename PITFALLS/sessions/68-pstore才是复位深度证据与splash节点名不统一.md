# 68 · 复位深度的证据在 **上一个内核** 里（pstore），不在本次 dmesg；顺手：`splash_region` 节点名两棵树不同、「没有 simpledrm」≠「没有交接 framebuffer」

- 编号：**#374**（pstore 才是复位深度证据）、**#375**（DT splash 节点名不一致 + 无 simpledrm 的误读）
- 日期：2026-10-23
- 报告：`reports/q32-kickoff-20261023.md`；判据来源 `reports/q32-warm-vs-cold-preresearch-20261023.md`

---

## #374 `psci: SYSTEM_RESET2 vendor reset_type=…` 永远不在「这一发」的 dmesg 里

### 现象

按预研 §2 写法去新启动后 `dmesg | grep 'SYSTEM_RESET2 vendor reset_type'`，**恒为 0** ——
容易误判成「暖复位钩子没生效 / 脚本以为自己进了 bootloader 其实降级了」。

### 根因

那条 `pr_info()` 是**被复位的那一个内核**在 `kernel_restart()` 路径里打的（`patches/kernel-history/elden_vk53-hw/0003-*`）。
复位之后是全新的 `dmesg` 环形缓冲；上一发的打印已经不存在了。

### 正确渠道：pstore / ramoops（在机已就绪）

```
[0.000000] OF: reserved mem: 0xc2000000..0xc23fffff (4096 KiB) nomap non-reusable ramoops@c2000000
[0.026582] printk: legacy console [ramoops-1] enabled
[0.027237] pstore: Registered ramoops as persistent store backend
```
`CONFIG_PSTORE=y / CONFIG_PSTORE_CONSOLE=y / CONFIG_PSTORE_RAM=y`，
`/sys/fs/pstore/console-ramoops*`（可能压缩，先 `zstd -dc`）。

### 两条硬纪律

- **读后即删**：pstore 条目被读一次就没了 ⇒ 取证脚本必须**第一步**归档到 `/var/tmp/`，再分析（`scripts/q32-boot-evidence.sh` 已这么做）。
- **空 ≠ 没发生过暖复位**：真 POR / 断电时 ramoops 区多被重训/清零 ⇒ `PSTORE_PRESENT=no`。
   因此判据只能是单向的：**pstore 有该打印 ⇒ 确定是暖复位（vendor 路径）；没有 ⇒ 不能推断是 POR**，
   必须由人声明（`RESET_DECLARED=por|cold|warm`）或 trial 记录里的 `--reset` 承担。

### 附带结论

架构 `SYSTEM_RESET` 与物理 POR 在**内核侧完全不可区分**（同一 PSCI 调用，无打印）⇒ 任何「暖/冷」对比实验，
每发都必须有一条人类/脚本声明的复位类型，否则样本不可解释。

---

## #375 两个小陷阱：DT 节点名两棵树不同；「无 simpledrm」被当成「无交接 FB」

### 375a 节点名：`splash_region` vs `splash-region@fc800000`

- `linux/` 树（源码）：`splash_mem: splash-region@fc800000 { reg = <0 0xfc800000 0 0x2b00000>; no-map; }`
- **在机 DTB（vk152）**：`/proc/device-tree/reserved-memory/` 下叫 **`splash_region`**（无 unit-address、无 `compatible`）

⇒ 脚本里写死 `/proc/device-tree/reserved-memory/splash-region@fc800000` 会**静默失效**（本轮首次跑就踩到，
表现为 `SPLASH_NODE=no` 而 `dmesg` 明明有 `reserved mem: … splash_region`）。
**一律用通配**：`for d in /proc/device-tree/reserved-memory/*splash*; do …`，并同时看 dmesg 的 `reserved mem:` 行做交叉验证。

### 375b 「没有 simpledrm」≠「没有固件 framebuffer」

7.3 树删掉 `chosen/framebuffer` 后：`simpledrm/efifb` 计数 **0**、`chosen/` 无 `framebuffer` —— 但

```
msm_dpu ae01000.display-controller: boot framebuffer mapped before SID switch: iova=0xfc800000 size=2b00000 translated=0xfc800000
msm_dpu ae01000.display-controller: [drm] reserved boot framebuffer IOVA 0xfc800000+0x2b00000
```

即 ABL **确实**留了活显示，只是内核这侧由 `msm_iommu_record_boot_framebuffer()`（读 `&mdss { memory-region = <&splash_mem> }`）
把该 IOVA **保留**下来（内容不接管、destroy 时才 unmap），而不是交给 simpledrm 当 fbcon。

⇒ 「ABL 有没有点屏」的判据 = `reserved mem:` 行 + `BOOTFB_RECORDED` + cmdline `silent_boot.mode`（`nonsilent` = 点了屏），
**不需要 probe 前快照**。`simpledrm=0` 只说明「内核没把固件 FB 当显示器用」，说明不了固件有没有点屏。
