# Gunyah 移植两个静默坑：`if VIRT_DRIVERS` 吞 config、`set_direct_map_*` 未导出（#383）

> 日期：2026-10-24 · 场景：把 AOSP android15-6.6 的 `drivers/virt/gunyah` 移植到 7.3-rc7（`build/gunyah-port`）。

## 坑 1：只开 `CONFIG_GUNYAH=m` 会被 syncconfig 静默丢弃

`drivers/virt/Kconfig` 里 `source "drivers/virt/gunyah/Kconfig"` 位于 `if VIRT_DRIVERS` 块内。
若 `.config` 只有 `CONFIG_GUNYAH=m` 而 `VIRT_DRIVERS` 未开，`syncconfig` 直接把 GUNYAH 抹掉，
**不报错、不警告**，表现为「明明写了 =m 却没编出 .ko」。

判据/做法：
```
grep -E '^CONFIG_(VIRT_DRIVERS|GUNYAH)=' .config    # 两者都要在
grep -c 'CONFIG_GUNYAH' include/config/auto.conf    # syncconfig 后必须仍在
```

## 坑 2：7.3 不导出 `set_direct_map_{invalid,default}_noflush`

`gunyah_rsc_mgr.ko` 依赖 `set_direct_map_default_noflush`（AOSP 的 rmap 版本用来改 guest 内存属性）。
该函数在 `arch/arm64/mm/pageattr.c` 里**存在但未 EXPORT_SYMBOL** ⇒ 模块编得过，
**insmod 时**才报 `Unknown symbol set_direct_map_default_noflush (err -2)`。

判据：
```
aarch64-linux-gnu-nm -u drivers/virt/gunyah/gunyah_rsc_mgr.ko | grep direct_map   # 出现 U 就是要补 export
```
修法（本轮已落 worktree）：在 `arch/arm64/mm/pageattr.c` 给两个函数各加 `EXPORT_SYMBOL_GPL(...)`，
**但必须重编内核**——模块树 UTS 相同的旧内核不会自动获得该符号。

## 坑 3（参考资产）：mainline 已删除 `include/uapi/linux/gunyah.h`

AOSP 6.6 还在用该 UAPI 头，而当前 torvalds 树已删（gunyah 系列未合并）；从 mainline 抓会 404。
本轮从 OnePlus SM8750 的 6.6 厂商树补齐（记 sha256）。⇒ **移植用参考快照时先做文件清单对账**，别信「应该有 N 个文件」。
