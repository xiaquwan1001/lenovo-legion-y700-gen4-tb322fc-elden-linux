# Gunyah 零写盘上机实验（2026-10-24）：**驱动全链路加载成功，只差 DT 节点**

> 镜像 `out/boot-elden-gunyah1.img`（sha256 `4d97e7e7…`，85 590 016 B）经 `fastboot boot` **零写盘**引导；
> 模块包 `out/gunyah-modules-gunyah1.tar.gz`（sha256 `753de11d…`）装入 `/lib/modules/<UTS>`。
> 产物证据：`reports/artifacts/gunyah-boot-test-20261024/result.txt`。

## 0. 结论（先数字）

| 检查 | 结果 |
|---|---|
| 镜像引导 | ✅ `fastboot boot` OKAY，SSH 约 15 s 上线，UTS `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`（与模块 vermagic 逐字一致） |
| 2 行 export 生效 | ✅ `/proc/kallsyms` 里 `set_direct_map_{default,invalid}_noflush` 各命中（共 4 条：函数 + `__ksymtab_`） |
| 配置 | ✅ `CONFIG_VIRT_DRIVERS=y`、`CONFIG_GUNYAH=m`、`CONFIG_HAVE_ARM_SMCCC_DISCOVERY=y` |
| 模块加载 | ✅ **5 个模块全部 insmod OK**：`gunyah_hypercall` → `gunyah` → `gunyah_platform_hooks` → `gunyah_qcom` → **`gunyah_rsc_mgr`**（此前因 `set_direct_map_*` 未导出**必失败**的那个） |
| 驱动注册 | ✅ `/sys/bus/platform/drivers/{gunyah,gunyah_rsc_mgr}` 存在 |
| 设备出现 | ❌ `/dev/gunyah` **不存在**；`/sys/bus/platform/devices` 只有 `gunyah-wdt`（那是 `qcom_scm` 注册的，不是本驱动） |
| dmesg | 无 gunyah 打印（模块 probe 未触发，因为**没有 DT 节点**） |

**⇒ 移植本身是通的**（编译 0/0 + 加载成功 + 符号可解析）；**唯一缺口 = DT 节点缺失**，不是代码问题。

## 1. 为什么没有设备：驱动靠 DT 匹配

| 模块 | 需要的 compatible | 来源 |
|---|---|---|
| `gunyah.ko`（→ `/dev/gunyah`） | `"gunyah-hypervisor"` / `"qcom,gunyah-hypervisor"` | `drivers/virt/gunyah/gunyah.c:34-36` |
| `gunyah_rsc_mgr.ko` | `"gunyah-resource-manager"` | `drivers/virt/gunyah/rsc_mgr.c:855-856` |

我们的 mainline DTB 里两个都没有（`/proc/device-tree` 只有 `reserved-memory/gunyah-hyp@80000000` 与 `hypervisor/qcom,gh-watchdog` 从 stock 侧看有、mainline 侧没有）。

## 2. ★关键发现：**厂商 DT 节点的属性集与上游驱动的期望完全对齐**

`gunyah_rsc_mgr` 的 DT 消费逻辑（`rsc_mgr.c:709-720`，`gunyah_platform_probe_capability()`）：

```c
ghrsc->irq   = platform_get_irq(pdev, idx);                    /* idx 0 = tx, 1 = rx */
of_property_read_u64_index(pdev->dev.of_node, "reg", idx, &ghrsc->capid);
```

而 stock Android 运行时节点（`reports/gunyah-dt-capid-20261024.md` §1 实测）恰好有：

```
reg                     ← 两个 u64：tx capid, rx capid
interrupts              ← 两个 IRQ
qcom,free-irq-start / qcom,is-full-duplex / qcom,rx,tx-message-size / qcom,rx,tx-queue-depth   ← 厂商额外属性，上游忽略
```

**⇒ 不需要任何驱动改动、也不需要厂商私有 ABI 适配：只要把该节点的 `reg` + `interrupts` 真值拿到，`gunyah_rsc_mgr` 就能 bind，RM RPC 就能起。**
（这同时否掉了「capid 需要专门的发现协议」这一类猜测——它就是一个普通 DT 属性。）

## 3. 因此剩下的唯一未知仍是那两组数

| 需要 | 现状 | 取法 |
|---|---|---|
| `reg`（tx/rx capid） | 只有 stock Android 运行时 DT 里有，SELinux 拒读 | A：临时 root 读一次；B：走厂商 UEFI 引导（UEFI 的 `RmVmDxe` 会补节点）；C：逆向 `RmVmDxe` 的 cap 来源 |
| `interrupts`（tx/rx IRQ） | 同上 | 同上（`/proc/interrupts` 在 stock Android 上对 shell **可读**，可先拿 IRQ 作交叉验证） |

## 4. 本轮副作用 / 回退

- 设备：`fastboot boot` 零写盘；**未写任何分区**；实验后已重启回 `boot_b`（正常 Linux）。
- rootfs：模块包装进了持久根 `/lib/modules/<UTS>/kernel/{arch/arm64/gunyah,drivers/virt/gunyah}`（9 个 `.ko`），后续实验可直接 `modprobe`；
  不想要时 `rm -rf` 对应目录 + `depmod -a` 即可。
- 无残留进程；无 systemd 单元改动。

## 5. 复现

```bash
# 已在机（模块已安装）
for m in gunyah_hypercall gunyah gunyah_platform_hooks gunyah_qcom gunyah_rsc_mgr; do modprobe $m; done
lsmod | grep gunyah
# 期望（当前状态）：5 个模块在；/dev/gunyah 不存在；dmesg 无 gunyah 打印
```
