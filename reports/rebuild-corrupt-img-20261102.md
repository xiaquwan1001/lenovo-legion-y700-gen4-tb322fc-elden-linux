# 2026-11-02 — 修复两枚静默损坏镜像（vk155 / m3v5-onboard-b）

来源症状：`reports/artifacts/vk-identity-corrupt-20261102.txt`（boot v0 header 正常、4096 处 gzip magic、
zlib 报 incorrect data check、文件 sha 与 manifest image_sha256 不符且 mtime 未变）。
坏件已移 `out/corrupt-20261102/`（未删）；新件写回 `out/` 原名。构建日志：`logs/rebuild-m3v5-onboard-b-20261102.log`。

## 总结论

| 镜像 | 结论 | 新 image sha256 | 与 manifest image_sha256 |
|---|---|---|---|
| `out/boot-elden-m3v5-onboard-b.img` | **原物恢复（逐字节相等）** | `a144e5ce1b374b928852bfb3503249ca48e81b37f53c4bb4005655bc597ec1e3` | **完全一致** |
| `out/boot-elden-vk155.img` | **失败：载荷数据真坏 + 原件无副本，不可原物恢复**（坏件保留于 out/corrupt-20261102/） | — | — |

---

## 一、boot-elden-m3v5-onboard-b.img — 原物恢复

### 症状
- 88 260 608 B，header v2 正常，kernel blob sha `8870e922…` ≠ manifest `kernel_packed_sha256=513db6c9…`。
- gzip 尾部 8 字节（CRC32+ISIZE）被清零（stored crc=0x0, isize=0）；忽略 CRC 解压可得完整输出但
  sha `1f571533…` ≠ manifest `kernel_payload_sha256=c4e884ad…`。

### 尝试与判据
1. 忽略 CRC 流式解压（`zlib.decompressobj(16+MAX_WBITS)`，截尾 5 B）：得 60 056 064 B，sha `1f571533…` ≠ manifest ⇒ 数据真坏（非仅尾部）。
2. 与健康 sibling `out/boot-elden-m3v5-onboard.img`（payload `c4e884ad…` 逐字解出）逐字节 diff：
   **仅 13 字节不同**，散布于 22 524 371–22 552 906 区间 ⇒ 局部零化损坏。
3. 原件在盘核查（全部与 manifest 逐字相等）：
   - `build/m3v5-pristine/arch/arm64/boot/Image.gz` = `513db6c9…`（= kernel_packed_sha256）
   - `out/initramfs-m3v5x1.cpio.gz` = `de859e0c…`（= ramdisk_sha256）
   - `out/m3v5-onboard/sm8750-lenovo-elden.dtb` = `0b614a3c…`（= dtb_packed_sha256）
   - `build/m3v5-pristine/.config` = `d3371cdb…`（= config_sha256）；git head `34865c8915bf` clean（= kernel_git_head）
4. 按 manifest `mkbootimg_args` 原样重打包：`python3 scripts/mkbootimg.py …`（同 argv，含 base/offsets/pagesize 4096）。

### 结论与验收
- 重打包产物 image sha256 = `a144e5ce…`，**与 manifest image_sha256 逐字相等 ⇒ 原物恢复**。
- ① 解 gzip 无 CRC 错（`do.decompress(k)+flush()` 直接通过）；② payload sha256 = `c4e884ada92970bd7fc7683d34d6efe1d185bc1ab8c8a8de179faff221e295fa` = manifest `kernel_payload_sha256`；③ banner = `Linux version 7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172 (elden@y700)…` = manifest kernel_uts；④ image sha = manifest 值，**无残余差异**，manifest 无需更新任何字段。

## 二、boot-elden-vk155.img — 失败（不可原物恢复）

### 症状
- 22 032 384 B，header v2 正常；kernel blob gzip 尾部同样被清零（crc=0/isize=0）。
- kernel blob 内 19 849 950 / 19 925 148 / 19 939 941 三处存在 1181/194/3555 B 的长零块（deflate 流中不应出现）⇒ 载荷数据被零化。
- 忽略 CRC 解压得 63 443 406 B，sha `93b34dbd…` ≠ manifest `kernel_payload_sha256=82e5c4b2…` ⇒ **数据真坏**。
- ramdisk 段完好：镜像内 ramdisk sha `2e9c9e1f…` = manifest `ramdisk_sha256`。

### 尝试
1. 原件 `Image.gz`（manifest kernel_sha256=`f641ad60…`）副本检索：`build/*/arch/arm64/boot/Image*` 全量 sha256 无一匹配（`build/vk151` 现为 `c9e6dae6…`）；71 个 out manifest 中 payload `82e5c4b2` / kernel `f641ad60` 仅 vk155 自身记录 ⇒ **无副本**。
2. 重建可行性核查：manifest config_sha256=`ba0c2a49…`（该 config 2026-10-23 由 `patches/config-vk127-working-20261018`+LOCALVERSION 钉版产生，报告 `reports/q28-v2-mdss-reset-20261023.md` §8 可考）；kernel git head `24223e44ad80` 仍在 vk151 git 中，但 vk155 为 **dirty+**（ITS quiesce 调用点前移等未提交改动），现 vk151 工作树已演进为 vk172 线（head `509f271d52`、release `…-dirty-debug-vk172`、11 个 dirty 文件已含后续改动），vk155 当时的 dirty 差集不可复原；且 kernel build 在 Image 内嵌编译时间戳 ⇒ 即使恢复源码态，重编 payload sha 也不可能逐字等于 `82e5c4b2`。dtb 亦已变（现 `e7642d7a…` ≠ manifest `7190ecf0…`）。
3. 据此**未执行重编**：产物只能是「vk172 线源码 + 部分近似 dirty」的新内核，打上 vk155 名号会造成版本身份失真（违背「不许掩盖」）。

### 结论
- **失败**：局部零化破坏 deflate 数据 + 原件无副本 + dirty 源码态不可复原 ⇒ 原物恢复与等价重建（payload 逐字相同）均不可达。
- 处置：坏件保留 `out/corrupt-20261102/boot-elden-vk155.img`（sha `8eef9acad8dc82b6c345760250525211b175691affb56e556658b331fb24216b`）；`versions/vk-kernel-identity.tsv` 维持 `kernel-unreadable` 标注即可收口该 WARN（如需 ITS-kexec 测试镜像，应以**新版本号**重立项，不冒用 vk155）。

---

## 复现命令要点

```bash
# onboard-b 重打包（mkbootimg_args 与 manifest 一字不差）
python3 scripts/mkbootimg.py --header_version 2 --os_version 15.0.0 --os_patch_level 2025-08 \
  --kernel build/m3v5-pristine/arch/arm64/boot/Image.gz --ramdisk out/initramfs-m3v5x1.cpio.gz \
  --dtb out/m3v5-onboard/sm8750-lenovo-elden.dtb --cmdline '<manifest cmdline 原文>' \
  --base 0x0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 --second_offset 0xf00000 \
  --tags_offset 0x100 --dtb_offset 0x1f00000 --pagesize 4096 -o out/boot-elden-m3v5-onboard-b.img
sha256sum out/boot-elden-m3v5-onboard-b.img   # = a144e5ce… = manifest image_sha256
```
