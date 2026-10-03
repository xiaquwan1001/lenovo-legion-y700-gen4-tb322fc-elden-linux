# TB321FU: MOD 包组合通过 prevent flash（2026-08-08 晚，验证成功）

`prevent-flash-verify.md` 判定"手动 patch 死路"后，本次会话用**官方 MOD 包组合**实际通过
了 prevent flash。本文件记录：MOD 组合内容、与手动方案的关键差异、验证结果、后续 super 刷写。

## MOD 组合（官方 Flash.cmd 内容 = EDL/QFIL 刷写集）
| 分区 | 镜像 | 说明 |
|---|---|---|
| boot_a | **testkey 签名版**（pixel_pkg/boot.img 即此：pubkey sha1 2597c218, rollback 1759622400） | ABL 信任 testkey ≤ ZUI 17.5.10.170 |
| vendor_boot_a | **MOD 包官方 PRC 版**（4× IROW→IPRC，与手动 patch 字节相同） | 官方工具转换 |
| dtbo_a / init_boot_a | 官方原版（row/full） | MOD 包内即原版 |
| vbmeta_a | MOD 包 vbmeta：**testkey** 主链，chain boot(recovery/testkey)+chain vbmeta_system(**OEM key** cdbb7717)，大量 fingerprint props（均 ROW），hash dtbo/init_boot/vendor_boot，hashtree odm/system_dlkm/vendor/vendor_dlkm | flags=0 |
| vbmeta_system_a | MOD 包：OEM key cdbb7717, RSA2048, **rollback 1754352000**（≠ 原厂 1759622400），仅 props 无描述符 | system 不校验 |

## 关键差异（为什么官方能过、手动不能）
手动方案（repart/final）用 `avbtool add_hash_footer` 重签 vendor_boot，**改了 vendor_boot 内嵌
vbmeta 字段**：@0xd5f012 处 4 字节 `0x00800100` → `0x00024002`…（avbtool 重写 header + 多了 8 字节
内容）→ 触发 prevent flash。官方工具（TB320FC_ROW_fastboot_prc_v2.x）**只改区域码字节，不动内嵌
vbmeta** → ABL 认可。教训：**vendor_boot 的"官方性"由内嵌 vbmeta 区域决定，手动 avbtool 重签会破坏它**。

## 验证结果（用户观察）
1. 不再卡 fastboot（prevent flash 通过）✓
2. 弹出 BL 警告"该系统未被验证"（= testkey 签名被 ABL 接受但标注非官方）✓
3. **闪现 Qualcomm 硬件信息 = 内核被加载并开始执行** ✓
4. 随即黑屏 —— 根因：super 里 system 仍是 **A5 自建 GSI**，与原厂 ZUI boot 链的 vendor 不匹配
   （ZUI boot 链期望 ZUI system）。**修复 = 刷原厂 super**。

## QFIL super 分片拼接 + fastboot 刷 super（验证有效）
- **分片格式**：`super_1~8.img` 不是 Android sparse（无 0xED26FF3A magic）、不是 LP 镜像——
  是**连续原始数据段**，`cat` 直接拼接即可。分片总大小 10.6 GB < 分区 13.97 GB（尾部零填充）。
- **LP 元数据位置（联想布局，非标准）**：拼接后 GEOM @ 218 MB、LPML @ 3294 MB（AOSP 标准在
  分区头部 4 KB/12 KB 处——**不要用标准 LP 解析假设**；需要 system 提取时先全文件扫 `GEOM`/`LPML`）。
- **super 是物理分区，bootloader 模式 fastboot 直接可刷**（不需要 fastbootd——fastbootd 只用于
  super 内部的逻辑分区 system/vendor）：
  ```
  cat super_1..8.img > super_full.img                    # 10.6 GB（放磁盘，/tmp 常是 tmpfs 会配额爆）
  dd if=/dev/zero of=super_pad.img bs=1 count=0 seek=<partition-size:super 字节>   # 稀疏占位
  dd if=super_full.img of=super_pad.img conv=notrunc     # 覆盖前 10.6 GB
  fastboot flash super super_pad.img                     # 13.97 GB，USB2.0 需数分钟，用后台+notify
  ```
  `fastboot getvar partition-size:super` 给十六进制字节数（TB321FU = 0x340000000 = 13,971,390,464）。
- EDL 读回验证写入：`edl r <part> <out>` + sha256 对比（EDL 会话"Connection detected, quiting"
  常在写入**完成后**打印——先读回验证再判断是否失败）。

## 刷写通道经验
- EDL firehose 仍每 1-2 次写入断流（USB Overflow）——拔插 USB 后**先读回验证上一分区**再继续。
- MOD 包官方流程是 EDL/QFIL；**EDL 刷写不依赖 BL 解锁状态**（firehose 底层通道）。
- super 大文件优先 fastboot（通道稳定），boot/vendor_boot 等小文件 fastboot 也稳。
