# 厂商 DTBO 在主线上一律 `-EINVAL`：先查板 DTB 有没有 `__symbols__`（#389）

> 日期：2026-10-24 · 场景：把 Gunyah 的 hyp DTBO（从 TZ SIP 拿到的 1013 B FDT overlay）用
> `of_overlay_fdt_apply()` 打到主线 live tree 上，两个 overlay 都返回 `-22/-EINVAL`。

## 判据与根因

- overlay 本身合法（`dtc` 能解、magic `0xd00dfeed`、`fdt_totalsize` 与给定 size 一致）。
- 根因 = **板 DTB 里没有 `__symbols__`**：主线 `dtc` 默认不加 `-@`，而厂商 overlay 带
  `__fixups__`（如 `arch_timer` phandle）⇒ 符号解析失败 ⇒ `of_overlay_fdt_apply` 返回 `-EINVAL`。
- 修法：`DTC_FLAGS_sm8750-lenovo-elden.dtb := -@`（`patches/gunyah/0001-*.patch`），DTB 从 153 KB → 201 KB，之后同一 overlay `apply -> 0`。

⇒ 以后再遇到「合法 overlay 打不进主线」，第一件事是
`dtc -I dtb -O dts <板 dtb> | grep -c __symbols__`（0 = 就是这个坑），而不是去怀疑 overlay 字节。

## 连带坑：`rmmod` 承载 overlay 的模块 = 拆节点 = 整机复位

`dtbo.ko` 持有 overlay；当 `gunyah_rsc_mgr` 已绑到该 overlay 建的节点时 `rmmod dtbo`，
overlay 被移除 ⇒ RM 的 msgq/IRQ 在跑的过程中节点消失 ⇒ 20 s 内整机复位（`/dev/gunyah` 随后消失）。

纪律：重载/卸载 overlay provider 前，先按逆序卸掉消费者
（`rmmod gunyah_rsc_mgr gunyah_qcom gunyah_platform_hooks gunyah gunyah_hypercall`），再动 dtbo。
