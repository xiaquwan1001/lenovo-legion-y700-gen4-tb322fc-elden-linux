# Session：2026-10-26 UEFI 可见性与 UFSDxe 代次差（lane E）

## 范围
主机侧：BootShim cache maintenance 取证 + 补丁 + 编译；UFSDxe 厂商件替换重建 A2/N2；issue #12 复核。不碰设备。

## 做了什么
1. Mu 树复用（7-mu-lenovo @ 6b6ac42a），取证链：BootShim.S（裸 ldp/stp 拷贝 + `br x5`，0 条 cache 指令）→ AndromedaPkg PrePi（`ArmDisableCachesAndMmu` 只清位不 clean；`ic iallu` 有；PrePi.c 的 `InvalidateDataCacheRange` 只 invalidate 不 clean）→ 结论：拷贝→执行跳变前缺 `dc civac` 序列。
2. 补丁 `patches/uefi/0001-bootshim-add-dc-civac-ic-iallu-before-entry.patch`（五步序列：civac 循环→dsb→ic iallu→dsb→isb），BootShim 编译 rc=0，反汇编核对指令编码。
3. 重建 A2（厂商 UFSDxe fa561bf1 + Mu RmVmDxe）/N2（全 Mu），均含补丁 BootShim；img→gunzip→LZMA@0xd268→ffs-extract 逐枚核对 PE32 sha 全中。
4. issue #12：仍 Open，最后活动 = 我方 10-21 追问，作者 0 回复 ⇒ 不回帖。

## 关键 sha
- A2.img `251953b9db75521b7938808643e2fff3b8e29887cc2013eaab70a02517a4ebb6`
- N2.img `528702c67a37487177f2761832d2ae949f8042798a3e9dacbdd11e574a5b2f9f`
- BootShim-cachefix.bin `0c1bb4daf0619be805ac0a1d9c601c5f61abab4342959aa92ba5c484bc09ac57`

## 坑
- LZMA GUID 字节序：手写 GUID hex 要做 little-endian 重排（`ee4e5898…` → `98584eee…`），且 fd 内两处命中（0x9d90 假、0xd268 真）。
- ffs-extract.py 用法是 `--out`，位置参数混用会报 usage。

## 未做 / 待父 agent
- C2（+厂商 RmVmDxe）未重建；上机 fastboot boot A2→N2；判据见报告 §4。
- 本机无可行 UART；显示通道是最便宜的早期存活信号。
