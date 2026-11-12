# 归档：UEFI logfs 8 MiB 取证件（2026-11-12）

## 做了什么

`reports/artifacts/` 下 23 个试验目录里的 **32 个 8 MiB logfs 全量快照**（合计 256.0 MiB）从
仓库里移出载荷本体，改为每目录一个 `payloads.tar.zst` + 逐件 sha 账 `SHA256SUMS.logfs`：

- 压缩后合计 **0.61 MiB**（这些 dump 绝大多数是 0 填充，zstd -3 压缩率 ≈ 0.2%）。
- sha 用 `dd if=<f> iflag=direct bs=1M` 直读计算（绕页缓存位翻转，见 PITFALLS #513），
  `SHA256SUMS.logfs` 第 3 列标注 `direct-read`。
- 每件写入 tar 后**回读校验**：解包重算 sha 与账目逐件一致（脚本内 assert，32/32 通过）。
- `.gitignore` 追加 `reports/artifacts/**/logfs*.{bin,boot,img}`，防止再次误提交。

依据：项目既定「证据类 artifact 压缩式清理」（2026-11-05 那轮把 `uefi-dxe*-20261104` 的
77 个二进制载荷 tar.zst 后删原件，236.2 MB → 45.9 MB，sha 全留）与「96 MiB 槽位镜像不入库」口径。

## 清单

| 目录 | 件数 | 原大小 | tar.zst |
|---|---|---|---|
| uefi-boot-20261101-130523 / -130938 / -131541 / -132027 / -132423 / -132850 / -133454 / -133929 / -135304 / -150302 | 1 件/目录 | 8 MiB | 20 KiB |
| uefi-boot-20261103-145434 / -164613 / -165429 / -195731 | 1 件/目录 | 8 MiB | 20 KiB |
| uefi-boot-20261107-220032 / -221322 | 1 件/目录 | 8 MiB | 20 KiB |
| uefi-boot-20261109-163712 | 1 件 | 8 MiB | 20 KiB |
| uefi-p61-flash-20261109 / uefi-p62-flash-20261109 | 1 件/目录 | 8 MiB | 20 KiB |
| uefi-p63-flash-20261109 | 8 件 | 64 MiB | 150 KiB |
| uefi-p67-trial-20261110 | 3 件 | 24 MiB | 60 KiB |
| uefi-slotboot-20261101 | 2 件 | 16 MiB | 40 KiB |

逐件文件级 sha 见各自目录的 `SHA256SUMS.logfs`。

## 怎么还原某个原始件

```bash
cd reports/artifacts/<试验目录>
tar --zstd -xf payloads.tar.zst logfs-whole.bin          # 只取一件
dd if=logfs-whole.bin iflag=direct bs=1M status=none | sha256sum   # 与该目录 SHA256SUMS.logfs 首列比对
```

## 对既有文档指针的影响

`reports/*.md`、`TASKS/README.md`、`PITFALLS/sessions/*` 里按文件名引用 `logfs-*.bin` 的地方**不需要改**：
文件名保持不变，只是现在位于 `payloads.tar.zst` 内，需要字节时按上面命令取回；sha 账在
`SHA256SUMS.logfs`，与以前「直接读文件算 sha」等价（且读法已标注为直读）。
