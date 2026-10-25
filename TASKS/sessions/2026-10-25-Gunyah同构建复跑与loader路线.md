# 会话：Gunyah 6.12 栈在同一构建内核上复跑 + `VM_INIT 0xA` 归因转向厂商 loader 路线

- 日期：2026-10-25（下午）
- 主题：消掉上轮的「构建不一致」变量；补测最后一个内存模型（整块急切 LEND）；修 7.3 `DTC_FLAGS` 回归；
  定位厂商 `/dev/qgunyah` 侧真正在用的内存所有权模型
- 结论（一句话）：**corruption 确实只是构建不一致（修掉后 0 条）；`VM_INIT 0xA MEM_INVALID` 对内存模型/DTB 布局完全不敏感，
  而厂商路径用的是主线不存在的 `MEM_DONATE(0x51000010)` + `gunyah_loader` hypercall 族 ⇒ G2 走到裁决点。**
- 证据指针：`reports/gunyah-612-samebuild-20261025.md`（主报告）、`PITFALLS #395`（DTC_FLAGS）、`PITFALLS #396`（gunyah.ko permanent）
- 产物：`out/boot-elden-gh612a.img`（反例：无 `__symbols__`）、`out/boot-elden-gh612b.img`（有效件，sha `c3fd81eb…`）

## 1. 做了什么

1. 在 **同一个 worktree** `build/gunyah-port @ 24223e4(dirty)` 重编 `Image.gz dtbs modules`，
   `/proc/version` 与 9 个模块 `vermagic` **逐字一致**（含 `-dirty`）⇒ 硬门通过后 `fastboot boot`（零写盘）。
2. 发现 DTB 无 `__symbols__`（7.3 的 `DTC_FLAGS` 变量名改成 `target-stem`，旧写法静默失效），修好后 overlay `apply -> 0`。
3. 6.12 栈上跑 `rmtest`（`CREATE_VM` → fd）与 `vmmtest` 两个内存模型：SHARE+按需分页、整块 8 MiB 急切 LEND（外加 `DTBOFF=0` 变体）。
4. 反汇编 vendor `gh_rm_drv.ko` / `gunyah_loader.ko` 交叉核对内存模型与 hypercall 族。

## 2. 关键数字

| 项 | 值 |
|---|---|
| corruption 条数（修好后） | 0（grep 的 6 条命中全是 `printk`/`ramoops` 噪声） |
| 6.12 模块 | 9 个，vermagic 逐字 = `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty` |
| RM 序列（两模型相同） | `01 → 12 → 09 → 33 → 34 → 0b` = `0xA MEM_INVALID` |
| 厂商 `MEM_DONATE` | `0x51000010`（`gh_rm_mem_donate` @ `gh_rm_drv.ko 0x67cc`） |
| 主线内存消息 | 只有 `LEND 0x12 / SHARE 0x13 / RECLAIM 0x15 / APPEND 0x18` |
| `gunyah_loader` hvc | `0x6045 0x604e 0x604f 0x6050 0x6052 0x6053 0x6063 0x6065` |

## 3. 收尾状态

- 设备已 `reboot2 normal` 回磁盘 `boot_b`；`/lib/modules/<UTS>/kernel/{drivers/virt,arch/arm64}/gunyah/` = 6.12 驱动集，
  6.6 原件备份在 `/root/ghmodules-6.6-backup.tar.gz`，开机钩子 `/etc/local.d/50-gunyah.start` 加载 9 个模块。
- 干净启动即 `/dev/gunyah` 可用、`dmesg` 无 corruption；`build/vk151` 日用树未改。
- 未写任何分区（仅 `fastboot boot`）。

## 4. 下一步（需用户裁决）

A 逆向 `gunyah_loader` 的 `MEM_DONATE + hvc 0x60xx` 在主线重建 donate 型内存路径（不可上游化）；
B 换参考 VMM（`qemu-for-gunyah`/crosvm-glibc）做差值（仍走 `/dev/gunyah`，大概率不解）；
C G2 回 Waydroid，Gunyah 只保留 6.12 分层作为 G1 上游补丁素材。
