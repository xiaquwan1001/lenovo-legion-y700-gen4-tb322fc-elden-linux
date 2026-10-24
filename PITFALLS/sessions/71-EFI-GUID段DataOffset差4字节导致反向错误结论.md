# EFI GUID-defined 段的 `DataOffset` 差 4 字节 ⇒ 得出「固件里没有该模块」的反向错误结论（#382）

> 日期：2026-10-24 · 场景：解析厂商 `uefi.elf` 找 UFSDxe。

## 现象

自写 FFS 解析器（`scripts/ffs-extract.py`）在 `uefi.elf` 上：
- FV/FFS 枚举正常（SEC + `uefiplat.cfg` + 2×`SMM_CORE`）；
- 所有 GUID-defined（LZMA）段 `lzma.decompress(...)` **全部 `LZMAError`**；
- 于是得出「DXE 驱动不在 UEFI FV、只在 XBL 打包体」的结论，并写进报告/任务台账。

**这个结论是错的。** 后台 lane 用另一套解析器解出 4 247 552 B 内嵌 FV，枚举到 `DxeCore` 和 59 个 DXE 模块，
其中包括**厂商 UFSDxe**（`0d35cd8e-…`、151 552 B、sha `fa561bf1…`）。

## 根因

`EFI_GUID_DEFINED` section 布局：

```
[0..3]  SectionSize(3) + Type(1)=0x02      <-- section 头起始（off）
[4..19] SectionDefinitionGuid(16)
[20..21] DataOffset(u16)                   <-- 相对 **section 头起始**
[22..23] Attributes(u16)
[DataOffset ..]  payload
```

我写成 `payload = buf[guid_offset + DataOffset:]`（即少算 4 字节）⇒ LZMA 流整体错位 ⇒ 必然失败。

## 纪律

- **解压「全部失败」时先怀疑自己的偏移/长度**，不要立刻归因「厂商私有压缩格式不可解」——后者会把一条可行路径判死。
- 结构化二进制解析要**交叉验证**：换一个工具/另一个实现各跑一次；或先验证已知可解样本（本例里 `imagefv.elf` 的同型段能解，就说明不是格式问题）。
- 反向结论（「固件里没有 X」）尤其危险：**证明存在只要一个命中，证明不存在需要正确解析全部路径**。

## 附带收获（更正后的正确事实）

- `uefi.elf` = ELF 外壳 → FV@0x1000 → 两个 LZMA 内嵌 FV（4 247 560 B / 3 194 888 B），后者之外还有 59 个 DXE 模块；
- 厂商 `UFSDxe` 与 Mu 的构建**同源**（字符串偏移逐字相同：`UFS.c` @`0x1b438`、`ufs_error_log` @`0x1e045`）；
- 产物：`reports/artifacts/uefi-dxe-20261024/`。
