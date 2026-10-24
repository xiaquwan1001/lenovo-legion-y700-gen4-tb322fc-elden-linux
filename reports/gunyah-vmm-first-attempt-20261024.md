# Gunyah VMM 第一步（2026-10-24 深夜）：用户态 harness 打通到 `VM_INIT`，RM 返回 **IRQ_INUSE(0x10)**

> 前置已就绪：RM 在主线可用（`reports/gunyah-mainline-rm-up-20261024.md`）。
> 本轮目标：不经 QEMU/crosvm，用最小 harness 把 guest VM 跑起来。
> 状态：**未完成** —— `VM_ALLOC_VMID` / DTB parcel 共享 / `VM_CONFIG_IMAGE` 全过，卡在 `VM_INIT`。

## 1. 已实测通过的链路（`tools/gunyah-modules/vmmtest/`）

```
open /dev/gunyah → GUNYAH_CREATE_VM                ✅ vm fd
GH_VM_SET_USER_MEM_REGION(gpa=0x80000000, 8 MiB, RWX)  ✅
GUNYAH_VM_SET_DTB_CONFIG(gpa+0x1000, 0x1000)       ✅
GUNYAH_VM_START                                     ❌ -EINVAL
```

dmesg 精确落点：

```
gunyah_rsc_mgr hypervisor:qcom,resource-manager-rpc@…: RM rejected message 5600000b. Error: 10
misc gunyah: Failed to initialize VM: -22
```

- `0x5600000b` = `GUNYAH_RM_RPC_VM_INIT`（`rsc_mgr_rpc.c:24`）。
- `Error: 10 (0x10)` = **`GUNYAH_RM_ERROR_IRQ_INUSE`**（`rsc_mgr.c` 的 `enum gunyah_rm_error`：`0xF=IRQ_INVALID`、`0x10=IRQ_INUSE`、`0x11=IRQ_RELEASED`）。

⇒ 也就是说：**VM 片本身被 RM 认可（vmid 已分配、DTB parcel 已被接受），卡在「给这个 VM 分配 IRQ 时发现已被占用」**。

## 2. 两个候选解释（未判定）

1. **IRQ 泄漏/池冲突**：本轮之前在同一 boot 里跑过多次 `GUNYAH_CREATE_VM`（RM RPC 冒烟测试），每次可能各占一份 Gunyah 虚拟 IRQ；VM 摧毁后未归还 ⇒ 新建 VM 时 `IRQ_INUSE`。
   **判据**：**新 boot 后第一件事**就跑 `vmmtest`（RM 状态全新鲜）。本轮想验这一点时设备被误操作成 USB 不枚举（`PITFALLS #368`：`reboot2 bootloader` 在 uptime 26 s 时下发），未取到数据。
2. **DTB 太"空"**：我们给的 guest DTB 只有 `memory` + `chosen`，没有 Gunyah guest 侧节点（doorbell / msgq / irq 分配对象），RM 的 `VM_INIT` 需要按 DTB 里的资源声明去分配 IRQ，声明缺失时可能退化成「固定 IRQ」而撞车。
   **判据**：把 guest DTB 换成带 Gunyah 资源节点的版本（vendor/crosvm 的 guest DT 模板）再试。

## 3. 其它已确认事实

- 开机自启钩子 `/etc/local.d/50-gunyah.start` **有效**：`reboot` 后 `dtbo.ko` 与 gunyah 5 模块自动加载；但**槽启动（boot_b）的 DTB 没有 `__symbols__`** ⇒ overlay 仍 `-EINVAL`，`/dev/gunyah` 不出现。⇒ 把 `-@` DTB 落到 boot_b 才是「开机即有 RM」的最后一公里（下次 vk 构建默认带）。
- `gunyah_vcpu.ko` / `irqfd` / `ioeventfd` 均已编好、可加载。

## 4. 下一步（按顺序）

1. 冷起（全新 RM 状态）先跑 `vmmtest`，判定 §2-① 是否成立。
2. 不成立则换 guest DTB（对照 `Droid-VM/crosvm` 的 gunyah guest DT 与 `edk2-gunyah` 的 VM DT）。
3. `VM_INIT` 过后剩下：`ADD_FUNCTION(VCPU 0)` → `SET_BOOT_CONTEXT(PC/X0/SP)` → `VCPU_RUN`，stub 会写 magic 并撞未映射物理地址（`0x0F000000`）⇒ 期望 `GUNYAH_VCPU_EXIT_MMIO` 或 `PAGE_FAULT`，且宿主内存里能读到 magic（这两条是「guest 真的执行了」的硬判据）。
